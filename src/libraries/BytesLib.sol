// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Solidity Bytes Arrays Utils
 * @author Gonçalo Sá <goncalo.sa@consensys.net>
 * @notice Utility library for handling tightly packed bytes arrays in Solidity.
 * @dev Supports slicing and converting bytes arrays to address and uint24 types.
 */
library BytesLib {
    /**
     * @notice Returns a slice from the input bytes array.
     * @dev Extracts a subarray starting at `_start` with length `_length`.
     *      Reverts if the requested slice exceeds the bounds of the array.
     * @param _bytes The original bytes array.
     * @param _start The starting index of the slice.
     * @param _length The number of bytes to include in the slice.
     * @return A new bytes array containing the specified slice.
     */
    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    ) internal pure returns (bytes memory) {
        require(_bytes.length >= _start + _length, 'slice_outOfBounds');
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

                    // update free-memory pointer
                    // allocating the array padded to 32 bytes like the compiler does now
                    mstore(0x40, and(add(mc, 31), not(31)))
                }
                // if we want a zero-length slice let's just return a zero-length array
                default {
                    tempBytes := mload(0x40)
                    // zero out the 32 bytes slice we are about to return
                    // we need to do it because Solidity does not garbage collect
                    mstore(tempBytes, 0)
                    mstore(0x40, add(tempBytes, 0x20))
                }
        }
        return tempBytes;
    }

    /**
     * @notice Reads an address from a bytes array.
     * @dev Loads 20 bytes from the specified start index and converts to address.
     *      Reverts if there are fewer than 20 bytes remaining.
     * @param _bytes The bytes array to read from.
     * @param _start The index to start reading from.
     * @return tempAddress The address extracted from the bytes array.
     */
    function toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address tempAddress) {
        require(_bytes.length >= _start + 20, 'toAddress_outOfBounds');
        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }
    }

    /**
     * @notice Reads a uint24 from a bytes array.
     * @dev Loads 3 bytes from the specified start index and converts to uint24.
     *      Reverts if there are fewer than 3 bytes remaining.
     * @param _bytes The bytes array to read from.
     * @param _start The index to start reading from.
     * @return tempUint The uint24 value extracted from the bytes array.
     */
    function toUint24(bytes memory _bytes, uint256 _start) internal pure returns (uint24 tempUint) {
        require(_bytes.length >= _start + 3, 'toUint24_outOfBounds');
        assembly {
            tempUint := mload(add(add(_bytes, 0x3), _start))
        }
    }
}
