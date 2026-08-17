// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EvxFactory} from "@evx-core/contracts/EvxFactory.sol";
import {EvxPool} from "@evx-core/contracts/EvxPool.sol";
import {TickMath} from "@evx-core/libraries/TickMath.sol";
import {IEvxMintCallback} from "@evx-core/interfaces/callback/IEvxMintCallback.sol";
import {IEvxSwapCallback} from "@evx-core/interfaces/callback/IEvxSwapCallback.sol";
import {IEvxPool} from "@evx-core/interfaces/IEvxPool.sol";
import {Quoter} from "@evx-periphery/contracts/lens/Quoter.sol";
import {IQuoter} from "@evx-periphery/interfaces/IQuoter.sol";
import {ZeroLiquidity} from "@evx-periphery/libraries/QuoterErrors.sol";
import {InsufficientLiquidity} from "@evx-periphery/libraries/QuoterErrors.sol";
import {InvalidRoute} from "@evx-periphery/libraries/QuoterErrors.sol";
import {OracleLibrary} from "@evx-periphery/libraries/OracleLibrary.sol";
import {QuoteSwapMathRef} from "../../libraries/QuoteSwapMathRef.sol";
import {QuoteVectors} from "../../fixtures/QuoteVectors.sol";

/**
 * @title QuoterOracle
 * @notice Normative fixture: helper (SwapMath) == Quoter == executed swap, same initial state.
 * @dev OracleLibrary.getQuoteAtTick is documented as divergent — not the oracle.
 */
contract QuoterOracleTest is Test, IEvxMintCallback, IEvxSwapCallback {
    uint24 constant FEE = 3000;
    address constant WETH9 = address(0xC0FFEE);

    EvxFactory factory;
    Quoter quoter;
    OracleToken tokenA;
    OracleToken tokenB;
    OracleToken tokenC;

    int256 private lastAmount0;
    int256 private lastAmount1;

    function setUp() public {
        EvxPool impl = new EvxPool();
        factory = new EvxFactory(address(impl));
        tokenA = new OracleToken("A", "A");
        tokenB = new OracleToken("B", "B");
        tokenC = new OracleToken("C", "C");
        quoter = new Quoter(address(factory), WETH9);
    }

    function evxMintCallback(uint256 amount0, uint256 amount1, bytes calldata) external override {
        IEvxPool pool = IEvxPool(msg.sender);
        if (amount0 > 0) OracleToken(pool.token0()).transfer(msg.sender, amount0);
        if (amount1 > 0) OracleToken(pool.token1()).transfer(msg.sender, amount1);
    }

    function evxSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external override {
        lastAmount0 = amount0Delta;
        lastAmount1 = amount1Delta;
        IEvxPool pool = IEvxPool(msg.sender);
        if (amount0Delta > 0) OracleToken(pool.token0()).transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) OracleToken(pool.token1()).transfer(msg.sender, uint256(amount1Delta));
    }

    function test_fixture_version_is_one() public pure {
        assertEq(QuoteVectors.VERSION, 1);
    }

    function test_tick0_exactIn_0for1() public {
        _runVector(QuoteVectors.tick0ExactIn0For1());
    }

    function test_tick0_exactIn_1for0() public {
        _runVector(QuoteVectors.tick0ExactIn1For0());
    }

    function test_tick0_exactOut_0for1() public {
        _runVector(QuoteVectors.tick0ExactOut0For1());
    }

    function test_tick0_exactOut_1for0() public {
        _runVector(QuoteVectors.tick0ExactOut1For0());
    }

    function test_tickCross_hasExpectedState() public {
        QuoteVectors.Vector memory v = QuoteVectors.tickCrossExactIn1For0();
        QuoteSwapMathRef.Result memory ref = _runVector(v);
        assertTrue(ref.tick != 0, "cross vector must leave tick 0");
    }

    function test_exactIn_overquote_is_success_not_insufficient() public {
        QuoteVectors.Vector memory v = QuoteVectors.exactInOverquoteThin();
        EvxPool pool = _poolAB(v);
        _mint(pool, v.range.lo, v.range.hi, v.range.liquidity);

        (address tokenIn, address tokenOut) = _dir(pool, v.zeroForOne);
        (uint256 amountOut,,,) = quoter.quoteExactInputSingle(
            IQuoter.QuoteExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: FEE,
                amountIn: v.amountIn,
                sqrtPriceLimitX96: 0
            })
        );
        QuoteSwapMathRef.Result memory ref = QuoteSwapMathRef.simulate(
            v.sqrtPriceX96, v.tick, pool.liquidity(), v.fee, v.zeroForOne, true, v.amountIn, v.range
        );
        assertEq(amountOut, ref.amountOut, "partial fill amountOut must match SwapMath ref");
        assertGt(amountOut, 0, "partial fill is success");
        assertLt(ref.amountIn, v.amountIn, "overquote must not consume the full input");
        assertEq(ref.amountIn, v.expectedAmountIn);
        assertEq(ref.amountOut, v.expectedAmountOut);
    }

    function test_ac2_zeroLiquidity_noMint_exactIn() public {
        EvxPool pool = _poolAB(QuoteVectors.tick0ExactIn0For1());
        assertEq(pool.liquidity(), 0);
        (address tokenIn, address tokenOut) = _dir(pool, true);
        vm.expectRevert(ZeroLiquidity.selector);
        quoter.quoteExactInputSingle(
            IQuoter.QuoteExactInputSingleParams({
                tokenIn: tokenIn, tokenOut: tokenOut, fee: FEE, amountIn: 1e18, sqrtPriceLimitX96: 0
            })
        );
    }

    function test_ac2_zeroLiquidity_noMint_exactOut() public {
        EvxPool pool = _poolAB(QuoteVectors.tick0ExactOut0For1());
        (address tokenIn, address tokenOut) = _dir(pool, true);
        vm.expectRevert(ZeroLiquidity.selector);
        quoter.quoteExactOutputSingle(
            IQuoter.QuoteExactOutputSingleParams({
                tokenIn: tokenIn, tokenOut: tokenOut, amount: 1e18, fee: FEE, sqrtPriceLimitX96: 0
            })
        );
    }

    function test_ac2b_outOfRange_is_not_zeroLiquidity() public {
        QuoteVectors.Vector memory v = QuoteVectors.outOfRangeReachable();
        EvxPool pool = _poolAB(v);
        _mint(pool, v.range.lo, v.range.hi, v.range.liquidity);
        assertEq(uint256(pool.liquidity()), 0, "current tick is out of range");

        (address tokenIn, address tokenOut) = _dir(pool, v.zeroForOne);
        (uint256 amountOut,,,) = quoter.quoteExactInputSingle(
            IQuoter.QuoteExactInputSingleParams({
                tokenIn: tokenIn, tokenOut: tokenOut, fee: FEE, amountIn: v.amountIn, sqrtPriceLimitX96: 0
            })
        );
        QuoteSwapMathRef.Result memory ref = QuoteSwapMathRef.simulate(
            v.sqrtPriceX96, v.tick, 0, v.fee, v.zeroForOne, true, v.amountIn, v.range
        );
        assertEq(amountOut, ref.amountOut);
        assertGt(amountOut, 0);
    }

    function test_ac2b_wrongDirection_is_zeroLiquidity() public {
        QuoteVectors.Vector memory v = QuoteVectors.outOfRangeReachable();
        EvxPool pool = _poolAB(v);
        _mint(pool, v.range.lo, v.range.hi, v.range.liquidity);
        (address tokenIn, address tokenOut) = _dir(pool, true); // down, away from [60,120]
        vm.expectRevert(ZeroLiquidity.selector);
        quoter.quoteExactInputSingle(
            IQuoter.QuoteExactInputSingleParams({
                tokenIn: tokenIn, tokenOut: tokenOut, fee: FEE, amountIn: 1e6, sqrtPriceLimitX96: 0
            })
        );
    }

    function test_exactOut_overquote_is_insufficientLiquidity() public {
        QuoteVectors.Vector memory v = QuoteVectors.exactInOverquoteThin();
        EvxPool pool = _poolAB(v);
        _mint(pool, v.range.lo, v.range.hi, v.range.liquidity);
        (address tokenIn, address tokenOut) = _dir(pool, v.zeroForOne);
        vm.expectRevert(InsufficientLiquidity.selector);
        quoter.quoteExactOutputSingle(
            IQuoter.QuoteExactOutputSingleParams({
                tokenIn: tokenIn, tokenOut: tokenOut, amount: 100e18, fee: FEE, sqrtPriceLimitX96: 0
            })
        );
    }

    function test_invalidRoute_missingPool() public {
        vm.expectRevert(InvalidRoute.selector);
        quoter.quoteExactInputSingle(
            IQuoter.QuoteExactInputSingleParams({
                tokenIn: address(tokenA),
                tokenOut: address(tokenB),
                fee: FEE,
                amountIn: 1e6,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function test_multiHop_twoRealPools() public {
        QuoteVectors.Vector memory v = QuoteVectors.tick0ExactIn0For1();
        EvxPool poolAB = _createPool(address(tokenA), address(tokenB), v);
        EvxPool poolBC = _createPool(address(tokenB), address(tokenC), v);
        _mint(poolAB, v.range.lo, v.range.hi, v.range.liquidity);
        _mint(poolBC, v.range.lo, v.range.hi, v.range.liquidity);

        address a = address(tokenA);
        address b = address(tokenB);
        address c = address(tokenC);

        (uint160 sqrtAB, int24 tickAB,,,,,) = poolAB.slot0();
        (uint160 sqrtBC, int24 tickBC,,,,,) = poolBC.slot0();
        uint128 lAB = poolAB.liquidity();
        uint128 lBC = poolBC.liquidity();

        QuoteSwapMathRef.Result memory hop1 = QuoteSwapMathRef.simulate(
            sqrtAB, tickAB, lAB, v.fee, a == poolAB.token0(), true, v.amountIn, v.range
        );
        QuoteSwapMathRef.Result memory hop2 = QuoteSwapMathRef.simulate(
            sqrtBC, tickBC, lBC, v.fee, b == poolBC.token0(), true, hop1.amountOut, v.range
        );

        bytes memory pathIn = abi.encodePacked(a, FEE, b, FEE, c);
        (uint256 amountOut,,,) = quoter.quoteExactInput(pathIn, v.amountIn);
        assertEq(amountOut, hop2.amountOut, "2-hop exact-in matches sequential SwapMath");

        uint256 wantOut = 1e6;
        QuoteSwapMathRef.Result memory out1 = QuoteSwapMathRef.simulate(
            sqrtBC, tickBC, lBC, v.fee, b == poolBC.token0(), false, wantOut, v.range
        );
        QuoteSwapMathRef.Result memory out0 = QuoteSwapMathRef.simulate(
            sqrtAB, tickAB, lAB, v.fee, a == poolAB.token0(), false, out1.amountIn, v.range
        );
        bytes memory pathOut = abi.encodePacked(c, FEE, b, FEE, a);
        (uint256 amountIn,,,) = quoter.quoteExactOutput(pathOut, wantOut);
        assertEq(amountIn, out0.amountIn, "2-hop exact-out matches sequential SwapMath");
    }

    function test_ac2b_farTick_beyond256Words_is_not_zeroLiquidity() public {
        // spacing 1: 256 words × 256 bits = 65_536 ticks. Range at 70_000 is past that cap
        // and still mintable (fee 500 / spacing 10 at tick 700_000 overflows mint amounts).
        factory.enableFeeAmount(100, 1);
        address poolAddr = factory.createPool(address(tokenA), address(tokenB), 100);
        EvxPool pool = EvxPool(payable(poolAddr));
        pool.initializeObservation(TickMath.getSqrtRatioAtTick(0));
        int24 lo = 70000;
        int24 hi = 70100;
        _mint(pool, lo, hi, 1e18);
        assertEq(uint256(pool.liquidity()), 0, "current tick is out of range");

        (address tokenIn, address tokenOut) = _dir(pool, false);
        (uint256 amountOut,,,) = quoter.quoteExactInputSingle(
            IQuoter.QuoteExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: 100,
                amountIn: 1e18,
                sqrtPriceLimitX96: 0
            })
        );
        assertGt(amountOut, 0, "reachable liquidity beyond 256 bitmap words");
    }

    function test_spotQuoteAtTick_divergesFromSwap() public {
        QuoteVectors.Vector memory v = QuoteVectors.tick0ExactIn0For1();
        EvxPool pool = _poolAB(v);
        _mint(pool, v.range.lo, v.range.hi, v.range.liquidity);
        (address tokenIn, address tokenOut) = _dir(pool, v.zeroForOne);
        (uint256 swapOut,,,) = quoter.quoteExactInputSingle(
            IQuoter.QuoteExactInputSingleParams({
                tokenIn: tokenIn, tokenOut: tokenOut, fee: FEE, amountIn: v.amountIn, sqrtPriceLimitX96: 0
            })
        );
        uint256 spot = OracleLibrary.getQuoteAtTick(v.tick, uint128(v.amountIn), tokenIn, tokenOut);
        assertTrue(spot != swapOut, "spot tick quote is not the swap oracle");
    }

    function _runVector(QuoteVectors.Vector memory v) internal returns (QuoteSwapMathRef.Result memory ref) {
        EvxPool pool = _poolAB(v);
        _mint(pool, v.range.lo, v.range.hi, v.range.liquidity);
        uint128 L = pool.liquidity();
        (uint160 sqrtP, int24 tick,,,,,) = pool.slot0();

        uint256 snapshot = vm.snapshotState();
        ref = QuoteSwapMathRef.simulate(sqrtP, tick, L, v.fee, v.zeroForOne, v.exactIn, _input(v), v.range);
        emit log_string(v.id);
        emit log_named_uint("ref.amountIn", ref.amountIn);
        emit log_named_uint("ref.amountOut", ref.amountOut);
        emit log_named_uint("ref.fee", ref.feePaid);
        emit log_named_int("ref.tick", tick);
        emit log_named_int("ref.tickAfter", ref.tick);
        emit log_named_uint("ref.sqrtAfter", ref.sqrtPriceX96);
        emit log_named_uint("ref.LAfter", ref.liquidity);

        vm.revertToState(snapshot);
        snapshot = vm.snapshotState();
        (address tokenIn, address tokenOut) = _dir(pool, v.zeroForOne);
        uint256 quoted;
        if (v.exactIn) {
            (quoted,,,) = quoter.quoteExactInputSingle(
                IQuoter.QuoteExactInputSingleParams({
                    tokenIn: tokenIn, tokenOut: tokenOut, fee: FEE, amountIn: v.amountIn, sqrtPriceLimitX96: 0
                })
            );
            _assertClose(quoted, ref.amountOut, v.toleranceWei, "quoter amountOut");
        } else {
            (quoted,,,) = quoter.quoteExactOutputSingle(
                IQuoter.QuoteExactOutputSingleParams({
                    tokenIn: tokenIn, tokenOut: tokenOut, amount: v.amountOut, fee: FEE, sqrtPriceLimitX96: 0
                })
            );
            _assertClose(quoted, ref.amountIn, v.toleranceWei, "quoter amountIn");
        }

        vm.revertToState(snapshot);
        _paySwap(pool, v.zeroForOne, v.exactIn, _input(v));
        uint256 swapIn = lastAmount0 > 0 ? uint256(lastAmount0) : uint256(lastAmount1);
        uint256 swapOut = lastAmount0 < 0 ? uint256(-lastAmount0) : uint256(-lastAmount1);
        _assertClose(swapIn, ref.amountIn, v.toleranceWei, "swap amountIn");
        _assertClose(swapOut, ref.amountOut, v.toleranceWei, "swap amountOut");

        if (v.hasExpectedState) {
            (uint160 sqrtAfter, int24 tickAfter,,,,,) = pool.slot0();
            assertEq(uint256(sqrtAfter), uint256(ref.sqrtPriceX96), "state sqrt");
            assertEq(tickAfter, ref.tick, "state tick");
            assertEq(uint256(pool.liquidity()), uint256(ref.liquidity), "state L");
            if (v.committed) {
                assertEq(uint256(ref.sqrtPriceX96), uint256(v.expectedSqrtPriceX96), "fixture sqrt");
                assertEq(ref.tick, v.expectedTick, "fixture tick");
                assertEq(uint256(ref.liquidity), uint256(v.expectedLiquidity), "fixture L");
            }
        }

        if (v.committed) {
            _assertClose(ref.amountIn, v.expectedAmountIn, v.toleranceWei, "fixture amountIn");
            _assertClose(ref.amountOut, v.expectedAmountOut, v.toleranceWei, "fixture amountOut");
            if (v.expectedFee != 0) {
                _assertClose(ref.feePaid, v.expectedFee, v.toleranceWei, "fixture fee");
            }
        }
    }

    function _input(QuoteVectors.Vector memory v) internal pure returns (uint256) {
        return v.exactIn ? v.amountIn : v.amountOut;
    }

    function _assertClose(uint256 a, uint256 b, uint256 tol, string memory label) internal pure {
        if (a > b) require(a - b <= tol, label);
        else require(b - a <= tol, label);
    }

    function _poolAB(QuoteVectors.Vector memory v) internal returns (EvxPool) {
        return _createPool(address(tokenA), address(tokenB), v);
    }

    function _createPool(address tA, address tB, QuoteVectors.Vector memory v) internal returns (EvxPool pool) {
        address poolAddr = factory.createPool(tA, tB, v.fee);
        pool = EvxPool(payable(poolAddr));
        pool.initializeObservation(v.sqrtPriceX96);
    }

    function _dir(EvxPool pool, bool zeroForOne) internal view returns (address tokenIn, address tokenOut) {
        if (zeroForOne) return (pool.token0(), pool.token1());
        return (pool.token1(), pool.token0());
    }

    function _mint(EvxPool pool, int24 lo, int24 hi, uint128 liq) internal {
        OracleToken(pool.token0()).mint(address(this), type(uint128).max);
        OracleToken(pool.token1()).mint(address(this), type(uint128).max);
        pool.mint(address(this), lo, hi, liq, "");
    }

    function _paySwap(EvxPool pool, bool zeroForOne, bool exactIn, uint256 amount) internal {
        OracleToken(pool.token0()).mint(address(this), type(uint128).max);
        OracleToken(pool.token1()).mint(address(this), type(uint128).max);
        int256 specified = exactIn ? int256(amount) : -int256(amount);
        uint160 limit = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
        pool.swap(address(this), zeroForOne, specified, limit, "");
    }
}

contract OracleToken is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
