// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";


abstract contract OdosDecoderAndSanitizer is BaseDecoderAndSanitizer {

    function swap(
        DecoderCustomTypes.swapTokenInfo memory tokenInfo,
        bytes calldata /*pathDefinition*/,
        address executor,
        uint32 /*referralCode*/
    ) external pure virtual returns (bytes memory addressesFound) {
        
        addressesFound = abi.encodePacked(tokenInfo.inputToken, tokenInfo.inputReceiver, tokenInfo.outputToken, tokenInfo.outputReceiver, executor); 

    }

    function swapCompact() external view virtual returns (bytes memory addressesFound) {
        DecoderCustomTypes.swapTokenInfo memory tokenInfo;
        address executor;
        uint32 referralCode;
        bytes calldata pathDefinition;
        
        // Reference to the OdosRouterV2 contract
        IOdosRouterV2 odosRouter = IOdosRouterV2(0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559); //temp
        
        {
            address msgSender = msg.sender;
            assembly {
                // Assembly function to get address from calldata
                function getAddress(currPos) -> result, newPos {
                    let inputPos := shr(240, calldataload(currPos))
                    
                    switch inputPos
                    // Reserve the null address as a special case that can be specified with 2 null bytes
                    case 0x0000 {
                        result := 0
                        newPos := add(currPos, 2)
                    }
                    // This case means that the address is encoded in the calldata directly following the code
                    case 0x0001 {
                        result := and(shr(80, calldataload(currPos)), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                        newPos := add(currPos, 22)
                    }
                    // For addresses from the addressList, we'll just store the index for later retrieval
                    default {
                        // Store a marker in the high bits and the index in the low bits
                        // We'll use this later to know we need to look up from addressList
                        result := or(0x1000000000000000000000000000000000000000, sub(inputPos, 2))
                        newPos := add(currPos, 2)
                    }
                }
                
                let result := 0
                let pos := 4

                // Load in the input and output token addresses
                result, pos := getAddress(pos)
                mstore(tokenInfo, result)

                result, pos := getAddress(pos)
                mstore(add(tokenInfo, 0x60), result)

                // Load in the input amount - a 0 byte means the full balance is to be used
                let inputAmountLength := shr(248, calldataload(pos))
                pos := add(pos, 1)

                if inputAmountLength {
                  mstore(add(tokenInfo, 0x20), shr(mul(sub(32, inputAmountLength), 8), calldataload(pos)))
                  pos := add(pos, inputAmountLength)
                }

                // Load in the quoted output amount
                let quoteAmountLength := shr(248, calldataload(pos))
                pos := add(pos, 1)

                let outputQuote := shr(mul(sub(32, quoteAmountLength), 8), calldataload(pos))
                mstore(add(tokenInfo, 0x80), outputQuote)
                pos := add(pos, quoteAmountLength)

                // Load the slippage tolerance and use to get the minimum output amount
                {
                  let slippageTolerance := shr(232, calldataload(pos))
                  mstore(add(tokenInfo, 0xA0), div(mul(outputQuote, sub(0xFFFFFF, slippageTolerance)), 0xFFFFFF))
                }
                pos := add(pos, 3)

                // Load in the executor address
                executor, pos := getAddress(pos)

                // Load in the destination to send the input to - Zero denotes the executor
                result, pos := getAddress(pos)
                if eq(result, 0) { result := executor }
                mstore(add(tokenInfo, 0x40), result)

                // Load in the destination to send the output to - Zero denotes msg.sender
                result, pos := getAddress(pos)
                if eq(result, 0) { result := msgSender }
                mstore(add(tokenInfo, 0xC0), result)

                // Load in the referralCode
                referralCode := shr(224, calldataload(pos))
                pos := add(pos, 4)

                // Set the offset and size for the pathDefinition portion of the msg.data
                pathDefinition.length := mul(shr(248, calldataload(pos)), 32)
                pathDefinition.offset := add(pos, 1)
            }
        }

        // For inputToken
        if (isAddressMarked(tokenInfo.inputToken)) {
            tokenInfo.inputToken = odosRouter.addressList(extractIndex(tokenInfo.inputToken));
        }
        
        // For outputToken
        if (isAddressMarked(tokenInfo.outputToken)) {
            tokenInfo.outputToken = odosRouter.addressList(extractIndex(tokenInfo.outputToken));
        }
        
        // For executor
        if (isAddressMarked(executor)) {
            executor = odosRouter.addressList(extractIndex(executor));
        }


        addressesFound = abi.encodePacked(tokenInfo.inputToken, tokenInfo.inputReceiver, tokenInfo.outputToken, tokenInfo.outputReceiver, executor); 
    }

    // Helper Functions

    function isAddressMarked(address addr) private pure returns (bool) {
        return uint256(uint160(addr)) >= 2**160;
    }
    
    function extractIndex(address addr) private pure returns (uint256) {
        return uint256(uint160(addr)) & uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

} 


interface IOdosRouterV2 {
    function addressList(uint256 index) external view returns (address); 
}
