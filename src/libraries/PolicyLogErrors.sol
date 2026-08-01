// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title EvxPolicyLog Custom Errors
/// @notice Gas-efficient error definitions for the policy observability log
/// @dev Errors are local to periphery — do not import evx-core Errors.sol for name reuse

/// @notice Caller is not the configured policy keeper
error OnlyPolicyKeeper();

/// @notice Policy keeper cannot be the zero address
error ZeroPolicyKeeper();
