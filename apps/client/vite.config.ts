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
      injectRegister: null,
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
  build: {
    rolldownOptions: {
      output: {
        codeSplitting: {
          groups: [
            { name: "vendor-tslib", test: /[\\/]tslib[\\/]/, priority: 40 },
            {
              name: "vendor-react",
              test: /[\\/]node_modules[\\/](react|react-dom|scheduler|@tanstack|i18next|react-i18next)[\\/]/,
              priority: 30,
            },
            { name: "vendor-supabase", test: /[\\/]node_modules[\\/]@supabase[\\/]/, priority: 20 },
            { name: "vendor-radix", test: /[\\/]node_modules[\\/](radix-ui|@radix-ui)[\\/]/, priority: 15 },
            { name: "vendor-ui", test: /[\\/]node_modules[\\/](lucide-react|class-variance-authority|clsx|tailwind-merge)[\\/]/, priority: 10 },
          ],
        },
      },
    },
  },
  test: { environment: "node" },
});
