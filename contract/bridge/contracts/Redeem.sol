// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {BTCUtils} from "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";
import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import {Request} from "./Request.sol";
import {TxValidate} from "./TxValidate.sol";
import "./IVaultRegistry.sol";

abstract contract Redeem is Request {
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

    function getRedeemFee(
        uint256 /*amountRequested*/
    ) private pure returns (uint256) {
        return 0;
    }

    function getRedeemId(address user) private view returns (uint256) {
        //getSecureId
        return
            uint256(
                keccak256(abi.encodePacked(user, blockhash(block.number - 1)))
            );
    }

    function getRedeemCollateral(uint256 amountBtc) private pure returns (uint256) {
        return amountBtc;
    }

    function getCurrentInclusionFee() private pure returns (uint256) {
        return 0;
    }

    function _requestRedeem(
        IVaultRegistry vaultRegistry,
        address requester,
        uint256 amountOneBtc,
        address btcAddress,
        address vaultId
    ) internal {
        lockOneBTC(requester, amountOneBtc);
        uint256 feeOneBtc = getRedeemFee(amountOneBtc);
        uint256 inclusionFee = getCurrentInclusionFee();
        uint256 toBeBurnedBtc = amountOneBtc - feeOneBtc;
        uint256 redeemAmountOneBtc = toBeBurnedBtc - inclusionFee;
        uint256 redeemId = getRedeemId(requester);

        require(
            vaultRegistry.tryIncreaseToBeRedeemedTokens(vaultId, toBeBurnedBtc),
            "Insufficient tokens committed"
        );
        // TODO: decrease collateral
        RedeemRequest storage request = redeemRequests[requester][redeemId];
        require(request.status == RequestStatus.None, "Invalid request");
        {
            request.vault = vaultId;
            request.opentime = block.timestamp;
            request.period = 2 days;
            request.fee = feeOneBtc;
            request.transferFeeBtc = inclusionFee;
            request.amountBtc = redeemAmountOneBtc;
            //request.premiumOne
            request.amountOne = getRedeemCollateral(redeemAmountOneBtc);
            request.requester = requester;
            request.btcAddress = btcAddress;
            //request.btcHeight
            request.status = RequestStatus.Pending;
        }
        vaultRegistry.useCollateralInc(vaultId, request.amountOne);
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
        IVaultRegistry vaultRegistry,
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
            redeemId
        );
        burnLockedOneBTC(request.amountBtc);
        releaseLockedOneBTC(request.vault, request.fee);
        request.status = RequestStatus.Completed;
        vaultRegistry.useCollateralDec(request.vault, request.amountOne);
        vaultRegistry.redeemTokens(
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

    function _cancelRedeem(IVaultRegistry vaultRegistry, address requester, uint256 redeemId) internal {
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
        releaseLockedOneBTC(request.requester, request.amountBtc + request.fee);

        vaultRegistry.useCollateralDec(request.vault, request.amountOne);
        vaultRegistry.slashCollateral(
            request.vault,
            request.requester,
            request.amountOne
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
