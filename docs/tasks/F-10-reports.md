# F-10: Multi-Store Reports & Analytics

Source plan: `docs/tasks/F-00-overview-full-mode.md` Card F-10.
Full mode is React-first: Multi-store reporting, analytics, daily stock snapshots, and CSV exports live in `apps/client` at `/app/reports` (permissions: `reports.store` or `reports.warehouse`).

## Scope & Capabilities

1. **Database Schema & Daily Snapshots**:
   - `public.stock_snapshots_daily`: Daily record of stock levels, unit costs, and inventory valuation per location and variant.
   - `public.snapshot_daily_stock(p_day)` RPC: Computes end-of-day valuation (`qty_on_hand * avg_cost`) across all locations and updates snapshots.
   - Initial snapshot backfilled from current `stock_levels`.
   - Covered by RLS policies and verified in `004_tenant_isolation_matrix.test.sql`.

2. **Multi-Store Analytics RPC (`public.report_multi_store`)**:
   - Fast, rollup-based aggregation reading only `daily_sales_summary`, `daily_item_sales`, `daily_expense_summary`, `daily_service_summary`, and `stock_levels`.
   - Supports tenant-wide overview (all stores & warehouses) or single-location scoping (`p_location_id`).
   - Strict location access verification: non-superadmin users can only view reports for locations they are assigned to.
   - Cashiers locked out (returns empty totals).
   - Generates:
     - Period totals (Net, Gross, Discounts, Tax, COGS, Profit, Margin %, Transaction count)
     - Day-by-day sales trend and payment tender breakdown
     - Top selling products with profit contribution
     - Multi-store comparison table with per-store sales, transactions, and inventory valuation
     - Inventory valuation metrics across all authorized stores and warehouses
     - Inter-store transfer volume and discrepancy metrics
     - Customer utang balances and debtor counts

3. **React Reports UI (`apps/client`)**:
   - Route `/app/reports` guarded by `requiresAny("reports.store", "reports.warehouse")`.
   - App layout navigation with full 1:1 EN/FIL localization (hidden from Solo mode).
   - Location picker: toggle between "All Locations" and individual stores/warehouses.
   - Quick date presets: "Today", "Last 7 Days", "This Month", "Last 30 Days", plus custom date pickers.
   - Executive KPI cards with margin percentages and average ticket size.
   - Multi-store comparison table comparing sales, profits, and stock valuation side-by-side.
   - Visual CSS bar chart displaying daily sales trends with interactive tooltips.
   - Top products leaderboard and tender breakdown (Cash, E-Wallet, Utang).
   - Warehouse transfer activity cards.
   - CSV export capabilities: Daily Sales CSV, Top Products CSV, and Store Comparison CSV.

4. **Localization & Quality Standards**:
   - 100% key parity between English (`en/admin.json`) and Filipino (`fil/admin.json`).
   - Comprehensive pgTAP suite (`028_multi_store_reports.test.sql`) verifying snapshots, multi-store rollups, scoped reporting, and permissions.
   - All 28 database test suites passed (3,161 tests).
   - Monorepo unit tests, typecheck, and lint pass with 0 errors.
