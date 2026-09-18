# STATE — DocPack / SlimFile

> 마지막 갱신: 2026-09-18 (젬 업그레이드)
> 이 파일은 **자유롭게 덮어쓴다** — 과거 상태는 git 이 기억한다. **100줄 이내 유지**
> (넘으면 끝난 것을 지운다. 역사 보존용 파일이 아니다).

## 지금 상태

- Rails 8.0.4 + PostgreSQL 16, Hotwire/Propshaft/Importmap. Kamal 으로 `5.223.92.4` 에 배포,
  `https://slimfile.net` 서비스 중. 이미지 압축 · PDF 변환 · SNS 리사이즈 3개 서비스.
- **배포 파이프라인 복구 완료 (2026-08-25).** 3중 결함(dotenv 미로딩 · PAT 만료 ·
  Kamal 파서가 `${VAR:-default}` 미지원)이 겹쳐 있었다. `.kamal/secrets` 가
  `.env.production.local` 을 직접 읽도록 바꿔 해결 — 이제 `kamal deploy` 만 치면 된다.
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
- **젬 업그레이드 완료 (2026-09-18, 브랜치 `chore/gem-upgrades`, 미배포·미머지).**
  minitest 핀을 **원인 제거**로 풀었다: `rails ~> 8.0.5`(→ 8.0.5.1) + `minitest < 7`(→ 6.0.6)
  + `minitest-mock` 추가(6.0.0 이 `minitest/mock` 을 분리). Ruby 는 두 Dockerfile 을
  `.ruby-version` 과 맞춰 3.3.0 → **3.3.9**(CI 가 프로덕션과 다른 인터프리터를 시험 중이었다).
  dependabot 12건 중 **7 젬 + Actions 2건을 올리고 3건(image_processing 2.x · puma 8 · kamal
  2.12)을 보류**했다. `CanonicalPathRedirect` 위치는 **실제 프로덕션 이미지**에서도 Static 앞임을
  확인. 자세한 내용은 CLAUDE.md "젬 업그레이드" 절, 판단 기준은 DECISIONS.md 2026-09-18.
  ⚠️ **CI 는 이 작업 전부터 빨간색이다** — `lint`(rubocop 86) · `scan_ruby`(brakeman exit 3).
  이 브랜치는 그 숫자를 바꾸지 않는다.
- 블로그 자동화(주제 100개 → Claude API 생성 → MWF 09:00 KST 발행 + Gmail 알림)는
  2026-04 검증 이후 **실제 현재 동작 상태 확인 필요** (마지막 발행일·남은 주제 수 미확인).

## 다음 할 일

-1. **`chore/gem-upgrades` 를 머지·배포.** SEO 작업(0번)과 **같은 배포에 섞을지 정할 것** —
   섞으면 문제가 났을 때 Rails 업그레이드 탓인지 URL 정규화 탓인지 구분이 안 된다.
   배포 후 확인: `/`·`/blog` 200, `kamal app exec 'bin/rails blog:stuck'`, 응답 헤더.
   보류한 3건은 **각각 별도 배포**로: ① `config/puma.rb` 바인드 명시 → 배포 → puma 8
   ② `gem "ruby-vips"` 선행 + 이미지 품질 전/후 비교 → image_processing 2.x ③ kamal 단독.

0. **배포 → GSC 재크롤링 요청.** SEO 정본 URL 작업이 전부 배포 대기 중이다.
   조사·수정·교차검증 4라운드 내역은 **CLAUDE.md 의 해당 절들**에 있다(여기서 반복하지 않는다).
   요지: 미색인 126개 noindex 는 **의도대로**(번역 여부 게이트), 그 옆의 모순 6가지와
   GSC 지명 3건을 고쳤고, 교차검증 (a) 7건 중 6건 처리 완료. 프로덕션 DB 미접촉.

1. **배포 절차.** 교차검증 4라운드에서 나온 (a) 7건 중 **6건 처리 완료.**
   남은 1건은 GREEN(영향 미미): `publish_stuck` 이 시계를 네 번 읽는다(39μs 편차) —
   `docs/review/CROSS_REVIEW_TRIAGE_2026-09-18_amber2b.md`. 배포를 막지 않는다.
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
5. **블로그 자동화 현재 상태 점검.** `kamal app exec 'bin/rails blog:stuck'` +
   `jobs:failed` + `runner "puts Post.group(:status).count"`. 2026-04-07 이후 재검증 기록 없음.
6. **PWA 작업 시 `app/views/pwa/manifest.json.erb` 처리 결정.** Rails 8 스캐폴드 잔재다 —
   라우트가 없고 레이아웃은 `/site.webmanifest`(정적)를 링크한다(`theme_color: "red"` 가 증거).
   **삭제할지 실제로 라우팅해 쓸지** 정한다. 쓰면 둘 중 하나만 남긴다.

## 막힌 것 / 기다리는 것

- 없음. (1번 PAT 재발급은 사람이 GitHub 에서 직접 해야 하지만 현재 배포를 막고 있지는 않다 —
  지금 토큰은 유효하며 만료 전까지 동작한다.)
