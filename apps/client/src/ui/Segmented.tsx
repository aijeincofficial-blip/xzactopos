import { cn } from "../lib/utils.ts";

export interface SegmentedOption<T extends string> {
  value: T;
  label: string;
}

/** Sand track segmented control (4px padding); active segment renders --ink fill with light text. */
export function Segmented<T extends string>({
  options,
  value,
  onChange,
  className,
  "aria-label": ariaLabel,
}: {
  options: ReadonlyArray<SegmentedOption<T>>;
  value: T;
  onChange: (next: T) => void;
  className?: string;
  "aria-label"?: string;
}) {
  return (
    <div
      role="group"
      aria-label={ariaLabel}
      className={cn(
        "inline-flex flex-wrap items-center gap-1 rounded-full border-[1.5px] border-sand-line bg-sand p-1",
        className,
      )}
    >
      {options.map((opt) => {
        const active = opt.value === value;
        return (
          <button
            key={opt.value}
            type="button"
            aria-pressed={active}
            onClick={() => onChange(opt.value)}
            className={cn(
              "inline-flex min-h-[36px] cursor-pointer items-center justify-center rounded-full px-4 py-1.5 text-sm font-semibold transition-colors focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-ink",
              active ? "bg-ink text-text-on-dark" : "text-muted-on-light hover:text-text-on-light",
            )}
          >
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}
