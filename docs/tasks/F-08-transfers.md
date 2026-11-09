# F-08: Warehouse & Inter-Store Stock Transfers

Source plan: `docs/tasks/F-00-overview-full-mode.md` Card F-08.
Full mode is React-first: Warehouse and retail inter-store stock transfers live in `apps/client` at `/app/transfers` (permissions: `transfer.manage` or `stock.adjust_store`).

## Scope & Capabilities

1. **Database Schema & Stock Math**:
   - `public.transfers`: Header tracking transfer lifecycle (`draft` -> `shipped` -> `received` or `cancelled`), origin and destination locations, manifest numbering (`TRF-YYMMDD-NNNN`), timestamps, actors, and discrepancy flag (`has_discrepancy`).
   - `public.transfer_items`: Line items specifying `variant_id`, `qty_shipped`, and `qty_received`.
   - `stock_movements_type_check` extended with `'transfer_out'` and `'transfer_in'`.
   - Stock deduction occurs upon shipment: snapshotted origin `stock_levels.avg_cost` recorded as `unit_cost` on `transfer_out` without mutating origin unit cost.
   - Stock receipt blends cost at destination: `transfer_in` calls `public.stock_blend_cost()` to update destination `stock_levels.avg_cost` based on shipped unit cost and received quantity.
   - Discrepancy handling: Counted vs shipped difference automatically detected, stored on `qty_received`, flagged on transfer header, and recorded in audit log.

2. **Security & Permissions**:
   - Tenant isolation and RLS policies enforced on both `transfers` and `transfer_items`.
   - Access restricted to superadmins and staff assigned to either the origin or destination location.
   - Cashiers strictly blocked from viewing or executing transfer operations.
   - Secure RPCs:
     - `create_transfer(p_from_location_id, p_to_location_id, p_notes, p_items, p_ship_now)`
     - `ship_transfer(p_transfer_id)`
     - `receive_transfer(p_transfer_id, p_items)`
     - `cancel_transfer(p_transfer_id, p_reason)` (draft transfers only)

3. **React UI (`apps/client`)**:
   - Route `/app/transfers` with navigation guard (`requiresAny("transfer.manage", "stock.adjust_store")`).
   - App layout navigation link with multi-permission check and `fullOnly: true` (hidden from Solo mode).
   - Filterable transfers list by status (`all`, `draft`, `shipped`, `received`, `cancelled`) and location.
   - Modal for creating drafts or immediate dispatch with origin/destination dropdowns and line item builder.
   - Modal for receiving transfers with line-by-line counted quantities and discrepancy warnings.
   - Printable transfer manifest dialog (`window.print()`) complete with dispatch/receipt signatures and location addresses.
   - Modal for cancelling draft transfers with audit reason capture.

4. **Localization & Verification**:
   - 100% key parity between English (`en/admin.json`, `en/errors.json`) and Filipino (`fil/admin.json`, `fil/errors.json`).
   - Complete pgTAP suite (`027_transfers.test.sql`) verifying permissions, isolation matrix, shipment deduction, receipt cost blending, and cancellation.
   - All unit tests, schemas, typecheck, and lint pass with 0 errors.
