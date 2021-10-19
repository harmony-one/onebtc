// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ValidateSPV} from "@interlay/bitcoin-spv-sol/contracts/ValidateSPV.sol";
import {TransactionUtils} from "./TransactionUtils.sol";
import {Issue} from "./Issue.sol";
import {Redeem} from "./Redeem.sol";
import {Replace} from "./Replace.sol";
import {IRelay} from "./IRelay.sol";

contract OneBtc is ERC20, Issue, Redeem, Replace {
    IRelay public realy;

    constructor(IRelay _relay) public ERC20("OneBtc", "OneBtc") {
        _setupDecimals(8);
        realy = _relay;
    }

    function verifyTx(
        bytes calldata merkleProof,
        bytes calldata rawTx,
        uint64 heightAndIndex,
        bytes calldata header
    ) private returns (bytes memory) {
        bytes32 txId = rawTx.hash256();
        realy.verifyTx(
            uint32(heightAndIndex >> 32),
            heightAndIndex & type(uint32).max,
            txId,
            header,
            merkleProof,
            6,
            true
        );
        TransactionUtils.Transaction memory btcTx = TransactionUtils.extractTx(
            rawTx
        );
        require(btcTx.locktime == 0, "locktime must zero!");
        // check version?
        // btcTx.version
        return btcTx.vouts;
    }

    function requestIssue(uint256 amountRequested, address vaultId)
        external
        payable
    {
        Issue._requestIssue(msg.sender, amountRequested, vaultId, msg.value);
    }

    function executeIssue(
        address requester,
        uint256 issueId,
        bytes calldata merkleProof,
        bytes calldata rawTx, // avoid compiler error: stack too deep
        //bytes calldata _version, bytes calldata _vin, bytes calldata _vout, bytes calldata _locktime,
        uint64 heightAndIndex,
        bytes calldata header
    ) external {
        bytes memory _vout = verifyTx(
            merkleProof,
            rawTx,
            heightAndIndex,
            header
        );
        Issue._executeIssue(requester, issueId, _vout);
    }

    function cancelIssue(address requester, uint256 issueId) external {
        Issue._cancelIssue(requester, issueId);
    }

    function requestRedeem(
        uint256 amountOneBtc,
        address btcAddress,
        address vaultId
    ) external {
        Redeem._requestRedeem(msg.sender, amountOneBtc, btcAddress, vaultId);
    }

    function executeRedeem(
        address requester,
        uint256 redeemId,
        bytes calldata merkleProof,
        bytes calldata rawTx,
        uint64 heightAndIndex,
        bytes calldata header
    ) external {
        bytes memory _vout = verifyTx(
            merkleProof,
            rawTx,
            heightAndIndex,
            header
        );
        Redeem._executeRedeem(requester, redeemId, _vout);
    }

    function cancelRedeem(address requester, uint256 redeemId) external {
        Redeem._cancelRedeem(requester, redeemId);
    }

    function lockOneBTC(address from, uint256 amount)
        internal
        override(Redeem)
    {
        //ERC20(this).transferFrom(from, address(this), amount);
        ERC20._transfer(msg.sender, address(this), amount);
    }

    function burnLockedOneBTC(uint256 amount) internal override(Redeem) {
        ERC20._burn(address(this), amount);
    }

    function releaseLockedOneBTC(address receiver, uint256 amount)
        internal
        override(Redeem)
    {
        ERC20._transfer(address(this), receiver, amount);
    }

    function issueOneBTC(address receiver, uint256 amount)
        internal
        override(Issue)
    {
        ERC20._mint(receiver, amount);
    }

    function requestReplace(
        address payable oldVaultId,
        uint256 btcAmount,
        uint256 griefingCollateral
    ) external payable {
        Replace._requestReplace(oldVaultId, btcAmount, griefingCollateral);
    }

    function acceptReplace(
        address oldVaultId,
        address newVaultId,
        uint256 btcAmount,
        uint256 collateral,
        uint256 btcPublicKeyX,
        uint256 btcPublicKeyY
    ) external payable {
        Replace._acceptReplace(
            oldVaultId,
            newVaultId,
            btcAmount,
            collateral,
            btcPublicKeyX,
            btcPublicKeyY
        );
    }

    function executeReplace(
        uint256 replaceId,
        bytes calldata merkleProof,
        bytes calldata rawTx, // avoid compiler error: stack too deep
        //bytes calldata _version, bytes calldata _vin, bytes calldata _vout, bytes calldata _locktime,
        uint64 heightAndIndex,
        bytes calldata header
    ) external {
        bytes memory _vout = verifyTx(
            merkleProof,
            rawTx,
            heightAndIndex,
            header
        );
        Replace._executeReplace(replaceId, _vout);
    }
}
