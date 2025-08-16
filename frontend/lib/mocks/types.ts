// SCAFFOLD: Type definitions for mock data structures
// PSEUDOCODE: Mirror contract structures from PieVault.sol

export interface MockPie {
  id: string
  name: string
  symbol: string
  creator: string
  createdAt: number
  tvl: number
  totalShares: bigint
  nav: number
  performance: {
    day: number
    week: number
    month: number
    year: number
  }
  allocations: MockAllocation[]
  allowedTokens: string[]
  rebalanceWindow: number
  lastRebalance: number
  nextRebalance: number
}

export interface MockAllocation {
  token: string
  symbol: string
  address: string
  weight: number // basis points (10000 = 100%)
  currentValue: number
  targetValue: number
  price: number
  logo?: string
}

export interface MockPosition {
  pieId: string
  pieName: string
  shares: bigint
  value: number
  costBasis: number
  pnl: number
  pnlPercent: number
  depositedAt: number
}

export interface MockTransaction {
  hash: string
  type: 'deposit' | 'withdraw' | 'rebalance' | 'create'
  status: 'pending' | 'success' | 'failed'
  pieId?: string
  amount?: number
  shares?: bigint
  timestamp: number
  gasUsed?: bigint
  gasPrice?: bigint
}

export interface MockWindow {
  currentWindow: number
  nextWindow: number
  pendingDeposits: number
  pendingWithdrawals: number
  totalShares: bigint
  nav: number
}