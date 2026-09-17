# Codex 교차검증 결과 원문 — 미색인 63개 조사 & 수정 · 2026-09-17

> ⛔**이 파일의 본문은 외부 모델 출력 원문이다. 요약·수정하지 않는다.**
> 판정은 `CROSS_REVIEW_TRIAGE_2026-09-17_indexing.md` 에서만 한다.

| 항목 | 값 |
|---|---|
| 실행 명령 | `codex exec --sandbox read-only --skip-git-repo-check -C /Users/sunghoon/Projects/docpack -o <결과> - < docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_indexing.md` |
| 도구 / 모델 | `codex-cli 0.144.3` (ChatGPT 로그인) |
| 대상 커밋 | `1809852` (브랜치 `fix/blog-indexing-signals`) |
| 조각 구성 | **단일 조각** |
| 소요 시간 | 65초 |
| 종료 코드 | 0 |
| 입력 패키지 | `docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_indexing.md` (852줄) |

---

[보안] [확신도 높음] draft/scheduled 글이 공개 200이고, 한국어 본문이 있으면 indexable입니다  
근거: `app/controllers/posts_controller.rb:9`, `app/views/posts/show.html.erb:11`, `app/models/post.rb:33-35`  
설명: `GET /blog/<draft-or-scheduled-slug>` 가 `status: ["published", "scheduled", "draft"]` 를 모두 허용합니다. 해당 글에 `body_ko` 가 있으면 `translated?(:ko)` 가 true라서 `content_for :robots, "noindex,follow"` 도 붙지 않습니다. 사이트맵/목록에 없더라도 슬러그가 유출되거나 내부 링크/프리뷰 링크가 잡히면 미공개 글이 색인 가능한 공개 페이지가 됩니다.

[논리 오류] [확신도 보통] 무프리픽스 bilingual 글은 여전히 요청 협상에 따라 본문/메타가 바뀝니다  
근거: `app/controllers/application_controller.rb:18-20`, `app/models/post.rb:15-25`, `app/views/posts/show.html.erb:6-9`  
설명: canonical/robots는 `@url_locale` 기반으로 고쳤지만, `@post.title`, `@post.body`, `@post.meta_description` 는 계속 `I18n.locale` 을 읽습니다. 그래서 `GET /blog/bilingual-post` 에 `Accept-Language: en` 또는 `locale` 쿠키가 있으면 URL은 한국어 정본으로 canonicalize하면서 title/description/body는 영어로 나갈 수 있습니다. 현재 라이브 글 42개가 전부 Korean-only라 실측에서는 안 드러난 것으로 보이지만, `body_en` 이 있는 글이 생기면 “같은 URL이 요청자에 따라 다르게 답하는” 회귀가 남습니다.

[논리 오류] [확신도 낮음] `@hreflang_locales = []` 인 경우에도 x-default hreflang은 계속 출력됩니다  
근거: `app/helpers/application_helper.rb:58-64`, `app/views/layouts/application.html.erb:13-17`  
설명: helper는 `nil`=전체, `[]`=없음으로 잘 구분하지만, 레이아웃은 그 결과와 별개로 항상 `x-default` 를 출력합니다. 특히 `translated_locales` 가 빈 배열이 될 수 있는 글이면 언어 alternate는 0개인데 `x-default` 만 noindex/canonical 대상 URL로 남습니다. 실제 발생 가능성은 fixtures와 live 데이터에 따라 낮지만, 주석의 “empty array is a real answer” 규칙과는 완전히 일치하지 않습니다.

Q1. `url_locale` 은 canonical/robots/hreflang 본체에는 충분히 적용됐습니다. 다만 `Post#title/body/meta_description` 와 `og:locale` 은 아직 `I18n.locale` 기반입니다. 전자는 bilingual 글에서 실제 콘텐츠/메타 협상 의존을 만들 수 있어 수정 대상이라고 봅니다. `og:locale` 은 Google 색인 핵심 신호라기보다는 social metadata라 심각도는 낮습니다.

Q2. `hreflang_alternates(nil)` / `[]` 구분 자체는 옳습니다. `presence` 폴백을 안 쓴 것도 맞습니다. 회귀는 `posts#index`, 정적 페이지처럼 `@hreflang_locales` 미설정이면 전체 locale이 나가는 현재 동작에서는 없어 보입니다. 단, x-default 예외는 위 지적처럼 별도로 남습니다.

Q3. 제공된 `config/routes.rb` 조각에는 실제 redirect 라인과 `/blog/:slug` 라인이 빠져 있어 최종 검증은 불가합니다. 경로 요청: `config/routes.rb` 블로그 라우트 나머지. 원칙적으로 `/blog/index.html` 전용 라우트가 `/blog/:slug` 위에 있으면 `index.html` 슬러그 글은 가려지는 게 맞습니다. 이 slug를 허용할 계획이 없다면 괜찮고, 허용한다면 충돌입니다.

Q4. `?category=` 를 사이트맵에서 뺀 판단은 맞습니다. 현재 페이지가 `/blog?category=privacy` 에서 canonical `/blog` 를 선언한다면 사이트맵에 넣는 쪽이 더 나쁩니다. 카테고리 페이지를 랭킹 대상으로 삼고 싶을 때만 자기참조 canonical, 고유 title/description, 본문/목록 차별화 후 재추가가 맞습니다.

Q5. 공허한 단언은 크게 보이지 않습니다. Accept-Language 테스트는 canonical/robots 회귀는 잡습니다. 다만 bilingual 글의 무프리픽스 콘텐츠/메타 협상 의존은 못 잡습니다. `GET /blog/bilingual-post` + `Accept-Language: en` 에서 title/body/meta가 한국어 URL 기준으로 고정되는지 테스트가 필요합니다.

Q6. 126개 noindex 유지, `/xx/blog` 목록 hreflang/canonical 유지, category sitemap 제외는 타당합니다. 반대로 draft/scheduled를 public `show` 에서 200으로 서빙하고 한국어 본문이면 indexable하게 두는 판단은 위험합니다. admin을 robots.txt `Disallow` 에만 의존하는 문제는 해당 파일/컨트롤러가 패키지에 없어 판단 보류입니다.