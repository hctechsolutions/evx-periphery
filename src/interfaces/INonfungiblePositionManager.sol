// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';

import './IPeripheryImmutableState.sol';
import './IPeripheryPayments.sol';
import './IPoolInitializer.sol';
import './IERC721Permit.sol';

/**
 * @title INonfungiblePositionManager
 * @notice Interface for managing Evx LP positions as ERC721 tokens.
 * @dev Allows minting, modifying, collecting, and burning NFT-wrapped LP positions.
 */
interface INonfungiblePositionManager is
    IPoolInitializer,
    IPeripheryPayments,
    IPeripheryImmutableState,
    IERC721Metadata,
    IERC721Permit
{
    /**
     * @notice Emitted when liquidity is increased for a position NFT.
     * @dev Also emitted when a new position is minted.
     */
    event IncreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    /**
     * @notice Emitted when liquidity is decreased from a position NFT.
     */
    event DecreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    /**
     * @notice Emitted when a position NFT collects accrued tokens.
     * @dev Collected amounts may differ from emitted values due to rounding inside the pool.
     */
    event Collect(uint256 indexed tokenId, address recipient, uint256 amount0, uint256 amount1);

    /**
     * @notice Returns detailed position info for a given token ID.
     * @param tokenId The ID of the position token.
     * @return nonce Permit nonce for the position.
     * @return operator Address approved for transfer.
     * @return token0 Address of token0 in the pool.
     * @return token1 Address of token1 in the pool.
     * @return fee Pool fee tier.
     * @return tickLower Lower tick of the position.
     * @return tickUpper Upper tick of the position.
     * @return liquidity Current liquidity of the position.
     * @return feeGrowthInside0LastX128 Fee growth snapshot for token0.
     * @return feeGrowthInside1LastX128 Fee growth snapshot for token1.
     * @return tokensOwed0 Accrued token0 fees.
     * @return tokensOwed1 Accrued token1 fees.
     */
    function positions(uint256 tokenId)
        external
        view
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
        );

    /// @notice Parameters used for minting a new NFT position.
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    /**
     * @notice Creates and mints a new position wrapped in an NFT.
     * @param params Struct with mint parameters.
     * @return tokenId The newly minted position's token ID.
     * @return liquidity Liquidity amount minted.
     * @return amount0 Actual amount of token0 used.
     * @return amount1 Actual amount of token1 used.
     */
    function mint(MintParams calldata params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    /// @notice Parameters for increasing liquidity in a position.
    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /**
     * @notice Increases liquidity for an existing position.
     * @param params Struct with liquidity addition parameters.
     * @return liquidity Amount of liquidity added.
     * @return amount0 Amount of token0 used.
     * @return amount1 Amount of token1 used.
     */
    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    /// @notice Parameters for decreasing liquidity in a position.
    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /**
     * @notice Decreases liquidity in a position.
     * @param params Struct with withdrawal parameters.
     * @return amount0 Token0 amount returned.
     * @return amount1 Token1 amount returned.
     */
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    /// @notice Parameters for collecting accrued tokens from a position.
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    /**
     * @notice Collects tokens accrued by a position.
     * @param params Struct with collection parameters.
     * @return amount0 Token0 amount collected.
     * @return amount1 Token1 amount collected.
     */
    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Burns an NFT representing a position.
     * @dev Position must have zero liquidity and no owed tokens.
     * @param tokenId The token ID to burn.
     */
    function burn(uint256 tokenId) external payable;
}
