// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";  

abstract contract EulerEVKDecoderAndSanitizer is BaseDecoderAndSanitizer, ERC4626DecoderAndSanitizer {

    constructor (address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}
   
    function borrow(uint256 /*amount*/, address receiver) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(receiver); 
    }

    function repay(uint256 /*amount*/, address receiver) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(receiver); 
    }

    function repayWithShares(uint256 /*amount*/, address receiver) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(receiver); 
    }
}
