import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import enAdmin from "../locales/en/admin.json";
import enAuth from "../locales/en/auth.json";
import enCommon from "../locales/en/common.json";
import enErrors from "../locales/en/errors.json";
import enShell from "../locales/en/shell.json";
import filAdmin from "../locales/fil/admin.json";
import filAuth from "../locales/fil/auth.json";
import filCommon from "../locales/fil/common.json";
import filErrors from "../locales/fil/errors.json";
import filShell from "../locales/fil/shell.json";

// Locale files are bundled so the app works offline.
export const resources = {
  en: { common: enCommon, shell: enShell, auth: enAuth, admin: enAdmin, errors: enErrors },
  fil: { common: filCommon, shell: filShell, auth: filAuth, admin: filAdmin, errors: filErrors },
} as const;

export const SUPPORTED_LOCALES = ["en", "fil"] as const;
export type Locale = (typeof SUPPORTED_LOCALES)[number];

export function resolveLocale(input: string | undefined | null): Locale {
  const base = (input ?? "").toLowerCase().split("-")[0];
  if (base === "tl" || base === "fil") return "fil";
  return "en";
}

export async function initI18n(locale: Locale = resolveLocale(globalThis.navigator?.language)) {
  await i18n.use(initReactI18next).init({
    resources,
    lng: locale,
    fallbackLng: "en",
    defaultNS: "common",
    ns: Object.keys(resources.en),
    interpolation: { escapeValue: false },
  });
  return i18n;
}

export default i18n;
