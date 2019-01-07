pragma solidity >=0.4.22 <0.6.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "bytes/BytesLib.sol";

/// @title BTCRelay implementation in Solidity
/// @notice Stores Bitcoin block _headers and heaviest (PoW) chain tip, and allows verification of transaction inclusion proofs 
contract BTCRelay {
    
    using SafeMath for uint256;
    using BytesLib for bytes;

    struct Header {
        // start block header
        uint256 version; // block cersion (4 bytes)
        bytes32 prevBlockHash; // previous block hash (32 bytes)
        bytes32 merkleRoot; // root hash of transaction merkle tree (32 bytes)
        uint256 time; // Unix epoch timestamp (4 bytes) - in BE!
        uint256 nBits; // encoded diff. target (4 bytes)
        uint256 nonce; // PoW solution nonce (4 bytes)
        // End block header
        uint256 chainWork; // accumulated PoW at the height of this block - not part of header
        uint256 height; // position of block - not part of header
    }
    mapping(bytes32 => Header) public _headers;

    bytes32 public _heaviestBlock; // block with the highest chainWork, i.e., blockchain tip
    uint256 public _highScore; // highest chainWork, i.e., accumulated PoW at current blockchain tip
    bytes32 public _lastDifficultyAdjustmentBlock; // block of last difficulty adjustment height (height mod DIFFICULTY_ADJUSTMENT_INVETVAL = 0)

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
    * @param _blockHash block header hash of block header submitted for storage
    * @param _returnCode block height if validation was successful, error code otherwise
    */
    event StoreHeader(bytes32 indexed _blockHash, uint256 indexed _returnCode);

    /**
    * @param _blockHash block header hash of block header submitted for storage
    * @param _returnCode none if transaction verification successful, error code otherwise
    */
    event VerityTransaction(bytes32 indexed _txid, uint256 indexed _returnCode);

    /**
    * @notice Initialized BTCRelay with provided block, i.e., defined the first block of the stored chain. 
    * @dev TODO: check issue with "height mod 2016 = 2015" requirement (old btc relay!). Alexei: IMHO should be called with "height mod 2016 = 0"
    * @param blockHeaderHash block hedaer hash 
    * @param height block height
    * @param nBits nBits of block  header (necessary for difficulty target validation of next block)
    * @param chainWork total accumulated PoW at given block height/hash 
    */
    constructor(bytes32 blockHeaderHash, uint256 height, uint256 time, bytes32 merkleRoot, uint256 nBits, uint256 chainWork) public {
        _heaviestBlock = blockHeaderHash;
        _lastDifficultyAdjustmentBlock = blockHeaderHash;
        _highScore = chainWork;
        
        _headers[blockHeaderHash].height = height;
        _headers[blockHeaderHash].nBits = nBits;
        _headers[blockHeaderHash].chainWork = chainWork;
        _headers[blockHeaderHash].time = time;
        _headers[blockHeaderHash].merkleRoot = merkleRoot;
    }

    
    function storeBlockHeader(bytes blockHeaderBytes) public {
        bytes32 hashPrevBlock = flip32Bytes(blockHeaderBytes.slice(4, 32));
        bytes32 hashCurrentBlock = dblShaFlip(blockHeaderBytes);

                
        // Block hash must be greated 0        
        require(hashCurrentBlock > 0, "Submitted block has invalid hash");
        // Fail if previous block hash not in current state of main chain
        require(_headers[hashPrevBlock], "Previos block hash '" + str(hashPrevBlock) + "' not in found current state of main chain");

        // Fails if previos block header is not stored
        uint256 chainWorkPrevBlock = _headers[hashPrevBlock].chainWork;

        uint256 target = nBitsToTarget(flipBytes(blockHeaderBytes.slice(72, 4)));
        uint256 blockHeight = 1 + _headers[hashPrevBlock].height;

        if(headerCurrentBlock < target){
            

            require(correctDifficultyTarget(hashPrevBlock, blockheight));
            
            // STOPPED HERE
        }

    }

    // HELPER FUNCTIONS
    /**
    * @notice Converts a little endian (LE) byte array of size 32 to big endian (BE), i.e., flips byte order
    * @param bytesLE to be flipped LE byte array 
    * @return BE representation of parsed bytesLE
    */
    function flip32Bytes(bytes32 bytes32LE) private pure returns (bytes32) {
        bytes32 memory bytesBE = 0x0;
        for (uint256 i = 0; i < 32; i++){
            bytesBE >>= 8;
            bytesBE |= bytesLE[i];
        }
        return bytesBE;
    }

    function flipBytes(bytes bytesLE) private pure returns (bytes) {
        bytes memory bytesBE = 0x0;
        for (uint256 i = 0; i < bytesLE.length; i++){
            bytesBE >>= 8;
            bytesBE |= bytesLE[i];
        }
        return bytesBE;
    }

    /**
    * @notice Performns Bitcoin-like double sha256 (LE!)
    * @param data bytes to be flipped and double hashed 
    * @return reversed and double hashed representation of parsed data
    */
    function dblShaFlip(bytes32 data) private pure returns (bytes32){
        flip32Bytes(sha256(sha256(data)));
    }

    /**
    * @notice Calculates the PoW difficulty target from compressed nBits representation, 
    * according to https://bitcoin.org/en/developer-reference#target-nbits
    * @param nBits compressed PoW target representation
    * @return PoW difficulty target computed from nBits (byte array of size 32)
    */
    function nBitsToTarget(uint256 nBits) private pure returns (bytes32){
        uint256 exp = uint256(nBits) >> 24;
        uint256 c = uint256(nBits) & 0xffffff;
        bytes32 target = bytes32(c * 2**(8*(exp - 3)));
        return target;
    }

    /**
    * @notice Checks if the difficulty target should be adjusted at this block height
    * @param blockHeight block height to be checked
    * @return true, if block height is at difficulty adjustment interval, otherwise false
    */
    function difficultyShouldBeAdjusted(uint256 blockHeight) private pure returns (bool){
        return mod(blockHeight, DIFFICULTY_ADJUSTMENT_INVETVAL);
    }

    /**
    * @notice Verifies the currently submitted block header has the correct difficutly target, based on contract parameters
    * @dev Called from storeBlockHeader. TODO: think about emitting events in this function to identify the reason for failures
    * @param hashPrevBlock Previous block hash (necessary to retrieve previous target)
    */
    function correctDifficultyTarget(bytes32 hashPrevBlock, uint256 blockHeight, uint256 nBits) private view returns(bool) {
        prevNBits = _headers[hashPrevBlock].nBits;
        
        if(!difficultyShouldBeAdjusted(blockHeight)){
            // Difficulty not adjusted at this block height
            if(nBits != prevNBits && prevNBits != 0){
                return false;
            }
        } else {
            // Difficulty should be adjusted at this block height => check if adjusted correctly!
            uint256 prevTarget = nBitsToTarget(prevNBits);
            uint256 prevTime = _headers[prevBlockHash].time;

            uint256 startTime = _headers[_lastDifficultyAdjustmentBlock].time;
            
            uint256 newBits = computeNewBits(prevTime, startTime, prevTarget);

        }
    }


    function computeNewBits(uint256 prevTime, uint256 startTime, uint256 prevTarget) private pure returns(uint256){
        uint256 actualTimeSpan = prevTime - startTime;
        if(actualTimeSpan < TARGET_TIMESPAN_DIV_4){
            actualTimeSpan = TARGET_TIMESPAN_DIV_4;
        } 
        if(actualTimeSpan > TARGET_TIMESPAN_MUL_4){
            actualTimeSpan = TARGET_TIMESPAN_MUL_4;
        }

        uint256 newTarget = div(mul(actualTimeSpan, prevTarget), TARGET_TIMESPAN);
        if(newTarget > UNROUNDED_MAX_TARGET){
            newTarget = UNROUNDED_MAX_TARGET;
        }

        // STOPPED HERE
        return(0);
    }

    function targetToNBits(uint256 target) private pure returns(uint256){
        // STOPPED HERE - not sure if needed
    }



}