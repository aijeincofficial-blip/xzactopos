import { useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { useNavigate, useRouterState } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { ArrowDownToLine, ArrowLeftRight, Boxes, ClipboardCheck, Package, SlidersHorizontal } from "lucide-react";
import {
  Alert,
  Badge,
  Button,
  Card,
  Dialog,
  EmptyState,
  ErrorState,
  Field,
  Input,
  PageHeader,
  Select,
  StatCard,
  TabPanel,
  Table,
  TableSkeleton,
  Tabs,
  Td,
  Th,
  useToast,
} from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { tenantMode } from "../lib/mode.ts";
import { readStoredPortal, resolveEffectivePortal } from "../lib/portal.ts";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { parseAmount } from "../lib/sale-math.ts";
import { formatQty, parseQty, stockStatus } from "../lib/product-math.ts";
import {
  countStock,
  fetchCategories,
  fetchProductRows,
  fetchStockMovements,
  getExpiryStatus,
  openPack,
  receiveStock,
  setExpiry,
  type MovementFilterCategory,
  type ProductRow,
  type StockMovementType,
} from "../lib/stock-api.ts";

type StockFilter = "all" | "low" | "out" | "expiring";
type MovementFilter = "all" | MovementFilterCategory;

const KNOWN_MOVEMENT_TYPES: ReadonlySet<string> = new Set<StockMovementType>([
  "opening",
  "sale",
  "sale_void",
  "sale_return",
  "receipt",
  "count_correction",
  "damage",
  "conversion_out",
  "conversion_in",
  "conversion_void",
  "transfer_out",
  "transfer_in",
  "bin_move",
]);

function movementTone(type: string, qtyDelta: number): "good" | "warn" | "danger" | "neutral" {
  if (type === "damage" || type === "sale_void") return "danger";
  if (type === "transfer_in" || type === "receipt" || type === "opening" || type === "sale_return") return "good";
  if (type === "transfer_out" || type === "count_correction") return "warn";
  return qtyDelta > 0 ? "good" : "neutral";
}

function StoreStockActionDialog({
  row,
  allRows,
  currency,
  locationId,
  locationLabel,
  canSeeCost,
  onClose,
}: {
  row: ProductRow;
  allRows: ReadonlyArray<ProductRow>;
  currency: string;
  locationId: string;
  locationLabel: string;
  canSeeCost: boolean;
  onClose: () => void;
}) {
  const { t } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const qc = useQueryClient();
  const toast = useToast();

  const hasRepack = Boolean(row.breaksIntoVariantId && row.breaksIntoQty);
  const pieceRow = hasRepack ? allRows.find((r) => r.variantId === row.breaksIntoVariantId) ?? null : null;

  const [actionTab, setActionTab] = useState<"count" | "restock" | "repack" | "expiry">("count");
  const [countedText, setCountedText] = useState(() => formatQty(Math.max(0, row.qty)));
  const [reason, setReason] = useState<"counted" | "damage" | "other">("counted");

  const [addQtyText, setAddQtyText] = useState("");
  const [unitCostText, setUnitCostText] = useState("");
  const [restockExpiry, setRestockExpiry] = useState(row.expiresOn ?? "");

  const [packsText, setPacksText] = useState("1");
  const [expiryOnly, setExpiryOnly] = useState(row.expiresOn ?? "");
  const [formError, setFormError] = useState<string | null>(null);

  async function refreshInventory() {
    await Promise.all([
      qc.invalidateQueries({ queryKey: ["products"] }),
      qc.invalidateQueries({ queryKey: ["stock-movements"] }),
      qc.invalidateQueries({ queryKey: ["sellables"] }),
    ]);
  }

  const countMutation = useMutation({
    mutationFn: async () => {
      const n = parseQty(countedText, { allowZero: true });
      if (n === null) throw new Error("qty_invalid");
      return countStock(row.variantId, n, reason, locationId);
    },
    onSuccess: async (res) => {
      const sign = res.delta > 0 ? "+" : "";
      toast.good(t("admin:products.counted", { delta: `${sign}${formatQty(res.delta)}` }));
      await refreshInventory();
      onClose();
    },
    onError: (e) => {
      const m = e instanceof Error && e.message === "qty_invalid" ? t("admin:products.problem.count") : msg(e);
      setFormError(m);
    },
  });

  const restockMutation = useMutation({
    mutationFn: async () => {
      const n = parseQty(addQtyText);
      if (n === null) throw new Error("qty_invalid");
      const costMinor = canSeeCost && unitCostText.trim() !== "" ? parseAmount(unitCostText, currency) : null;
      if (canSeeCost && unitCostText.trim() !== "" && costMinor === null) throw new Error("cost_invalid");
      return receiveStock(row.variantId, n, costMinor, locationId, restockExpiry || null);
    },
    onSuccess: async () => {
      toast.good(t("admin:products.received"));
      await refreshInventory();
      onClose();
    },
    onError: (e) => {
      const m =
        e instanceof Error && e.message === "qty_invalid"
          ? t("admin:products.problem.qty")
          : e instanceof Error && e.message === "cost_invalid"
            ? t("admin:products.problem.cost")
            : msg(e);
      setFormError(m);
    },
  });

  const repackMutation = useMutation({
    mutationFn: async () => {
      const packs = parseInt(packsText, 10);
      if (!Number.isFinite(packs) || packs <= 0) throw new Error("qty_invalid");
      return openPack(row.variantId, packs, locationId);
    },
    onSuccess: async () => {
      const packs = parseInt(packsText, 10) || 1;
      const produced = packs * (row.breaksIntoQty ?? 1);
      toast.good(
        t("admin:products.openPackSuccess", {
          packs,
          pieces: produced,
        }),
      );
      await refreshInventory();
      onClose();
    },
    onError: (e) => {
      const m = e instanceof Error && e.message === "qty_invalid" ? t("admin:products.problem.qty") : msg(e);
      setFormError(m);
    },
  });

  const expiryMutation = useMutation({
    mutationFn: (dateVal: string | null) => setExpiry(row.variantId, dateVal, locationId),
    onSuccess: async () => {
      toast.good(t("admin:products.expirySaved"));
      await refreshInventory();
      onClose();
    },
    onError: (e) => setFormError(msg(e)),
  });

  const dialogTabs = [
    { value: "count", label: t("admin:inventory.actionTabCount") },
    { value: "restock", label: t("admin:inventory.actionTabRestock") },
    ...(hasRepack ? [{ value: "repack", label: t("admin:inventory.actionTabRepack") }] : []),
    { value: "expiry", label: t("admin:inventory.actionTabExpiry") },
  ];

  return (
    <Dialog
      open
      onOpenChange={(v) => {
        if (!v) onClose();
      }}
      title={t("admin:inventory.dialogTitle", { name: row.name })}
      closeLabel={t("common:actions.close")}
    >
      <div className="grid gap-4">
        <div className="rounded-md border border-slate-200 bg-slate-50 px-3 py-2 text-xs text-slate-700">
          <span className="font-semibold">
            {t("admin:inventory.dialogCurrentOnHand", {
              location: locationLabel,
              qty: formatQty(row.qty),
              unit: row.unit,
            })}
          </span>
          <span className="ml-2 font-mono text-slate-500">({row.sku})</span>
        </div>

        {formError ? <Alert tone="error">{formError}</Alert> : null}

        <Tabs
          value={actionTab}
          onValueChange={(v) => {
            setFormError(null);
            setActionTab(v as typeof actionTab);
          }}
          tabs={dialogTabs}
          label={row.name}
        >
          <TabPanel value="count">
            <div className="grid gap-3">
              <Field label={t("admin:products.countedQty")}>
                <Input
                  data-testid="inventory-count-input"
                  inputMode="decimal"
                  value={countedText}
                  onChange={(e) => setCountedText(e.target.value)}
                />
              </Field>
              <Field label={t("admin:products.reason")}>
                <Select value={reason} onChange={(e) => setReason(e.target.value as "counted" | "damage" | "other")}>
                  <option value="counted">{t("admin:products.reasons.counted")}</option>
                  <option value="damage">{t("admin:products.reasons.damage")}</option>
                  <option value="other">{t("admin:products.reasons.other")}</option>
                </Select>
              </Field>
              <div className="flex justify-end gap-2 pt-2">
                <Button variant="outline" onClick={onClose}>
                  {t("common:actions.cancel")}
                </Button>
                <Button
                  data-testid="inventory-count-submit"
                  disabled={countMutation.isPending}
                  onClick={() => countMutation.mutate()}
                >
                  {t("admin:products.setCount")}
                </Button>
              </div>
            </div>
          </TabPanel>

          <TabPanel value="restock">
            <div className="grid gap-3">
              <Field label={t("admin:products.receiveQty")}>
                <Input
                  data-testid="inventory-restock-qty"
                  inputMode="decimal"
                  placeholder="0"
                  value={addQtyText}
                  onChange={(e) => setAddQtyText(e.target.value)}
                />
              </Field>
              {canSeeCost ? (
                <Field label={t("admin:products.receiveCost")}>
                  <Input
                    inputMode="decimal"
                    placeholder="0.00"
                    value={unitCostText}
                    onChange={(e) => setUnitCostText(e.target.value)}
                  />
                </Field>
              ) : null}
              <Field label={t("admin:products.expiresOn")}>
                <Input type="date" value={restockExpiry} onChange={(e) => setRestockExpiry(e.target.value)} />
              </Field>
              <div className="flex justify-end gap-2 pt-2">
                <Button variant="outline" onClick={onClose}>
                  {t("common:actions.cancel")}
                </Button>
                <Button
                  data-testid="inventory-restock-submit"
                  disabled={restockMutation.isPending}
                  onClick={() => restockMutation.mutate()}
                >
                  {t("admin:products.receive")}
                </Button>
              </div>
            </div>
          </TabPanel>

          {hasRepack ? (
            <TabPanel value="repack">
              <div className="grid gap-3">
                <p className="text-xs text-slate-600">
                  1 {row.unit} = {row.breaksIntoQty} {pieceRow?.unit ?? "pc"}{" "}
                  {pieceRow ? `(${pieceRow.name})` : ""}
                </p>
                <Field label={t("admin:products.packsToOpen")}>
                  <Input
                    type="number"
                    min="1"
                    max="10000"
                    value={packsText}
                    onChange={(e) => setPacksText(e.target.value)}
                  />
                </Field>
                <Field label={t("admin:products.piecesProduced")}>
                  <div className="flex h-9 items-center rounded-md border border-slate-200 bg-slate-50 px-3 text-sm font-semibold text-slate-900 tabular-nums">
                    {(parseInt(packsText, 10) || 0) * (row.breaksIntoQty ?? 0)} {pieceRow?.unit ?? "pc"}
                  </div>
                </Field>
                <div className="flex justify-end gap-2 pt-2">
                  <Button variant="outline" onClick={onClose}>
                    {t("common:actions.cancel")}
                  </Button>
                  <Button disabled={repackMutation.isPending} onClick={() => repackMutation.mutate()}>
                    {t("admin:products.openPack")}
                  </Button>
                </div>
              </div>
            </TabPanel>
          ) : null}

          <TabPanel value="expiry">
            <div className="grid gap-3">
              <Field label={t("admin:products.expiresOn")}>
                <Input type="date" value={expiryOnly} onChange={(e) => setExpiryOnly(e.target.value)} />
              </Field>
              <div className="flex justify-end gap-2 pt-2">
                {row.expiresOn ? (
                  <Button
                    variant="outline"
                    disabled={expiryMutation.isPending}
                    onClick={() => expiryMutation.mutate(null)}
                  >
                    {t("admin:products.clearExpiry")}
                  </Button>
                ) : null}
                <Button
                  disabled={expiryMutation.isPending}
                  onClick={() => expiryMutation.mutate(expiryOnly || null)}
                >
                  {t("admin:products.setExpiry")}
                </Button>
              </div>
            </div>
          </TabPanel>
        </Tabs>
      </div>
    </Dialog>
  );
}

export function InventoryPage() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const navigate = useNavigate();
  const { access, can } = useSession();
  const { activeStore, activeWarehouse } = useActiveLocation();
  const path = useRouterState({ select: (s) => s.location.pathname });
  const mode = tenantMode(access);
  const activePortal = resolveEffectivePortal(access, mode, path, readStoredPortal());
  const isWarehousePortal = activePortal === "warehouse";

  const activeLoc = isWarehousePortal
    ? activeWarehouse ?? access.locations.find((l) => l.type === "warehouse") ?? access.locations[0] ?? null
    : activeStore ?? access.locations.find((l) => l.type === "store") ?? access.locations[0] ?? null;

  const currency = access.tenant.base_currency;
  const fmtMoney = (minor: number) => formatMoney(money(minor, currency), i18n.language);

  const [tab, setTab] = useState<"stock" | "movements">("stock");
  const [search, setSearch] = useState("");
  const [categoryId, setCategoryId] = useState("");
  const [stockFilter, setStockFilter] = useState<StockFilter>("all");
  const [movFilter, setMovFilter] = useState<MovementFilter>("all");
  const [movSearch, setMovSearch] = useState("");
  const [adjustingRow, setAdjustingRow] = useState<ProductRow | null>(null);

  const productsQuery = useQuery({
    queryKey: ["products", activeLoc?.id, currency],
    queryFn: () => fetchProductRows(currency, activeLoc!.id),
    enabled: Boolean(activeLoc?.id),
  });

  const categoriesQuery = useQuery({
    queryKey: ["categories"],
    queryFn: fetchCategories,
    enabled: Boolean(activeLoc?.id),
  });

  const movementsQuery = useQuery({
    queryKey: ["stock-movements", activeLoc?.id],
    queryFn: () => fetchStockMovements(activeLoc!.id, 150),
    enabled: Boolean(activeLoc?.id),
  });

  const allRows = productsQuery.data ?? [];
  const categories = categoriesQuery.data ?? [];

  const kpis = useMemo(() => {
    let trackedCount = 0;
    let totalUnits = 0;
    let retailMinor = 0;
    let costMinor = 0;
    let outCount = 0;
    let lowCount = 0;
    let expiringCount = 0;

    for (const r of allRows) {
      if (r.tracked) {
        trackedCount += 1;
        const positiveQty = Math.max(0, r.qty);
        totalUnits += positiveQty;
        if (r.price != null) retailMinor += Math.round(positiveQty * r.price);
        costMinor += Math.round(positiveQty * r.cost);

        const st = stockStatus(r);
        if (st === "out") outCount += 1;
        else if (st === "low") lowCount += 1;
      }
      const exp = getExpiryStatus(r.expiresOn);
      if (exp === "expired" || exp === "expiring_soon") expiringCount += 1;
    }
    return {
      trackedCount,
      totalCount: allRows.length,
      totalUnits,
      retailMinor,
      costMinor,
      outCount,
      lowCount,
      expiringCount,
      alertTotal: outCount + lowCount + expiringCount,
    };
  }, [allRows]);

  const filteredStockRows = useMemo(() => {
    const needle = search.trim().toLowerCase();
    return allRows.filter((r) => {
      if (needle) {
        const hit =
          r.name.toLowerCase().includes(needle) ||
          r.sku.toLowerCase().includes(needle) ||
          r.barcode?.toLowerCase() === needle ||
          Boolean(r.barcode?.toLowerCase().includes(needle));
        if (!hit) return false;
      }
      if (categoryId && r.categoryId !== categoryId) return false;
      if (stockFilter === "low" && stockStatus(r) !== "low") return false;
      if (stockFilter === "out" && stockStatus(r) !== "out") return false;
      if (stockFilter === "expiring") {
        const exp = getExpiryStatus(r.expiresOn);
        if (exp !== "expired" && exp !== "expiring_soon") return false;
      }
      return true;
    });
  }, [allRows, search, categoryId, stockFilter]);

  const filteredMovements = useMemo(() => {
    const rows = movementsQuery.data ?? [];
    const needle = movSearch.trim().toLowerCase();
    return rows.filter((m) => {
      if (movFilter !== "all" && m.category !== movFilter) return false;
      if (needle) {
        const hit = m.productName.toLowerCase().includes(needle) || m.sku.toLowerCase().includes(needle);
        if (!hit) return false;
      }
      return true;
    });
  }, [movementsQuery.data, movFilter, movSearch]);

  if (!activeLoc) {
    return (
      <Card>
        <p className="text-sm text-slate-600">{t("admin:sell.noStore")}</p>
      </Card>
    );
  }

  const canManageCatalog = can("catalog.manage", activeLoc.id);
  const canSeeCost = canManageCatalog || can("reports.warehouse", activeLoc.id);
  const canAdjustStoreStock = activeLoc.type === "store" && can("stock.adjust_store", activeLoc.id);
  const canOpenBins =
    activeLoc.type === "warehouse" &&
    (can("transfer.manage", activeLoc.id) ||
      can("stock.adjust_store", activeLoc.id) ||
      can("locations.manage", activeLoc.id));
  const showActionsCol = canAdjustStoreStock || canOpenBins;

  const canReceiveWarehouseInPos =
    !isWarehousePortal && mode === "full" && access.modules.warehouse && can("sale.create", activeLoc.id);
  const canDispatchToPos = isWarehousePortal && can("transfer.manage", activeLoc.id);
  const canCountWarehouse = isWarehousePortal && can("stock.adjust_warehouse", activeLoc.id);

  // Enforce strictly max ONE solid primary CTA in the PageHeader
  const hasPrimaryWarehouseDispatch = canDispatchToPos;
  const hasPrimaryPosReceive = !isWarehousePortal && canReceiveWarehouseInPos;

  return (
    <div className="grid gap-6" data-testid="inventory-page">
      <PageHeader
        title={isWarehousePortal ? t("admin:inventory.warehouseTitle") : t("admin:inventory.storeTitle")}
        subtitle={t("admin:inventory.subtitle", { location: `${activeLoc.code} · ${activeLoc.name}` })}
        actions={
          <>
            {canManageCatalog ? (
              <Button
                variant={hasPrimaryPosReceive || hasPrimaryWarehouseDispatch ? "outline" : "primary"}
                size="sm"
                data-testid="inventory-products-btn"
                onClick={() => void navigate({ to: "/app/products" })}
              >
                <Package size={15} aria-hidden />
                <span>{t("admin:inventory.manageCatalogBtn")}</span>
              </Button>
            ) : null}
            {canCountWarehouse ? (
              <Button
                variant="outline"
                size="sm"
                onClick={() => void navigate({ to: "/app/counts" })}
              >
                <ClipboardCheck size={15} aria-hidden />
                <span>{t("admin:inventory.cycleCountsBtn")}</span>
              </Button>
            ) : null}
            {canReceiveWarehouseInPos ? (
              <Button
                size="sm"
                data-testid="inventory-receive-warehouse-btn"
                onClick={() => void navigate({ to: "/app/receive-stock" })}
              >
                <ArrowDownToLine size={15} aria-hidden />
                <span>{t("admin:inventory.receiveFromWarehouseBtn")}</span>
              </Button>
            ) : null}
            {canDispatchToPos ? (
              <Button
                size="sm"
                data-testid="inventory-dispatch-pos-btn"
                onClick={() => void navigate({ to: "/app/transfers" })}
              >
                <ArrowLeftRight size={15} aria-hidden />
                <span>{t("admin:inventory.dispatchToPosBtn")}</span>
              </Button>
            ) : null}
          </>
        }
      />

      {/* KPI Summary Row */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label={t("admin:inventory.kpiTrackedSkus")}
          value={<span className="tabular-nums">{kpis.trackedCount}</span>}
          subtext={t("admin:inventory.kpiTrackedSubtext", { total: kpis.totalCount })}
        />
        <StatCard
          label={t("admin:inventory.kpiUnitsOnHand")}
          value={<span className="tabular-nums">{formatQty(kpis.totalUnits)}</span>}
          subtext={t("admin:inventory.kpiUnitsSubtext", { code: activeLoc.code })}
        />
        <StatCard
          label={t("admin:inventory.kpiRetailValue")}
          value={<span className="tabular-nums">{fmtMoney(kpis.retailMinor)}</span>}
          subtext={
            canSeeCost
              ? t("admin:inventory.kpiCostSubtext", { cost: fmtMoney(kpis.costMinor) })
              : t("admin:inventory.kpiRetailSubtext")
          }
        />
        <StatCard
          label={t("admin:inventory.kpiAlerts")}
          value={
            <span className={kpis.alertTotal > 0 ? "text-amber-700 tabular-nums" : "tabular-nums"}>
              {kpis.alertTotal}
            </span>
          }
          subtext={t("admin:inventory.kpiAlertsSubtext", {
            out: kpis.outCount,
            low: kpis.lowCount,
            expiring: kpis.expiringCount,
          })}
        />
      </div>

      <Tabs
        value={tab}
        onValueChange={(v) => setTab(v as "stock" | "movements")}
        label={isWarehousePortal ? t("admin:inventory.warehouseTitle") : t("admin:inventory.storeTitle")}
        tabs={[
          {
            value: "stock",
            label: `${t("admin:inventory.tabStock")} (${allRows.length})`,
            testId: "inventory-tab-stock",
          },
          {
            value: "movements",
            label: t("admin:inventory.tabMovements"),
            testId: "inventory-tab-movements",
          },
        ]}
      >
        <TabPanel value="stock">
          <div className="grid gap-4">
            <div className="grid gap-2 sm:grid-cols-[1fr_220px]">
              <Input
                data-testid="inventory-search"
                placeholder={t("admin:inventory.searchPlaceholder")}
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
              <Select
                aria-label={t("admin:inventory.allCategories")}
                value={categoryId}
                onChange={(e) => setCategoryId(e.target.value)}
              >
                <option value="">{t("admin:inventory.allCategories")}</option>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </Select>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              {(
                [
                  { id: "all", label: t("admin:inventory.filterAll") },
                  { id: "low", label: `${t("admin:inventory.filterLow")} (${kpis.lowCount})` },
                  { id: "out", label: `${t("admin:inventory.filterOut")} (${kpis.outCount})` },
                  { id: "expiring", label: `${t("admin:inventory.filterExpiring")} (${kpis.expiringCount})` },
                ] as const
              ).map((f) => (
                <Button
                  key={f.id}
                  variant="outline"
                  size="sm"
                  className={stockFilter === f.id ? "border-brand-600 bg-brand-50 text-brand-text" : ""}
                  onClick={() => setStockFilter(f.id)}
                >
                  {f.label}
                </Button>
              ))}
            </div>

            {productsQuery.isPending ? (
              <Card className="p-0">
                <TableSkeleton rows={6} cols={6} />
              </Card>
            ) : productsQuery.isError ? (
              <ErrorState
                message={msg(productsQuery.error)}
                retryLabel={t("common:actions.retry")}
                onRetry={() => void productsQuery.refetch()}
              />
            ) : filteredStockRows.length === 0 ? (
              <EmptyState
                title={t("admin:inventory.emptyTitle")}
                hint={t("admin:inventory.emptyHint")}
              />
            ) : (
              <Table data-testid="inventory-stock-table">
                <thead>
                  <tr>
                    <Th>{t("admin:inventory.colProduct")}</Th>
                    <Th>{t("admin:inventory.colSku")}</Th>
                    <Th>{t("admin:inventory.colStatus")}</Th>
                    <Th numeric>{t("admin:inventory.colReorder")}</Th>
                    <Th numeric>{t("admin:inventory.colOnHand")}</Th>
                    <Th numeric>{t("admin:inventory.colPrice")}</Th>
                    {showActionsCol ? <Th numeric>{t("admin:inventory.colActions")}</Th> : null}
                  </tr>
                </thead>
                <tbody>
                  {filteredStockRows.map((r) => {
                    const st = stockStatus(r);
                    const exp = getExpiryStatus(r.expiresOn);
                    return (
                      <tr key={r.variantId} data-testid={`inv-row-${r.sku}`}>
                        <Td>
                          <div className="font-semibold text-slate-900">{r.name}</div>
                          <div className="mt-0.5 flex flex-wrap items-center gap-1.5 text-xs text-slate-500">
                            {r.categoryName ? <Badge tone="neutral">{r.categoryName}</Badge> : null}
                            {r.breaksIntoQty ? (
                              <Badge tone="neutral">1 = {r.breaksIntoQty} pcs</Badge>
                            ) : null}
                            {!r.active ? <Badge tone="warn">{t("admin:products.inactive")}</Badge> : null}
                            {exp === "expired" ? (
                              <Badge tone="danger">
                                {t("admin:products.expired")} · {r.expiresOn}
                              </Badge>
                            ) : exp === "expiring_soon" ? (
                              <Badge tone="warn">
                                {t("admin:products.expiringSoon")} · {r.expiresOn}
                              </Badge>
                            ) : null}
                          </div>
                        </Td>
                        <Td>
                          <div className="font-mono text-xs font-semibold text-slate-800">{r.sku}</div>
                          {r.barcode ? (
                            <div className="font-mono text-xs text-slate-500">{r.barcode}</div>
                          ) : null}
                        </Td>
                        <Td>
                          {!r.tracked ? (
                            <Badge tone="neutral">{t("admin:inventory.statusUntracked")}</Badge>
                          ) : st === "out" ? (
                            <Badge tone="danger">{t("admin:inventory.statusOut")}</Badge>
                          ) : st === "low" ? (
                            <Badge tone="warn">{t("admin:inventory.statusLow")}</Badge>
                          ) : (
                            <Badge tone="good">{t("admin:inventory.statusInStock")}</Badge>
                          )}
                        </Td>
                        <Td numeric className="text-slate-600">
                          {r.tracked && r.reorderPoint > 0 ? `${formatQty(r.reorderPoint)} ${r.unit}` : "—"}
                        </Td>
                        <Td
                          numeric
                          className={
                            !r.tracked
                              ? "text-slate-500"
                              : st === "out"
                                ? "font-semibold text-red-700"
                                : st === "low"
                                  ? "font-semibold text-amber-800"
                                  : "font-semibold text-slate-900"
                          }
                        >
                          {r.tracked ? `${formatQty(r.qty)} ${r.unit}` : "—"}
                        </Td>
                        <Td numeric>
                          {r.price != null ? fmtMoney(r.price) : "—"}
                        </Td>
                        {showActionsCol ? (
                          <Td numeric>
                            {canAdjustStoreStock && r.tracked ? (
                              <Button
                                variant="outline"
                                size="sm"
                                data-testid={`inv-adjust-${r.sku}`}
                                onClick={() => setAdjustingRow(r)}
                              >
                                <SlidersHorizontal size={14} aria-hidden />
                                <span>{t("admin:inventory.adjustBtn")}</span>
                              </Button>
                            ) : canOpenBins && r.tracked ? (
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => void navigate({ to: "/app/bins" })}
                              >
                                <Boxes size={14} aria-hidden />
                                <span>{t("admin:inventory.binsBtn")}</span>
                              </Button>
                            ) : null}
                          </Td>
                        ) : null}
                      </tr>
                    );
                  })}
                </tbody>
              </Table>
            )}
          </div>
        </TabPanel>

        <TabPanel value="movements">
          <div className="grid gap-4">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="flex flex-wrap items-center gap-2">
                {(
                  [
                    { id: "all", label: t("admin:inventory.movFilterAll") },
                    { id: "sales", label: t("admin:inventory.movFilterSales") },
                    { id: "transfers", label: t("admin:inventory.movFilterTransfers") },
                    { id: "restock", label: t("admin:inventory.movFilterRestock") },
                    { id: "adjustments", label: t("admin:inventory.movFilterAdjustments") },
                  ] as const
                ).map((f) => (
                  <Button
                    key={f.id}
                    variant="outline"
                    size="sm"
                    className={movFilter === f.id ? "border-brand-600 bg-brand-50 text-brand-text" : ""}
                    onClick={() => setMovFilter(f.id)}
                  >
                    {f.label}
                  </Button>
                ))}
              </div>
              <div className="w-full sm:w-64">
                <Input
                  placeholder={t("admin:inventory.searchPlaceholder")}
                  value={movSearch}
                  onChange={(e) => setMovSearch(e.target.value)}
                />
              </div>
            </div>

            {movementsQuery.isPending ? (
              <Card className="p-0">
                <TableSkeleton rows={6} cols={5} />
              </Card>
            ) : movementsQuery.isError ? (
              <ErrorState
                message={msg(movementsQuery.error)}
                retryLabel={t("common:actions.retry")}
                onRetry={() => void movementsQuery.refetch()}
              />
            ) : filteredMovements.length === 0 ? (
              <EmptyState
                title={t("admin:inventory.movEmptyTitle")}
                hint={t("admin:inventory.movEmptyHint")}
              />
            ) : (
              <Table data-testid="inventory-movements-table">
                <thead>
                  <tr>
                    <Th>{t("admin:inventory.movColDate")}</Th>
                    <Th>{t("admin:inventory.movColProduct")}</Th>
                    <Th>{t("admin:inventory.movColSku")}</Th>
                    <Th>{t("admin:inventory.movColType")}</Th>
                    <Th numeric>{t("admin:inventory.movColDelta")}</Th>
                  </tr>
                </thead>
                <tbody>
                  {filteredMovements.map((m) => {
                    const typeLabel = KNOWN_MOVEMENT_TYPES.has(m.type)
                      ? t(`admin:inventory.movType.${m.type as StockMovementType}`)
                      : m.type;
                    const sign = m.qtyDelta > 0 ? "+" : "";
                    return (
                      <tr key={m.id}>
                        <Td className="text-xs text-slate-600 tabular-nums">
                          {new Date(m.occurredAt).toLocaleString(i18n.language)}
                        </Td>
                        <Td className="font-semibold text-slate-900">{m.productName}</Td>
                        <Td className="font-mono text-xs text-slate-600">{m.sku}</Td>
                        <Td>
                          <Badge tone={movementTone(m.type, m.qtyDelta)}>{typeLabel}</Badge>
                        </Td>
                        <Td
                          numeric
                          className={
                            m.qtyDelta > 0
                              ? "font-semibold text-emerald-700"
                              : m.qtyDelta < 0
                                ? "font-semibold text-slate-800"
                                : "text-slate-500"
                          }
                        >
                          {sign}
                          {formatQty(m.qtyDelta)} {m.unit}
                        </Td>
                      </tr>
                    );
                  })}
                </tbody>
              </Table>
            )}
          </div>
        </TabPanel>
      </Tabs>

      {adjustingRow ? (
        <StoreStockActionDialog
          row={adjustingRow}
          allRows={allRows}
          currency={currency}
          locationId={activeLoc.id}
          locationLabel={`${activeLoc.code} · ${activeLoc.name}`}
          canSeeCost={canSeeCost}
          onClose={() => setAdjustingRow(null)}
        />
      ) : null}
    </div>
  );
}
