// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import {BTCUtils} from "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";
import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import {Request} from "./Request.sol";
import {TxValidate} from "./TxValidate.sol";
import {ICollateral} from "./Collateral.sol";
import {VaultRegistry} from "./VaultRegistry.sol";

abstract contract Replace is VaultRegistry, Request {
    //    using BTCUtils for bytes;
    //    using BytesLib for bytes;

    event RequestReplace(
        address indexed oldVault,
        uint256 btcAmount,
        uint256 griefingCollateral
    );

    event WithdrawReplace(
        address indexed oldVault,
        uint256 withdrawnTokens,
        uint256 withdrawnGriefingCollateral
    );

    event AcceptReplace(
        uint256 indexed replaceId,
        address indexed oldVault,
        address indexed newVault,
        uint256 btcAmount,
        uint256 collateral,
        address btcAddress
    );

    event ExecuteReplace(
        uint256 indexed replaceId,
        address indexed oldVault,
        address indexed newVault
    );

    event CancelReplace(
        uint256 indexed replaceId,
        address indexed oldVault,
        address indexed newVault,
        uint256 slashedCollateral
    );

    mapping(uint256 => ReplaceRequest) public replaceRequests;

    function getReplaceGriefingCollateral(uint256 amountBtc)
        private
        returns (uint256)
    {
        return collateralFor(amountBtc).mul(5).div(100); // 5% replace griefing collateral
    }

    function _requestReplace(
        address payable oldVaultId,
        uint256 btcAmount,
        uint256 griefingCollateral
    ) internal {
        require(
            msg.sender == oldVaultId,
            "Sender should be the owner of this Vault"
        );

        // The oldVault MUST NOT be banned
        Vault storage oldVault = vaults[oldVaultId];
        require(
            oldVault.liquidatedCollateral == 0,
            "Cannot replace a banned vault"
        );

        // vault.issued - vault.toBeRedeemed
        uint256 requestableTokens = VaultRegistry.requestableToBeReplacedTokens(
            oldVaultId
        );

        // cap to maximum replaceable token
        require(btcAmount <= requestableTokens, "exceeds eligible replacement");

        // 5% griefing is calculated on collateral?
        (
            uint256 totalToBeReplaced,
            uint256 totalGriefingCollateral
        ) = VaultRegistry.tryIncreaseToBeReplacedTokens(
                oldVaultId,
                btcAmount,           // btc to replace
                griefingCollateral       // one's equivalent
            );

        // check that total-to-be-replaced is above the minimum. NOTE: this means that even
        // a request with amount=0 is valid, as long the _total_ is above DUST. This might
        // be the case if the vault just wants to increase the griefing collateral, for example.
        uint256 dustValue = 0;
        require(totalToBeReplaced > dustValue, "Amount below dust amount");

        // check that that the total griefing collateral is sufficient to back the total to-be-replaced amount
        require(
            getReplaceGriefingCollateral(totalToBeReplaced) <=
                totalGriefingCollateral,
            "Insufficient collateral"
        );

        // Lock the oldVault’s griefing collateral. Note that this directly locks the amount
        ICollateral.lockCollateral(oldVaultId, griefingCollateral);

        emit RequestReplace(
            oldVaultId,
            btcAmount,
            griefingCollateral
        );
    }

    function _withdrawReplace(address oldVaultId, uint256 btcAmount) internal {
        require(msg.sender == oldVaultId, "Sender should be old vault owner");
        // TODO: SECURITY CHECK (The oldVault MUST NOT be banned)
        // already checked by requestReplace, unless we care about that small window.

        (uint256 withdrawnTokens, uint256 toWithdrawCollateral) = VaultRegistry
            .decreaseToBeReplacedTokens(oldVaultId, btcAmount);

        ICollateral.releaseCollateral(oldVaultId, toWithdrawCollateral);

        require(withdrawnTokens != 0, "Withdraw tokens is zero");

        emit WithdrawReplace(oldVaultId, withdrawnTokens, toWithdrawCollateral);
    }

    function _acceptReplace(
        address oldVaultId,
        address newVaultId,
        uint256 btcAmount,
        uint256 collateral,
        uint256 btcPublicKeyX,
        uint256 btcPublicKeyY
    ) internal {
        require(msg.sender == newVaultId, "Sender should be new vault owner");
        require(
            oldVaultId != newVaultId,
            "Old vault must not be equal to new vault"
        );

        require(msg.value == collateral, "incorrect amount sent");
        
        // TODO: The newVault’s free balance MUST be enough to lock collateral.
        // TODO: SECURITY CHECK (The oldVault, newVault MUST NOT be banned)

        Vault storage oldVault = VaultRegistry.vaults[oldVaultId];
        Vault storage newVault = VaultRegistry.vaults[newVaultId];

        require(oldVault.btcPublicKeyX != 0, "Vault does not exist");
        require(newVault.btcPublicKeyX != 0, "Vault does not exist");

        // decrease old-vault's to-be-replaced tokens
        (uint256 redeemableTokens, uint256 griefingCollateral) = VaultRegistry
            .decreaseToBeReplacedTokens(oldVaultId, btcAmount);

        // TODO: check amount_btc is above the minimum
        uint256 dustValue = 0;
        require(redeemableTokens >= dustValue, "Amount below dust amount");

        // Calculate and lock the new-vault's additional collateral
        uint256 actualNewVaultCollateral = VaultRegistry.calculateCollateral(
            collateral,
            redeemableTokens,
            btcAmount
        );

        VaultRegistry.tryDepositCollateral(
            newVaultId,
            actualNewVaultCollateral
        );

        // increase old-vault's to-be-redeemed tokens - this should never fail
        VaultRegistry.tryIncreaseToBeRedeemedTokens(
            oldVaultId,
            redeemableTokens
        );

        // increase new-vault's to-be-issued tokens - this will fail if there is insufficient collateral
        VaultRegistry.tryIncreaseToBeIssuedTokens(newVaultId, redeemableTokens);
        ICollateral.useCollateralInc(newVaultId, VaultRegistry.collateralForIssued(redeemableTokens));

        uint256 replaceId = uint256(
            keccak256(abi.encodePacked(oldVaultId, blockhash(block.number - 1)))
        );

        address btcAddress = VaultRegistry.insertVaultDepositAddress(
            newVaultId,
            btcPublicKeyX,
            btcPublicKeyY,
            replaceId
        );

        ReplaceRequest storage replace = replaceRequests[replaceId];

        require(
            replace.status == RequestStatus.None,
            "This replace already created"
        );

        {
            replace.oldVault = address(uint160(oldVaultId));
            replace.newVault = address(uint160(newVaultId));
            replace.amount = redeemableTokens;
            replace.btcAddress = btcAddress;
            replace.collateral = actualNewVaultCollateral;
            replace.griefingCollateral = griefingCollateral;
            replace.period = 2 days;
            replace.btcHeight = 0;
            replace.status = RequestStatus.Pending;
        }

        emit AcceptReplace(
            replaceId,
            replace.oldVault,
            replace.newVault,
            replace.amount,
            replace.collateral,
            replace.btcAddress
        );
    }

    function _executeReplace(uint256 replaceId, bytes memory _vout) internal {
        // Retrieve the ReplaceRequest as per the replaceId parameter from Vaults in the VaultRegistry
        ReplaceRequest storage replace = replaceRequests[replaceId];
        require(
            replace.status == RequestStatus.Pending,
            "Wrong request status"
        );

        // // NOTE: anyone can call this method provided the proof is correct
        address oldVaultId = replace.oldVault;
        address newVaultId = replace.newVault;

        uint256 amountTransferred = TxValidate.validateTransaction(
            _vout,
            0,
            replace.btcAddress,
            replaceId,
            0
        );

        require(
            amountTransferred >= replace.amount,
            "Transaction contains wrong btc amount"
        );

        // decrease old-vault's issued & to-be-redeemed tokens, and
        // change new-vault's to-be-issued tokens to issued tokens
        VaultRegistry.replaceTokens(
            oldVaultId,
            newVaultId,
            replace.amount,
            replace.collateral
        );

        VaultRegistry.decreaseToBeRedeemedTokens(
            oldVaultId,
            replace.amount
        );

        // if the old vault has not been liquidated, give it back its griefing collateral
        ICollateral.releaseCollateral(oldVaultId, replace.griefingCollateral);
        ICollateral.useCollateralDec(oldVaultId, VaultRegistry.collateralForIssued(replace.amount));

        // Emit ExecuteReplace event.
        emit ExecuteReplace(replaceId, oldVaultId, newVaultId);

        // Remove replace request
        replace.status = RequestStatus.Completed;
    }

    //uint256[45] private __gap;
}
