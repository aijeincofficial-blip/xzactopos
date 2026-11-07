// Runs pgTAP tests via the Supabase CLI. Fails loudly if tooling or tests are missing once migrations exist.
import { spawnSync } from "node:child_process";
import { readdirSync } from "node:fs";

const hasMigrations = readdirSync("supabase/migrations").some((f) => f.endsWith(".sql"));
if (!hasMigrations) {
  console.log("test:db - NOT RUN (no migrations yet)");
  process.exit(0);
}
const r = spawnSync("pnpm", ["exec", "supabase", "test", "db"], { stdio: "inherit", shell: true });
process.exit(r.status ?? 1);
