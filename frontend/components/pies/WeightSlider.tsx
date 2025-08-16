'use client'

// SCAFFOLD: Interactive weight adjustment with sliders
// PSEUDOCODE:
// - Slider for each allocation
// - Ensure weights sum to 100%
// - Visual feedback during adjustment
// - Normalize button if over/under 100%

import React from 'react'
import type { MockAllocation } from '@/lib/mocks/types'

interface WeightSliderProps {
  allocations: MockAllocation[]
  onChange: (allocations: MockAllocation[]) => void
  maxTotal?: number
}

export function WeightSlider({ allocations, onChange, maxTotal = 10000 }: WeightSliderProps) {
  // TODO: Track local state for smooth updates
  // TODO: Implement weight adjustment logic
  // TODO: Auto-normalize when over limit
  // TODO: Visual bar showing total allocation
  throw new Error('Not implemented: WeightSlider')
}