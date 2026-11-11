import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider } from "@tanstack/react-router";
import { initI18n } from "./i18n/index.ts";
import { makeRouter } from "./router.tsx";
import { applyTheme, readTheme } from "./lib/theme.ts";
import { supabase } from "./lib/supabase.ts";
import { ToastProvider } from "./components/ui.tsx";
import "./index.css";

const queryClient = new QueryClient({
  // No background polling on admin screens; refetch on demand after mutations.
  defaultOptions: { queries: { refetchOnWindowFocus: false, retry: false } },
});
applyTheme(readTheme()); // before the first paint, so a dark choice does not flash light
const router = makeRouter(queryClient);

supabase.auth.onAuthStateChange((event) => {
  if (event === "PASSWORD_RECOVERY") {
    void router.navigate({ to: "/reset-password" });
  }
});

void initI18n().then(() => {
  createRoot(document.getElementById("root")!).render(
    <StrictMode>
      <QueryClientProvider client={queryClient}>
        <ToastProvider>
          <RouterProvider router={router} />
        </ToastProvider>
      </QueryClientProvider>
    </StrictMode>,
  );
});
