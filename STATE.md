# STATE — DocPack / SlimFile

> 마지막 갱신: 2026-09-18
> 이 파일은 **자유롭게 덮어쓴다** — 과거 상태는 git 이 기억한다. **100줄 이내 유지**
> (넘으면 끝난 것을 지운다. 역사 보존용 파일이 아니다).

## 지금 상태

- Rails 8.0.4 + PostgreSQL 16, Hotwire/Propshaft/Importmap. Kamal 으로 `5.223.92.4` 에 배포,
  `https://slimfile.net` 서비스 중. 이미지 압축 · PDF 변환 · SNS 리사이즈 3개 서비스.
- **배포 파이프라인 복구 완료 (2026-08-25).** 3중 결함이 겹쳐 있었다 —
  ① Kamal 2 가 dotenv 자동 로딩을 제거해 `KAMAL_REGISTRY_PASSWORD` 가 빈 값
  ② ghcr.io PAT 만료 (`Bad credentials`)
  ③ 수정 과정에서 넣은 `${VAR:-default}` 를 Kamal 파서가 지원하지 않아 값이 손상.
  `.kamal/secrets` 가 `.env.production.local` 을 직접 읽도록 바꿔 해결. 이제 `kamal deploy` 만 치면 된다.
  자세한 내용은 CLAUDE.md "Deploy note" / "Kamal secrets parser trap" 절.
- **드래그앤드롭 + 업로드 목록 완료 (`6b42ec8` 외, 2026-08-25, 배포됨).** 원인은
  `upload_controller.js` 부재 + `#preview-area` 가 컨트롤러의 형제라 타겟을 못 찾은 것.
  목록에 서비스 컬러(액센트 바·테두리·헤더 밴드)와 진입 애니메이션까지 입혔다.
  **다크모드는 이 앱에 없다** — `prefers-color-scheme` 가 `app/`·`public/` 어디에도 없다.
- SafeFile(`public/safe/index.html`) v2 좌표 기반 마스킹. 최근 작업은 상단바 로고/네비 정리와
  서비스워커 stale-shell 고정, 포맷별 "PDF로 저장" 경로 추가.
- **SEO 정본 URL 정리 완료 (2026-09-17~18, 전부 미배포).** `/safe/` 중복 4개 · 미색인 63개 ·
  GSC 지명 3개 · 트레일링/반복 슬래시를 모두 잡았다. 한 URL = 한 주소가 `lib/canonical_path_redirect.rb`
  (Rack 301, `ActionDispatch::Static` 앞) + self-referencing canonical 로 보장된다.
  자세한 내용은 CLAUDE.md 의 해당 4개 절. 언어별 `/xx/safe/` 는 존재하지 않는다(전부 404).
- **부수 발견: Rails 테스트 스위트가 죽어 있었다.** minitest 6 ↔ railties 8.0.4 비호환으로
  단언 하나 못 돌고 죽었다(`minitest "~> 5.25"` 핀으로 복구). **다음에 같은 걸 찾을 때는
  "0 tests" 가 아니라 `종료코드 != 0` + `요약 줄 부재` 를 봐라** — 실제 신호는 그쪽이다.
- 블로그 자동화(주제 100개 → Claude API 생성 → MWF 09:00 KST 발행 + Gmail 알림)는
  2026-04 검증 이후 **실제 현재 동작 상태 확인 필요** (마지막 발행일·남은 주제 수 미확인).

## 다음 할 일

0. **배포 → GSC 재크롤링 요청.** (`/safe/` canonical + 미색인 63개 조사 수정이 모두 대기 중)
   - **미색인 63개 조사 완료.** noindex 40 은 **의도대로**다 — 게이트는 draft 가 아니라
     **번역 여부**이고 42개 글이 전부 한국어 단독이라 en/ja/es 126개가 구조적으로 noindex 다.
     그 옆에서 모순 6가지를 고쳤다(가장 심각: 한국어 정본 URL 이 `Accept-Language: en` 에
     noindex 를 반환). **GSC 지명 3건도 수정 완료 — 직전 추정 3건은 전부 틀렸었다.**
   - 프로덕션 DB 는 건드리지 않았다. 판정은 전부 라이브 HTTP 실측 + 깃 이력.
   - 교차검증 (a) 2건(색인 게이트가 발행 상태를 본다 · 콘텐츠도 URL 로케일을 따른다)
     **수정·재검증 완료**. **`body_en` 을 채워도 안전하다** — 개발 DB 에서 확인하고 원복했다.
   - 교차검증 (a) **3건 전부 수정·재검증 완료** (2026-09-18, CLAUDE.md "교차검증 (a) 3건 수정" 절):
     ① `PublishScheduledPostsJob` 이 글 단위로 격리되고, 건너뛴 글은 **런당 관리자 메일 1통**으로
        드러난다(로그만 두면 "영구히 미발행" 을 아무도 모른다). 인프라 예외는 일부러 전파한다.
     ② 반복 슬래시 — **지적보다 넓었다.** `/safe/sw.js/` 와 **경로 중간**(`//about`·`/en//about`
        ·`/blog//:slug`)까지 진짜 200 이었다. 정규화→매핑 순서로 바꿔 1홉 보장.
     ③ 미들웨어를 무조건 삽입하고 가드는 **위치만** 고른다(`enabled=false` 에서 0개였음 — 실측).
     - 부수: **`blog:seed_safefile_posts` 가 직전 커밋으로 실제로 깨져 있었다**(실측, 두 번째
       항목에서 중단). 검증이 이 시드의 오래된 버그를 잡아준 것 — 전에는 본문 없는 published
       중복 2개를 조용히 만들었다. 패턴만 고치고 시드의 존재 이유 정리는 보류(DECISIONS.md).
     - 부수: `ko.yml` 에 검증 메시지 블록 추가. 없어서 검증 실패가 `Translation missing…` 으로
       나왔고, 그건 **발행 실패 알림의 "이유" 칸**이라 알림이 동작하지 않는 상태였다.
   - 교차검증 새 (a) **2건 전부 수정·재검증 완료** (2026-09-18,
     CLAUDE.md "교차검증 새 AMBER 2건 수정" 절):
     ① 막힌 글이 이제 **알림이 아니라 상태**다 — `Post.publish_stuck`(파생 스코프)을
        **DB 만 의존하는 3곳**에서 읽는다: 어드민 배너 · `Stuck (n)` 필터 · `rake blog:stuck`
        (exit 1, 브라우저·비밀번호 불필요). 메일은 보조. 이유는 `posts.publish_error` 에.
        **메일 양쪽을 raise 로 만든 상태에서도 글이 드러나는 것을 테스트로 고정했다.**
        재시도 정책도 정리 — 잡마다 선언(발행잡은 재시도 O / 생성잡은 X, 유료 API),
        메일은 별도 잡(`ApplicationMailDeliveryJob`), 실패한 잡은 `rake jobs:failed`.
     ② **시드 제거** — `db/seeds/safefile_posts.rb` 와 `blog:seed_safefile_posts` 를 지웠다.
        `blog:migrate_privacy` 가 create-or-update 로 **단일 소유자**가 되고,
        제목·메타·본문은 **덮지 않는다**(카테고리만 소유). 신선한 DB 재생성도 실측 확인.

1. **배포 절차.** 미해결 (a) **0건**. 교차검증 3라운드에서 나온 5건 전부 처리했다.
   - `kamal deploy`. 라이브에서 `/safe`·`/safe/index.html` 이 301 인지,
     `/safe/` 에 canonical 이 박혔는지 curl 로 확인.
   - **반복 슬래시도 라이브에서 확인**: `/safe//`·`/safe/sw.js/`·`//about`·`/en//about`
     ·`/blog//<슬러그>` 가 전부 301 1홉인지 (로컬 137경로에서 중복 200 = 0 이었다).
   - **`blog:migrate_privacy` 를 돌린다** (이제 create-or-update, 멱등, 3개 글의 단일 소유자).
     `blog:seed_safefile_posts` 는 **삭제됐다** — 마이그레이션을 되돌리던 태스크다.
   - **배포 후 `rake blog:stuck` 과 `rake jobs:failed` 를 한 번 돌려볼 것.** 둘 다 읽기
     전용이고, 문제가 있으면 exit 1 이다 (`kamal app exec 'bin/rails blog:stuck'`).
   - 라이브에서 `curl -H 'Accept-Language: en-US' .../blog/<슬러그>` 가 **noindex 없이**
     오는지, `/faq` canonical 이 `/faq` 로 남는지도 확인 (이번 수정의 핵심 지표).
   - 그 다음 GSC: `/safe/`·`/blog` URL 검사 → 색인 생성 요청, sitemap 재제출,
     "찾을 수 없음(404)" 목록에서 `/blog/index.html` 인지 확인. 반영까지 며칠~2주.
   - 배포 후 SW 가 새로 깔리므로, 기존 방문자 한 명이 `/safe/` 를 열고 오프라인에서도
     열리는지 눈으로 한 번 볼 것 (자동 검증은 통과했다).
   - 선택: 42개 글 중 몇 개라도 `body_en` 을 채우면 그만큼 en URL 이 색인 대상으로 바뀐다.
     지금은 42개 전부 한국어 단독이라 en/ja/es 126개가 구조적으로 noindex 다.

2. **ghcr.io PAT 재발급.** 2026-08-25 디버깅 중 `od -c` 로 토큰을 평문 출력해 세션 기록에 남았다.
   교체 후 `.env.production.local` 과 `.env` 두 파일 모두 갱신 (두 파일은 같은 값을 유지해야 함).
3. **진단 코드 제거.** `app/views/layouts/application.html.erb` 의 `window.__jsErrors` 수집기와
   `params[:debug]` 로 걸린 `alert()` 블록은 임시다. 원인 규명이 끝났으므로 이제 지워도 된다.
   `dragover`/`drop` preventDefault 자체는 남긴다.
4. **업로드 목록 실기기 확인.** 자동 검증은 통과했으나 실제 모바일 Safari/Chrome 에서
   드롭·파일 선택·긴 파일명 생략을 눈으로 한 번 볼 것.
5. **블로그 자동화 현재 상태 점검.** `kamal app exec 'bin/rails runner "puts Post.group(:status).count; puts BlogTopic.where(used: false).count"'`
   로 발행 현황과 잔여 주제 확인. 2026-04-07 SolidQueue/SMTP 수정 이후 재검증한 기록이 없다.
6. **PWA 작업 시 `app/views/pwa/manifest.json.erb` 처리 결정.** Rails 8 스캐폴드 잔재다 —
   라우트가 없고 레이아웃은 `/site.webmanifest`(정적)를 링크한다(`theme_color: "red"` 가 증거).
   **삭제할지 실제로 라우팅해 쓸지** 정한다. 쓰면 둘 중 하나만 남긴다.

## 막힌 것 / 기다리는 것

- 없음. (1번 PAT 재발급은 사람이 GitHub 에서 직접 해야 하지만 현재 배포를 막고 있지는 않다 —
  지금 토큰은 유효하며 만료 전까지 동작한다.)
