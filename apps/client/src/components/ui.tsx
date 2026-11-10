// Small shadcn-style primitives. Dialog is Radix; the rest are plain elements with Tailwind classes.
import { createContext, useCallback, useContext, useMemo, useState, type ComponentProps, type ReactNode } from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { Dialog as RadixDialog, Tabs as RadixTabs, Toast as RadixToast } from "radix-ui";
import { AlertTriangle, CheckCircle2, Inbox, Info, X } from "lucide-react";
import { cn } from "../lib/utils.ts";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 rounded-md text-sm font-medium transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-600 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        primary: "bg-brand-600 text-[#fff] hover:bg-brand-700",
        outline: "border border-slate-300 bg-white hover:bg-slate-100",
        danger: "bg-[#dc2626] text-[#fff] hover:bg-[#b91c1c]",
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
  "h-9 w-full rounded-md border border-slate-300 bg-white px-3 text-sm focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-brand-600 disabled:bg-slate-100 disabled:text-slate-500";

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
        <RadixDialog.Overlay className="fixed inset-0 bg-black/50" />
        <RadixDialog.Content
          aria-describedby={undefined}
          className="fixed top-1/2 left-1/2 max-h-[90vh] w-[min(32rem,92vw)] -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-lg border border-slate-200 bg-white p-5 shadow-xl"
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

/** Page title with an optional line under it and actions on the right. One per screen. */
export function PageHeader({ title, subtitle, actions }: { title: string; subtitle?: string; actions?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">{title}</h1>
        {subtitle ? <p className="text-sm text-slate-500">{subtitle}</p> : null}
      </div>
      {actions ? <div className="flex flex-wrap items-center gap-2">{actions}</div> : null}
    </div>
  );
}

/** Nothing here yet: say so, and offer the next step. */
export function EmptyState({ title, hint, action }: { title: string; hint?: string; action?: ReactNode }) {
  return (
    <div className="grid justify-items-center gap-2 rounded-lg border border-dashed border-slate-300 px-4 py-10 text-center">
      <Inbox size={28} className="text-slate-400" aria-hidden />
      <p className="font-medium">{title}</p>
      {hint ? <p className="max-w-sm text-sm text-slate-500">{hint}</p> : null}
      {action}
    </div>
  );
}

/** A load or save failed: the reason, and a way to try again. */
export function ErrorState({ message, retryLabel, onRetry }: { message: string; retryLabel?: string; onRetry?: () => void }) {
  return (
    <div role="alert" className="flex flex-wrap items-center gap-3 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
      <AlertTriangle size={18} aria-hidden />
      <span className="mr-auto">{message}</span>
      {onRetry && retryLabel ? (
        <Button variant="outline" size="sm" onClick={onRetry}>
          {retryLabel}
        </Button>
      ) : null}
    </div>
  );
}

const tableClass =
  "w-full text-left text-sm [&_thead_th]:bg-slate-50 [&_thead_th]:px-3 [&_thead_th]:py-2 [&_thead_th]:text-xs [&_thead_th]:font-medium [&_thead_th]:tracking-wide [&_thead_th]:text-slate-500 [&_thead_th]:uppercase [&_tbody_tr]:border-t [&_tbody_tr]:border-slate-100 [&_tbody_tr:hover]:bg-slate-50";

/**
 * Data table: quiet uppercase header, row dividers, hover row. Header and row styling comes from the table itself,
 * so plain th/td work. `bare` skips the bordered scroll wrapper, for a table that already sits in a Card.
 */
export function Table({ className, bare, ...props }: ComponentProps<"table"> & { bare?: boolean }) {
  const table = <table className={cn(tableClass, className)} {...props} />;
  if (bare) return table;
  return <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white">{table}</div>;
}

export function Th({ className, numeric, ...props }: ComponentProps<"th"> & { numeric?: boolean }) {
  return (
    <th
      scope="col"
      className={cn("bg-slate-50 px-3 py-2 text-xs font-medium tracking-wide text-slate-500 uppercase", numeric && "text-right", className)}
      {...props}
    />
  );
}

export function Td({ className, numeric, ...props }: ComponentProps<"td"> & { numeric?: boolean }) {
  return <td className={cn("px-3 py-2", numeric && "text-right tabular-nums", className)} {...props} />;
}

/** Tabs (Radix: arrow keys, roles and focus come for free). Pass the panels as TabPanel children. */
export function Tabs({
  value,
  onValueChange,
  tabs,
  children,
  label,
}: {
  value: string;
  onValueChange: (v: string) => void;
  tabs: ReadonlyArray<{ value: string; label: string; testId?: string }>;
  children: ReactNode;
  label: string;
}) {
  return (
    <RadixTabs.Root value={value} onValueChange={onValueChange} className="grid gap-4">
      <RadixTabs.List aria-label={label} className="flex gap-1 overflow-x-auto border-b border-slate-200">
        {tabs.map((tab) => (
          <RadixTabs.Trigger
            key={tab.value}
            value={tab.value}
            data-testid={tab.testId}
            className="-mb-px border-b-2 border-transparent px-3 py-2 text-sm whitespace-nowrap text-slate-600 hover:text-slate-900 data-[state=active]:border-brand-600 data-[state=active]:font-medium data-[state=active]:text-slate-900"
          >
            {tab.label}
          </RadixTabs.Trigger>
        ))}
      </RadixTabs.List>
      {children}
    </RadixTabs.Root>
  );
}

export function TabPanel({ value, children }: { value: string; children: ReactNode }) {
  return <RadixTabs.Content value={value}>{children}</RadixTabs.Content>;
}

export type ToastTone = "good" | "warn" | "error" | "info";

export interface ToastMessage {
  id: string;
  title?: string;
  message: string;
  tone: ToastTone;
  duration?: number;
}

export interface ToastContextValue {
  toast: (message: string, opts?: { title?: string; tone?: ToastTone; duration?: number }) => void;
  good: (message: string, opts?: { title?: string; duration?: number }) => void;
  error: (message: string, opts?: { title?: string; duration?: number }) => void;
  warn: (message: string, opts?: { title?: string; duration?: number }) => void;
  info: (message: string, opts?: { title?: string; duration?: number }) => void;
}

const ToastContext = createContext<ToastContextValue | null>(null);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<ToastMessage[]>([]);

  const dismiss = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const addToast = useCallback((message: string, opts?: { title?: string; tone?: ToastTone; duration?: number }) => {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    const tone = opts?.tone ?? "info";
    const item: ToastMessage = {
      id,
      title: opts?.title,
      message,
      tone,
      duration: opts?.duration ?? (tone === "error" ? 6000 : 3500),
    };
    setToasts((prev) => [...prev, item]);
  }, []);

  const value = useMemo<ToastContextValue>(
    () => ({
      toast: addToast,
      good: (msg, opts) => addToast(msg, { ...opts, tone: "good" }),
      error: (msg, opts) => addToast(msg, { ...opts, tone: "error" }),
      warn: (msg, opts) => addToast(msg, { ...opts, tone: "warn" }),
      info: (msg, opts) => addToast(msg, { ...opts, tone: "info" }),
    }),
    [addToast],
  );

  return (
    <ToastContext.Provider value={value}>
      <RadixToast.Provider swipeDirection="right">
        {children}
        {toasts.map((t) => {
          const isError = t.tone === "error";
          const isGood = t.tone === "good";
          const isWarn = t.tone === "warn";
          return (
            <RadixToast.Root
              key={t.id}
              duration={t.duration}
              onOpenChange={(open) => {
                if (!open) dismiss(t.id);
              }}
              className={cn(
                "group pointer-events-auto relative flex w-full items-start gap-3 rounded-lg border p-3.5 shadow-lg transition-all",
                "bg-white",
                isGood && "border-green-200 text-green-900 bg-green-50/50",
                isError && "border-red-200 text-red-900 bg-red-50/50",
                isWarn && "border-amber-200 text-amber-900 bg-amber-50/50",
                !isGood && !isError && !isWarn && "border-slate-200 text-slate-900",
              )}
            >
              <span className="shrink-0 mt-0.5">
                {isGood ? (
                  <CheckCircle2 size={18} className="text-emerald-600" aria-hidden />
                ) : isError ? (
                  <AlertTriangle size={18} className="text-red-600" aria-hidden />
                ) : isWarn ? (
                  <AlertTriangle size={18} className="text-amber-600" aria-hidden />
                ) : (
                  <Info size={18} className="text-brand-600" aria-hidden />
                )}
              </span>
              <div className="grid gap-0.5 flex-1 text-sm">
                {t.title ? (
                  <RadixToast.Title className="font-semibold text-xs tracking-wide uppercase">
                    {t.title}
                  </RadixToast.Title>
                ) : null}
                <RadixToast.Description className="text-sm font-medium">
                  {t.message}
                </RadixToast.Description>
              </div>
              <RadixToast.Close
                aria-label="Close"
                className="shrink-0 rounded p-1 text-slate-400 hover:bg-slate-100 hover:text-slate-700 transition-colors"
              >
                <X size={16} />
              </RadixToast.Close>
            </RadixToast.Root>
          );
        })}
        <RadixToast.Viewport className="fixed bottom-4 right-4 z-50 flex max-h-screen w-full max-w-sm flex-col gap-2 p-4 pointer-events-none outline-none sm:bottom-6 sm:right-6" />
      </RadixToast.Provider>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext);
  if (!ctx) {
    return {
      toast: () => {},
      good: () => {},
      error: () => {},
      warn: () => {},
      info: () => {},
    };
  }
  return ctx;
}
