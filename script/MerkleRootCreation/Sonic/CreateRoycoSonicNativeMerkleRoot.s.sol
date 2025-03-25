pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Sonic/CreateRoycoSonicNativeMerkleRoot.s.sol:CreateRoycoSonicNativeMerkleRoot --rpc-url $SONIC_MAINNET_RPC_URL
 */
contract CreateRoycoSonicNativeMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;
    // TODO: Fill in the addresses
    address public boringVault = ;
    address public managerAddress = ;
    address public accountantAddress = ;
    address public rawDataDecoderAndSanitizer = ;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateSonicNativeStrategistMerkleRoot();
    }

    function generateSonicNativeStrategistMerkleRoot() public {
        setSourceChainName(sonicMainnet);
        setAddress(false, sonicMainnet, "boringVault", boringVault);
        setAddress(false, sonicMainnet, "managerAddress", managerAddress);
        setAddress(false, sonicMainnet, "accountantAddress", accountantAddress);
        setAddress(false, sonicMainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Fee Claiming ========================== //TODO: CHECK
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true); //add yield claiming

         // ========================== Odos ==========================
         address[] memory tokens = new address[](1);
         SwapKind[] memory kind = new SwapKind[](1);
         tokens[0] = getAddress(sourceChain, "USDC");
         kind[0] = SwapKind.BuyAndSell;

         _addOdosSwapLeafs(leafs, tokens, kind);

        // ========================== Royco ========================== //TODO: FIX INPUTS, check if other royco functions are needed
        _addRoycoRecipeAPOfferLeafs(leafs, getAddress(sonicMainnet, "USDC"), getAddress(sonicMainnet, "USDC"), getAddress(sonicMainnet, "RoycoStrategist"));
        _addRoycoRecipeAPOfferLeafs(leafs, getAddress(sonicMainnet, "USDC"), getAddress(sonicMainnet, "USDC"), getAddress(sonicMainnet, "RoycoStrategist"));

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Sonic/RoycoSonicNativeStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
