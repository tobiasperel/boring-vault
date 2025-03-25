// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {DeriveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DeriveDecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullDeriveDecoderAndSanitizer is DeriveDecoderAndSanitizer {}

contract DeriveDecoderAndSanitizer is BaseTestIntegration {

    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 22067550); 
            
        address deriveDecoder = address(new FullDeriveDecoderAndSanitizer()); 

        _overrideDecoder(deriveDecoder); 
    }


    function testDeriveDeposit() internal {
        _setUpMainnet(); 
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6); 

        address connectorPlugOnDeriveChain = 0x2e1245d57a304c7314687e529d610071628117f3;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addDeriveVaultLeafs(
            leafs, 
            getAddress(sourceChain, "derive_LBTC_basis_deposit"),
            getAddress(sourceChain, "derive_LBTC_basis_deposit_connector"),
            getAddress(sourceChain, "derive_LBTC_basis_withdraw"),
            getAddress(sourceChain, "derive_LBTC_basis_withdraw_connector"),
            connectorPlugOnDeriveChain,            
            getAddress(sourceChain, "derive_boringTestVault_wallet")
        ); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(3); 
        
        //manage leafs
        tx_.manageLeafs[0] = leafs[0]; //approve LBTC
        tx_.manageLeafs[1] = leafs[1]; //approve bLBTC (basis traded lbtc)
        tx_.manageLeafs[2] = leafs[2]; //bridge LBTC (deposit)

        //generate proofs
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "LBTC"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "derive_LBTC_basis_token"); //approve 
        tx_.targets[2] = getAddress(sourceChain, "derive_LBTC_basis_deposit"); //bridge() (deposit vault)

        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "derive_LBTC_basis_deposit"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "derive_LBTC_basis_withdraw"), type(uint256).max
        
        bytes memory extraDepositData = abi.encode(address(boringVault), connectorPlugOnDeriveChain);  

        tx_.targetData[2] = abi.encodeWithSignature(
            "bridge(address,uint256,uint256,address,bytes,bytes)",  
            getAddress(sourceChain, "derive_boringTestVault_wallet"),
            0.1e8, 
            2000000,
            0x457379de638CAFeB1759a22457fe893b288E2e89, //connector
            extraDepositData, 
            ""
        );
        
        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        
        //submit the call 
        _submitManagerCall(manageProofs, tx_); 

    }

}
