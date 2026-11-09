# Full mode: more staff, more stores, warehouse (plan)

Solo is accepted (Phases 0 to 8 plus the opening cash, keypad, wallet float, import/export and tab work; see `docs/tasks/P8-13-acceptance.md`). This overview prepares Full mode. It does not start it. Source plan: `docs/plan.md` sections 4, 5, 7, 8, 12 and 15; triaged gaps: `docs/gaps-review.md` section D. Cards below use the `F-nn` prefix; split them into `F-nn-m` files when one starts.

## Direction change (owner, 2026-11-08): Full mode is React-first
- **Solo stays as it is on the phone** (Flutter, accepted). No new Flutter Solo features are needed; only fixes and an upgrade note (below).
- **Solo also needs a web version (owner, 2026-11-08):** `apps/client` gets a Solo experience too (one owner, one store, sell/stock/utang/Today in the browser, same data and backend). Both Solo apps, phone and web, show an "Upgrade to Full" entry. Solo and Full are the same React app, with the Full screens (staff, stores, warehouse, shifts, reports) hidden until the tenant upgrades.
- **Full mode is built mainly in the React back-office (`apps/client`)**: setup, upgrade wizard, tenant settings, staff, stores, warehouse, bins, shifts review, reports. The earlier plan to build F-03 (settings) and F-04 (staff) screens in Flutter is **parked**; those cards become React cards and Flutter versions come after Full mode works.
- **Upgrade path:** a solo tenant upgrades **in place, same tenant**: the owner starts an "Upgrade to Full" wizard (in React web, reachable from the Solo web app and from the Solo phone app, which opens or links to it), which turns on the modules (`set_modules`, `upsert_location`, `complete_setup`). All products, sales, stock and utang stay; nothing is copied. The Solo app only shows a note that the upgrade exists.
- **Flutter after the upgrade:** still the phone app for selling (owner and cashiers) and, later, warehouse roles. It must be prepared for the change (store picker, server sale numbers and device registration are already done in F-01/F-02; role-based tabs and offline PIN follow).
- **Decisions recorded:** 3 to 10 stores and 5 to 30 staff (plan on Pro); per-cashier shifts needed before staff go live; supervisor PIN must work offline (F-06 before staff go live); discounts: small threshold for cashiers, above it a supervisor PIN; React admin is kept; warehouse is in the first Full release.
- **Findings for the wizard:** the solo owner already has the `superadmin` role (`provision_solo_store`), so `set_modules`, `upsert_location` and `complete_setup` (name, timezone, tax mode, locales; base currency locked after setup) can be called as they are. No server change is known to be needed for the wizard itself.

## What Full mode is (from the recalibration doc)
Same app, same backend, same data. Solo is the default (one owner, one store, auto-provisioned). Full mode is switched on per tenant through `tenant_modules` and role assignments: more users, more stores, a warehouse. No data migration when a store grows. The role decides which screens a user sees; the database enforces (RPCs check role, location and module). Heavy modules are loaded only when on and are not synced when off.

## Already in place (do not rebuild)
- Tenancy, RBAC (superadmin, admin with manager or supervisor per store, warehouse, cashier), RLS on every table, `has_location_access`, custom access-token hook, audit log, `provision_solo_store`.
- Edge Functions `create_user` (cashier with a synthetic email) and `invite_user`; admin RPCs `set_user_role`, `assign_location`, `revoke_location`, `set_user_active`, `upsert_location`, `set_modules`, `get_my_access`. The React `apps/client` back-office uses them.
- Supervisor PIN approval (`set_my_pin`, `approve_supervisor_action`, `supervisor_approvals`) used by expenses, day close and service entries; audit rows for those.
- Idempotent `sync_push` ops, delta pulls with 5 s hold-back, the Drift outbox pattern, per-location wallet float, day close, expenses, services, tingi conversions, stock ledger with average cost.

## Solo limitations Full mode must resolve first
These were accepted for one store and are wrong or incomplete with several stores or staff (1, 2 and the opening-cash /
per-store part of 7 are resolved on the data side by F-01):
1. **No store on local sales** (`sales` table on the phone has no store column); the sale op only works when the user has exactly one store (gap B3). Sales, expected cash and reports must be per store.
2. **Utang ledger has no store or payment method** (`customer_ledger`); the day close counts every utang payment as cash, tenant-wide.
3. **Receipt numbers** use a random 3-character device code, so two devices can clash (gap B1). Needs server `sale_no` and a `devices` table. **Resolved on the data side by F-02** (local numbers unique per device; server `sale_no` per store and day).
4. **Expense and report reads are admin-only**; cashiers cannot see cash expenses at the drawer count.
5. **Supervisors need signal once** to get a PIN approval (no offline PIN RPC; `profiles.pin_hash` and the manager-override design exist but offline verification does not).
6. **Refused ops** (missing approval) are not audit-logged.
7. **Expiry is one date per product** (no lots); **piece cost** and **opening cash default** assume one store per phone.
8. Reports are online only (last result cached); no `stock_snapshots_daily`.
9. CI has never run (no remote), the React admin's future is undecided, release APK signing needs the owner's keystore.

## Proposed order and cards
| Card | Work | Model |
| --- | --- | --- |
| F-00a Housekeeping | Merge the solo branch to `main` (owner's OK), CI remote and first green run (C1), keystore by the owner, decide the React admin, write `docs/START-HERE-full-mode.md` | Sonnet |
| F-01 Store scoping | `location_id` on local sales and on `customer_ledger` (migration + backfill), store picker, every sale/stock/report query scoped to the chosen store, B3 fixed, day close and wallet float per store. **Data layer DONE (2026-11-08, `F-01-store-scoping.md`); picker UI open (Sonnet), steps listed at the end of that card. Reports stay all-stores until F-10.** | Opus (schema, sync, ledger) then Sonnet (picker UI) |
| F-02 Server sale number and devices | `devices` table, server-issued `sale_no` per store, keep offline local number until sync (B1). **Data layer DONE (2026-11-08, `F-02-server-sale-number-and-devices.md`); showing `displayNo` + "not confirmed yet" on receipt and Today open (Sonnet).** | Opus |
| F-03 Tenant settings and the mode switch | Settings screen (name, timezone, tax mode, languages), "Add staff / another store / warehouse" flow that toggles `tenant_modules`, limits shown, nothing changes for a solo owner who does not use it | Sonnet (RPCs exist) |
| F-04 Staff in the Flutter app | List, create cashier, invite by email, roles and positions, store assignment, deactivate; cashier and warehouse home screens (fewer tabs); set PIN screen | Sonnet (Opus if a new RPC is needed) |
| F-05 Shifts and the drawer | Open and close a shift per cashier with opening and counted cash (generalises the day close), X and Z reports, expenses visible to the shift's cashier | Opus (ledger) then Sonnet |
| F-06 Offline PIN and approvals | Offline PIN unlock (PBKDF2 hash delivered by a dedicated RPC, never readable by clients), offline manager override validated on sync, audit of refused ops | Opus |
| F-07 Sales controls | Per-line and cart discounts with thresholds by role, void and refund rules per role (cashier: own sale, same shift, below limit), card payments | Opus (rules) then Sonnet |
| F-08 Warehouse (plan Phase 5) | Warehouse locations, suppliers, purchase orders, goods receipts, transfers ship/receive/discrepancy, stock counts, warehouse role UI | Opus (stock math) then Sonnet |
| F-09 Bins (plan Phase 5b) | Zones, bins, labels, `bins_enabled`, bin stock = warehouse stock invariant, put-away, pick lists, bin counts | Opus then Sonnet |
| F-10 Reports (plan Phase 6 full) | `stock_snapshots_daily`, store and warehouse reports from rollups, CSV, 2 s on 100K movements | Opus (rollups) then Sonnet |
| F-11 Free-tier operations (plan Phase 8) | Keep-alive, weekly backup, archive job, usage meter, restore runbook, load test | Sonnet |
| F-12 Later (plan Phase 9) | Platform admin UI, loyalty, lots and expiry, multi-currency, Pro upgrade runbook | later |

Dependencies: F-01 and F-02 come before everything with more than one store or device; F-03 and F-04 can start after F-01 (a tenant with staff needs per-store sales); F-05 needs F-04; F-06 can run next to F-05; F-08 needs F-01 and F-04; F-09 needs F-08; F-10 after the data it reads exists.

## Rules that carry over (CLAUDE.md)
Migrations and pgTAP before UI; every new table has RLS, an isolation-matrix row per role and a test; stock only changes through `stock_movements`; money is integer minor units; `unique (tenant_id, ...)` business keys; strings through ARB (en + fil); never edit an existing migration; Opus for RLS, sync, ledger and stock math, Sonnet otherwise; run `pnpm check` before declaring a card done; one commit per card.

## Decisions needed from the owner before F-01
1. **First target:** a second store first (F-01, F-02) or staff first (F-03, F-04)? Recommendation: stores first, because staff without per-store sales would still be wrong.
2. **Real scale:** how many stores, how many staff, sales per day? Decides when to move off the free tier (plan section 2 says plan on Pro for real trading).
3. **Shifts:** does every cashier need an opening and closing cash count, or is the owner's day close enough for now?
4. **Offline supervisor PIN:** must a supervisor approve with no signal at all (needs F-06 before staff go live), or is one connection per approval acceptable?
5. **Discount policy:** thresholds and who may override (plan: above a threshold needs a supervisor PIN).
6. **React admin:** retire it once the Flutter app covers staff and stores, or keep it as a web back-office?
7. **Warehouse:** needed in the first Full release, or after stores and staff?

## Not part of this plan
Barcode hardware tests and thermal printers (set aside by the owner), a platform-operator screen, tax and receipt compliance until local rules are confirmed.
