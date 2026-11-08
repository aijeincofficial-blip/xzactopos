import { useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Alert, Badge, Button, Card, Input } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { fetchRecentSales, fetchSaleDetail, voidSale } from "../lib/sell-api.ts";

/** Sales (Solo web): the store's latest sales, each as a receipt, with cancel (void) for those allowed to. */
export function SalesPage() {
  const { t, i18n } = useTranslation("admin");
  const msg = useErrorMessage();
  const { access, can } = useSession();
  const qc = useQueryClient();
  const currency = access.tenant.base_currency;
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);
  const when = (iso: string) =>
    new Intl.DateTimeFormat(i18n.language, { dateStyle: "medium", timeStyle: "short", timeZone: access.tenant.timezone }).format(new Date(iso));

  const store = access.locations.find((l) => l.type === "store" && can("sale.create", l.id));
  const [openId, setOpenId] = useState<string | null>(null);
  const [asking, setAsking] = useState(false);
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);

  const list = useQuery({
    queryKey: ["sales", store?.id],
    queryFn: () => fetchRecentSales(store?.id ?? ""),
    enabled: Boolean(store),
    refetchInterval: 120_000,
  });
  const detail = useQuery({ queryKey: ["sale", openId], queryFn: () => fetchSaleDetail(openId ?? ""), enabled: openId !== null });

  const cancel = useMutation({
    mutationFn: () => voidSale(openId ?? "", reason),
    onSuccess: async () => {
      setAsking(false);
      setReason("");
      setError(null);
      await Promise.all([
        qc.invalidateQueries({ queryKey: ["sales"] }),
        qc.invalidateQueries({ queryKey: ["sale", openId] }),
        qc.invalidateQueries({ queryKey: ["day-summary"] }),
      ]);
    },
    onError: (e) => setError(msg(e)),
  });

  if (!store) {
    return (
      <Card>
        <p>{t("sell.noStore")}</p>
      </Card>
    );
  }

  if (openId !== null) {
    const d = detail.data;
    return (
      <div className="grid max-w-xl gap-3">
        <div>
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              setOpenId(null);
              setAsking(false);
              setError(null);
            }}
          >
            {t("sales.back")}
          </Button>
        </div>
        {detail.isPending ? <Card>{t("sales.loading")}</Card> : null}
        {detail.isError ? <Alert>{t("sales.error")}</Alert> : null}
        {d ? (
          <Card className="grid gap-3" data-testid="sale-detail">
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="font-mono text-lg font-semibold">{d.sale.sale_no ?? d.sale.local_no}</h2>
              <Badge tone={d.sale.status === "voided" ? "warn" : "good"}>{t(`sales.status.${d.sale.status}`)}</Badge>
              <span className="ml-auto text-sm text-slate-500">{when(d.sale.sold_at)}</span>
            </div>
            {d.customerName ? (
              <div className="text-sm">
                {t("sell.customer")}: <strong>{d.customerName}</strong>
              </div>
            ) : null}
            <ul className="grid gap-1 text-sm">
              {d.items.map((i, k) => (
                <li key={k} className="flex justify-between gap-2">
                  <span>
                    {i.product_name} × {i.qty}
                  </span>
                  <span>{fmt(i.line_total)}</span>
                </li>
              ))}
            </ul>
            <div className="grid gap-1 border-t border-slate-200 pt-2 text-sm">
              <div className="flex justify-between">
                <span>{t("sell.subtotal")}</span>
                <span>{fmt(d.sale.subtotal)}</span>
              </div>
              {d.sale.discount > 0 ? (
                <div className="flex justify-between">
                  <span>{t("sell.discount")}</span>
                  <span>-{fmt(d.sale.discount)}</span>
                </div>
              ) : null}
              <div className="flex justify-between text-base font-semibold">
                <span>{t("sell.total")}</span>
                <span>{fmt(d.sale.total)}</span>
              </div>
              {d.payments.map((p, k) => (
                <div key={k} className="flex justify-between text-slate-600">
                  <span>{p.method === "ewallet" && p.wallet ? `${t("sell.ewallet")} (${t(`sell.wallets.${p.wallet as "gcash" | "maya" | "other"}`)})` : t(`sell.${p.method as "cash" | "ewallet" | "utang"}`)}</span>
                  <span>{fmt(p.amount)}</span>
                </div>
              ))}
            </div>

            {d.sale.status === "completed" && can("sale.void", d.sale.location_id) ? (
              asking ? (
                <div className="grid gap-2 rounded-md border border-red-200 p-3">
                  <p className="text-sm">{t("sales.voidWarning")}</p>
                  <Input data-testid="void-reason" placeholder={t("sales.reason")} value={reason} maxLength={200} onChange={(e) => setReason(e.target.value)} />
                  {error ? <Alert>{error}</Alert> : null}
                  <div className="flex gap-2">
                    <Button variant="danger" data-testid="void-confirm" disabled={cancel.isPending} onClick={() => cancel.mutate()}>
                      {t("sales.confirmVoid")}
                    </Button>
                    <Button variant="ghost" onClick={() => setAsking(false)}>
                      {t("sell.cancel")}
                    </Button>
                  </div>
                </div>
              ) : (
                <Button variant="outline" data-testid="void-start" onClick={() => setAsking(true)}>
                  {t("sales.voidSale")}
                </Button>
              )
            ) : null}
          </Card>
        ) : null}
      </div>
    );
  }

  return (
    <div className="grid max-w-2xl gap-3">
      <h2 className="text-lg font-semibold">{t("sales.title")}</h2>
      {list.isPending ? <Card>{t("sales.loading")}</Card> : null}
      {list.isError ? <Alert>{t("sales.error")}</Alert> : null}
      {list.data && list.data.length === 0 ? <Card>{t("sales.empty")}</Card> : null}
      <ul className="grid gap-2">
        {(list.data ?? []).map((s) => (
          <li key={s.id}>
            <button
              type="button"
              data-testid={`sale-${s.sale_no ?? s.local_no}`}
              onClick={() => setOpenId(s.id)}
              className="flex w-full items-center justify-between gap-2 rounded-md border border-slate-200 bg-white px-3 py-2 text-left text-sm hover:bg-slate-50"
            >
              <span>
                <span className="block font-mono font-medium">{s.sale_no ?? s.local_no}</span>
                <span className="text-xs text-slate-500">{when(s.sold_at)}</span>
              </span>
              <span className="flex items-center gap-2">
                {s.status === "voided" ? <Badge tone="warn">{t("sales.status.voided")}</Badge> : null}
                <span className="font-semibold">{fmt(s.total)}</span>
              </span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
