const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL!;

export interface Session {
  id: string;
  title: string;
  date: string;
  startTime: string;
  endTime: string;
  capacity: number;
  bookedCount: number;
  status: "open" | "full";
}

// See GitHub issue #12 (availability UI).
export async function fetchAvailability(): Promise<Session[]> {
  const res = await fetch(`${API_BASE_URL}/availability`);
  if (!res.ok) throw new Error("Failed to load availability");
  return res.json();
}

// See GitHub issue #13 (booking confirmation UI).
export async function createBooking(customerID: string, sessionID: string) {
  const res = await fetch(`${API_BASE_URL}/bookings`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ customerID, sessionID }),
  });
  if (!res.ok) throw new Error("Failed to create booking");
  return res.json();
}
