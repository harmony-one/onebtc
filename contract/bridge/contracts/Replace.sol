// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
import {BTCUtils} from "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";
import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import {S_ReplaceRequest, RequestStatus} from "./Request.sol";
import {TxValidate} from "./TxValidate.sol";
import {ICollateral} from "./Collateral.sol";
import {VaultRegistry} from "./VaultRegistry.sol";

abstract contract Replace is ICollateral, VaultRegistry {
//    using BTCUtils for bytes;
//    using BytesLib for bytes;

    event RequestReplace(
        uint256 indexed replaceId,
        address indexed oldVault,
        uint256 btcAmount
    );

    event WithdrawReplace(
        address indexed oldVault,
        uint256 indexed replaceId,
        uint256 withdrawnTokens,
        uint256 withdrawnGriefingCollateral
    );

    event AcceptReplace(
        uint256 indexed replaceId,
        address indexed oldVault,
        address indexed newVault,
        address btcAddress,
        uint256 btcAmount,
        uint256 collateral
    );

    event ExecuteReplace(
        uint256 indexed replaceId,
        address indexed oldVault,
        address indexed newVault
    );

    event CancelReplace(
        uint256 indexed replaceId,
        address indexed oldVault,
        address indexed newVault,
        uint256 slashedCollateral
    );

    mapping(address => mapping(uint256 => S_ReplaceRequest)) public replaceRequests;

    function getReplaceId(address user) private view returns (uint256) {
        //getSecureId
        return
        uint256(
            keccak256(abi.encodePacked(user, blockhash(block.number - 1)))
        );
    }

    function _requestReplace(
        address payable oldVaultId,
        uint256 btcAmount,
        uint256 griefingCollateral
    ) internal {
        require(msg.sender == oldVaultId, 'Sender should be owner of this Vault');

        // TODO: SECURITY CHECK (The oldVault MUST NOT be banned)

        // TODO: The oldVault MUST request sufficient btcAmount to be replaced such that its total is above ReplaceBtcDustValue.
        /*
            ERR_AMOUNT_BELOW_BTC_DUST_VALUE
            Message: “To be replaced amount is too small.”
            Function: requestReplace, acceptReplace
            Cause: The Vault requests or accepts an insufficient number of tokens.
        */

        uint256 replaceId = getIssueId(oldVaultId);
        S_ReplaceRequest storage request = issueRequests[oldVaultId][issueId];

        require(request.status == RequestStatus.None, "This replace already created");

        Vault storage vault = vaults[vaultId];

        uint256 (increaseAmount, collateral) = VaultRegistry.increaseToBeReplacedTokens(oldVaultId, btcAmount, griefingCollateral);

        {
            request.oldVault = address(uint160(vaultId));
            request.amount = increaseAmount;
            request.griefingCollateral = collateral;
            request.period = 2 days;
            request.btcHeight = 0;
            request.status = RequestStatus.Pending;
        }

        emit RequestReplace(replaceId, oldVaultId, increaseAmount);
    }

    function _withdrawReplace(address oldVaultId, uint256 replaceId, uint256 tokens) internal {
        require(msg.sender == oldVaultId, 'Sender should be owner of OldVault');

        // TODO: SECURITY CHECK (The oldVault MUST NOT be banned)

        S_ReplaceRequest storage request = issueRequests[oldVaultId][issueId];
        require(request.status == RequestStatus.Pending, "This replace status not pending");

        uint256 (decreaseAmount, griefingCollateral) = VaultRegistry.decreaseToBeReplacedTokens(oldVaultId, btcAmount, griefingCollateral);

        {
            request.amount -= decreaseAmount;
            request.griefingCollateral = griefingCollateral;
        }

        emit WithdrawReplace(oldVaultId, replaceId, decreaseAmount, griefingCollateral);
    }
}
