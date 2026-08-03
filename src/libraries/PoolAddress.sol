// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/interfaces/IEvxFactory.sol';

/**
 * @title PoolAddress
 * @notice Provides helper functions for computing Evx pool addresses and ordering tokens.
 * @dev Uses CREATE2 logic adapted to Evx’s minimal‑proxy (EIP‑1167) pools.
 *      Prefer [`resolve`] for live pools — `POOL_INIT_CODE_HASH` embeds the pool
 *      implementation address and drifts whenever a new `EvxPool` is deployed.
 */
library PoolAddress {
    /**
     * @dev `INIT_CODE_HASH` for EVX’s 58‑byte minimal proxy.
     *
     * The hash is `keccak256(initCode)`, where `initCode` is:
     * `0x3d602d80600a3d3981f3363d3d373d3d3d363d73 +
     * <implementation>` +
     * `5af43d82803e903d91602b57fd5bf3`.
     *
     * **Recalculate and update this constant whenever a new `EvxPool`
     * implementation is deployed.**
     *
     * Example using Foundry:
     * ```bash
     * IMPL=<implementation_address>
     * cast keccak "0x3d602d80600a3d3981f3363d3d373d3d3d363d73${IMPL:2}5af43d82803e903d91602b57fd5bf3"
     * ```
     */
    bytes32 internal constant POOL_INIT_CODE_HASH = 0x56c8f9f8c1544dcffa4e5f69e448719d481963b3b6e8d2c7e84ed6ba80ffcee4;

    /**
     * @notice A struct that uniquely identifies a pool by its tokens and fee.
     * @param token0 The address of the lower-sorted token.
     * @param token1 The address of the higher-sorted token.
     * @param fee The fee tier of the pool.
     */
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /**
     * @notice Computes a PoolKey from two unordered token addresses and a fee.
     * @dev Orders tokens by address and returns a PoolKey with token0 < token1.
     * @param tokenA One of the two tokens.
     * @param tokenB The other token.
     * @param fee The fee tier associated with the pool.
     * @return key Poolkey A PoolKey struct with sorted token0 and token1.
     */
    function getPoolKey(
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal pure returns (PoolKey memory key) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        key = PoolKey({token0: tokenA, token1: tokenB, fee: fee});
    }

    /**
     * @notice Computes the deterministic address of a Evx pool.
     * @dev Formula: `address = address(uint160(uint256(keccak256(0xff ++ factory ++ salt ++ initCodeHash))))`.
     *      `salt = keccak256(token0, token1, fee)`.
     * @param factory Factory contract that deploys pools via `Clones.cloneDeterministic`.
     * @param key     Pool parameters (sorted tokens and fee).
     * @return pool   Deterministic pool address.
     */
    function computeAddress(address factory, PoolKey memory key) internal pure returns (address pool) {
        require(key.token0 < key.token1);
        pool = address(uint160(uint256(
            keccak256(
                abi.encodePacked(
                    hex"ff",
                    factory,
                    keccak256(abi.encodePacked(key.token0, key.token1, key.fee)),
                    POOL_INIT_CODE_HASH
                )
            )
        )));
    }

    /**
     * @notice Resolves a live pool via factory registry, falling back to CREATE2.
     * @dev `getPool` is authoritative for EIP-1167 clones (init-code hash depends on impl).
     *      Fallback preserves etched/mock fixtures that only seed `computeAddress`.
     *      Skip the registry call when `factory` has no code (unit-test etch harnesses).
     */
    function resolve(address factory, PoolKey memory key) internal view returns (address pool) {
        require(key.token0 < key.token1);
        if (factory.code.length > 0) {
            try IEvxFactory(factory).getPool(key.token0, key.token1, key.fee) returns (address p) {
                pool = p;
            } catch {
                // Fall through to CREATE2 — preserves etched/mock fixtures and
                // tolerates non-factory contracts at `factory`.
            }
        }
        if (pool == address(0)) {
            pool = computeAddress(factory, key);
        }
    }
}
