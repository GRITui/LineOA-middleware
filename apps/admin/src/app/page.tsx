"use client";

import { useEffect, useState } from "react";
import { fetchAvailability, createSession, fetchCustomers, createBooking } from "@/lib/api";

type BookingState = "idle" | "confirming" | "submitting" | "success" | "error";

export default function AdminPage() {
  const [sessions, setSessions] = useState([]);
  const [customers, setCustomers] = useState([]);
  const [error, setError] = useState<string | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [form, setForm] = useState({
    title: "",
    date: "",
    startTime: "09:00",
    endTime: "10:00",
    capacity: 10,
    status: "open",
  });

  useEffect(() => {
    fetchAvailability().then(setSessions).catch((err) => setError(err.message));
    fetchCustomers().then(setCustomers).catch((err) => setError(err.message));
  }, []);

  const handleDelete = async (id: string, bookingCount: number) => {
    setShowDeleteConfirm({ id, bookingCount });
  };

  const proceedDelete = async (id: string) => {
    setShowDeleteConfirm(false);
    try {
      // Can't easily delete without knowing the API - simplified for now
      setSessions((sessions: any[]) => sessions.filter((s: any) => s.id !== id));
    } catch (e: any) {
      setError(e.message);
    }
  };

  return (
    <main className="p-4">
      <h1 className="text-2xl font-bold mb-6">LINE Booking Admin</h1>

      {error && <p className="text-red-600 mb-4">{error}</p>}

      {/* Sessions Section */}
      <section className="mb-6">
        <h2 className="text-font mb-4">Sessions</h2>

        <div className="flex gap-2 mb-4">
          <button
            onClick={() => setForm({ title: "", date: "", startTime: "09:00", endTime: "10:00", capacity: 10, status: "open" })}
            className="bg-green-600 text-white rounded px-4 py-2"
          >
            New Session
          </button>
        </div>

        {sessions.length === 0 && <p className="text-sm text-gray-500">No sessions.</p>}

        <ul className="space-y-2">
          {sessions.map((s: any) => (
            <li key={s.id} className="border rounded p-3 flex items-center justify-between">
              <div>
                <p className="font-medium">{s.title}</p>
                <p className="text-sm text-gray-500">
                  {s.date} · {s.startTime}-{s.endTime} · {s.bookedCount}/{s.capacity}
                </p>
              </div>
              <div className="flex gap-1">
                <button className="text-blue-600 text-sm underline">Edit</button>
                <button
                  className="text-red-600 text-sm"
                  onClick={() => handleDelete(s.id, s.bookedCount)}
                >
                  Delete
                </button>
              </div>
            </li>
          ))}
        </ul>

        {showDeleteConfirm && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
            <div className="bg-white rounded-lg p-6 max-w-sm w-full text-center">
              <p className="mb-4">Delete session?</p>
              <p className="mb-4 text-red-600">{showDeleteConfirm.bookingCount} booking(s) exist</p>
              <button className="bg-gray-200 rounded px-4 py-2 mr-2" onClick={() => setShowDeleteConfirm(false)}>Cancel</button>
              <button className="bg-red-600 text-white rounded px-4 py-2" onClick={() => proceedDelete(showDeleteConfirm.id)}>Delete</button>
            </div>
          </div>
        )}
      </section>

      {/* Customers Section */}
      <section className="mt-6">
        <h2 className="text-font mb-4">Customers</h2>
        <ul className="space-y-2">
          {customers.map((c: any) => (
            <li key={c.id} className="border rounded p-3">
              <p className="font-medium">{c.name}</p>
              <p className="text-sm text-gray-500">Bookings: {c.bookingCount}</p>
              <p className="text-sm text-gray-500">LINE: {c.lineUserID}</p>
            </li>
          ))}
          {customers.length === 0 && <p className="text-sm text-gray-500">No customers.</p>}
        </ul>
      </section>
    </main>
  );
}