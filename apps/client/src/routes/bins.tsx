import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useTranslation } from "react-i18next";
import { Alert, Badge, Button, Card, Dialog, Field, Input, Select, Table } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { supabase } from "../lib/supabase.ts";
import {
  checkBinStockInvariant,
  enableWarehouseBins,
  listBinStock,
  listWarehouseBins,
  moveBinStock,
  upsertWarehouseBin,
  upsertWarehouseZone,
  type BinStockItem,
  type BinType,
  type WarehouseBin,
  type ZoneType,
} from "../lib/bins-api.ts";

export function BinsPage() {
  const { t } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const { access, can } = useSession();
  const qc = useQueryClient();

  const warehouses = access.locations.filter(
    (l) => l.type === "warehouse" && (can("stock.adjust_store", l.id) || can("transfer.manage", l.id) || can("locations.manage", l.id)),
  );

  const [selectedWarehouseId, setSelectedWarehouseId] = useState<string>(
    warehouses[0]?.id ?? "",
  );
  const [selectedZoneFilter, setSelectedZoneFilter] = useState<string>("");

  // Modals state
  const [showAddZone, setShowAddZone] = useState(false);
  const [showAddBin, setShowAddBin] = useState(false);
  const [showMoveStock, setShowMoveStock] = useState(false);
  const [activeBinDetail, setActiveBinDetail] = useState<WarehouseBin | null>(null);

  // Form states: Zone
  const [zoneCode, setZoneCode] = useState("");
  const [zoneName, setZoneName] = useState("");
  const [zoneType, setZoneType] = useState<ZoneType>("storage");

  // Form states: Bin
  const [binCode, setBinCode] = useState("");
  const [binZoneId, setBinZoneId] = useState("");
  const [binAisle, setBinAisle] = useState("");
  const [binRack, setBinRack] = useState("");
  const [binShelf, setBinShelf] = useState("");
  const [binPos, setBinPos] = useState("");
  const [binType, setBinType] = useState<BinType>("shelf");
  const [binMaxQty, setBinMaxQty] = useState("");

  // Form states: Move stock
  const [moveFromBin, setMoveFromBin] = useState("");
  const [moveToBin, setMoveToBin] = useState("");
  const [moveVariantId, setMoveVariantId] = useState("");
  const [moveQty, setMoveQty] = useState("");
  const [moveReason, setMoveReason] = useState("");

  const [actionError, setActionError] = useState<string | null>(null);

  // Queries
  const warehouseDetails = useQuery({
    queryKey: ["warehouse-location", selectedWarehouseId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("locations")
        .select("id, code, name, type, bins_enabled")
        .eq("id", selectedWarehouseId)
        .single();
      if (error) throw error;
      return data;
    },
    enabled: Boolean(selectedWarehouseId),
  });

  const isBinsEnabled = Boolean(warehouseDetails.data?.bins_enabled);

  const binsQuery = useQuery({
    queryKey: ["warehouse-bins", selectedWarehouseId, selectedZoneFilter],
    queryFn: () => listWarehouseBins(selectedWarehouseId, selectedZoneFilter || undefined),
    enabled: Boolean(selectedWarehouseId) && isBinsEnabled,
  });

  const zonesQuery = useQuery({
    queryKey: ["warehouse-zones", selectedWarehouseId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("warehouse_zones")
        .select("id, code, name, type")
        .eq("warehouse_id", selectedWarehouseId)
        .is("deleted_at", null)
        .order("code");
      if (error) throw error;
      return (data ?? []) as Array<{ id: string; code: string; name: string; type: ZoneType }>;
    },
    enabled: Boolean(selectedWarehouseId) && isBinsEnabled,
  });

  const invariantQuery = useQuery({
    queryKey: ["bin-invariant", selectedWarehouseId],
    queryFn: () => checkBinStockInvariant(selectedWarehouseId),
    enabled: Boolean(selectedWarehouseId) && isBinsEnabled,
    refetchInterval: 60_000,
  });

  const binStockQuery = useQuery({
    queryKey: ["bin-stock", activeBinDetail?.id],
    queryFn: () => listBinStock(activeBinDetail!.id),
    enabled: Boolean(activeBinDetail?.id),
  });

  const sourceBinStock = useQuery({
    queryKey: ["source-bin-stock", moveFromBin],
    queryFn: () => listBinStock(moveFromBin),
    enabled: Boolean(moveFromBin),
  });

  // Mutations
  const enableMutation = useMutation({
    mutationFn: () => enableWarehouseBins(selectedWarehouseId),
    onSuccess: async () => {
      await Promise.all([
        qc.invalidateQueries({ queryKey: ["warehouse-location", selectedWarehouseId] }),
        qc.invalidateQueries({ queryKey: ["warehouse-bins", selectedWarehouseId] }),
        qc.invalidateQueries({ queryKey: ["warehouse-zones", selectedWarehouseId] }),
        qc.invalidateQueries({ queryKey: ["bin-invariant", selectedWarehouseId] }),
        qc.invalidateQueries({ queryKey: ["locations"] }),
      ]);
    },
    onError: (e) => setActionError(msg(e)),
  });

  const addZoneMutation = useMutation({
    mutationFn: () => upsertWarehouseZone(selectedWarehouseId, zoneCode.trim(), zoneName.trim(), zoneType),
    onSuccess: async () => {
      setShowAddZone(false);
      setZoneCode("");
      setZoneName("");
      setActionError(null);
      await qc.invalidateQueries({ queryKey: ["warehouse-zones", selectedWarehouseId] });
    },
    onError: (e) => setActionError(msg(e)),
  });

  const addBinMutation = useMutation({
    mutationFn: () =>
      upsertWarehouseBin(
        selectedWarehouseId,
        binCode.trim(),
        binZoneId || undefined,
        binAisle.trim() || undefined,
        binRack.trim() || undefined,
        binShelf.trim() || undefined,
        binPos.trim() || undefined,
        binType,
        binMaxQty.trim() ? Number(binMaxQty) : undefined,
      ),
    onSuccess: async () => {
      setShowAddBin(false);
      setBinCode("");
      setBinAisle("");
      setBinRack("");
      setBinShelf("");
      setBinPos("");
      setBinMaxQty("");
      setActionError(null);
      await qc.invalidateQueries({ queryKey: ["warehouse-bins", selectedWarehouseId] });
    },
    onError: (e) => setActionError(msg(e)),
  });

  const moveStockMutation = useMutation({
    mutationFn: () =>
      moveBinStock(
        selectedWarehouseId,
        moveFromBin,
        moveToBin,
        moveVariantId,
        Number(moveQty),
        moveReason.trim() || undefined,
      ),
    onSuccess: async () => {
      setShowMoveStock(false);
      setMoveVariantId("");
      setMoveQty("");
      setMoveReason("");
      setActionError(null);
      await Promise.all([
        qc.invalidateQueries({ queryKey: ["warehouse-bins", selectedWarehouseId] }),
        qc.invalidateQueries({ queryKey: ["bin-invariant", selectedWarehouseId] }),
        qc.invalidateQueries({ queryKey: ["bin-stock"] }),
      ]);
    },
    onError: (e) => setActionError(msg(e)),
  });

  if (warehouses.length === 0) {
    return (
      <Card>
        <p className="text-sm text-slate-600">{t("bins.noWarehouses", "No warehouses accessible.")}</p>
      </Card>
    );
  }

  const allBins = binsQuery.data ?? [];
  const allZones = zonesQuery.data ?? [];
  const invariantRows = invariantQuery.data ?? [];
  const isInvariantBalanced = invariantRows.every((r) => r.is_valid);

  const totalOccupied = allBins.filter((b) => b.total_qty > 0).length;
  const totalUnits = allBins.reduce((sum, b) => sum + Number(b.total_qty), 0);

  return (
    <div className="grid gap-4">
      {/* Header and Warehouse Selector */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold">{t("bins.title", "Warehouse Bins & Storage")}</h1>
          <p className="text-xs text-slate-500">
            {t("bins.subtitle", "Zones, aisle/rack/shelf positions, put-away, and pick locations.")}
          </p>
        </div>

        {warehouses.length > 1 ? (
          <div className="flex items-center gap-2">
            <span className="text-sm text-slate-500">{t("bins.warehouse", "Warehouse")}:</span>
            <Select
              value={selectedWarehouseId}
              onChange={(e) => setSelectedWarehouseId(e.target.value)}
              className="w-56"
            >
              {warehouses.map((w) => (
                <option key={w.id} value={w.id}>
                  {w.code} · {w.name}
                </option>
              ))}
            </Select>
          </div>
        ) : null}
      </div>

      {actionError ? <Alert>{actionError}</Alert> : null}

      {/* When Bins Not Enabled on this Warehouse */}
      {!isBinsEnabled ? (
        <Card className="grid gap-3 p-6 text-center">
          <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-slate-100 text-2xl">
            📦
          </div>
          <h2 className="text-lg font-semibold">{t("bins.enableTitle", "Enable Warehouse Bins")}</h2>
          <p className="mx-auto max-w-md text-sm text-slate-500">
            {t(
              "bins.enableDesc",
              "Track stock per bin, shelf, and rack. Bins support automated put-away from receiving, pick lists with walking-route ordering, and strict stock invariant verification.",
            )}
          </p>
          <div className="pt-2">
            <Button
              onClick={() => enableMutation.mutate()}
              disabled={enableMutation.isPending}
            >
              {enableMutation.isPending
                ? t("bins.enabling", "Enabling Bins...")
                : t("bins.enableAction", "Enable Bins & Default Zones")}
            </Button>
          </div>
        </Card>
      ) : (
        <>
          {/* Invariant & Metrics Bar */}
          <div className="grid gap-3 sm:grid-cols-4">
            <Card className="p-4">
              <div className="text-xs text-slate-500 uppercase">{t("bins.totalBins", "Total Bins")}</div>
              <div className="mt-1 text-2xl font-bold">{allBins.length}</div>
            </Card>
            <Card className="p-4">
              <div className="text-xs text-slate-500 uppercase">{t("bins.occupiedBins", "Occupied Bins")}</div>
              <div className="mt-1 text-2xl font-bold text-slate-900">{totalOccupied}</div>
            </Card>
            <Card className="p-4">
              <div className="text-xs text-slate-500 uppercase">{t("bins.totalUnits", "Total Units")}</div>
              <div className="mt-1 text-2xl font-bold text-slate-900">{totalUnits.toLocaleString()}</div>
            </Card>
            <Card className="p-4">
              <div className="text-xs text-slate-500 uppercase">{t("bins.ledgerStatus", "Ledger Invariant")}</div>
              <div className="mt-1">
                {isInvariantBalanced ? (
                  <Badge tone="good">✓ {t("bins.balanced", "100% Balanced")}</Badge>
                ) : (
                  <Badge tone="warn">⚠️ {t("bins.discrepancy", "Discrepancy Detected")}</Badge>
                )}
              </div>
            </Card>
          </div>

          {/* Action Toolbar */}
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <span className="text-xs text-slate-500 uppercase">{t("bins.filterZone", "Zone")}:</span>
              <Select
                value={selectedZoneFilter}
                onChange={(e) => setSelectedZoneFilter(e.target.value)}
                className="w-44 text-sm"
              >
                <option value="">{t("bins.allZones", "All Zones")}</option>
                {allZones.map((z) => (
                  <option key={z.id} value={z.id}>
                    {z.code} ({z.name})
                  </option>
                ))}
              </Select>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <Button variant="outline" size="sm" onClick={() => setShowAddZone(true)}>
                + {t("bins.addZone", "Add Zone")}
              </Button>
              <Button variant="outline" size="sm" onClick={() => setShowAddBin(true)}>
                + {t("bins.addBin", "Add Bin")}
              </Button>
              <Button size="sm" onClick={() => setShowMoveStock(true)}>
                ⇄ {t("bins.moveStock", "Put-away / Move Stock")}
              </Button>
            </div>
          </div>

          {/* Bins Table */}
          <Card className="overflow-x-auto p-0">
            <Table bare>
              <thead className="border-b border-slate-200 text-xs text-slate-500 uppercase">
                <tr>
                  <th className="p-3">{t("bins.colCode", "Bin Code")}</th>
                  <th className="p-3">{t("bins.colZone", "Zone")}</th>
                  <th className="p-3">{t("bins.colPosition", "Position")}</th>
                  <th className="p-3">{t("bins.colType", "Type")}</th>
                  <th className="p-3 text-right">{t("bins.colItems", "Variants")}</th>
                  <th className="p-3 text-right">{t("bins.colTotalQty", "Units")}</th>
                  <th className="p-3 text-right">{t("bins.colMaxQty", "Capacity")}</th>
                  <th className="p-3 text-center">{t("common:actions.actions", "Actions")}</th>
                </tr>
              </thead>
              <tbody>
                {allBins.map((bin) => {
                  const posParts = [bin.aisle ? `Aisle ${bin.aisle}` : null, bin.rack ? `Rack ${bin.rack}` : null, bin.shelf ? `Shelf ${bin.shelf}` : null, bin.position ? `Pos ${bin.position}` : null]
                    .filter(Boolean)
                    .join(" · ");

                  return (
                    <tr key={bin.id} className="border-b border-slate-100 last:border-0 hover:bg-slate-50">
                      <td className="p-3 font-mono font-semibold text-slate-900">
                        {bin.code}
                      </td>
                      <td className="p-3">
                        <Badge tone={bin.zone_type === "receiving" ? "warn" : bin.zone_type === "staging" ? "good" : "neutral"}>
                          {bin.zone_code ?? "—"}
                        </Badge>
                      </td>
                      <td className="p-3 text-xs text-slate-600">
                        {posParts || "—"}
                      </td>
                      <td className="p-3 text-xs capitalize text-slate-600">{bin.type}</td>
                      <td className="p-3 text-right font-medium">{bin.item_count}</td>
                      <td className="p-3 text-right font-semibold text-slate-900">{bin.total_qty}</td>
                      <td className="p-3 text-right text-xs text-slate-500">
                        {bin.max_qty ? `${bin.max_qty} max` : "—"}
                      </td>
                      <td className="p-3 text-center">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => setActiveBinDetail(bin)}
                        >
                          {t("bins.viewContents", "View Items")}
                        </Button>
                      </td>
                    </tr>
                  );
                })}
                {allBins.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="p-6 text-center text-sm text-slate-500">
                      {t("bins.empty", "No bins found in this zone.")}
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </Table>
          </Card>
        </>
      )}

      {/* Modal: View Bin Items */}
      <Dialog
        open={Boolean(activeBinDetail)}
        onOpenChange={(open) => !open && setActiveBinDetail(null)}
        title={`${t("bins.binStockTitle", "Bin Contents")}: ${activeBinDetail?.code ?? ""}`}
        closeLabel={t("common:actions.close", "Close")}
      >
        <div className="grid gap-3">
          <div className="flex items-center justify-between text-xs text-slate-500">
            <span>{activeBinDetail?.zone_code ? `Zone: ${activeBinDetail.zone_code}` : ""}</span>
            <span className="font-semibold text-slate-900">{activeBinDetail?.total_qty} total units</span>
          </div>

          {binStockQuery.isPending ? (
            <p className="text-sm text-slate-500">{t("common:status.loading", "Loading items...")}</p>
          ) : (binStockQuery.data ?? []).length === 0 ? (
            <p className="p-4 text-center text-sm text-slate-500">{t("bins.binEmpty", "This bin is currently empty.")}</p>
          ) : (
            <div className="max-h-80 overflow-y-auto rounded-md border border-slate-200">
              <Table bare>
                <thead className="bg-slate-50 text-xs text-slate-500 uppercase">
                  <tr>
                    <th className="p-2.5">SKU</th>
                    <th className="p-2.5">{t("bins.product", "Product")}</th>
                    <th className="p-2.5 text-right">{t("bins.qty", "Qty")}</th>
                  </tr>
                </thead>
                <tbody>
                  {(binStockQuery.data ?? []).map((item: BinStockItem) => (
                    <tr key={item.variant_id} className="border-t border-slate-100">
                      <td className="p-2.5 font-mono text-xs">{item.sku}</td>
                      <td className="p-2.5 text-xs font-medium">{item.product_name}</td>
                      <td className="p-2.5 text-right font-semibold">{item.qty_on_hand}</td>
                    </tr>
                  ))}
                </tbody>
              </Table>
            </div>
          )}
        </div>
      </Dialog>

      {/* Modal: Add Zone */}
      <Dialog
        open={showAddZone}
        onOpenChange={setShowAddZone}
        title={t("bins.newZoneTitle", "Create Warehouse Zone")}
        closeLabel={t("common:actions.cancel", "Cancel")}
      >
        <form
          onSubmit={(e) => {
            e.preventDefault();
            addZoneMutation.mutate();
          }}
          className="grid gap-3"
        >
          <Field label={t("bins.zoneCode", "Zone Code")} hint="e.g. COLD, AISLE-1, BULK">
            <Input
              value={zoneCode}
              onChange={(e) => setZoneCode(e.target.value.toUpperCase())}
              placeholder="e.g. COLD"
              required
              maxLength={20}
            />
          </Field>
          <Field label={t("bins.zoneName", "Zone Name")}>
            <Input
              value={zoneName}
              onChange={(e) => setZoneName(e.target.value)}
              placeholder="e.g. Cold Storage"
              required
              maxLength={120}
            />
          </Field>
          <Field label={t("bins.zoneType", "Zone Type")}>
            <Select value={zoneType} onChange={(e) => setZoneType(e.target.value as ZoneType)}>
              <option value="storage">{t("bins.zoneTypes.storage", "Storage")}</option>
              <option value="picking">{t("bins.zoneTypes.picking", "Picking")}</option>
              <option value="receiving">{t("bins.zoneTypes.receiving", "Receiving")}</option>
              <option value="staging">{t("bins.zoneTypes.staging", "Staging")}</option>
              <option value="quarantine">{t("bins.zoneTypes.quarantine", "Quarantine")}</option>
              <option value="damaged">{t("bins.zoneTypes.damaged", "Damaged")}</option>
            </Select>
          </Field>
          <div className="flex justify-end gap-2 pt-2">
            <Button type="button" variant="outline" onClick={() => setShowAddZone(false)}>
              {t("common:actions.cancel", "Cancel")}
            </Button>
            <Button type="submit" disabled={!zoneCode || !zoneName || addZoneMutation.isPending}>
              {addZoneMutation.isPending ? t("common:status.saving", "Saving...") : t("common:actions.save", "Save Zone")}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* Modal: Add Bin */}
      <Dialog
        open={showAddBin}
        onOpenChange={setShowAddBin}
        title={t("bins.newBinTitle", "Create Warehouse Bin")}
        closeLabel={t("common:actions.cancel", "Cancel")}
      >
        <form
          onSubmit={(e) => {
            e.preventDefault();
            addBinMutation.mutate();
          }}
          className="grid gap-3"
        >
          <Field label={t("bins.binCode", "Bin Code / Barcode Label")} hint="Unique identifier within this warehouse">
            <Input
              value={binCode}
              onChange={(e) => setBinCode(e.target.value.toUpperCase())}
              placeholder="e.g. A-02-1"
              required
              maxLength={30}
            />
          </Field>
          <Field label={t("bins.zone", "Zone")}>
            <Select value={binZoneId} onChange={(e) => setBinZoneId(e.target.value)}>
              <option value="">{t("bins.noZone", "— No Zone —")}</option>
              {allZones.map((z) => (
                <option key={z.id} value={z.id}>
                  {z.code} · {z.name}
                </option>
              ))}
            </Select>
          </Field>
          <div className="grid grid-cols-2 gap-2">
            <Field label={t("bins.aisle", "Aisle")}>
              <Input value={binAisle} onChange={(e) => setBinAisle(e.target.value)} placeholder="A" maxLength={20} />
            </Field>
            <Field label={t("bins.rack", "Rack")}>
              <Input value={binRack} onChange={(e) => setBinRack(e.target.value)} placeholder="01" maxLength={20} />
            </Field>
          </div>
          <div className="grid grid-cols-2 gap-2">
            <Field label={t("bins.shelf", "Shelf")}>
              <Input value={binShelf} onChange={(e) => setBinShelf(e.target.value)} placeholder="1" maxLength={20} />
            </Field>
            <Field label={t("bins.position", "Position")}>
              <Input value={binPos} onChange={(e) => setBinPos(e.target.value)} placeholder="1" maxLength={20} />
            </Field>
          </div>
          <div className="grid grid-cols-2 gap-2">
            <Field label={t("bins.type", "Type")}>
              <Select value={binType} onChange={(e) => setBinType(e.target.value as BinType)}>
                <option value="shelf">{t("bins.types.shelf", "Shelf")}</option>
                <option value="pallet">{t("bins.types.pallet", "Pallet")}</option>
                <option value="floor">{t("bins.types.floor", "Floor")}</option>
                <option value="bin">{t("bins.types.bin", "Bin")}</option>
              </Select>
            </Field>
            <Field label={t("bins.maxQty", "Max Capacity (units)")}>
              <Input
                type="number"
                min="1"
                value={binMaxQty}
                onChange={(e) => setBinMaxQty(e.target.value)}
                placeholder="Unlimited"
              />
            </Field>
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <Button type="button" variant="outline" onClick={() => setShowAddBin(false)}>
              {t("common:actions.cancel", "Cancel")}
            </Button>
            <Button type="submit" disabled={!binCode || addBinMutation.isPending}>
              {addBinMutation.isPending ? t("common:status.saving", "Saving...") : t("common:actions.save", "Save Bin")}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* Modal: Move / Put-away Stock */}
      <Dialog
        open={showMoveStock}
        onOpenChange={setShowMoveStock}
        title={t("bins.moveStockTitle", "Put-away / Move Stock Between Bins")}
        closeLabel={t("common:actions.cancel", "Cancel")}
      >
        <form
          onSubmit={(e) => {
            e.preventDefault();
            moveStockMutation.mutate();
          }}
          className="grid gap-3"
        >
          <Field label={t("bins.fromBin", "From Bin (Source)")}>
            <Select
              value={moveFromBin}
              onChange={(e) => {
                setMoveFromBin(e.target.value);
                setMoveVariantId("");
              }}
              required
            >
              <option value="">{t("bins.selectSourceBin", "— Select Source Bin —")}</option>
              {allBins
                .filter((b) => b.total_qty > 0)
                .map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.code} ({b.total_qty} units)
                  </option>
                ))}
            </Select>
          </Field>

          {moveFromBin ? (
            <Field label={t("bins.itemToMove", "Product Item")}>
              <Select value={moveVariantId} onChange={(e) => setMoveVariantId(e.target.value)} required>
                <option value="">{t("bins.selectProduct", "— Select Item —")}</option>
                {(sourceBinStock.data ?? []).map((s) => (
                  <option key={s.variant_id} value={s.variant_id}>
                    {s.product_name} ({s.sku}) · {s.qty_on_hand} available
                  </option>
                ))}
              </Select>
            </Field>
          ) : null}

          <Field label={t("bins.toBin", "To Bin (Destination)")}>
            <Select value={moveToBin} onChange={(e) => setMoveToBin(e.target.value)} required>
              <option value="">{t("bins.selectDestBin", "— Select Destination Bin —")}</option>
              {allBins
                .filter((b) => b.id !== moveFromBin)
                .map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.code} {b.zone_code ? `[${b.zone_code}]` : ""} ({b.total_qty} units)
                  </option>
                ))}
            </Select>
          </Field>

          <Field label={t("bins.qty", "Quantity to Move")}>
            <Input
              type="number"
              step="any"
              min="0.001"
              value={moveQty}
              onChange={(e) => setMoveQty(e.target.value)}
              placeholder="e.g. 10"
              required
            />
          </Field>

          <Field label={t("bins.reason", "Reason / Task")} hint="e.g. Putaway from receiving, replenishment">
            <Input
              value={moveReason}
              onChange={(e) => setMoveReason(e.target.value)}
              placeholder="putaway"
            />
          </Field>

          <div className="flex justify-end gap-2 pt-2">
            <Button type="button" variant="outline" onClick={() => setShowMoveStock(false)}>
              {t("common:actions.cancel", "Cancel")}
            </Button>
            <Button
              type="submit"
              disabled={
                !moveFromBin ||
                !moveToBin ||
                !moveVariantId ||
                !moveQty ||
                moveStockMutation.isPending
              }
            >
              {moveStockMutation.isPending ? t("common:status.moving", "Moving...") : t("bins.confirmMove", "Transfer Stock")}
            </Button>
          </div>
        </form>
      </Dialog>
    </div>
  );
}
