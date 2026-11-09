# P3-07 Today and void
Goal: end-of-day total and a safe way to undo a wrong sale.
- Home tile "Ngayong araw": today's total sales, cash in, utang given, number of sales, from this device's sales. Sales list (newest first) opens the receipt.
- "Cancel sale" on a receipt: confirm, then `voidSale` (stock back, utang charge reversed, receipt marked CANCELLED, still listed). Voided sales do not count in totals. Cannot cancel twice.
- Server side was built in P3-02; this card is UI plus the local effect. Ask Opus to review the reversal tests.
- Tests: totals exclude voids, void restores local stock and balance, double void refused, list order.
- Done when: analyze/test pass; checked in the web build. Use Sonnet (Opus review of the reversal).
