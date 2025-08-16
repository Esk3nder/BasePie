import { generatePie, generateWindow } from './generators'
import type { MockPie, MockPosition, MockTransaction, MockWindow } from './types'

// Get mock config from environment or defaults
const getMockConfig = () => ({
  delay: parseInt(process.env.NEXT_PUBLIC_MOCK_DELAY || '500'),
  errorRate: parseFloat(process.env.NEXT_PUBLIC_MOCK_ERROR_RATE || '0'),
})

// In-memory store for mock data
class MockContractStore {
  private pies: Map<string, MockPie> = new Map()
  private positions: Map<string, MockPosition[]> = new Map()
  private transactions: MockTransaction[] = []
  private pendingTxs: Map<string, MockTransaction> = new Map()

  constructor() {
    // Initialize with some default pies
    const { generatePies } = require('./generators')
    const initialPies = generatePies(10)
    initialPies.forEach(pie => this.pies.set(pie.id, pie))
  }

  getPie(id: string): MockPie | undefined {
    return this.pies.get(id)
  }

  getAllPies(): MockPie[] {
    return Array.from(this.pies.values())
  }

  createPie(pie: Omit<MockPie, 'id'>): MockPie {
    const newPie = { ...pie, id: crypto.randomUUID() } as MockPie
    this.pies.set(newPie.id, newPie)
    return newPie
  }

  getUserPositions(address: string): MockPosition[] {
    return this.positions.get(address) || []
  }

  addPosition(address: string, position: MockPosition): void {
    const userPositions = this.positions.get(address) || []
    userPositions.push(position)
    this.positions.set(address, userPositions)
  }

  updatePosition(address: string, pieId: string, update: (pos: MockPosition) => void): void {
    const positions = this.positions.get(address) || []
    const position = positions.find(p => p.pieId === pieId)
    if (position) {
      update(position)
    }
  }

  addTransaction(tx: MockTransaction): void {
    this.transactions.push(tx)
    if (tx.status === 'pending') {
      this.pendingTxs.set(tx.hash, tx)
    }
  }

  updateTransactionStatus(hash: string, status: 'success' | 'failed'): void {
    const tx = this.pendingTxs.get(hash)
    if (tx) {
      tx.status = status
      this.pendingTxs.delete(hash)
    }
  }

  generatePies(count: number): MockPie[] {
    return generatePies(count)
  }
}

export const mockStore = new MockContractStore()

// Mock delay helper
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))

// Mock transaction helper
async function mockTransaction<T>(
  action: () => T,
  options: { delay?: number; failureRate?: number } = {}
): Promise<{ hash: string; wait: () => Promise<{ status: 'success' | 'failed' }> }> {
  const config = getMockConfig()
  const txDelay = options.delay ?? config.delay
  const failureRate = options.failureRate ?? config.errorRate
  
  const hash = `0x${crypto.randomUUID().replace(/-/g, '')}`
  const willFail = Math.random() < failureRate

  const tx: MockTransaction = {
    hash,
    type: 'deposit', // Will be overridden by caller
    status: 'pending',
    timestamp: Date.now(),
  }
  mockStore.addTransaction(tx)

  return {
    hash,
    wait: async () => {
      await delay(txDelay)
      const status = willFail ? 'failed' : 'success'
      mockStore.updateTransactionStatus(hash, status)
      
      if (willFail) {
        throw new Error('Transaction failed')
      }
      
      action()
      return { status }
    },
  }
}

// Mock PieFactory Contract
export const mockPieFactory = {
  address: '0x0000000000000000000000000000000000000001',
  
  async createPie(params: {
    name: string
    symbol: string
    allocations: { token: string; weight: number }[]
    allowedTokens: string[]
    rebalanceWindow: number
  }) {
    // Validate weights sum to 10000
    const totalWeight = params.allocations.reduce((sum, a) => sum + a.weight, 0)
    if (totalWeight !== 10000) {
      throw new Error(`Weights must sum to 10000, got ${totalWeight}`)
    }

    return mockTransaction(() => {
      const pie = generatePie({
        name: params.name,
        symbol: params.symbol,
        allocations: params.allocations.map(a => ({
          token: a.token,
          symbol: a.token,
          address: `0x${crypto.randomUUID().replace(/-/g, '').slice(0, 40)}`,
          weight: a.weight,
          currentValue: 0,
          targetValue: 0,
          price: Math.random() * 1000,
        })),
        allowedTokens: params.allowedTokens,
        rebalanceWindow: params.rebalanceWindow,
        creator: '0x1234567890123456789012345678901234567890',
        createdAt: Date.now(),
        tvl: 0,
        totalShares: BigInt(0),
        nav: 1,
      })
      mockStore.createPie(pie)
      return pie
    })
  },

  async getAllPies() {
    const config = getMockConfig()
    await delay(config.delay)
    return mockStore.getAllPies()
  },

  async getPie(id: string) {
    const config = getMockConfig()
    await delay(config.delay / 2)
    return mockStore.getPie(id)
  }
}

// Mock PieVault Contract
export const mockPieVault = {
  address: '0x0000000000000000000000000000000000000002',

  async deposit(pieId: string, amount: number, receiver: string) {
    return mockTransaction(() => {
      const pie = mockStore.getPie(pieId)
      if (!pie) throw new Error('Pie not found')
      
      const shares = BigInt(Math.floor(amount * 100 / pie.nav))
      const position: MockPosition = {
        pieId,
        pieName: pie.name,
        shares,
        value: amount,
        costBasis: amount,
        pnl: 0,
        pnlPercent: 0,
        depositedAt: Date.now(),
      }
      mockStore.addPosition(receiver, position)
      return { shares }
    })
  },

  async requestRedeem(pieId: string, shares: bigint, owner: string) {
    return mockTransaction(() => {
      mockStore.updatePosition(owner, pieId, (position) => {
        position.shares = position.shares > shares ? position.shares - shares : BigInt(0)
        if (position.shares === BigInt(0)) {
          // Remove position if fully redeemed
          const positions = mockStore.getUserPositions(owner)
          const index = positions.indexOf(position)
          if (index > -1) {
            positions.splice(index, 1)
          }
        }
      })
      return { requestId: crypto.randomUUID() }
    })
  },

  async getPositions(user: string) {
    const config = getMockConfig()
    await delay(config.delay / 2)
    return mockStore.getUserPositions(user)
  },

  async getCurrentWindow(pieId: string) {
    const config = getMockConfig()
    await delay(config.delay / 3)
    return generateWindow({ 
      pendingDeposits: Math.random() * 100000,
      pendingWithdrawals: Math.random() * 50000,
    })
  },

  async previewDeposit(pieId: string, amount: number) {
    const config = getMockConfig()
    await delay(config.delay / 4)
    const pie = mockStore.getPie(pieId)
    if (!pie) throw new Error('Pie not found')
    
    const shares = BigInt(Math.floor(amount * 100 / pie.nav))
    return { shares, nav: pie.nav }
  },

  async previewRedeem(pieId: string, shares: bigint) {
    const config = getMockConfig()
    await delay(config.delay / 4)
    const pie = mockStore.getPie(pieId)
    if (!pie) throw new Error('Pie not found')
    
    const amount = Number(shares) / 100 * pie.nav
    return { amount, nav: pie.nav }
  }
}

// Mock Token Contract (USDC)
export const mockToken = {
  async approve(spender: string, amount: bigint) {
    return mockTransaction(() => {
      return { approved: true }
    }, { delay: 800 })
  },

  async balanceOf(address: string) {
    const config = getMockConfig()
    await delay(config.delay / 4)
    // Return random balance between 1k and 100k USDC (6 decimals)
    return BigInt(Math.floor(Math.random() * 99000 + 1000) * 1e6)
  }
}

// Mock Permit2 Contract
export const mockPermit2 = {
  address: '0x000000000022D473030F116dDEE9F6B43aC78BA3',

  async permit(params: {
    token: string
    amount: bigint
    deadline: bigint
    nonce: bigint
  }) {
    const config = getMockConfig()
    await delay(config.delay / 2)
    return {
      signature: `0x${crypto.randomUUID().replace(/-/g, '')}${crypto.randomUUID().replace(/-/g, '')}`,
      deadline: params.deadline,
      nonce: params.nonce,
    }
  }
}

// Export additional functions for testing
export function generatePies(count: number): MockPie[] {
  return mockStore.generatePies(count)
}