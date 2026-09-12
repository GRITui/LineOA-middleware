const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8080';

export interface Session {
  id: string;
  title: string;
  date: string;
  startTime: string;
  endTime: string;
  capacity: number;
  bookedCount: number;
  status: 'open' | 'full';
}

export interface Customer {
  id: string;
  lineUserID: string;
  name: string;
  bookingCount: number;
}

export async function fetchAvailability(): Promise<Session[]> {
  const res = await fetch(`${API_BASE_URL}/availability`, {
    cache: 'no-store',
  });
  if (!res.ok) throw new Error('Failed to load availability');
  return res.json();
}

export async function createSession(input: { title: string; date: string; startTime: string; endTime: string; capacity: number; status?: 'open' | 'full' }): Promise<Session> {
  const res = await fetch(`${API_BASE_URL}/sessions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(input),
    cache: 'no-store',
  });
  if (!res.ok) throw new Error('Failed to create session');
  return res.json();
}

export async function updateSession(id: string, input: { title: string; date: string; startTime: string; endTime: string; capacity: number; status?: 'open' | 'full' }): Promise<Session> {
  const res = await fetch(`${API_BASE_URL}/sessions/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(input),
    cache: 'no-store',
  });
  if (!res.ok) throw new Error('Failed to update session');
  return res.json();
}

export async function deleteSession(id: string): Promise<{ success: boolean }> {
  const res = await fetch(`${API_BASE_URL}/sessions/${id}`, {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json' },
    cache: 'no-store',
  });
  if (!res.ok) throw new Error('Failed to delete session');
  return res.json();
}

export async function fetchCustomers(): Promise<Customer[]> {
  const res = await fetch(`${API_BASE_URL}/customers`, {
    cache: 'no-store',
  });
  if (!res.ok) throw new Error('Failed to fetch customers');
  return res.json();
}

export async function createBooking(customerID: string, sessionID: string): Promise<{ success: boolean }> {
  const res = await fetch(`${API_BASE_URL}/bookings`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ customerID, sessionID }),
    cache: 'no-store',
  });
  if (!res.ok) throw new Error('Failed to create booking');
  return res.json();
}