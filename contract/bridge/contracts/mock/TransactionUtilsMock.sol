// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {TransactionUtils} from "../TransactionUtils.sol";

contract TransactionUtilsMock {
    function extractTx(bytes memory rawTx)
        public
        pure
        returns (TransactionUtils.Transaction memory)
    {
        return TransactionUtils.extractTx(rawTx);
    }
}
