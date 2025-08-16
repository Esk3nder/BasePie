# BasePie Smart Contracts

## PieFactory Implementation

The PieFactory contract has been implemented with the following features:

### Core Functionality
- **Pie Creation**: Deploy new PieVault instances using EIP-1167 minimal proxy pattern
- **Token Allowlist**: Global allowlist to restrict which tokens can be used in pies
- **Weight Validation**: Ensures weights sum to exactly 10,000 basis points
- **Access Control**: Role-based permissions for governance functions
- **Security**: ReentrancyGuard, Pausable, and input validation

### Key Functions

#### `createPie()`
- Deploys a new PieVault clone
- Validates all input parameters
- Ensures all assets are allowlisted
- Verifies weights sum to 10,000 bps
- Emits `PieCreated` event

#### `setGlobalAllowlist()`
- Governor-only function
- Adds/removes tokens from global allowlist
- Emits `GlobalAllowlistUpdated` event

#### `setVaultImplementation()`
- Governor-only function
- Updates the vault implementation address
- Validates that the implementation is a contract

### Testing

Comprehensive test suite includes:
- Success path testing
- Weight validation
- Allowlist enforcement
- Access control verification
- Event emission tests
- Gas optimization tests
- Fuzz testing for weight validation

### Gas Optimization
- Uses EIP-1167 minimal proxy pattern for efficient vault deployment
- Target: < 500k gas for pie creation

### Security Considerations
- All external functions protected with appropriate modifiers
- Input validation on all user-provided data
- No external calls during state changes
- Duplicate asset detection

## Next Steps
1. Implement PieVault contract (ERC-4626 async vault)
2. Deploy to Base Sepolia testnet
3. Integrate with frontend
4. Add additional test coverage

## Running Tests

```bash
# Install Foundry if not already installed
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Run tests
forge test --match-contract PieFactoryTest -vv

# Run with gas report
forge test --match-contract PieFactoryTest --gas-report
```