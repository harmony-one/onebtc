pragma solidity >=0.4.22 <0.6.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Utils.sol";

/// @title BTCRelay implementation in Solidity
/// @notice Stores Bitcoin block _headers and heaviest (PoW) chain tip, and allows verification of transaction inclusion proofs 
contract BTCRelayAlt {
    
    using SafeMath for uint256;
    using Utils for bytes;
    

    struct HeaderInfo {
        uint256 blockHeight;
        uint256 chainWork;
    }
    mapping(bytes32 => bytes) public _headerBytes;
    mapping(bytes32 => HeaderInfo) public _headerInfos;

    // Potentially more optimal - need to add chainWork and blockHeight though...
    //mapping(bytes32 => bytes) public _headers;

    bytes32 public _heaviestBlock; // block with the highest chainWork, i.e., blockchain tip
    uint256 public _highScore; // highest chainWork, i.e., accumulated PoW at current blockchain tip
    uint256 public _lastDiffAdjustmentTime; // timestamp of the block of last difficulty adjustment (blockHeight mod DIFFICULTY_ADJUSTMENT_INVETVAL = 0)

    // CONSTANTS
    /**
    * Bitcoin difficulty constants
    * TODO: move this to constructor before deployment
    */ 
    uint256 public constant DIFFICULTY_ADJUSTMENT_INVETVAL = 2016;
    uint256 public constant TARGET_TIMESPAN = 14 * 24 * 60 * 60; // 2 weeks 
    uint256 public constant UNROUNDED_MAX_TARGET = 2**224 - 1; 
    uint256 public constant TARGET_TIMESPAN_DIV_4 = TARGET_TIMESPAN / 4; // store division as constant to save costs
    uint256 public constant TARGET_TIMESPAN_MUL_4 = TARGET_TIMESPAN * 4; // store multiplucation as constant to save costs

    // ERROR CODES
    // error codes for storeBlockHeader
    uint256 public constant ERR_DIFFICULTY = 10010;  // difficulty didn't match current difficulty
    uint256 public constant ERR_RETARGET = 10020;  // difficulty didn't match retarget
    uint256 public constant ERR_NO_PREV_BLOCK = 10030;
    uint256 public constant ERR_BLOCK_ALREADY_EXISTS = 10040;
    uint256 public constant ERR_PROOF_OF_WORK = 10090;
    // error codes for verifyTx
    uint256 public constant ERR_BAD_FEE = 20010;
    uint256 public constant ERR_CONFIRMATIONS = 20020;
    uint256 public constant ERR_CHAIN = 20030;
    uint256 public constant ERR_MERKLE_ROOT = 20040;
    uint256 public constant ERR_TX_64BYTE = 20050;

    // EVENTS
    /**
    * @param blockHash block header hash of block header submitted for storage
    * @param blockHeight blockHeight
    */
    event StoreHeader(bytes32 indexed blockHash, uint256 indexed blockHeight);
    /**
    * @param txid block header hash of block header submitted for storage
    */
    event VerityTransaction(bytes32 indexed txid);

    /**
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
        require(_heaviestBlock == 0, "Initial parent has already been set");
        
       
        bytes32 blockHeaderHash = dblShaFlip(blockHeaderBytes).toBytes32(); 
        _heaviestBlock = blockHeaderHash;
        _highScore = chainWork;
        _lastDiffAdjustmentTime = lastDiffAdjustmentTime;
        
        _headerBytes[blockHeaderHash] = blockHeaderBytes;
        _headerInfos[blockHeaderHash].blockHeight = blockHeight;
        _headerInfos[blockHeaderHash].chainWork = chainWork;

        emit StoreHeader(blockHeaderHash, blockHeight);
    }

    /**
    * @notice Parses, validates and stores Bitcoin block header to mapping
    * @param blockHeaderBytes Raw Bitcoin block header bytes (80 bytes)
    * 
    */  
    function storeBlockHeader(bytes memory blockHeaderBytes) public returns (bytes32) {
        
        require(blockHeaderBytes.length == 80, "Invalid block header size");

        bytes32 hashPrevBlock = blockHeaderBytes.slice(4, 32).flipBytes().toBytes32();
        bytes memory hashCurrentBlockBytes = dblShaFlip(blockHeaderBytes);
        bytes32 hashCurrentBlock = hashCurrentBlockBytes.toBytes32();

        // Fail if previous block hash not in current state of main chain
        // Time is always set in block header struct (prevBlockHash and height can be 0 for Genesis block)
        require(_headerBytes[hashPrevBlock].length > 0, "Previous block hash not found in current state of main chain");

        // Fails if previous block header is not stored
        uint256 chainWorkPrevBlock = _headerInfos[hashPrevBlock].chainWork;
        uint256 target = getTargetFromHeader(blockHeaderBytes);
        uint256 blockHeight = 1 + _headerInfos[hashPrevBlock].blockHeight;
        
        // Check the PoW solution matches the target specified in the block header
        require(hashCurrentBlockBytes.bytesToUint() < target, "PoW solution hash does not match difficulty target specified in block header!");
        // Check the specified difficulty target is correct:
        // If retarget: according to Bitcoin's difficulty adjustment mechanism;
        // Else: same as last block. 
        require(correctDifficultyTarget(hashPrevBlock, blockHeight, target), "Incorrect difficulty target specified in block header!");

        // https://en.bitcoin.it/wiki/Difficulty
        // TODO: check correct conversion here
        uint256 difficulty = 0x00000000FFFF0000000000000000000000000000000000000000000000000000 / target;
        uint256 chainWork = chainWorkPrevBlock + difficulty;

        // Check if the current block is the new blockchain tip.
        // If yes => update _highScore and _heaviestBlock
        // If not => a fork is being submitted
        if(chainWork > _highScore){
            _heaviestBlock = hashCurrentBlock;
            _highScore = chainWork;
        }

        _headerBytes[hashCurrentBlock] = blockHeaderBytes;
        _headerInfos[hashCurrentBlock].blockHeight = blockHeight;
        _headerInfos[hashCurrentBlock].chainWork = chainWork;
        
        emit StoreHeader(hashCurrentBlock, blockHeight);
    }

    // HELPER FUNCTIONS
    /**
    * @notice Performns Bitcoin-like double sha256 (LE!)
    * @param data Bytes to be flipped and double hashed 
    * @return Reversed and double hashed representation of parsed data
    */
    function dblShaFlip(bytes memory data) public pure returns (bytes memory){
        return abi.encodePacked(sha256(abi.encodePacked(sha256(data)))).flipBytes();
    }

    /**
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

    /**
    * @notice Checks if the difficulty target should be adjusted at this block blockHeight
    * @param blockHeight block blockHeight to be checked
    * @return true, if block blockHeight is at difficulty adjustment interval, otherwise false
    */
    function difficultyShouldBeAdjusted(uint256 blockHeight) private pure returns (bool){
        return blockHeight % DIFFICULTY_ADJUSTMENT_INVETVAL == 0;
    }

    /**
    * @notice Verifies the currently submitted block header has the correct difficutly target, based on contract parameters
    * @dev Called from storeBlockHeader. TODO: think about emitting events in this function to identify the reason for failures
    * @param hashPrevBlock Previous block hash (necessary to retrieve previous target)
    */
    function correctDifficultyTarget(bytes32 hashPrevBlock, uint256 blockHeight, uint256 target) private view returns(bool) {
        bytes memory prevBlockHeader = _headerBytes[hashPrevBlock];
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

    /**
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

    function getTimeFromHeader(bytes memory blockHeaderBytes) public pure returns(uint32){
        return uint32(blockHeaderBytes.slice(68,4).flipBytes().bytesToUint()); 
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

    function getBlockHeader(bytes32 blockHeaderHash) public view returns(
        uint32 version,
        uint32 time,
        uint32 nonce,
        bytes32 prevBlockHash,
        bytes32 merkleRoot,
        uint256 target
    ){
        bytes memory blockHeaderBytes = _headerBytes[blockHeaderHash];
        version = uint32(blockHeaderBytes.slice(0,4).flipBytes().bytesToUint());
        time = uint32(blockHeaderBytes.slice(68,4).flipBytes().bytesToUint());
        nonce = uint32(blockHeaderBytes.slice(76, 4).flipBytes().bytesToUint());
        prevBlockHash = blockHeaderBytes.slice(4, 32).flipBytes().toBytes32();
        merkleRoot = blockHeaderBytes.slice(36,32).toBytes32();
        target = nBitsToTarget(blockHeaderBytes.slice(72, 4).flipBytes().bytesToUint());
        return(version, time, nonce, prevBlockHash, merkleRoot, target);
    }

    function getDifficulty(uint256 target) public pure returns(uint256){
        return 0x00000000FFFF0000000000000000000000000000000000000000000000000000 / target;
    }
}