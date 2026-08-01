// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PositionKey
 * @notice Utility library to compute a unique key for a position in a liquidity pool.
 * @dev Encodes the position using the owner's address and the tick range.
 */
library PositionKey {
    /**
     * @notice Computes a unique identifier for a position.
     * @dev Uses `keccak256` over the concatenation of owner, tickLower, and tickUpper.
     * @param owner The address that owns the position.
     * @param tickLower The lower bound of the position's tick range.
     * @param tickUpper The upper bound of the position's tick range.
     * @return A bytes32 hash representing the position key.
     */
    function compute(
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, tickLower, tickUpper));
    }
}
