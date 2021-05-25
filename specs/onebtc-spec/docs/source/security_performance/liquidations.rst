.. _liquidations:

Vault Liquidations
==================

Vaults are collateralized entities in the system responsible for keeping BTC in custody.
If Vaults fail to behave according to protocol rules, they face punishment through slashing of collateral. There are two types of failures: **safety failures** and **crash failures**.

Safety Failures
~~~~~~~~~~~~~~~

A safety failure occurs in two cases:

#. **Theft**: a Vault is considered to have committed theft if it moves/spends BTC unauthorized by the ONEBTC bridge. Theft is detected and reported by Relayers via an SPV proof.
#. **Severe Undercollteralization**: a Vaults drops below the ``110%`` liquidation collateral threshold.

In both cases, the Vault’s entire BTC holdings are liquidated and its ONE collateral is slashed - up to 150% (secure collateral threshold) of the liquidated BTC value.

Consequently, the bridge offers users to burn ("Burn Event") their tokens to restore the 1:1 balance between the issued (e.g., ONEBTC) and locked asset (e.g., BTC).

Crash Failures
~~~~~~~~~~~~~~

If Vaults go offline and fail to execute redeem, they are:

* **Penalized** (punishment fee slashed) and
* **Temporarily banned for 24 hours** from accepting further issue, redeem, and replace requests.

The punishment fee is calculated based on the Vault’s SLA (Service Level Agreement) level, which is a value between 0 and 100. The higher the Vault’s SLA, the lower the punishment for a failed redeem.

In detail, the punishment fee is calculated as follows:

* **Minimum Punishment Fee**: 10% of the failed redeem value.
* **Maximum Punishment Fee**: 30% of the failed redeem value.
* **Punishment Fee**: calculated based on the Vaults SLA value as defined in the :ref:`SlashAmountVault`.

Liquidations (Safety Failures)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

When a Vault is liquidated, its ``issued`` and ``toBeIssued`` tokens are *moved* to the Liquidation Vault.
In contrast, the Vault's ``toBeRedeemed`` tokens are *copied* over.
The Vault loses access to at least part of its backing collateral:

* The Vault loses ``confiscatedCollateral = min(SECURE_THRESHOLD * (issued + toBeIssued), backingCollateral)``, and any leftover amount is released to its free balance.
* Of the confiscated collateral, an amount of ``confiscatedCollateral * (toBeRedeemed / (issued + toBeIssued))`` stays locked in the Vault, and the rest is moved to the Liquidation Vault. This is in anticipation of vaults being able to complete ongoing redeem and replace requests. When these requests succeed, the liquidated Vault's collateral is returned. When the requests fail (i.e., the ``cancel`` calls are being made), the remaining collateral is slashed to the Liquidation Vault.


When the Liquidation Vault contains tokens, users can do a liquidation_redeem ("burn event"). Users can call this function to burn ONEBTC and receive ONE in return.

* The user receives ``liquidationVault.collateral * (burnedTokens / (issued + toBeIssued)`` in its free balance.
* At most ``liquidationVault.issued - liquidationVault.toBeRedeemed`` tokens can be burned.

Vault liquidation affects Vault interactions is the following ways:

* Operations that increase ``toBeIssued`` or ``toBeRedeemed`` are disallowed. This means that no new issue/redeem/replace request can be made.
* Any operation that would decrease ``toBeIssued`` or change ``issued`` on a user Vault instead changes it on the Liquidation Vault
* Any operation that would decrease ``toBeRedeemed`` tokens on a user Vault *additionally* decreases it on the Liquidation Vault

Issue
-----

- ``requestIssue``
    - disallowed
- ``executeIssue``
    - Overpayment protection is disabled; if a user transfers too many BTC, the user loses it.
    - SLA of Vault is not increased
- ``cancelIssue``
    - User's griefing collateral is released back to the user, rather than slashed to the Vault.

Redeem
------

- ``requestRedeem``
    - disallowed
- ``executeRedeem``
    - Part of the Vault's collateral is released. Amount: ``Vault.backingCollateral * (redeem.amount / Vault.toBeRedeemed)``, where ``toBeRedeemed`` is read before it is decreased
    - The premium, if any, is not transferred to the user.
- ``cancelRedeem``
    - Calculates ``slashedCollateral = Vault.backingCollateral * (redeem.amount / Vault.toBeRedeemed)``,  where ``toBeRedeemed`` is read *before* it is decreased, and then:
    - If reimburse:
        - transfers ``slashedCollateral`` to user.
    - Else if not reimburse:
        - transfers ``slashedCollateral`` to Liquidation Vault.
    - Fee pool does not receive anything.

Replace
-------

- ``requestReplace``, ``acceptReplace``, ``withdrawReplace``
    - disallowed
- ``executeReplace``
    - if ``oldVault`` is liquidated
        - ``oldVVault``'s collateral is released as in ``executeRedeem`` above
    - if ``newVault`` is liquidated
        - ``newVault``'s remaining collateral is slashed as in ``executeIssue`` above
- ``cancelReplace``
    - if ``oldVault`` is liquidated
        - collateral is slashed to Liquidation Vault, as in ``cancelRedeem`` above
    - if ``newVault`` is liquidated
        - griefing collateral is slashed to ``newVault``'s free balance rather than to its backing collateral

Implementation Notes
--------------------

- In ``cancelIssue``, when the griefing collateral is slashed, it is forwarded to the fee pool.
- In ``cancelReplace``, when the griefing collateral is slashed, it is forwarded to the backing collateral to the Vault. In case the Vault is liquidated, it is forwarded to the free balance of the Vault.
- In ``premiumRedeem``, the griefing collateral is set as 0.
- In ``executeReplace``, the ``oldVault``'s griefing collateral is released, regardless of whether or not it is liquidated.
