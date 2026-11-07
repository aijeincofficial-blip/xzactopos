import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: "autoUpdate",
      manifest: {
        name: "POS Platform",
        short_name: "POS",
        display: "standalone",
        start_url: "/",
        theme_color: "#0f172a",
        background_color: "#ffffff",
        icons: [],
      },
    }),
  ],
  server: { port: 5173 },
  test: { environment: "node" },
});
