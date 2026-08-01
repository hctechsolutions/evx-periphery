// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Quoter Custom Errors
/// @notice Gas-efficient error definitions for Quoter contract
/// @dev Errors are organized to improve readability and debugging

/// @notice Swap callback received zero amounts for both tokens
error NoOpSwap();

/// @notice Exact output swap received different amount than expected
/// @param expected The expected output amount that was cached
/// @param received The actual amount received in the callback
error OutputAmountMismatch(uint256 expected, uint256 received);

/// @notice Revert reason from pool has insufficient data to parse
/// @param length The actual length of the revert data received
error InsufficientRevertData(uint256 length);

/// @notice Quote operation failed due to pool error
/// @param reason The raw revert reason from the pool
error PoolQuoteFailed(bytes reason);

/// @notice Pool does not exist for the given token pair and fee
/// @param tokenA The first token address
/// @param tokenB The second token address
/// @param fee The fee tier
error PoolNotFound(address tokenA, address tokenB, uint24 fee);

/// @notice Insufficient liquidity in the pool to complete the quote
/// @dev This error is thrown when the pool returns type(int256).min which would cause
///      a panic during uint256 conversion. This typically indicates zero or insufficient liquidity.
error InsufficientLiquidity();
