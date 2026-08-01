// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@evx-periphery/contracts/base/PeripheryPaymentsWithFee.sol";
import "@evx-periphery/contracts/base/PeripheryImmutableState.sol";

/**
 * @title PeripheryPaymentsWithFee Test Suite
 */
contract PeripheryPaymentsWithFeeTest is Test {
    MockWETH private weth;
    MockERC20 private usdc;
    PaymentsWithFeeHarness private harness;

    address private constant USER = address(0xCAFE);
    address private constant FEE = address(0xFEE1);

    function setUp() public {
        weth = new MockWETH();
        usdc = new MockERC20("USDC", "USDC");
        harness = new PaymentsWithFeeHarness(address(0xFACADE), address(weth));
    }

    /* -------------------------------------------------------------------------- */
    /*                        unwrapWETH9WithFee()                                 */
    /* -------------------------------------------------------------------------- */

    function testUnwrapWETH9WithFeeSuccess() public {
        // Deposit 5 ETH worth of WETH into harness
        weth.deposit{value: 5 ether}();
        weth.transfer(address(harness), 5 ether);

        uint256 feeBips = 50; // 0.5%
        uint256 expectedFee = (5 ether * feeBips) / 10_000; // 0.025 ETH

        uint256 startUser = USER.balance;
        uint256 startFee = FEE.balance;

        vm.prank(USER);
        harness.unwrapWETH9WithFee(1 ether, USER, feeBips, FEE);

        assertEq(weth.balanceOf(address(harness)), 0);
        assertEq(USER.balance - startUser, 5 ether - expectedFee, "Recipient ETH wrong");
        assertEq(FEE.balance - startFee, expectedFee, "Fee ETH wrong");
    }

    function testUnwrapWETH9WithFeeRevertsInvalidFee() public {
        weth.deposit{value: 1 ether}();
        weth.transfer(address(harness), 1 ether);

        vm.expectRevert();
        harness.unwrapWETH9WithFee(0, USER, 0, FEE); // fee = 0

        vm.expectRevert();
        harness.unwrapWETH9WithFee(0, USER, 101, FEE); // fee > 100 bips
    }

    function testUnwrapWETH9WithFeeRevertsInsufficient() public {
        vm.expectRevert(bytes("Insufficient WETH9"));
        harness.unwrapWETH9WithFee(1 ether, USER, 10, FEE);
    }

    /* -------------------------------------------------------------------------- */
    /*                         sweepTokenWithFee()                                 */
    /* -------------------------------------------------------------------------- */

    function testSweepTokenWithFeeSuccess() public {
        usdc.mint(address(harness), 1_000e6); // 6‑decimals mock token but using 18 decimals; treat raw
        uint256 feeBips = 100; // 1%
        uint256 expectedFee = (1_000e6 * feeBips) / 10_000; // 10e6

        vm.prank(USER);
        harness.sweepTokenWithFee(address(usdc), 100e6, USER, feeBips, FEE);

        assertEq(usdc.balanceOf(FEE), expectedFee);
        assertEq(usdc.balanceOf(USER), 1_000e6 - expectedFee);
        assertEq(usdc.balanceOf(address(harness)), 0);
    }

    function testSweepTokenWithFeeRevertsInvalidFee() public {
        vm.expectRevert();
        harness.sweepTokenWithFee(address(usdc), 0, USER, 0, FEE);

        vm.expectRevert();
        harness.sweepTokenWithFee(address(usdc), 0, USER, 101, FEE);
    }

    function testSweepTokenWithFeeRevertsInsufficient() public {
        vm.expectRevert(bytes("Insufficient token"));
        harness.sweepTokenWithFee(address(usdc), 1, USER, 10, FEE);
    }
}

/* ----------------------------- Harness ----------------------------------- */

contract PaymentsWithFeeHarness is PeripheryPaymentsWithFee {
    constructor(address _factory, address _weth) PeripheryImmutableState(_factory, _weth) {}
    // No additional code needed – using inherited functions directly.}
}

/* ----------------------------- Mocks ------------------------------------- */

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
