# P1-07 Admin UI (Sonnet is fine)
Plan: §4 onboarding, §11 stack.
- Adds from the plan stack: TanStack Router + Query, Tailwind + shadcn/ui, Zod.
- Login with tenant slug (`/t/<slug>`) + username or email. Route guards by role/module (UI hides; DB enforces).
- Screens: setup wizard (business, base currency, timezone, languages, modules), locations, users (create, role, locations + position, deactivate), module toggles.
- All strings via i18next (en + fil), key-parity test stays green.
Done when: flows work in the browser against local Supabase; admin with two stores sees different actions per store.
