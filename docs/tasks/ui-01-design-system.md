# UI-01 — Design system foundation

**Read first:** `docs/design.md` (whole file). Do not read docs/plan.md for this task.
**Model:** Sonnet.
**Scope:** UI only. Do not touch migrations, RPCs, RLS, the sync engine or stock math.

## Goal
Replace the default/plain styling with the design system in `docs/design.md`,
starting with shared building blocks so every later screen inherits the look.

## Steps
0. Copy `tokens.json` to `docs/tokens.json` and the logo files to `public/brand/`
   (and `assets/brand/` in the mobile app). Generate the CSS variables / Tailwind theme / RN theme
   **from tokens.json** rather than retyping the values.
1. Add the fonts (Bricolage Grotesque, Inter, JetBrains Mono) and the color tokens
   (CSS variables, and the Tailwind theme if Tailwind is used) exactly as in §2, §3 and §11.
2. Create `src/ui/` components: `LimeButton`, `GhostButton`, `Pill`, `Segmented`,
   `Receipt` (zig-zag edge + dashed dividers), `MoneyText` (uses the shared
   `formatMoney(minor, currency, locale)`), `SyncChip` (4 states from §10), `DataTable`,
   `StatTile`, `EmptyState`, `AppShell` (ink icon rail + top bar).
3. `AppShell` builds the nav from role + enabled modules (hide, don't disable).
4. All component text goes through i18next keys (`en` + `fil`).
5. Add a `/dev/ui` page (dev builds only) that renders every component in every state,
   in both English and Tagalog.

## Done when
- [ ] No component uses raw hex values outside the token file.
- [ ] `/dev/ui` shows every component and state; nothing overflows in `fil`.
- [ ] Self-check in `docs/design.md` §12 passes.
- [ ] `pnpm check` passes.
- [ ] Commit, update `docs/handoff.md`.

---
### Follow-up cards (one per session, /clear between)
- **UI-02** Landing page → design.md §7 "Landing page"
- **UI-03** POS register → §7 "POS register" (variant picker sheet, offline Charge)
- **UI-04** Inventory: products/variants list + stock levels table
- **UI-05** Stock movements ledger + Adjust stock form (append-only)
- **UI-06** Warehouse: bins grid + mismatch check (only when `bins_enabled`)
- **UI-07** Dashboard/reports stat tiles + charts (read rollup tables)
- **UI-08** Responsive pass: bottom tab bar, phone POS (charge bar + ticket sheet), stacked-card tables (§12)
- **UI-09** Mobile app parity: same components from tokens.json, ZigzagEdge via react-native-svg (§12)
