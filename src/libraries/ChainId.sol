// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ChainId
 * @notice Utility library to retrieve the current blockchain chain ID.
 * @dev Uses inline assembly to return the chain ID of the executing environment.
 */
library ChainId {
    /**
     * @notice Returns the current chain ID.
     * @dev Reads the chain ID using the EVM `chainid()` opcode.
     * @return chainId The current chain ID as a uint256.
     */
    function get() internal view returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }
}
