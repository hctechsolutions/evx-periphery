// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TokenRatioSortOrderTest
 * @notice Unit‑tests for the constants defined in TokenRatioSortOrder.
 */
import "forge-std/Test.sol";
import {TokenRatioSortOrder} from "@evx-periphery/libraries/TokenRatioSortOrder.sol";

contract TokenRatioSortOrderTest is Test {

    function testNumeratorValues() external pure {
        assertEq(TokenRatioSortOrder.NUMERATOR_MOST, 300);
        assertEq(TokenRatioSortOrder.NUMERATOR_MORE, 200);
        assertEq(TokenRatioSortOrder.NUMERATOR,      100);
    }

    function testDenominatorValues() external pure {
        assertEq(TokenRatioSortOrder.DENOMINATOR_MOST, -300);
        assertEq(TokenRatioSortOrder.DENOMINATOR_MORE, -200);
        assertEq(TokenRatioSortOrder.DENOMINATOR,      -100);
    }

    function testNumeratorOrdering() external pure {
        assertGt(TokenRatioSortOrder.NUMERATOR_MOST, TokenRatioSortOrder.NUMERATOR_MORE);
        assertGt(TokenRatioSortOrder.NUMERATOR_MORE, TokenRatioSortOrder.NUMERATOR);
        assertGt(TokenRatioSortOrder.NUMERATOR, 0);
    }

    function testDenominatorOrdering() external pure {
        assertLt(TokenRatioSortOrder.DENOMINATOR_MOST, TokenRatioSortOrder.DENOMINATOR_MORE);
        assertLt(TokenRatioSortOrder.DENOMINATOR_MORE, TokenRatioSortOrder.DENOMINATOR);
        assertLt(TokenRatioSortOrder.DENOMINATOR, 0);
    }
}
