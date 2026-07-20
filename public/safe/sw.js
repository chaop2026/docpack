/*
 * SafeFile service worker — offline app shell.
 *
 * Cache-busting design (learned from the 1-year static-HTML cache bug):
 *   1. CACHE_VERSION is bumped on every meaningful deploy. All cache names are
 *      namespaced by it, and activate() deletes every cache that isn't the
 *      current version — so an old shell can never get pinned.
 *   2. skipWaiting() + clients.claim() make a new SW take over immediately,
 *      instead of waiting for every tab to close.
 *   3. HTML / navigations use NETWORK-FIRST: a fresh deploy is always fetched
 *      when online; the cached copy is only a fallback for offline. The shell
 *      HTML is therefore never "stuck" at an old version.
 *
 * Never cached: POST/non-GET, and anything under /api/ (esp. /api/safe_scan —
 * the AI deep-scan endpoint must always hit the network and never be stored).
 *
 * CDN libraries (pdf.js, mammoth, tesseract, jspdf, heic2any, Google Fonts) are
 * version-pinned URLs, so they use CACHE-FIRST: first visit pays the network
 * cost (no extra first-load burden — nothing is pre-fetched), and returning
 * visitors get them instantly from cache. Because the URLs are immutable, there
 * is no staleness risk.
 */
// The build-time token below is replaced with the image build timestamp by the
// Dockerfile (sed), so every deploy bumps the version even when this file is
// otherwise unchanged. Unstamped (local dev) it stays a valid, stable literal.
const CACHE_VERSION = 'v2-__SW_BUILD__';
const SHELL_CACHE = `safefile-shell-${CACHE_VERSION}`;
const RUNTIME_CACHE = `safefile-runtime-${CACHE_VERSION}`;

// Minimal app shell precached on install (UI must open offline).
const SHELL_ASSETS = [
  '/safe/',
  '/safe/index.html',
  '/safe/manifest.ko.webmanifest',
  '/safe/manifest.en.webmanifest',
  '/safe/manifest.ja.webmanifest',
  '/safe/manifest.es.webmanifest',
  '/safe/icon.svg',
  '/safe/icon-192.png',
  '/safe/icon-512.png',
  '/safe/icon-maskable-512.png',
  '/safe/apple-touch-icon.png',
];

// Cross-origin hosts whose (version-pinned) assets we cache-first for revisit speed.
const CACHEABLE_CDN = [
  'cdnjs.cloudflare.com',
  'cdn.jsdelivr.net',
  'fonts.googleapis.com',
  'fonts.gstatic.com',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(SHELL_CACHE).then((cache) =>
      // Precache with cache:'reload' so a stale HTTP-cache entry (e.g. a legacy
      // long-max-age shell) can NEVER be baked into the offline cache — that
      // exact chain pinned an old app shell on returning visitors. cache each
      // individually to tolerate transient misses (a 404 must not fail install).
      Promise.all(SHELL_ASSETS.map((u) =>
        fetch(new Request(u, { cache: 'reload' }))
          .then((r) => (r && r.ok) ? cache.put(u, r.clone()) : null)
          .catch(() => null)
      ))
    ).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k.startsWith('safefile-') && k !== SHELL_CACHE && k !== RUNTIME_CACHE)
          .map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

// Let the page trigger an immediate takeover after an update if it wants to.
self.addEventListener('message', (event) => {
  if (event.data === 'skipWaiting') self.skipWaiting();
});

function isHtmlRequest(request) {
  return request.mode === 'navigate' ||
    (request.headers.get('accept') || '').includes('text/html');
}

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Only ever handle GET. Never touch the API (safe_scan must always be live).
  if (request.method !== 'GET') return;
  if (url.origin === self.location.origin && url.pathname.startsWith('/api/')) return;

  // Never intercept the SW script itself — always let it reach the network so
  // updates are found. (The browser's update fetch already bypasses the SW; this
  // just stops the same-origin cache-first branch below from ever serving a
  // stale /safe/sw.js.)
  if (url.origin === self.location.origin && url.pathname === '/safe/sw.js') return;

  // HTML / navigations: network-first, and force cache:'no-cache' so the SW
  // ALWAYS revalidates with the server instead of trusting HTTP-cache freshness.
  // A legacy long-max-age HTML entry can no longer silently satisfy this fetch
  // and pin an old shell — "network-first" now truly hits the network. (no-cache,
  // not no-store, so an unchanged shell still gets a cheap 304.) Cache Storage is
  // the offline-only fallback.
  if (isHtmlRequest(request) && url.origin === self.location.origin) {
    event.respondWith(
      fetch(request.url, { cache: 'no-cache' })
        .then((resp) => {
          const copy = resp.clone();
          caches.open(SHELL_CACHE).then((c) => c.put(request, copy)).catch(() => {});
          return resp;
        })
        .catch(() => caches.match(request).then((r) => r || caches.match('/safe/index.html')))
    );
    return;
  }

  // Same-origin static assets (icons, manifest, svg): cache-first.
  if (url.origin === self.location.origin) {
    event.respondWith(
      caches.match(request).then((cached) =>
        cached ||
        fetch(request).then((resp) => {
          const copy = resp.clone();
          caches.open(SHELL_CACHE).then((c) => c.put(request, copy)).catch(() => {});
          return resp;
        }).catch(() => cached)
      )
    );
    return;
  }

  // Version-pinned CDN libraries: cache-first (immutable URLs → no staleness).
  if (CACHEABLE_CDN.includes(url.hostname)) {
    event.respondWith(
      caches.match(request).then((cached) => {
        if (cached) return cached;
        return fetch(request).then((resp) => {
          // cache opaque/ok responses; opaque (no-cors CDN) is fine for <script>.
          const copy = resp.clone();
          caches.open(RUNTIME_CACHE).then((c) => c.put(request, copy)).catch(() => {});
          return resp;
        });
      })
    );
    return;
  }

  // Everything else (ads, analytics, other cross-origin): pass through untouched.
});
