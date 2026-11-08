# F-02 Server sale number and devices (data layer DONE)

Second Full-mode card (`F-00-overview-full-mode.md`, solo limitation 3; gap B1). SERVER + Flutter DATA LAYER only (Opus).
No screen, no ARB string was changed. Showing the number on the receipt and in Today is the next step (Sonnet), see the end.

## Problem (before)
- The phone numbers a sale `<device code>-YYMMDD-NNNN`: a random 3-character code made once per phone (meta
  `device_code`) plus a per-day counter (meta `receipt_YYMMDD`).
- The server refused a repeated number tenant-wide: `constraint sales_local_no_per_tenant unique (tenant_id, local_no)`
  (`20261108000500_sales_ledger.sql`), surfaced as hint `duplicate_local_no` by `op_record_sale`. Two phones that drew
  the same code produce the same numbers, so the second phone's sale was REJECTED (parked as failed: money not synced).
- Receipts had no per-store sequence and no number that every device agrees on.

## Model (server: `20261108002100_devices_sale_no.sql`)
### `devices`
| Column | Notes |
| --- | --- |
| `id uuid` primary key | UUIDv7 made by the app on first use, kept in the phone's meta, never changes. Globally unique: an id another tenant uses is refused (`id_conflict`). |
| `tenant_id` | fk tenants (cascade); `unique (tenant_id, id)` so sales can reference it within the tenant |
| `user_id` | who registered it (set on insert only; a shared phone keeps its first user) |
| `name` | optional, 1..60 after trim |
| `platform` | optional, 1..20 (`android`, `web`, ...) |
| `first_seen_at`, `last_seen_at`, `created_at`, `updated_at`, `deleted_at` | soft delete = "retired" |

- RLS: read = superadmin and admins (the whole tenant), everyone else their own rows; insert = own rows (`user_id =
  auth.uid()`); update = own rows, and the superadmin any row of the tenant (retire a lost phone); columns a client may
  update: `name, platform, last_seen_at, deleted_at`. No delete privilege. Isolation-matrix rows for every role (`004`).
- Limit: `tenant_limits.max_devices` (column existed since P1-01, default 50; 200 when a tenant has no limits row) devices
  that are not retired. Enforced by a trigger on insert and on un-retire (serialised per tenant with an advisory lock),
  hint `device_limit`. An existing device always re-registers.
- `register_device(p_id uuid, p_name text default null, p_platform text default null) returns jsonb`: any active user;
  idempotent upsert; on insert sets `user_id`; on repeat bumps `last_seen_at`, keeps name/platform when given null,
  un-retires (subject to the limit). Hints: `id_required`, `invalid_value` (name > 60 / platform > 20), `id_conflict`,
  `device_limit`. Returns `{id, name, platform, user_id, first_seen_at, last_seen_at}`.

### `sale_counters` (server-only, no client privilege at all, like `processed_ops`)
`(tenant_id, location_id, day, last_no, updated_at)`, primary key `(location_id, day)`, fk `(tenant_id, location_id)`.

### `sales` columns
- `device_id uuid null`, fk `(tenant_id, device_id) -> devices (tenant_id, id)` (same tenant).
- `sale_no text null`: **`<store code>-<YYMMDD>-<NNNN>`**, e.g. `S01-261108-0001`. Day = the tenant-timezone business
  day of `sold_at` (same convention as `daily_sales_summary`: `(sold_at at time zone tenants.timezone)::date`). NNNN =
  per (store, day) counter from 1, zero-padded to 4 and simply longer after 9999 (`S01-261108-10000`, never cut).
  Unique index `(location_id, sale_no) where sale_no is not null`.
- Rows from before F-02 keep `sale_no` and `device_id` null (no row was rewritten); the app shows their local number.

### How the number is taken (gap-free, concurrency-safe)
`op_record_sale` calls `next_sale_no(tenant, store, sold_at)` INSIDE the same `begin ... exception` block as the sale
insert: `insert into sale_counters ... on conflict (location_id, day) do update set last_no = last_no + 1 returning`.
- A sale refused after the number was taken (unknown product, a receipt clash, any error) rolls the block / the op's
  subtransaction back, counter included: **no gap**. A replayed op returns the stored `processed_ops` result: **same
  number, no second number**. A void only changes `status`: **the number stays** and is never given again.
- Two concurrent pushes for the same store and day: the upsert takes the counter row's lock; the second waits for the
  first to commit, then (READ COMMITTED re-check of ON CONFLICT DO UPDATE) increments the committed value. So no duplicate
  by construction; the unique index is a second guard. (pgTAP runs in one session, so this is argued, not raced; the
  sequential test proves 1..N with no gap or duplicate.)
- An offline sale synced days later takes the next number of ITS day (numbers within a day follow sync order, not sale
  time).

## Constraint decision (local number)
`sales_local_no_per_tenant unique (tenant_id, local_no)` was DROPPED and replaced by two partial unique indexes:
- `sales_local_no_per_device (tenant_id, device_id, local_no) where device_id is not null`
- `sales_local_no_per_tenant (tenant_id, local_no) where device_id is null` (the old rule, for rows / older apps
  without a device: backward compatible).
Existing rows all have no device and were unique per tenant, so the index built without touching data. Two devices with
the same random code now both sync; the same device repeating a number is still `duplicate_local_no`.

## `record_sale` and the pull
- Payload: optional `device_id`. Decision: the sale is **never refused because of its device**. Registered in this
  tenant -> stored. Unknown id -> registered on the spot for the seller (no name; best effort). Another tenant's id, the
  device limit reached, or not a uuid -> **ignored** (stored null; the sale then falls under the tenant-wide local-number
  rule). Reason: a refused sale is unsynced money; the device only scopes the provisional number.
- Result gains `sale_no` and `device_id`: `{sale_id, local_no, sale_no, device_id, applied_at}` (replays the same).
- `sync_pull_sales` rows gain `sale_no` and `device_id` (additive).
- Unchanged: `sync_push` (no new kind), `op_void_sale`, RLS on sales, audit rows (`sale.create` meta stays
  `{no, total, utang}`), `report_summary`, every other op.

## Phone: Drift schema v14 (`AppDatabase._deviceStep`)
Keeps every row and every unsent op:
- `sales.sale_no`, `sales.device_id` (nullable).
- Makes the device id now (meta `device_id`, UUIDv7) if missing, and gives it to every UNSENT `record_sale` op payload
  (`json_set`, nothing else in the payload changes) and its local sale row. Sales already sent stay `device_id` null.
- Drops the `sales` cursor: the last 30 days come again with their server numbers.

### Store API
```dart
// SalesStore (sales_models.dart), implemented in DriftSales
Future<String> deviceId();   // UUIDv7, made once, meta 'device_id'; new only when ensureTenant clears data for another business
Future<void> posOpApplied(String opId, String? appliedAt, {Map<String, dynamic>? result}); // stores result['sale_no'] on result['sale_id']

// SaleSummary (new optional field and getters)
final String? saleNo;                 // server number, null until confirmed
String get displayNo => saleNo ?? localNo;
bool get provisional => saleNo == null;
// SaleDetail: String? get saleNo; String get displayNo; bool get provisional (delegate to summary)

// sync_engine.dart
abstract class DeviceApi {            // optional second interface: SupabaseBackend implements it, test fakes need not
  Future<Map<String, dynamic>> registerDevice(String id, {String? name, String? platform});
}
// SyncEngine
static const deviceNameKey = 'device_name';   // meta key of the optional device name sent with the registration
Map<String, dynamic>? get device;             // the server's device row once registered this session
Future<bool> registerDevice({bool force = false});
static String get devicePlatform;             // 'web' or defaultTargetPlatform.name
```
- `commitSale`: the local sale row and the `record_sale` payload carry `device_id`. `localNo` generation is unchanged
  (still `<random code>-YYMMDD-NNNN`; with per-device uniqueness on the server a clash of the code no longer matters).
- The engine registers the device at the start of its first run, then not again for that engine (= one sign-in
  session). Best effort: offline / server error = tried on the next run; a permanent refusal (`id_conflict`,
  `device_limit`) is not retried that session. Never blocks pushing or selling.
- The number reaches the phone from the op result (`posOpApplied`) AND from the sales pull, whichever comes first. A
  pulled row without a number never erases a stored one; a sale with an unsent op (e.g. a cancel) still takes the
  server number from the pull. `watchSale` / `watchSales` re-emit when it arrives.

## Tests
- pgTAP `026_devices_sale_no.test.sql` (72): schema; register_device (create, trim, idempotent, last-seen bump, shared
  phone, every role, inactive refused, other tenant `id_conflict`, bad input); RLS on devices per role (read, own
  insert, no insert for others, no owner change, no delete, owner retires); the limit (fits, refused, existing still
  ok, direct insert, retire frees, un-retire over limit refused); sale_no format, per store, per day, the Manila midnight
  boundary both ways, replay same number without consuming, refused sales give the number back (gap-free), cashier
  default store, 1..6 with no gap, counters per store/day; devices on sales (two devices same local number both ok with
  different numbers, same device repeat refused, unknown id registered, other tenant / garbage ignored); void keeps
  the number and it is not reused; > 9999; old rows (null device keeps the tenant rule, device rows may reuse, sale_no
  unique per store, other tenant's device fk); the pull carries both fields (null for old rows); server-only pieces.
  `004` matrix: `devices` and `sale_counters` rows for every role (+100 assertions).
- Flutter `test/device_sale_no_test.dart` (10): device id stable across restarts and new for another business;
  registered once per session (offline first, then once, forced again, next session again); refused registration not
  retried and sales still sync; payload and row carry device_id; offline sale keeps its local number until confirmed;
  sale_no from the op result; sale_no from the pull and never erased; unsent cancel + pull; two stores number on their
  own (fake server); two phones with the same code both sync (B1); v13 -> v14 upgrade keeps rows and ops, patches only
  the unsent sale, drops the sales cursor, then numbers it.
- No existing expectation had to change (Flutter 335 and pgTAP files 001..025 pass as they were, except `004`, which got
  its new rows).

## Not done / limits
- No real concurrent race in pgTAP (one session); the safety argument is above.
- Old server rows keep no `sale_no` (not backfilled, by design).
- Utang ledger rows (`watchLedger` -> `LedgerEntryView.localNo`) and the CSV export still show the local number.
- A device is not renamed from the app yet (no screen); `name` is null unless meta `device_name` is set.
- Store code changes later: new numbers use the new code; the counter is keyed by store id, so no clash.

## What the Sonnet UI step must do
1. Receipt (`receipt_screen.dart`, the printed receipt in `core/receipt_printer.dart`) and the Today / sales lists: show
   `displayNo` instead of `localNo`; when `provisional` is true add a small "not confirmed yet" marker (new ARB key en +
   fil, e.g. `saleNoProvisional`). Optionally show the local number in small print under a confirmed server number.
2. Optional: Settings shows the device (`await store.deviceId()`, short form) and a name field that writes
   `store.setMeta(SyncEngine.deviceNameKey, name)` then calls `CatalogScope.of(context).engine.registerDevice(force: true)`.
3. Optional: utang ledger rows and the export could use the server number (needs `sale_no` in `watchLedger` /
   `LedgerEntryView`, a data-layer change).

## UI step done (Sonnet)
The receipt (`receipt-no`), the Today list, the printed/shared receipt PDF (its title, file name and number line) now show `displayNo`: the server's `sale_no` once the sale is confirmed, the local number before that. The "Not sent yet" marker that was already on the receipt covers the provisional state, so no new string was added. The sales CSV has a new `sale_no` column after `receipt_no` (the local number; empty until confirmed). Test: `test/sale_no_screen_test.dart`. Not done (optional): a device name field in Settings, and the server number in utang ledger rows.
