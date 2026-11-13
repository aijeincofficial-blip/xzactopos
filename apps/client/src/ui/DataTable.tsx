import type { ReactNode } from "react";
import { cn } from "../lib/utils.ts";

export interface DataTableColumn<T> {
  key: string;
  header: string;
  align?: "left" | "right";
  mono?: boolean;
  render: (row: T) => ReactNode;
}

/** Paper card data table (rounded-24, 56px rows, 1.5px dashed --dash dividers, sand row hover). */
export function DataTable<T>({
  columns,
  rows,
  rowKey,
  onRowClick,
  className,
}: {
  columns: ReadonlyArray<DataTableColumn<T>>;
  rows: ReadonlyArray<T>;
  rowKey: (row: T) => string;
  onRowClick?: (row: T) => void;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "overflow-x-auto rounded-[24px] border-[1.5px] border-sand-line bg-paper text-text-on-light",
        className,
      )}
    >
      <table className="w-full min-w-[560px] border-collapse text-left">
        <thead>
          <tr className="border-b-[1.5px] border-dashed border-dash">
            {columns.map((col) => (
              <th
                key={col.key}
                className={cn(
                  "px-5 py-4 font-mono text-xs font-normal tracking-[0.08em] text-muted-on-light uppercase",
                  col.align === "right" ? "text-right" : "text-left",
                )}
              >
                {col.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, idx) => (
            <tr
              key={rowKey(row)}
              onClick={onRowClick ? () => onRowClick(row) : undefined}
              className={cn(
                "h-14 transition-colors hover:bg-sand",
                idx < rows.length - 1 ? "border-b-[1.5px] border-dashed border-dash" : "",
                onRowClick ? "cursor-pointer" : "",
              )}
            >
              {columns.map((col) => (
                <td
                  key={col.key}
                  className={cn(
                    "px-5 py-3 text-[15px]",
                    col.align === "right" ? "text-right" : "text-left",
                    col.mono ? "font-mono text-sm font-semibold tabular-nums" : "",
                  )}
                >
                  {col.render(row)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
