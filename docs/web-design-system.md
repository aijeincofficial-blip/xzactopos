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

## Not done yet
- Toasts (saved / failed messages are still inline), `ErrorState` on load failures, more `EmptyState` use.
- Products still has its own header and list markup; Sell, Counts and Purchasing forms are unchanged inside.
- A contrast check with a tool on every screen in dark mode. Only Today, Sell, Products, Settings and the shell were looked at by eye, on the Solo test store; the Full-mode screens (Purchasing, Counts, Warehouses and the tables) were not seen in a browser because no Full-mode test account was at hand.
