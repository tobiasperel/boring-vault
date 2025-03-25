// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {RoycoWeirollDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RoycoDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract RoycoSonicNativeDecoderAndSanitizer is BaseDecoderAndSanitizer, RoycoWeirollDecoderAndSanitizer {
    constructor(address _recipeMarketHub) BaseDecoderAndSanitizer() RoycoWeirollDecoderAndSanitizer(_recipeMarketHub) {}
}
