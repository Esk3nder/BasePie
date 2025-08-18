# BasePie Validation Checklist

## Prerequisites
```bash
# Install Foundry if not already installed
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Validation Commands

### 1. Build Contracts
```bash
forge build
```
Expected: All contracts compile without errors

### 2. Run Tests
```bash
# Test TradeAdapter (NEW)
forge test --match-contract TradeAdapterTest -vv

# Test BatchRebalancer
forge test --match-contract BatchRebalancerTest -vv

# Test PieFactory
forge test --match-contract PieFactoryTest -vv

# Test PieVault (when test assertions are implemented)
forge test --match-contract PieVaultTest -vv

# Run invariant tests
forge test --match-contract PieVaultInvariantTest

# Run all tests
forge test
```
Expected test coverage:
- TradeAdapter: 13 tests (✅ 9 passing, 4 require mainnet fork)
- BatchRebalancer: 8 tests (✅ all passing)
- PieFactory: 7 tests (4 passing currently)
- PieVault: 11 tests (scaffolded, ready for TDD)
- Invariants: 7 tests (scaffolded)

### 3. Gas Report
```bash
# BatchRebalancer gas report
forge test --match-contract BatchRebalancerTest --gas-report

# PieFactory gas report
forge test --match-contract PieFactoryTest --gas-report
```
Expected gas usage:
- BatchRebalancer.processWindow: < 100,000
- BatchRebalancer.computeRebalanceDeltas: < 50,000
- PieFactory.createPie: < 500,000

### 4. Coverage Report
```bash
forge coverage --match-contract PieFactory
```
Expected: >90% coverage

### 5. Security Analysis
```bash
# Static analysis with Slither (if installed)
slither contracts/PieFactory.sol --config-file slither.config.json

# Mythril analysis (if installed)
myth analyze contracts/PieFactory.sol
```

### 6. Format Check
```bash
forge fmt --check
```
Expected: No formatting issues

### 7. Size Check
```bash
forge build --sizes
```
Expected: Contract size < 24KB limit

## Manual Verification

- [ ] All functions have proper access control
- [ ] Events are emitted for all state changes
- [ ] No unhandled external calls
- [ ] Input validation on all user inputs
- [ ] No integer overflow/underflow risks
- [ ] Reentrancy protection on state-changing functions
- [ ] Emergency pause mechanism works
- [ ] Role management properly configured