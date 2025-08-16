import { faker } from '@faker-js/faker'
import type { MockPie, MockAllocation, MockPosition, MockTransaction, MockWindow } from './types'

const TOKEN_LIST = [
  { symbol: 'WETH', name: 'Wrapped Ether', address: '0x4200000000000000000000000000000000000006', price: 3500 },
  { symbol: 'USDC', name: 'USD Coin', address: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913', price: 1 },
  { symbol: 'WBTC', name: 'Wrapped Bitcoin', address: '0x68f180fcCe6836688e9084f035309E29Bf0A2095', price: 65000 },
  { symbol: 'LINK', name: 'Chainlink', address: '0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196', price: 15 },
  { symbol: 'UNI', name: 'Uniswap', address: '0xD9F6a7471A59c11Fbf99094dc0e69FB604Ad94E2', price: 6 },
  { symbol: 'AAVE', name: 'Aave', address: '0x18Cd890F4e23422DC4aa8C2D6E0bd3F8e1D37382', price: 100 },
  { symbol: 'SNX', name: 'Synthetix', address: '0x22e6966B799c4D5B13BE962E1D117b56327FDa66', price: 3 },
  { symbol: 'MKR', name: 'Maker', address: '0xaB5B7B5849784279280188b93E0B2C31439E2AcF', price: 1500 },
]

export function generatePie(overrides: Partial<MockPie> = {}): MockPie {
  const allocations = generateAllocations(faker.number.int({ min: 3, max: 8 }))
  const tvl = faker.number.float({ min: 10000, max: 5000000, fractionDigits: 2 })
  const createdAt = faker.date.past({ years: 1 }).getTime()
  const lastRebalance = faker.date.recent({ days: 30 }).getTime()
  const rebalanceWindow = faker.helpers.arrayElement([1, 7, 14, 30]) * 86400 // seconds
  
  const strategies = ['Growth', 'Value', 'Balanced', 'DeFi', 'Yield', 'Blue Chip']
  const companies = ['Alpha', 'Beta', 'Gamma', 'Delta', 'Sigma', 'Omega']
  
  return {
    id: faker.string.uuid(),
    name: `${faker.helpers.arrayElement(companies)} ${faker.helpers.arrayElement(strategies)} Pie`,
    symbol: faker.finance.currencyCode() + 'PIE',
    creator: faker.finance.ethereumAddress(),
    createdAt,
    tvl,
    totalShares: BigInt(Math.floor(tvl * 100)),
    nav: faker.number.float({ min: 0.95, max: 1.05, fractionDigits: 4 }),
    performance: {
      day: faker.number.float({ min: -5, max: 5, fractionDigits: 2 }),
      week: faker.number.float({ min: -10, max: 10, fractionDigits: 2 }),
      month: faker.number.float({ min: -20, max: 20, fractionDigits: 2 }),
      year: faker.number.float({ min: -20, max: 50, fractionDigits: 2 }),
    },
    allocations,
    allowedTokens: allocations.map(a => a.address),
    rebalanceWindow,
    lastRebalance,
    nextRebalance: lastRebalance + rebalanceWindow * 1000, // convert to ms
    ...overrides,
  }
}

export function generateAllocations(count: number = 5): MockAllocation[] {
  const selectedTokens = faker.helpers.arrayElements(TOKEN_LIST, count)
  const weights = generateWeights(count)
  
  return selectedTokens.map((token, i) => {
    const currentValue = faker.number.float({ min: 1000, max: 100000, fractionDigits: 2 })
    return {
      token: token.name,
      symbol: token.symbol,
      address: token.address,
      weight: weights[i],
      currentValue,
      targetValue: currentValue * faker.number.float({ min: 0.95, max: 1.05 }),
      price: token.price * faker.number.float({ min: 0.9, max: 1.1 }),
      logo: `https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/base/assets/${token.address}/logo.png`
    }
  })
}

export function generatePosition(overrides: Partial<MockPosition> = {}): MockPosition {
  const value = faker.number.float({ min: 100, max: 50000, fractionDigits: 2 })
  const costBasis = value * faker.number.float({ min: 0.8, max: 1.2 })
  const pnl = value - costBasis
  
  return {
    pieId: faker.string.uuid(),
    pieName: `${faker.company.name()} Pie`,
    shares: BigInt(Math.floor(value * 100)),
    value,
    costBasis,
    pnl,
    pnlPercent: (pnl / costBasis) * 100,
    depositedAt: faker.date.past({ years: 1 }).getTime(),
    ...overrides,
  }
}

export function generateTransaction(overrides: Partial<MockTransaction> = {}): MockTransaction {
  const typeRandom = Math.random()
  const type = typeRandom < 0.6 ? 'deposit' : 
               typeRandom < 0.9 ? 'withdraw' : 
               typeRandom < 0.95 ? 'rebalance' : 'create'
  
  const status = faker.helpers.weightedArrayElement([
    { value: 'success' as const, weight: 8 },
    { value: 'pending' as const, weight: 1 },
    { value: 'failed' as const, weight: 1 },
  ])
  
  return {
    hash: '0x' + faker.string.hexadecimal({ length: 64, prefix: '' }),
    type,
    status,
    pieId: type !== 'create' ? faker.string.uuid() : undefined,
    amount: type === 'deposit' || type === 'withdraw' 
      ? faker.number.float({ min: 100, max: 10000, fractionDigits: 2 })
      : undefined,
    shares: type === 'deposit' || type === 'withdraw'
      ? BigInt(faker.number.int({ min: 10000, max: 1000000 }))
      : undefined,
    timestamp: faker.date.recent({ days: 30 }).getTime(),
    gasUsed: status === 'success' 
      ? BigInt(faker.number.int({ min: 100000, max: 500000 }))
      : undefined,
    gasPrice: status === 'success'
      ? BigInt(faker.number.int({ min: 1000000000, max: 50000000000 }))
      : undefined,
    ...overrides,
  }
}

export function generateWindow(overrides: Partial<MockWindow> = {}): MockWindow {
  const currentWindow = Math.floor(Date.now() / 86400000) // Current day number
  
  return {
    currentWindow,
    nextWindow: currentWindow + 1,
    pendingDeposits: faker.number.float({ min: 0, max: 100000, fractionDigits: 2 }),
    pendingWithdrawals: faker.number.float({ min: 0, max: 50000, fractionDigits: 2 }),
    totalShares: BigInt(faker.number.int({ min: 1000000, max: 10000000 })),
    nav: faker.number.float({ min: 0.98, max: 1.02, fractionDigits: 4 }),
    ...overrides,
  }
}

// Utility functions
export function generateWeights(count: number): number[] {
  const rawWeights = Array.from({ length: count }, () => 
    faker.number.int({ min: 500, max: 4000 }) // 5% to 40% each
  )
  const total = rawWeights.reduce((a, b) => a + b, 0)
  const normalized = rawWeights.map(w => Math.round((w / total) * 10000))
  
  // Adjust for rounding errors
  const normalizedTotal = normalized.reduce((a, b) => a + b, 0)
  if (normalizedTotal !== 10000 && normalized.length > 0) {
    normalized[0] += 10000 - normalizedTotal
  }
  
  return normalized
}

export function generatePerformanceData(days: number = 30): Array<{date: string, value: number, volume?: number}> {
  const data = []
  const now = Date.now()
  const dayMs = 24 * 60 * 60 * 1000
  let value = 100

  for (let i = days; i >= 0; i--) {
    const change = (Math.random() - 0.48) * 5 // Slight upward bias
    value = value * (1 + change / 100)
    value = Math.max(50, Math.min(200, value)) // Keep in reasonable range
    
    data.push({
      date: new Date(now - i * dayMs).toISOString().split('T')[0],
      value: Math.round(value * 100) / 100,
      volume: Math.random() * 100000
    })
  }
  
  return data
}

export function generatePies(count: number = 10): MockPie[] {
  return Array.from({ length: count }, () => generatePie())
}

export function generatePositions(count: number = 5): MockPosition[] {
  return Array.from({ length: count }, () => generatePosition())
}

export function generateTransactions(count: number = 20): MockTransaction[] {
  return Array.from({ length: count }, () => generateTransaction())
}