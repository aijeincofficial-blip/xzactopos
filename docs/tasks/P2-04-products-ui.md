# P2-04 Products UI (solo)
Goal: add a product in under 15 seconds.
- Home gets a **Products** tile. List shows name, price, stock hint; search box on top; big "+" button.
- **Quick add** is one screen: name, price (numeric pad), optional barcode, optional opening stock. Everything else is hidden under "More" (category, unit, cost, reorder point).
- Edit and archive (with confirm). Empty state explains the first step in plain Filipino.
- Never show the word variant, SKU or tax in Solo mode; SKU auto-generated from a per-tenant counter or the id.
- All text through ARB keys (en + fil, parity test). Large touch targets, works at 360 px width.
- Tests: widget tests for quick add validation, list, archive; offline add shows "pending" and appears in the list at once.
- Done when: `flutter analyze` and `flutter test` pass and it is verified in Chrome. Use Sonnet.
