.. _incentives:

Economic Incentives
===================

Incentives are the core of decentralized systems. Fundamentally, actors in decentralized systems participate in a game where each actor attempts to maximize its utility. Designs of such decentralized systems need to encode a mechanism that provides clear incentives for actors to adhere to protocol rules while discouraging undesired behavior. Specifically, actors make risk-based decisions: payoffs associated with the execution of certain actions are compared against the risk incurred by the action. The BTC Bridge, being an open system with multiple distinct stakeholders, must hence offer a mechanism to assure honest participation outweighs subversive strategies.

The overall objective of the incentive mechanism is an optimization problem with private information in a dynamic setting. Users need to pay fees to Vaults in return for their service. On the one hand, user fees should be low enough to allow them to profit from having ONEBTC (e.g., if a user stands to gain from earning interest in a stablecoin system using ONEBTC, then the fee for issuing ONEBTC should not outweigh the interest gain). On the other hand, fees need to be high enough to encourage Vaults and Staked Relayers to lock their ONE in the system and operate Vault/Staked Relayer clients. This problem is amplified as the BTC Bridge does not exist in isolation and Vaults/Staked Relayers can choose to participate in other protocols (e.g., staking, stablecoin issuance) as well. In the following we outline the constraints we see, a minimal viable incentive model, and pointers to further research questions we plan to solve by getting feedback from potential Vaults and Staked Relayers as well as quantitative modeling.


Roles
~~~~~

We can classify four groups of users, or agents, in the BTC Bridge system. This is mainly based on their prior cryptocurrency holdings - namely BTC and ONE.

Users
-----

- **Protocol role** Users lock BTC with Vaults to create ONEBTC. They hold and/or use ONEBTC for payments, lending, or investment in financial products. At some point, users redeem ONEBTC for BTC by destroying the backed assets.
- **Economics** A user holds BTC and has exposure to an exchange rate from BTC to other assets. A user’s incentives are based on the services (and their rewards) available when issuing ONEBTC.
- **Risks** A user gives up custody over their BTC to a Vault. The Vault is over-collateralized in ONE (i.e., compared to the USD they will lose when taking away the user’s BTC), however, in a market crisis with significant price drops and liquidity shortages, Vaults might choose to keep the BTC. Users will be reimbursed with ONE in that case - not the currency they initially started out with.

Vaults
------

- **Protocol role** Vaults lock up ONE collateral in the BTC Bridge and hold users’ BTC (i.e., receive custody). When users wish to redeem ONEBTC for BTC, Vaults release BTC to users according to the events received from the BTC Bridge.
- **Economics** Vaults hold ONE and thus have exposure to the ONE price against other assets. Vaults inherently make a bet that ONE will increase in value against other assets – otherwise they would simply exchange ONE against their preferred asset(s). This is a simplified view of the underlying problem. In reality, we need to additionally consider nominated vaults as well as vault pooling. Moreover, the inflation of ONE will play a major role in selection of the asset that fees should be paid in.
- **Risks** A Vault backs a set of ONEBTC with ONE collateral. If the exchange rate of the ONE/BTC pair drops the Vault stands at risk to not be able to keep the required level of over-collateralization. This risk can be elevated by a shortage of liquidity.


Staked Relayers
---------------

- **Protocol role** Staked Relayers run Bitcoin full nodes and submit block headers to BTC-Relay, ensuring it remains up to date with Bitcoin’s state. They also report failures occurring on Bitcoin (missing transactional data or invalid blocks) and report misbehaving Vaults who have allegedly stolen BTC (move BTC outside of BTC Bridge constraints). Staked Relayers lock ONE as collateral to disincentivize false ﬂagging on Vaults and Bitcoin failures.
- **Economics** Staked Relayers are exposed to similar mechanics as Vaults, since they also hold ONE. However, they have no direct exposure to the BTC/ONE exchange rate, since they (typically, at least as part of the BTC Bridge) do not hold BTC. As such, Staked Relayers can purely be motivated to earn interest on ONE, but can also have the option to earn interest in ONEBTC and optimize their holdings depending on the best possible return at any given time.
- **Risks** Staked Relayers need to keep an up-to-date Bitcoin full node running to receive the latest blocks and be able to verify transaction availability and validity. They might risk voting on wrong status update proposals for the BTC Bridge if their node is being attacked, e.g. eclipse or DoS attacks.


Collators
---------

- **Protocol role** Collators are full nodes on both a shard and the Relay Chain. They collect shard transactions and produce state transition proofs for the validators on the Relay Chain. They can also send and receive messages from other shards using XCMP.

Processes
~~~~~~~~~

We will now explain how each of the four agent types above profits from participating in the BTC Bridge. Specifically, we sketch a typical interaction ﬂow with the BTC Bridge and explain how each agent type behaves.

Issue process
-------------

The first step is to issue ONEBTC and give users access to other protocols.

1. A Vault locks an amount of ONE in the BTC Bridge.
2. A user requests to issue a certain amount of ONEBTC. A user can directly select a Vault to issue with. If the user does not select a Vault, a Vault is automatically selected with preference given to Vaults with higher SLA rating. In the first iteration of the protocol this selection is deterministic.
3. The user transfers the equivalent amount of BTC that he wants to issue to the Vault. Additionally, the user provides a fee in BTC that is locked with the Vault as well.
4. The user proves the transfer of BTC to the BTC Bridge and receives the requested amount of newly issued ONEBTC.
5. The fees paid by the users are issued as ONEBTC as well. They are forwarded to a general fee pool and distributed according to a configurable distribution to all Vaults, Staked Relayers, Maintainers, and Collators. This ensures that all participants earn on new issue requests, independent if their current collateral is already reserved or not.
6. The user can then freely use the issued ONEBTC to participate in any other protocol deployed on the BTC Bridge and connected Bridges.


Redeem process
--------------

The BTC Bridge is intended to primarily incentivize users to issue ONEBTC and minimize friction to redeem BTC. Hence, the redeem process is structured in a simple way with providing the same incentives to all participating Vaults. Moreover, Vaults are punished for not fulfilling a redeem request in time.

A user can retry to redeem with other Vaults in case a redeem request is not fulfilled. In this case, the non-fulfilling Vault will be punished not by the entire BTC amount but rather by a smaller amount.

1. A user requests to redeem ONEBTC for BTC with a Vault and locks the equivalent amount of ONEBTC.
2. The Vault sends the BTC minus the globally defined fee to the user.
3. The fee is kept in ONEBTC and, equally to the issue process, paid into the fee pool to be distributed among all participants.
4. The Vault proves correct redeem with the BTC Bridge and unlocks the ONE collateral in return.
5. The Vault can decide to keep the ONE collateral in the BTC Bridge to participate in issue requests or withdraw the collateral.


ONEBTC interest process
-------------------------

Fees paid in ONEBTC (on Issue, Redeem, and Replace) are forwarded to a fee pool.
The fee pool then distributes the ONEBTC fees to all Vaults, Staked Relayers, Maintainers, and Collators according to a configurable distribution, and, if implemented, depending on the SLA score.
All participants are able to withdraw their accumulated fees at any time.

ONE interest process
--------------------

Fees paid in ONE are forwarded to a fee pool.
The fee pool then distributes the ONEBTC fees to all Vaults, Staked Relayers, Maintainers, and Collators according to a configurable distribution, and, if implemented, depending on the SLA score.
All participants are able to withdraw their accumulated fees at any time.

Arbitrage
---------

After the issue process is completed a user can access any protocol deployed on Harmony using ONEBTC. Not everyone that wants to obtain ONEBTC has to take this route. We imagine that liquidity providers issue ONEBTC and exchange these for other assets in the Harmony ecosystem. The price of ONEBTC and BTC will hence be decoupled.

Price decoupling of BTC and ONEBTC, in turn, can be used by arbitrage traders. If ONEBTC trades relatively higher than BTC, arbitrage traders will seek to issue new ONEBTC with their existing BTC to sell ONEBTC at a higher market price. In case BTC trades above ONEBTC, arbitrageurs seek to redeem ONEBTC for BTC and trade these at a higher market price.


Constraints
~~~~~~~~~~~

We sketched above how each agent can be motivated to participate based on their incentive. However, determining the fee model, including how much a user should pay in BTC fees or the interest earned in ONE or ONEBTC by Vaults and Staked Relayers, requires careful consideration. These numbers depend on certain constraints than can be roughly categorized in two parts:

1. **Inherent risks**: Each agent takes on different risks that include, for example, giving up custody of their BTC, exchange rate risk on the ONE/BTC pair, costs to maintain the infrastructure to operate Vault and Staked Relayer clients, as well as trusting the BTC Bridge to operate correctly and as designed.
2. **Opportunity costs**: Each agent might decide to take an alternative path to receive the desired incentives. For example, users might pick a different platform or bridge to utilize their BTC. Also Vaults, Staked Relayers, and Keepers might pick other protocols to earn interest on their ONE holdings.

We provide an overview of the risks and alternatives for the agents in Table 1. When an agent is exposed to a high risk and has several alternatives, the agent needs to receive an accordingly high reward in return: if the risks and alternatives outweigh the incentives for an agent, the agent will not join the BTC Bridge. As seen in already deployed protocols including wBTC and pTokens, experiencing – to this date – insignificant volume, the balance of risks, alternatives, and incentives need to motivate agents to join.

*Table 1*: A subjective rating of the risks and alternatives for each agent. Risk ratings are from low to high. Alternatives ratings are also from low to high, where “high" indicates the existence of numerous viable alternatives, while “low“ indicates that the BTC Bridge is the dominant option on the market.

.. tabularcolumns:: |l|l|p{0.3\linewidth}|l|p{0.3\linewidth}|

+----------------+-------------+-----------------------------------------------------------------------------------------------------------------------------------------+------------------+-----------------------------------------------------------------------+
| Agent          | Risk rating | Risks                                                                                                                                   | Opportunity cost | Alternatives                                                          |
+----------------+-------------+-----------------------------------------------------------------------------------------------------------------------------------------+------------------+-----------------------------------------------------------------------+
| User           | high        | Counterparty (Vault, Staked Relayer), Technical risk (BTC Bridge), Market risks (ONE/BTC volatility and liquidity through Vault)        | medium           | wBTC, tBTC, RenVM, ChainX                                             |
+----------------+-------------+-----------------------------------------------------------------------------------------------------------------------------------------+------------------+-----------------------------------------------------------------------+
| Vault          | high        | Counterparty (Staked Relayer), Technical risk (BTC Bridge, Vault client), Market risks (ONE/BTC volatility and liquidity)               | high             | Staking (relay chain, Bridges), Lending (Acala), Trading (Laminar)    |
+----------------+-------------+-----------------------------------------------------------------------------------------------------------------------------------------+------------------+-----------------------------------------------------------------------+
| Staked Relayer | low         | Technical risk (BTC Bridge, relayer client, Bitcoin client)                                                                             | high             | Staking (relay chain, Bridges), Lending (Acala), Trading (Laminar)    |
+----------------+-------------+-----------------------------------------------------------------------------------------------------------------------------------------+------------------+-----------------------------------------------------------------------+
| Keeper         | high        | Counterparty (Staked Relayer), Technical risk (BTC Bridge, Vault and Keeper client), Market risks (ONE/BTC volatility and liquidity)    | high             | Staking (relay chain, Bridges), Lending (Acala), Trading (Laminar)    |
+----------------+-------------+-----------------------------------------------------------------------------------------------------------------------------------------+------------------+-----------------------------------------------------------------------+