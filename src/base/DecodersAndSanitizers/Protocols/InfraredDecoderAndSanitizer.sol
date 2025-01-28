// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract InfraredDecoderAndSanitizer is BaseDecoderAndSanitizer {
    
    function stake(uint256 /*amount*/) external pure returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    function withdraw(uint256 /*amount*/) external pure returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    function getRewardForUser(address receiver) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver); 
    }

    function getReward() external pure returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    function exit() external pure returns (bytes memory addressesFound) {
        return addressesFound; 
    }

}
