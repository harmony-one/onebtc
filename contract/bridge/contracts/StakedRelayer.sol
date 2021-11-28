pragma solidity 0.6.12;

import {IRelay} from "./IRelay.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";

interface IVaultRegistry {
    function liquidateTheftVault(address vaultId, address reporterId) external;
}

contract StakedRelayer is Initializable, OwnableUpgradeable {
    using BTCUtils for bytes;

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

    IRelay public relay;
    IVaultRegistry public vaultRegistry;
    mapping(bytes32 => bool) public theftReports;

    function initialize(
        IRelay _relay,
        IVaultRegistry _vaultRegistry
    ) external initializer {
        relay = _relay;
        vaultRegistry = _vaultRegistry;
    }

    /**
     * @dev Report vault misbehavior by providing fraud proof (malicious bitcoin transaction and the corresponding transaction inclusion proof). Fully slashes the vault.
     */
    function reportVaultTheft(
        address vaultId,
        bytes calldata rawTx,
        uint64 heightAndIndex,
        bytes calldata merkleProof,
        bytes calldata header
    ) external {
        bytes32 txId = rawTx.hash256();

        // check if already reported
        bytes32 reportKey = keccak256(abi.encodePacked(vaultId, txId));
        require(theftReports[reportKey] == false, "This txId has already been logged as a theft by the given vault");

        // verify transaction inclusion using header and merkle proof
        relay.verifyTx(
            uint32(heightAndIndex >> 32),
            heightAndIndex & type(uint32).max,
            txId,
            header,
            merkleProof,
            6,
            true
        );

        // all looks good, liquidate vault
        address reporterId = msg.sender;
        vaultRegistry.liquidateTheftVault(vaultId, reporterId);

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
        vaultRegistry.liquidateTheftVault(vaultId, reporterId);

        emit VaultDoublePayment(vaultId, leftTxId, rightTxId);
    }
}
