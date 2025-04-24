// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Berachain/CreateLiquidBtcMerkleRoot.s.sol:CreateLiquidBtcMerkleRoot --rpc-url $BERA_CHAIN_RPC_URL
 */
contract CreateLiquidBtcMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x5f46d540b6eD704C3c8789105F30E075AA900726; 
    address public managerAddress = 0xaFa8c08bedB2eC1bbEb64A7fFa44c604e7cca68d;
    address public accountantAddress = 0xEa23aC6D7D11f6b181d6B98174D334478ADAe6b0;
    address public rawDataDecoderAndSanitizer = 0x7904708be89437a3b06D2333291ecF13A98e5B5C;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(berachain);
        setAddress(false, berachain, "boringVault", boringVault);
        setAddress(false, berachain, "managerAddress", managerAddress);
        setAddress(false, berachain, "accountantAddress", accountantAddress);
        setAddress(false, berachain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);
        

        // ========================== Kodiak Swaps ==========================

        address[] memory token0 = new address[](1);  
        token0[0] = getAddress(sourceChain, "WBTC");    

        address[] memory token1 = new address[](1);  
        token1[0] = getAddress(sourceChain, "solvBTC");    

        _addUniswapV3Leafs(leafs, token0, token1, false); 

        // ========================== Kodiak Islands ==========================

        address[] memory islands = new address[](1);  
        islands[0] = getAddress(sourceChain, "kodiak_island_WBTC_solvBTC_005%"); 

        _addKodiakIslandLeafs(leafs, islands); 

        // ========================== Dolomite Supply ==========================
        
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "srUSD"), false);          
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "USDC"), false);          

        // ========================== Dolomite Borrow ==========================
        
        _addDolomiteBorrowLeafs(leafs, getAddress(sourceChain, "srUSD"));
        _addDolomiteBorrowLeafs(leafs, getAddress(sourceChain, "USDC"));

        // ========================== Ooga Booga ==========================
        address[] memory assets = new address[](6);
        SwapKind[] memory kind = new SwapKind[](6);
        assets[0] = getAddress(sourceChain, "iBGT");
        kind[0] = SwapKind.Sell;
        assets[1] = getAddress(sourceChain, "WBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "solvBTC");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "BGT"); //just in case
        kind[3] = SwapKind.Sell;
        assets[4] = getAddress(sourceChain, "USDC");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "srUSD");
        kind[5] = SwapKind.BuyAndSell;

        _addOogaBoogaSwapLeafs(leafs, assets, kind);

        // ========================== Infrared ==========================
        _addInfraredVaultLeafs(leafs, getAddress(sourceChain, "infrared_vault_wbtc_solvbtc"));

        // ========================== LayerZero/Stargate ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WBTC"), getAddress(sourceChain, "WBTC"), layerZeroMainnetEndpointId);   
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "solvBTC"), getAddress(sourceChain, "solvBTC_OFT"), layerZeroMainnetEndpointId);   
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "srUSD"), getAddress(sourceChain, "stargatesrUSD"), layerZeroMainnetEndpointId);   
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "srUSD"), getAddress(sourceChain, "stargateUSDC"), layerZeroMainnetEndpointId);   

        // ========================== Verify ==========================
        
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Berachain/LiquidBtcStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
