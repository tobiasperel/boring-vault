// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract CompoundV2DecoderAndSanitizer is BaseDecoderAndSanitizer {
    // ============================== Ctoken ===============================
    function mint(uint256 /*mintAmount*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function redeem(uint256 /*redeemTokens*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function redeemUnderlying(uint256 /*redeemAmount*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function borrow(uint256 /*borrowAmount*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function repayBorrow(uint256 /*repayAmount*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    // ============================== CNative ===============================
    function mint() external payable virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function repayBorrow() external payable virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
