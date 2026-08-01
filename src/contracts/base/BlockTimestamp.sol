// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BlockTimestamp Utility
 * @notice Provides a method to retrieve the current block timestamp.
 * @dev This abstract contract is intended to be overridden in tests to simulate time-dependent logic.
 */
abstract contract BlockTimestamp {
    /**
     * @notice Returns the current block timestamp.
     * @dev Designed to be overridden in test contracts for mocking time behavior.
     * @return timestamp The current block timestamp.
     */
    function _blockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
