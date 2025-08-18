'use client'

import React, { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useMockCreatePie } from '@/lib/mocks/hooks'
import { TOKEN_LIST } from '@/lib/mocks/generators'
import { WeightSlider } from '@/components/pies/WeightSlider'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Separator } from '@/components/ui/separator'
import type { MockAllocation } from '@/lib/mocks/types'

interface FormData {
  name: string
  symbol: string
  selectedTokens: typeof TOKEN_LIST[0][]
  allocations: MockAllocation[]
}

interface ValidationErrors {
  name?: string
  symbol?: string
  tokens?: string
  weights?: string
}

export default function BuilderPage() {
  const router = useRouter()
  const { createPie, isPending, error: createError } = useMockCreatePie()
  
  // Form state
  const [formData, setFormData] = useState<FormData>({
    name: '',
    symbol: '',
    selectedTokens: [],
    allocations: []
  })
  
  const [errors, setErrors] = useState<ValidationErrors>({})
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleNameChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newName = e.target.value
    setFormData(prev => ({ ...prev, name: newName }))
    if (errors.name && newName) {
      setErrors(prev => ({ ...prev, name: undefined }))
    }
  }

  const handleSymbolChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newSymbol = e.target.value.toUpperCase()
    setFormData(prev => ({ ...prev, symbol: newSymbol }))
    if (errors.symbol && newSymbol) {
      setErrors(prev => ({ ...prev, symbol: undefined }))
    }
  }

  const handleAddToken = (token: typeof TOKEN_LIST[0]) => {
    if (formData.selectedTokens.some(t => t.address === token.address)) {
      return // Already selected
    }
    
    const newTokens = [...formData.selectedTokens, token]
    const newAllocation: MockAllocation = {
      token: token.address,
      symbol: token.symbol,
      address: token.address,
      weight: 0,
      currentValue: 0,
      targetValue: 0,
      price: token.price || 0
    }
    const newAllocations = [...formData.allocations, newAllocation]
    
    setFormData(prev => ({
      ...prev,
      selectedTokens: newTokens,
      allocations: newAllocations
    }))
    
    if (newTokens.length >= 2 && errors.tokens) {
      setErrors(prev => ({ ...prev, tokens: undefined }))
    }
  }

  const handleRemoveToken = (tokenAddress: string) => {
    const newTokens = formData.selectedTokens.filter(t => t.address !== tokenAddress)
    const newAllocations = formData.allocations.filter(a => a.address !== tokenAddress)
    
    setFormData(prev => ({
      ...prev,
      selectedTokens: newTokens,
      allocations: newAllocations
    }))
  }

  const handleAllocationsChange = (newAllocations: MockAllocation[]) => {
    setFormData(prev => ({ ...prev, allocations: newAllocations }))
    
    const totalWeight = newAllocations.reduce((sum, a) => sum + a.weight, 0)
    if (totalWeight === 10000 && errors.weights) {
      setErrors(prev => ({ ...prev, weights: undefined }))
    }
  }

  const validateForm = (): boolean => {
    const newErrors: ValidationErrors = {}
    
    if (!formData.name.trim()) {
      newErrors.name = 'Pie name is required'
    }
    
    if (!formData.symbol.trim()) {
      newErrors.symbol = 'Symbol is required'
    }
    
    if (formData.selectedTokens.length < 2) {
      newErrors.tokens = 'At least 2 tokens required'
    }
    
    const totalWeight = formData.allocations.reduce((sum, a) => sum + a.weight, 0)
    if (totalWeight !== 10000) {
      newErrors.weights = `Weights must equal 100% (currently ${(totalWeight / 100).toFixed(2)}%)`
    }
    
    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = async () => {
    if (!validateForm()) {
      return
    }
    
    setIsSubmitting(true)
    
    try {
      const result = await createPie({
        name: formData.name,
        symbol: formData.symbol,
        allocations: formData.allocations
      })
      
      console.log('Pie created successfully:', result)
      router.push('/pies')
    } catch (error) {
      console.error('Failed to create pie:', error)
      // Error is handled by the hook's error state
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="container mx-auto max-w-4xl py-8 px-4">
      <Card>
        <CardHeader>
          <CardTitle className="text-2xl">Create New Pie</CardTitle>
          <CardDescription>
            Design your own portfolio allocation strategy
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* Pie Details Section */}
          <div className="space-y-4">
            <h3 className="text-lg font-semibold">Pie Details</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="name">Pie Name</Label>
                <Input
                  id="name"
                  placeholder="e.g., DeFi Blue Chips"
                  value={formData.name}
                  onChange={handleNameChange}
                  aria-invalid={!!errors.name}
                />
                {errors.name && (
                  <p className="text-sm text-red-500">{errors.name}</p>
                )}
              </div>
              <div className="space-y-2">
                <Label htmlFor="symbol">Symbol</Label>
                <Input
                  id="symbol"
                  placeholder="e.g., DEFIPIE"
                  value={formData.symbol}
                  onChange={handleSymbolChange}
                  aria-invalid={!!errors.symbol}
                />
                {errors.symbol && (
                  <p className="text-sm text-red-500">{errors.symbol}</p>
                )}
              </div>
            </div>
          </div>

          <Separator />

          {/* Token Selection Section */}
          <div className="space-y-4">
            <h3 className="text-lg font-semibold">Select Tokens</h3>
            <div className="space-y-4">
              {/* Available Tokens */}
              <div>
                <p className="text-sm text-gray-600 mb-2">Available Tokens</p>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                  {TOKEN_LIST.map((token) => {
                    const isSelected = formData.selectedTokens.some(
                      t => t.address === token.address
                    )
                    return (
                      <Button
                        key={token.address}
                        variant={isSelected ? "default" : "outline"}
                        size="sm"
                        onClick={() => !isSelected && handleAddToken(token)}
                        disabled={isSelected}
                        className="justify-start"
                      >
                        {token.symbol}
                      </Button>
                    )
                  })}
                </div>
              </div>

              {/* Selected Tokens */}
              {formData.selectedTokens.length > 0 && (
                <div>
                  <p className="text-sm text-gray-600 mb-2">
                    Selected Tokens ({formData.selectedTokens.length})
                  </p>
                  <div className="flex flex-wrap gap-2">
                    {formData.selectedTokens.map((token) => (
                      <div
                        key={token.address}
                        className="flex items-center gap-1 px-3 py-1 bg-blue-100 dark:bg-blue-900 rounded-full"
                      >
                        <span className="text-sm font-medium">{token.symbol}</span>
                        <button
                          onClick={() => handleRemoveToken(token.address)}
                          className="text-red-500 hover:text-red-700"
                          aria-label={`Remove ${token.symbol}`}
                        >
                          ×
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              )}
              {errors.tokens && (
                <p className="text-sm text-red-500">{errors.tokens}</p>
              )}
            </div>
          </div>

          <Separator />

          {/* Weight Allocation Section */}
          {formData.selectedTokens.length >= 2 && (
            <>
              <div className="space-y-4">
                <h3 className="text-lg font-semibold">Allocate Weights</h3>
                <WeightSlider
                  allocations={formData.allocations}
                  onChange={handleAllocationsChange}
                  maxTotal={10000}
                />
                {errors.weights && (
                  <p className="text-sm text-red-500 mt-2">{errors.weights}</p>
                )}
              </div>
              <Separator />
            </>
          )}

          {/* Submit Section */}
          <div className="flex justify-end gap-4">
            <Button
              variant="outline"
              onClick={() => router.push('/pies')}
              disabled={isSubmitting}
            >
              Cancel
            </Button>
            <Button
              onClick={handleSubmit}
              disabled={isSubmitting || isPending}
            >
              {isPending ? 'Creating...' : 'Create Pie'}
            </Button>
          </div>

          {/* Error Display */}
          {createError && (
            <div className="p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg">
              <p className="text-sm text-red-600 dark:text-red-400">
                {createError.message}
              </p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}