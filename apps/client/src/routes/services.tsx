import { useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money, uuidv7 } from "@pos/core";
import { ArrowDownLeft, ArrowLeftRight, ArrowUpRight, Smartphone, X } from "lucide-react";
import {
  Alert,
  Badge,
  Button,
  Card,
  EmptyState,
  ErrorState,
  Field,
  Input,
  PageHeader,
  Select,
  StatCard,
  TableSkeleton,
  useToast,
} from "../components/ui.tsx";
import { SupervisorPinDialog } from "../components/supervisor-pin-dialog.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { useActiveLocation } from "../lib/location-context.tsx";
import type { OfflineApprovalPayload } from "../lib/offline-pin-api.ts";
import { parseAmount } from "../lib/sale-math.ts";
import {
  ALL_SERVICE_WALLETS,
  EWALLET_OPTIONS,
  fetchRecentServiceTxns,
  fetchStoreWalletFloats,
  serviceCashEffect,
  serviceFloatEffect,
  submitServiceTxn,
  voidServiceTxn,
  type RecordServiceTxnInput,
  type ServiceKind,
  type ServiceTxnRow,
  type ServiceWallet,
} from "../lib/services-api.ts";
import { useSession } from "../lib/session.tsx";

function parseSignedAmount(text: string, currency: string): number | null {
  const trimmed = text.trim();
  if (!trimmed) return null;
  if (trimmed.startsWith("-")) {
    const abs = parseAmount(trimmed.slice(1).trim(), currency);
    return abs === null || abs === 0 ? null : -abs;
  }
  const clean = trimmed.startsWith("+") ? trimmed.slice(1).trim() : trimmed;
  const pos = parseAmount(clean, currency);
  return pos === null || pos === 0 ? null : pos;
}

export function ServicesPage() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const toast = useToast();
  const { access, can } = useSession();
  const qc = useQueryClient();
  const currency = access.tenant.base_currency ?? "PHP";
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);
  const fmtSigned = (n: number) => (n > 0 ? `+${fmt(n)}` : fmt(n));

  const { activeStore } = useActiveLocation();
  const store =
    activeStore && can("sale.create", activeStore.id)
      ? activeStore
      : access.locations.find((l) => l.type === "store" && can("sale.create", l.id));
  const storeAccess = store ? access.locations.find((l) => l.id === store.id) : undefined;

  const isManagerOrOwner =
    access.role === "superadmin" || (access.role === "admin" && storeAccess?.position === "manager");
  const isSupervisor = access.role === "admin" && storeAccess?.position === "supervisor";
  const canManageFloat = isManagerOrOwner || isSupervisor;

  const [formOpen, setFormOpen] = useState(false);
  const [kind, setKind] = useState<ServiceKind>("cash_in");
  const [wallet, setWallet] = useState<ServiceWallet>("gcash");
  const [amountText, setAmountText] = useState("");
  const [feeText, setFeeText] = useState("");
  const [priceText, setPriceText] = useState("");
  const [refText, setRefText] = useState("");
  const [noteText, setNoteText] = useState("");
  const [formError, setFormError] = useState<string | null>(null);

  // Supervisor PIN modal state for float movements or voids
  const [pendingRecord, setPendingRecord] = useState<RecordServiceTxnInput | null>(null);
  const [voidingId, setVoidingId] = useState<string | null>(null);
  const [voidReason, setVoidReason] = useState("");
  const [voidError, setVoidError] = useState<string | null>(null);
  const [pendingVoidId, setPendingVoidId] = useState<string | null>(null);

  const floatsQuery = useQuery({
    queryKey: ["wallet-floats", store?.id],
    queryFn: () => fetchStoreWalletFloats(store?.id ?? ""),
    enabled: Boolean(store),
    refetchInterval: 60_000,
  });

  const txnsQuery = useQuery({
    queryKey: ["service-txns", store?.id],
    queryFn: () => fetchRecentServiceTxns(store?.id ?? "", currency),
    enabled: Boolean(store),
    refetchInterval: 60_000,
  });

  const refreshAll = () =>
    Promise.all([
      qc.invalidateQueries({ queryKey: ["wallet-floats", store?.id] }),
      qc.invalidateQueries({ queryKey: ["service-txns", store?.id] }),
      qc.invalidateQueries({ queryKey: ["day-summary"] }),
      qc.invalidateQueries({ queryKey: ["multi-store-report"] }),
    ]);

  function openEntryForm(nextKind: ServiceKind) {
    setKind(nextKind);
    setWallet(nextKind === "load" ? "load" : "gcash");
    setAmountText("");
    setFeeText("");
    setPriceText("");
    setRefText("");
    setNoteText("");
    setFormError(null);
    setFormOpen(true);
  }

  function handleKindChange(nextKind: ServiceKind) {
    setKind(nextKind);
    if ((nextKind === "cash_in" || nextKind === "cash_out") && wallet === "load") {
      setWallet("gcash");
    } else if (nextKind === "load") {
      setWallet("load");
    }
    setFormError(null);
  }

  const preview = useMemo(() => {
    const amt =
      kind === "float_adjust"
        ? parseSignedAmount(amountText, currency)
        : parseAmount(amountText, currency);
    if (amt === null || amt === 0) return null;

    if (kind === "load") {
      const price = parseAmount(priceText, currency);
      if (price === null || price < amt) return null;
      const fee = price - amt;
      return {
        fee,
        cash: serviceCashEffect("load", amt, fee, price),
        float: serviceFloatEffect("load", amt),
      };
    }

    const fee =
      kind === "cash_in" || kind === "cash_out"
        ? (feeText.trim() ? (parseAmount(feeText, currency) ?? 0) : 0)
        : 0;

    return {
      fee,
      cash: serviceCashEffect(kind, amt, fee, null),
      float: serviceFloatEffect(kind, amt),
    };
  }, [kind, amountText, feeText, priceText, currency]);

  const recordMut = useMutation({
    mutationFn: async (input: RecordServiceTxnInput) => {
      return submitServiceTxn(input);
    },
    onSuccess: async (res) => {
      setPendingRecord(null);
      setFormOpen(false);
      setAmountText("");
      setFeeText("");
      setPriceText("");
      setRefText("");
      setNoteText("");
      setFormError(null);
      toast.good(res.queuedOffline ? t("common:offline.queuedToast") : t("common:saved"));
      await refreshAll();
    },
    onError: (e) => {
      const err = msg(e);
      setFormError(err);
      toast.error(err);
    },
  });

  const voidMut = useMutation({
    mutationFn: async (params: {
      txnId: string;
      reason?: string;
      approvalId?: string;
      offlineApproval?: OfflineApprovalPayload;
    }) => {
      await voidServiceTxn(params);
    },
    onSuccess: async () => {
      setPendingVoidId(null);
      setVoidingId(null);
      setVoidReason("");
      setVoidError(null);
      toast.good(t("services.voided"));
      await refreshAll();
    },
    onError: (e) => {
      const err = msg(e);
      setVoidError(err);
      toast.error(err);
    },
  });

  function submitForm() {
    if (!store) return;
    setFormError(null);

    const amt =
      kind === "float_adjust"
        ? parseSignedAmount(amountText, currency)
        : parseAmount(amountText, currency);

    if (amt === null || amt === 0 || (kind !== "float_adjust" && amt < 0)) {
      setFormError(t("services.amountInvalid"));
      return;
    }

    let fee: number | undefined;
    let price: number | undefined;

    if (kind === "load") {
      const parsedPrice = parseAmount(priceText, currency);
      if (parsedPrice === null || parsedPrice < amt) {
        setFormError(t("services.priceBelowCost"));
        return;
      }
      price = parsedPrice;
    } else if (kind === "cash_in" || kind === "cash_out") {
      if (feeText.trim()) {
        const parsedFee = parseAmount(feeText, currency);
        if (parsedFee === null || parsedFee < 0) {
          setFormError(t("services.amountInvalid"));
          return;
        }
        fee = parsedFee;
      }
    } else if (kind === "float_adjust" && !noteText.trim()) {
      setFormError(t("services.adjustNoteRequired"));
      return;
    }

    const id = uuidv7();
    const draft: RecordServiceTxnInput = {
      id,
      locationId: store.id,
      kind,
      wallet,
      amount: amt,
      ...(fee !== undefined ? { fee } : {}),
      ...(price !== undefined ? { price } : {}),
      ...(refText.trim() ? { ref: refText.trim() } : {}),
      ...(noteText.trim() ? { note: noteText.trim() } : {}),
    };

    if ((kind === "float_topup" || kind === "float_withdraw") && isSupervisor) {
      setPendingRecord(draft);
      return;
    }

    recordMut.mutate(draft);
  }

  function confirmVoid(txn: ServiceTxnRow) {
    if (isSupervisor && txn.kind !== "float_adjust") {
      setPendingVoidId(txn.id);
      return;
    }
    voidMut.mutate({ txnId: txn.id, reason: voidReason });
  }

  if (!store) {
    return <EmptyState title={t("sell.noStore")} />;
  }

  const txns = txnsQuery.data ?? [];
  const floats = floatsQuery.data ?? [];
  const todayPrefix = new Date().toISOString().slice(0, 10);
  const todayActive = txns.filter((row) => !row.voided_at && row.txn_at.slice(0, 10) === todayPrefix);
  const feesToday = todayActive.reduce((sum, row) => sum + row.fee, 0);

  const walletChoices =
    kind === "cash_in" || kind === "cash_out" ? EWALLET_OPTIONS : ALL_SERVICE_WALLETS;
  const kindChoices: ServiceKind[] = [
    "cash_in",
    "cash_out",
    "load",
    ...(canManageFloat ? (["float_topup", "float_withdraw"] as ServiceKind[]) : []),
    ...(isManagerOrOwner ? (["float_adjust"] as ServiceKind[]) : []),
  ];

  return (
    <div className="grid max-w-4xl gap-5">
      <PageHeader
        title={t("services.title")}
        subtitle={`${store.code} · ${store.name} — ${t("services.subtitle")}`}
        actions={
          <div className="flex flex-wrap items-center gap-2">
            <Button
              size="sm"
              variant={formOpen && kind === "cash_in" ? "primary" : "outline"}
              data-testid="service-action-cash-in"
              onClick={() => openEntryForm("cash_in")}
            >
              <ArrowDownLeft size={15} aria-hidden />
              <span>{t("services.cashIn")}</span>
            </Button>
            <Button
              size="sm"
              variant={formOpen && kind === "cash_out" ? "primary" : "outline"}
              data-testid="service-action-cash-out"
              onClick={() => openEntryForm("cash_out")}
            >
              <ArrowUpRight size={15} aria-hidden />
              <span>{t("services.cashOut")}</span>
            </Button>
            <Button
              size="sm"
              variant={formOpen && kind === "load" ? "primary" : "outline"}
              data-testid="service-action-load"
              onClick={() => openEntryForm("load")}
            >
              <Smartphone size={15} aria-hidden />
              <span>{t("services.sellLoad")}</span>
            </Button>
            {canManageFloat ? (
              <Button
                size="sm"
                variant={
                  formOpen && (kind === "float_topup" || kind === "float_withdraw" || kind === "float_adjust")
                    ? "primary"
                    : "outline"
                }
                data-testid="service-action-float"
                onClick={() => openEntryForm("float_topup")}
              >
                <ArrowLeftRight size={15} aria-hidden />
                <span>{t("services.manageFloat")}</span>
              </Button>
            ) : null}
          </div>
        }
      />

      {/* KPI & Wallet Float Strip */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label={t("services.feesToday")}
          value={<span className="text-emerald-700 tabular-nums">{fmt(feesToday)}</span>}
          subtext={t("services.txnsToday", { count: todayActive.length })}
        />
        {floats.length === 0 ? (
          <Card className="flex items-center text-xs text-slate-500 sm:col-span-1 lg:col-span-3">
            {t("services.noFloats")}
          </Card>
        ) : (
          floats.map((f) => (
            <StatCard
              key={f.wallet}
              label={t(`services.wallets.${f.wallet}`)}
              value={
                <span className={`tabular-nums ${f.negative ? "text-red-700" : "text-slate-900"}`}>
                  {fmt(f.balance)}
                </span>
              }
              subtext={f.negative ? t("services.needsTopup") : t("services.walletFloats")}
            />
          ))
        )}
      </div>

      {/* Record Service Entry Form */}
      {formOpen ? (
        <Card className="grid gap-4 border-brand-200/80" data-testid="record-service-card">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-semibold text-slate-900">{t("services.recordTitle")}</h3>
            <Button variant="ghost" size="sm" onClick={() => setFormOpen(false)} aria-label={t("sell.cancel")}>
              <X size={15} aria-hidden />
            </Button>
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            <Field label={t("services.kindLabel")}>
              <Select
                data-testid="service-kind"
                value={kind}
                onChange={(e) => handleKindChange(e.target.value as ServiceKind)}
              >
                {kindChoices.map((k) => (
                  <option key={k} value={k}>
                    {t(`services.kinds.${k}`)}
                  </option>
                ))}
              </Select>
            </Field>

            <Field label={t("services.walletLabel")}>
              <Select
                data-testid="service-wallet"
                value={wallet}
                onChange={(e) => setWallet(e.target.value as ServiceWallet)}
              >
                {walletChoices.map((w) => (
                  <option key={w} value={w}>
                    {t(`services.wallets.${w}`)}
                  </option>
                ))}
              </Select>
            </Field>

            <Field
              label={
                kind === "float_adjust" ? t("services.adjustAmountLabel") : t("services.amountLabel")
              }
            >
              <Input
                data-testid="service-amount"
                inputMode="decimal"
                placeholder={fmt(0)}
                value={amountText}
                onChange={(e) => setAmountText(e.target.value)}
              />
            </Field>

            {kind === "cash_in" || kind === "cash_out" ? (
              <Field label={t("services.feeLabel")}>
                <Input
                  data-testid="service-fee"
                  inputMode="decimal"
                  placeholder={fmt(0)}
                  value={feeText}
                  onChange={(e) => setFeeText(e.target.value)}
                />
              </Field>
            ) : kind === "load" ? (
              <Field label={t("services.loadPriceLabel")}>
                <Input
                  data-testid="service-price"
                  inputMode="decimal"
                  placeholder={fmt(0)}
                  value={priceText}
                  onChange={(e) => setPriceText(e.target.value)}
                />
              </Field>
            ) : null}

            {kind === "cash_in" || kind === "cash_out" || kind === "load" ? (
              <Field label={t("services.refLabel")}>
                <Input
                  data-testid="service-ref"
                  maxLength={200}
                  placeholder={t("services.refPlaceholder")}
                  value={refText}
                  onChange={(e) => setRefText(e.target.value)}
                />
              </Field>
            ) : null}

            <Field label={t("services.noteLabel")}>
              <Input
                data-testid="service-note"
                maxLength={200}
                placeholder={
                  kind === "float_adjust" ? t("services.noteRequired") : t("services.noteOptional")
                }
                value={noteText}
                onChange={(e) => setNoteText(e.target.value)}
              />
            </Field>
          </div>

          {preview ? (
            <div className="flex flex-wrap items-center justify-between gap-2 rounded-md border border-slate-200 bg-slate-50 px-3.5 py-2 text-xs text-slate-700 tabular-nums">
              <span>
                {t("services.drawerEffectPreview", {
                  cash: fmtSigned(preview.cash),
                  float: fmtSigned(preview.float),
                })}
              </span>
              {kind === "load" ? (
                <span className="font-semibold text-emerald-700">
                  {t("services.loadMarginPreview", { fee: fmt(preview.fee) })}
                </span>
              ) : null}
            </div>
          ) : null}

          {formError ? <Alert>{formError}</Alert> : null}

          <div className="flex justify-end gap-2 border-t border-slate-100 pt-3">
            <Button variant="ghost" onClick={() => setFormOpen(false)}>
              {t("sell.cancel")}
            </Button>
            <Button
              data-testid="save-service-btn"
              disabled={recordMut.isPending || amountText.trim() === ""}
              onClick={submitForm}
            >
              {t("services.saveEntry")}
            </Button>
          </div>
        </Card>
      ) : null}

      {txnsQuery.isError ? (
        <ErrorState
          message={t("services.error")}
          onRetry={() => void txnsQuery.refetch()}
          retryLabel={t("common:actions.retry")}
        />
      ) : txnsQuery.isPending ? (
        <Card className="p-0">
          <TableSkeleton rows={4} cols={4} />
        </Card>
      ) : txns.length === 0 ? (
        <EmptyState title={t("services.empty")} />
      ) : (
        <Card className="overflow-hidden p-0 sm:p-0">
          <div className="border-b border-slate-100 px-5 py-3 text-sm font-semibold text-slate-900">
            {t("services.recentEntries")}
          </div>
          <ul className="divide-y divide-slate-100">
            {txns.map((txn) => {
              const isVoided = Boolean(txn.voided_at);
              const cashEff = serviceCashEffect(txn.kind, txn.amount, txn.fee, txn.price);
              const floatEff = serviceFloatEffect(txn.kind, txn.amount);
              const canVoid =
                !isVoided &&
                (isManagerOrOwner || (isSupervisor && txn.kind !== "float_adjust"));

              return (
                <li
                  key={txn.id}
                  data-testid={`service-row-${txn.id}`}
                  className={`grid gap-2 px-5 py-3.5 text-sm transition-colors hover:bg-slate-50/70 ${
                    isVoided ? "opacity-65" : ""
                  }`}
                >
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div className="flex flex-wrap items-center gap-2.5">
                      <span
                        className={`text-base font-semibold tabular-nums ${
                          isVoided ? "text-slate-400 line-through" : "text-slate-900"
                        }`}
                      >
                        {txn.kind === "float_adjust" ? fmtSigned(txn.amount) : fmt(txn.amount)}
                      </span>
                      <Badge tone={txn.kind === "cash_in" || txn.kind === "load" ? "good" : "neutral"}>
                        {t(`services.kinds.${txn.kind}`)}
                      </Badge>
                      <Badge>{t(`services.wallets.${txn.wallet}`)}</Badge>
                      {txn.fee > 0 ? (
                        <span className="text-xs font-semibold text-emerald-700 tabular-nums">
                          +{fmt(txn.fee)} fee
                        </span>
                      ) : null}
                    </div>

                    <div className="flex items-center gap-3">
                      <span className="font-mono text-xs text-slate-400">
                        {txn.txn_at.slice(0, 10)} {txn.txn_at.slice(11, 16)}
                      </span>
                      {isVoided ? (
                        <Badge tone="warn">{t("services.voided")}</Badge>
                      ) : txn.pending ? (
                        <Badge tone="warn">{t("common:offline.queuedBadge")}</Badge>
                      ) : canVoid ? (
                        <Button
                          size="sm"
                          variant="ghost"
                          data-testid={`void-service-btn-${txn.id}`}
                          onClick={() => {
                            setVoidingId(txn.id);
                            setVoidReason("");
                            setVoidError(null);
                          }}
                        >
                          {t("services.void")}
                        </Button>
                      ) : null}
                    </div>
                  </div>

                  <div className="flex flex-wrap items-center gap-3 text-xs text-slate-500 tabular-nums">
                    <span>
                      {t("services.drawerEffectPreview", {
                        cash: fmtSigned(cashEff),
                        float: fmtSigned(floatEff),
                      })}
                    </span>
                    {txn.ref ? <span className="font-mono text-slate-600">#{txn.ref}</span> : null}
                    {txn.note ? <span>· {txn.note}</span> : null}
                  </div>

                  {voidingId === txn.id ? (
                    <div className="mt-1 grid gap-2.5 rounded-xl border border-red-200 bg-red-50/70 p-3">
                      <p className="text-xs font-medium text-red-900">{t("services.voidPrompt")}</p>
                      <Input
                        data-testid="void-service-reason"
                        placeholder={t("sales.reason")}
                        maxLength={200}
                        value={voidReason}
                        onChange={(e) => setVoidReason(e.target.value)}
                      />
                      {voidError ? <Alert>{voidError}</Alert> : null}
                      <div className="flex justify-end gap-2">
                        <Button size="sm" variant="ghost" onClick={() => setVoidingId(null)}>
                          {t("sell.cancel")}
                        </Button>
                        <Button
                          size="sm"
                          variant="danger"
                          data-testid="confirm-void-service"
                          disabled={voidMut.isPending}
                          onClick={() => confirmVoid(txn)}
                        >
                          {t("sales.confirmVoid")}
                        </Button>
                      </div>
                    </div>
                  ) : null}
                </li>
              );
            })}
          </ul>
        </Card>
      )}

      {/* Supervisor PIN Dialog for Float Movements */}
      <SupervisorPinDialog
        open={Boolean(pendingRecord)}
        onOpenChange={(open) => {
          if (!open) setPendingRecord(null);
        }}
        locationId={store.id}
        action="record_service_txn"
        refId={pendingRecord?.id ?? ""}
        title={t("services.approveFloatTitle")}
        description={t("services.approveFloatDesc")}
        onApproved={(approvalId, offlineApproval) => {
          if (!pendingRecord) return;
          recordMut.mutate({
            ...pendingRecord,
            ...(approvalId ? { approvalId } : {}),
            ...(offlineApproval ? { offlineApproval } : {}),
          });
        }}
      />

      {/* Supervisor PIN Dialog for Service Voids */}
      <SupervisorPinDialog
        open={Boolean(pendingVoidId)}
        onOpenChange={(open) => {
          if (!open) setPendingVoidId(null);
        }}
        locationId={store.id}
        action="void_service_txn"
        refId={pendingVoidId ?? ""}
        title={t("services.approveVoidTitle")}
        description={t("services.approveVoidDesc")}
        onApproved={(approvalId, offlineApproval) => {
          if (!pendingVoidId) return;
          voidMut.mutate({
            txnId: pendingVoidId,
            reason: voidReason,
            ...(approvalId ? { approvalId } : {}),
            ...(offlineApproval ? { offlineApproval } : {}),
          });
        }}
      />
    </div>
  );
}
