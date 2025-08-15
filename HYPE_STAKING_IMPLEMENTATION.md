# HYPE Staking Vault Implementation

## Overview

HYPE Staking Vault implements a leveraged looping strategy using the BoringVault architecture. Users deposit HYPE tokens to earn yield through a loop: stake HYPE for stHYPE, use stHYPE as collateral to borrow more HYPE, repeat.

## How to Run Tests

```bash
# Run all HYPE staking tests
forge test --match-contract HypeStakingVaultTest

# Run with verbose output
forge test --match-contract HypeStakingVaultTest -vv

# Run specific test
forge test --match-test testBasicLoopExecution
```

## How to Deploy the Vault

1. **Update addresses in deployment script:**
   ```solidity
   // Edit script/DeployHypeStakingVault.s.sol
   address public constant HYPE_TOKEN = 0x...;
   address public constant STHYPE_TOKEN = 0x...;
   address public constant HYPE_STAKING_CONTRACT = 0x...;
   address public constant FELIX_LENDING_POOL = 0x...;
   ```

2. **Run deployment:**
   ```bash
   forge script script/DeployHypeStakingVault.s.sol --rpc-url $RPC_URL --broadcast
   ```

3. **Post-deployment setup:**
   - Set up roles and permissions
   - Generate merkle root using `CreateHypeStakingMerkleRoot.s.sol`
   - Call `setManageRoot()` on manager
   - Configure strategy parameters

## Strategy Flow

1. **User deposits HYPE** → BoringVault mints shares
2. **Strategy execution loop:**
   - Stake HYPE → receive stHYPE
   - Supply stHYPE as collateral to Felix
   - Borrow HYPE against stHYPE
   - Repeat until target LTV reached
3. **Yield generation:**
   - Earn staking rewards from HYPE staking
   - Earn lending rewards from Felix
   - Compound rewards back into position
4. **User withdrawal** → Unwind positions and return HYPE

## Vault Components Responsibility

### BoringVault
- Core vault contract holding user funds
- Mints/burns shares on deposit/withdrawal
- Executes manager calls through merkle verification

### ManagerWithMerkleVerification
- Security layer using merkle trees
- Validates all vault operations against pre-approved actions
- Prevents unauthorized fund access

### HypeStakingLoopingManager
- Main strategy orchestrator
- Executes looping logic: stake, supply, borrow, repeat
- Handles rebalancing and emergency exits
- Manages position health and LTV ratios

### HypeStakingDecoderAndSanitizer
- Validates function arguments for security
- Ensures only approved addresses in function calls
- Part of merkle verification system

### Key Functions

- `executeLoop()` - Creates leveraged position
- `harvestAndCompound()` - Claims rewards and compounds
- `rebalance()` - Adjusts position to target LTV
- `emergencyExit()` - Unwinds all positions for safety

## Architecture Benefits

- **Security**: Merkle verification prevents unauthorized operations
- **Flexibility**: Can add new protocols through merkle updates
- **MEV Protection**: TellerWithMultiAssetSupport prevents arbitrage
- **Upgradability**: Strategy logic separate from vault storage
