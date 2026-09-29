// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PoolAddressTest
 * @notice Unit tests for the PoolAddress library
 */
import "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {EvxFactory} from "@evx-core/contracts/EvxFactory.sol";
import {EvxPool} from "@evx-core/contracts/EvxPool.sol";
import {IEvxFactory} from "@evx-core/interfaces/IEvxFactory.sol";
import {PoolAddress} from "@evx-periphery/libraries/PoolAddress.sol";

contract ResolveCaller {
    function resolve(address factory, PoolAddress.PoolKey calldata key) external view returns (address) {
        return PoolAddress.resolve(factory, key);
    }
}

contract PoolAddressTest is Test {
    /* -------------------------------------------------------------------------- */
    /*                                Test data                                   */
    /* -------------------------------------------------------------------------- */

    address internal constant TOKEN_A =
        0x1111111111111111111111111111111111111111;
    address internal constant TOKEN_B =
        0x2222222222222222222222222222222222222222;

    uint24  internal constant FEE     = 3_000; // 0.30 %
    address internal constant FACTORY =
        0xF000000000000000000000000000000000000001;

    /* -------------------------------------------------------------------------- */
    /*                               getPoolKey                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Ensures the function orders tokens (token0 < token1) and keeps `fee`.
     */
    function testGetPoolKeyOrdering() external pure {
        PoolAddress.PoolKey memory key =
            PoolAddress.getPoolKey(TOKEN_B, TOKEN_A, FEE);

        assertTrue(key.token0 < key.token1, "token ordering incorrect");
        assertEq(key.token0, TOKEN_A, "token0 mismatch");
        assertEq(key.token1, TOKEN_B, "token1 mismatch");
        assertEq(key.fee,    FEE,     "fee  mismatch");
    }

    /* -------------------------------------------------------------------------- */
    /*                              computeAddress                                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Calling twice with the same key MUST return the same address,
     *         and reversing input token order (while using `getPoolKey`)
     *         must yield the identical pool address.
     */
    function testComputeAddressDeterministic() external view {
        PoolAddress.PoolKey memory key1 =
            PoolAddress.getPoolKey(TOKEN_A, TOKEN_B, FEE);
        PoolAddress.PoolKey memory key2 =
            PoolAddress.getPoolKey(TOKEN_B, TOKEN_A, FEE); // reversed input

        address addr1 = PoolAddress.computeAddress(FACTORY, key1);
        address addr2 = PoolAddress.computeAddress(FACTORY, key1);
        address addr3 = PoolAddress.computeAddress(FACTORY, key2);

        assertEq(addr1, addr2, "computeAddress not deterministic");
        assertEq(addr1, addr3, "address should ignore input order");
    }

    /**
     * @notice Library result must equal the manual CREATE2 hash.
     */
    function testComputeAddressMatchesManualHash() external view {
        PoolAddress.PoolKey memory key =
            PoolAddress.getPoolKey(TOKEN_A, TOKEN_B, FEE);

        // Value returned by library
        address expected = PoolAddress.computeAddress(FACTORY, key);

        // Manual CREATE2 reconstruction (must match computeAddress’s encodePacked)
        bytes32 salt = keccak256(
            abi.encodePacked(key.token0, key.token1, key.fee)
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                hex"ff",
                FACTORY,
                salt,
                PoolAddress.POOL_INIT_CODE_HASH
            )
        );
        address manual = address(uint160(uint256(hash)));

        assertEq(manual, expected, "manual hash mismatch");
    }

    /**
     * @notice Passing an unsorted PoolKey must revert (library `require`).
     * forge-config: default.allow_internal_expect_revert = true
     */
    function testComputeAddressRevertsOnUnsortedKey() external {
        PoolAddress.PoolKey memory badKey = PoolAddress.PoolKey({
            token0: TOKEN_B, // token0 > token1
            token1: TOKEN_A,
            fee:    FEE
        });

        vm.expectRevert();
        PoolAddress.computeAddress(FACTORY, badKey);
    }

    /// @notice Live factory prediction matches OpenZeppelin's clone address.
    function testComputeAddressMatchesClonePrediction() external {
        EvxPool implementation = new EvxPool();
        EvxFactory factory = new EvxFactory(address(implementation));
        PoolAddress.PoolKey memory key = PoolAddress.getPoolKey(TOKEN_A, TOKEN_B, FEE);

        address predicted = PoolAddress.computeAddress(address(factory), key);
        bytes32 salt = keccak256(abi.encodePacked(key.token0, key.token1, key.fee));
        address fromClones = Clones.predictDeterministicAddress(
            address(implementation),
            salt,
            address(factory)
        );

        assertEq(predicted, fromClones, "clone prediction mismatch");
        assertEq(PoolAddress.resolve(address(factory), key), predicted, "empty registry");
    }

    /// @notice A registry entry that is not the predicted clone is rejected.
    /// forge-config: default.allow_internal_expect_revert = true
    function testResolveRevertsWhenRegistryDisagrees() external {
        EvxPool implementation = new EvxPool();
        EvxFactory factory = new EvxFactory(address(implementation));
        PoolAddress.PoolKey memory key = PoolAddress.getPoolKey(TOKEN_A, TOKEN_B, FEE);

        vm.mockCall(
            address(factory),
            abi.encodeWithSelector(IEvxFactory.getPool.selector, key.token0, key.token1, key.fee),
            abi.encode(address(0x1234))
        );

        ResolveCaller caller = new ResolveCaller();
        vm.expectRevert(PoolAddress.RegistryMismatch.selector);
        caller.resolve(address(factory), key);
    }
}
