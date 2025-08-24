/**
 * SCTE-35 Streaming Control Center - Layout
 * 
 * © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
 * 
 * This software is the property of Morus Broadcasting Pvt Ltd and is protected by
 * copyright law and international treaties. Unauthorized use, reproduction, or
 * distribution is strictly prohibited.
 */

import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { Toaster } from "@/components/ui/toaster";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "SCTE-35 Streaming Control Center",
  description: "Professional SCTE-35 streaming control center with RTMP, HLS, and SSAI support by Morus Broadcasting Pvt Ltd",
  keywords: ["SCTE-35", "Streaming", "RTMP", "HLS", "SSAI", "Morus Broadcasting", "Next.js", "TypeScript", "Tailwind CSS"],
  authors: [{ name: "Morus Broadcasting Pvt Ltd" }],
  openGraph: {
    title: "SCTE-35 Streaming Control Center",
    description: "Professional streaming control center by Morus Broadcasting Pvt Ltd",
    siteName: "Morus Broadcasting Pvt Ltd",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "SCTE-35 Streaming Control Center",
    description: "Professional streaming control center by Morus Broadcasting Pvt Ltd",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased bg-background text-foreground`}
      >
        {children}
        <Toaster />
      </body>
    </html>
  );
}
