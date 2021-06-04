/*
SPDX-License-Identifier: MIT

Security Module
https://onebtc-dev.web.app/spec/security.html

The Security module is responsible for
(1) tracking the status of the BTC Bridge
(2) the "active" blocks of the BTC Bridge
(3) generating secure identifiers
*/

pragma solidity ^0.6.12;

contract Security {
    StatusCode bridgeStatus;
    ErrorCode[] errors;
    uint256 nonce;
    uint256 activeBlockCount;

    enum StatusCode {
        RUNNING,
        ERROR,
        SHUTDOWN
    }

    enum ErrorCode {
        NONE,
        ORACLE_OFFLINE,
        BTC_RELAY_OFFLINE
    }

    event RecoverFromErrors(
        StatusCode statusCode,
        ErrorCode errorCode
    );

    /**
    * @notice Generates a unique ID using an account identifier, the Nonce and a random seed.
    * @param account Bridge account identifier (links this identifier to the AccountId associated with the process where this secure id is to be used, e.g., the user calling requestIssue).
    * @return a cryptographic hash generated via a secure hash function.
    */
    function generateSecureId(address account) public returns(bytes32) {
        nonce += 1;

        uint blockNumber = block.number;
        bytes32 blockHashPrevious = blockhash(blockNumber - 1);
        bytes32 hash = sha256(abi.encode(account, nonce, blockHashPrevious));

        return hash;
    }

    /**
    * @notice Checks if the given period has expired since the given starting point. This calculation is based on the activeBlockCount.
    * @param opentime the activeBlockCount at the time the issue/redeem/replace was opened.
    * @param period the number of blocks the user or vault has to complete the action.
    * @return true if the period has expired.
    */
    function hasExpired(uint256 opentime, uint256 period) public view returns(bool) {
        uint256 expiredTime = opentime + period;
        return activeBlockCount > expiredTime;
    }

    /**
    * @notice Governance sets a status code for the BTC Bridge manually.
    * @param statusCode the new StatusCode of the BTC-Bridge.
    */
    function setBridgeStatus(StatusCode statusCode) public {
        bridgeStatus = statusCode;
    }

    /**
    * @notice Governance inserts an error for the BTC Bridge manually.
    * @param errorCode the ErrorCode to be added to the set of errors of the BTC-Bridge.
    */
    function insertBridgeError(ErrorCode errorCode) public {
        errors.push(errorCode);
    }

    /**
    * @notice Governance removes an error for the BTC Bridge manually.
    * @param errorCode the ErrorCode to be removed from the set of errors of the BTC-Bridge.
    */
    function removeBridgeError(ErrorCode errorCode) public {
        uint index = errors[errorCode].index;
        if (!index) return;

        delete errors[index];
    }
}
