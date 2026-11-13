import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { Link } from "@tanstack/react-router";
import { ArrowRight, CheckCircle2, CreditCard, ShoppingBag, Smartphone, Store, Warehouse } from "lucide-react";
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
      icon: Smartphone,
      title: t("landing.features.syncTitle"),
      body: t("landing.features.syncBody"),
    },
  ];

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      <header className="sticky top-0 z-20 border-b border-slate-200/80 bg-white/90 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3 sm:px-6">
          <Link to="/" className="flex items-center gap-3 text-slate-900">
            <img
              src="/logo_squircle.png"
              alt="XZACTO POS"
              width={36}
              height={36}
              className="h-9 w-9 rounded-xl border border-slate-200/90 object-cover shadow-xs"
            />
            <div className="flex items-center gap-2">
              <span className="text-base font-semibold tracking-tight text-slate-900">XZACTO</span>
              <Badge tone="neutral">POS</Badge>
            </div>
          </Link>

          <div className="flex items-center gap-2 [&_select]:h-8 [&_select]:text-xs">
            <ThemeCycleButton />
            <LanguageSelect />
            <Link
              to="/warehouse"
              className="hidden text-sm font-medium text-slate-600 hover:text-slate-900 sm:inline-block sm:px-2"
              data-testid="landing-nav-warehouse"
            >
              {t("landing.warehousePortal")}
            </Link>
            <Link to={posTarget} data-testid="landing-nav-pos">
              <Button size="sm">
                {posLabel}
                <ArrowRight size={15} className="ml-1.5" aria-hidden />
              </Button>
            </Link>
          </div>
        </div>
      </header>

      <main className="mx-auto grid max-w-6xl gap-14 px-4 py-12 sm:px-6 sm:py-16">
        <section className="grid items-center gap-8 lg:grid-cols-[1.2fr_0.8fr]">
          <div className="grid gap-5">
            <div>
              <Badge tone="good">{t("landing.eyebrow")}</Badge>
            </div>
            <h1 className="text-3xl font-bold tracking-tight text-slate-900 sm:text-5xl sm:leading-tight">
              {t("landing.heroTitle")}
            </h1>
            <p className="max-w-2xl text-base text-slate-600 sm:text-lg">
              {t("landing.heroSubtitle")}
            </p>
            <div className="flex flex-wrap items-center gap-3 pt-1">
              <Link to={posTarget} data-testid="landing-pos-btn">
                <Button className="h-11 px-5 text-base">
                  <ShoppingBag size={18} className="mr-2" aria-hidden />
                  {posLabel}
                </Button>
              </Link>
              <Link to="/signup" data-testid="landing-signup-btn">
                <Button variant="outline" className="h-11 px-5 text-base">
                  {t("landing.startSolo")}
                </Button>
              </Link>
              <Link
                to="/warehouse"
                className="inline-flex items-center gap-1.5 px-2 py-2 text-sm font-medium text-slate-600 hover:text-slate-900"
                data-testid="landing-warehouse-btn"
              >
                <Warehouse size={16} aria-hidden />
                {t("landing.warehousePortal")}
              </Link>
            </div>
          </div>

          <Card className="grid gap-4 border-slate-200/90 bg-white p-6 shadow-sm">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div className="flex items-center gap-2.5">
                <img
                  src="/logo_squircle.png"
                  alt="XZACTO"
                  width={32}
                  height={32}
                  className="h-8 w-8 rounded-lg object-cover"
                />
                <div>
                  <div className="text-sm font-semibold text-slate-900">XZACTO POS</div>
                  <div className="text-xs text-slate-500">{t("brand.tagline")}</div>
                </div>
              </div>
              <Badge tone="good">Online & Offline</Badge>
            </div>
            <ul className="grid gap-3 text-sm text-slate-700">
              <li className="flex items-start gap-2.5">
                <CheckCircle2 size={17} className="mt-0.5 shrink-0 text-emerald-600" aria-hidden />
                <span>{t("landing.features.posTitle")}</span>
              </li>
              <li className="flex items-start gap-2.5">
                <CheckCircle2 size={17} className="mt-0.5 shrink-0 text-emerald-600" aria-hidden />
                <span>{t("landing.features.warehouseTitle")}</span>
              </li>
              <li className="flex items-start gap-2.5">
                <CheckCircle2 size={17} className="mt-0.5 shrink-0 text-emerald-600" aria-hidden />
                <span>{t("landing.features.utangTitle")}</span>
              </li>
              <li className="flex items-start gap-2.5">
                <CheckCircle2 size={17} className="mt-0.5 shrink-0 text-emerald-600" aria-hidden />
                <span>{t("landing.features.syncTitle")}</span>
              </li>
            </ul>
            <Link to={posTarget} className="pt-1">
              <Button className="w-full" data-testid="landing-card-pos-btn">
                {posLabel}
                <ArrowRight size={16} className="ml-2" aria-hidden />
              </Button>
            </Link>
          </Card>
        </section>

        <section className="grid gap-6">
          <h2 className="text-xl font-semibold tracking-tight text-slate-900 sm:text-2xl">
            {t("landing.featuresTitle")}
          </h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {features.map((f) => {
              const Icon = f.icon;
              return (
                <Card key={f.title} className="grid content-start gap-3 p-5">
                  <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-brand-50 text-brand-600">
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
          <h2 className="text-xl font-semibold tracking-tight text-slate-900 sm:text-2xl">
            {t("landing.plansTitle")}
          </h2>
          <div className="grid gap-4 md:grid-cols-2">
            <Card className="grid content-between gap-5 p-6">
              <div className="grid gap-2.5">
                <div>
                  <Badge tone="neutral">{t("landing.plans.soloBadge")}</Badge>
                </div>
                <h3 className="text-lg font-semibold text-slate-900">{t("landing.plans.soloTitle")}</h3>
                <p className="text-sm leading-relaxed text-slate-600">{t("landing.plans.soloBody")}</p>
              </div>
              <div>
                <Link to="/signup">
                  <Button variant="outline">{t("landing.plans.soloCta")}</Button>
                </Link>
              </div>
            </Card>

            <Card className="grid content-between gap-5 border-brand-200 p-6">
              <div className="grid gap-2.5">
                <div>
                  <Badge tone="good">{t("landing.plans.fullBadge")}</Badge>
                </div>
                <h3 className="text-lg font-semibold text-slate-900">{t("landing.plans.fullTitle")}</h3>
                <p className="text-sm leading-relaxed text-slate-600">{t("landing.plans.fullBody")}</p>
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
