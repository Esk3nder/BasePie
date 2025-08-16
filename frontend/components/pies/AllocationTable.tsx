'use client'

// SCAFFOLD: Sortable table for pie allocations
// PSEUDOCODE:
// - Display token, weight, value, price
// - Sort by weight/value/name
// - Editable weights in builder mode
// - Total row showing sums

import React from 'react'
import type { MockAllocation } from '@/lib/mocks/types'

interface AllocationTableProps {
  allocations: MockAllocation[]
  editable?: boolean
  onWeightChange?: (index: number, weight: number) => void
  onRemove?: (index: number) => void
}

export function AllocationTable({ 
  allocations, 
  editable = false,
  onWeightChange,
  onRemove 
}: AllocationTableProps) {
  // TODO: Implement sorting state
  // TODO: Render table with headers
  // TODO: Calculate totals
  // TODO: Handle weight editing
  throw new Error('Not implemented: AllocationTable')
}