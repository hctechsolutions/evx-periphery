// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FullMath.sol";
import "./FixedPoint128.sol";
import "./LiquidityMath.sol";

/**
 * @title Position
 * @notice Library for managing liquidity positions within tick boundaries.
 * @dev Each position is uniquely identified by owner and tick range, and stores fee and liquidity metadata.
 */
library Position {
    /**
     * @notice Stores data associated with a single liquidity position.
     * @dev Tracks liquidity, fee growth snapshots, and tokens owed for later collection.
     */
    struct Info {
        /// @notice The amount of liquidity held by this position.
        uint128 liquidity;

        /// @notice The fee growth in token0 inside the tick range as of the last update.
        uint256 feeGrowthInside0LastX128;

        /// @notice The fee growth in token1 inside the tick range as of the last update.
        uint256 feeGrowthInside1LastX128;

        /// @notice The amount of token0 owed to the position owner.
        uint128 tokensOwed0;

        /// @notice The amount of token1 owed to the position owner.
        uint128 tokensOwed1;
    }

    /**
     * @notice Retrieves the position info for a given owner and tick range.
     * @dev The key is derived as a keccak256 hash of (owner, tickLower, tickUpper).
     * @param self The mapping of all positions.
     * @param owner The address of the position owner.
     * @param tickLower The lower tick boundary of the position.
     * @param tickUpper The upper tick boundary of the position.
     * @return position The storage pointer to the position's data.
     */
    function get(
        mapping(bytes32 => Info) storage self,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (Position.Info storage position) {
        position = self[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
    }

    /**
     * @notice Updates a position with new liquidity and credits any accrued fees.
     * @dev Also updates the position's fee growth snapshot and tokens owed.
     * @param self The position to update.
     * @param liquidityDelta The change in liquidity (positive to add, negative to remove).
     * @param feeGrowthInside0X128 The current cumulative fee growth for token0 within the tick range.
     * @param feeGrowthInside1X128 The current cumulative fee growth for token1 within the tick range.
     */
    function update(
        Info storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {
        Info memory _self = self;

        uint128 liquidityNext;
        if (liquidityDelta == 0) {
            require(_self.liquidity > 0, "NP"); // Prevents updates to positions with zero liquidity.
            liquidityNext = _self.liquidity;
        } else {
            liquidityNext = LiquidityMath.addDelta(_self.liquidity, liquidityDelta);
        }

        // Calculate fees owed since the last update.
        uint128 tokensOwed0 =
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside0X128 - _self.feeGrowthInside0LastX128,
                    _self.liquidity,
                    FixedPoint128.Q128
                )
            );
        uint128 tokensOwed1 =
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside1X128 - _self.feeGrowthInside1LastX128,
                    _self.liquidity,
                    FixedPoint128.Q128
                )
            );

        // Apply updates to the position.
        if (liquidityDelta != 0) self.liquidity = liquidityNext;
        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            self.tokensOwed0 += tokensOwed0;
            self.tokensOwed1 += tokensOwed1;
        }
    }
}
