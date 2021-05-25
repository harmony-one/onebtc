.. _Vault-registry:

Vault Registry
==============

Overview
~~~~~~~~

The vault registry is the central place to manage vaults. Vaults can register themselves here, update their collateral, or can be liquidated.
Similarly, the issue, redeem, refund, and replace protocols call this module to assign vaults during issue, redeem, refund, and replace procedures.
Morever, vaults use the registry to register public key for the :ref:`okd` and register addresses for the :ref:`op-return` scheme.

Data Model
~~~~~~~~~~

Constants
---------

GRANULARITY
...........

The granularity of the ``SecureCollateralThreshold``, ``LiquidationCollateralThreshold``, and ``PunishmentFee``.


Scalars
-------

MinimumCollateralVault
......................

The minimum collateral (ONE) a vault needs to provide to participate in the issue process.

.. note:: This is a protection against spamming the protocol with very small collateral amounts.


PunishmentFee
.............

If a vault misbehaves in either the redeem or replace protocol by failing to prove that it sent the correct amount of BTC to the correct address within the time limit, a vault is punished.
The punishment is the equivalent value of BTC in ONE (valued at the current exchange rate via :ref:`getExchangeRate`) plus a fixed ``PunishmentFee`` that is added as a percentage on top to compensate the damaged party for its loss.
For example, if the ``PunishmentFee`` is set to 50000, it is equivalent to 50%.


PunishmentDelay
.................

If a vault fails to execute a correct redeem or replace, it is *temporarily* banned from further issue, redeem or replace requests.


RedeemPremiumFee
.................

If a vault is running low on collateral and falls below ``PremiumRedeemThreshold``, users are allocated a premium in ONE when redeeming with the vault - as defined by this parameter.
For example, if the ``RedeemPremiumFee`` is set to 5000, it is equivalent to 5%.

SecureCollateralThreshold
..........................

Determines the over-collareralization rate for ONE collateral locked by Vaults, necessary for issuing ONEBTC.
Must to be strictly greater than ``100000`` and ``LiquidationCollateralThreshold``.

The vault can take on issue requests depending on the collateral it provides and under consideration of the ``SecureCollateralThreshold``.
The maximum amount of ONEBTC a vault is able to support during the issue process is based on the following equation:
:math:`\text{max(ONEBTC)} = \text{collateral} * \text{ExchangeRate} / \text{SecureCollateralThreshold}`.

.. note:: As an example, assume we use ``ONE`` as collateral, we issue ``ONEBTC`` and lock ``BTC`` on the Bitcoin side. Let's assume the ``BTC``/``ONE`` exchange rate is ``80``, i.e. one has to pay 80 ``ONE`` to receive 1 ``BTC``. Further, the ``SecureCollateralThreshold`` is 200%, i.e. a vault has to provide two-times the amount of collateral to back an issue request. Now let's say the vault deposits 400 ``ONE`` as collateral. Then this vault can back at most 2.5 ONEBTC as: :math:`400 * (1/80) / 2 = 2.5`.


PremiumRedeemThreshold
......................

Determines the rate for the collateral rate of Vaults, at which users receive a premium in ONE, allocated from the Vault's collateral, when performing a :ref:`redeem-protocol` with this Vault.
Must to be strictly greater than ``100000`` and ``LiquidationCollateralThreshold``.


LiquidationCollateralThreshold
..............................

Determines the lower bound for the collateral rate in ONEBTC. Must be strictly greater than ``100000``. If a Vault's collateral rate drops below this, automatic liquidation (forced Redeem) is triggered.


LiquidationVault
.................
Account identifier of an artificial vault maintained by the VaultRegistry to handle polkaBTC balances and ONE collateral of liquidated Vaults. That is, when a vault is liquidated, its balances are transferred to ``LiquidationVault`` and claims are later handled via the ``LiquidationVault``.


.. note:: A Vault's token balances and ONE collateral are transferred to the ``LiquidationVault`` as a result of automated liquidations and :ref:`reportVaultTheft`.


Maps
----


Vaults
......

Mapping from accounts of Vaults to their struct. ``<Account, Vault>``.


RegisterRequests (Optional)
.............................

Mapping from registerIDs of RegisterRequest to their structs. ``<U256, RegisterRequest>``.


Structs
-------

Vault
.....

Stores the information of a Vault.

.. tabularcolumns:: |l|l|L|

=========================  ==================  ========================================================
Parameter                  Type                Description
=========================  ==================  ========================================================
``toBeIssuedTokens``       ONEBTC              Number of ONEBTC tokens currently requested as part of an uncompleted issue request.
``issuedTokens``           ONEBTC              Number of ONEBTC tokens actively issued by this Vault.
``toBeRedeemedTokens``     ONEBTC              Number of ONEBTC tokens reserved by pending redeem and replace requests.
``collateral``             ONE                 Total amount of collateral provided by this vault (note: "free" collateral is calculated on the fly and updated each time new exchange rate data is received).
``btcAddress``             Wallet<BtcAddress>  A set of Bitcoin address(es) of this vault, to be used for issuing of ONEBTC tokens.
``bannedUntil``            u256                Block height until which this vault is banned from being used for Issue, Redeem (except during automatic liquidation) and Replace .
``status``                 VaultStatus         Current status of the vault (Active, Liquidated, CommittedTheft)
=========================  ==================  ========================================================

.. note:: This specification currently assumes for simplicity that a vault will reuse the same BTC address, even after multiple redeem requests. **[Future Extension]**: For better security, Vaults may desire to generate new BTC addresses each time they execute a redeem request. This can be handled by pre-generating multiple BTC addresses and storing these in a list for each Vault. Caution is necessary for users which execute issue requests with "old" vault addresses - these BTC must be moved to the latest address by Vaults.


RegisterRequest (Optional)
...........................

Optional struct storing data used in the (optional) validity check of the BTC address provided by a vault upon registration.

===================  =========  ========================================================
Parameter            Type       Description
===================  =========  ========================================================
``registerId``       H256       Identifier used to link a Bitcoin transaction inclusion proof to this registration request (included in OP_RETURN).
``vault``            Account    Parachain account identifier of the registered Vault
``timeout``          DateTime   Optional maximum delay before the vault must submit a valid tranasction inclusion proof.
===================  =========  ========================================================

.. *Substrate*::

  #[derive(Encode, Decode, Default, Clone, PartialEq)]
  #[cfg_attr(feature = "std", derive(Debug))]
  pub struct Vault<H256, AccountId, DateTime> {
        registrationID: H256,
        vault: AccountId,
        timeout: DateTime
  }

Functions
~~~~~~~~~


.. _registerVault:

registerVault
-------------

Initiates the registration procedure for a new Vault. The vault provides its BTC address and locks up ONE collateral, which is to be used to the issuing process.

**[Optional]: check valid BTC address**: The new vault provides its BTC address and it's ONE collateral, creating a ``RegistrationRequest``, and receives in return a ``registerID``, which it must include in the OP_RETURN field of a transaction signed by the public key corresponding to the provided BTC address. The proof is checked by the BTC-Relay component, and if successful, the vault is registered.
Note: Collateral can be required to prevent griefing / spamming.


Specification
.............

*Function Signature*

``requestRegistration(vault, collateral, btcAddress)``

*Parameters*

* ``vault``: The account of the vault to be registered.
* ``collateral``: to-be-locked collateral in ONE.


*Events*

* ``RegisterVault(Vault, collateral)``: emit an event stating that a new vault (``vault``) was registered and provide information on the Vault's collateral (``collateral``).

*Errors*

* ``ERR_MIN_AMOUNT``: The provided collateral was insufficient - it must be above ``MinimumCollateralVault``.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must be set to ``RUNNING:0``.

Function Sequence
.................

The ``registerVault`` function takes as input a Parachain AccountID, a Bitcoin address and ONE collateral, and registers a new vault in the system.

1. Check that ``collateral > MinimumCollateralVault`` holds, i.e., the vault provided sufficient collateral (above the spam protection threshold).

  a. Raise ``ERR_MIN_AMOUNT`` error if this check fails.

2. Store the provided data as a new ``Vault``.

3. **[Optional]**: generate a ``registrationID`` which the vault must be include in the OP_RETURN of a new BTC transaction spending BTC from the specified ``btcAddress``. This can be stored in a ``RegisterRequest`` struct, alongside the AccoundID (``vault``) and a timelimit in seconds.

.. _proveValidBTCAddress:

proveValidBTCAddress (Optional)
-------------------------------

A vault optionally may be required to prove that the BTC address is provided during registration is indeed valid, by providing a transaction inclusion proof, showing BTC can be spent from the address.

Specification
.............

*Function Signature*

``proveValidBTCAddress(registrationID, merkleProof, rawTx)``

*Parameters*

* ``registrationID``: identifier of the RegisterRequest
* ``merkleProof``: Merkle tree path (concatenated LE SHA256 hashes).
* ``rawTx``: Raw Bitcoin transaction including the transaction inputs and outputs.


*Events*

* ``ProveValidBTCAddress(vault, btcAddress)``: emit an event stating that a vault (``vault``) submitted a proof that its BTC address is valid.

*Errors*

* ``ERR_INVALID_BTC_ADDRESS``: Not a valid BTC address.
* see ``verifyTransactionInclusion`` in BTC-Relay.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must be set to ``RUNNING:0``.

Function Sequence
.................

1. Retrieve the ``RegisterRequest`` with the given ``registerID`` from ``RegisterRequests``.

  a) Throw ``ERR_INVALID_REGISTER_ID`` error if no active RegisterRequest ``registerID`` can be found in ``RegisterRequests``.

2. Call ``verifyTransactionInclusion(txId, merkleProof)``. If this call returns an error, abort and return the error.

3. Call ``validateTransactionInclusion`` providing the ``rawTx``, ``registerID`` and the vault's Bitcoin address as parameters. If this call returns an error, abort and return the error.

4. Remove the ``RegisterRequest`` with the ``registerID`` from ``RegisterRequests``.

5. Emit a ``ProveValidBTCAddress`` event, setting the ``vault`` account identifier and the vault's Bitcoin address (``Vault.btcAddress``) as parameters.

.. _registerAddress:

registerAddress
---------------

Add a new BTC address to the vault's wallet.

Specification
.............

*Function Signature*

``registerAddress(vaultId: AccountId, address: BtcAddress)``

*Parameters*

* ``vaultId``: the account of the vault.
* ``address``: a valid BTC address.

*Events*

* ``RegisterAddress(vaultId, address)``


Function Sequence
.................

1. Add a new BTC address to the vault's wallet.
2. Set the new BTC address to the primary (default) address.

.. _updatePublicKey:

updatePublicKey
---------------

The vault adds a new public key as a basis for the :ref:`okd`.

Specification
.............

*Function Signature*

``updatePublicKey(vaultId: AccountId, publicKey: BtcPublicKey)``

*Parameters*

* ``vaultId``: the account of the vault.
* ``publicKey``: the BTC public key of the vault to update.

*Events*

* ``UpdatePublicKey(vaultId, publicKey)``


Function Sequence
.................

1. Add a new BTC address to the vault's wallet.
2. Set the new BTC address to the primary (default) address.


.. _lockAdditionalCollateral:

lockAdditionalCollateral
------------------------

The vault locks additional collateral as a security against stealing the Bitcoin locked with it.

Specification
.............

*Function Signature*

``lockCollateral(Vault, collateral)``

*Parameters*

* ``Vault``: The account of the vault locking collateral.
* ``collateral``: to-be-locked collateral in ONE.

: If the locking has completed successfully.

*Events*

* ``LockAdditionalCollateral(Vault, newCollateral, totalCollateral, freeCollateral)``: emit an event stating how much new (``newCollateral``), total collateral (``totalCollateral``) and freely available collateral (``freeCollateral``) the vault calling this function has locked.

*Errors*

* ``ERR_VAULT_NOT_FOUND``: The specified vault does not exist.


Precondition
............

* The BTC Parachain status in the :ref:`security` component must not be set to ``SHUTDOWN: 2``.
* If the BTC Parachain status in the :ref:`security` component is set to ``ERROR: 1``, it must not include the error code ``ORACLE_OFFLINE: 3``.

Function Sequence
.................

1) Retrieve the ``Vault`` from ``Vaults`` with the specified AccountId (``vault``).

  a. Raise ``ERR_VAULT_NOT_FOUND`` error if no such ``vault`` entry exists in ``Vaults``.

2. Increase the ``collateral`` of the ``Vault``.


.. _withdrawCollateral:

withdrawCollateral
------------------

A vault can withdraw its *free* collateral at any time, as long as there remains more collateral (*free or used in backing issued ONEBTC*) than ``MinimumCollateralVault`` and above the ``SecureCollateralThreshold``. Collateral that is currently being used to back issued ONEBTC remains locked until the vault is used for a redeem request (full release can take multiple redeem requests).


Specification
.............

*Function Signature*

``withdrawCollateral(vault, withdrawAmount)``

*Parameters*

* ``vault``: The account of the vault withdrawing collateral.
* ``withdrawAmount``: To-be-withdrawn collateral in ONE.

*Events*

* ``WithdrawCollateral(Vault, withdrawAmount, totalCollateral)``: emit emit an event stating how much collateral was withdrawn by the vault and total collateral a vault has left.

*Errors*

* ``ERR_VAULT_NOT_FOUND = "There exists no vault with the given account id"``: The specified vault does not exist.
* ``ERR_INSUFFICIENT_FREE_COLLATERAL``: The vault is trying to withdraw more collateral than is currently free.
* ``ERR_MIN_AMOUNT``: The amount of locked collateral (free + used) needs to be above ``MinimumCollateralVault``.
* ``ERR_UNAUTHORIZED``: The caller of the withdrawal is not the specified vault, and hence not authorized to withdraw funds.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must be set to ``RUNNING:0``.

Function Sequence
.................

1) Retrieve the ``Vault`` from ``Vaults`` with the specified AccountId (``vault``).

  a. Raise ``ERR_VAULT_NOT_FOUND`` error if no such ``vault`` entry exists in ``Vaults``.

2) Check that the caller of this function is indeed the specified ``Vault`` (AccountId ``vault``).

  a) Raise ``ERR_UNAUTHORIZED`` error is the caller of this function is not the vault specified for withdrawal.

3. Check that ``Vault`` has sufficient free collateral: ``withdrawAmount <= (Vault.collateral - Vault.issuedTokens * SecureCollateralThreshold)``

  a. Raise ``ERR_INSUFFICIENT_FREE_COLLATERAL`` error if this check fails.

4. Check that the remaining **total** (``free`` + used) collateral is greater than ``MinimumCollateralVault`` (``Vault.collateral - withdrawAmount >= MinimumCollateralVault``).

  a. Raise ``ERR_MIN_AMOUNT`` if this check fails. The vault must close its account if it wishes to withdraw collateral below the ``MinimumCollateralVault`` threshold, or request a Replace if some of the collateral is already used for issued ONEBTC.

5. Call the :ref:`releaseCollateral` function to release the requested ``withdrawAmount`` of ONE collateral to the specified Vault's account (``vault`` AccountId) and deduct the collateral tracked for the vault in ``Vaults``: ``Vault.collateral - withdrawAmount``.

6. Emit ``WithdrawCollateral`` event

.. _increaseToBeIssuedTokens:

increaseToBeIssuedTokens
------------------------

.. Reserves a given amount of ONEBTC tokens, i.e., the corresponding ONE collateral amount, calculated via :ref:`getExchangeRate`, is marked as "not free".
.. This function is called from the :ref:`requestIssue` function and is necessary to prevent race conditions (multiple requests trying to use the same amount of collateral).

During an issue request function (:ref:`requestIssue`), a user must be able to assign a vault to the issue request. As a vault can be assigned to multiple issue requests, race conditions may occur. To prevent race conditions, a Vault's collateral is *reserved* when an ``IssueRequest`` is created - ``toBeIssuedTokens`` specifies how much ONEBTC is to be issued (and the reserved collateral is then calculated based on :ref:`getExchangeRate`).
This function further calculates the amount of collateral that will be assigned to the issue request.

Specification
.............

*Function Signature*

``increaseToBeIssuedTokens(vault, tokens)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``tokens``: The amount of ONEBTC to be locked.

*Returns*

* ``btcAddress``: The Bitcoin address of the vault.

*Events*

* ``IncreaseToBeIssuedTokens(vaultId, tokens)``

*Errors*

* ``ERR_EXCEEDING_VAULT_LIMIT``: The selected vault has not provided enough collateral to issue the requested amount.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must be set to ``RUNNING:0``.

Function Sequence
.................

1.  Checks if the selected vault has locked enough collateral to cover the amount of ONEBTC ``tokens`` to be issued. Return ``ERR_EXCEEDING_VAULT_LIMIT`` error if this checks fails. Otherwise, assign the tokens to the vault.

    - Select the ``vault`` from the registry and get the ``vault.toBeIssuedTokens``, ``vault.issuedTokens`` and ``vault.collateral``.
    - Calculate how many tokens can be issued by multiplying the ``vault.collateral`` with the ``ExchangeRate`` (from the :ref:`oracle`) and the ``SecureCollateralThreshold`` considering the ``GRANULARITY`` and subtract the ``vault.issuedTokens`` and the ``vault.toBeIssuedTokens``. Memorize the result as ``available_tokens``.
    - Check if the ``available_tokens`` is equal or greater than ``tokens``. If not enough ``available_tokens`` is free, throw ``ERR_EXCEEDING_VAULT_LIMIT``. Else, add ``tokens`` to ``vault.toBeIssuedTokens``.

2. Get the Bitcoin address of the vault as ``btcAddress``.
3. Return the ``btcAddress``.

.. _decreaseToBeIssuedTokens:

decreaseToBeIssuedTokens
------------------------

A Vault's committed tokens are unreserved when an issue request (:ref:`cancelIssue`) is cancelled due to a timeout (failure!).

Specification
.............

*Function Signature*

``decreaseToBeIssuedTokens(vault, tokens)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``tokens``: The amount of ONEBTC to be unreserved.


*Events*

* ``DecreaseToBeIssuedTokens(vault, tokens)``

*Errors*

* ``ERR_INSUFFICIENT_TOKENS_COMMITTED``: The requested amount of ``tokens`` exceeds the ``toBeIssuedTokens`` by this vault.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must not be set to ``SHUTDOWN: 2``.
* If the BTC Parachain status in the :ref:`security` component is set to ``ERROR: 1``, it must not include the error codes ``INVALID_BTC_RELAY: 2``, ``ORACLE_OFFLINE: 3``, or ``LIQUIDATION: 4``.

.. note:: We allow to cancel pending requests. If the BTC Parachain is in status ``ERROR: 1`` with ``NO_DATA_BTC_RELAY: 1`` and the required BTC transaction is in a block not yet included in the BTC-Relay, the request will not be able to complete. In this case, this function will get called to cancel the request.

.. .. todo:: Exclude a crashed exchange rate oracle failure from this - this call should be allowed even if we have no exchange rate, as it is only used in failed Issue and Replace, or in successful Redeem and Replace. The check for an up-an-running exchange rate oracle is handled separately in each of these protocols, if necessary.

.. .. todo:: I suppose it should always be possible to exit the system?

.. .. comment:: [Alexei] Unfortunately, not really. We need an up-and-running BTC-Relay to prevent Vaults from getting slashed when Redeem or Replace are triggered.


Function Sequence
.................

1. Checks if the amount of ``tokens`` to be released is less or equal to the amount of ``vault.toBeIssuedTokens``. If not, throws ``ERR_INSUFFICIENT_TOKENS_COMMITTED``.

2. Subtracts ``tokens`` from ``vault.toBeIssuedTokens``.


.. _issueTokens:

issueTokens
-----------

The issue process completes when a user calls the :ref:`executeIssue` function and provides a valid proof for sending BTC to the vault. At this point, the ``toBeIssuedTokens`` assigned to a vault are decreased and the ``issuedTokens`` balance is increased by the ``amount`` of issued tokens.

Specification
.............

*Function Signature*

``issueTokens(vault, amount)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``tokens``: The amount of ONEBTC that were just issued.


*Events*

* ``IssueTokens(vault, tokens)``: Emit an event when an issue request is executed.

*Errors*

* ``ERR_INSUFFICIENT_TOKENS_COMMITTED``: Return if the requested amount of ``tokens`` exceeds the ``toBeIssuedTokens`` by this vault.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must not be set to ``SHUTDOWN: 2``.
* If the BTC Parachain status in the :ref:`security` component is set to ``ERROR: 1``, it must not include the error codes ``INVALID_BTC_RELAY: 2``, ``ORACLE_OFFLINE: 3``, or ``LIQUIDATION: 4``.

.. note:: We allow to complete pending requests. If the BTC Parachain is in status ``ERROR: 1`` with ``NO_DATA_BTC_RELAY: 1`` and the required BTC transaction is in a block that is included before the affected block height in the BTC-Relay, the request will be able to complete. In this case, this function will get called to complete the request.

Function Sequence
.................

1. Checks if the amount of ``tokens`` to be released is less or equal to the amount of ``vault.toBeIssuedTokens``. If not, throws ``ERR_INSUFFICIENT_TOKENS_COMMITTED``.

2. Subtracts ``tokens`` from ``vault.toBeIssuedTokens``.

3. Add ``tokens`` to ``vault.issuedTokens``.


.. _increaseToBeRedeemedTokens:

increaseToBeRedeemedTokens
--------------------------

Add an amount tokens to the ``toBeRedeemedTokens`` balance of a vault. This function serves as a prevention against race conditions in the redeem and replace procedures.
If, for example, a vault would receive two redeem requests at the same time that have a higher amount of tokens to be issued than his ``issuedTokens`` balance, one of the two redeem requests should be rejected.

Specification
.............

*Function Signature*

``increaseToBeRedeemedTokens(vault, tokens)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``tokens``: The amount of ONEBTC to be redeemed.


*Events*

* ``IncreaseToBeRedeemedTokens(vault, tokens)``: Emit an event when a redeem request is requested.

*Errors*

* ``ERR_INSUFFICIENT_TOKENS_COMMITTED``: The requested amount of ``tokens`` exceeds the ``IssuedTokens`` by this vault.

Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must not be set to ``SHUTDOWN: 2``.
* If the BTC Parachain status in the :ref:`security` component is set to ``ERROR: 1``, it must not include the error codes ``NO_DATA_BTC_RELAY: 1``, ``INVALID_BTC_RELAY: 2``, or ``ORACLE_OFFLINE: 3``.

.. note:: This function must still be available in case of liquidation of vaults.


Function Sequence
.................

1. Checks if the amount of ``tokens`` to be redeemed is less or equal to the amount of ``vault.IssuedTokens`` minus the ``vault.toBeRedeemedTokens``. If not, throws ``ERR_INSUFFICIENT_TOKENS_COMMITTED``.

2. Add ``tokens`` to ``vault.toBeRedeemedTokens``.


.. _decreaseToBeRedeemedTokens:

decreaseToBeRedeemedTokens
--------------------------

Subtract an amount tokens from the ``toBeRedeemedTokens`` balance of a vault.

Specification
.............

*Function Signature*

``decreaseToBeRedeemedTokens(vault, tokens)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``tokens``: The amount of ONEBTC not to be replaced.


*Events*

* ``DecreaseToBeRedeemedTokens(vault, tokens)``: Emit an event when a replace request cannot be completed because the vault has too little tokens committed.


*Errors*

* ``ERR_INSUFFICIENT_TOKENS_COMMITTED``: The requested amount of ``tokens`` exceeds the ``toBeRedeemedTokens`` by this vault.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must not be set to ``SHUTDOWN: 2``.
* If the BTC Parachain status in the :ref:`security` component is set to ``ERROR: 1``, it must not include the error codes ``ORACLE_OFFLINE: 3`` or ``LIQUIDATION: 4``.

Function Sequence
.................

1. Checks if the amount of ``tokens`` less or equal to the amount of ``vault.toBeRedeemedTokens`` tokens. If not, throws ``ERR_INSUFFICIENT_TOKENS_COMMITTED``.

2. Subtract ``tokens`` from ``vault.toBeRedeemedTokens``.


.. _decreaseTokens:

decreaseTokens
--------------

If a redeem request is not fulfilled, the amount of tokens assigned to the ``toBeRedeemedTokens`` must be removed. Also, we consider the tokens lost at this point and hence remove the ``issuedTokens`` from this vault and punish the vault for not redeeming the tokens.

Specification
.............

*Function Signature*

``decreaseTokens(vault, user, tokens, collateral)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``user``: The BTC Parachain address of the user that made the redeem request.
* ``tokens``: The amount of ONEBTC that were not redeemed.
* ``collateral``: The amount of collateral assigned to this request.


*Events*

* ``DecreaseTokens(vault, user, tokens, collateral)``: Emit an event if a redeem request cannot be fulfilled.

*Errors*

* ``ERR_INSUFFICIENT_TOKENS_COMMITTED``: The requested amount of ``tokens`` exceeds the ``toBeRedeemedTokens`` by this vault.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must not be set to ``SHUTDOWN: 2``.
* If the BTC Parachain status in the :ref:`security` component is set to ``ERROR: 1``, it must not include the error codes ``INVALID_BTC_RELAY: 2`` or ``ORACLE_OFFLINE: 3``.

Function Sequence
.................

1. Checks if the amount of ``tokens`` is less or equal to the amount of ``vault.toBeRedeemedTokens``. If not, throws ``ERR_INSUFFICIENT_TOKENS_COMMITTED``.

2. Subtract ``tokens`` from ``vault.toBeRedeemedTokens``.

3. Subtract ``tokens`` from ``vault.issuedTokens``.

4. Punish the vault for not fulfilling the request to redeem tokens.

    - Call the :ref:`getExchangeRate` function to obtain the current exchange rate.
    - Calculate the current value of ``tokens`` in collateral with the exchange rate.
    - Add a punishment percentage on top of the ``token`` value expressed as collateral from the ``PunishmentFee`` and store the punishment payment as ``payment``.
    - Check if the vault is above the ``SecureCollateralThreshold`` when we remove ``payment`` from ``vault.collateral``. If the vault falls under the ``SecureCollateralThreshold``, reduce the ``payment`` so that the vault is exactly on the ``SecureCollateralThreshold``.
    - Call the :ref:`slashCollateral` function with the ``vault`` as ``sender``, ``user`` as ``receiver``, and ``payment`` as ``amount``.
    - Reduce the ``vault.collateral`` by ``payment``.


.. _redeemTokens:

redeemTokens
------------

When a redeem request successfully completes, the ``toBeRedeemedToken`` and the ``issuedToken`` balance must be reduced to reflect that removal of ONEBTC.

Specification
.............

*Function Signature*

``redeemTokens(vault, tokens)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``tokens``: The amount of ONEBTC redeemed.


*Events*

* ``RedeemTokens(vault, tokens)``: Emit an event when a redeem request successfully completes.

*Errors*

* ``ERR_INSUFFICIENT_TOKENS_COMMITTED``: Return if the requested amount of ``tokens`` exceeds the ``issuedTokens`` or ``toBeRedeemedTokens`` by this vault.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must not be set to ``SHUTDOWN: 2``.
* If the BTC Parachain status in the :ref:`security` component is set to ``ERROR: 1``, it must not include the error codes ``INVALID_BTC_RELAY: 2`` or ``ORACLE_OFFLINE: 3``.

Function Sequence
.................

1. Checks if the amount of ``tokens`` to be redeemed is less or equal to the amount of ``vault.issuedTokens`` and the ``vault.toBeRedeemedTokens``. If not, throws ``ERR_INSUFFICIENT_TOKENS_COMMITTED``.

2. Subtract ``tokens`` from ``vault.toBeRedeemedTokens``.

3. Subtract ``tokens`` from ``vault.issuedTokens``.

.. _redeemTokensPremium:

redeemTokensPremium
-------------------

Handles a redeem request, where a user is paid a premium in ONE. Calls :ref:`redeemTokens` and then allocates the corresponding amount of ONE to the ``redeemer`` using the Vault's free collateral.

Specification
.............

*Function Signature*

``redeemTokensPremium(vault, tokens, premiumONE, redeemer)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``tokens``: The amount of ONEBTC redeemed.
* ``premiumONE``: The amount of ONE to be paid to the user as a premium using the Vault's released collateral.
* ``redeemer``: The user that redeems at a premium.


*Events*

* ``RedeemTokensPremium(vault, tokens, premiumONE, redeemer)``: Emit an event when a user is executing a redeem request that includes a premium.

*Errors*

* ``ERR_INSUFFICIENT_TOKENS_COMMITTED``: Return if the requested amount of ``tokens`` exceeds the ``issuedTokens`` or ``toBeRedeemedTokens`` by this vault.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must not be set to ``SHUTDOWN: 2``.
* If the BTC Parachain status in the :ref:`security` component is set to ``ERROR: 1``, it must not include the error codes ``INVALID_BTC_RELAY: 2`` or ``ORACLE_OFFLINE: 3``.

Function Sequence
.................

1. Call :ref:`redeemTokens` passing ``vault`` and ``tokens`` as parameters.

2. If ``premiumONE > 0``:

   a. Transfer the corresponding amount of Vault's collateral to ``LiquidationVault`` by calling :ref:`slashCollateral` and passing ``vault`` and ``LiquidationVault`` as parameters.

   b. Emit ``RedeemTokensPremium(vault, tokens, premiumONE, redeemer)`` event.

.. _redeemTokensLiquidation:

redeemTokensLiquidation
------------------------

Handles redeem requests which are executed during a ``LIQUIDATION`` recover (see :ref:`security`).
Reduces the ``issuedToken`` of the ``LiquidationVault`` and "slashes" the corresponding amount of ONE collateral.
Once ``LiquidationVault`` has not more ``issuedToken`` left, removes the ``LIQUIDATION`` error from the BTC Parachain status.

Specification
.............

*Function Signature*

``redeemTokensLiquidation(redeemer, redeemONEinBTC)``

*Parameters*

* ``redeemer`` : The account of the user redeeming polkaBTC.
* ``redeemONEinBTC``: The amount of ONEBTC to be redeemed in ONE with the ``LiquidationVault``, denominated in BTC.



*Events*

* ``RedeemTokensLiquidation(redeemer, redeemONEinBTC)``: Emit an event when a redeem is executed under the ``LIQUIDATION`` status..

*Errors*

* ``ERR_INSUFFICIENT_TOKENS_COMMITTED``: Return if the requested amount of ``redeemONEinBTC`` exceeds the ``issuedTokens`` or by this vault.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must not be set to ``SHUTDOWN: 2``.

Function Sequence
.................

1. Check if ``LiquidationVault.issuedTokens >= redeemONEinBTC``. Return ``ERR_INSUFFICIENT_TOKENS_COMMITTED`` if this check fails.

2. Subtract ``redeemONEinBTC`` from ``vault.issuedTokens``.

3. Transfer the ``LiquidationVault``'s ONE collateral to the ``redeemer`` by calling :ref:`slashCollateral` and passing ``LiquidationVault``, ``redeemer`` and ``redeemONEinBTC *`` :ref:`getExchangeRate` as parameters.

5. Emit ``RedeemTokensLiquidation(redeemer, redeemONEinBTC)`` event.

.. _replaceTokens:

replaceTokens
-------------

When a replace request successfully completes, the ``toBeRedeemedTokens`` and the ``issuedToken`` balance must be reduced to reflect that removal of ONEBTC from the ``oldVault``.Consequently, the ``issuedTokens`` of the ``newVault`` need to be increased by the same amount.

Specification
.............

*Function Signature*

``replaceTokens(oldVault, newVault, tokens, collateral)``

*Parameters*

* ``oldVault``: Account identifier of the vault to be replaced.
* ``newVault``: Account identifier of the vault accepting the replace request.
* ``tokens``: The amount of ONEBTC replaced.
* ``collateral``: The collateral provided by the new vault.


*Events*

* ``ReplaceTokens(oldVault, newVault, tokens, collateral)``: Emit an event when a replace requests is successfully executed.

*Errors*

* ``ERR_INSUFFICIENT_TOKENS_COMMITTED``: The requested amount of ``tokens`` exceeds the ``issuedTokens`` or ``toBeReplaceedTokens`` by this vault.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must not be set to ``SHUTDOWN: 2``.
* If the BTC Parachain status in the :ref:`security` component is set to ``ERROR: 1``, it must not include the error codes ``INVALID_BTC_RELAY: 2`` or ``ORACLE_OFFLINE: 3``.

Function Sequence
.................

1. Checks if the amount of ``tokens`` to be replaced is less or equal to the amount of ``oldVault.issuedTokens`` and the ``oldVault.toBeReplaceedTokens``. If not, throws ``ERR_INSUFFICIENT_TOKENS_COMMITTED``.

2. Subtract ``tokens`` from ``oldVault.toBeReplaceedTokens``.

3. Subtract ``tokens`` from ``oldVault.issuedTokens``.

4. Add ``tokens`` to ``newVault.issuedTokens``.

5. Add ``collateral`` to the ``newVault.collateral``.


.. _liquidateVault:

liquidateVault
--------------

Liquidates a vault, transferring all of its token balances to the ``LiquidationVault``, as well as the ONE collateral.

.. todo:: Update all pending Issue, Redeem and Replace requests with this vault to point to the ``LiquidationVault`` for handling of slashed collateral.

Specification
.............

*Function Signature*

``liquidateVault(vault)``

*Parameters*

* ``vault``: Account identifier of the vault to be liquidated.


*Events*

* ``LiquidateVault(vault)``: Emit an event indicating that the vault with ``vault`` account identifier has been liquidated.

*Errors*

* ``ERR_INSUFFICIENT_TOKENS_COMMITTED``: The requested amount of ``tokens`` exceeds the ``issuedTokens`` or ``toBeReplaceedTokens`` by this vault.


Function Sequence
.................

1. Set ``LiquidationVault.toBeIssuedTokens = vault.toBeIssuedTokens``

2. Set ``LiquidationVault.issuedTokens = vault.issuedTokens``

3. Set ``LiquidationVault.toBeRedeemedToken= vault.toBeRedeemedToken``

4. Transfer the liquidated Vault's collateral to ``LiquidationVault`` by calling :ref:`slashCollateral` and passing ``vault`` and ``LiquidationVault`` as parameters.

5. Remove ``vault`` from ``Vaults``

6. Emit ``LiquidateVault(vault)`` event.



Events
~~~~~~

RegisterVault
-------------

Emit an event stating that a new vault (``vault``) was registered and provide information on the Vault’s collateral (``collateral``).

*Event Signature*

``RegisterVault(vault, collateral)``

*Parameters*

* ``vault``: The account of the vault to be registered.
* ``collateral``: to-be-locked collateral in ONE.

*Functions*

* :ref:`registerVault`

.. _event_ProveValidBTCAddress:

ProveValidBTCAddress
--------------------

Emit an event stating that a vault (``vault``) submitted a proof that its BTC address is valid.

*Event Signature*

``ProveValidBTCAddress(vault, btcAddress)``

*Parameters*

* ``vault``: The account of the vault to be registered.
* ``btcAddress``: The BTC address of the vault.

*Functions*

* :ref:`proveValidBTCAddress`

.. _event_LockAdditionalCollateral:

LockAdditionalCollateral
------------------------

Emit an event stating how much new (``newCollateral``), total collateral (``totalCollateral``) and freely available collateral (``freeCollateral``) the vault calling this function has locked.

*Event Signature*

``LockAdditionalCollateral(Vault, newCollateral, totalCollateral, freeCollateral)``

*Parameters*

* ``Vault``: The account of the vault locking collateral.
* ``newCollateral``: to-be-locked collateral in ONE.
* ``totalCollateral``: total collateral in ONE.
* ``freeCollateral``: collateral not "occupied" with ONEBTC in ONE.

*Functions*

* :ref:`lockAdditionalCollateral`


WithdrawCollateral
------------------

Emit emit an event stating how much collateral was withdrawn by the vault and total collateral a vault has left.

*Event Signature*

``WithdrawCollateral(Vault, withdrawAmount, totalCollateral)``

*Parameters*

* ``Vault``: The account of the vault locking collateral.
* ``withdrawAmount``: To-be-withdrawn collateral in ONE.
* ``totalCollateral``: total collateral in ONE.

*Functions*

* ref:`withdrawCollateral`


IncreaseToBeIssuedTokens
------------------------

Emit

*Event Signature*

``IncreaseToBeIssuedTokens(vaultId, tokens)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``tokens``: The amount of ONEBTC to be locked.


*Functions*

* ref:``increaseToBeIssuedTokens``


DecreaseToBeIssuedTokens
------------------------

Emit

*Event Signature*

``DecreaseToBeIssuedTokens(vaultId, tokens)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``tokens``: The amount of ONEBTC to be unreserved.


*Functions*

* ref:``decreaseToBeIssuedTokens``


IssueTokens
-----------

Emit an event when an issue request is executed.

*Event Signature*

``IssueTokens(vault, tokens)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``tokens``: The amount of ONEBTC that were just issued.

*Functions*

* ref:``issueTokens``


IncreaseToBeRedeemedTokens
--------------------------

Emit an event when a redeem request is requested.

*Event Signature*

``IncreaseToBeRedeemedTokens(vault, tokens)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``tokens``: The amount of ONEBTC to be redeemed.

*Functions*

* ref:``increaseToBeRedeemedTokens``


DecreaseToBeRedeemedTokens
--------------------------

Emit an event when a replace request cannot be completed because the vault has too little tokens committed.

*Event Signature*

``DecreaseToBeRedeemedTokens(vault, tokens)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``tokens``: The amount of ONEBTC not to be replaced.

*Functions*

* ref:``decreaseToBeRedeemedTokens``


DecreaseTokens
--------------

Emit an event if a redeem request cannot be fulfilled.

*Event Signature*

``DecreaseTokens(vault, user, tokens, collateral)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``user``: The BTC Parachain address of the user that made the redeem request.
* ``tokens``: The amount of ONEBTC that were not redeemed.
* ``collateral``: The amount of collateral assigned to this request.

*Functions*

* ref:``decreaseTokens``


RedeemTokens
------------

Emit an event when a redeem request successfully completes.

*Event Signature*

``RedeemTokens(vault, tokens)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``tokens``: The amount of ONEBTC redeemed.

*Functions*

* ref:``redeemTokens``


RedeemTokensPremium
-------------------

Emit an event when a user is executing a redeem request that includes a premium.

*Event Signature*

``RedeemTokensPremium(vault, tokens, premiumONE, redeemer)``

*Parameters*

* ``vault``: The BTC Parachain address of the Vault.
* ``tokens``: The amount of ONEBTC redeemed.
* ``premiumONE``: The amount of ONE to be paid to the user as a premium using the Vault's released collateral.
* ``redeemer``: The user that redeems at a premium.

*Functions*

* ref:``redeemTokensPremium``


RedeemTokensLiquidation
-----------------------

Emit an event when a redeem is executed under the ``LIQUIDATION`` status.

*Event Signature*

``RedeemTokensLiquidation(redeemer, redeemONEinBTC)``

*Parameters*

* ``redeemer`` : The account of the user redeeming polkaBTC.
* ``redeemONEinBTC``: The amount of ONEBTC to be redeemed in ONE with the ``LiquidationVault``, denominated in BTC.

*Functions*

* ref:``redeemTokensLiquidation``


ReplaceTokens
-------------

Emit an event when a replace requests is successfully executed.

*Event Signature*

``ReplaceTokens(oldVault, newVault, tokens, collateral)``

*Parameters*

* ``oldVault``: Account identifier of the vault to be replaced.
* ``newVault``: Account identifier of the vault accepting the replace request.
* ``tokens``: The amount of ONEBTC replaced.
* ``collateral``: The collateral provided by the new vault.

*Functions*

* ref:``replaceTokens``


LiquidateVault
--------------

Emit an event indicating that the vault with ``vault`` account identifier has been liquidated.

*Event Signature*

``LiquidateVault(vault)``

*Parameters*

* ``vault``: Account identifier of the vault to be liquidated.

*Functions*

* ref:``liquidateVault``


Error Codes
~~~~~~~~~~~

``ERR_MIN_AMOUNT``

* **Message**: "The provided collateral was insufficient - it must be above ``MinimumCollateralVault``."
* **Function**: :ref:`registerVault` | :ref:`withdrawCollateral`
* **Cause**: The vault provided too little collateral, i.e. below the MinimumCollateralVault limit.

``ERR_INVALID_BTC_ADDRESS``

* **Message**: "Not a valid BTC address."
* **Function**: :ref:`proveValidBTCAddress`
* **Cause**: BTC-Relay failed to verify the BTC address. See ``verifyTransactionInclusion`` in BTC-Relay.

``ERR_VAULT_NOT_FOUND``

* **Message**: "The specified vault does not exist. ."
* **Function**: :ref:`lockAdditionalCollateral`
* **Cause**: vault could not be found in ``Vaults`` mapping.

``ERR_INSUFFICIENT_FREE_COLLATERAL``

* **Message**: "Not enough free collateral available."
* **Function**: :ref:`withdrawCollateral`
* **Cause**: The vault is trying to withdraw more collateral than is currently free.

``ERR_UNAUTHORIZED``

* **Message**: "Origin of the call mismatches authorization."
* **Function**: :ref:`withdrawCollateral`
* **Cause**: The caller of the withdrawal is not the specified vault, and hence not authorized to withdraw funds.

``ERR_EXCEEDING_VAULT_LIMIT``

* **Message**: "Issue request exceeds vault collateral limit."
* **Function**: :ref:`increaseToBeIssuedTokens`
* **Cause**: The collateral provided by the vault combined with the exchange rate forms an upper limit on how much ONEBTC can be issued. The requested amount exceeds this limit.

``ERR_INSUFFICIENT_TOKENS_COMMITTED``

* **Message**: "The requested amount of ``tokens`` exceeds the amount by this vault."
* **Function**: :ref:`decreaseToBeIssuedTokens` | :ref:`issueTokens` | :ref:`increaseToBeRedeemedTokens` | :ref:`decreaseToBeRedeemedTokens` | :ref:`decreaseTokens` | :ref:`redeemTokens` | :ref:`redeemTokensLiquidation` | :ref:`replaceTokens` | :ref:`liquidateVault`
* **Cause**: A user tries to cancel/execute an issue request or create a replace request for a vault that has less than the reserved tokens committed.
