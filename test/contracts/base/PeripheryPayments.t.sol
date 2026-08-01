// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/libraries/TransferHelper.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@evx-periphery/contracts/base/PeripheryPayments.sol";
import "@evx-periphery/contracts/base/PeripheryImmutableState.sol";

/**
 * @title PeripheryPayments Test Suite
 * @notice Covers `unwrapWETH9`, `sweepToken`, `refundETH`, and the branches of the internal `pay` helper.
 */
contract PeripheryPaymentsTest is Test {
    MockWETH private weth;
    MockERC20 private dai;
    PaymentsHarness private payHarness;
    address private constant USER = address(0xABCD);

    function setUp() public {
        weth = new MockWETH();
        dai = new MockERC20("DAI", "DAI");
        payHarness = new PaymentsHarness(address(0xDEAD), address(weth));
    }

    function testUnwrapWETH9Success() public {
        weth.deposit{value: 2 ether}();
        weth.transfer(address(payHarness), 2 ether);

        uint256 startBal = USER.balance;
        vm.prank(USER);
        payHarness.unwrapWETH9(1 ether, USER);

        assertEq(weth.balanceOf(address(payHarness)), 0);
        assertEq(USER.balance - startBal, 2 ether);
    }

    function testUnwrapWETH9RevertWhenInsufficient() public {
        vm.expectRevert(bytes("Insufficient WETH9"));
        payHarness.unwrapWETH9(1, USER);
    }

    function testSweepTokenSuccess() public {
        dai.mint(address(payHarness), 1_000 ether);
        vm.prank(USER);
        payHarness.sweepToken(address(dai), 100 ether, USER);
        assertEq(dai.balanceOf(USER), 1_000 ether);
        assertEq(dai.balanceOf(address(payHarness)), 0);
    }

    function testSweepTokenRevertWhenInsufficient() public {
        vm.expectRevert(bytes("Insufficient token"));
        payHarness.sweepToken(address(dai), 1, USER);
    }

    function testRefundETH() public {
        // Directly fund the harness with 1 ETH
        vm.deal(address(payHarness), 1 ether);

        uint256 startBal = USER.balance;
        vm.prank(USER);
        payHarness.refundETH();
        assertEq(USER.balance - startBal, 1 ether, "User refunded 1 ETH");
    }

    function testPayWithEthWrapping() public {
        vm.deal(address(payHarness), 2 ether);
        uint256 before = weth.balanceOf(USER);
        payHarness.payWithWETH9(1 ether, USER);
        assertEq(weth.balanceOf(USER) - before, 1 ether);
    }

    function testPayWithInternalTokens() public {
        dai.mint(address(payHarness), 500 ether);
        uint256 before = dai.balanceOf(USER);
        payHarness.payFromContractToken(address(dai), USER, 200 ether);
        assertEq(dai.balanceOf(USER) - before, 200 ether);
        assertEq(dai.balanceOf(address(payHarness)), 300 ether);
    }

    function testPayPullingTokens() public {
        dai.mint(USER, 100 ether);
        vm.prank(USER);
        dai.approve(address(payHarness), 80 ether);

        uint256 recBefore = dai.balanceOf(address(0xBEEF));
        payHarness.payPull(address(dai), USER, address(0xBEEF), 80 ether);
        assertEq(dai.balanceOf(address(0xBEEF)) - recBefore, 80 ether);
    }
}

contract PaymentsHarness is PeripheryPayments {
    constructor(address _factory, address _weth) PeripheryImmutableState(_factory, _weth) {}

    function payWithWETH9(uint256 value, address recipient) external {
        pay(WETH9, address(0), recipient, value);
    }

    function payFromContractToken(address token, address recipient, uint256 value) external {
        pay(token, address(this), recipient, value);
    }

    function payPull(address token, address payer, address recipient, uint256 value) external {
        pay(token, payer, recipient, value);
    }
}

contract MockERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    constructor(string memory n, string memory s) {
        name = n;
        symbol = s;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 current = allowance[from][msg.sender];
        require(current >= amount, "ALLOW");
        allowance[from][msg.sender] = current - amount;
        _transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "BAL");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

contract MockWETH is MockERC20 {
    constructor() MockERC20("WETH", "WETH") {}

    function deposit() external payable {
        totalSupply += msg.value;
        balanceOf[msg.sender] += msg.value;
        emit Transfer(address(0), msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "BAL");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {}
}
