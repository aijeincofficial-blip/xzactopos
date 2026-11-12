import { fromMajor } from "@pos/core";
import type { ProductRow } from "./stock-api.ts";

export const IMPORT_MAX_ROWS = 500;

export const PRODUCTS_CSV_TEMPLATE =
  "Name,SKU,Barcode,Category,Price,Cost,Unit,TaxRate,Tracked,Active,ReorderPoint,OnHand,ExpiresOn\r\n";

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
  let str = String(val);
  // Guard against spreadsheet formula execution (=, +, @) matching Mobile export.dart
  if (str.length > 0 && "=+@".includes(str[0]!)) {
    str = `'${str}`;
  }
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
  const withBom = content.startsWith("\uFEFF") ? content : `\uFEFF${content}`;
  const blob = new Blob([withBom], { type: "text/csv;charset=utf-8;" });
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

export interface CustomerLedgerExportItem {
  date: string;
  kind: string;
  description: string;
  method?: string;
  amount: number;
}

export interface SaleExportItem {
  receiptNo: string;
  soldAt: string;
  status: "completed" | "voided";
  customer: string | null;
  paymentMethods: string;
  subtotal: number;
  discount: number;
  total: number;
  refunded: number;
  netTotal: number;
}

export interface AuditLogExportItem {
  createdAt: string;
  action: string;
  category: string;
  actor: string;
  location: string;
  entity: string;
  entityId: string | null;
  details: string;
}

export interface ExpenseExportItem {
  spentAt: string;
  status: "active" | "voided";
  category: string;
  paidFrom: string;
  wallet: string | null;
  amount: number;
  note: string | null;
  voidReason: string | null;
}

export interface ServiceTxnExportItem {
  txnAt: string;
  status: "active" | "voided";
  kind: string;
  wallet: string;
  amount: number;
  fee: number;
  cashEffect: number;
  floatEffect: number;
  ref: string | null;
  note: string | null;
  voidReason: string | null;
}

export function exportServiceTxnsCsv(items: ServiceTxnExportItem[], currency = "PHP"): string {
  const headers = [
    "Timestamp",
    "Status",
    "Entry Type",
    "Wallet",
    `Principal (${currency})`,
    `Fee (${currency})`,
    `Drawer Cash Effect (${currency})`,
    `Wallet Float Effect (${currency})`,
    "Reference",
    "Note",
    "Void Reason",
  ];
  const lines = [headers.join(",")];
  for (const item of items) {
    lines.push(
      [
        escapeCsvField(item.txnAt),
        escapeCsvField(item.status),
        escapeCsvField(item.kind),
        escapeCsvField(item.wallet),
        escapeCsvField((item.amount / 100).toFixed(2)),
        escapeCsvField((item.fee / 100).toFixed(2)),
        escapeCsvField((item.cashEffect / 100).toFixed(2)),
        escapeCsvField((item.floatEffect / 100).toFixed(2)),
        escapeCsvField(item.ref ?? ""),
        escapeCsvField(item.note ?? ""),
        escapeCsvField(item.voidReason ?? ""),
      ].join(","),
    );
  }
  return lines.join("\r\n");
}

export interface TransferExportItem {
  transferNo: string;
  status: string;
  origin: string;
  destination: string;
  lines: number;
  shippedUnits: number;
  receivedUnits: number | null;
  discrepancy: boolean;
  createdAt: string;
  notes: string | null;
}

export function exportTransfersCsv(items: TransferExportItem[]): string {
  const headers = [
    "Transfer No",
    "Status",
    "Origin",
    "Destination",
    "Lines",
    "Shipped Units",
    "Received Units",
    "Discrepancy",
    "Created At",
    "Notes",
  ];
  const lines = [headers.join(",")];
  for (const item of items) {
    lines.push(
      [
        escapeCsvField(item.transferNo),
        escapeCsvField(item.status),
        escapeCsvField(item.origin),
        escapeCsvField(item.destination),
        escapeCsvField(item.lines),
        escapeCsvField(item.shippedUnits),
        escapeCsvField(item.receivedUnits !== null ? item.receivedUnits : ""),
        escapeCsvField(item.discrepancy ? "yes" : "no"),
        escapeCsvField(item.createdAt),
        escapeCsvField(item.notes ?? ""),
      ].join(","),
    );
  }
  return lines.join("\r\n");
}

export interface ReorderExportItem {
  warehouse: string;
  product: string;
  sku: string;
  onHand: number;
  reorderPoint: number;
  thresholdType: "custom" | "default";
  incoming: number;
  onOrder: number;
  status: string;
  shortfall: number;
}

export function exportReorderListCsv(items: ReorderExportItem[]): string {
  const headers = [
    "Warehouse",
    "Product",
    "SKU",
    "On Hand",
    "Reorder Point",
    "Threshold Type",
    "In Transit",
    "On Order",
    "Status",
    "Shortfall",
  ];
  const lines = [headers.join(",")];
  for (const item of items) {
    lines.push(
      [
        escapeCsvField(item.warehouse),
        escapeCsvField(item.product),
        escapeCsvField(item.sku),
        escapeCsvField(item.onHand),
        escapeCsvField(item.reorderPoint),
        escapeCsvField(item.thresholdType),
        escapeCsvField(item.incoming),
        escapeCsvField(item.onOrder),
        escapeCsvField(item.status),
        escapeCsvField(item.shortfall),
      ].join(","),
    );
  }
  return lines.join("\r\n");
}

export function exportExpensesCsv(items: ExpenseExportItem[], currency = "PHP"): string {
  const headers = [
    "Spent At",
    "Status",
    "Category",
    "Paid From",
    "Wallet",
    `Amount (${currency})`,
    "Note",
    "Void Reason",
  ];
  const lines = [headers.join(",")];
  for (const item of items) {
    lines.push(
      [
        escapeCsvField(item.spentAt),
        escapeCsvField(item.status),
        escapeCsvField(item.category),
        escapeCsvField(item.paidFrom),
        escapeCsvField(item.wallet ?? ""),
        escapeCsvField((item.amount / 100).toFixed(2)),
        escapeCsvField(item.note ?? ""),
        escapeCsvField(item.voidReason ?? ""),
      ].join(","),
    );
  }
  return lines.join("\r\n");
}

export function exportAuditLogsCsv(items: AuditLogExportItem[]): string {
  const headers = [
    "Timestamp",
    "Action",
    "Category",
    "Actor",
    "Location",
    "Entity",
    "Entity ID",
    "Details",
  ];
  const lines = [headers.join(",")];
  for (const item of items) {
    lines.push(
      [
        escapeCsvField(item.createdAt),
        escapeCsvField(item.action),
        escapeCsvField(item.category),
        escapeCsvField(item.actor),
        escapeCsvField(item.location),
        escapeCsvField(item.entity),
        escapeCsvField(item.entityId ?? ""),
        escapeCsvField(item.details),
      ].join(","),
    );
  }
  return lines.join("\r\n");
}

export function exportSalesCsv(items: SaleExportItem[], currency = "PHP"): string {
  const headers = [
    "Receipt No",
    "Sold At",
    "Status",
    "Customer",
    "Payment Methods",
    `Subtotal (${currency})`,
    `Discount (${currency})`,
    `Total (${currency})`,
    `Refunded (${currency})`,
    `Net Total (${currency})`,
  ];
  const lines = [headers.join(",")];
  for (const item of items) {
    lines.push([
      escapeCsvField(item.receiptNo),
      escapeCsvField(item.soldAt),
      escapeCsvField(item.status),
      escapeCsvField(item.customer ?? ""),
      escapeCsvField(item.paymentMethods),
      escapeCsvField((item.subtotal / 100).toFixed(2)),
      escapeCsvField((item.discount / 100).toFixed(2)),
      escapeCsvField((item.total / 100).toFixed(2)),
      escapeCsvField((item.refunded / 100).toFixed(2)),
      escapeCsvField((item.netTotal / 100).toFixed(2)),
    ].join(","));
  }
  return lines.join("\r\n");
}

export function exportCustomerLedgerCsv(
  customerName: string,
  items: CustomerLedgerExportItem[],
  currency = "PHP"
): string {
  const headers = [
    "Date",
    "Customer",
    "Transaction Type",
    "Description / Note",
    "Payment Method",
    `Amount (${currency})`,
  ];
  const lines = [headers.join(",")];
  for (const item of items) {
    lines.push([
      escapeCsvField(item.date),
      escapeCsvField(customerName),
      escapeCsvField(item.kind),
      escapeCsvField(item.description),
      escapeCsvField(item.method || "—"),
      escapeCsvField((item.amount / 100).toFixed(2)),
    ].join(","));
  }
  return lines.join("\r\n");
}

/** Parses RFC-4180 CSV or spreadsheet-pasted TSV/semicolon text with quotes, escaped quotes (""), and BOM stripping. */
export function parseCsv(text: string): string[][] {
  const src = text.startsWith("\uFEFF") ? text.slice(1) : text;
  const firstNonEmpty = src
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .split("\n")
    .find((l) => l.trim().length > 0) ?? "";
  let delim = ",";
  if (firstNonEmpty.includes("\t")) {
    delim = "\t";
  } else if ((firstNonEmpty.match(/;/g)?.length ?? 0) > (firstNonEmpty.match(/,/g)?.length ?? 0)) {
    delim = ";";
  }

  const rows: string[][] = [];
  let currentRow: string[] = [];
  let currentVal = "";
  let insideQuotes = false;

  for (let i = 0; i < src.length; i++) {
    const char = src[i];
    const nextChar = src[i + 1];

    if (char === '"') {
      if (insideQuotes && nextChar === '"') {
        currentVal += '"';
        i++; // skip escaped quote
      } else {
        insideQuotes = !insideQuotes;
      }
    } else if (char === delim && !insideQuotes) {
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

const HEADER_ALIASES: Record<string, readonly string[]> = {
  name: ["name", "product", "item", "pangalan", "produkto"],
  price: ["price", "presyo", "sellingprice"],
  sku: ["sku"],
  barcode: ["barcode", "code"],
  category: ["category", "kategorya"],
  cost: ["cost", "puhunan", "capital"],
  unit: ["unit"],
  taxrate: ["taxrate", "tax"],
  tracked: ["tracked"],
  active: ["active"],
  reorderpoint: ["reorderpoint", "reorder"],
  openingqty: ["onhand", "openingqty", "stock", "qty", "quantity", "bilang"],
  expireson: ["expireson", "expiry"],
};

function parseCsvMoney(raw: string, currency: string): number | null {
  const cleaned = raw.replace(/[₱\s,]|php/gi, "").trim();
  if (!cleaned) return null;
  try {
    const m = fromMajor(cleaned, currency);
    return m.amount >= 0 ? m.amount : null;
  } catch {
    return null;
  }
}

export function matchExistingProduct(
  item: Pick<ParsedProductImport, "sku" | "barcode">,
  existingRows: readonly ProductRow[],
): ProductRow | null {
  const sku = item.sku.trim().toLowerCase();
  if (sku) {
    const bySku = existingRows.find((r) => r.sku.trim().toLowerCase() === sku);
    if (bySku) return bySku;
  }
  const barcode = item.barcode.trim().toLowerCase();
  if (barcode) {
    const byBarcode = existingRows.find(
      (r) => r.barcode && r.barcode.trim().toLowerCase() === barcode,
    );
    if (byBarcode) return byBarcode;
  }
  return null;
}

export function parseAndValidateImport(
  csvText: string,
  currency = "PHP",
): { valid: ParsedProductImport[]; errors: string[]; tooMany: boolean } {
  const grid = parseCsv(csvText);
  const firstRow = grid[0];
  if (!firstRow) {
    return { valid: [], errors: ["CSV file is empty or missing data rows."], tooMany: false };
  }

  const normalizedFirst = firstRow.map((h) => h.toLowerCase().replace(/[^a-z0-9]/g, ""));
  const colIndex = new Map<string, number>();
  for (const [canonical, aliases] of Object.entries(HEADER_ALIASES)) {
    const idx = normalizedFirst.findIndex((h) => aliases.includes(h));
    if (idx >= 0) colIndex.set(canonical, idx);
  }

  const hasHeader = colIndex.has("name") || colIndex.has("price");
  if (hasHeader && grid.length < 2) {
    return { valid: [], errors: ["CSV file is empty or missing data rows."], tooMany: false };
  }

  let startIdx = 1;
  if (!hasHeader) {
    // Headerless spreadsheet paste fallback matching Mobile parseProductCsv:
    // name, price, barcode, cost, stock, unit
    colIndex.set("name", 0);
    colIndex.set("price", 1);
    colIndex.set("barcode", 2);
    colIndex.set("cost", 3);
    colIndex.set("openingqty", 4);
    colIndex.set("unit", 5);
    startIdx = 0;
  }

  const getCol = (row: string[], key: string): string => {
    const idx = colIndex.get(key);
    return idx !== undefined && row[idx] !== undefined ? row[idx]! : "";
  };

  const valid: ParsedProductImport[] = [];
  const errors: string[] = [];
  let tooMany = false;

  for (let i = startIdx; i < grid.length; i++) {
    if (valid.length + errors.length >= IMPORT_MAX_ROWS) {
      tooMany = true;
      break;
    }
    const row = grid[i];
    if (!row) continue;
    const lineNo = i + 1;
    const name = getCol(row, "name");
    if (!name) {
      errors.push(`Line ${lineNo}: Missing product name.`);
      continue;
    }

    const priceRaw = getCol(row, "price");
    const priceMinor = parseCsvMoney(priceRaw, currency);
    if (priceMinor === null) {
      errors.push(`Line ${lineNo}: Invalid price "${priceRaw}".`);
      continue;
    }

    const costRaw = getCol(row, "cost");
    const costMinor = costRaw ? parseCsvMoney(costRaw, currency) : 0;
    if (costMinor === null) {
      errors.push(`Line ${lineNo}: Invalid cost "${costRaw}".`);
      continue;
    }

    const taxRaw = getCol(row, "taxrate");
    const taxNum = taxRaw ? parseFloat(taxRaw) : 0;
    const taxRate = !isNaN(taxNum) ? (taxNum > 1 ? taxNum / 100 : taxNum) : 0;

    const reorderRaw = getCol(row, "reorderpoint");
    const reorderPoint = reorderRaw ? parseFloat(reorderRaw) : 0;

    const openingRaw = getCol(row, "openingqty");
    const openingQty = openingRaw ? parseFloat(openingRaw) : 0;
    if (openingRaw && (isNaN(openingQty) || openingQty < 0)) {
      errors.push(`Line ${lineNo}: Invalid stock quantity "${openingRaw}".`);
      continue;
    }

    const trackedRaw = getCol(row, "tracked").toLowerCase();
    const tracked = trackedRaw === "" ? true : ["true", "1", "yes"].includes(trackedRaw);

    const activeRaw = getCol(row, "active").toLowerCase();
    const active = activeRaw === "" ? true : ["true", "1", "yes"].includes(activeRaw);

    valid.push({
      name,
      sku: getCol(row, "sku"),
      barcode: getCol(row, "barcode"),
      category: getCol(row, "category"),
      price: priceMinor,
      cost: costMinor,
      unit: getCol(row, "unit") || "pc",
      taxRate: Math.max(0, Math.min(taxRate, 0.9999)),
      tracked,
      active,
      reorderPoint: isNaN(reorderPoint) ? 0 : Math.max(0, reorderPoint),
      openingQty: isNaN(openingQty) ? 0 : Math.max(0, openingQty),
      expiresOn: getCol(row, "expireson"),
    });
  }

  return { valid, errors, tooMany };
}
