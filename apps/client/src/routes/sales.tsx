import { useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Alert, Badge, Button, Card, EmptyState, ErrorState, Input, PageHeader, useToast } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { ApiError } from "../lib/api.ts";
import { supabase } from "../lib/supabase.ts";
import { fetchRecentSales, fetchSaleDetail, voidSale } from "../lib/sell-api.ts";
import { SupervisorPinDialog } from "../components/supervisor-pin-dialog.tsx";
import { ReceiptModal } from "../components/receipt-slip.tsx";
import type { OfflineApprovalPayload } from "../lib/offline-pin-api.ts";

/** Sales (Solo web): the store's latest sales, each as a receipt, with cancel (void) for those allowed to. */
export function SalesPage() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const toast = useToast();
  const { access, can } = useSession();
  const qc = useQueryClient();
  const currency = access.tenant.base_currency;
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);
  const when = (iso: string) =>
    new Intl.DateTimeFormat(i18n.language, { dateStyle: "medium", timeStyle: "short", timeZone: access.tenant.timezone }).format(new Date(iso));

  const { activeStore } = useActiveLocation();
  const store = (activeStore && can("sale.create", activeStore.id)) ? activeStore : access.locations.find((l) => l.type === "store" && can("sale.create", l.id));
  const [openId, setOpenId] = useState<string | null>(null);
  const [asking, setAsking] = useState(false);
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [showApprovalDialog, setShowApprovalDialog] = useState(false);
  const [showReceiptModal, setShowReceiptModal] = useState(false);
  const [approvalId, setApprovalId] = useState<string | null>(null);
  const [offlineApproval, setOfflineApproval] = useState<OfflineApprovalPayload | null>(null);

  const list = useQuery({
    queryKey: ["sales", store?.id],
    queryFn: () => fetchRecentSales(store?.id ?? ""),
    enabled: Boolean(store),
    refetchInterval: 120_000,
  });
  const detail = useQuery({ queryKey: ["sale", openId], queryFn: () => fetchSaleDetail(openId ?? ""), enabled: openId !== null });

  const settingsQuery = useQuery({
    queryKey: ["tenant-settings-controls"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("tenant_settings")
        .select("max_cashier_void_amount, cashier_can_void_own")
        .single();
      if (error) return null;
      return data;
    },
    staleTime: 60_000,
  });

  const maxVoidAmt = settingsQuery.data?.max_cashier_void_amount ?? 50000;
  const canVoidOwn = Boolean(settingsQuery.data?.cashier_can_void_own);
  const isCashier = access.role === "cashier";
  const needsSupervisor = isCashier && (!canVoidOwn || (detail.data?.sale.total ?? 0) > maxVoidAmt);

  const cancel = useMutation({
    mutationFn: (override?: { approvalId?: string; offlineApproval?: OfflineApprovalPayload }) =>
      voidSale(
        openId ?? "",
        reason,
        override?.approvalId ?? approvalId ?? undefined,
        override?.offlineApproval ?? offlineApproval ?? undefined,
      ),
    onSuccess: async () => {
      setAsking(false);
      setReason("");
      setError(null);
      setApprovalId(null);
      setOfflineApproval(null);
      setShowApprovalDialog(false);
      toast.good(t("sales.status.voided"));
      await Promise.all([
        qc.invalidateQueries({ queryKey: ["sales"] }),
        qc.invalidateQueries({ queryKey: ["sale", openId] }),
        qc.invalidateQueries({ queryKey: ["day-summary"] }),
      ]);
    },
    onError: (e) => {
      if (e instanceof ApiError && e.key === "approval_required") {
        setShowApprovalDialog(true);
        return;
      }
      const err = msg(e);
      setError(err);
      toast.error(err);
    },
  });

  function handleConfirmVoid() {
    if (needsSupervisor && !approvalId && !offlineApproval) {
      setShowApprovalDialog(true);
      return;
    }
    cancel.mutate();
  }

  if (!store) {
    return (
      <EmptyState title={t("sell.noStore")} />
    );
  }

  if (openId !== null) {
    const d = detail.data;
    return (
      <div className="grid max-w-xl gap-3">
        <div>
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              setOpenId(null);
              setAsking(false);
              setError(null);
            }}
          >
            {t("sales.back")}
          </Button>
        </div>
        {detail.isPending ? (
          <Card className="grid gap-3">
            <div className="h-6 w-32 rounded bg-slate-200 animate-pulse" />
            <div className="h-4 w-48 rounded bg-slate-200 animate-pulse" />
            <div className="space-y-2 pt-2">
              <div className="h-4 w-full rounded bg-slate-200 animate-pulse" />
              <div className="h-4 w-full rounded bg-slate-200 animate-pulse" />
            </div>
          </Card>
        ) : null}
        {detail.isError ? (
          <ErrorState message={t("sales.error")} onRetry={() => void detail.refetch()} retryLabel={t("common:actions.retry")} />
        ) : null}
        {d ? (
          <Card className="grid gap-3" data-testid="sale-detail">
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="font-mono text-lg font-semibold">{d.sale.sale_no ?? d.sale.local_no}</h2>
              <Badge tone={d.sale.status === "voided" ? "warn" : "good"}>{t(`sales.status.${d.sale.status}`)}</Badge>
              <span className="ml-auto text-sm text-slate-500">{when(d.sale.sold_at)}</span>
            </div>
            {d.customerName ? (
              <div className="text-sm">
                <span className="text-slate-500">{t("sell.customer")}</span>{" "}
                <span className="font-semibold text-slate-900">{d.customerName}</span>
              </div>
            ) : null}
            <ul className="grid gap-1 text-sm">
              {d.items.map((i, k) => (
                <li key={k} className="flex justify-between gap-2">
                  <span>
                    {i.product_name} × {i.qty}
                  </span>
                  <span>{fmt(i.line_total)}</span>
                </li>
              ))}
            </ul>
            <div className="grid gap-1 border-t border-slate-200 pt-2 text-sm">
              <div className="flex justify-between">
                <span>{t("sell.subtotal")}</span>
                <span>{fmt(d.sale.subtotal)}</span>
              </div>
              {d.sale.discount > 0 ? (
                <div className="flex justify-between">
                  <span>{t("sell.discount")}</span>
                  <span>-{fmt(d.sale.discount)}</span>
                </div>
              ) : null}
              <div className="flex justify-between text-base font-semibold">
                <span>{t("sell.total")}</span>
                <span>{fmt(d.sale.total)}</span>
              </div>
              {d.payments.map((p, k) => (
                <div key={k} className="flex justify-between text-slate-600">
                  <span>
                    {p.method === "ewallet" && p.wallet
                      ? `${t("sell.ewallet")} (${t(`sell.wallets.${p.wallet as "gcash" | "maya" | "other"}`)})`
                      : p.method === "card"
                        ? `${t("sell.card")}${p.reference ? ` (${p.reference})` : ""}`
                        : t(`sell.${p.method as "cash" | "ewallet" | "card" | "utang"}`)}
                  </span>
                  <span>{fmt(p.amount)}</span>
                </div>
              ))}
            </div>

            <div className="flex flex-wrap items-center gap-2 pt-2 border-t border-slate-100 no-print">
              <Button
                variant="outline"
                data-testid="print-receipt-btn"
                onClick={() => setShowReceiptModal(true)}
              >
                🖨️ {t("sales.printReceipt")}
              </Button>

              {d.sale.status === "completed" && can("sale.void", d.sale.location_id) ? (
                asking ? (
                  <div className="grid gap-2 w-full rounded-md border border-red-200 p-3 mt-2">
                    <p className="text-sm">{t("sales.voidWarning")}</p>
                    <Input data-testid="void-reason" placeholder={t("sales.reason")} value={reason} maxLength={200} onChange={(e) => setReason(e.target.value)} />
                    {error ? <Alert>{error}</Alert> : null}
                    <div className="flex gap-2">
                      <Button variant="danger" data-testid="void-confirm" disabled={cancel.isPending} onClick={handleConfirmVoid}>
                        {t("sales.confirmVoid")}
                      </Button>
                      <Button variant="ghost" onClick={() => setAsking(false)}>
                        {t("sell.cancel")}
                      </Button>
                    </div>
                  </div>
                ) : (
                  <Button variant="outline" data-testid="void-start" onClick={() => setAsking(true)}>
                    {t("sales.voidSale")}
                  </Button>
                )
              ) : null}
            </div>
          </Card>
        ) : null}

        {d ? (
          <ReceiptModal
            open={showReceiptModal}
            onClose={() => setShowReceiptModal(false)}
            receipt={{
              tenantName: access.tenant.name,
              storeName: store?.name ?? "",
              storeCode: store?.code ?? "",
              receiptNo: d.sale.sale_no ?? d.sale.local_no,
              soldAt: d.sale.sold_at,
              cashierName: access.full_name || access.username,
              customerName: d.customerName,
              items: d.items.map((i) => ({
                product_name: i.product_name,
                qty: i.qty,
                unit_price: i.unit_price,
                line_total: i.line_total,
              })),
              subtotal: d.sale.subtotal,
              discount: d.sale.discount,
              total: d.sale.total,
              payments: d.payments,
              currency,
              timezone: access.tenant.timezone,
              isVoided: d.sale.status === "voided",
            }}
          />
        ) : null}

        <SupervisorPinDialog
          open={showApprovalDialog}
          onOpenChange={setShowApprovalDialog}
          locationId={detail.data?.sale.location_id ?? store?.id ?? ""}
          action="void_sale"
          refId={openId ?? ""}
          onApproved={(apprId, offlineAppr) => {
            setApprovalId(apprId || null);
            setOfflineApproval(offlineAppr || null);
            cancel.mutate({ approvalId: apprId || undefined, offlineApproval: offlineAppr || undefined });
          }}
        />
      </div>
    );
  }

  return (
    <div className="grid max-w-2xl gap-4">
      <PageHeader title={t("sales.title")} />
      {list.isPending ? (
        <ul className="grid gap-2">
          {Array.from({ length: 5 }).map((_, i) => (
            <li key={i} className="h-14 rounded-md border border-slate-200 bg-slate-100 animate-pulse" />
          ))}
        </ul>
      ) : null}
      {list.isError ? (
        <ErrorState message={t("sales.error")} onRetry={() => void list.refetch()} retryLabel={t("common:actions.retry")} />
      ) : null}
      {list.data && list.data.length === 0 ? <EmptyState title={t("sales.empty")} /> : null}
      <ul className="grid gap-2">
        {(list.data ?? []).map((s) => (
          <li key={s.id}>
            <button
              type="button"
              data-testid={`sale-${s.sale_no ?? s.local_no}`}
              onClick={() => setOpenId(s.id)}
              className="flex w-full items-center justify-between gap-2 rounded-md border border-slate-200 bg-white px-3 py-2 text-left text-sm hover:bg-slate-50 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-600/20"
            >
              <span>
                <span className="block font-mono font-semibold">{s.sale_no ?? s.local_no}</span>
                <span className="text-xs text-slate-500">{when(s.sold_at)}</span>
              </span>
              <span className="flex items-center gap-2">
                {s.status === "voided" ? <Badge tone="warn">{t("sales.status.voided")}</Badge> : null}
                <span className="font-semibold">{fmt(s.total)}</span>
              </span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
