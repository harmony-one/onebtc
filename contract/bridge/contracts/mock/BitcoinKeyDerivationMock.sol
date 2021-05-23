// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import {BitcoinKeyDerivation} from "../crypto/BitcoinKeyDerivation.sol";
import {Secp256k1} from "../crypto/Secp256k1.sol";

contract BitcoinKeyDerivationMock {
    function derivate(uint256 pubX, uint256 pubY, uint256 id) external view returns(address) {
        return BitcoinKeyDerivation.derivate(pubX, pubY, id);
    }
    function btcAddress(bytes calldata pubKey, uint256 id) external view returns(address) {
        return BitcoinKeyDerivation.btcAddress(pubKey);
    }
}