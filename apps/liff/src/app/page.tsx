"use client";

import { useEffect, useState } from "react";
import { initLiff, liff } from "@/lib/liff";
import { fetchAvailability, createBooking, type Session } from "@/lib/api";

export default function BookingPage() {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    initLiff()
      .then(() => fetchAvailability())
      .then(setSessions)
      .catch((err) => setError(err.message));
  }, []);

  async function handleBook(sessionID: string) {
    try {
      const profile = await liff.getProfile();
      await createBooking(profile.userId, sessionID);
      const updated = await fetchAvailability();
      setSessions(updated);
    } catch (err: any) {
      setError(err.message);
    }
  }

  return (
    <main className="min-h-screen p-4">
      <h1 className="text-xl font-semibold mb-4">Available Sessions</h1>
      {error && <p className="text-red-600 mb-4">{error}</p>}
      <ul className="space-y-3">
        {sessions.map((session) => (
          <li key={session.id} className="border rounded-lg p-3 flex items-center justify-between">
            <div>
              <p className="font-medium">{session.title}</p>
              <p className="text-sm text-gray-500">
                {session.date} {session.startTime}–{session.endTime} · {session.bookedCount}/{session.capacity}
              </p>
            </div>
            <button
              className="bg-green-600 text-white rounded px-3 py-1 disabled:opacity-50"
              disabled={session.status === "full"}
              onClick={() => handleBook(session.id)}
            >
              {session.status === "full" ? "Full" : "Book"}
            </button>
          </li>
        ))}
      </ul>
    </main>
  );
}
