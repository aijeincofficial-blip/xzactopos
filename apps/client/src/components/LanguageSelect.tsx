import { useTranslation } from "react-i18next";
import { SUPPORTED_LOCALES, storeLocale, type Locale } from "../i18n/index.ts";
import { Select } from "./ui.tsx";

export function LanguageSelect({ onChoose }: { onChoose?: (locale: Locale) => void }) {
  const { t, i18n } = useTranslation("common");
  return (
    <Select
      aria-label={t("language.label")}
      className="w-auto"
      value={i18n.language}
      onChange={(e) => {
        const l = e.target.value as Locale;
        void i18n.changeLanguage(l);
        storeLocale(l);
        onChoose?.(l);
      }}
    >
      {SUPPORTED_LOCALES.map((l) => (
        <option key={l} value={l}>
          {t(`language.${l}`)}
        </option>
      ))}
    </Select>
  );
}
