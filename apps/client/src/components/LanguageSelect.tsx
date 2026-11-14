import { useTranslation } from "react-i18next";
import { SUPPORTED_LOCALES, switchLanguage, type Locale } from "../i18n/index.ts";

export function LanguageSelect({ onChoose }: { onChoose?: (locale: Locale) => void }) {
  const { t, i18n } = useTranslation("common");
  return (
    <select
      aria-label={t("language.label")}
      className="min-h-[44px] w-auto cursor-pointer rounded-[14px] border-[1.5px] border-slate-300 bg-white px-3.5 py-2 text-sm text-slate-900 transition-colors focus:border-slate-900 focus:outline-none"
      value={i18n.language}
      onChange={(e) => {
        const l = e.target.value as Locale;
        void switchLanguage(l);
        onChoose?.(l);
      }}
    >
      {SUPPORTED_LOCALES.map((l) => (
        <option key={l} value={l}>
          {t(`language.${l}`)}
        </option>
      ))}
    </select>
  );
}
