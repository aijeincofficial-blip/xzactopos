# P2-03 Local store, money and pull sync (Flutter)
Goal: the catalog lives on the device and stays fresh with minimal data.
- Spike first (30 min): Drift running on web (Chrome) and Android with the same schema. If web storage is not workable, stop and report before building more.
- `lib/core/money.dart`: integer centavos, PHP formatting for fil/en, parse "12.50" to 1250. Port the cases from the TS money tests.
- `LocalStore` interface + Drift implementation: products, variants, prices, categories, `sync_cursors`, `outbox`.
- Sync: pull `sync_pull_catalog` on sign-in and then every 120 s when idle with backoff (CLAUDE.md), apply upserts and tombstones in one local transaction.
  Push: outbox drains `upsert_product` / `archive_product` in order; transient errors retry with backoff; permanent errors go to a "needs attention" list.
- Status badge: synced / pending N / offline. No Realtime.
- Tests: money cases, Drift store (in-memory), sync apply + tombstone, outbox idempotent retry with a fake `Backend`.
- Done when: `flutter analyze` and `flutter test` pass; airplane mode in Chrome devtools keeps reads working. Use Opus.
