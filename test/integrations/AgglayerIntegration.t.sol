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
        _setupChain("mainnet", 22067550); 
            
        address agglayerDecoder = address(new FullAgglayerDecoderAndSanitizer()); 

        _overrideDecoder(agglayerDecoder); 
    }

    function testAgglayerBridgeAsset() external {
        _setUpMainnet(); 

        //to, from, destId, originId 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addAgglayerLeafs(leafs, toChain, fromChain);    

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        
        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve USDC
        tx_.manageLeafs[1] = leafs[1]; //bridgeAsset (USDC)

        
        tx_.targets[0] = waETHUSDC; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
    }

}
        
