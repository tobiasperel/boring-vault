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
 *  source .env && forge script script/MerkleRootCreation/Unichain/CreatePrimeGoldenGooseUnichainMerkleRoot.s.sol --rpc-url $UNICHAIN_RPC_URL
 */
contract CreatePrimeGoldenGooseUnichainMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;
   

    address public boringVault = 0xEc0569121753e50979d3C6Aa093bb881e8E752C5;
    address public managerAddress = 0xDa61124f29fb788718eC868f5f0005c78904a41D;
    address public accountantAddress = 0xC2693B160d164f17f4D67Af811eEC28aBE01598a;
    address public rawDataDecoderAndSanitizer = 0x7FE4786f25460F469113835fb64756B03dcb5C5b;

    function setUp() external {
        // Setup is done in generateMerkleRoot to avoid double forking
    }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMerkleRoot();
    }

    function generateMerkleRoot() public {
        // Force Unichain fork
        vm.createSelectFork(vm.envString("UNICHAIN_RPC_URL"));
        
        setSourceChainName(unichain);
        setAddress(false, unichain, "boringVault", boringVault);
        setAddress(false, unichain, "managerAddress", managerAddress);
        setAddress(false, unichain, "accountantAddress", accountantAddress);
        setAddress(false, unichain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs);

        // ========================== Layer Zero ==========================
        _addLayerZeroLeafNative(leafs, getAddress(sourceChain, "stargateNative"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== Morpho ==========================
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "morphowstETHmarket"));

        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "morphoK3CapitalETHMaxi")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "morphoGauntletWETH")));

        // ========================== Euler ==========================
        {
            ERC4626[] memory depositVaults = new ERC4626[](2);
            depositVaults[0] = ERC4626(getAddress(sourceChain, "eulerWETH"));
            depositVaults[1] = ERC4626(getAddress(sourceChain, "eulerwstETHmarket"));

            address[] memory subaccounts = new address[](2);
            subaccounts[0] = address(boringVault);
            subaccounts[1] = address(boringVault);

            _addEulerDepositLeafs(leafs, depositVaults, subaccounts);
        }

        // ========================== Odos ==========================
        {
            address[] memory assets = new address[](2);
            SwapKind[] memory kind = new SwapKind[](2);
            assets[0] = getAddress(sourceChain, "WETH");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "WSTETH");
            kind[1] = SwapKind.BuyAndSell;
           
        

            _addOdosSwapLeafs(leafs, assets, kind);

        // =========================== 1Inch ==========================
            _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);
        }


        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Unichain/PrimeGoldenGooseUnichainStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
