// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EvxFactory} from "@evx-core/contracts/EvxFactory.sol";
import {EvxPool} from "@evx-core/contracts/EvxPool.sol";
import {TickMath} from "@evx-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "@evx-core/libraries/SqrtPriceMath.sol";
import {LowGasSafeMath} from "@evx-core/libraries/LowGasSafeMath.sol";
import {IEvxMintCallback} from "@evx-core/interfaces/callback/IEvxMintCallback.sol";
import {IEvxPool} from "@evx-core/interfaces/IEvxPool.sol";
import {Quoter} from "@evx-periphery/contracts/lens/Quoter.sol";
import {IQuoter} from "@evx-periphery/interfaces/IQuoter.sol";
import {PoolQuoteFailed} from "@evx-periphery/libraries/QuoterErrors.sol";
import {InsufficientLiquidity} from "@evx-periphery/libraries/QuoterErrors.sol";
import {ZeroLiquidity} from "@evx-periphery/libraries/QuoterErrors.sol";
import {InvalidRoute} from "@evx-periphery/libraries/QuoterErrors.sol";
import {OutputAmountMismatch} from "@evx-periphery/libraries/QuoterErrors.sol";

/**
 * @title QuoterPanicCapture
 * @notice Task 0B: hunt PoolQuoteFailed(Panic(0x11)) against a REAL EvxPool + Quoter.
 * @dev Not a MockPoolPanic fixture. Logs raw revert for RCA classification.
 */
contract QuoterPanicCaptureTest is Test {
    uint24 constant FEE = 3000;
    address constant WETH9 = address(0xC0FFEE);

    EvxFactory factory;
    EvxPool pool;
    Quoter quoter;
    MockERC20 tokenA;
    MockERC20 tokenB;
    MintCb mintCb;

    address token0;
    address token1;

    bytes4 constant PANIC_SEL = bytes4(0x4e487b71);
    bytes4 constant POOL_QUOTE_FAILED = PoolQuoteFailed.selector;

    function setUp() public {
        EvxPool impl = new EvxPool();
        factory = new EvxFactory(address(impl));
        tokenA = new MockERC20("A", "A");
        tokenB = new MockERC20("B", "B");

        // periphery lib/evx-core uses createPool(tokenA, tokenB, fee)
        address poolAddr = factory.createPool(address(tokenA), address(tokenB), FEE);
        pool = EvxPool(payable(poolAddr));
        pool.initializeObservation(TickMath.getSqrtRatioAtTick(0));

        token0 = pool.token0();
        token1 = pool.token1();

        mintCb = new MintCb(ERC20(token0), ERC20(token1));
        quoter = new Quoter(address(factory), WETH9);
    }

    function _mintLiquidity(uint128 liq, int24 tickLower, int24 tickUpper) internal {
        MockERC20(token0).mint(address(mintCb), type(uint128).max);
        MockERC20(token1).mint(address(mintCb), type(uint128).max);
        vm.prank(address(mintCb));
        pool.mint(address(this), tickLower, tickUpper, liq, "");
    }

    function _quoteExactIn(uint256 amountIn) internal returns (bytes memory reason) {
        try quoter.quoteExactInputSingle(
            IQuoter.QuoteExactInputSingleParams({
                tokenIn: token0,
                tokenOut: token1,
                fee: FEE,
                amountIn: amountIn,
                sqrtPriceLimitX96: 0
            })
        ) returns (uint256 amountOut, uint160, uint32, uint256) {
            emit log_named_uint("quote_ok_amountOut", amountOut);
            return bytes("");
        } catch (bytes memory data) {
            return data;
        }
    }

    function _quoteExactOut(uint256 amountOut) internal returns (bytes memory reason) {
        try quoter.quoteExactOutputSingle(
            IQuoter.QuoteExactOutputSingleParams({
                tokenIn: token0,
                tokenOut: token1,
                amount: amountOut,
                fee: FEE,
                sqrtPriceLimitX96: 0
            })
        ) returns (uint256 amountIn, uint160, uint32, uint256) {
            emit log_named_uint("quote_ok_amountIn", amountIn);
            return bytes("");
        } catch (bytes memory data) {
            return data;
        }
    }

    function _classify(bytes memory reason) internal returns (string memory label, bool isPanic11) {
        if (reason.length == 0) return ("success", false);
        bytes4 sel;
        assembly {
            sel := mload(add(reason, 0x20))
        }
        emit log_named_bytes32("revert_selector", bytes32(sel));
        emit log_named_uint("revert_len", reason.length);
        emit log_named_bytes("raw_revert", reason);

        if (sel == InsufficientLiquidity.selector) return ("InsufficientLiquidity", false);
        if (sel == ZeroLiquidity.selector) return ("ZeroLiquidity", false);
        if (sel == InvalidRoute.selector) return ("InvalidRoute", false);
        if (sel == OutputAmountMismatch.selector) return ("OutputAmountMismatch", false);
        if (sel == POOL_QUOTE_FAILED) {
            // abi.encodeWithSelector(PoolQuoteFailed.selector, bytes reason)
            // decode inner: skip 4 + 32 offset + 32 length
            (bytes memory inner) = abi.decode(_slice(reason, 4), (bytes));
            emit log_named_bytes("PoolQuoteFailed_inner", inner);
            if (inner.length >= 4) {
                bytes4 innerSel;
                assembly {
                    innerSel := mload(add(inner, 0x20))
                }
                emit log_named_bytes32("inner_selector", bytes32(innerSel));
                if (innerSel == PANIC_SEL && inner.length >= 36) {
                    uint256 code;
                    assembly {
                        code := mload(add(inner, 0x24))
                    }
                    emit log_named_uint("panic_code", code);
                    if (code == 0x11) return ("PoolQuoteFailed(Panic(0x11))", true);
                    return ("PoolQuoteFailed(Panic(other))", false);
                }
            }
            return ("PoolQuoteFailed(other)", false);
        }
        if (sel == PANIC_SEL) {
            if (reason.length >= 36) {
                uint256 code;
                assembly {
                    code := mload(add(reason, 0x24))
                }
                emit log_named_uint("panic_code", code);
                if (code == 0x11) return ("raw_Panic", true);
            }
            return ("raw_Panic(other)", false);
        }
        return ("other", false);
    }

    function _slice(bytes memory data, uint256 start) internal pure returns (bytes memory out) {
        require(data.length > start, "slice");
        out = new bytes(data.length - start);
        for (uint256 i = 0; i < out.length; i++) {
            out[i] = data[start + i];
        }
    }

    /// @notice Thin in-range L + huge exact-in (anvil proxy scenario)
    function test_0B_thinLiquidity_exactIn_overquote() public {
        _mintLiquidity(1e12, -60, 60);
        bytes memory reason = _quoteExactIn(100e18);
        (string memory label, bool panic11) = _classify(reason);
        emit log_string(string.concat("CLASSIFICATION=", label));
        // Do not invent AD-26: record outcome for RCA
        if (panic11) {
            emit log("CAPTURED: PoolQuoteFailed(Panic(0x11)) against real EvxPool");
        }
    }

    /// @notice Zero in-range liquidity (initialized pool, no mint)
    function test_0B_zeroLiquidity_exactIn() public {
        bytes memory reason = _quoteExactIn(1e18);
        (string memory label, bool panic11) = _classify(reason);
        emit log_string(string.concat("CLASSIFICATION=", label));
        if (panic11) emit log("CAPTURED Panic against zero-L pool");
    }

    /// @notice Exact-out larger than pool can deliver with thin L
    function test_0B_thinLiquidity_exactOut_overquote() public {
        _mintLiquidity(1e12, -60, 60);
        bytes memory reason = _quoteExactOut(100e18);
        (string memory label, bool panic11) = _classify(reason);
        emit log_string(string.concat("CLASSIFICATION=", label));
        if (panic11) emit log("CAPTURED Panic on exactOut overquote");
    }

    /// @notice Extreme amount near uint128 boundary on tiny L
    function test_0B_tinyL_extremeAmount() public {
        _mintLiquidity(1, -60, 60);
        bytes memory reason = _quoteExactIn(type(uint128).max);
        (string memory label, bool panic11) = _classify(reason);
        emit log_string(string.concat("CLASSIFICATION=", label));
        if (panic11) emit log("CAPTURED Panic on extreme amount");
    }

    /// @notice Sweep amounts looking for Panic(0x11) with fixed thin L
    function test_0B_sweep_find_panic() public {
        _mintLiquidity(1e6, -120, 120);
        uint256[8] memory amounts = [
            uint256(1),
            1e6,
            1e12,
            1e15,
            1e18,
            1e24,
            1e30,
            type(uint128).max
        ];
        uint256 hits;
        for (uint256 i = 0; i < amounts.length; i++) {
            bytes memory reason = _quoteExactIn(amounts[i]);
            (string memory label, bool panic11) = _classify(reason);
            emit log_named_uint("amountIn", amounts[i]);
            emit log_string(string.concat("  -> ", label));
            if (panic11) hits++;
        }
        emit log_named_uint("panic11_hits", hits);
    }

    /**
     * @notice Direct lib: Solidity 0.8 checked mul in SqrtPriceMath (0.7-port pattern).
     * @dev Uniswap V3 relied on wrap-on-overflow; without unchecked, overflow → Panic(0x11).
     */
    function test_0B_lib_SqrtPriceMath_overflow_is_Panic11() public {
        SqrtPriceMathHarness h = new SqrtPriceMathHarness();
        uint160 sqrtP = TickMath.MAX_SQRT_RATIO - 1;
        uint128 liq = 1e18;
        // amount * sqrtP overflows uint256
        uint256 amount = type(uint256).max / uint256(sqrtP) + 1;

        try h.nextSqrtPriceAmount0Add(sqrtP, liq, amount) {
            emit log("UNEXPECTED: SqrtPriceMath did not revert");
        } catch (bytes memory data) {
            (string memory label, bool panic11) = _classify(data);
            emit log_string(string.concat("CLASSIFICATION=", label));
            assertTrue(panic11, "expected Panic(0x11) from checked mul overflow");
        }
    }

    /// @notice Direct lib: LowGasSafeMath.add overflows → Panic(0x11) under 0.8
    function test_0B_lib_LowGasSafeMath_add_is_Panic11() public {
        LowGasSafeMathHarness h = new LowGasSafeMathHarness();
        try h.add(type(uint256).max, 1) {
            emit log("UNEXPECTED: LowGasSafeMath.add did not revert");
        } catch (bytes memory data) {
            (string memory label, bool panic11) = _classify(data);
            emit log_string(string.concat("CLASSIFICATION=", label));
            assertTrue(panic11, "expected Panic(0x11) from LowGasSafeMath.add");
        }
    }

    /**
     * @notice Quoter path: pool near MAX price + huge exact-in token0 (zeroForOne).
     * @dev Tries to surface the SqrtPriceMath checked-mul Panic through real EvxPool+Quoter.
     */
    function test_0B_extremePrice_hugeExactIn() public {
        MockERC20 a = new MockERC20("X", "X");
        MockERC20 b = new MockERC20("Y", "Y");
        address poolAddr = factory.createPool(address(a), address(b), FEE);
        EvxPool extreme = EvxPool(payable(poolAddr));

        int24 spacing = 60;
        int24 tick = ((TickMath.MAX_TICK / spacing) * spacing) - (spacing * 10);
        extreme.initializeObservation(TickMath.getSqrtRatioAtTick(tick));

        address t0 = extreme.token0();
        address t1 = extreme.token1();
        MintCb cb = new MintCb(ERC20(t0), ERC20(t1));
        MockERC20(t0).mint(address(cb), type(uint128).max);
        MockERC20(t1).mint(address(cb), type(uint128).max);
        vm.prank(address(cb));
        extreme.mint(address(this), tick - spacing * 2, tick + spacing * 2, 1e12, "");

        Quoter q = new Quoter(address(factory), WETH9);
        uint160 sqrtP = TickMath.getSqrtRatioAtTick(tick);
        uint256 overflowFloor = type(uint256).max / uint256(sqrtP) + 1;
        emit log_named_uint("sqrtP", sqrtP);
        emit log_named_uint("overflowFloor", overflowFloor);

        // Prefer amount that overflows amount*sqrtP; clamp to uint128 if quote ABI uses that path via pool
        uint256 amountIn = overflowFloor < type(uint128).max ? overflowFloor : type(uint128).max;
        if (amountIn < overflowFloor) {
            // at this price uint128.max already overflows product
            emit log("uint128.max already past overflowFloor");
            amountIn = type(uint128).max;
        }

        try q.quoteExactInputSingle(
            IQuoter.QuoteExactInputSingleParams({
                tokenIn: t0,
                tokenOut: t1,
                fee: FEE,
                amountIn: amountIn,
                sqrtPriceLimitX96: 0
            })
        ) returns (uint256 amountOut, uint160, uint32, uint256) {
            emit log_named_uint("quote_ok_amountOut", amountOut);
            emit log_string("CLASSIFICATION=success");
        } catch (bytes memory data) {
            (string memory label, bool panic11) = _classify(data);
            emit log_string(string.concat("CLASSIFICATION=", label));
            if (panic11) emit log("CAPTURED: Panic via extreme price Quoter path");
            assertTrue(panic11, "expected PoolQuoteFailed(Panic(0x11)) via SqrtPriceMath checked mul");
        }
    }

    /// @notice Extreme price + amounts past overflowFloor for amount*sqrtP
    function test_0B_extremePrice_overflowSweep() public {
        MockERC20 a = new MockERC20("X2", "X2");
        MockERC20 b = new MockERC20("Y2", "Y2");
        address poolAddr = factory.createPool(address(a), address(b), FEE);
        EvxPool extreme = EvxPool(payable(poolAddr));

        int24 spacing = 60;
        int24 tick = ((TickMath.MAX_TICK / spacing) * spacing) - (spacing * 10);
        uint160 sqrtP = TickMath.getSqrtRatioAtTick(tick);
        extreme.initializeObservation(sqrtP);

        address t0 = extreme.token0();
        address t1 = extreme.token1();
        MintCb cb = new MintCb(ERC20(t0), ERC20(t1));
        MockERC20(t0).mint(address(cb), type(uint128).max);
        MockERC20(t1).mint(address(cb), type(uint128).max);
        vm.prank(address(cb));
        extreme.mint(address(this), tick - spacing * 4, tick + spacing * 4, 1e18, "");

        Quoter q = new Quoter(address(factory), WETH9);
        uint256 overflowFloor = type(uint256).max / uint256(sqrtP) + 1;
        emit log_named_uint("overflowFloor", overflowFloor);

        uint256[4] memory amounts = [
            overflowFloor,
            type(uint128).max,
            type(uint256).max / 2,
            type(uint256).max
        ];

        uint256 hits;
        for (uint256 i = 0; i < amounts.length; i++) {
            try q.quoteExactInputSingle(
                IQuoter.QuoteExactInputSingleParams({
                    tokenIn: t0,
                    tokenOut: t1,
                    fee: FEE,
                    amountIn: amounts[i],
                    sqrtPriceLimitX96: 0
                })
            ) returns (uint256 amountOut, uint160, uint32, uint256) {
                emit log_named_uint("amountIn", amounts[i]);
                emit log_named_uint("quote_ok_amountOut", amountOut);
                emit log_string("  -> success");
            } catch (bytes memory data) {
                (string memory label, bool panic11) = _classify(data);
                emit log_named_uint("amountIn", amounts[i]);
                emit log_string(string.concat("  -> ", label));
                if (panic11) hits++;
            }
        }
        emit log_named_uint("panic11_hits", hits);
        assertGe(hits, 1, "expected at least one Panic(0x11) hit on overflow amounts");
    }
}

/// @dev Exposes SqrtPriceMath for Panic capture (library internal).
contract SqrtPriceMathHarness {
    function nextSqrtPriceAmount0Add(uint160 sqrtP, uint128 liq, uint256 amount)
        external
        pure
        returns (uint160)
    {
        return SqrtPriceMath.getNextSqrtPriceFromAmount0RoundingUp(sqrtP, liq, amount, true);
    }
}

contract LowGasSafeMathHarness {
    function add(uint256 x, uint256 y) external pure returns (uint256) {
        return LowGasSafeMath.add(x, y);
    }
}

contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MintCb is IEvxMintCallback {
    ERC20 private t0;
    ERC20 private t1;
    constructor(ERC20 a, ERC20 b) {
        t0 = a;
        t1 = b;
    }
    function evxMintCallback(uint256 amount0, uint256 amount1, bytes calldata) external override {
        require(t0.transfer(msg.sender, amount0), "m0");
        require(t1.transfer(msg.sender, amount1), "m1");
    }
}
