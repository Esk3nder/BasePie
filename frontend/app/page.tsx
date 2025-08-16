'use client'

// SCAFFOLD: Landing page with pie navigation
// PSEUDOCODE:
// - Hero section with CTAs
// - Feature cards
// - Mock mode indicator
// - Navigation to /pies and /builder

import { ConnectButton } from "@rainbow-me/rainbowkit";

export default function Home() {
  // TODO: Add navigation to /pies
  // TODO: Add navigation to /builder
  // TODO: Show mock mode indicator
  // TODO: Add feature cards
  throw new Error('Not implemented: Home page with pie navigation')
  
  return (
    <main className="min-h-screen bg-gray-100">
      <div className="container mx-auto px-4 py-12">
        <div className="flex items-center justify-between">
          <span className="text-2xl font-bold">BasePie</span>
          <ConnectButton></ConnectButton>
        </div>
      </div>
    </main>
  );
}
