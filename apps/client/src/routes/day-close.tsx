import { useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Alert, Badge, Button, Card, Input } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { parseAmount } from "../lib/sale-math.ts";
import { dayInTimezone, getDaySummary } from "../lib/today.ts";
import { computeDifference, computeExpectedCash } from "../lib/day-close-math.ts";
import {
  closeDay,
  fetchDayCloses,
  fetchTodayCashUtang,
  type DayCloseRow,
} from "../lib/day-close-api.ts";

export function DayClosePage() {
  const { t, i18n } = useTranslation("admin");
  const msg = useErrorMessage();
  const { access, can } = useSession();
  const qc = useQueryClient();
  const currency = access.tenant.base_currency;
  const timezone = access.tenant.timezone;
  const today = dayInTimezone(timezone);
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);
  const store = access.locations.find((l) => l.type === "store" && can("shift.manage", l.id));

  const [openingText, setOpeningText] = useState("");
  const [countedText, setCountedText] = useState("");
  const [note, setNote] = useState("");
  const [closeError, setCloseError] = useState<string | null>(null);
  const [successNote, setSuccessNote] = useState<string | null>(null);

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
      setSuccessNote(t("dayClose.closedSuccess", { diff: fmt(r.difference) }));
      await Promise.all([
        qc.invalidateQueries({ queryKey: ["day-closes", store?.id] }),
        qc.invalidateQueries({ queryKey: ["day-summary"] }),
      ]);
    },
    onError: (e) => {
      setSuccessNote(null);
      setCloseError(e instanceof Error ? e.message : msg(e));
    },
  });

  if (!store) {
    return (
      <Card>
        <p>{t("sell.noStore")}</p>
      </Card>
    );
  }

  return (
    <div className="grid max-w-4xl gap-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h2 className="text-lg font-semibold">{t("dayClose.title")}</h2>
          <p className="text-xs text-slate-500">
            {today} · {timezone}
          </p>
        </div>
        {todayClose ? (
          <Badge tone="good">
            {t("dayClose.statusClosed", { time: todayClose.closed_at.slice(11, 16) })}
          </Badge>
        ) : (
          <Badge tone="warn">{t("dayClose.statusOpen")}</Badge>
        )}
      </div>

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

          <label className="grid gap-1 text-sm">
            <span className="font-medium">{t("dayClose.countedCash")}</span>
            <Input
              data-testid="counted-cash-input"
              inputMode="decimal"
              placeholder={fmt(0)}
              value={countedText}
              onChange={(e) => setCountedText(e.target.value)}
            />
          </label>

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

          <label className="grid gap-1 text-sm">
            <span className="font-medium">{t("expenses.note")}</span>
            <Input
              data-testid="close-note-input"
              placeholder={t("expenses.notePlaceholder")}
              maxLength={200}
              value={note}
              onChange={(e) => setNote(e.target.value)}
            />
          </label>

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
        <h3 className="font-medium text-sm border-b border-slate-100 pb-2">
          {t("dayClose.historyTitle")}
        </h3>
        {dayClosesQuery.isPending ? <p className="text-sm text-slate-500">{t("today.loading")}</p> : null}
        {dayClosesQuery.data && dayClosesQuery.data.length === 0 ? (
          <p className="text-sm text-slate-500">{t("dayClose.noHistory")}</p>
        ) : null}

        <ul className="grid gap-2">
          {(dayClosesQuery.data ?? []).map((dc: DayCloseRow) => (
            <li
              key={dc.id}
              className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-100 pb-2 text-sm last:border-0"
            >
              <div>
                <span className="font-medium block">{dc.day}</span>
                <span className="text-xs text-slate-500">
                  {t("dayClose.opening")}: {fmt(dc.opening_cash)} · {t("dayClose.expected")}: {fmt(dc.expected_cash)}
                  {dc.note ? ` · "${dc.note}"` : ""}
                </span>
              </div>
              <div className="text-right">
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
            </li>
          ))}
        </ul>
      </Card>
    </div>
  );
}
