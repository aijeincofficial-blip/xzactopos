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
| F-13c Suppliers and purchase orders | `suppliers`, `purchase_orders`, `po_items` (tenant-leading, RLS, isolation-matrix rows per role). RPCs: `upsert_supplier`, `create_po` (draft), `submit_po`, `cancel_po`. PO addressed to one warehouse; status draft, ordered, partly_received, received, cancelled. | Opus |
| F-13d Goods receipts | `goods_receipts`, `goods_receipt_items`; `receive_po(po_id, items)` supports partial and over/under receipt, writes `receipt` movements via F-13b, updates `qty_received`, flags discrepancies; receipt without a PO allowed and flagged. | Opus |
| F-13e Warehouse stock counts | `stock_counts`, `stock_count_items`; `start_count`, `submit_count`, `close_count` writes `count_correction` movements for the differences only; works per bin when bins are on, and keeps the invariant. | Opus |
| F-13f Cross-warehouse views | RPCs for stock of one variant across all my warehouses, per-warehouse reorder list, in-transit between warehouses. Reads only; explicit columns, paginated. | Sonnet |
| F-13g React screens | Suppliers, POs, receiving, counts, warehouse switcher; Full-only, guarded with `can()` keys (`purchasing.manage`, `stock.count` already exist in `permissions.ts`). | Sonnet |
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
