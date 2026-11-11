import { useMemo, useRef, useState, type FormEvent } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowDownToLine, Minus, Plus, ScanBarcode, Warehouse } from "lucide-react";
import {
  Alert,
  Badge,
  Button,
  Card,
  Dialog,
  EmptyState,
  ErrorState,
  Input,
  PageHeader,
  TabPanel,
  TableSkeleton,
  Tabs,
  useToast,
} from "../components/ui.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { receiveTransferSchema } from "../lib/schemas.ts";
import {
  listStoreIncomingTransfers,
  receiveTransfer,
  type PosIncomingTransferRow,
} from "../lib/transfers-api.ts";

export function ReceiveStockPage() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const toast = useToast();
  const qc = useQueryClient();
  const { activeStore } = useActiveLocation();

  const [tab, setTab] = useState<"incoming" | "history">("incoming");
  const [activeTransfer, setActiveTransfer] = useState<PosIncomingTransferRow | null>(null);
  const [counts, setCounts] = useState<Record<string, number>>({});
  const [scanText, setScanText] = useState("");
  const [scanFeedback, setScanFeedback] = useState<{ tone: "good" | "error"; text: string } | null>(null);
  const [receiveError, setReceiveError] = useState<string | null>(null);
  const scanInputRef = useRef<HTMLInputElement>(null);

  const incomingQuery = useQuery({
    queryKey: ["pos-incoming-transfers", activeStore?.id, "all"],
    queryFn: () => listStoreIncomingTransfers(activeStore!.id, true),
    enabled: Boolean(activeStore?.id),
    refetchInterval: 20_000,
  });

  const shippedRows = useMemo(
    () => (incomingQuery.data ?? []).filter((r) => r.status === "shipped"),
    [incomingQuery.data],
  );
  const receivedRows = useMemo(
    () => (incomingQuery.data ?? []).filter((r) => r.status === "received"),
    [incomingQuery.data],
  );

  function openReceiveDialog(trf: PosIncomingTransferRow) {
    const initial: Record<string, number> = {};
    for (const item of trf.transfer_items) {
      initial[item.variant_id] = Number(item.qty_shipped);
    }
    setCounts(initial);
    setScanText("");
    setScanFeedback(null);
    setReceiveError(null);
    setActiveTransfer(trf);
  }

  function setLineQty(variantId: string, val: number) {
    const safe = Number.isFinite(val) ? Math.max(0, Number(val.toFixed(3))) : 0;
    setCounts((prev) => ({ ...prev, [variantId]: safe }));
  }

  function matchAllShipped() {
    if (!activeTransfer) return;
    const next: Record<string, number> = {};
    for (const item of activeTransfer.transfer_items) {
      next[item.variant_id] = Number(item.qty_shipped);
    }
    setCounts(next);
    setScanFeedback(null);
  }

  function zeroAll() {
    if (!activeTransfer) return;
    const next: Record<string, number> = {};
    for (const item of activeTransfer.transfer_items) {
      next[item.variant_id] = 0;
    }
    setCounts(next);
    setScanFeedback(null);
    scanInputRef.current?.focus();
  }

  function handleScanEnter() {
    if (!activeTransfer) return;
    const q = scanText.trim().toLowerCase();
    if (!q) return;
    const hit = activeTransfer.transfer_items.find(
      (it) => it.barcode?.toLowerCase() === q || it.sku.toLowerCase() === q,
    );
    if (!hit) {
      setScanFeedback({ tone: "error", text: t("admin:posReceive.scanNotFound", { code: scanText.trim() }) });
      return;
    }
    const nextQty = Number(((counts[hit.variant_id] ?? 0) + 1).toFixed(3));
    setCounts((prev) => ({ ...prev, [hit.variant_id]: nextQty }));
    setScanText("");
    setScanFeedback({
      tone: "good",
      text: t("admin:posReceive.scanMatched", {
        name: hit.product_name,
        received: nextQty,
        shipped: Number(hit.qty_shipped),
      }),
    });
  }

  const hasDiscrepancy = useMemo(() => {
    if (!activeTransfer) return false;
    return activeTransfer.transfer_items.some(
      (it) => Number(counts[it.variant_id] ?? 0) !== Number(it.qty_shipped),
    );
  }, [activeTransfer, counts]);

  const receiveMut = useMutation({
    mutationFn: async () => {
      if (!activeTransfer) throw new Error("no_transfer");
      const items = activeTransfer.transfer_items.map((it) => ({
        variantId: it.variant_id,
        qtyReceived: Number(counts[it.variant_id] ?? 0),
      }));
      const parsed = receiveTransferSchema.safeParse({ items });
      if (!parsed.success) {
        throw new Error("invalid_receive");
      }
      return receiveTransfer(activeTransfer.id, parsed.data.items);
    },
    onSuccess: async () => {
      await Promise.all([
        qc.invalidateQueries({ queryKey: ["pos-incoming-transfers"] }),
        qc.invalidateQueries({ queryKey: ["store-stock"] }),
        qc.invalidateQueries({ queryKey: ["transfers"] }),
      ]);
      setActiveTransfer(null);
      toast.good(t("admin:posReceive.receivedToast"));
    },
    onError: (e) => {
      const err =
        e instanceof Error && e.message === "invalid_receive"
          ? t("admin:transfers.invalidReceive")
          : msg(e);
      setReceiveError(err);
      toast.error(err);
    },
  });

  function handleConfirmSubmit(e: FormEvent) {
    e.preventDefault();
    setReceiveError(null);
    receiveMut.mutate();
  }

  if (!activeStore) {
    return <EmptyState title={t("admin:sell.noStore")} />;
  }

  const fmtDate = (iso: string | null) =>
    iso
      ? new Date(iso).toLocaleString(i18n.language, {
          month: "short",
          day: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        })
      : "—";

  return (
    <div className="grid gap-6">
      <PageHeader
        title={t("admin:posReceive.title")}
        subtitle={t("admin:posReceive.subtitle", { store: `${activeStore.code} · ${activeStore.name}` })}
        actions={
          <Badge tone={shippedRows.length > 0 ? "warn" : "good"}>
            {t("admin:posReceive.inTransitBadge", { count: shippedRows.length })}
          </Badge>
        }
      />

      {incomingQuery.isPending ? (
        <Card>
          <TableSkeleton rows={4} cols={5} />
        </Card>
      ) : incomingQuery.isError ? (
        <ErrorState
          message={msg(incomingQuery.error)}
          onRetry={() => void incomingQuery.refetch()}
        />
      ) : (
        <Tabs
          value={tab}
          onValueChange={(v) => setTab(v as "incoming" | "history")}
          label={t("admin:posReceive.title")}
          tabs={[
            {
              value: "incoming",
              label: `${t("admin:posReceive.tabIncoming")} (${shippedRows.length})`,
              testId: "pos-receive-tab-incoming",
            },
            {
              value: "history",
              label: `${t("admin:posReceive.tabHistory")} (${receivedRows.length})`,
              testId: "pos-receive-tab-history",
            },
          ]}
        >
          <TabPanel value="incoming">
            {shippedRows.length === 0 ? (
              <Card>
                <EmptyState
                  title={t("admin:posReceive.emptyTitle")}
                  hint={t("admin:posReceive.emptyDescription")}
                />
              </Card>
            ) : (
              <div className="grid gap-4">
                {shippedRows.map((trf, idx) => {
                  const totalUnits = trf.transfer_items.reduce(
                    (s, i) => s + Number(i.qty_shipped),
                    0,
                  );
                  return (
                    <Card
                      key={trf.id}
                      data-testid={`incoming-shipment-${trf.transfer_no}`}
                      className="grid gap-4"
                    >
                      <div className="flex flex-wrap items-start justify-between gap-4">
                        <div className="grid gap-1">
                          <div className="flex flex-wrap items-center gap-2">
                            <span className="font-mono text-base font-semibold text-slate-900">
                              {trf.transfer_no}
                            </span>
                            <Badge tone="warn">{t("admin:transfers.statusShipped")}</Badge>
                          </div>
                          <div className="flex flex-wrap items-center gap-2 text-sm text-slate-700">
                            <Warehouse size={16} className="text-slate-400" aria-hidden />
                            <span className="font-semibold">
                              {trf.from_location.code} · {trf.from_location.name}
                            </span>
                            <span className="text-slate-400">→</span>
                            <span>
                              {trf.to_location.code} · {trf.to_location.name}
                            </span>
                          </div>
                          <div className="text-xs text-slate-600">
                            {t("admin:posReceive.dispatchedAt", { date: fmtDate(trf.shipped_at) })}
                            {trf.notes ? ` · ${trf.notes}` : ""}
                          </div>
                        </div>

                        <div className="flex items-center gap-4">
                          <div className="text-right">
                            <div className="text-xs text-slate-600">{t("admin:posReceive.manifestSummary")}</div>
                            <div className="text-sm font-semibold text-slate-900 tabular-nums">
                              {t("admin:posReceive.linesAndUnits", {
                                lines: trf.transfer_items.length,
                                units: totalUnits,
                              })}
                            </div>
                          </div>
                          <Button
                            variant={idx === 0 ? "primary" : "outline"}
                            data-testid={`pos-receive-btn-${trf.transfer_no}`}
                            onClick={() => openReceiveDialog(trf)}
                          >
                            <ArrowDownToLine size={16} aria-hidden />
                            <span>{t("admin:posReceive.receiveAction")}</span>
                          </Button>
                        </div>
                      </div>

                      <div className="flex flex-wrap gap-2 border-t border-slate-100 pt-3">
                        {trf.transfer_items.map((item) => (
                          <div
                            key={item.id}
                            className="inline-flex items-center gap-2 rounded-md bg-slate-50 px-3 py-1 text-xs text-slate-700"
                          >
                            <span className="font-semibold text-slate-900">{item.product_name}</span>
                            <span className="font-mono text-slate-500">{item.sku}</span>
                            <span className="font-semibold text-brand-text tabular-nums">
                              ×{Number(item.qty_shipped)}
                            </span>
                          </div>
                        ))}
                      </div>
                    </Card>
                  );
                })}
              </div>
            )}
          </TabPanel>

          <TabPanel value="history">
            {receivedRows.length === 0 ? (
              <Card>
                <EmptyState
                  title={t("admin:posReceive.historyEmptyTitle")}
                  hint={t("admin:posReceive.historyEmptyDescription")}
                />
              </Card>
            ) : (
              <div className="grid gap-3">
                {receivedRows.map((trf) => (
                  <Card key={trf.id} className="grid gap-3">
                    <div className="flex flex-wrap items-center justify-between gap-3">
                      <div className="grid gap-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="font-mono text-sm font-semibold text-slate-900">
                            {trf.transfer_no}
                          </span>
                          <Badge tone="good">{t("admin:transfers.statusReceived")}</Badge>
                          {trf.has_discrepancy ? (
                            <Badge tone="warn">{t("admin:transfers.discrepancy")}</Badge>
                          ) : null}
                        </div>
                        <div className="text-xs text-slate-600">
                          {trf.from_location.code} · {trf.from_location.name} →{" "}
                          {trf.to_location.code} · {trf.to_location.name} ·{" "}
                          {fmtDate(trf.received_at)}
                        </div>
                      </div>
                      <div className="text-xs font-semibold text-slate-700 tabular-nums">
                        {trf.transfer_items.length} {t("admin:transfers.items")}
                      </div>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      {trf.transfer_items.map((item) => {
                        const shipped = Number(item.qty_shipped);
                        const received = Number(item.qty_received ?? shipped);
                        const diff = received - shipped;
                        return (
                          <span
                            key={item.id}
                            className="inline-flex items-center gap-1.5 rounded-md bg-slate-50 px-2.5 py-1 text-xs text-slate-700"
                          >
                            <span className="font-semibold text-slate-900">{item.product_name}</span>
                            <span className="tabular-nums">
                              {received}/{shipped}
                            </span>
                            {diff !== 0 ? (
                              <span className="font-semibold text-amber-800 tabular-nums">
                                ({diff > 0 ? `+${diff}` : diff})
                              </span>
                            ) : null}
                          </span>
                        );
                      })}
                    </div>
                  </Card>
                ))}
              </div>
            )}
          </TabPanel>
        </Tabs>
      )}

      {/* POS Stock Receiving Dialog */}
      <Dialog
        open={Boolean(activeTransfer)}
        onOpenChange={(o) => {
          if (!o) setActiveTransfer(null);
        }}
        title={
          activeTransfer
            ? `${t("admin:posReceive.dialogTitle")} · ${activeTransfer.transfer_no}`
            : t("admin:posReceive.dialogTitle")
        }
        closeLabel={t("common:actions.close")}
      >
        {activeTransfer ? (
          <form onSubmit={handleConfirmSubmit} className="grid gap-4">
            <div className="text-xs text-slate-600">
              {activeTransfer.from_location.code} · {activeTransfer.from_location.name} →{" "}
              {activeTransfer.to_location.code} · {activeTransfer.to_location.name}
            </div>

            {/* Barcode / SKU Scan Bar */}
            <div className="grid gap-2 rounded-lg bg-slate-50 p-3">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <label
                  htmlFor="pos-receive-scan-input"
                  className="flex items-center gap-1.5 text-xs font-semibold text-slate-700"
                >
                  <ScanBarcode size={15} className="text-slate-500" aria-hidden />
                  <span>{t("admin:posReceive.scanLabel")}</span>
                </label>
                <div className="flex items-center gap-2">
                  <Button type="button" variant="outline" size="sm" onClick={zeroAll}>
                    {t("admin:posReceive.countFromZero")}
                  </Button>
                  <Button type="button" variant="outline" size="sm" onClick={matchAllShipped}>
                    {t("admin:posReceive.matchAll")}
                  </Button>
                </div>
              </div>
              <Input
                id="pos-receive-scan-input"
                ref={scanInputRef}
                data-testid="pos-receive-scan"
                value={scanText}
                onChange={(e) => setScanText(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") {
                    e.preventDefault();
                    handleScanEnter();
                  }
                }}
                placeholder={t("admin:posReceive.scanPlaceholder")}
                className="bg-white"
              />
              {scanFeedback ? (
                <Alert tone={scanFeedback.tone}>{scanFeedback.text}</Alert>
              ) : null}
            </div>

            {/* Line Items Verification List */}
            <div className="grid max-h-80 gap-2 overflow-y-auto pr-1">
              {activeTransfer.transfer_items.map((item) => {
                const shipped = Number(item.qty_shipped);
                const received = Number(counts[item.variant_id] ?? 0);
                const diff = Number((received - shipped).toFixed(3));
                return (
                  <div
                    key={item.id}
                    className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-slate-200 bg-white p-3"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-semibold text-slate-900">
                        {item.product_name}
                      </div>
                      <div className="flex flex-wrap items-center gap-2 text-xs text-slate-600">
                        <span className="font-mono">{item.sku}</span>
                        {item.barcode ? <span className="font-mono">· {item.barcode}</span> : null}
                        <span>
                          · {t("admin:posReceive.shippedQty")}:{" "}
                          <strong className="font-semibold text-slate-900 tabular-nums">
                            {shipped}
                          </strong>
                        </span>
                      </div>
                    </div>

                    <div className="flex items-center gap-3">
                      {diff === 0 ? (
                        <Badge tone="good">{t("admin:posReceive.matched")}</Badge>
                      ) : (
                        <Badge tone="warn">{diff > 0 ? `+${diff}` : `${diff}`}</Badge>
                      )}
                      <div className="inline-flex items-center rounded-md border border-slate-200 bg-slate-50">
                        <button
                          type="button"
                          aria-label={t("admin:sell.qty")}
                          onClick={() => setLineQty(item.variant_id, received - 1)}
                          className="flex h-8 w-8 items-center justify-center text-slate-600 hover:bg-slate-100 hover:text-slate-900"
                        >
                          <Minus size={14} aria-hidden />
                        </button>
                        <input
                          type="number"
                          min="0"
                          step="any"
                          aria-label={`${t("admin:posReceive.receivedQty")} ${item.product_name}`}
                          data-testid={`pos-receive-qty-${item.sku}`}
                          value={received}
                          onChange={(e) => setLineQty(item.variant_id, Number(e.target.value))}
                          className="h-8 w-16 border-x border-slate-200 bg-white px-1 text-center text-sm font-semibold text-slate-900 tabular-nums focus:outline-none"
                        />
                        <button
                          type="button"
                          aria-label={t("admin:sell.qty")}
                          onClick={() => setLineQty(item.variant_id, received + 1)}
                          className="flex h-8 w-8 items-center justify-center text-slate-600 hover:bg-slate-100 hover:text-slate-900"
                        >
                          <Plus size={14} aria-hidden />
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>

            {hasDiscrepancy ? (
              <Alert tone="warn">{t("admin:posReceive.discrepancyWarning")}</Alert>
            ) : null}

            {receiveError ? <Alert>{receiveError}</Alert> : null}

            <div className="flex justify-end gap-2 pt-2">
              <Button
                type="button"
                variant="outline"
                onClick={() => setActiveTransfer(null)}
              >
                {t("common:actions.cancel")}
              </Button>
              <Button
                type="submit"
                disabled={receiveMut.isPending}
                data-testid="pos-confirm-receive-btn"
              >
                {receiveMut.isPending
                  ? t("admin:posReceive.saving")
                  : t("admin:posReceive.confirmReceive")}
              </Button>
            </div>
          </form>
        ) : null}
      </Dialog>
    </div>
  );
}
