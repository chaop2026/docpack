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

## GSC 실제 URL 3건 + Codex 신규 2건 (2026-09-18)

> **직전 세션의 추정 3건은 전부 틀렸다.** (404=`/blog/index.html` 추정 → 실제 `/api/safe_scan`,
> 중복 2건=`/xx/blog` 목록 추정 → 실제 `/en/about`·`/blog/contract-checklist/`.)
> 이번에는 라이브 실측과 코드 근거 없이는 아무것도 판정하지 않았다. 프로덕션 DB 미접촉.

### A1 — JSON-LD 가 canonical 과 다른 문서를 가리키던 문제

`posts/show.html.erb` 의 `"url"` 과 `mainEntityOfPage.@id` 가 `/blog/:slug` 로 **로케일
프리픽스 없이 하드코딩**돼 있었다. **JSON-LD 전 필드 전수 확인**(`posts/show`·`layouts/application`
·`pages/faq` 3개 블록)해서 URL 을 담는 필드는 이 둘뿐임을 확인하고 `canonical_path` 로 통일했다.
(`publisher.url`·WebApplication `url` 은 사이트 루트라 로케일 무관, FAQPage 는 URL 필드 없음.)

### A2 — 검증 공백: **발행된 글은 반드시 한국어 본문을 가진다**

불변식을 먼저 정하고 `validates :body_ko, presence: true, if: -> { status == "published" }` 로 강제.
한국어가 기본 로케일이라 `/blog/:slug` 는 다른 모든 로케일이 canonical 로 삼고 x-default 가
가리키는 주소다. `body_en` 만 있는 발행 글은 그 주소를 **존재하지만 색인 불가**로 만든다.
초안·예약은 면제한다(글은 비어 있는 채로 만들어져 채워진다). 라이브 sitemap 상 42개 글이
전부 ko 로 등재돼 있으므로(= `body_ko.present?`) 기존 데이터는 위반 0건.

### A3 — `body_en` 채운 상태 실측 (개발 DB, 실제 HTTP, 원복 확인)

| URL | canonical | JSON-LD url/@id | 일치 | robots |
|---|---|---|---|---|
| `/blog/resume-privacy` (±AL=en) | `/blog/resume-privacy` | 동일 | ✅ | 없음 |
| `/en/blog/resume-privacy` (±AL=ko) | `/en/blog/resume-privacy` | 동일 | ✅ | 없음 |
| `/ja/blog/resume-privacy` | `/blog/resume-privacy` | 동일 | ✅ | `noindex,follow` |

x-default → `/blog/resume-privacy`, **robots 없음**(색인 불가 URL 아님). 원복 후 TEMP 마커 0건,
hreflang 이 `[ko, x-default]` 로 복귀.

### B1 — `/api/safe_scan` 이 발견된 경로 (실측)

사이트 전체에서 이 URL 의 **유일한 등장은 인라인 JS 문자열 리터럴 하나**다 —
`public/safe/index.html:1702` 의 `fetch('/api/safe_scan',{`. 링크(`<a href>`)·form action·
sitemap(0건)·llms.txt(0건) 어디에도 없다. **Googlebot 이 렌더링 중 JS 에서 URL 문자열을 수확한 것.**
라우트는 POST 전용이라 GET 은 404 (`POST` 는 400). GSC 최초 감지 2026-09-05 와 맞는다.

### B2 — `/api/*` 전수와 크롤 차단 방식

`bin/rails routes` 전수: **`POST /api/safe_scan` 하나뿐**. `robots.txt` 에 `/api` Disallow **없었다**.
→ `Disallow: /api/` 추가. **X-Robots-Tag 가 아니라 robots.txt 를 쓴 이유**: noindex 헤더는
**가져와야** 적용되는데 그 크롤이 바로 막으려는 것이고, GET 이 404 라 헤더를 붙일 응답 자체가 없다.

### B3/B4 — 트레일링 슬래시: **라우터** 문제 (정적 아님)

판별 근거: `/about/` 응답에 CSRF 메타 태그가 있다(=레이아웃 렌더=라우터). `public/` 의
디렉터리는 `safe`·`privacy` **둘뿐**이라 `ActionDispatch::Static` 이 `/about/` 을 잡을 수 없다.
Rails 라우터가 트레일링 슬래시를 없는 것처럼 매칭한다.

**실측 규모**(리다이렉트 미추적): 글 URL **168/168**(42글×4로케일) + 그 외 **32경로**가
슬래시 유무 양쪽 다 진짜 200. `/sitemap.xml/` 까지.

`lib/static_index_redirect.rb` → **`lib/canonical_path_redirect.rb`** 로 이름을 바꾸고 확장했다.
두 규칙이 **반대 방향**이라 한 미들웨어가 둘 다 갖는다:
- 정적 디렉터리(`/safe`·`/privacy`)는 **슬래시가 붙은 쪽**이 정본
- 라우팅된 페이지는 **슬래시가 없는 쪽**이 정본 (`/+\z` 로 여러 개도 한 홉에 정리)

곁들여: `OLD_BLOG_SLUGS` 리다이렉트 대상에서 트레일링 슬래시 제거(안 하면 301→301→301),
`public/safe/index.html`·`app/views/pages/home.html.erb` 의 `/blog/` 링크를 `/blog` 로.

**`/blog/contract-checklist/` 는 2홉이다** — 미들웨어가 철자를 정규화하고(1홉) 라우터가 이동을
해결한다(2홉). 슬러그 표를 미들웨어로 끌어오면 1홉이 되지만 `routes.rb` 가 죽은 코드가 된다
(`/safe` 가 당한 그 함정). 2개의 301 이 더 싸다. 루프·3홉 이상 없음을 테스트로 고정.

### B5 — `/en/about`: 게이트가 정적 페이지에 없던 것이 맞다, 다만 원인은 다르다

**전제를 실측으로 검증했다.** `/faq`·`/compress`·`/` 는 **진짜 번역돼 있다**
(한국어판 대비 유사도 0.28~0.38, 한글 비율 44~47% vs 번역본 0%).
**`/about` 만 4개 로케일이 92~94% 동일**하고, 한국어판조차 한글 비율 **5%** 다.

원인: `app/views/pages/about.html.erb` 는 **`t()` 호출이 하나도 없는 하드코딩 영어**이고
`config/locales` 에 `about.*` 키가 없다. 즉 미번역이 아니라 **번역 대상이 아닌 단일 문서**다.

→ 블로그 글과 같은 규칙 적용: `/xx/about` 은 `noindex,follow` + canonical `/about`,
sitemap 은 `/about` 하나만, **hreflang 은 0개**(영어 단일 문서가 자기를 한국어·일본어
알터네이트라고 선언하면 거짓이고, x-default 도 마찬가지). `page_meta` 도 없었어서 함께 추가했다.
**`/faq`·`/compress`·`/pdf`·`/social` 은 그대로 4개 로케일 유지** — 진짜 번역이기 때문이다.

### 검증

- `bin/rails test` → **87 runs / 502 assertions / 0 failures** (직전 58/278).
  신규 `test/models/post_test.rb`(8) + `test/integration/canonical_urls_test.rb`(13) +
  미들웨어 테스트 확장 + JSON-LD 테스트.
- 트레일링 슬래시 66경로 재측정 → **중복 200: 0개**. `/safe/`·`/privacy/`·`/` 는 유지,
  `/about///` 도 한 홉.
- sitemap 30개 전부 200·자기참조 canonical·noindex 0·리다이렉트 0.
- 내부 링크 102개 → 깨짐 0, **리다이렉트 0**.
- Accept-Language(en/ja/es) × 10페이지 canonical 불변 PASS.
- ⚠️ **이니셜라이저는 dev 에서 자동 리로드되지 않는다** — 미들웨어를 추가·이름변경한 뒤
  `docker compose restart web` 하기 전까지 측정값이 전부 "수정 전"이었다. 재시작 후 재측정했다.

### 남는 관찰 (수정 안 함)

- `config/locales/ko.yml` 에 `activerecord.errors` 블록이 없어, 검증 실패 메시지가
  `Translation missing…` 으로 나온다. 어드민 폼에서 사람이 보게 되는 문자열이다. 별건.
- `<html lang>`·`og:locale`·UI 크롬은 여전히 협상된다(직전 세션의 관찰 그대로). 제품 결정.

### 외부 교차검증 (Codex CLI, read-only)

- 패키지 `docs/review/CODEX_REVIEW_PACKAGE_2026-09-18_gsc3.md` (비밀값 0건, 라우트 전문)
- 원문 `docs/review/CODEX_RESULT_2026-09-18_gsc3.md` (codex-cli 0.144.3, 113초)
- 대조 `docs/review/CROSS_REVIEW_TRIAGE_2026-09-18_gsc3.md` — 9건 전부 (a)/(b)/(c) 분류
- **N-1 `해소됨` · N-2 `해소됨` · B-404 `적절` · B-중복 `적절`.** (b) 의견 차이 0건.
  Codex 가 독립 확인해준 것: 2홉 수용 근거, robots.txt 선택, `/about` 의 hreflang 0개 판단,
  JSON-LD URL 필드가 2개뿐이라는 전수 확인.
- **새 (a) 3건 — 다음 런. 이번 세션에서는 고치지 않았다**:
  1. **AMBER** `PublishScheduledPostsJob` 이 `update!` 를 rescue 없이 `find_each` 안에서
     호출한다. **이번에 추가한 `body_ko` 검증에 걸리면 그 배치의 나머지 글이 전부 발행되지
     않는다.** 검증 전에는 본문 없는 글이 발행돼 버렸고(잘못이지만 배치는 계속), 이제는
     발행을 막되 뒤따르는 글까지 막는다 — **이번 커밋이 만든 트레이드오프다.**
     촉발 조건(`body_ko` 없는 `scheduled` 글)이 있는지는 프로덕션 DB 를 안 보므로 알 수 없다.
     → 글 단위 `rescue` + 로그. **배포 전 처리 권장.**
  2. **GREEN** 정적 디렉터리 밑 **반복 슬래시**가 미들웨어를 빠져나간다. **재현 확인**(md5 동일):
     `/safe//`·`/safe///`·`/privacy//`·`/safe//index.html`·`/safe//sw.js` 전부 200.
     `start_with?("#{dir}/")` 가 이들을 "에셋" 으로 보고 통과시킨다.
     → `squeeze("/")` 를 디렉터리 분기보다 **앞**에 둔다.
  3. **GREEN** 미들웨어 삽입이 `public_file_server.enabled` 에 묶여 있다. **프로덕션 스택을
     실제로 뽑아 확인한 결과 현재는 들어간다**(변수 유무 무관). 다만 가드의 근거가 낡았다 —
     이제 Static 과 무관한 라우팅 페이지도 고치므로, 정적 서빙을 프록시로 옮기면 정본 URL
     정규화가 아무 신호 없이 사라진다. → 가드 제거.
- **이번 패키지의 빈틈**: 잡·서비스 계층을 넣지 않았다. Codex 의 유일한 "경로 요청"이
  `PublishScheduledPostsJob` 이었고 그것이 위 1번을 끌어냈다. 다음 패키지엔 포함한다.

## 교차검증 (a) 3건 수정 (2026-09-18)

`docs/review/CROSS_REVIEW_TRIAGE_2026-09-18_gsc3.md` 의 (a) 3건. 프로덕션 DB 미접촉, 미배포.
전부 **수정 전에 먼저 재현**하고 **수정 후 다시 측정**했다.

### A-1 (AMBER) — 한 글의 검증 실패가 배치 전체의 발행을 막던 문제

**직전 커밋이 만든 트레이드오프다.** `validates :body_ko, if: published` 를 넣기 전에는 본문
없는 글이 *발행돼 버렸고*(잘못이지만 배치는 계속됐다), 넣은 뒤에는 `find_each` 안의 rescue 없는
`update!` 가 `RecordInvalid` 를 던져 **그 뒤의 글이 전부 발행되지 않는다.** 정확성은 올랐고
가용성은 내려갔는데 그 교환을 인지하지 못한 채 바꿨다.

**먼저 정한 것 — 어떤 실패를 어떻게 드러내는가** (구현보다 이 표가 먼저다):

| 실패 | 격리 | 드러내는 방법 | 왜 |
|---|---|---|---|
| `update!` 가 레코드를 거부 (`RecordInvalid`·`RecordNotSaved`) | 그 글만 건너뛰고 배치 계속 | 글마다 `logger.error` **+ 런 끝에 관리자 메일 1통** | 이 수정의 **새 실패 모드가 "그 글이 영구히 미발행"** 이다. 로그만 두면 그 "영구히" 를 아무도 모른다 |
| 알림 메일 enqueue 실패 | 메일만 포기, **발행은 되돌리지 않음** | `logger.error` | 글은 이미 공개됐다. 알림을 정직하게 만들려고 발행을 롤백하면 공개된 페이지를 숨기는 것이 된다 |
| 그 외 전부 (DB 연결 끊김 등) | **격리하지 않음 — 그대로 전파** | 잡이 실패하고 Solid Queue 가 재시도 | 삼키면 모든 글이 "검증 실패" 로 보고되고 잡은 **성공으로 종료** 된다 — 발행해줄 재시도를 버리는 셈 |
| 실패 보고 메일 자체의 실패 | rescue (메일 호출만 좁게) | `logger.error` | 알림의 알림은 없다. 이미 발행한 것까지 잃을 수는 없다 |

**메일이 핵심이다.** 실패 1건이든 10건이든 **런당 1통** — 시스템적 문제가 메일 폭탄이 되면
안 된다. 잡은 매일 09:00 KST 에 돌므로 **고쳐지기 전까지 매일 한 통**이 온다. 그 잔소리가
안전망이다. 메일은 슬러그·검증 메시지·`/admin/posts/:id/edit` 링크를 담는다
(`BlogMailer#publish_failed` + `app/views/blog_mailer/publish_failed.html.erb`, 신규).

`RECORD_REJECTED` 를 두 예외로 **좁게** 잡은 것이 설계의 나머지 절반이다 — 넓게 잡으면
인프라 장애가 "글 문제" 로 오분류되고 잡이 성공으로 끝난다.

### A-1 부수: 알림이 한국어로 말하지 못하던 문제 (같은 수정의 일부)

첫 테스트가 바로 드러냈다 — `config/locales/ko.yml` 에 `activerecord.errors` 블록이 **없고**
ko 가 기본 로케일이라, 검증 실패가 자기 조회 흔적을 그대로 출력했다:

```
RecordInvalid#message → "Translation missing: ko.activerecord.errors.messages.record_invalid"
errors.full_messages  → "Body ko Translation missing. Options considered were: …"
```

**이유 칸에 "Translation missing" 이 찍히는 알림은 동작하지 않는 알림이다.** 그래서 이건
장식이 아니라 A-1 의 일부다. 이 문자열을 사람이 읽는 곳은 두 군데 —
어드민 폼(`admin/posts/_form`·`admin/banners/_form` 이 `errors.full_messages` 를 출력)과
이번에 추가한 발행 실패 메일.

이 앱이 실제로 쓰는 검증자 3종(presence·uniqueness·inclusion) + `record_invalid` 래퍼 +
Post·Banner 속성명으로 **범위를 좁혀** 넣었다. `errors.format` 은 공백 없는
`"%{attribute}%{message}"` — 한국어 조사는 명사에 붙으므로 기본 포맷은 단어 중간에 공백을 만든다.
`rails-i18n` 젬은 없다(넣으면 이 블록은 대체된다). **`en.yml` 은 건드리지 않았다** —
Rails 기본 en 이 이미 "Body ko can't be blank" 를 준다(확인함).

| | 수정 전 | 수정 후 |
|---|---|---|
| `RecordInvalid#message` | `Translation missing: ko.activerecord.errors.messages.record_invalid` | `저장할 수 없습니다: 본문(한국어)을(를) 입력해 주세요` |
| `full_messages` | `Body ko Translation missing. Options considered were: …` | `본문(한국어)을(를) 입력해 주세요` |

### A-1 전수 확인 — "rescue 없는 bang 메서드가 순회 안에" 5건

`app`·`lib`·`db`·`script` 전체를 스캔(들여쓰기로 감싸는 블록을 추적하는 스크립트 + 수동 확인):

| # | 위치 | 판정 | 조치 |
|---|---|---|---|
| 1 | `app/jobs/publish_scheduled_posts_job.rb:6` | **무인 실행·실패 비가시** | 위 A-1 |
| 2 | `lib/tasks/blog.rake:34` `Post.create!` in `count.times` | 루프가 이미 생성 실패에 `next` 한다 — 의도가 이미 "건너뛰고 계속" | 글 단위 rescue 추가 |
| 3 | `lib/tasks/blog.rake:176` `post.update!` in `each_with_index` | 동일 | 동일 |
| 4 | `lib/tasks/blog_migrate_privacy.rake:43` `post.save!` in `each` | 동일 (+ 멱등 태스크) | 항목 단위 rescue + **끝에 `abort`** |
| 5 | `db/seeds/safefile_posts.rb:40` `post.save!` in `each` | **이번 스캔이 새로 찾은 것 — 실제로 깨져 있었다** | 아래 별항 |

2·3 에 `abort` 를 넣지 않은 이유: 사람이 터미널에서 돌리는 생성 태스크이고 이미
`puts "FAILED — skipping"` + exit 0 가 기존 관례다. 4·5 는 `kamal app exec` 로 돌리는
**데이터 정리** 태스크라 exit code 가 자동화에 읽힌다 — 그래서 모든 항목에 기회를 준
**다음** 실패한다.

> 📌 **정정 (같은 세션의 교차검증에서 잡음)**: 처음 이 문단에 "4·5 는 CLAUDE.md 의
> Post-deploy commands 목록에 있다" 고 적었는데 **사실이 아니다.** 그 목록(위 "Blog
> Automation Verification" 절)에는 `blog:seed_topics`·`blog:publish_test`·
> `blog:verify_autopublish` 셋뿐이다. `blog:migrate_privacy` 는 **자기 파일 헤더 주석**에
> `kamal app exec 'bin/rails blog:migrate_privacy'` 를 적어두고 있고,
> `blog:seed_safefile_posts` 는 **어디에도 배포 후 단계로 문서화돼 있지 않다.**
> `abort` 결정은 유지한다(둘 다 프로덕션에서 손으로 돌리는 데이터 태스크이고 하나는 스스로
> 그렇게 문서화한다) — 정정한 것은 **인용한 근거**다.

**격리하지 않은 것** (순회 안이 아니므로 예외가 올바른 결과):
`auto_generate_blog_post_job`(런당 글 1개, 뒤에 아무것도 없음 — 예외 → 재시도가 맞다),
`app/controllers/**`(요청 스코프, 예외 = 500 = 즉시 보임; `banners#swap_order` 는 트랜잭션 안
2개 업데이트라 둘 다 성공해야 한다), `Post#publish!`.

부수 확인: `posts_controller.rb:11` 의 `increment!(:view_count)` 는 **검증을 우회**한다
(`update_counters` = 직접 SQL). 실측함 — 본문 없는 글의 공개 페이지가 500 이 되지 않는다.

### A-1 별항 — `blog:seed_safefile_posts` 는 직전 커밋으로 실제로 깨져 있었다

**실측**: `rake blog:seed_safefile_posts` → 두 번째 항목에서
`ActiveRecord::RecordInvalid` 로 **중단**, 세 번째는 시도조차 못 한다.

원인은 두 겹이고 둘 다 이 시드보다 나중에 생겼다:
1. 시드의 원래 전제는 주석에 있던 "본문은 `public/blog/<slug>/index.html` 이 담당한다" 였다 —
   그래서 **본문 없는 published 레코드**를 만드는 게 의도였다. `9f8bfff`(2026-07-17) 가
   `public/blog/` 를 삭제하고 `blog:migrate_privacy` 가 본문을 DB 로 옮기며 슬러그를
   **개명**했다(`rrn-masking`→`resident-number-masking`,
   `contract-checklist`→`contract-sharing-checklist`). 시드는 개명 **전** 슬러그를 쓰므로
   마이그레이션이 끝난 DB 에서는 기존 글을 못 찾고 **중복 글을 새로 만들려 한다**.
2. 2026-09-18 의 검증이 그 생성을 거부한다.

**즉 검증이 이 시드의 버그를 잡아준 것이다** — 검증 전에는 본문 없는 published 중복 2개를
조용히 만들어 `/blog` 목록과 사이트맵을 오염시켰다. 확인: 수정 후 재실행해도 DB 에 중복 0건.

조치는 **패턴 수정까지만** 했다 — 항목 단위 rescue + 이유를 밝히는 경고 + 전 항목 처리 후
`abort`(exit 1). **이 파일을 어떻게 정리할지(마이그레이션에 합치기 / 본문을
`db/blog_privacy/` 에서 읽게 하기 / 삭제)는 별도 결정이라 손대지 않았다.** 관련 관찰:
마이그레이션 후에 시드를 돌리면 기존 글의 `category` 를 `privacy`→`student` 로 되돌려
두 태스크가 서로 싸운다(실행 로그로 확인).

### A-2 (GREEN) — 반복 슬래시가 미들웨어를 빠져나가던 문제 (**지적보다 넓었다**)

교차검증은 트레일링 반복(`/safe//`, `/safe//index.html`, `/safe//sw.js`, `/privacy//`) 을
지적했다. 재현하면서 **두 가족을 더 찾았다**:

| 새로 찾은 것 | 실측 |
|---|---|
| `/safe/sw.js/` — 정적 디렉터리 **밑 에셋의 트레일링 슬래시** | 200, `/safe/sw.js` 와 8979 바이트 동일. 옛 코드의 "정적 디렉터리 밑은 절대 손대지 않는다" 분기가 통과시켰다 |
| **경로 중간** 반복 슬래시 — `//about`·`/en//about`·`/en///about`·`//en/about`·`//faq`·`//blog`·`//sitemap.xml`·`//robots.txt`·`/blog//:slug`·`/en//blog//:slug` | 전부 진짜 200. CSRF 토큰만 빼면 정본과 **바이트 동일**(`/en//about` 대조 확인). 라우터가 반복 슬래시를 없는 것처럼 매칭한다 |

**트레일링 슬래시를 얼마나 벗겨도 경로 중간은 못 잡는다** — 지적된 `squeeze` 위치 조정이
아니라 **순서 자체**를 바꿔야 했다.

**수정** (`lib/canonical_path_redirect.rb`): `canonical_target` 을 얇게 두고
`canonical_spelling(path)` 를 신설 — **① 정규화(`squeeze("/")` + 트레일링 `/+` 제거) → ②
그 결과를 정본 주소로 매핑** 의 두 단계. 이 **순서**가 핵심이다:

- 정규화를 먼저 하면 `DIRS` 분기에서 "밑의 에셋은 통과" 라는 특례가 **필요 없어진다**
  (코드가 줄었다). `/safe/` 의 슬래시는 `/safe` → `/safe/` 매핑이 되살린다.
- **1홉이 보장된다.** `/safe//index.html/` 이 301 두 번이 아니라 곧바로 `/safe/` 로 간다.
- 이 메서드가 돌려줄 수 있는 모든 값이 **자기 자신의 고정점**이다 — 그래서 체인도 루프도
  구조적으로 불가능하다. 논증에 기대지 않고 두 가지로 고정했다:
  ① 미들웨어가 내보낸 Location 을 **다시 자기에게 먹여** 200 인지 확인(40경로),
  ② `canonical_spelling` 의 **멱등성**을 순수 함수 수준에서 단언.

### A-3 (GREEN) — 미들웨어가 `public_file_server.enabled` 에 묶여 있던 문제

가드는 **정적 디렉터리만 다룰 때는 옳았다** — Static 이 없으면 할 일도 없었다. 2026-09-18 에
라우팅 페이지(`/about/`·`/blog/:slug/`·`/sitemap.xml/`) 정규화를 맡은 순간부터 틀렸다.

**추정하지 않고 실측했다** — 프로덕션 환경으로 스택을 뽑았다:

| 구성 | 수정 전 | 수정 후 |
|---|---|---|
| `RAILS_SERVE_STATIC_FILES=true` (실제 배포 형태) | `CanonicalPathRedirect` 1개 | 1개 (Static 바로 앞) |
| 변수 미설정 (Rails 8 기본 참) | 1개 | 1개 (Static 바로 앞) |
| **`public_file_server.enabled = false`** (프록시가 public/ 서빙) | **0개** | **1개 (스택 최상단)** |

0개였다 — public/ 을 nginx 뒤로 옮기면 **사이트 전체 정본 URL 정규화가 에러도 로그도 없이
사라진다.** 이 저장소가 반복해 당한 조용한 실패 모양 그대로다.

**수정**: 가드를 없애지 않고 **역할을 바꿨다** — 이제 삽입 **위치**만 고른다.
Static 이 있으면 `insert_before`(반드시 앞이어야 한다 — 파일 핸들러가 `/safe` 를 먼저 답한다),
없으면 `unshift`. 무조건 `insert_before` 는 `"No such middleware to insert before"` 로
**부팅을 깨뜨린다** — 배포 구성 변경이 크래시가 된다. `unshift` 는 `ActionDispatch::SSL` 보다
위에 놓이는데, 홉 수는 양쪽 다 2(스킴·철자 순서만 바뀜)이고 Location 이 경로만 담으므로
SSL 이 자기 차례를 잃지 않는다.

`static_html_no_cache.rb` 의 가드는 **같은 실수가 아니라서 그대로 뒀다** — 그 미들웨어는
Static 이 내보내는 캐시 헤더를 고쳐쓰는 것이 존재 이유라, Static 이 없으면 진짜로 할 일이 없다.
두 초기화 파일 주석에 이 구분을 적었다.

### 검증

| 검증 | 결과 |
|---|---|
| `bin/rails test` | **109 runs / 793 assertions / 0 failures** (직전 87/502) |
| 신규 `test/jobs/publish_scheduled_posts_job_test.rb` | 14개 / 80 단언 |
| 확장 `test/lib/canonical_path_redirect_test.rb` | 25개 / 208 단언 (직전 17개) |
| 확장 `test/integration/canonical_urls_test.rb` | 14개 / 232 단언 |
| **반복 슬래시 회귀 테스트가 수정 전 코드를 잡는가** | **22/25 단언 실패** (root 3건은 원래도 동작) |
| **잡 테스트가 수정 전 잡을 잡는가** | **9/14 테스트 실패** (나머지 5건은 원래 맞던 동작) |
| 로컬 경로 스윕 137개 (리다이렉트 미추적) | **중복 200: 0개**, 루프 0, 3홉 이상 0. 홉 분포 `{1: 89, 2: 1}` |
| 그 2홉 1건 | `/blog/contract-checklist/` → `/blog/contract-checklist` → `/blog/contract-sharing-checklist` — 철자(미들웨어) + 이동(라우터). DECISIONS.md 2026-09-18 에서 수용한 그 건 |
| 사이트맵 30개 | 전부 200 · 자기참조 canonical · noindex 0 · 리다이렉트 0 |
| 내부 링크 64개 (로컬 DB 는 글 3개 — 라이브 42개 기준 102개와 다르다) | 깨짐 0 · 리다이렉트 0 |
| Accept-Language(none/en/ja/es/ko) × 무프리픽스 8페이지 | canonical·robots 전부 불변 |
| **SW 프리캐시 URL 11개가 직접 200 인가** | 전부 200 — 새 301 이 프리캐시 경로에 끼어들지 않았다. (끼어들면 `r.redirected` 를 실패로 올리는 `precache()` 가 install 을 실패시켜 SW 업데이트가 멈춘다) |
| SW 네트워크 실패 주입 (`test/sw/offline_resilience.mjs`) | **9/9 통과** — 회귀 없음 |
| 프로덕션 미들웨어 스택 3형태 | 위 A-3 표 |
| rubocop (변경 파일 10개) | 신규 위반 0 (남은 12건은 HEAD 사본에 rubocop 을 돌려 **전부 기존 것**임을 확인) |
| 프로덕션 DB | **미접촉** |

⚠️ **이니셜라이저·`lib/` 는 dev 에서 리로드되지 않는다** (직전 세션이 이미 당한 것).
미들웨어를 바꾼 뒤 `docker compose restart web` 하기 전 측정은 전부 "수정 전" 값이다.
이번에도 매 측정 전에 재시작했고, 회귀 테스트를 위해 옛 파일을 넣었다 뺄 때도 재시작했다.

### self-check 로 추가 정리한 것

- `report` 의 rescue 범위를 **메일 호출만**으로 좁혔다. 처음에는 메서드 전체를 감싸서
  요약 로그까지 rescue 안에 있었다 — 로거가 실패하면 rescue 안에서 또 로거를 부르는 모양이라
  의도가 흐렸다. 무엇이 "없어도 되는 것" 인지가 코드에서 보여야 한다.
- `publish` 의 `begin/rescue/else` 를 평범한 `begin/rescue` + 조기 `return false` 로 바꿨다.
  메서드 레벨 `else` 의 반환값 규칙은 맞게 동작하지만 읽는 사람이 한 번 멈춘다.
- `describe_failure` 가 **문자열·정수만** 담는다. Post 나 예외 객체를 담으면 `deliver_later`
  직렬화가 **프로덕션에서만** 터진다(잡 테스트는 초록으로 끝난다). 그래서 테스트가
  `perform_enqueued_jobs` 까지 돌려 메일이 실제로 렌더·발송되는 것을 본다.
- 잡 테스트의 로그 캡처에 **severity 를 포함하는 formatter** 를 붙였다. 기본 formatter 는
  메시지만 쓰므로 `/ERROR.*/` 단언이 어떤 레벨에도 통과하는 **공허한 단언**이 된다.
- 반복 슬래시 통합 테스트가 공허하지 않은지 확인했다 — 옛 미들웨어로 돌리면 실패한다.
  즉 `ActionDispatch::IntegrationTest` 는 `//` 를 정규화하지 않고 그대로 넘긴다.
- 미들웨어가 스택에 **실제로 꽂혀 있는지**를 단언하는 테스트를 추가했다(Static 앞 위치까지).
  이 파일의 나머지 단언 전부가 그 전제에 기대고 있다. Static 이 없는 분기는 스택이 부팅 때
  한 번만 만들어져 in-process 로 못 재현하므로, 위 A-3 실측이 담당한다고 주석에 적었다.

### 남는 관찰 (수정 안 함)

- `blog:seed_safefile_posts` 의 존재 이유 정리 (위 별항) — 어느 태스크가 이 3개 글을
  소유하는지 결정해야 한다.
- `auto_generate_blog_post_job` 에서 `topic.update!(used: true)` 가 실패하면 주제가 unused 로
  남아 다음 런에 다시 뽑힌다(슬러그 유일성 때문에 `-1` 접미 글이 생긴다). 순회 안이 아니라
  이번 패턴은 아니다. 또한 `Post.create!` 실패 시 재시도가 **API 비용을 다시 쓴다**.
- Banner·BlogTopic·Conversion 의 속성명은 ko 번역이 없어 여전히 영어 humanize 로 나온다
  (메시지 본문은 이제 한국어). 어드민 폼이 있는 Post·Banner 만 넣었다.
- `<html lang>`·`og:locale`·UI 크롬은 여전히 협상된다 (이전 세션들의 관찰 그대로). 제품 결정.

### 외부 교차검증 (Codex CLI, read-only)

- 패키지 `docs/review/CODEX_REVIEW_PACKAGE_2026-09-18_amber3.md` (비밀값 0건,
  **잡·메일러·레이크·시드·SW·라우트 전문 포함** — 직전 라운드의 빈틈을 고쳤다)
- 원문 `docs/review/CODEX_RESULT_2026-09-18_amber3.md` (codex-cli 0.144.3, `gpt-5.5`, 96초)
- 대조 `docs/review/CROSS_REVIEW_TRIAGE_2026-09-18_amber3.md` — 12건 전부 (a)/(b)/(c) 분류
- **A-2 `해소됨` · A-3 `해소됨` · A-1 `부분 해소`.** (b) 의견 차이 0건.
- ⚠️ **새 (a) 2건 — 다음 런. 이번 세션에서는 고치지 않았다.** 둘 다 우리가 패키지 ⑥ 에
  "확신 없음" 으로 올린 항목이고, **둘 다 Codex 판단이 옳다**:
  1. **AMBER** 발행 실패 알림이 **메일 전달 성공에 의존**한다. `report` 는 `deliver_later`
     **호출만** rescue 하므로, 이후 메일 잡의 렌더·SMTP 실패는 rescue 밖이다. 코드로 확인:
     `ApplicationJob` 의 `retry_on`·`discard_on` 은 **주석 처리된 스캐폴드 그대로**이고
     `rescue_from`·`failed_executions` 처리가 **0건**이라, 실패한 메일은 아무도 보지 않는
     `solid_queue_failed_executions` 행이 된다. **가정이 아니다 — SMTP 실패 선례가 있다**
     (CLAUDE.md:145, 2026-04-07 `GMAIL_PASSWORD` 빈 값 → `535-5.7.8`).
     → 메일과 **무관한 채널**을 둔다. `scheduled` 인데 `published_at` 이 한참 과거인 글을
     **상태로** 노출하는 쪽이 가장 튼튼하다 — 알림은 유실되지만 상태는 유실되지 않는다.
  2. **AMBER (프로덕션 데이터)** 대체된 `db/seeds/safefile_posts.rb` 가 **마이그레이션
     결과를 되돌린다.** **실측**: `privacy` → `student` (그리고 `title_*`·
     `meta_description_*` 까지 시드의 하드코딩 값으로 덮는다 — 사람이 어드민에서 편집한
     내용도 사라진다). 그 쓰기는 `abort` **전에** 일어난다. 우리는 이걸 관찰했으나 "남는
     관찰" 로 내려놨다 — **Codex 의 등급이 더 정확하다.** → 소유권 결정 후 삭제 또는 재작성.
     **프로덕션에서 이 시드를 돌리기 전에 처리할 것** (배포 자체를 막지는 않는다).
- Codex 의 "경로 요청" 3건을 **전부 받아서 확인했고 답이 바뀌지 않았다**:
  ① 모델 콜백/락 → `Post` 에 `before_save`·`around_save` **0개**, `lock_version` **없음**
  (→ `RecordNotSaved`·`StaleObjectError` 는 현재 발생 불가; `slug` 유니크 인덱스는 있으나
  `update!(status:)` 가 `slug` 를 안 건드리므로 `RecordNotUnique` 도 불가)
  ② `%2F` 통합 테스트 → percent-encoded 슬래시는 중복 콘텐츠 위험이 아니다(디코딩되면
  `squeeze` 가 처리하고, 안 되면 정규화 대상이 아니다)
  ③ 프로덕션 SSL/프록시 설정 → **`ActionDispatch::HostAuthorization` 은 프로덕션 스택에
  아예 없다**(`config.hosts` 가 `production.rb:85` 에서 주석 처리). SSL 앞 배치를 안전하게
  만드는 성질(Location 이 path-only, Host 를 읽지도 반사하지도 않음)을 self-check 에서
  **테스트로 고정했다**(`HTTP_HOST: evil.example.com` 주입).
- Codex 가 독립 확인해준 것: `RECORD_REJECTED` 경계, ActiveJob 직렬화 안전성,
  `canonical_spelling` **반례 없음**, `/safe/sw.js/` 301 의 SW 무해성, ko.yml 키 충돌 없음,
  공허한 단언 없음(formatter·스텁·통합테스트 세 지점 모두).
- 이번 라운드의 방법론 성과: **"확신이 없는 지점" 7개를 패키지에 명시한 것이 실제로
  작동했다** — 그중 2개가 (a) 로 확정됐고, 둘 다 우리 스스로는 (a) 로 올리지 못한 것이다.
- **운영 메모**: `codex exec` 는 `< /dev/null` 이 필요하다. 첫 시도가
  `Reading additional input from stdin...` 에서 10분간 아무 일도 하지 않고 멈췄다.

## 교차검증 새 AMBER 2건 수정 (2026-09-18)

`docs/review/CROSS_REVIEW_TRIAGE_2026-09-18_amber3.md` 의 (a) 2건. 프로덕션 DB 미접촉, 미배포.
**이번 라운드는 문서에 적는 모든 인용을 실제 파일에서 다시 확인했다** — 직전 라운드에서
자기 커밋 rationale 의 사실 오류가 리뷰에 잡혔기 때문이다.

### B-1 (AMBER) — 알림이 메일 발송 성공에 의존하던 문제

직전 수정은 건너뛴 글을 **메일로만** 알렸다. 그게 부족하다는 지적이 옳았고, 근거는 가설이
아니라 이 앱의 이력이다:

| 확인한 사실 | 근거 (재확인함) |
|---|---|
| Solid Queue 는 **스스로 재시도하지 않는다** | `ClaimedExecution#perform` 이 실패 시 `failed_with(result.error)` 후 즉시 re-raise (`solid_queue-1.4.0/app/models/solid_queue/claimed_execution.rb:65-73`). `FailedExecution#retry` 는 **수동 호출 전용** (`failed_execution.rb:21-29`) |
| 재시도 정책이 **아예 없었다** | `ApplicationJob` 의 `retry_on`·`discard_on` 이 **주석 처리된 스캐폴드**였고 `rescue_handlers == []` (런타임 실측). 즉 예외를 던진 잡은 재시도 0회로 `solid_queue_failed_executions` 로 직행 |
| 그 테이블을 **아무도 읽지 않았다** | `app/`·`config/`·`lib/` 전체에 `rescue_from`·`failed_executions` 처리 0건 |
| 프로덕션 큐 | `config.active_job.queue_adapter = :solid_queue` (`config/environments/production.rb:53`) |
| **SMTP 실패 선례** | CLAUDE.md:145 — 2026-04-07 `GMAIL_PASSWORD` 빈 값 → `SMTPAuthenticationError 535-5.7.8` |

#### 먼저 정한 것 — 어떤 상태를, 어디에, 어떻게 기록하고, 관리자는 어디서 보는가

**상태 정의**: `Post.publish_stuck` = `status == "scheduled"` **이면서** 예약 시각이 지난 글.

**핵심 설계 결정: 권위 있는 신호는 파생(derived)이다** — 잡이 쓰는 플래그가 아니다.
닫으려는 실패가 "보고해야 할 메커니즘 자체가 죽었다" 이므로, 신호가 그 메커니즘에 의존하면
안 된다. 파생 스코프는 **글 행 외에 아무것에도 의존하지 않으므로** 플래그보다 엄격히 많이 잡는다:

| 실패 | 잡이 쓰는 플래그 | 파생 스코프 |
|---|---|---|
| 검증이 글을 거부 | ✓ | ✓ |
| **잡이 아예 안 돌았다** (2026-04-07 `SOLID_QUEUE_IN_PUMA=false` 로 실제 발생) | ✗ | ✓ |
| 잡이 그 글에 닿기 전에 죽었다 | ✗ | ✓ |

**두 가지 인내심** (테스트가 끌어낸 설계 수정):
- **이유가 기록된 경우**(`publish_error` 있음) → 증거이므로 **예약 시각이 지나는 즉시** 집계.
- **아무것도 기록되지 않은 경우** → 다음 런을 기다리는 중일 수 있다. 잡은 하루 한 번(09:00 KST)
  도니 09:30 예약 글은 정당하게 약 23.5시간 기다린다 → **26시간(`PUBLISH_GRACE`) 유예**.

  처음에는 26시간 단일 규칙이었는데, 테스트가 **잡이 이미 거부한 글이 하루 동안 안 보이는**
  것을 드러냈다. 그 하루가 바로 이 장치가 없애려는 지연이다.

**이유의 기록 위치**: `posts.publish_error` (text, nullable, 신규 마이그레이션).
잡이 `update_column` 으로 쓴다 — 검증을 **의도적으로** 우회한다(레코드가 유효하지 않은 것이
바로 쓰는 이유다). 발행 성공 시 지운다. **이유가 없어도 글은 목록에 뜬다**("이유 미기록").

**관리자가 보는 곳 — 서로 독립인 3곳 + 보조 1곳**:

| # | 어디 | 무엇에 의존하는가 |
|---|---|---|
| 1 | `/admin/posts` 상단 **빨간 배너** (모든 필터에서 표시) | DB 만 |
| 2 | **`Stuck (n)` 필터 칩** | DB 만 |
| 3 | **`rake blog:stuck`** — 막힌 글이 있으면 **exit 1** | DB 만. 브라우저·어드민 비밀번호 불필요 → `kamal app exec` 로 확인 가능, 나중에 모니터에 붙일 수 있다 |
| 4 | 메일 (`BlogMailer#publish_failed`) | SMTP + 큐 — **보조로 남겼다** |

**`/up` 은 쓰지 않았다**: Kamal 배포 헬스체크 경로다(`config/deploy.yml` 에 `healthcheck.path`
가 없어 kamal-proxy 기본값을 쓴다 — `kamal-2.11.0/lib/kamal/configuration/proxy.rb:80` 이
`proxy_config.dig("healthcheck","path")` 를 그대로 넘긴다). 막힌 글로 `/up` 이 실패하면
**배포가 막힌다.** 애플리케이션 데이터에 배포 게이트를 묶지 않는다.

#### 재시도 정책 — 이 앱의 실제 잡 구성에 맞춰 정리

**실패한 잡이 보이는 곳**: `rake jobs:failed` (신규) 가 `solid_queue_failed_executions` 를
읽어 잡 클래스·예외·메시지·수동 재시도 방법을 출력하고, 있으면 exit 1.
dev 에서는 큐 DB 가 없으므로(`AsyncAdapter`) 안내만 출력한다 — **상수가 아니라 테이블 존재로
가드한다**(먼저 상수로 썼다가 `PG::UndefinedTable` 로 죽는 것을 측정하고 고쳤다).

**정책을 `ApplicationJob` 에 일괄로 두지 않았다.** 재시도 안전성은 잡마다 다른 성질이다:

| 잡 | 정책 | 이유 |
|---|---|---|
| `PublishScheduledPostsJob` | `retry_on Deadlocked`·`ConnectionNotEstablished` (3회, polynomial) | **재생이 무해하다** — `scheduled_ready` 가 발행된 글을 즉시 제외하므로 두 번째 패스는 아무것도 재발행·재알림하지 않는다 (테스트로 고정) |
| `AutoGenerateBlogPostJob` | **재시도 없음** (누락이 의도) | 멱등이 아니다. 유료 Claude API 를 먼저 호출하므로 재생이 글 하나에 두 번 지불하고, `Post.create!` 후 `topic.update!` 전에 실패하면 재생이 같은 주제로 두 번째 글(`-1` 접미)을 만든다 |
| `ApplicationJob` | `discard_on DeserializationError` 만 (로그 남김) | 모든 잡에 안전한 것만. 레코드가 사라졌으면 어떤 재시도도 성공할 수 없다 |

**메일은 `ApplicationJob` 이 커버하지 않는다 — 이것이 이 작업의 함정이었다.**
`ActionMailer::MailDeliveryJob` 은 `ActiveJob::Base` 를 상속한다(실측: 조상이
`[MailDeliveryJob, ActiveJob::Base, …]`). **스캐폴드 주석을 그냥 해제하는 "수정" 은
메일 발송에 아무 효과가 없으면서 처리된 것처럼 보인다.** 그래서
`ApplicationMailDeliveryJob < ActionMailer::MailDeliveryJob` (신규) 을 만들고
`config.action_mailer.delivery_job` 로 연결했다(`config/application.rb`):
- 일시적 SMTP·네트워크 오류는 5회 재시도.
- **영구 거부는 재시도하지 않는다** — `SMTPAuthenticationError`(=2026-04-07 의 그 오류)는
  자격증명 문제라 몇 번을 보내도 실패한다. 로그를 남기고 **re-raise** 해서
  `solid_queue_failed_executions` 에 남게 한다.

### B-2 (AMBER, 프로덕션 데이터) — 폐기된 시드가 마이그레이션을 되돌리던 문제

**실측 재현** (개발 DB): 마이그레이션이 끝난 상태에서 시드를 돌리면 `resume-privacy` 가
`privacy` → `student` 로 돌아가고, 제목·영문제목·메타 설명이 시드의 하드코딩 값으로 덮인다.
그 쓰기는 `abort` **전에** 일어난다(항목1 저장 → 항목2·3 거부 → abort).

**판단: 가드가 아니라 제거.** 근거:
- 이 파일을 로드하는 곳은 `lib/tasks/blog.rake` 의 태스크 **하나뿐**이었다
  (`db/seeds.rb` 는 `blog_topics`·`blog_styles` 만 로드한다 — 확인).
- 3개 글은 **이미 프로덕션에 있다** (라이브 사이트맵 확인).
- **어떤 가드든 우회할 수 있다. 존재하지 않는 태스크는 우회할 수 없다.**

**다만 삭제만 하면 신선한 DB 에서 이 3개 글을 만들 경로가 사라진다**
(`blog:migrate_privacy` 는 기존 레코드만 고쳤다). 그래서 마이그레이션을
**create-or-update** 로 만들어 **단일 소유자**가 되게 했다. 제목·메타는 시드에서 옮겼다
(시드·개발 DB·라이브 3곳이 일치하는 것을 먼저 확인했다).

**소유 범위를 명시했다** — 이것이 시드의 결함을 물려받지 않는 지점이다:

| 필드 | create | update |
|---|---|---|
| `slug`(개명)·`category` | 설정 | **설정** (이 태스크가 소유) |
| `title_*`·`meta_description_*` | 설정 | **건드리지 않음** — 덮어쓰는 것이 시드가 잘못한 바로 그것 |
| `body_ko` | 파일에서 설정 | **비어 있을 때만** 파일에서 채운다 |

`body_ko` 를 "비어 있을 때만" 으로 바꾼 것은 **동작 변경**이다. 전에는 항상 파일로 덮었다.
이 태스크의 헤더가 스스로 "DB 를 단일 진실 원천으로 만든다" 고 적고 있으므로, 한 번 채운 뒤에는
파일이 할 일을 다 한 것이다 — 영구 소유자가 어드민 편집을 파일로 되돌리는 것은
"마이그레이션 이름을 쓴 되돌리기 버튼" 이다.

**같은 위험의 다른 시드 전수 확인 — 실측으로** (읽기만 하지 않았다). 각 시드가 쓰는
레코드의 필드를 마커로 바꾼 뒤 시드를 돌려 마커가 살아남는지 봤다:

| 시드 | 패턴 | 결과 |
|---|---|---|
| `db/seeds.rb` (배너) | `find_or_create_by!(…) do \|b\| … end` — 블록은 **생성 시에만** 실행 | **PRESERVED** (안전) |
| `db/seeds/blog_topics.rb` | 동일 | **PRESERVED** (안전) |
| `db/seeds/blog_styles.rb` | 동일 | **PRESERVED** (안전) |
| `db/seeds/safefile_posts.rb` | `find_or_initialize_by` + **블록 밖** `assign_attributes` + `save!` | **OVERWRITTEN** ← 유일한 위험 |

⚠️ **첫 프로브는 결함이 있었다**: safefile 시드의 마커를 `"student"` 로 썼는데 그건 시드가
쓰는 값과 같아서 덮어쓰기와 보존이 구분되지 않았다("PRESERVED" 라는 거짓 통과). 시드가 쓰지
않는 유효한 값(`"office"`)으로 다시 재서 `student` 로 덮이는 것을 확인했다.
**마커는 반드시 대상이 쓰는 값과 달라야 한다.**

`blog:regenerate_scheduled` 도 본문을 덮지만 `status: "scheduled"` 만 대상이고
마이그레이션이 만드는 글은 `published` 이므로 되돌릴 수 없다(코드 확인).

### 검증

| 검증 | 결과 |
|---|---|
| `bin/rails test` | **156 runs / 1171 assertions / 0 failures** (직전 110/835) |
| 신규 `test/jobs/retry_policy_test.rb` | 8개 |
| 신규 `test/integration/stuck_posts_visibility_test.rb` | 13개 |
| 신규 `test/integration/privacy_guide_ownership_test.rb` | 8개 |
| 확장 `test/jobs/publish_scheduled_posts_job_test.rb` | 22개 (직전 14) |
| 확장 `test/models/post_test.rb` | 16개 (직전 7) |
| **새 테스트가 직전 코드를 잡는가** | **67개 중 57개 실패/에러** (6 failures + 51 errors). 원인별: `publish_stuck` 부재 41 · `PUBLISH_GRACE` 부재 2 · `publish_overdue_by` 부재 1 · `ApplicationMailDeliveryJob` 부재 3 · `rescue_handlers == []` 2 · 마이그레이션이 생성 못 함 1 · 마이그레이션이 본문을 덮음 1 |
| **메일이 완전히 죽은 상태에서 막힌 글이 드러나는가** | 통과 — `post_published`·`publish_failed` 양쪽을 raise 로 만들고 `deliveries` 가 빈 것을 단언한 뒤, 배너와 스코프에서 글을 찾는다 |
| 엔드투엔드 (실제 HTTP) | 잡 실행 → `publish_error` 기록 → `rake blog:stuck` exit 1 · 배너 "발행되지 못한 글 1건" · `Stuck (1)` 칩 · 한국어 이유 전부 확인 |
| 마이그레이션 생성 경로 | 개발 DB 에서 3개 글을 **실제로 지우고** 재생성 — 카테고리·본문·제목·메타·발행일 전부 정확 |
| 마이그레이션이 편집을 지키는가 | 5개 필드를 사람이 고친 것처럼 바꾼 뒤 재실행 — `saved_changes` 가 `[category, updated_at]` 뿐 |
| 프로덕션 미들웨어·정본 URL (직전 라운드) | 137경로 중복 200 **0개**, 루프 0, 홉 `{1: 89, 2: 1}` |
| 사이트맵 30 / 내부 링크 64 / Accept-Language 8페이지 | 전부 문제 0 |
| SW 네트워크 실패 주입 | **9/9** |
| rubocop | **신규 위반 0** (변경 파일 17개에서 10건, 직전 커밋 사본에 돌린 baseline 도 같은 10건) |
| 프로덕션 DB | **미접촉** |

### self-check / 이번 라운드에 잡힌 자기 실수

- 🔴 **`git checkout -- .` 로 커밋하지 않은 작업을 날렸다.** "상태를 리셋" 하려고 돌렸는데
  그 시점의 소스 수정 11개 파일이 함께 사라졌다(테스트·마이그레이션은 untracked 라 생존).
  전부 다시 작성해 복구했고 테스트 수·단언 수가 사고 전과 동일함을 확인했다.
  **교훈: 파괴적 git 명령 전에 커밋한다.** 이후의 "구 코드 대조" 는 먼저 체크포인트 커밋을
  만들고 나서 실행했다 — 그래야 `git checkout HEAD -- <파일>` 로 되돌릴 수 있다.
- `rake jobs:failed` 를 `defined?(SolidQueue::FailedExecution)` 로 가드했다가 dev 에서
  `PG::UndefinedTable` 로 죽는 것을 측정했다. 젬이 모든 환경에 로드되므로 상수는 항상 있다 —
  **테이블 존재**로 가드해야 한다.
- 시드 덮어쓰기 프로브의 마커가 대상이 쓰는 값과 같아 거짓 통과가 나왔다(위 ⚠️).
- `retry_policy_test.rb` 의 re-raise 단언을
  `assert_raises(SameError) { handler_call || raise(SameError) }` 로 썼다가 고쳤다 —
  핸들러가 삼켜도 **테스트가 스스로 예외를 공급**하므로 통과하는 공허한 단언이었다.
  동일 객체(`assert_same`)로 바꿨다.
- 잡 테스트를 자식 프로세스(`bin/rails blog:stuck`)로 돌렸더니 아무것도 보고하지 않았다 —
  테스트의 레코드가 **커밋되지 않은 트랜잭션** 안에 있어 자식이 볼 수 없었다.
  초록 단언과 안 보이는 DB 가 밖에서 같아 보인다. `test/support/rake_task_helper.rb` 로
  **같은 프로세스에서** 실행하고 `abort` 의 `SystemExit` 를 종료코드로 번역한다.
- `publish_stuck` 이 26시간 단일 규칙이던 것을 테스트가 잡았다(위 "두 가지 인내심").
- 스코프와 술어(`publish_stuck?`) 두 구현이 어긋나지 않도록 **8개 조합 전수 대조** 테스트를 뒀다.

### 남는 관찰 (수정 안 함)

- `rake jobs:failed` 는 사람이 돌려야 보인다. 정기 확인을 자동화하려면 `recurring.yml` 에
  넣거나 외부 모니터를 붙여야 한다 — 알림 채널을 또 만드는 판단이라 이번 범위에서 뺐다.
- `blog:generate`·`regenerate_scheduled` 는 여전히 exit 0 (사람이 보는 앞에서 도는 생성
  태스크라는 기존 관례). 자동화에 들어가면 조용한 실패가 된다 — Codex 가 직전 라운드에
  올린 관찰 그대로다.
- Banner·BlogTopic·Conversion 의 속성명은 ko 번역이 없어 영어 humanize 로 나온다.
- `<html lang>`·`og:locale`·UI 크롬은 여전히 협상된다. 제품 결정.

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

**외부 교차검증 (Codex CLI `gpt-5.5`, read-only, 88초)**: 패키지
[`docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_minitest-sweep.md`](docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_minitest-sweep.md) ·
원문 [`CODEX_RESULT_2026-09-17_minitest-sweep.md`](docs/review/CODEX_RESULT_2026-09-17_minitest-sweep.md) ·
대조 [`CROSS_REVIEW_TRIAGE_2026-09-17_minitest-sweep.md`](docs/review/CROSS_REVIEW_TRIAGE_2026-09-17_minitest-sweep.md).
지적 4건 중 **(a) 진짜 문제 1건**(판정 기준 `minitest >= 6` 이 과함 — 8.0.5 의 분기에 `else` 가 없어
**minitest 7 은 LineFiltering 이 아예 안 붙고 줄 필터링이 조용히 죽는다**), **(b) 의견 차이 2건**,
**(c) 오탐 1건**(lock↔로드 괴리 주장 — 실은 minitest 5.27.0 이 `VERSION = "5.26.2"` 로 상수를 잘못 박은 것.
`bundle list` 로 8개 전수 재확인해 lock 과 전부 일치함을 확인했다). **이 세션에서 (a) 는 고치지 않았다.**
