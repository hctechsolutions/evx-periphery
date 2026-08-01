// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@evx-core/libraries/Errors.sol";

/**
 * @title NoDelegateCallUpgradeable
 * @notice Base contract to prevent functions from being executed via delegatecall when used behind a proxy.
 * @dev Implementations must call `__NoDelegateCall_init` during their initializer to set the original address.
 */
abstract contract NoDelegateCallUpgradeable {
    /// @notice The address of the contract when not invoked via delegatecall.
    /// @dev This is set once during initialization.
    address private _noDelegateCallOriginal;

    /// @custom:gap Reserved storage space to allow for layout changes in the future.
    uint256[49] private __gap;

    /**
     * @notice Initializes the no-delegate-call guard.
     * @dev Must be called once in the proxied contract's initializer.
     */
    function __NoDelegateCall_init() internal {
        if (_noDelegateCallOriginal != address(0)) revert AlreadyInitialized();
        _noDelegateCallOriginal = address(this);
    }

    /**
     * @notice Modifier to ensure a function is not called through delegatecall.
     * @dev Reverts if the call context differs from the original deployment address.
     */
    modifier noDelegateCall() {
        if (address(this) != _noDelegateCallOriginal) revert NoDelegateCallError();
        _;
    }
}
