// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { NoDelegateCall } from "@evx-core/contracts/NoDelegateCall.sol";
import { NoDelegateCallError } from "@evx-core/contracts/NoDelegateCall.sol";

/**
 * @title Child
 * @notice Test implementation contract that uses the NoDelegateCall modifier to prevent delegatecalls.
 * @dev Inherits from NoDelegateCall and exposes a sample method protected by the modifier.
 */
contract Child is NoDelegateCall {
    /**
     * @notice A sample function protected by the noDelegateCall modifier.
     * @dev Returns a constant value if the function is called directly.
     * @return The value 12345 if not delegatecalled.
     */
    function protectedCall() external view noDelegateCall returns (uint256) {
        return 12345;
    }
}

/**
 * @title DelegateCaller
 * @notice Contract that attempts to delegatecall a method from another contract.
 * @dev Used to test whether the NoDelegateCall modifier correctly prevents delegatecalls.
 */
contract DelegateCaller {
    /**
     * @notice Executes a delegatecall to the target contract.
     * @dev Will revert if the target contract includes a delegatecall guard.
     * @param target The address of the target contract.
     * @return result The result returned by the delegatecall if successful.
     */
    function callViaDelegate(address target) external returns (uint256 result) {
        (bool success, bytes memory data) = target.delegatecall(
            abi.encodeWithSignature("protectedCall()")
        );
        if (!success) {
            // Propaga exatamente o revert do child (incluindo selector de custom error)
            assembly {
                revert(add(data, 0x20), mload(data))
            }
        }
        return abi.decode(data, (uint256));
    }

    /**
     * @notice Decodes a revert reason from the returned data.
     * @dev If data is too short, a fallback message is returned.
     * @param data The raw return data from the failed call.
     * @return message The revert message string.
     */
    function getRevertMessage(bytes memory data) internal pure returns (string memory message) {
        if (data.length < 68) return "delegatecall reverted";
        assembly { data := add(data, 0x04) }
        return abi.decode(data, (string));
    }
}

/**
 * @title NoDelegateCallTest
 * @notice Foundry test suite for the NoDelegateCall modifier.
 * @dev Verifies that direct calls succeed and delegatecalls are properly rejected.
 */
contract NoDelegateCallTest is Test {
    Child         public child;
    DelegateCaller public delegateCaller;

    /**
     * @notice Deploys Child and DelegateCaller contracts for testing.
     */
    function setUp() public {
        child          = new Child();
        delegateCaller = new DelegateCaller();
    }

    /**
     * @notice Tests that a direct call to a protected function succeeds.
     * @dev Verifies that the return value is correct when no delegatecall is used.
     */
    function testDirectCallSuccess() public view {
        uint256 result = child.protectedCall();
        assertEq(result, 12345);
    }

    /**
     * @notice Tests that a delegatecall to a protected function fails.
     * @dev Expects the call to revert with a specific revert reason.
     */
    function testDelegateCallReverts() public {
        vm.expectRevert(NoDelegateCallError.selector);
        delegateCaller.callViaDelegate(address(child));
    }
}
