import i18n, { type BackendModule, type Resource } from "i18next";
import { initReactI18next } from "react-i18next";
import enAuth from "../locales/en/auth.json";
import enCommon from "../locales/en/common.json";
import enShell from "../locales/en/shell.json";

export const SUPPORTED_LOCALES = ["en", "fil"] as const;
export type Locale = (typeof SUPPORTED_LOCALES)[number];

export const ALL_NAMESPACES = ["common", "auth", "shell", "admin", "errors"] as const;
export const PUBLIC_NAMESPACES = ["common", "auth"] as const;
export type Namespace = (typeof ALL_NAMESPACES)[number];

const LOCALE_STORAGE_KEY = "pos.locale";

const LOADERS: Record<Locale, Record<Namespace, () => Promise<{ default: Record<string, unknown> }>>> = {
  en: {
    common: () => Promise.resolve({ default: enCommon }),
    auth: () => Promise.resolve({ default: enAuth }),
    shell: () => Promise.resolve({ default: enShell }),
    admin: () => import("../locales/en/admin.json"),
    errors: () => import("../locales/en/errors.json"),
  },
  fil: {
    common: () => import("../locales/fil/common.json"),
    auth: () => import("../locales/fil/auth.json"),
    shell: () => import("../locales/fil/shell.json"),
    admin: () => import("../locales/fil/admin.json"),
    errors: () => import("../locales/fil/errors.json"),
  },
};

function isNamespace(ns: string): ns is Namespace {
  return (ALL_NAMESPACES as readonly string[]).includes(ns);
}

const lazyLocaleBackend: BackendModule = {
  type: "backend",
  init() {},
  read(language, namespace, callback) {
    const loc = resolveLocale(language);
    if (!isNamespace(namespace)) {
      callback(null, {});
      return;
    }
    void LOADERS[loc][namespace]()
      .then((mod) => callback(null, mod.default))
      .catch((err) => callback(err instanceof Error ? err : new Error(String(err)), null));
  },
};

export function resolveLocale(tag?: string | null): Locale {
  if (!tag) return "en";
  const lower = tag.trim().toLowerCase();
  if (lower.startsWith("fil") || lower === "tl" || lower.startsWith("tl-")) return "fil";
  return "en";
}

function isSupported(tag?: string | null): tag is Locale {
  return Boolean(tag && (SUPPORTED_LOCALES as readonly string[]).includes(tag.trim().toLowerCase()));
}

export function pickLocale(userLocale?: string | null, tenantLocale?: string | null): Locale {
  if (isSupported(userLocale)) return userLocale;
  if (isSupported(tenantLocale)) return tenantLocale;
  return "en";
}

export function storedLocale(): Locale | null {
  try {
    const raw = typeof localStorage !== "undefined" ? localStorage.getItem(LOCALE_STORAGE_KEY) : null;
    return isSupported(raw) ? raw : null;
  } catch {
    return null;
  }
}

export function storeLocale(locale: Locale): void {
  try {
    if (typeof localStorage !== "undefined") {
      localStorage.setItem(LOCALE_STORAGE_KEY, locale);
    }
  } catch {
    // ignore storage failures
  }
}

export function canInitI18nSync(
  locale: Locale,
  namespaces: readonly Namespace[] = PUBLIC_NAMESPACES,
): boolean {
  return locale === "en" && namespaces.every((ns) => ns === "common" || ns === "auth" || ns === "shell");
}

function baseInitOptions(locale: Locale, namespaces: readonly Namespace[]) {
  return {
    lng: locale,
    fallbackLng: "en",
    defaultNS: "common" as const,
    ns: [...namespaces],
    partialBundledLanguages: true,
    resources: {
      en: {
        common: enCommon,
        auth: enAuth,
        shell: enShell,
      },
    },
    interpolation: { escapeValue: false },
    react: { useSuspense: false },
  };
}

const requestedNamespaces = new Set<Namespace>(PUBLIC_NAMESPACES);

function trackNamespaces(namespaces: readonly Namespace[]): void {
  for (const ns of namespaces) requestedNamespaces.add(ns);
}

export function initI18nSync(
  locale: Locale = "en",
  namespaces: readonly Namespace[] = PUBLIC_NAMESPACES,
) {
  trackNamespaces(namespaces);
  if (i18n.isInitialized) return i18n;
  void i18n.use(lazyLocaleBackend).use(initReactI18next).init(baseInitOptions(locale, namespaces));
  return i18n;
}

export async function ensureI18nNamespaces(
  namespaces: readonly Namespace[],
  locale?: Locale,
): Promise<void> {
  trackNamespaces(namespaces);
  if (!i18n.isInitialized) return;
  const target = locale ?? resolveLocale(i18n.language);
  const missing = namespaces.filter((ns) => !i18n.hasResourceBundle(target, ns));
  if (missing.length > 0) {
    const loaded = await Promise.all(
      missing.map(async (ns) => [ns, (await LOADERS[target][ns]()).default] as const),
    );
    for (const [ns, data] of loaded) {
      i18n.addResourceBundle(target, ns, data, true, true);
    }
  }
  if (target !== "en") {
    const missingFallback = namespaces.filter((ns) => !i18n.hasResourceBundle("en", ns));
    if (missingFallback.length > 0) {
      const loadedFallback = await Promise.all(
        missingFallback.map(async (ns) => [ns, (await LOADERS.en[ns]()).default] as const),
      );
      for (const [ns, data] of loadedFallback) {
        i18n.addResourceBundle("en", ns, data, true, true);
      }
    }
  }
}

export async function switchLanguage(locale: Locale): Promise<void> {
  storeLocale(locale);
  const targets = requestedNamespaces.size > 0 ? Array.from(requestedNamespaces) : PUBLIC_NAMESPACES;
  await ensureI18nNamespaces(targets, locale);
  await i18n.changeLanguage(locale);
}

export async function initI18n(
  locale: Locale = storedLocale() ?? resolveLocale(globalThis.navigator?.language),
  opts?: { namespaces?: readonly Namespace[] },
) {
  const targetNs = opts?.namespaces ?? ALL_NAMESPACES;
  trackNamespaces(targetNs);

  if (!i18n.isInitialized) {
    if (canInitI18nSync(locale, targetNs)) {
      initI18nSync(locale, targetNs);
      return i18n;
    }
    const base = baseInitOptions(locale, targetNs);
    const enResources: Record<string, Record<string, unknown>> = { ...base.resources.en };
    const resources: Resource = { en: enResources };
    await Promise.all([
      ...targetNs
        .filter((ns) => !(locale === "en" && (ns === "common" || ns === "auth" || ns === "shell")))
        .map(async (ns) => {
          const langBucket = (resources[locale] ??= {}) as Record<string, Record<string, unknown>>;
          langBucket[ns] = (await LOADERS[locale][ns]()).default;
        }),
      ...(locale !== "en"
        ? targetNs
            .filter((ns) => ns === "admin" || ns === "errors")
            .map(async (ns) => {
              enResources[ns] = (await LOADERS.en[ns]()).default;
            })
        : []),
    ]);
    await i18n.use(lazyLocaleBackend).use(initReactI18next).init({
      ...base,
      resources,
    });
    return i18n;
  }

  await ensureI18nNamespaces(targetNs, locale);
  if (i18n.language !== locale) {
    await i18n.changeLanguage(locale);
  }
  return i18n;
}

export default i18n;
