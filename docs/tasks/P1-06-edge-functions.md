# P1-06 Edge Functions: create_user, invite_user
Plan: §5, §15 Login.
- `create_user`: caller JWT verified; superadmin any role, manager only cashiers for own stores. Cashier gets synthetic email `<username>.<slug>@pos.invalid` and a password set by the admin. Creates auth user + profile + location assignment via RPC, rolls back on failure.
- `invite_user`: superadmin invites superadmin/admin/warehouse by real email.
- Service role key only inside functions (env), never in client.
- Tests: Deno tests for validation and permission refusal; one end-to-end run against local stack.
Done when: superadmin creates a cashier and assigns a store via the function (Phase 1 Done-when).
