// Shared UI primitives styled in the "Receipt paper at a night market" system (docs/design.md).
import { createContext, useCallback, useContext, useMemo, useState, type ComponentProps, type ReactNode } from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { Dialog as RadixDialog, Tabs as RadixTabs, Toast as RadixToast } from "radix-ui";
import { AlertTriangle, CheckCircle2, Inbox, Info, X } from "lucide-react";
import { cn } from "../lib/utils.ts";

const buttonVariants = cva(
  "inline-flex cursor-pointer items-center justify-center gap-2 rounded-full text-sm font-semibold transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-lime disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        primary: "border-[1.5px] border-lime bg-lime text-ink hover:border-lime-hover hover:bg-lime-hover",
        outline:
          "border-[1.5px] border-slate-200 bg-white text-slate-900 hover:border-slate-900",
        danger: "border-[1.5px] border-sw-meal-fg/25 bg-sw-meal text-sw-meal-fg hover:opacity-90",
        ghost: "text-slate-600 hover:bg-slate-100 hover:text-slate-900",
      },
      size: { md: "min-h-[44px] px-5 py-2", sm: "min-h-[36px] px-3.5 py-1.5 text-xs" },
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
  "min-h-[44px] h-11 w-full rounded-[14px] border-[1.5px] border-slate-200 bg-white px-3.5 text-sm font-normal text-slate-900 transition-colors placeholder:text-slate-400 hover:border-slate-300 focus-visible:border-slate-900 focus-visible:outline-2 focus-visible:outline-offset-0 focus-visible:outline-slate-900 disabled:bg-slate-100 disabled:text-slate-500";

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
      <span className="text-sm font-semibold text-slate-800">{label}</span>
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
      className={cn("rounded-[24px] border-[1.5px] border-slate-200 bg-white p-5 sm:p-6", className)}
      {...props}
    />
  );
}

export function Alert({ tone = "error", children }: { tone?: "error" | "info" | "warn" | "good"; children: ReactNode }) {
  return (
    <div
      role={tone === "error" ? "alert" : "status"}
      className={cn(
        "rounded-[16px] border-[1.5px] px-4 py-3 text-sm font-normal",
        tone === "error" && "border-red-200 bg-red-50 text-red-900",
        tone === "info" && "border-slate-200 bg-slate-100 text-slate-900",
        tone === "warn" && "border-amber-200 bg-amber-50 text-amber-900",
        tone === "good" && "border-emerald-200 bg-emerald-50 text-emerald-900",
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
        "inline-flex items-center gap-1 rounded-full border-[1.5px] px-2.5 py-0.5 font-mono text-[11px] font-semibold",
        tone === "good" && "border-ok-dot/25 bg-ok-bg text-ok-fg",
        tone === "warn" && "border-sw-pastry-fg/20 bg-sw-pastry text-sw-pastry-fg",
        tone === "danger" && "border-sw-meal-fg/20 bg-sw-meal text-sw-meal-fg",
        tone === "neutral" && "border-slate-200 bg-slate-100 text-slate-800",
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
        <RadixDialog.Overlay className="fixed inset-0 z-50 bg-ink/70" />
        <RadixDialog.Content
          aria-describedby={undefined}
          className="receipt-float fixed top-1/2 left-1/2 z-50 max-h-[90vh] w-[min(32rem,92vw)] -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-[28px] border-[1.5px] border-slate-200 bg-white p-6"
        >
          <div className="mb-4 flex items-center justify-between gap-3">
            <RadixDialog.Title className="font-display text-xl font-extrabold tracking-[-0.02em] text-slate-900">
              {title}
            </RadixDialog.Title>
            <RadixDialog.Close
              aria-label={closeLabel}
              className="inline-flex min-h-[36px] min-w-[36px] items-center justify-center rounded-full text-slate-500 transition-colors hover:bg-slate-100 hover:text-slate-900"
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

/** Page title with crisp Bricolage display typography and right-aligned actions. */
export function PageHeader({ title, subtitle, actions }: { title: string; subtitle?: string; actions?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-center justify-between gap-3">
      <div className="grid gap-1">
        <h1 className="font-display text-2xl font-extrabold tracking-[-0.025em] text-slate-900 sm:text-[32px] sm:leading-tight">
          {title}
        </h1>
        {subtitle ? <p className="text-sm text-slate-500">{subtitle}</p> : null}
      </div>
      {actions ? <div className="flex flex-wrap items-center gap-2">{actions}</div> : null}
    </div>
  );
}

/** Empty state matching docs/design.md §7: stroke icon, one sentence, and a lime CTA. */
export function EmptyState({ title, hint, action }: { title: string; hint?: string; action?: ReactNode }) {
  return (
    <div className="grid justify-items-center gap-3 rounded-[24px] border-[1.5px] border-dashed border-slate-300 bg-white px-6 py-10 text-center">
      <div className="flex h-12 w-12 items-center justify-center rounded-[14px] border-[1.5px] border-slate-200 bg-slate-50 text-slate-600">
        <Inbox size={22} strokeWidth={1.75} aria-hidden />
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
      className="flex flex-wrap items-center gap-3 rounded-[20px] border-[1.5px] border-red-200 bg-red-50 p-4 text-sm text-red-900"
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
  "w-full text-left text-sm [&_thead_th]:bg-white [&_thead_th]:px-4 [&_thead_th]:py-3 [&_thead_th]:font-mono [&_thead_th]:text-[11px] [&_thead_th]:font-semibold [&_thead_th]:tracking-[0.08em] [&_thead_th]:text-slate-500 [&_thead_th]:uppercase [&_tbody_tr]:border-t-[1.5px] [&_tbody_tr]:border-dashed [&_tbody_tr]:border-slate-300 [&_tbody_tr]:transition-colors [&_tbody_tr:hover]:bg-slate-50";

/**
 * Receipt-paper data table: mono uppercase headers, dashed --dash row dividers, hover --sand, no zebra stripes.
 * `bare` skips the bordered scroll wrapper, for a table that already sits inside a Card.
 */
export function Table({ className, bare, ...props }: ComponentProps<"table"> & { bare?: boolean }) {
  const table = <table className={cn(tableClass, className)} {...props} />;
  if (bare) return table;
  return <div className="overflow-x-auto rounded-[24px] border-[1.5px] border-slate-200 bg-white">{table}</div>;
}

export function Th({ className, numeric, ...props }: ComponentProps<"th"> & { numeric?: boolean }) {
  return (
    <th
      scope="col"
      className={cn(
        "bg-white px-4 py-3 font-mono text-[11px] font-semibold tracking-[0.08em] text-slate-500 uppercase",
        numeric && "text-right",
        className,
      )}
      {...props}
    />
  );
}

export function Td({ className, numeric, ...props }: ComponentProps<"td"> & { numeric?: boolean }) {
  return (
    <td
      className={cn("px-4 py-3.5 text-slate-900", numeric && "text-right font-mono tabular-nums", className)}
      {...props}
    />
  );
}

/** Loading skeleton block: matches content layout and size to prevent layout shift */
export function Skeleton({ className, ...props }: ComponentProps<"div">) {
  return <div className={cn("animate-pulse rounded-[14px] bg-slate-200/80", className)} {...props} />;
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

/** Night Market stat card: mono uppercase eyebrow above Bricolage Grotesque 800 figure. */
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
    <div className={cn("rounded-[24px] border-[1.5px] border-slate-200 bg-white p-5", className)}>
      <div className="font-mono text-[11px] font-semibold tracking-[0.08em] text-slate-500 uppercase">{label}</div>
      <div className="mt-2 font-display text-3xl leading-none font-extrabold tracking-[-0.03em] text-slate-900 tabular-nums sm:text-[36px]">
        {value}
      </div>
      {subtext ? <div className="mt-1.5 text-xs text-slate-500">{subtext}</div> : null}
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
        className="flex gap-1.5 overflow-x-auto overflow-y-hidden border-b-[1.5px] border-slate-200 [scrollbar-width:none]"
      >
        {tabs.map((tab) => (
          <RadixTabs.Trigger
            key={tab.value}
            value={tab.value}
            data-testid={tab.testId}
            className="-mb-[1.5px] cursor-pointer border-b-2 border-transparent px-3.5 py-2.5 text-sm font-medium whitespace-nowrap text-slate-500 transition-colors hover:text-slate-900 data-[state=active]:border-slate-900 data-[state=active]:font-semibold data-[state=active]:text-slate-900"
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
                "receipt-float group pointer-events-auto relative flex w-full items-start gap-3 rounded-[20px] border-[1.5px] bg-white p-4 transition-all",
                isGood && "border-emerald-200 bg-emerald-50 text-emerald-900",
                isError && "border-red-200 bg-red-50 text-red-900",
                isWarn && "border-amber-200 bg-amber-50 text-amber-900",
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
                  <Info size={18} className="text-slate-700" aria-hidden />
                )}
              </span>
              <div className="grid flex-1 gap-0.5 text-sm">
                {t.title ? (
                  <RadixToast.Title className="font-mono text-xs font-semibold tracking-wide uppercase">
                    {t.title}
                  </RadixToast.Title>
                ) : null}
                <RadixToast.Description className="text-sm font-medium">{t.message}</RadixToast.Description>
              </div>
              <RadixToast.Close
                aria-label="Close"
                className="shrink-0 rounded-full p-1 text-slate-500 transition-colors hover:bg-slate-100 hover:text-slate-900"
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
