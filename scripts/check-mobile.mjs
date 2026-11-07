// Flutter checks for apps/mobile: analyze + tests. Skipped (loudly) when Flutter is not installed.
import { spawnSync } from "node:child_process";

const probe = spawnSync("flutter", ["--version"], { shell: true, stdio: "ignore" });
if (probe.status !== 0) {
  console.log("check:mobile - NOT RUN (flutter not found on PATH)");
  process.exit(0);
}
for (const args of [["analyze"], ["test"]]) {
  const r = spawnSync("flutter", args, { cwd: "apps/mobile", stdio: "inherit", shell: true });
  if (r.status !== 0) process.exit(r.status ?? 1);
}
