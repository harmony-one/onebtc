.. _btc-relay:

BTC-Relay
==========

The BTC-Relay is responsible for storing Bitcoin block headers and maintaining the current longest chain.
We can use the stored block headers to verify transaction inclusion in Bitcoin.
Further, BTC_Relay exposes functions to validate that the contents of a transactions are as expected.

The specification of the `BTC-Relay is found here: https://interlay.gitlab.io/polkabtc-spec/btcrelay-spec/ <https://interlay.gitlab.io/polkabtc-spec/btcrelay-spec/>`_.

