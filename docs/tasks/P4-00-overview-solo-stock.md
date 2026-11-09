# Phase 4 (solo): Stock in, count, low-stock, in Flutter

Plan section 12 Phase 4 for a solo store. The ledger, trigger-derived levels and sale deduction already exist (P3-01..P3-03). This phase adds the ways stock goes up or gets corrected, a Stock screen, low-stock warnings, and average cost.

## Goal
The tindera records stock coming in ("bumili ako ng 24"), corrects it by typing what she counted, sees what is low, and the numbers on the Sell screen are trustworthy.
**Done when:** a random sequence of sales, voids, stock-ins and counts leaves every stock level equal to the sum of its movements (pgTAP property test); products that do not track stock write no movements; the numbers on the phone match the server after a sync; `pnpm check` is green.

## Decisions (defaults chosen; change them here before P4-01 if you disagree)
1. **Never-counted products** (no stock movement and no level yet) show "Not counted" and never a warning. The first stock-in or count starts their count. This replaces the confusing "None left" after a first sale.
2. **Count = type what you have.** The tindera enters the number on the shelf; the app writes the difference as a `count_correction` movement. Reasons offered: counted, damaged/expired (`damage`), other. Stock-in is a `receipt` movement.
3. **Permissions:** same as opening stock (superadmin, or an admin managing the store). Cashiers can see stock, not change it. Warehouse role comes with Phase 5.
4. **Average cost** lives on `stock_levels.avg_cost` and moves only on stock-in with a cost (weighted average). A sale line copies `avg_cost` as `unit_cost` when known, else the variant cost. Stock-in without a cost leaves it alone.
5. **Low stock** = quantity at or below the product's reorder point, only when the reorder point is above 0 (default 0 = no warning). Set under "More" in the product form. The Stock screen has a "Low" filter and Home shows a count.
6. **No stock edit by hand, ever:** only movements. A count or stock-in is queued through the outbox like sales, and counted locally until the server catches up (same rule as P3-03).
7. **Deferred (Phase 5):** transfers, purchase orders, goods receipts, supplier returns, cycle counts by bin.

## Cards
| Card | Work | Model |
| --- | --- | --- |
| P4-01 stock RPCs and average cost | migration (new movement types, `avg_cost`), `op_receive_stock`, `op_adjust_stock`, pull gains `avg_cost`, pgTAP incl. property test | Opus |
| P4-02 local stock ops and sync | Drift v5, local effects, new op kinds in the engine, low-stock and not-counted queries | Opus |
| P4-03 Stock screen, stock in, count | list, search, stock-in, count/adjust, fil + en | Sonnet |
| P4-04 low-stock and not-counted display | reorder point in the product form, Low filter, Home badge, Sell screen wording | Sonnet |
| P4-05 acceptance | browser walk-through, report in handoff | Sonnet |
