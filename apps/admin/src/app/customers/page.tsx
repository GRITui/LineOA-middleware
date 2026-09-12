import { useEffect, useState } from "react";
import { apiBase } from "@/lib/apiClient";
import { CustomersTable } from "@/components/CustomersTable";
import Head from "next/head";

type Customer = {
  id: string;
  name: string;
  email?: string;
  bookingCount: number;
};

export default function CustomersPage() {
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchCustomers = async () => {
      try {
        setLoading(true);
        const response = await fetch(`${apiBase}/customers`);
        if (!response.ok) {
          throw new Error(`API error ${response.status}: ${await response.text()}`);
        }
        const data = await response.json();
        setCustomers(data);
        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Unknown error");
      } finally {
        setLoading(false);
      }
    };

    fetchCustomers();
  }, []);

  return (
    <>
      <Head>
        <title>Customers – Admin</title>
      </Head>

      <main className="p-6">
        <h1 className="text-2xl font-bold mb-4">Customers</h1>

        {loading && <p>Loading...</p>}
        {error && <p className="text-red-600">Error: {error}</p>}

        {!loading && !error && customers.length === 0 && (
          <p>No customers found.</p>
        )}

        {!loading && !error && customers.length > 0 && (
          <CustomersTable customers={customers} />
        )}
      </main>
    </>
  );
}
