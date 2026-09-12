import Link from "next/link";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ADMIN_COOKIE, isValidSession } from "@/lib/auth";

// Gate for every admin page: unauthenticated visitors go to /login.
// /login and /api/auth/* live outside this group, so no redirect loop.
export default async function ProtectedLayout({ children }: { children: React.ReactNode }) {
  const store = await cookies();
  if (!isValidSession(store.get(ADMIN_COOKIE)?.value)) {
    redirect("/login");
  }

  return (
    <>
      <header className="bg-blue-800 text-white p-4 flex justify-between items-center">
        <h1 className="text-xl font-semibold">Admin Panel</h1>
        <nav className="space-x-4 flex items-center">
          <Link href="/">Sessions</Link>
          <Link href="/customers">Customers</Link>
          <Link href="/reports">Reports</Link>
          <form action="/api/auth/logout" method="post">
            <button type="submit" className="underline">
              Sign out
            </button>
          </form>
        </nav>
      </header>
      <main>{children}</main>
      <footer className="bg-gray-100 text-center p-2 text-sm">
        © {new Date().getFullYear()} Your Company
      </footer>
    </>
  );
}
