import { useTranslation } from "react-i18next";
import { SUPPORTED_LOCALES } from "../i18n/index.ts";
import { Select } from "./ui.tsx";

export function LanguageSelect() {
  const { t, i18n } = useTranslation("common");
  return (
    <Select
      aria-label={t("language.label")}
      className="w-auto"
      value={i18n.language}
      onChange={(e) => void i18n.changeLanguage(e.target.value)}
    >
      {SUPPORTED_LOCALES.map((l) => (
        <option key={l} value={l}>
          {t(`language.${l}`)}
        </option>
      ))}
    </Select>
  );
}
