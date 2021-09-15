// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import {ICollateral} from "./Collateral.sol";
import {BitcoinKeyDerivation} from "./crypto/BitcoinKeyDerivation.sol";
import {ExchangeRateOracle} from "./ExchangeRateOracle.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";

abstract contract VaultRegistry is ICollateral {
    struct Vault {
        uint256 btcPublicKeyX;
        uint256 btcPublicKeyY;
        uint256 collateral;
        uint256 issued;
        uint256 toBeIssued;
        uint256 toBeRedeemed;
        uint256 replaceCollateral;
        uint256 toBeReplaced;
        mapping(address => bool) depositAddresses;
    }
    mapping(address => Vault) public vaults;
    uint256 public constant secureCollateralThreshold = 150; // 150%
    ExchangeRateOracle oracle;

    event RegisterVault(
        address indexed vaultId,
        uint256 collateral,
        uint256 btcPublicKeyX,
        uint256 btcPublicKeyY
    );

    event VaultPublicKeyUpdate(address indexed vaultId, uint256 x, uint256 y);
    event IncreaseToBeIssuedTokens(address indexed vaultId, uint256 amount);
    event IncreaseToBeRedeemedTokens(address indexed vaultId, uint256 amount);
    event DecreaseToBeIssuedTokens(address indexed vaultId, uint256 amount);
    event IssueTokens(address indexed vaultId, uint256 amount);
    event RedeemTokens(address indexed vaultId, uint256 amount);
    event IncreaseToBeReplacedTokens(address indexed vaultId, uint256 amount);
    event DecreaseToBeReplacedTokens(address indexed vaultId, uint256 amount);
    event ReplaceTokens(address indexed oldVaultId, address indexed newVaultId, uint256 tokens, uint256 collateral);

    function registerVault(uint256 btcPublicKeyX, uint256 btcPublicKeyY)
        external
        payable
    {
        address vaultId = msg.sender;
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX == 0, "vaultExist");
        require(
            btcPublicKeyX != 0 && btcPublicKeyY != 0,
            "invalidPubkey"
        );
        vault.btcPublicKeyX = btcPublicKeyX;
        vault.btcPublicKeyY = btcPublicKeyY;
        lockAdditionalCollateral();
        emit RegisterVault(
            vaultId,
            msg.value,
            btcPublicKeyX,
            btcPublicKeyY
        );
    }

    function toBeRedeemed(address vaultId) public view returns (uint256) {
        Vault storage vault = vaults[vaultId];
        return vault.toBeRedeemed;
    }

    function issued(address vaultId) public view returns (uint256) {
        Vault storage vault = vaults[vaultId];
        return vault.issued;
    }

    function registerDepositAddress(address vaultId, uint256 issueId)
        internal
        returns (address)
    {
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");
        address derivedKey =
            BitcoinKeyDerivation.derivate(
                vault.btcPublicKeyX,
                vault.btcPublicKeyY,
                issueId
            );

        require(!vault.depositAddresses[derivedKey], 'This btc address already used');
        vault.depositAddresses[derivedKey] = true;

        return derivedKey;
    }

    function insertVaultDepositAddress(
        address vaultId,
        uint256 btcPublicKeyX,
        uint256 btcPublicKeyY,
        uint256 replaceId
    ) internal returns(address) {
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");

        address btcAddress = BitcoinKeyDerivation.derivate(
            btcPublicKeyX,
            btcPublicKeyY,
            replaceId
        );

        require(!vault.depositAddresses[btcAddress], 'This btc address already used');
        vault.depositAddresses[btcAddress] = true;

        return btcAddress;
    }

    function updatePublicKey(
        uint256 btcPublicKeyX,
        uint256 btcPublicKeyY
    ) external {
        address vaultId = msg.sender;
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");
        vault.btcPublicKeyX = btcPublicKeyX;
        vault.btcPublicKeyY = btcPublicKeyY;
        emit VaultPublicKeyUpdate(vaultId, btcPublicKeyX, btcPublicKeyY);
    }

    function lockAdditionalCollateral() public payable {
        address vaultId = msg.sender;
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");
        vault.collateral += msg.value;
        ICollateral.lockCollateral(vaultId, msg.value);
    }

    function withdrawCollateral(uint256 amount) external {
        Vault storage vault = vaults[msg.sender];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");
        vault.collateral -= amount;
        ICollateral.releaseCollateral(msg.sender, amount);
    }

    function decreaseToBeIssuedTokens(address vaultId, uint256 amount) internal {
        Vault storage vault = vaults[vaultId];
        vault.toBeIssued -= amount;
        emit DecreaseToBeIssuedTokens(vaultId, amount);
    }

    function tryIncreaseToBeIssuedTokens(address vaultId, uint256 amount) internal returns(bool) {
        uint256 issuableTokens = issuableTokens(vaultId);
        if(issuableTokens < amount) return false; // ExceedingVaultLimit
        Vault storage vault = vaults[vaultId];
        vault.toBeIssued += amount;
        emit IncreaseToBeIssuedTokens(vaultId, amount);
        return true;
    }

    function tryIncreaseToBeRedeemedTokens(address vaultId, uint256 amount) internal returns(bool) {
        uint256 redeemable = redeemableTokens(vaultId);
        if(amount > redeemable) return false; // ExceedingVaultLimit
        Vault storage vault = vaults[vaultId];
        vault.toBeRedeemed += amount;
        emit IncreaseToBeRedeemedTokens(vaultId, amount);
        return true;
    }

    function redeemableTokens(address vaultId) internal returns(uint256) {
        Vault storage vault = vaults[vaultId];
        return vault.issued - vault.toBeRedeemed;
    }

    function redeemTokens(address vaultId, uint256 amount) internal {
        Vault storage vault = vaults[vaultId];
        vault.toBeRedeemed -= amount;
        vault.issued -= amount;
        emit RedeemTokens(vaultId, amount);
    }

    function calculateMaxWrappedFromCollateralForThreshold(uint256 collateral, uint256 threshold) public view returns(uint256) {
        // TODO - fix oracle.collateralToWrapped
        // uint256 collateralInWrapped = oracle.collateralToWrapped(collateral);
        return collateral*100/threshold;
    }

    function issuableTokens(address vaultId) public view returns(uint256) {
        uint256 freeCollateral = ICollateral.getFreeCollateral(vaultId);
        return calculateMaxWrappedFromCollateralForThreshold(freeCollateral, secureCollateralThreshold);
    }

    function issueTokens(address vaultId, uint256 amount) internal {
        Vault storage vault = vaults[vaultId];
        vault.issued += amount;
        vault.toBeIssued -= amount;
        emit IssueTokens(vaultId, amount);
    }

    function calculateCollateral(uint256 collateral, uint256 numerator, uint256 denominator) internal returns (uint256 amount) {
        if(numerator == 0 && denominator == 0) {
            return collateral;
        }

        return collateral * numerator / denominator;
    }

    function requestableToBeReplacedTokens(address vaultId) internal returns (uint256 amount) {
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");

        uint256 requestableIncrease = vault.issued - vault.toBeRedeemed - vault.toBeReplaced;

        return requestableIncrease;
    }

    function tryIncreaseToBeReplacedTokens(address vaultId, uint256 tokens, uint256 collateral) internal returns (uint256, uint256) {
        Vault storage vault = vaults[vaultId];

        uint256 requestableIncrease = requestableToBeReplacedTokens(vaultId);

        require(tokens <= requestableIncrease, 'Could not increase to-be-replaced tokens because it is more than issued amount');

        vault.toBeReplaced += tokens;
        vault.replaceCollateral += collateral;

        emit IncreaseToBeReplacedTokens(vaultId, tokens);

        return (vault.toBeReplaced, vault.replaceCollateral);
    }

    function decreaseToBeReplacedTokens(address vaultId, uint256 tokens) internal returns (uint256, uint256) {
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");

        uint256 usedTokens = Math.min(vault.toBeReplaced, tokens);

        uint256 calculatedCollateral = calculateCollateral(vault.replaceCollateral, usedTokens, vault.toBeReplaced);
        uint256 usedCollateral = Math.min(vault.replaceCollateral, calculatedCollateral);

        vault.toBeReplaced -= usedTokens;
        vault.replaceCollateral -= usedCollateral;

        emit DecreaseToBeReplacedTokens(vaultId, usedTokens);

        return(usedTokens, usedCollateral);
    }

    function replaceTokens(address oldVaultId, address newVaultId, uint256 tokens, uint256 collateral) internal {
        Vault storage oldVault = vaults[oldVaultId];
        Vault storage newVault = vaults[newVaultId];

        require(oldVault.btcPublicKeyX != 0, "vaultNotExist");
        require(newVault.btcPublicKeyX != 0, "vaultNotExist");

        // TODO: add liquidation functionality
        // if old_vault.data.is_liquidated()

        oldVault.issued -= tokens;
        newVault.issued += tokens;

        emit ReplaceTokens(oldVaultId, newVaultId, tokens, collateral);
    }

    function tryDepositCollateral(address vaultId, uint256 amount) internal {
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");

        ICollateral.lockCollateral(vaultId, amount);

        // Self::increase_total_backing_collateral(amount)?;

        // TODO: Deposit `amount` of stake in the pool
        // ext::staking::deposit_stake::<T>(T::GetRewardsCurrencyId::get(), vault_id, vault_id, amount)?;
    }
}
