# P8-13 Phase 8 acceptance report (solo store essentials)

Run on 2026-11-08 on branch `claude/phase3-sell-8261d3`. Nothing is pushed.

## Gate
`pnpm check` passed: lint, types, Vitest, pgTAP **2618 tests in 22 files**, `flutter analyze` clean, `flutter test` **271 passed**.

## What was built (cards P8-01 to P8-12)
| Card | Result |
| --- | --- |
| P8-01 | Long-press a Sell tile to pin a favorite (device-local). Top sellers already existed. |
| P8-02 / 02b / 02c | Expenses: server ledger, supervisor PIN approval, audit log; phone store and sync; day close record. |
| P8-03 | Expenses and Day close screens on Today; refused ops retry with a supervisor PIN. |
| P8-04 | Reports: profit after expenses; stock purchases not double counted. |
| P8-05 | Restock list (pasuyo) from low stock, copy as text. |
| P8-06 / 07 | Load and e-wallet ledger (cash in/out, load, float) and screens. |
| P8-08 / 09 | Tingi: pack to piece link, open a pack, exact cost split; screens. |
| P8-10 | Utang pay-by date, overdue list and badge, shareable statement (no phone, no notes). |
| P8-11 | One expiry date per product (earliest on the shelf), "expiring" filter and Home badge. |
| P8-12 | CSV export of sales, utang and stock from Settings. |

## Checked on the Android emulator (Pixel 4, API 33, debug build, local Supabase)
- Sign in with a new local account, name the store, Home loads (Filipino default).
- Today shows the new Load & e-wallet, Expenses and Close the day cards.
- Added an expense of 125.50 through the form; the list and total updated at once, the badge went green, and the **server received it**: `expenses` has 12550 centavos, `audit_log` has one `expense.record` row.
- Close the day: expected cash and the live short/over line work (typed 50, saw "Sobra ng 175.50").
- Load & e-wallet screen opens and shows the four actions.
Screenshots: `docs/p8-acceptance/`.

## Not checked on a device (tests only)
Selling and pinning on Sell, load entries and float moves, tingi (product form and open a pack), expiry, pay-by dates and statement sharing, CSV sharing, supervisor PIN approval (needs a second user with a PIN), offline then reconnect, Reports with expenses. These have widget and store tests but no emulator run.

## Findings to fix (go into the UI revamp)
1. ~~Expense dialog is cramped with the keyboard open~~ FIXED: now a bottom sheet (screenshot `11_expense_sheet.png`). The Save button still needs a scroll below the note.
2. ~~Filipino labels are truncated~~ on the Load & e-wallet action buttons ("Magbenta n...", "Galawin an..."): the four buttons now allow two lines (not re-checked on the device).
3. Today: the Expenses and Close-the-day cards are now the same height (fixed); the screen is still busy and is the main target of the bottom-tab step.
4. **Day close has no opening cash (sukli).** With only an expense and no sales, expected cash is negative (-125.50). Add an optional starting cash to the day close.
5. **E-wallet sale payments and e-wallet expenses do not move the wallet float** (no wallet is named). The owner corrects with a float adjustment.
6. Fixed during this phase: garbled characters in the utang ledger (a double-encoded middle dot and minus sign) and a Settings change that broke two tests.

## Risks and open items
- ~~The P8-11 migration file was edited after it was applied locally.~~ RESOLVED 2026-11-08: a clean `supabase db reset` (owner approved) replayed all 23 migrations without errors, and `pnpm check` then passed on the fresh database (pgTAP 2618 in 22 files, Flutter 275). The local demo data and the test account `p813.accept@example.com` were wiped; create a new account in the app to test again.
- `SupabaseBackend` calls for the new pulls and PIN approval were only tested through fakes and the one expense sync above.
- Supervisor-only admins need signal once to get a PIN approval; offline approval is a Full-mode item.
- Refused ops (missing approval) are not written to the audit log; wrong PINs are.
- Release APK signing still needs the owner's keystore (not created).

## UI revamp, step 1 (calm look) done after the acceptance run
Flat tinted icon circles instead of glowing coins, one solid primary button instead of the dark `>>>` pill (the `obsidian` token now equals the palette primary), one light shadow per card, amount owed shown first on the Utang tile. Screenshot `10_home_revamp.png`. `flutter analyze` clean, 271 tests pass.
**Step 2 done: bottom tabs.** `HomeShell` (`lib/screens/home_shell.dart`) replaces the old Home: tabs Sell (opens first), Stock, Utang, Reports (owner/admins) and More (products, restock, Today, expenses, load and e-wallet, close the day, settings). Today is a strip on top of Sell. Badges on Stock (low + expiring) and Utang (overdue). The phone back button goes to Sell first. Screenshots `12_tabs_sell.png`, `13_tabs_more.png`. 275 Flutter tests pass.
Two real fixes came out of it: Sell now stays alive in its tab, so its quick tiles refresh when products arrive (before, the first sync would have left them empty until a sale), and the Stock badge is also shown while that tab is selected.
Not done: the Keypad tab on Sell (planned after load/e-wallet), and a device check of the Stock, Utang and Reports tabs.

## Import & export (added after the tabs)
More > "Import & export" (`DataScreen`, owner/admins). **Export** (CSV through the share sheet): products, sales, utang, stock; the export section was moved out of Settings. **Import**: paste rows copied from a spreadsheet (tabs, commas or semicolons; header optional, English or Filipino column names; order without a header: name, price, barcode, cost, stock). The sheet shows how many rows are ready and which rows have problems; confirming adds them as products with opening stock. Rows with a barcode already in use (or repeated in the paste) are skipped and counted. At most 500 rows per paste. "Copy the column names" gives a header to start a spreadsheet; an exported product list can be pasted straight back in. No file picker (no new dependency); a file import can be added later. 287 Flutter tests pass; not run on the emulator yet.
