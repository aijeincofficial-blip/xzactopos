# F-05: Shifts and the Drawer (X & Z Reports)

Source plan: `docs/tasks/F-00-overview-full-mode.md` Card F-05.
Full mode is React-first: Drawer reconciliation, per-cashier shift records, X-reports (interim shift reading), and Z-reports (final shift close) live in `apps/client` at `/app/day-close` (permission: `shift.manage`).

## Scope & Capabilities

1. **Shift Drawer Reconciliation**:
   - Stores opening cash float (`day_closes.opening_cash`).
   - Automatically computes expected cash in drawer based on:
     - `opening_cash`
     - `cash_sales`
     - `cash_utang_payments` (collected customer debt)
     - `cash_expenses` (paid out of drawer)
   - Records counted cash and captures over/short differences (`difference = counted_cash - expected_cash`).
2. **X-Report (Interim Mid-Shift Reading)**:
   - Cashiers and supervisors can inspect the active drawer state without closing or resetting the drawer.
   - Non-resetting interim slip showing:
     - Store identity, date/time, and active cashier
     - Current expected cash in drawer
     - Completed transaction counts and gross sales
     - Non-cash tenders (GCash, Maya, other e-wallets, utang credit)
   - Formatted for display and browser printing.
3. **Z-Report (Final Shift Close Reading)**:
   - Generated upon drawer close and archived in shift history.
   - Slip showing final counted cash vs expected cash, over/short variance, note/remarks, closed-by cashier name, and supervisor approval (if required).
   - Allows reprinting past Z-reports from any historical shift row.
4. **History & Multi-Store Scoping**:
   - Scoped to active store via `useActiveLocation`.
   - Maps staff UUIDs (`closed_by`, `approved_by`) to human-readable names.
   - Filters past closes by variance (All, Discrepancies only, Balanced only).
5. **Localization**:
   - 100% key parity between English (`en/admin.json`) and Filipino (`fil/admin.json`).
