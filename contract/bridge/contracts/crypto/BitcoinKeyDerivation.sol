// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {Secp256k1} from "./Secp256k1.sol";

// https://interlay.gitlab.io/polkabtc-spec/security_performance/security-analysis.html#unique-addresses-via-on-chain-key-derivation
library BitcoinKeyDerivation{

    function derive(uint256 pubX, uint256 pubY, uint256 id) internal view returns(address) {
        bytes32 c =
            keccak256(
                abi.encodePacked(
                    pubX,
                    pubY,
                    id
                )
            );
        (pubX, pubY) =
            Secp256k1.ecMul(
                uint256(c),
                pubX,
                pubY
            );
        return btcAddress(Secp256k1.compression(pubX, pubY));
    }
    function btcAddress(bytes memory pubKey) internal view returns (address) {
        return address(uint160(ripemd160(abi.encodePacked(sha256(pubKey)))));
    }
}