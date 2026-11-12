import { useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Download, Plus, X } from "lucide-react";
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
import { useSession } from "../lib/session.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { downloadCsv, exportExpensesCsv } from "../lib/csv-helper.ts";
import { parseAmount } from "../lib/sale-math.ts";
import type { Wallet } from "../lib/sale-math.ts";
import {
  EXPENSE_CATEGORIES,
  fetchRecentExpenses,
  filterExpenseRows,
  recordExpense,
  summarizeExpenseRows,
  voidExpense,
  type ExpenseCategory,
  type ExpensePaidFromFilter,
  type ExpenseRow,
  type ExpenseStatusFilter,
} from "../lib/expense-api.ts";

const WALLETS: Wallet[] = ["gcash", "maya", "other"];

export function ExpensesPage() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const msg = useErrorMessage();
  const toast = useToast();
  const { access, can } = useSession();
  const qc = useQueryClient();
  const currency = access.tenant.base_currency;
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);
  const { activeStore } = useActiveLocation();
  const store =
    activeStore && can("shift.manage", activeStore.id)
      ? activeStore
      : access.locations.find((l) => l.type === "store" && can("shift.manage", l.id));

  const [showAdd, setShowAdd] = useState(false);
  const [amountText, setAmountText] = useState("");
  const [category, setCategory] = useState<ExpenseCategory>("utilities");
  const [paidFrom, setPaidFrom] = useState<"cash" | "ewallet">("cash");
  const [wallet, setWallet] = useState<Wallet>("gcash");
  const [note, setNote] = useState("");
  const [addError, setAddError] = useState<string | null>(null);

  // Filter state
  const [searchText, setSearchText] = useState("");
  const [filterCategory, setFilterCategory] = useState<ExpenseCategory | "all">("all");
  const [filterPaidFrom, setFilterPaidFrom] = useState<ExpensePaidFromFilter>("all");
  const [filterStatus, setFilterStatus] = useState<ExpenseStatusFilter>("all");
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");

  // Void state
  const [voidingId, setVoidingId] = useState<string | null>(null);
  const [voidReason, setVoidReason] = useState("");
  const [voidError, setVoidError] = useState<string | null>(null);

  const expensesQuery = useQuery({
    queryKey: ["expenses", store?.id],
    queryFn: () => fetchRecentExpenses(store?.id ?? "", currency),
    enabled: Boolean(store),
    refetchInterval: 60_000,
  });

  const refreshAll = () =>
    Promise.all([
      qc.invalidateQueries({ queryKey: ["expenses", store?.id] }),
      qc.invalidateQueries({ queryKey: ["day-summary"] }),
    ]);

  const addMut = useMutation({
    mutationFn: async () => {
      if (!store) throw new Error("No store");
      const minor = parseAmount(amountText, currency);
      if (minor === null || minor <= 0) {
        throw new Error(t("expenses.amountInvalid"));
      }
      return recordExpense({
        amount: minor,
        category,
        paid_from: paidFrom,
        wallet: paidFrom === "ewallet" ? wallet : undefined,
        note,
        locationId: store.id,
      });
    },
    onSuccess: async (res) => {
      setAmountText("");
      setNote("");
      setAddError(null);
      setShowAdd(false);
      toast.good(res.queuedOffline ? t("common:offline.queuedToast") : t("common:saved"));
      await refreshAll();
    },
    onError: (e) => {
      const err = e instanceof Error ? e.message : msg(e);
      setAddError(err);
      toast.error(err);
    },
  });

  const voidMut = useMutation({
    mutationFn: async (id: string) => {
      await voidExpense(id, voidReason);
    },
    onSuccess: async () => {
      setVoidingId(null);
      setVoidReason("");
      setVoidError(null);
      toast.good(t("expenses.voided"));
      await refreshAll();
    },
    onError: (e) => {
      const err = msg(e);
      setVoidError(err);
      toast.error(err);
    },
  });

  const items = useMemo(() => expensesQuery.data ?? [], [expensesQuery.data]);
  const hasActiveFilters =
    searchText.trim().length > 0 ||
    filterCategory !== "all" ||
    filterPaidFrom !== "all" ||
    filterStatus !== "all" ||
    fromDate !== "" ||
    toDate !== "";

  const filteredItems = useMemo(
    () =>
      filterExpenseRows(items, {
        search: searchText,
        category: filterCategory,
        paidFrom: filterPaidFrom,
        status: filterStatus,
        fromDate,
        toDate,
      }),
    [items, searchText, filterCategory, filterPaidFrom, filterStatus, fromDate, toDate],
  );

  const summary = useMemo(() => summarizeExpenseRows(filteredItems), [filteredItems]);

  if (!store) {
    return <EmptyState title={t("sell.noStore")} />;
  }

  function clearFilters() {
    setSearchText("");
    setFilterCategory("all");
    setFilterPaidFrom("all");
    setFilterStatus("all");
    setFromDate("");
    setToDate("");
  }

  function handleExportCsv() {
    if (!store || filteredItems.length === 0) return;
    const csv = exportExpensesCsv(
      filteredItems.map((exp) => ({
        spentAt: exp.spent_at,
        status: exp.voided_at ? "voided" : "active",
        category: t(`expenses.categories.${exp.category}`),
        paidFrom: exp.paid_from === "ewallet" ? t("sell.ewallet") : t("sell.cash"),
        wallet: exp.wallet ? t(`sell.wallets.${exp.wallet}`) : null,
        amount: exp.amount,
        note: exp.note,
        voidReason: exp.void_reason,
      })),
      currency,
    );
    const stamp = new Date().toISOString().slice(0, 10);
    downloadCsv(csv, `expenses-${store.code.toLowerCase()}-${stamp}.csv`);
    toast.good(t("expenses.exportedToast", { count: filteredItems.length }));
  }

  return (
    <div className="grid max-w-4xl gap-5">
      <PageHeader
        title={t("expenses.title")}
        subtitle={`${store.code} · ${store.name}`}
        actions={
          <div className="flex flex-wrap items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              data-testid="export-expenses-csv"
              disabled={filteredItems.length === 0}
              onClick={handleExportCsv}
            >
              <Download size={15} aria-hidden />
              <span>{t("expenses.exportCsv")}</span>
            </Button>
            <Button
              variant={showAdd ? "outline" : "primary"}
              size="sm"
              data-testid="add-expense-btn"
              onClick={() => setShowAdd(!showAdd)}
            >
              {showAdd ? <X size={15} aria-hidden /> : <Plus size={15} aria-hidden />}
              <span>{showAdd ? t("sell.cancel") : t("expenses.add")}</span>
            </Button>
          </div>
        }
      />

      {/* KPI Summary Strip */}
      <div className="grid gap-4 sm:grid-cols-3">
        <StatCard
          label={t("expenses.kpiTotalSpend")}
          value={<span className="tabular-nums text-slate-900">{fmt(summary.totalActive)}</span>}
          subtext={t("expenses.kpiTotalSubtext", {
            count: summary.activeCount,
            operating: fmt(summary.operatingSpend),
          })}
        />
        <StatCard
          label={t("expenses.kpiCashOutflow")}
          value={<span className="tabular-nums text-amber-800">{fmt(summary.cashOutflow)}</span>}
          subtext={t("expenses.kpiCashSubtext")}
        />
        <StatCard
          label={t("expenses.kpiEwalletOutflow")}
          value={<span className="tabular-nums text-slate-900">{fmt(summary.ewalletOutflow)}</span>}
          subtext={t("expenses.kpiEwalletSubtext", { voided: summary.voidedCount })}
        />
      </div>

      {showAdd ? (
        <Card className="grid gap-4 border-brand-200/80" data-testid="add-expense-card">
          <h3 className="text-sm font-semibold text-slate-900">{t("expenses.recordNew")}</h3>
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label={t("expenses.amount")}>
              <Input
                data-testid="expense-amount"
                inputMode="decimal"
                placeholder={fmt(0)}
                value={amountText}
                onChange={(e) => setAmountText(e.target.value)}
              />
            </Field>
            <Field label={t("expenses.category")}>
              <Select
                data-testid="expense-category"
                value={category}
                onChange={(e) => setCategory(e.target.value as ExpenseCategory)}
              >
                {EXPENSE_CATEGORIES.map((cat) => (
                  <option key={cat} value={cat}>
                    {t(`expenses.categories.${cat}`)}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label={t("expenses.paidFrom")}>
              <Select
                data-testid="expense-paid-from"
                value={paidFrom}
                onChange={(e) => setPaidFrom(e.target.value as "cash" | "ewallet")}
              >
                <option value="cash">{t("sell.cash")}</option>
                <option value="ewallet">{t("sell.ewallet")}</option>
              </Select>
            </Field>
            {paidFrom === "ewallet" ? (
              <Field label={t("sell.wallet")}>
                <Select
                  data-testid="expense-wallet"
                  value={wallet}
                  onChange={(e) => setWallet(e.target.value as Wallet)}
                >
                  {WALLETS.map((w) => (
                    <option key={w} value={w}>
                      {t(`sell.wallets.${w}`)}
                    </option>
                  ))}
                </Select>
              </Field>
            ) : null}
          </div>
          <Field label={t("expenses.note")}>
            <Input
              data-testid="expense-note"
              placeholder={t("expenses.notePlaceholder")}
              maxLength={200}
              value={note}
              onChange={(e) => setNote(e.target.value)}
            />
          </Field>
          {addError ? <Alert>{addError}</Alert> : null}
          <div className="flex justify-end gap-2 border-t border-slate-100 pt-3">
            <Button variant="ghost" onClick={() => setShowAdd(false)}>
              {t("sell.cancel")}
            </Button>
            <Button
              data-testid="save-expense-btn"
              disabled={addMut.isPending || amountText.trim() === ""}
              onClick={() => addMut.mutate()}
            >
              {t("products.save")}
            </Button>
          </div>
        </Card>
      ) : null}

      {/* Filter Bar */}
      {items.length > 0 || hasActiveFilters ? (
        <Card className="grid gap-3">
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Field label={t("expenses.searchLabel")}>
              <Input
                data-testid="expenses-search"
                placeholder={t("expenses.searchPlaceholder")}
                value={searchText}
                onChange={(e) => setSearchText(e.target.value)}
              />
            </Field>
            <Field label={t("expenses.category")}>
              <Select
                data-testid="expenses-filter-category"
                value={filterCategory}
                onChange={(e) => setFilterCategory(e.target.value as ExpenseCategory | "all")}
              >
                <option value="all">{t("expenses.allCategories")}</option>
                {EXPENSE_CATEGORIES.map((cat) => (
                  <option key={cat} value={cat}>
                    {t(`expenses.categories.${cat}`)}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label={t("expenses.paidFrom")}>
              <Select
                data-testid="expenses-filter-paid-from"
                value={filterPaidFrom}
                onChange={(e) => setFilterPaidFrom(e.target.value as ExpensePaidFromFilter)}
              >
                <option value="all">{t("expenses.allPaidFrom")}</option>
                <option value="cash">{t("sell.cash")}</option>
                <option value="ewallet">{t("sell.ewallet")}</option>
              </Select>
            </Field>
            <Field label={t("expenses.statusLabel")}>
              <Select
                data-testid="expenses-filter-status"
                value={filterStatus}
                onChange={(e) => setFilterStatus(e.target.value as ExpenseStatusFilter)}
              >
                <option value="all">{t("expenses.statusAll")}</option>
                <option value="active">{t("expenses.statusActive")}</option>
                <option value="voided">{t("expenses.statusVoided")}</option>
              </Select>
            </Field>
          </div>

          <div className="flex flex-wrap items-end justify-between gap-3">
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label={t("expenses.dateFrom")}>
                <Input
                  type="date"
                  data-testid="expenses-filter-from"
                  value={fromDate}
                  onChange={(e) => setFromDate(e.target.value)}
                />
              </Field>
              <Field label={t("expenses.dateTo")}>
                <Input
                  type="date"
                  data-testid="expenses-filter-to"
                  value={toDate}
                  onChange={(e) => setToDate(e.target.value)}
                />
              </Field>
            </div>
            {hasActiveFilters ? (
              <div className="flex items-center gap-3 text-xs text-slate-500">
                <span>
                  {t("expenses.showingFiltered", {
                    shown: filteredItems.length,
                    total: items.length,
                  })}
                </span>
                <Button
                  size="sm"
                  variant="ghost"
                  data-testid="expenses-clear-filters"
                  onClick={clearFilters}
                >
                  {t("expenses.clearFilters")}
                </Button>
              </div>
            ) : null}
          </div>
        </Card>
      ) : null}

      {expensesQuery.isError ? (
        <ErrorState
          message={t("expenses.error")}
          onRetry={() => void expensesQuery.refetch()}
          retryLabel={t("common:actions.retry")}
        />
      ) : null}

      {expensesQuery.isPending ? (
        <Card className="p-0">
          <TableSkeleton rows={4} cols={3} />
        </Card>
      ) : items.length === 0 ? (
        <EmptyState title={t("expenses.empty")} />
      ) : filteredItems.length === 0 ? (
        <EmptyState title={t("expenses.emptyFiltered")} />
      ) : (
        <Card className="overflow-hidden p-0 sm:p-0">
          <ul className="divide-y divide-slate-100">
            {filteredItems.map((exp: ExpenseRow) => {
              const isVoided = Boolean(exp.voided_at);
              return (
                <li
                  key={exp.id}
                  data-testid={`expense-row-${exp.id}`}
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
                        {fmt(exp.amount)}
                      </span>
                      <Badge>{t(`expenses.categories.${exp.category}`)}</Badge>
                      <span className="text-xs text-slate-500">
                        {exp.paid_from === "ewallet" && exp.wallet
                          ? `${t("sell.ewallet")} (${t(`sell.wallets.${exp.wallet}`)})`
                          : t("sell.cash")}
                      </span>
                    </div>
                    <div className="flex items-center gap-3">
                      <span className="font-mono text-xs text-slate-400">
                        {exp.spent_at.slice(0, 10)} {exp.spent_at.slice(11, 16)}
                      </span>
                      {isVoided ? (
                        <Badge tone="warn">{t("expenses.voided")}</Badge>
                      ) : exp.pending ? (
                        <Badge tone="warn">{t("common:offline.queuedBadge")}</Badge>
                      ) : (
                        <Button
                          size="sm"
                          variant="ghost"
                          data-testid={`void-expense-btn-${exp.id}`}
                          onClick={() => {
                            setVoidingId(exp.id);
                            setVoidReason("");
                            setVoidError(null);
                          }}
                        >
                          {t("expenses.void")}
                        </Button>
                      )}
                    </div>
                  </div>

                  {exp.note ? <p className="text-xs text-slate-500">{exp.note}</p> : null}

                  {voidingId === exp.id ? (
                    <div className="mt-1 grid gap-2.5 rounded-xl border border-red-200 bg-red-50/70 p-3">
                      <p className="text-xs font-medium text-red-900">{t("expenses.voidPrompt")}</p>
                      <Input
                        data-testid="void-expense-reason"
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
                          data-testid="confirm-void-expense"
                          disabled={voidMut.isPending}
                          onClick={() => voidMut.mutate(exp.id)}
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
    </div>
  );
}
