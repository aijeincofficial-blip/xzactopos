import { useState, type ChangeEvent } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money, toMajorNumber } from "@pos/core";
import { Alert, Badge, Button, Card, Dialog, EmptyState, ErrorState, Field, Input, PageHeader, Select, useToast } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { parseAmount } from "../lib/sale-math.ts";
import { formatQty, parseQty, parseTaxPercent, stockStatus, taxPercentText } from "../lib/product-math.ts";
import {
  archiveCategory,
  archiveProduct,
  countStock,
  createProduct,
  fetchCategories,
  fetchProductRows,
  fetchRecentConversions,
  getExpiryStatus,
  openPack,
  receiveStock,
  setExpiry,
  updateProduct,
  upsertCategory,
  voidOpenPack,
  type Category,
  type ProductInput,
  type ProductRow,
} from "../lib/stock-api.ts";
import { downloadCsv, exportProductsCsv, parseAndValidateImport, type ParsedProductImport } from "../lib/csv-helper.ts";

type ProblemKey = "name" | "price" | "cost" | "tax" | "reorder" | "opening" | "qty" | "count";

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
  categories: Category[];
  availablePieces: ProductRow[];
}

/** Create (row = null) or edit one product and its default variant. */
function ProductForm({ row, currency, onSaved, onCancel, locationId, categories, availablePieces }: FormProps) {
  const { t } = useTranslation("admin");
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const toast = useToast();
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
  const [categoryId, setCategoryId] = useState<string>(row?.categoryId ?? "");

  // Tingi repack config
  const [isPack, setIsPack] = useState(Boolean(row?.breaksIntoVariantId));
  const [pieceVariantId, setPieceVariantId] = useState(row?.breaksIntoVariantId ?? "");
  const [piecesPerPack, setPiecesPerPack] = useState(row?.breaksIntoQty ? String(row.breaksIntoQty) : "20");

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

      const ratioNum = parseInt(piecesPerPack, 10);
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
        categoryId: categoryId.trim() ? categoryId : null,
        breaksIntoVariantId: isPack && pieceVariantId.trim() ? pieceVariantId : null,
        breaksIntoQty: isPack && !isNaN(ratioNum) && ratioNum > 0 ? ratioNum : null,
      };

      if (row) await updateProduct(row, input);
      else await createProduct(input, openingQty as number, locationId);
      return true;
    },
    onSuccess: async (saved) => {
      if (!saved) return;
      setError(null);
      setSaved(true);
      toast.good(t("products.saved"));
      await Promise.all([qc.invalidateQueries({ queryKey: ["products"] }), qc.invalidateQueries({ queryKey: ["sellables"] })]);
      onSaved();
    },
    onError: (e) => {
      setSaved(false);
      const m = msg(e);
      setError(m);
      toast.error(m);
    },
  });

  return (
    <Card className="grid gap-3" data-testid="product-form">
      <h3 className="font-medium">{row ? t("products.edit") : t("products.add")}</h3>
      <div className="grid gap-3 sm:grid-cols-2">
        <Field label={t("products.name")}>
          <Input data-testid="pf-name" value={name} maxLength={120} onChange={(e) => setName(e.target.value)} />
        </Field>
        <Field label={t("products.category")}>
          <Select value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
            <option value="">{t("products.noCategory")}</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </Select>
        </Field>
        <Field label={t("products.price")}>
          <Input data-testid="pf-price" inputMode="decimal" value={price} onChange={(e) => setPrice(e.target.value)} />
        </Field>
        <Field label={t("products.cost")}>
          <Input data-testid="pf-cost" inputMode="decimal" value={cost} onChange={(e) => setCost(e.target.value)} />
        </Field>
        <Field label={t("products.unit")}>
          <Input value={unit} maxLength={16} onChange={(e) => setUnit(e.target.value)} />
        </Field>
        <Field label={t("products.tax")}>
          <Input inputMode="decimal" value={tax} onChange={(e) => setTax(e.target.value)} />
        </Field>
        <Field label={t("products.reorder")}>
          <Input inputMode="decimal" value={reorder} onChange={(e) => setReorder(e.target.value)} />
        </Field>
        <Field label={t("products.sku")}>
          <Input value={sku} maxLength={40} placeholder={t("products.skuAuto")} onChange={(e) => setSku(e.target.value)} />
        </Field>
        <Field label={t("products.barcode")}>
          <Input value={barcode} maxLength={64} onChange={(e) => setBarcode(e.target.value)} />
        </Field>
        {!row ? (
          <Field label={t("products.opening")}>
            <Input data-testid="pf-opening" inputMode="decimal" value={opening} onChange={(e) => setOpening(e.target.value)} />
          </Field>
        ) : null}
      </div>

      {/* Tingi / Repack Link */}
      <div className="rounded border border-slate-200 bg-slate-50 p-3 text-sm grid gap-2">
        <label className="flex items-center gap-2 font-medium">
          <input type="checkbox" checked={isPack} onChange={(e) => setIsPack(e.target.checked)} />
          {t("products.isPack")}
        </label>
        {isPack ? (
          <div className="grid gap-2 sm:grid-cols-2 pt-1">
            <Field label={t("products.breaksIntoPiece")}>
              <Select value={pieceVariantId} onChange={(e) => setPieceVariantId(e.target.value)}>
                <option value="">{t("products.selectPiece")}</option>
                {availablePieces
                  .filter((p) => p.variantId !== row?.variantId)
                  .map((p) => (
                    <option key={p.variantId} value={p.variantId}>
                      {p.name} ({p.sku})
                    </option>
                  ))}
              </Select>
            </Field>
            <Field label={t("products.piecesPerPack")}>
              <Input
                type="number"
                min="1"
                max="10000"
                value={piecesPerPack}
                onChange={(e) => setPiecesPerPack(e.target.value)}
              />
            </Field>
          </div>
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

/** Stock in, counting, tingi repack conversions, and expiry dates. */
function StockPanel({
  row,
  currency,
  locationId,
  fmt,
  availablePieces,
}: {
  row: ProductRow;
  currency: string;
  locationId: string;
  fmt: (n: number) => string;
  availablePieces: ProductRow[];
}) {
  const { t } = useTranslation("admin");
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const toast = useToast();
  const [inQty, setInQty] = useState("");
  const [inCost, setInCost] = useState("");
  const [inExpiry, setInExpiry] = useState("");
  const [counted, setCounted] = useState("");
  const [reason, setReason] = useState<"counted" | "damage" | "other">("counted");
  const [expiryEdit, setExpiryEdit] = useState(row.expiresOn ?? "");
  const [note, setNote] = useState<{ tone: "info" | "error"; text: string } | null>(null);

  // Tingi Open Pack state
  const [openPacksCount, setOpenPacksCount] = useState("1");
  const [openPackNote, setOpenPackNote] = useState("");

  const refresh = () =>
    Promise.all([
      qc.invalidateQueries({ queryKey: ["products"] }),
      qc.invalidateQueries({ queryKey: ["sellables"] }),
      qc.invalidateQueries({ queryKey: ["conversions", locationId] }),
    ]);

  const conversionsQuery = useQuery({
    queryKey: ["conversions", locationId],
    queryFn: () => fetchRecentConversions(locationId),
    enabled: Boolean(row.breaksIntoVariantId),
  });

  const receive = useMutation({
    mutationFn: async () => {
      const qty = parseQty(inQty);
      const cost = inCost.trim() === "" ? null : parseAmount(inCost, currency);
      if (qty === null || (inCost.trim() !== "" && cost === null)) {
        setNote({ tone: "error", text: t("products.problem.qty") });
        return false;
      }
      await receiveStock(row.variantId, qty, cost, locationId, inExpiry || null);
      return true;
    },
    onSuccess: async (ok) => {
      if (!ok) return;
      setInQty("");
      setInCost("");
      setInExpiry("");
      const successText = t("products.received");
      setNote({ tone: "info", text: successText });
      toast.good(successText);
      await refresh();
    },
    onError: (e) => {
      const m = msg(e);
      setNote({ tone: "error", text: m });
      toast.error(m);
    },
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
      const successText = t("products.counted", { delta: formatQty(r.delta) });
      setNote({ tone: "info", text: successText });
      toast.good(successText);
      await refresh();
    },
    onError: (e) => {
      const m = msg(e);
      setNote({ tone: "error", text: m });
      toast.error(m);
    },
  });

  const expiryMutation = useMutation({
    mutationFn: (newDate: string | null) => setExpiry(row.variantId, newDate, locationId),
    onSuccess: async () => {
      const successText = t("products.expirySaved");
      setNote({ tone: "info", text: successText });
      toast.good(successText);
      await refresh();
    },
    onError: (e) => {
      const m = msg(e);
      setNote({ tone: "error", text: m });
      toast.error(m);
    },
  });

  const openPackMutation = useMutation({
    mutationFn: async () => {
      const p = parseInt(openPacksCount, 10);
      if (isNaN(p) || p <= 0) return null;
      return openPack(row.variantId, p, locationId, openPackNote);
    },
    onSuccess: async (res) => {
      if (!res) return;
      const piecesTotal = parseInt(openPacksCount, 10) * (row.breaksIntoQty ?? 1);
      const successText = t("products.openPackSuccess", { packs: openPacksCount, pieces: piecesTotal });
      setNote({
        tone: "info",
        text: successText,
      });
      toast.good(successText);
      setOpenPacksCount("1");
      setOpenPackNote("");
      await refresh();
    },
    onError: (e) => {
      const m = msg(e);
      setNote({ tone: "error", text: m });
      toast.error(m);
    },
  });

  const voidOpeningMutation = useMutation({
    mutationFn: (convId: string) => voidOpenPack(convId, "User requested void"),
    onSuccess: async () => {
      const successText = t("products.voidOpeningSuccess");
      setNote({ tone: "info", text: successText });
      toast.good(successText);
      await refresh();
    },
    onError: (e) => {
      const m = msg(e);
      setNote({ tone: "error", text: m });
      toast.error(m);
    },
  });

  if (!row.tracked) return <Card className="text-sm text-slate-600">{t("products.notTracked")}</Card>;

  const piece = availablePieces.find((p) => p.variantId === row.breaksIntoVariantId);
  const expiryStatus = getExpiryStatus(row.expiresOn);

  return (
    <Card className="grid gap-3" data-testid="stock-panel">
      <div className="flex items-center justify-between">
        <h3 className="font-medium">{t("products.stock")}</h3>
        {expiryStatus === "expired" ? (
          <Badge tone="warn">⚠️ {t("products.expired")}</Badge>
        ) : expiryStatus === "expiring_soon" ? (
          <Badge tone="warn">⏳ {t("products.expiringSoon")}</Badge>
        ) : null}
      </div>

      <div className="text-sm flex flex-wrap items-center justify-between gap-2 border-b border-slate-100 pb-2">
        <div>
          {t("products.onHand")}: <strong data-testid="on-hand">{formatQty(row.qty)}</strong> {row.unit}
          {row.cost > 0 ? <span className="text-slate-500"> · {t("products.cost")} {fmt(row.cost)}</span> : null}
        </div>
        {row.expiresOn ? (
          <div className="text-xs text-slate-600">
            {t("products.expiresOn")}: <strong>{row.expiresOn}</strong>
          </div>
        ) : null}
      </div>

      {/* Receive Stock */}
      <div className="grid gap-2 sm:grid-cols-[1fr_1fr_1fr_auto] sm:items-end">
        <Field label={t("products.receiveQty")}>
          <Input data-testid="receive-qty" inputMode="decimal" value={inQty} onChange={(e) => setInQty(e.target.value)} />
        </Field>
        <Field label={t("products.receiveCost")}>
          <Input data-testid="receive-cost" inputMode="decimal" value={inCost} onChange={(e) => setInCost(e.target.value)} />
        </Field>
        <Field label={t("products.expiryDateOptional")}>
          <Input type="date" value={inExpiry} onChange={(e) => setInExpiry(e.target.value)} />
        </Field>
        <Button data-testid="receive-go" disabled={receive.isPending} onClick={() => receive.mutate()}>
          {t("products.receive")}
        </Button>
      </div>

      {/* Set Expiry Date Directly */}
      <div className="grid gap-2 sm:grid-cols-[1fr_auto_auto] sm:items-end border-t border-slate-100 pt-2">
        <Field label={t("products.expiresOn")}>
          <Input type="date" value={expiryEdit} onChange={(e) => setExpiryEdit(e.target.value)} />
        </Field>
        <Button
          variant="outline"
          disabled={expiryMutation.isPending || !expiryEdit}
          onClick={() => expiryMutation.mutate(expiryEdit)}
        >
          {t("products.setExpiry")}
        </Button>
        {row.expiresOn ? (
          <Button
            variant="ghost"
            disabled={expiryMutation.isPending}
            onClick={() => {
              setExpiryEdit("");
              expiryMutation.mutate(null);
            }}
          >
            {t("products.clearExpiry")}
          </Button>
        ) : null}
      </div>

      {/* Count Stock */}
      <div className="grid gap-2 sm:grid-cols-[1fr_1fr_auto] sm:items-end border-t border-slate-100 pt-2">
        <Field label={t("products.countedQty")}>
          <Input data-testid="count-qty" inputMode="decimal" value={counted} onChange={(e) => setCounted(e.target.value)} />
        </Field>
        <Field label={t("products.reason")}>
          <Select value={reason} onChange={(e) => setReason(e.target.value as "counted" | "damage" | "other")}>
            <option value="counted">{t("products.reasons.counted")}</option>
            <option value="damage">{t("products.reasons.damage")}</option>
            <option value="other">{t("products.reasons.other")}</option>
          </Select>
        </Field>
        <Button variant="outline" data-testid="count-go" disabled={count.isPending} onClick={() => count.mutate()}>
          {t("products.setCount")}
        </Button>
      </div>

      {/* Tingi / Repack Open Pack */}
      {row.breaksIntoVariantId && row.breaksIntoQty ? (
        <div className="rounded border border-brand-100 bg-brand-50 p-3 grid gap-2.5 mt-2">
          <div className="flex items-center justify-between">
            <span className="font-semibold text-xs text-brand-text uppercase tracking-wide">
              {t("products.openPackTitle")}
            </span>
            <span className="text-xs text-brand-text">
              1 {row.unit} = {row.breaksIntoQty} {piece ? piece.unit : "pcs"} {piece ? `(${piece.name})` : ""}
            </span>
          </div>
          <p className="text-xs text-slate-600">{t("products.openPackHint")}</p>
          <div className="grid gap-2 sm:grid-cols-[1fr_1fr_auto] sm:items-end">
            <Field label={t("products.packsToOpen")}>
              <Input
                type="number"
                min="1"
                max="10000"
                value={openPacksCount}
                onChange={(e) => setOpenPacksCount(e.target.value)}
              />
            </Field>
            <Field label={t("products.piecesProduced")}>
              <div className="h-9 px-3 flex items-center font-bold text-brand-text bg-white border border-slate-200 rounded-md text-sm">
                {(parseInt(openPacksCount, 10) || 0) * row.breaksIntoQty} {piece?.unit ?? "pcs"}
              </div>
            </Field>
            <Button
              disabled={openPackMutation.isPending}
              onClick={() => openPackMutation.mutate()}
            >
              {openPackMutation.isPending ? t("products.openPack") : t("products.openPack")}
            </Button>
          </div>

          {/* Recent Openings list for this pack */}
          {conversionsQuery.data && conversionsQuery.data.filter((c) => c.pack_variant_id === row.variantId).length > 0 ? (
            <div className="mt-2 text-xs border-t border-brand-100 pt-2">
              <span className="font-medium text-slate-700 block mb-1">{t("products.recentOpenings")}:</span>
              <ul className="grid gap-1">
                {conversionsQuery.data
                  .filter((c) => c.pack_variant_id === row.variantId)
                  .slice(0, 5)
                  .map((c) => (
                    <li key={c.id} className="flex items-center justify-between bg-white px-2.5 py-1 rounded border border-slate-100">
                      <span>
                        {c.packs} pack(s) → {c.pieces} pcs ({new Date(c.converted_at).toLocaleDateString()})
                        {c.voided_at ? <span className="ml-1 text-red-600 font-medium">({t("sales.status.voided")})</span> : null}
                      </span>
                      {!c.voided_at ? (
                        <button
                          type="button"
                          className="text-red-600 hover:underline font-medium ml-2"
                          disabled={voidOpeningMutation.isPending}
                          onClick={() => voidOpeningMutation.mutate(c.id)}
                        >
                          {t("products.voidOpening")}
                        </button>
                      ) : null}
                    </li>
                  ))}
              </ul>
            </div>
          ) : null}
        </div>
      ) : null}

      {note ? <Alert tone={note.tone}>{note.text}</Alert> : null}
    </Card>
  );
}

/** Categories management modal */
function CategoryDialog({
  open,
  onOpenChange,
  categories,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  categories: Category[];
}) {
  const { t } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const toast = useToast();
  const [editingId, setEditingId] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [parentId, setParentId] = useState("");
  const [alert, setAlert] = useState<{ tone: "info" | "error"; text: string } | null>(null);

  const save = useMutation({
    mutationFn: () =>
      upsertCategory({
        id: editingId ?? undefined,
        name,
        parentId: parentId || null,
      }),
    onSuccess: async () => {
      setName("");
      setParentId("");
      setEditingId(null);
      const successText = t("products.categorySaved");
      setAlert({ tone: "info", text: successText });
      toast.good(successText);
      await qc.invalidateQueries({ queryKey: ["categories"] });
      await qc.invalidateQueries({ queryKey: ["products"] });
    },
    onError: (e) => {
      const m = msg(e);
      setAlert({ tone: "error", text: m });
      toast.error(m);
    },
  });

  const archive = useMutation({
    mutationFn: (id: string) => archiveCategory(id),
    onSuccess: async () => {
      const successText = t("products.categoryArchived");
      setAlert({ tone: "info", text: successText });
      toast.good(successText);
      await qc.invalidateQueries({ queryKey: ["categories"] });
      await qc.invalidateQueries({ queryKey: ["products"] });
    },
    onError: (e) => {
      const m = msg(e);
      setAlert({ tone: "error", text: m });
      toast.error(m);
    },
  });

  return (
    <Dialog open={open} onOpenChange={onOpenChange} title={t("products.manageCategories")} closeLabel={t("common:actions.close")}>
      <div className="grid gap-4">
        {/* Form */}
        <div className="rounded-lg border border-slate-200 bg-slate-50 p-3 grid gap-2.5">
          <h4 className="font-semibold text-sm">
            {editingId ? t("products.editCategory") : t("products.addCategory")}
          </h4>
          <Field label={t("products.categoryName")}>
            <Input value={name} maxLength={80} onChange={(e) => setName(e.target.value)} />
          </Field>
          <Field label={t("products.parentCategory")}>
            <Select value={parentId} onChange={(e) => setParentId(e.target.value)}>
              <option value="">{t("products.noParent")}</option>
              {categories
                .filter((c) => c.id !== editingId)
                .map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
            </Select>
          </Field>
          <div className="flex gap-2 mt-1">
            <Button disabled={save.isPending || !name.trim()} onClick={() => save.mutate()}>
              {t("products.save")}
            </Button>
            {editingId ? (
              <Button
                variant="ghost"
                onClick={() => {
                  setEditingId(null);
                  setName("");
                  setParentId("");
                }}
              >
                {t("sell.cancel")}
              </Button>
            ) : null}
          </div>
        </div>

        {alert ? <Alert tone={alert.tone}>{alert.text}</Alert> : null}

        {/* Existing Categories */}
        <div className="grid gap-1">
          <h4 className="font-medium text-xs text-slate-500 uppercase">{t("products.categories")}</h4>
          {categories.length === 0 ? (
            <p className="text-xs text-slate-500 italic py-2">No categories yet.</p>
          ) : (
            <ul className="max-h-56 overflow-y-auto divide-y divide-slate-100 rounded border border-slate-200 text-sm">
              {categories.map((c) => (
                <li key={c.id} className="p-2 flex items-center justify-between hover:bg-slate-50">
                  <span className="font-medium">
                    {c.name}
                    {c.parentId ? (
                      <span className="text-xs text-slate-500 ml-2 font-normal">
                        ({categories.find((p) => p.id === c.parentId)?.name ?? "Parent"})
                      </span>
                    ) : null}
                  </span>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      className="text-xs text-brand-text hover:underline"
                      onClick={() => {
                        setEditingId(c.id);
                        setName(c.name);
                        setParentId(c.parentId ?? "");
                      }}
                    >
                      {t("common:actions.edit")}
                    </button>
                    <button
                      type="button"
                      className="text-xs text-red-600 hover:underline"
                      disabled={archive.isPending}
                      onClick={() => archive.mutate(c.id)}
                    >
                      {t("products.archiveCategory")}
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </Dialog>
  );
}

/** CSV Import dialog */
function ImportDialog({
  open,
  onOpenChange,
  locationId,
  categories,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  locationId: string;
  categories: Category[];
}) {
  const { t } = useTranslation(["admin", "common"]);
  const qc = useQueryClient();
  const toast = useToast();
  const [parsed, setParsed] = useState<{ valid: ParsedProductImport[]; errors: string[] } | null>(null);
  const [importing, setImporting] = useState(false);
  const [progress, setProgress] = useState(0);
  const [doneMsg, setDoneMsg] = useState<string | null>(null);

  const handleFile = (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (evt) => {
      const text = String(evt.target?.result ?? "");
      const res = parseAndValidateImport(text);
      setParsed(res);
      setDoneMsg(null);
    };
    reader.readAsText(file);
  };

  const executeImport = async () => {
    if (!parsed || parsed.valid.length === 0) return;
    setImporting(true);
    setProgress(0);
    const catMap = new Map(categories.map((c) => [c.name.toLowerCase().trim(), c.id]));

    let count = 0;
    for (const item of parsed.valid) {
      try {
        const catId = item.category ? catMap.get(item.category.toLowerCase().trim()) ?? null : null;
        const res = await createProduct(
          {
            name: item.name,
            price: item.price,
            cost: item.cost,
            unit: item.unit,
            taxRate: item.taxRate,
            tracked: item.tracked,
            active: item.active,
            sku: item.sku,
            barcode: item.barcode,
            reorderPoint: item.reorderPoint,
            categoryId: catId,
          },
          item.openingQty,
          locationId,
        );

        if (item.expiresOn) {
          await setExpiry(res.variantId, item.expiresOn, locationId);
        }
        count++;
        setProgress(Math.round((count / parsed.valid.length) * 100));
      } catch (err) {
        console.error("Failed to import item", item.name, err);
      }
    }

    setImporting(false);
    const successMsg = t("products.importSuccess", { count });
    setDoneMsg(successMsg);
    toast.good(successMsg);
    await Promise.all([qc.invalidateQueries({ queryKey: ["products"] }), qc.invalidateQueries({ queryKey: ["sellables"] })]);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange} title={t("products.importDialogTitle")} closeLabel={t("common:actions.close")}>
      <div className="grid gap-3">
        <p className="text-xs text-slate-500">{t("products.importDialogDesc")}</p>

        <Field label={t("products.importFileLabel")}>
          <input
            type="file"
            accept=".csv"
            onChange={handleFile}
            className="block w-full text-xs text-slate-500 file:mr-3 file:py-1.5 file:px-3 file:rounded-md file:border-0 file:text-xs file:font-semibold file:bg-slate-100 hover:file:bg-slate-200"
          />
        </Field>

        {parsed ? (
          <div className="grid gap-2 text-xs">
            <div className="font-medium text-emerald-800 bg-emerald-50 border border-emerald-200 p-2.5 rounded">
              ✓ {t("products.importPreview", { valid: parsed.valid.length })}
            </div>
            {parsed.errors.length > 0 ? (
              <div className="text-amber-800 bg-amber-50 border border-amber-200 p-2.5 rounded max-h-32 overflow-y-auto">
                <span className="font-semibold">{t("products.importErrors", { count: parsed.errors.length })}</span>
                <ul className="list-disc pl-4 mt-1">
                  {parsed.errors.slice(0, 10).map((err, i) => (
                    <li key={i}>{err}</li>
                  ))}
                </ul>
              </div>
            ) : null}
          </div>
        ) : null}

        {importing ? (
          <div className="grid gap-1">
            <span className="text-xs text-slate-600 font-medium">
              {t("products.importing")} ({progress}%)
            </span>
            <div className="h-2 w-full bg-slate-100 rounded-full overflow-hidden">
              <div className="h-full bg-brand-600 transition-all" style={{ width: `${progress}%` }} />
            </div>
          </div>
        ) : null}

        {doneMsg ? <Alert tone="info">{doneMsg}</Alert> : null}

        <div className="flex justify-end gap-2 mt-2">
          <Button
            disabled={!parsed || parsed.valid.length === 0 || importing}
            onClick={executeImport}
          >
            {t("products.startImport")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

/** Products and stock: catalog, categories, tingi repack, expiry dates, and CSV import/export. */
export function ProductsPage() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const { access, can } = useSession();
  const qc = useQueryClient();
  const toast = useToast();
  const currency = access.tenant.base_currency;
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);
  const { activeStore } = useActiveLocation();
  const store = (activeStore && can("catalog.manage", activeStore.id)) ? activeStore : access.locations.find((l) => l.type === "store" && can("catalog.manage", l.id));

  const [search, setSearch] = useState("");
  const [filterCategory, setFilterCategory] = useState("");
  const [onlyLow, setOnlyLow] = useState(false);
  const [onlyExpiring, setOnlyExpiring] = useState(false);
  const [adding, setAdding] = useState(false);
  const [openId, setOpenId] = useState<string | null>(null);
  const [archiveError, setArchiveError] = useState<string | null>(null);
  const [categoryModal, setCategoryModal] = useState(false);
  const [importModal, setImportModal] = useState(false);

  const categoriesQuery = useQuery({
    queryKey: ["categories"],
    queryFn: fetchCategories,
  });

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
      toast.good(t("admin:products.saved"));
      await Promise.all([qc.invalidateQueries({ queryKey: ["products"] }), qc.invalidateQueries({ queryKey: ["sellables"] })]);
    },
    onError: (e) => {
      const m = msg(e);
      setArchiveError(m);
      toast.error(m);
    },
  });

  if (!store) {
    return (
      <Card>
        <p>{t("admin:sell.noStore")}</p>
      </Card>
    );
  }

  const needle = search.trim().toLowerCase();
  const rows = (q.data ?? []).filter((r) => {
    const matchesSearch = !needle || r.name.toLowerCase().includes(needle) || r.sku.toLowerCase().includes(needle) || r.barcode?.toLowerCase() === needle;
    const matchesCategory = !filterCategory || r.categoryId === filterCategory;
    const matchesLow = !onlyLow || ["out", "low"].includes(stockStatus(r));
    const expiryStatus = getExpiryStatus(r.expiresOn);
    const matchesExpiry = !onlyExpiring || ["expired", "expiring_soon"].includes(expiryStatus);
    return matchesSearch && matchesCategory && matchesLow && matchesExpiry;
  });

  const open = q.data?.find((r) => r.variantId === openId) ?? null;
  const canStock = can("stock.adjust_store", store.id);
  const categories = categoriesQuery.data ?? [];

  const handleExportCsv = () => {
    if (!q.data) return;
    const csv = exportProductsCsv(q.data, currency);
    downloadCsv(csv, `products-${new Date().toISOString().slice(0, 10)}.csv`);
  };

  return (
    <div className="grid gap-4 lg:grid-cols-[1fr_440px]">
      <section className="grid content-start gap-3">
        <PageHeader
          title={t("admin:products.title")}
          actions={
            <>
              <Button variant="outline" size="sm" onClick={() => setCategoryModal(true)}>
                📁 {t("admin:products.categories")}
              </Button>
              <Button variant="outline" size="sm" onClick={handleExportCsv} disabled={!q.data?.length}>
                ⬇️ {t("admin:products.exportCsv")}
              </Button>
              <Button variant="outline" size="sm" onClick={() => setImportModal(true)}>
                ⬆️ {t("admin:products.importCsv")}
              </Button>
              <Button size="sm" data-testid="add-product" onClick={() => { setAdding(true); setOpenId(null); }}>
                + {t("admin:products.add")}
              </Button>
            </>
          }
        />

        <div className="grid gap-2 sm:grid-cols-[1fr_auto]">
          <Input data-testid="products-search" placeholder={t("admin:sell.search")} value={search} onChange={(e) => setSearch(e.target.value)} />
          <Select value={filterCategory} onChange={(e) => setFilterCategory(e.target.value)} className="sm:w-48">
            <option value="">{t("admin:products.allCategories")}</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </Select>
        </div>

        <div className="flex flex-wrap items-center gap-4 text-sm">
          <label className="flex items-center gap-2">
            <input type="checkbox" checked={onlyLow} onChange={(e) => setOnlyLow(e.target.checked)} />
            {t("admin:products.onlyLow")}
          </label>
          <label className="flex items-center gap-2">
            <input type="checkbox" checked={onlyExpiring} onChange={(e) => setOnlyExpiring(e.target.checked)} />
            {t("admin:products.onlyExpiring")}
          </label>
        </div>

        {q.isPending ? <Card className="p-8 text-center text-sm text-slate-500">{t("admin:sell.loading")}</Card> : null}
        {q.isError ? <ErrorState message={t("admin:sell.loadError")} onRetry={() => q.refetch()} retryLabel={t("common:actions.retry")} /> : null}
        {q.data && q.data.length === 0 ? (
          <EmptyState
            title={t("admin:products.empty")}
            action={
              <Button size="sm" onClick={() => { setAdding(true); setOpenId(null); }}>
                + {t("admin:products.add")}
              </Button>
            }
          />
        ) : null}

        <ul className="grid gap-2">
          {rows.map((r) => {
            const status = stockStatus(r);
            const expiry = getExpiryStatus(r.expiresOn);
            const isSelected = r.variantId === openId;
            return (
              <li key={r.variantId}>
                <button
                  type="button"
                  data-testid={`row-${r.sku}`}
                  onClick={() => { setOpenId(r.variantId); setAdding(false); setArchiveError(null); }}
                  className={`flex w-full items-center justify-between gap-3 rounded-lg border bg-white p-3 text-left text-sm transition-all hover:bg-slate-50 ${isSelected ? "border-brand-600 ring-2 ring-brand-600/20 bg-brand-50/20" : "border-slate-200"}`}
                >
                  <span className="min-w-0">
                    <span className="block font-medium truncate text-slate-900">{r.name}</span>
                    <span className="flex flex-wrap items-center gap-1.5 text-xs text-slate-500 mt-1">
                      <span className="font-mono">{r.sku}</span>
                      {r.categoryName ? <span className="bg-slate-100 text-slate-700 px-1.5 py-0.5 rounded font-medium">{r.categoryName}</span> : null}
                      {r.breaksIntoVariantId ? <span className="text-brand-text font-medium">📦 Pack (1→{r.breaksIntoQty})</span> : null}
                      {r.active ? "" : <span className="text-slate-400">· {t("admin:products.inactive")}</span>}
                    </span>
                  </span>
                  <span className="flex shrink-0 items-center gap-2">
                    {expiry === "expired" ? <Badge tone="warn">⚠️ {t("admin:products.expired")}</Badge> : null}
                    {expiry === "expiring_soon" ? <Badge tone="warn">⏳ {t("admin:products.expiringSoon")}</Badge> : null}
                    {status === "out" ? <Badge tone="warn">{t("admin:products.out")}</Badge> : null}
                    {status === "low" ? <Badge tone="warn">{t("admin:products.low")}</Badge> : null}
                    <span className="text-right">
                      <span className="block font-semibold tabular-nums">{r.price === null ? t("admin:products.noPrice") : fmt(r.price)}</span>
                      {r.tracked ? (
                        <span className="text-xs text-slate-500 tabular-nums">
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
          <ProductForm
            row={null}
            currency={currency}
            locationId={store.id}
            categories={categories}
            availablePieces={q.data ?? []}
            onSaved={() => setAdding(false)}
            onCancel={() => setAdding(false)}
          />
        ) : open ? (
          <>
            <ProductForm
              key={open.variantId}
              row={open}
              currency={currency}
              locationId={store.id}
              categories={categories}
              availablePieces={q.data ?? []}
              onSaved={() => undefined}
              onCancel={() => setOpenId(null)}
            />
            {canStock ? (
              <StockPanel
                key={`s-${open.variantId}`}
                row={open}
                currency={currency}
                locationId={store.id}
                fmt={fmt}
                availablePieces={q.data ?? []}
              />
            ) : null}
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

      {/* Category Manager Modal */}
      <CategoryDialog
        open={categoryModal}
        onOpenChange={setCategoryModal}
        categories={categories}
      />

      {/* Import CSV Modal */}
      <ImportDialog
        open={importModal}
        onOpenChange={setImportModal}
        locationId={store.id}
        categories={categories}
      />
    </div>
  );
}
