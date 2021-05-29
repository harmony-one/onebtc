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
        uint256 indexed issue_id,
        address indexed requester,
        address indexed vault_id,
        uint256 amount,
        uint256 fee,
        address btc_address
    );
    event IssueComplete(
        uint256 indexed issude_id,
        address indexed requester,
        address indexed vault_id,
        uint256 amount,
        uint256 fee,
        address btc_address
    );
    event IssueCancel(
        uint256 indexed issude_id,
        address indexed requester,
        address indexed vault_id,
        uint256 amount,
        uint256 fee,
        address btc_address
    );
    mapping(address => mapping(uint256 => S_IssueRequest)) public issueRequests;

    function issueOneBTC(address receiver, uint256 amount) internal virtual;

    function register_deposit_address(address vault_id, uint256 issue_id)
        internal
        virtual
        returns (address);

    function get_issue_fee(
        uint256 /*amount_requested*/
    ) private pure returns (uint256) {
        return 0;
    }

    function get_issue_id(address user) private view returns (uint256) {
        //get_secure_id
        return
            uint256(
                keccak256(abi.encodePacked(user, blockhash(block.number - 1)))
            );
    }

    function get_issue_griefing_collateral(uint256 amount_btc)
        private
        returns (uint256)
    {
        return amount_btc;
    }

    function _request_issue(
        address payable requester,
        uint256 amount_requested,
        address vault_id,
        uint256 griefing_collateral
    ) internal {
        require(
            get_issue_griefing_collateral(amount_requested) <=
                griefing_collateral,
            "InsufficientCollateral"
        );
        uint256 issue_id = get_issue_id(requester);
        address btc_address = register_deposit_address(vault_id, issue_id);
        uint256 fee = get_issue_fee(amount_requested);
        uint256 amount_user = amount_requested - fee;
        S_IssueRequest storage request = issueRequests[requester][issue_id];
        require(request.status == RequestStatus.None, "invalid request");
        {
            request.vault = address(uint160(vault_id));
            request.opentime = block.timestamp;
            request.requester = requester;
            request.btc_address = btc_address;
            request.amount = amount_user;
            request.fee = fee;
            request.griefing_collateral = griefing_collateral;
            request.period = 2 days;
            request.btc_height = 0;
            request.status = RequestStatus.Pending;
        }
        ICollateral.lock_collateral(
            request.requester,
            request.griefing_collateral
        ); // ICollateral::
        emit IssueRequest(
            issue_id,
            requester,
            vault_id,
            amount_user,
            fee,
            btc_address
        );
    }

    function _execute_issue(
        address requester,
        uint256 issue_id,
        bytes memory _vout
    ) internal {
        S_IssueRequest storage request = issueRequests[requester][issue_id];
        require(
            request.status == RequestStatus.Pending,
            "request is completed"
        );
        uint256 amount_transferred =
            TxValidate.validate_transaction(
                _vout,
                0,
                request.btc_address,
                issue_id
            );
        if (amount_transferred != request.amount + request.fee) {
            // only the requester of the issue can execute payments with different amounts
            require(msg.sender == requestor, "InvalidExecutor");
            request.fee = get_issue_fee(amount_transferred);
            request.amount = amount_transferred - request.fee;
        }
        issueOneBTC(request.vault, request.fee);
        issueOneBTC(request.requester, amount_transferred);
        ICollateral.release_collateral(
            request.requester,
            request.griefing_collateral
        ); // ICollateral::
        request.status = RequestStatus.Completed;
        emit IssueComplete(
            issue_id,
            requester,
            request.vault,
            request.amount,
            request.fee,
            request.btc_address
        );
    }

    function _cancel_issue(address requester, uint256 issue_id) internal {
        S_IssueRequest storage request = issueRequests[requester][issue_id];
        require(
            request.status == RequestStatus.Pending,
            "request is completed"
        );
        require(
            block.timestamp > request.opentime + request.period,
            "TimeNotExpired"
        );
        request.status = RequestStatus.Cancelled;
        ICollateral.slash_collateral(
            request.requester,
            request.vault,
            request.griefing_collateral
        ); // ICollateral::
        emit IssueCancel(
            issue_id,
            requester,
            request.vault,
            request.amount,
            request.fee,
            request.btc_address
        );
    }
}
