'use client'

import React, { useState, useMemo } from 'react'
import Link from 'next/link'
import { useMockPies } from '@/lib/mocks/hooks'
import { PieCard } from '@/components/pies/PieCard'

type SortOption = 'tvl' | 'performance' | 'name' | 'assets'

export default function PiesPage() {
  const { data: pies, isLoading, error, refetch } = useMockPies()
  const [searchTerm, setSearchTerm] = useState('')
  const [sortBy, setSortBy] = useState<SortOption>('tvl')
  const [showOnlyPositive, setShowOnlyPositive] = useState(false)
  
  // Filter and sort pies
  const filteredAndSortedPies = useMemo(() => {
    let filtered = pies || []
    
    // Apply search filter
    if (searchTerm) {
      filtered = filtered.filter(pie => 
        pie.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        pie.symbol.toLowerCase().includes(searchTerm.toLowerCase()) ||
        pie.allocations.some(a => 
          a.symbol.toLowerCase().includes(searchTerm.toLowerCase())
        )
      )
    }
    
    // Apply performance filter
    if (showOnlyPositive) {
      filtered = filtered.filter(pie => (pie.performance?.day || 0) > 0)
    }
    
    // Sort
    const sorted = [...filtered].sort((a, b) => {
      switch (sortBy) {
        case 'tvl':
          return b.tvl - a.tvl
        case 'performance':
          return (b.performance?.day || 0) - (a.performance?.day || 0)
        case 'name':
          return a.name.localeCompare(b.name)
        case 'assets':
          return b.allocations.length - a.allocations.length
        default:
          return 0
      }
    })
    
    return sorted
  }, [pies, searchTerm, sortBy, showOnlyPositive])
  
  // Loading state
  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="flex items-center justify-center h-64">
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
            <p className="text-gray-600 dark:text-gray-400">Loading pies...</p>
          </div>
        </div>
      </div>
    )
  }
  
  // Error state
  if (error) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-6">
          <h2 className="text-red-800 dark:text-red-200 font-semibold mb-2">Error loading pies</h2>
          <p className="text-red-600 dark:text-red-300 mb-4">{error.message}</p>
          <button
            onClick={refetch}
            className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg"
          >
            Try Again
          </button>
        </div>
      </div>
    )
  }
  
  return (
    <div className="container mx-auto px-4 py-8">
      {/* Header */}
      <div className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">
            Explore Pies
          </h1>
          <p className="text-gray-600 dark:text-gray-400">
            Discover and invest in curated token portfolios
          </p>
        </div>
        <Link
          href="/builder"
          className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors"
        >
          Create Pie
        </Link>
      </div>
      
      {/* Filters and Search */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow-sm p-4 mb-6">
        <div className="flex flex-col md:flex-row gap-4">
          {/* Search */}
          <div className="flex-1">
            <input
              type="text"
              placeholder="Search by name, symbol, or asset..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-500"
            />
          </div>
          
          {/* Sort */}
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value as SortOption)}
            className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
          >
            <option value="tvl">Sort by TVL</option>
            <option value="performance">Sort by Performance</option>
            <option value="name">Sort by Name</option>
            <option value="assets">Sort by Assets</option>
          </select>
          
          {/* Filter */}
          <label className="flex items-center gap-2 px-4 py-2">
            <input
              type="checkbox"
              checked={showOnlyPositive}
              onChange={(e) => setShowOnlyPositive(e.target.checked)}
              className="w-4 h-4"
            />
            <span className="text-sm text-gray-700 dark:text-gray-300">
              Positive 24h only
            </span>
          </label>
        </div>
      </div>
      
      {/* Stats Bar */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <div className="bg-white dark:bg-gray-900 rounded-lg p-4">
          <p className="text-sm text-gray-500 dark:text-gray-400">Total Pies</p>
          <p className="text-2xl font-bold text-gray-900 dark:text-white">
            {pies?.length || 0}
          </p>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-lg p-4">
          <p className="text-sm text-gray-500 dark:text-gray-400">Total TVL</p>
          <p className="text-2xl font-bold text-gray-900 dark:text-white">
            ${((pies?.reduce((sum, p) => sum + p.tvl, 0) || 0) / 1000000).toFixed(1)}M
          </p>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-lg p-4">
          <p className="text-sm text-gray-500 dark:text-gray-400">Avg Performance</p>
          <p className="text-2xl font-bold text-gray-900 dark:text-white">
            {(pies?.reduce((sum, p) => sum + (p.performance?.day || 0), 0) / (pies?.length || 1)).toFixed(2)}%
          </p>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-lg p-4">
          <p className="text-sm text-gray-500 dark:text-gray-400">Results</p>
          <p className="text-2xl font-bold text-gray-900 dark:text-white">
            {filteredAndSortedPies.length}
          </p>
        </div>
      </div>
      
      {/* Pies Grid */}
      {filteredAndSortedPies.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          {filteredAndSortedPies.map((pie) => (
            <PieCard
              key={pie.id}
              pie={pie}
              showActions
              onInvest={() => {
                // Navigate to pie detail with invest modal
                window.location.href = `/pies/${pie.id}?action=invest`
              }}
              onShare={() => {
                // Copy link to clipboard
                navigator.clipboard.writeText(`${window.location.origin}/pies/${pie.id}`)
                alert('Link copied to clipboard!')
              }}
            />
          ))}
        </div>
      ) : (
        <div className="text-center py-12">
          <p className="text-gray-500 dark:text-gray-400 mb-4">
            No pies found matching your criteria
          </p>
          <button
            onClick={() => {
              setSearchTerm('')
              setShowOnlyPositive(false)
            }}
            className="text-blue-600 hover:text-blue-700 font-medium"
          >
            Clear filters
          </button>
        </div>
      )}
    </div>
  )
}