import type { Metadata } from "next";
import { Open_Sans } from "next/font/google";
import "./globals.css";
import "@rainbow-me/rainbowkit/styles.css";
import { Providers } from "../components/Providers";

const openSans = Open_Sans({
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "EVM Frontend Starter",
  description: "A Next.js application using Open Sans font.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${openSans.className} antialiased`}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
