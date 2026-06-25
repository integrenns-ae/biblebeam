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

  // Navigationen (die Seite selbst) network-first: neue Deploys erscheinen
  // sofort beim ersten Reload; offline Fallback auf den Cache.
  if (req.mode === 'navigate') {
    event.respondWith(
      (async () => {
        const cache = await caches.open(CACHE);
        try {
          const fresh = await fetch(req);
          if (fresh && fresh.ok) cache.put(req, fresh.clone());
          return fresh;
        } catch (_) {
          return (
            (await cache.match(req)) ||
            (await cache.match('index.html')) ||
            (await cache.match('./')) ||
            Response.error()
          );
        }
      })(),
    );
    return;
  }

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
