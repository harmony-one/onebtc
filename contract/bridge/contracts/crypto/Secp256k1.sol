// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./EllipticCurve.sol";

/**
 * @title Secp256k1 Elliptic Curve
 * @notice Example of particularization of Elliptic Curve for secp256k1 curve
 * @author Witnet Foundation
 */
library Secp256k1 {
    uint256 constant GX =
        0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    uint256 constant GY =
        0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;
    uint256 constant AA = 0;
    uint256 constant BB = 7;
    uint256 constant PP =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    uint256 constant NN =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    function ecMul(
        uint256 scale,
        uint256 Px,
        uint256 Py
    ) external pure returns (uint256, uint256) {
        require(scale % NN != 0, "invalid scale");
        return EllipticCurve.ecMul(scale, Px, Py, AA, PP);
    }

    /*
    function priToAddress(uint256 pri) internal view returns(address) {
        (uint256 px, uint256 py) = ecMul(pri, GX, GY);
        return btcAddress(compression(px, py));
    }
    */
    // covert uncompression public key(64bytes) to compression publick key(33bytes)
    function compression(uint256 x, uint256 y)
        internal
        pure
        returns (bytes memory)
    {
        uint8 parity = 2 + uint8(y & 1);
        return abi.encodePacked(parity, x);
    }
}
