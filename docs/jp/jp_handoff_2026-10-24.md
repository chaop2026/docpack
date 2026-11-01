# SafeFile JP — 다음 세션 인계 문서 (2026-10-24 23:59 작성)

> 목적: 다음 세션이 이 문서 하나로 지금까지의 전략·구현·자산·워크플로우를 이해하고, **「주 1회 원소스 멀티유스(OSMU) 콘텐츠 자동 파이프라인 + Justin 1회 승인」** 설계를 바로 시작할 수 있게 한다.
> 읽는 순서: §0 → §1 → §5 → §6. 나머지는 참조.

---

## 0. 한 줄 현황

- 제품: SafeFile JP-1 알파 **배포됨** (slimfile.net/safe/, 4종 서류 자동 띠 마스킹 + 제출목적 게이트). 랜딩 3페이지·파일럿 폼·익명 계측 **배포됨**.
- 마케팅: X `@safefile_jp` 개설·프로필·고정 트윗(JA)+영어 답글 완료. LinkedIn(Justin 개인) 영어 출시 글 1건 게시. 콘텐츠 파이프라인(`make_episode.mjs`) 동작, ep01~03 산출물 생성됨, **ep01만 게시**.
- 매출 축(파일럿 영업): **아직 시작 안 함** — 예측 P2(11-22까지 접촉 메일 40통)가 최우선 미착수 항목.
- 다음 세션 과제: 블로그(자체 사이트)를 **허브**로 한 OSMU 주간 파이프라인 설계 + 일본어 글쓰기 전략 + 30편 주제 확정 + 자동 게시·1회 승인 구조.

---

## 1. 지금까지의 전략 — 다시 생각한 요약

### 1-1. 확정된 것 (바꾸지 말 것)
| 항목 | 결정 | 근거 문서 |
|---|---|---|
| 1순위 수익 | 건설 입찰·보조금 정산 서류를 반복 제출하는 소규모 사업자 B2B-lite (チームプラン 月¥2,980) | jp_market_decision_v2 |
| 2순위 | AI 입력 전 익명화 — 30日パス ¥980 | 〃 |
| 광고 | 콘텐츠·랜딩 페이지에만. `/safe/` 처리 화면에는 절대 없음 | 〃 (Codex 15번) |
| 포지셔닝 문장 | 「提出先のルールどおりに、自動で正しく黒塗り。ファイルはブラウザの外に出ません。」 | 〃 |
| 금지 | 사건명(タイムズカー 등)·1인칭 피해담·「絶対/防ぐ/唯一/必ず安全」·「막을 수 있었다」·미출시 기능(一括 등) 언급 | 전략 v2 §5, S6b 가드 |
| 필수 문장 | 모든 How-to에 「提出先の指示を必ず確認してください。」 | 〃 |
| 채널 | 랜딩(매출 축) + X·YouTube Shorts·Instagram(상방). 주 1편 OSMU | 예측 보고서 §9 |
| 언어 원칙 | X 본 트윗 = 일본어, 영어는 스레드 마지막 답글. LinkedIn = Justin 1인칭 영어(브랜드 화법 금지). 영어 전용 계정 안 만듦 | 2026-10-24 |
| 예측 검증 | 매월 22일 리뷰(첫 리뷰 2026-11-22). 검증일 지나면 예측값 수정 금지 | 예측 보고서 §6 |

### 1-2. 오늘 새로 깨달은 것 (다음 세션이 반영할 것)
1. **블로그가 빠져 있었다 — 그런데 이미 있다.** slimfile.net/blog 는 Rails 블로그(`Post` 모델, 42편 게시, KO/EN 컬럼)이고, **자동 생성 파이프라인이 이미 돌고 있다**: `AutoGenerateBlogPostJob`(월·수·금 00:00 KST, Claude API `claude-sonnet-4-6`로 KO 초안 + 히어로 이미지) → `draft` 저장 → `BlogMailer.review_requested` 메일 → Justin이 admin에서 `improve`/`publish` → `PublishScheduledPostsJob`(매일 09:00)이 `scheduled` 글 게시. **즉 "초안 자동 생성 → 1회 승인 → 자동 게시" 구조가 KO 블로그에 이미 존재**한다. JP는 이것을 **확장**하면 되지, 새로 만들 필요가 없다.
   - 제약: `posts` 테이블에 `body_ja`/`title_ja`/`meta_description_ja` 컬럼이 **없다**(ko/en만). `BlogTopic.category`에 `privacy`·`jp` 류가 없다. 라우트는 `/:locale/blog/:slug`를 지원(ja/es는 KO로 폴백 + noindex). 
2. **OG 태그 문제**: LinkedIn이 `/safe/jp/nyusatsu/` 링크를 "DocPack - Image Compression & PDF Conversion"으로 미리보기했다. 랜딩 3페이지 OG title/description/image를 SafeFile 로고·문안으로 바꿔야 한다(소셜 공유 전환율 직결).
3. **영어 UI에서는 일본 서류가 탐지되지 않는다** — `OCR_LANGS()`가 UI 언어에 종속(en→`eng`). 영어 데모는 영문 샘플로 만들었다. 영어권 대상 JP 서류 데모가 필요하면 `?lang=ja` 로 녹화하고 자막만 영어로.
4. **X 신규 계정 제한**: "Unlock more on X" 안내 — 몇 주간 검색·추천 노출 제한. 팔로잉 0·팔로워 0. 첫 2주는 **팔로우 20~30(建設業協会·電子入札·行政書士·デジタル庁)·답글 참여**가 게시보다 중요.
5. **자동 게시의 현실적 수단**(다음 세션에서 결정):
   - 블로그: 이미 자동(위 1).
   - X: API Free tier(월 1,500 쓰기, 미디어 업로드 가능) → `scripts/content/post_x.mjs` 가능. 또는 지금처럼 Claude(Chrome)가 승인 후 게시.
   - LinkedIn: 공식 API는 앱 심사 필요(개인 공유는 "Share on LinkedIn" 제품으로 비교적 쉬움). 당분간 Claude(Chrome) 게시.
   - YouTube Shorts: Data API(일 쿼터 10,000, 업로드 1건 1,600) → 스크립트 가능. **채널 아직 없음.**
   - Instagram: Graph API는 비즈니스 계정+FB 페이지 필요. **SafeFile용 IG 계정 없음.** 우선순위 낮춤 권장(일본 B2B 타깃과 안 맞음) → X·블로그·YouTube·LinkedIn 4곳으로 축소 검토.
   - "1회 승인" 구현안: 주간 패키지(글 JA/EN + 카루셀 3 + GIF/MP4 + X 스레드 + LinkedIn 글)를 **하나의 미리보기 페이지(아티팩트 또는 admin 페이지)**로 묶어 Justin이 1번 승인 → 전 채널 발행. 블로그의 기존 review_requested 메일 흐름에 X/LinkedIn 항목을 붙이는 쪽이 가장 적은 변경.

---

## 2. 구현 자산 — 어디에 무엇이 있나 (Mac `~/Projects/docpack`)

### 2-1. 제품
- `public/safe/index.html` — 탐지·마스킹 전부(JP_RULES, jpClassify, JP_LEGAL, 목적 게이트, 띠 전용 마스킹, 래스터 평탄화, sendBeacon 계측). URL 파라미터 `?lang=ja&purpose=<identity_submit|my_number_procedure|bid_attachment|consult_share>&from=<nyusatsu|honnin|aimae|direct>`.
- `public/safe/jp/{nyusatsu,honnin-kakunin,ai-mae}/index.html`, `jp.js`, `jp.css` — 랜딩 3페이지(JA 본문, EN 접이식).
- `app/controllers/api/{base,jp_pilot,safe_events}_controller.rb`, `admin/jp_pilot_requests_controller.rb`, 모델 `JpPilotRequest`·`SafeEvent`, `lib/tasks/safe.rake`(`safe:jp_weekly` → `docs/jp/metrics/YYYY-WW.md`).
- 테스트: `test/safe/run.mjs`+`specs.json`(골든), `test/safe/check_matrix.mjs`(법적 매트릭스↔코드 188 triples), `test/safe/jp_landing_check.mjs`(110/110), `test/sw/offline_resilience.mjs`.
- 더미: `test/safe/fixtures/jp/` 44개(4종 × png/jpg/pdf + specs), `gen.py`.
- 법적 매트릭스: `test/safe/fixtures/jp/jp_legal_matrix_alpha4.json`.

### 2-2. 콘텐츠 파이프라인
- `content/jp/topics.json` — 33편(ep·track A/B·title_ja/en·doc·purpose·landing·status·week).
- `scripts/content/make_episode.mjs <ep>` — 입력 `content/jp/epNN/post_ja.md`(frontmatter: title·hook·bullets 3·cta·captions 3) → `x_thread.md`(4~5 트윗, UTM), `carousel_1..3.png`(1080×1350), `demo.gif/mp4`(track A, 로컬 서버에서 Playwright 녹화), `manifest.json`. 5-surface 금지어 가드 + 필수 문장 자동 삽입. 템플릿 `scripts/content/templates/carousel.html`. 사용법 `scripts/content/README.md`.
- 생성됨: `content/jp/ep01..03/` 전체 산출물. **ep01 X 게시 완료**(manifest `posted.x=true`, 고정 트윗은 GIF+요약문, 5개 스레드 전체는 미게시). ep02·03 미게시.
- 영어 출시 세트: `content/en/launch/` — `safefile_demo_en.{gif,mp4}`, 결과 캡처, `linkedin_post_en.txt`.

### 2-3. 브랜드
- `public/safe/brand/` — 확정 로고 B(먹색 배경 크림 S, 꼬리 한 토막 분리) `icon.svg`, `favicon.ico`, `icon-{16..512}.png`, `x_profile_400.png`, `x_header_1500x500.png`.
- `docs/jp/brand/options/` — 후보 4안·비교 시트·생성 스크립트. `docs/jp/brand/README.md` — 선택 이유·색상 토큰(INK #1A1613 / CREAM #F6F4EE / SAND #E8E3D8 / YELLOW #FFD84D)·X 프로필 값·게시 기록.
- **미결**: `/safe/` 사이트 파비콘(`public/safe/icon-512.png` 등)은 아직 예전 것. 교체 여부 결정 필요.

### 2-4. 문서(`docs/jp/`)
`jp_safefile_strategy_v2_2026-10-21.md`(전략, 30편 목록 §6), `jp_market_decision_v2_2026-10-22.md`(수익 결정), `jp_forecast_report_2026-10-22.md`(예측 P1~P17·중단 기준), `jp_landing_copy_2026-10-22.md`(문안 정본 + 파일럿 메일 JA/EN), `s3*_report.md`·`s6*_report.md`·`s7_report.md`(구현 보고), `codex_review_*.md`(교차검증), `outreach_log.md`(비어 있음), `metrics/`.
프로젝트 컨텍스트(claude.ai): `claude/2026-10-21_JP진출전략_v2`, `claude/2026-10-22_JP시장수익결정_v2`, `claude/2026-10-22_JP보수적사업모델예측_검증표`, `claude/2026-10-24_SafeFileJP_브랜드자산_X프로필`, `claude/brand/safefile_logo_B2.svg`.

### 2-5. 계정
- X `@safefile_jp` (chaop2026@gmail.com, 패스키=MacBook Touch ID, iCloud 키체인 동기화). 이름 `SafeFile セーフファイル`, 링크 `/safe/jp/nyusatsu/`, 위치 Japan. 고정 트윗 https://x.com/safefile_jp/status/2113999418223685682
- LinkedIn Justin 개인 https://www.linkedin.com/in/sunghoon-sim-7460a8b7/
- Meta: 9개 중 3개 삭제 예약, 나머지 유지. SafeFile용 IG/FB/Threads 없음. YouTube 채널 없음. Telegram/WhatsApp/LINE 점검 보류.

---

## 3. 워크플로우 — 역할 분담과 절차

| 역할 | 담당 | 비고 |
|---|---|---|
| 전략·검수·콘텐츠 승인·게시(Chrome) | Claude(이 프로젝트 세션) | Mac 폴더 연결 시 파일 직접 읽기/쓰기 가능(`device_bash`, 읽기·쓰기 전용. node/Chrome/Docker/Codex 없음) |
| 코드 구현·테스트·커밋 | Claude Code (Mac) | 프롬프트는 docs/jp/sN_prompt.md 형식, 자율 규칙·3-Strike·골든 유지·푸시/배포 금지·마지막 줄 `SN_DONE` |
| 교차 검증 | Codex (Mac) | `codex exec --full-auto "$(cat docs/jp/codex_prompt_X.md)" \| tee docs/jp/codex_review_X.md`. 루프 방지: 수정 라운드 후엔 지명된 AMBER 종결 여부만 확인, 신규 지적은 백로그(미탐·증빙훼손·법적 과장만 예외) |
| 배포 | **Justin 본인만** | Claude Code와 별도 셸에서 `set -a; source .env.production.local; set +a && kamal deploy` |
| 게시 최종 클릭 | Justin 승인 → Claude 실행 | 오늘: X 고정 트윗·영어 답글·LinkedIn 모두 "게시해" 1회 승인 후 Claude가 Chrome으로 게시 |

Claude Code 세션 시작 명령(항상): `caffeinate -i &` → `tmux new -s docpack` → `claude --dangerously-skip-permissions`.

---

## 4. 미커밋·미배포·미완 항목 (다음 Claude Code 실행 시 1순위)

**미커밋(Mac 작업 트리, 6건)**: `public/safe/brand/`, `docs/jp/brand/`, `content/en/launch/`, `content/jp/ep01/manifest.json`, `docs/jp/jp_landing_copy_2026-10-22.md`(미출시 "一括" 3줄 삭제), `docs/jp/jp_handoff_2026-10-24.md`(이 문서). 그리고 정체불명 `public/safe/작업물/`(Justin 확인 필요 — public/ 아래라 배포 시 공개됨).
**미배포**: 1e392a9(B-10 메타 설명 수정) — 다음 배포에 포함.
**미완**: `docs/jp/pilot_targets.md`(파일럿 후보 10곳) 미작성 · 접촉 메일 0통 · 랜딩 OG 태그 · 사이트 파비콘 교체 결정 · ep02/03 게시 · X 팔로우 20~30 · YouTube 채널 개설 · Stripe JP 상품(파일럿 2곳 전까지 보류).
**백로그(S3/S6b)**: 世帯連記式, 本籍 라벨 퍼지매치, QR 라벨 없는 승격, PDF 객체그래프 검사, ICC 해시, 폰트 핀, /safe/jp/ 301→404, honeypot 타이밍, 600/min 근거, 免許証 뒷면 판정 D-2.

---

## 5. 다음 세션 과제 정의 — 「주간 OSMU 파이프라인」

### 5-1. Justin이 원하는 것(원문 요지)
- 매주 토 또는 일에 주기적으로 실행.
- 약 30편 주제를 미리 잡아 지속 노출하는 마케팅 전략.
- 글·이미지·GIF·동영상 생성 → 자동 게시까지. **마지막에 Justin 승인 1회만.**
- 일본 특화 글쓰기 전략 + 실제로 보여줘야 하는 중요 정보 전달 방식.
- 영어 사용자는 LinkedIn으로.
- 자체 사이트 블로그 운영(원소스의 출발점).

### 5-2. Claude가 추가하는 것(빠진 항목)
1. **블로그를 허브로**: 정본 = 블로그 글(JA + EN). X 스레드·카루셀·Shorts·LinkedIn은 블로그 URL(UTM)로 회귀. SEO: `/ja/blog/:slug` 실제 색인 가능하게(ja 컬럼 추가, hreflang, sitemap, JSON-LD Article/FAQ). 이게 P1·P10(랜딩 방문)의 유일한 복리 자산.
2. **기존 블로그 파이프라인 재사용**: `AutoGenerateBlogPostJob` 패턴 그대로 `jp` 트랙 추가(`BlogTopic` 33편 import, 생성 프롬프트를 `content/jp` 금지어 가드·필수 문장과 동일 규칙으로, 히어로 = carousel_1 재사용). review 메일 1통 = 승인 1회.
3. **주간 패키지 미리보기 1장**: 글 JA/EN·카루셀·GIF/MP4·X 스레드·LinkedIn 글·게시 예정 시각을 한 페이지로. 승인 → `status=scheduled` + X/LinkedIn 게시 큐.
4. **게시 자동화 수단 결정**(§1-2 ⑤): 블로그=이미 자동, X=API 또는 Chrome, LinkedIn=Chrome, YouTube=API, Instagram=보류. **스케줄 세션**: claude.ai 예약 작업은 클라우드에서 돌고 Chrome이 없으므로, Chrome 게시는 (a) Justin이 주말에 세션을 열어 "승인" 한 마디로 Claude가 게시, 또는 (b) "컴퓨터 필요" 예약 작업(Mac 켜져 있을 때)으로. 다음 세션에서 (a)로 시작 권장.
5. **일본어 글쓰기 규칙서**: です・ます体, 書類名은 정식 명칭(資格確認書/被保険者証 구분), 숫자·根拠(법령·施行日) 1개 이상, 「提出先の指示が優先」, 사건명 금지, 1인칭 피해담 금지, 제목 패턴(【】 사용, 32자 내), 検索 의도별 3유형(手順/理由/比較). X는 140자 기준(일본어 2바이트 계산) — 오늘 영어 답글 280자 초과 3회 재작성한 교훈: **글자 수 사전 계산기** 넣기.
6. **채널별 포맷 규칙**: 노션 스타일(아이콘·굵기·빈 줄) 기본. LinkedIn은 유니코드 볼드, X는 이모지 번호(①②③), 블로그는 H2/H3+표. 링크 미리보기용 OG 정비.
7. **측정 연결**: UTM 규칙(`utm_source=x|linkedin|blog|youtube&utm_campaign=epNN`), `safe:jp_weekly`, Search Console, 예측 P15(2027-01-22까지 24편)·P16(SNS 경유 10%)·P17(YouTube 3,000) 대조표를 주간 패키지에 자동 첨부.
8. **매출 축을 콘텐츠에 종속시키지 말 것**: 파일럿 접촉 메일 40통(P2)은 콘텐츠와 별개로 **즉시** 시작. 다음 세션 첫 30분은 `pilot_targets.md` 10곳 작성.
9. **법·안전 가드 유지**: 더미 카드 긴 변 ≤800px, 「見本」 워터마크, 법적 효과는 「制限される場合があります」 수준, Codex 교차검증은 전략 문서·블로그 프롬프트에 1회.
10. **YouTube Shorts 채널 개설 + 세로 1080×1920 녹화**(현재 GIF는 720×1280). Instagram은 보류 결정.

### 5-3. 다음 세션 산출물(권장 순서)
1. `docs/jp/pilot_targets.md` (10곳) + 첫 메일 5통 발송 준비 — 30분
2. `docs/jp/jp_content_strategy_v3.md` — 블로그 허브 OSMU 전략, 일본어 글쓰기 규칙서, 30편 주제 재배열(블로그 제목·검색 의도·채널별 파생물·주차), 채널 결정(IG 보류), KPI 연결
3. Codex 교차검증 1회 → v3 확정
4. Claude Code 프롬프트 `docs/jp/s8_prompt.md`: ja 컬럼 마이그레이션, BlogTopic jp 33편 import, 생성 프롬프트+가드, 주간 패키지 미리보기, X API 게시 스크립트(키는 .env), OG 태그 수정, 사이트 파비콘 교체, 미커밋 6건 커밋
5. 첫 주간 실행(ep01을 블로그 글로 재게시 → X 스레드 → LinkedIn EN) — 승인 1회 테스트

---

## 6. 다음 세션 시작 프롬프트 (복사용)

```
[새 Claude.ai 프로젝트 세션 · 프로젝트 "safefile.net 서비스" · Mac 폴더 ~/Projects/docpack 연결 후]

docs/jp/jp_handoff_2026-10-24.md 를 먼저 읽고(프로젝트 문서 claude/2026-10-24_JP인계_OSMU주간파이프라인.md 와 동일), §5 순서대로 진행해.
1) pilot_targets.md 10곳 먼저.
2) 블로그를 허브로 하는 주간 OSMU 전략 v3 + 일본어 글쓰기 규칙서 + 30편 재배열. 기존 Rails 블로그 파이프라인(AutoGenerateBlogPostJob → review 메일 → PublishScheduledPostsJob)을 재사용하는 설계로.
3) Codex 교차검증 1회 후 확정.
4) Claude Code용 s8_prompt.md 작성.
질문은 되돌리기 어려운 결정(채널 추가·삭제, 가격, 결제, 배포)에만.
```

---

## 7. 2026-10-25 추가 (이 절이 §0·§5·§6보다 최신 — 충돌 시 이 절이 우선)

- **완료**: `docs/jp/jp_content_strategy_v3.md`(v3.1, 교차검증 반영 확정) · `docs/jp/codex_review_v3_2026-10-25.md`(ChatGPT 교차검증, 5 AMBER → 전부 반영, YES-with-fixes) · `docs/jp/s8_prompt.md`(v3.1 반영판) · `docs/jp/private/pilot_targets.md`(실명 10곳 + 첫 메일 5통, **gitignore**).
- **Justin 결정 완료(2026-10-25 「권장대로」)**: Instagram 보류 · X 개발자 앱 등록 진행(한도 확인 후 자동화 ON) · ja 글 `/blog/`→`/ja/blog/` 301 · 사이트 파비콘 교체. 교차검증은 Claude가 알아서 진행하고 요약만 보고.
- **다음 행동 순서**: ① s8 실행(Claude Code) ② 배포(Justin) ③ 파일럿 메일 5통 발송(폼) ④ 첫 주간 승인 테스트(ep01, 블로그 게시 월요일 2026-10-26 → 실제로는 s8 배포 후 첫 월요일).
- **폐기·주의 문서**: §5-2 ⑤·§1-2 ⑤의 「X API Free 월 1,500」 전제는 **틀림**(교차검증 Q3) — v3.1 §2-3 참조. §5-3의 1주차 10-27은 화요일 — **10-26(月)** 로 정정됨. P15는 원문 보존, **P18 신설**.
- Codex CLI는 이 세션 연결 셸에서 안 보임 → 교차검증은 ChatGPT 웹(Chrome)으로 수행. 결과는 항상 `docs/jp/codex_review_*.md`에 저장.

## 8. 2026-10-25 18:45 — S8 배포 완료·ep01 승인 (이 절이 §7보다 최신)

- S8 → S8b → S8c(교차검증 3라운드, 최종 GREEN) → **배포 완료**(3d68a43, 18:05 KST). 체크리스트 ⓪~⑧ 전부 통과. ep01~03 프로덕션 import(draft). 주간 잡 `auto_generate_jp` 등록(다음 실행 10-31 토 00:00 KST).
- **ep01 승인됨**(18:44, Claude가 Chrome으로 「承認」 클릭) → 블로그 10-26 09:00 JST 자동 공개, X 12:00 드라이런.
- 결정(Justin): 사람 작업은 **토요일 한 번**(승인 + LinkedIn 예약 게시). LinkedIn = 개발 일지·쉬운 말·시각물(PDF ≤10장 또는 MP4 또는 사진) 필수. 승인 화면·메일은 **한국어**여야 함(현재 일본어 — S9).
- 주의: `X_API_DRY_RUN`이 `deploy.yml` env에 없어 컨테이너에 안 들어감(키 없어 자동 드라이런). **X 키 넣기 전 S9-1 필수.**
- 다음: `docs/jp/s9_todo.md`(한국어 승인 화면·LinkedIn 개발 일지·PDF 설명서·deploy.yml) → 파일럿 메일 5통 발송. 스킬 `weekly-osmu-pipeline` 저장됨(§6에 적용·변경법).
- 미커밋: codex_review_s8c·s8b_report(-U docpack 수정)·s9_todo·linkedin_en.md·전략 §3-3·이 절 → 다음 Claude Code 세션에서 커밋.

## 9. 2026-10-27 22:05 — 남은 일 (이 절이 §8보다 최신)
- S9 배포 완료(afc8fa7, 20:50). 드라이런 컨테이너 적용·미리보기 404·/safefile 301 실측 통과. 고정 트윗 교체(2115055040432083148, 고통→원인→해결, utm 없음), 10-24 트윗 삭제.
- 파이프라인 운영은 「SNS 계정 운영」 프로젝트로 이관(인계: `osmu_pipeline_handoff_2026-10-27.md`). schooljob 주간 브리핑 결정 메모는 `teachermatch/docs/osmu/`. HelloKorean·Rolli·currencyrate·slotbook 제외.
- 미커밋 4건(manifest·s9_todo·codex_review_s9·osmu_pipeline_handoff) → 다음 Claude Code 세션(S10) 첫 커밋.
- **Justin**: ① LinkedIn ep01 개발 일지 게시(`content/jp/ep01/linkedin_en.md` + 카루셀 3장) ② 10-31(토) ep02 승인 메일 — X 첫 줄이 고통으로 시작하지 않으면 반려 ③ **파일럿 메일 5통(P2: 11-22까지 40통, 현재 0통)** — `docs/jp/private/pilot_targets.md` §3 폼 붙여넣기. 매출 축이며 콘텐츠와 무관하게 즉시 ④ `public/safe/작업물/` 정체 확인.
- **월간 배치 기한**: ep04 publish_on 11-16 → 주간 잡이 11-07(토)에 찾음 → **11-06까지 ep04~08 원고 생성·import** 필요(없으면 API 폴백으로 텍스트만 생성됨).
- S10: utm→via 교체, X 문안 규칙(고통 첫 줄) guard·전략 반영 + ep02~03 x_thread 재작성, finish! 키 단위(완료됨, S9 F-17), X 실제 게시 ON은 요금제 확인 후.
