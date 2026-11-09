# F-04m: Staff on the phone

Part of priority 3 (cashier-ready Mobile Full). Web staff management stays as in `F-04-staff-management.md`; this is the small phone part the owner needs at the till.

## Scope (done 2026-11-09)
- **More > Staff** for the owner, managers and the Solo owner (not cashiers or warehouse staff). Online only: nothing is kept in the local database.
- List of everyone: name, role, store, "Off" when switched off, and for cashiers the name they sign in with (`username.storecode`).
- **Add a cashier**: username, name, password (8+), store (asked only when there is more than one). Uses the existing `create_user` function, so the server still decides who may add whom.
- **Switch off / on** (`set_user_active`; no menu on your own row) and **Clear PIN** (`clear_user_pin`, owner only).
- **Sign-in on the phone** now takes `username.storecode` as well as an email (it becomes `username.storecode@pos.invalid`, the address `create_user` makes). Before, a cashier had to type the whole synthetic address.
- Refusals are explained: duplicate name, bad input, not allowed, cannot switch yourself off, no room on the plan, no signal.

## Not done
Changing a role, assigning more stores or positions, inviting by email, resetting a cashier's password. These stay on the web (`/app/users`).

## Checks
- `test/staff_screen_test.dart`, 12 tests; mutation (managers could clear a PIN) was caught. Flutter 545 tests, analyzer clean.
- The exact calls the phone makes were run against the local server as the Solo owner (`scratchpad/staff_probe.mjs`): list, stores, create (201), duplicate (409 `duplicate`), switch off, clear PIN, and the new cashier signs in with the synthetic address.
- Not run on the emulator screen by hand; the widget tests drive the same screens.
