// Test setup and global mocks
import '@testing-library/jest-dom'
import { vi } from 'vitest'

// Mock Next.js router
vi.mock('next/navigation', () => ({
  useRouter: () => ({
    push: vi.fn(),
    replace: vi.fn(),
    prefetch: vi.fn(),
  }),
  useParams: () => ({}),
  useSearchParams: () => new URLSearchParams(),
}))

// Mock environment variables
process.env.NEXT_PUBLIC_ENABLE_MOCKS = 'true'
process.env.NEXT_PUBLIC_MOCK_DELAY = '0'
process.env.NEXT_PUBLIC_MOCK_ERROR_RATE = '0'