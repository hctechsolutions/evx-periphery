// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/TransferHelper.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Mock ERC20 returning true
contract TokenReturnTrue is IERC20 {
    mapping(address => uint256) public balanceOf;
    function totalSupply() external pure override returns (uint256) { return 0; }
    function allowance(address, address) external pure override returns (uint256) { return 0; }
    function approve(address, uint256) external pure override returns (bool) { return true; }
    function transfer(address to, uint256 value) external override returns (bool) {
        balanceOf[to] += value;
        return true;
    }
    function transferFrom(address, address to, uint256 value) external override returns (bool) {
        balanceOf[to] += value;
        return true;
    }
}

/// @notice Mock ERC20 with no return value
contract TokenNoReturn {
    mapping(address => uint256) public balanceOf;
    function transfer(address to, uint256 value) external {
        balanceOf[to] += value;
    }
}

/// @notice Mock ERC20 returning false
contract TokenReturnFalse is IERC20 {
    mapping(address => uint256) public balanceOf;
    function totalSupply() external pure override returns (uint256) { return 0; }
    function allowance(address, address) external pure override returns (uint256) { return 0; }
    function approve(address, uint256) external pure override returns (bool) { return true; }
    function transfer(address to, uint256 value) external override returns (bool) {
        balanceOf[to] += value;
        return false;
    }
    function transferFrom(address, address to, uint256 value) external override returns (bool) {
        balanceOf[to] += value;
        return false;
    }
}

/// @notice Mock ERC20 transfer reverting
contract TokenRevert {
    function transfer(address, uint256) external pure {
        revert("revert");
    }
}

/// @notice Harness to call TransferHelper.safeTransfer
contract TransferHelperHarness {
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) external {
        TransferHelper.safeTransfer(token, to, value);
    }
}

/// @title TransferHelper Library Test Suite
contract TransferHelperTest is Test {
    TransferHelperHarness harness;
    address recipient;

    function setUp() public {
        harness = new TransferHelperHarness();
        recipient = address(0xBEEF);
    }

    /// @notice safeTransfer succeeds when token returns true
    function testSafeTransferReturnTrue() public {
        TokenReturnTrue token = new TokenReturnTrue();
        // mint by directly interacting
        token.transfer(recipient, 123);
        // now test helper
        harness.safeTransfer(address(token), recipient, 456);
        assertEq(token.balanceOf(recipient), 123 + 456);
    }

    /// @notice safeTransfer succeeds when token has no return
    function testSafeTransferNoReturn() public {
        TokenNoReturn token = new TokenNoReturn();
        token.transfer(recipient, 100);
        harness.safeTransfer(address(token), recipient, 456);
        assertEq(token.balanceOf(recipient), 100 + 456);
    }

    /// @notice safeTransfer reverts when token returns false
    function testSafeTransferReturnFalseReverts() public {
        TokenReturnFalse token = new TokenReturnFalse();
        vm.expectRevert(bytes("TF"));
        harness.safeTransfer(address(token), recipient, 789);
    }

    /// @notice safeTransfer reverts when token.transfer reverts
    function testSafeTransferRevertReverts() public {
        TokenRevert token = new TokenRevert();
        vm.expectRevert(bytes("TF"));
        harness.safeTransfer(address(token), recipient, 1);
    }
}