import { useTranslation } from "react-i18next";
import { formatMoney, money } from "@pos/core";
import { Alert, Button, Dialog } from "./ui.tsx";

export interface ShiftSlipData {
  kind: "x" | "z";
  tenantName: string;
  storeName: string;
  storeCode?: string;
  storeAddress?: string | null;
  receiptHeader?: string | null;
  receiptFooter?: string | null;
  cashierName: string;
  openedAt: string;
  closedAt?: string | null;
  closedByName?: string | null;
  openingCash: number;
  expectedCash: number | null;
  expectedPending?: boolean;
  serverExpectedCash?: number | null;
  countedCash?: number | null;
  difference?: number | null;
  note?: string | null;
  currency: string;
  timezone?: string;
}

export interface DayCloseSlipData {
  kind: "x" | "z";
  tenantName: string;
  storeName: string;
  storeCode?: string;
  storeAddress?: string | null;
  receiptHeader?: string | null;
  receiptFooter?: string | null;
  dayLabel: string;
  timeLabel?: string;
  closedByName?: string | null;
  approvedByName?: string | null;
  openingCash: number;
  cashSales?: number;
  cashUtang?: number;
  cashExpenses?: number;
  expectedCash: number;
  countedCash?: number;
  difference?: number;
  totals?: {
    gross: number;
    net: number;
    txns: number;
    ewallet: number;
    card?: number;
    utang: number;
  } | null;
  note?: string | null;
  currency: string;
}

function formatSlipDateTime(iso: string, lang: string, timezone?: string): string {
  try {
    return new Intl.DateTimeFormat(lang, {
      dateStyle: "medium",
      timeStyle: "short",
      timeZone: timezone || "Asia/Manila",
    }).format(new Date(iso));
  } catch {
    return new Date(iso).toLocaleString();
  }
}

function ThermalSlipHeader({
  tenantName,
  storeName,
  storeCode,
  storeAddress,
  receiptHeader,
  badgeLabel,
  badgeTone,
}: {
  tenantName: string;
  storeName: string;
  storeCode?: string | undefined;
  storeAddress?: string | null | undefined;
  receiptHeader?: string | null | undefined;
  badgeLabel: string;
  badgeTone: "amber" | "emerald";
}) {
  return (
    <div className="border-b border-dashed border-slate-300 pb-2 mb-2 text-center">
      <h3 className="font-bold text-sm tracking-wide uppercase">{tenantName}</h3>
      <p className="text-xs text-slate-600">
        {storeName} {storeCode ? `(${storeCode})` : ""}
      </p>
      {storeAddress?.trim() ? (
        <p className="text-[10px] text-slate-500 whitespace-pre-line" data-testid="shift-slip-store-address">
          {storeAddress.trim()}
        </p>
      ) : null}
      {receiptHeader?.trim() ? (
        <p className="mt-1 text-[10px] text-slate-600 whitespace-pre-line" data-testid="shift-slip-custom-header">
          {receiptHeader.trim()}
        </p>
      ) : null}
      <div
        data-testid="shift-slip-kind"
        className={`mt-1.5 inline-block rounded px-2 py-0.5 text-[11px] font-bold tracking-wider uppercase ${
          badgeTone === "amber" ? "bg-amber-100 text-amber-900" : "bg-emerald-100 text-emerald-900"
        }`}
      >
        {badgeLabel}
      </div>
    </div>
  );
}

export function ShiftSlipView({ slip }: { slip: ShiftSlipData }) {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const fmt = (n: number) => formatMoney(money(n, slip.currency), i18n.language);

  const isMismatch =
    slip.kind === "z" &&
    slip.serverExpectedCash !== null &&
    slip.serverExpectedCash !== undefined &&
    slip.expectedCash !== null &&
    slip.serverExpectedCash !== slip.expectedCash;

  return (
    <div className="printable-slip text-xs font-mono text-slate-900 bg-white p-4 max-w-sm mx-auto border border-dashed border-slate-300 rounded shadow-sm print:border-none print:shadow-none print:p-0 print:max-w-none">
      <ThermalSlipHeader
        tenantName={slip.tenantName}
        storeName={slip.storeName}
        storeCode={slip.storeCode}
        storeAddress={slip.storeAddress}
        receiptHeader={slip.receiptHeader}
        badgeLabel={slip.kind === "x" ? t("dayClose.shiftXTitle") : t("dayClose.shiftZTitle")}
        badgeTone={slip.kind === "x" ? "amber" : "emerald"}
      />

      {/* Shift Metadata */}
      <div className="space-y-0.5 border-b border-dashed border-slate-300 pb-2 mb-2 text-[11px]">
        <div className="flex justify-between gap-2">
          <span className="text-slate-500">{t("dayClose.cashier")}:</span>
          <span className="font-semibold text-right">{slip.cashierName}</span>
        </div>
        <div className="flex justify-between gap-2">
          <span className="text-slate-500">{t("dayClose.openedAt")}:</span>
          <span className="text-right">{formatSlipDateTime(slip.openedAt, i18n.language, slip.timezone)}</span>
        </div>
        {slip.closedAt ? (
          <div className="flex justify-between gap-2">
            <span className="text-slate-500">{t("dayClose.closedAt")}:</span>
            <span className="text-right">{formatSlipDateTime(slip.closedAt, i18n.language, slip.timezone)}</span>
          </div>
        ) : null}
        {slip.closedByName ? (
          <div className="flex justify-between gap-2">
            <span className="text-slate-500">{t("dayClose.closedBy")}:</span>
            <span className="text-right">{slip.closedByName}</span>
          </div>
        ) : null}
      </div>

      {/* Figures */}
      <div className="space-y-1 border-b border-dashed border-slate-300 pb-2 mb-2 text-[11px]">
        <div className="flex justify-between">
          <span className="text-slate-600">{t("dayClose.openingCash")}:</span>
          <span className="tabular-nums">{fmt(slip.openingCash)}</span>
        </div>
        <div
          className={`flex justify-between ${
            slip.kind === "x" ? "border-t border-slate-200 pt-1 text-sm font-bold text-slate-900" : "text-slate-600"
          }`}
        >
          <span>{slip.kind === "x" ? t("dayClose.cashInDrawer") : t("dayClose.expectedInDrawer")}:</span>
          <span className="tabular-nums" data-testid="shift-slip-expected">
            {slip.expectedPending ? "..." : slip.expectedCash !== null ? fmt(slip.expectedCash) : "-"}
          </span>
        </div>
        {slip.kind === "z" && slip.serverExpectedCash !== null && slip.serverExpectedCash !== undefined ? (
          <div className="flex justify-between text-[10px] text-slate-500">
            <span>{t("dayClose.serverExpected")}:</span>
            <span className="tabular-nums">{fmt(slip.serverExpectedCash)}</span>
          </div>
        ) : null}
        {slip.kind === "z" ? (
          <>
            <div className="flex justify-between border-t border-slate-200 pt-1 text-sm font-bold text-slate-900">
              <span>{t("dayClose.countedCash")}:</span>
              <span className="tabular-nums" data-testid="shift-slip-counted">
                {slip.countedCash !== null && slip.countedCash !== undefined ? fmt(slip.countedCash) : "-"}
              </span>
            </div>
            {slip.difference !== null && slip.difference !== undefined ? (
              <div
                data-testid="shift-slip-diff"
                className={`mt-1 flex items-center justify-between rounded px-2 py-1 text-xs font-bold ${
                  slip.difference === 0
                    ? "bg-slate-100 text-slate-800"
                    : slip.difference > 0
                      ? "bg-emerald-50 text-emerald-800"
                      : "bg-red-50 text-red-800"
                }`}
              >
                <span>{slip.difference >= 0 ? t("dayClose.over") : t("dayClose.short")}:</span>
                <span className="tabular-nums">
                  {slip.difference > 0 ? `+${fmt(slip.difference)}` : fmt(slip.difference)}
                </span>
              </div>
            ) : null}
          </>
        ) : null}
      </div>

      {isMismatch ? (
        <div className="mb-2">
          <Alert tone="info">{t("dayClose.serverMismatchWarn")}</Alert>
        </div>
      ) : null}

      {slip.note?.trim() ? (
        <div className="mb-2 rounded border border-slate-200 bg-slate-50 p-2 text-[11px] text-slate-700">
          <strong>{t("expenses.note")}:</strong> {slip.note.trim()}
        </div>
      ) : null}

      {/* Footer */}
      <div className="text-center text-[10px] text-slate-500 pt-1 space-y-0.5">
        <p className="italic">{slip.kind === "x" ? t("dayClose.xReportNotice") : t("dayClose.zReportNotice")}</p>
        {slip.receiptFooter?.trim() ? (
          <p className="whitespace-pre-line text-slate-600" data-testid="shift-slip-custom-footer">
            {slip.receiptFooter.trim()}
          </p>
        ) : null}
      </div>
    </div>
  );
}

export function DayCloseSlipView({ slip }: { slip: DayCloseSlipData }) {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const fmt = (n: number) => formatMoney(money(n, slip.currency), i18n.language);

  return (
    <div className="printable-slip text-xs font-mono text-slate-900 bg-white p-4 max-w-sm mx-auto border border-dashed border-slate-300 rounded shadow-sm print:border-none print:shadow-none print:p-0 print:max-w-none">
      <ThermalSlipHeader
        tenantName={slip.tenantName}
        storeName={slip.storeName}
        storeCode={slip.storeCode}
        storeAddress={slip.storeAddress}
        receiptHeader={slip.receiptHeader}
        badgeLabel={slip.kind === "x" ? t("dayClose.interimReading") : t("dayClose.finalClose")}
        badgeTone={slip.kind === "x" ? "amber" : "emerald"}
      />

      <div className="space-y-0.5 border-b border-dashed border-slate-300 pb-2 mb-2 text-[11px]">
        <div className="flex justify-between">
          <span className="text-slate-500">{t("purchasing.receipts.date")}:</span>
          <span>
            {slip.dayLabel}
            {slip.timeLabel ? ` · ${slip.timeLabel}` : ""}
          </span>
        </div>
        {slip.closedByName ? (
          <div className="flex justify-between">
            <span className="text-slate-500">{t("dayClose.closedBy")}:</span>
            <span>{slip.closedByName}</span>
          </div>
        ) : null}
        {slip.approvedByName ? (
          <div className="flex justify-between">
            <span className="text-slate-500">{t("dayClose.approvedBy")}:</span>
            <span>{slip.approvedByName}</span>
          </div>
        ) : null}
      </div>

      {/* Drawer cash breakdown */}
      <div className="space-y-1 border-b border-dashed border-slate-300 pb-2 mb-2 text-[11px]">
        <div className="flex justify-between">
          <span className="text-slate-600">{t("dayClose.openingCash")}:</span>
          <span className="tabular-nums">{fmt(slip.openingCash)}</span>
        </div>
        {slip.cashSales !== undefined ? (
          <div className="flex justify-between">
            <span className="text-slate-600">+ {t("dayClose.cashSales")}:</span>
            <span className="tabular-nums">{fmt(slip.cashSales)}</span>
          </div>
        ) : null}
        {slip.cashUtang !== undefined ? (
          <div className="flex justify-between">
            <span className="text-slate-600">+ {t("dayClose.cashUtangCollected")}:</span>
            <span className="tabular-nums">{fmt(slip.cashUtang)}</span>
          </div>
        ) : null}
        {slip.cashExpenses !== undefined ? (
          <div className="flex justify-between">
            <span className="text-slate-600">- {t("dayClose.cashExpenses")}:</span>
            <span className="tabular-nums">{fmt(slip.cashExpenses)}</span>
          </div>
        ) : null}
        <div
          className={`flex justify-between ${
            slip.kind === "x" ? "border-t border-slate-200 pt-1 text-sm font-bold text-slate-900" : "text-slate-600"
          }`}
        >
          <span>{slip.kind === "x" ? t("dayClose.cashInDrawer") : t("dayClose.expectedInDrawer")}:</span>
          <span className="tabular-nums">{fmt(slip.expectedCash)}</span>
        </div>

        {slip.kind === "z" && slip.countedCash !== undefined ? (
          <>
            <div className="flex justify-between border-t border-slate-200 pt-1 text-sm font-bold text-slate-900">
              <span>{t("dayClose.countedCash")}:</span>
              <span className="tabular-nums">{fmt(slip.countedCash)}</span>
            </div>
            {slip.difference !== undefined ? (
              <div
                className={`mt-1 flex items-center justify-between rounded px-2 py-1 text-xs font-bold ${
                  slip.difference === 0
                    ? "bg-slate-100 text-slate-800"
                    : slip.difference > 0
                      ? "bg-emerald-50 text-emerald-800"
                      : "bg-red-50 text-red-800"
                }`}
              >
                <span>{slip.difference >= 0 ? t("dayClose.over") : t("dayClose.short")}:</span>
                <span className="tabular-nums">
                  {slip.difference > 0 ? `+${fmt(slip.difference)}` : fmt(slip.difference)}
                </span>
              </div>
            ) : null}
          </>
        ) : null}
      </div>

      {/* Totals & tenders */}
      {slip.totals ? (
        <div className="space-y-1 border-b border-dashed border-slate-300 pb-2 mb-2 text-[11px] text-slate-600">
          <div className="flex justify-between">
            <span>{t("dayClose.txnCount")}:</span>
            <span className="font-semibold text-slate-900 tabular-nums">{slip.totals.txns}</span>
          </div>
          <div className="flex justify-between">
            <span>{t("dayClose.grossSales")}:</span>
            <span className="font-semibold text-slate-900 tabular-nums">{fmt(slip.totals.gross)}</span>
          </div>
          <div className="flex justify-between">
            <span>{t("dayClose.ewalletSales")}:</span>
            <span className="font-semibold text-slate-900 tabular-nums">{fmt(slip.totals.ewallet)}</span>
          </div>
          {slip.totals.card !== undefined ? (
            <div className="flex justify-between">
              <span>{t("dayClose.cardSales")}:</span>
              <span className="font-semibold text-slate-900 tabular-nums">{fmt(slip.totals.card)}</span>
            </div>
          ) : null}
          <div className="flex justify-between">
            <span>{t("dayClose.utangSales")}:</span>
            <span className="font-semibold text-slate-900 tabular-nums">{fmt(slip.totals.utang)}</span>
          </div>
        </div>
      ) : null}

      {slip.note?.trim() ? (
        <div className="mb-2 rounded border border-slate-200 bg-slate-50 p-2 text-[11px] text-slate-700">
          <strong>{t("expenses.note")}:</strong> {slip.note.trim()}
        </div>
      ) : null}

      <div className="text-center text-[10px] text-slate-500 pt-1 space-y-0.5">
        <p className="italic">{slip.kind === "x" ? t("dayClose.xReportNotice") : t("dayClose.zReportNotice")}</p>
        {slip.receiptFooter?.trim() ? (
          <p className="whitespace-pre-line text-slate-600" data-testid="shift-slip-custom-footer">
            {slip.receiptFooter.trim()}
          </p>
        ) : null}
      </div>
    </div>
  );
}

export function ShiftSlipModal({
  open,
  onClose,
  slip,
}: {
  open: boolean;
  onClose: () => void;
  slip: ShiftSlipData | null;
}) {
  const { t } = useTranslation(["admin", "common"]);
  if (!slip) return null;

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (!next) onClose();
      }}
      title={slip.kind === "x" ? t("dayClose.shiftXTitle") : t("dayClose.shiftZTitle")}
      closeLabel={t("common:actions.close")}
    >
      <div className="grid gap-4" data-testid="shift-slip-modal">
        <ShiftSlipView slip={slip} />
        <div className="no-print flex justify-end gap-2 pt-1">
          <Button variant="outline" onClick={() => window.print()} data-testid="shift-slip-print-btn">
            {t("dayClose.print")}
          </Button>
          <Button onClick={onClose}>{t("common:actions.close")}</Button>
        </div>
      </div>
    </Dialog>
  );
}
