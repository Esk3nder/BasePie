'use client'

import React, { useState, useEffect, useCallback } from 'react'
import type { MockAllocation } from '@/lib/mocks/types'

interface WeightSliderProps {
  allocations: MockAllocation[]
  onChange: (allocations: MockAllocation[]) => void
  maxTotal?: number
}

export function WeightSlider({ allocations, onChange, maxTotal = 10000 }: WeightSliderProps) {
  const [localAllocations, setLocalAllocations] = useState(allocations)
  const [isDragging, setIsDragging] = useState(false)
  
  // Calculate total weight
  const totalWeight = localAllocations.reduce((sum, a) => sum + a.weight, 0)
  const isOverweight = totalWeight > maxTotal
  const totalPercentage = (totalWeight / 100).toFixed(2)
  
  useEffect(() => {
    setLocalAllocations(allocations)
  }, [allocations])

  const handleWeightChange = useCallback((index: number, newWeight: number) => {
    const updated = [...localAllocations]
    updated[index] = { ...updated[index], weight: Math.max(0, Math.min(maxTotal, newWeight)) }
    setLocalAllocations(updated)
    
    // Debounced onChange
    const timer = setTimeout(() => {
      onChange(updated)
    }, 200)
    
    return () => clearTimeout(timer)
  }, [localAllocations, onChange, maxTotal])

  const normalizeWeights = useCallback(() => {
    if (totalWeight === 0) return
    
    const normalized = localAllocations.map(allocation => ({
      ...allocation,
      weight: Math.round((allocation.weight / totalWeight) * maxTotal)
    }))
    
    // Adjust for rounding errors
    const normalizedTotal = normalized.reduce((sum, a) => sum + a.weight, 0)
    if (normalizedTotal !== maxTotal && normalized.length > 0) {
      normalized[0].weight += maxTotal - normalizedTotal
    }
    
    setLocalAllocations(normalized)
    onChange(normalized)
  }, [localAllocations, totalWeight, maxTotal, onChange])

  const distributeEvenly = useCallback(() => {
    const evenWeight = Math.floor(maxTotal / localAllocations.length)
    const remainder = maxTotal - (evenWeight * localAllocations.length)
    
    const distributed = localAllocations.map((allocation, index) => ({
      ...allocation,
      weight: evenWeight + (index === 0 ? remainder : 0)
    }))
    
    setLocalAllocations(distributed)
    onChange(distributed)
  }, [localAllocations, maxTotal, onChange])

  return (
    <div className="space-y-4">
      {/* Total allocation bar */}
      <div className="mb-4">
        <div className="flex justify-between items-center mb-2">
          <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
            Total Allocation
          </span>
          <span className={`text-sm font-bold ${isOverweight ? 'text-red-500' : totalWeight === maxTotal ? 'text-green-500' : 'text-yellow-500'}`}>
            {totalPercentage}%
          </span>
        </div>
        <div className="w-full h-3 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
          <div 
            className={`h-full transition-all duration-300 ${
              isOverweight ? 'bg-red-500' : totalWeight === maxTotal ? 'bg-green-500' : 'bg-yellow-500'
            }`}
            style={{ width: `${Math.min(100, (totalWeight / maxTotal) * 100)}%` }}
          />
        </div>
        {isOverweight && (
          <p className="text-xs text-red-500 mt-1">
            Allocation exceeds 100% by {((totalWeight - maxTotal) / 100).toFixed(2)}%
          </p>
        )}
      </div>

      {/* Individual sliders */}
      <div className="space-y-3">
        {localAllocations.map((allocation, index) => {
          const percentage = (allocation.weight / 100).toFixed(2)
          
          return (
            <div key={allocation.address} className="space-y-1">
              <div className="flex justify-between items-center">
                <div className="flex items-center gap-2">
                  <div className="w-6 h-6 rounded-full bg-gradient-to-br from-blue-500 to-purple-500 flex items-center justify-center text-white text-xs font-bold">
                    {allocation.symbol.slice(0, 2)}
                  </div>
                  <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
                    {allocation.symbol}
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <input
                    type="number"
                    value={percentage}
                    onChange={(e) => {
                      const newWeight = Math.round(parseFloat(e.target.value) * 100)
                      if (!isNaN(newWeight)) {
                        handleWeightChange(index, newWeight)
                      }
                    }}
                    className="w-16 px-2 py-1 text-sm text-right border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-800"
                    step="0.01"
                    min="0"
                    max="100"
                  />
                  <span className="text-sm text-gray-500">%</span>
                </div>
              </div>
              
              <div className="relative">
                <input
                  type="range"
                  min="0"
                  max={maxTotal}
                  step="100"
                  value={allocation.weight}
                  onChange={(e) => handleWeightChange(index, parseInt(e.target.value))}
                  onMouseDown={() => setIsDragging(true)}
                  onMouseUp={() => setIsDragging(false)}
                  className="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer slider"
                  style={{
                    background: `linear-gradient(to right, #3B82F6 0%, #3B82F6 ${(allocation.weight / maxTotal) * 100}%, #E5E7EB ${(allocation.weight / maxTotal) * 100}%, #E5E7EB 100%)`
                  }}
                />
                <div 
                  className="absolute top-0 left-0 h-2 bg-blue-500 rounded-l-lg pointer-events-none transition-all"
                  style={{ width: `${(allocation.weight / maxTotal) * 100}%` }}
                />
              </div>
            </div>
          )
        })}
      </div>

      {/* Action buttons */}
      <div className="flex gap-2 pt-4">
        <button
          onClick={normalizeWeights}
          disabled={totalWeight === maxTotal}
          className="px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white rounded-lg text-sm font-medium transition-colors"
        >
          Normalize to 100%
        </button>
        <button
          onClick={distributeEvenly}
          className="px-4 py-2 bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 rounded-lg text-sm font-medium transition-colors"
        >
          Distribute Evenly
        </button>
      </div>

      {/* Helper text */}
      <div className="text-xs text-gray-500 dark:text-gray-400">
        <p>💡 Tip: Drag sliders or enter exact percentages to adjust allocations</p>
        {totalWeight !== maxTotal && (
          <p className="mt-1">
            {totalWeight < maxTotal 
              ? `You have ${((maxTotal - totalWeight) / 100).toFixed(2)}% remaining to allocate`
              : `Click "Normalize" to automatically adjust to 100%`
            }
          </p>
        )}
      </div>
    </div>
  )
}