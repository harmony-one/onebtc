.. _security-analysis:

Security Analysis
=================

Replay Attacks
~~~~~~~~~~~~~~

Without adequate protection, inclusion proofs for transactions on Bitcoin can be **replayed** by: (i) the user to trick ONEBTC component into issuing duplicate ONEBTC tokens and (ii) the vault to reuse a single transaction on Bitcoin to falsely prove multiple redeem, replace, and refund requests.
We employ two different mechanisms to achieve this:

1. *Identification via OP_RETURN*: When sending a Bitcoin transaction, the BTC-Parachain requires that a unique identifier is included as one of the outputs in the transaction.
2. *Unique Addresses via On-Chain Key Derivation*: The BTC-Parachain generates a new and unique address that Bitcoin can be transferred to.

The details of the transaction format can be found at the `accepted Bitcoin transaction format <https://interlay.gitlab.io/polkabtc-spec/btcrelay-spec/intro/accepted-format.html>`_.


.. _op-return:

OP_RETURN
---------

Applied in the following protocols:

- :ref:`redeem-protocol`
- :ref:`replace-protocol`
- :ref:`refund-protocol`

A simple and practical mitigation is to introduce unique identifiers for each protocol execution and require transactions on Bitcoin submitted to the BTC-Relay of these protocols to contain the corresponding identifier.

In this specification, we achieve this by requiring that vaults prepare a transaction with at least two outputs. One output is an OP_RETURN with a unique hash created in the :ref:`security` module.
Vaults are using Bitcoin full-nodes to send transactions and can easily and programmatically create transactions with an OP_RETURN output.

**UX Issues with OP_RETURN**

However, OP_RETURN has severe UX problems. Most Bitcoin wallets do not support OP_RETURN. That is, a user cannot use the UI to easily create an OP_RETURN transaction.
As of this writing, the only wallet that supports this out of the box is Electrum. Other wallets, such as Samurai, exist but only support mainnet transactions (hence, have not yet been tested).

In addition, while Bitcoin’s URI format (`BIP21 <https://en.bitcoin.it/wiki/BIP_0021>`_) generally supports OP_RETURN, none of the existing wallets have implemented an interpreter for this “upgraded” URI structure - this would have to be implemented manually by wallet providers.
An alternative solution is to pre-generate the Bitcoin transaction for the user. The problem with this is that - again - most Bitcoin wallets do not support parsing of raw Bitcoin transactions. That is, a user cannot easily verify that the raw Bitcoin transaction string provided by ONEBTC indeed does what it should do (and does not steal the user's funds). This approach works with hardware wallets, such as Ledger - but again, not all users will use ONEBTC from hardware wallets.




Unique Addresses via On-Chain Key Derivation
--------------------------------------------

Applied in the following protocol:

- :ref:`issue-protocol`

To avoid the use of OP_RETURN during the issue process, and the significant usability drawbacks incurred by this approach, we employ the use of an On-chain Key Derivation scheme (OKD) for Bitcoin’s ECDSA (secp256k1 curve). The BTC-Parachain maintains a BTC ‘master’ public key for each registered vault and generates a unique, ephemeral ‘deposit’ public key (and RIPEMD-160 address) for each issue request, utilizing the unique issue identifier for replay protection.

This way, each issue request can be linked to a distinct Bitcoin transaction via the receiving (‘deposit’) address, making it impossible for vaults/users to execute replay attacks. The use of OKD thereby allows to keep the issue process non-interactive, ensuring vaults cannot censor issue requests.

.. _okd:

On-Chain Key Derivation Scheme
..............................

We define the full OKD scheme as follows (additive notation):

**Preliminaries**

A Vault has a private/public keypair :math:`(v, V)`, where :math:`V = v·G` and :math:`G` is the base point of the secp256k1 curve.
Upon registration, the Vault submits public key :math:`V` to the BTC-Parachain storage.

**Issue protocol via new OKD scheme**

1. When a user creates an issue request, the BTC-Parachain
    a. Computes :math:`c = H(V || id)`, where id is the unique issue identifier, generated on-chain by the BTC-Parachain using the user’s AccountId and an internal auto-incrementing nonce as input.
    b. Generates a new public key (“deposit public key”) :math:`D = V·c` and then the corresponding BTC RIPEMD-160 hash-based address :math:`addr(D)` (‘deposit’ address) using :math:`D` as input.
    c. Stores :math:`D` and :math:`addr(D)` alongside the id of the Issue request.
2. The user deposits the amount of to-be-issued BTC to :math:`addr(D)` and submits the Bitcoin transaction inclusion proof, alongside the raw Bitcoin transaction, to BTC-Relay.
3. The BTC-Relay verifies that the destination address of the Bitcoin transaction is indeed :math:`addr(D)` (and the amount, etc.) and mints new ONEBTC to the user’s AccountId.
4. The Vault knows that the private key of :math:`D` is :math:`c·v`, where :math:`c = H(V || id)` is publicly known (can be computed by the Vault off-chain, or stored on-chain for convenience). The Vault can now import the private key :math:`c·v` into its Bitcoin wallet to gain access to the deposited BTC (required for redeem).


Counterfeiting
~~~~~~~~~~~~~~

A vault which receives lock transaction from a user during :ref:`issue-protocol` could use these coins to re-execute the issue itself, creating counterfeit ONEBTC.
This would result in ONEBTC being issued for the same amount of lock transaction breaking **consistency**, i.e., :math:`|locked_BTC| < |ONEBTC|`.
To this end, the ONEBTC component forbids vaults to move locked funds lock transaction received during :ref:`issue-protocol` and considers such cases as theft.
This theft is observable by any user.
However, we used the specific roles of Staked Relayers to report theft of BTC.
To restore **Consistency**, the ONEBTC component slashes the vault's entire collateral and executes automatic liquidation, yielding negative utility for the vault.
To allow economically rational vaults to move funds on the BTC Parachain we use the :ref:`replace-protocol`, a non-interactive atomic cross-chain swap (ACCS) protocol based on cross-chain state verification.


Permanent Blockchain Splits
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Permanent chain splits or *hard forks* occur where consensus rules are loosened or conflicting rules are introduced, resulting in multiple instances of the same blockchain.
Thereby, a mechanism to differentiate between the two resulting chains *replay protection* is necessary for secure operation.

Backing Chain
-------------

If replay protection is provided after a permanent split of Bitcoin, the BTC-Relay must be updated to verify the latter for Bitcoin (or Bitcoin' respectively).
If no replay protection is implemented, BTC-Relay will behave according to the protocol rules of Bitcoin for selecting the "main" chain. For example, it will follow the chain with most accumulated PoW under Nakamoto consensus.

Issuing Chain
-------------

A permanent fork on the issuing blockchain results in two chains I and I' with two instances of the ONEBTC component identified by the same public keys. To prevent an adversary exploiting this to execute replay attacks, both users and vaults must be required to include a unique identifier (or a digest thereof) in the transactions published on Bitcoin as part of :ref:`issue-protocol` and :ref:`redeem-protocol` (in addition to the identifiers introduces in Replay Attacks).

Next, we identify two possibilities to synchronize Bitcoin balances on I and I': (i) deploy a chain relay for I on I' and vice-versa to continuously synchronize the ONEBTC components or (ii) redeploy the ONEBTC component on both chains and require users and vaults to re-issue Bitcoin, explicitly selecting I or I'.

Denial-of-Service Attacks
~~~~~~~~~~~~~~~~~~~~~~~~~

ONEBTC is decentralized by design, thus making denial-of-service (DoS) attacks difficult. Given that any user with access to Bitcoin and BTC Parachain can become a vault, an adversary would have to target all vaults simultaneously. Where there are a large number of vaults, this attack would be impractical and expensive to perform. Alternatively, an attacker may try to target the ONEBTC component. However, performing a DoS attack against the ONEBTC component is equivalent to a DoS attack against the entire issuing blockchain or network, which conflicts with our assumptions of a resource bounded adversary and the security models of Bitcoin and BTC Parachain. Moreover, should an adversary perform a Sybil attack and register as a large number of vaults and ignore service requests to perform a DoS attack, the adversary would be required to lock up a large amount of collateral to be effective. This would lead to the collateral being slashed by the ONEBTC component, making this attack expensive and irrational.

Fee Model Security: Sybil Attacks and Extortion
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

While the exact design of the fee model lies beyond the scope of this paper, we outline the following two restrictions, necessary to protect against attacks by malicious vaults.

Sybil Attacks
-------------

To prevent financial gains from Sybil attacks, where a single adversary creates multiple low collateralized vaults, the ONEBTC component can enforce (i) a minimum necessary collateral amount and (ii) a fee model based on issued volume, rather than "pay-per-issue".
In practice, users can in principle easily filter out low-collateral vaults.

Extortion
---------

Without adequate restrictions, vaults could set extreme fees for executing :ref:`redeem-protocol`, making redeeming of Bitcoin unfeasible.
To this end, the ONEBTC component must enforce that either (i) no fees can be charged for executing :ref:`redeem-protocol` or (ii) fees for redeeming must be pre-agreed upon during \issue.


.. Collateral
.. ~~~~~~~~~~

.. Collateral thresholds>
.. * Secure
.. * PremiumRedeem
.. * Liquidation

.. .. not:: ONEBTC can never be force-liquidated from users. Reason: the tokens could be used in other applications and replacing these with ONE could have negative side-effects. An alternative is to define a new token standard for this (future work).

.. _griefing:

Griefing
~~~~~~~~

Griefing describes the act of blocking a vaults collateral by creating "bogus" requests. There are two cases:

1. A user can create an issue request without the intention to issue tokens. The user "blocks" the vault's collateral for a specific amount of time. if enough users execute this, a legitimate user could possibly not find a vault with free collateral to start an issue request.
2. A vault can request to be replaced without the intention to be replaced. When another vault accepts the replace request, that vault needs to lock additional collateral. The requesting vault, however, could never complete the replace request to e.g. ensure that it will be able to serve more issue requests.

For both cases, we require the requesting parties to lock up a (small) amount of griefing collateral. This makes such attacks costly for the attacker.


Concurrency
~~~~~~~~~~~

We need to ensure that concurrrent issue, redeem, and replace requests are handled.

Concurrent redeem
-----------------

We need to make sure that a vault cannot be used in multiple redeem requests in parallel if that would exceed his amount of locked BTC. **Example**: If the vault has 5 BTC locked and receives two redeem requests for 5 ONEBTC/BTC, he can only fulfil one and would lose his collateral with the other.

Concurrent issue and redeem
---------------------------

A vault can be used in parallel for issue and redeem requests. In the issue procedure, the vault's ``issuedTokens`` are already increased when the issue request is created. However, this is before (!) the BTC is sent to the vault. If we used these ``issuedTokens`` as a basis for redeem requests, we might end up in a case where the vault does not have enough BTC. **Example**: The vault already has 3 BTC in custody from previous successful issue procedures. A user creates an issue request for 2 ONEBTC. At this point, the ``issuedTokens`` by this vault are 5. However, his BTC balance is only 3. Now, a user could create a redeem request of 5 ONEBTC and the vault would have to fulfill those. The user could then cancel the issue request over 2 ONEBTC. The vault could only send 3 BTC to the user and would lose his deposit. Or the vault just loses his deposit without sending any BTC.

Solution
--------

We use seperate token balances to handle issue, replace, and redeem requests in the :ref:`Vault-registry`.
