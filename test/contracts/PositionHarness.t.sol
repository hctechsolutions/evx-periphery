// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import { EvxFactory } from "@evx-core/contracts/EvxFactory.sol";
import { EvxPool } from "@evx-core/contracts/EvxPool.sol";
import { TickMath } from "@evx-core/libraries/TickMath.sol";
import { IERC20Minimal } from "@evx-core/interfaces/IERC20Minimal.sol";

import { NonfungiblePositionManager } from "@evx-periphery/contracts/NonfungiblePositionManager.sol";
import { NonfungibleTokenPositionDescriptor } from "@evx-periphery/contracts/NonfungibleTokenPositionDescriptor.sol";
import { INonfungiblePositionManager } from "@evx-periphery/interfaces/INonfungiblePositionManager.sol";
import { MockToken } from "../../scripts/MockToken.sol";
import { IERC721Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/**
 * @title PositionHarnessTest
 * @notice Deterministic local NPM lifecycle (mint → update_range → burn) for Intent Engine Story 5.3.
 * @dev No Sepolia fork. Fixed fee/ticks/amounts → reproducible liquidity. update_range PoC =
 *      decreaseLiquidity(100%) + collect + burn(old) + mint(new ticks).
 */
contract PositionHarnessTest is Test {
    // Fixed fixture knobs (determinism).
    uint24 internal constant FEE = 3000;
    int24 internal constant TICK_LOWER = -60;
    int24 internal constant TICK_UPPER = 60;
    int24 internal constant TICK_LOWER_UPDATED = -120;
    int24 internal constant TICK_UPPER_UPDATED = 120;
    uint256 internal constant AMOUNT_DESIRED = 1e18;
    uint256 internal constant DEADLINE = type(uint256).max;

    EvxFactory internal factory;
    NonfungiblePositionManager internal npm;
    MockToken internal tokenA;
    MockToken internal tokenB;
    address internal token0;
    address internal token1;
    address internal pool;

    function setUp() public {
        EvxPool impl = new EvxPool();
        factory = new EvxFactory(address(impl));

        tokenA = new MockToken("TokenA", "TKA");
        tokenB = new MockToken("TokenB", "TKB");
        if (address(tokenA) < address(tokenB)) {
            token0 = address(tokenA);
            token1 = address(tokenB);
        } else {
            token0 = address(tokenB);
            token1 = address(tokenA);
        }

        // WETH9 unused for ERC20-only harness path; placeholder address is fine.
        address weth9 = address(0xC0FFEE);
        NonfungibleTokenPositionDescriptor descriptor =
            new NonfungibleTokenPositionDescriptor(weth9, _strToBytes32("ETH"));
        npm = new NonfungiblePositionManager(address(factory), weth9, address(descriptor));

        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(0);
        pool = npm.createAndInitializePoolIfNecessary(token0, token1, FEE, sqrtPriceX96);
        assertTrue(pool != address(0), "pool");

        // Fund + approve NPM for mint callbacks.
        MockToken(token0).mint(address(this), 100 * AMOUNT_DESIRED);
        MockToken(token1).mint(address(this), 100 * AMOUNT_DESIRED);
        IERC20Minimal(token0).approve(address(npm), type(uint256).max);
        IERC20Minimal(token1).approve(address(npm), type(uint256).max);
    }

    function testHarnessMintBurnUpdateDeterministic() public {
        (uint256 tokenId, uint128 liquidity, , ) = _mintRange(TICK_LOWER, TICK_UPPER);
        assertEq(tokenId, 1, "first nft id");
        assertGt(liquidity, 0, "mint liquidity");

        // Same fixture replay → same liquidity (determinism gate).
        (uint256 tokenId2, uint128 liquidity2, , ) = _mintRange(TICK_LOWER, TICK_UPPER);
        assertEq(tokenId2, 2, "second nft id");
        assertEq(liquidity2, liquidity, "deterministic liquidity");

        // update_range on tokenId: decrease 100% + collect + burn + mint new ticks.
        uint256 newTokenId = _updateRange(tokenId, liquidity, TICK_LOWER_UPDATED, TICK_UPPER_UPDATED);
        assertEq(newTokenId, 3, "updated nft id");

        (, , , , , int24 tickLower, int24 tickUpper, uint128 newLiq, , , , ) = npm.positions(newTokenId);
        assertEq(tickLower, TICK_LOWER_UPDATED);
        assertEq(tickUpper, TICK_UPPER_UPDATED);
        assertGt(newLiq, 0, "updated liquidity");

        // Burn remaining minted position (tokenId2).
        _burnFully(tokenId2, liquidity2);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId2));
        npm.ownerOf(tokenId2);

        _burnFully(newTokenId, newLiq);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, newTokenId));
        npm.ownerOf(newTokenId);
    }

    function testHarnessMintSucceedsAndPositionsReadable() public {
        (uint256 tokenId, uint128 liquidity, , ) = _mintRange(TICK_LOWER, TICK_UPPER);
        assertEq(npm.ownerOf(tokenId), address(this));
        (, , address p0, address p1, uint24 fee, int24 lo, int24 hi, uint128 liq, , , , ) =
            npm.positions(tokenId);
        assertEq(p0, token0);
        assertEq(p1, token1);
        assertEq(fee, FEE);
        assertEq(lo, TICK_LOWER);
        assertEq(hi, TICK_UPPER);
        assertEq(liq, liquidity);
    }

    function _mintRange(int24 tickLower, int24 tickUpper)
        internal
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: FEE,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: AMOUNT_DESIRED,
            amount1Desired: AMOUNT_DESIRED,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: DEADLINE
        });
        return npm.mint(params);
    }

    /// @dev PoC update_range = decreaseLiquidity(100%) + collect + burn(old) + mint(new ticks).
    function _updateRange(uint256 tokenId, uint128 liquidity, int24 newLower, int24 newUpper)
        internal
        returns (uint256 newTokenId)
    {
        npm.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: DEADLINE
            })
        );
        npm.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        npm.burn(tokenId);

        (newTokenId, , , ) = _mintRange(newLower, newUpper);
    }

    function _burnFully(uint256 tokenId, uint128 liquidity) internal {
        if (liquidity > 0) {
            npm.decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: DEADLINE
                })
            );
            npm.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: tokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );
        }
        npm.burn(tokenId);
    }

    function _strToBytes32(string memory s) internal pure returns (bytes32 r) {
        bytes memory temp = bytes(s);
        require(temp.length <= 32, "label");
        assembly {
            r := mload(add(temp, 32))
        }
    }
}
