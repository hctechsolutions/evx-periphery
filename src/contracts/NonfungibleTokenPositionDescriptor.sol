// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/interfaces/IEvxPool.sol';
import '@evx-periphery/libraries/SafeERC20Namer.sol';

import '@evx-periphery/libraries/ChainId.sol';
import '@evx-periphery/interfaces/INonfungiblePositionManager.sol';
import '@evx-periphery/interfaces/INonfungibleTokenPositionDescriptor.sol';
import '@evx-periphery/interfaces/IERC20Metadata.sol';
import '@evx-periphery/libraries/PoolAddress.sol';
import '@evx-periphery/libraries/NFT/NFTDescriptor.sol';
import '@evx-periphery/libraries/TokenRatioSortOrder.sol';

import { ConstructTokenURIParams } from '@evx-periphery/libraries/NFT/NFTSharedStructs.sol';

/**
 * @title NonfungibleTokenPositionDescriptor
 * @notice Generates on-chain metadata for NFT positions representing liquidity.
 * @dev Used by the position manager to produce SVG-based JSON token URIs.
 */
contract NonfungibleTokenPositionDescriptor is INonfungibleTokenPositionDescriptor {
    /// @dev Common token addresses for priority logic on mainnet.
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private constant TBTC = 0x8dAEBADE922dF735c38C80C7eBD708Af50815fAa;
    address private constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    /// @notice Address of WETH9 used for native token symbol resolution.
    address public immutable WETH9;

    /// @notice Null-terminated bytes representing the native currency label.
    bytes32 public immutable nativeCurrencyLabelBytes;

    /**
     * @notice Initializes the descriptor contract.
     * @param _WETH9 The address of the WETH9 token.
     * @param _nativeCurrencyLabelBytes A 32-byte null-terminated label (e.g., "ETH").
     */
    constructor(address _WETH9, bytes32 _nativeCurrencyLabelBytes) {
        WETH9 = _WETH9;
        nativeCurrencyLabelBytes = _nativeCurrencyLabelBytes;
    }

    /**
     * @notice Converts the native currency label bytes to a string.
     * @dev Stops at the first null byte (0x00).
     * @return The native currency label (e.g., "ETH").
     */
    function nativeCurrencyLabel() public view returns (string memory) {
        uint256 len = 0;
        while (len < 32 && nativeCurrencyLabelBytes[len] != 0) {
            len++;
        }
        bytes memory b = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            b[i] = nativeCurrencyLabelBytes[i];
        }
        return string(b);
    }

    /// @inheritdoc INonfungibleTokenPositionDescriptor
    function tokenURI(INonfungiblePositionManager positionManager, uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        (, , address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, , , , , ) =
            positionManager.positions(tokenId);

        IEvxPool pool =
            IEvxPool(
                PoolAddress.computeAddress(
                    positionManager.factory(),
                    PoolAddress.PoolKey({token0: token0, token1: token1, fee: fee})
                )
            );

        bool _flipRatio = flipRatio(token0, token1, ChainId.get());
        address quoteTokenAddress = !_flipRatio ? token1 : token0;
        address baseTokenAddress = !_flipRatio ? token0 : token1;
        (, int24 tick, , , , , ) = pool.slot0();

        return
            NFTDescriptor.constructTokenURI(
                ConstructTokenURIParams({
                    tokenId: tokenId,
                    quoteTokenAddress: quoteTokenAddress,
                    baseTokenAddress: baseTokenAddress,
                    quoteTokenSymbol: quoteTokenAddress == WETH9
                        ? nativeCurrencyLabel()
                        : SafeERC20Namer.tokenSymbol(quoteTokenAddress),
                    baseTokenSymbol: baseTokenAddress == WETH9
                        ? nativeCurrencyLabel()
                        : SafeERC20Namer.tokenSymbol(baseTokenAddress),
                    quoteTokenDecimals: IERC20Metadata(quoteTokenAddress).decimals(),
                    baseTokenDecimals: IERC20Metadata(baseTokenAddress).decimals(),
                    flipRatio: _flipRatio,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    tickCurrent: tick,
                    tickSpacing: pool.tickSpacing(),
                    fee: fee,
                    poolAddress: address(pool)
                })
            );
    }

    /**
     * @notice Determines whether the token pair ratio should be flipped for rendering.
     * @dev Uses predefined priority to decide which token is base vs quote.
     * @param token0 Address of the first token.
     * @param token1 Address of the second token.
     * @param chainId The current chain ID.
     * @return True if token1 should be base and token0 should be quote.
     */
    function flipRatio(
        address token0,
        address token1,
        uint256 chainId
    ) public view returns (bool) {
        return tokenRatioPriority(token0, chainId) > tokenRatioPriority(token1, chainId);
    }

    /**
     * @notice Returns the display priority for a token.
     * @dev Determines base/quote order for ratio formatting in token URI.
     * @param token The address of the token.
     * @param chainId The chain ID being evaluated.
     * @return A numeric priority. Higher = more likely to be base.
     */
    function tokenRatioPriority(address token, uint256 chainId) public view returns (int256) {
        if (token == WETH9) {
            return TokenRatioSortOrder.DENOMINATOR;
        }
        if (chainId == 1) {
            if (token == USDC) {
                return TokenRatioSortOrder.NUMERATOR_MOST;
            } else if (token == USDT) {
                return TokenRatioSortOrder.NUMERATOR_MORE;
            } else if (token == DAI) {
                return TokenRatioSortOrder.NUMERATOR;
            } else if (token == TBTC) {
                return TokenRatioSortOrder.DENOMINATOR_MORE;
            } else if (token == WBTC) {
                return TokenRatioSortOrder.DENOMINATOR_MOST;
            } else {
                return 0;
            }
        }
        return 0;
    }
}
