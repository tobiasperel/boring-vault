// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreatePrimeGoldenGooseMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreatePrimeGoldenGooseMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xEc0569121753e50979d3C6Aa093bb881e8E752C5;
    address public managerAddress = 0xDa61124f29fb788718eC868f5f0005c78904a41D;
    address public accountantAddress = 0xC2693B160d164f17f4D67Af811eEC28aBE01598a;
    address public rawDataDecoderAndSanitizer = 0x8EA825e335D1a296432D8D2f13594630139CA1B4;

    function setUp() external {
        // Ensure we're forking mainnet properly
        if (block.chainid != 1) {
            vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        }
    }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMerkleRoot();
    }

    function generateMerkleRoot() public {
        // Force mainnet fork
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Rewards ==========================
        ERC20[] memory tokensToClaim = new ERC20[](1);
        tokensToClaim[0] = getERC20(sourceChain, "rEUL");
        _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "dev1Address"), tokensToClaim);
        _addrEULWrappingLeafs(leafs);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs);

        // ========================== Standard Bridge ==========================
        ERC20[] memory localTokens = new ERC20[](2);
        ERC20[] memory remoteTokens = new ERC20[](2);
        localTokens[0] = getERC20(sourceChain, "WETH");
        remoteTokens[0] = getERC20(unichain, "WETH");
        localTokens[1] = getERC20(sourceChain, "WSTETH");
        remoteTokens[1] = getERC20(unichain, "WSTETH");

        _addStandardBridgeLeafs(
            leafs,
            unichain,
            getAddress(unichain, "crossDomainMessenger"),
            getAddress(sourceChain, "unichainResolvedDelegate"),
            getAddress(sourceChain, "unichainStandardBridge"),
            getAddress(sourceChain, "unichainPortal"),
            localTokens,
            remoteTokens
        );

        _addLidoStandardBridgeLeafs(
            leafs,
            unichain,
            getAddress(unichain, "crossDomainMessenger"),
            getAddress(sourceChain, "unichainResolvedDelegate"),
            getAddress(sourceChain, "unichainStandardBridge"),
            getAddress(sourceChain, "unichainPortal")
        );

        // ========================== Layer Zero ==========================
        _addLayerZeroLeafNative(leafs, getAddress(sourceChain, "stargateNative"), layerZeroUnichainEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== Morpho ==========================
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "WSTETH_WETH_945"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "WEETH_WETH_915"));

        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "WSTETH_WETH_945"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "WEETH_WETH_915"));

        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "steakhouseETH")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletWETHPrime")));

        // ========================== Euler ==========================
        {
            ERC4626[] memory depositVaults = new ERC4626[](2);
            depositVaults[0] = ERC4626(getAddress(sourceChain, "eulerPrimeWETH"));
            depositVaults[1] = ERC4626(getAddress(sourceChain, "evkWSTETH"));

            address[] memory subaccounts = new address[](1);
            subaccounts[0] = address(boringVault);

            _addEulerDepositLeafs(leafs, depositVaults, subaccounts);
        }

        // ========================== Balancer ==========================
        _addBalancerV3Leafs(
            leafs, getAddress(sourceChain, "balancerV3_Surge_Fluid_wstETH-wETH_boosted"), true, getAddress(sourceChain, "balancerV3_Surge_Fluid_wstETH-wETH_boosted_gauge")
        );

        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fwstETH"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWETH"));

        // ========================== Balancer Flash Loans ==========================
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WSTETH"));

        // =========================== Lido ==========================
        _addLidoLeafs(leafs);

        // Allow for swapping for fwstETH and fWETH
        // ========================== Odos ==========================
        {
            address[] memory assets = new address[](4);
            SwapKind[] memory kind = new SwapKind[](4);
            assets[0] = getAddress(sourceChain, "WETH");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "WSTETH");
            kind[1] = SwapKind.BuyAndSell;
            assets[2] = getAddress(sourceChain, "rEUL");
            kind[2] = SwapKind.Sell;
            assets[3] = getAddress(sourceChain, "EUL");
            kind[3] = SwapKind.Sell;

            _addOdosSwapLeafs(leafs, assets, kind);

        // =========================== 1Inch ==========================
            _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);
        }


        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/PrimeGoldenGooseStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
