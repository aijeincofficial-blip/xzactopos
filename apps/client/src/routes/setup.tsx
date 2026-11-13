import { useState } from "react";
import { useTranslation } from "react-i18next";
import { useNavigate } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { listCurrencies, rpc } from "../lib/api.ts";
import { fieldErrors, setupBusinessSchema, setupLanguagesSchema } from "../lib/schemas.ts";
import { accessQuery, useSession } from "../lib/session.tsx";
import { useErrorMessage, useValidationMessage } from "../lib/i18n-helpers.ts";
import { Alert, Button, Card, Field, Input, Select } from "../components/ui.tsx";
import { ModuleChoice } from "../components/ModuleChoice.tsx";

type Locale = "en" | "fil";
const LOCALES: Locale[] = ["en", "fil"];

function timezones(): string[] {
  try {
    return Intl.supportedValuesOf("timeZone");
  } catch {
    return ["UTC"];
  }
}

export function SetupPage() {
  const { t } = useTranslation(["admin", "common"]);
  const { access } = useSession();
  const qc = useQueryClient();
  const navigate = useNavigate();
  const errMsg = useErrorMessage();
  const vm = useValidationMessage();
  const currencies = useQuery({ queryKey: ["currencies"], queryFn: listCurrencies, staleTime: Infinity });

  const [step, setStep] = useState(0);
  const [name, setName] = useState(access.tenant.name);
  const [baseCurrency, setBaseCurrency] = useState(access.tenant.base_currency);
  const [timezone, setTimezone] = useState(access.tenant.timezone);
  const [taxMode, setTaxMode] = useState<"inclusive" | "exclusive" | "none">("inclusive");
  const [locales, setLocales] = useState<Locale[]>(["en", "fil"]);
  const [defaultLocale, setDefaultLocale] = useState<Locale>("en");
  const [pos, setPos] = useState(access.modules.pos);
  const [warehouse, setWarehouse] = useState(access.modules.warehouse);
  const [errors, setErrors] = useState<Record<string, string>>({});

  const save = useMutation({
    mutationFn: () =>
      rpc("complete_setup", {
        p_name: name.trim(),
        p_base_currency: baseCurrency,
        p_timezone: timezone,
        p_tax_mode: taxMode,
        p_default_locale: defaultLocale,
        p_locales: locales,
        p_pos: pos,
        p_warehouse: warehouse,
      }),
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: accessQuery.queryKey });
      await navigate({ to: "/app/locations" });
    },
  });

  function next() {
    if (step === 0) {
      const r = setupBusinessSchema.safeParse({ name, baseCurrency, timezone, taxMode });
      if (!r.success) return setErrors(fieldErrors(r.error));
    }
    if (step === 1) {
      const r = setupLanguagesSchema.safeParse({ locales, defaultLocale });
      if (!r.success) return setErrors(fieldErrors(r.error));
    }
    setErrors({});
    setStep(step + 1);
  }

  const steps = ["business", "languages", "modules"] as const;

  return (
    <Card className="mx-auto grid w-full max-w-xl gap-4">
      <div>
        <h1 className="font-display text-2xl font-extrabold tracking-tight text-slate-900">{t("setup.title")}</h1>
        <p className="mt-1 font-mono text-xs font-semibold tracking-[0.06em] text-slate-500 uppercase">
          {t("setup.step", { current: step + 1, total: steps.length })}: {t(`setup.steps.${steps[step]!}`)}
        </p>
      </div>
      {save.isError ? <Alert>{errMsg(save.error)}</Alert> : null}

      {step === 0 ? (
        <div className="grid gap-4">
          <Field label={t("setup.name")} error={vm(errors["name"])}>
            <Input value={name} onChange={(e) => setName(e.target.value)} />
          </Field>
          <Field label={t("setup.currency")} hint={t("setup.currencyHint")} error={vm(errors["baseCurrency"])}>
            <Select value={baseCurrency} onChange={(e) => setBaseCurrency(e.target.value)}>
              {(currencies.data ?? [{ code: baseCurrency, name: baseCurrency }]).map((c) => (
                <option key={c.code} value={c.code}>
                  {c.code} · {c.name}
                </option>
              ))}
            </Select>
          </Field>
          <Field label={t("setup.timezone")} error={vm(errors["timezone"])}>
            <Input list="tz-list" value={timezone} onChange={(e) => setTimezone(e.target.value)} />
            <datalist id="tz-list">
              {timezones().map((z) => (
                <option key={z} value={z} />
              ))}
            </datalist>
          </Field>
          <Field label={t("setup.taxMode")}>
            <Select value={taxMode} onChange={(e) => setTaxMode(e.target.value as typeof taxMode)}>
              {(["inclusive", "exclusive", "none"] as const).map((m) => (
                <option key={m} value={m}>
                  {t(`setup.tax.${m}`)}
                </option>
              ))}
            </Select>
          </Field>
        </div>
      ) : null}

      {step === 1 ? (
        <div className="grid gap-4">
          <fieldset className="grid gap-2">
            <legend className="mb-1 text-sm font-medium">{t("setup.locales")}</legend>
            {LOCALES.map((l) => (
              <label key={l} className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={locales.includes(l)}
                  onChange={(e) => setLocales(e.target.checked ? [...locales, l] : locales.filter((x) => x !== l))}
                />
                {t(`common:language.${l}`)}
              </label>
            ))}
            {errors["locales"] ? (
              <span role="alert" className="text-xs text-red-600">
                {vm(errors["locales"])}
              </span>
            ) : null}
          </fieldset>
          <Field label={t("setup.defaultLocale")} error={vm(errors["defaultLocale"])}>
            <Select value={defaultLocale} onChange={(e) => setDefaultLocale(e.target.value as Locale)}>
              {LOCALES.map((l) => (
                <option key={l} value={l}>
                  {t(`common:language.${l}`)}
                </option>
              ))}
            </Select>
          </Field>
        </div>
      ) : null}

      {step === 2 ? <ModuleChoice pos={pos} warehouse={warehouse} onPos={setPos} onWarehouse={setWarehouse} /> : null}

      <div className="flex justify-between">
        <Button variant="outline" disabled={step === 0 || save.isPending} onClick={() => setStep(step - 1)}>
          {t("common:actions.back")}
        </Button>
        {step < steps.length - 1 ? (
          <Button onClick={next}>{t("common:actions.next")}</Button>
        ) : (
          <Button disabled={save.isPending} onClick={() => save.mutate()}>
            {t("setup.finish")}
          </Button>
        )}
      </div>
    </Card>
  );
}
