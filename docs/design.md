# DESIGN.md — POS Visual Style Guide

> **For the AI:** Read this whole file before writing any UI. Follow it exactly.
> Do not fall back to default Tailwind/Bootstrap/Material looks. If something
> isn't covered here, choose the option that fits the "receipt-paper night
> market" feel below — never a generic SaaS look.

---

## 1. The concept (read this first)

**"Receipt paper at a night market."**
Deep ink-green surfaces, one loud acid-lime accent, warm off-white "receipt paper"
cards with dashed dividers and a zig-zag torn edge, chunky grotesque headlines,
and monospace numbers like a printed till receipt.

It should feel **bold, warm, confident and tactile** — not corporate, not pastel,
not "default dashboard".

---

## 2. Color tokens (use ONLY these)

```css
:root {
  /* surfaces */
  --ink:        #0F1A16;  /* main dark background, sidebar, buttons on lime */
  --ink-2:      #16241F;  /* cards on dark */
  --ink-line:   #24342D;  /* borders on dark */
  --ink-line-2: #2F3F38;  /* stronger borders / dashed rings on dark */
  --paper:      #FFFDF5;  /* receipt paper, light cards */
  --sand:       #EDEAE1;  /* app background (light areas) */
  --sand-line:  #D6D1C4;  /* borders on light */
  --dash:       #C9C4B5;  /* dashed receipt dividers */

  /* text */
  --text-on-dark:   #F2F5EF;
  --muted-on-dark:  #B7C4BD;
  --text-on-light:  #1A231F;
  --muted-on-light: #4A5A52;

  /* the ONE accent */
  --lime:       #D4F25A;
  --lime-hover: #E4FF7A;

  /* category swatches (product tiles) — bg / text */
  --sw-coffee:    #3B2A20; --sw-coffee-fg:    #F3D9B8;
  --sw-noncoffee: #C9E3A6; --sw-noncoffee-fg: #1F3A14;
  --sw-pastry:    #F4D58A; --sw-pastry-fg:    #4A3208;
  --sw-meal:      #F0B9A2; --sw-meal-fg:      #4A1A0C;

  /* status */
  --ok-bg: #DDE9C8; --ok-fg: #1F3A14; --ok-dot: #3D7A1F;
}
```

Rules:
- **Lime is the only accent.** Use it for the primary CTA, the active nav item,
  "paid" states, and small highlights. Never for big background areas, except
  one full-width band or one pricing block per page.
- Text on lime is always `--ink`, never white.
- **No gradients** as backgrounds. **No purple, no blue, no neon glow.**
- Pure black `#000` and pure white `#fff` are banned. Use `--ink` and `--paper`.

---

## 3. Typography

Load from Google Fonts:
```html
<link href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,400..800&family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
```

| Role | Font | Weight | Size | Tracking |
|---|---|---|---|---|
| Hero headline | Bricolage Grotesque | 800 | `clamp(52px, 7vw, 104px)`, line-height 0.92 | `-0.045em` |
| Section heading (h2) | Bricolage Grotesque | 800 | `clamp(40px, 5vw, 64px)`, lh 1 | `-0.035em` |
| Card / screen title | Bricolage Grotesque | 700–800 | 24–36px | `-0.02em` |
| Body | Inter | 400 | 17–19px, line-height 1.6 | normal |
| UI labels / buttons | Inter | 600 | 14–17px | normal |
| **All prices, totals, order numbers, qty** | JetBrains Mono | 400/600 | 12–15px | normal |
| Eyebrow labels | JetBrains Mono | 400 | 12–13px, UPPERCASE | `0.08em` |

Rules:
- Headlines are **big and tight**. If a headline looks "normal sized", make it bigger.
- Every money value uses JetBrains Mono. Money is stored as **integer minor units + currency code**,
  so never format by hand: use one shared `formatMoney(minor, currency, locale)` helper built on
  `Intl.NumberFormat` (e.g. `125000, "PHP"` → `₱1,250.00`). Use `font-variant-numeric: tabular-nums`
  so columns of prices line up.
- The final TOTAL is the one exception: Bricolage Grotesque 800, ~34px.

---

## 4. Shape, spacing, depth

- Radius: buttons/pills `999px`; cards `24–28px`; big feature blocks `40px`;
  small controls `10–16px`.
- Spacing scale (px): 4, 8, 12, 16, 20, 24, 32, 40, 56, 64, 96, 128.
  Landing sections use **96–128px** vertical padding. Be generous.
- Borders are `1.5px` (not 1px).
- Shadows: only on "floating" things (the receipt, a sticker/tag):
  `0 40px 80px rgba(0,0,0,.45)`. Cards otherwise have **no shadow**, just borders.
- Slight rotation is allowed for **decorative** elements only:
  receipt `rotate(-3deg)`, sticker tags `rotate(6deg)`, marquee band `rotate(-1.5deg)`.

---

## 5. Signature elements (these make it look designed — use them)

### 5a. Receipt paper card
```css
.receipt { background: var(--paper); color: var(--text-on-light); position: relative; }
.receipt::after { /* torn zig-zag bottom edge */
  content: ""; position: absolute; left: 0; right: 0; bottom: -9px; height: 10px;
  background:
    linear-gradient(135deg, var(--paper) 50%, transparent 50%) 0 0 / 14px 14px,
    linear-gradient(-135deg, var(--paper) 50%, transparent 50%) 0 0 / 14px 14px;
}
.receipt hr, .dash { border: 0; border-top: 1.5px dashed var(--dash); }
```
Use it for: the cart/order ticket in the POS and the hero visual on the landing page.

### 5b. Lime sticker tag
A small lime rounded box (radius 16px) with a check icon and short text like
"Paid · GCash". Rotated ~6deg, with a shadow, overlapping the corner of the receipt.

### 5c. Marquee band
A full-width lime strip, slightly rotated, with big Bricolage text listing
business types separated by `✳`: "Cafés ✳ Bakeries ✳ Milk tea ✳ Food stalls …"

### 5d. Numbered feature cards
Dark cards (`--ink-2`, border `--ink-line`) with a lime mono number `01`, `02`…
at the top, then a lime stroke icon, then the title and body. On hover the border turns lime.

### 5e. Monogram product tiles (no stock photos needed)
Each product tile has a colored swatch block (category color from tokens) with
a big 2-letter monogram (`Sl` for Spanish Latte) in Bricolage 800 46px at the bottom-left.
Name below in Inter 600, price below that in mono.

---

## 6. Components

**Primary button:** lime bg, ink text, radius 999px, padding `18px 28px`,
Inter 600, optional → arrow icon. Hover: `--lime-hover`.

**Ghost button (on dark):** transparent, `1.5px solid --ink-line-2`, light text.
Hover: border + text turn lime.

**Pill / filter chip (on light):** paper bg, `1.5px --sand-line` border, min-height 44px.
Active: ink bg, light text. Show a small mono count next to the label.

**Segmented toggle:** sand track with 4px padding; active segment = ink bg, light text.

**Payment method buttons (on dark):** outlined boxes with icon above label;
active = lime border + lime text + slightly lighter ink bg.

**Charge button:** full width, 68px tall, radius 20px, lime, "Charge" on the left
and the mono total on the right. Disabled = `#2A3A33` bg, `#7F918A` text.

**Qty stepper:** 32px square buttons (radius 10px), `−` and `+` icons, mono number between.

**Icons:** simple 2px **stroke** SVG icons (Lucide-style). **Never emoji.**

---

## 7. Screen layouts

### Landing page (dark `--ink` background)
1. **Nav:** logo (lime rounded square mark + lowercase wordmark) · links · lime "Open the register" pill.
2. **Hero:** two columns, wrapping on mobile. Left: lime eyebrow with dot,
   3-line giant headline (last line in lime), muted paragraph, primary + ghost buttons.
   Right: tilted receipt card (5a) with a dashed circle behind it and a sticker tag (5b).
3. **Marquee band** (5c).
4. **Features:** big h2 on the left, short muted text on the right, then a 4-card grid (5d).
5. **How it works:** section switches to **paper** background. Numbered list with giant
   1 / 2 / 3, rows separated by dashed lines.
6. **Pricing:** one big **lime** block (radius 40px) with headline on the left and an
   ink pricing card on the right.
7. **Footer:** thin top border, wordmark, links, copyright.

### POS register (light `--sand` app, dark accents)
```
┌──────┬───────────────────────────────────┬──────────────────┐
│ ink  │  eyebrow + "New order" title       │  INK PANEL       │
│ icon │  search · "Shift open" chip        │ ┌──────────────┐ │
│ rail │  [All][Coffee][Non-coffee]…pills   │ │ receipt paper │ │
│ 88px │  ┌────┐┌────┐┌────┐┌────┐          │ │ order #, toggle│ │
│      │  │tile││tile││tile││tile│ grid     │ │ lines + steppers│
│ lime │  └────┘└────┘└────┘└────┘          │ │ VAT, TOTAL    │ │
│active│                                    │ └/\/\/\/\/\/\/\┘ │
│      │                                    │ [Cash][Card][QR] │
│avatar│                                    │ [ CHARGE ₱xxx ]  │
└──────┴───────────────────────────────────┴──────────────────┘
```
- Left rail: ink, icon-only buttons 52px, active = lime square.
- Middle: product grid `repeat(auto-fill, minmax(176px, 1fr))`, gap 16px.
  A tile that's in the cart gets an ink border and a `×2` badge on its swatch.
- Right: ink panel 380–460px with the receipt ticket (5a) on top and
  payment + Charge below.
- Empty cart: receipt icon + "Tap an item to start the order."
- After charging: the receipt shows a big lime check circle, "Paid", amount + method,
  and a "Start next order" button.
- VAT line: `VAT 12% (incl.) = total × 12 / 112`. Display only, so the UI never
  calculates money that gets saved. Totals come from the same domain function or RPC the sale uses.

### Back-office screens (Inventory core, Warehouse add-on, admin)
These share one **app shell**: the ink icon rail on the left, a sand content area,
and a top bar holding the page title, a store/location switcher and the sync status chip (§10).

- **Data tables** (products, variants, stock levels, movements):
  paper card (radius 24px) on sand, header row in mono uppercase 12px `--muted-on-light`,
  rows 56px tall separated by `1.5px dashed --dash` lines (the receipt motif),
  numbers right-aligned in mono. Wrap wide tables in an `overflow-x: auto` box.
  Row hover = `--sand` bg. No zebra stripes.
- **Stock numbers:** quantity in mono 600. Low stock = a pill with `--sw-meal` bg / `--sw-meal-fg`
  and the word "Low", never just a red number. Out of stock = an ink pill with "Out".
- **Stock movements ledger** (append-only): looks like a long receipt. Each row shows a mono
  timestamp, the movement type as a pill (Sale, Receive, Transfer, Adjust, Count),
  a signed qty (`+12` / `−3`, never colored by hue alone, the sign is mandatory) and the actor.
  **No edit or delete buttons on movements, ever.** To correct stock, use an "Adjust stock"
  button that opens a form and appends a new movement.
- **Variants:** show them as chips under the product name (`Hot · 12oz`, `Iced · 16oz`).
  Variants are the sellable unit, so in the POS grid a product with several variants opens
  a small paper sheet listing its variants as big tiles (≥ 64px tall) rather than adding to the cart directly.
- **Warehouse bins** (only when `bins_enabled`): a grid of bin cards with a mono bin code
  (`A-03-2`) in Bricolage 700 and the qty. Show a "Bins total vs warehouse total" check row;
  when they differ, show an ink pill "Mismatch" plus the difference.
- **Forms:** labels above inputs in Inter 600 14px, inputs 48px tall, radius 14px,
  `1.5px --sand-line` border, focus = `2px solid --ink` outline. Primary action is the lime pill,
  bottom-right; Cancel is a text button beside it.
- **Empty states:** a stroke icon, one sentence, and one lime action button. No illustrations.
- **Dashboard/reports:** stat tiles are paper cards with a mono eyebrow label and a
  Bricolage 800 40px number. Charts use ink for the main series, lime for highlight only
  and sand-line for grid lines.

---

## 8. Hard rules / do NOT

- ❌ No default component-library look (plain shadcn grey cards, Bootstrap blue buttons, MUI).
- ❌ No gradients, glassmorphism, neon glow, purple.
- ❌ No emoji icons. No stock photos of people.
- ❌ No tiny headlines. No 1px hairline borders everywhere.
- ❌ No left-colored-border "alert" cards.
- ❌ Don't add new accent colors. Only lime.
- ✅ Touch targets ≥ 44px (cashiers use tablets).
- ✅ Text contrast ≥ 4.5:1 (use the muted tokens above; they pass).
- ✅ Responsive: columns wrap on narrow screens; the POS rail/grid/ticket stack on phones.
- ✅ Real `<button>` and `<label>` elements; `aria-label` on icon-only buttons.

---

## 10. Project-specific UI rules (match CLAUDE.md)

- **i18n:** no hard-coded strings in components. Every label, button and empty state goes
  through i18next keys with both `en` and `fil`. Tagalog text often runs **30–50% longer**,
  so buttons, pills and nav labels must wrap or grow: no fixed widths on text, and no
  `white-space: nowrap` except on prices and codes. Test each screen with `fil` before calling it done.
- **Roles and modules:** the nav and actions are built from the user's role and the tenant's
  enabled modules. Hide what they can't use. Don't show disabled, greyed-out items,
  and don't show POS or Warehouse nav when that add-on is off. The database still enforces this;
  the UI only hides.
- **Offline-first status chip** (top bar of every screen, and the POS header):
  - Online and synced: `--ok-bg` pill with a green dot, "Synced".
  - Offline: ink pill with a lime dot, "Offline · 3 queued" (mono count from the outbox).
  - Syncing: same pill with a small spinning stroke icon, "Syncing…".
  - Sync error: `--sw-meal` pill, "Sync issue". Tapping it opens details.
  Selling must **never** be blocked by being offline. The Charge button works offline.
- **No live-updating flicker on POS:** no Realtime. Data refreshes on poll, so don't animate
  lists in or out on refresh; keep each tile's position stable.
- **Tenant/store context** is always visible in the top bar (store name + location),
  so cashiers know which branch they're ringing up.
- **Timestamps** are stored in UTC and shown in the device's local time, in mono.

## 11. Optional: Tailwind mapping

If the project uses Tailwind, put the tokens in `tailwind.config` rather than using raw hex values in classes:
```js
theme: { extend: {
  colors: {
    ink: { DEFAULT: '#0F1A16', 2: '#16241F', line: '#24342D', line2: '#2F3F38' },
    paper: '#FFFDF5', sand: { DEFAULT: '#EDEAE1', line: '#D6D1C4' }, dash: '#C9C4B5',
    lime: { DEFAULT: '#D4F25A', hover: '#E4FF7A' },
    muted: { dark: '#B7C4BD', light: '#4A5A52' },
  },
  fontFamily: {
    display: ['"Bricolage Grotesque"', 'sans-serif'],
    sans: ['Inter', 'system-ui', 'sans-serif'],
    mono: ['"JetBrains Mono"', 'monospace'],
  },
  borderWidth: { DEFAULT: '1.5px' },
}}
```
Build the reusable pieces once (`<Receipt>`, `<Pill>`, `<LimeButton>`, `<MoneyText>`,
`<SyncChip>`, `<DataTable>`) in `src/ui/`, and have every screen use them.

## 12. Mobile parity (phone, tablet, native app)

**One source of truth:** `docs/tokens.json` holds every color, font, size, radius and spacing
value. Web turns it into CSS variables/Tailwind; the mobile app imports it as its theme.
Never copy hex values into mobile code by hand. "Parity" means **the same tokens,
the same components and the same i18n keys** on both platforms, not pixel-identical layouts.

### Breakpoints → layouts
| Width | Layout |
|---|---|
| ≥ 1024 (desktop, landscape tablet) | Full 3-column POS: rail · grid · ticket (§7) |
| 600–1023 (portrait tablet) | Rail becomes a **bottom tab bar**; grid on the left, ticket as a right panel at 340px |
| < 600 (phone) | Bottom tab bar; grid full width; ticket becomes a **bottom sheet** (below) |

### Phone POS (the important one)
- **Header:** store name (mono eyebrow) + "New order" title + SyncChip on the right. Search is an
  icon button that expands to a full-width field.
- **Category pills** scroll horizontally in one row (do not wrap on phone), sticky under the header.
- **Product grid:** 2 columns (3 on wide phones ≥ 400). Tiles keep the monogram swatch at 88px height.
- **Sticky charge bar** pinned to the bottom, above the tab bar and safe area: an ink bar holding
  "3 items" and the mono total on the left, and a lime **"Review"** button on the right.
  It is hidden when the cart is empty.
- **Ticket bottom sheet:** tapping the bar opens a sheet (radius 24 top corners, paper bg,
  zig-zag *top* edge so it reads as a receipt being pulled up). It holds the lines with steppers,
  Dine in/Take out, VAT/total, payment buttons and the full-width lime **Charge** (64px).
  Swipe down or tap the scrim to close. The variant picker is also a bottom sheet.
- **Paid state:** full-screen ink overlay, big lime check, amount in Bricolage, method in mono,
  "Start next order". Fire a light haptic on success.

### Back-office on phone
- Tables become **stacked cards**: a paper card per row, with the name (Inter 600) and the
  key number (mono, right-aligned) on top and secondary fields as label/value pairs below,
  separated by a dashed line. No horizontal-scroll tables on phone, except the movements
  ledger, which may scroll.
- Forms: one column, sticky bottom action bar holding the lime primary button (full width).
- Bins grid: 2 columns.

### Bottom tab bar (replaces the rail on < 1024)
Ink bar, max 5 items, built from role + modules (same logic as the rail).
The active tab is a lime pill behind the icon, with the label below in Inter 600 11–12px.
If there are more than 5 destinations, the 5th tab is "More" and opens a sheet.

### Native app specifics (React Native / Expo, if used)
- Load fonts with `expo-font` using the font names in tokens.json. Don't fall back to the system font.
- CSS pseudo-elements don't exist in RN, so draw the **zig-zag edge with `react-native-svg`**
  in a shared `<ZigzagEdge position="top|bottom" color={paper} />` component.
- No hover states on touch, so give pressed states instead: tiles scale to 0.98, buttons darken
  slightly (`opacity: 0.85` or the hover token).
- Respect safe areas (`react-native-safe-area-context`) for the charge bar and tab bar.
- Numbers: `fontVariant: ['tabular-nums']` on all MoneyText.
- Same component names as web (`LimeButton`, `Pill`, `Receipt`, `MoneyText`, `SyncChip`…)
  so the AI and developers can map one to the other.

### Touch rules (all platforms)
Min target 44px; product tiles ≥ 64px; Charge 64px; 8px minimum gap between tappable things.
Primary actions sit in the bottom third of the screen (thumb zone) on phone.

## 13. Self-check before you finish

1. Is the headline huge and tight?
2. Is lime the ONLY accent, and used sparingly?
3. Are all prices in JetBrains Mono with `₱`?
4. Is there at least one receipt-paper card with dashed dividers and a zig-zag edge?
5. Would this look out of place as a generic SaaS template? (It should.)
6. Does the screen still fit when switched to Tagalog (`fil`)?
7. Is the sync status chip visible, and does the screen work offline?
8. Are there zero hard-coded strings and zero hand-formatted money values?
9. Does it work at 360px wide (phone), with the charge bar and sheet, and at 768px (tablet)?
10. Are all values coming from tokens.json, with nothing hard-coded on mobile?

## 14. Brand assets
Logo files live in `public/brand/` (web) and `assets/brand/` (mobile):
`xzacto-logo-on-dark.svg` (ink backgrounds), `xzacto-logo-on-light.svg` (sand/paper backgrounds),
`xzacto-mark.svg` (the ticket mark alone), `xzacto-app-icon.svg` (PWA/app icon, 512),
`favicon.svg`. Never redraw, recolor or stretch the logo. Minimum mark size is 24px;
below that, use `favicon.svg`.
