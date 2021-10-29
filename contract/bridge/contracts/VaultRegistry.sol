// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import {ICollateral} from "./Collateral.sol";
import {BitcoinKeyDerivation} from "./crypto/BitcoinKeyDerivation.sol";
import {ExchangeRateOracle} from "./ExchangeRateOracle.sol";

abstract contract VaultRegistry is Initializable, ICollateral {
    using SafeMathUpgradeable for uint256;

    struct Vault {
        uint256 btcPublicKeyX;
        uint256 btcPublicKeyY;
        uint256 collateral;
        uint256 issued;
        uint256 toBeIssued;
        uint256 toBeRedeemed;
        uint256 replaceCollateral;
        uint256 toBeReplaced;
        uint256 liquidatedCollateral;
        mapping(address => bool) depositAddresses;
    }

    mapping(address => Vault) public vaults;
    uint256 public constant SECURE_COLLATERAL_THRESHOLD = 150; // 150%
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
    event ReplaceTokens(
        address indexed oldVaultId,
        address indexed newVaultId,
        uint256 tokens,
        uint256 collateral
    );
    event LiquidateVault();

    function registerVault(uint256 btcPublicKeyX, uint256 btcPublicKeyY)
        external
        payable
    {
        address vaultId = msg.sender;
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX == 0, "vaultExist");
        require(btcPublicKeyX != 0 && btcPublicKeyY != 0, "invalidPubkey");
        vault.btcPublicKeyX = btcPublicKeyX;
        vault.btcPublicKeyY = btcPublicKeyY;
        lockAdditionalCollateral();
        emit RegisterVault(vaultId, msg.value, btcPublicKeyX, btcPublicKeyY);
    }

    // function toBeRedeemed(address vaultId) public view returns (uint256) {
    //     Vault storage vault = vaults[vaultId];
    //     return vault.toBeRedeemed;
    // }

    // function issued(address vaultId) public view returns (uint256) {
    //     Vault storage vault = vaults[vaultId];
    //     return vault.issued;
    // }

    function registerDepositAddress(address vaultId, uint256 issueId)
        internal
        returns (address)
    {
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");
        address derivedKey = BitcoinKeyDerivation.derivate(
            vault.btcPublicKeyX,
            vault.btcPublicKeyY,
            issueId
        );

        require(
            !vault.depositAddresses[derivedKey],
            "This btc address already used"
        );
        vault.depositAddresses[derivedKey] = true;

        return derivedKey;
    }

    function insertVaultDepositAddress(
        address vaultId,
        uint256 btcPublicKeyX,
        uint256 btcPublicKeyY,
        uint256 replaceId
    ) internal returns (address) {
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");

        address btcAddress = BitcoinKeyDerivation.derivate(
            btcPublicKeyX,
            btcPublicKeyY,
            replaceId
        );

        require(
            !vault.depositAddresses[btcAddress],
            "This btc address already used"
        );
        vault.depositAddresses[btcAddress] = true;

        return btcAddress;
    }

    function updatePublicKey(uint256 btcPublicKeyX, uint256 btcPublicKeyY)
        external
    {
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
        vault.collateral = vault.collateral.add(msg.value);
        ICollateral.lockCollateral(vaultId, msg.value);
    }

    function withdrawCollateral(uint256 amount) external {
        Vault storage vault = vaults[msg.sender];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");
        vault.collateral = vault.collateral.sub(amount);
        ICollateral.releaseCollateral(msg.sender, amount);
    }

    function decreaseToBeIssuedTokens(address vaultId, uint256 amount)
        internal
    {
        Vault storage vault = vaults[vaultId];
        vault.toBeIssued = vault.toBeIssued.sub(amount);
        emit DecreaseToBeIssuedTokens(vaultId, amount);
    }

    function tryIncreaseToBeIssuedTokens(address vaultId, uint256 amount)
        internal
        returns (bool)
    {
        uint256 issuableTokens = issuableTokens(vaultId);
        if (issuableTokens < amount) return false; // ExceedingVaultLimit
        Vault storage vault = vaults[vaultId];
        vault.toBeIssued = vault.toBeIssued.add(amount);
        emit IncreaseToBeIssuedTokens(vaultId, amount);
        return true;
    }

    function tryIncreaseToBeRedeemedTokens(address vaultId, uint256 amount)
        internal
        returns (bool)
    {
        uint256 redeemable = redeemableTokens(vaultId);
        if (amount > redeemable) return false; // ExceedingVaultLimit
        Vault storage vault = vaults[vaultId];
        vault.toBeRedeemed = vault.toBeRedeemed.add(amount);
        emit IncreaseToBeRedeemedTokens(vaultId, amount);
        return true;
    }

    function redeemableTokens(address vaultId) internal returns (uint256) {
        Vault storage vault = vaults[vaultId];
        return vault.issued.sub(vault.toBeRedeemed);
    }

    function redeemTokens(address vaultId, uint256 amount) internal {
        Vault storage vault = vaults[vaultId];
        vault.toBeRedeemed = vault.toBeRedeemed.sub(amount);
        vault.issued = vault.issued.sub(amount);
        emit RedeemTokens(vaultId, amount);
    }

    function issuableTokens(address vaultId) public view returns (uint256) {
        uint256 freeCollateral = ICollateral.getFreeCollateral(vaultId);
        return
            oracle.collateralToWrapped(
                freeCollateral.mul(100).div(SECURE_COLLATERAL_THRESHOLD)
            );
    }

    function issueTokens(address vaultId, uint256 amount) internal {
        Vault storage vault = vaults[vaultId];
        vault.issued = vault.issued.add(amount);
        vault.toBeIssued = vault.toBeIssued.sub(amount);
        emit IssueTokens(vaultId, amount);
    }

    function calculateCollateral(
        uint256 collateral,
        uint256 numerator,
        uint256 denominator
    ) internal returns (uint256 amount) {
        if (numerator == 0 && denominator == 0) {
            return collateral;
        }

        return collateral.mul(numerator).div(denominator);
    }

    function requestableToBeReplacedTokens(address vaultId)
        internal
        returns (uint256 amount)
    {
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");

        uint256 requestableIncrease = vault.issued.sub(vault.toBeRedeemed).sub(
            vault.toBeReplaced
        );

        return requestableIncrease;
    }

    function tryIncreaseToBeReplacedTokens(
        address vaultId,
        uint256 tokens,
        uint256 collateral
    ) internal returns (uint256, uint256) {
        Vault storage vault = vaults[vaultId];

        uint256 requestableIncrease = requestableToBeReplacedTokens(vaultId);

        require(
            tokens <= requestableIncrease,
            "Could not increase to-be-replaced tokens because it is more than issued amount"
        );

        vault.toBeReplaced = vault.toBeReplaced.add(tokens);
        vault.replaceCollateral = vault.replaceCollateral.add(collateral);

        emit IncreaseToBeReplacedTokens(vaultId, tokens);

        return (vault.toBeReplaced, vault.replaceCollateral);
    }

    function decreaseToBeReplacedTokens(address vaultId, uint256 tokens)
        internal
        returns (uint256, uint256)
    {
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");

        uint256 usedTokens = MathUpgradeable.min(vault.toBeReplaced, tokens);

        uint256 calculatedCollateral = calculateCollateral(
            vault.replaceCollateral,
            usedTokens,
            vault.toBeReplaced
        );
        uint256 usedCollateral = MathUpgradeable.min(
            vault.replaceCollateral,
            calculatedCollateral
        );

        vault.toBeReplaced = vault.toBeReplaced.sub(usedTokens);
        vault.replaceCollateral = vault.replaceCollateral.sub(usedCollateral);

        emit DecreaseToBeReplacedTokens(vaultId, usedTokens);

        return (usedTokens, usedCollateral);
    }

    function replaceTokens(
        address oldVaultId,
        address newVaultId,
        uint256 tokens,
        uint256 collateral
    ) internal {
        Vault storage oldVault = vaults[oldVaultId];
        Vault storage newVault = vaults[newVaultId];

        require(oldVault.btcPublicKeyX != 0, "vaultNotExist");
        require(newVault.btcPublicKeyX != 0, "vaultNotExist");

        // TODO: add liquidation functionality
        // if old_vault.data.is_liquidated()

        oldVault.issued = oldVault.issued.sub(tokens);
        newVault.issued = newVault.issued.add(tokens);

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

<<<<<<< HEAD
    uint256[45] private __gap;
=======
    function slashForToBeRedeemed(address vaultId, uint256 amount) private {
        Vault storage vault = vaults[vaultId];
        uint256 collateral = MathUpgradeable.min(vault.collateral, amount);
        vault.liquidatedCollateral = vault.liquidatedCollateral.add(collateral);
        // TODO: what to do with slashable collateral corresponding to to-be-redeemed tokens?
    }

    function slashToLiquidationVault(address vaultId, uint256 amount) private {
        Vault storage vault = vaults[vaultId];
        Vault storage liquidateVault = vaults[address(this)];
        liquidateVault.collateral = liquidateVault.collateral.add(amount);
        vault.collateral = vault.collateral.sub(amount);
        // slash collateral
        ICollateral.slashCollateral(vaultId, address(this), amount);
        ICollateral.lockCollateral(address(this), amount); // TODO; double check
    }

    function backedTokens(address vaultId) private returns (uint256) {
        Vault storage vault = vaults[vaultId];
        return vault.issued.add(vault.toBeIssued);
    }

    function getUsedCollateral(address vaultId) private returns (uint256) {
        Vault storage vault = vaults[vaultId];
        uint256 issuedTokens = backedTokens(vaultId);
        uint256 collateralForIssuedTokens = issuedTokens.mul(
            SECURE_COLLATERAL_THRESHOLD
        );
        return MathUpgradeable.min(vault.collateral, collateralForIssuedTokens);
    }

    function liquidate(address vaultId, address reporterId) private {
        Vault storage vault = vaults[vaultId];

        // pay the theft report reward to reporter

        // liquidate at most SECURE_THRESHOLD * collateral
        // liquidated collateral = collateral held for the issued + to be issued
        uint256 liquidatedCollateral = getUsedCollateral(vaultId);

        // collateral tokens = total backed tokens
        uint256 collateralTokens = backedTokens(vaultId);

        // liquidate collateral excluding to be redeemed =
        // liquidate collateral * (collateral tokens - to be redeemed tokens) / collateral tokens
        uint256 ratio = collateralTokens.sub(vault.toBeRedeemed).div(
            collateralTokens
        );
        uint256 liquidatedCollateralExcludingToBeRedeemed = liquidatedCollateral
            .mul(ratio);

        // collateral for to be redeemed = liquidated collateral - liquidate collateral excluding to be redeemed
        uint256 collateralForToBeRedeemed = liquidatedCollateral -
            liquidatedCollateralExcludingToBeRedeemed;

        // slash collateral for the to_be_redeemed tokens
        slashForToBeRedeemed(vaultId, collateralForToBeRedeemed);

        // slash collateral used for issued + to_be_issued to the liquidation vault
        slashToLiquidationVault(
            vaultId,
            liquidatedCollateralExcludingToBeRedeemed
        );

        // copy tokens to liquidation vault
        address liquidationVaultId = address(this);
        Vault storage liquidationVault = vaults[liquidationVaultId];

        // increase issued, to be issued, and to be redeemed tokens from vault to liquidationVault
        liquidationVault.issued = liquidationVault.issued.add(vault.issued);
        liquidationVault.toBeIssued = liquidationVault.toBeIssued.add(
            vault.toBeIssued
        );
        liquidationVault.toBeRedeemed = liquidationVault.toBeRedeemed.add(
            vault.toBeRedeemed
        );

        // clear the vault values
        vault.issued = 0;
        vault.toBeIssued = 0;
        vault.toBeRedeemed = 0;
    }

    /**
     * @dev Liquidate a vault by transferring all of its token balances to the liquidation vault.
     */
    function liquidateVault(address vaultId, address reporterId) internal {
        liquidate(vaultId, reporterId);
    }
>>>>>>> aa1afa3702664b42e1c72838a82d704760afdfc5
}
