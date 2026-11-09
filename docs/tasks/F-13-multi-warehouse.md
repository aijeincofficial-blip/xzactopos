# F-13: Fortify the warehouse side, for several warehouses

Source: owner request 2026-11-09 ("fortify warehouse, it should be multiple warehouse"). Plan: `docs/plan.md` section 8 (warehouse flows), Phase 5 and 5b.
F-08 (transfers) and F-09 (bins) built the movement and bin mechanics. This card closes what is missing for a business with **several warehouses**.

## Audit (2026-11-09, read from the code on `claude/phase3-sell-8261d3`)
What already works for N warehouses (by design): `locations` has no cap of one warehouse; `location_access` scopes a warehouse user to the warehouses they are assigned
(a user can hold several); `create_transfer` accepts any two active locations (warehouse to warehouse included); bins are unique per `(tenant, warehouse, code)`;
`bins_enabled` is per warehouse; RLS on transfers and bins follows location access.

Gaps found:
1. **Nothing is tested with two warehouses.** All warehouse pgTAP files use one warehouse (WH01). Isolation between warehouses is unproven.
2. **There is no way to receive goods into a warehouse.** `op_receive_stock` resolves a *store* (`resolve_store` filters `type = 'store'`) and is gated by `catalog_write_mode() = 'full'`,
   which the `warehouse` role does not have (cost and SKU only). Warehouse stock can only arrive by a store-to-warehouse transfer or a direct insert in tests.
3. **No purchasing side at all:** no `suppliers`, `purchase_orders`, `po_items`, `goods_receipts`, `goods_receipt_items`. Plan Phase 5 "PO to receipt to transfer to store receipt" cannot run.
4. **No stock count / adjustment for a warehouse.** `op_adjust_stock` is store-only for the same reason; `stock_counts` / `stock_count_items` do not exist.
5. **Bins:** the invariant (sum of bins = warehouse stock) is only exercised for one warehouse; `move_bin_stock`, `execute_putaway`, `generate_pick_list` have no test that a user of warehouse A is refused in warehouse B,
   and no test that a transfer between two bin-enabled warehouses keeps both invariants.
6. **No per-warehouse reorder or low-stock view**, and no "stock across warehouses" view for one variant (where is it, how much).
7. **Mobile has no warehouse screens** (receive, count, pick, put-away); web has transfers and bins only.
8. **Limits:** only `tenant_limits.max_locations` (total). No `max_warehouses`; platform admin cannot cap them separately. (Decision needed, see below.)

## Decisions needed from the owner
1. How many warehouses do you expect (2 to 3, or 10 as in the plan's pilot)? Does it need a separate `max_warehouses` limit?
2. Do suppliers/POs belong to the tenant (shared by all warehouses) or to one warehouse? Recommendation: tenant-level suppliers, a PO is addressed to one warehouse.
3. Who orders: only warehouse staff + admins at that warehouse (recommendation), or also store managers?
4. Does a goods receipt need to match a PO, or can a warehouse receive without one ("walk-in delivery")? Recommendation: allow both, receipt without PO is flagged.
5. Warehouse-to-warehouse transfers: any two warehouses, or only via a manager approval? (Today: any two the user can reach on the origin side.)
6. Mobile first or web first for the new screens? (Warehouse staff work with scanners and phones; plan says React-first for Full.)

## Cards (one at a time, tests first)
| Card | Work | Model |
| --- | --- | --- |
| F-13a Multi-warehouse proof (**DONE 2026-11-09**, see below) | pgTAP `035_multi_warehouse.test.sql`: 1 tenant, warehouses W1 (bins on) and W2 (bins off), 2 stores, a warehouse user per warehouse + one with both. Proves: each user sees only their warehouses' stock, movements, transfers, bins; cannot ship/receive/put-away/pick in the other; W1-to-W2 transfer ships, receives, blends cost and keeps W1's bin invariant; same bin code in both warehouses; user with both sees both. **Fix whatever it finds** in a new migration. | Opus |
| F-13b Receive into a warehouse (**DONE 2026-11-09**, see below) | RPC `op_receive_warehouse_stock` (idempotent, outbox-ready): warehouse role + warehouse assignment required, location must be a warehouse, lands in the default RECEIVING bin when `bins_enabled`, blends average cost. Stays inside the ledger (`stock_movements` only). | Opus |
| F-13c Suppliers and purchase orders (**DONE 2026-11-09**, see below) | `suppliers`, `purchase_orders`, `po_items` (tenant-leading, RLS, isolation-matrix rows per role). RPCs: `upsert_supplier`, `create_po` (draft), `submit_po`, `cancel_po`. PO addressed to one warehouse; status draft, ordered, partly_received, received, cancelled. | Opus |
| F-13d Goods receipts (**DONE 2026-11-09**, see below) | `goods_receipts`, `goods_receipt_items`; `receive_po(po_id, items)` supports partial and over/under receipt, writes `receipt` movements via F-13b, updates `qty_received`, flags discrepancies; receipt without a PO allowed and flagged. | Opus |
| F-13e Warehouse stock counts (**DONE 2026-11-09**, see below) | `stock_counts`, `stock_count_items`; `start_count`, `submit_count`, `close_count` writes `count_correction` movements for the differences only; works per bin when bins are on, and keeps the invariant. | Opus |
| F-13f Cross-warehouse views (**DONE 2026-11-09**, see below) | RPCs for stock of one variant across all my warehouses, per-warehouse reorder list, in-transit between warehouses. Reads only; explicit columns, paginated. | Sonnet |
| F-13g React screens (**slices 1 and 2 of 3 DONE 2026-11-09**: Purchasing, Counts; the warehouse overview remains) | Suppliers, POs, receiving, counts, warehouse switcher; Full-only, guarded with `can()` keys (`purchasing.manage`, `stock.count` already exist in `permissions.ts`). | Sonnet |
| F-13h Flutter warehouse role | Receive (scan), count, pick/put-away for warehouse users; outbox ops through `sync_push`; reuse the supervisor-PIN pattern for large adjustments. | Opus (sync) then Sonnet |
| F-13i Acceptance | Two-warehouse scenario end to end: PO to receipt at W1, put-away, W1 to W2 transfer, W2 to store, counts at both; stock correct at every step, bin invariants hold, run partly offline on the phone. Report in handoff. | Sonnet |

Dependencies: F-13a first (it may reveal bugs the rest builds on); F-13b before F-13d; F-13c before F-13d; F-13e after F-13b; screens last.

## Rules that carry over
Never edit an existing migration (new file, newest `sync_push` definition copied when changed); every new table gets RLS plus a row per role in `004_tenant_isolation_matrix.test.sql`;
stock only changes through `stock_movements`; money in integer minor units; business keys unique per tenant; strings through i18n (en + fil);
`pnpm check` green before each card is done; one commit per card; a mutation check on every stock-math rule.

## F-13a result (2026-11-09)
Migration `20261109000100_multi_warehouse_hardening.sql`, pgTAP `035_multi_warehouse.test.sql` (48 tests: 1 tenant, warehouses W1 with bins and W2 with bins, a store,
users: owner, one warehouse user per warehouse, one assigned to both, a store admin, a cashier). `pnpm check` green (pgTAP 3599 in 35 files).

Bugs the test found, all fixed:
1. **`bin_stock_levels` readable across warehouses.** A warehouse or admin user of W1 saw the bin stock rows of W2. The policy checked the role only. Now scoped through the bin's warehouse.
2. **`pick_list_items` readable across warehouses.** Same cause; now scoped through the pick list's warehouse.
3. **Shipping without a pick drove the STAGING bin negative.** The `transfer_out` movement is routed to STAGING. `set_stock_movement_bin()` now refuses with SQLSTATE 55000, hint `pick_required`, when STAGING holds fewer units than the shipment
   (row locked, so two concurrent shipments cannot spend the same picked units). Applies to `ship_transfer` and `create_transfer(..., p_ship_now)`.

Proven to work for two warehouses: stock levels, movements, bins, zones, pick lists and transfers are scoped to the user's own warehouses; a user assigned to both sees both; a store cashier sees no warehouse stock;
the same bin code (`RECEIVING`, `B-01`) lives in both warehouses; bin moves across warehouses are refused; the sending warehouse cannot receive its own shipment and the receiving one cannot ship;
a short receipt (28 of 30) is flagged and leaves exactly the 2 lost units out of the system; bin invariants hold in both warehouses after ship and receive.

Mutation evidence: before the migration the test failed exactly on the three bugs (tests 10, 12, 27, 43 of the first run); after it, all pass.

Behaviour change to know about: on a bins-enabled warehouse a transfer can no longer be shipped (including "ship now" on create) until the items are picked into STAGING. Warehouses without bins are unaffected.
Open question for F-13b onward: should shipping auto-pick from storage bins instead of refusing? (Simpler for small warehouses; more allocation logic.)
Not yet covered by F-13a: stock counts, purchasing, per-warehouse limits, offline/sync, UI. Those are F-13b to F-13i.

## F-13b result (2026-11-09)
Migration `20261109000200_warehouse_receiving.sql`, pgTAP `036_warehouse_receiving.test.sql` (30 tests). `pnpm check` green (pgTAP 3629 in 36 files).

- New op **`receive_warehouse_stock`** (`op_receive_warehouse_stock`), reached only through `sync_push` (idempotent via `claim_op`/`finish_op`, so the phone outbox can queue it).
  `sync_push` is re-created from the 20261108002500 definition with one extra `when`; the newest definition now lives in 20261109000200.
- Payload `{ location_id, variant_id, qty, unit_cost? }`. The warehouse MUST be named and MUST be a warehouse (no default: several warehouses exist). One `receipt` movement; the existing triggers do the rest:
  RECEIVING bin when bins are on, bin invariant, weighted average cost (50 @ 1000 + 30 @ 1200 = 1075; a receipt without a cost leaves the average alone).
- Who: owner anywhere; a warehouse user in their own warehouses (`purchasing.manage` in `permissions.ts`). Store admins and cashiers are refused; so is a warehouse user of another warehouse (`location_denied`). Needs both modules on.
- Hints: not_allowed, location_required, location_not_found, location_denied, not_a_warehouse, qty_invalid, invalid_value, unknown_variant, op_id_reused. Refused ops write nothing and roll back their op claim.
- Mutation checks (rule broken on purpose, test must fail): no location-access check, stores allowed, no replay guard, cost ignored: all caught. "Admin role allowed": not caught, and cannot be: `validate_location_access` only lets admins hold stores,
  so an admin never has warehouse access; the role check is defense in depth behind that rule.
- Not done here (by design): batching several lines, supplier or PO reference, a receipt document (F-13c/F-13d); expiry date on warehouse receipts; any screen; the Dart `sync_push` kinds list on the phone.

## F-13c result (2026-11-09)
Migration `20261109000300_suppliers_purchase_orders.sql`, pgTAP `037_suppliers_purchase_orders.test.sql` (67 tests), isolation matrix `004` gained `suppliers`, `purchase_orders`, `po_items` (2308 tests now).
`pnpm check` green (pgTAP 3846 in 37 files). Decisions taken as recommended: suppliers belong to the tenant, a PO is addressed to one warehouse, only the owner and warehouse staff order.

- Tables: `suppliers` (name unique per tenant ignoring case and spacing, soft delete), `purchase_orders` (`PO-YYMMDD-NNNN`, status draft / ordered / partly_received / received / cancelled, warehouse-only by trigger),
  `po_items` (one line per product, `qty_received` default 0, over-receipt allowed, expected `unit_cost`). RLS: owner and warehouse role only; POs and lines only for the user's own warehouses; no client writes.
- RPCs (all need both modules on and the owner or warehouse role): `upsert_supplier` (client id, full replace), `archive_supplier` (refused while a draft/ordered/partly-received PO uses it), `create_po` (client id; same id + warehouse + supplier = replay),
  `submit_po` (draft to ordered, harmless if repeated), `cancel_po` (draft or ordered with nothing received; harmless if repeated). Each writes `audit_log`. Hints are listed at the top of the migration.
- Not done here: editing a draft PO (cancel and recreate for now), receiving goods against a PO (F-13d writes `qty_received` and the status moves to partly_received / received), screens, the Dart side.
- Mutation checks: 13 rules broken on purpose, 11 caught outright; 2 more tests added for `create_po` (owner to a store) and `cancel_po` (received quantity alone), both now caught. Three survivors are equivalent by design:
  `upsert_supplier` duplicate-name check (the unique index gives the same hint), `po_items_read` warehouse clause (the `exists` over `purchase_orders` is already filtered; kept explicit as defense in depth after the F-13a leak),
  and `cancel_po` dropping only the status half of "has receipts" (the quantity half covers consistent data).
- Concurrency note: PO numbers take a per-tenant advisory lock and have a unique key, but there is no concurrent test.
- **Found, not fixed (out of scope):** `next_transfer_no` (F-08) has no lock and `transfers` has no unique `(tenant_id, transfer_no)`, so two simultaneous transfers can get the same number. Same fix as POs; candidate for a small follow-up card.

## F-13d result (2026-11-09)
Migration `20261109000400_goods_receipts.sql`, pgTAP `038_goods_receipts.test.sql` (96 tests), isolation matrix `004` gained `goods_receipts` and `goods_receipt_items` (2501 tests with 038). `pnpm check` green (pgTAP 4042 in 38 files).

- Tables `goods_receipts` (`GRN-YYMMDD-NNNN`, warehouse-only by trigger, `without_po` must agree with `po_id`, `has_discrepancy`) and `goods_receipt_items` (`qty_remaining_before`, `over_received`). Both append-only (update/delete refused, rows vanish only with their tenant).
  RLS like POs: owner and warehouse staff, own warehouses only, no client writes. `purchase_orders` gained `short_closed_at`, `short_closed_by`, `close_reason`.
- `receive_po(id, po_id, items, notes, delivery_ref)`: ordered or partly-received PO only; all-or-nothing; one `receipt` movement per line (`ref_type goods_receipt`) so RECEIVING bin, bin invariant and average cost follow from the ledger triggers.
  Line cost = cost on the delivery, else the PO line cost, else the average is left alone. Adds to `po_items.qty_received`; PO becomes `partly_received` or `received`. Products not on the PO are refused (`not_on_po`).
  Over-delivery is accepted and flagged; a short delivery is just a partly received PO. Same receipt id + same PO = replay; the same id for another PO = `id_conflict`.
- `receive_without_po(id, warehouse, supplier?, items, ...)`: walk-in delivery, flagged `without_po` and audited as `grn.receive_no_po`; supplier optional; warehouse must be one the user is assigned to.
- `close_po(po_id, reason)`: short-close a PO that received something; PO becomes `received` with who, when and why; nothing received = `nothing_received` (cancel instead); harmless if repeated.
- Mutation checks: 21 rules broken on purpose (qty counted twice or never, status logic both ways, over-delivery flag, PO cost vs invoice cost, stock not written, status gate, access checks on all three RPCs, replay rules,
  off-PO products, duplicate lines, store acceptance, foreign supplier, close rules). All caught; one needed a new assertion (`qty_remaining_before` on a second delivery), added.
- Not done here: editing a draft PO, returning goods to a supplier, receipts in other currencies, expiry dates on warehouse receipts, lot numbers, putting goods away from RECEIVING (existing `execute_putaway`), screens, the phone/outbox side.

## F-13e result (2026-11-09)
Migration `20261109000500_warehouse_counts.sql`, pgTAP `039_warehouse_counts.test.sql` (109 tests), isolation matrix `004` gained `stock_counts` and `stock_count_items`. `pnpm check` green (pgTAP 4251 in 39 files).

- Tables `stock_counts` (`CNT-YYMMDD-NNNN`, status open / closed / cancelled, optional `bin_id` scope, one OPEN count per warehouse by partial unique index) and `stock_count_items`
  (`qty_system`, `qty_counted >= 0`, `qty_variance`, `auto_zero`). Finished counts are history: update/delete refused by trigger. RLS: owner and warehouse staff, own warehouses only, no client writes.
- RPCs (owner or the warehouse's own staff; both modules on): `start_count(id, warehouse, bin?, notes?)`, `record_count(count, items)` (1 to 500 lines, all-or-nothing, a product counted again replaces its line),
  `close_count(count, zero_uncounted?)`, `cancel_count(count, reason?)`. Recording moves nothing; closing writes `count_correction` movements (`ref_type stock_count`) for lines that differ. Every action is idempotent or harmless when repeated and audited.
- **Key rule:** each line stores the system quantity at the moment it was counted; the correction is `counted - that`, so a delivery or sale during the count survives (count 97 of 100, 10 arrive later: 107, not 97). Recounting refreshes the snapshot.
  Corrections never change the average cost.
- With bins every line names a bin of that warehouse and the correction lands in that bin, so sum of bins = warehouse stock still holds. A bin count touches only its bin. `zero_uncounted` treats stock in scope that has no line as counted zero (marked `auto_zero`);
  with a bin scope it zeroes only inside that bin. Closing a count with no lines is refused (`nothing_counted`).
- Mutation checks: 26 rules broken on purpose. 23 caught by assertions, including the stale-snapshot case; 3 gaps found and closed with new tests (recount snapshot, replay with another warehouse, cancel by another warehouse's user).
  Two mutants (closing matching lines, zeroing already-counted spots) are caught only because the table constraints make the test crash; one (two open counts) is equivalent because the unique index gives the same hint.
- Not done here: approval of large variances (supervisor PIN, planned with the phone work in F-13h), blind counts, count sheets/printing, counting stores with this flow (stores keep `adjust_stock`), screens, the phone side.

## F-13f result (2026-11-09)
Migration `20261109000600_warehouse_views.sql`, pgTAP `040_warehouse_views.test.sql` (78 tests). `pnpm check` green (pgTAP 4329 in 40 files). No new tables.

Three read-only functions, all `security invoker` + `stable`, so row-level security does the scoping (owner: every warehouse; warehouse user: own warehouses; store admin and cashier: none; tenants never mix). Anonymous users cannot call them.
- `warehouse_stock_by_variant(variant)`: one row per visible warehouse (including ones that hold none): on hand, average cost, stock value, `incoming_qty` (shipped transfers not yet received) and `on_order_qty` (ordered minus received on ordered or partly received POs; drafts, cancelled and finished are ignored).
- `warehouse_reorder_list(warehouse?, limit, after_location, after_variant)`: lines at or below the variant's reorder point (0 = not managed, stores excluded, negative stock included) with incoming and on-order, `covered` (on hand + incoming + on order is above the point) and `shortfall`. Keyset paged, 1 to 500.
- `warehouse_transfers_in_transit(warehouse?, limit, after_shipped_at, after_id)`: shipped, not received, touching a warehouse the caller can see (store-to-store shipments excluded); newest first; lines, units, hours in transit. Names of locations the caller cannot see come back null.
- Limitation, by design for now: `reorder_point` is one number per product for every place it is stocked. Different thresholds per warehouse would need a small `(location, variant, reorder_point)` table; not built.
- Mutation checks: 24 rules broken on purpose (store/status/direction filters, on-order arithmetic, value, empty warehouses, threshold boundary, unmanaged products, incoming/on-order in covered and shortfall, warehouse filter, keyset repeat, page cap, unit sum, and `security definer` leaks on all three). Six first survived because the fixtures could not tell them apart; fixtures were strengthened (a product exactly at its point, an unmanaged product at zero, a store line below its point, a line covered by incoming stock alone, a two-line shipment, a store-to-store shipment, 510 lines for the cap). All 24 are now caught.
- Not covered: the 500 cap on `warehouse_transfers_in_transit` (same expression as the reorder list, which is tested).

## F-13g slice 1 result (2026-11-09): Purchasing screen in the web app
Route `/app/purchasing` (guard `purchasing.manage`, nav entry "Purchasing" / "Pagbili", Full mode only). Files: `src/routes/purchasing.tsx`, `src/lib/purchasing-api.ts` (typed wrappers, direct reads under RLS), `src/lib/purchasing-math.ts` + `purchasing-math.test.ts` (17 tests), locale keys under `admin.purchasing` and new error hints in `errors.json` (English and Filipino, parity test green).
- **Orders tab:** list with status and warehouse filters; new order (warehouse, supplier, expected date, lines with product, quantity, optional cost; save as draft or place now); details; place, cancel (with reason), receive, close short, receive without an order. Buttons follow what the server accepts (`poActions`).
- **Receive dialog:** per-line remaining, arrived quantity, optional invoice cost (the order's cost shown as the placeholder), "fill with what is still expected", live over-delivery warning (accepted and flagged by the server), delivery number and notes.
- **Suppliers tab:** list, add, edit, remove. **Deliveries tab:** receipts with order link, delivery number, "no order" and "more than ordered" badges, expandable lines.
- One id per dialog (UUIDv7), so retrying after a dropped connection is a replay, not a second order or receipt.
- **Checked in the browser** against local Supabase with a throwaway tenant (`whtest`: two warehouses, a store, an owner and two warehouse clerks): added a supplier, validation on an empty order, a two-line order placed, a partial delivery at an invoice cost (stock and average cost matched the database), an over-delivery (accepted and flagged), closing short, the deliveries list, and a second warehouse's clerk: sees only their warehouse, none of the other warehouse's orders or deliveries, but the shared suppliers. Filipino rendering checked. No console errors.
- Found and fixed along the way: pgTAP `037` and `039` counted audit rows and supplier names across the whole database, so unrelated data in the dev database could fail them. They are now scoped to their own tenants.
- Not done in this slice: editing a draft order, searching products by typing (the picker is a plain list of up to 1000 variants), printing an order, pagination beyond 200 orders / 100 deliveries, component tests (the web client only tests pure logic).
- Dev note: the Claude preview tool is tied to the original checkout and cannot serve this worktree; run `pnpm --filter @pos/client dev --port 5174` from the worktree and open it in the browser pane. The worktree needs its own gitignored `apps/client/.env.local` (copy from the main checkout). The local test tenant can be recreated with a short script (service-role admin API for the auth users, `provision_tenant` for the tenant).

## F-13g slice 2 result (2026-11-09): Counts screen in the web app
Route `/app/counts` (guard `stock.adjust_warehouse`, nav "Counts" / "Bilangan", Full mode only). Files: `src/routes/counts.tsx`, `src/lib/counts-api.ts`, `src/lib/counts-math.ts` + `counts-math.test.ts` (16 tests), locale keys under `admin.counts` (English and Filipino).
- **Flow:** pick a warehouse (only the ones the user may count) -> start a count (whole warehouse, or one bin when the warehouse uses bins; one open count per warehouse is enforced by the server) -> a table of everything the system holds in scope, plus any product the user adds (found stock) -> type counted quantities (0 is a real count) and save as often as needed -> close (summary of shortage and surplus, optional "treat products I did not count as zero" with the number of products that would be zeroed) or cancel (with a reason). Closed and cancelled counts stay in an expandable history with per-line differences.
- **Rules shown on screen:** saving changes no stock; the difference preview is counted minus the system quantity at the moment the line was counted (what the server will apply); close is disabled while typed quantities are unsaved; a bin count only offers its own bin.
- **Pure rules** (`counts-math`): row identity (product + bin), merging live system quantities with saved lines and added rows (scoped to the bin), turning typed text into the payload (0 allowed, bin required with bins), variance summary, status helpers.
- **Checked in the browser** against local Supabase: as a second warehouse's clerk (bins on): empty-scope validation, one-bin count, live preview, invalid quantity refused, save (no stock moved), found stock added, close with "zero uncounted" ticked on a one-bin count: corrections landed only in that bin (RECEIVING untouched), totals and the bin invariant correct. As the owner (no bins): full count, uncounted products zeroed with a warning first (oil -20, sugar -7, rice -2), unsaved-quantity guard, cancel (stock unchanged). No console errors.
- Found and fixed along the way: messages that embedded a count ("Saved 1 lines.") were reworded to be number-neutral, because plural forms differ in Filipino (project rule: no typed counts in plural text).
- Not done in this slice: blind counts (hiding the system quantity), count sheets/printing, scanning, supervisor approval for large variances, product search by typing (plain list, up to 1000 variants), history paging beyond 50 counts, component tests.
