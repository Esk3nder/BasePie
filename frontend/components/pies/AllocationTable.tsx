'use client'

import React, { useState, useMemo } from 'react'
import type { MockAllocation } from '@/lib/mocks/types'

interface AllocationTableProps {
  allocations: MockAllocation[]
  editable?: boolean
  onWeightChange?: (index: number, weight: number) => void
  onRemove?: (index: number) => void
}

type SortField = 'symbol' | 'weight' | 'value' | 'price'
type SortDirection = 'asc' | 'desc'

export function AllocationTable({ 
  allocations, 
  editable = false,
  onWeightChange,
  onRemove 
}: AllocationTableProps) {
  const [sortField, setSortField] = useState<SortField>('weight')
  const [sortDirection, setSortDirection] = useState<SortDirection>('desc')
  const [editingIndex, setEditingIndex] = useState<number | null>(null)
  const [tempWeight, setTempWeight] = useState<string>('')

  // Sort allocations
  const sortedAllocations = useMemo(() => {
    const sorted = [...allocations].sort((a, b) => {
      let aVal: any, bVal: any
      
      switch (sortField) {
        case 'symbol':
          aVal = a.symbol
          bVal = b.symbol
          break
        case 'weight':
          aVal = a.weight
          bVal = b.weight
          break
        case 'value':
          aVal = a.currentValue
          bVal = b.currentValue
          break
        case 'price':
          aVal = a.price
          bVal = b.price
          break
      }
      
      if (sortDirection === 'asc') {
        return aVal > bVal ? 1 : -1
      } else {
        return aVal < bVal ? 1 : -1
      }
    })
    
    return sorted
  }, [allocations, sortField, sortDirection])

  // Calculate totals
  const totalWeight = allocations.reduce((sum, a) => sum + a.weight, 0)
  const totalValue = allocations.reduce((sum, a) => sum + a.currentValue, 0)

  const handleSort = (field: SortField) => {
    if (sortField === field) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc')
    } else {
      setSortField(field)
      setSortDirection('desc')
    }
  }

  const handleEditStart = (index: number, weight: number) => {
    setEditingIndex(index)
    setTempWeight((weight / 100).toString())
  }

  const handleEditSave = (index: number) => {
    const newWeight = parseFloat(tempWeight) * 100
    if (!isNaN(newWeight) && newWeight >= 0 && newWeight <= 10000) {
      onWeightChange?.(index, Math.round(newWeight))
    }
    setEditingIndex(null)
    setTempWeight('')
  }

  const handleEditCancel = () => {
    setEditingIndex(null)
    setTempWeight('')
  }

  const SortIcon = ({ field }: { field: SortField }) => {
    if (sortField !== field) {
      return <span className="text-gray-400">↕</span>
    }
    return <span>{sortDirection === 'asc' ? '↑' : '↓'}</span>
  }

  return (
    <div className="w-full overflow-x-auto">
      <table className="w-full text-sm">
        <thead className="border-b border-gray-200 dark:border-gray-700">
          <tr>
            <th 
              className="text-left py-3 px-4 font-medium cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800"
              onClick={() => handleSort('symbol')}
            >
              <div className="flex items-center gap-1">
                Token <SortIcon field="symbol" />
              </div>
            </th>
            <th 
              className="text-right py-3 px-4 font-medium cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800"
              onClick={() => handleSort('weight')}
            >
              <div className="flex items-center justify-end gap-1">
                Weight <SortIcon field="weight" />
              </div>
            </th>
            <th 
              className="text-right py-3 px-4 font-medium cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800"
              onClick={() => handleSort('value')}
            >
              <div className="flex items-center justify-end gap-1">
                Value <SortIcon field="value" />
              </div>
            </th>
            <th 
              className="text-right py-3 px-4 font-medium cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800"
              onClick={() => handleSort('price')}
            >
              <div className="flex items-center justify-end gap-1">
                Price <SortIcon field="price" />
              </div>
            </th>
            {editable && <th className="w-20"></th>}
          </tr>
        </thead>
        <tbody>
          {sortedAllocations.map((allocation, index) => {
            const originalIndex = allocations.indexOf(allocation)
            const isEditing = editingIndex === originalIndex
            
            return (
              <tr 
                key={allocation.address}
                className="border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-900"
              >
                <td className="py-3 px-4">
                  <div className="flex items-center gap-2">
                    <div className="w-8 h-8 rounded-full bg-gradient-to-br from-blue-500 to-purple-500 flex items-center justify-center text-white text-xs font-bold">
                      {allocation.symbol.slice(0, 2)}
                    </div>
                    <div>
                      <div className="font-medium">{allocation.symbol}</div>
                      <div className="text-xs text-gray-500">{allocation.token}</div>
                    </div>
                  </div>
                </td>
                <td className="py-3 px-4 text-right">
                  {editable && isEditing ? (
                    <div className="flex items-center justify-end gap-1">
                      <input
                        type="number"
                        value={tempWeight}
                        onChange={(e) => setTempWeight(e.target.value)}
                        className="w-20 px-2 py-1 border rounded text-right"
                        step="0.01"
                        min="0"
                        max="100"
                        autoFocus
                        onKeyDown={(e) => {
                          if (e.key === 'Enter') handleEditSave(originalIndex)
                          if (e.key === 'Escape') handleEditCancel()
                        }}
                      />
                      <span>%</span>
                    </div>
                  ) : (
                    <div 
                      className={editable ? 'cursor-pointer hover:text-blue-600' : ''}
                      onClick={() => editable && handleEditStart(originalIndex, allocation.weight)}
                    >
                      {(allocation.weight / 100).toFixed(2)}%
                    </div>
                  )}
                </td>
                <td className="py-3 px-4 text-right">
                  ${allocation.currentValue.toLocaleString()}
                </td>
                <td className="py-3 px-4 text-right">
                  ${allocation.price.toLocaleString()}
                </td>
                {editable && (
                  <td className="py-3 px-4">
                    {isEditing ? (
                      <div className="flex gap-1">
                        <button
                          onClick={() => handleEditSave(originalIndex)}
                          className="px-2 py-1 bg-green-500 text-white rounded text-xs hover:bg-green-600"
                        >
                          ✓
                        </button>
                        <button
                          onClick={handleEditCancel}
                          className="px-2 py-1 bg-red-500 text-white rounded text-xs hover:bg-red-600"
                        >
                          ✕
                        </button>
                      </div>
                    ) : (
                      <button
                        onClick={() => onRemove?.(originalIndex)}
                        className="px-2 py-1 bg-red-500 text-white rounded text-xs hover:bg-red-600"
                      >
                        Remove
                      </button>
                    )}
                  </td>
                )}
              </tr>
            )
          })}
        </tbody>
        <tfoot className="border-t-2 border-gray-300 dark:border-gray-600">
          <tr className="font-semibold">
            <td className="py-3 px-4">Total</td>
            <td className="py-3 px-4 text-right">
              <span className={totalWeight !== 10000 ? 'text-red-500' : ''}>
                {(totalWeight / 100).toFixed(2)}%
              </span>
            </td>
            <td className="py-3 px-4 text-right">
              ${totalValue.toLocaleString()}
            </td>
            <td className="py-3 px-4"></td>
            {editable && <td></td>}
          </tr>
        </tfoot>
      </table>
      
      {editable && totalWeight !== 10000 && (
        <div className="mt-2 p-2 bg-yellow-100 dark:bg-yellow-900/20 rounded text-sm text-yellow-800 dark:text-yellow-200">
          ⚠️ Weights must sum to 100% (currently {(totalWeight / 100).toFixed(2)}%)
        </div>
      )}
    </div>
  )
}