.. _data-model:

Data Model
===========

The BTC-Relay, as opposed to Bitcoin SPV clients, only stores a subset of information contained in block headers and does not store transactions. 
Specifically, only data that is absolutely necessary to perform correct verification of block headers and transaction inclusion is stored. 

Types
~~~~~

RawBlockHeader
..............

An 80 bytes long Bitcoin blockchain header.

Constants
~~~~~~~~~

DIFFICULTY_ADJUSTMENT_INTERVAL
..............................

The interval in number of blocks at which Bitcoin adjusts its difficulty (approx. every 2 weeks = 2016 blocks).


TARGET_TIMESPAN
...............

Expected duration of the different adjustment interval in seconds, ``1209600`` seconds (two weeks) in the case of Bitcoin.


TARGET_TIMESPAN_DIVISOR
.......................

Auxiliary constant used in Bitcoin's difficulty re-target mechanism. 

   
UNROUNDED_MAX_TARGET
....................

The maximum difficulty target, :math:`2^{224}-1` in the case of Bitcoin. For more information, see the `Bitcoin Wiki <https://en.bitcoin.it/wiki/Target>`_.


MAIN_CHAIN_ID
.............

Identifier of the Bitcoin main chain tracked in the ``ChainsIndex`` mapping. At any point in time, the ``BlockChain`` with this identifier is considered to be the main chain and will be used to transaction inclusion verification.



STABLE_BITCOIN_CONFIRMATIONS
............................

Global security parameter (typically referred to as ``k`` in scientific literature), determining the umber of confirmations (in blocks) necessary for a transaction to be considered "stable" in Bitcoin. Stable thereby means that the probability of the transaction being excluded from the blockchain due to a fork is negligible. 


STABLE_PARACHAIN_CONFIRMATIONS
..............................

Global security parameter (typically referred to as ``k`` in scientific literature), determining the umber of confirmations (in blocks) necessary for a transaction to be considered "stable" in the BTC Parachain. Stable thereby means that the probability of the transaction being excluded from the blockchain due to a fork is negligible. 

.. note:: We use this to enforce a minimum delay on Bitcoin block header acceptance in the BTC-Parachain in cases where a (large) number of block headers are submitted as a batch.


Structs
~~~~~~~
  
BlockHeader
...........

Representation of a Bitcoin block header, as stored in the 80 byte byte representation in the Bitcoin block chain (contains **no additional metadata** - see :ref:`RichBlockHeader`). 
This struct is only used for parsing the 80 byte block header - not for storage! 

.. note:: Fields marked as [Optional] are not critical for the secure operation of BTC-Relay, but can be stored anyway, at the developers discretion. We omit these fields in the rest of this specification. 

.. tabularcolumns:: |l|l|L|

======================  =========  ========================================================================
Parameter               Type       Description
======================  =========  ========================================================================
``merkleRoot``          byte32     Root of the Merkle tree referencing transactions included in the block.
``target``              u256       Difficulty target of this block (converted from ``nBits``, see `Bitcoin documentation <https://bitcoin.org/en/developer-reference#target-nbits>`_.).
``timestamp``           timestamp  UNIX timestamp indicating when this block was mined in Bitcoin.
``hashPrevBlock``       byte32     Block hash of the predecessor of this block.
.                       .          .
``version``             i32        [Optional] Version of the submitted block.
``nonce``               u32        [Optional] Nonce used to solve the PoW of this block. 
======================  =========  ========================================================================

.. _RichBlockHeader: 

RichBlockHeader
................

Representation of a Bitcoin block header containing additional metadata. This struct is used to store Bitcoin block headers. 

.. note:: Fields marked as [Optional] are not critical for the secure operation of BTC-Relay, but can be stored anyway, at the developers discretion. We omit these fields in the rest of this specification. 

.. tabularcolumns:: |l|l|L|

======================  ===========  ========================================================================
Parameter               Type         Description
======================  ===========  ========================================================================
``blockhash``           bytes32      Bitcoin's double SHA256 PoW block hash
``blockHeight``         u32          Height of this block in the Bitcoin main chain.
``chainRef``            u32          Pointer to the ``BlockChain`` struct in which this block header is contained.
``blockHeader``         BlockHeader  Associated parsed ``BlockHeader`` struct 
======================  ===========  ========================================================================

BlockChain
..........

Representation of a Bitcoin blockchain / fork.

.. tabularcolumns:: |l|l|L|

======================  ==============  ========================================================================
Parameter               Type            Description
======================  ==============  ========================================================================
``chainId``             U256            Unique identifier for faster lookup in ``ChainsIndex``
``chain``               Map<U256,H256>  Mapping of ``blockHeight`` to ``blockHash``, which points to a ``RichBlockHeader`` entry in ``BlockHeaders``.
``startHeight``         U256            Starting/lowest block height in the ``chain`` mapping. Used to determine the forking point during chain reorganizations.
``maxHeight``           U256            Max. block height in the ``chain`` mapping. Used for ordering in the ``Chains`` priority queue.
``noData``              Vec<U256>       List of block heights in ``chain`` referencing block hashes of ``RichBlockHeader`` entries in ``BlockHeaders`` which have been flagged as ``noData`` by Staked Relayers.
``invalid``             Vec<U256>       List of block heights in ``chain`` referencing block hashes of ``RichBlockHeader`` entries in ``BlockHeaders`` which have been flagged as ``invalid`` by Staked Relayers.
======================  ==============  ========================================================================

Data Structures
~~~~~~~~~~~~~~~

BlockHeaders
............

Mapping of ``<blockHash, RichBlockHeader>``, storing all verified Bitcoin block headers (fork and main chain) submitted to BTC-Relay.


Chains
.........

Priority queue of ``BlockChain`` elements, **ordered by** ``maxHeight`` (**descending**).
The ``BlockChain`` entry with the most significant ``maxHeight`` value (i.e., topmost element) in this mapping is considered to be the Bitcoin *main chain*.

The exact choice of data structure is left to the developer. We recommend to use a heap, which allows re-balancing (changing the priority/order of items while in the heap). Specifically, we require the following operations to be available:

  * ``max`` ... returns the item with the maximum value (as used for sorting).
  * ``insert`` ... inserts a new item, maintaining ordering in relation to other items.
  * ``delete`` ... removes an item.
  * ``find`` ... returns an item with a given index (by sorting key and stored value).
  * ``update`` ... [Optional] modifies the sorting key of an item and updates ordering if necessary (incrementing ``maxHeight`` of a BlockChain entry). Can be implemented using ``delete`` and ``insert``.

.. attention:: If two ``BlockChain`` entries have the same ``maxHeight``, do **not** change ordering! 

.. note:: The assumption for ``Chains`` is that, in the majority of cases, block headers will be appended to the *main chain* (longest chain), i.e., the ``BlockChain`` entry at the most significant position in the queue/heap. Similarly, transaction inclusion proofs (:ref:`verifyTransactionInclusion`) are only checked against the *main chain*. This means, in the average case lookup complexity will be O(1). Furthermore, block headers can only be appended if they (i) have a valid PoW and (ii) do not yet exist in ``BlockHeaders`` - hence, spamming is very costly and unlikely. Finally, blockchain forks and re-organizations occur infrequently, especially in Bitcoin. In principle, optimizing lookup costs should be prioritized, ideally O(1), while inserting of new items and re-balancing can even be O(n). 


ChainsIndex
...........

Auxiliary mapping of ``BlockChain`` structs to unique identifiers, for faster read access / lookup ``<U256, BlockChain>``, 


BestBlock
.........

32 byte Bitcoin block hash (double SHA256) identifying the current blockchain tip, i.e., the ``RichBlockHeader`` with the highest ``blockHeight`` in the ``BlockChain`` entry, which has the most significant ``height`` in the ``Chains`` priority queue (topmost position). 


.. note:: Bitcoin uses SHA256 (32 bytes) for its block hashes, transaction identifiers and Merkle trees. In Substrate, we hence use ``H256`` to represent these hashes.

BestBlockHeight
...............

Integer representing the maximum block height (``height``) in the ``Chains`` priority queue. This is also the ``blockHeight`` of the ``RichBlockHeader`` entry pointed to by ``BestBlock``.


ChainCounter
.................

Integer increment-only counter used to track existing BlockChain entries.
Initialized with 1 (0 is reserved for ``MAIN_CHAIN_ID``).
