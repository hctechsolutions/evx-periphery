// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/libraries/SafeCast.sol';
import '@evx-core/libraries/TickMath.sol';
import '@evx-core/interfaces/IEvxPool.sol';

import '@evx-periphery/interfaces/ISwapRouter.sol';
import '@evx-periphery/contracts/base/PeripheryImmutableState.sol';
import '@evx-periphery/contracts/base/PeripheryValidation.sol';
import '@evx-periphery/contracts/base/PeripheryPaymentsWithFee.sol';
import '@evx-periphery/contracts/base/Multicall.sol';
import '@evx-periphery/contracts/base/SelfPermit.sol';
import '@evx-periphery/libraries/Path.sol';
import '@evx-periphery/libraries/PoolAddress.sol';
import '@evx-periphery/libraries/CallbackValidation.sol';
import '@evx-periphery/interfaces/external/IWETH9.sol';

/**
 * @title SwapRouter
 * @notice Stateless router for executing swaps against Evx pools.
 * @dev Supports exact input and exact output swaps across single or multiple pools using encoded paths.
 */
contract SwapRouter is
    ISwapRouter,
    PeripheryImmutableState,
    PeripheryValidation,
    PeripheryPaymentsWithFee,
    Multicall,
    SelfPermit
{
    using Path for bytes;
    using SafeCast for uint256;

    /// @dev Sentinel value indicating no cached amountIn for exactOutput swaps.
    uint256 private constant DEFAULT_AMOUNT_IN_CACHED = type(uint256).max;

    /// @dev Temporary storage for computed input amount in exact output swaps.
    uint256 private amountInCached = DEFAULT_AMOUNT_IN_CACHED;

    /**
     * @notice Initializes the swap router with factory and WETH9 references.
     * @param _factory The address of the Evx factory.
     * @param _WETH9 The address of the WETH9 contract.
     */
    constructor(address _factory, address _WETH9) PeripheryImmutableState(_factory, _WETH9) {}

    /**
     * @notice Returns the pool for a given token pair and fee.
     * @dev May return an invalid contract address if the pool does not exist.
     * @param tokenA First token in the pair.
     * @param tokenB Second token in the pair.
     * @param fee Pool fee tier.
     * @return The pool address as an IEvxPool instance.
     */
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) private view returns (IEvxPool) {
        return IEvxPool(PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee)));
    }

    /**
     * @notice Struct used to carry swap context between pool calls.
     * @param path The swap path in encoded form (tokenIn, fee, tokenOut).
     * @param payer The address responsible for payment of the input token.
     */
    struct SwapCallbackData {
        bytes path;
        address payer;
    }

    /// @inheritdoc IEvxSwapCallback
    function evxSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external override {
        // TODO: Add custom errors to require above
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();
        CallbackValidation.verifyCallback(factory, tokenIn, tokenOut, fee);

        (bool isExactInput, uint256 amountToPay) =
            amount0Delta > 0
                ? (tokenIn < tokenOut, uint256(amount0Delta))
                : (tokenOut < tokenIn, uint256(amount1Delta));

        if (isExactInput) {
            pay(tokenIn, data.payer, msg.sender, amountToPay);
        } else {
            // Either initiate the next swap or pay
            if (data.path.hasMultiplePools()) {
                data.path = data.path.skipToken();
                exactOutputInternal(amountToPay, msg.sender, 0, data);
            } else {
                amountInCached = amountToPay;
                tokenIn = tokenOut; // Swap in/out because exact output swaps are reversed
                pay(tokenIn, data.payer, msg.sender, amountToPay);
            }
        }
    }

    /**
     * @dev Executes a single exact input swap using a Evx pool.
     * @param amountIn The amount of input token to swap.
     * @param recipient Address that will receive the output tokens.
     * @param sqrtPriceLimitX96 Price limit for the swap; set to 0 for no limit.
     * @param data Swap context including path and payer.
     * @return amountOut The amount of output token received.
     */
    function exactInputInternal(
        uint256 amountIn,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) private returns (uint256 amountOut) {
        // Allow swapping to the router address with address 0
        if (recipient == address(0)) recipient = address(this);

        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();
        bool zeroForOne = tokenIn < tokenOut;

        (int256 amount0, int256 amount1) =
            getPool(tokenIn, tokenOut, fee).swap(
                recipient,
                zeroForOne,
                amountIn.toInt256(),
                sqrtPriceLimitX96 == 0
                    ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                    : sqrtPriceLimitX96,
                abi.encode(data)
            );

        return uint256(-(zeroForOne ? amount1 : amount0));
    }

    /// @inheritdoc ISwapRouter
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint256 amountOut)
    {
        amountOut = exactInputInternal(
            params.amountIn,
            params.recipient,
            params.sqrtPriceLimitX96,
            SwapCallbackData({path: abi.encodePacked(params.tokenIn, params.fee, params.tokenOut), payer: msg.sender})
        );
        require(amountOut >= params.amountOutMinimum, 'Too little received');
    }

    /// @inheritdoc ISwapRouter
    function exactInput(ExactInputParams memory params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint256 amountOut)
    {
        // msg.sender pays for the first hop
        address payer = msg.sender; 

        while (true) {
            bool hasMultiplePools = params.path.hasMultiplePools();

            // The outputs of prior swaps become the inputs to subsequent ones
            params.amountIn = exactInputInternal(
                params.amountIn,
                hasMultiplePools ? address(this) : params.recipient, // For intermediate swaps, this contract custodies
                0,
                SwapCallbackData({
                    path: params.path.getFirstPool(), // Only the first pool in the path is necessary
                    payer: payer
                })
            );

            // Decide whether to continue or terminate
            if (hasMultiplePools) {
                payer = address(this); // At this point, the caller has paid
                params.path = params.path.skipToken();
            } else {
                amountOut = params.amountIn;
                break;
            }
        }

        require(amountOut >= params.amountOutMinimum, 'Too little received');
    }

    /**
     * @dev Executes a single exact output swap using a Evx pool.
     * @param amountOut The desired amount of output token.
     * @param recipient The recipient of the output tokens.
     * @param sqrtPriceLimitX96 Optional price constraint.
     * @param data Swap context.
     * @return amountIn The required amount of input token.
     */
    function exactOutputInternal(
        uint256 amountOut,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) private returns (uint256 amountIn) {
        // llow swapping to the router address with address 0
        if (recipient == address(0)) recipient = address(this);

        (address tokenOut, address tokenIn, uint24 fee) = data.path.decodeFirstPool();
        bool zeroForOne = tokenIn < tokenOut;

        (int256 amount0Delta, int256 amount1Delta) =
            getPool(tokenIn, tokenOut, fee).swap(
                recipient,
                zeroForOne,
                -amountOut.toInt256(),
                sqrtPriceLimitX96 == 0
                    ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                    : sqrtPriceLimitX96,
                abi.encode(data)
            );

        uint256 amountOutReceived;
        (amountIn, amountOutReceived) = zeroForOne
            ? (uint256(amount0Delta), uint256(-amount1Delta))
            : (uint256(amount1Delta), uint256(-amount0Delta));
        
        // It's technically possible to not receive the full output amount,
        // so if no price limit has been specified, require this possibility away
        if (sqrtPriceLimitX96 == 0) require(amountOutReceived == amountOut);
    }

    /// @inheritdoc ISwapRouter
    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint256 amountIn)
    {
        // Avoid an SLOAD by using the swap return data
        amountIn = exactOutputInternal(
            params.amountOut,
            params.recipient,
            params.sqrtPriceLimitX96,
            SwapCallbackData({path: abi.encodePacked(params.tokenOut, params.fee, params.tokenIn), payer: msg.sender})
        );

        require(amountIn <= params.amountInMaximum, 'Too much requested');
        // Has to be reset even though we don't use it in the single hop case
        amountInCached = DEFAULT_AMOUNT_IN_CACHED;
    }

    /// @inheritdoc ISwapRouter
    function exactOutput(ExactOutputParams calldata params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint256 amountIn)
    {
        // It's okay that the payer is fixed to msg.sender here, as they're only 
        // paying for the "final" exact output swap, which happens first, and 
        // subsequent swaps are paid for within nested callback frames
        exactOutputInternal(
            params.amountOut,
            params.recipient,
            0,
            SwapCallbackData({path: params.path, payer: msg.sender})
        );

        amountIn = amountInCached;
        require(amountIn <= params.amountInMaximum, 'Too much requested');
        amountInCached = DEFAULT_AMOUNT_IN_CACHED;
    }
}
