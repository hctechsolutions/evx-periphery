// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './BlockTimestamp.sol';

/**
 * @title PeripheryValidation
 * @notice Provides common validation modifiers for periphery contracts.
 * @dev Uses `_blockTimestamp()` to enable testability and mockable timestamps.
 */
abstract contract PeripheryValidation is BlockTimestamp {
    /**
     * @notice Reverts if the current block timestamp is greater than the given deadline.
     * @dev Helps prevent front-running and stale transactions.
     * @param deadline The timestamp by which the transaction must be executed.
     */
    modifier checkDeadline(uint256 deadline) {
        require(_blockTimestamp() <= deadline, 'Transaction too old');
        _;
    }
}
