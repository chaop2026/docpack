# DocPack - Project Guide

## Design System: Bento Soft Grid

All UI must follow the Bento Soft design system. Reference this when creating or modifying any frontend code.

### Color Tokens

| Token | Value | Usage |
|-------|-------|-------|
| Page background | `#F8F7F4` | body background |
| Card background | `#ffffff` | all cards, modals, inputs |
| Card border | `0.5px solid #E5E3DC` | cards, tables, inputs |
| Primary text | `#1A1918` | headings, labels |
| Secondary text | `#6B6963` | descriptions, hints |

### Service Colors

| Service | Primary | Light | Text |
|---------|---------|-------|------|
| Image Compress | `#0A6E8A` | `#E1F5F9` | `#07596F` |
| PDF Conversion | `#F59E0B` | `#FEF3C7` | `#92400E` |
| SNS Resize | `#7C3AED` | `#EDE9FE` | `#4C1D95` |

Each service page uses its own color for: buttons, upload zone hover, progress bar, spinner, icon boxes, and tags.

### Typography

| Element | Size | Weight | Extra |
|---------|------|--------|-------|
| Page title | 22px | 600 | letter-spacing: -0.02em |
| Card title | 15px | 600 | letter-spacing: -0.01em |
| Body / desc | 13px | 400 | color: #6B6963, line-height: 1.55 |
| Tag (chip) | 10px | 600 | uppercase, letter-spacing: 0.04em |

### Border Radius

| Element | Radius |
|---------|--------|
| Page card | 20px |
| Button | 12px |
| Icon box | 14px |
| Tag / chip | 20px |
| Banner | 14px |

### Transitions

| Element | Effect |
|---------|--------|
| Card hover | `transform: translateY(-3px)`, `transition: 0.2s` |
| Banner hover | `transform: translateX(3px)`, `transition: 0.15s` |
| Button hover | `opacity: 0.88` |

### Banner Colors (cycling)

Banners cycle through three color themes in order:
1. **Teal** - icon box: `#E1F5F9`, CTA button: `#0A6E8A`
2. **Gold** - icon box: `#FEF3C7`, CTA button: `#F59E0B`
3. **Purple** - icon box: `#EDE9FE`, CTA button: `#7C3AED`

Banner cards use white background with `#E5E3DC` border (not solid-color backgrounds).

### CSS File

All styles are in `app/assets/stylesheets/application.css` using CSS custom properties (`:root` variables). The admin layout has its own inline styles in `app/views/layouts/admin.html.erb` following the same token system.

### Key CSS Classes

- `.feature-card--compress`, `.feature-card--pdf`, `.feature-card--social` - home cards
- `.btn--compress`, `.btn--pdf`, `.btn--social` - service-colored buttons
- `.upload-zone--compress`, `.upload-zone--pdf`, `.upload-zone--social` - upload hover colors
- `.banner-card--teal`, `.banner-card--gold`, `.banner-card--purple` - banner themes
- `.page-header-icon` - service icon with colored background

## Tech Stack

- Rails 8.0.4 + PostgreSQL 16
- Hotwire (Turbo + Stimulus)
- Propshaft (asset pipeline)
- Importmap (no Node.js)
- Docker Compose for development (port 3001)

## I18n

- English: `config/locales/en.yml`
- Korean: `config/locales/ko.yml`
- Toggle via cookie (`:locale`), controller: `LocalesController#toggle`
- Banner model has bilingual columns: `title_en/ko`, `description_en/ko`, `button_text_en/ko`

## Admin

- Path: `/admin` (redirects to `/admin/banners`)
- Login: `/admin/login`, password from `ENV["ADMIN_PASSWORD"]` (default: `docpack2025`)
- Session-based auth via `Admin::BaseController`

## Blog System

- Model: `Post` (title_ko/en, body_ko/en, slug, category, status, published_at, cover_svg, meta_description_ko/en, view_count)
- Categories: `pdf`, `image`, `office`, `student`, `freelancer`, `global`
- Status: `draft`, `scheduled`, `published`
- Routes: `GET /blog` → `posts#index`, `GET /blog/:slug` → `posts#show`
- Admin: `/admin/posts` — CRUD + AI generate/improve
- AI Service: `BlogGeneratorService` — uses Claude API via net/http (ENV `ANTHROPIC_API_KEY`)
- CSS: `.blog-*` classes in `application.css`
- I18n: `blog.*` keys in en.yml/ko.yml

### Blog Auto-Generation Pipeline

- **BlogTopic model**: `topic` (string), `category` (string), `used` (boolean, default: false)
- **100 SEO topics**: `db/seeds/blog_topics.rb` — 25 pdf, 20 image, 20 office, 15 student, 10 freelancer, 10 global
- **Seed command**: `rake blog:seed_topics`
- **Auto-generate job**: `AutoGenerateBlogPostJob` — picks random unused topic, calls Claude API, creates `scheduled` post with next MWF 9am KST publish date
- **Publish job**: `PublishScheduledPostsJob` — runs daily at 9am KST, publishes posts where `published_at <= now`
- **Schedule** (`config/recurring.yml`):
  - `auto_generate_blog_post`: every Mon/Wed/Fri at midnight KST (generates post ahead of time)
  - `publish_scheduled_posts`: every day at 9am KST
- **Rake tasks** (`lib/tasks/blog.rake`):
  - `rake blog:generate[N]` — batch generate N posts (default 10), each scheduled for next available MWF
  - `rake blog:seed_topics` — seed 100 topics from `db/seeds/blog_topics.rb`

## Email Notifications

- **BlogMailer**: sends email to `chaop2@gmail.com` when a blog post is published
- Triggered by `PublishScheduledPostsJob` after changing post status to `published`
- Email includes: post title, link, summary, upcoming scheduled posts, remaining topic count
- SMTP: Gmail via `smtp.gmail.com:587`
- **Required env vars** (configured in `.kamal/secrets` and `config/deploy.yml` env.secret):
  - `GMAIL_USERNAME` — Gmail address used as sender (e.g. `chaop2@gmail.com`)
  - `GMAIL_PASSWORD` — Gmail App Password (not regular password; generate at https://myaccount.google.com/apppasswords)
- **Status**: Gmail SMTP activated and verified on 2026-04-04. Test email sent successfully.
- Config: `config/environments/production.rb` (action_mailer.smtp_settings)
- Secrets in `config/deploy.yml` under `env.secret`

## Blog Automation Verification (2026-04-04)

- **Step 2 verified**: `PostsController#index` uses `Post.published.recent` — only published posts shown on /blog (correct)
- **Rake tasks added**: `blog:publish_test` (generate+publish 1 post), `blog:verify_autopublish` (test auto-publish flow)
- **Post-deploy commands** (run on production):
  1. `kamal app exec 'bin/rails blog:seed_topics'` — seed 100 topics
  2. `kamal app exec 'bin/rails blog:publish_test'` — generate & publish test post via Claude API
  3. `kamal app exec 'bin/rails blog:verify_autopublish'` — verify scheduled→published transition
- **Auto-publish flow**: `PublishScheduledPostsJob` runs daily at 9am KST, finds `scheduled` posts with `published_at <= now`, updates to `published`, sends email via `BlogMailer`
- **Auto-generate flow**: `AutoGenerateBlogPostJob` runs MWF midnight KST, picks random unused topic, generates via Claude API, schedules for next MWF 9am KST
- **SolidQueue fix (2026-04-07)**: `SOLID_QUEUE_IN_PUMA` was `false` with no separate worker container → recurring jobs never ran. Changed to `true` so Puma runs SolidQueue scheduler/worker inline.
- **SMTP fix (2026-04-07)**: `GMAIL_PASSWORD` was empty in production env → SMTPAuthenticationError 535-5.7.8. Fixed by adding Gmail credentials to `.env` and deploying with correct env vars.
- **Deploy note (updated 2026-08-25)**: Just run `kamal deploy` — no sourcing needed. `.kamal/secrets` now reads `.env.production.local` itself via `$(grep … | cut …)`. Do NOT `source .env` first: it holds local dev `DB_PASSWORD=postgres` and would poison the deploy. Production secrets live in the untracked `.env.production.local` (never commit).
- **Kamal secrets parser trap (2026-08-25)**: `.kamal/secrets` supports `$(command)` substitution but **not** bash `${VAR:-default}`. Given `${VAR:-$(…)}` it emits the literal `:-<value>}` instead of failing, so the registry rejects the malformed credential with a generic `denied: denied` — indistinguishable from an expired token. Use plain `$(...)` only. To tell a bad *value* from a bad *token*, compare `kamal secrets print | <length check>` against the expected length (a classic `ghp_` PAT is exactly 40 chars); `docker login --password-stdin` succeeding while Kamal's `-p` fails also points at the value, not the token.
- **Registry auth (ghcr.io)**: username must equal the PAT owner's GitHub login (`chaop2026`); the token needs scope `write:packages`. Verify a token with `curl -H "Authorization: token $T" https://api.github.com/user` — `401 Bad credentials` means expired/revoked, and classic PATs do expire.
- **Verification results (2026-04-04 01:39 UTC)**:
  - 100 blog topics seeded on production
  - Test post published: "reduce-pdf-file-size-without-losing-quality" (category: global)
  - Auto-publish verified: "youtube-channel-art-image-optimization-guide" scheduled→published via PublishScheduledPostsJob, email notification enqueued
  - Final state: 2 published, 9 scheduled, 89 unused topics
  - Next scheduled: business-file-sharing-optimization-guide (2026-04-08)

## Blog Content Strategy: Psychology-Based Marketing (v2, 2026-04-08)

All blog posts use structured JSON generation with psychological marketing hooks. The `BlogGeneratorService` generates structured data (not raw HTML body) for the show page.

### Post Model — New Columns (2026-04-08)
- `trust_bar` (string) — social proof bar at top
- `pain_tag` (string) — urgency tag label
- `subtitle_ko` (string) — subtitle under title
- `error_mockup` (text, JSON) — browser error mockup data
- `recognition_text` (text) — empathy/recognition paragraph
- `loss_items` (text, JSON array) — loss framing items
- `stats` (text, JSON array) — 3 key statistics

### Show Page Structure (app/views/posts/show.html.erb)
1. Trust bar (teal, social proof)
2. Pain tag + Title + Subtitle + Meta
3. Error mockup (browser-style with service branding)
4. Recognition box (amber callout)
5. Loss box (red border, 4 loss items)
6. CTA #1 (inline teal bar)
7. Stats row (3 cards)
8. body_ko HTML (cause cards, steps, B/A comparison, situations, checklist, FAQ)
9. CTA #2 (bottom card)

### CSS Classes (v2, suffixed to avoid conflicts)
- `.blog-cta-inline-v2`, `.blog-stats-v2`, `.blog-steps-v2`
- `.blog-checklist-v2`, `.blog-faq-v2`, `.blog-cta-bottom-v2`
- `.blog-error-mockup`, `.blog-recognition`, `.blog-loss-box`
- `.blog-ba-wrap`, `.blog-situation-grid`, `.blog-cause-list`

### Core Principles
- **Loss Aversion first**: Show what the reader is losing NOW before showing what they gain
- **Pain-point opening**: First sentence must pierce the reader's specific pain
- **Concrete numbers only**: No vague expressions — every claim includes specific numbers
- **Dual CTA**: Call-to-action appears after problem recognition AND at the end
- **Pre-emptive FAQ**: Address the objections readers are already thinking

### Hero Image System (BlogImageService)
- **Service**: `app/services/blog_image_service.rb`
- **Storage**: Active Storage (`has_one_attached :hero_image` on Post model)
- **Generation**: Claude API로 고품질 SVG 히어로 이미지 생성
- **Content**: 문제 상황 재현 (브라우저 에러 목업 + Before/After 비교)
- **ViewBox**: `0 0 800 420`, 상단 60% 에러 재현 / 하단 40% 해결 결과
- **Trigger**: AI 포스트 생성 시 자동, AutoGenerateBlogPostJob에서도 자동
- **Display**: `show.html.erb`에서 메타 정보 아래 히어로 이미지 표시
- **Note**: Google Imagen은 유료 전용. 추후 유료 전환 시 BlogImageService에서 Imagen 4.0 사용 가능

### SVG Cover Image Standard (cover_svg)
- viewBox: `0 0 600 280`
- Before box (red: `#FCEBEB`/`#A32D2D`) → SlimFile arrow (`#0A6E8A`) → After box (green: `#EAF3DE`/`#3B6D11`)
- Background: `#F8F7F4`, all text in Korean, sans-serif font
- Bottom: 3 benefits (speed, size, quality)

### Rake Tasks
- `blog:regenerate_scheduled` — Regenerate up to 5 scheduled posts with new prompt
- `blog:publish_new` — Generate 1 new post and publish immediately

## Blog Writing Strategy Manager (BlogStyle)

- **Model**: `BlogStyle` — stores writing strategy patterns extracted from reference scripts
- **Columns**: `source_name`, `raw_script`, `hooking_patterns` (JSON), `sentence_structure` (JSON), `psychological_triggers` (JSON), `tone_style` (JSON), `is_active` (boolean), `notes`
- **Admin UI**: `/admin/blog_styles` — list, create, show, edit, delete, analyze (Claude API), toggle active/inactive
- **Claude Analysis**: `analyze` action sends `raw_script` to Claude API, extracts marketing patterns into structured JSON fields
- **BlogGeneratorService integration**: Active strategies (up to 3, newest first) are injected into the system prompt when generating blog posts. Hooking patterns, psychological triggers, and tone style are summarized and appended.
- **Seed**: `db/seeds/blog_styles.rb` — default strategy with loss aversion, social proof, urgency patterns
- **Nav**: "글쓰기 전략" link in admin sidebar

## SafeFile Pipeline (v2 — coordinate-based redaction, 2026-07-19)

- **File**: single static `public/safe/index.html` (served directly by Rails, language-independent single URL `/safe/`).
- **Core model change**: previously extracted text → re-typed masked text onto a blank canvas (lost original layout). **Now**: render the *original page* to canvas → detect PII bounding boxes → overlay black bars / partial-value fills on the coordinates → flatten. Original tables/stamps/signatures/layout are preserved.
- **Input routing** (`handleFile`):
  - **PDF**: pdf.js renders each page to canvas + text-layer items give per-item boxes (`pdfjsLib.Util.transform`). Multi-page. If a page has <8 text chars → **scanned page**, falls through to OCR.
  - **Image (JPG/PNG/WEBP/HEIC)**: drawn to canvas (capped 2400px); HEIC converted via lazy `heic2any`. OCR via lazy **Tesseract.js**.
  - **docx/txt/paste/sample**: no visual original → `renderTextPages()` lays text onto white A4-ratio canvases recording exact word boxes. (User decision 2026-07-19: keep these, don't drop.)
- **Coordinate matching** (`boxesForValue`): per page a char→item index map (`buildIndex`); exact `indexOf` then spaceless fallback; sub-item boxes via proportional char width. Entities with no match get a "위치 못 찾음 / not located" chip and are excluded from the maskable count.
- **Live toggle** (problem #2 fix): the value shown next to each toggle is `displayValue(e)` — `ok`→original, `half`→`maskHalf()`, `no`→`■` blocks. Every toggle (bulk/category/individual) calls `renderAll()` → list + `drawPreview()` redraw instantly.
- **Redaction rendering** (`drawRedactions`): `no`→solid ink rect (covers original); `half`→sampled-bg rect + partial value drawn on top (`drawFitText`, clipped). Original pixels are always covered — never shown through.
- **Output** (`composePage` → flatten): each page composited (original + redactions + watermark) to a **raster** canvas. JPG/PNG single-page = one image, multi-page = per-page downloads. PDF = jsPDF embedding per-page JPEG at original pt size → **no text layer, page count + size preserved**. Verified: output PDFs have 0 extractable text, 0 PII leak (pymupdf).
- **Watermark**: optional diagonal repeated semi-transparent text (`drawWatermark`, opacity 0.10). 4-lang presets + free text. **Bottom 14% + top 5% kept clear** (QR/barcode/stamp margin rule — user decision: margin only, no auto QR detection; 4-lang notice warns the user to check). Watermark-only (no masking) supported — make button enables when watermark on even with 0 masked.
- **Lazy CDN libs**: Tesseract.js (`@5.1.1`, langs `kor+eng`/`eng`/`jpn+eng`/`spa+eng` by UI lang), heic2any (`@0.0.4`), jsPDF (`cdnjs 2.5.1` — note: 2.5.2 is 404 on cdnjs). pdf.js + mammoth loaded eagerly (existing).
- **Progress**: `#prog` bar + `#scanStatus` text for page render (`renderProg`), OCR (`ocrProg` %), HEIC convert, build.
- **Privacy unchanged**: all processing in-browser; only AI deep scan (`/api/safe_scan`) sends extracted text (now text-only, never image) — controller unchanged.
- **i18n**: `I18N` dict in-file, ko/en/ja/es. New keys added for limits/OCR/watermark/render progress/errors.
- **Known limitations** (detection recall, not redaction mechanics): names/companies need AI deep scan (server, `ANTHROPIC_API_KEY`); Korean OCR recall is imperfect on low-quality scans; address regex captures approximate spans. Boxes that *are* found are placed accurately.
- **Design tokens unchanged**: `--paper #F7F5EF / --ink #17140F / --marker #FFE066`, IBM Plex.
- **Local verification** (2026-07-19, Playwright + system Chrome, 5 docs): text PDF / scanned-image PDF / JPG photo / table PDF / multi-page PDF — all passed layout preservation, mask positioning, 0 text-leak, live toggle, watermark, 4-lang switch.

## SEO & Sitemap

- Domain: `https://slimfile.net` (default `BASE_URL` in `app/helpers/application_helper.rb`)
- Dynamic sitemap: `GET /sitemap.xml` → `PagesController#sitemap` → `app/views/pages/sitemap.xml.erb`
- Static fallback: `public/sitemap.xml` (update manually when pages change)
- `public/robots.txt` includes `Sitemap: https://slimfile.net/sitemap.xml`
- Pages in sitemap: `/`, `/compress`, `/pdf`, `/social`, `/about`, `/faq`, `/blog`, `/blog/:slug`
- OG meta, Twitter cards, and JSON-LD structured data are in `app/views/layouts/application.html.erb`
- Per-page meta via `page_meta` helper in `ApplicationHelper`
- Google Search Console verification: `<meta name="google-site-verification">` in `application.html.erb`
- Blog posts: JSON-LD Article schema, og:type=article, article:published_time/modified_time in `posts/show.html.erb`
- AEO: `public/llms.txt` for AI/LLM discoverability, FAQ page with JSON-LD FAQPage schema
- Blog post hero images set as og:image when attached

## Static-page canonical / URL de-duplication (2026-09-17)

GSC 가 `/safe/` 를 **"사용자가 선택한 표준이 없는 중복 페이지"**(Duplicate without
user-selected canonical) 로 분류한 건에 대한 조사·수정 기록.

### 발견한 것 — 동일 바이트를 200 으로 돌려주는 URL 이 4개, canonical 태그는 0개

| URL | 어디서 발견되나 | 조사 전 응답 |
|---|---|---|
| `/safe/` | sitemap.xml, 상단바 링크 | 200 (127,444 B) |
| `/safe/?v=20260719` | **홈 카드 링크 (4개 로케일 전부)** | 200 (동일 바이트) |
| `/safe` | 외부 링크·수동 입력 | 200 (동일 바이트) |
| `/safe/index.html` | sw.js 프리캐시 목록 | 200 (동일 바이트) |

`public/safe/index.html` 에는 `<link rel="canonical">` 이 **아예 없었다**. 같은 내용을 주는
URL 이 여럿인데 페이지가 대표 URL 을 스스로 선언하지 않는 상태 — GSC 문구 그대로의 입력 조건이다.
sitemap 은 `/safe/` 를 신고하는데 홈에서 실제로 링크되는 건 `?v=` 쪽이라, Google 이 다른 URL 을
대표로 고르고 `/safe/` 를 중복으로 떨어뜨렸다.

### 왜 `/safe` 가 200 이었나 (라우트는 분명히 리다이렉트였는데)

`config/routes.rb` 의 `get "/safe", to: redirect("/safe/")` 는 **한 번도 실행된 적이 없다.**
`ActionDispatch::Static` 이 라우터보다 **앞**에 있고, `ActionDispatch::FileHandler` 가
`/safe` 요청을 `public/safe` → `public/safe.html` → `public/safe/index.html` 순으로 탐색해
마지막에서 200 을 먼저 돌려주기 때문. 라우터까지 요청이 도달하지 않으므로 그 라인은 죽은 코드였다.
**트레일링 슬래시 정규화는 정적 핸들러보다 앞선 레이어(Rack 미들웨어)에서 해야 한다.**

### 언어별 URL 은 존재하지 않는다 (hreflang 관련 중요)

`/ko/safe/`·`/en/safe/`·`/ja/safe/`·`/es/safe/` 는 전부 404 다 (라이브 확인).
`routes.rb` 의 로케일 스코프는 `en|ja|es` 로 제한돼 있고 `/safe` 는 그 스코프 **밖**이다.
`/safe/` 는 **단일 URL 이 4개 언어를 클라이언트에서 전환**하는 구조
(`localStorage safefile_lang` → `navigator.language`, `I18N` 딕셔너리 + `data-i18n` 속성).
→ 언어 간 상호참조 hreflang 은 **가리킬 대상 URL 이 없다.** 이 구조에 대해 Google 이 문서화한
패턴은 `x-default` 자기참조 하나뿐이므로 그것만 넣었다. ko/en/ja/es 알터네이트를 전부 같은 URL 로
찍는 것은 거짓 신호라 넣지 않았다.

### 수정 내역

- `public/safe/index.html` — self-referencing `canonical` = `https://slimfile.net/safe/`,
  `hreflang="x-default"` 자기참조, `robots`, og:(type/site_name/url/title/description/image/locale
  +alternate ×3), twitter:(card/title/description/image). **이것이 1차 수정**이며 `?v=` 쿼리
  중복까지 Google 이 통합하게 한다.
- `lib/static_index_redirect.rb` (신규) + `config/initializers/static_index_redirect.rb` —
  `ActionDispatch::Static` **앞**에 삽입되는 Rack 미들웨어. `/safe`·`/safe/index.html` 및
  `/privacy`·`/privacy/index.html` 을 트레일링 슬래시 URL 로 **301**. 쿼리스트링 보존,
  GET/HEAD 만 (POST 는 301 로 바꾸면 메서드·본문이 조용히 사라진다), `cache-control: no-cache`
  (영구 캐시된 301 은 브라우저에서 사실상 되돌릴 수 없다 — 이 앱은 이미 캐시 고착으로 한 번 당했다).
- `config/routes.rb` — 죽어 있던 `get "/safe", to: redirect("/safe/")` 제거 + 왜 죽어 있었는지 주석.
- `public/safe/sw.js` — `SHELL_ASSETS` 에서 `/safe/index.html` 제거(이제 301 이고,
  `cache.put()` 은 리다이렉트된 Response 를 거부하므로 프리캐시가 조용한 no-op 이 된다).
  오프라인 폴백을 `caches.match('/safe/')` 로 변경 + `ignoreSearch: true`
  (홈이 `/safe/?v=…` 로 링크하므로 이게 없으면 그 내비게이션이 캐시를 못 맞춘다).
- `app/views/pages/sitemap.xml.erb` — `/safe/` 항목에 `x-default` 알터네이트 추가 + 트레일링
  슬래시가 필수인 이유 주석.
- `app/views/pages/home.html.erb` — `?v=20260719` 는 **유지**(2026-07-15~07-19 나흘 사이에
  1년 캐시로 고착된 항목이 2027-07-19 까지 남아 있다). canonical 이 통합하므로 SEO 손실은 없다.
  그 날짜 이후 제거하라는 주석을 남겼다.
- `Gemfile` — `minitest "~> 5.25"` 핀. **부수 발견**: minitest 6.0.2 로 해석되면서
  railties 8.0.4 의 `rails/test_unit/line_filtering.rb`(2-arity `run`)와 충돌해
  모든 Rails 테스트가 단언 하나 못 돌리고 죽고 있었다("0 tests" 로 조용히 통과처럼 보였다).
- `test/integration/static_canonical_test.rb` (신규) — 리다이렉트·canonical·hreflang·sitemap
  회귀 가드 12개.

### 검증 (로컬 `localhost:3001`, 배포 전)

- Rack 단위 17 케이스 통과 (리다이렉트 대상·쿼리 보존·POST 통과·에셋 통과).
- `bin/rails test` → 12 runs / 35 assertions / 0 failures.
- Playwright(시스템 Chrome) 렌더 검증: `/safe/`·`/safe`·`/safe/index.html`·`/safe/?v=…`
  네 진입점 모두 최종 200, canonical·x-default·og:url 동일, hreflang 링크 정확히 1개,
  히어로·드롭존 렌더, JS 에러 0.
- 서비스워커 검증: 설치·활성 정상, 셸 캐시에 `/safe/` 있고 `/safe/index.html` 없음,
  매니페스트 4개 프리캐시, **오프라인에서 `/safe/` 와 `/safe/?v=…` 둘 다 셸 서빙**.
- 리다이렉트 홉 1회(체인 없음), 전체 라우트 16개 스모크 200.

### 외부 교차검증 (Codex CLI, read-only)

- 패키지: `docs/review/CODEX_REVIEW_PACKAGE_2026-09-17.md` (비밀값 0건 확인)
- 원문: `docs/review/CODEX_RESULT_2026-09-17.md` (codex-cli 0.144.3, 69초, 단일 조각)
- 대조: `docs/review/CROSS_REVIEW_TRIAGE_2026-09-17.md` — 7건 전부 (a)/(b)/(c) 분류
- (a) 2건 지적 → **둘 다 수정 완료 (2026-09-17, 아래 절)**

## 교차검증 (a) 2건 수정 (2026-09-17)

### A-1 (AMBER) — 서비스워커가 실패한 업데이트에 오프라인 셸을 잃던 문제

**증상**: `install` 이 모든 프리캐시를 `.catch(() => null)` 로 감싸 `/safe/` fetch 실패를
성공으로 처리 → `skipWaiting()` 으로 인계 → `activate` 가 구버전 `safefile-*` 캐시를 전부 삭제.
결과적으로 **양쪽 셸을 다 잃는다.** 업데이트가 "성공"을 보고하므로 밖에서는 보이지 않는다.

**수정** (`public/safe/sw.js`):
- `SHELL_ASSETS` 를 `REQUIRED_SHELL`(`/safe/`) + `OPTIONAL_SHELL_ASSETS`(아이콘·매니페스트)로 분리.
  공통 `precache()` 헬퍼가 `!r.ok` 와 **`r.redirected`** 를 모두 실패로 올린다
  (리다이렉트된 Response 는 `cache.put()` 이 거부하므로 읽을 수 있는 이유로 바꿔준다).
- `install` 은 `REQUIRED_SHELL` 을 **먼저, 실패를 전파하며** 캐시한다. 실패하면 install 자체가
  reject → `skipWaiting()` 도 activate 도 일어나지 않고 **구 SW 와 구 캐시가 그대로 살아남는다**.
  브라우저가 다음 방문에 업데이트를 재시도한다. 옵션 자산은 개별 실패를 계속 허용한다.
- `activate` 는 삭제 전에 `cache.match(REQUIRED_SHELL)` 로 **새 셸 존재를 확인**한다. 없으면
  구버전 캐시를 **남긴다** — fetch 폴백의 전역 `caches.match()` 는 오리진의 **모든** 캐시를
  뒤지므로 구버전 셸로도 앱이 열린다. 삭제는 되돌릴 수 없고 브라우저는 저장공간 압박 시
  임의로 엔트리를 버릴 수 있으므로, 가정하지 않고 확인한다.
- 페이지의 `navigator.serviceWorker.register(...)` 에는 이미 `.catch(()=>{})` 가 있어
  install 실패를 조용히 흡수한다 (확인함, `index.html:1887`).

**검증 — 인위적 네트워크 실패 주입** (`test/sw/`, 신규):
`/safe/` 를 503 으로 떨어뜨리는 Node 서버 + `__SW_BUILD__` 치환으로 실제 새 워커 버전을 만들어
실제 Chrome 을 3단계로 몬다. **수정본**: 구버전 캐시 생존 ✅, 오프라인 `/safe/`·`/safe/?v=` 둘 다
셸 서빙 ✅, 복구 후 신버전 캐시 생성 + 구버전 정리 ✅ (9/9 통과).
**수정 전 워커로 같은 하네스를 돌리면 3건 실패** — 구버전 캐시가 삭제되고 오프라인 내비게이션이
`net::ERR_FAILED` 로 죽는다. 테스트가 실제로 이 버그를 잡는다는 증거다 (`--old` 플래그).

### A-2 (GREEN) — 301 본문이 쿼리스트링을 이스케이프 없이 반사하던 문제

현재 스택에서는 도달 불가였다(raw `<`/`>`/`"` 는 Puma 가 400 으로 거부, 브라우저는 `Location`
있는 301 본문을 렌더하지 않음). **그러나 안전의 근거가 우리 코드가 아니라 상류 파서였다** —
서버를 바꾸거나 프록시를 앞에 두면 보장이 사라진다. 그래서 고쳤다.

**수정** (`lib/static_index_redirect.rb`):
- `body_for()` 가 `CGI.escapeHTML(location)` 을 거친다 (`require "cgi/escape"`).
- `redirect_location()` 이 쿼리스트링에서 `\r`·`\n` 을 제거한다 — 헤더 분리 방어를 파서에
  맡기지 않는다.
- 두 동작 모두 **왜 상류에 의존하면 안 되는지**를 주석으로 남겼다.

**검증**: `test/lib/static_index_redirect_test.rb` (신규 13개). 통합 테스트 스택은 URI 를
percent-encode 해버려 raw 바이트를 주입할 수 없으므로(그래서 단언이 공허해진다),
**Rack env 를 직접 만들어** 미들웨어 단위로 검증한다 — 이스케이프가 이 파일의 성질임을 확인할 수
있는 유일한 고도다. `"><script>` · `a" onmouseover=` · `&`·`'` · CRLF · percent-encoded 케이스
전부 커버.

### 재검증 결과 (회귀 없음, 전부 로컬)

| 검증 | 결과 |
|---|---|
| Rack 단위 케이스 | 25/25 통과 (라우팅 17 + SCRIPT_NAME + 이스케이프 4 + CRLF 2 + 가독성 1) |
| `bin/rails test` | **25 runs / 87 assertions / 0 failures** (수정 전 12/35) |
| Playwright 렌더 4개 진입점 | 전부 통과 — canonical 동일, hreflang 1개, JS 에러 0 |
| 서비스워커 설치·오프라인 폴백 | 통과 — `/safe/`·`/safe/?v=` 둘 다 |
| **SW 네트워크 실패 주입** | **9/9 통과** (수정 전 워커는 3건 실패 — 하네스 실효성 확인) |
| 라이브 HTTP 형태 | `/safe`·`/safe/index.html`·`/privacy` 301, `/safe/`·`/safe/sw.js` 200 |
| 실제 Puma 경유 이스케이프 | percent-encoded 그대로 유지, 마크업 미생성 |

### 라운드 2 교차검증 (수정 확인)

- 패키지 `docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_round2.md` (비밀값 0건)
- 원문 `docs/review/CODEX_RESULT_2026-09-17_round2.md` (codex-cli 0.144.3, 58초)
- 대조 `docs/review/CROSS_REVIEW_TRIAGE_2026-09-17_round2.md`
- **A-1 `해소됨` · A-2 `해소됨` · 새 지적 0건. 미해결 항목 없음.**
  R1~R5(구 캐시 보존 경로 · 빈 캐시 잔존 · 이스케이프의 소재 · 공허한 단언 여부) 전부 우리 판정과 일치.
- Codex 명시 한계: 줄 번호 대조만 했고 테스트를 재실행하지 않았다 — 실행 검증은 위 표가 담당한다.
- self-check 로 따로 잡은 것: `String#delete("\r\n")` 은 부분문자열이 아니라 **문자 집합**을
  지운다(의도대로 동작하나 오해를 부름) → 주석 추가.

## 미색인 63개 조사 — noindex 40 / 404 1 / 중복 2 (2026-09-17)

GSC 페이지 색인 리포트(알려진 134 = 색인 71 + 미색인 63) 조사 기록.
**프로덕션 DB 는 건드리지 않았다** — 전부 라이브 HTTP 실측(202 URL 크롤)과 코드/깃 이력으로 판별.

### noindex 가 붙는 곳 — 전수 목록

| 위치 | 조건 | 영향 |
|---|---|---|
| `app/views/posts/show.html.erb:9` | `unless @post_translated` → `noindex,follow` | **유일한 동적 noindex.** 아래 참조 |
| `app/views/layouts/application.html.erb:36` | `content_for?(:robots)` 일 때만 태그 출력 | 전달 통로. 스스로 판단 안 함 |
| `public/{400,404,422,500,406-*}.html` | 정적 에러 페이지 | 정상 (색인 대상 아님) |
| `public/privacy/index.html:9` | `index,follow` | noindex 아님 |
| `public/robots.txt` | `Disallow: /admin`, `/conversions` | noindex 아님 (크롤 차단) |
| **X-Robots-Tag 헤더** | **어디에도 없음** (라이브 9개 경로 확인) | — |

게이트는 **draft 승인이 아니라 번역 여부**다 (`Post#translated?`): `ko`→`body_ko`,
`en`→`body_en`, **`ja`/`es`는 언제나 false**. draft 상태는 noindex 와 무관하다.

### 실측 결과

- 사이트맵 42개 글 **전부 `ko` 단독** — 42개 모두 `body_en` 이 비어 있다.
- 따라서 글 하나당 noindex URL 3개(en/ja/es) → **라이브 noindex 총 126개** (크롤로 확인:
  `noindex,follow` 126 = en 42 + ja 42 + es 42, ko 0, 정적 페이지 0).
- GSC 의 40 은 이 126 중 **구글이 지금까지 크롤한 부분집합**이다. 방치하면 126 까지 늘어난다.
- 의도가 맞는지 검증: `/en|ja/blog/:slug` 본문이 한국어판과 **97.6~98.8% 동일**, 한글 비율 51~57%
  → 본문이 번역되지 않은 한국어 그대로다. **noindex 는 옳다.**

### 3분류

**① 정상 (의도된 noindex) — 126 URL**
판별 기준: *URL 이 표방하는 언어로 본문이 실제 번역돼 있지 않다.*
예: `/en/blog/resume-privacy`, `/ja/blog/resume-privacy`, `/es/blog/resume-privacy`.
의도는 `app/models/post.rb:31` 에 기록돼 있다. **수정하지 않았다.**

**② 문제 (의도치 않음) — 6증상 / 5개 수정**
판별 기준: *신호끼리 서로 모순되거나, 색인돼야 할 URL 이 색인에서 빠진다.*

1. **한국어 정본 URL 이 요청 헤더에 따라 noindex 를 반환했다.** ★가장 심각
   `curl -H 'Accept-Language: en-US' https://slimfile.net/blog/resume-privacy` →
   `noindex,follow`. `set_locale` 우선순위가 `URL 프리픽스 → 쿠키 → Accept-Language` 라서,
   프리픽스 없는 정본 URL 의 로케일이 **요청자에 따라 달라지고** 게이트가 그 값을 읽었다.
   같은 URL 이 크롤러마다 다른 색인 지시를 보내는 상태였다.
2. **프리픽스 없는 페이지의 canonical 이 `/en/...` 로 이동했다.** 같은 원인.
   `/faq`→`/en/faq`, `/`→`/en`, `/compress`→`/en/compress`, `/pdf`, `/social` (5개).
   `/about`·`/blog` 는 `page_meta` 가 레이아웃에 도달하지 못해 **우연히** 무사했다.
3. **`/blog/index.html` (+`/en|ja|es` 3개) 404.** `public/blog/index.html` 이 정적 파일이던
   시절 `/blog`·`/blog/`·`/blog/index.html` 이 모두 200 이었고, `9f8bfff`(2026-07-17)가
   파일을 지우면서 `/blog/:slug` 의 slug=`index.html` 로 흘러 404 가 됐다.
   **GSC "찾을 수 없음 1페이지"의 최유력 후보.**
4. **사이트맵이 `?category=privacy`(×4)를 실었다.** 그 페이지들의 canonical 은 `/blog` 다 —
   자기 주소를 부정하는 URL 을 사이트맵에 올린 모순.
5. **페이지 hreflang 이 글마다 4개 로케일을 광고했다.** 사이트맵은 늘 `ko` 하나만 실었다.
   광고 대상(`/ja/blog/:slug`)은 noindex 이고 canonical 도 한국어판을 가리킨다 —
   Google 규칙(hreflang 대상은 canonical·색인 가능이어야 함) 위반이자,
   **126개 noindex URL 이 발견된 경로 자체**다.
6. **`/blog` 4개 로케일 전부 `<title>`·description 이 없었다.** `PostsController#index` 가
   `helpers.page_meta` 를 호출했는데 컨트롤러발 `content_for` 는 레이아웃에 닿지 않는다
   (이미 아는 함정인데 재발). 라이브 `<title>` 이 기본값 `SlimFile` 이었다.

**③ 판단 불가 — 2건**
- **"Google 에서 사용자와 다른 표준을 선택함" 2페이지가 정확히 어느 URL인지.** 추정만 가능.
  데이터: `/en/blog`·`/ja/blog`·`/es/blog` 의 본문이 `/blog` 와 **89.5~91.8% 동일**
  (글 제목이 전부 한국어라 UI 크롬만 다르다). 자기참조 canonical 을 선언하지만 Google 이
  `/blog` 로 묶었을 가능성이 가장 높다 — 3개 중 2개가 보고된 수와 맞는다.
  반증된 가설: 글끼리의 중복(42개 전수 쌍 비교, 최대 유사도 0.612 · 중앙값 0.262 — 중복 아님).
  ②-1/②-2 로 canonical 이 요청마다 흔들린 것도 Google 이 선언을 불신할 이유가 된다.
- **draft/scheduled 글이 색인됐는지.** `PostsController#show` 는 `draft`·`scheduled` 도 200 으로
  서빙하고, 한국어 본문이 있으면 **noindex 가 붙지 않는다.** 사이트맵·목록에는 안 나오므로
  슬러그를 알아야 도달하지만 구조적으로는 열려 있다. 개수는 프로덕션 DB 없이 셀 수 없다.

### 수정 (a등급만)

- `app/helpers/application_helper.rb` — `url_locale` 신설(요청 경로에서 로케일 추출).
  `page_meta` 가 `locale_prefixed(path, url_locale)` 를 쓴다. **색인 신호는 협상이 아니라 URL 에서 나온다.**
- `app/controllers/posts_controller.rb` — `@url_locale` 로 게이트 판정, `@hreflang_locales` 전달,
  `index` 의 죽은 `page_meta` 호출 제거.
- `app/views/posts/show.html.erb` — canonical 을 `@url_locale` 로 산출.
- `app/views/posts/index.html.erb` — `page_meta` 를 뷰로 이동.
- `app/views/layouts/application.html.erb` + `hreflang_alternates(locales = nil)` — 로케일 집합을
  좁힐 수 있게. `nil`=전체, `[]`=없음(`.presence` 폴백 금지).
- `config/routes.rb` — `/blog/index.html` → 301 `/blog` (로케일 보존, `/blog/:slug` 보다 위).
- `app/views/pages/sitemap.xml.erb` — `?category=` 블록 제거.

**수정하지 않은 것**: ①의 126개 noindex(의도대로임), `/xx/blog` 목록 페이지의
hreflang·canonical(전략 판단), draft 공개 서빙(동작 결정), admin 의 robots.txt 의존.

### 검증

- `bin/rails test` → **46 runs / 190 assertions / 0 failures** (수정 전 25/87).
  신규 `test/integration/blog_indexing_test.rb` 22개 + `test/fixtures/posts.yml`(ko전용·이중언어 2종).
- 로컬 전수 감사: 사이트맵 33개 전부 200·자기참조 canonical·noindex 0,
  내부 링크 대상 103개 전부 해결.
- Accept-Language 매트릭스(none/en/ja) × 7개 무프리픽스 페이지 → canonical 전부 불변.
- `/blog` `<title>` = `블로그 - SlimFile`, 사이트맵 `?category=` 0개,
  `/blog/index.html`·`/en|ja/blog/index.html` 301.

### 외부 교차검증 (Codex CLI, read-only)

- 패키지 `docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_indexing.md` (비밀값 0건)
- 원문 `docs/review/CODEX_RESULT_2026-09-17_indexing.md` (codex-cli 0.144.3, 65초)
- 대조 `docs/review/CROSS_REVIEW_TRIAGE_2026-09-17_indexing.md` — 9건 전부 (a)/(b)/(c) 분류
- **미해결 (a) 2건 — 다음 런. 이번 세션에서는 고치지 않았다**:
  1. **AMBER** `draft`/`scheduled` 글이 공개 200 이면서 **noindex 가 안 붙는다**
     (게이트가 번역 여부만 보고 발행 상태는 안 본다). 우리가 "③ 판단 불가"로 분류했던 건데,
     개수는 못 세도 **코드 조건은 확정적**이라 Codex 분류가 더 정확하다.
     → `show.html.erb` 한 줄, 미리보기 200 은 유지하고 색인만 막는다.
  2. **AMBER** 이중언어 글이 무프리픽스 URL 에서 **본문·제목·설명을 여전히 협상**한다
     (`Post#title/body/meta_description` 가 `I18n.locale` 을 읽는다). 이번 수정이
     신호만 URL 기준으로 옮기고 내용은 남겨둔 절반짜리였다. **재현 확인**:
     `/blog/bilingual-post` + `Accept-Language: en` → 제목·설명·본문 전부 영어인데
     canonical 은 한국어 주소. 지금은 42개 글이 전부 한국어 단독이라 잠복이지만,
     **`body_en` 을 하나라도 채우면 즉시 중복 페이지가 생긴다 — 번역 전에 고칠 것.**
- Codex 가 확인해준 것: 사이트맵 `?category=` 제외 판단(재추가 조건까지 일치),
  `nil`/`[]` 구분, 공허한 단언 없음, 126개 noindex 유지 판단.
- 우리 패키지 결함 1건: `config/routes.rb` 를 `sed` 로 잘라 넣어 정작 redirect 라인이 빠졌다.
  다음부터 라우트 파일은 전문으로 넣는다. (제기된 우려는 반증됨 —
  `"index.html".parameterize` → `"index-html"` 이라 슬러그 충돌이 생길 수 없다.)

## 교차검증 AMBER 2건 수정 (2026-09-17)

`docs/review/CROSS_REVIEW_TRIAGE_2026-09-17_indexing.md` 의 (a) 2건.

### A-1 — 발행 상태가 색인 게이트에 반영되지 않던 문제

**증상**: `PostsController#show` 가 `draft`·`scheduled` 도 200 으로 서빙하는데,
게이트(`unless @post_translated`)는 **번역 여부만** 봤다. 한국어 본문이 있는 초안은
`translated?(:ko)` 가 true 라 noindex 가 안 붙었다 — 미발행 글이 색인 가능한 공개 페이지였다.

**상태별 신호 기준** (`Post#indexable?` 에 표로 박아뒀다):

| status | 접근 | robots | hreflang | sitemap |
|---|---|---|---|---|
| `published` + 해당 로케일 번역됨 | 200 | (없음) | `indexable_locales` | 포함 |
| `published` + 미번역 로케일 | 200 | `noindex,follow` | `indexable_locales` | 제외 |
| `scheduled` | 200 (미리보기) | `noindex,follow` | **없음** (+x-default 도 없음) | 제외 |
| `draft` | 200 (미리보기) | `noindex,follow` | **없음** (+x-default 도 없음) | 제외 |

**수정**:
- `Post#indexable?(loc)` = `status == "published" && translated?(loc)` — 모든 색인 신호의 단일 규칙.
- `Post#indexable_locales` — 미발행이면 `[]`. **빈 배열은 진짜 답**이므로 그대로 둔다
  (`hreflang_alternates` 의 `nil`≠`[]` 규칙이 여기서 쓰인다).
- 레이아웃: alternate 가 0개면 **x-default 도 출력하지 않는다.** 아무도 색인할 수 없는
  페이지를 가리키는 폴백 포인터는 참인 말이 아니다. (지난 라운드 Codex 의 B-1 지적을 여기서 해소)
- 사이트맵: `translated_locales` → `indexable_locales`. 위의 `Post.published` 스코프가
  혹시 바뀌어도 미발행 글이 샐 수 없다.
- **미리보기 200 은 그대로다.** 바뀐 것은 색인 지시뿐이다.

### A-2 — 절반짜리 수정 완결: 콘텐츠도 URL 기준으로

**증상**: canonical·robots·hreflang 은 `@url_locale` 로 옮겼는데 `Post#title/body/meta_description`
는 계속 `I18n.locale` 을 읽었다. 무프리픽스 URL 이 `Accept-Language: en` 요청에 **영어 제목·설명·본문**을
내보내면서 canonical 은 한국어 주소를 가리켰다 — `/en/blog/:slug` 와 같은 내용이 두 번째 주소에 생긴다.

**수정**: `Post#title/body/meta_description` 이 로케일을 인자로 받는다(`def title(loc = I18n.locale)`).
호출처는 `posts/show.html.erb`(→`@url_locale`) 와 `posts/index.html.erb`(→`url_locale`) 둘뿐이다
(메일러·어드민은 `_ko` 컬럼을 직접 읽으므로 영향 없음).
**폴백 의미는 그대로 뒀다** — 비한국어 로케일은 영어 컬럼을 우선하고 비면 한국어로 내려간다.
바꾼 것은 *로케일의 출처*뿐이다.

### 검증 — `body_en` 을 실제로 채운 상태에서 (개발 DB, 프로덕션 미접촉)

`resume-privacy` 에 `body_en`·`title_en`·`meta_description_en` 을 임시로 채우고 실제 HTTP 로 확인 후 원복:

| URL | Accept-Language | 본문 | canonical | robots |
|---|---|---|---|---|
| `/blog/resume-privacy` | none / en / ja | **한국어** | `/blog/resume-privacy` | 없음 |
| `/en/blog/resume-privacy` | none / **ko** | **영어** | `/en/blog/resume-privacy` | 없음 |
| `/ja/blog/resume-privacy` | none | 영어 폴백 | `/blog/resume-privacy` | `noindex,follow` |

hreflang 이 ko+en 둘 다로 늘고 사이트맵도 2개로 늘었다. 원복 후 DB 에 `TEMP` 마커 0건,
사이트맵 `resume-privacy` 항목 1개로 복귀 확인.

### 회귀 검증

- `bin/rails test` → **58 runs / 278 assertions / 0 failures** (수정 전 46/190).
  신규 픽스처 3종(draft·scheduled·이중언어 발행) + 테스트 14개.
- 사이트맵 33개 전부 200·자기참조 canonical·noindex 0 / 내부 링크 103개 전부 해결.
- Accept-Language(none/en/ja/es) × 무프리픽스 8페이지 → canonical 전부 불변,
  한국어 정본 글 URL 의 robots 태그 0개 유지.
- `/blog/index.html`·`/en/blog/index.html`·`/safe`·`/safe/index.html` 301 유지.

### self-check 로 추가 정리한 것

- `Post#title/body/meta_description` 의 `loc` 인자를 **필수로** 만들었다.
  `= I18n.locale` 기본값이 바로 이 버그를 만든 함정이라, 남겨두면 다음 호출자가 조용히
  되살린다. 기본값이 없으면 빠뜨리는 순간 호출 지점에서 `ArgumentError` 가 난다.
  (전 호출처가 이미 명시적으로 넘기고 있어 안전하게 제거 가능했다 — app·lib·db·script 전수 확인)
- `Post#translated_locales` **삭제**. `indexable_locales` 로 전부 대체돼 호출자가 0이 됐는데,
  남겨두면 누군가 hreflang 에 다시 써서 미발행 글 유출을 재도입한다.
  `translated?` 는 canonical 산출에 계속 쓰이므로 남긴다 (canonical 은 발행 여부가 아니라
  번역 여부를 따라야 한다 — 미발행 한국어 글도 자기 ko 주소로 canonical 을 잡는 게 맞다).
- `application_helper.rb` 의 주석이 사라진 `translated_locales` 를 가리키고 있어 갱신.

### 남는 관찰 (수정 안 함)

- `/ja|es/blog/:slug` 는 번역이 없을 때 **영어 폴백**을 보여준다(일본어 UI + 영어 본문).
  noindex 라 SEO 영향은 없고, 폴백 우선순위를 바꾸는 건 별도 판단이라 손대지 않았다.
- 무프리픽스 URL 의 **UI 크롬은 여전히 협상**된다(`<html lang="en">` + 한국어 본문).
  이번 요구사항은 본문·제목·설명에 한정됐다. UI 까지 URL 기준으로 맞추려면
  영어권 방문자가 `/` 에서 한국어를 보게 되므로 제품 결정이 필요하다.

### 외부 교차검증 (Codex CLI, read-only)

- 패키지 `docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_amber2.md` (비밀값 0건, 라우트 전문 포함)
- 원문 `docs/review/CODEX_RESULT_2026-09-17_amber2.md` (codex-cli 0.144.3, 87초)
- 대조 `docs/review/CROSS_REVIEW_TRIAGE_2026-09-17_amber2.md` — 8건 전부 (a)/(b)/(c) 분류
- **A-1 `해소됨` · A-2 `해소됨`.** R1~R6 (유출 경로 · 필수 인자화 · `translated?` 유지 ·
  x-default 생략 · 공허한 단언 · 폴백/UI 판단) 전부 우리 판정과 일치.
- **새 (a) 2건 — 다음 런. 이번 세션에서는 고치지 않았다**:
  1. **AMBER** `/en/blog/:slug` 의 **JSON-LD `url`·`mainEntityOfPage.@id` 가 한국어 URL 로
     하드코딩**돼 canonical 과 어긋난다 (`show.html.erb:33`, `:50`).
     **재현 확인**: canonical `/en/blog/…` vs JSON-LD `/blog/…`.
     **A-2 와 트리거가 같다 — `body_en` 을 채우기 전에 고칠 것.**
  2. **GREEN** `body_en` 만 있고 `body_ko` 가 없는 published 글이 생기면 **x-default 가
     noindex URL 을 가리킨다** (레이아웃·사이트맵 양쪽). **재현 확인**: `<loc>`·alternate 는
     정확한데 x-default 만 규칙을 지나친다. 현재 이 데이터 모양을 만드는 경로는 없다
     (`Post` 가 `body_ko` 를 검증하지 않는 공백). `body_ko` 필수화 여부는 정책 결정.
- 우리가 먼저 올린 관찰을 Codex 가 확인해준 것: `<html lang>` 협상 잔존 (+`og:locale` 추가 지적).
  UI 크롬까지 URL 기준으로 맞추는 것은 제품 결정이라 (a) 로 보지 않았다.
- 직전 라운드의 패키지 결함(라우트를 `sed` 로 잘라 넣어 검토 대상 라인 누락)을 고쳐
  **전문 투입**했다 — 이번엔 "경로 요청"이 0건이었다.

## Favicon & PWA Manifest (2026-04-22)

- **Files in `public/`**: `favicon.ico`, `favicon-16x16.png`, `favicon-32x32.png`, `apple-touch-icon.png`, `android-chrome-192x192.png`, `android-chrome-512x512.png`, `site.webmanifest`
- **Manifest**: name=SlimFile, theme_color=`#0A6E8A` (teal primary), background_color=`#F8F7F4` (page bg), display=standalone
- **Layout**: `<link>` tags in `app/views/layouts/application.html.erb` head — favicon (ico + 16/32 png), apple-touch-icon (180x180), manifest
- **Source**: Generated via favicon.io
- **Commit**: `a1fd3dc feat: add full favicon set with PWA manifest`

## minitest 6 × railties 호환성 점검 (2026-09-17)

docpack 에서 나온 "테스트가 죽었는데 요약만 보면 통과처럼 보이던" 문제가 다른 곳에도 있는지
`~/Projects` 전체를 훑었다(Gemfile 에 rails 가 있는 디렉터리 기준 — 활성 8개 + `_archive` 워크트리 1개).

**판정 기준은 버전이 아니라 소스다.** railties `8.0.5` 부터 `rails/test_unit/line_filtering.rb` 에
`Minitest::VERSION` 분기가 들어갔다 — MT5 는 `run(reporter, options)`, MT6 는 `run_suite(reporter, options)`.
`8.0.4` 이하에는 2-arity `run` 하나뿐이라 minitest 6 이 `runnable.run(reporter, options, …)` 를
3인자로 부르면 `wrong number of arguments (given 3, expected 1..2)` 로 **단언 하나 돌기 전에 죽는다**.

> 비호환 = `railties < 8.0.5` **그리고** `minitest >= 6`. 둘 중 하나만으로는 안전하다.

설치된 railties 로 직접 확인: 8.0.0 / 8.0.2 / 8.0.4 → `run_suite` 없음, 8.0.5 / 8.0.5.1 / 8.1.3.1 → 있음.

**이 프로젝트**: railties `8.0.4` / minitest `5.27.0`(핀) → **이미 조치됨. 이번 점검의 대조군.**

`~/Projects` 의 Rails 프로젝트 중 **railties 가 8.0.5 미만인 것은 docpack 하나뿐**이다.
나머지 7개는 전부 8.0.5 이상이라 같은 사고가 날 수 없다. 즉 **이 문제는 docpack 고유였고,
다른 프로젝트로 번지지 않았다.** 다만 docpack 은 `rails "~> 8.0.4"` 라 핀을 풀면 다시 위험해진다 —
핀을 지우려면 그 전에 `rails` 를 8.0.5 이상으로 올려라.

**원증상 재현(격리 프로브로 실측)**: 실제 Gemfile 은 건드리지 않고 `Gemfile.mt6probe` 사본에서만
minitest 를 `~> 6.0` 으로 풀어 `BUNDLE_GEMFILE` 로 돌렸다(확인 후 프로브 파일 삭제).
railties 8.0.4 + minitest 6.0.2 조합에서:

```
railties-8.0.4/lib/rails/test_unit/line_filtering.rb:7:in `run':
wrong number of arguments (given 3, expected 1..2) (ArgumentError)
```

**기존 기록 한 줄을 정정한다.** 위에 "`0 tests` 로 조용히 통과처럼 보였다" 고 적어뒀지만,
실제 출력은 `0 runs, 0 assertions, 0 failures` 를 **찍지 않는다**. 스택 트레이스를 stderr 로 쏟고
exit code `1` 로 죽는다. stdout 만 보면 `Running 46 tests …` / `# Running:` 에서 **요약 줄 없이 끊긴다**.
"0 tests 로 통과" 가 아니라 **"요약이 아예 없음"** 이 진짜 신호다 — 조용한 쪽이 아니라 시끄러운 쪽인데,
tail 만 훑으면 아무 일도 없었던 것처럼 보이는 종류의 시끄러움이다. 참고로 정상(minitest 5)일 때는
exit code `0`. **다음에 같은 걸 찾을 때는 `0 tests` 가 아니라 `종료코드 != 0` 과 `요약 줄 부재` 를 봐라.**
