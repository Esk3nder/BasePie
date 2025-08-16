'use client'

import { ConnectButton } from "@rainbow-me/rainbowkit";
import Link from "next/link";
import { useMockConfig } from "@/components/MockProvider";

export default function Home() {
  const isMockMode = process.env.NEXT_PUBLIC_ENABLE_MOCKS === 'true';
  
  return (
    <main className="min-h-screen bg-gradient-to-b from-gray-50 to-gray-100">
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="flex items-center justify-between mb-12">
          <span className="text-3xl font-bold text-gray-900">BasePie</span>
          <div className="flex items-center gap-4">
            {isMockMode && (
              <span className="text-sm px-3 py-1 bg-yellow-100 text-yellow-800 rounded-full">
                Mock Mode
              </span>
            )}
            {!isMockMode && <ConnectButton />}
          </div>
        </div>

        {/* Hero Section */}
        <div className="text-center py-16">
          <h1 className="text-5xl font-bold text-gray-900 mb-4">
            Portfolio Management on Base
          </h1>
          <p className="text-xl text-gray-600 mb-8 max-w-2xl mx-auto">
            Create and manage diversified crypto portfolios with automated rebalancing
          </p>
          
          {/* CTAs */}
          <div className="flex gap-4 justify-center">
            <Link
              href="/pies"
              className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
            >
              Explore Pies
            </Link>
            <Link
              href="/builder"
              className="px-6 py-3 bg-gray-800 text-white rounded-lg hover:bg-gray-900 transition-colors"
            >
              Create Your Pie
            </Link>
          </div>
        </div>

        {/* Feature Cards */}
        <div className="grid md:grid-cols-3 gap-6 mt-16">
          <div className="bg-white p-6 rounded-lg shadow-md">
            <h3 className="text-xl font-semibold mb-2">Automated Rebalancing</h3>
            <p className="text-gray-600">
              Keep your portfolio balanced automatically with our batch rebalancer
            </p>
          </div>
          
          <div className="bg-white p-6 rounded-lg shadow-md">
            <h3 className="text-xl font-semibold mb-2">Low Fees</h3>
            <p className="text-gray-600">
              Benefit from efficient gas usage and minimal management fees
            </p>
          </div>
          
          <div className="bg-white p-6 rounded-lg shadow-md">
            <h3 className="text-xl font-semibold mb-2">ERC-4626 Vaults</h3>
            <p className="text-gray-600">
              Built on the standard vault interface for maximum composability
            </p>
          </div>
        </div>

        {/* Quick Links */}
        <div className="mt-16 border-t pt-8">
          <h2 className="text-2xl font-semibold mb-4">Quick Links</h2>
          <div className="flex gap-6">
            <Link href="/portfolio" className="text-blue-600 hover:underline">
              My Portfolio
            </Link>
            <Link href="/pies" className="text-blue-600 hover:underline">
              All Pies
            </Link>
            <Link href="/builder" className="text-blue-600 hover:underline">
              Pie Builder
            </Link>
          </div>
        </div>
      </div>
    </main>
  );
}
