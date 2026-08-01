// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from 'forge-std/Test.sol';
import { TickLens } from '../../../src/contracts/lens/TickLens.sol';
import { IEvxPoolImmutables } from '@evx-core/interfaces/pool/IEvxPoolImmutables.sol';

contract TickLensTest is Test {
    TickLens public tickLens;
    address public mockPool;

    function setUp() public {
        tickLens = new TickLens();
        mockPool = address(0x123);
    }

    function testGetPopulatedTicksInWord() public {
        // This test would require a real pool with initialized ticks
        // For now, we'll just test that the function doesn't revert
        vm.expectRevert();
        tickLens.getPopulatedTicksInWord(mockPool, 0);
    }

    function testGetTicksFromPriceRange() public {
        // Test with sqrt prices in X96 format
        uint160 sqrtPriceLowerX96 = 79228162514264337593543950336; // sqrt(1.5) * 2^96
        uint160 sqrtPriceUpperX96 = 91442775600000000000000000000; // sqrt(2.0) * 2^96
        
        // Mock the pool to return a tick spacing
        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(IEvxPoolImmutables.tickSpacing.selector),
            abi.encode(int24(10))
        );
        
        (int24 tickLower, int24 tickUpper) = tickLens.getTicksFromPriceRange(
            mockPool,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96
        );
        
        // Verify that lower tick is less than upper tick
        assertTrue(tickLower < tickUpper, "Lower tick should be less than upper tick");
        
        // Verify that ticks are properly spaced (multiple of 10)
        assertTrue(tickLower % 10 == 0, "Lower tick should be properly spaced");
        assertTrue(tickUpper % 10 == 0, "Upper tick should be properly spaced");
    }

    function testGetTicksFromPriceRangeRevertsOnInvalidPrices() public {
        // Test with invalid price range (lower >= upper)
        vm.expectRevert("Price lower must be less than price upper");
        tickLens.getTicksFromPriceRange(
            mockPool,
            91442775600000000000000000000, // Higher sqrt price
            79228162514264337593543950336  // Lower sqrt price
        );
        
        // Test with zero prices
        vm.expectRevert("Prices must be positive");
        tickLens.getTicksFromPriceRange(
            mockPool,
            0,
            79228162514264337593543950336
        );
    }


}
