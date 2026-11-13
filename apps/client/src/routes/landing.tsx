import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { Link } from "@tanstack/react-router";
import {
  ArrowRight,
  CheckCircle2,
  CreditCard,
  Layers,
  ShieldCheck,
  ShoppingBag,
  Smartphone,
  Sparkles,
  Store,
  Truck,
  Warehouse,
  WifiOff,
} from "lucide-react";
import { hasSession } from "../lib/session.tsx";
import { Badge, Button, Card } from "../components/ui.tsx";
import { LanguageSelect } from "../components/LanguageSelect.tsx";
import { ThemeCycleButton } from "./public.tsx";

export function LandingPage() {
  const { t } = useTranslation("auth");
  const [signedIn, setSignedIn] = useState(false);

  useEffect(() => {
    let active = true;
    void hasSession().then((ok) => {
      if (active) setSignedIn(ok);
    });
    return () => {
      active = false;
    };
  }, []);

  const posTarget = signedIn ? "/app" : "/login";
  const posLabel = signedIn ? t("landing.goToPos") : t("landing.openPos");

  const stats = [
    { icon: WifiOff, title: t("landing.stats.offline"), sub: t("landing.stats.offlineSub") },
    { icon: ShieldCheck, title: t("landing.stats.math"), sub: t("landing.stats.mathSub") },
    { icon: Warehouse, title: t("landing.stats.warehouses"), sub: t("landing.stats.warehousesSub") },
    { icon: Smartphone, title: t("landing.stats.platforms"), sub: t("landing.stats.platformsSub") },
  ];

  const features = [
    {
      icon: CreditCard,
      title: t("landing.features.posTitle"),
      body: t("landing.features.posBody"),
    },
    {
      icon: Warehouse,
      title: t("landing.features.warehouseTitle"),
      body: t("landing.features.warehouseBody"),
    },
    {
      icon: Store,
      title: t("landing.features.utangTitle"),
      body: t("landing.features.utangBody"),
    },
    {
      icon: Layers,
      title: t("landing.features.syncTitle"),
      body: t("landing.features.syncBody"),
    },
  ];

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      <header className="sticky top-0 z-20 border-b border-slate-200/80 bg-white/85 backdrop-blur-md">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3 sm:px-6">
          <Link to="/" className="flex items-center gap-3 text-slate-900">
            <img
              src="/logo_squircle.png"
              alt="XZACTO POS"
              width={38}
              height={38}
              className="h-9.5 w-9.5 rounded-xl border border-slate-200/90 object-cover shadow-xs"
            />
            <div className="flex items-center gap-2">
              <span className="text-lg font-bold tracking-tight text-slate-900">XZACTO</span>
              <Badge tone="neutral">POS</Badge>
            </div>
          </Link>

          <div className="flex items-center gap-2 [&_select]:h-8 [&_select]:text-xs">
            <ThemeCycleButton />
            <LanguageSelect />
            <Link
              to="/warehouse"
              className="hidden rounded-lg px-2.5 py-1.5 text-sm font-medium text-slate-600 transition hover:bg-slate-100 hover:text-slate-900 sm:inline-flex sm:items-center sm:gap-1.5"
              data-testid="landing-nav-warehouse"
            >
              <Warehouse size={15} aria-hidden />
              {t("landing.warehousePortal")}
            </Link>
            <Link to={posTarget} data-testid="landing-nav-pos">
              <Button size="sm" className="shadow-xs">
                {posLabel}
                <ArrowRight size={15} className="ml-1.5" aria-hidden />
              </Button>
            </Link>
          </div>
        </div>
      </header>

      <div className="border-b border-slate-200/70 bg-gradient-to-b from-brand-50/70 via-slate-50 to-slate-50">
        <section className="mx-auto grid max-w-6xl items-center gap-10 px-4 py-12 sm:px-6 sm:py-16 lg:grid-cols-[1.15fr_0.85fr] lg:gap-12">
          <div className="grid gap-5">
            <div className="inline-flex w-fit items-center gap-2 rounded-full border border-brand-200 bg-white px-3 py-1 text-xs font-semibold text-brand-700 shadow-2xs">
              <Sparkles size={13} aria-hidden />
              <span>{t("landing.eyebrow")}</span>
            </div>

            <h1 className="text-3xl font-extrabold tracking-tight text-slate-900 sm:text-5xl sm:leading-[1.12]">
              {t("landing.heroTitle")}
            </h1>

            <p className="max-w-xl text-base leading-relaxed text-slate-600 sm:text-lg">
              {t("landing.heroSubtitle")}
            </p>

            <div className="flex flex-wrap items-center gap-3 pt-1">
              <Link to={posTarget} data-testid="landing-pos-btn">
                <Button className="h-11 px-5 text-base shadow-sm">
                  <ShoppingBag size={18} className="mr-2" aria-hidden />
                  {posLabel}
                </Button>
              </Link>
              <Link to="/signup" data-testid="landing-signup-btn">
                <Button variant="outline" className="h-11 bg-white px-5 text-base">
                  {t("landing.startSolo")}
                </Button>
              </Link>
              <Link
                to="/warehouse"
                className="inline-flex items-center gap-1.5 rounded-lg px-3 py-2 text-sm font-medium text-slate-600 transition hover:bg-white hover:text-slate-900"
                data-testid="landing-warehouse-btn"
              >
                <Warehouse size={16} aria-hidden />
                {t("landing.warehousePortal")}
              </Link>
            </div>
          </div>

          <div className="grid gap-3">
            <Card className="grid gap-4 border-slate-200/90 bg-white p-5 shadow-md">
              <div className="flex items-center justify-between gap-2 border-b border-slate-100 pb-3">
                <div className="flex items-center gap-2.5">
                  <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-brand-600 text-white">
                    <Store size={16} aria-hidden />
                  </div>
                  <div className="text-sm font-semibold text-slate-900">
                    {t("landing.preview.counterTitle")}
                  </div>
                </div>
                <div className="flex items-center gap-1.5">
                  <Badge tone="good">{t("landing.preview.shiftOpen")}</Badge>
                  <Badge tone="neutral">{t("landing.preview.synced")}</Badge>
                </div>
              </div>

              <div className="grid gap-2 text-sm">
                <div className="flex items-center justify-between rounded-lg bg-slate-50 px-3 py-2">
                  <div>
                    <div className="font-medium text-slate-900">{t("landing.preview.item1")}</div>
                    <div className="text-xs text-slate-500">1 × ₱1,550.00</div>
                  </div>
                  <span className="font-semibold tabular-nums text-slate-900">₱1,550.00</span>
                </div>
                <div className="flex items-center justify-between rounded-lg bg-slate-50 px-3 py-2">
                  <div>
                    <div className="font-medium text-slate-900">{t("landing.preview.item2")}</div>
                    <div className="text-xs text-slate-500">2 × ₱110.00</div>
                  </div>
                  <span className="font-semibold tabular-nums text-slate-900">₱220.00</span>
                </div>
              </div>

              <div className="flex items-center justify-between border-t border-slate-100 pt-3">
                <div>
                  <div className="text-xs font-medium text-slate-500">{t("landing.preview.totalLabel")}</div>
                  <div className="text-xl font-bold tabular-nums text-slate-900">₱1,770.00</div>
                </div>
                <Badge tone="neutral">{t("landing.preview.splitLabel")}</Badge>
              </div>

              <Link to={posTarget} data-testid="landing-card-pos-btn">
                <Button className="w-full justify-between">
                  <span>{t("landing.preview.completeBtn")}</span>
                  <ArrowRight size={16} aria-hidden />
                </Button>
              </Link>
            </Card>

            <div className="flex items-center justify-between gap-3 rounded-xl border border-amber-200 bg-amber-50/80 px-4 py-3 text-xs shadow-xs">
              <div className="flex items-start gap-2.5">
                <Truck size={16} className="mt-0.5 shrink-0 text-amber-700" aria-hidden />
                <div>
                  <div className="font-semibold text-amber-900">{t("landing.preview.whTitle")}</div>
                  <div className="text-amber-800">{t("landing.preview.whSub")}</div>
                </div>
              </div>
              <Link
                to={posTarget}
                className="shrink-0 rounded-md bg-white px-2.5 py-1 font-semibold text-amber-900 shadow-2xs ring-1 ring-amber-200 hover:bg-amber-100"
              >
                {t("landing.preview.whAction")}
              </Link>
            </div>
          </div>
        </section>
      </div>

      <main className="mx-auto grid max-w-6xl gap-14 px-4 py-12 sm:px-6 sm:py-14">
        <section className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {stats.map((s) => {
            const Icon = s.icon;
            return (
              <div
                key={s.title}
                className="flex items-center gap-3 rounded-xl border border-slate-200/80 bg-white px-4 py-3.5 shadow-2xs"
              >
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-brand-50 text-brand-600">
                  <Icon size={18} aria-hidden />
                </div>
                <div className="min-w-0">
                  <div className="truncate text-sm font-semibold text-slate-900">{s.title}</div>
                  <div className="truncate text-xs text-slate-500">{s.sub}</div>
                </div>
              </div>
            );
          })}
        </section>

        <section className="grid gap-6">
          <div className="grid gap-1.5">
            <h2 className="text-2xl font-bold tracking-tight text-slate-900 sm:text-3xl">
              {t("landing.featuresTitle")}
            </h2>
          </div>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {features.map((f) => {
              const Icon = f.icon;
              return (
                <Card
                  key={f.title}
                  className="grid content-start gap-3 border-slate-200/90 bg-white p-5 transition hover:border-brand-200 hover:shadow-md"
                >
                  <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-50 text-brand-600">
                    <Icon size={20} aria-hidden />
                  </div>
                  <h3 className="text-base font-semibold text-slate-900">{f.title}</h3>
                  <p className="text-sm leading-relaxed text-slate-600">{f.body}</p>
                </Card>
              );
            })}
          </div>
        </section>

        <section className="grid gap-6">
          <div className="grid gap-1.5">
            <h2 className="text-2xl font-bold tracking-tight text-slate-900 sm:text-3xl">
              {t("landing.plansTitle")}
            </h2>
            <p className="max-w-2xl text-sm text-slate-600 sm:text-base">
              {t("landing.plansSubtitle")}
            </p>
          </div>
          <div className="grid gap-5 md:grid-cols-2">
            <Card className="grid content-between gap-6 border-slate-200/90 bg-white p-6">
              <div className="grid gap-3">
                <div>
                  <Badge tone="neutral">{t("landing.plans.soloBadge")}</Badge>
                </div>
                <h3 className="text-xl font-bold text-slate-900">{t("landing.plans.soloTitle")}</h3>
                <p className="text-sm leading-relaxed text-slate-600">{t("landing.plans.soloBody")}</p>
                <ul className="grid gap-2 pt-1 text-sm text-slate-700">
                  {[
                    t("landing.plans.soloBullet1"),
                    t("landing.plans.soloBullet2"),
                    t("landing.plans.soloBullet3"),
                  ].map((item) => (
                    <li key={item} className="flex items-start gap-2">
                      <CheckCircle2 size={16} className="mt-0.5 shrink-0 text-emerald-600" aria-hidden />
                      <span>{item}</span>
                    </li>
                  ))}
                </ul>
              </div>
              <div>
                <Link to="/signup">
                  <Button variant="outline" className="w-full sm:w-auto">
                    {t("landing.plans.soloCta")}
                  </Button>
                </Link>
              </div>
            </Card>

            <Card className="grid content-between gap-6 border-brand-200 bg-white p-6 ring-1 ring-brand-100">
              <div className="grid gap-3">
                <div>
                  <Badge tone="good">{t("landing.plans.fullBadge")}</Badge>
                </div>
                <h3 className="text-xl font-bold text-slate-900">{t("landing.plans.fullTitle")}</h3>
                <p className="text-sm leading-relaxed text-slate-600">{t("landing.plans.fullBody")}</p>
                <ul className="grid gap-2 pt-1 text-sm text-slate-700">
                  {[
                    t("landing.plans.fullBullet1"),
                    t("landing.plans.fullBullet2"),
                    t("landing.plans.fullBullet3"),
                  ].map((item) => (
                    <li key={item} className="flex items-start gap-2">
                      <CheckCircle2 size={16} className="mt-0.5 shrink-0 text-brand-600" aria-hidden />
                      <span>{item}</span>
                    </li>
                  ))}
                </ul>
              </div>
              <div className="flex flex-wrap gap-3">
                <Link to={posTarget}>
                  <Button>{posLabel}</Button>
                </Link>
                <Link to="/warehouse">
                  <Button variant="outline">{t("landing.warehousePortal")}</Button>
                </Link>
              </div>
            </Card>
          </div>
        </section>

        <section className="rounded-2xl bg-brand-600 px-6 py-8 text-white shadow-md sm:flex sm:items-center sm:justify-between sm:gap-6 sm:px-8 sm:py-10">
          <div className="grid gap-1.5">
            <h2 className="text-xl font-bold tracking-tight text-white sm:text-2xl">
              {t("landing.ctaBanner.title")}
            </h2>
            <p className="text-sm text-brand-100 sm:text-base">
              {t("landing.ctaBanner.subtitle")}
            </p>
          </div>
          <div className="mt-5 flex flex-wrap gap-3 sm:mt-0 sm:shrink-0">
            <Link to={posTarget}>
              <Button className="bg-white text-brand-700 hover:bg-brand-50">
                {posLabel}
                <ArrowRight size={16} className="ml-1.5" aria-hidden />
              </Button>
            </Link>
            <Link to="/signup">
              <Button variant="outline" className="border-brand-300 bg-transparent text-white hover:bg-brand-700">
                {t("landing.startSolo")}
              </Button>
            </Link>
          </div>
        </section>
      </main>

      <footer className="border-t border-slate-200/80 bg-white">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 px-4 py-6 text-sm text-slate-500 sm:px-6">
          <span>{t("landing.footerNote")}</span>
          <div className="flex items-center gap-4">
            <Link to={posTarget} className="hover:text-slate-900">
              {posLabel}
            </Link>
            <Link to="/warehouse" className="hover:text-slate-900">
              {t("landing.warehousePortal")}
            </Link>
            <Link to="/signup" className="hover:text-slate-900">
              {t("landing.startSolo")}
            </Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
