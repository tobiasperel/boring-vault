// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";


abstract contract AgglayerDecoderAndSanitizer is BaseDecoderAndSanitizer {

    //============================== ERRORS ===============================
    error AgglayerDecoderAndSanitizer__PermitDataNonZero(); 

     function bridgeAsset(
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 /*amount*/,
        address token,
        bool /*forceUpdateGlobalExitRoot*/,
        bytes calldata /*permitData*/
    ) external pure virtual returns (bytes memory addressesFound) {
        if (permitData.length > 0) revert AgglayerDecoderAndSanitizer__PermitDataNonZero(); 

        address destinationNetwork0 = address(bytes20(bytes16(destinationNetwork)));
        address destinationNetwork1 = address(bytes20(bytes16(destinationNetwork << 128)));

        addressesFound = abi.encodePacked(destinationNetwork0, destinationNetwork1, destinationAddress, token); 
    }
    
    //tree depth: https://github.com/agglayer/ulxly-contracts/blob/ac153f7ca70d41f113820c5441363038a33baaef/contracts/v2/lib/DepositContractBase.sol#L15
    //TODO figure out if we need to sanitize `metadata` 
    function claimAsset(
        bytes32[32] calldata /*smtProofLocalExitRoot*/,
        bytes32[32] calldata /*smtProofRollupExitRoot*/,
        uint256 /*globalIndex*/,
        bytes32 /*mainnetExitRoot*/,
        bytes32 /*rollupExitRoot*/,
        uint32 originNetwork,
        address originTokenAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 /*amount*/,
        bytes calldata /*metadata*/
    ) external pure virtual returns (bytes memory addressesFound) {
        address originNetwork0 = address(bytes20(bytes16(originNetwork)));
        address originNetwork1 = address(bytes20(bytes16(originNetwork << 128)));

        address destinationNetwork0 = address(bytes20(bytes16(destinationNetwork)));
        address destinationNetwork1 = address(bytes20(bytes16(destinationNetwork << 128)));

        addressesFound = abi.encodePacked(originNetwork0, originNetwork1, originTokenAddress, destinationNetwork0, destinationNetwork1, destinationAddress); 
    }

    function bridgeMessage(
        uint32 destinationNetwork,
        address destinationAddress,
        bool /*forceUpdateGlobalExitRoot*/,
        bytes calldata /*metadata*/
    ) external pure virtual returns (bytes memory addressesFound) {
        address destinationNetwork0 = address(bytes20(bytes16(destinationNetwork)));
        address destinationNetwork1 = address(bytes20(bytes16(destinationNetwork << 128)));

        addressesFound = abi.encodePacked(destinationNetwork0, destinationNetwork1, destinationAddress); 
    }

    function bridgeMessageWETH(
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 /*amountWETH*/,
        bool /*forceUpdateGlobalExitRoot*/,
        bytes calldata /*metadata*/
    ) external pure virtual returns (bytes memory addressesFound) {
        address destinationNetwork0 = address(bytes20(bytes16(destinationNetwork)));
        address destinationNetwork1 = address(bytes20(bytes16(destinationNetwork << 128)));

        addressesFound = abi.encodePacked(destinationNetwork0, destinationNetwork1, destinationAddress); 
    }
    
    function claimMessage(
        bytes32[32] calldata /*smtProofLocalExitRoot*/,
        bytes32[32] calldata /*smtProofRollupExitRoot*/,
        uint256 /*globalIndex*/,
        bytes32 /*mainnetExitRoot*/,
        bytes32 /*rollupExitRoot*/,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 /*amount*/,
        bytes calldata /*metadata*/
    ) external pure virtual returns (bytes memory addressesFound) {
        address originNetwork0 = address(bytes20(bytes16(originNetwork)));
        address originNetwork1 = address(bytes20(bytes16(originNetwork << 128)));

        address destinationNetwork0 = address(bytes20(bytes16(destinationNetwork)));
        address destinationNetwork1 = address(bytes20(bytes16(destinationNetwork << 128)));

        addressesFound = abi.encodePacked(originNetwork0, originNetwork1, originTokenAddress, destinationNetwork0, destinationNetwork1, destinationAddress); 
    }
}
