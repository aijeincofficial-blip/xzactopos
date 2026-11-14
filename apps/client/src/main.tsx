import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider } from "@tanstack/react-router";
import {
  ALL_NAMESPACES,
  canInitI18nSync,
  initI18n,
  initI18nSync,
  PUBLIC_NAMESPACES,
  resolveLocale,
  storedLocale,
} from "./i18n/index.ts";
import { makeRouter } from "./router.tsx";
import { applyTheme, readTheme } from "./lib/theme.ts";
import { hasStoredSessionHint } from "./lib/session-hint.ts";
import { ToastProvider } from "./components/toast.tsx";
import "./index.css";

const queryClient = new QueryClient({
  // No background polling on admin screens; offline-first so cached/outbox queries & mutations run while offline.
  defaultOptions: {
    queries: { refetchOnWindowFocus: false, retry: false, networkMode: "offlineFirst" },
    mutations: { networkMode: "offlineFirst" },
  },
});
applyTheme(readTheme()); // before the first paint, so a dark choice does not flash light
const router = makeRouter(queryClient);

let authListenerStarted = false;
function ensureAuthStateListener(): void {
  if (authListenerStarted) return;
  authListenerStarted = true;
  void Promise.all([
    import("./lib/supabase.ts"),
    import("./lib/api.ts"),
    import("./lib/pos-outbox.ts"),
  ]).then(([{ supabase }, { clearSensitiveSessionStorage }, { setPosOutboxTenant }]) => {
    supabase.auth.onAuthStateChange((event) => {
      if (event === "PASSWORD_RECOVERY") {
        void router.navigate({ to: "/reset-password" });
      } else if (event === "SIGNED_OUT") {
        clearSensitiveSessionStorage();
        setPosOutboxTenant(null);
        queryClient.clear();
      }
    });
  });
}

const pathname = typeof window !== "undefined" ? window.location.pathname : "/";
const hasAuthUrlParams =
  typeof window !== "undefined" &&
  (window.location.hash.includes("type=recovery") ||
    window.location.hash.includes("access_token") ||
    window.location.search.includes("code="));

if (pathname !== "/" || hasStoredSessionHint() || hasAuthUrlParams) {
  ensureAuthStateListener();
}

router.subscribe("onBeforeLoad", (evt) => {
  if (evt.toLocation.pathname !== "/") {
    ensureAuthStateListener();
  }
});

const bootLocale = storedLocale() ?? resolveLocale(globalThis.navigator?.language);
const bootNamespaces = pathname.startsWith("/app") ? ALL_NAMESPACES : PUBLIC_NAMESPACES;

function mountApp() {
  createRoot(document.getElementById("root")!).render(
    <StrictMode>
      <QueryClientProvider client={queryClient}>
        <ToastProvider>
          <RouterProvider router={router} />
        </ToastProvider>
      </QueryClientProvider>
    </StrictMode>,
  );
}

// Warm /app/sell route chunks in parallel with session/access RPC on direct POS boot
// without adding /app code to landing page (/) initial bundles.
if (typeof window !== "undefined" && window.location.pathname === "/app/sell") {
  void import("./routes/app-layout.tsx");
  void import("./routes/sell.tsx");
}

if (canInitI18nSync(bootLocale, bootNamespaces)) {
  initI18nSync(bootLocale, bootNamespaces);
  mountApp();
} else {
  void initI18n(bootLocale, { namespaces: bootNamespaces }).then(mountApp);
}

// Defer service worker registration well past initial hydration so 100+ asset
// precaching does not compete with first-visit rendering or auth/catalog RPCs.
if (import.meta.env.PROD && typeof window !== "undefined" && "serviceWorker" in navigator) {
  const registerSw = () => {
    window.setTimeout(() => {
      void navigator.serviceWorker.register("/sw.js").catch(() => {});
    }, 4000);
  };
  if (document.readyState === "complete") {
    registerSw();
  } else {
    window.addEventListener("load", registerSw, { once: true });
  }
}
