// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/libraries/SafeCast.sol';
import '@evx-core/libraries/TickMath.sol';
import '@evx-core/libraries/TickBitmap.sol';
import '@evx-core/interfaces/IEvxPool.sol';
import '@evx-core/interfaces/IEvxFactory.sol';
import '@evx-core/interfaces/callback/IEvxSwapCallback.sol';
import '@evx-core/libraries/FullMath.sol';
import '@evx-core/libraries/FixedPoint96.sol';

import '@evx-periphery/interfaces/IQuoter.sol';
import '@evx-periphery/contracts/base/PeripheryImmutableState.sol';
import '@evx-periphery/libraries/Path.sol';
import '@evx-periphery/libraries/PoolAddress.sol';
import '@evx-periphery/libraries/CallbackValidation.sol';
import '@evx-periphery/libraries/PoolTicksCounter.sol';
import '@evx-periphery/libraries/LiquidityAmounts.sol';
import '@evx-periphery/libraries/QuoterErrors.sol';

/**
 * @title Quoter
 * @notice Provides quotes for swaps without executing them. Intended for off-chain estimation only
 * @dev Not gas-efficient and should not be called on-chain. Intended for off-chain estimation only.
 */
contract Quoter is IQuoter, IEvxSwapCallback, PeripheryImmutableState {
    using Path for bytes;
    using SafeCast for uint256;
    using PoolTicksCounter for IEvxPool;

    /// @dev Transient storage variable used to check a safety condition in exact output swaps.
    uint256 private amountOutCached;

    /**
     * @notice Initializes the quoter with the factory and WETH9 addresses.
     * @param _factory The address of the EvxFactory contract.
     * @param _WETH9 The address of the WETH9 token.
     */
    constructor(address _factory, address _WETH9) PeripheryImmutableState(_factory, _WETH9) {}

    /**
     * @notice Internal helper to fetch a pool instance.
     * @param tokenA One of the tokens.
     * @param tokenB The other token.
     * @param fee The pool fee tier.
     * @return The EvxPool instance.
     */
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) private view returns (IEvxPool) {
        address poolAddress = IEvxFactory(factory).getPool(tokenA, tokenB, fee);
        if (poolAddress == address(0)) {
            revert PoolNotFound(tokenA, tokenB, fee);
        }
        return IEvxPool(poolAddress);
    }

    /// @inheritdoc IEvxSwapCallback
    function evxSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory path
    ) external view override {
        if (amount0Delta == 0 && amount1Delta == 0) revert NoOpSwap();

        // Validate that amounts are not type(int256).min to prevent panic during uint256 conversion
        // This typically indicates insufficient or zero liquidity in the pool
        if (amount0Delta == type(int256).min || amount1Delta == type(int256).min) {
            revert InsufficientLiquidity();
        }

        (address tokenIn, address tokenOut, uint24 fee) = path.decodeFirstPool();
        CallbackValidation.verifyCallback(factory, tokenIn, tokenOut, fee);

        (bool isExactInput, uint256 amountToPay, uint256 amountReceived) =
            amount0Delta > 0
                ? (tokenIn < tokenOut, uint256(amount0Delta), uint256(-amount1Delta))
                : (tokenOut < tokenIn, uint256(amount1Delta), uint256(-amount0Delta));

        IEvxPool pool = getPool(tokenIn, tokenOut, fee);
        (uint160 sqrtPriceX96After, int24 tickAfter, , , , , ) = pool.slot0();

        if (isExactInput) {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountReceived)
                mstore(add(ptr, 0x20), sqrtPriceX96After)
                mstore(add(ptr, 0x40), tickAfter)
                revert(ptr, 96)
            }
        } else {
            // If the cache has been populated, ensure that the full output amount has been received
            if (amountOutCached != 0 && amountReceived != amountOutCached) {
                revert OutputAmountMismatch(amountOutCached, amountReceived);
            }
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountToPay)
                mstore(add(ptr, 0x20), sqrtPriceX96After)
                mstore(add(ptr, 0x40), tickAfter)
                revert(ptr, 96)
            }
        }
    }

    /**
     * @dev Parses the revert reason returned by a simulated swap.
     * @param reason The raw revert data.
     * @return amount The quoted amount.
     * @return sqrtPriceX96After The price after the simulated swap.
     * @return tickAfter The tick after the simulated swap.
     */
    function parseRevertReason(bytes memory reason)
        private
        pure
        returns (
            uint256 amount,
            uint160 sqrtPriceX96After,
            int24 tickAfter
        )
    {
        if (reason.length != 96) {
            // If we have at least 4 bytes (error selector), preserve the original error
            // This allows us to extract errors even when they have no arguments (like NoLiquidity)
            if (reason.length >= 4) {
                // Wrap the pool error in our custom error to preserve context
                // This works for errors with or without arguments
                revert PoolQuoteFailed(reason);
            }
            // Only use InsufficientRevertData if we truly don't have enough data (less than selector)
            revert InsufficientRevertData(reason.length);
        }
        return abi.decode(reason, (uint256, uint160, int24));
    }

    /**
     * @dev Processes the revert and extracts quote data.
     * @param reason The revert data.
     * @param pool The pool used for the quote.
     * @param gasEstimate The estimated gas used.
     * @return amount The quoted amount.
     * @return sqrtPriceX96After Price after the swap.
     * @return initializedTicksCrossed Number of initialized ticks crossed.
     * @return gasEstimate Gas consumed.
     */
    function handleRevert(
        bytes memory reason,
        IEvxPool pool,
        uint256 gasEstimate
    )
        private
        view
        returns (
            uint256 amount,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256
        )
    {
        int24 tickBefore;
        int24 tickAfter;
        (, tickBefore, , , , , ) = pool.slot0();
        (amount, sqrtPriceX96After, tickAfter) = parseRevertReason(reason);

        initializedTicksCrossed = pool.countInitializedTicksCrossed(tickBefore, tickAfter);

        return (amount, sqrtPriceX96After, initializedTicksCrossed, gasEstimate);
    }

    /// @inheritdoc IQuoter
    function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
        public
        override
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        )
    {
        IEvxPool pool = getPool(params.tokenIn, params.tokenOut, params.fee);
        
        // Get token0 from the pool (tokens are always sorted: token0 < token1)
        address token0 = pool.token0();
        
        // Calculate zeroForOne based on pool token order, not path order
        // zeroForOne = true means swapping token0 -> token1
        // zeroForOne = false means swapping token1 -> token0
        bool zeroForOne = params.tokenIn == token0;

        uint256 gasBefore = gasleft();
        try
            pool.swap(
                address(this), // address(0) might cause issues with some tokens
                zeroForOne,
                params.amountIn.toInt256(),
                params.sqrtPriceLimitX96 == 0
                    ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                    : params.sqrtPriceLimitX96,
                abi.encodePacked(params.tokenIn, params.fee, params.tokenOut)
            )
        {} catch (bytes memory reason) {
            gasEstimate = gasBefore - gasleft();
            return handleRevert(reason, pool, gasEstimate);
        }
    }

    /// @inheritdoc IQuoter
    function quoteExactInput(bytes memory path, uint256 amountIn)
        public
        override
        returns (
            uint256 amountOut,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        )
    {
        sqrtPriceX96AfterList = new uint160[](path.numPools());
        initializedTicksCrossedList = new uint32[](path.numPools());

        uint256 i = 0;
        while (true) {
            (address tokenIn, address tokenOut, uint24 fee) = path.decodeFirstPool();

            // The outputs of prior swaps become the inputs to subsequent ones
            (uint256 _amountOut, uint160 _sqrtPriceX96After, uint32 _initializedTicksCrossed, uint256 _gasEstimate) =
                quoteExactInputSingle(
                    QuoteExactInputSingleParams({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        fee: fee,
                        amountIn: amountIn,
                        sqrtPriceLimitX96: 0
                    })
                );

            sqrtPriceX96AfterList[i] = _sqrtPriceX96After;
            initializedTicksCrossedList[i] = _initializedTicksCrossed;
            amountIn = _amountOut;
            gasEstimate += _gasEstimate;
            i++;

            // Decide whether to continue or terminate
            if (path.hasMultiplePools()) {
                path = path.skipToken();
            } else {
                return (amountIn, sqrtPriceX96AfterList, initializedTicksCrossedList, gasEstimate);
            }
        }
    }

    /// @inheritdoc IQuoter
    function quoteExactOutputSingle(QuoteExactOutputSingleParams memory params)
        public
        override
        returns (
            uint256 amountIn,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        )
    {
        IEvxPool pool = getPool(params.tokenIn, params.tokenOut, params.fee);
        
        // Get token0 from the pool (tokens are always sorted: token0 < token1)
        address token0 = pool.token0();
        
        // Calculate zeroForOne based on pool token order, not path order
        // zeroForOne = true means swapping token0 -> token1
        // zeroForOne = false means swapping token1 -> token0
        bool zeroForOne = params.tokenIn == token0;

        // If no price limit has been specified, cache the output amount for comparison in the swap callback
        if (params.sqrtPriceLimitX96 == 0) amountOutCached = params.amount;
        uint256 gasBefore = gasleft();
        try
            pool.swap(
                address(this),
                zeroForOne,
                -params.amount.toInt256(),
                params.sqrtPriceLimitX96 == 0
                    ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                    : params.sqrtPriceLimitX96,
                abi.encodePacked(params.tokenOut, params.fee, params.tokenIn)
            )
        {} catch (bytes memory reason) {
            gasEstimate = gasBefore - gasleft();
            if (params.sqrtPriceLimitX96 == 0) delete amountOutCached;
            return handleRevert(reason, pool, gasEstimate);
        }
    }

    /// @inheritdoc IQuoter
    function quoteExactOutput(bytes memory path, uint256 amountOut)
        public
        override
        returns (
            uint256 amountIn,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        )
    {
        sqrtPriceX96AfterList = new uint160[](path.numPools());
        initializedTicksCrossedList = new uint32[](path.numPools());

        uint256 i = 0;
        while (true) {
            (address tokenOut, address tokenIn, uint24 fee) = path.decodeFirstPool();

            // The inputs of prior swaps become the outputs of subsequent ones
            (uint256 _amountIn, uint160 _sqrtPriceX96After, uint32 _initializedTicksCrossed, uint256 _gasEstimate) =
                quoteExactOutputSingle(
                    QuoteExactOutputSingleParams({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        amount: amountOut,
                        fee: fee,
                        sqrtPriceLimitX96: 0
                    })
                );

            sqrtPriceX96AfterList[i] = _sqrtPriceX96After;
            initializedTicksCrossedList[i] = _initializedTicksCrossed;
            amountOut = _amountIn;
            gasEstimate += _gasEstimate;
            i++;

            // Decide whether to continue or terminate
            if (path.hasMultiplePools()) {
                path = path.skipToken();
            } else {
                return (amountOut, sqrtPriceX96AfterList, initializedTicksCrossedList, gasEstimate);
            }
        }
    }
}
