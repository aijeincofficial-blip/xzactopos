import { useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { usePollInterval } from "../lib/polling.ts";
import { formatMoney, money } from "@pos/core";
import { Calculator } from "lucide-react";
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
  TableSkeleton,
  TabPanel,
  Tabs,
  useToast,
} from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { canCloseDayForRole } from "../lib/portal.ts";
import { useActiveLocation } from "../lib/location-context.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { parseAmount } from "../lib/sale-math.ts";
import { dayInTimezone, getDaySummary } from "../lib/today.ts";
import { computeDifference, computeExpectedCash } from "../lib/day-close-math.ts";
import { listUsers } from "../lib/api.ts";
import {
  closeDay,
  fetchDayCloses,
  fetchTodayCashServices,
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
import { DenominationCounterDialog } from "../components/denomination-counter-dialog.tsx";
import { DayCloseSlipView, ShiftSlipView } from "../components/shift-slip.tsx";

export function DayClosePage() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const toast = useToast();
  const { access, can } = useSession();
  const pollInterval = usePollInterval(120_000);
  const qc = useQueryClient();
  const currency = access.tenant.base_currency;
  const timezone = access.tenant.timezone;
  const today = dayInTimezone(timezone);
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);
  const { activeStore } = useActiveLocation();
  const store = (activeStore && can("shift.manage", activeStore.id))
    ? activeStore
    : access.locations.find((l) => l.type === "store" && can("shift.manage", l.id));

  const canCloseDay = canCloseDayForRole(access.role);
  const [activeTab, setActiveTab] = useState<"day-closes" | "shifts">(canCloseDay ? "day-closes" : "shifts");

  // Day close drawer inputs
  const [openingText, setOpeningText] = useState("");
  const [countedText, setCountedText] = useState("");
  const [showDenomDialog, setShowDenomDialog] = useState(false);
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
    queryKey: ["day-summary", today, store?.id],
    queryFn: () => getDaySummary(today, store?.id),
    enabled: canCloseDay && Boolean(store),
    refetchInterval: pollInterval,
  });

  const cashUtangQuery = useQuery({
    queryKey: ["today-cash-utang", store?.id, today],
    queryFn: () => fetchTodayCashUtang(store?.id ?? "", today, timezone),
    enabled: canCloseDay && Boolean(store),
    refetchInterval: pollInterval,
  });

  const cashServicesQuery = useQuery({
    queryKey: ["today-cash-services", store?.id, today],
    queryFn: () => fetchTodayCashServices(store?.id ?? "", today, timezone),
    enabled: canCloseDay && Boolean(store),
    refetchInterval: pollInterval,
  });

  const dayClosesQuery = useQuery({
    queryKey: ["day-closes", store?.id],
    queryFn: () => fetchDayCloses(store?.id ?? ""),
    enabled: canCloseDay && Boolean(store),
  });

  const storeShiftsQuery = useQuery({
    queryKey: ["store-shifts", store?.id],
    queryFn: () => fetchStoreShifts(store?.id ?? ""),
    enabled: Boolean(store),
    refetchInterval: pollInterval,
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
  const cashServices = cashServicesQuery.data ?? 0;

  const parsedOpening = openingText.trim() === "" ? 0 : parseAmount(openingText, currency);
  const parsedCounted = countedText.trim() === "" ? null : parseAmount(countedText, currency);

  const openingCash = parsedOpening ?? 0;
  const expectedCash = computeExpectedCash({
    openingCash,
    cashSales,
    cashUtangPayments: cashUtang,
    cashServices,
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
          canCloseDay ? (
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
          ) : null
        }
      />

      {successNote ? <Alert tone="info">{successNote}</Alert> : null}

      <Tabs
        value={canCloseDay ? activeTab : "shifts"}
        onValueChange={(v) => setActiveTab(v as "day-closes" | "shifts")}
        label={t("dayClose.title")}
        tabs={[
          ...(canCloseDay
            ? [{ value: "day-closes", label: t("dayClose.tabDayClose"), testId: "tab-day-closes" }]
            : []),
          { value: "shifts", label: t("dayClose.tabShifts"), testId: "tab-shifts" },
        ]}
      >
        {canCloseDay ? (
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
                    <span>
                      {cashServices >= 0 ? "+" : "-"} {t("dayClose.cashServices")}:
                    </span>
                    <span data-testid="cash-services-total">{fmt(Math.abs(cashServices))}</span>
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

                <div className="grid gap-1.5">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-semibold text-slate-700">{t("dayClose.countedCash")}</span>
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      data-testid="open-denomination-counter"
                      onClick={() => setShowDenomDialog(true)}
                    >
                      <Calculator size={14} className="text-ink" aria-hidden />
                      <span>{t("dayClose.denominationCalculator")}</span>
                    </Button>
                  </div>
                  <Input
                    data-testid="counted-cash-input"
                    inputMode="decimal"
                    placeholder={fmt(0)}
                    value={countedText}
                    onChange={(e) => setCountedText(e.target.value)}
                  />
                </div>

                {diff !== null ? (
                  <div
                    className={`flex items-center justify-between rounded-[14px] border-[1.5px] p-3 text-sm ${
                      diff === 0
                        ? "border-sand-line bg-sand text-text-on-light"
                        : diff > 0
                        ? "border-ok-dot/40 bg-ok-bg text-ok-fg"
                        : "border-sw-meal-fg/30 bg-sw-meal text-sw-meal-fg"
                    }`}
                    data-testid="difference-badge"
                  >
                    <span>{diff >= 0 ? t("dayClose.over") : t("dayClose.short")}:</span>
                    <strong className="font-mono text-base tabular-nums">{fmt(Math.abs(diff))}</strong>
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

              {dayClosesQuery.isPending ? <TableSkeleton rows={3} cols={3} /> : null}
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
        ) : null}

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
      {canCloseDay && showXReport ? (
        <XReportDialog
          store={store}
          today={today}
          fmt={fmt}
          openingCash={openingCash}
          cashSales={cashSales}
          cashUtang={cashUtang}
          cashServices={cashServices}
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

      <DenominationCounterDialog
        open={showDenomDialog}
        onClose={() => setShowDenomDialog(false)}
        onApply={(_, decimalStr) => setCountedText(decimalStr)}
        currency={currency}
      />
    </div>
  );
}

function XReportDialog({
  store,
  today,
  openingCash,
  cashSales,
  cashUtang,
  cashServices,
  cashExpenses,
  expectedCash,
  totals,
  onClose,
}: {
  store: { code: string; name: string; address?: string | null };
  today: string;
  fmt: (n: number) => string;
  openingCash: number;
  cashSales: number;
  cashUtang: number;
  cashServices: number;
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
        <DayCloseSlipView
          slip={{
            kind: "x",
            tenantName: access.tenant.name,
            storeName: store.name,
            storeCode: store.code,
            storeAddress: store.address ?? null,
            receiptHeader: access.tenant.receipt_header ?? null,
            receiptFooter: access.tenant.receipt_footer ?? null,
            dayLabel: today,
            timeLabel: new Date().toLocaleTimeString(),
            closedByName: access.full_name || access.username,
            openingCash,
            cashSales,
            cashUtang,
            cashServices,
            cashExpenses,
            expectedCash,
            totals,
            currency: access.tenant.base_currency,
          }}
        />
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
  onClose,
}: {
  report: DayCloseRow;
  store: { code: string; name: string; address?: string | null };
  userMap: Map<string, string>;
  fmt: (n: number) => string;
  onClose: () => void;
}) {
  const { t } = useTranslation(["admin", "common"]);
  const { access } = useSession();

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={t("dayClose.zReportTitle")} closeLabel={t("common:actions.close")}>
      <div className="grid gap-4 text-sm">
        <DayCloseSlipView
          slip={{
            kind: "z",
            tenantName: access.tenant.name,
            storeName: store.name,
            storeCode: store.code,
            storeAddress: store.address ?? null,
            receiptHeader: access.tenant.receipt_header ?? null,
            receiptFooter: access.tenant.receipt_footer ?? null,
            dayLabel: report.day,
            timeLabel: report.closed_at.slice(11, 19),
            closedByName: report.closed_by ? (userMap.get(report.closed_by) ?? report.closed_by.slice(0, 8)) : null,
            approvedByName: report.approved_by ? (userMap.get(report.approved_by) ?? report.approved_by.slice(0, 8)) : null,
            openingCash: report.opening_cash,
            expectedCash: report.expected_cash,
            countedCash: report.counted_cash,
            difference: report.difference,
            note: report.note,
            currency: access.tenant.base_currency,
          }}
        />
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
  onClose,
}: {
  shift: ShiftRow;
  store: { code: string; name: string; address?: string | null };
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
      <div className="grid gap-4 text-sm">
        <ShiftSlipView
          slip={{
            kind: "x",
            tenantName: access.tenant.name,
            storeName: store.name,
            storeCode: store.code,
            storeAddress: store.address ?? null,
            receiptHeader: access.tenant.receipt_header ?? null,
            receiptFooter: access.tenant.receipt_footer ?? null,
            cashierName,
            openedAt: shift.opened_at,
            openingCash: shift.opening_cash,
            expectedCash,
            expectedPending: expectedQuery.isPending,
            currency: shift.currency || access.tenant.base_currency,
            timezone: access.tenant.timezone,
          }}
        />
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
  onClose,
}: {
  shift: ShiftRow;
  store: { code: string; name: string; address?: string | null };
  cashierName: string;
  userMap: Map<string, string>;
  fmt: (n: number) => string;
  onClose: () => void;
}) {
  const { t } = useTranslation(["admin", "common"]);
  const { access } = useSession();

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={t("dayClose.shiftZTitle")} closeLabel={t("common:actions.close")}>
      <div className="grid gap-4 text-sm">
        <ShiftSlipView
          slip={{
            kind: "z",
            tenantName: access.tenant.name,
            storeName: store.name,
            storeCode: store.code,
            storeAddress: store.address ?? null,
            receiptHeader: access.tenant.receipt_header ?? null,
            receiptFooter: access.tenant.receipt_footer ?? null,
            cashierName,
            openedAt: shift.opened_at,
            closedAt: shift.closed_at,
            closedByName: shift.closed_by ? (userMap.get(shift.closed_by) ?? shift.closed_by.slice(0, 8)) : null,
            openingCash: shift.opening_cash,
            expectedCash: shift.expected_cash,
            serverExpectedCash: shift.server_expected_cash,
            countedCash: shift.counted_cash,
            difference: shift.difference,
            note: shift.note,
            currency: shift.currency || access.tenant.base_currency,
            timezone: access.tenant.timezone,
          }}
        />
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
  const [showDenomDialog, setShowDenomDialog] = useState(false);
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

        <div className="grid gap-1.5">
          <div className="flex items-center justify-between">
            <span className="text-sm font-semibold">{t("dayClose.countedCash")}</span>
            <Button
              type="button"
              variant="outline"
              size="sm"
              data-testid="supervisor-open-denomination-counter"
              onClick={() => setShowDenomDialog(true)}
            >
              <Calculator size={14} className="text-ink" aria-hidden />
              <span>{t("dayClose.denominationCalculator")}</span>
            </Button>
          </div>
          <Input
            data-testid="supervisor-counted-input"
            inputMode="decimal"
            placeholder={fmt(0)}
            value={countedText}
            onChange={(e) => setCountedText(e.target.value)}
          />
        </div>

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

      <DenominationCounterDialog
        open={showDenomDialog}
        onClose={() => setShowDenomDialog(false)}
        onApply={(_, decimalStr) => setCountedText(decimalStr)}
        currency={currency}
      />
    </Dialog>
  );
}
