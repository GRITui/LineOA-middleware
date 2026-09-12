type ReportsTableProps = {
  columns: string[];
  rows: string[][];
};

export default function ReportsTable({ columns, rows }: ReportsTableProps) {
  return (
    <table className="min-w-full border border-gray-200">
      <thead className="bg-gray-100">
        <tr>
          {columns.map(col => (
            <th key={col} className="px-4 py-2 text-left font-medium">
              {col}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {rows.map((row, i) => (
          <tr key={i} className={i % 2 ? 'bg-white' : 'bg-gray-50'}>
            {row.map((cell, j) => (
              <td key={j} className="px-4 py-2 border-t border-gray-200">
                {cell}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}