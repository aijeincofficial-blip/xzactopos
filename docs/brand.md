# XZACTO brand / logo

Official app logo, cut from the owner's concept image (2026-11-08) and recoloured to the app palette.

## Files
| File | Use |
| --- | --- |
| `apps/mobile/assets/brand/logo_mark.png` | Transparent mark, 1024 px. Put on any dark surface. |
| `apps/mobile/assets/brand/logo_squircle.png` | Squircle (superellipse n=5) app icon, 1024 px. Main logo. |
| `apps/mobile/assets/brand/logo_round.png` | Round version, 1024 px. |
| `apps/mobile/assets/brand/logo_full_bleed.png` | Square, no mask (store listings / iOS, which masks itself). |
| `android/app/src/main/res/mipmap-*/ic_launcher*.png` | Legacy squircle + round launcher icons. |
| `android/.../mipmap-anydpi-v26/ic_launcher(_round).xml` | Adaptive icon (Android 8+): foreground = mark in the 66 dp safe zone, background = obsidian glow. The launcher picks the shape. |
| `web/favicon.png`, `web/icons/Icon-*.png` | Web/PWA icons (maskable ones keep the mark inside the 80 % safe zone). |

## Colours
- Background: obsidian `#0F172A` (same as the Sell pill) with a soft blue glow top-left and mint glow bottom-right.
- Mark hues moved onto Fresh Tide: blue `#1E6FF2`, mint `#2FD9B2`, amber `#F59E0B`.

## In the app
- Sign-in screen: squircle logo + "XZACTO / POS APP" (`Key('app-logo')`).
- Settings footer: round logo (`Key('settings-logo')`).
- Both fall back to the old icon badge if the asset is missing (tests never break on it).

## Regenerating
The script that made these lives outside the repo (Antigravity scratch: `make_logo.py`, needs numpy + Pillow in a venv).
Steps: crop the mark from the concept, upscale 6x, matte against the navy background, shift hues to the palette,
compose on the obsidian glow, mask squircle/round, export all sizes.

**Quality note:** the source mark was only ~220 px wide inside a 1024 x 571 JPEG, so the 1024 px masters are upscaled
and slightly soft. Launcher sizes (max 192 px) look sharp. For print, store banners or a big splash, ask the designer for
the original vector (SVG/AI) and re-export from that.
