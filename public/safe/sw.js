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
 * Libraries. Since S11c (2026-11-05) pdf.js, its worker, mammoth, jsPDF and
 * heic2any are served from THIS origin (/safe/vendor/, see that directory's
 * README for why), and since S12 (2026-11-06) the webfonts are too (/fonts/,
 * see public/fonts/README.md), so all of them take the same-origin cache-first
 * path below. The one thing still cross-origin is Tesseract.js — loaded lazily
 * and only for OCR; it keeps the version-pinned CACHE-FIRST treatment, which is
 * safe because the URL is immutable.
 */
// Bumped to v4 by S12: the webfonts moved on-origin, so every runtime cache
// entry naming fonts.gstatic.com is now dead weight that nothing will ever
// request again — same reason v3 was cut for cdnjs in S11c. A version bump is
// what evicts it (see activate()).
// The build-time token below is replaced with the image build timestamp by the
// Dockerfile (sed), so every deploy bumps the version even when this file is
// otherwise unchanged. Unstamped (local dev) it stays a valid, stable literal.
const CACHE_VERSION = 'v4-__SW_BUILD__';
const SHELL_CACHE = `safefile-shell-${CACHE_VERSION}`;
const RUNTIME_CACHE = `safefile-runtime-${CACHE_VERSION}`;

// The one asset the offline UI cannot open without. Precaching it is REQUIRED:
// if it fails, install fails (see below) rather than silently producing a
// version that can never open offline.
//
// It used to have a twin, '/safe/index.html', which is deliberately gone: since
// 2026-09-17 that URL 301s to '/safe/' (lib/canonical_path_redirect.rb, SEO
// de-duplication) and cache.put() rejects a redirected Response, so precaching
// it could only ever be a silent no-op. Losing the twin also lost the
// redundancy that used to absorb a failed '/safe/' fetch — which is exactly why
// the required/optional split below exists.
const REQUIRED_SHELL = '/safe/';

// Best-effort extras. A transient miss on an icon must NOT block the update:
// the UI still opens offline without them.
const OPTIONAL_SHELL_ASSETS = [
  '/safe/manifest.ko.webmanifest',
  '/safe/manifest.en.webmanifest',
  '/safe/manifest.ja.webmanifest',
  '/safe/manifest.es.webmanifest',
  '/safe/brand/icon.svg',
  '/safe/brand/icon-192.png',
  '/safe/brand/icon-512.png',
  '/safe/brand/icon-maskable-512.png',
  '/safe/brand/icon-180.png',

  // S11c — the vendored libraries (public/safe/vendor/). Optional for the same
  // reason as the icons: the UI still OPENS without them. What it cannot do
  // without them is its job, and the gap this closes is narrow but real — an
  // installed PWA opened offline right after an update has an empty cache for
  // them, so the shell would render over a dead pipeline. 2.41 MB.
  //
  // heic2any (1.35 MB) is deliberately NOT here: it is needed only for an iPhone
  // HEIC input, and precaching the single largest file for a minority path would
  // charge every reader of the page for it. It still gets cached on first use by
  // the same-origin cache-first branch in fetch(), which is exactly the
  // treatment it had while it lived on a CDN.
  '/safe/vendor/pdf.min.js',
  '/safe/vendor/pdf.worker.min.js',
  '/safe/vendor/mammoth.browser.min.js',
  '/safe/vendor/jspdf.umd.min.js',

  // S12 — the webfont stylesheet (8 KB). Only the stylesheet: the 292 woff2
  // files behind it are NOT precached, and that is the right trade. Each one
  // carries a unicode-range, so a browser downloads the handful its text
  // actually needs; precaching all of them would charge every reader 2.34 MB to
  // save a first-paint reflow. They get cached on first use by the same-origin
  // cache-first branch in fetch() — the treatment they had while on Google's
  // CDN, minus the third-party request.
  //
  // So an offline shell still renders in the system fallback stack if a font
  // was never fetched online. That is exactly what happened before this change
  // too (fonts.gstatic.com is unreachable offline), so nothing regressed.
  '/fonts/fonts.css',
];

// Cross-origin hosts whose (version-pinned) assets we cache-first for revisit
// speed. cdnjs went from this list in S11c and the Google Fonts pair in S12,
// for the same reason both times — a host listed here that the page never
// contacts is a comment claiming a dependency that does not exist. The fonts
// now live in /fonts/ and are handled by the same-origin cache-first branch in
// fetch(), which is strictly better: they get cached on first use without being
// named here at all. jsdelivr stays for Tesseract.js, the one library still
// off-origin; see public/safe/vendor/README.md.
const CACHEABLE_CDN = [
  'cdn.jsdelivr.net',
];

// Precache with cache:'reload' so a stale HTTP-cache entry (e.g. a legacy
// long-max-age shell) can NEVER be baked into the offline cache — that exact
// chain pinned an old app shell on returning visitors.
function precache(cache, url) {
  return fetch(new Request(url, { cache: 'reload' })).then((r) => {
    // A redirected Response would make cache.put() reject, so surface it as a
    // plain failure with a readable reason instead.
    if (!r || !r.ok || r.redirected) {
      throw new Error(`precache ${url}: ${r ? (r.redirected ? 'redirected' : r.status) : 'no response'}`);
    }
    return cache.put(url, r.clone());
  });
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(SHELL_CACHE);

    // REQUIRED first, and let a failure reject the whole install. Without this
    // a transient network blip during install produced a "successful" SW that
    // then took over (skipWaiting) and evicted the previous version's caches in
    // activate — costing a returning visitor a working offline shell. A failed
    // install instead leaves the OLD service worker active with its caches
    // intact, and the browser retries the update on a later visit.
    await precache(cache, REQUIRED_SHELL);

    // Optional extras: tolerate individual misses (a 404 must not fail install).
    await Promise.all(OPTIONAL_SHELL_ASSETS.map((u) => precache(cache, u).catch(() => null)));

    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // Evicting the previous version's caches is irreversible, so confirm this
    // version's shell is actually present before doing it. install already
    // guarantees that, but the browser may drop cache entries under storage
    // pressure at any time — verify rather than assume.
    //
    // When the shell is missing we keep the old caches. That is safe: the
    // offline fallback in fetch() uses the global caches.match(), which
    // searches EVERY cache in the origin, so a previous version's shell still
    // opens the app. The next version's activate clears the backlog.
    const cache = await caches.open(SHELL_CACHE);
    const shellReady = !!(await cache.match(REQUIRED_SHELL));

    if (shellReady) {
      const keys = await caches.keys();
      await Promise.all(
        keys
          .filter((k) => k.startsWith('safefile-') && k !== SHELL_CACHE && k !== RUNTIME_CACHE)
          .map((k) => caches.delete(k))
      );
    }

    await self.clients.claim();
  })());
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
        // Offline fallback. Two details matter:
        //   - `ignoreSearch`: the home page links to /safe/?v=… (cache-buster),
        //     and without it that navigation would miss the precached shell.
        //   - the global `caches.match` searches EVERY cache in the origin, not
        //     just SHELL_CACHE — so when activate deliberately keeps a previous
        //     version's caches (missing shell), that older shell still opens
        //     the app offline.
        .catch(() => caches.match(request, { ignoreSearch: true }).then((r) => r || caches.match(REQUIRED_SHELL)))
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
