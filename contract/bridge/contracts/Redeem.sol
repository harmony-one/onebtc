// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {BTCUtils} from "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";
import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import {Request} from "./Request.sol";
import {TxValidate} from "./TxValidate.sol";
import {ICollateral} from "./Collateral.sol";
import {VaultRegistry} from "./VaultRegistry.sol";

abstract contract Redeem is VaultRegistry, Request {
    using BTCUtils for bytes;
    using BytesLib for bytes;

    mapping(address => mapping(uint256 => RedeemRequest)) public redeemRequests;

    event RedeemRequested(
        uint256 indexed redeemId,
        address indexed requester,
        address indexed vaultId,
        uint256 amount,
        uint256 fee,
        address btcAddress
    );

    event RedeemCompleted(
        uint256 indexed redeemId,
        address indexed requester,
        address indexed vaultId,
        uint256 amount,
        uint256 fee,
        address btcAddress
    );

    event RedeemCanceled(
        uint256 indexed redeemId,
        address indexed requester,
        address indexed vaultId,
        uint256 amount,
        uint256 fee,
        address btcAddress
    );

    function lockOneBTC(address from, uint256 amount) internal virtual;

    function burnLockedOneBTC(uint256 amount) internal virtual;

    function releaseLockedOneBTC(address receiver, uint256 amount)
        internal
        virtual;

    function _requestRedeem(
        address requester,
        uint256 amountOneBtc,
        address btcAddress,
        address vaultId
    ) internal {
        lockOneBTC(requester, amountOneBtc);
        uint256 feeOneBtc = amountOneBtc.mul(5).div(1000); //0.5%
        uint256 inclusionFee = 0;
        uint256 toBeBurnedBtc = amountOneBtc - feeOneBtc;
        uint256 redeemAmountOneBtc = toBeBurnedBtc - inclusionFee;
        uint256 redeemId = uint256(
            keccak256(abi.encodePacked(requester, blockhash(block.number - 1)))
        );

        require(
            VaultRegistry.tryIncreaseToBeRedeemedTokens(vaultId, toBeBurnedBtc),
            "Insufficient tokens committed"
        );
        RedeemRequest storage request = redeemRequests[requester][redeemId];
        require(request.status == RequestStatus.None, "Invalid request");
        {
            request.vault = vaultId;
            request.opentime = block.timestamp;
            request.period = 2 days;
            request.fee = feeOneBtc;
            request.transferFeeBtc = inclusionFee;
            request.amountBtc = redeemAmountOneBtc;
            request.requester = requester;
            request.btcAddress = btcAddress;
            request.status = RequestStatus.Pending;
        }
        emit RedeemRequested(
            redeemId,
            requester,
            vaultId,
            request.amountBtc,
            request.fee,
            request.btcAddress
        );
    }

    function _executeRedeem(
        address requester,
        uint256 redeemId,
        bytes memory _vout
    ) internal {
        RedeemRequest storage request = redeemRequests[requester][redeemId];
        require(
            request.status == RequestStatus.Pending,
            "Request is already completed"
        );
        TxValidate.validateTransaction(
            _vout,
            request.amountBtc,
            request.btcAddress,
            redeemId,
            0
        );
        burnLockedOneBTC(request.amountBtc);
        releaseLockedOneBTC(request.vault, request.fee);
        request.status = RequestStatus.Completed;
        // release the collateral for redeemed btc
        ICollateral.useCollateralDec(
            request.vault,
            VaultRegistry.collateralFor(request.amountBtc)
        );
        VaultRegistry.redeemTokens(
            request.vault,
            request.amountBtc + request.transferFeeBtc
        );
        emit RedeemCompleted(
            redeemId,
            requester,
            request.vault,
            request.amountBtc,
            request.fee,
            request.btcAddress
        );
    }

    function _cancelRedeem(
        address requester,
        uint256 redeemId,
        bool reimburse
    ) internal {
        RedeemRequest storage request = redeemRequests[requester][redeemId];
        require(
            request.status == RequestStatus.Pending,
            "Request is already completed"
        );
        require(
            block.timestamp > request.opentime + request.period,
            "Time not expired"
        );
        request.status = RequestStatus.Cancelled;
        uint256 total = request.amountBtc + request.fee;
        if (reimburse) {
            uint256 slashCollateral = VaultRegistry.collateralFor(total);
            uint256 punishmentFee = slashCollateral.mul(10).div(100); // 10% punishment fee
            uint256 totalSlash = slashCollateral.add(punishmentFee);
            ICollateral.useCollateralDec(request.vault, totalSlash);
            ICollateral.slashCollateral(
                request.vault,
                request.requester,
                totalSlash
            );
        } else {
            releaseLockedOneBTC(request.requester, total);
        }
        VaultRegistry.decreaseToBeRedeemedTokens(
            request.vault,
            request.amountBtc + request.transferFeeBtc
        );
        emit RedeemCanceled(
            redeemId,
            requester,
            request.vault,
            request.amountBtc,
            request.fee,
            request.btcAddress
        );
    }

    uint256[45] private __gap;
}
