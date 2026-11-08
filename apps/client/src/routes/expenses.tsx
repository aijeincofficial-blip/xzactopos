import { useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Alert, Badge, Button, Card, Input, Select } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { parseAmount } from "../lib/sale-math.ts";
import type { Wallet } from "../lib/sale-math.ts";
import {
  EXPENSE_CATEGORIES,
  fetchRecentExpenses,
  recordExpense,
  voidExpense,
  type ExpenseCategory,
  type ExpenseRow,
} from "../lib/expense-api.ts";

const WALLETS: Wallet[] = ["gcash", "maya", "other"];

export function ExpensesPage() {
  const { t, i18n } = useTranslation("admin");
  const msg = useErrorMessage();
  const { access, can } = useSession();
  const qc = useQueryClient();
  const currency = access.tenant.base_currency;
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);
  const { activeStore } = useActiveLocation();
  const store = (activeStore && can("shift.manage", activeStore.id)) ? activeStore : access.locations.find((l) => l.type === "store" && can("shift.manage", l.id));

  const [showAdd, setShowAdd] = useState(false);
  const [amountText, setAmountText] = useState("");
  const [category, setCategory] = useState<ExpenseCategory>("utilities");
  const [paidFrom, setPaidFrom] = useState<"cash" | "ewallet">("cash");
  const [wallet, setWallet] = useState<Wallet>("gcash");
  const [note, setNote] = useState("");
  const [addError, setAddError] = useState<string | null>(null);

  // Void state
  const [voidingId, setVoidingId] = useState<string | null>(null);
  const [voidReason, setVoidReason] = useState("");
  const [voidError, setVoidError] = useState<string | null>(null);

  const expensesQuery = useQuery({
    queryKey: ["expenses", store?.id],
    queryFn: () => fetchRecentExpenses(store?.id ?? ""),
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
      await recordExpense({
        amount: minor,
        category,
        paid_from: paidFrom,
        wallet: paidFrom === "ewallet" ? wallet : undefined,
        note,
        locationId: store.id,
      });
    },
    onSuccess: async () => {
      setAmountText("");
      setNote("");
      setAddError(null);
      setShowAdd(false);
      await refreshAll();
    },
    onError: (e) => setAddError(e instanceof Error ? e.message : msg(e)),
  });

  const voidMut = useMutation({
    mutationFn: async (id: string) => {
      await voidExpense(id, voidReason);
    },
    onSuccess: async () => {
      setVoidingId(null);
      setVoidReason("");
      setVoidError(null);
      await refreshAll();
    },
    onError: (e) => setVoidError(msg(e)),
  });

  if (!store) {
    return (
      <Card>
        <p>{t("sell.noStore")}</p>
      </Card>
    );
  }

  const items = expensesQuery.data ?? [];

  return (
    <div className="grid max-w-3xl gap-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-lg font-semibold">{t("expenses.title")}</h2>
        <Button data-testid="add-expense-btn" onClick={() => setShowAdd(!showAdd)}>
          {showAdd ? t("sell.cancel") : t("expenses.add")}
        </Button>
      </div>

      {showAdd ? (
        <Card className="grid gap-3 border-slate-900" data-testid="add-expense-card">
          <h3 className="font-medium">{t("expenses.recordNew")}</h3>
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="grid gap-1 text-sm">
              <span className="font-medium">{t("expenses.amount")}</span>
              <Input
                data-testid="expense-amount"
                inputMode="decimal"
                placeholder={fmt(0)}
                value={amountText}
                onChange={(e) => setAmountText(e.target.value)}
              />
            </label>
            <label className="grid gap-1 text-sm">
              <span className="font-medium">{t("expenses.category")}</span>
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
            </label>
            <label className="grid gap-1 text-sm">
              <span className="font-medium">{t("expenses.paidFrom")}</span>
              <Select
                data-testid="expense-paid-from"
                value={paidFrom}
                onChange={(e) => setPaidFrom(e.target.value as "cash" | "ewallet")}
              >
                <option value="cash">{t("sell.cash")}</option>
                <option value="ewallet">{t("sell.ewallet")}</option>
              </Select>
            </label>
            {paidFrom === "ewallet" ? (
              <label className="grid gap-1 text-sm">
                <span className="font-medium">{t("sell.wallet")}</span>
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
              </label>
            ) : null}
          </div>
          <label className="grid gap-1 text-sm">
            <span className="font-medium">{t("expenses.note")}</span>
            <Input
              data-testid="expense-note"
              placeholder={t("expenses.notePlaceholder")}
              maxLength={200}
              value={note}
              onChange={(e) => setNote(e.target.value)}
            />
          </label>
          {addError ? <Alert>{addError}</Alert> : null}
          <div className="flex gap-2">
            <Button
              data-testid="save-expense-btn"
              disabled={addMut.isPending || amountText.trim() === ""}
              onClick={() => addMut.mutate()}
            >
              {t("products.save")}
            </Button>
            <Button variant="ghost" onClick={() => setShowAdd(false)}>
              {t("sell.cancel")}
            </Button>
          </div>
        </Card>
      ) : null}

      {expensesQuery.isPending ? <Card>{t("expenses.loading")}</Card> : null}
      {expensesQuery.isError ? <Alert>{t("expenses.error")}</Alert> : null}
      {expensesQuery.data && items.length === 0 ? <Card>{t("expenses.empty")}</Card> : null}

      <ul className="grid gap-2">
        {items.map((exp: ExpenseRow) => {
          const isVoided = Boolean(exp.voided_at);
          return (
            <li key={exp.id}>
              <Card className="grid gap-2 text-sm" data-testid={`expense-row-${exp.id}`}>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <span className="font-semibold text-base">{fmt(exp.amount)}</span>
                    <Badge>{t(`expenses.categories.${exp.category}`)}</Badge>
                    <span className="text-xs text-slate-500">
                      {exp.paid_from === "ewallet" && exp.wallet
                        ? `${t("sell.ewallet")} (${t(`sell.wallets.${exp.wallet}`)})`
                        : t("sell.cash")}
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    {isVoided ? (
                      <Badge tone="warn">{t("expenses.voided")}</Badge>
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
                    <span className="text-xs text-slate-400">
                      {exp.spent_at.slice(0, 10)} {exp.spent_at.slice(11, 16)}
                    </span>
                  </div>
                </div>

                {exp.note ? <p className="text-xs text-slate-600 italic">"{exp.note}"</p> : null}

                {voidingId === exp.id ? (
                  <div className="grid gap-2 rounded border border-red-200 bg-red-50 p-2 mt-2">
                    <p className="text-xs text-red-900">{t("expenses.voidPrompt")}</p>
                    <Input
                      data-testid="void-expense-reason"
                      placeholder={t("sales.reason")}
                      maxLength={200}
                      value={voidReason}
                      onChange={(e) => setVoidReason(e.target.value)}
                    />
                    {voidError ? <Alert>{voidError}</Alert> : null}
                    <div className="flex gap-2">
                      <Button
                        size="sm"
                        variant="danger"
                        data-testid="confirm-void-expense"
                        disabled={voidMut.isPending}
                        onClick={() => voidMut.mutate(exp.id)}
                      >
                        {t("sales.confirmVoid")}
                      </Button>
                      <Button size="sm" variant="ghost" onClick={() => setVoidingId(null)}>
                        {t("sell.cancel")}
                      </Button>
                    </div>
                  </div>
                ) : null}
              </Card>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
