// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/Errors.sol";
import "@evx-core/contracts/NoDelegateCallUpgradeable.sol";

/// @title ERC1967Proxy
/// @notice Minimal EIP-1967 proxy for testing delegatecall protections.
/// @dev Stores implementation address at standard EIP-1967 slot and forwards all calls via delegatecall.
contract ERC1967Proxy {
    /// @notice Sets the implementation address in the EIP-1967 storage slot.
    /// @param _logic Address of the implementation contract.
    constructor(address _logic) {
        assembly {
            sstore(
                0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc,
                _logic
            )
        }
    }

    /// @notice Fallback function that delegates calls to the implementation address.
    fallback() external payable {
        assembly {
            let impl := sload(
                0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
            )
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

/// @title TestNoDelegateCallUpgradeable
/// @notice Helper contract exposing `initialize` and a protected function guarded by `noDelegateCall`.
/// @dev Inherits from `NoDelegateCallUpgradeable`.
contract TestNoDelegateCallUpgradeable is NoDelegateCallUpgradeable {
    /// @notice Initializes the contract by setting internal storage flags.
    function initialize() external {
        __NoDelegateCall_init();
    }

    /// @notice Protected function that can only be called directly, not through a delegatecall.
    /// @return uint256 Always returns 123.
    function protectedFunction() external noDelegateCall returns (uint256) {
        return 123;
    }
}

/// @title NoDelegateCallUpgradeableTest
/// @notice Unit tests for the `NoDelegateCallUpgradeable` modifier using proxy simulations.
contract NoDelegateCallUpgradeableTest is Test {
    TestNoDelegateCallUpgradeable impl;

    /// @notice Sets up the test environment by deploying the implementation contract.
    function setUp() public {
        impl = new TestNoDelegateCallUpgradeable();
    }

    /// @notice Tests that initializing once succeeds.
    function testInitializeOnceSucceeds() public {
        impl.initialize();
    }

    /// @notice Tests that initializing twice reverts with `AlreadyInitialized` error.
    function testInitializeTwiceReverts() public {
        impl.initialize();
        vm.expectRevert(abi.encodeWithSelector(AlreadyInitialized.selector));
        impl.initialize();
    }

    /// @notice Tests that calling `protectedFunction` after initialization succeeds.
    function testProtectedFunctionSucceeds() public {
        impl.initialize();
        uint256 result = impl.protectedFunction();
        assertEq(result, 123, "protectedFunction should return 123");
    }

    /// @notice Tests that calling `protectedFunction` through a proxy without initialization reverts with `NoDelegateCallError`.
    function testProxyProtectedFunctionWithoutInitializeReverts() public {
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl));
        TestNoDelegateCallUpgradeable proxyAs = TestNoDelegateCallUpgradeable(address(proxy));
        vm.expectRevert(abi.encodeWithSelector(NoDelegateCallError.selector));
        proxyAs.protectedFunction();
    }

    /// @notice Tests that after initializing through the proxy, `protectedFunction` succeeds.
    function testProxyProtectedFunctionAfterInitializeSucceeds() public {
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl));

        (bool okInit, ) = address(proxy).call(
            abi.encodeWithSelector(TestNoDelegateCallUpgradeable.initialize.selector)
        );
        require(okInit, "proxy initialize failed");

        (bool ok, bytes memory ret) = address(proxy).call(
            abi.encodeWithSelector(TestNoDelegateCallUpgradeable.protectedFunction.selector)
        );
        require(ok, "proxy protectedFunction failed");
        uint256 result = abi.decode(ret, (uint256));
        assertEq(result, 123, "protectedFunction via proxy should return 123");
    }
}
