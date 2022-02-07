pragma solidity ^0.6.12;

import {SLA} from "../SLA.sol";

contract SLAWrapper is SLA {
    // function slashVaultTest (address account) public returns (uint256){
    //     uint256 slashAmount = SlashVault(account);
    //     return slashAmount;
    // }

    // function updateSlaTes (address account, int256 delta) internal  returns(uint256){
    //     updateSLA(account, delta);
    // }

    constructor(uint256  _TotalIssueCount,
    uint256  _LifetimeIssued,
    uint256  _VaultExecuteIssueMaxSlaChange,
    uint256  _VaultDepositMaxSlaChange,
    uint256  _VaultWithdrawMaxSlaChange,
    uint256  _AverageDepositCount,
    uint256  _AverageDeposit,
    uint256  _AverageWithdrawCount,
    uint256  _AverageWithdraw) SLA(  _TotalIssueCount,
      _LifetimeIssued,
      _VaultExecuteIssueMaxSlaChange,
      _VaultDepositMaxSlaChange,
      _VaultWithdrawMaxSlaChange,
      _AverageDepositCount,
      _AverageDeposit,
      _AverageWithdrawCount,
      _AverageWithdraw) public {}

    function eventUpdateVaultSla(address vaultId, VaultEvent eventType,uint256 amount) public returns (uint256) {
        _eventUpdateVaultSla(vaultId, eventType, amount);
    }


    function eventUpdateRelayerSla(address vaultId, VaultEvent eventType,uint256 amount) public returns (uint256) {
        _eventUpdateRelayerSla(vaultId, eventType, amount);
    }

    function updateRelayerSla(address account, int256 delta) public {
        _updateRelayerSla(account, delta);
    }

    // for use in tests
    function setVaultSla(address vaultId,  uint256 sla) public {
        VaultSLA[vaultId].sla = sla;
    }

    function setRelayerSla(address vaultId, uint256 sla) public {
        StakedRelayerSLA[vaultId].sla = sla;
    }

}
