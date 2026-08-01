// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/interfaces/IEvxPool.sol';
import '@evx-core/libraries/FixedPoint128.sol';
import '@evx-core/libraries/TickMath.sol';
import '@evx-core/libraries/Tick.sol';
import '@evx-periphery/interfaces/INonfungiblePositionManager.sol';
import './LiquidityAmounts.sol';
import './PoolAddress.sol';
import './PositionKey.sol';

/**
 * @title PositionValue
 * @notice Utility library for calculating the value of a Evx NFT liquidity position.
 * @dev Computes principal and fee amounts held in a given NFT position.
 */
library PositionValue {
    /**
     * @notice Returns the total value of a position in token0 and token1, including principal and fees.
     * @param positionManager The address of the Evx NonfungiblePositionManager.
     * @param tokenId The ID of the NFT representing the position.
     * @param sqrtRatioX96 The current sqrt price (Q64.96 format).
     * @return amount0 The total amount of token0 (principal + fees).
     * @return amount1 The total amount of token1 (principal + fees).
     */
    function total(
        INonfungiblePositionManager positionManager,
        uint256 tokenId,
        uint160 sqrtRatioX96
    ) internal view returns (uint256 amount0, uint256 amount1) {
        (uint256 amount0Principal, uint256 amount1Principal) = principal(positionManager, tokenId, sqrtRatioX96);
        (uint256 amount0Fee, uint256 amount1Fee) = fees(positionManager, tokenId);
        return (amount0Principal + amount0Fee, amount1Principal + amount1Fee);
    }

    /**
     * @notice Returns the principal (liquidity-based) amount of token0 and token1 in a position.
     * @param positionManager The address of the Evx NonfungiblePositionManager.
     * @param tokenId The ID of the NFT representing the position.
     * @param sqrtRatioX96 The current sqrt price (Q64.96 format).
     * @return amount0 The principal amount of token0.
     * @return amount1 The principal amount of token1.
     */
    function principal(
        INonfungiblePositionManager positionManager,
        uint256 tokenId,
        uint160 sqrtRatioX96
    ) internal view returns (uint256 amount0, uint256 amount1) {
        (, , , , , int24 tickLower, int24 tickUpper, uint128 liquidity, , , , ) = positionManager.positions(tokenId);

        return
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
    }

    /**
     * @notice A struct containing data required to compute fees owed to a position.
     */
    struct FeeParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 positionFeeGrowthInside0LastX128;
        uint256 positionFeeGrowthInside1LastX128;
        uint256 tokensOwed0;
        uint256 tokensOwed1;
    }

    /**
     * @notice Returns the fees owed to a position.
     * @param positionManager The address of the Evx NonfungiblePositionManager.
     * @param tokenId The ID of the NFT representing the position.
     * @return amount0 The fees owed in token0.
     * @return amount1 The fees owed in token1.
     */
    function fees(INonfungiblePositionManager positionManager, uint256 tokenId)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 positionFeeGrowthInside0LastX128,
            uint256 positionFeeGrowthInside1LastX128,
            uint256 tokensOwed0,
            uint256 tokensOwed1
        ) = positionManager.positions(tokenId);

        return
            _fees(
                positionManager,
                FeeParams({
                    token0: token0,
                    token1: token1,
                    fee: fee,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidity: liquidity,
                    positionFeeGrowthInside0LastX128: positionFeeGrowthInside0LastX128,
                    positionFeeGrowthInside1LastX128: positionFeeGrowthInside1LastX128,
                    tokensOwed0: tokensOwed0,
                    tokensOwed1: tokensOwed1
                })
            );
    }

    /**
     * @dev Internal helper for computing fees using `FeeParams`.
     * @param positionManager The position manager to reference the factory.
     * @param feeParams The data required to calculate the fees owed.
     * @return amount0 The fees owed in token0.
     * @return amount1 The fees owed in token1.
     */
    function _fees(INonfungiblePositionManager positionManager, FeeParams memory feeParams)
        private
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (uint256 poolFeeGrowthInside0LastX128, uint256 poolFeeGrowthInside1LastX128) =
            _getFeeGrowthInside(
                IEvxPool(
                    PoolAddress.computeAddress(
                        positionManager.factory(),
                        PoolAddress.PoolKey({token0: feeParams.token0, token1: feeParams.token1, fee: feeParams.fee})
                    )
                ),
                feeParams.tickLower,
                feeParams.tickUpper
            );

        amount0 =
            FullMath.mulDiv(
                poolFeeGrowthInside0LastX128 - feeParams.positionFeeGrowthInside0LastX128,
                feeParams.liquidity,
                FixedPoint128.Q128
            ) +
            feeParams.tokensOwed0;

        amount1 =
            FullMath.mulDiv(
                poolFeeGrowthInside1LastX128 - feeParams.positionFeeGrowthInside1LastX128,
                feeParams.liquidity,
                FixedPoint128.Q128
            ) +
            feeParams.tokensOwed1;
    }

    /**
     * @dev Computes the fee growth inside a given tick range.
     * @param pool The Evx pool contract.
     * @param tickLower The lower bound of the position's tick.
     * @param tickUpper The upper bound of the position's tick.
     * @return feeGrowthInside0X128 The fee growth for token0 inside the tick range.
     * @return feeGrowthInside1X128 The fee growth for token1 inside the tick range.
     */
    function _getFeeGrowthInside(
        IEvxPool pool,
        int24 tickLower,
        int24 tickUpper
    ) private view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        (, int24 tickCurrent, , , , , ) = pool.slot0();
        (, , uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128, , , , ) = pool.ticks(tickLower);
        (, , uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128, , , , ) = pool.ticks(tickUpper);

        if (tickCurrent < tickLower) {
            feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
            feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
        } else if (tickCurrent < tickUpper) {
            uint256 feeGrowthGlobal0X128 = pool.feeGrowthGlobal0X128();
            uint256 feeGrowthGlobal1X128 = pool.feeGrowthGlobal1X128();
            feeGrowthInside0X128 = feeGrowthGlobal0X128 - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
            feeGrowthInside1X128 = feeGrowthGlobal1X128 - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
        } else {
            feeGrowthInside0X128 = upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128;
            feeGrowthInside1X128 = upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128;
        }
    }
}
