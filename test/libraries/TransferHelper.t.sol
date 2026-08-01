// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TransferHelperTest
 * @notice Unit tests for all helpers in TransferHelper.
 */
import "forge-std/Test.sol";
import {TransferHelper} from "@evx-periphery/libraries/TransferHelper.sol";

/* -------------------------------------------------------------------------- */
/*                               Mock ERC‑20s                                 */
/* -------------------------------------------------------------------------- */

abstract contract ERC20Base {
    mapping(address => uint256) internal _bal;
    mapping(address => mapping(address => uint256)) internal _allow;

    /* ------------------------- admin helper (tests) ------------------------ */
    function setBalance(address a, uint256 amt) external {
        _bal[a] = amt;
    }

    /* ---------------------------- view helpers ----------------------------- */
    function balanceOf(address a) external view returns (uint256) {
        return _bal[a];
    }
}

/**
 * Behaves “normally”: returns `true` on transfer/transferFrom/approve.
 */
contract ERC20True is ERC20Base {
    function transfer(address to, uint256 amt) external returns (bool) {
        _bal[msg.sender] -= amt;
        _bal[to] += amt;
        return true;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        _allow[msg.sender][spender] = amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        _bal[from] -= amt;
        _bal[to] += amt;
        return true;
    }
}

/**
 * Always returns `false`.
 */
contract ERC20False is ERC20Base {
    function transfer(address, uint256) external pure returns (bool) { return false; }
    function approve(address, uint256) external pure returns (bool) { return false; }
    function transferFrom(address, address, uint256) external pure returns (bool) { return false; }
}

/**
 * Returns *no data* (legacy ERC‑20s like USDT).
 */
contract ERC20NoReturn is ERC20Base {
    function transfer(address to, uint256 amt) external { _bal[msg.sender] -= amt; _bal[to] += amt; }
    function approve(address, uint256) external { /* no‑op */ }
    function transferFrom(address from, address to, uint256 amt) external { _bal[from] -= amt; _bal[to] += amt; }
}

/* -------------------------------------------------------------------------- */
/*                           ETH receiver helpers                             */
/* -------------------------------------------------------------------------- */

contract PayableReceiver {
    receive() external payable {}
}

contract RevertingReceiver {
    receive() external payable { revert("no eth"); }
}

/* -------------------------------------------------------------------------- */
/*                 Wrapper exposing the internal library calls                */
/* -------------------------------------------------------------------------- */

contract TransferWrapper {
    using TransferHelper for address;

    /* ---------------  ERC‑20 wrappers --------------- */

    function callSafeTransfer(address token, address to, uint256 v) external {
        token.safeTransfer(to, v);
    }

    function callSafeTransferFrom(address token, address from, address to, uint256 v) external {
        token.safeTransferFrom(from, to, v);
    }

    function callSafeApprove(address token, address to, uint256 v) external {
        token.safeApprove(to, v);
    }

    /* ---------------  ETH wrapper --------------- */

    receive() external payable {}

    function callSafeTransferETH(address to, uint256 v) external {
        TransferHelper.safeTransferETH(to, v);
    }
}

/* -------------------------------------------------------------------------- */
/*                                 Test suite                                 */
/* -------------------------------------------------------------------------- */

contract TransferHelperTest is Test {
    TransferWrapper internal wrap;
    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB   = address(0xB0B);

    function setUp() public {
        wrap = new TransferWrapper();
        vm.deal(address(wrap), 10 ether); // fund wrapper for ETH tests
    }

    /* ============ ERC‑20: safeTransfer ============ */

    function testSafeTransferTrue() external {
        ERC20True tok = new ERC20True();
        tok.setBalance(address(wrap), 100);
        vm.prank(address(wrap));
        wrap.callSafeTransfer(address(tok), BOB, 50);
        assertEq(tok.balanceOf(BOB), 50);
    }

    function testSafeTransferNoReturn() external {
        ERC20NoReturn tok = new ERC20NoReturn();
        tok.setBalance(address(wrap), 100);
        vm.prank(address(wrap));
        wrap.callSafeTransfer(address(tok), BOB, 40);
        assertEq(tok.balanceOf(BOB), 40);
    }

    function testSafeTransferFalseReverts() external {
        ERC20False tok = new ERC20False();
        vm.prank(address(wrap));
        vm.expectRevert(bytes("ST"));
        wrap.callSafeTransfer(address(tok), BOB, 1);
    }

    /* ============ ERC‑20: safeTransferFrom ============ */

    function testSafeTransferFromTrue() external {
        ERC20True tok = new ERC20True();
        tok.setBalance(ALICE, 60);
        vm.prank(address(wrap));
        wrap.callSafeTransferFrom(address(tok), ALICE, BOB, 30);
        assertEq(tok.balanceOf(BOB), 30);
    }

    function testSafeTransferFromFalseReverts() external {
        ERC20False tok = new ERC20False();
        vm.prank(address(wrap));
        vm.expectRevert(bytes("STF"));
        wrap.callSafeTransferFrom(address(tok), ALICE, BOB, 1);
    }

    /* ============ ERC‑20: safeApprove ============ */

    function testSafeApproveTrue() external {
        ERC20True tok = new ERC20True();
        vm.prank(address(wrap));
        wrap.callSafeApprove(address(tok), BOB, 123);
        // success is enough; no revert
    }

    function testSafeApproveFalseReverts() external {
        ERC20False tok = new ERC20False();
        vm.prank(address(wrap));
        vm.expectRevert(bytes("SA"));
        wrap.callSafeApprove(address(tok), BOB, 1);
    }

    /* ============ ETH transfers ============ */

    function testSafeTransferETHSuccess() external {
        PayableReceiver recv = new PayableReceiver();
        uint256 before = address(recv).balance;
        vm.prank(address(wrap));
        wrap.callSafeTransferETH(payable(address(recv)), 1 ether);
        assertEq(address(recv).balance, before + 1 ether);
    }

    function testSafeTransferETHReverts() external {
        RevertingReceiver recv = new RevertingReceiver();
        vm.prank(address(wrap));
        vm.expectRevert(bytes("STE"));
        wrap.callSafeTransferETH(payable(address(recv)), 0.1 ether);
    }
}
