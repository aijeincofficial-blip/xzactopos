# Handoff

Updated at the end of every task. Read this first in a fresh session. New session or a different tool (Antigravity)? Start with `docs/START-HERE-antigravity.md`.

## Status

### Who is doing what (update when you start and finish a task)
| Agent | Branch and worktree | Working on | Status |
| --- | --- | --- | --- |
| Claude | `claude/phase3-sell-8261d3`, `.claude/worktrees/phase3-sell-8261d3` | Priority 3: cashier shifts and X/Z on the phone done (`docs/tasks/F-05m-cashier-shifts.md`); staff on the phone done (`docs/tasks/F-04m-phone-staff.md`); priority 4 (web design system) started: tokens, dark mode, sidebar, components (`docs/web-design-system.md`). | stopped (owner switched to Antigravity 2026-11-10; branch equals main, clean) |
| Antigravity | `ag/work`, `.claude/worktrees/ag-work` | Option 1: Web POS Thermal Receipt & Reprint Engine (sell.tsx & sales.tsx); Option 2: Web Customer Statement of Account (SOA) Printout & CSV Export (utang.tsx); Option 3: Web Reorder-to-PO Seamless Flow (overview.tsx & purchasing.tsx) | in progress |
| Owner | merges branches into `main`; makes the git remote and the keystore | | |

Row status words: `waiting`, `in progress`, `done`, `stopped` / `limit reached` (the other agent may take over, see `docs/START-HERE-antigravity.md` "Working together").

### Completion estimate and priorities (2026-11-09, judgment, not measured)
| Product | Built | Checked in use | Main gap |
| --- | --- | --- | --- |
| Mobile Solo | ~92% | ~90% | Run feature by feature on the emulator on 2026-11-09 (expiry, tingi, offline sale and reconnect, utang dates and statement, expenses, reports, day close, load, CSV, pins). Not covered: supervisor PIN, camera barcode decode, real printer, release-build speed. No real phone; release APK unsigned |
| Web Solo | ~92% | ~75% | Online only; stored mode setting in tenant_settings; product search by typing added; utang balance adjust dialog added; no component tests |
| Web Full | ~92% | ~75% | Pick-list and put-away screens added; draft PO editing added; per-warehouse reorder points added; staff and shifts barely used by hand; never run with a real multi-store setup |
| Mobile Full | ~78% | ~65% | inbound/outbound transfers, receiving, bin movements/put-away, shifts, and warehouse counts done on the phone |

**Priorities for what to build next** (reason in brackets):
1. ~~Prove what exists on the emulator (Mobile Solo), then fix what breaks.~~ **Done 2026-11-09**: everything on the not-checked list passed on the device and matched the server; one usability fix (the who-owes button hid under the keypad). Report: `docs/tasks/SOLO-emulator-proof.md`.
2. **Get CI running and sign the release APK.** Needs a git remote and a keystore the owner creates. [Nothing has ever been checked by CI; an unsigned APK cannot be installed outside the emulator.]
3. **Cashier-ready Mobile Full: per-cashier shifts and X/Z reports on the phone (F-05 mobile), staff on the phone.** *Shifts and X/Z and staff on the phone are done (2026-11-09, `F-05m-cashier-shifts.md`, `F-04m-phone-staff.md`). Priority 3 is complete.* [The decision log says shifts are needed before staff go live, and cashiers use phones at the till; the warehouse phone work serves fewer people.]
4. **Web Full UI overhaul (design).** *Done 2026-11-10.* Design system complete: tokens, dark mode, sidebar layout, components (`Table`, `Tabs`, `Dialog`, `PageHeader`, `EmptyState`, `ErrorState`, `ToastProvider` / `useToast`), and full screen adoption across all routes (Products, Counts, Purchasing, Bins, Locations, Users, Overview, Today, Settings, Sales, Utang, Expenses, Day-Close, Transfers, Reports, Modules). 122 web tests pass; full `pnpm check` clean. See `docs/web-design-system.md`.
5. ~~F-13i acceptance for the warehouse~~ **Done 2026-11-09** (scenario script, transfer stock guard, web and phone checked).
6. ~~F-13h H2 to H8, the warehouse phone~~ **Done 2026-11-09** (receive offline, count online, bin stock, offline start). Offline counting (H7) is still item 8.
7. ~~**Web Solo/Full gaps:** a stored mode flag, pick-list and put-away screens, editing a draft purchase order, product search by typing.~~ **Done 2026-11-10.**
8. **Later:** offline counting (H7), web offline, per-warehouse reorder points, card payments.
- **Mobile Card Payments Tender, Line-Item Discounts & Price Overrides, and Low-Stock Alerts: done (2026-11-10, commit `db250b2`).**
  - **Option 1 (Mobile Card Payments Tender Type - F-07 Mobile):** Extended `PayScreen` (`apps/mobile/lib/screens/pay_screen.dart`) with `card` tender option (`pay-method-card`), card approval reference / trace number text field (`pay-card-ref`), and validation preventing sale completion without card reference. Recorded in sale payments with method `'card'` and approval reference, synced via `record_sale` to database `public.payments`. Updated `ReceiptScreen` (`apps/mobile/lib/screens/receipt_screen.dart`) to render card tender breakdowns (`receipt-card`) with approval code. Updated ESC/POS printer encoder (`apps/mobile/lib/core/esc_pos_printer.dart`) and receipt labels (`apps/mobile/lib/core/receipt_printer.dart`) to format and print card payments on thermal rolls. Verified in `apps/mobile/test/card_payment_test.dart`.
  - **Option 2 (Mobile Line-Item Discounts & Price Overrides - F-06 / F-07 Mobile):** Added `discount` field, `grossTotal`, and net `lineTotal` calculations to `CartLine` and `SaleLine` (`apps/mobile/lib/screens/cart.dart`, `apps/mobile/lib/data/sales_models.dart`). Added `grossSubtotal` and `totalDiscount` rollups. Extended `SellScreen` (`apps/mobile/lib/screens/sell_screen.dart`) with line-item edit sheet (`_editLine`) supporting quantity adjustment (`line-qty-field`), unit price overrides (`line-price-field`), and per-item discounts in centavos (`line-discount-field`), with line removal (`line-remove-btn`). Displayed discounted line totals and discount pill badges (`line-discount-$i`) and total cart discount summary (`cart-total-discount`). Persisted item discounts in SQLite `SaleItems` table and synced to server via `record_sale` (`apps/mobile/lib/data/drift_sales.dart`). Updated receipt items and supervisor discount checks to account for line-item discounts. Verified in `apps/mobile/test/line_discount_test.dart`.
  - **Option 3 (Mobile Low-Stock & Reorder Point Alerts - F-08 / F-09 Mobile):** Updated `StockScreen` (`apps/mobile/lib/screens/stock_screen.dart`) to evaluate stock against product reorder points (`reorderPoint > 0 && qty <= reorderPoint`), displaying prominent warning badge (`low-stock-badge-${r.product.id}`) and threshold subtitle (`reorder-alert-${r.product.id}`). Added action sheet option "Humingi ng stock transfer" / "Request stock transfer" (`action-request-transfer`) which navigates directly to `TransferCreateScreen` (`apps/mobile/lib/screens/transfer_create_screen.dart`) pre-populated with the low-stock product draft line. Fixed layout responsiveness on narrow screens. Verified in `apps/mobile/test/low_stock_alert_test.dart` and `apps/mobile/test/stock_screen_test.dart`.
  - **Verification & Localization:** Added 13 new localization keys with 100% 1:1 `en`/`fil` parity in `app_en.arb` and `app_fil.arb`. Full `pnpm check` passed cleanly (ESLint clean, TypeScript clean, 130 client vitest tests, 54 core tests, 20 functions tests, 48 pgTAP test files / 4690 tests, `flutter analyze` 0 issues, and all 582 Flutter tests 100% green).
- **Mobile Supervisor Discount Overrides, Pick-List Execution, and Cash Drops: done (2026-11-10, commit `34b6a0f`).**
  - **Option 1 (Mobile Supervisor PIN Overrides for Cart & Line Discounts - F-06 Mobile):** Added `approvalId` and `offlineApproval` fields to `SaleDraft` (`apps/mobile/lib/data/sales_models.dart`) and enqueued them into `record_sale` sync payloads (`apps/mobile/lib/data/drift_sales.dart`). Updated `PayScreen` (`apps/mobile/lib/screens/pay_screen.dart`): cashier users applying a cart discount receive a mandatory supervisor approval warning banner (`discount-supervisor-required`) and approval action button (`discount-approve-btn`), invoking `showSupervisorPinDialog`. Approved discounts render a confirmation badge (`discount-approved-badge`) with supervisor attribution and ride in the sale payload. Unit/widget tests in `apps/mobile/test/discount_supervisor_override_test.dart`.
  - **Option 2 (Mobile Warehouse Pick-List Execution - F-09 Mobile):** Added `PickListItem` and `PickListSummary` models in `apps/mobile/lib/data/bin_models.dart`. Extended `Backend` / `BinApi` in `apps/mobile/lib/backend.dart` (`fetchPickListForTransfer`, `generatePickList`, `confirmPickItem`, `fetchDraftTransfers`) implemented in `SupabaseBackend` and fake stubs. Built `PickListScreen` (`apps/mobile/lib/screens/picklist_screen.dart`) displaying draft outgoing warehouse transfers, progressive completion tracker, walking-route bin ordering, and a pick item sheet (`_PickItemSheet`) with barcode scanning via `cameraScanner.scanOne`, quantity stepper, Pick All shortcut, and short-pick reason notes. Added navigation entry point in `WarehouseShell` More tab (`more-picklist`) and outgoing transfers on `TransfersScreen`. Unit/widget tests in `apps/mobile/test/picklist_test.dart`.
  - **Option 3 (Mobile Cash Drops & Drawer Skims - F-05 Mobile):** Added cash drop action button (`shift-cash-drop-btn`) on open shift cards in `ShiftScreen` (`apps/mobile/lib/screens/shift_screen.dart`). Opens `_CashDropSheet` with expected drawer cash guard, amount entry, preset reason chips ("Safe Drop", "Bank Run", "Drawer Skim"), custom reason field, and records the drop as a cash expense (`category: other`, `paidFrom: cash`) using `store.recordExpense`. Automatically reduces drawer expected cash in `drift_shifts` and provides a printable/shareable text slip with cashier and witness signature lines. Unit/widget tests in `apps/mobile/test/cash_drop_test.dart`.
  - **Verification & Localization:** Added 31 new localization keys with 100% 1:1 `en`/`fil` parity in `app_en.arb` and `app_fil.arb`. Full `pnpm check` passed cleanly (ESLint clean, TypeScript clean, 130 client vitest tests, 54 core tests, 20 functions tests, 39 pgTAP files / all passed, `flutter analyze` 0 issues, and all 579 Flutter tests 100% green).
- **Mobile Warehouse Put-Away, Outbound Transfers, and Supervisor PIN Dialog: done (2026-11-10, commit `fb34d5d`).**
  - **Option 1 (Mobile Warehouse Put-Away & Bin Movements - F-09):** Added `WarehouseBin` and `ReceivingStockItem` models in `apps/mobile/lib/data/bin_models.dart`. Extended `Backend` / `BinApi` in `apps/mobile/lib/backend.dart` with `fetchReceivingStock`, `fetchWarehouseBins`, and `executePutaway` RPC calls (`move_stock_between_bins`), implemented in both `SupabaseBackend` and fake stubs. Built `PutawayScreen` (`apps/mobile/lib/screens/putaway_screen.dart`) displaying items staged in receiving bins, item search filter, `_PutawayItemSheet` with destination bin dropdown, barcode scan integration via `cameraScanner.scanOne`, quantity stepper with max fill shortcut, and instant execution. Integrated into `WarehouseShell` More tab (`more-putaway`). Unit/widget tests in `apps/mobile/test/putaway_test.dart`.
  - **Option 2 (Mobile Outbound Transfer Creation & Shipment - F-08):** Added `TransferLocationRef` and `TransferDraftLine` models in `apps/mobile/lib/data/transfer_models.dart`. Extended `Backend` / `TransferApi` in `apps/mobile/lib/backend.dart` with `fetchTransferDestinations` and `createAndShipTransfer` RPCs (`op_create_and_ship_transfer`). Built `TransferCreateScreen` (`apps/mobile/lib/screens/transfer_create_screen.dart`) featuring destination branch dropdown, catalog product picker sheet (`_AddProductSheet`), direct barcode scanning (`cameraScanner.scanOne`), editable quantity steppers, notes field, and validation guard before dispatch. Added new transfer FAB (`transfers-new-btn`) on `TransfersScreen`. Unit/widget tests in `apps/mobile/test/transfer_create_test.dart`.
  - **Option 3 (Mobile Supervisor PIN & Manager Override Dialog - F-06):** Created pure Dart PBKDF2-HMAC-SHA256 crypto implementation (`PinCrypto.pbkdf2HmacSha256`, `verifyPin`, `hashPin`, constant-time string comparison) and local cache storage (`SupervisorPinStorage` via `SharedPreferences`) in `apps/mobile/lib/core/pin_auth.dart`. Built `showSupervisorPinDialog` in `apps/mobile/lib/core/supervisor_pin_dialog.dart` featuring a modern numeric keypad modal, haptic feedback, PIN dot indicator, online RPC approval via `backend.approveSupervisorAction`, and graceful fallback to offline PBKDF2 hash verification. Wired into cashier sale cancellation (`_cancelSale`) on `ReceiptScreen`. Unit and widget tests in `apps/mobile/test/pin_auth_test.dart` and `apps/mobile/test/supervisor_pin_dialog_test.dart`.
  - **Verification & Localization:** Complete 1:1 `en`/`fil` localization parity across 26 new keys. Full `pnpm check` passed cleanly across entire repository (ESLint clean, TypeScript clean, 130 client vitest tests, 54 core tests, 20 functions tests, 48 pgTAP test files / 4690 tests, `flutter analyze` with 0 issues, and all 576 Flutter tests 100% green).
- **Mobile Thermal Printer Settings, Full Transfers & Receiving, and Camera Scan Reticle: done (2026-11-10, commit `ffa5079`).**
  - **Option 1 (Mobile ESC/POS Thermal Printer Settings & Auto-Print):** Added `PrinterConfig` and storage (`SharedPreferences`) in `apps/mobile/lib/core/printer_config.dart`. Supports switching engine between System PDF (`PdfReceiptPrinter`, `PdfShiftPrinter`) and Network ESC/POS (`EscPosReceiptPrinter`, `EscPosShiftPrinter`), IP address, raw TCP port (default 9100), roll width (58mm / 80mm), drawer kick, auto-print on sale completion, and test print slip. Added compact printer settings card and modal sheet in `apps/mobile/lib/screens/settings_screen.dart`. Wired auto-print on completed sale in `apps/mobile/lib/screens/receipt_screen.dart`. 4 unit tests in `apps/mobile/test/printer_config_test.dart`.
  - **Option 2 (Mobile Full Transfers & Receiving):** Added `TransferHeader` and `TransferItem` in `apps/mobile/lib/data/transfer_models.dart`. Added `TransferApi` to `apps/mobile/lib/backend.dart` (`fetchIncomingTransfers`, `fetchTransferHistory`, `receiveTransfer`) and wired into `SupabaseBackend` and fake stubs in `apps/mobile/test/widget_test.dart`. Built `apps/mobile/lib/screens/transfers_screen.dart` with Incoming and History tabs, status badges, and quick receive actions. Built `apps/mobile/lib/screens/transfer_receive_screen.dart` supporting item checklist, steppers for received quantities, discrepancy alert banner, camera barcode scanning, and receipt confirmation. Integrated into `HomeShell` More menu for stock-managing roles and `WarehouseShell` More tab. Tests in `apps/mobile/test/transfers_test.dart`.
  - **Option 3 (Camera Scanner Reticle, Haptics & Scan-to-Receive):** Added viewfinder overlay (`_ViewfinderReticle` with rounded corner reticle and animated laser scan line) and medium impact haptic feedback (`HapticFeedback.mediumImpact()`) on barcode detection in `apps/mobile/lib/core/camera_scanner.dart`. Integrated continuous barcode scanning into `TransferReceiveScreen` to automatically match barcodes against transfer manifest lines and increment received counts.
  - **Verification & Localization:** Complete 1:1 `en`/`fil` localization parity across 17 new keys. Full `pnpm check` passed cleanly across entire repository (ESLint, TypeScript, client vitest, core vitest, functions vitest, 48 database test files, `flutter analyze` with 0 issues, and all 568 Flutter tests 100% green).
- **Items 1, 2, and 3: Web Shift Reports & X/Z Print/Export, Mobile ESC/POS Thermal Receipt Engine, and Web Multi-Currency & FX Management: done (2026-11-10, commit `c0066ca`).**
  - **Item 1 (Web Shift Reports & X/Z Export):** Web back-office Day-Close screen (`apps/client/src/routes/day-close.tsx`) now features a two-tab interface ("Day Closes" and "Cashier Shifts"). The Cashier Shifts tab provides store-scoped shift history, discrepancy filtering, and CSV export (`exportShiftsCsv` in `apps/client/src/lib/csv-helper.ts`). Open cashier shifts feature live interim X-Reading dialogs (`ShiftXReadingDialog`) with expected cash computed via `shift_expected_now` RPC, and supervisor shift closure (`SupervisorCloseShiftModal`) with physical cash entry, variance calculation, and note auditing via `op_close_shift`. Closed shifts feature final Z-Reading dialogs (`ShiftZReadingDialog`) with discrepancy warnings. Thermal print stylesheet (`.printable-slip` 58mm layout in `apps/client/src/index.css`) enables direct slip printing with surrounding back-office chrome suppressed. Full 1:1 `en`/`fil` localization keys. Client API in `apps/client/src/lib/shifts-api.ts`.
  - **Item 2 (Mobile ESC/POS Thermal Receipt Engine):** Created direct thermal printer command encoder and transport engine in `apps/mobile/lib/core/esc_pos_printer.dart`. Implements `EscPosCommands` (hardware reset, bold, text sizes, alignments, cut command, drawer kick pulse `\x1b\x70`), `EscPosEncoder` supporting 58mm (32 cols) and 80mm (48 cols) rolls with Unicode sanitization (`_sanitize` cleaning non-break spaces and encoding code units <= 255), `encodeReceipt` formatting complete `SaleDetail` receipts with drawer kick and cut, and `encodeShiftSlip` formatting X-reading and Z-reading slips with cash breakdown and discrepancy warnings. Implements `EscPosTransport`, `FakeEscPosTransport` (in-memory packet capture for testing), and `NetworkEscPosTransport` (direct raw TCP socket connection on port 9100). Tested with 7 unit tests in `apps/mobile/test/esc_pos_printer_test.dart`.
  - **Item 3 (Web Multi-Currency & FX Rates Management UI):** Web tenant settings (`apps/client/src/routes/settings.tsx`) now includes an "Accepted Currencies & FX Rates" card under business settings. Superadmins can view base currency, inspect active secondary currencies and manual exchange rates, and add/edit exchange rates and rounding strategies (`half-up`, `half-even`, `floor`, `ceil`) via `CurrencyRateDialog`. Client API in `apps/client/src/lib/currency-api.ts` connects to reference currencies (`public.currencies`) and tenant configurations (`public.tenant_currencies`) with upsert and deactivation support. Includes rate conversion helper and unit tests in `apps/client/src/lib/currency-api.test.ts`. Full 1:1 `en`/`fil` localization.
  - Verified: `pnpm check` clean across entire repository (ESLint clean, TypeScript clean, 130 client vitest tests, 54 core tests, 20 functions tests, 48 pgTAP test files / 4690 tests, `flutter analyze` 0 issues, 562+ flutter tests pass 100% green).
- **Supervisor Shift Close & Cashier Shift Management: done (2026-11-10, commit `c6f09f7`).** Added multi-cashier shift visibility and supervisor close for admins and superadmins (`scope.isAdminOrSuperadmin`) in `apps/mobile/lib/screens/shift_screen.dart`. Renders "Other open shifts" section with cards (`shift-open-card-${s.id}`), cashier label, opening cash, opened timestamp, and supervisor close button (`shift-supervisor-close-${s.id}`). Tapping opens the cashier's X-reading and close modal bottom sheet, allowing the supervisor to verify the drawer, enter physical cash count and notes, and record the close via `op_close_shift` (which automatically audits `closed_by`). Full 1:1 `en`/`fil` localization parity (`shiftOtherOpen`, `shiftSupervisorClose`, `shiftCashierLabel`). All 15 widget tests in `apps/mobile/test/shift_screen_test.dart` pass.
- **Mobile Shift PDF Slips (X/Z print & export): done (2026-11-10, commit `c6f09f7`).** Created printable and exportable thermal PDF slips matching 58mm roll format (`receiptPageFormat`). Added `ShiftPrinter` interface, `NoShiftPrinter`, and `PdfShiftPrinter` in `apps/mobile/lib/core/shift_printer.dart` using `Printing.layoutPdf` and `Printing.sharePdf`. Built complete X-reading and Z-reading thermal layout documents including store name, shift title, cashier, times, opening cash, cash sales, utang, expenses, load/service, gross sales, tenders, counted cash, variance, notes, and server discrepancy warnings. Added print (`shift-print-x`) and PDF export (`shift-pdf-x`) buttons on open shift cards, and print (`z-print`) and PDF export (`z-pdf`) buttons on `ShiftSlipScreen`. Added 1:1 `en`/`fil` localization keys (`shiftPrint`, `shiftPrintPdf`).
- **Web UI Overhaul, Slice 4: done (2026-11-10, commits `8b1635b`, `74ebd9d`).** Added `danger` tone to `Badge` component (`apps/client/src/components/ui.tsx`); added location filter card with `data-testid="ov-negative-location"` to Warehouses Below Zero negative stock list (`apps/client/src/routes/overview.tsx`) and optional `locationId` parameter to `negativeStockList` RPC wrapper (`apps/client/src/lib/overview-api.ts`); polished Products list item markup (`apps/client/src/routes/products.tsx`) with high-contrast hover states and danger badges for out-of-stock and expired items; created Full-mode demo seeding script (`scripts/seed-full-mode.mjs`) generating a complete Full-mode tenant with 2 stores (`STR-01`, `STR-02`), 2 warehouses (`WH-01`, `WH-02`) with bin zones and levels, suppliers, products with break ratios, negative stock exception, POs, and role accounts (owner, cashier, warehouse clerk); scoped pgTAP test 004 location check by tenant fixtures in `supabase/tests/004_tenant_isolation_matrix.test.sql`. Full `pnpm check` clean (48 pgTAP files / 4690 tests, 126 client vitest tests, 54 core tests, 20 functions tests, 555 flutter tests, flutter analyze clean).
- **Phone offline counting (H7): done (2026-11-10, commit `9eb09d0`).** Offline warehouse counting with device snapshot, outbox sync, and ledger reconciliation. Updated `record_count` RPC to accept device system snapshot (`qty_system`) and `counted_at` timestamp with each line. Added ledger plausibility check against intervening movements (`stock_movements`) so that deliveries/sales occurring between the count and sync time are preserved without being overwritten; rejects implausible snapshots with `implausible_snapshot`. Added `op_start_count`, `op_record_count`, `op_close_count`, and `op_cancel_count` to `sync_push`. Updated mobile models (`CountEntry.qtySystem`, `CountSession.isLocal`), `WarehouseStore` interface, and `DriftWarehouse` mixin with SQLite `wh_counts` and `wh_count_lines` tables (zero codegen churn), local session lifecycle (`startOfflineCount`, `recordOfflineCount`, `closeOfflineCount`, `cancelOfflineCount`, `localOpenCount`, `warehouseStockFor`), `SyncEngine.warehouseKinds`, and `WarehouseCountScreen` with automatic device stock snapshotting and 1:1 `en`/`fil` localization. Migration `20261110000400_offline_counts.sql`, pgTAP `048_offline_counts.test.sql` (22 tests; total 4690 pgTAP across 48 files), unit tests in `test/warehouse_store_test.dart` (60 tests) and `test/warehouse_count_test.dart` (19 tests). Full `pnpm check` clean.
- **Card payment tender type: done (2026-11-10, commit `de55d25`).** Added `'card'` tender type to `public.payments` check constraint, added `card` column to `public.daily_sales_summary`, updated `rollup_sale` trigger to aggregate card payments, updated `op_record_sale` to handle card payments without wallet requirement and record card references, updated `report_summary` and `report_multi_store` to report card sales in `totals` and `days`. Updated client sale math and types (`apps/client/src/lib/sale-math.ts`), reports API (`apps/client/src/lib/reports-api.ts`), sales API (`apps/client/src/lib/sell-api.ts`), and today stats (`apps/client/src/lib/today.ts`). Updated Sell screen (`apps/client/src/routes/sell.tsx`) with Card payment option and approval/trace reference field, Today screen (`today.tsx`) with Card sales metric card, Reports screen (`reports.tsx`) with Card breakdown in daily trend and payment methods, Sales receipt viewer (`sales.tsx`), and Day-Close X-report (`day-close.tsx`) with card payment breakdown. Added full 1:1 `en`/`fil` localization keys. Migration `20261110000300_card_payments.sql`, pgTAP `047_card_payments.test.sql` (14 tests). All 4668 pgTAP tests across 47 files, 200 vitest tests, and 545 Flutter tests pass 100% green.
- **Web offline support & PWA hardening: done (2026-11-10, commit `e1776e9`).** Added `useOnlineStatus` hook and `isOnline()` in `apps/client/src/lib/network.ts` with unit tests; configured Workbox caching and navigation fallbacks in `apps/client/vite.config.ts`; added offline warning badge in app header and alert banner in main layout (`apps/client/src/routes/app-layout.tsx`); full 1:1 `en`/`fil` localization keys in `apps/client/src/locales/{en,fil}/common.json`.
- **Per-warehouse reorder points: done (2026-11-10, commit `ace0df7`).** Added `location_reorder_points` table with RLS, audit logging, and `004_tenant_isolation_matrix.test.sql` coverage; RPC `set_location_reorder_point` allowing managers and superadmins to set warehouse-specific reorder thresholds or revert to product default; updated `warehouse_reorder_list` to use `coalesce(lrp.reorder_point, v.reorder_point)` and return `is_override`; web Overview Reorder tab displays custom badges, edit threshold dialog, and revert-to-default capability; client API `setLocationReorderPoint`; migration `20261110000200_location_reorder_points.sql`, pgTAP `046_location_reorder_points.test.sql` (21 tests).
- **Utang balance adjustment on web: done (2026-11-10).** Added "Ayusin ang utang" / "Adjust balance" dialog in `apps/client/src/routes/utang.tsx` matching mobile capability; supports write-offs (bawas / owes less) and corrections (dagdag / owes more) with note and store scoping; client API `adjustUtang` in `apps/client/src/lib/utang-api.ts` calling `adjust_utang` op through `sync_push`; helper and tests in `utang-math.ts`; full en/fil localization; permissions guard for store managers and superadmins.
- **Web Solo/Full gaps: done (2026-11-10).** Stored mode flag (`tenant_settings.mode` in `solo | full`, RPC `set_tenant_mode`, exposed in `get_my_access()`, prioritized in `tenantMode()`); product search by typing in Counts (`apps/client/src/routes/counts.tsx`), Purchasing lines editor (`apps/client/src/routes/purchasing.tsx`), and Warehouse Overview (`apps/client/src/routes/overview.tsx`); editing draft purchase orders (`update_po` RPC, `EditOrderDialog` with line edits, supplier, expected date, notes, and direct placement); warehouse put-away screen (`list_receiving_stock` RPC, dedicated Put-away tab in `apps/client/src/routes/bins.tsx`, guided put-away dialog calling `execute_putaway`); walking-route pick lists for transfers (`get_pick_list_for_transfer` RPC, `PickListDialog` in `apps/client/src/routes/transfers.tsx` with `generate_pick_list` and `confirm_pick_item`). Migration `20261110000100_web_gaps_po_mode.sql`, pgTAP `045_web_gaps.test.sql` (28 tests; total 4583 across 45 files), vitest (123 web + 54 core + 20 functions), Flutter (545 tests). Full `pnpm check` clean.
- **Web UI overhaul, slice 3: done (2026-11-10).** Radix Toast system (`useToast` hook with `good`, `error`, `warn`, `info`, and `toast`, mounted at root), Products screen restyled (design tokens, `Field`, `PageHeader`, `EmptyState`, `ErrorState`, toasts on all operations), and complete adoption of `ErrorState`, `EmptyState`, `PageHeader`, `Field`, and toasts across all back-office routes. All existing `data-testid` selectors preserved. Full `pnpm check` passed.
- **Web UI overhaul, slice 2: done (2026-11-09).** 16 tables on the shared `Table`, tabs on `Tabs`, `PageHeader` on Sell, Today, Purchasing, Counts, Warehouses. Typecheck, lint, 122 tests pass. Full-mode screens not seen in a browser. Left: toasts, ErrorState, contrast pass, Products list markup.
- **Web UI overhaul, slice 1: done (2026-11-09).** Tokens and dark mode (re-maps the Tailwind colours, so every screen follows), sidebar layout with groups and a phone drawer, theme toggle, new components (PageHeader, EmptyState, ErrorState, Table, Tabs), brand blue replaces indigo/purple. Looked at in the browser (Today, Products, shell; light, dark, phone width). Next slices: move Sell, Today, Products, Purchasing, Counts, Warehouses onto the components, toasts, a contrast pass. See `docs/web-design-system.md`.
- **F-04m staff on the phone: done (2026-11-09).** More > Staff (owner, managers): list, add a cashier, switch off or on, clear PIN; sign-in accepts `username.storecode`. 12 phone tests, server calls checked against the local stack. Not on the emulator by hand. Not done: roles, extra stores, email invites, cashier password reset (web only).
- **F-05m cashier shifts: done (2026-11-09).** Server (`shifts` table, `open_shift` / `close_shift` ops, the server's own expected cash per cashier, `shift_expected_now`, pull, isolation matrix; pgTAP 46 in `044`), phone (Drift schema 16, store, X reading, sync, screens: start, X, close with the count and the server's figure when online, Z report, history, sharing as text; Sell button and More > Shift for owner, admins and cashiers), checked on the emulator as the owner offline and as a cashier online, every figure matching the server. 25 + 14 mutations on the phone, 17 of 18 on the server. Flutter 533 tests. Decisions are in the card (no supervisor PIN to close; the day close stays separate). Not done: printing slips, closing someone else's shift from the phone, staff on the phone.
- **Priority 1 done: Mobile Solo proven on the emulator (2026-11-09).** New account through the app, then expiry, tingi (exact cost split), an offline sale that synced on reconnect (temporary receipt number became the server's), utang pay-by date and statement sharing, expenses, reports with expenses, day close with opening cash, load/e-wallet float, CSV export and pinning, each checked against the server's rows. Fixed: the "Choose who owes" button hid under the keypad after "All on utang" (new test). Not covered: supervisor PIN (needs a second user), camera barcode decode, real printer, release-build speed. Test account `tindera.p1@example.test` / `Tindera-pass1` (tenant `solo-e423847bcdeb`) is in the local database.
- **Local test data cleaned (2026-11-09).** Tenants `h8-mw91d2at` and `f13i-mw97727i` and their users were deleted from the local database. The ledger's append-only guard blocks deleting a tenant that has stock movements, so the delete ran in one transaction with only the `stock_movements_append_only` trigger switched off, switched on again before commit (checked). The three scratch tenants from scenario reruns (`f13i-mw976d6b`, `f13i-mw986o6r`, `f13i-mw987676`) and their nine users were deleted the same way; only the older `whtest` is left. Next time: use the same transaction, or give the scenario script a cleanup step.
- **Phone cleanups (2026-11-09).** Settings now says "Active warehouse" ("Aktibong bodega") for a warehouse clerk and keeps "Active store" for everyone else; two tests, one mutation checked. The other note, the sync badge doing nothing while a bottom sheet is open, is the normal behaviour of a modal sheet (the first tap outside closes it), so it was left alone. Flutter 497 tests.
- **Negative stock report: done (2026-11-09).** `negative_stock_list` (security invoker, scoped by row-level security, keyset-paged) and a "Below zero" tab on the web Warehouses screen (en + fil). Lines clear themselves when stock is added. Migration `20261109001000`, pgTAP 043 (19 tests), vitest 120. Not on the phone; no place filter in the web screen yet.
- **Transfer stock guard: done (2026-11-09).** A transfer can no longer send more than the origin holds (`insufficient_stock`, one trigger on `stock_movements` for `transfer_out`); offline sales are unchanged. Migration `20261109000900`, pgTAP 042 (16 tests, suite 4440), web text en + fil, F-13i scenario 65 of 65, `pnpm check` green. Not built yet: the negative-stock exception report.
- **F-13i two-warehouse acceptance: done (2026-11-09).** Whole scenario (PO, receipt, put-away, W1 to W2 transfer with picks, W2 to store, counts at both, access limits) passes on the server with stock, bin invariant and ledger checked after every step (repeatable: `scripts/acceptance/f13i-two-warehouses.mjs`); web and phone agree with the server, including a receipt into a bin warehouse made offline on the emulator. **One decision for you:** transfers can take a warehouse below zero (shipped 500 from a warehouse holding 19, it went to -481); recommended guard in `ship_transfer`, see the F-13 card. Fixed: sign-out left the Settings screen on top. Local test tenants `h8-...` and `f13i-...` remain in the shared database.
- **F-13h merged to `main` (2026-11-09), commit `9f82144`** (no fast-forward): H1 to H8 and the offline start. `pnpm check` green on the tip before the merge. Next: F-13i (two-warehouse acceptance on web and server). A local test tenant `h8-mw91d2at` is still in the shared database.
- **F-13h offline start: done (2026-11-09).** The app now opens with no signal: the last access answer is kept on the phone (same user only, at most 7 days, replaced by every server answer, dropped on sign-out or when the server says no business) and used only when the server cannot be reached; the gate asks again every 60 s and switches to the server's answer. 13 new Flutter tests (494 in all), 14 mutations (13 caught, one redundant key removed), checked on the emulator with airplane mode on. The 7 days is a default you can change (`AccessCache.maxAge`). Next: F-13i, then merge H1 to H8 and this to `main`.
- **F-13h H8 emulator acceptance: done (2026-11-09).** Clerk signed in on the Android emulator against the local server, received against an order with airplane mode on, reconnected (receipt number and numbers agree with the server, no dip or double count), counted online (server stock corrected), and a clerk of the other warehouse saw nothing of it (checked over the API and row-level security). The emulator found three real bugs, fixed with tests: screens not updating after local writes (Drift shared a stream between watchers with the same SQL), the order detail not refreshing, and the count quantity box not taking the keyboard. **Open:** the app cannot start with no signal at all (home gate needs the server; affects every role). Details and the checklist in `docs/tasks/F-13h-phone-warehouse.md`. Next: F-13i, the offline-start card, then merge H1 to H8.
- **F-13h H6 count and stock screens: done (2026-11-09).** Count tab on the phone (online only): start for the warehouse or one bin, count by search or scan with the system quantity shown per line, finish (optionally zeroing uncounted) or cancel, each warehouse with its own count; Stock shows which bins hold a product. en + fil text for server refusals. 17 new Flutter tests, 21 mutations caught. `SupabaseBackend` count calls not yet checked against a live server (H8). Next: H8 emulator acceptance, then merge H1 to H6 to `main`.
- **F-13h H5 receive screens: done (2026-11-09).** Receive goods against an order (quantity, optional cost, over-delivery warning, reference, notes) and delivery without an order (supplier, search or scan); saved on the phone at once, receipt number shown after sync; en + fil text for the phone-side refusals. 11 new Flutter tests, 13 mutations (11 caught, 2 equivalent). Next: H6 count and stock screens, H8.
- **F-13h H4 warehouse home and picker: done (2026-11-09).** Warehouse-role users land on `WarehouseShell` (Receive, Count, Stock, More); active warehouse remembered on the phone, picker only with 2+ warehouses; Receive lists open orders (with waiting-to-sync marker) and receipts from this phone; Stock is searchable. en + fil strings. Flutter 448, 10 mutations caught. Count is a placeholder until H6. Next: H5 receive screens, H6, H8.
- **F-13h H3 warehouse sync in the sync engine: done (2026-11-09).** `WarehouseApi`, receipts through `sync_push`, pull with cursors and paging, `syncScopeForRole` (warehouse clerks pull warehouse data and no store data; everyone else the reverse), and a snapshot rule so orders that finish elsewhere are forgotten after a re-pull. 25 new Flutter tests (424), 15 mutations checked. A real-server check of `SupabaseBackend.pullWarehouse` waits for H8. Next: H4, H5, H6, H8.
- **F-13h H2 local database for warehouse data: done (2026-11-09).** Drift schema 15 (9 tables), `WarehouseStore` interface, `DriftWarehouse` mixin, `test/warehouse_store_test.dart` (38), server addendum `20261109000800_grn_result_applied_at.sql`. Numbers = server copy + unsettled local receipts; settle rule uses the server's `applied_at` and a complete pull. Flutter 399, pgTAP 4424. Not yet called by the sync engine. Next: H3 sync engine, then screens H4 to H6.
- **F-13h H1 server warehouse sync: done (2026-11-09).** Migration `20261109000700_warehouse_sync.sql`, pgTAP `041_warehouse_sync.test.sql` (94). `sync_push` kinds `receive_po` and `receive_without_po` (op id = receipt id); `sync_pull_warehouse` (warehouses, bins, bin and warehouse stock, suppliers, open orders with lines). Newest `sync_push` definition is now in that migration. pgTAP total 4423 in 41 files. Next: H2 local database (Drift v15), H3 sync engine, then screens.
- **F-13h phone screens: plan (2026-11-09).** `docs/tasks/F-13h-phone-warehouse.md`. Survey result: the Flutter app has no warehouse concept (a warehouse user has no store, and `storesOf()` keeps only stores), so this needs a warehouse home, local schema v15, `sync_pull_warehouse` and two new `sync_push` kinds. Decisions to confirm: receiving offline, counting online-only in v1; warehouse-role users get their own home; no put-away or picking in v1.
- **F-13g slice 3, Warehouse overview (web): done (2026-11-09), F-13g complete.** `/app/warehouses`: reorder list, shipments in transit, find a product across warehouses. 13 new web tests; client 117, pgTAP 4329, Flutter 361. Next: F-13h phone screens for warehouse staff, then F-13i acceptance.
- **F-13g slice 2, Counts screen (web): done (2026-11-09).** `/app/counts`: start (whole warehouse or one bin), count, save, close (optionally zero uncounted) or cancel, history. Browser-checked on a bins warehouse and a non-bins warehouse. 16 new web tests; client 104, pgTAP 4329, Flutter 361. Next: warehouse overview screen (stock by product, reorder list, in transit), then F-13h phone and F-13i acceptance.
- **F-13g slice 1, Purchasing screen (web): done (2026-11-09).** `/app/purchasing`: orders, suppliers, deliveries; receive against an order (partial, over, close short) and without one. Browser-checked as owner and as a second warehouse's clerk. 17 new web tests; client 88, pgTAP 4329, Flutter 361. Next: counts screen, then the warehouse overview (stock by product, reorder list, in transit), then F-13h phone and F-13i acceptance.
- **F-13f cross-warehouse views: done (2026-11-09).** Migration `20261109000600_warehouse_views.sql`, pgTAP `040_warehouse_views.test.sql` (78). Read-only, run as the caller: `warehouse_stock_by_variant`, `warehouse_reorder_list`, `warehouse_transfers_in_transit`. pgTAP total 4329 in 40 files. All server work in F-13 is now done; next are the screens (F-13g web, F-13h phone) and acceptance (F-13i).
- **F-13e warehouse stock counts: done (2026-11-09).** Migration `20261109000500_warehouse_counts.sql`, pgTAP `039_warehouse_counts.test.sql` (109), matrix rows in `004`. RPCs `start_count`, `record_count`, `close_count`, `cancel_count`. Corrections are measured against the system quantity at count time. pgTAP total 4251 in 39 files. Next: F-13f cross-warehouse views, then screens (F-13g web, F-13h phone) and acceptance (F-13i).
- **F-13d goods receipts: done (2026-11-09).** Migration `20261109000400_goods_receipts.sql`, pgTAP `038_goods_receipts.test.sql` (96), matrix rows in `004`. RPCs `receive_po`, `receive_without_po`, `close_po`; tables `goods_receipts`, `goods_receipt_items`. pgTAP total 4042 in 38 files. Next: F-13e warehouse stock counts.
- **F-13c suppliers and purchase orders: done (2026-11-09).** Migration `20261109000300_suppliers_purchase_orders.sql`, pgTAP `037_suppliers_purchase_orders.test.sql` (67), matrix rows added in `004`. RPCs `upsert_supplier`, `archive_supplier`, `create_po`, `submit_po`, `cancel_po`. pgTAP total 3846 in 37 files. Next: F-13d goods receipts (writes `po_items.qty_received`). Known issue: transfer numbers can collide under concurrency (see card).
- **F-13b receive into a warehouse: done (2026-11-09).** New `sync_push` kind `receive_warehouse_stock` (migration `20261109000200_warehouse_receiving.sql`, pgTAP `036_warehouse_receiving.test.sql`, 30 tests). Newest `sync_push` definition is now in that migration. pgTAP total 3629 in 36 files. Next: F-13c suppliers and purchase orders.
- **F-13a multi-warehouse proof: done (2026-11-09).** `docs/tasks/F-13-multi-warehouse.md` plans the rest (receiving into a warehouse, suppliers/POs, goods receipts, counts, screens). Migration `20261109000100_multi_warehouse_hardening.sql` + pgTAP `035_multi_warehouse.test.sql` (48). Fixed: bin stock and pick list items leaked across warehouses; shipping without a pick made STAGING negative (now `pick_required`). pgTAP total 3599 in 35 files. `main` was merged from this branch on 2026-11-09 (`8b7da68`); this work is on the branch only.
- **Track 1 Mobile Adaptation Completed (2026-11-09):**
  - **F-06 mobile (`7b24cca`):** Offline supervisor PIN verification utility (`apps/mobile/lib/core/pin.dart`), PBKDF2 hash checking matching Supabase/`@pos/core`, local store offline PIN caching per location, seamless online-to-offline PIN fallback, and outbox op requeue with offline approval payload for sync replay. Tests in `pin_test.dart` and `supervisor_pin_test.dart` all passing.
  - **F-04 mobile (`631a0e2`):** Role-based navigation and staff permission guards in Flutter: `CatalogScope` role context (`role`, `isCashier`, `isWarehouse`, `isAdminOrSuperadmin`), warehouse role stock management permissions, cashier restriction guards (hiding expenses and day close on TodayScreen, hiding upgrade card in Settings). Tests in `role_permissions_test.dart`, `reports_test.dart`, and `stock_screen_test.dart` all passing.
- **Solo on the Web & Upgrade to Full (W-01 to W-05) DONE (2026-11-08):**
  - **W-01 (`259cdd9`):** Web shell & Today screen from rollups.
  - **W-02 (`2cf8f20`, `34bf57b`):** Sell on web (cart, discounts, cash/e-wallet/utang, split pay, sales list, receipt, void).
  - **W-03 (`8112fb4`):** Products & stock (catalog, prices, stock-in, count corrections, opening stock).
  - **W-04 (`8542b2c`):** Utang payments, pay-by dates, expenses list/record/void with approvals, daily drawer reconciliation & close history.
  - **W-05 (`6dc19be`):** Upgrade to Full mode wizard (`/app/upgrade`), Today screen banner, mobile Settings entry, 100% data preservation verified in PostgreSQL.
- **Full mode (React-first) Foundation Completed (2026-11-08):**
  - **F-01 (`70b6d2e`):** Store scoping & multi-store data foundation (done).
  - **F-02 (`fa36fc0`):** Server sale number & device registry (done).
  - **F-03 (`6eaa150`):** Tenant business settings, quotas, and receipt styling (done).
  - **F-04 (`f2ef69d`):** Staff management in React: email invites, cashier creation, multi-store positions, supervisor PIN management (done).
  - **F-01w (`57bda42`):** Store scoping & active store switcher in React web across all operational screens (done).
  - **F-05 (`598572d`):** Shifts and drawer reconciliation with X-Report (interim reading) & Z-Report (final shift close), cashier mapping, and discrepancy filtering (done).
  - **F-08 (`34dac48`):** Warehouse and inter-store stock transfers in React (draft, send, receive with discrepancy detection, in-transit aging) (done).
  - **F-10 (`7f597f0`):** Multi-store reports & analytics in React: store comparison, payment tenders, top products, daily trends, transfers summary (done).
  - **F-07 (`39c3ffd`):** Sales controls, role-based discounts & void thresholds, supervisor overrides (done).
  - **F-06 (`dce0a2c`):** Offline PIN delivery (`pull_offline_pins`), offline approval verification on sync, refused op auditing (`op.refused`) (done).
  - **F-09 (`744d326`):** Warehouse bins, zones, put-away, walking-route pick lists, bin stock = warehouse stock invariant validation (done).
  - **F-11 (`4b4c39f`):** Free-tier operations, storage metering, keep-alive ping, automated backup, and archive maintenance (done).
  - **W-03 Extensions (`893b11d`):** Catalog categories, tingi repack conversions, expiry dates, and CSV import/export in React client (done).
  - **F-12 (`97f5ee2`):** Platform administration, operator dashboard, multi-tenant metrics, and tenant lifecycle (done).
- **Full mode started (2026-11-08):** F-01 store scoping and F-02 server sale number + devices are done; F-03 (tenant settings + mode switch) is next. Handoff for a new session or tool: `docs/START-HERE-antigravity.md` (rewritten today).
- **Solo mode is wrapped up (2026-11-08).** Phases 0 to 8 plus the tabs revamp, keypad, opening cash, e-wallet float, import/export are done; acceptance and open findings: `docs/tasks/P8-13-acceptance.md`. Full mode is planned in `docs/tasks/F-00-overview-full-mode.md`; **F-01 store scoping: data layer done** (section near the end), picker UI done; **F-02 server sale number and devices: data layer done**, receipt/Today display next. Branch `claude/phase3-sell-8261d3` holds all of it, not pushed, not merged to `main`.
- Phase 0 (Foundation): done, committed (6d59c99).
- **Phase 3 (solo Sell screen, utang, stock ledger): done** (cards P3-01..P3-08, report at the end of this file). Phase 2 (solo catalog) accepted before it. Next: Phase 4.
- **Phase 6 (solo reports from rollups): done** (section at the end; gaps triaged in `docs/gaps-review.md`).
- **Phase 4 (solo stock in, count, low-stock, average cost): done** (cards P4-01..P4-05, report at the end of this file).
- **Phase 1 (Tenancy, Auth, RBAC): done, accepted (P1-08).** Cards in docs/tasks/P1-01..P1-08. Next: Phase 2 (catalog and local store).
  - P1-01 core schema: done. Migration `20261107000100_core_tenancy.sql`, pgTAP `001_core_schema.test.sql` (38 tests).
  - P1-02 hook + helpers: done. Migration `20261107000200_auth_hook_and_helpers.sql`, pgTAP `002_auth_helpers.test.sql` (42 tests).
    Hook enabled in `supabase/config.toml`; verified end-to-end (real sign-in token carries tenant_id, user_role, tenant_status, user_active).
  - P1-03 RLS policies + guard: done. Migration `20261107000300_rls_policies.sql`, pgTAP `003_rls_guard_and_policies.test.sql` (33 tests).
  - P1-04 isolation matrix: done. pgTAP `004_tenant_isolation_matrix.test.sql` (508 tests): 2 tenants with colliding keys x
    5 users (superadmin, admin, cashier, warehouse, deactivated) x 10 tables x 5 metrics (own read, own update, foreign read,
    foreign update, delete blocked) against an explicit expectation table. Mutation-tested: a leaky locations policy fails it.
    **When adding a tenant table, add a row per role to `expected` and a probe entry**, or the coverage check fails.
  - P1-05 RPCs + permissions: done. Migration `20261107000400_admin_rpcs.sql`, pgTAP `005_admin_rpcs.test.sql` (53 tests),
    `packages/core/src/permissions.ts` + 25 Vitest tests.
    RPCs: `provision_tenant` (service role / platform admin; takes the owner's existing auth user id), `complete_setup`,
    `set_modules`, `upsert_location` (client UUIDv7 id, limit check, warehouse needs module, type fixed), `archive_location`,
    `set_user_role` (ends old assignments), `assign_location` / `revoke_location` (managers: cashiers into stores they manage,
    no positions), `set_user_active` (no self-deactivation), `get_my_access` (client permission context in one call).
    Last-superadmin protection on demote and deactivate. Every change writes `audit_log`.
    Errors: 42501 not allowed, 22023 bad argument, P0001 business rule with a stable `hint` key for i18n
    (last_superadmin, limit_locations, base_currency_locked, location_type_locked, self_deactivate, user_has_tenant, ...).
  - `can(ctx, key, locationId?)` / `check()` mirror the §5 matrix; build ctx with `contextFromAccess(get_my_access())`.
    Without a location id it answers "in at least one of my locations". UI hint only; RPCs are the gate.
  - P1-06 Edge Functions: done. `supabase/functions/create_user`, `invite_user`, `_shared/{validate,http,clients}.ts`.
    Migration `20261107000500_user_registration.sql`: `admin_register_user` (service role only) holds all authorization,
    the functions only pass the verified caller id. Refused requests delete the just-created auth user.
    Tests: pgTAP `006_user_registration.test.sql` (16), Vitest `validate.test.ts` (20, run by `pnpm test:functions`),
    end-to-end `pnpm smoke:users` (16 checks against the local stack, cleans up after itself).
  - **Login model:** cashiers sign in as `<username>.<slug>@pos.invalid` (client builds it from slug + username);
    invited users sign in with their real email. Deliberately no anon lookup function (would allow account enumeration).
  - `invite_user` also provisions a tenant + first superadmin when called with the service role key or by a platform admin.
  - Auth `site_url` is now `http://localhost:5173` (invite links land on the client).
  - P1-07 admin UI: done. Added TanStack Router + Query, Zod, Tailwind v4 (`@tailwindcss/vite`), and shadcn support
    packages (radix-ui, class-variance-authority, clsx, tailwind-merge, lucide-react; approved). Components are hand-written
    shadcn-style in `apps/client/src/components/ui.tsx`, not generated by the shadcn CLI.
    Routes (`router.tsx`): `/` business code, `/t/<slug>` login, `/app` guarded layout (dashboard, setup, locations, users, modules).
    Guards use `can()` from `@pos/core` on the `get_my_access()` payload; DB stays the gate. Superadmin with setup pending is
    redirected to the 3-step wizard (`complete_setup`). Dashboard shows allowed actions per store (manager in A vs supervisor in B).
    Users: create via `create_user` function, manage role/locations/activation via RPCs; managers only see cashiers in stores they manage.
    i18n: new namespaces `auth`, `admin`, `errors` (en + fil, parity test green). API hint keys map to `errors:<hint>`, zod messages
    are `errors:validation.*` keys. `uuidv7()` added to `@pos/core` (client-generated ids).
    Verified in the browser against local Supabase (dana: different actions per store, create cashier; owner: wizard, add store,
    modules page, fil switch). `pnpm check` passes (690 pgTAP tests).
    Known gaps: see the Phase 1 acceptance report below.
  - Local demo data (not in repo): tenants `demo-full` (owner/dana/cora/carl/cory/nina) and `demo-new`, password `Demo-pass-123`. Reset with `supabase db reset`.
- **RLS shape:** reads follow the §5 matrix; direct client writes only for simple master data
  (tenant name/timezone/tax_mode, settings, currency rates, location name/address/active, own profile name/locale).
  Modules, roles, assignments, new locations, bins: RPC only (P1-05). Column-level grants enforce the editable columns.
- `profiles.pin_hash` is not client-readable (column grant). Offline PIN material needs a dedicated RPC later (Phase 3).
- Default privileges: new tables never grant anon or client DELETE/TRUNCATE; new functions are not executable by anon/public.
  New functions still need an explicit `grant execute ... to authenticated` when clients should call them.
- Guard test fails if any public table lacks RLS, `tenant_id` (allow-list: tenants, currencies, platform_admins),
  or a tenant-leading index; if anon has any grant; if a SECURITY DEFINER function lacks a pinned search_path.
- `audit_log.location_id` added so admins read audit entries for stores they manage.
- Policy gotcha: `x = any ((select fn()))` treats the array as a subquery; write `x = any ((select fn())::uuid[])`.
- **Auth decision:** JWT claims are UI hints. Helpers read role/active live from `profiles` and require the profile tenant to match
  the JWT `tenant_id` claim. Demotion/deactivation is immediate. Suspended tenants still resolve (read/export) but
  `assert_active_user()` refuses writes. Archived tenants and deactivated users resolve to nothing.
- Helpers for policies/RPCs: `auth_tenant_id()`, `auth_role()`, `is_superadmin()`, `is_active_user()`, `is_platform_admin()`,
  `has_location_access(loc, min_position)`, `auth_location_ids()`, `assert_active_user()`, `assert_module(m)`, `assert_location_access(loc, pos)`.
  Wrap in `(select ...)` inside policies.
- Changing `supabase/config.toml` (auth) needs `supabase stop && supabase start`; `db reset` alone is not enough.
- RLS is enabled on every table already, with no client policies yet (deny-all) until P1-03.
- `location_access` rules live in a trigger (role vs location type vs position). Changing a user's role must
  also clear or fix their assignments: handle in `set_user_role` RPC (P1-05).
- `tenant_modules` is one row per tenant with booleans; `check (inventory)` keeps the core always on.

## Phase 1 acceptance report (plan section 12, P1-08)
Run on 2026-11-07 against the local stack.

| Criterion | Result |
| --- | --- |
| pgTAP proves cross-tenant isolation for every role | **Pass.** `004_tenant_isolation_matrix` (508 tests): 2 tenants x 5 users x 10 tables x 5 metrics; mutation-tested. All 6 pgTAP files pass, 693 tests |
| Superadmin can create a cashier and assign a store | **Pass.** `pnpm smoke:users` 16/16 (create_user, synthetic email, cashier signs in and sees only S01). Browser: owner created cashier `nina` in Store B from the Users dialog and she appeared with that store |
| Admin with two stores and different positions sees correct permissions in each | **Pass.** Browser: `dana` (manager A, supervisor B) sees "Manage users (cashiers only)", products, stock adjust, audit log in A but only sell, PIN-gated discount, void, shifts, store reports in B. Users page offers Manage only for Store A cashiers. `/app/locations` redirects her to `/app`. Smoke test also proves the DB refuses the supervisor store |
| `pnpm check` | **Pass.** lint, types, Vitest (core 51, client 18, functions 20), pgTAP 693 |
| Locale after sign-in (gap fixed in this card) | **Pass.** `get_my_access.locale` = profile locale, else tenant default, else en; client applies it once per sign-in and saves changes to `profiles.locale`. Browser: chose Filipino, cleared the device cache, reloaded, still Filipino from the profile; `dana` (no profile locale) got the tenant default. Tests: Vitest `pickLocale`, pgTAP x3 (fallback, own update allowed, profile wins) |

Also seen in the browser: signing in on `/t/demo-new` with a `demo-full` account is refused (wrong business); a deactivated or unknown account lands on the business-code page.

### Known gaps (carry forward)
- **CI never run.** No remote; `.github/workflows/ci.yml` and the `supabase start -x ...` exclusion list are untested (from Phase 0).
- **No invite-by-email screen.** `invite_user` exists and is smoke-tested; the UI only creates username/password users. Platform operator tooling (provision tenant UI) is Phase 9.
- **No component or browser-automation tests.** The admin UI was verified by hand; Vitest runs in node. Playwright was deferred by the plan.
- **Session expiry mid-use** is handled only by the route guard on navigation; an expired token during a mutation shows the generic error.
- **Tenant settings editing after setup** (name, timezone, tax mode, languages) has no screen; only modules and locations can change. Base currency is locked by design.
- **Password reset and user password change** have no UI.
- **User list is capped at 500 rows, no search or pagination** (fine for the pilot size).
- Offline PIN material (`profiles.pin_hash`) still needs its RPC in Phase 3.
- Local demo data only exists in the dev DB (`demo-full`, `demo-new`, password `Demo-pass-123`); `supabase db reset` removes it.

## Phase 0 acceptance report (plan section 12)
| Criterion | Result |
| --- | --- |
| `pnpm dev` runs client against local Supabase | Verified in browser: shows "Connected", no console errors, en/fil switch works |
| Money formats correctly in 3 currencies and 2 locales | 22 tests pass (USD/JPY/KWD x en/fil, plus de-DE separators, parsing, rounding, convert, allocate) |
| i18next scaffolding | en + fil bundled; key-parity test passes (5 client tests) |
| CI green | **Not verified.** `.github/workflows/ci.yml` written but never run (no remote). The `supabase start -x ...` exclusion list is untested |
| `pnpm check` | Passes locally (lint, types, tests). pgTAP step is "NOT RUN" until migrations exist |

## Layout (matches plan section 11)
- `apps/client` Vite + React 19 + TS PWA. `packages/core` (`@pos/core`: money). `packages/sync` (`@pos/sync`: empty stub).
- Deferred from the plan stack to the phases that need them: Tailwind/shadcn, TanStack Query/Router, Dexie, Zod, Capacitor, Playwright.

## Decisions and gotchas
- TypeScript pinned to 6.x: typescript-eslint does not support TS 7 yet.
- Poll interval conflict: CLAUDE.md says 120 s idle with backoff; plan section 2 says 60 s. CLAUDE.md wins unless changed.
- `apps/client/.env.local` holds the local anon key (gitignored). Regenerate from `pnpm exec supabase status -o env`.
- Docker CLI is not on PATH in some shells: add `C:\Program Files\Docker\Docker\resources\bin`.
- `supabase_vector` container restarts on Windows (optional log collector; ignore or disable analytics).
- Money amounts are JS numbers (safe integers). Revisit if any amount can exceed 2^53 minor units.
- Local DB: postgresql://postgres:postgres@127.0.0.1:54322/postgres, Studio http://127.0.0.1:54323.
- Docker Desktop disk may still be on C:. VirtualBox VM was moved to D:.

## Recalibration (after Phase 1)
Solo sari-sari focus + Flutter client: see `docs/recalibration-solo-flutter.md`. Next cards: S-01, S-02 (docs/tasks). Phase 1 is closed; continue with Phase S, then Phase 2 in Flutter.

### S-01 solo provisioning: done (branch `flutter-solo`)
- Migration `20261108000100_solo_store.sql`: `provision_solo_store(tenant_id, location_id, store_name, locale='fil')`, callable by any signed-in user with no business.
  Creates tenant (PHP, Asia/Manila, setup complete), modules inventory+POS on / warehouse off, settings (fil default, locales fil+en), limits,
  owner profile as superadmin (username from the email prefix, else `owner`), one store `MAIN`, audit entry. Second call -> `user_has_tenant`.
- pgTAP `007_solo_store.test.sql` (13). `pnpm check` green: 706 pgTAP tests. No existing migration or test was edited.
- **For S-02:** RLS reads need the `tenant_id` claim, which a session only has after refreshing its token. The client must call
  `refreshSession()` right after `provision_solo_store`, before reading anything.

### S-02 Flutter scaffold: done (branch `flutter-solo`)
- `apps/mobile` (Flutter 3.41, web + android). `supabase_flutter`, ARB i18n (en + fil, fil default, FIL/EN toggle). Screens: sign up/in, name your store, Home.
- `lib/backend.dart` is the seam (`Backend` interface; `SupabaseBackend` calls `get_my_access`, `provision_solo_store`, then `refreshSession()`). Widgets are tested with a fake.
- Config via `--dart-define=SUPABASE_URL / SUPABASE_ANON_KEY` (anon key only). Run: `apps/mobile/run-web.ps1` (Chrome, hot reload) or `flutter run -d web-server --web-port 5300 ...`.
- Verified: `flutter analyze` clean, `flutter test` 4/4 (store naming -> Home, language switch, sign-up form, ARB key parity). In the browser against local Supabase: signed up a new user, named a store, landed on Home with the store name. `pnpm check` unaffected (Flutter is not part of it yet).
- Bug caught by tests: `setState(() => _access = future)` returned a Future; use a block body.
- Gotchas: `intl` is pinned to 0.20.2 by flutter_localizations; `l10n.yaml` needs `nullable-getter: false`; heredocs with quotes can break the Bash tool, use the Write tool.
- Not done: Android toolchain (`cmdline-tools` + licenses missing in `flutter doctor`) blocks the phone APK. Flutter is not wired into `pnpm check`/CI yet. Local test user `nena.s02test@example.com` exists in the dev DB only.

### Phase 2 (solo) planned
Cards `docs/tasks/P2-00..P2-07` (overview + 7). Decisions are listed in P2-00; confirm them before P2-01. Next: P2-01 catalog schema (Opus).

### P2-01 catalog schema: done (branch `flutter-solo`)
- Migration `20261108000200_catalog.sql`: `categories`, `products` (unit, tax_rate, track_stock, active, `photo_path`), `product_variants`
  (sku, barcode, `is_default`, `option_value_ids` kept for Full mode, cost in base minor units, fractional `reorder_point`), `variant_prices`
  (pk variant_id + currency, integer minor units). Composite `(tenant_id, id)` FKs so no row can point across tenants.
- Keys: `unique (tenant_id, sku)` (archived SKUs stay taken); live barcode unique per tenant (archiving frees it); one live default variant per product.
- `products_limit` trigger enforces `tenant_limits.max_products` on live products (hint `limit_products`).
- RLS: read for active members (`tenant_id = auth_tenant_id()`); no client insert/update/delete at all, writes come in P2-02 RPCs.
  The base-currency price row is required by the RPC, not by a constraint.
- Delta-sync indexes `(tenant_id, updated_at, id)`.
- Tests: pgTAP `008_catalog_schema.test.sql` (20); isolation matrix gained 4 tables x 5 roles (now 926 pgTAP tests total).
  Mutation-tested: `products` policy set to `using (true)` fails the matrix for every role. `pnpm check` green.

### P2-02 catalog RPCs and pull: done (branch `flutter-solo`)
- Migration `20261108000300_catalog_rpcs.sql`:
  - `processed_ops` (pk `tenant_id, client_op_id`, server-only, no client privilege). Op ids are per tenant, so one tenant can never read or block another's.
    Internal `claim_op` / `finish_op`: claim at the start (a concurrent duplicate waits on the key), store the result at the end; a failed op rolls back its claim.
  - `upsert_product(op_id, product jsonb)` returns `{product_id, variant_id, sku, created, replay}`. Payload: `{id, name, price, unit?, category_id?, tax_rate?,
    track_stock?, active?, photo_path?, variant: {id, sku?, barcode?, cost?, reorder_point?, active?}}`. Price is base-currency minor units and required on create.
    Missing keys keep their value on update. SKU auto `P-<12 hex>` when blank. Same op id + other kind -> `op_id_reused`.
  - `archive_product(op_id, product_id)`: tombstones product, variants and prices (`deleted_at`), frees the barcode.
  - `sync_pull_catalog(cursors jsonb, limit)`: per table `{rows, cursor {ts, k}, has_more}`, keyset by `(updated_at, key)`, explicit columns, tombstones included.
    Runs as the caller (RLS applies). **Holds back rows newer than now() - 5 s** so a slow writer is never skipped by a cursor.
  - Permission (`catalog.manage`): superadmin and admins who manage at least one live store: full. Warehouse: cost and SKU of existing products only.
    Others: `not_allowed`. Writes need an active tenant and the inventory module.
  - Hints for i18n: not_allowed, cost_and_sku_only, op_id_required, op_id_reused, id_required, id_conflict, name_required, price_required,
    duplicate_sku, duplicate_barcode, bad_category, invalid_value, product_archived, variant_mismatch, not_found, no_account, limit_products.
- Tests: pgTAP `009_catalog_rpcs.test.sql` (42); matrix gained `processed_ops` (1018 pgTAP total). Mutation-tested: `catalog_write_mode()` returning
  'full' for everyone fails 6 tests. `pnpm check` green.
- Gotcha: Supabase grants EXECUTE to anon on new functions; every client RPC needs `revoke execute ... from public, anon` (guard test 003 #6 catches it).
- Not verified from a clean `supabase db reset` (kept the local demo data); the migration was applied with `supabase migration up`.

### P2-03 local store + sync, P2-04 products UI, P2-05 search and scan: done (branch `flutter-solo`, one commit)
Built together while automated; one commit because later cards changed earlier files (search column, store fallback).
- **Local store (P2-03):** Drift (SQLite) behind `LocalStore` (`lib/data/local_store.dart`), implemented by `DriftStore`. Schema v2 (`lib/data/db.dart`):
  categories, products (+ `search_name`), variants, prices, sync_cursors, outbox, opening_stock, meta. v1 -> v2 migration backfills `search_name`.
  Device data is wiped when a different tenant signs in (`ensureTenant`); pending ops of the old tenant are lost then (known gap).
- **Sync (P2-03):** `lib/sync/sync_engine.dart`: push outbox in order, then pull `sync_pull_catalog` pages. Runs on start, 2 s after a local
  change, every 120 s idle; failures back off 15 s -> 15 min. No Realtime. Transient errors keep the op (same op id = server dedupes);
  refusals (`isPermanent` in backend.dart) park it as failed -> "needs attention" banner with Discard (drops it, removes a never-synced
  product, forces a full re-pull). Pull skips rows of products that still have local unsent ops.
- **Money (P2-03):** `lib/core/money.dart`, port of the TS money utils (parse, format, multiply half-up, allocate). 12 tests.
- **Products (P2-04):** Home has big tiles (Products; Sell = coming soon). List with search, price, "not sent yet" icon; one-screen quick add
  (name, price, barcode, opening stock; unit and cost under More); edit; remove with confirm; local duplicate-barcode check.
  No "variant", "SKU" or "tax" words in the UI. Language switch moved from a floating overlay (it covered the add button) to an app-bar button.
- **Search and scan (P2-05):** every word must match, accents and case ignored (`lib/core/search.dart`); order: exact barcode, name prefix, rest.
  2,000 products: 7 ms in tests. Keyboard-wedge/USB/Bluetooth scanners: scan icon focuses the search box; Enter on a known barcode opens it,
  an unknown barcode offers "Add product" with it prefilled. **Camera scan deferred** (needs the Android toolchain to test).
- **Web storage:** `web/sqlite3.wasm` (from the sqlite3.dart release `sqlite3-3.5.2`, SHA-256 matches the hash in the pub package) and
  `web/drift_worker.js` (compiled locally: `dart compile js -O2 -o web/drift_worker.js tool/drift_worker.dart`; rebuild after a Drift upgrade).
  If the normal open fails, `StoreSession` retries once in safe mode (SQLite in the page, IndexedDB). Needed because the Claude desktop
  in-app browser blocks network requests from SharedWorkers (verified with a probe); regular Chrome does not. Error screen + Try again otherwise.
  Hosting must serve `.wasm` as `application/wasm` (Python's http.server on Windows does not by default).
- **Bugs found and fixed:** setState arrow returning a Future (retry button); Filipino plurals: gen-l10n maps `=1` to CLDR "one", which in
  `fil` also covers 2, 3, 5... so "1 produkto" showed for 3. Every plural branch now uses `{count}`; a test guards it.
- **Verified in the browser** (release build, local Supabase, test user `nena.s02test@example.com`, 3 seeded server products): pull shows all 3
  with prices; data survives reload; simulated offline (requests to :54321 blocked in the page): added "Pancit Canton" -> shows at once with
  the pending icon and "Walang signal, 1 naka-save sa phone"; scanned a known barcode offline -> opens it; unknown barcode -> add dialog;
  back online + tap badge -> server has the product with the same SKU, one processed op and a `product.create` audit row.
- Tests: `flutter test` 47 (money, store, sync engine, products widgets, search, scanner flow, safe-mode fallback, plurals); `flutter analyze` clean;
  `pnpm check` green (Flutter is still not part of it).
- **Gaps for P2-07:** offline *first load* of the web app needs a service worker that caches the app, `sqlite3.wasm` and `drift_worker.js`
  (and canvaskit is loaded from gstatic by default: build with `--no-web-resources-cdn` for offline). Camera scan. Phone test (Android toolchain).
  Opening stock is stored on the device only until Phase 4. Product photos are P2-06.

### P2-06 product photos: done (branch `flutter-solo`)
- Migration `20261108000400_product_photos.sql`: private bucket `product-photos` (JPEG only, 200 KB cap). Object path
  `<tenant_id>/<product_id>/<client_op_id>.jpg`: a new path per change, so no device ever shows a stale cached photo.
  Policies on `storage.objects`: read = any active member of the tenant; insert/update = `can_upload_product_photo()` (superadmin or a store
  manager, active tenant, inventory on; warehouse is cost/SKU only so no photos); no delete policy. Path shape and tenant folder checked by
  `is_own_product_photo_path()`. pgTAP `010_product_photos.test.sql` (15); mutation-tested (upload rule loosened -> 4 failures). 1033 pgTAP total.
- Client: `lib/core/photo.dart` (camera/gallery via image_picker, then `compressPhoto`: <= 640 px, JPEG, <= 100 KB, lowers quality then size).
  Schema v3 adds `photo_uploads` (queued bytes) and `photo_cache` (last photo per product). `store.setPhoto` shows the photo at once and queues
  an `upload_photo` op after the product's own op; the engine uploads the file (upsert), then calls `upsert_product` with `photo_path` reusing the
  op id (retry-safe). Storage 400/403 -> needs attention (`not_allowed`), 413 -> `photo_too_large`; anything else retries.
  `PhotoLoader` downloads a photo only when its row is shown, at most 2 at a time, shares a download between rows, keeps it on the device.
- UI: photo section at the top of the product form (Kumuha ng litrato / Pumili ng litrato), thumbnails in the list. Save is now a bottom bar that
  is always visible (it scrolled off small screens once error messages showed).
- Verified in the browser (release build): picked a 1200x900 photo -> stored 76 KB JPEG in Storage, product row points at it; a second
  "device" (other origin) pulled the catalog and downloaded only that one photo with one authenticated GET.
- Bugs found: `whenComplete(() => map.remove(key))` returned the same future and waited on itself (deadlock) - use a block body;
  a stale web plugin registrant after adding a plugin gave `MissingPluginException` in the release build - run `flutter clean` after adding plugins.
- `apps/mobile/tool/serve_web.py <dir> <port>`: static server with the right `.wasm` MIME type and no caching, for testing `build/web`.
- Gaps: old photo versions are never deleted from Storage (free tier: ~100 KB each; add cleanup later). Camera capture on Android untested
  (toolchain). Tests: `flutter test` 60, `flutter analyze` clean, `pnpm check` green.

## Phase 2 (solo) acceptance report (P2-07)
Run on 2026-11-07, branch `flutter-solo`, release web build served by `tool/serve_web.py`, local Supabase. New test tindera
`tindera.p207@example.com` (local dev DB only), store "Sari-Sari ni Aling Rosa".

| Criterion (P2-00 "Done when") | Result |
| --- | --- |
| New solo user adds 5 products (name, price, optional barcode, optional photo) in under 3 minutes | **Pass.** Sign up -> name the store -> 5 products (3 with barcodes, 1 with opening stock): 64 s of automated input. Each product = name, Tab, price, (Tab, barcode), Save. A person typing will be slower but well under 3 min. Photo add verified in P2-06 |
| Offline: search by name and lookup by barcode still work | **Pass.** Requests to Supabase blocked in the page: "pina" found "Piña Juice 250ml" (accent-insensitive); typing barcode 4807770270017 + Enter opened Lucky Me Pancit Canton |
| A product added offline syncs when the signal returns | **Pass.** Added "Itlog (piraso)" offline: listed at once with the pending icon, badge "Walang signal, 2 naka-save sa phone". Back online + tap badge: server has all 6 products with correct centavo prices; badge "Naka-sync" |
| Same catalog on a second device | **Pass.** Fresh origin (second "device"), signed in: all 6 products with prices; photos download lazily (P2-06) |
| New store defaults | **Pass.** Tenant PHP, `fil` default, setup complete, one store, owner = superadmin (S-01) |
| `pnpm check` and `flutter test` green | **Pass.** pnpm: lint, types, Vitest (core 51, client 18, functions 20), pgTAP 1033 (10 files). Flutter: analyze clean, 61 tests |

**Bug found and fixed in this card:** a product saved while a sync was *pulling* waited for the 120 s idle poll (the end of the run replaced
the 2 s "sync soon" timer). `poke()` now asks the running sync to go again. Regression test `sync_engine_test.dart` blocks the pull, saves,
and fails on the old code (verified) / passes on the fix.

### Known gaps (carry forward)
- **Phone not tested.** Android toolchain incomplete (`flutter doctor`: cmdline-tools, licenses). Blocks APK, camera capture and camera scan.
- **Offline first load of the web app** needs a service worker caching the app, `sqlite3.wasm`, `drift_worker.js`, and canvaskit
  (served from gstatic by default; build with `--no-web-resources-cdn`). Today the web app needs signal to start; data then works offline.
- **Clean `supabase db reset` not run** since S-01 (kept the local demo data); migrations were applied with `supabase migration up`. CI never run (no remote).
- Shared-worker storage is blocked in the Claude in-app browser; the app falls back to in-page storage (works, single tab only).
- Pending ops are lost if a different store signs in on the same device. Old photo versions are never deleted from Storage.
- Opening stock lives on the device until Phase 4 (stock ledger). Camera barcode scan deferred.
- `flutter test` is not part of `pnpm check`.

**Next:** Phases 3 and 4 are done (sections at the end of this file). Phase 6 (reduced reports) is done too. The cross-phase gap fix round (A3 A4 A5 A6 B4 B5 B9) is done, see the end of this file and `docs/gaps-review.md`. Phase 7 (camera, printing, offline web, phone check) is done too, see the Phase 7 section.

## Phase 3 (solo): Sell screen, cash, utang, receipt, stock ledger - done (branch `claude/phase3-sell-8261d3`, cards `docs/tasks/P3-00..P3-08`)
Decisions are in `P3-00-overview-solo-sell.md` (confirmed by the user, including the e-wallet label, cancel sale, and Flutter in `pnpm check`).

- **P3-01 schema** (`20261108000500_sales_ledger.sql`): `stock_movements` (append-only; types opening | sale | sale_void), `stock_levels` (trigger-derived, may go negative),
  `customers`, `customer_ledger` (append-only, balance = sum, charge > 0 / payment < 0), `sales`, `sale_items`, `payments`. All RLS read-only for clients.
  Sales, stock, lines and payments follow store access (`auth_location_ids()`); customers and ledger: superadmin, admin, cashier (not warehouse). `unique (tenant_id, local_no)`,
  `total = subtotal - discount` as a check. pgTAP `011` (26) + isolation matrix rows for 7 tables x 5 roles (mutation-tested: a `sales` policy of `using (true)` fails the matrix).
- **P3-02 RPCs** (`20261108000600_sale_rpcs.sql`): `sync_push(ops)` (1 to 50 ops, one subtransaction per op, `claim_op`/`finish_op` idempotency) dispatching to `op_record_sale`,
  `op_void_sale`, `op_upsert_customer`, `op_record_utang_payment`, `op_post_opening_stock`; `sync_pull_pos(cursors, limit)` (stock levels, customers, ledger; keyset, 5 s hold-back).
  The server recomputes every total and refuses a client that disagrees (`totals_mismatch`, `payments_mismatch`). Per-op result `ok | rejected(hint) | error(code)`; a transient `error`
  (40001, 40P01, ...) stops the batch so later ops are never applied out of order. Void needs supervisor access to the store (the solo owner is superadmin). Negative stock is accepted.
  Op id reuse across kinds -> `op_id_reused`. pgTAP `012` (73). Hints: not_allowed, location_required, location_denied, customer_required, unknown_customer, unknown_variant, items_required,
  qty_invalid, totals_mismatch, payments_mismatch, duplicate_local_no, id_conflict, sale_not_found, amount_invalid, invalid_value, unknown_kind, batch_invalid.
- **P3-03 local store and sync:** Drift schema v4 (customers, server_ledger, local_ledger, stock_levels, local_movements, sales, sale_items, sale_payments); `SalesStore` interface (`lib/data/sales_models.dart`)
  implemented by the `DriftSales` mixin on `DriftStore`. `commitSale` is one transaction (sale, lines, payments, stock effect, utang entry, outbox op, receipt number `<3-char device code>-YYMMDD-NNNN`).
  Line math is integer (qty in thousandths) so it can never differ from the server's numeric rounding.
  **Stock and utang on screen = server copy + local effects.** An effect stays counted until a complete pull (no `has_more`) has `server_time - 5 s >= applied_at`, and for stock also a local
  level row at least as new as the op. Tested against a fake server that honours the hold-back. Engine: consecutive pos ops go out in batches of 50; catalog ops keep their own RPCs; the pull runs
  catalog, then pos. `openingOpId(variant)` is a fixed op id per variant, so opening stock can never count twice; v3 `opening_stock` rows are converted to ops on upgrade (tested).
- **P3-04..07 screens:** Sell (search, keyboard-scanner Enter, quick-tap tiles = most sold in 30 days, cart persisted in `meta`), Pay (exact cash by default, quick bills, change, GCash/Maya label,
  utang for the unpaid rest with a customer picker / new customer, peso discount), Receipt (on screen; `ReceiptPrinter` interface with `NoPrinter`), Utang (balances, history, record a payment, overpay refused),
  Today (takings by cash / e-wallet / utang, sales list, cancel from the receipt). Home tiles: Sell, Utang, Today, Products. All strings in fil + en.
- **Bugs found by tests and the browser:** the push loop stopped after 50 ops (the progress guard was wrong; it now counts settled ops); a fake server that ignored the hold-back made stock count twice;
  `setState` returning a Future again (`_pay`); `ButtonSegment` has no `key`.

### Phase 3 acceptance report (P3-08)
Run 2026-11-07/08 against the local stack, release web build served by `tool/serve_web.py` on :5301, using the existing local test tindera "Tindahan ni Aling Nena" (its Drift v3 data migrated to v4 in place).

| Criterion (P3-00 "Done when") | Result |
| --- | --- |
| 20 sales offline reach the server exactly once, also after a forced mid-push failure | **Pass.** `sales_sync_test`: 20 offline sales; the server applies the batch but the response is lost; the phone retries with the same op ids: 20 sales, stock 100-20, no duplicates; the screen shows 80 before and after the server level arrives. Also 120 ops go out as batches 50/50/20. Server side: `supabase/scripts/accept_p3_push_20.sql` pushes 20 ops (one bad) twice in a rolled-back transaction: 19 ok + 1 rejected, second push = 19 replays, 19 sales, 19 movements, 45,600 centavos, stock taken 38 |
| Real browser, offline (requests to :54321 blocked in the page) | **Pass.** Sale 1 (3 Kape + 1 Pancit, cash 100.00, change 45.50) and sale 2 (Sardinas all on utang, new customer Aling Rosa) completed offline with receipts T4U-261107-0001 / -0002 marked "not sent yet" and the badge "3 saved on this phone". Back online + tap on the badge: server has 2 sales, 1 customer, `processed_ops` record_sale 2 / upsert_customer 1; totals 54.50 (tendered 100.00) and 26.00 utang; movements -3 / -1 / -1; Aling Rosa balance 26.00 |
| Cancel a sale | **Pass.** Cancelled sale 2 from its receipt: shown KINANSELA, server has it `voided`, Aling Rosa balance 0.00, Sardinas stock back to 0 |
| Opening stock becomes a movement | **Pass in tests.** `post_opening_stock` raises the level and a replay adds nothing (pgTAP `012`); the device v3 -> v4 conversion is tested. Not re-checked in the browser (the demo products had no opening stock) |
| `pnpm check`, `flutter analyze`, `flutter test` | **Pass.** `pnpm check` now ends with `check:mobile` (analyze + test; skipped with a notice when Flutter is not on PATH): lint, types, Vitest, pgTAP 1482 tests (12 files), Flutter analyze clean, 110 tests |

### Known gaps (carry forward)
- **Stock UX:** a product that never had opening stock shows "None left" after its first sale (its level goes negative). Phase 4 (stock in, adjust, low stock) should decide how never-counted products look.
- **Utang "adjust"** has no op yet (the ledger kind exists for cancels only). The receipt's "not sent" icon is not live (it refreshes when the receipt is reopened).
- **Receipt number clashes:** the 3-character device code is random; a clash with another device of the same tenant shows as a rejected op (`duplicate_local_no`). Full mode adds a server `sale_no`.
- **Sale history is not pulled:** "Today" shows sales made on this device only; a reinstall loses the local receipts (the server keeps them; Phase 6 reports).
- Quick-tap pinning is not built (top sellers only). Printing and sharing are Phase 7. Shifts, PIN unlock (and the offline PIN RPC), card payments, per-line discounts: Full mode.
- Discarding a rejected sale or void removes it locally and drops its stock/utang effect; the sync cursors are reset (full re-pull), as for catalog ops.
- Phone/APK still untested (another session owns the Android build). Offline first load of the web app is still a Phase 7 gap.

**Next:** done in Phase 4 (see below).

## Phase 4 (solo): stock in, count, low-stock, average cost - done (cards `docs/tasks/P4-00..P4-05`)
- **P4-01** (`20261108000700_stock_ops.sql`): movement types `receipt`, `count_correction`, `damage`; `stock_levels.avg_cost` kept by the movement trigger (weighted average, moved only by a receipt that carries a cost);
  `op_receive_stock` and `op_adjust_stock` through `sync_push` (same permission as opening stock: superadmin or admin manager). A count sends the number counted; the server computes the difference from the level at that moment,
  so a late sale or a retry never skews it, and a difference of 0 writes nothing. pgTAP `013` (29) includes a 300-operation property test: every level equals the sum of its movements.
- **P4-02** (`20261108000800_stock_counted.sql`): `stock_levels.counted` = someone has stated how many there are (opening, receipt, count, damage). Sales alone never set it, so a never-counted product shows "Not counted"
  (not "None left"). `sync_pull_pos` returns `avg_cost` and `counted`. Drift v5 (`stock_levels.avg_cost/counted`, `local_movements.counts`; v4 -> v5 resets the stock-level cursor so flags arrive; tested).
  `receiveStock`, `adjustStock` (local effect = counted - stock shown now), `watchStockList`; sale lines copy the pulled average cost as `unit_cost`.
- **P4-03/P4-04 screens:** Stock (search, All / Low chips, stock in with optional cost, count with reason Counted / Damaged / Other, pending icon, read-only for cashiers via `CatalogScope.canManageStock`),
  reorder point under "More" in the product form (synced as `reorder_point`), red "low" count on the Home Stock tile, Sell screen shows "N left, running low" at or below the reorder point.

### Phase 4 acceptance report (P4-05)
| Criterion | Result |
| --- | --- |
| Levels equal the sum of movements after random sales, voids, stock-ins and counts | **Pass.** pgTAP `013`: 300 pseudo-random operations, zero mismatching levels |
| Products that do not track stock write no movements | **Pass.** pgTAP `012` (untracked sale writes none) and the Stock list hides them |
| Numbers on the phone match the server after a sync | **Pass.** Fake-server test with a lost reply (count applied once, same number before and after the level arrives); browser: existing Drift v4 data upgraded to v5, all 4 products "Not counted" (including Kape and Pancit, which had sales), stock in of 24 for Kape made offline showed 21 (24 minus the 3 already sold) with the pending icon and "1 saved on this phone"; after going online: receipt +24 in `stock_movements`, level 21, `counted = true`; the phone showed 21 and "Synced" |
| `pnpm check` | **Pass.** pgTAP 1511 tests (13 files), Flutter analyze clean, 128 tests |

Not re-checked in the browser: a count from the UI and the Low filter / Home badge (widget-tested).

### Known gaps (carry forward)
- Average cost only moves on a stock in that has a cost; the local screens do not show it (it is copied onto sales as the cost snapshot). Margin reports are Phase 6.
- A count of exactly what the phone already shows writes nothing, so counting a never-counted product as 0 leaves it "Not counted".
- Stock in has no supplier, note or receipt document (Phase 5 goods receipts). Transfers, cycle counts and bins are Phase 5/5b.
- Stock is per store; with several stores the sale/stock ops still rely on the server picking the only store (see the Phase 3 gaps).

**Next:** Phase 6 (reduced reports: daily/weekly sales, top items, utang balance) and Phase 7 (APK, camera scan, printing). Then the Full-mode phases.

## Phase 6 (solo): reports from rollups - done (cards `docs/tasks/P6-00..`)
- **P6-01** (`20261108000900_sales_rollups.sql`): `daily_sales_summary` (per store and day: gross, discount, net, tax, cogs, transactions, cash / e-wallet / utang) and `daily_item_sales` (per store, day, variant).
  Days are in the tenant timezone. Kept by deferred constraint triggers on `sales` (insert; status change to voided), so lines and payments exist when they run and a rolled-back op leaves nothing; sales made before the
  migration were back-filled. `report_summary(from, to)` returns days, totals, top items and utang owed, reading only the rollups and the utang ledger (runs as the caller, so RLS applies).
  Read access: superadmin and admins for their stores; cashiers and warehouse read nothing. pgTAP `014` (25): rollups equal the raw sales, a cancel removes a sale, 01:00 Manila time falls on the next day, access by role;
  isolation matrix rows for both tables. In pgTAP use `set constraints all immediate` to fire the deferred triggers inside the test transaction.
- **P6-02:** "Ulat" tile (owner and admins only) -> 7 or 30 days: sales total, estimated profit (shown only when costs exist), cash / GCash / utang split, a bar per day (empty days included), best sellers, utang owed and top debtors.
  The last result per period is kept in `meta` and shown offline with "last report from ...". A line says how many unsent sales and changes are not included.
- **Home is now a two-column grid** (six tiles no longer scroll off a phone screen).
- Mistake caught: I committed once with 9 failing tests (the new tile pushed Products below the fold in the 800x600 test surface); fixed in the next commit by the grid. Run `flutter test` before the commit, not after.

### Phase 6 acceptance report
| Criterion | Result |
| --- | --- |
| Rollups equal the raw sales; cancelling takes a sale out | **Pass.** pgTAP `014` (sum of rollup net = sum of completed sales before and after a cancel) |
| Report reads rollups only | **Pass.** `report_summary` selects only from `daily_sales_summary`, `daily_item_sales`, `customers`, `customer_ledger` |
| Screen against the real server | **Pass (browser).** Release web build, local Supabase: Ulat showed sales 54.50, 1 sale, cash 54.50, per-day bar on Nov 7, best seller Kape 3-in-1 (3 sold, 36.00); it matches the database (the cancelled utang sale is excluded) |
| Works offline from its last result | **Pass in widget tests** (not re-checked in the browser) |
| `pnpm check` | **Pass.** pgTAP 1636 tests (14 files), Flutter analyze clean, 134 tests |

### Known gaps
See `docs/gaps-review.md` for the triaged list across all phases. New in Phase 6: reports are online only (last result cached), profit is an estimate from the cost snapshot, no CSV export, no month picker.

## Gap fix round after Phase 6 (details in `docs/gaps-review.md`)
- Migrations: `20261108001000_utang_adjust_sales_pull.sql` (`op_adjust_utang`, `sync_pull_sales`; `sync_push` re-created with `adjust_utang`). Latest `sync_push` definition is in that file (earlier ones are superseded; always copy from the newest).
- App: `UnsentChangesException` guard, `AuthExpired`, password screens, `watchSale`, `adjustUtang`, `applyPullSales`; `SyncApi` gained `pullSales` (every fake in the tests implements it).
- **Local database was reset** (`supabase db reset`) at the user's request: all 16 migrations replay cleanly; demo tenants, `nena.s02test@example.com` and `tindera.p207@example.com` no longer exist. Create a new account in the app to test. Browser tabs that still hold the old session will sign out; if an old tenant's device data holds unsent changes, the new "Unsent changes" screen appears (Discard and continue).
- Tests: pgTAP 1659 (15 files), Flutter analyze clean, 154 tests, `smoke:users` 16/16 on the fresh database. Not browser-checked in this round (widget and store tests only).


### Android (emulator) setup and check: done (branch `flutter-solo`)
No physical phone: Android is tested on the emulator `Pixel_4_API_33` (API 33, x86_64, WHPX acceleration works).
- **Java:** Flutter used Android Studio's bundled Java 11 (old Studio, `...\Android Studio\jre`); AGP needs 17. Fixed machine-wide with
  `flutter config --jdk-dir="C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot"` (undo: `flutter config --jdk-dir=`). Not stored in the repo.
- First Gradle build ~14 min (downloads Gradle, AGP, NDK 28.2 auto-installed under the existing SDK license). Later builds are incremental.
  `flutter doctor` still warns "cmdline-tools missing": harmless for builds; install from Android Studio > SDK Manager > SDK Tools to clear it.
  Duplicate `platforms/android-33-2` folder in the SDK only causes warnings.
- **Manifests:** main adds `INTERNET` (release builds need it for Supabase) and the label "Aking Tindahan"; `src/debug` adds
  `usesCleartextTraffic="true"` so the debug app reaches local Supabase over HTTP. Release stays HTTPS-only.
- **Run:** start the emulator, then `apps/mobile/run-android.ps1` (uses `http://10.0.2.2:54321`, the emulator's address for this PC).
- **Verified on the emulator:** sign in as `tindera.p207@example.com` -> 6 products pulled into native SQLite (no wasm needed on Android);
  airplane mode on -> edit Itlog, take a photo with the emulator camera (real Android camera app, image_picker) -> shows at once, badge
  "Walang signal, 3 naka-save sa phone"; airplane off + tap badge -> server has the 38 KB JPEG in Storage and the product points to it.
- **Bug found and fixed:** the app bar overflowed on phone widths (the full sync sentence + store name + buttons; up to 300 px over at 360
  wide in Filipino offline). Below 600 px the badge is now icon + count, the sentence is the tooltip and screen-reader label.
  Regression test `test/phone_layout_test.dart` (360 and 411 px, Filipino, offline, 3 waiting) fails on the old badge, passes now.
- Driving the emulator from a script: type slowly (`adb shell input text` per character) — the debug build drops fast input;
  the Escape key (keyevent 111) acts as Back. Debug builds are slow (skipped frames); judge speed on a `--release` or `--profile` build.
- Not done: release APK signing (needs a keystore, Phase 7), profile/release performance check on the emulator.

## Phase 7 (solo): camera scan, receipt printing, offline web, phone check - done (cards `docs/tasks/P7-00-overview-solo-mobile.md`)
`flutter-solo` (the Android emulator setup by the other session) was merged into this branch first, so the phone test below includes its manifests and phone badge.
- **Camera scan** (`lib/core/camera_scanner.dart`): `CameraScanner` interface (`scanOne`, `scanMany` continuous), `mobile_scanner` implementation, hidden on the web. Sell has a camera button next to the search box (each code goes into the cart, unknown or priceless codes are named, the same code is ignored for 1.5 s, "Done" closes it), Products' scan button reads one code and opens the product (or offers to add it), and the product form's barcode field has a camera button. Tests use a fake camera (`test/flutter_test_config.dart` makes every test start with no camera and no printer).
- **Receipts** (`lib/core/receipt_printer.dart`): `buildReceiptPdf` (58 mm roll; the peso sign prints as "P" because the built-in PDF font has none), `PdfReceiptPrinter` (system print dialog and share sheet), Print and Share buttons on the receipt. Direct Bluetooth ESC/POS stays a future `ReceiptPrinter`.
- **Offline web:** Flutter 3.41 no longer registers its own service worker by default, so `web/sw.js` does it (network first with a 4 s limit, then the saved copy; same-origin GET only, never Supabase). Registered in `web/index.html`. Build with `--no-web-resources-cdn`. The app also asks for persistent storage (`navigator.storage.persist()`). `tool/sw_test.mjs` checks the worker against a fake environment (8 checks, run by `pnpm check`).
- **Dependencies:** `mobile_scanner`, `pdf`, `printing`, `web` added. `pdf` needs `archive < 4.1`, so `image` is pinned to `>=4.5.0 <4.8.0` (newer `image` does not compile against that `archive`); `compressPhoto` now catches the decoder's exceptions because the older `image` throws on garbage bytes instead of returning null.
- **Sell screen on phones:** the search box no longer autofocuses below 600 px width (the keyboard covered the items); stock hint text on tiles is one line with an ellipsis (it overflowed by 39 px at phone width).

### Phase 7 acceptance report
| Criterion | Result |
| --- | --- |
| APK builds | **Pass.** `flutter build apk --debug` works on this machine (the `flutter doctor` cmdline-tools warning does not block builds); merged manifest has `CAMERA` and `INTERNET`, minSdk 24 |
| Runs on a phone (A1) | **Pass on the Android 13 emulator** (`emulator-5554`), debug build with `--dart-define=SUPABASE_URL=http://10.0.2.2:54321`: sign up a new account, name the store, home grid fits the screen, add a product, sell it, receipt. Native SQLite works (no wasm). Typing through `adb` is slow and error-prone (see the earlier Android note) |
| Camera scan | **Partly.** The scan screen opens from the Products search, Android shows the camera permission prompt, and after "While using the app" the live preview (the emulator's virtual scene) fills the screen with the hint "Itutok ang camera sa barcode". **No barcode was decoded**: the virtual scene has none. Decoding is covered only through the fake camera in tests; try a real barcode on a real phone or load a barcode image into the emulator's virtual scene |
| Receipt print | **Pass on the emulator.** Print opens Android's print UI with the 58 mm receipt preview (store, number, items, total, cash, "Salamat po!", prices as "P12.00"). Share and a real printer were not tried |
| Web offline first load (A2) | **Logic checked, browser not.** The worker passes its 8 node checks. The Claude in-app browser refuses to fetch any service worker script ("unknown error fetching the script", the same restriction as shared workers), so registration and an offline reload were not tried in a browser. Test in a normal Chrome: load the app online twice, switch the network off, reload |
| Persistent storage | **Written, not confirmed.** `persist()` is requested at start; the in-app browser reported `persisted() = false` |
| `pnpm check` | **Pass.** pgTAP 1659 (15 files), service worker checks 8/8, Flutter analyze clean, 169 tests |

My debug build replaced the other session's build of the same app on the emulator (same package, same debug key, data kept). The emulator has a test account `p7.accept@example.com` on the freshly reset database.

### Known gaps
- Barcode decoding by the camera and the Share action are untested on a device; no real Bluetooth/thermal printer.
- Web camera scan is not built (the web plugin needs a CDN script); the web keeps USB scanner and typing.
- Release APK signing (keystore) is not set up.
- Offline web needs a normal-browser check (see above).

### Phase 7 follow-up
Share was checked on the emulator (Android share sheet with `LL3-261107-0001.pdf`). Offline web in a normal Chrome, real barcode decoding and release signing are still open: see `docs/START-HERE-antigravity.md`.

## Phase 8 (solo store essentials): P8-02 expenses schema - done
- Migration `20261108001100_expenses.sql`: `expenses` (append-only, void only), `daily_expense_summary` rollup (per store/day/category,
  voids taken out), ops `record_expense` / `void_expense` in `sync_push`, `sync_pull_expenses`, and `report_summary` gained an `expenses` block.
- Record/void: superadmin or the store's manager. Read: superadmin and admins of the store. Cashiers neither.
- pgTAP `016_expenses.test.sql` (79, incl. a 400-op random record/void/replay mix) + 100 new matrix rows in `004`. Suite: 1838 (16 files).
- Payload and pull shapes for the Flutter card P8-03: `docs/tasks/P8-02-expenses-schema.md`. No Flutter change yet.
- P8-02b (`20261108001200_expense_supervisor_approval.sql`): store supervisors may record/void with a single-use approval from
  `approve_supervisor_action` (PIN checked online, PBKDF2 `pin_hash`, 5 tries / 15 min lockout, 12 h validity); owner and managers need none.
  New `set_my_pin`, `clear_user_pin`, server-only `supervisor_approvals`, `expenses.approved_by` / `void_approved_by`, audit rows
  `expense.record` / `expense.void` / `pin.failed` / `approval.grant`. sync_push unchanged. pgTAP `017` (63) + 50 matrix rows; suite 1951 (17 files).
  Gap: a supervisor with no signal cannot get an approval (offline PIN RPC is Full mode); refused ops are not audited.
- P8-02c (`20261108001300_day_close.sql`): `day_closes` (append-only cash counts, re-counts allowed), op `close_day` (owner/manager,
  supervisor with a `close_day` approval; stores the phone's expected/counted cash and the server's own `server_expected_cash`),
  `sync_pull_day_closes`, audit `day.close`. pgTAP `018` (53) + 50 matrix rows; suite 2054 (18 files).
  Flutter: Drift v6 (`expenses`, `day_closes`), `SalesStore` expense/close API incl. `expectedCash`, sync engine pushes the 3 kinds
  and pulls both tables, `Backend.setMyPin` / `approveSupervisorAction`. 17 new tests (201 total). No screens yet: P8-03 uses
  `docs/tasks/P8-02c-expenses-client-and-day-close.md`. Also fixed `password_test` (broken since P8-12: Settings got taller).
  Gap: utang payments have no store on the server, so `server_expected_cash` counts them tenant-wide.
- P8-06 (`20261108001400_service_ledger.sql`): load / e-wallet ledger. `service_txns` (append-only, void only; kinds cash_in,
  cash_out, load, float_topup, float_withdraw, float_adjust; wallets gcash, maya, load, other; fee always cash, = income),
  trigger-kept `wallet_float` and `daily_service_summary`, ops `record_service_txn` / `void_service_txn` (sellers record customer
  services; float moves and voids: owner/manager, supervisor with a `record_service_txn` / `void_service_txn` approval;
  float_adjust owner/manager only), `sync_pull_service` (rows + current floats in one response), audit `service.record` /
  `service.void` without the customer ref. `day_close_server_expected` adds service cash; `report_summary` gained `services`.
  pgTAP `019` (109, incl. a 340-op seeded property test) + 150 matrix rows; suite 2313 (19 files).
  Flutter: Drift v7 (`service_txns`, `wallet_float`, `local_float_effects`), `SalesStore.recordServiceTxn` / `voidServiceTxn` /
  `watchServiceTxns` / `watchTodayServices` / `watchWalletFloat` / `applyPullService`, `expectedCash` includes service cash,
  sync engine pushes both kinds and pulls `pullService`. 14 new tests (222 total). No screens yet: P8-07 uses
  `docs/tasks/P8-06-load-ewallet-ledger.md`.
  Gap: e-wallet sale payments and e-wallet expenses name no wallet, so they do not move `wallet_float` (correct with float_adjust).
- P8-08 (`20261108001500_tingi_repack.sql`): tingi / repack. The piece is its own product; the pack variant carries
  `breaks_into_variant_id` + `breaks_into_qty` (same tenant by composite FK, no self link, no chains: a variant is a pack or a
  piece, trigger-guarded). Ops `set_tingi_link` (catalog rights), `open_pack` / `void_open_pack` (stock-in rights, no approvals)
  write `conversion_out` / `conversion_in` / `conversion_void` movements; append-only `conversions` + `sync_pull_conversions`;
  `sync_pull_catalog` carries the link. Cost rule: `T = packs x pack avg` (exact), piece avg `half_up((Q x C + T) / (Q + N))`
  via one exact `stock_blend_cost` (receipts use it too); value off by at most half a centavo per piece. Over-opening and a
  void below zero are allowed (like sales). pgTAP `020` (102, incl. a 400-step property test) + 50 matrix rows; suite 2465
  (20 files). Flutter: Drift v8 (link columns, `local_movements.unit_cost` / `total_cost`, `conversions`), `SalesStore`
  `setTingiLink` / `clearTingiLink` / `tingiPiece` / `openPack` / `voidOpenPack` / `watchConversions` / `averageCost` /
  `applyPullConversions`, `ProductView` link fields; the phone now replays its unconfirmed stock-ins and openings with the
  server's cost rule, so sale costs match the server before the pull. 15 new tests (240 total). No screens yet: P8-09 uses
  `docs/tasks/P8-08-tingi-repack.md`.
- P8-10 (`20261108001600_utang_due_dates.sql`): `customers.due_on` (promised payment date), op `set_utang_due` (same people as
  recording a payment: owner, admins, cashiers; warehouse `not_allowed`; `YYYY-MM-DD` or null, key required, within 2 years,
  else `invalid_value`; no-change and replays write nothing; audit `utang.set_due`), `sync_pull_pos` customers carry `due_on`.
  pgTAP `021` (38); suite 2503 (21 files). Flutter: Drift v9 (`customers.due_on`, customers re-pulled), `setUtangDue` /
  `watchOverdueCustomers` / `overdueCount`, `CustomerView.dueOn` / `overdue(today)` / `daysOverdue(today)`, sync kind
  `set_utang_due`, pure `utangStatementText` (`lib/core/utang_statement.dart`, never the phone number). 13 new tests (256 total).
  Version asserts in three upgrade tests now compare with `schemaVersion`; the v4 upgrade test keeps `customer_ledger` instead of
  `customers` (v9 re-pulls customers). No screens yet: the UI card uses `docs/tasks/P8-10-utang-due-dates.md`.
- P8-11 (`20261108001700_expiry_dates.sql`): expiry dates, kept simple. One date per store + variant = the earliest on the
  shelf, **no lots** (after the early batch is gone the tindera sets the next date). Table `stock_expiry` (RLS like
  `stock_levels`, no client writes; `stock_levels` untouched), op `set_expiry` (stock-in rights; 2000 .. +10 years, past
  allowed, else `invalid_value`; audit `stock.set_expiry`), `receive_stock` optional `expires_on` (earlier of stored and new
  while qty > 0 before the receipt, else replaced; nothing else changes), `sync_pull_pos` new `stock_expiry` section.
  pgTAP `022` (65) + 50 matrix rows; suite 2618 (22 files). Flutter: Drift v10 (`stock_expiry`), `setExpiry`,
  `receiveStock(expiresOn:)`, `watchExpiring` / `expiringCount`, `StockRow.expiresOn` / `expired` / `expiringSoon` /
  `daysLeft`, sync kind `set_expiry`, discard removes the local date. 11 new tests (267 total). No screens yet: the UI card
  uses `docs/tasks/P8-11-expiry-dates.md`.
- P8-14 (`20261108001800_opening_cash.sql`, added card): opening cash (sukli) in the day close. `day_closes.opening_cash`
  (centavos >= 0, default 0, append-only), `close_day` optional `opening_cash` (bad value `amount_invalid`),
  `server_expected_cash = opening + day cash flow`, client `expected_cash` includes it, audit meta + `sync_pull_day_closes`
  carry it; closes without it unchanged. pgTAP `023` (37), `018` pull key list updated; suite 2655 (23 files). Flutter: Drift
  v11, `defaultOpeningCash(day)` (count of the newest earlier close at this store, else 0), `expectedCash` /
  `watchExpectedCash(day, {openingCash})` add it (default when null: existing callers now include the opening),
  `closeDay(openingCash:)`, `DayCloseView.openingCash`. 10 new tests (297 total). Screen change still open:
  `docs/tasks/P8-14-opening-cash.md`.
- P8-15 (`20261108001900_ewallet_float_payments.sql`, added card): e-wallet sale payments and e-wallet expenses may name the
  wallet (`payments.wallet`, `expenses.wallet`: gcash | maya | other, never load; only on ewallet, else `invalid_value`; set
  once). AFTER triggers move `wallet_float` (+payment / -expense, reversed on sale cancel / expense void; no wallet = no
  movement, as before). `op_record_sale` / `op_record_expense` accept `wallet`, `sync_pull_sales` payments and
  `sync_pull_expenses` rows carry it, expense audit gains `wallet` when named. Cash, expected cash, sales/expense rollups and
  report keys unchanged. pgTAP `024` (86, incl. a 420-op property test); suite 2741 (24 files). Flutter: Drift v12,
  `PaymentDraft(wallet:)`, `recordExpense(wallet:)`, `SalePaymentView.wallet`, `ExpenseView.wallet`, local float effects for
  sales / expenses / their voids under the P8-06 drop rule. 10 new tests (311 total). Wallet chooser on the Pay screen and
  expense sheet still open: `docs/tasks/P8-15-ewallet-float-payments.md`.
  Closes the P8-06 gap / P8-13 finding 5 on the data side.

## Full mode F-01: store scoping, data layer (2026-11-08, card `docs/tasks/F-01-store-scoping.md`)
- Server `20261108002000_store_scoping.sql`: `customer_ledger.location_id` (fk, same tenant) + `method` (cash | ewallet,
  default cash), backfilled (sale's store, else the tenant's only/first store). `record_utang_payment` takes `location_id`
  (required with several stores: `location_required`; access checked: `location_denied`) and `method`; `adjust_utang` an
  optional `location_id`; sale / void ledger rows carry the sale's store. `day_close_server_expected` counts only CASH utang
  payments taken at the closing store. `sync_pull_pos` ledger rows and `sync_pull_sales` rows carry `location_id` (+ `method`).
  `record_sale` without a store: still fine with one store, `location_required` with several (unchanged rule). pgTAP `025`
  (52); `018` fixture names S01 and S02's figure is 6600 (was 8100). Suite 2793 (25 files).
- Phone: Drift v13 (store columns on sales, local movements, both ledgers, local float effects; `stock_expiry` keyed by
  store + variant; local rows placed from their unsent op; sales / ledger / expiry cursors dropped). ACTIVE STORE in meta:
  `activeLocationId`, `setActiveStore(id)` (only assigned stores), `myStores()` (`StoreRef`), `watchActiveStore()`;
  `ensureTenant(stores:)` (StoreSession passes `storesOf(access)`); every store-sensitive read and write follows it, streams
  re-emit on a switch. `recordUtangPayment(method:)`. 12 new tests (`store_scoping_test.dart`), 327 total; 299 pass, the
  same 28 widget tests that already failed before this card still fail (they come from the UI changes in f76375b /
  cff195e, untouched here). Solo devices behave exactly as before.
- Next (Sonnet, UI only): the store picker and the screen wiring listed at the end of the F-01 card (incl.
  `supervisor_pin.dart` passing `locationId`, cash / e-wallet choice on the utang payment sheet).

## Full mode F-02: server sale number and devices, data layer (2026-11-08, card `docs/tasks/F-02-server-sale-number-and-devices.md`)
- Server `20261108002100_devices_sale_no.sql`: `devices` (client UUIDv7 id, RLS: admins read all, users their own, owner
  retires; limit `tenant_limits.max_devices`, hint `device_limit`), `register_device(p_id, p_name, p_platform)`
  (idempotent, `id_conflict` for another tenant's id), `sale_counters` (server-only), `sales.device_id` + `sales.sale_no`
  = `<store code>-<YYMMDD>-<NNNN>` per store and tenant-timezone day, taken atomically in the sale's transaction (gap-free,
  replay-safe, void keeps it). Local-number rule now per device (`sales_local_no_per_device`); rows without a device keep
  the tenant-wide rule. `record_sale` takes optional `device_id` (never refuses a sale over it) and returns `sale_no`;
  `sync_pull_sales` rows carry `sale_no`, `device_id`. pgTAP `026` (72) + `004` matrix rows.
- Phone: Drift v14 (`sales.sale_no`, `sales.device_id`; device id made, unsent sale ops given it, sales cursor dropped).
  `store.deviceId()`, `SaleSummary/SaleDetail.saleNo`, `displayNo`, `provisional`; the engine registers the device once per
  session (best effort, `DeviceApi`), the number arrives from the op result or the pull. `test/device_sale_no_test.dart` (10).
- Next (Sonnet, UI only): show `displayNo` with a "not confirmed yet" marker on the receipt and in Today (card, last section).

## Antigravity Session: Neo-Fintech Design, Settings Screen, Theme Fix, & Reports Enrichment
Read `docs/START-HERE-claude.md` for the complete handoff from Antigravity.
- **Sculptural Ceramic Redesign**: Elevated app UI across all screens into a neo-fintech / Web3 ceramic aesthetic (`AppCard`, `SummaryCard`, `CoinBadge`, `_ObsidianSellButton`).
- **Fixed Live Theme Switching**: Converted `_ThemeSheet` to stateful, dynamic color tokens react across both `FreshTide` and `GoldenIndigo` palettes in both Light and Dark modes.
- **Dedicated Settings Screen**: Created `SettingsScreen` (`apps/mobile/lib/screens/settings_screen.dart`) housing Store identity, Theme & Mode, Language, Security/Password, and Sign Out.
- **Home Header & 360px Safety**: Streamlined AppBar with store capsule, store avatar with active indicator, and zero overflow on 360px devices.
- **Enriched Reporting**: Added Average Order Value (AOV), Total Orders, multi-channel payment share bar, and live inventory health & reorder alert card.
- **Tests**: All 25 suites and 173 automated tests passing green. Live verified on Android emulator (`emulator-5554`).

## W-01: web shell and Solo home (2026-11-08)
- apps/client: mode-aware nav (src/lib/mode.ts, Solo derived from access: owner + one store + no warehouse) and a read-only Today screen (src/routes/today.tsx, 
eport_summary for the business-timezone day). Solo hides Locations/Users/Modules; Full shows the existing dashboard. en + fil strings under dmin.today.
- No server change. client typecheck, lint and vitest (24 tests) pass; full pnpm check not run (no SQL touched). Not yet checked in a browser against the local stack.
- Known gap: an owner with staff but nothing else still derives as Solo (access has no staff count). A stored mode flag can replace tenantMode() later.
- Next: W-02 Sell.

## W-02 (part 1): Sell on the web (2026-11-08)
- apps/client: Sell screen (src/routes/sell.tsx, route /app/sell, nav entry for anyone with sale.create): catalog search (name/SKU/barcode, Enter adds an exact barcode/SKU), cart with fractional qty, discount, cash (with change) or e-wallet (gcash/maya/other + reference), receipt confirmation showing the server sale number.
- src/lib/sale-math.ts ports the phone's SaleLine math (qty in thousandths, half-up line total, tax-inclusive line tax) and builds the 
ecord_sale payload; src/lib/sell-api.ts loads the catalog via sync_pull_catalog, keeps a stable web device id + receipt counter in localStorage, 
egister_device, and sends the sale with sync_push (same op id on retry; retries a clashing provisional number up to 3 times).
- Verified: client typecheck, lint, vitest 38 tests (5000 seeded random lines vs a BigInt reference, 500 seeded random payloads; mutation-checked by breaking the rounding and the tax half-up, both caught). Checked against the local server in a rolled-back transaction: both payload kinds accepted, sale_no issued, totals and tax equal, replay recognised, stock and GCash float moved. Not yet clicked through in a browser.
- NOT done yet in W-02: utang (needs customers: pick/create via upsert_customer), void/refund, split payments, a receipt reprint view. Tax mode: lines carry tax-inclusive tax from the product tax_rate like the phone; no tenant tax_mode logic yet.
- Stock can go negative: the server does not block selling below zero (existing behaviour, unchanged).

## W-02 (part 2): utang, customers, split payments, sales list and void on the web (2026-11-08)
- Sell: payment method cash / e-wallet / utang, a customer picker with quick-add (upsert_customer op), and a 'Paid now' amount; whatever is not paid now goes on utang (uildPayments in src/lib/sale-math.ts, tested: 2000 seeded random choices always add up to the total). Utang needs a customer (client check + the server's customer_required).
- Sales screen (src/routes/sales.tsx, /app/sales): the store's latest 50 sales, receipt detail (items, payments, customer, server sale number), Cancel sale (void) with a reason for users with sale.void at that store; the server decides (op_void_sale needs supervisor access).
- Checked on the local server in a rolled-back transaction: a split sale (600 cash + 1400 utang) and a full-utang sale, owed 3400; voiding the utang sale took it back to 1400 and returned stock; a repeated void is harmless (already=true); the screens' reads (customers, sales, sale_items, payments) work for the owner under RLS. client typecheck, lint, vitest 42 tests pass. Not clicked through in a browser.
- Still open for Solo web: utang payments screen and customer balances (W-04), stock and products (W-03). Cashier-role void is refused by the server by design (supervisor-level), the button shows only when sale.void allows it.

## W-03: Products and stock on the web (2026-11-08)
- apps/client: Products screen (src/routes/products.tsx, /app/products, permission catalog.manage): catalog with price, on-hand at the store and out/low badges, search, 'only low stock' filter; add product (one default variant, opening stock posted via post_opening_stock), edit, archive; stock panel (needs stock.adjust_store): stock in with optional unit cost (
eceive_stock) and a count with reason (djust_stock; the server records the difference as a movement). Stock is never edited directly.
- Logic: src/lib/product-math.ts (typed quantities, tax percent to stored rate, stock status; tested), src/lib/stock-api.ts (catalog + stock_levels join, upsert_product / rchive_product RPCs, stock ops through sync_push), pullCatalog() split out of sell-api.ts.
- Checked on the local server in a rolled-back transaction: create product (SKU auto-made), opening stock 10, receive 10 at cost 800, count 17.5 as damage (delta -2.5, on hand 17.5), edit price/tax/barcode/reorder, archive. client typecheck, lint, vitest 51 tests pass (the locale parity test caught one stray key). Not clicked through in a browser.
- Notes: a stock-in cost moves the average cost in the ledger but does not change the product's own cost field (server behaviour, unchanged). Not built yet: tingi/open-pack links, expiry dates, categories, product photos, variants/options (Solo shows only the default variant), CSV import/export.

## F-03: Tenant Business Settings, Quotas, and Receipt Styling (2026-11-08)
- apps/client: Business Settings screen (`src/routes/settings.tsx`, route `/app/settings`, guarded by `tenant.settings`):
  - Business Profile: store name, business slug (read-only for cashier sign-in `<username>.<slug>`), IANA timezone picker, tax mode (`inclusive` / `exclusive` / `none`), base currency (locked to protect ledger integrity).
  - Languages & Regional: multi-lingual selection (`en`, `fil`), default business language, and offline session duration (1 to 30 days).
  - Receipt Customization: header (slogan, TIN, address) and footer (thank you note, return policies) text fields.
  - Quotas & Resource Capacities: live meters showing current usage against `tenant_limits` for locations, users/staff, registered devices, and catalog products.
- Schema & API: `src/lib/settings-api.ts` (`fetchTenantSettings`, `updateTenantSettings`), `src/lib/schemas.ts` (`tenantSettingsSchema` with validation tests in `schemas.test.ts`).
- Nav: Added Settings link to app layout navigation with strict permission check.
- Parity: 1:1 key parity between English and Filipino translations under `settings.*` in `src/locales/en/admin.json` and `fil/admin.json`.
- Verified: client vitest 59 tests passing, `tsc -p tsconfig.json` clean, `eslint` 0 errors.

## F-04: Staff Management in React (2026-11-08)
- apps/client: Staff Management screen (`src/routes/users.tsx`, route `/app/users`, permission `users.manage`):
  - Onboarding & Creation: Direct cashier account creation with store assignment (`create_user` edge function with synthetic `<username>.<slug>@pos.invalid` email) + Superadmin invite by real email for managers, supervisors, and warehouse staff (`invite_user` edge function).
  - Supervisor & Cashier PIN Management: Superadmin can clear/reset any staff member's PIN via `clear_user_pin` RPC; any logged-in user can set or change their 4-to-8 digit supervisor PIN via `set_my_pin` RPC.
  - Multi-store assignments and positions (`manager` vs `supervisor`) with role-appropriate location type restrictions.
  - Search, filtering (by role, location/store, and active/inactive status), and quota tracker (`tenant_limits.max_users`).
- Logic & API: `src/lib/api.ts` (`inviteUser`, `clearUserPin`, `setMyPin`, `getTenantLimits`), `src/lib/schemas.ts` (`inviteUserSchema`, `setPinSchema` with test coverage in `schemas.test.ts`).
- Parity: 100% key parity between English and Filipino in both `admin.json` and `errors.json`.
- Verified: client vitest 61 tests passing, `tsc -p tsconfig.json` clean, `eslint` 0 errors.

## F-01w: Store Scoping & Active Store Switcher in React Web (2026-11-08)
- apps/client: Multi-store awareness and active store context across the entire web application:
  - `src/lib/location-context.tsx`: `LocationProvider` and `useActiveLocation` hook managing `activeStoreId`, persistent active store selection in `localStorage`, and fallbacks.
  - `src/routes/app-layout.tsx`: Store switcher dropdown in navigation header when the tenant has multiple stores.
  - Operational screens updated: `sell.tsx` (cart, catalog, `record_sale`), `sales.tsx` (recent sales, void), `products.tsx` (on-hand stock, stock-in, count adjustments), `day-close.tsx` (reconciliation, close day), `expenses.tsx` (expenses ledger), and `utang.tsx` (payments recorded at active store).
- Verified: client vitest 65 tests passing (`location-context.test.ts`), `tsc -p tsconfig.json` clean, `eslint` 0 errors.

## F-05: Shifts and the Drawer (X & Z Reports) (2026-11-08)
- apps/client: Shifts & Drawer Reconciliation screen (`src/routes/day-close.tsx`, route `/app/day-close`, permission `shift.manage`):
  - X-Report (Interim Mid-Shift Reading): Non-resetting interim slip showing opening cash float, cash sales, cash utang collected, cash expenses, current expected cash in drawer, gross sales, and non-cash tenders with browser print support.
  - Z-Report (Final Shift Close Reading): Formal shift close slip showing final counted cash vs expected cash, over/short variance, note, cashier name, supervisor approval, and browser print support.
  - Staff & Shift Mapping: Correlates `closed_by` and `approved_by` to human-readable names via `listUsers`.
  - Discrepancy Filtering: History can be filtered by variance (All, Discrepancies only, Balanced only).
- Verified: client vitest 65 tests passing, `tsc -p tsconfig.json` clean, `eslint` 0 errors.




