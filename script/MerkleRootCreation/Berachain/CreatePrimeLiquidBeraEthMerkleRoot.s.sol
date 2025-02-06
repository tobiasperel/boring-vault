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
 *  source .env && forge script script/MerkleRootCreation/Berachain/CreatePrimeLiquidBeraBtcMerkleRoot.s.sol:CreatePrimeLiquidBeraBtcMerkleRoot --rpc-url $BERA_CHAIN_RPC_URL
 */
contract CreatePrimeLiquidBeraBtcMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x46fcd35431f5B371224ACC2e2E91732867B1A77e; 
    address public managerAddress = 0x7280E05ccF01066C715aDc936f860BD65510f816;
    address public accountantAddress = 0x4faE50B524e0D05BD73fDF28b273DB7D4A57CCe9;
    address public rawDataDecoderAndSanitizer = 0x9b0FF5F9625F99Ae64CfFdc85B56e594D520ACcB;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        
        // ========================== Kodiak Swaps ==========================
        
        address[] memory token0 = new address[](2);  
        token0[0] = getAddress(sourceChain, "WETH");    
        token0[1] = getAddress(sourceChain, "WETH");    

        address[] memory token1 = new address[](2);  
        token1[0] = getAddress(sourceChain, "WEETH");    
        token1[1] = getAddress(sourceChain, "beraETH");    
        
        _addUniswapV3Leafs(leafs, token0, token1, false); 

        // ========================== Kodiak Islands ==========================
        
        address[] memory islands = new address[](3);  
        islands[0] = getAddress(sourceChain, "kodiak_island_WETH_WEETH_005%"); 
        islands[1] = getAddress(sourceChain, "kodiak_island_WETH_beraETH_005%"); 
        islands[2] = getAddress(sourceChain, "kodiak_island_WEETH_WEETH_OT_005%"); 
         

        // ========================== Dolomite Supply ==========================
        
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "WETH"));          
        _addDolomiteDepositLeafs(leafs, getAddress(sourceChain, "WEETH"));          


        // ========================== dTokens ==========================
        
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "dWETH")));   
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "dWEETH")));   

        // ========================== Goldilocks ==========================

        address[] memory vaults = new address[](1); 
        vaults[0] = getAddress(sourceChain, "goldivault_weETH"); 

        _addGoldiVaultLeafs(leafs, vaults); 

        // ========================== beraETH ==========================
        _addBeraETHLeafs(leafs); 


        // ========================== Verify ==========================
        
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Berachain/PrimeLiquidBeraEth.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
