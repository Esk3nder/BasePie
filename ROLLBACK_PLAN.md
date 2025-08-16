# Rollback Plan - PieFactory Implementation

## Overview
This document outlines the rollback procedures for the PieFactory smart contract implementation.

## Rollback Scenarios

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