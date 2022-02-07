// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

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
        int256 deltaSla
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
    }

    uint256 public VaultSLATarget = 100;
    int256 public FailedRedeem = -100;

    mapping(address => SlaData) VaultSLA;
    mapping(address => SlaData) StakedRelayerSLA;
    mapping(address => bool) VaultTrue;


    /*
    - adjust stake
    - liquidate stake
    - calculate slashed amount
    - fixed point unsigned to signed
    - wrapper to uint128
    - currency to fixed point
    */

    constructor( uint256  _TotalIssueCount,
    uint256  _LifetimeIssued,
    uint256  _VaultExecuteIssueMaxSlaChange,
    uint256  _VaultDepositMaxSlaChange,
    uint256  _VaultWithdrawMaxSlaChange,
    uint256  _AverageDepositCount,
    uint256  _AverageDeposit,
    uint256  _AverageWithdrawCount,
    uint256  _AverageWithdraw) public {
        TotalIssueCount = _TotalIssueCount;
        LifetimeIssued = _LifetimeIssued;
        VaultDepositMaxSlaChange = _VaultDepositMaxSlaChange;
        VaultWithdrawMaxSlaChange = _VaultWithdrawMaxSlaChange;
        AverageDeposit = _AverageDeposit;
        AverageDepositCount = _AverageDepositCount;
        AverageWithdraw = _AverageWithdraw;
        AverageWithdrawCount = _AverageWithdrawCount;
    }

    
    function _executeIssueSlaChange(uint256 amount) internal returns (uint256) {
        uint256 count = TotalIssueCount + 1;
        TotalIssueCount = count;
        uint256 total = LifetimeIssued + amount;
        LifetimeIssued = total;
        uint256 average = total / count;
        uint256 maxSlaChange = VaultExecuteIssueMaxSlaChange;
        //uint256 increase = (amount / average) * maxSlaChange;
        return (amount * maxSlaChange) / average;
    }


    // Calculates the potential sla change for a vault depositing collateral. The value will be
    // clipped between 0 and VaultDepositMaxSlaChange, but it does not take into consideration
    // Vault's current SLA. It can return a value > 0 when its sla is already at the maximum.
    
    function _depositSlaChange(uint256 amount) internal returns (uint256) {
        uint256 maxSlaChange = VaultDepositMaxSlaChange;

        uint256 count = AverageDepositCount + 1;
        AverageDepositCount = count;
        // newAverage = (oldAverage * (n-1) + newValue) / n
        uint256 average = (AverageDeposit * (count - 1) + amount) / count;
        AverageDeposit = average;
        // increase = (amount / average) * maxSlaChange
        return (amount / average) * maxSlaChange;
    }

    function _withdrawSlaChange(uint256 amount) internal returns (uint256) {
        uint256 maxSlaChange = VaultWithdrawMaxSlaChange;

        uint256 count = AverageWithdrawCount + 1;
        AverageWithdrawCount = count;

        // newAverage = (oldAverage * (n-1) + newValue) / n
        uint256 average = (AverageWithdraw * (count - 1) + amount) / count;
        AverageWithdraw = average;
        return (amount / average) * maxSlaChange;
    }

    function _liquidateSla(address vaultId) internal returns (int256) {
        // TODO
        //Self::liquidateStake::<T::CollateralVaultRewards>(vaultId)?;
        //Self::liquidateStake::<T::WrappedVaultRewards>(vaultId)?;
        // revert("TODO");
        SlaData storage slaData = VaultSLA[vaultId];
        int256 deltaSla = -int256(slaData.sla);
        slaData.sla = 0;
        emit UpdateVaultSLA(vaultId, 0, deltaSla);
    }

    function limit(
        uint256 min,
        uint256 cur,
        uint256 max
    ) internal pure returns (uint256) {
        return cur > max ? max : (cur > min ? cur : min);
    }

    event data (uint256,uint256,uint256, uint256);

    function _eventUpdateVaultSla(
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
            revert("unknown type");
        }

        uint256 newSla = currentSla + deltaSla;
        uint256 maxSla = VaultSLATarget; // todo: check that this is indeed the max

        uint256 boundedNewSla = limit(0, newSla, maxSla);
        /*
        Self::adjustStake::<T::CollateralVaultRewards>(vaultId, deltaSla)?;
        Self::adjustStake::<T::WrappedVaultRewards>(vaultId, deltaSla)?;
        */
        slaData.sla = boundedNewSla;
        emit UpdateVaultSLA(vaultId, boundedNewSla, int256(deltaSla));
    }


     function _eventUpdateRelayerSla(
        address relayerId,
        VaultEvent eventType,
        uint256 amount
    ) internal {
        SlaData storage slaData = StakedRelayerSLA[relayerId];
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
            _liquidateSla(relayerId);
            return;
        } else {
            revert("unknown type");
        }

        uint256 newSla = currentSla + deltaSla;
        uint256 maxSla = VaultSLATarget; // todo: check that this is indeed the max

        uint256 boundedNewSla = limit(0, newSla, maxSla);
        /*
        Self::adjustStake::<T::CollateralVaultRewards>(vaultId, deltaSla)?;
        Self::adjustStake::<T::WrappedVaultRewards>(vaultId, deltaSla)?;
        */
        slaData.sla = boundedNewSla;
        emit UpdateVaultSLA(relayerId, boundedNewSla, int256(deltaSla));
    }

    function calculateSlashAmount(address account) internal returns (uint256) {
        SlaData memory vault = VaultSLA[account];
        uint256 slaTarget = VaultSLATarget;
        uint256 sla = vault.sla;
        uint256 liquidateThreshold = vault.liquidate;
        uint256 premiumRedeemThreshold = vault.vaultRedeemFailure; 

        uint256 realSlashed = premiumRedeemThreshold.sub(liquidateThreshold).div(slaTarget).mul(sla).add(liquidateThreshold);
        
        return realSlashed;
    }

    function updateVaultSLA(address account, int256 delta) internal {
        SlaData storage vault;
            vault = VaultSLA[account];

            if(delta > 0){
                vault.sla  = vault.sla + uint256(delta);
            }
            if(delta <0){
                vault.sla = vault.sla - uint256(delta);
            }
            UpdateVaultSLA(account, vault.sla, delta);
    }

    function _updateRelayerSla(address account, int256 delta) internal {
           SlaData storage  vault = StakedRelayerSLA[account];
                if(delta > 0){
                vault.sla  = vault.sla + uint256(delta);
            }
            if(delta <0){
                vault.sla = vault.sla - uint256(delta);
            }
            UpdateRelayerSLA(account, vault.sla, delta);

    }


    function getRelayerSla ( address vaultId) public view returns (uint256){
        return StakedRelayerSLA[vaultId].sla;
    }

    function getVaultSla(address vaultId) public view returns (uint256 ){
        return VaultSLA[vaultId].sla;
    }
}
