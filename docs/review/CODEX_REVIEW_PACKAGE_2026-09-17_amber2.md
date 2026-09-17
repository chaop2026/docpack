# Codex 교차검증 패키지 — AMBER 2건 수정 확인 · 2026-09-17

> 비밀값 스캔 결과는 문서 말미.

## ① 리뷰어용 프롬프트

당신은 **독립 코드 리뷰어**다. 아래 패키지만 근거로 판단하라.

**맥락**: Rails 8.0.4 앱 `slimfile.net`. 직전 라운드에서 당신(같은 도구)이 커밋 `1809852` 에
대해 AMBER 2건을 냈다. 이번 커밋 `6138753` 은 **그 2건을 고치려는 시도**다.
아직 배포되지 않았다. **프로덕션 DB 는 건드리지 않았다.**

**이번 리뷰의 목적은 두 가지다**:
1. **A-1 · A-2 가 실제로 해소됐는가?** 각각 `해소됨` / `부분 해소` / `미해소` 로 판정하고
   판정 근거를 파일:줄로 대라.
2. **수정이 새로 만든 문제는 없는가?**

**직전 라운드 지적 원문**:

> **A-1 [보안][확신도 높음]** draft/scheduled 글이 공개 200이고, 한국어 본문이 있으면
> indexable입니다. `GET /blog/<draft-or-scheduled-slug>` 가
> `status: ["published", "scheduled", "draft"]` 를 모두 허용합니다. 해당 글에 `body_ko` 가
> 있으면 `translated?(:ko)` 가 true라서 `content_for :robots, "noindex,follow"` 도 붙지
> 않습니다. 사이트맵/목록에 없더라도 슬러그가 유출되거나 내부 링크/프리뷰 링크가 잡히면
> 미공개 글이 색인 가능한 공개 페이지가 됩니다.

> **A-2 [논리 오류][확신도 보통]** 무프리픽스 bilingual 글은 여전히 요청 협상에 따라
> 본문/메타가 바뀝니다. canonical/robots는 `@url_locale` 기반으로 고쳤지만, `@post.title`,
> `@post.body`, `@post.meta_description` 는 계속 `I18n.locale` 을 읽습니다. 그래서
> `GET /blog/bilingual-post` 에 `Accept-Language: en` 또는 `locale` 쿠키가 있으면 URL은
> 한국어 정본으로 canonicalize하면서 title/description/body는 영어로 나갈 수 있습니다.

**지적 분류 고정**: `정책 위반` / `보안` / `데이터 손실 위험` / `논리 오류`

**규칙**:
- 모든 지적에 **파일:줄 근거**를 달아라. 근거 없는 지적은 적지 마라.
- **확신도(높음/보통/낮음)** 표기. 낮아도 적되 낮다고 밝혀라.
- **여기 없는 파일은 추측하지 마라.** 필요하면 "경로 요청: <파일>" 이라고 적어라.
- 하지 말 것: 스타일 지적, 일반론적 "테스트를 늘려라", 정본 문서를 고치자는 제안.

**이 저장소가 반복해 당한 실패 유형** (이 관점으로 파고들어라):
1. **조용한 실패** — 실패했는데 성공처럼 보인다.
2. **암묵적 상류 의존** — 안전의 근거가 우리 코드 밖에 있다.
3. **공허한 검사** — 아무것도 검증하지 않는 테스트/단언.
4. **협상 의존** — 같은 URL 이 요청자에 따라 다르게 답한다.

**특히 답을 원하는 질문**:
- R1. draft/scheduled 가 **모든 경로에서** 색인 불가가 됐는가? 빠져나가는 경로가 있는가?
  (사이트맵 · hreflang · x-default · JSON-LD · og:url · 목록 페이지)
- R2. `Post#title/body/meta_description` 의 `loc` 를 **필수 인자**로 바꾼 판단이 옳은가?
  놓친 호출처가 있는가? (app·lib·db·script 전수 grep 했다고 주장하지만 검증해달라)
- R3. `translated?` 는 남기고 `translated_locales` 만 지웠다. canonical 이 여전히
  `translated?` 를 쓰는 게 맞는가? (미발행 한국어 글이 자기 ko 주소로 canonical 을 잡는 것)
- R4. alternate 가 0개면 **x-default 도 생략**하도록 바꿨다. 옳은가? 부작용이 있는가?
- R5. `test/integration/blog_indexing_test.rb` 에 **공허한 단언**이 있는가?
  특히 `body_en` 을 채운 상태의 로케일 분리 테스트가 실제로 회귀를 잡는가?
- R6. 고치지 않기로 한 것의 판단이 옳은가?
  (`/ja|es` 가 번역 없을 때 **영어 폴백**을 보여주는 것 · 무프리픽스 URL 의 **UI 크롬은
  여전히 협상**되어 `<html lang="en">` + 한국어 본문이 되는 것)

**출력 형식**:
```
[A-1 판정] 해소됨 | 부분 해소 | 미해소
근거: <파일:줄>
설명: ...

[A-2 판정] 해소됨 | 부분 해소 | 미해소
근거: <파일:줄>
설명: ...
```
그 다음 **새 지적**(있으면), 마지막에 R1~R6 답변.

---

## ② 수정 요약

### A-1 — 발행 상태를 색인 게이트에 반영

상태별 신호 기준(코드 주석에 표로 박아뒀다):

| status | 접근 | robots | hreflang | sitemap |
|---|---|---|---|---|
| `published` + 해당 로케일 번역됨 | 200 | (없음) | `indexable_locales` | 포함 |
| `published` + 미번역 로케일 | 200 | `noindex,follow` | `indexable_locales` | 제외 |
| `scheduled` | 200 (미리보기) | `noindex,follow` | **없음** (+x-default 도 없음) | 제외 |
| `draft` | 200 (미리보기) | `noindex,follow` | **없음** (+x-default 도 없음) | 제외 |

- `Post#indexable?(loc)` = `status == "published" && translated?(loc)` — 단일 규칙
- `Post#indexable_locales` — 미발행이면 `[]`
- 레이아웃: alternate 0개면 x-default 도 생략
- 사이트맵: `translated_locales` → `indexable_locales`
- **미리보기 200 은 유지**

### A-2 — 콘텐츠도 URL 로케일 기준으로

- `Post#title/body/meta_description` 이 로케일을 **필수 인자**로 받는다 (기본값 제거)
- 호출처: `posts/show.html.erb`(→`@url_locale`), `posts/index.html.erb`(→`url_locale`) 둘뿐
- **폴백 의미는 그대로** (비한국어 → 영어 컬럼 우선, 비면 한국어)
- `translated_locales` 삭제 (호출자 0, 죽은 쌍둥이가 재도입 통로가 된다)

### 검증 — `body_en` 을 실제로 채운 상태 (개발 DB, 실제 HTTP)

| URL | Accept-Language | 본문 | canonical | robots |
|---|---|---|---|---|
| `/blog/resume-privacy` | none / en / ja | **한국어** | `/blog/resume-privacy` | 없음 |
| `/en/blog/resume-privacy` | none / **ko** | **영어** | `/en/blog/resume-privacy` | 없음 |
| `/ja/blog/resume-privacy` | none | 영어 폴백 | `/blog/resume-privacy` | `noindex,follow` |

원복 후 DB 에 TEMP 마커 0건 확인.

### 회귀 검증

- `bin/rails test` → **58 runs / 278 assertions / 0 failures** (직전 46/190)
- 사이트맵 33개 전부 200·자기참조 canonical·noindex 0 / 내부 링크 103개 전부 해결
- Accept-Language(none/en/ja/es) × 무프리픽스 8페이지 → canonical 전부 불변
- `/blog/index.html`·`/safe` 계열 301 유지

---

## ③ 핵심 파일 전문

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

#### `app/views/posts/show.html.erb`

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
    "url": "<%= base_url %>/blog/<%= @post.slug %>",
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
      "@id": "<%= base_url %>/blog/<%= @post.slug %>"
    }
  }
  </script>
<% end %>

<% if @post.trust_bar.present? %>
<div class="blog-trust-bar">
  <%= @post.trust_bar %>
</div>
<% end %>

<div style="max-width: 640px; margin: 0 auto; padding: 2rem 1.25rem;">
  <%# Pain Tag %>
  <div class="blog-pain-tag"><%= @post.pain_tag.presence || @post.category.upcase %></div>

  <%# 제목 %>
  <h1 style="font-size: 22px; font-weight: 700; letter-spacing: -0.02em; margin-bottom: 6px;"><%= @post.title(@url_locale) %></h1>
  <% if @post.subtitle_ko.present? %>
    <p class="blog-subhead"><%= @post.subtitle_ko %></p>
  <% end %>

  <%# Meta %>
  <div class="blog-meta">
    <span><%= @post.published_at&.strftime("%Y.%m.%d") %></span>
    <span><%= t("blog.views", count: @post.view_count) %></span>
  </div>

  <%# Hero Image %>
  <% if @post.hero_image.attached? %>
    <div style="margin-bottom: 24px; border-radius: 14px; overflow: hidden; border: 0.5px solid #E5E3DC;">
      <%= image_tag @post.hero_image, style: "width: 100%; height: auto; display: block;", alt: @post.title_ko %>
    </div>
  <% end %>

  <%# Error Mockup %>
  <% if @post.error_mockup.present? %>
    <% mockup = begin; JSON.parse(@post.error_mockup); rescue; nil; end %>
    <% if mockup %>
    <div class="blog-error-mockup">
      <div class="blog-browser-bar">
        <div class="blog-browser-dots">
          <div class="blog-dot blog-dot-r"></div>
          <div class="blog-dot blog-dot-y"></div>
          <div class="blog-dot blog-dot-g"></div>
        </div>
        <div class="blog-url-bar"><%= mockup['url_bar'] %></div>
      </div>
      <div class="blog-error-body">
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:16px">
          <div style="width:30px;height:30px;background:<%= mockup['service_icon_color'] %>;border-radius:7px;display:flex;align-items:center;justify-content:center;color:#fff;font-size:14px;font-weight:800;flex-shrink:0">
            <%= mockup['service_icon_letter'] %>
          </div>
          <div>
            <strong style="display:block;font-size:14px;font-weight:700"><%= mockup['service_name'] %></strong>
          </div>
        </div>
        <div class="blog-error-alert">
          <div class="blog-error-icon">&#9888;</div>
          <div>
            <span class="blog-error-title"><%= mockup['error_title'] %></span>
            <p class="blog-error-desc"><%= mockup['error_desc'] %></p>
          </div>
        </div>
        <div class="blog-file-row">
          <div class="blog-file-icon">PDF</div>
          <div>
            <span class="blog-file-name"><%= mockup['file_name'] %></span>
            <span class="blog-file-date">방금 작성</span>
          </div>
          <div class="blog-size-badge"><%= mockup['size_label'] %></div>
        </div>
      </div>
    </div>
    <p style="text-align:center;font-size:12px;color:#6B6963;margin-bottom:24px;font-style:italic">많은 분들이 경험하는 바로 그 상황입니다.</p>
    <% end %>
  <% end %>

  <%# Recognition %>
  <% if @post.recognition_text.present? %>
  <div class="blog-recognition">
    <%= @post.recognition_text %>
  </div>
  <% end %>

  <%# Loss Box %>
  <% if @post.loss_items.present? %>
    <% items = begin; JSON.parse(@post.loss_items); rescue; []; end %>
    <% if items.any? %>
    <div class="blog-loss-box">
      <div class="blog-loss-title">지금 이 문제를 방치하면 잃게 되는 것</div>
      <ul>
        <% items.each do |item| %>
        <li>
          <div class="blog-loss-dot"></div>
          <span><%= item %></span>
        </li>
        <% end %>
      </ul>
    </div>
    <% end %>
  <% end %>

  <%# CTA #1 %>
  <a href="https://slimfile.net" class="blog-cta-inline-v2">
    <div class="blog-cta-inline-text">
      <strong>지금 바로 해결하기</strong>
      <span>무료 &middot; 회원가입 불필요 &middot; 30초 완료</span>
    </div>
    <div class="blog-cta-inline-btn">압축 시작 &rarr;</div>
  </a>

  <%# Stats %>
  <% if @post.stats.present? %>
    <% stats = begin; JSON.parse(@post.stats); rescue; []; end %>
    <% if stats.any? %>
    <div class="blog-stats-v2">
      <% stats.each do |stat| %>
      <div class="blog-stat-card">
        <div class="blog-stat-num"><%= stat['num'] %></div>
        <div class="blog-stat-label"><%= stat['label'] %></div>
      </div>
      <% end %>
    </div>
    <% end %>
  <% end %>

  <%# 본문 HTML (cause, steps, ba, situations, checklist, faq) %>
  <div class="blog-post-body">
    <%= @post.body(@url_locale).to_s.html_safe %>
  </div>

  <%# CTA #2 %>
  <div class="blog-cta-bottom-v2">
    <h3>지금 바로 해결하세요</h3>
    <p>무료 &middot; 회원가입 불필요 &middot; 30초 완료 &middot; 오늘 수천 명이 이미 사용 중</p>
    <div class="blog-btn-group">
      <a href="https://slimfile.net/compress" class="blog-btn-primary">이미지 압축 시작 &rarr;</a>
      <a href="https://slimfile.net/pdf" class="blog-btn-secondary">PDF 변환하기</a>
    </div>
  </div>

  <div style="text-align:center;margin-top:20px">
    <a href="/blog" style="font-size:13px;color:#6B6963;text-decoration:none">&larr; 블로그 목록으로</a>
  </div>
</div>
```

#### `app/views/posts/index.html.erb`

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
  <div class="page-header">
    <div class="page-header-icon" style="background: var(--compress-light);">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--compress)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>
    </div>
    <div>
      <h1><%= t("blog.heading") %></h1>
      <p class="page-desc"><%= t("blog.description") %></p>
    </div>
  </div>

  <div class="blog-categories">
    <%= link_to t("blog.all"), blog_path, class: "blog-cat-chip #{params[:category].blank? ? 'blog-cat-chip--active' : ''}" %>
    <% %w[privacy image pdf office student freelancer global].each do |cat| %>
      <%= link_to t("blog.categories.#{cat}"), blog_path(category: cat), class: "blog-cat-chip #{params[:category] == cat ? 'blog-cat-chip--active' : ''}" %>
    <% end %>
  </div>

  <% if @posts.any? %>
    <div class="blog-grid">
      <% @posts.each do |post| %>
        <article class="blog-card">
          <% if post.cover_svg.present? %>
            <div class="blog-card-cover"><%= post.cover_svg.html_safe %></div>
          <% else %>
            <div class="blog-card-cover blog-card-cover--placeholder">
              <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--compress)" stroke-width="1.5"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>
            </div>
          <% end %>
          <div class="blog-card-body">
            <span class="blog-card-cat"><%= t("blog.categories.#{post.category}") %></span>
            <h2 class="blog-card-title"><%= link_to post.title(url_locale), blog_post_path(slug: post.slug) %></h2>
            <p class="blog-card-desc"><%= truncate(post.meta_description(url_locale).to_s, length: 100) %></p>
            <time class="blog-card-date"><%= post.published_at&.strftime("%Y.%m.%d") %></time>
          </div>
        </article>
      <% end %>
    </div>
  <% else %>
    <div class="blog-empty">
      <p><%= t("blog.empty") %></p>
    </div>
  <% end %>

  <% if params[:category].present? %>
    <div class="blog-back-to-all">
      <%= link_to "#{t('blog.view_all')} →".html_safe, blog_path, class: "blog-back-to-all-link" %>
    </div>
  <% end %>
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

#### `app/views/layouts/application.html.erb`

```erb
<!DOCTYPE html>
<html lang="<%= I18n.locale %>">
  <head>
    <script>
      window.__jsErrors = [];
      window.addEventListener('error', function(e){
        window.__jsErrors.push((e.message||'?') + ' @ ' + (e.filename||'?') + ':' + (e.lineno||'?'));
      }, true);

      window.addEventListener('dragover', function(e){ e.preventDefault(); }, false);
      window.addEventListener('drop', function(e){
        var t = e.target;
        if (t && t.tagName === 'INPUT' && t.type === 'file') return;
        e.preventDefault();
      }, false);
    </script>
    <!-- Google tag (gtag.js) -->
    <script async src="https://www.googletagmanager.com/gtag/js?id=G-1RHNPW0ZTD"></script>
    <script>
      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag('js', new Date());
      gtag('config', 'G-1RHNPW0ZTD');
    </script>
    <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-9747637096324982" crossorigin="anonymous"></script>
    <title><%= content_for(:meta_title) || content_for(:title) || "SlimFile" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="mobile-web-app-capable" content="yes">
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

    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="<%= content_for(:meta_title) || content_for(:title) || 'SlimFile' %>">
    <meta name="twitter:description" content="<%= content_for(:meta_description) || t('seo.default_description') %>">
    <meta name="twitter:image" content="<%= content_for(:meta_image) || "#{base_url}/icon.png?v=2" %>">

    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <meta name="i18n-success" content="<%= t('toast.success') %>">
    <meta name="i18n-error" content="<%= t('toast.error') %>">
    <meta name="i18n-network-error" content="<%= t('toast.network_error') %>">
    <meta name="i18n-no-files" content="<%= t('toast.no_files') %>">

    <%# Upload limits mirror ConversionsController so client and server agree. %>
    <meta name="upload-max-files" content="<%= ConversionsController::MAX_FILES %>">
    <meta name="upload-max-size" content="<%= ConversionsController::MAX_FILE_SIZE.to_i %>">
    <%# %{count}/%{size}/%{name} are left as literal placeholders for upload_controller to fill. %>
    <meta name="i18n-upload-summary" content="<%= t('upload.selected_summary', count: '%{count}', size: '%{size}') %>">
    <meta name="i18n-upload-duplicates" content="<%= t('upload.duplicates_skipped', count: '%{count}') %>">
    <meta name="i18n-upload-drop-failed" content="<%= t('upload.drop_failed') %>">
    <meta name="i18n-upload-remove" content="<%= t('upload.remove_file', name: '%{name}') %>">
    <meta name="i18n-upload-excluded-note" content="<%= t('upload.excluded_note') %>">
    <meta name="i18n-upload-dnd-unsupported" content="<%= t('upload.dnd_unsupported') %>">
    <meta name="i18n-upload-reason-too-large" content="<%= t('upload.reason_too_large', max: number_to_human_size(ConversionsController::MAX_FILE_SIZE)) %>">
    <meta name="i18n-upload-reason-invalid-type" content="<%= t('upload.reason_invalid_type') %>">
    <meta name="i18n-upload-reason-too-many" content="<%= t('upload.reason_too_many', max: ConversionsController::MAX_FILES) %>">

    <%= yield :head %>

    <link rel="icon" type="image/x-icon" href="/favicon.ico?v=2">
    <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png?v=2">
    <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png?v=2">
    <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png?v=2">
    <link rel="manifest" href="/site.webmanifest?v=2">

    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
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
      ]
    }
    </script>
  </head>

  <body>
    <header class="top-bar">
      <div class="top-bar-inner">
        <div class="top-bar-brands">
          <%= link_to "SlimFile", root_path, class: "top-bar-logo" %>
          <span class="brand-sep" aria-hidden="true"></span>
          <%# SafeFile as its own logo (CSS bar icon reproduced from /safe/ header) %>
          <%= link_to "/safe/", class: "top-bar-safe" do %><span class="top-bar-safe-bar" aria-hidden="true"></span>SafeFile<% end %>
        </div>
        <div class="top-bar-right">
          <%= link_to t("nav_blog"), blog_path, class: "top-bar-nav-link" %>
          <details class="lang-dropdown">
            <summary class="btn-lang" aria-label="Select language"><%= locale_name(I18n.locale) %></summary>
            <ul class="lang-menu">
              <% I18n.available_locales.each do |loc| %>
                <li>
                  <%= link_to locale_name(loc), locale_switch_path(loc),
                        class: "lang-menu-item#{' is-active' if loc == I18n.locale}",
                        hreflang: loc, rel: (loc == I18n.locale ? nil : "alternate") %>
                </li>
              <% end %>
            </ul>
          </details>
        </div>
      </div>
    </header>
    <div class="bookmark-banner" data-controller="bookmark-banner" data-bookmark-banner-target="banner" style="display:none;">
      <span class="bookmark-banner-icon">&#11088;</span>
      <span class="bookmark-banner-text"><%= t("bookmark.message") %></span>
      <button class="bookmark-banner-close" data-action="bookmark-banner#dismiss">&times;</button>
    </div>
    <%= yield %>
    <% if params[:debug] %>
  <script>
    window.addEventListener('load', function(){
      setTimeout(function(){
        alert(
          'UA: ' + navigator.userAgent + '\n\n' +
          'Stimulus: ' + (typeof window.Stimulus) + '\n' +
          'importmap 지원: ' + (window.HTMLScriptElement && HTMLScriptElement.supports ? HTMLScriptElement.supports('importmap') : '알수없음') + '\n\n' +
          'JS 에러:\n' + (window.__jsErrors.join('\n') || '없음')
        );
      }, 1500);
    });
  </script>
<% end %>
  </body>
</html>
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

  # ── publication state gates indexing too ────────────────────────────────
  #
  #   status      robots           why
  #   ---------   --------------   -------------------------------------------
  #   published   (none)           live, body exists in this locale
  #   published   noindex,follow   body not translated into this locale
  #   scheduled   noindex,follow   not live yet, but served for preview
  #   draft       noindex,follow   served for preview, never indexable

  test "a draft is still served for preview" do
    get "/blog/draft-post"
    assert_response :success, "the preview link must keep working"
    assert_includes response.body, "초안"
  end

  test "a draft is never indexable, in any locale" do
    ["/blog/draft-post", "/en/blog/draft-post", "/ja/blog/draft-post"].each do |path|
      get path
      assert_equal "noindex,follow", robots(response.body), "#{path} is an unpublished draft"
    end
  end

  test "a scheduled post is served for preview but never indexable" do
    get "/blog/scheduled-post"
    assert_response :success
    assert_equal "noindex,follow", robots(response.body)
  end

  test "an unpublished post advertises no alternates at all" do
    # [] is a real answer, not "unspecified" — and x-default goes with it, since
    # a fallback pointer to a page nobody may index says nothing true.
    %w[/blog/draft-post /blog/scheduled-post].each do |path|
      get path
      assert_empty hreflangs(response.body), "#{path} must advertise no locale"
      assert_nil x_default(response.body), "#{path} must not emit x-default either"
    end
  end

  test "publishing is what opens the gate" do
    # Same Korean body in both; only status differs.
    get "/blog/korean-only-post"
    assert_nil robots(response.body)
    get "/blog/draft-post"
    assert_equal "noindex,follow", robots(response.body)
  end

  test "an unpublished post never reaches the sitemap" do
    get "/sitemap.xml"
    %w[draft-post scheduled-post].each do |slug|
      assert_not_includes response.body, "/blog/#{slug}"
    end
  end

  # ── content follows the URL, not the reader's browser ────────────────────
  #
  # The half-fix this closes: canonical/robots moved onto the URL while
  # title/description/body kept reading I18n.locale, so an unprefixed URL served
  # English to an `Accept-Language: en` request — the same content as the /en URL
  # at a second address, under a Korean canonical.

  test "an unprefixed URL serves Korean whatever the browser asks for" do
    NEGOTIATION_HEADERS.each do |headers|
      get "/blog/bilingual-published-post", headers: headers
      lang = headers.values.first

      assert_includes response.body, "KOBODY", "body switched language for #{lang}"
      assert_not_includes response.body, "ENBODY", "English body leaked onto the Korean URL for #{lang}"
      assert_includes response.body, "이중언어 발행 글"
      assert_not_includes response.body, "Bilingual published post"
      assert_includes response.body, "KODESC"

      assert_equal "#{BASE}/blog/bilingual-published-post", canonical(response.body)
      assert_nil robots(response.body)
    end
  end

  test "the English URL serves English and canonicalises to itself" do
    get "/en/blog/bilingual-published-post"
    assert_includes response.body, "ENBODY"
    assert_not_includes response.body, "KOBODY"
    assert_includes response.body, "Bilingual published post"
    assert_includes response.body, "ENDESC"
    assert_equal "#{BASE}/en/blog/bilingual-published-post", canonical(response.body)
    assert_nil robots(response.body)
  end

  test "the English URL is unmoved by an opposing header" do
    get "/en/blog/bilingual-published-post",
        headers: { "HTTP_ACCEPT_LANGUAGE" => "ko-KR,ko;q=0.9" }
    assert_includes response.body, "ENBODY"
    assert_equal "#{BASE}/en/blog/bilingual-published-post", canonical(response.body)
  end

  test "a locale cookie does not move a post's content either" do
    get "/en/blog/bilingual-published-post"   # sets the locale cookie to en
    get "/blog/bilingual-published-post"
    assert_includes response.body, "KOBODY"
    assert_not_includes response.body, "ENBODY"
  end

  test "the listing follows the URL's locale too" do
    get "/blog", headers: { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9" }
    assert_includes response.body, "이중언어 발행 글"
    assert_not_includes response.body, "Bilingual published post"

    get "/en/blog"
    assert_includes response.body, "Bilingual published post"
  end

  test "a translated post is advertised under both locales and each self-canonicalises" do
    get "/blog/bilingual-published-post"
    assert_equal [
      ["ko", "#{BASE}/blog/bilingual-published-post"],
      ["en", "#{BASE}/en/blog/bilingual-published-post"]
    ], hreflangs(response.body)

    hreflangs(response.body).each do |_loc, href|
      get href.sub(BASE, "")
      assert_equal href, canonical(response.body)
      assert_nil robots(response.body)
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

---

## ④ 정본 대조표 (이번 수정 관련)

| 규칙 (DECISIONS.md) | 구현 위치 |
|---|---|
| 색인 게이트는 발행 상태 + 번역 여부 둘 다 본다 | `Post#indexable?` |
| 미발행 글은 hreflang 을 하나도 안 내보내고 x-default 도 뺀다 | `Post#indexable_locales`, 레이아웃 |
| `title/body/meta_description` 도 URL 로케일을 인자로 받는다 (필수) | `Post`, `posts/show`, `posts/index` |
| 사이트맵 로케일 출처는 `indexable_locales` | `sitemap.xml.erb` |
| (기존) 색인 신호는 URL 에서 파생 | `ApplicationHelper#url_locale` |
| (기존) `hreflang_alternates(nil)`=전체, `([])`=없음 | `ApplicationHelper` |
| (기존) `page_meta` 는 뷰에서만 호출 | `posts/index`, `posts/show` |

## ⑤ 확신이 없는 지점 (이미 아는 것)

1. `/ja|es/blog/:slug` 는 번역이 없으면 **영어 폴백**을 보여준다(일본어 UI + 영어 본문).
   noindex 라 SEO 영향은 없다고 보고 폴백 우선순위를 바꾸지 않았다. **의견을 달라.**
2. 무프리픽스 URL 의 **UI 크롬은 여전히 협상**된다 — `<html lang="en">` 인데 본문은 한국어가
   되는 조합이 가능하다. 이번 요구 범위가 본문·제목·설명이었고, UI 까지 URL 기준으로 맞추면
   영어권 방문자가 `/` 에서 한국어를 보게 되므로 제품 결정이라 판단했다.
3. `loc` 를 필수 인자로 만든 것은 호출처 전수 grep(app·lib·db·script)에 근거한다.
   콘솔/레이크에서 `post.title` 을 부르던 습관이 있었다면 깨진다 — 조용히 틀리는 것보다
   낫다고 판단했다.
4. `indexable?` 가 `status == "published"` 문자열 비교다. `published` 스코프와 중복 표현이지만
   술어 메서드를 새로 만들지는 않았다.

## 비밀값 스캔 결과

```
grep -nEi "api[_-]?key|secret|password|token|BEGIN [A-Z ]*PRIVATE KEY|AKIA|ghp_|sk-[A-Za-z0-9]{20}" \
  docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_amber2.md
```

**매치 0건.** `.env` · `.env.production.local` · `config/master.key` · `.kamal/secrets` 미포함.
프로덕션 DB 내용도 없다 — 검증에 쓴 임시 `body_en` 은 **개발 DB** 에만 넣었다 원복했다.

이번에는 지난 라운드의 패키지 결함(`sed` 로 라우트 파일을 잘라 넣어 정작 검토 대상 라인이
빠졌던 것)을 반복하지 않기 위해 `config/routes.rb` 를 **전문**으로 넣었다.
