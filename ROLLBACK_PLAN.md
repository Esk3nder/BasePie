# Rollback Plan - BasePie Smart Contracts

## Overview
This document outlines the rollback procedures for the BasePie smart contract suite including PieFactory, PieVault, and BatchRebalancer implementations.

## Rollback Scenarios

### BatchRebalancer-Specific Rollback

#### Critical Issues Requiring Immediate Rollback:
- Incorrect NAV calculations causing value loss
- Trade execution failures causing vault lockup  
- Oracle manipulation vulnerabilities
- Window processing causing state corruption

#### Rollback Steps:
```bash
# 1. Pause the rebalancer immediately
cast send <REBALANCER_ADDRESS> "pause()" --private-key $GOVERNOR_KEY

# 2. Revoke keeper roles to prevent window processing
cast send <REBALANCER_ADDRESS> "revokeRole(bytes32,address)" \
  $(cast keccak "KEEPER_ROLE") <KEEPER_ADDRESS> --private-key $GOVERNOR_KEY

# 3. Remove rebalancer role from vaults
cast send <VAULT_ADDRESS> "revokeRole(bytes32,address)" \
  $(cast keccak "REBALANCER_ROLE") <REBALANCER_ADDRESS> --private-key $GOVERNOR_KEY

# 4. If mid-window, manually settle pending requests
# Check last processed window for each vault
cast call <REBALANCER_ADDRESS> "lastProcessedWindow(address)" <VAULT_ADDRESS>
```

### OracleModule-Specific Rollback

#### Critical Issues Requiring Immediate Rollback:
- Incorrect price normalization causing NAV miscalculation
- Chainlink feed integration failures
- Decimal conversion errors leading to value loss
- Health check logic blocking all price fetches
- Gas costs exceeding 100k for batch operations

#### Rollback Steps:
```bash
# 1. Deploy emergency MockOracle as temporary replacement
# MockOracle provides hardcoded safe prices for critical operations

# 2. Update BatchRebalancer to use MockOracle
cast send <BATCH_REBALANCER> "setOracleModule(address)" <MOCK_ORACLE> --private-key $ADMIN_KEY

# 3. Verify price feeds working
cast call <MOCK_ORACLE> "getUsdPrice(address)" <WETH_ADDRESS>

# 4. Deploy fixed OracleModule
forge script script/Deploy.s.sol --rpc-url $RPC --broadcast

# 5. Re-register Chainlink feeds
cast send <NEW_ORACLE> "registerFeed(address,address)" <TOKEN> <FEED> --private-key $ADMIN_KEY

# 6. Switch BatchRebalancer to new Oracle
cast send <BATCH_REBALANCER> "setOracleModule(address)" <NEW_ORACLE> --private-key $ADMIN_KEY
```

### 1. Pre-Deployment Rollback (Development)
If issues are discovered during testing before mainnet deployment:

```bash
# Revert to previous commit
git revert HEAD

# Or reset to specific commit before PieFactory implementation
git reset --hard <commit-hash-before-piefactory>

# Force push if needed (only on feature branches)
git push --force origin <branch-name>
```

### 2. Post-Deployment Rollback (Testnet)
If issues are discovered after testnet deployment:

#### Option A: Emergency Pause
```solidity
// Immediate action - pause the factory
PieFactory.pause()
```

#### Option B: Deploy Fixed Version
1. Fix the issues in the code
2. Deploy new PieFactory instance
3. Update frontend to point to new factory address
4. Announce deprecation of old factory

### 3. Post-Deployment Rollback (Mainnet)
If critical issues are discovered after mainnet deployment:

#### Immediate Response:
1. **Pause Factory Operations**
   ```javascript
   // Using governor account
   await factory.pause();
   ```

2. **Notify Users**
   - Post announcement on official channels
   - Update frontend with warning banner

#### Recovery Options:

**Option 1: Minimal Fix**
- If issue is in admin functions only, deploy patch
- Update governor to point to new implementation

**Option 2: Full Migration**
- Deploy new factory with fixes
- Provide migration path for existing pies
- Update all integrations

## Data Recovery

### Existing Pies
Since pies are separate contracts deployed via proxy:
- Existing pies remain functional
- Can be managed independently of factory

### State Recovery
```javascript
// Script to extract deployed pies from old factory
const oldFactory = await ethers.getContractAt("PieFactory", OLD_FACTORY_ADDRESS);
const allPies = await oldFactory.getAllPies();

// Store for migration reference
fs.writeFileSync('deployed-pies.json', JSON.stringify(allPies));
```

## Monitoring & Detection

### Key Metrics to Monitor
- Gas usage anomalies
- Failed transactions rate
- Unexpected revert reasons
- Abnormal pie creation patterns

### Alert Thresholds
- Gas usage > 500k for createPie
- Failed transaction rate > 10%
- Any unauthorized access attempts

## Communication Plan

1. **Internal Team**: Immediate Slack/Discord notification
2. **Users**: Twitter/Discord announcement within 15 minutes
3. **Partners**: Direct communication within 1 hour
4. **Post-Mortem**: Published within 48 hours

## Testing Rollback

### Simulation Steps
1. Deploy to testnet
2. Create several test pies
3. Simulate critical failure
4. Execute pause procedure
5. Deploy fixed version
6. Verify migration path

## Rollback Checklist

- [ ] Identify the issue severity (Critical/High/Medium/Low)
- [ ] Pause factory if critical
- [ ] Notify team members
- [ ] Document issue details
- [ ] Prepare fix or rollback code
- [ ] Test fix on testnet
- [ ] Communicate with users
- [ ] Deploy fix/rollback
- [ ] Verify system stability
- [ ] Publish post-mortem

## Contact Information

- Technical Lead: [Contact Info]
- Security Team: [Contact Info]
- Communications: [Contact Info]
- On-Call Engineer: [Contact Info]

## Recovery Time Objectives

- **Detection to Response**: < 15 minutes
- **Response to Mitigation**: < 1 hour
- **Mitigation to Resolution**: < 4 hours
- **Post-Mortem Publication**: < 48 hours