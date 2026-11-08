# Web (React): Solo first, then the upgrade to Full

Owner decision 2026-11-08: Solo is the foundation. The React app `apps/client` gets a Solo experience (same data and backend as the phone app), and both Solo apps show "Upgrade to Full". Full screens are built on top afterwards. Context: `docs/tasks/F-00-overview-full-mode.md` ("Direction change").

## What exists in `apps/client` today
- Stack: React 19, TanStack Router + Query, supabase-js, i18next (en + fil), zod, Tailwind. Online only: no local store, no outbox.
- Routes: `/app` dashboard, `/app/setup`, `/app/locations`, `/app/users`, `/app/modules`. Guards use `can(permission)` from `@pos/core`; route access comes from `get_my_access`.
- No selling, stock, utang, expenses or reports screens yet.

## Assumptions (change them if wrong)
1. Web Solo is **online-first**: it reads and writes through the existing RPCs and RLS (no Dexie or outbox in the first version). Offline stays the phone app's job.
2. The web app reuses the same RPCs the phone app syncs through (sale, stock, utang, expense, day close), not new tables. Any new RPC needs pgTAP first.
3. The nav is driven by mode: Solo tenants (one store, no staff modules) see Today, Sell, Stock, Utang, Expenses, Settings; the Full screens appear after the upgrade.

## Cards
| Card | Work | Model |
| --- | --- | --- |
| W-01 Shell and Solo home | Mode-aware nav, Today (sales, cash, wallet float) from the existing rollups, en + fil strings, tests | Sonnet |
| W-02 Sell | Product search, cart, cash / e-wallet / utang payment through the sale RPC, receipt view, void. **DONE 2026-11-08: search, cart, discount, cash, e-wallet, utang with customers, split payment, server sale number, Sales list/receipt, void.** | Opus (money) then Sonnet |
| W-03 Stock and products | Products with variants, stock levels, receive, adjust, count, tingi (through `stock_movements` RPCs). **DONE 2026-11-08 for products, stock levels, stock in and counts; tingi, expiry, categories, photos and import/export are not built yet.** | Opus (stock math) then Sonnet |
| W-04 Utang, expenses, day close | Customer ledger and payments, expenses, opening cash, day close. **DONE 2026-11-08: customer balances & ledger, utang cash/ewallet payments, due dates, expenses list/record/void with approval rules, daily drawer reconciliation & close history.** | Sonnet (Opus if a new RPC is needed) |
| W-05 Upgrade to Full | Wizard (explain, confirm, `complete_setup` / `set_modules` / `upsert_location`), same tenant, nothing copied; "Upgrade to Full" entry on the web Solo home and in the Flutter Solo app (opens or links to the web wizard); test that a solo tenant's data is unchanged after the upgrade. **DONE 2026-11-08: React Upgrade Wizard (/app/upgrade) with data safety guarantee & optional location creation, Today screen upgrade banner, Flutter Settings upgrade entry & dialog, schema & localization parity, verified 100% zero data diff in PostgreSQL test.** | Opus (data safety) then Sonnet |
| W-06 and later | Full screens: staff, stores, warehouse, shifts, reports (cards F-04 to F-10, rewritten for React) | per card |

Order: W-01 to W-04 give Solo on the web; W-05 adds the upgrade; the F cards follow. Flutter Solo gets only the upgrade entry (in W-05) and fixes.

## Rules
Same as `CLAUDE.md`: migrations and pgTAP before UI, RLS on every table, stock only through `stock_movements`, money in integer minor units, strings through i18next keys (en + fil), `pnpm check` before done, one commit per card.
