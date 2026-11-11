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
        name: "XZACTO POS",
        short_name: "XZACTO",
        description: "Multi-store retail POS, inventory, and warehouse platform",
        display: "standalone",
        display_override: ["fullscreen", "standalone"],
        start_url: "/",
        theme_color: "#3419d2",
        background_color: "#fbfaf9",
        icons: [
          { src: "/icons/Icon-192.png", sizes: "192x192", type: "image/png" },
          { src: "/icons/Icon-512.png", sizes: "512x512", type: "image/png" },
          { src: "/icons/Icon-maskable-192.png", sizes: "192x192", type: "image/png", purpose: "maskable" },
          { src: "/icons/Icon-maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
        ],
      },
    }),
  ],
  server: { port: 5173 },
  test: { environment: "node" },
});
