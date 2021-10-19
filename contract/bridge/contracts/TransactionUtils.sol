// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {ValidateSPV} from "@interlay/bitcoin-spv-sol/contracts/ValidateSPV.sol";
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

    function extractTx(bytes memory rawTx)
        internal
        pure
        returns (Transaction memory)
    {
        uint256 length = rawTx.length;
        uint256 pos = 4; // skip version

        bytes memory segwit = rawTx.slice(pos, 2);
        if (segwit[0] == 0x00 && segwit[1] == 0x01) {
            pos = pos + 2;
        }

        uint256 vinsPos = pos;

        (uint256 varIntLen, uint256 numInputs) = rawTx
            .slice(pos, length - pos)
            .parseVarInt();
        pos += varIntLen + 1;

        for (uint256 i = 0; i < numInputs; i++) {
            pos += 36; // skip outpoint
            // read varInt for script sig
            (uint256 scriptSigvarIntLen, uint256 scriptSigLen) = rawTx
                .slice(pos, length - pos)
                .parseVarInt();

            pos += (scriptSigvarIntLen +
                1 + // skip varInt
                scriptSigLen + // skip script content
                4); // skip sequence
        }
        uint256 voutsPos = pos;
        return
            Transaction({
                version: uint32(rawTx.slice(0, 4).bytesToUint()),
                vins: rawTx.slice(vinsPos, voutsPos - vinsPos),
                vouts: rawTx.slice(voutsPos, length - 4 - voutsPos),
                locktime: uint32(rawTx.lastBytes(4).bytesToUint())
            });
    }
}
