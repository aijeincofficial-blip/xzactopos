# Solo UI references and revamp direction

Written 2026-11-07 for the solo UI revamp planned after Phase 8. The owner likes the current look but wants it improved, calmer, not fancy. Sources are thin (vendor help pages, forum posts); treat them as patterns, not studies. No screenshots were taken from these apps.

## What the references do
| Pattern | Seen in | Note for us |
| --- | --- | --- |
| **Bottom tab bar** for the daily tools (Sell, Orders, Reports...), customizable | Square POS redesign | We hide everything behind Home tiles. Bottom tabs would cut taps for the 4 daily screens |
| **Checkout tabs: Keypad / Item library / Favorites** | Square | Keypad = type an amount with no product (useful for load, "tingi" items without a catalog entry). Favorites = our pins (P8-01) |
| **Favorites grid on phone, max 30, drag to order**; **colour-coded items**; tablets use custom pages | Loyverse (help centre, G2 review) | Our pinned tiles match; add optional item colour and a drag order later |
| **Too many graphic tiles overwhelm**; text-only grid for long names / big catalogs | Capterra review of Loyverse, SalesPlay help | Offer a compact text list mode; keep photos optional |
| **Large tap targets, speed over decoration** | POS design guides (VP0, uxjournal) | Our tiles are ok; cart +/- buttons are small |
| **Enter on a barcode adds one unit and refocuses the search** | pos-sales-ui guides | We already do this |
| **Four columns is too dense on a phone** | Frappe POS Awesome forum | Keep 2 columns on phones |
| **Hide fields a small shop does not need** (tax, change suggestions) | VillaTheme POS | Keep Pay simple: cash received, quick amounts, change |
| **Home shows the day's key numbers**: sales, stock alerts, utang owed | Sari-sari apps (SukliPH, Peddlr, SariSari) | Our Home has Today; add "utang owed" and "low stock" numbers |
| **Offline-first, notebook-like utang flow, low-friction setup** | Sari-sari app write-ups | Already our core; keep utang as a plain list of names and amounts |

## Where our current design is heavy
- Glowing circular "coin" badges on every tile, obsidian pill with `>>>` arrows, dual drop shadows: decoration with no information.
- The Home mixes six tiles, a hero card and a settings card: the daily tools are not distinguished from rare ones.
- Tile sublabels repeat the tile name; numbers (owed, low stock) are the useful part.

## Proposed direction (calm, not fancy)
1. **Navigation:** bottom bar with Sell, Stock, Utang, Reports, More (Settings, Expenses, Restock, Export). Home becomes a "Today" dashboard.
2. **Sell screen:** Favorites/All toggle (like Square/Loyverse), a Keypad tab for typed amounts, category chips, optional compact text list. Cart collapses to a bottom bar showing item count and a large Charge button with the total; tap to expand the cart.
3. **Cards:** one soft shadow or a hairline border, not both; flat icons in tinted circles instead of glowing coins; one primary colour per screen for actions.
4. **Numbers first:** on Today and tiles, show the figure (sales, owed, low count) before the label.
5. **Targets and type:** min 48 dp targets, qty buttons larger, amounts in the largest weight; prices right-aligned.
6. **Colour:** keep the two palettes; use colour for meaning (cash, e-wallet, utang, low stock), not decoration; optional per-item colour dot.
7. **Keep:** offline sync badge, theme switch, Filipino/English, tokens in `AppColors`.

## Open questions for the owner
- Bottom tabs or keep Home tiles?
- Keypad tab on Sell: yes/no?
- Photos on tiles or text-only by default?

## Sources
- Square POS redesign: https://squareup.com/us/en/the-bottom-line/inside-square/square-pos-redesign
- Loyverse favorites (smartphone): https://help.loyverse.com/help/favorites-on-smartphones
- Loyverse sale screen arrangement: https://help.loyverse.com/help/how-arrange-sale-screen-loyverse
- Frappe POS Awesome mobile usability thread: https://discuss.frappe.io/t/improving-pos-awesome-mobile-responsiveness-and-usability-for-mobile-devices/144296
- SalesPlay home screen layout: https://help.salesplaypos.com/help/how-to-change-the-pos-app-home-screen-layout
- POS design guide (uxjournal): https://medium.com/uxjournal/the-design-principles-in-the-pos-system-pos-design-guide-part-2-57d1bcb30ac0 (could not be fetched; search summary only)
- Sari-sari app landscape: https://www.hashmicro.com/ph/blog/pos-for-sari-sari-store/, https://restofworld.org/2024/sari-sari-philippines-tech/
