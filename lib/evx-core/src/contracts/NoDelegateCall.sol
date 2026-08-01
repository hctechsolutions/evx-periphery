// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@evx-core/libraries/Errors.sol";

/**
 * @title NoDelegateCall
 * @notice Base contract that prevents functions from being called through delegatecall.
 * @dev Stores the original contract address in an immutable and uses it to detect delegatecall usage.
 */
abstract contract NoDelegateCall {
    
    /// @notice The original address of this contract at the time of deployment.
    /// @dev Used to detect whether the contract is being called via delegatecall.
    address private immutable original;

    /**
     * @notice Initializes the original address to the current contract's address.
     * @dev This is set only once during deployment and stored as an immutable variable.
     */
    constructor() {
        original = address(this);
    }

    /**
     * @notice Internal check to ensure that the function is not being executed through delegatecall.
     * @dev Compares the current address context with the original deployment address.
     *      Reverts if the contract is being delegatecalled.
     */
    function checkNotDelegateCall() private view {
        if (address(this) != original) revert NoDelegateCallError();
    }

    /**
     * @notice Modifier to prevent delegatecall execution.
     * @dev Ensures the function is called directly and not via delegatecall.
     */
    modifier noDelegateCall() {
        checkNotDelegateCall();
        _;
    }
}
