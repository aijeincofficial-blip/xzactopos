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

## Not done yet
- Moving the existing screens onto PageHeader, Table, Tabs, EmptyState and ErrorState (they still use their own markup and plain `<table>` and hand-made tab buttons). Order: Sell, Today, Products, Purchasing, Counts, Warehouses, then the rest.
- Toasts (saved / failed messages are still inline).
- A contrast check with a tool on every screen in dark mode; only Today, Products and the shell were looked at by eye.
- Light and dark were checked in the browser pane at desktop and phone width on the Solo test store; Full mode screens were not.
