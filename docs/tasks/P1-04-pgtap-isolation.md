# P1-04 pgTAP isolation suite (Opus)
Plan: §10, Phase 1 Done-when.
- Test fixtures: 2 tenants with identical location codes and usernames; users for every role in each; admin who is manager in Store A, supervisor in Store B.
- Per role x per table: can read own tenant rows it should, zero rows from the other tenant, cannot insert/update/delete across tenants.
- Admin per-store permissions evaluate differently in Store A vs Store B.
- Deactivated user and suspended tenant are refused by RPCs.
Done when: `supabase test db` green; this is the main Phase 1 acceptance proof.
