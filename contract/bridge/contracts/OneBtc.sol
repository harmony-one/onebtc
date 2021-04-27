// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ValidateSPV} from "@interlay/bitcoin-spv-sol/contracts/ValidateSPV.sol";
import {TransactionUtils} from "./TransactionUtils.sol";
import {Issue} from "./Issue.sol";
import {Redeem} from "./Redeem.sol";
import {IRelay} from "./IRelay.sol";
import {VaultRegistry} from "./VaultRegistry.sol";

contract OneBtc is ERC20,Issue,Redeem,VaultRegistry {

    IRelay public realy;
    constructor(IRelay _relay) ERC20("OneBtc", "OneBtc") public {
        _setupDecimals(18);
        realy = _relay;
    }

    function verifyTx(
        bytes calldata merkle_proof, bytes calldata raw_tx,
        uint64 heightAndIndex, bytes calldata header
    ) private returns(bytes memory) {
        bytes32 tx_id = raw_tx.hash256();
        realy.verifyTx(uint32(heightAndIndex>>32), heightAndIndex&type(uint32).max, tx_id, header, merkle_proof, 6, true);
        TransactionUtils.Transaction memory btcTx = TransactionUtils.extractTx(raw_tx);
        require(btcTx.locktime == 0, "locktime must zero!");
        // check version?
        // btcTx.version
        return btcTx.vouts;
    }

    function request_issue(uint256 amount_requested, address vault_id) external payable {
        Issue._request_issue(msg.sender, amount_requested, vault_id, msg.value);
    }

    function execute_issue(
        address requester, uint256 issue_id,
        bytes calldata merkle_proof, bytes calldata raw_tx, // avoid compiler error: stack too deep
        //bytes calldata _version, bytes calldata _vin, bytes calldata _vout, bytes calldata _locktime,
        uint64 heightAndIndex, bytes calldata header
    ) external {
        bytes memory _vout = verifyTx(merkle_proof, raw_tx, heightAndIndex, header);
        Issue._execute_issue(requester, issue_id, _vout);
    }

    function cancel_issue(address requester, uint256 issue_id) external {
        Issue._cancel_issue(requester, issue_id);
    }

    function request_redeem(uint256 amount_one_btc, address btc_address, address vault_id) external {
        Redeem._request_redeem(msg.sender, amount_one_btc, btc_address, vault_id);
    }

    function execute_redeem(address requester, uint256 redeem_id,
        bytes calldata merkle_proof, bytes calldata raw_tx,
        uint64 heightAndIndex, bytes calldata header
    ) external {
        bytes memory _vout = verifyTx(merkle_proof, raw_tx, heightAndIndex, header);
        Redeem._execute_redeem(requester, redeem_id, _vout);
    }

    function cancel_redeem(address requester, uint256 redeem_id) external {
        Redeem._cancel_redeem(requester, redeem_id);
    }

    function lockOneBTC(address from, uint256 amount) internal override(Redeem) {
        ERC20.transferFrom(from, address(this), amount);
    }
    function burnLockedOneBTC(uint256 amount) internal override(Redeem) {
        ERC20._burn(address(this), amount);
    }
    function releaseLockedOneBTC(address receiver, uint256 amount) internal override(Redeem) {
        ERC20.transfer(receiver, amount);
    }
    function issueOneBTC(address receiver, uint256 amount) internal override(Issue) {
        ERC20._mint(receiver, amount);
    }

    function register_deposit_address(address vault_id, uint256 issue_id) internal view override(Issue) returns(address) {
        VaultRegistry._register_deposit_address(vault_id, issue_id);
    }
}