# P3-04 Sell screen
Goal: the home tile "Magbenta" opens a screen where adding an item takes one tap, scan or a few letters.
- Layout (phone first, works wide on web): search box on top (scan icon focuses it, Enter on a known barcode adds the item; unknown barcode says so and offers "Add product"),
  grid of quick-tap tiles (decision 15) with photo/name/price, cart below or in a bottom sheet with a sticky total bar and big "Bayad" button.
- Cart: tap tile again = +1, `-`/`+` steps, swipe or X to remove, tap the quantity for a keypad, price shown per line; a line with price 0 or no price is blocked with a short message.
  Stock left shown small on tiles/search results; at 0 or below a soft warning, never a block.
- Cart lives in memory and in `meta` so a phone call or app restart does not lose it; "Clear" asks first.
- Strings fil + en (`sell.*`), `{count}` plurals; no words "SKU", "variant".
- Tests: widget tests with a fake store (add by scan, add by search, quantity, remove, total in centavos, persisted cart restored, out-of-stock warning).
- Done when: `flutter analyze`/`flutter test` pass and the screen is checked in the web build. Use Sonnet.
