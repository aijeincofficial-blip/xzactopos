import { useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Badge, Button, Card, ErrorState, PageHeader, useToast } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { listLocations } from "../lib/api.ts";
import {
  exportDailySalesCsv,
  exportStoresComparisonCsv,
  exportTopProductsCsv,
  fetchMultiStoreReport,
  snapshotDailyStock,
} from "../lib/reports-api.ts";

function toDateString(d: Date): string {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function ReportsPage() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const { access, can } = useSession();
  const toast = useToast();
  const currency = access.tenant.base_currency ?? "PHP";

  // Date ranges
  const today = useMemo(() => new Date(), []);
  const todayStr = useMemo(() => toDateString(today), [today]);

  const [datePreset, setDatePreset] = useState<"today" | "7d" | "mtd" | "30d" | "custom">("7d");
  const [fromDate, setFromDate] = useState(() => {
    const d = new Date();
    d.setDate(d.getDate() - 6);
    return toDateString(d);
  });
  const [toDate, setToDate] = useState(todayStr);
  const [selectedLocationId, setSelectedLocationId] = useState<string>("all");

  function handlePresetChange(preset: "today" | "7d" | "mtd" | "30d" | "custom") {
    setDatePreset(preset);
    const now = new Date();
    if (preset === "today") {
      setFromDate(toDateString(now));
      setToDate(toDateString(now));
    } else if (preset === "7d") {
      const d = new Date();
      d.setDate(d.getDate() - 6);
      setFromDate(toDateString(d));
      setToDate(toDateString(now));
    } else if (preset === "mtd") {
      const d = new Date(now.getFullYear(), now.getMonth(), 1);
      setFromDate(toDateString(d));
      setToDate(toDateString(now));
    } else if (preset === "30d") {
      const d = new Date();
      d.setDate(d.getDate() - 29);
      setFromDate(toDateString(d));
      setToDate(toDateString(now));
    }
  }

  // Locations Query
  const locationsQuery = useQuery({
    queryKey: ["locations"],
    queryFn: listLocations,
    staleTime: 60_000,
  });

  const availableLocations = useMemo(() => {
    const all = (locationsQuery.data ?? []).filter((l) => l.active);
    if (access.role === "superadmin") return all;
    return all.filter((l) => access.locations.some((al) => al.id === l.id));
  }, [locationsQuery.data, access]);

  // Report Query
  const reportQuery = useQuery({
    queryKey: ["multi-store-report", fromDate, toDate, selectedLocationId],
    queryFn: () =>
      fetchMultiStoreReport({
        from: fromDate,
        to: toDate,
        locationId: selectedLocationId === "all" ? null : selectedLocationId,
      }),
    refetchInterval: 60_000,
  });

  // Snapshot Mutation
  const snapshotMutation = useMutation({
    mutationFn: () => snapshotDailyStock(),
    onSuccess: () => {
      toast.good(t("admin:reports.snapshotSuccess", { defaultValue: "Stock snapshot recorded" }));
      void reportQuery.refetch();
    },
    onError: () => {
      toast.error(t("admin:reports.snapshotError", { defaultValue: "Failed to snapshot stock" }));
    },
  });

  const rep = reportQuery.data;

  const fmt = (centavos: number) => formatMoney(money(centavos, currency), i18n.language);

  // Maximum daily net sales for relative bar chart heights
  const maxDayNet = useMemo(() => {
    if (!rep || rep.days.length === 0) return 1;
    return Math.max(...rep.days.map((d) => d.net), 1);
  }, [rep]);

  const avgTxnValue = useMemo(() => {
    if (!rep || rep.totals.txns === 0) return 0;
    return Math.round(rep.totals.net / rep.totals.txns);
  }, [rep]);

  const canSnapshot = can("stock.adjust_warehouse") || access.role === "superadmin";

  return (
    <div className="grid gap-6">
      {/* Title & Actions */}
      <PageHeader
        title={t("admin:reports.title")}
        subtitle={t("admin:reports.subtitle")}
        actions={
          <div className="flex flex-wrap items-center gap-2">
            {canSnapshot && (
              <Button
                variant="outline"
                size="sm"
                disabled={snapshotMutation.isPending}
                onClick={() => snapshotMutation.mutate()}
              >
                {snapshotMutation.isPending
                  ? t("admin:reports.snapshotting")
                  : t("admin:reports.snapshotNow")}
              </Button>
            )}

            {rep && (
              <div className="flex items-center gap-1.5">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => exportDailySalesCsv(rep, access.tenant.name)}
                >
                  📥 {t("admin:reports.exportDaily")}
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => exportTopProductsCsv(rep, access.tenant.name)}
                >
                  📥 {t("admin:reports.exportProducts")}
                </Button>
                {rep.stores.length > 1 && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => exportStoresComparisonCsv(rep, access.tenant.name)}
                  >
                    📥 {t("admin:reports.exportStores")}
                  </Button>
                )}
              </div>
            )}
          </div>
        }
      />

      {/* Filter Bar */}
      <Card className="flex flex-wrap items-center justify-between gap-4">
        {/* Location Filter */}
        <div className="flex items-center gap-2">
          <span className="text-xs font-semibold uppercase text-slate-500">
            {t("admin:reports.location")}:
          </span>
          <select
            value={selectedLocationId}
            onChange={(e) => setSelectedLocationId(e.target.value)}
            className="rounded border border-slate-300 bg-white px-2 py-1 text-xs font-medium text-slate-700"
          >
            <option value="all">{t("admin:reports.allLocations")}</option>
            {availableLocations.map((loc) => (
              <option key={loc.id} value={loc.id}>
                {loc.type === "warehouse" ? "🏢" : "🏪"} {loc.code} · {loc.name}
              </option>
            ))}
          </select>
        </div>

        {/* Date Presets & Custom Range */}
        <div className="flex flex-wrap items-center gap-2">
          <div className="inline-flex rounded-md border border-slate-200 bg-slate-50 p-0.5 text-xs">
            <button
              type="button"
              onClick={() => handlePresetChange("today")}
              className={`rounded px-2.5 py-1 font-medium transition ${
                datePreset === "today" ? "bg-white text-slate-900 shadow-sm" : "text-slate-600 hover:text-slate-900"
              }`}
            >
              {t("admin:reports.today")}
            </button>
            <button
              type="button"
              onClick={() => handlePresetChange("7d")}
              className={`rounded px-2.5 py-1 font-medium transition ${
                datePreset === "7d" ? "bg-white text-slate-900 shadow-sm" : "text-slate-600 hover:text-slate-900"
              }`}
            >
              {t("admin:reports.last7Days")}
            </button>
            <button
              type="button"
              onClick={() => handlePresetChange("mtd")}
              className={`rounded px-2.5 py-1 font-medium transition ${
                datePreset === "mtd" ? "bg-white text-slate-900 shadow-sm" : "text-slate-600 hover:text-slate-900"
              }`}
            >
              {t("admin:reports.monthToDate")}
            </button>
            <button
              type="button"
              onClick={() => handlePresetChange("30d")}
              className={`rounded px-2.5 py-1 font-medium transition ${
                datePreset === "30d" ? "bg-white text-slate-900 shadow-sm" : "text-slate-600 hover:text-slate-900"
              }`}
            >
              {t("admin:reports.last30Days")}
            </button>
          </div>

          <div className="flex items-center gap-1.5 text-xs text-slate-600">
            <input
              type="date"
              value={fromDate}
              max={toDate}
              onChange={(e) => {
                setDatePreset("custom");
                setFromDate(e.target.value);
              }}
              className="rounded border border-slate-300 px-2 py-1 text-xs"
            />
            <span>→</span>
            <input
              type="date"
              value={toDate}
              min={fromDate}
              max={todayStr}
              onChange={(e) => {
                setDatePreset("custom");
                setToDate(e.target.value);
              }}
              className="rounded border border-slate-300 px-2 py-1 text-xs"
            />
          </div>
        </div>
      </Card>

      {/* Loading & Content */}
      {reportQuery.isLoading ? (
        <Card className="py-12 text-center text-slate-500">
          {t("admin:reports.loading")}
        </Card>
      ) : reportQuery.isError ? (
        <ErrorState
          message={t("admin:reports.noData")}
          onRetry={() => void reportQuery.refetch()}
          retryLabel={t("common:actions.retry")}
        />
      ) : !rep ? (
        <Card className="py-12 text-center text-slate-500">
          {t("admin:reports.noData")}
        </Card>
      ) : (
        <>
          {/* Executive KPI Cards */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <Card>
              <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                {t("admin:reports.netSales")}
              </div>
              <div className="mt-1 text-2xl font-bold text-slate-900">
                {fmt(rep.totals.net)}
              </div>
              <div className="mt-1 flex items-center gap-2 text-xs text-slate-500">
                <span>{t("admin:reports.gross")}: {fmt(rep.totals.gross)}</span>
                {rep.totals.discount > 0 && (
                  <span className="text-amber-700">
                    -{fmt(rep.totals.discount)}
                  </span>
                )}
              </div>
            </Card>

            <Card>
              <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                {t("admin:reports.grossProfit")}
              </div>
              <div className="mt-1 text-2xl font-bold text-emerald-600">
                {fmt(rep.totals.profit)}
              </div>
              <div className="mt-1 text-xs text-slate-500">
                {t("admin:reports.margin")}: <span className="font-semibold text-slate-700">{rep.totals.margin_percent}%</span> · {t("admin:reports.cogs")}: {fmt(rep.totals.cogs)}
              </div>
            </Card>

            <Card>
              <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                {t("admin:reports.transactions")}
              </div>
              <div className="mt-1 text-2xl font-bold text-slate-900">
                {rep.totals.txns}
              </div>
              <div className="mt-1 text-xs text-slate-500">
                {t("admin:reports.avgBasket")}: <span className="font-semibold text-slate-700">{fmt(avgTxnValue)}</span>
              </div>
            </Card>

            <Card>
              <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                {t("admin:reports.stockValuation")}
              </div>
              <div className="mt-1 text-2xl font-bold text-slate-900">
                {fmt(rep.stock_valuation.total_value)}
              </div>
              <div className="mt-1 text-xs text-slate-500">
                {rep.stock_valuation.total_units} {t("admin:reports.unitsOnHand")} ({rep.stock_valuation.items_count} {t("admin:reports.skus")})
              </div>
            </Card>
          </div>

          {/* Multi-Store Comparison (When viewing all locations or multiple stores exist) */}
          {selectedLocationId === "all" && rep.stores.length > 1 && (
            <Card className="grid gap-3">
              <h2 className="text-base font-bold text-slate-900">
                {t("admin:reports.storeComparisonTitle")}
              </h2>
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm text-slate-600">
                  <thead className="border-b border-slate-200 bg-slate-50 text-xs font-semibold uppercase text-slate-500">
                    <tr>
                      <th className="px-3 py-2">{t("admin:reports.store")}</th>
                      <th className="px-3 py-2 text-right">{t("admin:reports.netSales")}</th>
                      <th className="px-3 py-2 text-right">{t("admin:reports.grossProfit")}</th>
                      <th className="px-3 py-2 text-right">{t("admin:reports.transactions")}</th>
                      <th className="px-3 py-2 text-right">{t("admin:reports.currentStockValue")}</th>
                      <th className="px-3 py-2 text-right">{t("admin:reports.stockUnits")}</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {rep.stores.map((s) => (
                      <tr key={s.location_id} className="hover:bg-slate-50/50">
                        <td className="px-3 py-2.5">
                          <div className="font-semibold text-slate-900">
                            {s.type === "warehouse" ? "🏢" : "🏪"} {s.name}
                          </div>
                          <div className="text-xs text-slate-400">
                            {s.code} · <Badge tone={s.type === "warehouse" ? "neutral" : "good"}>{s.type}</Badge>
                          </div>
                        </td>
                        <td className="px-3 py-2.5 text-right font-medium text-slate-900">
                          {fmt(s.net)}
                        </td>
                        <td className="px-3 py-2.5 text-right font-semibold text-emerald-600">
                          {fmt(s.profit)}
                        </td>
                        <td className="px-3 py-2.5 text-right text-slate-700">
                          {s.txns}
                        </td>
                        <td className="px-3 py-2.5 text-right font-medium text-slate-900">
                          {fmt(s.stock_value)}
                        </td>
                        <td className="px-3 py-2.5 text-right text-slate-600">
                          {s.stock_units}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Card>
          )}

          {/* Daily Trend & Visual Bar Chart */}
          <Card className="grid gap-4">
            <h2 className="text-base font-bold text-slate-900">
              {t("admin:reports.dailyTrendTitle")}
            </h2>

            {/* Visual Bars */}
            <div className="flex h-36 items-end gap-1.5 border-b border-slate-200 pb-2">
              {rep.days.length === 0 ? (
                <div className="m-auto text-xs text-slate-400">{t("admin:reports.noSalesInRange")}</div>
              ) : (
                rep.days.map((d) => {
                  const pct = Math.max(Math.round((d.net / maxDayNet) * 100), 2);
                  const shortDate = d.day.slice(5); // MM-DD
                  return (
                    <div
                      key={d.day}
                      className="group relative flex flex-1 flex-col items-center justify-end h-full"
                    >
                      {/* Tooltip */}
                      <div className="pointer-events-none absolute -top-8 hidden whitespace-nowrap rounded bg-slate-900 px-2 py-0.5 text-xs text-white shadow-md group-hover:block z-10">
                        {d.day}: {fmt(d.net)} ({d.txns} txns)
                      </div>
                      <div
                        style={{ height: `${pct}%` }}
                        className="w-full max-w-[36px] rounded-t bg-slate-800 transition hover:bg-slate-600"
                      />
                      <span className="mt-1 text-[10px] text-slate-400">{shortDate}</span>
                    </div>
                  );
                })
              )}
            </div>

            {/* Daily Breakdown Table */}
            <div className="max-h-64 overflow-y-auto">
              <table className="w-full text-left text-xs text-slate-600">
                <thead className="border-b border-slate-200 bg-slate-50 font-semibold uppercase text-slate-500">
                  <tr>
                    <th className="px-3 py-2">{t("admin:reports.date")}</th>
                    <th className="px-3 py-2 text-right">{t("admin:reports.netSales")}</th>
                    <th className="px-3 py-2 text-right">{t("admin:reports.grossProfit")}</th>
                    <th className="px-3 py-2 text-right">{t("admin:reports.transactions")}</th>
                    <th className="px-3 py-2 text-right">{t("admin:reports.cash")}</th>
                    <th className="px-3 py-2 text-right">{t("admin:reports.ewallet")}</th>
                    <th className="px-3 py-2 text-right">{t("admin:reports.utangCredit")}</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {rep.days.map((d) => (
                    <tr key={d.day} className="hover:bg-slate-50/50">
                      <td className="px-3 py-2 font-medium text-slate-800">{d.day}</td>
                      <td className="px-3 py-2 text-right font-semibold text-slate-900">{fmt(d.net)}</td>
                      <td className="px-3 py-2 text-right text-emerald-600 font-medium">{fmt(d.profit)}</td>
                      <td className="px-3 py-2 text-right">{d.txns}</td>
                      <td className="px-3 py-2 text-right text-slate-500">{fmt(d.cash)}</td>
                      <td className="px-3 py-2 text-right text-slate-500">{fmt(d.ewallet)}</td>
                      <td className="px-3 py-2 text-right text-slate-500">{fmt(d.utang)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>

          {/* Lower Grid: Top Products & Tenders/Transfers */}
          <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
            {/* Top Selling Products */}
            <Card className="grid gap-3">
              <h2 className="text-base font-bold text-slate-900">
                {t("admin:reports.topProductsTitle")}
              </h2>
              {rep.top_items.length === 0 ? (
                <div className="py-6 text-center text-xs text-slate-400">
                  {t("admin:reports.noProductsSold")}
                </div>
              ) : (
                <div className="max-h-72 overflow-y-auto">
                  <table className="w-full text-left text-xs text-slate-600">
                    <thead className="border-b border-slate-200 bg-slate-50 font-semibold uppercase text-slate-500">
                      <tr>
                        <th className="px-3 py-2">{t("admin:reports.product")}</th>
                        <th className="px-3 py-2 text-right">{t("admin:reports.unitsSold")}</th>
                        <th className="px-3 py-2 text-right">{t("admin:reports.revenue")}</th>
                        <th className="px-3 py-2 text-right">{t("admin:reports.profit")}</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {rep.top_items.map((item) => (
                        <tr key={item.variant_id} className="hover:bg-slate-50/50">
                          <td className="px-3 py-2">
                            <div className="font-semibold text-slate-800">{item.name}</div>
                            {item.sku && <div className="text-[10px] text-slate-400">{item.sku}</div>}
                          </td>
                          <td className="px-3 py-2 text-right font-medium">{item.qty}</td>
                          <td className="px-3 py-2 text-right font-semibold text-slate-900">
                            {fmt(item.revenue)}
                          </td>
                          <td className="px-3 py-2 text-right font-medium text-emerald-600">
                            {fmt(item.profit)}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </Card>

            {/* Tenders, Utang & Transfers Overview */}
            <div className="grid gap-6">
              {/* Payment Methods */}
              <Card className="grid gap-3">
                <h2 className="text-base font-bold text-slate-900">
                  {t("admin:reports.tendersTitle")}
                </h2>
                <div className="grid gap-2 text-xs">
                  <div className="flex items-center justify-between">
                    <span className="font-medium text-slate-700">💵 {t("admin:reports.cash")}</span>
                    <span className="font-semibold text-slate-900">{fmt(rep.totals.cash)}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="font-medium text-slate-700">📱 {t("admin:reports.ewallet")}</span>
                    <span className="font-semibold text-slate-900">{fmt(rep.totals.ewallet)}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="font-medium text-slate-700">📒 {t("admin:reports.utangCredit")}</span>
                    <span className="font-semibold text-slate-900">{fmt(rep.totals.utang)}</span>
                  </div>
                </div>

                {rep.utang.owed > 0 && (
                  <div className="mt-2 rounded-md bg-amber-50 p-2.5 text-xs text-amber-900">
                    <span className="font-bold">{t("admin:reports.totalCustomerDebt")}:</span>{" "}
                    {fmt(rep.utang.owed)} ({rep.utang.customers.length} {t("admin:reports.debtors")})
                  </div>
                )}
              </Card>

              {/* Warehouse & Transfers Activity */}
              <Card className="grid gap-3">
                <h2 className="text-base font-bold text-slate-900">
                  {t("admin:reports.transfersTitle")}
                </h2>
                <div className="grid grid-cols-2 gap-3 text-xs">
                  <div className="rounded-md border border-slate-100 bg-slate-50 p-2.5">
                    <div className="text-slate-500">{t("admin:reports.totalTransfers")}</div>
                    <div className="text-lg font-bold text-slate-900">{rep.transfers.total_transfers}</div>
                  </div>
                  <div className="rounded-md border border-slate-100 bg-slate-50 p-2.5">
                    <div className="text-slate-500">{t("admin:reports.transfersShipped")}</div>
                    <div className="text-lg font-bold text-amber-600">{rep.transfers.shipped_count}</div>
                  </div>
                  <div className="rounded-md border border-slate-100 bg-slate-50 p-2.5">
                    <div className="text-slate-500">{t("admin:reports.transfersReceived")}</div>
                    <div className="text-lg font-bold text-emerald-600">{rep.transfers.received_count}</div>
                  </div>
                  <div className="rounded-md border border-slate-100 bg-slate-50 p-2.5">
                    <div className="text-slate-500">{t("admin:reports.transfersDiscrepant")}</div>
                    <div className="text-lg font-bold text-red-600">{rep.transfers.discrepancy_count}</div>
                  </div>
                </div>
              </Card>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
