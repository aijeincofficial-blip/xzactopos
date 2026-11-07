import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import enCommon from "../locales/en/common.json";
import enShell from "../locales/en/shell.json";
import filCommon from "../locales/fil/common.json";
import filShell from "../locales/fil/shell.json";

// Locale files are bundled so the app works offline.
export const resources = {
  en: { common: enCommon, shell: enShell },
  fil: { common: filCommon, shell: filShell },
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
    ns: ["common", "shell"],
    interpolation: { escapeValue: false },
  });
  return i18n;
}

export default i18n;
