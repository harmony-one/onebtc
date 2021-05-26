.. _accepted-tx-format:

Accepted Bitcoin Transaction Format
===================================

The :ref:`parser` module of BTC-Relay can in theory be used to parse arbitrary Bitcoin transactions.
However, the ONEBTC component of the BTC Bridge restricts the format of Bitcoin transactions to ensure consistency and prevent protocol failure due to parsing errors.

As such, Bitcoin transactions for which transaction inclusion proofs are submitted to BTC-Relay as part of the in the ONEBTC *Issue*, *Redeem*, and *Replace* protocols must be `P2PKH <https://en.bitcoinwiki.org/wiki/Pay-to-Pubkey_Hash>`_ or `P2WPKH <https://github.com/libbitcoin/libbitcoin-system/wiki/P2WPKH-Transactions>`_ transactions and follow the format below.

Case 1: OP_RETURN Transactions
------------------------------

The `OP_RETURN <https://bitcoin.org/en/transactions-guide#term-null-data>`_ field can be used to store `40 bytes in a given Bitcoin transaction <https://bitcoin.stackexchange.com/questions/29554/explanation-of-what-an-op-return-transaction-looks-like>`_. The transaction output that includes the OP_RETURN is provably unspendable. We require specific information in the OP_RETURN field to prevent replay attacks in ONEBTC.

Many Bitcoin wallets automatically order UTXOs. We require that the *Payment UTXO* and the *Data UTXO* are made within the first three indexes (index 0 - 2).
We *do not* require any specific ordering of those outputs.
The reason behind checking for the first three outputs is that wallets like Electrum might insert the UTXOs returning part of the spent input at index 1.

.. note:: Please refer to the ONEBTC specification for more details on the *Refund*, *Redeem* and *Replace* protocols.


.. tabularcolumns:: |l|L|

============================  ===========================================================
Inputs                        Outputs
============================  ===========================================================
*Arbitrary number of inputs*  **Index 0 to 2**:

                              *Payment UTXO*: P2PKH / P2WPKH output to ``btcAddress`` Bitcoin address.

                              *Data UTXO*: OP_RETURN containing ``identifier``

                              **Index 3-31**:

                              Any other UTXOs that will not be considered.

============================  ===========================================================

The value and recipient address (``btcAddress``) of the *Payment UTXO* and the ``identifier`` in the *Data UTXO* (OP_RETURN) depend on the executed ONEBTC protocol:

  + In *Refund* ``btcAddress`` is the Bitcoin address of the user for the refunding process and ``identifier`` is the ``refundId`` of the ``RefundRequest`` in ``RefundRequests``.
  + In *Redeem* ``btcAddress`` is the Bitcoin address of the user who triggered the redeem process and ``identifier`` is the ``redeemId`` of the ``RedeemRequest`` in ``RedeemRequests``.
  + In *Replace* ``btcAddress`` is the Bitcoin address of the new vault, which has agreed to replace the vault which triggered the replace protocol and ``identifier`` is the ``replaceId`` of the ``ReplaceRequest`` in ``ReplaceRequests``.

Case 2: Regular P2PKH / P2WPKH / P2SH / P2WSH Transactions
----------------------------------------------------------

We accept regular `P2PKH <https://en.bitcoinwiki.org/wiki/Pay-to-Pubkey_Hash>`_, `P2WPKH <https://github.com/libbitcoin/libbitcoin-system/wiki/P2WPKH-Transactions>`_, `P2SH <https://github.com/libbitcoin/libbitcoin-system/wiki/P2SH(P2WSH)-Transactions>`_, and `P2WSH <https://github.com/libbitcoin/libbitcoin-system/wiki/P2WSH-Transactions>`_ transactions.
We ensure that the recipient address is unique via the On-Chain Key Derivation Scheme.

Many Bitcoin wallets automatically order UTXOs. We require that the *Payment UTXO* is included within the first three indexes (index 0 - 2).
We *do not* require any specific ordering of those outputs.
The reason behind checking for the first three outputs is that wallets like Electrum might insert the UTXOs returning part of the spent input at index 1.

.. note:: Please refer to the ONEBTC specification for more details on the *Issue* protocol.

.. tabularcolumns:: |l|L|

============================  ===========================================================
Inputs                        Outputs
============================  ===========================================================
*Arbitrary number of inputs*  **Index 0 to 2**:

                              *Payment UTXO*: Output to ``btcAddress`` Bitcoin address.

                              **Index 3-31**:

                              Any other UTXOs that will not be considered.

============================  ===========================================================

The recipient address (``btcAddress``) of the *Payment UTXO* is a address derived from the public key the vault submitted to the BTC-Bridge.