// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title The interface for the Evx Factory
 * @notice The Evx Factory facilitates creation of Evx pools and control over the protocol fees
 * @dev Provides functions to create pools, query pools, and manage fee configurations
 */
interface IEvxFactory {
    /**
     * @notice Emitted when the owner of the factory is changed
     * @param oldOwner The owner before the owner was changed
     * @param newOwner The owner after the owner was changed
     */
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    /**
     * @notice Emitted when a pool is created
     * @param token0 The first token of the pool by address sort order
     * @param token1 The second token of the pool by address sort order
     * @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
     * @param tickSpacing The minimum number of ticks between initialized ticks
     * @param pool The address of the created pool
     */
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        int24 tickSpacing,
        address pool
    );

    /**
     * @notice Emitted when a new fee amount is enabled for pool creation via the factory
     * @param fee The enabled fee, denominated in hundredths of a bip
     * @param tickSpacing The minimum number of ticks between initialized ticks for pools created with the given fee
     */
    event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);

    /**
     * @notice Returns the current owner of the factory
     * @dev Can be changed by the current owner via setOwner
     * @return ownerAddress The address of the factory owner
     */
    function owner() external view returns (address ownerAddress);

    /**
     * @notice Returns the tick spacing for a given fee amount, if enabled, or 0 if not enabled
     * @dev A fee amount can never be removed once enabled
     * @param fee The fee tier denominated in hundredths of a bip
     * @return tickSpacing The tick spacing associated with the fee
     */
    function feeAmountTickSpacing(uint24 fee) external view returns (int24 tickSpacing);

    /**
     * @notice Returns the pool address for a given token pair and fee, or address(0) if it does not exist
     * @dev tokenA and tokenB may be passed in either order
     * @param tokenA The contract address of one token
     * @param tokenB The contract address of the other token
     * @param fee The fee tier denominated in hundredths of a bip
     * @return pool The address of the pool or zero address if not found
     */
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);

    /**
     * @notice Creates a new Evx pool for the given tokens and fee
     * @dev Uses deterministic CREATE2 address via token ordering and fee salt
     *      Reverts if pool exists, fee invalid, or token inputs invalid
     * @param tokenA One of the two tokens
     * @param tokenB The other token
     * @param fee The fee tier for the pool
     * @return pool The address of the newly created pool
     */
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);

    /**
     * @notice Transfers factory ownership to a new owner
     * @dev Must be called by the current owner
     * @param _owner The new owner address to set
     */
    function setOwner(address _owner) external;

    /**
     * @notice Enables a new fee tier with given tick spacing
     * @dev Fee tiers cannot be removed once enabled
     * @param fee The fee tier denominated in hundredths of a bip
     * @param tickSpacing The tick spacing to enforce for this fee tier
     */
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
}
