import type { ComponentProps } from "react";
import { cn } from "../lib/utils.ts";

export interface ReceiptProps extends ComponentProps<"div"> {
  edge?: "bottom" | "top";
}

/** Warm --paper receipt card with torn zig-zag edge and dashed divider helper. */
export function Receipt({ edge = "bottom", className, children, ...props }: ReceiptProps) {
  return (
    <div
      className={cn(
        edge === "top" ? "receipt-pullup rounded-t-[24px]" : "receipt rounded-t-[24px]",
        "px-6 py-6 text-text-on-light",
        className,
      )}
      {...props}
    >
      {children}
    </div>
  );
}

/** Dashed 1.5px receipt divider matching docs/design.md §5a. */
export function ReceiptDash({ className }: { className?: string }) {
  return <hr className={cn("dash my-4", className)} />;
}
