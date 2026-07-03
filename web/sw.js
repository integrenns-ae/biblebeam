// Lichtpfad PWA Service-Worker.
// Strategie:
//  - Navigationen (index.html) NETWORK-FIRST -> neue Deploys sofort sichtbar,
//    offline Fallback auf den Cache.
//  - Übrige Dateien stale-while-revalidate (schneller Start, offline ok).
//  - Der CACHE-Name wird bei jedem Deploy gestempelt (deploy.sh) -> ein neuer
//    Deploy verwirft den alten Cache, Code-Assets werden frisch geladen.
//  - Supabase-Aufrufe werden NIE gecached (dynamisch/auth).
'use strict';

// Platzhalter wird von deploy.sh pro Deploy ersetzt (z. B. lichtpfad-20260624…).
const CACHE = 'lichtpfad-v3';

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      // alte Cache-Versionen aufräumen
      for (const name of await caches.keys()) {
        if (name !== CACHE) await caches.delete(name);
      }
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  const sameOrigin = url.origin === self.location.origin;
  const isFont =
    url.host === 'fonts.gstatic.com' || url.host === 'fonts.googleapis.com';
  if (!sameOrigin && !isFont) return; // z. B. Supabase: durchreichen, nie cachen

  // Alles (inkl. index.html) einheitlich stale-while-revalidate: index.html und
  // App-Code kommen so immer aus DERSELBEN Cache-Generation -> nie "neue Seite +
  // alter Code". Aktualität kommt über den Cache-Stempel je Deploy + den
  // controllerchange-Reload in index.html.
  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE);
      const cached = await cache.match(req);

      const refresh = fetch(req)
        .then((fresh) => {
          if (fresh && (fresh.ok || fresh.type === 'opaque')) {
            cache.put(req, fresh.clone());
          }
          return fresh;
        })
        .catch(() => undefined);

      if (cached) {
        // sofort aus dem Cache antworten, Update läuft im Hintergrund weiter
        event.waitUntil(refresh);
        return cached;
      }

      const fresh = await refresh;
      if (fresh) return fresh;

      if (req.mode === 'navigate') {
        const index =
          (await cache.match('index.html')) || (await cache.match('./'));
        if (index) return index;
      }
      return Response.error();
    })(),
  );
});
