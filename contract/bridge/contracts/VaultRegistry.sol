// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import {ICollateral} from "./Collateral.sol";
import "./IExchangeRateOracle.sol";
import "./interface/IVaultRegistry.sol";
import "./interface/IVaultReward.sol";
import "./lib/VaultRegistryLib.sol";

abstract contract VaultRegistry is Initializable, ICollateral, IVaultRegistry {
    using SafeMathUpgradeable for uint256;

    mapping(address => Vault) public vaults;
    IExchangeRateOracle public oracle;
    // upgrade contract
    address public vaultReward;
    bool public isSetVaultReward;

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

    modifier onlyVaultReward() {
        require(msg.sender == vaultReward, "Only VaultReward");
        _;
    }

    function registerVault(uint256 btcPublicKeyX, uint256 btcPublicKeyY)
        external
        payable
    {
        address vaultId = msg.sender;
        VaultRegistryLib.registerVault(vaults[vaultId], btcPublicKeyX, btcPublicKeyY);
        lockAdditionalCollateral();
        emit RegisterVault(vaultId, msg.value, btcPublicKeyX, btcPublicKeyY);
    }

    function registerDepositAddress(address vaultId, uint256 issueId)
        internal
        returns (address)
    {
        requireVaultExistence(vaults[vaultId].btcPublicKeyX);
        return VaultRegistryLib.registerDepositAddress(vaults[vaultId], vaultId, issueId);
    }

    function insertVaultDepositAddress(
        address vaultId,
        uint256 btcPublicKeyX,
        uint256 btcPublicKeyY,
        uint256 replaceId
    ) internal returns (address) {
        requireVaultExistence(vaults[vaultId].btcPublicKeyX);
        return VaultRegistryLib.insertVaultDepositAddress(vaults[vaultId], btcPublicKeyX, btcPublicKeyY, replaceId);
    }

    function updatePublicKey(uint256 btcPublicKeyX, uint256 btcPublicKeyY)
        external
    {
        address vaultId = msg.sender;
        Vault storage vault = vaults[vaultId];
        requireVaultExistence(vault.btcPublicKeyX);
        vault.btcPublicKeyX = btcPublicKeyX;
        vault.btcPublicKeyY = btcPublicKeyY;
        emit VaultPublicKeyUpdate(vaultId, btcPublicKeyX, btcPublicKeyY);
    }

    function lockAdditionalCollateral() public payable {
        _lockAdditionalCollateral(msg.sender, msg.value);
    }

    function lockAdditionalCollateralFromVaultReward(address _vaultId) external override payable onlyVaultReward {
        require(block.timestamp < IVaultReward(vaultReward).getVaultLockExpireAt(_vaultId), "Vault was expired");

        _lockAdditionalCollateral(_vaultId, msg.value);
    }

    function _lockAdditionalCollateral(address _vaultId, uint256 _lockAmount) private {
        _updateVaultAccClaimableRewards(_vaultId);

        Vault storage vault = vaults[_vaultId];
        requireVaultExistence(vault.btcPublicKeyX);
        vault.collateral = vault.collateral.add(_lockAmount);
        ICollateral.lockCollateral(_vaultId, _lockAmount);
    }

    function withdrawCollateral(uint256 amount) external {
        require(IVaultReward(vaultReward).getVaultLockExpireAt(msg.sender) < block.timestamp, "Vault lock period is not expired");
        
        Vault storage vault = vaults[msg.sender];
        requireVaultExistence(vault.btcPublicKeyX);
        // is allowed to withdraw collateral
        require(
            amount <=
                getTotalCollateral(msg.sender).sub(
                    collateralForIssued(vault.issued.add(vault.toBeIssued))
                ),
            "Only unbacked collateral can be withdrawn"
        );
        vault.collateral = vault.collateral.sub(amount);
        ICollateral.releaseCollateral(msg.sender, amount);
    }

    function _updateVaultAccClaimableRewards(address _vaultId) internal {
        // update vault accClaimableRewards
        IVaultReward(vaultReward).updateVaultAccClaimableRewards(_vaultId);
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
        Vault memory vault = vaults[vaultId];
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
        return oracle.collateralToWrapped(freeCollateral.mul(100).div(150));
    }

    function collateralFor(uint256 amount) public view returns (uint256) {
        return oracle.wrappedToCollateral(amount);
    }

    function collateralForIssued(uint256 amount) public view returns (uint256) {
        return oracle.wrappedToCollateral(amount).mul(150).div(100);
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
    ) internal view returns (uint256 amount) {
        if (numerator == 0 && denominator == 0) {
            return collateral;
        }

        return collateral.mul(numerator).div(denominator);
    }

    // function requestableToBeReplacedTokens(address vaultId)
    //     internal
    //     returns (uint256 amount)
    // {
    //     Vault memory vault = vaults[vaultId];
    //     requireVaultExistence(vault.btcPublicKeyX);

    //     uint256 requestableIncrease = vault.issued.sub(vault.toBeRedeemed).sub(
    //         vault.toBeReplaced
    //     );

    //     return requestableIncrease;
    // }

    // function tryIncreaseToBeReplacedTokens(
    //     address vaultId,
    //     uint256 tokens,
    //     uint256 collateral
    // ) internal returns (uint256, uint256) {
    //     Vault storage vault = vaults[vaultId];

    //     uint256 requestableIncrease = requestableToBeReplacedTokens(vaultId);

    //     require(
    //         tokens <= requestableIncrease,
    //         "Could not increase to-be-replaced tokens because it is more than issued amount"
    //     );

    //     vault.toBeReplaced = vault.toBeReplaced.add(tokens);
    //     vault.replaceCollateral = vault.replaceCollateral.add(collateral);

    //     emit IncreaseToBeReplacedTokens(vaultId, tokens);

    //     return (vault.toBeReplaced, vault.replaceCollateral);
    // }

    // function decreaseToBeReplacedTokens(address vaultId, uint256 tokens)
    //     internal
    //     returns (uint256, uint256)
    // {
    //     Vault storage vault = vaults[vaultId];
    //     requireVaultExistence(vault.btcPublicKeyX);

    //     uint256 usedTokens = MathUpgradeable.min(vault.toBeReplaced, tokens);

    //     uint256 calculatedCollateral = calculateCollateral(
    //         vault.replaceCollateral,
    //         usedTokens,
    //         vault.toBeReplaced
    //     );
    //     uint256 usedCollateral = MathUpgradeable.min(
    //         vault.replaceCollateral,
    //         calculatedCollateral
    //     );

    //     vault.toBeReplaced = vault.toBeReplaced.sub(usedTokens);
    //     vault.replaceCollateral = vault.replaceCollateral.sub(usedCollateral);

    //     emit DecreaseToBeReplacedTokens(vaultId, usedTokens);

    //     return (usedTokens, usedCollateral);
    // }

    // function replaceTokens(
    //     address oldVaultId,
    //     address newVaultId,
    //     uint256 tokens,
    //     uint256 collateral
    // ) internal {
    //     Vault storage oldVault = vaults[oldVaultId];
    //     Vault storage newVault = vaults[newVaultId];

    //     requireVaultExistence(oldVault.btcPublicKeyX);
    //     requireVaultExistence(newVault.btcPublicKeyX);

    //     // TODO: add liquidation functionality
    //     // if old_vault.data.is_liquidated()

    //     oldVault.issued = oldVault.issued.sub(tokens);
    //     newVault.issued = newVault.issued.add(tokens);

    //     emit ReplaceTokens(oldVaultId, newVaultId, tokens, collateral);
    // }

    function tryDepositCollateral(address vaultId, uint256 amount) internal {
        Vault storage vault = vaults[vaultId];
        requireVaultExistence(vault.btcPublicKeyX);

        ICollateral.lockCollateral(vaultId, amount);
    }

    function slashForToBeRedeemed(address vaultId, uint256 amount) private {
        Vault storage vault = vaults[vaultId];
        uint256 collateral = MathUpgradeable.min(vault.collateral, amount);
        vault.liquidatedCollateral = vault.liquidatedCollateral.add(collateral);
        // TODO: what to do with slashable collateral corresponding to to-be-redeemed tokens? - users can redeem as long as to-be-redeemed request is not cancelled.
        // TODO: If to-be-redeemed request is not cancelled, the collateral corresonding to to-be-redeemed tokens will be slash and it will be transfered to the LiquidationVault so that users can redeem it on LiquidationVault, not old vault.
    }

    function slashToLiquidationVault(address vaultId, uint256 amount) private {
        Vault storage vault = vaults[vaultId];
        Vault storage liquidateVault = vaults[address(this)];
        liquidateVault.collateral = liquidateVault.collateral.add(amount);
        vault.collateral = vault.collateral.sub(amount);
        // slash collateral
        ICollateral.slashCollateral(vaultId, address(this), amount);
        ICollateral.lockCollateral(address(this), amount);
    }

    /**
     * @dev Liquidate a vault by transferring all of its token balances to the liquidation vault.
     */
    function liquidateVault(address vaultId, address reporterId) internal {
        _updateVaultAccClaimableRewards(vaultId);

        Vault storage vault = vaults[vaultId];

        // pay the theft report reward to reporter

        // liquidate at most SECURE_THRESHOLD * collateral
        // liquidated collateral = collateral held for the issued + to be issued
        uint256 issuedTokens = vault.issued.add(vault.toBeIssued);
        uint256 collateralForIssuedTokens = collateralForIssued(issuedTokens);
        uint256 liquidatedCollateral = MathUpgradeable.min(
            vault.collateral,
            collateralForIssuedTokens
        );

        // collateral tokens = total backed tokens
        uint256 collateralTokens = vault.issued.add(vault.toBeIssued);

        // liquidate collateral excluding to be redeemed =
        // liquidate collateral * (collateral tokens - to be redeemed tokens) / collateral tokens
        uint256 ratio = (collateralTokens.sub(vault.toBeRedeemed)).div(
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

        // TODO: toBeRedeemed will be kept as long is the to-be-redeemed request is not cancelled.
        // liquidationVault.toBeRedeemed = liquidationVault.toBeRedeemed.add(
        //     vault.toBeRedeemed
        // );

        // clear the vault values
        vault.issued = 0;
        vault.toBeIssued = 0;

        // TODO: toBeRedeemed will be kept as long is the to-be-redeemed request is not cancelled.
        // vault.toBeRedeemed = 0;
    }

    function requireVaultExistence(uint256 _vaultBtcPublicKeyX) private {
        require(_vaultBtcPublicKeyX != 0, "Vault does not exist");
    }

    function getVault(address _vaultId) external view override returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        Vault memory vault = vaults[_vaultId];

        return (
            vault.btcPublicKeyX,
            vault.btcPublicKeyY,
            vault.collateral,
            vault.issued,
            vault.toBeIssued,
            vault.toBeRedeemed,
            vault.replaceCollateral,
            vault.toBeReplaced,
            vault.liquidatedCollateral
        );
    }

    function setVaultRewardAddress(address _vaultReward) external {
        require(!isSetVaultReward, "VaultReward already set");
        isSetVaultReward = true;

        vaultReward = _vaultReward;
    }

    uint256[44] private __gap;
}
