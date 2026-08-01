// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ChainIdTest
 * @notice Unit tests for the ChainId library.
 */
import "forge-std/Test.sol";
import {ChainId} from "@evx-periphery/libraries/ChainId.sol";

contract ChainIdTest is Test {
    /**
     * @notice Ensures that `ChainId.get()` returns the same value as `block.chainid`
     *         in the VM’s initial state.
     */
    function testInitialChainIdMatchesBlock() external view {
        uint256 expected = block.chainid;
        uint256 actual   = ChainId.get();
        assertEq(actual, expected, "ChainId.get() != block.chainid");
    }

    /**
     * @notice After changing the chain ID via the `vm.chainId` cheat‑code,
     *         `ChainId.get()` must reflect the new value.
     */
    function testChainIdAfterVmChange() external {
        uint256 newId = 12345;
        vm.chainId(newId);          // change the chain ID only for this context

        uint256 actual = ChainId.get();
        assertEq(actual, newId, "ChainId.get() != new chainId");
    }
}
