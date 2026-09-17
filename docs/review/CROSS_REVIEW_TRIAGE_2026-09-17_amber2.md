# 교차검증 대조(triage) — AMBER 2건 수정 확인

- 대상 커밋: `6138753` (브랜치 `fix/blog-indexing-signals`, **미배포**)
- 외부 모델 출력 원문: [`CODEX_RESULT_2026-09-17_amber2.md`](CODEX_RESULT_2026-09-17_amber2.md)
- 투입 패키지: [`CODEX_REVIEW_PACKAGE_2026-09-17_amber2.md`](CODEX_REVIEW_PACKAGE_2026-09-17_amber2.md)
- 직전 라운드: [`CROSS_REVIEW_TRIAGE_2026-09-17_indexing.md`](CROSS_REVIEW_TRIAGE_2026-09-17_indexing.md)
- 🔴 **이 세션에서는 새 (a) 를 고치지 않았다.** 아래 2건은 **다음 수정 런의 입력**이다.

## 결론

**직전 라운드의 AMBER 2건은 둘 다 `해소됨` 판정.** 새 지적 2건은 **둘 다 재현 확인**했다.

| 직전 지적 | 판정 | 우리 대조 |
|---|---|---|
| A-1 draft/scheduled 가 색인 가능 | **해소됨** | 동의 — 코드 + 테스트 + 실측 |
| A-2 무프리픽스 URL 이 본문·메타를 협상 | **해소됨** | 동의 — `body_en` 채운 실측으로 확인 |

지적 2건 + Q(R1~R6) 6건 = **8건 전부 분류했다.**

---

## (a) 진짜 문제 — 2건 (둘 다 신규)

### N-1. 영어 정본 페이지의 JSON-LD 가 한국어 URL 을 가리킨다 — **AMBER**

**Codex 지적**: `[논리 오류][확신도 보통]` `/en/blog/:slug` 는 canonical 이 `/en/blog/...` 인데
Article JSON-LD 의 `url` 과 `mainEntityOfPage.@id` 는 `/blog/...` 로 고정된다.

**재현했다** (`bilingual_published` 픽스처, `GET /en/blog/bilingual-published-post`):

| 신호 | 값 |
|---|---|
| `<link rel="canonical">` | `https://slimfile.net/en/blog/bilingual-published-post` |
| JSON-LD `url` | `https://slimfile.net/blog/bilingual-published-post` |
| JSON-LD `mainEntityOfPage.@id` | `https://slimfile.net/blog/bilingual-published-post` |

**원인**: `app/views/posts/show.html.erb:33` 과 `:50` 이 `<%= base_url %>/blog/<%= @post.slug %>`
로 **로케일 프리픽스 없이 하드코딩**돼 있다. `canonical_path` 는 `@url_locale` 로 계산하는데
JSON-LD 만 그 계산을 지나쳤다.

**A-2 와 같은 잠복 패턴이다.** 지금은 42개 글 전부 한국어 단독이라 `/en/blog/:slug` 가
언제나 noindex 이고 canonical 도 `/blog/...` 라서 JSON-LD 와 우연히 일치한다.
**`body_en` 을 채우는 순간 어긋난다** — A-2 와 트리거가 완전히 같다.

**예상 수정 범위** (다음 런): `posts/show.html.erb` 두 줄. 이미 계산해 둔 `canonical_path` 를
그대로 쓴다(`<%= base_url %><%= canonical_path %>`). 회귀 테스트는 위 표를 단언으로 옮기고,
"JSON-LD url == canonical" 을 로케일별로 확인.

---

### N-2. x-default 가 색인 불가 URL 을 가리킬 수 있다 — **GREEN**

**Codex 지적**: `[논리 오류][확신도 낮음]` 모델이 `body_ko` 를 요구하지 않으므로
`body_en` 만 있는 published 글이 가능하다. 그러면 `indexable_locales == [:en]` 인데
레이아웃·사이트맵의 x-default 는 무조건 한국어 URL 을 가리키고, 그 URL 은 noindex 다.

**재현했다** (`body_ko: nil`, `body_en` 있는 published 글을 만들어 확인 후 삭제):

```
<loc> entries      : ["https://slimfile.net/en/blog/en-only-post"]      ← 올바름
alternates         : [["en", ".../en/blog/en-only-post"]]                ← 올바름
x-default targets  : ["https://slimfile.net/blog/en-only-post"]          ← 문제
  → 그 URL 의 robots = "noindex,follow"
```

`<loc>` 와 alternate 는 정확하다. **x-default 만 규칙을 지나친다** — 레이아웃
(`application.html.erb`) 과 사이트맵(`sitemap.xml.erb`) 양쪽 모두.

`Post` 검증이 `title_ko` 만 요구하고 `body_ko` 는 요구하지 않는 것도 확인했다
(`Post.create!(body_ko: nil, body_en: "…")` 가 통과한다).

**GREEN 인 이유**: 이 데이터 모양을 만드는 경로가 현재 없다 — `BlogGeneratorService` 는
한국어를 먼저 쓰고, 42개 글 전부 `body_ko` 가 있다. 검증 공백이지 현행 결함은 아니다.

**예상 수정 범위** (다음 런): x-default 를 `indexable_locales` 안에서 고르게 한다
(기본 로케일이 색인 가능하면 그것, 아니면 첫 번째 색인 가능 로케일, 하나도 없으면 생략).
레이아웃과 사이트맵 두 곳. 더불어 `validates :body_ko, presence: true` 를 걸지
**정책으로 정할 것** — 한국어 없는 글을 허용할 생각이 있는지가 먼저다.

---

## (b) 의견 차이 — 우리가 맞음 — 1건

### B-1. R6 — `<html lang>` 과 `og:locale` 이 여전히 `I18n.locale` 기반

Codex: "무프리픽스 URL 에서 협상 의존 메타가 남습니다… SEO 신호를 전부 URL 기준으로
통일한다는 원칙이면 후속 정리가 필요합니다."

**판정: 이번 범위에서는 우리가 맞다 — 다만 지적의 사실관계는 정확하고 우리도 먼저 올렸다.**
근거: 이번 요구 범위는 **본문·제목·설명**이었고, CLAUDE.md "남는 관찰" 과 패키지 ⑤-2 에
`<html lang>` 협상 잔존을 **우리가 먼저 적어 보냈다**. Codex 가 `og:locale` 을 하나 더한 것은
정확한 보탬이다.

고치지 않는 이유: `<html lang>`·`og:locale` 을 URL 기준으로 맞추려면 **UI 크롬도 함께** 맞춰야
말이 된다(영어 UI + `lang="ko"` 는 더 이상하다). 그건 영어권 방문자가 `/` 에서 한국어를 보게
되는 제품 결정이다. `og:locale` 은 Codex 도 "색인 핵심 신호라기보다 social metadata" 라고
직전 라운드에 답했다. 다음 런 작업 목록에는 넣되 **(a) 가 아니라 제품 판단 항목**으로 둔다.

---

## (c) 오탐 / 해당 없음 — 5건

### C-1. R1 — draft/scheduled 유출 경로

Codex: "robots, hreflang, x-default, sitemap, 목록 페이지 기준으로 빠져나가는 경로가 보이지
않습니다." 우리 판정과 일치. 지적 아님.
(Codex 가 짚은 "og:url/canonical/JSON-LD URL 은 여전히 렌더된다"는 사실이지만,
`noindex,follow` 가 붙고 발견 경로가 전부 막혀 색인으로 이어지지 않는다 — 본인도 그렇게 적었다.)

### C-2. R2 — 필수 인자화

Codex: "판단은 옳습니다. grep 범위에서 무인자 호출처는 보이지 않았고…" 일치. 지적 아님.

### C-3. R3 — canonical 이 `translated?` 를 쓰는 것

Codex: "이 수정 목적 안에서는 맞습니다." 일치. 지적 아님.
(미발행 한국어 글이 자기 ko 주소로 self-canonical 이어도 noindex + alternate 0개라 열리지 않는다.)

### C-4. R4 — alternate 0개면 x-default 생략

Codex: "옳습니다." 일치. 다만 "alternate 는 1개 이상인데 default URL 이 indexable 이 아닌"
경우를 덧붙였고, 그건 **N-2 로 이미 반영**했다. 별건으로 세지 않는다.

### C-5. R5 — 공허한 단언

Codex: "핵심 회귀 쪽에서는 보이지 않습니다… `KOBODY`/`ENBODY` 양방향 포함/미포함을 확인합니다."
일치. "JSON-LD URL 불일치는 테스트가 잡지 않는다"는 지적은 **N-1 로 반영**했다.

---

## 이번 라운드 자체 개선

직전 라운드 패키지 결함(`sed` 로 `config/routes.rb` 를 잘라 넣어 정작 검토 대상 라인이
빠졌던 것)을 반복하지 않으려고 **라우트 파일을 전문으로** 넣었다. 이번에는 "경로 요청"이
한 건도 나오지 않았다.

## 다음 런 작업 목록 (이 문서의 산출물)

| # | 항목 | 위험도 | 파일 |
|---|---|---|---|
| 1 | JSON-LD `url`·`@id` 를 `canonical_path` 로 통일 | AMBER | `app/views/posts/show.html.erb` |
| 2 | x-default 를 `indexable_locales` 안에서 고르기 + `body_ko` 검증 정책 결정 | GREEN | `layouts/application.html.erb`, `pages/sitemap.xml.erb`, `app/models/post.rb` |
| 3 | (제품 판단) `<html lang>`·`og:locale`·UI 크롬을 URL 기준으로 통일할지 | — | — |

⛔ 전부 **이번 세션에서 고치지 않았다.**
**1번은 `body_en` 을 채우기 전에 고쳐야 한다** — A-2 와 트리거가 같다.
