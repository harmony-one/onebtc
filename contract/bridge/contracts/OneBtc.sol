// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ValidateSPV} from "@interlay/bitcoin-spv-sol/contracts/ValidateSPV.sol";
import {TransactionUtils} from "./TransactionUtils.sol";
import {Issue} from "./Issue.sol";
import {Redeem} from "./Redeem.sol";
import {Replace} from "./Replace.sol";
import {IRelay} from "./IRelay.sol";

contract OneBtc is ERC20Upgradeable, Issue, Redeem, Replace {
    IRelay public realy;

    function initialize(IRelay _relay) external initializer {
        __ERC20_init("OneBtc", "OneBtc");
        _setupDecimals(8);
        realy = _relay;
    }

    function verifyTx(
        uint32 height,
        uint256 index,
        bytes calldata rawTx,
        bytes calldata header,
        bytes calldata merkleProof
    ) public returns (bytes memory) {
        bytes32 txId = rawTx.hash256();
        realy.verifyTx(
            height,
            index,
            txId,
            header,
            merkleProof,
            1,
            true
        );
        TransactionUtils.Transaction memory btcTx =
        TransactionUtils.extractTx(rawTx);
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
        uint32 height,
        uint256 index,
        bytes calldata header
    ) external {
        bytes memory _vout =
        verifyTx(height, index, rawTx, header, merkleProof);

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
        uint32 height,
        uint256 index,
        bytes calldata header
    ) external {
        bytes memory _vout =
        verifyTx(height, index, rawTx, header, merkleProof);

        Redeem._executeRedeem(requester, redeemId, _vout);
    }

    function cancelRedeem(address requester, uint256 redeemId) external {
        Redeem._cancelRedeem(requester, redeemId);
    }

    function lockOneBTC(address from, uint256 amount)
        internal
        override(Redeem)
    {
        ERC20Upgradeable._transfer(msg.sender, address(this), amount);
    }

    function burnLockedOneBTC(uint256 amount) internal override(Redeem) {
        ERC20Upgradeable._burn(address(this), amount);
    }

    function releaseLockedOneBTC(address receiver, uint256 amount)
        internal
        override(Redeem)
    {
        ERC20Upgradeable._transfer(address(this), receiver, amount);
    }

    function issueOneBTC(address receiver, uint256 amount)
        internal
        override(Issue)
    {
        ERC20Upgradeable._mint(receiver, amount);
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
        uint32 height,
        uint256 index,
        bytes calldata header
    ) external {
        bytes memory _vout = verifyTx(height, index, rawTx, header, merkleProof);
        Replace._executeReplace(replaceId, _vout);
    }
}
