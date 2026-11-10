import { useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Alert, Badge, Button, Card, Dialog, ErrorState, Field, Input, PageHeader, Select, useToast } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { pullCatalog } from "../lib/sell-api.ts";
import { listLocations } from "../lib/api.ts";
import {
  cancelTransfer,
  createTransfer,
  listTransfers,
  receiveTransfer,
  shipTransfer,
  type TransferRow,
  type TransferStatus,
} from "../lib/transfers-api.ts";
import { createTransferSchema, fieldErrors, receiveTransferSchema } from "../lib/schemas.ts";

export function TransfersPage() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const toast = useToast();
  const { access, can } = useSession();
  const qc = useQueryClient();

  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [locationFilter, setLocationFilter] = useState<string>("all");

  const [showCreateModal, setShowCreateModal] = useState(false);
  const [receivingTransfer, setReceivingTransfer] = useState<TransferRow | null>(null);
  const [manifestTransfer, setManifestTransfer] = useState<TransferRow | null>(null);
  const [cancellingTransfer, setCancellingTransfer] = useState<TransferRow | null>(null);
  const [cancelReason, setCancelReason] = useState("");

  // Create form state
  const [fromLocId, setFromLocId] = useState("");
  const [toLocId, setToLocId] = useState("");
  const [notes, setNotes] = useState("");
  const [shipNow, setShipNow] = useState(false);
  const [formItems, setFormItems] = useState<Array<{ variantId: string; qty: number }>>([
    { variantId: "", qty: 1 },
  ]);
  const [createFormErrors, setCreateFormErrors] = useState<Record<string, string>>({});
  const [createError, setCreateError] = useState<string | null>(null);

  // Receive form state
  const [receiveItems, setReceiveItems] = useState<Array<{ variantId: string; qtyReceived: number }>>([]);
  const [receiveError, setReceiveError] = useState<string | null>(null);

  // Queries
  const transfersQuery = useQuery({
    queryKey: ["transfers", statusFilter, locationFilter],
    queryFn: () => listTransfers({ status: statusFilter, locationId: locationFilter }),
    refetchInterval: 30_000,
  });

  const locationsQuery = useQuery({
    queryKey: ["locations"],
    queryFn: listLocations,
    staleTime: 60_000,
  });

  const catalogQuery = useQuery({
    queryKey: ["catalog-pull"],
    queryFn: pullCatalog,
    staleTime: 60_000,
  });

  // Prepare product options
  const productOptions = useMemo(() => {
    if (!catalogQuery.data) return [];
    const products = new Map(
      catalogQuery.data.products.rows.filter((p) => p.active && !p.deleted_at).map((p) => [p.id, p]),
    );
    const options: Array<{ variantId: string; name: string; sku: string }> = [];
    for (const v of catalogQuery.data.product_variants.rows) {
      if (!v.active || v.deleted_at) continue;
      const p = products.get(v.product_id);
      if (!p) continue;
      options.push({
        variantId: v.id,
        name: p.name,
        sku: v.sku,
      });
    }
    return options.sort((a, b) => a.name.localeCompare(b.name));
  }, [catalogQuery.data]);

  const activeLocations = useMemo(() => {
    return (locationsQuery.data ?? []).filter((l) => l.active);
  }, [locationsQuery.data]);

  // Mutations
  const createMutation = useMutation({
    mutationFn: createTransfer,
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["transfers"] });
      setShowCreateModal(false);
      resetCreateForm();
      toast.good(t("admin:transfers.createdSuccess", { defaultValue: "Transfer created" }));
    },
    onError: (e) => {
      const err = msg(e);
      setCreateError(err);
      toast.error(err);
    },
  });

  const shipMutation = useMutation({
    mutationFn: shipTransfer,
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["transfers"] });
      toast.good(t("admin:transfers.shippedSuccess", { defaultValue: "Transfer shipped" }));
    },
    onError: (e) => toast.error(msg(e)),
  });

  const receiveMutation = useMutation({
    mutationFn: (vars: { transferId: string; items: Array<{ variantId: string; qtyReceived: number }> }) =>
      receiveTransfer(vars.transferId, vars.items),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["transfers"] });
      setReceivingTransfer(null);
      toast.good(t("admin:transfers.receivedSuccess", { defaultValue: "Transfer received" }));
    },
    onError: (e) => {
      const err = msg(e);
      setReceiveError(err);
      toast.error(err);
    },
  });

  const cancelMutation = useMutation({
    mutationFn: (vars: { transferId: string; reason?: string }) => cancelTransfer(vars.transferId, vars.reason),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["transfers"] });
      setCancellingTransfer(null);
      setCancelReason("");
      toast.good(t("admin:transfers.cancelledSuccess", { defaultValue: "Transfer cancelled" }));
    },
    onError: (e) => toast.error(msg(e)),
  });

  function resetCreateForm() {
    setFromLocId("");
    setToLocId("");
    setNotes("");
    setShipNow(false);
    setFormItems([{ variantId: "", qty: 1 }]);
    setCreateFormErrors({});
    setCreateError(null);
  }

  function handleAddItem() {
    setFormItems((prev) => [...prev, { variantId: "", qty: 1 }]);
  }

  function handleRemoveItem(index: number) {
    setFormItems((prev) => prev.filter((_, i) => i !== index));
  }

  function handleItemChange(index: number, field: "variantId" | "qty", val: string | number) {
    setFormItems((prev) =>
      prev.map((item, i) => (i === index ? { ...item, [field]: val } : item)),
    );
  }

  function handleCreateSubmit(e: React.FormEvent) {
    e.preventDefault();
    setCreateError(null);
    setCreateFormErrors({});

    const parsed = createTransferSchema.safeParse({
      fromLocationId: fromLocId,
      toLocationId: toLocId,
      notes: notes || undefined,
      items: formItems.filter((i) => Boolean(i.variantId)),
      shipNow,
    });

    if (!parsed.success) {
      setCreateFormErrors(fieldErrors(parsed.error));
      return;
    }

    createMutation.mutate({
      fromLocationId: parsed.data.fromLocationId,
      toLocationId: parsed.data.toLocationId,
      notes: parsed.data.notes,
      items: parsed.data.items,
      shipNow: parsed.data.shipNow,
    });
  }

  function openReceiveModal(trf: TransferRow) {
    setReceivingTransfer(trf);
    setReceiveError(null);
    setReceiveItems(
      (trf.transfer_items ?? []).map((ti) => ({
        variantId: ti.variant_id,
        qtyReceived: Number(ti.qty_shipped),
      })),
    );
  }

  function handleReceiveSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!receivingTransfer) return;
    setReceiveError(null);

    const parsed = receiveTransferSchema.safeParse({
      items: receiveItems,
    });

    if (!parsed.success) {
      setReceiveError(t("admin:transfers.invalidReceive"));
      return;
    }

    receiveMutation.mutate({
      transferId: receivingTransfer.id,
      items: parsed.data.items,
    });
  }

  const hasReceiveDiscrepancy = useMemo(() => {
    if (!receivingTransfer || !receivingTransfer.transfer_items) return false;
    return receiveItems.some((ri) => {
      const orig = receivingTransfer.transfer_items?.find((ti) => ti.variant_id === ri.variantId);
      return orig && Number(orig.qty_shipped) !== Number(ri.qtyReceived);
    });
  }, [receivingTransfer, receiveItems]);

  const canCreate = can("stock.adjust_store") || can("transfer.manage");

  function statusBadge(status: TransferStatus, hasDiscrepancy: boolean) {
    switch (status) {
      case "draft":
        return <Badge tone="neutral">{t("admin:transfers.statusDraft")}</Badge>;
      case "shipped":
        return <Badge tone="warn">{t("admin:transfers.statusShipped")}</Badge>;
      case "received":
        return (
          <div className="inline-flex items-center gap-1">
            <Badge tone="good">{t("admin:transfers.statusReceived")}</Badge>
            {hasDiscrepancy && (
              <Badge tone="warn">{t("admin:transfers.discrepancy")}</Badge>
            )}
          </div>
        );
      case "cancelled":
        return <Badge tone="neutral">{t("admin:transfers.statusCancelled")}</Badge>;
    }
  }

  return (
    <div className="grid gap-6">
      {/* Header */}
      <PageHeader
        title={t("admin:transfers.title")}
        subtitle={t("admin:transfers.subtitle")}
        actions={
          canCreate ? (
            <Button onClick={() => setShowCreateModal(true)}>
              {t("admin:transfers.newTransfer")}
            </Button>
          ) : undefined
        }
      />

      {/* Filters */}
      <Card className="flex flex-wrap items-center gap-4">
        <div className="flex items-center gap-2">
          <span className="text-xs font-medium text-slate-500">
            {t("admin:transfers.filterStatus")}:
          </span>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="rounded border border-slate-300 bg-white px-2 py-1 text-xs text-slate-700"
          >
            <option value="all">{t("admin:transfers.allStatuses")}</option>
            <option value="draft">{t("admin:transfers.statusDraft")}</option>
            <option value="shipped">{t("admin:transfers.statusShipped")}</option>
            <option value="received">{t("admin:transfers.statusReceived")}</option>
            <option value="cancelled">{t("admin:transfers.statusCancelled")}</option>
          </select>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs font-medium text-slate-500">
            {t("admin:transfers.filterLocation")}:
          </span>
          <select
            value={locationFilter}
            onChange={(e) => setLocationFilter(e.target.value)}
            className="rounded border border-slate-300 bg-white px-2 py-1 text-xs text-slate-700"
          >
            <option value="all">{t("admin:transfers.allLocations")}</option>
            {activeLocations.map((loc) => (
              <option key={loc.id} value={loc.id}>
                {loc.type === "warehouse" ? "🏢" : "🏪"} {loc.code} · {loc.name}
              </option>
            ))}
          </select>
        </div>
      </Card>

      {/* Transfers Table */}
      {transfersQuery.isError ? (
        <ErrorState
          message={msg(transfersQuery.error)}
          onRetry={() => void transfersQuery.refetch()}
          retryLabel={t("common:actions.retry")}
        />
      ) : null}
      <Card className="overflow-x-auto p-0">
        <table className="w-full text-left text-sm text-slate-600">
          <thead className="border-b border-slate-200 bg-slate-50 text-xs font-semibold uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">{t("admin:transfers.transferNo")}</th>
              <th className="px-4 py-3">{t("admin:transfers.origin")}</th>
              <th className="px-4 py-3">{t("admin:transfers.destination")}</th>
              <th className="px-4 py-3">{t("admin:transfers.items")}</th>
              <th className="px-4 py-3">{t("admin:transfers.status")}</th>
              <th className="px-4 py-3">{t("admin:transfers.date")}</th>
              <th className="px-4 py-3 text-right">{t("admin:transfers.actions")}</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {transfersQuery.isLoading ? (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-slate-500">
                  {t("admin:transfers.loading")}
                </td>
              </tr>
            ) : (transfersQuery.data ?? []).length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-slate-500">
                  {t("admin:transfers.noTransfers")}
                </td>
              </tr>
            ) : (
              (transfersQuery.data ?? []).map((trf) => {
                const totalQty = (trf.transfer_items ?? []).reduce(
                  (acc, item) => acc + Number(item.qty_shipped),
                  0,
                );
                const itemCount = trf.transfer_items?.length ?? 0;
                const canShip = trf.status === "draft" && (access.role === "superadmin" || access.locations.some((l) => l.id === trf.from_location_id));
                const canReceive = trf.status === "shipped" && (access.role === "superadmin" || access.locations.some((l) => l.id === trf.to_location_id));
                const canCancel = trf.status === "draft" && (access.role === "superadmin" || access.locations.some((l) => l.id === trf.from_location_id));

                return (
                  <tr key={trf.id} className="hover:bg-slate-50/50">
                    <td className="px-4 py-3 font-semibold text-slate-900">
                      {trf.transfer_no}
                    </td>
                    <td className="px-4 py-3">
                      <span className="font-medium text-slate-800">
                        {trf.from_location?.name ?? trf.from_location_id}
                      </span>
                      <span className="ml-1 text-xs text-slate-400">
                        ({trf.from_location?.code})
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <span className="font-medium text-slate-800">
                        {trf.to_location?.name ?? trf.to_location_id}
                      </span>
                      <span className="ml-1 text-xs text-slate-400">
                        ({trf.to_location?.code})
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      {itemCount} {t("admin:transfers.lines")} · {totalQty} {t("admin:transfers.units")}
                    </td>
                    <td className="px-4 py-3">
                      {statusBadge(trf.status, trf.has_discrepancy)}
                    </td>
                    <td className="px-4 py-3 text-xs text-slate-500">
                      {new Date(trf.created_at).toLocaleDateString(i18n.language, {
                        month: "short",
                        day: "numeric",
                        hour: "2-digit",
                        minute: "2-digit",
                      })}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => setManifestTransfer(trf)}
                        >
                          {t("admin:transfers.manifest")}
                        </Button>
                        {canShip && (
                          <Button
                            variant="outline"
                            size="sm"
                            disabled={shipMutation.isPending}
                            onClick={() => shipMutation.mutate(trf.id)}
                          >
                            {t("admin:transfers.ship")}
                          </Button>
                        )}
                        {canReceive && (
                          <Button
                            variant="primary"
                            size="sm"
                            onClick={() => openReceiveModal(trf)}
                          >
                            {t("admin:transfers.receive")}
                          </Button>
                        )}
                        {canCancel && (
                          <Button
                            variant="ghost"
                            size="sm"
                            className="text-red-600 hover:bg-red-50"
                            onClick={() => setCancellingTransfer(trf)}
                          >
                            {t("admin:transfers.cancel")}
                          </Button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </Card>

      {/* Modal: Create Transfer */}
      <Dialog
        open={showCreateModal}
        onOpenChange={setShowCreateModal}
        title={t("admin:transfers.newTransferTitle")}
        closeLabel={t("common:actions.cancel")}
      >
        <form onSubmit={handleCreateSubmit} className="grid gap-4">
          {createError && <Alert tone="error">{createError}</Alert>}

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Field
              label={t("admin:transfers.originLocation")}
              error={createFormErrors["fromLocationId"]}
            >
              <Select
                value={fromLocId}
                onChange={(e) => setFromLocId(e.target.value)}
                required
              >
                <option value="">{t("admin:transfers.selectOrigin")}</option>
                {activeLocations.map((loc) => (
                  <option key={loc.id} value={loc.id}>
                    {loc.type === "warehouse" ? "🏢" : "🏪"} {loc.code} · {loc.name}
                  </option>
                ))}
              </Select>
            </Field>

            <Field
              label={t("admin:transfers.destinationLocation")}
              error={createFormErrors["toLocationId"]}
            >
              <Select
                value={toLocId}
                onChange={(e) => setToLocId(e.target.value)}
                required
              >
                <option value="">{t("admin:transfers.selectDestination")}</option>
                {activeLocations
                  .filter((loc) => loc.id !== fromLocId)
                  .map((loc) => (
                    <option key={loc.id} value={loc.id}>
                      {loc.type === "warehouse" ? "🏢" : "🏪"} {loc.code} · {loc.name}
                    </option>
                  ))}
              </Select>
            </Field>
          </div>

          <Field label={t("admin:transfers.notes")}>
            <Input
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder={t("admin:transfers.notesPlaceholder")}
            />
          </Field>

          {/* Items Section */}
          <div className="grid gap-2 border-t border-slate-100 pt-3">
            <div className="flex items-center justify-between">
              <span className="text-sm font-semibold text-slate-800">
                {t("admin:transfers.itemsTitle")}
              </span>
              <Button variant="ghost" size="sm" onClick={handleAddItem}>
                + {t("admin:transfers.addItem")}
              </Button>
            </div>
            {createFormErrors["items"] && (
              <p className="text-xs text-red-600">{t("admin:transfers.itemsRequired")}</p>
            )}

            <div className="grid gap-2">
              {formItems.map((item, idx) => (
                <div key={idx} className="flex items-center gap-2">
                  <div className="flex-1">
                    <Select
                      value={item.variantId}
                      onChange={(e) => handleItemChange(idx, "variantId", e.target.value)}
                      required
                    >
                      <option value="">{t("admin:transfers.selectProduct")}</option>
                      {productOptions.map((p) => (
                        <option key={p.variantId} value={p.variantId}>
                          {p.name} ({p.sku})
                        </option>
                      ))}
                    </Select>
                  </div>
                  <div className="w-24">
                    <Input
                      type="number"
                      min="0.001"
                      step="any"
                      value={item.qty}
                      onChange={(e) => handleItemChange(idx, "qty", parseFloat(e.target.value) || 0)}
                      required
                    />
                  </div>
                  {formItems.length > 1 && (
                    <Button
                      variant="ghost"
                      size="sm"
                      className="text-red-500 hover:bg-red-50"
                      onClick={() => handleRemoveItem(idx)}
                    >
                      ✕
                    </Button>
                  )}
                </div>
              ))}
            </div>
          </div>

          <label className="flex items-center gap-2 border-t border-slate-100 pt-3 text-sm text-slate-700">
            <input
              type="checkbox"
              checked={shipNow}
              onChange={(e) => setShipNow(e.target.checked)}
              className="h-4 w-4 rounded border-slate-300 text-slate-900 focus:ring-slate-900"
            />
            <span>{t("admin:transfers.shipImmediately")}</span>
          </label>

          <div className="flex justify-end gap-2 border-t border-slate-100 pt-3">
            <Button
              variant="outline"
              onClick={() => {
                setShowCreateModal(false);
                resetCreateForm();
              }}
            >
              {t("common:actions.cancel")}
            </Button>
            <Button type="submit" disabled={createMutation.isPending}>
              {createMutation.isPending
                ? t("admin:transfers.saving")
                : shipNow
                  ? t("admin:transfers.shipNow")
                  : t("admin:transfers.saveDraft")}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* Modal: Receive Transfer */}
      <Dialog
        open={Boolean(receivingTransfer)}
        onOpenChange={(open) => !open && setReceivingTransfer(null)}
        title={`${t("admin:transfers.receiveTitle")}: ${receivingTransfer?.transfer_no ?? ""}`}
        closeLabel={t("common:actions.cancel")}
      >
        <form onSubmit={handleReceiveSubmit} className="grid gap-4">
          {receiveError && <Alert tone="error">{receiveError}</Alert>}

          <div className="rounded-md bg-slate-50 p-3 text-xs text-slate-600">
            <div>
              <span className="font-semibold">{t("admin:transfers.origin")}:</span>{" "}
              {receivingTransfer?.from_location?.name} ({receivingTransfer?.from_location?.code})
            </div>
            <div>
              <span className="font-semibold">{t("admin:transfers.destination")}:</span>{" "}
              {receivingTransfer?.to_location?.name} ({receivingTransfer?.to_location?.code})
            </div>
          </div>

          {hasReceiveDiscrepancy && (
            <Alert tone="info">
              ⚠️ {t("admin:transfers.discrepancyNotice")}
            </Alert>
          )}

          <div className="max-h-72 overflow-y-auto">
            <table className="w-full text-left text-sm text-slate-600">
              <thead className="border-b border-slate-200 bg-slate-50 text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-3 py-2">{t("admin:transfers.product")}</th>
                  <th className="px-3 py-2 text-right">{t("admin:transfers.shippedQty")}</th>
                  <th className="px-3 py-2 text-right">{t("admin:transfers.countedQty")}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {receivingTransfer?.transfer_items?.map((item) => {
                  const current = receiveItems.find((ri) => ri.variantId === item.variant_id);
                  const isDiff = current && Number(current.qtyReceived) !== Number(item.qty_shipped);

                  return (
                    <tr key={item.id}>
                      <td className="px-3 py-2">
                        <div className="font-medium text-slate-800">
                          {item.variant?.product?.name ?? "Unknown"}
                        </div>
                        <div className="text-xs text-slate-400">{item.variant?.sku}</div>
                      </td>
                      <td className="px-3 py-2 text-right font-medium">
                        {item.qty_shipped}
                      </td>
                      <td className="px-3 py-2 text-right">
                        <Input
                          type="number"
                          min="0"
                          step="any"
                          className={`w-24 text-right font-semibold ${
                            isDiff ? "border-amber-400 bg-amber-50 text-amber-900" : ""
                          }`}
                          value={current?.qtyReceived ?? ""}
                          onChange={(e) => {
                            const val = parseFloat(e.target.value) || 0;
                            setReceiveItems((prev) =>
                              prev.map((ri) =>
                                ri.variantId === item.variant_id
                                  ? { ...ri, qtyReceived: val }
                                  : ri,
                              ),
                            );
                          }}
                          required
                        />
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          <div className="flex justify-end gap-2 border-t border-slate-100 pt-3">
            <Button variant="outline" onClick={() => setReceivingTransfer(null)}>
              {t("common:actions.cancel")}
            </Button>
            <Button type="submit" disabled={receiveMutation.isPending}>
              {receiveMutation.isPending ? t("admin:transfers.saving") : t("admin:transfers.confirmReceipt")}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* Modal: Transfer Manifest (Printable View) */}
      <Dialog
        open={Boolean(manifestTransfer)}
        onOpenChange={(open) => !open && setManifestTransfer(null)}
        title={t("admin:transfers.manifestTitle")}
        closeLabel={t("common:actions.close")}
      >
        <div className="grid gap-4 print:p-0">
          <div className="border-b border-slate-200 pb-3">
            <div className="flex justify-between">
              <div>
                <h2 className="text-lg font-bold text-slate-900">{access.tenant.name}</h2>
                <div className="text-sm font-semibold text-slate-700">
                  {t("admin:transfers.stockTransferManifest")}
                </div>
              </div>
              <div className="text-right">
                <div className="text-sm font-mono font-bold text-slate-900">
                  {manifestTransfer?.transfer_no}
                </div>
                <div className="text-xs text-slate-500">
                  {manifestTransfer?.created_at &&
                    new Date(manifestTransfer.created_at).toLocaleDateString(i18n.language, {
                      dateStyle: "medium",
                    })}
                </div>
              </div>
            </div>
          </div>

          {/* Location Details */}
          <div className="grid grid-cols-2 gap-4 rounded-md border border-slate-100 bg-slate-50 p-3 text-xs">
            <div>
              <div className="font-semibold uppercase tracking-wider text-slate-400">
                {t("admin:transfers.dispatchedFrom")}
              </div>
              <div className="font-bold text-slate-800">
                {manifestTransfer?.from_location?.name} ({manifestTransfer?.from_location?.code})
              </div>
              <div className="text-slate-500">{manifestTransfer?.from_location?.address}</div>
            </div>
            <div>
              <div className="font-semibold uppercase tracking-wider text-slate-400">
                {t("admin:transfers.destination")}
              </div>
              <div className="font-bold text-slate-800">
                {manifestTransfer?.to_location?.name} ({manifestTransfer?.to_location?.code})
              </div>
              <div className="text-slate-500">{manifestTransfer?.to_location?.address}</div>
            </div>
          </div>

          {manifestTransfer?.notes && (
            <div className="rounded-md border border-slate-100 p-2.5 text-xs text-slate-600">
              <span className="font-semibold text-slate-700">{t("admin:transfers.notes")}:</span>{" "}
              {manifestTransfer.notes}
            </div>
          )}

          {/* Items Table */}
          <table className="w-full text-left text-xs text-slate-600">
            <thead className="border-b border-slate-200 bg-slate-50 font-semibold uppercase text-slate-500">
              <tr>
                <th className="px-3 py-2">{t("admin:transfers.product")}</th>
                <th className="px-3 py-2 text-right">{t("admin:transfers.shippedQty")}</th>
                <th className="px-3 py-2 text-right">{t("admin:transfers.receivedQty")}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {manifestTransfer?.transfer_items?.map((item) => (
                <tr key={item.id}>
                  <td className="px-3 py-2">
                    <div className="font-semibold text-slate-800">
                      {item.variant?.product?.name ?? "Unknown"}
                    </div>
                    <div className="text-slate-400">{item.variant?.sku}</div>
                  </td>
                  <td className="px-3 py-2 text-right font-medium">{item.qty_shipped}</td>
                  <td className="px-3 py-2 text-right font-medium">
                    {item.qty_received ?? "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {/* Signatures */}
          <div className="mt-4 grid grid-cols-2 gap-8 border-t border-slate-200 pt-6 text-xs text-slate-600">
            <div className="border-t border-dashed border-slate-300 pt-1 text-center">
              {t("admin:transfers.dispatchedBySignature")}
            </div>
            <div className="border-t border-dashed border-slate-300 pt-1 text-center">
              {t("admin:transfers.receivedBySignature")}
            </div>
          </div>

          <div className="flex justify-end gap-2 border-t border-slate-100 pt-3 print:hidden">
            <Button variant="outline" onClick={() => setManifestTransfer(null)}>
              {t("common:actions.close")}
            </Button>
            <Button onClick={() => window.print()}>
              🖨️ {t("admin:transfers.printManifest")}
            </Button>
          </div>
        </div>
      </Dialog>

      {/* Modal: Cancel Transfer Confirmation */}
      <Dialog
        open={Boolean(cancellingTransfer)}
        onOpenChange={(open) => !open && setCancellingTransfer(null)}
        title={t("admin:transfers.cancelConfirmTitle")}
        closeLabel={t("common:actions.cancel")}
      >
        <div className="grid gap-4">
          <p className="text-sm text-slate-600">
            {t("admin:transfers.cancelConfirmMessage", {
              transferNo: cancellingTransfer?.transfer_no,
            })}
          </p>

          <Field label={t("admin:transfers.cancelReason")}>
            <Input
              value={cancelReason}
              onChange={(e) => setCancelReason(e.target.value)}
              placeholder={t("admin:transfers.cancelReasonPlaceholder")}
            />
          </Field>

          <div className="flex justify-end gap-2 border-t border-slate-100 pt-3">
            <Button variant="outline" onClick={() => setCancellingTransfer(null)}>
              {t("common:actions.cancel")}
            </Button>
            <Button
              variant="danger"
              disabled={cancelMutation.isPending}
              onClick={() => {
                if (cancellingTransfer) {
                  cancelMutation.mutate({
                    transferId: cancellingTransfer.id,
                    reason: cancelReason,
                  });
                }
              }}
            >
              {cancelMutation.isPending
                ? t("admin:transfers.saving")
                : t("admin:transfers.confirmCancel")}
            </Button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}
