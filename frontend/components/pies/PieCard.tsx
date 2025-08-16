'use client'

// SCAFFOLD: Pie summary card for listings
// PSEUDOCODE:
// - Display name, TVL, performance
// - Show top 3 allocations
// - Quick actions: invest, share
// - Link to detail page

import React from 'react'
import type { MockPie } from '@/lib/mocks/types'

interface PieCardProps {
  pie: MockPie
  showActions?: boolean
  onInvest?: () => void
  onShare?: () => void
}

export function PieCard({ pie, showActions = false, onInvest, onShare }: PieCardProps) {
  // TODO: Render card with shadcn/ui
  // TODO: Format performance with colors
  // TODO: Show allocation preview
  // TODO: Handle action buttons
  throw new Error('Not implemented: PieCard')
}