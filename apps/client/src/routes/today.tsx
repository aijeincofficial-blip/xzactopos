import { useTranslation } from "react-i18next";
import { Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Button, Card, EmptyState, ErrorState, PageHeader } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { tenantMode } from "../lib/mode.ts";
import { dayInTimezone, getDaySummary } from "../lib/today.ts";

function Stat({ label, value, id }: { label: string; value: string; id: string }) {
  return (
    <Card data-testid={id}>
      <div className="text-xs text-slate-500">{label}</div>
      <div className="mt-1 text-xl font-semibold">{value}</div>
    </Card>
  );
}

/** Solo home: today's sales, how they were paid, expenses and what customers still owe (read-only). */
export function TodayPage() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const { access, can } = useSession();
  const mode = tenantMode(access);
  const day = dayInTimezone(access.tenant.timezone);
  const q = useQuery({ queryKey: ["day-summary", day], queryFn: () => getDaySummary(day), refetchInterval: 120_000 });
  const fmt = (n: number) => formatMoney(money(n, access.tenant.base_currency), i18n.language);

  if (q.isPending) return <Card>{t("today.loading")}</Card>;
  if (q.isError) return <ErrorState message={t("today.error")} onRetry={() => void q.refetch()} retryLabel={t("common:actions.retry")} />;

  const s = q.data;
  const cashLeft = s.totals.cash - s.expenses.cash;
  return (
    <>
      {can("tenant.modules") && mode === "solo" ? (
        <Card className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-brand-100 bg-brand-50 p-4">
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <span className="rounded bg-brand-600 px-1.5 py-0.5 text-xs font-semibold text-[#fff] uppercase tracking-wider">
                {t("upgrade.badge")}
              </span>
              <h3 className="font-semibold text-slate-900">{t("upgrade.soloBannerTitle")}</h3>
            </div>
            <p className="text-sm text-slate-600 max-w-2xl">
              {t("upgrade.soloBannerText")}
            </p>
          </div>
          <Link to="/app/upgrade" className="inline-flex shrink-0">
            <Button variant="primary" size="sm">
              {t("upgrade.soloBannerAction")}
            </Button>
          </Link>
        </Card>
      ) : null}
      <PageHeader title={t("today.title")} subtitle={day} />
      <div className="grid gap-3 sm:grid-cols-3">
        <Stat id="today-net" label={t("today.sales")} value={fmt(s.totals.net)} />
        <Stat id="today-txns" label={t("today.transactions")} value={String(s.totals.txns)} />
        <Stat id="today-owed" label={t("today.owed")} value={fmt(s.utang.owed)} />
        <Stat id="today-cash" label={t("today.cash")} value={fmt(s.totals.cash)} />
        <Stat id="today-ewallet" label={t("today.ewallet")} value={fmt(s.totals.ewallet)} />
        <Stat id="today-card" label={t("today.card")} value={fmt(s.totals.card ?? 0)} />
        <Stat id="today-expenses" label={t("today.expenses")} value={fmt(s.expenses.total)} />
      </div>
      <Card data-testid="today-cash-after-expenses">
        <div className="text-xs text-slate-500">{t("today.cashAfterExpenses")}</div>
        <div className="mt-1 text-xl font-semibold">{fmt(cashLeft)}</div>
      </Card>
      <Card>
        <h3 className="mb-2 font-medium">{t("today.topItems")}</h3>
        {s.top_items.length === 0 ? (
          <EmptyState title={t("today.noSales")} />
        ) : (
          <ul className="grid gap-1 text-sm">
            {s.top_items.slice(0, 5).map((i) => (
              <li key={i.variant_id} className="flex justify-between gap-2">
                <span>
                  {i.name} × {i.qty}
                </span>
                <span>{fmt(i.revenue)}</span>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </>
  );
}
