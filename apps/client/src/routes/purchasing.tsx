import { Fragment, useEffect, useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useTranslation } from "react-i18next";
import { formatMoney, money, uuidv7 } from "@pos/core";
import { Alert, Badge, Button, Card, Dialog, Field, Input, Select, Table, PageHeader, Tabs, TabPanel, EmptyState, ErrorState, useToast } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { formatQty } from "../lib/product-math.ts";
import {
  buildPoItems,
  buildReceiveItems,
  lineValue,
  poActions,
  poProgress,
  poStatusTone,
  remainingQty,
  type LineError,
  type PoLineDraft,
  type ReceiveRow,
} from "../lib/purchasing-math.ts";
import {
  archiveSupplier,
  cancelPo,
  closePo,
  createPo,
  listGoodsReceipts,
  listPurchaseOrders,
  listSuppliers,
  listVariantOptions,
  receivePo,
  receiveWithoutPo,
  submitPo,
  updatePo,
  upsertSupplier,
  type PurchaseOrder,
  type Supplier,
  type VariantOption,
} from "../lib/purchasing-api.ts";

type Tab = "orders" | "suppliers" | "receipts";

const blankLine = (): PoLineDraft => ({ variantId: "", qtyText: "", costText: "" });
const productLabel = (v: VariantOption | null) => (v ? `${v.product?.name ?? v.sku} · ${v.sku}` : "?");

export function PurchasingPage() {
  const { t } = useTranslation("admin");
  const [tab, setTab] = useState<Tab>("orders");
  return (
    <div className="grid gap-4">
      <PageHeader title={t("purchasing.title")} subtitle={t("purchasing.subtitle")} />
      <Tabs
        value={tab}
        onValueChange={(v) => setTab(v as Tab)}
        label={t("purchasing.title")}
        tabs={(["orders", "suppliers", "receipts"] as const).map((k) => ({ value: k, label: t(`purchasing.tabs.${k}`), testId: `tab-${k}` }))}
      >
        <TabPanel value={tab}>{tab === "orders" ? <OrdersTab /> : tab === "suppliers" ? <SuppliersTab /> : <ReceiptsTab />}</TabPanel>
      </Tabs>
    </div>
  );
}

/* ------------------------------------------------------------------------------------------------ orders */

export interface NewOrderInitialData {
  warehouseId?: string;
  supplierId?: string;
  expectedAt?: string;
  notes?: string;
  lines?: PoLineDraft[];
}

type Modal =
  | { kind: "new"; initialData?: NewOrderInitialData }
  | { kind: "walkin" }
  | { kind: "detail" | "receive" | "cancel" | "close" | "edit"; po: PurchaseOrder }
  | null;

function useWarehouses() {
  const { access, can } = useSession();
  return access.locations.filter((l) => l.type === "warehouse" && can("purchasing.manage", l.id));
}

function OrdersTab() {
  const { t } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const toast = useToast();
  const warehouses = useWarehouses();
  const [status, setStatus] = useState("");
  const [warehouseId, setWarehouseId] = useState("");
  const [modal, setModal] = useState<Modal>(null);
  const [notice, setNotice] = useState<string | null>(null);

  useEffect(() => {
    // 1. Check sessionStorage for draft PO (e.g. from low stock shortfall)
    const draftJson = sessionStorage.getItem("xzactopos:draft-po");
    if (draftJson) {
      sessionStorage.removeItem("xzactopos:draft-po");
      try {
        const draft = JSON.parse(draftJson) as NewOrderInitialData;
        setModal({ kind: "new", initialData: draft });
        if (draft.warehouseId) {
          setWarehouseId(draft.warehouseId);
        }
        return;
      } catch {
        // ignore parse error
      }
    }

    // 2. Check URL search params: ?warehouseId=...&variantId=...&qty=...
    const sp = new URLSearchParams(window.location.search);
    const qWarehouse = sp.get("warehouseId");
    const qVariant = sp.get("variantId");
    const qQty = sp.get("qty");
    if (qWarehouse || qVariant) {
      const newUrl = window.location.pathname;
      window.history.replaceState({}, "", newUrl);

      const initLines: PoLineDraft[] = qVariant
        ? [{ variantId: qVariant, qtyText: qQty ?? "1", costText: "" }]
        : [blankLine()];

      setModal({
        kind: "new",
        initialData: {
          warehouseId: qWarehouse ?? undefined,
          lines: initLines,
        },
      });
      if (qWarehouse) {
        setWarehouseId(qWarehouse);
      }
    }
  }, []);

  const orders = useQuery({ queryKey: ["po", "orders"], queryFn: listPurchaseOrders });
  const rows = (orders.data ?? []).filter((p) => (!status || p.status === status) && (!warehouseId || p.warehouse_id === warehouseId));

  const submit = useMutation({
    mutationFn: (id: string) => submitPo(id),
    onSuccess: () => {
      toast.good(t("purchasing.action.submit"));
      void qc.invalidateQueries({ queryKey: ["po"] });
    },
  });

  const handleDone = (m: string) => {
    setNotice(m);
    toast.good(m);
  };

  return (
    <div className="grid gap-4">
      <Card className="flex flex-wrap items-end gap-3">
        <Field label={t("purchasing.orders.filterStatus")}>
          <Select value={status} onChange={(e) => setStatus(e.target.value)} data-testid="filter-status">
            <option value="">{t("purchasing.orders.allStatuses")}</option>
            {(["draft", "ordered", "partly_received", "received", "cancelled"] as const).map((s) => (
              <option key={s} value={s}>
                {t(`purchasing.status.${s}`)}
              </option>
            ))}
          </Select>
        </Field>
        <Field label={t("purchasing.orders.filterWarehouse")}>
          <Select value={warehouseId} onChange={(e) => setWarehouseId(e.target.value)}>
            <option value="">{t("purchasing.orders.allWarehouses")}</option>
            {warehouses.map((w) => (
              <option key={w.id} value={w.id}>
                {w.code} · {w.name}
              </option>
            ))}
          </Select>
        </Field>
        <div className="ml-auto flex gap-2">
          <Button variant="outline" onClick={() => setModal({ kind: "walkin" })} disabled={warehouses.length === 0} data-testid="open-walkin">
            {t("purchasing.orders.receiveNoPo")}
          </Button>
          <Button onClick={() => setModal({ kind: "new" })} disabled={warehouses.length === 0} data-testid="open-new-order">
            {t("purchasing.orders.new")}
          </Button>
        </div>
      </Card>

      {warehouses.length === 0 ? <Alert tone="info">{t("purchasing.orders.noWarehouses")}</Alert> : null}
      {notice ? <Alert tone="info">{notice}</Alert> : null}
      {orders.isError ? <ErrorState message={msg(orders.error)} onRetry={() => orders.refetch()} retryLabel={t("common:actions.retry")} /> : null}
      {submit.isError ? <ErrorState message={msg(submit.error)} /> : null}

      <Card className="overflow-x-auto p-0">
        {orders.isLoading ? (
          <p className="p-4 text-sm text-slate-500">{t("purchasing.loading")}</p>
        ) : rows.length === 0 ? (
          <div data-testid="no-orders" className="p-4">
            <EmptyState title={t("purchasing.orders.none")} />
          </div>
        ) : (
          <Table bare>
            <thead>
              <tr className="border-b border-slate-200 text-slate-500">
                {(["poNo", "warehouse", "supplier", "expected", "status", "progress", "actions"] as const).map((c) => (
                  <th key={c} className="px-3 py-2 font-medium">
                    {t(`purchasing.orders.${c}`)}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((po) => {
                const progress = poProgress(po.po_items);
                const acts = poActions(po.status, po.po_items.some((i) => i.qty_received > 0));
                return (
                  <tr key={po.id} className="border-b border-slate-100 align-top" data-testid={`po-${po.po_no}`}>
                    <td className="px-3 py-2 font-mono text-xs">{po.po_no}</td>
                    <td className="px-3 py-2">{po.warehouse?.code ?? "—"}</td>
                    <td className="px-3 py-2">{po.supplier?.name ?? "—"}</td>
                    <td className="px-3 py-2">{po.expected_at ?? "—"}</td>
                    <td className="px-3 py-2">
                      <Badge tone={poStatusTone(po.status)}>{t(`purchasing.status.${po.status}`)}</Badge>
                      {po.short_closed_at ? <div className="mt-1 text-xs text-slate-500">{t("purchasing.orders.shortClosed")}</div> : null}
                    </td>
                    <td className="px-3 py-2">{po.status === "draft" || po.status === "cancelled" ? "—" : `${progress.percent}%`}</td>
                    <td className="px-3 py-2">
                      <div className="flex flex-wrap gap-1">
                        <Button size="sm" variant="ghost" onClick={() => setModal({ kind: "detail", po })}>
                          {t("purchasing.action.details")}
                        </Button>
                        {po.status === "draft" ? (
                          <Button size="sm" variant="outline" onClick={() => setModal({ kind: "edit", po })} data-testid={`edit-${po.po_no}`}>
                            {t("purchasing.action.edit", "Edit")}
                          </Button>
                        ) : null}
                        {acts.submit ? (
                          <Button size="sm" variant="outline" disabled={submit.isPending} onClick={() => submit.mutate(po.id)} data-testid={`submit-${po.po_no}`}>
                            {t("purchasing.action.submit")}
                          </Button>
                        ) : null}
                        {acts.receive ? (
                          <Button size="sm" onClick={() => setModal({ kind: "receive", po })} data-testid={`receive-${po.po_no}`}>
                            {t("purchasing.action.receive")}
                          </Button>
                        ) : null}
                        {acts.close ? (
                          <Button size="sm" variant="outline" onClick={() => setModal({ kind: "close", po })}>
                            {t("purchasing.action.close")}
                          </Button>
                        ) : null}
                        {acts.cancel ? (
                          <Button size="sm" variant="ghost" onClick={() => setModal({ kind: "cancel", po })}>
                            {t("purchasing.action.cancel")}
                          </Button>
                        ) : null}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </Table>
        )}
      </Card>

      {modal?.kind === "new" ? (
        <NewOrderDialog
          initialData={modal.initialData}
          onClose={() => setModal(null)}
          onDone={(m) => {
            handleDone(m);
            setModal(null);
          }}
        />
      ) : null}
      {modal?.kind === "edit" ? <EditOrderDialog po={modal.po} onClose={() => setModal(null)} onDone={(m) => { handleDone(m); setModal(null); }} /> : null}
      {modal?.kind === "walkin" ? <WalkInDialog onClose={() => setModal(null)} onDone={(m) => { handleDone(m); setModal(null); }} /> : null}
      {modal?.kind === "detail" ? <DetailDialog po={modal.po} onClose={() => setModal(null)} /> : null}
      {modal?.kind === "receive" ? <ReceiveDialog po={modal.po} onClose={() => setModal(null)} onDone={(m) => { handleDone(m); setModal(null); }} /> : null}
      {modal?.kind === "cancel" ? <CancelDialog po={modal.po} onClose={() => setModal(null)} /> : null}
      {modal?.kind === "close" ? <CloseDialog po={modal.po} onClose={() => setModal(null)} /> : null}
    </div>
  );
}

/* ------------------------------------------------------------------------------------------------ line editor */

function LinesEditor({
  lines,
  onChange,
  variants,
  currency,
  errors,
}: {
  lines: PoLineDraft[];
  onChange: (l: PoLineDraft[]) => void;
  variants: VariantOption[];
  currency: string;
  errors: Array<LineError | null>;
}) {
  const { t } = useTranslation("admin");
  const [filter, setFilter] = useState("");
  const set = (i: number, patch: Partial<PoLineDraft>) => onChange(lines.map((l, j) => (j === i ? { ...l, ...patch } : l)));

  const lineVariants = (selectedId: string) => {
    const q = filter.trim().toLowerCase();
    if (!q) return variants;
    return variants.filter((v) => {
      if (v.id === selectedId) return true;
      const name = (v.product?.name ?? "").toLowerCase();
      const sku = (v.sku ?? "").toLowerCase();
      return name.includes(q) || sku.includes(q);
    });
  };

  return (
    <div className="grid gap-2">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="text-sm font-medium">{t("purchasing.form.lines")}</span>
        <div className="flex items-center gap-2">
          <Input
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            placeholder={t("purchasing.form.filterProducts", "Filter products...")}
            className="h-8 w-44 text-xs"
            data-testid="filter-lines-product"
          />
          <Button size="sm" variant="outline" onClick={() => onChange([...lines, blankLine()])} data-testid="add-line">
            {t("purchasing.form.addLine")}
          </Button>
        </div>
      </div>
      {lines.map((l, i) => (
        <div key={i} className="grid gap-1 rounded-md border border-slate-200 p-2" data-testid={`line-${i}`}>
          <div className="grid grid-cols-[1fr_5.5rem_6.5rem_auto] items-start gap-2">
            <Select aria-label={t("purchasing.form.product")} value={l.variantId} onChange={(e) => set(i, { variantId: e.target.value })} data-testid={`line-${i}-product`}>
              <option value="">{t("purchasing.form.selectProduct")}</option>
              {lineVariants(l.variantId).map((v) => (
                <option key={v.id} value={v.id}>
                  {productLabel(v)}
                </option>
              ))}
            </Select>
            <Input aria-label={t("purchasing.form.qty")} placeholder={t("purchasing.form.qty")} inputMode="decimal" value={l.qtyText} onChange={(e) => set(i, { qtyText: e.target.value })} data-testid={`line-${i}-qty`} />
            <Input aria-label={t("purchasing.form.cost")} placeholder={t("purchasing.form.cost")} title={t("purchasing.form.costHint", { currency })} inputMode="decimal" value={l.costText} onChange={(e) => set(i, { costText: e.target.value })} data-testid={`line-${i}-cost`} />
            <Button size="sm" variant="ghost" aria-label={t("purchasing.form.removeLine")} disabled={lines.length === 1} onClick={() => onChange(lines.filter((_, j) => j !== i))}>
              ✕
            </Button>
          </div>
          {errors[i] ? (
            <span role="alert" className="text-xs text-red-600">
              {t(`purchasing.lineError.${errors[i]}`)}
            </span>
          ) : null}
        </div>
      ))}
    </div>
  );
}

/* ------------------------------------------------------------------------------------------------ new order */

export function NewOrderDialog({
  initialData,
  onClose,
  onDone,
}: {
  initialData?: NewOrderInitialData;
  onClose: () => void;
  onDone: (message: string) => void;
}) {
  const { t } = useTranslation("admin");
  const { access } = useSession();
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const warehouses = useWarehouses();
  const suppliers = useQuery({ queryKey: ["po", "suppliers"], queryFn: listSuppliers });
  const variants = useQuery({ queryKey: ["po", "variants"], queryFn: listVariantOptions });
  const [id] = useState(() => uuidv7()); // one id per dialog, so a retry after a dropped connection is a replay
  const [warehouseId, setWarehouseId] = useState(
    initialData?.warehouseId || (warehouses.length === 1 ? warehouses[0]!.id : "")
  );
  const [supplierId, setSupplierId] = useState(initialData?.supplierId || "");
  const [expectedAt, setExpectedAt] = useState(initialData?.expectedAt || "");
  const [notes, setNotes] = useState(initialData?.notes || "");
  const [lines, setLines] = useState<PoLineDraft[]>(
    initialData?.lines && initialData.lines.length > 0
      ? initialData.lines
      : [blankLine()]
  );
  const [formError, setFormError] = useState<string | null>(null);
  const [rowErrors, setRowErrors] = useState<Array<LineError | null>>([]);
  const currency = access.tenant.base_currency;

  const save = useMutation({
    mutationFn: async (placeNow: boolean) => {
      const built = buildPoItems(lines, currency);
      setRowErrors(built.rowErrors);
      if (!warehouseId) throw new Error("needWarehouse");
      if (!supplierId) throw new Error("needSupplier");
      if (built.empty) throw new Error("needLines");
      if (!built.ok) throw new Error("rows");
      await createPo({ id, warehouseId, supplierId, expectedAt, notes, items: built.items });
      if (placeNow) await submitPo(id);
      return id;
    },
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ["po"] });
      const list = await qc.fetchQuery({ queryKey: ["po", "orders"], queryFn: listPurchaseOrders });
      onDone(t("purchasing.form.created", { no: list.find((p) => p.id === id)?.po_no ?? "" }));
    },
    onError: (e) => {
      const m = e instanceof Error ? e.message : "";
      if (m === "needWarehouse") setFormError(t("purchasing.form.needWarehouse"));
      else if (m === "needSupplier") setFormError(t("purchasing.form.needSupplier"));
      else if (m === "needLines") setFormError(t("purchasing.form.needLines"));
      else if (m === "rows") setFormError(null);
      else setFormError(msg(e));
    },
  });

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={t("purchasing.form.title")} closeLabel={t("purchasing.close")}>
      <div className="grid gap-3">
        <Field label={t("purchasing.form.warehouse")}>
          <Select value={warehouseId} onChange={(e) => setWarehouseId(e.target.value)} data-testid="new-warehouse">
            <option value="">{t("purchasing.form.selectWarehouse")}</option>
            {warehouses.map((w) => (
              <option key={w.id} value={w.id}>
                {w.code} · {w.name}
              </option>
            ))}
          </Select>
        </Field>
        <Field label={t("purchasing.form.supplier")}>
          <Select value={supplierId} onChange={(e) => setSupplierId(e.target.value)} data-testid="new-supplier">
            <option value="">{t("purchasing.form.selectSupplier")}</option>
            {(suppliers.data ?? []).map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </Select>
        </Field>
        {suppliers.data && suppliers.data.length === 0 ? <Alert tone="info">{t("purchasing.form.noSuppliers")}</Alert> : null}
        <Field label={t("purchasing.form.expectedOn")}>
          <Input type="date" value={expectedAt} onChange={(e) => setExpectedAt(e.target.value)} />
        </Field>
        <Field label={t("purchasing.form.notes")}>
          <Input value={notes} placeholder={t("purchasing.form.notesPlaceholder")} onChange={(e) => setNotes(e.target.value)} />
        </Field>
        <LinesEditor lines={lines} onChange={setLines} variants={variants.data ?? []} currency={currency} errors={rowErrors} />
        {formError ? <Alert>{formError}</Alert> : null}
        <div className="flex justify-end gap-2">
          <Button variant="outline" disabled={save.isPending} onClick={() => save.mutate(false)} data-testid="save-draft">
            {save.isPending ? t("purchasing.saving") : t("purchasing.form.saveDraft")}
          </Button>
          <Button disabled={save.isPending} onClick={() => save.mutate(true)} data-testid="place-now">
            {t("purchasing.form.placeNow")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

function EditOrderDialog({ po, onClose, onDone }: { po: PurchaseOrder; onClose: () => void; onDone: (message: string) => void }) {
  const { t } = useTranslation("admin");
  const { access } = useSession();
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const suppliers = useQuery({ queryKey: ["po", "suppliers"], queryFn: listSuppliers });
  const variants = useQuery({ queryKey: ["po", "variants"], queryFn: listVariantOptions });
  const [supplierId, setSupplierId] = useState(po.supplier_id);
  const [expectedAt, setExpectedAt] = useState(po.expected_at ?? "");
  const [notes, setNotes] = useState(po.notes ?? "");
  const [lines, setLines] = useState<PoLineDraft[]>(() =>
    po.po_items.length > 0
      ? po.po_items.map((i) => ({
          variantId: i.variant_id,
          qtyText: String(i.qty_ordered),
          costText: i.unit_cost !== null && i.unit_cost !== undefined ? (i.unit_cost / 100).toFixed(2) : "",
        }))
      : [blankLine()]
  );
  const [formError, setFormError] = useState<string | null>(null);
  const [rowErrors, setRowErrors] = useState<Array<LineError | null>>([]);
  const currency = access.tenant.base_currency;

  const save = useMutation({
    mutationFn: async (placeNow: boolean) => {
      const built = buildPoItems(lines, currency);
      setRowErrors(built.rowErrors);
      if (!supplierId) throw new Error("needSupplier");
      if (built.empty) throw new Error("needLines");
      if (!built.ok) throw new Error("rows");
      await updatePo({ poId: po.id, supplierId, expectedAt, notes, items: built.items });
      if (placeNow) await submitPo(po.id);
      return po.id;
    },
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ["po"] });
      onDone(t("purchasing.form.updated", "Purchase order updated"));
    },
    onError: (e) => {
      const m = e instanceof Error ? e.message : "";
      if (m === "needSupplier") setFormError(t("purchasing.form.needSupplier"));
      else if (m === "needLines") setFormError(t("purchasing.form.needLines"));
      else if (m === "rows") setFormError(null);
      else setFormError(msg(e));
    },
  });

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={`${t("purchasing.action.edit", "Edit")} ${po.po_no}`} closeLabel={t("purchasing.close")}>
      <div className="grid gap-3">
        <Field label={t("purchasing.form.warehouse")}>
          <Input disabled value={po.warehouse ? `${po.warehouse.code} · ${po.warehouse.name}` : po.warehouse_id} />
        </Field>
        <Field label={t("purchasing.form.supplier")}>
          <Select value={supplierId} onChange={(e) => setSupplierId(e.target.value)} data-testid="edit-supplier">
            <option value="">{t("purchasing.form.selectSupplier")}</option>
            {(suppliers.data ?? []).map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </Select>
        </Field>
        <Field label={t("purchasing.form.expectedOn")}>
          <Input type="date" value={expectedAt} onChange={(e) => setExpectedAt(e.target.value)} data-testid="edit-expected" />
        </Field>
        <Field label={t("purchasing.form.notes")}>
          <Input value={notes} placeholder={t("purchasing.form.notesPlaceholder")} onChange={(e) => setNotes(e.target.value)} data-testid="edit-notes" />
        </Field>
        <LinesEditor lines={lines} onChange={setLines} variants={variants.data ?? []} currency={currency} errors={rowErrors} />
        {formError ? <Alert>{formError}</Alert> : null}
        <div className="flex justify-end gap-2">
          <Button variant="outline" disabled={save.isPending} onClick={() => save.mutate(false)} data-testid="save-edit">
            {save.isPending ? t("purchasing.saving") : t("purchasing.form.saveChanges", "Save Changes")}
          </Button>
          <Button disabled={save.isPending} onClick={() => save.mutate(true)} data-testid="edit-place-now">
            {t("purchasing.form.placeNow")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

/* ------------------------------------------------------------------------------------------------ detail / cancel / close */

function DetailDialog({ po, onClose }: { po: PurchaseOrder; onClose: () => void }) {
  const { t, i18n } = useTranslation("admin");
  const { access } = useSession();
  const currency = access.tenant.base_currency;
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);
  const total = po.po_items.reduce((s, i) => s + (lineValue(i.qty_ordered, i.unit_cost) ?? 0), 0);
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={t("purchasing.detail.title", { no: po.po_no })} closeLabel={t("purchasing.close")}>
      <div className="grid gap-3 text-sm">
        <div className="flex flex-wrap items-center gap-2">
          <Badge tone={poStatusTone(po.status)}>{t(`purchasing.status.${po.status}`)}</Badge>
          <span>
            {po.warehouse?.code} · {po.supplier?.name}
          </span>
        </div>
        {po.notes ? <p className="text-slate-600">{po.notes}</p> : null}
        {po.cancel_reason ? <p className="text-slate-600">{t("purchasing.detail.cancelReason", { reason: po.cancel_reason })}</p> : null}
        {po.close_reason ? <p className="text-slate-600">{t("purchasing.detail.closeReason", { reason: po.close_reason })}</p> : null}
        {po.po_items.length === 0 ? (
          <p className="text-slate-500">{t("purchasing.detail.noLines")}</p>
        ) : (
          <Table bare>
            <thead>
              <tr className="border-b border-slate-200 text-slate-500">
                <th className="py-1 font-medium">{t("purchasing.form.product")}</th>
                <th className="py-1 font-medium">{t("purchasing.detail.ordered")}</th>
                <th className="py-1 font-medium">{t("purchasing.detail.received")}</th>
                <th className="py-1 font-medium">{t("purchasing.detail.remaining")}</th>
                <th className="py-1 font-medium">{t("purchasing.detail.cost")}</th>
              </tr>
            </thead>
            <tbody>
              {po.po_items.map((i) => (
                <tr key={i.id} className="border-b border-slate-100">
                  <td className="py-1">{productLabel(i.variant)}</td>
                  <td className="py-1">{formatQty(i.qty_ordered)}</td>
                  <td className="py-1">{formatQty(i.qty_received)}</td>
                  <td className="py-1">{formatQty(remainingQty(i))}</td>
                  <td className="py-1">{i.unit_cost === null ? "—" : fmt(i.unit_cost)}</td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
        <p className="text-right font-medium">
          {t("purchasing.detail.value")}: {fmt(total)}
        </p>
      </div>
    </Dialog>
  );
}

function CancelDialog({ po, onClose }: { po: PurchaseOrder; onClose: () => void }) {
  const { t } = useTranslation("admin");
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const [reason, setReason] = useState("");
  const run = useMutation({
    mutationFn: () => cancelPo(po.id, reason),
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ["po"] });
      onClose();
    },
  });
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={t("purchasing.cancel.title", { no: po.po_no })} closeLabel={t("purchasing.close")}>
      <div className="grid gap-3">
        <Field label={t("purchasing.cancel.reason")}>
          <Input value={reason} onChange={(e) => setReason(e.target.value)} data-testid="cancel-reason" />
        </Field>
        {run.isError ? <Alert>{msg(run.error)}</Alert> : null}
        <div className="flex justify-end gap-2">
          <Button variant="outline" onClick={onClose}>
            {t("purchasing.cancel.keep")}
          </Button>
          <Button variant="danger" disabled={run.isPending} onClick={() => run.mutate()} data-testid="confirm-cancel">
            {t("purchasing.cancel.confirm")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

function CloseDialog({ po, onClose }: { po: PurchaseOrder; onClose: () => void }) {
  const { t } = useTranslation("admin");
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const [reason, setReason] = useState("");
  const run = useMutation({
    mutationFn: () => closePo(po.id, reason),
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ["po"] });
      onClose();
    },
  });
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={t("purchasing.closeShort.title", { no: po.po_no })} closeLabel={t("purchasing.close")}>
      <div className="grid gap-3">
        <p className="text-sm text-slate-600">{t("purchasing.closeShort.help")}</p>
        <Field label={t("purchasing.closeShort.reason")}>
          <Input value={reason} onChange={(e) => setReason(e.target.value)} data-testid="close-reason" />
        </Field>
        {run.isError ? <Alert>{msg(run.error)}</Alert> : null}
        <div className="flex justify-end">
          <Button disabled={run.isPending} onClick={() => run.mutate()} data-testid="confirm-close">
            {t("purchasing.closeShort.confirm")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

/* ------------------------------------------------------------------------------------------------ receive */

function ReceiveDialog({ po, onClose, onDone }: { po: PurchaseOrder; onClose: () => void; onDone: (message: string) => void }) {
  const { t, i18n } = useTranslation("admin");
  const { access } = useSession();
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const currency = access.tenant.base_currency;
  const [id] = useState(() => uuidv7());
  const [deliveryRef, setDeliveryRef] = useState("");
  const [notes, setNotes] = useState("");
  const [qty, setQty] = useState<Record<string, string>>({});
  const [cost, setCost] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [rowErrors, setRowErrors] = useState<Array<LineError | null>>([]);

  const rows: ReceiveRow[] = useMemo(
    () => po.po_items.map((i) => ({ variantId: i.variant_id, remaining: remainingQty(i), qtyText: qty[i.variant_id] ?? "", costText: cost[i.variant_id] ?? "" })),
    [po, qty, cost],
  );
  const built = buildReceiveItems(rows, currency);

  const run = useMutation({
    mutationFn: async () => {
      setRowErrors(built.rowErrors);
      if (built.empty) throw new Error("nothing");
      if (!built.ok) throw new Error("rows");
      return await receivePo({ id, poId: po.id, items: built.items, notes, deliveryRef });
    },
    onSuccess: async (r) => {
      await qc.invalidateQueries({ queryKey: ["po"] });
      onDone(t("purchasing.receive.done", { grn: r.grn_no }));
    },
    onError: (e) => {
      if (e instanceof Error && e.message === "nothing") setError(t("purchasing.receive.nothing"));
      else if (e instanceof Error && e.message === "rows") setError(null);
      else setError(msg(e));
    },
  });

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={t("purchasing.receive.title", { no: po.po_no })} closeLabel={t("purchasing.close")}>
      <div className="grid gap-3">
        <Field label={t("purchasing.receive.deliveryRef")}>
          <Input value={deliveryRef} onChange={(e) => setDeliveryRef(e.target.value)} data-testid="delivery-ref" />
        </Field>
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium">{t("purchasing.form.lines")}</span>
          <Button
            size="sm"
            variant="outline"
            data-testid="fill-remaining"
            onClick={() => setQty(Object.fromEntries(po.po_items.filter((i) => remainingQty(i) > 0).map((i) => [i.variant_id, formatQty(remainingQty(i))])))}
          >
            {t("purchasing.receive.fillRemaining")}
          </Button>
        </div>
        {po.po_items.map((i, idx) => (
          <div key={i.id} className="grid gap-1 rounded-md border border-slate-200 p-2" data-testid={`recv-line-${idx}`}>
            <div className="text-sm font-medium">{productLabel(i.variant)}</div>
            <div className="grid grid-cols-3 items-end gap-2 text-xs text-slate-500">
              <div>
                {t("purchasing.receive.remaining")}
                <div className="text-sm font-medium text-slate-900">{formatQty(remainingQty(i))}</div>
              </div>
              <label className="grid gap-0.5">
                {t("purchasing.receive.arrived")}
                <Input inputMode="decimal" value={qty[i.variant_id] ?? ""} onChange={(e) => setQty({ ...qty, [i.variant_id]: e.target.value })} data-testid={`recv-${idx}-qty`} />
              </label>
              <label className="grid gap-0.5">
                {t("purchasing.receive.cost")}
                <Input
                  inputMode="decimal"
                  placeholder={i.unit_cost === null ? "" : formatMoney(money(i.unit_cost, currency), i18n.language)}
                  value={cost[i.variant_id] ?? ""}
                  onChange={(e) => setCost({ ...cost, [i.variant_id]: e.target.value })}
                  data-testid={`recv-${idx}-cost`}
                />
              </label>
            </div>
            {built.over[idx] ? <span className="text-xs text-amber-700">{t("purchasing.receive.over")}</span> : null}
            {rowErrors[idx] ? (
              <span role="alert" className="text-xs text-red-600">
                {t(`purchasing.lineError.${rowErrors[idx]}`)}
              </span>
            ) : null}
          </div>
        ))}
        <p className="text-xs text-slate-500">{t("purchasing.receive.costHint")}</p>
        <Field label={t("purchasing.receive.notes")}>
          <Input value={notes} onChange={(e) => setNotes(e.target.value)} />
        </Field>
        {error ? <Alert>{error}</Alert> : null}
        <div className="flex justify-end">
          <Button disabled={run.isPending} onClick={() => run.mutate()} data-testid="confirm-receive">
            {run.isPending ? t("purchasing.saving") : t("purchasing.receive.confirm")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

function WalkInDialog({ onClose, onDone }: { onClose: () => void; onDone: (message: string) => void }) {
  const { t } = useTranslation("admin");
  const { access } = useSession();
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const warehouses = useWarehouses();
  const suppliers = useQuery({ queryKey: ["po", "suppliers"], queryFn: listSuppliers });
  const variants = useQuery({ queryKey: ["po", "variants"], queryFn: listVariantOptions });
  const [id] = useState(() => uuidv7());
  const [warehouseId, setWarehouseId] = useState(warehouses.length === 1 ? warehouses[0]!.id : "");
  const [supplierId, setSupplierId] = useState("");
  const [deliveryRef, setDeliveryRef] = useState("");
  const [notes, setNotes] = useState("");
  const [lines, setLines] = useState<PoLineDraft[]>([blankLine()]);
  const [error, setError] = useState<string | null>(null);
  const [rowErrors, setRowErrors] = useState<Array<LineError | null>>([]);
  const currency = access.tenant.base_currency;

  const run = useMutation({
    mutationFn: async () => {
      const built = buildPoItems(lines, currency);
      setRowErrors(built.rowErrors);
      if (!warehouseId) throw new Error("needWarehouse");
      if (built.empty) throw new Error("needLines");
      if (!built.ok) throw new Error("rows");
      return await receiveWithoutPo({ id, warehouseId, supplierId, items: built.items, notes, deliveryRef });
    },
    onSuccess: async (r) => {
      await qc.invalidateQueries({ queryKey: ["po"] });
      onDone(t("purchasing.receive.done", { grn: r.grn_no }));
    },
    onError: (e) => {
      const m = e instanceof Error ? e.message : "";
      if (m === "needWarehouse") setError(t("purchasing.form.needWarehouse"));
      else if (m === "needLines") setError(t("purchasing.form.needLines"));
      else if (m === "rows") setError(null);
      else setError(msg(e));
    },
  });

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={t("purchasing.walkIn.title")} closeLabel={t("purchasing.close")}>
      <div className="grid gap-3">
        <Alert tone="info">{t("purchasing.walkIn.note")}</Alert>
        <Field label={t("purchasing.walkIn.warehouse")}>
          <Select value={warehouseId} onChange={(e) => setWarehouseId(e.target.value)} data-testid="walkin-warehouse">
            <option value="">{t("purchasing.form.selectWarehouse")}</option>
            {warehouses.map((w) => (
              <option key={w.id} value={w.id}>
                {w.code} · {w.name}
              </option>
            ))}
          </Select>
        </Field>
        <Field label={t("purchasing.walkIn.supplier")}>
          <Select value={supplierId} onChange={(e) => setSupplierId(e.target.value)}>
            <option value="">{t("purchasing.walkIn.noSupplier")}</option>
            {(suppliers.data ?? []).map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </Select>
        </Field>
        <Field label={t("purchasing.receive.deliveryRef")}>
          <Input value={deliveryRef} onChange={(e) => setDeliveryRef(e.target.value)} />
        </Field>
        <LinesEditor lines={lines} onChange={setLines} variants={variants.data ?? []} currency={currency} errors={rowErrors} />
        <Field label={t("purchasing.receive.notes")}>
          <Input value={notes} onChange={(e) => setNotes(e.target.value)} />
        </Field>
        {error ? <Alert>{error}</Alert> : null}
        <div className="flex justify-end">
          <Button disabled={run.isPending} onClick={() => run.mutate()} data-testid="confirm-walkin">
            {run.isPending ? t("purchasing.saving") : t("purchasing.receive.confirm")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

/* ------------------------------------------------------------------------------------------------ suppliers */

function SuppliersTab() {
  const { t } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const toast = useToast();
  const suppliers = useQuery({ queryKey: ["po", "suppliers"], queryFn: listSuppliers });
  const [editing, setEditing] = useState<Supplier | "new" | null>(null);
  const remove = useMutation({
    mutationFn: (id: string) => archiveSupplier(id),
    onSuccess: () => {
      toast.good(t("purchasing.suppliers.save"));
      void qc.invalidateQueries({ queryKey: ["po", "suppliers"] });
    },
  });
  return (
    <div className="grid gap-4">
      <div className="flex justify-end">
        <Button onClick={() => setEditing("new")} data-testid="add-supplier">
          {t("purchasing.suppliers.add")}
        </Button>
      </div>
      {suppliers.isError ? <ErrorState message={msg(suppliers.error)} onRetry={() => suppliers.refetch()} retryLabel={t("common:actions.retry")} /> : null}
      {remove.isError ? <ErrorState message={msg(remove.error)} /> : null}
      <Card className="overflow-x-auto p-0">
        {suppliers.isLoading ? (
          <p className="p-4 text-sm text-slate-500">{t("purchasing.loading")}</p>
        ) : (suppliers.data ?? []).length === 0 ? (
          <div data-testid="no-suppliers" className="p-4">
            <EmptyState
              title={t("purchasing.suppliers.none")}
              action={
                <Button size="sm" onClick={() => setEditing("new")}>
                  + {t("purchasing.suppliers.add")}
                </Button>
              }
            />
          </div>
        ) : (
          <Table bare>
            <thead>
              <tr className="border-b border-slate-200 text-slate-500">
                {(["name", "contact", "phone", "email", "actions"] as const).map((c) => (
                  <th key={c} className="px-3 py-2 font-medium">
                    {t(`purchasing.suppliers.${c}`)}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {(suppliers.data ?? []).map((s) => (
                <tr key={s.id} className="border-b border-slate-100" data-testid={`supplier-${s.name}`}>
                  <td className="px-3 py-2 font-medium">{s.name}</td>
                  <td className="px-3 py-2">{s.contact_name ?? "—"}</td>
                  <td className="px-3 py-2">{s.phone ?? "—"}</td>
                  <td className="px-3 py-2">{s.email ?? "—"}</td>
                  <td className="px-3 py-2">
                    <div className="flex gap-1">
                      <Button size="sm" variant="outline" onClick={() => setEditing(s)}>
                        {t("purchasing.suppliers.edit")}
                      </Button>
                      <Button
                        size="sm"
                        variant="ghost"
                        disabled={remove.isPending}
                        onClick={() => {
                          if (window.confirm(t("purchasing.suppliers.removeConfirm", { name: s.name }))) remove.mutate(s.id);
                        }}
                      >
                        {t("purchasing.suppliers.remove")}
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>
      {editing ? <SupplierDialog supplier={editing === "new" ? null : editing} onClose={() => setEditing(null)} /> : null}
    </div>
  );
}

function SupplierDialog({ supplier, onClose }: { supplier: Supplier | null; onClose: () => void }) {
  const { t } = useTranslation("admin");
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const toast = useToast();
  const [id] = useState(() => supplier?.id ?? uuidv7());
  const [name, setName] = useState(supplier?.name ?? "");
  const [contact, setContact] = useState(supplier?.contact_name ?? "");
  const [phone, setPhone] = useState(supplier?.phone ?? "");
  const [email, setEmail] = useState(supplier?.email ?? "");
  const [notes, setNotes] = useState(supplier?.notes ?? "");
  const run = useMutation({
    mutationFn: () => upsertSupplier({ id, name, contact_name: contact, phone, email, notes }),
    onSuccess: async () => {
      toast.good(t("purchasing.suppliers.save"));
      await qc.invalidateQueries({ queryKey: ["po", "suppliers"] });
      onClose();
    },
  });
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={supplier ? t("purchasing.suppliers.edit") : t("purchasing.suppliers.add")} closeLabel={t("purchasing.close")}>
      <div className="grid gap-3">
        <Field label={t("purchasing.suppliers.name")}>
          <Input value={name} onChange={(e) => setName(e.target.value)} data-testid="supplier-name" />
        </Field>
        <Field label={t("purchasing.suppliers.contact")}>
          <Input value={contact} onChange={(e) => setContact(e.target.value)} />
        </Field>
        <Field label={t("purchasing.suppliers.phone")}>
          <Input value={phone} onChange={(e) => setPhone(e.target.value)} />
        </Field>
        <Field label={t("purchasing.suppliers.email")}>
          <Input type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
        </Field>
        <Field label={t("purchasing.suppliers.notes")}>
          <Input value={notes} onChange={(e) => setNotes(e.target.value)} />
        </Field>
        {run.isError ? <Alert>{msg(run.error)}</Alert> : null}
        <div className="flex justify-end">
          <Button disabled={run.isPending} onClick={() => run.mutate()} data-testid="save-supplier">
            {run.isPending ? t("purchasing.saving") : t("purchasing.suppliers.save")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

/* ------------------------------------------------------------------------------------------------ deliveries */

function ReceiptsTab() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const receipts = useQuery({ queryKey: ["po", "receipts"], queryFn: listGoodsReceipts });
  const [open, setOpen] = useState<string | null>(null);
  return (
    <Card className="overflow-x-auto p-0">
      {receipts.isError ? <ErrorState message={msg(receipts.error)} onRetry={() => receipts.refetch()} retryLabel={t("common:actions.retry")} /> : null}
      {receipts.isLoading ? (
        <p className="p-4 text-sm text-slate-500">{t("purchasing.loading")}</p>
      ) : (receipts.data ?? []).length === 0 ? (
        <div data-testid="no-receipts" className="p-4">
          <EmptyState title={t("purchasing.receipts.none")} />
        </div>
      ) : (
        <Table bare>
          <thead>
            <tr className="border-b border-slate-200 text-slate-500">
              {(["grnNo", "date", "warehouse", "supplier", "order", "deliveryRef", "lines"] as const).map((c) => (
                <th key={c} className="px-3 py-2 font-medium">
                  {t(`purchasing.receipts.${c}`)}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {(receipts.data ?? []).map((g) => (
              <Fragment key={g.id}>
                <tr className="cursor-pointer border-b border-slate-100 align-top hover:bg-slate-50" onClick={() => setOpen(open === g.id ? null : g.id)} data-testid={`grn-${g.grn_no}`}>
                  <td className="px-3 py-2 font-mono text-xs">{g.grn_no}</td>
                  <td className="px-3 py-2">{new Date(g.received_at).toLocaleDateString(i18n.language)}</td>
                  <td className="px-3 py-2">{g.warehouse?.code ?? "—"}</td>
                  <td className="px-3 py-2">{g.supplier?.name ?? "—"}</td>
                  <td className="px-3 py-2">
                    {g.purchase_order?.po_no ?? <Badge tone="warn">{t("purchasing.receipts.noOrder")}</Badge>}
                    {g.has_discrepancy ? (
                      <div className="mt-1">
                        <Badge tone="warn">{t("purchasing.receipts.moreThanOrdered")}</Badge>
                      </div>
                    ) : null}
                  </td>
                  <td className="px-3 py-2">{g.delivery_ref ?? "—"}</td>
                  <td className="px-3 py-2">{g.goods_receipt_items.length}</td>
                </tr>
                {open === g.id ? (
                  <tr className="border-b border-slate-100 bg-slate-50">
                    <td colSpan={7} className="px-3 py-2">
                      <ul className="grid gap-0.5 text-sm">
                        {g.goods_receipt_items.map((i) => (
                          <li key={i.id}>
                            {productLabel(i.variant)} — {formatQty(i.qty)} {i.variant?.product?.unit ?? ""}
                            {i.over_received ? <span className="ml-2 text-xs text-amber-700">{t("purchasing.receipts.moreThanOrdered")}</span> : null}
                          </li>
                        ))}
                      </ul>
                    </td>
                  </tr>
                ) : null}
              </Fragment>
            ))}
          </tbody>
        </Table>
      )}
    </Card>
  );
}
