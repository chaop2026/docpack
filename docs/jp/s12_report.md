# S12 — 웹폰트 자체 호스팅 · /ja/blog 언어 전환기 · JP 브랜드명 통일 · 로컬 gem 진단

2026-11-06 · 브랜치 `main` · **미배포·미푸시·실제 게시 0건** · 프로덕션 DB 미접촉
`X_API_DRY_RUN` 줄 무수정(`config/deploy.yml` diff 0줄)

| 유닛 | 커밋 | 상태 |
|---|---|---|
| U0 로컬 gem 오류 진단 (수정 금지) | — | ✅ 규명 — **지시서의 전제가 틀렸다** |
| U1 웹폰트 자체 호스팅 | `c574ae4` | ✅ |
| U2 /ja/blog 언어 전환기 | `ef1c998` | ✅ |
| U3 JP 브랜드명 SafeFile 통일 | `88c08cf` | ✅ |

보류 0건. 승인 큐는 [`docs/autorun/AUTORUN_2026-11-06.md`](../autorun/AUTORUN_2026-11-06.md).

---

## U0 — 「일반 터미널에서만 실패」가 아니었다

지시서의 전제: *일반 터미널에서 `bin/rails test` 가 gem 을 못 찾는데 같은 Mac 의
Claude Code 세션에서는 돌았다* → 셸 환경 차이로 읽힌다.

**측정하니 Claude Code 세션에서도 똑같이 실패한다.** 차이는 셸이 아니라 **Docker 대
호스트**였다. CLAUDE.md 에 기록된 모든 초록 테스트(503 runs 등)는 컨테이너에서 돈 것이다.

| 환경 | ruby | bundler | gem home | `bin/rails test` |
|---|---|---|---|---|
| 깨끗한 **대화형** 로그인 셸 (Terminal.app 조건) | rbenv **3.3.9** | 2.6.9 | `~/.rbenv/versions/3.3.9/…` | ❌ `Could not find propshaft-1.3.2 …` |
| Claude Code Bash 세션 | rbenv **3.3.9** | 2.6.9 | 동일 | ❌ **같은 오류** |
| `docker compose exec web` | 3.3.9 | — | 컨테이너 | ✅ 19 runs / 71 assertions |

호스트 rbenv gem home 의 실제 버전 — 전부 **2026-09-18 젬 업그레이드 이전** 값이다:

| gem | 호스트 설치본 | `Gemfile.lock` 요구 |
|---|---|---|
| propshaft | 1.3.1 | **1.3.2** |
| jbuilder | 2.14.1 | **2.15.1** |
| bootsnap | 1.23.0 | **1.26.0** |
| msgpack | 1.8.0 / 1.8.3 | **1.8.5** |
| minitest | 5.20.0 / 5.27.0 / 6.0.2 | **6.0.6** |

→ 그 세션이 `Gemfile.lock` 을 올렸지만 `bundle install` 은 **컨테이너에서만** 돌았다.
호스트는 그때 이후로 한 번도 맞춰진 적이 없다. `.bundle/config`·`~/.bundle/config`
**둘 다 없고**, `BUNDLE_*`·`GEM_*` 환경변수도 양쪽 모두 0개다 — 설정 문제가 아니다.

### ⚠️ 측정 방법에서 걸러낸 함정 2개

1. **`zsh -lc` 는 Terminal.app 의 모델이 아니다.** zsh 는 `~/.zshrc` 를 **대화형**
   셸에서만 읽으므로 `zsh -lc` 에서는 rbenv init(`.zshrc:20-21`)이 **실행되지 않고**
   `ruby` 가 시스템 2.6.10 으로 떨어진다. 이것만 보고 멈추면 「PATH 에 rbenv shims 가
   없다」는 **틀린 결론**을 내게 된다. `zsh -ilc` 로 재서야 3.3.9 가 나온다.
2. **첫 `zsh -lc` 측정은 상속된 PATH 에 오염돼 있었다.** 내 Bash 세션의 PATH 에 이미
   shims·php@8.3·bun 이 있어 `.zshrc` 가 실행된 것처럼 보였다. `env -i` 로 다시 쟀다.

### 결론 — 셸·Gemfile·Gemfile.lock 은 무수정

Justin 이 칠 명령은 둘 중 하나다.

**권장 (지금 CLAUDE.md 의 모든 초록 수치가 나온 그 경로):**

    docker compose exec web bin/rails test

**호스트에서도 돌리고 싶다면** (pg·nokogiri 네이티브 빌드가 필요해 실패할 수 있고,
그러면 호스트와 컨테이너가 서로 다른 트리로 갈라진다):

    bundle install

---

## U1 — 웹폰트 자체 호스팅 (`c574ae4`)

`public/safe/vendor/README.md` 가 스스로 적어둔 다음 항목이다:
*"Google Fonts … is not a script, so §3-1's sentence is not false because of it,
but it is the next thing to bring in-house."*

### 전수 확인 — 실사용분만

| 페이지 | 요청한 것 | 실제로 쓰는가 |
|---|---|---|
| `/safe/` | Sans KR 400/500/700 + Mono 400/500 | ✅ 둘 다 (`font-family` 4종) |
| `/privacy/` | Sans KR 400/500/700 | ✅ Sans 만 |
| `/safe/jp/nyusatsu/`·`honnin-kakunin/`·`ai-mae/` | Sans KR + Mono | ✅ `/safe/jp/jp.css` 의 `body` + `.mono` 경유 |
| **Rails 레이아웃** | **없음** | 시스템 스택(`-apple-system, BlinkMacSystemFont, …`) |

> 세 랜딩은 페이지 본문에 `font-family` 선언이 0개라 처음엔 「쓰지 않는 글꼴을 받고
> 있다」로 보였다. 공유 CSS(`jp.css:23,24`)를 보고서야 실사용임을 확인했다. **페이지
> 하나만 grep 하면 틀린 결론이 나오는 모양이었다.**

### 재서브셋하지 않았다

292개 `@font-face`(Mono 5×2 + Sans KR 94×3)를 Google 의 `unicode-range` 분할 그대로
유지한다. 그 range 가 브라우저로 하여금 페이지에 **실제로 있는** 한국어 서브셋만 받게
하는 장치이므로, 이 변경 뒤 런타임 트래픽의 모양은 전과 같고 **출처만 다르다**.

하나로 합치면 파일 수는 줄지만, 4개 언어 i18n 사전을 클라이언트에서 전환하는
페이지(`/safe/`)에서 **어떤 글자가 나타나도 되는지를 내가 정하는** 셈이 된다. 그
결정에서 빠진 글자는 요란하게 실패하지 않는다 — 한 페이지, 한 언어에서 조용히
시스템 폰트로 떨어지고, 그걸 읽는 사람만 본다.

**2.34 MB / 292 파일.** 버전 변경 없음(전송 경로 변경).
일본어는 전과 같이 시스템 폰트가 그린다 — Plex Sans KR 은 라틴+한글만 덮는다.

### 무결성 — 할 수 있는 것과 할 수 없는 것

Google 은 글꼴 파일에 **SRI 를 publish 하지 않는다.** `public/safe/vendor/` 가 쓴
「다른 응답에 실린 해시와 대조」가 여기서는 불가능하다. 받은 파일을 다시 해시하면
자기 자신과 항상 일치하므로 검사가 아니다. 그래서 `script/vendor_fonts.mjs` 는:

1. 파일마다 **두 번** fetch(별도 연결)해 sha256 일치를 요구 — 불변 URL 에서 실제로
   일어나는 실패(절단·손상 전송)를 잡는다
2. 바이트 길이가 서버가 알린 `Content-Length`(다른 응답의 다른 필드)와 일치
3. 모든 파일이 woff2 매직 `wOF2` 로 시작

**상류 해시보다 약하고, README 가 그렇게 적는다.** 「그 URL 이 준 것을 온전히
받았다」는 세우지만 「그 URL 이 무엇을 줘야 하는가」는 독립적으로 세우지 못한다.

### privacy §3-1 — 예외가 2개에서 1개로

KO·JA 양쪽. 「글꼴도 이 사이트에서 제공합니다 / 書体もこのサイトから配信しています」를
**긍정형으로** 넣고, 남은 예외(OCR: `cdn.jsdelivr.net`·`tessdata.projectnaptha.com`)만
이름을 밝힌다. 테스트가 **양쪽 반을 다** 단언한다 — 개수 문구(`한 가지`/`1つ`)가 목록과
함께 움직이는지, 그리고 `fonts.googleapis.com` 이 산문에서 **사라졌는지**. 후자가 없으면
페이지가 더 이상 하지 않는 요청을 계속 고백하게 되고, 자기 네트워크 탭을 확인한 독자는
두 문장 중 어느 쪽이 낡았는지 알 수 없다.

### 서비스 워커

`CACHEABLE_CDN` 에서 fonts 호스트 2개 제거(jsdelivr 만 남음 — Tesseract.js) ·
`CACHE_VERSION` **v3→v4**(죽은 `fonts.gstatic.com` 런타임 항목 축출) ·
`/fonts/fonts.css` **만** precache.

292개 woff2 는 **일부러 선캐시하지 않는다.** 각자 `unicode-range` 를 달고 있어 브라우저가
필요한 것만 받는데, 전부 선캐시하면 첫 페인트 리플로를 줄이려고 **모든 독자에게 2.34MB**
를 물린다. 같은 출처 cache-first 분기가 첫 사용 시 캐시한다 — CDN 에 있을 때 받던 대우에서
제3자 요청만 뺀 것이다.

오프라인에서 글꼴을 한 번도 받지 않았다면 폴백 스택으로 렌더된다. **변경 전에도
정확히 그랬다**(`fonts.gstatic.com` 은 오프라인에서 닿지 않는다) — 회귀가 아니다.

### 하지 않은 것

`scripts/content/templates/{carousel,guide,shorts_card}.html` 은 여전히 Google Fonts 를
받는다. Playwright 로 로컬 렌더해 PNG/PDF 산출물을 만드는 **생성 템플릿**이고 방문자에게
서빙되지 않으므로 이 디렉터리가 지키는 약속 밖이다. 고치면 검증을 위해 회차 생성기를
돌려야 하는데, 그 생성기가 2026-11-05 런에서 커밋된 산출물 45개를 퇴화시켰다.

---

## U2 — /ja/blog 언어 전환기 (`ef1c998`)

`/ja/blog` 가 「한국어」를 제시하고 그 링크는 `/blog` 로 갔다. 리다이렉트도 에러도
아니다 — `/blog` 는 **한국어 간행물**이다. 일본어 독자가 이 페이지의 한국어판을 찾아
누르면 다른 간행물에 도착하고, **유일한 증상은 「제목이 전부 바뀌었다」뿐이다.**

S11 이 hreflang 을 좁히고(`@hreflang_locales = []`), S11c 가 JP **글** 페이지의
전환기를 좁혔는데 **목록**이 남았다 — 한 규칙의 두 쪽이 갈라지는 전형이다.

- `PostsController#index`: `@switcher_locales = [] if @url_locale == :ja`
  (hreflang 과 같은 집합·같은 근거)
- 레이아웃: **전환할 대상이 없으면 컨트롤 자체를 렌더하지 않는다.** `[]` 를 그냥 넘기면
  빈 메뉴가 나오고, 그건 없는 것보다 나쁘다(고장난 것처럼 보인다). 지금 읽고 있는 언어
  하나만 든 드롭다운은 아무 일도 하지 않는 버튼이다.
- 글 쪽의 `[ :ja, :en ]` 하드코딩 → `[ :ja, (:en if post.translated?(:en)) ].compact`.
  **현재 데이터에서는 값이 같다**(8편 전부 `body_en` 2~3천자, 실측). `post_en.md` 없이
  import 된 다음 회차에 대비한 것이다.

### E-1 때문에 JP 픽스처를 추가하지 않았다

`blog_seo_snapshot_test.rb` 는 `Post.order(:slug)` × 4 프리픽스 + MODEL 행을 모아
**키 집합이 스냅샷과 같은지** 단언한다(`assert_equal expected.keys.sort, captured.keys.sort`).
JP 글 픽스처 하나를 넣으면 항목이 5개 늘어 **「한국어 트랙이 움직이지 않았다」를 증명하는
바로 그 테스트가 깨진다.** (S8b 가 반대쪽에서 같은 벽에 부딪혔다 — 리다이렉트 대상
슬러그에 픽스처를 넣어 `PrivacyGuideOwnershipTest` 8건을 깼다.)

→ 목록 쪽은 HTTP 로, 글 쪽 파생은 **저장하지 않은 `Post`** 로 단위 검증했다. 변경 대상이
요청이 아니라 글이므로 그게 맞는 고도이기도 하다.

---

## U3 — JP 브랜드명 통일 (`88c08cf`)

S11b 가 `publisher` 를 SafeFile 로 바꾸고 `author` 를 남겼다. 일본어 글 하나가
**같은 JSON-LD 객체 안에서** `publisher=SafeFile`·`author=SlimFile` 을 선언했다 —
S11b 가 없애려던 「한 엔티티가 두 이름」이 **키 한 칸 아래에서** 재현된 것이다.

`og:site_name` 도 같이 고쳤다 — JSON-LD 를 파싱하지 않는 크롤러와 사람이 간행물
이름을 보는 다른 자리다. 레이아웃이 `content_for(:og_site_name)` 을 읽고 미설정이면
`"SlimFile"` 이라 **한국어 출력은 1바이트도 변하지 않는다.**

| 분기 기준 | 이유 |
|---|---|
| `og:site_name` → **`primary_locale`** (글이 쓰인 언어) | `/en/blog/:slug` 는 일본어 회차의 영어판이고 그 발행자도 SafeFile 이다. `@url_locale` 로 분기하면 **한 글이 어느 주소로 열렸는지에 따라 발행자가 바뀐다** |
| `/ja/blog` 목록도 포함 | 지시는 「JP 글」이었지만, 목록을 SlimFile 로 남기면 랜딩=SafeFile · 글=SafeFile · **그 둘을 잇는 색인=SlimFile** 이 되어 같은 JP 표면에 세 번째 이름이 생긴다 |

`content_for` 는 **APPEND** 하므로 지역변수로 한 번만 읽는다 — 두 번 부르면 조용히
`"SafeFileSafeFile"` 이 된다(이 저장소가 robots 지시어에서 이미 당한 모양).

**한국어 무이동을 직접 단언했다.** E-1 은 JSON-LD 를 보지 못하므로 스냅샷이 지킬 수
없다: KO 글의 `author`·`publisher` **해시 전체** + `/blog`·`/en/blog`·`/es/blog`·`/`·
`/faq` 의 `og:site_name=SlimFile`.

---

## 검증

| 검증 | 결과 |
|---|---|
| `bin/rails test` (컨테이너) | **522 runs / 3,981 assertions / 0 failures** (S11c 503/3,835) |
| 신규 `webfont_self_hosting_test` | 9개 / 76 단언 |
| 신규 `language_switcher_test` | 7개 / 38 단언 |
| 확장 `jp_geo_surface_test` | 20→**24개** / 276 단언 |
| **E-1 스냅샷** | **38/38 통과 · 스냅샷 파일 미수정(바이트 불변)** |
| 골든 `run.mjs` | **557/557** 불변 |
| `check_matrix` | **188 triple + 10 legal pair** 불변 |
| `jp_landing_check` | 169→**172/172** (+3 = 랜딩 3곳 글꼴 단언) |
| `unlocated_check` | **19/19** |
| SW 장애 주입 | **9/9** (하네스가 `v4` 를 소스에서 읽어 자동 추종) |
| `canonical_sweep` | **6/6** (사이트맵 33 · 내부 링크 46 · 34페이지 JSON-LD · AL 10×5) |
| `site_verification_test` | 4/27 |
| `public_assets_readable_test` | 3/10 — `public/**` 글롭이 `public/fonts/` 297개를 자동 포함 |
| `SHA256SUMS` | **292/292 OK** · `--verify` 재실행 통과 |
| 권한 | 644 아닌 파일 **0개**, 디렉터리 755 |
| rubocop | **86** (신규 0) |
| brakeman | **12** (증가 0) |
| 금지어 가드(22규칙) | **신규 0** — 아래 |
| 프로덕션 DB | **미접촉** |

### 금지어 — 기존 7건을 전부 설명했다

`JpContentGuard.rules[:forbidden]`(22규칙)을 변경 페이지 7개에 적용: 154회 검사, 7건 적중.
**HEAD 베이스라인(110회 검사, 7건)과 동일 — 신규 0.** 7건의 정체:

| 적중 | 정체 |
|---|---|
| `privacy`·`/safe/` `hundred_percent` = `100%` ×2 | **인라인 CSS** 의 `-webkit-text-size-adjust:100%`. 내 텍스트 추출기가 `<style>` 을 걷어내지 않아 생긴 것으로, 산문이 아니다 |
| `nyusatsu` `ikkatsu`·`fukusu_files`·`shori_kiroku`·`batch_en`·`proclog_en` | **팀플랜 로드맵 목록**(`複数PDFの一括処理`, `処理記録`, `batch PDF processing, processing log`). S6b 가 명시적으로 제외한 구절이고 면책 문장이 함께 있다 |

신규 파일(`public/fonts/README.md`·`fonts.css`)은 0건.

### 변이 프로브 10/10 — 전부 발화

| # | 변이 | 결과 |
|---|---|---|
| 1 | `ai-mae` 에 Google Fonts `<link>` 복원 | 2 failures |
| 2 | `privacy` 의 `fonts.css` link 삭제 | 1 failure (단언 76→67) |
| 3 | 참조된 woff2 1개 제거 (dangling src) | 1 failure |
| 4 | `CACHE_VERSION` v4→v3 | 1 failure |
| A | index 의 `@switcher_locales = []` 제거 | 1 failure |
| B | 레이아웃의 「전환 대상 없으면 숨김」 가드 제거 | 1 failure |
| C | 글 쪽 파생을 `[ :ja, :en ]` 하드코딩으로 되돌림 | 1 failure |
| D | `author` 삼항식을 `SlimFile` 하드코딩으로 | 2 failures |
| E | `og_site_name` 을 레이아웃에서 무조건 `SafeFile` 로 (한국어 오염) | 2 failures |
| F | 글 쪽 `content_for` 제거 (JP 가 SlimFile 로) | 2 failures |

매 프로브 뒤 `git checkout -- <경로>` 로 원복하고 **미커밋 0건**을 확인했다. 프로브는
전부 **커밋 이후**에 돌렸다 — 이 저장소가 `git checkout -- .` 로 미커밋 작업 11개
파일을 날린 전례가 있어, 파괴적 git 명령 전에 커밋한다는 규약을 따랐다.

### 골든 하네스의 404 는 내 것이 아니다

`run.mjs` 가 콘솔 오류로 404 9건 + SW `PageError` 1건을 보고한다. **HEAD~1 의
`public/safe/index.html`·`sw.js` 를 넣고 같은 하네스를 돌려 동일함을 확인했다**
(9×404 + 1 PageError, 557/557). 기존 현상이고 이번 변경과 무관하다.
하네스의 정적 서버 root 는 `public/` 이므로 `/fonts/fonts.css` 와 woff2 는 **정상
해석된다**(실측) — 404 는 글꼴이 아니다.

---

## 남는 공백

- **`WebApplication.name` 은 여전히 사이트 전역 `"SlimFile"`.** JP 페이지에서
  `og:site_name=SafeFile` 과 나란히 선다. 그 블록은 조직이 아니라 **도구**를 설명하는
  다른 엔티티 타입이라 판단이 한 겹 더 필요하다(이번 범위 밖 — 승인 큐 🟡).
  `<title>`·`twitter:title` 기본값, 상단바 로고 텍스트도 같은 꼬리다.
- **생성 템플릿 3개는 Google Fonts 를 계속 받는다**(위 U1). 서빙되지 않으므로 약속
  밖이지만, 자체 호스팅으로 옮기려면 생성기 재실행이 필요하다.
- **글꼴 무결성은 상류 해시가 없다**(위 U1). Google 이 SRI 를 내지 않는 한 더 세게 할
  수 없다.
- 호스트 gem 트리가 `Gemfile.lock` 과 어긋나 있다(U0). 컨테이너에서만 테스트가 돈다.
- `public/safe/작업물/` 미해결 — `.gitignore`·`.dockerignore` 로 배포 대상에서만 빠져
  있다(2026-10-25 S8 이후 그대로). **이번에도 커밋 0건**(추적 0 확인).
- `/ja/blog` 카테고리 칩 7개 중 1개만 글이 있다.
- ep04~33 본문 미작성 · Shorts 8편 미게시.
- **X 한도 미확인 → `X_API_DRY_RUN=1` 유지** (이 런에서 그 줄 무수정, deploy.yml diff 0줄).
- **일본 변호사 검토는 여전히 없다.**
