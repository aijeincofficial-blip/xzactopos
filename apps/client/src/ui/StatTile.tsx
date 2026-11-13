import type { ReactNode } from "react";
import { cn } from "../lib/utils.ts";

/** Paper metric card with mono uppercase eyebrow and Bricolage 800 40px stat figure. */
export function StatTile({
  eyebrow,
  value,
  meta,
  className,
}: {
  eyebrow: string;
  value: ReactNode;
  meta?: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "grid gap-2 rounded-[24px] border-[1.5px] border-sand-line bg-paper p-6 text-text-on-light",
        className,
      )}
    >
      <span className="font-mono text-xs tracking-[0.08em] text-muted-on-light uppercase">
        {eyebrow}
      </span>
      <div className="font-display text-[40px] font-extrabold leading-none tracking-[-0.03em] tabular-nums">
        {value}
      </div>
      {meta ? <div className="text-sm text-muted-on-light">{meta}</div> : null}
    </div>
  );
}
