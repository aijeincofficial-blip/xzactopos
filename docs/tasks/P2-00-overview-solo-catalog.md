# Phase 2 (solo): Catalog and local store, in Flutter

Replaces the Dexie/React wording of plan section 12 Phase 2. Everything else in plan sections 6 and 7 still applies.

## Goal
A tindera adds her products in seconds, the catalog is on her phone, and she can search or scan it with no signal.
**Done when:** a new solo user adds 5 products (name, price, optional barcode, optional photo) in under 3 minutes; the app is put in airplane mode;
search by name and lookup by barcode still work; adding a product offline syncs when the signal returns; `pnpm check` and `flutter test` are green.

## Decisions (change them here before starting P2-01)
1. **One name, one price, one default variant.** The UI never says "variant" in Solo mode. The schema keeps `product_variants` + `variant_prices`
   exactly as plan section 6, so Full mode can add option sets later with no migration of sales data.
2. **Deferred to Full mode:** option sets and the matrix generator, `product_translations`, CSV import, suppliers. Solo uses one name.
3. **Offline add/edit of products is allowed for solo.** One editor means no conflicts, so ops go through the outbox with a client `client_op_id`
   and last-write-wins by server `updated_at`. (Plan section 7 says master data is online-only; that is relaxed for single-user tenants only.)
4. **Local store is Drift (SQLite)**, behind a `LocalStore` interface like the plan says. Risk: Drift on web needs the sqlite3 wasm setup, so P2-03 starts with a spike.
5. **Photos live in Supabase Storage, never in the DB** (CLAUDE.md). Resized on the device to about 640 px, JPEG, under 100 KB.
6. **Stock starts in Phase 4, but "opening stock" is asked at product add** and stored locally until the ledger exists. Do not write `stock_levels` from the client.
7. **Currency:** PHP, integer centavos. Dart money utils are a port of `packages/core` money tests.

## Cards (one at a time, in order)
| Card | Work | Model |
| --- | --- | --- |
| P2-01 catalog schema | migration + RLS + pgTAP + isolation matrix rows | Opus |
| P2-02 catalog RPCs and sync pull | `upsert_product`, `archive_product`, `sync_pull_catalog` | Opus |
| P2-03 local store | Dart money, Drift `LocalStore`, pull sync, outbox for product ops | Opus |
| P2-04 products UI | list, quick add, edit, archive, low-effort empty state (fil + en) | Sonnet |
| P2-05 search and scan | instant search, barcode lookup (keyboard scanner, then camera) | Sonnet |
| P2-06 photos | Storage bucket + policies, capture, resize, upload queue | Sonnet |
| P2-07 acceptance | offline walk-through, report in handoff | Sonnet |

## Prerequisite for the phone
Android toolchain (`flutter doctor`: cmdline-tools and licenses). Needed for P2-05 camera scan and the phone test, not for P2-01 to P2-04 (Chrome).
