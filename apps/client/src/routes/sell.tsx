import { useEffect, useMemo, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money, uuidv7 } from "@pos/core";
import { Alert, Button, Card, Input, Select, PageHeader } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { ApiError } from "../lib/api.ts";
import { dayInTimezone } from "../lib/today.ts";
import {
  cartSubtotal,
  buildPayments,
  cartTotal,
  changeDue,
  draftProblem,
  lineTotal,
  parseAmount,
  type CartLine,
  type PayMethod,
  type SaleDraft,
  type Wallet,
} from "../lib/sale-math.ts";
import { createCustomer, fetchCustomers, fetchSellables, nextLocalNo, registerWebDevice, submitSale, webDevice, type Sellable, type SoldReceipt } from "../lib/sell-api.ts";
import { supabase } from "../lib/supabase.ts";
import { SupervisorPinDialog } from "../components/supervisor-pin-dialog.tsx";
import { ReceiptSlipView, type ReceiptData } from "../components/receipt-slip.tsx";
import type { OfflineApprovalPayload } from "../lib/offline-pin-api.ts";

import {
  getStoredPinned,
  saveStoredPinned,
  resolveFastKeyProducts,
  isSkuPinned,
  togglePinnedSku,
} from "../lib/fast-keys.ts";

const WALLETS: Wallet[] = ["gcash", "maya", "other"];

interface Done extends SoldReceipt {
  total: number;
  change: number;
  onUtang: number;
  receiptData?: ReceiptData;
}

/** Sell (Solo web): search, cart, cash or e-wallet payment, one `record_sale` op through `sync_push`. Online only. */
export function SellPage() {
  const { t, i18n } = useTranslation("admin");
  const msg = useErrorMessage();
  const { access, can } = useSession();
  const currency = access.tenant.base_currency;
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);

  const { activeStore } = useActiveLocation();
  const store = (activeStore && can("sale.create", activeStore.id)) ? activeStore : access.locations.find((l) => l.type === "store" && can("sale.create", l.id));
  const catalog = useQuery({ queryKey: ["sellables", currency], queryFn: () => fetchSellables(currency), staleTime: 30_000 });

  const [search, setSearch] = useState("");
  const [cart, setCart] = useState<CartLine[]>([]);
  const [discountText, setDiscountText] = useState("");
  const [method, setMethod] = useState<PayMethod>("cash");
  const [customerId, setCustomerId] = useState("");
  const [paidText, setPaidText] = useState("");
  const [newName, setNewName] = useState("");
  const [newPhone, setNewPhone] = useState("");
  const [showNew, setShowNew] = useState(false);
  const qc = useQueryClient();
  const [wallet, setWallet] = useState<Wallet>("gcash");
  const [reference, setReference] = useState("");
  const [tenderedText, setTenderedText] = useState("");
  const [problem, setProblem] = useState<string | null>(null);
  const [done, setDone] = useState<Done | null>(null);
  const [approvalId, setApprovalId] = useState<string | null>(null);
  const [offlineApproval, setOfflineApproval] = useState<OfflineApprovalPayload | null>(null);
  const [showApprovalDialog, setShowApprovalDialog] = useState(false);
  const attempt = useRef<{ key: string; id: string; opId: string } | null>(null);

  useEffect(() => {
    void registerWebDevice();
  }, []);

  const settingsQuery = useQuery({
    queryKey: ["tenant-settings-controls"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("tenant_settings")
        .select("max_cashier_discount_percent, max_cashier_void_amount, cashier_can_void_own")
        .single();
      if (error) return null;
      return data;
    },
    staleTime: 60_000,
  });

  const maxDiscountPct = settingsQuery.data?.max_cashier_discount_percent ?? 10;
  const discount = parseAmount(discountText, currency);
  const tendered = parseAmount(tenderedText, currency);
  const subtotal = cartSubtotal(cart);
  const total = discount === null ? subtotal : cartTotal(cart, discount);

  const isDiscountOverLimit =
    access.role === "cashier" &&
    subtotal > 0 &&
    (discount ?? 0) * 100 > subtotal * maxDiscountPct;

  const paidNow = paidText.trim() === "" ? null : parseAmount(paidText, currency);
  const paidInvalid = paidText.trim() !== "" && paidNow === null;
  const payments = paidInvalid || discount === null ? null : buildPayments(total, { method, paidNow, tendered, wallet, reference: reference.trim() });
  const onUtang = payments?.find((p) => p.method === "utang")?.amount ?? 0;
  const cashPay = payments?.find((p) => p.method === "cash");
  const change = cashPay && tendered !== null && tendered > 0 ? changeDue(tendered, cashPay.amount) : 0;
  const customers = useQuery({ queryKey: ["customers"], queryFn: fetchCustomers, staleTime: 30_000 });

  const shown = useMemo(() => {
    const q = search.trim().toLowerCase();
    const all = catalog.data ?? [];
    return (q ? all.filter((s) => s.name.toLowerCase().includes(q) || s.sku.toLowerCase().includes(q) || s.barcode?.toLowerCase() === q) : all).slice(0, 60);
  }, [catalog.data, search]);

  const [customPinned, setCustomPinned] = useState<string[] | null>(() => getStoredPinned());

  const fastKeyProducts = useMemo(
    () => resolveFastKeyProducts(catalog.data ?? [], customPinned),
    [catalog.data, customPinned],
  );

  function isPinned(sku: string): boolean {
    return isSkuPinned(sku, catalog.data ?? [], customPinned);
  }

  function togglePin(sku: string) {
    const next = togglePinnedSku(sku, catalog.data ?? [], customPinned);
    setCustomPinned(next);
    saveStoredPinned(next);
  }

  function add(s: Sellable, qty = 1) {
    setProblem(null);
    setCart((c) => {
      const i = c.findIndex((l) => l.variantId === s.variantId);
      if (i >= 0) return c.map((l, k) => (k === i ? { ...l, qty: l.qty + qty } : l));
      return [...c, { variantId: s.variantId, name: s.name, qty, unitPrice: s.price, unitCost: s.cost, taxRate: s.taxRate, tracked: s.tracked }];
    });
  }

  function onSearchEnter() {
    const q = search.trim().toLowerCase();
    const hit = q ? (catalog.data ?? []).find((s) => s.barcode?.toLowerCase() === q || s.sku.toLowerCase() === q) : undefined;
    if (hit) {
      add(hit);
      setSearch("");
    }
  }

  function setQty(variantId: string, text: string) {
    const qty = Number(text);
    setCart((c) => c.map((l) => (l.variantId === variantId ? { ...l, qty: Number.isFinite(qty) ? qty : 0 } : l)));
  }

  function reset() {
    setCart([]);
    setDiscountText("");
    setTenderedText("");
    setReference("");
    setPaidText("");
    setCustomerId("");
    setProblem(null);
    setApprovalId(null);
    setOfflineApproval(null);
    setShowApprovalDialog(false);
    attempt.current = null;
  }

  const addCustomer = useMutation({
    mutationFn: () => createCustomer(newName, newPhone),
    onSuccess: async (c) => {
      await qc.invalidateQueries({ queryKey: ["customers"] });
      setCustomerId(c.id);
      setNewName("");
      setNewPhone("");
      setShowNew(false);
    },
    onError: (e) => setProblem(msg(e)),
  });

  const charge = useMutation({
    mutationFn: async (override?: { approvalId?: string; offlineApproval?: OfflineApprovalPayload }): Promise<Done> => {
      if (!store) throw new ApiError("not_allowed", "no store");
      if (discount === null || payments === null || (method === "cash" && tendered === null)) throw new ApiError("amount_invalid", "amount");
      const day = dayInTimezone(access.tenant.timezone);
      const key = JSON.stringify([cart, discount, payments, store.id, customerId]);
      if (attempt.current?.key !== key) attempt.current = { key, id: uuidv7(), opId: uuidv7() };
      const currentApproval = override?.approvalId ?? approvalId;
      const currentOfflineApproval = override?.offlineApproval ?? offlineApproval;
      const base = {
        id: attempt.current.id,
        soldAt: new Date(),
        locationId: store.id,
        deviceId: webDevice().id,
        customerId: customerId || undefined,
        discount,
        approvalId: currentApproval || undefined,
        offlineApproval: currentOfflineApproval || undefined,
        lines: cart,
        payments,
      };
      const bad = draftProblem({ ...base, localNo: "X-000000-0000" });
      if (bad) throw new ApiError(bad, bad);
      // a clash of the provisional number is the only retry case; the same op id keeps the retry safe
      for (let n = 0; ; n++) {
        const draft: SaleDraft = { ...base, localNo: nextLocalNo(day) };
        try {
          const r = await submitSale(draft, attempt.current.opId);
          const cash = payments.find((p) => p.method === "cash");
          const change = cash ? changeDue(cash.tendered ?? cash.amount, cash.amount) : 0;
          const onUtang = payments.find((p) => p.method === "utang")?.amount ?? 0;
          const receiptData: ReceiptData = {
            tenantName: access.tenant.name,
            storeName: store.name,
            storeCode: store.code,
            receiptNo: r.saleNo ?? r.localNo,
            soldAt: new Date(),
            cashierName: access.full_name || access.username,
            customerName: (customers.data ?? []).find((c) => c.id === customerId)?.name || null,
            items: cart.map((line) => ({
              product_name: line.name,
              qty: line.qty,
              unit_price: line.unitPrice,
              line_total: line.qty * line.unitPrice,
            })),
            subtotal,
            discount,
            total,
            payments: payments.map((p) => ({
              method: p.method,
              amount: p.amount,
              wallet: p.wallet,
              reference: p.reference,
            })),
            change,
            onUtang,
            currency,
            timezone: access.tenant.timezone,
          };
          return { ...r, total, change, onUtang, receiptData };
        } catch (e) {
          if (!(e instanceof ApiError && e.key === "duplicate_local_no" && n < 3)) throw e;
        }
      }
    },
    onSuccess: (r) => {
      setDone(r);
      reset();
    },
    onError: (e) => {
      if (e instanceof ApiError && e.key === "approval_required") {
        setShowApprovalDialog(true);
        return;
      }
      setProblem(e instanceof ApiError && i18n.exists(`admin:sell.problem.${e.key}`) ? t(`sell.problem.${e.key}` as never) : msg(e));
    },
  });

  function handleCharge() {
    if (!store) return;
    if (isDiscountOverLimit && !approvalId && !offlineApproval) {
      const key = JSON.stringify([cart, discount, payments, store.id, customerId]);
      if (attempt.current?.key !== key) attempt.current = { key, id: uuidv7(), opId: uuidv7() };
      setShowApprovalDialog(true);
      return;
    }
    charge.mutate();
  }

  if (!store) {
    return (
      <Card>
        <p>{t("sell.noStore")}</p>
      </Card>
    );
  }

  if (done) {
    return (
      <div className="grid max-w-md gap-4">
        <Card className="grid gap-3" data-testid="sale-done">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold text-emerald-700">✓ {t("sell.done")}</h2>
            <div className="text-sm font-mono text-slate-500">
              {t("sell.receiptNo")} <span className="font-semibold text-slate-900">{done.saleNo ?? done.localNo}</span>
            </div>
          </div>
          <div className="text-2xl font-semibold text-slate-900">{fmt(done.total)}</div>
          {done.onUtang > 0 ? (
            <div className="flex justify-between text-sm text-amber-800">
              <span>{t("sell.onUtang")}</span>
              <strong>{fmt(done.onUtang)}</strong>
            </div>
          ) : null}
          {done.change > 0 ? (
            <div className="flex justify-between text-sm text-slate-600">
              <span>{t("sell.change")}</span>
              <strong>{fmt(done.change)}</strong>
            </div>
          ) : null}
          <div className="flex gap-2 pt-2 border-t border-slate-100 no-print">
            <Button variant="outline" data-testid="print-receipt-btn" onClick={() => window.print()} className="flex-1">
              🖨️ {t("sell.printReceipt")}
            </Button>
            <Button data-testid="new-sale" onClick={() => setDone(null)} className="flex-1">
              {t("sell.newSale")}
            </Button>
          </div>
        </Card>

        {done.receiptData ? (
          <div className="bg-slate-50 p-2 rounded-lg border border-slate-200">
            <ReceiptSlipView receipt={done.receiptData} />
          </div>
        ) : null}
      </div>
    );
  }

  return (
    <div className="grid gap-4 lg:grid-cols-[1fr_380px]">
      <section className="grid content-start gap-3">
        <PageHeader title={t("sell.title")} />
        <Input
          data-testid="sell-search"
          placeholder={t("sell.search")}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && onSearchEnter()}
        />
        {/* Fast-Keys Quick Bar */}
        {fastKeyProducts.length > 0 || (customPinned !== null && customPinned.length === 0) ? (
          <div data-testid="fast-keys-bar" className="grid gap-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                {t("sell.fastKeys")}
              </span>
            </div>
            {fastKeyProducts.length === 0 ? (
              <p className="text-xs text-slate-400 py-1">{t("sell.fastKeysEmpty")}</p>
            ) : (
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-2">
                {fastKeyProducts.map((s) => (
                  <button
                    key={s.variantId}
                    type="button"
                    data-testid={`fast-key-${s.sku}`}
                    onClick={() => add(s)}
                    className="flex flex-col justify-between p-2 rounded-md border border-slate-200 bg-white text-left hover:border-slate-300 hover:bg-slate-50 transition-colors shadow-xs"
                  >
                    <div className="w-full">
                      <span className="block text-xs font-semibold text-slate-900 truncate" title={s.name}>
                        {s.name}
                      </span>
                      <span className="block text-[11px] text-slate-500 font-mono truncate">{s.sku}</span>
                    </div>
                    <div className="mt-2">
                      <span className="inline-block rounded bg-slate-100 px-1.5 py-0.5 text-xs font-semibold text-slate-800">
                        {fmt(s.price)}
                      </span>
                    </div>
                  </button>
                ))}
              </div>
            )}
          </div>
        ) : null}

        {catalog.isPending ? (
          <ul className="grid gap-2 sm:grid-cols-2">
            {Array.from({ length: 6 }).map((_, i) => (
              <li key={i} className="h-14 rounded-md border border-slate-200 bg-slate-100 animate-pulse" />
            ))}
          </ul>
        ) : null}
        {catalog.isError ? <Alert>{t("sell.loadError")}</Alert> : null}
        {catalog.data && catalog.data.length === 0 ? <Card>{t("sell.noProducts")}</Card> : null}
        {catalog.data && catalog.data.length > 0 && shown.length === 0 ? <Card>{t("sell.noMatch")}</Card> : null}
        <ul className="grid gap-2 sm:grid-cols-2">
          {shown.map((s) => {
            const pinned = isPinned(s.sku);
            return (
              <li key={s.variantId} className="flex items-stretch gap-1">
                <button
                  type="button"
                  data-testid={`product-${s.sku}`}
                  onClick={() => add(s)}
                  className="flex flex-1 items-center justify-between gap-2 rounded-md border border-slate-200 bg-white px-3 py-2 text-left text-sm hover:bg-slate-50 focus:outline-none"
                >
                  <span className="min-w-0 flex-1">
                    <span className="block font-semibold truncate">{s.name}</span>
                    <span className="text-xs text-slate-500 font-mono">{s.sku}</span>
                  </span>
                  <span className="font-semibold whitespace-nowrap">{fmt(s.price)}</span>
                </button>
                <button
                  type="button"
                  data-testid={`pin-toggle-${s.sku}`}
                  title={pinned ? t("sell.unpinFromFastKeys") : t("sell.pinToFastKeys")}
                  aria-label={pinned ? t("sell.unpinFromFastKeys") : t("sell.pinToFastKeys")}
                  onClick={() => togglePin(s.sku)}
                  className={`flex items-center justify-center w-9 rounded-md border text-sm transition-colors ${
                    pinned
                      ? "border-amber-300 bg-amber-50 text-amber-600 hover:bg-amber-100"
                      : "border-slate-200 bg-white text-slate-400 hover:text-slate-600 hover:bg-slate-50"
                  }`}
                >
                  ★
                </button>
              </li>
            );
          })}
        </ul>
      </section>

      <Card className="grid content-start gap-3" data-testid="cart">
        <h3 className="font-semibold">{t("sell.cart")}</h3>
        {cart.length === 0 ? (
          <p className="text-sm text-slate-500">{t("sell.emptyCart")}</p>
        ) : (
          <ul className="grid gap-2">
            {cart.map((l) => (
              <li key={l.variantId} className="grid grid-cols-[1fr_84px_auto] items-center gap-2 text-sm">
                <span className="truncate">{l.name}</span>
                <Input
                  aria-label={t("sell.qty")}
                  data-testid={`qty-${l.variantId}`}
                  inputMode="decimal"
                  value={String(l.qty)}
                  onChange={(e) => setQty(l.variantId, e.target.value)}
                />
                <span className="flex items-center gap-1">
                  <span className="w-20 text-right">{fmt(lineTotal(l.qty, l.unitPrice))}</span>
                  <Button variant="ghost" size="sm" aria-label={t("sell.remove")} onClick={() => setCart((c) => c.filter((x) => x.variantId !== l.variantId))}>
                    ×
                  </Button>
                </span>
              </li>
            ))}
          </ul>
        )}

        <div className="grid gap-1 border-t border-slate-200 pt-3 text-sm">
          <div className="flex justify-between">
            <span>{t("sell.subtotal")}</span>
            <span>{fmt(subtotal)}</span>
          </div>
          <label className="flex items-center justify-between gap-2">
            <span>{t("sell.discount")}</span>
            <Input className="w-28 text-right" data-testid="discount" inputMode="decimal" value={discountText} onChange={(e) => setDiscountText(e.target.value)} />
          </label>
          <div className="flex justify-between text-base font-semibold" data-testid="cart-total">
            <span>{t("sell.total")}</span>
            <span>{fmt(total)}</span>
          </div>
        </div>

        <div className="grid gap-2 border-t border-slate-200 pt-3 text-sm">
          <span className="font-semibold">{t("sell.payment")}</span>
          <Select aria-label={t("sell.payment")} data-testid="pay-method" value={method} onChange={(e) => setMethod(e.target.value as PayMethod)}>
            <option value="cash">{t("sell.cash")}</option>
            <option value="ewallet">{t("sell.ewallet")}</option>
            <option value="card">{t("sell.card")}</option>
            <option value="utang">{t("sell.utang")}</option>
          </Select>

          <Select aria-label={t("sell.customer")} data-testid="customer" value={customerId} onChange={(e) => setCustomerId(e.target.value)}>
            <option value="">{method === "utang" ? t("sell.chooseCustomer") : t("sell.noCustomer")}</option>
            {(customers.data ?? []).map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </Select>
          {showNew ? (
            <div className="grid gap-2 rounded-md border border-slate-200 p-2">
              <Input data-testid="new-customer-name" placeholder={t("sell.customerName")} value={newName} maxLength={80} onChange={(e) => setNewName(e.target.value)} />
              <Input placeholder={t("sell.customerPhone")} value={newPhone} maxLength={32} onChange={(e) => setNewPhone(e.target.value)} />
              <div className="flex gap-2">
                <Button size="sm" data-testid="save-customer" disabled={newName.trim() === "" || addCustomer.isPending} onClick={() => addCustomer.mutate()}>
                  {t("sell.addCustomer")}
                </Button>
                <Button size="sm" variant="ghost" onClick={() => setShowNew(false)}>
                  {t("sell.cancel")}
                </Button>
              </div>
            </div>
          ) : (
            <Button variant="ghost" size="sm" data-testid="new-customer" onClick={() => setShowNew(true)}>
              {t("sell.newCustomer")}
            </Button>
          )}

          {method !== "utang" ? (
            <label className="flex items-center justify-between gap-2">
              <span>{t("sell.paidNow")}</span>
              <Input className="w-28 text-right" data-testid="paid-now" inputMode="decimal" placeholder={fmt(total)} value={paidText} onChange={(e) => setPaidText(e.target.value)} />
            </label>
          ) : null}
          {onUtang > 0 ? (
            <div className="flex justify-between">
              <span>{t("sell.onUtang")}</span>
              <strong data-testid="on-utang">{fmt(onUtang)}</strong>
            </div>
          ) : null}

          {method === "cash" ? (
            <>
              <label className="flex items-center justify-between gap-2">
                <span>{t("sell.tendered")}</span>
                <Input className="w-28 text-right" data-testid="tendered" inputMode="decimal" value={tenderedText} onChange={(e) => setTenderedText(e.target.value)} />
              </label>
              {change > 0 ? (
                <div className="flex justify-between">
                  <span>{t("sell.change")}</span>
                  <strong data-testid="change">{fmt(change)}</strong>
                </div>
              ) : null}
            </>
          ) : null}
          {method === "ewallet" ? (
            <>
              <Select aria-label={t("sell.wallet")} data-testid="pay-wallet" value={wallet} onChange={(e) => setWallet(e.target.value as Wallet)}>
                {WALLETS.map((w) => (
                  <option key={w} value={w}>
                    {t(`sell.wallets.${w}`)}
                  </option>
                ))}
              </Select>
              <Input placeholder={t("sell.reference")} value={reference} maxLength={64} onChange={(e) => setReference(e.target.value)} />
            </>
          ) : null}
          {method === "card" ? (
            <Input data-testid="pay-card-ref" placeholder={t("sell.cardRefPlaceholder")} value={reference} maxLength={64} onChange={(e) => setReference(e.target.value)} />
          ) : null}
        </div>
        {problem ? <Alert>{problem}</Alert> : null}
        <Button data-testid="charge" disabled={cart.length === 0 || charge.isPending} onClick={handleCharge}>
          {charge.isPending ? t("sell.charging") : t("sell.charge", { total: fmt(total) })}
        </Button>
        {cart.length > 0 ? (
          <Button variant="ghost" size="sm" onClick={reset}>
            {t("sell.clear")}
          </Button>
        ) : null}
      </Card>

      <SupervisorPinDialog
        open={showApprovalDialog}
        onOpenChange={setShowApprovalDialog}
        locationId={store.id}
        action="sale_discount"
        refId={attempt.current?.id ?? ""}
        onApproved={(apprId, offlineAppr) => {
          setApprovalId(apprId || null);
          setOfflineApproval(offlineAppr || null);
          charge.mutate({ approvalId: apprId || undefined, offlineApproval: offlineAppr || undefined });
        }}
      />
    </div>
  );
}
