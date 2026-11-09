// Checks the offline service worker (web/sw.js) against a small fake of the service worker environment.
// Run: node apps/mobile/tool/sw_test.mjs   (exit code 1 on any failure)
import { readFileSync } from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";

const source = readFileSync(new URL("../web/sw.js", import.meta.url), "utf8");
const ORIGIN = "http://app.test";

function makeEnv({ network }) {
  const handlers = {};
  const store = new Map(); // cache name -> Map(url -> Response)
  const cachesFake = {
    async open(name) {
      if (!store.has(name)) store.set(name, new Map());
      const m = store.get(name);
      return {
        async match(req) {
          const r = m.get(typeof req === "string" ? req : req.url);
          return r ? r.clone() : undefined;
        },
        async put(req, res) {
          m.set(typeof req === "string" ? req : req.url, res);
        },
      };
    },
    async keys() {
      return [...store.keys()];
    },
    async delete(name) {
      return store.delete(name);
    },
  };
  const self = {
    location: { origin: ORIGIN },
    registration: { scope: `${ORIGIN}/` },
    clients: { claim: async () => {} },
    skipWaiting() {},
    addEventListener(type, fn) {
      handlers[type] = fn;
    },
  };
  const ctx = vm.createContext({
    self, caches: cachesFake, URL, AbortController, setTimeout, clearTimeout, console,
    fetch: (req, opts) => network(req, opts),
  });
  vm.runInContext(source, ctx);
  const request = (url, { method = "GET", mode = "cors" } = {}) => ({ url, method, mode });
  async function fetchThroughSW(req) {
    let answer;
    let handled = false;
    await handlers.fetch({
      request: req,
      respondWith(p) {
        handled = true;
        answer = p;
      },
    });
    return handled ? await answer : "passed-through";
  }
  return { handlers, store, fetchThroughSW, request };
}

let failed = 0;
async function test(name, fn) {
  try {
    await fn();
    console.log("PASS ", name);
  } catch (e) {
    failed++;
    console.log("FAIL ", name, "\n     ", e.message);
  }
}

await test("online: answers from the network and keeps a copy", async () => {
  const env = makeEnv({ network: async () => new Response("main-js", { status: 200 }) });
  const res = await env.fetchThroughSW(env.request(`${ORIGIN}/main.dart.js`));
  assert.equal(await res.text(), "main-js");
  assert.equal(env.store.get("xz-app-v1").size, 1);
});

await test("offline: serves the saved copy", async () => {
  let up = true;
  const env = makeEnv({
    network: async () => {
      if (!up) throw new TypeError("offline");
      return new Response("sqlite-wasm", { status: 200 });
    },
  });
  await env.fetchThroughSW(env.request(`${ORIGIN}/sqlite3.wasm`));
  up = false;
  const res = await env.fetchThroughSW(env.request(`${ORIGIN}/sqlite3.wasm`));
  assert.equal(await res.text(), "sqlite-wasm");
});

await test("offline: opening the app (navigation) falls back to the saved start page", async () => {
  let up = true;
  const env = makeEnv({
    network: async () => {
      if (!up) throw new TypeError("offline");
      return new Response("<html>app</html>", { status: 200 });
    },
  });
  await env.fetchThroughSW(env.request(`${ORIGIN}/`, { mode: "navigate" }));
  up = false;
  const res = await env.fetchThroughSW(env.request(`${ORIGIN}/index.html?x=1`, { mode: "navigate" }));
  assert.equal(await res.text(), "<html>app</html>");
});

await test("offline and never saved: the failure is passed on", async () => {
  const env = makeEnv({ network: async () => { throw new TypeError("offline"); } });
  await assert.rejects(() => env.fetchThroughSW(env.request(`${ORIGIN}/never-loaded.js`)), /offline/);
});

await test("a slow network gives up after the limit and the saved copy is used", async () => {
  let slow = false;
  const env = makeEnv({
    network: (req, opts) =>
      slow
        ? new Promise((_, reject) => opts.signal.addEventListener("abort", () => reject(new Error("aborted"))))
        : Promise.resolve(new Response("v1", { status: 200 })),
  });
  await env.fetchThroughSW(env.request(`${ORIGIN}/a.js`));
  slow = true;
  const t0 = Date.now();
  const res = await env.fetchThroughSW(env.request(`${ORIGIN}/a.js`));
  assert.equal(await res.text(), "v1");
  assert.ok(Date.now() - t0 >= 3500 && Date.now() - t0 < 6000, "waited about 4 s");
});

await test("errors and partial answers are not saved", async () => {
  const env = makeEnv({ network: async () => new Response("nope", { status: 404 }) });
  await env.fetchThroughSW(env.request(`${ORIGIN}/missing.js`));
  assert.equal(env.store.get("xz-app-v1").size, 0);
  const env2 = makeEnv({ network: async () => new Response("part", { status: 206 }) });
  await env2.fetchThroughSW(env2.request(`${ORIGIN}/video.mp4`));
  assert.equal(env2.store.get("xz-app-v1").size, 0);
});

await test("other origins (Supabase) and non-GET requests are never touched", async () => {
  const env = makeEnv({ network: async () => new Response("x", { status: 200 }) });
  assert.equal(await env.fetchThroughSW(env.request("http://127.0.0.1:54321/rest/v1/rpc/sync_push")), "passed-through");
  assert.equal(await env.fetchThroughSW(env.request(`${ORIGIN}/api`, { method: "POST" })), "passed-through");
});

await test("activate removes old cache versions", async () => {
  const env = makeEnv({ network: async () => new Response("x") });
  env.store.set("xz-app-v0", new Map());
  env.store.set("xz-app-v1", new Map());
  await new Promise((resolve) => env.handlers.activate({ waitUntil: (p) => p.then(resolve) }));
  assert.deepEqual([...env.store.keys()], ["xz-app-v1"]);
});

if (failed) {
  console.log(`\n${failed} failed`);
  process.exit(1);
}
console.log("\nservice worker checks passed");
