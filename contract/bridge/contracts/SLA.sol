// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SLA {

    using SafeMath for uint256;

    event UpdateVaultSLA(
        address indexed vaultId,
        uint256 boundedNewSla,
        int256 deltaSla
    );
    event UpdateRelayerSLA(
        address indexed relayerId,
        uint256 newSla,
        uint256 deltaSla
    );

    enum VaultEvent {
        RedeemFailure,
        SubmitIssueProof,
        Refund,
        ExecuteIssue,
        Deposit,
        Withdraw,
        Liquidate
    }

    uint256 public TotalIssueCount;
    uint256 public LifetimeIssued;
    uint256 public VaultExecuteIssueMaxSlaChange;
    uint256 public VaultDepositMaxSlaChange;
    uint256 public VaultWithdrawMaxSlaChange;
    uint256 public AverageDepositCount;
    uint256 public AverageDeposit;
    uint256 public AverageWithdrawCount;
    uint256 public AverageWithdraw;

    struct SlaData {
        uint256 vaultRedeemFailure;
        uint256 vaultSubmitIssueProof;
        uint256 vaultRefund;
        uint256 executeIssue;
        uint256 deposit;
        uint256 withdraw;
        uint256 liquidate;
        uint256 sla;
        uint256 vaultTargetSla;
    }

    uint256 public VaultSLATarget = 100;
    int256 public FailedRedeem = -100;

    mapping(address => SlaData) VaultSLA;
    mapping(address => SlaData) StakedRelayerSLA;
    mapping(address => bool) VaultTrue;

    function _executeIssueSlaChange(uint256 amount) private returns (uint256) {
        uint256 count = TotalIssueCount + 1;
        TotalIssueCount = count;
        uint256 total = LifetimeIssued + amount;
        LifetimeIssued = total;
        uint256 average = total / count;
        uint256 maxSlaChange = VaultExecuteIssueMaxSlaChange;
        //uint256 increase = (amount / average) * maxSlaChange;
        return (amount * maxSlaChange) / average;
    }

    function _depositSlaChange(uint256 amount) private returns (uint256) {
        uint256 maxSlaChange = VaultDepositMaxSlaChange;

        uint256 count = AverageDepositCount + 1;
        AverageDepositCount = count;
        // newAverage = (oldAverage * (n-1) + newValue) / n
        uint256 average = (AverageDeposit * (count - 1) + amount) / count;
        AverageDeposit = average;
        // increase = (amount / average) * maxSlaChange
        return (amount / average) * maxSlaChange;
    }

    function _withdrawSlaChange(uint256 amount) private returns (uint256) {
        uint256 maxSlaChange = VaultWithdrawMaxSlaChange;

        uint256 count = AverageWithdrawCount + 1;
        AverageWithdrawCount = count;

        // newAverage = (oldAverage * (n-1) + newValue) / n
        uint256 average = (AverageWithdraw * (count - 1) + amount) / count;
        AverageWithdraw = average;
        return (amount / average) * maxSlaChange;
    }

    function _liquidateSla(address vaultId) private returns (int256) {
        // TODO
        //Self::liquidateStake::<T::CollateralVaultRewards>(vaultId)?;
        //Self::liquidateStake::<T::WrappedVaultRewards>(vaultId)?;
        revert("TODO");
        SlaData storage slaData = VaultSLA[vaultId];
        int256 deltaSla = -int256(slaData.sla);
        slaData.sla = 0;
        emit UpdateVaultSLA(vaultId, 0, deltaSla);
    }

    function limit(
        uint256 min,
        uint256 cur,
        uint256 max
    ) private pure returns (uint256) {
        return cur > max ? max : (cur > min ? cur : min);
    }

    function eventUpdateVaultSla(
        address vaultId,
        VaultEvent eventType,
        uint256 amount
    ) internal {
        SlaData storage slaData = VaultSLA[vaultId];
        uint256 currentSla = slaData.sla;
        uint256 deltaSla;
        if (eventType == VaultEvent.RedeemFailure) {
            deltaSla = slaData.vaultRedeemFailure;
        } else if (eventType == VaultEvent.SubmitIssueProof) {
            deltaSla = slaData.vaultSubmitIssueProof;
        } else if (eventType == VaultEvent.Refund) {
            deltaSla = slaData.vaultRefund;
        } else if (eventType == VaultEvent.ExecuteIssue) {
            deltaSla = _executeIssueSlaChange(amount);
        } else if (eventType == VaultEvent.Deposit) {
            deltaSla = _depositSlaChange(amount);
        } else if (eventType == VaultEvent.Withdraw) {
            deltaSla = _withdrawSlaChange(amount);
        } else if (eventType == VaultEvent.Liquidate) {
            _liquidateSla(vaultId);
            return;
        } else {
            revert("unknow type");
        }

        uint256 newSla = currentSla + deltaSla;
        uint256 maxSla = slaData.vaultTargetSla; // todo: check that this is indeed the max

        uint256 boundedNewSla = limit(0, newSla, maxSla);
        /*
        Self::adjustStake::<T::CollateralVaultRewards>(vaultId, deltaSla)?;
        Self::adjustStake::<T::WrappedVaultRewards>(vaultId, deltaSla)?;
        */
        slaData.sla = boundedNewSla;
        emit UpdateVaultSLA(vaultId, boundedNewSla, int256(deltaSla));
    }

    function SlashVault(address account) internal returns (uint256) {
        SlaData vault = VaultSLA[account];
        uint256 slaTarget = vault.vaultTargetSla;
        uint256 sla = vaule.sla;
        uint256 liquidateThreshold = vault.liquidate;
        uint256 premiumRedeemThreshold = vault.vaultRedeemFailure; 

        uint256 realSlashed = premiumRedeemThreshold.sub(liquidateThreshold).div(slaTarget).mul(sla).add(liquidateThreshold);
        
        return realSlashed;
    }

    function updateSLA(address account, int256 delta) internal {
        SlaData storage vault;
        if(VaultTrue[address]){
            vault = VaultSLA[address];
                    vault.sla  = int256(vault).sla + delta;
                    UpdateVaultSLA(account, vault.sla, delta);
        }        
        else {
            vault = StakedRelayerSLA[address];
            vault.sla  = int256(vault).sla + delta;
            UpdateRelayerSLA(account, vault.sla, delta);
        }
    }
}
