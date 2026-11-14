# Runbook: Database Backup and Disaster Recovery

## 1. Overview & Policy
On the Supabase free tier, projects do not include automated daily backups or point-in-time recovery (PITR). To protect multi-tenant business data from accidental loss or corruption, this runbook defines backup procedures, retention schedules, and step-by-step restoration instructions.

- **Recovery Point Objective (RPO)**:
  - Scheduled: Weekly full backup (Sundays 02:00 UTC via GitHub Action `.github/workflows/backup.yml`).
  - Operational: On-demand manual backup before any major schema migration or maintenance event.
- **Recovery Time Objective (RTO)**: Under 30 minutes to restore a functional database from a compressed backup file.
- **Retention**: Weekly backups are retained for 30 days as encrypted GitHub Action artifacts or off-site archives.

---

## 2. Taking an On-Demand Backup

### Method A: Local Stack Backup Script
Run the automated backup script from the workspace:
```bash
node scripts/backup-db.mjs
```
This generates a timestamped SQL dump in the `backups/` directory (e.g. `backups/backup-2026-11-08T14-00-00-000Z.sql`).

### Method B: Remote Database via `pg_dump`
To take a compressed full backup of a remote Supabase production or staging database:
```bash
# Set your connection URI (with session/transaction pooler or direct connection)
export DB_URL="postgresql://postgres:[PASSWORD]@db.[PROJECT_REF].supabase.co:5432/postgres"

# Create timestamped dump
TIMESTAMP=$(date -u +%Y%m%d_%H%M%SZ)
pg_dump "$DB_URL" --clean --if-exists --no-owner --no-privileges | gzip > "backups/backup_${TIMESTAMP}.sql.gz"
```

Verify that the created archive is non-empty:
```bash
ls -lh backups/backup_*.sql.gz
```

---

## 3. Automated Keep-Alive Ping (Preventing Idle Project Pause)
Supabase free tier automatically pauses projects after 7 consecutive days of database inactivity.
- **Automated Workflow**: `.github/workflows/keep-alive.yml` runs every 3 days at 00:00 UTC.
- **Lightweight Health Endpoint**: Calls the `public.health_ping()` RPC via HTTPS using `SUPABASE_SERVICE_ROLE_KEY` (`anon` is revoked; regular authenticated users must pass `assert_active_user()`; for new `sb_secret_...` keys send only `apikey`, omit `Authorization: Bearer`):
  ```bash
  curl -X POST "https://[PROJECT_REF].supabase.co/rest/v1/rpc/health_ping" \
    -H "apikey: [SERVICE_ROLE_KEY]" \
    -H "Authorization: Bearer [SERVICE_ROLE_KEY]" \
    -H "Content-Type: application/json"
  ```
- **Expected Response**:
  ```json
  {
    "ok": true,
    "status": "healthy",
    "timestamp": "2026-11-08T14:00:00.000000Z",
    "version": "1.0.0"
  }
  ```

---

## 4. Restoration Procedure

### Step 1: Pre-Restoration Verification
1. Confirm the target database project is active and reachable.
2. If restoring to a fresh local stack, ensure containers are initialized:
   ```bash
   pnpm exec supabase start
   ```

### Step 2: Applying the Backup
Decompress and pipe the backup file into `psql`:
```bash
# If using a compressed archive:
gunzip -c backups/backup_YYYYMMDD_HHMMSSZ.sql.gz | psql "$TARGET_DB_URL"

# Or if restoring a local dump:
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -f backups/backup-YYYY-MM-DDTHH-MM-SS.sql
```

### Step 3: Post-Restoration Invariant & Integrity Checks
Run the following verification queries in `psql`:

1. **Verify Database Storage Metrics**:
   ```sql
   select public.get_storage_metrics();
   ```
   Ensure `ok` is `true` and table list is populated.

2. **Verify Warehouse Bin Stock Invariants**:
   For each active warehouse location:
   ```sql
   select * from public.check_bin_stock_invariant('<warehouse_id>');
   ```
   Confirm all rows report `is_valid = true` and `diff = 0`.

3. **Verify Tenant Isolation**:
   Execute the test suite to confirm RLS policies:
   ```bash
   pnpm test:db
   ```

---

## 5. Storage Quota Management & Data Archival

The Supabase free tier imposes a strict 500 MB database size limit.
- **Monitoring**: Check live usage anytime in the Web Admin settings under "Database & Storage Quota", or via RPC:
  ```sql
  select (public.get_storage_metrics() ->> 'used_mb') as used_mb,
         (public.get_storage_metrics() ->> 'status') as status;
  ```
- **Threshold Alerts**:
  - `status = 'warning'`: Storage is $\ge 70\%$ (350 MB). Review table sizes and run archival maintenance.
  - `status = 'critical'`: Storage is $\ge 90\%$ (450 MB). Immediate archival required or upgrade to Pro.
- **Pruning Stale Processed Ops & Expired Approvals**:
  To clean up idempotency op records and expired supervisor approvals older than 30 days:
  ```sql
  select public.archive_processed_ops(30);
  ```
