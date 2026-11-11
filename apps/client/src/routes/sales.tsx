import { useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Alert, Badge, Button, Card, Dialog, EmptyState, ErrorState, Field, Input, PageHeader, Select, useToast } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { ApiError } from "../lib/api.ts";
import { supabase } from "../lib/supabase.ts";
import { computePartialReturnRefund } from "../lib/sale-math.ts";
import { fetchRecentSales, fetchSaleDetail, returnSaleItems, voidSale } from "../lib/sell-api.ts";
import { SupervisorPinDialog } from "../components/supervisor-pin-dialog.tsx";
import { ReceiptModal } from "../components/receipt-slip.tsx";
import type { OfflineApprovalPayload } from "../lib/offline-pin-api.ts";

type RefundMethod = "cash" | "utang" | "ewallet" | "card";

/** Sales (Solo web): the store's latest sales, each as a receipt, with partial item returns and cancel (void). */
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

  // Partial Return Dialog state
  const [showReturnDialog, setShowReturnDialog] = useState(false);
  const [returnQtys, setReturnQtys] = useState<Record<string, number>>({});
  const [refundMethod, setRefundMethod] = useState<RefundMethod>("cash");
  const [returnReason, setReturnReason] = useState("");
  const [returnError, setReturnError] = useState<string | null>(null);

  // Supervisor approval escalation (shared across void & partial return)
  const [pendingAction, setPendingAction] = useState<"void" | "return">("void");
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
  const needsSupervisorVoid = isCashier && (!canVoidOwn || (detail.data?.sale.total ?? 0) > maxVoidAmt);

  const alreadyRefundedTotal = (detail.data?.returns ?? []).reduce((sum, r) => sum + r.refund_total, 0);
  const estimatedRefund = detail.data
    ? computePartialReturnRefund({
        saleSubtotal: detail.data.sale.subtotal,
        saleDiscount: detail.data.sale.discount,
        saleTotal: detail.data.sale.total,
        alreadyRefundedTotal,
        items: detail.data.items.map((it) => ({
          variantId: it.variant_id,
          soldQty: it.qty,
          alreadyReturnedQty: it.returned_qty,
          lineTotal: it.line_total,
          returnQty: returnQtys[it.id] ?? 0,
        })),
      })
    : 0;
  const needsSupervisorReturn = isCashier && (!canVoidOwn || estimatedRefund > maxVoidAmt);

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
        setPendingAction("void");
        setShowApprovalDialog(true);
        return;
      }
      const err = msg(e);
      setError(err);
      toast.error(err);
    },
  });

  const submitReturn = useMutation({
    mutationFn: async (override?: { approvalId?: string; offlineApproval?: OfflineApprovalPayload }) => {
      const d = detail.data;
      if (!d || !openId) throw new Error("sale_not_found");
      // Aggregate by variant_id
      const byVariant = new Map<string, number>();
      for (const it of d.items) {
        const q = returnQtys[it.id] ?? 0;
        if (q > 0) {
          byVariant.set(it.variant_id, (byVariant.get(it.variant_id) ?? 0) + q);
        }
      }
      const payloadItems = Array.from(byVariant.entries()).map(([variant_id, qty]) => ({
        variant_id,
        qty,
      }));
      return await returnSaleItems({
        saleId: openId,
        refundMethod,
        items: payloadItems,
        reason: returnReason,
        approvalId: override?.approvalId ?? approvalId ?? undefined,
        offlineApproval: override?.offlineApproval ?? offlineApproval ?? undefined,
      });
    },
    onSuccess: async (res) => {
      setShowReturnDialog(false);
      setReturnQtys({});
      setReturnReason("");
      setReturnError(null);
      setApprovalId(null);
      setOfflineApproval(null);
      setShowApprovalDialog(false);
      toast.good(t("sales.return.success", { amount: fmt(res.refund_total) }));
      await Promise.all([
        qc.invalidateQueries({ queryKey: ["sales"] }),
        qc.invalidateQueries({ queryKey: ["sale", openId] }),
        qc.invalidateQueries({ queryKey: ["products"] }),
        qc.invalidateQueries({ queryKey: ["sellables"] }),
        qc.invalidateQueries({ queryKey: ["customers"] }),
        qc.invalidateQueries({ queryKey: ["day-summary"] }),
      ]);
    },
    onError: (e) => {
      if (e instanceof ApiError && e.key === "approval_required") {
        setPendingAction("return");
        setShowApprovalDialog(true);
        return;
      }
      const err = msg(e);
      setReturnError(err);
      toast.error(err);
    },
  });

  function handleConfirmVoid() {
    if (needsSupervisorVoid && !approvalId && !offlineApproval) {
      setPendingAction("void");
      setShowApprovalDialog(true);
      return;
    }
    cancel.mutate(undefined);
  }

  function handleConfirmReturn() {
    if (needsSupervisorReturn && !approvalId && !offlineApproval) {
      setPendingAction("return");
      setShowApprovalDialog(true);
      return;
    }
    submitReturn.mutate(undefined);
  }

  function openReturnModal() {
    const d = detail.data;
    if (!d) return;
    setReturnQtys({});
    const defaultMethod = (d.payments[0]?.method as RefundMethod | undefined) ?? "cash";
    setRefundMethod(
      defaultMethod === "utang" && !d.sale.customer_id ? "cash" : defaultMethod,
    );
    setReturnReason("");
    setReturnError(null);
    setShowReturnDialog(true);
  }

  if (!store) {
    return (
      <EmptyState title={t("sell.noStore")} />
    );
  }

  if (openId !== null) {
    const d = detail.data;
    const hasRemainingItems = Boolean(
      d?.items.some((it) => it.qty - it.returned_qty > 0),
    );
    const hasAnyReturn = (d?.returns.length ?? 0) > 0;
    const totalSelectedToReturn = Object.values(returnQtys).reduce((s, q) => s + q, 0);

    return (
      <div className="grid max-w-xl gap-4">
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
            <div className="h-6 w-32 rounded-[6px] bg-slate-200 animate-pulse" />
            <div className="h-4 w-48 rounded-[6px] bg-slate-200 animate-pulse" />
            <div className="space-y-2 pt-2">
              <div className="h-4 w-full rounded-[6px] bg-slate-200 animate-pulse" />
              <div className="h-4 w-full rounded-[6px] bg-slate-200 animate-pulse" />
            </div>
          </Card>
        ) : null}
        {detail.isError ? (
          <ErrorState message={t("sales.error")} onRetry={() => void detail.refetch()} retryLabel={t("common:actions.retry")} />
        ) : null}
        {d ? (
          <Card className="grid gap-4 p-6" data-testid="sale-detail">
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="font-mono text-lg font-semibold text-slate-900">{d.sale.sale_no ?? d.sale.local_no}</h2>
              <Badge tone={d.sale.status === "voided" ? "warn" : "good"}>{t(`sales.status.${d.sale.status}`)}</Badge>
              {hasAnyReturn && d.sale.status === "completed" ? (
                <Badge tone="neutral">
                  {hasRemainingItems
                    ? t("sales.return.badgePartial", "Partially Returned")
                    : t("sales.return.badgeFull", "All Items Returned")}
                </Badge>
              ) : null}
              <span className="ml-auto text-sm text-slate-500">{when(d.sale.sold_at)}</span>
            </div>
            {d.customerName ? (
              <div className="text-sm">
                <span className="text-slate-500">{t("sell.customer")}</span>{" "}
                <span className="font-semibold text-slate-900">{d.customerName}</span>
              </div>
            ) : null}
            <ul className="grid gap-2 text-sm">
              {d.items.map((i) => (
                <li key={i.id} className="flex items-baseline justify-between gap-2">
                  <div>
                    <span className="text-slate-900">
                      {i.product_name} × {i.qty}
                    </span>
                    {i.returned_qty > 0 ? (
                      <span className="ml-2 text-xs font-semibold text-amber-700 bg-amber-50 border border-amber-200 rounded-[6px] px-1.5 py-0.5 tabular-nums">
                        {t("sales.return.returnedQty", { qty: i.returned_qty, defaultValue: "{{qty}} returned" })}
                      </span>
                    ) : null}
                  </div>
                  <span className="tabular-nums text-slate-900">{fmt(i.line_total)}</span>
                </li>
              ))}
            </ul>
            <div className="grid gap-1 border-t border-slate-200 pt-3 text-sm">
              <div className="flex justify-between">
                <span className="text-slate-600">{t("sell.subtotal")}</span>
                <span className="tabular-nums">{fmt(d.sale.subtotal)}</span>
              </div>
              {d.sale.discount > 0 ? (
                <div className="flex justify-between">
                  <span className="text-slate-600">{t("sell.discount")}</span>
                  <span className="tabular-nums">-{fmt(d.sale.discount)}</span>
                </div>
              ) : null}
              <div className="flex justify-between text-base font-semibold text-slate-900">
                <span>{t("sell.total")}</span>
                <span className="tabular-nums">{fmt(d.sale.total)}</span>
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
                  <span className="tabular-nums">{fmt(p.amount)}</span>
                </div>
              ))}
              {alreadyRefundedTotal > 0 ? (
                <div className="flex justify-between pt-1 font-semibold text-amber-700">
                  <span>{t("sales.return.refundedTotal", "Refunded")}</span>
                  <span className="tabular-nums">-{fmt(alreadyRefundedTotal)}</span>
                </div>
              ) : null}
            </div>

            {d.returns.length > 0 ? (
              <div className="rounded-[10px] bg-slate-50 p-3 grid gap-2 text-xs">
                <div className="font-semibold uppercase tracking-wider text-slate-500">
                  {t("sales.return.historyTitle", "Return History")}
                </div>
                {d.returns.map((r) => (
                  <div key={r.id} className="flex items-baseline justify-between gap-2 text-slate-700">
                    <span>
                      {when(r.returned_at)} · {t(`sell.${r.refund_method}`)}
                      {r.reason ? ` — ${r.reason}` : ""}
                    </span>
                    <span className="font-semibold tabular-nums">-{fmt(r.refund_total)}</span>
                  </div>
                ))}
              </div>
            ) : null}

            <div className="flex flex-wrap items-center gap-2 pt-2 border-t border-slate-100 no-print">
              <Button
                variant="outline"
                data-testid="print-receipt-btn"
                onClick={() => setShowReceiptModal(true)}
              >
                {t("sales.printReceipt")}
              </Button>

              {d.sale.status === "completed" && can("sale.void", d.sale.location_id) && hasRemainingItems ? (
                <Button
                  variant="outline"
                  data-testid="return-items-btn"
                  onClick={openReturnModal}
                >
                  {t("sales.return.action", "Return Items")}
                </Button>
              ) : null}

              {d.sale.status === "completed" && can("sale.void", d.sale.location_id) && !hasAnyReturn ? (
                asking ? (
                  <div className="grid gap-3 w-full rounded-[10px] bg-red-50 p-4 mt-2">
                    <p className="text-sm text-red-900">{t("sales.voidWarning")}</p>
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
                  <Button variant="ghost" data-testid="void-start" onClick={() => setAsking(true)}>
                    {t("sales.voidSale")}
                  </Button>
                )
              ) : null}
            </div>
          </Card>
        ) : null}

        {d ? (
          <Dialog
            open={showReturnDialog}
            onOpenChange={setShowReturnDialog}
            title={t("sales.return.dialogTitle", "Return Items & Refund")}
            closeLabel={t("common:actions.cancel")}
          >
            <div className="grid gap-4" data-testid="return-items-dialog">
              <p className="text-sm text-slate-600">
                {t(
                  "sales.return.dialogDesc",
                  "Choose the quantities returning to stock and how the refund is issued.",
                )}
              </p>

              <div className="grid gap-3 max-h-64 overflow-y-auto pr-1">
                {d.items.map((it) => {
                  const remaining = Math.max(0, Number((it.qty - it.returned_qty).toFixed(3)));
                  const val = returnQtys[it.id] ?? 0;
                  const step = Number.isInteger(it.qty) ? 1 : 0.1;

                  return (
                    <div
                      key={it.id}
                      className="flex items-center justify-between gap-3 rounded-[10px] bg-slate-50 p-3"
                    >
                      <div className="min-w-0">
                        <div className="text-sm font-semibold text-slate-900 truncate">
                          {it.product_name}
                        </div>
                        <div className="text-xs text-slate-500 tabular-nums">
                          {fmt(it.unit_price)} ·{" "}
                          {t("sales.return.remainingQty", {
                            qty: remaining,
                            defaultValue: "{{qty}} returnable",
                          })}
                        </div>
                      </div>

                      {remaining > 0 ? (
                        <div className="flex items-center gap-1.5">
                          <Button
                            type="button"
                            variant="outline"
                            size="sm"
                            disabled={val <= 0}
                            onClick={() =>
                              setReturnQtys((prev) => ({
                                ...prev,
                                [it.id]: Math.max(0, Number((val - step).toFixed(3))),
                              }))
                            }
                            data-testid={`return-dec-${it.id}`}
                          >
                            −
                          </Button>
                          <Input
                            type="number"
                            min={0}
                            max={remaining}
                            step="any"
                            value={val === 0 ? "" : String(val)}
                            placeholder="0"
                            onChange={(e) => {
                              const parsed = parseFloat(e.target.value);
                              const clamped = Number.isNaN(parsed)
                                ? 0
                                : Math.max(0, Math.min(remaining, parsed));
                              setReturnQtys((prev) => ({ ...prev, [it.id]: clamped }));
                            }}
                            className="w-20 text-center tabular-nums"
                            data-testid={`return-qty-${it.id}`}
                          />
                          <Button
                            type="button"
                            variant="outline"
                            size="sm"
                            disabled={val >= remaining}
                            onClick={() =>
                              setReturnQtys((prev) => ({
                                ...prev,
                                [it.id]: Math.min(remaining, Number((val + step).toFixed(3))),
                              }))
                            }
                            data-testid={`return-inc-${it.id}`}
                          >
                            +
                          </Button>
                        </div>
                      ) : (
                        <Badge tone="neutral">
                          {t("sales.return.fullyReturnedItem", "Returned")}
                        </Badge>
                      )}
                    </div>
                  );
                })}
              </div>

              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <Field label={t("sales.return.refundMethod", "Refund Method")}>
                  <Select
                    value={refundMethod}
                    onChange={(e) => setRefundMethod(e.target.value as RefundMethod)}
                    data-testid="return-refund-method"
                  >
                    <option value="cash">{t("sell.cash")}</option>
                    <option value="ewallet">{t("sell.ewallet")}</option>
                    <option value="card">{t("sell.card")}</option>
                    {d.sale.customer_id ? (
                      <option value="utang">{t("sell.utang")}</option>
                    ) : null}
                  </Select>
                </Field>

                <Field label={t("sales.reason")}>
                  <Input
                    value={returnReason}
                    onChange={(e) => setReturnReason(e.target.value)}
                    placeholder={t("sales.return.reasonPlaceholder", "e.g. Defective item, wrong size")}
                    maxLength={200}
                    data-testid="return-reason-input"
                  />
                </Field>
              </div>

              <div className="flex items-center justify-between rounded-[10px] bg-brand-50 border border-brand-200 p-3">
                <span className="text-sm font-semibold text-brand-900">
                  {t("sales.return.refundAmount", "Total Refund")}
                </span>
                <span className="text-lg font-semibold text-brand-900 tabular-nums" data-testid="return-refund-total">
                  {fmt(estimatedRefund)}
                </span>
              </div>

              {returnError ? <Alert>{returnError}</Alert> : null}

              <div className="flex justify-end gap-2 pt-1">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setShowReturnDialog(false)}
                >
                  {t("common:actions.cancel")}
                </Button>
                <Button
                  type="button"
                  disabled={totalSelectedToReturn <= 0 || submitReturn.isPending}
                  onClick={handleConfirmReturn}
                  data-testid="confirm-return-btn"
                >
                  {submitReturn.isPending
                    ? t("common:status.saving", "Saving...")
                    : t("sales.return.confirm", "Confirm Return")}
                </Button>
              </div>
            </div>
          </Dialog>
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
            if (pendingAction === "return") {
              submitReturn.mutate({
                approvalId: apprId || undefined,
                offlineApproval: offlineAppr || undefined,
              });
            } else {
              cancel.mutate({
                approvalId: apprId || undefined,
                offlineApproval: offlineAppr || undefined,
              });
            }
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
            <li key={i} className="h-14 rounded-[6px] border border-slate-200 bg-slate-100 animate-pulse" />
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
              className="flex w-full items-center justify-between gap-2 rounded-[6px] border border-slate-200 bg-white px-4 py-3 text-left text-sm hover:bg-slate-50 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
            >
              <span>
                <span className="block font-mono font-semibold text-slate-900">{s.sale_no ?? s.local_no}</span>
                <span className="text-xs text-slate-500">{when(s.sold_at)}</span>
              </span>
              <span className="flex items-center gap-2">
                {s.status === "voided" ? <Badge tone="warn">{t("sales.status.voided")}</Badge> : null}
                <span className="font-semibold tabular-nums text-slate-900">{fmt(s.total)}</span>
              </span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
