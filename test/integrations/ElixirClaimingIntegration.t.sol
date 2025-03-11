// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {EtherFiLiquidUsdDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidUsdDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract EthenaWithdrawIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

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
        uint256 blockNumber = 22024506;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new EtherFiLiquidUsdDecoderAndSanitizer(getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"))
        );

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

    function testEthenaWithdrawIntegration() external {

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addELXClaimingLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0]; //claim

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "elxTokenDistributor");

        //merkle proof
        bytes32[] memory merkleProofs = new bytes32[](13);
        merkleProofs[0] = 0x2ac656237c03eb3da4c23c1d3f9fe44e3c0e56a70957abd9f8422cdeb016c253;
        merkleProofs[1] = 0x8a9ca40ed7dcecf931aa6bbee0209424bff61c7c27ec43b5cd595cd4e2de36d9;
        merkleProofs[2] = 0xa966f249fe4484d42c74d63f13bb66416b812f6bde127ce7d728b42c9f9e9f6e;
        merkleProofs[3] = 0x049f162bd25dc9e957207485740e3d92e542db4623ef55a1012a93d67a99d9b8;
        merkleProofs[4] = 0xcc86d0e86a2f3303caacba362ed4663773692ce6436b9bd65acfca38823719070;
        merkleProofs[5] = 0x755d09e9a8d95fea930eb695a4c003ada3bb8387b42e3b21029edaeee20b7c82;
        merkleProofs[6] = 0xde1405b47b38f97342b4b323afe403acfa16e792c2be58a6e2e248eece5a85ad;
        merkleProofs[7] = 0x1b2df0180f736528dd29dda59e07051c622e9763cb1a95ae0f614fef7e00e3ff;
        merkleProofs[8] = 0xf8cb8665d6008ff837351acb04c8829cbd6c2677cf3b5db9e41b60add7e96181;
        merkleProofs[9] = 0x3120b8316d1c5e6b9c3b802c5ed83c0756b1a45d2a2f80838ea43677b60276980;
        merkleProofs[10] = 0x7f25fd751b9344055e81eb844672269fe1a05cb3d3841b7c16b9cb91529859b6;
        merkleProofs[11] = 0x0132354e4833ae849613407c62f5dcc18f401a92ec2d416456c93c36f83b315b;
        merkleProofs[12] = 0x766a125ee4bc084e6e9b689eba8ee84b11161dd2a976d4ceb8894db5f8d4c71e;
       
        bytes memory signature = hex"395b289f3397a83d4f68bbb3e2abd4bdcb62d140a28379d59b2ea44a49e4592633ad06abbaa9c540395d8a01f5ffeaf9f68b72ef24abc0e53d7fd897f90444801b"; 

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature(
            "claim(uint256,bytes32[],bytes)", 
            93315653340000000000, 
            merkleProofs,
            signature
        );

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](1);
        

        // NOTE: without a way to generate the proofs or signature for the vault, this is going to fail. 
        // The above proofs and signatures were taken from a passing TX for a user, but the vaults proofs and sig are unknown as this appears
        // to be generated on the FE for claims.  
        // At this point, I am unable to find any SDK or FE code that will do this for the vault addresses we need. 
        // The signature can be obtained from pranking the wallet on Rabby, but in order to generate the proofs this requires a siganture to be sent. 
        vm.expectRevert(); 
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface EthenaSusde {
    function cooldownDuration() external view returns (uint24);
    function cooldowns(address) external view returns (uint104 cooldownEnd, uint152 underlyingAmount);
}
