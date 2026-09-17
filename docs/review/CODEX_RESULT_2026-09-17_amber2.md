# Codex 교차검증 결과 원문 — AMBER 2건 수정 확인 · 2026-09-17

> ⛔**이 파일의 본문은 외부 모델 출력 원문이다. 요약·수정하지 않는다.**
> 판정은 `CROSS_REVIEW_TRIAGE_2026-09-17_amber2.md` 에서만 한다.

| 항목 | 값 |
|---|---|
| 실행 명령 | `codex exec --sandbox read-only --skip-git-repo-check -C /Users/sunghoon/Projects/docpack -o <결과> - < docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_amber2.md` |
| 도구 / 모델 | `codex-cli 0.144.3` (ChatGPT 로그인) |
| 대상 커밋 | `6138753` (브랜치 `fix/blog-indexing-signals`) |
| 직전 라운드 대상 | `1809852` — AMBER A-1 / A-2 |
| 조각 구성 | **단일 조각** (1,517줄, 라우트 파일 전문 포함) |
| 소요 시간 | 87초 |
| 종료 코드 | 0 |

---

[A-1 판정] 해소됨  
근거: `app/models/post.rb:67-75`, `app/controllers/posts_controller.rb:25-40`, `app/views/posts/show.html.erb:17`, `app/views/layouts/application.html.erb:45-50`, `app/views/pages/sitemap.xml.erb:44-62`  
설명: robots 게이트가 `translated?` 단독이 아니라 `status == "published" && translated?(loc)`로 바뀌었고, show는 URL 로케일 기준의 `@post_indexable`이 false면 `noindex,follow`를 냅니다. draft/scheduled는 `indexable_locales == []`가 되어 hreflang/x-default가 빠지고, sitemap은 `Post.published`와 `indexable_locales` 둘 다 거칩니다.

[A-2 판정] 해소됨  
근거: `app/models/post.rb:30-39`, `app/controllers/posts_controller.rb:25-26`, `app/views/posts/show.html.erb:10-12`, `app/views/posts/show.html.erb:31-32`, `app/views/posts/show.html.erb:67`, `app/views/posts/show.html.erb:179`, `app/views/posts/index.html.erb:43-44`  
설명: `title/body/meta_description`은 기본값 없는 필수 `loc` 인자로 바뀌었고, show/index 호출처가 `url_locale` 또는 `@url_locale`을 넘깁니다. 따라서 무프리픽스 `/blog/:slug`는 Accept-Language/cookie와 무관하게 한국어 본문/제목/설명을 냅니다.

새 지적:

1. [논리 오류][확신도 보통] Article JSON-LD의 `url`과 `mainEntityOfPage.@id`가 영어 정본 페이지에서도 한국어 URL로 고정됩니다.  
   근거: `app/views/posts/show.html.erb:5`, `app/views/posts/show.html.erb:10-13`, `app/views/posts/show.html.erb:33`, `app/views/posts/show.html.erb:48-50`  
   설명: `/en/blog/bilingual-post`는 canonical이 `/en/blog/...`가 되지만 JSON-LD Article은 `"url": "https://slimfile.net/blog/..."`, `@id`도 한국어 URL입니다. A-2를 되살리지는 않지만 canonical과 구조화 데이터가 서로 다른 정본을 말합니다.

2. [논리 오류][확신도 낮음] `body_en`만 있고 `body_ko`가 없는 published 글이 생기면 x-default가 noindex URL을 가리킬 수 있습니다.  
   근거: `app/models/post.rb:4-7`, `app/models/post.rb:47-50`, `app/models/post.rb:67-75`, `app/views/layouts/application.html.erb:49-50`, `app/views/pages/sitemap.xml.erb:59-62`  
   설명: 모델 검증은 `body_ko`를 요구하지 않습니다. 그런 글은 `indexable_locales == [:en]`이 될 수 있는데, layout/sitemap의 x-default는 무조건 default Korean URL입니다. 그 Korean URL은 `indexable?(:ko)` false라 noindex가 됩니다. 실제 생성기가 항상 `body_ko`를 채운다는 상류 보장이 있다면 현실 위험은 낮습니다.

R1. draft/scheduled는 robots, hreflang, x-default, sitemap, 목록 페이지 기준으로 빠져나가는 경로가 보이지 않습니다. 목록은 `Post.published`만 씁니다(`app/controllers/posts_controller.rb:3`). og:url/canonical/JSON-LD URL은 여전히 렌더되지만 `noindex,follow`가 붙고 hreflang/sitemap 발견 경로는 차단됩니다.

R2. 필수 인자화 판단은 옳습니다. grep 범위에서 무인자 `post.title/body/meta_description` 호출처는 보이지 않았고, 실제 호출은 show/index의 URL 로케일 전달뿐입니다.

R3. canonical이 `translated?`를 쓰는 것은 이 수정 목적 안에서는 맞습니다. draft/scheduled의 Korean URL이 self-canonical이어도 `noindex`가 붙고 alternates도 없어서 공개 색인 신호로는 열리지 않습니다.

R4. alternate 0개면 x-default 생략은 옳습니다. unpublished 페이지에 fallback 정본을 광고하지 않는 쪽이 신호 일관성이 높습니다. 단, 위 새 지적처럼 “alternate는 1개 이상인데 default URL은 indexable이 아닌” 데이터 모양은 별도 방어가 없습니다.

R5. 공허한 단언은 핵심 회귀 쪽에서는 보이지 않습니다. 특히 `body_en`이 채워진 fixture가 있고(`test/fixtures/posts.yml:60-70`), 무프리픽스/영어 URL 테스트가 `KOBODY`와 `ENBODY` 양방향 포함/미포함을 확인합니다(`test/integration/blog_indexing_test.rb:129-152`). 다만 JSON-LD URL 불일치는 테스트가 잡지 않습니다.

R6. `/ja|es`의 영어 폴백 유지와 무프리픽스 UI 크롬 협상 유지는 제품 판단으로 수용 가능합니다. 다만 `<html lang>`/`og:locale`은 계속 `I18n.locale` 기반이라 같은 무프리픽스 URL에서 협상 의존 메타가 남습니다(`app/views/layouts/application.html.erb:2`, `app/views/layouts/application.html.erb:59-61`). SEO 신호를 전부 URL 기준으로 통일한다는 원칙이면 후속 정리가 필요합니다.