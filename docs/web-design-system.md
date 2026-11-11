# Web design system (apps/client)

Started 2026-11-09 (handoff priority 4). Matches the phone app: brand blue for actions, mint for good, amber for watch, ruby for stop, obsidian navy surfaces.

## Tokens (`src/index.css`)
- Brand: `brand-50/100/500/600/700/800`, `brand-text` (blue for links and text, readable in both themes), `mint-500`, `navy-900`.
- Type scale: xs, sm (body), base, lg, xl (page title), 2xl, each with a line height.
- Radius `md` / `lg`, one soft shadow (`shadow-sm`).
- **Dark mode re-maps the Tailwind colour variables** (`slate`, `white`, `red`, `amber`, `emerald`, `green`, `indigo`, `brand`) under `:root[data-theme="dark"]`, and under the device preference when no choice is stored. So screens written with `bg-white`, `text-slate-500`, `bg-red-50` follow the theme with no `dark:` classes. Do not use raw hex colours in screens. Text that must stay white on a coloured button uses `text-[#fff]` (because `text-white` flips with the surface).
- Theme choice (system, light, dark) is in `src/lib/theme.ts`, kept per browser; the toggle is in the top bar (`data-testid="theme-toggle"`).

## Layout (`routes/app-layout.tsx`)
Left sidebar (Daily, Stock, Business groups, icons from lucide) on `md` and up; a drawer opened by the Menu button below that. Top bar: active store, language, theme, sign out. Content max width 6xl.

## Components (`components/ui.tsx`)
Button (primary is brand blue), Input, Select, Field, Card, Alert, Badge, Dialog, and new: **PageHeader**, **EmptyState**, **ErrorState**, **Table / Th / Td**, **Tabs / TabPanel** (Radix). Focus rings are brand blue on every control; animation is switched off for people who ask for reduced motion.

## Slice 2 (2026-11-09)
- Every plain data table (16, in Bins, Counts, Locations, Warehouses, Platform, Purchasing, Settings, Users) is now `<Table bare>`: the header and row look come from the component. `Table` without `bare` adds the bordered scroll wrapper.
- Purchasing and Warehouses use `Tabs` (arrow keys, roles) with the same test ids. Purchasing, Counts, Warehouses, Sell and Today use `PageHeader`; Products has the same title style. The purchasing order list uses `EmptyState`.

## Slice 3 (2026-11-10)
- **Toast Notification System (`components/ui.tsx`, `main.tsx`)**: Built on Radix UI Toast primitives (`ToastProvider`, `ToastViewport`, `ToastRoot`, `ToastTitle`, `ToastDescription`, `ToastClose`). Accessible, auto-dismissing (5s default, 8s for errors), theme-aware (re-mapped Tailwind token styling), supports reduced motion. `useToast()` hook provides `.good()`, `.error()`, `.warn()`, `.info()`, and custom `.toast()`. Mounted at the app root in `main.tsx`.
- **Products Screen Restyled (`routes/products.tsx`)**: Replaced bespoke `Labeled` components with standard `Field`, adopted `PageHeader`, `ErrorState`, `EmptyState`, design-token button styles (`ring-brand-600/20`), and toast notifications for create/edit, archiving, receiving, counting, pack opening, and CSV imports.
- **ErrorState & EmptyState Across Back-Office Routes**: Adopted `ErrorState` (with query retry handlers) and `EmptyState` across `Counts`, `Purchasing`, `Bins`, `Locations`, `Users`, `Overview` (Reorder, Transit, Negative, Product tabs), `Today`, `Settings`, `Sales`, `Utang`, `Expenses`, `Day-Close`, `Transfers`, `Reports`, and `Modules`.
- **PageHeader & Form Field Standardization**: Standardized `PageHeader` and `Field` across back-office pages, replacing ad-hoc headers while preserving 100% of existing `data-testid` attributes and route contracts.

## Slice 4 — Cobalt Royal & Cool Slate UI Redesign & Decluttering (2026-11-11)
- **Crisp Retail Palette (`src/index.css`, `src/lib/theme.ts`, `src/lib/theme.test.ts`)**: Replaced warm sepia grays and electric violet with a crisp **Cobalt Royal (`#2563eb` light / `#60a5fa` dark) + Cool Neutral Slate (`#f8fafc`–`#0f172a` light / `#0b1120`–`#f8fafc` dark)** palette, `8px` control radius (`--radius-control`), `12px` card radius (`--radius-card`), whisper-quiet shadows, and verified all 24 WCAG AA token pairs across light and dark modes.
- **Refined App Shell & Sidebar Footer (`routes/app-layout.tsx`, `routes/public.tsx`)**: Moved user avatar monogram, role label, `LanguageSelect`, and `Sign Out` from the top header into a dedicated **Sidebar Footer** (rendered in both desktop sidebar and mobile/kiosk slide-over drawer). Slimmed top header (`h-13`) to active location pill + essential portal/kiosk/theme toggles. Cleaned `/app` `DashboardPage` by replacing noisy walls of raw `perm.*` RBAC badges with clean store/warehouse cards.
- **Decluttered Kiosk POS & Back-Office Screens (`routes/sell.tsx`, `routes/today.tsx`, `routes/products.tsx`, `routes/utang.tsx`, `routes/day-close.tsx`, `routes/expenses.tsx`, `routes/overview.tsx`, `routes/modules.tsx`)**: Compact pill strip for Fast Keys (`fast-keys-bar`), hover-reveal pin stars, low/out-of-stock-only tile badges, 3 Hero KPI cards + unified Tender & Expense card on `Today`, dynamic slide-in right-hand inspectors on `Products` and `Utang` (eliminating empty `440px` right columns when browsing), divided list `Card`s, and crisp `lucide-react` stroke icons replacing raw emojis.

## Not done yet
- Automated browser axe/Lighthouse pass across every full-mode modal in dark mode (all 24 core token pairs are programmatically verified for WCAG AA in `theme.test.ts`).
