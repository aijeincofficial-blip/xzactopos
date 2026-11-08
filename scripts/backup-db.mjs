// scripts/backup-db.mjs: Dumps database schema and data to backups/
import { spawnSync } from "node:child_process";
import { mkdirSync, existsSync } from "node:fs";
import { join } from "node:path";

if (!existsSync("backups")) {
  mkdirSync("backups", { recursive: true });
}

const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
const outputFile = join("backups", `backup-${timestamp}.sql`);

console.log(`Starting database dump to ${outputFile}...`);

const res = spawnSync(
  "pnpm",
  ["exec", "supabase", "db", "dump", "--local", "-f", outputFile],
  { stdio: "inherit", shell: true }
);

if (res.status === 0) {
  console.log(`Backup successfully created at ${outputFile}`);
} else {
  console.error(`Database backup failed with exit code ${res.status}`);
  process.exit(res.status ?? 1);
}
