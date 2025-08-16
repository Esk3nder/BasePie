'use client'

import React, { useState } from 'react'
import { PieChart as RechartsPieChart, Pie, Cell, ResponsiveContainer, Tooltip, Legend } from 'recharts'
import type { MockAllocation } from '@/lib/mocks/types'

interface PieChartProps {
  allocations: MockAllocation[]
  size?: number
  showLegend?: boolean
  interactive?: boolean
  onSliceClick?: (allocation: MockAllocation) => void
}

// Color palette for tokens
const COLORS = [
  '#3B82F6', // blue
  '#8B5CF6', // violet
  '#EC4899', // pink
  '#F59E0B', // amber
  '#10B981', // emerald
  '#06B6D4', // cyan
  '#F43F5E', // rose
  '#6366F1', // indigo
  '#84CC16', // lime
  '#14B8A6', // teal
]

interface ChartData {
  name: string
  value: number
  symbol: string
  allocation: MockAllocation
}

const CustomTooltip = ({ active, payload }: any) => {
  if (active && payload && payload[0]) {
    const data = payload[0].payload
    return (
      <div className="bg-gray-900/95 backdrop-blur-sm p-3 rounded-lg shadow-xl border border-gray-700">
        <p className="text-white font-semibold">{data.name}</p>
        <p className="text-gray-300 text-sm">
          {data.symbol}: {(data.value / 100).toFixed(2)}%
        </p>
        <p className="text-gray-400 text-xs">
          ${data.allocation.currentValue.toLocaleString()}
        </p>
      </div>
    )
  }
  return null
}

const CustomLabel = ({ cx, cy, midAngle, innerRadius, outerRadius, percent }: any) => {
  const RADIAN = Math.PI / 180
  const radius = innerRadius + (outerRadius - innerRadius) * 0.5
  const x = cx + radius * Math.cos(-midAngle * RADIAN)
  const y = cy + radius * Math.sin(-midAngle * RADIAN)

  if (percent < 0.05) return null // Don't show label for small slices

  return (
    <text
      x={x}
      y={y}
      fill="white"
      textAnchor={x > cx ? 'start' : 'end'}
      dominantBaseline="central"
      className="text-xs font-medium"
    >
      {`${(percent * 100).toFixed(0)}%`}
    </text>
  )
}

export function PieChart({ 
  allocations, 
  size = 300, 
  showLegend = true,
  interactive = true,
  onSliceClick
}: PieChartProps) {
  const [activeIndex, setActiveIndex] = useState<number | null>(null)

  // Transform allocations to chart data
  const chartData: ChartData[] = allocations.map((allocation) => ({
    name: allocation.token,
    value: allocation.weight,
    symbol: allocation.symbol,
    allocation
  }))

  const handlePieEnter = (_: any, index: number) => {
    if (interactive) {
      setActiveIndex(index)
    }
  }

  const handlePieLeave = () => {
    setActiveIndex(null)
  }

  const handleClick = (data: ChartData) => {
    if (interactive && onSliceClick) {
      onSliceClick(data.allocation)
    }
  }

  return (
    <div className="relative" style={{ width: size, height: size }} data-testid="pie-chart">
      <ResponsiveContainer width="100%" height="100%">
        <RechartsPieChart>
          <Pie
            data={chartData}
            cx="50%"
            cy="50%"
            labelLine={false}
            label={CustomLabel}
            outerRadius={size / 3}
            fill="#8884d8"
            dataKey="value"
            animationBegin={0}
            animationDuration={500}
            onClick={(data) => handleClick(data)}
            onMouseEnter={handlePieEnter}
            onMouseLeave={handlePieLeave}
          >
            {chartData.map((entry, index) => (
              <Cell 
                key={`cell-${index}`} 
                fill={COLORS[index % COLORS.length]}
                stroke={activeIndex === index ? '#fff' : 'none'}
                strokeWidth={activeIndex === index ? 2 : 0}
                style={{
                  filter: activeIndex === index ? 'brightness(1.1)' : 'none',
                  cursor: interactive ? 'pointer' : 'default',
                  transition: 'all 0.2s ease'
                }}
              />
            ))}
          </Pie>
          <Tooltip content={<CustomTooltip />} />
          {showLegend && (
            <Legend 
              verticalAlign="bottom" 
              height={36}
              formatter={(value: string, entry: any) => (
                <span className="text-sm text-gray-300">
                  {entry.payload.symbol}
                </span>
              )}
            />
          )}
        </RechartsPieChart>
      </ResponsiveContainer>
      
      {/* Center value display */}
      <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
        <div className="text-center">
          <p className="text-2xl font-bold text-gray-900 dark:text-white">
            {allocations.length}
          </p>
          <p className="text-xs text-gray-500 dark:text-gray-400">
            Assets
          </p>
        </div>
      </div>
    </div>
  )
}