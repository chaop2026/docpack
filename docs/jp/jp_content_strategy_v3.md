# SafeFile JP — 콘텐츠 전략 v3.1: 블로그 허브 주간 OSMU 파이프라인 (2026-10-25)

> 전제 문서: `jp_safefile_strategy_v2_2026-10-21.md`(전략), `jp_market_decision_v2_2026-10-22.md`(수익), `jp_forecast_report_2026-10-22.md`(예측 P1~P17), `jp_handoff_2026-10-24.md`(인계). v2에서 확정한 것(§1-1 표)은 바꾸지 않는다. 이 문서는 **콘텐츠 생산·승인·게시 구조**만 정한다.
> 상태: **v3.1 확정** — 교차검증(`codex_review_v3_2026-10-25.md`, AMBER 5건) 반영 완료. `s8_prompt.md`로 구현됨(보고 `s8_report.md`).
>
> ## v3.1 변경 (교차검증 Q1~Q5 반영, 2026-10-25)
> | 출처 | v3 | v3.1 |
> |---|---|---|
> | Q5 | §4 표의 날짜가 「게시(月)」인데 **전부 화요일** | **전 행 하루 앞당김.** ep01 = **2026-10-26(月)**. `topics.json.publish_on` 이 정본이고 테스트가 33개 전부 월요일인지 단언한다 |
> | Q3 | 「X 트윗당 140자」를 X 의 상한으로 서술 | **X 실제 상한은 가중 280**(CJK 2·半角 1·URL 23). **140 은 우리 편집 상한**이고, 둘 다 이름을 붙여 따로 보고한다 |
> | Q3 | 「X 스레드 5트윗 고정」 | **5~6**. 필수문이 CTA 에서 분리되면 6이 된다. 영어 답글을 더하면 6~7 |
> | Q3 | 「X API Free = 월 1,500 쓰기」 | **확정 전제가 아니다.** 실제 요금제·월 쓰기 한도·미디어 업로드 권한을 계정에서 확인하기 전까지 `X_API_DRY_RUN=1` 유지 |
> | Q4 | 「모든 글에 根拠(법령명+施行日) 1개 이상」 | **조건부.** 법적 주장이 있는 글에만 `*.go.jp` 원문 URL + 「確認日: YYYY-MM-DD」. 手順 글에 법령을 억지로 붙이지 않는다(환각 유도) |
> | Q4 | 금지어가 문서·로컬·서버에서 제각각 | **정본 1개** `content/jp/guard_rules.json` — `make_episode.mjs` 와 `JpContentGuard` 가 같이 읽는다 |
> | Q5 | 연말(12-29)·GW(05-04) 「X만」 | **블로그만.** X·LinkedIn 은 다음 주 월요일로 이월(`social_skip`) |
> | Q5 | P15 를 「블로그·X·LinkedIn」으로 다시 읽음 | **P15 원문 보존**(X·YouTube·Instagram). 운영 채널 예측은 **신설 P18** |
> | Q5 | Instagram 보류는 「수치 영향 없음」 | 증거 초과. **운영 가정 변경**으로 기록(예측 보고서 §7) |
> | Q1 | — | KO 42편의 canonical·hreflang·x-default·noindex **불변**을 E-1 스냅샷 테스트로 고정 |
> | Q2 | — | 식별자 **(content_track, content_ep) DB unique**, slug 최초 1회 고정, 승인은 **approved_version** 으로 한 버전을 동결 |

---

## 0. 결론 (한 장)

| 항목 | 결정 |
|---|---|
| 허브 | **자체 블로그** `slimfile.net/ja/blog/:slug` (JA 정본) + `/en/blog/:slug` (EN). 모든 SNS 게시물은 블로그 URL(UTM)로 회귀 |
| 채널 | 블로그 · X(`@safefile_jp`, JA) · LinkedIn(Justin 개인, EN) · YouTube Shorts(채널 개설 후 5주차부터). **Instagram 보류**(계정 없음·B2B 타깃 불일치·Graph API 요건 과다) |
| 주기 | **주 1편**. 토 00:00 KST 패키지 생성·검토 메일 → Justin 주말 승인 1회 → 월 09:00 JST 블로그 → 월 12:00 JST X 스레드 → 화 LinkedIn → (Shorts) 수 |
| 승인 | **주 1회, 1화면**: `/admin/jp/packages/:ep` 미리보기(글 JA/EN · 카루셀 3 · GIF · X 스레드 · LinkedIn 글 · 게시 예정 시각 · KPI 대조표) → 「承認」 버튼 1번 |
| 생산 구조 | **2층**: ① 월 1회 Mac 배치(Claude Code)가 4~5편의 텍스트·카루셀·GIF를 `content/jp/epNN/`에 만들고 `rake content:jp_import`로 서버에 draft 등록 ② 서버 주간 잡이 다음 ep를 꺼내 검토 메일 → 승인 → 자동 게시. **기존 `AutoGenerateBlogPostJob → review 메일 → PublishScheduledPostsJob` 흐름을 그대로 재사용** |
| 게시 자동화 | 블로그 = 기존 잡 · X = X API v2(Free, 서버 잡 `XPublishJob`) · LinkedIn = 승인 메일에 복사용 본문 동봉, Justin 또는 Claude(Chrome) 게시 · YouTube = Data API(S9 이후) |
| 언어 | JA 정본 → EN 파생(LinkedIn·/en/blog). KO 본문은 **쓰지 않는다**(`primary_locale=ja`, KO 폴백 없음) |
| 측정 | UTM `utm_source=blog|x|linkedin|youtube&utm_medium=social|organic&utm_campaign=epNN`, `safe:jp_weekly`, Search Console. P15·P16·P17 대조표를 승인 화면에 자동 첨부 |
| 매출 축 분리 | 파일럿 접촉 메일(P2, 11-22까지 40통)은 콘텐츠와 무관하게 **지금** 시작 (`pilot_targets.md`) |

---

## 1. 왜 블로그가 허브인가

- X·LinkedIn·Shorts는 노출은 주지만 **검색 복리가 없다**. 랜딩 3페이지 방문(P1 ≥300/월, P10 ≥1,500/월)은 검색 유입 없이는 도달 불가. JA 블로그 글 30편은 「資格確認書 マスキング 入札」「免許証 コピー 黒塗り」 같은 롱테일 검색을 받는 유일한 자산이다.
- 블로그 글 1편 = X 스레드 1 + 카루셀 3 + GIF 1 + LinkedIn 1 + Shorts 1의 **원소스**. 파생물은 전부 블로그 URL로 돌아온다 → 채널 성과를 한 곳(UTM)에서 측정.
- 이미 Rails 블로그에 「초안 자동 생성 → 검토 메일 → 승인 → 예약 게시」가 돌고 있다. JP는 **컬럼 3개 + 트랙 1개 + 미리보기 1장**만 더하면 된다.

### 1-1. SEO 최소 요건 (s8 범위)
1. `posts`에 `title_ja / subtitle_ja / body_ja / meta_description_ja` 추가, `primary_locale`(`ko`|`ja`, 기본 `ko`) 추가.
2. `primary_locale=ja`인 글의 canonical = `/ja/blog/:slug`. `/blog/:slug`(KO 주소)는 ja 글이면 `/ja/blog/:slug`로 301. `indexable_locales`는 **본문이 있는 로케일만**(ja, en). hreflang: ja·en·x-default=ja.
3. 게시 불변식 변경: 「published 글은 `primary_locale`의 본문이 있어야 한다」(현재 `body_ko` 고정 → `body_#{primary_locale}`). KO 글에는 영향 없음.
4. sitemap에 `/ja/blog/` 글 포함. JSON-LD `Article` + `FAQPage`(각 글 FAQ 3문). `inLanguage: ja`.
5. 블로그 인덱스 `/ja/blog`는 ja 본문 글만. 카테고리 `privacy` 유지(새 카테고리 안 만듦), 필터는 `primary_locale`.
6. OG: ja 글은 `og:locale=ja_JP`, 이미지 = hero(carousel_1). 랜딩 3페이지 OG도 이번에 같이 고침(§6).

---

## 2. 생산 파이프라인 — 2층 구조

### 2-1. 1층: 월간 배치 (Mac, Claude Code, 월 1회 약 1시간)
- 입력: `content/jp/topics.json`의 다음 4~5편.
- Claude Code가 ep별로 `post_ja.md`(frontmatter + 본문 1,500~2,200자) · `post_en.md` · `faq_ja.md`(3문) 를 §3 규칙서대로 쓰고 → `node scripts/content/make_episode.mjs NN` → 카루셀 3 · GIF/MP4(트랙 A) · `x_thread.md` · `manifest.json`.
- 가드: `make_episode.mjs`의 FORBIDDEN·MUST_LINE 그대로 + **글자 수 계산기**(X 140자: 全角=2·半角=1·URL=23, LinkedIn 1,300자, 제목 32자) — 초과 시 `warnings`에 적고 **자동 축약 금지**(README 규칙).
- 등록: `rake content:jp_import[NN]` → `Post` draft 생성(`primary_locale=ja`, slug=`jp-epNN-<kebab>`, hero=carousel_1.png, `package`(jsonb)=x_thread·linkedin_text·captions·파일 목록), `BlogTopic`(track=jp, ep=NN) `used=true`. 이미 있으면 갱신(멱등). 커밋.
- 왜 Mac인가: Playwright·ffmpeg·로컬 데모 녹화는 서버에 없다. 월 1회 배치면 Justin 개입은 「프롬프트 1번 붙여넣기」뿐.
- 폴백: 서버 주간 잡이 다음 ep의 draft를 **못 찾으면** `BlogGeneratorService.generate_jp(topic)`로 텍스트만 생성(히어로=cover_svg, GIF 없음) → 검토 메일에 「アセット未生成」 표시. 결번은 생기지 않는다.

### 2-2. 2층: 서버 주간 잡 (기존 잡 확장)
| 시각(KST) | 잡 | 동작 |
|---|---|---|
| 토 00:00 | `AutoGenerateBlogPostJob`(jp 트랙, `config/recurring.yml`에 `auto_generate_jp` 추가) | `BlogTopic.jp.next` → 해당 draft Post 찾기(없으면 폴백 생성) → `published_at`=다음 월 09:00 JST → **`BlogMailer.review_requested`**(JP용 템플릿: 미리보기 링크 + X 스레드·LinkedIn 본문 그대로 + KPI 대조표) |
| 주말 | Justin | `/admin/jp/packages/:ep` 열어 확인 → 「承認」 1클릭(= `status: scheduled`, `package.approved_at`). 수정이 필요하면 기존 `improve`(지시문 1줄) |
| 월 09:00 JST | `PublishScheduledPostsJob`(기존) | 블로그 게시. 성공 시 `XPublishJob`을 12:00 JST로 enqueue |
| 월 12:00 JST | `XPublishJob`(신규) | X API v2로 스레드 5트윗 + 1트윗째 미디어(GIF 또는 carousel_1) 게시. 결과 URL을 `package.posted.x`에 기록. 실패 시 `publish_error`와 같은 방식으로 상태에 남기고 메일 |
| 화 | Justin/Claude | LinkedIn: 승인 메일의 `linkedin_text`(EN) 붙여넣기. Claude 세션이 열려 있으면 「게시해」 한마디로 Chrome 게시 |
| 수 | (S9) `YouTubeUploadJob` | Shorts 업로드(채널 개설 후) |

- 승인 1회 원칙: 승인 버튼 1번이 블로그·X 예약을 **동시에** 확정한다. LinkedIn만 수동(공식 API 심사 전).
- 안전장치: `Post.publish_stuck`(기존) + `package.posted.x == nil && published_at < 26h 전` → `rake blog:stuck`에 X 항목 추가.
- 되돌리기: 승인 후 게시 전이면 admin에서 `draft`로 되돌림. X 게시 후 삭제는 수동.

### 2-3. "자동 게시" 수단 결정표
| 채널 | 수단 | 비용/제약 | 결정 |
|---|---|---|---|
| 블로그 | 기존 `PublishScheduledPostsJob` | 없음 | **자동** |
| X | X API v2 | ⚠️ **「Free = 월 1,500 쓰기」는 확정 전제가 아니다**(교차검증 Q3). 앱 등록 1회, 키 4개 `.env`(`X_API_KEY…`) | **코드는 S8 완료, 기본 `X_API_DRY_RUN=1`.** 실제 계정의 요금제·월 쓰기 한도·미디어 업로드 권한을 확인한 뒤에만 켠다 |
| LinkedIn | 공식 API는 앱 심사 | 개인 프로필 게시는 Community Management API 심사 필요 | **수동**(메일 본문 복사). S10에서 재검토 |
| YouTube Shorts | Data API v3(일 10,000 쿼터, 업로드 1,600) | OAuth 1회, 채널 개설 필요 | **S9** |
| Instagram | Graph API(비즈 계정+FB 페이지) | 계정 없음 | **보류** |

---

## 3. 일본어 글쓰기 규칙서 (ブログ正本)

### 3-1. 톤·문체
- です・ます体. 명령형은 「〜してください」만. 「あなた」 사용 안 함(주어 생략 또는 「提出する側」「担当者」).
- 1인칭 브랜드 화법 금지(「弊社」「当社」「私たち」 → 「SafeFile」 또는 무주어). 1인칭 피해담·사건명 금지(v2 §5).
- 단정 금지어: 絶対 / 防ぐ·防げます / 唯一 / 必ず安全 / 完全に / 100%. 대체: 原則 / リスクを下げる / 読み取れなくする / 制限される場合があります.
- 법적 효과는 「〜される場合があります」까지. 통계·수치는 **출처 1개 이상**(법령·告示·省庁 페이지·施行日) 없으면 쓰지 않는다. 추정 수치 금지.
- 서류명은 정식 명칭: 資格確認書 / 健康保険被保険者証(2025-12-01 이후 경과조치 종료 전후 구분) / 運転免許証 / マイナンバーカード(個人番号カード) / 住民票の写し / 在留カード. 약칭은 첫 등장 후 괄호로.
- 숫자 半角, 연도 西暦(和暦는 괄호 병기 가능), 날짜 「2026年10月1日」 형식. 단위 「KB/MB」 半角.

### 3-2. 구조 (블로그 1편)
1. **제목** 32자 이내, 【】로 범위 1개(예: 【入札添付】). 검색 의도 3유형 중 1개로 쓴다: 手順(〜する手順/方法) · 理由(なぜ〜か/〜の仕組み) · 比較(〜と〜の違い/用途別).
2. **리드** 2~3문: 누가·어떤 제출 상황·무엇을 잘못하면 差し戻し되는가. 사건·공포 소구 없음.
3. **H2 3~5개**. 그중 1개는 반드시 **표**(隠す/残す 또는 用途別). 1개는 「手順は3つ」(앱 조작 3단계, 캡션과 동일 문장).
4. **根拠** — **법적 주장이 있을 때만.** 있으면 같은 글에 `*.go.jp` 원문 URL + 「確認日: YYYY-MM-DD」를 반드시 함께 둔다(법령명+조항+施行日). **확인할 수 없으면 법적 주장을 쓰지 않는다** — URL 을 채우려고 근거를 추정하지 않는다. 조작 手順만 다루는 글에는 법령을 붙이지 않는다.
5. **必須文** 「**提出先の指示を必ず確認してください。**」 — 본문 독립 행, 굵게.
6. **FAQ 3문**(H2「よくある質問」, Q는 検索語 형태) → JSON-LD FAQPage.
7. **CTA 1개**: 랜딩 UTM 링크 1줄 + 「ファイルはブラウザの中だけで処理され、サーバーには送信されません。登録も不要です。」
8. 분량 1,500~2,200자(全角). 더미 서류 이미지는 긴 변 ≤800px·「見本」 워터마크.
9. 미출시 기능 언급 금지(一括·保存·共有 등). 출시된 것만: 4종 자동 판정·목적 게이트·띠 마스킹·래스터 평탄화·EXIF 제거·브라우저 내 처리.

### 3-3. 채널별 파생 규칙
| 채널 | 형식 | 글자 수 | 비고 |
|---|---|---|---|
| X 스레드 | 5~6트윗: ①hook ②③④ 핵심 3(이모지 번호 ①②③) ⑤CTA+UTM. 1트윗째에 GIF 또는 carousel_1. 마지막 답글 = 영어 1트윗 | **가중 140**(全角2·半角1·URL 23·결합 이모지 클러스터 2). ⚠️ **X 의 실제 상한은 가중 280** — 140 은 우리 편집 상한이다 | 필수문은 ④ 또는 ⑤에. 넘치면 **별도 트윗**으로 빼서 6트윗이 된다(저자가 쓰지 않은 CTA 를 만들지 않는다) |
| LinkedIn | **개발 일지(dev log)** — Justin 1인칭 EN. 「이번 주 내가 무엇을 만들었고 왜 그렇게 설계했는지」가 본문이고, SafeFile은 그 작업의 맥락으로만 등장. 구조: 첫 줄 = 이번 주 한 일 한 문장(유니코드 볼드) → 설계 결정·배운 것 2~3포인트(기술적 구체성: 어떤 문제를 어떻게 풀었나) → 「이런 걸 서비스하고 있다, 궁금하면 한 번 써보고 피드백 달라」 1문장 → 링크 1개(블로그 EN 또는 랜딩) → 해시태그 3개(#buildinpublic #privacy #rails 류). **금지**: 일본인 대상 광고처럼 읽히는 문장(「日本の入札で…」식 타깃 호소), 기능 나열·세일즈 톤, 브랜드 화법(「SafeFile helps you…」), CTA 2개 이상 | ≤1,300자 | 전문성을 보여주는 곳이지 홍보하는 곳이 아님(Justin 2026-10-25) |
| 카루셀 3장 | 1080×1350: ①제목+hook ②표(隠す/残す) ③手順 3 + CTA | 1장 60자 내 | 기존 템플릿 |
| Shorts | 세로 1080×1920, 20~35초, 자막 JA(영어판은 `?lang=ja` 녹화 + EN 자막) | — | S9 |
| 블로그 EN | JA 의미 번역, 法令名은 JA 병기, 「qualification certificate (資格確認書)」 | 1,200~1,800 words 아님 — JA와 같은 구조 | /en/blog |

### 3-4. 자동 검사 (make_episode.mjs + 서버 `JpContentGuard`)
금지어 · 필수문 · 제목 32자 · 트윗 140자 · LinkedIn 1,300자 · FAQ 3문 존재 · 출처 URL 1개 이상(`根拠` 섹션에 http 링크 또는 법령명+施行日 정규식) · 미출시 기능어(一括/保存して/共有リンク) · 「あなた」 · 「弊社|当社」. 위반 = 검토 메일 상단에 빨간 목록, **자동 수정 없음**.

---

## 4. 30편(33편) 재배열 — 블로그 제목·검색 의도·주차

원칙: `topics.json` 순서(ep=주차) 유지. 바꾼 것은 ① 블로그 제목을 検索語 형태로 정리 ② 검색 의도 태그 ③ 주차→실제 월요일 날짜 ④ 트랙 A/B 교대 유지. ep01~03은 자산이 있으므로 1~3주차에 그대로 쓴다. **1주차 = 2026-10-27(月)**(ep01 X는 이미 게시, 블로그는 신규).

> ⚠️ **아래 표의 날짜는 전부 화요일이다**(교차검증 Q5 실측: 2026-10-27 = 화). **실제 게시일은 이 표에서 하루를 뺀 월요일**이고, 정본은 `content/jp/topics.json` 의 `publish_on` 이다(ep01 = **2026-10-26**). 표는 원문 보존을 위해 그대로 둔다.

| ep | 게시(표기·화) | 의도 | 블로그 제목(JA) | doc | 랜딩 | 파생 |
|---|---|---|---|---|---|---|
| 01 | 10-27 | 手順 | 【入札添付】資格確認書の番号を隠して提出する手順 | 資格確認書 | nyusatsu | 블로그·X(스레드 재게시)·LI |
| 02 | 11-03 | 理由 | 入札添付の資格確認書、「マスキング指示」の読み方 | 資格確認書 | nyusatsu | 블로그·X·LI |
| 03 | 11-10 | 手順 | ChatGPTに契約書を貼る前に個人情報だけ黒塗りする方法 | 契約書 | aimae | 블로그·X·LI |
| 04 | 11-17 | 手順 | 賃貸借契約書を専門家に相談する前の匿名化の手順 | 契約書 | aimae | 블로그·X·LI |
| 05 | 11-24 | 手順 | 電子入札のPDF容量制限と黒塗りを一度に済ませる方法 | 資格確認書 | nyusatsu | +Shorts(채널 개설 후) |
| 06 | 12-01 | 比較 | 補助金精算の添付書類、どこまで隠すか【用途別】 | 資格確認書 | nyusatsu | 전 채널 |
| 07 | 12-08 | 比較 | 源泉徴収票に個人番号がある場合・ない場合の扱い | 源泉徴収票 | nyusatsu | |
| 08 | 12-15 | 手順 | 家族の書類を代理で提出するときに確認すること | 資格確認書 | honnin | |
| 09 | 12-22 | 比較 | マイナンバーカードの表面・裏面、提出が必要なのはどちらか | MNカード | honnin | |
| 10 | 12-29 | 手順 | 運転免許証のコピーを送る前に確認する3つのこと | 免許証 | honnin | 연말 — **블로그만**(X·LI 다음 주 이월) |
| 11 | 01-05 | 比較 | 住民票の写し：用途別に残す項目・隠す項目 | 住民票 | honnin | |
| 12 | 01-12 | 理由 | 「黒塗りしたつもり」が読めてしまう仕組み | — | honnin | |
| 13 | 01-19 | 理由 | 付箋・マスキングテープで隠して撮影する方法の限界 | — | honnin | **P15 검증(01-22)** |
| 14 | 01-26 | 比較 | 「マスキングしてください」と書く提出先、書かない提出先 | — | nyusatsu | |
| 15 | 02-02 | 理由 | 本人確認書類は「最小化」が原則 — 求められた面と項目だけ | — | honnin | |
| 16 | 02-09 | 手順 | フリマ・ネット銀行の本人確認、画像を送る前にできること | 免許証 | honnin | |
| 17 | 02-16 | 手順 | 賃貸契約で身分証のコピーを求められたら確認すること | 免許証 | honnin | |
| 18 | 02-23 | 手順 | 履歴書PDFを相談用に共有する — 連絡先だけ隠す方法 | 履歴書 | aimae | |
| 19 | 03-02 | 比較 | 給与明細を相談に出すとき、口座番号と社員番号の扱い | 給与明細 | aimae | |
| 20 | 03-09 | 比較 | 通帳画像：残高証明として出す場合と相談用の違い | 通帳 | aimae | |
| 21 | 03-16 | 手順 | 在留カード：提出先が求める面を確認してから隠す | 在留カード | honnin | |
| 22 | 03-23 | 比較 | パスポートの番号・MRZを隠してよい場面、いけない場面 | パスポート | honnin | |
| 23 | 03-30 | 理由 | 職務経歴書を匿名で共有するときの考え方 | 職務経歴書 | aimae | |
| 24 | 04-06 | 手順 | スマホだけで：撮影 → 黒塗り → 確認 → 送信 | 免許証 | honnin | Shorts 중심 |
| 25 | 04-13 | 手順 | 透かし「〇〇提出用」の入れ方と、その限界 | 資格確認書 | nyusatsu | **P16·P17 검증(04-22)** |
| 26 | 04-20 | 理由 | 提出した本人確認書類はいつまで残るのか | — | honnin | |
| 27 | 04-27 | 理由 | 「そもそも出さない」という選択 — 最小化原則の実務 | — | honnin | |
| 28 | 05-04 | 手順 | 学生証の画像を送るとき、学生が確認できること | 学生証 | honnin | GW — **블로그만**(X·LI 다음 주 이월) |
| 29 | 05-11 | 比較 | 「サーバーに保存しない」ツールの見分け方 | — | honnin | |
| 30 | 05-18 | 理由 | 2027年4月の犯収法改正で本人確認はどう変わるか | — | honnin | 施行 전 재검증 필수 |
| 31 | 05-25 | 手順 | 副業の本人確認を毎回やり直さないために | — | honnin | |
| 32 | 06-01 | 手順 | 複数書類をまとめて処理する | 資格確認書 | nyusatsu | **一括 미출시면 ep33과 교체** |
| 33 | 06-08 | 理由 | 7か月の振り返りと、よくある黒塗りの落とし穴 | — | honnin | |

- ep30·32는 게시 4주 전 사실 재확인 조건부(`topics.json`에 `verify_before: true`).
- 연말·GW 는 **블로그만** 게시, X·LinkedIn 은 다음 주 월요일로 이월(`topics.json.social_skip`, `JpApproval#x_plan` 이 due_at 을 다음 월요일 12:00 JST 로 민다).
- **P15 는 원문 그대로 둔다**(X·YouTube·Instagram 3채널). Instagram 보류·YouTube 미개설이므로 지금 운영하는 채널로 P15 를 다시 읽는 것은 **예측값 수정**이다. 운영 채널 예측은 **신설 P18**(2027-01-22, 블로그·X·LinkedIn 채널별 실제 게시 누적 ≥24). 13주 × 3채널 = 최대 39 → 달성 가능. **P18 은 P15 의 대체 실적이 아니다.**

---

## 5. 측정·KPI 연결

- UTM 고정: `utm_source={blog|x|linkedin|youtube}&utm_medium={organic|social}&utm_campaign=ep{NN}`. 블로그 내 CTA는 `utm_source=blog`.
- `safe:jp_weekly` 산출(`docs/jp/metrics/YYYY-WW.md`)에 ① 주간 블로그 PV(ja) ② X 게시 URL·노출(수동 입력) ③ 랜딩 유입 UTM별 ④ P1/P10/P15/P16/P17 현재값 vs 예측 → 승인 화면 하단에 그대로 표시.
- Search Console: `/ja/blog/` 색인 수를 주간 지표에 추가(S8에서 sitemap 제출 후).
- 월 22일 예측 리뷰 때 이 표를 그대로 붙인다. 검증일 지난 예측값은 수정 금지(새 행 추가).

---

## 6. 이번 구현(S8)에 같이 끼워 넣는 부수 작업
1. 랜딩 3페이지 OG(title/description/image/locale) → SafeFile 로고·문안. LinkedIn 미리보기 오류 해결.
2. `/safe/` 사이트 파비콘·`icon-*.png`를 `public/safe/brand/`로 교체(**결정: 교체한다** — X 프로필과 동일 로고여야 공유 미리보기가 일치).
3. 미커밋 6건 커밋. `public/safe/작업물/`은 Justin 확인 전까지 `.gitignore` + 배포 제외(public 아래라 공개됨).
4. `content/jp/ep01/manifest.json` `posted.x=true` + 고정 트윗 URL 기록(현재 작업 트리는 false).
5. `content/jp/topics.json`에 `blog_title_ja`·`intent`·`publish_on`·`verify_before` 필드 추가(§4 표 그대로).

## 7. 되돌리기 어려운 결정 — Justin 확인 필요
- (a) Instagram 보류 — 예측 보고서 §9의 「X·YouTube·Instagram」을 「X·YouTube·LinkedIn」으로 바꾼다(보수 예측값에는 0이라 수치 영향 없음).
- (b) X API 앱 등록(Free) — 개발자 계정 생성 1회(전화번호·용도 기재). 거부되면 Chrome 게시 유지.
- (c) `/blog/:slug`→`/ja/blog/:slug` 301(ja 글 한정).
- (d) 사이트 파비콘 교체.
이 4개는 s8 실행 전 「승인」 한 번으로 묶어 결정한다.
