// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/contracts/base/BlockTimestamp.sol";
import "@evx-periphery/contracts/base/ERC721Permit.sol";
import "@evx-periphery/contracts/base/LiquidityManagement.sol";
import "@evx-periphery/libraries/LiquidityAmounts.sol";
import "@evx-core/libraries/TickMath.sol";


/**
 * @title ERC721Permit Test Suite
 */
contract LiquidityManagementTest is Test {
    MockERC20 private token0;
    MockERC20 private token1;
    MockEvxPool private poolImpl;
    address private poolAddr;
    LiquidityManagerHarness private manager;

    // Sorted token addresses per PoolAddress requirements
    address private t0;
    address private t1;

    uint24 private constant FEE = 3000;

    function setUp() public {
        // deploy mock tokens
        token0 = new MockERC20("Token0", "TK0");
        token1 = new MockERC20("Token1", "TK1");

        // determine canonical token ordering (token0 < token1)
        if (address(token0) < address(token1)) {
            t0 = address(token0);
            t1 = address(token1);
        } else {
            t0 = address(token1);
            t1 = address(token0);
        }

        // set synthetic pool price sqrtPriceX96 ~1 (2**96)
        poolImpl = new MockEvxPool(uint160(1 << 96));

        // compute deterministic pool address used by LiquidityManagement
        PoolAddress.PoolKey memory key = PoolAddress.PoolKey({token0: t0, token1: t1, fee: FEE});
        address factory = address(0xBEEF);
        vm.etch(factory, hex"00");
        vm.mockCall(
            factory,
            abi.encodeWithSelector(bytes4(keccak256("poolImplementation()"))),
            abi.encode(address(0x1111))
        );
        poolAddr = PoolAddress.computeAddress(factory, key);

        // Map pool code to deterministic address
        vm.etch(poolAddr, address(poolImpl).code);

        // Deploy liquidity manager harness
        manager = new LiquidityManagerHarness(factory, address(0xC0DE));
    }

    function testAddLiquiditySuccess() public {
        LiquidityManagement.AddLiquidityParams memory p = LiquidityManagement.AddLiquidityParams({
            token0: t0,
            token1: t1,
            fee: FEE,
            recipient: address(this),
            tickLower: -600,
            tickUpper: 600,
            amount0Desired: 1 ether,
            amount1Desired: 1 ether,
            amount0Min: 0.5 ether,
            amount1Min: 0.5 ether
        });

        (uint128 liq, uint256 amt0, uint256 amt1, ) = manager.addLiquidityExternal(p);
        assertGt(liq, 0, "Liquidity should be > 0");
        assertGe(amt0, p.amount0Min, "amount0 >= min" );
        assertGe(amt1, p.amount1Min, "amount1 >= min" );
    }

    function testAddLiquiditySlippageReverts() public {
        LiquidityManagement.AddLiquidityParams memory p = LiquidityManagement.AddLiquidityParams({
            token0: t0,
            token1: t1,
            fee: FEE,
            recipient: address(this),
            tickLower: -600,
            tickUpper: 600,
            amount0Desired: 1 ether,
            amount1Desired: 1 ether,
            amount0Min: 1 ether + 1,
            amount1Min: 1 ether + 1
        });
        vm.expectRevert("Price slippage check");
        manager.addLiquidityExternal(p);
    }
}

/* ---------------------------------- Mocks --------------------------------- */

contract MockERC20 {
    string public name; string public symbol; uint8 public constant decimals = 18; mapping(address=>uint256) public balanceOf;
    constructor(string memory n,string memory s){name=n;symbol=s;}
    function transfer(address to,uint256 amt) external returns(bool){balanceOf[to]+=amt;return true;}
}

/**
 * @notice Mimics a Evx pool style enough for addLiquidity logic.
 */
contract MockEvxPool {
    uint160 private immutable _sqrtPriceX96;
    constructor(uint160 p){_sqrtPriceX96=p;}

    function slot0() external view returns (uint160, int24, uint16, uint16, uint16, uint8, bool) {
        return (_sqrtPriceX96, 0, 0, 0, 0, 0, false);
    }

    function mint(address /*recipient*/, int24 tickLower, int24 tickUpper, uint128 liquidity, bytes calldata /*data*/)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            _sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            liquidity
        );
    }
}

/**
 * @notice Exposes `addLiquidity` for testing.
 */
contract LiquidityManagerHarness is LiquidityManagement {
    constructor(address _factory, address _weth) PeripheryImmutableState(_factory, _weth) {}
    function addLiquidityExternal(AddLiquidityParams memory p)
        external returns (uint128,uint256,uint256, IEvxPool pool)
    {
        return addLiquidity(p);
    }
}
