.. _collateral-module:

Collateral
==========

Overview
~~~~~~~~

The Collateral module is the central storage for collateral provided by users and vaults of the system.
It allows to (i) lock, (ii) release, and (iii) slash collateral of either users or vaults.
It can only be accessed by other modules and not directly through external transactions.


Step-by-Step
------------

The protocol has three different "sub-protocols".

- **Lock**: Store a certain amount of collateral from a single entity (user or vault).
- **Release**: Transfer a certain amount of collateral back to the entity that paid it.
- **Slash**: Transfer a certain amount of collateral to a party that was damaged by the actions of another party.

Data Model
~~~~~~~~~~

Scalars
-------

TotalCollateral
...............

The total collateral provided.


.. Enums
.. -----
..
.. CollateralType
.. ..............
..
.. Types of accepted collateral.
..
.. .. note:: For now, only ONE is accepted as collateral.


Maps
----

CollateralBalances
..................

Mapping from accounts to their collateral balances.


Functions
~~~~~~~~~

.. _lockCollateral:

lockCollateral
--------------

A user or a vault locks some amount of collateral.

Specification
.............

*Function Signature*

``lockCollateral(sender, amount)``

*Parameters*

* ``sender``: The sender wishing to lock collateral.
* ``amount``: The amount of collateral.


*Events*

* ``LockCollateral(sender, amount)``: Issues an event when collateral is locked.

Precondition
............

* The function must be called by any of the four modules: :ref:`issue-protocol`, :ref:`redeem-protocol`, :ref:`replace-protocol`, or :ref:`Vault-registry`.
* The BTC Bridge status in the :ref:`security` component must be set to ``RUNNING:0``.

Function Sequence
.................

1. Add the ``amount`` of provided collateral to the ``CollateralBalances`` of the ``sender``.
2. Increase ``TotalCollateral`` by ``amount``.

.. _releaseCollateral:

releaseCollateral
-----------------

When any of the issue, redeem, or replace protocols are completed successfully the party that has initially provided collateral receives their collateral back.

Specification
.............

*Function Signature*

``releaseCollateral(sender, amount)``

*Parameters*

* ``sender``: The sender getting returned its collateral.
* ``amount``: The amount of collateral.


*Events*

* ``ReleaseCollateral(sender, amount)``: Issues an event when collateral is released.

*Errors*

* ``ERR_INSUFFICIENT_COLLATERAL_AVAILABLE``: The ``sender`` has less collateral stored than the requested ``amount``.

Precondition
............

* The function must be called by any of the four modules: :ref:`issue-protocol`, :ref:`redeem-protocol`, :ref:`replace-protocol`, or :ref:`Vault-registry`.
* The BTC Bridge status in the :ref:`security` component must be set to ``RUNNING:0``.

Function Sequence
.................

1. Check if the ``amount`` is less or equal to the ``CollateralBalances`` of the ``sender``. If not, throw ``ERR_INSUFFICIENT_COLLATERAL_AVAILABLE``.

2. Deduct the ``amount`` from the ``sender``'s ``CollateralBalances``.

3. Deduct the ``amount`` from the ``TotalCollateral``.

4. Transfer the ``amount`` to the ``sender``.


.. _slashCollateral:

slashCollateral
-----------------

When any of the issue, redeem, or replace protocols are not completed in time, the party that has initially provided collateral (``sender``) is slashed and the collateral is transferred to another party (``receiver``).

Specification
.............

*Function Signature*

``slashCollateral(sender, receiver, amount)``

*Parameters*

* ``sender``: The sender that initially provided the collateral.
* ``receiver``: The receiver of the collateral.
* ``amount``: The amount of collateral.


*Events*

* ``SlashCollateral(sender, receiver, amount)``: Issues an event when collateral is slashed.

*Errors*

* ``ERR_INSUFFICIENT_COLLATERAL_AVAILABLE``: The ``sender`` has less collateral stored than the requested ``amount``.


Precondition
............

* The function must be called by any of the four modules: :ref:`issue-protocol`, :ref:`redeem-protocol`, :ref:`replace-protocol`, or :ref:`Vault-registry`.
* The BTC Bridge status in the :ref:`security` component must be set to ``RUNNING:0``.

Function Sequence
.................

1. Check if the ``amount`` is less or equal to the ``CollateralBalances`` of the ``sender``. If not, throw ``ERR_INSUFFICIENT_COLLATERAL_AVAILABLE``.

2. Deduct the ``amount`` from the ``sender``'s ``CollateralBalances``.

3. Deduct the ``amount`` from the ``TotalCollateral``.

4. Transfer the ``amount`` to the ``receiver``.

Events
~~~~~~

LockCollateral
--------------

Emit a ``LockCollateral`` event when a sender locks collateral.

*Event Signature*

``LockCollateral(sender, amount)``

*Parameters*

* ``sender``: The sender that provides the collateral.
* ``amount``: The amount of collateral.

*Function*

* :ref:`lockCollateral`


ReleaseCollateral
-----------------

Emit a ``ReleaseCollateral`` event when a sender releases collateral.

*Event Signature*

``ReleaseCollateral(sender, amount)``

*Parameters*

* ``sender``: The sender that initially provided the collateral.
* ``amount``: The amount of collateral.

*Function*

* :ref:`releaseCollateral`


SlashCollateral
----------------

Emit a ``SlashCollateral`` event when a sender's collateral is slashed and transferred to the receiver.

*Event Signature*

``SlashCollateral(sender, receiver, amount)``

*Parameters*

* ``sender``: The sender that initially provided the collateral.
* ``receiver``: The receiver of the collateral.
* ``amount``: The amount of collateral.

*Function*

* :ref:`slashCollateral`

Errors
~~~~~~

``ERR_INSUFFICIENT_COLLATERAL_AVAILABLE```

* **Message**: "The sender's collateral balance is below the requested amount."
* **Function**: :ref:`releaseCollateral` | :ref:`slashCollateral`
* **Cause**: the ``sender`` has less collateral stored than the requested ``amount``.
