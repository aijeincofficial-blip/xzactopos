import { useTranslation } from "react-i18next";
import { Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Banknote, CreditCard, HandCoins, Rocket, Smartphone, TrendingDown } from "lucide-react";
import { Button, Card, EmptyState, ErrorState, PageHeader, Skeleton } from "../components/ui.tsx";
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
                <Rocket size={14} className="text-ink" aria-hidden />
                <span>{t("upgrade.soloBannerAction")}</span>
              </Button>
            </Link>
          ) : null
        }
      />

      {/* Primary Hero KPIs */}
      <div className="grid gap-4 sm:grid-cols-3">
        <Card data-testid="today-net" className="grid gap-1.5 border-ink bg-ink p-5 text-text-on-dark">
          <div className="flex items-center justify-between gap-2">
            <span className="font-mono text-[11px] font-semibold tracking-wider text-muted-on-dark uppercase">
              {t("today.sales")}
            </span>
            <span data-testid="today-txns">
              <span className="inline-flex items-center rounded-full border border-ink-line-2 bg-ink-2 px-2.5 py-0.5 font-mono text-[11px] font-semibold text-lime">
                {s.totals.txns} {t("today.transactions")}
              </span>
            </span>
          </div>
          <div className="font-display text-3xl font-extrabold tracking-tight text-lime tabular-nums">
            {fmt(s.totals.net)}
          </div>
        </Card>

        <Card data-testid="today-cash-after-expenses" className="grid gap-1.5 p-5">
          <span className="font-mono text-[11px] font-semibold tracking-wider text-muted-on-light uppercase">
            {t("today.cashAfterExpenses")}
          </span>
          <div className="font-display text-2xl font-extrabold tracking-tight text-ok-fg tabular-nums">
            {fmt(cashLeft)}
          </div>
        </Card>

        <Card data-testid="today-owed" className="grid gap-1.5 p-5">
          <span className="font-mono text-[11px] font-semibold tracking-wider text-muted-on-light uppercase">
            {t("today.owed")}
          </span>
          <div
            className={`font-display text-2xl font-extrabold tracking-tight tabular-nums ${
              s.utang.owed > 0 ? "text-sw-pastry-fg" : "text-text-on-light"
            }`}
          >
            {fmt(s.utang.owed)}
          </div>
        </Card>
      </div>

      {/* Grouped Tender Breakdown & Top Items */}
      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="grid content-start gap-3">
          <h2 className="font-mono text-[11px] font-semibold tracking-wider text-muted-on-light uppercase">
            {t("sell.payment")}
          </h2>
          <div className="divide-y-[1.5px] divide-dashed divide-dash text-sm">
            <div data-testid="today-cash" className="flex items-center justify-between py-2.5 first:pt-0">
              <span className="flex items-center gap-2.5 text-muted-on-light">
                <Banknote size={16} className="text-ok-fg" aria-hidden />
                <span>{t("today.cash")}</span>
              </span>
              <span className="font-mono font-semibold text-text-on-light tabular-nums">{fmt(s.totals.cash)}</span>
            </div>
            <div data-testid="today-ewallet" className="flex items-center justify-between py-2.5">
              <span className="flex items-center gap-2.5 text-muted-on-light">
                <Smartphone size={16} className="text-ink" aria-hidden />
                <span>{t("today.ewallet")}</span>
              </span>
              <span className="font-mono font-semibold text-text-on-light tabular-nums">{fmt(s.totals.ewallet)}</span>
            </div>
            <div data-testid="today-card" className="flex items-center justify-between py-2.5">
              <span className="flex items-center gap-2.5 text-muted-on-light">
                <CreditCard size={16} className="text-muted-on-light" aria-hidden />
                <span>{t("today.card")}</span>
              </span>
              <span className="font-mono font-semibold text-text-on-light tabular-nums">
                {fmt(s.totals.card ?? 0)}
              </span>
            </div>
            <div data-testid="today-expenses" className="flex items-center justify-between py-2.5 last:pb-0">
              <span className="flex items-center gap-2.5 text-muted-on-light">
                <TrendingDown size={16} className="text-sw-meal-fg" aria-hidden />
                <span>{t("today.expenses")}</span>
              </span>
              <span className="font-mono font-semibold text-sw-meal-fg tabular-nums">{fmt(s.expenses.total)}</span>
            </div>
          </div>
        </Card>

        <Card className="grid content-start gap-3">
          <h2 className="font-mono text-[11px] font-semibold tracking-wider text-muted-on-light uppercase">
            {t("today.topItems")}
          </h2>
          {s.top_items.length === 0 ? (
            <EmptyState title={t("today.noSales")} />
          ) : (
            <ul className="divide-y-[1.5px] divide-dashed divide-dash text-sm">
              {s.top_items.slice(0, 5).map((i, idx) => (
                <li key={i.variant_id} className="flex items-center justify-between gap-3 py-2.5 first:pt-0 last:pb-0">
                  <div className="flex min-w-0 items-center gap-2.5">
                    <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-ink font-mono text-[11px] font-bold text-lime">
                      {idx + 1}
                    </span>
                    <span className="truncate font-semibold text-text-on-light">{i.name}</span>
                    <span className="shrink-0 font-mono text-xs text-muted-on-light tabular-nums">×{i.qty}</span>
                  </div>
                  <span className="font-mono font-bold text-text-on-light tabular-nums">{fmt(i.revenue)}</span>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>

      {can("tenant.modules") && mode === "solo" ? (
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-[20px] border-[1.5px] border-sand-line bg-paper px-4 py-3 text-xs text-muted-on-light">
          <div className="flex items-center gap-2">
            <HandCoins size={15} className="text-ink" aria-hidden />
            <span className="font-semibold text-text-on-light">{t("upgrade.soloBannerTitle")}</span>
            <span className="hidden text-muted-on-light sm:inline">— {t("upgrade.soloBannerText")}</span>
          </div>
          <Link to="/app/upgrade" className="font-semibold text-ink underline decoration-lime decoration-2 underline-offset-2 hover:opacity-80">
            {t("upgrade.soloBannerAction")} →
          </Link>
        </div>
      ) : null}
    </div>
  );
}
