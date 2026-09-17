# 교차검증 대조(triage) — 미색인 63개 조사 & 수정

- 대상 커밋: `1809852` (브랜치 `fix/blog-indexing-signals`, **미배포**)
- 외부 모델 출력 원문: [`CODEX_RESULT_2026-09-17_indexing.md`](CODEX_RESULT_2026-09-17_indexing.md)
- 투입 패키지: [`CODEX_REVIEW_PACKAGE_2026-09-17_indexing.md`](CODEX_REVIEW_PACKAGE_2026-09-17_indexing.md)
- 🔴 **이 세션에서는 (a) 를 고치지 않았다.** 아래 (a) 2건은 **다음 수정 런의 입력**이다.

지적 3건 + Q1~Q6 답변 6건 = **9건 전부 분류했다.**

---

## (a) 진짜 문제 — 2건

### A-1. draft/scheduled 글이 공개 200이고 색인 가능하다 — **AMBER**

**Codex 지적**: `[보안][확신도 높음]` `PostsController#show` 가
`status: ["published", "scheduled", "draft"]` 를 전부 허용하고, `body_ko` 가 있으면
`translated?(:ko)` 가 true 라 noindex 도 안 붙는다. 미공개 글이 색인 가능한 공개 페이지가 된다.

**코드로 확인함** — `app/controllers/posts_controller.rb:9`:
```ruby
@post = Post.where(status: [ "published", "scheduled", "draft" ]).find_by!(slug: params[:slug])
```
`show.html.erb:11` 의 `content_for :robots, "noindex,follow" unless @post_translated` 는
**번역 여부만** 본다. 발행 상태는 보지 않는다.

**우리가 먼저 올린 항목이다** — 패키지 ⑤-4 와 CLAUDE.md "③ 판단 불가" 에 적어 보냈고,
Codex 가 독립적으로 같은 결론에 도달했다. 우리는 "개수를 셀 수 없다"는 이유로 판단 불가로
분류했는데, **개수는 못 세도 코드 조건은 확정적**이다. 그 점에서 Codex 분류가 더 정확하다.

**완화 요인 (RED 가 아닌 이유)**: 사이트맵에도 `/blog` 목록에도 안 나온다
(`Post.published` 스코프). 도달하려면 슬러그를 알아야 하고, 슬러그는 `title_ko.parameterize`
라 추측이 아주 쉽지는 않다. 실제로 색인됐다는 증거는 없다 — 라이브에서 확인할 방법이 없다
(프로덕션 DB 를 건드리지 않기로 했으므로 draft 슬러그를 열거할 수 없다).

**예상 수정 범위** (다음 런): `app/views/posts/show.html.erb` 한 줄 —
게이트를 `unless @post_translated && @post.status == "published"` 로 넓힌다.
**미리보기 동작은 그대로 둔다**(200 유지) — 바뀌는 건 색인 여부뿐이다.
테스트는 `posts.yml` 에 draft/scheduled 픽스처 2개 추가.

---

### A-2. 이중언어 글은 무프리픽스 URL 에서 본문·메타가 여전히 협상된다 — **AMBER**

**Codex 지적**: `[논리 오류][확신도 보통]` canonical/robots 는 `@url_locale` 로 고쳤지만
`Post#title`·`#body`·`#meta_description` 은 계속 `I18n.locale` 을 읽는다.

**재현했다.** 테스트 DB 의 `bilingual` 픽스처로 실측:

| 요청 | `<title>` | description | 본문 | canonical |
|---|---|---|---|---|
| `GET /blog/bilingual-post` | `번역된 글` | `번역된 글의 설명` | 한국어 | `…/blog/bilingual-post` |
| `GET /blog/bilingual-post` + `Accept-Language: en` | `Translated post` | `Description of the translated post` | **영어** | `…/blog/bilingual-post` |

같은 URL 이 요청자에 따라 다른 제목·설명·본문을 내보내면서 canonical 은 한국어 주소로 고정된다.
게다가 그 영어 내용은 `/en/blog/bilingual-post` 와 동일하므로 **진짜 중복 쌍**이 만들어진다.

**이번 수정이 절반만 끝났다는 뜻이다.** 신호(canonical·robots·hreflang)는 URL 기준으로 옮겼는데
**내용과 메타는 협상에 남겨뒀다.** 내가 놓쳤고, Codex 지적이 맞다.

**지금 라이브에는 드러나지 않는다** — 42개 글 전부 `body_en` 이 비어 있어 `I18n.locale` 이
무엇이든 한국어가 나온다. `body_en` 을 하나라도 채우는 순간 발현된다.
(STATE.md 의 "선택: body_en 을 채우면…" 항목이 바로 그 트리거다. **채우기 전에 고쳐야 한다.**)

**예상 수정 범위** (다음 런): `Post#title/body/meta_description` 이 로케일을 인자로 받게 하고
(`def title(loc = I18n.locale)`), `posts/show.html.erb` 가 `@url_locale` 을 넘긴다.
회귀 테스트는 위 표를 그대로 단언으로 옮긴다.

---

## (b) 의견 차이 — 우리가 맞음 — 1건

### B-1. `@hreflang_locales == []` 인데 x-default 는 계속 출력된다

Codex: `[논리 오류][확신도 낮음]` 언어 alternate 가 0개인데 x-default 만 남는다.
주석의 "empty array is a real answer" 규칙과 완전히 일치하지는 않는다.

**판정: 현재 동작이 맞다 — 다만 지적의 사실관계는 정확하다.**
근거: x-default 는 **언어 주장이 아니라 폴백 포인터**다 (Google 문서: "특정 언어/지역을
대상으로 하지 않는 페이지"). 레이아웃은 `localized_path(I18n.default_locale)` 을 가리키므로
"번역이 하나도 없으면 한국어 주소로 가라"는 뜻이 되고, 그건 참이다.
`test/integration/blog_indexing_test.rb:16-25` 에서도 x-default 를 hreflang 집계에서
의도적으로 제외하며 같은 이유를 적어뒀다.

덧붙여 **발생 조건 자체가 없다**: `translated_locales` 가 빈 배열이 되려면 `body_ko` 가
비어 있어야 하는데, 그런 글은 애초에 noindex 라 hreflang 이 읽히지 않는다.
Codex 도 "실제 발생 가능성은 낮다"고 적었다. 문서화만 보강하면 충분하다고 본다.

---

## (c) 오탐 / 해당 없음 — 6건

### C-1. Q3 — "routes.rb 조각에 redirect 라인이 빠져 최종 검증 불가"

**사실이고, 우리 패키지 결함이다.** `sed -n '20,45p'` 로 잘라 넣었는데 실제 redirect 라인과
`/blog/:slug` 라인이 46줄 이후라 빠졌다. Codex 잘못이 아니라 **패키지를 만든 우리 잘못**이다.
다음 패키지에서는 라우트 파일을 전문으로 넣는다.

Codex 가 제기한 실질 우려(슬러그가 `index.html` 인 글이 가려지는가)는 **반증됨**:
`Post#generate_slug` 가 `title_ko.parameterize` 를 쓰고
`"index.html".parameterize` → `"index-html"` 이다 (러너로 확인). 자동 생성으로는 절대
`index.html` 슬러그가 나오지 않는다. 어드민에서 손으로 넣으면 가려지지만, 그건
`/blog/index.html` 을 글 주소로 쓰겠다는 뜻이라 막는 게 맞다.

### C-2. Q1 — `og:locale` 이 `I18n.locale` 기반

Codex 스스로 "색인 핵심 신호라기보다 social metadata라 심각도는 낮다"고 답했다. 동의한다.
OG 로케일은 공유 카드 표시용이고 색인 판정에 쓰이지 않는다. 지적 아님.
(단 A-2 를 고칠 때 같은 함수 근처를 지나가므로 그때 함께 본다.)

### C-3. Q2 — `nil`/`[]` 구분과 회귀

Codex: "구분 자체는 옳습니다. `presence` 폴백을 안 쓴 것도 맞습니다. 회귀는 없어 보입니다."
우리 판단과 일치. 지적 아님. (`test/integration/blog_indexing_test.rb` 의
"pages that are genuinely translated keep all four alternates" 가 이 회귀를 지킨다.)

### C-4. Q4 — 사이트맵에서 `?category=` 제외

Codex: "맞습니다… 랭킹 대상으로 삼고 싶을 때만 자기참조 canonical, 고유 title/description,
본문 차별화 후 재추가가 맞습니다." 우리 결정(DECISIONS.md 2026-09-17)과 **정확히 일치**하고,
재추가 조건까지 같다. 지적 아님.

### C-5. Q5 — 공허한 단언

Codex: "크게 보이지 않습니다. Accept-Language 테스트는 canonical/robots 회귀는 잡습니다."
못 잡는 케이스로 든 것은 A-2 이고, 이미 (a) 로 반영했다. 별건으로 세지 않는다.

### C-6. Q6 — admin 이 robots.txt 에만 의존

Codex: "해당 파일/컨트롤러가 패키지에 없어 판단 보류." 패키지에 안 넣은 우리 선택이 맞다
(이번 범위 밖). 참고로 `/admin` 은 `Admin::BaseController` 세션 인증 뒤에 있어
크롤러가 내용을 볼 수 없고, `robots.txt` 는 크롤 차단용이다. 다음에 다룬다면 별건이다.

---

## 다음 런 작업 목록 (이 문서의 산출물)

| # | 항목 | 위험도 | 파일 |
|---|---|---|---|
| 1 | draft/scheduled 글에 noindex 추가 (200 서빙은 유지) | AMBER | `app/views/posts/show.html.erb`, `test/fixtures/posts.yml` |
| 2 | `Post#title/body/meta_description` 를 `@url_locale` 기준으로 (협상 의존 제거) | AMBER | `app/models/post.rb`, `app/views/posts/show.html.erb` |

⛔ 둘 다 **이번 세션에서 고치지 않았다.**
**2번은 `body_en` 을 채우기 전에 반드시 먼저 고쳐야 한다** — 지금은 전 글이 한국어 단독이라
잠복 상태지만, 번역을 하나라도 넣는 순간 중복 페이지가 생긴다.
