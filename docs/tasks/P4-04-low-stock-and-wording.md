# P4-04 Low-stock and not-counted display
Goal: warnings only where they mean something.
- Product form: "Warn me when stock is at or below" under More (reorder point, default 0 = off); synced through `upsert_product` (already accepts `reorder_point`).
- Stock screen "Low" filter, Home tile shows how many are low. Sell screen: "Not counted" items show nothing; a counted item at 0 or below shows "None left (you can still sell)"; low items show the quantity in a warning colour.
- Tests: wording per state, reorder point saved and queued, Home count.
- Done when: analyze and test pass. Use Sonnet.
