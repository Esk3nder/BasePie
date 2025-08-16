'use client'

import React, { useState } from 'react'
import { useParams, useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { useMockPie, useMockWindow, useMockDeposit, useMockWithdraw, useMockAccount } from '@/lib/mocks/hooks'
import { PieChart } from '@/components/pies/PieChart'
import { AllocationTable } from '@/components/pies/AllocationTable'
import { PerformanceChart } from '@/components/pies/PerformanceChart'
import { generatePerformanceData } from '@/lib/mocks/generators'

export default function PieDetailPage() {
  const params = useParams()
  const searchParams = useSearchParams()
  const pieId = params?.id as string
  
  const { data: pie, isLoading, error } = useMockPie(pieId)
  const { data: window } = useMockWindow(pieId)
  const { address, isConnected } = useMockAccount()
  const { deposit, isPending: isDepositing } = useMockDeposit()
  const { withdraw, isPending: isWithdrawing } = useMockWithdraw()
  
  const [showDepositModal, setShowDepositModal] = useState(searchParams?.get('action') === 'invest')
  const [showWithdrawModal, setShowWithdrawModal] = useState(false)
  const [depositAmount, setDepositAmount] = useState('')
  const [withdrawShares, setWithdrawShares] = useState('')
  
  // Generate performance data for chart
  const performanceData = pie ? generatePerformanceData(30) : []
  
  const handleDeposit = async () => {
    if (!depositAmount || !pieId) return
    
    try {
      await deposit(pieId, parseFloat(depositAmount) * 1000000) // Convert to USDC decimals
      setShowDepositModal(false)
      setDepositAmount('')
      alert('Deposit successful!')
    } catch (error) {
      alert('Deposit failed: ' + (error as Error).message)
    }
  }
  
  const handleWithdraw = async () => {
    if (!withdrawShares || !pieId) return
    
    try {
      await withdraw(pieId, BigInt(withdrawShares))
      setShowWithdrawModal(false)
      setWithdrawShares('')
      alert('Withdrawal request submitted!')
    } catch (error) {
      alert('Withdrawal failed: ' + (error as Error).message)
    }
  }
  
  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="flex items-center justify-center h-64">
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
            <p className="text-gray-600 dark:text-gray-400">Loading pie details...</p>
          </div>
        </div>
      </div>
    )
  }
  
  if (error || !pie) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-6">
          <h2 className="text-red-800 dark:text-red-200 font-semibold mb-2">Pie not found</h2>
          <p className="text-red-600 dark:text-red-300 mb-4">
            {error?.message || 'The requested pie could not be found'}
          </p>
          <Link
            href="/pies"
            className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg inline-block"
          >
            Back to Pies
          </Link>
        </div>
      </div>
    )
  }
  
  return (
    <div className="container mx-auto px-4 py-8">
      {/* Header */}
      <div className="flex justify-between items-start mb-8">
        <div>
          <Link href="/pies" className="text-blue-600 hover:text-blue-700 mb-2 inline-block">
            ← Back to Pies
          </Link>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">
            {pie.name}
          </h1>
          <p className="text-gray-600 dark:text-gray-400">
            {pie.symbol} • {pie.allocations.length} assets
          </p>
        </div>
        
        <div className="flex gap-2">
          {isConnected ? (
            <>
              <button
                onClick={() => setShowDepositModal(true)}
                className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium"
              >
                Invest
              </button>
              <button
                onClick={() => setShowWithdrawModal(true)}
                className="px-6 py-3 bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 rounded-lg font-medium"
              >
                Withdraw
              </button>
            </>
          ) : (
            <button className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium">
              Connect Wallet
            </button>
          )}
          <button
            onClick={() => {
              navigator.clipboard.writeText(window.location.href)
              alert('Link copied!')
            }}
            className="px-6 py-3 bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 rounded-lg font-medium"
          >
            Share
          </button>
        </div>
      </div>
      
      {/* Key Metrics */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        <div className="bg-white dark:bg-gray-900 rounded-lg p-4">
          <p className="text-sm text-gray-500 dark:text-gray-400">TVL</p>
          <p className="text-2xl font-bold text-gray-900 dark:text-white">
            ${(pie.tvl / 1000000).toFixed(2)}M
          </p>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-lg p-4">
          <p className="text-sm text-gray-500 dark:text-gray-400">24h Change</p>
          <p className={`text-2xl font-bold ${(pie.performance?.day || 0) >= 0 ? 'text-green-500' : 'text-red-500'}`}>
            {(pie.performance?.day || 0) >= 0 ? '+' : ''}{pie.performance?.day?.toFixed(2)}%
          </p>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-lg p-4">
          <p className="text-sm text-gray-500 dark:text-gray-400">Window</p>
          <p className="text-2xl font-bold text-gray-900 dark:text-white">
            {window?.status || 'Open'}
          </p>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-lg p-4">
          <p className="text-sm text-gray-500 dark:text-gray-400">Rebalance</p>
          <p className="text-2xl font-bold text-gray-900 dark:text-white">
            Monthly
          </p>
        </div>
      </div>
      
      {/* Main Content Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Left Column - Chart and Performance */}
        <div className="lg:col-span-2 space-y-6">
          {/* Performance Chart */}
          <div className="bg-white dark:bg-gray-900 rounded-lg p-6">
            <h2 className="text-xl font-semibold mb-4">Performance</h2>
            <PerformanceChart 
              data={performanceData}
              timeframe="30d"
              showVolume
            />
          </div>
          
          {/* Allocation Table */}
          <div className="bg-white dark:bg-gray-900 rounded-lg p-6">
            <h2 className="text-xl font-semibold mb-4">Allocations</h2>
            <AllocationTable allocations={pie.allocations} />
          </div>
        </div>
        
        {/* Right Column - Pie Chart and Info */}
        <div className="space-y-6">
          {/* Pie Chart */}
          <div className="bg-white dark:bg-gray-900 rounded-lg p-6">
            <h2 className="text-xl font-semibold mb-4">Composition</h2>
            <PieChart 
              allocations={pie.allocations}
              size={280}
              showLegend
            />
          </div>
          
          {/* Info */}
          <div className="bg-white dark:bg-gray-900 rounded-lg p-6">
            <h2 className="text-xl font-semibold mb-4">Information</h2>
            <div className="space-y-3">
              <div className="flex justify-between">
                <span className="text-gray-500 dark:text-gray-400">Created</span>
                <span className="text-gray-900 dark:text-white">
                  {new Date(pie.createdAt).toLocaleDateString()}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500 dark:text-gray-400">Manager</span>
                <span className="text-gray-900 dark:text-white font-mono text-xs">
                  0x1234...5678
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500 dark:text-gray-400">Fee</span>
                <span className="text-gray-900 dark:text-white">
                  2.00%
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      {/* Deposit Modal */}
      {showDepositModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-900 rounded-lg p-6 w-full max-w-md">
            <h2 className="text-xl font-semibold mb-4">Invest in {pie.name}</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2">Amount (USDC)</label>
                <input
                  type="number"
                  value={depositAmount}
                  onChange={(e) => setDepositAmount(e.target.value)}
                  placeholder="0.00"
                  className="w-full px-4 py-2 border rounded-lg"
                />
              </div>
              <div className="flex gap-2">
                <button
                  onClick={handleDeposit}
                  disabled={isDepositing || !depositAmount}
                  className="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white rounded-lg"
                >
                  {isDepositing ? 'Processing...' : 'Confirm'}
                </button>
                <button
                  onClick={() => setShowDepositModal(false)}
                  className="flex-1 px-4 py-2 bg-gray-200 dark:bg-gray-700 rounded-lg"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
      
      {/* Withdraw Modal */}
      {showWithdrawModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-900 rounded-lg p-6 w-full max-w-md">
            <h2 className="text-xl font-semibold mb-4">Withdraw from {pie.name}</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2">Shares</label>
                <input
                  type="number"
                  value={withdrawShares}
                  onChange={(e) => setWithdrawShares(e.target.value)}
                  placeholder="0"
                  className="w-full px-4 py-2 border rounded-lg"
                />
              </div>
              <div className="flex gap-2">
                <button
                  onClick={handleWithdraw}
                  disabled={isWithdrawing || !withdrawShares}
                  className="flex-1 px-4 py-2 bg-red-600 hover:bg-red-700 disabled:bg-gray-400 text-white rounded-lg"
                >
                  {isWithdrawing ? 'Processing...' : 'Request Withdrawal'}
                </button>
                <button
                  onClick={() => setShowWithdrawModal(false)}
                  className="flex-1 px-4 py-2 bg-gray-200 dark:bg-gray-700 rounded-lg"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}