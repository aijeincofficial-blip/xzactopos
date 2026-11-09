import { useState } from "react";
import { useInfiniteQuery, useQuery } from "@tanstack/react-query";
import { Link } from "@tanstack/react-router";
import { useTranslation } from "react-i18next";
import { formatMoney, money } from "@pos/core";
import { Alert, Badge, Button, Card, Field, Select, Table, PageHeader, Tabs, TabPanel } from "../components/ui.tsx";
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
  negativeStockList,
  warehouseReorderList,
  warehouseStockByVariant,
  warehouseTransfersInTransit,
  type NegativeRow,
  type ReorderRow,
  type TransitRow,
} from "../lib/overview-api.ts";
import { listCountWarehouses } from "../lib/counts-api.ts";
import { listVariantOptions } from "../lib/purchasing-api.ts";

type Tab = "reorder" | "transit" | "product" | "negative";

export function OverviewPage() {
  const { t } = useTranslation("admin");
  const { can } = useSession();
  const [tab, setTab] = useState<Tab>("reorder");
  const warehousesQ = useQuery({ queryKey: ["overview", "warehouses"], queryFn: listCountWarehouses });
  const warehouses = (warehousesQ.data ?? []).filter((w) => can("reports.warehouse", w.id));

  return (
    <div className="grid gap-4">
      <PageHeader title={t("overview.title")} subtitle={t("overview.subtitle")} />
      {warehousesQ.isSuccess && warehouses.length === 0 ? <Alert tone="info">{t("overview.noWarehouses")}</Alert> : null}
      <Tabs
        value={tab}
        onValueChange={(v) => setTab(v as Tab)}
        label={t("overview.title")}
        tabs={(["reorder", "transit", "product", "negative"] as const).map((k) => ({ value: k, label: t(`overview.tabs.${k}`), testId: `ov-tab-${k}` }))}
      >
        <TabPanel value={tab}>
          {tab === "reorder" ? <ReorderTab warehouses={warehouses} /> : tab === "transit" ? <TransitTab warehouses={warehouses} /> : tab === "negative" ? <NegativeTab /> : <ProductTab />}
        </TabPanel>
      </Tabs>
    </div>
  );
}

function WarehouseFilter({
  warehouses,
  value,
  onChange,
}: {
  warehouses: Array<{ id: string; code: string; name: string }>;
  value: string;
  onChange: (v: string) => void;
}) {
  const { t } = useTranslation("admin");
  return (
    <Card className="flex flex-wrap items-end gap-3">
      <Field label={t("overview.filter.warehouse")}>
        <Select value={value} onChange={(e) => onChange(e.target.value)} data-testid="ov-warehouse">
          <option value="">{t("overview.filter.all")}</option>
          {warehouses.map((w) => (
            <option key={w.id} value={w.id}>
              {w.code} · {w.name}
            </option>
          ))}
        </Select>
      </Field>
    </Card>
  );
}

/* ------------------------------------------------------------------------------------------------ reorder */

function ReorderTab({ warehouses }: { warehouses: Array<{ id: string; code: string; name: string }> }) {
  const { t } = useTranslation("admin");
  const msg = useErrorMessage();
  const { can } = useSession();
  const [warehouseId, setWarehouseId] = useState("");
  const q = useInfiniteQuery({
    queryKey: ["overview", "reorder", warehouseId],
    initialPageParam: null as { location: string; variant: string } | null,
    queryFn: ({ pageParam }) => warehouseReorderList({ warehouseId, afterLocation: pageParam?.location, afterVariant: pageParam?.variant }),
    getNextPageParam: (last) => nextReorderCursor(last, PAGE_SIZE),
  });
  const rows: ReorderRow[] = (q.data?.pages ?? []).flat();
  const sum = reorderSummary(rows);

  return (
    <div className="grid gap-4">
      <WarehouseFilter warehouses={warehouses} value={warehouseId} onChange={setWarehouseId} />
      {q.isError ? <Alert>{msg(q.error)}</Alert> : null}
      {rows.length > 0 ? (
        <p className="text-sm text-slate-700" data-testid="reorder-summary">
          {t("overview.reorder.summary", { need: sum.needOrder, covered: sum.covered, atPoint: sum.atPoint })}
        </p>
      ) : null}
      <Card className="overflow-x-auto p-0">
        {q.isLoading ? (
          <p className="p-4 text-sm text-slate-500">{t("overview.loading")}</p>
        ) : rows.length === 0 ? (
          <p className="p-4 text-sm text-slate-500" data-testid="reorder-none">
            {t("overview.reorder.none")}
          </p>
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
                    <td className="px-3 py-2">{formatQty(r.reorder_point)}</td>
                    <td className="px-3 py-2">{formatQty(r.incoming_qty)}</td>
                    <td className="px-3 py-2">{formatQty(r.on_order_qty)}</td>
                    <td className="px-3 py-2">
                      <Badge tone={status === "covered" ? "good" : status === "order" ? "warn" : "neutral"}>{t(`overview.reorder.statusLabel.${status}`)}</Badge>
                    </td>
                    <td className="px-3 py-2">{status === "order" ? formatQty(r.shortfall) : "—"}</td>
                    <td className="px-3 py-2">
                      {status !== "covered" && can("purchasing.manage", r.location_id) ? (
                        <Link to="/app/purchasing" className="text-sm text-slate-700 underline">
                          {t("overview.reorder.newOrder")}
                        </Link>
                      ) : null}
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
    </div>
  );
}

/* ------------------------------------------------------------------------------------------------ below zero */

function NegativeTab() {
  const { t, i18n } = useTranslation("admin");
  const msg = useErrorMessage();
  const { access } = useSession();
  const currency = access.tenant.base_currency;
  const q = useInfiniteQuery({
    queryKey: ["overview", "negative"],
    initialPageParam: null as { location: string; variant: string } | null,
    queryFn: ({ pageParam }) => negativeStockList({ afterLocation: pageParam?.location, afterVariant: pageParam?.variant }),
    getNextPageParam: (last) => nextNegativeCursor(last, PAGE_SIZE),
  });
  const rows: NegativeRow[] = (q.data?.pages ?? []).flat();
  const sum = negativeSummary(rows);
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);

  return (
    <div className="grid gap-4">
      {q.isError ? <Alert>{msg(q.error)}</Alert> : null}
      {rows.length > 0 ? (
        <p className="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900" data-testid="negative-summary">
          {t("overview.negative.summary", { lines: sum.lines, places: sum.places, units: formatQty(sum.units), value: fmt(sum.value) })}
        </p>
      ) : null}
      <Card className="overflow-x-auto p-0">
        {q.isLoading ? (
          <p className="p-4 text-sm text-slate-500">{t("overview.loading")}</p>
        ) : rows.length === 0 ? (
          <p className="p-4 text-sm text-slate-500" data-testid="negative-none">
            {t("overview.negative.none")}
          </p>
        ) : (
          <Table bare>
            <thead>
              <tr className="border-b border-slate-200 text-slate-500">
                {(["place", "product", "onHand", "value", "lastMoved"] as const).map((c) => (
                  <th key={c} className="px-3 py-2 font-medium">
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
                  <td className="px-3 py-2 font-medium text-red-700">{formatQty(r.qty_on_hand)}</td>
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
  const { t, i18n } = useTranslation("admin");
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
      {q.isError ? <Alert>{msg(q.error)}</Alert> : null}
      <p className="text-sm text-slate-600">{t("overview.transit.help")}</p>
      <Card className="overflow-x-auto p-0">
        {q.isLoading ? (
          <p className="p-4 text-sm text-slate-500">{t("overview.loading")}</p>
        ) : rows.length === 0 ? (
          <p className="p-4 text-sm text-slate-500" data-testid="transit-none">
            {t("overview.transit.none")}
          </p>
        ) : (
          <Table bare>
            <thead>
              <tr className="border-b border-slate-200 text-slate-500">
                {(["no", "from", "to", "shipped", "age", "lines", "units"] as const).map((c) => (
                  <th key={c} className="px-3 py-2 font-medium">
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
  const { t, i18n } = useTranslation("admin");
  const msg = useErrorMessage();
  const { access } = useSession();
  const currency = access.tenant.base_currency;
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);
  const [variantId, setVariantId] = useState("");
  const variants = useQuery({ queryKey: ["po", "variants"], queryFn: listVariantOptions });
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
        <Field label={t("overview.product.product")}>
          <Select value={variantId} onChange={(e) => setVariantId(e.target.value)} data-testid="ov-variant">
            <option value="">{t("overview.product.choose")}</option>
            {(variants.data ?? []).map((v) => (
              <option key={v.id} value={v.id}>
                {v.product?.name ?? v.sku} · {v.sku}
              </option>
            ))}
          </Select>
        </Field>
      </Card>
      {stock.isError ? <Alert>{msg(stock.error)}</Alert> : null}
      {!variantId ? (
        <p className="text-sm text-slate-500">{t("overview.product.prompt")}</p>
      ) : stock.isLoading ? (
        <p className="text-sm text-slate-500">{t("overview.loading")}</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-slate-500">{t("overview.product.none")}</p>
      ) : (
        <Card className="overflow-x-auto p-0" data-testid="product-table">
          <Table bare>
            <thead>
              <tr className="border-b border-slate-200 text-slate-500">
                {(["warehouse", "onHand", "incoming", "onOrder", "cost", "value"] as const).map((c) => (
                  <th key={c} className="px-3 py-2 font-medium">
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
              <tr className="bg-slate-50 font-medium" data-testid="stock-total">
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
