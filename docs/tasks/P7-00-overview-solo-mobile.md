# Phase 7 (solo): phone camera scan, receipt printing, offline web, APK

Plan section 12 Phase 7 for the Flutter app (replaces the Capacitor wording). Closes gaps A1 and A2 as far as this machine allows.

## Goal
On a phone the tindera scans barcodes with the camera (one tap, or continuously while selling), prints or shares a receipt, and the web app opens with no signal after the first visit.
**Done when:** camera scan works through an interface the tests can fake (add to cart, find product, fill the barcode field); a receipt can be printed or shared as a 58 mm PDF; the web build starts offline after one online visit; `pnpm check` is green. An APK is built and run on a phone or emulator **only when the Android toolchain is complete** (see decision 1).

## Decisions
1. **Android toolchain is still incomplete on this machine** (`flutter doctor`: cmdline-tools missing, licenses not accepted), and another session owns `apps/mobile/android/` and `run-android.ps1`. This phase does not edit them and cannot build or run an APK here. The camera and print code is written against the plugins' normal Android setup and is checked with `flutter analyze` and fakes; **it is not tested on a phone**. The first phone test is the open item.
2. **Camera scan:** `mobile_scanner` (ML Kit on Android). Behind a `CameraScanner` interface so screens and tests never touch the plugin. Hidden on the web (the web plugin needs a CDN script, which would break offline); the web keeps the keyboard-wedge scanner and typing.
3. **Where it appears:** Sell (continuous mode: each code goes into the cart, unknown codes are named, same code is ignored for 1.5 s), Products search (single scan), product form barcode field (single scan).
4. **Receipts:** `pdf` + `printing`. A 58 mm roll PDF, sent to the system print dialog (any printer Android knows, including Bluetooth print services, or "save as PDF") or shared. The peso sign is printed as "P" because the built-in PDF font has no peso glyph. Direct ESC/POS over Bluetooth stays behind the `ReceiptPrinter` interface until a printer model is chosen.
5. **Offline web:** build with `--no-web-resources-cdn` (CanvasKit bundled) and rely on Flutter's service worker (caches the app, `sqlite3.wasm`, `drift_worker.js`). The app asks the browser for persistent storage so IndexedDB is not evicted.
6. **Deferred:** web camera scan (BarcodeDetector), ESC/POS Bluetooth, iOS.

## Cards
| Card | Work | Model |
| --- | --- | --- |
| P7-01 camera scan | `CameraScanner` interface, mobile_scanner implementation, Sell/Products/form wiring, fakes in tests | Sonnet |
| P7-02 receipt print and share | `buildReceiptPdf`, `PdfReceiptPrinter`, Print and Share buttons | Sonnet |
| P7-03 offline web and persistent storage | build flags, service worker check, `navigator.storage.persist()` | Sonnet |
| P7-04 acceptance | Android build attempt, report and open items in the handoff | Sonnet |
