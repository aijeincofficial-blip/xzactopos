import { useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Alert, Badge, Button, Card, Dialog, EmptyState, ErrorState, Field, Input, PageHeader, Select, useToast } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { parseAmount } from "../lib/sale-math.ts";
import { dayInTimezone, getDaySummary } from "../lib/today.ts";
import { computeDifference, computeExpectedCash } from "../lib/day-close-math.ts";
import { listUsers } from "../lib/api.ts";
import {
  closeDay,
  fetchDayCloses,
  fetchTodayCashUtang,
  type DayCloseRow,
} from "../lib/day-close-api.ts";

export function DayClosePage() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const toast = useToast();
  const { access, can } = useSession();
  const qc = useQueryClient();
  const currency = access.tenant.base_currency;
  const timezone = access.tenant.timezone;
  const today = dayInTimezone(timezone);
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);
  const { activeStore } = useActiveLocation();
  const store = (activeStore && can("shift.manage", activeStore.id)) ? activeStore : access.locations.find((l) => l.type === "store" && can("shift.manage", l.id));

  const [openingText, setOpeningText] = useState("");
  const [countedText, setCountedText] = useState("");
  const [note, setNote] = useState("");
  const [closeError, setCloseError] = useState<string | null>(null);
  const [successNote, setSuccessNote] = useState<string | null>(null);

  const [showXReport, setShowXReport] = useState(false);
  const [selectedZReport, setSelectedZReport] = useState<DayCloseRow | null>(null);
  const [historyFilter, setHistoryFilter] = useState<"all" | "discrepancies" | "balanced">("all");

  const daySummaryQuery = useQuery({
    queryKey: ["day-summary", today],
    queryFn: () => getDaySummary(today),
    refetchInterval: 60_000,
  });

  const cashUtangQuery = useQuery({
    queryKey: ["today-cash-utang", store?.id, today],
    queryFn: () => fetchTodayCashUtang(store?.id ?? "", today, timezone),
    enabled: Boolean(store),
    refetchInterval: 60_000,
  });

  const dayClosesQuery = useQuery({
    queryKey: ["day-closes", store?.id],
    queryFn: () => fetchDayCloses(store?.id ?? ""),
    enabled: Boolean(store),
  });

  const usersQuery = useQuery({
    queryKey: ["users"],
    queryFn: listUsers,
    staleTime: 60_000,
  });

  const userMap = useMemo(() => {
    const m = new Map<string, string>();
    for (const u of usersQuery.data ?? []) {
      m.set(u.user_id, u.full_name || u.username);
    }
    return m;
  }, [usersQuery.data]);

  const cashSales = daySummaryQuery.data?.totals.cash ?? 0;
  const cashExpenses = daySummaryQuery.data?.expenses.cash ?? 0;
  const cashUtang = cashUtangQuery.data ?? 0;

  const parsedOpening = openingText.trim() === "" ? 0 : parseAmount(openingText, currency);
  const parsedCounted = countedText.trim() === "" ? null : parseAmount(countedText, currency);

  const openingCash = parsedOpening ?? 0;
  const expectedCash = computeExpectedCash({
    openingCash,
    cashSales,
    cashUtangPayments: cashUtang,
    cashExpenses,
  });

  const diff = parsedCounted !== null ? computeDifference(parsedCounted, expectedCash) : null;

  const todayClose = (dayClosesQuery.data ?? []).find((c) => c.day === today) ?? null;

  const closeMut = useMutation({
    mutationFn: async () => {
      if (!store) throw new Error("No store");
      if (parsedOpening === null) throw new Error(t("dayClose.invalidOpening"));
      if (parsedCounted === null || parsedCounted < 0) throw new Error(t("dayClose.invalidCounted"));

      return closeDay({
        day: today,
        openingCash,
        expectedCash,
        countedCash: parsedCounted,
        locationId: store.id,
        note,
      });
    },
    onSuccess: async (r) => {
      setCountedText("");
      setNote("");
      setCloseError(null);
      const succ = t("dayClose.closedSuccess", { diff: fmt(r.difference) });
      setSuccessNote(succ);
      toast.good(succ);
      await Promise.all([
        qc.invalidateQueries({ queryKey: ["day-closes", store?.id] }),
        qc.invalidateQueries({ queryKey: ["day-summary"] }),
      ]);
    },
    onError: (e) => {
      setSuccessNote(null);
      const err = e instanceof Error ? e.message : msg(e);
      setCloseError(err);
      toast.error(err);
    },
  });

  const filteredCloses = useMemo(() => {
    return (dayClosesQuery.data ?? []).filter((dc) => {
      if (historyFilter === "discrepancies") return dc.difference !== 0;
      if (historyFilter === "balanced") return dc.difference === 0;
      return true;
    });
  }, [dayClosesQuery.data, historyFilter]);

  if (!store) {
    return (
      <EmptyState title={t("sell.noStore")} />
    );
  }

  return (
    <div className="grid max-w-4xl gap-4">
      <PageHeader
        title={t("dayClose.title")}
        subtitle={`${today} · ${store.name} (${store.code}) · ${timezone}`}
        actions={
          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" onClick={() => setShowXReport(true)}>
              {t("dayClose.xReportBtn")}
            </Button>
            {todayClose ? (
              <Badge tone="good">
                {t("dayClose.statusClosed", { time: todayClose.closed_at.slice(11, 16) })}
              </Badge>
            ) : (
              <Badge tone="warn">{t("dayClose.statusOpen")}</Badge>
            )}
          </div>
        }
      />

      {successNote ? <Alert tone="info">{successNote}</Alert> : null}

      <div className="grid gap-4 md:grid-cols-2">
        {/* Drawer cash breakdown */}
        <Card className="grid gap-3" data-testid="cash-breakdown-card">
          <h3 className="font-medium text-sm border-b border-slate-100 pb-2">
            {t("dayClose.drawerCalculation")}
          </h3>

          <div className="grid gap-2 text-sm">
            <div className="flex justify-between items-center">
              <span>{t("dayClose.openingCash")}:</span>
              <Input
                data-testid="opening-cash-input"
                className="w-28 text-right h-8"
                inputMode="decimal"
                placeholder={fmt(0)}
                value={openingText}
                onChange={(e) => setOpeningText(e.target.value)}
              />
            </div>
            <div className="flex justify-between text-slate-600">
              <span>+ {t("dayClose.cashSales")}:</span>
              <span>{fmt(cashSales)}</span>
            </div>
            <div className="flex justify-between text-slate-600">
              <span>+ {t("dayClose.cashUtangCollected")}:</span>
              <span>{fmt(cashUtang)}</span>
            </div>
            <div className="flex justify-between text-slate-600">
              <span>- {t("dayClose.cashExpenses")}:</span>
              <span>{fmt(cashExpenses)}</span>
            </div>
            <div className="flex justify-between font-semibold border-t border-slate-200 pt-2 text-base">
              <span>{t("dayClose.expectedInDrawer")}:</span>
              <span data-testid="expected-cash-total">{fmt(expectedCash)}</span>
            </div>
          </div>
        </Card>

        {/* Closing count entry */}
        <Card className="grid gap-3" data-testid="close-form-card">
          <h3 className="font-medium text-sm border-b border-slate-100 pb-2">
            {todayClose ? t("dayClose.recountTitle") : t("dayClose.countTitle")}
          </h3>

          <Field label={t("dayClose.countedCash")}>
            <Input
              data-testid="counted-cash-input"
              inputMode="decimal"
              placeholder={fmt(0)}
              value={countedText}
              onChange={(e) => setCountedText(e.target.value)}
            />
          </Field>

          {diff !== null ? (
            <div
              className={`p-2.5 rounded text-sm flex justify-between items-center ${
                diff === 0
                  ? "bg-slate-100 text-slate-800"
                  : diff > 0
                  ? "bg-emerald-50 text-emerald-800"
                  : "bg-red-50 text-red-800"
              }`}
              data-testid="difference-badge"
            >
              <span>{diff >= 0 ? t("dayClose.over") : t("dayClose.short")}:</span>
              <strong className="font-mono text-base">{fmt(Math.abs(diff))}</strong>
            </div>
          ) : null}

          <Field label={t("expenses.note")}>
            <Input
              data-testid="close-note-input"
              placeholder={t("expenses.notePlaceholder")}
              maxLength={200}
              value={note}
              onChange={(e) => setNote(e.target.value)}
            />
          </Field>

          {closeError ? <Alert>{closeError}</Alert> : null}

          <Button
            data-testid="close-day-btn"
            disabled={closeMut.isPending || countedText.trim() === ""}
            onClick={() => closeMut.mutate()}
          >
            {closeMut.isPending
              ? t("dayClose.submitting")
              : todayClose
              ? t("dayClose.recountSubmit")
              : t("dayClose.submitClose")}
          </Button>
        </Card>
      </div>

      {/* History of Day Closes */}
      <Card className="grid gap-3" data-testid="day-closes-history">
        <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-100 pb-2">
          <h3 className="font-medium text-sm">
            {t("dayClose.historyTitle")}
          </h3>
          <div className="w-40">
            <Select
              value={historyFilter}
              onChange={(e) => setHistoryFilter(e.target.value as "all" | "discrepancies" | "balanced")}
              className="text-xs py-1"
            >
              <option value="all">{t("dayClose.filterAll")}</option>
              <option value="discrepancies">{t("dayClose.filterDiscrepancies")}</option>
              <option value="balanced">{t("dayClose.filterBalanced")}</option>
            </Select>
          </div>
        </div>

        {dayClosesQuery.isPending ? <p className="text-sm text-slate-500">{t("today.loading")}</p> : null}
        {dayClosesQuery.isError ? (
          <ErrorState message={t("dayClose.historyTitle")} onRetry={() => void dayClosesQuery.refetch()} retryLabel={t("common:actions.retry")} />
        ) : null}
        {filteredCloses.length === 0 && !dayClosesQuery.isPending ? (
          <EmptyState title={t("dayClose.noHistory")} />
        ) : null}

        <ul className="grid gap-2">
          {filteredCloses.map((dc: DayCloseRow) => (
            <li
              key={dc.id}
              className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 pb-2 text-sm last:border-0 hover:bg-slate-50/40 px-1 rounded"
            >
              <div>
                <span className="font-medium block text-slate-900">{dc.day}</span>
                <span className="text-xs text-slate-500 block">
                  {t("dayClose.opening")}: {fmt(dc.opening_cash)} · {t("dayClose.expected")}: {fmt(dc.expected_cash)}
                  {dc.closed_by ? ` · ${t("dayClose.closedBy")}: ${userMap.get(dc.closed_by) ?? dc.closed_by.slice(0, 8)}` : ""}
                  {dc.note ? ` · "${dc.note}"` : ""}
                </span>
              </div>
              <div className="flex items-center gap-3 text-right">
                <div>
                  <span className="block font-semibold">{fmt(dc.counted_cash)}</span>
                  <span
                    className={`text-xs font-mono font-medium ${
                      dc.difference === 0
                        ? "text-slate-500"
                        : dc.difference > 0
                        ? "text-emerald-700"
                        : "text-red-700"
                    }`}
                  >
                    {dc.difference >= 0 ? `+${fmt(dc.difference)}` : fmt(dc.difference)}
                  </span>
                </div>
                <Button size="sm" variant="outline" onClick={() => setSelectedZReport(dc)}>
                  {t("dayClose.zReportBtn")}
                </Button>
              </div>
            </li>
          ))}
        </ul>
      </Card>

      {/* X-Report Dialog */}
      {showXReport ? (
        <XReportDialog
          store={store}
          today={today}
          fmt={fmt}
          openingCash={openingCash}
          cashSales={cashSales}
          cashUtang={cashUtang}
          cashExpenses={cashExpenses}
          expectedCash={expectedCash}
          totals={daySummaryQuery.data?.totals ?? null}
          onClose={() => setShowXReport(false)}
        />
      ) : null}

      {/* Z-Report Dialog */}
      {selectedZReport ? (
        <ZReportDialog
          report={selectedZReport}
          store={store}
          userMap={userMap}
          fmt={fmt}
          onClose={() => setSelectedZReport(null)}
        />
      ) : null}
    </div>
  );
}

function XReportDialog({
  store,
  today,
  fmt,
  openingCash,
  cashSales,
  cashUtang,
  cashExpenses,
  expectedCash,
  totals,
  onClose,
}: {
  store: { code: string; name: string };
  today: string;
  fmt: (n: number) => string;
  openingCash: number;
  cashSales: number;
  cashUtang: number;
  cashExpenses: number;
  expectedCash: number;
  totals: { gross: number; net: number; txns: number; ewallet: number; card?: number; utang: number } | null;
  onClose: () => void;
}) {
  const { t } = useTranslation(["admin", "common"]);
  const { access } = useSession();

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={t("dayClose.xReportTitle")} closeLabel={t("common:actions.close")}>
      <div className="grid gap-4 text-sm">
        <div className="border-b border-dashed border-slate-300 pb-3 text-center">
          <h3 className="font-bold text-base text-slate-900">{access.tenant.name}</h3>
          <p className="text-xs text-slate-600">
            {store.name} ({store.code})
          </p>
          <div className="mt-2 inline-block rounded bg-amber-50 px-2.5 py-0.5 text-xs font-semibold text-amber-800">
            {t("dayClose.interimReading")}
          </div>
          <p className="text-xs text-slate-400 mt-1">
            {today} · {new Date().toLocaleTimeString()}
          </p>
          <p className="text-xs text-slate-500">
            {t("dayClose.closedBy")}: {access.full_name || access.username}
          </p>
        </div>

        {/* Drawer cash summary */}
        <div className="grid gap-1.5 border-b border-dashed border-slate-300 pb-3">
          <div className="flex justify-between">
            <span className="text-slate-600">{t("dayClose.openingCash")}:</span>
            <span className="font-mono">{fmt(openingCash)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-slate-600">+ {t("dayClose.cashSales")}:</span>
            <span className="font-mono">{fmt(cashSales)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-slate-600">+ {t("dayClose.cashUtangCollected")}:</span>
            <span className="font-mono">{fmt(cashUtang)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-slate-600">- {t("dayClose.cashExpenses")}:</span>
            <span className="font-mono">{fmt(cashExpenses)}</span>
          </div>
          <div className="flex justify-between font-bold text-slate-900 border-t border-slate-200 pt-1.5 text-base">
            <span>{t("dayClose.cashInDrawer")}:</span>
            <span className="font-mono">{fmt(expectedCash)}</span>
          </div>
        </div>

        {/* Sales totals & tenders */}
        {totals ? (
          <div className="grid gap-1.5 border-b border-dashed border-slate-300 pb-3 text-xs text-slate-600">
            <div className="flex justify-between">
              <span>{t("dayClose.txnCount")}:</span>
              <span className="font-mono font-medium text-slate-900">{totals.txns}</span>
            </div>
            <div className="flex justify-between">
              <span>{t("dayClose.grossSales")}:</span>
              <span className="font-mono font-medium text-slate-900">{fmt(totals.gross)}</span>
            </div>
            <div className="flex justify-between">
              <span>{t("dayClose.ewalletSales")}:</span>
              <span className="font-mono font-medium text-slate-900">{fmt(totals.ewallet)}</span>
            </div>
            {totals.card !== undefined ? (
              <div className="flex justify-between">
                <span>{t("dayClose.cardSales")}:</span>
                <span className="font-mono font-medium text-slate-900">{fmt(totals.card)}</span>
              </div>
            ) : null}
            <div className="flex justify-between">
              <span>{t("dayClose.utangSales")}:</span>
              <span className="font-mono font-medium text-slate-900">{fmt(totals.utang)}</span>
            </div>
          </div>
        ) : null}

        <p className="text-center text-xs text-slate-400 italic">
          {t("dayClose.xReportNotice")}
        </p>

        <div className="flex justify-end gap-2 pt-2">
          <Button variant="outline" onClick={() => window.print()}>
            {t("dayClose.print")}
          </Button>
          <Button onClick={onClose}>{t("common:actions.close")}</Button>
        </div>
      </div>
    </Dialog>
  );
}

function ZReportDialog({
  report,
  store,
  userMap,
  fmt,
  onClose,
}: {
  report: DayCloseRow;
  store: { code: string; name: string };
  userMap: Map<string, string>;
  fmt: (n: number) => string;
  onClose: () => void;
}) {
  const { t } = useTranslation(["admin", "common"]);
  const { access } = useSession();

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={t("dayClose.zReportTitle")} closeLabel={t("common:actions.close")}>
      <div className="grid gap-4 text-sm">
        <div className="border-b border-dashed border-slate-300 pb-3 text-center">
          <h3 className="font-bold text-base text-slate-900">{access.tenant.name}</h3>
          <p className="text-xs text-slate-600">
            {store.name} ({store.code})
          </p>
          <div className="mt-2 inline-block rounded bg-emerald-50 px-2.5 py-0.5 text-xs font-semibold text-emerald-800">
            {t("dayClose.finalClose")}
          </div>
          <p className="text-xs text-slate-400 mt-1">
            {report.day} · {report.closed_at.slice(11, 19)}
          </p>
          {report.closed_by ? (
            <p className="text-xs text-slate-500">
              {t("dayClose.closedBy")}: {userMap.get(report.closed_by) ?? report.closed_by.slice(0, 8)}
            </p>
          ) : null}
          {report.approved_by ? (
            <p className="text-xs text-slate-500">
              {t("dayClose.approvedBy")}: {userMap.get(report.approved_by) ?? report.approved_by.slice(0, 8)}
            </p>
          ) : null}
        </div>

        {/* Reconciliation figures */}
        <div className="grid gap-2 border-b border-dashed border-slate-300 pb-3">
          <div className="flex justify-between text-slate-600">
            <span>{t("dayClose.openingCash")}:</span>
            <span className="font-mono">{fmt(report.opening_cash)}</span>
          </div>
          <div className="flex justify-between text-slate-600">
            <span>{t("dayClose.expectedInDrawer")}:</span>
            <span className="font-mono">{fmt(report.expected_cash)}</span>
          </div>
          <div className="flex justify-between font-bold text-slate-900 border-t border-slate-200 pt-1 text-base">
            <span>{t("dayClose.countedCash")}:</span>
            <span className="font-mono">{fmt(report.counted_cash)}</span>
          </div>
          <div
            className={`flex justify-between items-center rounded p-2 text-sm font-semibold ${
              report.difference === 0
                ? "bg-slate-100 text-slate-800"
                : report.difference > 0
                ? "bg-emerald-50 text-emerald-800"
                : "bg-red-50 text-red-800"
            }`}
          >
            <span>{report.difference >= 0 ? t("dayClose.over") : t("dayClose.short")}:</span>
            <span className="font-mono text-base">
              {report.difference >= 0 ? `+${fmt(report.difference)}` : fmt(report.difference)}
            </span>
          </div>
        </div>

        {report.note ? (
          <div className="rounded bg-slate-50 p-2 text-xs text-slate-600 border border-slate-200">
            <strong>{t("expenses.note")}:</strong> {report.note}
          </div>
        ) : null}

        <p className="text-center text-xs text-slate-400 italic">
          {t("dayClose.zReportNotice")}
        </p>

        <div className="flex justify-end gap-2 pt-2">
          <Button variant="outline" onClick={() => window.print()}>
            {t("dayClose.print")}
          </Button>
          <Button onClick={onClose}>{t("common:actions.close")}</Button>
        </div>
      </div>
    </Dialog>
  );
}
