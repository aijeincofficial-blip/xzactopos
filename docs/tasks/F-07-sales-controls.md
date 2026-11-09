# F-07: Sales Controls & Role-Based Permissions

Source plan: `docs/tasks/F-00-overview-full-mode.md` Card F-07.
Implements per-line and cart discount thresholds by role, cashier void rules (own same-day sale below threshold or requiring supervisor PIN authorization), tenant sales control settings, and a reusable supervisor PIN authorization dialog in React.

## Scope & Capabilities

1. **Tenant Settings for Sales Controls**:
   - `max_cashier_discount_percent` (integer, default 10%): Maximum percentage discount a cashier can grant on a sale without supervisor PIN authorization.
   - `max_cashier_void_amount` (bigint, default 50,000 minor units / ₱500.00): Maximum sale total a cashier can cancel without supervisor PIN authorization when cashier voids are permitted.
   - `cashier_can_void_own` (boolean, default false): Controls whether cashiers may void their own same-day sales without supervisor authorization up to the threshold. Defaults to `false` for backwards compatibility with solo test suites.
   - Managed in React Admin at `/app/settings`.

2. **Supervisor Approval Infrastructure**:
   - `supervisor_approvals` extended to support `'sale_discount'` and `'void_sale'` actions.
   - `list_store_approvers(p_location_id)`: Secure RPC returning active staff members assigned to the store as `supervisor`, `manager`, or tenant `superadmin`/`admin`.
   - `approve_supervisor_action`: Validates candidate's PBKDF2 PIN hash with rate-limiting, issuing a 5-minute single-use approval token.
   - `consume_supervisor_approval`: Atomic validation and consumption helper preventing token reuse, tenant leakage, or parameter tampering.

3. **Discount Threshold Enforcement**:
   - In `op_record_sale`, cashier discounts exceeding `max_cashier_discount_percent` require a valid `sale_discount` approval token.
   - Store managers, store supervisors, and tenant superadmins/admins bypass the threshold and can grant arbitrary discounts directly.
   - Line-item discounts and overall cart discounts are aggregated to evaluate against the threshold.

4. **Void Rules & Permissions**:
   - In `op_void_sale`, cashiers can only void their own sales created on the current date.
   - If `cashier_can_void_own` is disabled, cashier voids always require a valid `void_sale` supervisor approval token.
   - If `cashier_can_void_own` is enabled, cashier voids up to `max_cashier_void_amount` can proceed directly; voids above the threshold require a valid `void_sale` supervisor approval token.
   - Cashiers can never void sales created by another cashier or on previous dates without supervisor escalation.
   - Managers and owners retain full direct void privileges for sales within their assigned stores.

5. **Client UI & Reusable Components**:
   - `SupervisorPinDialog`: Modal dialog prompting the cashier to select an active store supervisor/manager and enter the supervisor's 4–8 digit PIN.
   - `SellScreen` (`/app/sell`): Evaluates discount percentage prior to charging. If threshold is exceeded, triggers `SupervisorPinDialog` and passes the generated `approval_id` with `op_record_sale`.
   - `SalesScreen` (`/app/sales`): Evaluates cashier void criteria prior to cancelling. Triggers `SupervisorPinDialog` when required and passes `approval_id` with `op_void_sale`.
   - `SettingsScreen` (`/app/settings`): "Sales Controls & Permissions" card with inputs for discount percentage, void limit, and cashier void toggle.

6. **Localization**:
   - 100% key parity between English (`en`) and Filipino (`fil`) in `admin.json` and `errors.json`.

## Server Interactions & RPCs

- `list_store_approvers`: Fetches eligible supervisors/managers for a store location.
- `approve_supervisor_action`: Authorizes action via supervisor PIN.
- `op_record_sale`: Enforces discount limits and consumes approval when required.
- `op_void_sale`: Enforces void rules and consumes approval when required.
- `update_tenant_settings`: Updates sales control thresholds and cashier permissions.

## Test Verification

- `supabase/tests/029_sales_controls.test.sql`: 28 pgTAP tests covering settings defaults, approvers listing, discount thresholds, PIN verification, single-use tokens, cashier void limits, and audit logs.
- Unit and client test suites: `apps/client` tests pass (10 test files, 66 tests).
