import { useState } from "react";
import { useTranslation } from "react-i18next";
import { useNavigate } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Calculator, Clock, ExternalLink, Printer } from "lucide-react";
import { formatMoney, money } from "@pos/core";
import {
  Alert,
  Badge,
  Button,
  Dialog,
  Field,
  Input,
  Select,
  useToast,
} from "./ui.tsx";
import { DenominationCounterDialog } from "./denomination-counter-dialog.tsx";
import { ShiftSlipModal, type ShiftSlipData } from "./shift-slip.tsx";
import { useSession } from "../lib/session.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { parseAmount } from "../lib/sale-math.ts";
import {
  closeCashierShift,
  fetchMyOpenShift,
  fetchShiftExpectedNow,
  openCashierShift,
} from "../lib/shifts-api.ts";
import {
  EXPENSE_CATEGORIES,
  recordExpense,
  type ExpenseCategory,
} from "../lib/expense-api.ts";
import { usePollInterval } from "../lib/polling.ts";

export function PosShiftControl({
  storeId,
  currency,
  timezone,
}: {
  storeId: string;
  currency: string;
  timezone: string;
}) {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const toast = useToast();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { access, can } = useSession();
  const pollInterval = usePollInterval(120_000);

  const [open, setOpen] = useState(false);
  const [tab, setTab] = useState<"close" | "drop">("close");
  const [openingText, setOpeningText] = useState("0");
  const [countedText, setCountedText] = useState("");
  const [closeNote, setCloseNote] = useState("");
  const [denomTarget, setDenomTarget] = useState<"opening" | "counted" | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [slipPreview, setSlipPreview] = useState<ShiftSlipData | null>(null);

  // Cash drop state
  const [dropAmountText, setDropAmountText] = useState("");
  const [dropCategory, setDropCategory] = useState<ExpenseCategory>("other");
  const [dropNote, setDropNote] = useState("");

  const canRecordExpense = access.role === "superadmin" || access.role === "admin";
  const canDayClose = can("shift.manage", storeId);

  const fmt = (minor: number) => formatMoney(money(minor, currency), i18n.language);
  const when = (iso: string) => {
    try {
      return new Intl.DateTimeFormat(i18n.language, {
        dateStyle: "short",
        timeStyle: "short",
        timeZone: timezone,
      }).format(new Date(iso));
    } catch {
      return iso.slice(0, 16).replace("T", " ");
    }
  };

  const shiftQuery = useQuery({
    queryKey: ["my-open-shift", access.user_id],
    queryFn: () => fetchMyOpenShift(access.user_id, currency),
    refetchInterval: pollInterval,
  });

  const openShift = shiftQuery.data ?? null;
  const isAtOtherStore = Boolean(openShift && openShift.location_id && openShift.location_id !== storeId);
  const otherStoreName = isAtOtherStore
    ? (access.locations.find((l) => l.id === openShift?.location_id)?.name ?? openShift?.location_id ?? "")
    : "";

  const expectedQuery = useQuery({
    queryKey: ["shift-expected-now", openShift?.id],
    queryFn: () => fetchShiftExpectedNow(openShift!.id),
    enabled: open && Boolean(openShift && !openShift.pending),
    staleTime: 10_000,
  });

  const expectedCash =
    expectedQuery.data?.server_expected_cash ?? openShift?.opening_cash ?? 0;

  const parsedCounted = countedText.trim() === "" ? null : parseAmount(countedText, currency);
  const diffPreview = parsedCounted !== null ? parsedCounted - expectedCash : null;

  async function refreshShiftState() {
    await Promise.all([
      qc.invalidateQueries({ queryKey: ["my-open-shift"] }),
      qc.invalidateQueries({ queryKey: ["store-shifts"] }),
      qc.invalidateQueries({ queryKey: ["shift-expected-now"] }),
    ]);
  }

  const startShiftMut = useMutation({
    mutationFn: async () => {
      const minor = openingText.trim() === "" ? 0 : parseAmount(openingText, currency);
      if (minor === null || minor < 0) {
        throw new Error(t("posShift.invalidAmount"));
      }
      return openCashierShift({ locationId: storeId, openingCash: minor });
    },
    onSuccess: async (res) => {
      setFormError(null);
      setOpen(false);
      toast.good(res.queuedOffline ? t("common:offline.queuedToast") : t("posShift.shiftStarted"));
      await refreshShiftState();
    },
    onError: (e) => {
      setFormError(e instanceof Error && e.message === t("posShift.invalidAmount") ? e.message : msg(e));
    },
  });

  const endShiftMut = useMutation({
    mutationFn: async () => {
      if (!openShift) throw new Error("No shift");
      if (parsedCounted === null || parsedCounted < 0) {
        throw new Error(t("posShift.invalidAmount"));
      }
      return closeCashierShift({
        shiftId: openShift.id,
        expectedCash,
        countedCash: parsedCounted,
        note: closeNote,
      });
    },
    onSuccess: async (res) => {
      const shiftSnapshot = openShift;
      const countedSnapshot = parsedCounted;
      const expectedSnapshot = expectedCash;
      const noteSnapshot = closeNote;
      const loc = access.locations.find((l) => l.id === (shiftSnapshot?.location_id ?? storeId));
      setCountedText("");
      setCloseNote("");
      setFormError(null);
      setOpen(false);
      toast.good(t("posShift.shiftClosed", { diff: fmt(res.difference) }));
      if (shiftSnapshot && countedSnapshot !== null) {
        setSlipPreview({
          kind: "z",
          tenantName: access.tenant.name,
          storeName: loc?.name ?? "",
          storeCode: loc?.code,
          storeAddress: loc?.address ?? null,
          receiptHeader: access.tenant.receipt_header ?? null,
          receiptFooter: access.tenant.receipt_footer ?? null,
          cashierName: access.full_name || access.username,
          openedAt: shiftSnapshot.opened_at,
          closedAt: new Date().toISOString(),
          closedByName: access.full_name || access.username,
          openingCash: shiftSnapshot.opening_cash,
          expectedCash: expectedSnapshot,
          serverExpectedCash: res.server_expected_cash,
          countedCash: countedSnapshot,
          difference: res.difference,
          note: noteSnapshot.trim() || null,
          currency,
          timezone,
        });
      }
      await refreshShiftState();
    },
    onError: (e) => {
      setFormError(e instanceof Error && e.message === t("posShift.invalidAmount") ? e.message : msg(e));
    },
  });

  const cashDropMut = useMutation({
    mutationFn: async () => {
      const minor = parseAmount(dropAmountText, currency);
      if (minor === null || minor <= 0) {
        throw new Error(t("posShift.invalidAmount"));
      }
      return recordExpense({
        amount: minor,
        category: dropCategory,
        paid_from: "cash",
        note: dropNote,
        locationId: storeId,
      });
    },
    onSuccess: async (res) => {
      setDropAmountText("");
      setDropNote("");
      setFormError(null);
      toast.good(res.queuedOffline ? t("common:offline.queuedToast") : t("posShift.cashDropSaved"));
      await Promise.all([
        qc.invalidateQueries({ queryKey: ["expenses"] }),
        qc.invalidateQueries({ queryKey: ["day-summary"] }),
        qc.invalidateQueries({ queryKey: ["shift-expected-now"] }),
      ]);
      setTab("close");
    },
    onError: (e) => {
      setFormError(e instanceof Error && e.message === t("posShift.invalidAmount") ? e.message : msg(e));
    },
  });

  const chipStyle = !openShift
    ? "border-sw-pastry-fg/30 bg-sw-pastry text-sw-pastry-fg hover:opacity-90"
    : isAtOtherStore
      ? "border-sw-pastry-fg/40 bg-sw-pastry text-sw-pastry-fg hover:opacity-90"
      : "border-ok-dot/40 bg-ok-bg text-ok-fg hover:opacity-90";

  return (
    <>
      <button
        type="button"
        data-testid="pos-shift-chip"
        onClick={() => {
          setFormError(null);
          setOpen(true);
        }}
        className={`inline-flex min-h-[36px] shrink-0 cursor-pointer items-center gap-1.5 rounded-full border-[1.5px] px-3 py-1.5 text-xs font-semibold transition-colors ${chipStyle}`}
      >
        <Clock
          size={14}
          className={!openShift || isAtOtherStore ? "text-sw-pastry-fg" : "text-ok-fg"}
          aria-hidden
        />
        <span>
          {!openShift
            ? t("posShift.noShiftChip")
            : isAtOtherStore
              ? t("posShift.otherStoreChip")
              : t("posShift.openChip")}
        </span>
      </button>

      <Dialog
        open={open}
        onOpenChange={setOpen}
        title={openShift ? t("posShift.dialogActiveTitle") : t("posShift.dialogOpenTitle")}
        closeLabel={t("common:actions.close")}
      >
        <div className="grid gap-4" data-testid="pos-shift-dialog">
          {!openShift ? (
            <>
              <p className="text-sm text-slate-600">{t("posShift.openDesc")}</p>
              <Field label={t("posShift.openingFloat")}>
                <div className="flex gap-2">
                  <Input
                    data-testid="pos-shift-opening-input"
                    inputMode="decimal"
                    value={openingText}
                    onChange={(e) => setOpeningText(e.target.value)}
                    placeholder="0.00"
                    className="flex-1 tabular-nums"
                  />
                  <Button
                    type="button"
                    variant="outline"
                    data-testid="pos-shift-open-denom-btn"
                    onClick={() => setDenomTarget("opening")}
                  >
                    <Calculator size={15} />
                    <span className="hidden sm:inline">{t("posShift.countBillsBtn")}</span>
                  </Button>
                </div>
              </Field>

              {formError ? <Alert>{formError}</Alert> : null}

              <div className="flex justify-end gap-2 border-t border-slate-100 pt-3">
                <Button type="button" variant="ghost" onClick={() => setOpen(false)}>
                  {t("common:actions.cancel")}
                </Button>
                <Button
                  type="button"
                  data-testid="pos-open-shift-btn"
                  disabled={startShiftMut.isPending}
                  onClick={() => startShiftMut.mutate()}
                >
                  {t("posShift.startShiftBtn")}
                </Button>
              </div>
            </>
          ) : (
            <>
              {isAtOtherStore ? (
                <Alert>{t("posShift.otherStoreWarning", { store: otherStoreName })}</Alert>
              ) : null}

              <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-200 bg-slate-50 p-3.5">
                <div className="grid gap-0.5">
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-semibold tracking-wider text-slate-500 uppercase">
                      {t("posShift.expectedCashNow")}
                    </span>
                    {openShift.pending ? (
                      <Badge tone="warn">{t("common:offline.queuedBadge")}</Badge>
                    ) : null}
                  </div>
                  <div
                    className="text-2xl font-semibold text-slate-900 tabular-nums"
                    data-testid="pos-shift-expected"
                  >
                    {fmt(expectedCash)}
                  </div>
                </div>
                <div className="grid justify-items-end gap-1.5 text-right text-xs text-slate-500">
                  <div>{t("posShift.openedSince", { time: when(openShift.opened_at) })}</div>
                  <div className="font-medium text-slate-700 tabular-nums">
                    {t("posShift.openingFloat")}: {fmt(openShift.opening_cash)}
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    data-testid="pos-shift-print-x"
                    onClick={() => {
                      const loc = access.locations.find((l) => l.id === (openShift.location_id ?? storeId));
                      setOpen(false);
                      setSlipPreview({
                        kind: "x",
                        tenantName: access.tenant.name,
                        storeName: loc?.name ?? "",
                        storeCode: loc?.code,
                        storeAddress: loc?.address ?? null,
                        receiptHeader: access.tenant.receipt_header ?? null,
                        receiptFooter: access.tenant.receipt_footer ?? null,
                        cashierName: access.full_name || access.username,
                        openedAt: openShift.opened_at,
                        openingCash: openShift.opening_cash,
                        expectedCash,
                        expectedPending: expectedQuery.isPending,
                        currency,
                        timezone,
                      });
                    }}
                  >
                    <Printer size={14} />
                    <span>{t("posShift.printXReading")}</span>
                  </Button>
                </div>
              </div>

              {canRecordExpense && !isAtOtherStore ? (
                <div className="flex gap-1.5 rounded-lg bg-slate-100 p-1">
                  <button
                    type="button"
                    data-testid="pos-shift-tab-close"
                    onClick={() => {
                      setTab("close");
                      setFormError(null);
                    }}
                    className={`flex-1 cursor-pointer rounded-md px-3 py-1.5 text-xs font-semibold transition-colors ${
                      tab === "close" ? "bg-white text-slate-900 shadow-2xs" : "text-slate-600 hover:text-slate-900"
                    }`}
                  >
                    {t("posShift.tabClose")}
                  </button>
                  <button
                    type="button"
                    data-testid="pos-shift-tab-drop"
                    onClick={() => {
                      setTab("drop");
                      setFormError(null);
                    }}
                    className={`flex-1 cursor-pointer rounded-md px-3 py-1.5 text-xs font-semibold transition-colors ${
                      tab === "drop" ? "bg-white text-slate-900 shadow-2xs" : "text-slate-600 hover:text-slate-900"
                    }`}
                  >
                    {t("posShift.tabCashDrop")}
                  </button>
                </div>
              ) : null}

              {tab === "drop" && canRecordExpense && !isAtOtherStore ? (
                <div className="grid gap-3">
                  <p className="text-xs text-slate-600">{t("posShift.cashDropDesc")}</p>
                  <div className="grid gap-3 sm:grid-cols-2">
                    <Field label={t("posShift.cashDropAmount")}>
                      <Input
                        data-testid="pos-cash-drop-amount"
                        inputMode="decimal"
                        value={dropAmountText}
                        onChange={(e) => setDropAmountText(e.target.value)}
                        placeholder="0.00"
                        className="tabular-nums"
                      />
                    </Field>
                    <Field label={t("posShift.cashDropCategory")}>
                      <Select
                        data-testid="pos-cash-drop-category"
                        value={dropCategory}
                        onChange={(e) => setDropCategory(e.target.value as ExpenseCategory)}
                      >
                        {EXPENSE_CATEGORIES.map((cat) => (
                          <option key={cat} value={cat}>
                            {t(`expenses.categories.${cat}`)}
                          </option>
                        ))}
                      </Select>
                    </Field>
                  </div>
                  <Field label={t("posShift.cashDropNote")}>
                    <Input
                      data-testid="pos-cash-drop-note"
                      value={dropNote}
                      onChange={(e) => setDropNote(e.target.value)}
                      placeholder={t("posShift.cashDropNotePlaceholder")}
                      maxLength={200}
                    />
                  </Field>
                  {formError ? <Alert>{formError}</Alert> : null}
                  <div className="flex justify-end gap-2 border-t border-slate-100 pt-3">
                    <Button
                      type="button"
                      data-testid="pos-cash-drop-submit"
                      disabled={cashDropMut.isPending || !dropAmountText.trim()}
                      onClick={() => cashDropMut.mutate()}
                    >
                      {t("posShift.cashDropBtn")}
                    </Button>
                  </div>
                </div>
              ) : (
                <div className="grid gap-3">
                  <Field label={t("posShift.countedCash")}>
                    <div className="flex gap-2">
                      <Input
                        data-testid="pos-shift-counted-input"
                        inputMode="decimal"
                        value={countedText}
                        onChange={(e) => setCountedText(e.target.value)}
                        placeholder="0.00"
                        className="flex-1 tabular-nums"
                      />
                      <Button
                        type="button"
                        variant="outline"
                        data-testid="pos-shift-count-denom-btn"
                        onClick={() => setDenomTarget("counted")}
                      >
                        <Calculator size={15} />
                        <span className="hidden sm:inline">{t("posShift.countBillsBtn")}</span>
                      </Button>
                    </div>
                  </Field>

                  {diffPreview !== null ? (
                    <div
                      data-testid="pos-shift-diff-preview"
                      className={`rounded-lg border px-3 py-2 text-xs font-semibold tabular-nums ${
                        diffPreview === 0
                          ? "border-emerald-200 bg-emerald-50 text-emerald-800"
                          : diffPreview < 0
                            ? "border-red-200 bg-red-50 text-red-800"
                            : "border-amber-200 bg-amber-50 text-amber-900"
                      }`}
                    >
                      {t("posShift.differencePreview", {
                        diff: diffPreview > 0 ? `+${fmt(diffPreview)}` : fmt(diffPreview),
                      })}
                    </div>
                  ) : null}

                  <Field label={t("posShift.noteOptional")}>
                    <Input
                      data-testid="pos-shift-close-note"
                      value={closeNote}
                      onChange={(e) => setCloseNote(e.target.value)}
                      maxLength={200}
                    />
                  </Field>

                  {formError ? <Alert>{formError}</Alert> : null}

                  <div className="flex flex-wrap items-center justify-between gap-2 border-t border-slate-100 pt-3">
                    {canDayClose ? (
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        data-testid="pos-go-day-close"
                        onClick={() => {
                          setOpen(false);
                          void navigate({ to: "/app/day-close" });
                        }}
                      >
                        <ExternalLink size={14} />
                        <span>{t("posShift.goDayClose")}</span>
                      </Button>
                    ) : (
                      <span />
                    )}
                    <div className="flex gap-2">
                      <Button type="button" variant="ghost" onClick={() => setOpen(false)}>
                        {t("common:actions.cancel")}
                      </Button>
                      <Button
                        type="button"
                        data-testid="pos-close-shift-btn"
                        disabled={
                          endShiftMut.isPending ||
                          Boolean(openShift.pending) ||
                          countedText.trim() === ""
                        }
                        onClick={() => endShiftMut.mutate()}
                      >
                        {t("posShift.closeShiftBtn")}
                      </Button>
                    </div>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </Dialog>

      <DenominationCounterDialog
        open={denomTarget !== null}
        onClose={() => setDenomTarget(null)}
        currency={currency}
        onApply={(_total, formattedDecimal) => {
          if (denomTarget === "opening") {
            setOpeningText(formattedDecimal);
          } else if (denomTarget === "counted") {
            setCountedText(formattedDecimal);
          }
        }}
      />

      <ShiftSlipModal
        open={slipPreview !== null}
        onClose={() => setSlipPreview(null)}
        slip={slipPreview}
      />
    </>
  );
}
