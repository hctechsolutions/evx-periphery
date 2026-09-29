// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@evx-core/interfaces/IEvxFactory.sol";
import "@evx-core/contracts/NoDelegateCall.sol";
import "@evx-core/contracts/EvxPool.sol";
import "@evx-core/libraries/Errors.sol";

contract EvxFactory is IEvxFactory, NoDelegateCall {
    /// @inheritdoc IEvxFactory
    address public override owner;

    /// @inheritdoc IEvxFactory
    mapping(uint24 => int24) public override feeAmountTickSpacing;

    /// @inheritdoc IEvxFactory
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    /// @notice Implementation contract address used for pool clones
    address public immutable override poolImplementation;

    /**
     * @dev Initializes default fee tiers and sets deployer as owner
     */
    constructor(address _poolImplementation) {
        if (_poolImplementation == address(0)) revert ZeroImplementation();
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);

        feeAmountTickSpacing[500]   = 10;
        feeAmountTickSpacing[3000]  = 60;
        feeAmountTickSpacing[10000] = 200;

        emit FeeAmountEnabled(500, 10);
        emit FeeAmountEnabled(3000, 60);
        emit FeeAmountEnabled(10000, 200);

        poolImplementation = _poolImplementation;
    }

    /**
     * @notice Sorts two token addresses to canonical order
     * @dev Reverts if tokens are identical or zero address
     * @param tokenA One token address
     * @param tokenB The other token address
     * @return token0 The lower address
     * @return token1 The higher address
     */
    function _sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        if (tokenA == tokenB) revert IdenticalAddresses();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
    }

    /// @inheritdoc IEvxFactory
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override noDelegateCall returns (address pool) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        int24 tickSpacing = feeAmountTickSpacing[fee];
        if (tickSpacing == 0) revert InvalidFee();
        if (getPool[token0][token1][fee] != address(0)) revert PoolExists();

        bytes32 salt = keccak256(abi.encodePacked(token0, token1, fee));
        pool = Clones.cloneDeterministic(poolImplementation, salt);
        EvxPool(pool).initialize(address(this), token0, token1, fee, tickSpacing);

        getPool[token0][token1][fee] = pool;
        getPool[token1][token0][fee] = pool;

        emit PoolCreated(token0, token1, fee, tickSpacing, pool);
    }

    /// @inheritdoc IEvxFactory
    function setOwner(address _owner) external override {
        if (msg.sender != owner) revert Forbidden();
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @inheritdoc IEvxFactory
    function enableFeeAmount(uint24 fee, int24 tickSpacing) public override {
        if (msg.sender != owner) revert Forbidden();
        if (fee >= 1_000_000) revert FeeTooHigh();
        if (tickSpacing <= 0 || tickSpacing >= 16_384) revert InvalidTickSpacing();
        if (feeAmountTickSpacing[fee] != 0) revert AlreadyEnabled();

        feeAmountTickSpacing[fee] = tickSpacing;
        emit FeeAmountEnabled(fee, tickSpacing);
    }
}
