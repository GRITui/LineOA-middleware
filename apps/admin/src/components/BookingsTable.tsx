"use client";

// Mirrors SessionController.BookingWithCustomer in apps/api.
export type Booking = {
  bookingID: string;
  status: string;
  createdDate: string | null;
  customerID: string;
  customerName: string;
  customerLineUserID: string;
  customerPhone: string | null;
  customerEmail: string | null;
  reminder24Sent: boolean;
  reminder2Sent: boolean;
  reminder15Sent: boolean;
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
            <tr key={booking.bookingID} className="odd:bg-white even:bg-gray-50">
              <td className="p-2 border">{booking.customerName}</td>
              <td className="p-2 border">{booking.customerLineUserID}</td>
              <td className="p-2 border">{booking.status}</td>
              <td className="p-2 border">
                {booking.createdDate ? new Date(booking.createdDate).toLocaleString() : "-"}
              </td>
              <td className="p-2 border text-center">{booking.reminder24Sent ? "✓" : "✗"}</td>
              <td className="p-2 border text-center">{booking.reminder2Sent ? "✓" : "✗"}</td>
              <td className="p-2 border text-center">{booking.reminder15Sent ? "✓" : "✗"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};
