import { Toast as RadixToast } from "radix-ui";
import { AlertTriangle, CheckCircle2, Info, X } from "lucide-react";
import { cn } from "../lib/utils.ts";
import type { ToastMessage } from "./toast.tsx";

export function ToastViewport({
  toasts,
  onDismiss,
}: {
  toasts: ReadonlyArray<ToastMessage>;
  onDismiss: (id: string) => void;
}) {
  return (
    <RadixToast.Provider swipeDirection="right">
      {toasts.map((t) => {
        const isError = t.tone === "error";
        const isGood = t.tone === "good";
        const isWarn = t.tone === "warn";
        return (
          <RadixToast.Root
            key={t.id}
            duration={t.duration}
            onOpenChange={(open) => {
              if (!open) onDismiss(t.id);
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
  );
}
