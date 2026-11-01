# 주간 OSMU 콘텐츠 파이프라인 — 운영 인계 문서 (2026-10-27)

> **누가 읽나**: SNS 계정 운영 프로젝트(Rolli·HelloKorean·개인 계정)를 맡는 Claude 세션과 Justin.
> **무엇을 넘기나**: SafeFile JP에서 2026-10-25~27에 만들어 **실제로 돌아가고 있는** 주간 콘텐츠 자동화 — 어디서 어떻게 작동하고, Justin에게 어떻게 알리고, 어떻게 게시되는지 전부.
> **같이 보는 것**: 계정 스킬 `weekly-osmu-pipeline`(절차·원칙·채널 규칙·적용법 §6). 이 문서는 그 스킬의 **구현 실물**이다.
> **코드 위치**: Mac `~/Projects/docpack`(Rails, 공개 저장소 `chaop2026/docpack`), 프로덕션 `slimfile.net`(서버 5.223.92.4, Kamal 배포).

---

## 0. 한 장 요약 — 매주 무슨 일이 일어나는가

```
[월 1회, Mac]  Claude Code가 4~5편 원고·이미지·GIF·PDF 생성 → rake로 서버 DB에 "초안" 등록
      │
[토 00:00 KST, 서버]  주간 잡이 다음 회차 초안을 꺼내 → Justin 메일(chaop2@gmail.com)로 승인 요청
      │
[토~일, Justin]  메일 버튼 → 관리자 화면(한국어) → 내용 확인 → 「승인」 1클릭
      │                                       └→ LinkedIn 글·PDF를 LinkedIn에 예약 게시(화요일)
      │
[월 09:00 JST, 서버]  블로그 자동 공개 (slimfile.net/ja/blog/…) + 「게시 완료」 메일
      │
[월 12:00 JST, 서버]  X 스레드 자동 게시 (현재는 드라이런 = 로그만, 실제 게시 OFF)
```

사람이 하는 일은 **토요일 한 번**(승인 + LinkedIn 예약)뿐이다. 나머지는 서버가 한다.

---

## 1. 작동 장소 — 두 곳

| 장소 | 무엇이 도나 | 왜 거기인가 |
|---|---|---|
| **Mac** (`~/Projects/docpack`) | 원고 생성(Claude Code), 이미지·GIF·PDF 렌더(`make_episode.mjs`: Playwright·ffmpeg), 서버에 초안 올리기(`rake content:jp_import`), 배포(`kamal deploy`) | Playwright·ffmpeg·Claude Code가 서버에 없다. 월 1회만 필요 |
| **프로덕션 서버** (Docker 컨테이너 `docpack-web`, Rails + Solid Queue) | 주간 잡·승인 메일·승인 화면·블로그 공개·X 게시·막힘 감지·KPI | 24시간 켜져 있고 Justin 개입 없이 돌아야 하는 것 |

**Claude(채팅)는 어디에도 끼어 있지 않다.** Claude가 없어도 매주 돌아간다. Claude는 (a) 월간 원고 배치를 Claude Code로 돌릴 때 (b) 승인 화면에서 Justin이 반려한 것을 고칠 때만 필요하다.

---

## 2. 입력 — 회차 하나는 폴더 하나

`content/jp/epNN/` (NN = 회차 = 주차). 한 회차에 들어 있는 파일:

| 파일 | 누가 만드나 | 내용 |
|---|---|---|
| `post_ja.md` | Claude Code(원고) | 블로그 정본(일본어). frontmatter: `title`·`hook`·`bullets` 3·`cta`·`captions` 3·`x_reply`. 본문 1,200~2,200자 |
| `post_en.md` | Claude Code | 영어판(같은 구조) |
| `summary_ko.md` | Claude Code | **승인자용 한국어 요약** 7섹션: 제목 / 요지 / 표 / 근거 / 트윗 / FAQ / 사람이 판단할 한 가지. **없으면 import 거부** |
| `linkedin_en.md` | Claude Code(또는 Justin) | LinkedIn 개발 일지 영어 전문. 자동 조립 아님. **없으면 import 거부** |
| `faq_ja.md` | Claude Code | FAQ 3문(블로그 본문 + JSON-LD FAQPage) |
| `x_thread.md` | `make_episode.mjs`가 생성 | 5~6트윗(hook·3포인트·필수문·CTA+링크) |
| `carousel_1~3.png` | `make_episode.mjs` | 1080×1350 카드 3장(①제목+hook ②표 ③3단계+CTA). 1번이 블로그 히어로 |
| `demo.gif`, `demo.mp4` | `make_episode.mjs` | 트랙 A(데모 있는 회차)만. 로컬 서버에서 Playwright가 실제 조작을 녹화 |
| `guide_en.pdf` + `guide_en_pages/` | `make_episode.mjs` | LinkedIn 문서 게시용 사용설명서 7장(표지 질문 → 문제 장면 → 화면 캡처 4장 → "써보고 알려달라") |
| `manifest.json` | `make_episode.mjs` | 생성 파일 목록·크기·경고·`posted`(어느 채널에 실제로 나갔나 — 사람이 기록) |

**주제 목록**: `content/jp/topics.json` — 33편. 필드 `ep`(=주차)·`track`(A 데모 있음/B 없음)·`title_ja/en`·`blog_title_ja`·`intent`(手順/理由/比較)·`doc`·`purpose`·`landing`·`publish_on`(**월요일 날짜**)·`verify_before`(법 개정 등 사전 확인 필요)·`social_skip`(연말·GW 주 — 블로그만, X·LI는 다음 주)·`status`.

**규칙 정본**: `content/jp/guard_rules.json` — 금지어(사건명·絶対·防ぐ 활용형·完全に·100%·미출시 기능어·弊社/あなた), 필수문(「提出先の指示を必ず確認してください。」 독립 행), 글자 수(제목 32, 트윗 가중 140 편집/280 실제, LinkedIn 1,500), LinkedIn 금지 패턴(광고 문장·세일즈 문구), 법적 주장 시 출처 요구. **Mac의 JS(`guard_rules.mjs`)와 서버의 Ruby(`JpContentGuard`)가 같은 파일을 읽는다** — 한쪽에만 있는 규칙이 생기지 않게.

---

## 3. 월간 배치 (Mac, 사람 1분 + Claude Code 1~2시간)

Claude Code 프롬프트 한 줄로 시작한다(실행 위치: `[새 Claude Code 세션]` · `~/Projects/docpack`):

```
content/jp/topics.json 의 ep04~ep08 원고를 docs/jp/jp_content_strategy_v3.md §3 규칙으로 작성해(post_ja·post_en·summary_ko·linkedin_en·faq_ja). 각 회차 node scripts/content/make_episode.mjs NN → bin/rails content:jp_import[NN]. guard 위반 0이어야 하고 자동 수정 금지. 커밋.
```

`make_episode.mjs NN`이 하는 일: frontmatter 읽기 → 가드 검사 → X 스레드 조립 + 가중 길이 계산 → 카루셀 3장 렌더 → (트랙 A) 로컬 Rails 서버 띄워 `/safe/?lang=ja&purpose=…`를 Playwright로 조작하며 프레임 캡처 → GIF/MP4 → 가이드 PDF 7장 → `manifest.json`. 실패해도 나머지는 만들고 manifest에 `demo: "failed: …"`.

`bin/rails content:jp_import[NN]`이 하는 일: 폴더를 읽어 서버 DB `posts`에 **초안 1행** upsert. 키는 `(content_track='jp', content_ep=NN)`(DB unique). 이미지·GIF·PDF는 ActiveStorage 첨부. 본문 HTML 변환. 가드 재검사 결과를 `package.guard`에 저장. **승인된 회차는 덮어쓰지 않는다**(exit 2, 충돌만 기록). 프로덕션에 넣을 땐 `kamal app exec --reuse 'bin/rails content:jp_import[NN]'`.

---

## 4. 서버 주간 잡 — 토요일 00:00 KST

`config/recurring.yml` → `AutoGenerateJpPostJob` (Solid Queue recurring, `every Saturday at 0am Asia/Seoul`).

1. 다음 회차 선정: `BlogTopic.next_jp` = 아직 검토 메일을 안 보낸 jp 토픽 중 `publish_on`이 **9일 이내**인 것, `publish_on` 순. 한 회차가 승인 안 돼도 다음 주는 다음 회차로 **전진**한다(막히지 않음). 건너뛴 회차는 관리자 배너·`rake blog:stuck`에 「미승인 기한 초과」로 뜬다.
2. 그 회차의 초안이 DB에 있으면 → `published_at = publish_on 09:00 JST`(지났으면 다음 월요일) 설정.
3. 초안이 **없으면**(월간 배치를 안 돌린 경우) → Claude API(`claude-sonnet-4-6`)로 텍스트만 생성(요약·트윗·LinkedIn 포함), 히어로는 SVG, GIF 없음. 메일 제목에 「[アセット未生成]」. 결번은 생기지 않는다.
4. `verify_before` 회차는 사람이 「확인 완료」를 누르기 전엔 게시 시각을 잡지 않는다.
5. **승인 요청 메일 발송**(회차당 주 1회).

---

## 5. 알림 — 전부 메일, 전부 chaop2@gmail.com

| 메일 | 언제 | 내용 |
|---|---|---|
| **`[SafeFile JP] 제NN회 승인 요청: {제목}`** | 토 00:00 | 파란 버튼(승인 화면 링크) · 공개 예정(블로그 월 09:00 JST / X 월 12:00 JST / LinkedIn 화요일 수동) · 글 요지 **한국어** · X 스레드 6줄 + 각 줄 한국어 · LinkedIn 본문(복사용) · FAQ + 한국어 · 「사람이 판단할 한 가지」(노란 박스) · 가드 결과 · KPI 대조표 · **첨부: guide_en.pdf, demo.mp4** |
| `[SlimFile 블로그] 새 글 발행: …` | 월 09:00 공개 직후 | 게시 완료 알림 |
| `발행 실패 N건` | 공개 못 한 경우 | 어떤 글이 왜 막혔는지 |
| `X 전송 결과 불명` | X 게시 중 응답 유실 | 사람이 타임라인 보고 「전송됨으로 기록」/「미전송으로 재개」 중 택1 |
| `X 전송 실패` | X API 거부 | 사유 |

텔레그램·Claude 앱·Notion 등 **다른 채널은 쓰지 않는다**(승인 통로를 하나로). 메일이 안 오면 `rake blog:stuck`/`rake jobs:failed`로 상태를 본다 — 메일이 죽어도 상태는 DB에 남는 설계.

---

## 6. 승인 화면 — `https://slimfile.net/admin/jp/packages/{NN}`

관리자 로그인(블로그 관리와 같은 계정). **전부 한국어**. 위에서 아래로:

1. 제목·부제·공개 주소·상태(초안/예약/공개)
2. **공개 예정표** + 바로 아래 **「승인」 버튼**(맨 아래에도 하나 더). 옆에 「누르면 월요일 09:00 JST에 블로그가 공개되고 X 스레드가 예약됩니다. 승인 전에는 아무것도 공개되지 않습니다.」
3. 「공개 페이지 미리보기」 링크 → 실제 공개 레이아웃으로 렌더(관리자만, 비로그인 404)
4. 글 본문(JA 렌더) + 바로 아래 **한국어 요지**, 영어판
5. 카루셀 3장, GIF
6. X 스레드 6줄(각 줄 가중 글자 수 + 한국어)
7. LinkedIn 본문(복사용) + 「예약 게시 → 화요일 09:00 JST」 안내
8. FAQ + 한국어
9. 가드 결과(위반 있으면 승인 버튼 비활성)
10. **「사람이 판단할 한 가지」** 노란 박스 — 이 글에서 Justin이 실제로 책임지는 주장 1개
11. KPI 대조표(예측 P1·P10·P15·P16·P17·P18 vs 현재)
12. 「승인」 / 「반려」

**「승인」을 누르면**: 상태 `scheduled` + `approved_at` + **`approved_version`**(제목·본문·스레드·LinkedIn·자산·게시 시각의 SHA256 지문) + X 대기 상태(`x.state=pending, due_at=published_at+3h`)가 **한 트랜잭션**으로 기록. 이후 누가 본문을 고치면 지문이 어긋나 X는 스스로 멈춘다(blocked). 고치려면 「반려」→ 수정 → 재승인.

**「반려」를 누르면**: 초안으로 복귀, 승인 지문 삭제, X 취소. 다음 토요일에 다시 메일이 오거나, Claude에게 "ep NN 고쳐"라고 하면 수정 후 재import.

---

## 7. 게시 — 채널별

### 블로그 (자동)
`PublishScheduledPostsJob`(매일 09:00 KST=JST)이 `scheduled`이고 시각이 된 글을 `published`로. 주소 `slimfile.net/ja/blog/{slug}`(영어판 `/en/blog/…`). canonical·hreflang·sitemap·JSON-LD(Article+FAQ) 자동. KO 블로그 42편의 색인 신호는 스냅샷 테스트(E-1, 38항목)로 불변 보장. 공개 후 X 잡을 enqueue하고 상태를 DB에 먼저 적는다(enqueue가 실패해도 `rake blog:x_pending`으로 복구).

### X (자동 — 현재 드라이런)
`XPublishJob`(월 12:00 JST). 설계의 핵심은 **같은 트윗을 두 번 올리지 않는 것**:
- 짧은 트랜잭션으로 **소유권 선점**(`worker_token`, 30분 TTL) → 루프는 트랜잭션 밖
- 트윗마다: `sending` 커밋 → API 호출 → `tweet_id`·`done` 커밋. 각 쓰기는 토큰 조건부 UPDATE 1회
- 재실행 시 `sending`으로 남은 건 「결과 불명」으로 승격하고 **멈춤**(자동 재전송 금지, 메일로 사람 확인). 재개 권한은 사람이 확인한 트윗 번호 목록(`resume_seqs`)에만
- 승인 지문 없거나 불일치 → blocked(fail-closed)
- 미디어: 1트윗째에 GIF(없으면 카루셀 1). 미디어 업로드 실패 시 텍스트만 올리지 않음
- **현재 `X_API_DRY_RUN=1`이 `config/deploy.yml`에 선언**되어 로그만 남긴다. X 키 4개(`X_API_KEY/SECRET/ACCESS_TOKEN/ACCESS_SECRET`)를 넣어도 이 줄을 지우는 커밋 없이는 실제 게시 불가. 실제 게시를 켜는 절차: X 개발자 앱 등록 → 요금제·월 쓰기 한도·미디어 업로드 권한 확인 → `.env.production.local`에 키 4개 → `deploy.yml`에서 `X_API_DRY_RUN` 줄 삭제 커밋 → 배포 → `kamal app exec --reuse 'bin/rails runner "puts XClient.dry_run?"'`가 false인지 확인.
- 3라운드 교차검증(S8→S8b→S8c)으로 크래시·동시 실행·응답 유실 경로를 닫았다. 테스트는 실제로 크래시를 주입한다.

### LinkedIn (수동 — Justin)
공식 API는 앱 심사가 필요해 자동화하지 않는다. 메일(또는 승인 화면)의 LinkedIn 본문을 복사 → 첨부된 `guide_en.pdf`를 "문서"로 추가(또는 `demo.mp4`) → LinkedIn **예약 게시**로 화요일 09:00 JST. 게시 후 글 주소를 승인 화면에 기록하면 P18에 집계된다.
규칙(전략 §3-3, 2026-10-25·27 개정): **개발 일지** — Justin 1인칭, "이번 주 내가 만든 것·설계 결정·배운 것", 서비스는 맥락으로만, 쉬운 말(전문용어 0, 문장 15단어 안팎, 첫 줄은 독자도 궁금할 질문), 끝은 "써보고 뭐가 헷갈렸는지 알려달라", 링크 1·해시태그 3, ≤1,500자. 금지: 특정 국가 대상 광고 문장, 기능 나열, 브랜드 화법, CTA 2개 이상. 시각물 필수(PDF ≤10장 또는 MP4 또는 사진 — **GIF는 LinkedIn에서 움직이지 않는다**).

### YouTube Shorts / Instagram
미구현. YouTube는 Data API로 S9 이후 예정(채널 미개설). Instagram은 비즈니스 계정+FB 페이지 요건과 B2B 타깃 불일치로 **보류**.

---

## 8. 측정·막힘 감지

- `safe_events` 테이블에 랜딩 조회·CTA 클릭이 쌓인다(브라우저 `sendBeacon`, 개인정보 없음). 유입 채널은 `?utm_source=` → 허용값 7개로 매핑.
- `rake safe:jp_weekly` → `docs/jp/metrics/YYYY-WW.md`: 랜딩 조회·블로그 PV·X URL·UTM별 유입·예측 대조(P1 랜딩 월 방문 / P10 / P15 원래 3채널 / P16 SNS 경유 비중(블로그 자체 유입은 분자에서 제외) / P17 YouTube / **P18 블로그·X·LinkedIn 채널별 게시 누적 ≥24**(2026-10-25 신설)). 같은 값이 승인 메일·화면에도 뜬다.
- `rake blog:stuck`(exit 1이면 문제): 예약됐는데 26시간 지나도 공개 안 됨 / X가 due 2시간 지나도 미완 / 미승인 회차 기한 초과. `/admin/posts` 상단 배너도 같은 것을 보여준다. **알림 채널(메일)이 죽어도 상태로 드러나게** 만든 것.

---

## 9. 운영 루틴 (Justin)

| 주기 | 할 일 | 시간 |
|---|---|---|
| **매주 토·일** | 메일 → 승인 화면 → 한국어 요약·「사람이 판단할 한 가지」 읽기 → 「승인」. LinkedIn 본문+PDF 예약 게시 | 10분 |
| **월 1회** | Claude Code에 월간 배치 프롬프트 1줄(§3) → 끝나면 `kamal app exec … content:jp_import[NN]` 4~5회 | 5분 + 대기 |
| 수시 | 반려한 회차: Claude에게 "ep NN 첫 줄 고통으로 고쳐" 등 → 수정 → 재import | — |
| 매월 22일 | 예측 보고서 리뷰(`safe:jp_weekly` 표를 그대로) | 20분 |

---

## 10. 다른 서비스(Rolli·HelloKorean·개인)로 옮길 때

**그대로 가져갈 수 있는 것** (스택 무관):
- 설계·절차·원칙 → 스킬 `weekly-osmu-pipeline` §1~§6 (적용법 §6: "weekly-osmu-pipeline을 <서비스>에 적용해. 타깃·정본 언어·채널·승인 요일·주제 N편" 한 문장)
- 회차 폴더 구조(§2), `topics.json` 스키마, `guard_rules.json`의 **형식**(값은 서비스별)
- `scripts/content/make_episode.mjs` + `templates/carousel.html`·`guide.html`(Node·Playwright·ffmpeg만 있으면 어디서나) — 디자인 토큰·언어·URL만 바꾸면 됨
- 승인 메일·승인 화면의 **구성**(§5·§6) — 승인자 언어 요약, 「사람이 판단할 한 가지」, 지문 동결
- X 게시의 상태 기계(§7: claim → sending → done, unknown 정지, resume 범위 한정)
- LinkedIn 개발 일지 규칙, 쉬운 말 규칙, 채널별 시각물 규칙

**다시 만들어야 하는 것** (docpack Rails에 종속):
- `AutoGenerateJpPostJob`·`PublishScheduledPostsJob`·`XPublishJob`·`JpImport`·`JpApproval`·`JpContentGuard`·`JpEpisodeSource`·`BlogMailer`·`Admin::JpPackagesController` — HelloKorean(Next.js)이나 Rolli는 같은 역할을 그쪽 스택으로. 설계는 §4~§7 그대로 옮기면 된다.
- 블로그가 **허브**여야 하므로, 그 서비스에 자체 블로그(DB·관리 화면·예약 공개)가 먼저 있어야 한다. 없으면 그게 1단계.

**개인 계정(LinkedIn 등)만이면**: 서버 없이 Mac 배치(§3) + 메일 대신 로컬 폴더 미리보기로도 충분하다. 승인 1회·채널별 규칙·시각물 필수만 지키면 된다.

---

## 11. 알려진 한계·다음 작업 (S10, 급하지 않음)

1. **`utm_` 파라미터 폐기** — Justin의 Chrome(차단 확장)에서 `?utm_*` 붙은 주소가 브라우저 단계에서 막혔다(서버는 정상 200). 공유 링크는 깨끗한 주소로 통일했고, 계측은 `?via=x&ep=NN`으로 바꿀 것(jp.js·safe_events·make_episode·KPI).
2. **X 문안 규칙** — 첫 줄은 반드시 **상대의 고통**(반려·마감 전날 다시 하기) → 원인 → 해결. "검은 상자 밑에 글자가 남는다" 같은 기술적 신기함을 첫 줄로 쓰지 말 것. 영어 답글은 본 트윗의 1:1 영어판. ep02~의 `x_thread`가 이 규칙 전에 쓰였으므로 토요일 승인 때 반려될 수 있음 → 규칙을 `guard_rules.json`·전략 §3-3에 넣고 원고 재작성.
3. X 실제 게시 ON(§7 절차) — 요금제 확인 후.
4. YouTube Shorts 채널 개설 + `YouTubeUploadJob`.
5. ep04~33 원고 미작성(월간 배치로).
6. 일본 변호사 검토 없음(법적 주장은 「制限される場合があります」 수준으로 제한 중).

---

## 12. 이번 3일에서 배운 것 (다음 서비스에서 처음부터 지킬 것)

- **승인자가 읽을 수 없는 언어로 된 패키지는 승인이 아니다** → 요약을 "파생물"이 아니라 "입력"으로(없으면 import 거부).
- **홍보 문장은 아무도 안 읽는다** → 첫 줄은 독자의 고통이나 질문. 기능 나열·"무료·가입 불필요"로 시작하지 않기.
- **외부 확인은 실제 공유 주소(파라미터 포함)로** → utm 차단을 깨끗한 주소로만 확인해서 놓쳤다.
- **`with_lock` 안의 `update_column`은 커밋이 아니다** → 외부 게시처럼 되돌릴 수 없는 호출은 트랜잭션 밖에서, 호출 전후 각각 커밋.
- **`.env`에 넣은 값이 `deploy.yml` env 목록에 없으면 컨테이너에 안 들어간다** → 안전장치는 deploy.yml에 선언하고 테스트로 강제.
- **달력 의존 테스트**(요일·날짜 계산)는 시계를 고정.
- **예측 지표의 채널 정의를 바꾸면 원문은 보존하고 새 지표를 추가**(P15 → P18).
- 교차검증(ChatGPT/Codex)은 묻지 않고 매 라운드 — S8에서 3라운드 동안 매번 새 결함 1개를 찾았다.

---

## 13. 파일 색인 (Mac `~/Projects/docpack`)

| 역할 | 경로 |
|---|---|
| 전략·규칙 정본 | `docs/jp/jp_content_strategy_v3.md` (v3.1) |
| 이 인계 문서 | `docs/jp/osmu_pipeline_handoff_2026-10-27.md` |
| 작업 이력·교차검증 | `docs/jp/s8_report.md`, `s8b_report.md`, `s8c_report.md`, `s9_report.md`, `codex_review_*.md` |
| 다음 작업 | `docs/jp/s9_todo.md`(S10 항목 포함) |
| 회차 콘텐츠 | `content/jp/epNN/`, `content/jp/topics.json`, `content/jp/guard_rules.json` |
| 생성 스크립트 | `scripts/content/make_episode.mjs`, `guard_rules.mjs`, `templates/{carousel,guide}.html`, `README.md` |
| 서버 코드 | `app/jobs/{auto_generate_jp_post_job,x_publish_job,publish_scheduled_posts_job}.rb`, `app/services/jp_*.rb`, `app/controllers/admin/jp_packages_controller.rb`, `app/views/admin/jp_packages/`, `app/views/blog_mailer/jp_*`, `app/mailers/blog_mailer.rb`, `lib/x_client.rb`, `lib/tasks/{content,blog,safe}.rake`, `config/recurring.yml`, `config/locales/ko.yml`(`jp_admin.*`) |
| 배포·환경 | `config/deploy.yml`(`X_API_DRY_RUN`), `.env.production.local`(키 이름만: `X_API_KEY X_API_SECRET X_ACCESS_TOKEN X_ACCESS_SECRET`) |
| 비공개(커밋 금지) | `docs/jp/private/`(파일럿 실명 명단·교차검증 입력) |
| 계정·채널 | X `@safefile_jp`(고정 트윗 2115055040432083148), LinkedIn Justin 개인, 블로그 `slimfile.net/ja/blog`, 승인 화면 `slimfile.net/admin/jp/packages/:ep` |
