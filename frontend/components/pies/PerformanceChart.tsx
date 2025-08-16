'use client'

import React, { useState } from 'react'
import { LineChart, Line, Area, AreaChart, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Bar, BarChart, ComposedChart } from 'recharts'

interface PerformanceData {
  date: string
  value: number
  volume?: number
}

interface PerformanceChartProps {
  data: PerformanceData[]
  timeframe?: '24h' | '7d' | '30d' | '1y'
  showVolume?: boolean
  height?: number
}

const CustomTooltip = ({ active, payload, label }: any) => {
  if (active && payload && payload[0]) {
    return (
      <div className="bg-gray-900/95 backdrop-blur-sm p-3 rounded-lg shadow-xl border border-gray-700">
        <p className="text-white text-sm">{label}</p>
        <p className="text-green-400 font-semibold">
          ${payload[0].value.toLocaleString()}
        </p>
        {payload[1] && (
          <p className="text-gray-400 text-xs">
            Vol: ${payload[1].value.toLocaleString()}
          </p>
        )}
      </div>
    )
  }
  return null
}

export function PerformanceChart({ 
  data, 
  timeframe = '7d',
  showVolume = false,
  height = 300
}: PerformanceChartProps) {
  const [selectedTimeframe, setSelectedTimeframe] = useState(timeframe)
  
  // Calculate performance metrics
  const firstValue = data[0]?.value || 0
  const lastValue = data[data.length - 1]?.value || 0
  const change = lastValue - firstValue
  const changePercent = firstValue > 0 ? (change / firstValue) * 100 : 0
  const isPositive = change >= 0
  
  // Find min and max for better chart scaling
  const values = data.map(d => d.value)
  const minValue = Math.min(...values) * 0.95
  const maxValue = Math.max(...values) * 1.05
  
  const timeframeButtons: Array<typeof timeframe> = ['24h', '7d', '30d', '1y']
  
  return (
    <div className="w-full">
      {/* Header with timeframe selector */}
      <div className="flex justify-between items-center mb-4">
        <div>
          <p className="text-2xl font-bold text-gray-900 dark:text-white">
            ${lastValue.toLocaleString()}
          </p>
          <p className={`text-sm ${isPositive ? 'text-green-500' : 'text-red-500'}`}>
            {isPositive ? '+' : ''}{change.toFixed(2)} ({changePercent.toFixed(2)}%)
          </p>
        </div>
        
        <div className="flex gap-1">
          {timeframeButtons.map((tf) => (
            <button
              key={tf}
              onClick={() => setSelectedTimeframe(tf)}
              className={`px-3 py-1 text-sm rounded-lg transition-colors ${
                selectedTimeframe === tf
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600'
              }`}
            >
              {tf}
            </button>
          ))}
        </div>
      </div>
      
      {/* Chart */}
      <ResponsiveContainer width="100%" height={height}>
        {showVolume ? (
          <ComposedChart data={data} margin={{ top: 5, right: 5, left: 5, bottom: 5 }}>
            <defs>
              <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor={isPositive ? '#10B981' : '#EF4444'} stopOpacity={0.8}/>
                <stop offset="95%" stopColor={isPositive ? '#10B981' : '#EF4444'} stopOpacity={0.1}/>
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#374151" opacity={0.3} />
            <XAxis 
              dataKey="date" 
              stroke="#9CA3AF"
              tick={{ fontSize: 12 }}
              tickFormatter={(value) => {
                // Format date based on timeframe
                if (selectedTimeframe === '24h') {
                  return value.split(' ')[1] || value // Show time
                }
                return value.split(' ')[0] // Show date
              }}
            />
            <YAxis 
              yAxisId="left"
              stroke="#9CA3AF"
              tick={{ fontSize: 12 }}
              domain={[minValue, maxValue]}
              tickFormatter={(value) => `$${value}`}
            />
            <YAxis 
              yAxisId="right"
              orientation="right"
              stroke="#9CA3AF"
              tick={{ fontSize: 12 }}
              tickFormatter={(value) => `${(value / 1000).toFixed(0)}k`}
            />
            <Tooltip content={<CustomTooltip />} />
            
            <Bar 
              yAxisId="right"
              dataKey="volume" 
              fill="#6366F1"
              opacity={0.3}
            />
            
            <Area
              yAxisId="left"
              type="monotone"
              dataKey="value"
              stroke={isPositive ? '#10B981' : '#EF4444'}
              strokeWidth={2}
              fill="url(#colorValue)"
            />
          </ComposedChart>
        ) : (
          <AreaChart data={data} margin={{ top: 5, right: 5, left: 5, bottom: 5 }}>
            <defs>
              <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor={isPositive ? '#10B981' : '#EF4444'} stopOpacity={0.8}/>
                <stop offset="95%" stopColor={isPositive ? '#10B981' : '#EF4444'} stopOpacity={0.1}/>
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#374151" opacity={0.3} />
            <XAxis 
              dataKey="date" 
              stroke="#9CA3AF"
              tick={{ fontSize: 12 }}
              tickFormatter={(value) => {
                // Format date based on timeframe
                if (selectedTimeframe === '24h') {
                  return value.split(' ')[1] || value // Show time
                }
                return value.split(' ')[0] // Show date
              }}
            />
            <YAxis 
              stroke="#9CA3AF"
              tick={{ fontSize: 12 }}
              domain={[minValue, maxValue]}
              tickFormatter={(value) => `$${value}`}
            />
            <Tooltip content={<CustomTooltip />} />
            <Area
              type="monotone"
              dataKey="value"
              stroke={isPositive ? '#10B981' : '#EF4444'}
              strokeWidth={2}
              fill="url(#colorValue)"
            />
          </AreaChart>
        )}
      </ResponsiveContainer>
      
      {/* Stats */}
      <div className="grid grid-cols-4 gap-4 mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
        <div>
          <p className="text-xs text-gray-500 dark:text-gray-400">High</p>
          <p className="text-sm font-medium text-gray-900 dark:text-white">
            ${Math.max(...values).toLocaleString()}
          </p>
        </div>
        <div>
          <p className="text-xs text-gray-500 dark:text-gray-400">Low</p>
          <p className="text-sm font-medium text-gray-900 dark:text-white">
            ${Math.min(...values).toLocaleString()}
          </p>
        </div>
        <div>
          <p className="text-xs text-gray-500 dark:text-gray-400">Avg</p>
          <p className="text-sm font-medium text-gray-900 dark:text-white">
            ${(values.reduce((a, b) => a + b, 0) / values.length).toLocaleString()}
          </p>
        </div>
        {showVolume && (
          <div>
            <p className="text-xs text-gray-500 dark:text-gray-400">Volume</p>
            <p className="text-sm font-medium text-gray-900 dark:text-white">
              ${(data.reduce((sum, d) => sum + (d.volume || 0), 0) / 1000000).toFixed(1)}M
            </p>
          </div>
        )}
      </div>
    </div>
  )
}