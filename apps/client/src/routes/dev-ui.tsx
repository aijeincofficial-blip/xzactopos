import { useState } from "react";
import { useTranslation } from "react-i18next";
import {
  ArrowRight,
  BarChart3,
  Check,
  Package,
  ShoppingCart,
  Store,
  Warehouse,
} from "lucide-react";
import {
  AppShell,
  DataTable,
  EmptyState,
  GhostButton,
  LimeButton,
  MoneyText,
  Pill,
  Receipt,
  ReceiptDash,
  Segmented,
  StatTile,
  SyncChip,
  type DataTableColumn,
} from "../ui/index.ts";
import { LanguageSelect } from "../components/LanguageSelect.tsx";

interface SampleStockRow {
  id: string;
  name: string;
  sku: string;
  qty: number;
  priceMinor: number;
}

export function DevUiPage() {
  const { t } = useTranslation(["common", "shell"]);
  const [pill, setPill] = useState<"all" | "coffee" | "pastry">("all");
  const [orderType, setOrderType] = useState<"dine" | "take">("dine");
  const [navId, setNavId] = useState("pos");

  const sampleRows: ReadonlyArray<SampleStockRow> = [
    { id: "1", name: "Spanish Latte (16oz)", sku: "COF-SL16", qty: 48, priceMinor: 14500 },
    { id: "2", name: "Sinandomeng Rice 25kg", sku: "GRC-SR25", qty: 3, priceMinor: 155000 },
    { id: "3", name: "Ensaymada Special", sku: "PST-ENS1", qty: 0, priceMinor: 6500 },
  ];

  const columns: ReadonlyArray<DataTableColumn<SampleStockRow>> = [
    { key: "name", header: t("common:devUi.colItem"), render: (r) => r.name },
    { key: "sku", header: t("common:devUi.colSku"), mono: true, render: (r) => r.sku },
    {
      key: "qty",
      header: t("common:devUi.colStock"),
      align: "right",
      mono: true,
      render: (r) => (
        <span
          className={
            r.qty === 0
              ? "inline-block rounded-full bg-ink px-2.5 py-0.5 font-mono text-xs text-text-on-dark"
              : r.qty <= 5
                ? "inline-block rounded-full bg-sw-meal px-2.5 py-0.5 font-mono text-xs text-sw-meal-fg"
                : "font-mono tabular-nums"
          }
        >
          {r.qty}
        </span>
      ),
    },
    {
      key: "price",
      header: t("common:devUi.colPrice"),
      align: "right",
      render: (r) => <MoneyText minor={r.priceMinor} currency="PHP" />,
    },
  ];

  const swatches = [
    { label: t("common:devUi.swatchCoffee"), cls: "bg-sw-coffee text-sw-coffee-fg", mono: "Sl" },
    { label: t("common:devUi.swatchNonCoffee"), cls: "bg-sw-noncoffee text-sw-noncoffee-fg", mono: "Mt" },
    { label: t("common:devUi.swatchPastry"), cls: "bg-sw-pastry text-sw-pastry-fg", mono: "En" },
    { label: t("common:devUi.swatchMeal"), cls: "bg-sw-meal text-sw-meal-fg", mono: "Sr" },
  ];

  return (
    <div className="min-h-screen bg-ink text-text-on-dark">
      <div className="mx-auto grid max-w-6xl gap-12 px-4 py-10 sm:px-8">
        <header className="flex flex-wrap items-center justify-between gap-4 border-b-[1.5px] border-ink-line pb-6">
          <div className="flex items-center gap-4">
            <img
              src="/brand/xzacto-logo-on-dark.svg"
              alt="xzacto"
              width={132}
              height={36}
              className="h-9 w-auto"
            />
            <div>
              <h1 className="font-display text-2xl font-extrabold tracking-[-0.02em] text-text-on-dark">
                {t("common:devUi.title")}
              </h1>
              <p className="text-sm text-muted-on-dark">{t("common:devUi.subtitle")}</p>
            </div>
          </div>
          <div className="text-text-on-light [&_select]:bg-paper [&_select]:text-text-on-light">
            <LanguageSelect />
          </div>
        </header>

        {/* SyncChip 4 States */}
        <section className="grid gap-4">
          <span className="font-mono text-xs tracking-[0.08em] text-lime uppercase">
            01 · {t("common:devUi.syncSection")}
          </span>
          <div className="flex flex-wrap items-center gap-3 rounded-[24px] border-[1.5px] border-ink-line bg-ink-2 p-6">
            <SyncChip state="synced" />
            <SyncChip state="offline" queuedCount={3} />
            <SyncChip state="syncing" />
            <SyncChip state="error" />
          </div>
        </section>

        {/* Buttons, Pills & Segmented */}
        <section className="grid gap-4">
          <span className="font-mono text-xs tracking-[0.08em] text-lime uppercase">
            02 · {t("common:devUi.buttonsSection")}
          </span>
          <div className="grid gap-5 rounded-[24px] border-[1.5px] border-ink-line bg-ink-2 p-6">
            <div className="flex flex-wrap items-center gap-3">
              <LimeButton>
                <span>{t("common:devUi.sampleCharge")}</span>
                <ArrowRight size={17} strokeWidth={2} aria-hidden />
              </LimeButton>
              <LimeButton disabled>{t("common:devUi.sampleCharge")}</LimeButton>
              <GhostButton>{t("common:devUi.sampleGhost")}</GhostButton>
            </div>
            <div className="rounded-[20px] bg-sand p-5 text-text-on-light">
              <div className="flex flex-wrap items-center gap-3">
                <Pill active={pill === "all"} count={42} onClick={() => setPill("all")}>
                  {t("common:devUi.pillAll")}
                </Pill>
                <Pill active={pill === "coffee"} count={18} onClick={() => setPill("coffee")}>
                  {t("common:devUi.pillCoffee")}
                </Pill>
                <Pill active={pill === "pastry"} count={9} onClick={() => setPill("pastry")}>
                  {t("common:devUi.pillPastry")}
                </Pill>
                <Segmented
                  aria-label="Order type"
                  value={orderType}
                  onChange={setOrderType}
                  options={[
                    { value: "dine", label: t("common:devUi.segDineIn") },
                    { value: "take", label: t("common:devUi.segTakeOut") },
                  ]}
                />
              </div>
            </div>
          </div>
        </section>

        {/* Swatches & Receipt */}
        <section className="grid gap-6 lg:grid-cols-2">
          <div className="grid content-start gap-4">
            <span className="font-mono text-xs tracking-[0.08em] text-lime uppercase">
              03 · {t("common:devUi.tokensSection")}
            </span>
            <div className="grid grid-cols-2 gap-3">
              {swatches.map((s) => (
                <div key={s.label} className="rounded-[20px] border-[1.5px] border-ink-line bg-ink-2 p-4">
                  <div className={`flex h-20 items-end rounded-[14px] p-3 ${s.cls}`}>
                    <span className="font-display text-[38px] font-extrabold leading-none tracking-[-0.03em]">
                      {s.mono}
                    </span>
                  </div>
                  <div className="mt-2.5 text-sm font-semibold text-text-on-dark">{s.label}</div>
                </div>
              ))}
            </div>
          </div>

          <div className="grid content-start gap-4">
            <span className="font-mono text-xs tracking-[0.08em] text-lime uppercase">
              04 · {t("common:devUi.receiptSection")}
            </span>
            <div className="relative pt-4 pb-6">
              <div className="inline-flex rotate-[5deg] items-center gap-1.5 rounded-[16px] bg-lime px-3.5 py-2 text-xs font-semibold text-ink shadow-[0_20px_40px_rgba(0,0,0,0.4)]">
                <Check size={14} strokeWidth={2.5} aria-hidden />
                <span>{t("common:devUi.receiptPaidTag")}</span>
              </div>
              <Receipt className="-mt-2 shadow-[0_40px_80px_rgba(0,0,0,0.45)]">
                <div className="flex items-center justify-between font-mono text-xs tracking-[0.08em] text-muted-on-light uppercase">
                  <span>{t("common:devUi.receiptNo")}</span>
                  <span>19:08</span>
                </div>
                <ReceiptDash />
                <div className="grid gap-2 text-sm">
                  <div className="flex items-baseline justify-between gap-4">
                    <span>2× {t("common:devUi.receiptItem1")}</span>
                    <MoneyText minor={29000} currency="PHP" />
                  </div>
                  <div className="flex items-baseline justify-between gap-4">
                    <span>1× {t("common:devUi.receiptItem2")}</span>
                    <MoneyText minor={6500} currency="PHP" />
                  </div>
                </div>
                <ReceiptDash />
                <div className="flex items-baseline justify-between text-xs text-muted-on-light">
                  <span>{t("common:devUi.receiptVat")}</span>
                  <MoneyText minor={3804} currency="PHP" />
                </div>
                <div className="mt-2 flex items-baseline justify-between">
                  <span className="font-mono text-xs tracking-[0.08em] uppercase">{t("common:devUi.receiptTotal")}</span>
                  <MoneyText minor={35500} currency="PHP" variant="total" />
                </div>
              </Receipt>
            </div>
          </div>
        </section>

        {/* Stat Tiles, Data Table & Empty State */}
        <section className="grid gap-4">
          <span className="font-mono text-xs tracking-[0.08em] text-lime uppercase">
            05 · {t("common:devUi.dataSection")}
          </span>
          <div className="grid gap-4 rounded-[28px] bg-sand p-6 text-text-on-light">
            <div className="grid gap-4 sm:grid-cols-2">
              <StatTile
                eyebrow={t("common:devUi.statSales")}
                value={<MoneyText minor={4892000} currency="PHP" variant="stat" />}
              />
              <StatTile eyebrow={t("common:devUi.statOrders")} value="142" />
            </div>
            <DataTable columns={columns} rows={sampleRows} rowKey={(r) => r.id} />
            <EmptyState
              icon={Package}
              message={t("common:devUi.emptyTitle")}
              actionLabel={t("common:devUi.emptyAction")}
              onAction={() => undefined}
            />
          </div>
        </section>

        {/* AppShell Preview */}
        <section className="grid gap-4">
          <span className="font-mono text-xs tracking-[0.08em] text-lime uppercase">
            06 · {t("common:devUi.shellSection")}
          </span>
          <AppShell
            contained
            storeName={t("common:devUi.shellStore")}
            eyebrow={t("common:devUi.shellMode")}
            title={t("common:devUi.shellTitle")}
            activeNavId={navId}
            syncState="offline"
            syncQueuedCount={2}
            navItems={[
              { id: "pos", label: t("common:devUi.navPos"), icon: ShoppingCart, onSelect: () => setNavId("pos") },
              { id: "stock", label: t("common:devUi.navStock"), icon: Package, onSelect: () => setNavId("stock") },
              { id: "wh", label: t("common:devUi.navWh"), icon: Warehouse, onSelect: () => setNavId("wh") },
              { id: "reports", label: t("common:devUi.navReports"), icon: BarChart3, onSelect: () => setNavId("reports") },
              { id: "store", label: t("common:devUi.navStore"), icon: Store, visible: false, onSelect: () => setNavId("store") },
            ]}
          >
            <div className="grid gap-3">
              <StatTile eyebrow={t("common:devUi.activeTab")} value={navId.toUpperCase()} />
            </div>
          </AppShell>
        </section>
      </div>
    </div>
  );
}
