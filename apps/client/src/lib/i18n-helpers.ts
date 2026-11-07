import { useTranslation } from "react-i18next";
import { ApiError } from "./api.ts";

/** Translate a dynamic key (validation messages, API error hints). Unknown keys fall back to `fallback`. */
export function useDynamicT() {
  const { i18n } = useTranslation();
  return (ns: string, key: string, fallbackKey?: string): string => {
    if (i18n.exists(`${ns}:${key}`)) return i18n.t(`${ns}:${key}` as never) as string;
    if (fallbackKey) return i18n.t(`${ns}:${fallbackKey}` as never) as string;
    return key;
  };
}

/** Message for any thrown value, via the stable hint key on ApiError. */
export function useErrorMessage() {
  const tr = useDynamicT();
  return (e: unknown): string => tr("errors", e instanceof ApiError ? e.key : "unknown", "unknown");
}

/** Message for a zod issue (the message is a `validation.*` key in the errors namespace). */
export function useValidationMessage() {
  const tr = useDynamicT();
  return (key: string | undefined): string | undefined => (key ? tr("errors", key, "validation.required") : undefined);
}
