# P0-04 Client shell, PWA and local Supabase
Goal: `pnpm dev` runs the Vite React PWA against local Supabase.
Do: Vite + React + TS, vite-plugin-pwa, supabase-js client using anon key only, status screen showing API reachability, `.env.example`.
Rules: no service role key in client code; no Realtime.
Done when: `pnpm dev` shows "connected" with the local stack running.
