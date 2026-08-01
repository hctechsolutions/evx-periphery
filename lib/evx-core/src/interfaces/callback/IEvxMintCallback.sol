// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IEvxMintCallback
 * @notice Interface for contracts that call IEvxPoolActions#mint to provide liquidity.
 * @dev Implementers must pay the owed tokens back to the pool during the callback.
 */
interface IEvxMintCallback {
    /**
     * @notice Callback invoked by an EvxPool after liquidity is minted to a position.
     * @dev The caller must transfer the owed amounts of token0 and token1 to the pool within this function.
     *      The caller must be verified to be a valid EvxPool deployed by the canonical EvxFactory.
     * @param amount0Owed The amount of token0 owed to the pool for the minted liquidity.
     * @param amount1Owed The amount of token1 owed to the pool for the minted liquidity.
     * @param data Arbitrary data forwarded from the original mint call.
     */
    function evxMintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}
