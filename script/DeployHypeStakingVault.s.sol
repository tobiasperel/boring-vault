// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority} from "lib/solmate/src/auth/authorities/RolesAuthority.sol";
import {Authority} from "lib/solmate/src/auth/Auth.sol";
import {HypeStakingLoopingManager} from "src/micro-managers/HypeStakingLoopingManager.sol";
import {HypeStakingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/HypeStakingDecoderAndSanitizer.sol";

/**
 * @title DeployHypeStakingVault
 * @notice Deployment script for HYPE Staking Vault with BoringVault architecture
 */
contract DeployHypeStakingVault is Script {
    // Deployment addresses - update these before deployment
    address public constant DEPLOYER = 0x0000000000000000000000000000000000000000;
    address public constant VAULT_OWNER = 0x0000000000000000000000000000000000000000;
    address public constant STRATEGIST = 0x0000000000000000000000000000000000000000;
    
    // Protocol addresses - update with real addresses
    address public constant HYPE_TOKEN = 0x0000000000000000000000000000000000000000;
    address public constant STHYPE_TOKEN = 0x0000000000000000000000000000000000000000;
    address public constant HYPE_STAKING_CONTRACT = 0x0000000000000000000000000000000000000000;
    address public constant FELIX_LENDING_POOL = 0x0000000000000000000000000000000000000000;
    address public constant UNISWAP_V3_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88; // Mainnet
    address public constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8; // Mainnet Balancer Vault

    // Vault configuration
    string public constant VAULT_NAME = "HYPE Staking Vault";
    string public constant VAULT_SYMBOL = "hsHYPE";
    uint8 public constant VAULT_DECIMALS = 18;

    function run() external {
        vm.startBroadcast(DEPLOYER);

        console.log("Deploying HYPE Staking Vault...");

        // 1. Deploy RolesAuthority
        RolesAuthority rolesAuthority = new RolesAuthority(VAULT_OWNER, Authority(address(0)));
        console.log("RolesAuthority deployed at:", address(rolesAuthority));

        // 2. Deploy BoringVault
        BoringVault boringVault = new BoringVault(VAULT_OWNER, VAULT_NAME, VAULT_SYMBOL, VAULT_DECIMALS);
        console.log("BoringVault deployed at:", address(boringVault));

        // 3. Deploy Manager
        ManagerWithMerkleVerification manager = new ManagerWithMerkleVerification(
            VAULT_OWNER,
            address(boringVault),
            BALANCER_VAULT
        );
        console.log("Manager deployed at:", address(manager));

        // 4. Deploy Decoder and Sanitizer
        HypeStakingDecoderAndSanitizer decoderAndSanitizer = new HypeStakingDecoderAndSanitizer(
            UNISWAP_V3_POSITION_MANAGER,
            HYPE_TOKEN,
            STHYPE_TOKEN,
            HYPE_STAKING_CONTRACT,
            FELIX_LENDING_POOL
        );
        console.log("Decoder and Sanitizer deployed at:", address(decoderAndSanitizer));

        // 5. Deploy Strategy Manager
        HypeStakingLoopingManager strategyManager = new HypeStakingLoopingManager(
            VAULT_OWNER,
            address(rolesAuthority),
            address(boringVault),
            address(manager),
            HYPE_TOKEN,
            STHYPE_TOKEN,
            HYPE_STAKING_CONTRACT,
            FELIX_LENDING_POOL,
            address(decoderAndSanitizer)
        );
        console.log("Strategy Manager deployed at:", address(strategyManager));

        console.log("\nDeployment Summary:");
        console.log("==================");
        console.log("BoringVault:", address(boringVault));
        console.log("Manager:", address(manager));
        console.log("RolesAuthority:", address(rolesAuthority));
        console.log("DecoderAndSanitizer:", address(decoderAndSanitizer));
        console.log("StrategyManager:", address(strategyManager));

        console.log("\nNext steps:");
        console.log("1. Set up roles and permissions");
        console.log("2. Generate and set merkle root");
        console.log("3. Configure strategy parameters");

        vm.stopBroadcast();
    }
}