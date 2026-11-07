# S-02 Flutter scaffold (apps/mobile)
Goal: Flutter app that signs in and starts a solo store, running in Chrome and on a phone.
- `flutter create apps/mobile`; add `supabase_flutter`, router, state mgmt, `intl`/ARB for en + fil (no hard-coded strings).
- Screens: Sign up / sign in, "Name your store" (calls `provision_solo_store`), empty Home.
- Config from env (anon key only, never the service role key). Local Supabase URL for dev.
- Tests: widget test for the store-name screen; Dart ARB key-parity test (en vs fil).
- Done when: `flutter run -d chrome` signs up a new user, creates the store, lands on Home; `flutter analyze` + `flutter test` pass; `pnpm check` still green.
