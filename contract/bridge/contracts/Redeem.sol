// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
import {BTCUtils} from "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";
import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import {S_RedeemRequest, RequestStatus} from "./Request.sol";
import {TxValidate} from "./TxValidate.sol";
import {ICollateral} from "./Collateral.sol";

abstract contract Redeem is ICollateral {
    using BTCUtils for bytes;
    using BytesLib for bytes;

    mapping(address=>mapping(uint256=>S_RedeemRequest)) public redeemRequests;

    event RedeemRequest(uint256 indexed redeem_id, address indexed requester, address indexed vault_id, uint256 amount, uint256 fee, address btc_address);
    event RedeemComplete(uint256 indexed redeem_id, address indexed requester, address indexed vault_id, uint256 amount, uint256 fee, address btc_address);
    event RedeemCancel(uint256 indexed redeem_id, address indexed requester, address indexed vault_id, uint256 amount, uint256 fee, address btc_address);
    function lockOneBTC(address from, uint256 amount) internal virtual;
    function burnLockedOneBTC(uint256 amount) internal virtual;
    function releaseLockedOneBTC(address receiver, uint256 amount) internal virtual;

    function get_redeem_fee(uint256 /*amount_requested*/) private pure returns(uint256) {
        return 0;
    }

    function get_redeem_id(address user) private view returns(uint256) { //get_secure_id
        return uint256(keccak256(abi.encodePacked(user, blockhash(block.number-1))));
    }

    function get_redeem_collateral(uint256 amount_btc) private returns(uint256) {
        return amount_btc;
    }

    function _request_redeem(address requester, uint256 amount_one_btc, address btc_address, address vault_id) internal {
        lockOneBTC(requester, amount_one_btc);
        uint256 fee_one_btc = get_redeem_fee(amount_one_btc);
        uint256 redeem_amount_one_btc = amount_one_btc - fee_one_btc;
        uint256 redeem_id = get_redeem_id(requester);
        // TODO: decrease collateral
        S_RedeemRequest storage request = redeemRequests[requester][redeem_id];
        require(request.status == RequestStatus.None, "invalid request");
        {
            request.vault = vault_id;
            request.opentime = block.timestamp;
            request.period = 2 days;
            request.fee = fee_one_btc;
            request.amount_btc = redeem_amount_one_btc;
            //request.premium_one
            request.amount_one = get_redeem_collateral(redeem_amount_one_btc);
            request.requester = requester;
            request.btc_address = btc_address;
            //request.btc_height
            request.status = RequestStatus.Pending;
        }
        ICollateral.use_collateral_inc(vault_id, request.amount_one);
        emit RedeemRequest(redeem_id, requester, vault_id, request.amount_btc, request.fee, request.btc_address);
    }

    function _execute_redeem(address requester, uint256 redeem_id, bytes memory _vout) internal {
        S_RedeemRequest storage request = redeemRequests[requester][redeem_id];
        require(request.status == RequestStatus.Pending, "request is completed");
        TxValidate.validate_transaction(_vout, request.amount_btc, request.btc_address, redeem_id);
        burnLockedOneBTC(request.amount_btc);
        releaseLockedOneBTC(request.vault, request.fee);
        request.status = RequestStatus.Completed;
        ICollateral.use_collateral_dec(request.vault, request.amount_one);
        emit RedeemComplete(redeem_id, requester, request.vault, request.amount_btc, request.fee, request.btc_address);
    }

    function _cancel_redeem(address requester, uint256 redeem_id) internal {
        S_RedeemRequest storage request = redeemRequests[requester][redeem_id];
        require(request.status == RequestStatus.Pending, "request is completed");
        require(block.timestamp > request.opentime + request.period, "TimeNotExpired");
        request.status = RequestStatus.Cancelled;
        releaseLockedOneBTC(request.requester, request.amount_btc + request.fee);

        ICollateral.use_collateral_dec(request.vault, request.amount_one);
        ICollateral.slash_collateral(request.vault, request.requester, request.amount_one);
        emit RedeemCancel(redeem_id, requester, request.vault, request.amount_btc, request.fee, request.btc_address);
    }
}