'use client'

// SCAFFOLD: Provider for mock configuration and dev tools
// PSEUDOCODE:
// - Context for mock config (enabled, delay, errorRate)
// - Dev tools panel for testing scenarios
// - LocalStorage persistence option

import React, { createContext, useContext, useState, useEffect } from 'react'

interface MockConfig {
  enabled: boolean
  delay: number
  errorRate: number
  showDevTools: boolean
}

const MockContext = createContext<{
  config: MockConfig
  setConfig: (config: Partial<MockConfig>) => void
}>({
  config: {
    enabled: false,
    delay: 500,
    errorRate: 0,
    showDevTools: false,
  },
  setConfig: () => {},
})

export function useMockConfig() {
  return useContext(MockContext)
}

export function MockProvider({ children }: { children: React.ReactNode }) {
  const [config, setConfigState] = useState<MockConfig>(() => {
    // Initialize from env vars and localStorage
    const enabled = process.env.NEXT_PUBLIC_ENABLE_MOCKS === 'true'
    const stored = typeof window !== 'undefined' ? localStorage.getItem('mockConfig') : null
    
    if (stored) {
      try {
        return { ...JSON.parse(stored), enabled }
      } catch {
        // Ignore parse errors
      }
    }
    
    return {
      enabled,
      delay: 500,
      errorRate: 0,
      showDevTools: enabled,
    }
  })

  const setConfig = (partial: Partial<MockConfig>) => {
    setConfigState(prev => {
      const newConfig = { ...prev, ...partial }
      if (typeof window !== 'undefined') {
        localStorage.setItem('mockConfig', JSON.stringify(newConfig))
      }
      return newConfig
    })
  }

  useEffect(() => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('mockConfig', JSON.stringify(config))
    }
  }, [config])

  return (
    <MockContext.Provider value={{ config, setConfig }}>
      {children}
      {config.showDevTools && config.enabled && <MockDevTools />}
    </MockContext.Provider>
  )
}

function MockDevTools() {
  const { config, setConfig } = useMockConfig()
  const [isMinimized, setIsMinimized] = useState(false)

  if (isMinimized) {
    return (
      <div className="fixed bottom-4 right-4 bg-gray-900 text-white p-2 rounded-lg shadow-lg z-50">
        <button
          onClick={() => setIsMinimized(false)}
          className="text-sm font-mono"
        >
          🔧 Mock Tools
        </button>
      </div>
    )
  }

  return (
    <div className="fixed bottom-4 right-4 bg-gray-900 text-white p-4 rounded-lg shadow-lg z-50 w-80">
      <div className="flex justify-between items-center mb-4">
        <h3 className="text-sm font-bold">Mock Dev Tools</h3>
        <button
          onClick={() => setIsMinimized(true)}
          className="text-gray-400 hover:text-white"
        >
          ─
        </button>
      </div>
      
      <div className="space-y-3">
        <div>
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={config.enabled}
              onChange={(e) => setConfig({ enabled: e.target.checked })}
              className="rounded"
            />
            <span className="text-sm">Enable Mocks</span>
          </label>
        </div>

        <div>
          <label className="text-sm block mb-1">
            Delay: {config.delay}ms
          </label>
          <input
            type="range"
            min="0"
            max="3000"
            step="100"
            value={config.delay}
            onChange={(e) => setConfig({ delay: Number(e.target.value) })}
            className="w-full"
          />
        </div>

        <div>
          <label className="text-sm block mb-1">
            Error Rate: {config.errorRate}%
          </label>
          <input
            type="range"
            min="0"
            max="100"
            step="5"
            value={config.errorRate}
            onChange={(e) => setConfig({ errorRate: Number(e.target.value) })}
            className="w-full"
          />
        </div>

        <div className="pt-2 border-t border-gray-700">
          <button
            onClick={() => {
              localStorage.removeItem('mockConfig')
              window.location.reload()
            }}
            className="text-sm bg-red-600 hover:bg-red-700 px-3 py-1 rounded"
          >
            Reset All Data
          </button>
        </div>
      </div>
    </div>
  )
}