pragma solidity >=0.4.22 <0.6.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Utils.sol";

/// @title BTCRelay implementation in Solidity
/// @notice Stores Bitcoin block _headers and heaviest (PoW) chain tip, and allows verification of transaction inclusion proofs 
contract BTCRelay {
    
    using SafeMath for uint256;
    using Utils for bytes;
    
    // Data structure representing a Bitcoin block header
    struct HeaderInfo {
        uint256 blockHeight; // height of this block header
        uint256 chainWork; // accumulated PoW at this height
        bytes header; // 80 bytes block header
        uint256 lastDiffAdjustment; // necessary to track, should a fork include a diff. adjustment block
    }

    // Temporary data structure used for fork submissions. 
    // Will be deleted upon success. Reasing in case of failure has no benefit to caller(!)
    struct Fork {
        uint256 startHeight; // start height of a fork
        uint256 length; // number of block in fork
        uint256 chainWork; // accumulated PoW on the fork branch
        bytes32[] forkHeaderHashes; // references to submitted block headers
    }

    mapping(bytes32 => HeaderInfo) public _headers; // mapping of block hashes to block headers (ALL ever submitted, i.e., incl. forks)
    mapping(uint256 => bytes32) public _mainChain; // mapping of block heights to block hashes of the MAIN CHAIN
    bytes32 public _heaviestBlock; // block with the highest chainWork, i.e., blockchain tip
    uint256 public _highScore; // highest chainWork, i.e., accumulated PoW at current blockchain tip    
    uint256 public _lastDiffAdjustmentTime; // timestamp of the block of last difficulty adjustment (blockHeight % 2016 == 0)
    mapping(uint256 => Fork) public _ongoingForks; // mapping of currently onoing fork submissions
    uint256 public _forkCounter = 1; // incremental counter for tracking fork submission. 0 used to indicate a main chain submission
    
    // CONSTANTS
    /*
    * Bitcoin difficulty constants
    */ 
    uint256 public constant DIFFICULTY_ADJUSTMENT_INVETVAL = 2016;
    uint256 public constant TARGET_TIMESPAN = 14 * 24 * 60 * 60; // 2 weeks 
    uint256 public constant UNROUNDED_MAX_TARGET = 2**224 - 1; 
    uint256 public constant TARGET_TIMESPAN_DIV_4 = TARGET_TIMESPAN / 4; // store division as constant to save costs
    uint256 public constant TARGET_TIMESPAN_MUL_4 = TARGET_TIMESPAN * 4; // store multiplucation as constant to save costs

    // EVENTS
    /*
    * @param blockHash block header hash of block header submitted for storage
    * @param blockHeight blockHeight
    */
    event StoreHeader(bytes32 indexed blockHash, uint256 indexed blockHeight);
    /*
    * @param blockHash block header hash of block header submitted for storage
    * @param blockHeight blockHeight
    * @param forkId identifier of fork in the contract
    */
    event StoreFork(bytes32 indexed blockHash, uint256 indexed blockHeight, uint256 indexed forkId);
    /*
    * @param newChainTip new tip of the blockchain after a triggered chain reorg. 
    * @param startHeight start blockHeight of fork
    * @param forkId identifier of the fork triggering the reorg.
    */
    event ChainReorg(bytes32 indexed newChainTip, uint256 indexed startHeight, uint256 indexed forkId);
    /*
    * @param txid block header hash of block header submitted for storage
    */
    event VerityTransaction(bytes32 indexed txid, uint256 indexed blockHeight);


    // EXCEPTION MESSAGES
    string ERR_GENESIS_SET = "Initial parent has already been set";
    string ERR_INVALID_FORK_ID = "Incorrect fork identifier: id 0 is no available";
    string ERR_INVALID_HEADER_SIZE = "Invalid block header size";
    string ERR_DUPLICATE_BLOCK = "Block already stored";
    string ERR_PREV_BLOCK = "Previous block hash not found"; 
    string ERR_LOW_DIFF = "PoW hash does not meet difficulty target of header";
    string ERR_DIFF_TARGET_HEADER = "Incorrect difficulty target specified in block header";
    string ERR_NOT_MAIN_CHAIN = "Main chain submission indicated, but submitted block is on a fork";
    string ERR_FORK_PREV_BLOCK = "Previous block hash does not match last block in fork submission";
    string ERR_NOT_FORK = "Indicated fork submission, but block is in main chain";
    string ERR_INVALID_TXID = "Invalid transaction identifier";
    string ERR_CONFIRMS = "Transaction has less confirmations than requested"; 
    string ERR_MERKLE_PROOF = "Invalid Merkle Proof structure";
    
    /*
    * @notice Initialized BTCRelay with provided block, i.e., defined the first block of the stored chain. 
    * @dev TODO: check issue with "blockHeight mod 2016 = 2015" requirement (old btc relay!). Alexei: IMHO should be called with "blockHeight mod 2016 = 0"
    * @param blockHeaderBytes Raw Bitcoin block headers
    * @param blockHeight block blockHeight
    * @param chainWork total accumulated PoW at given block blockHeight/hash 
    * @param lastDiffAdjustmentTime timestamp of the block of the last diff. adjustment. Note: diff. target of that block MUST be equal to @param target 
    */
    function setInitialParent(
        bytes memory blockHeaderBytes, 
        uint32 blockHeight, 
        uint256 chainWork,
        uint256 lastDiffAdjustmentTime) 
        public {
        require(_heaviestBlock == 0, ERR_GENESIS_SET);
        
       
        bytes32 blockHeaderHash = dblSha(blockHeaderBytes).flipBytes().toBytes32(); 
        _heaviestBlock = blockHeaderHash;
        _highScore = chainWork;
        _lastDiffAdjustmentTime = lastDiffAdjustmentTime;
        
        _headers[blockHeaderHash].header = blockHeaderBytes;
        _headers[blockHeaderHash].blockHeight = blockHeight;
        _headers[blockHeaderHash].chainWork = chainWork;

        emit StoreHeader(blockHeaderHash, blockHeight);
    }

    /*
    * @notice Submit block header to current main chain in relay
    * @dev Will revert if fork is submitted! Use submitNewForkChainHeader for fork submissions.
    */
    function submitMainChainHeader(bytes memory blockHeaderBytes) public returns (bytes32){
        return submitBlockHeader(blockHeaderBytes, 0);
    }
    
    /*
    * @notice Submit block header to start a NEW FORK
    * @dev Increments _forkCounter and uses this as forkId
    */
    function submitNewForkChainHeader(bytes memory blockHeaderBytes) public returns (bytes32 blockHeaderHash){
        blockHeaderHash = submitBlockHeader(blockHeaderBytes, _forkCounter);    
        _forkCounter++;
        return blockHeaderHash;
    }
    
    /*
    * @notice Submit block header to existing fork
    * @dev Will revert if previos block is not in the specified fork!
    */
    function submitForkChainHeader(bytes memory blockHeaderBytes, uint256 forkId) public returns (bytes32){
        require(forkId > 0, ERR_INVALID_FORK_ID);
        return submitBlockHeader(blockHeaderBytes, forkId);   
    }

    /*
    * @notice Parses, validates and stores Bitcoin block header to mapping
    * @dev Can only be called interlally - use submitXXXHeader for public access 
    * @param blockHeaderBytes Raw Bitcoin block header bytes (80 bytes)
    * @param forkId when submitting a fork, pass forkId to reference existing fork submission (Problem: submitting to fork even if not in fork?)
    * 
    */  
    function submitBlockHeader(bytes memory blockHeaderBytes, uint256 forkId) internal returns (bytes32) {
        
        require(blockHeaderBytes.length == 80, ERR_INVALID_HEADER_SIZE);

        bytes32 hashPrevBlock = blockHeaderBytes.slice(4, 32).flipBytes().toBytes32();
        bytes32 hashCurrentBlock = dblSha(blockHeaderBytes).flipBytes().toBytes32();

        // Fail if block already exists
        // Time is always set in block header struct (prevBlockHash and height can be 0 for Genesis block)
        require(_headers[hashCurrentBlock].header.length <= 0, ERR_DUPLICATE_BLOCK);
        // Fail if previous block hash not in current state of main chain
        require(_headers[hashPrevBlock].header.length > 0, ERR_PREV_BLOCK);

        // Fails if previous block header is not stored
        uint256 chainWorkPrevBlock = _headers[hashPrevBlock].chainWork;
        uint256 target = getTargetFromHeader(blockHeaderBytes);
        uint256 blockHeight = 1 + _headers[hashPrevBlock].blockHeight;
        
        // Check the PoW solution matches the target specified in the block header
        require(hashCurrentBlock <= bytes32(target), ERR_LOW_DIFF);
        // Check the specified difficulty target is correct:
        // If retarget: according to Bitcoin's difficulty adjustment mechanism;
        // Else: same as last block. 
        // TODO: return more detailed error messages here (i.e., move require into cocorrectDifficultyTarget function)
        require(correctDifficultyTarget(hashPrevBlock, blockHeight, target), ERR_DIFF_TARGET_HEADER);

        // https://en.bitcoin.it/wiki/Difficulty
        // TODO: check correct conversion here
        uint256 difficulty = getDifficulty(target);
        uint256 chainWork = chainWorkPrevBlock + difficulty;

        // Fork handling
        if(forkId == 0){
            // Main chain submission
            require(chainWork > _highScore, ERR_NOT_MAIN_CHAIN);
            _heaviestBlock = hashCurrentBlock;
            _highScore = chainWork;
            storeBlockHeader(hashCurrentBlock, blockHeaderBytes, blockHeight, chainWork);
            emit StoreHeader(hashCurrentBlock, blockHeight);
            
        } else if(_ongoingForks[forkId].length != 0){
            // Submission to ongoing fork
            // check that prev. block hash of current block is indeed in the fork
            require(getLatestForkHash(forkId) == hashPrevBlock, ERR_FORK_PREV_BLOCK);
            if(chainWork > _highScore){
                // Handle successful fork: remove old block header and update main chain reference
                uint256 currentHeight = _ongoingForks[forkId].startHeight;
                for (uint i = 0; i < _ongoingForks[forkId].forkHeaderHashes.length; i++) {                    
                    // Delete old block header data. 
                    // Note: This refunds gas!
                    // TODO: optimze such that users do not get cut-off by tx.gasUsed / 2
                    delete _headers[_mainChain[currentHeight]];
                    // Update main chain height pointer to new header from fork
                    _mainChain[currentHeight] = _ongoingForks[forkId].forkHeaderHashes[i];
                    currentHeight++;
                }
                emit ChainReorg(_mainChain[currentHeight-1], _ongoingForks[forkId].startHeight, forkId);
                // Delete successful fork submission
                // This refunds gas!
                delete _ongoingForks[forkId];
            
            } else {
                // Fork still being extended: append block
                storeForkHeader(forkId, hashCurrentBlock, _ongoingForks[forkId].chainWork + difficulty);
                emit StoreFork(hashCurrentBlock, blockHeight, forkId);
            }
        } else {
            // Submission of new fork
            // This should never fail
            assert(forkId == _forkCounter); 
            // Check that block is indeed a fork
            require(hashPrevBlock != _heaviestBlock, ERR_NOT_FORK);
            storeForkHeader(
                forkId,
                hashCurrentBlock,
                chainWorkPrevBlock + difficulty
            );
            _ongoingForks[forkId].startHeight = blockHeight;
            emit StoreFork(hashCurrentBlock, blockHeight, forkId);
        }
    }

    /*
    * @notice Stores parsed block header and meta information
    */
    function storeBlockHeader(bytes32 hashCurrentBlock, bytes memory blockHeaderBytes, uint256 blockHeight, uint256 chainWork) internal {
        // potentially externalize this call
        _headers[hashCurrentBlock].header = blockHeaderBytes;
        _headers[hashCurrentBlock].blockHeight = blockHeight;
        _headers[hashCurrentBlock].chainWork = chainWork;
        _mainChain[blockHeight] = hashCurrentBlock;
    }

    /*
    * @notice Stores and handles fork submission.
    */
    function storeForkHeader(uint256 forkId, bytes32 blockHeaderHash, uint256 chainWork) internal {
        _ongoingForks[forkId].chainWork = chainWork;
        _ongoingForks[forkId].length += 1;
        _ongoingForks[forkId].forkHeaderHashes.push(blockHeaderHash);
    }

    /*
    * @notice Verifies that a transaction is included in a block at a given blockheight
    * @param txid transaction identifier
    * @param txBlockHeight block height at which transacton is supposedly included
    * @param txIndex index of transaction in the block's tx merkle tree
    * @param merkleProof  merkle tree path (concatenated LE sha256 hashes)
    * @return True if txid is at the claimed position in the block at the given blockheight, False otherwise
    */
    function verifxTX(bytes32 txid, uint256 txBlockHeight, uint256 txIndex, bytes memory merkleProof, uint256 confirmations) public returns(bool) {
        // txid must not be 0
        require(txid != bytes32(0x0), ERR_INVALID_TXID);
        
        // check requrested confirmations. No need to compute proof if insufficient confs.
        require(_headers[_heaviestBlock].blockHeight - txBlockHeight >= confirmations, ERR_CONFIRMS);

        bytes32 blockHeaderHash = _mainChain[txBlockHeight];
        bytes32 merkleRoot = getMerkleRoot(_headers[blockHeaderHash].header);
        // Check merkle proof structure: 1st hash == txid and last hash == merkleRoot
        require(merkleProof.slice(0, 32).toBytes32() == txid, ERR_MERKLE_PROOF);
        require(merkleProof.slice(merkleRoot.length, 32).toBytes32() == merkleRoot, ERR_MERKLE_PROOF);
        
        // compute merkle tree root and check if it matches block's original merkle tree root
        if(computeMerkle(txid, txIndex, merkleProof) == merkleRoot){
            emit VerityTransaction(txid, txBlockHeight);
            return true;
        }
        return false;


    }

    // HELPER FUNCTIONS
    /*
    * @notice Performs Bitcoin-like double sha256 
    * @param data Bytes to be flipped and double hashed s
    */
    function dblSha(bytes memory data) public pure returns (bytes memory){
        return abi.encodePacked(sha256(abi.encodePacked(sha256(data))));
    }


    /*
    * @notice Calculates the PoW difficulty target from compressed nBits representation, 
    * according to https://bitcoin.org/en/developer-reference#target-nbits
    * @param nBits Compressed PoW target representation
    * @return PoW difficulty target computed from nBits
    */
    function nBitsToTarget(uint256 nBits) private pure returns (uint256){
        uint256 exp = uint256(nBits) >> 24;
        uint256 c = uint256(nBits) & 0xffffff;
        uint256 target = uint256((c * 2**(8*(exp - 3))));
        return target;
    }

    /*
    * @notice Checks if the difficulty target should be adjusted at this block blockHeight
    * @param blockHeight block blockHeight to be checked
    * @return true, if block blockHeight is at difficulty adjustment interval, otherwise false
    */
    function difficultyShouldBeAdjusted(uint256 blockHeight) private pure returns (bool){
        return blockHeight % DIFFICULTY_ADJUSTMENT_INVETVAL == 0;
    }

    /*
    * @notice Verifies the currently submitted block header has the correct difficutly target, based on contract parameters
    * @dev Called from submitBlockHeader. TODO: think about emitting events in this function to identify the reason for failures
    * @param hashPrevBlock Previous block hash (necessary to retrieve previous target)
    */
    function correctDifficultyTarget(bytes32 hashPrevBlock, uint256 blockHeight, uint256 target) private view returns(bool) {
        bytes memory prevBlockHeader = _headers[hashPrevBlock].header;
        uint256 prevTarget = getTargetFromHeader(prevBlockHeader);
        
        if(!difficultyShouldBeAdjusted(blockHeight)){
            // Difficulty not adjusted at this block blockHeight
            if(target != prevTarget && prevTarget != 0){
                return false;
            }
        } else {
            // Difficulty should be adjusted at this block blockHeight => check if adjusted correctly!
            uint256 prevTime = getTimeFromHeader(prevBlockHeader);
            uint256 startTime = _lastDiffAdjustmentTime;
            uint256 newTarget = computeNewTarget(prevTime, startTime, prevTarget);
            return target == newTarget;
        }
        return true;
    }

    /*
    * @notice Computes the new difficulty target based on the given parameters, 
    * according to: https://github.com/bitcoin/bitcoin/blob/78dae8caccd82cfbfd76557f1fb7d7557c7b5edb/src/pow.cpp 
    * @param prevTime timestamp of previous block 
    * @param startTime timestamp of last re-target
    * @param prevTarget PoW difficulty target of previous block
    */
    function computeNewTarget(uint256 prevTime, uint256 startTime, uint256 prevTarget) private pure returns(uint256){
        uint256 actualTimeSpan = prevTime - startTime;
        if(actualTimeSpan < TARGET_TIMESPAN_DIV_4){
            actualTimeSpan = TARGET_TIMESPAN_DIV_4;
        } 
        if(actualTimeSpan > TARGET_TIMESPAN_MUL_4){
            actualTimeSpan = TARGET_TIMESPAN_MUL_4;
        }

        uint256 newTarget = actualTimeSpan.mul(prevTarget).div(TARGET_TIMESPAN);
        if(newTarget > UNROUNDED_MAX_TARGET){
            newTarget = UNROUNDED_MAX_TARGET;
        }
        return newTarget;
    }   

    /*
    * @notice Reconstructs merkle tree root given a transaction hash, index in block and merkle tree path
    * @param txHash hash of to be verified transaction
    * @param txIndex index of transaction given by hash in the corresponding block's merkle tree 
    * @param merkleProof merkle tree path to transaction hash from block's merkle tree root
    * @return merkle tree root of the block containing the transaction, meaningless hash otherwise
    */
    function computeMerkle(bytes32 txHash, uint256 txIndex, bytes memory merkleProof) internal view returns(bytes32) {
    
        //  Special case: only coinbase tx in block. Root == proof
        if(merkleProof.length == 32) return merkleProof.toBytes32();

        // Merkle proof length must be greater than 64 and power of 2. Case length == 32 covered above.
        require(merkleProof.length > 64 && (merkleProof.length & (merkleProof.length - 1)) == 0, ERR_MERKLE_PROOF);
        
        bytes32 resultHash = txHash;

        for(uint i = 1; i < merkleProof.length / 32; i++) {
            if(txIndex % 2 == 1){
                resultHash = concatSHA256Hash(merkleProof.slice(i * 32, 32), abi.encodePacked(resultHash));
            } else {
                resultHash = concatSHA256Hash(abi.encodePacked(resultHash), merkleProof.slice(i * 32, 32));
            }
            txIndex /= 2;
        }
        return resultHash;
    }

    /*
    * @notice Concatenates and re-hashes two SHA256 hashes
    * @param left left side of the concatenation
    * @param right right side of the concatenation
    * @return sha256 hash of the concatenation of left and right
    */
    function concatSHA256Hash(bytes memory left, bytes memory right) public pure returns (bytes32) {
        return dblSha(abi.encodePacked(left, right)).toBytes32();
    }

    /*
    * @notice Checks if given block hash has the requested number of confirmations
    * @dev: Will fail in txBlockHash is not in _headers
    * @param blockHeaderHash Block header hash to be verified
    * @param confirmations Requested number of confirmations
    */
    function withinXConfirms(bytes32 blockHeaderHash, uint256 confirmations) public view returns(bool){
        return _headers[_heaviestBlock].blockHeight - _headers[blockHeaderHash].blockHeight >= confirmations;
    }

    // Parser functions
    function getTimeFromHeader(bytes memory blockHeaderBytes) public pure returns(uint32){
        return uint32(blockHeaderBytes.slice(68,4).flipBytes().bytesToUint()); 
    }

    function getMerkleRoot(bytes memory blockHeaderBytes) public pure returns(bytes32){
        return blockHeaderBytes.slice(36, 32).flipBytes().toBytes32();
    }

    function getPrevBlockHashFromHeader(bytes memory blockHeaderBytes) public pure returns(bytes32){
        return blockHeaderBytes.slice(4, 32).flipBytes().toBytes32();
    }

    function getMerkleRootFromHeader(bytes memory blockHeaderBytes) public pure returns(bytes32){
        return blockHeaderBytes.slice(36,32).toBytes32(); 
    }

    function getNBitsFromHeader(bytes memory blockHeaderBytes) public pure returns(uint256){
        return blockHeaderBytes.slice(72, 4).flipBytes().bytesToUint();
    }

    function getTargetFromHeader(bytes memory blockHeaderBytes) public pure returns(uint256){
        return nBitsToTarget(getNBitsFromHeader(blockHeaderBytes));
    }

    function getDifficulty(uint256 target) public pure returns(uint256){
        return 0x00000000FFFF0000000000000000000000000000000000000000000000000000 / target;
    }


    // Getters

    function getBlockHeader(bytes32 blockHeaderHash) public view returns(
        uint32 version,
        uint32 time,
        uint32 nonce,
        bytes32 prevBlockHash,
        bytes32 merkleRoot,
        uint256 target
    ){
        bytes memory blockHeaderBytes = _headers[blockHeaderHash].header;
        version = uint32(blockHeaderBytes.slice(0,4).flipBytes().bytesToUint());
        time = uint32(blockHeaderBytes.slice(68,4).flipBytes().bytesToUint());
        nonce = uint32(blockHeaderBytes.slice(76, 4).flipBytes().bytesToUint());
        prevBlockHash = blockHeaderBytes.slice(4, 32).flipBytes().toBytes32();
        merkleRoot = blockHeaderBytes.slice(36,32).toBytes32();
        target = nBitsToTarget(blockHeaderBytes.slice(72, 4).flipBytes().bytesToUint());
        return(version, time, nonce, prevBlockHash, merkleRoot, target);
    }

    function getLatestForkHash(uint256 forkId) public view returns(bytes32){
        return _ongoingForks[forkId].forkHeaderHashes[_ongoingForks[forkId].forkHeaderHashes.length - 1]; 
    }
}