// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {StandardBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";

contract HybridBtcBobDecoderAndSanitizer is 
    BaseDecoderAndSanitizer, 
    StandardBridgeDecoderAndSanitizer 
{

}
