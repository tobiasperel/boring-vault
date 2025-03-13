// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";


abstract contract Permit2DecoderAndSanitizer is BaseDecoderAndSanitizer {
    
    function approve(address token, address spender, uint160 /*amount*/, uint48 /*expiraton*/) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(token, spender);
    }
}
