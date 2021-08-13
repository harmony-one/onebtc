// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import {ICollateral} from "./Collateral.sol";
import {BitcoinKeyDerivation} from "./crypto/BitcoinKeyDerivation.sol";
import {ExchangeRateOracle} from "./ExchangeRateOracle.sol";

abstract contract VaultRegistry is ICollateral {
    struct Vault {
        uint256 btcPublicKeyX;
        uint256 btcPublicKeyY;
        uint256 collateral;
        uint256 issued;
        uint256 toBeIssued;
        uint256  toBeRedeemed;
        uint256 replaceCollateral;
        uint256 toBeReplaced;
        address[] depositAddresses;
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
        vault.depositAddresses.push(derivedKey);
        return derivedKey;
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

    function calculateCollateral(uint256 collateral, uint256 numerator, uint256 denominator) internal pure returns(uint256){
        return collateral*numerator/denominator;
    }

    function decreaseToBeIssuedTokens(address vaultId, uint256 amount) internal {
        Vault storage vault = vaults[vaultId];
        vault.toBeIssued -= amount;
        emit DecreaseToBeIssuedTokens(vaultId, amount);
    }

    function tryIncreaseToBeIssuedTokens(address vaultId, uint256 amount) internal returns(bool) {
        uint256 issuableTokens = issuableTokens(vaultId);
        if(issuableTokens > amount) return false; // ExceedingVaultLimit
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
        uint256 collateralInWrapped = oracle.collateralToWrapped(collateral);
        return collateralInWrapped*100/threshold;
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

    function increaseToBeReplacedTokens(address vaultId, uint256 btcAmount, uint256 collateral) internal returns (uint256 amount, uint256 collateral) {
        Vault storage vault = vaults[vaultId];

        require(!!vault, 'The Vault cannot be found');

        // The vault’s increased toBeReplaceedTokens MUST NOT exceed issuedTokens - toBeRedeemedTokens.
        uint256 replacableTokens = vault.issued - vault.toBeRedeem - vault.toBeReplace;
        uint256 amount = btcAmount > replacableTokens ? replacableTokens : btcAmount;
        require(amount <= 0, 'Could not withdraw to-be-replaced tokens because it was already zero');

        // An amount of griefingCollateral * (tokenIncrease / btcAmount) MUST be locked by this transaction.
        uint256 griefingCollateral = collateral * (replacableTokens / btcAmount);

        // TODO: added support for increased collateral value
        require(msg.value == griefingCollateral, 'The provided collateral is wrong');

        vault.toBeReplaced += amount;
        vault.replaceCollateral += griefingCollateral;

        emit IncreaseToBeReplacedTokens(vaultId, amount);

        return (amount, griefingCollateral);
    }

    function decreaseToBeReplacedTokens(address vaultId, uint256 tokens) internal returns (uint256 amount, uint256 collateral) {
        Vault storage vault = vaults[vaultId];

        require(!!vault, 'The Vault cannot be found');

        // tokenDecrease = min(toBeReplacedTokens, tokens)
        uint256 tokenDecrease = vault.toBeReplacedTokens > tokens ? tokens : vault.toBeReplacedTokens;

        require(tokenDecrease > 0, 'tokenDecrease should be non zero');

        vault.toBeReplaced -= tokenDecrease;

        uint collateralDecrease = (tokenDecrease / vault.toBeReplacedTokens) * vault.replaceCollateral;

        vault.replaceCollateral -= collateralDecrease;

        emit DecreaseToBeReplacedTokens(vaultId, tokenDecrease);

        return (tokenDecrease, collateralDecrease);
    }
}
