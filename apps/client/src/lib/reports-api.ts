import { supabase } from "./supabase.ts";

export type ReportTotals = {
  net: number;
  gross: number;
  discount: number;
  tax: number;
  cogs: number;
  txns: number;
  cash: number;
  ewallet: number;
  card: number;
  utang: number;
  profit: number;
  margin_percent: number;
};

export type ReportDay = {
  day: string;
  net: number;
  gross: number;
  discount: number;
  tax: number;
  cogs: number;
  txns: number;
  cash: number;
  ewallet: number;
  card: number;
  utang: number;
  profit: number;
};

export type ReportTopItem = {
  variant_id: string;
  name: string;
  sku: string;
  qty: number;
  revenue: number;
  cogs: number;
  profit: number;
};

export type ReportStoreSummary = {
  location_id: string;
  code: string;
  name: string;
  type: "store" | "warehouse";
  net: number;
  gross: number;
  cogs: number;
  txns: number;
  profit: number;
  stock_value: number;
  stock_units: number;
};

export type ReportStockValuation = {
  total_value: number;
  total_units: number;
  items_count: number;
};

export type ReportTransfers = {
  total_transfers: number;
  shipped_count: number;
  received_count: number;
  discrepancy_count: number;
};

export type ReportExpenses = {
  total: number;
  cash: number;
  ewallet: number;
  count: number;
  by_category: Array<{ category: string; amount: number; count: number }>;
  days: Array<{ day: string; amount: number }>;
};

export type ReportServices = {
  count: number;
  fee_total: number;
  by_kind: Array<{ kind: string; count: number; amount: number; fee: number }>;
  float: Array<{ wallet: string; balance: number }>;
};

export type ReportUtang = {
  owed: number;
  customers: Array<{ id: string; name: string; balance: number }>;
};

export type ReportMultiStoreResult = {
  from: string;
  to: string;
  location_id: string | null;
  totals: ReportTotals;
  days: ReportDay[];
  top_items: ReportTopItem[];
  stores: ReportStoreSummary[];
  stock_valuation: ReportStockValuation;
  transfers: ReportTransfers;
  expenses: ReportExpenses;
  services: ReportServices;
  utang: ReportUtang;
  server_time: string;
};

/** Filter locations down to active branches/warehouses accessible to the current user. */
export function filterAccessibleReportLocations<T extends { id: string; active: boolean }>(
  locations: readonly T[],
  access: { role: string | null; locations: ReadonlyArray<{ id: string }> },
): T[] {
  const active = locations.filter((l) => l.active);
  if (access.role === "superadmin") return active;
  const allowed = new Set(access.locations.map((al) => al.id));
  return active.filter((l) => allowed.has(l.id));
}

/** Fetch multi-store summary report from rollups. */
export async function fetchMultiStoreReport(params: {
  from: string;
  to: string;
  locationId?: string | null;
}): Promise<ReportMultiStoreResult> {
  const { data, error } = await supabase.rpc("report_multi_store", {
    p_from: params.from,
    p_to: params.to,
    p_location_id: params.locationId || null,
  });

  if (error) throw error;
  return data as ReportMultiStoreResult;
}

/** Trigger daily stock snapshot RPC. */
export async function snapshotDailyStock(day?: string): Promise<number> {
  const { data, error } = await supabase.rpc("snapshot_daily_stock", {
    p_day: day || null,
  });
  if (error) throw error;
  return data as number;
}

/** Utility to trigger browser CSV file download. */
export function downloadCsv(filename: string, csvContent: string) {
  const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.setAttribute("href", url);
  link.setAttribute("download", filename);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

function escapeCsvField(val: string | number): string {
  const s = String(val ?? "");
  if (s.includes(",") || s.includes('"') || s.includes("\n")) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function slugifyLocation(label?: string): string {
  if (!label) return "";
  const slug = label
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
  return slug ? `_${slug}` : "";
}

export function buildDailySalesCsv(
  data: ReportMultiStoreResult,
  tenantName: string,
  locationLabel?: string,
): { filename: string; content: string } {
  const headers = ["Date", "Gross Sales", "Discounts", "Net Sales", "COGS", "Estimated Profit", "Transactions", "Cash", "E-Wallet", "Card", "Utang"];
  const rows = data.days.map((d) => [
    d.day,
    (d.gross / 100).toFixed(2),
    (d.discount / 100).toFixed(2),
    (d.net / 100).toFixed(2),
    (d.cogs / 100).toFixed(2),
    (d.profit / 100).toFixed(2),
    d.txns,
    (d.cash / 100).toFixed(2),
    (d.ewallet / 100).toFixed(2),
    ((d.card ?? 0) / 100).toFixed(2),
    (d.utang / 100).toFixed(2),
  ]);

  const meta = [
    `# Daily Sales Report - ${escapeCsvField(tenantName)}`,
    ...(locationLabel ? [`# Location: ${escapeCsvField(locationLabel)}`] : []),
    `# Period: ${data.from} to ${data.to}`,
  ];

  return {
    filename: `sales_daily${slugifyLocation(locationLabel)}_${data.from}_to_${data.to}.csv`,
    content: [
      ...meta,
      headers.map(escapeCsvField).join(","),
      ...rows.map((r) => r.map(escapeCsvField).join(",")),
    ].join("\r\n"),
  };
}

/** Exports daily sales trend to CSV. */
export function exportDailySalesCsv(data: ReportMultiStoreResult, tenantName: string, locationLabel?: string) {
  const { filename, content } = buildDailySalesCsv(data, tenantName, locationLabel);
  downloadCsv(filename, content);
}

export function buildTopProductsCsv(
  data: ReportMultiStoreResult,
  tenantName: string,
  locationLabel?: string,
): { filename: string; content: string } {
  const headers = ["Product Name", "SKU", "Quantity Sold", "Total Revenue", "COGS", "Gross Profit"];
  const rows = data.top_items.map((item) => [
    item.name,
    item.sku,
    item.qty,
    (item.revenue / 100).toFixed(2),
    (item.cogs / 100).toFixed(2),
    (item.profit / 100).toFixed(2),
  ]);

  const meta = [
    `# Product Performance Report - ${escapeCsvField(tenantName)}`,
    ...(locationLabel ? [`# Location: ${escapeCsvField(locationLabel)}`] : []),
    `# Period: ${data.from} to ${data.to}`,
  ];

  return {
    filename: `top_products${slugifyLocation(locationLabel)}_${data.from}_to_${data.to}.csv`,
    content: [
      ...meta,
      headers.map(escapeCsvField).join(","),
      ...rows.map((r) => r.map(escapeCsvField).join(",")),
    ].join("\r\n"),
  };
}

/** Exports top products to CSV. */
export function exportTopProductsCsv(data: ReportMultiStoreResult, tenantName: string, locationLabel?: string) {
  const { filename, content } = buildTopProductsCsv(data, tenantName, locationLabel);
  downloadCsv(filename, content);
}

/** Exports multi-store breakdown to CSV. */
export function exportStoresComparisonCsv(data: ReportMultiStoreResult, tenantName: string) {
  const headers = ["Code", "Location Name", "Type", "Net Sales", "COGS", "Gross Profit", "Transactions", "Current Stock Value", "Stock Units"];
  const rows = data.stores.map((s) => [
    s.code,
    s.name,
    s.type,
    (s.net / 100).toFixed(2),
    (s.cogs / 100).toFixed(2),
    (s.profit / 100).toFixed(2),
    s.txns,
    (s.stock_value / 100).toFixed(2),
    s.stock_units,
  ]);

  const csvContent = [
    `# Multi-Store Comparison Report - ${escapeCsvField(tenantName)}`,
    `# Period: ${data.from} to ${data.to}`,
    headers.map(escapeCsvField).join(","),
    ...rows.map((r) => r.map(escapeCsvField).join(",")),
  ].join("\r\n");

  downloadCsv(`store_comparison_${data.from}_to_${data.to}.csv`, csvContent);
}
