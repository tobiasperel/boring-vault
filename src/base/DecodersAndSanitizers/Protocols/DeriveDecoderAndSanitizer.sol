// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract DeriveDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================
    
    DeriveDecoderAndSanitizer__OptionsLengthNonZero();  
    
    
    function bridge(
        address receiver_,
        uint256 /*amount_*/,
        uint256 /*msgGasLimit_*/,
        address connector_,
        bytes calldata extraData_,
        bytes calldata options_
    ) external pure virtual returns (bytes memory addressesFound) {
        if (options_.length > 0) revert DeriveDecoderAndSanitizer__OptionsLengthNonZero(); 
        (address user, address connectorPlugOnDeriveChain) = abi.decode(extraData_, address, address);  
        addressesFound = abi.encodePacked(receiver_, connector_, user, connectorPlugOnDeriveChain);  
    }

    function retry(
        address connector_,
        bytes32 /*messageId_*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(connector_); 
    }
    
}
