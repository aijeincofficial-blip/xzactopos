import { useTranslation } from "react-i18next";
import { formatMoney, money } from "@pos/core";
import { cn } from "../lib/utils.ts";

export interface MoneyTextProps {
  /** Integer minor units (e.g. centavos). */
  minor: number;
  currency?: string;
  /** Final register TOTAL uses Bricolage Grotesque 800; all other money values use JetBrains Mono. */
  variant?: "mono" | "total" | "stat";
  className?: string;
}

/** Single money formatter using @pos/core Intl formatting + tabular-nums (design.md §3). */
export function MoneyText({
  minor,
  currency = "PHP",
  variant = "mono",
  className,
}: MoneyTextProps) {
  const { i18n } = useTranslation();
  const formatted = formatMoney(money(minor, currency), i18n.language || "en");

  if (variant === "total") {
    return (
      <span className={cn("font-display text-[34px] font-extrabold leading-none tracking-[-0.03em] tabular-nums", className)}>
        {formatted}
      </span>
    );
  }
  if (variant === "stat") {
    return (
      <span className={cn("font-display text-[40px] font-extrabold leading-none tracking-[-0.03em] tabular-nums", className)}>
        {formatted}
      </span>
    );
  }
  return <span className={cn("font-mono tabular-nums", className)}>{formatted}</span>;
}
