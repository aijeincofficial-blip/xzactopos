import type { ProductRow } from "./stock-api.ts";

export interface ParsedProductImport {
  name: string;
  sku: string;
  barcode: string;
  category: string;
  price: number; // minor units
  cost: number;  // minor units
  unit: string;
  taxRate: number;
  tracked: boolean;
  active: boolean;
  reorderPoint: number;
  openingQty: number;
  expiresOn: string;
}

function escapeCsvField(val: string | number | boolean | null | undefined): string {
  if (val === null || val === undefined) return "";
  const str = String(val);
  if (str.includes(",") || str.includes('"') || str.includes("\n") || str.includes("\r")) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

export function exportProductsCsv(rows: ProductRow[], _currency?: string): string {
  const headers = [
    "Name",
    "SKU",
    "Barcode",
    "Category",
    "Price",
    "Cost",
    "Unit",
    "TaxRate",
    "Tracked",
    "Active",
    "ReorderPoint",
    "OnHand",
    "ExpiresOn",
  ];

  const lines = [headers.join(",")];
  for (const r of rows) {
    const priceMajor = r.price !== null ? (r.price / 100).toFixed(2) : "";
    const costMajor = (r.cost / 100).toFixed(2);
    lines.push([
      escapeCsvField(r.name),
      escapeCsvField(r.sku),
      escapeCsvField(r.barcode ?? ""),
      escapeCsvField(r.categoryName ?? ""),
      escapeCsvField(priceMajor),
      escapeCsvField(costMajor),
      escapeCsvField(r.unit),
      escapeCsvField((r.taxRate * 100).toFixed(2)),
      escapeCsvField(r.tracked ? "true" : "false"),
      escapeCsvField(r.active ? "true" : "false"),
      escapeCsvField(r.reorderPoint),
      escapeCsvField(r.qty),
      escapeCsvField(r.expiresOn ?? ""),
    ].join(","));
  }
  return lines.join("\r\n");
}

export function downloadCsv(content: string, filename: string): void {
  const blob = new Blob([content], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.setAttribute("href", url);
  link.setAttribute("download", filename);
  link.style.visibility = "hidden";
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

export interface ShiftExportItem {
  id: string;
  cashier: string;
  status: "open" | "closed";
  openedAt: string;
  closedAt: string | null;
  openingCash: number;
  expectedCash: number | null;
  countedCash: number | null;
  difference: number | null;
  closedBy: string | null;
  note: string | null;
}

export function exportShiftsCsv(shifts: ShiftExportItem[]): string {
  const headers = [
    "Shift ID",
    "Cashier",
    "Status",
    "Opened At",
    "Closed At",
    "Opening Cash",
    "Expected Cash",
    "Counted Cash",
    "Difference",
    "Closed By",
    "Note",
  ];
  const lines = [headers.join(",")];
  for (const s of shifts) {
    lines.push([
      escapeCsvField(s.id),
      escapeCsvField(s.cashier),
      escapeCsvField(s.status),
      escapeCsvField(s.openedAt),
      escapeCsvField(s.closedAt ?? ""),
      escapeCsvField((s.openingCash / 100).toFixed(2)),
      escapeCsvField(s.expectedCash !== null ? (s.expectedCash / 100).toFixed(2) : ""),
      escapeCsvField(s.countedCash !== null ? (s.countedCash / 100).toFixed(2) : ""),
      escapeCsvField(s.difference !== null ? (s.difference / 100).toFixed(2) : ""),
      escapeCsvField(s.closedBy ?? ""),
      escapeCsvField(s.note ?? ""),
    ].join(","));
  }
  return lines.join("\r\n");
}

export interface DayCloseExportItem {
  day: string;
  openingCash: number;
  expectedCash: number;
  countedCash: number;
  difference: number;
  closedAt: string;
  closedBy: string | null;
  note: string | null;
}

export function exportDayClosesCsv(closes: DayCloseExportItem[]): string {
  const headers = [
    "Date",
    "Opening Cash",
    "Expected Cash",
    "Counted Cash",
    "Difference",
    "Closed At",
    "Closed By",
    "Note",
  ];
  const lines = [headers.join(",")];
  for (const c of closes) {
    lines.push([
      escapeCsvField(c.day),
      escapeCsvField((c.openingCash / 100).toFixed(2)),
      escapeCsvField((c.expectedCash / 100).toFixed(2)),
      escapeCsvField((c.countedCash / 100).toFixed(2)),
      escapeCsvField((c.difference / 100).toFixed(2)),
      escapeCsvField(c.closedAt),
      escapeCsvField(c.closedBy ?? ""),
      escapeCsvField(c.note ?? ""),
    ].join(","));
  }
  return lines.join("\r\n");
}

/** Parses standard CSV text with quotes, escaped quotes (""), and commas. */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let currentRow: string[] = [];
  let currentVal = "";
  let insideQuotes = false;

  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    const nextChar = text[i + 1];

    if (char === '"') {
      if (insideQuotes && nextChar === '"') {
        currentVal += '"';
        i++; // skip escaped quote
      } else {
        insideQuotes = !insideQuotes;
      }
    } else if (char === "," && !insideQuotes) {
      currentRow.push(currentVal.trim());
      currentVal = "";
    } else if ((char === "\r" || char === "\n") && !insideQuotes) {
      if (char === "\r" && nextChar === "\n") i++; // handle CRLF
      currentRow.push(currentVal.trim());
      if (currentRow.some((c) => c !== "")) {
        rows.push(currentRow);
      }
      currentRow = [];
      currentVal = "";
    } else {
      currentVal += char;
    }
  }

  if (currentVal.length > 0 || currentRow.length > 0) {
    currentRow.push(currentVal.trim());
    if (currentRow.some((c) => c !== "")) {
      rows.push(currentRow);
    }
  }

  return rows;
}

export function parseAndValidateImport(csvText: string): { valid: ParsedProductImport[]; errors: string[] } {
  const grid = parseCsv(csvText);
  const headerRow = grid[0];
  if (!headerRow || grid.length < 2) {
    return { valid: [], errors: ["CSV file is empty or missing data rows."] };
  }

  const rawHeaders = headerRow.map((h) => h.toLowerCase().replace(/[^a-z0-9]/g, ""));
  const headerMap = new Map<string, number>();
  rawHeaders.forEach((h, idx) => headerMap.set(h, idx));

  const getCol = (row: string[], name: string): string => {
    const idx = headerMap.get(name);
    return idx !== undefined && row[idx] !== undefined ? row[idx]! : "";
  };

  const valid: ParsedProductImport[] = [];
  const errors: string[] = [];

  for (let i = 1; i < grid.length; i++) {
    const row = grid[i];
    if (!row) continue;
    const lineNo = i + 1;
    const name = getCol(row, "name");
    if (!name) {
      errors.push(`Line ${lineNo}: Missing product name.`);
      continue;
    }

    const priceRaw = getCol(row, "price");
    const priceNum = parseFloat(priceRaw);
    if (isNaN(priceNum) || priceNum < 0) {
      errors.push(`Line ${lineNo}: Invalid price "${priceRaw}".`);
      continue;
    }

    const costRaw = getCol(row, "cost");
    const costNum = costRaw ? parseFloat(costRaw) : 0;
    if (isNaN(costNum) || costNum < 0) {
      errors.push(`Line ${lineNo}: Invalid cost "${costRaw}".`);
      continue;
    }

    const taxRaw = getCol(row, "taxrate");
    const taxNum = taxRaw ? parseFloat(taxRaw) : 0;
    const taxRate = !isNaN(taxNum) ? (taxNum > 1 ? taxNum / 100 : taxNum) : 0;

    const reorderRaw = getCol(row, "reorderpoint");
    const reorderPoint = reorderRaw ? parseFloat(reorderRaw) : 0;

    const openingRaw = getCol(row, "onhand") || getCol(row, "openingqty");
    const openingQty = openingRaw ? parseFloat(openingRaw) : 0;

    const trackedRaw = getCol(row, "tracked").toLowerCase();
    const tracked = trackedRaw === "" ? true : ["true", "1", "yes"].includes(trackedRaw);

    const activeRaw = getCol(row, "active").toLowerCase();
    const active = activeRaw === "" ? true : ["true", "1", "yes"].includes(activeRaw);

    valid.push({
      name,
      sku: getCol(row, "sku"),
      barcode: getCol(row, "barcode"),
      category: getCol(row, "category"),
      price: Math.round(priceNum * 100),
      cost: Math.round(costNum * 100),
      unit: getCol(row, "unit") || "pc",
      taxRate: Math.max(0, Math.min(taxRate, 0.9999)),
      tracked,
      active,
      reorderPoint: isNaN(reorderPoint) ? 0 : Math.max(0, reorderPoint),
      openingQty: isNaN(openingQty) ? 0 : Math.max(0, openingQty),
      expiresOn: getCol(row, "expireson"),
    });
  }

  return { valid, errors };
}
