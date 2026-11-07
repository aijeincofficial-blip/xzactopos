# Design audit (card D-01)

Date: 2026-11-07. Device: Android emulator Pixel_4_API_33 (1080x2280), debug APK, light theme, Filipino, store "Tindahan ni Rosa" (1 product, 1 sale).
Screenshots: `docs/design-audit/`. Not yet audited: dark theme (does not exist), the pay, receipt, product form, auth and password screens (need an interactive walk), web at 360x640, font scale 1.5x. Add these in a second pass.

## How the app looks now
- Theme is one line in `lib/app.dart`: `ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true)`. It is teal/mint, not the owner's blue. Light only, no dark theme.
- Almost every surface is the same pale mint (`primaryContainer`): home tiles, product tiles, Today header, FABs. Nothing stands out, so nothing says "money" or "go".
- Few hard-coded colors (4 uses of `Colors.*`), so a central theme will restyle most of the app cheaply.

## Findings by screen
| Screen | Findings | Severity |
| --- | --- | --- |
| Launch | Default white Flutter logo splash for several seconds. No brand. Debug banner is only a debug build. | Med |
| Home | 6 equal tiles; Sell is the main job but is the same size as Reports. Greeting wraps to 2 lines and the store name in the app bar is cut off ("Tindahan ni ..."). "1 produkto sa phone na ito" is technical, not useful. Today's sales total and low stock are a tap away instead of visible. Large empty space under the grid. Four app bar icons (sync, EN, change password, sign out) crowd the title; sign out and change password sit next to each other in the top bar, easy to hit by mistake. | High |
| Sell | Product tiles are mint blocks with no photo; the tile is small (about 3 across would fit) and blank in the middle. Search field plus scan icon is good. Cart bar at the bottom is in thumb reach, total is large (good). Pay button is a disabled grey pill with low contrast. Hint text "Pindutin ang produkto..." is small, pale grey. | High |
| Utang | Summary band is a different, greyer teal than other screens. Empty state is text only, no icon or action. FAB "Bagong customer" is fine. | Low |
| Today | Strongest screen: big total, clear breakdown. The big mint block is heavy; the sale row shows an internal receipt number ("LL3-261107-0001") with no clear tap hint. | Med |
| Stock | Plain list; stock status text ("Hindi pa nabibilang") is small grey and does not read as a status. Filter chips are good but low contrast. Photo placeholder is a grey box. | Med |
| Products | Fine and consistent with Stock. Placeholder image box. FAB uses a Filipino verb ("Magdagdag") only; OK. | Low |
| Reports | Good content. The day bar chart uses one flat dark teal bar, other days show no bar; labels "Nob 1..7" are clear. Everything is the same weight; headings and numbers could separate better. | Med |

## Cross-cutting issues
1. No design tokens: spacing, radius and text sizes are chosen per screen (16, 12, 20 etc.).
2. Color is not meaningful: money, success, warning (low stock) and danger (utang owed, void) need distinct colors. Right now low stock is only a red count badge.
3. No dark theme.
4. App bar is the same on every screen (back arrow + sync cloud); the sync icon alone does not say "saved on this phone, not yet sent".
5. No branding: default splash, default launcher icon (not checked), no logo on sign-in.
6. Empty states are plain text.
7. Tap targets look fine (48 dp+) on the screens seen; confirm the app bar icon spacing on a small phone.
8. Text: body copy on grey backgrounds (hints, status text) is probably under 4.5:1 contrast; measure in D-07.

## Tap counts for the 5 core jobs (current)
| Job | Taps | Note |
| --- | --- | --- |
| Sell one item for cash | Home > Sell > tile > Bayad > confirm (about 5, confirm on the pay screen to verify) | Verify exact count in D-03 |
| Sell on utang | about 7 incl. customer picker | Verify in D-03 |
| Add stock | Home > Stock > product > form > save (about 5) | Verify in D-05 |
| Add product | Home > Products > Magdagdag > form > save (about 4 plus typing) | Verify in D-05 |
| See today's total | Home > Ngayong araw (2) | Should be 0: show it on Home |

## Recommendations carried into D-02 to D-08
- D-02: replace the teal seed with a fresh, cool blue primary plus a mint/teal accent (money, success); warm amber for low stock; coral red for utang/void; neutral cool-grey surfaces. Show the owner 2 palette options as flat previews before applying. Dark theme designed together with light.
- D-03: Sell tiles bigger with photo or colored initial; pay button always shows the total; exact-cash and bill shortcuts.
- D-04: Home gets a "today" strip (total, number of sales, low stock, utang owed); Sell is a large primary action; move sign out and change password into a menu.
- D-05: status chips for stock; richer empty states with an icon and a next action.
- D-06: clearer sync label ("Naka-save sa phone, hindi pa naipapadala").
- D-08: branded splash and launcher icon.
