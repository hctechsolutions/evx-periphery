// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Evx Custom Errors
/// @notice Gas-efficient, grouped error definitions for Evx contracts
/// @dev Errors are organized to improve readability, reuse and maintenance

/// @notice Re-entrancy detected; operation aborted.
error Locked();

/// @notice Action restricted to the protocol owner or administrator.
error OnlyFactoryOwner();

/// @notice Operation has already been executed once.
error AlreadyInitialized();

/// @notice Tick range must have lower value strictly less than upper value.
error InvalidTickOrder();

/// @notice Lower tick is below the supported minimum.
error TickLowerBelowMinimum();

/// @notice Upper tick is above the supported maximum.
error TickUpperAboveMaximum();

/// @notice Unable to obtain token balance from the token contract.
error BalanceQueryFailed();

/// @notice Lower tick has not been initialized.
error LowerTickNotInitialized();

/// @notice Upper tick has not been initialized.
error UpperTickNotInitialized();

/// @notice Liquidity amount must be greater than zero.
error MintZeroAmount();

/// @notice Insufficient token0 provided to satisfy the required amount.
error InsufficientBalance0();

/// @notice Insufficient token1 provided to satisfy the required amount.
error InsufficientBalance1();

/// @notice Swap amount cannot be zero.
error ZeroSwapAmount();

/// @notice Price limit violated during swap.
error SqrtPriceLimit();

/// @notice Insufficient input amount received during swap settlement.
error InsufficientInputAmount();

/// @notice No available liquidity in the current price range.
error NoLiquidity();

/// @notice Flash-loan fee for token0 was not fully repaid.
error FlashFee0NotReceived();

/// @notice Flash-loan fee for token1 was not fully repaid.
error FlashFee1NotReceived();

/// @notice Implementation address must not be the zero address.
error ZeroImplementation();

/// @notice Token pair addresses must not be identical.
error IdenticalAddresses();

/// @notice Zero address not allowed.
error ZeroAddress();

/// @notice Unsupported or disabled fee tier.
error InvalidFee();

/// @notice A pool for the given token pair and fee already exists.
error PoolExists();

/// @notice Callback invoked by an address that is not a recognized pool.
error InvalidPool();

/// @notice Caller is not authorized to perform this action.
error Forbidden();

/// @notice Fee tier exceeds the maximum allowable value.
error FeeTooHigh();

/// @notice Tick spacing must be within the supported range.
error InvalidTickSpacing();

/// @notice Fee tier has already been enabled.
error AlreadyEnabled();

/// @notice Function cannot be executed via delegatecall.
error NoDelegateCallError();

/// @notice Fee-protocol parameters are outside the valid range.
error InvalidFeeProtocol();