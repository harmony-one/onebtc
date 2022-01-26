// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {TxValidate} from "../TxValidate.sol";

contract TxValidateMock {
    function validateTransaction(
        bytes memory txVout,
        uint256 minimumBtc,
        address recipientBtcAddress,
        uint256 opReturnId,
        uint256 outputIndex
    ) public pure returns (uint256) {
        return
            TxValidate.validateTransaction(
                txVout,
                minimumBtc,
                recipientBtcAddress,
                opReturnId,
                outputIndex
            );
    }
}
