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
- **Deploy note**: Do NOT `source .env` before `kamal deploy` — `.env` has local dev `DB_PASSWORD=postgres`. Production uses `DB_PASSWORD=CurrencyRate2026!` from shell env. Set env vars explicitly: `DB_PASSWORD='CurrencyRate2026!' GMAIL_USERNAME=chaop2@gmail.com GMAIL_PASSWORD=udqjfhqerrnqwiwl kamal deploy`
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

### SVG Cover Image Standard
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

## SEO & Sitemap

- Domain: `https://slimfile.net` (default `BASE_URL` in `app/helpers/application_helper.rb`)
- Dynamic sitemap: `GET /sitemap.xml` → `PagesController#sitemap` → `app/views/pages/sitemap.xml.erb`
- Static fallback: `public/sitemap.xml` (update manually when pages change)
- `public/robots.txt` includes `Sitemap: https://slimfile.net/sitemap.xml`
- Pages in sitemap: `/`, `/compress`, `/pdf`, `/social`, `/about`, `/faq`, `/blog`, `/blog/:slug`
- OG meta, Twitter cards, and JSON-LD structured data are in `app/views/layouts/application.html.erb`
- Per-page meta via `page_meta` helper in `ApplicationHelper`
- Google Search Console verification: `<meta name="google-site-verification">` in `application.html.erb`
