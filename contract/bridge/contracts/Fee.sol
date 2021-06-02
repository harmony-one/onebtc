/*
SPDX-License-Identifier: MIT

Fee Module
https://onebtc-dev.web.app/spec/fee.html
https://onebtc-dev.web.app/economics/fees.html

1. Fees are paid by Users and forwarded to a common Fee Pool from e.g., issue and redeem requests.
2. Fees are then split to multiple smaller fee pools for the Vaults, Staked Relayers, Maintainers, and Collators.
3. The individual fee pools (Vaults, Staked Relayers, Maintainers, and Collators) are then split among the actors based on individual distribution criteria.
4. Each actor can withdraw fees from their individual pool.
5. Fees can be paid both in ONEBTC and ONE.
*/

pragma solidity ^0.6.12;

contract Fee {

    struct FeePools {
        uint256 bridgeFeePool;
        uint256 vaultRewards; // Initial value: 77%
        uint256 stakedRelayerRewards; // Initial value: 3%
        uint256 collatorRewards; // Initial value: 0%
    }

    struct Fees {
        uint256 maintainerRewards; // Initial value: 20%
        uint256 issueFee; // Paid in ONEBTC - Initial value: 0.5%
        uint256 issueGriefingCollateral; // Paid in ONE - Initial value: 0.005%
        uint256 redeemFee; // Paid in ONEBTC. - Initial value: 0.5%
        uint256 premiumRedeemFee; // Paid in ONE - Initial value: 5%
        uint256 punishmentFee; // Paid in ONE - Initial value: 10%
        uint256 punishmentDelay; // Measured in Bridge blocks - Initial value: 1 day (Bridge constant)
        uint256 replaceGriefingCollateral; // Paid in ONE - Initial value: 0.005%
    }

    mapping (address => uint256) totalRewards;

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
