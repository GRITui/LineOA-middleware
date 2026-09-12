"use client";

export type Customer = {
  id: string;
  name: string;
  email?: string;
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
            <th className="p-2 border text-left">Email</th>
            <th className="p-2 border text-center">Booking Count</th>
          </tr>
        </thead>
        <tbody>
          {customers.map((customer) => (
            <tr key={customer.id} className="odd:bg-white even:bg-gray-50">
              <td className="p-2 border">{customer.name}</td>
              <td className="p-2 border">{customer.email ?? "-"}</td>
              <td className="p-2 border text-center">{customer.bookingCount}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};
