'use client'

import React from 'react'
import Link from 'next/link'
import type { MockPie } from '@/lib/mocks/types'
import { PieChart } from './PieChart'

interface PieCardProps {
  pie: MockPie
  showActions?: boolean
  onInvest?: () => void
  onShare?: () => void
}

export function PieCard({ pie, showActions = false, onInvest, onShare }: PieCardProps) {
  // Calculate 24h performance
  const performance24h = pie.performance?.day || 0
  const performanceColor = performance24h >= 0 ? 'text-green-500' : 'text-red-500'
  const performanceIcon = performance24h >= 0 ? '↑' : '↓'
  
  // Get top 3 allocations for preview
  const topAllocations = pie.allocations
    .sort((a, b) => b.weight - a.weight)
    .slice(0, 3)
  
  const remainingCount = Math.max(0, pie.allocations.length - 3)
  const remainingWeight = pie.allocations
    .slice(3)
    .reduce((sum, a) => sum + a.weight, 0)

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl shadow-lg hover:shadow-xl transition-shadow duration-200 overflow-hidden">
      <Link href={`/pies/${pie.id}`} className="block">
        {/* Header */}
        <div className="p-4 border-b border-gray-200 dark:border-gray-800">
          <div className="flex justify-between items-start mb-2">
            <div>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                {pie.name}
              </h3>
              <p className="text-sm text-gray-500 dark:text-gray-400">
                {pie.symbol}
              </p>
            </div>
            <div className="text-right">
              <p className="text-xs text-gray-500 dark:text-gray-400">24h</p>
              <p className={`text-sm font-medium ${performanceColor}`}>
                {performanceIcon} {Math.abs(performance24h).toFixed(2)}%
              </p>
            </div>
          </div>
        </div>

        {/* Mini Chart */}
        <div className="p-4 flex justify-center">
          <PieChart 
            allocations={pie.allocations}
            size={120}
            showLegend={false}
            interactive={false}
          />
        </div>

        {/* Allocations Preview */}
        <div className="px-4 pb-2">
          <p className="text-xs text-gray-500 dark:text-gray-400 mb-2">Top Holdings</p>
          <div className="space-y-1">
            {topAllocations.map((allocation) => (
              <div key={allocation.address} className="flex justify-between text-sm">
                <span className="text-gray-700 dark:text-gray-300">
                  {allocation.symbol}
                </span>
                <span className="text-gray-500 dark:text-gray-400">
                  {(allocation.weight / 100).toFixed(1)}%
                </span>
              </div>
            ))}
            {remainingCount > 0 && (
              <div className="flex justify-between text-sm text-gray-400 dark:text-gray-500">
                <span>+{remainingCount} more</span>
                <span>{(remainingWeight / 100).toFixed(1)}%</span>
              </div>
            )}
          </div>
        </div>

        {/* Metrics */}
        <div className="px-4 py-3 bg-gray-50 dark:bg-gray-800/50 grid grid-cols-2 gap-4 text-sm">
          <div>
            <p className="text-gray-500 dark:text-gray-400 text-xs">TVL</p>
            <p className="font-medium text-gray-900 dark:text-white">
              ${(pie.tvl / 1000000).toFixed(2)}M
            </p>
          </div>
          <div>
            <p className="text-gray-500 dark:text-gray-400 text-xs">Assets</p>
            <p className="font-medium text-gray-900 dark:text-white">
              {pie.allocations.length}
            </p>
          </div>
        </div>
      </Link>

      {/* Actions */}
      {showActions && (
        <div className="px-4 pb-4 pt-2 flex gap-2">
          <button
            onClick={(e) => {
              e.preventDefault()
              onInvest?.()
            }}
            className="flex-1 px-3 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm font-medium transition-colors"
          >
            Invest
          </button>
          <button
            onClick={(e) => {
              e.preventDefault()
              onShare?.()
            }}
            className="px-3 py-2 bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 rounded-lg text-sm font-medium transition-colors"
          >
            Share
          </button>
        </div>
      )}
    </div>
  )
}