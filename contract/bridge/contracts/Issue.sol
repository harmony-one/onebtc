// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import {BTCUtils} from "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";
import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import {IssueRequest, RequestStatus} from "./Request.sol";
import {TxValidate} from "./TxValidate.sol";
import {ICollateral} from "./Collateral.sol";
import {VaultRegistry} from "./VaultRegistry.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

abstract contract Issue is ICollateral, VaultRegistry {
    using BTCUtils for bytes;
    using BytesLib for bytes;
    using SafeMathUpgradeable for uint256;

    event IssueRequested(
        uint256 indexed issueId,
        address indexed requester,
        address indexed vaultId,
        uint256 amount,
        uint256 fee,
        address btcAddress
    );

    event IssueCompleted(
        uint256 indexed issuedId,
        address indexed requester,
        address indexed vaultId,
        uint256 amount,
        uint256 fee,
        address btcAddress
    );

    event IssueCanceled(
        uint256 indexed issuedId,
        address indexed requester,
        address indexed vaultId,
        uint256 amount,
        uint256 fee,
        address btcAddress
    );

    event IssueAmountChanged(
        uint256 indexed issuedId,
        uint256 amount,
        uint256 fee,
        uint256 confiscatedGriefingCollateral
    );

    mapping(address => mapping(uint256 => IssueRequest)) public issueRequests;

    function issueOneBTC(address receiver, uint256 amount) internal virtual;

    function getIssueFee(uint256 amountRequested)
        private
        pure
        returns (uint256)
    {
        return (amountRequested * 2) / 1000;
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

    function updateIssueAmount(
        uint256 issueId,
        IssueRequest storage issue,
        uint256 transferredBtc,
        uint256 confiscatedGriefingCollateral
    ) internal {
        issue.fee = getIssueFee(transferredBtc);
        issue.amount = transferredBtc.sub(issue.fee);
        emit IssueAmountChanged(
            issueId,
            issue.amount,
            issue.fee,
            confiscatedGriefingCollateral
        );
    }

    function _requestIssue(
        address payable requester,
        uint256 amountRequested,
        address vaultId,
        uint256 griefingCollateral
    ) internal {
        require(
            getIssueGriefingCollateral(amountRequested) <= griefingCollateral,
            "InsufficientCollateral"
        );
        require(
            VaultRegistry.tryIncreaseToBeIssuedTokens(vaultId, amountRequested),
            "ExceedingVaultLimit"
        );
        uint256 issueId = getIssueId(requester);
        address btcAddress = VaultRegistry.registerDepositAddress(
            vaultId,
            issueId
        );
        uint256 fee = getIssueFee(amountRequested);
        uint256 amountUser = amountRequested.sub(fee);
        IssueRequest storage request = issueRequests[requester][issueId];
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
        );
        emit IssueRequested(
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
        IssueRequest storage request = issueRequests[requester][issueId];
        require(
            request.status == RequestStatus.Pending,
            "request is completed"
        );
        uint256 amountTransferred = TxValidate.validateTransaction(
            _vout,
            0,
            request.btcAddress,
            0x0
        );
        uint256 expectedTotalAmount = request.amount.add(request.fee);
        if (amountTransferred < expectedTotalAmount) {
            // only the requester of the issue can execute payments with different amounts
            require(msg.sender == request.requester, "InvalidExecutor");
            uint256 deficit = expectedTotalAmount - amountTransferred;
            VaultRegistry.decreaseToBeIssuedTokens(request.vault, deficit);
            uint256 releasedCollateral = VaultRegistry.calculateCollateral(
                request.griefingCollateral,
                amountTransferred,
                expectedTotalAmount
            );
            ICollateral.releaseCollateral(
                request.requester,
                releasedCollateral
            );
            uint256 slashedCollateral = request.griefingCollateral.sub(
                releasedCollateral
            );
            ICollateral.slashCollateral(
                request.requester,
                request.vault,
                slashedCollateral
            ); // ICollateral::
            updateIssueAmount(
                issueId,
                request,
                amountTransferred,
                slashedCollateral
            );
        } else {
            ICollateral.releaseCollateral(
                request.requester,
                request.griefingCollateral
            ); // ICollateral::
            if (amountTransferred > expectedTotalAmount) {
                uint256 surplusBtc = amountTransferred.sub(expectedTotalAmount);
                if (
                    VaultRegistry.tryIncreaseToBeIssuedTokens(
                        request.vault,
                        surplusBtc
                    )
                ) {
                    updateIssueAmount(issueId, request, amountTransferred, 0);
                } else {
                    // vault does not have enough collateral to accept the over payment, so refund.
                    // TODO requestRefund
                    // requestRefund(surplusBtc, request.vault, request.requester, issueId);
                }
            }
        }
        uint256 total = request.amount.add(request.fee);
        VaultRegistry.issueTokens(request.vault, total);
        issueOneBTC(request.vault, request.fee);
        issueOneBTC(request.requester, request.amount);
        request.status = RequestStatus.Completed;
        // TODO: update sla
        // sla.eventUpdateVaultSla(request.vault, total);
        emit IssueCompleted(
            issueId,
            requester,
            request.vault,
            request.amount,
            request.fee,
            request.btcAddress
        );
    }

    function _cancelIssue(address requester, uint256 issueId) internal {
        IssueRequest storage request = issueRequests[requester][issueId];
        require(
            request.status == RequestStatus.Pending,
            "request is completed"
        );
        require(
            block.timestamp > request.opentime.add(request.period),
            "TimeNotExpired"
        );
        request.status = RequestStatus.Cancelled;
        ICollateral.slashCollateral(
            request.requester,
            request.vault,
            request.griefingCollateral
        ); // ICollateral::
        VaultRegistry.decreaseToBeIssuedTokens(
            request.vault,
            request.amount + request.fee
        );
        emit IssueCanceled(
            issueId,
            requester,
            request.vault,
            request.amount,
            request.fee,
            request.btcAddress
        );
    }
}
