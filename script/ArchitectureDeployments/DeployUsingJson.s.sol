// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {ChainValues} from "test/resources/ChainValues.sol";

// Import Decoder and Sanitizer to deploy.
import {ITBPositionDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/ITBPositionDecoderAndSanitizer.sol";
import {console} from "@forge-std/Test.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/DeployUsingJson.s.sol:DeployUsingJsonScript --with-gas-price 30000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployUsingJsonScript is DeployArcticArchitecture, ChainValues {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    // MUST BE ORDERED ALPHABETICALLY
    struct WithdrawAssetConfig {
        string asset;
        uint256 completionWindow;
        uint256 maxLoss;
        uint256 withdrawDelay;
        uint256 withdrawFee;
    }

    function run() external view {
        string memory root = vm.projectRoot();
        string memory configPath = string.concat(root, "/script/ArchitectureDeployments/config.json");
        string memory json = vm.readFile(configPath);

        if (vm.keyExists(json, ".chainName")) {
            string memory chainName = vm.parseJsonString(json, ".chainName");
            console.log("Chain name:", chainName);
        }

        if (vm.keyExists(json, ".withdrawAssets")) {
            // Log the raw JSON first
            console.log("Raw withdraw assets JSON:");
            console.logBytes(vm.parseJson(json, ".withdrawAssets"));

            bytes memory withdrawAssets = vm.parseJson(json, ".withdrawAssets");
            WithdrawAssetConfig[] memory withdrawAssetConfigs = abi.decode(withdrawAssets, (WithdrawAssetConfig[]));

            for (uint256 i = 0; i < withdrawAssetConfigs.length; i++) {
                WithdrawAssetConfig memory config = withdrawAssetConfigs[i];
                console.log("\nWithdraw Asset", i);
                console.log("Asset:", config.asset);
                console.log("Completion Window:", config.completionWindow);
                console.log("Withdraw Fee:", config.withdrawFee);
                console.log("Max Loss:", config.maxLoss);
                console.log("Withdraw Delay:", config.withdrawDelay);
            }
        }
    }
}
