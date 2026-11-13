import type { ComponentProps } from "react";
import { useTranslation } from "react-i18next";
import { RefreshCw } from "lucide-react";
import { cn } from "../lib/utils.ts";

export type SyncChipState = "synced" | "offline" | "syncing" | "error";

export interface SyncChipProps extends Omit<ComponentProps<"button">, "children"> {
  state: SyncChipState;
  queuedCount?: number;
}

/** 4-state offline-first sync pill matching docs/design.md §10. */
export function SyncChip({
  state,
  queuedCount = 0,
  onClick,
  className,
  type = "button",
  ...props
}: SyncChipProps) {
  const { t } = useTranslation("common");

  const base =
    "inline-flex min-h-[36px] items-center gap-2 rounded-full px-3.5 py-1.5 text-xs font-semibold transition-opacity focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-lime";

  const interactive = onClick ? "cursor-pointer hover:opacity-90" : "cursor-default";

  if (state === "offline") {
    return (
      <button
        type={type}
        onClick={onClick}
        className={cn(base, interactive, "border-[1.5px] border-ink-line-2 bg-ink text-text-on-dark", className)}
        {...props}
      >
        <span className="h-2 w-2 shrink-0 rounded-full bg-lime" aria-hidden />
        <span className="font-mono tabular-nums">{t("sync.offlineQueued", { count: queuedCount })}</span>
      </button>
    );
  }

  if (state === "syncing") {
    return (
      <button
        type={type}
        onClick={onClick}
        className={cn(base, interactive, "border-[1.5px] border-ink-line-2 bg-ink text-text-on-dark", className)}
        {...props}
      >
        <RefreshCw size={13} className="shrink-0 animate-spin text-lime" aria-hidden />
        <span>{t("sync.syncing")}</span>
      </button>
    );
  }

  if (state === "error") {
    return (
      <button
        type={type}
        onClick={onClick}
        className={cn(base, interactive, "bg-sw-meal text-sw-meal-fg", className)}
        {...props}
      >
        <span className="h-2 w-2 shrink-0 rounded-full bg-sw-meal-fg" aria-hidden />
        <span>{t("sync.error")}</span>
      </button>
    );
  }

  return (
    <button
      type={type}
      onClick={onClick}
      className={cn(base, interactive, "bg-ok-bg text-ok-fg", className)}
      {...props}
    >
      <span className="h-2 w-2 shrink-0 rounded-full bg-ok-dot" aria-hidden />
      <span>{t("sync.synced")}</span>
    </button>
  );
}
