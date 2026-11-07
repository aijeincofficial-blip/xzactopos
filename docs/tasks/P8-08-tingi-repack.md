# P8-08 Tingi / repack (DONE)

Server: migration `supabase/migrations/20261108001500_tingi_repack.sql`, pgTAP `supabase/tests/020_tingi_repack.test.sql` (102,
incl. a seeded 400-step property test) plus `conversions` rows in the `004` matrix (50).
Flutter data layer: Drift schema v8, `SalesStore` methods, sync engine, tests `apps/mobile/test/tingi_test.dart` (15).
**No screens**: P8-09 (Sonnet) builds them on this API.

## Model
A store buys a pack (kaha, box, bundle) and sells single pieces. **The piece is its own product with its own default variant**
(Sell, search and quick tiles show a product's default variant, and the variant is the stockable / sellable unit), so the
catalog has e.g. "Yosi (kaha)" and "Yosi (stick)". A **link on the pack variant** says "1 of me breaks into N of that piece
variant". Opening a pack is a conversion: one movement out of the pack, one into the piece, under one id, in one op.
Stock is never edited: only `stock_movements`; `stock_levels` stays trigger-derived.

### The link (`product_variants`)
- `breaks_into_variant_id uuid` (the piece variant) and `breaks_into_qty integer` (pieces per pack, whole, 1..10000).
  Both set or both null (check). Not itself (check). Same tenant: composite FK `(tenant_id, breaks_into_variant_id)` ->
  `product_variants (tenant_id, id)`.
- **No chains, so no cycles:** a variant is a pack or a piece, never both. Trigger `guard_tingi_link` (serialised per tenant
  with an advisory lock) refuses a link whose piece is itself a pack, or whose pack is already some live pack's piece
  (hint `link_chain`). Several packs may break into the same piece (a carton and a kaha both into sticks).
- Soft delete: archived variants do not count for the chain rule; a link to an archived piece cannot be made
  (`piece_archived`) and cannot be opened (`piece_archived`). Both products must track stock (`not_tracked`).
- The catalog pull (`sync_pull_catalog`) now returns both columns on `product_variants` rows (additive). Changing a link moves
  the variant's `updated_at`, so it arrives by the normal delta pull.

## Cost rule (integer centavos; server `stock_blend_cost`, phone `conversionAvgCost` / `receiptAvgCost` - the same rule)
- `A` = the pack's average cost at the store (`stock_levels.avg_cost`); none -> the pack variant's `cost` when > 0; none ->
  unknown (no cost moves; the piece average is left alone).
- `T = packs x A`: exact, nothing rounded (whole packs x whole centavos). The pack leaves at `A` each, so the pack's stock value
  drops by exactly `T` (outgoing movements never change `avg_cost`).
- The pieces arrive carrying `T` (`stock_movements.total_cost` on the `conversion_in` row). With `Q`, `C` = the piece level and
  average before and `N` = packs x ratio:
  - `Q > 0` and `C` known: `C' = half_up((Q x C + T) / (Q + N))`
  - otherwise (no pieces, below zero, or no average): `C' = half_up(T / N)`
  - `half_up(n / d) = floor((2n + d) / (2d))`, computed exactly (Postgres `div`, Dart `BigInt`), never via a rounded division.
- **The stored average is the only rounding.** Stock value (qty x avg_cost) of pack + piece after the opening differs from before
  by `(Q + N) x (C' - exact)`: **at most half a centavo per piece on hand** (`2 |diff| <= Q + N`), zero when the division is exact.
- Receipts now use the same function (`value = qty x unit_cost`); for every realistic number this is what the old
  `round(...)` gave (test 013 unchanged), but now server and phone share one exact formula.
- A void does not move either average (like a sale void).

**Worked example (with a remainder).** A kaha at 103.50 (`A = 10350`), no sticks yet, ratio 20, open 1:
`T = 10350`, `C' = half_up(10350 / 20) = half_up(517.5) = 518`. The kaha's value drops 10350; the sticks are worth
`20 x 518 = 10360`: 10 centavos over, and the bound for 20 pieces is `20 / 2 = 10`. Open 2 more with those 20 on hand:
`T = 20700`, `C' = half_up((20 x 518 + 20700) / 60) = half_up(517.67) = 518`. A loose bought 5 sticks at 5.00 + 1 kaha:
`(2500 + 10350) / 25 = 514` exactly (no rounding at all).

### Stock rules
- Opening more packs than counted is **allowed** (the pack level goes below zero), like a sale: the app warns, nothing blocks.
- A void reverses both movements and **may push the piece level below zero** (pieces already sold): allowed for the same reason.
- Pieces from a pack make the piece "counted" (like a stock in); the pack side does not change its flag.

## Server
- `conversions` (append-only, guard trigger like `service_txns`: only one void - `voided_at`, `void_reason`, `voided_by`):
  client `id`, `tenant_id`, `location_id` (a store), `client_op_id` (unique per tenant), `pack_variant_id`, `piece_variant_id`,
  `packs`, `ratio` (at the time), `pieces` (= packs x ratio, check), `pack_cost`, `total_cost` (= packs x pack_cost, check),
  `piece_cost` (= half_up(total / pieces), display only), `note` (max 200), `converted_at`, `created_by`, `created_at`,
  `updated_at`, `deleted_at` (never set). RLS: read like `stock_movements` (the user's stores); no client writes.
- `stock_movements.type` gains `conversion_out` (pack, `-packs`, `unit_cost = A`), `conversion_in` (piece, `+pieces`,
  `unit_cost = piece_cost`, `total_cost = T`) - both `ref_type 'conversion'`, `ref_id` = the conversion id - and
  `conversion_void` (`ref_type 'conversion_void'`, the two reversals). New column `total_cost` (conversion_in only, check).
- `apply_stock_movement` re-created: `receipt` and `conversion_in` both go through `stock_blend_cost`; `conversion_in` counts.

### Who (the UI hides; the server enforces) - mirrors the existing rules, no new approvals
| Who | set_tingi_link (= catalog edit) | open_pack / void_open_pack (= receive / adjust stock) |
| --- | --- | --- |
| owner (superadmin) | yes | yes |
| admin who manages a store (`catalog_write_mode() = 'full'`) | yes | yes |
| admin who is only a supervisor | `not_allowed` | `not_allowed` |
| cashier | `not_allowed` | `not_allowed` |
| warehouse (cost and SKU only) | `not_allowed` | `not_allowed` |

Audit (small meta, replays write nothing): `product.tingi_link` (entity `variant`, `{piece_variant_id, pieces_per_pack, op_id}`,
only when the link changed), `stock.open_pack` (entity `conversion`, `{pack_variant_id, piece_variant_id, packs, pieces,
total_cost?, op_id}`), `stock.void_open_pack` (entity `conversion`, `{packs, pieces, reason?, op_id}`).

### Ops (through `sync_push`, idempotent by `op_id`)
`{ op_id, kind: "set_tingi_link", payload }`
```json
{ "variant_id": "<pack variant>", "piece_variant_id": "<piece variant> | null (= clear)", "pieces_per_pack": 20 }
```
Result `{ variant_id, piece_variant_id, pieces_per_pack, changed, applied_at, replay }`.

`{ op_id, kind: "open_pack", payload }`
```json
{
  "id": "<uuid v7 of the opening, required>",
  "pack_variant_id": "<uuid>",
  "packs": 2,                          // whole number 1..10000 (number or digit string); pieces at most 1,000,000
  "piece_variant_id": "<uuid>",        // optional guard: what the phone showed
  "pieces_per_pack": 20,               // optional guard: what the phone showed
  "note": "bukas",                     // optional, max 200
  "at": "2026-11-08T02:00:00Z",        // optional, default now()
  "location_id": "<store uuid>"        // optional when the user has exactly one store
}
```
Result `{ conversion_id, piece_variant_id, pieces, pack_cost, total_cost, piece_cost, applied_at, replay }`.
When a guard is sent and the link is different now, the op is refused (`link_changed`): phone and server never disagree on how
many pieces came out.

`{ op_id, kind: "void_open_pack", payload }` -> `{ "conversion_id": "<uuid>", "reason": "mali" }` (reason optional, max 200).
Result `{ conversion_id, applied_at, replay }`. A second void (new op id) is refused: `already_voided`.

Hints: `not_allowed`, `invalid_value`, `id_required`, `id_conflict`, `unknown_variant`, `piece_archived`, `not_tracked`,
`link_self`, `link_chain`, `ratio_invalid`, `qty_invalid`, `no_tingi_link`, `link_changed`, `conversion_not_found`,
`already_voided`, `location_required`, `location_denied`, `op_id_reused`, `module_disabled`.

### Pull: `sync_pull_conversions(p_cursor jsonb default null, p_limit int default 100)` (1..200)
Same rules as `sync_pull_service` (first pull = last 30 days by `converted_at`, then delta by `(updated_at, id)`, rows newer
than now - 5 s wait, a void comes again). Runs as the caller (store access).
```json
{ "rows": [ { "id", "location_id", "pack_variant_id", "piece_variant_id", "packs", "ratio", "pieces", "pack_cost",
              "total_cost", "piece_cost", "note", "converted_at", "created_by", "voided_at", "void_reason", "updated_at" } ],
  "cursor": { "ts": "<updated_at>", "k": "<id>" }, "has_more": false, "server_time": "..." }
```
**The stock levels themselves come through `sync_pull_pos` as always** (the trigger moves both levels' `updated_at`).

## Device: store API (`lib/data/sales_models.dart`, implemented in `drift_sales.dart`)
```dart
Future<void> setTingiLink({required String variantId, String? pieceVariantId, int? piecesPerPack, required String opId});
Future<void> clearTingiLink({required String variantId, required String opId});
Future<ProductView?> tingiPiece(String packVariantId);
Future<OpenedPack> openPack({required String id, required String packVariantId, required int packs, String? note,
    DateTime? at, required String opId});
Future<void> voidOpenPack({required String conversionId, String? reason, required String opId});
Stream<List<ConversionView>> watchConversions({required DateTime from, required DateTime to});
Future<int?> averageCost(String variantId);
// sync side
Future<void> applyPullConversions(Map<String, dynamic> response);
```
- `ProductView` (every product query: `watchProducts`, `findByBarcode`, `quickItems`, `watchStockList`, `tingiPiece`) gains
  `breaksIntoVariantId`, `piecesPerPack`, `pieceName` (the piece product's name, null if archived / missing) and
  `sellsByPiece`. `StockRow.product` carries them too.
- `setTingiLink` checks like the server (ArgumentError: ratio, self; StateError: unknown / archived, not tracked, chain), writes
  the local variant row and queues `set_tingi_link` with **entity = the pack's product id** (so the product shows `pending` and
  the catalog pull keeps the local row until the op has gone).
- `openPack` returns `OpenedPack(conversionId, pieceVariantId, packs, pieces, packCost, totalCost, pieceCost)`; writes a
  `conversions` row and two `local_movements` (pack `-packs`; piece `+pieces`, `counts`, `totalCost = T`) under the op id, and
  queues `open_pack` (entity = the opening id) with the link guards.
- `voidOpenPack` sets `voidedAt`, writes the two reversing local movements, queues `void_open_pack`.
- `ConversionView`: id, pack / piece variant ids and names, packs, ratio, pieces, packCost, totalCost, pieceCost, note,
  convertedAt, voidedAt / `voided`, voidReason, `pending`, `rejectedHint`.
- **Stock on the phone** = server level + `local_movements` not yet covered (the P4-02 rule: dropped once a complete pull has
  passed the op's `applied_at` and the level row is at least that new) - so both numbers change at once and never count twice.
- **Cost on the phone** (`averageCost`, sale cost of goods, the pack cost when opening): the server's `avg_cost`, then this
  device's uncovered movements replayed in order with the same integer rule (stock in with a cost -> `receiptAvgCost`, pieces
  from a pack -> `conversionAvgCost`, everything else quantity only). So a stick sold right after opening, offline, carries the
  same cost the server will hold. (This also fixes a stock in with a cost that the server had not confirmed yet: sales used the
  old average until the pull.) Helpers `halfUpDiv`, `receiptAvgCost`, `conversionAvgCost`, constants `tingiMaxPacks`,
  `tingiMaxRatio`.
- Drift v8: `variants.breaks_into_variant_id`, `variants.breaks_into_qty`, `local_movements.unit_cost`,
  `local_movements.total_cost`, table `conversions` (+ index `conversions_converted_at`); the `product_variants` cursor is
  dropped so the link columns fill on the next pull. Columns are added only if missing; every existing row is kept.

## Sync
- `set_tingi_link`, `open_pack`, `void_open_pack` go through `sync_push` in order with the other ops (same batching, retry,
  backoff). A `rejected` result parks the op as failed (`failedOps()`, `ConversionView.rejectedHint`); `discardFailed(opId)` takes
  its stock effects back (movements by op id), deletes a never-synced opening or un-voids a discarded void; a discarded link is
  restored by the full re-pull that `discardFailed` forces.
- After the service pull the engine pulls `SyncApi.pullConversions` (cursor `conversions`); a void still on its way is kept.

## What P8-09 (screens) must call
1. **Product form, section "Sold by piece too" (Tingi)**, owner / manager only: a toggle, "pieces per pack" (whole number),
   piece name (default "<name> (piraso)") and piece price. On save: create the piece product with `saveProduct(ProductDraft(id:
   uuid.v7(), variantId: uuid.v7(), name:, price:, ...), opId: uuid.v7())`, then `setTingiLink(variantId: pack.variantId,
   pieceVariantId: piece.variantId, piecesPerPack: n, opId: uuid.v7())` (same order, so the server has the piece first). Editing
   the ratio = `setTingiLink` again; turning it off = `clearTingiLink`. Show `pieceName` on the pack; hide the section on a
   product that is itself a piece (catch the StateError text for chains). Both products must keep a stock count.
2. **Stock screen, "Open a pack" action** on rows with `product.sellsByPiece`: ask how many packs (whole, default 1), preview
   `packs x piecesPerPack` pieces of `pieceName`, warn (do not block) when `qty < packs`, then `openPack(id: uuid.v7(),
   packVariantId:, packs:, opId: uuid.v7())`. Optional history from `watchConversions(from, to)` with a void action
   (`voidOpenPack`), showing `pending` / `rejectedHint` (`link_changed`: "the pieces per pack changed; check the product").
3. Selling pieces needs nothing new: the piece is an ordinary product; its cost of goods comes from `averageCost` automatically.
All labels through ARB (en + fil).

## Tests
- pgTAP `020_tingi_repack.test.sql` (102): link set / replay / no-change / clear, self, ratio 0 / 2.5 / 10001 / missing, chains
  both ways and the two-way cycle, cross-tenant piece, untracked, unknown, archived; direct-write checks (FK, checks, guard
  trigger); openings: result, levels, averages, value bound, movements, conversions row, counted, replay, audit, blend, link
  guards, bad packs, missing id, no link, id reuse, not tracked, archived piece, over-opening, no cost, variant-cost fallback;
  voids: levels, reversals, nothing deleted, replay, second void, unknown, below zero after sales, audit; append-only; roles
  (manager yes; supervisor, cashier, warehouse, other tenant no); pull fields, paging, hold-back, per-role, catalog link; and a
  seeded property test (6 pairs with random ratios, 400 random stock-ins with random costs, openings, piece sales, voids,
  second voids and replays): exact quantities, pack average unmoved, `T = packs x A`, piece average = an independent rounded
  numeric division, value within `2|diff| <= pieces`, voids restore both levels exactly, replays change nothing, and every
  level = the sum of its movements. Mutation-checked (floor instead of half-up fails 8 tests incl. the property).
- Flutter `tingi_test.dart` (15): link on the product / payload / clear, validation, untracked piece, opening effects and payload,
  sale cost after opening, blend and no-cost, over-opening, refusals, void, a full sync round trip with a lost reply (applied
  once, numbers unchanged when the server copy arrives, local effects dropped), `link_changed` refusal + discard, cashier
  refusal + link restored, a void kept while on its way, a property test against an independent model (160 random steps, with
  syncs in between and after) incl. the value bound and sale costs, the helper rule, v7 -> v8 upgrade.
