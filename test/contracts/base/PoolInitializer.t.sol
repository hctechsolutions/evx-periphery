// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

/* -------------------------------------------------------------------------- */
/*                    Minimal interface & mock definitions                     */
/* -------------------------------------------------------------------------- */

interface IMockEvxPool {
    function initializeObservation(uint160 sqrtPriceX96) external;
    function slot0() external view returns (uint160, int24, uint16, uint16, uint16, uint8, bool);
    function initialized() external view returns (bool);
}

interface IMockEvxFactory {
    function getPool(address, address, uint24) external view returns (address);
    function createPool(address, address, uint24) external returns (address);
}

/* -------------------------------------------------------------------------- */
/*                        PoolInitializer implementation                       */
/* -------------------------------------------------------------------------- */

import "@evx-periphery/contracts/base/PoolInitializer.sol";
import "@evx-periphery/contracts/base/PeripheryImmutableState.sol";

contract PoolInitializerHarness is PoolInitializer {
    constructor(address _factory, address _weth) PeripheryImmutableState(_factory, _weth) {}
}

/* -------------------------------------------------------------------------- */
/*                             Mock pool & factory                             */
/* -------------------------------------------------------------------------- */

contract MockEvxPool is IMockEvxPool {
    uint160 private _sqrtPriceX96;
    bool public override initialized;

    function initializeObservation(uint160 sqrtPriceX96) external override {
        require(!initialized, "ALREADY");
        _sqrtPriceX96 = sqrtPriceX96;
        initialized = true;
    }

    function slot0()
        external
        view
        override
        returns (uint160, int24, uint16, uint16, uint16, uint8, bool)
    {
        return (_sqrtPriceX96, 0, 0, 0, 0, 0, false);
    }
}

contract MockEvxFactory is IMockEvxFactory {
    mapping(bytes32 => address) public pools;

    function poolImplementation() external pure returns (address) {
        return address(0x1111);
    }

    function _key(address token0, address token1, uint24 fee) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token0, token1, fee));
    }

    function getPool(address t0, address t1, uint24 fee) external view override returns (address) {
        return pools[_key(t0, t1, fee)];
    }

    function createPool(address t0, address t1, uint24 fee) external override returns (address) {
        bytes32 key = _key(t0, t1, fee);
        require(pools[key] == address(0), "EXISTS");
        MockEvxPool pool = new MockEvxPool();
        pools[key] = address(pool);
        return address(pool);
    }
}

/* -------------------------------------------------------------------------- */
/*                            Test contract                                    */
/* -------------------------------------------------------------------------- */

contract PoolInitializerTest is Test {
    MockEvxFactory private factory;
    PoolInitializerHarness private initializer;

    address tokenA = address(0x1000);
    address tokenB = address(0x2000); // > tokenA
    uint24 constant FEE = 3_000;
    uint160 constant PRICE = uint160(1 << 96);

    function setUp() public {
        factory = new MockEvxFactory();

        initializer = new PoolInitializerHarness(address(factory), address(0xABCDEF));
    }

    function testCreatesAndInitializesWhenAbsent() public {
        address poolAddr = initializer.createAndInitializePoolIfNecessary(tokenA, tokenB, FEE, PRICE);
        assertTrue(poolAddr != address(0), "Pool address should be non zero");

        // Should be stored in factory
        assertEq(factory.getPool(tokenA, tokenB, FEE), poolAddr);

        // Should be initialized
        uint160 sqrtPrice; (sqrtPrice,,,,,,) = IMockEvxPool(poolAddr).slot0();
        assertEq(sqrtPrice, PRICE, "Pool initialized with wrong price");
    }

    function testReturnsExistingPoolWithoutReinit() public {
        // create & init first
        address first = initializer.createAndInitializePoolIfNecessary(tokenA, tokenB, FEE, PRICE);
        // call again with different price – should NOT re‑init
        uint160 newPrice = PRICE + 1_000;
        address second = initializer.createAndInitializePoolIfNecessary(tokenA, tokenB, FEE, newPrice);
        assertEq(first, second, "Should return same pool");

        uint160 stored; (stored,,,,,,) = IMockEvxPool(first).slot0();
        assertEq(stored, PRICE, "Price should remain original (no reinit)");
    }

    function testInitializesExistingUninitializedPool() public {
        // Manually create pool via factory but leave uninitialized
        address pool = factory.createPool(tokenA, tokenB, FEE);
        uint160 pre; (pre,,,,,,) = IMockEvxPool(pool).slot0();
        assertEq(pre, 0, "Should be uninitialized");

        // Now run initializer – should init existing pool
        address returned = initializer.createAndInitializePoolIfNecessary(tokenA, tokenB, FEE, PRICE);
        assertEq(returned, pool, "Should return same pool");

        uint160 _after;
        (_after,,,,,,) = IMockEvxPool(pool).slot0();
        assertEq(_after, PRICE, "Pool should now be initialized");
    }

    function testRevertsOnTokenOrder() public {
        vm.expectRevert();
        initializer.createAndInitializePoolIfNecessary(tokenB, tokenA, FEE, PRICE);
    }
}
