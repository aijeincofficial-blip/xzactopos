import { useTranslation } from "react-i18next";
import { Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Banknote, CreditCard, HandCoins, Rocket, Smartphone, TrendingDown } from "lucide-react";
import { Badge, Button, Card, EmptyState, ErrorState, PageHeader, Skeleton } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { tenantMode } from "../lib/mode.ts";
import { dayInTimezone, getDaySummary } from "../lib/today.ts";

/** Solo home: today's sales, tender breakdown, expenses, and customer utang in a calm, grouped layout. */
export function TodayPage() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const { access, can } = useSession();
  const mode = tenantMode(access);
  const day = dayInTimezone(access.tenant.timezone);
  const q = useQuery({ queryKey: ["day-summary", day], queryFn: () => getDaySummary(day), refetchInterval: 120_000 });
  const fmt = (n: number) => formatMoney(money(n, access.tenant.base_currency), i18n.language);

  if (q.isPending) {
    return (
      <div className="grid gap-5">
        <Skeleton className="h-8 w-48" />
        <div className="grid gap-4 sm:grid-cols-3">
          <Skeleton className="h-28" />
          <Skeleton className="h-28" />
          <Skeleton className="h-28" />
        </div>
        <Skeleton className="h-44" />
      </div>
    );
  }
  if (q.isError) {
    return <ErrorState message={t("today.error")} onRetry={() => void q.refetch()} retryLabel={t("common:actions.retry")} />;
  }

  const s = q.data;
  const cashLeft = s.totals.cash - s.expenses.cash;

  return (
    <div className="grid gap-5">
      <PageHeader
        title={t("today.title")}
        subtitle={day}
        actions={
          can("tenant.modules") && mode === "solo" ? (
            <Link to="/app/upgrade">
              <Button variant="outline" size="sm">
                <Rocket size={14} className="text-brand-600" aria-hidden />
                <span>{t("upgrade.soloBannerAction")}</span>
              </Button>
            </Link>
          ) : null
        }
      />

      {/* Primary Hero KPIs */}
      <div className="grid gap-4 sm:grid-cols-3">
        <Card data-testid="today-net" className="grid gap-1.5 border-brand-200/70 bg-brand-50/35 p-5">
          <div className="flex items-center justify-between gap-2">
            <span className="text-xs font-semibold tracking-wider text-slate-500 uppercase">{t("today.sales")}</span>
            <span data-testid="today-txns">
              <Badge tone="neutral">
                {s.totals.txns} {t("today.transactions")}
              </Badge>
            </span>
          </div>
          <div className="text-3xl font-semibold tracking-tight text-slate-900 tabular-nums">{fmt(s.totals.net)}</div>
        </Card>

        <Card data-testid="today-cash-after-expenses" className="grid gap-1.5 p-5">
          <span className="text-xs font-semibold tracking-wider text-slate-500 uppercase">
            {t("today.cashAfterExpenses")}
          </span>
          <div className="text-2xl font-semibold tracking-tight text-emerald-700 tabular-nums">{fmt(cashLeft)}</div>
        </Card>

        <Card data-testid="today-owed" className="grid gap-1.5 p-5">
          <span className="text-xs font-semibold tracking-wider text-slate-500 uppercase">{t("today.owed")}</span>
          <div
            className={`text-2xl font-semibold tracking-tight tabular-nums ${
              s.utang.owed > 0 ? "text-amber-700" : "text-slate-900"
            }`}
          >
            {fmt(s.utang.owed)}
          </div>
        </Card>
      </div>

      {/* Grouped Tender Breakdown & Top Items */}
      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="grid content-start gap-3">
          <h2 className="text-xs font-semibold tracking-wider text-slate-500 uppercase">{t("sell.payment")}</h2>
          <div className="divide-y divide-slate-100 text-sm">
            <div data-testid="today-cash" className="flex items-center justify-between py-2.5 first:pt-0">
              <span className="flex items-center gap-2.5 text-slate-600">
                <Banknote size={16} className="text-emerald-600" aria-hidden />
                <span>{t("today.cash")}</span>
              </span>
              <span className="font-semibold text-slate-900 tabular-nums">{fmt(s.totals.cash)}</span>
            </div>
            <div data-testid="today-ewallet" className="flex items-center justify-between py-2.5">
              <span className="flex items-center gap-2.5 text-slate-600">
                <Smartphone size={16} className="text-brand-600" aria-hidden />
                <span>{t("today.ewallet")}</span>
              </span>
              <span className="font-semibold text-slate-900 tabular-nums">{fmt(s.totals.ewallet)}</span>
            </div>
            <div data-testid="today-card" className="flex items-center justify-between py-2.5">
              <span className="flex items-center gap-2.5 text-slate-600">
                <CreditCard size={16} className="text-slate-500" aria-hidden />
                <span>{t("today.card")}</span>
              </span>
              <span className="font-semibold text-slate-900 tabular-nums">{fmt(s.totals.card ?? 0)}</span>
            </div>
            <div data-testid="today-expenses" className="flex items-center justify-between py-2.5 last:pb-0">
              <span className="flex items-center gap-2.5 text-slate-600">
                <TrendingDown size={16} className="text-red-500" aria-hidden />
                <span>{t("today.expenses")}</span>
              </span>
              <span className="font-semibold text-red-700 tabular-nums">{fmt(s.expenses.total)}</span>
            </div>
          </div>
        </Card>

        <Card className="grid content-start gap-3">
          <h2 className="text-xs font-semibold tracking-wider text-slate-500 uppercase">{t("today.topItems")}</h2>
          {s.top_items.length === 0 ? (
            <EmptyState title={t("today.noSales")} />
          ) : (
            <ul className="divide-y divide-slate-100 text-sm">
              {s.top_items.slice(0, 5).map((i, idx) => (
                <li key={i.variant_id} className="flex items-center justify-between gap-3 py-2.5 first:pt-0 last:pb-0">
                  <div className="flex min-w-0 items-center gap-2.5">
                    <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-md bg-slate-100 text-xs font-semibold text-slate-500">
                      {idx + 1}
                    </span>
                    <span className="truncate font-medium text-slate-900">{i.name}</span>
                    <span className="shrink-0 text-xs text-slate-400 tabular-nums">×{i.qty}</span>
                  </div>
                  <span className="font-semibold text-slate-900 tabular-nums">{fmt(i.revenue)}</span>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>

      {can("tenant.modules") && mode === "solo" ? (
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-200/80 bg-white px-4 py-3 text-xs text-slate-600">
          <div className="flex items-center gap-2">
            <HandCoins size={15} className="text-brand-600" aria-hidden />
            <span className="font-semibold text-slate-800">{t("upgrade.soloBannerTitle")}</span>
            <span className="hidden text-slate-500 sm:inline">— {t("upgrade.soloBannerText")}</span>
          </div>
          <Link to="/app/upgrade" className="font-semibold text-brand-text hover:underline">
            {t("upgrade.soloBannerAction")} →
          </Link>
        </div>
      ) : null}
    </div>
  );
}
