// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-periphery/contracts/base/PeripheryImmutableState.sol';
import '@evx-periphery/interfaces/INonfungiblePositionManager.sol';
import '@evx-periphery/contracts/NonfungiblePositionManager.sol';
import '@evx-periphery/libraries/PoolAddress.sol';
import '@evx-core/interfaces/IEvxPool.sol';

contract PositionLens is PeripheryImmutableState {
    address public immutable positionManager;

    /**
     * @notice Initializes the quoter with the factory and WETH9 addresses.
     * @param _factory The address of the EvxFactory contract.
     * @param _positionManager The address of the Evx Position Manager contract.
     * @param _WETH9 The address of the WETH9 token.
     */
    constructor(
        address _factory, 
        address _positionManager, 
        address _WETH9
    ) PeripheryImmutableState(_factory, _WETH9) {
        positionManager = _positionManager;
    }

    function getPositionFee(uint256 tokenId)
        public
        view
        returns (uint128 owed0, uint128 owed1)
    {
        INonfungiblePositionManager pm = INonfungiblePositionManager(positionManager);
        
        (
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
        ) = pm.positions(tokenId);
        
        require(liquidity > 0, "no liquidity");

        address poolAddr = PoolAddress.computeAddress(
            factory,
            PoolAddress.PoolKey({
                token0: token0, 
                token1: token1, 
                fee: fee
            })
        );

        IEvxPool pool = IEvxPool(poolAddr);

        ( , int24 tickCurrent , , , , , ) = pool.slot0();

        uint256 fgGlobal0 = pool.feeGrowthGlobal0X128();
        uint256 fgGlobal1 = pool.feeGrowthGlobal1X128();

        // ---- feeGrowthInside token0 ----
        (, , uint256 fgOutsideLower0 , uint256 fgOutsideLower1 , , , , ) = pool.ticks(tickLower);
        (, , uint256 fgOutsideUpper0 , uint256 fgOutsideUpper1 , , , , ) = pool.ticks(tickUpper);

        uint256 below0 = tickCurrent >= tickLower
            ? fgOutsideLower0
            : fgGlobal0 - fgOutsideLower0;
        uint256 above0 = tickCurrent <  tickUpper
            ? fgOutsideUpper0
            : fgGlobal0 - fgOutsideUpper0;

        uint256 inside0 = fgGlobal0 - below0 - above0;

        // ---- feeGrowthInside token1 ----
        uint256 below1 = tickCurrent >= tickLower
            ? fgOutsideLower1
            : fgGlobal1 - fgOutsideLower1;
        uint256 above1 = tickCurrent <  tickUpper
            ? fgOutsideUpper1
            : fgGlobal1 - fgOutsideUpper1;

        uint256 inside1 = fgGlobal1 - below1 - above1;

        owed0 = mulDiv128(
            liquidity,
            inside0 - feeGrowthInside0LastX128
        ) + tokensOwed0;

        owed1 = mulDiv128(
            liquidity,
            inside1 - feeGrowthInside1LastX128
        ) + tokensOwed1;
    }

    function mulDiv128(
        uint128 liquidity,
        uint256 delta
    ) internal pure returns (uint128) {
        return uint128((uint256(liquidity) * delta) >> 128);
    }
}
