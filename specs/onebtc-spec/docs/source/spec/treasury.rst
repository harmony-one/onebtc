.. _treasury-module:

Treasury
========

Overview
~~~~~~~~

The treasury serves as the central storage for all ONEBTC.
It exposes the :ref:`transfer` function to any user. With the transfer functions users can send ONEBTC to and from each other.
Further, the treasury exposes three internal functions for the :ref:`issue-protocol` and the :ref:`redeem-protocol`.

Step-by-step
------------

* **Transfer**: A user sends an amount of ONEBTC to another user by calling the :ref:`transfer` function.
* **Issue**: The issue module calls into the treasury when an issue request is completed and the user has provided a valid proof that he transferred the required amount of BTC to the correct vault. The issue module calls the :ref:`mint` function to grant the user the ONEBTC token.
* **Redeem**: The redeem protocol requires two calls to the treasury module. First, a user requests a redeem via the :ref:`requestRedeem` function. This invokes a call to the :ref:`lock` function that locks the requested amount of tokens for this user. Second, when a redeem request is completed and the vault has provided a valid proof that it transferred the required amount of BTC to the correct user, the redeem module calls the :ref:`burn` function to destroy the previously locked ONEBTC.

Data Model
~~~~~~~~~~

Constants
---------

- ``NAME``: ``ONEBTC``
- ``SYMBOL``: ``pBTC``

Scalars
-------

TotalSupply
...........

The total supply of ONEBTC.


Maps
----

Balances
........

Mapping from accounts to their balance.


Locked Balances
...............

Mapping from accounts to their balance of locked tokens. Locked tokens serve two purposes:

1. Locked tokens cannot be transferred. Once a user locks the token, the token needs to be unlocked to become spendable.
2. Locked tokens are the only tokens that can be burned in the redeem procedure.


Functions
~~~~~~~~~

.. _transfer:

transfer
--------

Transfers a specified amount of ONEBTC from a Sender to a Receiver on the BTC Bridge.

Specification
.............

*Function Signature*

``transfer(sender, receiver, amount)``

*Parameters*

* ``sender``: An account with enough funds to send the ``amount`` of ONEBTC to the ``receiver``.
* ``receiver``: Account receiving an amount of ONEBTC.
* ``amount``: The number of ONEBTC being sent in the transaction.


*Events*

* ``Transfer(sender, receiver, amount)``: Issues an event when a transfer of funds was successful.

*Errors*

* ``ERR_INSUFFICIENT_FUNDS``: The sender does not have a high enough balance to send an ``amount`` of ONEBTC.

.. *Substrate*

``fn transfer(origin, receiver: AccountId, amount: Balance) -> Result {...}``

Function Sequence
.................

The ``transfer`` function takes as input the sender, the receiver, and an amount. The function executes the following steps:

1. Check that the ``sender`` is authorised to send the transaction by verifying the signature attached to the transaction.
2. Check that the ``sender``'s balance is above the ``amount``. If ``Balances[sender] < amount`` (in Substrate ``free_balance``), raise ``ERR_INSUFFICIENT_FUNDS``.

3. Subtract the sender's balance by ``amount``, i.e. ``Balances[sender] -= amount`` and add ``amount`` to the receiver's balance, i.e. ``Balances[receiver] += amount``.

4. Emit the ``Transfer(sender, receiver, amount)`` event.

.. _mint:

mint
----

In the BTC Bridge new ONEBTC can be created by leveraging the :ref:`issue-protocol`.
However, to separate concerns and access to data, the Issue module has to call the ``mint`` function to complete the issue process in the ONEBTC component.
The function increases the ``totalSupply`` of ONEBTC.

.. warning:: This function can *only* be called from the Issue module.

Specification
.............

*Function Signature*

``mint(requester, amount)``

*Parameters*

* ``requester``: The account of the requester of ONEBTC.
* ``amount``: The amount of ONEBTC to be added to an account.


*Events*

* ``Mint(requester, amount)``: Issue an event when new ONEBTC are minted.

.. *Substrate*

``fn mint(requester: AccountId, amount: Balance) -> Result {...}``


Preconditions
.............

This is an internal function and can only be called by the :ref:`Issue module <issue-protocol>`.

Function Sequence
.................

1. Increase the ``requester`` Balance by ``amount``, i.e. ``Balances[requester] += amount``.
2. Emit the ``Mint(requester, amount)`` event.

.. _lock:

lock
----

During the redeem process, a user needs to be able to lock ONEBTC. Locking transfers coins from the ``Balances`` mapping to the ``LockedBalances`` mapping to prevent users from transferring the coins.

Specification
.............

*Function Signature*

``lock(redeemer, amount)``

*Parameters*

* ``redeemer``: The Redeemer wishing to lock a certain amount of ONEBTC.
* ``amount``: The amount of ONEBTC that should be locked.


*Events*

* ``Lock(redeemer, amount)``: Emits newly locked amount of ONEBTC by a user.

*Errors*

* ``ERR_INSUFFICIENT_FUNDS``: User has not enough ONEBTC to lock coins.


Precondition
............

* Can only be called by the redeem module.

Function Sequence
.................

1. Checks if the user has a balance higher than or equal to the requested amount, i.e. ``Balances[redeemer] >= amount``. Return ``ERR_INSUFFICIENT_FUNDS`` if the user's balance is too low.
2. Decreases the user's token balance by the amount and increases the locked tokens balance by amount, i.e. ``Balances[redeemer] -= amount`` and ``LockedBalances[redeemer] += amount``.
3. Emit the ``Lock`` event.

.. _burn:

burn
----

During the :ref:`redeem-protocol`, users first lock and then "burn" (i.e. destroy) their ONEBTC to receive BTC. Users can only burn tokens once they are locked to prevent transaction ordering dependencies. This means a user first needs to move his tokens from the ``Balances`` to the ``LockedBalances`` mapping via the :ref:`lock` function.

.. warning:: This function is only internally callable by the Redeem module.

Specification
.............

*Function Signature*

``burn(redeemer, amount)``

*Parameters*

* ``redeemer``: The Redeemer wishing to burn a certain amount of ONEBTC.
* ``amount``: The amount of ONEBTC that should be destroyed.


*Events*

* ``Burn(redeemer, amount)``: Issue an event when the amount of ONEBTC is successfully destroyed.

*Errors*

* ``ERR_INSUFFICIENT_LOCKED_FUNDS``: If the user has insufficient funds locked, i.e. her locked balance is lower than the amount.

.. *Substrate*

``fn burn(redeemer: AccountId, amount: Balance) -> Result {...}``

Preconditions
.............

This is an internal function and can only be called by the :ref:`Redeem module <redeem-protocol>`.

Function Sequence
.................

1. Check that the ``redeemer``'s locked balance is above the ``amount``. If ``LockedBalance[redeemer] < amount`` (in Substrate ``free_balance``), raise ``ERR_INSUFFICIENT_LOCKED_FUNDS``.
2. Subtract the Redeemer's locked balance by ``amount``, i.e. ``LockedBalances[redeemer] -= amount``.
3. Emit the ``Burn(redeemer, amount)`` event.

Events
~~~~~~

Transfer
--------
Issues an event when a transfer of funds was successful.

*Event Signature*

``Transfer(sender, receiver, amount)``

*Parameters*

* ``sender``: An account with enough funds to send the ``amount`` of ONEBTC to the ``receiver``.
* ``receiver``: Account receiving an amount of ONEBTC.
* ``amount``: The number of ONEBTC being sent in the transaction.

*Function*

* :ref:`transfer`


Mint
----

Issue an event when new ONEBTC are minted.

*Event Signature*

``Mint(requester, amount)``

*Parameters*

* ``requester``: The account of the requester of ONEBTC.
* ``amount``: The amount of ONEBTC to be added to an account.

*Function*

* :ref:`mint`


Lock
----

Emits newly locked amount of ONEBTC by a user.

*Event Signature*

``Lock(redeemer, amount)``

*Parameters*

* ``redeemer``: The Redeemer wishing to lock a certain amount of ONEBTC.
* ``amount``: The amount of ONEBTC that should be locked.

*Function*

* :ref:`lock`


Burn
----

Issue an event when the amount of ONEBTC is successfully destroyed.

*Event Signature*

``Burn(redeemer, amount)``

*Parameters*

* ``redeemer``: The Redeemer wishing to burn a certain amount of ONEBTC.
* ``amount``: The amount of ONEBTC that should be burned.

*Function*

* :ref:`burn`


Errors
~~~~~~

``ERR_INSUFFICIENT_FUNDS``

* **Message**: "The balance of this account is insufficient to complete the transaction."
* **Functions**: :ref:`transfer` | :ref:`lock`
* **Cause**: The balance of the user of available tokens (i.e. ``Balances``) is below a certain amount to either transfer or lock tokens.

``ERR_INSUFFICIENT_LOCKED_FUNDS``

* **Message**: "The locked token balance of this account is insufficient to burn the tokens."
* **Function**: :ref:`burn`
* **Cause**: The user has locked too little tokens in the ``LockedBalances`` to execute the burn function.

