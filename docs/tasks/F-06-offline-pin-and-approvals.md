# F-06: Offline PIN and Approvals

Source plan: `docs/tasks/F-00-overview-full-mode.md` Card F-06.
Implements secure delivery of manager/supervisor PBKDF2 PIN hashes to authorized store devices, client-side offline PIN verification, offline manager override verification upon sync replay, and audit logging for refused operations.

## Scope & Capabilities

1. **Secure Offline PIN Delivery**:
   - `public.pull_offline_pins(p_location_id uuid default null)`: Secure RPC that returns active store managers, supervisors, and staff with their PBKDF2 `pin_hash` to authorized store devices.
   - Restricts delivery to authenticated devices and users with active access to the store location.
   - Excludes inactive, deleted, or PIN-locked users from synchronization.

2. **Client-Side PIN Verification**:
   - `packages/core/src/pin.ts`: Web Crypto API implementation of PBKDF2-HMAC-SHA256 (`verifyPinPbkdf2`, `hashPinPbkdf2`) matching PostgreSQL/Supabase profile PIN hashes (`pbkdf2_sha256$<iterations>$<salt base64>$<hash base64>`).
   - `apps/client/src/lib/offline-pin-api.ts`: Manages caching of offline PIN hashes in `localStorage` scoped by store location (`pos.offlinePins.<locationId>`) and provides `verifyOfflineSupervisorPin`.
   - `apps/client/src/components/supervisor-pin-dialog.tsx`: When online, validates against server RPC `approve_supervisor_action`; when offline or during network dropouts, seamlessly falls back to local client PBKDF2 verification against cached PINs and generates an `offline_approval` payload.

3. **Server-Side Replay Verification on Sync**:
   - Extended `consume_supervisor_approval` and `authorize_expense_write` to accept `p_offline_approval jsonb default null`.
   - When processing synced operations (`record_sale`, `void_sale`, `record_expense`, `void_expense`), verifies offline approvals:
     - Approver identity exists and is an active supervisor, manager, or admin for the store.
     - Approver's PIN is not locked.
     - Approved action and target reference ID match the current operation.
     - Timestamp freshness is enforced (must be within 7 days and not in the far future: `<= now() + interval '10 minutes'`).
   - Logs an `approval.offline` audit log entry detailing the offline override.

4. **Refused Op Auditing**:
   - `public.sync_push`: Updated exception handling so that any non-transient refusal (e.g. invalid permissions, bad approvals, negative stock invariants, format violations) writes an `op.refused` audit log entry with the op kind, op ID, reason/hint, and error message before returning the rejected status.

5. **Client Sales & Void Integration**:
   - `apps/client/src/lib/sale-math.ts`: Supports `offlineApproval` in `SaleDraft` and serializes into `salePayload`.
   - `apps/client/src/lib/sell-api.ts`: Supports `offlineApproval` in `voidSale`.
   - `apps/client/src/routes/sell.tsx` and `apps/client/src/routes/sales.tsx`: Capture offline approvals from `SupervisorPinDialog` and submit them with offline drafts/ops.

6. **Localization**:
   - 100% key parity between English (`en`) and Filipino (`fil`) in `admin.json` and `errors.json`.

## Server Interactions & RPCs

- `pull_offline_pins`: Delivers active store approver PIN hashes to authorized devices.
- `consume_supervisor_approval`: Validates either online `approval_id` tokens or signed `offline_approval` metadata upon sync.
- `sync_push`: Replays batched offline ops with `op.refused` audit logging on rejections.

## Test Verification

- `packages/core/src/pin.test.ts`: Verifies PBKDF2-HMAC-SHA256 hash formatting, test vectors, and negative test cases.
- `supabase/tests/030_offline_pins_and_approvals.test.sql`: 24 pgTAP tests covering:
  - `pull_offline_pins` store scoping and exclusion of locked approvers.
  - Offline supervisor approval for discount overrides in `record_sale`.
  - Offline supervisor approval for void overrides in `void_sale`.
  - Offline supervisor approval for expense limits in `record_expense`.
  - Rejection of offline approvals from locked approvers.
  - `op.refused` audit log generation upon rejected sync operations.
- All 30 database test files passed (3,213 tests total).
