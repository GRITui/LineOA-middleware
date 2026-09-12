"use client";

import { use, useCallback, useEffect, useState } from "react";
import { apiGet, createManualBooking } from "@/lib/apiClient";
import { BookingsTable, type Booking } from "@/components/BookingsTable";

export default function SessionDetail({ params }: { params: Promise<{ sessionID: string }> }) {
  const { sessionID } = use(params);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // TSK-402: walk-in quick-add form state.
  const [showQuickAdd, setShowQuickAdd] = useState(false);
  const [walkInName, setWalkInName] = useState("");
  const [walkInPhone, setWalkInPhone] = useState("");
  const [quickAddError, setQuickAddError] = useState<string | null>(null);
  const [quickAddBusy, setQuickAddBusy] = useState(false);

  // Shared by the post-save refresh (submitQuickAdd).
  const loadBookings = useCallback(async () => {
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
  }, [sessionID]);

  // Mount fetch — same data-loading pattern as the customers page.
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

  async function submitQuickAdd(e: React.FormEvent) {
    e.preventDefault();
    setQuickAddBusy(true);
    setQuickAddError(null);
    try {
      await createManualBooking({
        sessionID,
        name: walkInName.trim(),
        phone: walkInPhone.trim() || undefined,
      });
      setShowQuickAdd(false);
      setWalkInName("");
      setWalkInPhone("");
      await loadBookings();
    } catch (err) {
      // Surfaces the 409 reason inline when the slot filled concurrently.
      setQuickAddError(err instanceof Error ? err.message : "Booking failed");
    } finally {
      setQuickAddBusy(false);
    }
  }

  return (
    <main className="p-6">
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-2xl font-bold">Session Bookings</h1>
        <button
          className="bg-blue-800 text-white rounded px-4 py-2 min-h-[44px]"
          onClick={() => {
            setQuickAddError(null);
            setShowQuickAdd(true);
          }}
        >
          Quick add walk-in
        </button>
      </div>

      {loading && <p>Loading...</p>}
      {error && <p className="text-red-600">Error: {error}</p>}

      {!loading && !error && bookings.length === 0 && (
        <p>No bookings for this session.</p>
      )}

      {!loading && !error && bookings.length > 0 && (
        <BookingsTable bookings={bookings} />
      )}

      {showQuickAdd && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <form
            onSubmit={submitQuickAdd}
            className="bg-white rounded-lg p-6 w-full max-w-sm space-y-4"
          >
            <h2 className="text-xl font-bold">Walk-in booking</h2>
            {quickAddError && <p className="text-red-600 text-sm">{quickAddError}</p>}
            <div>
              <label htmlFor="walkin-name" className="block text-sm font-medium mb-1">
                Name
              </label>
              <input
                id="walkin-name"
                value={walkInName}
                onChange={(e) => setWalkInName(e.target.value)}
                className="shadow appearance-none border rounded w-full py-2 px-3 min-h-[44px]"
                autoComplete="off"
              />
            </div>
            <div>
              <label htmlFor="walkin-phone" className="block text-sm font-medium mb-1">
                Phone (optional)
              </label>
              <input
                id="walkin-phone"
                value={walkInPhone}
                onChange={(e) => setWalkInPhone(e.target.value)}
                className="shadow appearance-none border rounded w-full py-2 px-3 min-h-[44px]"
                autoComplete="off"
              />
            </div>
            <div className="flex justify-end gap-2">
              <button
                type="button"
                className="border rounded px-4 py-2 min-h-[44px]"
                disabled={quickAddBusy}
                onClick={() => setShowQuickAdd(false)}
              >
                Cancel
              </button>
              <button
                type="submit"
                className="bg-blue-800 text-white rounded px-4 py-2 min-h-[44px] disabled:opacity-50"
                disabled={quickAddBusy || walkInName.trim().length === 0}
              >
                {quickAddBusy ? "Booking…" : "Confirm"}
              </button>
            </div>
          </form>
        </div>
      )}
    </main>
  );
}
