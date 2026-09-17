# Codex 교차검증 결과 원문 — GSC 실제 URL 3건 + 신규 2건 · 2026-09-18

> ⛔**이 파일의 본문은 외부 모델 출력 원문이다. 요약·수정하지 않는다.**
> 판정은 `CROSS_REVIEW_TRIAGE_2026-09-18_gsc3.md` 에서만 한다.

| 항목 | 값 |
|---|---|
| 실행 명령 | `codex exec --sandbox read-only --skip-git-repo-check -C /Users/sunghoon/Projects/docpack -o <결과> - < docs/review/CODEX_REVIEW_PACKAGE_2026-09-18_gsc3.md` |
| 도구 / 모델 | `codex-cli 0.144.3` (ChatGPT 로그인) |
| 대상 커밋 | `a504e39` (브랜치 `fix/blog-indexing-signals`) |
| 직전 라운드 대상 | `6138753` — 신규 N-1 / N-2 |
| 조각 구성 | **단일 조각** (1,584줄, 라우트 파일 전문 포함) |
| 소요 시간 | 113초 |
| 종료 코드 | 0 |

---

[N-1 판정] 해소됨  
근거: `app/views/posts/show.html.erb:5`, `app/views/posts/show.html.erb:13`, `app/views/posts/show.html.erb:37`, `app/views/posts/show.html.erb:54`  
설명: Article canonical, JSON-LD `url`, `mainEntityOfPage.@id`가 모두 같은 `canonical_path`에서 나옵니다. `/en/blog/...`에서 영어 정본이면 `/en/...`, 미번역이면 `/blog/...`로 같이 움직입니다.

[N-2 판정] 해소됨  
근거: `app/models/post.rb:21`, `app/models/post.rb:81`, `app/models/post.rb:88`  
설명: published 상태는 `body_ko`가 필수라서 `body_en`만 있는 published 글이 만들어지는 경로를 모델 레벨에서 막습니다. `x-default`가 한국어 정본을 가리키는 구조와도 맞습니다.

[B-404 판정] 적절  
근거: `config/routes.rb:67`, `public/robots.txt:17`, `test/integration/canonical_urls_test.rb:20`, `test/integration/canonical_urls_test.rb:28`  
설명: `/api/safe_scan`은 POST 전용 API이고 GET 404를 페이지처럼 고치는 것보다 `/api/` 크롤 자체를 막는 쪽이 맞습니다. X-Robots-Tag는 fetch가 선행돼야 하므로 이번 원인에는 덜 맞습니다.

[B-중복 판정] 적절, 단 아래 새 지적 1은 배포 확인 필요  
근거: `lib/canonical_path_redirect.rb:76`, `lib/canonical_path_redirect.rb:85`, `config/routes.rb:20`, `app/views/pages/about.html.erb:6`, `app/views/pages/about.html.erb:11`, `app/controllers/pages_controller.rb:27`, `app/views/pages/sitemap.xml.erb:83`  
설명: 트레일링 슬래시는 미들웨어가 먼저 철자를 정규화하고, 구 슬러그 이동은 라우터가 처리합니다. `/about`은 단일 URL만 sitemap에 싣고 prefixed URL은 canonical `/about` + noindex + hreflang 없음으로 처리되어 GSC 중복 원인과 맞물립니다.

**새 지적**

1. [논리 오류][확신도 보통] `CanonicalPathRedirect`가 `public_file_server.enabled`에 묶여 있어, 프록시가 정적 파일을 서빙하는 프로덕션 구성에서는 라우팅 페이지의 트레일링 슬래시 정규화까지 통째로 빠질 수 있습니다.  
근거: `config/initializers/canonical_path_redirect.rb:18`, `config/initializers/canonical_path_redirect.rb:22`, `lib/canonical_path_redirect.rb:83`  
설명: 주석은 “프록시가 public/을 서빙하면 no-op”라고 하지만, 이 미들웨어는 정적 디렉터리뿐 아니라 `/about/`, `/blog/.../`, `/sitemap.xml/` 같은 routed page도 고칩니다. 배포 환경에서 `ActionDispatch::Static`이 없으면 B-중복의 핵심 수정이 조용히 사라질 수 있습니다. 경로 요청: `config/environments/production.rb` 또는 프로덕션 기준 `bin/rails middleware` 결과.

2. [논리 오류][확신도 낮음] 정적 디렉터리의 반복 슬래시(`/safe//`, `/privacy//`)는 미들웨어에서 빠져나갑니다.  
근거: `lib/canonical_path_redirect.rb:76`, `lib/canonical_path_redirect.rb:80`, `test/lib/canonical_path_redirect_test.rb:80`  
설명: `path.start_with?("#{dir}/")`가 `/safe//`도 “asset underneath”로 보고 통과시킵니다. 라우팅 페이지 반복 슬래시는 테스트하지만(`/about//`), 정적 디렉터리 반복 슬래시는 없습니다. Static이 실제 200으로 정규화하면 중복 URL이 남습니다.

**Q1**  
대체로 맞지만 두 빈틈이 있습니다. Propshaft/Active Storage `/rails/...`, `/up`, `/admin`, `.webmanifest`, `/api/`는 일반적으로 trailing slash 제거 또는 pass-through 대상이라 큰 문제는 보이지 않습니다. 다만 배포에서 미들웨어가 빠질 수 있는 조건부 삽입, 그리고 `/safe//`류 반복 슬래시는 확인 필요입니다.

**Q2**  
2홉 수용 판단은 옳습니다. 근거는 `lib/canonical_path_redirect.rb:85`가 철자만 정규화하고, `config/routes.rb:20`이 slug move를 맡는 구조입니다. slug 표를 미들웨어로 옮기면 라우트가 죽은 코드가 되는 위험이 더 큽니다.

**Q3**  
robots.txt Disallow가 맞습니다. `public/robots.txt:17`이 `/api/`를 막고, `config/routes.rb:67`은 POST 전용입니다. GET 404에 noindex를 달 수 없고, noindex는 크롤을 요구하므로 원인 대응과 어긋납니다.

**Q4**  
구분은 옳습니다. `/about`은 `@hreflang_locales = []`로 hreflang을 비우고(`app/controllers/pages_controller.rb:27`), prefixed URL은 noindex(`app/views/pages/about.html.erb:11`), sitemap은 `/about`만 싣습니다(`app/views/pages/sitemap.xml.erb:83`). x-default도 빼는 판단은 일관됩니다. 이 페이지는 다국어 선택지가 아니라 단일 영어 문서입니다.

**Q5**  
`publish!` 자체는 빈 한국어 본문이면 실패하도록 바뀌었습니다(`app/models/post.rb:92`). 유효한 글은 깨지지 않아야 하지만, `PublishScheduledPostsJob` 코드는 패키지에 없어 배치가 예외를 삼키는지/전체 중단되는지는 판단 불가입니다. 경로 요청: `app/jobs/publish_scheduled_posts_job.rb`.

**Q6**  
검증됩니다. JSON-LD 블록은 `WebApplication`, `FAQPage`, `Article` 3개이고, 문제의 page identity URL 필드는 Article의 `url`과 `mainEntityOfPage.@id` 2개입니다. 둘 다 `canonical_path`를 씁니다(`app/views/posts/show.html.erb:37`, `app/views/posts/show.html.erb:54`). `publisher.url`은 조직 홈페이지 URL이라 N-1 대상이 아닙니다.

**Q7**  
공허한 단언은 뚜렷하게 보이지 않습니다. 트레일링 슬래시는 실제 301/Location/홉 수를 봅니다(`test/integration/canonical_urls_test.rb:36`, `:66`, `:98`). JSON-LD는 JSON parse 후 canonical과 값 비교를 합니다(`test/integration/blog_indexing_test.rb:337`). about은 canonical, robots, hreflang, sitemap을 각각 검증합니다(`test/integration/canonical_urls_test.rb:126`, `:134`, `:145`, `:154`). 다만 `/safe//` 케이스와 배포 스택 조건은 테스트가 비어 있습니다.