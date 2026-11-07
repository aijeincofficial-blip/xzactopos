# P3-01 Stock ledger and sales schema
Goal: the tables a sale needs, safe by RLS, with stock derived and never edited.
- Migration (new file, after `20261108000400`):
  - `stock_movements(id, tenant_id, location_id, variant_id, qty_delta numeric(12,3), type[opening|sale|sale_void], ref_type, ref_id, unit_cost, occurred_at, created_by, created_at)`.
    Append-only: no update/delete for anyone (trigger raises), no client INSERT policy (RPC only). Composite `(tenant_id, id)` FKs as in P2-01.
  - `stock_levels(tenant_id, location_id, variant_id, qty_on_hand, updated_at)` maintained by an AFTER INSERT trigger on movements (upsert and add). No client write privilege.
  - `customers(id, tenant_id, name, phone, updated_at, deleted_at)`; `customer_ledger(id, tenant_id, customer_id, kind[charge|payment|adjust], amount int, sale_id, note, occurred_at, created_at)`
    append-only, amount in base minor units (charge positive, payment negative, so balance = sum).
  - `sales(id, tenant_id, location_id, local_no, status[completed|voided], subtotal, discount, tax, total, customer_id, sold_at, created_by, client_op_id, voided_at, void_op_id)`;
    `unique (tenant_id, local_no)`. `sale_items(id, tenant_id, sale_id, variant_id, qty, unit_price, unit_cost, discount, tax, line_total)`;
    `payments(id, tenant_id, sale_id, method[cash|utang|ewallet], amount, reference)`. `check` that totals are consistent is done in the RPC, not by constraint.
  - RLS: read for active members of the tenant, nothing else; delta-sync indexes `(tenant_id, updated_at, id)` on levels, customers, ledger; tenant-leading indexes everywhere.
- Tests: pgTAP `011_sales_schema.test.sql` (trigger sums, append-only, local_no unique per tenant but reusable across tenants, FK cannot cross tenants); isolation matrix rows for all 7 new tables x 5 roles
  (guard test 003 must stay green); mutation test (loosen one policy, see the matrix fail).
- Done when: `pnpm check` passes. Use Opus.
