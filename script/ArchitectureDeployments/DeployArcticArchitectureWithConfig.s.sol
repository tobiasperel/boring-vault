// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault, Auth} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {TellerWithRemediation} from "src/base/Roles/TellerWithRemediation.sol";
import {
    ChainlinkCCIPTeller,
    CrossChainTellerWithGenericBridge
} from "src/base/Roles/CrossChain/Bridges/CCIP/ChainlinkCCIPTeller.sol";
import {LayerZeroTeller} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {AccountantWithRateProviders, IRateProvider} from "src/base/Roles/AccountantWithRateProviders.sol";
import {AccountantWithFixedRate} from "src/base/Roles/AccountantWithFixedRate.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {ArcticArchitectureLens} from "src/helper/ArcticArchitectureLens.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol";
import {DelayedWithdraw} from "src/base/Roles/DelayedWithdraw.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";
import {ChainValues} from "test/resources/ChainValues.sol";
import {PaymentSplitter} from "src/helper/PaymentSplitter.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringOnChainQueueWithTracking} from "src/base/Roles/BoringQueue/BoringOnChainQueueWithTracking.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {Pauser} from "src/base/Roles/Pauser.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {console} from "@forge-std/Test.sol";

/**
 *  source .env && forge script script/DeployArcticArchitectureWithConfig.s.sol:DeployArcticArchitectureWithConfigScript --sig "run(string)" config.json --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 *  source .env && forge script script/ArchitectureDeployments/DeployArcticArchitectureWithConfig.s.sol:DeployArcticArchitectureWithConfigScript --sig "run(string)" "config.json"
 */
contract DeployArcticArchitectureWithConfigScript is Script, ChainValues {
    struct AddressOrName {
        address address_;
        string name;
    }

    struct AccountantDeploymentParameters {
        uint16 allowedExchangeRateChangeLower;
        uint16 allowedExchangeRateChangeUpper;
        AddressOrName base;
        uint24 minimumUpateDelayInSeconds;
        uint16 performanceFee;
        uint16 platformFee;
        uint96 startingExchangeRate;
    }

    struct WithdrawAsset {
        ERC20 asset;
        uint32 withdrawDelay;
        uint32 completionWindow;
        uint16 withdrawFee;
        uint16 maxLoss;
    }

    struct PaymentSplitterSplit {
        uint96 percent;
        address to;
    }

    struct TimelockParameters {
        address[] executors;
        uint256 minDelay;
        address[] proposers;
    }

    struct DepositAsset {
        AddressOrName addressOrName;
        bool allowDeposits;
        bool allowWithdraws;
        bool isPeggedToBase;
        address rateProvider;
        uint16 sharePremium;
    }

    WithdrawAsset[] public withdrawAssets;

    // Contracts to deploy
    ArcticArchitectureLens public lens;
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    RolesAuthority public rolesAuthority;
    address public rawDataDecoderAndSanitizer;
    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    DelayedWithdraw public delayedWithdrawer;
    PaymentSplitter public paymentSplitter;
    BoringOnChainQueue public queue;
    BoringSolver public queueSolver;
    Pauser public pauser;
    TimelockController public timelock;

    // Roles
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant MINTER_ROLE = 2;
    uint8 public constant BURNER_ROLE = 3;
    uint8 public constant MANAGER_INTERNAL_ROLE = 4;
    uint8 public constant PAUSER_ROLE = 5;
    uint8 public constant SOLVER_ROLE = 12;
    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant MULTISIG_ROLE = 9;
    uint8 public constant STRATEGIST_MULTISIG_ROLE = 10;
    uint8 public constant STRATEGIST_ROLE = 7;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 11;
    uint8 public constant GENERIC_PAUSER_ROLE = 14;
    uint8 public constant GENERIC_UNPAUSER_ROLE = 15;
    uint8 public constant PAUSE_ALL_ROLE = 16;
    uint8 public constant UNPAUSE_ALL_ROLE = 17;
    uint8 public constant SENDER_PAUSER_ROLE = 18;
    uint8 public constant SENDER_UNPAUSER_ROLE = 19;
    uint8 public constant CAN_SOLVE_ROLE = 31;
    uint8 public constant ONLY_QUEUE_ROLE = 32;

    uint8 public droneCount;
    address[] public droneAddresses;

    bytes public boringCreationCode;

    string finalJson;
    string coreOutput;
    string depositAssetConfigurationOutput;
    string withdrawAssetConfigurationOutput;
    string accountantConfigurationOutput;
    string depositConfigurationOutput;
    string droneOutput;

    enum AccountantKind {
        VariableRate,
        FixedRate
    }

    AccountantKind internal accountantKind;

    enum TellerKind {
        Teller,
        TellerWithRemediation,
        TellerWithCcip,
        TellerWithLayerZero
    }

    TellerKind internal tellerKind;

    bool internal allowPublicDeposits;
    bool internal allowPublicWithdrawals;
    bool internal allowPublicSelfWithdraws;
    bool internal setupDepositAssets;
    bool internal setupWithdrawAssets;
    bool internal finishSetup;
    bool internal setupTestUser;
    bool internal saveDeploymentDetails;

    address internal baseAsset;

    struct Tx {
        address target;
        bytes data;
        uint256 value;
    }

    Tx[] internal txs;

    function getTxs() public view returns (Tx[] memory) {
        return txs;
    }

    function _addTx(address target, bytes memory data, uint256 value) internal {
        txs.push(Tx(target, data, value));
    }

    function _getAddressAndIfDeployed(string memory name) internal view returns (address, bool) {
        address deployedAt = deployer.getAddress(name);
        uint256 size;
        assembly {
            size := extcodesize(deployedAt)
        }
        return (deployedAt, size > 0);
    }

    function _getAddressIfDeployed(string memory name) internal view returns (address) {
        address deployedAt = deployer.getAddress(name);
        uint256 size;
        assembly {
            size := extcodesize(deployedAt)
        }
        if (size > 0) {
            return deployedAt;
        }
        return address(0);
    }

    bool internal deployContracts;
    Deployer internal deployer;

    error KeyNotFound(string key);
    error DeployError(string message);

    uint256 internal privateKey;

    string internal rawJson;
    string internal sourceChain;
    // 0 - off, 1 - error, 2 - warn, 3 - info, 4 - debug
    uint256 internal logLevel;

    address internal deploymentOwner;

    string internal rolesAuthorityDeploymentName;
    string internal lensDeploymentName;
    string internal boringVaultDeploymentName;
    string internal managerDeploymentName;
    string internal accountantDeploymentName;
    string internal tellerDeploymentName;
    string internal queueDeploymentName;
    string internal queueSolverDeploymentName;
    string internal droneBaseDeploymentName;
    string internal pauserDeploymentName;
    string internal timelockDeploymentName;

    function _log(string memory message, uint256 level) internal view {
        if (logLevel >= level) {
            if (level == 1) {
                revert DeployError(message);
            } else if (level == 2) {
                message = string.concat("[WARN]: ", message);
            } else if (level == 3) {
                message = string.concat("[INFO]: ", message);
            } else if (level == 4) {
                message = string.concat("[DEBUG]: ", message);
            }
            console.log(message);
        }
    }

    function run(string memory configurationFileName) external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        {
            string memory root = vm.projectRoot();
            string memory configurationPath = string.concat(root, "/deployments/configurations/", configurationFileName);
            rawJson = vm.readFile(configurationPath);
        }
        if (vm.keyExists(rawJson, ".deploymentParameters.logLevel")) {
            logLevel = vm.parseJsonUint(rawJson, ".deploymentParameters.logLevel");
            _log("Log level found in configuration file.", 3);
        } else {
            revert KeyNotFound(".deploymentParameters.logLevel");
        }
        if (vm.keyExists(rawJson, ".deploymentParameters.privateKeyEnvName")) {
            privateKey = vm.envUint(vm.parseJsonString(rawJson, ".deploymentParameters.privateKeyEnvName"));
            _log("Private key found in configuration file.", 3);
        } else {
            revert KeyNotFound(".deploymentParameters.privateKeyEnvName");
        }

        if (vm.keyExists(rawJson, ".deploymentParameters.chainName")) {
            string memory chainName = vm.parseJsonString(rawJson, ".deploymentParameters.chainName");
            vm.createSelectFork(chainName);
            sourceChain = chainName;
            _log(string.concat("Forked to chain: ", chainName), 3);
        } else {
            revert KeyNotFound(".deploymentParameters.chainName");
        }

        if (vm.keyExists(rawJson, ".deploymentParameters.deploymentOwnerAddressOrName")) {
            bytes memory addressOrNameRaw = vm.parseJson(rawJson, ".deploymentParameters.deploymentOwnerAddressOrName");
            AddressOrName memory addressOrName = abi.decode(addressOrNameRaw, (AddressOrName));
            deploymentOwner = addressOrName.address_ == address(0)
                ? getAddress(sourceChain, addressOrName.name)
                : addressOrName.address_;
            _log("Deployment owner found in configuration file.", 3);
        } else {
            revert KeyNotFound(".deploymentParameters.deploymentOwnerAddressOrName");
        }

        if (vm.keyExists(rawJson, ".deploymentParameters.deployContracts")) {
            deployContracts = vm.parseJsonBool(rawJson, ".deploymentParameters.deployContracts");
            _log("Deploy contracts found in configuration file.", 3);
        } else {
            // Don't error if deployContracts is not set, as it defaults to false.
            _log("Deploy contracts not set in configuration file, defaulting to false.", 2);
        }

        rolesAuthorityDeploymentName =
            vm.parseJsonString(rawJson, ".rolesAuthorityConfiguration.rolesAuthorityDeploymentName");
        lensDeploymentName = vm.parseJsonString(rawJson, ".lensConfiguration.lensDeploymentName");
        boringVaultDeploymentName = vm.parseJsonString(rawJson, ".boringVaultConfiguration.boringVaultDeploymentName");
        managerDeploymentName = vm.parseJsonString(rawJson, ".managerConfiguration.managerDeploymentName");
        accountantDeploymentName = vm.parseJsonString(rawJson, ".accountantConfiguration.accountantDeploymentName");
        tellerDeploymentName = vm.parseJsonString(rawJson, ".tellerConfiguration.tellerDeploymentName");
        queueDeploymentName = vm.parseJsonString(rawJson, ".boringQueueConfiguration.boringQueueDeploymentName");
        queueSolverDeploymentName = vm.parseJsonString(rawJson, ".boringQueueConfiguration.boringQueueSolverName");
        pauserDeploymentName = vm.parseJsonString(rawJson, ".pauserConfiguration.pauserDeploymentName");
        timelockDeploymentName = vm.parseJsonString(rawJson, ".timelockConfiguration.timelockDeploymentName");
        if (deployContracts) {
            // Get Deployer address from configuration file.
            bytes memory addressOrNameRaw = vm.parseJson(rawJson, ".deploymentParameters.deployerContractAddressOrName");
            AddressOrName memory addressOrName = abi.decode(addressOrNameRaw, (AddressOrName));
            deployer = addressOrName.address_ == address(0)
                ? Deployer(getAddress(sourceChain, addressOrName.name))
                : Deployer(addressOrName.address_);
            address deployedAddress;
            bool isDeployed;

            (deployedAddress, isDeployed) = _getAddressAndIfDeployed(rolesAuthorityDeploymentName);
            rolesAuthority = RolesAuthority(deployedAddress);
            if (!isDeployed) {
                creationCode = type(RolesAuthority).creationCode;
                constructorArgs = abi.encode(deploymentOwner, Authority(address(0)));
                _addTx(
                    address(deployer),
                    abi.encodeWithSelector(
                        deployer.deployContract.selector, rolesAuthorityDeploymentName, creationCode, constructorArgs, 0
                    ),
                    uint256(0)
                );
                _log("Roles authority deployment TX added", 3);
            }

            (deployedAddress, isDeployed) = _getAddressAndIfDeployed(lensDeploymentName);
            lens = ArcticArchitectureLens(deployedAddress);
            if (!isDeployed) {
                creationCode = type(ArcticArchitectureLens).creationCode;
                constructorArgs = hex"";
                _addTx(
                    address(deployer),
                    abi.encodeWithSelector(
                        deployer.deployContract.selector, lensDeploymentName, creationCode, constructorArgs, 0
                    ),
                    uint256(0)
                );
                _log("Lens deployment TX added", 3);
            }

            (deployedAddress, isDeployed) = _getAddressAndIfDeployed(boringVaultDeploymentName);
            boringVault = BoringVault(payable(deployedAddress));
            if (!isDeployed) {
                creationCode = type(BoringVault).creationCode;
                // Get boringVaultName, boringVaultSymbol, and boringVaultDecimals from configuration file.
                string memory boringVaultName = vm.parseJsonString(rawJson, ".boringVaultConfiguration.boringVaultName");
                string memory boringVaultSymbol =
                    vm.parseJsonString(rawJson, ".boringVaultConfiguration.boringVaultSymbol");
                uint256 boringVaultDecimals = vm.parseJsonUint(rawJson, ".boringVaultConfiguration.boringVaultDecimals");
                constructorArgs = abi.encode(deploymentOwner, boringVaultName, boringVaultSymbol, boringVaultDecimals);
                _addTx(
                    address(deployer),
                    abi.encodeWithSelector(
                        deployer.deployContract.selector, boringVaultDeploymentName, creationCode, constructorArgs, 0
                    ),
                    uint256(0)
                );
                _log("Boring vault deployment TX added", 3);
                _log(string.concat("Boring vault name: ", boringVaultName), 4);
                _log(string.concat("Boring vault symbol: ", boringVaultSymbol), 4);
                _log(string.concat("Boring vault decimals: ", vm.toString(boringVaultDecimals)), 4);
            }

            (deployedAddress, isDeployed) = _getAddressAndIfDeployed(managerDeploymentName);
            manager = ManagerWithMerkleVerification(deployedAddress);
            if (!isDeployed) {
                // Read balancerVault from configuration file.
                bytes memory balancerVaultRaw =
                    vm.parseJson(rawJson, ".managerConfiguration.balancerVaultAddressOrName");
                AddressOrName memory balancerVault = abi.decode(balancerVaultRaw, (AddressOrName));
                address balancerVaultAddress = balancerVault.address_ == address(0)
                    ? getAddress(sourceChain, balancerVault.name)
                    : balancerVault.address_;
                creationCode = type(ManagerWithMerkleVerification).creationCode;
                constructorArgs = abi.encode(deploymentOwner, address(boringVault), balancerVaultAddress);
                _addTx(
                    address(deployer),
                    abi.encodeWithSelector(
                        deployer.deployContract.selector, managerDeploymentName, creationCode, constructorArgs, 0
                    ),
                    uint256(0)
                );
                _log("Manager deployment TX added", 3);
                _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
                _log(string.concat("Balancer vault address: ", vm.toString(balancerVaultAddress)), 4);
            }

            (deployedAddress, isDeployed) = _getAddressAndIfDeployed(accountantDeploymentName);
            accountant = AccountantWithRateProviders(deployedAddress);
            if (!isDeployed) {
                // Figure out the payout address.
                address payoutAddress = vm.parseJsonAddress(
                    rawJson, ".accountantConfiguration.accountantParameters.payoutConfiguration.payoutTo"
                );
                if (payoutAddress == address(0)) {
                    // Need to deploy a payment splitter.
                    string memory paymentSplitterDeploymentName = vm.parseJsonString(
                        rawJson,
                        ".accountantConfiguration.accountantParameters.payoutConfiguration.optionalPaymentSplitterName"
                    );
                    (payoutAddress, isDeployed) = _getAddressAndIfDeployed(paymentSplitterDeploymentName);
                    paymentSplitter = PaymentSplitter(payoutAddress);
                    if (!isDeployed) {
                        creationCode = type(PaymentSplitter).creationCode;
                        // Read the splits from the configuration file.
                        bytes memory splitsRaw = vm.parseJson(
                            rawJson, ".accountantConfiguration.accountantParameters.payoutConfiguration.splits"
                        );
                        _log("Payment splitter deployment TX added", 3);
                        PaymentSplitterSplit[] memory splits = abi.decode(splitsRaw, (PaymentSplitterSplit[]));
                        uint256 totalPercent = 0;
                        for (uint256 i = 0; i < splits.length; i++) {
                            totalPercent += splits[i].percent;
                            _log(
                                string.concat(
                                    "Split: {to: ",
                                    vm.toString(splits[i].to),
                                    " percent: ",
                                    vm.toString(splits[i].percent),
                                    "}"
                                ),
                                4
                            );
                        }
                        _log(string.concat("Total percent: ", vm.toString(totalPercent)), 4);
                        constructorArgs = abi.encode(deploymentOwner, totalPercent, splits);
                        _addTx(
                            address(deployer),
                            abi.encodeWithSelector(
                                deployer.deployContract.selector,
                                paymentSplitterDeploymentName,
                                creationCode,
                                constructorArgs,
                                0
                            ),
                            uint256(0)
                        );
                    }
                }
                // Figure out what kind of accountant to deploy.
                bool variableRate =
                    vm.parseJsonBool(rawJson, ".accountantConfiguration.accountantParameters.kind.variableRate");
                bool fixedRate =
                    vm.parseJsonBool(rawJson, ".accountantConfiguration.accountantParameters.kind.fixedRate");
                if (variableRate && fixedRate) {
                    _log("Invalid accountant kind", 1);
                }
                // Get AccountantDeploymentParameters from configuration file.
                bytes memory accountantDeploymentParametersRaw = vm.parseJson(
                    rawJson, ".accountantConfiguration.accountantParameters.accountantDeploymentParameters"
                );
                AccountantDeploymentParameters memory accountantDeploymentParameters =
                    abi.decode(accountantDeploymentParametersRaw, (AccountantDeploymentParameters));
                baseAsset = accountantDeploymentParameters.base.address_ == address(0)
                    ? getAddress(sourceChain, accountantDeploymentParameters.base.name)
                    : accountantDeploymentParameters.base.address_;
                constructorArgs = abi.encode(
                    deploymentOwner,
                    address(boringVault),
                    payoutAddress,
                    accountantDeploymentParameters.startingExchangeRate,
                    base,
                    accountantDeploymentParameters.allowedExchangeRateChangeUpper,
                    accountantDeploymentParameters.allowedExchangeRateChangeLower,
                    accountantDeploymentParameters.minimumUpateDelayInSeconds,
                    accountantDeploymentParameters.platformFee,
                    accountantDeploymentParameters.performanceFee
                );
                if (variableRate) {
                    // Deploy VariableRateAccountant.
                    creationCode = type(AccountantWithRateProviders).creationCode;
                    accountantKind = AccountantKind.VariableRate;
                    _log("Accountant with rate providers deployment TX added", 3);
                } else if (fixedRate) {
                    // Deploy FixedRateAccountant.
                    creationCode = type(AccountantWithFixedRate).creationCode;
                    accountantKind = AccountantKind.FixedRate;
                    _log("Fixed rate accountant deployment TX added", 3);
                } else {
                    _log("Accountant kind not set in configuration file", 1);
                }
                _addTx(
                    address(deployer),
                    abi.encodeWithSelector(
                        deployer.deployContract.selector, accountantDeploymentName, creationCode, constructorArgs, 0
                    ),
                    uint256(0)
                );
                _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
                _log(string.concat("Payout address: ", vm.toString(payoutAddress)), 4);
                _log(
                    string.concat(
                        "Starting exchange rate: ", vm.toString(accountantDeploymentParameters.startingExchangeRate)
                    ),
                    4
                );
                _log(string.concat("Base address: ", vm.toString(baseAsset)), 4);
                _log(
                    string.concat(
                        "Allowed exchange rate change upper: ",
                        vm.toString(accountantDeploymentParameters.allowedExchangeRateChangeUpper)
                    ),
                    4
                );
                _log(
                    string.concat(
                        "Allowed exchange rate change lower: ",
                        vm.toString(accountantDeploymentParameters.allowedExchangeRateChangeLower)
                    ),
                    4
                );
                _log(
                    string.concat(
                        "Minimum update delay in seconds: ",
                        vm.toString(accountantDeploymentParameters.minimumUpateDelayInSeconds)
                    ),
                    4
                );
                _log(string.concat("Platform fee: ", vm.toString(accountantDeploymentParameters.platformFee)), 4);
                _log(string.concat("Performance fee: ", vm.toString(accountantDeploymentParameters.performanceFee)), 4);
            }

            (deployedAddress, isDeployed) = _getAddressAndIfDeployed(tellerDeploymentName);
            teller = TellerWithMultiAssetSupport(deployedAddress);
            if (!isDeployed) {
                // Get native wrapper address from configuration file.
                address nativeWrapperAddress = _handleAddressOrName(".deploymentParameters.nativeWrapperAddressOrName");
                // Figure out what kind of teller to deploy.
                bool tellerKindSet;
                bool normalTeller = vm.parseJsonBool(rawJson, ".tellerConfiguration.tellerParameters.kind.teller");
                if (normalTeller) {
                    creationCode = type(TellerWithMultiAssetSupport).creationCode;
                    tellerKind = TellerKind.Teller;
                    constructorArgs =
                        abi.encode(deploymentOwner, address(boringVault), address(accountant), nativeWrapperAddress);
                    tellerKindSet = true;
                    _log("Normal Teller deployment TX added", 3);
                    _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
                    _log(string.concat("Accountant address: ", vm.toString(address(accountant))), 4);
                    _log(string.concat("Native wrapper address: ", vm.toString(nativeWrapperAddress)), 4);
                }
                bool tellerWithRemediation =
                    vm.parseJsonBool(rawJson, ".tellerConfiguration.tellerParameters.kind.tellerWithRemediation");
                if (tellerWithRemediation) {
                    if (tellerKindSet) {
                        _log("Teller kind already set", 1);
                    }
                    creationCode = type(TellerWithRemediation).creationCode;
                    tellerKind = TellerKind.TellerWithRemediation;
                    constructorArgs =
                        abi.encode(deploymentOwner, address(boringVault), address(accountant), nativeWrapperAddress);
                    tellerKindSet = true;
                    _log("Teller with remediation deployment TX added", 3);
                    _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
                    _log(string.concat("Accountant address: ", vm.toString(address(accountant))), 4);
                    _log(string.concat("Native wrapper address: ", vm.toString(nativeWrapperAddress)), 4);
                }
                bool tellerWithCcip =
                    vm.parseJsonBool(rawJson, ".tellerConfiguration.tellerParameters.kind.tellerWithCcip");
                if (tellerWithCcip) {
                    if (tellerKindSet) {
                        _log("Teller kind already set", 1);
                    }
                    creationCode = type(ChainlinkCCIPTeller).creationCode;
                    tellerKind = TellerKind.TellerWithCcip;
                    // Get other config params from configuration file.
                    address tellerWithCcipRouterAddress =
                        _handleAddressOrName(".tellerConfiguration.tellerParameters.ccip.routerAddressOrName");

                    constructorArgs = abi.encode(
                        deploymentOwner,
                        address(boringVault),
                        address(accountant),
                        nativeWrapperAddress,
                        tellerWithCcipRouterAddress
                    );
                    tellerKindSet = true;
                    _log("Teller with CCIP deployment TX added", 3);
                    _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
                    _log(string.concat("Accountant address: ", vm.toString(address(accountant))), 4);
                    _log(string.concat("Native wrapper address: ", vm.toString(nativeWrapperAddress)), 4);
                    _log(string.concat("CCIP router address: ", vm.toString(tellerWithCcipRouterAddress)), 4);
                }
                bool tellerWithLayerZero =
                    vm.parseJsonBool(rawJson, ".tellerConfiguration.tellerParameters.kind.tellerWithLayerZero");
                if (tellerWithLayerZero) {
                    if (tellerKindSet) {
                        _log("Teller kind already set", 1);
                    }
                    creationCode = type(LayerZeroTeller).creationCode;
                    tellerKind = TellerKind.TellerWithLayerZero;
                    // Read the endpoint and lztoken from the configuration file.
                    address layerZeroEndpointAddress =
                        _handleAddressOrName(".tellerConfiguration.tellerParameters.layerZero.endpointAddressOrName");
                    address layerZeroTokenAddress =
                        _handleAddressOrName(".tellerConfiguration.tellerParameters.layerZero.lzTokenAddressOrName");
                    constructorArgs = abi.encode(
                        deploymentOwner,
                        address(boringVault),
                        address(accountant),
                        nativeWrapperAddress,
                        layerZeroEndpointAddress,
                        deploymentOwner,
                        layerZeroTokenAddress
                    );
                    tellerKindSet = true;
                    _log("Teller with LayerZero deployment TX added", 3);
                    _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
                    _log(string.concat("Accountant address: ", vm.toString(address(accountant))), 4);
                    _log(string.concat("Native wrapper address: ", vm.toString(nativeWrapperAddress)), 4);
                    _log(string.concat("LayerZero endpoint address: ", vm.toString(layerZeroEndpointAddress)), 4);
                    _log(string.concat("LayerZero token address: ", vm.toString(layerZeroTokenAddress)), 4);
                }

                _addTx(
                    address(deployer),
                    abi.encodeWithSelector(
                        deployer.deployContract.selector, tellerDeploymentName, creationCode, constructorArgs, 0
                    ),
                    uint256(0)
                );
            }

            (deployedAddress, isDeployed) = _getAddressAndIfDeployed(queueDeploymentName);
            queue = BoringOnChainQueue(deployedAddress);
            if (!isDeployed) {
                // Read configuration to determine kind.
                bool boringQueue =
                    vm.parseJsonBool(rawJson, ".boringQueueConfiguration.queueParameters.kind.boringQueue");
                bool boringQueueWithTracking =
                    vm.parseJsonBool(rawJson, ".boringQueueConfiguration.queueParameters.kind.boringQueueWithTracking");
                if (boringQueue && boringQueueWithTracking) {
                    _log("Invalid boring queue kind", 1);
                } else if (boringQueue) {
                    constructorArgs = abi.encode(deploymentOwner, address(0), address(boringVault), address(accountant));
                    creationCode = type(BoringOnChainQueue).creationCode;
                    _log("Boring on chain queue deployment TX added", 3);
                } else if (boringQueueWithTracking) {
                    constructorArgs =
                        abi.encode(deploymentOwner, address(0), address(boringVault), address(accountant), false);
                    creationCode = type(BoringOnChainQueueWithTracking).creationCode;
                    _log("Boring on chain queue with tracking deployment TX added", 3);
                }
                _log(string.concat("Boring vault address: ", vm.toString(address(boringVault))), 4);
                _log(string.concat("Accountant address: ", vm.toString(address(accountant))), 4);
                _addTx(
                    address(deployer),
                    abi.encodeWithSelector(
                        deployer.deployContract.selector, queueDeploymentName, creationCode, constructorArgs, 0
                    ),
                    uint256(0)
                );
            }

            (deployedAddress, isDeployed) = _getAddressAndIfDeployed(queueSolverDeploymentName);
            queueSolver = BoringSolver(deployedAddress);
            if (!isDeployed) {
                creationCode = type(BoringSolver).creationCode;
                constructorArgs = abi.encode(deploymentOwner, address(0), address(queue));
                _log("Boring solver deployment TX added", 3);
                _log(string.concat("Boring queue address: ", vm.toString(address(queue))), 4);
                _addTx(
                    address(deployer),
                    abi.encodeWithSelector(
                        deployer.deployContract.selector, queueSolverDeploymentName, creationCode, constructorArgs, 0
                    ),
                    uint256(0)
                );
            }

            (deployedAddress, isDeployed) = _getAddressAndIfDeployed(pauserDeploymentName);
            // Read config to determine if pauser should be deployed.
            bool shouldDeployPauser = vm.parseJsonBool(rawJson, ".pauserConfiguration.shouldDeploy");
            if (shouldDeployPauser) {
                pauser = Pauser(deployedAddress);
                if (!isDeployed) {
                    // Create pausables array.
                    address[] memory pausables = new address[](4);
                    pausables[0] = address(teller);
                    pausables[1] = address(queue);
                    pausables[2] = address(accountant);
                    pausables[3] = address(manager);
                    creationCode = type(Pauser).creationCode;
                    constructorArgs = abi.encode(deploymentOwner, address(0), pausables);

                    _log("Pauser deployment TX added", 3);
                    _addTx(
                        address(deployer),
                        abi.encodeWithSelector(
                            deployer.deployContract.selector, pauserDeploymentName, creationCode, constructorArgs, 0
                        ),
                        uint256(0)
                    );
                }
            }

            (deployedAddress, isDeployed) = _getAddressAndIfDeployed(timelockDeploymentName);
            // Read config to determine if timelock should be deployed.
            bool shouldDeployTimelock = vm.parseJsonBool(rawJson, ".timelockConfiguration.shouldDeploy");
            if (shouldDeployTimelock) {
                timelock = TimelockController(payable(deployedAddress));
                if (!isDeployed) {
                    creationCode = type(TimelockController).creationCode;
                    // Read timelock parameters from configuration file.
                    bytes memory timelockParametersRaw =
                        vm.parseJson(rawJson, ".timelockConfiguration.timelockParameters");
                    TimelockParameters memory timelockParameters =
                        abi.decode(timelockParametersRaw, (TimelockParameters));
                    constructorArgs = abi.encode(
                        deploymentOwner,
                        timelockParameters.minDelay,
                        timelockParameters.proposers,
                        timelockParameters.executors
                    );
                    _log("Timelock deployment TX added", 3);
                    _log(string.concat("Min delay: ", vm.toString(timelockParameters.minDelay)), 4);
                    // TODO log the proposers and executors.
                    _addTx(
                        address(deployer),
                        abi.encodeWithSelector(
                            deployer.deployContract.selector, timelockDeploymentName, creationCode, constructorArgs, 0
                        ),
                        uint256(0)
                    );
                }
            }

            // TODO handle drone deployment.
        } else {
            rolesAuthority = RolesAuthority(_getAddressIfDeployed(rolesAuthorityDeploymentName));
            lens = ArcticArchitectureLens(_getAddressIfDeployed(lensDeploymentName));
            boringVault = BoringVault(payable(_getAddressIfDeployed(boringVaultDeploymentName)));
            manager = ManagerWithMerkleVerification(_getAddressIfDeployed(managerDeploymentName));
            accountant = AccountantWithRateProviders(_getAddressIfDeployed(accountantDeploymentName));
            teller = TellerWithMultiAssetSupport(payable(_getAddressIfDeployed(tellerDeploymentName)));
            queue = BoringOnChainQueue(_getAddressIfDeployed(queueDeploymentName));
            queueSolver = BoringSolver(_getAddressIfDeployed(queueSolverDeploymentName));
            // Check if pauser should be deployed.
            bool shouldDeployPauser = vm.parseJsonBool(rawJson, ".pauserConfiguration.shouldDeploy");
            if (shouldDeployPauser) {
                pauser = Pauser(_getAddressIfDeployed(pauserDeploymentName));
            }
            bool shouldDeployTimelock = vm.parseJsonBool(rawJson, ".timelockConfiguration.shouldDeploy");
            if (shouldDeployTimelock) {
                timelock = TimelockController(payable(_getAddressIfDeployed(timelockDeploymentName)));
            }
        }

        // Check if we are setting up roles.
        bool setupRoles = vm.parseJsonBool(rawJson, ".deploymentParameters.setupRoles");
        if (setupRoles) {
            // Setup roles for boring vault.
            _addRoleCapabilityIfNotPresent(
                MANAGER_ROLE, address(boringVault), bytes4(abi.encodeWithSignature("manage(address,bytes,uint256)"))
            );
            _addRoleCapabilityIfNotPresent(
                MANAGER_ROLE,
                address(boringVault),
                bytes4(abi.encodeWithSignature("manage(address[],bytes[],uint256[])"))
            );
            _addRoleCapabilityIfNotPresent(MINTER_ROLE, address(boringVault), BoringVault.enter.selector);
            _addRoleCapabilityIfNotPresent(BURNER_ROLE, address(boringVault), BoringVault.exit.selector);
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(boringVault), BoringVault.setBeforeTransferHook.selector);

            // Setup roles for manager.
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector
            );
            _addRoleCapabilityIfNotPresent(
                MANAGER_INTERNAL_ROLE,
                address(manager),
                ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector
            );
            _addRoleCapabilityIfNotPresent(PAUSER_ROLE, address(manager), ManagerWithMerkleVerification.pause.selector);
            _addRoleCapabilityIfNotPresent(
                PAUSER_ROLE, address(manager), ManagerWithMerkleVerification.unpause.selector
            );
            _addRoleCapabilityIfNotPresent(
                STRATEGIST_ROLE,
                address(manager),
                ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector
            );

            // Setup roles for accountant.
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(accountant), AccountantWithRateProviders.setRateProviderData.selector
            );
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateDelay.selector
            );
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateUpper.selector
            );
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateLower.selector
            );
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(accountant), AccountantWithRateProviders.updatePlatformFee.selector
            );
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(accountant), AccountantWithRateProviders.updatePerformanceFee.selector
            );
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(accountant), AccountantWithRateProviders.updatePayoutAddress.selector
            );
            if (accountantKind == AccountantKind.VariableRate) {
                _addRoleCapabilityIfNotPresent(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.resetHighwaterMark.selector
                );
            } else if (accountantKind == AccountantKind.FixedRate) {
                _addRoleCapabilityIfNotPresent(
                    OWNER_ROLE, address(accountant), AccountantWithFixedRate.setYieldDistributor.selector
                );
            }
            _addRoleCapabilityIfNotPresent(PAUSER_ROLE, address(accountant), AccountantWithRateProviders.pause.selector);
            _addRoleCapabilityIfNotPresent(
                PAUSER_ROLE, address(accountant), AccountantWithRateProviders.unpause.selector
            );
            _addRoleCapabilityIfNotPresent(
                UPDATE_EXCHANGE_RATE_ROLE, address(accountant), AccountantWithRateProviders.updateExchangeRate.selector
            );

            // Setup roles for teller.
            _addRoleCapabilityIfNotPresent(
                SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector
            );
            _addRoleCapabilityIfNotPresent(
                SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector
            );
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector
            );
            _addRoleCapabilityIfNotPresent(
                STRATEGIST_MULTISIG_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector
            );
            _addRoleCapabilityIfNotPresent(PAUSER_ROLE, address(teller), TellerWithMultiAssetSupport.pause.selector);
            _addRoleCapabilityIfNotPresent(PAUSER_ROLE, address(teller), TellerWithMultiAssetSupport.unpause.selector);
            _addRoleCapabilityIfNotPresent(
                OWNER_ROLE, address(teller), TellerWithMultiAssetSupport.setShareLockPeriod.selector
            );
            _addRoleCapabilityIfNotPresent(
                STRATEGIST_MULTISIG_ROLE, address(teller), TellerWithMultiAssetSupport.refundDeposit.selector
            );
            allowPublicDeposits = vm.parseJsonBool(rawJson, ".tellerConfiguration.tellerParameters.allowPublicDeposits");
            if (tellerKind == TellerKind.TellerWithCcip) {
                _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(teller), ChainlinkCCIPTeller.addChain.selector);
                _addRoleCapabilityIfNotPresent(MULTISIG_ROLE, address(teller), ChainlinkCCIPTeller.removeChain.selector);
                _addRoleCapabilityIfNotPresent(
                    OWNER_ROLE, address(teller), ChainlinkCCIPTeller.allowMessagesFromChain.selector
                );
                _addRoleCapabilityIfNotPresent(
                    OWNER_ROLE, address(teller), ChainlinkCCIPTeller.allowMessagesToChain.selector
                );
                _addRoleCapabilityIfNotPresent(
                    MULTISIG_ROLE, address(teller), ChainlinkCCIPTeller.stopMessagesFromChain.selector
                );
                _addRoleCapabilityIfNotPresent(
                    MULTISIG_ROLE, address(teller), ChainlinkCCIPTeller.stopMessagesToChain.selector
                );
                _addRoleCapabilityIfNotPresent(
                    OWNER_ROLE, address(teller), ChainlinkCCIPTeller.setChainGasLimit.selector
                );
            }
            if (tellerKind == TellerKind.TellerWithLayerZero) {
                _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(teller), LayerZeroTeller.addChain.selector);
                _addRoleCapabilityIfNotPresent(MULTISIG_ROLE, address(teller), LayerZeroTeller.removeChain.selector);
                _addRoleCapabilityIfNotPresent(
                    OWNER_ROLE, address(teller), LayerZeroTeller.allowMessagesFromChain.selector
                );
                _addRoleCapabilityIfNotPresent(
                    OWNER_ROLE, address(teller), LayerZeroTeller.allowMessagesToChain.selector
                );
                _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(teller), LayerZeroTeller.setChainGasLimit.selector);
                _addRoleCapabilityIfNotPresent(
                    MULTISIG_ROLE, address(teller), LayerZeroTeller.stopMessagesFromChain.selector
                );
                _addRoleCapabilityIfNotPresent(
                    MULTISIG_ROLE, address(teller), LayerZeroTeller.stopMessagesToChain.selector
                );
            }
            if (allowPublicDeposits) {
                _setPublicCapabilityIfNotPresent(address(teller), TellerWithMultiAssetSupport.deposit.selector);
                _setPublicCapabilityIfNotPresent(
                    address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector
                );
                if (tellerKind == TellerKind.TellerWithCcip || tellerKind == TellerKind.TellerWithLayerZero) {
                    _setPublicCapabilityIfNotPresent(
                        address(teller), CrossChainTellerWithGenericBridge.depositAndBridge.selector
                    );
                    _setPublicCapabilityIfNotPresent(
                        address(teller), CrossChainTellerWithGenericBridge.depositAndBridgeWithPermit.selector
                    );
                    _setPublicCapabilityIfNotPresent(address(teller), CrossChainTellerWithGenericBridge.bridge.selector);
                }
            }

            // Setup roles for queue.
            _addRoleCapabilityIfNotPresent(OWNER_ROLE, address(queue), BoringOnChainQueue.rescueTokens.selector);
            _addRoleCapabilityIfNotPresent(
                MULTISIG_ROLE, address(queue), BoringOnChainQueue.updateWithdrawAsset.selector
            );
            _addRoleCapabilityIfNotPresent(
                MULTISIG_ROLE, address(queue), BoringOnChainQueue.stopWithdrawsInAsset.selector
            );
            _addRoleCapabilityIfNotPresent(
                STRATEGIST_MULTISIG_ROLE, address(queue), BoringOnChainQueue.stopWithdrawsInAsset.selector
            );
            _addRoleCapabilityIfNotPresent(
                STRATEGIST_MULTISIG_ROLE, address(queue), BoringOnChainQueue.cancelUserWithdraws.selector
            );
            _addRoleCapabilityIfNotPresent(
                CAN_SOLVE_ROLE, address(queue), BoringOnChainQueue.solveOnChainWithdraws.selector
            );
            _addRoleCapabilityIfNotPresent(ONLY_QUEUE_ROLE, address(queueSolver), BoringSolver.boringSolve.selector);
            _addRoleCapabilityIfNotPresent(
                CAN_SOLVE_ROLE, address(queueSolver), BoringSolver.boringRedeemSolve.selector
            );
            _addRoleCapabilityIfNotPresent(
                CAN_SOLVE_ROLE, address(queueSolver), BoringSolver.boringRedeemMintSolve.selector
            );

            allowPublicWithdrawals =
                vm.parseJsonBool(rawJson, ".boringQueueConfiguration.queueParameters.allowPublicWithdrawals");
            if (allowPublicWithdrawals) {
                _setPublicCapabilityIfNotPresent(address(queue), BoringOnChainQueue.requestOnChainWithdraw.selector);
                _setPublicCapabilityIfNotPresent(
                    address(queue), BoringOnChainQueue.requestOnChainWithdrawWithPermit.selector
                );
                _setPublicCapabilityIfNotPresent(address(queue), BoringOnChainQueue.cancelOnChainWithdraw.selector);
                _setPublicCapabilityIfNotPresent(address(queue), BoringOnChainQueue.replaceOnChainWithdraw.selector);
            }

            allowPublicSelfWithdraws =
                vm.parseJsonBool(rawJson, ".boringQueueConfiguration.queueParameters.allowPublicSelfWithdraws");
            if (allowPublicSelfWithdraws) {
                _setPublicCapabilityIfNotPresent(address(queueSolver), BoringSolver.boringRedeemSelfSolve.selector);
                _setPublicCapabilityIfNotPresent(address(queueSolver), BoringSolver.boringRedeemMintSelfSolve.selector);
            }

            // Setup roles for pauser.
            _addRoleCapabilityIfNotPresent(PAUSE_ALL_ROLE, address(pauser), Pauser.pauseAll.selector);
            _addRoleCapabilityIfNotPresent(UNPAUSE_ALL_ROLE, address(pauser), Pauser.unpauseAll.selector);
            _addRoleCapabilityIfNotPresent(SENDER_PAUSER_ROLE, address(pauser), Pauser.senderPause.selector);
            _addRoleCapabilityIfNotPresent(SENDER_UNPAUSER_ROLE, address(pauser), Pauser.senderUnpause.selector);
            _addRoleCapabilityIfNotPresent(GENERIC_PAUSER_ROLE, address(pauser), Pauser.pauseSingle.selector);
            _addRoleCapabilityIfNotPresent(GENERIC_PAUSER_ROLE, address(pauser), Pauser.pauseMultiple.selector);
            _addRoleCapabilityIfNotPresent(GENERIC_UNPAUSER_ROLE, address(pauser), Pauser.unpauseSingle.selector);
            _addRoleCapabilityIfNotPresent(GENERIC_UNPAUSER_ROLE, address(pauser), Pauser.unpauseMultiple.selector);

            // No roles to setup for timelock.
        }

        setupDepositAssets = vm.parseJsonBool(rawJson, ".deploymentParameters.setupDepositAssets");
        if (setupDepositAssets) {
            // Read deposit assets from configuration file.
            bytes memory depositAssetsRaw = vm.parseJson(rawJson, ".depositAssets");
            DepositAsset[] memory depositAssets = abi.decode(depositAssetsRaw, (DepositAsset[]));
            for (uint256 i; i < depositAssets.length; i++) {
                DepositAsset memory depositAsset = depositAssets[i];
                // See if teller already supports it.
                ERC20 asset = depositAsset.addressOrName.address_ == address(0)
                    ? getERC20(sourceChain, depositAsset.addressOrName.name)
                    : ERC20(depositAsset.addressOrName.address_);
                // TODO instead this should just auto add the asset if the teller is not deployed.
                (bool allowDeposits,,) = teller.assetData(asset);
                if (!allowDeposits) {
                    // Check if the accountant supports it.
                    (bool isPeggedToBase, IRateProvider rateProvider) = accountant.rateProviderData(asset);
                    if (!isPeggedToBase && address(rateProvider) == address(0)) {
                        _log(
                            string.concat(
                                "Asset is not pegged to base and no rate provider given for asset: ",
                                depositAsset.addressOrName.name
                            ),
                            1
                        );
                    }
                    _log(string.concat("Setting asset data for asset: ", depositAsset.addressOrName.name), 3);
                    _addTx(
                        address(teller),
                        abi.encodeWithSelector(
                            teller.updateAssetData.selector,
                            asset,
                            depositAsset.allowDeposits,
                            depositAsset.allowWithdraws,
                            depositAsset.sharePremium
                        ),
                        0
                    );
                }
            }
        }
    }

    // TODO these helper functions should check if the rolesAuth is deployed, and if not, they should add the tx anyways.
    function _setPublicCapabilityIfNotPresent(address target, bytes4 selector) internal {
        if (!rolesAuthority.isCapabilityPublic(target, selector)) {
            _addTx(
                address(rolesAuthority),
                abi.encodeWithSelector(rolesAuthority.setPublicCapability.selector, target, selector, true),
                0
            );
        }
    }

    function _addRoleCapabilityIfNotPresent(uint8 role, address target, bytes4 selector) internal {
        if (!rolesAuthority.doesRoleHaveCapability(role, target, selector)) {
            _addTx(
                address(rolesAuthority),
                abi.encodeWithSelector(rolesAuthority.setRoleCapability.selector, role, target, selector, true),
                0
            );
        }
    }

    function _handleAddressOrName(string memory key) internal view returns (address) {
        bytes memory addressOrNameRaw = vm.parseJson(rawJson, key);
        AddressOrName memory addressOrName = abi.decode(addressOrNameRaw, (AddressOrName));
        return
            addressOrName.address_ == address(0) ? getAddress(sourceChain, addressOrName.name) : addressOrName.address_;
    }
}
