import { Suspense, createContext, lazy, useCallback, useContext, useMemo, useState, type ReactNode } from "react";

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

const LazyToastViewport = lazy(() =>
  import("./toast-viewport.tsx").then((m) => ({ default: m.ToastViewport })),
);

const ToastContext = createContext<ToastContextValue | null>(null);

/** Lightweight toast context provider; loads the Radix Toast viewport lazily when the first toast fires. */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<ToastMessage[]>([]);
  const [hasTriggeredToast, setHasTriggeredToast] = useState(false);

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
    setHasTriggeredToast(true);
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
      {children}
      {hasTriggeredToast ? (
        <Suspense fallback={null}>
          <LazyToastViewport toasts={toasts} onDismiss={dismiss} />
        </Suspense>
      ) : null}
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
