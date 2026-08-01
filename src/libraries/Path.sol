// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './BytesLib.sol';

/**
 * @title Path
 * @notice Utility library for manipulating bytes-encoded paths for multihop swaps.
 * @dev Each segment in the path is encoded as: address (20 bytes) + fee (3 bytes).
 */
library Path {
    using BytesLib for bytes;

    /// @dev The size in bytes of an address.
    uint256 private constant ADDR_SIZE = 20;
    /// @dev The size in bytes of a pool fee.
    uint256 private constant FEE_SIZE = 3;

    /// @dev The total size in bytes of a token + fee segment.
    uint256 private constant NEXT_OFFSET = ADDR_SIZE + FEE_SIZE;
    /// @dev The size of the first pool segment: tokenA + fee + tokenB.
    uint256 private constant POP_OFFSET = NEXT_OFFSET + ADDR_SIZE;
    /// @dev Minimum byte length required for two or more pools.
    uint256 private constant MULTIPLE_POOLS_MIN_LENGTH = POP_OFFSET + NEXT_OFFSET;

    /**
     * @notice Checks whether the path contains two or more pools.
     * @param path The encoded swap path.
     * @return True if there are at least two pools, false otherwise.
     */
    function hasMultiplePools(bytes memory path) internal pure returns (bool) {
        return path.length >= MULTIPLE_POOLS_MIN_LENGTH;
    }

    /**
     * @notice Returns the number of pools encoded in the path.
     * @dev Each pool adds NEXT_OFFSET bytes to the path, except the first token which is ADDR_SIZE only.
     * @param path The encoded swap path.
     * @return The number of pools in the path.
     */
    function numPools(bytes memory path) internal pure returns (uint256) {
        // Ignore the first token address. From then on every fee and token offset indicates a pool.
        return ((path.length - ADDR_SIZE) / NEXT_OFFSET);
    }

    /**
     * @notice Decodes the first pool from the path.
     * @dev Extracts the first token, fee, and second token from the byte path.
     * @param path The encoded swap path.
     * @return tokenA The first token of the pool.
     * @return tokenB The second token of the pool.
     * @return fee The fee tier of the pool.
     */
    function decodeFirstPool(bytes memory path)
        internal
        pure
        returns (
            address tokenA,
            address tokenB,
            uint24 fee
        )
    {
        tokenA = path.toAddress(0);
        fee = path.toUint24(ADDR_SIZE);
        tokenB = path.toAddress(NEXT_OFFSET);
    }

    /**
     * @notice Extracts the segment corresponding to the first pool in the path.
     * @dev This includes tokenA + fee + tokenB.
     * @param path The encoded swap path.
     * @return A bytes array containing only the first pool segment.
     */
    function getFirstPool(bytes memory path) internal pure returns (bytes memory) {
        return path.slice(0, POP_OFFSET);
    }

    /**
     * @notice Removes the first token + fee segment from the path.
     * @dev Used to advance the path when iterating over pools in a multihop swap.
     * @param path The encoded swap path.
     * @return A new path with the first token + fee segment skipped.
     */
    function skipToken(bytes memory path) internal pure returns (bytes memory) {
        return path.slice(NEXT_OFFSET, path.length - NEXT_OFFSET);
    }
}
