import { useTranslation } from "react-i18next";
import { formatMoney, money } from "@pos/core";
import { Badge, Button, Dialog } from "./ui.tsx";
import { downloadCsv, exportCustomerLedgerCsv } from "../lib/csv-helper.ts";
import type { LedgerEntry } from "../lib/utang-api.ts";

export interface StatementCustomer {
  customerId: string;
  name: string;
  phone: string | null;
  dueOn: string | null;
  balance: number;
}

export function CustomerStatementDialog({
  open,
  onClose,
  customer,
  entries,
  currency,
  tenantName,
  storeName,
  preparedBy,
  today,
}: {
  open: boolean;
  onClose: () => void;
  customer: StatementCustomer | null;
  entries: LedgerEntry[];
  currency: string;
  tenantName: string;
  storeName: string;
  preparedBy: string;
  today: string;
}) {
  const { t, i18n } = useTranslation(["admin", "common"]);

  if (!customer) return null;

  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);

  // Compute breakdown totals
  let totalPurchases = 0;
  let totalPayments = 0;
  let totalAdjustments = 0;

  for (const entry of entries) {
    if (entry.kind === "charge") {
      totalPurchases += entry.amount;
    } else if (entry.kind === "payment") {
      totalPayments += Math.abs(entry.amount);
    } else if (entry.kind === "adjust") {
      totalAdjustments += entry.amount;
    }
  }

  // Calculate overdue days
  let isOverdue = false;
  let overdueDays = 0;
  if (customer.dueOn && customer.balance > 0 && customer.dueOn < today) {
    isOverdue = true;
    const dueTime = new Date(customer.dueOn).getTime();
    const todayTime = new Date(today).getTime();
    overdueDays = Math.max(1, Math.round((todayTime - dueTime) / (1000 * 60 * 60 * 24)));
  }

  const handleExportCsv = () => {
    const csv = exportCustomerLedgerCsv(
      customer.name,
      entries.map((e) => ({
        date: e.occurred_at.slice(0, 10),
        kind: t(`utang.kind.${e.kind}`),
        description: e.note ?? (e.kind === "charge" ? t("utang.kind.charge") : t(`utang.kind.${e.kind}`)),
        method: e.method ?? undefined,
        amount: e.amount,
      })),
      currency
    );
    const dateStr = new Date().toISOString().slice(0, 10);
    downloadCsv(csv, `statement-${customer.name.toLowerCase().replace(/\s+/g, "_")}-${dateStr}.csv`);
  };

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => !o && onClose()}
      title={t("utang.statementTitle")}
      closeLabel={t("common:actions.close")}
    >
      <div className="grid gap-4 py-2">
        {/* Printable Statement Document */}
        <div className="printable-statement bg-white p-4 rounded-md border border-slate-200 text-slate-900">
          {/* Header */}
          <div className="flex justify-between items-start border-b border-slate-300 pb-3 mb-3">
            <div>
              <h2 className="text-lg font-bold text-slate-900 uppercase tracking-wide">{tenantName}</h2>
              <p className="text-xs text-slate-600 font-medium">{storeName}</p>
            </div>
            <div className="text-right">
              <span className="inline-block text-xs font-bold uppercase tracking-wider text-brand-700 bg-brand-50 px-2 py-0.5 rounded">
                {t("utang.statement")}
              </span>
              <p className="text-xs text-slate-500 mt-1">
                {t("utang.statementDate")}: {new Date().toLocaleDateString(i18n.language)}
              </p>
            </div>
          </div>

          {/* Customer & Account Details */}
          <div className="grid grid-cols-2 gap-4 bg-slate-50 p-3 rounded border border-slate-200 mb-3 text-xs">
            <div>
              <p className="text-slate-500 font-medium">{t("sell.customer")}</p>
              <p className="text-sm font-bold text-slate-900">{customer.name}</p>
              {customer.phone ? <p className="text-slate-600">{customer.phone}</p> : null}
            </div>
            <div className="text-right">
              <p className="text-slate-500 font-medium">{t("utang.totalOutstanding")}</p>
              <p className="text-base font-bold text-amber-900">{fmt(customer.balance)}</p>
              <div className="mt-1 flex items-center justify-end gap-1.5">
                {customer.dueOn ? (
                  <span className="text-slate-600">
                    {t("utang.promisedPayDate")}: <strong>{customer.dueOn}</strong>
                  </span>
                ) : null}
                {isOverdue ? (
                  <Badge tone="danger">{t("utang.overdue", { days: overdueDays })}</Badge>
                ) : (
                  <Badge tone={customer.balance > 0 ? "warn" : "good"}>{t("utang.current")}</Badge>
                )}
              </div>
            </div>
          </div>

          {/* Breakdown summary */}
          <div className="grid grid-cols-3 gap-2 py-2 border-y border-slate-200 text-center mb-3 text-xs">
            <div>
              <p className="text-slate-500">{t("utang.charges")}</p>
              <p className="font-semibold text-slate-800">{fmt(totalPurchases)}</p>
            </div>
            <div>
              <p className="text-slate-500">{t("utang.paymentsTotal")}</p>
              <p className="font-semibold text-emerald-700">-{fmt(totalPayments)}</p>
            </div>
            <div>
              <p className="text-slate-500">{t("utang.adjustmentsTotal")}</p>
              <p className={`font-semibold ${totalAdjustments < 0 ? "text-emerald-700" : "text-slate-800"}`}>
                {totalAdjustments !== 0 ? fmt(totalAdjustments) : "₱0.00"}
              </p>
            </div>
          </div>

          {/* Transaction Ledger Table */}
          <div className="mb-4">
            <h4 className="text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
              {t("utang.ledgerTransactions")}
            </h4>
            <div className="border border-slate-200 rounded overflow-hidden">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="bg-slate-100 border-b border-slate-200 text-slate-600 font-semibold">
                    <th className="py-1.5 px-2">{t("purchasing.receipts.date")}</th>
                    <th className="py-1.5 px-2">{t("expenses.category")}</th>
                    <th className="py-1.5 px-2">{t("expenses.note")}</th>
                    <th className="py-1.5 px-2 text-right">{t("expenses.amount")}</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {entries.length === 0 ? (
                    <tr>
                      <td colSpan={4} className="py-3 text-center text-slate-400">
                        {t("utang.noHistory")}
                      </td>
                    </tr>
                  ) : (
                    entries.map((entry) => (
                      <tr key={entry.id} className="text-slate-700">
                        <td className="py-1.5 px-2 whitespace-nowrap">{entry.occurred_at.slice(0, 10)}</td>
                        <td className="py-1.5 px-2 font-medium">
                          {t(`utang.kind.${entry.kind}`)}
                          {entry.method ? ` (${entry.method})` : ""}
                        </td>
                        <td className="py-1.5 px-2 text-slate-500">{entry.note || "—"}</td>
                        <td
                          className={`py-1.5 px-2 text-right font-mono font-semibold ${
                            entry.amount > 0 ? "text-amber-800" : "text-emerald-700"
                          }`}
                        >
                          {entry.amount > 0 ? `+${fmt(entry.amount)}` : fmt(entry.amount)}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Acknowledgment & Signatures */}
          <div className="grid grid-cols-2 gap-8 pt-4 border-t border-slate-200 text-xs text-slate-600">
            <div>
              <p className="text-slate-500">{t("utang.preparedBy")}:</p>
              <p className="font-semibold text-slate-800 mt-0.5">{preparedBy}</p>
            </div>
            <div className="text-right">
              <p className="text-slate-500 mb-6">{t("utang.customerSignature")}:</p>
              <div className="border-b border-slate-400 inline-block w-48 text-center text-[10px] text-slate-400">
                (Signature over printed name)
              </div>
            </div>
          </div>

          {/* Footer note */}
          <p className="text-[10px] text-slate-400 text-center mt-4">
            {t("utang.statementFooter")}
          </p>
        </div>

        {/* Dialog Actions (Excluded from print) */}
        <div className="flex justify-between items-center border-t border-slate-100 pt-3 no-print">
          <Button variant="outline" onClick={handleExportCsv} data-testid="soa-download-csv">
            📥 {t("utang.downloadCsv")}
          </Button>

          <div className="flex gap-2">
            <Button variant="outline" onClick={onClose}>
              {t("common:actions.close")}
            </Button>
            <Button data-testid="soa-print-btn" onClick={() => window.print()}>
              🖨️ {t("utang.printStatement")}
            </Button>
          </div>
        </div>
      </div>
    </Dialog>
  );
}
