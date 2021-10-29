// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import {BTCUtils} from "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";
import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import {Request} from "./Request.sol";
import {TxValidate} from "./TxValidate.sol";
import {ICollateral} from "./Collateral.sol";
import {VaultRegistry} from "./VaultRegistry.sol";

abstract contract Redeem is Initializable, VaultRegistry, Request {
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

    function getRedeemCollateral(uint256 amountBtc) private returns (uint256) {
        return amountBtc;
    }

    function getCurrentInclusionFee() private returns (uint256) {
        return 0;
    }

    function _requestRedeem(
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
            VaultRegistry.tryIncreaseToBeRedeemedTokens(vaultId, toBeBurnedBtc),
            "InsufficientTokensCommitted"
        );
        // TODO: decrease collateral
        RedeemRequest storage request = redeemRequests[requester][redeemId];
        require(request.status == RequestStatus.None, "invalid request");
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
        ICollateral.useCollateralInc(vaultId, request.amountOne);
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
            "request is completed"
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
        ICollateral.useCollateralDec(request.vault, request.amountOne);
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

    function _cancelRedeem(address requester, uint256 redeemId) internal {
        RedeemRequest storage request = redeemRequests[requester][redeemId];
        require(
            request.status == RequestStatus.Pending,
            "request is completed"
        );
        require(
            block.timestamp > request.opentime + request.period,
            "TimeNotExpired"
        );
        request.status = RequestStatus.Cancelled;
        releaseLockedOneBTC(request.requester, request.amountBtc + request.fee);

        ICollateral.useCollateralDec(request.vault, request.amountOne);
        ICollateral.slashCollateral(
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
