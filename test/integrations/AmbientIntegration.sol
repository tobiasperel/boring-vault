// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {AmbientDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AmbientDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract AmbientIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    function setUp() external {
        setSourceChainName("swell");
        // Setup forked environment.
        string memory rpcKey = "SWELL_CHAIN_RPC_URL";
        uint256 blockNumber = 4242847;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new FullAmbientDecoderAndSanitizer()
        );

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MANGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true); }

    function testAmbientLiquidityWarmPath__Concentrated() external {
        deal(address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDE"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        
        address baseToken= getAddress(sourceChain, "ETH");  
        address quoteToken = getAddress(sourceChain, "USDE");  

        _addAmbientLPLeafs(leafs, baseToken, quoteToken);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve USDE
        manageLeafs[1] = leafs[1]; //mint USDE/ETH 

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "USDE");
        targets[1] = getAddress(sourceChain, "crocSwapDex");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "crocSwapDex"), type(uint256).max
        );
        // Mint concentrated lp position params
        //
        //(uint8 code, address base, address quote, uint256 poolIdx,
        // int24 bidTick, int24 askTick, uint128 liq,
        // uint128 limitLower, uint128 limitHigher,
        // uint8 reserveFlags, address lpConduit) = 
        
        //This is what is encoded 
        //bytes memory mintParams = abi.encode(
        //    uint8(12),
        //    address(0), //ETH
        //    getAddress(sourceChain, "USDE"), 
        //    uint256(420),
        //    int24(-12412),
        //    int24(-10408),
        //    uint128(2e18),
        //    uint128(0.25e18),
        //    uint128(0.255e18),
        //    uint8(0),
        //    address(0) //lpConduit
        //);  
        
        bytes memory mintParams = hex"000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d3a1ff2b6bab83b63cd9ad0787074081a52ef3400000000000000000000000000000000000000000000000000000000000001a4fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffecf84fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed7580000000000000000000000000000000000000000000000001bc16d674ec80000000000000000000000000000000000000000000000000000056f8f4d80ef0000000000000000000000000000000000000000000000000000057d52561522000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"; 

        targetData[1] = abi.encodeWithSignature(
            "userCmd(uint16,bytes)", uint16(128), mintParams
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2); 
        values[0] = 0; 
        values[1] = 0.1e18;  //verify that we are refunded excess ETH (use -vvvv to check the call data) 

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);


        // Due to the JIT liquidity protection enabled on Ambient, we must skip a few blocks before removing liquidity
        skip(100); 
            
        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2]; //remove liq ETH/USDE

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "crocSwapDex");

        
        bytes memory burnParams = hex"000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d3a1ff2b6bab83b63cd9ad0787074081a52ef3400000000000000000000000000000000000000000000000000000000000001a4fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffecf84fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed7580000000000000000000000000000000000000000000000000c198a12647360000000000000000000000000000000000000000000000000000572a5852c0200000000000000000000000000000000000000000000000000000580a9d8c479000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature(
            "userCmd(uint16,bytes)", uint16(128), burnParams
        );

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        values = new uint256[](1); 

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        //boring vault shoud receive around $2 in each pair, (verify with -vvvv)
    }

    function testAmbientLiquidityWarmPath__Ambient() external {
        deal(address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDE"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        
        address baseToken= getAddress(sourceChain, "ETH");  
        address quoteToken = getAddress(sourceChain, "USDE");  

        _addAmbientLPLeafs(leafs, baseToken, quoteToken);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve USDE
        manageLeafs[1] = leafs[1]; //mint USDE/ETH 

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "USDE");
        targets[1] = getAddress(sourceChain, "crocSwapDex");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "crocSwapDex"), type(uint256).max
        );
        // Mint concentrated lp position params
        //
        //(uint8 code, address base, address quote, uint256 poolIdx,
        // int24 bidTick, int24 askTick, uint128 liq,
        // uint128 limitLower, uint128 limitHigher,
        // uint8 reserveFlags, address lpConduit) = 
        
        //This is what is encoded 
        //bytes memory mintParams = abi.encode(
        //    uint8(12),
        //    address(0), //ETH
        //    getAddress(sourceChain, "USDE"), 
        //    uint256(420),
        //    int24(-12412),
        //    int24(-10408),
        //    uint128(2e18),
        //    uint128(0.25e18),
        //    uint128(0.255e18),
        //    uint8(0),
        //    address(0) //lpConduit
        //);  
        
        bytes memory mintParams = hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d3a1ff2b6bab83b63cd9ad0787074081a52ef3400000000000000000000000000000000000000000000000000000000000001a4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001bc16d674ec80000000000000000000000000000000000000000000000000000057556196d56000000000000000000000000000000000000000000000000000005836158b016000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"; 

        targetData[1] = abi.encodeWithSignature(
            "userCmd(uint16,bytes)", uint16(128), mintParams
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2); 
        values[0] = 0; 
        values[1] = 0.1e18;  //verify that we are refunded excess ETH (use -vvvv to check the call data) 

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);


        // Due to the JIT liquidity protection enabled on Ambient, we must skip a few blocks before removing liquidity
        skip(100); 
            
        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2]; //remove liq ETH/USDE

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "crocSwapDex");

        
        bytes memory burnParams = hex"000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d3a1ff2b6bab83b63cd9ad0787074081a52ef3400000000000000000000000000000000000000000000000000000000000001a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000005746c0da3ba0000000000000000000000000000000000000000000000000000058274f2b769000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature(
            "userCmd(uint16,bytes)", uint16(128), burnParams
        );

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        values = new uint256[](1); 

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        //boring vault shoud receive around $2 in each pair, (verify with -vvvv)
    }

    function testAmbientLiquidityWarmPath__ConcentratedHarvest() external {
        deal(address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDE"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        
        address baseToken= getAddress(sourceChain, "ETH");  
        address quoteToken = getAddress(sourceChain, "USDE");  

        _addAmbientLPLeafs(leafs, baseToken, quoteToken);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve USDE
        manageLeafs[1] = leafs[1]; //mint USDE/ETH 

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "USDE");
        targets[1] = getAddress(sourceChain, "crocSwapDex");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "crocSwapDex"), type(uint256).max
        );
        // Mint concentrated lp position params
        //
        //(uint8 code, address base, address quote, uint256 poolIdx,
        // int24 bidTick, int24 askTick, uint128 liq,
        // uint128 limitLower, uint128 limitHigher,
        // uint8 reserveFlags, address lpConduit) = 
        
        //This is what is encoded 
        //bytes memory mintParams = abi.encode(
        //    uint8(12),
        //    address(0), //ETH
        //    getAddress(sourceChain, "USDE"), 
        //    uint256(420),
        //    int24(-12412),
        //    int24(-10408),
        //    uint128(2e18),
        //    uint128(0.25e18),
        //    uint128(0.255e18),
        //    uint8(0),
        //    address(0) //lpConduit
        //);  
        
        bytes memory mintParams = hex"000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d3a1ff2b6bab83b63cd9ad0787074081a52ef3400000000000000000000000000000000000000000000000000000000000001a4fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffecf84fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed7580000000000000000000000000000000000000000000000001bc16d674ec80000000000000000000000000000000000000000000000000000056f8f4d80ef0000000000000000000000000000000000000000000000000000057d52561522000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"; 

        targetData[1] = abi.encodeWithSignature(
            "userCmd(uint16,bytes)", uint16(128), mintParams
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2); 
        values[0] = 0; 
        values[1] = 0.1e18;  //verify that we are refunded excess ETH (use -vvvv to check the call data) 

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);


        // Due to the JIT liquidity protection enabled on Ambient, we must skip a few blocks before removing liquidity
        skip(1000); 
            
        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2]; //remove liq ETH/USDE

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "crocSwapDex");

        //bytes memory harvestParams = abi.encode(
        //    uint8(5),
        //    address(0), //ETH
        //    getAddress(sourceChain, "USDE"), 
        //    uint256(420),
        //    int24(-12412),
        //    int24(-10408),
        //    uint128(2e18),
        //    uint128(0.25e18),
        //    uint128(0.255e18),
        //    uint8(0),
        //    address(0) //lpConduit
        //);  
        
        bytes memory harvestParams = hex"000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d3a1ff2b6bab83b63cd9ad0787074081a52ef3400000000000000000000000000000000000000000000000000000000000001a4fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffecf84fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed7580000000000000000000000000000000000000000000000000c198a12647360000000000000000000000000000000000000000000000000000572a5852c0200000000000000000000000000000000000000000000000000000580a9d8c479000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature(
            "userCmd(uint16,bytes)", uint16(128), harvestParams
        );

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        values = new uint256[](1); 

        uint256 usdeBefore = getERC20(sourceChain, "USDE").balanceOf(address(boringVault)); 
        

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        //boring vault path should work

        uint256 usdeAfter = getERC20(sourceChain, "USDE").balanceOf(address(boringVault)); 

        assertGt(usdeAfter, usdeBefore); 
    }

    function testAmbientLiquidityColdPath__SwapETHForToken() external {
        deal(address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDE"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        
        address baseToken= getAddress(sourceChain, "ETH");  
        address quoteToken = getAddress(sourceChain, "USDE");  

        _addAmbientLPLeafs(leafs, baseToken, quoteToken);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve USDE
        manageLeafs[1] = leafs[1]; //mint swap ETH for USDE 

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "USDE");
        targets[1] = getAddress(sourceChain, "crocSwapDex");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "crocSwapDex"), type(uint256).max
        );
        // Swap params
        //
        //
        
        //This is what is encoded 
        //bytes memory mintParams = abi.encode(
        //    uint8(12),
        //    address(0), //ETH
        //    getAddress(sourceChain, "USDE"), 
        //    uint256(420),
        //    int24(-12412),
        //    int24(-10408),
        //    uint128(2e18),
        //    uint128(0.25e18),
        //    uint128(0.255e18),
        //    uint8(0),
        //    address(0) //lpConduit
        //);  
        
        bytes memory mintParams = hex"000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d3a1ff2b6bab83b63cd9ad0787074081a52ef3400000000000000000000000000000000000000000000000000000000000001a4fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffecf84fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed7580000000000000000000000000000000000000000000000001bc16d674ec80000000000000000000000000000000000000000000000000000056f8f4d80ef0000000000000000000000000000000000000000000000000000057d52561522000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"; 

        targetData[1] = abi.encodeWithSignature(
            "userCmd(uint16,bytes)", uint16(128), mintParams
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2); 
        values[0] = 0; 
        values[1] = 0.1e18;  //verify that we are refunded excess ETH (use -vvvv to check the call data) 

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);


        // Due to the JIT liquidity protection enabled on Ambient, we must skip a few blocks before removing liquidity
        skip(1000); 
            
        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2]; //remove liq ETH/USDE

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "crocSwapDex");

        //bytes memory harvestParams = abi.encode(
        //    uint8(5),
        //    address(0), //ETH
        //    getAddress(sourceChain, "USDE"), 
        //    uint256(420),
        //    int24(-12412),
        //    int24(-10408),
        //    uint128(2e18),
        //    uint128(0.25e18),
        //    uint128(0.255e18),
        //    uint8(0),
        //    address(0) //lpConduit
        //);  
        
        bytes memory harvestParams = hex"000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d3a1ff2b6bab83b63cd9ad0787074081a52ef3400000000000000000000000000000000000000000000000000000000000001a4fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffecf84fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed7580000000000000000000000000000000000000000000000000c198a12647360000000000000000000000000000000000000000000000000000572a5852c0200000000000000000000000000000000000000000000000000000580a9d8c479000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature(
            "userCmd(uint16,bytes)", uint16(128), harvestParams
        );

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        values = new uint256[](1); 

        uint256 usdeBefore = getERC20(sourceChain, "USDE").balanceOf(address(boringVault)); 
        

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        //boring vault path should work

        uint256 usdeAfter = getERC20(sourceChain, "USDE").balanceOf(address(boringVault)); 

        assertGt(usdeAfter, usdeBefore); 
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}


contract FullAmbientDecoderAndSanitizer is AmbientDecoderAndSanitizer{}
