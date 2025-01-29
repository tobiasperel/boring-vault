// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";


abstract contract GoldiVaultDecoderAndSanitizer is BaseDecoderAndSanitizer {


    function deposit(uint256 /*amount*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    function redeemOwnership(uint256 /*amount*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;  
    }

    function redeemYield(uint256 /*amount*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }

}
