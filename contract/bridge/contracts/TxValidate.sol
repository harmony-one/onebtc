// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import {BTCUtils} from "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";
import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import {ValidateSPV} from "@interlay/bitcoin-spv-sol/contracts/ValidateSPV.sol";

library TxValidate {
    using BTCUtils for bytes;
    using BytesLib for bytes;

    function validateTransaction(
        bytes memory txVout,
        uint256 minimumBtc,
        address recipientBtcAddress,
        uint256 opReturnId,
        uint256 outputIndex
    ) internal pure returns (uint256) {
        uint256 btcAmount;
        address btcAddress;

        if (opReturnId != 0x0) {
            (, uint256 _nVouts) = txVout.parseVarInt();
            uint256 voutCount = _nVouts;
            bytes memory OP_RETURN_DATA;
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

            require(
                OP_RETURN_DATA.bytesToUint() == opReturnId,
                "Invalid OpReturn"
            );
        } else {
            bytes memory vout = txVout.extractOutputAtIndex(outputIndex);
            bytes memory bytesAddress = vout.extractHash();
            btcAmount = vout.extractValue();
            btcAddress = bytesAddress.toAddress(0);
        }

        require(btcAmount >= minimumBtc, "Insufficient BTC value");
        require(btcAddress == recipientBtcAddress, "Invalid recipient");

        return btcAmount;
    }
}
