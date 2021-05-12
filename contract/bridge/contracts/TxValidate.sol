// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
import {BTCUtils} from "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";
import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {ValidateSPV} from "@interlay/bitcoin-spv-sol/contracts/ValidateSPV.sol";

library TxValidate {
    using BTCUtils for bytes;
    using BytesLib for bytes;
    function extract_payment_value_and_op_return(bytes memory tx_vout, address recipient_btc_address) private pure returns(uint256 btc_amount, uint256 op_return) {
        (,uint256 _nVouts) = tx_vout.parseVarInt();
        uint256 vout_count = Math.min(_nVouts, 3);
        bytes memory OP_RETURN_DATA;
        address btc_address;
        for (uint i = 0; i < vout_count; i++) {
            bytes memory vout = tx_vout.extractOutputAtIndex(i);
            if(OP_RETURN_DATA.length == 0) {
                OP_RETURN_DATA = vout.extractOpReturnData();
                if(OP_RETURN_DATA.length > 0) continue;
            }
            if(btc_address != recipient_btc_address) {
                bytes memory bytesAddress = vout.extractHash();
                if(bytesAddress.length == 20 && bytesAddress.toAddress(0) == recipient_btc_address) {
                    btc_amount = vout.extractValue();
                    btc_address = recipient_btc_address;
                }
            }
        }
        require(btc_address == recipient_btc_address, "InvalidRecipient");
        require(OP_RETURN_DATA.length > 0, "NoOpRetrun");
        op_return = OP_RETURN_DATA.bytesToUint();
    }
    function validate_transaction(bytes memory tx_vout, uint256 minimum_btc, address recipient_btc_address, uint256 op_return_id) internal pure returns(uint256) {
        (uint256 extr_payment_value, uint256 extr_op_return) = extract_payment_value_and_op_return(tx_vout, recipient_btc_address);
        require(extr_op_return == op_return_id, "InvalidOpReturn");
        require(extr_payment_value >= minimum_btc, "InsufficientValue");
        return extr_payment_value;
    }
}