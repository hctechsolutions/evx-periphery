// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/interfaces/IEvxFactory.sol';
import '@evx-core/interfaces/callback/IEvxMintCallback.sol';
import '@evx-core/libraries/TickMath.sol';

import '@evx-periphery/libraries/PoolAddress.sol';
import '@evx-periphery/libraries/CallbackValidation.sol';
import '@evx-periphery/libraries/LiquidityAmounts.sol';

import './PeripheryPayments.sol';
import './PeripheryImmutableState.sol';

/**
 * @title LiquidityManagement
 * @notice Internal functions for safely managing liquidity in Evx.
 * @dev Handles mint callbacks and liquidity calculations when adding liquidity to a pool.
 */
abstract contract LiquidityManagement is IEvxMintCallback, PeripheryImmutableState, PeripheryPayments {
    /**
     * @notice Struct containing information for the mint callback.
     * @param poolKey Encoded pool parameters.
     * @param payer The address responsible for the payment.
     */
    struct MintCallbackData {
        PoolAddress.PoolKey poolKey;
        address payer;
    }

    /// @inheritdoc IEvxMintCallback
    function evxMintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));
        CallbackValidation.verifyCallback(factory, decoded.poolKey);

        if (amount0Owed > 0) pay(decoded.poolKey.token0, decoded.payer, msg.sender, amount0Owed);
        if (amount1Owed > 0) pay(decoded.poolKey.token1, decoded.payer, msg.sender, amount1Owed);
    }

    /**
     * @notice Parameters used to add liquidity to a pool.
     * @param token0 The first token of the pool.
     * @param token1 The second token of the pool.
     * @param fee The fee tier of the pool.
     * @param recipient The address that will receive the minted liquidity.
     * @param tickLower The lower tick of the position.
     * @param tickUpper The upper tick of the position.
     * @param amount0Desired The desired amount of token0 to add.
     * @param amount1Desired The desired amount of token1 to add.
     * @param amount0Min The minimum amount of token0 to add (for slippage protection).
     * @param amount1Min The minimum amount of token1 to add (for slippage protection).
     */
    struct AddLiquidityParams {
        address token0;
        address token1;
        uint24 fee;
        address recipient;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    /**
     * @notice Adds liquidity to an existing Evx pool.
     * @dev Calculates the liquidity amount using current price and tick bounds.
     * Performs slippage check after minting.
     * @param params The parameters for adding liquidity.
     * @return liquidity The amount of liquidity minted.
     * @return amount0 The actual amount of token0 used.
     * @return amount1 The actual amount of token1 used.
     * @return pool The pool instance where liquidity was added.
     */
    function addLiquidity(AddLiquidityParams memory params)
        internal
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            IEvxPool pool
        )
    {
        PoolAddress.PoolKey memory poolKey = PoolAddress.PoolKey({
            token0: params.token0, 
            token1: params.token1, 
            fee: params.fee
        });

        pool = IEvxPool(PoolAddress.computeAddress(factory, poolKey));

        // compute the liquidity amount
        {
            (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(params.tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(params.tickUpper);

            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                sqrtRatioAX96,
                sqrtRatioBX96,
                params.amount0Desired,
                params.amount1Desired
            );
        }

        (amount0, amount1) = pool.mint(
            params.recipient,
            params.tickLower,
            params.tickUpper,
            liquidity,
            abi.encode(MintCallbackData({poolKey: poolKey, payer: msg.sender}))
        );

        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, 'Price slippage check');
    }
}
