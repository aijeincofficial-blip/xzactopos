# F-13h: Phone screens for warehouse staff (Flutter)

Part of `F-13-multi-warehouse.md`. The server side (F-13a to F-13f) and the web screens (F-13g) are done. This card puts the daily warehouse jobs on the phone: receive goods, count stock, look things up.

## Survey of `apps/mobile` (2026-11-09, branch `claude/phase3-sell-8261d3`)
- **The app has no warehouse concept.** `storesOf()` (`lib/sync/store_session.dart`) keeps only locations of type `store`. The device store (`ensureTenant(stores: ...)`), every screen and `sync_pull_pos` are built around one active store. A `warehouse` role user has no store, so after sign-in there is nothing for them to work in. The only trace of the role is `CatalogScope.isWarehouse` and a `canManageStock` flag, both store-level.
- `HomeShell` always builds the store tabs (Today, Stock, POS, Utang, More). Nothing role-specific besides hiding a few cards from cashiers.
- Sync: `SyncEngine` pushes the outbox in batches through `sync_push` (kinds listed in `lib/sync/sync_engine.dart`, `posKinds`), then pulls `sync_pull_pos` / `sync_pull_catalog` with cursors. Drift schema is at **version 14** (`lib/data/db.dart`). The catalog (products and variants) is tenant-wide, so a warehouse phone already gets product names and barcodes.
- The server already accepts one warehouse op through `sync_push`: `receive_warehouse_stock` (F-13b, one line per op). Receipts against a purchase order, walk-in receipts and counts are direct RPCs today, not `sync_push` kinds.
- 63 Flutter test files exist; `flutter test` is part of `pnpm check`. Emulator `Pixel_4_API_33` is the only device.

## Decisions taken (change them here before building)
1. **Receiving works offline; counting is online-only in the first version.** Receipts only ever add stock, so replaying them later is safe. A count is measured against the system quantity *at the moment each line is counted* (F-13e). Queued offline, the server would take that snapshot at sync time, after deliveries or sales may have happened, and the correction would be wrong. Doing it properly needs the device to send its own snapshot and the server to validate it. That is a separate, riskier card (H7 below), not part of v1.
2. **Warehouse-role users get their own home** (Receive, Count, Stock, More). Owners and admins keep the store home. An owner who wants to work in a warehouse on a phone uses a "Warehouse" entry in More (H4), after v1.
3. **v1 covers:** receive against a purchase order, receive without one (walk-in), count (whole warehouse or one bin), stock lookup per warehouse and bin, scan with the existing keyboard-wedge and camera scanner. **Not in v1:** put-away and picking (bins), transfers, ordering (creating POs stays on the web).
4. **Several warehouses per user:** a picker like the store picker, and the choice is remembered on the device.

## Cards (one at a time, tests first)
| Card | Work | Model |
| --- | --- | --- |
| H1 Server: warehouse sync | New migration. `sync_push` gains kinds `receive_po` and `receive_without_po` (thin `op_*` wrappers over the F-13d RPCs; the receipt id is the idempotency key). New `sync_pull_warehouse(cursors, limit)`: the caller's warehouses, bins, bin stock levels, warehouse stock levels, suppliers, and open purchase orders with their lines, keyset paged with the same 5 s hold-back as `sync_pull_pos`. pgTAP for access (a clerk gets only their warehouses), paging, replay and refusal hints. Copy the newest `sync_push` (now in `20261109000200_warehouse_receiving.sql`). | Opus |
| H2 Local store | Drift v15: warehouses, bins, warehouse stock, suppliers, open POs and lines, and a local receipt record so a receipt shows at once and the PO quantities move before it syncs. `LocalStore` methods and migration test v14 to v15. | Opus |
| H3 Sync engine | New kinds in the push loop, `sync_pull_warehouse` in the pull loop with its own cursors, refused receipts parked as "needs attention" (reuse the banner and Discard), backoff and 120 s idle poll unchanged, no Realtime. A pull must not overwrite a PO that has unsent local receipts (same rule as products). | Opus |
| H4 Warehouse home and picker | `CatalogScope` learns the active warehouse; warehouse-role users land on a warehouse home; a warehouse picker; offline badge as today. English and Filipino strings, plurals without typed counts. | Sonnet |
| H5 Receive screens | Open orders for the warehouse, receive lines (quantity, optional invoice cost, over-delivery warning), walk-in receipt with scan, queued offline with the receipt number shown after sync. | Sonnet |
| H6 Count and stock screens | Start, count by scanning or typing, save, close or cancel (needs signal); stock lookup by product and bin. | Sonnet |
| H7 (later) Offline counting | Device sends its own snapshot with each line; server accepts it only if it is plausible against the ledger; conflict handling. Decide after v1 is used. | Opus |
| H8 Acceptance | Emulator run: sign in as a clerk of one of two warehouses, receive against an order with airplane mode on, reconnect, confirm the server and the phone agree; count online; confirm a clerk of the other warehouse sees nothing of it. Report in the handoff. | Sonnet |

## Risks to watch
- Getting `ensureTenant` right for a user with no store (today it assumes one).
- Pulls that overwrite local unsent receipts, and `sync_push` ordering between receipts and later counts.
- A cashier or admin phone must not start pulling warehouse data (the server already scopes it; the app should not even ask).
- The phone layout: large touch targets, scan-first entry, one hand.
