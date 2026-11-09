# F-09: Warehouse Bins, Zones, Put-away, and Pick Lists

## 1. Overview
In full warehouse operations, inventory is not stored in an amorphous lump. Items live in designated physical locations: zones (e.g. Receiving, Storage, Staging, Cold Storage), aisles, racks, shelves, and bin positions. Card F-09 implements warehouse bin tracking, walking-route pick lists for transfer fulfillment, automated put-away, and mathematical inventory invariant validation between bin totals and overall warehouse stock levels.

## 2. Database Schema
Migration: `supabase/migrations/20261108002600_warehouse_bins.sql`

### 2.1 Tables
- **`warehouse_zones`**:
  - Code, name, type (`receiving`, `storage`, `picking`, `staging`, `quarantine`, `damaged`).
  - Scoped to tenant and warehouse location.
- **`bins`**:
  - Bin identifier (`code`), zone assignment (`zone_id`), physical coordinates (`aisle`, `rack`, `shelf`, `position`), type (`pallet`, `shelf`, `floor`, `bin`), and optional capacity limit (`max_qty`).
  - Unique per `(tenant_id, warehouse_id, upper(code))`.
- **`bin_stock_levels`**:
  - Real-time stock quantity per `(bin_id, variant_id)`.
  - Maintained automatically by triggers on `stock_movements`.
- **`pick_lists`**:
  - Generated for draft transfers, allocating items to bins in walking-route order (`aisle` -> `rack` -> `shelf` -> `position`).
  - Statuses: `pending`, `in_progress`, `completed`, `cancelled`.
- **`pick_list_items`**:
  - Specific bin allocations with `qty_requested`, `qty_picked`, and `short_reason`.

### 2.2 Movement Hooks & Triggers
- **`stock_movements.bin_id`**: Foreign key to `bins(id)`.
- **`set_stock_movement_bin()` trigger**:
  - When `bins_enabled = true` on a warehouse and a movement has no `bin_id`:
    - Inbound receipts automatically route to the warehouse's default `RECEIVING` bin.
    - Outbound transfer shipments (`transfer_out`) automatically deduct from the warehouse's default `STAGING` bin.
- **`apply_stock_movement()` trigger**:
  - Updates `bin_stock_levels` on every movement referencing a `bin_id`.
  - Internal bin movements (`type = 'bin_move'`) update bin levels without perturbing overall warehouse `stock_levels`.

### 2.3 The Bin Stock Invariant
For any warehouse where `bins_enabled = true`:
$$\sum_{\text{bins}} \text{bin\_stock\_levels.qty\_on\_hand} = \text{stock\_levels.qty\_on\_hand}$$
The function `check_bin_stock_invariant(p_warehouse_id)` audits all variants and returns any discrepancies.

## 3. Database RPCs
- **`enable_warehouse_bins(p_warehouse_id)`**:
  - Validates location is a warehouse.
  - Provisions default `RCV` (Receiving), `STG` (Staging), and `GEN` (General Storage) zones.
  - Provisions default `RECEIVING`, `STAGING`, and `A-01-1` bins.
  - Migrates all existing non-zero `stock_levels` into the `RECEIVING` bin so the invariant holds immediately.
- **`check_bin_stock_invariant(p_warehouse_id)`**:
  - Returns `variant_id, sku, warehouse_qty, bins_qty, diff, is_valid`.
- **`upsert_warehouse_zone` & `upsert_warehouse_bin`**:
  - RBAC protected: allows `superadmin`, `admin`, `warehouse` roles; blocks cashiers.
- **`list_warehouse_bins` & `list_bin_stock`**:
  - Fetches bins sorted by walking route coordinates with item counts and total quantities.
- **`move_bin_stock` / `execute_putaway`**:
  - Atomically deducts from source bin and credits destination bin within the same warehouse.
  - Validates source bin has sufficient quantity (`insufficient_bin_stock`).
- **`generate_pick_list(p_transfer_id)`**:
  - Generates walking-route-ordered pick list for draft transfers.
- **`confirm_pick_item(p_pick_list_id, p_item_id, p_qty_picked, p_short_reason)`**:
  - Moves picked units from the storage bin to the `STAGING` bin via `move_bin_stock`.
  - When all items are picked, advances pick list status to `completed`.

## 4. Frontend Client Implementation
- **API Client**: `apps/client/src/lib/bins-api.ts`
- **UI View**: `apps/client/src/routes/bins.tsx`
  - Warehouse switcher (for multi-warehouse organizations).
  - Enable Bins callout with one-click setup.
  - KPI cards: Total Bins, Occupied Bins, Total Units, Invariant Health badge.
  - Zone filtering dropdown.
  - Dialogs for Add Zone, Add Bin, Put-away / Move Stock, and View Bin Contents.
- **Navigation & Routing**:
  - Route `/bins` registered in `apps/client/src/router.tsx`.
  - Nav entry in `apps/client/src/routes/app-layout.tsx` for authorized warehouse staff and managers.
- **Locales**: Full 1:1 parity between `en/admin.json` and `fil/admin.json`.

## 5. Verification
- **pgTAP Test Suite**: `supabase/tests/031_warehouse_bins.test.sql` (30 tests passing).
- **Tenant Isolation Matrix**: `supabase/tests/004_tenant_isolation_matrix.test.sql` covers all 5 new bin tables.
- **Typecheck & Lint**: All client packages typechecked and passing.
