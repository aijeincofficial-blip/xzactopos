import { useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import {
  Alert,
  Badge,
  Button,
  Card,
  Dialog,
  EmptyState,
  ErrorState,
  Field,
  Input,
  PageHeader,
  Select,
  TabPanel,
  Tabs,
  useToast,
} from "../components/ui.tsx";
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
import {
  closeCashierShift,
  fetchShiftExpectedNow,
  fetchStoreShifts,
  type ShiftRow,
} from "../lib/shifts-api.ts";
import {
  downloadCsv,
  exportDayClosesCsv,
  exportShiftsCsv,
} from "../lib/csv-helper.ts";

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
  const store = (activeStore && can("shift.manage", activeStore.id))
    ? activeStore
    : access.locations.find((l) => l.type === "store" && can("shift.manage", l.id));

  const [activeTab, setActiveTab] = useState<"day-closes" | "shifts">("day-closes");

  // Day close drawer inputs
  const [openingText, setOpeningText] = useState("");
  const [countedText, setCountedText] = useState("");
  const [note, setNote] = useState("");
  const [closeError, setCloseError] = useState<string | null>(null);
  const [successNote, setSuccessNote] = useState<string | null>(null);

  // Day close reports & filters
  const [showXReport, setShowXReport] = useState(false);
  const [selectedZReport, setSelectedZReport] = useState<DayCloseRow | null>(null);
  const [historyFilter, setHistoryFilter] = useState<"all" | "discrepancies" | "balanced">("all");

  // Shifts state & dialogs
  const [shiftsFilter, setShiftsFilter] = useState<"all" | "open" | "closed" | "discrepancies">("all");
  const [selectedShiftX, setSelectedShiftX] = useState<ShiftRow | null>(null);
  const [selectedShiftZ, setSelectedShiftZ] = useState<ShiftRow | null>(null);
  const [closingShift, setClosingShift] = useState<ShiftRow | null>(null);

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

  const storeShiftsQuery = useQuery({
    queryKey: ["store-shifts", store?.id],
    queryFn: () => fetchStoreShifts(store?.id ?? ""),
    enabled: Boolean(store),
    refetchInterval: 30_000,
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

  const filteredShifts = useMemo(() => {
    return (storeShiftsQuery.data ?? []).filter((s) => {
      if (shiftsFilter === "open") return s.closed_at === null;
      if (shiftsFilter === "closed") return s.closed_at !== null;
      if (shiftsFilter === "discrepancies") return s.closed_at !== null && s.difference !== 0;
      return true;
    });
  }, [storeShiftsQuery.data, shiftsFilter]);

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

      <Tabs
        value={activeTab}
        onValueChange={(v) => setActiveTab(v as "day-closes" | "shifts")}
        label={t("dayClose.title")}
        tabs={[
          { value: "day-closes", label: t("dayClose.tabDayClose"), testId: "tab-day-closes" },
          { value: "shifts", label: t("dayClose.tabShifts"), testId: "tab-shifts" },
        ]}
      >
        <TabPanel value="day-closes">
          <div className="grid gap-4">
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
                <div className="flex items-center gap-2">
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
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => {
                      const csv = exportDayClosesCsv(
                        (dayClosesQuery.data ?? []).map((dc) => ({
                          day: dc.day,
                          openingCash: dc.opening_cash,
                          expectedCash: dc.expected_cash,
                          countedCash: dc.counted_cash,
                          difference: dc.difference,
                          closedAt: dc.closed_at,
                          closedBy: dc.closed_by ? userMap.get(dc.closed_by) ?? dc.closed_by : null,
                          note: dc.note,
                        })),
                      );
                      downloadCsv(csv, `day-closes-${store.code}-${today}.csv`);
                    }}
                  >
                    {t("dayClose.exportCsv")}
                  </Button>
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
          </div>
        </TabPanel>

        <TabPanel value="shifts">
          {/* Cashier Shifts Tab */}
          <Card className="grid gap-3" data-testid="cashier-shifts-card">
            <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-100 pb-2">
              <div>
                <h3 className="font-medium text-sm">{t("dayClose.shiftsTitle")}</h3>
                <p className="text-xs text-slate-500">
                  {t("dayClose.cashier")}: {store.name} ({store.code})
                </p>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-44">
                  <Select
                    value={shiftsFilter}
                    onChange={(e) => setShiftsFilter(e.target.value as "all" | "open" | "closed" | "discrepancies")}
                    className="text-xs py-1"
                  >
                    <option value="all">{t("dayClose.filterAll")}</option>
                    <option value="open">{t("dayClose.filterOpen")}</option>
                    <option value="closed">{t("dayClose.filterClosed")}</option>
                    <option value="discrepancies">{t("dayClose.filterDiscrepancies")}</option>
                  </Select>
                </div>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => {
                    const csv = exportShiftsCsv(
                      (storeShiftsQuery.data ?? []).map((s) => ({
                        id: s.id,
                        cashier: userMap.get(s.cashier_id) ?? s.cashier_id.slice(0, 8),
                        status: s.closed_at ? "closed" : "open",
                        openedAt: s.opened_at,
                        closedAt: s.closed_at,
                        openingCash: s.opening_cash,
                        expectedCash: s.expected_cash,
                        countedCash: s.counted_cash,
                        difference: s.difference,
                        closedBy: s.closed_by ? userMap.get(s.closed_by) ?? s.closed_by : null,
                        note: s.note,
                      })),
                    );
                    downloadCsv(csv, `cashier-shifts-${store.code}-${today}.csv`);
                  }}
                >
                  {t("dayClose.exportCsv")}
                </Button>
              </div>
            </div>

            {storeShiftsQuery.isPending ? <p className="text-sm text-slate-500">{t("today.loading")}</p> : null}
            {storeShiftsQuery.isError ? (
              <ErrorState
                message={t("dayClose.shiftsTitle")}
                onRetry={() => void storeShiftsQuery.refetch()}
                retryLabel={t("common:actions.retry")}
              />
            ) : null}
            {filteredShifts.length === 0 && !storeShiftsQuery.isPending ? (
              <EmptyState title={t("dayClose.noShifts")} />
            ) : null}

            <ul className="grid gap-2">
              {filteredShifts.map((s: ShiftRow) => {
                const cashierName = userMap.get(s.cashier_id) ?? s.cashier_id.slice(0, 8);
                const isOpen = s.closed_at === null;

                return (
                  <li
                    key={s.id}
                    className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 pb-2 text-sm last:border-0 hover:bg-slate-50/40 px-1 rounded"
                    data-testid={`shift-row-${s.id}`}
                  >
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-semibold text-slate-900">{cashierName}</span>
                        {isOpen ? (
                          <Badge tone="warn">{t("dayClose.statusOpen")}</Badge>
                        ) : s.difference !== 0 ? (
                          <Badge tone="danger">{t("dayClose.filterDiscrepancies")}</Badge>
                        ) : (
                          <Badge tone="good">{t("dayClose.filterBalanced")}</Badge>
                        )}
                      </div>
                      <span className="text-xs text-slate-500 block mt-0.5">
                        {t("dayClose.openedAt")}: {new Date(s.opened_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                        {s.closed_at ? ` · ${t("dayClose.closedAt")}: ${new Date(s.closed_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}` : ""}
                        {` · ${t("dayClose.opening")}: ${fmt(s.opening_cash)}`}
                        {s.note ? ` · "${s.note}"` : ""}
                      </span>
                    </div>

                    <div className="flex items-center gap-3 text-right">
                      {isOpen ? (
                        <div className="flex items-center gap-2">
                          <Button
                            size="sm"
                            variant="outline"
                            data-testid={`shift-x-btn-${s.id}`}
                            onClick={() => setSelectedShiftX(s)}
                          >
                            {t("dayClose.xReportBtn")}
                          </Button>
                          <Button
                            size="sm"
                            data-testid={`shift-close-btn-${s.id}`}
                            onClick={() => setClosingShift(s)}
                          >
                            {t("dayClose.supervisorClose")}
                          </Button>
                        </div>
                      ) : (
                        <>
                          <div>
                            <span className="block font-semibold">
                              {s.counted_cash !== null ? fmt(s.counted_cash) : "-"}
                            </span>
                            {s.difference !== null ? (
                              <span
                                className={`text-xs font-mono font-medium ${
                                  s.difference === 0
                                    ? "text-slate-500"
                                    : s.difference > 0
                                    ? "text-emerald-700"
                                    : "text-red-700"
                                }`}
                              >
                                {s.difference >= 0 ? `+${fmt(s.difference)}` : fmt(s.difference)}
                              </span>
                            ) : null}
                          </div>
                          <Button
                            size="sm"
                            variant="outline"
                            data-testid={`shift-z-btn-${s.id}`}
                            onClick={() => setSelectedShiftZ(s)}
                          >
                            {t("dayClose.zReportBtn")}
                          </Button>
                        </>
                      )}
                    </div>
                  </li>
                );
              })}
            </ul>
          </Card>
        </TabPanel>
      </Tabs>

      {/* Day Close X-Report Dialog */}
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

      {/* Day Close Z-Report Dialog */}
      {selectedZReport ? (
        <ZReportDialog
          report={selectedZReport}
          store={store}
          userMap={userMap}
          fmt={fmt}
          onClose={() => setSelectedZReport(null)}
        />
      ) : null}

      {/* Cashier Shift X-Reading Dialog */}
      {selectedShiftX ? (
        <ShiftXReadingDialog
          shift={selectedShiftX}
          store={store}
          cashierName={userMap.get(selectedShiftX.cashier_id) ?? selectedShiftX.cashier_id.slice(0, 8)}
          fmt={fmt}
          onClose={() => setSelectedShiftX(null)}
        />
      ) : null}

      {/* Cashier Shift Z-Reading Dialog */}
      {selectedShiftZ ? (
        <ShiftZReadingDialog
          shift={selectedShiftZ}
          store={store}
          cashierName={userMap.get(selectedShiftZ.cashier_id) ?? selectedShiftZ.cashier_id.slice(0, 8)}
          userMap={userMap}
          fmt={fmt}
          onClose={() => setSelectedShiftZ(null)}
        />
      ) : null}

      {/* Supervisor Close Shift Modal */}
      {closingShift ? (
        <SupervisorCloseShiftModal
          shift={closingShift}
          store={store}
          currency={currency}
          cashierName={userMap.get(closingShift.cashier_id) ?? closingShift.cashier_id.slice(0, 8)}
          fmt={fmt}
          onClose={() => setClosingShift(null)}
          onSuccess={async (diffAmount) => {
            setClosingShift(null);
            const succ = t("dayClose.shiftClosedSuccess", { diff: fmt(diffAmount) });
            toast.good(succ);
            await qc.invalidateQueries({ queryKey: ["store-shifts", store.id] });
          }}
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
      <div className="printable-slip grid gap-4 text-sm">
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

        <div className="no-print flex justify-end gap-2 pt-2">
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
      <div className="printable-slip grid gap-4 text-sm">
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

        <div className="no-print flex justify-end gap-2 pt-2">
          <Button variant="outline" onClick={() => window.print()}>
            {t("dayClose.print")}
          </Button>
          <Button onClick={onClose}>{t("common:actions.close")}</Button>
        </div>
      </div>
    </Dialog>
  );
}

function ShiftXReadingDialog({
  shift,
  store,
  cashierName,
  fmt,
  onClose,
}: {
  shift: ShiftRow;
  store: { code: string; name: string };
  cashierName: string;
  fmt: (n: number) => string;
  onClose: () => void;
}) {
  const { t } = useTranslation(["admin", "common"]);
  const { access } = useSession();

  const expectedQuery = useQuery({
    queryKey: ["shift-expected-now", shift.id],
    queryFn: () => fetchShiftExpectedNow(shift.id),
    staleTime: 10_000,
  });

  const expectedCash = expectedQuery.data?.server_expected_cash ?? shift.opening_cash;

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={t("dayClose.shiftXTitle")} closeLabel={t("common:actions.close")}>
      <div className="printable-slip grid gap-4 text-sm">
        <div className="border-b border-dashed border-slate-300 pb-3 text-center">
          <h3 className="font-bold text-base text-slate-900">{access.tenant.name}</h3>
          <p className="text-xs text-slate-600">
            {store.name} ({store.code})
          </p>
          <div className="mt-2 inline-block rounded bg-amber-50 px-2.5 py-0.5 text-xs font-semibold text-amber-800">
            {t("dayClose.shiftXTitle")}
          </div>
          <p className="text-xs text-slate-700 font-medium mt-1">
            {t("dayClose.cashier")}: {cashierName}
          </p>
          <p className="text-xs text-slate-400">
            {t("dayClose.openedAt")}: {new Date(shift.opened_at).toLocaleString()}
          </p>
        </div>

        <div className="grid gap-2 border-b border-dashed border-slate-300 pb-3">
          <div className="flex justify-between text-slate-600">
            <span>{t("dayClose.openingCash")}:</span>
            <span className="font-mono">{fmt(shift.opening_cash)}</span>
          </div>
          <div className="flex justify-between font-bold text-slate-900 border-t border-slate-200 pt-1 text-base">
            <span>{t("dayClose.cashInDrawer")}:</span>
            <span className="font-mono">
              {expectedQuery.isPending ? "..." : fmt(expectedCash)}
            </span>
          </div>
        </div>

        <p className="text-center text-xs text-slate-400 italic">
          {t("dayClose.xReportNotice")}
        </p>

        <div className="no-print flex justify-end gap-2 pt-2">
          <Button variant="outline" onClick={() => window.print()}>
            {t("dayClose.print")}
          </Button>
          <Button onClick={onClose}>{t("common:actions.close")}</Button>
        </div>
      </div>
    </Dialog>
  );
}

function ShiftZReadingDialog({
  shift,
  store,
  cashierName,
  userMap,
  fmt,
  onClose,
}: {
  shift: ShiftRow;
  store: { code: string; name: string };
  cashierName: string;
  userMap: Map<string, string>;
  fmt: (n: number) => string;
  onClose: () => void;
}) {
  const { t } = useTranslation(["admin", "common"]);
  const { access } = useSession();

  const isMismatch =
    shift.server_expected_cash !== null &&
    shift.expected_cash !== null &&
    shift.server_expected_cash !== shift.expected_cash;

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={t("dayClose.shiftZTitle")} closeLabel={t("common:actions.close")}>
      <div className="printable-slip grid gap-4 text-sm">
        <div className="border-b border-dashed border-slate-300 pb-3 text-center">
          <h3 className="font-bold text-base text-slate-900">{access.tenant.name}</h3>
          <p className="text-xs text-slate-600">
            {store.name} ({store.code})
          </p>
          <div className="mt-2 inline-block rounded bg-emerald-50 px-2.5 py-0.5 text-xs font-semibold text-emerald-800">
            {t("dayClose.shiftZTitle")}
          </div>
          <p className="text-xs text-slate-700 font-medium mt-1">
            {t("dayClose.cashier")}: {cashierName}
          </p>
          <p className="text-xs text-slate-400">
            {new Date(shift.opened_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
            {shift.closed_at ? ` → ${new Date(shift.closed_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}` : ""}
          </p>
          {shift.closed_by ? (
            <p className="text-xs text-slate-500">
              {t("dayClose.closedBy")}: {userMap.get(shift.closed_by) ?? shift.closed_by.slice(0, 8)}
            </p>
          ) : null}
        </div>

        <div className="grid gap-2 border-b border-dashed border-slate-300 pb-3">
          <div className="flex justify-between text-slate-600">
            <span>{t("dayClose.openingCash")}:</span>
            <span className="font-mono">{fmt(shift.opening_cash)}</span>
          </div>
          <div className="flex justify-between text-slate-600">
            <span>{t("dayClose.expectedInDrawer")}:</span>
            <span className="font-mono">{shift.expected_cash !== null ? fmt(shift.expected_cash) : "-"}</span>
          </div>
          {shift.server_expected_cash !== null ? (
            <div className="flex justify-between text-slate-500 text-xs">
              <span>{t("dayClose.serverExpected")}:</span>
              <span className="font-mono">{fmt(shift.server_expected_cash)}</span>
            </div>
          ) : null}
          <div className="flex justify-between font-bold text-slate-900 border-t border-slate-200 pt-1 text-base">
            <span>{t("dayClose.countedCash")}:</span>
            <span className="font-mono">{shift.counted_cash !== null ? fmt(shift.counted_cash) : "-"}</span>
          </div>

          {shift.difference !== null ? (
            <div
              className={`flex justify-between items-center rounded p-2 text-sm font-semibold ${
                shift.difference === 0
                  ? "bg-slate-100 text-slate-800"
                  : shift.difference > 0
                  ? "bg-emerald-50 text-emerald-800"
                  : "bg-red-50 text-red-800"
              }`}
            >
              <span>{shift.difference >= 0 ? t("dayClose.over") : t("dayClose.short")}:</span>
              <span className="font-mono text-base">
                {shift.difference >= 0 ? `+${fmt(shift.difference)}` : fmt(shift.difference)}
              </span>
            </div>
          ) : null}
        </div>

        {isMismatch ? (
          <Alert tone="info">
            {t("dayClose.serverMismatchWarn")}
          </Alert>
        ) : null}

        {shift.note ? (
          <div className="rounded bg-slate-50 p-2 text-xs text-slate-600 border border-slate-200">
            <strong>{t("expenses.note")}:</strong> {shift.note}
          </div>
        ) : null}

        <p className="text-center text-xs text-slate-400 italic">
          {t("dayClose.zReportNotice")}
        </p>

        <div className="no-print flex justify-end gap-2 pt-2">
          <Button variant="outline" onClick={() => window.print()}>
            {t("dayClose.print")}
          </Button>
          <Button onClick={onClose}>{t("common:actions.close")}</Button>
        </div>
      </div>
    </Dialog>
  );
}

function SupervisorCloseShiftModal({
  shift,
  currency,
  cashierName,
  fmt,
  onClose,
  onSuccess,
}: {
  shift: ShiftRow;
  store: { code: string; name: string };
  currency: string;
  cashierName: string;
  fmt: (n: number) => string;
  onClose: () => void;
  onSuccess: (diff: number) => void;
}) {
  const { t } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const [countedText, setCountedText] = useState("");
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);

  const expectedQuery = useQuery({
    queryKey: ["shift-expected-now", shift.id],
    queryFn: () => fetchShiftExpectedNow(shift.id),
  });

  const expectedCash = expectedQuery.data?.server_expected_cash ?? shift.opening_cash;
  const parsedCounted = countedText.trim() === "" ? null : parseAmount(countedText, currency);
  const diff = parsedCounted !== null ? parsedCounted - expectedCash : null;

  const mut = useMutation({
    mutationFn: async () => {
      if (parsedCounted === null || parsedCounted < 0) {
        throw new Error(t("dayClose.invalidCounted"));
      }
      return closeCashierShift({
        shiftId: shift.id,
        expectedCash,
        countedCash: parsedCounted,
        note,
      });
    },
    onSuccess: (res) => {
      onSuccess(res.difference);
    },
    onError: (e) => {
      setError(e instanceof Error ? e.message : msg(e));
    },
  });

  return (
    <Dialog
      open
      onOpenChange={(o) => !o && onClose()}
      title={t("dayClose.supervisorCloseTitle")}
      closeLabel={t("common:actions.close")}
    >
      <div className="grid gap-3 text-sm">
        <p className="text-xs text-slate-600">
          {t("dayClose.supervisorClosePrompt")}
        </p>

        <div className="rounded bg-slate-50 p-2.5 border border-slate-200 grid gap-1 text-xs">
          <div className="flex justify-between">
            <span className="text-slate-600">{t("dayClose.cashier")}:</span>
            <span className="font-semibold text-slate-900">{cashierName}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-slate-600">{t("dayClose.openingCash")}:</span>
            <span className="font-mono">{fmt(shift.opening_cash)}</span>
          </div>
          <div className="flex justify-between font-medium">
            <span className="text-slate-700">{t("dayClose.expectedInDrawer")}:</span>
            <span className="font-mono">
              {expectedQuery.isPending ? "..." : fmt(expectedCash)}
            </span>
          </div>
        </div>

        <Field label={t("dayClose.countedCash")}>
          <Input
            data-testid="supervisor-counted-input"
            inputMode="decimal"
            placeholder={fmt(0)}
            value={countedText}
            onChange={(e) => setCountedText(e.target.value)}
          />
        </Field>

        {diff !== null ? (
          <div
            className={`p-2 rounded text-xs flex justify-between items-center ${
              diff === 0
                ? "bg-slate-100 text-slate-800"
                : diff > 0
                ? "bg-emerald-50 text-emerald-800"
                : "bg-red-50 text-red-800"
            }`}
          >
            <span>{diff >= 0 ? t("dayClose.over") : t("dayClose.short")}:</span>
            <strong className="font-mono text-sm">{fmt(Math.abs(diff))}</strong>
          </div>
        ) : null}

        <Field label={t("expenses.note")}>
          <Input
            data-testid="supervisor-note-input"
            placeholder={t("expenses.notePlaceholder")}
            maxLength={200}
            value={note}
            onChange={(e) => setNote(e.target.value)}
          />
        </Field>

        {error ? <Alert>{error}</Alert> : null}

        <div className="flex justify-end gap-2 pt-2 border-t border-slate-100">
          <Button variant="outline" onClick={onClose}>
            {t("common:actions.cancel")}
          </Button>
          <Button
            data-testid="supervisor-submit-close"
            disabled={mut.isPending || countedText.trim() === ""}
            onClick={() => mut.mutate()}
          >
            {mut.isPending ? t("dayClose.submitting") : t("dayClose.supervisorClose")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}
