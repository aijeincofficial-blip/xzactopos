// Small shadcn-style primitives. Dialog, Tabs, and Toast use Radix; the rest are clean semantic Tailwind components.
import { createContext, useCallback, useContext, useMemo, useState, type ComponentProps, type ReactNode } from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { Dialog as RadixDialog, Tabs as RadixTabs, Toast as RadixToast } from "radix-ui";
import { AlertTriangle, CheckCircle2, Inbox, Info, X } from "lucide-react";
import { cn } from "../lib/utils.ts";

const buttonVariants = cva(
  "inline-flex cursor-pointer items-center justify-center gap-2 rounded-lg text-sm font-semibold transition-all focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-600 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        primary: "bg-brand-600 text-white shadow-xs hover:bg-brand-700 active:translate-y-[0.5px]",
        outline:
          "border border-slate-200/90 bg-white text-slate-700 shadow-xs hover:border-slate-300 hover:bg-slate-50 hover:text-slate-900",
        danger: "bg-red-600 text-white shadow-xs hover:bg-red-700 active:translate-y-[0.5px]",
        ghost: "text-slate-600 hover:bg-slate-100 hover:text-slate-900",
      },
      size: { md: "h-9.5 px-4", sm: "h-8 px-3 text-xs" },
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
  "h-9.5 w-full rounded-lg border border-slate-200 bg-white px-3 text-sm font-normal text-slate-900 shadow-2xs transition-colors placeholder:text-slate-400 hover:border-slate-300 focus-visible:border-brand-500 focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-brand-600 disabled:bg-slate-100 disabled:text-slate-500";

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
    <label className="grid gap-1.5 text-sm">
      <span className="text-xs font-semibold text-slate-700">{label}</span>
      {children}
      {hint && !error ? <span className="text-xs text-slate-500">{hint}</span> : null}
      {error ? (
        <span role="alert" className="text-xs font-medium text-red-700">
          {error}
        </span>
      ) : null}
    </label>
  );
}

export function Card({ className, ...props }: ComponentProps<"section">) {
  return (
    <section
      className={cn("rounded-xl border border-slate-200/90 bg-white p-5 shadow-xs sm:p-6", className)}
      {...props}
    />
  );
}

export function Alert({ tone = "error", children }: { tone?: "error" | "info" | "warn" | "good"; children: ReactNode }) {
  return (
    <div
      role={tone === "error" ? "alert" : "status"}
      className={cn(
        "rounded-lg border-l-4 px-4 py-3 text-sm font-normal shadow-2xs",
        tone === "error" && "border-red-500 border-y border-r border-y-red-200 border-r-red-200 bg-red-50 text-red-900",
        tone === "info" && "border-brand-500 border-y border-r border-y-brand-200 border-r-brand-200 bg-brand-50 text-slate-900",
        tone === "warn" && "border-amber-500 border-y border-r border-y-amber-200 border-r-amber-200 bg-amber-50 text-amber-900",
        tone === "good" && "border-emerald-500 border-y border-r border-y-emerald-200 border-r-emerald-200 bg-emerald-50 text-emerald-900",
      )}
    >
      {children}
    </div>
  );
}

export function Badge({
  children,
  tone = "neutral",
}: {
  children: ReactNode;
  tone?: "neutral" | "good" | "warn" | "danger";
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-md border px-2 py-0.5 text-xs font-semibold",
        tone === "good" && "border-green-200/80 bg-green-50 text-green-900",
        tone === "warn" && "border-amber-200/80 bg-amber-50 text-amber-900",
        tone === "danger" && "border-red-200/80 bg-red-50 text-red-900",
        tone === "neutral" && "border-slate-200/80 bg-slate-100 text-slate-800",
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
        <RadixDialog.Overlay className="fixed inset-0 z-50 bg-slate-950/45 backdrop-blur-[1px]" />
        <RadixDialog.Content
          aria-describedby={undefined}
          className="fixed top-1/2 left-1/2 z-50 max-h-[90vh] w-[min(32rem,92vw)] -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-xl border border-slate-200 bg-white p-6 shadow-xl"
        >
          <div className="mb-4 flex items-center justify-between gap-3">
            <RadixDialog.Title className="text-lg font-semibold tracking-tight text-slate-900">{title}</RadixDialog.Title>
            <RadixDialog.Close
              aria-label={closeLabel}
              className="rounded-lg p-1.5 text-slate-500 transition-colors hover:bg-slate-100 hover:text-slate-900"
            >
              <X size={18} />
            </RadixDialog.Close>
          </div>
          {children}
        </RadixDialog.Content>
      </RadixDialog.Portal>
    </RadixDialog.Root>
  );
}

/** Page title with an optional calm subtitle and right-aligned primary/secondary actions. */
export function PageHeader({ title, subtitle, actions }: { title: string; subtitle?: string; actions?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-center justify-between gap-3">
      <div className="grid gap-0.5">
        <h1 className="text-xl font-semibold tracking-tight text-slate-900">{title}</h1>
        {subtitle ? <p className="text-sm text-slate-500">{subtitle}</p> : null}
      </div>
      {actions ? <div className="flex flex-wrap items-center gap-2">{actions}</div> : null}
    </div>
  );
}

/** Nothing here yet: say so calmly, and offer the next step. */
export function EmptyState({ title, hint, action }: { title: string; hint?: string; action?: ReactNode }) {
  return (
    <div className="grid justify-items-center gap-2.5 rounded-xl border border-dashed border-slate-200 bg-slate-50/60 px-6 py-10 text-center">
      <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-slate-100 text-slate-400">
        <Inbox size={22} aria-hidden />
      </div>
      <p className="text-sm font-semibold text-slate-900">{title}</p>
      {hint ? <p className="max-w-sm text-xs text-slate-500">{hint}</p> : null}
      {action ? <div className="mt-1">{action}</div> : null}
    </div>
  );
}

/** A load or save failed: the reason, and a way to try again. */
export function ErrorState({
  message,
  retryLabel,
  onRetry,
}: {
  message: string;
  retryLabel?: string;
  onRetry?: () => void;
}) {
  return (
    <div
      role="alert"
      className="flex flex-wrap items-center gap-3 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-900 shadow-2xs"
    >
      <AlertTriangle size={18} className="shrink-0 text-red-600" aria-hidden />
      <span className="mr-auto font-normal">{message}</span>
      {onRetry && retryLabel ? (
        <Button variant="outline" size="sm" onClick={onRetry}>
          {retryLabel}
        </Button>
      ) : null}
    </div>
  );
}

const tableClass =
  "w-full text-left text-sm [&_thead_th]:bg-slate-50/90 [&_thead_th]:px-3.5 [&_thead_th]:py-2.5 [&_thead_th]:text-xs [&_thead_th]:font-semibold [&_thead_th]:tracking-wider [&_thead_th]:text-slate-500 [&_thead_th]:uppercase [&_tbody_tr]:border-t [&_tbody_tr]:border-slate-100 [&_tbody_tr]:transition-colors [&_tbody_tr:hover]:bg-slate-50/80";

/**
 * Data table: quiet uppercase header, subtle row dividers, calm hover row.
 * `bare` skips the bordered scroll wrapper, for a table that already sits inside a Card.
 */
export function Table({ className, bare, ...props }: ComponentProps<"table"> & { bare?: boolean }) {
  const table = <table className={cn(tableClass, className)} {...props} />;
  if (bare) return table;
  return <div className="overflow-x-auto rounded-xl border border-slate-200/90 bg-white shadow-xs">{table}</div>;
}

export function Th({ className, numeric, ...props }: ComponentProps<"th"> & { numeric?: boolean }) {
  return (
    <th
      scope="col"
      className={cn(
        "bg-slate-50/90 px-3.5 py-2.5 text-xs font-semibold tracking-wider text-slate-500 uppercase",
        numeric && "text-right",
        className,
      )}
      {...props}
    />
  );
}

export function Td({ className, numeric, ...props }: ComponentProps<"td"> & { numeric?: boolean }) {
  return <td className={cn("px-3.5 py-2.5 text-slate-900", numeric && "text-right tabular-nums", className)} {...props} />;
}

/** Loading skeleton block: matches content layout and size to prevent layout shift */
export function Skeleton({ className, ...props }: ComponentProps<"div">) {
  return <div className={cn("animate-pulse rounded-lg bg-slate-200/80", className)} {...props} />;
}

/** Pre-built table loading skeleton matching common data table column layouts */
export function TableSkeleton({ rows = 4, cols = 4 }: { rows?: number; cols?: number }) {
  return (
    <div className="grid gap-3 p-4">
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="flex gap-4">
          {Array.from({ length: cols }).map((_, j) => (
            <Skeleton key={j} className="h-5 flex-1" />
          ))}
        </div>
      ))}
    </div>
  );
}

/** Visual stat card: muted uppercase label above bold prominent value, avoiding inline 'Label: value' strings */
export function StatCard({
  label,
  value,
  subtext,
  className,
}: {
  label: string;
  value: ReactNode;
  subtext?: string;
  className?: string;
}) {
  return (
    <div className={cn("rounded-xl border border-slate-200/90 bg-white p-4 shadow-xs sm:p-5", className)}>
      <div className="text-xs font-semibold tracking-wider text-slate-500 uppercase">{label}</div>
      <div className="mt-1.5 text-2xl font-semibold tracking-tight text-slate-900 tabular-nums">{value}</div>
      {subtext ? <div className="mt-1 text-xs text-slate-500">{subtext}</div> : null}
    </div>
  );
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
      <RadixTabs.List
        aria-label={label}
        className="flex gap-1 overflow-x-auto overflow-y-hidden border-b border-slate-200 [scrollbar-width:none]"
      >
        {tabs.map((tab) => (
          <RadixTabs.Trigger
            key={tab.value}
            value={tab.value}
            data-testid={tab.testId}
            className="-mb-px cursor-pointer border-b-2 border-transparent px-3.5 py-2 text-sm whitespace-nowrap text-slate-500 transition-colors hover:text-slate-900 data-[state=active]:border-brand-600 data-[state=active]:font-semibold data-[state=active]:text-brand-text"
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
                "group pointer-events-auto relative flex w-full items-start gap-3 rounded-xl border bg-white p-3.5 shadow-lg transition-all",
                isGood && "border-green-200 bg-green-50/70 text-green-900",
                isError && "border-red-200 bg-red-50/70 text-red-900",
                isWarn && "border-amber-200 bg-amber-50/70 text-amber-900",
                !isGood && !isError && !isWarn && "border-slate-200 text-slate-900",
              )}
            >
              <span className="mt-0.5 shrink-0">
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
              <div className="grid flex-1 gap-0.5 text-sm">
                {t.title ? (
                  <RadixToast.Title className="text-xs font-semibold tracking-wide uppercase">
                    {t.title}
                  </RadixToast.Title>
                ) : null}
                <RadixToast.Description className="text-sm font-medium">{t.message}</RadixToast.Description>
              </div>
              <RadixToast.Close
                aria-label="Close"
                className="shrink-0 rounded-lg p-1 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-700"
              >
                <X size={16} />
              </RadixToast.Close>
            </RadixToast.Root>
          );
        })}
        <RadixToast.Viewport className="pointer-events-none fixed right-4 bottom-4 z-50 flex max-h-screen w-full max-w-sm flex-col gap-2 p-4 outline-none sm:right-6 sm:bottom-6" />
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
