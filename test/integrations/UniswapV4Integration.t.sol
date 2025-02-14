// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {UniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {Actions, Commands, TickMath, LiquidityAmounts, Constants} from "src/interfaces/UniswapV4Actions.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract UniswapV4IntegrationTest is Test, MerkleTreeHelper {
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
        uint256 blockNumber = 21838936;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullUniswapV4DecoderAndSanitizer());

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

    function testUniswapV4Swaps() external {
        deal(getAddress(sourceChain, "USDT"), address(boringVault), 1_000_000e6);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e8);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "USDT");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");

        _addUniswapV4Leafs(leafs, token0, token1);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        _generateTestLeafs(leafs, manageTree); 

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](10);
        manageLeafs[0] = leafs[0]; //approve USDC router
        manageLeafs[1] = leafs[2]; //approve USDC permit2
        manageLeafs[2] = leafs[3]; //approve USDC permit2 router

        manageLeafs[3] = leafs[5]; //approve USDT router
        manageLeafs[4] = leafs[7]; //approve USDT permit2
        manageLeafs[5] = leafs[8]; //approve USDT permit2 router

        manageLeafs[6] = leafs[10]; //execute() V4_SWAP

        manageLeafs[7] = leafs[4]; //approve permit2 for positionManager
        manageLeafs[8] = leafs[9]; //approve positionManager()
        manageLeafs[9] = leafs[12]; //modifyLiquidities()

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](10);
        targets[0] = getAddress(sourceChain, "USDC"); //approve router
        targets[1] = getAddress(sourceChain, "USDC"); //approve permit2
        targets[2] = getAddress(sourceChain, "permit2"); //approve permit2 router

        targets[3] = getAddress(sourceChain, "USDT"); //approve 
        targets[4] = getAddress(sourceChain, "USDT"); //approve 
        targets[5] = getAddress(sourceChain, "permit2"); //approve permit2 router

        targets[6] = getAddress(sourceChain, "uniV4UniversalRouter");

        targets[7] = getAddress(sourceChain, "permit2"); //approve permit2 posm usdc
        targets[8] = getAddress(sourceChain, "permit2"); //approve permit2 posm usdt 
        targets[9] = getAddress(sourceChain, "uniV4PositionManager");

        bytes[] memory targetData = new bytes[](10);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV4UniversalRouter"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        targetData[2] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", getAddress(sourceChain, "USDC"), getAddress(sourceChain, "uniV4UniversalRouter"), 1000e8, block.timestamp + 1000
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV4UniversalRouter"), type(uint256).max
        );
        targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        targetData[5] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", getAddress(sourceChain, "USDT"), getAddress(sourceChain, "uniV4UniversalRouter"), type(uint160).max, block.timestamp + 1000
        );
        
        // Universal Router takes 2 params, commands and inputs. 
        // Commands == V4_SWAP
        // Inputs are broken down into smaller things: Actions and Params
        // Actions help the flow of the swap, and Params are params for the actions
        // Actions.SWAP_SINGLE would have params of SwapParams, etc
        // these are then put together in inputs[0] = abi.encode(actions, params); 
        // and this is used in the `execute()` function

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        DecoderCustomTypes.PoolKey memory key = DecoderCustomTypes.PoolKey(
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "USDT"),
            100,
            1,
            address(0) //no hook address?
        );         

        uint128 amountIn = 1e8; 
        uint128 minAmountOut = 0; 

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            DecoderCustomTypes.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,            // true if we're swapping token0 for token1
                amountIn: amountIn,          // amount of tokens we're swapping
                amountOutMinimum: minAmountOut, // minimum amount we expect to receive
                hookData: bytes("")             // no hook data needed
            })
        );

        // Second parameter: specify input tokens for the swap
        // encode SETTLE_ALL parameters
        params[1] = abi.encode(key.currency0, amountIn);
        // Third parameter: specify output tokens from the swap
        params[2] = abi.encode(key.currency1, minAmountOut);
        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);


        targetData[6] = abi.encodeWithSignature(
            "execute(bytes,bytes[],uint256)", commands, inputs, block.timestamp
        );

        targetData[7] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", getAddress(sourceChain, "USDC"), getAddress(sourceChain, "uniV4PositionManager"), type(uint160).max, type(uint48).max
        );
        targetData[8] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", getAddress(sourceChain, "USDT"), getAddress(sourceChain, "uniV4PositionManager"), type(uint160).max, type(uint48).max
        );
        { 
        //actions
        bytes memory liquidityActions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_ALL)); 
        params = new bytes[](2); 

        int24 tickLower = TickMath.minUsableTick(key.tickSpacing);
        int24 tickUpper = TickMath.maxUsableTick(key.tickSpacing);
        
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            uint128(100e6)
        );

        params[0] = abi.encode(
            key, 
            tickLower,
            tickUpper,
            100e6,
            type(uint256).max,
            type(uint256).max,
            address(boringVault),
            block.timestamp + 1,
            new bytes(0)
        ); 
        params[1] = abi.encode(key.currency0, key.currency1); 


        targetData[9] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );
        }

        address[] memory decodersAndSanitizers = new address[](10);
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

        uint256[] memory values = new uint256[](10);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullUniswapV4DecoderAndSanitizer is UniswapV4DecoderAndSanitizer {}

interface IUniswapV2Factory {
    function getPair(address token0, address token1) external view returns (address);
}
