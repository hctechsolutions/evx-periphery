// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/libraries/StringUtils.sol";


contract StringUtilsTest is Test {
    function testFeeToPercentString() public pure {
        assertEq(StringUtils.feeToPercentString(3000), "0.3%");
        assertEq(StringUtils.feeToPercentString(10000), "1%");
        assertEq(StringUtils.feeToPercentString(1), "0.0001%");
        assertEq(StringUtils.feeToPercentString(0), "0%");
    }
}