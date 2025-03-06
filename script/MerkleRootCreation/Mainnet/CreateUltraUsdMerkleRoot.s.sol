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
contract CreateUltraUsdMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xbc0f3B23930fff9f4894914bD745ABAbA9588265;
    address public rawDataDecoderAndSanitizer = 0xD03d4De8E8b47550fCF93898c7524E9e9A8aEc2D;
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

        ManageLeaf[] memory leafs = new ManageLeaf[](2048);

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

        // ========================== MorphoBlue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));
        // ========================== Usual ==========================
        _addUsualMoneyLeafs(leafs);

        // ========================== Elixir ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sdeUSD")));

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

        _addLeafsFor1InchGeneralSwapping(leafs, oneInchAssets, oneInchKind);

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

        // ========================== Resolv ==========================
        _addAllResolvLeafs(leafs);

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

        _addLeafsForDroneTransfers(leafs, drone, localTokens);

        // ========================== Drone Leafs ==========================

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

        // ========================== MorphoBlue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));

        // ========================== Usual ==========================
        _addUsualMoneyLeafs(leafs);

        // ========================== Elixir ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sdeUSD")));

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

        // ========================== 1inch ==========================
        /*
         *
         */
        _addLeafsFor1InchGeneralSwapping(leafs, oneInchAssets, oneInchKind);

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

        // ========================== Resolv ==========================
        _addAllResolvLeafs(leafs);

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

        _addLeafsForDroneTransfers(leafs, drone, localTokens);

        // ========================== Drone Functions ==========================
        _createDroneLeafs(leafs, drone, startIndex, leafIndex + 1);

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/UltraUsdStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
