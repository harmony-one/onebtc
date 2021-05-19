.. _service_level_agreements:

Service Level Agreements
========================

Vaults and Staked Relayers take up critical roles in the BTC-Parachain. Both provide collateral, have clearly defined tasks and face punishment in case of misbehavior. However, slashing collateral for each minor protocol deviation would result in too high risk profiles for Vaults and Staked Relayers, yielding these roles unattractive to users.

As a result, we introduce Service Level Agreements for Vaults and Staked Relayers: being online and following protocol rules increases the SLA, while non-critical failures reduces the rating. Higher SLAs result in higher rewards and preferred treatment where applicable in the Issue and Redeem protocols. If the SLA of a Vault or Staked Relayer falls below a certain threshold, a punishment will be incurred, ranging from a mere collateral penalty up to full collateral confiscation and a system ban.

SLA Value
~~~~~~~~~

The SLA value is a number between 0 and 100. When a Vault or Staked Relayer registers with BTC-Parachain, it starts with an SLA of 0.

SLA Actions
~~~~~~~~~~~

We list below several actions that Vaults and Staked Relayers can execute in the protocol that have an impact on their SLA.

Vaults
------

Desired Actions
...............

- **Execute Issue**: execute redeem, on time with the correct amount.
- **Submit Issue Proof**: Vault submits correct Issue proof on behalf of the user.
- **Forward Additional BTC**: Vault submits correct issue or return proof where the vault is the forwarding vault.
 

Undesired Actions
.................

- **Fail Redeem**: redeem not executed on time (or at all) or with the incorrect amount (more specific: fail to provide inclusion proof for BTC payment to BTC-Relay on time)

Staked Relayers
---------------

Desired Actions
...............

- **Submit BTC block header**: submit a valid Bitcoin block header, that later becomes (**TODO:**define delay to not punish "good" fork submissions) part of the main chain. 
  - [Optional]: even if the block header already is stored, an additional confirmation is treated as beneficial action. This needs to be **time-bounded**. Otherwise, resubmitting old blocks allows to improve SLA, while adding no security and spamming the Parachain)
- **Correctly report theft**: correctly report a Vault for moving BTC outside of the protocol rules (i.e., viewed as theft attempt). 
  - Note: TX inclusion proof must pass (TODO: check how this is currently implemented). 

Undesired Actions
.................

No actions with SLA impact.

Non-SLA Actions
~~~~~~~~~~~~~~~

There are several other actions that do not impact the SLA scores at the moment.
For completeness, we list them here. The SLA model might be revised and the below actions may be considered to impact the SLA in the future.

Vaults
------

Desired Actions
...............

- **Execute Redeem**: execute redeem, on time with the correct amount.
- **Collateralization**: Maintain a collateralization rate above the *Secure Collateral Threshold*. 
- **Execute Replace**: if requested replace, transfer the correct amount of BTC to the new Vault on time.

Undesired Actions
.................

- **Fail Replace**: replace protocol (BTC transfer) not executed on time (or at all) or with the incorrect amount.
- **Undercollateralization**: Collateralization rate below  *Secure Collateral Threshold*. 
- **Strong Undercollateralization**:  Collateralization rate below  *Premium Collateral Threshold*. 
- **Liquidation**:   Collateralization rate below  *Liquidation Collateral Threshold*, which triggers liquidation of the Vault.
- **Theft**: the Vault transfers BTC from its UTXO(s) outside of the protocol rules. There is a dedicated check for this in the BTC-Parachain: only redeem, replace and registered migration of assets are allowed and these are clearly defined. 
- **Repeated Failed Redeem**: repeated failed redeem requests can incur a higher SLA deduction#
- **Repeated Failed Replace**: repeated failed replace requests can incur a higher SLA deduction

Staked Relayers
---------------

Desired Actions
...............

- **Correctly report NO_DATA**: report/vote a block as NO_DATA in case of a majority vote passed
- **Correctly report INVALID**: report/vote a block as INVALID in case of a majority vote passed
- **Correct report LIQUIDATION**: report a Vault for being below the *Liquidation Collateral Threshold* and trigger automatic liquidation. 
- **Correctly report ORACLE_OFFLINE**: correctly report that the/an oracle has not reported data for a pre-defined amount of time (i.e., considered offline).
- **Majority on status update vote**: participate in a status update vote on the **majority** side.
  - Exception: NO_DATA votes are rewarded no matter how the vote was cast. Reason: since NO_DATA does not incur slashing of minority votes, being on the "majority" side must not yield additional benefits here, otherwise this incentivizes "herd" behavior without actually performing checks.  

Undesired Actions
.................

- **Ignore vote**: do not participate in a status update vote.
- **Ignore NO_DATA**: do note vote in a NO_DATA vote at all.
- **Ignore INVALID**: do note vote in an INVALID vote at all.
- **Wrong INVALID report/vote**: report or vote on the **minority** (and persumably wrong side) of an INVALID vote
- **Governance punishment**: the governance mechanism can reduce the SLA of a Vault (e.g. if majority did not vote INVALID, but there was indeed an invalid block, i.e. an attack)

- [Optional] **Minority on status update vote**: vote on the **minority** side. 
  - Since this will also slash collateral in most cases, e.g. INVALID votes (exception: NO_DATA), there may be no need for this extra SLA reduction. 
- [Optional] **Offline**: do not perform **any** of the desired actions within a certain time frame, while being registered. Time needs to be defined. 
- [Optional] **Wrong theft report**: report Vault theft but the BTC transaction turns out to be valid / according to protocol rules.
  - If a such wrong call will automatically fail in the parachain, then there is probably no need for SLA reduction here.  
- [Optional] **Wrong ORCALE_OFFLINE report**: oracle reported offline but was online. A such wrong call will fail in the parachain, so there is probably no need for SLA reduction here. 
- [Optional]: **Wrong LIQUIDATION report**: wrongly report a Vault for being below the *Liquidation Collateral Threshold*.  A such wrong call will fail in the parachain, so there is probably no need for SLA reduction here. 