// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BalancerV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV3DecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullBalancerV3DecoderAndSanitizer is BalancerV3DecoderAndSanitizer {}

contract BalancerV3IntegrationTest is BaseTestIntegration {
        
    //comes from balancer pool FE 
    address waETHUSDC = 0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E; //where ETH means mainnet not ETH currency
    address waETHUSDT = 0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8; //where ETH means mainnet not ETH currency
    address waETHGHO = 0xC71Ea051a5F82c67ADcF634c36FFE6334793D24C; //where ETH means mainnet not ETH currency

    address waETHWETH = 0x0FE906e030a44eF24CA8c7dC7B7c53A6C4F00ce9;  
    address waETHWSTETH = 0x775F661b0bD1739349b9A2A3EF60be277c5d2D29;  

    function setUp() public override {
        super.setUp(); 
        _setupChain("mainnet", 22067550); 
            
        address balancerV3Decoder = address(new FullBalancerV3DecoderAndSanitizer()); 

        _overrideDecoder(balancerV3Decoder); 
    }

    function testBalancerAddRemoveLiqProportional() external {
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6); 
        deal(waETHUSDC, address(boringVault), 1_000e18); 
        deal(waETHUSDT, address(boringVault), 1_000e18); 
        deal(waETHGHO, address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), boosted); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(8); 

        tx_.manageLeafs[0] = leafs[19]; //approve permit2 USDC
        tx_.manageLeafs[1] = leafs[20]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[5]; //approve permit2 USDT
        tx_.manageLeafs[3] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[4] = leafs[12]; //approve permit2 GHO
        tx_.manageLeafs[5] = leafs[13]; //use permit2 to approve router
        tx_.manageLeafs[6] = leafs[21]; //use permit2 to approve router

        tx_.manageLeafs[7] = leafs[22]; //addLiqProportional

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = waETHUSDC; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = waETHUSDT; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[4] = waETHGHO; //approve 
        tx_.targets[5] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[6] = getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"); //approve 
        
        //router calls
        tx_.targets[7] = getAddress(sourceChain, "balancerV3Router"); //addLiqProportional

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHUSDC, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHUSDT, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[5] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHGHO, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[6] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](3); 
        amounts[0] = 10e18;  
        amounts[1] = 10e18;  
        amounts[2] = 10e18;  

        tx_.targetData[7] = abi.encodeWithSignature(
            "addLiquidityProportional(address,uint256[],uint256,bool,bytes)", getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), amounts, 1e8, false, "" 
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get LP tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_USDC_GHO_USDT").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(1 days); 

        // Try unbalanced method
        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[26]; 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3Router"); 

        amounts[0] = 0;  
        amounts[1] = 0;  
        amounts[2] = 0;  

        tx_.targetData[0] = abi.encodeWithSignature(
            "removeLiquidityProportional(address,uint256,uint256[],bool,bytes)", getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), lpBalance, amounts, false, "" 
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have more LP now
        uint256 lpBalance2 = getERC20(sourceChain, "balancerV3_USDC_GHO_USDT").balanceOf(address(boringVault)); 
        assertEq(lpBalance2, 0); 
    }

    function testBalancerAddRemoveLiqSingleTokenExactOut() external {
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6); 
        deal(waETHUSDC, address(boringVault), 1_000e18); 
        deal(waETHUSDT, address(boringVault), 1_000e18); 
        deal(waETHGHO, address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), boosted); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(8); 

        tx_.manageLeafs[0] = leafs[19]; //approve permit2 USDC
        tx_.manageLeafs[1] = leafs[20]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[5]; //approve permit2 USDT
        tx_.manageLeafs[3] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[4] = leafs[12]; //approve permit2 GHO
        tx_.manageLeafs[5] = leafs[13]; //use permit2 to approve router
        tx_.manageLeafs[6] = leafs[21]; //use permit2 to approve router

        tx_.manageLeafs[7] = leafs[24]; //addLiqUnbalanced

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = waETHUSDC; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = waETHUSDT; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[4] = waETHGHO; //approve 
        tx_.targets[5] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[6] = getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"); //approve 
        //router calls
        tx_.targets[7] = getAddress(sourceChain, "balancerV3Router"); //addLiqUnbalanced

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHUSDC, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHUSDT, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[5] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHGHO, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[6] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](3); 
        amounts[0] = 10e18;  
        amounts[1] = 0;  
        amounts[2] = 0;  

        tx_.targetData[7] = abi.encodeWithSignature(
            "addLiquiditySingleTokenExactOut(address,address,uint256,uint256,bool,bytes)", 
            getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"),
            waETHUSDC,
            10e18,
            1e8,
            false,
            "" 
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get LP tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_USDC_GHO_USDT").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(1 days); 

        // Try unbalanced method
        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[26]; 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3Router"); 

        amounts[0] = 0;  
        amounts[1] = 0;  
        amounts[2] = 0;  

        tx_.targetData[0] = abi.encodeWithSignature(
            "removeLiquidityProportional(address,uint256,uint256[],bool,bytes)", getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), lpBalance, amounts, false, "" 
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have more LP now
        uint256 lpBalance2 = getERC20(sourceChain, "balancerV3_USDC_GHO_USDT").balanceOf(address(boringVault)); 
        assertEq(lpBalance2, 0); 
    }

    function testBalancerAddRemoveLiqUnbalanced() external {
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        deal(waETHWETH, address(boringVault), 1_000e18); 
        deal(waETHWSTETH, address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"), boosted); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(6); 

        tx_.manageLeafs[0] = leafs[5]; //approve permit2 WETH
        tx_.manageLeafs[1] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[12]; //approve permit2 WSTETH
        tx_.manageLeafs[3] = leafs[13]; //use permit2 to approve router
        tx_.manageLeafs[4] = leafs[14]; //approve router to spend bpt
        
        //router calls
        tx_.manageLeafs[5] = leafs[16]; //addLiqUnbalanced

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = waETHWETH; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = waETHWSTETH; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[4] = getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"); //approve 
        //router calls
        tx_.targets[5] = getAddress(sourceChain, "balancerV3Router"); //addLiqUnbalanced

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWSTETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 1e18;  
        amounts[1] = 0;  

        tx_.targetData[5] = abi.encodeWithSignature(
            "addLiquidityUnbalanced(address,uint256[],uint256,bool,bytes)", 
            getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"),
            amounts,
            1e8,
            false,
            "" 
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get LP tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_WETH_WSTETH_boosted").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(1 days); 

        // Try unbalanced method
        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[19]; 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3Router"); 

        amounts[0] = 0;  
        amounts[1] = 0;  

        tx_.targetData[0] = abi.encodeWithSignature(
            "removeLiquidityProportional(address,uint256,uint256[],bool,bytes)", getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"), lpBalance, amounts, false, "" 
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have more LP now
        uint256 lpBalance2 = getERC20(sourceChain, "balancerV3_WETH_WSTETH_boosted").balanceOf(address(boringVault)); 
        assertEq(lpBalance2, 0); 
    }

    function testBalancerAddRemoveLiqSingleTokenExactIn() external {
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        deal(waETHWETH, address(boringVault), 1_000e18); 
        deal(waETHWSTETH, address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"), boosted); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(6); 

        tx_.manageLeafs[0] = leafs[5]; //approve permit2 WETH
        tx_.manageLeafs[1] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[12]; //approve permit2 WSTETH
        tx_.manageLeafs[3] = leafs[13]; //use permit2 to approve router
        tx_.manageLeafs[4] = leafs[14]; //approve router to spend bpt
        
        //router calls
        tx_.manageLeafs[5] = leafs[16]; //addLiqUnbalanced

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = waETHWETH; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = waETHWSTETH; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[4] = getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"); //approve 
        //router calls
        tx_.targets[5] = getAddress(sourceChain, "balancerV3Router"); //addLiqUnbalanced

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWSTETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 0.1e18;  
        amounts[1] = 0;  

        tx_.targetData[5] = abi.encodeWithSignature(
            "addLiquidityUnbalanced(address,uint256[],uint256,bool,bytes)", 
            getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"),
            amounts,
            1e2,
            false,
            "" 
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get LP tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_WETH_WSTETH_boosted").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(1 days); 

        // Try unbalanced method
        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[20]; 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3Router"); 

        tx_.targetData[0] = abi.encodeWithSignature(
            "removeLiquiditySingleTokenExactIn(address,uint256,address,uint256,bool,bytes)", getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"), lpBalance, waETHWETH, 10, false, "" 
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have 0 lp left
        uint256 lpBalance2 = getERC20(sourceChain, "balancerV3_WETH_WSTETH_boosted").balanceOf(address(boringVault)); 
        assertEq(lpBalance2, 0); 
    }

    function testBalancerRemoveLiqSingleTokenExactOut() external {
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        //deal(waETHWETH, address(boringVault), 1_000e18); 
        deal(waETHWSTETH, address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"), boosted); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(6); 

        tx_.manageLeafs[0] = leafs[5]; //approve permit2 WETH
        tx_.manageLeafs[1] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[12]; //approve permit2 WSTETH
        tx_.manageLeafs[3] = leafs[13]; //use permit2 to approve router
        tx_.manageLeafs[4] = leafs[14]; //approve router to spend bpt
        
        //router calls
        tx_.manageLeafs[5] = leafs[16]; //addLiqUnbalanced

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = waETHWETH; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = waETHWSTETH; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[4] = getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"); //approve 
        //router calls
        tx_.targets[5] = getAddress(sourceChain, "balancerV3Router"); //addLiqUnbalanced

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWSTETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 0;  
        amounts[1] = 0.1e18;  

        tx_.targetData[5] = abi.encodeWithSignature(
            "addLiquidityUnbalanced(address,uint256[],uint256,bool,bytes)", 
            getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"),
            amounts,
            1e2,
            false,
            "" 
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get LP tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_WETH_WSTETH_boosted").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(1 days); 

        // Try unbalanced method
        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[21]; 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3Router"); 

        tx_.targetData[0] = abi.encodeWithSignature(
            "removeLiquiditySingleTokenExactOut(address,uint256,address,uint256,bool,bytes)", getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"), lpBalance, waETHWETH, 1e8, false, "" 
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have 1e8 waETHWETH out
        uint256 waETHWETHBalance = ERC20(waETHWETH).balanceOf(address(boringVault)); 
        assertEq(waETHWETHBalance, 1e8); 
    }

    function testBalancerV3Swap__ExactIn() external {
        
        deal(waETHWETH, address(boringVault), 1_000e18); 
        deal(waETHWSTETH, address(boringVault), 1_000e18); 
        
        //swapping assumes you already have the necessary tokens to swap into the pool
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBalancerV3SwapLeafs(leafs, getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted")); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(3); 
        
        tx_.manageLeafs[0] = leafs[0]; //approve waWETH
        tx_.manageLeafs[1] = leafs[1]; //apporve waWSTETH
        tx_.manageLeafs[2] = leafs[2]; //swapExactIn
        

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        //targets
        tx_.targets[0] = waETHWETH; //approve 
        tx_.targets[1] = waETHWSTETH; //approve 
        tx_.targets[2] = getAddress(sourceChain, "balancerV3Router"); //addLiqUnbalanced
        
        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Vault"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Vault"), type(uint256).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "swapSingleTokenExactIn(address,address,address,uint256,uint256,uint256,bool,bytes)", 
            getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"),
            waETHWETH,
            waETHWSTETH,
            1e18, //in
            1, //min out
            block.timestamp + 1,
            false,
            bytes("")
        );
        
        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get LP tokens 
        //uint256 lpBalance = getERC20(sourceChain, "balancerV3_WETH_WSTETH_boosted").balanceOf(address(boringVault)); 
        //assertGt(lpBalance, 0); 
    }



}
