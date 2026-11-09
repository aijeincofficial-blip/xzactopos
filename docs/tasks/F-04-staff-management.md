# F-04: Staff Management in React

Source plan: `docs/tasks/F-00-overview-full-mode.md` Card F-04.
Full mode is React-first: staff onboarding, invitations, multi-store assignment, positions, and supervisor PIN management live in `apps/client` at `/app/users` (permission: `users.manage`).

## Scope & Capabilities

1. **Staff Onboarding & Creation**:
   - **Cashier Accounts**: Direct cashier creation with username, full name, initial password, and mandatory store assignment. Cashiers sign in with their store code/slug (`<username>.<slug>`).
   - **Invite by Email**: Superadmins can invite managers, supervisors, warehouse staff, or co-owners via email using the `invite_user` Edge Function. The invitee receives a secure link to set their own password.
2. **Role & Store Scoping**:
   - Role management (`superadmin`, `admin`, `warehouse`, `cashier`).
   - Store & warehouse assignments with role-appropriate location type restrictions.
   - Positions for store admins: `manager` vs `supervisor` (required when assigned to a store).
3. **Supervisor & Cashier PIN Management**:
   - **Clear / Reset PIN**: Superadmin can clear/reset any staff member's PIN via `clear_user_pin` RPC when forgotten or locked.
   - **Change My PIN**: Current user can set or update their 4 to 8-digit supervisor PIN via `set_my_pin` RPC, requiring current PIN verification when already set.
4. **Filtering, Search & Quota Awareness**:
   - Filter by Role, Location/Store, and Active/Inactive status.
   - Real-time search across usernames and full names.
   - Quota capacity tracker displaying current staff vs `tenant_limits.max_users`.
5. **Localization**:
   - 100% key parity between English (`en/admin.json`) and Filipino (`fil/admin.json`).

## Server Interactions

- `create_user` (Edge function): Cashiers with synthetic email (`<username>.<slug>@pos.invalid`).
- `invite_user` (Edge function): Real email invitations for superadmin, admin, warehouse.
- `set_user_role` (RPC): Changes role, automatically resetting invalid location assignments.
- `assign_location` / `revoke_location` (RPCs): Manages store & warehouse assignments with positions.
- `set_user_active` (RPC): Activates or deactivates user with last-superadmin protection.
- `clear_user_pin` (RPC): Superadmin resets a user's `profiles.pin_hash` to NULL.
- `set_my_pin` (RPC): Sets/updates PBKDF2 hash in `profiles.pin_hash`.
