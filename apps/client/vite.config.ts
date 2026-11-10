import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      registerType: "autoUpdate",
      workbox: {
        globPatterns: ["**/*.{js,css,html,ico,png,svg,woff2}"],
        navigateFallback: "/index.html",
        navigateFallbackDenylist: [/^\/api/, /^\/auth/],
      },
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
