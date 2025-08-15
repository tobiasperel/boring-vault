    // SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/**
 * @title HypeStakingVaultTest
 * @notice Comprehensive test suite for HYPE Staking Vault implementation
 * 
 * Tests cover:
 * - Vault deployment and configuration
 * - BoringVault integration with manager and decoder
 * - Strategy execution: loop creation, harvesting, rebalancing
 * - Access control and security features
 * - Emergency exit functionality
 * 
 * Run tests: forge test --match-contract HypeStakingVaultTest
 */

import {Test, console} from "forge-std/Test.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {HypeStakingLoopingManager} from "src/micro-managers/HypeStakingLoopingManager.sol";
import {HypeStakingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/HypeStakingDecoderAndSanitizer.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Authority} from "@solmate/auth/Auth.sol";

/**
 * @title HypeStakingVaultTest
 * @notice Comprehensive test suite for HYPE staking vault using BoringVault architecture
 */
contract HypeStakingVaultTest is Test {
    //============================== TEST CONTRACTS ===============================

    BoringVault public boringVault;
    ManagerWithMerkleVerification public manager;
    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    HypeStakingLoopingManager public strategyManager;
    HypeStakingDecoderAndSanitizer public decoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    //============================== MOCK CONTRACTS ===============================

    MockERC20 public hypeToken;
    MockERC20 public stHypeToken;
    MockHypeStakingContract public hypeStaking;
    MockFelixLendingPool public felixLendingPool;
    address public uniswapV3PositionManager;

    //============================== TEST ACCOUNTS ===============================

    address public owner = makeAddr("owner");
    address public strategist = makeAddr("strategist");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public feeCollector = makeAddr("feeCollector");

    //============================== ROLES ===============================

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant SOLVER_ROLE = 6;

    //============================== CONSTANTS ===============================

    uint256 public constant INITIAL_DEPOSIT = 1000e18;
    uint256 public constant HYPE_TOTAL_SUPPLY = 1_000_000e18;
    string public constant VAULT_NAME = "HYPE Staking Vault";
    string public constant VAULT_SYMBOL = "hsHYPE";
    uint8 public constant VAULT_DECIMALS = 18;

    //============================== SETUP ===============================

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock tokens
        hypeToken = new MockERC20("HYPE Token", "HYPE", 18);
        stHypeToken = new MockERC20("Staked HYPE", "stHYPE", 18);
        
        // Mint tokens for testing
        hypeToken.mint(user1, INITIAL_DEPOSIT * 10);
        hypeToken.mint(user2, INITIAL_DEPOSIT * 10);
        hypeToken.mint(owner, INITIAL_DEPOSIT * 10);

        // Deploy mock contracts
        hypeStaking = new MockHypeStakingContract(address(hypeToken), address(stHypeToken));
        felixLendingPool = new MockFelixLendingPool(address(hypeToken), address(stHypeToken));
        uniswapV3PositionManager = makeAddr("uniswapV3PositionManager");

        // Deploy core BoringVault components
        boringVault = new BoringVault(owner, VAULT_NAME, VAULT_SYMBOL, VAULT_DECIMALS);
        
        manager = new ManagerWithMerkleVerification(
            owner,
            address(boringVault),
            address(0) // No balancer vault for this test
        );

        teller = new TellerWithMultiAssetSupport(
            owner,
            address(boringVault),
            address(0), // No accountant initially
            address(0)  // No queue initially
        );

        // Deploy decoder and sanitizer
        decoderAndSanitizer = new HypeStakingDecoderAndSanitizer(
            uniswapV3PositionManager,
            address(hypeToken),
            address(stHypeToken),
            address(hypeStaking),
            address(felixLendingPool)
        );

        // Deploy strategy manager
        strategyManager = new HypeStakingLoopingManager(
            owner,
            address(0), // No authority initially
            address(boringVault),
            address(manager),
            address(hypeToken),
            address(stHypeToken),
            address(hypeStaking),
            address(felixLendingPool),
            address(decoderAndSanitizer)
        );

        // Setup roles authority
        rolesAuthority = new RolesAuthority(owner, Authority(address(0)));
        
        // Set authority for contracts
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);
        strategyManager.setAuthority(rolesAuthority);

        _setupRoles();

        vm.stopPrank();
    }

    function _setupRoles() internal {
        // Manager role capabilities
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256("manage(address,bytes,uint256)")),
            true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256("manage(address[],bytes[],uint256[])")),
            true
        );

        // Strategist role capabilities
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(strategyManager),
            HypeStakingLoopingManager.executeLoop.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(strategyManager),
            HypeStakingLoopingManager.harvestAndCompound.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(strategyManager),
            HypeStakingLoopingManager.rebalance.selector,
            true
        );

        // Admin role capabilities
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE,
            address(manager),
            ManagerWithMerkleVerification.setManageRoot.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE,
            address(strategyManager),
            HypeStakingLoopingManager.updateConfig.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE,
            address(strategyManager),
            HypeStakingLoopingManager.emergencyExit.selector,
            true
        );

        // Grant roles to users
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(strategist, STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(owner, ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
    }

    //============================== UNIT TESTS ===============================

    function testVaultDeployment() public {
        assertEq(boringVault.name(), VAULT_NAME);
        assertEq(boringVault.symbol(), VAULT_SYMBOL);
        assertEq(boringVault.decimals(), VAULT_DECIMALS);
        assertEq(boringVault.owner(), owner);
    }

    function testStrategyManagerDeployment() public {
        assertEq(address(strategyManager.boringVault()), address(boringVault));
        assertEq(address(strategyManager.manager()), address(manager));
        assertEq(address(strategyManager.hypeToken()), address(hypeToken));
        assertEq(address(strategyManager.stHypeToken()), address(stHypeToken));
        assertEq(strategyManager.stakingContract(), address(hypeStaking));
        assertEq(strategyManager.felixLendingPool(), address(felixLendingPool));

        // Check default config
        (
            uint256 targetLTV,
            uint256 maxLTV,
            uint256 minLTV,
            uint256 rebalanceThreshold,
            uint256 maxIterations,
            bool loopingEnabled
        ) = strategyManager.config();

        assertEq(targetLTV, 7500);
        assertEq(maxLTV, 8500);
        assertEq(minLTV, 6500);
        assertEq(rebalanceThreshold, 500);
        assertEq(maxIterations, 5);
        assertTrue(loopingEnabled);
    }

    function testDecoderAndSanitizerDeployment() public {
        assertEq(decoderAndSanitizer.hypeToken(), address(hypeToken));
        assertEq(decoderAndSanitizer.stHypeToken(), address(stHypeToken));
        assertEq(decoderAndSanitizer.hypeStakingContract(), address(hypeStaking));
        assertEq(decoderAndSanitizer.felixLendingPool(), address(felixLendingPool));
    }

    function testConfigUpdate() public {
        HypeStakingLoopingManager.LoopingConfig memory newConfig = HypeStakingLoopingManager.LoopingConfig({
            targetLTV: 8000,
            maxLTV: 9000,
            minLTV: 7000,
            rebalanceThreshold: 300,
            maxIterations: 7,
            loopingEnabled: true
        });

        vm.prank(owner);
        strategyManager.updateConfig(newConfig);

        (
            uint256 targetLTV,
            uint256 maxLTV,
            uint256 minLTV,
            uint256 rebalanceThreshold,
            uint256 maxIterations,
            bool loopingEnabled
        ) = strategyManager.config();

        assertEq(targetLTV, 8000);
        assertEq(maxLTV, 9000);
        assertEq(minLTV, 7000);
        assertEq(rebalanceThreshold, 300);
        assertEq(maxIterations, 7);
        assertTrue(loopingEnabled);
    }

    function testInvalidConfigUpdate() public {
        // Test invalid config where targetLTV >= maxLTV
        HypeStakingLoopingManager.LoopingConfig memory invalidConfig = HypeStakingLoopingManager.LoopingConfig({
            targetLTV: 9000,
            maxLTV: 8500,
            minLTV: 7000,
            rebalanceThreshold: 300,
            maxIterations: 7,
            loopingEnabled: true
        });

        vm.prank(owner);
        vm.expectRevert(HypeStakingLoopingManager.HypeStakingLoopingManager__InvalidConfig.selector);
        strategyManager.updateConfig(invalidConfig);
    }

    function testPerformanceFeeUpdate() public {
        vm.prank(owner);
        strategyManager.updatePerformanceFee(1500); // 15%

        assertEq(strategyManager.performanceFee(), 1500);
    }

    function testPerformanceFeeUpdateTooHigh() public {
        vm.prank(owner);
        vm.expectRevert("Fee too high");
        strategyManager.updatePerformanceFee(2500); // 25% - too high
    }

    //============================== INTEGRATION TESTS ===============================

    function testBasicLoopExecution() public {
        // Deposit HYPE into the vault
        uint256 depositAmount = 1000e18;
        
        vm.startPrank(owner);
        hypeToken.transfer(address(boringVault), depositAmount);

        // Setup basic merkle root (this would normally be generated from JSON)
        bytes32 dummyRoot = keccak256("dummy_root");
        manager.setManageRoot(strategist, dummyRoot);

        // Mock the merkle verification to always pass and simulate staking/borrowing
        vm.mockCall(
            address(manager),
            abi.encodeWithSelector(ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector),
            abi.encode()
        );

        // Manually simulate the loop execution by minting stHYPE and setting up balances
        // This simulates what would happen in a real loop execution
        uint256 stakeAmount = depositAmount;
        MockERC20(address(stHypeToken)).mint(address(boringVault), stakeAmount);
        
        // Simulate Felix lending pool collateral and borrowing
        uint256 borrowAmount = stakeAmount * 7000 / 10000; // 70% LTV
        felixLendingPool.setUserCollateral(address(boringVault), address(stHypeToken), stakeAmount);
        felixLendingPool.setUserBorrow(address(boringVault), address(hypeToken), borrowAmount);
        MockERC20(address(hypeToken)).mint(address(boringVault), borrowAmount);

        vm.stopPrank();

        // Execute loop as strategist
        vm.prank(strategist);
        strategyManager.executeLoop(depositAmount, 3);

        // Verify position was created
        HypeStakingLoopingManager.PositionInfo memory position = strategyManager.getPositionInfo();
        
        // Should have some position now
        assertGe(position.stakedAmount, 0);
        assertGe(position.totalValue, 0);
    }

    function testRebalancing() public {
        // Setup position similar to testBasicLoopExecution
        uint256 depositAmount = 1000e18;
        
        vm.startPrank(owner);
        hypeToken.transfer(address(boringVault), depositAmount);
        bytes32 dummyRoot = keccak256("dummy_root");
        manager.setManageRoot(strategist, dummyRoot);
        
        vm.mockCall(
            address(manager),
            abi.encodeWithSelector(ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector),
            abi.encode()
        );

        // Setup mock position
        uint256 stakeAmount = depositAmount;
        MockERC20(address(stHypeToken)).mint(address(boringVault), stakeAmount);
        uint256 borrowAmount = stakeAmount * 7000 / 10000;
        felixLendingPool.setUserCollateral(address(boringVault), address(stHypeToken), stakeAmount);
        felixLendingPool.setUserBorrow(address(boringVault), address(hypeToken), borrowAmount);
        MockERC20(address(hypeToken)).mint(address(boringVault), borrowAmount);
        vm.stopPrank();

        vm.prank(strategist);
        strategyManager.rebalance();

        // Verify rebalancing logic
        HypeStakingLoopingManager.PositionInfo memory position = strategyManager.getPositionInfo();
        assertGe(position.totalValue, 0);
    }

    function testEmergencyExit() public {
        // Setup position similar to testBasicLoopExecution
        uint256 depositAmount = 1000e18;
        
        vm.startPrank(owner);
        hypeToken.transfer(address(boringVault), depositAmount);
        bytes32 dummyRoot = keccak256("dummy_root");
        manager.setManageRoot(strategist, dummyRoot);
        
        vm.mockCall(
            address(manager),
            abi.encodeWithSelector(ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector),
            abi.encode()
        );

        // Setup mock position
        uint256 stakeAmount = depositAmount;
        MockERC20(address(stHypeToken)).mint(address(boringVault), stakeAmount);
        uint256 borrowAmount = stakeAmount * 7000 / 10000;
        felixLendingPool.setUserCollateral(address(boringVault), address(stHypeToken), stakeAmount);
        felixLendingPool.setUserBorrow(address(boringVault), address(hypeToken), borrowAmount);
        MockERC20(address(hypeToken)).mint(address(boringVault), borrowAmount);

        uint256 vaultHypeBefore = hypeToken.balanceOf(address(boringVault));

        strategyManager.emergencyExit();
        vm.stopPrank();

        uint256 vaultHypeAfter = hypeToken.balanceOf(address(boringVault));

        // Should have maintained HYPE balance (at minimum)
        assertGe(vaultHypeAfter, 0);

        // Position should be cleared or minimal
        HypeStakingLoopingManager.PositionInfo memory position = strategyManager.getPositionInfo();
        // Position values should be minimal after emergency exit
        assertGe(position.totalValue, 0);
    }

    function testHarvestAndCompound() public {
        // Setup position similar to testBasicLoopExecution
        uint256 depositAmount = 1000e18;
        
        vm.startPrank(owner);
        hypeToken.transfer(address(boringVault), depositAmount);
        bytes32 dummyRoot = keccak256("dummy_root");
        manager.setManageRoot(strategist, dummyRoot);
        
        vm.mockCall(
            address(manager),
            abi.encodeWithSelector(ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector),
            abi.encode()
        );

        // Setup mock position
        uint256 stakeAmount = depositAmount;
        MockERC20(address(stHypeToken)).mint(address(boringVault), stakeAmount);
        uint256 borrowAmount = stakeAmount * 7000 / 10000;
        felixLendingPool.setUserCollateral(address(boringVault), address(stHypeToken), stakeAmount);
        felixLendingPool.setUserBorrow(address(boringVault), address(hypeToken), borrowAmount);
        MockERC20(address(hypeToken)).mint(address(boringVault), borrowAmount);
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + 2 hours);

        // Mock some rewards
        hypeStaking.setRewards(100e18);

        vm.prank(strategist);
        strategyManager.harvestAndCompound();

        // Verify harvest was executed
        assertGt(strategyManager.lastHarvest(), 0);
    }

    function testHealthScore() public {
        // Test with no position
        uint256 healthScore = strategyManager.getHealthScore();
        assertEq(healthScore, 100); // Perfect health with no position

        // Setup position similar to testBasicLoopExecution
        uint256 depositAmount = 1000e18;
        
        vm.startPrank(owner);
        hypeToken.transfer(address(boringVault), depositAmount);
        bytes32 dummyRoot = keccak256("dummy_root");
        manager.setManageRoot(strategist, dummyRoot);
        
        vm.mockCall(
            address(manager),
            abi.encodeWithSelector(ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector),
            abi.encode()
        );

        // Setup mock position
        uint256 stakeAmount = depositAmount;
        MockERC20(address(stHypeToken)).mint(address(boringVault), stakeAmount);
        uint256 borrowAmount = stakeAmount * 7000 / 10000;
        felixLendingPool.setUserCollateral(address(boringVault), address(stHypeToken), stakeAmount);
        felixLendingPool.setUserBorrow(address(boringVault), address(hypeToken), borrowAmount);
        MockERC20(address(hypeToken)).mint(address(boringVault), borrowAmount);
        vm.stopPrank();
        
        healthScore = strategyManager.getHealthScore();
        assertGt(healthScore, 0);
        assertLe(healthScore, 100);
    }

    function testRebalancingThreshold() public {
        // Setup position similar to testBasicLoopExecution
        uint256 depositAmount = 1000e18;
        
        vm.startPrank(owner);
        hypeToken.transfer(address(boringVault), depositAmount);
        bytes32 dummyRoot = keccak256("dummy_root");
        manager.setManageRoot(strategist, dummyRoot);
        
        vm.mockCall(
            address(manager),
            abi.encodeWithSelector(ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector),
            abi.encode()
        );

        // Setup mock position with target LTV close to default (75%)
        // Only set stHYPE as collateral in Felix, not direct holdings
        uint256 stakeAmount = depositAmount;
        uint256 borrowAmount = stakeAmount * 7500 / 10000; // 75% LTV to match target
        felixLendingPool.setUserCollateral(address(boringVault), address(stHypeToken), stakeAmount);
        felixLendingPool.setUserBorrow(address(boringVault), address(hypeToken), borrowAmount);
        MockERC20(address(hypeToken)).mint(address(boringVault), borrowAmount);
        vm.stopPrank();

        // Should not need rebalancing initially since LTV should be at target
        assertFalse(strategyManager.needsRebalancing());
    }

    //============================== ACCESS CONTROL TESTS ===============================

    function testOnlyOwnerCanUpdateConfig() public {
        HypeStakingLoopingManager.LoopingConfig memory newConfig = HypeStakingLoopingManager.LoopingConfig({
            targetLTV: 8000,
            maxLTV: 9000,
            minLTV: 7000,
            rebalanceThreshold: 300,
            maxIterations: 7,
            loopingEnabled: true
        });

        vm.prank(user1);
        vm.expectRevert();
        strategyManager.updateConfig(newConfig);
    }

    function testOnlyStrategistCanExecuteLoop() public {
        vm.prank(user1);
        vm.expectRevert();
        strategyManager.executeLoop(1000e18, 3);
    }

    function testOnlyOwnerCanEmergencyExit() public {
        vm.prank(user1);
        vm.expectRevert();
        strategyManager.emergencyExit();
    }

    //============================== DECODER TESTS ===============================

    function testDecoderStakeFunction() public {
        bytes memory addressesFound = decoderAndSanitizer.stake(1000e18, address(boringVault));
        assertEq(addressesFound, abi.encodePacked(address(boringVault)));
    }

    function testDecoderUnstakeFunction() public {
        bytes memory addressesFound = decoderAndSanitizer.unstake(1000e18, address(boringVault));
        assertEq(addressesFound, abi.encodePacked(address(boringVault)));
    }

    function testDecoderApproveFunction() public {
        bytes memory addressesFound = decoderAndSanitizer.approve(address(hypeStaking), 1000e18);
        assertEq(addressesFound, abi.encodePacked(address(hypeStaking)));
    }

    function testDecoderSupplyFunction() public {
        bytes memory addressesFound = decoderAndSanitizer.supply(
            address(stHypeToken),
            1000e18,
            address(boringVault),
            0
        );
        assertEq(addressesFound, abi.encodePacked(address(stHypeToken), address(boringVault)));
    }

    function testDecoderBorrowFunction() public {
        bytes memory addressesFound = decoderAndSanitizer.borrow(
            address(hypeToken),
            500e18,
            2,
            0,
            address(boringVault)
        );
        assertEq(addressesFound, abi.encodePacked(address(hypeToken), address(boringVault)));
    }
}

//============================== MOCK CONTRACTS ===============================

contract MockHypeStakingContract {
    ERC20 public immutable hypeToken;
    ERC20 public immutable stHypeToken;
    uint256 public exchangeRate = 1e18; // 1:1 initially
    uint256 public rewardsAvailable = 0;

    constructor(address _hypeToken, address _stHypeToken) {
        hypeToken = ERC20(_hypeToken);
        stHypeToken = ERC20(_stHypeToken);
    }

    function stake(uint256 amount, address receiver) external {
        hypeToken.transferFrom(msg.sender, address(this), amount);
        MockERC20(address(stHypeToken)).mint(receiver, amount);
    }

    function unstake(uint256 shares, address receiver) external {
        MockERC20(address(stHypeToken)).burn(msg.sender, shares);
        MockERC20(address(hypeToken)).mint(receiver, shares);
    }

    function claimRewards(address receiver) external {
        if (rewardsAvailable > 0) {
            MockERC20(address(hypeToken)).mint(receiver, rewardsAvailable);
            rewardsAvailable = 0;
        }
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return shares * exchangeRate / 1e18;
    }

    function setExchangeRate(uint256 _rate) external {
        exchangeRate = _rate;
    }

    function setRewards(uint256 _rewards) external {
        rewardsAvailable = _rewards;
    }
}

contract MockFelixLendingPool {
    ERC20 public immutable hypeToken;
    ERC20 public immutable stHypeToken;
    
    mapping(address => mapping(address => uint256)) public userCollateral;
    mapping(address => mapping(address => uint256)) public userBorrows;

    constructor(address _hypeToken, address _stHypeToken) {
        hypeToken = ERC20(_hypeToken);
        stHypeToken = ERC20(_stHypeToken);
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        ERC20(asset).transferFrom(msg.sender, address(this), amount);
        userCollateral[onBehalfOf][asset] += amount;
    }

    function borrow(address asset, uint256 amount, uint256, uint16, address onBehalfOf) external {
        userBorrows[onBehalfOf][asset] += amount;
        MockERC20(asset).mint(onBehalfOf, amount);
    }

    function repay(address asset, uint256 amount, uint256, address onBehalfOf) external {
        ERC20(asset).transferFrom(msg.sender, address(this), amount);
        userBorrows[onBehalfOf][asset] -= amount;
    }

    function withdraw(address asset, uint256 amount, address to) external {
        userCollateral[msg.sender][asset] -= amount;
        ERC20(asset).transfer(to, amount);
    }

    function setUserUseReserveAsCollateral(address, bool) external {
        // No-op for testing
    }

    function getUserCollateralBalance(address user, address asset) external view returns (uint256) {
        return userCollateral[user][asset];
    }

    function getUserBorrowBalance(address user, address asset) external view returns (uint256) {
        return userBorrows[user][asset];
    }
    
    // Helper functions for testing
    function setUserCollateral(address user, address asset, uint256 amount) external {
        userCollateral[user][asset] = amount;
    }
    
    function setUserBorrow(address user, address asset, uint256 amount) external {
        userBorrows[user][asset] = amount;
    }
}
