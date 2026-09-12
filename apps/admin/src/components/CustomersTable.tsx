"use client";

// Mirrors CustomerWithBookingCount in apps/api (no email field on the backend).
export type Customer = {
  id: string;
  lineUserID: string;
  name: string;
  bookingCount: number;
};

interface CustomersTableProps {
  customers: Customer[];
}

export const CustomersTable = ({ customers }: CustomersTableProps) => {
  return (
    <div className="overflow-x-auto">
      <table className="min-w-full border-collapse">
        <thead className="bg-gray-100">
          <tr>
            <th className="p-2 border text-left">Customer Name</th>
            <th className="p-2 border text-left">LINE User ID</th>
            <th className="p-2 border text-center">Booking Count</th>
          </tr>
        </thead>
        <tbody>
          {customers.map((customer) => (
            <tr key={customer.id} className="odd:bg-white even:bg-gray-50">
              <td className="p-2 border">{customer.name}</td>
              <td className="p-2 border">{customer.lineUserID}</td>
              <td className="p-2 border text-center">{customer.bookingCount}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};
