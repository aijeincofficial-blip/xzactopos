import type { LucideIcon } from "lucide-react";
import { cn } from "../lib/utils.ts";
import { LimeButton } from "./LimeButton.tsx";

/** Empty state matching design.md §7: stroke icon, one clear sentence, and optional LimeButton action. */
export function EmptyState({
  icon: Icon,
  message,
  actionLabel,
  onAction,
  className,
}: {
  icon: LucideIcon;
  message: string;
  actionLabel?: string;
  onAction?: () => void;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "grid justify-items-center gap-4 rounded-[24px] border-[1.5px] border-dashed border-sand-line bg-paper px-6 py-12 text-center text-text-on-light",
        className,
      )}
    >
      <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-sand text-ink">
        <Icon size={24} strokeWidth={2} aria-hidden />
      </div>
      <p className="max-w-md text-base text-muted-on-light">{message}</p>
      {actionLabel && onAction ? (
        <LimeButton onClick={onAction}>{actionLabel}</LimeButton>
      ) : null}
    </div>
  );
}
