// Small shadcn-style primitives. Dialog is Radix; the rest are plain elements with Tailwind classes.
import type { ComponentProps, ReactNode } from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { Dialog as RadixDialog } from "radix-ui";
import { X } from "lucide-react";
import { cn } from "../lib/utils.ts";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 rounded-md text-sm font-medium transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-900 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        primary: "bg-slate-900 text-white hover:bg-slate-700",
        outline: "border border-slate-300 bg-white hover:bg-slate-100",
        danger: "bg-red-600 text-white hover:bg-red-700",
        ghost: "hover:bg-slate-100",
      },
      size: { md: "h-9 px-4", sm: "h-8 px-3" },
    },
    defaultVariants: { variant: "primary", size: "md" },
  },
);

export function Button({
  className,
  variant,
  size,
  type = "button",
  ...props
}: ComponentProps<"button"> & VariantProps<typeof buttonVariants>) {
  return <button type={type} className={cn(buttonVariants({ variant, size }), className)} {...props} />;
}

const field =
  "h-9 w-full rounded-md border border-slate-300 bg-white px-3 text-sm focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-slate-900 disabled:bg-slate-100 disabled:text-slate-500";

export function Input({ className, ...props }: ComponentProps<"input">) {
  return <input className={cn(field, className)} {...props} />;
}

export function Select({ className, ...props }: ComponentProps<"select">) {
  return <select className={cn(field, className)} {...props} />;
}

export function Field({
  label,
  hint,
  error,
  children,
}: {
  label: string;
  hint?: string;
  error?: string | undefined;
  children: ReactNode;
}) {
  return (
    <label className="grid gap-1 text-sm">
      <span className="font-medium">{label}</span>
      {children}
      {hint && !error ? <span className="text-xs text-slate-500">{hint}</span> : null}
      {error ? (
        <span role="alert" className="text-xs text-red-600">
          {error}
        </span>
      ) : null}
    </label>
  );
}

export function Card({ className, ...props }: ComponentProps<"section">) {
  return <section className={cn("rounded-lg border border-slate-200 bg-white p-4 shadow-sm", className)} {...props} />;
}

export function Alert({ tone = "error", children }: { tone?: "error" | "info"; children: ReactNode }) {
  return (
    <p
      role={tone === "error" ? "alert" : "status"}
      className={cn(
        "rounded-md border px-3 py-2 text-sm",
        tone === "error" ? "border-red-200 bg-red-50 text-red-800" : "border-slate-200 bg-slate-100 text-slate-700",
      )}
    >
      {children}
    </p>
  );
}

export function Badge({ children, tone = "neutral" }: { children: ReactNode; tone?: "neutral" | "good" | "warn" }) {
  return (
    <span
      className={cn(
        "inline-block rounded-full px-2 py-0.5 text-xs font-medium",
        tone === "good" && "bg-green-100 text-green-800",
        tone === "warn" && "bg-amber-100 text-amber-800",
        tone === "neutral" && "bg-slate-100 text-slate-700",
      )}
    >
      {children}
    </span>
  );
}

export function Dialog({
  open,
  onOpenChange,
  title,
  closeLabel,
  children,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  closeLabel: string;
  children: ReactNode;
}) {
  return (
    <RadixDialog.Root open={open} onOpenChange={onOpenChange}>
      <RadixDialog.Portal>
        <RadixDialog.Overlay className="fixed inset-0 bg-slate-900/40" />
        <RadixDialog.Content
          aria-describedby={undefined}
          className="fixed top-1/2 left-1/2 max-h-[90vh] w-[min(32rem,92vw)] -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-lg bg-white p-5 shadow-xl"
        >
          <div className="mb-4 flex items-center justify-between">
            <RadixDialog.Title className="text-lg font-semibold">{title}</RadixDialog.Title>
            <RadixDialog.Close aria-label={closeLabel} className="rounded p-1 hover:bg-slate-100">
              <X size={18} />
            </RadixDialog.Close>
          </div>
          {children}
        </RadixDialog.Content>
      </RadixDialog.Portal>
    </RadixDialog.Root>
  );
}
