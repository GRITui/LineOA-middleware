"use client";

import { useEffect, useMemo, useState } from "react";
import { initLiff, liff } from "@/lib/liff";
import { fetchAvailability, createBooking, resolveCustomer, type Session, type Customer } from "@/lib/api";

type BookingState = "idle" | "confirming" | "submitting" | "success" | "error";

function parseDate(iso: string): Date | null {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? null : d;
}

function dayNumeral(iso: string): string {
  return parseDate(iso)?.getDate().toString() ?? iso;
}

function dateMeta(iso: string): string {
  const d = parseDate(iso);
  if (!d) return iso;
  const weekday = d.toLocaleDateString(undefined, { weekday: "long" });
  const month = d.toLocaleDateString(undefined, { month: "long" });
  return `${weekday}, ${month}`;
}

function durationLabel(startTime: string, endTime: string): string | null {
  const parts = (t: string) => t.split(":").map(Number);
  const [sh, sm] = parts(startTime);
  const [eh, em] = parts(endTime);
  if ([sh, sm, eh, em].some((n) => Number.isNaN(n))) return null;
  const mins = eh * 60 + em - (sh * 60 + sm);
  return mins > 0 ? `${mins} min` : null;
}

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

  const openCount = slotsForDate.filter((s) => s.status !== "full").length;

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
    <div className="tt-shell">
      <main className="tt-phone">
        <header className="tt-header">
          <div className="tt-kicker">Class schedule · book in seconds</div>
          <h1>Book a Session</h1>
        </header>
        {error && <p className="tt-error">{error}</p>}

        {bookingState === "success" && (
          <div className="tt-success">
            Booking confirmed! You&apos;ll get a LINE message with the details.
            <button className="tt-link" onClick={cancelConfirmation}>
              Book another
            </button>
          </div>
        )}

        {bookingState !== "success" && (
          <>
            <div className="tt-datenav">
              <div className="tt-big">{effectiveDate ? dayNumeral(effectiveDate) : "–"}</div>
              <div className="tt-rest">
                {effectiveDate ? dateMeta(effectiveDate) : "No dates available"}
                <br />
                {effectiveDate && (
                  <>
                    <b>
                      {slotsForDate.length} session{slotsForDate.length === 1 ? "" : "s"}
                    </b>{" "}
                    · <span className="tt-ok">{openCount} with space</span>
                  </>
                )}
              </div>
            </div>

            <div className="tt-weekstrip" role="tablist" aria-label="Dates">
              {dates.map((date) => (
                <span
                  key={date}
                  role="tab"
                  aria-selected={date === effectiveDate}
                  title={dateMeta(date)}
                  className={date === effectiveDate ? "tt-on" : ""}
                  onClick={() => {
                    setSelectedDate(date);
                    cancelConfirmation();
                  }}
                >
                  {dayNumeral(date)}
                </span>
              ))}
              {dates.length === 0 && <p className="tt-muted">No dates available.</p>}
            </div>

            <div className="tt-ledger">
              {slotsForDate.map((session) => {
                const isFull = session.status === "full";
                const isSelected = selectedSession?.id === session.id;
                const left = session.capacity - session.bookedCount;
                const dur = durationLabel(session.startTime, session.endTime);
                return (
                  <div key={session.id} className={`tt-slot${isFull ? " tt-full" : ""}`}>
                    <div className="tt-time">
                      {session.startTime}
                      {dur && <span>{dur}</span>}
                    </div>
                    <div>
                      <div className="tt-t">{session.title}</div>
                      <div className="tt-m">
                        {isFull ? (
                          <span className="tt-fulltag">Full</span>
                        ) : (
                          <>
                            <span className="tt-ok">{left} left</span> · {session.bookedCount}/
                            {session.capacity}
                          </>
                        )}
                      </div>
                    </div>
                    <button
                      className={isSelected ? "tt-hot" : ""}
                      disabled={isFull}
                      aria-disabled={isFull}
                      onClick={() => pickSlot(session)}
                    >
                      {isFull ? "Full" : "Select"}
                    </button>
                  </div>
                );
              })}
              {effectiveDate && slotsForDate.length === 0 && (
                <p className="tt-muted">No slots for this date.</p>
              )}
            </div>
          </>
        )}

        {selectedSession && bookingState !== "success" && (
          <div className="tt-confirm">
            <p>
              <b>{selectedSession.title}</b> — {dateMeta(selectedSession.date)},{" "}
              {selectedSession.startTime}. Confirm booking?
            </p>
            <div className="tt-row">
              <button
                className="tt-go"
                disabled={bookingState === "submitting"}
                onClick={confirmBooking}
              >
                {bookingState === "submitting" ? "Booking…" : "Confirm booking"}
              </button>
              <button
                className="tt-back"
                disabled={bookingState === "submitting"}
                onClick={cancelConfirmation}
              >
                Cancel
              </button>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
