// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {RoycoWeirollDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RoycoDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract RoycoIntegrationTest is BaseTestIntegration {
    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 21713448); 
            
        address roycoDecoder = address(new FullRoycoDecoderAndSaniziter(0x783251f103555068c1E9D755f69458f39eD937c0)); 

        _overrideDecoder(roycoDecoder); 
    }

    function _setUpSonic() internal {
        super.setUp(); 
        _setupChain("sonicMainnet", 14684422); 
            
        address roycoDecoder = address(new FullRoycoDecoderAndSaniziter(0xFcc593aD3705EBcd72eC961c63eb484BE795BDbD)); 

        _overrideDecoder(roycoDecoder); 
    }

    function testRoycoERC4626Integration() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "supplyUSDCAaveWrappedVault")));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //deposit
        manageLeafs[2] = leafs[2]; //withdraw
        manageLeafs[3] = leafs[3]; //mint
        manageLeafs[4] = leafs[4]; //redeem

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        //we are supplying USDC onto Aave.
        address[] memory targets = new address[](5);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");
        targets[2] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");
        targets[3] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");
        targets[4] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");

        bytes[] memory targetData = new bytes[](5);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "supplyUSDCAaveWrappedVault"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("deposit(uint256,address)", 100e6, getAddress(sourceChain, "boringVault"));
        targetData[2] = abi.encodeWithSignature(
            "withdraw(uint256,address,address)",
            90e6,
            getAddress(sourceChain, "boringVault"),
            getAddress(sourceChain, "boringVault")
        );
        targetData[3] = //mint 10 shares
         abi.encodeWithSignature("mint(uint256,address)", 10e6, getAddress(sourceChain, "boringVault"));
        targetData[4] = //redeem 10 shares
        abi.encodeWithSignature(
            "redeem(uint256,address,address)",
            10e6,
            getAddress(sourceChain, "boringVault"),
            getAddress(sourceChain, "boringVault")
        );

        address[] memory decodersAndSanitizers = new address[](5);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](5);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testRoycoERC4626IntegrationClaiming() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addRoyco4626VaultLeafs(leafs, ERC4626(getAddress(sourceChain, "supplyUSDCAaveWrappedVault")));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //deposit

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        //we are supplying USDC onto Aave.
        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "supplyUSDCAaveWrappedVault"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("deposit(uint256,address)", 100e6, getAddress(sourceChain, "boringVault"));

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        //skip some time
        skip(12 weeks);

        manageLeafs[0] = leafs[5]; //claim
        manageLeafs[1] = leafs[6]; //claimFees

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets[0] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");
        targets[1] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");

        targetData[0] = abi.encodeWithSignature("claim(address)", getAddress(sourceChain, "boringVault"));
        targetData[1] = abi.encodeWithSignature("claimFees(address)", getAddress(sourceChain, "boringVault"));

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testRoycoWeirollForfeitIntegration() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6);

        bytes32 stkGHOMarketHash = 0x83c459782b2ff36629401b1a592354fc085f29ae00cf97b803f73cac464d389b;

        bytes32 stkGHOHash = 0x8349eff9a17d01f2e9fa015121d0d03cd4b15ae9f2b8b17add16bbad006a1c6a;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addRoycoWeirollLeafs(leafs, getERC20(sourceChain, "USDC"), stkGHOMarketHash, getAddress(sourceChain, "boringVault"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //first we'll check early unlocks and forfeits
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //fillIPOffers (execute deposit script)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        //we are interacting the stkGHO market
        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "recipeMarketHub");

        bytes32[] memory ipOfferHashes = new bytes32[](1);
        ipOfferHashes[0] = stkGHOHash; //stkGHO offer hash from: https://etherscan.io/tx/0x133e477a7573555df912bba020c3a5e3c3b137a21a76c8f52b3b5a7a2065f2e0

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e6;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "recipeMarketHub"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "fillIPOffers(bytes32[],uint256[],address,address)",
            ipOfferHashes,
            amounts,
            address(0),
            getAddress(sourceChain, "boringVault")
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        //execute deposit script
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        ///Test Withdraws

        //accrue some rewards
        skip(7 days);

        //NOTE: created upon calling `fillIPOffers()` and needed for withdrawls
        address expectedWeirollWallet = 0xF2075aBc3cC8EE8F75F28Ac9A3c5CAeBe1E9C7Cb;
        bool executeWithdraw = true;

        ManageLeaf[] memory manageLeafs2 = new ManageLeaf[](1);
        manageLeafs2[0] = leafs[3]; //forfeit

        manageProofs = _getProofsUsingTree(manageLeafs2, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "recipeMarketHub");

        targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("forfeit(address,bool)", expectedWeirollWallet, executeWithdraw);

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        values = new uint256[](1);

        //execute forfeit script with rewards accrued
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testRoycoWeirollExecuteWithdrawIntegrationComplete() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6);

        bytes32 stkGHOMarketHash = 0x83c459782b2ff36629401b1a592354fc085f29ae00cf97b803f73cac464d389b;

        bytes32 stkGHOHash = 0x8349eff9a17d01f2e9fa015121d0d03cd4b15ae9f2b8b17add16bbad006a1c6a;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addRoycoWeirollLeafs(leafs, getERC20(sourceChain, "USDC"), stkGHOMarketHash, getAddress(sourceChain, "boringVault"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //first we'll check early unlocks and forfeits
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //fillIPOffers (execute deposit script)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        //we are interacting the stkGHO market
        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "recipeMarketHub");

        bytes32[] memory ipOfferHashes = new bytes32[](1);
        ipOfferHashes[0] = stkGHOHash; //stkGHO offer hash from: https://etherscan.io/tx/0x133e477a7573555df912bba020c3a5e3c3b137a21a76c8f52b3b5a7a2065f2e0

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e6;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "recipeMarketHub"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "fillIPOffers(bytes32[],uint256[],address,address)",
            ipOfferHashes,
            amounts,
            address(0),
            getAddress(sourceChain, "boringVault")
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        //execute deposit script
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        ///Test Withdraws

        //accrue some rewards
        skip(40 days);

        //NOTE: created upon calling `fillIPOffers()` and needed for withdrawls
        address expectedWeirollWallet = 0xF2075aBc3cC8EE8F75F28Ac9A3c5CAeBe1E9C7Cb;

        ManageLeaf[] memory manageLeafs2 = new ManageLeaf[](2);
        manageLeafs2[0] = leafs[2]; //executeWithdrawalScript
        manageLeafs2[1] = leafs[4]; //executeWithdrawalScript

        manageProofs = _getProofsUsingTree(manageLeafs2, manageTree);

        targets = new address[](2);
        targets[0] = getAddress(sourceChain, "recipeMarketHub");
        targets[1] = getAddress(sourceChain, "recipeMarketHub");

        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("executeWithdrawalScript(address)", expectedWeirollWallet);
        targetData[1] = abi.encodeWithSignature(
            "claim(address,address)", expectedWeirollWallet, getAddress(sourceChain, "boringVault")
        );

        decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        values = new uint256[](2);

        //execute forfeit script with rewards accrued
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testRoycoWeirollExecuteWithdrawIntegration() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WBTC"), address(boringVault), 1_000e6);

        bytes32 wbtcMarketHash = 0xb36f14fd392b9a1d6c3fabedb9a62a63d2067ca0ebeb63bbc2c93b11cc8eb3a2;

        bytes32 wbtcFillOfferHash = 0xe6d27a147193a240619759a35ebed3b4c2bd931cc3aaf9887c37724eea46f235;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addRoycoWeirollLeafs(
            leafs, getERC20(sourceChain, "WBTC"), wbtcMarketHash, getAddress(sourceChain, "boringVault")
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //first we'll check early unlocks and forfeits
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //fillIPOffers (execute deposit script)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        //we are interacting the stkGHO market
        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WBTC");
        targets[1] = getAddress(sourceChain, "recipeMarketHub");

        bytes32[] memory ipOfferHashes = new bytes32[](1);
        ipOfferHashes[0] = wbtcFillOfferHash;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e6;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "recipeMarketHub"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "fillIPOffers(bytes32[],uint256[],address,address)",
            ipOfferHashes,
            amounts,
            address(0),
            getAddress(sourceChain, "boringVault")
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        //execute deposit script
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testRoycoWeirollVaultMarketHubIntegration() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100_000e6);

        address[] memory incentivesRequested = new address[](2);
        incentivesRequested[0] = getAddress(sourceChain, "WBTC");
        incentivesRequested[1] = getAddress(sourceChain, "WETH");
        uint256[] memory amountsRequested = new uint256[](2);
        amountsRequested[0] = 1e8;
        amountsRequested[1] = 10e18;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        // fundingVault = address(0) means pull funds from caller (boringVault)
        _addRoycoVaultMarketLeafs(leafs, getAddress(sourceChain, "USDC"), getAddress(sourceChain, "supplyUSDCAaveWrappedVault"), address(0), incentivesRequested);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0]; //approve WrappedVault
        manageLeafs[1] = leafs[1]; //safeDeposit
        manageLeafs[2] = leafs[2]; //approve VaultMarketHub
        manageLeafs[3] = leafs[3]; //createAPOffer

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");
        targets[2] = getAddress(sourceChain, "USDC");
        targets[3] = getAddress(sourceChain, "vaultMarketHub");

        bytes[] memory targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "supplyUSDCAaveWrappedVault"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "safeDeposit(uint256,address,uint256)", 100e6, getAddress(sourceChain, "boringVault"), 88e6
        );
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "vaultMarketHub"), type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "createAPOffer(address,address,uint256,uint256,address[],uint256[])",
            getAddress(sourceChain, "supplyUSDCAaveWrappedVault"),
            address(0),
            100e6,
            1773880121, // March 19 2026
            incentivesRequested,
            amountsRequested
        );

        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](4);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testRoycoWeirollRecipeMarketHubIntegration() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100_000e6);
        bytes32 targetMarketHash = 0x83c459782b2ff36629401b1a592354fc085f29ae00cf97b803f73cac464d389b; //swap USDC to stkGHO market hash

        address[] memory incentivesRequested = new address[](2);
        incentivesRequested[0] = getAddress(sourceChain, "WBTC");
        incentivesRequested[1] = getAddress(sourceChain, "WETH");
        uint256[] memory amountsRequested = new uint256[](2);
        amountsRequested[0] = 1e8;
        amountsRequested[1] = 10e18;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addRoycoRecipeAPOfferLeafs(leafs, getAddress(sourceChain, "USDC"), targetMarketHash, address(0), incentivesRequested);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "recipeMarketHub");
        targets[2] = getAddress(sourceChain, "recipeMarketHub");

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "recipeMarketHub"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "createAPOffer(bytes32,address,uint256,uint256,address[],uint256[])",
            targetMarketHash,
            address(0),
            100e6,
            1773880121, // March 19 2026
            incentivesRequested,
            amountsRequested
        );
        targetData[2] = abi.encodeWithSignature(
            "cancelAPOffer((uint256,bytes32,address,address,uint256,uint256,address[],uint256[]))",
            DecoderCustomTypes.APOffer(11, // this depends on when we are forking from, this is the 11th offer created
            targetMarketHash,
            getAddress(sourceChain, "boringVault"), // msg.sender of createAPOffer call
            address(0),
            100e6,
            1773880121, // March 19 2026
            incentivesRequested,
            amountsRequested)
        );

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }
}

// NOTE: Big Decoder will inherit from RoycoWeirollDecoderAndSanitizer and ERC4626DecoderAndSanitizer
contract FullRoycoDecoderAndSaniziter is RoycoWeirollDecoderAndSanitizer, ERC4626DecoderAndSanitizer {
    constructor(address _recipeMarketHub) RoycoWeirollDecoderAndSanitizer(_recipeMarketHub) {}
}
