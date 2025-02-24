// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol"; 
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  forge script script/DeployGenericRateProvider.s.sol:DeployGenericRateProvider --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployGenericRateProvider is Script, ContractNames, Test {
    uint256 public privateKey;
    
    address target = 0x7122985656e38BDC0302Db86685bb972b145bD3C; 
    bytes4 selector = 0x7ff9b596; 
    Deployer deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d); 

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        creationCode = type(GenericRateProvider).creationCode;
        constructorArgs = abi.encode(
            target, 
            selector,
            0, 0,
            0, 0,
            0, 0,
            0, 0
        );
        deployer.deployContract("STONE Rate Provider V0.0", creationCode, constructorArgs, 0); 

    }

}
