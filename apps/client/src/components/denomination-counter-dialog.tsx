import { useState } from "react";
import { useTranslation } from "react-i18next";
import { formatMoney, money } from "@pos/core";
import { Banknote, Coins } from "lucide-react";
import { Button, Dialog, Input } from "./ui.tsx";
import {
  PHP_DENOMINATIONS,
  calculateDenominationTotal,
  type DenominationCounts,
} from "../lib/denomination-math.ts";

export interface DenominationCounterDialogProps {
  open: boolean;
  onClose: () => void;
  onApply: (totalAmount: number, formattedDecimal: string) => void;
  currency: string;
}

export function DenominationCounterDialog({
  open,
  onClose,
  onApply,
  currency,
}: DenominationCounterDialogProps) {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const [counts, setCounts] = useState<DenominationCounts>({});

  const total = calculateDenominationTotal(PHP_DENOMINATIONS, counts);
  const fmt = (n: number) =>
    formatMoney(money(Math.round(n * 100), currency), i18n.language);

  const handleCountChange = (id: string, val: string) => {
    const num = parseInt(val, 10);
    setCounts((prev) => {
      const next = { ...prev };
      if (!val || isNaN(num) || num <= 0) {
        delete next[id];
      } else {
        next[id] = num;
      }
      return next;
    });
  };

  const handleApply = () => {
    onApply(total, total.toFixed(2));
    onClose();
  };

  const handleClear = () => {
    setCounts({});
  };

  const bills = PHP_DENOMINATIONS.filter((d) => d.type === "bill");
  const coins = PHP_DENOMINATIONS.filter((d) => d.type === "coin");

  return (
    <Dialog
      open={open}
      onOpenChange={(isOpen) => !isOpen && onClose()}
      title={t("dayClose.denominationCalculator")}
      closeLabel={t("common:actions.close")}
    >
      <div className="grid gap-4 py-2 max-w-xl" data-testid="denomination-dialog">
        {/* Total Summary */}
        <div className="flex items-center justify-between rounded-lg border border-slate-200 bg-slate-50 p-4">
          <div>
            <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">
              {t("dayClose.totalCalculated")}
            </div>
            <div
              className="mt-1 text-2xl font-bold text-slate-900"
              data-testid="denom-total"
            >
              {fmt(total)}
            </div>
          </div>
          <Button
            size="sm"
            variant="outline"
            onClick={handleClear}
            data-testid="denom-clear-btn"
          >
            {t("dayClose.clearCount")}
          </Button>
        </div>

        {/* Banknotes Section */}
        <div className="grid gap-2">
          <h4 className="flex items-center gap-1.5 font-mono text-xs font-semibold uppercase tracking-wider text-muted-on-light">
            <Banknote size={14} aria-hidden />
            <span>{t("dayClose.bills")}</span>
          </h4>
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
            {bills.map((d) => {
              const qty = counts[d.id] ?? "";
              const lineTotal = (counts[d.id] ?? 0) * d.value;
              return (
                <div
                  key={d.id}
                  className="rounded-md border border-slate-200 bg-white p-2 text-sm"
                >
                  <div className="flex items-center justify-between font-semibold text-slate-700">
                    <span>₱{d.label}</span>
                    <span className="text-xs text-slate-500 font-normal">
                      {lineTotal > 0 ? fmt(lineTotal) : "—"}
                    </span>
                  </div>
                  <Input
                    type="number"
                    min="0"
                    step="1"
                    placeholder="0"
                    value={qty}
                    onChange={(e) => handleCountChange(d.id, e.target.value)}
                    className="mt-1 text-right font-mono"
                    data-testid={`denom-input-${d.id}`}
                  />
                </div>
              );
            })}
          </div>
        </div>

        {/* Coins Section */}
        <div className="grid gap-2">
          <h4 className="flex items-center gap-1.5 font-mono text-xs font-semibold uppercase tracking-wider text-muted-on-light">
            <Coins size={14} aria-hidden />
            <span>{t("dayClose.coins")}</span>
          </h4>
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
            {coins.map((d) => {
              const qty = counts[d.id] ?? "";
              const lineTotal = (counts[d.id] ?? 0) * d.value;
              return (
                <div
                  key={d.id}
                  className="rounded-md border border-slate-200 bg-white p-2 text-sm"
                >
                  <div className="flex items-center justify-between font-semibold text-slate-700">
                    <span>₱{d.label}</span>
                    <span className="text-xs text-slate-500 font-normal">
                      {lineTotal > 0 ? fmt(lineTotal) : "—"}
                    </span>
                  </div>
                  <Input
                    type="number"
                    min="0"
                    step="1"
                    placeholder="0"
                    value={qty}
                    onChange={(e) => handleCountChange(d.id, e.target.value)}
                    className="mt-1 text-right font-mono"
                    data-testid={`denom-input-${d.id}`}
                  />
                </div>
              );
            })}
          </div>
        </div>

        {/* Footer Actions */}
        <div className="flex justify-end gap-2 pt-2 border-t border-slate-100">
          <Button variant="ghost" onClick={onClose}>
            {t("common:actions.cancel")}
          </Button>
          <Button
            data-testid="denom-apply-btn"
            onClick={handleApply}
            disabled={total <= 0}
          >
            {t("dayClose.applyCount")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}
