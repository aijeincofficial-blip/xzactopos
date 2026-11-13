import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { Link } from "@tanstack/react-router";
import {
  ArrowRight,
  BarChart3,
  CheckCircle2,
  ChevronDown,
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

type ShowcaseTab = "pos" | "warehouse" | "reports";

export function LandingPage() {
  const { t } = useTranslation("auth");
  const [signedIn, setSignedIn] = useState(false);
  const [showcase, setShowcase] = useState<ShowcaseTab>("pos");
  const [openFaq, setOpenFaq] = useState<number>(0);

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

  const industries = [
    {
      icon: Store,
      badge: t("landing.industries.card1Badge"),
      title: t("landing.industries.card1Title"),
      body: t("landing.industries.card1Body"),
    },
    {
      icon: ShoppingBag,
      badge: t("landing.industries.card2Badge"),
      title: t("landing.industries.card2Title"),
      body: t("landing.industries.card2Body"),
    },
    {
      icon: Warehouse,
      badge: t("landing.industries.card3Badge"),
      title: t("landing.industries.card3Title"),
      body: t("landing.industries.card3Body"),
    },
  ];

  const features = [
    {
      icon: CreditCard,
      title: t("landing.features.posTitle"),
      body: t("landing.features.posBody"),
    },
    {
      icon: Truck,
      title: t("landing.features.warehouseTitle"),
      body: t("landing.features.warehouseBody"),
    },
    {
      icon: BarChart3,
      title: t("landing.features.utangTitle"),
      body: t("landing.features.utangBody"),
    },
    {
      icon: Layers,
      title: t("landing.features.syncTitle"),
      body: t("landing.features.syncBody"),
    },
  ];

  const faqs = [
    { q: t("landing.faq.q1"), a: t("landing.faq.a1") },
    { q: t("landing.faq.q2"), a: t("landing.faq.a2") },
    { q: t("landing.faq.q3"), a: t("landing.faq.a3") },
    { q: t("landing.faq.q4"), a: t("landing.faq.a4") },
  ];

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      <header className="sticky top-0 z-30 border-b border-slate-200/80 bg-white/85 backdrop-blur-md">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3 sm:px-6">
          <div className="flex items-center gap-8">
            <Link to="/" className="flex items-center gap-2.5 text-slate-900">
              <img
                src="/logo_squircle.png"
                alt="XZACTO POS"
                width={36}
                height={36}
                className="h-9 w-9 rounded-xl border border-slate-200/90 object-cover shadow-xs"
              />
              <div className="flex items-center gap-2">
                <span className="text-lg font-bold tracking-tight text-slate-900">XZACTO</span>
                <Badge tone="neutral">POS</Badge>
              </div>
            </Link>

            <nav className="hidden items-center gap-6 text-sm font-medium text-slate-600 md:flex">
              <a href="#solutions" className="transition hover:text-slate-900">
                {t("landing.nav.solutions")}
              </a>
              <a href="#features" className="transition hover:text-slate-900">
                {t("landing.nav.features")}
              </a>
              <a href="#pricing" className="transition hover:text-slate-900">
                {t("landing.nav.pricing")}
              </a>
              <a href="#faq" className="transition hover:text-slate-900">
                {t("landing.nav.faq")}
              </a>
            </nav>
          </div>

          <div className="flex items-center gap-2 [&_select]:h-8 [&_select]:text-xs">
            <ThemeCycleButton />
            <LanguageSelect />
            <Link
              to="/warehouse"
              className="hidden rounded-lg px-2.5 py-1.5 text-sm font-medium text-slate-600 transition hover:bg-slate-100 hover:text-slate-900 lg:inline-flex lg:items-center lg:gap-1.5"
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

      <section className="relative overflow-hidden border-b border-slate-200/80 bg-gradient-to-b from-brand-50/80 via-white to-slate-50">
        <div className="mx-auto grid max-w-6xl items-center gap-10 px-4 py-12 sm:px-6 sm:py-16 lg:grid-cols-[1.08fr_0.92fr] lg:gap-12 lg:py-20">
          <div className="grid gap-5">
            <div className="inline-flex w-fit items-center gap-2 rounded-full border border-brand-200 bg-white px-3.5 py-1 text-xs font-semibold text-brand-700 shadow-xs">
              <Sparkles size={13} aria-hidden />
              <span>{t("landing.eyebrow")}</span>
            </div>

            <h1 className="text-4xl font-extrabold tracking-tight text-slate-900 sm:text-5xl sm:leading-[1.08]">
              {t("landing.heroTitle")}
            </h1>

            <p className="max-w-xl text-base leading-relaxed text-slate-600 sm:text-lg">
              {t("landing.heroSubtitle")}
            </p>

            <div className="flex flex-wrap items-center gap-3 pt-1">
              <Link to={posTarget} data-testid="landing-pos-btn">
                <Button className="h-12 px-6 text-base font-semibold shadow-sm">
                  <ShoppingBag size={18} className="mr-2" aria-hidden />
                  {posLabel}
                </Button>
              </Link>
              <Link to="/signup" data-testid="landing-signup-btn">
                <Button variant="outline" className="h-12 bg-white px-5 text-base font-medium">
                  {t("landing.startSolo")}
                </Button>
              </Link>
              <Link
                to="/warehouse"
                className="inline-flex items-center gap-1.5 rounded-lg px-3 py-2 text-sm font-medium text-slate-600 transition hover:bg-slate-100 hover:text-slate-900"
                data-testid="landing-warehouse-btn"
              >
                <Warehouse size={16} aria-hidden />
                {t("landing.warehousePortal")}
              </Link>
            </div>

            <p className="text-xs font-medium text-slate-500">{t("landing.trustNote")}</p>
          </div>

          <div className="rounded-2xl border border-slate-200/90 bg-white shadow-xl">
            <div className="flex items-center justify-between border-b border-slate-100 bg-slate-50/80 px-4 py-2.5 rounded-t-2xl">
              <div className="flex items-center gap-1.5">
                <span className="h-2.5 w-2.5 rounded-full bg-red-400" />
                <span className="h-2.5 w-2.5 rounded-full bg-amber-400" />
                <span className="h-2.5 w-2.5 rounded-full bg-emerald-400" />
              </div>
              <span className="rounded-md bg-white px-3 py-0.5 text-[11px] font-medium text-slate-500 ring-1 ring-slate-200/80">
                pos.xzactopos.app
              </span>
              <Badge tone="good">{t("landing.preview.synced")}</Badge>
            </div>

            <div className="flex gap-1 border-b border-slate-100 bg-slate-50/40 px-3 pt-2.5">
              {(
                [
                  ["pos", t("landing.showcase.tabPos")],
                  ["warehouse", t("landing.showcase.tabWarehouse")],
                  ["reports", t("landing.showcase.tabReports")],
                ] as const
              ).map(([id, label]) => (
                <button
                  key={id}
                  type="button"
                  onClick={() => setShowcase(id)}
                  className={`rounded-t-lg px-3 py-1.5 text-xs font-semibold transition ${
                    showcase === id
                      ? "bg-white text-brand-700 ring-1 ring-b-0 ring-slate-200/80"
                      : "text-slate-500 hover:text-slate-900"
                  }`}
                >
                  {label}
                </button>
              ))}
            </div>

            <div className="grid gap-4 p-5">
              {showcase === "pos" ? (
                <>
                  <div className="flex items-center justify-between gap-2">
                    <div className="flex items-center gap-2">
                      <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-brand-600 text-white">
                        <Store size={15} aria-hidden />
                      </div>
                      <span className="text-sm font-semibold text-slate-900">
                        {t("landing.showcase.posHeader")}
                      </span>
                    </div>
                    <Badge tone="good">{t("landing.preview.shiftOpen")}</Badge>
                  </div>

                  <div className="grid gap-2 text-sm">
                    <div className="flex items-center justify-between rounded-xl bg-slate-50 px-3.5 py-2.5">
                      <div>
                        <div className="font-medium text-slate-900">{t("landing.preview.item1")}</div>
                        <div className="text-xs text-slate-500">1 × ₱1,550.00</div>
                      </div>
                      <span className="font-semibold tabular-nums text-slate-900">₱1,550.00</span>
                    </div>
                    <div className="flex items-center justify-between rounded-xl bg-slate-50 px-3.5 py-2.5">
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
                      <div className="text-2xl font-bold tabular-nums text-slate-900">₱1,770.00</div>
                    </div>
                    <Badge tone="neutral">{t("landing.preview.splitLabel")}</Badge>
                  </div>
                </>
              ) : null}

              {showcase === "warehouse" ? (
                <>
                  <div className="flex items-center justify-between gap-2">
                    <div className="flex items-center gap-2">
                      <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-amber-500 text-white">
                        <Truck size={15} aria-hidden />
                      </div>
                      <span className="text-sm font-semibold text-slate-900">
                        {t("landing.showcase.whHeader")}
                      </span>
                    </div>
                    <Badge tone="warn">2 low</Badge>
                  </div>

                  <div className="grid gap-2.5 text-sm">
                    <div className="flex items-center justify-between gap-3 rounded-xl border border-amber-200/80 bg-amber-50/70 px-3.5 py-2.5">
                      <div className="min-w-0">
                        <div className="truncate font-semibold text-slate-900">
                          {t("landing.showcase.whRow1Title")}
                        </div>
                        <div className="truncate text-xs text-slate-600">{t("landing.showcase.whRow1Sub")}</div>
                      </div>
                      <Badge tone="good">{t("landing.showcase.whRow1Stock")}</Badge>
                    </div>
                    <div className="flex items-center justify-between gap-3 rounded-xl border border-slate-200/80 bg-slate-50 px-3.5 py-2.5">
                      <div className="min-w-0">
                        <div className="truncate font-semibold text-slate-900">
                          {t("landing.showcase.whRow2Title")}
                        </div>
                        <div className="truncate text-xs text-slate-600">{t("landing.showcase.whRow2Sub")}</div>
                      </div>
                      <Badge tone="neutral">{t("landing.showcase.whRow2Stock")}</Badge>
                    </div>
                  </div>
                </>
              ) : null}

              {showcase === "reports" ? (
                <>
                  <div className="flex items-center justify-between gap-2">
                    <div className="flex items-center gap-2">
                      <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-emerald-600 text-white">
                        <BarChart3 size={15} aria-hidden />
                      </div>
                      <span className="text-sm font-semibold text-slate-900">
                        {t("landing.showcase.repHeader")}
                      </span>
                    </div>
                    <Badge tone="good">{t("landing.showcase.repStatus")}</Badge>
                  </div>

                  <div className="grid grid-cols-3 gap-2.5">
                    <div className="rounded-xl bg-slate-50 p-3">
                      <div className="text-[11px] font-medium text-slate-500">
                        {t("landing.showcase.repSales")}
                      </div>
                      <div className="mt-1 text-base font-bold tabular-nums text-slate-900">₱48,920</div>
                    </div>
                    <div className="rounded-xl bg-slate-50 p-3">
                      <div className="text-[11px] font-medium text-slate-500">
                        {t("landing.showcase.repCash")}
                      </div>
                      <div className="mt-1 text-base font-bold tabular-nums text-slate-900">₱31,450</div>
                    </div>
                    <div className="rounded-xl bg-slate-50 p-3">
                      <div className="text-[11px] font-medium text-slate-500">
                        {t("landing.showcase.repUtang")}
                      </div>
                      <div className="mt-1 text-base font-bold tabular-nums text-emerald-700">₱6,200</div>
                    </div>
                  </div>
                </>
              ) : null}

              <Link to={posTarget} data-testid="landing-card-pos-btn">
                <Button className="w-full justify-between">
                  <span>{posLabel}</span>
                  <ArrowRight size={16} aria-hidden />
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </section>

      <main className="mx-auto grid max-w-6xl gap-16 px-4 py-12 sm:px-6 sm:py-16">
        <section className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {stats.map((s) => {
            const Icon = s.icon;
            return (
              <div
                key={s.title}
                className="flex items-center gap-3.5 rounded-xl border border-slate-200/90 bg-white px-4 py-3.5 shadow-2xs"
              >
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-brand-50 text-brand-600">
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

        <section id="solutions" className="grid gap-6 scroll-mt-20">
          <div className="grid gap-2">
            <h2 className="text-2xl font-bold tracking-tight text-slate-900 sm:text-3xl">
              {t("landing.industries.title")}
            </h2>
            <p className="max-w-2xl text-sm text-slate-600 sm:text-base">
              {t("landing.industries.subtitle")}
            </p>
          </div>
          <div className="grid gap-5 md:grid-cols-3">
            {industries.map((item) => {
              const Icon = item.icon;
              return (
                <Card key={item.title} className="grid content-start gap-3.5 border-slate-200/90 bg-white p-6">
                  <div className="flex items-center justify-between">
                    <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-50 text-brand-600">
                      <Icon size={20} aria-hidden />
                    </div>
                    <Badge tone="neutral">{item.badge}</Badge>
                  </div>
                  <h3 className="text-lg font-bold text-slate-900">{item.title}</h3>
                  <p className="text-sm leading-relaxed text-slate-600">{item.body}</p>
                </Card>
              );
            })}
          </div>
        </section>

        <section id="features" className="grid gap-6 scroll-mt-20">
          <h2 className="text-2xl font-bold tracking-tight text-slate-900 sm:text-3xl">
            {t("landing.featuresTitle")}
          </h2>
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

        <section id="pricing" className="grid gap-6 scroll-mt-20">
          <div className="grid gap-2">
            <h2 className="text-2xl font-bold tracking-tight text-slate-900 sm:text-3xl">
              {t("landing.pricing.title")}
            </h2>
            <p className="max-w-2xl text-sm text-slate-600 sm:text-base">
              {t("landing.pricing.subtitle")}
            </p>
          </div>
          <div className="grid gap-5 md:grid-cols-2">
            <Card className="grid content-between gap-6 border-slate-200/90 bg-white p-6 sm:p-7">
              <div className="grid gap-3.5">
                <div className="flex items-center justify-between">
                  <Badge tone="neutral">{t("landing.plans.soloBadge")}</Badge>
                </div>
                <div className="flex items-baseline gap-1.5">
                  <span className="text-3xl font-extrabold text-slate-900">{t("landing.pricing.soloPrice")}</span>
                  <span className="text-sm text-slate-500">{t("landing.pricing.soloPeriod")}</span>
                </div>
                <h3 className="text-xl font-bold text-slate-900">{t("landing.plans.soloTitle")}</h3>
                <p className="text-sm leading-relaxed text-slate-600">{t("landing.plans.soloBody")}</p>
                <ul className="grid gap-2.5 pt-1 text-sm text-slate-700">
                  {[
                    t("landing.plans.soloBullet1"),
                    t("landing.plans.soloBullet2"),
                    t("landing.plans.soloBullet3"),
                  ].map((item) => (
                    <li key={item} className="flex items-start gap-2.5">
                      <CheckCircle2 size={16} className="mt-0.5 shrink-0 text-emerald-600" aria-hidden />
                      <span>{item}</span>
                    </li>
                  ))}
                </ul>
              </div>
              <Link to="/signup">
                <Button variant="outline" className="w-full sm:w-auto">
                  {t("landing.plans.soloCta")}
                </Button>
              </Link>
            </Card>

            <Card className="grid content-between gap-6 border-brand-300 bg-white p-6 ring-2 ring-brand-100 sm:p-7">
              <div className="grid gap-3.5">
                <div className="flex items-center justify-between">
                  <Badge tone="good">{t("landing.plans.fullBadge")}</Badge>
                  <Badge tone="neutral">{t("landing.pricing.popular")}</Badge>
                </div>
                <div className="flex items-baseline gap-1.5">
                  <span className="text-3xl font-extrabold text-slate-900">{t("landing.pricing.fullPrice")}</span>
                  <span className="text-sm text-slate-500">{t("landing.pricing.fullPeriod")}</span>
                </div>
                <h3 className="text-xl font-bold text-slate-900">{t("landing.plans.fullTitle")}</h3>
                <p className="text-sm leading-relaxed text-slate-600">{t("landing.plans.fullBody")}</p>
                <ul className="grid gap-2.5 pt-1 text-sm text-slate-700">
                  {[
                    t("landing.plans.fullBullet1"),
                    t("landing.plans.fullBullet2"),
                    t("landing.plans.fullBullet3"),
                  ].map((item) => (
                    <li key={item} className="flex items-start gap-2.5">
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

        <section id="faq" className="grid gap-6 scroll-mt-20">
          <h2 className="text-2xl font-bold tracking-tight text-slate-900 sm:text-3xl">
            {t("landing.faq.title")}
          </h2>
          <div className="grid gap-3">
            {faqs.map((item, idx) => {
              const open = openFaq === idx;
              return (
                <div
                  key={item.q}
                  className="rounded-xl border border-slate-200/90 bg-white transition hover:border-slate-300"
                >
                  <button
                    type="button"
                    onClick={() => setOpenFaq(open ? -1 : idx)}
                    className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left"
                  >
                    <span className="text-sm font-semibold text-slate-900 sm:text-base">{item.q}</span>
                    <ChevronDown
                      size={18}
                      className={`shrink-0 text-slate-500 transition-transform ${open ? "rotate-180" : ""}`}
                      aria-hidden
                    />
                  </button>
                  {open ? (
                    <div className="border-t border-slate-100 px-5 py-3.5 text-sm leading-relaxed text-slate-600">
                      {item.a}
                    </div>
                  ) : null}
                </div>
              );
            })}
          </div>
        </section>

        <section className="rounded-2xl bg-brand-600 px-6 py-8 text-white shadow-lg sm:flex sm:items-center sm:justify-between sm:gap-6 sm:px-9 sm:py-10">
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
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 px-4 py-7 text-sm text-slate-500 sm:px-6">
          <div className="flex items-center gap-2.5">
            <img
              src="/logo_squircle.png"
              alt="XZACTO POS"
              width={24}
              height={24}
              className="h-6 w-6 rounded-md object-cover"
            />
            <span>{t("landing.footerNote")}</span>
          </div>
          <div className="flex flex-wrap items-center gap-5 font-medium">
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
