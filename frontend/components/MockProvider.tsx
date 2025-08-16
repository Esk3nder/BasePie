'use client'

import React, { createContext, useContext, useState, useEffect, useCallback } from 'react'
import { mockStore } from '@/lib/mocks/contracts'
import { generatePies, generatePositions } from '@/lib/mocks/generators'

interface MockConfig {
  enabled: boolean
  delay: number
  errorRate: number
  showDevTools: boolean
}

interface MockContextValue {
  config: MockConfig
  setConfig: (config: Partial<MockConfig>) => void
  resetData: () => void
  triggerScenario: (scenario: string) => void
}

const MockContext = createContext<MockContextValue>({
  config: {
    enabled: false,
    delay: 500,
    errorRate: 0,
    showDevTools: false,
  },
  setConfig: () => {},
  resetData: () => {},
  triggerScenario: () => {},
})

export function useMockConfig() {
  return useContext(MockContext)
}

export function MockProvider({ children }: { children: React.ReactNode }) {
  const [config, setConfigState] = useState<MockConfig>(() => {
    // Initialize from environment variables
    const enabled = process.env.NEXT_PUBLIC_ENABLE_MOCKS === 'true'
    const delay = parseInt(process.env.NEXT_PUBLIC_MOCK_DELAY || '500')
    const errorRate = parseFloat(process.env.NEXT_PUBLIC_MOCK_ERROR_RATE || '0')
    const showDevTools = process.env.NODE_ENV === 'development' && enabled
    
    // Try to restore from localStorage
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('mockConfig')
      if (saved) {
        try {
          return JSON.parse(saved)
        } catch (e) {
          // Fallback to env defaults
        }
      }
    }
    
    return { enabled, delay, errorRate, showDevTools }
  })

  const setConfig = useCallback((partial: Partial<MockConfig>) => {
    setConfigState(prev => {
      const newConfig = { ...prev, ...partial }
      // Persist to localStorage
      if (typeof window !== 'undefined') {
        localStorage.setItem('mockConfig', JSON.stringify(newConfig))
      }
      return newConfig
    })
  }, [])

  const resetData = useCallback(() => {
    // Clear and regenerate mock data
    const newPies = generatePies(10)
    // Reset store (would need to add reset method to MockContractStore)
    localStorage.removeItem('mockConfig')
    window.location.reload() // Simple reset for now
  }, [])

  const triggerScenario = useCallback((scenario: string) => {
    switch (scenario) {
      case 'largeTvl':
        // Update a pie to have large TVL
        const pies = mockStore.getAllPies()
        if (pies[0]) {
          pies[0].tvl = 10000000 // $10M
        }
        break
      case 'highVolatility':
        // Trigger price changes
        console.log('Triggering high volatility scenario')
        break
      case 'failedTx':
        // Set high error rate temporarily
        setConfig({ errorRate: 1 })
        setTimeout(() => setConfig({ errorRate: 0 }), 5000)
        break
      case 'networkDelay':
        // Set high delay temporarily
        setConfig({ delay: 3000 })
        setTimeout(() => setConfig({ delay: 500 }), 10000)
        break
    }
  }, [setConfig])

  // Persist config changes
  useEffect(() => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('mockConfig', JSON.stringify(config))
    }
  }, [config])

  const contextValue: MockContextValue = {
    config,
    setConfig,
    resetData,
    triggerScenario,
  }

  return (
    <MockContext.Provider value={contextValue}>
      {children}
      {config.showDevTools && config.enabled && <MockDevTools />}
    </MockContext.Provider>
  )
}

function MockDevTools() {
  const { config, setConfig, resetData, triggerScenario } = useMockConfig()
  const [isCollapsed, setIsCollapsed] = useState(false)

  // Keyboard shortcut to toggle
  useEffect(() => {
    const handleKeyPress = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'd') {
        e.preventDefault()
        setIsCollapsed(prev => !prev)
      }
    }
    window.addEventListener('keydown', handleKeyPress)
    return () => window.removeEventListener('keydown', handleKeyPress)
  }, [])

  if (isCollapsed) {
    return (
      <div 
        className="fixed bottom-4 right-4 z-50 bg-gray-900/90 backdrop-blur-sm text-white p-2 rounded-lg cursor-pointer shadow-xl"
        onClick={() => setIsCollapsed(false)}
      >
        <span className="text-xs">DevTools (⌘D)</span>
      </div>
    )
  }

  return (
    <div className="fixed bottom-4 right-4 z-50 w-80 max-h-[600px] overflow-y-auto bg-gray-900/90 backdrop-blur-sm text-white p-4 rounded-lg shadow-xl">
      <div className="flex justify-between items-center mb-4">
        <h3 className="text-lg font-bold">Mock DevTools</h3>
        <button 
          onClick={() => setIsCollapsed(true)}
          className="text-gray-400 hover:text-white"
        >
          ✕
        </button>
      </div>

      <div className="space-y-4">
        {/* Enable/Disable Mock Mode */}
        <div>
          <label className="flex items-center space-x-2">
            <input
              type="checkbox"
              checked={config.enabled}
              onChange={(e) => setConfig({ enabled: e.target.checked })}
              className="w-4 h-4"
            />
            <span>Mock Mode Enabled</span>
          </label>
        </div>

        {/* Delay Slider */}
        <div>
          <label className="block text-sm mb-1">
            Network Delay: {config.delay}ms
          </label>
          <input
            type="range"
            min="0"
            max="3000"
            step="100"
            value={config.delay}
            onChange={(e) => setConfig({ delay: parseInt(e.target.value) })}
            className="w-full"
          />
        </div>

        {/* Error Rate Slider */}
        <div>
          <label className="block text-sm mb-1">
            Error Rate: {(config.errorRate * 100).toFixed(0)}%
          </label>
          <input
            type="range"
            min="0"
            max="1"
            step="0.1"
            value={config.errorRate}
            onChange={(e) => setConfig({ errorRate: parseFloat(e.target.value) })}
            className="w-full"
          />
        </div>

        {/* Scenario Triggers */}
        <div>
          <h4 className="text-sm font-semibold mb-2">Test Scenarios</h4>
          <div className="grid grid-cols-2 gap-2">
            <button
              onClick={() => triggerScenario('largeTvl')}
              className="px-2 py-1 bg-blue-600 hover:bg-blue-700 rounded text-xs"
            >
              Large TVL
            </button>
            <button
              onClick={() => triggerScenario('highVolatility')}
              className="px-2 py-1 bg-purple-600 hover:bg-purple-700 rounded text-xs"
            >
              High Volatility
            </button>
            <button
              onClick={() => triggerScenario('failedTx')}
              className="px-2 py-1 bg-red-600 hover:bg-red-700 rounded text-xs"
            >
              Failed TX
            </button>
            <button
              onClick={() => triggerScenario('networkDelay')}
              className="px-2 py-1 bg-yellow-600 hover:bg-yellow-700 rounded text-xs"
            >
              Network Delay
            </button>
          </div>
        </div>

        {/* Reset Button */}
        <button
          onClick={resetData}
          className="w-full px-3 py-2 bg-gray-700 hover:bg-gray-600 rounded text-sm"
        >
          Reset All Data
        </button>

        {/* Keyboard Shortcuts */}
        <div className="text-xs text-gray-400 pt-2 border-t border-gray-700">
          <p>⌘D / Ctrl+D: Toggle DevTools</p>
        </div>
      </div>
    </div>
  )
}