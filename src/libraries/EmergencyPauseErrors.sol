// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title EvxEmergencyPause Custom Errors
/// @notice Gas-efficient error definitions for emergency pause ACL + gate
/// @dev Errors are local to periphery — do not import evx-core Errors.sol for name reuse

/// @notice Caller is not the configured pauser
error OnlyPauser();

/// @notice Pauser cannot be the zero address
error ZeroPauser();

/// @notice Critical / gated operation rejected because the system is paused
error EnforcedPause();

/// @notice Unpause rejected because the system is not paused
error ExpectedPause();

/// @notice Critical op code is outside the PoC gate set
error InvalidCriticalOp();
