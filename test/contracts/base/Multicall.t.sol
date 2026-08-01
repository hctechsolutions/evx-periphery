// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/contracts/base/Multicall.sol";

/**
 * @title Multicall Test Suite
 * @notice Unit tests for the Evx `Multicall` utility contract.
 */
contract MulticallTest is Test {
    MulticallMock private mc;

    function setUp() public {
        mc = new MulticallMock();
    }

    /**
     * @notice Executes a batch with state‑changing and view calls and verifies returned data.
     */
    function testMulticallSuccess() public {
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeCall(MulticallMock.setNumber, (10));
        calls[1] = abi.encodeCall(MulticallMock.getNumber, ());
        calls[2] = abi.encodeCall(MulticallMock.double, (7));

        bytes[] memory results = mc.multicall(calls);

        // getNumber() should return 10
        assertEq(abi.decode(results[1], (uint256)), 10, "stored value mismatch");
        // double(7) should return 14
        assertEq(abi.decode(results[2], (uint256)), 14, "double result mismatch");
        // Ensure state was updated by setNumber
        assertEq(mc.stored(), 10, "stored() should be 10");
    }

    /**
     * @notice Ensures that a revert in any delegate‑called function propagates.
     */
    function testMulticallPropagatesRevert() public {
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(MulticallMock.setNumber, (1));
        calls[1] = abi.encodeCall(MulticallMock.revertIfZero, (0)); // will revert with "ZERO"

        vm.expectRevert(bytes("ZERO"));
        mc.multicall(calls);

        // State should be unchanged (atomicity)
        assertEq(mc.stored(), 0, "State should roll back on revert");
    }
}

/* ---------------------------------- Mock ---------------------------------- */

/**
 * @title MulticallMock
 * @notice Minimal concrete contract that inherits `Multicall` and exposes helper functions for testing.
 */
contract MulticallMock is Multicall {
    uint256 public stored;

    /**
     * @notice Stores `x` and returns it.
     */
    function setNumber(uint256 x) external returns (uint256) {
        stored = x;
        return x;
    }

    /**
     * @notice Returns the stored number.
     */
    function getNumber() external view returns (uint256) {
        return stored;
    }

    /**
     * @notice Returns `x * 2`.
     */
    function double(uint256 x) external pure returns (uint256) {
        return x * 2;
    }

    /**
     * @notice Reverts with "ZERO" if `x` is zero.
     */
    function revertIfZero(uint256 x) external pure {
        require(x != 0, "ZERO");
    }
}
