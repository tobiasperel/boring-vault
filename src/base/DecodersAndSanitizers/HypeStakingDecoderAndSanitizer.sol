// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {BalancerV2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV2DecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";

/**
 * @title HypeStakingDecoderAndSanitizer
 * @notice Decoder and sanitizer for HYPE staking operations and Felix protocol borrowing
 * @dev Supports staking HYPE tokens, borrowing against stHYPE collateral, and necessary swaps
 */
contract HypeStakingDecoderAndSanitizer is
    UniswapV3DecoderAndSanitizer,
    BalancerV2DecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    BaseDecoderAndSanitizer
{
    //============================== IMMUTABLES ===============================

    /**
     * @notice The HYPE token address
     */
    address public immutable hypeToken;

    /**
     * @notice The stHYPE token address (staked HYPE)
     */
    address public immutable stHypeToken;

    /**
     * @notice The HYPE staking contract address
     */
    address public immutable hypeStakingContract;

    /**
     * @notice The Felix lending pool address
     */
    address public immutable felixLendingPool;

    //============================== CONSTRUCTOR ===============================

    constructor(
        address _uniswapV3NonFungiblePositionManager,
        address _hypeToken,
        address _stHypeToken,
        address _hypeStakingContract,
        address _felixLendingPool
    ) UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager) {
        hypeToken = _hypeToken;
        stHypeToken = _stHypeToken;
        hypeStakingContract = _hypeStakingContract;
        felixLendingPool = _felixLendingPool;
    }

    //============================== HYPE STAKING FUNCTIONS ===============================

    /**
     * @notice Decode and sanitize HYPE staking operations
     * @param amount Amount of HYPE to stake
     * @param receiver Address to receive stHYPE tokens
     */
    function stake(uint256 amount, address receiver)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    /**
     * @notice Decode and sanitize HYPE unstaking operations
     * @param shares Amount of stHYPE shares to unstake
     * @param receiver Address to receive HYPE tokens
     */
    function unstake(uint256 shares, address receiver)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    /**
     * @notice Decode and sanitize reward claiming
     * @param receiver Address to receive rewards
     */
    function claimRewards(address receiver)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    //============================== FELIX LENDING FUNCTIONS ===============================

    /**
     * @notice Decode and sanitize Felix deposit (collateral) operations
     * @param asset Address of the asset to deposit
     * @param amount Amount to deposit
     * @param onBehalfOf Address to credit the deposit to
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset, onBehalfOf);
    }

    /**
     * @notice Decode and sanitize Felix borrow operations
     * @param asset Address of the asset to borrow
     * @param amount Amount to borrow
     * @param interestRateMode Interest rate mode (1 for stable, 2 for variable)
     * @param referralCode Referral code
     * @param onBehalfOf Address to credit the borrow to
     */
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(asset, onBehalfOf);
    }

    /**
     * @notice Decode and sanitize Felix repay operations
     * @param asset Address of the asset to repay
     * @param amount Amount to repay
     * @param interestRateMode Interest rate mode
     * @param onBehalfOf Address to repay for
     */
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset, onBehalfOf);
    }

    /**
     * @notice Decode and sanitize Felix withdraw operations
     * @param asset Address of the asset to withdraw
     * @param amount Amount to withdraw
     * @param to Address to send withdrawn assets to
     */
    function withdraw(address asset, uint256 amount, address to)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset, to);
    }

    /**
     * @notice Decode and sanitize Felix setUserUseReserveAsCollateral operations
     * @param asset Address of the asset
     * @param useAsCollateral Whether to use as collateral
     */
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset);
    }

    //============================== HANDLE FUNCTION COLLISIONS ===============================

    /**
     * @notice BalancerV2 and ERC4626 both specify a `deposit(uint256,address)`,
     *         all cases are handled the same way.
     */
    function deposit(uint256, address receiver)
        external
        pure
        override(BalancerV2DecoderAndSanitizer, ERC4626DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }
}
