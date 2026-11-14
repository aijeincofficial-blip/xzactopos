import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { Link } from "@tanstack/react-router";
import {
  ArrowRight,
  Check,
  CreditCard,
  ShoppingBag,
  Warehouse,
  WifiOff,
} from "lucide-react";
import { hasStoredSessionHint } from "../lib/session-hint.ts";
import { cn } from "../lib/utils.ts";
import { LanguageSelect } from "../components/LanguageSelect.tsx";
import { GHOST_BUTTON_CLASSES, LIME_BUTTON_CLASSES } from "../ui/LimeButton.tsx";
import { MoneyText } from "../ui/MoneyText.tsx";
import { Receipt, ReceiptDash } from "../ui/Receipt.tsx";

export function LandingPage() {
  const { t } = useTranslation("auth");
  const [signedIn, setSignedIn] = useState(false);

  useEffect(() => {
    if (!hasStoredSessionHint()) return;
    let active = true;
    void import("../lib/session.tsx")
      .then(({ hasSession }) => hasSession())
      .then((ok) => {
        if (active) setSignedIn(ok);
      });
    return () => {
      active = false;
    };
  }, []);

  const posTarget = signedIn ? "/app" : "/login";
  const posLabel = signedIn ? t("landing.goToPos") : t("landing.openPos");
  const marqueeText = t("landing.marqueeItems");

  const features = [
    {
      num: "01",
      icon: ShoppingBag,
      title: t("landing.features.posTitle"),
      body: t("landing.features.posBody"),
    },
    {
      num: "02",
      icon: Warehouse,
      title: t("landing.features.warehouseTitle"),
      body: t("landing.features.warehouseBody"),
    },
    {
      num: "03",
      icon: CreditCard,
      title: t("landing.features.utangTitle"),
      body: t("landing.features.utangBody"),
    },
    {
      num: "04",
      icon: WifiOff,
      title: t("landing.features.syncTitle"),
      body: t("landing.features.syncBody"),
    },
  ];

  const steps = [
    {
      num: "01",
      title: t("landing.howSteps.step1Title"),
      body: t("landing.howSteps.step1Body"),
    },
    {
      num: "02",
      title: t("landing.howSteps.step2Title"),
      body: t("landing.howSteps.step2Body"),
    },
    {
      num: "03",
      title: t("landing.howSteps.step3Title"),
      body: t("landing.howSteps.step3Body"),
    },
  ];

  const pricingBullets = [
    t("landing.pricing.bullet1"),
    t("landing.pricing.bullet2"),
    t("landing.pricing.bullet3"),
  ];

  return (
    <div className="min-h-screen w-full max-w-full overflow-x-hidden bg-ink text-text-on-dark">
      {/* 1. Navigation */}
      <header className="border-b-[1.5px] border-ink-line bg-ink">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-4 sm:px-8">
          <Link to="/" className="inline-flex min-h-[44px] shrink-0 items-center">
            <img
              src="/brand/xzacto-logo-on-dark.svg"
              alt="xzacto"
              width={132}
              height={36}
              className="h-8 w-auto sm:h-9"
            />
          </Link>

          <nav
            aria-label="Landing sections"
            className="hidden items-center gap-7 text-sm font-medium text-muted-on-dark lg:flex"
          >
            <a href="#features" className="transition-colors hover:text-lime">
              {t("landing.nav.features")}
            </a>
            <a href="#how" className="transition-colors hover:text-lime">
              {t("landing.nav.solutions")}
            </a>
            <a href="#pricing" className="transition-colors hover:text-lime">
              {t("landing.nav.pricing")}
            </a>
            <Link to="/warehouse" className="transition-colors hover:text-lime">
              {t("landing.nav.faq")}
            </Link>
          </nav>

          <div className="flex flex-wrap items-center gap-2.5 sm:gap-3">
            <div className="[&_select]:min-h-[44px] [&_select]:rounded-full [&_select]:border-[1.5px] [&_select]:border-ink-line-2 [&_select]:bg-ink-2 [&_select]:px-3.5 [&_select]:py-2 [&_select]:text-sm [&_select]:font-medium [&_select]:text-text-on-dark">
              <LanguageSelect />
            </div>
            <Link
              to={posTarget}
              data-testid="landing-nav-pos"
              className={cn(LIME_BUTTON_CLASSES, "hidden px-5 py-2.5 text-sm whitespace-nowrap sm:inline-flex")}
            >
              <span>{posLabel}</span>
              <ArrowRight size={16} strokeWidth={2} aria-hidden />
            </Link>
          </div>
        </div>
      </header>

      <main>
      {/* 2. Asymmetric Hero (--ink + tilted paper receipt) */}
      <section className="mx-auto max-w-6xl px-4 pt-10 pb-14 sm:px-8 sm:pt-12 sm:pb-16 lg:pt-16 lg:pb-24">
        <div className="grid grid-cols-1 items-center gap-12 lg:grid-cols-12">
          <div className="min-w-0 space-y-6 lg:col-span-7">
            <div className="inline-flex max-w-full flex-wrap items-center gap-2.5 font-mono text-xs font-semibold tracking-[0.08em] text-lime uppercase">
              <span className="h-2 w-2 shrink-0 rounded-full bg-lime" aria-hidden />
              <span className="min-w-0 break-words">{t("landing.eyebrow")}</span>
            </div>

            <h1 className="font-display text-[clamp(2.25rem,5.4vw,4.5rem)] leading-[1.02] font-extrabold tracking-[-0.03em] text-text-on-dark">
              <span className="block">{t("landing.heroLine1")}</span>
              <span className="block">{t("landing.heroLine2")}</span>
              <span className="block text-lime">{t("landing.heroLine3")}</span>
            </h1>

            <p className="max-w-xl text-base leading-relaxed text-muted-on-dark sm:text-lg">
              {t("landing.heroSubtitle")}
            </p>

            <div className="flex flex-wrap items-center gap-3 pt-2">
              <Link
                to={posTarget}
                data-testid="landing-pos-btn"
                className={cn(LIME_BUTTON_CLASSES, "whitespace-nowrap")}
              >
                <span>{posLabel}</span>
                <ArrowRight size={17} strokeWidth={2} aria-hidden />
              </Link>
              <Link
                to="/signup"
                data-testid="landing-signup-btn"
                className={cn(GHOST_BUTTON_CLASSES, "whitespace-nowrap")}
              >
                <span>{t("landing.startSolo")}</span>
              </Link>
              <Link
                to="/warehouse"
                data-testid="landing-warehouse-btn"
                className="inline-flex min-h-[44px] items-center gap-2 rounded-full px-3 text-sm font-medium text-muted-on-dark underline-offset-4 transition-colors hover:text-lime hover:underline"
              >
                <Warehouse size={16} strokeWidth={1.75} aria-hidden />
                <span>{t("landing.warehousePortal")}</span>
              </Link>
            </div>
          </div>

          {/* Floating Sample Receipt */}
          <div className="relative flex min-w-0 items-center justify-center py-8 lg:col-span-5">
            <div
              aria-hidden
              className="pointer-events-none absolute h-[260px] w-[260px] rounded-full border-[1.5px] border-dashed border-ink-line-2 sm:h-[360px] sm:w-[360px]"
            />
            <div className="relative w-full max-w-[300px] sm:max-w-[340px]">
              <div className="sticker-float absolute -top-4 right-1 z-10 rotate-6 rounded-full border-2 border-ink bg-lime px-4 py-1.5 font-mono text-xs font-semibold tracking-[0.04em] text-ink uppercase sm:right-2">
                {t("landing.receiptSample.paidTag")}
              </div>

              <Receipt className="receipt-float -rotate-2 sm:-rotate-3">
                <div className="flex items-center justify-between gap-2">
                  <img
                    src="/brand/xzacto-logo-on-light.svg"
                    alt="xzacto"
                    width={96}
                    height={26}
                    className="h-6 w-auto"
                  />
                  <span className="font-mono text-xs font-semibold text-muted-on-light">
                    {t("landing.receiptSample.orderNo")}
                  </span>
                </div>
                <p className="mt-2 font-mono text-[11px] tracking-[0.06em] text-muted-on-light uppercase">
                  {t("landing.receiptSample.storeLabel")}
                </p>

                <ReceiptDash />

                <div className="space-y-2.5 text-sm">
                  <div className="flex items-baseline justify-between gap-4">
                    <span>{t("landing.receiptSample.item1")}</span>
                    <MoneyText minor={310000} currency="PHP" className="shrink-0 font-medium" />
                  </div>
                  <div className="flex items-baseline justify-between gap-4">
                    <span>{t("landing.receiptSample.item2")}</span>
                    <MoneyText minor={11000} currency="PHP" className="shrink-0 font-medium" />
                  </div>
                  <div className="flex items-baseline justify-between gap-4">
                    <span>{t("landing.receiptSample.item3")}</span>
                    <MoneyText minor={43500} currency="PHP" className="shrink-0 font-medium" />
                  </div>
                </div>

                <ReceiptDash />

                <div className="flex items-baseline justify-between gap-4 text-xs text-muted-on-light">
                  <span>{t("landing.receiptSample.vatLabel")}</span>
                  <MoneyText minor={39054} currency="PHP" className="shrink-0" />
                </div>

                <div className="mt-3 flex items-baseline justify-between gap-3">
                  <span className="font-mono text-xs font-semibold tracking-[0.06em] text-muted-on-light uppercase">
                    {t("landing.receiptSample.totalLabel")}
                  </span>
                  <MoneyText minor={364500} currency="PHP" variant="total" className="text-text-on-light" />
                </div>
              </Receipt>
            </div>
          </div>
        </div>
      </section>

      {/* 3. Tilted Full-Width Lime Marquee Band */}
      <div className="w-full overflow-hidden py-4">
        <div className="-mx-4 overflow-hidden -rotate-[1.2deg] bg-lime py-3.5 text-ink">
          <div className="xz-marquee-track font-display text-lg font-extrabold tracking-[-0.01em] whitespace-nowrap sm:text-xl">
            <div className="flex shrink-0 items-center">
              <span className="px-4">{marqueeText}</span>
              <span className="px-1" aria-hidden>✳</span>
              <span className="px-4">{marqueeText}</span>
              <span className="px-1" aria-hidden>✳</span>
            </div>
            <div className="flex shrink-0 items-center" aria-hidden>
              <span className="px-4">{marqueeText}</span>
              <span className="px-1">✳</span>
              <span className="px-4">{marqueeText}</span>
              <span className="px-1">✳</span>
            </div>
          </div>
        </div>
      </div>

      {/* 4. Features 4-Card Grid (--ink) */}
      <section
        id="features"
        className="mx-auto max-w-6xl px-4 py-20 [content-visibility:auto] [contain-intrinsic-size:auto_520px] sm:px-8 lg:py-24"
      >
        <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <h2 className="max-w-2xl font-display text-[clamp(2rem,4vw,3rem)] leading-[1.06] font-extrabold tracking-[-0.025em] text-text-on-dark">
            {t("landing.featuresHeader")}
          </h2>
          <p className="max-w-md text-base leading-relaxed text-muted-on-dark">
            {t("landing.featuresSub")}
          </p>
        </div>

        <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {features.map((item) => {
            const Icon = item.icon;
            return (
              <article
                key={item.num}
                className="flex flex-col gap-4 rounded-[24px] border-[1.5px] border-ink-line bg-ink-2 p-6 transition-colors hover:border-lime"
              >
                <div className="flex items-center justify-between">
                  <span className="font-mono text-xs font-semibold tracking-[0.08em] text-lime">
                    {item.num}
                  </span>
                  <Icon size={20} strokeWidth={1.75} className="text-lime" aria-hidden />
                </div>
                <h3 className="font-display text-xl leading-snug font-extrabold tracking-[-0.02em] text-text-on-dark">
                  {item.title}
                </h3>
                <p className="text-sm leading-relaxed text-muted-on-dark">{item.body}</p>
              </article>
            );
          })}
        </div>
      </section>

      {/* 5. How It Works (--paper receipt section) */}
      <section
        id="how"
        className="bg-paper py-20 text-text-on-light [content-visibility:auto] [contain-intrinsic-size:auto_600px] lg:py-24"
      >
        <div className="mx-auto max-w-6xl px-4 sm:px-8">
          <h2 className="max-w-2xl font-display text-[clamp(2rem,4vw,3rem)] leading-[1.06] font-extrabold tracking-[-0.025em] text-text-on-light">
            {t("landing.howTitle")}
          </h2>

          <div className="mt-10">
            <ReceiptDash className="my-0" />
            {steps.map((step) => (
              <div key={step.num}>
                <div className="grid gap-4 py-8 sm:grid-cols-[88px_1fr] sm:items-baseline">
                  <span className="font-mono text-sm font-semibold tracking-[0.06em] text-muted-on-light">
                    {step.num}
                  </span>
                  <div className="grid gap-2 md:grid-cols-12 md:gap-8">
                    <h3 className="font-display text-2xl font-extrabold tracking-[-0.02em] text-text-on-light md:col-span-5">
                      {step.title}
                    </h3>
                    <p className="text-base leading-relaxed text-muted-on-light md:col-span-7">
                      {step.body}
                    </p>
                  </div>
                </div>
                <ReceiptDash className="my-0" />
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 6. Pricing (One full --lime container + --ink pricing card) */}
      <section
        id="pricing"
        className="bg-ink py-20 [content-visibility:auto] [contain-intrinsic-size:auto_560px] lg:py-24"
      >
        <div className="mx-auto max-w-6xl px-4 sm:px-8">
          <div className="grid gap-10 rounded-[40px] bg-lime p-7 text-ink sm:p-12 lg:grid-cols-12 lg:items-center">
            <div className="space-y-5 lg:col-span-6">
              <p className="font-mono text-xs font-semibold tracking-[0.08em] text-ink uppercase">
                {t("landing.pricing.eyebrow")}
              </p>
              <h2 className="font-display text-[clamp(2rem,3.8vw,3rem)] leading-[1.06] font-extrabold tracking-[-0.025em] text-ink">
                {t("landing.pricing.title")}
              </h2>
              <p className="max-w-lg text-base leading-relaxed text-ink">
                {t("landing.pricing.subtitle")}
              </p>
              <div>
                <span className="inline-flex min-h-[44px] items-center rounded-full bg-ink px-5 py-2 font-mono text-xs font-semibold tracking-[0.04em] text-lime">
                  {t("landing.pricing.soloPill")}
                </span>
              </div>
            </div>

            <div className="lg:col-span-6">
              <div className="rounded-[28px] bg-ink p-7 text-text-on-dark sm:p-8">
                <p className="font-mono text-xs font-semibold tracking-[0.08em] text-lime uppercase">
                  {t("landing.pricing.cardBadge")}
                </p>
                <h3 className="mt-2 font-display text-2xl font-extrabold tracking-[-0.02em] text-text-on-dark">
                  {t("landing.pricing.cardTitle")}
                </h3>
                <div className="mt-4 flex flex-wrap items-baseline gap-2">
                  <MoneyText minor={149900} currency="PHP" variant="stat" className="text-lime" />
                  <span className="font-mono text-sm text-muted-on-dark">
                    {t("landing.pricing.perMonth")}
                  </span>
                </div>

                <hr className="my-6 border-0 border-t-[1.5px] border-dashed border-ink-line-2" />

                <ul className="space-y-3 text-sm text-text-on-dark">
                  {pricingBullets.map((bullet) => (
                    <li key={bullet} className="flex items-start gap-2.5">
                      <Check size={17} strokeWidth={2} className="mt-0.5 shrink-0 text-lime" aria-hidden />
                      <span>{bullet}</span>
                    </li>
                  ))}
                </ul>

                <div className="mt-7 flex flex-wrap gap-3">
                  <Link
                    to={posTarget}
                    className={cn(LIME_BUTTON_CLASSES, "whitespace-nowrap")}
                  >
                    <span>{posLabel}</span>
                    <ArrowRight size={17} strokeWidth={2} aria-hidden />
                  </Link>
                  <Link
                    to="/signup"
                    className={cn(GHOST_BUTTON_CLASSES, "whitespace-nowrap")}
                  >
                    <span>{t("landing.startSolo")}</span>
                  </Link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
      </main>

      {/* 7. Footer (--ink) */}
      <footer className="border-t-[1.5px] border-ink-line bg-ink">
        <div className="mx-auto flex max-w-6xl flex-col gap-6 px-4 py-10 sm:flex-row sm:items-center sm:justify-between sm:px-8">
          <div className="space-y-2">
            <img
              src="/brand/xzacto-logo-on-dark.svg"
              alt="xzacto"
              width={116}
              height={32}
              className="h-8 w-auto"
            />
            <p className="text-xs text-muted-on-dark">{t("landing.footerNote")}</p>
          </div>

          <div className="flex flex-wrap items-center gap-6 text-sm font-medium text-muted-on-dark">
            <Link to={posTarget} className="transition-colors hover:text-lime">
              {posLabel}
            </Link>
            <Link to="/warehouse" className="transition-colors hover:text-lime">
              {t("landing.warehousePortal")}
            </Link>
            <Link to="/signup" className="transition-colors hover:text-lime">
              {t("landing.startSolo")}
            </Link>
            <span className="font-mono text-xs text-muted-on-dark">
              {t("landing.footerCopyright")}
            </span>
          </div>
        </div>
      </footer>
    </div>
  );
}
