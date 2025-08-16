// SCAFFOLD: Mock replacements for wagmi hooks
// PSEUDOCODE:
// - useMockAccount: Simulate wallet connection
// - useMockPies: Fetch all pies with loading states
// - useMockDeposit/Withdraw: Transaction hooks
// - useMockPositions: User portfolio data

import { useState, useEffect, useCallback } from 'react'
import type { MockPie, MockPosition, MockTransaction } from './types'

// Mock account hook
export function useMockAccount() {
  // TODO: Track connection state
  // TODO: Generate mock address
  throw new Error('Not implemented: useMockAccount')
}

// Mock connect hook
export function useMockConnect() {
  // TODO: Simulate wallet connection flow
  // TODO: Update global account state
  throw new Error('Not implemented: useMockConnect')
}

// Mock pies query hook
export function useMockPies() {
  const [pies, setPies] = useState<MockPie[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)

  // TODO: Fetch pies from mockPieFactory
  // TODO: Handle loading and error states
  
  return { data: pies, isLoading, error, refetch: () => {} }
}

// Mock single pie hook
export function useMockPie(id: string) {
  // TODO: Fetch specific pie
  throw new Error('Not implemented: useMockPie')
}

// Mock positions hook
export function useMockPositions(address?: string) {
  // TODO: Fetch user positions
  throw new Error('Not implemented: useMockPositions')
}

// Mock deposit hook
export function useMockDeposit() {
  // TODO: Handle deposit transaction
  throw new Error('Not implemented: useMockDeposit')
}

// Mock withdraw hook
export function useMockWithdraw() {
  // TODO: Handle withdrawal request
  throw new Error('Not implemented: useMockWithdraw')
}

// Mock create pie hook
export function useMockCreatePie() {
  // TODO: Handle pie creation
  throw new Error('Not implemented: useMockCreatePie')
}

// Mock transaction hook (generic)
export function useMockTransaction() {
  // TODO: Generic transaction handler
  // TODO: Track pending/success/error states
  throw new Error('Not implemented: useMockTransaction')
}

// Mock balance hook
export function useMockBalance(address?: string) {
  // TODO: Return USDC balance
  throw new Error('Not implemented: useMockBalance')
}

// Mock window hook
export function useMockWindow(pieId: string) {
  // TODO: Fetch current window state
  throw new Error('Not implemented: useMockWindow')
}

// Mock preview hooks
export function useMockPreviewDeposit(pieId: string, amount: number) {
  // TODO: Calculate expected shares
  throw new Error('Not implemented: useMockPreviewDeposit')
}

export function useMockPreviewRedeem(pieId: string, shares: bigint) {
  // TODO: Calculate expected USDC
  throw new Error('Not implemented: useMockPreviewRedeem')
}