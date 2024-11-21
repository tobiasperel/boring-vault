// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployTimelock.s.sol:DeployTimelockScript --with-gas-price 15000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployTimelockScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;

    // Contracts to deploy
    RolesAuthority public rolesAuthority;
    Deployer public deployer;
    TimelockController public timelock;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        deployer = Deployer(deployerAddress);
        creationCode = type(TimelockController).creationCode;
        uint256 minDelay = 300;
        address[] memory proposers = new address[](2);
        proposers[0] = dev0Address;
        proposers[1] = dev1Address;
        address[] memory executors = new address[](1);
        executors[0] = 0xCEA8039076E35a825854c5C2f85659430b06ec96; // Mainnet multisig
        address admin = address(0);
        constructorArgs = abi.encode(minDelay, proposers, executors, admin);
        timelock =
            TimelockController(payable(deployer.deployContract("eBTC Timelock V0.0", creationCode, constructorArgs, 0)));

        timelock.schedule(
            address(timelock),
            0,
            abi.encodeWithSelector(TimelockController.updateDelay.selector, 1 days),
            bytes32(0),
            bytes32(0),
            300
        );

        vm.stopBroadcast();
    }
}
