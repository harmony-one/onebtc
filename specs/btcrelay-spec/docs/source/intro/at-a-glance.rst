BTC-Relay at a Glance
=====================

Overview
--------

BTC-Relay is the key component of the BTC Bridge on Harmony. It's main task is to allow the Bridge to verify the state of Bitcoin and react to transactions and events.
Specifically, BTC-Relay acts as a `Bitcoin SPV/light client <https://bitcoin.org/en/operating-modes-guide#simplified-payment-verification-spv>`_ on Harmony, storing only Bitcoin block headers and allowing users to verify transaction inclusion proofs.
Further, it is able to handle forks and follows the chain with the most accumulated Proof-of-Work.

The correct operation of BTC-Relay is crucial: should BTC-Relay cease to operate, the bridge between Harmony and Bitcoin is interrupted.

.. figure:: ../figures/polkaBTC-btcrelay.png
    :alt: Overview of BTC-Relay as a component of the BTC Bridge

    BTC-Relay (highlighted in blue) is a key component of the BTC Bridge: it is necessary to verify and keep track of the state of Bitcoin.


How to Use this Document
------------------------
This document provides a specification for BTC-Relay in the form of a Harmony Bridge acting as a Bridge to Bitcoin, to be implemented on `Substrate <https://substrate.dev/>`_.


Before implementing or using BTC-Relay on Harmony, make yourself familiar with this specification and read up on any content you are unfamiliar with by following the provided links (e.g. to academic papers and the `Bitcoin developer reference <https://bitcoin.org/en/developer-reference>`_).


Recommended Background Reading
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We also recommend readers, unfamiliar with the problem of cross-chain communication, to study the following papers - in addition to acquiring a base understanding for the operation and security model of distributed ledgers.

+ **XCLAIM: Trustless, Interoperable, Cryptocurrency-backed Assets**. *IEEE Security and Privacy (S&P).* Zamyatin, A., Harz, D., Lind, J., Panayiotou, P., Gervais, A., & Knottenbelt, W. (2019). `[PDF] <https://eprint.iacr.org/2018/643.pdf>`__
+ **SoK: Communication Across Distributed Ledgers**. *Cryptology ePrint Archiv, Report 2019/1128*. Zamyatin A, Al-Bassam M, Zindros D, Kokoris-Kogias E, Moreno-Sanchez P, Kiayias A, Knottenbelt WJ. (2019) `[PDF] <https://eprint.iacr.org/2019/1128.pdf>`__
+ **Proof-of-Work Sidechains**. *Workshop on Trusted Smart Contracts, Financial Cryptography* Kiayias, A., & Zindros, D. (2018) `[PDF] <https://eprint.iacr.org/2018/1048.pdf>`__
+ **Enabling Blockchain Innovations with Pegged Sidechains**. *Back, A., Corallo, M., Dashjr, L., Friedenbach, M., Maxwell, G., Miller, A., Poelstra A., Timon J.,  & Wuille, P*. (2019) `[PDF] <https://blockstream.com/sidechains.pdf>`__
