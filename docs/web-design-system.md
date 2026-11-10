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

## Not done yet
- A contrast check with an automated tool on every screen in dark mode. Full-mode screens (Purchasing, Counts, Warehouses, Transfers, Bins) checked for component rendering and test compliance; end-to-end visual inspection in browser across both themes.
