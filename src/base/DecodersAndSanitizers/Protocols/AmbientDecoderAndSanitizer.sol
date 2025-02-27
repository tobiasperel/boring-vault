// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract AmbientDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================

    function swap(
        address base,
        address quote,
        uint256 /*poolIdx*/,
        bool /*isBuy*/,
        bool /*inBaseQty*/,
        uint128 /*qty*/,
        uint16 /*tip*/,
        uint128 /*limitPrice*/,
        uint128 /*minOut*/,
        uint8 /*reserveFlags*/
    ) external pure virtual returns (bytes memory addressesFound) {
        //TODO: see if there are differences between pool indexes? 
        addressesFound = abi.encodePacked(base, quote); 
    }

    function userCmd (uint16 callpath, bytes calldata cmd) {
        //rip
    }
}
