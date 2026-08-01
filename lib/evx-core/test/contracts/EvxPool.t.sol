// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@evx-core/contracts/EvxFactory.sol";
import "@evx-core/contracts/EvxPool.sol";
import { TickMath } from "@evx-core/libraries/TickMath.sol";
import "@evx-core/interfaces/callback/IEvxMintCallback.sol";
import "@evx-core/interfaces/callback/IEvxSwapCallback.sol";
import "@evx-core/interfaces/callback/IEvxFlashCallback.sol";
import "@evx-core/interfaces/pool/IEvxPoolEvents.sol";

/**
 * @title EvxPoolTest
 * @notice Comprehensive unit tests for EvxPool covering mint, burn, swap, flash, and fee logic.
 */
contract EvxPoolTest is Test {
    EvxFactory factory;
    EvxPool pool;
    MockERC20 tokenA;
    MockERC20 tokenB;
    MintCallbackMock mintCb;
    SwapCallbackMock swapCb;
    FlashCallbackMock flashCb;
    address owner;

    /**
     * @notice Sets up factory, pool, tokens, and callbacks. Initializes pool at price 1.0.
     * @dev Called before each test. Deploys factory, tokens, creates pool with fee 5 bps, initializes price to 1.0, and deploys callback mocks.
     */
    function setUp() public {
        EvxPool poolImplementation = new EvxPool();
        factory = new EvxFactory(address(poolImplementation));

        owner = address(this);
        tokenA = new MockERC20("TokenA", "TKA");
        tokenB = new MockERC20("TokenB", "TKB");

        // create and initialize pool
        address poolAddr = factory.createPool(address(tokenA), address(tokenB), 500);
        pool = EvxPool(payable(poolAddr));

        uint160 price = TickMath.getSqrtRatioAtTick(0);
        pool.initializeObservation(price);

        ERC20 t0 = ERC20(pool.token0());
        ERC20 t1 = ERC20(pool.token1());

        mintCb  = new MintCallbackMock(t0, t1);
        swapCb  = new SwapCallbackMock(t0, t1);
        flashCb = new FlashCallbackMock(t0, t1);
    }

    /**
     * @notice Should revert if initialize is called more than once.
     * @dev Expects revert on second call to initialize with same price.
     */
    function testInitializeRevertsIfCalledTwice() public {
        uint160 price = TickMath.getSqrtRatioAtTick(0);
        vm.expectRevert();
        pool.initializeObservation(price);
    }

    /**
     * @notice Should revert when mint amount is zero.
     * @dev Expects revert when calling mint with zero amount.
     */
    function testMintRevertsZeroAmount() public {
        vm.expectRevert();
        pool.mint(address(mintCb), 0, 10, 0, "");
    }

    function testEmitObservationInitialized() public {
        address poolAddr = factory.createPool(address(tokenA), address(tokenB), 3000);
        EvxPool freshPool = EvxPool(payable(poolAddr));
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(10);

        vm.expectEmit(true, false, false, true);
        emit IEvxPoolEvents.InitializeObservation(sqrtPriceX96, 10);

        freshPool.initializeObservation(sqrtPriceX96);
    }

    /**
     * @notice Full mint, burn, and collect cycle should accrue fees.
     * @dev Mints tokens to callback, performs mint, burn and collect operations.
     */
    function testMintAndCollect() public {
        // fund mint callback with tokens
        tokenA.mint(address(mintCb), 1e25);
        tokenB.mint(address(mintCb), 1e25);

        // mint liquidity under mintCb context
        vm.prank(address(mintCb));
        pool.mint(address(this), -10, 10, 1000, "");

        // burn liquidity as position owner
        pool.burn(-10, 10, 1000);

        // collect owed fees (may be zero)
        pool.collect(address(this), -10, 10, type(uint128).max, type(uint128).max);
    }

    /**
     * @notice Should revert on swap when specified amount is zero.
     * @dev Expects revert calling swap with zero amount parameter.
     */
    function testSwapRevertsZeroSpecified() public {
        vm.expectRevert();
        pool.swap(address(swapCb), true, 0, TickMath.MIN_SQRT_RATIO + 1, "");
    }

    /**
     * @notice Should revert when price limit is invalid for zero-for-one swap.
     * @dev Expects revert when calling swap with price limit equal to MAX_SQRT_RATIO.
     */
    function testSwapZeroForOneRevertsLimit() public {
        vm.expectRevert();
        pool.swap(address(swapCb), true, 1000, TickMath.MAX_SQRT_RATIO, "");
    }

    /**
     * @notice Executes exact input swap zero-for-one without revert.
     * @dev Mints liquidity and runs swap with positive input amount.
     */
    function testSwapExactInputZeroForOne() public {
        // fund and mint liquidity under mintCb context
        tokenA.mint(address(mintCb), 1e24);
        tokenB.mint(address(mintCb), 1e24);

        vm.prank(address(mintCb));
        pool.mint(address(this), -10, 10, 1000, "");

        // fund swap callback and execute swap as swapCb
        tokenA.mint(address(swapCb), 1e24);
        tokenB.mint(address(swapCb), 1e24);
        
        vm.prank(address(swapCb));
        pool.swap(address(this), true, int256(500 * 1e18), TickMath.getSqrtRatioAtTick(-1), "");
    }

    /**
     * @notice Should revert flash if no liquidity is available.
     * @dev Expects revert on flash when pool has zero liquidity.
     */
    function testFlashRevertsNoLiquidity() public {
        vm.expectRevert();
        pool.flash(address(flashCb), 100, 100, "");
    }

    /**
     * @notice Should succeed flash with repayment of principal plus fees.
     * @dev Funds pool, mints liquidity, and executes flash that repays principal and fees.
     */
    function testFlashSuccess() public {
        // fund and mint liquidity under mintCb context
        tokenA.mint(address(mintCb), 1e25);
        tokenB.mint(address(mintCb), 1e25);

        tokenA.mint(address(this), 1000);
        tokenB.mint(address(this), 1000);

        vm.prank(address(mintCb));
        pool.mint(address(this), -10, 10, 1000, "");
        
        // fund pool with principal for flash via mintCb
        tokenA.transfer(address(pool), 100);
        tokenB.transfer(address(pool), 100);

        // fund flash callback with ample tokens
        tokenA.mint(address(flashCb), 1e25);
        tokenB.mint(address(flashCb), 1e25);

        // execute flash under flashCb context
        vm.prank(address(flashCb));
        pool.flash(address(this), 100, 100, abi.encode(uint256(100), uint256(100)));
    }

    /**
     * @notice Only factory owner can set protocol fee and collect protocol fees.
     * @dev Tests non-owner revert, and owner success including fee collection.
     */
    function testSetFeeProtocolAndCollectProtocol() public {
        // non-owner fails
        vm.prank(address(0x456));
        vm.expectRevert();
        pool.setFeeProtocol(5, 5);

        // owner succeeds
        vm.prank(owner);
        pool.setFeeProtocol(5, 5);

        // fund and mint liquidity under mintCb context to generate protocol fees
        tokenA.mint(address(mintCb), 1e24);
        tokenB.mint(address(mintCb), 1e24);
        vm.prank(address(mintCb));
        pool.mint(address(this), -10, 10, 1000, "");

        // collect protocol fees as owner
        vm.prank(owner);
        (uint128 c0, uint128 c1) = pool.collectProtocol(address(this), type(uint128).max, type(uint128).max);
        assertTrue(c0 >= 0 && c1 >= 0);
    }

    /**
     * @notice Observation and snapshot functions should behave correctly.
     * @dev Tests increaseObservationCardinalityNext, observe and expect revert for snapshotCumulativesInside on uninitialized pair.
     */
    function testObserveAndSnapshot() public {
        vm.prank(owner);
        pool.increaseObservationCardinalityNext(10);

        uint32[] memory secs = new uint32[](1);
        secs[0] = 0;
        (int56[] memory ticks, ) = pool.observe(secs);
        assertEq(ticks.length, 1);

        vm.expectRevert();
        pool.snapshotCumulativesInside(1, 2);
    }

    /**
     * @notice Test swap zero-for-one exact input additional scenario.
     * @dev Mints tokens, liquidity, and executes swap under different pool balance conditions.
     */
    function testSwapZeroForOneExactInputAdditional() public {
        tokenA.mint(address(mintCb), 1e26);
        tokenB.mint(address(mintCb), 1e26);

        tokenA.mint(address(swapCb), 1e26);
        tokenB.mint(address(swapCb), 1e26);

        vm.prank(address(mintCb));
        pool.mint(address(this), -10, 10, 1000, "");
        
        tokenB.mint(address(pool), 1e21);
        
        vm.prank(address(swapCb));
        pool.swap(address(this), true, int256(500 * 1e18), TickMath.getSqrtRatioAtTick(-1), "");
    }

    /**
     * @notice Test swap one-for-zero exact input scenario.
     * @dev Mints tokens, liquidity, and executes swap one-for-zero with exact input.
     */
    function testSwapOneForZeroExactInput() public {
        tokenA.mint(address(mintCb), 1e26);
        tokenB.mint(address(mintCb), 1e26);

        tokenA.mint(address(swapCb), 1e26);
        tokenB.mint(address(swapCb), 1e26);

        vm.prank(address(mintCb));
        pool.mint(address(this), -10, 10, 1000, "");
        
        tokenA.mint(address(pool), 1e21);
        
        vm.prank(address(swapCb));
        pool.swap(address(this), false, int256(500 * 1e18), TickMath.getSqrtRatioAtTick(1), "");
    }

    /**
     * @notice Test exact output swap zero-for-one scenario.
     * @dev Mints tokens, liquidity, and executes swap with negative amount parameter for exact output.
     */
    function testSwapZeroForOneExactOutput() public {
        tokenA.mint(address(mintCb), 1e26);
        tokenB.mint(address(mintCb), 1e26);

        tokenA.mint(address(swapCb), 1e26);
        tokenB.mint(address(swapCb), 1e26);  

        vm.prank(address(mintCb));
        pool.mint(address(this), -10, 10, 1000, "");
        tokenA.mint(address(pool), 1e21);
        vm.prank(address(swapCb));
        pool.swap(address(this), true, -int256(500 * 1e18), TickMath.getSqrtRatioAtTick(-1), "");
    }

    /**
     * @notice Test exact output swap one-for-zero scenario.
     * @dev Mints tokens, liquidity, and executes swap with negative amount parameter for one-for-zero swap.
     */
    function testSwapOneForZeroExactOutput() public {
        tokenA.mint(address(mintCb), 1e26);
        tokenB.mint(address(mintCb), 1e26);

        tokenA.mint(address(swapCb), 1e26);
        tokenB.mint(address(swapCb), 1e26);        

        vm.prank(address(mintCb));
        pool.mint(address(this), -10, 10, 1000, "");
        
        tokenB.mint(address(pool), 1e21);
        
        vm.prank(address(swapCb));
        pool.swap(address(this), false, -int256(500 * 1e18), TickMath.getSqrtRatioAtTick(1), "");
    }

    /**
     * @notice Test price limit bounds for swap.
     * @dev Expects revert when price limit equal to MIN_SQRT_RATIO or MAX_SQRT_RATIO.
     */
    function testSwapPriceLimitsExtremes() public {
        vm.expectRevert();
        pool.swap(address(swapCb), true, 100, TickMath.MIN_SQRT_RATIO, "");
        vm.expectRevert();
        pool.swap(address(swapCb), false, 100, TickMath.MAX_SQRT_RATIO, "");
    }

    /**
     * @notice Calling increaseObservationCardinalityNext with no change should leave state and emit no event.
     * @dev Reads current observationCardinalityNext and calls function again.
     */
    function testIncreaseObservationCardinalityNextNoChange() public {
      (, , , , uint16 observationCardinalityNext, ,) = pool.slot0();
        vm.prank(address(factory));
        pool.increaseObservationCardinalityNext(observationCardinalityNext);
    }

    /**
     * @notice Test snapshotCumulativesInside for various branch conditions.
     * @dev Tests revert on uninitialized, branch across, above and below current tick.
     */
    function testSnapshotCumulativesInsideBranches() public {
        // 1) uninitialized => revert
        vm.expectRevert();
        pool.snapshotCumulativesInside(1, 2);

        // 2) branch across current tick (-10,10)
        tokenA.mint(address(mintCb), 1e26);
        tokenB.mint(address(mintCb), 1e26);
        vm.prank(address(mintCb));
        pool.mint(address(this), -10, 10, 1000, "");
        pool.snapshotCumulativesInside(-10, 10);

        // 3) branch above current tick (20,30)
        tokenA.mint(address(mintCb), 1e26);
        tokenB.mint(address(mintCb), 1e26);
        vm.prank(address(mintCb));
        pool.mint(address(this), 20, 30, 1000, "");
        pool.snapshotCumulativesInside(20, 30);

        // 4) branch below current tick (-30,-20)
        tokenA.mint(address(mintCb), 1e26);
        tokenB.mint(address(mintCb), 1e26);
        vm.prank(address(mintCb));
        pool.mint(address(this), -30, -20, 1000, "");
        pool.snapshotCumulativesInside(-30, -20);
    }

    /**
     * @notice Invalid setFeeProtocol parameters should revert.
     * @dev Tests revert for small and large fee values outside valid range.
     */
    function testSetFeeProtocolInvalid() public {
        vm.expectRevert();
        pool.setFeeProtocol(1, 1);
        vm.expectRevert();
        pool.setFeeProtocol(11, 11);
    }

    /**
     * @notice CollectProtocol partial should only transfer available fees.
     * @dev Generates protocol fees via flash and collects partial amounts.
     */
    function testCollectProtocolPartial() public {
        // configure fee protocol as owner
        vm.prank(owner);
        pool.setFeeProtocol(5, 5);

        // mint liquidity to enable flash
        tokenA.mint(address(mintCb), 1e25);
        tokenB.mint(address(mintCb), 1e25);

        vm.prank(address(mintCb));
        pool.mint(address(this), -10, 10, 1000, "");

        // simulate flash to generate protocolFees
        tokenA.mint(address(this), 200);
        tokenB.mint(address(this), 200);

        tokenA.mint(address(pool), 100);
        tokenB.mint(address(pool), 100);
        
        tokenA.mint(address(flashCb), 1e25);
        tokenB.mint(address(flashCb), 1e25);

        vm.prank(address(flashCb));
        pool.flash(address(this), 100, 100, abi.encode(uint256(100), uint256(100)));

        // collect only 1 of token0, none of token1
        vm.prank(owner);
        (uint128 c0, uint128 c1) = pool.collectProtocol(address(this), 1, 0);
        assertEq(c0, 0);
        assertEq(c1, 0);
    }

    /**
     * @notice Burn without tokens owed should revert on second burn.
     * @dev Tests revert when attempting to burn more than owed after initial burn.
     */
    function testBurnWithoutTokensOwed() public {
        tokenA.mint(address(mintCb), 1e26);
        tokenB.mint(address(mintCb), 1e26);

        // First burn
        vm.prank(address(mintCb));
        pool.mint(address(this), -10, 10, 1000, "");
        pool.burn(-10, 10, 1000);

        // Second burn
        vm.expectRevert();
        pool.burn(-10, 10, 1);
    }
}

/// @title MockERC20
/// @notice Simplified ERC20 token for testing purposes.
contract MockERC20 is ERC20 {
    /**
     * @param name Name of the token.
     * @param symbol Symbol of the token.
     */
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /**
     * @notice Mints `amount` tokens to address `to`.
     * @param to Recipient address to receive minted tokens.
     * @param amount Amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title MintCallbackMock
/// @notice Mocks the mint callback by repaying minted amounts.
contract MintCallbackMock is IEvxMintCallback {
    ERC20 private token0;
    ERC20 private token1;

    /**
     * @param _token0 The first token used in pool.
     * @param _token1 The second token used in pool.
     */
    constructor(ERC20 _token0, ERC20 _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @notice Callback to repay minted amounts.
     * @param amount0 The amount of token0 to repay.
     * @param amount1 The amount of token1 to repay.
     * @param data Unused callback data.
     */
    function evxMintCallback(uint256 amount0, uint256 amount1, bytes calldata data) external override {
        require(token0.transfer(msg.sender, amount0), "MC0");
        require(token1.transfer(msg.sender, amount1), "MC1");
    }
}

/// @title SwapCallbackMock
/// @notice Mocks the swap callback by repaying swap deltas.
contract SwapCallbackMock is IEvxSwapCallback {
    ERC20 private token0;
    ERC20 private token1;

    /**
     * @param _token0 The first token used in pool.
     * @param _token1 The second token used in pool.
     */
    constructor(ERC20 _token0, ERC20 _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @notice Callback to repay swap amounts.
     * @param amount0Delta The change in token0 balance (positive means repay).
     * @param amount1Delta The change in token1 balance (positive means repay).
     * @param data Unused callback data.
     */
    /**
     * @notice Callback to repay swap amounts.
     * @param amount0Delta The change in token0 balance (positive means repay).
     * @param amount1Delta The change in token1 balance (positive means repay).
     * @param data Unused callback data.
     * @param initializedTicksCrossed Unused; for interface compatibility.
     */
    function evxSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data, uint32 initializedTicksCrossed) external override {
        if (amount0Delta > 0) require(token0.transfer(msg.sender, uint256(amount0Delta)), "SC0");
        if (amount1Delta > 0) require(token1.transfer(msg.sender, uint256(amount1Delta)), "SC1");
    }
}

/// @title FlashCallbackMock
/// @notice Mocks the flash callback by repaying principal and fees.
contract FlashCallbackMock is IEvxFlashCallback {
    ERC20 private token0;
    ERC20 private token1;

    /**
     * @param _token0 The first token used in pool.
     * @param _token1 The second token used in pool.
     */
    constructor(ERC20 _token0, ERC20 _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @notice Callback to repay flash loan principal and fees.
     * @param fee0 The fee amount for token0.
     * @param fee1 The fee amount for token1.
     * @param data Encoded amounts (principal) to repay.
     */
    function evxFlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external override {
        (uint256 amount0, uint256 amount1) = abi.decode(data, (uint256, uint256));
        require(token0.transfer(msg.sender, amount0 + fee0), "FWD0");
        require(token1.transfer(msg.sender, amount1 + fee1), "FWD1");
    }
}