.. _parser:

Functions: Parser
==================


List of functions used to extract data from Bitcoin block headers and transactions.
See the Bitcoin Developer Reference for details on the `block header <https://bitcoin.org/en/developer-reference#block-chain>`_ and `transaction <https://bitcoin.org/en/developer-reference#transactions>`_ format.


.. note:: When comparing byte values, use the hash (e.g. SHA256) to avoid errors.


Block Header
------------

.. _extractHashPrevBlock:

extractHashPrevBlock
~~~~~~~~~~~~~~~~~~~~

Extracts the ``hashPrevBlock`` (reference to previous block) from a Bitcoin block header.

*Function Signature*

``extractHashPrevBlock(blockHeaderBytes)``

*Parameters*

* ``blockHeaderBytes``: 80 byte raw Bitcoin block header.

*Returns*

* ``hashPrevBlock``: the 32 byte block hash reference to the previous block.

.. *Substrate*::

  fn extractHashPrevBlock(blockHeaderBytes: T::RawBlockHeader) -> H256 {...}


Function Sequence
.................

1. Return 32 bytes starting at index 4 of ``blockHeaderBytes``

.. _extractMerkleRoot:

extractMerkleRoot
~~~~~~~~~~~~~~~~~

Extracts the ``merkleRoot`` from a Bitcoin block header.

*Function Signature*

``extractMerkleRoot(blockHeaderBytes)``

*Parameters*

* ``blockHeaderBytes``: 80 byte raw Bitcoin block header

*Returns*

* ``merkleRoot``: the 32 byte Merkle tree root of the block header

.. *Substrate*::

  fn extractMerkleRoot(blockHeaderBytes: T::RawBlockHeader) -> H256 {...}


Function Sequence
.................

1. Return 32 bytes starting at index 36 of ``blockHeaderBytes``.


.. _extractTimestamp:

extractTimestamp
~~~~~~~~~~~~~~~~~

Extracts the timestamp from the block header.

*Function Signature*

``extractTimestamp(blockHeaderBytes)``

*Parameters*

* ``blockHeaderBytes``: 80 byte raw Bitcoin block header

*Returns*

* ``timestamp``: timestamp representation of the 4 byte timestamp field of the block header

.. *Substrate*::

  fn extractTimestamp(blockHeaderBytes: T::RawBlockHeader) -> T::Moment {...}

Function Sequence
.................

1. Return 32 bytes starting at index 68 of ``blockHeaderBytes``.



.. _extractNBits:

extractNBits
~~~~~~~~~~~~

Extracts the ``nBits`` from a Bitcoin block header. This field is necessary to compute that ``target`` in ``nBitsToTarget``.

*Function Signature*

``extractNBits(blockHeaderBytes)``

*Parameters*

* ``blockHeaderBytes``: 80 byte raw Bitcoin block header

*Returns*

* ``nBits``: the 4 byte nBits field of the block header

.. *Substrate*::

  fn extractNBits(blockHeaderBytes: T::RawBlockHeader) -> u32 {...}

Function Sequence
.................

1. Return 4 bytes starting at index 72 of ``blockHeaderBytes``.



.. _parseBlockHeader:

parseBlockHeader
~~~~~~~~~~~~~~~~

Parses a 80 bytes raw Bitcoin block header and, if successful, returns a  ``RichBlockHeader`` struct.



*Function Signature*

``parseBlockHeader(blockHeaderBytes)``

*Parameters*

* ``blockHeaderBytes``: 80 byte raw Bitcoin block header

*Returns*

* ``BlockHeader``: the parsed Bitcoin block header

*Errors*

* ``ERR_INVALID_HEADER_SIZE = "Invalid block header size"``: return error if the submitted block header is not exactly 80 bytes long.

.. *Substrate*::

  fn parseBlockHeader(blockHeaderBytes: T::RawBlockHeader) -> T::RichBlockHeader {...}


Function Sequence
.................

1. Check that the ``blockHeaderBytes`` is 80 bytes long. Return ``ERR_INVALID_HEADER_SIZE`` exception and abort otherwise.

2. Create a new ``BlockHeader`` (``BlockHeader``) struct and initialize as follows:

  * ``BlockHeader.merkleRoot =``:ref:`extractMerkleRoot` (``blockHeaderBytes``)
  * ``BlockHeader.target =`` :ref:`nBitsToTarget` (:ref:`extractNBits` (``blockHeaderBytes``))
  * ``BlockHeader.timestamp =`` :ref:`extractTimestamp` (``blockHeaderBytes``)
  * ``BlockHeader.hashPrevBlock = :ref:`extractHashPrevBlock` (``blockHeaderBytes``)

3. Return ``BlockHeader``





Transactions
-------------

.. todo:: The parser functions used for transaction processing (called by other modules) will be added on demand. See ONEBTC specification for more details.


.. _extractOutputs:

extractOutputs
~~~~~~~~~~~~~~~

Extracts the outputs from the given (raw) transaction (``rawTransaction``).

Specification
.............

*Function Signature*

``extractOutputs(rawTransaction) -> u64``

*Parameters*

* ``rawTransaction``: A variable byte size encoded transaction.

*Returns*

* ``outputs``: A list of variable byte size encoded outputs of the given transaction.


Function Sequence
.................

1. Determine the start of the output list in the transaction using :ref:`getOutputStartIndex`.

2. Determine the number of outputs (determine VarInt size using :ref:`determineVarIntDataLength` and extract bytes indicating the number of outputs accordingly).

3. Loop over the output size, determining the output length for each output (determine VarInt size using :ref:`determineVarIntDataLength` and extract bytes indicating the output size accordingly). Extract the bytes for each output and append them to the ``outputs`` list.

4. Return ``outputs``.


.. note:: Optionally, check the output type here and add flag to return list (use tuple of flag and output bytes then).


.. _getOutputStartIndex:

getOutputStartIndex
~~~~~~~~~~~~~~~~~~~

Extracts the starting index of the outputs in a transaction (i.e., skips over the variable size list of inputs).

*Function Signature*

``getOutputStartIndex(rawTransaction -> u64)``

*Parameters*

* ``rawTransaction``:  A variable byte size encoded transaction.

*Returns*

* ``outputIndex``: integer index indicating the starting point of the list of outputs in the raw transaction.


*Errors*

* ``ERR_INVALID_TX_VERSION = "Invalid transaction version"``: The version of the given transaction is not 1 or 2.

.. note:: Currently, the transaction version can be 1 or 2. See `transaction format details <https://bitcoin.org/en/developer-reference#raw-transaction-format>`_ in the Bitcoin Developer Reference.


Function Sequence
.................

See the `Bitcoin transaction format in the Bitcoin Developer Reference <https://bitcoin.org/en/developer-reference#raw-transaction-format>`_.


1. Init position counter ``pos = 0``.

2. Check the ``version`` bytes of the transaction (must be 1 or 2). Then skip over: ``pos = pos + 4``.

3. Check if the transaction is a SegWit transaction. If yes, ``pos = pos + 2``.

4. Parse the VarInt size (:ref:``determineVarIntDataLength``) and extract the bytes indicating the number of inputs accordingly. Increment ``pos`` accordingly.

5. Iterate over the number of inputs and skip over (incrementing ``pos``). Note: it is necessary to determine the length of the ``scriptSig`` using :ref:`determineVarIntDataLength`.

6. Return ``pos`` indicating the start of the output list in the raw transaction.


.. _determineVarIntDataLength:

determineVarIntDataLength
~~~~~~~~~~~~~~~~~~~~~~~~~

Determines the length of the Bitcoin CompactSize Unsigned Integers (other term for *VarInt*) in bytes. See `CompactSize Unsigned Integers <https://bitcoin.org/en/developer-reference#compactsize-unsigned-integers>`_ for details.

*Function Signature*

``getOutputStartIndex(varIntFlag -> u64)``

*Parameters*

* ``varIntFlag``:  1 byte flag indicating size of Bitcoin's VarInt

*Returns*

* ``varInt``: integer length of the VarInt (excluding flag).


Function Sequence
.................

1. Check flag and return accordingly:

  * If ``0xff`` return ``8``,

  * Else if ``0xfe`` return 4,

  * Else if ``0xfd`` return 2,

  * Otherwise return ``0``


.. _extractOPRETURN:

extractOPRETURN
~~~~~~~~~~~~~~~

Extracts the OP_RETURN of a given transaction. The OP_RETURN field can be used to store `80 bytes in a given Bitcoin transaction <https://bitcoin.stackexchange.com/questions/29554/explanation-of-what-an-op-return-transaction-looks-like>`_. The transaction output that includes the OP_RETURN is provably unspendable.

.. note:: The OP_RETURN field is used to include replay protection data in the ONEBTC *Issue*, *Redeem*, and *Replace* protocols.

*Function Signature*

``extractOPRETURN()``

*Parameters*

* ``rawOutput``: raw encoded output

*Returns*

* ``opreturn``: value of the OP_RETURN data.

*Errors*

* ``ERR_NOT_OP_RETURN = "Expecting OP_RETURN output, but got another type.``: The given output was not an OP_RETURN output.


Function Sequence
.................

1. Check that the output is indeed an OP_RETURN output: ``pk_script[0] == 0x6a``. Return ``ERR_NOT_OP_RETURN`` error if this check fails. Note: the ``pk_script`` starts at index ``9`` of the output (nevertheless, make sure to check the length of VarInt indicating the output size using :ref:`determineVarIntDataLength`).

2. Determine the length of the OP_RETURN field (``pk_script[10]``) and return the OP_RETURN value (excluding the flag and size, i.e., starting at index ``11``).



.. _extractOutputValue:

extractOutputValue
~~~~~~~~~~~~~~~~~~

Extracts the value of the given output.


.. note:: Needs conversion to Big Endian when converting to integer.

*Function Signature*

``extractOutputValue(rawOutput)``

*Parameters*

* ``rawOutput``: raw encoded output

*Returns*

* ``value``: value of the output.


Function Sequence
.................

1. Return the first 8 bytes of ``output``, converted from LE to BE.



.. _extractOutputAddress:

extractOutputAddress
~~~~~~~~~~~~~~~~~~~~

Extracts the value of the given output.

.. note:: Please refer to the `Bitcoin Developer Reference on Transactions <https://bitcoin.org/en/transactions-guide#introduction>`_ when implementing this function.

*Function Signature*

``extractOutputAddress(rawOutput)``

*Parameters*

* ``rawOutput``: raw encoded output

*Returns*

* ``value``: value of the output.

*Errors*

* ``ERR_INVALID_OUTPUT_SCRIPT = "Invalid or malformed output script"``: The script of the given output is invalid or malformed.


Function Sequence
.................

1. Check if output is a SegWit output: ``output[9] == 0``.

   a. If SegWit output (P2WPKH or P2WSH), check that ``output[10]`` equals the length of the output script (extract from``output[8]``). If this check fails, return ``ERR_INVALID_OUTPUT_SCRIPT``.
   b. Return the number of characters specified in ``output[8]`` (length of the output script), starting with ``output[11]``. This will be 20 bytes for `P2WPKH <https://github.com/libbitcoin/libbitcoin-system/wiki/P2WPKH-Transactions>`_ and 32 bytes for `P2WSH <https://github.com/libbitcoin/libbitcoin-system/wiki/P2WSH-Transactions>`_.

2. Otherwise, extract the ``tag`` indicating  the output type: 3 bytes starting at index ``8`` in ``output``.

   a. If P2PKH output (``tag == [0x19, 0x76, 0xa9]``). Check that ``output[11] == [0x14]`` or the last two bytes are equal to ``[0x88, 0xac]. If this check fails, return ``ERR_INVALID_OUTPUT_SCRIPT``. Otherwise, return 20 bytes starting with ``output[12]``.


   b. If P2WSH output (``tag == [0x17, 0xa9, 0x14]``). Check that the last byte is equal to ``[0x87]``. If this check fails, return ``ERR_INVALID_OUTPUT_SCRIPT``. Otherwise, return 32 bytes starting with ``output[12]``.
