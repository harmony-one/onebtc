// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
import {BTCUtils} from "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";
import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {ValidateSPV} from "@interlay/bitcoin-spv-sol/contracts/ValidateSPV.sol";

library TxValidate {
    using BTCUtils for bytes;
    using BytesLib for bytes;

    function extractPaymentValueAndOpReturn(
        bytes memory txVout,
        address recipientBtcAddress
    ) private pure returns (uint256 btcAmount, uint256 opReturn) {
        (, uint256 _nVouts) = txVout.parseVarInt();
        uint256 voutCount = Math.min(_nVouts, 3);
        bytes memory OP_RETURN_DATA;
        address btcAddress;
        for (uint256 i = 0; i < voutCount; i++) {
            bytes memory vout = txVout.extractOutputAtIndex(i);
            if (OP_RETURN_DATA.length == 0) {
                OP_RETURN_DATA = vout.extractOpReturnData();
                if (OP_RETURN_DATA.length > 0) continue;
            }
            if (btcAddress != recipientBtcAddress) {
                bytes memory bytesAddress = vout.extractHash();
                if (
                    bytesAddress.length == 20 &&
                    bytesAddress.toAddress(0) == recipientBtcAddress
                ) {
                    btcAmount = vout.extractValue();
                    btcAddress = recipientBtcAddress;
                }
            }
        }
        require(btcAddress == recipientBtcAddress, "InvalidRecipient");
        require(OP_RETURN_DATA.length > 0, "NoOpRetrun");
        opReturn = OP_RETURN_DATA.bytesToUint();
    }

    function validateTransaction(
        bytes memory txVout,
        uint256 minimumBtc,
        address recipientBtcAddress,
        uint256 opReturnId
    ) internal pure returns (uint256) {
        (uint256 extrPaymentValue, uint256 extrOpReturn) =
            extractPaymentValueAndOpReturn(txVout, recipientBtcAddress);
        require(extrOpReturn == opReturnId, "InvalidOpReturn");
        require(extrPaymentValue >= minimumBtc, "InsufficientValue");
        return extrPaymentValue;
    }
}
