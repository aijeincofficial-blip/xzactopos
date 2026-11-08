# W-03: Stock, Products, Categories, Tingi Repack, Expiry Dates, and CSV Import/Export

## 1. Overview
W-03 provides the comprehensive web-based catalog, category management, inventory operations, and item configuration for the React admin client (`apps/client`). In addition to standard product CRUD, stock in, and counting, it implements:
1. **Category Management**: Full hierarchical category taxonomy (CRUD, parent categories, category assignment to products, and safe auto-detachment on archival).
2. **Tingi / Repack Pack-to-Piece Conversions**: Configuration of packs that break into loose pieces with ratio, opening packs with integer-safe cost blending, and voiding pack openings.
3. **Expiry Dates & Batch Tracking**: Earliest shelf expiry tracking per product, quick updates/clearing, inline date capture on stock-in receipts, and visual "Expired" / "Expiring soon" alerts.
4. **Product CSV Import & Export**: One-click catalog export to CSV with proper quoting and full spreadsheet import with client-side syntax/data validation and automatic batch creation.

## 2. Database Schema & RPCs
- Migration: `supabase/migrations/20261108002800_catalog_categories.sql`
- **`public.upsert_category(p_op_id uuid, p_category jsonb)`**:
  - Validates tenant, role (`catalog_write_mode() = 'full'`), name length (1..80), and parent hierarchy (no self-parenting, tenant isolation).
  - Creates or updates category, writes `'category.create'` / `'category.update'` audit log, and claims op idempotently.
- **`public.archive_category(p_op_id uuid, p_category_id uuid)`**:
  - Soft-deletes category (`deleted_at = now()`).
  - Automatically safely clears `category_id = null` for all active products referencing the archived category.
  - Writes `'category.archive'` audit log.
- Security:
  - Revoked from `public, anon`; granted to `authenticated`.
- pgTAP Test Suite: `supabase/tests/033_catalog_categories.test.sql` (18 tests: RBAC, validation, idempotency, product detachment, audit logs).

## 3. Client Implementation
- **Stock & Catalog API (`apps/client/src/lib/stock-api.ts`)**:
  - `fetchCategories()`, `upsertCategory()`, `archiveCategory()`.
  - `fetchStockExpiries()`, `setExpiry()`, `getExpiryStatus()`.
  - `setTingiLink()`, `openPack()`, `voidOpenPack()`, `fetchRecentConversions()`.
  - `toProductRows()` mapping categories, tingi links, and expiry dates.
- **CSV Processing (`apps/client/src/lib/csv-helper.ts`)**:
  - `exportProductsCsv()`, `downloadCsv()`.
  - `parseCsv()` with RFC 4180 quotation and comma escaping.
  - `parseAndValidateImport()` with line-by-line validation for name, price, cost, tax, stock on hand, and expiry.
- **UI Routes & Modals (`apps/client/src/routes/products.tsx`)**:
  - **Category Filter & Dialog**: Dropdown filtering, top-level category badges, and modal category management.
  - **Tingi Repack UI**: Pack checkbox and piece ratio configuration in `ProductForm`; dedicated "Open Pack" conversion panel in `StockPanel` with recent openings and void action.
  - **Stock Expiry UI**: Receipt date capture, quick set/clear expiry date, and status badges (`⚠️ Expired`, `⏳ Expiring soon`).
  - **CSV Export & Import Dialog**: Download catalog with one click, CSV upload preview with validation error reporting and batch progress bar.
- **Localization**:
  - 100% key parity in English (`en/admin.json`) and Filipino (`fil/admin.json`).

## 4. Verification
- `supabase test db supabase/tests/033_catalog_categories.test.sql`: 18/18 tests passed.
- `supabase test db supabase/tests/003_rls_guard_and_policies.test.sql`: 33/33 tests passed (anon privileges strictly preserved).
- `vitest src/lib/stock-api.test.ts`: 4/4 tests passed.
- `vitest src/lib/csv-helper.test.ts`: 3/3 tests passed.
- `vitest src/i18n/locales.test.ts`: 12/12 tests passed.
- All workspace tests: 11 test files, 71 tests passed.
