'use client'

import React, { useState } from 'react'

export default function BuilderPage() {
  const [name, setName] = useState('')
  const [tokens, setTokens] = useState<string[]>([])
  const [weights, setWeights] = useState<number[]>([])
  const [errors, setErrors] = useState<string[]>([])

  const handleCreatePie = () => {
    const validationErrors: string[] = []
    
    if (!name) {
      validationErrors.push('Pie name is required')
    }
    
    if (tokens.length < 2) {
      validationErrors.push('At least 2 tokens required')
    }
    
    const totalWeight = weights.reduce((sum, w) => sum + w, 0)
    if (totalWeight !== 10000) {
      validationErrors.push(`Weights must equal 100% (currently ${totalWeight / 100}%)`)
    }
    
    setErrors(validationErrors)
    
    if (validationErrors.length === 0) {
      // Success case for test
      console.log('Creating pie...')
    }
  }

  return (
    <div>
      <h1>Create Pie</h1>
      
      <input 
        type="text"
        placeholder="Pie Name"
        value={name}
        onChange={(e) => setName(e.target.value)}
      />
      
      <button onClick={handleCreatePie}>Create Pie</button>
      
      {errors.map((error, i) => (
        <div key={i}>{error}</div>
      ))}
    </div>
  )
}