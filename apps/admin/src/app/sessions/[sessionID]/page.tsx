"use client";

import { use, useEffect, useState } from "react";
import { apiGet } from "@/lib/apiClient";
import { BookingsTable, type Booking } from "@/components/BookingsTable";

export default function SessionDetail({ params }: { params: Promise<{ sessionID: string }> }) {
  const { sessionID } = use(params);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchBookings = async () => {
      try {
        setLoading(true);
        const data = await apiGet<Booking[]>(`/sessions/${sessionID}/bookings`);
        setBookings(data);
        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Unknown error");
      } finally {
        setLoading(false);
      }
    };

    fetchBookings();
  }, [sessionID]);

  return (
    <main className="p-6">
      <h1 className="text-2xl font-bold mb-4">Session Bookings</h1>

      {loading && <p>Loading...</p>}
      {error && <p className="text-red-600">Error: {error}</p>}

      {!loading && !error && bookings.length === 0 && (
        <p>No bookings for this session.</p>
      )}

      {!loading && !error && bookings.length > 0 && (
        <BookingsTable bookings={bookings} />
      )}
    </main>
  );
}
