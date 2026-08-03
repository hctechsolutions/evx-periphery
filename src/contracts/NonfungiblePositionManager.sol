// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/interfaces/IEvxPool.sol';
import '@evx-core/libraries/FixedPoint128.sol';
import '@evx-core/libraries/FullMath.sol';

import '@evx-periphery/interfaces/INonfungiblePositionManager.sol';
import '@evx-periphery/interfaces/INonfungibleTokenPositionDescriptor.sol';
import '@evx-periphery/libraries/PositionKey.sol';
import '@evx-periphery/libraries/PoolAddress.sol';
import '@evx-periphery/contracts/base/LiquidityManagement.sol';
import '@evx-periphery/contracts/base/PeripheryImmutableState.sol';
import '@evx-periphery/contracts/base/Multicall.sol';
import '@evx-periphery/contracts/base/ERC721Permit.sol';
import '@evx-periphery/contracts/base/PeripheryValidation.sol';
import '@evx-periphery/contracts/base/SelfPermit.sol';
import '@evx-periphery/contracts/base/PoolInitializer.sol';

/**
 * @title NonfungiblePositionManager
 * @notice Wraps Evx liquidity positions into ERC721 NFTs.
 * @dev Each position is represented as a unique NFT with encoded tick range, liquidity, and fee growth.
 */
contract NonfungiblePositionManager is
    INonfungiblePositionManager,
    Multicall,
    ERC721Permit,
    PeripheryImmutableState,
    PoolInitializer,
    LiquidityManagement,
    PeripheryValidation,
    SelfPermit
{

    /**
     * @notice Stores metadata for a single NFT-based liquidity position.
     * @dev Each field tracks state for fee accounting, authorization, and liquidity range.
     * This structure is used internally to manage and track LP positions.
     *
     * @param nonce A sequential value used for signature invalidation via permit.
     * @param operator The address approved to manage this token (set via `approve`).
     * @param poolId Internal identifier referencing the pool associated with the position.
     * @param tickLower The lower bound of the tick range in which liquidity is provided.
     * @param tickUpper The upper bound of the tick range in which liquidity is provided.
     * @param liquidity The current liquidity amount held by this position.
     * @param feeGrowthInside0LastX128 Last recorded fee growth for token0 within the tick range.
     * @param feeGrowthInside1LastX128 Last recorded fee growth for token1 within the tick range.
     * @param tokensOwed0 The amount of token0 accrued but not yet collected.
     * @param tokensOwed1 The amount of token1 accrued but not yet collected.
     */
    struct Position {
        uint96 nonce;
        address operator;
        uint80 poolId;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    /// @dev Internal pool ID mapping and data
    mapping(address => uint80) private _poolIds;

    /// @dev Pool keys by pool ID, to save on SSTOREs for position data
    mapping(uint80 => PoolAddress.PoolKey) private _poolIdToPoolKey;

    /// @dev Maps tokenId to position
    mapping(uint256 => Position) private _positions;

    /// @dev Next NFT tokenId (starts at 1)
    uint176 private _nextId = 1;

    /// @dev Next internal pool ID (starts at 1)
    uint80 private _nextPoolId = 1;

    /// @dev Token URI descriptor
    address private immutable _tokenDescriptor;

    /**
     * @notice Deploys the position manager with base configuration.
     * @param _factory The address of the Evx factory.
     * @param _WETH9 The address of the WETH9 contract.
     * @param _tokenDescriptor_ The address of the token URI descriptor contract.
     */
    constructor(
        address _factory,
        address _WETH9,
        address _tokenDescriptor_
    ) ERC721Permit('Evx Positions NFT-V1', 'EVX-POS', '1') PeripheryImmutableState(_factory, _WETH9) {
        _tokenDescriptor = _tokenDescriptor_;
    }

    /// @inheritdoc INonfungiblePositionManager
    function positions(uint256 tokenId)
        external
        view
        override
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        Position memory position = _positions[tokenId];
        require(position.poolId != 0, 'Invalid token ID');
        PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
        return (
            position.nonce,
            position.operator,
            poolKey.token0,
            poolKey.token1,
            poolKey.fee,
            position.tickLower,
            position.tickUpper,
            position.liquidity,
            position.feeGrowthInside0LastX128,
            position.feeGrowthInside1LastX128,
            position.tokensOwed0,
            position.tokensOwed1
        );
    }

    /**
     * @notice Stores the pool key if it's not cached, and returns the internal ID.
     * @param pool The address of the pool.
     * @param poolKey The pool key used to derive the address.
     * @return poolId The ID assigned to the pool.
     */
    function cachePoolKey(address pool, PoolAddress.PoolKey memory poolKey) private returns (uint80 poolId) {
        poolId = _poolIds[pool];
        if (poolId == 0) {
            _poolIds[pool] = (poolId = _nextPoolId++);
            _poolIdToPoolKey[poolId] = poolKey;
        }
    }

    /// @inheritdoc INonfungiblePositionManager
    function mint(MintParams calldata params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        IEvxPool pool;
        (liquidity, amount0, amount1, pool) = addLiquidity(
            AddLiquidityParams({
                token0: params.token0,
                token1: params.token1,
                fee: params.fee,
                recipient: address(this),
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min
            })
        );

        _mint(params.recipient, (tokenId = _nextId++));

        bytes32 positionKey = PositionKey.compute(address(this), params.tickLower, params.tickUpper);
        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, , ) = pool.positions(positionKey);

        uint80 poolId = cachePoolKey(
            address(pool),
            PoolAddress.PoolKey({token0: params.token0, token1: params.token1, fee: params.fee})
        );

        _positions[tokenId] = Position({
            nonce: 0,
            operator: address(0),
            poolId: poolId,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            liquidity: liquidity,
            feeGrowthInside0LastX128: feeGrowthInside0LastX128,
            feeGrowthInside1LastX128: feeGrowthInside1LastX128,
            tokensOwed0: 0,
            tokensOwed1: 0
        });

        emit IncreaseLiquidity(tokenId, liquidity, amount0, amount1);
    }

    /**
     * @notice Modifier to ensure msg.sender is authorized for a given token.
     * @param tokenId The ID of the position token.
     */
    modifier isAuthorizedForToken(uint256 tokenId) {
        require(_isAuthorized(ownerOf(tokenId), msg.sender, tokenId), 'Not approved');
        _;
    }

    /**
     * @notice Returns the token URI for a given position token.
     * @param tokenId The token ID.
     * @return The URI string for the position metadata.
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, IERC721Metadata) returns (string memory) {
        require(_ownerOf(tokenId) != address(0));
        return INonfungibleTokenPositionDescriptor(_tokenDescriptor).tokenURI(this, tokenId);
    }

    /**
     * @notice Unused override to save bytecode size.
     */
    function baseURI() public pure returns (string memory) {}

    /// @inheritdoc INonfungiblePositionManager
    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        Position storage position = _positions[params.tokenId];

        PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];

        IEvxPool pool;
        (liquidity, amount0, amount1, pool) = addLiquidity(
            AddLiquidityParams({
                token0: poolKey.token0,
                token1: poolKey.token1,
                fee: poolKey.fee,
                tickLower: position.tickLower,
                tickUpper: position.tickUpper,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                recipient: address(this)
            })
        );

        bytes32 positionKey = PositionKey.compute(address(this), position.tickLower, position.tickUpper);

        // This is now updated to the current transaction
        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, , ) = pool.positions(positionKey);

        position.tokensOwed0 += uint128(
            FullMath.mulDiv(
                feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128,
                position.liquidity,
                FixedPoint128.Q128
            )
        );
        position.tokensOwed1 += uint128(
            FullMath.mulDiv(
                feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128,
                position.liquidity,
                FixedPoint128.Q128
            )
        );

        position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        position.liquidity += liquidity;

        emit IncreaseLiquidity(params.tokenId, liquidity, amount0, amount1);
    }

    /// @inheritdoc INonfungiblePositionManager
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        override
        isAuthorizedForToken(params.tokenId)
        checkDeadline(params.deadline)
        returns (uint256 amount0, uint256 amount1)
    {
        require(params.liquidity > 0);
        Position storage position = _positions[params.tokenId];

        uint128 positionLiquidity = position.liquidity;
        require(positionLiquidity >= params.liquidity);

        PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
        IEvxPool pool = IEvxPool(PoolAddress.resolve(factory, poolKey));
        (amount0, amount1) = pool.burn(position.tickLower, position.tickUpper, params.liquidity);

        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, 'Price slippage check');

        bytes32 positionKey = PositionKey.compute(address(this), position.tickLower, position.tickUpper);
        
        // This is now updated to the current transaction
        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, , ) = pool.positions(positionKey);

        position.tokensOwed0 +=
            uint128(amount0) +
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128,
                    positionLiquidity,
                    FixedPoint128.Q128
                )
            );
        position.tokensOwed1 +=
            uint128(amount1) +
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128,
                    positionLiquidity,
                    FixedPoint128.Q128
                )
            );

        position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        
        // Subtraction is safe because we checked positionLiquidity is gte params.liquidity
        position.liquidity = positionLiquidity - params.liquidity;

        emit DecreaseLiquidity(params.tokenId, params.liquidity, amount0, amount1);
    }

    /// @inheritdoc INonfungiblePositionManager
    function collect(CollectParams calldata params)
        external
        payable
        override
        isAuthorizedForToken(params.tokenId)
        returns (uint256 amount0, uint256 amount1)
    {
        require(params.amount0Max > 0 || params.amount1Max > 0);
        
        // Allow collecting to the nft position manager address with address 0
        address recipient = params.recipient == address(0) ? address(this) : params.recipient;

        Position storage position = _positions[params.tokenId];
        PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
        IEvxPool pool = IEvxPool(PoolAddress.resolve(factory, poolKey));

        (uint128 tokensOwed0, uint128 tokensOwed1) = (position.tokensOwed0, position.tokensOwed1);

        // Trigger an update of the position fees owed and fee growth snapshots if it has any liquidity
        if (position.liquidity > 0) {
            pool.burn(position.tickLower, position.tickUpper, 0);
            (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, , ) =
                pool.positions(PositionKey.compute(address(this), position.tickLower, position.tickUpper));

            tokensOwed0 += uint128(
                FullMath.mulDiv(
                    feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128,
                    position.liquidity,
                    FixedPoint128.Q128
                )
            );
            tokensOwed1 += uint128(
                FullMath.mulDiv(
                    feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128,
                    position.liquidity,
                    FixedPoint128.Q128
                )
            );

            position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
            position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        }

        // compute the arguments to give to the pool#collect method
        (uint128 amount0Collect, uint128 amount1Collect) =
            (
                params.amount0Max > tokensOwed0 ? tokensOwed0 : params.amount0Max,
                params.amount1Max > tokensOwed1 ? tokensOwed1 : params.amount1Max
            );

        // the actual amounts collected are returned
        (amount0, amount1) = pool.collect(
            recipient,
            position.tickLower,
            position.tickUpper,
            amount0Collect,
            amount1Collect
        );


        // Sometimes there will be a few less wei than expected due to rounding 
        // down in core, but we just subtract the full amount expected
        // instead of the actual amount so we can burn the token
        position.tokensOwed0 = tokensOwed0 - amount0Collect;
        position.tokensOwed1 = tokensOwed1 - amount1Collect;

        emit Collect(params.tokenId, recipient, amount0Collect, amount1Collect);
    }

    /// @inheritdoc INonfungiblePositionManager
    function burn(uint256 tokenId) external payable override isAuthorizedForToken(tokenId) {
        Position storage position = _positions[tokenId];
        require(position.liquidity == 0 && position.tokensOwed0 == 0 && position.tokensOwed1 == 0, 'Not cleared');
        delete _positions[tokenId];
        _burn(tokenId);
    }

    /**
     * @notice Returns and increments the nonce for a given token ID.
     * @dev Used in permit signature validation.
     * @param tokenId The token ID.
     * @return The current nonce before increment.
     */
    function _getAndIncrementNonce(uint256 tokenId) internal override returns (uint256) {
        return uint256(_positions[tokenId].nonce++);
    }

    /// @inheritdoc IERC721
    function getApproved(uint256 tokenId) public view override(ERC721, IERC721) returns (address) {
        require(_ownerOf(tokenId) != address(0), 'ERC721: approved query for nonexistent token');
        return _positions[tokenId].operator;
    }
}
