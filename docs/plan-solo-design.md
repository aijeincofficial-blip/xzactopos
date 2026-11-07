# Plan: Solo design pass (before Full mode)

Status: DRAFT for owner review. Nothing here is built.
Assumption: "design" means the look, feel and flow of the solo Flutter app (`apps/mobile`), not new features. Confirm or correct this first (see Open questions).

## Deferred: Phase 7 leftovers (come back later)
| Item | State | When |
| --- | --- | --- |
| Offline web in normal Chrome | Done, verified 2026-11-07 (needs `--pwa-strategy=none`, two online loads) | closed |
| Barcode decoding on a device | Skipped by owner | Before the pilot, with a real phone and real barcode, or an `analyzeImage` probe on a generated EAN-13 PNG |
| Release APK signing | Owner must create and keep the keystore | When the owner is ready; never generate it without asking |
| Bluetooth/thermal printer | Not testable here | When a printer is available |

## Goal
A tindera on a cheap Android phone, one hand, patchy signal, mostly Filipino, can sell, restock and check utang without thinking. Every screen should look like it belongs to one app.

## Current state (from the code)
Screens: auth, store name, home, sell, pay, receipt, today, products, product form, stock, utang, reports, password screens. Shared parts: `cart`, `customer_picker`, `product_thumb`, scanner, printer. No shared design system document exists yet.

## Steps (each is a small card, `docs/tasks/D-NN-*.md`, with acceptance before the next)
1. **D-01 Audit (no code).** Walk every screen on the emulator and on web at 360x640 and 412x915. List: inconsistent spacing, colors, button styles, tap targets under 48 dp, text under 14 sp, screens with no empty/loading/error state, and the number of taps for the 5 core jobs (sell cash, sell utang, add stock, add product, see today's total). Output: `docs/design-audit.md` with screenshots.
2. **D-02 Design tokens and theme.** One place in `lib/core/theme.dart`: color scheme (high contrast, readable in sunlight), type scale, spacing scale, button and input styles, light theme first, dark optional. No hard-coded colors or sizes in screens afterwards.
3. **D-03 Core flow design: Sell.** Fewest taps to a paid sale: big product tiles with photo, quick-item buttons, running total pinned at the bottom within thumb reach, keyboard never covers the cart, one-tap exact cash and common bills, utang in two taps.
4. **D-04 Home and navigation.** Home shows only what a solo owner needs: Sell (largest), Today total, Low stock count, Utang owed. Hide anything for Full mode. Decide bottom bar vs tiles.
5. **D-05 Stock, Products, Utang, Reports restyle.** Apply tokens; clear empty states ("No products yet, add your first"); consistent list rows and forms; confirm dialogs for void and utang adjust.
6. **D-06 States and feedback.** Standard patterns for offline, "not sent" (sync pending), sync error, session expired. Plain Filipino and English wording, no technical terms. Check all strings go through ARB files with `{count}` plurals.
7. **D-07 Accessibility and low-end performance.** Font scale up to 1.5x without clipping, tap targets 48 dp, screen reader labels on icon buttons, scrolling lists stay smooth on the emulator with 2,000 products, cold start time recorded.
8. **D-08 First-run experience.** Sign up, name the store, add first product (or skip), first sale. Short, skippable, Filipino default.
9. **D-09 Acceptance.** Test with one real tindera or the owner on a real phone doing the 5 core jobs; record taps, time and confusion points; fix the top items. `pnpm check` green, update `docs/handoff.md`.

## Rules (unchanged, from CLAUDE.md)
No migration edits. Strings only in ARB (English + Filipino). Run `flutter test` before committing, `pnpm check` before declaring done. Web builds use `--pwa-strategy=none`. This pass should need no database changes; if one appears, stop and ask.

## Decisions (owner, 2026-11-07)
1. Scope: front-end design only (look, feel, flow of the solo app). No new features, no database changes.
2. Look: brand stays blue, but fresh and cool to the eye, with an "abundant" feel that suits a sales POS (think prosperity: clean, bright, confident). Candidate direction for D-02: cool blue primary with a fresh teal/mint accent for money and success, soft off-white surfaces, generous rounded cards. Palette to be shown to the owner as 2 options before it is applied.
3. Themes: light and dark both (dark must keep money and stock status readable).
4. Testing: Android emulator (Pixel_4_API_33) is the test device for D-09; no real phone or tindera required.
5. Order: this design pass first, then Full mode.
