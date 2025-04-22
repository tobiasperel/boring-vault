// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";


abstract contract DvStETHDecoderAndSanitizer is BaseDecoderAndSanitizer {


    function deposit(
        address to,
        uint256[] memory /*amounts*/,
        uint256 /*minLpAmount*/,
        uint256 /*deadline*/,
        uint256 /*referralCode*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to); 
    }

    function registerWithdrawal(
        address to,
        uint256 /*lpAmount*/,
        uint256[] memory /*minAmounts*/,
        uint256 /*deadline*/,
        uint256 /*requestDeadline*/,
        bool /*closePrevious*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to); 
    }

    function cancelWithdrawalRequest() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    function emergencyWithdraw(uint256[] memory /*minAmounts*/, uint256 /*deadline*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }


}

