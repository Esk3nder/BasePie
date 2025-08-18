import { useState, useEffect, useCallback } from 'react'
import { useMockConfig } from '@/components/MockProvider'
import { mockStore, mockPieFactory, mockPieVault, mockToken } from './contracts'
import { generatePositions } from './generators'
import type { MockPie, MockPosition, MockAllocation } from './types'

// Helper to apply mock delay
const useMockDelay = () => {
  const { config } = useMockConfig()
  return useCallback(
    async () => {
      if (config.delay > 0) {
        await new Promise(resolve => setTimeout(resolve, config.delay))
      }
    },
    [config.delay]
  )
}

// Helper to check error rate
const useMockError = () => {
  const { config } = useMockConfig()
  return useCallback(() => {
    return Math.random() < config.errorRate
  }, [config.errorRate])
}

// Mock account hook
export function useMockAccount() {
  const [address, setAddress] = useState<string | undefined>()
  const [isConnected, setIsConnected] = useState(false)
  const [isConnecting, setIsConnecting] = useState(false)

  useEffect(() => {
    // Check localStorage for saved connection
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('mockAccount')
      if (saved) {
        setAddress(saved)
        setIsConnected(true)
      }
    }
  }, [])

  return {
    address,
    isConnected,
    isConnecting,
    status: isConnecting ? 'connecting' : isConnected ? 'connected' : 'disconnected',
  }
}

// Mock connect hook
export function useMockConnect() {
  const delay = useMockDelay()
  const shouldError = useMockError()
  const [isPending, setIsPending] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const connect = useCallback(async () => {
    setIsPending(true)
    setError(null)
    
    await delay()
    
    if (shouldError()) {
      const error = new Error('Failed to connect wallet')
      setError(error)
      setIsPending(false)
      throw error
    }

    // Generate a deterministic address
    const address = `0x${Math.random().toString(16).slice(2, 42).padEnd(40, '0')}`
    
    // Save to localStorage
    if (typeof window !== 'undefined') {
      localStorage.setItem('mockAccount', address)
    }
    
    setIsPending(false)
    
    // Trigger a re-render of useMockAccount
    window.dispatchEvent(new Event('storage'))
    
    return { account: address }
  }, [delay, shouldError])

  const disconnect = useCallback(() => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('mockAccount')
      window.dispatchEvent(new Event('storage'))
    }
  }, [])

  return {
    connect,
    disconnect,
    isPending,
    error,
  }
}

// Mock pies query hook
export function useMockPies() {
  const [pies, setPies] = useState<MockPie[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)
  const delay = useMockDelay()
  const shouldError = useMockError()

  const fetchPies = useCallback(async () => {
    setIsLoading(true)
    setError(null)
    
    await delay()
    
    if (shouldError()) {
      const error = new Error('Failed to fetch pies')
      setError(error)
      setIsLoading(false)
      return
    }

    try {
      const allPies = await mockPieFactory.getAllPies()
      setPies(allPies)
    } catch (e) {
      setError(e as Error)
    } finally {
      setIsLoading(false)
    }
  }, [delay, shouldError])

  useEffect(() => {
    fetchPies()
  }, [fetchPies])

  return { 
    data: pies, 
    isLoading, 
    error, 
    refetch: fetchPies 
  }
}

// Mock single pie hook
export function useMockPie(id: string) {
  const [pie, setPie] = useState<MockPie | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)
  const delay = useMockDelay()
  const shouldError = useMockError()

  const fetchPie = useCallback(async () => {
    if (!id) return
    
    setIsLoading(true)
    setError(null)
    
    await delay()
    
    if (shouldError()) {
      const error = new Error('Failed to fetch pie')
      setError(error)
      setIsLoading(false)
      return
    }

    try {
      const pieData = await mockPieFactory.getPie(id)
      setPie(pieData)
    } catch (e) {
      setError(e as Error)
    } finally {
      setIsLoading(false)
    }
  }, [id, delay, shouldError])

  useEffect(() => {
    fetchPie()
  }, [fetchPie])

  return { 
    data: pie, 
    isLoading, 
    error, 
    refetch: fetchPie 
  }
}

// Mock positions hook
export function useMockPositions(address?: string) {
  const [positions, setPositions] = useState<MockPosition[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)
  const delay = useMockDelay()
  const shouldError = useMockError()

  const fetchPositions = useCallback(async () => {
    if (!address) {
      setPositions([])
      setIsLoading(false)
      return
    }
    
    setIsLoading(true)
    setError(null)
    
    await delay()
    
    if (shouldError()) {
      const error = new Error('Failed to fetch positions')
      setError(error)
      setIsLoading(false)
      return
    }

    try {
      let userPositions = mockStore.getUserPositions(address)
      
      // Generate some initial positions if none exist
      if (userPositions.length === 0) {
        const pies = mockStore.getAllPies()
        userPositions = generatePositions(address, pies.slice(0, 3))
        userPositions.forEach(pos => mockStore.addPosition(address, pos))
      }
      
      setPositions(userPositions)
    } catch (e) {
      setError(e as Error)
    } finally {
      setIsLoading(false)
    }
  }, [address, delay, shouldError])

  useEffect(() => {
    fetchPositions()
  }, [fetchPositions])

  return { 
    data: positions, 
    isLoading, 
    error, 
    refetch: fetchPositions 
  }
}

// Mock deposit hook
export function useMockDeposit() {
  const [isPending, setIsPending] = useState(false)
  const [error, setError] = useState<Error | null>(null)
  const [data, setData] = useState<{ hash: string } | null>(null)
  const delay = useMockDelay()
  const shouldError = useMockError()

  const deposit = useCallback(async (pieId: string, amount: number) => {
    setIsPending(true)
    setError(null)
    setData(null)
    
    await delay()
    
    if (shouldError()) {
      const error = new Error('Deposit failed')
      setError(error)
      setIsPending(false)
      throw error
    }

    try {
      const result = await mockPieVault.deposit(pieId, amount)
      setData({ hash: result.hash })
      
      // Wait for transaction
      await result.wait()
      
      return result
    } catch (e) {
      setError(e as Error)
      throw e
    } finally {
      setIsPending(false)
    }
  }, [delay, shouldError])

  return {
    deposit,
    isPending,
    error,
    data,
  }
}

// Mock withdraw hook
export function useMockWithdraw() {
  const [isPending, setIsPending] = useState(false)
  const [error, setError] = useState<Error | null>(null)
  const [data, setData] = useState<{ hash: string } | null>(null)
  const delay = useMockDelay()
  const shouldError = useMockError()

  const withdraw = useCallback(async (pieId: string, shares: bigint) => {
    setIsPending(true)
    setError(null)
    setData(null)
    
    await delay()
    
    if (shouldError()) {
      const error = new Error('Withdrawal failed')
      setError(error)
      setIsPending(false)
      throw error
    }

    try {
      const result = await mockPieVault.requestRedeem(pieId, shares)
      setData({ hash: result.hash })
      
      // Wait for transaction
      await result.wait()
      
      return result
    } catch (e) {
      setError(e as Error)
      throw e
    } finally {
      setIsPending(false)
    }
  }, [delay, shouldError])

  return {
    withdraw,
    isPending,
    error,
    data,
  }
}

// Mock create pie hook
export function useMockCreatePie() {
  const [isPending, setIsPending] = useState(false)
  const [error, setError] = useState<Error | null>(null)
  const [data, setData] = useState<MockPie | null>(null)
  const delay = useMockDelay()
  const shouldError = useMockError()

  const createPie = useCallback(async (params: {
    name: string
    symbol: string
    allocations: MockAllocation[]
  }) => {
    setIsPending(true)
    setError(null)
    setData(null)
    
    await delay()
    
    if (shouldError()) {
      const error = new Error('Failed to create pie')
      setError(error)
      setIsPending(false)
      throw error
    }

    try {
      const pie = await mockPieFactory.createPie(params)
      setData(pie)
      return pie
    } catch (e) {
      setError(e as Error)
      throw e
    } finally {
      setIsPending(false)
    }
  }, [delay, shouldError])

  return {
    createPie,
    isPending,
    error,
    data,
  }
}

// Mock transaction hook (generic)
export function useMockTransaction() {
  const [isPending, setIsPending] = useState(false)
  const [isSuccess, setIsSuccess] = useState(false)
  const [error, setError] = useState<Error | null>(null)
  const [data, setData] = useState<{ hash: string } | null>(null)
  const delay = useMockDelay()
  const shouldError = useMockError()

  const sendTransaction = useCallback(async (action: () => Promise<any>) => {
    setIsPending(true)
    setIsSuccess(false)
    setError(null)
    setData(null)
    
    await delay()
    
    if (shouldError()) {
      const error = new Error('Transaction failed')
      setError(error)
      setIsPending(false)
      throw error
    }

    try {
      const result = await action()
      setData({ hash: result.hash })
      
      // Wait for transaction
      const receipt = await result.wait()
      
      if (receipt.status === 'success') {
        setIsSuccess(true)
      } else {
        throw new Error('Transaction reverted')
      }
      
      return result
    } catch (e) {
      setError(e as Error)
      throw e
    } finally {
      setIsPending(false)
    }
  }, [delay, shouldError])

  return {
    sendTransaction,
    isPending,
    isSuccess,
    error,
    data,
  }
}

// Mock balance hook
export function useMockBalance(address?: string) {
  const [balance, setBalance] = useState<bigint>(0n)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)
  const delay = useMockDelay()

  const fetchBalance = useCallback(async () => {
    if (!address) {
      setBalance(0n)
      setIsLoading(false)
      return
    }
    
    setIsLoading(true)
    setError(null)
    
    await delay()

    try {
      const bal = await mockToken.balanceOf(address)
      setBalance(bal)
    } catch (e) {
      setError(e as Error)
    } finally {
      setIsLoading(false)
    }
  }, [address, delay])

  useEffect(() => {
    fetchBalance()
  }, [fetchBalance])

  return { 
    data: balance, 
    isLoading, 
    error, 
    refetch: fetchBalance 
  }
}

// Mock window hook
export function useMockWindow(pieId: string) {
  const [window, setWindow] = useState<any>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)
  const delay = useMockDelay()

  const fetchWindow = useCallback(async () => {
    if (!pieId) return
    
    setIsLoading(true)
    setError(null)
    
    await delay()

    try {
      const windowData = await mockPieVault.getCurrentWindow(pieId)
      setWindow(windowData)
    } catch (e) {
      setError(e as Error)
    } finally {
      setIsLoading(false)
    }
  }, [pieId, delay])

  useEffect(() => {
    fetchWindow()
  }, [fetchWindow])

  return { 
    data: window, 
    isLoading, 
    error, 
    refetch: fetchWindow 
  }
}

// Mock preview hooks
export function useMockPreviewDeposit(pieId: string, amount: number) {
  const [shares, setShares] = useState<bigint>(0n)
  const [isLoading, setIsLoading] = useState(false)
  const delay = useMockDelay()

  const preview = useCallback(async () => {
    if (!pieId || amount <= 0) {
      setShares(0n)
      return
    }
    
    setIsLoading(true)
    await delay()

    try {
      const previewShares = await mockPieVault.previewDeposit(pieId, amount)
      setShares(previewShares)
    } finally {
      setIsLoading(false)
    }
  }, [pieId, amount, delay])

  useEffect(() => {
    preview()
  }, [preview])

  return { data: shares, isLoading }
}

export function useMockPreviewRedeem(pieId: string, shares: bigint) {
  const [assets, setAssets] = useState<number>(0)
  const [isLoading, setIsLoading] = useState(false)
  const delay = useMockDelay()

  const preview = useCallback(async () => {
    if (!pieId || shares <= 0n) {
      setAssets(0)
      return
    }
    
    setIsLoading(true)
    await delay()

    try {
      const previewAssets = await mockPieVault.previewRedeem(pieId, shares)
      setAssets(previewAssets)
    } finally {
      setIsLoading(false)
    }
  }, [pieId, shares, delay])

  useEffect(() => {
    preview()
  }, [preview])

  return { data: assets, isLoading }
}