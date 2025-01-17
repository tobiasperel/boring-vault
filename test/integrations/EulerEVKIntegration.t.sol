// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {EulerEVKFullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EulerEVKFullDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {DroneLib} from "src/base/Drones/DroneLib.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";

import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract EulerEVKIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;
    BoringDrone public boringDrone;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21431088;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        boringDrone = new BoringDrone(address(boringVault), 0);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new EulerEVKFullDecoderAndSanitizer());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MANGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);
    }

    function testEulerEVKIntegration() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        ERC4626 evkWEETH = ERC4626(getAddress(sourceChain, "evkWETH"));
        ERC4626 evkUSDC = ERC4626(getAddress(sourceChain, "evkUSDC"));

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addEulerEVKLeafs(
            leafs,
            getERC20(sourceChain, "USDC"), //asset we're borrowing
            getAddress(sourceChain, "ethereumVaultConnector"),
            evkWEETH, //vault we want to deposit into
            evkUSDC //vaut we want to borrow from
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](11);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[6];
        manageLeafs[7] = leafs[7];
        manageLeafs[8] = leafs[8];
        manageLeafs[9] = leafs[9];
        manageLeafs[10] = leafs[10];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](11);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "evkWETH");
        targets[2] = getAddress(sourceChain, "evkWETH");
        targets[3] = getAddress(sourceChain, "evkWETH");
        targets[4] = getAddress(sourceChain, "evkWETH");
        targets[5] = getAddress(sourceChain, "USDC");
        targets[6] = getAddress(sourceChain, "ethereumVaultConnector");
        targets[7] = getAddress(sourceChain, "ethereumVaultConnector");
        targets[8] = getAddress(sourceChain, "evkUSDC");
        targets[9] = getAddress(sourceChain, "evkUSDC");
        targets[10] = getAddress(sourceChain, "evkUSDC");

        bytes[] memory targetData = new bytes[](11);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "evkWETH"), type(uint256).max);
        targetData[1] = abi.encodeWithSignature("deposit(uint256,address)", 1000e18, address(boringVault));
        targetData[2] = abi.encodeWithSignature(
            "withdraw(uint256,address,address)", 1e18, address(boringVault), address(boringVault)
        );
        targetData[3] = abi.encodeWithSignature("mint(uint256,address)", 100, address(boringVault));
        targetData[4] =
            abi.encodeWithSignature("redeem(uint256,address,address)", 100, address(boringVault), address(boringVault));
        targetData[5] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "evkUSDC"), type(uint256).max);
        targetData[6] = abi.encodeWithSignature(
            "enableController(address,address)", address(boringVault), getAddress(sourceChain, "evkUSDC")
        );
        targetData[7] = abi.encodeWithSignature(
            "enableCollateral(address,address)", address(boringVault), getAddress(sourceChain, "evkWETH")
        );
        targetData[8] = abi.encodeWithSignature("borrow(uint256,address)", 1e6, address(boringVault));
        targetData[9] = abi.encodeWithSignature("repay(uint256,address)", 1e4, address(boringVault));
        targetData[10] =
            abi.encodeWithSignature("repayWithShares(uint256,address)", type(uint256).max, address(boringVault));

        uint256[] memory values = new uint256[](11);

        address[] memory decodersAndSanitizers = new address[](11);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[10] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testEulerEVKIntegrationDisableCollateral() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        ERC4626 evkWEETH = ERC4626(getAddress(sourceChain, "evkWETH"));
        ERC4626 evkUSDC = ERC4626(getAddress(sourceChain, "evkUSDC"));

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addEulerEVKLeafs(
            leafs,
            getERC20(sourceChain, "USDC"), //asset we're borrowing
            getAddress(sourceChain, "ethereumVaultConnector"),
            evkWEETH, //vault we want to deposit into
            evkUSDC //vaut we want to borrow from
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[5]; //approve borrow vault
        manageLeafs[1] = leafs[6]; //enableController
        manageLeafs[2] = leafs[7]; //enableCollateral
        manageLeafs[3] = leafs[11]; //disableCollateral
        manageLeafs[4] = leafs[12]; //disableController

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](5);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "ethereumVaultConnector");
        targets[2] = getAddress(sourceChain, "ethereumVaultConnector");
        targets[3] = getAddress(sourceChain, "ethereumVaultConnector");
        targets[4] = getAddress(sourceChain, "ethereumVaultConnector");

        bytes[] memory targetData = new bytes[](5);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "evkUSDC"), type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "enableController(address,address)", address(boringVault), getAddress(sourceChain, "evkUSDC")
        );
        targetData[2] = abi.encodeWithSignature(
            "enableCollateral(address,address)", address(boringVault), getAddress(sourceChain, "evkWETH")
        );
        targetData[3] = abi.encodeWithSignature(
            "disableCollateral(address,address)", address(boringVault), getAddress(sourceChain, "evkWETH")
        );
        targetData[4] = abi.encodeWithSignature(
            "disableController(address)", address(boringVault)
        );

        uint256[] memory values = new uint256[](5);

        address[] memory decodersAndSanitizers = new address[](5);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }


    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface IEVK {
    function balanceOf(address user) external view returns (uint256);
    function asset() external view returns (address);
    function creator() external view returns (address);
}
