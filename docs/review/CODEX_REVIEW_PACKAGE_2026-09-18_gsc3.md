# Codex 교차검증 패키지 — GSC 실제 URL 3건 + Codex 신규 2건 · 2026-09-18

> 비밀값 스캔 결과는 문서 말미.

## ① 리뷰어용 프롬프트

당신은 **독립 코드 리뷰어**다. 아래 패키지만 근거로 판단하라.

**맥락**: Rails 8.0.4 앱 `slimfile.net`, 커밋 `a504e39` (브랜치 `fix/blog-indexing-signals`).
아직 배포되지 않았다. **프로덕션 DB 는 건드리지 않았다.**

두 묶음을 한 번에 다뤘다.

**묶음 A — 직전 라운드에서 당신이 낸 신규 2건**
> **N-1 [논리 오류][확신도 보통]** Article JSON-LD 의 `url` 과 `mainEntityOfPage.@id` 가
> 영어 정본 페이지에서도 한국어 URL 로 고정됩니다. canonical 과 구조화 데이터가 서로 다른
> 정본을 말합니다.
> **N-2 [논리 오류][확신도 낮음]** `body_en` 만 있고 `body_ko` 가 없는 published 글이 생기면
> x-default 가 noindex URL 을 가리킬 수 있습니다. 모델 검증이 `body_ko` 를 요구하지 않습니다.

**묶음 B — GSC 가 실제 URL 3건을 공개**
직전 세션에서 내가 낸 **추정 3건은 전부 틀렸다.** 실제:
- 404 1건 = `https://slimfile.net/api/safe_scan` (최종 크롤 2026-08-31, 최초 감지 2026-09-05)
- 중복(구글이 다른 표준 선택) 2건 = `https://slimfile.net/en/about` (2026-08-16),
  `https://slimfile.net/blog/contract-checklist/` (2026-07-18, **트레일링 슬래시**)

**지적 분류 고정**: `정책 위반` / `보안` / `데이터 손실 위험` / `논리 오류`

**규칙**:
- 모든 지적에 **파일:줄 근거**. 근거 없는 지적은 적지 마라.
- **확신도(높음/보통/낮음)** 표기.
- **여기 없는 파일은 추측하지 마라.** 필요하면 "경로 요청: <파일>".
- 하지 말 것: 스타일 지적, 일반론적 "테스트를 늘려라", 정본 문서를 고치자는 제안.

**이 저장소가 반복해 당한 실패 유형** (이 관점으로 파고들어라):
1. **조용한 실패** — 실패했는데 성공처럼 보인다.
   (이번 세션 실제 사례: 미들웨어를 추가한 뒤 **이니셜라이저가 dev 에서 리로드되지 않아**
   측정값이 전부 "수정 전"이었고 마치 수정이 아무 효과도 없는 것처럼 읽혔다. 재시작 후 해결.)
2. **암묵적 상류 의존** — 안전의 근거가 우리 코드 밖에 있다.
3. **공허한 검사** — 아무것도 검증하지 않는 테스트/단언.
4. **죽은 코드** — 라우트/설정이 앞 레이어에 가려 한 번도 실행되지 않는다.

**특히 답을 원하는 질문**:
- Q1. `CanonicalPathRedirect` 가 **두 방향 규칙**(정적 디렉터리는 슬래시 유지, 라우팅된
  페이지는 슬래시 제거)을 한 클래스에 담았다. 빠져나가거나 잘못 잡는 경로가 있는가?
  (Propshaft 에셋, Active Storage `/rails/...`, `/up`, `/admin`, `.webmanifest`, `/api/`)
- Q2. 구 슬러그(`/blog/contract-checklist/`)가 **2홉**이 되는 것을 받아들였다.
  슬러그 표를 미들웨어로 옮기면 1홉이지만 `routes.rb` 가 죽은 코드가 된다. 이 트레이드오프가 옳은가?
- Q3. `/api/*` 를 **robots.txt Disallow** 로 막았다(X-Robots-Tag 아님). 옳은가?
  Googlebot 이 인라인 JS 문자열에서 URL 을 수확한 것이 원인인데, 다른 대응이 더 나은가?
- Q4. `/about` 을 **hreflang 0개 + 프리픽스 URL noindex + canonical `/about`** 으로 처리했다.
  `/faq`·`/compress`·`/` 는 진짜 번역이라 4로케일 유지. 이 구분이 옳은가?
  x-default 조차 넣지 않은 판단은?
- Q5. `validates :body_ko, presence: true, if: -> { status == "published" }` 가
  기존 발행 경로(`publish!`, `PublishScheduledPostsJob`)를 깨뜨리지 않는가?
- Q6. JSON-LD URL 필드를 전수 확인했다고 주장한다(3개 블록, URL 필드는 2개뿐). 검증해달라.
- Q7. 테스트에 **공허한 단언**이 있는가? 특히 트레일링 슬래시·JSON-LD·about 테스트.

**출력 형식**:
```
[N-1 판정] 해소됨 | 부분 해소 | 미해소
근거: <파일:줄>
설명: ...

[N-2 판정] ...
[B-404 판정] 적절 | 부적절     (api/safe_scan 대응)
[B-중복 판정] 적절 | 부적절     (트레일링 슬래시 + /en/about 대응)
```
그 다음 **새 지적**(있으면), 마지막에 Q1~Q7 답변.

---

## ② 실측 요약 (전부 라이브 HTTP 또는 코드 근거)

### B1 — `/api/safe_scan` 발견 경로
사이트 전체에서 이 URL 의 **유일한 등장은 인라인 JS 문자열 리터럴**:
`public/safe/index.html:1702` 의 `fetch('/api/safe_scan',{`.
`<a href>`·form action·sitemap(0)·llms.txt(0) 어디에도 없다.
`GET` → **404** (라우트가 POST 전용), `POST` → 400.
`bin/rails routes` 전수: `/api/*` 는 `POST /api/safe_scan` **하나뿐**.
`robots.txt` 에 `/api` Disallow 가 **없었다**.

### B3/B4 — 트레일링 슬래시 (리다이렉트 미추적 실측)
- 글 URL **168/168** (42글 × 4로케일) 이 슬래시 유무 양쪽 다 **진짜 200**
- 그 외 **32경로** 동일 (`/about/`, `/blog/`, `/en/`, `/faq/`, … `/sitemap.xml/` 포함)
- **레이어 판별**: `/about/` 응답에 CSRF 메타 태그가 있다(=레이아웃 렌더=**라우터**).
  `public/` 의 디렉터리는 `safe`·`privacy` **둘뿐**이라 Static 이 잡을 수 없다.

### B5 — `/about` 은 미번역이 아니라 **번역 대상이 아님**
본문 유사도 실측(한국어판 대비):

| 페이지 | /en | /ja | /es | ko 한글비율 |
|---|---|---|---|---|
| `/about` | **0.935** | **0.941** | **0.922** | **0.05** |
| `/faq` | 0.325 | 0.384 | 0.281 | 0.44 |
| `/compress` | 0.338 | 0.353 | 0.323 | 0.44 |
| `/` | 0.286 | 0.350 | 0.305 | 0.47 |

`about.html.erb` 는 `t()` 호출이 **하나도 없는 하드코딩 영어**, `config/locales` 에
`about.*` 키 **없음**. `/faq`·`/compress`·`/` 는 진짜 번역이다.

### A3 — `body_en` 채운 상태 실측 (개발 DB, 실제 HTTP, 원복 확인)

| URL | canonical | JSON-LD url/@id | 일치 | robots |
|---|---|---|---|---|
| `/blog/resume-privacy` (±AL=en) | `/blog/resume-privacy` | 동일 | ✅ | 없음 |
| `/en/blog/resume-privacy` (±AL=ko) | `/en/blog/resume-privacy` | 동일 | ✅ | 없음 |
| `/ja/blog/resume-privacy` | `/blog/resume-privacy` | 동일 | ✅ | `noindex,follow` |

x-default → `/blog/resume-privacy`, robots 없음(색인 가능). 원복 후 TEMP 마커 0건.

### 수정 후 재측정
- 트레일링 슬래시 66경로 → **중복 200: 0개**. `/safe/`·`/privacy/`·`/` 유지, `/about///` 도 한 홉.
- sitemap 30개 전부 200·자기참조 canonical·noindex 0·**리다이렉트 0**
- 내부 링크 102개 → 깨짐 0, **리다이렉트 0**
- Accept-Language(en/ja/es) × 10페이지 canonical 불변 PASS
- `bin/rails test` → **87 runs / 502 assertions / 0 failures** (직전 58/278)

---

## ③ 핵심 파일 전문

#### `lib/canonical_path_redirect.rb`

```ruby
# frozen_string_literal: true

require "cgi/escape"

# Rack middleware that gives every page exactly one spelling of its address.
#
# Two different layers were handing out duplicates, in opposite directions:
#
#   1. ActionDispatch::FileHandler resolves a request for `/safe` by probing
#      `public/safe`, `public/safe.html` and finally `public/safe/index.html`,
#      so `/safe`, `/safe/` and `/safe/index.html` all returned an identical
#      200. And because ActionDispatch::Static sits *in front of* the router,
#      `get "/safe", to: redirect("/safe/")` never ran — the static handler
#      answered first and the route was dead code.
#
#   2. The Rails router matches a trailing slash as if it were not there, so
#      every routed page answered twice as well: `/about` and `/about/`,
#      `/blog/:slug` and `/blog/:slug/`, down to `/sitemap.xml/`. Measured live
#      2026-09-17: 168 of 168 post URLs and 32 other paths, all real 200s, no
#      redirect involved. Search Console had already picked one of them up —
#      `/blog/contract-checklist/` was reported as a duplicate whose canonical
#      Google chose for itself.
#
# These need opposite fixes, which is why one middleware owns both: a static
# directory is canonical WITH the trailing slash (that is what `public/safe/`
# is), and a routed page is canonical WITHOUT it.
#
# It must be inserted BEFORE ActionDispatch::Static (see the initializer) or the
# static handler wins again for case 1.
class CanonicalPathRedirect
  # Directory-backed static HTML entrypoints, spelled without the trailing
  # slash. Each is served from `public/<dir>/index.html` and is canonical WITH
  # the slash. These are the only two directories under public/ (verified), and
  # both are declared that way in the sitemap.
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

  # Returns the canonical spelling of this path, or nil when the request is
  # already canonical and should pass through untouched.
  def canonical_target(env)
    return nil unless SAFE_METHODS.include?(env["REQUEST_METHOD"])

    path = env["PATH_INFO"].to_s
    return nil if path.empty? || path == "/"

    # Static directories: canonical WITH the slash.
    DIRS.each do |dir|
      return "#{dir}/" if path == dir || path == "#{dir}/index.html"
      # Already canonical, or an asset underneath it — never touched. This also
      # keeps the trailing-slash rule below from stripping `/safe/` itself.
      return nil if path.start_with?("#{dir}/")
    end

    # Routed pages: canonical WITHOUT the slash. Strip every trailing slash so
    # `/about//` resolves in one hop rather than redirecting twice.
    stripped = path.sub(%r{/+\z}, "")
    return nil if stripped == path

    stripped.empty? ? "/" : stripped
  end

  # The Location the client is sent to. The query string is echoed back from the
  # request, so strip anything that could break out of the header. Puma already
  # rejects a request line containing CR or LF, but relying on that would make
  # this middleware's safety a property of the upstream parser rather than of
  # this code — swap the server or put a proxy in front and the guarantee is
  # gone. Strip them here so the invariant holds on its own.
  def redirect_location(env, target)
    # SCRIPT_NAME is "" for a root-mounted app (the case here), but including it
    # keeps the Location correct if this app is ever mounted under a sub-path.
    #
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
end
```

#### `config/initializers/canonical_path_redirect.rb`

```ruby
# frozen_string_literal: true

# Insert CanonicalPathRedirect in front of the static file server so every page
# has one address: `/safe` and `/safe/index.html` collapse onto `/safe/`, and
# every routed page's trailing-slash twin collapses onto the bare path.
# See lib/canonical_path_redirect.rb for the full rationale.
#
# It must sit ahead of ActionDispatch::Static: the static handler answers
# `/safe` from public/safe/index.html before the router ever sees it, which is
# why the equivalent route in config/routes.rb was dead code.
#
# Order vs StaticHtmlNoCache: both insert before ActionDispatch::Static, and
# initializers load alphabetically (canonical_path_redirect → static_html_no_cache),
# so this one ends up the *outer* of the two. That is harmless either way: the
# rewriter only touches responses carrying `public, max-age=…`, and this 301
# sends `no-cache`.
#
# Guarded so it is a no-op when ActionDispatch::Static is not in the stack
# (i.e. when a front-end proxy serves public/ instead of this app).
require Rails.root.join("lib", "canonical_path_redirect").to_s

Rails.application.config.middleware.insert_before(
  ActionDispatch::Static, CanonicalPathRedirect
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
  # stays in Spanish (/es/blog/contract-checklist → /es/blog/contract-sharing-checklist).
  #
  # The targets carry NO trailing slash (2026-09-18). They used to, and once
  # CanonicalPathRedirect started normalising routed paths that made every one of
  # these a 301 to a 301. Search Console had already caught the old spelling:
  # /blog/contract-checklist/ was reported as a duplicate with a Google-chosen
  # canonical, last crawled 2026-07-18 — a day before the rename shipped.
  OLD_BLOG_SLUGS = {
    "rrn-masking"        => "resident-number-masking",
    "contract-checklist" => "contract-sharing-checklist"
  }.freeze

  OLD_BLOG_SLUGS.each do |old_slug, new_slug|
    get "/blog/#{old_slug}", to: redirect("/blog/#{new_slug}")
    %w[en ja es].each do |loc|
      get "/#{loc}/blog/#{old_slug}", to: redirect("/#{loc}/blog/#{new_slug}")
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

    # The blog index used to be a static file at public/blog/index.html, so
    # ActionDispatch::Static answered /blog, /blog/ AND /blog/index.html with an
    # identical 200 and Google indexed all three. 9f8bfff (2026-07-17) deleted
    # the file when the listing moved into Rails, which left /blog/index.html
    # falling through to "/blog/:slug" below as slug="index.html" → 404.
    # 301 it back onto the listing instead of stranding an indexed URL.
    # MUST stay above "/blog/:slug" — routes match in declaration order.
    get "/blog/index.html",
        to: redirect { |params, _req| params[:locale] ? "/#{params[:locale]}/blog" : "/blog" }

    get "/blog/:slug", to: "posts#show",  as: :blog_post
  end

  # SafeFile — public/safe/index.html은 Rails가 정적 서빙(언어 독립 단일 URL),
  # API는 AI 정밀 검사 중계. 로케일 프리픽스 없음.
  #
  # `get "/safe", to: redirect("/safe/")` 는 여기 있었지만 **한 번도 실행된 적이 없다**
  # (2026-09-17 제거). ActionDispatch::Static 이 라우터보다 앞에 있고,
  # FileHandler 가 `/safe` 요청을 `public/safe/index.html` 로 해석해 200 을 먼저
  # 돌려주기 때문이다. 트레일링 슬래시 정규화는 정적 핸들러보다 앞서야 하므로
  # Rack 미들웨어(lib/canonical_path_redirect.rb)로 옮겼다.
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

#### `app/models/post.rb`

```ruby
class Post < ApplicationRecord
  has_one_attached :hero_image

  validates :title_ko, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :category, inclusion: { in: %w[privacy pdf image office student freelancer global] }
  validates :status, inclusion: { in: %w[draft scheduled published] }

  # The invariant: **a published post always has a Korean body.**
  #
  # Korean is the default locale, so /blog/:slug — the address every other
  # locale canonicalises to, the one x-default points at, and the only one the
  # language switcher can always reach — is the Korean page. A published post
  # with body_en but no body_ko makes that address real but not indexable:
  # indexable_locales comes back [:en], yet x-default still aims at the Korean
  # URL, which is noindex. Reproduced before writing this validation.
  #
  # Nothing builds that shape today (BlogGeneratorService writes Korean first,
  # and all 42 live posts have body_ko), so this closes a gap rather than fixing
  # a live defect. Drafts stay exempt: a post is created empty and filled in.
  validates :body_ko, presence: true, if: -> { status == "published" }

  scope :published, -> { where(status: "published") }
  scope :scheduled_ready, -> { where(status: "scheduled").where("published_at <= ?", Time.current) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }

  before_validation :generate_slug, if: -> { slug.blank? && title_ko.present? }

  # ── Localized content ───────────────────────────────────────────────────
  #
  # `loc` is the locale of the URL being rendered, not the one I18n negotiated —
  # callers pass ApplicationHelper#url_locale. It is REQUIRED on purpose. These
  # three used to default to I18n.locale, and that default is the whole bug: an
  # unprefixed /blog/:slug served an English title and body to anyone sending
  # `Accept-Language: en` while still declaring the Korean canonical — one URL
  # with two contents, and an exact duplicate of /en/blog/:slug. A default would
  # let the next caller reintroduce it in silence; without one, forgetting is an
  # ArgumentError at the call site. Only a prefixed URL may serve localized
  # content.
  #
  # The fallback itself is unchanged: any non-Korean locale prefers the English
  # column and drops to Korean when it is empty (ja/es have no columns at all).
  def title(loc)
    loc.to_sym == :ko ? title_ko : (title_en.presence || title_ko)
  end

  def body(loc)
    loc.to_sym == :ko ? body_ko : (body_en.presence || body_ko)
  end

  def meta_description(loc)
    loc.to_sym == :ko ? meta_description_ko : (meta_description_en.presence || meta_description_ko)
  end

  # ── Indexing ────────────────────────────────────────────────────────────
  #
  # Blog posts only carry ko/en body columns. A locale counts as "translated"
  # only when that locale's body column is actually filled in — ja/es never are,
  # and en falls back to ko text (untranslated) unless body_en is present.
  def translated?(loc = I18n.locale)
    case loc.to_sym
    when :ko then body_ko.present?
    when :en then body_en.present?
    else false
    end
  end

  # The single rule behind every indexing signal this post emits.
  #
  #   status      | robots        | why
  #   ------------|---------------|--------------------------------------------
  #   published   | (none)        | live, and the body exists in this locale
  #   published   | noindex,follow| body not translated into this locale, so the
  #               |               | URL would put Korean text on an /en|ja|es
  #               |               | address
  #   scheduled   | noindex,follow| not live yet — PostsController#show serves it
  #   draft       | noindex,follow| 200 for preview, but it must never be indexed
  #
  # Preview keeps its 200; only the indexing directive changes.
  def indexable?(loc = I18n.locale)
    status == "published" && translated?(loc)
  end

  # Locales this post may actually be indexed under — drives sitemap + hreflang.
  # Empty for anything unpublished, which is a real answer and stays empty:
  # an unpublished post advertises no alternates at all.
  def indexable_locales
    [ :ko, :en ].select { |l| indexable?(l) }
  end

  def publish!
    update!(status: "published", published_at: Time.current) if published_at.blank?
    update!(status: "published")
  end

  private

  def generate_slug
    base = title_ko.to_s.parameterize
    base = SecureRandom.hex(6) if base.blank?
    self.slug = base
    counter = 1
    while Post.where(slug: slug).where.not(id: id).exists?
      self.slug = "#{base}-#{counter}"
      counter += 1
    end
  end
end
```

#### `app/controllers/pages_controller.rb`

```ruby
class PagesController < ApplicationController
  def home
  end

  def compress
  end

  def pdf
  end

  def social
    @presets = SocialResizer::PRESETS
  end

  # The about copy is hardcoded English — about.html.erb contains no t() calls
  # and config/locales has no `about.*` keys — so /about, /en/about, /ja/about
  # and /es/about all serve the same document. Measured live 2026-09-17: the
  # four are 92-94% identical, against 28-38% for /faq, /compress and /, which
  # really are translated. Search Console had already folded them, reporting
  # /en/about as a duplicate whose canonical Google chose for itself.
  #
  # One document gets one indexable URL, the same rule blog posts follow for
  # locales they were never translated into: the prefixed variants canonicalise
  # to /about and carry noindex (see about.html.erb), and the sitemap lists only
  # /about. No hreflang at all — an English-only page makes no language claim,
  # and declaring itself the Korean or Japanese alternate would be a false one.
  def about
    @hreflang_locales = []
  end

  def faq
    @faq_items = t("faq.items")
  end

  def sitemap
    @base_url = helpers.base_url
    respond_to do |format|
      format.xml
    end
  end
end
```

#### `app/controllers/posts_controller.rb`

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.published.recent
    @posts = @posts.by_category(params[:category]) if params[:category].present?
    # page_meta lives in index.html.erb — a controller-side call is a silent
    # no-op here. See the comment at the top of that view.
  end

  def show
    @post = Post.where(status: [ "published", "scheduled", "draft" ]).find_by!(slug: params[:slug])
    @post.increment!(:view_count)
    @related_posts = Post.published.where(category: @post.category).where.not(id: @post.id).recent.limit(3)

    # Empty body or a locale we haven't actually translated into → don't index
    # this URL; point its canonical at the Korean original (see show.html.erb).
    # NOTE: page/meta tags are emitted from the view via content_for — content_for
    # set from a controller's `helpers` proxy does not reach the rendered layout.
    # Instance variables DO reach it, which is why @hreflang_locales is set here.
    #
    # The gate reads the locale off the URL, not off I18n.locale. set_locale
    # resolves a bare /blog/:slug through the cookie and then Accept-Language, so
    # keying on I18n.locale made the Korean canonical URL answer `noindex,follow`
    # to anyone sending `Accept-Language: en` — including any crawler that does.
    # Measured live 2026-09-17 on /blog/resume-privacy.
    @url_locale = helpers.url_locale
    @post_translated = @post.translated?(@url_locale)

    # The robots gate. Post#indexable? folds in publication state, which the old
    # gate never looked at: a draft or scheduled post with a Korean body came
    # back 200 with no noindex, so an unpublished article was an indexable
    # public page. The 200 stays — preview still works — and only the directive
    # changes. The signal table lives on Post#indexable?.
    @post_indexable = @post.indexable?(@url_locale)

    # Only advertise the locales this post can actually be indexed under. The
    # default set (all four) pointed at /en|ja|es/blog/:slug — URLs that carry
    # noindex and canonicalise back here, which is both self-contradictory and
    # the route by which Google discovered 126 no-index URLs. Unpublished posts
    # advertise nothing at all: [] is a real answer, not "unspecified".
    @hreflang_locales = @post.indexable_locales
  end
end
```

#### `app/helpers/application_helper.rb`

```ruby
module ApplicationHelper
  LOCALE_NAMES = { ko: "한국어", en: "English", ja: "日本語", es: "Español" }.freeze
  # The prefixes that appear in a URL. Must stay in step with the route
  # constraint in config/routes.rb (`scope "(:locale)", locale: /en|ja|es/`) —
  # Korean is the default and never carries a prefix.
  LOCALE_PREFIX = %r{\A/(en|ja|es)(?=/|\z)}.freeze
  OG_LOCALES   = { ko: "ko_KR", en: "en_US", ja: "ja_JP", es: "es_ES" }.freeze

  def base_url
    ENV.fetch("BASE_URL", "https://slimfile.net")
  end

  # The locale the URL itself declares, ignoring cookie / Accept-Language
  # negotiation. Every indexing signal must be derived from this rather than from
  # I18n.locale: set_locale resolves a *bare* path through the cookie and then
  # Accept-Language, so the same URL used to answer different crawlers
  # differently — GET /faq with `Accept-Language: en` declared its canonical to
  # be /en/faq, and GET /blog/:slug with the same header came back noindex.
  # A URL has to send one answer to everyone.
  def url_locale
    m = request.path.match(LOCALE_PREFIX)
    m ? m[1].to_sym : I18n.default_locale
  end

  # `path` is the canonical unprefixed path (e.g. "/faq"); the URL's own locale
  # prefix is applied so each localized page self-canonicalizes.
  # `canonical` (when given) is an absolute path already resolved to the correct
  # locale — used to point untranslated blog pages at the Korean original.
  def page_meta(title:, description:, path: nil, image: nil, canonical: nil)
    canonical_path = canonical || (path ? locale_prefixed(path, url_locale) : request.path)
    content_for(:meta_title, title)
    content_for(:meta_description, description)
    content_for(:meta_url, "#{base_url}#{canonical_path}")
    content_for(:meta_image, image || "#{base_url}/icon.png")
  end

  # Prepend the locale prefix to an unprefixed path (Korean/default stays bare).
  def locale_prefixed(path, locale = I18n.locale)
    return path if locale.to_sym == I18n.default_locale

    path == "/" ? "/#{locale}" : "/#{locale}#{path}"
  end

  # Native language name for the locale switcher.
  def locale_name(locale)
    LOCALE_NAMES[locale.to_sym] || locale.to_s
  end

  def og_locale(locale = I18n.locale)
    OG_LOCALES[locale.to_sym] || "en_US"
  end

  # Current request path with any locale prefix stripped (always starts with "/").
  def path_without_locale
    request.path.sub(LOCALE_PREFIX, "").presence || "/"
  end

  # Path for the current page under a given locale. Korean (default) is unprefixed.
  def localized_path(locale)
    locale_prefixed(path_without_locale, locale)
  end

  # Same as localized_path but preserves the query string (for the switcher links).
  def localized_url_path(locale)
    path = localized_path(locale)
    request.query_string.present? ? "#{path}?#{request.query_string}" : path
  end

  # Path used by the language switcher. The default (Korean) locale has no URL
  # prefix, so a bare path is ambiguous with a stale `locale` cookie and
  # set_locale would keep the previous language. Make the choice explicit with
  # ?locale=ko (read with top priority by set_locale, which then persists it).
  # Non-default locales are unambiguous via their prefix; we only carry over any
  # existing non-locale query (e.g. ?category=privacy).
  def locale_switch_path(locale)
    base = localized_path(locale)
    query = request.query_parameters.except("locale")
    query["locale"] = locale if locale.to_sym == I18n.default_locale
    query.present? ? "#{base}?#{query.to_query}" : base
  end

  # [[locale, absolute_url], ...] for hreflang alternates (canonical, no query).
  #
  # `locales` narrows the set for pages that do not genuinely exist in every UI
  # language. Blog posts are the case: the UI chrome is translated but the body
  # is not, so /ja/blog/:slug serves the Korean article under a Japanese shell —
  # it carries noindex and canonicalises to the Korean URL. Advertising it as
  # the Japanese alternate contradicts both of those signals (Google requires
  # hreflang targets to be canonical and indexable) and is how those URLs get
  # discovered in the first place. The sitemap has always used the narrowed set
  # (Post#indexable_locales); this makes the page agree with it.
  # nil means "not specified" → every UI locale. An empty array is a real answer
  # ("this page exists in no locale yet") and must stay empty rather than fall
  # back to all four.
  def hreflang_alternates(locales = nil)
    (locales.nil? ? I18n.available_locales : locales)
      .map { |loc| [loc, "#{base_url}#{localized_path(loc)}"] }
  end
end
```

#### `app/views/pages/about.html.erb`

```erb
<% content_for(:title, "About - SlimFile") %>
<%# One document, one indexable address — see PagesController#about. The
    canonical is the literal "/about" rather than locale_prefixed(...), because
    the prefixed URLs are not translations of this page, they are the same
    bytes. %>
<% page_meta(
     title: "About - SlimFile",
     description: "SlimFile is a free web service that compresses images and converts them to PDF, keeping files under 2MB for easy document submission.",
     canonical: "/about"
   ) %>
<% content_for :robots, "noindex,follow" unless url_locale == I18n.default_locale %>

<div class="container">
  <h1>About SlimFile</h1>

  <section>
    <h2>What is SlimFile?</h2>
    <p>SlimFile is a free web service that compresses images and converts them to PDF format,
       ensuring files stay under 2MB for easy document submission.</p>
  </section>

  <section>
    <h2>Features</h2>
    <ul>
      <li>Image compression with quality preservation</li>
      <li>Multi-image to PDF conversion</li>
      <li>Social media preset resizing</li>
      <li>Supports JPEG, PNG, HEIC, and WebP formats</li>
    </ul>
  </section>

  <section>
    <h2>Privacy</h2>
    <p>Your files are automatically deleted from our servers within 1 hour after processing.
       We do not store or share your images.</p>
  </section>
</div>
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

  # Fully localized UI pages: [path, changefreq, priority].
  # /about is NOT here: its copy is hardcoded English with no t() calls, so the
  # four locale URLs are the same document (92-94% identical, measured
  # 2026-09-17) rather than translations of each other. Listing them as an
  # hreflang set would be a false claim, and Google had already folded them —
  # /en/about came back as a duplicate with a Google-chosen canonical. It is
  # listed once, further down, alongside the other single-URL pages.
  ui_pages = [
    ["/",         "daily",   "1.0"],
    ["/compress", "weekly",  "0.9"],
    ["/pdf",      "weekly",  "0.9"],
    ["/social",   "weekly",  "0.9"],
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
<%# Category listing pages (?category=privacy et al.) are deliberately NOT listed.
    They used to be, and that contradicted the pages themselves: PostsController#index
    calls page_meta(path: "/blog"), so /blog?category=privacy declares
    <link rel="canonical" href="…/blog"> — an address other than its own. A sitemap is
    a list of canonical URLs, so advertising a URL that disowns its own address tells
    Google two different things at once. (Measured live 2026-09-17: all four
    ?category=privacy URLs canonicalised to the unfiltered listing.)
    Nothing is lost by dropping them — every post they filter to is listed
    individually below. If category pages should rank in their own right, the fix is
    to make them self-canonicalise first, and only then re-add them here. %>
<% Post.published.recent.each do |post| %>
  <% lastmod = (post.updated_at || post.published_at)&.to_date&.iso8601 %>
  <%# Only emit locales the post is actually translated into — untranslated
      (ja/es always, en unless body_en present) URLs carry noindex, so keeping
      them out of the sitemap avoids indexing empty/mismatched pages. %>
  <%# indexable_locales, not translated_locales: it folds in publication state as
      well, so the sitemap cannot list an unpublished post even if the loop above
      ever stops scoping to Post.published. %>
  <% locales = post.indexable_locales %>
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
      301 here (lib/canonical_path_redirect.rb) and must never enter the sitemap. %>
  <url>
    <loc><%= @base_url %>/safe/</loc>
    <lastmod><%= Date.today.iso8601 %></lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.9</priority>
    <xhtml:link rel="alternate" hreflang="x-default" href="<%= @base_url %>/safe/"/>
  </url>
  <url>
    <%# English-only document; see the ui_pages comment above. %>
    <loc><%= @base_url %>/about</loc>
    <lastmod><%= Date.today.iso8601 %></lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
  <url>
    <loc><%= @base_url %>/privacy/</loc>
    <lastmod><%= Date.today.iso8601 %></lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.5</priority>
  </url>
</urlset>
```

#### `public/robots.txt`

```text
User-agent: *
Allow: /
Disallow: /admin
Disallow: /conversions

# /api/* is a JSON endpoint, not a page. Googlebot found /api/safe_scan on its
# own: the URL appears nowhere as a link, a form action, in the sitemap or in
# llms.txt — its only occurrence site-wide is the string literal inside
# `fetch('/api/safe_scan', …)` in public/safe/index.html, which the renderer
# harvests. The route is POST-only, so the resulting GET is a 404, which is what
# Search Console reported (first seen 2026-09-05).
#
# Disallow rather than X-Robots-Tag: noindex is deliberate. A noindex header has
# to be *fetched* to be obeyed, which is the crawl we are trying to prevent, and
# a 404 gives us no response of our own to attach a header to. Blocking the
# crawl is both the correct tool and the only one that works here.
Disallow: /api/

Sitemap: https://slimfile.net/sitemap.xml
```

#### `test/lib/canonical_path_redirect_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib", "canonical_path_redirect").to_s

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
class CanonicalPathRedirectTest < ActiveSupport::TestCase
  # Inner app stands in for ActionDispatch::Static; a 200 means "passed through".
  PASSTHROUGH = ->(env) { [200, { "content-type" => "text/html" }, ["STATIC:#{env["PATH_INFO"]}"]] }

  def call(path, method: "GET", query: "", script_name: "")
    CanonicalPathRedirect.new(PASSTHROUGH).call(
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
    %w[/ /safe/ /privacy/ /safe/sw.js /safe/icon.svg /safe/manifest.ko.webmanifest
       /api/safe_scan /safety /blog/safe /about /blog/some-slug].each do |path|
      status, = call(path)
      assert_equal 200, status, path
    end
  end

  # ── routed pages are canonical WITHOUT the trailing slash ───────────────
  #
  # The Rails router matches a trailing slash as if it were absent, so every
  # routed page answered twice. Measured live 2026-09-17: 168 of 168 post URLs
  # and 32 other paths returned a real 200 both ways, no redirect involved.

  test "a trailing slash on a routed page redirects to the bare path" do
    {
      "/about/" => "/about",
      "/faq/" => "/faq",
      "/blog/" => "/blog",
      "/blog/some-slug/" => "/blog/some-slug",
      "/en/" => "/en",
      "/en/about/" => "/en/about",
      "/ja/blog/some-slug/" => "/ja/blog/some-slug",
      "/sitemap.xml/" => "/sitemap.xml"
    }.each do |path, target|
      status, headers, = call(path)
      assert_equal 301, status, path
      assert_equal target, headers["location"], path
    end
  end

  test "the site root keeps its slash" do
    status, = call("/")
    assert_equal 200, status, "/ is already canonical and must not redirect"
  end

  test "repeated trailing slashes collapse in a single hop" do
    _, headers, = call("/about//")
    assert_equal "/about", headers["location"]
    _, headers, = call("/about///")
    assert_equal "/about", headers["location"]
  end

  test "a static directory keeps its slash while routed paths lose theirs" do
    # The two rules point in opposite directions, which is why one middleware
    # owns both. /safe/ is a real directory under public/; /about/ is not.
    assert_equal 200, call("/safe/").first
    assert_equal 200, call("/privacy/").first
    assert_equal 301, call("/about/").first
  end

  test "assets underneath a static directory are never rewritten" do
    %w[/safe/sw.js /safe/icon.svg /safe/manifest.ko.webmanifest /privacy/style.css].each do |path|
      assert_equal 200, call(path).first, path
    end
  end

  test "the trailing-slash redirect preserves the query string" do
    _, headers, = call("/blog/", query: "category=privacy")
    assert_equal "/blog?category=privacy", headers["location"]
  end

  test "only GET and HEAD lose the trailing slash" do
    assert_equal 301, call("/about/", method: "HEAD").first
    assert_equal 200, call("/about/", method: "POST").first
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

#### `test/integration/canonical_urls_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"

# Search Console named three URLs on 2026-09-18, and every earlier guess about
# which they would be had been wrong. These tests pin the measured causes.
#
#   https://slimfile.net/api/safe_scan            404, first seen 2026-09-05
#   https://slimfile.net/en/about                 duplicate, Google-chosen canonical
#   https://slimfile.net/blog/contract-checklist/ duplicate, Google-chosen canonical
class CanonicalUrlsTest < ActionDispatch::IntegrationTest
  BASE = "https://slimfile.net"

  def canonical(body) = body[/<link rel="canonical" href="([^"]*)"/, 1]
  def robots(body) = body[/<meta name="robots" content="([^"]*)"/, 1]
  def hreflangs(body) = body.scan(/<link rel="alternate" hreflang="([^"]+)"/).flatten

  # ── /api/safe_scan ──────────────────────────────────────────────────────

  test "the API endpoint is blocked from crawling in robots.txt" do
    # Not X-Robots-Tag: a noindex header has to be fetched to be obeyed, which
    # is the crawl we are preventing, and GET returns 404 so there is no
    # response of ours to attach a header to.
    get "/robots.txt"
    assert_match %r{^Disallow: /api/$}, response.body
  end

  test "GET on the API endpoint is still a 404 and that is fine" do
    # It is POST-only by design; robots.txt is what keeps crawlers away.
    get "/api/safe_scan"
    assert_response :not_found
  end

  # ── trailing slashes ────────────────────────────────────────────────────

  test "every routed page redirects its trailing-slash twin to the bare path" do
    {
      "/about/" => "/about",
      "/faq/" => "/faq",
      "/compress/" => "/compress",
      "/pdf/" => "/pdf",
      "/social/" => "/social",
      "/blog/" => "/blog",
      "/en/" => "/en",
      "/en/faq/" => "/en/faq",
      "/ja/compress/" => "/ja/compress",
      "/es/blog/" => "/es/blog",
      "/blog/korean-only-post/" => "/blog/korean-only-post",
      "/en/blog/bilingual-post/" => "/en/blog/bilingual-post"
    }.each do |path, target|
      get path
      assert_response :moved_permanently, path
      assert_redirected_to target
    end
  end

  test "the static directories keep their trailing slash" do
    %w[/safe/ /privacy/].each do |path|
      get path
      assert_response :success, "#{path} is a real directory under public/"
    end
    get "/safe"
    assert_redirected_to "/safe/"
  end

  test "a renamed slug spelled with a trailing slash still lands on the new address" do
    # Two hops, by design and bounded: this middleware normalises *spelling* and
    # runs ahead of the router, which resolves the *move*. So
    # /blog/contract-checklist/ → /blog/contract-checklist → the new slug.
    # Pulling the slug table into the middleware would collapse it to one hop
    # and make the route in config/routes.rb dead code — the exact trap /safe
    # fell into. Two 301s is the cheaper price.
    #
    # The targets no longer carry a trailing slash of their own, which would
    # have added a third hop.
    get "/blog/contract-checklist/"
    assert_response :moved_permanently
    assert_redirected_to "/blog/contract-checklist"

    follow_redirect!
    assert_response :moved_permanently
    assert_redirected_to "/blog/contract-sharing-checklist"

    follow_redirect!
    assert_response :not_found, "the fixture set has no such post, but the chain terminates"
  end

  test "the bare spelling of a renamed slug is still one hop" do
    get "/blog/contract-checklist"
    assert_response :moved_permanently
    assert_redirected_to "/blog/contract-sharing-checklist"

    get "/en/blog/rrn-masking"
    assert_response :moved_permanently
    assert_redirected_to "/en/blog/resident-number-masking"
  end

  test "no redirect chain loops or exceeds two hops" do
    %w[/about/ /blog/ /en/faq/ /blog/contract-checklist/ /safe /safe/index.html
       /blog/index.html /blog/rrn-masking/].each do |path|
      get path
      seen = [path]
      hops = 0
      while response.redirect? && hops < 5
        loc = response.headers["location"].sub("http://www.example.com", "")
        assert_not_includes seen, loc, "#{path} loops at #{loc}"
        seen << loc
        follow_redirect!
        hops += 1
      end
      assert_operator hops, :<=, 2, "#{path} took #{hops} hops: #{seen.inspect}"
    end
  end

  test "no sitemap URL is itself a redirect" do
    get "/sitemap.xml"
    locs = response.body.scan(%r{<loc>([^<]+)</loc>}).flatten
    locs.each do |u|
      get u.sub(BASE, "")
      assert_response :success, "#{u} is advertised in the sitemap but redirects"
    end
  end

  # ── /about is one document, not four ────────────────────────────────────

  test "the about page canonicalises every locale onto /about" do
    %w[/about /en/about /ja/about /es/about].each do |path|
      get path
      assert_response :success, path
      assert_equal "#{BASE}/about", canonical(response.body), path
    end
  end

  test "only the unprefixed about page is indexable" do
    get "/about"
    assert_nil robots(response.body)

    %w[/en/about /ja/about /es/about].each do |path|
      get path
      assert_equal "noindex,follow", robots(response.body),
                   "#{path} serves the same English document as /about"
    end
  end

  test "the about page claims no language at all" do
    # Hardcoded English with no t() calls: declaring itself the Korean or
    # Japanese alternate would be a false claim, and x-default would be too.
    %w[/about /en/about].each do |path|
      get path
      assert_empty hreflangs(response.body), path
    end
  end

  test "the sitemap lists about once, unprefixed" do
    get "/sitemap.xml"
    locs = response.body.scan(%r{<loc>([^<]+)</loc>}).flatten
    assert_includes locs, "#{BASE}/about"
    %w[en ja es].each { |loc| assert_not_includes locs, "#{BASE}/#{loc}/about" }
  end

  test "genuinely translated pages keep all four locale URLs" do
    # The narrowing must not leak onto /faq, /compress or / — those really are
    # translated (28-38% similar to Korean, measured, vs 92-94% for about).
    get "/sitemap.xml"
    locs = response.body.scan(%r{<loc>([^<]+)</loc>}).flatten
    %w[/faq /compress /pdf /social].each do |path|
      %w[en ja es].each do |loc|
        assert_includes locs, "#{BASE}/#{loc}#{path}"
      end
    end
    get "/en/faq"
    assert_nil robots(response.body)
    assert_equal %w[ko en ja es x-default], hreflangs(response.body)
  end
end
```

#### `test/models/post_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"

class PostTest < ActiveSupport::TestCase
  # The invariant: a published post always has a Korean body.
  #
  # Korean is the default locale, so /blog/:slug is the address every other
  # locale canonicalises to and the one x-default points at. A published post
  # with body_en but no body_ko makes that address real but not indexable —
  # indexable_locales comes back [:en] while x-default still aims at the Korean
  # URL, which is noindex. Reproduced before the validation was written.
  test "a published post requires a Korean body" do
    post = Post.new(title_ko: "영어만", title_en: "English only",
                    body_ko: nil, body_en: "<p>EN</p>",
                    slug: "en-only", category: "global",
                    status: "published", published_at: Time.current)
    assert_not post.valid?
    # Asserting the attribute, not the message: config/locales/ko.yml carries no
    # activerecord.errors block, so under the default locale the message comes
    # back as "Translation missing…". That is a real gap in the admin forms and
    # is noted separately; it must not make this test brittle.
    assert_includes post.errors.attribute_names, :body_ko
  end

  test "drafts and scheduled posts may still be empty" do
    # A post is created blank and filled in; the gate belongs at publication.
    %w[draft scheduled].each do |status|
      post = Post.new(title_ko: "초안", slug: "d-#{status}", category: "global", status: status)
      assert post.valid?, "#{status}: #{post.errors.full_messages}"
    end
  end

  test "publishing an empty post fails loudly rather than silently" do
    post = Post.create!(title_ko: "초안", slug: "to-publish", category: "global", status: "draft")
    assert_raises(ActiveRecord::RecordInvalid) { post.publish! }
  end

  test "indexable? requires publication and a body in that locale" do
    ko = posts(:korean_only)
    assert ko.indexable?(:ko)
    assert_not ko.indexable?(:en)
    assert_not ko.indexable?(:ja)

    both = posts(:bilingual)
    assert both.indexable?(:ko)
    assert both.indexable?(:en)

    assert_not posts(:draft_post).indexable?(:ko)
    assert_not posts(:scheduled_post).indexable?(:ko)
  end

  test "indexable_locales is empty for anything unpublished" do
    assert_equal [ :ko ], posts(:korean_only).indexable_locales
    assert_equal [ :ko, :en ], posts(:bilingual).indexable_locales
    assert_empty posts(:draft_post).indexable_locales
    assert_empty posts(:scheduled_post).indexable_locales
  end

  test "the localized readers require an explicit locale" do
    # No default: the default used to be I18n.locale, and that is the bug.
    post = posts(:bilingual)
    assert_raises(ArgumentError) { post.title }
    assert_raises(ArgumentError) { post.body }
    assert_raises(ArgumentError) { post.meta_description }
  end

  test "the localized readers follow the locale they are given" do
    post = posts(:bilingual)
    assert_equal "번역된 글", post.title(:ko)
    assert_equal "Translated post", post.title(:en)
    # ja/es have no columns and fall back to English, then Korean.
    assert_equal "Translated post", post.title(:ja)
    assert_equal "한국어 본문입니다.", post.body(:ko).strip.delete("<p>/")
  end
end
```

#### `test/fixtures/posts.yml`

```yaml
# Two shapes matter for indexing, and they are the two fixtures here:
#
#   korean_only  — the shape every one of the 42 live posts actually has
#                  (body_ko filled, body_en blank). Its /en, /ja and /es URLs
#                  serve the Korean article under a translated shell, so they
#                  carry noindex and canonicalise back to the Korean URL.
#   bilingual    — body_en filled as well. Exists on no live post yet, but it is
#                  the shape the translation gate is written for, so the tests
#                  need it to prove the gate opens and not just that it is shut.

korean_only:
  title_ko: "한국어 전용 글"
  body_ko: "<p>한국어 본문입니다.</p>"
  body_en: ""
  slug: "korean-only-post"
  category: "pdf"
  status: "published"
  published_at: <%= 3.days.ago.to_fs(:db) %>
  meta_description_ko: "한국어 전용 글의 설명"

bilingual:
  title_ko: "번역된 글"
  title_en: "Translated post"
  body_ko: "<p>한국어 본문입니다.</p>"
  body_en: "<p>English body.</p>"
  slug: "bilingual-post"
  category: "global"
  status: "published"
  published_at: <%= 2.days.ago.to_fs(:db) %>
  meta_description_ko: "번역된 글의 설명"
  meta_description_en: "Description of the translated post"

# PostsController#show serves draft and scheduled posts too, so the preview link
# works before publication. That 200 is deliberate; being indexable was not.
# Both have a Korean body, which is precisely the case the old gate waved
# through — translated?(:ko) was true, so no noindex was emitted.

draft_post:
  title_ko: "초안 글"
  body_ko: "<p>아직 발행하지 않은 초안입니다.</p>"
  body_en: ""
  slug: "draft-post"
  category: "office"
  status: "draft"
  meta_description_ko: "초안 글의 설명"

scheduled_post:
  title_ko: "예약된 글"
  body_ko: "<p>발행 예약된 글입니다.</p>"
  body_en: ""
  slug: "scheduled-post"
  category: "student"
  status: "scheduled"
  published_at: <%= 3.days.from_now.to_fs(:db) %>
  meta_description_ko: "예약된 글의 설명"

# A published post translated into English, used to prove the locale split holds
# once body_en is actually filled in: the unprefixed URL must stay Korean no
# matter what the reader's browser asks for, and only /en may serve English.
bilingual_published:
  title_ko: "이중언어 발행 글"
  title_en: "Bilingual published post"
  body_ko: "<p>한국어 본문 고유문자열 KOBODY.</p>"
  body_en: "<p>English body unique marker ENBODY.</p>"
  slug: "bilingual-published-post"
  category: "global"
  status: "published"
  published_at: <%= 1.day.ago.to_fs(:db) %>
  meta_description_ko: "한국어 설명 KODESC"
  meta_description_en: "English description ENDESC"
```

#### `app/views/posts/show.html.erb` — 첫 60줄 (canonical + JSON-LD)

```erb
<%# Page meta must be emitted from the view: content_for set via the controller's
    `helpers` proxy does not propagate to the layout head. %>
<%# @url_locale, not I18n.locale — the canonical must follow the URL, not the
    reader's cookie/Accept-Language. See PostsController#show. %>
<% canonical_path = @post_translated ? locale_prefixed("/blog/#{@post.slug}", @url_locale) : "/blog/#{@post.slug}" %>
<%# Content follows @url_locale too, not just the canonical. Reading I18n.locale
    here meant an unprefixed URL served an English title/description/body to an
    `Accept-Language: en` request while pointing its canonical at the Korean
    address — the same content as /en/blog/:slug at a second URL. %>
<% page_meta(
     title: @post.title(@url_locale),
     description: @post.meta_description(@url_locale).presence || @post.title(@url_locale),
     canonical: canonical_path
   ) %>
<%# Not @post_translated: a draft or scheduled post is 200 for preview but must
    never be indexed either. See Post#indexable? for the full signal table. %>
<% content_for :robots, "noindex,follow" unless @post_indexable %>

<% content_for :head do %>
  <meta property="og:type" content="article">
  <meta property="article:published_time" content="<%= @post.published_at&.iso8601 %>">
  <meta property="article:modified_time" content="<%= @post.updated_at&.iso8601 %>">
  <meta property="article:section" content="<%= @post.category %>">
  <% if @post.hero_image.attached? %>
    <% content_for :meta_image, url_for(@post.hero_image) %>
  <% end %>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Article",
    "headline": "<%= j @post.title(@url_locale) %>",
    "description": "<%= j(@post.meta_description(@url_locale).to_s) %>",
    <%# canonical_path, not a hardcoded /blog/:slug — on /en/blog/:slug the
        canonical says /en/... while these said /... , so the page and its
        structured data named two different documents. Same rule as the rest of
        the indexing signals: derive it from the URL. %>
    "url": "<%= base_url %><%= canonical_path %>",
    "datePublished": "<%= @post.published_at&.iso8601 %>",
    "dateModified": "<%= @post.updated_at&.iso8601 %>",
    <% if @post.hero_image.attached? %>
    "image": "<%= url_for(@post.hero_image) %>",
    <% end %>
    "author": {
      "@type": "Organization",
      "name": "SlimFile"
    },
    "publisher": {
      "@type": "Organization",
      "name": "SlimFile",
      "url": "<%= base_url %>"
    },
    "mainEntityOfPage": {
      "@type": "WebPage",
      "@id": "<%= base_url %><%= canonical_path %>"
    }
  }
  </script>
<% end %>

<% if @post.trust_bar.present? %>
```

#### `app/views/layouts/application.html.erb` — head 의 색인 신호 + JSON-LD

```erb
    <meta charset="utf-8">
    <meta name="google-site-verification" content="kgzqmiPFYQX0JWICmT3tB88tsJ7TADz-uyXJdu1pAEw" />

    <meta name="description" content="<%= content_for(:meta_description) || t('seo.default_description') %>">
    <meta name="keywords" content="<%= t('seo.keywords') %>">

    <% if content_for?(:robots) %>
    <meta name="robots" content="<%= content_for(:robots) %>">
    <% end %>
    <link rel="canonical" href="<%= content_for(:meta_url) || "#{base_url}#{request.path}" %>">

    <%# @hreflang_locales lets a controller narrow the set — see the helper.
        An explicitly empty set means "this page may not be indexed under any
        locale" (an unpublished post), so x-default is suppressed with it —
        a fallback pointer to a page nobody may index says nothing true. %>
    <% alternates = hreflang_alternates(@hreflang_locales) %>
    <% alternates.each do |loc, href| %>
    <link rel="alternate" hreflang="<%= loc %>" href="<%= href %>">
    <% end %>
    <% if alternates.any? %>
    <link rel="alternate" hreflang="x-default" href="<%= "#{base_url}#{localized_path(I18n.default_locale)}" %>">
    <% end %>

    <meta property="og:type" content="website">
    <meta property="og:site_name" content="SlimFile">
    <meta property="og:title" content="<%= content_for(:meta_title) || content_for(:title) || 'SlimFile' %>">
    <meta property="og:description" content="<%= content_for(:meta_description) || t('seo.default_description') %>">
    <meta property="og:url" content="<%= content_for(:meta_url) || "#{base_url}#{request.path}" %>">
    <meta property="og:image" content="<%= content_for(:meta_image) || "#{base_url}/icon.png?v=2" %>">
    <meta property="og:locale" content="<%= og_locale %>">
    <% (I18n.available_locales - [I18n.locale]).each do |loc| %>
    <meta property="og:locale:alternate" content="<%= og_locale(loc) %>">
    <% end %>
    <%= javascript_importmap_tags %>

    <script type="application/ld+json">
    {
      "@context": "https://schema.org",
      "@type": "WebApplication",
      "name": "SlimFile",
      "url": "<%= base_url %>",
      "description": "<%= t('seo.default_description') %>",
      "applicationCategory": "MultimediaApplication",
      "operatingSystem": "Web",
      "offers": {
        "@type": "Offer",
        "price": "0",
        "priceCurrency": "USD"
      },
      "featureList": [
        "Image compression",
        "PDF conversion",
        "Social media image resizing"
```

#### `app/views/pages/faq.html.erb` — JSON-LD (URL 필드 없음을 확인용)

```erb
<% content_for(:title, t("faq.title")) %>
<% page_meta(title: t("faq.title"), description: t("seo.faq_description"), path: "/faq") %>

<% content_for(:head) do %>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": [
      <% @faq_items.each_with_index do |item, i| %>
      {
        "@type": "Question",
        "name": "<%= j item[:q] %>",
        "acceptedAnswer": {
          "@type": "Answer",
          "text": "<%= j item[:a] %>"
        }
      }<%= "," unless i == @faq_items.size - 1 %>
      <% end %>
    ]
  }
  </script>
<% end %>

```

#### 미들웨어 스택 실측 (`bin/rails middleware`, 상위 6줄)

```
use ActionDispatch::HostAuthorization
use Rack::Sendfile
use CanonicalPathRedirect
use StaticHtmlNoCache
use ActionDispatch::Static
use Propshaft::Server
```

---

## ④ 정본 대조표 (이번 수정, DECISIONS.md 2026-09-18 행)

| 규칙 | 구현 위치 |
|---|---|
| 트레일링 슬래시 정본은 두 방향 (정적 디렉터리 有 / 라우팅 페이지 無) | `lib/canonical_path_redirect.rb` |
| 구 슬러그 리다이렉트는 2홉을 받아들인다 (표를 미들웨어로 옮기지 않는다) | `config/routes.rb` + 미들웨어 |
| `/api/*` 는 robots.txt Disallow 로 막는다 (X-Robots-Tag 아님) | `public/robots.txt` |
| `/about` 은 번역 대상이 아닌 단일 문서 — noindex + canonical + hreflang 0개 | `pages_controller.rb`, `about.html.erb`, `sitemap.xml.erb` |
| 발행된 글은 반드시 한국어 본문을 가진다 | `app/models/post.rb` |
| JSON-LD `url`·`@id` 도 `canonical_path` 를 쓴다 | `posts/show.html.erb` |
| (기존) 색인 신호는 URL 에서 파생 | `ApplicationHelper#url_locale` |
| (기존) 색인 게이트 = 발행 상태 + 번역 여부 | `Post#indexable?` |

## ⑤ 확신이 없는 지점 (이미 아는 것)

1. **`/blog/contract-checklist/` 가 2홉이다.** 미들웨어가 철자를, 라우터가 이동을 해결한다.
   1홉으로 만들려면 슬러그 표를 미들웨어에 넣어야 하는데 그러면 `routes.rb` 가 죽은 코드가 된다
   (`/safe` 가 당한 함정). 2홉이 낫다고 판단했다. **의견을 달라.**
2. `/about` 에 **x-default 조차 넣지 않았다.** `/safe/` 는 x-default 자기참조를 쓰는데,
   그건 한 URL 이 4개 언어를 서빙하기 때문이고 `/about` 은 1개 언어다. 그래서 다르게 갔다.
3. `config/locales/ko.yml` 에 `activerecord.errors` 블록이 없어 검증 실패 메시지가
   `Translation missing…` 으로 나온다. 어드민 폼에서 사람이 본다. **이번에 고치지 않았다** (별건).
4. `<html lang>`·`og:locale`·UI 크롬은 여전히 협상된다(직전 라운드 관찰 그대로). 제품 결정.
5. `/ja|es/blog/:slug` 는 번역이 없으면 영어 폴백을 보여준다. noindex 라 SEO 영향 없음.

## 비밀값 스캔 결과

```
grep -nEi "api[_-]?key|secret|password|BEGIN [A-Z ]*PRIVATE KEY|AKIA|ghp_|sk-[A-Za-z0-9]{20}" \
  docs/review/CODEX_REVIEW_PACKAGE_2026-09-18_gsc3.md
```

**매치 0건.** `.env` · `.env.production.local` · `config/master.key` · `.kamal/secrets` 미포함.
프로덕션 DB 내용도 없다 — 검증에 쓴 임시 `body_en` 은 **개발 DB** 에만 넣었다 원복했다.
`config/routes.rb` 는 지난 라운드의 패키지 결함(잘라 넣어 검토 대상 라인이 빠짐)을
반복하지 않기 위해 **전문**으로 넣었다.
