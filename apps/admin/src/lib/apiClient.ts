export const apiBase = (process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8080").replace(/\/+$/, "");

export async function apiGet<T>(path: string): Promise<T> {
  const url = `${apiBase}${path}`;
  const res = await fetch(url, {
    method: "GET",
    credentials: "include",
    headers: {
      Accept: "application/json",
    },
  });

  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`API error ${res.status}: ${txt}`);
  }

  return (await res.json()) as T;
}

// TSK-402: walk-in / phone booking (admin creates a guest customer server-side).
export async function createManualBooking(input: {
  sessionID: string;
  name: string;
  phone?: string;
}): Promise<unknown> {
  const res = await fetch(`${apiBase}/bookings/manual`, {
    method: "POST",
    headers: { Accept: "application/json", "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`API error ${res.status}: ${txt}`);
  }
  return res.json();
}
