# P4-03 Stock screen, stock in, count
Goal: three taps to record "bumili ako ng 24" and one number to correct a count.
- Home tile "Stock": list of products with quantity ("Not counted" when never counted), search and scan, filter chips All / Low.
- Row tap opens a sheet: big "Stock in" (quantity, optional cost) and "Count" (type the number on the shelf, reason). Both work offline and show a pending icon.
- Cashiers see the screen read-only. fil + en strings with `{count}` plurals.
- Tests: widget tests for stock in, count, filters, read-only role, not-counted wording.
- Done when: analyze and test pass; checked in the web build. Use Sonnet.
