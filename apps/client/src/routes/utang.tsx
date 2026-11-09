import { useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Alert, Badge, Button, Card, Input, Select } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { parseAmount } from "../lib/sale-math.ts";
import { isOverdue } from "../lib/utang-math.ts";
import { dayInTimezone } from "../lib/today.ts";
import { createCustomer } from "../lib/sell-api.ts";
import {
  fetchCustomerLedger,
  fetchCustomersWithBalances,
  recordUtangPayment,
  setUtangDueDate,
} from "../lib/utang-api.ts";

export function UtangPage() {
  const { t, i18n } = useTranslation("admin");
  const msg = useErrorMessage();
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
      await refreshAll();
      setSelectedId(created.id);
    },
    onError: (e) => setPayError(msg(e)),
  });

  const payMut = useMutation({
    mutationFn: async () => {
      if (!store) throw new Error("No store");
      if (!selectedCustomer) throw new Error("No customer selected");
      const minor = parseAmount(payAmount, currency);
      if (minor === null || minor <= 0) {
        throw new Error(t("utang.amountInvalid"));
      }
      await recordUtangPayment({
        customerId: selectedCustomer.customerId,
        amount: minor,
        method: payMethod,
        note: payNote,
        locationId: store.id,
      });
    },
    onSuccess: async () => {
      setPayAmount("");
      setPayNote("");
      setPayError(null);
      await refreshAll();
    },
    onError: (e) => setPayError(e instanceof Error ? e.message : msg(e)),
  });

  const dueDateMut = useMutation({
    mutationFn: async () => {
      if (!selectedCustomer) return;
      await setUtangDueDate(selectedCustomer.customerId, newDueDate ? newDueDate : null);
    },
    onSuccess: async () => {
      setDueDateError(null);
      await refreshAll();
    },
    onError: (e) => setDueDateError(msg(e)),
  });

  if (!store) {
    return (
      <Card>
        <p>{t("sell.noStore")}</p>
      </Card>
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
    <div className="grid gap-4 lg:grid-cols-[1fr_420px]">
      <section className="grid content-start gap-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <h2 className="text-lg font-semibold">{t("utang.title")}</h2>
            <p className="text-xs text-slate-500">
              {t("utang.totalOwed")}: <strong className="text-slate-900">{fmt(totalOwed)}</strong>
            </p>
          </div>
          <Button data-testid="add-customer-btn" onClick={() => setShowAdd(true)}>
            {t("utang.newCustomer")}
          </Button>
        </div>

        {showAdd ? (
          <Card className="grid gap-2 border-slate-900 p-3" data-testid="new-customer-card">
            <h3 className="font-medium text-sm">{t("utang.newCustomer")}</h3>
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
            <div className="flex gap-2">
              <Button
                size="sm"
                data-testid="cust-save-btn"
                disabled={newName.trim() === "" || addCustomerMut.isPending}
                onClick={() => addCustomerMut.mutate()}
              >
                {t("products.save")}
              </Button>
              <Button size="sm" variant="ghost" onClick={() => setShowAdd(false)}>
                {t("sell.cancel")}
              </Button>
            </div>
          </Card>
        ) : null}

        <Input
          data-testid="utang-search"
          placeholder={t("utang.searchPlaceholder")}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />

        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={onlyOwed} onChange={(e) => setOnlyOwed(e.target.checked)} />
          {t("utang.onlyOwed")}
        </label>

        {customersQuery.isPending ? <Card>{t("utang.loading")}</Card> : null}
        {customersQuery.isError ? <Alert>{t("utang.error")}</Alert> : null}
        {customersQuery.data && customers.length === 0 ? <Card>{t("utang.noCustomers")}</Card> : null}

        <ul className="grid gap-2">
          {customers.map((c) => {
            const overdue = isOverdue(c.balance, c.dueOn, today);
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
                  }}
                  className={`flex w-full items-center justify-between gap-2 rounded-md border bg-white px-3 py-2 text-left text-sm hover:bg-slate-50 ${
                    c.customerId === selectedId ? "border-slate-900" : "border-slate-200"
                  }`}
                >
                  <span>
                    <span className="block font-medium">{c.name}</span>
                    <span className="text-xs text-slate-500">
                      {c.phone ? `${c.phone} · ` : ""}
                      {c.dueOn ? `${t("utang.due")}: ${c.dueOn}` : t("utang.noDueDate")}
                    </span>
                  </span>
                  <span className="flex items-center gap-2">
                    {overdue ? <Badge tone="warn">{t("utang.overdue")}</Badge> : null}
                    <span className={`font-semibold ${c.balance > 0 ? "text-amber-800" : "text-slate-600"}`}>
                      {fmt(c.balance)}
                    </span>
                  </span>
                </button>
              </li>
            );
          })}
        </ul>
      </section>

      <section className="grid content-start gap-3">
        {selectedCustomer ? (
          <div className="grid gap-3">
            <Card className="grid gap-3" data-testid="customer-detail-card">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-semibold text-lg">{selectedCustomer.name}</h3>
                  {selectedCustomer.phone ? (
                    <p className="text-xs text-slate-500">{selectedCustomer.phone}</p>
                  ) : null}
                </div>
                <div className="text-right">
                  <span className="text-xs text-slate-500 block">{t("utang.balance")}</span>
                  <span
                    data-testid="customer-balance"
                    className={`text-xl font-bold ${
                      selectedCustomer.balance > 0 ? "text-amber-700" : "text-emerald-700"
                    }`}
                  >
                    {fmt(selectedCustomer.balance)}
                  </span>
                </div>
              </div>

              {/* Record Payment */}
              <div className="grid gap-2 border-t border-slate-200 pt-3">
                <span className="text-sm font-medium">{t("utang.recordPayment")}</span>
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
                <span className="text-sm font-medium">{t("utang.promisedPayDate")}</span>
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
              <h4 className="text-sm font-semibold">{t("utang.history")}</h4>
              {ledgerQuery.isPending ? <p className="text-sm text-slate-500">{t("utang.loading")}</p> : null}
              {ledgerQuery.data && ledgerQuery.data.length === 0 ? (
                <p className="text-sm text-slate-500">{t("utang.noHistory")}</p>
              ) : null}
              <ul className="grid gap-1.5 text-sm">
                {(ledgerQuery.data ?? []).map((entry) => (
                  <li
                    key={entry.id}
                    className="flex items-center justify-between border-b border-slate-100 pb-1.5 last:border-0"
                  >
                    <div>
                      <span className="block font-medium">
                        {t(`utang.kind.${entry.kind}`)}
                        {entry.note ? ` - ${entry.note}` : ""}
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
        ) : (
          <Card className="text-sm text-slate-500">{t("utang.pickCustomer")}</Card>
        )}
      </section>
    </div>
  );
}
