# F-12: Platform Administration, Multi-Tenant Metrics, and Operator Dashboard

## 1. Overview
XZACTO POS is a multi-tenant platform serving multiple retail businesses. While tenant isolation and role-based access control (RBAC) ensure businesses cannot see each other's data, platform operators and SaaS system administrators require a dedicated control plane to monitor global system health, supervise tenant accounts, manage billing plans and quota ceilings, and provision new business tenants.

Card F-12 implements the complete platform administration capability: database authorization functions, cross-tenant analytical RPCs, tenant lifecycle state machines, audit logging, a dedicated platform API client, an operator dashboard UI, navigation integration, and full English/Filipino localization.

---

## 2. Security & Database Implementation
Migration: `supabase/migrations/20261108002900_platform_admin.sql`

### 2.1 Operator Authorization (`assert_platform_admin`)
- Validates that the executing caller is either:
  1. `service_role` (PostgreSQL internal admin / automation worker), or
  2. An authenticated user registered in `public.platform_admins`.
- Revoked from `public` and `anon`; granted to `authenticated`.
- Raises `42501 (forbidden)` if the caller is not a platform administrator.
- `public.get_my_access()` is extended to return `'is_platform_admin', public.is_platform_admin()`.

### 2.2 Global Telemetry (`get_platform_metrics`)
- Aggregates system-wide figures across all tenants:
  - `total_tenants`: count of all non-deleted tenants.
  - `active_tenants`: count of tenants in `'active'` state.
  - `suspended_tenants`: count of tenants in `'suspended'` state.
  - `pro_tenants` / `free_tenants`: subscription tier breakdown.
  - `total_users`: total user profiles registered across all tenants.
  - `total_sales_count`: global completed sales transactions count (`voided_at is null`).
  - `total_gross_sales`: global gross revenue across all businesses.
  - `storage`: embeds storage quota telemetry (`total_bytes`, `used_mb`, `limit_mb`, `percent_used`, `status`) to monitor the free-tier 500 MB budget.
- Security: Protected by `assert_platform_admin()`.

### 2.3 Tenant Roster & Filter (`list_platform_tenants`)
- Returns cross-tenant list of businesses matching search parameters (`p_search`, `p_status`).
- Computes per-tenant rollups:
  - Active store and warehouse location counts.
  - Active user count.
  - Lifetime gross sales volume.
  - Subscription plan (`free` vs `pro`) and quota limits JSON.
  - Account status (`active`, `suspended`, `archived`) and creation timestamp.
- Security: Protected by `assert_platform_admin()`.

### 2.4 Tenant Lifecycle & Quotas
- **Status Management (`set_platform_tenant_status`)**:
  - Updates tenant status (`active` vs `suspended`).
  - Records an audit log entry (`action = 'platform.tenant_status'`) capturing old status, new status, and operator reason.
- **Plan & Quota Ceilings (`set_platform_tenant_plan`)**:
  - Updates tenant plan (`free` vs `pro`) and custom limits object (`stores`, `registers`, `users`, `products`).
  - Records an audit log entry (`action = 'platform.tenant_plan'`) capturing previous settings, new plan, and limits.
- **Provisioning (`provision_tenant`)**:
  - Granted to `authenticated` so authorized platform administrators can provision new tenant businesses and initialize the owner profile.

---

## 3. Database Verification
pgTAP Test Suite: `supabase/tests/034_platform_admin.test.sql` (21 tests)

- **Security Gate Tests**:
  - Verifies `anon` cannot call any platform admin RPCs (`42501`).
  - Verifies standard tenant cashiers and tenant superadmins are denied access (`42501`).
- **Telemetry & Discovery Tests**:
  - Verifies platform admin can fetch platform metrics with complete structural fields.
  - Verifies searching tenants by name/slug and filtering by status (`active` / `suspended`).
- **Lifecycle & Quota Tests**:
  - Verifies suspending an active tenant and confirming status change.
  - Verifies audit log creation with reason on status change.
  - Verifies upgrading tenant plan from `free` to `pro` with custom limits (`stores`, `registers`, `products`).
  - Verifies audit log creation on plan change.

---

## 4. Frontend Client Implementation

### 4.1 Client API (`apps/client/src/lib/platform-api.ts`)
- TypeScript models: `PlatformMetrics`, `PlatformTenant`, `PlatformTenantLimits`.
- API Callers:
  - `fetchPlatformMetrics()`: calls `get_platform_metrics`.
  - `fetchPlatformTenants(search, status)`: calls `list_platform_tenants`.
  - `setPlatformTenantStatus(tenantId, status, reason)`: calls `set_platform_tenant_status`.
  - `setPlatformTenantPlan(tenantId, plan, limits)`: calls `set_platform_tenant_plan`.
  - `provisionPlatformTenant(name, slug, currency, timezone, ownerUserId, ownerUsername)`: calls `provision_tenant`.

### 4.2 Platform Administration Route (`apps/client/src/routes/platform.tsx`)
- **KPI Summary Cards**:
  - Total Tenants with active vs. suspended breakdown.
  - Pro Subscriptions ratio.
  - Global Registered Users.
  - Platform Database Storage meter with progress bar and percent used.
- **Search & Filters**:
  - Real-time search query input (tenant name or slug).
  - Status dropdown selector (`All`, `Active`, `Suspended`).
- **Tenants Table**:
  - Lists business name, slug, plan badge (`Free` vs `Pro`), status badge, store/warehouse count, user count, gross sales formatted with currency, and creation date.
  - Action buttons: "Plan & Limits" and "Suspend" / "Activate".
- **Action Dialogs**:
  - **Status Dialog**: confirmation prompt requiring an operator reason before suspending or reactivating a business.
  - **Plan & Limits Dialog**: switch between Free and Pro tiers, with granular ceiling inputs for maximum stores, registers, users, and catalog products.
  - **Provision Tenant Dialog**: modal to create a new business tenant and set up initial owner credentials.

### 4.3 Navigation & Routing
- Route `/app/platform` added in `apps/client/src/router.tsx`, protected with a `beforeLoad` check on `context.access.is_platform_admin`.
- Navigation bar in `apps/client/src/routes/app-layout.tsx` dynamically shows the "Platform" tab only when `access.is_platform_admin` is true.

### 4.4 Localization
- 100% key parity between English (`apps/client/src/locales/en/admin.json`) and Filipino (`apps/client/src/locales/fil/admin.json`).
- All platform KPI titles, table column headers, status badges, actions, dialog strings, and confirmation messages localized.

---

## 5. Verification Summary
- **Database Tests**: 34 test files, 3,551 tests passed (`Result: PASS`).
- **Client Vitest Tests**: 11 test files, 71 tests passed (including locale parity tests).
- **TypeScript Typecheck**: Passed with 0 errors (`packages/sync`, `packages/core`, `apps/client`).
- **ESLint**: Passed with 0 errors.
