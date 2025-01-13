// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {TimelockController, AccessControl} from "@openzeppelin/contracts/governance/TimelockController.sol";
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

    address public safe = 0x3FF1db55460125C667f5d2c68aAaBdeDf3FB2948;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("corn");
    }

    function run() external {
        // bytes memory creationCode;
        // bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        // deployer = Deployer(deployerAddress);
        // creationCode = type(TimelockController).creationCode;
        // uint256 minDelay = 300;
        // address[] memory proposers = new address[](2);
        // proposers[0] = dev1Address;
        // proposers[1] = dev0Address;
        // address[] memory executors = new address[](2);
        // executors[0] = dev1Address;
        // executors[1] = dev0Address;
        // address admin = address(0);
        // constructorArgs = abi.encode(minDelay, proposers, executors, admin);
        // timelock =
        // TimelockController(payable(deployer.deployContract("eBTC Timelock V0.0", creationCode, constructorArgs, 0)));

        timelock = TimelockController(payable(0x70a64840A353c58f63333570f53dba0948bEcE3d));

        address[] memory targets = new address[](3);
        targets[0] = address(timelock);
        targets[1] = address(timelock);
        targets[2] = address(timelock);

        bytes[] memory payloads = new bytes[](3);
        payloads[0] = abi.encodeWithSelector(AccessControl.grantRole.selector, timelock.PROPOSER_ROLE(), safe);
        payloads[1] = abi.encodeWithSelector(AccessControl.grantRole.selector, timelock.EXECUTOR_ROLE(), safe);
        payloads[2] = abi.encodeWithSelector(AccessControl.grantRole.selector, timelock.CANCELLER_ROLE(), safe);

        uint256[] memory values = new uint256[](3);

        timelock.executeBatch(targets, values, payloads, bytes32(0), bytes32(0));

        // targets = new address[](7);
        // targets[0] = address(timelock);
        // targets[1] = address(timelock);
        // targets[2] = address(timelock);
        // targets[3] = address(timelock);
        // targets[4] = address(timelock);
        // targets[5] = address(timelock);
        // targets[6] = address(timelock);
        // payloads = new bytes[](7);
        // payloads[0] = abi.encodeWithSelector(AccessControl.revokeRole.selector, timelock.PROPOSER_ROLE(), dev0Address);
        // payloads[1] = abi.encodeWithSelector(AccessControl.revokeRole.selector, timelock.EXECUTOR_ROLE(), dev0Address);
        // payloads[2] = abi.encodeWithSelector(AccessControl.revokeRole.selector, timelock.CANCELLER_ROLE(), dev0Address);
        // payloads[3] = abi.encodeWithSelector(AccessControl.revokeRole.selector, timelock.PROPOSER_ROLE(), dev1Address);
        // payloads[4] = abi.encodeWithSelector(AccessControl.revokeRole.selector, timelock.EXECUTOR_ROLE(), dev1Address);
        // payloads[5] = abi.encodeWithSelector(AccessControl.revokeRole.selector, timelock.CANCELLER_ROLE(), dev1Address);
        // payloads[6] = abi.encodeWithSelector(TimelockController.updateDelay.selector, 1 days);

        // values = new uint256[](7);

        // timelock.scheduleBatch(targets, values, payloads, bytes32(0), bytes32(0), 300);

        vm.stopBroadcast();
    }
}
