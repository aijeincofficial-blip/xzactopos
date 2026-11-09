# P2-05 Search and barcode scan
Goal: find any product instantly with no signal; this is the base of the Sell screen.
- Local search: name contains (case and accent insensitive), barcode exact, results in under 100 ms for 2,000 products.
- Barcode lookup by variant barcode from the local store. Keyboard-wedge scanners (they type digits + Enter) work first, so web and USB scanners are covered.
- Camera scan with `mobile_scanner` on Android; on web, fall back to typing. Needs the Android toolchain for a phone test.
- Unknown barcode offers "Add this product" with the barcode prefilled.
- Tests: search ordering and accents, barcode hit and miss, unknown-barcode flow.
- Done when: tests green and verified offline in Chrome. Use Sonnet.
