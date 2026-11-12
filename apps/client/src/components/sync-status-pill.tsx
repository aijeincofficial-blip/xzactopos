import { useEffect, useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { useQueryClient } from "@tanstack/react-query";
import { AlertTriangle, CloudUpload, RefreshCw, Trash2, WifiOff } from "lucide-react";
import { formatMoney, money } from "@pos/core";
import { Badge, Button, Dialog, useToast } from "./ui.tsx";
import { useOnlineStatus } from "../lib/network.ts";
import {
  describeQueuedPosOp,
  discardPosOp,
  flushPosOutbox,
  retryFailedPosOps,
  setPosOutboxTenant,
  usePosOutboxSnapshot,
} from "../lib/pos-outbox.ts";

export function SyncStatusPill({
  tenantId,
  currency,
  timezone,
}: {
  tenantId: string;
  currency: string;
  timezone: string;
}) {
  const { t, i18n } = useTranslation(["common", "errors"]);
  const qc = useQueryClient();
  const toast = useToast();
  setPosOutboxTenant(tenantId);

  const isOnline = useOnlineStatus();
  const outboxOps = usePosOutboxSnapshot();
  const [open, setOpen] = useState(false);
  const [syncing, setSyncing] = useState(false);

  const pendingCount = useMemo(
    () => outboxOps.filter((o) => o.state === "pending").length,
    [outboxOps],
  );
  const failedCount = useMemo(
    () => outboxOps.filter((o) => o.state === "failed").length,
    [outboxOps],
  );

  const fmt = (minor: number) => formatMoney(money(minor, currency), i18n.language);
  const when = (iso: string) => {
    try {
      return new Intl.DateTimeFormat(i18n.language, {
        dateStyle: "short",
        timeStyle: "short",
        timeZone: timezone,
      }).format(new Date(iso));
    } catch {
      return iso.slice(0, 16).replace("T", " ");
    }
  };

  async function invalidateSyncedStores() {
    await Promise.all([
      qc.invalidateQueries({ queryKey: ["sales"] }),
      qc.invalidateQueries({ queryKey: ["pos-stock-levels"] }),
      qc.invalidateQueries({ queryKey: ["products"] }),
      qc.invalidateQueries({ queryKey: ["customers"] }),
      qc.invalidateQueries({ queryKey: ["customers-balances"] }),
      qc.invalidateQueries({ queryKey: ["customer-ledger"] }),
      qc.invalidateQueries({ queryKey: ["expenses"] }),
      qc.invalidateQueries({ queryKey: ["service-txns"] }),
      qc.invalidateQueries({ queryKey: ["wallet-floats"] }),
      qc.invalidateQueries({ queryKey: ["store-shifts"] }),
      qc.invalidateQueries({ queryKey: ["day-summary"] }),
    ]);
  }

  async function runFlush(retryFailed = false) {
    if (!isOnline) return;
    if (retryFailed && failedCount > 0) {
      retryFailedPosOps();
    }
    setSyncing(true);
    try {
      const res = await flushPosOutbox();
      if (res.synced > 0) {
        toast.good(t("common:offline.syncedToast", { count: res.synced }));
        await invalidateSyncedStores();
      }
    } finally {
      setSyncing(false);
    }
  }

  useEffect(() => {
    if (!isOnline || pendingCount === 0) return;
    void runFlush(false);
  }, [isOnline, pendingCount]);

  if (isOnline && outboxOps.length === 0 && !open) {
    return null;
  }

  const toneClass = !isOnline
    ? "border-amber-300 bg-amber-50 text-amber-900 hover:bg-amber-100"
    : failedCount > 0
      ? "border-red-300 bg-red-50 text-red-900 hover:bg-red-100"
      : "border-brand-200 bg-brand-50 text-brand-text hover:bg-brand-100/70";

  return (
    <>
      <button
        type="button"
        data-testid="global-sync-pill"
        onClick={() => setOpen(true)}
        className={`inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-full border px-2.5 text-xs font-semibold transition-colors ${toneClass}`}
      >
        {!isOnline ? (
          <span data-testid="offline-badge" className="inline-flex items-center gap-1.5">
            <WifiOff size={13} aria-hidden />
            <span>
              {outboxOps.length > 0
                ? `${t("common:offline.badge")} · ${outboxOps.length}`
                : t("common:offline.badge")}
            </span>
          </span>
        ) : failedCount > 0 ? (
          <>
            <AlertTriangle size={13} aria-hidden />
            <span>{t("common:offline.syncFailedPill", { count: failedCount })}</span>
          </>
        ) : syncing ? (
          <>
            <RefreshCw size={13} className="animate-spin" aria-hidden />
            <span>{t("common:offline.syncingPill", { count: pendingCount })}</span>
          </>
        ) : (
          <>
            <CloudUpload size={13} aria-hidden />
            <span>{t("common:offline.syncPendingPill", { count: pendingCount })}</span>
          </>
        )}
      </button>

      <Dialog
        open={open}
        onOpenChange={setOpen}
        title={t("common:offline.inspectorTitle")}
        closeLabel={t("common:actions.close")}
      >
        <div className="grid gap-4" data-testid="outbox-inspector-dialog">
          <p className="text-xs text-slate-600">{t("common:offline.inspectorDesc")}</p>

          {outboxOps.length === 0 ? (
            <div className="rounded-xl border border-dashed border-slate-200 bg-slate-50/70 px-4 py-6 text-center text-sm text-slate-600">
              {t("common:offline.inspectorEmpty")}
            </div>
          ) : (
            <ul className="grid max-h-72 gap-2 overflow-y-auto pr-1">
              {outboxOps.map((op) => {
                const desc = describeQueuedPosOp(op);
                return (
                  <li
                    key={op.opId}
                    data-testid={`outbox-row-${op.opId}`}
                    className="flex items-start justify-between gap-3 rounded-xl border border-slate-200 bg-slate-50/80 p-3 text-xs"
                  >
                    <div className="min-w-0 grid gap-0.5">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="font-semibold text-slate-900">
                          {t(`common:offline.opKind.${op.kind}`)}
                        </span>
                        <Badge tone={op.state === "failed" ? "danger" : "warn"}>
                          {op.state === "failed"
                            ? t("common:offline.stateFailed")
                            : t("common:offline.statePending")}
                        </Badge>
                        {desc.amountMinor !== null ? (
                          <span className="font-semibold text-slate-800 tabular-nums">
                            {fmt(desc.amountMinor)}
                          </span>
                        ) : null}
                      </div>
                      <div className="flex flex-wrap items-center gap-1.5 text-slate-500">
                        <span>{when(op.createdAt)}</span>
                        {desc.primaryRef ? (
                          <>
                            <span>·</span>
                            <span className="font-mono text-slate-700">{desc.primaryRef}</span>
                          </>
                        ) : null}
                      </div>
                      {op.lastError ? (
                        <div className="mt-0.5 font-medium text-red-700">
                          {t(`errors:${op.lastError}`, { defaultValue: op.lastError })}
                        </div>
                      ) : null}
                    </div>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      data-testid={`discard-outbox-${op.opId}`}
                      onClick={() => discardPosOp(op.opId)}
                      aria-label={t("common:offline.discard")}
                      title={t("common:offline.discard")}
                    >
                      <Trash2 size={14} className="text-slate-500" />
                    </Button>
                  </li>
                );
              })}
            </ul>
          )}

          <div className="flex flex-wrap items-center justify-end gap-2 border-t border-slate-100 pt-3">
            {failedCount > 0 ? (
              <Button
                type="button"
                variant="outline"
                size="sm"
                data-testid="outbox-retry-failed"
                disabled={!isOnline || syncing}
                onClick={() => void runFlush(true)}
              >
                <RefreshCw size={14} />
                <span>{t("common:offline.retryAll")}</span>
              </Button>
            ) : null}
            <Button
              type="button"
              size="sm"
              data-testid="outbox-sync-now"
              disabled={!isOnline || syncing || outboxOps.length === 0}
              onClick={() => void runFlush(true)}
            >
              <RefreshCw size={14} className={syncing ? "animate-spin" : ""} />
              <span>{t("common:offline.syncNow")}</span>
            </Button>
          </div>
        </div>
      </Dialog>
    </>
  );
}
