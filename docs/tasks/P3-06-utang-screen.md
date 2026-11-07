# P3-06 Utang screen
Goal: the tindera sees who owes what and records payments without a notebook.
- Home tile "Utang": customers with a balance first (biggest first), search, total owed at the top, "Add customer" (name, optional phone).
- Customer page: balance, history (sales on utang, payments, adjustments) newest first, big "Nagbayad" button (amount keypad, defaults to the full balance, optional note), "Adjust" under More.
- Overpayment is refused with a short message (balance cannot go below 0 in solo). Works offline through the outbox; pending items show the same small pending icon as products.
- Tests: widget tests for list order, payment updates the balance at once, overpay refused, history lines, fil/en plurals.
- Done when: analyze/test pass; checked in the web build. Use Sonnet.
