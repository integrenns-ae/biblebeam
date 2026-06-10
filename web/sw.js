// Lichtpfad PWA Service-Worker.
// Strategie: network-first mit Cache-Fallback.
//  - online: immer frische Dateien (kein Versions-Skew nach Deploys),
//    jede erfolgreiche Antwort wird gecached
//  - offline: alles bisher Geladene wird aus dem Cache bedient
//  - Supabase-Aufrufe werden NIE gecached (dynamisch/auth)
'use strict';

const CACHE = 'lichtpfad-v1';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

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
      try {
        const fresh = await fetch(req);
        if (fresh && (fresh.ok || fresh.type === 'opaque')) {
          cache.put(req, fresh.clone());
        }
        return fresh;
      } catch (err) {
        const cached = await cache.match(req);
        if (cached) return cached;
        if (req.mode === 'navigate') {
          const index =
            (await cache.match('index.html')) || (await cache.match('./'));
          if (index) return index;
        }
        throw err;
      }
    })(),
  );
});
