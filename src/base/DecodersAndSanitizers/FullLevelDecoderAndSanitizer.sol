// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;


import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {LevelDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LevelDecoderAndSanitizer.sol";

contract FullLevelDecoderAndSanitizer is 
    BaseDecoderAndSanitizer,
    LevelDecoderAndSanitizer
{

}
