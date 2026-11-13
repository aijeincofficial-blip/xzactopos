import { useMemo, useState } from "react";
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useNavigate } from "@tanstack/react-router";
import { useTranslation } from "react-i18next";
import { formatMoney, money } from "@pos/core";
import { Download } from "lucide-react";
import { Alert, Badge, Button, Card, Dialog, EmptyState, ErrorState, Field, Input, PageHeader, Select, Table, TableSkeleton, Tabs, TabPanel, useToast } from "../components/ui.tsx";
import { downloadCsv, exportReorderListCsv } from "../lib/csv-helper.ts";
import { useSession } from "../lib/session.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { formatQty } from "../lib/product-math.ts";
import {
  negativeSummary,
  nextNegativeCursor,
  nextReorderCursor,
  nextTransitCursor,
  reorderStatus,
  reorderSummary,
  stockTotals,
  transitAge,
  transitIsLate,
} from "../lib/overview-math.ts";
import {
  PAGE_SIZE,
  fetchStoreReplenishment,
  negativeStockList,
  setLocationReorderPoint,
  warehouseReorderList,
  warehouseStockByVariant,
  warehouseTransfersInTransit,
  type NegativeRow,
  type ReorderRow,
  type TransitRow,
} from "../lib/overview-api.ts";
import { listCountWarehouses } from "../lib/counts-api.ts";
import { listVariantOptions } from "../lib/purchasing-api.ts";

type Tab = "reorder" | "stores" | "transit" | "product" | "negative";

export function OverviewPage() {
  const { t } = useTranslation(["admin", "common"]);
  const { access, can } = useSession();
  const [tab, setTab] = useState<Tab>("reorder");
  const warehousesQ = useQuery({ queryKey: ["overview", "warehouses"], queryFn: listCountWarehouses });
  const warehouses = (warehousesQ.data ?? []).filter((w) => can("reports.warehouse", w.id));
  const stores = access.locations.filter((l) => l.type === "store");
  const visibleTabs = (
    stores.length > 0
      ? (["reorder", "stores", "transit", "product", "negative"] as const)
      : (["reorder", "transit", "product", "negative"] as const)
  ).map((k) => ({ value: k, label: t(`overview.tabs.${k}`), testId: `ov-tab-${k}` }));

  return (
    <div className="grid gap-4">
      <PageHeader title={t("overview.title")} subtitle={t("overview.subtitle")} />
      {warehousesQ.isSuccess && warehouses.length === 0 ? <EmptyState title={t("overview.noWarehouses")} /> : null}
      <Tabs
        value={tab}
        onValueChange={(v) => setTab(v as Tab)}
        label={t("overview.title")}
        tabs={visibleTabs}
      >
        <TabPanel value={tab}>
          {tab === "reorder" ? (
            <ReorderTab warehouses={warehouses} />
          ) : tab === "stores" ? (
            <StoreReplenishmentTab stores={stores} warehouses={warehouses} />
          ) : tab === "transit" ? (
            <TransitTab warehouses={warehouses} />
          ) : tab === "negative" ? (
            <NegativeTab />
          ) : (
            <ProductTab />
          )}
        </TabPanel>
      </Tabs>
    </div>
  );
}

function WarehouseFilter({
  warehouses,
  value,
  onChange,
  children,
}: {
  warehouses: Array<{ id: string; code: string; name: string }>;
  value: string;
  onChange: (v: string) => void;
  children?: React.ReactNode;
}) {
  const { t } = useTranslation("admin");
  return (
    <div className="flex flex-wrap items-center justify-between gap-3">
      <div className="flex items-center gap-2.5">
        <span className="text-xs font-semibold text-slate-500">{t("overview.filter.warehouse")}</span>
        <Select value={value} onChange={(e) => onChange(e.target.value)} data-testid="ov-warehouse" className="w-56">
          <option value="">{t("overview.filter.all")}</option>
          {warehouses.map((w) => (
            <option key={w.id} value={w.id}>
              {w.code} · {w.name}
            </option>
          ))}
        </Select>
      </div>
      {children ? <div className="flex flex-wrap items-center gap-2">{children}</div> : null}
    </div>
  );
}

/* ------------------------------------------------------------------------------------------------ reorder */

function ReorderTab({ warehouses }: { warehouses: Array<{ id: string; code: string; name: string }> }) {
  const { t } = useTranslation(["admin", "common"]);
  const navigate = useNavigate();
  const msg = useErrorMessage();
  const toast = useToast();
  const qc = useQueryClient();
  const { can, access } = useSession();
  const [warehouseId, setWarehouseId] = useState("");
  const [editingRow, setEditingRow] = useState<ReorderRow | null>(null);
  const [editPoint, setEditPoint] = useState("");
  const [editError, setEditError] = useState<string | null>(null);

  const q = useInfiniteQuery({
    queryKey: ["overview", "reorder", warehouseId],
    initialPageParam: null as { location: string; variant: string } | null,
    queryFn: ({ pageParam }) => warehouseReorderList({ warehouseId, afterLocation: pageParam?.location, afterVariant: pageParam?.variant }),
    getNextPageParam: (last) => nextReorderCursor(last, PAGE_SIZE),
  });
  const rows: ReorderRow[] = (q.data?.pages ?? []).flat();
  const sum = reorderSummary(rows);
  const needOrderRows = rows.filter((r) => reorderStatus(r) === "order");

  const handleDraftPoAll = () => {
    if (needOrderRows.length === 0) return;
    const lines = needOrderRows.map((r) => ({
      variantId: r.variant_id,
      qtyText: String(Math.max(1, r.shortfall)),
      costText: "",
    }));
    const targetWarehouse = warehouseId || (needOrderRows[0]?.location_id ?? "");
    sessionStorage.setItem(
      "xzactopos:draft-po",
      JSON.stringify({
        warehouseId: targetWarehouse,
        lines,
        notes: `Auto-drafted from low stock (${needOrderRows.length} items)`,
      })
    );
    navigate({ to: "/app/purchasing" });
  };

  const handleExportReorderCsv = () => {
    if (rows.length === 0) return;
    const csv = exportReorderListCsv(
      rows.map((r) => {
        const status = reorderStatus(r);
        return {
          warehouse: r.location_code,
          product: r.product_name,
          sku: r.sku,
          onHand: r.qty_on_hand,
          reorderPoint: r.reorder_point,
          thresholdType: r.is_override ? "custom" : "default",
          incoming: r.incoming_qty,
          onOrder: r.on_order_qty,
          status: t(`overview.reorder.statusLabel.${status}`),
          shortfall: status === "order" ? r.shortfall : 0,
        };
      }),
    );
    const stamp = new Date().toISOString().slice(0, 10);
    downloadCsv(csv, `warehouse-reorder-${stamp}.csv`);
    toast.good(t("overview.reorder.exportedToast", { count: rows.length }));
  };

  const saveThresholdMut = useMutation({
    mutationFn: async (point: number | null) => {
      if (!editingRow) return;
      await setLocationReorderPoint({
        locationId: editingRow.location_id,
        variantId: editingRow.variant_id,
        reorderPoint: point,
      });
    },
    onSuccess: async () => {
      setEditingRow(null);
      setEditError(null);
      toast.good(t("common:saved"));
      await qc.invalidateQueries({ queryKey: ["overview", "reorder"] });
    },
    onError: (e) => {
      const err = msg(e);
      setEditError(err);
      toast.error(err);
    },
  });

  return (
    <div className="grid gap-4">
      <WarehouseFilter warehouses={warehouses} value={warehouseId} onChange={setWarehouseId}>
        <Button
          size="sm"
          variant="outline"
          data-testid="export-reorder-csv"
          disabled={rows.length === 0}
          onClick={handleExportReorderCsv}
        >
          <Download size={15} aria-hidden />
          <span>{t("overview.reorder.exportCsv")}</span>
        </Button>
        {needOrderRows.length > 0 ? (
          <Button
            size="sm"
            variant="outline"
            data-testid="draft-po-all-low-stock"
            title={t("overview.reorder.draftPoAllDesc")}
            onClick={handleDraftPoAll}
          >
            {t("overview.reorder.draftPoAll")}
          </Button>
        ) : null}
      </WarehouseFilter>
      {q.isError ? <ErrorState message={msg(q.error)} onRetry={() => void q.refetch()} retryLabel={t("common:actions.retry")} /> : null}
      {rows.length > 0 ? (
        <p className="text-sm text-slate-700" data-testid="reorder-summary">
          {t("overview.reorder.summary", { need: sum.needOrder, covered: sum.covered, atPoint: sum.atPoint })}
        </p>
      ) : null}
      <Card className="overflow-x-auto p-0">
        {q.isLoading ? (
          <TableSkeleton rows={5} cols={9} />
        ) : rows.length === 0 ? (
          <div data-testid="reorder-none" className="p-4">
            <EmptyState title={t("overview.reorder.none")} />
          </div>
        ) : (
          <Table bare>
            <thead>
              <tr className="border-b border-slate-200 text-slate-500">
                {(["warehouse", "product", "onHand", "point", "incoming", "onOrder", "status", "shortfall"] as const).map((c) => (
                  <th key={c} className="px-3 py-2 font-medium">
                    {t(`overview.reorder.${c}`)}
                  </th>
                ))}
                <th />
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => {
                const status = reorderStatus(r);
                return (
                  <tr key={`${r.location_id}:${r.variant_id}`} className="border-b border-slate-100" data-testid={`reorder-${r.location_code}-${r.sku}`}>
                    <td className="px-3 py-2">{r.location_code}</td>
                    <td className="px-3 py-2">
                      {r.product_name} · {r.sku}
                    </td>
                    <td className="px-3 py-2">{formatQty(r.qty_on_hand)}</td>
                    <td className="px-3 py-2">
                      <div className="flex items-center gap-1.5">
                        <span>{formatQty(r.reorder_point)}</span>
                        {r.is_override ? (
                          <Badge tone="neutral">
                            {t("overview.reorder.customOverride")}
                          </Badge>
                        ) : null}
                      </div>
                    </td>
                    <td className="px-3 py-2">{formatQty(r.incoming_qty)}</td>
                    <td className="px-3 py-2">{formatQty(r.on_order_qty)}</td>
                    <td className="px-3 py-2">
                      <Badge tone={status === "covered" ? "good" : status === "order" ? "warn" : "neutral"}>{t(`overview.reorder.statusLabel.${status}`)}</Badge>
                    </td>
                    <td className="px-3 py-2">{status === "order" ? formatQty(r.shortfall) : "—"}</td>
                    <td className="px-3 py-2">
                      <div className="flex items-center gap-2">
                        {status !== "covered" && can("purchasing.manage", r.location_id) ? (
                          <Link
                            to="/app/purchasing"
                            className="text-sm text-slate-700 underline"
                            data-testid={`new-order-${r.location_code}-${r.sku}`}
                            onClick={() => {
                              sessionStorage.setItem(
                                "xzactopos:draft-po",
                                JSON.stringify({
                                  warehouseId: r.location_id,
                                  lines: [
                                    {
                                      variantId: r.variant_id,
                                      qtyText: String(Math.max(1, r.shortfall)),
                                      costText: "",
                                    },
                                  ],
                                })
                              );
                            }}
                          >
                            {t("overview.reorder.newOrder")}
                          </Link>
                        ) : null}
                        {(can("purchasing.manage", r.location_id) || access.role === "superadmin") ? (
                          <Button
                            size="sm"
                            variant="ghost"
                            data-testid={`edit-threshold-${r.location_code}-${r.sku}`}
                            onClick={() => {
                              setEditingRow(r);
                              setEditPoint(String(r.reorder_point));
                              setEditError(null);
                            }}
                          >
                            {t("overview.reorder.editThreshold")}
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
      <p className="text-xs text-slate-500">{t("overview.reorder.legend")}</p>
      {q.hasNextPage ? (
        <div>
          <Button variant="outline" disabled={q.isFetchingNextPage} onClick={() => void q.fetchNextPage()} data-testid="reorder-more">
            {q.isFetchingNextPage ? t("overview.loading") : t("overview.showMore")}
          </Button>
        </div>
      ) : null}

      {editingRow ? (
        <Dialog
          open
          onOpenChange={(o) => {
            if (!o) {
              setEditingRow(null);
              setEditError(null);
            }
          }}
          title={t("overview.reorder.editThresholdTitle", { product: editingRow.product_name, warehouse: editingRow.location_code })}
          closeLabel={t("common:actions.close")}
        >
          <div className="grid gap-4 py-2">
            <p className="text-sm text-slate-600">{t("overview.reorder.editThresholdDesc")}</p>
            <div className="rounded-md border border-slate-200 bg-slate-50 p-3">
              <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                {t("overview.reorder.onHand")}
              </div>
              <div className="mt-1 text-lg font-semibold text-slate-900">
                {formatQty(editingRow.qty_on_hand)}
              </div>
            </div>

            <Field label={t("overview.reorder.point")}>
              <Input
                data-testid="reorder-point-input"
                type="number"
                min="0"
                step="any"
                autoFocus
                value={editPoint}
                onChange={(e) => setEditPoint(e.target.value)}
              />
            </Field>

            {editError ? <Alert tone="error">{editError}</Alert> : null}

            <div className="flex flex-wrap items-center justify-between gap-2 pt-2">
              {editingRow.is_override ? (
                <Button
                  type="button"
                  variant="outline"
                  data-testid="revert-default-btn"
                  disabled={saveThresholdMut.isPending}
                  onClick={() => saveThresholdMut.mutate(null)}
                >
                  {t("overview.reorder.revertDefault")}
                </Button>
              ) : <div />}

              <div className="flex items-center gap-2">
                <Button
                  type="button"
                  variant="ghost"
                  onClick={() => {
                    setEditingRow(null);
                    setEditError(null);
                  }}
                >
                  {t("common:actions.cancel")}
                </Button>
                <Button
                  type="button"
                  data-testid="save-threshold-btn"
                  disabled={saveThresholdMut.isPending || !editPoint.trim() || Number(editPoint) < 0}
                  onClick={() => saveThresholdMut.mutate(Number(editPoint))}
                >
                  {t("common:actions.save")}
                </Button>
              </div>
            </div>
          </div>
        </Dialog>
      ) : null}
    </div>
  );
}

/* ------------------------------------------------------------------------------------------------ below zero */

function NegativeTab() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const { access } = useSession();
  const currency = access.tenant.base_currency;
  const [locationId, setLocationId] = useState("");
  const locations = access.locations;
  const q = useInfiniteQuery({
    queryKey: ["overview", "negative", locationId],
    initialPageParam: null as { location: string; variant: string } | null,
    queryFn: ({ pageParam }) => negativeStockList({ locationId, afterLocation: pageParam?.location, afterVariant: pageParam?.variant }),
    getNextPageParam: (last) => nextNegativeCursor(last, PAGE_SIZE),
  });
  const rows: NegativeRow[] = (q.data?.pages ?? []).flat();
  const sum = negativeSummary(rows);
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);

  return (
    <div className="grid gap-4">
      <Card className="flex flex-wrap items-end gap-3">
        <Field label={t("overview.filter.warehouse")}>
          <Select value={locationId} onChange={(e) => setLocationId(e.target.value)} data-testid="ov-negative-location">
            <option value="">{t("overview.filter.all")}</option>
            {locations.map((l) => (
              <option key={l.id} value={l.id}>
                {l.code} · {l.name}
              </option>
            ))}
          </Select>
        </Field>
      </Card>
      {q.isError ? <ErrorState message={msg(q.error)} onRetry={() => void q.refetch()} retryLabel={t("common:actions.retry")} /> : null}
      {rows.length > 0 ? (
        <p className="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900" data-testid="negative-summary">
          {t("overview.negative.summary", { lines: sum.lines, places: sum.places, units: formatQty(sum.units), value: fmt(sum.value) })}
        </p>
      ) : null}
      <Card className="overflow-x-auto p-0">
        {q.isLoading ? (
          <TableSkeleton rows={5} cols={5} />
        ) : rows.length === 0 ? (
          <div data-testid="negative-none" className="p-4">
            <EmptyState title={t("overview.negative.none")} />
          </div>
        ) : (
          <Table bare>
            <thead>
              <tr className="border-b border-slate-200 text-slate-500">
                {(["place", "product", "onHand", "value", "lastMoved"] as const).map((c) => (
                  <th key={c} className="px-3 py-2 font-semibold">
                    {t(`overview.negative.${c}`)}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={`${r.location_id}:${r.variant_id}`} className="border-b border-slate-100" data-testid={`negative-${r.location_code}-${r.sku}`}>
                  <td className="px-3 py-2">
                    {r.location_code} <span className="text-xs text-slate-500">({t(`overview.negative.type.${r.location_type}`)})</span>
                  </td>
                  <td className="px-3 py-2">
                    {r.product_name} · {r.sku}
                  </td>
                  <td className="px-3 py-2 font-semibold text-red-700">{formatQty(r.qty_on_hand)}</td>
                  <td className="px-3 py-2">{r.stock_value === null ? "—" : fmt(r.stock_value)}</td>
                  <td className="px-3 py-2">{r.last_movement_at ? new Date(r.last_movement_at).toLocaleDateString(i18n.language) : "—"}</td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>
      <p className="text-xs text-slate-500">{t("overview.negative.legend")}</p>
      {q.hasNextPage ? (
        <div>
          <Button variant="outline" disabled={q.isFetchingNextPage} onClick={() => void q.fetchNextPage()} data-testid="negative-more">
            {q.isFetchingNextPage ? t("overview.loading") : t("overview.showMore")}
          </Button>
        </div>
      ) : null}
    </div>
  );
}

/* ------------------------------------------------------------------------------------------------ in transit */

function TransitTab({ warehouses }: { warehouses: Array<{ id: string; code: string; name: string }> }) {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const [warehouseId, setWarehouseId] = useState("");
  const q = useInfiniteQuery({
    queryKey: ["overview", "transit", warehouseId],
    initialPageParam: null as { shippedAt: string; id: string } | null,
    queryFn: ({ pageParam }) => warehouseTransfersInTransit({ warehouseId, afterShippedAt: pageParam?.shippedAt, afterId: pageParam?.id }),
    getNextPageParam: (last) => nextTransitCursor(last, PAGE_SIZE),
  });
  const rows: TransitRow[] = (q.data?.pages ?? []).flat();

  return (
    <div className="grid gap-4">
      <WarehouseFilter warehouses={warehouses} value={warehouseId} onChange={setWarehouseId} />
      {q.isError ? <ErrorState message={msg(q.error)} onRetry={() => void q.refetch()} retryLabel={t("common:actions.retry")} /> : null}
      <p className="text-sm text-slate-600">{t("overview.transit.help")}</p>
      <Card className="overflow-x-auto p-0">
        {q.isLoading ? (
          <TableSkeleton rows={5} cols={7} />
        ) : rows.length === 0 ? (
          <div data-testid="transit-none" className="p-4">
            <EmptyState title={t("overview.transit.none")} />
          </div>
        ) : (
          <Table bare>
            <thead>
              <tr className="border-b border-slate-200 text-slate-500">
                {(["no", "from", "to", "shipped", "age", "lines", "units"] as const).map((c) => (
                  <th key={c} className="px-3 py-2 font-semibold">
                    {t(`overview.transit.${c}`)}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => {
                const age = transitAge(r.hours_in_transit);
                const late = transitIsLate(r.hours_in_transit);
                return (
                  <tr key={r.transfer_id} className="border-b border-slate-100" data-testid={`transit-${r.transfer_no}`}>
                    <td className="px-3 py-2 font-mono text-xs">{r.transfer_no}</td>
                    <td className="px-3 py-2">{r.from_code ?? t("overview.transit.other")}</td>
                    <td className="px-3 py-2">{r.to_code ?? t("overview.transit.other")}</td>
                    <td className="px-3 py-2">{new Date(r.shipped_at).toLocaleDateString(i18n.language)}</td>
                    <td className="px-3 py-2">
                      {age.days > 0 ? t("overview.transit.ageDays", { days: age.days, hours: age.hours }) : t("overview.transit.ageHours", { hours: age.hours })}
                      {late ? (
                        <span className="ml-2">
                          <Badge tone="warn">{t("overview.transit.late")}</Badge>
                        </span>
                      ) : null}
                    </td>
                    <td className="px-3 py-2">{r.lines}</td>
                    <td className="px-3 py-2">{formatQty(r.units)}</td>
                  </tr>
                );
              })}
            </tbody>
          </Table>
        )}
      </Card>
      {q.hasNextPage ? (
        <div>
          <Button variant="outline" disabled={q.isFetchingNextPage} onClick={() => void q.fetchNextPage()} data-testid="transit-more">
            {q.isFetchingNextPage ? t("overview.loading") : t("overview.showMore")}
          </Button>
        </div>
      ) : null}
    </div>
  );
}

/* ------------------------------------------------------------------------------------------------ find a product */

function ProductTab() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const { access } = useSession();
  const currency = access.tenant.base_currency;
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);
  const [variantId, setVariantId] = useState("");
  const [productSearch, setProductSearch] = useState("");
  const variants = useQuery({ queryKey: ["po", "variants"], queryFn: listVariantOptions });
  const filteredVariants = useMemo(() => {
    const q = productSearch.trim().toLowerCase();
    if (!q) return variants.data ?? [];
    return (variants.data ?? []).filter((v) => {
      const name = (v.product?.name ?? "").toLowerCase();
      const sku = (v.sku ?? "").toLowerCase();
      return name.includes(q) || sku.includes(q);
    });
  }, [variants.data, productSearch]);
  const stock = useQuery({
    queryKey: ["overview", "stock", variantId],
    queryFn: () => warehouseStockByVariant(variantId),
    enabled: Boolean(variantId),
  });
  const rows = stock.data ?? [];
  const totals = stockTotals(rows);

  return (
    <div className="grid gap-4">
      <Card className="flex flex-wrap items-end gap-3">
        <Field label={t("overview.product.search", "Search product")}>
          <Input
            value={productSearch}
            onChange={(e) => setProductSearch(e.target.value)}
            placeholder={t("overview.product.searchPlaceholder", "Type name or SKU...")}
            className="w-56"
            data-testid="ov-search-variant"
          />
        </Field>
        <Field label={t("overview.product.product")}>
          <Select value={variantId} onChange={(e) => setVariantId(e.target.value)} data-testid="ov-variant">
            <option value="">{t("overview.product.choose")}</option>
            {filteredVariants.map((v) => (
              <option key={v.id} value={v.id}>
                {v.product?.name ?? v.sku} · {v.sku}
              </option>
            ))}
          </Select>
        </Field>
      </Card>
      {stock.isError ? <ErrorState message={msg(stock.error)} onRetry={() => void stock.refetch()} retryLabel={t("common:actions.retry")} /> : null}
      {!variantId ? (
        <p className="text-sm text-slate-500">{t("overview.product.prompt")}</p>
      ) : stock.isLoading ? (
        <Card className="p-0">
          <TableSkeleton rows={4} cols={6} />
        </Card>
      ) : rows.length === 0 ? (
        <EmptyState title={t("overview.product.none")} />
      ) : (
        <Card className="overflow-x-auto p-0" data-testid="product-table">
          <Table bare>
            <thead>
              <tr className="border-b border-slate-200 text-slate-500">
                {(["warehouse", "onHand", "incoming", "onOrder", "cost", "value"] as const).map((c) => (
                  <th key={c} className="px-3 py-2 font-semibold">
                    {t(`overview.product.${c}`)}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.location_id} className="border-b border-slate-100" data-testid={`stock-${r.code}`}>
                  <td className="px-3 py-2">
                    {r.code} · {r.name}
                  </td>
                  <td className="px-3 py-2">{formatQty(r.qty_on_hand)}</td>
                  <td className="px-3 py-2">{formatQty(r.incoming_qty)}</td>
                  <td className="px-3 py-2">{formatQty(r.on_order_qty)}</td>
                  <td className="px-3 py-2">{r.avg_cost === null ? "—" : fmt(r.avg_cost)}</td>
                  <td className="px-3 py-2">{r.stock_value === null ? "—" : fmt(r.stock_value)}</td>
                </tr>
              ))}
              <tr className="bg-slate-50 font-semibold" data-testid="stock-total">
                <td className="px-3 py-2">{t("overview.product.total")}</td>
                <td className="px-3 py-2">{formatQty(totals.qty)}</td>
                <td className="px-3 py-2">{formatQty(totals.incoming)}</td>
                <td className="px-3 py-2">{formatQty(totals.onOrder)}</td>
                <td className="px-3 py-2">—</td>
                <td className="px-3 py-2">{totals.value === null ? "—" : fmt(totals.value)}</td>
              </tr>
            </tbody>
          </Table>
        </Card>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------------------------------------ store replenishment */

function StoreReplenishmentTab({
  stores,
  warehouses,
}: {
  stores: ReadonlyArray<{ id: string; code: string; name: string }>;
  warehouses: ReadonlyArray<{ id: string; code: string; name: string }>;
}) {
  const { t } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const navigate = useNavigate();
  const { can } = useSession();
  const [storeId, setStoreId] = useState("");
  const q = useQuery({
    queryKey: ["overview", "store-replenishment", storeId, stores.map((s) => s.id).join(",")],
    queryFn: () => fetchStoreReplenishment({ stores, warehouses, storeId: storeId || undefined }),
    enabled: stores.length > 0,
  });
  const rows = q.data ?? [];

  return (
    <div className="grid gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2.5">
          <span className="text-xs font-semibold text-slate-500">{t("overview.stores.filterStore")}</span>
          <Select value={storeId} onChange={(e) => setStoreId(e.target.value)} data-testid="ov-store-filter" className="w-56">
            <option value="">{t("overview.stores.allStores")}</option>
            {stores.map((s) => (
              <option key={s.id} value={s.id}>
                {s.code} · {s.name}
              </option>
            ))}
          </Select>
        </div>
        <span className="text-sm font-medium text-slate-600" data-testid="store-replenish-summary">
          {t("overview.stores.summary", { count: rows.length })}
        </span>
      </div>

      {q.isError ? (
        <ErrorState
          message={msg(q.error)}
          onRetry={() => void q.refetch()}
          retryLabel={t("common:actions.retry")}
        />
      ) : null}

      <Card className="overflow-x-auto p-0">
        {q.isLoading ? (
          <TableSkeleton rows={5} cols={7} />
        ) : rows.length === 0 ? (
          <div className="p-4" data-testid="store-replenish-none">
            <EmptyState title={t("overview.stores.none")} />
          </div>
        ) : (
          <Table bare>
            <thead>
              <tr className="border-b border-slate-200 text-slate-500">
                {(["store", "product", "storeStock", "point", "shortfall", "warehouseAvail", "actions"] as const).map((c) => (
                  <th key={c} className="px-3 py-2 font-semibold">
                    {t(`overview.stores.${c}`)}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr
                  key={`${r.store_id}:${r.variant_id}`}
                  className="border-b border-slate-100"
                  data-testid={`store-replenish-${r.store_code}-${r.sku}`}
                >
                  <td className="px-3 py-2 font-medium">{r.store_code} · {r.store_name}</td>
                  <td className="px-3 py-2">{r.product_name} · {r.sku}</td>
                  <td className="px-3 py-2">
                    <Badge tone={r.store_qty <= 0 ? "danger" : "warn"}>{formatQty(r.store_qty)}</Badge>
                  </td>
                  <td className="px-3 py-2">{formatQty(r.reorder_point)}</td>
                  <td className="px-3 py-2 font-medium text-amber-700">{formatQty(r.shortfall)}</td>
                  <td className="px-3 py-2">
                    {r.warehouse_total > 0 ? (
                      <span className="text-sm text-emerald-700">
                        {formatQty(r.warehouse_total)} ({r.best_warehouse_code}: {formatQty(r.best_warehouse_qty)})
                      </span>
                    ) : (
                      <span className="text-xs text-slate-400">{t("overview.stores.noWarehouseStock")}</span>
                    )}
                  </td>
                  <td className="px-3 py-2">
                    {r.best_warehouse_id && can("transfer.manage", r.best_warehouse_id) ? (
                      <Button
                        size="sm"
                        variant="outline"
                        data-testid={`dispatch-store-${r.store_code}-${r.sku}`}
                        onClick={() => {
                          sessionStorage.setItem(
                            "xzactopos:draft-transfer",
                            JSON.stringify({
                              fromLocationId: r.best_warehouse_id,
                              toLocationId: r.store_id,
                              items: [{ variantId: r.variant_id, qty: Math.min(r.shortfall, r.best_warehouse_qty) }],
                            }),
                          );
                          void navigate({ to: "/app/transfers" });
                        }}
                      >
                        {t("overview.stores.dispatch")}
                      </Button>
                    ) : null}
                  </td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>
    </div>
  );
}
