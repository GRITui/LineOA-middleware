import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "LINE Booking",
  description: "LINE Mini App booking POC",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
