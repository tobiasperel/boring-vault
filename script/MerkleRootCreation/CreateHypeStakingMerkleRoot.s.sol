// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

/**
 * @title CreateHypeStakingMerkleRoot
 * @notice Script to generate merkle root for HYPE staking strategy operations
 */
contract CreateHypeStakingMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    // Contract addresses (to be updated with actual deployment addresses)
    address public constant HYPE_TOKEN = 0x0000000000000000000000000000000000000000;
    address public constant STHYPE_TOKEN = 0x0000000000000000000000000000000000000000; 
    address public constant HYPE_STAKING_CONTRACT = 0x0000000000000000000000000000000000000000;
    address public constant FELIX_LENDING_POOL = 0x0000000000000000000000000000000000000000;
    address public constant BORING_VAULT = 0x0000000000000000000000000000000000000000;
    address public constant DECODER_AND_SANITIZER = 0x0000000000000000000000000000000000000000;
    address public constant UNISWAP_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    function run() external {
        console.log("Generating HYPE Staking Strategy Merkle Root...");
        
        ManageLeaf[] memory leafs = new ManageLeaf[](20);
        
        // HYPE Token Operations
        _addHypeTokenLeafs(leafs, 0);
        
        // HYPE Staking Operations  
        _addHypeStakingLeafs(leafs, 4);
        
        // Felix Lending Operations
        _addFelixLendingLeafs(leafs, 8);
        
        // DEX Operations for emergency/rebalancing
        _addDexLeafs(leafs, 16);
        
        bytes32[][] memory tree = _generateMerkleTree(leafs);
        bytes32 root = tree[tree.length - 1][0];
        
        console.log("Generated Merkle Root:", vm.toString(root));
        
        // Write to JSON file
        _writeToJsonFile(leafs, tree, root);
        
        console.log("Merkle tree generated successfully!");
        console.log("Next steps:");
        console.log("1. Update addresses in the generated JSON file");
        console.log("2. Call setManageRoot on ManagerWithMerkleVerification");
        console.log("3. Test strategy execution");
    }
    
    function _addHypeTokenLeafs(ManageLeaf[] memory leafs, uint256 startIndex) internal pure {
        // Approve HYPE staking contract to spend HYPE
        leafs[startIndex] = ManageLeaf({
            target: HYPE_TOKEN,
            valueNonZero: false,
            selector: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex].argumentAddresses[0] = HYPE_STAKING_CONTRACT;
        
        // Approve Felix lending pool to spend HYPE  
        leafs[startIndex + 1] = ManageLeaf({
            target: HYPE_TOKEN,
            valueNonZero: false,
            selector: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 1].argumentAddresses[0] = FELIX_LENDING_POOL;
        
        // Transfer HYPE (for internal rebalancing)
        leafs[startIndex + 2] = ManageLeaf({
            target: HYPE_TOKEN,
            valueNonZero: false,
            selector: "transfer(address,uint256)",
            argumentAddresses: new address[](1),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 2].argumentAddresses[0] = BORING_VAULT;
        
        // Approve Uniswap for emergency swaps
        leafs[startIndex + 3] = ManageLeaf({
            target: HYPE_TOKEN,
            valueNonZero: false,
            selector: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 3].argumentAddresses[0] = UNISWAP_V3_ROUTER;
    }
    
    function _addHypeStakingLeafs(ManageLeaf[] memory leafs, uint256 startIndex) internal pure {
        // Stake HYPE tokens
        leafs[startIndex] = ManageLeaf({
            target: HYPE_STAKING_CONTRACT,
            valueNonZero: false,
            selector: "stake(uint256,address)",
            argumentAddresses: new address[](1),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex].argumentAddresses[0] = BORING_VAULT;
        
        // Unstake stHYPE tokens
        leafs[startIndex + 1] = ManageLeaf({
            target: HYPE_STAKING_CONTRACT,
            valueNonZero: false,
            selector: "unstake(uint256,address)",
            argumentAddresses: new address[](1),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 1].argumentAddresses[0] = BORING_VAULT;
        
        // Claim staking rewards
        leafs[startIndex + 2] = ManageLeaf({
            target: HYPE_STAKING_CONTRACT,
            valueNonZero: false,
            selector: "claimRewards(address)",
            argumentAddresses: new address[](1),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 2].argumentAddresses[0] = BORING_VAULT;
        
        // Approve stHYPE to Felix for collateral
        leafs[startIndex + 3] = ManageLeaf({
            target: STHYPE_TOKEN,
            valueNonZero: false,
            selector: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 3].argumentAddresses[0] = FELIX_LENDING_POOL;
    }
    
    function _addFelixLendingLeafs(ManageLeaf[] memory leafs, uint256 startIndex) internal pure {
        // Supply stHYPE as collateral
        leafs[startIndex] = ManageLeaf({
            target: FELIX_LENDING_POOL,
            valueNonZero: false,
            selector: "supply(address,uint256,address,uint16)",
            argumentAddresses: new address[](2),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex].argumentAddresses[0] = STHYPE_TOKEN;
        leafs[startIndex].argumentAddresses[1] = BORING_VAULT;
        
        // Borrow HYPE against stHYPE collateral
        leafs[startIndex + 1] = ManageLeaf({
            target: FELIX_LENDING_POOL,
            valueNonZero: false,
            selector: "borrow(address,uint256,uint256,uint16,address)",
            argumentAddresses: new address[](2),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 1].argumentAddresses[0] = HYPE_TOKEN;
        leafs[startIndex + 1].argumentAddresses[1] = BORING_VAULT;
        
        // Repay HYPE debt
        leafs[startIndex + 2] = ManageLeaf({
            target: FELIX_LENDING_POOL,
            valueNonZero: false,
            selector: "repay(address,uint256,uint256,address)",
            argumentAddresses: new address[](2),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 2].argumentAddresses[0] = HYPE_TOKEN;
        leafs[startIndex + 2].argumentAddresses[1] = BORING_VAULT;
        
        // Withdraw stHYPE collateral
        leafs[startIndex + 3] = ManageLeaf({
            target: FELIX_LENDING_POOL,
            valueNonZero: false,
            selector: "withdraw(address,uint256,address)",
            argumentAddresses: new address[](2),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 3].argumentAddresses[0] = STHYPE_TOKEN;
        leafs[startIndex + 3].argumentAddresses[1] = BORING_VAULT;
        
        // Set reserve as collateral
        leafs[startIndex + 4] = ManageLeaf({
            target: FELIX_LENDING_POOL,
            valueNonZero: false,
            selector: "setUserUseReserveAsCollateral(address,bool)",
            argumentAddresses: new address[](1),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 4].argumentAddresses[0] = STHYPE_TOKEN;
        
        // Emergency repay with collateral
        leafs[startIndex + 5] = ManageLeaf({
            target: FELIX_LENDING_POOL,
            valueNonZero: false,
            selector: "repayWithCollateral(address,address,uint256,bool)",
            argumentAddresses: new address[](2),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 5].argumentAddresses[0] = HYPE_TOKEN;
        leafs[startIndex + 5].argumentAddresses[1] = STHYPE_TOKEN;
        
        // Flashloan for position adjustments
        leafs[startIndex + 6] = ManageLeaf({
            target: FELIX_LENDING_POOL,
            valueNonZero: false,
            selector: "flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)",
            argumentAddresses: new address[](1),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 6].argumentAddresses[0] = BORING_VAULT;
        
        // Emergency liquidation call
        leafs[startIndex + 7] = ManageLeaf({
            target: FELIX_LENDING_POOL,
            valueNonZero: false,
            selector: "liquidationCall(address,address,address,uint256,bool)",
            argumentAddresses: new address[](3),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 7].argumentAddresses[0] = STHYPE_TOKEN;
        leafs[startIndex + 7].argumentAddresses[1] = HYPE_TOKEN;
        leafs[startIndex + 7].argumentAddresses[2] = BORING_VAULT;
    }
    
    function _addDexLeafs(ManageLeaf[] memory leafs, uint256 startIndex) internal pure {
        // Uniswap V3 exact input single (emergency swaps)
        leafs[startIndex] = ManageLeaf({
            target: UNISWAP_V3_ROUTER,
            valueNonZero: false,
            selector: "exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))",
            argumentAddresses: new address[](3),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex].argumentAddresses[0] = HYPE_TOKEN;
        leafs[startIndex].argumentAddresses[1] = STHYPE_TOKEN;
        leafs[startIndex].argumentAddresses[2] = BORING_VAULT;
        
        // Uniswap V3 exact output single
        leafs[startIndex + 1] = ManageLeaf({
            target: UNISWAP_V3_ROUTER,
            valueNonZero: false,
            selector: "exactOutputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))",
            argumentAddresses: new address[](3),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 1].argumentAddresses[0] = HYPE_TOKEN;
        leafs[startIndex + 1].argumentAddresses[1] = STHYPE_TOKEN;
        leafs[startIndex + 1].argumentAddresses[2] = BORING_VAULT;
        
        // Multicall for complex operations
        leafs[startIndex + 2] = ManageLeaf({
            target: UNISWAP_V3_ROUTER,
            valueNonZero: false,
            selector: "multicall(uint256,bytes[])",
            argumentAddresses: new address[](0),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        
        // Self destruct multicall for cleanup
        leafs[startIndex + 3] = ManageLeaf({
            target: UNISWAP_V3_ROUTER,
            valueNonZero: false,
            selector: "selfPermit(address,uint256,uint256,uint8,bytes32,bytes32)",
            argumentAddresses: new address[](1),
            argumentAddressesCheck: "",
            decoderAndSanitizerAddress: DECODER_AND_SANITIZER
        });
        leafs[startIndex + 3].argumentAddresses[0] = HYPE_TOKEN;
    }
    
    function _writeToJsonFile(
        ManageLeaf[] memory leafs,
        bytes32[][] memory tree,
        bytes32 root
    ) internal {
        // In a real implementation, this would write to a JSON file
        // For now, just output the structure
        
        console.log("JSON Structure:");
        console.log("{");
        console.log('  "metadata": {');
        console.log('    "AccountantAddress": "0x0000000000000000000000000000000000000000",');
        console.log('    "BoringVaultAddress": "%s",', vm.toString(BORING_VAULT));
        console.log('    "DecoderAndSanitizerAddress": "%s",', vm.toString(DECODER_AND_SANITIZER));
        console.log('    "LeafCount": %s,', vm.toString(leafs.length));
        console.log('    "ManageRoot": "%s",', vm.toString(root));
        console.log('    "ManagerAddress": "0x0000000000000000000000000000000000000000"');
        console.log('  },');
        console.log('  "leafs": [');
        
        for (uint256 i = 0; i < leafs.length; i++) {
            bytes32 leafDigest = keccak256(
                abi.encodePacked(
                    leafs[i].decoderAndSanitizerAddress,
                    leafs[i].target,
                    leafs[i].valueNonZero,
                    bytes4(keccak256(bytes(leafs[i].selector))),
                    _encodeAddresses(leafs[i].argumentAddresses)
                )
            );
            
            console.log('    {');
            console.log('      "TargetAddress": "%s",', vm.toString(leafs[i].target));
            console.log('      "FunctionSelector": "%s",', vm.toString(bytes4(keccak256(bytes(leafs[i].selector)))));
            console.log('      "FunctionSignature": "%s",', leafs[i].selector);
            console.log('      "CanSendValue": %s,', leafs[i].valueNonZero ? "true" : "false");
            console.log('      "DecoderAndSanitizerAddress": "%s",', vm.toString(leafs[i].decoderAndSanitizerAddress));
            console.log('      "LeafDigest": "%s"', vm.toString(leafDigest));
            
            if (i < leafs.length - 1) {
                console.log('    },');
            } else {
                console.log('    }');
            }
        }
        
        console.log('  ]');
        console.log('}');
    }
    
    function _encodeAddresses(address[] memory addresses) internal pure returns (bytes memory) {
        bytes memory encoded = new bytes(addresses.length * 20);
        for (uint256 i = 0; i < addresses.length; i++) {
            bytes20 addr = bytes20(addresses[i]);
            for (uint256 j = 0; j < 20; j++) {
                encoded[i * 20 + j] = addr[j];
            }
        }
        return encoded;
    }
}
