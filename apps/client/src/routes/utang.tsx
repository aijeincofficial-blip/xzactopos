import { useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Plus, X } from "lucide-react";
import { Alert, Badge, Button, Card, Dialog, EmptyState, ErrorState, Field, Input, PageHeader, Select, TableSkeleton, useToast } from "../components/ui.tsx";
import { CustomerStatementDialog } from "../components/customer-statement-dialog.tsx";
import { downloadCsv, exportCustomerLedgerCsv, type CustomerLedgerExportItem } from "../lib/csv-helper.ts";
import { useSession } from "../lib/session.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { parseAmount } from "../lib/sale-math.ts";
import { calculateAdjustment, isOverdue } from "../lib/utang-math.ts";
import { dayInTimezone } from "../lib/today.ts";
import { createCustomer } from "../lib/sell-api.ts";
import {
  adjustUtang,
  fetchCustomerLedger,
  fetchCustomersWithBalances,
  recordUtangPayment,
  setUtangDueDate,
} from "../lib/utang-api.ts";

export function UtangPage() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const toast = useToast();
  const { access, can } = useSession();
  const qc = useQueryClient();
  const currency = access.tenant.base_currency;
  const today = dayInTimezone(access.tenant.timezone);
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);
  const { activeStore } = useActiveLocation();
  const store = (activeStore && can("sale.create", activeStore.id)) ? activeStore : access.locations.find((l) => l.type === "store" && can("sale.create", l.id));

  const [search, setSearch] = useState("");
  const [onlyOwed, setOnlyOwed] = useState(true);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  // New customer form
  const [showAdd, setShowAdd] = useState(false);
  const [newName, setNewName] = useState("");
  const [newPhone, setNewPhone] = useState("");

  // Payment form
  const [payAmount, setPayAmount] = useState("");
  const [payMethod, setPayMethod] = useState<"cash" | "ewallet">("cash");
  const [payNote, setPayNote] = useState("");
  const [payError, setPayError] = useState<string | null>(null);

  // Due date form
  const [newDueDate, setNewDueDate] = useState("");
  const [dueDateError, setDueDateError] = useState<string | null>(null);

  // Adjust balance form
  const canAdjust = (store && can("stock.adjust_store", store.id)) || access.role === "superadmin";
  const [showAdjust, setShowAdjust] = useState(false);
  const [adjustDirection, setAdjustDirection] = useState<"less" | "more">("less");
  const [adjustAmount, setAdjustAmount] = useState("");
  const [adjustNote, setAdjustNote] = useState("");
  const [adjustError, setAdjustError] = useState<string | null>(null);

  // Statement dialog
  const [showStatement, setShowStatement] = useState(false);

  const customersQuery = useQuery({
    queryKey: ["customers-balances"],
    queryFn: () => fetchCustomersWithBalances(),
    refetchInterval: 60_000,
  });

  const ledgerQuery = useQuery({
    queryKey: ["customer-ledger", selectedId],
    queryFn: () => fetchCustomerLedger(selectedId!),
    enabled: selectedId !== null,
  });

  const selectedCustomer = (customersQuery.data ?? []).find((c) => c.customerId === selectedId) ?? null;

  const refreshAll = () =>
    Promise.all([
      qc.invalidateQueries({ queryKey: ["customers-balances"] }),
      qc.invalidateQueries({ queryKey: ["customer-ledger", selectedId] }),
      qc.invalidateQueries({ queryKey: ["day-summary"] }),
      qc.invalidateQueries({ queryKey: ["customers"] }),
    ]);

  const addCustomerMut = useMutation({
    mutationFn: () => createCustomer(newName, newPhone),
    onSuccess: async (created) => {
      setNewName("");
      setNewPhone("");
      setShowAdd(false);
      toast.good(t("common:saved"));
      await refreshAll();
      setSelectedId(created.id);
    },
    onError: (e) => {
      const err = msg(e);
      setPayError(err);
      toast.error(err);
    },
  });

  const payMut = useMutation({
    mutationFn: async () => {
      if (!store) throw new Error("No store");
      if (!selectedCustomer) throw new Error("No customer selected");
      const minor = parseAmount(payAmount, currency);
      if (minor === null || minor <= 0) {
        throw new Error(t("utang.amountInvalid"));
      }
      return recordUtangPayment({
        customerId: selectedCustomer.customerId,
        amount: minor,
        method: payMethod,
        note: payNote,
        locationId: store.id,
      });
    },
    onSuccess: async (res) => {
      setPayAmount("");
      setPayNote("");
      setPayError(null);
      toast.good(res.queuedOffline ? t("common:offline.queuedToast") : t("common:saved"));
      await refreshAll();
    },
    onError: (e) => {
      const err = e instanceof Error ? e.message : msg(e);
      setPayError(err);
      toast.error(err);
    },
  });

  const dueDateMut = useMutation({
    mutationFn: async () => {
      if (!selectedCustomer) return;
      await setUtangDueDate(selectedCustomer.customerId, newDueDate ? newDueDate : null);
    },
    onSuccess: async () => {
      setDueDateError(null);
      toast.good(t("common:saved"));
      await refreshAll();
    },
    onError: (e) => {
      const err = msg(e);
      setDueDateError(err);
      toast.error(err);
    },
  });

  const adjustMut = useMutation({
    mutationFn: async () => {
      if (!selectedCustomer) throw new Error("No customer selected");
      const minor = parseAmount(adjustAmount, currency);
      if (minor === null || minor <= 0) {
        throw new Error(t("utang.adjustAmountInvalid"));
      }
      const signed = calculateAdjustment(minor, adjustDirection);
      if (signed === 0) {
        throw new Error(t("utang.adjustAmountInvalid"));
      }
      await adjustUtang({
        customerId: selectedCustomer.customerId,
        amount: signed,
        note: adjustNote,
        locationId: store?.id,
      });
    },
    onSuccess: async () => {
      setShowAdjust(false);
      setAdjustAmount("");
      setAdjustNote("");
      setAdjustError(null);
      toast.good(t("utang.adjusted"));
      await refreshAll();
    },
    onError: (e) => {
      const err = e instanceof Error ? e.message : msg(e);
      setAdjustError(err);
      toast.error(err);
    },
  });

  if (!store) {
    return (
      <EmptyState title={t("sell.noStore")} />
    );
  }

  const needle = search.trim().toLowerCase();
  const customers = (customersQuery.data ?? []).filter((c) => {
    const matchesSearch = !needle || c.name.toLowerCase().includes(needle) || (c.phone ?? "").includes(needle);
    const matchesFilter = !onlyOwed || c.balance > 0;
    return matchesSearch && matchesFilter;
  });

  const totalOwed = (customersQuery.data ?? []).reduce((acc, c) => acc + Math.max(0, c.balance), 0);

  return (
    <div className="grid gap-5">
      <PageHeader
        title={t("utang.title")}
        subtitle={`${t("utang.totalOwed")}: ${fmt(totalOwed)}`}
        actions={
          <Button size="sm" data-testid="add-customer-btn" onClick={() => setShowAdd(true)}>
            <Plus size={15} aria-hidden />
            <span>{t("utang.newCustomer")}</span>
          </Button>
        }
      />
      <div className={selectedCustomer ? "grid items-start gap-5 lg:grid-cols-[1fr_420px]" : "grid gap-5"}>
        <section className="grid content-start gap-3.5">
          {showAdd ? (
            <Card className="grid gap-3 border-brand-200/80 p-4" data-testid="new-customer-card">
              <h3 className="text-sm font-semibold text-slate-900">{t("utang.newCustomer")}</h3>
              <div className="grid gap-2.5 sm:grid-cols-2">
                <Input
                  data-testid="cust-name-input"
                  placeholder={t("sell.customerName")}
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                />
                <Input
                  data-testid="cust-phone-input"
                  placeholder={t("sell.customerPhone")}
                  value={newPhone}
                  onChange={(e) => setNewPhone(e.target.value)}
                />
              </div>
              <div className="flex justify-end gap-2">
                <Button size="sm" variant="ghost" onClick={() => setShowAdd(false)}>
                  {t("sell.cancel")}
                </Button>
                <Button
                  size="sm"
                  data-testid="cust-save-btn"
                  disabled={newName.trim() === "" || addCustomerMut.isPending}
                  onClick={() => addCustomerMut.mutate()}
                >
                  {t("products.save")}
                </Button>
              </div>
            </Card>
          ) : null}

          <div className="flex flex-wrap items-center gap-2.5">
            <Input
              data-testid="utang-search"
              placeholder={t("utang.searchPlaceholder")}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="min-w-[220px] flex-1"
            />
            <label className="inline-flex cursor-pointer items-center gap-2 rounded-lg border border-slate-200/80 bg-white px-3 py-2 text-xs font-medium text-slate-700 hover:bg-slate-50">
              <input
                type="checkbox"
                checked={onlyOwed}
                onChange={(e) => setOnlyOwed(e.target.checked)}
                className="rounded border-slate-300 text-brand-600"
              />
              <span>{t("utang.onlyOwed")}</span>
            </label>
          </div>

          {customersQuery.isPending ? (
            <Card className="p-0">
              <TableSkeleton rows={4} cols={3} />
            </Card>
          ) : null}
          {customersQuery.isError ? (
            <ErrorState message={t("utang.error")} onRetry={() => void customersQuery.refetch()} retryLabel={t("common:actions.retry")} />
          ) : null}
          {customersQuery.data && customers.length === 0 ? <EmptyState title={t("utang.noCustomers")} /> : null}

          {customers.length > 0 ? (
            <Card className="overflow-hidden p-0 sm:p-0">
              <ul className="divide-y divide-slate-100">
                {customers.map((c) => {
                  const overdue = isOverdue(c.balance, c.dueOn, today);
                  const isSelected = c.customerId === selectedId;
                  return (
                    <li key={c.customerId}>
                      <button
                        type="button"
                        data-testid={`customer-row-${c.customerId}`}
                        onClick={() => {
                          setSelectedId(c.customerId);
                          setNewDueDate(c.dueOn ?? "");
                          setPayError(null);
                          setDueDateError(null);
                          setShowAdjust(false);
                          setAdjustError(null);
                        }}
                        className={`flex w-full cursor-pointer items-center justify-between gap-3 px-4 py-3 text-left text-sm transition-colors ${
                          isSelected ? "bg-brand-50/60" : "hover:bg-slate-50/80"
                        }`}
                      >
                        <span className="min-w-0">
                          <span className="block truncate font-semibold text-slate-900">{c.name}</span>
                          <span className="text-xs text-slate-500">
                            {c.phone ? `${c.phone} · ` : ""}
                            {c.dueOn ? `${t("utang.due")}: ${c.dueOn}` : t("utang.noDueDate")}
                          </span>
                        </span>
                        <span className="flex shrink-0 items-center gap-2.5">
                          {overdue ? <Badge tone="warn">{t("utang.overdue")}</Badge> : null}
                          <span
                            className={`font-semibold tabular-nums ${
                              c.balance > 0 ? "text-amber-700" : "text-slate-500"
                            }`}
                          >
                            {fmt(c.balance)}
                          </span>
                        </span>
                      </button>
                    </li>
                  );
                })}
              </ul>
            </Card>
          ) : null}
        </section>

        {selectedCustomer ? (
          <section className="grid content-start gap-3 lg:sticky lg:top-16">
            <div className="grid gap-3">
              <Card className="grid gap-3" data-testid="customer-detail-card">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <h3 className="text-base font-semibold text-slate-900">{selectedCustomer.name}</h3>
                    {selectedCustomer.phone ? (
                      <p className="text-xs text-slate-500">{selectedCustomer.phone}</p>
                    ) : null}
                  </div>
                  <div className="flex items-start gap-2">
                    <div className="text-right">
                      <span className="block text-xs text-slate-500">{t("utang.balance")}</span>
                      <span
                        data-testid="customer-balance"
                        className={`text-xl font-semibold tabular-nums ${
                          selectedCustomer.balance > 0 ? "text-amber-700" : "text-emerald-700"
                        }`}
                      >
                        {fmt(selectedCustomer.balance)}
                      </span>
                      {canAdjust ? (
                        <div className="mt-1">
                          <Button
                            size="sm"
                            variant="outline"
                            data-testid="adjust-balance-btn"
                            onClick={() => {
                              setAdjustDirection("less");
                              setAdjustAmount("");
                              setAdjustNote("");
                              setAdjustError(null);
                              setShowAdjust(true);
                            }}
                          >
                            {t("utang.adjustBalance")}
                          </Button>
                        </div>
                      ) : null}
                    </div>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="px-2"
                      aria-label={t("common:actions.close")}
                      onClick={() => setSelectedId(null)}
                    >
                      <X size={16} aria-hidden />
                    </Button>
                  </div>
                </div>

              {/* Record Payment */}
              <div className="grid gap-2 border-t border-slate-200 pt-3">
                <span className="text-sm font-semibold">{t("utang.recordPayment")}</span>
                <div className="grid gap-2 sm:grid-cols-2">
                  <Input
                    data-testid="payment-amount"
                    inputMode="decimal"
                    placeholder={t("utang.paymentAmount")}
                    value={payAmount}
                    onChange={(e) => setPayAmount(e.target.value)}
                  />
                  <Select
                    data-testid="payment-method"
                    value={payMethod}
                    onChange={(e) => setPayMethod(e.target.value as "cash" | "ewallet")}
                  >
                    <option value="cash">{t("sell.cash")}</option>
                    <option value="ewallet">{t("sell.ewallet")}</option>
                  </Select>
                </div>
                <Input
                  data-testid="payment-note"
                  placeholder={t("utang.notePlaceholder")}
                  maxLength={200}
                  value={payNote}
                  onChange={(e) => setPayNote(e.target.value)}
                />
                {payError ? <Alert>{payError}</Alert> : null}
                <Button
                  data-testid="save-payment-btn"
                  disabled={payMut.isPending || payAmount.trim() === ""}
                  onClick={() => payMut.mutate()}
                >
                  {t("utang.submitPayment")}
                </Button>
              </div>

              {/* Due Date Management */}
              <div className="grid gap-2 border-t border-slate-200 pt-3">
                <span className="text-sm font-semibold">{t("utang.promisedPayDate")}</span>
                <div className="flex gap-2">
                  <Input
                    type="date"
                    data-testid="due-date-input"
                    value={newDueDate}
                    onChange={(e) => setNewDueDate(e.target.value)}
                  />
                  <Button
                    size="sm"
                    variant="outline"
                    data-testid="save-due-date-btn"
                    disabled={dueDateMut.isPending}
                    onClick={() => dueDateMut.mutate()}
                  >
                    {t("products.save")}
                  </Button>
                </div>
                {dueDateError ? <Alert>{dueDateError}</Alert> : null}
              </div>
            </Card>

            {/* Statement / Ledger History */}
            <Card className="grid gap-2" data-testid="customer-ledger-card">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <h4 className="text-sm font-semibold">{t("utang.history")}</h4>
                <div className="flex items-center gap-2">
                  <Button
                    size="sm"
                    variant="outline"
                    data-testid="soa-open-btn"
                    onClick={() => setShowStatement(true)}
                  >
                    {t("utang.printStatement")}
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    data-testid="export-ledger-csv"
                    disabled={!ledgerQuery.data || ledgerQuery.data.length === 0}
                    onClick={() => {
                      if (!selectedCustomer || !ledgerQuery.data) return;
                      const items: CustomerLedgerExportItem[] = ledgerQuery.data.map((e) => ({
                        date: e.occurred_at.slice(0, 10),
                        kind: t(`utang.kind.${e.kind}`),
                        description: e.note ?? (e.kind === "charge" ? t("utang.kind.charge") : t(`utang.kind.${e.kind}`)),
                        method: e.method ?? undefined,
                        amount: e.amount,
                      }));
                      const csv = exportCustomerLedgerCsv(selectedCustomer.name, items, currency);
                      const safeName = selectedCustomer.name.toLowerCase().replace(/[^a-z0-9]/g, "_");
                      downloadCsv(csv, `soa-${safeName}-${today}.csv`);
                    }}
                  >
                    {t("utang.downloadCsv")}
                  </Button>
                </div>
              </div>
              {ledgerQuery.isPending ? (
                <div className="grid gap-2 py-2">
                  {Array.from({ length: 3 }).map((_, i) => (
                    <div key={i} className="h-8 rounded bg-slate-100 animate-pulse" />
                  ))}
                </div>
              ) : null}
              {ledgerQuery.isError ? (
                <ErrorState message={t("utang.error")} onRetry={() => void ledgerQuery.refetch()} retryLabel={t("common:actions.retry")} />
              ) : null}
              {ledgerQuery.data && ledgerQuery.data.length === 0 ? (
                <EmptyState title={t("utang.noHistory")} />
              ) : null}
              <ul className="grid gap-1.5 text-sm">
                {(ledgerQuery.data ?? []).map((entry) => (
                  <li
                    key={entry.id}
                    className="flex items-center justify-between border-b border-slate-100 pb-1.5 last:border-0"
                  >
                    <div>
                      <span className="flex items-center gap-2 font-semibold">
                        <span>
                          {t(`utang.kind.${entry.kind}`)}
                          {entry.note ? ` - ${entry.note}` : ""}
                        </span>
                        {entry.pending ? <Badge tone="warn">{t("common:offline.queuedBadge")}</Badge> : null}
                      </span>
                      <span className="text-xs text-slate-400">
                        {entry.occurred_at.slice(0, 10)} {entry.method ? `· ${entry.method}` : ""}
                      </span>
                    </div>
                    <span
                      className={`font-mono font-semibold ${
                        entry.amount > 0 ? "text-amber-800" : "text-emerald-700"
                      }`}
                    >
                      {entry.amount > 0 ? `+${fmt(entry.amount)}` : fmt(entry.amount)}
                    </span>
                  </li>
                ))}
              </ul>
            </Card>
          </div>
          </section>
        ) : null}
      </div>

      {showAdjust && selectedCustomer ? (
        <Dialog
          open
          onOpenChange={(open) => {
            if (!open) {
              setShowAdjust(false);
              setAdjustError(null);
            }
          }}
          title={t("utang.adjustTitle", { name: selectedCustomer.name })}
          closeLabel={t("common:actions.close")}
        >
          <div className="grid gap-4 py-2">
            <div className="flex gap-2">
              <Button
                type="button"
                size="sm"
                variant={adjustDirection === "less" ? "primary" : "outline"}
                data-testid="adjust-less"
                onClick={() => setAdjustDirection("less")}
              >
                {t("utang.writeOff")}
              </Button>
              <Button
                type="button"
                size="sm"
                variant={adjustDirection === "more" ? "primary" : "outline"}
                data-testid="adjust-more"
                onClick={() => setAdjustDirection("more")}
              >
                {t("utang.addMore")}
              </Button>
            </div>

            <Field label={t("utang.adjustAmount")}>
              <Input
                data-testid="adjust-amount"
                inputMode="decimal"
                placeholder="0.00"
                autoFocus
                value={adjustAmount}
                onChange={(e) => setAdjustAmount(e.target.value)}
              />
            </Field>

            <Field label={t("utang.adjustNote")}>
              <Input
                data-testid="adjust-note"
                maxLength={200}
                placeholder={t("utang.notePlaceholder")}
                value={adjustNote}
                onChange={(e) => setAdjustNote(e.target.value)}
              />
            </Field>

            {adjustError ? <Alert>{adjustError}</Alert> : null}

            <div className="flex justify-end gap-2 pt-2">
              <Button
                type="button"
                variant="ghost"
                onClick={() => {
                  setShowAdjust(false);
                  setAdjustError(null);
                }}
              >
                {t("common:actions.cancel")}
              </Button>
              <Button
                type="button"
                data-testid="adjust-save-btn"
                disabled={adjustMut.isPending || !adjustAmount.trim()}
                onClick={() => adjustMut.mutate()}
              >
                {t("common:actions.save")}
              </Button>
            </div>
          </div>
        </Dialog>
      ) : null}

      <CustomerStatementDialog
        open={showStatement}
        onClose={() => setShowStatement(false)}
        customer={selectedCustomer}
        entries={ledgerQuery.data ?? []}
        currency={currency}
        tenantName={access.tenant.name}
        storeName={store?.name ?? ""}
        preparedBy={access.full_name || access.username}
        today={today}
      />
    </div>
  );
}
