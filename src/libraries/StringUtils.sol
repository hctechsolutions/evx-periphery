// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ConstructTokenURIParams, DecimalStringParams } from './NFT/NFTSharedStructs.sol';
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

library StringUtils {

    /**
     * @notice Converts a pool fee (in hundredths of a bip) into a human-readable percentage string.
     * @dev Handles both integer and fractional parts. Example: 500 → "0.05%", 3000 → "0.3%", 10000 → "1%".
     * @param fee The fee value as a uint24 (e.g., 3000 = 0.3%).
     * @return feeString A formatted percentage string (e.g., "0.3%").
     */
    function feeToPercentString(uint24 fee) internal pure returns (string memory) {
        // 1 unit = 0.0001%
        uint256 intPart = fee / 10_000;      // Integer part of the percentage
        uint256 fracPart = fee % 10_000;     // Fractional part (up to 4 digits)

        if (fracPart == 0) {
            return string(abi.encodePacked(Strings.toString(intPart), "%"));
        }

        // Trim trailing zeros from the fractional part
        uint8 decimals = 4;
        while (fracPart % 10 == 0) {
            fracPart /= 10;
            decimals--;
        }

        // Pad with leading zeros if needed
        string memory fracStr = Strings.toString(fracPart);
        uint8 missingZeros = decimals - uint8(bytes(fracStr).length);
        bytes memory leading = new bytes(missingZeros);
        for (uint8 i; i < missingZeros; ++i) leading[i] = "0";

        return string(
            abi.encodePacked(
                intPart == 0 ? "0" : Strings.toString(intPart),
                ".",
                string(leading),
                fracStr,
                "%"
            )
        );
    }
}
