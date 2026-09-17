# Codex 교차검증 패키지 — 미색인 63개 조사 & 수정 · 2026-09-17

> 비밀값 스캔 결과는 문서 말미.

## ① 리뷰어용 프롬프트

당신은 이 저장소를 처음 보는 **독립 코드 리뷰어**다. 아래 패키지만 근거로 판단하라.

**맥락**: Rails 8.0.4 앱 `slimfile.net`. Google Search Console 의 페이지 색인 리포트가
알려진 134 = 색인 71 + 미색인 63 (noindex 40 · 404 1 · "Google 이 사용자와 다른 표준 선택" 2)
이라고 보고했다. 그 원인을 조사하고 (a)등급만 고친 커밋 `1809852` 를 검토한다.
**아직 배포되지 않았다. 프로덕션 DB 는 건드리지 않았다** — 판정은 전부 라이브 HTTP 실측(202 URL)과 깃 이력.

**지적 분류 고정**: `정책 위반` / `보안` / `데이터 손실 위험` / `논리 오류`

**규칙**:
- 모든 지적에 **파일:줄 근거**를 달아라. 근거 없는 지적은 적지 마라.
- **확신도(높음/보통/낮음)** 표기. 낮아도 적되 낮다고 밝혀라.
- **여기 없는 파일은 추측하지 마라.** 필요하면 "경로 요청: <파일>" 이라고 적어라.
- 하지 말 것: 스타일 지적(rubocop-rails-omakase 고정), 일반론적 "테스트를 늘려라",
  정본 문서(DECISIONS.md)를 고치자는 제안.

**이 저장소가 반복해 당한 실패 유형** (이 관점으로 파고들어라):
1. **조용한 실패** — 실패했는데 성공처럼 보인다.
   (실사례: ① 라우트가 정적 핸들러에 가려 한 번도 실행 안 됨 ② minitest 비호환으로 전 테스트가
   죽었는데 "0 tests" 로 통과처럼 보임 ③ **컨트롤러에서 부른 `page_meta` 가 조용히 무시돼
   `/blog` 4개 로케일이 전부 기본 `<title>` 로 나감** — 이번에 또 걸렸다)
2. **암묵적 상류 의존** — 안전의 근거가 우리 코드 밖에 있다.
3. **공허한 검사** — 아무것도 검증하지 않는 테스트/단언.
4. **협상 의존** — 같은 URL 이 요청자에 따라 다르게 답한다.

**특히 답을 원하는 질문**:
- Q1. `url_locale`(요청 경로 파싱)이 색인 신호의 근거로 **정말 충분한가?**
  `I18n.locale` 을 여전히 읽어 색인 신호에 영향을 주는 경로가 남아 있는가?
  (`locale_prefixed` 의 기본 인자, 레이아웃의 x-default, `localized_path`, og:locale 등)
- Q2. `hreflang_alternates(locales = nil)` 에서 `nil`=전체 / `[]`=없음 구분이 옳은가?
  `@hreflang_locales` 가 설정되지 않은 페이지(`posts#index`, 정적 페이지)에 회귀가 없는가?
- Q3. `/blog/index.html` 301 라우트가 `/blog/:slug` 보다 위에 있는데, **슬러그가
  `index.html` 인 글**이나 다른 경로를 가리지 않는가? 로케일 보존은 맞는가?
- Q4. 사이트맵에서 `?category=` 를 뺀 판단이 옳은가? 대안(페이지를 자기참조 canonical 로
  바꾸고 남기기)이 더 나은가?
- Q5. `test/integration/blog_indexing_test.rb` 에 **공허한 단언**이 있는가? 특히
  Accept-Language 테스트가 실제로 회귀를 잡는가? 놓친 케이스는?
- Q6. **고치지 않기로 한 것들**의 판단이 옳은가?
  (126개 noindex 유지 · `/xx/blog` 목록의 hreflang·canonical 유지 · draft/scheduled 를
  `show` 에서 200 으로 서빙 · admin 이 robots.txt Disallow 에만 의존)

**출력 형식**: 지적별로
```
[분류] [확신도] 제목
근거: <파일:줄>
설명: <어떤 입력에서 무엇이 잘못되는가>
```
마지막에 Q1~Q6 답변.

---

## ② 조사 결과 요약 (수정 전 라이브 실측)

### noindex 가 붙는 곳 — 전수

| 위치 | 조건 |
|---|---|
| `app/views/posts/show.html.erb:9` | `unless @post_translated` → `noindex,follow` — **유일한 동적 noindex** |
| `app/views/layouts/application.html.erb` | `content_for?(:robots)` 일 때만 태그 출력 (전달 통로) |
| `public/{400,404,422,500,406-*}.html` | 정적 에러 페이지 |
| `public/robots.txt` | `Disallow: /admin`, `/conversions` (noindex 아님) |
| **X-Robots-Tag** | **어디에도 없음** (라이브 9개 경로 확인) |

게이트는 draft 승인이 아니라 **번역 여부**다: `Post#translated?` 가 `ko`→`body_ko`,
`en`→`body_en`, `ja`/`es`→**항상 false**.

### 실측 숫자

- 사이트맵 76 URL, 글 42개 **전부 `ko` 단독**(42개 모두 `body_en` 빈 값).
- 글 42 × 4 로케일 = 168 URL 크롤 → `noindex,follow` **126개** (en 42 + ja 42 + es 42),
  ko 0, 정적 페이지 0. GSC 의 40 은 이 126 의 크롤된 부분집합.
- `/en|ja/blog/:slug` 본문이 한국어판과 **97.6~98.8% 동일**, 한글 비율 51~57%
  → 번역 안 된 한국어 본문. **noindex 는 옳다 → 고치지 않음.**
- 글끼리 중복 가설은 **반증됨**: 42개 전수 쌍 비교 최대 유사도 0.612, 중앙값 0.262.
- `/en|ja|es/blog` 목록 페이지는 `/blog` 와 **89.5~91.8% 동일** → "Google 이 다른 표준 선택 2개"의
  최유력 후보(추정, 확정 불가).

### 발견한 모순 6가지 (전부 이번에 수정)

1. **한국어 정본 URL 이 요청 헤더에 따라 noindex 반환.**
   `curl -H 'Accept-Language: en-US' https://slimfile.net/blog/resume-privacy` → `noindex,follow`.
   `set_locale` 우선순위가 `URL 프리픽스 → 쿠키 → Accept-Language` 인데 게이트가 그 결과를 읽었다.
2. **프리픽스 없는 페이지의 canonical 이동**: `/faq`→`/en/faq`, `/`→`/en`, `/compress`, `/pdf`, `/social`.
   `/about`·`/blog` 는 `page_meta` 가 레이아웃에 도달 못 해 **우연히** 무사.
3. **`/blog/index.html`(+3 로케일) 404.** `9f8bfff`(2026-07-17)가 `public/blog/index.html` 삭제 →
   `/blog/:slug` 의 slug=`index.html` 로 흘러 404.
4. **사이트맵이 `?category=privacy`(×4)를 실음.** 그 페이지 canonical 은 `/blog`.
5. **페이지 hreflang 이 글마다 4개 로케일 광고** (사이트맵은 `ko` 하나). 광고 대상은 noindex 이고
   canonical 도 한국어판을 가리킴. 126개가 발견된 경로.
6. **`/blog` 4개 로케일 전부 `<title>SlimFile</title>`** (컨트롤러발 `page_meta` 가 무시됨).

### 검증

- `bin/rails test` → **46 runs / 190 assertions / 0 failures** (수정 전 25/87)
- 로컬 전수 감사: 사이트맵 33개 전부 200·자기참조 canonical·noindex 0, 내부 링크 103개 전부 해결
- Accept-Language(none/en/ja) × 무프리픽스 7페이지 → canonical 전부 불변

---

## ③ 핵심 파일 전문

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
  # (Post#translated_locales); this makes the page agree with it.
  # nil means "not specified" → every UI locale. An empty array is a real answer
  # ("this page exists in no locale yet") and must stay empty rather than fall
  # back to all four.
  def hreflang_alternates(locales = nil)
    (locales.nil? ? I18n.available_locales : locales)
      .map { |loc| [loc, "#{base_url}#{localized_path(loc)}"] }
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

    # Only advertise the locales this post actually exists in. The default set
    # (all four) pointed at /en|ja|es/blog/:slug — URLs that carry noindex and
    # canonicalise back here, which is both self-contradictory and the route by
    # which Google discovered 126 no-index URLs. Matches the sitemap, which has
    # always used translated_locales.
    @hreflang_locales = @post.translated_locales
  end
end
```

#### `app/controllers/application_controller.rb`

```ruby
class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_locale

  # Keep the current locale in generated URLs. Korean (default) has no prefix,
  # so we pass locale: nil for it and Rails omits the optional (:locale) segment.
  def default_url_options
    { locale: (I18n.locale == I18n.default_locale ? nil : I18n.locale) }
  end

  private

  # Priority: URL prefix (params[:locale]) → cookie → Accept-Language → default.
  # The route constraint only matches en/ja/es, so a bare path (no prefix) means
  # cookie/browser preference decides — Korean when none is set.
  def set_locale
    requested = params[:locale].presence || cookies[:locale].presence || locale_from_browser
    locale = available?(requested) ? requested.to_sym : I18n.default_locale
    I18n.locale = locale

    # Persist an explicit URL choice so the preference survives later navigation.
    if params[:locale].present? && available?(params[:locale])
      cookies[:locale] = { value: locale, expires: 1.year.from_now }
    end
  end

  def locale_from_browser
    accept_language = request.env["HTTP_ACCEPT_LANGUAGE"]
    return nil unless accept_language

    accept_language.scan(/[a-z]{2}/).find { |lang| available?(lang) }
  end

  def available?(locale)
    locale.present? && I18n.available_locales.map(&:to_s).include?(locale.to_s)
  end
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

  scope :published, -> { where(status: "published") }
  scope :scheduled_ready, -> { where(status: "scheduled").where("published_at <= ?", Time.current) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }

  before_validation :generate_slug, if: -> { slug.blank? && title_ko.present? }

  def title
    I18n.locale == :ko ? title_ko : (title_en.presence || title_ko)
  end

  def body
    I18n.locale == :ko ? body_ko : (body_en.presence || body_ko)
  end

  def meta_description
    I18n.locale == :ko ? meta_description_ko : (meta_description_en.presence || meta_description_ko)
  end

  # Blog posts only carry ko/en body columns. A locale counts as "translated"
  # only when that locale's body column is actually filled in — ja/es never are,
  # and en falls back to ko text (untranslated) unless body_en is present.
  # Used to gate indexing (noindex,follow) so empty/untranslated locale pages
  # don't get indexed while AdSense review is in progress.
  def translated?(loc = I18n.locale)
    case loc.to_sym
    when :ko then body_ko.present?
    when :en then body_en.present?
    else false
    end
  end

  # Locales whose body is genuinely present — drives sitemap + hreflang.
  def translated_locales
    [ :ko, :en ].select { |l| translated?(l) }
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

#### `test/integration/blog_indexing_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"

# Guards the indexing signals a blog post sends, after the 2026-09-17 audit of
# Search Console's "not indexed: 63" report.
#
# The audit's finding was not that the noindex gate is wrong — it is right, and
# the first group of tests pins that down. It was that three *other* signals
# disagreed with it: the page's hreflang advertised four locales for posts that
# exist in one, the sitemap advertised URLs that disown their own address, and
# a URL that used to be an indexed page had started answering 404.
class BlogIndexingTest < ActionDispatch::IntegrationTest
  BASE = "https://slimfile.net"

  # x-default is excluded: it is a fallback pointer, not a language claim, and
  # the layout emits it for every page regardless of the narrowed locale set.
  def hreflangs(body)
    body.scan(/<link rel="alternate" hreflang="([^"]+)" href="([^"]+)"/)
        .reject { |loc, _| loc == "x-default" }
  end

  def x_default(body)
    body[/<link rel="alternate" hreflang="x-default" href="([^"]*)"/, 1]
  end

  def robots(body)
    body[/<meta name="robots" content="([^"]*)"/, 1]
  end

  def canonical(body)
    body[/<link rel="canonical" href="([^"]*)"/, 1]
  end

  # ── the noindex gate itself (this behaviour is intended; keep it) ────────

  test "a Korean-only post is indexable at its Korean URL" do
    get "/blog/korean-only-post"
    assert_response :success
    assert_nil robots(response.body), "the Korean original must not be noindexed"
    assert_equal "#{BASE}/blog/korean-only-post", canonical(response.body)
  end

  test "a Korean-only post is noindexed at every untranslated locale URL" do
    %w[en ja es].each do |loc|
      get "/#{loc}/blog/korean-only-post"
      assert_response :success
      assert_equal "noindex,follow", robots(response.body),
                   "/#{loc}/blog/… serves the Korean body under a #{loc} shell"
      assert_equal "#{BASE}/blog/korean-only-post", canonical(response.body),
                   "…and must point at the Korean original"
    end
  end

  test "a translated post is indexable at the locale it was translated into" do
    get "/en/blog/bilingual-post"
    assert_response :success
    assert_nil robots(response.body)
    assert_equal "#{BASE}/en/blog/bilingual-post", canonical(response.body)
  end

  test "a translated post is still noindexed at locales it has no body for" do
    %w[ja es].each do |loc|
      get "/#{loc}/blog/bilingual-post"
      assert_equal "noindex,follow", robots(response.body)
    end
  end

  # ── hreflang must agree with the noindex gate ───────────────────────────

  test "a Korean-only post advertises only the Korean alternate" do
    get "/blog/korean-only-post"
    assert_equal [["ko", "#{BASE}/blog/korean-only-post"]], hreflangs(response.body)
  end

  test "hreflang never points at a URL that is noindexed" do
    # This is the contradiction the audit found: /ja/blog/:slug was advertised
    # as the Japanese alternate while itself carrying noindex.
    get "/blog/korean-only-post"
    hreflangs(response.body).each do |_loc, href|
      get href.sub(BASE, "")
      assert_nil robots(response.body), "#{href} is advertised via hreflang but is noindexed"
    end
  end

  test "hreflang never points at a URL that canonicalises elsewhere" do
    get "/blog/korean-only-post"
    hreflangs(response.body).each do |_loc, href|
      get href.sub(BASE, "")
      assert_equal href, canonical(response.body),
                   "#{href} is advertised via hreflang but disowns its own address"
    end
  end

  test "a translated post advertises both of its locales" do
    get "/blog/bilingual-post"
    assert_equal [
      ["ko", "#{BASE}/blog/bilingual-post"],
      ["en", "#{BASE}/en/blog/bilingual-post"]
    ], hreflangs(response.body)
  end

  test "an untranslated locale URL still advertises the Korean original" do
    get "/ja/blog/korean-only-post"
    assert_equal [["ko", "#{BASE}/blog/korean-only-post"]], hreflangs(response.body)
  end

  test "pages that are genuinely translated keep all four alternates" do
    # The narrowing must be scoped to posts — the UI pages really do exist in
    # every locale, so nothing about them changes.
    get "/faq"
    assert_equal %w[ko en ja es], hreflangs(response.body).map(&:first)
  end

  # ── the sitemap must agree with the pages ───────────────────────────────

  test "the sitemap lists no URL that canonicalises elsewhere" do
    get "/sitemap.xml"
    assert_response :success
    locs = response.body.scan(%r{<loc>([^<]+)</loc>}).flatten

    assert_not locs.any? { |u| u.include?("?category=") },
               "category URLs declare canonical=/blog, so listing them contradicts the page"

    locs.grep(%r{/blog/}).each do |u|
      get u.sub(BASE, "")
      assert_equal u, canonical(response.body), "#{u} is in the sitemap but disowns its own address"
      assert_nil robots(response.body), "#{u} is in the sitemap but is noindexed"
    end
  end

  test "the sitemap lists a post only under the locales it was translated into" do
    get "/sitemap.xml"
    locs = response.body.scan(%r{<loc>([^<]+)</loc>}).flatten

    assert_includes locs, "#{BASE}/blog/korean-only-post"
    %w[en ja es].each do |loc|
      assert_not_includes locs, "#{BASE}/#{loc}/blog/korean-only-post"
    end

    assert_includes locs, "#{BASE}/blog/bilingual-post"
    assert_includes locs, "#{BASE}/en/blog/bilingual-post"
    %w[ja es].each do |loc|
      assert_not_includes locs, "#{BASE}/#{loc}/blog/bilingual-post"
    end
  end

  # ── indexing signals must come from the URL, not from negotiation ───────
  #
  # set_locale resolves a bare path through the cookie and then Accept-Language.
  # Keying canonical/robots on the result made one URL answer different crawlers
  # differently: GET /faq with `Accept-Language: en` declared canonical /en/faq,
  # and the Korean canonical /blog/:slug came back noindex.

  NEGOTIATION_HEADERS = [
    { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9" },
    { "HTTP_ACCEPT_LANGUAGE" => "ja-JP,ja;q=0.9" },
    { "HTTP_ACCEPT_LANGUAGE" => "es-ES,es;q=0.9" }
  ].freeze

  test "an unprefixed page keeps its own canonical whatever language is requested" do
    %w[/ /compress /pdf /social /faq /about /blog].each do |path|
      get path
      baseline = canonical(response.body)
      assert_equal "#{BASE}#{path == '/' ? '/' : path}", baseline

      NEGOTIATION_HEADERS.each do |headers|
        get path, headers: headers
        assert_equal baseline, canonical(response.body),
                     "#{path} changed its canonical for #{headers.values.first}"
      end
    end
  end

  test "the Korean canonical post URL is never noindexed by a request header" do
    NEGOTIATION_HEADERS.each do |headers|
      get "/blog/korean-only-post", headers: headers
      assert_nil robots(response.body),
                 "/blog/korean-only-post went noindex for #{headers.values.first}"
      assert_equal "#{BASE}/blog/korean-only-post", canonical(response.body)
    end
  end

  test "a locale-prefixed URL is unaffected by an opposing header" do
    get "/en/blog/bilingual-post", headers: { "HTTP_ACCEPT_LANGUAGE" => "ko-KR,ko;q=0.9" }
    assert_nil robots(response.body)
    assert_equal "#{BASE}/en/blog/bilingual-post", canonical(response.body)
  end

  test "a locale cookie does not move a page's canonical either" do
    get "/en/faq"              # sets the locale cookie to en
    get "/faq"
    assert_equal "#{BASE}/faq", canonical(response.body)
  end

  # ── the blog listing's own meta ──────────────────────────────────────────

  test "the blog listing has its own title and description" do
    get "/blog"
    assert_not_equal "SlimFile", response.body[%r{<title>(.*?)</title>}m, 1].to_s.strip,
                     "page_meta must run from the view or the layout falls back to the default"
    assert_includes response.body, %(<meta property="og:url" content="#{BASE}/blog">)
  end

  test "each locale's blog listing self-canonicalises" do
    %w[en ja es].each do |loc|
      get "/#{loc}/blog"
      assert_equal "#{BASE}/#{loc}/blog", canonical(response.body)
    end
  end

  # ── the stranded static URL ─────────────────────────────────────────────

  test "/blog/index.html redirects to the listing instead of 404ing" do
    # public/blog/index.html was a real indexed page until 9f8bfff deleted it;
    # afterwards it fell through to "/blog/:slug" as slug="index.html" → 404.
    get "/blog/index.html"
    assert_response :moved_permanently
    assert_redirected_to "/blog"
  end

  test "/blog/index.html keeps the reader's locale" do
    %w[en ja es].each do |loc|
      get "/#{loc}/blog/index.html"
      assert_response :moved_permanently
      assert_redirected_to "/#{loc}/blog"
    end
  end

  test "the index.html route does not shadow a real post" do
    get "/blog/korean-only-post"
    assert_response :success
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
```

#### `config/routes.rb` — 블로그 라우트 부분

```ruby

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
```

#### `app/views/layouts/application.html.erb` — head 의 색인 신호

```erb
    <meta charset="utf-8">
    <meta name="google-site-verification" content="kgzqmiPFYQX0JWICmT3tB88tsJ7TADz-uyXJdu1pAEw" />

    <meta name="description" content="<%= content_for(:meta_description) || t('seo.default_description') %>">
    <meta name="keywords" content="<%= t('seo.keywords') %>">

    <% if content_for?(:robots) %>
    <meta name="robots" content="<%= content_for(:robots) %>">
    <% end %>
    <link rel="canonical" href="<%= content_for(:meta_url) || "#{base_url}#{request.path}" %>">

    <%# @hreflang_locales lets a controller narrow the set — see the helper. %>
    <% hreflang_alternates(@hreflang_locales).each do |loc, href| %>
    <link rel="alternate" hreflang="<%= loc %>" href="<%= href %>">
    <% end %>
    <link rel="alternate" hreflang="x-default" href="<%= "#{base_url}#{localized_path(I18n.default_locale)}" %>">

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

    <meta name="twitter:card" content="summary_large_image">
```

#### `app/views/posts/show.html.erb` — 첫 12줄

```erb
<%# Page meta must be emitted from the view: content_for set via the controller's
    `helpers` proxy does not propagate to the layout head. %>
<%# @url_locale, not I18n.locale — the canonical must follow the URL, not the
    reader's cookie/Accept-Language. See PostsController#show. %>
<% canonical_path = @post_translated ? locale_prefixed("/blog/#{@post.slug}", @url_locale) : "/blog/#{@post.slug}" %>
<% page_meta(
     title: @post.title,
     description: @post.meta_description.presence || @post.title,
     canonical: canonical_path
   ) %>
<% content_for :robots, "noindex,follow" unless @post_translated %>

```

#### `app/views/posts/index.html.erb` — 첫 12줄

```erb
<%# Moved here from PostsController#index (2026-09-17). content_for set through a
    controller's `helpers` proxy never reaches the rendered layout, so the call
    was a silent no-op and all four /blog listings shipped the default
    "SlimFile" <title> with the generic site description — measured live before
    the move. Same trap as posts/show.html.erb; keep page_meta in the view. %>
<% page_meta(
     title: t("blog.title"),
     description: t("blog.meta_description"),
     path: "/blog"
   ) %>

<div class="container">
```

---

## ④ 정본 대조표

| 규칙 (DECISIONS.md, 이번에 신설) | 구현 위치 |
|---|---|
| 색인 신호는 `I18n.locale` 이 아니라 **URL** 에서 파생 | `ApplicationHelper#url_locale`, `page_meta`, `PostsController#show` |
| 글 hreflang 은 `Post#translated_locales` 로 좁힘 | `@hreflang_locales` + 레이아웃 |
| `hreflang_alternates(nil)`=전체, `([])`=없음 (`.presence` 폴백 금지) | `ApplicationHelper` |
| 사이트맵에서 `?category=` 제외 | `sitemap.xml.erb` |
| `/blog/index.html` → 301 `/blog` (`/blog/:slug` 보다 위) | `config/routes.rb` |
| `page_meta` 는 **뷰에서만** 호출 | `posts/index.html.erb`, `posts/show.html.erb` |
| (기존) 번역 안 된 로케일 URL 은 noindex + 한국어판 canonical | `posts/show.html.erb`, `Post#translated?` |

## ⑤ 확신이 없는 지점 (이미 아는 것)

1. **GSC 의 404 1개가 정말 `/blog/index.html` 인지 확정할 수 없다.** 라이브에서 404 인 것은
   맞고 과거 색인된 페이지였던 것도 맞지만, GSC 가 그 URL 을 세고 있는지는 리포트를 열어야 안다.
2. **"다른 표준 선택" 2개가 어느 URL인지 확정 불가.** `/xx/blog` 목록(89.5~91.8% 동일)이
   최유력이라고 판단했으나 추정이다.
3. `posts#index`(`/blog` 목록)의 hreflang 은 **좁히지 않았다.** UI 크롬은 번역되지만 글 제목은
   전부 한국어다. 전략 판단이라 (a)로 보지 않았다. **이 판단에 의견을 달라.**
4. `draft`/`scheduled` 글이 `show` 에서 200 으로 서빙되고, 한국어 본문이 있으면 noindex 가
   안 붙는다. 사이트맵·목록에 없어 슬러그를 알아야 도달한다. 동작 결정이라 손대지 않았다.
5. `@hreflang_locales` 가 빈 배열이면 hreflang 링크가 하나도 안 나가지만 레이아웃의
   **x-default 는 여전히 출력된다.** 무해하다고 판단.

## 비밀값 스캔 결과

```
grep -nEi "api[_-]?key|secret|password|token|BEGIN [A-Z ]*PRIVATE KEY|AKIA|ghp_|sk-[A-Za-z0-9]{20}" \
  docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_indexing.md
```

**매치 0건.** `.env` · `.env.production.local` · `config/master.key` · `.kamal/secrets` 미포함.
프로덕션 DB 덤프도 포함하지 않았다 — 숫자는 전부 공개 HTTP 응답에서 나온 것이다.
