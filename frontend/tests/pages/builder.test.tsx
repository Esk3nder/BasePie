// TEST SCAFFOLD: Builder page tests
// Expected failures until implementation

import { describe, it, expect } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import BuilderPage from '@/app/builder/page'

describe('Builder Page', () => {
  it('should validate pie name is required', async () => {
    render(<BuilderPage />)
    
    const createButton = screen.getByRole('button', { name: 'Create Pie' })
    fireEvent.click(createButton)
    
    await waitFor(() => {
      expect(screen.getByText(/name is required/i)).toBeInTheDocument()
    })
  })

  it('should validate minimum 2 tokens', async () => {
    render(<BuilderPage />)
    
    // Add only 1 token
    const createButton = screen.getByRole('button', { name: 'Create Pie' })
    fireEvent.click(createButton)
    
    await waitFor(() => {
      expect(screen.getByText(/at least 2 tokens/i)).toBeInTheDocument()
    })
  })

  it('should validate weights sum to 100%', async () => {
    render(<BuilderPage />)
    
    // Add tokens with invalid weights
    const createButton = screen.getByRole('button', { name: 'Create Pie' })
    fireEvent.click(createButton)
    
    await waitFor(() => {
      expect(screen.getByText(/must equal 100%/i)).toBeInTheDocument()
    })
  })

  it('should create pie on valid submission', async () => {
    // SHOULD FAIL: Not implemented
    render(<BuilderPage />)
    
    // Fill valid form
    // Submit
    // Check for success
  })
})