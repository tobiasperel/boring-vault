// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AgglayerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AgglayerDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullAgglayerDecoderAndSanitizer is AgglayerDecoderAndSanitizer{}


contract AgglayerIntegrationTest is BaseTestIntegration {


    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 22338950); 
            
        address agglayerDecoder = address(new FullAgglayerDecoderAndSanitizer()); 

        _overrideDecoder(agglayerDecoder); 
    }

    function testAgglayerBridgeAsset() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100e6);  
        deal(address(boringVault), 1e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);


        uint32 toChain = uint32(3); 
        uint32 fromChain = uint32(0); 
        address zkEVMBridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
        _addAgglayerTokenLeafs(
            leafs, 
            zkEVMBridge,
            getAddress(sourceChain, "USDC"),
            fromChain,
            toChain 
        );    

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        
        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve USDC
        tx_.manageLeafs[1] = leafs[1]; //bridgeAsset (USDC)

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "USDC"); //approve 
        tx_.targets[1] = zkEVMBridge;  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", zkEVMBridge, type(uint256).max
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "bridgeAsset(uint32,address,uint256,address,bool,bytes)",
            toChain, 
            address(boringVault),
            100e6,
            getAddress(sourceChain, "USDC"), 
            true,
            ""
        ); 


        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
    }


    function testAgglayerBridgeMessage() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100e6);  
        deal(address(boringVault), 1e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);


        uint32 toChain = uint32(3); 
        uint32 fromChain = uint32(0); 
        address zkEVMBridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
        _addAgglayerTokenLeafs(
            leafs, 
            zkEVMBridge,
            getAddress(sourceChain, "USDC"),
            fromChain,
            toChain 
        );    

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        
        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve USDC
        tx_.manageLeafs[1] = leafs[3]; //bridgeMessage (USDC)

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "USDC"); //approve 
        tx_.targets[1] = zkEVMBridge;  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", zkEVMBridge, type(uint256).max
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "bridgeAsset(uint32,address,uint256,address,bool,bytes)",
            toChain, 
            address(boringVault),
            100e6,
            getAddress(sourceChain, "USDC"), 
            true,
            ""
        ); 


        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
    }

}
        
