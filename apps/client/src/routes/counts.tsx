import { Fragment, useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useTranslation } from "react-i18next";
import { uuidv7 } from "@pos/core";
import { Alert, Badge, Button, Card, Dialog, EmptyState, ErrorState, Field, Input, Select, Table, PageHeader, useToast } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { formatQty } from "../lib/product-math.ts";
import {
  buildCountItems,
  countStatusTone,
  mergeCountRows,
  summarizeVariance,
  variance,
  type CountRow,
  type SavedLine,
} from "../lib/counts-math.ts";
import {
  cancelCount,
  closeCount,
  listCountBins,
  listCounts,
  listCountWarehouses,
  listSystemStock,
  recordCount,
  startCount,
  type CountBin,
  type CountWarehouse,
  type StockCount,
} from "../lib/counts-api.ts";
import { listVariantOptions, type VariantOption } from "../lib/purchasing-api.ts";

const productLabel = (v: VariantOption | undefined) => (v ? `${v.product?.name ?? v.sku} · ${v.sku}` : "?");
const signed = (n: number) => (n > 0 ? `+${formatQty(n)}` : formatQty(n));

export function CountsPage() {
  const { t } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const { can } = useSession();
  const warehousesQ = useQuery({ queryKey: ["counts", "warehouses"], queryFn: listCountWarehouses });
  const warehouses = (warehousesQ.data ?? []).filter((w) => can("stock.adjust_warehouse", w.id));
  const [picked, setPicked] = useState("");
  const warehouse = warehouses.find((w) => w.id === picked) ?? warehouses[0];
  const [notice, setNotice] = useState<string | null>(null);

  const countsQ = useQuery({
    queryKey: ["counts", "list", warehouse?.id],
    queryFn: () => listCounts(warehouse!.id),
    enabled: Boolean(warehouse),
  });
  const open = (countsQ.data ?? []).find((c) => c.status === "open");
  const past = (countsQ.data ?? []).filter((c) => c.status !== "open");

  return (
    <div className="grid gap-4">
      <PageHeader title={t("counts.title")} subtitle={t("counts.subtitle")} />

      {warehousesQ.isError ? <ErrorState message={msg(warehousesQ.error)} onRetry={() => warehousesQ.refetch()} retryLabel={t("common:actions.retry")} /> : null}
      {warehousesQ.isSuccess && warehouses.length === 0 ? <EmptyState title={t("counts.noWarehouses")} /> : null}

      {warehouse ? (
        <>
          <Card className="flex flex-wrap items-end gap-3">
            <Field label={t("counts.warehouse")}>
              <Select
                value={warehouse.id}
                onChange={(e) => {
                  setPicked(e.target.value);
                  setNotice(null);
                }}
                data-testid="count-warehouse"
              >
                {warehouses.map((w) => (
                  <option key={w.id} value={w.id}>
                    {w.code} · {w.name}
                  </option>
                ))}
              </Select>
            </Field>
          </Card>

          {notice ? <Alert tone="info">{notice}</Alert> : null}
          {countsQ.isError ? <ErrorState message={msg(countsQ.error)} onRetry={() => countsQ.refetch()} retryLabel={t("common:actions.retry")} /> : null}

          {countsQ.isSuccess ? (
            open ? (
              <OpenCount key={open.id} count={open} warehouse={warehouse} onNotice={setNotice} />
            ) : (
              <StartCard warehouse={warehouse} onNotice={setNotice} />
            )
          ) : null}

          <History counts={past} />
        </>
      ) : null}
    </div>
  );
}

/* ------------------------------------------------------------------------------------------------ start */

function StartCard({ warehouse, onNotice }: { warehouse: CountWarehouse; onNotice: (m: string | null) => void }) {
  const { t } = useTranslation("admin");
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const [id] = useState(() => uuidv7());
  const [scope, setScope] = useState<"all" | "bin">("all");
  const [binId, setBinId] = useState("");
  const [notes, setNotes] = useState("");
  const [error, setError] = useState<string | null>(null);
  const bins = useQuery({ queryKey: ["counts", "bins", warehouse.id], queryFn: () => listCountBins(warehouse.id), enabled: warehouse.bins_enabled });

  const run = useMutation({
    mutationFn: async () => {
      if (scope === "bin" && !binId) throw new Error("needBin");
      return await startCount({ id, warehouseId: warehouse.id, binId: scope === "bin" ? binId : null, notes });
    },
    onSuccess: async () => {
      onNotice(null);
      await qc.invalidateQueries({ queryKey: ["counts"] });
    },
    onError: (e) => setError(e instanceof Error && e.message === "needBin" ? t("counts.start.needBin") : msg(e)),
  });

  return (
    <Card className="grid gap-3" data-testid="start-card">
      <h2 className="font-medium">{t("counts.start.title")}</h2>
      <p className="text-sm text-slate-600">{t("counts.start.help")}</p>
      {warehouse.bins_enabled ? (
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label={t("counts.start.scope")}>
            <Select value={scope} onChange={(e) => setScope(e.target.value as "all" | "bin")} data-testid="start-scope">
              <option value="all">{t("counts.start.wholeWarehouse")}</option>
              <option value="bin">{t("counts.start.bin")}</option>
            </Select>
          </Field>
          {scope === "bin" ? (
            <Field label={t("counts.add.bin")}>
              <Select value={binId} onChange={(e) => setBinId(e.target.value)} data-testid="start-bin">
                <option value="">{t("counts.start.selectBin")}</option>
                {(bins.data ?? []).map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.code}
                  </option>
                ))}
              </Select>
            </Field>
          ) : null}
        </div>
      ) : null}
      <Field label={t("counts.start.notes")}>
        <Input value={notes} onChange={(e) => setNotes(e.target.value)} />
      </Field>
      {error ? <Alert>{error}</Alert> : null}
      <div>
        <Button disabled={run.isPending} onClick={() => run.mutate()} data-testid="start-count">
          {run.isPending ? t("counts.saving") : t("counts.start.button")}
        </Button>
      </div>
    </Card>
  );
}

/* ------------------------------------------------------------------------------------------------ open count */

function OpenCount({ count, warehouse, onNotice }: { count: StockCount; warehouse: CountWarehouse; onNotice: (m: string | null) => void }) {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const toast = useToast();
  const variantsQ = useQuery({ queryKey: ["po", "variants"], queryFn: listVariantOptions });
  const systemQ = useQuery({ queryKey: ["counts", "system", warehouse.id, count.id], queryFn: () => listSystemStock(warehouse) });
  const binsQ = useQuery({ queryKey: ["counts", "bins", warehouse.id], queryFn: () => listCountBins(warehouse.id), enabled: warehouse.bins_enabled });
  const [typed, setTyped] = useState<Record<string, string>>({});
  const [added, setAdded] = useState<Array<{ variantId: string; binId: string | null }>>([]);
  const [addVariant, setAddVariant] = useState("");
  const [addBin, setAddBin] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [rowErrors, setRowErrors] = useState<Record<string, string>>({});
  const [dialog, setDialog] = useState<"close" | "cancel" | null>(null);

  const variantMap = useMemo(() => new Map((variantsQ.data ?? []).map((v) => [v.id, v])), [variantsQ.data]);
  const binMap = useMemo(() => new Map<string, CountBin>((binsQ.data ?? []).map((b) => [b.id, b])), [binsQ.data]);
  const saved: SavedLine[] = count.stock_count_items.map((l) => ({
    variantId: l.variant_id,
    binId: l.bin_id,
    qtySystem: Number(l.qty_system),
    qtyCounted: Number(l.qty_counted),
    autoZero: l.auto_zero,
  }));
  const rows = useMemo(() => {
    const merged = mergeCountRows(systemQ.data ?? [], saved, added, count.bin_id);
    const label = (r: CountRow) => productLabel(variantMap.get(r.variantId));
    const binCode = (r: CountRow) => (r.binId ? (binMap.get(r.binId)?.code ?? "") : "");
    return merged.sort((a, b) => label(a).localeCompare(label(b)) || binCode(a).localeCompare(binCode(b)));
  }, [systemQ.data, count, added, variantMap, binMap]);

  const hasTyped = Object.values(typed).some((v) => v.trim() !== "");
  const scopeLabel = count.bin ? t("counts.open.scopeBin", { code: count.bin.code }) : t("counts.open.scopeAll");

  const save = useMutation({
    mutationFn: async () => {
      const input = rows.map((r) => ({ variantId: r.variantId, binId: r.binId, qtyText: typed[r.key] ?? "" }));
      const built = buildCountItems(input, warehouse.bins_enabled);
      const errs: Record<string, string> = {};
      built.rowErrors.forEach((e, i) => {
        if (e) errs[rows[i]!.key] = e;
      });
      setRowErrors(errs);
      if (built.empty) throw new Error("nothing");
      if (!built.ok) throw new Error("rows");
      return await recordCount(count.id, built.items);
    },
    onSuccess: async (r) => {
      setTyped({});
      setError(null);
      const doneMsg = t("counts.save.done", { n: r.recorded });
      onNotice(doneMsg);
      toast.good(doneMsg);
      await qc.invalidateQueries({ queryKey: ["counts"] });
    },
    onError: (e) => {
      const m = e instanceof Error ? e.message : "";
      if (m === "nothing") setError(t("counts.save.nothing"));
      else if (m === "rows") setError(null);
      else setError(msg(e));
    },
  });

  function addRow() {
    if (!addVariant) return;
    if (warehouse.bins_enabled && !addBin) return;
    setAdded([...added, { variantId: addVariant, binId: warehouse.bins_enabled ? addBin : null }]);
    setAddVariant("");
  }

  return (
    <Card className="grid gap-4" data-testid="open-count">
      <div className="flex flex-wrap items-center gap-2">
        <h2 className="font-medium">{t("counts.open.title", { no: count.count_no })}</h2>
        <Badge tone={countStatusTone(count.status)}>{t(`counts.status.${count.status}`)}</Badge>
        <span className="text-sm text-slate-600">
          {scopeLabel} · {t("counts.open.started", { date: new Date(count.started_at).toLocaleString(i18n.language) })}
        </span>
        <div className="ml-auto flex gap-2">
          <Button variant="ghost" onClick={() => setDialog("cancel")} data-testid="open-cancel">
            {t("counts.cancel.button")}
          </Button>
          <Button variant="outline" onClick={() => setDialog("close")} data-testid="open-close">
            {t("counts.closeCount.button")}
          </Button>
        </div>
      </div>
      {count.notes ? <p className="text-sm text-slate-600">{count.notes}</p> : null}

      <div className="flex flex-wrap items-end gap-2 rounded-md bg-slate-50 p-3">
        <Field label={t("counts.add.product")}>
          <Select value={addVariant} onChange={(e) => setAddVariant(e.target.value)} data-testid="add-variant">
            <option value="">{t("counts.add.selectProduct")}</option>
            {(variantsQ.data ?? []).map((v) => (
              <option key={v.id} value={v.id}>
                {productLabel(v)}
              </option>
            ))}
          </Select>
        </Field>
        {warehouse.bins_enabled ? (
          <Field label={t("counts.add.bin")}>
            <Select value={addBin} onChange={(e) => setAddBin(e.target.value)} data-testid="add-bin">
              <option value="">{t("counts.add.selectBin")}</option>
              {(binsQ.data ?? []).filter((b) => !count.bin_id || b.id === count.bin_id).map((b) => (
                <option key={b.id} value={b.id}>
                  {b.code}
                </option>
              ))}
            </Select>
          </Field>
        ) : null}
        <Button variant="outline" onClick={addRow} disabled={!addVariant || (warehouse.bins_enabled && !addBin)} data-testid="add-row">
          {t("counts.add.button")}
        </Button>
      </div>

      {systemQ.isError ? <ErrorState message={msg(systemQ.error)} onRetry={() => systemQ.refetch()} retryLabel={t("common:actions.retry")} /> : null}
      {rows.length === 0 ? (
        <p className="text-sm text-slate-500" data-testid="no-rows">
          {t("counts.table.none")}
        </p>
      ) : (
        <div className="overflow-x-auto">
          <Table bare>
            <thead>
              <tr className="border-b border-slate-200 text-slate-500">
                <th className="px-2 py-2 font-medium">{t("counts.table.product")}</th>
                {warehouse.bins_enabled ? <th className="px-2 py-2 font-medium">{t("counts.table.bin")}</th> : null}
                <th className="px-2 py-2 font-medium">{t("counts.table.system")}</th>
                <th className="w-32 px-2 py-2 font-medium">{t("counts.table.count")}</th>
                <th className="px-2 py-2 font-medium">{t("counts.table.difference")}</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r, i) => {
                const text = typed[r.key] ?? "";
                const typedNum = text.trim() === "" ? null : Number(text);
                const diff =
                  typedNum !== null && Number.isFinite(typedNum)
                    ? variance(typedNum, r.systemNow)
                    : r.saved
                      ? variance(r.saved.qtyCounted, r.saved.qtySystem)
                      : null;
                return (
                  <tr key={r.key} className="border-b border-slate-100 align-top" data-testid={`count-row-${i}`}>
                    <td className="px-2 py-2">{productLabel(variantMap.get(r.variantId))}</td>
                    {warehouse.bins_enabled ? <td className="px-2 py-2">{r.binId ? (binMap.get(r.binId)?.code ?? "?") : "—"}</td> : null}
                    <td className="px-2 py-2">{formatQty(r.systemNow)}</td>
                    <td className="px-2 py-2">
                      <Input
                        inputMode="decimal"
                        aria-label={t("counts.table.count")}
                        value={text}
                        placeholder={r.saved ? formatQty(r.saved.qtyCounted) : ""}
                        onChange={(e) => setTyped({ ...typed, [r.key]: e.target.value })}
                        data-testid={`count-input-${i}`}
                      />
                      {r.saved ? (
                        <div className="mt-1 text-xs text-slate-500">{t("counts.open.recount", { counted: formatQty(r.saved.qtyCounted), system: formatQty(r.saved.qtySystem) })}</div>
                      ) : null}
                      {rowErrors[r.key] ? (
                        <span role="alert" className="text-xs text-red-600">
                          {t(`counts.save.lineError.${rowErrors[r.key] as "qty_invalid" | "bin_required"}`)}
                        </span>
                      ) : null}
                    </td>
                    <td className="px-2 py-2">
                      {diff === null ? (
                        <span className="text-slate-400">{t("counts.table.notCounted")}</span>
                      ) : (
                        <span className={diff === 0 ? "text-slate-500" : diff < 0 ? "font-medium text-red-700" : "font-medium text-green-700"} data-testid={`count-diff-${i}`}>
                          {signed(diff)}
                        </span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </Table>
        </div>
      )}

      {error ? <Alert>{error}</Alert> : null}
      <div className="flex justify-end">
        <Button disabled={save.isPending || rows.length === 0} onClick={() => save.mutate()} data-testid="save-counts">
          {save.isPending ? t("counts.saving") : t("counts.save.button")}
        </Button>
      </div>

      {dialog === "close" ? (
        <CloseDialog count={count} rows={rows} hasUnsaved={hasTyped} onClose={() => setDialog(null)} onDone={onNotice} />
      ) : null}
      {dialog === "cancel" ? <CancelDialog count={count} onClose={() => setDialog(null)} /> : null}
    </Card>
  );
}

function CloseDialog({
  count,
  rows,
  hasUnsaved,
  onClose,
  onDone,
}: {
  count: StockCount;
  rows: CountRow[];
  hasUnsaved: boolean;
  onClose: () => void;
  onDone: (m: string) => void;
}) {
  const { t } = useTranslation("admin");
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const toast = useToast();
  const [zero, setZero] = useState(false);
  const lines = count.stock_count_items.map((l) => ({ qtySystem: Number(l.qty_system), qtyCounted: Number(l.qty_counted) }));
  const sum = summarizeVariance(lines);
  const wouldZero = rows.filter((r) => r.systemNow !== 0 && !r.saved).length;
  const nothing = lines.length === 0 && !(zero && wouldZero > 0);

  const run = useMutation({
    mutationFn: () => closeCount(count.id, zero),
    onSuccess: async (r) => {
      await qc.invalidateQueries({ queryKey: ["counts"] });
      const doneMsg = t("counts.closeCount.done", { no: count.count_no, corrections: r.corrections, net: signed(Number(r.net_variance)) });
      onDone(doneMsg);
      toast.good(doneMsg);
      onClose();
    },
  });

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={t("counts.closeCount.title", { no: count.count_no })} closeLabel={t("counts.close")}>
      <div className="grid gap-3 text-sm">
        <p className="text-slate-600">{t("counts.closeCount.help")}</p>
        {lines.length === 0 ? (
          <p>{t("counts.closeCount.none")}</p>
        ) : (
          <p data-testid="close-summary">
            {t("counts.closeCount.summary", { corrections: sum.corrections, lines: sum.lines, shortage: formatQty(Math.abs(sum.shortage)), surplus: formatQty(sum.surplus) })}
          </p>
        )}
        <label className="flex items-start gap-2">
          <input type="checkbox" checked={zero} onChange={(e) => setZero(e.target.checked)} className="mt-1" data-testid="zero-uncounted" />
          <span>
            {t("counts.closeCount.zeroLabel")}
            {zero && wouldZero > 0 ? <span className="block text-amber-700">{t("counts.closeCount.zeroWarning", { n: wouldZero })}</span> : null}
          </span>
        </label>
        {hasUnsaved ? <Alert>{t("counts.closeCount.unsaved")}</Alert> : null}
        {run.isError ? <Alert>{msg(run.error)}</Alert> : null}
        <div className="flex justify-end">
          <Button disabled={run.isPending || hasUnsaved || nothing} onClick={() => run.mutate()} data-testid="confirm-close-count">
            {run.isPending ? t("counts.saving") : t("counts.closeCount.confirm")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

function CancelDialog({ count, onClose }: { count: StockCount; onClose: () => void }) {
  const { t } = useTranslation("admin");
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const toast = useToast();
  const [reason, setReason] = useState("");
  const run = useMutation({
    mutationFn: () => cancelCount(count.id, reason),
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ["counts"] });
      toast.good(t("counts.cancel.title", { no: count.count_no }));
      onClose();
    },
  });
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()} title={t("counts.cancel.title", { no: count.count_no })} closeLabel={t("counts.close")}>
      <div className="grid gap-3">
        <Field label={t("counts.cancel.reason")}>
          <Input value={reason} onChange={(e) => setReason(e.target.value)} data-testid="cancel-count-reason" />
        </Field>
        {run.isError ? <Alert>{msg(run.error)}</Alert> : null}
        <div className="flex justify-end gap-2">
          <Button variant="outline" onClick={onClose}>
            {t("counts.cancel.keep")}
          </Button>
          <Button variant="danger" disabled={run.isPending} onClick={() => run.mutate()} data-testid="confirm-cancel-count">
            {t("counts.cancel.confirm")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

/* ------------------------------------------------------------------------------------------------ history */

function History({ counts }: { counts: StockCount[] }) {
  const { t, i18n } = useTranslation("admin");
  const variantsQ = useQuery({ queryKey: ["po", "variants"], queryFn: listVariantOptions });
  const [openId, setOpenId] = useState<string | null>(null);
  return (
    <Card className="overflow-x-auto p-0" data-testid="count-history">
      <h2 className="px-4 pt-4 font-medium">{t("counts.history.title")}</h2>
      {counts.length === 0 ? (
        <p className="p-4 text-sm text-slate-500">{t("counts.history.none")}</p>
      ) : (
        <Table bare>
          <thead>
            <tr className="border-b border-slate-200 text-slate-500">
              {(["no", "date", "scope", "status", "lines", "corrections"] as const).map((c) => (
                <th key={c} className="px-3 py-2 font-medium">
                  {t(`counts.history.${c}`)}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {counts.map((c) => {
              const corrections = c.stock_count_items.filter((l) => Number(l.qty_variance ?? 0) !== 0).length;
              return (
                <Fragment key={c.id}>
                  <tr className="cursor-pointer border-b border-slate-100 align-top hover:bg-slate-50" onClick={() => setOpenId(openId === c.id ? null : c.id)} data-testid={`count-${c.count_no}`}>
                    <td className="px-3 py-2 font-mono text-xs">{c.count_no}</td>
                    <td className="px-3 py-2">{new Date(c.closed_at ?? c.cancelled_at ?? c.started_at).toLocaleDateString(i18n.language)}</td>
                    <td className="px-3 py-2">{c.bin ? t("counts.open.scopeBin", { code: c.bin.code }) : t("counts.open.scopeAll")}</td>
                    <td className="px-3 py-2">
                      <Badge tone={countStatusTone(c.status)}>{t(`counts.status.${c.status}`)}</Badge>
                    </td>
                    <td className="px-3 py-2">{c.stock_count_items.length}</td>
                    <td className="px-3 py-2">{c.status === "closed" ? corrections : "—"}</td>
                  </tr>
                  {openId === c.id ? (
                    <tr className="border-b border-slate-100 bg-slate-50">
                      <td colSpan={6} className="px-3 py-2">
                        {c.cancel_reason ? <p className="mb-1 text-slate-600">{t("counts.history.cancelReason", { reason: c.cancel_reason })}</p> : null}
                        <ul className="grid gap-0.5">
                          {c.stock_count_items.map((l) => {
                            const v = l.qty_variance === null ? null : Number(l.qty_variance);
                            return (
                              <li key={l.id}>
                                {productLabel(l.variant ?? variantsQ.data?.find((x) => x.id === l.variant_id))}
                                {l.bin ? ` · ${l.bin.code}` : ""} — {t("counts.history.counted")} {formatQty(Number(l.qty_counted))}, {t("counts.history.system")} {formatQty(Number(l.qty_system))}
                                {v !== null && v !== 0 ? <span className={v < 0 ? "ml-2 text-red-700" : "ml-2 text-green-700"}>{signed(v)}</span> : null}
                                {l.auto_zero ? <span className="ml-2 text-xs text-amber-700">{t("counts.history.zero")}</span> : null}
                              </li>
                            );
                          })}
                        </ul>
                      </td>
                    </tr>
                  ) : null}
                </Fragment>
              );
            })}
          </tbody>
        </Table>
      )}
    </Card>
  );
}
