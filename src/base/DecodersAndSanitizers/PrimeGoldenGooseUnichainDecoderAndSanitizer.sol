// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {UniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {MorphoBlueDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MorphoBlueDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {EulerEVKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {StandardBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";

contract PrimeGoldenGooseUnichainDecoderAndSanitizer is 
    BaseDecoderAndSanitizer,
    UniswapV4DecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    MorphoBlueDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    EulerEVKDecoderAndSanitizer,
    StandardBridgeDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    OneInchDecoderAndSanitizer
{
    constructor(
        address _uniswapV4PositionManager,
        address _odosRouter
    )
        UniswapV4DecoderAndSanitizer(_uniswapV4PositionManager)
        OdosDecoderAndSanitizer(_odosRouter)
    {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================
    
    /**
     * @notice TellerDecoderAndSanitizer and ERC4626DecoderAndSanitizer both specify a deposit function
     * ERC4626: deposit(uint256,address)
     * Teller: deposit(address,uint256,uint256)
     * These have different signatures so no conflict exists
     */

    /**
     * @notice ERC4626DecoderAndSanitizer specifies withdraw(uint256,address,address)
     * MorphoBlueDecoderAndSanitizer specifies withdraw(MarketParams,uint256,uint256,address,address)
     * NativeWrapperDecoderAndSanitizer specifies withdraw(uint256)
     * These have different signatures so no conflict exists
     */
}