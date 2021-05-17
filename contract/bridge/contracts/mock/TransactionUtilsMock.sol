// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {TransactionUtils} from "../TransactionUtils.sol";

contract TransactionUtilsMock {
    function extractTx(bytes memory raw_tx)
        public
        pure
        returns (TransactionUtils.Transaction memory)
    {
        return TransactionUtils.extractTx(raw_tx);
    }
}
