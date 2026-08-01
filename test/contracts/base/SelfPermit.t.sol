// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/contracts/base/SelfPermit.sol";

/**
 * @title SelfPermit Test Suite
 */
contract SelfPermitTest is Test {
    MockPermitToken private token;
    PermitHarness private harness;
    address private constant USER = address(0xB0B);

    function setUp() public {
        token = new MockPermitToken();
        harness = new PermitHarness();
        token.mint(USER, 1_000 ether);
    }

    function testSelfPermitSetsAllowance() public {
        vm.prank(USER);
        harness.selfPermit(address(token), 500 ether, block.timestamp + 1 days, 0, bytes32(0), bytes32(0));
        assertEq(token.allowance(USER, address(harness)), 500 ether);
    }

    function testSelfPermitIfNecessarySkipsWhenEnough() public {
        vm.prank(USER);
        token.approve(address(harness), 600 ether);
        vm.prank(USER);
        harness.selfPermitIfNecessary(address(token), 500 ether, block.timestamp + 1 days, 0, bytes32(0), bytes32(0));
        assertEq(token.allowance(USER, address(harness)), 600 ether);
    }

    function testSelfPermitIfNecessaryCallsWhenLow() public {
        vm.prank(USER);
        harness.selfPermitIfNecessary(address(token), 800 ether, block.timestamp + 1 days, 0, bytes32(0), bytes32(0));
        assertEq(token.allowance(USER, address(harness)), 800 ether);
    }

    function testSelfPermitAllowedSetsMax() public {
        vm.prank(USER);
        harness.selfPermitAllowed(address(token), 0, block.timestamp + 1 days, 0, bytes32(0), bytes32(0));
        assertEq(token.allowance(USER, address(harness)), type(uint256).max);
    }

    function testSelfPermitAllowedIfNecessarySkipsWhenMax() public {
        vm.prank(USER);
        token.approve(address(harness), type(uint256).max);
        vm.prank(USER);
        harness.selfPermitAllowedIfNecessary(address(token), 0, block.timestamp + 1 days, 0, bytes32(0), bytes32(0));
        assertEq(token.permitAllowedCount(), 0);
    }

    function testSelfPermitAllowedIfNecessaryCallsWhenNotMax() public {
        vm.prank(USER);
        token.approve(address(harness), 123);
        vm.prank(USER);
        harness.selfPermitAllowedIfNecessary(address(token), 1, block.timestamp + 1 days, 0, bytes32(0), bytes32(0));
        assertEq(token.allowance(USER, address(harness)), type(uint256).max);
        assertEq(token.permitAllowedCount(), 1);
    }
}

// ---------------------------------------------------------------------------
// Harness inheriting SelfPermit
// ---------------------------------------------------------------------------
contract PermitHarness is SelfPermit {}


contract MockPermitToken is IERC20, IERC20Permit, IERC20PermitAllowed {
    string public constant name = "Mock";
    string public constant symbol = "MCK";
    uint8 public constant decimals = 18;

    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    uint256 private _nonces;
    uint256 private _permitAllowedCalls;

    // -------------------------------- ERC20 --------------------------------
    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
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

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "BAL");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    // --------------------------- IERC20Permit ------------------------------
    function nonces(address) external view override returns (uint256) { return _nonces; }
    function DOMAIN_SEPARATOR() external pure override returns (bytes32) { return bytes32(0); }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 /*deadline*/,
        uint8 /*v*/, bytes32 /*r*/, bytes32 /*s*/
    ) external override {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    // --------------------- IERC20PermitAllowed -----------------------------
    function permit(
        address owner,
        address spender,
        uint256 /*nonce*/,
        uint256 /*expiry*/,
        bool allowed,
        uint8 /*v*/, bytes32 /*r*/, bytes32 /*s*/
    ) external override {
        _permitAllowedCalls += 1;
        allowance[owner][spender] = allowed ? type(uint256).max : 0;
        emit Approval(owner, spender, allowance[owner][spender]);
    }

    function permitAllowedCount() external view returns (uint256) { return _permitAllowedCalls; }
}

