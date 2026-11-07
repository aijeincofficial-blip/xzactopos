# P3-05 Pay and receipt
Goal: finish a sale in two taps for exact or common cash amounts.
- Pay screen: total big; cash tendered with quick buttons (exact, next 50/100/500/1000) and a keypad; change due shown in large type and turns red if short.
- "Utang" button for the unpaid rest: pick a customer (search, or add by name on the spot); cash + utang mix allowed (decision 4). E-wallet button if confirmed (optional reference).
- Optional peso-off discount (decision 12), capped at the subtotal.
- Confirm calls `commitSale` once (button disabled while saving, so a double tap cannot make two sales; the op id is made before the tap and reused).
- Receipt screen: shop name, `local_no`, date/time, lines, discount, total, paid, change, utang and customer balance; "Bagong benta" returns to an empty cart. Receipt reopens from Today (P3-07).
  Share/print: a `ReceiptPrinter` interface with a no-op default; real printers are Phase 7.
- Tests: change math (table of cases), mixed cash + utang totals, double-tap safety, customer required for utang, receipt content in fil and en.
- Done when: analyze/test pass; a full sale checked in the web build, offline. Use Sonnet.
