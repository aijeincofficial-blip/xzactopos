import { useEffect, useMemo, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery } from "@tanstack/react-query";
import { formatMoney, money, uuidv7 } from "@pos/core";
import { Alert, Button, Card, Input, Select } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { ApiError } from "../lib/api.ts";
import { dayInTimezone } from "../lib/today.ts";
import {
  cartSubtotal,
  cartTotal,
  changeDue,
  draftProblem,
  lineTotal,
  parseAmount,
  type CartLine,
  type PaymentDraft,
  type SaleDraft,
  type Wallet,
} from "../lib/sale-math.ts";
import { fetchSellables, nextLocalNo, registerWebDevice, submitSale, webDevice, type Sellable, type SoldReceipt } from "../lib/sell-api.ts";

const WALLETS: Wallet[] = ["gcash", "maya", "other"];

interface Done extends SoldReceipt {
  total: number;
  change: number;
}

/** Sell (Solo web): search, cart, cash or e-wallet payment, one `record_sale` op through `sync_push`. Online only. */
export function SellPage() {
  const { t, i18n } = useTranslation("admin");
  const msg = useErrorMessage();
  const { access, can } = useSession();
  const currency = access.tenant.base_currency;
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);

  const store = access.locations.find((l) => l.type === "store" && can("sale.create", l.id));
  const catalog = useQuery({ queryKey: ["sellables", currency], queryFn: () => fetchSellables(currency), staleTime: 30_000 });

  const [search, setSearch] = useState("");
  const [cart, setCart] = useState<CartLine[]>([]);
  const [discountText, setDiscountText] = useState("");
  const [method, setMethod] = useState<"cash" | "ewallet">("cash");
  const [wallet, setWallet] = useState<Wallet>("gcash");
  const [reference, setReference] = useState("");
  const [tenderedText, setTenderedText] = useState("");
  const [problem, setProblem] = useState<string | null>(null);
  const [done, setDone] = useState<Done | null>(null);
  const attempt = useRef<{ key: string; id: string; opId: string } | null>(null);

  useEffect(() => {
    void registerWebDevice();
  }, []);

  const discount = parseAmount(discountText, currency);
  const tendered = parseAmount(tenderedText, currency);
  const subtotal = cartSubtotal(cart);
  const total = discount === null ? subtotal : cartTotal(cart, discount);
  const change = method === "cash" && tendered !== null && tendered > 0 ? changeDue(tendered, total) : 0;

  const shown = useMemo(() => {
    const q = search.trim().toLowerCase();
    const all = catalog.data ?? [];
    return (q ? all.filter((s) => s.name.toLowerCase().includes(q) || s.sku.toLowerCase().includes(q) || s.barcode?.toLowerCase() === q) : all).slice(0, 60);
  }, [catalog.data, search]);

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
    setProblem(null);
    attempt.current = null;
  }

  const charge = useMutation({
    mutationFn: async (): Promise<Done> => {
      if (!store) throw new ApiError("not_allowed", "no store");
      if (discount === null || (method === "cash" && tendered === null)) throw new ApiError("amount_invalid", "amount");
      const day = dayInTimezone(access.tenant.timezone);
      const pay: PaymentDraft =
        method === "cash"
          ? { method: "cash", amount: total, tendered: tendered && tendered > 0 ? tendered : total }
          : { method: "ewallet", amount: total, wallet, ...(reference.trim() ? { reference: reference.trim() } : {}) };
      const key = JSON.stringify([cart, discount, pay, store.id]);
      if (attempt.current?.key !== key) attempt.current = { key, id: uuidv7(), opId: uuidv7() };
      const base = { id: attempt.current.id, soldAt: new Date(), locationId: store.id, deviceId: webDevice().id, discount, lines: cart, payments: [pay] };
      const bad = draftProblem({ ...base, localNo: "X-000000-0000" });
      if (bad) throw new ApiError(bad, bad);
      // a clash of the provisional number is the only retry case; the same op id keeps the retry safe
      for (let n = 0; ; n++) {
        const draft: SaleDraft = { ...base, localNo: nextLocalNo(day) };
        try {
          const r = await submitSale(draft, attempt.current.opId);
          return { ...r, total, change: pay.method === "cash" ? changeDue(pay.tendered ?? total, total) : 0 };
        } catch (e) {
          if (!(e instanceof ApiError && e.key === "duplicate_local_no" && n < 3)) throw e;
        }
      }
    },
    onSuccess: (r) => {
      setDone(r);
      reset();
    },
    onError: (e) => setProblem(e instanceof ApiError && i18n.exists(`admin:sell.problem.${e.key}`) ? t(`sell.problem.${e.key}` as never) : msg(e)),
  });

  if (!store) {
    return (
      <Card>
        <p>{t("sell.noStore")}</p>
      </Card>
    );
  }

  if (done) {
    return (
      <Card className="grid max-w-md gap-3" data-testid="sale-done">
        <h2 className="text-lg font-semibold">{t("sell.done")}</h2>
        <div className="text-sm text-slate-500">
          {t("sell.receiptNo")} <span className="font-mono text-slate-900">{done.saleNo ?? done.localNo}</span>
        </div>
        <div className="text-2xl font-semibold">{fmt(done.total)}</div>
        {done.change > 0 ? (
          <div className="text-sm">
            {t("sell.change")}: <strong>{fmt(done.change)}</strong>
          </div>
        ) : null}
        <Button data-testid="new-sale" onClick={() => setDone(null)}>
          {t("sell.newSale")}
        </Button>
      </Card>
    );
  }

  return (
    <div className="grid gap-4 lg:grid-cols-[1fr_380px]">
      <section className="grid content-start gap-3">
        <h2 className="text-lg font-semibold">{t("sell.title")}</h2>
        <Input
          data-testid="sell-search"
          placeholder={t("sell.search")}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && onSearchEnter()}
        />
        {catalog.isPending ? <Card>{t("sell.loading")}</Card> : null}
        {catalog.isError ? <Alert>{t("sell.loadError")}</Alert> : null}
        {catalog.data && catalog.data.length === 0 ? <Card>{t("sell.noProducts")}</Card> : null}
        {catalog.data && catalog.data.length > 0 && shown.length === 0 ? <Card>{t("sell.noMatch")}</Card> : null}
        <ul className="grid gap-2 sm:grid-cols-2">
          {shown.map((s) => (
            <li key={s.variantId}>
              <button
                type="button"
                data-testid={`product-${s.sku}`}
                onClick={() => add(s)}
                className="flex w-full items-center justify-between gap-2 rounded-md border border-slate-200 bg-white px-3 py-2 text-left text-sm hover:bg-slate-50"
              >
                <span>
                  <span className="block font-medium">{s.name}</span>
                  <span className="text-xs text-slate-500">{s.sku}</span>
                </span>
                <span className="font-semibold">{fmt(s.price)}</span>
              </button>
            </li>
          ))}
        </ul>
      </section>

      <Card className="grid content-start gap-3" data-testid="cart">
        <h3 className="font-medium">{t("sell.cart")}</h3>
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
          <span className="font-medium">{t("sell.payment")}</span>
          <Select aria-label={t("sell.payment")} data-testid="pay-method" value={method} onChange={(e) => setMethod(e.target.value as "cash" | "ewallet")}>
            <option value="cash">{t("sell.cash")}</option>
            <option value="ewallet">{t("sell.ewallet")}</option>
          </Select>
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
          ) : (
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
          )}
        </div>

        {problem ? <Alert>{problem}</Alert> : null}
        <Button data-testid="charge" disabled={cart.length === 0 || charge.isPending} onClick={() => charge.mutate()}>
          {charge.isPending ? t("sell.charging") : t("sell.charge", { total: fmt(total) })}
        </Button>
        {cart.length > 0 ? (
          <Button variant="ghost" size="sm" onClick={reset}>
            {t("sell.clear")}
          </Button>
        ) : null}
      </Card>
    </div>
  );
}
