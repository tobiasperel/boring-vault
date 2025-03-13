// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {BalancerV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV3DecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullBalancerV3DecoderAndSanitizer is BalancerV3DecoderAndSanitizer {}

contract BalancerV3IntegrationTest is BaseTestIntegration {


    function setUp() public override {
        super.setUp(); 
        _setupChain("mainnet", 22038923); 
            
        address balancerV3Decoder = address(new FullBalancerV3DecoderAndSanitizer()); 
        overrideDecoder(balancerV3Decoder); 
            
    }


    function testBalancerFullDepoistFlow() external {
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6); 

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), boosted); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve permit2 
        manageLeafs[1] = leafs[1]; //use permit2 to approve router

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);
        
        //comes from balancer pool FE 
        address waETHUSDC = 0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E;  

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "USDC"); //approve 
        targets[1] = getAddress(sourceChain, "waETHUSDC"); //

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "deposit(uint256,address)", 1_000e6, address(boringVault)  
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2); 

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

    }
}
