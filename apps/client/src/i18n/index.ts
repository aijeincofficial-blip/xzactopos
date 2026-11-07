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

/** Locale for a signed-in user: their own choice, else the tenant default, else English. */
export function pickLocale(profileLocale: string | null | undefined, tenantDefault: string | null | undefined): Locale {
  for (const c of [profileLocale, tenantDefault]) {
    if (c && (SUPPORTED_LOCALES as readonly string[]).includes(c)) return c as Locale;
  }
  return "en";
}

const LOCALE_KEY = "pos.locale";

/** Last chosen language on this device, so sign-in pages match before anyone is signed in. */
export function storedLocale(): Locale | null {
  try {
    const v = localStorage.getItem(LOCALE_KEY);
    return v && (SUPPORTED_LOCALES as readonly string[]).includes(v) ? (v as Locale) : null;
  } catch {
    return null;
  }
}

export function storeLocale(locale: Locale) {
  try {
    localStorage.setItem(LOCALE_KEY, locale);
  } catch {
    /* storage can be blocked; this is only a convenience */
  }
}

export async function initI18n(locale: Locale = storedLocale() ?? resolveLocale(globalThis.navigator?.language)) {
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
