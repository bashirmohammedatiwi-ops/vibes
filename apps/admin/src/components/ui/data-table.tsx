import type { ReactNode } from "react";

type Column<T> = {
  key: string;
  header: ReactNode;
  cell: (row: T) => ReactNode;
  className?: string;
};

type Props<T> = {
  columns: Column<T>[];
  rows: T[];
  rowKey: (row: T) => string;
  onRowClick?: (row: T) => void;
  empty?: ReactNode;
};

export function DataTable<T>({ columns, rows, rowKey, onRowClick, empty }: Props<T>) {
  if (!rows.length && empty) return <>{empty}</>;

  return (
    <div className="data-table-wrap hidden overflow-x-auto md:block">
      <table className="data-table w-full min-w-[720px] text-right text-sm">
        <thead>
          <tr>
            {columns.map((col) => (
              <th key={col.key} className={col.className}>
                {col.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr
              key={rowKey(row)}
              className={onRowClick ? "cursor-pointer" : undefined}
              onClick={(e) => {
                if ((e.target as HTMLElement).closest("button, a, input, select, textarea")) return;
                onRowClick?.(row);
              }}
            >
              {columns.map((col) => (
                <td key={col.key} className={col.className}>
                  {col.cell(row)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
