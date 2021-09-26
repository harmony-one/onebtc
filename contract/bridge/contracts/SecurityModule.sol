pragma solidity ^0.6.2;


contract SecurityModule {


    enum StatusCode {
        RUNNING,
        ERROR,
        SHITDOWN
    }

    enum ErrorCode {
        NONE,
        ORACLE_OFFLINE,
        BTC_RELAY_OFFLINE
    }

    event RecoverFromErrors(StatusCode code, ErrorCode code);
    
    uint256 BridgeStatus;
    uint256 Nonce;
    uint256 ActiveBlockCount;
    ErrorCode[] errors;

    // returns the hash of the shard's parent block
    function parent_hash() returns (string) {
        return blockhash(block.number - 1);
    }

    function generateSecurityId(address account) returns ( string ) {
        Nonce += 1;
        return keccak256(abi.encodePacked(account, Nonce, parent_hash()));
    }

    function hasExpired (uint256 opentime uint256 period ) returns (bool) { 
        uint256 totalActiveBlockCount = openTime + period;
        return totalActiveBlockCount > ActiveBlockCount;
    } 

    function setBridgeStatus(StatusCode statuscode) {
        BridgeStatus = statusCode;
    }

    function insertBridgeError(ErrorCode error){
        errors.push(error);
    }

    function removeBridgeError(ErrorCode error){
        for(uint256 i = 0; i< errors.length; i++){
            if(errors[i] == error){
                delete errors[i];
                break;
            }
        }
    }
}
