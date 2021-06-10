// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
import {BTCUtils} from "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";
import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import {S_IssueRequest, RequestStatus} from "./Request.sol";
import {TxValidate} from "./TxValidate.sol";
import {ICollateral} from "./Collateral.sol";

abstract contract Issue is ICollateral {
    using BTCUtils for bytes;
    using BytesLib for bytes;

    event IssueRequest(
        uint256 indexed issueId,
        address indexed requester,
        address indexed vaultId,
        uint256 amount,
        uint256 fee,
        address btcAddress
    );
    event IssueComplete(
        uint256 indexed issudeId,
        address indexed requester,
        address indexed vaultId,
        uint256 amount,
        uint256 fee,
        address btcAddress
    );
    event IssueCancel(
        uint256 indexed issudeId,
        address indexed requester,
        address indexed vaultId,
        uint256 amount,
        uint256 fee,
        address btcAddress
    );
    mapping(address => mapping(uint256 => S_IssueRequest)) public issueRequests;

    function issueOneBTC(address receiver, uint256 amount) internal virtual;

    function registerDepositAddress(address vaultId, uint256 issueId)
        internal
        virtual
        returns (address);

    function getIssueFee(
        uint256 amountRequested
    ) private pure returns (uint256) {
        return amountRequested*2/1000;
    }

    function getIssueId(address user) private view returns (uint256) {
        //getSecureId
        return
            uint256(
                keccak256(abi.encodePacked(user, blockhash(block.number - 1)))
            );
    }

    function getIssueGriefingCollateral(uint256 amountBtc)
        private
        returns (uint256)
    {
        return amountBtc;
    }

    function _requestIssue(
        address payable requester,
        uint256 amountRequested,
        address vaultId,
        uint256 griefingCollateral
    ) internal {
        require(
            getIssueGriefingCollateral(amountRequested) <=
                griefingCollateral,
            "InsufficientCollateral"
        );
        uint256 issueId = getIssueId(requester);
        address btcAddress = registerDepositAddress(vaultId, issueId);
        uint256 fee = getIssueFee(amountRequested);
        uint256 amountUser = amountRequested - fee;
        S_IssueRequest storage request = issueRequests[requester][issueId];
        require(request.status == RequestStatus.None, "invalid request");
        {
            request.vault = address(uint160(vaultId));
            request.opentime = block.timestamp;
            request.requester = requester;
            request.btcAddress = btcAddress;
            request.amount = amountUser;
            request.fee = fee;
            request.griefingCollateral = griefingCollateral;
            request.period = 2 days;
            request.btcHeight = 0;
            request.status = RequestStatus.Pending;
        }
        ICollateral.lockCollateral(
            request.requester,
            request.griefingCollateral
        ); // ICollateral::
        emit IssueRequest(
            issueId,
            requester,
            vaultId,
            amountUser,
            fee,
            btcAddress
        );
    }

    function _executeIssue(
        address requester,
        uint256 issueId,
        bytes memory _vout
    ) internal {
        S_IssueRequest storage request = issueRequests[requester][issueId];
        require(
            request.status == RequestStatus.Pending,
            "request is completed"
        );
        uint256 amountTransferred =
            TxValidate.validateTransaction(
                _vout,
                0,
                request.btcAddress,
                issueId
            );
        if (amountTransferred != request.amount + request.fee) {
            // only the requester of the issue can execute payments with different amounts
            require(msg.sender == requester, "InvalidExecutor");
            request.fee = getIssueFee(amountTransferred);
            request.amount = amountTransferred - request.fee;
        }
        issueOneBTC(request.vault, request.fee);
        issueOneBTC(request.requester, request.amount);
        ICollateral.releaseCollateral(
            request.requester,
            request.griefingCollateral
        ); // ICollateral::
        request.status = RequestStatus.Completed;
        emit IssueComplete(
            issueId,
            requester,
            request.vault,
            request.amount,
            request.fee,
            request.btcAddress
        );
    }

    function _cancelIssue(address requester, uint256 issueId) internal {
        S_IssueRequest storage request = issueRequests[requester][issueId];
        require(
            request.status == RequestStatus.Pending,
            "request is completed"
        );
        require(
            block.timestamp > request.opentime + request.period,
            "TimeNotExpired"
        );
        request.status = RequestStatus.Cancelled;
        ICollateral.slashCollateral(
            request.requester,
            request.vault,
            request.griefingCollateral
        ); // ICollateral::
        emit IssueCancel(
            issueId,
            requester,
            request.vault,
            request.amount,
            request.fee,
            request.btcAddress
        );
    }
}
