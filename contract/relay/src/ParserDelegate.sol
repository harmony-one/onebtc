// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {BytesLib} from "@interlay/bitcoin-spv-sol/contracts/BytesLib.sol";

import {Parser} from "./Parser.sol";

contract ParserDelegate {
    using BytesLib for bytes;
    using Parser for bytes;

    function extractInputLength(bytes memory rawTx) public pure returns (uint numInputs, uint lenInputs) {
        return rawTx.extractInputLength();
    }

    function extractOutputLength(bytes memory rawTx) public pure returns (uint numOutputs, uint lenOutputs) {
        return rawTx.extractOutputLength();
    }

    function extractNumOutputs(bytes memory rawTx) public pure returns (uint) {
        (, uint lenInputs) = rawTx.extractInputLength();
        bytes memory outputs = rawTx.slice(lenInputs, rawTx.length - lenInputs);
        (uint numOutputs, ) = outputs.extractOutputLength();
        return numOutputs;
    }

    function extractOutputAtIndex(bytes memory rawTx, uint256 index) public pure returns (bytes memory) {
        (, uint lenInputs) = rawTx.extractInputLength();
        return rawTx.slice(lenInputs, rawTx.length - lenInputs).extractOutputAtIndex(index);
    }

    function extractOutputValueAtIndex(bytes memory rawTx, uint256 index) public pure returns (uint256) {
        bytes memory output = extractOutputAtIndex(rawTx, index);
        return output.extractOutputValue();
    }

    function extractOutputScriptAtIndex(bytes memory rawTx, uint256 index) public pure returns (bytes memory) {
        bytes memory output = extractOutputAtIndex(rawTx, index);
        return output.extractOutputScript();
    }
}