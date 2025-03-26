pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateRoycoMetaVaultMainnetMerkleRoot.s.sol:CreateRoycoMetaVaultMainnetMerkleRoot --rpc-url $MAINNET_RPC_URL
 */
contract CreateRoycoMetaVaultMainnetMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;
    // TODO: CHECK the addresses
    address public boringVault = 0x0c734D3f969F2DD73E433A277B7f2aAd9A931A7D;
    address public managerAddress = 0x74CA0a2f29fff8F375Eb49E94430015D12879a26;
    address public accountantAddress = 0x36Bf94F0F9005C15051625d83732F7dA25DF16E6;
    address public rawDataDecoderAndSanitizer = 0x1ce013130d069B505f193022eB39f918Bd108bE0;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateMetaVaultMainnetStrategistMerkleRoot();
    }

    function generateMetaVaultMainnetStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== SonicGateway ==========================
        ERC20[] memory mainnetAssets = new ERC20[](1);
        //address[] memory sonicAssets = new address[](1);
        mainnetAssets[0] = getERC20(mainnet, "USDC");
        //sonicAssets[0] = getAddress(sonicMainnet, "USDC");
        _addSonicGatewayLeafsEth(leafs, mainnetAssets);

        // ========================== LayerZero ========================== // Using stargate pool as OFT
        _addLayerZeroLeafs(leafs, getERC20(mainnet, "USDC"), getAddress(mainnet, "stargateUSDC"), layerZeroSonicMainnetEndpointId);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true); //add yield claiming

        // ========================== Odos ==========================
         address[] memory tokens = new address[](1);
         SwapKind[] memory kind = new SwapKind[](1);
         tokens[0] = getAddress(sourceChain, "USDC");
         kind[0] = SwapKind.BuyAndSell;

         _addOdosSwapLeafs(leafs, tokens, kind);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/RoycoMetaVaultMainnetStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
