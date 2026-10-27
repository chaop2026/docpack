# SafeFile JP S9: 승인 화면·메일 한국어화 + 한국어 요약 + LinkedIn 개발 일지 파일 + PDF 사용설명서 + 드라이런 안전장치 + /safefile 301. 배포·푸시·실제 게시 금지.

## 자율 실행 규칙
- 중간 확인 없이 끝까지. 막히면 CLAUDE.md 「JP-1 이슈 로그」에 기록하고 계속. 3-Strike. 시간 약속 금지.
- 기존 테스트 전부(367)·E-1 38/38·골든 557·jp_landing_check 128 유지. KO 색인 신호 불변. XPublishJob·JpImport의 S8b/S8c 원자성·잠금 구조는 건드리지 않는다.
- `X_API_DRY_RUN=1` 고정. 프로덕션 미접촉. 완료 시 커밋, `docs/jp/s9_report.md`, 마지막 줄 "S9_DONE".
- 먼저 미커밋 작업물을 **별도 커밋 1개**로: `docs/jp/codex_review_s8c_2026-10-25.md`, `docs/jp/s8b_report.md`(-U docpack 수정), `docs/jp/s9_todo.md`, `content/jp/ep01/linkedin_en.md`, `docs/jp/jp_content_strategy_v3.md`(§3-3 LinkedIn 행), `docs/jp/jp_handoff_2026-10-24.md`(§8). `docs/jp/private/`·`public/safe/작업물/`은 여전히 커밋 금지.

## 읽을 것
docs/jp/s9_todo.md(요구 원문), docs/jp/jp_content_strategy_v3.md §3-3(LinkedIn 개발 일지 규칙), app/views/admin/jp_packages/show.html.erb, app/views/blog_mailer/jp_review_requested.html.erb, app/services/jp_episode_source.rb, app/services/jp_import.rb(package 키 merge 규칙 — `summary_ko`·`linkedin_text`·`guide_pdf`는 import가 쓰는 키), scripts/content/make_episode.mjs, scripts/content/templates/carousel.html, config/deploy.yml, config/routes.rb

## A. 드라이런 안전장치 (가장 먼저, 작게)
1. `config/deploy.yml` → `env.clear`(비밀 아님)에 `X_API_DRY_RUN: "1"` 추가. `.env.production.local`의 값보다 **deploy.yml의 clear 값이 항상 컨테이너에 들어가는** 구조로 — 나중에 실제 게시를 켤 때는 deploy.yml에서 그 줄을 지우는 **의식적인 커밋**이 필요하게. `XClient.dry_run?`은 ENV `X_API_DRY_RUN=="1"` **또는** 키 4개 중 하나라도 없음. 테스트: ENV 1 + 키 4개 있음 → dry_run true.
2. `config/routes.rb`: `/safefile`, `/safefile/` → `/safe/` 301. `test/safe/jp_landing_check.mjs` 또는 라우트 테스트에 1건 추가.

## B. 승인 화면·메일 = 한국어 (승인자 언어)
3. `app/views/admin/jp_packages/show.html.erb`·`jp_review_requested.html.erb`·`jp_review_requested_x_failed`·`jp_x_unknown`의 **모든 UI 문자열을 한국어로**. 콘텐츠 본문(JA/EN)만 원문. 버튼: 「승인」「반려」「확인 완료로 표시」「미전송으로 재개」「전송됨으로 기록」. 라벨 예: 공개 예정 / 블로그(일본어) / X 스레드 / LinkedIn(수동 · 예약 게시 → 화요일 09:00 JST) / 자주 묻는 질문 / 검사 결과 / KPI 대조. 메일 제목 `[SafeFile JP] 제NN회 승인 요청: {title_ja}`. 일본어 UI 문자열은 `config/locales/ko.yml`의 `jp_admin.*` 키로 모으고 뷰는 `t()`만 — 하드코딩 금지. 기존 KO 어드민(`/admin/posts`)과 톤 일치.
4. **승인 버튼 위치**: 페이지 **최상단**(공개 예정표 바로 아래, 현 위치 유지)과 **최하단**(KPI 표 아래) 두 곳. 하단 버튼은 상단과 같은 폼. 「승인」 버튼 옆에 한 줄: 「누르면 월요일 09:00 JST에 블로그가 공개되고 X 스레드가 예약됩니다. 승인 전에는 아무것도 공개되지 않습니다.」
5. 승인 화면 상단에 **「공개 페이지 미리보기」** 링크: draft/scheduled 글을 관리자 세션에서만 실제 공개 레이아웃으로 렌더하는 `/admin/jp/packages/:ep/preview` (noindex, 비관리자 404). 기존 `posts#show`를 재사용하되 `@preview=true`로 published 가드만 우회. E-1에 영향 없어야 함(공개 라우트 불변).

## C. 한국어 요약 (`summary_ko`)
6. `content/jp/epNN/summary_ko.md` 신설 — frontmatter 없음, 섹션 고정: `## 제목` / `## 요지`(3~4문장) / `## 표`(隠す/残す 등 본문 표를 KO로) / `## 근거`(법령·시행일·출처 1줄) / `## 트윗`(번호별 KO, 영어 답글 포함) / `## FAQ` / `## 사람이 판단할 한 가지`(이 글에서 Justin이 실제로 책임지는 주장 1개). `JpEpisodeSource`가 읽어 `package.summary_ko`(섹션별 해시)로 import. **없으면 import 거부**(exit 1, 「summary_ko.md 없음 — 승인자가 읽을 수 없는 패키지는 만들지 않는다」). 폴백(API 생성) 경로는 `BlogGeneratorService#generate_jp` 출력 JSON에 `summary_ko` 필드를 추가해 같은 구조로.
7. 승인 화면·메일: 각 JA 섹션 **바로 아래**에 회색 박스로 KO 요약을 붙인다(글 요지는 본문 위, 트윗 KO는 각 트윗 아래, FAQ KO는 각 Q 아래). 「사람이 판단할 한 가지」는 승인 버튼 바로 위에 노란 박스.
8. `JpContentGuard`에 KO 요약 존재·섹션 7개 존재 검사 추가(위반이면 승인 비활성).
9. ep01~03의 `summary_ko.md`를 작성(ep01은 2026-10-25 Claude 번역을 기준으로; ep02·03은 post_ja.md에서) → 재import(ep01은 scheduled라 **거부되어야 정상** — 보고서에 그 거부 출력을 증거로 붙일 것. ep02·03만 갱신).

## D. LinkedIn = 개발 일지 파일
10. `JpEpisodeSource#linkedin_text`의 자동 조립 **삭제**. `content/jp/epNN/linkedin_en.md`를 읽어 그대로 `package.linkedin_text`. 없으면 import 거부(exit 1). 규칙은 전략 v3.1 §3-3 LinkedIn 행(2026-10-25 개정) — 코드 주석에 그 행을 인용.
11. `guard_rules.json`에 `linkedin` 섹션: 금지 패턴 `SafeFile (helps|lets|allows) you`, `free for the first`, `日本の`, `Japanese (companies|businesses) (can|should)`, `sign up`, `limited time`; 문장 길이 평균 ≤ 18단어(쉬운 말), 링크 1개만, 해시태그 ≤3, ≤1,300자. 위반 → 승인 비활성.
12. ep01 `linkedin_en.md`는 **2026-10-25 저녁의 「쉬운 말」 버전**으로 교체(아래 본문 그대로 저장). ep02·03은 같은 톤·같은 구조(첫 줄 = 독자도 궁금할 질문, 전문용어 0, 끝은 「써보고 뭐가 헷갈렸는지 알려달라」)로 작성하되 **각 회차에서 Justin이 실제로 만든 것**을 쓴다: ep02 = 「제출처 지시문을 읽는 법」을 도구가 어떻게 돕게 했나(목적 선택 → 마스크 집합), ep03 = AI에 붙여넣기 전 익명화 모드를 왜 따로 만들었나.

ep01 linkedin_en.md 본문:
```
𝗜 𝘀𝗽𝗲𝗻𝘁 𝘁𝗵𝗶𝘀 𝘄𝗲𝗲𝗸 𝗼𝗻 𝗮 𝘀𝗺𝗮𝗹𝗹 𝗾𝘂𝗲𝘀𝘁𝗶𝗼𝗻: 𝘄𝗵𝗲𝗻 𝘆𝗼𝘂 𝗯𝗹𝗮𝗰𝗸 𝗼𝘂𝘁 𝗮 𝗻𝘂𝗺𝗯𝗲𝗿 𝗼𝗻 𝗮 𝗱𝗼𝗰𝘂𝗺𝗲𝗻𝘁, 𝗶𝘀 𝗶𝘁 𝗿𝗲𝗮𝗹𝗹𝘆 𝗴𝗼𝗻𝗲?

Often, no. If you draw a black box over a number in a PDF, the number is usually still there underneath. Select the text, copy, paste — it comes right back. The black box only fools your eyes.

I'm building a small tool called SafeFile. You drop in a document, it finds the personal details, and it covers them. It runs entirely in your browser, so the file never leaves your computer.

This week I added support for Japanese ID documents, and I learned three simple things:

1. "What to hide" depends on who you're sending it to. The same health insurance card needs different parts covered for a government bid than for a bank. So the tool now asks "where is this going?" first.

2. The safe way to hide something is to turn the whole page into a flat picture. Then there's nothing underneath to copy.

3. People never miss the big number. They miss the tiny 2-digit code and the QR square in the corner — which contain the same information.

It's free, it's early, and I'm sure it has rough edges. If you ever have to send a copy of an ID somewhere, try it and tell me what felt confusing. That helps me more than a like.

https://slimfile.net/en/blog/jp-ep01-how-to-redact-the-numbers-on-a-qualifica?utm_source=linkedin&utm_medium=social&utm_campaign=ep01

#buildinpublic #privacy #sideproject
```

## E. PDF 사용설명서 (LinkedIn 문서 게시용)
13. `make_episode.mjs`에 `guide_en.pdf` 생성 추가: 1080×1350 세로, **6~8장(최대 10)**, 기존 `carousel.html` 토큰·폰트 재사용. 장 구성: ① 표지(질문 한 줄 = linkedin_en.md 첫 줄의 쉬운 말) ② 문제 장면(검은 상자 아래 글자가 복사되는 캡처 또는 도식) ③~⑥ 단계별 **실제 화면 캡처**(데모 녹화 프레임에서 뽑음: 드롭 → 목적 선택 → 자동 표시 → 결과 저장) + 각 장 한 줄 쉬운 영어 ⑦ 「It's free. Try it and tell me what confused you.」 + 랜딩 URL(UTM linkedin). 트랙 B(데모 없음)는 캡처 대신 카루셀 도식으로 같은 장 수. Playwright `page.pdf()`로 장당 1페이지. 산출: `content/jp/epNN/guide_en.pdf`(≤5MB) + `guide_en_pages/01..NN.png`.
14. import가 `guide_en.pdf`를 `package_assets`에 첨부, 승인 메일에 **첨부파일**로(PDF + demo.mp4 있으면 같이). 메일 본문에 「LinkedIn: 아래 본문을 붙여넣고, 첨부된 PDF를 '문서'로 추가 → 예약 게시(화요일 09:00 JST)」 안내 1줄.
15. ep01~03 전부 생성(ep01은 재import 거부되므로 파일만 생성하고 보고서에 PNG 3장 샘플).

## F. 기타
16. KO 글 Article JSON-LD `inLanguage: "ko"` 추가 — **E-1 스냅샷은 HTML head의 canonical·robots·hreflang만 보므로 영향 없어야 하지만, 스냅샷을 돌려 25/38 동일을 증명**하고 JSON-LD 변경은 별도 테스트로.
17. `finish!`의 `posted` 서브트리: 통째 교체 → `jsonb_set(package, '{posted,x}', …)`·`'{posted,x_url}'` 키 단위. 기존 26+concurrency 테스트 유지.

## G. 테스트·보고
18. 테스트: ko.yml 키 누락 0(뷰 렌더 시 `translation missing` 문자열 없음), preview 라우트 비관리자 404·관리자 200·noindex, summary_ko 없는 import → exit 1, linkedin_en 없는 import → exit 1, linkedin 가드 6패턴 positive/negative, dry_run?(ENV=1 + 키 있음 → true), `/safefile` 301, guide_en.pdf 페이지 수 6~10·크기 ≤5MB.
19. `docs/jp/s9_report.md`: 변경 표, ep02 승인 화면 **한국어** 스크린샷(`docs/jp/s9_samples/`), ep01 재import 거부 출력, guide PDF 1·3·7장 PNG, 배포 체크리스트(s8b_report §5 ⓪~⑧ 재사용 + ⑨ `kamal app exec --reuse 'bin/rails runner "puts XClient.dry_run?"'` 가 true + ⑩ `/safefile` 301 + ⑪ 승인 화면이 한국어로 뜨는지). 실행 위치·복사용 명령 포함.
