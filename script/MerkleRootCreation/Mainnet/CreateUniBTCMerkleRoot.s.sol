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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateCbBTCMerkleRoot.s.sol:CreateCbBTCMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateUniBTCMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = ;0xf6d71c15657A7f2B9aeDf561615feF9E05fE2cb3; 
    address public managerAddress = 0xaded360316287F1d0A0E7Bc416AB8112F295e893;
    address public accountantAddress = 0x37e6e4526483D05711b8D6F92c27F2f3a16FC45b;
    address public rawDataDecoderAndSanitizer = 0xa8df6E7ec5063fb0691bb53814BE7A8F2E1cE943;


    function setUp() external {}

    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "WBTC");
        token0[1] = getAddress(sourceChain, "WBTC");
        token0[2] = getAddress(sourceChain, "cbBTC");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "cbBTC");
        token1[1] = getAddress(sourceChain, "uniBTC");
        token1[2] = getAddress(sourceChain, "uniBTC");

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "cbBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "uniBTC");
        kind[2] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_uniBTC_market_03_26_25"), true);



        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/uniBTCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }
}
