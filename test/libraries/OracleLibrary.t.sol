// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/libraries/OracleLibrary.sol";
import "@evx-core/interfaces/pool/IEvxPoolDerivedState.sol";

/**
 * @title OracleLibrary Test Suite
 * @notice Unit tests for the Evx `OracleLibrary` helper functions.
 */
contract OracleLibraryTest is Test {
    address private constant MOCK_POOL = address(0xBEEF);

    /**
     * @notice Ensures `consult` correctly derives the arithmetic mean tick and a positive harmonic liquidity.
     */
    function testConsultArithmeticMeanTick() public {
        uint32 secondsAgo = 10;

        // Assemble mock return data for `observe(uint32[])`
        int56[] memory tickCumulatives = new int56[](2);
        tickCumulatives[0] = 0;      // older cumulative
        tickCumulatives[1] = 100;    // cumulative after 10 s  =>  mean tick = 10

        uint160[] memory splCumulatives = new uint160[](2);
        splCumulatives[0] = 0;
        splCumulatives[1] = 2;       // small non‑zero delta to avoid div‑by‑zero

        // Mock `observe` - match by selector so any calldata is accepted
        bytes memory observeSelector = abi.encodeWithSelector(IEvxPoolDerivedState.observe.selector);
        vm.mockCall(MOCK_POOL, observeSelector, abi.encode(tickCumulatives, splCumulatives));

        (int24 meanTick, uint128 harmonicLiquidity) = OracleLibrary.consult(MOCK_POOL, secondsAgo);

        assertEq(meanTick, 10, "Arithmetic mean tick mismatch");
        assertGt(harmonicLiquidity, 0, "Liquidity must be positive");
    }

    /**
     * @notice `consult` must revert when `secondsAgo == 0`.
     * forge-config: default.allow_internal_expect_revert = true
     */
    function testConsultRevertsWithZeroSecondsAgo() public {
        vm.expectRevert();
        OracleLibrary.consult(MOCK_POOL, 0);
    }

    /**
     * @notice Tick 0 should quote 1:1 when `baseToken < quoteToken`.
     */
    function testGetQuoteAtTickTickZeroAscending() public pure {
        address base = address(0x100);
        address quote = address(0x200);
        uint128 amount = 1 ether;
        uint256 quoteAmount = OracleLibrary.getQuoteAtTick(0, amount, base, quote);
        assertEq(quoteAmount, amount, "Price 1:1 expected");
    }

    /**
     * @notice Tick 0 should quote 1:1 when `baseToken > quoteToken`.
     */
    function testGetQuoteAtTickTickZeroDescending() public pure {
        address base = address(0x300);
        address quote = address(0x100);
        uint128 amount = 5 ether;
        uint256 quoteAmount = OracleLibrary.getQuoteAtTick(0, amount, base, quote);
        assertEq(quoteAmount, amount, "Price 1:1 expected");
    }

    /**
     * @notice Verifies weighted mean tick for positive values.
     */
    function testWeightedArithmeticMeanTick() public pure {
        OracleLibrary.WeightedTickData[] memory data = new OracleLibrary.WeightedTickData[](2);
        data[0] = OracleLibrary.WeightedTickData({tick: 10, weight: 1});
        data[1] = OracleLibrary.WeightedTickData({tick: 20, weight: 3});
        int24 mean = OracleLibrary.getWeightedArithmeticMeanTick(data);
        assertEq(mean, 17, "Weighted mean should be floor((10+60)/4)=17");
    }

    /**
     * @notice Weighted mean should round toward negative infinity for negative numerators.
     */
    function testWeightedArithmeticMeanTickRoundingDown() public pure {
        OracleLibrary.WeightedTickData[] memory data = new OracleLibrary.WeightedTickData[](2);
        data[0] = OracleLibrary.WeightedTickData({tick: -11, weight: 1});
        data[1] = OracleLibrary.WeightedTickData({tick: 0,   weight: 1});
        int24 mean = OracleLibrary.getWeightedArithmeticMeanTick(data);
        assertEq(mean, -6, "Expected rounding toward - Infinity ( -11/2 = -5.5 => -6 )");
    }

    /**
     * @notice Ensures ticks are added or subtracted based on token ordering.
     */
    function testGetChainedPrice() public pure {
        // Three tokens; first pair ascending, second descending
        address[] memory tokens = new address[](3);
        tokens[0] = address(0x100); // < 0x300  → add first tick
        tokens[1] = address(0x300);
        tokens[2] = address(0x200); // < 0x300  is false → subtract second tick

        int24[] memory ticks = new int24[](2);
        ticks[0] = 15;  // added
        ticks[1] = 5;   // subtracted

        int256 synthetic = OracleLibrary.getChainedPrice(tokens, ticks);
        assertEq(synthetic, 10, "15 - 5 = 10");
    }
}
