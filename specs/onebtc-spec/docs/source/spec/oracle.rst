.. _oracle:

Exchange Rate Oracle
====================

.. note:: This exchange oracle module is a bare minimum model that relies on a single trusted oracle source. Decentralized oracles are a difficult and open research problem that is outside of the scope of this specification. However, the general interface to get the exchange rate can remain the same even with different constructions.


The Exchange Rate Oracle receives a continuous data feed on the exchange rate between BTC and ONE.

The implementation of the oracle **is not part of this specification**. ONEBTC assumes the oracle operates correctly and that the received data is reliable.


Data Model
~~~~~~~~~~

Constants
---------

GRANULARITY
...........

The granularity of the exchange rate. The granularity is set to :math:`10^{-5}`.


Scalars
-------

ExchangeRateBtcInDot
....................

The BTC in ONE exchange rate. This exchange rate is used to determine how much collateral is required to issue a specific amount of ONEBTC.

.. note:: If the ``ExchangeRate`` is set to 1238763, it translates to :math:`12.38763` as the last five digits are used for the floating point (as defined by the ``GRANULARITY``).


SatoshiPerBytesFast
...................

The estimated Satoshis per bytes required to get a Bitcoin transaction included in the next block.


SatoshiPerBytesMedium
.....................

The estimated Satoshis per bytes required to get a Bitcoin transaction included in the next three blocks (about 30 min).


SatoshiPerBytesSlow
...................

The estimated Satoshis per bytes required to get a Bitcoin transaction included in the six blocks (about 1 hour).


MaxDelay
........

The maximum delay in seconds between incoming calls providing exchange rate data. If the Exchange Rate Oracle receives no data for more than this period, the BTC Parachain enters an ``Error`` state with a ``ORACLE_OFFLINE`` error cause.


LastExchangeRateTime
....................

UNIX timestamp indicating when the last exchange rate data was received.


Enums
-----

InclusionEstimate
.................

The estimated time until when a BTC transaction is included based on the Satoshi per byte fee.

* ``FAST: 0`` - the fee to include a BTC transaction within the next block.

* ``MEDIUM: 1``- the fee to include a BTC transaction within the next three blocks (~30 min)).

* ``SLOW: 2`` - the fee to include a BTC transaction within the six blocks  (~60 min).

Maps
----

AuthorizedOracles
.................

The account(s) of the oracle. Returns true if registered as an oracle.


Functions
~~~~~~~~~

.. _setExchangeRate:

setExchangeRate
---------------

Set the latest (aggregate) BTC/ONE exchange rate. This function invokes a check of vault collateral rates in the :ref:`Vault-registry` component.

Specification
.............

*Function Signature*

``setExchangeRate(oracle, rate)``

*Parameters*

* ``oracle``: the oracle account calling this function. Must be pre-authorized and tracked in this component!
* ``rate``: the ``u128`` BTC/ONE exchange rate


*Events*

* ``SetExchangeRate(oracle, rate)``: Emits the new exchange rate when it is updated by the oracle.

*Errors*

* ``ERR_INVALID_ORACLE_SOURCE``: the caller of the function was not the authorized oracle.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must be set to ``RUNNING:0``.

Function Sequence
.................

1. Check if the caller of the function is the ``AuthorizedOracle``. If not, throw ``ERR_INVALID_ORACLE_SOURCE``.
2. Update the ``ExchangeRate`` with the ``rate``.
3. If ``LastExchangeRateTime`` minus the current UNIX timestamp is greater or equal to ``MaxDelay``, call :ref:`recoverFromORACLEOFFLINE` to recover from an ``ORACLE_OFFLINE`` error (which was the case before this data submission).
4. Set ``LastExchangeRateTime`` to the current UNIX timestamp.
5. Emit the ``SetExchangeRate`` event.

.. _setSatoshiPerBytes:

setSatoshiPerBytes
------------------

Set the Satoshi per bytes fee

Specification
.............

*Function Signature*

``setSatoshiPerBytes(fee, InclusionEstimate)``

*Parameters*

* ``fee``: the Satoshi per byte fee.
* ``InclusionEstimate``: the estimated inclusion time.

*Events*

* ``SetSatoshiPerByte(fee, InclusionEstimate)``:

*Errors*

* ``ERR_INVALID_ORACLE_SOURCE``: the caller of the function was not the authorized oracle.


Requirements
............

* The BTC Parachain status in the :ref:`security` component MUST be set to ``RUNNING:0``.
* If the caller of the function is not in ``AuthorizedOracles`` MUST return ``ERR_INVALID_ORACLE_SOURCE``.
* If the above checks passed, the function MUST update the ``SatoshiPerBytes`` field indicated by the ``InclusionEstimate`` enum.
* If the above steps passed, MUST emit the ``SetSatoshiPerByte`` event.

.. _getExchangeRate:

getExchangeRate
----------------


Returns the latest BTC/ONE exchange rate, as received from the external data sources.

Specification
.............

*Function Signature*

``getExchangeRate()``

*Returns*

* `u128` (aggregate) exchange rate value


.. *Substrate*

``fn getExchangeRate(origin) -> Result<u128, ERR_MISSING_EXCHANGE_RATE> {...}``

*Errors*

``ERR_MISSING_EXCHANGE_RATE``: the last exchange rate information exceeded the maximum delay acceptable by the oracle.

Preconditions
.............

This function can be called by any participant to retrieve the BTC/ONE exchange rate as tracked by the BTC Parachain.

Function Sequence
.................

1. Check if the current (UNIX) time minus the ``LastExchangeRateTime`` exceeds ``MaxDelay``. If this is the case, return ``ERR_MISSING_EXCHANGE_RATE`` error.

2. Otherwise, return the ``ExchangeRate`` from storage.



.. _getLastExchangeRateTime:

getLastExchangeRateTime
------------------------


Returns the UNIX timestamp of when the last BTC/ONE exchange rate was received from the external data sources.

Specification
.............

*Function Signature*

``getLastExchangeRateTime()``

*Returns*

* `timestamp`: 32bit UNIX timestamp


.. *Substrate*

``fn getLastExchangeRateTime() -> U32 {...}``


Function Sequence
.................

1. Return ``LastExchangeRateTime`` from storage.


Events
~~~~~~~~~~~~

SetExchangeRate
----------------

Emits the new exchange rate when it is updated by the oracle.

*Event Signature*

``SetExchangeRate(oracle, rate)``

*Parameters*

* ``oracle``: the oracle account calling this function. Must be pre-authorized and tracked in this component!
* ``rate``: the ``u128`` BTC/ONE exchange rate

*Function*

:ref:`setExchangeRate`

.. _recoverFromORACLEOFFLINE:

recoverFromORACLEOFFLINE
-------------------------

Internal function. Recovers the BTC Parachain state from a ``ORACLE_OFFLINE`` error and sets ``ParachainStatus`` to ``RUNNING`` if there are no other errors.

.. attention:: Can only be called from :ref:`oracle`.

Specification
.............

*Function Signature*

``recoverFromORACLEOFFLINE()``

*Events*

* ``ExecuteStatusUpdate(newStatusCode, addErrors, removeErrors, msg)`` - emits an event indicating the status change, with ``newStatusCode`` being the new ``StatusCode``, ``addErrors`` the set of to-be-added ``ErrorCode`` entries (if the new status is ``Error``), ``removeErrors`` the set of to-be-removed ``ErrorCode`` entries,, and ``msg`` the detailed reason for the status update.


Error Codes
~~~~~~~~~~~~

``ERR_MISSING_EXCHANGE_RATE``

* **Message**: "Exchange rate not set."
* **Function**: :ref:`getExchangeRate`
* **Cause**: The last exchange rate information exceeded the maximum delay acceptable by the oracle.



``ERR_INVALID_ORACLE_SOURCE``

* **Message**: "Invalid oracle account."
* **Function**: :ref:`setExchangeRate`
* **Cause**: The caller of the function was not the authorized oracle.

.. todo:: Halt ONEBTC if the exchange rate oracle fails: liveness failure if no more data is incoming, as well as safety failure if the Governance Mechanism flags incorrect exchange rates.
