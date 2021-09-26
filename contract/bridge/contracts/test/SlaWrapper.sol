pragma solidity ^0.6.12;

import {SLA} from "../SLA.sol";

contract SLAWrapper is SLA {
    function slashVaultTest (address account) public returns (uint256){
        uint256 slashAmount = SlashVault(account);
        return slashAmount;
    }

    function updateSlaTes (address account, int256 delta) internal {
        updateSLA(account, delta);
    }
}
