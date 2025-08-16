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
  // TODO: Initialize config from env vars
  // TODO: Persist to localStorage
  // TODO: Render dev tools conditionally
  throw new Error('Not implemented: MockProvider')
}

function MockDevTools() {
  // TODO: Floating panel with:
  // - Enable/disable toggle
  // - Delay slider (0-3000ms)
  // - Error rate slider (0-100%)
  // - Trigger scenarios buttons
  // - Reset data button
  throw new Error('Not implemented: MockDevTools')
}