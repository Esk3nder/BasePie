# feat: Implement PieVault - Async ERC-4626 vault with batch settlement

## What
Implements the core `PieVault` contract - an async ERC-4626 vault with request/claim lifecycle, batch settlement, and portfolio rebalancing support.

## Why
The PieVault is the core component of the BasePie protocol, enabling:
- Non-custodial portfolio management with M1-style UX
- Async deposit/redeem with fair batch pricing
- Window-based rebalancing to maintain target allocations
- Gas-efficient batch processing of requests

## Changes
### New Files
- `contracts/PieVault.sol` - Main vault implementation (470+ lines)
- `contracts/libraries/RequestLib.sol` - Request validation and calculations
- `test/PieVault.t.sol` - Unit test suite (11 tests)
- `test/PieVault.invariant.t.sol` - Invariant test suite (7 tests)

### Modified Files
- `contracts/interfaces/IPieVault.sol` - Complete interface definition
- `test/PieFactory.t.sol` - Updated to use PieVault instead of mock

### Key Features
- ✅ Async request/claim lifecycle (ERC-7540 compatible)
- ✅ Batch settlement with NAV calculations
- ✅ Portfolio weight scheduling
- ✅ Access control (CREATOR, REBALANCER roles)
- ✅ Pausable operations
- ✅ Reentrancy protection
- ✅ Decimal conversion handling (6↔18)

## Risks
- **Gas Usage**: Settlement function may approach block gas limit with many requests
- **Decimal Precision**: Conversion between USDC (6) and shares (18) decimals
- **Oracle Dependency**: NAV calculation will depend on price oracle (stubbed for now)

## Testing
```bash
# Build contracts
forge build

# Run tests (scaffolded for TDD)
forge test --match-contract PieVaultTest

# Check gas usage
forge test --gas-report
```

### Test Coverage
- Unit tests: 11 tests scaffolded
- Invariant tests: 7 tests scaffolded
- Integration: Ready for next phase

## Reviewer Checklist
- [ ] Contract compiles without errors
- [ ] Access control properly implemented
- [ ] State transitions are valid
- [ ] No reentrancy vulnerabilities
- [ ] Events emitted for all state changes
- [ ] Test scaffolding ready for TDD

## Next Steps
1. Implement test assertions (currently scaffolded)
2. Integrate OracleModule for NAV calculations
3. Implement BatchRebalancer for settlement execution
4. Deploy to Base Sepolia for testing