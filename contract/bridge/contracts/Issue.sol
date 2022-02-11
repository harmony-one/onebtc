// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";
import "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import "./Request.sol";
import "./TxValidate.sol";
import "./Collateral.sol";
import "./VaultRegistry.sol";

abstract contract Issue is VaultRegistry, Request {
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

    function updateIssueAmount(
        uint256 issueId,
        IssueRequest storage issue,
        uint256 transferredBtc,
        uint256 confiscatedGriefingCollateral
    ) internal {
        issue.fee = transferredBtc.mul(5).div(1000); //0.5%
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
        // griefing collateral needs to be >= 0.005% of vaults collateral
        require(
            collateralForIssued(amountRequested).mul(5).div(1000) <= griefingCollateral,
            "Insufficient griefing collateral"
        );
        require(
            VaultRegistry.tryIncreaseToBeIssuedTokens(vaultId, amountRequested),
            "Amount requested exceeds vault limit"
        );
        uint256 issueId = uint256(
            keccak256(
                abi.encodePacked(requester, blockhash(block.number - 1))
            )
        );
        address btcAddress = VaultRegistry.registerDepositAddress(
            vaultId,
            issueId
        );
        uint256 fee = amountRequested.mul(5).div(1000); //0.5%
        uint256 amountUser = amountRequested.sub(fee);
        IssueRequest storage request = issueRequests[requester][issueId];
        require(request.status == RequestStatus.None, "Invalid issue request");
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
        // updated used collateral for the issued
        ICollateral.useCollateralInc(request.vault, VaultRegistry.collateralForIssued(amountRequested));
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
        bytes memory _vout,
        uint256 outputIndex
    ) internal {
        IssueRequest storage request = issueRequests[requester][issueId];
        require(
            request.status == RequestStatus.Pending,
            "Request is already completed"
        );
        uint256 amountTransferred = TxValidate.validateTransaction(
            _vout,
            0,
            request.btcAddress,
            0x0, // will validate only output with outputIndex
            outputIndex
        );
        uint256 expectedTotalAmount = request.amount.add(request.fee);
        if (amountTransferred < expectedTotalAmount) {
            // only the requester of the issue can execute payments with different amounts
            require(msg.sender == request.requester, "Invalid executor");
            uint256 deficit = expectedTotalAmount - amountTransferred;
            VaultRegistry.decreaseToBeIssuedTokens(request.vault, deficit);
            // release portion of the griefing collateral of the requester
            uint256 releasedCollateral = VaultRegistry.calculateCollateral(
                request.griefingCollateral,
                amountTransferred,
                expectedTotalAmount
            );
            ICollateral.releaseCollateral(
                request.requester,
                releasedCollateral
            );
            // send the rest to vault as slashing
            uint256 slashedCollateral = request.griefingCollateral.sub(
                releasedCollateral
            );
            ICollateral.slashCollateral(
                request.requester,
                request.vault,
                slashedCollateral
            );
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
            );
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
                    // refund is disabled
                    require(false, "Overpayment refund is disabled");
                }
            }
        }
        uint256 total = request.amount.add(request.fee);
        VaultRegistry.issueTokens(request.vault, total);
        issueOneBTC(request.vault, request.fee);
        issueOneBTC(request.requester, request.amount);
        request.status = RequestStatus.Completed;
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
            "Request is already completed"
        );
        require(
            block.timestamp > request.opentime.add(request.period),
            "Time not expired"
        );
        request.status = RequestStatus.Cancelled;
        ICollateral.slashCollateral(
            request.requester,
            request.vault,
            request.griefingCollateral
        );
        uint256 total = request.amount + request.fee;
        VaultRegistry.decreaseToBeIssuedTokens(
            request.vault,
            total
        );
        ICollateral.useCollateralDec(request.vault, VaultRegistry.collateralForIssued(total));
        emit IssueCanceled(
            issueId,
            requester,
            request.vault,
            request.amount,
            request.fee,
            request.btcAddress
        );
    }

    uint256[45] private __gap;
}
