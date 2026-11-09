# Mobile Solo emulator proof (priority 1) - 2026-11-09

Run on the Android 13 emulator (`Pixel_4_API_33`, debug build of `main` after the F-13 work) against the local Supabase stack. A new account (`tindera.p1@example.test`) was created through the app (sign-up, name the store), so onboarding was exercised for real. The products and opening stock were added through the server RPCs to save typing; everything else was done on the phone, and every result was compared with the server's rows. English UI.

This closes the "not checked on a device" list of `P8-13-acceptance.md`, except the items marked **not covered**.

| Feature | Result |
| --- | --- |
| Sign up, name the store, home | **Pass.** Account and `solo-...` business created; catalog and stock pulled to the phone on a sync tap |
| Expiry dates | **Pass.** "Set expiry date" on a stock row, "Expires in 3 days", an "Expiring (1)" filter and a badge on the Stock tab; the server has `stock_expiry` 2026-11-12 |
| Tingi / repack | **Pass.** "Sold by piece too" (20 pieces, name, price) created the piece product; "Open a pack" showed "That makes 20 x Yosi piraso"; stock became 2 packs + 20 pieces on the phone and on the server; the piece's average cost is 700 = 14000 / 20 exactly |
| Selling, offline, then reconnect | **Pass.** With airplane mode on: 3 pieces + 1 sardinas, cash 100, change 45, receipt `UJK-261109-0001`, "Not sent yet", stock left 17 / 5. After reconnecting the receipt number became the server's `MAIN-261109-0001`, "Not sent yet" disappeared, and the server stock matched |
| Utang on a sale, customer added in the sale | **Pass** (see finding 1) |
| Utang pay-by date | **Pass.** Setting a past date showed "3 days overdue", the Utang tab got a badge, Change date / Clear date appeared |
| Send statement | **Pass.** The Android share sheet opened with "Utang statement: Aling Nena..." |
| Expenses | **Pass.** 125 electric/water; the server has 12500 centavos, category `utilities` |
| Reports with expenses | **Pass.** Sales 103.00, cash / e-wallet / utang split 55 / 0 / 48, "Expenses (not stock): 125.00", profit after expenses -97.00, estimated profit 28.00 (checked by hand against the cost snapshots on the server) |
| Day close with opening cash | **Pass.** Cash that should be in the drawer: -70.00 before; with a sukli of 200 it became 130.00; counting 125 showed "Short by 5.00"; saved; the server has opening 20000, expected 13000, counted 12500, difference -500 |
| Load and e-wallet | **Pass.** GCash cash-in 500 with a 10 fee: fees earned 10.00, wallet float -500.00 "Needs a top-up"; the server's `wallet_float` is -50000 |
| CSV export | **Pass.** More > Import and export > Sales opened the share sheet with `sales-2026-11-09.csv` |
| Pin a favorite | **Pass.** Long-press on a Sell tile: "Pinned Yosi pack to the top", pin icon, tile moved first |
| Top sellers order on Sell | **Pass.** After the first sale the sold items moved to the top |

**Not covered:** supervisor PIN approval (it needs a second user with a PIN; a solo owner is the superadmin and never needs it, so it belongs to a Full-mode run), the camera barcode decode (the emulator's camera scene has no barcode), a real receipt printer, Filipino text on these screens (the previous run used Filipino), the offline Utang payment, and performance on a release build.

## Findings
1. **Fixed: the "Choose who owes" button hid under the keypad.** After "All on utang" (or part payment) the customer button sat below the visible list on a normal phone, and Finish sale stayed disabled with no hint, until the user scrolled. The payment screen now scrolls the utang card into view the first time utang appears. A new test reproduces it on a short screen (fails without the fix); two older tests now wait for the scroll to finish.
2. **Earlier findings re-checked:** the empty Sell screen now has an "Add product" button (fixed since the last run). The tap that jumped back to Sell after sign-in did not happen again. Still open from the last run: the keypad's "Other item" has no cost, so it counts as 100% margin in the profit estimate; the Reports "Pumasok na cash" label cut-off was not looked at (English run).
3. **Slow on the debug build, not investigated:** the receipt after a sale took about 9 seconds to appear while offline (a spinner). A debug build on a 2 GB emulator is not a fair test; check it on a release or profile build.
4. **Note:** opening-stock products show no average cost on the server (`stock_levels.avg_cost` empty) until goods are received; the sale lines still carry the product's own cost, so profit is right.

Test data: tenant `solo-e423847bcdeb` (account `tindera.p1@example.test`, password `Tindera-pass1`) is left in the local database.
