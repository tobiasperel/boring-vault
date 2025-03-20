// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";


abstract contract ElixirClaimingDecoderAndSanitizer is BaseDecoderAndSanitizer {
    
    //validtion of the claim is handled by the airdrop, no need to sanitize anything
    function claim(uint256 /*_amount*/, bytes32[] calldata /*_merkleProof*/, bytes calldata /*_signature*/) external pure returns (bytes memory addressesFound) {
        return addressesFound; 
    }

}
