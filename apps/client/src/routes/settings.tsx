import { useState, useEffect, type FormEvent } from "react";
import { useTranslation } from "react-i18next";
import { Link } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchTenantSettings, updateTenantSettings } from "../lib/settings-api.ts";
import { fieldErrors, tenantSettingsSchema } from "../lib/schemas.ts";
import { accessQuery } from "../lib/session.tsx";
import { useErrorMessage, useValidationMessage } from "../lib/i18n-helpers.ts";
import { Alert, Badge, Button, Card, Field, Input, Select } from "../components/ui.tsx";

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
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [savedSuccess, setSavedSuccess] = useState(false);

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
