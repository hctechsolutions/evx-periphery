// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/contracts/base/PeripheryValidation.sol";

/**
 * @title PeripheryValidation Test Suite
 */
contract PeripheryValidationTest is Test {
    ValidationHarness private harness;

    function setUp() public {
        harness = new ValidationHarness();
    }

    function testCheckDeadlinePassesWhenBefore() public view {
        uint256 deadline = block.timestamp + 1 hours;
        // Call should succeed and return true
        bool ok = harness.action(deadline);
        assertTrue(ok, "Modifier should allow call before deadline");
    }

    function testCheckDeadlinePassesWhenEqual() public view {
        uint256 deadline = block.timestamp;
        bool ok = harness.action(deadline);
        assertTrue(ok, "Modifier should allow call at exact deadline");
    }

    function testCheckDeadlineRevertsWhenAfter() public {
        uint256 deadline = block.timestamp - 1;
        vm.expectRevert(bytes("Transaction too old"));
        harness.action(deadline);
    }
}

/**
 * @title ValidationHarness
 * @notice Minimal concrete contract exposing a function gated by the `checkDeadline` modifier.
 */
contract ValidationHarness is PeripheryValidation {
    function action(uint256 deadline) external view checkDeadline(deadline) returns (bool) {
        return true;
    }
}
