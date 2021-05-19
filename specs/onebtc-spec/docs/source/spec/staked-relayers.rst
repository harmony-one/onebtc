.. _staked-relayers:

Staked Relayers
===============

The :ref:`staked-relayers` module is responsible for handling the registration and staking of Staked Relayers. 
It also wraps functions for Staked Relayers to submit Bitcoin block headers to the :ref:`btc-relay`. 


Overview
~~~~~~~~

**Staked Relayers** are participants whose main role it is to run Bitcoin full nodes and:
    
    1. Submit valid Bitcoin block headers to increase their :ref:`sla` score.
    2. Check vaults do not move BTC, unless expressly requested during :ref:`redeem-protocol`, :ref:`replace-protocol` or :ref:`refund-protocol`.

 In the second case, a single staked relayer report suffices - the module should check the accusation (using a Merkle proof), and liquidate the vault if valid. 


Staked Relayers are overseen by the Parachain **Governance Mechanism**. 
The Governance Mechanism also votes on critical changes to the architecture or unexpected failures, e.g. hard forks or detected 51% attacks (if a fork exceeds the specified security parameter *k*, see `Security Parameter k <https://interlay.gitlab.io/polkabtc-spec/btcrelay-spec/security_performance/security.html#security-parameter-k>`_.). 



Data Model
~~~~~~~~~~

Structs
--------

StakedRelayer
..............

Stores the information of a Staked Relayer.

.. tabularcolumns:: |l|l|L|

=========================  =========  ========================================================
Parameter                  Type       Description
=========================  =========  ======================================================== 
``stake``                  Backing    Total amount of collateral/stake provided by this Staked Relayer.
=========================  =========  ========================================================


Data Storage
~~~~~~~~~~~~

Constants
---------

STAKED_RELAYER_STAKE
......................

Integer denoting the minimum stake which Staked Relayers must provide when registering. 


Maps
----

StakedRelayers
...............

Mapping from accounts of StakedRelayers to their struct. ``<Account, StakedRelayer>``.


TheftReports
.............

Mapping of Bitcoin transaction identifiers (SHA256 hashes) to account identifiers of Vaults who have been caught stealing Bitcoin.
Per Bitcoin transaction, multiple Vaults can be accused (multiple inputs can come from multiple Vaults). 
This mapping is necessary to prevent duplicate theft reports.


Functions
~~~~~~~~~

.. _registerStakedRelayer:

registerStakedRelayer
----------------------

Registers a new Staked Relayer, locking the provided collateral, which must exceed ``STAKED_RELAYER_STAKE``.

Specification
.............

*Function Signature*

``registerStakedRelayer(stakedRelayer, stake)``

*Parameters*

* ``stakedRelayer``: The account of the staked relayer to be registered.
* ``stake``: to-be-locked collateral/stake.

*Events*

* ``RegisterStakedRelayer(StakedRelayer, collateral)``: emit an event stating that a new staked relayer (``stakedRelayer``) was registered and provide information on the Staked Relayer's stake (``stake``). 

*Errors*

* ``ERR_ALREADY_REGISTERED = "This AccountId is already registered as a Staked Relayer"``: The given account identifier is already registered. 
* ``ERR_INSUFFICIENT_STAKE = "Insufficient stake provided"``: The provided stake was insufficient - it must be above ``STAKED_RELAYER_STAKE``.


Preconditions
.............

Function Sequence
.................

The ``registerStakedRelayer`` function takes as input an AccountID and collateral amount (to be used as stake) to register a new staked relayer in the system.

1) Check that the ``stakedRelayer`` is not already in ``StakedRelayers``. Return ``ERR_ALREADY_REGISTERED`` if this check fails.

2) Check that ``stake > STAKED_RELAYER_STAKE`` holds, i.e., the staked relayer provided sufficient collateral. Return ``ERR_INSUFFICIENT_STAKE`` error if this check fails.

3) Lock the stake/collateral by calling :ref:`lockCollateral` and passing ``stakedRelayer`` and the ``stake`` as parameters.

4) Store the provided information (amount of ``stake``) in a new ``StakedRelayer`` and insert it into the ``StakedRelayers`` mapping using the ``stakedRelayer`` AccountId as key.

5) Emit a ``RegisterStakedRelayer(StakedRelayer, collateral)`` event. 


.. _deRegisterStakedRelayer:

deRegisterStakedRelayer
-----------------------

De-registers a Staked Relayer, releasing the associated stake.

Specification
.............

*Function Signature*

``registerStakedRelayer(stakedRelayer)``

*Parameters*

* ``stakedRelayer``: The account of the staked relayer to be de-registered.

*Events*

* ``DeRegisterStakedRelayer(StakedRelayer)``: emit an event stating that a staked relayer has been de-registered (``stakedRelayer``).

*Errors*

* ``ERR_NOT_REGISTERED = "This AccountId is not registered as a Staked Relayer"``: The given account identifier is not registered. 

Preconditions
.............

Function Sequence
.................

1) Check if the ``stakedRelayer`` is indeed registered in ``StakedRelayers``. Return ``ERR_NOT_REGISTERED`` if this check fails.

3) Release the stake/collateral of the ``stakedRelayer`` by calling :ref:`lockCollateral` and passing ``stakedRelayer`` and the ``StakeRelayer.stake`` (as retrieved from ``StakedRelayers``) as parameters.

4) Remove the entry from ``StakedRelayers`` which has ``stakedRelayer`` as key.

5) Emit a ``DeRegisterStakedRelayer(StakedRelayer)`` event. 


.. _slashStakedRelayer: 

slashStakedRelayer
----------------------

Slashes the stake/collateral of a staked relayer and removes them from the staked relayer list (mapping).

.. warning:: This function can only be called by the Governance Mechanism.


Specification
.............

*Function Signature*

``slashStakedRelayer(governanceMechanism, stakedRelayer)``

*Parameters*

* ``governanceMechanism``: The AccountId of the Governance Mechanism.
* ``stakedRelayer``: The account of the staked relayer to be slashed.


*Events*

* ``SlashStakedRelayer(stakedRelayer)``: emits an event indicating that a given staked relayer (``stakedRelayer``) has been slashed and removed from ``StakedRelayers``.

*Errors*

* ``ERR_GOVERNANCE_ONLY = This action can only be executed by the Governance Mechanism``: Only the Governance Mechanism can slash Staked Relayers.
* ``ERR_NOT_REGISTERED = "This AccountId is not registered as a Staked Relayer"``: The given account identifier is not registered. 


Function Sequence
.................

1. Check that the caller of this function is indeed the Governance Mechanism. Return ``ERR_GOVERNANCE_ONLY`` if this check fails.

2. Retrieve the staked relayer with the given account identifier (``stakedRelayer``) from ``StakedRelayers``. Return ``ERR_NOT_REGISTERED`` if not staked relayer with the given identifier can be found.

3. Confiscate the Staked Relayer's collateral. For this, call :ref:`slashCollateral` providing ``stakedRelayer`` and ``governanceMechanism`` as parameters.

4. Remove ``stakedRelayer`` from ``StakedRelayers``

5. Emit ``SlashStakedRelayer(stakedRelayer)`` event.


.. _reportVaultTheft:

reportVaultTheft
-----------------

A staked relayer reports misbehavior by a vault, providing a fraud proof (malicious Bitcoin transaction and the corresponding transaction inclusion proof). 

A vault is not allowed to move BTC from any registered Bitcoin address (as specified by ``Vault.wallet``), except in the following three cases:

   1) The vault is executing a :ref:`redeem-protocol`. In this case, we can link the transaction to a ``RedeemRequest`` and check the correct recipient. 
   2) The vault is executing a :ref:`replace-protocol`. In this case, we can link the transaction to a ``ReplaceRequest`` and check the correct recipient. 
   3) The vault is executing a :ref:`refund-protocol`. In this case, we can link the transaction to a ``RefundRequest`` and check the correct recipient. 
   4) [Optional] The vault is "merging" multiple UTXOs it controls into a single / multiple UTXOs it controls, e.g. for maintenance. In this case, the recipient address of all outputs (e.g. ``P2PKH`` / ``P2WPKH``) must be the same Vault. 

In all other cases, the vault is considered to have stolen the BTC.

This function checks if the vault actually misbehaved (i.e., makes sure that the provided transaction is not one of the above valid cases) and automatically liquidates the vault (i.e., triggers :ref:`redeem-protocol`).


Specification
.............

*Function Signature*

``reportVaultTheft(vault, merkleProof, rawTx)``


*Parameters*

* ``vaultId``: the account of the accused Vault.
* ``merkleProof``: Merkle tree path (concatenated LE SHA256 hashes).
* ``rawTx``: Raw Bitcoin transaction including the transaction inputs and outputs.


*Events*

* ``ReportVaultTheft(vault)`` - emits an event indicating that a vault (``vault``) has been caught displacing BTC without permission.

*Errors*

* ``ERR_STAKED_RELAYERS_ONLY = "This action can only be executed by Staked Relayers"``: The caller of this function was not a Staked Relayer. Only Staked Relayers are allowed to suggest and vote on BTC Parachain status updates.
* ``ERR_ALREADY_REPORTED = "This txId has already been logged as a theft by the given Vault"``: This transaction / vault combination has already been reported.
* ``ERR_VAULT_NOT_FOUND = "There exists no vault with the given account id"``: The specified vault does not exist. 
* ``ERR_ALREADY_LIQUIDATED = "This vault is already being liquidated``: The specified vault is already being liquidated.
* ``ERR_VALID_REDEEM = "The given transaction is a valid Redeem execution by the accused Vault"``: The given transaction is associated with a valid :ref:`redeem-protocol`.
* ``ERR_VALID_REPLACE = "The given transaction is a valid Replace execution by the accused Vault"``: The given transaction is associated with a valid :ref:`replace-protocol`.
* ``ERR_VALID_REFUND = "The given transaction is a valid Refund execution by the accused Vault"``: The given transaction is associated with a valid :ref:`refund-protocol`.
* ``ERR_VALID_MERGE_TRANSACTION = "The given transaction is a valid 'UTXO merge' transaction by the accused Vault"``: The given transaction represents an allowed "merging" of UTXOs by the accused vault (no BTC was displaced).


Function Sequence
.................

1. Check that the caller of this function is indeed a Staked Relayer. Return ``ERR_STAKED_RELAYERS_ONLY`` if this check fails.

2. Check if the specified ``vault`` exists in ``Vaults`` in :ref:`vault-registry`. Return ``ERR_VAULT_NOT_FOUND`` if there is no vault with the specified account identifier.

3. Check if this ``vault`` has already been liquidated. If this is the case, return ``ERR_ALREADY_LIQUIDATED`` (no point in duplicate reporting).

4. Check if the given Bitcoin transaction is already associated with an entry in ``TheftReports`` (calculate ``txId`` from ``rawTx`` as key for lookup). If yes, check if the specified ``vault`` is already listed in the associated set of Vaults. If the vault is already in the set, return ``ERR_ALREADY_REPORTED``. 

5. Extract the ``outputs`` from ``rawTx`` using `extractOutputs` from the BTC-Relay.

6. Check if the transaction is a "migration" of UTXOs to the same Vault. For each output, in the extracted ``outputs``, extract the recipient Bitcoin address (using `extractOutputAddress` from the BTC-Relay). 

   a) If one of the extracted Bitcoin addresses does not match a Bitcoin address of the accused ``vault`` (``Vault.wallet``) **continue to step 7**. 

   b) If all extracted addresses match the Bitcoin addresses of the accused ``vault`` (``Vault.wallet``), abort and return ``ERR_VALID_MERGE_TRANSACTION``.

7. Check if the transaction is part of a valid :ref:`redeem-protocol`, :ref:`replace-protocol` or :ref:`refund-protocol` process. 

  a) Extract the OP_RETURN value using `extractOPRETURN` from the BTC-Relay. If this call returns an error (no valid OP_RETURN output, hence not valid :ref:`redeem-protocol`, :ref:`replace-protocol` or :ref:`refund-protocol` process), **continue to step 8**. 

  c) Check if the extracted OP_RETURN value matches any ``redeemId`` in ``RedeemRequest`` (in ``RedeemRequests`` in :ref:`redeem-protocol`), any ``replaceId`` in ``ReplaceRequest`` (in ``RedeemRequests`` in :ref:`redeem-protocol`) or any ``refundId`` in ``RefundRequest`` (in ``RefundRequests`` in :ref:`refund-protocol`) entries *associated with this Vault*. If no match is found, **continue to step 8**.

  d) Otherwise, if an associated ``RedeemRequest``, ``ReplaceRequest`` or ``RefundRequest`` was found: extract the value (using `extractOutputValue` from the BTC-Relay) and recipient Bitcoin address (using `extractOutputAddress` from the BTC-Relay). Next, check:

      i ) if the value is equal (or greater) than ``paymentValue`` in the ``RedeemRequest``, ``ReplaceRequest`` or ``RefundRequest``. 
     
      ii ) if the recipient Bitcoin address matches the recipient specified in the ``RedeemRequest``, ``ReplaceRequest`` or ``RefundRequest``.

      iii ) if the change Bitcoin address(es) are registered to the accused ``vault`` (``Vault.wallet``).

    If all checks are successful, abort and return ``ERR_VALID_REDEEM``, ``ERR_VALID_REPLACE`` or ``ERR_VALID_REFUND``. Otherwise, **continue to step 8**.

8. The vault misbehaved (displaced BTC). 

    a) Call :ref:`liquidateVault`, liquidating the vault and transferring all of its balances and collateral to the ``LiquidationVault`` for failure and reimbursement handling;

    b) emit ``ReportVaultTheft(vaultId)``
  
9. Return


Events
~~~~~~~

RegisterStakedRelayer
----------------------

Emit an event stating that a new staked relayer was registered and provide information on the Staked Relayer's stake

*Event Signature*

``RegisterStakedRelayer(StakedRelayer, collateral)``

*Parameters*

* ``stakedRelayer``: newly registered staked Relayer
* ``stake``: stake provided by the staked relayer upon registration 

*Functions*

* :ref:`registerStakedRelayer`


DeRegisterStakedRelayer
-------------------------

Emit an event stating that a staked relayer has been de-registered 

*Event Signature*

``DeRegisterStakedRelayer(StakedRelayer)``

*Parameters*

* ``stakedRelayer``: account identifier of de-registered Staked Relayer

*Functions*

* :ref:`deRegisterStakedRelayer`


SlashStakedRelayer
-------------------

Emits an event indicating that a staked relayer has been slashed.


*Event Signature*

``SlashStakedRelayer(stakedRelayer)``

*Parameters*

* ``stakedRelayer``: account identifier of the slashed staked relayer.

*Functions*

* :ref:`slashStakedRelayer`


ReportVaultTheft
-------------------

Emits an event when a vault has been accused of theft.

*Event Signature*

``ReportVaultTheft(vault)``

*Parameters*

* ``vault``: account identifier of the vault accused of theft. 

*Functions*

* :ref:`reportVaultTheft`

Errors
~~~~~~~

``ERR_NOT_REGISTERED``

* **Message**: "This AccountId is not registered as a Staked Relayer."
* **Function**: :ref:`deRegisterStakedRelayer`, :ref:`slashStakedRelayer`
* **Cause**: The given account identifier is not registered. 

``ERR_GOVERNANCE_ONLY``

* **Message**: "This action can only be executed by the Governance Mechanism"
* **Function**: :ref:`slashStakedRelayer`
* **Cause**: The suggested status (``SHUTDOWN``) can only be triggered by the Governance Mechanism but the caller of the function is not part of the Governance Mechanism.

``ERR_STAKED_RELAYERS_ONLY``

* **Message**: "This action can only be executed by Staked Relayers"
* **Function**: :ref:`reportVaultTheft`
* **Cause**: The caller of this function was not a Staked Relayer. Only Staked Relayers are allowed to suggest and vote on BTC Parachain status updates.

``ERR_ALREADY_REPORTED``

* **Message**: "This txId has already been logged as a theft by the given Vault"
* **Function**: :ref:`reportVaultTheft`
* **Cause**: This transaction / vault combination has already been reported.

``ERR_VAULT_NOT_FOUND``

* **Message**: "There exists no vault with the given account id"
* **Function**: :ref:`reportVaultTheft`
* **Cause**:  The specified vault does not exist. 

``ERR_ALREADY_LIQUIDATED``

* **Message**: "This vault is already being liquidated"
* **Function**: :ref:`reportVaultTheft`
* **Cause**:  The specified vault is already being liquidated.

``ERR_VALID_REDEEM``

* **Message**: "The given transaction is a valid Redeem execution by the accused Vault"
* **Function**: :ref:`reportVaultTheft`
* **Cause**: The given transaction is associated with a valid :ref:`redeem-protocol`.

``ERR_VALID_REPLACE``

* **Message**: "The given transaction is a valid Replace execution by the accused Vault"
* **Function**: :ref:`reportVaultTheft`
* **Cause**: The given transaction is associated with a valid :ref:`replace-protocol`.

``ERR_VALID_REFUND``

* **Message**: "The given transaction is a valid Refund execution by the accused Vault"
* **Function**: :ref:`reportVaultTheft`
* **Cause**: The given transaction is associated with a valid :ref:`refund-protocol`.

``ERR_VALID_MERGE_TRANSACTION``

* **Message**: "The given transaction is a valid 'UTXO merge' transaction by the accused Vault"
* **Function**: :ref:`reportVaultTheft`
* **Cause**: The given transaction represents an allowed "merging" of UTXOs by the accused vault (no BTC was displaced).
