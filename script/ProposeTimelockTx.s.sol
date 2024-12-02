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
 *  source .env && forge script script/ProposeTimelockTx.s.sol:ProposeTimelockTxScript --with-gas-price 15000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract ProposeTimelockTxScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;

    RolesAuthority public rolesAuthority = RolesAuthority(0x6889E57BcA038C28520C0B047a75e567502ea5F6);
    TimelockController public timelock = TimelockController(payable(0x70a64840A353c58f63333570f53dba0948bEcE3d));

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        address multisig = 0xCEA8039076E35a825854c5C2f85659430b06ec96;
        uint8 ownerRole = 8;

        timelock.schedule(
            address(rolesAuthority),
            0,
            abi.encodeWithSelector(RolesAuthority.setUserRole.selector, multisig, ownerRole, false),
            bytes32(0),
            bytes32(0),
            1 days
        );

        vm.stopBroadcast();
    }
}
