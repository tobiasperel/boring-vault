// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";


contract VedaLoopingStrategy is Auth, ReentrancyGuard {
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
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 shares, uint256 amount);
    
    //============================== ERRORS ===============================

    error VedaLoopingStrategy__InvalidConfig();
    error VedaLoopingStrategy__LTVTooHigh();
    error VedaLoopingStrategy__LoopingDisabled();
    error VedaLoopingStrategy__InsufficientCollateral();
    error VedaLoopingStrategy__SlippageTooHigh();
    error VedaLoopingStrategy__MaxIterationsReached();
    error VedaLoopingStrategy__ExchangeRateUnavailable();

    //============================== IMMUTABLES ===============================

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
     * @notice The lending protocol for borrowing HYPE
     */
    address public immutable lendingPool;

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
     * @notice Accumulated performance fees
     */
    uint256 public accumulatedFees;

    /**
     * @notice Performance fee percentage (in basis points)
     */
    uint256 public performanceFee = 1000; // 10%

    /**
     * @notice User shares mapping - each user's shares represent their original deposit amount
     */
    mapping(address => uint256) public userShares;

    /**
     * @notice User deposit timestamp mapping - tracks when each user deposited
     */
    mapping(address => uint256) public userDepositTime;

    //============================== CONSTRUCTOR ===============================

    constructor(
        address _owner,
        address _authority,
        address _hypeToken,
        address _stHypeToken,
        address _stakingContract,
        address _lendingPool
    ) Auth(_owner, Authority(_authority)) {
        hypeToken = ERC20(_hypeToken);
        stHypeToken = ERC20(_stHypeToken);
        stakingContract = _stakingContract;
        lendingPool = _lendingPool;

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
            revert VedaLoopingStrategy__InvalidConfig();
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
        
        uint256 hypeBalance = hypeToken.balanceOf(address(this));
        emit EmergencyExit(0, hypeBalance);
    }

    //============================== CORE STRATEGY FUNCTIONS ===============================

    /**
     * @notice Deposit HYPE and execute looping strategy
     * @param amount Amount of HYPE to deposit
     * @param minStakedOut Minimum stHYPE expected from looping
     */
    function deposit(uint256 amount, uint256 minStakedOut) external nonReentrant returns (uint256 shares) {
        if (!config.loopingEnabled) revert VedaLoopingStrategy__LoopingDisabled();
        require(amount > 0, "Amount must be greater than 0");
        
        hypeToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Calculate shares before executing loop (1:1 with deposited amount)
        shares = amount;
        
        uint256 stakedBefore = stHypeToken.balanceOf(address(this));
        _executeLoop(amount);
        uint256 stakedAfter = stHypeToken.balanceOf(address(this));
        
        uint256 stakedReceived = stakedAfter - stakedBefore;
        if (stakedReceived < minStakedOut) revert VedaLoopingStrategy__SlippageTooHigh();
        
        // Update user shares and deposit time
        userShares[msg.sender] += shares;
        userDepositTime[msg.sender] = block.timestamp;
        
        emit Deposit(msg.sender, amount, shares);
    }

    /**
     * @notice Withdraw HYPE by unwinding positions
     * @param shares Amount of shares to withdraw
     * @param minAmountOut Minimum HYPE expected (for slippage protection)
     */
    function withdraw(uint256 shares, uint256 minAmountOut) external nonReentrant returns (uint256) {
        require(shares > 0, "Shares must be greater than 0");
        
        // CRITICAL: Check user has enough shares BEFORE any operations to prevent underflow
        uint256 userCurrentShares = userShares[msg.sender];
        require(userCurrentShares >= shares, "Insufficient user shares");
        require(userCurrentShares > 0, "User has no shares");
        
        // In our simple system: shares = HYPE amount (1:1)
        uint256 hypeAmount = shares;
        
        // CRITICAL: Verify user has actual funds - check if user's HYPE amount is available
        // Each user's shares represent their claim on the underlying HYPE
        PositionInfo memory position = getPositionInfo();
        require(position.netValue > 0, "Strategy has no net value");
        require(hypeAmount <= position.netValue, "Insufficient strategy liquidity");
        
        // Additional check: verify this specific user can withdraw their amount
        // This prevents users from withdrawing more than their fair share
        uint256 userHypeBalance = _calculateUserActualBalance(msg.sender);
        require(hypeAmount <= userHypeBalance, "User cannot withdraw more than their balance");
        
        uint256 hypeBefore = hypeToken.balanceOf(address(this));
        
        // Partially unwind the position to get the requested HYPE amount
        _partialUnwind(hypeAmount);
        
        uint256 hypeAfter = hypeToken.balanceOf(address(this));
        
        // Safe calculation to prevent underflow
        uint256 hypeWithdrawn = hypeAfter > hypeBefore ? hypeAfter - hypeBefore : 0;
        if (hypeWithdrawn < minAmountOut) revert VedaLoopingStrategy__SlippageTooHigh();
        
        // Update user shares ONLY after successful withdrawal (process inverse of deposit)
        userShares[msg.sender] = userCurrentShares - shares;
        
        if (hypeWithdrawn > 0) {
            hypeToken.safeTransfer(msg.sender, hypeWithdrawn);
        }
        
        emit Withdraw(msg.sender, shares, hypeWithdrawn);
        return hypeWithdrawn;
    }

    /**
     * @notice Harvest staking rewards and compound them
     */
    function harvestAndCompound() external nonReentrant {
        uint256 timeSinceHarvest = block.timestamp - lastHarvest;
        require(timeSinceHarvest >= 1 hours, "Too frequent harvest");
        
        // Harvest staking rewards (implementation depends on staking contract)
        uint256 rewards = _harvestStakingRewards();
        
        if (rewards > 0) {
            // Take performance fee
            uint256 fee = rewards.mulDivDown(performanceFee, MAX_BPS);
            accumulatedFees += fee;
            
            uint256 netRewards = rewards - fee;
            
            // Compound rewards back into the loop
            if (netRewards > 0 && config.loopingEnabled) {
                _executeLoop(netRewards);
            }
            
            emit YieldHarvested(rewards, netRewards);
        }
        
        lastHarvest = block.timestamp;
    }

    /**
     * @notice Rebalance position if LTV is outside target range
     */
    function rebalance() external nonReentrant {
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

    //============================== SHARE CALCULATION FUNCTIONS ===============================

    /**
     * @notice Calculate user's current balance (simple 1:1 with shares)
     * @param user User address
     * @return Current balance (same as shares)
     */
    function _calculateUserBalance(address user) internal view returns (uint256) {
        // Simple: user's balance = their shares (1:1 with original deposit)
        return userShares[user];
    }

    /**
     * @notice Calculate user's actual withdrawable balance based on strategy performance
     * @param user User address
     * @return Actual HYPE amount the user can withdraw
     */
    function _calculateUserActualBalance(address user) internal view returns (uint256) {
        uint256 userShares_ = userShares[user];
        if (userShares_ == 0) return 0;
        
        // In our simple 1:1 system, user can withdraw their exact share amount
        // This represents their original deposit in HYPE terms
        return userShares_;
    }

    //============================== INTERNAL FUNCTIONS ===============================

    /**
     * @notice Execute the looping strategy
     * @param initialAmount Initial HYPE amount to loop
     */
    function _executeLoop(uint256 initialAmount) internal {
        uint256 currentAmount = initialAmount;
        uint256 iterations = 0;
        
        while (iterations < config.maxIterations && currentAmount > 0) {
            // Stake HYPE to get stHYPE
            uint256 stakedAmount = _stakeHype(currentAmount);
            
            // Use stHYPE as collateral and borrow more HYPE
            uint256 borrowedAmount = _borrowAgainstCollateral(stakedAmount);
            
            // If borrowed amount is too small, exit loop
            if (borrowedAmount < initialAmount / 100) break; // Less than 1% of initial
            
            // Additional safety: break if borrowed amount is less than 10% of current amount
            if (borrowedAmount < currentAmount / 10) break;
            
            currentAmount = borrowedAmount;
            iterations++;
        }
        
        // Only revert if we couldn't do any iterations, not if we reached max
        if (iterations >= config.maxIterations && currentAmount > initialAmount / 50) {
            revert VedaLoopingStrategy__MaxIterationsReached();
        }
        
        PositionInfo memory finalPosition = getPositionInfo();
        emit LoopExecuted(iterations, finalPosition.stakedAmount, finalPosition.borrowedAmount);
    }

    /**
     * @notice Stake HYPE tokens
     * @param amount Amount to stake
     * @return Amount of stHYPE received
     */
    function _stakeHype(uint256 amount) internal returns (uint256) {
        if (amount == 0) return 0;
        
        hypeToken.safeApprove(stakingContract, amount);
        
        uint256 stHypeBefore = stHypeToken.balanceOf(address(this));
        
        // Call staking contract (implementation depends on specific staking contract)
        (bool success,) = stakingContract.call(
            abi.encodeWithSignature("stake(uint256)", amount)
        );
        require(success, "Staking failed");
        
        uint256 stHypeAfter = stHypeToken.balanceOf(address(this));
        return stHypeAfter - stHypeBefore;
    }

    /**
     * @notice Borrow HYPE against stHYPE collateral
     * @param collateralAmount Amount of stHYPE to use as collateral
     * @return Amount of HYPE borrowed
     */
    function _borrowAgainstCollateral(uint256 collateralAmount) internal returns (uint256) {
        if (collateralAmount == 0) return 0;
        
        stHypeToken.safeApprove(lendingPool, collateralAmount);
        
        // Calculate safe borrow amount based on target LTV
        uint256 collateralValue = _getCollateralValue(collateralAmount);
        uint256 maxBorrowAmount = collateralValue.mulDivDown(config.targetLTV, MAX_BPS);
        
        uint256 hypeBefore = hypeToken.balanceOf(address(this));
        
        // Call lending pool (implementation depends on specific lending protocol)
        (bool success,) = lendingPool.call(
            abi.encodeWithSignature(
                "depositAndBorrow(address,uint256,address,uint256)",
                address(stHypeToken),
                collateralAmount,
                address(hypeToken),
                maxBorrowAmount
            )
        );
        require(success, "Borrowing failed");
        
        uint256 hypeAfter = hypeToken.balanceOf(address(this));
        return hypeAfter - hypeBefore;
    }

    /**
     * @notice Unwind entire position
     */
    function _unwindPosition() internal {
        PositionInfo memory position = getPositionInfo();
        
        if (position.borrowedAmount > 0) {
            // Repay all debt
            _repayDebt(position.borrowedAmount);
        }
        
        if (position.stakedAmount > 0) {
            // Unstake all stHYPE
            _unstakeAll();
        }
    }

    /**
     * @notice Partially unwind position
     * @param targetWithdraw Target amount to withdraw
     */
    function _partialUnwind(uint256 targetWithdraw) internal {
        PositionInfo memory position = getPositionInfo();
        
        if (targetWithdraw >= position.netValue) {
            _unwindPosition();
            return;
        }
        
        uint256 withdrawRatio = targetWithdraw.mulDivDown(PRECISION, position.netValue);
        uint256 debtToRepay = position.borrowedAmount.mulDivDown(withdrawRatio, PRECISION);
        
        // Calculate how much collateral to withdraw from lending pool (not from staking!)
        uint256 collateralInLendingPool = _getCollateralInLendingPool();
        uint256 collateralToWithdraw = collateralInLendingPool.mulDivDown(withdrawRatio, PRECISION);
        
        // First repay the proportional debt
        if (debtToRepay > 0) {
            _repayDebt(debtToRepay);
        }
        
        // Then withdraw the collateral from lending pool
        if (collateralToWithdraw > 0) {
            _withdrawCollateral(collateralToWithdraw);
        }
        
        // Finally, unstake the withdrawn collateral to get HYPE tokens
        if (collateralToWithdraw > 0) {
            _unstake(collateralToWithdraw);
        }
    }

    /**
     * @notice Increase leverage to target LTV
     */
    function _increaseLeverage(PositionInfo memory position, uint256 targetLTV) internal {
        uint256 targetDebt = position.collateralValue.mulDivDown(targetLTV, MAX_BPS);
        uint256 additionalDebt = targetDebt - position.borrowedAmount;
        
        if (additionalDebt > 0) {
            _borrowMore(additionalDebt);
            _stakeHype(additionalDebt);
        }
    }

    /**
     * @notice Decrease leverage to target LTV
     */
    function _decreaseLeverage(PositionInfo memory position, uint256 targetLTV) internal {
        uint256 targetDebt = position.collateralValue.mulDivDown(targetLTV, MAX_BPS);
        uint256 excessDebt = position.borrowedAmount - targetDebt;
        
        if (excessDebt > 0) {
            uint256 collateralToUnstake = _calculateCollateralForDebt(excessDebt);
            _unstake(collateralToUnstake);
            _repayDebt(excessDebt);
        }
    }

    /**
     * @notice Harvest staking rewards
     * @return Amount of rewards harvested
     */
    function _harvestStakingRewards() internal returns (uint256) {
        uint256 rewardsBefore = hypeToken.balanceOf(address(this));
        
        // Call harvest function (implementation depends on staking contract)
        (bool success,) = stakingContract.call(
            abi.encodeWithSignature("claimRewards()")
        );
        
        if (success) {
            uint256 rewardsAfter = hypeToken.balanceOf(address(this));
            return rewardsAfter - rewardsBefore;
        }
        
        return 0;
    }

    /**
     * @notice Repay debt to lending pool
     * @param amount Amount to repay
     */
    function _repayDebt(uint256 amount) internal {
        if (amount == 0) return;
        
        hypeToken.safeApprove(lendingPool, amount);
        
        (bool success,) = lendingPool.call(
            abi.encodeWithSignature("repay(address,uint256)", address(hypeToken), amount)
        );
        require(success, "Repayment failed");
    }

    /**
     * @notice Unstake specific amount
     * @param amount Amount to unstake
     */
    function _unstake(uint256 amount) internal {
        if (amount == 0) return;
        
        (bool success,) = stakingContract.call(
            abi.encodeWithSignature("unstake(uint256)", amount)
        );
        require(success, "Unstaking failed");
    }

    /**
     * @notice Unstake all stHYPE
     */
    function _unstakeAll() internal {
        uint256 stakedBalance = stHypeToken.balanceOf(address(this));
        if (stakedBalance > 0) {
            _unstake(stakedBalance);
        }
    }

    /**
     * @notice Borrow additional HYPE
     * @param amount Amount to borrow
     */
    function _borrowMore(uint256 amount) internal {
        if (amount == 0) return;
        
        (bool success,) = lendingPool.call(
            abi.encodeWithSignature("borrow(address,uint256)", address(hypeToken), amount)
        );
        require(success, "Additional borrowing failed");
    }

    /**
     * @notice Withdraw collateral from lending pool
     * @param amount Amount to withdraw
     */
    function _withdrawCollateral(uint256 amount) internal {
        if (amount == 0) return;
        
        (bool success,) = lendingPool.call(
            abi.encodeWithSignature("withdraw(address,uint256)", address(stHypeToken), amount)
        );
        require(success, "Collateral withdrawal failed");
    }

    //============================== USER VIEW FUNCTIONS ===============================

    /**
     * @notice Get user's balance in HYPE tokens
     * @param user User address
     * @return balance Amount of HYPE tokens the user owns
     */
    function balanceOf(address user) external view returns (uint256 balance) {
        return userShares[user]; // 1:1 with original deposit
    }

    /**
     * @notice Get user's share balance
     * @param user User address
     * @return shares Number of shares the user owns
     */
    function sharesOf(address user) external view returns (uint256 shares) {
        return userShares[user];
    }

    //============================== VIEW FUNCTIONS ===============================

    /**
     * @notice Get current position information
     * @return position Current position details
     */
    function getPositionInfo() public view returns (PositionInfo memory position) {
        // Get stHYPE that we hold directly
        uint256 directStHype = stHypeToken.balanceOf(address(this));
        
        // Get stHYPE that we have as collateral in lending pool
        uint256 collateralStHype = _getCollateralInLendingPool();
        
        // Total staked amount includes both direct and collateral
        position.stakedAmount = directStHype + collateralStHype;
        
        // Calculate total collateral value (all our stHYPE)
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
        
        // Get asset value using ERC4626 convertToAssets function
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("convertToAssets(uint256)", stHypeAmount)
        );
        
        if (success && data.length >= 32) {
            value = abi.decode(data, (uint256));
        } else {
            revert VedaLoopingStrategy__ExchangeRateUnavailable();
        }
    }

    /**
     * @notice Get current borrowed amount
     * @return borrowed Current debt amount
     */
    function _getBorrowedAmount() internal view returns (uint256 borrowed) {
        (bool success, bytes memory data) = lendingPool.staticcall(
            abi.encodeWithSignature("getBorrowBalance(address,address)", address(this), address(hypeToken))
        );
        
        if (success && data.length >= 32) {
            borrowed = abi.decode(data, (uint256));
        }
    }

    /**
     * @notice Get amount of stHYPE we have as collateral in the lending pool
     * @return collateralAmount Amount of stHYPE in lending pool as collateral
     */
    function _getCollateralInLendingPool() internal view returns (uint256 collateralAmount) {
        // Try to get our collateral balance from the lending pool
        (bool success, bytes memory data) = lendingPool.staticcall(
            abi.encodeWithSignature("getCollateralBalance(address,address)", address(this), address(stHypeToken))
        );
        
        if (success && data.length >= 32) {
            collateralAmount = abi.decode(data, (uint256));
        }
        // If the call fails, return 0 (fallback behavior)
    }

    /**
     * @notice Calculate collateral needed for debt amount
     * @param debtAmount Amount of debt
     * @return collateralAmount Required collateral
     */
    function _calculateCollateralForDebt(uint256 debtAmount) internal view returns (uint256 collateralAmount) {
        // This is a simplified calculation - in practice would need to account for exchange rates
        collateralAmount = debtAmount.mulDivDown(MAX_BPS, config.targetLTV);
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


    //============================== FEE COLLECTION ===============================

    /**
     * @notice Collect accumulated performance fees
     */
    function collectFees() external requiresAuth {
        uint256 fees = accumulatedFees;
        if (fees > 0) {
            accumulatedFees = 0;
            hypeToken.safeTransfer(msg.sender, fees);
        }
    }
}
