.. _refund-protocol:

Refund
======

Overview
~~~~~~~~

The Refund module is a user failsafe mechanism. In case a user accidentally locks more Bitcoin than the actual issue request, the refund mechanism seeks to ensure that either (1) the initial issue request is increased to issue more ONEBTC or (2) the BTC are returned to the sending user.

Step-by-step
------------

If a user falsely sends additional BTC (i.e., :math:`|\text{BTC}| > |\text{ONEBTC}|`) during the issue process:

1. **Case 1: The originally selected vault has sufficient collateral locked to cover the entire BTC amount sent by the user**:
    a. Increase the issue request ONEBTC amount and the fee to reflect the actual BTC amount paid by the user.
    b. As before, issue the ONEBTC to the user and forward the fees.
    c. Emit an event that the issue amount was increased.
2. **Case 2: The originally selected vault does NOT have sufficient collateral locked to cover the additional BTC amount sent by the user**:
    a. Automatically create a return request from the issue module that includes a return fee (deducted from the originial BTC payment) paid to the vault returning the BTC.
    b. The vault fulfills the return request via a transaction inclusion proof (similar to execute issue). However, this does not create a new ONEBTC.

.. note:: Only case 2 is handled in this module. Case 1 is handled directly by the issue module.

.. note:: Normally, enforcing actions by a vault is achieved by locking collateral of the vault and slashing the vault in case of misbehavior. In the case where a user sends too many BTC and the vault does not have enough “free” collateral left, we cannot lock more collateral. However, the original vault cannot move the additional BTC sent as this would be flagged as theft and the vault would get slashed. The vault can possibly take the overpaid BTC though if the vault would not be backing any ONEBTC any longer (e.g. due to redeem/replace).


Security
--------

- Unique identification of Bitcoin payments: :ref:`op-return`
