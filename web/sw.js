// Lichtpfad PWA Service-Worker.
// Strategie: stale-while-revalidate (Cache sofort, Update im Hintergrund).
//  - Start ist schnell, auch bei langsamem Netz (alles kommt aus dem Cache)
//  - jede Antwort wird im Hintergrund aktualisiert -> neue Deploys greifen
//    beim übernächsten Start automatisch
//  - offline: alles bisher Geladene funktioniert
//  - Supabase-Aufrufe werden NIE gecached (dynamisch/auth)
'use strict';

const CACHE = 'lichtpfad-v2';

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
