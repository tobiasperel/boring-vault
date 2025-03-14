// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.21;

// src/interfaces/DecoderCustomTypes.sol

contract DecoderCustomTypes {
    // ========================================= BALANCER =========================================
    struct JoinPoolRequest {
        address[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    struct ExitPoolRequest {
        address[] assets;
        uint256[] minAmountsOut;
        bytes userData;
        bool toInternalBalance;
    }

    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        address assetIn;
        address assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address recipient;
        bool toInternalBalance;
    }

    // ========================================= UNISWAP V3 =========================================

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct ExactInputParamsRouter02 {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct PancakeSwapExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    // ========================================= MORPHO BLUE =========================================

    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    // ========================================= 1INCH =========================================

    struct SwapDescription {
        address srcToken;
        address dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    // ========================================= PENDLE =========================================
    struct TokenInput {
        // TOKEN DATA
        address tokenIn;
        uint256 netTokenIn;
        address tokenMintSy;
        // AGGREGATOR DATA
        address pendleSwap;
        SwapData swapData;
    }

    struct TokenOutput {
        // TOKEN DATA
        address tokenOut;
        uint256 minTokenOut;
        address tokenRedeemSy;
        // AGGREGATOR DATA
        address pendleSwap;
        SwapData swapData;
    }

    struct ApproxParams {
        uint256 guessMin;
        uint256 guessMax;
        uint256 guessOffchain; // pass 0 in to skip this variable
        uint256 maxIteration; // every iteration, the diff between guessMin and guessMax will be divided by 2
        uint256 eps; // the max eps between the returned result & the correct result, base 1e18. Normally this number will be set
            // to 1e15 (1e18/1000 = 0.1%)
    }

    struct SwapData {
        SwapType swapType;
        address extRouter;
        bytes extCalldata;
        bool needScale;
    }

    enum SwapType {
        NONE,
        KYBERSWAP,
        ONE_INCH,
        // ETH_WETH not used in Aggregator
        ETH_WETH
    }

    struct LimitOrderData {
        address limitRouter;
        uint256 epsSkipMarket; // only used for swap operations, will be ignored otherwise
        FillOrderParams[] normalFills;
        FillOrderParams[] flashFills;
        bytes optData;
    }

    struct FillOrderParams {
        Order order;
        bytes signature;
        uint256 makingAmount;
    }

    struct Order {
        uint256 salt;
        uint256 expiry;
        uint256 nonce;
        OrderType orderType;
        address token;
        address YT;
        address maker;
        address receiver;
        uint256 makingAmount;
        uint256 lnImpliedRate;
        uint256 failSafeRate;
        bytes permit;
    }

    enum OrderType {
        SY_FOR_PT,
        PT_FOR_SY,
        SY_FOR_YT,
        YT_FOR_SY
    }

    // ========================================= EIGEN LAYER =========================================

    struct QueuedWithdrawalParams {
        // Array of strategies that the QueuedWithdrawal contains
        address[] strategies;
        // Array containing the amount of shares in each Strategy in the `strategies` array
        uint256[] shares;
        // The address of the withdrawer
        address withdrawer;
    }

    struct Withdrawal {
        // The address that originated the Withdrawal
        address staker;
        // The address that the staker was delegated to at the time that the Withdrawal was created
        address delegatedTo;
        // The address that can complete the Withdrawal + will receive funds when completing the withdrawal
        address withdrawer;
        // Nonce used to guarantee that otherwise identical withdrawals have unique hashes
        uint256 nonce;
        // Block number when the Withdrawal was created
        uint32 startBlock;
        // Array of strategies that the Withdrawal contains
        address[] strategies;
        // Array containing the amount of shares in each Strategy in the `strategies` array
        uint256[] shares;
    }

    struct SignatureWithExpiry {
        // the signature itself, formatted as a single bytes object
        bytes signature;
        // the expiration timestamp (UTC) of the signature
        uint256 expiry;
    }

    struct EarnerTreeMerkleLeaf {
        address earner;
        bytes32 earnerTokenRoot;
    }

    struct TokenTreeMerkleLeaf {
        address token;
        uint256 cumulativeEarnings;
    }

    struct RewardsMerkleClaim {
        uint32 rootIndex;
        uint32 earnerIndex;
        bytes earnerTreeProof;
        EarnerTreeMerkleLeaf earnerLeaf;
        uint32[] tokenIndices;
        bytes[] tokenTreeProofs;
        TokenTreeMerkleLeaf[] tokenLeaves;
    }

    // ========================================= CCIP =========================================

    // If extraArgs is empty bytes, the default is 200k gas limit.
    struct EVM2AnyMessage {
        bytes receiver; // abi.encode(receiver address) for dest EVM chains
        bytes data; // Data payload
        EVMTokenAmount[] tokenAmounts; // Token transfers
        address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2)
    }

    /// @dev RMN depends on this struct, if changing, please notify the RMN maintainers.
    struct EVMTokenAmount {
        address token; // token address on the local chain.
        uint256 amount; // Amount of tokens.
    }

    struct EVMExtraArgsV1 {
        uint256 gasLimit;
    }

    // ========================================= OFT =========================================

    struct SendParam {
        uint32 dstEid; // Destination endpoint ID.
        bytes32 to; // Recipient address.
        uint256 amountLD; // Amount to send in local decimals.
        uint256 minAmountLD; // Minimum amount to send in local decimals.
        bytes extraOptions; // Additional options supplied by the caller to be used in the LayerZero message.
        bytes composeMsg; // The composed message for the send() operation.
        bytes oftCmd; // The OFT command to be executed, unused in default OFT implementations.
    }

    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }
    // ========================================= L1StandardBridge =========================================

    struct WithdrawalTransaction {
        uint256 nonce;
        address sender;
        address target;
        uint256 value;
        uint256 gasLimit;
        bytes data;
    }

    struct OutputRootProof {
        bytes32 version;
        bytes32 stateRoot;
        bytes32 messagePasserStorageRoot;
        bytes32 latestBlockhash;
    }

    // ========================================= Mantle L1StandardBridge =========================================

    struct MantleWithdrawalTransaction {
        uint256 nonce;
        address sender;
        address target;
        uint256 mntValue;
        uint256 value;
        uint256 gasLimit;
        bytes data;
    }

    // ========================================= Linea Bridge =========================================

    struct ClaimMessageWithProofParams {
        bytes32[] proof;
        uint256 messageNumber;
        uint32 leafIndex;
        address from;
        address to;
        uint256 fee;
        uint256 value;
        address payable feeRecipient;
        bytes32 merkleRoot;
        bytes data;
    }

    // ========================================= Scroll Bridge =========================================

    struct L2MessageProof {
        uint256 batchIndex;
        bytes merkleProof;
    }

    // ========================================= Camelot V3 =========================================

    struct CamelotMintParams {
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }
    // ========================================= Velodrome V3 =========================================

    struct VelodromeMintParams {
        address token0;
        address token1;
        int24 tickSpacing;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
        uint160 sqrtPriceX96;
    }

    // ========================================= Karak =========================================

    struct QueuedWithdrawal {
        address staker;
        address delegatedTo;
        uint256 nonce;
        uint256 start;
        WithdrawRequest request;
    }

    struct WithdrawRequest {
        address[] vaults;
        uint256[] shares;
        address withdrawer;
    }

    // ========================================= Term Finance ==================================

    /// @dev TermAuctionOfferSubmission represents an offer submission to offeror an amount of money for a specific interest rate
    struct TermAuctionOfferSubmission {
        /// @dev For an existing offer this is the unique onchain identifier for this offer. For a new offer this is a randomized input that will be used to generate the unique onchain identifier.
        bytes32 id;
        /// @dev The address of the offeror
        address offeror;
        /// @dev Hash of the offered price as a percentage of the initial loaned amount vs amount returned at maturity. This stores 9 decimal places
        bytes32 offerPriceHash;
        /// @dev The maximum amount of purchase tokens that can be lent
        uint256 amount;
        /// @dev The address of the ERC20 purchase token
        address purchaseToken;
    }

    // ========================================= Dolomite Finance ==================================

    enum BalanceCheckFlag {
        Both,
        From,
        To,
        None
    }

    // ========================================= Silo Finance ==================================
    /// @dev There are 2 types of accounting in the system: for non-borrowable collateral deposit called "protected" and
    ///      for borrowable collateral deposit called "collateral". System does
    ///      identical calculations for each type of accounting but it uses different data. To avoid code duplication
    ///      this enum is used to decide which data should be read.
    enum CollateralType {
        Protected, // default
        Collateral
    }

    enum ActionType {
        Deposit,
        Mint,
        Repay,
        RepayShares
    }

    struct Action {
        // what do you want to do?
        uint8 actionType;
        // which Silo are you interacting with?
        address silo;
        // what asset do you want to use?
        address asset;
        // options specific for actions
        bytes options;
    }

    struct AnyAction {
        // how much assets or shares do you want to use?
        uint256 amount;
        // are you using Protected, Collateral
        uint8 assetType;
    }

    // ========================================= LBTC Bridge ==================================
    struct DepositBridgeAction {
        uint256 fromChain;
        bytes32 fromContract;
        uint256 toChain;
        address toContract;
        address recipient;
        uint64 amount;
        uint256 nonce;
    }

    // ========================================= Odos ==================================
    
    struct swapTokenInfo {
        address inputToken;
        uint256 inputAmount;
        address inputReceiver;
        address outputToken;
        uint256 outputQuote;
        uint256 outputMin;
        address outputReceiver;
    }
    // ========================================= Level ==================================
    
    /// @dev for reference 
    //enum OrderType {
    //    MINT,
    //    REDEEM
    //}
    
    struct LevelOrder {
        uint8 order_type;
        address benefactor;
        address beneficiary;
        address collateral_asset;
        uint256 collateral_amount;
        uint256 lvlusd_amount;
    }    

    struct Route {
        address[] addresses;
        uint256[] ratios;
    }
}

// src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol

// Swell
interface INonFungiblePositionManager {
    struct Position {
        // the nonce for permits
        uint96 nonce;
        // the address that is approved for spending this token
        address operator;
        // the ID of the pool with which this token is connected
        uint80 poolId;
        // the tick range of the position
        int24 tickLower;
        int24 tickUpper;
        // the liquidity of the position
        uint128 liquidity;
        // the fee growth of the aggregate position as of the last action on the individual position
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // how many uncollected tokens are owed to the position, as of the last computation
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    function ownerOf(uint256 tokenId) external view returns (address);
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}

interface PancakeSwapV3MasterChef {
    function userPositionInfos(uint256 id)
        external
        view
        returns (
            uint128 liquidity,
            uint128 boostLiquidity,
            int24 tickLower,
            int24 tickUpper,
            uint256 rewardsGrowthInside,
            uint256 reward,
            address user,
            uint256 pid,
            uint256 boostMultiplier
        );
}

interface CamelotNonFungiblePositionManager {
    function ownerOf(uint256 tokenId) external view returns (address);
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}

interface IRecipeMarketHub {
    function offerHashToIPOffer(bytes32 offer)
        external
        view
        returns (uint256, bytes32, address, uint256, uint256, uint256);
}

interface IPoolRegistry {
    function poolInfo(uint256 _pid) external view returns (address, address, address, address, uint8); 
}

// src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol

contract BaseDecoderAndSanitizer {
    error BaseDecoderAndSanitizer__FunctionSelectorNotSupported();
    //============================== IMMUTABLES ===============================

    function approve(address spender, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(spender);
    }

    function transfer(address _to, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_to);
    }

    function claimFees(address feeAsset) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(feeAsset);
    }

    function claimYield(address yieldAsset) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(yieldAsset);
    }

    function withdrawNonBoringToken(address token, uint256 /*amount*/ )
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(token);
    }

    function withdrawNativeFromDrone() external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    //============================== FALLBACK ===============================
    /**
     * @notice The purpose of this function is to revert with a known error,
     *         so that during merkle tree creation we can verify that a
     *         leafs decoder and sanitizer implments the required function
     *         selector.
     */
    fallback() external {
        revert BaseDecoderAndSanitizer__FunctionSelectorNotSupported();
    }
}

// src/base/DecodersAndSanitizers/Protocols/AmbientDecoderAndSanitizer.sol

abstract contract AmbientDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error AmbientDecoderAndSanitizer__UnsupportedCallPath(); 

    //============================== CrocSwapDex ===============================
    
    // NOTE: this is disabled on ETH and Scroll according to their docs and swaps should be routed through either the Router or using `userCmd()`
    // NOTE: the router exposes the same abi as the function below, just at a higher gas cost. 
    function swap(
        address base,
        address quote,
        uint256, /*poolIdx*/
        bool, /*isBuy*/
        bool, /*inBaseQty*/
        uint128, /*qty*/
        uint16, /*tip*/
        uint128, /*limitPrice*/
        uint128, /*minOut*/
        uint8 /*reserveFlags*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(base, quote);
    }

    function userCmd(uint16 callpath, bytes calldata cmd) external pure virtual returns (bytes memory addressesFound) {
        // NOTE: LP warmpath seems to be 128 (on FE execution) or 2 (https://github.com/CrocSwap/CrocSwap-protocol/blob/33f339d014d21c47b1e20c9c998d1c12d85976f7/contracts/mixins/StorageLayout.sol#L184) in the contract itself. 
        // swap is 1, knockout is 7, confirmed by FE execution.  
        //
        //
        // This should be all the functionality a strategist would need
        if (callpath == 1) {
            (
                address base,
                address quote,
                /*uint256 poolIdx*/,
                /*bool, isBuy*/,
                /*bool, /*inBaseQty*/,
                /*uint128, /*qty*/,
                /*uint16, /*tip*/,
                /*uint128, /*limitPrice*/,
                /*uint128, /*minOut*/,
                /*uint8 /*reserveFlags*/
            ) = abi.decode(
                cmd, (address, address, uint256, bool, bool, uint128, uint16, uint128, uint128, uint8));

            addressesFound = abi.encodePacked(base, quote);   

        } else if (callpath == 128 || callpath == 2) { //handle concentrated LP positions and ambient (full range) positions
            (
                /*uint8 code*/,
                address base,
                address quote,
                /*uint256 poolIdx*/,
                /*int24 bidTick*/,
                /*int24 askTick*/,
                /*uint128 liq*/,
                /*uint128 limitLower*/,
                /*uint128 limitHigher*/,
                /*uint8 reserveFlags*/,
                address lpConduit
            ) = abi.decode(
                cmd, (uint8, address, address, uint256, int24, int24, uint128, uint128, uint128, uint8, address)
            );

            addressesFound = abi.encodePacked(base, quote, lpConduit);
        } else if (callpath == 7) {
            //knockout position
            //args are further decoded into ((uint128 qty, bool insideMid) = abi.decode(args, (uint128,bool))); and not needed for sanitation
            (
                /*uint8 code*/,
                address base,
                address quote,
                /*uint256 poolIdx*/,
                /*int24 idTick*/,
                /*int24 askTick*/,
                /*bool isBid*/,
                /*uint8 reserveFlags*/,
                /*bytes memory args*/
            ) = abi.decode(cmd, (uint8, address, address, uint256, int24, int24, bool, uint8, bytes));

            addressesFound = abi.encodePacked(base, quote); 
        } else {
            revert AmbientDecoderAndSanitizer__UnsupportedCallPath(); 
        }
    }
}

// src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol

abstract contract ERC4626DecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERC4626 ===============================

    function deposit(uint256, address receiver) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver);
    }

    function mint(uint256, address receiver) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver);
    }

    function withdraw(uint256, address receiver, address owner)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver, owner);
    }

    function redeem(uint256, address receiver, address owner)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver, owner);
    }
}

// src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol

abstract contract MerklDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== Merkl ===============================

    error MerklDecoderAndSanitizer__InputLengthMismatch();

    function toggleOperator(address user, address operator)
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        sensitiveArguments = abi.encodePacked(user, operator);
    }

    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        // The distributor checks if the lengths match, but we also do it here just in case Distributors are upgraded.
        uint256 usersLength = users.length;
        if (usersLength != tokens.length || usersLength != amounts.length || usersLength != proofs.length) {
            revert MerklDecoderAndSanitizer__InputLengthMismatch();
        }

        for (uint256 i; i < usersLength; ++i) {
            sensitiveArguments = abi.encodePacked(sensitiveArguments, users[i], tokens[i]);
        }
    }
}

// src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol

abstract contract NativeWrapperDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ETHERFI ===============================

    function deposit() external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function withdraw(uint256) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
}

// src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol

abstract contract OFTDecoderAndSanitizer is BaseDecoderAndSanitizer {
    error OFTDecoderAndSanitizer__NonZeroMessage();
    error OFTDecoderAndSanitizer__NonZeroOFTCommand();

    //============================== OFT ===============================

    function send(
        DecoderCustomTypes.SendParam calldata _sendParam,
        DecoderCustomTypes.MessagingFee calldata, /*_fee*/
        address _refundAddress
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        // Sanitize Message.
        if (_sendParam.composeMsg.length > 0) {
            revert OFTDecoderAndSanitizer__NonZeroMessage();
        }
        if (_sendParam.oftCmd.length > 0) {
            revert OFTDecoderAndSanitizer__NonZeroOFTCommand();
        }

        sensitiveArguments =
            abi.encodePacked(address(uint160(_sendParam.dstEid)), address(bytes20(_sendParam.to << 96)), _refundAddress);
    }
}

// src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol

abstract contract StandardBridgeDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== StandardBridge ===============================

    /// @notice Example TX https://etherscan.io/tx/0x0b1cc213286c328e3fb483cfef9342aee51409b67ee5af1dc409e37273710f9f
    /// @notice Eample TX https://basescan.org/tx/0x7805ac08f38bec2d98edafc2e6f9571271a76b5ede3928f96d3edbc459d0ea4d
    function bridgeETHTo(address _to, uint32, /*_minGasLimit*/ bytes calldata /*_extraData*/ )
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(_to);
    }

    function bridgeERC20To(
        address _localToken,
        address _remoteToken,
        address _to,
        uint256, /*_amount*/
        uint32, /*_minGasLimit*/
        bytes calldata /*_extraData*/
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(_localToken, _remoteToken, _to);
    }

    /// @notice Example TX https://etherscan.io/tx/0x774db0b2aac5123f7a67fe00d57fb6c1f731457df435097481e7c8c913630fe1
    /// @notice This appears to be callable by anyone, so I would think that the sender and target values are constrained by the proofs
    // Playing with tendely sims, this does seem to be the case, so I am not sure it is worth it to sanitize these arguments
    function proveWithdrawalTransaction(
        DecoderCustomTypes.WithdrawalTransaction calldata _tx,
        uint256, /*_l2OutputIndex*/
        DecoderCustomTypes.OutputRootProof calldata, /*_outputRootProof*/
        bytes[] calldata /*_withdrawalProof*/
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }

    /// @notice Eample TX https://etherscan.io/tx/0x5bb20258a0b151a6acb01f05ea42ee2f51123cba5d51e9be46a5033e675faefe
    function finalizeWithdrawalTransaction(DecoderCustomTypes.WithdrawalTransaction calldata _tx)
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }
}

// src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol

abstract contract EulerEVKDecoderAndSanitizer is BaseDecoderAndSanitizer, ERC4626DecoderAndSanitizer {

    //============================== ERRORS ===============================
    
    error EulerEVKDecoderAndSanitizer__FunctionSelectorNotSupported();

    //============================== EthereumVaultConnector  ===============================
    
    function enableController(address account, address vault)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(account, vault);
    }

    function enableCollateral(address account, address vault)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(account, vault);
    }

    function disableController(address account) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(account);
    }

    //nothing to sanitize
    function disableController() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function disableCollateral(address account, address vault)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(account, vault);
    }

    function call(
        address targetContract,
        address onBehalfOfAccount,
        uint256 /*value*/,
        bytes calldata data
    ) external pure returns (bytes memory addressesFound) {
        //target contract = vault
        //onBehalfOfAccount = subaccount
        //data will always be a function, so we can put the whitelisted function selectors in leaves
        //these should only need to be assets that pull funds to avoid sending anything to subaccounts mistakenly
        //afaik, the only ones would be borrow, withdraw, and redeem

        bytes4 selector = bytes4(data[:4]);

        if (selector == bytes4(keccak256("borrow(uint256,address)"))) {
            (, address receiver) = abi.decode(data[4:], (uint256, address));
            return abi.encodePacked(targetContract, onBehalfOfAccount, address(uint160(uint32(selector))), receiver);
        } else if (selector == bytes4(keccak256("withdraw(uint256,address,address)"))) {
            (, address receiver, address owner) = abi.decode(data[4:], (uint256, address, address));
            return abi.encodePacked(targetContract, onBehalfOfAccount, address(uint160(uint32(selector))), receiver, owner);
        } else if (selector == bytes4(keccak256("redeem(uint256,address,address)"))) {
            (, address receiver, address owner) = abi.decode(data[4:], (uint256, address, address));
            return abi.encodePacked(targetContract, onBehalfOfAccount, address(uint160(uint32(selector))), receiver, owner);
        } else {
            revert EulerEVKDecoderAndSanitizer__FunctionSelectorNotSupported(); 
        }
    }

    //============================== EVK Vaults ===============================
    
    function borrow(uint256, /*amount*/ address receiver) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(receiver);
    }

    function repay(uint256, /*amount*/ address receiver) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(receiver);
    }

    function repayWithShares(uint256, /*amount*/ address receiver)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(receiver);
    }
}

// src/base/DecodersAndSanitizers/Protocols/VelodromeDecoderAndSanitizer.sol

abstract contract VelodromeDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error VelodromeDecoderAndSanitizer__BadTokenId();
    error VelodromeDecoderAndSanitizer__PoolCreationNotAllowed();

    //============================== IMMUTABLES ===============================

    /**
     * @notice The networks velodrom nonfungible position manager.
     * @notice Optimism 0x416b433906b1B72FA758e166e239c43d68dC6F29
     * @notice Base 0x827922686190790b37229fd06084350E74485b72
     * @notice
     */
    INonFungiblePositionManager internal immutable velodromeNonFungiblePositionManager;

    constructor(address _velodromeNonFungiblePositionManager) {
        velodromeNonFungiblePositionManager = INonFungiblePositionManager(_velodromeNonFungiblePositionManager);
    }

    //============================== VELODROME V3 ===============================

    function mint(DecoderCustomTypes.VelodromeMintParams calldata params)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        if (params.sqrtPriceX96 != 0) {
            revert VelodromeDecoderAndSanitizer__PoolCreationNotAllowed();
        }
        // Return addresses found
        addressesFound = abi.encodePacked(params.token0, params.token1, params.recipient);
    }

    function increaseLiquidity(DecoderCustomTypes.IncreaseLiquidityParams calldata params)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        // Sanitize raw data
        address owner = velodromeNonFungiblePositionManager.ownerOf(params.tokenId);
        // Extract addresses from VelodromeNonFungiblePositionManager.positions(params.tokenId).
        (, address operator, address token0, address token1,,,,,,,,) =
            velodromeNonFungiblePositionManager.positions(params.tokenId);
        addressesFound = abi.encodePacked(operator, token0, token1, owner);
    }

    function decreaseLiquidity(DecoderCustomTypes.DecreaseLiquidityParams calldata params)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        // Sanitize raw data
        // NOTE ownerOf check is done in PositionManager contract as well, but it is added here
        // just for completeness.
        address owner = velodromeNonFungiblePositionManager.ownerOf(params.tokenId);
        // Extract addresses from VelodromeNonFungiblePositionManager.positions(params.tokenId).

        // No addresses in data
        return abi.encodePacked(owner);
    }

    function collect(DecoderCustomTypes.CollectParams calldata params)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        // Sanitize raw data
        // NOTE ownerOf check is done in PositionManager contract as well, but it is added here
        // just for completeness.
        address owner = velodromeNonFungiblePositionManager.ownerOf(params.tokenId);

        // Return addresses found
        addressesFound = abi.encodePacked(params.recipient, owner);
    }

    function burn(uint256 /*tokenId*/ ) external pure virtual returns (bytes memory addressesFound) {
        // positionManager.burn(tokenId) will verify that the tokenId has no liquidity, and no tokens owed.
        // Nothing to sanitize or return
        return addressesFound;
    }

    //============================== VELODROME V2 ===============================

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool, /*stable*/
        uint256, /*amountADesired*/
        uint256, /*amountBDesired*/
        uint256, /*amountAMin*/
        uint256, /*amountBMin*/
        address to,
        uint256 /*deadline*/
    ) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize
        // Return addresses found
        addressesFound = abi.encodePacked(tokenA, tokenB, to);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool, /*stable*/
        uint256, /*liquidity*/
        uint256, /*amountAMin*/
        uint256, /*amountBMin*/
        address to,
        uint256 /*deadline*/
    ) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize
        // Return addresses found
        addressesFound = abi.encodePacked(tokenA, tokenB, to);
    }

    //============================== VELODROME V2/V3 GAUGE ===============================

    function deposit(uint256 /*tokenId_or_amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function withdraw(uint256 /*tokenId_or_amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    // Only callable on V3 gauge
    function getReward(uint256 /*tokenId*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function getReward(address account) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(account);
    }
}

// src/base/DecodersAndSanitizers/SwellEtherFiLiquidEthDecoderAndSanitizer.sol

contract SwellEtherFiLiquidEthDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    StandardBridgeDecoderAndSanitizer,
    EulerEVKDecoderAndSanitizer,
    MerklDecoderAndSanitizer,
    AmbientDecoderAndSanitizer,
    VelodromeDecoderAndSanitizer
{

    constructor(address _velodromeNonFungiblePositionManager) VelodromeDecoderAndSanitizer(_velodromeNonFungiblePositionManager){}

    /**
     * @notice Velodrome, NativeWrapper both specify a `withdraw(uint256)`,
     *         all cases are handled the same way.
     */
    function withdraw(uint256 /*amount*/)
        external
        pure
        override(VelodromeDecoderAndSanitizer, NativeWrapperDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound; 
    }

}

