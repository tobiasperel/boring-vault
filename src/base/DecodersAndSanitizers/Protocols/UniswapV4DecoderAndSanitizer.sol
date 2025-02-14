// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {Actions, Commands} from "src/interfaces/UniswapV4Actions.sol"; 

//TODO remove
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

abstract contract UniswapV4DecoderAndSanitizer is BaseDecoderAndSanitizer, Test {
    //============================== ERRORS ===============================

    error UniswapV4DecoderAndSanitizer__NotSwapInput(); 
    error UniswapV4DecoderAndSanitizer__UnsupportedAction(); 
    error UniswapV4DecoderAndSanitizer__UnsupportedSubAction(); 
   
    //TODO bytes are cringe but this might work better for our use case //============================== Universal Router ===============================
    
    // @dev in order to sanitize we require that only command be passed in a time. This defeats the ability to batch commands together, but is necessary to avoid having a gajillion leaves for all possible orders that can be used here
    // @dev inputs can be grouped together based on common things, ie. swaps will always be swap, settle, take, etc. 
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 /*deadline*/) external pure returns (bytes memory addressesFound) {
        // Verify exactly 1 byte
        require(commands.length == 1, "Invalid commands length");
        // Extract and verify command
        uint8 command = uint8(commands[0]);
        if (command == uint8(Commands.V4_SWAP)) {

            // Extract the path from PoolKey
            (bytes memory actions, bytes[] memory params) = abi.decode(inputs[0], (bytes, bytes[]));

            if (uint8(actions[0]) != uint8(Actions.SWAP_EXACT_IN_SINGLE)) revert UniswapV4DecoderAndSanitizer__NotSwapInput(); 

            // Decode the first param which should be our ExactInputSingleParams struct
            DecoderCustomTypes.ExactInputSingleParams memory swapParams = abi.decode(params[0], (DecoderCustomTypes.ExactInputSingleParams));

            // Extract addresses from poolKey
            address currency0 = address(swapParams.poolKey.currency0);
            address currency1 = address(swapParams.poolKey.currency1);

            addressesFound = abi.encodePacked(address(uint160(command)), currency0, currency1);  
        } else {
            //only support v4 swaps via the universal router
            revert UniswapV4DecoderAndSanitizer__NotSwapInput();  
        }
    }

    //============================== Permit2 ===============================
    
    function approve(address token, address spender, uint160 /*amount*/, uint48 /*expiraton*/) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(token, spender); 
    } 

    //============================== Position Manager ===============================
    
    //TODO sanitize 
    function modifyLiquidities(bytes calldata unlockData, uint256 /*deadline*/) external view returns (bytes memory addressesFound) { 
        // First decode the outer tuple (actions, params)
        (bytes memory actions, bytes[] memory params) = abi.decode(unlockData, (bytes, bytes[]));
        
        uint8 action = uint8(bytes1(actions[0]));
        if (action == uint8(Actions.MINT_POSITION)) {
        //TODO do we sanitize the hook address (from pool key)? potentially yes?  
             (
                DecoderCustomTypes.PoolKey memory poolKey,
                /*int24 tickLower*/,
                /*int24 tickUpper*/,
                /*uint256 liquidity*/,
                /*uint128 amount0Max*/,
                /*uint128 amount1Max*/,
                address recipient,
                /*bytes memory hookData*/
            ) = abi.decode(params[0], (DecoderCustomTypes.PoolKey, int24, int24, uint256, uint128, uint128, address, bytes));
            
            // Ensure we're settling the correct pair 
            (address currency0Settle, address currency1Settle) = abi.decode(params[1], (address, address)); 
              
            addressesFound = abi.encodePacked(poolKey.currency0, poolKey.currency1, recipient, currency0Settle, currency1Settle); 
            return addressesFound;             
         
        } else if (action == uint8(Actions.INCREASE_LIQUIDITY)) {
           //params0 we don't care about here, but we need to check if we are settling, closing, or clearing and taking 
            uint8 subAction = uint8(bytes1(actions[1])); 
            if (subAction == uint8(Actions.SETTLE_PAIR)) {
                (address currency0Settle, address currency1Settle) = abi.decode(params[1], (address, address)); 
                
                addressesFound = abi.encodePacked(currency0Settle, currency1Settle); 
            } else if (subAction == uint8(Actions.CLOSE_CURRENCY)) {
                (address currency0Settle) = abi.decode(params[1], (address)); 
                (address currency1Settle) = abi.decode(params[2], (address)); 
                
                addressesFound = abi.encodePacked(currency0Settle, currency1Settle); 

            } else if (subAction == uint8(Actions.CLEAR_OR_TAKE)) {
                (address currency0Settle, ) = abi.decode(params[1], (address, uint256)); 
                (address currency1Settle, ) = abi.decode(params[2], (address, uint256)); 

                addressesFound = abi.encodePacked(currency0Settle, currency1Settle); 
            } else {
                revert UniswapV4DecoderAndSanitizer__UnsupportedSubAction(); 
            }
        } else if (action == uint8(Actions.DECREASE_LIQUIDITY)) {

            uint8 subAction = uint8(bytes1(actions[1])); 
            if (subAction == uint8(Actions.TAKE_PAIR)) {
               
                (address currency0Settle, address currency1Settle, address recipient) = abi.decode(params[1], (address, address, address)); 

                addressesFound = abi.encodePacked(currency0Settle, currency1Settle, recipient); 

            } else if (subAction == uint8(Actions.CLOSE_CURRENCY)) {
                (address currency0Settle) = abi.decode(params[1], (address)); 
                (address currency1Settle) = abi.decode(params[2], (address)); 
                
                addressesFound = abi.encodePacked(currency0Settle, currency1Settle); 

            } else if (subAction == uint8(Actions.CLEAR_OR_TAKE)) {
                (address currency0Settle, ) = abi.decode(params[1], (address, uint256)); 
                (address currency1Settle, ) = abi.decode(params[2], (address, uint256)); 

                addressesFound = abi.encodePacked(currency0Settle, currency1Settle); 

            } else {
                revert UniswapV4DecoderAndSanitizer__UnsupportedSubAction(); 
            }
        } else if (action == uint8(Actions.BURN_POSITION)) {
            
            //burn requires a TAKE_PAIR but has no params necessary to sanitize as they are all uints or hook data 
            (address currency0Settle, address currency1Settle, address recipient) = abi.decode(params[1], (address, address, address)); 

                addressesFound = abi.encodePacked(currency0Settle, currency1Settle, recipient); 

        } else {
            revert UniswapV4DecoderAndSanitizer__UnsupportedAction(); 
        }
    }
}
