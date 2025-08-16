# Base Pies 🥧

M1-style portfolio vaults on Base L2 with automated rebalancing and social features.

## Overview

Base Pies is a non-custodial, window-rebalanced portfolio vault system built on Base L2. It provides ERC-20/4626 semantics with async settlement, allowing users to create and invest in diversified crypto portfolios ("pies") with automated rebalancing.

## Key Features

- **Non-custodial**: Users maintain full control of their assets
- **Async ERC-4626 Vaults**: Deposit/withdraw in USDC with batch settlement
- **Automated Rebalancing**: Daily window-based rebalancing via Uniswap/0x
- **Social Sharing**: Share and clone portfolio strategies
- **M1-like UX**: Target weights, fractional shares, clear activity feeds

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Frontend  │────▶│  PieFactory  │────▶│  PieVault   │
└─────────────┘     └──────────────┘     └─────────────┘
                            │                     │
                            ▼                     ▼
                    ┌──────────────┐     ┌─────────────┐
                    │   Keepers    │────▶│ Rebalancer  │
                    └──────────────┘     └─────────────┘
                            │                     │
                            ▼                     ▼
                    ┌──────────────┐     ┌─────────────┐
                    │    Oracle    │     │TradeAdapter │
                    └──────────────┘     └─────────────┘
```

## Project Structure

```
├── contracts/          # Smart contracts
│   ├── interfaces/     # Contract interfaces
│   ├── core/          # Core vault logic
│   ├── adapters/      # DEX adapters
│   └── libraries/     # Shared libraries
├── scripts/           # Deployment scripts
├── test/             # Contract tests
├── keeper/           # Off-chain automation
├── subgraph/         # Indexing & queries
├── app/              # Frontend application
└── docs/             # Documentation
```

## Contracts

- **PieFactory**: Deploys new pie vaults with configured parameters
- **PieVault**: ERC-4626 async vault with request/claim lifecycle
- **BatchRebalancer**: Computes deltas and executes rebalancing trades
- **TradeAdapter**: Interfaces with Uniswap Universal Router and 0x
- **OracleModule**: Chainlink price feeds integration for Base network with health monitoring, decimal normalization, and USDC special handling
- **KeeperGate**: Window scheduling and automation triggers

## Development

### Prerequisites

- Node.js >= 18
- Foundry (for smart contract development)
- Git

### Setup

```bash
# Install dependencies
npm install

# Install Foundry (if not installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Build contracts
forge build

# Run tests
forge test

# Deploy to Base Sepolia
forge script scripts/Deploy.s.sol --rpc-url base-sepolia --broadcast
```

### Environment Variables

Create a `.env` file:

```env
PRIVATE_KEY=your_private_key
ETHERSCAN_API_KEY=your_etherscan_api_key
RPC_URL_BASE=https://mainnet.base.org
RPC_URL_BASE_SEPOLIA=https://sepolia.base.org
```

## Testing

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/PieVault.t.sol

# Run with gas reporting
forge test --gas-report

# Run invariant tests
forge test --match-test invariant
```

## Oracle Configuration

The OracleModule provides reliable USD price discovery for portfolio valuation and rebalancing:

### Features
- **Chainlink Integration**: Primary price feeds from Chainlink on Base network
- **Decimal Normalization**: All prices normalized to 18 decimals for consistency
- **Health Monitoring**: Staleness (30 min) and deviation (2%) checks
- **USDC Optimization**: Hardcoded $1 for USDC to save gas
- **Batch Operations**: Efficient multi-token price fetching

### Supported Feeds (Base Mainnet)
- ETH/USD: `0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70`
- cbETH/USD: `0xd7818272B9e248357d13057AAb0B417aF31E817d`
- USDC/USD: Special handling (always $1)

### Configuration
```solidity
// Register new price feed
oracleModule.registerFeed(tokenAddress, chainlinkFeedAddress);

// Adjust health parameters
oracleModule.setStalenessThreshold(1800); // 30 minutes
oracleModule.setMaxDeviation(200); // 2% in basis points
```

## Security

- All contracts use OpenZeppelin's battle-tested libraries
- Comprehensive test coverage including fuzz and invariant testing
- Slippage protection and oracle deviation checks
- Allowlisted routers and tokens
- Pausable operations for emergency scenarios

## License

MIT