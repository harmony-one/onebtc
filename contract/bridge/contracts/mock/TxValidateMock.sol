// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import {TxValidate} from "../TxValidate.sol";

contract TxValidateMock {
    function validate_transaction(
        bytes memory tx_vout,
        uint256 minimum_btc,
        address recipient_btc_address,
        uint256 op_return_id
    ) public pure returns (uint256) {
        return
            TxValidate.validate_transaction(
                tx_vout,
                minimum_btc,
                recipient_btc_address,
                op_return_id
            );
    }
}
