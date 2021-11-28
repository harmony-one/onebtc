// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";
import {BTCUtils} from "@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol";

library Parser {
    using SafeMathUpgradeable for uint256;
    using BytesLib for bytes;
    using BTCUtils for bytes;

    // EXCEPTION MESSAGES
    string constant ERR_INVALID_OUTPUT = "Invalid output";

    /**
    * @notice Extracts number of inputs and ending index
    * @param rawTx Raw transaction
    * @return Number of inputs
    * @return Scanner end position
    */
    function extractInputLength(bytes memory rawTx) internal pure returns (uint, uint) {
        uint length = rawTx.length;

        // skip version
        uint pos = 4;

        bytes memory segwit = rawTx.slice(pos, 2);
        if (segwit[0] == 0x00 && segwit[1] == 0x01) {
            pos = pos + 2;
        }

        uint varIntLen = rawTx.slice(pos, length - pos).determineVarIntDataLength();
        if (varIntLen == 0) {
            varIntLen = 1;
        }

        uint numInputs = rawTx.slice(pos, varIntLen).bytesToUint();
        pos = pos + varIntLen;

        for (uint i = 0; i < numInputs; i++) {
            pos = pos + 32;
            pos = pos + 4;
            // read varInt for script sig
            uint scriptSigvarIntLen = rawTx.slice(pos, length - pos).determineVarIntDataLength();
            if (scriptSigvarIntLen == 0) {
                scriptSigvarIntLen = 1;
            }
            uint scriptSigLen = rawTx.slice(pos, scriptSigvarIntLen).bytesToUint();
            pos = pos + scriptSigvarIntLen;
            // get script sig
            pos = pos + scriptSigLen;
            // get sequence 4 bytes
            pos = pos + 4;
            // new pos is now start of next index
        }

        return (numInputs, pos);
    }

    /**
    * @notice Extracts number of outputs and ending index
    * @param rawTx Raw transaction
    * @return Number of outputs
    * @return Scanner end position
    */
    function extractOutputLength(bytes memory rawTx) internal pure returns (uint, uint) {
        uint length = rawTx.length;
        uint pos = 0;

        uint varIntLen = rawTx.slice(pos, length - pos).determineVarIntDataLength();
        if (varIntLen == 0) {
            varIntLen = 1;
        }

        uint numOutputs = rawTx.slice(pos, varIntLen).bytesToUint();
        pos = pos + varIntLen;

        for (uint i = 0;  i < numOutputs; i++) {
            pos = pos + 8;
            uint pkScriptVarIntLen = rawTx.slice(pos, length - pos).determineVarIntDataLength();
            if (pkScriptVarIntLen == 0) {
                pkScriptVarIntLen = 1;
            }
            uint pkScriptLen = rawTx.slice(pos, pkScriptVarIntLen).bytesToUint();
            pos = pos + pkScriptVarIntLen;
            pos = pos + pkScriptLen;
        }

        return (numOutputs, pos);
    }

    /**
    * @notice Extracts output from transaction outputs
    * @param outputs Raw transaction outputs
    * @param index Index of output
    * @return Output bytes
    */
    function extractOutputAtIndex(bytes memory outputs, uint256 index) internal pure returns (bytes memory) {
        uint length = outputs.length;
        uint pos = 0;

        uint varIntLen = outputs.slice(pos, length - pos).determineVarIntDataLength();
        if (varIntLen == 0) {
            varIntLen = 1;
        }

        uint numOutputs = outputs.slice(pos, varIntLen).bytesToUint();
        require(numOutputs >= index, ERR_INVALID_OUTPUT);
        pos = pos + varIntLen;

        uint start = pos;
        for (uint i = 0;  i < numOutputs; i++) {
            pos = pos + 8;
            uint pkScriptVarIntLen = outputs.slice(pos, length - pos).determineVarIntDataLength();
            if (pkScriptVarIntLen == 0) {
                pkScriptVarIntLen = 1;
            }
            uint pkScriptLen = outputs.slice(pos, pkScriptVarIntLen).bytesToUint();
            pos = pos + pkScriptVarIntLen;
            pos = pos + pkScriptLen;
            if (i == index) {
                return outputs.slice(start, pos);
            }
            start = pos;
        }

        return "";
    }

    /**
    * @notice Extracts the amount from a tx output
    * @param out Raw transaction output
    * @return Value
    */
    function extractOutputValue(bytes memory out) internal pure returns (uint64) {
        return out.extractValue();
    }

    /**
    * @notice Extracts the script from a tx output
    * @param out Raw transaction output
    * @return Script bytes
    */
    function extractOutputScript(bytes memory out) internal pure returns (bytes memory) {
        uint length = out.length;

        // skip value
        uint pos = 8;
        uint pkScriptVarIntLen = out.slice(pos, length - pos).determineVarIntDataLength();
        if (pkScriptVarIntLen == 0) {
            pkScriptVarIntLen = 1;
        }

        uint pkScriptLen = out.slice(pos, pkScriptVarIntLen).bytesToUint();
        pos = pos + pkScriptVarIntLen;
        return out.slice(pos, pkScriptLen);
    }
}