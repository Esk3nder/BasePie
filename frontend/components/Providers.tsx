"use client";

import "@rainbow-me/rainbowkit/styles.css";
import { getDefaultConfig, RainbowKitProvider } from "@rainbow-me/rainbowkit";
import { WagmiProvider } from "wagmi";
import { mainnet, polygon, optimism, arbitrum, base } from "wagmi/chains";
import { QueryClientProvider, QueryClient } from "@tanstack/react-query";
import { MockProvider } from "./MockProvider";

// Use a demo projectId for development if not configured
// Get your own at https://cloud.walletconnect.com
const projectId = process.env.NEXT_PUBLIC_PROJECT_ID || "2f5c8a23e7a9b1d4e6f3a8b5c9d2e1f4";

const config = getDefaultConfig({
  appName: "BasePie",
  projectId: projectId,
  chains: [mainnet, polygon, optimism, arbitrum, base],
  ssr: true, // If your dApp uses server side rendering (SSR)
});
const queryClient = new QueryClient();

// SCAFFOLD: Wrap with MockProvider and conditionally render RainbowKit
export function Providers({ children }: { children: React.ReactNode }) {
  // TODO: Check mock config to conditionally render providers
  // TODO: In mock mode, skip RainbowKit but keep Wagmi for types
  throw new Error('Not implemented: Providers with MockProvider integration')
  
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>{children}</RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
