import type { ComponentProps } from "react";
import { cn } from "../lib/utils.ts";

export interface PillProps extends ComponentProps<"button"> {
  active?: boolean;
  count?: number;
  tone?: "light" | "dark";
}

/** Filter / category pill (min-h 44px): paper + sand-line on light, ink fill when active; optional mono count. */
export function Pill({
  active = false,
  count,
  tone = "light",
  type = "button",
  className,
  children,
  ...props
}: PillProps) {
  const lightClasses = active
    ? "border-ink bg-ink text-text-on-dark"
    : "border-sand-line bg-paper text-text-on-light hover:border-ink";
  const darkClasses = active
    ? "border-lime bg-lime text-ink"
    : "border-ink-line-2 bg-ink-2 text-text-on-dark hover:border-lime hover:text-lime";

  return (
    <button
      type={type}
      aria-pressed={active}
      className={cn(
        "inline-flex min-h-[44px] cursor-pointer items-center justify-center gap-2 rounded-full border-[1.5px] px-4 py-2 text-sm font-semibold transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-lime",
        tone === "dark" ? darkClasses : lightClasses,
        className,
      )}
      {...props}
    >
      <span>{children}</span>
      {count !== undefined ? (
        <span
          className={cn(
            "font-mono text-xs font-semibold tabular-nums",
            active
              ? tone === "dark"
                ? "text-ink"
                : "text-lime"
              : tone === "dark"
                ? "text-muted-on-dark"
                : "text-muted-on-light",
          )}
        >
          {count}
        </span>
      ) : null}
    </button>
  );
}
