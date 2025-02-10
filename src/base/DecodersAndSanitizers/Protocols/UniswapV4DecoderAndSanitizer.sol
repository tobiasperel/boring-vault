// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract UniswapV2DecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================
   

    //============================== Universal Router ===============================
    //maybe use? 

    //============================== Pool Manager ===============================
    function swap(DecoderCustomTypes.PoolKey memory /*key*/, DecoderCustomTypes.SwapParams memory /*params*/, bytes calldata /*hookData*/ external pure returns (bytes memory addressesFound) {
        return addressesFound; 
    }
}
