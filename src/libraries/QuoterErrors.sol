// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Quoter Custom Errors
/// @notice Gas-efficient error definitions for Quoter contract
/// @dev AD-26 taxonomy: emit only when the cause is known (RCA). Never map Panic(0x11)→ArithmeticInternal by default.

/// @notice Swap callback received zero amounts for both tokens (no progress)
/// @dev Prefer ZeroLiquidity for AD-26 surface; kept for backwards compatibility of selector consumers
error NoOpSwap();

/// @notice Pool has zero in-range liquidity / swap produced no amounts (AD-26: zero_liquidity)
error ZeroLiquidity();

/// @notice Exact output swap received different amount than expected
/// @param expected The expected output amount that was cached
/// @param received The actual amount received in the callback
error OutputAmountMismatch(uint256 expected, uint256 received);

/// @notice Revert reason from pool has insufficient data to parse
/// @param length The actual length of the revert data received
error InsufficientRevertData(uint256 length);

/// @notice Quote operation failed due to unclassified pool/core revert (opaque)
/// @dev Inner bytes may be Panic(0x11) or unknown selectors — NOT an AD-26 classification.
///      Consumers must treat this as unclassified (HTTP 500), never as arithmetic_internal by default.
/// @param reason The raw revert reason from the pool
error PoolQuoteFailed(bytes reason);

/// @notice Pool does not exist for the given token pair and fee
/// @param tokenA The first token address
/// @param tokenB The second token address
/// @param fee The fee tier
error PoolNotFound(address tokenA, address tokenB, uint24 fee);

/// @notice Route/pool selection is invalid (AD-26: invalid_route)
error InvalidRoute();

/// @notice Insufficient liquidity in the pool to complete the quote (AD-26: insufficient_liquidity)
/// @dev Thrown when the pool returns type(int256).min which would Panic during uint256 conversion.
///      RCA Task 0A (reproducible mechanism, not identity with residual/prod Panic path §B):
///      Quoter.evxSwapCallback `uint256(-amountDelta)` with amountDelta == type(int256).min
///      → cause = insufficient_liquidity.
error InsufficientLiquidity();

/// @notice Protocol determined the failure is internal math/invariant (AD-26: arithmetic_internal)
/// @dev Terminal diagnostic. Emit ONLY after RCA proves internal cause — never as Panic default.
error ArithmeticInternal();
