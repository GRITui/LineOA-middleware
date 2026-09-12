import { useEffect, useState } from "react";
import { apiBase } from "@/lib/apiClient";
import { BookingsTable } from "@/components/BookingsTable";
import Head from "next/head";

type Booking = {
  id: string;
  customerName: string;
  lineUserID: string;
  status: string;
  createdDate: string;
  reminder24hSent: boolean;
  reminder2hSent: boolean;
  reminder15mSent: boolean;
};

interface SessionDetailPageProps {
  params: {
    sessionID: string;
  };
}

export default function SessionDetail({ params }: SessionDetailPageProps) {
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchBookings = async () => {
      try {
        setLoading(true);
        const response = await fetch(`${apiBase}/sessions/${params.sessionID}/bookings`);
        if (!response.ok) {
          throw new Error(`API error ${response.status}: ${await response.text()}`);
        }
        const data = await response.json();
        setBookings(data);
        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Unknown error");
      } finally {
        setLoading(false);
      }
    };

    fetchBookings();
  }, [params.sessionID]);

  return (
    <>
      <Head>
        <title>Session {params.sessionID} – Bookings</title>
      </Head>

      <main className="p-6">
        <h1 className="text-2xl font-bold mb-4">Session {params.sessionID} – Bookings</h1>

        {loading && <p>Loading...</p>}
        {error && <p className="text-red-600">Error: {error}</p>}

        {!loading && !error && bookings.length === 0 && (
          <p>No bookings for this session.</p>
        )}

        {!loading && !error && bookings.length > 0 && (
          <BookingsTable bookings={bookings} />
        )}
      </main>
    </>
  );
}
