// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

import "@evx-core/interfaces/IERC20Minimal.sol";

import "@evx-core/interfaces/IEvxPool.sol";

import "@evx-core/contracts/NoDelegateCallUpgradeable.sol";

import { LowGasSafeMath } from "@evx-core/libraries/LowGasSafeMath.sol";
import { TransferHelper } from "@evx-core/libraries/TransferHelper.sol";
import { FixedPoint128 } from "@evx-core/libraries/FixedPoint128.sol";
import { LiquidityMath } from "@evx-core/libraries/LiquidityMath.sol";
import { SqrtPriceMath } from "@evx-core/libraries/SqrtPriceMath.sol";
import { TickBitmap } from "@evx-core/libraries/TickBitmap.sol";
import { SafeCast } from "@evx-core/libraries/SafeCast.sol";
import { Position } from "@evx-core/libraries/Position.sol";
import { FullMath } from "@evx-core/libraries/FullMath.sol";
import { TickMath } from "@evx-core/libraries/TickMath.sol";
import { SwapMath } from "@evx-core/libraries/SwapMath.sol";
import { Oracle } from "@evx-core/libraries/Oracle.sol";
import { Tick } from "@evx-core/libraries/Tick.sol";

import "@evx-core/libraries/Errors.sol";

import "@evx-core/interfaces/IEvxFactory.sol";
import "@evx-core/interfaces/callback/IEvxMintCallback.sol";
import "@evx-core/interfaces/callback/IEvxSwapCallback.sol";
import "@evx-core/interfaces/callback/IEvxFlashCallback.sol";

/**
 * @title EvxPool
 * @notice Evx-style pool implementation handling liquidity, swaps, and fees for a token pair
 * @dev Initializes parameters via IEvxPoolDeployer; protected against delegate calls and reentrancy
 */
contract EvxPool is IEvxPool, NoDelegateCallUpgradeable {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;

    using SafeCast for uint256;
    using SafeCast for int256;

    using SafeCast for uint128;

    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using Oracle for Oracle.Observation[65535];

    /// @inheritdoc IEvxPoolImmutables
    address public factory;

    /// @inheritdoc IEvxPoolImmutables
    address public token0;

    /// @inheritdoc IEvxPoolImmutables
    address public token1;

    /// @inheritdoc IEvxPoolImmutables
    uint24 public fee;

    /// @inheritdoc IEvxPoolImmutables
    int24 public tickSpacing;

    /// @inheritdoc IEvxPoolImmutables
    uint128 public maxLiquidityPerTick;

    /**
    * @notice Parameters for modifying a liquidity position.
    * @dev Used when minting or burning liquidity from a given tick range.
    */
    struct ModifyPositionParams {
        /// @notice Address of the position owner.
        address owner;

        /// @notice Lower bound of the position's tick range.
        int24 tickLower;

        /// @notice Upper bound of the position's tick range.
        int24 tickUpper;

        /// @notice Amount of liquidity to add (positive) or remove (negative).
        int128 liquidityDelta;
    }

    /**
    * @notice Stores transient data needed during a swap.
    * @dev This data is used to cache state during the swap execution loop.
    */
    struct SwapCache {
        /// @notice Protocol fee in effect for the input token.
        uint8 feeProtocol;

        /// @notice Liquidity at the beginning of the swap.
        uint128 liquidityStart;

        /// @notice Current block timestamp.
        uint32 blockTimestamp;

        /// @notice Accumulated tick value, updated if a tick is crossed.
        int56 tickCumulative;

        /// @notice Accumulated seconds per liquidity, updated if a tick is crossed.
        uint160 secondsPerLiquidityCumulativeX128;

        /// @notice Flag indicating if the cumulative values were already computed.
        bool computedLatestObservation;
    }

    /**
    * @notice Aggregates the current state of an in-progress swap.
    * @dev This struct is mutated in each step of the swap loop and finalized at the end.
    */
    struct SwapState {
        /// @notice Amount remaining to be swapped in or out.
        int256 amountSpecifiedRemaining;

        /// @notice Amount of tokens calculated to be received or sent.
        int256 amountCalculated;

        /// @notice Current sqrt price Q64.96 after this swap step.
        uint160 sqrtPriceX96;

        /// @notice Tick corresponding to the current sqrt price.
        int24 tick;

        /// @notice Global fee growth for the input token.
        uint256 feeGrowthGlobalX128;

        /// @notice Protocol fee accumulated during the swap.
        uint128 protocolFee;

        /// @notice Current available liquidity within the tick range.
        uint128 liquidity;
    }

    /**
    * @notice Contains temporary variables for a single step in a swap.
    * @dev Used to perform intermediate calculations during swap iteration.
    */
    struct StepComputations {
        /// @notice Starting sqrt price of the current swap step.
        uint160 sqrtPriceStartX96;

        /// @notice Next tick to be crossed in the direction of the swap.
        int24 tickNext;

        /// @notice Indicates whether tickNext is initialized.
        bool initialized;

        /// @notice Sqrt price at the next tick.
        uint160 sqrtPriceNextX96;

        /// @notice Amount of input token for this step.
        uint256 amountIn;

        /// @notice Amount of output token for this step.
        uint256 amountOut;

        /// @notice Fee amount paid during this step.
        uint256 feeAmount;
    }

    /**
    * @notice Core storage slot used by the pool to track state.
    * @dev Frequently accessed and modified during swaps and liquidity operations.
    */
    struct Slot0 {
        /// @notice Current sqrt price Q64.96 of the pool.
        uint160 sqrtPriceX96;

        /// @notice Current tick of the pool.
        int24 tick;

        /// @notice Index of the last written oracle observation.
        uint16 observationIndex;

        /// @notice Current max number of stored oracle observations.
        uint16 observationCardinality;

        /// @notice Target max number of observations to store, pending growth.
        uint16 observationCardinalityNext;

        /// @notice Protocol fee encoded as an integer divisor of the swap fee.
        uint8 feeProtocol;

        /// @notice Indicates whether the pool is unlocked and reentrancy-safe.
        bool unlocked;
    }

    /// @inheritdoc IEvxPoolState
    Slot0 public override slot0;

    /// @inheritdoc IEvxPoolState
    uint256 public override feeGrowthGlobal0X128;

    /// @inheritdoc IEvxPoolState
    uint256 public override feeGrowthGlobal1X128;

    // accumulated protocol fees in token0/token1 units
    struct ProtocolFees {
        uint128 token0;
        uint128 token1;
    }

    /// @inheritdoc IEvxPoolState
    ProtocolFees public override protocolFees;

    /// @inheritdoc IEvxPoolState
    uint128 public override liquidity;

    /// @inheritdoc IEvxPoolState
    mapping(int24 => Tick.Info) public override ticks;
    /// @inheritdoc IEvxPoolState
    mapping(int16 => uint256) public override tickBitmap;
    /// @inheritdoc IEvxPoolState
    mapping(bytes32 => Position.Info) public override positions;
    /// @inheritdoc IEvxPoolState
    Oracle.Observation[65535] public override observations;

    /**
     * @notice Modifier to protect functions from reentrancy and enforce pool initialization
     * @dev Ensures mutual exclusion and verifies that the pool is initialized
     */    
    modifier lock() {
        if (!slot0.unlocked) revert Locked();
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    /**
     * @notice Modifier to restrict function access to the factory owner
     * @dev Validates the caller against the factory's owner address
     */    
    modifier onlyFactoryOwner() {
        if (msg.sender != IEvxFactory(factory).owner()) revert OnlyFactoryOwner();
        _;
    }

    /**
     * @notice Validates a tick range
     * @dev Ensures tickLower < tickUpper and that both are within valid tick bounds
     * @param tickLower The lower tick
     * @param tickUpper The upper tick
     */
    function checkTicks(int24 tickLower, int24 tickUpper) private pure {
        if (tickLower > tickUpper) revert InvalidTickOrder();
        if (tickLower <= TickMath.MIN_TICK) revert TickLowerBelowMinimum();
        if (tickUpper >= TickMath.MAX_TICK) revert TickUpperAboveMaximum();
    }

    /**
     * @notice Returns the block timestamp truncated to 32 bits
     * @dev Used to ensure compatibility with uint32 timestamps
     * @return The current block timestamp truncated to uint32
     */
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    /**
     * @notice Gets the current balance of token0 held by the pool
     * @dev Uses staticcall to avoid extcodesize overhead
     * @return The token0 balance
     */
    function balance0() private view returns (uint256) {
        (bool success, bytes memory data) =
            token0.staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this)));
        if (!(success && data.length >= 32)) revert BalanceQueryFailed();
        return abi.decode(data, (uint256));
    }

    /**
     * @notice Gets the current balance of token1 held by the pool
     * @dev Uses staticcall to avoid extcodesize overhead
     * @return The token1 balance
     */
    function balance1() private view returns (uint256) {
        (bool success, bytes memory data) =
            token1.staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this)));
        if (!(success && data.length >= 32)) revert BalanceQueryFailed();
        return abi.decode(data, (uint256));
    }

    /// @inheritdoc IEvxPoolDerivedState
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        override
        noDelegateCall
        returns (
            int56 tickCumulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        )
    {
        checkTicks(tickLower, tickUpper);

        int56 tickCumulativeLower;
        int56 tickCumulativeUpper;
        uint160 secondsPerLiquidityOutsideLowerX128;
        uint160 secondsPerLiquidityOutsideUpperX128;
        uint32 secondsOutsideLower;
        uint32 secondsOutsideUpper;

        {
            Tick.Info storage lower = ticks[tickLower];
            Tick.Info storage upper = ticks[tickUpper];
            bool initializedLower;
            (tickCumulativeLower, secondsPerLiquidityOutsideLowerX128, secondsOutsideLower, initializedLower) = (
                lower.tickCumulativeOutside,
                lower.secondsPerLiquidityOutsideX128,
                lower.secondsOutside,
                lower.initialized
            );
            if (!initializedLower) revert LowerTickNotInitialized();

            bool initializedUpper;
            (tickCumulativeUpper, secondsPerLiquidityOutsideUpperX128, secondsOutsideUpper, initializedUpper) = (
                upper.tickCumulativeOutside,
                upper.secondsPerLiquidityOutsideX128,
                upper.secondsOutside,
                upper.initialized
            );
            if (!initializedUpper) revert UpperTickNotInitialized();
        }

        Slot0 memory _slot0 = slot0;

        if (_slot0.tick < tickLower) {
            return (
                tickCumulativeLower - tickCumulativeUpper,
                secondsPerLiquidityOutsideLowerX128 - secondsPerLiquidityOutsideUpperX128,
                secondsOutsideLower - secondsOutsideUpper
            );
        } else if (_slot0.tick < tickUpper) {
            uint32 time = _blockTimestamp();
            (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) =
                observations.observeSingle(
                    time,
                    0,
                    _slot0.tick,
                    _slot0.observationIndex,
                    liquidity,
                    _slot0.observationCardinality
                );
            return (
                tickCumulative - tickCumulativeLower - tickCumulativeUpper,
                secondsPerLiquidityCumulativeX128 -
                    secondsPerLiquidityOutsideLowerX128 -
                    secondsPerLiquidityOutsideUpperX128,
                time - secondsOutsideLower - secondsOutsideUpper
            );
        } else {
            return (
                tickCumulativeUpper - tickCumulativeLower,
                secondsPerLiquidityOutsideUpperX128 - secondsPerLiquidityOutsideLowerX128,
                secondsOutsideUpper - secondsOutsideLower
            );
        }
    }

    /// @inheritdoc IEvxPoolDerivedState
    function observe(uint32[] calldata secondsAgos)
        external
        view
        override
        noDelegateCall
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        return
            observations.observe(
                _blockTimestamp(),
                secondsAgos,
                slot0.tick,
                slot0.observationIndex,
                liquidity,
                slot0.observationCardinality
            );
    }

    /// @inheritdoc IEvxPoolActions
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext)
        external
        override
        lock
        noDelegateCall
    {
        uint16 observationCardinalityNextOld = slot0.observationCardinalityNext; // for the event
        uint16 observationCardinalityNextNew =
            observations.grow(observationCardinalityNextOld, observationCardinalityNext);
        slot0.observationCardinalityNext = observationCardinalityNextNew;
        if (observationCardinalityNextOld != observationCardinalityNextNew)
            emit IncreaseObservationCardinalityNext(observationCardinalityNextOld, observationCardinalityNextNew);
    }

    function initialize(
        address _factory,
        address _token0,
        address _token1,
        uint24  _fee,
        int24 _tickSpacing
    ) external {
        __NoDelegateCall_init();

        factory = _factory;
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
        tickSpacing = _tickSpacing;

        maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(_tickSpacing);
    }

    /// @inheritdoc IEvxPoolActions
    /// @dev not locked because it initializes unlocked
    function initializeObservation(uint160 sqrtPriceX96) external override {
        if (slot0.sqrtPriceX96 != 0) revert AlreadyInitialized();

        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        (uint16 cardinality, uint16 cardinalityNext) = observations.initialize(_blockTimestamp());

        slot0 = Slot0({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            observationIndex: 0,
            observationCardinality: cardinality,
            observationCardinalityNext: cardinalityNext,
            feeProtocol: 0,
            unlocked: true
        });

        emit InitializeObservation(sqrtPriceX96, tick);
    }

    /**
     * @notice Internal function to modify a liquidity position
     * @dev Computes and updates a position, handles tick updates
     * @param params Struct containing position owner, tick range, and liquidity delta
     * @return position The updated position storage pointer
     * @return amount0 Delta of token0 due to position change
     * @return amount1 Delta of token1 due to position change
     */
    function _modifyPosition(ModifyPositionParams memory params)
        private
        noDelegateCall
        returns (
            Position.Info storage position,
            int256 amount0,
            int256 amount1
        )
    {
        checkTicks(params.tickLower, params.tickUpper);

        Slot0 memory _slot0 = slot0; // SLOAD for gas optimization

        position = _updatePosition(
            params.owner,
            params.tickLower,
            params.tickUpper,
            params.liquidityDelta,
            _slot0.tick
        );

        if (params.liquidityDelta != 0) {
            if (_slot0.tick < params.tickLower) {
                // current tick is below the passed range; liquidity can only become in range by crossing from left to
                // right, when we'll need _more_ token0 (it's becoming more valuable) so user must provide it
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            } else if (_slot0.tick < params.tickUpper) {
                // current tick is inside the passed range
                uint128 liquidityBefore = liquidity; // SLOAD for gas optimization

                // write an oracle entry
                (slot0.observationIndex, slot0.observationCardinality) = observations.write(
                    _slot0.observationIndex,
                    _blockTimestamp(),
                    _slot0.tick,
                    liquidityBefore,
                    _slot0.observationCardinality,
                    _slot0.observationCardinalityNext
                );

                amount0 = SqrtPriceMath.getAmount0Delta(
                    _slot0.sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    _slot0.sqrtPriceX96,
                    params.liquidityDelta
                );

                liquidity = LiquidityMath.addDelta(liquidityBefore, params.liquidityDelta);
            } else {
                // current tick is above the passed range; liquidity can only become in range by crossing from right to
                // left, when we'll need _more_ token1 (it's becoming more valuable) so user must provide it
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            }
        }
    }

    /**
     * @notice Updates a position's liquidity and fees
     * @dev Performs tick initialization, updates fee growth, and adjusts liquidity
     * @param owner Position owner
     * @param tickLower Lower tick of the position
     * @param tickUpper Upper tick of the position
     * @param liquidityDelta Amount of liquidity to change
     * @param tick Current pool tick
     * @return position Updated position reference
     */
    function _updatePosition(
        address owner,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta,
        int24 tick
    ) private returns (Position.Info storage position) {
        position = positions.get(owner, tickLower, tickUpper);

        uint256 _feeGrowthGlobal0X128 = feeGrowthGlobal0X128; // SLOAD for gas optimization
        uint256 _feeGrowthGlobal1X128 = feeGrowthGlobal1X128; // SLOAD for gas optimization

        // if we need to update the ticks, do it
        bool flippedLower;
        bool flippedUpper;
        if (liquidityDelta != 0) {
            uint32 time = _blockTimestamp();
            (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) =
                observations.observeSingle(
                    time,
                    0,
                    slot0.tick,
                    slot0.observationIndex,
                    liquidity,
                    slot0.observationCardinality
                );

            flippedLower = ticks.update(
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                secondsPerLiquidityCumulativeX128,
                tickCumulative,
                time,
                false,
                maxLiquidityPerTick
            );
            flippedUpper = ticks.update(
                tickUpper,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                secondsPerLiquidityCumulativeX128,
                tickCumulative,
                time,
                true,
                maxLiquidityPerTick
            );

            if (flippedLower) {
                tickBitmap.flipTick(tickLower, tickSpacing);
            }
            if (flippedUpper) {
                tickBitmap.flipTick(tickUpper, tickSpacing);
            }
        }

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            ticks.getFeeGrowthInside(tickLower, tickUpper, tick, _feeGrowthGlobal0X128, _feeGrowthGlobal1X128);

        position.update(liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);

        // clear any tick data that is no longer needed
        if (liquidityDelta < 0) {
            if (flippedLower) {
                ticks.clear(tickLower);
            }
            if (flippedUpper) {
                ticks.clear(tickUpper);
            }
        }
    }

    /// @inheritdoc IEvxPoolActions
    /// @dev noDelegateCall is applied indirectly via _modifyPosition
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        if (amount <= 0) revert MintZeroAmount();

        int128 liquidityDelta = amount.toInt256().toInt128();
        (, int256 amount0Int, int256 amount1Int) =
            _modifyPosition(
                ModifyPositionParams({
                    owner: recipient,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: liquidityDelta
                })
            );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        uint256 balance0Before;
        uint256 balance1Before;
        
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();
        IEvxMintCallback(msg.sender).evxMintCallback(amount0, amount1, data);
        if (amount0 > 0 && balance0Before.add(amount0) > balance0()) revert InsufficientBalance0();
        if (amount1 > 0 && balance1Before.add(amount1) > balance1()) revert InsufficientBalance1();
        
        emit Mint(msg.sender, recipient, tickLower, tickUpper, amount, amount0, amount1);
    }

    /// @inheritdoc IEvxPoolActions
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override lock returns (uint128 amount0, uint128 amount1) {
        // we don't need to checkTicks here, because invalid positions will never have non-zero tokensOwed{0,1}
        Position.Info storage position = positions.get(msg.sender, tickLower, tickUpper);

        amount0 = amount0Requested > position.tokensOwed0 ? position.tokensOwed0 : amount0Requested;
        amount1 = amount1Requested > position.tokensOwed1 ? position.tokensOwed1 : amount1Requested;

        if (amount0 > 0) {
            position.tokensOwed0 -= amount0;
            TransferHelper.safeTransfer(token0, recipient, amount0);
        }
        if (amount1 > 0) {
            position.tokensOwed1 -= amount1;
            TransferHelper.safeTransfer(token1, recipient, amount1);
        }

        emit Collect(msg.sender, recipient, tickLower, tickUpper, amount0, amount1);
    }

    /// @inheritdoc IEvxPoolActions
    /// @dev noDelegateCall is applied indirectly via _modifyPosition
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        int128 negativeLiquidityDelta = amount.toInt256().toInt128() * -1;
        (Position.Info storage position, int256 amount0Int, int256 amount1Int) =
            _modifyPosition(
                ModifyPositionParams({
                    owner: msg.sender,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: negativeLiquidityDelta
                })
            );

        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0 || amount1 > 0) {
            (position.tokensOwed0, position.tokensOwed1) = (
                position.tokensOwed0 + uint128(amount0),
                position.tokensOwed1 + uint128(amount1)
            );
        }

        emit Burn(msg.sender, tickLower, tickUpper, amount, amount0, amount1);
    }

    /// @inheritdoc IEvxPoolActions
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override noDelegateCall returns (int256 amount0, int256 amount1) {
        if (amountSpecified == 0) revert ZeroSwapAmount();

        Slot0 memory slot0Start = slot0;

        if (!slot0Start.unlocked) revert Locked();

        if (zeroForOne ? !(sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO) : !(sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO)) revert SqrtPriceLimit();

        slot0.unlocked = false;

        SwapCache memory cache =
            SwapCache({
                liquidityStart: liquidity,
                blockTimestamp: _blockTimestamp(),
                feeProtocol: zeroForOne ? (slot0Start.feeProtocol % 16) : (slot0Start.feeProtocol >> 4),
                secondsPerLiquidityCumulativeX128: 0,
                tickCumulative: 0,
                computedLatestObservation: false
            });

        bool exactInput = amountSpecified > 0;

        SwapState memory state =
            SwapState({
                amountSpecifiedRemaining: amountSpecified,
                amountCalculated: 0,
                sqrtPriceX96: slot0Start.sqrtPriceX96,
                tick: slot0Start.tick,
                feeGrowthGlobalX128: zeroForOne ? feeGrowthGlobal0X128 : feeGrowthGlobal1X128,
                protocolFee: 0,
                liquidity: cache.liquidityStart
            });

        // continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
        while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
            StepComputations memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.tickNext, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                tickSpacing,
                zeroForOne
            );

            // ensure that we do not overshoot the min/max tick, as the tick bitmap is not aware of these bounds
            if (step.tickNext < TickMath.MIN_TICK) {
                step.tickNext = TickMath.MIN_TICK;
            } else if (step.tickNext > TickMath.MAX_TICK) {
                step.tickNext = TickMath.MAX_TICK;
            }

            // get the price for the next tick
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

            // compute values to swap to the target tick, price limit, or point where input/output amount is exhausted
            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                (zeroForOne ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                fee
            );

            if (exactInput) {
                state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
                state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());
            } else {
                state.amountSpecifiedRemaining += step.amountOut.toInt256();
                state.amountCalculated = state.amountCalculated.add((step.amountIn + step.feeAmount).toInt256());
            }

            // if the protocol fee is on, calculate how much is owed, decrement feeAmount, and increment protocolFee
            if (cache.feeProtocol > 0) {
                uint256 delta = step.feeAmount / cache.feeProtocol;
                step.feeAmount -= delta;
                state.protocolFee += uint128(delta);
            }

            // update global fee tracker
            if (state.liquidity > 0)
                state.feeGrowthGlobalX128 += FullMath.mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);

            // shift tick if we reached the next price
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                // if the tick is initialized, run the tick transition
                if (step.initialized) {
                    // check for the placeholder value, which we replace with the actual value the first time the swap
                    // crosses an initialized tick
                    if (!cache.computedLatestObservation) {
                        (cache.tickCumulative, cache.secondsPerLiquidityCumulativeX128) = observations.observeSingle(
                            cache.blockTimestamp,
                            0,
                            slot0Start.tick,
                            slot0Start.observationIndex,
                            cache.liquidityStart,
                            slot0Start.observationCardinality
                        );
                        cache.computedLatestObservation = true;
                    }
                    int128 liquidityNet =
                        ticks.cross(
                            step.tickNext,
                            (zeroForOne ? state.feeGrowthGlobalX128 : feeGrowthGlobal0X128),
                            (zeroForOne ? feeGrowthGlobal1X128 : state.feeGrowthGlobalX128),
                            cache.secondsPerLiquidityCumulativeX128,
                            cache.tickCumulative,
                            cache.blockTimestamp
                        );
                    // if we're moving leftward, we interpret liquidityNet as the opposite sign
                    // safe because liquidityNet cannot be type(int128).min
                    if (zeroForOne) liquidityNet = -liquidityNet;

                    state.liquidity = LiquidityMath.addDelta(state.liquidity, liquidityNet);
                }

                state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        // update tick and write an oracle entry if the tick change
        if (state.tick != slot0Start.tick) {
            (uint16 observationIndex, uint16 observationCardinality) =
                observations.write(
                    slot0Start.observationIndex,
                    cache.blockTimestamp,
                    slot0Start.tick,
                    cache.liquidityStart,
                    slot0Start.observationCardinality,
                    slot0Start.observationCardinalityNext
                );
            (slot0.sqrtPriceX96, slot0.tick, slot0.observationIndex, slot0.observationCardinality) = (
                state.sqrtPriceX96,
                state.tick,
                observationIndex,
                observationCardinality
            );
        } else {
            // otherwise just update the price
            slot0.sqrtPriceX96 = state.sqrtPriceX96;
        }

        // update liquidity if it changed
        if (cache.liquidityStart != state.liquidity) liquidity = state.liquidity;

        // update fee growth global and, if necessary, protocol fees
        // overflow is acceptable, protocol has to withdraw before it hits type(uint128).max fees
        if (zeroForOne) {
            feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
            if (state.protocolFee > 0) protocolFees.token0 += state.protocolFee;
        } else {
            feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
            if (state.protocolFee > 0) protocolFees.token1 += state.protocolFee;
        }

        (amount0, amount1) = zeroForOne == exactInput
            ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
            : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);

        // do the transfers and collect payment
        if (zeroForOne) {
            if (amount1 < 0) TransferHelper.safeTransfer(token1, recipient, uint256(-amount1));

            uint256 balance0Before = balance0();
            IEvxSwapCallback(msg.sender).evxSwapCallback(amount0, amount1, data);           
            if (balance0Before.add(uint256(amount0)) > balance0()) revert InsufficientInputAmount();
        } else {
            if (amount0 < 0) TransferHelper.safeTransfer(token0, recipient, uint256(-amount0));

            uint256 balance1Before = balance1();
            IEvxSwapCallback(msg.sender).evxSwapCallback(amount0, amount1, data);
            if (balance1Before.add(uint256(amount1)) > balance1()) revert InsufficientInputAmount();
        }

        emit Swap(msg.sender, recipient, amount0, amount1, state.sqrtPriceX96, state.liquidity, state.tick);
        slot0.unlocked = true;
    }

    /// @inheritdoc IEvxPoolActions
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override lock noDelegateCall {
        uint128 _liquidity = liquidity;
        if (_liquidity <= 0) revert NoLiquidity();

        uint256 fee0 = FullMath.mulDivRoundingUp(amount0, fee, 1e6);
        uint256 fee1 = FullMath.mulDivRoundingUp(amount1, fee, 1e6);
        uint256 balance0Before = balance0();
        uint256 balance1Before = balance1();

        if (amount0 > 0) TransferHelper.safeTransfer(token0, recipient, amount0);
        if (amount1 > 0) TransferHelper.safeTransfer(token1, recipient, amount1);

        IEvxFlashCallback(msg.sender).evxFlashCallback(fee0, fee1, data);

        uint256 balance0After = balance0();
        uint256 balance1After = balance1();

        if (balance0Before.add(fee0) > balance0After) revert FlashFee0NotReceived();
        if (balance1Before.add(fee1) > balance1After) revert FlashFee1NotReceived();

        // sub is safe because we know balanceAfter is gt balanceBefore by at least fee
        uint256 paid0 = balance0After - balance0Before;
        uint256 paid1 = balance1After - balance1Before;

        if (paid0 > 0) {
            uint8 feeProtocol0 = slot0.feeProtocol % 16;
            uint256 fees0 = feeProtocol0 == 0 ? 0 : paid0 / feeProtocol0;
            if (uint128(fees0) > 0) protocolFees.token0 += uint128(fees0);
            feeGrowthGlobal0X128 += FullMath.mulDiv(paid0 - fees0, FixedPoint128.Q128, _liquidity);
        }
        if (paid1 > 0) {
            uint8 feeProtocol1 = slot0.feeProtocol >> 4;
            uint256 fees1 = feeProtocol1 == 0 ? 0 : paid1 / feeProtocol1;
            if (uint128(fees1) > 0) protocolFees.token1 += uint128(fees1);
            feeGrowthGlobal1X128 += FullMath.mulDiv(paid1 - fees1, FixedPoint128.Q128, _liquidity);
        }

        emit Flash(msg.sender, recipient, amount0, amount1, paid0, paid1);
    }

    /// @inheritdoc IEvxPoolOwnerActions
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external override lock onlyFactoryOwner {
        if (!(
        (feeProtocol0 == 0 || (feeProtocol0 >= 4 && feeProtocol0 <= 10)) &&
        (feeProtocol1 == 0 || (feeProtocol1 >= 4 && feeProtocol1 <= 10))
        )) revert InvalidFeeProtocol();

        uint8 feeProtocolOld = slot0.feeProtocol;
        slot0.feeProtocol = feeProtocol0 + (feeProtocol1 << 4);
        emit SetFeeProtocol(feeProtocolOld % 16, feeProtocolOld >> 4, feeProtocol0, feeProtocol1);
    }

    /// @inheritdoc IEvxPoolOwnerActions
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override lock onlyFactoryOwner returns (uint128 amount0, uint128 amount1) {
        amount0 = amount0Requested > protocolFees.token0 ? protocolFees.token0 : amount0Requested;
        amount1 = amount1Requested > protocolFees.token1 ? protocolFees.token1 : amount1Requested;

        if (amount0 > 0) {
            if (amount0 == protocolFees.token0) amount0--; // ensure that the slot is not cleared, for gas savings
            protocolFees.token0 -= amount0;
            TransferHelper.safeTransfer(token0, recipient, amount0);
        }
        if (amount1 > 0) {
            if (amount1 == protocolFees.token1) amount1--; // ensure that the slot is not cleared, for gas savings
            protocolFees.token1 -= amount1;
            TransferHelper.safeTransfer(token1, recipient, amount1);
        }

        emit CollectProtocol(msg.sender, recipient, amount0, amount1);
    }
}
