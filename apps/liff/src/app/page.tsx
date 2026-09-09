"use client";

import { useEffect, useMemo, useState } from "react";
import { initLiff, liff } from "@/lib/liff";
import { fetchAvailability, createBooking, resolveCustomer, type Session, type Customer } from "@/lib/api";

type BookingState = "idle" | "confirming" | "submitting" | "success" | "error";

export default function BookingPage() {
  const [customer, setCustomer] = useState<Customer | null>(null);
  const [sessions, setSessions] = useState<Session[]>([]);
  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  const [selectedSession, setSelectedSession] = useState<Session | null>(null);
  const [bookingState, setBookingState] = useState<BookingState>("idle");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // See GitHub issue #11: initialize LIFF, then resolve/create the Customer
    // record from the LINE profile before anything else can be booked.
    initLiff()
      .then(() => liff.getProfile())
      .then((profile) => resolveCustomer(profile.userId, profile.displayName))
      .then(setCustomer)
      .catch((err) => setError(err.message));

    // See GitHub issue #12: availability is independent of login state.
    fetchAvailability()
      .then(setSessions)
      .catch((err) => setError(err.message));
  }, []);

  // See GitHub issue #12: group sessions by date so the UI is a date picker
  // followed by a time-slot picker for that date.
  const dates = useMemo(() => {
    const unique = Array.from(new Set(sessions.map((s) => s.date)));
    return unique.sort();
  }, [sessions]);

  const effectiveDate = selectedDate ?? dates[0] ?? null;

  const slotsForDate = useMemo(
    () => sessions.filter((s) => s.date === effectiveDate),
    [sessions, effectiveDate]
  );

  function pickSlot(session: Session) {
    if (session.status === "full") return;
    setSelectedSession(session);
    setBookingState("confirming");
    setError(null);
  }

  async function confirmBooking() {
    if (!selectedSession) return;
    if (!customer) {
      setError("Still signing you in — please try again in a moment.");
      return;
    }

    setBookingState("submitting");
    try {
      // See GitHub issue #13: confirm the slot via POST /bookings, then refresh
      // availability in place (no full page reload).
      await createBooking(customer.id, selectedSession.id);
      const updated = await fetchAvailability();
      setSessions(updated);
      setBookingState("success");
    } catch (err: any) {
      setError(err.message);
      setBookingState("error");
    }
  }

  function cancelConfirmation() {
    setSelectedSession(null);
    setBookingState("idle");
    setError(null);
  }

  return (
    <main className="min-h-screen p-4">
      <h1 className="text-xl font-semibold mb-4">Book a Session</h1>
      {error && <p className="text-red-600 mb-4">{error}</p>}

      {bookingState === "success" && (
        <div className="mb-4 rounded-lg bg-green-50 border border-green-200 p-3 text-green-800">
          Booking confirmed! You&apos;ll get a LINE message with the details.
          <button className="ml-3 underline" onClick={cancelConfirmation}>
            Book another
          </button>
        </div>
      )}

      {bookingState !== "success" && (
        <>
          <section className="mb-4">
            <h2 className="text-sm font-medium text-gray-500 mb-2">Date</h2>
            <div className="flex gap-2 flex-wrap">
              {dates.map((date) => (
                <button
                  key={date}
                  className={`rounded-full px-3 py-1 text-sm border ${
                    date === effectiveDate
                      ? "bg-green-600 text-white border-green-600"
                      : "bg-white text-gray-700 border-gray-300"
                  }`}
                  onClick={() => {
                    setSelectedDate(date);
                    cancelConfirmation();
                  }}
                >
                  {date}
                </button>
              ))}
              {dates.length === 0 && <p className="text-sm text-gray-500">No dates available.</p>}
            </div>
          </section>

          <section>
            <h2 className="text-sm font-medium text-gray-500 mb-2">Time slot</h2>
            <ul className="space-y-3">
              {slotsForDate.map((session) => {
                const isFull = session.status === "full";
                const isSelected = selectedSession?.id === session.id;
                return (
                  <li
                    key={session.id}
                    className={`border rounded-lg p-3 flex items-center justify-between ${
                      isFull ? "opacity-50" : ""
                    } ${isSelected ? "border-green-600 ring-1 ring-green-600" : ""}`}
                  >
                    <div>
                      <p className="font-medium">{session.title}</p>
                      <p className="text-sm text-gray-500">
                        {session.startTime}–{session.endTime} · {session.bookedCount}/{session.capacity}
                        {isFull && " · Full"}
                      </p>
                    </div>
                    <button
                      className="bg-green-600 text-white rounded px-3 py-1 disabled:opacity-50 disabled:cursor-not-allowed"
                      disabled={isFull}
                      aria-disabled={isFull}
                      onClick={() => pickSlot(session)}
                    >
                      {isFull ? "Full" : "Select"}
                    </button>
                  </li>
                );
              })}
              {effectiveDate && slotsForDate.length === 0 && (
                <p className="text-sm text-gray-500">No slots for this date.</p>
              )}
            </ul>
          </section>
        </>
      )}

      {selectedSession && bookingState !== "success" && (
        <div className="fixed bottom-0 left-0 right-0 bg-white border-t p-4 shadow-lg">
          <p className="mb-2 text-sm">
            Confirm <span className="font-medium">{selectedSession.title}</span> on{" "}
            {selectedSession.date} {selectedSession.startTime}–{selectedSession.endTime}?
          </p>
          <div className="flex gap-2">
            <button
              className="bg-green-600 text-white rounded px-4 py-2 disabled:opacity-50"
              disabled={bookingState === "submitting"}
              onClick={confirmBooking}
            >
              {bookingState === "submitting" ? "Booking…" : "Confirm booking"}
            </button>
            <button
              className="border rounded px-4 py-2"
              disabled={bookingState === "submitting"}
              onClick={cancelConfirmation}
            >
              Cancel
            </button>
          </div>
        </div>
      )}
    </main>
  );
}
