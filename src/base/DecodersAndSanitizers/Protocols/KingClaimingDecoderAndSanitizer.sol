// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract KingClaimingDecoderAndSanitizer is BaseDecoderAndSanitizer {
    
    
    function claim(
        address account,
        uint256 /*cumulativeAmount*/,
        bytes32 /*expectedMerkleRoot*/,
        bytes32[] calldata /*merkleProof*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(account); 
    }

}
