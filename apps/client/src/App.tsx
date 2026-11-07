import { useCallback, useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { formatMoney, money } from "@pos/core";
import { checkConnection, type ConnectionState } from "./lib/supabase.ts";
import { SUPPORTED_LOCALES, type Locale } from "./i18n/index.ts";

const SAMPLES = [money(123456, "USD"), money(123456, "JPY"), money(123456, "KWD")];

export function App() {
  const { t, i18n } = useTranslation(["common", "shell"]);
  const [state, setState] = useState<ConnectionState | "checking">("checking");

  const check = useCallback(() => {
    const ctl = new AbortController();
    setState("checking");
    void checkConnection(ctl.signal).then((s) => {
      if (!ctl.signal.aborted) setState(s);
    });
    return () => ctl.abort();
  }, []);

  useEffect(() => check(), [check]);

  const locale = i18n.language as Locale;

  return (
    <main
      style={{
        maxInlineSize: "40rem",
        marginInline: "auto",
        padding: "1.5rem",
        fontFamily: "system-ui",
      }}
    >
      <h1>{t("common:appName")}</h1>
      <h2>{t("shell:title")}</h2>

      <p>
        <strong>{t("shell:status.label")}: </strong>
        <span data-testid="status">
          {state === "checking" ? t("shell:status.checking") : t(`shell:status.${state}`)}
        </span>{" "}
        <button type="button" onClick={check}>
          {t("common:actions.retry")}
        </button>
      </p>

      <label>
        {t("common:language.label")}{" "}
        <select value={locale} onChange={(e) => void i18n.changeLanguage(e.target.value)}>
          {SUPPORTED_LOCALES.map((l) => (
            <option key={l} value={l}>
              {t(`common:language.${l}`)}
            </option>
          ))}
        </select>
      </label>

      <ul>
        {SAMPLES.map((m) => (
          <li key={m.currency}>
            {t("shell:moneySample", { currency: m.currency })}: {formatMoney(m, locale)}
          </li>
        ))}
      </ul>
    </main>
  );
}
