# STATE — DocPack / SlimFile

> 마지막 갱신: 2026-11-07 (Rails 8.1.4.1 보안 업그레이드 · 배포 대기)
> 이 파일은 **자유롭게 덮어쓴다** — 과거 상태는 git 이 기억한다. **100줄 이내 유지**
> (넘으면 끝난 것을 지운다. 역사 보존용 파일이 아니다).

## 지금 상태

- Rails **8.1.4.1** + PostgreSQL 16, Hotwire/Propshaft/Importmap. Kamal 으로 `5.223.92.4` 에 배포,
  `https://slimfile.net` 서비스 중. 이미지 압축 · PDF 변환 · SNS 리사이즈 3개 서비스.
- **Rails 8.1.4.1 업그레이드 · 배포 대기 (2026-11-07).** 8.0 보안지원 종료일이 그날이었다.
  `load_defaults` 는 **8.0 유지**(8.1 전환은 별도 작업). 테스트 565/4183 0F · brakeman 12→11
  (EOLRails 소멸·신규 0) · Codex RED 0. **배포 전 사람 확인 5건은
  `docs/review/CROSS_REVIEW_TRIAGE_2026-11-07_rails81.md` §2 가 정본**(특히 프로덕션
  Active Storage 스키마 SQL 3개 — 마이그레이션 거부 판단의 유일한 미검증 전제).
- **배포 파이프라인 복구 완료 (2026-08-25).** 이제 `kamal deploy` 만 치면 된다.
  자세한 내용은 CLAUDE.md "Deploy note" / "Kamal secrets parser trap" 절.
- **드래그앤드롭 + 업로드 목록 완료 (`6b42ec8` 외, 2026-08-25, 배포됨).**
  **다크모드는 이 앱에 없다** — `prefers-color-scheme` 가 `app/`·`public/` 어디에도 없다.
- SafeFile(`public/safe/index.html`) v2 좌표 기반 마스킹. 최근 작업은 상단바 로고/네비 정리와
  서비스워커 stale-shell 고정, 포맷별 "PDF로 저장" 경로 추가.
- **SafeFile JP-1 알파 4종 (2026-10-21, 미배포).** 資格確認書·運転免許証·マイナンバーカード·
  住民票 프리셋 + 제출 목적 게이트 + 띠 단일화(부분 마스킹 제거). 법적 정본은
  `test/safe/fixtures/jp/jp_legal_matrix_alpha4.json` 하나이고 `test/safe/check_matrix.mjs` 가
  코드의 `JP_RULES`·`JP_LEGAL` 과 (doc, field, purpose) 전수 + 법령 그룹을 대조한다.
  라운드 4회(S3 → S3b → S3c → S3d) 모두 Codex 교차검증을 받았고, **S3d 에서 마지막 AMBER
  까지 닫혔다** — 골든 **557/557**. CLAUDE.md 의 JP-1 네 절과 `docs/jp/s3d_report.md`.
  **남은 공백은 그 보고서 §5 가 정본이다**(여기 복사하지 않는다).
  ⚠️ 카드 더미는 공개 저장소에 있다(2026-10-21 사람 결정). **일본 변호사 검토는 아직 없다.**
- **SafeFile JP S6·S7 (2026-10-22, 미배포·미게시).** 알파가 닫힌 뒤의 **첫 시장 접촉**이다.
  일본어 랜딩 3페이지(`/safe/jp/{nyusatsu,honnin-kakunin,ai-mae}/`, 문안 정본 그대로) ·
  파일럿 신청 폼(`POST /api/jp_pilot`, honeypot + IP당 10분 3회, 읽기 전용 어드민 목록) ·
  **개인정보 0 계측**(`POST /api/safe_events` — 모델이 저장 가능한 모양을 단독 정의, IP 미열람,
  테이블 컬럼 4개) · 주 1편 33편 계획과 `scripts/content/make_episode.mjs`(첫 3편 제작 완료).
  탐지 로직 무변경. CLAUDE.md 의 S6·S7 절과 `docs/jp/s6_report.md`·`s7_report.md`.
  ⚠️ 라이브 중 실제 결함 2건을 잡아 고쳤다 — 검증 메시지가 조회 흔적을 신청자에게 보내던 것,
  그리고 **`?locale=ja` 로 계측 엔드포인트가 1년짜리 쿠키를 심던 것**(약속 위반이었다).
- **S6b 교차검증 반영 완료 (2026-10-22, 미배포·미푸시·미게시). 배포 전 마지막 라운드.**
  Codex AMBER 7건 중 (a) 6건 수정 · (b) 1건 백로그 · (c) 0건. `docs/jp/s6b_report.md`.
  ⚠️ **`/api/` 가 외부 사이트의 평범한 HTML 폼으로 행과 메일을 만들 수 있었다 — 라이브 재현**
  (form POST → 201 + 행 1건). CSRF skip 의 근거였던 「JSON 엔드포인트」가 어디서도 강제되지
  않았다. 이제 `Api::BaseController` 가 비-JSON POST 를 **415**, 타 Origin/Referer 를 **403**.
  두 레이트리밋도 `read→+1→write`(동시 20요청에 **6건 통과**, 상한 3)에서 원자적
  `Rails.cache.increment`(**정확히 3건**)로 바꿨다. 콘텐츠 가드는 JA 본문만 보던 것을
  **5개 면**(JA frontmatter/본문 · EN · X스레드 · 캐러셀)으로 넓혔고 미출시 기능 우회표현 ·
  법적 단정 · 1인칭 피해담 · PNG 실측 크기를 막는다. 변이 프로브 7/7 발화.
  **남은 공백·백로그는 `s6b_report.md` §6 이 정본**(B-1~B-11). 그중 **B-10 은 사람 확인 대상**:
  `nyusatsu` 의 meta/og/twitter description 이 아직 `複数PDFを一括` 이라고 말한다(대안 문안 준비됨).
- **SEO 정본 URL 정리 완료 (2026-09-17~18, 전부 미배포).** `/safe/` 중복 4개 · 미색인 63개 ·
  GSC 지명 3개 · 트레일링/반복 슬래시. 한 URL = 한 주소가 `lib/canonical_path_redirect.rb`
  (Rack 301, `ActionDispatch::Static` 앞) + self-referencing canonical 로 보장된다.
  CLAUDE.md 의 해당 4개 절. 언어별 `/xx/safe/` 는 존재하지 않는다(전부 404).
- **젬 업그레이드 (2026-09-18).** Rails 부분은 위 8.1.4.1 항목이 대체했다. 아직 유효한 것:
  보류 3건(image_processing 2.x · puma 8 · kamal 2.12, 각각 **별도 배포**) · 판단 기준
  DECISIONS.md 2026-09-18 · `middleware_probe.sh` 의 임시 이니셜라이저가 남으면 Static 이
  프로덕션 스택에서 사라진다(a-3, **배포 전 처리 권장**. 그 스크립트는 `rm` 을 품고 있어
  2026-11-07 세션은 측정을 손으로 재현했다 — 3개 구성 전부 8.0.5.1 때와 동일).
  ⚠️ **CI 의 `lint`(rubocop 86)·`scan_ruby`(brakeman exit 3)는 이 작업 전부터 빨갛다**
  (2026-11-07 재측정도 86 / 11경고 동일 — Rails 업그레이드가 바꾼 것은 EOLRails 1건뿐).
- 블로그 자동화(주제 100 → Claude API → MWF 09:00 KST + Gmail)는 2026-04 이후 미재검증(아래 5번).

## 다음 할 일

-1. **보류 젬 3건은 각각 별도 배포로**: ① `config/puma.rb` 바인드 명시 → 배포 → puma 8
   ② `gem "ruby-vips"` 선행 + 이미지 품질 전/후 비교 → image_processing 2.x ③ kamal 단독.
   Rails 8.1.4.1 과 **같은 배포에 섞지 않는다** — 섞으면 문제의 원인을 구분할 수 없다.

0~1. **배포 → GSC 재크롤링 요청.** SEO 정본 URL 작업이 전부 배포 대기 중이다. 내역은
   **CLAUDE.md 의 해당 절들**(여기서 반복하지 않는다). 요지: 미색인 126개 noindex 는
   **의도대로**(번역 여부 게이트), 그 옆의 모순 6가지와 GSC 지명 3건을 고쳤다. 교차검증
   (a) 7건 중 6건 완료, 남은 1건은 GREEN(`publish_stuck` 이 시계를 네 번 읽는다, 39μs) —
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
   - **S6b**: `/api/` 세 경로에 form-urlencoded POST 가 **415**, 타 Origin JSON 이 **403**,
     정상 JSON 이 기존대로인지 curl 로 확인. 랜딩 3페이지의 카운터가 204 를 받는지도.

1b. **JP-1 배포 판단.** S3c 교차검증에서 남았던 AMBER 1건이 **S3d 에서 닫혔다**
   (`docs/jp/s3d_report.md`). 배포를 막는 코드 항목은 더 없다 — 다음 라운드를 더 돌릴지,
   이대로 배포할지는 사람 결정이다. 한 번 더 돌릴 경우 검토 범위는 **「S3d 의 AMBER 1건이
   닫혔는가」만**(s3d_report §2·§3). **배포와 무관하게 남은 사람 결정 2건**: 미명시 조합을
   숨길지(S3b 발견 6) · 출처 없는 must_keep 을 제3의 레벨로 분리할지(발견 7).
   그리고 **일본 변호사 검토 — 여전히 없다.**

1c. **JP S6·S7 교차검증 완료 → S6b 반영 완료.** 원문
   `docs/jp/codex_review_s6s7_2026-10-22.md` · 처리 `docs/jp/s6b_report.md`.
   AMBER 7건 중 (a) 6건 수정 · (b) 1건 백로그 · (c) 0건. **코드 쪽 배포 차단 항목은 없다.**
   **남은 사람 결정 3건**: ① **B-10** — `nyusatsu` 의 meta/og/twitter description 이 아직
   `複数PDFを一括` 이라고 말한다(본문은 고쳤고 스니펫에는 단서가 들어갈 자리가 없다;
   대안 문안은 `s6b_report.md` §5) ② Stripe JP 상품 2개(月¥2,980 / 30日パス¥980) —
   없으면 `ai-mae` 의 구매 CTA 는 메일로 남는다 ③ 한 라운드 더 돌릴지. 돌린다면 검토 범위는
   **「AMBER 6건이 닫혔는가 + 새 가드가 공허하지 않은가」**(s6b_report §2~§5, 변이 프로브 7/7).

2. **ghcr.io PAT 재발급.** 2026-08-25 디버깅 중 `od -c` 로 토큰을 평문 출력해 세션 기록에 남았다.
   교체 후 `.env.production.local` 과 `.env` 두 파일 모두 갱신 (두 파일은 같은 값을 유지해야 함).
3. **진단 코드 제거.** `application.html.erb` 의 `window.__jsErrors` 수집기와 `params[:debug]`
   `alert()` 블록은 임시다. 지워도 된다 (`dragover`/`drop` preventDefault 는 남긴다).
4. **업로드 목록 실기기 확인.** 실제 모바일 Safari/Chrome 에서 드롭·파일 선택·긴 파일명 생략.
5. **블로그 자동화 현재 상태 점검.** `kamal app exec 'bin/rails blog:stuck'` +
   `jobs:failed` + `runner "puts Post.group(:status).count"`. 2026-04-07 이후 재검증 기록 없음.
6. **PWA 작업 시 `app/views/pwa/manifest.json.erb` 처리 결정.** Rails 8 스캐폴드 잔재다 —
   라우트가 없고 레이아웃은 `/site.webmanifest`(정적)를 링크한다(`theme_color: "red"` 가 증거).
   **삭제할지 실제로 라우팅해 쓸지** 정한다. 쓰면 둘 중 하나만 남긴다.

## 막힌 것 / 기다리는 것

- 없음. (1번 PAT 재발급은 사람이 GitHub 에서 직접 해야 하지만 현재 배포를 막고 있지는 않다 —
  지금 토큰은 유효하며 만료 전까지 동작한다.)
