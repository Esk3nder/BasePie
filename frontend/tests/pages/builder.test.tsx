// TEST SCAFFOLD: Builder page tests
// Expected failures until implementation

import { describe, it, expect, beforeEach, vi } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { useRouter } from 'next/navigation'
import BuilderPage from '@/app/builder/page'
import { useMockCreatePie } from '@/lib/mocks/hooks'

// Mock next/navigation
vi.mock('next/navigation', () => ({
  useRouter: vi.fn()
}))

// Mock the hooks
vi.mock('@/lib/mocks/hooks', () => ({
  useMockCreatePie: vi.fn()
}))

describe('Builder Page', () => {
  const mockPush = vi.fn()
  const mockCreatePie = vi.fn()
  
  beforeEach(() => {
    vi.clearAllMocks()
    
    ;(useRouter as any).mockReturnValue({
      push: mockPush
    })
    
    ;(useMockCreatePie as any).mockReturnValue({
      createPie: mockCreatePie,
      isPending: false,
      error: null
    })
  })

  describe('Form Rendering', () => {
    it('should render all form sections', () => {
      render(<BuilderPage />)
      
      // Check for main sections
      expect(screen.getByText('Create New Pie')).toBeInTheDocument()
      expect(screen.getByText('Pie Details')).toBeInTheDocument()
      expect(screen.getByText('Select Tokens')).toBeInTheDocument()
      expect(screen.getByText('Available Tokens')).toBeInTheDocument()
      
      // Check for inputs
      expect(screen.getByLabelText('Pie Name')).toBeInTheDocument()
      expect(screen.getByLabelText('Symbol')).toBeInTheDocument()
      
      // Check for buttons
      expect(screen.getByRole('button', { name: 'Cancel' })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Create Pie' })).toBeInTheDocument()
    })

    it('should display token selection buttons', () => {
      render(<BuilderPage />)
      
      // Should show available tokens
      expect(screen.getByRole('button', { name: 'WETH' })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'USDC' })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'WBTC' })).toBeInTheDocument()
    })
  })

  describe('Form Validation', () => {
    it('should validate pie name is required', async () => {
      render(<BuilderPage />)
      
      const createButton = screen.getByRole('button', { name: 'Create Pie' })
      fireEvent.click(createButton)
      
      await waitFor(() => {
        expect(screen.getByText('Pie name is required')).toBeInTheDocument()
      })
    })

    it('should validate symbol is required', async () => {
      render(<BuilderPage />)
      
      const nameInput = screen.getByLabelText('Pie Name')
      fireEvent.change(nameInput, { target: { value: 'Test Pie' } })
      
      const createButton = screen.getByRole('button', { name: 'Create Pie' })
      fireEvent.click(createButton)
      
      await waitFor(() => {
        expect(screen.getByText('Symbol is required')).toBeInTheDocument()
      })
    })

    it('should validate minimum 2 tokens selected', async () => {
      render(<BuilderPage />)
      
      const nameInput = screen.getByLabelText('Pie Name')
      const symbolInput = screen.getByLabelText('Symbol')
      
      fireEvent.change(nameInput, { target: { value: 'Test Pie' } })
      fireEvent.change(symbolInput, { target: { value: 'TESTPIE' } })
      
      // Add only 1 token
      const wethButton = screen.getByRole('button', { name: 'WETH' })
      fireEvent.click(wethButton)
      
      const createButton = screen.getByRole('button', { name: 'Create Pie' })
      fireEvent.click(createButton)
      
      await waitFor(() => {
        expect(screen.getByText('At least 2 tokens required')).toBeInTheDocument()
      })
    })

    it('should validate weights sum to 100%', async () => {
      render(<BuilderPage />)
      
      // Fill required fields
      const nameInput = screen.getByLabelText('Pie Name')
      const symbolInput = screen.getByLabelText('Symbol')
      
      fireEvent.change(nameInput, { target: { value: 'Test Pie' } })
      fireEvent.change(symbolInput, { target: { value: 'TESTPIE' } })
      
      // Add 2 tokens
      const wethButton = screen.getByRole('button', { name: 'WETH' })
      const usdcButton = screen.getByRole('button', { name: 'USDC' })
      
      fireEvent.click(wethButton)
      fireEvent.click(usdcButton)
      
      // Should show weight allocation section
      await waitFor(() => {
        expect(screen.getByText('Allocate Weights')).toBeInTheDocument()
      })
      
      // Submit without setting weights to 100%
      const createButton = screen.getByRole('button', { name: 'Create Pie' })
      fireEvent.click(createButton)
      
      await waitFor(() => {
        expect(screen.getByText(/Weights must equal 100%/)).toBeInTheDocument()
      })
    })
  })

  describe('Token Selection', () => {
    it('should add token to selection when clicked', async () => {
      render(<BuilderPage />)
      
      const wethButton = screen.getByRole('button', { name: 'WETH' })
      fireEvent.click(wethButton)
      
      await waitFor(() => {
        expect(screen.getByText('Selected Tokens (1)')).toBeInTheDocument()
        expect(screen.getByRole('button', { name: 'Remove WETH' })).toBeInTheDocument()
      })
    })

    it('should remove token from selection', async () => {
      render(<BuilderPage />)
      
      // Add token first
      const wethButton = screen.getByRole('button', { name: 'WETH' })
      fireEvent.click(wethButton)
      
      await waitFor(() => {
        expect(screen.getByText('Selected Tokens (1)')).toBeInTheDocument()
      })
      
      // Remove token
      const removeButton = screen.getByRole('button', { name: 'Remove WETH' })
      fireEvent.click(removeButton)
      
      await waitFor(() => {
        expect(screen.queryByText('Selected Tokens')).not.toBeInTheDocument()
      })
    })

    it('should show weight allocation after selecting 2 tokens', async () => {
      render(<BuilderPage />)
      
      const wethButton = screen.getByRole('button', { name: 'WETH' })
      const usdcButton = screen.getByRole('button', { name: 'USDC' })
      
      fireEvent.click(wethButton)
      fireEvent.click(usdcButton)
      
      await waitFor(() => {
        expect(screen.getByText('Allocate Weights')).toBeInTheDocument()
      })
    })
  })

  describe('Form Submission', () => {
    it('should create pie with valid data', async () => {
      mockCreatePie.mockResolvedValue({ id: 'test-pie-id' })
      
      render(<BuilderPage />)
      
      // Fill form
      const nameInput = screen.getByLabelText('Pie Name')
      const symbolInput = screen.getByLabelText('Symbol')
      
      fireEvent.change(nameInput, { target: { value: 'Test Pie' } })
      fireEvent.change(symbolInput, { target: { value: 'TESTPIE' } })
      
      // Add tokens
      const wethButton = screen.getByRole('button', { name: 'WETH' })
      const usdcButton = screen.getByRole('button', { name: 'USDC' })
      
      fireEvent.click(wethButton)
      fireEvent.click(usdcButton)
      
      // Wait for weight allocation to appear
      await waitFor(() => {
        expect(screen.getByText('Allocate Weights')).toBeInTheDocument()
      })
      
      // Click distribute evenly button to set weights to 100%
      const distributeButton = screen.getByRole('button', { name: 'Distribute Evenly' })
      fireEvent.click(distributeButton)
      
      // Wait a bit for the weights to update
      await new Promise(resolve => setTimeout(resolve, 300))
      
      // Submit
      const createButton = screen.getByRole('button', { name: 'Create Pie' })
      fireEvent.click(createButton)
      
      await waitFor(() => {
        expect(mockCreatePie).toHaveBeenCalledWith({
          name: 'Test Pie',
          symbol: 'TESTPIE',
          allocations: expect.any(Array)
        })
        expect(mockPush).toHaveBeenCalledWith('/pies')
      })
    })

    it('should handle creation errors', async () => {
      const mockError = new Error('Failed to create pie')
      mockCreatePie.mockRejectedValue(mockError)
      
      ;(useMockCreatePie as any).mockReturnValue({
        createPie: mockCreatePie,
        isPending: false,
        error: mockError
      })
      
      render(<BuilderPage />)
      
      // Check error is displayed
      await waitFor(() => {
        expect(screen.getByText('Failed to create pie')).toBeInTheDocument()
      })
    })
  })

  describe('User Interactions', () => {
    it('should uppercase symbol input automatically', async () => {
      render(<BuilderPage />)
      
      const symbolInput = screen.getByLabelText('Symbol') as HTMLInputElement
      fireEvent.change(symbolInput, { target: { value: 'testpie' } })
      
      await waitFor(() => {
        expect(symbolInput.value).toBe('TESTPIE')
      })
    })

    it('should navigate to /pies on cancel', async () => {
      render(<BuilderPage />)
      
      const cancelButton = screen.getByRole('button', { name: 'Cancel' })
      fireEvent.click(cancelButton)
      
      expect(mockPush).toHaveBeenCalledWith('/pies')
    })
  })
})