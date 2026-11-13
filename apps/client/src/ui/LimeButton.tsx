import type { ComponentProps } from "react";
import { cn } from "../lib/utils.ts";

export const LIME_BUTTON_CLASSES =
  "inline-flex min-h-[44px] cursor-pointer items-center justify-center gap-2 rounded-full bg-lime px-7 py-3.5 text-center text-[15px] font-semibold text-ink transition-colors hover:bg-lime-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-lime disabled:cursor-not-allowed disabled:bg-disabled-bg disabled:text-disabled-fg";

export const GHOST_BUTTON_CLASSES =
  "inline-flex min-h-[44px] cursor-pointer items-center justify-center gap-2 rounded-full border-[1.5px] border-ink-line-2 bg-transparent px-6 py-3 text-center text-[15px] font-semibold text-text-on-dark transition-colors hover:border-lime hover:text-lime focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-lime disabled:cursor-not-allowed disabled:opacity-50";

/** Primary night-market CTA button: acid-lime surface, ink text, full pill radius, 44px+ touch target. */
export function LimeButton({
  className,
  type = "button",
  children,
  ...props
}: ComponentProps<"button">) {
  return (
    <button
      type={type}
      className={cn(LIME_BUTTON_CLASSES, className)}
      {...props}
    >
      {children}
    </button>
  );
}

/** Secondary ghost button on dark --ink surfaces: 1.5px --ink-line-2 border turning --lime on hover. */
export function GhostButton({
  className,
  type = "button",
  children,
  ...props
}: ComponentProps<"button">) {
  return (
    <button
      type={type}
      className={cn(GHOST_BUTTON_CLASSES, className)}
      {...props}
    >
      {children}
    </button>
  );
}
