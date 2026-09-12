import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "LINE Booking Admin",
  description: "Admin panel for LINE booking sessions",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
