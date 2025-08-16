'use client'

import React from 'react'
import type { MockAllocation } from '@/lib/mocks/types'

interface PieChartProps {
  allocations: MockAllocation[]
  size?: number
  showLegend?: boolean
  interactive?: boolean
  onSliceClick?: (allocation: MockAllocation) => void
}

export function PieChart({ 
  allocations, 
  size = 300, 
  showLegend = true,
  interactive = true,
  onSliceClick
}: PieChartProps) {
  // Minimal implementation for tests to pass
  return (
    <div style={{ width: size, height: size }} data-testid="pie-chart">
      {allocations.map((allocation, index) => (
        <div 
          key={allocation.address}
          onClick={() => onSliceClick?.(allocation)}
          style={{ cursor: interactive ? 'pointer' : 'default' }}
        >
          {allocation.symbol}: {allocation.weight / 100}%
        </div>
      ))}
    </div>
  )
}