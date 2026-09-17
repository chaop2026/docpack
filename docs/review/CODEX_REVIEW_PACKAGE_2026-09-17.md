# Codex 교차검증 패키지 — /safe/ canonical & URL de-duplication (2026-09-17)

> 비밀값 스캔: 이 패키지 작성 직후 `grep -nEi "api[_-]?key|secret|password|token|..."` 를
> 돌려 결과를 이 문서 말미에 적었다. `.env` · `config/master.key` · `.kamal/secrets` 는 포함하지 않았다.

---

## ① 리뷰어용 프롬프트

당신은 이 저장소를 처음 보는 **독립 코드 리뷰어**다. 아래 패키지만 근거로 판단하라.

**대상**: Rails 8.0.4 앱 `slimfile.net` 의 커밋 `d6d0655` (브랜치 `fix/safe-canonical-duplicate`).
아직 **배포되지 않았다**. 목적은 Google Search Console 이 `/safe/` 를
"Duplicate without user-selected canonical" 로 분류한 문제를 고치는 것.

**지적은 다음 4개로만 분류하라**:
`정책 위반` / `보안` / `데이터 손실 위험` / `논리 오류`

**규칙**:
- 모든 지적에 **파일:줄 근거**를 달아라. 근거 없는 지적은 적지 마라.
- 각 지적에 **확신도(높음/보통/낮음)** 를 표기하라. 낮아도 적되 낮다고 밝혀라.
- **여기 없는 파일은 추측하지 마라.** 필요하면 "경로 요청: <파일>" 이라고 적어라.
- 하지 말 것: 스타일 지적(rubocop-rails-omakase 가 고정한다), 일반론적 "테스트를 늘려라",
  정본 문서(DECISIONS.md)를 고치자는 제안.

**이 저장소가 반복해 당한 실패 유형** — 이 관점으로 특히 파고들어라:
1. **조용한 실패** — 실패했는데 성공처럼 보인다. (실제 사례: ① `get "/safe", to: redirect("/safe/")`
   라우트가 정적 핸들러에 가려 한 번도 실행되지 않았다. ② minitest 6 비호환으로 모든 테스트가
   죽었는데 "0 tests / 0 failures" 로 통과처럼 보였다. ③ Kamal secrets 파서가 `${VAR:-기본값}` 을
   실패시키지 않고 리터럴로 내보내 인증이 깨졌다.)
2. **캐시 고착** — 한 번 잘못 캐시되면 되돌릴 수 없다. (실제 사례: 정적 HTML 이
   `Cache-Control: public, max-age=1년` 로 서빙돼 배포가 방문자에게 도달하지 않았다.
   `lib/static_html_no_cache.rb` 가 그 대응이다. 서비스워커 셸 고착도 같은 계열.)
3. **공허한 검사** — 아무것도 검증하지 않는 테스트/단언.

**특히 답을 원하는 질문**:
- Q1. `StaticIndexRedirect` 가 `ActionDispatch::Static` **앞**에 들어가는데, 이 위치에서
  놓치거나 깨뜨리는 요청 경로가 있는가? (Propshaft 에셋, `/api/`, Active Storage,
  PWA 매니페스트/서비스워커, Rails 헬스체크 `/up`)
- Q2. 301 에 `cache-control: no-cache` 를 붙인 판단이 SEO 또는 동작상 문제가 되는가?
- Q3. 서비스워커에서 `SHELL_ASSETS` 의 `/safe/index.html` 을 제거하고 오프라인 폴백을
  `caches.match(request, {ignoreSearch:true})` → `caches.match('/safe/')` 로 바꿨다.
  **이미 구버전 SW 가 설치된 기존 방문자**에게 이 전환이 안전한가? 오프라인이 깨지는 경로가 있는가?
- Q4. 단일 URL 이 4개 언어를 클라이언트에서 전환하는 구조에서 `hreflang="x-default"` 자기참조
  하나만 두는 것이 맞는가, 아니면 다른 신호가 더 필요한가?
- Q5. `test/integration/static_canonical_test.rb` 에 **공허한 단언**이나 통과해도 아무것도
  보장하지 않는 테스트가 있는가?

**출력 형식**: 지적별로
```
[분류] [확신도] 제목
근거: <파일:줄>
설명: <왜 문제인가 / 어떤 입력에서 무엇이 잘못되는가>
```
마지막에 Q1~Q5 에 대한 답을 따로 적어라.

---

## ② 기준 커밋 이후 변경 요약

기준: `71dcd81` (main). 대상: `d6d0655`.

### 문제 (수정 전 라이브 상태, curl 로 실측)

동일 바이트(127,444 B)를 200 으로 돌려주는 URL 이 4개였고, 페이지에 `<link rel="canonical">` 이 **없었다**:

| URL | 어디서 발견되나 | 응답 |
|---|---|---|
| `/safe/` | sitemap.xml, 레이아웃 상단바 링크 | 200 |
| `/safe/?v=20260719` | **홈 카드 링크 (ko/en/ja/es 전부)** | 200 |
| `/safe` | 외부 링크·직접 입력 | 200 |
| `/safe/index.html` | `sw.js` 프리캐시 목록 | 200 |

`/ko/safe/`·`/en/safe/`·`/ja/safe/`·`/es/safe/` 는 **전부 404** (라이브 확인). 로케일 스코프는
`en|ja|es` 로 제한돼 있고 `/safe` 는 그 스코프 밖이다. 즉 **언어별 URL 이 존재하지 않는다** —
`/safe/` 한 URL 이 localStorage/navigator 기반으로 4개 언어를 클라이언트에서 전환한다.

### 변경 (도메인별)

- **SEO 메타** — `public/safe/index.html` head 에 canonical(`https://slimfile.net/safe/`),
  `hreflang="x-default"` 자기참조, robots, og:*, twitter:* 추가.
- **URL 정규화** — `lib/static_index_redirect.rb` (신규 Rack 미들웨어) +
  `config/initializers/static_index_redirect.rb`. `/safe`·`/safe/index.html`·
  `/privacy`·`/privacy/index.html` → 트레일링 슬래시 URL 로 301.
- **죽은 코드 제거** — `config/routes.rb` 의 `get "/safe", to: redirect("/safe/")`.
- **서비스워커** — `SHELL_ASSETS` 에서 `/safe/index.html` 제거, 오프라인 폴백 변경.
- **sitemap** — `/safe/` 항목에 `x-default` 알터네이트 추가.
- **테스트 인프라** — `Gemfile` 에 `minitest "~> 5.25"` 핀(비호환으로 전 테스트가 죽어 있었다).
- **회귀 테스트** — `test/integration/static_canonical_test.rb` 신규 12개.

---

## ③ 핵심 파일 전문

#### `lib/static_index_redirect.rb`

```ruby
# frozen_string_literal: true

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

    # SCRIPT_NAME is "" for a root-mounted app (the case here), but including it
    # keeps the Location correct if this app is ever mounted under a sub-path.
    query = env["QUERY_STRING"].to_s
    location = "#{env["SCRIPT_NAME"]}#{target}"
    location = "#{location}?#{query}" unless query.empty?

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
      ["<html><body>Moved Permanently: <a href=\"#{location}\">#{location}</a></body></html>"]
    ]
  end

  private

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

#### `config/initializers/static_index_redirect.rb`

```ruby
# frozen_string_literal: true

# Insert StaticIndexRedirect in front of the static file server so `/safe`,
# `/safe/index.html` (and the same pair for /privacy) 301 to the single
# canonical `/safe/` instead of each answering an identical 200.
# See lib/static_index_redirect.rb for the full rationale.
#
# Order vs StaticHtmlNoCache: both insert before ActionDispatch::Static, and
# initializers load alphabetically (static_html_no_cache → static_index_redirect),
# so this one ends up the *inner* of the two — the 301 travels back out through
# StaticHtmlNoCache. That is harmless: the rewriter only touches responses
# carrying `public, max-age=…`, and this 301 sends `no-cache`.
#
# Guarded so it is a no-op when ActionDispatch::Static is not in the stack
# (i.e. when a front-end proxy serves public/ instead of this app).
require Rails.root.join("lib", "static_index_redirect").to_s

Rails.application.config.middleware.insert_before(
  ActionDispatch::Static, StaticIndexRedirect
) if Rails.application.config.public_file_server.enabled
```

#### `lib/static_html_no_cache.rb`

```ruby
# frozen_string_literal: true

# Rack middleware that downgrades the far-future Cache-Control on *static HTML*
# files to `no-cache`, so returning visitors always revalidate the HTML and a
# deploy reaches them immediately (a stale cached ETag/Last-Modified still gets
# a cheap 304, so unchanged pages cost no bandwidth).
#
# Why this exists: `config.public_file_server.headers` applies ONE header hash
# to every file under public/ (assets AND html). That is correct for digest-
# stamped assets (immutable, safe to cache for a year) but catastrophic for
# HTML entrypoints like /safe/ and /privacy/ — once a browser caches them with
# `max-age=1.year` it will not even ask the server again for up to a year.
#
# This middleware sits in front of ActionDispatch::Static and rewrites ONLY the
# responses that carry the static long-cache signature (`public, max-age=…`)
# AND are `text/html`. That precisely targets static HTML files and leaves:
#   - digest-stamped assets  → not text/html, untouched (keep long cache)
#   - dynamic Rails pages     → no `public, max-age` header, untouched
#   - sitemap.xml             → application/xml, untouched (keeps its own 3600)
class StaticHtmlNoCache
  # Serve stored copy but always revalidate first. Conditional GET via
  # Last-Modified/ETag still yields 304 when the file is unchanged.
  REVALIDATE = "no-cache"

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    rewrite!(headers, env["PATH_INFO"].to_s)
    [status, headers, body]
  end

  private

  # Paths that, like static HTML, must always revalidate so a deploy reaches
  # returning visitors immediately:
  #   - the service worker (/safe/sw.js): a 1-year-cached SW would pin an old
  #     app shell / caching logic on returning visitors — the very failure this
  #     middleware exists to prevent, one layer deeper.
  #   - PWA manifests (*.webmanifest): small, occasionally-edited metadata.
  # Digest-stamped assets and immutable icons keep their long cache.
  REVALIDATE_PATHS = /\/sw\.js\z|\.webmanifest\z/i

  def rewrite!(headers, path)
    content_type = lookup(headers, "content-type")
    is_html = content_type&.downcase&.include?("text/html")
    return unless is_html || path =~ REVALIDATE_PATHS

    cache_control = lookup(headers, "cache-control")
    return unless cache_control
    # only touch the far-future static header (public + a max-age), never the
    # `private/must-revalidate` that dynamic responses already carry.
    return unless cache_control =~ /\bpublic\b/i && cache_control =~ /max-age=\s*\d+/i

    assign(headers, "cache-control", REVALIDATE)
  end

  # Case-insensitive header access that works for both a plain Hash (Rack 2)
  # and Rack::Headers (Rack 3, already case-insensitive).
  def lookup(headers, name)
    return headers[name] if headers.key?(name)
    key = headers.keys.find { |k| k.to_s.casecmp?(name) }
    key && headers[key]
  end

  def assign(headers, name, value)
    key = headers.key?(name) ? name : (headers.keys.find { |k| k.to_s.casecmp?(name) } || name)
    headers[key] = value
  end
end
```

#### `config/initializers/static_html_no_cache.rb`

```ruby
# frozen_string_literal: true

# Insert StaticHtmlNoCache in front of the static file server so static HTML
# entrypoints (/safe/, /privacy/, static blog posts) are served `no-cache`
# instead of inheriting the 1-year `public_file_server.headers` meant for
# digest-stamped assets. See lib/static_html_no_cache.rb for the full rationale.
#
# Only relevant when this app serves static files itself (RAILS_SERVE_STATIC_FILES
# in production; enabled by default in dev/test). Guarded so it is a no-op when
# ActionDispatch::Static is not in the stack.
require Rails.root.join("lib", "static_html_no_cache").to_s

Rails.application.config.middleware.insert_before(
  ActionDispatch::Static, StaticHtmlNoCache
) if Rails.application.config.public_file_server.enabled
```

#### `config/routes.rb`

```ruby
Rails.application.routes.draw do
  # Permanent slug renames for the static SafeFile guide posts. These must come
  # before the "/blog/:slug" route below so they win; after the folder rename the
  # old paths no longer resolve as static files and fall through to here.
  # 301 (redirect default) — never reverse. Rails matches the routes with or
  # without a trailing slash, so both /blog/rrn-masking and /blog/rrn-masking/
  # are covered. The locale prefix is preserved in the target so a Spanish reader
  # stays in Spanish (/es/blog/contract-checklist → /es/blog/contract-sharing-checklist/).
  OLD_BLOG_SLUGS = {
    "rrn-masking"        => "resident-number-masking",
    "contract-checklist" => "contract-sharing-checklist"
  }.freeze

  OLD_BLOG_SLUGS.each do |old_slug, new_slug|
    get "/blog/#{old_slug}", to: redirect("/blog/#{new_slug}/")
    %w[en ja es].each do |loc|
      get "/#{loc}/blog/#{old_slug}", to: redirect("/#{loc}/blog/#{new_slug}/")
    end
  end

  # Locale-prefixed public pages. Korean (default) uses bare paths; the
  # constraint only matches en/ja/es, so /ko/... never resolves here.
  scope "(:locale)", locale: /en|ja|es/ do
    root "pages#home"

    resources :conversions, only: [:create, :show] do
      member do
        get :download
      end
    end

    get "/compress", to: "pages#compress"
    get "/pdf",      to: "pages#pdf"
    get "/social",   to: "pages#social"
    get "/about",    to: "pages#about"
    get "/faq",      to: "pages#faq"

    get "/blog",       to: "posts#index", as: :blog
    get "/blog/:slug", to: "posts#show",  as: :blog_post
  end

  # SafeFile — public/safe/index.html은 Rails가 정적 서빙(언어 독립 단일 URL),
  # API는 AI 정밀 검사 중계. 로케일 프리픽스 없음.
  #
  # `get "/safe", to: redirect("/safe/")` 는 여기 있었지만 **한 번도 실행된 적이 없다**
  # (2026-09-17 제거). ActionDispatch::Static 이 라우터보다 앞에 있고,
  # FileHandler 가 `/safe` 요청을 `public/safe/index.html` 로 해석해 200 을 먼저
  # 돌려주기 때문이다. 트레일링 슬래시 정규화는 정적 핸들러보다 앞서야 하므로
  # Rack 미들웨어(lib/static_index_redirect.rb)로 옮겼다.
  post "/api/safe_scan", to: "api/safe_scan#create"

  namespace :admin do
    get  "login",  to: "sessions#new",     as: :login
    post "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    resources :posts do
      member do
        post :generate
        post :improve
        post :publish
      end
      collection do
        post :auto_generate
      end
    end

    resources :banners do
      member do
        patch :toggle
        patch :move
      end
    end

    resources :blog_styles do
      member do
        post :analyze
        post :toggle
      end
    end

    root to: "banners#index"
  end

  get "sitemap.xml", to: "pages#sitemap", as: :sitemap, defaults: { format: :xml }

  get "up" => "rails/health#show", as: :rails_health_check
end
```

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

// Minimal app shell precached on install (UI must open offline).
// '/safe/index.html' is deliberately absent: since 2026-09-17 it 301s to
// '/safe/' (lib/static_index_redirect.rb, SEO de-duplication). cache.put()
// rejects a redirected Response, so precaching it could only ever be a silent
// no-op — and the offline fallback below now points at '/safe/' instead.
const SHELL_ASSETS = [
  '/safe/',
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
        // Offline fallback. `ignoreSearch` matters: the home page links to
        // /safe/?v=… (cache-buster), and without it that navigation would miss
        // the precached '/safe/' entry and fall through to the shell below.
        .catch(() => caches.match(request, { ignoreSearch: true }).then((r) => r || caches.match('/safe/')))
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

#### `app/views/pages/sitemap.xml.erb`

```erb
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml">
<%
  default   = I18n.default_locale
  ui_locales = I18n.available_locales                 # [:ko, :en, :ja, :es] — fully translated UI
  prefix = ->(loc, path) { loc == default ? path : "/#{loc}#{path == '/' ? '' : path}" }

  # Fully localized UI pages: [path, changefreq, priority]
  ui_pages = [
    ["/",         "daily",   "1.0"],
    ["/compress", "weekly",  "0.9"],
    ["/pdf",      "weekly",  "0.9"],
    ["/social",   "weekly",  "0.9"],
    ["/about",    "monthly", "0.7"],
    ["/faq",      "monthly", "0.7"],
    ["/blog",     "daily",   "0.8"],
  ]
%>
<% ui_pages.each do |path, changefreq, priority| %>
  <% ui_locales.each do |loc| %>
  <url>
    <loc><%= @base_url %><%= prefix.(loc, path) %></loc>
    <lastmod><%= Date.today.iso8601 %></lastmod>
    <changefreq><%= changefreq %></changefreq>
    <priority><%= priority %></priority>
    <% ui_locales.each do |alt| %>
    <xhtml:link rel="alternate" hreflang="<%= alt %>" href="<%= @base_url %><%= prefix.(alt, path) %>"/>
    <% end %>
    <xhtml:link rel="alternate" hreflang="x-default" href="<%= @base_url %><%= prefix.(default, path) %>"/>
  </url>
  <% end %>
<% end %>
<%# Category listing pages — currently privacy (SafeFile guides). 4 UI locales. %>
<% category_pages = %w[privacy] %>
<% category_pages.each do |cat| %>
  <% ui_locales.each do |loc| %>
  <url>
    <loc><%= @base_url %><%= prefix.(loc, "/blog") %>?category=<%= cat %></loc>
    <lastmod><%= Date.today.iso8601 %></lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.6</priority>
    <% ui_locales.each do |alt| %>
    <xhtml:link rel="alternate" hreflang="<%= alt %>" href="<%= @base_url %><%= prefix.(alt, "/blog") %>?category=<%= cat %>"/>
    <% end %>
    <xhtml:link rel="alternate" hreflang="x-default" href="<%= @base_url %><%= prefix.(default, "/blog") %>?category=<%= cat %>"/>
  </url>
  <% end %>
<% end %>
<% Post.published.recent.each do |post| %>
  <% lastmod = (post.updated_at || post.published_at)&.to_date&.iso8601 %>
  <%# Only emit locales the post is actually translated into — untranslated
      (ja/es always, en unless body_en present) URLs carry noindex, so keeping
      them out of the sitemap avoids indexing empty/mismatched pages. %>
  <% locales = post.translated_locales %>
  <% locales.each do |loc| %>
  <url>
    <loc><%= @base_url %><%= prefix.(loc, "/blog/#{post.slug}") %></loc>
    <lastmod><%= lastmod %></lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.6</priority>
    <% locales.each do |alt| %>
    <xhtml:link rel="alternate" hreflang="<%= alt %>" href="<%= @base_url %><%= prefix.(alt, "/blog/#{post.slug}") %>"/>
    <% end %>
    <xhtml:link rel="alternate" hreflang="x-default" href="<%= @base_url %><%= prefix.(default, "/blog/#{post.slug}") %>"/>
  </url>
  <% end %>
<% end %>
  <%# Single-URL static pages. /safe/ serves all four languages from ONE URL
      (client-side i18n), so there is no per-language URL to cross-reference:
      x-default self-reference is the only hreflang Google documents for this
      shape. The trailing slash is mandatory — /safe and /safe/index.html now
      301 here (lib/static_index_redirect.rb) and must never enter the sitemap. %>
  <url>
    <loc><%= @base_url %>/safe/</loc>
    <lastmod><%= Date.today.iso8601 %></lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.9</priority>
    <xhtml:link rel="alternate" hreflang="x-default" href="<%= @base_url %>/safe/"/>
  </url>
  <url>
    <loc><%= @base_url %>/privacy/</loc>
    <lastmod><%= Date.today.iso8601 %></lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.5</priority>
  </url>
</urlset>
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

#### `public/safe/index.html` — head 부분만 (전체 127KB, 나머지는 스타일 + 인라인 JS)

```html
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#F7F5EF">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="default">
<meta name="apple-mobile-web-app-title" content="SafeFile">
<meta name="application-name" content="SafeFile">
<link rel="manifest" href="/safe/manifest.ko.webmanifest" id="manifestLink">
<link rel="icon" type="image/svg+xml" href="/safe/icon.svg">
<link rel="icon" type="image/png" sizes="192x192" href="/safe/icon-192.png">
<link rel="apple-touch-icon" href="/safe/apple-touch-icon.png">
<title>SafeFile — 문서 속 개인정보, 1분 안에 지우고 공유</title>
<meta name="description" content="문서를 올리면 원본 모습 그대로 두고 개인정보 위치에만 검은 바를 덮어 새 문서로 만들어 드립니다. 무료, 회원가입 없음.">
<meta name="robots" content="index,follow">
<!-- Canonical / hreflang.
     이 페이지는 **단일 URL 이 4개 언어(ko/en/ja/es)를 클라이언트에서 전환**하는 구조다
     (localStorage → navigator.language). 따라서 언어별 URL 이 존재하지 않으므로
     언어 간 상호참조 hreflang 은 가리킬 대상이 없다. Google 이 이 구조에 대해 문서화한
     패턴은 x-default 자기참조 하나뿐이다 ("특정 언어/지역을 대상으로 하지 않는 페이지").
     canonical 은 트레일링 슬래시가 붙은 /safe/ 로 고정한다 — /safe, /safe/index.html,
     /safe/?v=... 이 모두 동일 바이트를 200 으로 반환하므로, 이 태그가 없으면
     Google 이 "사용자가 선택한 표준이 없는 중복 페이지"로 분류한다. -->
<link rel="canonical" href="https://slimfile.net/safe/">
<link rel="alternate" hreflang="x-default" href="https://slimfile.net/safe/">
<meta property="og:type" content="website">
<meta property="og:site_name" content="SafeFile">
<meta property="og:url" content="https://slimfile.net/safe/">
<meta property="og:title" content="SafeFile — 문서 속 개인정보, 1분 안에 지우고 공유">
<meta property="og:description" content="문서를 올리면 원본 모습 그대로 두고 개인정보 위치에만 검은 바를 덮어 새 문서로 만들어 드립니다. 무료, 회원가입 없음.">
<meta property="og:image" content="https://slimfile.net/safe/icon-512.png">
<meta property="og:locale" content="ko_KR">
<meta property="og:locale:alternate" content="en_US">
<meta property="og:locale:alternate" content="ja_JP">
<meta property="og:locale:alternate" content="es_ES">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="SafeFile — 문서 속 개인정보, 1분 안에 지우고 공유">
<meta name="twitter:description" content="문서를 올리면 원본 모습 그대로 두고 개인정보 위치에만 검은 바를 덮어 새 문서로 만들어 드립니다. 무료, 회원가입 없음.">
<meta name="twitter:image" content="https://slimfile.net/safe/icon-512.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+KR:wght@400;500;700&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
```

#### `public/safe/index.html` — 언어 감지 / applyLang (본문 i18n 방식 확인용)

```javascript
}
};
const LANGS = ['ko','en','ja','es'];
function detectLang(){
  try { const s = localStorage.getItem('safefile_lang'); if (s && LANGS.includes(s)) return s; } catch(e){}
  const n = (navigator.language||'ko').toLowerCase();
  for (const l of LANGS) if (n.startsWith(l)) return l;
  return 'ko';
}
let LANG = detectLang();
const T = () => I18N[LANG];
setInterval(()=>{cw=(cw+1)%T().cycle.length;const el=$('cycleWord');if(el)el.textContent=T().cycle[cw];},3600);

/* ───────── apply language ───────── */
function applyLang(){
  document.documentElement.lang=LANG;
  try { localStorage.setItem('safefile_lang', LANG); } catch(e){}
  const sel=$('langSel'); if(sel) sel.value=LANG;
  document.querySelectorAll('[data-i18n]').forEach(el=>{
    const k=el.dataset.i18n; const v=T()[k];
    if(typeof v==='string') el.innerHTML=v;
  });
  document.querySelectorAll('[data-i18n-ph]').forEach(el=>{const v=T()[el.dataset.i18nPh];if(typeof v==='string')el.placeholder=v;});
  document.querySelectorAll('[data-i18n-aria]').forEach(el=>{const v=T()[el.dataset.i18nAria];if(typeof v==='string')el.setAttribute('aria-label',v);});
  $('pasteArea').placeholder=T().pastePh;
  const ml=$('manifestLink'); if(ml) ml.href=`/safe/manifest.${LANG}.webmanifest`;
  if(typeof refreshInstallBanner==='function') refreshInstallBanner();
  buildWmPresets();
  renderHero(); renderList(); buildPreview();
  // keep the result viewer in sync (fit label + fullscreen aria are language-dependent)
  if(typeof rvPages!=='undefined' && rvPages.length && $('result') && $('result').style.display!=='none'){
    const b=$('rvFull'); if(b&&rvIsFull) b.setAttribute('aria-label',T().rvExitAria);
    rvRender();
  }
}
$('langSel').addEventListener('change',e=>{LANG=e.target.value;applyLang();});

```

#### `app/views/pages/home.html.erb` — /safe/ 카드 링크

```erb
    <% end %>

    <%# ?v busts the browser cache for returning visitors who previously cached
        /safe/ under the old 1-year Cache-Control (a new URL = new cache key, so
        it bypasses the poisoned entry and picks up the new no-cache header).
        SEO note (2026-09-17): this makes /safe/?v=20260719 a second crawlable
        URL for the same bytes, which is half of why GSC reported /safe/ as a
        duplicate. It is now consolidated by the <link rel=canonical> on the
        page itself — the standard fix for query-parameter duplicates.
        Expiry: the poisoned entries can only have been written between
        2026-07-15 (SafeFile launch) and 2026-07-19 (bd5a111, the no-cache fix),
        so they all lapse by 2027-07-19. Drop the ?v after that date and this
        link becomes the canonical URL outright. %>
    <%= link_to "/safe/?v=20260719", class: "feature-card feature-card--safe" do %>
      <div class="feature-card-icon">🔒</div>
      <span class="feature-card-tag">PRIVACY</span>
      <div class="feature-card-title"><%= t("home.safe") %></div>
      <p class="feature-card-desc"><%= t("safe.description") %></p>
      <span class="feature-card-btn"><%= t("safe.submit") %></span>
    <% end %>
  </nav>

  <%= render_banners(page: "all", position: "after_result") %>
```

#### `Gemfile` — test 그룹

```ruby

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Pinned to 5.x: minitest 6 calls `runnable.run(reporter, options, …)` with an
  # extra argument, but railties 8.0.4 prepends its own 2-arity `run` via
  # rails/test_unit/line_filtering.rb. Resolving to 6.x makes EVERY Rails test
  # abort with "wrong number of arguments (given 3, expected 1..2)" before a
  # single assertion runs — which is why the suite silently reported "0 tests".
  # Revisit when Rails ships minitest 6 support. (Found 2026-09-17.)
  gem "minitest", "~> 5.25"
end
```

#### 미들웨어 스택 실측 (`bin/rails middleware`, 상위 8줄)

```
use ActionDispatch::HostAuthorization
use Rack::Sendfile
use StaticHtmlNoCache
use StaticIndexRedirect
use ActionDispatch::Static
use Propshaft::Server
use ActionDispatch::Executor
... (Rack::Head 는 훨씬 안쪽, 라우터 직전에 있다)
```

---

## ④ 정본 대조표

| 규칙 (DECISIONS.md / CLAUDE.md) | 구현 위치 | 지금 아는 상태 |
|---|---|---|
| `/safe/` 는 **로케일 프리픽스 없는 단일 URL**. 언어는 클라이언트 전환 | `config/routes.rb` 주석, `public/safe/index.html` `detectLang()` | 유지. 언어별 URL 신설은 **기각·보류**로 DECISIONS.md 에 기록 |
| 정적 HTML 은 **1년 캐시 금지**, 항상 재검증 | `lib/static_html_no_cache.rb` | 유지. 새 301 은 `no-cache` 를 직접 지정 |
| 서비스워커 HTML 은 **network-first**, 셸 고착 금지 | `public/safe/sw.js` | 유지. `CACHE_VERSION` 은 Dockerfile 이 빌드 시각으로 치환 |
| 홈의 `?v=20260719` 는 2026-07-15~07-19 사이 고착된 1년 캐시 대응. **2027-07-19 이후 제거** | `app/views/pages/home.html.erb` | 유지 + canonical 로 통합 |
| SafeFile 출력은 래스터 flatten, 처리는 브라우저 내부 | (이번 변경과 무관) | 건드리지 않음 |

## ⑤ 확신이 없는 지점 (이미 아는 것 — 다시 발견할 필요 없음)

1. **Googlebot 은 `navigator.language` 가 en-US 라 영어로 렌더된다.** 그런데 서빙되는 원시
   HTML 의 `<title>`·`description` 은 한국어이고 `applyLang()` 은 title/description 을
   갱신하지 않는다. 즉 **색인 제목(한국어) 과 렌더 본문(영어) 이 불일치**한다.
   이번 커밋에서 **일부러 건드리지 않았다** — JS 로 title 을 바꾸면 Google 이 영어 제목을
   색인해 한국어 검색 노출이 떨어질 수 있어서, 별도 판단이 필요하다고 봤다.
   **이 판단이 맞는지 의견을 달라.**
2. `StaticIndexRedirect::DIRS` 는 대소문자를 구분한다. 프로덕션은 Linux 라 `/SAFE` 는 404 지만,
   개발용 macOS 는 대소문자 무시 파일시스템이라 `/SAFE` 가 200 일 수 있다. 무시하기로 했다.
3. 301 응답 본문을 GET/HEAD 구분 없이 같이 만든다. Puma 가 HEAD 에서 본문을 잘라내는 것을
   raw socket 으로 확인했으나(`content-length: 72`, 본문 없음), Rack::Head 가 이 미들웨어보다
   **안쪽**에 있다는 사실은 그대로다.
4. 미들웨어가 파일 존재 여부를 확인하지 않는다. `public/safe/` 가 사라지면 `/safe` 는
   301 후 404 가 된다(현재는 바로 404). 허용 가능하다고 판단.

## 비밀값 스캔 결과

```
grep -nEi "api[_-]?key|secret|password|token|BEGIN [A-Z ]*PRIVATE KEY|AKIA|ghp_|sk-[A-Za-z0-9]{20}" \
  docs/review/CODEX_REVIEW_PACKAGE_2026-09-17.md
```

매치 4건, **전부 값이 아닌 산문·주석**이므로 통과:

| 줄 | 매치 | 판정 |
|---|---|---|
| 3, 4 | 스캔 명령 자체를 인용한 머리말 | 값 아님 |
| 29 | "Kamal secrets 파서가 …" — 실패 유형 설명 문장 | 값 아님 |
| 411 | `sw.js` 주석의 "The build-time **token** below…" (`__SW_BUILD__` 플레이스홀더를 가리킴) | 값 아님 |

**비밀값 0건.** `.env` · `.env.production.local` · `config/master.key` · `.kamal/secrets` 는
어느 것도 이 패키지에 포함되지 않았다.
