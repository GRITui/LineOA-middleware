import type { Metadata } from "next";
import "./globals.css";
import Link from "next/link";

export const metadata: Metadata = {
  title: "LINE Booking Admin",
  description: "Admin panel for LINE booking sessions",
};

export default function RootLayout({
  children}: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <header className="bg-blue-800 text-white p-4 flex justify-between">
          <h1 className="text-xl font-semibold">Admin Panel</h1>
          <nav className="space-x-4">
            <Link href="/">Home</Link>
            <Link href="/sessions">Sessions</Link>
            <Link href="/customers">Customers</Link>
          </nav>
        </header>
        <main>{children}</main>
        <footer className="bg-gray-100 text-center p-2 text-sm">
          © {new Date().getFullYear()} Your Company
        </footer>
      </body>
    </html>
  );
}
