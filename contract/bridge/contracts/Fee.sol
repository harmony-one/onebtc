// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

contract Fee {

    event WithdrawFees(
        address account,
        string currency,
        uint256 amount
    );

    /*
    Specifies the distribution of fees in the Vault fee pool among individual Vaults.
    */
    function distributeVaultRewards() public {
        // 1. Calculate the fees assigned to all Vaults using the BridgeFeePool and the VaultRewards.
        // 2. Calculate the fees for every Vault according to the initial values.
        // 3. Update the TotalRewards mapping for the Vault.
    }

    /*
    Specifies the distribution of fees in the Staked Relayer fee pool among individual Staked Relayers.
    This function can implement different reward distributions.
    We differentiate if the BTC-Bridge operates with the SLA model or without.
    */
    function distributeRelayerRewards() public {
        // 1. Calculate the fees assigned to all Staked Relayers using the BridgeFeePool and the StakedRelayerRewards.
        // 2. Calculate the fees for every Staked Relayer according to the reward distribution mode (SLA model activated/deactivated).
        // 3. Update the TotalRewards mapping for the Staked Relayer.
    }

    /*
    Allows staked relayers, vaults, collators and maintainers to withdraw the fees earned.
    */
    function withdrawFees(address account, string memory currency, uint256 amount) public {
        // 1. Transfer the request amount to the account in case the balance is sufficient.
        // 2. Update the TotalRewards of the account.
    }
}
