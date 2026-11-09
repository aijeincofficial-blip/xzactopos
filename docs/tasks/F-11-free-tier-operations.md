# F-11: Free-Tier Operations, Quota Guardrails, and Resilience

## 1. Overview
XZACTO POS is designed to run reliably on the Supabase free tier ($500\text{ MB}$ database limit, project auto-pause after 7 days of inactivity, and connection pooler constraints). Card F-11 implements operational tooling, database functions, automated workflows, client-facing storage telemetry, and resilience runbooks to ensure the platform stays healthy, never exceeds storage limits, and remains awake.

## 2. Database Functions & Operations
Migration: `supabase/migrations/20261108002700_free_tier_operations.sql`

### 2.1 Keep-Alive Ping (`health_ping`)
- Lightweight function returning:
  - `ok`: boolean (`true`)
  - `status`: `'healthy'`
  - `timestamp`: current timestamp (`now()`)
  - `database`: database name (`current_database()`)
  - `version`: PostgreSQL version string (`version()`)
- Security: Revoked from `public` and `anon`; granted to `authenticated` users and service role.

### 2.2 Storage Metering (`get_storage_metrics`)
- Inspects `pg_database_size(current_database())` against the 500 MB budget ($524,288,000\text{ bytes}$).
- Returns:
  - `total_bytes`: integer database size.
  - `used_mb`: numeric size in megabytes.
  - `limit_mb`: 500.
  - `percent_used`: numeric percentage of quota used.
  - `status`: `'healthy'` (< 70%), `'warning'` (70%–89%), `'critical'` ($\ge 90\%$).
  - `tables`: JSON array of top 15 largest public tables with table name, byte size, human-readable size (`pg_size_pretty`), and estimated row count from `pg_class.reltuples`.
  - `tenant_stats`: JSON object with tenant-specific record counts (`sales`, `sale_items`, `stock_movements`, `processed_ops`, `audit_logs`).
- Security: Requires `superadmin` or `admin` role; blocks cashiers.

### 2.3 Idempotency & Log Archival (`archive_processed_ops`)
- Prunes stale operations from `processed_ops` older than retention threshold (default 30 days, minimum 7 days safeguard).
- Cleans up expired supervisor approval tokens (`supervisor_approvals`) that are either used or past their `expires_at` with `issued_at` older than retention cutoff.
- Preserves tenant isolation (deletes only the caller's tenant rows, or all tenants if called by service role / maintenance worker).
- Records a `'maintenance.archive'` audit log entry with deleted row counts.
- Returns `{ ops_deleted: integer, approvals_deleted: integer, cutoff: timestamptz }`.

## 3. Automation & Tooling
- **Backup Script (`scripts/backup-db.mjs`)**:
  - Connects using `SUPABASE_DB_URL` or standard PostgreSQL environment variables (`PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE`).
  - Dumps database to `backups/backup-<ISO_TIMESTAMP>.sql`.
- **Keep-Alive GitHub Action (`.github/workflows/keep-alive.yml`)**:
  - Scheduled via cron to run every 3 days (`0 4 */3 * *`).
  - Executes RPC `health_ping()` over REST API using `SUPABASE_SERVICE_ROLE_KEY` to prevent project pausing.
- **Weekly Backup GitHub Action (`.github/workflows/backup.yml`)**:
  - Scheduled via cron to run every Sunday at 02:00 UTC (`0 2 * * 0`).
  - Dumps PostgreSQL schema and data, compressing into artifacts with 30-day retention.
- **Disaster Recovery Runbook (`docs/runbooks/backup-and-restore.md`)**:
  - Step-by-step documentation for backup creation, automated keep-alive, restore verification, point-in-time recovery, and 500 MB quota triage.

## 4. Frontend Client Implementation
- **Client API (`apps/client/src/lib/maintenance-api.ts`)**:
  - `fetchStorageMetrics()`: calls `get_storage_metrics` RPC.
  - `runArchiveMaintenance(daysToKeep)`: calls `archive_processed_ops` RPC.
  - `checkHealthPing()`: calls `health_ping` RPC.
- **Settings UI (`apps/client/src/routes/settings.tsx`)**:
  - "Database & Storage Quota" section visible to administrators.
  - Visual quota bar with health status badge (`Healthy`, `Warning`, `Critical`).
  - One-click "Test Keep-Alive Ping" button with live status and timestamp feedback.
  - One-click "Prune Stale Ops (30d+)" maintenance action with toast notification.
  - Table breakdown showing the largest database tables and row estimates.
- **Localization**:
  - Fully translated in English (`en/admin.json`) and Filipino (`fil/admin.json`) with exact 1:1 key parity.

## 5. Verification
- **pgTAP Test Suite (`supabase/tests/032_free_tier_operations.test.sql`)**:
  - 19 test assertions covering health ping security, storage metrics calculation, RBAC authorization, archive pruning logic, min-retention enforcement, and audit logging.
  - All 32 database test suites passed (`3512 tests`).
- **Client Tests & Types**:
  - `apps/client test`: Passed (10 test suites, 66 tests).
  - Locale parity test: Passed (12 tests).
  - TypeScript typecheck: Passed across `core`, `sync`, and `client`.
