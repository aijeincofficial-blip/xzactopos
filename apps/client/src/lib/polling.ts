import { useEffect, useSyncExternalStore } from "react";
import type { QueryClient } from "@tanstack/react-query";
import { useOnlineStatus } from "./network.ts";

/** Minimum background polling cadence (120 s) so idle tabs stay gentle on Free-Tier compute. */
export const MIN_POLL_INTERVAL_MS = 120_000;

function subscribeVisibility(cb: () => void): () => void {
  if (typeof document === "undefined") return () => {};
  document.addEventListener("visibilitychange", cb);
  return () => document.removeEventListener("visibilitychange", cb);
}

function getPageVisible(): boolean {
  return typeof document === "undefined" ? true : !document.hidden;
}

export function usePageVisible(): boolean {
  return useSyncExternalStore(subscribeVisibility, getPageVisible, () => true);
}

/**
 * Computes a React Query `refetchInterval`:
 * - `false` when offline or the tab is backgrounded (`document.hidden`)
 * - Otherwise clamped to at least `MIN_POLL_INTERVAL_MS` (120 s).
 */
export function resolvePollInterval(online: boolean, visible: boolean, ms = MIN_POLL_INTERVAL_MS): number | false {
  if (!online || !visible) return false;
  return Math.max(ms, MIN_POLL_INTERVAL_MS);
}

/** React hook returning `false` when offline or hidden, else at least `MIN_POLL_INTERVAL_MS` (120 s). */
export function usePollInterval(ms = MIN_POLL_INTERVAL_MS): number | false {
  const online = useOnlineStatus();
  const visible = usePageVisible();
  return resolvePollInterval(online, visible, ms);
}

/**
 * Refreshes active queries when connectivity returns or a hidden tab becomes visible again.
 * Throttled so rapid tab switches don't burst requests.
 */
export function useVisibilityResumeInvalidation(qc: QueryClient, cooldownMs = 15_000): void {
  useEffect(() => {
    if (typeof document === "undefined" || typeof window === "undefined") return;
    let lastResumeAt = Date.now();

    const handleResume = () => {
      if (document.hidden || !navigator.onLine) return;
      const now = Date.now();
      if (now - lastResumeAt < cooldownMs) return;
      lastResumeAt = now;
      void qc.invalidateQueries({ refetchType: "active" });
    };

    document.addEventListener("visibilitychange", handleResume);
    window.addEventListener("online", handleResume);
    return () => {
      document.removeEventListener("visibilitychange", handleResume);
      window.removeEventListener("online", handleResume);
    };
  }, [qc, cooldownMs]);
}
