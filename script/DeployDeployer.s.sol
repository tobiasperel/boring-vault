// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {MockERC20} from "src/helper/MockERC20.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployDeployer.s.sol:DeployDeployerScript --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployDeployerScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;

    // Contracts to deploy
    RolesAuthority public rolesAuthority;
    Deployer public deployer;

    uint8 public DEPLOYER_ROLE = 1;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("polygon");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        // deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d);
        // rolesAuthority = RolesAuthority(0x4df6b73328B639073db150C4584196c4d97053b7);

        // deployer.setAuthority(rolesAuthority);

        // rolesAuthority.setRoleCapability(DEPLOYER_ROLE, address(deployer), Deployer.deployContract.selector, true);
        // rolesAuthority.setUserRole(dev0Address, DEPLOYER_ROLE, true);
        // rolesAuthority.setUserRole(dev1Address, DEPLOYER_ROLE, true);

        // // Deploy deployer to act as tx bundler.
        // deployer = new Deployer(dev0Address, rolesAuthority);

        // rolesAuthority.setUserRole(address(deployer), DEPLOYER_ROLE, true);

        deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d);

        constructorArgs = abi.encode("Crispy USD", "CUSD", 6);
        creationCode = type(MockERC20).creationCode;
        MockERC20(deployer.deployContract("CrispyUSD V0.1", creationCode, constructorArgs, 0));

        vm.stopBroadcast();
    }
}
