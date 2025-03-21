// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateUltraUsdMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 100000000000000000
 */
/// @dev NOTE: This script contains drone leaves. If adding new functionality, be sure to include it in drones as well. 
contract CreateUltraUsdMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xbc0f3B23930fff9f4894914bD745ABAbA9588265;
    address public rawDataDecoderAndSanitizer = 0xfB319769c34AeAf8587F386417d984BE49088338;
    address public managerAddress = 0x4f81c27e750A453d6206C2d10548d6566F60886C;
    address public accountantAddress = 0x95fE19b324bE69250138FE8EE50356e9f6d17Cfe;
    address public drone = 0x20A0d13C4643AB962C6804BC6ba6Eea0505F11De;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateUltraUsdStrategistMerkleRoot();
    }

    function generateUltraUsdStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](4096);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](4);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "DAI");
        feeAssets[2] = getERC20(sourceChain, "USDT");
        feeAssets[3] = getERC20(sourceChain, "USDE");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ========================== Aave V3 ==========================
        ERC20[] memory aaveSupplyAssets = new ERC20[](6);
        aaveSupplyAssets[0] = getERC20(sourceChain, "USDC");
        aaveSupplyAssets[1] = getERC20(sourceChain, "USDT");
        aaveSupplyAssets[2] = getERC20(sourceChain, "DAI");
        aaveSupplyAssets[3] = getERC20(sourceChain, "WEETH");
        aaveSupplyAssets[4] = getERC20(sourceChain, "WSTETH");
        aaveSupplyAssets[5] = getERC20(sourceChain, "USDS");
        ERC20[] memory aaveBorrowAssets = new ERC20[](6);
        aaveBorrowAssets[0] = getERC20(sourceChain, "USDC");
        aaveBorrowAssets[1] = getERC20(sourceChain, "USDT");
        aaveBorrowAssets[2] = getERC20(sourceChain, "DAI");
        aaveBorrowAssets[3] = getERC20(sourceChain, "WETH");
        aaveBorrowAssets[4] = getERC20(sourceChain, "WSTETH");
        aaveBorrowAssets[5] = getERC20(sourceChain, "GHO");
        _addAaveV3Leafs(leafs, aaveSupplyAssets, aaveBorrowAssets);

        // ========================== SparkLend ==========================
        ERC20[] memory sparkLendSupplyAssets = new ERC20[](7);
        sparkLendSupplyAssets[0] = getERC20(sourceChain, "USDC");
        sparkLendSupplyAssets[1] = getERC20(sourceChain, "USDT");
        sparkLendSupplyAssets[2] = getERC20(sourceChain, "DAI");
        sparkLendSupplyAssets[3] = getERC20(sourceChain, "sUSDs");
        sparkLendSupplyAssets[4] = getERC20(sourceChain, "WETH");
        sparkLendSupplyAssets[5] = getERC20(sourceChain, "WSTETH");
        sparkLendSupplyAssets[6] = getERC20(sourceChain, "WEETH");
        ERC20[] memory sparkLendBorrowAssets = new ERC20[](5);
        sparkLendBorrowAssets[0] = getERC20(sourceChain, "USDC");
        sparkLendBorrowAssets[1] = getERC20(sourceChain, "USDT");
        sparkLendBorrowAssets[2] = getERC20(sourceChain, "DAI");
        sparkLendBorrowAssets[3] = getERC20(sourceChain, "WETH");
        sparkLendBorrowAssets[4] = getERC20(sourceChain, "WSTETH");

        _addSparkLendLeafs(leafs, sparkLendSupplyAssets, sparkLendBorrowAssets);

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "usualBoostedUSDC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCprime")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCfrontier")));

        // ========================== MorphoBlue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));

        // ========================== Morpho Rewards ==========================
        _addMorphoRewardMerkleClaimerLeafs(leafs, universalRewardsDistributor);

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));
        // ========================== Usual ==========================
        _addUsualMoneyLeafs(leafs);

        // ========================== Elixir ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sdeUSD")));
        _addELXClaimingLeafs(leafs);

        // ========================== Elixir Withdraws ==========================
        _addElixirSdeUSDWithdrawLeafs(leafs);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_sUSDe_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_01_29_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_02_26_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_03_26_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_04_23_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_06_25_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_wstUSR_market_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USDe_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_lvlUSD_05_28_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_slvlUSD_05_28_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_sUSDe_05_28_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_syrupUSDC_04_23_25"), true);

        // ========================== 1inch ==========================
        /*
         *
         */
        address[] memory oneInchAssets = new address[](23);
        SwapKind[] memory oneInchKind = new SwapKind[](23);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchKind[0] = SwapKind.BuyAndSell;
        oneInchAssets[1] = getAddress(sourceChain, "USDT");
        oneInchKind[1] = SwapKind.BuyAndSell;
        oneInchAssets[2] = getAddress(sourceChain, "DAI");
        oneInchKind[2] = SwapKind.BuyAndSell;
        oneInchAssets[3] = getAddress(sourceChain, "USDS");
        oneInchKind[3] = SwapKind.BuyAndSell;
        oneInchAssets[4] = getAddress(sourceChain, "PENDLE");
        oneInchKind[4] = SwapKind.Sell;
        oneInchAssets[5] = getAddress(sourceChain, "deUSD");
        oneInchKind[5] = SwapKind.BuyAndSell;
        oneInchAssets[6] = getAddress(sourceChain, "sdeUSD");
        oneInchKind[6] = SwapKind.BuyAndSell;
        oneInchAssets[7] = getAddress(sourceChain, "USDS");
        oneInchKind[7] = SwapKind.BuyAndSell;
        oneInchAssets[8] = getAddress(sourceChain, "sUSDs");
        oneInchKind[8] = SwapKind.BuyAndSell;
        oneInchAssets[9] = getAddress(sourceChain, "USD0");
        oneInchKind[9] = SwapKind.BuyAndSell;
        oneInchAssets[10] = getAddress(sourceChain, "USD0_plus");
        oneInchKind[10] = SwapKind.BuyAndSell;
        oneInchAssets[11] = getAddress(sourceChain, "WETH");
        oneInchKind[11] = SwapKind.BuyAndSell;
        oneInchAssets[12] = getAddress(sourceChain, "WEETH");
        oneInchKind[12] = SwapKind.BuyAndSell;
        oneInchAssets[13] = getAddress(sourceChain, "USDE");
        oneInchKind[13] = SwapKind.BuyAndSell;
        oneInchAssets[14] = getAddress(sourceChain, "SUSDE");
        oneInchKind[14] = SwapKind.BuyAndSell;
        oneInchAssets[15] = getAddress(sourceChain, "WSTETH");
        oneInchKind[15] = SwapKind.BuyAndSell;
        oneInchAssets[16] = getAddress(sourceChain, "MORPHO");
        oneInchKind[16] = SwapKind.Sell;
        oneInchAssets[17] = getAddress(sourceChain, "USUAL");
        oneInchKind[17] = SwapKind.Sell;
        oneInchAssets[18] = getAddress(sourceChain, "ETHFI");
        oneInchKind[18] = SwapKind.Sell;
        oneInchAssets[19] = getAddress(sourceChain, "USR");
        oneInchKind[19] = SwapKind.BuyAndSell;
        oneInchAssets[20] = getAddress(sourceChain, "GHO");
        oneInchKind[20] = SwapKind.BuyAndSell;
        oneInchAssets[21] = getAddress(sourceChain, "lvlUSD");
        oneInchKind[21] = SwapKind.BuyAndSell;
        oneInchAssets[22] = getAddress(sourceChain, "slvlUSD");
        oneInchKind[22] = SwapKind.BuyAndSell;
        oneInchAssets[23] = getAddress(sourceChain, "EIGEN");
        oneInchKind[23] = SwapKind.Sell;
        oneInchAssets[24] = getAddress(sourceChain, "KING"); // TODO: double check this should be included
        oneInchKind[24] = SwapKind.Sell;
        oneInchAssets[25] = getAddress(sourceChain, "ELX");
        oneInchKind[25] = SwapKind.Sell;
        oneInchAssets[26] = getAddress(sourceChain, "syrupUSDC");
        oneInchKind[26] = SwapKind.BuyAndSell;
        oneInchAssets[27] = getAddress(sourceChain, "syrupUSDT");
        oneInchKind[27] = SwapKind.BuyAndSell;
        oneInchAssets[28] = getAddress(sourceChain, "WSTUSR");
        oneInchKind[28] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, oneInchAssets, oneInchKind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, oneInchAssets, oneInchKind); 

        // ========================== EtherFi ==========================
        /**
         * stake, unstake, wrap, unwrap
         */
        _addEtherFiLeafs(leafs);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Ethena ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE")));
        _addEthenaSUSDeWithdrawLeafs(leafs);

        // ========================== Curve ==========================
        _addCurveLeafs(
            leafs,
            getAddress(sourceChain, "USD0_USD0++_CurvePool"),
            2,
            getAddress(sourceChain, "USD0_USD0++_CurveGauge")
        );
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "USD0_USD0++_CurvePool"));

        // ========================== MakerDAO ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDs")));

        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sDAI")));

        // ========================== lvlUSD ==========================
        _addLevelLeafs(leafs);

        // ========================== Spectra ==========================
        _addSpectraLeafs(
            leafs,
            getAddress(sourceChain, "spectra_lvlUSD_Pool"),
            getAddress(sourceChain, "spectra_lvlUSD_PT"),
            getAddress(sourceChain, "spectra_lvlUSD_YT"),
            getAddress(sourceChain, "spectra_lvlUSD_IBT")
        );

        _addSpectraLeafs(
            leafs,
            getAddress(sourceChain, "spectra_sdeUSD_Pool"),
            getAddress(sourceChain, "spectra_sdeUSD_PT"),
            getAddress(sourceChain, "spectra_sdeUSD_YT"),
            getAddress(sourceChain, "spectra_sdeUSD_IBT")
        );

        _addSpectraLeafs(
            leafs,
            getAddress(sourceChain, "spectra_wstUSR_Pool"),
            getAddress(sourceChain, "spectra_wstUSR_PT"),
            getAddress(sourceChain, "spectra_wstUSR_YT"),
            getAddress(sourceChain, "spectra_wstUSR_IBT")
        );

        // ========================== Resolv ==========================
        _addAllResolvLeafs(leafs);

        // ========================== Teller ==========================
        ERC20[] memory tellerAssets = new ERC20[](4); 
        tellerAssets[0] = getERC20(sourceChain, "USDT");
        tellerAssets[1] = getERC20(sourceChain, "USDC");
        tellerAssets[2] = getERC20(sourceChain, "DAI");
        tellerAssets[3] = getERC20(sourceChain, "USDS");
        _addTellerLeafs(leafs, getAddress(sourceChain, "TACTeller"), tellerAssets, false); // TODO find actual TAC teller address

        // ========================== BalancerV3 ==========================
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), true, getAddress(sourceChain, "balancerV3_USDC_GHO_USDT_gauge")); // TODO: check approvals

        // ========================== Aura ==========================
        // TODO: add aura leafs using a new merkle tree helper function that works like _addConvexLeafs but targets aura booster

        // ========================== Syrup ==========================
        _addAllSyrupLeafs(leafs);

        // ========================== Euler ==========================
        ERC4626[] memory depositVaults = new ERC4626[](1);
        depositVaults[0] = ERC4626(getAddress(sourceChain, "evkeUSDC-22"));

        address[] memory subaccounts = new address[](1);
        subaccounts[0] = address(boringVault);

        ERC4626[] memory borrowVaults = new ERC4626[](1); 
        borrowVaults[0] = ERC4626(getAddress(sourceChain, "evkeUSDC-22")); 

        _addEulerDepositLeafs(leafs, depositVaults, subaccounts);
        _addEulerBorrowLeafs(leafs, borrowVaults, subaccounts);

        // ========================== Fluid ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fUSDC"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fUSDT"));            
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fsUSDe")); // TODO check if this should exist

        // ========================== Fluid Dex ========================== // TODO find + fix addresses
         {
            ERC20[] memory supplyTokens = new ERC20[](1);
            supplyTokens[0] = getERC20(sourceChain, "sUSDe");

            ERC20[] memory borrowTokens = new ERC20[](2);
            borrowTokens[0] = getERC20(sourceChain, "USDT");
            borrowTokens[1] = getERC20(sourceChain, "USDC");

            uint256 dexType = 3000; // TODO check this, it would make more sense for it to be 30000

            _addFluidDexLeafs(
                leafs, getAddress(sourceChain, "sUSDe_DEX-USDC-USDT"), dexType, supplyTokens, borrowTokens, false //no native ETH leaves
            );
        }

        // ========================== King ==========================
        // TODO add redeem leaf

        // ========================== Drone Transfers ==========================
        ERC20[] memory localTokens = new ERC20[](22);
        localTokens[0] = getERC20("mainnet", "USDC");
        localTokens[1] = getERC20("mainnet", "USDT");
        localTokens[2] = getERC20("mainnet", "DAI");
        localTokens[3] = getERC20("mainnet", "WETH");
        localTokens[4] = getERC20("mainnet", "WEETH");
        localTokens[5] = getERC20("mainnet", "USD0");
        localTokens[6] = getERC20("mainnet", "USD0_plus");
        localTokens[7] = getERC20("mainnet", "deUSD");
        localTokens[8] = getERC20("mainnet", "sdeUSD");
        localTokens[9] = getERC20("mainnet", "USDE");
        localTokens[10] = getERC20("mainnet", "SUSDE");
        localTokens[11] = getERC20("mainnet", "USDS");
        localTokens[12] = getERC20("mainnet", "sUSDs");
        localTokens[13] = getERC20("mainnet", "sDAI");
        localTokens[14] = getERC20("mainnet", "lvlUSD");
        localTokens[15] = getERC20("mainnet", "slvlUSD");
        localTokens[16] = getERC20("mainnet", "pendle_lvlUSD_05_28_25_sy");
        localTokens[17] = getERC20("mainnet", "pendle_lvlUSD_05_28_25_pt");
        localTokens[18] = getERC20("mainnet", "pendle_lvlUSD_05_28_25_yt");
        localTokens[19] = getERC20("mainnet", "pendle_slvlUSD_05_28_25_sy");
        localTokens[20] = getERC20("mainnet", "pendle_slvlUSD_05_28_25_pt");
        localTokens[21] = getERC20("mainnet", "pendle_slvlUSD_05_28_25_yt");
        // TODO: complete

        _addLeafsForDroneTransfers(leafs, drone, localTokens);

        // ====================================================
        //
        //                  Begin Drone Leaves
        //
        // ====================================================

        uint256 startIndex = leafIndex + 1;
        setAddress(true, sourceChain, "boringVault", drone);

        // ========================== Aave V3 ==========================
        _addAaveV3Leafs(leafs, aaveSupplyAssets, aaveBorrowAssets);

        // ========================== SparkLend ==========================
        _addSparkLendLeafs(leafs, sparkLendSupplyAssets, sparkLendBorrowAssets);

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "usualBoostedUSDC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCprime")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCfrontier")));

        // ========================== MorphoBlue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));

        // ========================== Morpho Rewards ==========================
        _addMorphoRewardMerkleClaimerLeafs(leafs, getAddress(sourceChain, "universalRewardsDistributor"));

        // ========================== Usual ==========================
        _addUsualMoneyLeafs(leafs);

        // ========================== Elixir ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sdeUSD")));
        _addELXClaimingLeafs(leafs);

        // ========================== Elixir Withdraws ==========================
        _addElixirSdeUSDWithdrawLeafs(leafs);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_sUSDe_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_01_29_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_02_26_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_03_26_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_04_23_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_06_25_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_wstUSR_market_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USDe_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_lvlUSD_05_28_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_slvlUSD_05_28_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_sUSDe_05_28_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_syrupUSDC_04_23_25"), true);

        // ========================== 1inch ==========================
        /*
         *
         */
        _addLeafsFor1InchGeneralSwapping(leafs, oneInchAssets, oneInchKind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, oneInchAssets, oneInchKind);  

        // ========================== EtherFi ==========================
        /**
         * stake, unstake, wrap, unwrap
         */
        _addEtherFiLeafs(leafs);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Ethena ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE")));
        _addEthenaSUSDeWithdrawLeafs(leafs);

        // ========================== Curve ==========================
        _addCurveLeafs(
            leafs,
            getAddress(sourceChain, "USD0_USD0++_CurvePool"),
            2,
            getAddress(sourceChain, "USD0_USD0++_CurveGauge")
        );
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "USD0_USD0++_CurvePool"));

        // ========================== MakerDAO ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDs")));

        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sDAI")));

        // ========================== lvlUSD ==========================
        _addLevelLeafs(leafs);

        // ========================== Spectra ==========================
        _addSpectraLeafs(
            leafs,
            getAddress(sourceChain, "spectra_lvlUSD_Pool"),
            getAddress(sourceChain, "spectra_lvlUSD_PT"),
            getAddress(sourceChain, "spectra_lvlUSD_YT"),
            getAddress(sourceChain, "spectra_lvlUSD_IBT")
        );

        _addSpectraLeafs(
            leafs,
            getAddress(sourceChain, "spectra_sdeUSD_Pool"),
            getAddress(sourceChain, "spectra_sdeUSD_PT"),
            getAddress(sourceChain, "spectra_sdeUSD_YT"),
            getAddress(sourceChain, "spectra_sdeUSD_IBT")
        );

        _addSpectraLeafs(
            leafs,
            getAddress(sourceChain, "spectra_wstUSR_Pool"),
            getAddress(sourceChain, "spectra_wstUSR_PT"),
            getAddress(sourceChain, "spectra_wstUSR_YT"),
            getAddress(sourceChain, "spectra_wstUSR_IBT")
        );

        // ========================== Resolv ==========================
        _addAllResolvLeafs(leafs);

        // ========================== Teller ==========================
        _addTellerLeafs(leafs, getAddress(sourceChain, "TACTeller"), tellerAssets, false);

        // ========================== BalancerV3 ==========================
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), true, getAddress(sourceChain, "balancerV3_USDC_GHO_USDT_gauge")); // TODO: check approvals

        // ========================== Aura ==========================
        // TODO: add aura leafs using a new merkle tree helper function that works like _addConvexLeafs but targets aura booster

        // ========================== Syrup ==========================
        _addAllSyrupLeafs(leafs);

        // ========================== Euler ==========================
        subaccounts[0] = address(drone); // TODO: confirm any others like this
        _addEulerDepositLeafs(leafs, depositVaults, subaccounts);
        _addEulerBorrowLeafs(leafs, borrowVaults, subaccounts);

        // ========================== Fluid ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fUSDC"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fUSDT"));            
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fsUSDe")); // TODO check if this should exist

        // ========================== Fluid Dex ========================== // TODO find + fix addresses
         {
            ERC20[] memory supplyTokens = new ERC20[](1);
            supplyTokens[0] = getERC20(sourceChain, "sUSDe");

            ERC20[] memory borrowTokens = new ERC20[](2);
            borrowTokens[0] = getERC20(sourceChain, "USDT");
            borrowTokens[1] = getERC20(sourceChain, "USDC");

            uint256 dexType = 4000;

            _addFluidDexLeafs(
                leafs, getAddress(sourceChain, "sUSDe_DEX-USDC-USDT"), dexType, supplyTokens, borrowTokens, false //no native ETH leaves
            );
        }

        // ========================== King ==========================
        // TODO add redeem leaf

        // ========================== Drone Transfers ==========================
        localTokens = new ERC20[](22);
        localTokens[0] = getERC20("mainnet", "USDC");
        localTokens[1] = getERC20("mainnet", "USDT");
        localTokens[2] = getERC20("mainnet", "DAI");
        localTokens[3] = getERC20("mainnet", "WETH");
        localTokens[4] = getERC20("mainnet", "WEETH");
        localTokens[5] = getERC20("mainnet", "USD0");
        localTokens[6] = getERC20("mainnet", "USD0_plus");
        localTokens[7] = getERC20("mainnet", "deUSD");
        localTokens[8] = getERC20("mainnet", "sdeUSD");
        localTokens[9] = getERC20("mainnet", "USDE");
        localTokens[10] = getERC20("mainnet", "SUSDE");
        localTokens[11] = getERC20("mainnet", "USDS");
        localTokens[12] = getERC20("mainnet", "sUSDs");
        localTokens[13] = getERC20("mainnet", "sDAI");
        localTokens[14] = getERC20("mainnet", "lvlUSD");
        localTokens[15] = getERC20("mainnet", "slvlUSD");
        localTokens[16] = getERC20("mainnet", "pendle_lvlUSD_05_28_25_sy");
        localTokens[17] = getERC20("mainnet", "pendle_lvlUSD_05_28_25_pt");
        localTokens[18] = getERC20("mainnet", "pendle_lvlUSD_05_28_25_yt");
        localTokens[19] = getERC20("mainnet", "pendle_slvlUSD_05_28_25_sy");
        localTokens[20] = getERC20("mainnet", "pendle_slvlUSD_05_28_25_pt");
        localTokens[21] = getERC20("mainnet", "pendle_slvlUSD_05_28_25_yt");
        localTokens[22] = getERC20("mainnet", "syrupUSDC");
        localTokens[23] = getERC20("mainnet", "syrupUSDT");
        localTokens[24] = getERC20("mainnet", "wstUSR");
        localTokens[25] = getERC20("mainnet", "ETHFI");
        localTokens[26] = getERC20("mainnet", "USR");
        localTokens[27] = getERC20("mainnet", "GHO");
        localTokens[28] = getERC20("mainnet", "ELX");
        localTokens[29] = getERC20("mainnet", "KING");
        localTokens[30] = getERC20("mainnet", "EIGEN");
        localTokens[31] = getERC20("mainnet", "pendle_sUSDe_03_26_25_sy");
        localTokens[32] = getERC20("mainnet", "pendle_sUSDe_03_26_25_pt");
        localTokens[33] = getERC20("mainnet", "pendle_sUSDe_03_26_25_yt");
        localTokens[34] = getERC20("mainnet", "pendle_sUSDe_05_28_25_sy");
        localTokens[35] = getERC20("mainnet", "pendle_sUSDe_05_28_25_pt");
        localTokens[36] = getERC20("mainnet", "pendle_sUSDe_05_28_25_yt");
        localTokens[37] = getERC20("mainnet", "pendle_syrupUSDC_04_23_25_sy");
        localTokens[38] = getERC20("mainnet", "pendle_syrupUSDC_04_23_25_pt");
        localTokens[39] = getERC20("mainnet", "pendle_syrupUSDC_04_23_25_yt");

        // TODO, complete determine if all wrapped tokens should be included

        _addLeafsForDroneTransfers(leafs, drone, localTokens);

        // ========================== Drone Functions ==========================
        _createDroneLeafs(leafs, drone, startIndex, leafIndex + 1);

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/UltraUsdStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
