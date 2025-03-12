// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract BalancerV2DecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================
    
    // TODO decide on what we want to do for userData
    // afaict this is reliant on what type of pool we are adding liquidity into? 
    // if we disable any bytes being passed, will it bork certain pools? 
    
    
    // Router 
    // Add Liquidity
    function addLiquidityProportional(
    address pool,
    uint256[] memory /*maxAmountsIn*/,
    uint256 /*exactBptAmountOut*/,
    bool /*wethIsEth*/,
    bytes memory /*userData*/
    ) external pure virtual returns (bytes memory addressesFound) {

        addressesFound = abi.encodePacked(pool); 
    }

    function addLiquidityUnbalanced(
        address pool,
        uint256[] memory /*exactAmountsIn*/,
        uint256 /*minBptAmountOut*/,
        bool /*wethIsEth*/,
        bytes memory /*userData*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(pool); 
    }

    function addLiquiditySingleTokenExactOut(
        address pool,
        address tokenIn,
        uint256 /*maxAmountIn*/,
        uint256 /*exactBptAmountOut*/,
        bool /*wethIsEth*/,
        bytes memory /*userData*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(pool, tokenIn); 
    }

     function addLiquidityCustom(
        address pool,
        uint256[] memory /*maxAmountsIn*/,
        uint256 /*minBptAmountOut*/,
        bool /*wethIsEth*/,
        bytes memory /*userData*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(pool); 
    }
   
    // Remove Liquidity
    function removeLiquidityProportional(
        address pool,
        uint256 /*exactBptAmountIn*/,
        uint256[] memory /*minAmountsOut*/,
        bool /*wethIsEth*/,
        bytes memory /*userData*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(pool); 
    }

     function removeLiquiditySingleTokenExactIn(
        address pool,
        uint256 /*exactBptAmountIn*/,
        address /*tokenOut*/,
        uint256 /*minAmountOut*/,
        bool /*wethIsEth*/,
        bytes memory /*userData*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(pool); 
    }

    function removeLiquiditySingleTokenExactOut(
        address pool,
        uint256 /*maxBptAmountIn*/,
        IERC20 /*tokenOut*/,
        uint256 /*exactAmountOut*/,
        bool /*wethIsEth*/
        bytes memory /*userData*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(pool); 
    }

     function removeLiquidityCustom(
        address pool,
        uint256 /*maxBptAmountIn*/,
        uint256[] memory /*minAmountsOut*/,
        bool /*wethIsEth*/,
        bytes memory /*userData*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(pool); 
    }

    function removeLiquidityRecovery(
        address pool,
        uint256 /*exactBptAmountIn*/,
        uint256[] memory /*minAmountsOut*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(pool); 
    }
    
    // Swaps   
     function swapSingleTokenExactIn(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 /*exactAmountIn*/,
        uint256 /*minAmountOut*/,
        uint256 /*deadline*/,
        bool /*wethIsEth*/,
        bytes calldata /*userData*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(pool, tokenIn, tokenOut); 
    } 

    function swapSingleTokenExactOut(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 /*exactAmountOut*/,
        uint256 /*maxAmountIn*/,
        uint256 /*deadline*/,
        bool /*wethIsEth*/,
       bytes calldata userData
    ) external
}
