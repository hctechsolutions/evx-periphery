// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/interfaces/callback/IEvxFlashCallback.sol';
import '@evx-core/libraries/LowGasSafeMath.sol';

import '@evx-periphery/contracts/base/PeripheryPayments.sol';
import '@evx-periphery/contracts/base/PeripheryImmutableState.sol';
import '@evx-periphery/libraries/PoolAddress.sol';
import '@evx-periphery/libraries/CallbackValidation.sol';
import '@evx-periphery/libraries/TransferHelper.sol';
import '@evx-periphery/interfaces/ISwapRouter.sol';

/**
 * @title PairFlash
 * @notice Example implementation of a flash swap using Evx's flash callback.
 * @dev Used in arbitrage between two pools to repay a flash borrow and extract profit.
 */
contract PairFlash is IEvxFlashCallback, PeripheryPayments {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;

    /// @notice Swap router used to perform arbitrage operations.
    ISwapRouter public immutable swapRouter;

    /**
     * @notice Initializes the contract with router, factory and WETH9.
     * @param _swapRouter Address of the swap router.
     * @param _factory Address of the EvxFactory.
     * @param _WETH9 Address of the WETH9 token.
     */
    constructor(
        ISwapRouter _swapRouter,
        address _factory,
        address _WETH9
    ) PeripheryImmutableState(_factory, _WETH9) {
        swapRouter = _swapRouter;
    }

    /**
     * @notice Parameters passed during flash callback execution.
     * @dev Used to reconstruct context during `evxFlashCallback`.
     * @param amount0 Amount of token0 borrowed.
     * @param amount1 Amount of token1 borrowed.
     * @param payer Address to receive any resulting profit.
     * @param poolKey Encoded pool parameters.
     * @param poolFee2 Fee tier for first arbitrage pool.
     * @param poolFee3 Fee tier for second arbitrage pool.
     */
    struct FlashCallbackData {
        uint256 amount0;
        uint256 amount1;
        address payer;
        PoolAddress.PoolKey poolKey;
        uint24 poolFee2;
        uint24 poolFee3;
    }

    /**
     * @notice Called by Evx pool after a flash borrow is executed.
     * @dev Executes two arbitrage swaps and ensures repayment with profit (if possible).
     * Reverts if the result is not profitable.
     * @param fee0 Fee owed for borrowed token0.
     * @param fee1 Fee owed for borrowed token1.
     * @param data Encoded `FlashCallbackData` struct.
     */
    function evxFlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        FlashCallbackData memory decoded = abi.decode(data, (FlashCallbackData));
        CallbackValidation.verifyCallback(factory, decoded.poolKey);

        address token0 = decoded.poolKey.token0;
        address token1 = decoded.poolKey.token1;

        // Profitability parameters - we must receive at least the required 
        // payment from the arbitrage swaps exactInputSingle will 
        // fail if this amount not met
        uint256 amount0Min = LowGasSafeMath.add(decoded.amount0, fee0);
        uint256 amount1Min = LowGasSafeMath.add(decoded.amount1, fee1);

        // Arbitrage swap 1: token1 -> token0
        TransferHelper.safeApprove(token1, address(swapRouter), decoded.amount1);
        uint256 amountOut0 =
            swapRouter.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: token1,
                    tokenOut: token0,
                    fee: decoded.poolFee2,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: decoded.amount1,
                    amountOutMinimum: amount0Min,
                    sqrtPriceLimitX96: 0
                })
            );

        // Arbitrage swap 2: token0 -> token1
        TransferHelper.safeApprove(token0, address(swapRouter), decoded.amount0);
        uint256 amountOut1 =
            swapRouter.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: token0,
                    tokenOut: token1,
                    fee: decoded.poolFee3,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: decoded.amount0,
                    amountOutMinimum: amount1Min,
                    sqrtPriceLimitX96: 0
                })
            );

        // Repay flash borrow
        if (amount0Min > 0) pay(token0, address(this), msg.sender, amount0Min);
        if (amount1Min > 0) pay(token1, address(this), msg.sender, amount1Min);

        // Transfer any profit to payer
        if (amountOut0 > amount0Min) {
            uint256 profit0 = amountOut0 - amount0Min;
            pay(token0, address(this), decoded.payer, profit0);
        }
        if (amountOut1 > amount1Min) {
            uint256 profit1 = amountOut1 - amount1Min;
            pay(token1, address(this), decoded.payer, profit1);
        }
    }

    /**
     * @notice Parameters used to initiate a flash borrow and arbitrage.
     * @param token0 Address of token0 in the pool to borrow from.
     * @param token1 Address of token1 in the pool to borrow from.
     * @param fee1 Fee tier of the initial borrow pool.
     * @param amount0 Amount of token0 to borrow.
     * @param amount1 Amount of token1 to borrow.
     * @param fee2 Fee tier of the first arbitrage pool.
     * @param fee3 Fee tier of the second arbitrage pool.
     */
    struct FlashParams {
        address token0;
        address token1;
        uint24 fee1;
        uint256 amount0;
        uint256 amount1;
        uint24 fee2;
        uint24 fee3;
    }

    /**
     * @notice Initiates a flash borrow and sets up arbitrage logic.
     * @dev Triggers `evxFlashCallback` with encoded context.
     * @param params The parameters required to initiate and settle the flash loan.
     */
    function initFlash(FlashParams memory params) external {
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: params.token0, token1: params.token1, fee: params.fee1});

        IEvxPool pool = IEvxPool(PoolAddress.computeAddress(factory, poolKey));

        pool.flash(
            address(this),
            params.amount0,
            params.amount1,
            abi.encode(
                FlashCallbackData({
                    amount0: params.amount0,
                    amount1: params.amount1,
                    payer: msg.sender,
                    poolKey: poolKey,
                    poolFee2: params.fee2,
                    poolFee3: params.fee3
                })
            )
        );
    }
}
