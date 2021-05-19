.. _sla:

SLA
===

Overview
~~~~~~~~

The SLA implements the scheme outline in the :ref:`service_level_agreements`. Its main purpose is to store and compute Vault and Staked Relayer SLAs.

We define an SLA value as a real number between 0 and 100: :math:`\text{SLA} = [0, 100)`

Initially, all vaults and staked relayer have an SLA of 0 (lowest SLA). Through the performance of predefined “desired actions”, they can increase their SLA to a maximum of 100 (highest SLA).

SLAs are used twofold:

- **Vaults:** Vaults with high SLAs avoid having their entire collateral slashed in case they fail to correctly execute a Redeem request (i.e., only the minimum amount of collateral is slashed, defined by the LiquidationThreshold)
- **Staked Relayers:** For Staked Relayers, the SLA has a direct impact on the earned fees.


Step-by-step
------------

1. Vault and Staked Relayers interact with the BTC-Parachain.
2. Certain actions have an impact on their SLA. If this is the case, the function updates the SLA score of the Vault or Staked Relayer accordingly.
3. The SLA is stored for each Vault and Staked Relayer to impact collateral slashing for Vaults and for fee allocation to Staked Relayers.


Data Model
~~~~~~~~~~

Scalars (Vaults)
----------------

VaultSLATarget
..............

Target value for Vault SLAs. 

- Initial value: 100

FailedRedeem (Decrease)
.......................

- Initial value: -100

ExecutedIssue (Increase)
........................

Based on volume of the issue request as compared to the average issue request size (avgIssueSizeN) of the last N issue requests. 
SLAIncrease = max(requestSize / avgIssueSizeN * maxSLA, maxSLA)

- Initial value: maxSLA = 4

SubmitIssueProof (Increase)
...........................

 Vault submits correct Issue proof on behalf of the user.

- Initial value: 1


Scalars (Staked Relayers)
-------------------------

Staked Relayer SLA Target
.........................

Target value for Staked Relayer SLAs

- Initial value: 100

Block Submission (Increase)
...........................

- Initial value: +1

Correct NoData Report/Vote (Increase)
.....................................

- Initial value: +1

Correct Invalid Report/Vote (Increase)
......................................

- Initial value: +10

Correct Theft Report (Increase)
...............................

- Initial value: +1

Correct Oracle Offline Report (Increase)
........................................

- Initial value: +1

False NoData Report/Vote (Decrease)
...................................

- Initial value: -10

False Invalid Report/Vote (Decrease)
....................................

- Initial value: -100

Ignored Vote (Decrease)
.......................

- Initial value: -10

Maps
----

VaultSLA
........

Mapping from Vault accounts to their SLA score.

StakedRelayerSLA
................

Mapping from Staked Relayer accounts to their SLA score.

Functions
~~~~~~~~~

.. _SlashAmountVault:

SlashAmountVault
----------------

We reduce the amount of slashed collateral based on a Vaults SLA. The minimum amount slashed is given by the ``LiquidationThreshold``, the maximum amount slashed by the ``PremiumRedeemThreshold``. The actual slashed amount of collateral is a linear function parameter zed by the two thresholds:

:math:`\text{MinSlashed} = \text{LiquidationThreshold} - 100\%` (currently 10%)
:math:`\text{MaxSlashed} = \text{PremiumRedeemThreshold} - 100\%` (currently 30%)

:math:`\text{RealSlashed} = (\text{MaxSlashed} - \text{MinSlashed}) / \text{SLATarget} * \text{SLA}`
    :math:`+ (\text{LiquidationThreshold} - 100\%)`



Specification
.............

*Function Signature*

``SlashVault(account)``

*Parameters*

* ``account``: The account ID of the vault.

*Returns*

* ``rate``: The rate (in %) to-be-slashed.

Function Sequence
.................

1. Based on the Vault's SLA, calculate the to-be-slashed percentage based on the formula above.

.. _updateSLA:

updateSLA
---------

Updates the SLA of a Vault or Relayer.

Specification
.............

*Function Signature*

``updateSLA(account, delta)``

*Parameters*

* ``account``: the account that will be updated
* ``delta``: the increase or decrease in the sla score.

*Events*

* ``UpdateSLA``

Events
~~~~~~

UpdateSLA
---------

*Event Signature*

``UpdateSLA(account, total_score, delta)``

*Parameters*

* ``account``: the account that will be updated
* ``total_score``: the SLA score of the account after the update
* ``delta``: the increase or decrease in the sla score.

*Functions*

* :ref:`updateSLA`

