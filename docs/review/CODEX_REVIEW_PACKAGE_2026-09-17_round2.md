# Codex 교차검증 패키지 — 라운드 2 (수정 확인) · 2026-09-17

> 비밀값 스캔 결과는 문서 말미.

## ① 리뷰어용 프롬프트

당신은 **독립 코드 리뷰어**다. 아래 패키지만 근거로 판단하라.

**맥락**: 라운드 1 에서 당신(같은 도구)이 커밋 `d6d0655` 에 대해 지적 2건을 냈다.
이번 커밋 `cf6d69f` 는 **그 2건을 고치려는 시도**다. 아직 배포되지 않았다.

**이번 리뷰의 목적은 두 가지다**:
1. **A-1 · A-2 가 실제로 해소됐는가?** 각각 `해소됨` / `부분 해소` / `미해소` 로 판정하고
   판정 근거를 파일:줄로 대라.
2. **수정이 새로 만든 문제는 없는가?** 특히 서비스워커 생애주기는 되돌리기 어렵다.

**라운드 1 지적 원문**:

> **A-1 [논리 오류][확신도 높음]** 새 서비스워커 설치가 셸 캐시 실패를 성공처럼 처리한 뒤
> 기존 오프라인 캐시를 삭제할 수 있음. 설치 중 `/safe/` 프리캐시가 실패해도 `.catch(() => null)`
> 때문에 install 은 성공하고 `skipWaiting()` 한다. activate 에서는 이전 `safefile-*` 캐시를
> 모두 삭제한다. 즉 기존 방문자가 업데이트는 받았지만 `/safe/` 셸 fetch 가 일시 실패한 경우,
> 정상 작동하던 구버전 오프라인 셸을 삭제하고 새 셸도 없는 상태가 될 수 있다.
> 최소한 `/safe/` 자체는 설치 실패를 install 실패로 올려서 기존 SW와 기존 캐시가 유지되게 해야 한다.

> **A-2 [보안][확신도 낮음]** 301 HTML 본문이 쿼리 문자열 포함 Location 을 이스케이프 없이
> 반사함. `QUERY_STRING` 을 붙인 `location` 을 HTML 속성값과 텍스트 노드에 그대로 넣는다.
> 301 본문은 보통 사용자가 보지 않지만 `text/html` 로 내려가므로 방어적으로 escape 하는 편이 맞다.

**지적 분류 고정**: `정책 위반` / `보안` / `데이터 손실 위험` / `논리 오류`

**규칙**:
- 모든 지적에 **파일:줄 근거**를 달아라. 근거 없는 지적은 적지 마라.
- **확신도(높음/보통/낮음)** 표기. 낮아도 적되 낮다고 밝혀라.
- **여기 없는 파일은 추측하지 마라.** 필요하면 "경로 요청: <파일>" 이라고 적어라.
- 하지 말 것: 스타일 지적, 일반론적 "테스트를 늘려라", 정본 문서를 고치자는 제안.

**이 저장소가 반복해 당한 실패 유형** (이 관점으로 파고들어라):
1. **조용한 실패** — 실패했는데 성공처럼 보인다.
2. **캐시 고착** — 한 번 잘못 캐시되면 되돌릴 수 없다.
3. **공허한 검사** — 아무것도 검증하지 않는 테스트/단언.
4. **암묵적 상류 의존** — 안전의 근거가 우리 코드 밖에 있다.

**특히 답을 원하는 질문**:
- R1. install 이 실패하면 **구 SW 와 구 캐시가 정말로 보존되는가?** 보존이 깨지는 경로가 있는가?
- R2. `activate` 가 `shellReady` 가 false 일 때 구버전 캐시를 **남기는** 선택이 옳은가?
  캐시가 무한정 쌓이거나, 오래된 셸이 영구 고착되는 경로가 생기지 않는가?
- R3. install 실패 시 `caches.open(SHELL_CACHE)` 로 만들어진 **부분 채워진 새 캐시**가 남는다.
  이게 나중에 문제를 일으키는가? (다음 install 재시도, fetch 폴백, activate 판정)
- R4. `CGI.escapeHTML` + CR/LF 제거로 A-2 가 **우리 코드의 성질**이 됐는가? 남은 구멍이 있는가?
- R5. `test/lib/static_index_redirect_test.rb` 와 `test/sw/offline_resilience.mjs` 에
  **공허한 단언**이 있는가? 특히 SW 하네스가 실제로 회귀를 잡는다고 볼 수 있는가?

**출력 형식**:
```
[A-1 판정] 해소됨 | 부분 해소 | 미해소
근거: <파일:줄>
설명: ...

[A-2 판정] 해소됨 | 부분 해소 | 미해소
근거: <파일:줄>
설명: ...
```
그 다음 **새 지적**(있으면)을 라운드 1 형식으로, 마지막에 R1~R5 답변.

---

## ② 수정 요약

### A-1 수정 (`public/safe/sw.js`)
- `SHELL_ASSETS` → `REQUIRED_SHELL`(`/safe/`) + `OPTIONAL_SHELL_ASSETS`(아이콘·매니페스트) 분리
- 공통 `precache()` 헬퍼: `!r.ok` **또는 `r.redirected`** 를 throw (리다이렉트된 Response 는
  `cache.put()` 이 거부하므로 읽을 수 있는 실패로 바꾼다)
- `install`: `REQUIRED_SHELL` 을 먼저, **실패를 전파하며** 캐시 → 실패 시 install 자체가 reject
  → `skipWaiting()`·activate 미발생 → 구 SW·구 캐시 보존. 옵션 자산은 개별 실패 허용.
- `activate`: 삭제 전 `cache.match(REQUIRED_SHELL)` 로 확인. 없으면 구버전 캐시를 **남긴다**.
- 페이지 등록부에 이미 `.catch(()=>{})` 가 있다 (`index.html:1887`, 아래 발췌 포함).

### A-2 수정 (`lib/static_index_redirect.rb`)
- `body_for()` 가 `CGI.escapeHTML(location)` 사용
- `redirect_location()` 이 쿼리스트링에서 CR·LF 제거
- `require "cgi/escape"` 추가

### 검증 (전부 로컬, 배포 전)
- Rack 단위 25 케이스 통과
- `bin/rails test` → **25 runs / 87 assertions / 0 failures** (수정 전 12/35)
- Playwright 렌더 4개 진입점 통과 (canonical 동일, hreflang 1개, JS 에러 0)
- SW 설치·오프라인 폴백 통과 (`/safe/`·`/safe/?v=` 둘 다)
- **SW 네트워크 실패 주입 9/9 통과.** 같은 하네스를 수정 전 워커로 돌리면 3건 실패
  (구버전 캐시 삭제 + 오프라인 내비게이션 `net::ERR_FAILED`)

---

## ③ 핵심 파일 전문

#### `public/safe/sw.js`

```javascript
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

// The one asset the offline UI cannot open without. Precaching it is REQUIRED:
// if it fails, install fails (see below) rather than silently producing a
// version that can never open offline.
//
// It used to have a twin, '/safe/index.html', which is deliberately gone: since
// 2026-09-17 that URL 301s to '/safe/' (lib/static_index_redirect.rb, SEO
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
```

#### `lib/static_index_redirect.rb`

```ruby
# frozen_string_literal: true

require "cgi/escape"

# Rack middleware that collapses the duplicate URLs a static-directory page
# otherwise answers on, into one canonical trailing-slash URL.
#
# Why this exists (2026-09-17, GSC "Duplicate without user-selected canonical"):
# `ActionDispatch::FileHandler` resolves a request for `/safe` by probing
# `public/safe`, `public/safe.html` and finally `public/safe/index.html` — so
# `/safe`, `/safe/` and `/safe/index.html` all returned an identical 200. And
# because ActionDispatch::Static sits *in front of* the router, the
# `get "/safe", to: redirect("/safe/")` route in config/routes.rb never ran:
# the static handler answered first and the redirect was dead code.
#
# Three URLs × identical bytes × no `<link rel=canonical>` is the textbook input
# for Google's "Duplicate without user-selected canonical". The canonical tag on
# the page is the primary fix; this middleware removes the duplicates at the
# source so Google never has to consolidate them in the first place.
#
# Must be inserted BEFORE ActionDispatch::Static (see the initializer) or the
# static handler wins again.
class StaticIndexRedirect
  # Directory-backed static HTML entrypoints, without the trailing slash.
  # Each one is served from `public/<dir>/index.html`.
  DIRS = %w[/safe /privacy].freeze

  # Only GET/HEAD are redirected. A POST must never be turned into a 301 — the
  # method and body would be silently dropped by the client.
  SAFE_METHODS = %w[GET HEAD].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    target = canonical_target(env)
    return @app.call(env) unless target

    location = redirect_location(env, target)

    [
      301,
      {
        "location" => location,
        "content-type" => "text/html; charset=utf-8",
        # A permanently-cached 301 is effectively irreversible in the browser.
        # This app has already been bitten once by a pinned static cache
        # (see lib/static_html_no_cache.rb), so the redirect always revalidates.
        "cache-control" => "no-cache"
      },
      [body_for(location)]
    ]
  end

  private

  # The Location the client is sent to. The query string is echoed back from the
  # request, so strip anything that could break out of the header. Puma already
  # rejects a request line containing CR or LF, but relying on that would make
  # this middleware's safety a property of the upstream parser rather than of
  # this code — swap the server or put a proxy in front and the guarantee is
  # gone. Strip them here so the invariant holds on its own.
  def redirect_location(env, target)
    # SCRIPT_NAME is "" for a root-mounted app (the case here), but including it
    # keeps the Location correct if this app is ever mounted under a sub-path.
    # String#delete takes a character SET, not a substring — this removes every
    # CR and every LF, not just the "\r\n" pair.
    query = env["QUERY_STRING"].to_s.delete("\r\n")
    location = "#{env["SCRIPT_NAME"]}#{target}"
    query.empty? ? location : "#{location}?#{query}"
  end

  # The 301 body is a courtesy for clients that do not follow Location (browsers
  # never render it). It still echoes request-controlled input, so escape it:
  # the same reasoning as above — the raw `<`, `>` and `"` that would make this
  # an injection are currently stopped by Puma's request-line parser, and that
  # is not a guarantee this file should depend on.
  def body_for(location)
    escaped = CGI.escapeHTML(location)
    "<html><body>Moved Permanently: <a href=\"#{escaped}\">#{escaped}</a></body></html>"
  end

  # Returns the canonical "/dir/" path when this request is one of the duplicate
  # spellings, or nil when the request should pass through untouched.
  def canonical_target(env)
    return nil unless SAFE_METHODS.include?(env["REQUEST_METHOD"])

    path = env["PATH_INFO"].to_s
    DIRS.each do |dir|
      return "#{dir}/" if path == dir || path == "#{dir}/index.html"
    end
    nil
  end
end
```

#### `test/lib/static_index_redirect_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib", "static_index_redirect").to_s

# Unit tests for the redirect middleware, driven with a hand-built Rack env.
#
# Why not drive these through ActionDispatch::IntegrationTest: that stack parses
# and percent-encodes the URI before the middleware runs, so `<`, `>`, `"` and
# CR/LF arrive already neutralised and the assertions would pass vacuously.
# Puma does the same in production — it answers 400 to a request line carrying
# those bytes. That is precisely the dependency these tests exist to remove: the
# escaping has to be a property of this file, not of whatever parser happens to
# sit in front of it. Handing the middleware a raw env is the only altitude at
# which that can actually be asserted.
class StaticIndexRedirectTest < ActiveSupport::TestCase
  # Inner app stands in for ActionDispatch::Static; a 200 means "passed through".
  PASSTHROUGH = ->(env) { [200, { "content-type" => "text/html" }, ["STATIC:#{env["PATH_INFO"]}"]] }

  def call(path, method: "GET", query: "", script_name: "")
    StaticIndexRedirect.new(PASSTHROUGH).call(
      "PATH_INFO" => path,
      "REQUEST_METHOD" => method,
      "QUERY_STRING" => query,
      "SCRIPT_NAME" => script_name
    )
  end

  # ── redirect targets ────────────────────────────────────────────────────

  test "duplicate spellings redirect to the trailing-slash URL" do
    {
      "/safe" => "/safe/",
      "/safe/index.html" => "/safe/",
      "/privacy" => "/privacy/",
      "/privacy/index.html" => "/privacy/"
    }.each do |path, target|
      status, headers, = call(path)
      assert_equal 301, status, path
      assert_equal target, headers["location"], path
    end
  end

  test "the canonical spelling and everything else passes through" do
    %w[/safe/ /privacy/ /safe/sw.js /safe/icon.svg /safe/manifest.ko.webmanifest
       /api/safe_scan /safety /blog/safe].each do |path|
      status, = call(path)
      assert_equal 200, status, path
    end
  end

  test "only GET and HEAD are redirected" do
    assert_equal 301, call("/safe", method: "HEAD").first
    # Turning a POST into a 301 would silently drop the method and body.
    assert_equal 200, call("/safe", method: "POST").first
    assert_equal 200, call("/privacy/index.html", method: "PUT").first
  end

  test "SCRIPT_NAME is preserved for a sub-path mount" do
    _, headers, = call("/safe", script_name: "/app")
    assert_equal "/app/safe/", headers["location"]
  end

  # ── query string handling ───────────────────────────────────────────────

  test "the query string is preserved" do
    _, headers, = call("/safe", query: "v=20260719")
    assert_equal "/safe/?v=20260719", headers["location"]
  end

  test "CR and LF are stripped from the Location header" do
    _, headers, = call("/safe", query: "a=1\r\nX-Injected: yes")
    assert_no_match(/[\r\n]/, headers["location"])
    assert_equal "/safe/?a=1X-Injected: yes", headers["location"]
  end

  # ── 301 body escaping ───────────────────────────────────────────────────

  test "HTML metacharacters from the query string are escaped in the body" do
    _, _, body = call("/safe", query: %(x="><script>alert(1)</script>))
    html = body.first

    assert_not_includes html, "<script>"
    assert_includes html, "&lt;script&gt;"
    assert_includes html, "&quot;"
    # The anchor the template itself writes is the only markup left standing.
    assert_equal 1, html.scan("<a href=").length
    assert_equal 1, html.scan("</a>").length
  end

  test "an attribute-breaking payload cannot escape the href" do
    _, _, body = call("/safe", query: %(x=a" onmouseover="alert(1)))
    html = body.first

    assert_not_includes html, "onmouseover=\"alert"
    assert_includes html, "&quot;"
    # exactly two quote characters remain: the ones delimiting href="…"
    assert_equal 2, html.count('"')
  end

  test "ampersands and single quotes are escaped" do
    _, _, body = call("/safe", query: "x=a&b='c'")
    html = body.first

    assert_includes html, "&amp;"
    assert_not_includes html, "'"
  end

  test "percent-encoded payloads stay inert and unmangled" do
    encoded = "x=%22%3E%3Cscript%3E"
    _, headers, body = call("/safe", query: encoded)

    assert_equal "/safe/?#{encoded}", headers["location"]
    assert_includes body.first, encoded
    assert_not_includes body.first, "<script>"
  end

  test "an ordinary query string stays readable in the body" do
    _, _, body = call("/safe", query: "v=20260719")
    assert_includes body.first, %(<a href="/safe/?v=20260719">/safe/?v=20260719</a>)
  end

  # ── response shape ──────────────────────────────────────────────────────

  test "the redirect is not cached permanently by the browser" do
    _, headers, = call("/safe")
    assert_equal "no-cache", headers["cache-control"]
    assert_equal "text/html; charset=utf-8", headers["content-type"]
  end
end
```

#### `test/sw/offline_resilience.mjs`

```javascript
import { chromium } from 'playwright';
import server, { state } from './fault_server.mjs';

const BASE = 'http://localhost:4321/safe/';
const SW_FIXED = new URL('../../public/safe/sw.js', import.meta.url).pathname;
const SW_OLD   = process.argv[2] === '--old' ? true : false;
const LABEL    = SW_OLD ? 'PRE-FIX sw.js (expected to LOSE the offline shell)'
                        : 'FIXED sw.js (expected to KEEP the offline shell)';
state.swFile = SW_OLD ? new URL('./sw_old.js', import.meta.url).pathname : SW_FIXED;

const sleep = ms => new Promise(r => setTimeout(r, ms));
const results = [];
const check = (n, ok) => { results.push([n, ok]); console.log(`   ${ok ? 'OK  ' : 'FAIL'} ${n}`); return ok; };

const shellCaches = (page) => page.evaluate(async () => {
  const keys = (await caches.keys()).filter(k => k.startsWith('safefile-shell-'));
  const out = {};
  for (const k of keys) out[k] = (await (await caches.open(k)).keys()).map(r => new URL(r.url).pathname);
  return out;
});

const browser = await chromium.launch({ channel: 'chrome' });
const ctx = await browser.newContext();
const page = await ctx.newPage();

console.log(`\n══ ${LABEL} ══`);

// ── Phase 1: healthy install ────────────────────────────────────────────
state.failShell = false; state.swVersion = 1;
await page.goto(BASE, { waitUntil: 'load' });
await page.evaluate(() => navigator.serviceWorker.ready);
await sleep(2000);
const p1 = await shellCaches(page);
console.log('\n Phase 1 — healthy install');
console.log('   caches:', Object.keys(p1));
check('v1 shell cache exists', !!p1['safefile-shell-v2-1']);
check('v1 cache holds the shell', (p1['safefile-shell-v2-1'] || []).includes('/safe/'));

// ── Phase 2: update while '/safe/' is failing ───────────────────────────
state.failShell = true; state.swVersion = 2;
console.log("\n Phase 2 — update with '/safe/' returning 503");
await page.evaluate(async () => { const r = await navigator.serviceWorker.getRegistration(); await r.update().catch(()=>{}); });
await sleep(3500);

const p2 = await shellCaches(page);
console.log('   caches:', Object.keys(p2));
const keptOld = (p2['safefile-shell-v2-1'] || []).includes('/safe/');
check('previous version cache SURVIVES the failed update', keptOld);

// offline must still open the app
await ctx.setOffline(true);
let offlineShell = false, offlineShellV = false;
try { await page.goto(BASE, { waitUntil: 'domcontentloaded' }); offlineShell = !!(await page.$('.dropzone')); } catch (e) { console.log('   nav threw:', e.message.split('\n')[0]); }
try { await page.goto(BASE + '?v=20260719', { waitUntil: 'domcontentloaded' }); offlineShellV = !!(await page.$('.dropzone')); } catch (e) { console.log('   nav(?v) threw:', e.message.split('\n')[0]); }
await ctx.setOffline(false);
check('offline /safe/ still serves the shell', offlineShell);
check('offline /safe/?v=… still serves the shell', offlineShellV);

// ── Phase 3: recovery once the network is back ──────────────────────────
state.failShell = false;
console.log('\n Phase 3 — network restored');
await page.goto(BASE, { waitUntil: 'load' });
await page.evaluate(async () => { const r = await navigator.serviceWorker.getRegistration(); await r.update().catch(()=>{}); });
await sleep(3500);
await page.goto(BASE, { waitUntil: 'load' });
await sleep(1500);
const p3 = await shellCaches(page);
console.log('   caches:', Object.keys(p3));
check('v2 shell cache now exists', !!p3['safefile-shell-v2-2']);
check('v2 cache holds the shell', (p3['safefile-shell-v2-2'] || []).includes('/safe/'));
check('stale v1 cache is cleaned up', !p3['safefile-shell-v2-1']);

await ctx.setOffline(true);
let recovered = false;
try { await page.goto(BASE, { waitUntil: 'domcontentloaded' }); recovered = !!(await page.$('.dropzone')); } catch {}
await ctx.setOffline(false);
check('offline works again after recovery', recovered);

await browser.close();
server.close();

const failed = results.filter(([, ok]) => !ok);
console.log(`\n${failed.length === 0 ? 'ALL FAULT-INJECTION CHECKS PASS' : failed.length + ' FAILED: ' + failed.map(([n]) => n).join(' | ')}`);
process.exit(failed.length === 0 ? 0 : 1);
```

#### `test/sw/fault_server.mjs`

```javascript
// Static server for public/safe/ with two injectable faults:
//   state.failShell  -> '/safe/' answers 503 (simulates a transient network failure)
//   state.swVersion  -> substituted into sw.js's __SW_BUILD__ token, so changing it
//                       makes the browser see a genuinely new service worker
//   state.swFile     -> which sw.js source to serve (fixed vs. pre-fix)
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(new URL('../../public/safe', import.meta.url).pathname);
const PORT = 4321;
export const state = { failShell: false, swVersion: 1, swFile: path.join(ROOT, 'sw.js') };

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.svg': 'image/svg+xml',
  '.png': 'image/png', '.webmanifest': 'application/manifest+json' };

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  let p = url.pathname;

  if (p === '/safe/' || p === '/safe/index.html') {
    if (state.failShell) { res.writeHead(503); res.end('injected failure'); return; }
    p = '/safe/index.html';
  }
  if (p === '/safe/sw.js') {
    const src = fs.readFileSync(state.swFile, 'utf8').replace('__SW_BUILD__', String(state.swVersion));
    res.writeHead(200, { 'content-type': 'text/javascript', 'cache-control': 'no-cache' });
    res.end(src);
    return;
  }
  const file = path.join(ROOT, p.replace(/^\/safe\//, ''));
  if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404); res.end('nf'); return;
  }
  res.writeHead(200, { 'content-type': TYPES[path.extname(file)] || 'application/octet-stream',
                       'cache-control': 'no-cache' });
  res.end(fs.readFileSync(file));
});
server.listen(PORT);
export default server;
```

#### `test/integration/static_canonical_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"

# Regression guard for the 2026-09-17 Search Console finding on /safe/
# ("Duplicate page without user-selected canonical").
#
# The defect had two halves and both are covered here:
#   1. /safe, /safe/ and /safe/index.html each answered an identical 200,
#      because ActionDispatch::FileHandler resolves all three to
#      public/safe/index.html — and it runs BEFORE the router, so the
#      `get "/safe", to: redirect("/safe/")` route never fired.
#   2. public/safe/index.html carried no <link rel="canonical">, so Google had
#      no user-selected canonical to consolidate the duplicates onto.
class StaticCanonicalTest < ActionDispatch::IntegrationTest
  CANONICAL_SAFE = "https://slimfile.net/safe/"

  # ── 1. duplicate spellings collapse onto the trailing-slash URL ──────────

  test "/safe permanently redirects to /safe/" do
    get "/safe"
    assert_response :moved_permanently
    assert_equal "/safe/", response.headers["location"]
  end

  test "/safe/index.html permanently redirects to /safe/" do
    get "/safe/index.html"
    assert_response :moved_permanently
    assert_equal "/safe/", response.headers["location"]
  end

  test "the redirect preserves the query string" do
    # The home page links to /safe/?v=20260719 (cache-buster); a visitor who
    # lands on /safe?v=… must keep it rather than silently lose the param.
    get "/safe?v=20260719"
    assert_response :moved_permanently
    assert_equal "/safe/?v=20260719", response.headers["location"]
  end

  test "the redirect is not cached permanently by the browser" do
    # A pinned 301 is effectively irreversible client-side; this app has been
    # bitten by a pinned static cache before (lib/static_html_no_cache.rb).
    get "/safe"
    assert_equal "no-cache", response.headers["cache-control"]
  end

  test "/privacy and /privacy/index.html collapse the same way" do
    get "/privacy"
    assert_response :moved_permanently
    assert_equal "/privacy/", response.headers["location"]

    get "/privacy/index.html"
    assert_response :moved_permanently
    assert_equal "/privacy/", response.headers["location"]
  end

  test "an ordinary query string round-trips readably in the 301 body" do
    # Escaping of hostile input is covered at the middleware level in
    # test/lib/static_index_redirect_test.rb — this stack percent-encodes the
    # query before the middleware sees it, so raw bytes cannot be injected here.
    get "/safe", params: { v: "20260719" }
    assert_includes response.body, %(<a href="/safe/?v=20260719">/safe/?v=20260719</a>)
  end

  test "the canonical URL itself is served, not redirected" do
    get "/safe/"
    assert_response :success
    assert_includes response.body, "SafeFile"
  end

  test "assets under /safe/ are untouched by the redirect" do
    %w[/safe/sw.js /safe/icon.svg /safe/manifest.ko.webmanifest].each do |path|
      get path
      assert_response :success, "#{path} must not be redirected"
    end
  end

  # ── 2. the page declares its own canonical ──────────────────────────────

  test "/safe/ declares a self-referencing canonical with a trailing slash" do
    get "/safe/"
    assert_includes response.body, %(<link rel="canonical" href="#{CANONICAL_SAFE}">)
  end

  test "/safe/ declares x-default hreflang and nothing else" do
    # One URL serves all four languages via client-side i18n, so there is no
    # per-language URL to cross-reference. x-default self-reference is the only
    # hreflang that is true for this shape — adding ko/en/ja/es alternates
    # pointing at the same URL would be a false signal.
    get "/safe/"
    hreflangs = response.body.scan(/<link rel="alternate" hreflang="([^"]+)"/).flatten
    assert_equal ["x-default"], hreflangs
    assert_includes response.body,
                    %(<link rel="alternate" hreflang="x-default" href="#{CANONICAL_SAFE}">)
  end

  test "og:url matches the canonical URL" do
    get "/safe/"
    assert_includes response.body, %(<meta property="og:url" content="#{CANONICAL_SAFE}">)
  end

  test "/privacy/ keeps its own self-referencing canonical" do
    get "/privacy/"
    assert_includes response.body,
                    %(<link rel="canonical" href="https://slimfile.net/privacy/">)
  end

  # ── 3. the sitemap only ever advertises the canonical spelling ──────────

  test "sitemap lists /safe/ with a trailing slash and no duplicate spellings" do
    get "/sitemap.xml"
    assert_response :success
    assert_includes response.body, "<loc>https://slimfile.net/safe/</loc>"
    assert_not_includes response.body, "<loc>https://slimfile.net/safe</loc>"
    assert_not_includes response.body, "/safe/index.html"
    assert_not_includes response.body, "/safe/?v="
  end
end
```

#### `public/safe/index.html` — 서비스워커 등록부 (install 실패 처리 확인용)

```javascript
  // Register the offline-shell service worker. Best-effort; never blocks the UI.
  if ('serviceWorker' in navigator) {
    // When a NEW service worker takes control, reload once so open tabs pick up
    // the fresh shell instead of waiting for a manual reload. Guarded so the
    // first-visit claim (no prior controller) doesn't reload, and against loops.
    let swReloading = false;
    const hadController = !!navigator.serviceWorker.controller;
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      if (!hadController || swReloading) return;
      swReloading = true;
      window.location.reload();
    });
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('/safe/sw.js').then((reg) => {
        if (reg && reg.update) reg.update();   // proactive update check on each load
      }).catch(()=>{});
    });
  }

```

---

## ④ 정본 대조표 (이번 수정과 관련된 것만)

| 규칙 (DECISIONS.md) | 구현 위치 | 상태 |
|---|---|---|
| 셸을 필수/선택으로 나누고 필수 실패 시 install 실패 | `sw.js` install | 이번에 신설 |
| activate 는 새 셸 확인 후에만 구 캐시 삭제, 없으면 남긴다 | `sw.js` activate | 이번에 신설 |
| 301 본문·Location 방어를 상류 파서에 맡기지 않는다 | `static_index_redirect.rb` | 이번에 신설 |
| 이스케이프 검증은 통합이 아니라 Rack 단위 테스트로 | `test/lib/…_test.rb` | 이번에 신설 |
| SW 회귀 테스트는 수정 전 워커로도 돌려 실패 확인 (`--old`) | `test/sw/` | 이번에 신설 |
| 정적 HTML 1년 캐시 금지, 항상 재검증 | `lib/static_html_no_cache.rb` | 기존 유지 |
| SW HTML 은 network-first, 셸 고착 금지 | `sw.js` fetch | 기존 유지 |
| `/safe/` 는 로케일 프리픽스 없는 단일 URL, canonical 은 `/safe/` | `index.html` head | 기존 유지 |

## ⑤ 확신이 없는 지점 (이미 아는 것)

1. install 실패 시 `caches.open(SHELL_CACHE)` 가 만든 **빈/부분 캐시**가 남는다.
   실측으로 확인했다 — 실패 단계에서 `safefile-shell-v2-2` 가 비어 있는 채로 존재했고,
   네트워크 복구 후 정상적으로 채워지며 구버전이 정리됐다. **문제 없다고 판단했으나 확신은 보통.**
2. `activate` 에서 `shellReady` 가 false 면 구 캐시를 남긴다 → 그 activate 는 한 번만 실행되므로
   정리는 **다음 버전의 activate** 로 미뤄진다. 저장공간이 한 버전만큼 더 쓰인다.
   install 이 이제 셸을 보장하므로 실제로 발생하기 어렵다고 봤다.
3. `precache()` 가 `r.clone()` 을 넘기는데 원본 `r` 은 소비되지 않는다 (기존 코드에서 유지).
   불필요한 clone 이지만 동작상 무해하다고 판단.
4. 라운드 1 에서 (b)/(c) 로 판정한 것들(단일 URL 다국어 신호 · `public_file_server.enabled` 조건 ·
   301 의 `no-cache` · 공허한 단언 없음)은 이번에 바꾸지 않았다.

## 비밀값 스캔 결과

매치 2건, **둘 다 주석의 "token" 단어**이므로 통과:

| 줄 | 매치 | 판정 |
|---|---|---|
| 121 | `sw.js` 주석 "The build-time **token** below…" (`__SW_BUILD__` 플레이스홀더) | 값 아님 |
| 636 | `fault_server.mjs` 주석 "`__SW_BUILD__` **token**" | 값 아님 |

**비밀값 0건.** `.env` · `.env.production.local` · `config/master.key` · `.kamal/secrets` 미포함.
