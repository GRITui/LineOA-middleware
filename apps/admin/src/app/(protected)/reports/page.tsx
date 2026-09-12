"use client";

import { useEffect, useState } from 'react';
import { apiGet } from '@/lib/apiClient';
import ReportsTable from '@/components/ReportsTable';
import BarChart from '@/components/BarChart';

// Mirrors ReportController.BookingsByDayRow in apps/api.
type BookingByDay = {
  date: string;
  count: number;
};

// Mirrors ReportController.CapacityUtilizationRow in apps/api
// (utilization is a 0..1 fraction).
type CapacityRow = {
  sessionID: string;
  title: string;
  date: string;
  capacity: number;
  bookedCount: number;
  utilization: number;
};

export default function ReportsPage() {
  const [bookings, setBookings] = useState<BookingByDay[] | null>(null);
  const [capacity, setCapacity] = useState<CapacityRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchData() {
      try {
        const [bJson, cJson] = await Promise.all([
          apiGet<BookingByDay[]>('/reports/bookings-by-day'),
          apiGet<CapacityRow[]>('/reports/capacity-utilization'),
        ]);
        setBookings(bJson);
        setCapacity(cJson);
        setError(null);
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Failed to fetch reports');
      } finally {
        setLoading(false);
      }
    }

    fetchData();
  }, []);

  if (loading) return <p>Loading reports…</p>;
  if (error) return <p className="text-red-600">Error: {error}</p>;

  const hasBookings = bookings !== null && bookings.length > 0;
  const hasCapacity = capacity !== null && capacity.length > 0;

  return (
    <main className="p-6 space-y-8">
      <h1 className="text-2xl font-bold">Reports Dashboard</h1>

      <section>
        <h2 className="text-xl mb-2">Bookings by Day</h2>
        {hasBookings ? (
          <ReportsTable
            columns={['Date', 'Bookings']}
            rows={bookings.map(b => [b.date, b.count.toString()])}
          />
        ) : (
          <p>No booking data available.</p>
        )}
      </section>

      <section>
        <h2 className="text-xl mb-2">Capacity Utilization</h2>
        {hasCapacity ? (
          <ReportsTable
            columns={['Session', 'Date', 'Capacity', 'Booked', 'Utilization %']}
            rows={capacity.map(c => [
              c.title,
              c.date,
              c.capacity.toString(),
              c.bookedCount.toString(),
              (c.utilization * 100).toFixed(1) + '%'
            ])}
          />
        ) : (
          <p>No capacity data available.</p>
        )}
      </section>

      <section>
        <h2 className="text-xl mb-2">Bookings per Day (Bar Chart)</h2>
        {hasBookings ? (
          <BarChart data={bookings.map(b => ({ label: b.date, value: b.count }))} />
        ) : (
          <p>No data to display chart.</p>
        )}
      </section>
    </main>
  );
}
