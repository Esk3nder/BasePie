# PieFactory Validation Checklist

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
forge test --match-contract PieFactoryTest -vv
```
Expected: All tests pass
- ✅ test_createPie_success
- ✅ test_createPie_revertsInvalidWeights
- ✅ test_createPie_revertsNonAllowlistedToken
- ✅ test_setGlobalAllowlist_onlyGovernor
- ✅ test_createPie_emitsEvent
- ✅ test_gasLimit_under500k
- ✅ testFuzz_weightValidation

### 3. Gas Report
```bash
forge test --match-contract PieFactoryTest --gas-report
```
Expected: createPie gas usage < 500,000

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