import { useTranslation } from "react-i18next";
import { formatMoney, money } from "@pos/core";
import { Button, Dialog } from "./ui.tsx";

export interface ReceiptItem {
  product_name: string;
  qty: number;
  unit_price: number;
  discount?: number;
  line_total: number;
}

export interface ReceiptPayment {
  method: string;
  amount: number;
  wallet?: string | null;
  reference?: string | null;
}

export interface ReceiptData {
  tenantName: string;
  storeName: string;
  storeCode?: string;
  storeAddress?: string;
  receiptNo: string;
  soldAt: string | Date;
  cashierName?: string;
  customerName?: string | null;
  items: ReceiptItem[];
  subtotal: number;
  discount: number;
  total: number;
  payments: ReceiptPayment[];
  change?: number;
  onUtang?: number;
  currency: string;
  timezone?: string;
  isVoided?: boolean;
}

export function ReceiptSlipView({ receipt }: { receipt: ReceiptData }) {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const fmt = (n: number) => formatMoney(money(n, receipt.currency), i18n.language);
  const formattedDate = new Intl.DateTimeFormat(i18n.language, {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: receipt.timezone || "Asia/Manila",
  }).format(new Date(receipt.soldAt));

  return (
    <div className="printable-slip text-xs font-mono text-slate-900 bg-white p-4 max-w-sm mx-auto border border-dashed border-slate-300 rounded shadow-sm print:border-none print:shadow-none print:p-0 print:max-w-none">
      {/* Header */}
      <div className="text-center border-b border-dashed border-slate-300 pb-2 mb-2">
        <h3 className="font-bold text-sm tracking-wide uppercase">{receipt.tenantName}</h3>
        <p className="text-xs text-slate-600">
          {receipt.storeName} {receipt.storeCode ? `(${receipt.storeCode})` : ""}
        </p>
        {receipt.storeAddress ? <p className="text-[10px] text-slate-500">{receipt.storeAddress}</p> : null}
        {receipt.isVoided ? (
          <div className="my-1.5 inline-block rounded bg-red-100 text-red-800 px-2 py-0.5 text-[11px] font-bold tracking-wider">
            *** {t("sales.status.voided").toUpperCase()} ***
          </div>
        ) : null}
      </div>

      {/* Meta info */}
      <div className="space-y-0.5 border-b border-dashed border-slate-300 pb-2 mb-2 text-[11px]">
        <div className="flex justify-between">
          <span className="text-slate-500">{t("sell.receiptNo")}:</span>
          <span className="font-bold">{receipt.receiptNo}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-slate-500">{t("purchasing.receipts.date")}:</span>
          <span>{formattedDate}</span>
        </div>
        {receipt.cashierName ? (
          <div className="flex justify-between">
            <span className="text-slate-500">{t("dayClose.cashier")}:</span>
            <span>{receipt.cashierName}</span>
          </div>
        ) : null}
        {receipt.customerName ? (
          <div className="flex justify-between">
            <span className="text-slate-500">{t("sell.customer")}:</span>
            <span className="font-medium">{receipt.customerName}</span>
          </div>
        ) : null}
      </div>

      {/* Line Items */}
      <div className="border-b border-dashed border-slate-300 pb-2 mb-2">
        <div className="flex justify-between text-[11px] text-slate-500 font-semibold mb-1">
          <span>{t("products.name")}</span>
          <span>{t("sell.subtotal")}</span>
        </div>
        <div className="space-y-1.5">
          {receipt.items.map((item, idx) => (
            <div key={idx} className="text-[11px]">
              <div className="flex justify-between items-start">
                <span className="font-medium pr-2">{item.product_name}</span>
                <span className="font-semibold whitespace-nowrap">{fmt(item.line_total)}</span>
              </div>
              <div className="flex justify-between text-[10px] text-slate-500">
                <span>
                  {item.qty} × {fmt(item.unit_price)}
                </span>
                {item.discount && item.discount > 0 ? (
                  <span className="text-emerald-700">-{fmt(item.discount)}</span>
                ) : null}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Totals */}
      <div className="space-y-1 border-b border-dashed border-slate-300 pb-2 mb-2 text-[11px]">
        <div className="flex justify-between">
          <span>{t("sell.subtotal")}</span>
          <span>{fmt(receipt.subtotal)}</span>
        </div>
        {receipt.discount > 0 ? (
          <div className="flex justify-between text-emerald-700">
            <span>{t("sell.discount")}</span>
            <span>-{fmt(receipt.discount)}</span>
          </div>
        ) : null}
        <div className="flex justify-between text-sm font-bold pt-1 border-t border-slate-200">
          <span>{t("sell.total")}</span>
          <span>{fmt(receipt.total)}</span>
        </div>
      </div>

      {/* Payments */}
      <div className="space-y-1 border-b border-dashed border-slate-300 pb-2 mb-2 text-[11px]">
        {receipt.payments.map((p, idx) => (
          <div key={idx} className="flex justify-between">
            <span className="text-slate-600">
              {p.method === "ewallet" && p.wallet
                ? `${t("sell.ewallet")} (${t(`sell.wallets.${p.wallet as "gcash" | "maya" | "other"}`)})`
                : p.method === "card"
                  ? `${t("sell.card")}${p.reference ? ` (${p.reference})` : ""}`
                  : t(`sell.${p.method as "cash" | "ewallet" | "card" | "utang"}`)}
            </span>
            <span className="font-medium">{fmt(p.amount)}</span>
          </div>
        ))}
        {typeof receipt.change === "number" && receipt.change > 0 ? (
          <div className="flex justify-between text-slate-500 pt-0.5">
            <span>{t("sell.change")}</span>
            <span>{fmt(receipt.change)}</span>
          </div>
        ) : null}
        {typeof receipt.onUtang === "number" && receipt.onUtang > 0 ? (
          <div className="flex justify-between text-amber-800 font-medium pt-0.5">
            <span>{t("sell.onUtang")}</span>
            <span>{fmt(receipt.onUtang)}</span>
          </div>
        ) : null}
      </div>

      {/* Footer */}
      <div className="text-center pt-1 text-[10px] text-slate-500">
        <p>{t("sell.thankYou") || "Thank you for your purchase!"}</p>
      </div>
    </div>
  );
}

export function ReceiptModal({
  open,
  onClose,
  receipt,
}: {
  open: boolean;
  onClose: () => void;
  receipt: ReceiptData | null;
}) {
  const { t } = useTranslation(["admin", "common"]);

  if (!receipt) return null;

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()} title={t("sell.receiptNo")} closeLabel={t("common:actions.close")}>
      <div className="grid gap-4 py-2">
        <ReceiptSlipView receipt={receipt} />

        <div className="flex justify-end gap-2 border-t border-slate-100 pt-3 no-print">
          <Button variant="outline" onClick={onClose}>
            {t("common:actions.close")}
          </Button>
          <Button data-testid="print-receipt-btn" onClick={() => window.print()}>
            🖨️ {t("sell.printReceipt") || "Print Receipt"}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}
