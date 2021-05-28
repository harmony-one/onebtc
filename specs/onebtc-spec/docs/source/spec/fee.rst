Fee
===

Overview
~~~~~~~~

The fee model crate implements the fee model outlined in :ref:`fee_model`.


Step-by-step
------------

1. Fees are paid by Users and forwarded to a common Fee Pool from e.g., issue and redeem requests.
2. Fees are then split to multiple smaller fee pools for the Vaults, Staked Relayers, Maintainers, and Collators.
3. The individual fee pools (Vaults, Staked Relayers, Maintainers, and Collators) are then split among the actors based on individual distribution criteria.
4. Each actor can withdraw fees from their individual pool.
5. Fees can be paid both in `ONEBTC` and `ONE`.


Data Model
~~~~~~~~~~

Scalars (Fee Pools)
-------------------

BridgeFeePool
................

Tracks the balance of fees earned by the BTC-Bridge which are to be distributed across all Vault, Staked Relayer, Collator and Maintainer pools.

VaultRewards
............

Tracks the fee share (in %) allocated to Vaults.

- Initial value: 77%

StakedRelayerRewards
....................

Tracks the fee share (in %) allocated to Staked Relayers.

- Initial value: 3%

CollatorRewards
...............

Tracks the fee share (in %) allocated to Collators (excl. Bridge transaction fees).

- Initial value: 0%

MaintainerRewards
.................

Tracks fee share (in %) allocated to Bridge maintainers.

- Initial value: 20%

Scalars (Fees)
--------------

IssueFee
........

Issue fee share (configurable parameter, as percentage) that users need to pay upon execute issuing ONEBTC.

- Paid in ONEBTC
- Initial value: 0.5%

IssueGriefingCollateral
.......................

Default griefing collateral (in ONE) as a percentage of the locked collateral of a vault a user has to lock to issue ONEBTC.

- Paid in ONE
- Initial value: 0.005%

RedeemFee
.........

Redeem fee share (configurable parameter, as percentage) that users need to pay upon request redeeming ONEBTC.

- Paid in ONEBTC.
- Initial value: 0.5%

PremiumRedeemFee
................

Fee for users to premium redeem (as percentage). If users execute a redeem with a Vault flagged for premium redeem, they earn a ONE premium,  slashed from the Vault’s collateral.

- Paid in ONE
- Initial value: 5%

PunishmentFee
.............

Fee (as percentage) that a vault has to pay if it fails to execute redeem requests (for redeem, on top of the slashed BTC-in-ONE value of the request). The fee is paid in ONE based on the ONEBTC amount at the current exchange rate.

- Paid in ONE
- Initial value: 10%

PunishmentDelay
...............

Time period in which a vault cannot participate in issue, redeem or replace requests.

- Measured in Bridge blocks
- Initial value: 1 day (Bridge constant)

ReplaceGriefingCollateral
.........................

Default griefing collateral (in ONE) as a percentage of the to-be-locked ONE collateral of the new vault,  vault has to lock to be replaced by another vault. This collateral will be slashed and allocated to the replacing Vault if the to-be-replaced Vault does not transfer BTC on time.

- Paid in ONE
- Initial value: 0.005%

Maps
----

TotalRewards
.............

Mapping from accounts to their reward balances.


Functions
~~~~~~~~~

distributeVaultRewards
----------------------

Specifies the distribution of fees in the Vault fee pool among individual Vaults.

- Initial values:
    - 90% of Vault fees according to: Vault issued ONEBTC / total issued ONEBTC.
    - 10% of Vault fees according to: Vault locked ONE / total locked ONE

Specification
.............

*Function Signature*

``distributeVaultRewards()``


Function Sequence
.................

1. Calculate the fees assigned to all Vaults using the `BridgeFeePool` and the `VaultRewards`.
2. Calculate the fees for every Vault according to the initial values.
3. Update the `TotalRewards` mapping for the Vault.

distributeRelayerRewards
------------------------

Specifies the distribution of fees in the Staked Relayer fee pool among individual Staked Relayers. This function can implement different reward distributions. We differentiate if the BTC-Bridge operates with the SLA model or without.

- SLA model deactivated:
    - 100% of Staked Relayer fees distributed among active relayers proportional to their locked stake.
- SLA model activated:
    - We distribute rewards to Staked Relayers, based on a scoring system which takes into account their SLA and locked stake.
    - :math:`\text{score(relayer)} = \text{relayer.sla} * \text{relayer.stake}`
    - :math:`\text{reward(relayer)} = \text{totalReward} / \text{totalRelayerScore} * \text{relayer.score}` where totalReward is the amount of fees currently distributed and totalRelayerScore is the sum of the scores of all active Staked Relayers.

Specification
.............

*Function Signature*

``distributeRelayerRewards()``


Function Sequence
.................

1. Calculate the fees assigned to all Staked Relayers using the `BridgeFeePool` and the `StakedRelayerRewards`.
2. Calculate the fees for every Staked Relayer according to the reward distribution mode (SLA model activated/deactivated).
3. Update the `TotalRewards` mapping for the Staked Relayer.

.. _withdrawFees:

withdrawFees
------------

A function that allows staked relayers, vaults, collators and maintainers to withdraw the fees earned.

Specification
.............

*Function Signature*

``withdrawFees(account, currency, amount)``

*Parameters*

* ``account``: the account withdrawing fees
* ``currency``: the currency of the fee to withdraw
* ``amount``: the amount to withdraw

*Events*

* ``WithdrawFees(account, currency, amount)``

Function Sequence
.................

1. Transfer the request amount to the account in case the balance is sufficient.
2. Update the `TotalRewards` of the account.

Events
~~~~~~

WithdrawFees
------------

*Event Signature*

``WithdrawFees(account, currency, amount)``

*Parameters*

* ``account``: the account withdrawing fees
* ``currency``: the currency of the fee to withdraw
* ``amount``: the amount to withdraw

*Functions*

* :ref:`withdrawFees`

