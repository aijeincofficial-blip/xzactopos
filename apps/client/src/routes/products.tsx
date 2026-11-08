import { useState, type ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money, toMajorNumber } from "@pos/core";
import { Alert, Badge, Button, Card, Input, Select } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { parseAmount } from "../lib/sale-math.ts";
import { formatQty, parseQty, parseTaxPercent, stockStatus, taxPercentText } from "../lib/product-math.ts";
import {
  archiveProduct,
  countStock,
  createProduct,
  fetchProductRows,
  receiveStock,
  updateProduct,
  type ProductInput,
  type ProductRow,
} from "../lib/stock-api.ts";

type ProblemKey = "name" | "price" | "cost" | "tax" | "reorder" | "opening" | "qty" | "count";

function Labeled({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="grid gap-1 text-sm">
      <span className="font-medium">{label}</span>
      {children}
    </label>
  );
}

/** "12.50" for the form from minor units, without a currency symbol. */
function majorText(minor: number, currency: string): string {
  return minor === 0 ? "" : String(toMajorNumber(money(minor, currency)));
}

interface FormProps {
  row: ProductRow | null;
  currency: string;
  onSaved: () => void;
  onCancel: () => void;
  locationId: string;
}

/** Create (row = null) or edit one product and its default variant. */
function ProductForm({ row, currency, onSaved, onCancel, locationId }: FormProps) {
  const { t } = useTranslation("admin");
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const [name, setName] = useState(row?.name ?? "");
  const [price, setPrice] = useState(row?.price != null ? majorText(row.price, currency) : "");
  const [cost, setCost] = useState(row ? majorText(row.cost, currency) : "");
  const [unit, setUnit] = useState(row?.unit ?? "pc");
  const [tax, setTax] = useState(row ? taxPercentText(row.taxRate) : "");
  const [sku, setSku] = useState(row?.sku ?? "");
  const [barcode, setBarcode] = useState(row?.barcode ?? "");
  const [reorder, setReorder] = useState(row && row.reorderPoint ? formatQty(row.reorderPoint) : "");
  const [tracked, setTracked] = useState(row?.tracked ?? true);
  const [active, setActive] = useState(row?.active ?? true);
  const [opening, setOpening] = useState("");
  const [problem, setProblem] = useState<ProblemKey | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  const save = useMutation({
    mutationFn: async () => {
      const priceMinor = price.trim() === "" ? null : parseAmount(price, currency);
      const costMinor = parseAmount(cost, currency);
      const taxRate = parseTaxPercent(tax);
      const reorderPoint = reorder.trim() === "" ? 0 : parseQty(reorder, { allowZero: true });
      const openingQty = opening.trim() === "" ? 0 : parseQty(opening, { allowZero: true });
      const bad: ProblemKey | null =
        name.trim() === "" ? "name"
        : priceMinor === null ? "price"
        : costMinor === null ? "cost"
        : taxRate === null ? "tax"
        : reorderPoint === null ? "reorder"
        : openingQty === null ? "opening"
        : null;
      if (bad) {
        setProblem(bad);
        return false;
      }
      setProblem(null);
      const input: ProductInput = {
        name,
        price: priceMinor as number,
        cost: costMinor as number,
        unit,
        taxRate: taxRate as number,
        tracked,
        active,
        sku,
        barcode,
        reorderPoint: reorderPoint as number,
      };
      if (row) await updateProduct(row, input);
      else await createProduct(input, openingQty as number, locationId);
      return true;
    },
    onSuccess: async (saved) => {
      if (!saved) return;
      setError(null);
      setSaved(true);
      await Promise.all([qc.invalidateQueries({ queryKey: ["products"] }), qc.invalidateQueries({ queryKey: ["sellables"] })]);
      onSaved();
    },
    onError: (e) => {
      setSaved(false);
      setError(msg(e));
    },
  });

  return (
    <Card className="grid gap-3" data-testid="product-form">
      <h3 className="font-medium">{row ? t("products.edit") : t("products.add")}</h3>
      <div className="grid gap-3 sm:grid-cols-2">
        <Labeled label={t("products.name")}>
          <Input data-testid="pf-name" value={name} maxLength={120} onChange={(e) => setName(e.target.value)} />
        </Labeled>
        <Labeled label={t("products.price")}>
          <Input data-testid="pf-price" inputMode="decimal" value={price} onChange={(e) => setPrice(e.target.value)} />
        </Labeled>
        <Labeled label={t("products.cost")}>
          <Input data-testid="pf-cost" inputMode="decimal" value={cost} onChange={(e) => setCost(e.target.value)} />
        </Labeled>
        <Labeled label={t("products.unit")}>
          <Input value={unit} maxLength={16} onChange={(e) => setUnit(e.target.value)} />
        </Labeled>
        <Labeled label={t("products.tax")}>
          <Input inputMode="decimal" value={tax} onChange={(e) => setTax(e.target.value)} />
        </Labeled>
        <Labeled label={t("products.reorder")}>
          <Input inputMode="decimal" value={reorder} onChange={(e) => setReorder(e.target.value)} />
        </Labeled>
        <Labeled label={t("products.sku")}>
          <Input value={sku} maxLength={40} placeholder={t("products.skuAuto")} onChange={(e) => setSku(e.target.value)} />
        </Labeled>
        <Labeled label={t("products.barcode")}>
          <Input value={barcode} maxLength={64} onChange={(e) => setBarcode(e.target.value)} />
        </Labeled>
        {!row ? (
          <Labeled label={t("products.opening")}>
            <Input data-testid="pf-opening" inputMode="decimal" value={opening} onChange={(e) => setOpening(e.target.value)} />
          </Labeled>
        ) : null}
      </div>
      <div className="flex flex-wrap gap-4 text-sm">
        <label className="flex items-center gap-2">
          <input type="checkbox" checked={tracked} onChange={(e) => setTracked(e.target.checked)} />
          {t("products.tracked")}
        </label>
        <label className="flex items-center gap-2">
          <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} />
          {t("products.active")}
        </label>
      </div>
      {problem ? <Alert>{t(`products.problem.${problem}`)}</Alert> : null}
      {error ? <Alert>{error}</Alert> : null}
      {saved && row ? <Alert tone="info">{t("products.saved")}</Alert> : null}
      <div className="flex gap-2">
        <Button data-testid="pf-save" disabled={save.isPending} onClick={() => save.mutate()}>
          {t("products.save")}
        </Button>
        <Button variant="ghost" onClick={onCancel}>
          {t("sell.cancel")}
        </Button>
      </div>
    </Card>
  );
}

/** Stock in and counting for one product at the chosen store. */
function StockPanel({ row, currency, locationId, fmt }: { row: ProductRow; currency: string; locationId: string; fmt: (n: number) => string }) {
  const { t } = useTranslation("admin");
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const [inQty, setInQty] = useState("");
  const [inCost, setInCost] = useState("");
  const [counted, setCounted] = useState("");
  const [reason, setReason] = useState<"counted" | "damage" | "other">("counted");
  const [note, setNote] = useState<{ tone: "info" | "error"; text: string } | null>(null);

  const refresh = () => Promise.all([qc.invalidateQueries({ queryKey: ["products"] }), qc.invalidateQueries({ queryKey: ["sellables"] })]);

  const receive = useMutation({
    mutationFn: async () => {
      const qty = parseQty(inQty);
      const cost = inCost.trim() === "" ? null : parseAmount(inCost, currency);
      if (qty === null || (inCost.trim() !== "" && cost === null)) {
        setNote({ tone: "error", text: t("products.problem.qty") });
        return false;
      }
      await receiveStock(row.variantId, qty, cost, locationId);
      return true;
    },
    onSuccess: async (ok) => {
      if (!ok) return;
      setInQty("");
      setInCost("");
      setNote({ tone: "info", text: t("products.received") });
      await refresh();
    },
    onError: (e) => setNote({ tone: "error", text: msg(e) }),
  });

  const count = useMutation({
    mutationFn: async () => {
      const n = parseQty(counted, { allowZero: true });
      if (n === null) {
        setNote({ tone: "error", text: t("products.problem.count") });
        return null;
      }
      return countStock(row.variantId, n, reason, locationId);
    },
    onSuccess: async (r) => {
      if (!r) return;
      setCounted("");
      setNote({ tone: "info", text: t("products.counted", { delta: formatQty(r.delta) }) });
      await refresh();
    },
    onError: (e) => setNote({ tone: "error", text: msg(e) }),
  });

  if (!row.tracked) return <Card className="text-sm text-slate-600">{t("products.notTracked")}</Card>;

  return (
    <Card className="grid gap-3" data-testid="stock-panel">
      <h3 className="font-medium">{t("products.stock")}</h3>
      <div className="text-sm">
        {t("products.onHand")}: <strong data-testid="on-hand">{formatQty(row.qty)}</strong> {row.unit}
        {row.cost > 0 ? <span className="text-slate-500"> · {t("products.cost")} {fmt(row.cost)}</span> : null}
      </div>
      <div className="grid gap-2 sm:grid-cols-[1fr_1fr_auto] sm:items-end">
        <Labeled label={t("products.receiveQty")}>
          <Input data-testid="receive-qty" inputMode="decimal" value={inQty} onChange={(e) => setInQty(e.target.value)} />
        </Labeled>
        <Labeled label={t("products.receiveCost")}>
          <Input data-testid="receive-cost" inputMode="decimal" value={inCost} onChange={(e) => setInCost(e.target.value)} />
        </Labeled>
        <Button data-testid="receive-go" disabled={receive.isPending} onClick={() => receive.mutate()}>
          {t("products.receive")}
        </Button>
      </div>
      <div className="grid gap-2 sm:grid-cols-[1fr_1fr_auto] sm:items-end">
        <Labeled label={t("products.countedQty")}>
          <Input data-testid="count-qty" inputMode="decimal" value={counted} onChange={(e) => setCounted(e.target.value)} />
        </Labeled>
        <Labeled label={t("products.reason")}>
          <Select value={reason} onChange={(e) => setReason(e.target.value as "counted" | "damage" | "other")}>
            <option value="counted">{t("products.reasons.counted")}</option>
            <option value="damage">{t("products.reasons.damage")}</option>
            <option value="other">{t("products.reasons.other")}</option>
          </Select>
        </Labeled>
        <Button variant="outline" data-testid="count-go" disabled={count.isPending} onClick={() => count.mutate()}>
          {t("products.setCount")}
        </Button>
      </div>
      {note ? <Alert tone={note.tone}>{note.text}</Alert> : null}
    </Card>
  );
}

/** Products and stock (Solo web): the catalog with prices and on-hand, add / edit / archive, stock in, counts. */
export function ProductsPage() {
  const { t, i18n } = useTranslation("admin");
  const msg = useErrorMessage();
  const { access, can } = useSession();
  const qc = useQueryClient();
  const currency = access.tenant.base_currency;
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);
  const { activeStore } = useActiveLocation();
  const store = (activeStore && can("catalog.manage", activeStore.id)) ? activeStore : access.locations.find((l) => l.type === "store" && can("catalog.manage", l.id));

  const [search, setSearch] = useState("");
  const [onlyLow, setOnlyLow] = useState(false);
  const [adding, setAdding] = useState(false);
  const [openId, setOpenId] = useState<string | null>(null);
  const [archiveError, setArchiveError] = useState<string | null>(null);

  const q = useQuery({
    queryKey: ["products", store?.id, currency],
    queryFn: () => fetchProductRows(currency, store?.id ?? ""),
    enabled: Boolean(store),
  });
  const archive = useMutation({
    mutationFn: (productId: string) => archiveProduct(productId),
    onSuccess: async () => {
      setOpenId(null);
      setArchiveError(null);
      await Promise.all([qc.invalidateQueries({ queryKey: ["products"] }), qc.invalidateQueries({ queryKey: ["sellables"] })]);
    },
    onError: (e) => setArchiveError(msg(e)),
  });

  if (!store) {
    return (
      <Card>
        <p>{t("sell.noStore")}</p>
      </Card>
    );
  }

  const needle = search.trim().toLowerCase();
  const rows = (q.data ?? []).filter(
    (r) =>
      (!needle || r.name.toLowerCase().includes(needle) || r.sku.toLowerCase().includes(needle) || r.barcode?.toLowerCase() === needle) &&
      (!onlyLow || ["out", "low"].includes(stockStatus(r))),
  );
  const open = q.data?.find((r) => r.variantId === openId) ?? null;
  const canStock = can("stock.adjust_store", store.id);

  return (
    <div className="grid gap-4 lg:grid-cols-[1fr_420px]">
      <section className="grid content-start gap-3">
        <div className="flex flex-wrap items-center gap-2">
          <h2 className="mr-auto text-lg font-semibold">{t("products.title")}</h2>
          <Button data-testid="add-product" onClick={() => { setAdding(true); setOpenId(null); }}>
            {t("products.add")}
          </Button>
        </div>
        <Input data-testid="products-search" placeholder={t("sell.search")} value={search} onChange={(e) => setSearch(e.target.value)} />
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={onlyLow} onChange={(e) => setOnlyLow(e.target.checked)} />
          {t("products.onlyLow")}
        </label>
        {q.isPending ? <Card>{t("sell.loading")}</Card> : null}
        {q.isError ? <Alert>{t("sell.loadError")}</Alert> : null}
        {q.data && q.data.length === 0 ? <Card>{t("products.empty")}</Card> : null}
        <ul className="grid gap-2">
          {rows.map((r) => {
            const status = stockStatus(r);
            return (
              <li key={r.variantId}>
                <button
                  type="button"
                  data-testid={`row-${r.sku}`}
                  onClick={() => { setOpenId(r.variantId); setAdding(false); setArchiveError(null); }}
                  className={`flex w-full items-center justify-between gap-2 rounded-md border bg-white px-3 py-2 text-left text-sm hover:bg-slate-50 ${r.variantId === openId ? "border-slate-900" : "border-slate-200"}`}
                >
                  <span>
                    <span className="block font-medium">{r.name}</span>
                    <span className="text-xs text-slate-500">
                      {r.sku}
                      {r.active ? "" : ` · ${t("products.inactive")}`}
                    </span>
                  </span>
                  <span className="flex items-center gap-2">
                    {status === "out" ? <Badge tone="warn">{t("products.out")}</Badge> : null}
                    {status === "low" ? <Badge tone="warn">{t("products.low")}</Badge> : null}
                    <span className="text-right">
                      <span className="block font-semibold">{r.price === null ? t("products.noPrice") : fmt(r.price)}</span>
                      {r.tracked ? (
                        <span className="text-xs text-slate-500">
                          {formatQty(r.qty)} {r.unit}
                        </span>
                      ) : null}
                    </span>
                  </span>
                </button>
              </li>
            );
          })}
        </ul>
      </section>

      <section className="grid content-start gap-3">
        {adding ? (
          <ProductForm row={null} currency={currency} locationId={store.id} onSaved={() => setAdding(false)} onCancel={() => setAdding(false)} />
        ) : open ? (
          <>
            <ProductForm key={open.variantId} row={open} currency={currency} locationId={store.id} onSaved={() => undefined} onCancel={() => setOpenId(null)} />
            {canStock ? <StockPanel key={`s-${open.variantId}`} row={open} currency={currency} locationId={store.id} fmt={fmt} /> : null}
            <Card className="grid gap-2">
              {archiveError ? <Alert>{archiveError}</Alert> : null}
              <Button variant="danger" data-testid="archive" disabled={archive.isPending} onClick={() => archive.mutate(open.productId)}>
                {t("products.archive")}
              </Button>
              <p className="text-xs text-slate-500">{t("products.archiveHint")}</p>
            </Card>
          </>
        ) : (
          <Card className="text-sm text-slate-500">{t("products.pick")}</Card>
        )}
      </section>
    </div>
  );
}
