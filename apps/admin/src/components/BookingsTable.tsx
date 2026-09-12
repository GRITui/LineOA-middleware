"use client";

import { format } from "date-fns";

export type Booking = {
  id: string;
  customerName: string;
  lineUserID: string;
  status: string;
  createdDate: string;
  reminder24hSent: boolean;
  reminder2hSent: boolean;
  reminder15mSent: boolean;
};

interface BookingsTableProps {
  bookings: Booking[];
}

export const BookingsTable = ({ bookings }: BookingsTableProps) => {
  return (
    <div className="overflow-x-auto">
      <table className="min-w-full border-collapse">
        <thead className="bg-gray-100">
          <tr>
            <th className="p-2 border text-left">Customer Name</th>
            <th className="p-2 border text-left">Line User ID</th>
            <th className="p-2 border text-left">Status</th>
            <th className="p-2 border text-left">Created Date</th>
            <th className="p-2 border text-center">24h Reminder</th>
            <th className="p-2 border text-center">2h Reminder</th>
            <th className="p-2 border text-center">15min Reminder</th>
          </tr>
        </thead>
        <tbody>
          {bookings.map((booking) => (
            <tr key={booking.id} className="odd:bg-white even:bg-gray-50">
              <td className="p-2 border">{booking.customerName}</td>
              <td className="p-2 border">{booking.lineUserID}</td>
              <td className="p-2 border">{booking.status}</td>
              <td className="p-2 border">{format(new Date(booking.createdDate), "PPpp")}</td>
              <td className="p-2 border text-center">{booking.reminder24hSent ? "✓" : "✗"}</td>
              <td className="p-2 border text-center">{booking.reminder2hSent ? "✓" : "✗"}</td>
              <td className="p-2 border text-center">{booking.reminder15mSent ? "✓" : "✗"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};
