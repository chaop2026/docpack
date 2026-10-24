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

### 리뷰 대기 중 self-check 가 잡은 실제 결함 (같은 커밋에서 수정)

⑦.3("파생 상태가 놓치는 경우")을 직접 파보다 찾았다. **잡이 거부한 글을 사람이 어드민에서
고쳐도 `publish_error` 가 남아, 배너가 이미 해결된 실패를 계속 설명한다.** 재현(실측):

```
after failure  : stuck=true  reason="…본문(한국어)을(를) 입력해 주세요"
after admin fix: stuck=true  reason="…본문(한국어)을(를) 입력해 주세요"   ← 거짓
                 body=18b                                             ← 본문은 채워져 있다
```

어드민 폼이 `status`·`published_at` 을 실제로 노출하는 것도 함께 확인했다(실측).
그 경로 자체는 **오탐이 아니다** — 그렇게 되돌린 글은 다음 09:00 런에 발행되고, 이유가
기록돼 있지 않으므로 26시간 유예가 정확히 그 창을 덮는다.

**수정**: `before_save :clear_stale_publish_error, if: -> { publish_error.present? && changed? }`.
기록된 이유는 "잡이 시도한 시점" 을 설명하므로 사람이 편집하면 거짓일 수 있다. 지우면 글은
여전히 `publish_stuck` 에 남되 **유예 창으로 되돌아간다** — 증거가 사라졌으니 다음 런을 다시
기다리는 것이 정직한 상태다. 잡은 `update_column` 으로 쓰고 지우므로 이 콜백과 다투지 않는다.
테스트 3개(지워짐 / 지워도 진짜 지연은 유지 / 변경 없는 저장은 그대로).

### 외부 교차검증 (Codex CLI, read-only)

- 패키지 `docs/review/CODEX_REVIEW_PACKAGE_2026-09-18_amber2b.md`
  (**잡·메일러·시드·레이크 계층 전부 + Solid Queue 젬 소스 인용** — 재시도 논증의 전제를
  리뷰어가 *확인할 수 있게* 했다. 비밀값 0건, 어드민 개발 폴백 비밀번호 등장은 명시했다)
- 원문 `docs/review/CODEX_RESULT_2026-09-18_amber2b.md` (codex-cli 0.144.3, `gpt-5.5`)
- 대조 `docs/review/CROSS_REVIEW_TRIAGE_2026-09-18_amber2b.md` — 13건 전부 (a)/(b)/(c) 분류
- **B-1 `해소됨` · B-2 `해소됨`.** (b) 의견 차이 0건. **"경로 요청" 0건**
  (라운드 2: 1건 → 라운드 3: 3건 → 이번 0건).
- ⚠️ **새 (a) 1건 — 다음 런. 이번 세션에서는 고치지 않았다**:
  **GREEN** `publish_stuck` 스코프와 술어가 **시계를 따로 읽는다**. 측정하니 지적보다 한 겹
  더 있었다 — 스코프 **내부**에서도 `Time.current` 를 두 번 불러 `cutoff` 가 `now - grace` 가
  아니다(**39 마이크로초** 벌어짐). 두 구현 합쳐 시계를 네 번 읽는다.
  26시간 창 + 하루 한 번 잡에서 어떤 판정도 바꾸지 않지만, **근거가 값의 성질이 아니라
  값의 크기**라서 (a) 로 센다. → `now:` 를 주입해 한 번만 읽게 한다. 부수 효과로
  테스트가 경계값을 마이크로초 단위로 고정할 수 있게 된다(지금은 못 한다).
- Codex 가 독립 확인해준 것: SQL 우선순위(우리가 리뷰 대기 중 이미 괄호를 넣었다),
  `update_column` 사용의 타당성(+`updated_at` 미오염 이점을 추가로 짚어줬다),
  재시도 정책의 적합성, 시드 제거 판단, 새 소유 범위, `/up` 부작위, **공허한 단언 없음**
  (세 지점 모두), 파생 상태가 플래그보다 낫다는 주장.
- 여전히 열린 것: 메일 예외 목록의 완결성(우리 ⑦.4, Codex 도 "확정 불가"),
  `rake jobs:failed` 의 프로덕션 큐 DB 실측(**배포 후 확인 항목**).

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

## 젬 업그레이드 — minitest 핀 제거 + dependabot 12건 분류 (2026-09-18)

브랜치 `chore/gem-upgrades`. **미배포.** 프로덕션 DB 미접촉. 모든 판정은 로컬 실측이고,
읽지 않은 릴리스 노트를 근거로 쓴 곳은 없다.

### 1. `minitest "~> 5.25"` 핀을 **원인 제거**로 풀었다

핀은 증상 억제였다. railties 8.0.4 는 `line_filtering.rb` 에서 2-arity `run` 을 **무조건**
prepend 하는데 minitest 6 은 3인자로 부른다. railties **8.0.5** 가 `Minitest::VERSION` 분기와
MT6 용 `run_suite` 를 들고 오면서 그 비호환 자체가 사라졌다 — 그래서 핀이 아니라 하한을 올렸다.

| | 전 | 후 |
|---|---|---|
| `Gemfile` rails | `~> 8.0.4` | **`~> 8.0.5`** |
| 해석된 rails | 8.0.4 | **8.0.5.1** |
| `Gemfile` minitest | `~> 5.25` (핀) | **`< 7`** (상한만) |
| 해석된 minitest | 5.27.0 | **6.0.6** |
| Ruby (Dockerfile · Dockerfile.dev) | 3.3.0 | **3.3.9** (`.ruby-version` 과 일치) |

`8.0.5` → `8.0.5.1` 은 전 컴포넌트 CHANGELOG 가 "No changes" 이고, `8.0.4`→`8.0.5` 는 버그픽스
전용이다(라우팅·미들웨어·잡 의미 변경 0건 — 6개 젬 CHANGELOG 전수 확인).

#### `< 7` 상한은 핀이 아니라 **다른 제약**이라 남긴다

railties 8.0.5.1 의 분기에는 `else` 가 없다:

```ruby
case Minitest::VERSION
when /^5/ then obj.extend MT5
when /^6/ then obj.extend MT6
end                            # ← else 없음
```

읽고 판정하지 않고 **프로브로 확인**했다 (`Minitest::VERSION` 을 바꿔가며 실제로 extend):

```
Minitest::VERSION=6.0.6  -> Rails::LineFiltering::MT6
Minitest::VERSION=7.0.0  -> NONE (줄 필터링이 조용히 무력화)
Minitest::VERSION=5.27.0 -> Rails::LineFiltering::MT5
```

minitest 7 은 **죽지 않는다** — `bin/rails test 파일:42` 가 그 줄 대신 **파일 전체**를 돈다.
조용한 오답이 시끄러운 크래시보다 나쁘므로, railties 에 `else`(또는 `/^7/`)가 생길 때까지 상한을 둔다.
(직전 라운드 Codex 지적 a-1 이 여기서 해소됐다.)

#### minitest 6 이 실제로 요구한 코드 변경 — `minitest/mock`

minitest 6.0.0 이 `lib/minitest/mock.rb` 를 **별도 젬으로 분리**했다(History.rdoc 6.0.0:
"Dropped minitest/mock.rb. This has been extracted to the minitest-mock gem."). 이 저장소는
`Object#stub` 때문에 두 파일에서 `require "minitest/mock"` 한다
(`test/jobs/publish_scheduled_posts_job_test.rb`, `test/integration/stuck_posts_visibility_test.rb`)
→ `gem "minitest-mock"` 추가. 그 젬은 minitest 에 **런타임 의존이 없다**(gemspec 확인) — 파일이
옮겨갔을 뿐이다.

**단언 수가 1179 → 1218 로 늘었다.** 코드가 바뀌어서가 아니라 minitest 6 의
"Assertions reuse themselves a lot more. Bumps assertion count in some places."(자체 changelog) 때문이다.
런 수는 159 로 동일하다.

#### ★ `CanonicalPathRedirect` 삽입 위치 — Rails 8.0.5.1 에서도 유효한가

`script/middleware_probe.sh`(신규) 로 **프로덕션 스택을 실제로 뽑아** 3형태 전부 측정했다.
컨테이너 재시작 **후**에 쟀다(이니셜라이저·`lib/` 는 dev 에서 리로드되지 않는다 — 두 세션 연속 당한 함정).

| 구성 | 8.0.4 (전) | 8.0.5.1 (후) |
|---|---|---|
| `RAILS_SERVE_STATIC_FILES=true` (실제 배포 형태) | Static 바로 앞 | **동일** |
| 변수 미설정 | Static 바로 앞 | **동일** |
| `public_file_server.enabled = false` | 스택 최상단 | **동일** |

27줄 전체 스택을 `diff` 로 대조 — **완전히 동일**(옛 Gemfile 을 `BUNDLE_GEMFILE` 로 따로 물려 8.0.4
스택을 다시 뽑아 비교). 나아가 **실제 프로덕션 이미지를 빌드해** 그 안에서도 확인했다:
`docker build` → `bin/rails middleware` → `CanonicalPathRedirect` 가 `ActionDispatch::Static` 앞.
dev 컨테이너가 아니라 배포되는 아티팩트에서 잰 값이다.

#### Ruby 3.3.0 ↔ 3.3.9 불일치 (부수 발견, 수정함)

`.ruby-version` 은 3.3.9 인데 `Dockerfile`·`Dockerfile.dev` 는 3.3.0 이었다. CI 는
`ruby/setup-ruby` 로 `.ruby-version` 을 읽으므로 **CI 가 프로덕션과 다른 인터프리터를 시험하고
있었다** — 초록 CI 는 전부 3.3.9 에 대한 증거였고 3.3.0 에 대한 증거는 하나도 없었다.
Dockerfile 자신의 주석이 "Make sure RUBY_VERSION matches .ruby-version" 이라고 적고 있다.
같은 3.3 계열이라 패치 정렬이며, **프로덕션 이미지를 3.3.9 로 실제 빌드해 부팅까지 확인**했다.

### 2. dependabot 12건 — 기준을 먼저 정하고 그 기준대로 분류

**버전 번호가 아니라 측정으로 분류한다.** 올리는 조건은 전부 충족:
(a) 릴리스 노트/소스 diff 에 **이 앱이 실행하는 경로**에 닿는 breaking change 가 없다 —
번호가 아니라 읽어서 확인 · (b) 이 앱의 사용처를 **grep 으로 확인**(추정 금지) ·
(c) 로컬 검증 전부 통과 · (d) 잘못된 판단이 **로컬에서 드러난다**(프로덕션에서만 드러나면 안 된다).
보류 조건은 하나라도 해당하면: (x) breaking change 가 실행 경로에 닿는다 ·
(y) 확인하려면 **배포해야 한다**(내 권한 밖) · (z) 배포 경로 위에 있는데 **이 앱에 필요한 것이 없다**.

#### 올린 것 — 7건

| 젬 | 전 → 후 | 분류 | 근거 |
|---|---|---|---|
| bootsnap | 1.23.0 → **1.26.0** | minor | 훅 API 추가 + Ruby 3.4/4.0·YJIT 캐시키 버그픽스. 부팅 시점만 |
| brakeman | 8.0.4 → **8.0.6** | patch | dev/test 그룹. **경고 6건·exit 3 이 8.0.4 와 완전히 동일**(나란히 측정) |
| jbuilder | 2.14.1 → **2.15.1** | minor | 내부 성능. **이 앱에 `.jbuilder` 뷰가 0개** — 젬이 로드되지도 않는다 |
| propshaft | 1.3.1 → **1.3.2** | patch | text/html·text/css 에 `charset=utf-8` 추가. 관측됨: `/assets/*.css` 가 `text/css; charset=utf-8`. 프로덕션은 `RAILS_SERVE_STATIC_FILES=true` 라 Propshaft::Server 를 안 탄다 |
| rubyzip | 3.2.2 → **3.6.0** | **minor (메이저 아님)** | zip-slip 방지·SecureRandom 은 **추출** 경로. 이 앱은 쓰기만 한다(`Zip::OutputStream.open` + 블록, `conversions_controller.rb:173`). 2엔트리 아카이브 쓰기·읽기 스모크 통과 |
| selenium-webdriver | 4.41.0 → **4.49.0** | minor | test 그룹. **`test/system` 디렉터리가 없어** `test:system` 이 0건을 돈다(실측, exit 0) |
| solid_cable | 3.0.12 → **4.0.2** | **major 인데 측정상 additive** | 아래 별항 |

**bundler 가 dependabot 제안보다 더 올라갔다**(rubyzip 3.4.1→3.6.0, solid_cable 4.0.0→4.0.2,
bootsnap 1.24.6→1.26.0, brakeman 8.0.5→8.0.6, selenium 4.46→4.49). **그 델타도 읽었다** —
안 읽은 버전을 "검토함" 으로 치지 않는다. `msgpack 1.8.0→1.8.5` 는 bootsnap 의존으로 따라왔다.

**solid_cable 4.0.0 별항 — 번호는 메이저, 측정은 additive.**
3.0.12↔4.0.2 **전체 소스 diff** 를 떴다: ① `Listener` 에 재연결 백오프 추가,
② Rails 8.1 용 executor 실드, ③ **빈 `Railtie` 클래스 삭제**(3.0.12 의 `lib/solid_cable.rb` 도
그 파일을 require 하지 않았다 — 죽은 코드였다. 이게 메이저인 이유). 런타임 의존 불변(`>= 7.2`),
`required_ruby_version >= 3.3.0`(우리 3.3.9). **gemspec 의 `minitest ~> 5.0` 은 development
의존이라 이 번들에 오지 않는다 — 왔다면 방금 푼 핀이 되살아났을 것이라 일부러 확인했다.**
그리고 **이 앱에는 `app/channels` 가 없다** — 어댑터가 설정만 돼 있고 `Listener` 를 만들지 않는다.
⚠️ 지시문의 "solid_cable 은 Solid Queue 와 함께 도는 인프라" 는 사실이 아니다 — solid_cable 은
**Action Cable** 어댑터이고 Solid Queue 와 무관하다.

#### 보류한 것 — 3건 (근거와 함께)

**① image_processing 1.14.0 → 2.0.2 — (x) 실행 경로 직격. 가장 위험.**
이 앱의 **세 제품 전부**가 `ImageProcessing::Vips` 를 탄다
(`image_compressor.rb`·`pdf_builder.rb`·`social_resizer.rb`). 2.0.0 changelog 원문:

- "`mini_magick`/`ruby-vips` are now soft dependencies and need to be **manually added to the Gemfile**"
  → 지금 `ruby-vips 2.3.0` 은 image_processing 1.14.0 이 끌고 오는 것이다(`Gemfile.lock:136`).
  `gem "ruby-vips"` 를 **먼저** 넣지 않고 올리면 세 서비스가 전부 죽는다.
- "[vips] **Unfuzzed loaders are now blocked by default**" → 받아들이는 입력 포맷이 바뀐다.
  사용자가 올리는 임의의 이미지를 처리하는 앱이다.
- "[vips] **Sharpening after resize has been disabled by default**" → **출력 품질이 조용히 바뀐다.**
  리사이즈 품질이 이 제품의 본체다.

→ 올리려면 `ruby-vips` 명시 + 실제 이미지로 전/후 출력 비교가 **선행**돼야 한다. 별도 작업이다.

**② puma 7.2.0 → 8.0.2 — (x)+(y). 프로덕션 웹서버.**
8.0.0 의 유일한 "Breaking changes" 항목이 바인드 주소다: *"Default production bind address
changed from `0.0.0.0` to `::` (IPv6) when a non-loopback IPv6 interface is available."*
`config/puma.rb:31` 은 `port ENV.fetch("PORT", 3001)` 로 **호스트를 명시하지 않는다** — 업그레이드
가이드가 핀하라고 지목한 바로 그 형태다(`port ENV.fetch('PORT',…), '0.0.0.0'`).

측정한 것: 프로덕션 이미지 안에서 puma 8 의 판정식을 그대로 돌리면
`ipv6_interface_available? => false`(주소 `127.0.0.1`·`172.17.0.4`·`::1` 뿐) → **이 모양의
컨테이너에서는 무해**하다. 하지만 그건 내 로컬 docker 브리지이지 Kamal 이 만드는 프로덕션
네트워크가 아니다. **확정하려면 배포해야 하는데 그건 사람 몫이다.**

같이 확인해서 **문제가 아니라고 배제한 것들**: `solid_queue` 의 puma 플러그인은
`Puma::Const::VERSION < 7` 로 분기하고 puma 8 은 `after_booted`/`after_stopped`/`before_restart`
경로를 타는데 **그 셋 다 puma 8.0.2 에 그대로 있다**(소스 확인). `before_thread_start` 는
이 앱에서 안 쓴다. `http_content_length_limit` 기본값은 7·8 둘 다 `nil` 이라 6번 항목도 무관.
`fork_worker` 미사용이라 phased-restart 변경도 무관.

→ 권장 순서: 먼저 `config/puma.rb` 에 바인드를 **명시**하고(puma 7 상태로) 배포해 무해함을 확인,
그 다음 puma 8. 두 변경을 한 배포에 섞지 않는다.

**③ kamal 2.11.0 → 2.12.0 — (y)+(z). 배포 도구 자체.**
소스 diff 는 넓다(CLI 다수 · validator · 새 OTel output 서브시스템). 이 저장소가 의존하는
`$(...)` 치환(`Kamal::Secrets::Dotenv::InlineCommandSubstitution`)과 `configuration/proxy.rb` 는
**바이트 동일**이라 알려진 함정은 재발하지 않는다(확인함). 그래도 보류하는 이유는 버그가 아니라
**순서**다 — **배포 도구와 앱을 같은 배포에서 함께 바꾸면, 실패했을 때 어느 쪽 탓인지 알 수 없다.**
Rails 업그레이드가 무사히 나간 뒤 단독으로 올린다.

#### GitHub Actions 2건 — 올렸다 (검증은 push 후 GitHub 에서)

`actions/checkout@v4 → v7`, `actions/upload-artifact@v4 → v7`.
**동기가 실측으로 있다**: main 의 모든 런에 이미
`Node.js 20 is deprecated. … actions/checkout@v4 … forced to run on Node.js 24` 주석이 붙는다.

각 메이저의 breaking change 가 **이 워크플로를 비껴가는 이유**:
v5/v6 의 Node 24 런타임 + 러너 `>= 2.327.1` 요구 → 전 잡이 `ubuntu-latest`(GitHub 호스티드,
항상 그 이상)이고 self-hosted 러너가 없다. checkout v7 의 "fork PR 체크아웃 차단" 은
`pull_request_target`·`workflow_run` 한정인데 이 워크플로는 `pull_request`·`push` 만 쓴다.
upload-artifact v7 의 `archive:` 는 추가 입력이고 기본값 불변이며, 그 스텝은
`if: failure()` 스크린샷 업로드라 `test/system` 이 없는 지금은 아예 발화하지 않는다.

⚠️ **워크플로 파일은 로컬에서 돌려볼 수 없다. 이 2건만은 push 후 GitHub 에서 확인해야 한다.**

#### ⚠️ 베이스라인 정정 — **CI 는 이미 빨간색이었다**

손대기 전에 측정했다(run `35295783921`, main):

| 잡 | 상태 | 이유 |
|---|---|---|
| `test` | ✅ | — |
| `scan_js` | ✅ | — |
| `lint` | ❌ | rubocop **86건** (전부 기존 것) |
| `scan_ruby` | ❌ | brakeman 경고 6건 → **exit 3** |

이 브랜치는 네 결과를 **하나도 바꾸지 않는다**(86=86, 6=6, main 트리에 같은 도구를 돌려 대조).
**push 후 CI 가 빨갛다면 "빨간가" 가 아니라 "어느 잡인가" 를 봐라.**
기존 86건·6건을 어떻게 할지는 이 작업의 범위가 아니다 — **사람 결정 사항**.

### 3. 검증 (전부 Ruby 3.3.9 + Rails 8.0.5.1 + minitest 6.0.6 에서 재측정)

| 검증 | 결과 |
|---|---|
| `bin/rails test` | **159 runs / 1218 assertions / 0 failures / 0 errors** (전 159/1179 — 단언 증가는 minitest 6 자체의 변화) |
| `bin/rails test:system` | 0 runs, exit 0 (CI 가 함께 돌린다) |
| 줄 필터링 (minitest 6 의 MT6 경로) | `post_test.rb:13` → **1 run** vs 파일 전체 19 runs |
| 프로덕션 미들웨어 스택 3형태 | 8.0.4 와 **27줄 전부 동일**. `CanonicalPathRedirect` 가 Static 앞 |
| **실제 프로덕션 이미지** | `docker build` 성공(Ruby 3.3.9) → 부팅 → 스택 위치 동일 |
| `script/canonical_sweep.rb` | **88 철자 / 중복 200 = 0 / 홉 `{1=>66, 2=>2}` / 6개 검사 전부 통과** |
| **그 스윕이 공허하지 않은가** | 미들웨어를 실제로 빼고 재측정 → **64건 실패, 중복 200 이 20→84** (빼고 넣을 때마다 컨테이너 재시작) |
| SW 네트워크 실패 주입 | **9/9** |
| rubocop | 86건 — main 트리에 같은 도구를 돌린 값과 **동일** (신규 0) |
| brakeman | 경고 6 / exit 3 — main 과 **동일** |
| `bin/importmap audit` | no vulnerable packages |
| 이미지 파이프라인 | `ImageProcessing::Vips` resize+convert 정상(1.14.0 유지) |
| ZIP 쓰기 경로 | rubyzip 3.6.0 으로 2엔트리 아카이브 쓰기·재읽기 정상 |
| `rake blog:stuck` / `jobs:failed` | 정상 동작 (막힌 글 0) |
| 프로덕션 DB | **미접촉** |

### 4. 이번에 커밋한 검증 스크립트 2개 (다음 라운드가 다시 만들지 않도록)

- **`script/middleware_probe.sh`** — 프로덕션 미들웨어 스택을 3개 정적파일 구성에서 출력한다.
  세 번째 구성(`public_file_server.enabled = false`)은 **임시 이니셜라이저**로 만든다 —
  `canonical_path_redirect.rb` 가 그 플래그를 **로드 시점에** 읽으므로 알파벳순으로 앞서는
  이름(`aaa_…`)이어야 하고, `trap EXIT` 로 지운다.
- **`script/canonical_sweep.rb`** — 매 라운드 손으로 다시 만들던 6개 검사(중복 200 · 홉 수 ·
  사이트맵 · 내부 링크 · canonical↔JSON-LD · Accept-Language 불변성)를 한 파일에 고정. 실패 시 exit 1.
  함정 하나를 주석으로 박아뒀다: **`URI.join` 을 쓰면 안 된다** — 선행 `//` 를 프로토콜 상대 주소로
  읽어 `//about` 이 호스트 `about` 이 된다. 그 철자가 바로 검사 대상이다.

### 5. 부수로 고친 것 (젬과 무관, 새 스윕이 잡았다)

`public/privacy/index.html:101` 이 `https://slimfile.net/blog/` 를 링크하고 있었다 —
트레일링 슬래시 작업 이후 301 이다. 직전 라운드의 내부 링크 측정이 놓친 이유는 그 측정이
**상대 경로 href 만** 봤기 때문이다(이건 절대 URL). `/blog` 로 고쳤다.

### 6. 남는 관찰 / 다음 런

- `rails "~> 8.0.5"` 는 **8.1 을 막는다**(전 `~> 8.0.4` 와 같은 천장). dependabot 이 8.1 을
  제안하면 제약을 넓혀야 하고, 그때 `minitest < 7` 상한도 재점검한다.
- brakeman 이 `Support for Rails 8.0.5.1 ends on 2026-11-07` 을 보고한다. 8.1 이전 계획이 필요하다.
- CI 의 `lint`·`scan_ruby` 가 기존 결함으로 빨갛다 (위 표). 사람 결정.
- `test/safe/node_modules` 심링크가 **죽은 스크래치패드**를 가리킨다. SW 하네스를 돌리려면
  playwright 를 매번 새로 깔아야 한다 — `test/sw/README.md` 의 안내가 현실과 어긋나 있다.

### 7. 외부 교차검증 (Codex CLI, read-only)

- 패키지 `docs/review/CODEX_REVIEW_PACKAGE_2026-09-18_gems.md` (비밀값 0건 — `deploy.yml` 은
  서버 IP·레지스트리 계정 때문에 **넣지 않고** 판단에 필요한 4줄만 인용)
- 원문 `docs/review/CODEX_RESULT_2026-09-18_gems.md` (codex-cli 0.144.3, 55,004 tokens)
- 대조 `docs/review/CROSS_REVIEW_TRIAGE_2026-09-18_gems.md` — 지적 3건 + 질문 답변 9건 전수 분류
- **젬 선택·업그레이드 판단에 대한 (a) 지적은 0건.** Codex 가 독립 확인해준 것:
  `rails "~> 8.0.5"` 로 railties 하한이 간접 강제되는 것(lock 상 `rails` 가 `railties (= …)` 로
  못박음) · `minitest-mock` 추가가 `Object#stub` 재구현보다 안전 · **puma 8 보류가 과하지 않음**
  (`proxy.app_port` 는 Puma 의 bind host 를 고정하지 않는다) · **image_processing 보류가 알려진
  보안 수정 방치가 아님**(호출부 3개가 취약 경로인 user-input loader/saver 옵션·`#apply` 를
  타지 않는다) · Actions v7 트리거 판단.
- ⚠️ **새 (a) 3건 — 다음 런. 이번 세션에서는 고치지 않았다.** 셋 다 **이번에 새로 커밋한
  검증 스크립트**의 결함이고, 둘은 내가 패키지에 "확신 없음" 으로 올린 항목이다.
  **세 건 모두 반영 전에 직접 재현했다**:
  1. **AMBER** `canonical_sweep.rb` 가 **sitemap 이 죽으면 0건 검사하고 통과**한다.
     재현: `SLUGS` 를 비우면 `0 entries checked` / `0 internal link targets` → `ALL CHECKS PASSED`.
     **"0 tests" 가 통과처럼 보였던 minitest 사고와 같은 모양**을, 그 교훈을 적어둔 저장소에서
     내가 다시 만들었다. → sitemap 200 + `<loc>` 개수 하한을 단언한다.
  2. **AMBER** `[5/6]` JSON-LD 검사가 **단언 0회로도 통과**한다. 재현: 지금은 31페이지에서
     **6회** 비교가 실제로 돈다(공허하지 않다) — 그러나 JSON-LD 블록이 통째로 사라지는
     회귀가 오면 "31 pages checked" 를 찍고 통과한다. 출력이 **비교 수가 아니라 페이지 수**다.
  3. **AMBER (배포 위험)** `middleware_probe.sh` 의 임시 이니셜라이저가 남으면
     **`ActionDispatch::Static` 이 프로덕션 스택에서 0개가 된다**(실측) — `/safe/`·`/privacy/`
     ·`/assets/*` 가 전부 죽는다. Codex 는 SIGKILL 을 들었지만 **더 현실적인 경로가 있다**:
     스크립트가 도는 중에 `docker compose restart web` 이 들어오면 프로세스는 죽고 파일은
     **바인드 마운트라 호스트 트리에 남는다**(실측). 이번 세션에 그 명령을 열 번 넘게 돌렸다.
     `git status` 에 `??` 로 뜨긴 하지만, **이번 세션에서 `git add -A` 가 의도치 않은 심링크를
     실제로 커밋에 쓸어 담았다** — 그 안전망은 뚫린 전례가 있다.
     → 파일명을 gitignore 하고(가드보다 강한 것은 "커밋될 수 없음"), 더 낫게는 **저장소 안에
     파일을 만들지 않는 방식**으로 바꾼다. **배포 전 처리 권장.**
- **(b) 의견 차이 1건**: 상한 대신 CI 단언을 두라 → "대신" 이 아니라 "함께" 다.
  상한은 **예방**(오늘 나와도 막는다)이고 단언은 **탐지**(들어온 뒤 빨간불)다. 순서가 다르다.
  다만 "풀어야 할 때를 아무도 모른다" 는 지적은 옳다 — 주석은 실행되지 않는다.
  줄 필터링 회귀 테스트를 다음 런에 추가한다. **(c) 오탐 0건.**
- 이번 라운드 관찰: Codex 가 read-only 샌드박스에서 **저장소를 직접 읽어**(패키지 밖 파일 포함)
  "경로 요청" 이 0건이었다. 대신 인용 줄 번호는 패키지가 아니라 실제 파일 기준이다.
- 방법론 결과: **매 라운드 버려지던 검증 스크립트를 고정한 것은 옳았지만, 고정하는 순간
  그것도 검토 대상이 된다.** 이번 (a) 3건이 전부 거기서 나왔다.

## SafeFile JP-1 알파 — 띠 단일화 + 일본 4종 탐지 + 목적 프리셋 (2026-10-21)

브랜치 `main`. **미배포.** 프로덕션 DB 미접촉.
보고 [`docs/jp/s3_report.md`](docs/jp/s3_report.md) · 전체 로그 [`docs/jp/s3_golden_result.md`](docs/jp/s3_golden_result.md)
전략 [`docs/jp/jp_safefile_strategy_v2_2026-10-21.md`](docs/jp/jp_safefile_strategy_v2_2026-10-21.md) §3·§7
법적 정본 [`test/safe/fixtures/jp/jp_legal_matrix_alpha4.json`](test/safe/fixtures/jp/jp_legal_matrix_alpha4.json)

**골든 130 → 389, 0 실패.** SW 하네스 9/9 유지.

### 1. 마스킹이 **띠만** 남았다 (모드 3 → 2)
부분 마스킹은 비밀의 일부를 배경색 패치 **위에 다시 그린다** — 안전성이 "우리가 얼마나
드러내기로 했는가" 에 달려 있고, 제출하는 사람은 결과 파일만 보고 그 판단을 감사할 수 없다.
띠에는 그 자유도가 없다. 부분이 기본이던 유형은 전부 띠 기본이 됐다(더 많이 가린다).
`drawRedactions` 의 오버랩 에스컬레이션 경로 전체가 **모드와 함께 사라졌다** — 두 별표
문자열이 서로 위에 그려지던 실패 종류가 통째로 없어졌다.

- `bandRect()` = 박스 + max(높이 15%, 2px). 박스는 **추정치**다(pdf.js 는 사이드베어링 제외,
  OCR 은 안티앨리어싱 가장자리 절단). `region:true`(사람이 드래그한 영역·탐지된 欄)는 **키우지 않는다** — 그건 추정이 아니라 의도다.
- 띠 색: 먹(기본)·흰색·지정 1색.
- 골든의 `__maskRects` 가 **패딩 적용 후**를 잰다 → `MUST_NOT_MASK` 가 더 엄격해졌다.

### 2. 출력 안전성: "0 extractable characters" 는 **세 누출 중 하나**다
나머지 둘은 바이트를 읽어야 보인다 — 이미지 EXIF/XMP/IPTC, PDF `/Annots`·`/EmbeddedFile`,
그리고 **증분 저장**(리비전 1 = 미마스킹본이 같은 파일에 물리적으로 남음 → `%%EOF` 정확히 1개).
ICC 는 금지하지 않되 경계를 둔다: Chrome 의 456B 일반 sRGB 는 색공간 선언이지만
**열람자의 디스플레이 프로파일**은 제조사·모델 태그(`dmnd`/`dmdd`)를 달고 훨씬 크다.

### 3. 일본 탐지 — 정규식 단독 자동마스킹 금지
자동 띠 = ① 문서분류 ∧ ② 같은 행 레이블 앵커 ∧ ③ 형식(個人番号는 체크디지트). 그 미만은 후보.

- **NFKC 를 문자 단위로** 돌린다 → 1→n 확장은 허용하되 n→1 결합(`ｶ`+`ﾞ`→`ガ`)이 원본
  인덱스를 삼키는 일이 **구조적으로 불가능**.
- **OCR 혼동 접기는 문맥 조건부.** `ー`→`-` 를 무조건 접으면 `コード`→`コ-ド` 가 되어
  **二次元コード 앵커 자체가 깨진다** — 그게 이 픽스처의 유일한 코드 탐지 경로였다.
- 세그먼트 분리 임계 = 페이지 폭 10%. 레이블→값 간격(~80px)보다 넓고 칸→칸(~140px)보다 좁다.
- 분류는 **가중 합**이지 단일 키워드가 아니다 — OCR 은 어떤 줄이든 뭉개는데 **뭉개지는 레이블이
  매번 다르다**(`保険者番号` 가 5개 중 3개에서 `RREES`/`REEES`/`WREEES`).
- 欄(備考欄·臓器提供欄)은 **그려진 사각형**으로 찾는다(150px 연속 잉크 가로줄 + x범위 ±12px).
  비어 보이는 칸이 바로 흐린 손글씨가 숨는 자리다. 세 欄 전부 픽셀 단위로 정확.
- **二次元コード: 라벨은 신원, 픽셀은 경계.** 라벨 클러스터를 정사각으로 키우면 라벨이 블록
  한쪽 구석에 있어 띠가 어긋난다. 레이블 없는 블록은 **candidate 로만** 낸다(진짜 QR 더미가
  §4 로 금지돼 골든 커버리지가 없다 — 검증 안 된 탐지가 스스로 픽셀을 지우면 안 된다).

### ⚠ 숫자는 통과시키고 **그림이 잡은 결함 2건**
1. `保険者番号` 선두 숫자가 띠 밖으로 남았다 — Tesseract 가 ` 99221010` 처럼 **앞 공백 포함**
   문자열을 주는데 bbox 는 잉크 박스다. 공백을 세면 문자 폭 계산이 한 칸 밀린다. **피복률 96%.**
   → `ocrCanvas` 에서 `w.text.trim()`.
2. 二次元コード 띠 어긋남 — **피복 80%, 60% 게이트 통과.**

⇒ **피복률은 "얼마나" 를 말하지 "어디" 를 말하지 않는다.** `test/safe/render.mjs` 를
고정했다(게이트 아님, 육안 검증 전용).

### 4. 골든이 공허하지 않은지 **변이로 확인**
구조 폴백 제거 → 4건 실패 / 세대원 규칙 제거 → 13건 실패 / `keep`→`recommend` → 4건 실패.
⚠ **`JP_COVERAGE`(검사한 박스 수가 0이면 실패) 가드는 추가 직후 내 자신의 집계 결함을 잡았다**
— `mask:["ALL"]` 경로가 카운터를 안 올리고 있었다. `canonical_sweep.rb` 가 sitemap 이 죽으면
0건 검사하고 통과하던 것과 **같은 모양**을, 그 교훈이 적힌 저장소에서 또 만들 뻔했다.
`JP_CLEAR` 도 같은 이유다 — `require_banded` 만 있으면 "이 목적에서 띠가 켜진다"는 단언이
**모든 목적에서 켜져 있어도** 통과한다.

### 5. 남은 공백 (다음 런)
- **레이블 없는 QR**: 픽스처·유닛 둘 다 없음 → candidate 고정.
- **電話·FAX / 住所 자동 분기**: 알파 4종에 전화번호가 없고 住所 는 전부 `keep` →
  `jp_units` 로만 고정했다. **실제 문서에서 박스로 변환되는 경로는 한 번도 실행된 적이 없다.**
- **多ページ 일본 문서**: 픽스처가 전부 1페이지. 2페이지 이후 분류 상속 경로 미실행.
- 운영 메모: `test/sw/node_modules` 는 `ln -s ../safe/node_modules` 로 공유한다(README 갱신).

## SafeFile JP-1 S3b — 교차검증 지적 반영 (2026-10-21)

브랜치 `main`. **미배포.** 프로덕션 DB 미접촉.
보고 [`docs/jp/s3b_report.md`](docs/jp/s3b_report.md) · 전체 로그 [`docs/jp/s3b_golden_result.md`](docs/jp/s3b_golden_result.md)
입력(Codex 원문) [`docs/jp/codex_review_s3_2026-10-21.md`](docs/jp/codex_review_s3_2026-10-21.md)
다음 라운드 프롬프트 [`docs/jp/codex_prompt_s3b.md`](docs/jp/codex_prompt_s3b.md)

**골든 389 → 484, 0 실패.** 매트릭스 대조 **188 triple 일치**. SW 하네스 9/9 유지.

### 닫은 것 — 전부 「밖에서 보면 정상과 구별되지 않던」 실패
1. **분류 실패가 무경고로 JP 보호를 껐다.** 이제 ① score ≥ min = 확정 ② 제목만 읽힘 =
   `low`(auto·gate 전부 recommend 로 강등) ③ 일본 공문서 특징만 있음 = **차단성 경고 배너**.
   경고는 `jpBar` 와 독립이다 — 존재 이유가 "바가 안 뜨는 경우"에 보이는 것이기 때문.
2. **레이블 없는 사각 블록이 기본 출력에서 가려졌다.** 주석은 "never automatic" 인데
   `recommend` 의 기본 mode 는 `no` 였다 — 주석과 동작이 반대. 이제 `optional`/`ok`.
   ⚠ 실측: `mynumber_card/back` 의 QR 은 실제로 이 경로를 탄다(라벨 미인식). 뒷면은
   `back_all` 이 덮어 결과가 같지만, **資格確認書 에서 라벨을 잃으면 QR 이 후보로만 남는다.**
3. **다중 페이지에서 1페이지가 전 페이지의 규칙을 정했다.** 양면 카드 PDF 의 결과가
   **스캔 순서로 뒤집혔다**(表→裏: 裏에 띠 없음 / 裏→表: 表까지 전면 띠). finding 마다
   `doc·side·page` 를 저장하고 페이지별로 판정한다.
4. **「その他」 체크 하나가 법적 띠를 지웠다.** `back_all`·`qr` 는 타입이 `other` 다.
   `e.legal` 플래그 + `isOn` 분기 + 전용 그룹 「法令・提出先ルール」. 해제는 개별 항목에서만,
   해제 시 경고. **전체 공개**는 법적 띠를 건드리지 않고 **전체 비공개**는 건드린다(피복만 는다).

### 정본이 단일 소스가 됐다 — `test/safe/check_matrix.mjs` (신규)
페이지는 빌드 단계가 없어 `JP_RULES` 는 JSON 정본의 **손으로 쓴 거울**이다. 그래서 어긋남을
읽기 과제가 아니라 **테스트 실패**로 만들었다: JSON 에서 `(doc, field, purpose) → level` 을
파생 → `index.html` 에서 표를 잘라내 실행 → **어느 쪽에라도 있는 모든 triple** 대조 →
불변식 **`verified:false ⇒ auto·gate 금지`** 강제 → 비교 횟수 <100 이면 추출이 깨진 것으로 실패.
`run.mjs` 가 맨 먼저 호출한다. 주요 레벨 변경: `免許証番号` → identity_submit **keep**,
`住民票コード` → **recommend**(출처 없음), `本籍/筆頭者` → 2목적 **optional** 환원,
**미명시 조합은 `null`** (UI 에 내지 않음 — 「침묵은 허가가 아니다」).

### 個人番号 해제는 드롭다운만으로 되지 않는다
`個人番号手続` 선택 **+ 확인 체크박스**(「提出先が法定の個人番号関係事務を行う」)가 모두 있어야
`back_all·my_number·qr` 의 띠가 풀린다. 미확인이면 `keep` → **`gate`** 로 되돌아간다.
목적을 바꾸면 체크는 항상 초기화된다. 裏面 안내 문구도 4개 언어에서 완화했다(「~できません」→
복사·보관의 **제한**과 제출처 조건). 체크디지트 출처를 **e-Gov 관련 명령 제5조**로 정정
(산식은 원래 옳았다) + 나머지 0·1 경계 벡터 추가.

### ⚠ 하네스: 피복률은 「어디를」 말하지 않는다
`保険者番号계열·個人番号·住民票コード·免許証番号` 는 60% 면적 대신 **잉크 연결요소별 99% 피복**을
본다. 성분 0개면 실패(공허한 통과 방지). **실효성 확인**: `ocrCanvas` 의 `w.text.trim()` 을 빼
직전 라운드가 기록한 그 결함을 되살리니 `8 comp, worst 74%` 로 실패 — 같은 상태에서 60% 게이트는
통과한다. 그 외: 기대 키가 픽스처에 없으면 **FAIL**(+ `gen.py` 가 variant 별로 기대표를 가지치기),
`keep:'all'` 전 박스 열거(**단 도달 케이스 없음**), `require_banded` 가 `located ∧ isOn` 까지,
**「예상하지 않은 자동 엔티티 0」 allowlist**(총수 상한은 맞는 5개와 맞는 2개+틀린 3개를 구별 못한다).

### 변이 프로브 6건 — 새 단언이 공허하지 않음을 전부 실측
`isOn` 이 legal 무시 → 2실패 · OCR trim 제거 → JP_INK 실패 · 확인 없는 게이트 → 2실패 ·
unlabelled 를 recommend 로 → 3실패(기본 출력 피복 100%) · `jumin_code` 를 auto 로 → AUTO_SET 실패
+ 매트릭스 3건 · `back_all` 을 1페이지 class 로 → **양방향 4실패**.

### 이번 라운드에 스스로 잡은 하네스 결함 2건
- **`__allCatsOff()` 가 전역을 흘렸다.** `catEnabled` 는 `resetAll()` 도 파일 재로드도 복원하지
  않는 모듈 상태라, 카테고리를 끈 뒤 문서만 다시 읽으면 **그 뒤 모든 문서가 OFF 로** 돈다.
  첫 전체 런에서 14건이 빨개졌고 **그중 11건은 다른 문서의 멀쩡한 단언**이었다. 스냅샷/복원 쌍으로 교체.
- **`pages.length > 0` 은 「로드 완료」가 아니다.** 페이지는 한 장씩 push 되므로 2페이지 OCR
  문서에서는 2페이지가 Tesseract 안에 있을 때 true 가 되고, 그 뒤 측정은 **문서 절반**을 설명한다.
  완료 신호를 `#docWrap` 노출로 바꿨다.

### 남는 공백 (s3b_report §5 백로그 B-1~B-15)
동적 세그먼트 임계 · `headOnly` 잡음 클래스 · 世帯連記式 · 欄 프레임 세로변 검증 · 패딩 clamp ·
PDF 객체그래프 · ICC 해시 allowlist · PNG 청크 파서 · 적응 배경 · `geometry:false` 기하 검증 ·
電話·FAX 통합 경로 · `keep:"all"` 도달 케이스 · 번호군 전수 무효화 · 변호사 검토 ·
**`発行日`·`発行者` 탐지 규칙**(매트릭스는 keep 이라고 선언하는데 경고가 생성될 수 없다 — 죽은
규칙이지만 지우면 정본이 침묵하게 되므로 「既知の空白」으로 남겼다).

## SafeFile JP-1 S3c — 2차 교차검증 AMBER 4건 + 하네스 공허 경로 3건 (2026-10-21)

브랜치 `main`. **미배포.** 프로덕션 DB 미접촉. **배포 전 마지막 라운드.**
보고 [`docs/jp/s3c_report.md`](docs/jp/s3c_report.md) · 입력 [`docs/jp/codex_review_s3b_2026-10-21.md`](docs/jp/codex_review_s3b_2026-10-21.md)
다음 라운드 프롬프트 [`docs/jp/codex_prompt_s3c.md`](docs/jp/codex_prompt_s3c.md)

**골든 484 → 533, 0 실패.** 정본 대조 **188 triple + 10 legal pair**. 변이 프로브 **7/7 실측**.

### 닫은 것 — 네 건 다 「밖에서 보면 정상과 구별되지 않던」 실패
1. **분류 불가 페이지가 남의 규칙으로 통치됐다.** `jpClassify(pi) || cls0` 는 양면 카드의
   스캔 순서는 고쳤지만 통장 사본·세금 통지서가 같은 PDF 에 묶이면 **카드 규칙**을 받았다 —
   누출이 아니라 **제출 증빙의 훼손** 방향. 이제 분류 불가 = `null` = JP 규칙 0개이고,
   예외는 「직전 페이지가 그 카드의 `front` ∧ 이 페이지에 `JP_BACK_ANCHORS[doc]` 앵커」를
   **동시에** 입증한 裏面뿐(`viaBackAnchor` 로 추적). `臓器提供` 는 マイナ에서 **앞면** 항목이라
   카드 앵커 목록에서 의도적으로 뺐다.
   ⚠ 기존 두 케이스(表→裏·裏→表)는 두 페이지가 **각자 분류되므로 승격 경로를 밟지 않는다** —
   그래서 「back.png 를 y≥100 으로 크롭해 타이틀만 제거」와 「front + `testdocs/1_text.pdf`
   1페이지(pdf.js 렌더)」를 런타임 합성해 양방향을 고정했다. 새 바이너리는 커밋하지 않았다.
2. **경고 두 개가 반대말을 하면서 한 문구를 썼다.** `lowconf` 는 자동 레벨을 `recommend` 로
   강등하는데 `recommend` 의 기본 mode 는 `'no'` 다 — **띠가 출력에 들어간다.** 그 상태에
   「自動黒塗りは適用していません」를 붙였다. 이제 `lowconf`(앰버·확인 요구)와
   `unclassified`(적색·정지)가 별 문구·별 스타일이고, **4개 언어 각각 자국어만** 쓴다.
   `JP_SUSPECT_RE` 에서 **和暦 단독 조건 제거** — 일본어 이력서·청구서가 전부 和暦을 실으므로
   경고가 「이 텍스트는 일본어다」를 뜻하게 되고, 그러면 사용자가 무시하는 법을 배운다.
   하네스는 **배너 문구**와 **실제로 칠해진 띠 수**를 함께 단언한다(가시성만 보면 문구가
   출력과 반대여도 통과한다 — 그게 이 결함이었다).
3. **가리지 않겠다고 약속한 필드가 가려야 하는 번호를 숨겼다.** 두 레이블-값 쌍이 한 세그먼트가
   되면 `保険者番号` 는 머리에 없어 자기 규칙으로 앵커할 수 없고 구조 폴백에 맡겨지는데,
   폴백은 `used` 가 아닌 span 만 claim 한다. `保険者名`(keep, `last:true`)이 tail 전체를
   `used` 로 찍어 그 폴백을 침묵시켰다. ① 값의 끝을 **같은 세그먼트의 다음 알려진 레이블
   직전**으로 제한(모든 값 경로) ② keep 전용 필드는 **4자리 이상 숫자 런**을
   `used`·boxes·value **어디에도** claim 하지 않는다. **두 겹 다 load-bearing 임을 변이로 확인**
   (①만으로는 이웃 레이블이 OCR 로 깨진 케이스가 안 닫힌다 — 이 서식에서는 그게 측정된 정상).
   ⚠ 교환: keep 필드 **자기 값**의 4자리 이상 숫자 런이 폴백에 잡힐 수 있다(과잉 마스킹 방향).
4. **출처를 확보하지 못했다고 스스로 적은 규칙이 법령 금지를 단정했다.** `JP_LEGAL_FIELDS` 가
   평평한 필드명 Set 이라 `verified:false` 인 `住民票コード` 가 법령 그룹에 들어가 있었다.
   이제 정본의 **명시 속성 `legal_enforcement: true`** 에서 **문서별** 집합(`JP_LEGAL`)을 파생하고,
   `check_matrix` 가 ① `verified:false ⇒ legal_enforcement 금지` ② **집합 동등**(부분집합 아님)
   ③ `legalPairs < 8` 이면 실패 를 강제한다. 확인 체크박스 문구는 **사용자가 읽을 수 있는 종이**
   에 대한 사실로 교체(「提出先の案内で、個人番号（裏面）の提出が明示的に求められていることを
   確認しました」), 법적 효과 표현은 전부 「制限される**場合があります**」 수준으로.

### 하네스 공허 경로
- **빈 배열의 `.every()` 는 `true`** (실측) — 「labelled code still banded」가 레이블 QR 탐지가
  통째로 사라져도 녹색이었다. `length > 0` 선행 + `NO LABELLED CODE FOUND` 로 구별.
- **부분집합 allowlist 는 「맞는 다섯」과 「전혀 없음」을 구별하지 못한다.**
  `required_auto`(집합 동등, 결정적 입력 16케이스) / `allowed_auto`(부분집합, 회전·흐림 JPG 3케이스).
  ⚠ **전환 직후 `kouki.png` 의 유령 멤버(`hihokensha_bango` — 한 번도 발화하지 않는다)를 즉시
  잡았다.** 부분집합 검사에서는 「허용된 여분」으로 조용히 통과하던 항목이다.
- **`__allCatsOff` 에 `try/finally`.** 전체 런에 예외를 주입해 측정: **8 LOAD 에러로 격리,
  나머지 398 단언 전부 녹색**, 복원 행 8/8 `restored`.

### UI — 「이 목적의 규칙이 없습니다」
매트릭스가 미명시 조합을 `null` 로 두므로 목적을 바꾸면 목록이 **통째로 빌 수 있다**
(`資格確認書 + 個人番号手続`). 무설명 공백은 「고장난 도구」로 읽히고 그 다음 해석은
「가릴 것이 없었다」다. 조건은 **「현재 목적에서 JP 엔티티 0개」** — `JP_RULES` 기준의
「규칙 0개」는 `JP_EXTRA`(address_loose·tel)가 네 목적을 다 덮어 **영원히 참이 되지 않는다**.
이것은 **발견 6 의 완화이지 해결이 아니다**(미명시 조합을 「탐지됨·정책 미확정·기본 OFF」로
노출할 것인가는 제품 결정 — s3c_report §5 백로그).

### 남는 공백 (s3c_report §5)
이번이 만든 것: 裏面 승격이 **페이지 크기·비율·연속성을 보지 않는다**(C-1) ·
**page 0 분류 불가면 전 페이지 JP OFF**(C-2, S3b 이전부터) · A-3② 의 과잉 마스킹 경로 골든 미커버(C-3).
S3b 발견 중 백로그: 4(30페이지 렌더 p50/p95 미계측) · **6**(미명시 조합을 숨기는 정책) ·
**7**(출처 없는 must_keep 의 정본 승격 — 제3의 「제출처 확인 필요」 레벨이 필요) ·
8(`発行日`·`発行者` detector 부재 + 대조기가 사람 읽는 `field` 를 무시) ·
9(대조기의 문자열 슬라이스·완전성 경계) · 13(`inMask` 동어반복) · 15(`__inkCover` 임계값) ·
17(합성 테스트는 정책 배선만) · 19·20·21(법적 그룹 UI·QR 신뢰도) · 22(`applies_to` 수동 갱신) ·
23(`keep:"all"` 미도달) · 24(variant 가지치기). **변호사 검토는 여전히 없다.**

### JP-1 이슈 로그

**2026-10-21 · 결정됨(사람) · 법률 검토는 미해결 — 카드 더미를 공개 저장소에 둔다**
`chaop2026/docpack` 은 **PUBLIC** 이다(`gh repo view` 확인). 전략 v2 §4 는
「개별 고해상 카드 파일은 공개 배포 금지 / 법률 검토 전까지 카드 더미는 내부 테스트 전용」
이라고 적고 있다. 커밋하면 그 보류를 사실상 해제하는 셈이다.
**2026-10-21 사람 결정: 더미는 이대로 공개 저장소에 둔다.** 아래 위험 평가는 유지한다 —
결정이 위험을 0으로 만들지는 않는다.

**그럼에도 커밋한 이유**와 **줄인 범위**:
- §4 의 *생성* 안전조건은 전부 충족한다 — 와이어프레임형, 전면 「見本・架空・本人確認に
  使用不可」 워터마크, 公安委員会名·관인·로고·실제 QR·IC 표시 전부 없음, 체크디지트 불일치,
  실존 불가 주소, 架空 인명, 사진 없음(빈 회색 패널).
  ⚠️ **~~오용 가치는 사실상 0이다~~ → 오용 위험은 낮으나 0이 아니고, 미해결이다**
  (2026-10-21 교차검증 7-1·7-2 지적을 받아 정정). 근거: ① 무효화가 **전수가 아니다** —
  `mynumber_invalid()` 와 면허번호만 의도적으로 규격을 깨고, `hokensha()`·記号/番号/枝番·
  고정 `住民票コード` 에는 유효성 부정 로직이 없다(코드 확인). ② 우편번호 `999-99xx` 가
  실제 미할당인지 검증하지 않았다. ③ 공개 git 이력은 영구 복제 가능하고 고해상 카드형
  이미지는 편집 재료 가치가 남는다. 일본 형법 155조는 `行使の目的` 이 요건이라 이 픽스처
  자체가 곧 위법이라고 단정할 근거는 없고, GitHub AUP 가 이를 명시적으로 금지한다고
  확인할 수도 없다 — **둘 다 "낮음" 이지 "0" 이 아니다.**
  남은 제약은 **"일본 변호사 검토 전까지 보류"** 이며, 그 검토는 **아직 없다**.
- 골든 하네스가 그 파일 없이는 **돌지 않는다.** `gen.py` 는 결정적이지만 Linux + Noto CJK
  전제라 이 맥에서 재생성이 불가능하고, 재생성하면 PIL 버전 차이로 **박스 좌표가 흔들려
  모든 spec 이 깨진다.**
- **줄인 것**: `docs/jp/jp_fixtures_alpha4.zip`(6.1MB, 같은 바이트의 중복)은 **커밋하지 않고
  gitignore** 했다 — zip 은 기술적 목적이 없고 모양 자체가 재배포다.
  `test/safe/fixtures/jp/README.md` 에 §4 상태를 명시했다.

→ ~~**사람이 결정할 것**: (a) 이대로 둔다 / (b) 픽스처를 별도 비공개 저장소로 옮기고
submodule 로 받는다 / (c) 변호사 검토 후 재판단.~~
**(2026-10-21 결정: (a) 이대로 둔다.)** 남는 후속 작업 두 가지:
- 모든 번호군에 명시적 무효 검사를 넣거나 문자를 섞어 ①을 닫는다 (gen.py, 재생성 필요 →
  좌표가 흔들리므로 spec 재생성과 한 묶음).
- 일본 변호사 검토. 그때까지 「오용 가치 0」 이라고 쓰지 않는다.

## SafeFile JP-1 S3d — Codex 3차 잔여 AMBER 1건 (2026-10-22)

브랜치 `main`. **미배포.** 프로덕션 DB 미접촉. **배포 전 수정 종료.**
보고 [`docs/jp/s3d_report.md`](docs/jp/s3d_report.md) · 입력 [`docs/jp/codex_review_s3c_2026-10-21.md`](docs/jp/codex_review_s3c_2026-10-21.md)

**골든 533 → 557, 0 실패(166초).** 정본 대조 188 triple + 10 legal pair 유지. SW 9/9 유지.

### 단어는 면(面)의 증거가 아니다
S3c 의 裏面 승격은 「직전 페이지가 그 카드의 front」 ∧ 「`JP_BACK_ANCHORS[doc]` 가 맞는다」
였고, 두 번째 겹이 `/個人番号|マイナンバー|二次元コード/` 였다. `二次元コード` 는 카드 고유도
뒷면 고유도 아니고(資格確認書·택배 전표·QR 안내 전단에 다 있다), `マイナンバー` 는 이 카드에
**관해 쓰인 모든 안내문**에 있다. 그 앵커는 「이 페이지는 그 카드의 뒷면이다」가 아니라
**「이 페이지는 그 카드를 언급한다」**를 입증했고, 승격된 페이지는 **전면이 띠로 덮인다** —
출력은 제대로 가린 것처럼 보이는데 사라진 것은 제출해야 할 안내문이다.

**수정 — `JP_BACK_PROOF`**: 카드마다 「레이블 ∧ 그 면 고유 값 형식」 둘을 함께 요구하고,
값 형식은 **골든이 이미 돌리는 그 탐지기**로 확인한다(병렬 파서를 두면 본 탐지기와 조용히
어긋난다). マイナ = `個人番号`/`マイナンバー` 가 세그먼트 머리 ∧ 그 뒤 **12자리**
(`jpDigitSpan`; 전각은 NFKC 가, 4-4-4 는 구분자 허용이 처리 — 카드가 실제로 그렇게 인쇄한다).
免許証 = `備考欄`/`臓器提供` 계열 레이블 ∧ **그려진 欄 프레임**(전단은 단어를 인쇄할 수 있지만
150px 연속 잉크 사각 프레임은 인쇄하지 않는다). **資格確認書·住民票은 항목이 없는 것이 맞다** —
양면 카드가 아니고 `jpClassify` 가 side 를 부여하지 않는다.

### 음성 테스트는 **논리곱의 겹마다** 하나씩
양성 케이스(`表 + 裏(タイトル切除)`)는 **옛 앵커에서도 새 증명에서도 통과**하므로 이 결함을
잡지 못한다. ① `二次元コード` 안내문 + 12자리 참조번호 = **값만 있고 레이블 없음** ·
② `マイナンバー` 안내문, 12자리 없음 = **레이블만 있고 값 없음** · ③ ① 을 흰 캔버스에 그려
front.png 와 PDF 합성 → **OCR**(실제 스캔 경로). ①② 는 앱 자신의 텍스트 렌더러로 만들어
OCR 변수를 뺐고, 빈 줄 60개로 페이지를 끊되 **2페이지인지 단언**한다. 새 바이너리 커밋 0건.

⚠ **`JP_NEG_VACUOUS`**: 「승격되지 않았다」는 **옛 앵커 단어가 애초에 페이지에 없을 때도 참**
이다(크롭 실수·OCR 실패·렌더러 변경). 그래서 옛 정규식이 2페이지 텍스트에 **여전히 맞는다**를
함께 단언한다 — 이 줄이 녹색인 동안에만 나머지가 새 규칙에 대한 증거다. 3케이스 전부 `match`.

⚠ 안내문에 `マイナンバーカード` 를 **쓸 수 없다**: 그 문자열만으로 4점이라 페이지가 **스스로
카드로 분류되고** 승격 경로에 도달하지 않는다(그래서 지적서 예시 문구를 그대로 쓰지 않았다).
산문의 카드 이름이 분류를 발화시키는 것은 **별개의 공백** → s3d_report §5 D-1.

### 변이 프로브 (실측) + 免許証 경로 도달성
앵커를 옛 정규식으로 되돌리면 **542/557, 15 실패** — 세 음성 케이스가 각 5건씩,
`JP_BACKANCHOR` false→true, `JP_ATTACH_CLEAR` ≤10%→**100%**(안내문 전면 피복). 원복 후 557/557.
**免許証은 조였으나 그 승격 경로는 돌지 않는다**(실측): 타이틀을 크롭한 免許証 뒷면은
`備考欄`+`臓器提供`+`提供意思` = 4점으로 **스스로 분류되고**, side 판정에 뒷면 증거가 없어
`front` 로 떨어진다. 동시에 `jpBackProofFrame` 은 그 페이지에서 **true** — 과잉 조임이 아니다.
그래서 免許証 양성 케이스를 골든에 **넣지 않았다**(넣으면 「뒷면을 front 로 읽은 상태」를
고정한다). 띠 자체는 유실되지 않는다 — `JP_REGION_LABELS` 는 side 로 필터하지 않는다. → §5 D-2.

## SafeFile JP S6 — 랜딩 3페이지 + 파일럿 폼 + 익명 계측 (2026-10-22)

브랜치 `main`. **미배포·미푸시.** 프로덕션 DB 미접촉.
보고 [`docs/jp/s6_report.md`](docs/jp/s6_report.md) · 문안 정본 [`docs/jp/jp_landing_copy_2026-10-22.md`](docs/jp/jp_landing_copy_2026-10-22.md)
지시서 [`docs/jp/s6_prompt.md`](docs/jp/s6_prompt.md)

**골든 557/557 유지 · SW 9/9 유지 · `bin/rails test` 159→188 runs / 1218→1414 assertions / 0 failures
· 신규 라이브 하네스 `test/safe/jp_landing_check.mjs` 102/102 · canonical sweep 6/6
· rubocop 86건(베이스라인과 동일, 신규 0) · brakeman 6건(동일).**

### 페이지를 만드는 것만으로 주소가 둘이 된다
`public/<dir>/index.html` 이 생기면 `ActionDispatch::FileHandler` 가 **슬래시 없는 철자에도 같은
바이트를 200 으로** 돌려준다 — `/safe/` 를 GSC 에서 「사용자가 선택한 표준이 없는 중복 페이지」로
만든 그 구조다. 랜딩 3개를 `CanonicalPathRedirect::DIRS` 에 넣고, 목록을 **파일시스템에서 파생해
집합 동등으로 대조하는 테스트**를 뒀다(`Dir.glob("public/**/index.html")`). 다음에 랜딩을 더
만들고 DIRS 를 잊으면 테스트가 먼저 실패한다(변이 확인: 1개 제거 → 2건 실패).
`/safe/jp` 는 **일부러 DIRS 에 없다** — index.html 이 없으므로 넣으면 셋 중 하나에 네 번째 주소를
발명하는 셈이고, 아무것도 없는 주소의 정직한 답은 404 다(`/safe/jp/` → 301 → 404, 수용).

### hreflang 0개 — `/about` 과 같은 판정
한 URL = 한 일본어 문서이고 영어는 **그 URL 안**의 접이식 블록이다. `en` 알터네이트는 존재하지
않는 URL 을 가리키고 `x-default` 자기참조는 「특정 언어를 대상으로 하지 않는다」는 거짓이다.
`?lang=en` 토글을 쓰지 않은 이유도 같다 — 같은 내용이 두 주소로 서빙되는 상태를 새로 만든다.
(`/safe/` 는 반대 경우 — 1 URL × 4언어 클라이언트 전환 — 이라 x-default 를 갖는다.)

### 계측: 저장 가능한 모양을 모델이 단독으로 정의한다
`SafeEvent::NAMES`·`KEYS`·`VALUES` 가 정본이고 컨트롤러·집계 레이크·테스트가 전부 그것을 읽는다.
**키가 하나라도 화이트리스트 밖이면 이벤트 전체를 거부**한다(422, 부분 저장 없음) — 일부만 저장된
행은 「일어나지 않은 일」을 데이터처럼 기록하고, `sendBeacon` 은 응답을 읽지 않으므로 조용한
누락이 양쪽에서 보이지 않는다. 컨트롤러가 **클라이언트가 보낸 키를 그대로** sanitize 에 넘기는
것도 같은 이유다(알려진 키만 걸러 넘기면 드리프트가 성공으로 보인다).
**`request.remote_ip` 를 읽지 않는다** — 저장도 해시도 레이트리밋 키도 아니다. 해시한 IP 도
결국 방문자 식별자다. 대신 엔드포인트 **전체**에 분당 600건 상한을 둔다(누가 하는지 구별할 수
없는 것이 이 교환의 핵심이라 상한을 넉넉히 뒀다). 테이블 컬럼이 `id,name,props,created_at`
**넷뿐**임을 테스트가 단언한다 — 스타일이 아니라 `/safe/` 와 랜딩의 약속이다.

### honeypot 은 성공과 구별되지 않아야 하고, 빈 값은 스팸이 아니다
채워진 `website` → 행을 쓰지 않고 **201**(구별 가능한 거부는 스팸 스크립트에 공짜 오라클).
⚠️ 빈 문자열을 스팸으로 세면 **모든 진짜 신청이 성공 메시지와 함께 버려지고** 증상은
「관리 목록이 안 늘어난다」뿐이다 — 전용 테스트를 뒀다. IP 당 10분 3회 상한은 **캐시 키에만**
IP 를 쓰고 DB 에는 어떤 형태로도 쓰지 않는다.

### 🔴 라이브 중 잡은 실제 결함 ② — 계측 엔드포인트가 1년짜리 쿠키를 심을 수 있었다
**교차검증 프롬프트를 쓰다가 찾았다.** 실측(수정 전): `POST /api/safe_events?locale=ja`
→ `204` **+ `Set-Cookie: locale=ja`, 만료 1년**. `ApplicationController#set_locale` 은
`params[:locale]` 이 있으면 쿠키를 쓰는데 **`params` 에는 쿼리스트링이 포함된다.** 우리는
「이 라우트에 `:locale` 세그먼트가 없다」만 확인하고 쿼리스트링을 보지 않았다 — 「쿠키를
쓰지 않는다」는 문서의 주장이 코드에서 **거짓**인 채로 커밋됐다. 방문자를 식별하지 않겠다는
것이 이 엔드포인트의 존재 이유이므로, 성질이 아니라 약속이 깨진 것이다.
→ `Api::BaseController`(신규)가 `/api/` 세 엔드포인트 전부에서 `set_locale` 과 CSRF 를 skip.
`/api/` 밑에 로케일 의존 출력은 하나도 없다(safe_scan 프롬프트는 하드코딩, jp_pilot 은 필드
이름만, safe_events 는 본문 없음) — 이 필터가 여기서 하는 일은 **부작용뿐**이었다.
회귀 테스트 2개: 쿠키 0 **+ `/ja/faq` 는 여전히 쿠키를 심는다**(두 번째가 없으면 언어 전환이
통째로 망가져도 첫 번째가 잘못된 이유로 녹색이 된다). 변이로 확인 — skip 을 빼면 1건 실패.

### ⚠ 라이브 중 잡은 실제 결함 ① — 검증 실패 메시지가 조회 흔적을 신청자에게 보냈다
실측: `{"ok":false,"errors":["EmailTranslation missing. Options considered were: …"]}`.
`ko.yml` 의 `activerecord.errors.messages` 에 `invalid`·`too_long` 이 없었다(2026-09-18 에
presence·uniqueness·inclusion 만 넣었다). 두 겹으로 고쳤다: ① 컨트롤러가 **필드 이름만**
돌려주고 일본어 페이지가 자기 문구를 렌더한다 → **서버 로케일이 일본어 페이지에 나타날 경로를
없앴다**(사례가 아니라 종류를 닫았다) ② ko.yml 에 `invalid`·`too_long`·`too_short`·
`not_a_number` + `jp_pilot_request` 속성명 추가 — 신청자는 안 보지만 **로그와 콘솔은 본다**.

### ⚠ 하네스: `sendBeacon` 의 payload 는 Playwright 가 읽을 수 없다
`postData()` 와 `postDataBuffer()` 가 **둘 다 null** 이다(실측). 처음 하네스는 그것을 `{}` 로
파싱해 「landing_view 0건」으로 빨간불을 냈는데 같은 시점 DB 에는 행이 정확히 있었다.
→ 페이지 안에서 `navigator.sendBeacon` 을 감싸 payload 를 기록하고 원본에 위임하며, payload
만으로는 「페이지가 보내려 한 것」만 증명되므로 **응답 204**(서버 화이트리스트의 동의)를 함께
단언한다. CTA 카운터가 0으로 보인 것은 내비게이션이 실제로 일어나 payload 배열이 새 문서에서
빈 채로 다시 만들어진 것 — 캡처 단계 `preventDefault` 로 **내비게이션만** 취소했다.
**「측정 대상이 사라져서 0」과 「발화하지 않아서 0」은 밖에서 같아 보인다.**

### `/safe/index.html` 최소 변경 (탐지 로직 무변경)
`SF_PARAMS`(`?lang`·`?purpose`·`?from` 읽기 전용) · `detectLang()` 에서 **명시적 `?lang=` 이
localStorage 보다 앞선다**(랜딩은 일본어 전용인데 몇 달 전 선택으로 떨어지면 안 된다) ·
`JP_PURPOSE0` 가 `JP_STATE0()` 에 들어가 **`resetAll()` 이후에도 목적이 유지된다**
(「다른 문서」는 입찰 담당자가 가장 많이 누르는 버튼이다) · `sfEvent()` 호출 6곳.
`download` 이벤트는 **분류된 JP 문서일 때만** `purpose` 를 보낸다 — `jpState.purpose` 는 JP
프리셋이 돌지 않아도 기본값을 가지므로 무조건 보내면 목적 통계가 부풀어진다.

### 정본 문안에 **더한** 것 3곳 (문구 변경 아님, 사람 확인 대상)
① 세 페이지에 `提出先の指示を必ず確認してください。` 1줄(정본 공통 규칙이 요구하는데 페이지 1 엔
`※ 提出先の指示が優先です` 만 있었다) ② `ai-mae` 의 구매 CTA 밑에 `※ 決済は準備中です。` 1줄
(**Stripe JP 상품이 아직 없다** — 아무 데도 가지 않는 구매 버튼이 더 나쁘다고 판단, 메일 링크로 연결)
③ 폼 성공·실패 안내 문구. 정본과 페이지가 갈라진 상태로 두지 않는다.

### 남는 공백 (s6_report §5)
Stripe JP 상품 2개 · GSC JA 랜딩 등록(배포 후) · `purpose` 이벤트가 init 때 `doc_class:"none"`
으로 1건 남아 「드롭다운 변경」과 구별되지 않음 · `safe_events` 보존 기간 정책 없음 ·
전역 상한이 가해자를 구별하지 못함(엣지에서 막을 일) · 프로덕션 SMTP 실제 발송 미확인 ·
`jp_pilot_requests` 에 「선착 10사」 마감 처리가 없음.

## SafeFile JP S7 — 콘텐츠 파이프라인 + 첫 3편 (2026-10-22)

브랜치 `main`. **미배포·미게시·미푸시.** 프로덕션 미접촉.
보고 [`docs/jp/s7_report.md`](docs/jp/s7_report.md) · 주제 정본 [`content/jp/topics.json`](content/jp/topics.json)
사용법 [`scripts/content/README.md`](scripts/content/README.md) · 검수 샘플 `docs/jp/s7_samples/`

**33편 계획 · ep01~03 본문(JA/EN) + 산출물 생성 · 파이프라인 가드 4종 실측 발화.**

### `ep` 는 발행 순서이고, 전략 문서의 번호가 아니다
전략 v2 §6 의 30편을 시장결정 v2 §4 대로 손봤다(1·14·20 → 最小化原則 교육형, 신규 3편).
순서를 바꿨으므로 **`ep` = `week` = 발행 순서**로 다시 매기고, 원래 번호는 `src` 로 보관해
재작성 이력을 추적 가능하게 했다. 1층·資格確認書 가 ep01·ep02, **AI 익명화 2편이 ep03·ep04**.
**ep32(일괄처리)는 `blocked_until` 로 빌드 자체를 거부**한다 — 기능이 없는데 홍보하면 안 되고,
목록에서 지우면 슬롯이 조용히 잊힌다.

### 파이프라인이 **하지 않는** 것이 설계의 절반
① **`post_en.md` 를 생성하지 않는다** — 마케팅 문안의 기계 번역은 기계 번역처럼 읽히고, 이
프로젝트의 영어판은 번역이 아니라 병행 재작성이다(랜딩 3페이지와 같은 판단). ② **본문을
고치지 않는다** — 금지어·필수 문장 위반은 보고하고 **아무 파일도 쓰지 않고 exit 1**. 정규식을
만족시키려고 남의 문장을 고치면 아무도 고르지 않은 카피가 나간다. ③ **140자 초과 트윗을
자르지 않는다** — 바이트 경계에서 자른 문장은 저자가 쓰지 않은 문장이고 올라간 뒤엔 안 보인다.
글자 수를 옆에 적어 올리기 전에 보이게 한다.

### 가드가 있는 규칙과 없는 규칙을 구별해 적는다
코드가 강제: 사건명 · `絶対/唯一/必ず安全/防ぎます` · `一括処理` · 필수 문장
`提出先の指示を必ず確認してください`. **정규식으로 판정할 수 없어 사람이 지키는 것**:
1인칭 피해담 금지 · 더미 카드 축소 삽화(긴 변 ≤800px). 이 구분을 보고서 표에 명시했다 —
「규칙이 있다」와 「규칙이 강제된다」가 같아 보이면 안 된다.

### 없는 것은 없다고 적는다
더미가 있는 문서는 골든 픽스처가 있는 알파 4종뿐이다. `doc` 이 그 밖이면
`demo: "failed: no dummy document exists for doc=…"` 가 manifest 에 그대로 남는다(ep03 이 그 경우).
트랙 B 는 `skipped`. 데모가 실패해도 나머지 산출물은 전부 만들어진다 — 네 파일을 다섯 번째
때문에 버리는 파이프라인은 덜 돌게 된다.

### ⚠ 「0.5초 간격 40프레임」을 연속으로 찍으면 문서가 한 장도 안 나온다
촬영풍 JPG 의 Tesseract OCR 에 수십 초가 걸려서, 한 번에 연속 녹화하면 **40프레임 전부가
진행 바**가 된다. 단계별로 쪼개 찍는다(업로드 4 → 탐지 10 → 목적 바 6 → 결과 나머지).
간격·상한은 그대로. 자막은 **페이지 안에 주입한 DOM 바** — ffmpeg `drawtext` 로 넣으면
일본어 폰트 경로를 스크립트에 박아야 하고 문구가 두 군데 살게 된다.

### ⚠ 빌드하다 잡은 자기 결함 2건
1. **정적 서버가 디렉터리 요청에 404 를 돌려줬다.** 첫 실행은
   `setInputFiles: Timeout … waiting for locator('#fileInput')` 로 죽었는데 진짜 원인은
   `/safe/` 가 404 였던 것 — **사실이지만 쓸모없는 메시지**다. 실제 앱은 Static 이
   `<dir>/index.html` 을 돌려주므로, 그러지 않는 하네스는 **에러 페이지를 녹화한 GIF** 를 만든다.
   → 디렉터리를 index.html 로 해석 + **goto 직후 응답 코드와 `#fileInput` 존재를 먼저 단언**.
2. **playwright 는 CJS 라 `import()` 결과가 `.default` 밑에 온다.** 네임스페이스에서 `chromium`
   을 바로 읽으면 `undefined` 이고 실패는 30줄 뒤에 나타난다. 두 해석 경로 모두 정규화한다.
   사본을 만들지 않고 골든 하네스의 설치본을 빌려 쓴다 — 버전이 조용히 갈라지는 것을 막는다.

### 실측
`make_episode.mjs 3`(데모 없음) **5.8초** · `make_episode.mjs 1`(OCR+GIF+MP4) **33.0초**.
ep01 데모 40프레임 GIF 399KB / MP4 218KB. 캐러셀 3편 모두 축소 0회(100%).
본문 산문 614~783자. 변이 프로브 4/4 발화(exit 1 / 1 / 2 / 2).

### 남는 공백 (s7_report §8)
ep04~33 본문 미작성 · 게시 0건(`posted` 전부 false, `status` 전부 draft) ·
**ep05·ep06 의 전자입찰 용량 상한·보조금 정산 요령은 근거 미확인 — 본문 전에 공고 1건 확인** ·
생성물(PNG/GIF/MP4)을 git 에 커밋(33편이면 ~30MB, 무거워지면 GIF/MP4 부터 뺀다) ·
`x_thread` 가 t.co 단축을 고려하지 않음(보수적 방향) · 캐러셀은 Instagram 규격만.

## SafeFile JP S6b — 교차검증 AMBER 7건 (2026-10-22)

브랜치 `main`. **미배포·미푸시·미게시.** 프로덕션 DB 미접촉. **배포 전 마지막 라운드.**
보고 [`docs/jp/s6b_report.md`](docs/jp/s6b_report.md) · 입력 [`docs/jp/codex_review_s6s7_2026-10-22.md`](docs/jp/codex_review_s6s7_2026-10-22.md)

**(a) 6건 수정 · (b) 1건 백로그 · (c) 0건.** `bin/rails test` 188→**208 runs / 1487 assertions /
0 failures** · `jp_landing_check` 102→**107** · 골든 **557/557** · `check_matrix` 188 triple +
10 legal pair · SW **9/9** · canonical sweep **6/6** · rubocop 86·brakeman 6(둘 다 베이스라인
동일, 신규 0) · 변이 프로브 **7/7 실측**.

### 🔴 「JSON 엔드포인트라 CSRF 를 건너뛴다」가 코드에서는 참이 아니었다
「세션을 읽지 않으므로 빌릴 권한이 없다」는 **사실이지만 질문에 답하지 않는다.** 외부 POST 는
권한을 빌릴 필요가 없다 — 남의 페이지의 평범한 HTML `<form>` 이 form-urlencoded 로 보내면
Rails 가 **같은 `params`** 를 만들고 `/api/jp_pilot` 이 행을 쓰고 메일을 보낸다. 응답을 읽을
필요조차 없다. **라이브 실측**: 가드 없이 `form POST → 201`, `jp_pilot_requests 0 → 1`.
스킵의 *근거*는 우리 호출자를 묘사했을 뿐 **우리 수용 범위를 강제하지 않았다.**

→ `Api::BaseController` 에 두 겹. ① **JSON 전용(415)** — 이것이 실제로 구멍을 막는 절반이다.
외부 `<form>` 은 세 enctype 밖으로 못 나가고, fetch/XHR 로 JSON 을 보내려는 순간 CORS 아래다.
② **Origin/Referer 가 있을 때만 호스트 대조(403)** — **부재는 신호가 아니다**(curl·모니터·
sendBeacon). 「있으면 우리 것」이지 「있어야 한다」가 아니다. 전체 origin 이 아니라 **호스트**를
비교한다(프록시 뒤 scheme 불일치 + 외부 요청의 Host 는 브라우저가 **우리** URL 에서 설정한다).
`Origin: null` 은 **부재로 취급하지 않는다** — 브라우저가 「우리 것이 아니다」를 말하는 것이다.
클라이언트는 바꿀 것이 없었다(네 호출부 전부 이미 `application/json`, 확인함).

### 상한이 동시 요청에서는 상한이 아니었다
`read → +1 → write` 는 lost update 다. **Solid Cache 가 프로세스 공유라는 사실은 이 경쟁을
해결하지 않는다** — 공유 스토어가 두 리더에게 같은 낡은 값을 보여주는 조건 그 자체다.
기존 상한 테스트는 요청을 한 줄로 보내므로 깨진 코드에서도 초록이었다.
**실측(20스레드·상한 3)**: 옛 패턴 **6건 통과**, `Rails.cache.increment` **정확히 3건**.
→ `Api::BaseController#over_limit?` 하나로 통일. write-then-increment 춤은 필요 없다 —
세 스토어 전부 원자적이고 키를 만든다(solid_cache `lock_and_write` = `SELECT … FOR UPDATE` /
memory_store `synchronize` / **null_store 는 nil 을 반환**해 역가드 테스트가 계속 유효하다).
그 세 번째를 전용 테스트로 고정했다. 테스트는 **옛 패턴의 재구현을 옆에 둔다** — 두 구현에서
다 통과하는 동시성 테스트는 테스트가 아니다. `/api/safe_scan` 의 같은 패턴은 **테스트가
0개**라 손대지 않았다(백로그 B-8).

### 콘텐츠 가드가 한 면만 보고 있었다
JA frontmatter+본문을 **한 문자열로 합쳐** 검사해서 범위가 코드에서 안 보였고, 실제로 틀렸다 —
**영어 원고와 생성된 X 스레드는 아예 검사되지 않았다.** 그래서 ep01 이 「複数枚をまとめて
読み込めます」/"Several files at once is fine"(파일 입력은 `multiple` 이 없고 `files[0]` 을
읽는다)를 싣고 세 스레드가 필수 문장 없이 나갔는데 **빌드는 위반 0건을 보고했다.**
→ 이름 있는 **다섯 면**(`post_ja.md (frontmatter)`·`(body)`·`post_en.md`·`x_thread.md
(generated)`·`carousel text`). 스레드는 **완성된 파일 문자열**을 본다 — 헤더가 `topics.json` 의
`title_ja` 를 싣고 그 문자열은 frontmatter 가드가 영원히 못 본다. 그래서 `threadMd` 를
가드 **앞**에서 만들고 통과 후에 쓴다(「위반이면 아무 파일도 안 쓴다」 유지).
금지어는 정확한 한 덩어리가 아니라 **우회 표현과 영어**까지: `一括`·`複数(枚|ファイル|PDF)`·
`まとめて…`·`処理記録`·`batch`·`several files`·`processing log`. 필수 문장은 **생성기가 자동
포함**하고 140자를 넘기면 CTA 를 줄이지 않고 **별도 트윗**으로 뺀다.
캐러셀 1080×1350 은 세 곳에 **선언**돼 있었고 디스크와 대조하는 곳은 0곳이었다 → PNG 의
IHDR 을 직접 읽어 manifest `pixels` 에 적고 어긋나면 exit 1.

### 가드가 있는 규칙과 없는 규칙을 README 에서 분리했다
1인칭 피해담 정규식은 **모양 하나**만 잡는 휴리스틱이고, 더미 카드 삽화 ≤800px 은 **발화
지점이 없다**(어느 회차도 삽화를 싣지 않는다). 「규칙이 있다」와 「규칙이 강제된다」가 같아
보이면 안 되므로 `scripts/content/README.md` 에 두 표로 나눴다.

### 법적 효과 단정 6곳 → 허용 수준
`原則(として)制限されています`·`is restricted in principle`·`The law constrains` →
`制限される場合があります`·`may be restricted`. **JSON-LD `acceptedAnswer` 를 본문과 함께**
고친 것이 핵심이다 — 리치 결과는 본문과 다른 문장을 인용할 수 있고, 사람이 읽는 페이지만
완화하면 구글이 단정형을 계속 보여준다. 근거는 신중함이 아니라 **변호사 검토가 없다**는 사실.

### `purpose` 이벤트에 `source: init | user`
랜딩의 `?purpose=` 는 init 중에 `purpose` 행을 하나 쓴다 — **사용자가 아무것도 만지기 전에.**
그 행은 `doc_class:"none"` 까지 달고 있어 사후 구별도 안 됐고, 모든 목적 통계가 프리셀렉트를
선택으로 세고 있었다. 고정 범주 둘만 추가(새 컬럼 0, 자유 텍스트 0). 레이크가 `SafeEvent::KEYS`
에서 섹션을 파생하므로 `purpose × source` 표가 자동으로 생긴다(실측). P11 주석에
**`source=user` 로만 세라**를 적었다 — 표가 생기는 것과 바르게 읽는 것은 다른 문제다.

### self-check
멀티파트 415 테스트가 **틀린 이유로** 초록이었다(`params:` 해시 → 통합 세션이 자기 boundary 를
덧붙여 **Rack 이 우리 필터 전에** 거부; raw 본문으로 교체). 415/403 테스트 11개가 전부
「거부됐다」를 단언하므로 **쓰는 페이로드가 유효한지** 역가드를 뒀다. `over_limit?` 가 죽은
코드일 수 있어 엔드포인트가 **그 키 모양으로 센다**를 단언한다. 라이브 하네스가 429 로
빨개진 것은 내 curl 프로브가 IP 상한을 써버린 것 — **「상한이 깨졌다」와 「상한이 이미
소진됐다」가 밖에서 같아 보인다**(재시작 후 107/107).

### 남는 공백 (s6b_report §6 이 정본, B-1~B-11)
honeypot 타이밍 오라클(**(b)** — 상수 시간으로 만들려면 거부 경로도 DB 를 두드리거나 임의
sleep 을 넣어야 한다; 문서의 주장을 「일반 봇을 속이는 fake success」로 낮추는 것이 먼저) ·
메일 전달 실패의 파생 가시성 · **600/분의 근거 없음** · `/safe/jp/` 301→404 · 캐러셀 폰트 고정 ·
생성물 저장 정책 · `safe_scan` 상한 · 정본 접촉 메일의 `複数PDFを一括処理` ·
**B-10 (사람 확인)**: `nyusatsu` 의 meta/og/twitter description 이 아직 `複数PDFを一括` 이라고
말한다 — 본문은 고쳤지만 검색 스니펫에는 단서가 들어갈 자리가 없다(대안 문안 §5).
**일본 변호사 검토는 여전히 없다.**

## JP-1 이슈 로그 추가 (2026-10-25 · S8)

**`public/safe/작업물/` 정체 확인 필요 (Justin)** — 안에 PDF 1개
(`SafeFile — 문서 속 개인정보, 1분 안에 지우고 공유.pdf`). `public/` 밑이므로 배포되면
`ActionDispatch::Static` 이 `/safe/작업물/<파일명>` 으로 **공개 서빙한다**. 삭제하지 않고
`.gitignore`(기존) + `.dockerignore`(S8 추가)로 **배포 대상에서만** 뺐다 — 제외는 되돌릴 수
있고 삭제는 되돌릴 수 없다. 확인 후 (a) 삭제 / (b) `docs/` 로 이동 / (c) 의도적 공개물이면
`.dockerignore` 에서 제거 중 택1.
