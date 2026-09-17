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

## Favicon & PWA Manifest (2026-04-22)

- **Files in `public/`**: `favicon.ico`, `favicon-16x16.png`, `favicon-32x32.png`, `apple-touch-icon.png`, `android-chrome-192x192.png`, `android-chrome-512x512.png`, `site.webmanifest`
- **Manifest**: name=SlimFile, theme_color=`#0A6E8A` (teal primary), background_color=`#F8F7F4` (page bg), display=standalone
- **Layout**: `<link>` tags in `app/views/layouts/application.html.erb` head — favicon (ico + 16/32 png), apple-touch-icon (180x180), manifest
- **Source**: Generated via favicon.io
- **Commit**: `a1fd3dc feat: add full favicon set with PWA manifest`
