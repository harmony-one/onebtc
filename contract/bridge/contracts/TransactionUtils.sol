// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import {ValidateSPV} from "@interlay/bitcoin-spv-sol/contracts/ValidateSPV.sol";
//import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import {BTCUtils} from "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";

library TransactionUtils {
    using BTCUtils for bytes;
    using BytesLib for bytes;

    struct Transaction {
        uint32 version;
        bytes vins;
        bytes vouts;
        uint32 locktime;
    }

    function extractTx(bytes memory raw_tx) internal pure returns(Transaction memory) {
        uint length = raw_tx.length;
        uint pos = 4; // skip version

        bytes memory segwit = raw_tx.slice(pos, 2);
        if (segwit[0] == 0x00 && segwit[1] == 0x01) {
            pos = pos + 2;
        }

        uint vinsPos = pos;

        (uint varIntLen, uint numInputs)  = raw_tx.slice(pos, length-pos).parseVarInt();
        pos += varIntLen + 1;

        for (uint i = 0; i < numInputs; i++) {
            pos += 36; // skip outpoint
            // read varInt for script sig
            (uint scriptSigvarIntLen, uint scriptSigLen) = raw_tx.slice(pos, length-pos).parseVarInt();
           
            pos += (
                scriptSigvarIntLen + 1 // skip varInt
                + scriptSigLen // skip script content
                + 4 // skip sequence
            );
        }
        uint voutsPos = pos;
        return Transaction({
            version : uint32(raw_tx.slice(0, 4).bytesToUint()),
            vins : raw_tx.slice(vinsPos, voutsPos-vinsPos),
            vouts : raw_tx.slice(voutsPos, length-4-voutsPos),
            locktime : uint32(raw_tx.lastBytes(4).bytesToUint())
        });
    }
}