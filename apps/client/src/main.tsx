import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider } from "@tanstack/react-router";
import { initI18n } from "./i18n/index.ts";
import { makeRouter } from "./router.tsx";
import "./index.css";

const queryClient = new QueryClient({
  // No background polling on admin screens; refetch on demand after mutations.
  defaultOptions: { queries: { refetchOnWindowFocus: false, retry: false } },
});
const router = makeRouter(queryClient);

void initI18n().then(() => {
  createRoot(document.getElementById("root")!).render(
    <StrictMode>
      <QueryClientProvider client={queryClient}>
        <RouterProvider router={router} />
      </QueryClientProvider>
    </StrictMode>,
  );
});
