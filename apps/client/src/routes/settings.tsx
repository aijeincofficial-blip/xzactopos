import { useState, useEffect, type FormEvent } from "react";
import { useTranslation } from "react-i18next";
import { Link } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchTenantSettings, updateTenantSettings } from "../lib/settings-api.ts";
import { fieldErrors, tenantSettingsSchema } from "../lib/schemas.ts";
import { accessQuery } from "../lib/session.tsx";
import { useErrorMessage, useValidationMessage } from "../lib/i18n-helpers.ts";
import { Alert, Badge, Button, Card, Field, Input, Select } from "../components/ui.tsx";
import {
  fetchStorageMetrics,
  runArchiveMaintenance,
  checkHealthPing,
  type HealthPingResult,
} from "../lib/maintenance-api.ts";

function timezones(): string[] {
  try {
    return Intl.supportedValuesOf("timeZone");
  } catch {
    return ["Asia/Manila", "UTC"];
  }
}

export function SettingsPage() {
  const { t } = useTranslation(["admin", "common"]);
  const qc = useQueryClient();
  const errMsg = useErrorMessage();
  const vm = useValidationMessage();

  const q = useQuery({
    queryKey: ["tenant-settings"],
    queryFn: fetchTenantSettings,
  });

  const [name, setName] = useState("");
  const [timezone, setTimezone] = useState("Asia/Manila");
  const [taxMode, setTaxMode] = useState<"inclusive" | "exclusive" | "none">("inclusive");
  const [defaultLocale, setDefaultLocale] = useState<"en" | "fil">("en");
  const [locales, setLocales] = useState<("en" | "fil")[]>(["en", "fil"]);
  const [offlineSessionDays, setOfflineSessionDays] = useState(7);
  const [receiptHeader, setReceiptHeader] = useState("");
  const [receiptFooter, setReceiptFooter] = useState("");
  const [maxCashierDiscountPercent, setMaxCashierDiscountPercent] = useState(10);
  const [maxCashierVoidAmount, setMaxCashierVoidAmount] = useState(500);
  const [cashierCanVoidOwn, setCashierCanVoidOwn] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [savedSuccess, setSavedSuccess] = useState(false);

  // Storage & Maintenance states
  const [archiveMessage, setArchiveMessage] = useState<string | null>(null);
  const [pingResult, setPingResult] = useState<HealthPingResult | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const storageQuery = useQuery({
    queryKey: ["storage-metrics"],
    queryFn: fetchStorageMetrics,
  });

  const archiveMutation = useMutation({
    mutationFn: () => runArchiveMaintenance(30),
    onSuccess: async (res) => {
      await qc.invalidateQueries({ queryKey: ["storage-metrics"] });
      setArchiveMessage(
        t("settings.archiveSuccess", {
          ops: res.ops_deleted,
          approvals: res.approvals_deleted,
        })
      );
      setTimeout(() => setArchiveMessage(null), 5000);
    },
    onError: (e) => setActionError(errMsg(e)),
  });

  const pingMutation = useMutation({
    mutationFn: checkHealthPing,
    onSuccess: (res) => {
      setPingResult(res);
      setTimeout(() => setPingResult(null), 6000);
    },
    onError: (e) => setActionError(errMsg(e)),
  });

  useEffect(() => {
    if (q.data) {
      setName(q.data.tenant.name);
      setTimezone(q.data.tenant.timezone);
      setTaxMode(q.data.tenant.tax_mode);
      setDefaultLocale(q.data.settings.default_locale);
      setLocales(q.data.settings.locales);
      setOfflineSessionDays(q.data.settings.offline_session_days);
      setReceiptHeader(q.data.settings.receipt_header ?? "");
      setReceiptFooter(q.data.settings.receipt_footer ?? "");
      setMaxCashierDiscountPercent(q.data.settings.max_cashier_discount_percent ?? 10);
      setMaxCashierVoidAmount((q.data.settings.max_cashier_void_amount ?? 50000) / 100);
      setCashierCanVoidOwn(Boolean(q.data.settings.cashier_can_void_own));
    }
  }, [q.data]);

  const save = useMutation({
    mutationFn: async () => {
      if (!q.data) return;
      await updateTenantSettings({
        tenantId: q.data.tenant.id,
        name,
        timezone,
        tax_mode: taxMode,
        default_locale: defaultLocale,
        locales,
        offline_session_days: offlineSessionDays,
        receipt_header: receiptHeader,
        receipt_footer: receiptFooter,
        max_cashier_discount_percent: maxCashierDiscountPercent,
        max_cashier_void_amount: Math.round(maxCashierVoidAmount * 100),
        cashier_can_void_own: cashierCanVoidOwn,
      });
    },
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ["tenant-settings"] });
      await qc.invalidateQueries({ queryKey: accessQuery.queryKey });
      setSavedSuccess(true);
      setTimeout(() => setSavedSuccess(false), 4000);
    },
  });

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    const r = tenantSettingsSchema.safeParse({
      name,
      timezone,
      taxMode,
      defaultLocale,
      locales,
      offlineSessionDays,
      receiptHeader,
      receiptFooter,
      maxCashierDiscountPercent,
      maxCashierVoidAmount: Math.round(maxCashierVoidAmount * 100),
      cashierCanVoidOwn,
    });
    if (!r.success) {
      setErrors(fieldErrors(r.error));
      return;
    }
    setErrors({});
    save.mutate();
  }

  function toggleLocale(lang: "en" | "fil") {
    if (locales.includes(lang)) {
      if (locales.length === 1) return; // Must have at least 1
      const next = locales.filter((l) => l !== lang);
      setLocales(next);
      if (defaultLocale === lang && next.length > 0) {
        setDefaultLocale(next[0]!);
      }
    } else {
      setLocales([...locales, lang]);
    }
  }

  if (q.isPending) return <Card>{t("settings.loading")}</Card>;
  if (q.isError) return <Alert>{errMsg(q.error)}</Alert>;

  const d = q.data;
  const tzList = timezones();
  if (!tzList.includes(timezone)) tzList.unshift(timezone);

  return (
    <div className="grid gap-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">{t("settings.title")}</h1>
          <p className="text-sm text-slate-500">{t("settings.subtitle")}</p>
        </div>
        <div className="flex items-center gap-2">
          <Badge tone={d.tenant.status === "active" ? "good" : "warn"}>
            {t(`settings.status.${d.tenant.status}`)}
          </Badge>
          <Badge tone={d.tenant.plan === "pro" ? "good" : "neutral"}>
            {t(`settings.plan.${d.tenant.plan}`)}
          </Badge>
        </div>
      </div>

      {save.isError ? <Alert>{errMsg(save.error)}</Alert> : null}
      {savedSuccess ? <Alert tone="info">{t("common:saved")}</Alert> : null}
      {actionError ? <Alert>{actionError}</Alert> : null}

      <form onSubmit={handleSubmit} className="grid gap-6">
        {/* Business Profile */}
        <Card className="grid gap-4">
          <h2 className="text-lg font-semibold">{t("settings.businessSection")}</h2>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label={t("settings.businessName")} error={vm(errors["name"])}>
              <Input value={name} onChange={(e) => setName(e.target.value)} />
            </Field>

            <Field label={t("settings.businessCode")} hint={t("settings.businessCodeHint")}>
              <Input value={d.tenant.slug} disabled />
            </Field>

            <Field label={t("settings.timezone")} error={vm(errors["timezone"])}>
              <Select value={timezone} onChange={(e) => setTimezone(e.target.value)}>
                {tzList.map((tz) => (
                  <option key={tz} value={tz}>
                    {tz}
                  </option>
                ))}
              </Select>
            </Field>

            <Field label={t("settings.taxMode")}>
              <Select
                value={taxMode}
                onChange={(e) => setTaxMode(e.target.value as "inclusive" | "exclusive" | "none")}
              >
                <option value="inclusive">{t("settings.taxModeInclusive")}</option>
                <option value="exclusive">{t("settings.taxModeExclusive")}</option>
                <option value="none">{t("settings.taxModeNone")}</option>
              </Select>
            </Field>

            <Field label={t("settings.baseCurrency")} hint={t("settings.currencyLockedHint")}>
              <Input value={d.tenant.base_currency} disabled />
            </Field>
          </div>
        </Card>

        {/* Languages & Locales */}
        <Card className="grid gap-4">
          <h2 className="text-lg font-semibold">{t("settings.languageSection")}</h2>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <span className="text-sm font-medium">{t("settings.supportedLanguages")}</span>
              <p className="text-xs text-slate-500 mb-2">{t("settings.supportedLanguagesHint")}</p>
              <div className="flex gap-4">
                <label className="flex items-center gap-2 text-sm cursor-pointer">
                  <input
                    type="checkbox"
                    checked={locales.includes("en")}
                    onChange={() => toggleLocale("en")}
                    className="h-4 w-4 rounded border-slate-300 text-slate-900"
                  />
                  {t("settings.langEn")}
                </label>
                <label className="flex items-center gap-2 text-sm cursor-pointer">
                  <input
                    type="checkbox"
                    checked={locales.includes("fil")}
                    onChange={() => toggleLocale("fil")}
                    className="h-4 w-4 rounded border-slate-300 text-slate-900"
                  />
                  {t("settings.langFil")}
                </label>
              </div>
              {errors["locales"] ? (
                <span role="alert" className="text-xs text-red-600 block mt-1">
                  {vm(errors["locales"])}
                </span>
              ) : null}
            </div>

            <Field label={t("settings.defaultLanguage")} error={vm(errors["defaultLocale"])}>
              <Select
                value={defaultLocale}
                onChange={(e) => setDefaultLocale(e.target.value as "en" | "fil")}
              >
                {locales.map((l) => (
                  <option key={l} value={l}>
                    {l === "en" ? t("settings.langEn") : t("settings.langFil")}
                  </option>
                ))}
              </Select>
            </Field>
          </div>
        </Card>

        {/* Receipts & Offline */}
        <Card className="grid gap-4">
          <h2 className="text-lg font-semibold">{t("settings.receiptSection")}</h2>
          <div className="grid gap-4">
            <Field
              label={t("settings.receiptHeader")}
              hint={t("settings.receiptHeaderHint")}
              error={vm(errors["receiptHeader"])}
            >
              <Input
                value={receiptHeader}
                onChange={(e) => setReceiptHeader(e.target.value)}
                placeholder="e.g. Tindahan Ni Rosa • TIN: 123-456-789"
              />
            </Field>

            <Field
              label={t("settings.receiptFooter")}
              hint={t("settings.receiptFooterHint")}
              error={vm(errors["receiptFooter"])}
            >
              <Input
                value={receiptFooter}
                onChange={(e) => setReceiptFooter(e.target.value)}
                placeholder="e.g. Maraming salamat po! Mag-ingat sa biyahe."
              />
            </Field>

            <Field
              label={t("settings.offlineDuration")}
              hint={t("settings.offlineDurationHint")}
              error={vm(errors["offlineSessionDays"])}
            >
              <Input
                type="number"
                min={1}
                max={30}
                value={offlineSessionDays}
                onChange={(e) => setOfflineSessionDays(Number(e.target.value))}
                className="max-w-xs"
              />
            </Field>
          </div>
        </Card>

        {/* Sales Controls & Permissions */}
        <Card className="grid gap-4">
          <h2 className="text-lg font-semibold">{t("settings.salesControlsSection")}</h2>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field
              label={t("settings.maxCashierDiscountPercent")}
              hint={t("settings.maxCashierDiscountPercentHint")}
              error={vm(errors["maxCashierDiscountPercent"])}
            >
              <Input
                type="number"
                min={0}
                max={100}
                value={maxCashierDiscountPercent}
                onChange={(e) => setMaxCashierDiscountPercent(Number(e.target.value))}
                className="max-w-xs"
              />
            </Field>

            <Field
              label={t("settings.maxCashierVoidAmount")}
              hint={t("settings.maxCashierVoidAmountHint")}
              error={vm(errors["maxCashierVoidAmount"])}
            >
              <Input
                type="number"
                min={0}
                step="0.01"
                value={maxCashierVoidAmount}
                onChange={(e) => setMaxCashierVoidAmount(Number(e.target.value))}
                className="max-w-xs"
              />
            </Field>

            <div className="sm:col-span-2">
              <label className="flex items-center gap-2 text-sm cursor-pointer">
                <input
                  type="checkbox"
                  checked={cashierCanVoidOwn}
                  onChange={(e) => setCashierCanVoidOwn(e.target.checked)}
                  className="h-4 w-4 rounded border-slate-300 text-slate-900"
                />
                <span className="font-medium text-slate-800">{t("settings.cashierCanVoidOwn")}</span>
              </label>
              <p className="text-xs text-slate-500 mt-1">{t("settings.cashierCanVoidOwnHint")}</p>
            </div>
          </div>
        </Card>

        {/* Quotas & Capacity Limits */}
        <Card className="grid gap-4">
          <h2 className="text-lg font-semibold">{t("settings.limitsSection")}</h2>
          <p className="text-xs text-slate-500">{t("settings.limitsDesc")}</p>
          <div className="grid gap-4 sm:grid-cols-4">
            <div className="rounded-lg border border-slate-200 p-3 bg-slate-50/50">
              <div className="text-xs text-slate-500">{t("settings.limitLocations")}</div>
              <div className="mt-1 text-xl font-bold text-slate-900">
                {d.counts.locations} / {d.limits.max_locations}
              </div>
            </div>
            <div className="rounded-lg border border-slate-200 p-3 bg-slate-50/50">
              <div className="text-xs text-slate-500">{t("settings.limitUsers")}</div>
              <div className="mt-1 text-xl font-bold text-slate-900">
                {d.counts.users} / {d.limits.max_users}
              </div>
            </div>
            <div className="rounded-lg border border-slate-200 p-3 bg-slate-50/50">
              <div className="text-xs text-slate-500">{t("settings.limitDevices")}</div>
              <div className="mt-1 text-xl font-bold text-slate-900">
                {d.counts.devices} / {d.limits.max_devices}
              </div>
            </div>
            <div className="rounded-lg border border-slate-200 p-3 bg-slate-50/50">
              <div className="text-xs text-slate-500">{t("settings.limitProducts")}</div>
              <div className="mt-1 text-xl font-bold text-slate-900">
                {d.counts.products} / {d.limits.max_products}
              </div>
            </div>
          </div>
        </Card>

        {/* Free-Tier Storage & Maintenance Card */}
        {storageQuery.data ? (
          <Card className="grid gap-4">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div>
                <h2 className="text-lg font-semibold">{t("settings.storageTitle")}</h2>
                <p className="text-xs text-slate-500">{t("settings.storageDesc")}</p>
              </div>
              <Badge
                tone={
                  storageQuery.data.status === "critical"
                    ? "warn"
                    : storageQuery.data.status === "warning"
                    ? "warn"
                    : "good"
                }
              >
                {storageQuery.data.status === "critical"
                  ? `⚠️ ${t("settings.statusCritical")}`
                  : storageQuery.data.status === "warning"
                  ? `⚠️ ${t("settings.statusWarning")}`
                  : `✓ ${t("settings.statusHealthy")}`}
              </Badge>
            </div>

            {/* Storage Progress Bar */}
            <div className="grid gap-1.5">
              <div className="flex justify-between text-xs font-medium text-slate-600">
                <span>
                  {storageQuery.data.used_mb} MB {t("settings.usedOf")} {storageQuery.data.limit_mb} MB
                </span>
                <span>{storageQuery.data.percent_used}%</span>
              </div>
              <div className="h-2.5 w-full overflow-hidden rounded-full bg-slate-100">
                <div
                  className={`h-full transition-all ${
                    storageQuery.data.status === "critical"
                      ? "bg-rose-500"
                      : storageQuery.data.status === "warning"
                      ? "bg-amber-500"
                      : "bg-emerald-500"
                  }`}
                  style={{ width: `${Math.min(storageQuery.data.percent_used, 100)}%` }}
                />
              </div>
            </div>

            {/* Actions & Health Ping */}
            <div className="flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 pt-3">
              <div className="flex items-center gap-2">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => pingMutation.mutate()}
                  disabled={pingMutation.isPending}
                >
                  {pingMutation.isPending ? t("settings.loading") : `⚡ ${t("settings.testPing")}`}
                </Button>
                {pingResult ? (
                  <span className="text-xs text-emerald-600 font-medium">
                    ✓ {pingResult.status} ({new Date(pingResult.timestamp).toLocaleTimeString()})
                  </span>
                ) : null}
              </div>

              <div className="flex items-center gap-2">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => archiveMutation.mutate()}
                  disabled={archiveMutation.isPending}
                >
                  {archiveMutation.isPending ? t("settings.saving") : `🧹 ${t("settings.runMaintenance")}`}
                </Button>
                {archiveMessage ? (
                  <span className="text-xs text-emerald-600 font-medium">
                    ✓ {archiveMessage}
                  </span>
                ) : null}
              </div>
            </div>

            {/* Top Tables breakdown */}
            <div className="mt-2">
              <div className="text-xs font-semibold uppercase text-slate-500 mb-2">
                {t("settings.largestTables")}
              </div>
              <div className="max-h-48 overflow-y-auto rounded border border-slate-200 text-xs">
                <table className="w-full text-left">
                  <thead className="bg-slate-50 text-slate-500 uppercase">
                    <tr>
                      <th className="p-2">{t("settings.tableName")}</th>
                      <th className="p-2 text-right">{t("settings.estRows")}</th>
                      <th className="p-2 text-right">{t("settings.totalSize")}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {storageQuery.data.tables.slice(0, 8).map((tbl) => (
                      <tr key={tbl.table_name} className="border-t border-slate-100 font-mono">
                        <td className="p-2 text-slate-900 font-sans">{tbl.table_name}</td>
                        <td className="p-2 text-right text-slate-600">
                          {Number(tbl.estimated_rows).toLocaleString()}
                        </td>
                        <td className="p-2 text-right text-slate-900 font-semibold">{tbl.formatted_size}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </Card>
        ) : null}

        <div className="flex items-center justify-between gap-4">
          <Button type="submit" disabled={save.isPending}>
            {save.isPending ? t("settings.saving") : t("common:actions.save")}
          </Button>
          <div className="flex gap-2">
            <Link to="/app/modules" className="inline-flex">
              <Button variant="outline" size="sm">
                {t("nav.modules")}
              </Button>
            </Link>
            <Link to="/app/locations" className="inline-flex">
              <Button variant="outline" size="sm">
                {t("nav.locations")}
              </Button>
            </Link>
          </div>
        </div>
      </form>
    </div>
  );
}
