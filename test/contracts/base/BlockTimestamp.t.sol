// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/contracts/base/BlockTimestamp.sol";

/**
 * @title BlockTimestamp Test Suite
 * @notice Unit tests for the BlockTimestamp helper contract.
 * @dev Validates both the default implementation and a mocked override.
 */
contract BlockTimestampTest is Test {
    BlockTimestampWrapper private wrapper;

    /**
     * @notice Deploys a fresh BlockTimestampWrapper before each test case.
     */
    function setUp() public {
        wrapper = new BlockTimestampWrapper();
    }

    /**
     * @notice Checks that `_blockTimestamp()` equals the EVM `block.timestamp`
     *         in the default implementation.
     */
    function testDefaultBlockTimestampMatchesBlockTimestamp() public {
        uint256 warped = 1_717_558_000; // Arbitrary timestamp
        vm.warp(warped);
        assertEq(
            wrapper.getTimestamp(),
            warped,
            "Default _blockTimestamp should match block.timestamp"
        );
    }

    /**
     * @notice Ensures that overriding `_blockTimestamp()` enables deterministic
     *         timestamps for testing purposes.
     */
    function testOverrideBlockTimestamp() public {
        uint256 mocked = 1_234_567_890;
        MockBlockTimestamp mock = new MockBlockTimestamp(mocked);
        assertEq(
            mock.getTimestamp(),
            mocked,
            "Overridden _blockTimestamp should return mocked timestamp"
        );
    }
}

/**
 * @title BlockTimestamp Wrapper
 * @notice Exposes `_blockTimestamp()` as a public view for testing.
 */
contract BlockTimestampWrapper is BlockTimestamp {
    /**
     * @notice Returns the internal block timestamp.
     * @return The timestamp returned by `_blockTimestamp()`.
     */
    function getTimestamp() external view returns (uint256) {
        return _blockTimestamp();
    }
}

/**
 * @title Mock BlockTimestamp
 * @notice Overrides `_blockTimestamp()` with a constant value for deterministic tests.
 */
contract MockBlockTimestamp is BlockTimestamp {
    uint256 private immutable _mockedTimestamp;

    /**
     * @notice Initializes the mock with a fixed timestamp.
     * @param mockedTimestamp_ The timestamp that `_blockTimestamp()` should return.
     */
    constructor(uint256 mockedTimestamp_) {
        _mockedTimestamp = mockedTimestamp_;
    }

    /**
     * @notice Returns the mocked timestamp rather than `block.timestamp`.
     * @return The mocked timestamp set at construction.
     */
    function _blockTimestamp() internal view override returns (uint256) {
        return _mockedTimestamp;
    }

    /**
     * @notice Exposes the mocked timestamp publicly for assertions.
     * @return The mocked timestamp.
     */
    function getTimestamp() external view returns (uint256) {
        return _blockTimestamp();
    }
}
