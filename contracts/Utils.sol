pragma solidity >=0.4.22 <0.6.0;

library Utils{

    function slice(bytes memory _bytes, uint _start, uint _length) internal  pure returns (bytes memory) {
        require(_bytes.length >= (_start + _length), 'Slice out of bounds');

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(_length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(tempBytes, _length)

                //update free-memory pointer
                //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }


    function toBytes32(bytes memory _source) internal pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(_source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(_source, 32))
        }
    }


    /**
    * @notice Converts dynamic bytes array to unit256
    * @param b Dynamic byte array in BE
    * @return Integer representation of b
    */
    function bytesToUint(bytes memory b) internal pure returns (uint256){
        uint256 number;
        for(uint i = 0;i < b.length; i++){
            number = number + uint256(uint8(b[i])) * (2 ** (8 * (b.length - (i + 1))));
        }
        return number;
    }


    /**
    * @notice Converts a little endian (LE) byte array of size 32 to big endian (BE), i.e., flips byte order
    * @param bytesLE To be flipped LE byte array 
    * @return bytes32 BE representation of parsed bytesLE
    */
    function flipBytes(bytes memory bytesLE) internal pure returns (bytes memory) {
        bytes memory bytesBE = new bytes(bytesLE.length);
        for (uint i = 0; i < bytesLE.length; i++){
            bytesBE[bytesLE.length - i - 1] = bytesLE[i];
        }
        return bytesBE;
    }

    /*
    function flip32Bytes(bytes32 bytesLE) private pure returns (bytes32) {
        bytes32 bytesBE = 0x0;
        for (uint256 i = 0; i < 32; i++){
            bytesBE >>= 8;
            bytesBE |= bytesLE[i];
        }
        return bytesBE;
    }
    */
}