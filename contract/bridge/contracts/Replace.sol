// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import {BTCUtils} from "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";
import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import {Request} from "./Request.sol";
import {TxValidate} from "./TxValidate.sol";
import "./IVaultRegistry.sol";

abstract contract Replace is Request {
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

    function getReplaceId(address user) private view returns (uint256) {
        //getSecureId
        return
            uint256(
                keccak256(abi.encodePacked(user, blockhash(block.number - 1)))
            );
    }

    function getReplaceBtcDustValue() private returns (uint256) {
        // TODO
        return 0;
    }

    function getReplaceGriefingCollateral(uint256 amountBtc)
        private
        returns (uint256)
    {
        // TODO
        return amountBtc;
    }

    function _requestReplace(
        IVaultRegistry vaultRegistry,
        address payable oldVaultId,
        uint256 btcAmount,
        uint256 griefingCollateral
    ) internal {
        require(
            msg.sender == oldVaultId,
            "Sender should be the owner of this Vault"
        );

        // TODO: SECURITY CHECK (The oldVault MUST NOT be banned)

        uint256 requestableTokens = vaultRegistry.requestableToBeReplacedTokens(
            oldVaultId
        );
        uint256 toBeReplacedIncrease = MathUpgradeable.min(requestableTokens, btcAmount);

        uint256 replaceCollateralIncrease = griefingCollateral;

        if (btcAmount > 0) {
            replaceCollateralIncrease = vaultRegistry.calculateCollateral(
                griefingCollateral,
                toBeReplacedIncrease,
                btcAmount
            );
        }

        (
            uint256 totalToBeReplaced,
            uint256 totalGriefingCollateral
        ) = vaultRegistry.tryIncreaseToBeReplacedTokens(
                oldVaultId,
                toBeReplacedIncrease,
                replaceCollateralIncrease
            );

        // check that total-to-be-replaced is above the minimum. NOTE: this means that even
        // a request with amount=0 is valid, as long the _total_ is above DUST. This might
        // be the case if the vault just wants to increase the griefing collateral, for example.
        uint256 dustValue = getReplaceBtcDustValue();
        require(totalToBeReplaced >= dustValue, "Amount below dust amount");

        // check that that the total griefing collateral is sufficient to back the total to-be-replaced amount
        require(
            getReplaceGriefingCollateral(totalToBeReplaced) <=
                totalGriefingCollateral,
            "Insufficient collateral"
        );

        // Lock the oldVault’s griefing collateral. Note that this directly locks the amount
        vaultRegistry.lockCollateral(oldVaultId, replaceCollateralIncrease);

        emit RequestReplace(
            oldVaultId,
            toBeReplacedIncrease,
            replaceCollateralIncrease
        );
    }

    function _withdrawReplace(IVaultRegistry vaultRegistry, address oldVaultId, uint256 btcAmount) internal {
        require(msg.sender == oldVaultId, "Sender should be old vault owner");
        // TODO: SECURITY CHECK (The oldVault MUST NOT be banned)

        (uint256 withdrawnTokens, uint256 toWithdrawCollateral) = vaultRegistry
            .decreaseToBeReplacedTokens(oldVaultId, btcAmount);

        vaultRegistry.releaseCollateral(oldVaultId, toWithdrawCollateral);

        require(withdrawnTokens == 0, "Withdraw tokens is zero");

        emit WithdrawReplace(oldVaultId, withdrawnTokens, toWithdrawCollateral);
    }

    function _acceptReplace(
        IVaultRegistry vaultRegistry,
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

        // TODO: The newVault’s free balance MUST be enough to lock collateral.
        // TODO: SECURITY CHECK (The oldVault, newVault MUST NOT be banned)

        (uint256 oldVaultBtcPublicKeyX,,,,,,,,) = vaultRegistry.vaults(oldVaultId);
        (uint256 newVaultBtcPublicKeyX,,,,,,,,) = vaultRegistry.vaults(newVaultId);

        require(oldVaultBtcPublicKeyX != 0, "Vault does not exist");
        require(newVaultBtcPublicKeyX != 0, "Vault does not exist");

        // decrease old-vault's to-be-replaced tokens
        (uint256 redeemableTokens, uint256 griefingCollateral) = vaultRegistry
            .decreaseToBeReplacedTokens(oldVaultId, btcAmount);

        // TODO: check amount_btc is above the minimum
        uint256 dustValue = getReplaceBtcDustValue();
        require(redeemableTokens >= dustValue, "Amount below dust amount");

        // Calculate and lock the new-vault's additional collateral
        uint256 actualNewVaultCollateral = vaultRegistry.calculateCollateral(
            collateral,
            redeemableTokens,
            btcAmount
        );

        vaultRegistry.tryDepositCollateral(
            newVaultId,
            actualNewVaultCollateral
        );

        // increase old-vault's to-be-redeemed tokens - this should never fail
        vaultRegistry.tryIncreaseToBeRedeemedTokens(
            oldVaultId,
            redeemableTokens
        );

        // increase new-vault's to-be-issued tokens - this will fail if there is insufficient collateral
        vaultRegistry.tryIncreaseToBeIssuedTokens(newVaultId, redeemableTokens);

        uint256 replaceId = getReplaceId(oldVaultId);

        address btcAddress = vaultRegistry.insertVaultDepositAddress(
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

    function _executeReplace(IVaultRegistry vaultRegistry, uint256 replaceId, bytes memory _vout) internal {
        // Retrieve the ReplaceRequest as per the replaceId parameter from Vaults in the VaultRegistry
        ReplaceRequest storage replace = replaceRequests[replaceId];
        require(
            replace.status == RequestStatus.Pending,
            "Wrong request status"
        );

        // NOTE: anyone can call this method provided the proof is correct
        address oldVaultId = replace.oldVault;
        address newVaultId = replace.newVault;

        uint256 amountTransferred = TxValidate.validateTransaction(
            _vout,
            0,
            replace.btcAddress,
            replaceId
        );

        require(
            amountTransferred >= replace.amount,
            "Transaction contains wrong btc amount"
        );

        // decrease old-vault's issued & to-be-redeemed tokens, and
        // change new-vault's to-be-issued tokens to issued tokens
        vaultRegistry.replaceTokens(
            oldVaultId,
            newVaultId,
            replace.amount,
            replace.collateral
        );

        // if the old vault has not been liquidated, give it back its griefing collateral
        vaultRegistry.releaseCollateral(oldVaultId, replace.griefingCollateral);

        // Emit ExecuteReplace event.
        emit ExecuteReplace(replaceId, oldVaultId, newVaultId);

        // Remove replace request
        {
            replace.status = RequestStatus.Completed;
        }
    }

    uint256[45] private __gap;
}
