// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Quoter Custom Errors
/// @notice Gas-efficient error definitions for Quoter contract
/// @dev AD-26 taxonomy: emit only when the cause is known (RCA). Never map Panic(0x11)→ArithmeticInternal by default.

/// @notice Swap callback received zero amounts for both tokens (no progress)
/// @dev Prefer ZeroLiquidity for AD-26 surface; kept for backwards compatibility of selector consumers
error NoOpSwap();

/// @notice Pool has no usable liquidity on the route (AD-26: zero_liquidity)
/// @dev Emitted before pool.swap when liquidity()==0 at the current tick AND no initialized tick
///      is reachable in the swap direction (core TickBitmap). Not inferred from callback (0,0)
///      as the acceptance path, and never from core NoLiquidity (flash-only).
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
/// @dev Legacy selector. Runtime getPool emits InvalidRoute() when the pool is missing.
///      SDK maps PoolNotFound → invalid_route (alias). Do not delete from ABI.
/// @param tokenA The first token address
/// @param tokenB The second token address
/// @param fee The fee tier
error PoolNotFound(address tokenA, address tokenB, uint24 fee);

/// @notice Route/pool selection is invalid (AD-26: invalid_route)
error InvalidRoute();

/// @notice Insufficient liquidity to complete the quote (AD-26: insufficient_liquidity)
/// @dev Two known causes, same code:
///      1. Economy: exact-out amount the curve cannot cover (received < cached).
///      2. Mechanism 0A: pool callback returns type(int256).min (unsafe uint256 negation).
///      Not a label for Panic(0x11) / port arithmetic.
error InsufficientLiquidity();

/// @notice Protocol determined the failure is internal math/invariant (AD-26: arithmetic_internal)
/// @dev Terminal diagnostic. Emit ONLY after RCA proves internal cause — never as Panic default.
error ArithmeticInternal();
