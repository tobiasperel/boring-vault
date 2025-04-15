// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Sonic/CreateSfrxUSDScUSDMerkleRoot.s.sol:CreateSfrxUSDScUSDMerkleRoot --rpc-url $SONIC_RPC_URL
 * 
 *  NOTE: The Silo contract at 0x4E09FF794D255a123b00efa30162667A8054a845 is deployed but NOT activated.
 *  Confirmed from execution trace: it returns "NotActivated" when calling getSilos().
 */
contract CreateSfrxUSDScUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE;
    address public managerAddress = 0x76fda7A02B616070D3eC5902Fa3C5683AC3cB8B6;
    address public accountantAddress = 0xA76E0F54918E39A63904b51F688513043242a0BE;
    address public rawDataDecoderAndSanitizer = 0xfdD1309DeDB4336c9fABef3150b24cB64732dEDF;

    function setUp() external {}

    function run() external {
        console.log("Running Merkle root generation for sfrxUSD/scUSD pool (without Silo functionality)");
        
        // Run the actual generation
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(sonicMainnet);
        setAddress(false, sonicMainnet, "boringVault", boringVault);
        setAddress(false, sonicMainnet, "managerAddress", managerAddress);
        setAddress(false, sonicMainnet, "accountantAddress", accountantAddress);
        setAddress(false, sonicMainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== SonicGateway ==========================
        address[] memory mainnetAssets = new address[](1);
        address[] memory sonicAssets = new address[](1);
        mainnetAssets[0] = getAddress(mainnet, "sfrxUSD"); // Mainnet sfrxUSD
        sonicAssets[0] = getAddress(sonicMainnet, "scUSD"); // Sonic scUSD
        _addSonicGatewayLeafsSonic(leafs, mainnetAssets, sonicAssets);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "scUSD");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);

        // ========================== SiloV2 ==========================
        // IMPORTANT: This section is completely disabled because the Silo is not activated yet
        // Contract at address 0x4E09FF794D255a123b00efa30162667A8054a845 returns "NotActivated" 
        // when calling getSilos() - confirmed from execution trace
        // 
        // When Silo is activated, uncomment the following code:
        //
        // address[] memory incentivesControllers = new address[](2);
        // incentivesControllers[0] = address(0); 
        // incentivesControllers[1] = address(0);
        // _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_sfrxUSD_scUSD_id48_config"), incentivesControllers);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Sonic/SfrxUSDScUSDStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
} 