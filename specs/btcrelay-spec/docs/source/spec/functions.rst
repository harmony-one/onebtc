.. _storage-verification:

Functions: Storage and Verification
===================================

.. _initialize:

initialize
----------

Initializes BTC-Relay with the first Bitcoin block to be tracked and initializes all data structures (see :ref:`data-model`).

.. note:: BTC-Relay **does not** have to be initialized with Bitcoin's genesis block! The first block to be tracked can be selected freely.

.. warning:: Caution when setting the first block in BTC-Relay: only succeeding blocks can be submitted and **predecessors will be rejected**!


Specification
~~~~~~~~~~~~~

*Function Signature*

``initialize(blockHeaderBytes, blockHeight)``

*Parameters*

* ``relayer``: the account submitting the block
* ``blockHeaderBytes``: 80 byte raw Bitcoin block header
* ``blockHeight``: integer Bitcoin block height of the submitted block header

*Events*

* ``Initialized(blockHeight, blockHash, relayer)``: if the first block header was stored successfully, emit an event with the stored block's height (``blockHeight``) and the (PoW) block hash (``blockHash``).

*Errors*

* ``ERR_ALREADY_INITIALIZED = "Already initialized"``: return error if this function is called after BTC-Relay has already been initialized.

Preconditions
~~~~~~~~~~~~~

* This is the first time this function is called, i.e., when BTC-Relay is being deployed.

Function sequence
~~~~~~~~~~~~~~~~~

1. Check if ``initialize`` is called for the first time. Return ``ERR_ALREADY_INITIALIZED`` if BTC-Relay has already been initialized.

2. Parse ``blockHeaderBytes``, extracting  the ``merkleRoot`` (:ref:`extractMerkleRoot`), ``timestamp`` (:ref:`extractTimestamp`) and ``target`` (:ref:`extractNBits` and :ref:`nBitsToTarget`) from ``blockHeaderBytes``, and compute the block hash (``hashCurrentBlock``) using :ref:`sha256d` (passing ``blockHeaderBytes`` as parameter).

3. Create a new ``BlockChain`` entry in ``Chains``:

    - ``chainId =``:ref:`getChainsCounter`
    - ``startHeight = blockHeight``
    - ``maxHeight = blockHeight``
    - ``noData = Vec::new()``
    - ``invalid = Vec::new()``
    - Insert ``hashCurrentBlock`` in the ``chain`` mapping using ``blockHeight`` as key.

4. Insert a pointer to ``BlockChain`` into ``ChainsIndex`` using  ``chainId`` as key.

5. Store a new ``RichBlockHeader`` struct containing ``merkleRoot``, ``blockHeight``, ``timestamp``, ``target``, and a pointer (``chainRef``) to the ``BlockChain`` struct - as associated with this block header - in ``BlockHeaders``, using ``hashCurrentBlock`` as key.

6. Set ``BestBlock = hashCurrentBlock`` and ``BestBlockHeight = blockHeight``.

7. Emit a ``Initialized`` event using ``height`` and ``hashCurrentBlock`` as input.

.. warning:: Attention: the Bitcoin block header submitted to ``initialize`` must be in the Bitcoin main chain - this must be checked outside of the BTC Parachain **before** making this function call! A wrong initialization will cause the entire BTC Parachain to fail, since verification requires that all submitted blocks **must** (indirectly) point to the initialized block (i.e., have it as ancestor, just like the actual Bitcoin genesis block).

.. _storeBlockHeader:

storeBlockHeader
----------------

Method to submit block headers to the BTC-Relay. This function calls  :ref:`verifyBlockHeader` providing the 80 bytes Bitcoin block header as input, and, if the latter returns ``True``, extracts from the block header and stores the hash, height and Merkle tree root of the given block header in ``BlockHeaders``.
If the block header extends an existing ``BlockChain`` entry in ``Chains``, it appends the block hash to the ``chains`` mapping and increments the ``maxHeight``. Otherwise, a new ``Blockchain`` entry is created.

Specification
~~~~~~~~~~~~~

*Function Signature*

``storeBlockHeader(relayer, blockHeaderBytes)``

*Parameters*

* ``relayer``: the account submitting the block
* ``blockHeaderBytes``: 80 byte raw Bitcoin block header.

*Events*

* ``StoreMainChainHeader(blockHeight, blockHash, relayer)``: if the block header was successful appended to the currently longest chain (*main chain*) emit an event with the stored block's height (``blockHeight``) and the (PoW) block hash (``blockHash``).
* ``StoreForkHeader(forkId, blockHeight, blockHash, relayer)``: if the block header was successful appended to a new or existing fork, emit an event with the block height (``blockHeight``) and the (PoW) block hash (``blockHash``).

Preconditions
~~~~~~~~~~~~~

* The BTC Parachain status must not be set to ``SHUTDOWN: 3``.

.. warning:: The BTC-Relay does not necessarily have the same view of the Bitcoin blockchain as the user's local Bitcoin client. This can happen if (i) the BTC-Relay is under attack, (ii) the BTC-Relay is out of sync, or, similarly, (iii) if the user's local Bitcoin client is under attack or out of sync (see :ref:`security`).

.. note:: The 80 bytes block header can be retrieved from the `bitcoin-rpc client <https://en.bitcoin.it/wiki/Original_Bitcoin_client/API_calls_list>`_ by calling the `getBlock <https://bitcoin-rpc.github.io/en/doc/0.17.99/rpc/blockchain/getblock/>`_ and setting verbosity to ``0`` (``getBlock <blockHash> 0``).


Function sequence
~~~~~~~~~~~~~~~~~

1. Call :ref:`verifyBlockHeader` passing ``blockHeaderBytes`` as function parameter. If this call **returns an error** , then abort and return the raised error. If successful, this call returns a parsed ``BlockHeader`` (``BlockHeader``) struct.

2. Determine which ``BlockChain`` entry in ``Chains`` this block header is extending, or if it is a new fork and hence a new ``BlockChain`` entry needs to be created. For this, get the ``prevBlockHeader`` (``RichBlockHeader``) stored in ``BlockHeaders`` with ``BlockHeader.hashPrevBlock`` and use ``prevBlockHeader.chainRef`` to lookup the associated ``BlockChain`` struct in ``ChainsIndex``. Then, check if the  ``prevBlockHeader.blockHeight`` (as referenced by ``hashPrevBlock``) is equal  to ``BlockChain.maxHeight``.

   a. If not equal (can only be less in this case), then the current submission is creating a **new fork**.

    i ) Create a new ``BlockChain`` struct, setting ``BlockChain.startHeight = RichBlockHeader.blockHeight`` (as referenced in ``hashPrevBlock``), ``BlockChain.maxHeight = RichBlockHeader.blockHeight + 1`` (as referenced in ``hashPrevBlock``), and appending ``hashCurrentBlock`` (compute the block hash using :ref:`sha256d`, passing ``blockHeaderBytes`` as parameter) to the (currently empty) ``BlockChain.chain`` mapping.

    ii ) Set ``BlockChain.chainId =`` :ref:`getChainsCounter`.

    iii ) Insert the new ``BlockChain`` into ``Chains``.

    iv ) Insert the new ``BlockChain`` into ``ChainsIndex`` using  ``BlockChain.chainId`` as key.

  b. Otherwise, if equal, then the current submission is **extending** the ``BlockChain`` referenced by ``RichBlockHeader.chainRef`` (as per``hashPrevBlock``).

    i )  Append the ``hashCurrentBlock`` to the ``chain``  map in ``BlockChain`` and **increment** ``maxHeight``

    ii ) Check if a blockchain reorganization is necessary. For this, call :ref:`checkAndDoReorg` passing the pointer to ``BlockChain`` as parameter.

3. Check if ``BlockChain`` is the main chain, i.e. check if ``chainId == MAIN_CHAIN_ID``.

   a. If ``BlockChain`` **is not** the main chain (``chainId =/= MAIN_CHAIN_ID``) and  ``BlockChain.maxHeight > nextBestForkHeight`` set ``nextBestForkHeight = BlockChain.maxHeight``.

   b. If ``BlockChain`` **is** the main chain (``chainId == MAIN_CHAIN_ID``) set ``BestBlock = hashCurrentBlock``  and ``BestBlockHeight = BlockChain.maxHeight``.

4. Create a new ``RichBlockHeader`` and initalize as follows:

  * ``RichBlockHeader.blockHeight = prevBlock.blockHeight + 1``,
  * ``RichBlockHeader.chainRef = BlockChain.chainId``,
  * ``RichBlockHeader.merkleRoot = BlockHeader.merkleRoot``,
  * ``RichBlockHeader.target = BlockHeader.target``,
  * ``RichBlockHeader.timestamp = BlockHeader.timestamp``,
  * ``RichBlockHeader.hashPrevBlock = BlockHeader.hashPrevBlock``

5. Insert ``RichBlockHeader`` into ``BlockHeaders`` using ``hashCurrentBlock`` as key.

6. Emit event.

   a. If submission was to *main chain* (``BlockChain`` with ``chainId == MAIN_CHAIN_ID``), emit ``StoreMainChainBlockHeader`` event using ``height`` and ``hashCurrentBlock`` as input (``StoreMainChainHeader(height, hashCurrentBlock)``).

   b. If submission was to another ``BlockChain`` entry (new or existing), emit ``StoreForkHeader(height, hashCurrentBlock)``.


.. figure:: ../figures/storeBlockHeader-sequence.png
    :alt: storeBlockHeader sequence diagram

    Sequence diagram showing the function sequence of :ref:`storeBlockHeader`.


.. _checkAndDoReorg:

checkAndDoReorg
---------------

This function is called from :ref:`storeBlockHeader` and checks if a block header submission resulted in a chain reorganization.
Updates the ordering in / re-balances ``Chains`` if necessary.


Specification
~~~~~~~~~~~~~

*Function Signature*

``checkAndDoReorg(fork)``

*Parameters*

* ``&fork``: pointer to a ``BlockChain`` entry in ``Chains``.

*Events*

*  ``ChainReorg(newChainTip, blockHeight, forkDepth)``: if the submitted block header on a fork results in a reorganization (fork longer than current main chain), emit an event with the block hash of the new highest block (``newChainTip``), the new maximum block height (``blockHeight``) and the depth of the fork (``forkDepth``).

Function Sequence
~~~~~~~~~~~~~~~~~

1.  Check if the ordering of the ``BlockChain`` entry needs updating. For this, check the ``maxHeight`` of the "next-highest" ``BlockChain`` (parent in heap or predecessor in sorted linked list) in ``Chains``.

   a. If ``fork`` is the top-level element, i.e., the main chain, do nothing.

   b. Else if the "next-highest" entry has a lower ``maxHeight``, update ordering by switching positions - continue, until reaching the "top" of the ``Chains`` data structure or a ``BlockChain`` entry with a higher ``maxHeight``.

2. If ordering was updated, check if the top-level element in the ``Chains`` data structure changed (i.e., is no longer the main chain defined by ``MAIN_CHAIN_ID``). If this is the case:

  a. Retrieve the main chain ``BlockChain`` entry (``mainChain``) from ``ChainsIndex`` using ``MAIN_CHAIN_ID``

  b. Check if the ``maxHeight`` of the new top-level ``BlockChain`` exceeds ``mainChain.maxHeight`` by at least ``STABLE_BITCOIN_CONFIRMATIONS``. If true, continue. If false, ``return`` (no chain reorg needs to be executed yet).

  a. Create a new empty ``BlockChain`` (``forkedMainChain``) struct and initalize with:

    - ``forkedMainChain.chainId =`` :ref:`getChainsCounter`,
    - ``forkedMainChain.chain = HashMap::new()``
    - ``forkedMainChain.startHeight = fork.startHeight``,
    - ``forkedMainChain.maxHeight = mainChain.maxHeight``
    - ``forkedMainChain.noData = Vec::new()``
    - ``forkedMainChain.invalid = Vec::new()``

  b. Loop: starting from ``fork.startHeight`` as ``currHeight`` until ``fork.maxHeight``:

    i ) Set ``forkedMainChain.chain[currHeight] = mainChain.chain[currHeight]`` (overwrite the forked out main chain blocks with blocks in the fork).

    ii ) Get the ``RichBlockHeader`` for the new ``mainChain.chain[currHeight]`` and update its ``chainRef`` to point to ``mainChain``.

    iii ) Set ``forkedMainChain.chain[currHeight] = fork.chain[currHeight]`` (write forked main chain blocks to new ``BlockChain`` entry to be tracked as an ongoing fork).

    iv ) Get the ``RichBlockHeader`` for the new ``forkedMainChain.chain[currHeight]`` and update its ``chainRef`` to point to ``forkedMainChain``.

    v ) If ``currHeight > mainChain.maxHeight`` set ``mainChain.maxHeight = currHeight``.

  c. For each block height in ``fork.noData`` and ``fork.invalid``: add the block height to ``mainChain.noData`` and ``mainChain.noData`` respectively.

  d. Update ``BestBlockHeight = mainChain.maxHeight`` and ``BestBlock = mainChain.chain[mainChain.maxHeight]`` (``nextBestForkHeight`` updated in :ref:`storeBlockHeader`).

  f. Check that ``noData`` or ``invalid`` are both **empty** in ``mainChain``. If this is the case, check if we need to update the BTC Parachain state.

    i ) If ``noData`` or ``invalid`` are both **empty** and ``Errors`` in :ref:`security` contains ``NO_DATA_BTC_RELAY`` or ``INVALID_BTC_RELAY`` call ``recoverFromBTCRelayFailure`` to recover the BTC Parachain from the BTC-Relay related error.

    ii ) If ``ParachainStatus`` is set to ``RUNNING`` and either ``noData`` or ``invalid`` are **not empty** in the new main chain ``BlockChain`` entry: update ``ParachainStatus`` to ``ERROR`` and append ``NO_DATA_BTC_RELAY`` or ``INVALID_BTC_RELAY`` (depending on which of ``invalid`` and ``noData`` lists was not empty) to the ``Errors`` list.

  g. Remove ``fork`` from ``Chains``.

  h. Emit a ``ChainReorg(newChainTip, blockHeight, forkDepth)``, where ``newChainTip`` is the new ``BestBlock``, ``blockHeight`` is the new ``BestBlockHeight``, and ``forkDepth`` is the depth of the fork (``fork.maxHeight - fork.startHeight``).

.. note:: We may want to track the ``mainChain`` identifier separately for quicker access (same main chain updated in case of forks).

.. _verifyBlockHeader:

verifyBlockHeader
-----------------

The ``verifyBlockHeader`` function parses and verifies Bitcoin block headers.
If all checks are successful, returns a ``BlockHeader`` representation of the 80 byte raw block header given as input.

.. note:: This function does not check whether the submitted block header extends the main chain or a fork. This check is performed in :ref:`storeBlockHeader`.

Specification
~~~~~~~~~~~~~~
*Function Signature*

``verifyBlockHeader(blockHeaderBytes)``

*Parameters*

* ``blockHeaderBytes``: 80 byte raw Bitcoin block header.


*Returns*

* ``BlockHeader``: if all checks pass successfully, return a parsed ``BlockHeader``.

*Errors*


* ``ERR_DUPLICATE_BLOCK = "Block already stored"``: return error if the submitted block header is already stored in BTC-Relay (duplicate PoW ``blockHash``).
* ``ERR_PREV_BLOCK = "Previous block hash not found"``: return error if the submitted block does not reference an already stored block header as predecessor (via ``prevBlockHash``).
* ``ERR_LOW_DIFF = "PoW hash does not meet difficulty target of header"``: return error when the header's ``blockHash`` does not meet the ``target`` specified in the block header.
* ``ERR_DIFF_TARGET_HEADER = "Incorrect difficulty target specified in block header"``: return error if the ``target`` specified in the block header is incorrect for its block height (difficulty re-target not executed).

.. *Substrate*::

  fn verifyBlockHeader(origin, blockHeaderBytes: RawBlockHeader) -> H256 {...}

Function Sequence
~~~~~~~~~~~~~~~~~

1. Call :ref:`parseBlockHeader` passing ``blockHeaderBytes`` as parameter to parse the block header. If this call returns an error, abort and return the error. If successful, :ref:`parseBlockHeader` returns a parsed ``BlockHeader`` (``BlockHeader``) struct.

2. Compute ``hashCurrentBlock``, the double SHA256 hash over the 80 bytes block header, using :ref:`sha256d` (passing ``blockHeaderBytes`` as parameter).

3. Check that the block header is not yet stored in BTC-Relay (``hashCurrentBlock`` must not yet be in ``BlockHeaders``). Return ``ERR_DUPLICATE_BLOCK`` otherwise.

4. Get the ``RichBlockHeader`` (``prevBlock``) referenced by the submitted block header via ``BlockHeader.hashPrevBlock``. Return ``ERR_PREV_BLOCK`` if no such entry was found.

5. Check that the Proof-of-Work hash (``hashCurrentBlock``) is below the ``BlockHeader.target``. Return ``ERR_LOW_DIFF`` otherwise.

6. Check that the ``BlockHeader.target`` is correct by calling :ref:`checkCorrectTarget` passing ``BlockHeader.hashPrevBlock``, ``prevBlock.blockHeight`` and ``BlockHeader.target`` as parameters (as per Bitcoin's difficulty adjustment mechanism, see `here <https://github.com/bitcoin/bitcoin/blob/78dae8caccd82cfbfd76557f1fb7d7557c7b5edb/src/pow.cpp>`_). If this call returns ``False``, return ``ERR_DIFF_TARGET_HEADER``.

7. Return ``BlockHeader``

.. figure:: ../figures/verifyBlockHeader-sequence.png
    :alt: verifyBlockHeader sequence diagram

    Sequence diagram showing the function sequence of :ref:`verifyBlockHeader`.


.. _verifyTransactionInclusion:

verifyTransactionInclusion
--------------------------

The ``verifyTransactionInclusion`` function is one of the core components of the BTC-Relay: this function checks if a given transaction was indeed included in a given block (as stored in ``BlockHeaders`` and tracked by ``Chains``), by reconstructing the Merkle tree root (given a Merkle proof). Also checks if sufficient confirmations have passed since the inclusion of the transaction (considering the current state of the BTC-Relay ``Chains``).

Specification
~~~~~~~~~~~~~

*Function Signature*

``verifyTransactionInclusion(txId, merkleProof, confirmations, insecure)``

*Parameters*

* ``txId``: 32 byte hash identifier of the transaction.
* ``merkleProof``: Merkle tree path (concatenated LE sha256 hashes, dynamic sized).
* ``confirmations``: integer number of confirmation required.

.. note:: The Merkle proof for a Bitcoin transaction can be retrieved using the ``bitcoin-rpc`` `gettxoutproof <https://bitcoin-rpc.github.io/en/doc/0.17.99/rpc/blockchain/gettxoutproof/>`_ method and dropping the first 170 characters. The Merkle proof thereby consists of a list of SHA256 hashes, as well as an indicator in which order the hash concatenation is to be applied (left or right).

*Returns*

* ``True``: if the given ``txId`` appears in at the position specified by ``txIndex`` in the transaction Merkle tree of the block at height ``blockHeight`` and sufficient confirmations have passed since inclusion.
* Error otherwise.

*Events*

* ``VerifyTransaction(txId, txBlockHeight, confirmations)``: if verification was successful, emit an event specifying the ``txId``, the ``blockHeight`` and the requested number of ``confirmations``.

*Errors*

* ``ERR_SHUTDOWN = "BTC Parachain has shut down"``: the BTC Parachain has been shutdown by a manual intervention of the Governance Mechanism.
* ``ERR_MALFORMED_TXID = "Malformed transaction identifier"``: return error if the transaction identifier (``txId``) is malformed.
* ``ERR_CONFIRMATIONS = "Transaction has less confirmations than requested"``: return error if the block in which the transaction specified by ``txId`` was included has less confirmations than requested.
* ``ERR_INVALID_MERKLE_PROOF = "Invalid Merkle Proof"``: return error if the Merkle proof is malformed or fails verification (does not hash to Merkle root).
* ``ERR_ONGOING_FORK = "Verification disabled due to ongoing fork"``: return error if the ``mainChain`` is not at least ``STABLE_BITCOIN_CONFIRMATIONS`` ahead of the next best fork.

Preconditions
~~~~~~~~~~~~~

* The BTC Parachain status must not be set to ``SHUTDOWN: 3``. If ``SHUTDOWN`` is set, all transaction verification is disabled.


Function Sequence
~~~~~~~~~~~~~~~~~

1. Check that ``txId`` is 32 bytes long. Return ``ERR_MALFORMED_TXID`` error if this check fails.

2. Check that the current ``BestBlockHeight`` exceeds ``txBlockHeight`` by the requested confirmations.  Return ``ERR_CONFIRMATIONS`` if this check fails.

  a. If ``insecure == True``, check against user-defined ``confirmations`` only

  b. If ``insecure == True``, check against ``max(confirmations, STABLE_BITCOIN_CONFIRMATIONS)``.

3. Check if the Bitcoin block was stored for a sufficient number of blocks (on the parachain) to ensure that staked relayers had the time to flag the block as potentially invalid. Check performed against ``STABLE_PARACHAIN_CONFIRMATIONS``.

4. Extract the block header from ``BlockHeaders`` using the ``blockHash`` tracked in ``Chains`` at the passed ``txBlockHeight``.

5. Check that the first 32 bytes of ``merkleProof`` are equal to the ``txId`` and the last 32 bytes are equal to the ``merkleRoot`` of the specified block header. Also check that the ``merkleProof`` size is either exactly 32 bytes, or is 64 bytes or more and a power of 2. Return ``ERR_INVALID_MERKLE_PROOF`` if one of these checks fails.

6. Call :ref:`computeMerkle` passing ``txId``, ``txIndex`` and ``merkleProof`` as parameters.

  a. If this call returns the ``merkleRoot``, emit a ``VerifyTransaction(txId, txBlockHeight, confirmations)`` event and return ``True``.

  b. Otherwise return ``ERR_INVALID_MERKLE_PROOF``.

.. figure:: ../figures/verifyTransaction-sequence.png
    :alt: verifyTransactionInclusion sequence diagram

    The steps to verify a transaction in the :ref:`verifyTransactionInclusion` function.

.. _validateTransaction:

validateTransaction
--------------------

Given a raw Bitcoin transaction, this function

1) Parses and extracts

   a. the value and recipient address of the *Payment UTXO*,
   b. [Optionally] the OP_RETURN value of the *Data UTXO*.

2) Validates the extracted values against the function parameters.

.. note:: See :ref:`bitcoin-data-model` for more details on the transaction structure, and :ref:`accepted-tx-format` for the transaction format of Bitcoin transactions validated in this function.

Specification
~~~~~~~~~~~~~

*Function Signature*

``validateTransaction(rawTx, paymentValue, recipientBtcAddress, opReturnId)``

*Parameters*

* ``rawTx``:  raw Bitcoin transaction including the transaction inputs and outputs.
* ``paymentValue``: integer value of BTC sent in the (first) *Payment UTXO* of transaction.
* ``recipientBtcAddress``: 20 byte Bitcoin address of recipient of the BTC in the (first) *Payment UTXO*.
* ``opReturnId``: [Optional] 32 byte hash identifier expected in OP_RETURN (see :ref:`replace-attacks`).

*Returns*

* ``True``: if the transaction was successfully parsed and validation of the passed values was correct.
* Error otherwise.

*Events*

* ``ValidateTransaction(txId, paymentValue, recipientBtcAddress, opReturnId)``: if parsing and validation was successful, emit an event specifying the ``txId``, the ``paymentValue``, the ``recipientBtcAddress`` and the ``opReturnId``.

*Errors*

* ``ERR_INSUFFICIENT_VALUE = "Value of payment below requested amount"``: return error the value of the (first) *Payment UTXO* is lower than ``paymentValue``.
* ``ERR_TX_FORMAT = "Transaction has incorrect format"``: return error if the transaction has an incorrect format (see :ref:`accepted-tx-format`).
* ``ERR_WRONG_RECIPIENT = "Incorrect recipient Bitcoin address"``: return error if the recipient specified in the (first) *Payment UTXO* does not match the given ``recipientBtcAddress``.
* ``ERR_INVALID_OPRETURN = "Incorrect identifier in OP_RETURN field"``: return error if the OP_RETURN field of the (second) *Data UTXO* does not match the given ``opReturnId``.

Preconditions
~~~~~~~~~~~~~

* The BTC Parachain status must not be set to ``SHUTDOWN: 3``. If ``SHUTDOWN`` is set, all transaction validation is disabled.

Function Sequence
~~~~~~~~~~~~~~~~~

See the `raw Transaction Format section in the Bitcoin Developer Reference <https://bitcoin.org/en/developer-reference#raw-transaction-format>`_ for a full specification of Bitcoin's transaction format (and how to extract inputs, outputs etc. from the raw transaction format).

1. Extract the ``outputs`` from ``rawTx`` using :ref:`extractOutputs`.

  a. Check that the transaction (``rawTx``) has at least 2 outputs. One output (*Payment UTXO*) must be a `P2PKH <https://en.bitcoinwiki.org/wiki/Pay-to-Pubkey_Hash>`_ or `P2WPKH <https://github.com/libbitcoin/libbitcoin-system/wiki/P2WPKH-Transactions>`_ output. Another output (*Data UTXO*) must be an `OP_RETURN <https://bitcoin.org/en/transactions-guide#term-null-data>`_ output. Raise ``ERR_TX_FORMAT`` if this check fails.

2. Extract the value of the *Payment UTXO* using :ref:`extractOutputValue` and check that it is equal (or greater) than ``paymentValue``. Return ``ERR_INSUFFICIENT_VALUE`` if this check fails.

3. Extract the Bitcoin address specified as recipient in the *Payment UTXO* using :ref:`extractOutputAddress` and check that it matches ``recipientBtcAddress``. Return ``ERR_WRONG_RECIPIENT`` if this check fails, or the error returned by :ref:`extractOutputAddress` (if the output was malformed).

4. Extract the OP_RETURN value from the *Data UTXO* using :ref:`extractOPRETURN` and check that it matches ``opReturnId``. Return ``ERR_INVALID_OPRETURN`` error if this check fails, or the error returned by :ref:`extractOPRETURN` (if the output was malformed).

.. _verifyAndValidateTransaction:

verifyAndValidateTransaction
----------------------------

The ``verifyAndValidateTransaction`` function is a wrapper around the :ref:`verifyTransactionInclusion` and the :ref:`validateTransaction` functions. It adds an additional check to verify that the validated transaction is the one included in the specified block.

Specification
~~~~~~~~~~~~~

*Function Signature*

``verifyAndValidateTransaction(merkleProof, confirmations, rawTx, paymentValue, recipientBtcAddress, opReturnId)``

*Parameters*

* ``txId``: 32 byte hash identifier of the transaction.
* ``merkleProof``: Merkle tree path (concatenated LE sha256 hashes, dynamic sized).
* ``confirmations``: integer number of confirmation required.
* ``rawTx``:  raw Bitcoin transaction including the transaction inputs and outputs.
* ``paymentValue``: integer value of BTC sent in the (first) *Payment UTXO* of transaction.
* ``recipientBtcAddress``: 20 byte Bitcoin address of recipient of the BTC in the (first) *Payment UTXO*.
* ``opReturnId``: [Optional] 32 byte hash identifier expected in OP_RETURN (see :ref:`replace-attacks`).

*Returns*

* ``True``: If the same transaction has been verified and validated.
* Error otherwise.

Function Sequence
~~~~~~~~~~~~~~~~~

#. Parse the ``rawTx`` to get the tx id.
#. Call :ref:`verifyTransactionInclusion` with the applicable parameters.
#. Call :ref:`validateTransaction` with the applicable parameters.


.. _flagBlockError:

flagBlockError
----------------

Flags tracked Bitcoin block headers when Staked Relayers report and agree on a ``NO_DATA_BTC_RELAY`` or ``INVALID_BTC_RELAY`` failure.

.. attention:: This function **does not** validate the Staked Relayers accusation. Instead, it is put up to a majority vote among all Staked Relayers in the form of a

.. note:: This function can only be called from the *Security* module of ONEBTC, after Staked Relayers have achieved a majority vote on a BTC Parachain status update indicating a BTC-Relay failure.

Specification
~~~~~~~~~~~~~~

*Function Signature*

``flagBlockError(blockHash, errors)``


*Parameters*

* ``blockHash``: SHA256 block hash of the block containing the error.
* ``errors``: list of ``ErrorCode`` entries which are to be flagged for the block with the given blockHash. Can be "NO_DATA_BTC_RELAY" or "INVALID_BTC_RELAY".


*Events*

* ``FlagBTCBlockError(blockHash, chainId, errors)`` - emits an event indicating that a Bitcoin block hash (identified ``blockHash``) in a ``BlockChain`` entry (``chainId``) was flagged with errors (``errors`` list of ``ErrorCode`` entries).

*Errors*

* ``ERR_UNKNOWN_ERRORCODE = "The reported error code is unknown"``: The reported ``ErrorCode`` can only be ``NO_DATA_BTC_RELAY`` or ``INVALID_BTC_RELAY``.
* ``ERR_BLOCK_NOT_FOUND  = "No Bitcoin block header found with the given block hash"``: No ``RichBlockHeader`` entry exists with the given block hash.
* ``ERR_ALREADY_REPORTED = "This error has already been reported for the given block hash and is pending confirmation"``: The error reported for the given block hash is currently pending a vote by Staked Relayers.


Function Sequence
.................

1. Check if ``errors`` contains  ``NO_DATA_BTC_RELAY`` or ``INVALID_BTC_RELAY``. If neither match, return ``ERR_UNKNOWN_ERRORCODE``.

2. Retrieve the ``RichBlockHeader`` entry from ``BlockHeaders`` using ``blockHash``. Return ``ERR_BLOCK_NOT_FOUND`` if no block header can be found.

3. Retrieve the ``BlockChain`` entry for the given ``RichBlockHeader`` using ``ChainsIndex`` for lookup with the block header's ``chainRef`` as key.

4. Flag errors in the ``BlockChain`` entry:

   a. If ``errors`` contains ``NO_DATA_BTC_RELAY``, append the ``RichBlockHeader.blockHeight`` to ``BlockChain.noData``

   b. If ``errors`` contains ``INVALID_BTC_RELAY``,  append the ``RichBlockHeader.blockHeight`` to ``BlockChain.invalid`` .

5. Emit ``FlagBTCBlockError(blockHash, chainId, errors)`` event, with the given ``blockHash``, the ``chainId`` of the flagged ``BlockChain`` entry and the given ``errors`` as parameters.

6. Return


.. _clearBlockError:

clearBlockError
------------------

Clears ``ErrorCode`` entries given as parameters from the status of a ``RichBlockHeader``.  Can be ``NO_DATA_BTC_RELAY`` or ``INVALID_BTC_RELAY`` failure.

.. note:: This function can only be called from the *Security* module of ONEBTC, after Staked Relayers have achieved a majority vote on a BTC Parachain status update indicating that a ``RichBlockHeader`` entry no longer has the specified errors.


Specification
~~~~~~~~~~~~~~

*Function Signature*

``flagBlockError(blockHash, errors)``

*Parameters*

* ``blockHash``: SHA256 block hash of the block containing the error.
* ``errors``: list of ``ErrorCode`` entries which are to be **cleared** from the block with the given blockHash. Can be ``NO_DATA_BTC_RELAY`` or ``INVALID_BTC_RELAY``.


*Events*

* ``ClearBlockError(blockHash, chainId, errors)`` - emits an event indicating that a Bitcoin block hash (identified ``blockHash``) in a ``BlockChain`` entry (``chainId``) was cleared from the given errors (``errors`` list of ``ErrorCode`` entries).

*Errors*

* ``ERR_UNKNOWN_ERRORCODE = "The reported error code is unknown"``: The reported ``ErrorCode`` can only be ``NO_DATA_BTC_RELAY`` or ``INVALID_BTC_RELAY``.
* ``ERR_BLOCK_NOT_FOUND  = "No Bitcoin block header found with the given block hash"``: No ``RichBlockHeader`` entry exists with the given block hash.
* ``ERR_ALREADY_REPORTED = "This error has already been reported for the given block hash and is pending confirmation"``: The error reported for the given block hash is currently pending a vote by Staked Relayers.


Function Sequence
.................

1. Check if ``errors`` contains  ``NO_DATA_BTC_RELAY`` or ``INVALID_BTC_RELAY``. If neither match, return ``ERR_UNKNOWN_ERRORCODE``.

2. Retrieve the ``RichBlockHeader`` entry from ``BlockHeaders`` using ``blockHash``. Return ``ERR_BLOCK_NOT_FOUND`` if no block header can be found.

3. Retrieve the ``BlockChain`` entry for the given ``RichBlockHeader`` using ``ChainsIndex`` for lookup with the block header's ``chainRef`` as key.

4. Un-flag error codes in the ``BlockChain`` entry.

   a. If ``errors`` contains ``NO_DATA_BTC_RELAY``: remove ``RichBlockHeader.blockHeight`` from ``BlockChain.noData``

   b. If ``errors`` contains ``INVALID_BTC_RELAY``: remove ``RichBlockHeader.blockHeight`` from ``BlockChain.invalid``

5. Emit ``ClearBlockError(blockHash, chainId, errors)`` event, with the given ``blockHash``, the ``chainId`` of the flagged ``BlockChain`` entry and the given ``errors`` as parameters.

6. Return
