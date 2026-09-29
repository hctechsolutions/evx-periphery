// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/interfaces/IEvxFactory.sol';

/**
 * @title PoolAddress
 * @notice Computes Evx pool addresses from the factory's immutable pool implementation.
 * @dev Pools are EIP-1167 clones. The init code embeds the implementation address,
 *      so the hash is derived at call time from `poolImplementation()` instead of a
 *      compile-time constant. A constant remains only for fixtures whose factory
 *      address has no code.
 */
library PoolAddress {
    /// @notice Registry returned a pool that is not the CREATE2 clone of this factory.
    error RegistryMismatch();

    /**
     * @dev Fallback hash for unit tests that pass a factory address with no code.
     *      Production paths ignore this value and hash the live implementation.
     */
    bytes32 internal constant POOL_INIT_CODE_HASH = 0x56c8f9f8c1544dcffa4e5f69e448719d481963b3b6e8d2c7e84ed6ba80ffcee4;

    /// @notice Identifies a pool by sorted tokens and fee tier.
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @notice EIP-1167 init-code hash for a clone of `implementation` (55 bytes).
    function initCodeHash(address implementation) internal pure returns (bytes32 hash) {
        hash = keccak256(
            abi.encodePacked(
                hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
                implementation,
                hex"5af43d82803e903d91602b57fd5bf3"
            )
        );
    }

    /// @notice Orders tokens and keeps the fee tier.
    function getPoolKey(
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal pure returns (PoolKey memory key) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        key = PoolKey({token0: tokenA, token1: tokenB, fee: fee});
    }

    /**
     * @notice CREATE2 address of the pool for `key`.
     * @dev When `factory` has code, the hash comes from its immutable implementation.
     *      When it has no code, the test fallback constant is used.
     */
    function computeAddress(address factory, PoolKey memory key) internal view returns (address pool) {
        if (factory.code.length == 0) {
            return computeAddress(factory, key, POOL_INIT_CODE_HASH);
        }
        return computeAddress(factory, key, initCodeHash(IEvxFactory(factory).poolImplementation()));
    }

    /// @notice CREATE2 address using an explicit init-code hash.
    function computeAddress(
        address factory,
        PoolKey memory key,
        bytes32 poolInitCodeHash
    ) internal pure returns (address pool) {
        require(key.token0 < key.token1);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(key.token0, key.token1, key.fee)),
                            poolInitCodeHash
                        )
                    )
                )
            )
        );
    }

    /**
     * @notice Predicted clone address, rejecting a registry entry that disagrees.
     * @dev `getPool == address(0)` means the pool is not created yet; the prediction stands.
     *      A non-zero registry value must equal the CREATE2 address.
     */
    function resolve(address factory, PoolKey memory key) internal view returns (address pool) {
        pool = computeAddress(factory, key);
        if (factory.code.length == 0) return pool;
        (bool ok, bytes memory data) = factory.staticcall(
            abi.encodeWithSelector(IEvxFactory.getPool.selector, key.token0, key.token1, key.fee)
        );
        if (ok && data.length >= 32) {
            address registered = abi.decode(data, (address));
            if (registered != address(0) && registered != pool) revert RegistryMismatch();
        }
    }
}
