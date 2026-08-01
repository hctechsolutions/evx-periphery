// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IEvxPool} from "@evx-core/interfaces/IEvxPool.sol";
import {PoolAddress}   from "@evx-periphery/libraries/PoolAddress.sol";
import {CallbackValidation} from "@evx-periphery/libraries/CallbackValidation.sol";

/**
 * @dev Minimal wrapper that exposes the internal library calls so the test can
 *      interact with them directly.
 */
contract CallbackValidationWrapper {
    function verify(
        address factory,
        address tokenA,
        address tokenB,
        uint24  fee
    ) external view returns (address pool) {
        pool = address(
            CallbackValidation.verifyCallback(factory, tokenA, tokenB, fee)
        );
    }

    function verifyWithKey(
        address factory,
        PoolAddress.PoolKey calldata key
    ) external view returns (address pool) {
        pool = address(
            CallbackValidation.verifyCallback(factory, key)
        );
    }
}

contract CallbackValidationTest is Test {
    CallbackValidationWrapper internal wrapper;

    address internal constant FACTORY =
        0xF000000000000000000000000000000000000001;

    address internal constant TOKEN0 =
        0x0000000000000000000000000000000000000002;
    address internal constant TOKEN1 =
        0x0000000000000000000000000000000000000003;

    uint24 internal constant FEE = 3_000; // 0.30 %

    function setUp() public {
        wrapper = new CallbackValidationWrapper();
    }

    /**
     * @notice Library should return the deterministic pool address and
     *         **not** revert when `msg.sender` is that pool.
     */
    function testVerifyCallbackSucceeds() external {
        // Build the canonical PoolKey
        PoolAddress.PoolKey memory key =
            PoolAddress.getPoolKey(TOKEN0, TOKEN1, FEE);

        // Pre‑compute the expected pool address
        address pool = PoolAddress.computeAddress(FACTORY, key);

        // Deploy a 1‑byte stub code at `pool` so `extcodesize(pool) > 0`.
        vm.etch(pool, hex"00");

        // Pretend the call comes **from** the pool
        vm.prank(pool);
        address returned =
            wrapper.verify(FACTORY, TOKEN0, TOKEN1, FEE);

        assertEq(returned, pool, "pool address mismatch");
    }

    /**
     * @notice Any sender that is **not** the pool must cause a revert.
     */
    function testVerifyCallbackWrongSenderReverts() external {
        PoolAddress.PoolKey memory key =
            PoolAddress.getPoolKey(TOKEN0, TOKEN1, FEE);

        address pool = PoolAddress.computeAddress(FACTORY, key);
        vm.etch(pool, hex"00");

        // Call from an arbitrary address (not the pool)
        vm.prank(address(0xBEEF));
        vm.expectRevert(); // no custom error string; just expect a revert
        wrapper.verify(FACTORY, TOKEN0, TOKEN1, FEE);
    }

    /**
     * @notice Overload that takes a `PoolKey` works identically.
     */
    function testVerifyCallbackWithKeySucceeds() external {
        PoolAddress.PoolKey memory key =
            PoolAddress.getPoolKey(TOKEN0, TOKEN1, FEE);

        address pool = PoolAddress.computeAddress(FACTORY, key);
        vm.etch(pool, hex"00");

        vm.prank(pool);
        address returned = wrapper.verifyWithKey(FACTORY, key);
        assertEq(returned, pool, "pool address mismatch");
    }
}
