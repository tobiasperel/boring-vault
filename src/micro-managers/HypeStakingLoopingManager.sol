// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

/**
 * @title HypeStakingLoopingManager
 * @notice A micro-manager for HYPE staking looping strategy within the BoringVault architecture
 * @dev This contract orchestrates the looping strategy by calling the BoringVault through 
 *      the ManagerWithMerkleVerification system
 */
contract HypeStakingLoopingManager is Auth, ReentrancyGuard {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    //============================== STRUCTS ===============================

    struct LoopingConfig {
        uint256 targetLTV;           // Target loan-to-value ratio (in basis points, e.g., 7500 = 75%)
        uint256 maxLTV;              // Maximum allowed LTV before liquidation risk
        uint256 minLTV;              // Minimum LTV to maintain efficiency
        uint256 rebalanceThreshold;  // Threshold for triggering rebalancing
        uint256 maxIterations;       // Maximum loops to prevent gas issues
        bool loopingEnabled;         // Enable/disable looping functionality
    }

    struct PositionInfo {
        uint256 stakedAmount;        // Total amount of HYPE staked
        uint256 borrowedAmount;      // Total amount of HYPE borrowed
        uint256 collateralValue;     // Current collateral value
        uint256 currentLTV;          // Current loan-to-value ratio
        uint256 totalValue;          // Total position value
        uint256 netValue;            // Net position value (collateral - debt)
    }

    //============================== EVENTS ===============================

    event LoopExecuted(uint256 iterations, uint256 finalStakedAmount, uint256 finalBorrowedAmount);
    event Rebalanced(uint256 oldLTV, uint256 newLTV, bool increased);
    event ConfigUpdated(LoopingConfig oldConfig, LoopingConfig newConfig);
    event EmergencyExit(uint256 stakedWithdrawn, uint256 debtRepaid);
    event YieldHarvested(uint256 stakingRewards, uint256 netYield);

    //============================== ERRORS ===============================

    error HypeStakingLoopingManager__InvalidConfig();
    error HypeStakingLoopingManager__LTVTooHigh();
    error HypeStakingLoopingManager__LoopingDisabled();
    error HypeStakingLoopingManager__InsufficientCollateral();
    error HypeStakingLoopingManager__SlippageTooHigh();
    error HypeStakingLoopingManager__MaxIterationsReached();
    error HypeStakingLoopingManager__ExchangeRateUnavailable();

    //============================== IMMUTABLES ===============================

    /**
     * @notice The BoringVault that holds the assets
     */
    BoringVault public immutable boringVault;

    /**
     * @notice The manager with merkle verification for secure operations
     */
    ManagerWithMerkleVerification public immutable manager;

    /**
     * @notice The HYPE token being staked and borrowed
     */
    ERC20 public immutable hypeToken;

    /**
     * @notice The staked HYPE token (stHYPE) received from staking
     */
    ERC20 public immutable stHypeToken;

    /**
     * @notice The staking contract for HYPE tokens
     */
    address public immutable stakingContract;

    /**
     * @notice The lending protocol for borrowing HYPE (Felix)
     */
    address public immutable felixLendingPool;

    /**
     * @notice The decoder and sanitizer for this strategy
     */
    address public immutable decoderAndSanitizer;

    /**
     * @notice Maximum basis points (100%)
     */
    uint256 public constant MAX_BPS = 10000;

    /**
     * @notice Precision for calculations
     */
    uint256 public constant PRECISION = 1e18;

    //============================== STATE VARIABLES ===============================

    /**
     * @notice Current looping configuration
     */
    LoopingConfig public config;

    /**
     * @notice Last harvest timestamp
     */
    uint256 public lastHarvest;

    /**
     * @notice Performance fee percentage (in basis points)
     */
    uint256 public performanceFee = 1000; // 10%

    //============================== CONSTRUCTOR ===============================

    constructor(
        address _owner,
        address _authority,
        address _boringVault,
        address _manager,
        address _hypeToken,
        address _stHypeToken,
        address _stakingContract,
        address _felixLendingPool,
        address _decoderAndSanitizer
    ) Auth(_owner, Authority(_authority)) {
        boringVault = BoringVault(payable(_boringVault));
        manager = ManagerWithMerkleVerification(_manager);
        hypeToken = ERC20(_hypeToken);
        stHypeToken = ERC20(_stHypeToken);
        stakingContract = _stakingContract;
        felixLendingPool = _felixLendingPool;
        decoderAndSanitizer = _decoderAndSanitizer;

        // Set default configuration
        config = LoopingConfig({
            targetLTV: 7500,        // 75%
            maxLTV: 8500,           // 85%
            minLTV: 6500,           // 65%
            rebalanceThreshold: 500, // 5%
            maxIterations: 5,
            loopingEnabled: true
        });

        lastHarvest = block.timestamp;
    }

    //============================== ADMIN FUNCTIONS ===============================

    /**
     * @notice Update looping configuration
     * @param newConfig New configuration parameters
     */
    function updateConfig(LoopingConfig calldata newConfig) external requiresAuth {
        if (newConfig.targetLTV >= newConfig.maxLTV || 
            newConfig.minLTV >= newConfig.targetLTV ||
            newConfig.maxLTV > 9500 || // 95% max for safety
            newConfig.maxIterations == 0) {
            revert HypeStakingLoopingManager__InvalidConfig();
        }

        LoopingConfig memory oldConfig = config;
        config = newConfig;
        
        emit ConfigUpdated(oldConfig, newConfig);
    }

    /**
     * @notice Update performance fee
     * @param newFee New performance fee in basis points
     */
    function updatePerformanceFee(uint256 newFee) external requiresAuth {
        require(newFee <= 2000, "Fee too high"); // Max 20%
        performanceFee = newFee;
    }

    /**
     * @notice Emergency exit - unwind all positions
     */
    function emergencyExit() external requiresAuth {
        _unwindPosition();
        emit EmergencyExit(0, 0);
    }

    //============================== CORE STRATEGY FUNCTIONS ===============================

    /**
     * @notice Execute the looping strategy
     * @param initialAmount Initial HYPE amount available in the vault to loop
     * @param maxIterations Maximum number of loop iterations
     */
    function executeLoop(uint256 initialAmount, uint256 maxIterations) external requiresAuth nonReentrant {
        if (!config.loopingEnabled) revert HypeStakingLoopingManager__LoopingDisabled();
        require(initialAmount > 0, "Amount must be greater than 0");
        
        uint256 iterations = _executeLoopInternal(initialAmount, maxIterations);
        
        PositionInfo memory finalPosition = getPositionInfo();
        emit LoopExecuted(iterations, finalPosition.stakedAmount, finalPosition.borrowedAmount);
    }

    /**
     * @notice Harvest staking rewards and compound them
     */
    function harvestAndCompound() external requiresAuth nonReentrant {
        uint256 timeSinceHarvest = block.timestamp - lastHarvest;
        require(timeSinceHarvest >= 1 hours, "Too frequent harvest");
        
        // Harvest staking rewards
        uint256 rewards = _harvestStakingRewards();
        
        if (rewards > 0) {
            // Take performance fee
            uint256 fee = rewards.mulDivDown(performanceFee, MAX_BPS);
            uint256 netRewards = rewards - fee;
            
            // Compound rewards back into the loop
            if (netRewards > 0 && config.loopingEnabled) {
                _executeLoopInternal(netRewards, config.maxIterations);
            }
            
            emit YieldHarvested(rewards, netRewards);
        }
        
        lastHarvest = block.timestamp;
    }

    /**
     * @notice Rebalance position if LTV is outside target range
     */
    function rebalance() external requiresAuth nonReentrant {
        PositionInfo memory position = getPositionInfo();
        
        uint256 targetLTV = config.targetLTV;
        uint256 threshold = config.rebalanceThreshold;
        
        // Check if rebalancing is needed
        bool needsRebalance = position.currentLTV > targetLTV + threshold || 
                             position.currentLTV < targetLTV - threshold;
        
        if (!needsRebalance) return;
        
        bool isIncrease = position.currentLTV < targetLTV;
        uint256 oldLTV = position.currentLTV;
        
        if (isIncrease) {
            _increaseLeverage(position, targetLTV);
        } else {
            _decreaseLeverage(position, targetLTV);
        }
        
        emit Rebalanced(oldLTV, targetLTV, isIncrease);
    }

    /**
     * @notice Unwind part of the position
     * @param targetUnwindAmount Target amount to unwind (in HYPE terms)
     */
    function partialUnwind(uint256 targetUnwindAmount) external requiresAuth nonReentrant {
        _partialUnwind(targetUnwindAmount);
    }

    //============================== INTERNAL FUNCTIONS ===============================

    /**
     * @notice Execute the looping strategy internal implementation
     * @param initialAmount Initial HYPE amount to loop
     * @param maxIterations Maximum number of iterations
     * @return iterations Number of iterations executed
     */
    function _executeLoopInternal(uint256 initialAmount, uint256 maxIterations) internal returns (uint256 iterations) {
        uint256 currentAmount = initialAmount;
        
        while (iterations < maxIterations && currentAmount > 0) {
            // Stake HYPE to get stHYPE
            uint256 stakedAmount = _stakeHype(currentAmount);
            
            // Use stHYPE as collateral and borrow more HYPE
            uint256 borrowedAmount = _borrowAgainstCollateral(stakedAmount);
            
            // If borrowed amount is too small, exit loop
            if (borrowedAmount < initialAmount / 100) break; // Less than 1% of initial
            
            currentAmount = borrowedAmount;
            iterations++;
        }
        
        // Only revert if we couldn't do any iterations and amount is significant
        if (iterations >= maxIterations && currentAmount > initialAmount / 50) {
            revert HypeStakingLoopingManager__MaxIterationsReached();
        }
    }

    /**
     * @notice Stake HYPE tokens through the BoringVault
     * @param amount Amount to stake
     * @return Amount of stHYPE received
     */
    function _stakeHype(uint256 amount) internal returns (uint256) {
        if (amount == 0) return 0;
        
        // Prepare merkle proof parameters for staking operation
        bytes32[][] memory manageProofs = new bytes32[][](2);
        address[] memory decodersAndSanitizers = new address[](2);
        address[] memory targets = new address[](2);
        bytes[] memory targetData = new bytes[](2);
        uint256[] memory values = new uint256[](2);
        
        // First: Approve staking contract to spend HYPE
        decodersAndSanitizers[0] = decoderAndSanitizer;
        targets[0] = address(hypeToken);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", stakingContract, amount);
        values[0] = 0;
        
        // Second: Stake HYPE
        decodersAndSanitizers[1] = decoderAndSanitizer;
        targets[1] = stakingContract;
        targetData[1] = abi.encodeWithSignature("stake(uint256,address)", amount, address(boringVault));
        values[1] = 0;
        
        // Get the vault's stHYPE balance before
        uint256 stHypeBefore = stHypeToken.balanceOf(address(boringVault));
        
        // Execute through manager
        manager.manageVaultWithMerkleVerification(
            manageProofs,
            decodersAndSanitizers,
            targets,
            targetData,
            values
        );
        
        uint256 stHypeAfter = stHypeToken.balanceOf(address(boringVault));
        return stHypeAfter - stHypeBefore;
    }

    /**
     * @notice Borrow HYPE against stHYPE collateral through the BoringVault
     * @param collateralAmount Amount of stHYPE to use as collateral
     * @return Amount of HYPE borrowed
     */
    function _borrowAgainstCollateral(uint256 collateralAmount) internal returns (uint256) {
        if (collateralAmount == 0) return 0;
        
        // Calculate safe borrow amount based on target LTV
        uint256 collateralValue = _getCollateralValue(collateralAmount);
        uint256 maxBorrowAmount = collateralValue.mulDivDown(config.targetLTV, MAX_BPS);
        
        // Prepare merkle proof parameters for borrowing operation
        bytes32[][] memory manageProofs = new bytes32[][](3);
        address[] memory decodersAndSanitizers = new address[](3);
        address[] memory targets = new address[](3);
        bytes[] memory targetData = new bytes[](3);
        uint256[] memory values = new uint256[](3);
        
        // First: Approve Felix to spend stHYPE
        decodersAndSanitizers[0] = decoderAndSanitizer;
        targets[0] = address(stHypeToken);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", felixLendingPool, collateralAmount);
        values[0] = 0;
        
        // Second: Supply stHYPE as collateral
        decodersAndSanitizers[1] = decoderAndSanitizer;
        targets[1] = felixLendingPool;
        targetData[1] = abi.encodeWithSignature(
            "supply(address,uint256,address,uint16)",
            address(stHypeToken),
            collateralAmount,
            address(boringVault),
            0 // referral code
        );
        values[1] = 0;
        
        // Third: Borrow HYPE
        decodersAndSanitizers[2] = decoderAndSanitizer;
        targets[2] = felixLendingPool;
        targetData[2] = abi.encodeWithSignature(
            "borrow(address,uint256,uint256,uint16,address)",
            address(hypeToken),
            maxBorrowAmount,
            2, // variable rate
            0, // referral code
            address(boringVault)
        );
        values[2] = 0;
        
        uint256 hypeBefore = hypeToken.balanceOf(address(boringVault));
        
        // Execute through manager
        manager.manageVaultWithMerkleVerification(
            manageProofs,
            decodersAndSanitizers,
            targets,
            targetData,
            values
        );
        
        uint256 hypeAfter = hypeToken.balanceOf(address(boringVault));
        return hypeAfter - hypeBefore;
    }

    /**
     * @notice Harvest staking rewards through the BoringVault
     * @return Amount of rewards harvested
     */
    function _harvestStakingRewards() internal returns (uint256) {
        // Prepare merkle proof parameters for claiming rewards
        bytes32[][] memory manageProofs = new bytes32[][](1);
        address[] memory decodersAndSanitizers = new address[](1);
        address[] memory targets = new address[](1);
        bytes[] memory targetData = new bytes[](1);
        uint256[] memory values = new uint256[](1);
        
        decodersAndSanitizers[0] = decoderAndSanitizer;
        targets[0] = stakingContract;
        targetData[0] = abi.encodeWithSignature("claimRewards(address)", address(boringVault));
        values[0] = 0;
        
        uint256 rewardsBefore = hypeToken.balanceOf(address(boringVault));
        
        // Execute through manager
        manager.manageVaultWithMerkleVerification(
            manageProofs,
            decodersAndSanitizers,
            targets,
            targetData,
            values
        );
        
        uint256 rewardsAfter = hypeToken.balanceOf(address(boringVault));
        return rewardsAfter - rewardsBefore;
    }

    /**
     * @notice Unwind entire position
     */
    function _unwindPosition() internal {
        PositionInfo memory position = getPositionInfo();
        
        if (position.borrowedAmount > 0) {
            // Repay all debt first
            _repayDebt(position.borrowedAmount);
        }
        
        if (position.stakedAmount > 0) {
            // Withdraw collateral and unstake
            _withdrawAndUnstake(position.stakedAmount);
        }
    }

    /**
     * @notice Partially unwind position
     * @param targetUnwind Target amount to unwind
     */
    function _partialUnwind(uint256 targetUnwind) internal {
        PositionInfo memory position = getPositionInfo();
        
        if (targetUnwind >= position.netValue) {
            _unwindPosition();
            return;
        }
        
        uint256 unwindRatio = targetUnwind.mulDivDown(PRECISION, position.netValue);
        uint256 debtToRepay = position.borrowedAmount.mulDivDown(unwindRatio, PRECISION);
        uint256 collateralToWithdraw = position.stakedAmount.mulDivDown(unwindRatio, PRECISION);
        
        // Repay proportional debt
        if (debtToRepay > 0) {
            _repayDebt(debtToRepay);
        }
        
        // Withdraw and unstake proportional collateral
        if (collateralToWithdraw > 0) {
            _withdrawAndUnstake(collateralToWithdraw);
        }
    }

    /**
     * @notice Repay debt to Felix
     * @param amount Amount to repay
     */
    function _repayDebt(uint256 amount) internal {
        if (amount == 0) return;
        
        bytes32[][] memory manageProofs = new bytes32[][](2);
        address[] memory decodersAndSanitizers = new address[](2);
        address[] memory targets = new address[](2);
        bytes[] memory targetData = new bytes[](2);
        uint256[] memory values = new uint256[](2);
        
        // Approve Felix to spend HYPE for repayment
        decodersAndSanitizers[0] = decoderAndSanitizer;
        targets[0] = address(hypeToken);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", felixLendingPool, amount);
        values[0] = 0;
        
        // Repay debt
        decodersAndSanitizers[1] = decoderAndSanitizer;
        targets[1] = felixLendingPool;
        targetData[1] = abi.encodeWithSignature(
            "repay(address,uint256,uint256,address)",
            address(hypeToken),
            amount,
            2, // variable rate
            address(boringVault)
        );
        values[1] = 0;
        
        manager.manageVaultWithMerkleVerification(
            manageProofs,
            decodersAndSanitizers,
            targets,
            targetData,
            values
        );
    }

    /**
     * @notice Withdraw collateral from Felix and unstake
     * @param amount Amount to withdraw and unstake
     */
    function _withdrawAndUnstake(uint256 amount) internal {
        if (amount == 0) return;
        
        bytes32[][] memory manageProofs = new bytes32[][](2);
        address[] memory decodersAndSanitizers = new address[](2);
        address[] memory targets = new address[](2);
        bytes[] memory targetData = new bytes[](2);
        uint256[] memory values = new uint256[](2);
        
        // Withdraw stHYPE from Felix
        decodersAndSanitizers[0] = decoderAndSanitizer;
        targets[0] = felixLendingPool;
        targetData[0] = abi.encodeWithSignature(
            "withdraw(address,uint256,address)",
            address(stHypeToken),
            amount,
            address(boringVault)
        );
        values[0] = 0;
        
        // Unstake stHYPE to get HYPE
        decodersAndSanitizers[1] = decoderAndSanitizer;
        targets[1] = stakingContract;
        targetData[1] = abi.encodeWithSignature("unstake(uint256,address)", amount, address(boringVault));
        values[1] = 0;
        
        manager.manageVaultWithMerkleVerification(
            manageProofs,
            decodersAndSanitizers,
            targets,
            targetData,
            values
        );
    }

    /**
     * @notice Increase leverage to target LTV
     */
    function _increaseLeverage(PositionInfo memory position, uint256 targetLTV) internal {
        uint256 targetDebt = position.collateralValue.mulDivDown(targetLTV, MAX_BPS);
        uint256 additionalDebt = targetDebt - position.borrowedAmount;
        
        if (additionalDebt > 0) {
            // Borrow more and stake it
            _executeLoopInternal(additionalDebt, 1);
        }
    }

    /**
     * @notice Decrease leverage to target LTV
     */
    function _decreaseLeverage(PositionInfo memory position, uint256 targetLTV) internal {
        uint256 targetDebt = position.collateralValue.mulDivDown(targetLTV, MAX_BPS);
        uint256 excessDebt = position.borrowedAmount - targetDebt;
        
        if (excessDebt > 0) {
            _partialUnwind(excessDebt);
        }
    }

    //============================== VIEW FUNCTIONS ===============================

    /**
     * @notice Get current position information
     * @return position Current position details
     */
    function getPositionInfo() public view returns (PositionInfo memory position) {
        // Get stHYPE balance in vault (direct holdings)
        uint256 directStHype = stHypeToken.balanceOf(address(boringVault));
        
        // Get stHYPE supplied as collateral to Felix
        uint256 collateralStHype = _getCollateralInFelixLendingPool();
        
        // Total staked amount
        position.stakedAmount = directStHype + collateralStHype;
        
        // Calculate total collateral value
        position.collateralValue = _getCollateralValue(position.stakedAmount);
        
        // Get borrowed amount
        position.borrowedAmount = _getBorrowedAmount();
        
        if (position.collateralValue > 0) {
            position.currentLTV = position.borrowedAmount.mulDivDown(MAX_BPS, position.collateralValue);
        }
        
        position.totalValue = position.collateralValue;
        position.netValue = position.collateralValue > position.borrowedAmount 
            ? position.collateralValue - position.borrowedAmount 
            : 0;
    }

    /**
     * @notice Get collateral value in HYPE terms
     * @param stHypeAmount Amount of stHYPE
     * @return value Value in HYPE
     */
    function _getCollateralValue(uint256 stHypeAmount) internal view returns (uint256 value) {
        if (stHypeAmount == 0) return 0;
        
        // Get the exchange rate from stHYPE to HYPE
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("convertToAssets(uint256)", stHypeAmount)
        );
        
        if (success && data.length >= 32) {
            value = abi.decode(data, (uint256));
        } else {
            // Fallback: assume 1:1 ratio if conversion fails
            value = stHypeAmount;
        }
    }

    /**
     * @notice Get current borrowed amount from Felix
     * @return borrowed Current debt amount
     */
    function _getBorrowedAmount() internal view returns (uint256 borrowed) {
        (bool success, bytes memory data) = felixLendingPool.staticcall(
            abi.encodeWithSignature("getUserBorrowBalance(address,address)", address(boringVault), address(hypeToken))
        );
        
        if (success && data.length >= 32) {
            borrowed = abi.decode(data, (uint256));
        }
    }

    /**
     * @notice Get amount of stHYPE supplied as collateral to Felix
     * @return collateralAmount Amount of stHYPE in Felix lending pool
     */
    function _getCollateralInFelixLendingPool() internal view returns (uint256 collateralAmount) {
        (bool success, bytes memory data) = felixLendingPool.staticcall(
            abi.encodeWithSignature("getUserCollateralBalance(address,address)", address(boringVault), address(stHypeToken))
        );
        
        if (success && data.length >= 32) {
            collateralAmount = abi.decode(data, (uint256));
        }
    }

    /**
     * @notice Get strategy health score (0-100)
     * @return health Health score
     */
    function getHealthScore() external view returns (uint256 health) {
        PositionInfo memory position = getPositionInfo();
        
        if (position.collateralValue == 0) return 100;
        
        // Health decreases as LTV approaches maxLTV
        if (position.currentLTV >= config.maxLTV) return 0;
        
        uint256 cushion = config.maxLTV - position.currentLTV;
        health = cushion.mulDivDown(100, config.maxLTV);
    }

    /**
     * @notice Check if rebalancing is needed
     * @return needed True if rebalancing is needed
     */
    function needsRebalancing() external view returns (bool needed) {
        PositionInfo memory position = getPositionInfo();
        uint256 targetLTV = config.targetLTV;
        uint256 threshold = config.rebalanceThreshold;
        
        needed = position.currentLTV > targetLTV + threshold || 
                position.currentLTV < targetLTV - threshold;
    }
}
