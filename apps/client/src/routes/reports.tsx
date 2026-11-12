import { useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Download } from "lucide-react";
import {
  Alert,
  Badge,
  Button,
  Card,
  EmptyState,
  ErrorState,
  Input,
  PageHeader,
  Select,
  Skeleton,
  StatCard,
  Table,
  TableSkeleton,
  Td,
  Th,
  useToast,
} from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { listLocations } from "../lib/api.ts";
import {
  exportDailySalesCsv,
  exportStoresComparisonCsv,
  exportTopProductsCsv,
  fetchMultiStoreReport,
  filterAccessibleReportLocations,
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

  const locationsQuery = useQuery({
    queryKey: ["locations"],
    queryFn: listLocations,
    staleTime: 60_000,
  });

  const availableLocations = useMemo(
    () => filterAccessibleReportLocations(locationsQuery.data ?? [], access),
    [locationsQuery.data, access],
  );

  const selectedLocation = useMemo(
    () => (selectedLocationId === "all" ? null : (availableLocations.find((l) => l.id === selectedLocationId) ?? null)),
    [availableLocations, selectedLocationId],
  );
  const selectedLocationLabel = selectedLocation ? `${selectedLocation.code} · ${selectedLocation.name}` : undefined;

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

  const maxDayNet = useMemo(() => {
    if (!rep || rep.days.length === 0) return 1;
    return Math.max(...rep.days.map((d) => d.net), 1);
  }, [rep]);

  const peakDay = useMemo(() => {
    if (!rep || rep.days.length === 0) return null;
    return rep.days.reduce((best, cur) => (cur.net > best.net ? cur : best), rep.days[0]!);
  }, [rep]);

  const dailyAvgNet = useMemo(() => {
    if (!rep || rep.days.length === 0) return 0;
    return Math.round(rep.totals.net / rep.days.length);
  }, [rep]);

  const avgTxnValue = useMemo(() => {
    if (!rep || rep.totals.txns === 0) return 0;
    return Math.round(rep.totals.net / rep.totals.txns);
  }, [rep]);

  const tenderRows = useMemo(() => {
    if (!rep) return [];
    const card = rep.totals.card ?? 0;
    const sum = Math.max(rep.totals.cash + rep.totals.ewallet + card + rep.totals.utang, 1);
    return [
      { key: "cash", label: t("admin:reports.cash"), amount: rep.totals.cash, pct: Math.round((rep.totals.cash / sum) * 100), barClass: "bg-emerald-600" },
      { key: "ewallet", label: t("admin:reports.ewallet"), amount: rep.totals.ewallet, pct: Math.round((rep.totals.ewallet / sum) * 100), barClass: "bg-brand-600" },
      { key: "card", label: t("admin:reports.card"), amount: card, pct: Math.round((card / sum) * 100), barClass: "bg-slate-700" },
      { key: "utang", label: t("admin:reports.utangCredit"), amount: rep.totals.utang, pct: Math.round((rep.totals.utang / sum) * 100), barClass: "bg-amber-500" },
    ];
  }, [rep, t]);

  const canSnapshot = can("stock.adjust_warehouse") || access.role === "superadmin";

  return (
    <div className="grid gap-6">
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
                {snapshotMutation.isPending ? t("admin:reports.snapshotting") : t("admin:reports.snapshotNow")}
              </Button>
            )}

            {rep && (
              <div className="flex flex-wrap items-center gap-2">
                <Button variant="outline" size="sm" onClick={() => exportDailySalesCsv(rep, access.tenant.name, selectedLocationLabel)}>
                  <Download size={14} className="text-slate-500" aria-hidden />
                  <span>{t("admin:reports.exportDaily")}</span>
                </Button>
                <Button variant="outline" size="sm" onClick={() => exportTopProductsCsv(rep, access.tenant.name, selectedLocationLabel)}>
                  <Download size={14} className="text-slate-500" aria-hidden />
                  <span>{t("admin:reports.exportProducts")}</span>
                </Button>
                {rep.stores.length > 1 && (
                  <Button variant="outline" size="sm" onClick={() => exportStoresComparisonCsv(rep, access.tenant.name)}>
                    <Download size={14} className="text-slate-500" aria-hidden />
                    <span>{t("admin:reports.exportStores")}</span>
                  </Button>
                )}
              </div>
            )}
          </div>
        }
      />

      {/* Filter Bar */}
      <Card className="flex flex-wrap items-end justify-between gap-4">
        <div className="grid gap-1">
          <span className="text-xs font-semibold tracking-wider text-slate-600 uppercase">
            {t("admin:reports.location")}
          </span>
          <Select
            data-testid="reports-location-filter"
            aria-label={t("admin:reports.location")}
            value={selectedLocationId}
            onChange={(e) => setSelectedLocationId(e.target.value)}
            className="w-56"
          >
            <option value="all">{t("admin:reports.allLocations")}</option>
            {availableLocations.map((loc) => (
              <option key={loc.id} value={loc.id}>
                {loc.code} · {loc.name}
              </option>
            ))}
          </Select>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <div className="inline-flex rounded-md border border-slate-200 bg-slate-100 p-1 text-xs">
            {(
              [
                ["today", t("admin:reports.today")],
                ["7d", t("admin:reports.last7Days")],
                ["mtd", t("admin:reports.monthToDate")],
                ["30d", t("admin:reports.last30Days")],
              ] as const
            ).map(([key, label]) => (
              <button
                key={key}
                type="button"
                onClick={() => handlePresetChange(key)}
                className={`rounded-md px-3 py-1 transition-colors ${
                  datePreset === key
                    ? "bg-white font-semibold text-slate-900 shadow-xs"
                    : "font-normal text-slate-600 hover:text-slate-900"
                }`}
              >
                {label}
              </button>
            ))}
          </div>

          <div className="flex items-center gap-2 text-xs text-slate-600">
            <Input
              type="date"
              value={fromDate}
              max={toDate}
              onChange={(e) => {
                setDatePreset("custom");
                setFromDate(e.target.value);
              }}
              className="w-36 text-xs"
            />
            <span>→</span>
            <Input
              type="date"
              value={toDate}
              min={fromDate}
              max={todayStr}
              onChange={(e) => {
                setDatePreset("custom");
                setToDate(e.target.value);
              }}
              className="w-36 text-xs"
            />
          </div>
        </div>
      </Card>

      {reportQuery.isLoading ? (
        <div className="grid gap-6">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {Array.from({ length: 4 }).map((_, i) => (
              <Card key={i} className="grid gap-2">
                <Skeleton className="h-4 w-24" />
                <Skeleton className="h-8 w-32" />
                <Skeleton className="h-3 w-40" />
              </Card>
            ))}
          </div>
          <Card>
            <TableSkeleton rows={5} cols={6} />
          </Card>
        </div>
      ) : reportQuery.isError ? (
        <ErrorState
          message={t("admin:reports.noData")}
          onRetry={() => void reportQuery.refetch()}
          retryLabel={t("common:actions.retry")}
        />
      ) : !rep ? (
        <EmptyState title={t("admin:reports.noData")} />
      ) : (
        <>
          {/* Executive KPI Cards */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <StatCard
              label={t("admin:reports.netSales")}
              value={<span className="tabular-nums">{fmt(rep.totals.net)}</span>}
              subtext={
                rep.totals.discount > 0
                  ? `${t("admin:reports.gross")} ${fmt(rep.totals.gross)} (−${fmt(rep.totals.discount)})`
                  : `${t("admin:reports.gross")} ${fmt(rep.totals.gross)}`
              }
            />
            <StatCard
              label={t("admin:reports.grossProfit")}
              value={<span className="text-emerald-700 tabular-nums">{fmt(rep.totals.profit)}</span>}
              subtext={`${rep.totals.margin_percent}% ${t("admin:reports.margin").toLowerCase()} · ${t("admin:reports.cogs")} ${fmt(rep.totals.cogs)}`}
            />
            <StatCard
              label={t("admin:reports.transactions")}
              value={<span className="tabular-nums">{rep.totals.txns}</span>}
              subtext={`${t("admin:reports.avgBasket")} ${fmt(avgTxnValue)}`}
            />
            <StatCard
              label={t("admin:reports.stockValuation")}
              value={<span className="tabular-nums">{fmt(rep.stock_valuation.total_value)}</span>}
              subtext={`${rep.stock_valuation.total_units} ${t("admin:reports.unitsOnHand")} (${rep.stock_valuation.items_count} ${t("admin:reports.skus")})`}
            />
          </div>

          {/* Multi-Store Comparison */}
          {selectedLocationId === "all" && rep.stores.length > 1 && (
            <Card className="grid gap-4">
              <h2 className="text-base font-semibold text-slate-900">{t("admin:reports.storeComparisonTitle")}</h2>
              <div className="overflow-x-auto">
                <Table bare>
                  <thead>
                    <tr>
                      <Th>{t("admin:reports.store")}</Th>
                      <Th numeric>{t("admin:reports.netSales")}</Th>
                      <Th numeric>{t("admin:reports.grossProfit")}</Th>
                      <Th numeric>{t("admin:reports.transactions")}</Th>
                      <Th numeric>{t("admin:reports.currentStockValue")}</Th>
                      <Th numeric>{t("admin:reports.stockUnits")}</Th>
                    </tr>
                  </thead>
                  <tbody>
                    {rep.stores.map((s) => (
                      <tr
                        key={s.location_id}
                        onClick={() => setSelectedLocationId(s.location_id)}
                        className="cursor-pointer transition-colors hover:bg-slate-50"
                      >
                        <Td>
                          <div className="font-semibold text-slate-900">{s.name}</div>
                          <div className="mt-0.5 flex items-center gap-2 text-xs text-slate-600">
                            <span>{s.code}</span>
                            <Badge tone={s.type === "warehouse" ? "neutral" : "good"}>{s.type}</Badge>
                          </div>
                        </Td>
                        <Td numeric className="font-semibold">{fmt(s.net)}</Td>
                        <Td numeric className="font-semibold text-emerald-700">{fmt(s.profit)}</Td>
                        <Td numeric>{s.txns}</Td>
                        <Td numeric>{fmt(s.stock_value)}</Td>
                        <Td numeric className="text-slate-600">{s.stock_units}</Td>
                      </tr>
                    ))}
                  </tbody>
                </Table>
              </div>
            </Card>
          )}

          {/* Daily Trend & Token-Styled Bar Chart */}
          <Card className="grid gap-6" data-testid="daily-trend-card">
            <div className="flex flex-wrap items-baseline justify-between gap-3">
              <h2 className="text-base font-semibold text-slate-900">{t("admin:reports.dailyTrendTitle")}</h2>
              {peakDay && (
                <div className="flex flex-wrap items-center gap-3 text-xs text-slate-600 tabular-nums">
                  <span>
                    {t("admin:reports.dailyAvg")} <strong className="font-semibold text-slate-900">{fmt(dailyAvgNet)}</strong>
                  </span>
                  <span>
                    {t("admin:reports.dailyPeak")} ({peakDay.day.slice(5)}){" "}
                    <strong className="font-semibold text-brand-700">{fmt(peakDay.net)}</strong>
                  </span>
                </div>
              )}
            </div>

            {/* Visual Bars */}
            {rep.days.length === 0 ? (
              <EmptyState title={t("admin:reports.noSalesInRange")} />
            ) : (
              <div className="relative rounded-md border border-slate-200 bg-slate-50 p-4" data-testid="daily-trend-bars">
                <div className="flex h-40 items-end gap-2 border-b border-slate-200 pb-2">
                  {rep.days.map((d) => {
                    const pct = d.net > 0 ? Math.max(Math.round((d.net / maxDayNet) * 100), 6) : 2;
                    const isPeak = peakDay?.day === d.day && d.net > 0;
                    return (
                      <div
                        key={d.day}
                        data-testid={`daily-trend-bar-${d.day}`}
                        className="group relative flex h-full flex-1 flex-col items-center justify-end"
                      >
                        <div className="pointer-events-none absolute -top-9 z-10 hidden whitespace-nowrap rounded-md border border-slate-200 bg-white px-2.5 py-1 text-xs text-slate-900 shadow-md group-hover:block tabular-nums">
                          <span className="font-semibold">{d.day}</span> · {fmt(d.net)} ({d.txns})
                        </div>
                        <div
                          style={{ height: `${pct}%` }}
                          className={`w-full max-w-10 rounded-t-md transition-colors ${
                            d.net === 0
                              ? "bg-slate-200"
                              : isPeak
                                ? "bg-brand-600 hover:bg-brand-700"
                                : "bg-brand-400 hover:bg-brand-600"
                          }`}
                        />
                      </div>
                    );
                  })}
                </div>
                <div className="mt-2 flex items-center gap-2">
                  {rep.days.map((d) => (
                    <div key={d.day} className="flex-1 text-center font-mono text-xs text-slate-600 truncate">
                      {d.day.slice(5)}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Daily Breakdown Table */}
            {rep.days.length > 0 && (
              <div className="max-h-72 overflow-y-auto">
                <Table bare>
                  <thead>
                    <tr>
                      <Th>{t("admin:reports.date")}</Th>
                      <Th numeric>{t("admin:reports.netSales")}</Th>
                      <Th numeric>{t("admin:reports.grossProfit")}</Th>
                      <Th numeric>{t("admin:reports.transactions")}</Th>
                      <Th numeric>{t("admin:reports.cash")}</Th>
                      <Th numeric>{t("admin:reports.ewallet")}</Th>
                      <Th numeric>{t("admin:reports.card")}</Th>
                      <Th numeric>{t("admin:reports.utangCredit")}</Th>
                    </tr>
                  </thead>
                  <tbody>
                    {rep.days.map((d) => (
                      <tr key={d.day}>
                        <Td className="font-semibold">{d.day}</Td>
                        <Td numeric className="font-semibold">{fmt(d.net)}</Td>
                        <Td numeric className="text-emerald-700">{fmt(d.profit)}</Td>
                        <Td numeric>{d.txns}</Td>
                        <Td numeric className="text-slate-600">{fmt(d.cash)}</Td>
                        <Td numeric className="text-slate-600">{fmt(d.ewallet)}</Td>
                        <Td numeric className="text-slate-600">{fmt(d.card ?? 0)}</Td>
                        <Td numeric className="text-slate-600">{fmt(d.utang)}</Td>
                      </tr>
                    ))}
                  </tbody>
                </Table>
              </div>
            )}
          </Card>

          {/* Lower Grid: Top Products & Tenders/Transfers */}
          <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
            <Card className="grid content-start gap-4">
              <h2 className="text-base font-semibold text-slate-900">{t("admin:reports.topProductsTitle")}</h2>
              {rep.top_items.length === 0 ? (
                <EmptyState title={t("admin:reports.noProductsSold")} />
              ) : (
                <div className="max-h-80 overflow-y-auto">
                  <Table bare>
                    <thead>
                      <tr>
                        <Th>{t("admin:reports.product")}</Th>
                        <Th numeric>{t("admin:reports.unitsSold")}</Th>
                        <Th numeric>{t("admin:reports.revenue")}</Th>
                        <Th numeric>{t("admin:reports.profit")}</Th>
                      </tr>
                    </thead>
                    <tbody>
                      {rep.top_items.map((item) => (
                        <tr key={item.variant_id}>
                          <Td>
                            <div className="font-semibold text-slate-900">{item.name}</div>
                            {item.sku && <div className="font-mono text-xs text-slate-600">{item.sku}</div>}
                          </Td>
                          <Td numeric>{item.qty}</Td>
                          <Td numeric className="font-semibold">{fmt(item.revenue)}</Td>
                          <Td numeric className="text-emerald-700">{fmt(item.profit)}</Td>
                        </tr>
                      ))}
                    </tbody>
                  </Table>
                </div>
              )}
            </Card>

            <div className="grid content-start gap-6">
              {/* Payment Methods with Share Bars */}
              <Card className="grid gap-4" data-testid="tenders-breakdown-card">
                <h2 className="text-base font-semibold text-slate-900">{t("admin:reports.tendersTitle")}</h2>
                <div className="grid gap-3">
                  {tenderRows.map((row) => (
                    <div key={row.key} className="grid gap-1 text-sm">
                      <div className="flex items-baseline justify-between gap-2">
                        <span className="text-slate-700">{row.label}</span>
                        <span className="flex items-baseline gap-2 tabular-nums">
                          <span className="text-xs text-slate-600">{row.pct}%</span>
                          <span className="font-semibold text-slate-900">{fmt(row.amount)}</span>
                        </span>
                      </div>
                      <div className="h-2 w-full overflow-hidden rounded-md bg-slate-100">
                        <div
                          style={{ width: `${row.amount > 0 ? Math.max(row.pct, 3) : 0}%` }}
                          className={`h-full rounded-md ${row.barClass}`}
                        />
                      </div>
                    </div>
                  ))}
                </div>

                {rep.utang.owed > 0 && (
                  <Alert tone="warn">
                    <span className="font-semibold">{t("admin:reports.totalCustomerDebt")}</span>{" "}
                    <span className="tabular-nums">
                      {fmt(rep.utang.owed)} ({rep.utang.customers.length} {t("admin:reports.debtors")})
                    </span>
                  </Alert>
                )}
              </Card>

              {/* Warehouse & Transfers Activity */}
              <Card className="grid gap-4">
                <h2 className="text-base font-semibold text-slate-900">{t("admin:reports.transfersTitle")}</h2>
                <div className="grid grid-cols-2 gap-3">
                  <div className="rounded-md border border-slate-200 bg-slate-50 p-3">
                    <div className="text-xs font-semibold tracking-wider text-slate-600 uppercase">
                      {t("admin:reports.totalTransfers")}
                    </div>
                    <div className="mt-1 text-xl font-semibold text-slate-900 tabular-nums">
                      {rep.transfers.total_transfers}
                    </div>
                  </div>
                  <div className="rounded-md border border-slate-200 bg-slate-50 p-3">
                    <div className="text-xs font-semibold tracking-wider text-slate-600 uppercase">
                      {t("admin:reports.transfersShipped")}
                    </div>
                    <div className="mt-1 text-xl font-semibold text-amber-700 tabular-nums">
                      {rep.transfers.shipped_count}
                    </div>
                  </div>
                  <div className="rounded-md border border-slate-200 bg-slate-50 p-3">
                    <div className="text-xs font-semibold tracking-wider text-slate-600 uppercase">
                      {t("admin:reports.transfersReceived")}
                    </div>
                    <div className="mt-1 text-xl font-semibold text-emerald-700 tabular-nums">
                      {rep.transfers.received_count}
                    </div>
                  </div>
                  <div className="rounded-md border border-slate-200 bg-slate-50 p-3">
                    <div className="text-xs font-semibold tracking-wider text-slate-600 uppercase">
                      {t("admin:reports.transfersDiscrepant")}
                    </div>
                    <div className="mt-1 text-xl font-semibold text-red-700 tabular-nums">
                      {rep.transfers.discrepancy_count}
                    </div>
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
