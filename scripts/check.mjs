// pnpm check = lint, types, tests, pgTAP. Stops at first failure.
import { spawnSync } from "node:child_process";

const steps = ["lint", "typecheck", "test", "test:db"];
for (const s of steps) {
  console.log(`\n== pnpm ${s} ==`);
  const r = spawnSync("pnpm", [s], { stdio: "inherit", shell: true });
  if (r.status !== 0) {
    console.error(`\ncheck FAILED at: ${s}`);
    process.exit(r.status ?? 1);
  }
}
console.log("\ncheck passed");
