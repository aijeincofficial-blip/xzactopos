// Keeps the web app usable with no signal after one online visit.
// Flutter no longer registers its own service worker by default, so this small one does it:
//   - same-origin GET requests only (never the Supabase API: sales go through the app's own outbox);
//   - network first, with a 4 s limit so a weak signal does not stall the app, then the saved copy;
//   - every good answer is saved, so the app, canvaskit, sqlite3.wasm and drift_worker.js are all
//     available offline once they have been loaded once.
const CACHE = 'xz-app-v1';
const NETWORK_LIMIT_MS = 4000;

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) {
        if (key !== CACHE) await caches.delete(key);
      }
      await self.clients.claim();
    })(),
  );
});

async function fromNetwork(request) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), NETWORK_LIMIT_MS);
  try {
    return await fetch(request, { signal: ctrl.signal });
  } finally {
    clearTimeout(timer);
  }
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;

  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE);
      try {
        const response = await fromNetwork(request);
        // only complete, successful answers are kept (a 206 partial or an error page is not)
        if (response.status === 200) cache.put(request, response.clone());
        return response;
      } catch (err) {
        const saved =
          (await cache.match(request)) ||
          (request.mode === 'navigate' ? await cache.match(new URL('./', self.registration.scope).href) : undefined);
        if (saved) return saved;
        throw err;
      }
    })(),
  );
});
