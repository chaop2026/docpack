warning: `--full-auto` is deprecated; use `--sandbox workspace-write` instead.
2026-10-20T15:10:24.262272Z ERROR codex_models_manager::cache: failed to load models cache: missing field `base_instructions` at line 139 column 5
OpenAI Codex v0.146.0
--------
workdir: /Users/sunghoon/Projects/docpack
model: gpt-5.6-sol
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR]
reasoning effort: none
reasoning summaries: none
session id: 01a159dd-1a11-7262-be53-35fd7e26498d
--------
user
당신은 일본 개인정보 보호 실무와 B2C 웹서비스 성장 전략에 정통한 독립 검토자입니다. docs/jp/jp_safefile_strategy_2026-10-20.md 와 docs/jp/jp_documents_catalog.json 을 읽고, 이를 작성한 Claude와 독립적으로 비판적 검토를 하세요. 필요하면 public/safe/index.html 의 실제 탐지 코드도 참고하세요. 칭찬은 생략하고 틀린 것·빠진 것·위험한 것만 쓰세요. 각 항목은 "문제 / 근거 / 수정안" 형식, 근거 없으면 "확인 불가"라고 명시.
1. 사실 오류: 타임즈카 유출 수치·날짜, 告知要求制限 시행일과 대상, 資格確認書 마스킹 항목, マイナンバーカード 裏面 취급, IC칩 본인확인 2027년 4월
2. 카탈로그 jp01~jp13 필드 누락·오류, always/optional 분류 타당성, 추가해야 할 문서(年金手帳, 印鑑証明, 課税証明, 障害者手帳 등)
3. pii_patterns 정규식의 오탐·미탐 위험(住所·電話·記号番号 앵커), 전각/漢数字 처리
4. 타깃 "25–39 転職·引越し·副業" 적정성, 유료 "マスキング済み書類ボックス"(월 300~500엔) 현실성
5. 더미 카드 이미지(免許証·マイナカード 레이아웃 동일, 「見本」 표기, 문양 미재현)의 일본 법적 리스크와 안전 제작 조건
6. X·YouTube Shorts·Instagram Reels 선택 타당성, 30편 주제 중 어색하거나 위험한 제목, 타임즈카 피해자 소재의 적절성
7. 실행 순서 S1~S7과 "S5 통과 전 홍보 금지" 게이트 타당성, 2주 내 S3~S5가 비현실적이면 대안
마지막에 "즉시 수정해야 할 상위 5개"를 우선순위로 요약. 일본어 고유명사는 그대로, 답변은 한국어로. 파일을 수정하지 말고 검토 결과만 출력하세요.
hook: SessionStart
hook: SessionStart Completed
hook: UserPromptSubmit
hook: UserPromptSubmit Completed
codex
두 문서와 실제 탐지 코드를 대조하고, 법령·공식 안내처럼 시점에 따라 달라질 수 있는 사실은 현재 일본의 1차 자료로 검증하겠습니다. 파일은 수정하지 않습니다.
codex
웹 검증이 포함되므로 `firecrawl-search` 지침을 사용해 공식 원문 중심으로 사실관계를 확인하겠습니다. 이 지침 때문에 먼저 검색 방식과 인용 기준을 확인합니다.
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "sed -n '1,240p' /Users/sunghoon/.agents/skills/firecrawl-search/SKILL.md" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
---
name: firecrawl-search
description: |
  Web search with full page content extraction. Use this skill whenever the user asks to search the web, find articles, research a topic, look something up, find recent news, discover sources, or says "search for", "find me", "look up", "what are people saying about", or "find articles about". Returns real search results with optional full-page markdown — not just snippets. Provides capabilities beyond Claude's built-in WebSearch.
allowed-tools:
  - Bash(firecrawl *)
  - Bash(npx firecrawl *)
---

# firecrawl search

Web search with optional content scraping. Returns search results as JSON, optionally with full page content.

## When to use

- You don't have a specific URL yet
- You need to find pages, answer questions, or discover sources
- First step in the [workflow escalation pattern](firecrawl-cli): search → scrape → map → crawl → interact

## Quick start

```bash
# Basic search
firecrawl search "your query" -o .firecrawl/result.json --json

# Search and scrape full page content from results
firecrawl search "your query" --scrape -o .firecrawl/scraped.json --json

# News from the past day
firecrawl search "your query" --sources news --tbs qdr:d -o .firecrawl/news.json --json

# Programming question: search GitHub issues, merged PRs, READMEs, and docs
firecrawl search "your query" --categories developer -o .firecrawl/developer.json --json
```

## Developer search

`--categories developer` adds an index built for coding agents. It covers GitHub
issues, merged pull requests, repository READMEs, and curated documentation
sites. Use it for a programming question: an error message, an API contract, a
library behaviour, or a known bug.

The hits arrive in their own `data.developer` group beside `data.web`. Each hit
holds `url`, `title`, and `description`, where `description` is the matched
passage. Read the passages with
`jq -r '.data.developer[] | .url, .description' .firecrawl/developer.json`.

The dedicated `firecrawl developer` command searches only that index and keeps
the full matched passages:

```bash
# Developer search only, with full passages
firecrawl developer "your query" --limit 10 -o .firecrawl/developer.json --json
```

Each result holds `id`, `type` (`issue`, `pull_request`, `readme`, `doc`),
`url`, `title`, and `passages`. Read them with
`jq -r '.results[] | .url, .passages[].text' .firecrawl/developer.json`.

## Options

| Option                                         | Description                                   |
| ---------------------------------------------- | --------------------------------------------- |
| `--limit <n>`                                  | Max number of results                         |
| `--sources <web,images,news>`                  | Source types to search                        |
| `--categories <github,research,pdf,developer>` | Filter by category                            |
| `--tbs <qdr:h\|d\|w\|m\|y>`                    | Time-based search filter                      |
| `--location`                                   | Location for search results                   |
| `--country <code>`                             | Country code for search                       |
| `--scrape`                                     | Also scrape full page content for each result |
| `--scrape-formats`                             | Formats when scraping (default: markdown)     |
| `-o, --output <path>`                          | Output file path                              |
| `--json`                                       | Output as JSON                                |

## Tips

- **`--scrape` fetches full content** — don't re-scrape URLs from search results. This saves credits and avoids redundant fetches.
- Always write results to `.firecrawl/` with `-o` to avoid context window bloat.
- Use `jq` to extract URLs or titles: `jq -r '.data.web[].url' .firecrawl/search.json`
- Naming convention: `.firecrawl/search-{query}.json` or `.firecrawl/search-{query}-scraped.json`

## Send feedback after every search (refunds 1 credit)

Search costs 2 credits. After you've actually used the results (or decided they were useless), send structured feedback with `firecrawl search-feedback <id>`. The first feedback per search refunds 1 credit and helps us improve search quality. **Do this once per search**, in the background, after you finish processing the results — it does not block your main task.

**Opt out:** if `FIRECRAWL_NO_SEARCH_FEEDBACK=1` (or `FIRECRAWL_DISABLE_SEARCH_FEEDBACK=1`) is set, the CLI silently skips the call and never sends anything. Respect that — do not try to work around it. (Team admins can also disable this server-side; the API will return `feedbackErrorCode: "TEAM_OPTED_OUT"` and the CLI will exit 0 silently.)

**Rules to know before you call this:**

- **Time window:** must be sent within ~2 minutes of the search. Late feedback is rejected.
- **`--missing-content` is the most important field.** It's a list of _specific pieces_ of content you expected but did not find. One topic per entry — do not pack multiple topics into one string. These aggregate across teams and tell us what to index next.
- **Substantive content required** (zero-effort feedback is rejected with HTTP 400):
  - `good` → must include at least one `--valuable-sources` entry.
  - `partial` → must include `--valuable-sources` or `--missing-content`.
  - `bad` → must include `--missing-content` or `--query-suggestions`.
- **Daily refund cap (per team, per UTC day, default 100 credits).** Once your team has been refunded 100 credits today, further submissions still record feedback but no longer refund credits. The response includes `creditsRefundedToday` / `dailyRefundCap` / `dailyCapReached`. **When `dailyCapReached: true`, stop calling `search-feedback` for the rest of the UTC day** — it won't refund anything and you're wasting bandwidth.
- **Idempotent:** re-submitting for the same search id returns success but no extra refund.
- **`--silent &`** is the right pattern — exit code 0 even on failure, so a rejected/expired call never crashes your pipeline.

Read the search response's `id`:

```bash
SEARCH_ID=$(jq -r '.id' .firecrawl/search-react-hooks.json)
```

Then send feedback. Pick the rating that matches what actually happened:

```bash
# Results were useful, with notes on what was still missing
firecrawl search-feedback "$SEARCH_ID" \
  --rating good \
  --valuable-sources '[{"url":"https://react.dev/reference/react/hooks","reason":"Most authoritative"}]' \
  --missing-content '[
    {"topic":"useDeferredValue","description":"No example of useDeferredValue with Suspense"},
    {"topic":"useTransition","description":"No coverage of useTransition for routing"}
  ]' \
  --query-suggestions "Boost react.dev for queries about react hooks" \
  --silent &

# Results were partially useful — multiple missing topics, one entry per topic
firecrawl search-feedback "$SEARCH_ID" \
  --rating partial \
  --missing-content '[
    {"topic":"useDeferredValue"},
    {"topic":"useTransition","description":"Need React 18+ examples"},
    {"topic":"Server Components hooks"}
  ]' \
  --silent &

# Quick form — repeat --missing-content or use comma-separated topics
firecrawl search-feedback "$SEARCH_ID" \
  --rating bad \
  --missing-content "official api reference: missing v2 endpoints" \
  --missing-content "code examples in python" \
  --silent &
```

**`--missing-content` accepts:**

- JSON array of `{topic, description?}` objects (richest, preferred)
- `"topic: description"` strings (shorthand)
- Plain `"topic1, topic2, topic3"` (when you only have topic names)
- Repeated `--missing-content` flags

`--silent` suppresses output and `&` runs it in the background so feedback never blocks you.

## See also

- [firecrawl-scrape](../firecrawl-scrape/SKILL.md) — scrape a specific URL
- [firecrawl-map](../firecrawl-map/SKILL.md) — discover URLs within a site
- [firecrawl-crawl](../firecrawl-crawl/SKILL.md) — bulk extract from a site

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "wc -l docs/jp/jp_safefile_strategy_2026-10-20.md docs/jp/jp_documents_catalog.json public/safe/index.html && sed -n '1,260p' docs/jp/jp_safefile_strategy_2026-10-20.md && sed -n '1,300p' docs/jp/jp_documents_catalog.json" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
     175 docs/jp/jp_safefile_strategy_2026-10-20.md
      95 docs/jp/jp_documents_catalog.json
    1957 public/safe/index.html
    2227 total
# SafeFile 일본 진출 전략 v1 (2026-10-20)

> 목적: "회사는 지켜주지 않는다. 서류는 내가 가린다"는 일본의 현재 정서를 SafeFile 유입으로 전환
> 범위: 타깃 확정 → 문서 카탈로그 → 제품 요구사항 → 더미데이터 → 콘텐츠 3개월 → 운영

---

## 1. 지금이 기회인 이유 (팩트 기반)

| 신호 | 내용 | 출처 |
|---|---|---|
| 타임즈카 유출 | 2026-09-25 발각. 최대 660만 계정, 그중 **면허증·학생증·주민표 이미지 약 160만 건** | 共同通信 10/3, 週刊アスキー 9/29 |
| 집단소송 | 변호사 사이트 등록 **1만 5천 명(10/2 기준)** | 共同通信 |
| 행정 반응 | 경시청·면허시험장에 재교부 상담 쇄도, 후쿠시마현 특별 재교부 접수(10/10) | bsrweb 10/8, 아메바 블로그 |
| 연쇄 유출 | 10월 들어 大和証券·物語コーポレーション 등 추가 발표 | bsrweb 10/8 |
| 제도 공백 | IC칩 본인확인 의무화는 **2027년 4월** → 그때까지 "이미지만으로 계좌 개설" 창구 잔존 | 週刊アスキー |
| 법적 마스킹 의무 | 保険証·資格確認書 사본 제출 시 **保険者番号·記号·番号·枝番·QR** 마스킹 (告知要求制限, 2020-10-01 시행) — 지자체·은행·카드사가 "마스킹해서 내라" 안내 중 | 大阪府, 東京都共済, PayPay銀行, SoftBank |

**핵심 통찰**: 일본에는 이미 "黒塗り(구로누리)"라는 **의무이자 관행**이 있고, 사람들은 지금 그것을 **付箋·마스킹테이프·스마트폰 편집앱**으로 손수 하고 있다. 경쟁 도구는 B2B eKYC(ProTech AI Masking, TRUSTDOCK)뿐이고 **개인용 무료 웹툴은 공백**. "黒塗りしたつもりが透ける" 공포(모자이크·반투명 복원)도 커뮤니티에서 반복 언급 → "이미지로 평탄화해서 복원 불가"가 SafeFile의 기술 메시지.

---

## 2. 타깃 — 연령이 아니라 "제출을 피할 수 없는 순간"으로 정의

| 순위 | 세그먼트 | 연령 중심 | 반드시 제출하는 서류 | 왜 1순위인가 | 콘텐츠 훅 |
|---|---|---|---|---|---|
| **1** | 転職・引越し・副業을 동시에 겪는 사회초년~중견 | **25–39** | 履歴書·職務経歴書, 免許証, 資格確認書/保険証, 住民票, 源泉徴収票, 賃貸契約書 | 제출 빈도 최다, 스마트폰으로 서류 찍어 보내는 세대, 타임즈카 피해자 다수(기사 인터뷰 27세·34세 회사원) | "送る前に30秒で黒塗り" |
| 2 | 프리마·중고거래·크라우드소싱 본인확인 | 20–34 | 免許証, マイナカード表面, 在留カード | 메르카리 2025년 고액거래 본인확인 의무화 → 신규 18%가 에러 경험, "画像を送るのが怖い" 질문 다수 | "メルカリに免許証を送る前に" |
| 3 | 건설·개인사업자·관리자 (입찰·허가 서류) | 35–55 | 保険証写し, 標準報酬決定通知書, 住民票 | **법적 마스킹 의무** + 지자체가 견본 PDF 배포 → 검색 의도 명확, 재제출 공포 | "入札書類の保険証マスキング、再提出なしで" |
| 4 | 외국인 거주자 (영어 버전 대상) | 20–40 | 在留カード, パスポート, 住民票 | 영어 버전 운영 요구에 부합, 일본어 서류를 영어 UI로 가릴 수 있는 유일한 툴 포지션 | "Redact your 在留カード in English UI" |

**결정**: 1순위 세그먼트(25–39)를 메인, 3순위(건설·사업자)를 SEO 롱테일로 병행. 2·4는 콘텐츠만.

### 저장 기능 → 수수료 정책 (요청 반영)
- 무료: 업로드→마스킹→다운로드(서버 미저장 유지)
- 유료(후속): **"マスキング済み書類ボックス"** — 가린 사본만 암호화 저장, 다음 제출 때 재사용. 원본은 절대 저장하지 않음(개인정보처리방침과 무충돌). 과금 근거: "매번 다시 가리지 않아도 됨"
- 가격 가설: 月額 300~500엔 또는 1회 100엔. 검증은 콘텐츠 반응 후

---

## 3. 제품 요구사항 (JP 출시 게이트)

### 3-1. 마스킹 방식 단일화 (결정 반영)
- 별표(***)·부분값 오버레이 **폐지** → 띠(바)만. 색은 검정 기본 + 흰색·사용자 지정 1색
- 띠는 OCR/텍스트 좌표 박스를 2px 패딩으로 덮고 **래스터 평탄화** → "透けない黒塗り" 보증 문구 사용 가능
- 출력: JPG(0.85~0.92)·PNG·PDF(텍스트 레이어 없음). docx/xlsx 원본 포맷 유지는 2차

### 3-2. 일본어 탐지(JP-1) 필수 패턴
| 유형 | 패턴 | 비고 |
|---|---|---|
| マイナンバー | 12자리, 4-4-4 구분 허용, **체크디지트 검증** | 裏面·通知カード·源泉徴収票·住民票에 등장 |
| 保険者番号 | 8자리(健保) / 6자리(国保) | |
| 記号・番号・枝番 | 記号 1~8자리 + 番号 1~8자리 + 枝番 2자리 | 레이블 앵커 "記号"/"番号"/"枝番" 필수 |
| 運転免許証番号 | 12자리 | 레이블 "番号"/"第" 앵커 |
| 在留カード番号 | 영2+숫8+영2 (AB12345678CD) | |
| パスポート | 영2+숫7 (TR1234567) | |
| 電話 | 0X0-XXXX-XXXX / 03-XXXX-XXXX / 0120 | 시외국번 가변 |
| 郵便番号 | 〒?\d{3}-\d{4} | |
| 住所 | 都道府県+市区町村+丁目番地号 (전각 숫자·漢数字 포함) | |
| 生年月日 | 和暦(昭和/平成/令和 N年M月D日)+서기 | 和暦 → 서기 변환 불필요, 탐지만 |
| 銀行口座 | 支店番号 3자리 + 口座番号 7자리, 레이블 앵커 | 通帳·給与明細 |
| 本籍 | 레이블 "本籍" 뒤 주소 | 住民票·戸籍 |
| QR/二次元コード | 이미지 탐지(OpenCV 불가 시 사각 고대비 영역 휴리스틱) | 資格確認書 마스킹 항목 |
- 전각/반각 정규화, 오탐 가드에 **일본 기관명·지명 리스트** 추가
- 골든 하네스에 일본어 픽스처 ≥8종 추가, max_auto 상한 재산정

### 3-3. 서류 프리셋(JP-3) — "이 서류는 여기"를 버튼 하나로
| 프리셋 | 자동 띠 위치 | 근거 |
|---|---|---|
| 健康保険証 / 資格確認書 | 保険者番号, 記号, 番号, 枝番, QR, 性別 | 告知要求制限 + 은행·카드사 안내 |
| 運転免許証 | 臓器提供意思表示欄(裏), 本籍変更履歴, 免許証番号(선택) | SoftBank 안내 |
| マイナンバーカード | **裏面 전체 경고 + 업로드 차단 권유**, 表面 性別·臓器提供 | 지자체 안내(裏面 コピー禁止) |
| 住民票 | 個人番号, 本籍, 性別, 世帯主 이외 가족 | 大阪府·SoftBank |
| 在留カード / パスポート | 番号, 性別(선택) | |
| 履歴書(JIS) | 住所 상세, 電話, 生年月日 일부, 写真(선택) | 공유용 |

### 3-4. 워터마크 프리셋(일본 관행 문구)
「〇〇提出用」「本人確認のみに使用」「コピー・転用禁止」「2026年10月20日 ○○社提出」 + 날짜 자동

---

## 4. 일본 개인정보 문서 카탈로그 (더미 생성 대상)

> 상세 필드는 `jp_documents_catalog.json` 참조. 공공 7 + 개인 6 = 13종, 포맷별 변형 포함 40~50개 파일 목표.

| # | 문서 | 유형 | 주 포맷 | 핵심 PII | 마스킹 관행 |
|---|---|---|---|---|---|
| 1 | 運転免許証 | 카드(표·裏) | JPG(스마트폰 촬영) | 氏名, 生年月日, 住所, 番号, 顔写真, 本籍変更履歴 | 臓器提供欄·裏面 변경이력 |
| 2 | マイナンバーカード | 카드(표·裏) | JPG | 氏名, 住所, 生年月日, 性別, 個人番号(裏), 顔写真 | 裏面 제출 금지 |
| 3 | 健康保険証(구) / 資格確認書(신) | 카드/A4 | JPG, PDF | 記号, 番号, 枝番, 保険者番号, QR, 事業所名 | 법적 의무 마스킹 |
| 4 | 住民票の写し | A4 공문서 | PDF, JPG | 氏名, 住所, 本籍, 個人番号, 世帯員, 続柄 | 本籍·個人番号·가족 |
| 5 | 在留カード | 카드 | JPG | 番号, 国籍, 在留資格, 期間 | 番号 |
| 6 | パスポート 身分事項ページ | 책 | JPG | 旅券番号, 本籍(都道府県), MRZ | 番号·MRZ |
| 7 | 源泉徴収票 | A4 세무 | PDF, XLSX | 個人番号, 住所, 支払金額, 控除対象配偶者 | 個人番号·금액 |
| 8 | 履歴書(JIS 規格) | A4/A3 개인 | DOCX, PDF, XLSX | 氏名, 生年月日, 住所, 電話, メール, 写真, 学歴·職歴 | 공유 시 상세주소·전화 |
| 9 | 職務経歴書 | A4 개인 | DOCX, PDF | 氏名, 連絡先, 会社名, 年収(가끔) | 연봉·회사명 |
| 10 | 給与明細 / 標準報酬決定通知書 | A4 | PDF, XLSX | 社員番号, 口座, 支給額, 被保険者整理番号 | 整理番号·口座 |
| 11 | 賃貸借契約書 | A4 복수쪽 | PDF | 貸主·借主 氏名住所, 保証人, 印影, 口座 | 제3자 정보·印影 |
| 12 | 通帳 / 振込明細 | 책/영수 | JPG | 口座番号, 残高, 取引履歴 | 口座·残高 |
| 13 | 在職証明書 / 卒業証明書 / 成績証明書 | A4 | PDF, DOCX | 氏名, 生年月日, 学籍番号, 成績 | 학적번호·성적 |

더미 생성 원칙: 이름(架空 姓名 생성), 주소(존재하지 않는 番地), 번호(체크디지트는 맞되 실존 불가 패턴), 사진(실루엣/生成 아바타), 모든 카드에 「見本」 워터마크. 실물 디자인의 문양·홀로그램은 재현하지 않음.

---

## 5. 콘텐츠 전략 (3개월, 3일 1회 = 30편)

### 플랫폼 3개 (근거: ICT総研 2026-07 — LINE 71.1%, YouTube 67.6%, X 45.4%, Instagram 42.0%)
1. **X** — 유출 뉴스가 실시간으로 도는 곳. 텍스트+이미지 1장, 스레드. 가장 빠른 유입
2. **YouTube Shorts** — 사용법 How-to 10편의 집. 검색 유입(「保険証 マスキング やり方」) 지속
3. **Instagram Reels** — 25–39 여성 비중 보강, 카루셀로 "どこを隠す" 도해 재활용
- LINE: 유저 최다이나 신규 계정 도달 0 → 제외. 단, LINE 공식계정은 유료 전환 후 CRM용으로 재검토

### 2트랙
- **트랙 A: How-to 10편(서류 1종=1편)** — 더미 문서를 실제 사이트에 올려 가리고 내려받는 60초 화면녹화 + 자막. 일본어/영어 2버전
- **트랙 B: 에피소드 20편** — 1인 상황극(텍스트+정지화면 슬라이드, 추후 영상화). 예: "メルカリに免許証を送る夜", "入札書類を再提出させられた日", "元彼に住民票を送っていた話(픽션)"

### 30편 주제안 (검수용)
| 회 | 트랙 | 주제(일본어 제목) | 서류 |
|---|---|---|---|
| 1 | B | 免許証の画像、会社は守ってくれなかった — 660万件のあと私がしたこと | 免許証 |
| 2 | A | 【30秒】保険証・資格確認書の記号番号を黒塗りする方法 | 資格確認書 |
| 3 | A | 運転免許証を送る前に隠すべき3か所 | 免許証 |
| 4 | B | 「黒塗りしたつもり」が透けていた話 | — |
| 5 | A | マイナンバーカード、裏面は絶対に送らない。表面はここを隠す | マイナカード |
| 6 | B | メルカリ本人確認、怖くてできない人へ | 免許証 |
| 7 | A | 住民票の写し、本籍とマイナンバーを消して提出する | 住民票 |
| 8 | B | 入札書類の保険証、マスキング忘れで再提出になった | 保険証 |
| 9 | A | 履歴書PDFから住所と電話だけ消して共有する | 履歴書 |
| 10 | B | 付箋とマスキングテープ、もうやめませんか | — |
| 11 | A | 源泉徴収票のマイナンバー欄を隠して提出 | 源泉徴収票 |
| 12 | B | 賃貸契約で身分証コピーを求められたとき | 免許証·住民票 |
| 13 | A | 在留カードを安全に送る(英語版同時) | 在留カード |
| 14 | B | 退会しても7年保存されていた私の免許証 | — |
| 15 | A | 給与明細の口座番号と社員番号を隠す | 給与明細 |
| 16 | B | 口座開設は「画像だけ」で通る?2027年4月まで続く穴 | — |
| 17 | A | 賃貸借契約書、相手の個人情報まで消してから相談する | 契約書 |
| 18 | B | 黒塗りは誰の責任?企業は「マスキングして送れ」と言う | — |
| 19 | A | パスポートの番号とMRZを隠す | パスポート |
| 20 | B | 信用情報機関への本人申告(JICC/CIC)と一緒にやること | — |
| 21 | A | 通帳の残高と口座番号、スクショ前に消す | 通帳 |
| 22 | B | 学生証の画像も流出していた — 学生がいま出来ること | 学生証 |
| 23 | A | 職務経歴書の年収と会社名を伏せて送る | 職務経歴書 |
| 24 | B | 「サーバーに保存しない」ツールしか使わない理由 | — |
| 25 | A | スマホだけで完結:撮影→黒塗り→送信 | 全般 |
| 26 | B | 副業の本人確認、毎回同じ書類を撮り直していませんか | — |
| 27 | A | 透かし「〇〇提出用」を入れて転用を防ぐ | 全般 |
| 28 | B | 家族の分も:子どもの保険証、親の住民票 | 保険証 |
| 29 | A | 10枚まとめて黒塗り(一括処理) | 全般 |
| 30 | B | 2か月やってみた総括 + 読者の黒塗り失敗集 | — |

---

## 6. 실행 순서와 게이트

| 단계 | 산출물 | 완료 기준 | 담당 |
|---|---|---|---|
| S1 조사·카탈로그 | 본 문서 + catalog.json | 13종 필드·관행 확정 | 완료(본 문서) |
| S2 더미 생성 | 40~50 파일 (docx/pdf/xlsx/jpg) | 각 문서에 기대 마스킹 specs.json 동봉 | Claude(이 세션) |
| S3 JP-1 탐지 + 띠 단일화 | index.html 수정, 골든 +8 | `node run.mjs` 0 exit, 일본어 픽스처 전부 통과 | Claude Code |
| S4 JP-3 프리셋 + 워터마크 | 프리셋 6종 | 더미 13종 수동 검수 통과 | Claude Code |
| S5 실사이트 검증 | 제가 Chrome로 업로드·다운로드 | 13종 중 12종 이상 1분 내 완료 | Claude |
| S6 콘텐츠 제작 | 30편(JA/EN) + How-to 녹화 10편 | 주제 검수 후 순차 | Claude |
| S7 게시 운영 | 3일 1회 전달 → Justin 게시 | 반응 데이터로 유료화 결정 | Justin |

**홍보는 S5 통과 전 시작 금지.** 타임즈카 이슈는 길어야 2~3개월 지속 → S3~S5를 2주 안에 끝내야 파도를 탐.

---

## 7. 리스크·미확인

- 일본어 OCR recall 미측정(Tesseract jpn). 스마트폰 사진 품질에서 記号·番号 인식률이 낮으면 프리셋(좌표 기반)이 백업
- 카드 더미 이미지의 법적 민감성 → 「見本」 명시·문양 미재현으로 관리
- safefile.net 도메인 미확정. 일본어 콘텐츠 URL이 slimfile.net/safe/ 로 노출되면 브랜드 분산
- X 소셜리스닝은 API 없이 검색엔진 경유만 가능 → 정량 데이터는 Yahoo!知恵袋·bengo4·note로 보완
{
  "version": "2026-10-20",
  "purpose": "SafeFile JP — 일본 개인정보 문서 카탈로그. 더미 생성·프리셋·탐지 규칙의 정본.",
  "pii_patterns": {
    "my_number": {"regex": "\\d{4}[-\\s]?\\d{4}[-\\s]?\\d{4}", "digits": 12, "check_digit": "mod11 (個人番号検査用数字)", "appears_in": ["マイナンバーカード裏面", "通知カード", "住民票(記載あり)", "源泉徴収票", "扶養控除申告書"]},
    "hokensha_bango": {"regex": "(?<=保険者番号)\\s*\\d{6,8}", "note": "健保8桁 / 国保6桁"},
    "kigo_bango_edaban": {"regex": "記号\\s*[\\d０-９A-Za-z]{1,8}.*?番号\\s*[\\d０-９]{1,8}(.*?枝番\\s*\\d{2})?", "note": "告知要求制限 대상"},
    "driver_license_no": {"regex": "(?<=番号|第)\\s*\\d{12}", "digits": 12},
    "zairyu_card_no": {"regex": "[A-Z]{2}\\d{8}[A-Z]{2}"},
    "passport_no": {"regex": "[A-Z]{2}\\d{7}"},
    "phone": {"regex": "(0[5-9]0-?\\d{4}-?\\d{4}|0\\d{1,4}-?\\d{1,4}-?\\d{4}|0120-?\\d{3}-?\\d{3})"},
    "postal": {"regex": "〒?\\s*\\d{3}-\\d{4}"},
    "address": {"regex": "(北海道|東京都|(?:京都|大阪)府|.{2,3}県).{1,12}?(市|区|郡|町|村).{0,20}?([0-9０-９一二三四五六七八九十]+丁目)?.{0,15}?[0-9０-９一二三四五六七八九十]+(番地?|-|−|ー)[0-9０-９]*(号)?"},
    "birth_wareki": {"regex": "(明治|大正|昭和|平成|令和|M|T|S|H|R)\\s*(元|\\d{1,2})年\\s*\\d{1,2}月\\s*\\d{1,2}日"},
    "birth_seireki": {"regex": "(19|20)\\d{2}[年/.-]\\s*\\d{1,2}[月/.-]\\s*\\d{1,2}日?"},
    "bank_account": {"regex": "(店番|支店(番号|コード))\\s*\\d{3}.*?(口座番号|口座)\\s*\\d{7}", "note": "레이블 앵커 필수"},
    "honseki": {"regex": "(?<=本籍)\\s*.{4,40}"},
    "qr": {"type": "image-heuristic", "note": "資格確認書 二次元コード"}
  },
  "documents": [
    {"id": "jp01", "name": "運転免許証", "category": "公的身分証", "owner_segment": [1,2], "formats": ["jpg(表)", "jpg(裏)", "pdf(両面コピー)"],
     "fields": ["氏名", "生年月日(和暦)", "住所", "交付日", "有効期限", "免許の条件", "番号(12桁)", "種類", "顔写真", "公安委員会名", "裏面:本籍変更/住所変更履歴", "裏面:臓器提供意思表示欄"],
     "mask_norm": {"always": ["臓器提供意思表示欄", "裏面変更履歴"], "optional": ["番号", "本籍"], "keep_for_kyc": ["氏名", "生年月日", "住所", "顔写真", "有効期限"]},
     "preset": "license", "source": ["SoftBank Dialpad 本人確認書類案内", "aspicjapan.org"]},
    {"id": "jp02", "name": "マイナンバーカード(個人番号カード)", "category": "公的身分証", "owner_segment": [1,2], "formats": ["jpg(表)", "jpg(裏)"],
     "fields": ["氏名", "住所", "生年月日", "性別", "有効期限", "顔写真", "券面記載事項追記欄", "裏面:個人番号(12桁)", "裏面:氏名", "裏面:生年月日", "裏面:臓器提供意思", "裏面:QR"],
     "mask_norm": {"always": ["裏面全体(提出禁止)"], "optional": ["性別", "臓器提供意思"], "keep_for_kyc": ["表面"]},
     "preset": "mynumber_card", "source": ["愛知県 本人確認書類留意点", "墨田区·品川区 利用案内", "秋田市FAQ"]},
    {"id": "jp03", "name": "健康保険証(旧) / 資格確認書(新)", "category": "公的身分証", "owner_segment": [1,3], "formats": ["jpg(カード)", "pdf(A4 資格確認書)", "jpg(縦型紙)"],
     "fields": ["記号", "番号", "枝番", "氏名", "生年月日", "性別", "資格取得年月日", "事業所名称", "保険者番号", "保険者名称", "保険者所在地", "交付日", "二次元コード"],
     "mask_norm": {"always": ["保険者番号", "記号", "番号", "枝番", "二次元コード"], "optional": ["性別", "通院歴(家族分含む)"], "keep_for_kyc": ["氏名", "生年月日", "住所", "事業所名称"]},
     "legal": "健康保険法 告知要求制限 (令和2年10月1日施行)", "preset": "insurance", "source": ["大阪府 添付注意", "東京都共済 R8.7.27 加筆", "PayPay銀行", "千葉市", "長崎県建設企画課"]},
    {"id": "jp04", "name": "住民票の写し", "category": "公文書", "owner_segment": [1,3,4], "formats": ["pdf", "jpg(撮影)"],
     "fields": ["氏名", "生年月日", "性別", "住所", "世帯主", "続柄", "本籍", "筆頭者", "住民となった日", "個人番号(記載選択時)", "住民票コード", "市区町村長印"],
     "mask_norm": {"always": ["個人番号", "住民票コード"], "optional": ["本籍", "筆頭者", "性別", "本人以外の世帯員"], "keep_for_kyc": ["氏名", "生年月日", "住所", "発行日"]},
     "preset": "juminhyo", "source": ["大阪府", "SoftBank", "aspicjapan"]},
    {"id": "jp05", "name": "在留カード", "category": "公的身分証", "owner_segment": [4], "formats": ["jpg(表)", "jpg(裏)"],
     "fields": ["氏名(ローマ字)", "生年月日", "性別", "国籍·地域", "住居地", "在留資格", "就労制限の有無", "在留期間", "在留カード番号", "顔写真", "裏面:住居地変更", "裏面:資格外活動許可"],
     "mask_norm": {"always": [], "optional": ["在留カード番号", "性別"], "keep_for_kyc": ["氏名", "生年月日", "住居地", "在留資格", "在留期間"]},
     "preset": "zairyu", "source": ["TRUSTDOCK 対応書類"]},
    {"id": "jp06", "name": "パスポート 身分事項ページ", "category": "公的身分証", "owner_segment": [1,4], "formats": ["jpg"],
     "fields": ["旅券番号", "姓", "名", "国籍", "生年月日", "性別", "本籍(都道府県)", "発行日", "有効期限", "発行官庁", "顔写真", "MRZ 2行"],
     "mask_norm": {"always": [], "optional": ["旅券番号", "MRZ", "性別", "本籍"], "keep_for_kyc": ["姓名", "生年月日", "有効期限", "顔写真"]},
     "preset": "passport", "source": ["aspicjapan"]},
    {"id": "jp07", "name": "源泉徴収票(給与所得の)", "category": "税務", "owner_segment": [1,3], "formats": ["pdf", "xlsx", "jpg"],
     "fields": ["支払を受ける者 住所", "氏名", "個人番号", "支払金額", "給与所得控除後の金額", "所得控除の額の合計額", "源泉徴収税額", "控除対象配偶者", "扶養親族", "社会保険料等", "生命保険料", "住宅借入金", "支払者 名称·住所·法人番号"],
     "mask_norm": {"always": ["個人番号"], "optional": ["支払金額", "税額", "配偶者·扶養親族氏名", "住所"], "keep_for_kyc": ["氏名", "支払者名", "年分"]},
     "preset": "gensen", "source": ["一般慣行"]},
    {"id": "jp08", "name": "履歴書(JIS規格)", "category": "個人文書", "owner_segment": [1,2], "formats": ["docx", "pdf", "xlsx", "jpg(手書きスキャン)"],
     "fields": ["氏名", "ふりがな", "生年月日", "年齢", "性別", "現住所", "〒", "電話", "携帯", "メール", "連絡先", "写真", "学歴", "職歴", "免許·資格", "志望動機", "本人希望欄", "配偶者·扶養家族(旧様式)"],
     "mask_norm": {"always": [], "optional": ["現住所 番地以下", "電話", "メール", "写真", "生年月日 日", "配偶者·扶養"], "keep_for_share": ["氏名(or イニシャル)", "学歴", "職歴", "資格"]},
     "preset": "rirekisho", "source": ["JIS Z 8303 様式慣行"]},
    {"id": "jp09", "name": "職務経歴書", "category": "個人文書", "owner_segment": [1], "formats": ["docx", "pdf"],
     "fields": ["氏名", "日付", "連絡先", "職務要約", "会社名", "在籍期間", "部署·役職", "年収(記載時)", "実績数値", "取引先名"],
     "mask_norm": {"optional": ["連絡先", "会社名", "年収", "取引先名"]},
     "preset": "shokumu", "source": ["一般慣行"]},
    {"id": "jp10", "name": "給与明細 / 標準報酬決定通知書", "category": "給与", "owner_segment": [1,3], "formats": ["pdf", "xlsx", "jpg"],
     "fields": ["社員番号", "氏名", "所属", "支給額内訳", "控除額内訳", "差引支給額", "振込口座(銀行·支店·口座番号)", "被保険者整理番号", "事業所整理番号", "標準報酬月額"],
     "mask_norm": {"always": ["被保険者整理番号", "口座番号"], "optional": ["社員番号", "金額"], "keep_for_kyc": ["氏名", "事業所名", "対象月"]},
     "preset": "payslip", "source": ["山梨県 標準報酬決定通知書 マスキング", "京都府"]},
    {"id": "jp11", "name": "賃貸借契約書", "category": "契約", "owner_segment": [1], "formats": ["pdf(複数頁)", "jpg(撮影)"],
     "fields": ["物件所在地", "貸主 氏名·住所", "借主 氏名·住所·生年月日·電話", "連帯保証人 氏名·住所·電話·勤務先", "緊急連絡先", "賃料", "敷金·礼金", "振込口座", "印影", "仲介業者 免許番号"],
     "mask_norm": {"always": ["第三者(貸主·保証人)の個人情報", "印影", "振込口座"], "optional": ["借主 電話·生年月日", "物件 号室"]},
     "preset": "lease", "source": ["bengo4 相談事例"]},
    {"id": "jp12", "name": "通帳 / 振込明細 / 残高証明", "category": "金融", "owner_segment": [1,2], "formats": ["jpg", "pdf(ネット銀行)"],
     "fields": ["銀行名", "支店名·店番", "口座番号", "口座名義(カナ)", "残高", "取引履歴(日付·摘要·金額)", "振込先名"],
     "mask_norm": {"always": ["口座番号", "残高"], "optional": ["取引履歴 相手名"], "keep": ["銀行名", "支店名", "名義"]},
     "preset": "bankbook", "source": ["一般慣行"]},
    {"id": "jp13", "name": "在職証明書 / 卒業証明書 / 成績証明書 / 学生証", "category": "証明書", "owner_segment": [1,2], "formats": ["pdf", "docx", "jpg(学生証)"],
     "fields": ["氏名", "生年月日", "学籍番号/社員番号", "所属", "入学·入社日", "成績(科目·評価·GPA)", "発行者印", "顔写真(学生証)"],
     "mask_norm": {"always": ["学籍番号·社員番号"], "optional": ["成績明細", "生年月日", "顔写真"]},
     "preset": "certificate", "source": ["タイムズカー流出 学生証画像 事例"]}
  ],
  "watermark_presets_ja": ["〇〇提出用", "本人確認のみに使用", "コピー・転用禁止", "{date} {recipient}提出用", "SafeFileで黒塗り済み"],
  "dummy_generation_rules": {
    "names": "架空姓名(常用漢字ランダム組合せ, 実在有名人回避)",
    "addresses": "実在都道府県·市区 + 存在しない丁目番地(例: 99丁目)",
    "numbers": "チェックディジット整合, 先頭に非実在プレフィックス",
    "photos": "生成アバター or シルエット",
    "all_cards": "「見本」透かし必須, 公的紋様·ホログラム非再現",
    "formats_per_doc": ["docx", "pdf", "xlsx(表形式のみ)", "jpg 撮影風(斜め·影)", "png スキャン風"]
  },
  "sources": [
    "https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf",
    "https://www.kyosai.metro.tokyo.jp/assets/84b47fd406a8378372a6015863f83bc93c0c8a75.pdf",
    "https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html",
    "https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf",
    "https://www.aspicjapan.org/asu/article/6908",
    "https://www.pref.aichi.jp/uploaded/attachment/364666.pdf",
    "https://www.sn-hoki.co.jp/articles/article4935267/",
    "https://weekly.ascii.jp/elem/000/004/437/4437878/",
    "https://bsrweb.jp/article/480322",
    "https://prtimes.jp/main/html/rd/p/000000030.000019182.html"
  ]
}

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'rg -n "pii|PII|pattern|regex|住所|電話|記号|番号|マイナン|保険|license|postal|birth|bank|passport|zairyu|redact|mask" public/safe/index.html | head -260' in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
78:.redact-word{position:relative;display:inline-block;padding:0 6px;white-space:nowrap}
79:.redact-word .bar{position:absolute;inset:6% -2% 4% -2%;background:var(--ink);border-radius:4px;transform-origin:left center;animation:sweep 3.6s ease-in-out infinite}
81:@media (prefers-reduced-motion:reduce){.redact-word .bar{animation:none;transform:scaleX(1);opacity:.92}}
127:.pii-item .del{border:1px solid var(--line);background:#fff;color:var(--no);border-radius:8px;width:30px;min-height:30px;cursor:pointer;font-size:13px;flex-shrink:0;font-family:inherit}
128:.pii-item .del:hover{background:var(--no-bg);border-color:var(--no)}
132:.pii-item.is-cand{background:#fff}
133:.pii-item .val-wrap{display:flex;flex-direction:column;gap:2px;min-width:0;flex:1}
134:.pii-item .reason{font-size:10.5px;color:var(--half);font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
145:.pii-list{flex:1;overflow:auto;display:flex;flex-direction:column;gap:6px;min-height:0}
158:.pii-item{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:8px 10px;border:1px solid var(--line);border-radius:10px;margin-bottom:6px;background:#fff;flex-wrap:wrap}
159:.pii-item .val{font-size:13px;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1}
160:.pii-item.nolocate .val{opacity:.6}
161:.pii-item .nl{font-size:10px;font-weight:600;color:var(--half);background:var(--half-bg);border-radius:10px;padding:1px 6px;flex-shrink:0}
266:  .pii-item .del{min-height:44px;width:44px;font-size:15px}
360:        <h2><span class="step-n">2</span> <span data-i18n="s2">발견된 개인정보</span> <span id="piiCount" style="color:var(--sub);font-weight:400;font-size:13px"></span></h2>
369:        <div class="pii-list" id="piiList"></div>
527:  types:{rrn:'주민등록번호',ssn:'SSN(미국)',passport:'여권번호',license:'운전면허번호',card:'카드번호',account:'계좌번호',phone:'전화번호',email:'이메일',birth:'생년월일',address:'주소',name:'이름',company:'회사·소속',title:'직책',ip:'IP 주소',url:'SNS·URL',health:'건강·민감정보',other:'기타',manual:'직접 선택'}
535:  s1:'Upload document', s2:'Detected personal info', s3:'Create document', s3sub:'Composites the masking over your original. Text under the black boxes is not copied.',
544:  hintBefore:'Preset the default visibility for each category. When found in your document, items are masked accordingly.',
547:  aiHint:'AI finds unpatterned info like names, companies, and addresses from context.', btnAI:'AI deep scan',
561:  tMade:n=>`Done! ${n} spots masked`, tMadeWM:'Done! Watermark applied', tCopied:'Copied to clipboard', tSaved:n=>`Saved ${n}`,
581:  types:{rrn:'Korean RRN',ssn:'SSN (US)',passport:'Passport no.',license:"Driver's license",card:'Card number',account:'Bank account',phone:'Phone',email:'Email',birth:'Date of birth',address:'Address',name:'Name',company:'Company',title:'Job title',ip:'IP address',url:'Social · URL',health:'Health / sensitive',other:'Other',manual:'Manual'}
586:  cycle:['身分証番号','電話番号','自宅住所','口座番号','氏名'],
601:  aiHint:'氏名・会社・住所のようにパターンのない情報は、AIが文脈から見つけます。', btnAI:'AI精密検査',
629:  reasons:{name:'氏名の可能性', addr:'住所の可能性', addr_contact:'住所の可能性 · 連絡先の近く', addr_edge:'住所の可能性 · 文書の上部・下部', addr_kw:'住所の可能性 · 地名・住所語'},
635:  types:{rrn:'住民登録番号(韓国)',ssn:'SSN(米国)',passport:'パスポート番号',license:'運転免許番号',card:'カード番号',account:'口座番号',phone:'電話番号',email:'メール',birth:'生年月日',address:'住所',name:'氏名',company:'会社・所属',title:'役職',ip:'IPアドレス',url:'SNS・URL',health:'健康・センシティブ情報',other:'その他',manual:'手動選択'}
689:  types:{rrn:'RRN de Corea',ssn:'SSN (EE. UU.)',passport:'N.º de pasaporte',license:'Permiso de conducir',card:'N.º de tarjeta',account:'Cuenta bancaria',phone:'Teléfono',email:'Correo',birth:'Fecha de nacimiento',address:'Dirección',name:'Nombre',company:'Empresa',title:'Cargo',ip:'Dirección IP',url:'Redes · URL',health:'Salud / sensible',other:'Otro',manual:'Manual'}
722:  rrn:{icon:'🪪',risk:'no'}, ssn:{icon:'🪪',risk:'no'}, passport:{icon:'🛂',risk:'no'},
723:  license:{icon:'🚗',risk:'no'}, card:{icon:'💳',risk:'no'}, account:{icon:'🏦',risk:'no'},
724:  phone:{icon:'📞',risk:'half'}, email:{icon:'✉️',risk:'half'}, birth:{icon:'🎂',risk:'half'},
729:  // 비(非)PII 본문이 자동으로 훼손된다(예: TOPIK→TOP**). 확실한 유형만 기본 마스킹하고
748:  $('heroH1').innerHTML = T().heroPre + `<span class="redact-word"><span id="cycleWord">${T().cycle[cw]}</span><span class="bar" aria-hidden="true"></span></span>` + T().heroPost;
776:/* ───────── regex detection ───────── */
782:  {type:'passport',re:/\b[MSRODG]\d{8}\b/g},
783:  {type:'license',re:/\b\d{2}-\d{2}-\d{6}-\d{2}\b/g},
786:  {type:'birth',  re:/\b(19|20)\d{2}[.\-\/년 ]\s?\d{1,2}[.\-\/월 ]\s?\d{1,2}일?\b/g},
820:function regexScan(text){
826:      if(rule.type==='birth' && found.some(f=>f.type==='rrn'&&f.value.includes(v))) continue;
834:   (1) confirmed  — a number (street/postal) → auto-masked as before
836:                    with an institution/org → visible "review" item, not masked
839:const ORG_RE=/\b(foundation|trust|ngo|organi[sz]ation|association|federation|council|ministry|bank|ltd|inc|corp|pvt|company|technolog|solutions?|systems?|services?|labs?|studios?|agency|enterprises?)\b|재단|협회|공사|공단|주식회사|株式会社|財団|協会/i;
844:// "Korea"/"India"/"Indian" must be excluded outright (not masked, not a
845:// candidate), no matter which path (regex, candidate, or AI) proposes it.
862:  // anchor, never PII — the `words.every` guard keeps this tight (a single non
873:  if(/\d/.test(v)) return 'address';        // (1) number → confirmed, auto-mask
875:  if(isCountryOrAdj(v)) return 'drop';       // (3) lone country/nationality → not PII
1014:/* ───────── text masking (for partial rendering, list display, copy) ───────── */
1015:// Format-preserving partial phone mask: keep every non-digit character (+, spaces,
1019:function maskPhone(v){
1024:  const maskFrom=front, maskTo=n-back;              // mask digit positions [maskFrom, maskTo)
1026:  for(let k=maskFrom;k<maskTo;k++) out[digitIdx[k]]='*';
1029:function maskHalf(type,v){
1032:    case 'phone': return maskPhone(v);
1037:    case 'birth': return v.replace(/\d{1,2}([일.\-\/]?)\s*$/,'**$1');
1045:const maskBlockText=v=>'■'.repeat(Math.min(Math.max(Math.round(v.replace(/\s/g,'').length*0.8),3),12));
1047:function displayValue(e){ if(e.mode==='ok') return e.value; if(e.mode==='half') return maskHalf(e.type,e.value); return maskBlockText(e.value); }
1078:// short value never masks a fragment inside a longer word — e.g. "Korea" must
1320:    addEntities(regexScan(docText));
1344:    // Country / nationality is never PII — drop it regardless of proposed type
1349:    // demoted to a visible company, never masked as a name.
1355:      else type=d;                                     // 'address' (mask) or 'company' (visible)
1377:// "MANSI GAZAL" redundant (the confirmed mask already covers it). Only the shorter,
1398:/* ───────── preview (rendered page + live redaction overlay) ───────── */
1450:// for partial-mask remnant safety); a big bar doesn't need it.
1462:// Overlap-aware redaction. Two entities that resolve to the same coordinate band
1466:// ghosting) and a shorter masked value left an uncovered original tail. We now
1467:// (1) build every entity's per-line render plan, (2) paint partial masks first
1468:// covering each line's FULL background, then (3) paint solid masks on top, and
1469:// escalate any partial whose slot is overlapped by another mask to a solid block
1470:// — masking strength wins (비공개 > 부분 > 공개) and no original pixels survive.
1480:    // Large display text (e.g. a 48pt name) can't be partial-masked with
1493:  // 1) partial masks — cover each line's full background, draw the value ONCE.
1503:    drawFitText(ctx, S(a.x), S(a.y), S(a.w), S(a.h), maskHalf(p.e.type,p.e.value), a.bg);
1506:  // 2) solid masks on top.
1539:/* ───────── manual region selection (drag to redact photo/signature/name) ───────── */
1607:      <div class="pii-item${located(e)?'':' nolocate'}">
1628:      <div class="pii-item${cand?' is-cand':''}">
1643:  const list=$('piiList'), t=T();
1648:  $('piiCount').textContent= total? t.cntUse(total):'';
1669:$('piiList').addEventListener('change',e=>{
1673:$('piiList').addEventListener('click',e=>{
1745:    out=out.replace(re, e.mode==='half'? maskHalf(e.type,e.value) : maskBlockText(e.value));

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "sed -n '715,915p' public/safe/index.html && sed -n '1010,1060p' public/safe/index.html && rg -n \"max_auto|MAX_AUTO|Tesseract|jpn|lang|OCR|aiScan|detect\" public/safe/index.html | head -180" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
const catEnabled={}, catDefault={};
const $=id=>document.getElementById(id);
const toast=msg=>{const t=$('toast');t.textContent=msg;t.classList.add('show');clearTimeout(t._tm);t._tm=setTimeout(()=>t.classList.remove('show'),2600);};
const setStatus=s=>{$('scanStatus').textContent=s||'';};
const setProg=(v)=>{const p=$('prog');if(v==null||v<=0){p.classList.remove('on');$('progBar').style.width='0';}else{p.classList.add('on');$('progBar').style.width=Math.round(Math.min(1,v)*100)+'%';}};

const TYPES = {
  rrn:{icon:'🪪',risk:'no'}, ssn:{icon:'🪪',risk:'no'}, passport:{icon:'🛂',risk:'no'},
  license:{icon:'🚗',risk:'no'}, card:{icon:'💳',risk:'no'}, account:{icon:'🏦',risk:'no'},
  phone:{icon:'📞',risk:'half'}, email:{icon:'✉️',risk:'half'}, birth:{icon:'🎂',risk:'half'},
  address:{icon:'📍',risk:'half'}, name:{icon:'👤',risk:'half'},
  company:{icon:'🏢',risk:'ok'}, title:{icon:'💼',risk:'ok'},
  ip:{icon:'🌐',risk:'no'}, url:{icon:'🔗',risk:'half'}, health:{icon:'🏥',risk:'no'},
  // 'other' = "분류 불확실". 불확실한 것을 기본 마스킹하면 시험명·수상명·자격증명 같은
  // 비(非)PII 본문이 자동으로 훼손된다(예: TOPIK→TOP**). 확실한 유형만 기본 마스킹하고
  // other 는 기본 공개(ok) 후 사용자가 필요 시 직접 켠다. (오탐 본문 훼손 방지)
  other:{icon:'📌',risk:'ok'}
};
Object.keys(TYPES).forEach(t=>{catEnabled[t]=true;catDefault[t]=TYPES[t].risk;});
const isOn=e=>catEnabled[e.type]!==false;
const tLabel=t=>T().types[t]||t;

/* ───────── lazy library loaders ───────── */
const _scripts={};
function loadScript(src){return _scripts[src]||(_scripts[src]=new Promise((res,rej)=>{const s=document.createElement('script');s.src=src;s.async=true;s.onload=res;s.onerror=()=>rej(new Error('load fail '+src));document.head.appendChild(s);}));}
async function ensureTesseract(){ if(!window.Tesseract) await loadScript(CDN_TESSERACT); return window.Tesseract; }
async function ensureHeic(){ if(!window.heic2any) await loadScript(CDN_HEIC); return window.heic2any; }
async function ensureJsPDF(){ if(!(window.jspdf&&window.jspdf.jsPDF)) await loadScript(CDN_JSPDF); return window.jspdf; }
function OCR_LANGS(){ return ({ko:'kor+eng',en:'eng',ja:'jpn+eng',es:'spa+eng'})[LANG]||'eng'; }

/* ───────── hero cycle ───────── */
let cw=0;
function renderHero(){
  $('heroH1').innerHTML = T().heroPre + `<span class="redact-word"><span id="cycleWord">${T().cycle[cw]}</span><span class="bar" aria-hidden="true"></span></span>` + T().heroPost;
}
setInterval(()=>{cw=(cw+1)%T().cycle.length;const el=$('cycleWord');if(el)el.textContent=T().cycle[cw];},3600);

/* ───────── apply language ───────── */
function applyLang(){
  document.documentElement.lang=LANG;
  try { localStorage.setItem('safefile_lang', LANG); } catch(e){}
  const sel=$('langSel'); if(sel) sel.value=LANG;
  document.querySelectorAll('[data-i18n]').forEach(el=>{
    const k=el.dataset.i18n; const v=T()[k];
    if(typeof v==='string') el.innerHTML=v;
  });
  document.querySelectorAll('[data-i18n-ph]').forEach(el=>{const v=T()[el.dataset.i18nPh];if(typeof v==='string')el.placeholder=v;});
  document.querySelectorAll('[data-i18n-aria]').forEach(el=>{const v=T()[el.dataset.i18nAria];if(typeof v==='string')el.setAttribute('aria-label',v);});
  $('pasteArea').placeholder=T().pastePh;
  const ml=$('manifestLink'); if(ml) ml.href=`/safe/manifest.${LANG}.webmanifest`;
  if(typeof refreshInstallBanner==='function') refreshInstallBanner();
  buildWmPresets();
  renderHero(); renderList(); buildPreview();
  // keep the result viewer in sync (fit label + fullscreen aria are language-dependent)
  if(typeof rvPages!=='undefined' && rvPages.length && $('result') && $('result').style.display!=='none'){
    const b=$('rvFull'); if(b&&rvIsFull) b.setAttribute('aria-label',T().rvExitAria);
    rvRender();
  }
}
$('langSel').addEventListener('change',e=>{LANG=e.target.value;applyLang();});

/* ───────── regex detection ───────── */
const REGEX_RULES=[
  {type:'rrn',    re:/\d{6}[-‐ ]?[1-4]\d{6}/g},
  {type:'ssn',    re:/\b\d{3}-\d{2}-\d{4}\b/g},
  {type:'card',   re:/\b\d{4}[- ]\d{4}[- ]\d{4}[- ]\d{4}\b/g},
  {type:'email',  re:/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g},
  {type:'passport',re:/\b[MSRODG]\d{8}\b/g},
  {type:'license',re:/\b\d{2}-\d{2}-\d{6}-\d{2}\b/g},
  {type:'account',re:/\b\d{3,6}-\d{2,6}-\d{3,6}\b/g},
  {type:'ip',     re:/\b(?:\d{1,3}\.){3}\d{1,3}\b/g},
  {type:'birth',  re:/\b(19|20)\d{2}[.\-\/년 ]\s?\d{1,2}[.\-\/월 ]\s?\d{1,2}일?\b/g},
  {type:'address',re:/(서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충청?[북남]|전라?[북남]|경상?[북남]|제주)[^\n,()]{0,20}?(시|군|구)\s?[^\n,()]{0,25}?(로|길|대로)\s?\d+[^\n,()]{0,20}/g},
  {type:'url',    re:/https?:\/\/[^\s)>\]]+|(?:instagram|facebook|linkedin|twitter|x)\.com\/[^\s)>\]]+/g},
];
/* International phone detection. Regex + digit-count validation per shape.
   Covers +country-code (any), KR/JP/ID/BR/US/ES/MX domestic & grouped forms.
   Digit-count gates keep false positives (IDs, dates, accounts) out. */
const RRN_LIKE=/\d{6}[-‐ ]?[1-4]\d{6}/;
function phoneScan(text){
  const out=[], seen=new Set();
  const add=(raw,min,max)=>{
    let v=raw.trim().replace(/[.\s,;:]+$/,'').replace(/^[.\s,;:]+/,'');
    const d=v.replace(/\D/g,'');
    if(d.length<min||d.length>max) return;
    if(RRN_LIKE.test(v)) return;                 // Korean RRN, not a phone
    if(/^0+$/.test(d)||/^(\d)\1+$/.test(d)) return; // all-same digits
    if(seen.has(d)) return; seen.add(d);
    out.push({type:'phone',value:v});
  };
  let m,re;
  // 1) international, starts with + and country code
  re=/\+\d[\d\s().\-]{5,17}\d/g;
  while((m=re.exec(text))) add(m[0],8,15);
  // 2) parenthesised area code, e.g. Brazil (11) 91234-5678, (415) 555-2671
  re=/\(\d{2,4}\)[\s.\-]?\d{3,5}[\s.\-]?\d{3,4}/g;
  while((m=re.exec(text))) add(m[0],9,12);
  // 3) domestic trunk starting with 0 (KR 010/02, JP 090, ID 0812 …)
  re=/\b0\d{1,3}[\s.\-]?\d{3,4}[\s.\-]?\d{3,4}(?:[\s.\-]?\d{2,4})?(?!\d)/g;
  while((m=re.exec(text))) add(m[0],9,13);
  // 4) grouped 3-3/4-4 without +, e.g. US 415-555-2671, 415.555.2671
  re=/\b\d{3}[\s.\-]\d{3,4}[\s.\-]\d{4}(?!\d)/g;
  while((m=re.exec(text))) add(m[0],10,11);
  return out;
}
function regexScan(text){
  const found=phoneScan(text);            // phones first so numeric dedup below defers to them
  for(const rule of REGEX_RULES){
    let m; const re=new RegExp(rule.re.source,rule.re.flags);
    while((m=re.exec(text))!==null){
      const v=m[0].trim();
      if(rule.type==='birth' && found.some(f=>f.type==='rrn'&&f.value.includes(v))) continue;
      if((rule.type==='account'||rule.type==='ip') && found.some(f=>f.value.includes(v)||v.includes(f.value))) continue;
      found.push({type:rule.type,value:v});
    }
  }
  return found;
}
/* Address detection in 3 tiers (mirrors the name-candidate approach):
   (1) confirmed  — a number (street/postal) → auto-masked as before
   (2) candidate  — place/city with a country or address keyword, NOT combined
                    with an institution/org → visible "review" item, not masked
   (3) excluded   — institution/org names, lone tokens, country-only, prose */
const INSTITUTION_RE=/\b(univ|university|college|institute|institution|school|academy|polytechnic|faculty|department|hospital|clinic|seminary)\b|대학교|대학원|대학|고등학교|중학교|초등학교|학원|학교|병원|연구소|大学|大學|高校|高等学校|学院|学校|universidad|colegio|instituto|escuela|facultad|academia/i;
const ORG_RE=/\b(foundation|trust|ngo|organi[sz]ation|association|federation|council|ministry|bank|ltd|inc|corp|pvt|company|technolog|solutions?|systems?|services?|labs?|studios?|agency|enterprises?)\b|재단|협회|공사|공단|주식회사|株式会社|財団|協会/i;
const COUNTRY_RE=/\b(india|indonesia|korea|japan|brazil|brasil|spain|espa[nñ]a|mexico|m[eé]xico|usa|u\.s\.a\.?|united states|u\.k\.?|united kingdom|england|canada|australia|singapore|philippines|vietnam|thailand|malaysia|germany|france|italy|netherlands|nepal|bangladesh|pakistan|sri lanka|china|taiwan|uae|dubai|qatar)\b/i;
const ADDR_KEYWORD_RE=/\b(road|rd|street|st|avenue|ave|lane|ln|nagar|sector|colony|society|apartment|apartments|apt|flat|block|marg|enclave|vihar|puram|layout|phase|cross|extension|residency|towers?|heights?|villa|plot|gali|chowk|mohalla|bagh|ganj)\b|[가-힣]{2,}(로|길|동|읍|면|리)\b|丁目|区|市/i;
const isOrgName=v=>INSTITUTION_RE.test(v)||ORG_RE.test(v);
// Country names and nationality adjectives are NEVER personal info — a lone
// "Korea"/"India"/"Indian" must be excluded outright (not masked, not a
// candidate), no matter which path (regex, candidate, or AI) proposes it.
const COUNTRY_ADJ_RE=/^(korean|indian|japanese|chinese|american|british|english|spanish|mexican|brazilian|canadian|australian|french|german|italian|dutch|nepali|nepalese|bangladeshi|pakistani|filipino|filipina|vietnamese|thai|malaysian|singaporean|taiwanese|emirati|qatari|russian|swiss|swedish|norwegian|danish|finnish|polish|turkish|greek|portuguese|indonesian)$/i;
const DIRWORD_RE=/^(south|north|east|west|republic|of|the)$/i;
function isCountryOrAdj(v){
  const raw=(v||'').trim();
  if(!raw) return false;
  // Strip a parenthetical suffix (award/title) BEFORE the country test, then
  // trim stray edge punctuation. This keeps the country "anchor" judgment
  // identical whether a line stands alone ("Korea") or has merged with an
  // adjacent parenthetical ("Korea (Koreaz Contest)") — both are anchored on
  // the country and must be dropped, not proposed as an address.
  const core=raw.replace(/\([^)]*\)/g,' ').replace(/\s+/g,' ').trim();
  const t=core.replace(/^[.,()'"’]+|[.,()'"’]+$/g,'').trim();
  if(!t) return false;
  if(COUNTRY_ADJ_RE.test(t)) return true;                 // "Indian"
  const words=t.split(/\s+/).filter(Boolean);
  // A phrase built ONLY of direction/filler words + a country name is a country
  // anchor, never PII — the `words.every` guard keeps this tight (a single non
  // dir/country token disqualifies it). The length cap is 4 (not 2) so a wrapped
  // official name whose tail line reads "Republic of Korea (Koreaz Contest)"
  // — the real-résumé merged-line trap — is still dropped, not proposed as an
  // address candidate. "of the republic of korea" = 4 words, still all dir+country.
  if(words.length && words.length<=4 && COUNTRY_RE.test(t) && !/\d/.test(t) && !isOrgName(t)
     && words.every(w=>{const c=w.replace(/[.,]/g,''); return DIRWORD_RE.test(c)||COUNTRY_RE.test(c);}))
    return true;                                           // "Korea", "South Korea", "Republic of Korea (…)"
  return false;
}
function classifyAddress(v){
  if(/\d/.test(v)) return 'address';        // (1) number → confirmed, auto-mask
  if(isOrgName(v)) return 'company';         // (3) org/institution → visible, not address
  if(isCountryOrAdj(v)) return 'drop';       // (3) lone country/nationality → not PII
  const words=v.trim().split(/\s+/);
  if(words.length<=1) return 'drop';         // (3) lone place token (e.g. "Imphal")
  if(COUNTRY_RE.test(v)||ADDR_KEYWORD_RE.test(v)) return 'candidate'; // (2)
  return 'drop';                             // (3) no address signal
}
/* Name heuristic: the largest text near the top of page 1 is likely the
   person's name. Conservative — skips doc titles, only fires when clear font
   variation exists (so plain text docs never produce a candidate). */
const DOC_TITLE_RE=/^(resume|r[eé]sum[eé]|cv|curriculum\s*vitae|curriculum|bio\s*data|biodata|profile|portfolio|자기?소개서|이력서|履歴書|職務経歴書|hoja\s*de\s*vida)$/i;
const NON_NAME_RE=/증명서|명세서|계약서|신청서|경력|재직|이력|자기소개|졸업|성적|证明|証明|明細|履歴|resume|résumé|profile|curriculum|contract|certificate|statement|invoice/i;
function isLikelyName(text){
  if(!text||text.length<2||text.length>40) return false;
  if(/[\d@]|https?:|www\./i.test(text)) return false;
  if(DOC_TITLE_RE.test(text.trim())||NON_NAME_RE.test(text)) return false;
  if(isOrgName(text)||isCountryOrAdj(text)) return false;  // schools/orgs/countries are not names
  if(text.split(/\s+/).length>4) return false;
  const compact=text.replace(/\s/g,'');
  const letters=(text.match(/[A-Za-zÀ-ɏ가-힣぀-ヿ一-鿿]/g)||[]).length;
  return letters >= compact.length*0.7;
}
function nameCandidates(){
  if(!pages.length) return [];
  const page=pages[0]; if(!page.items||!page.items.length) return [];
  const topItems=page.items.filter(it=>it.y < page.h*0.42 && (it.str||'').trim().length>=2);
  if(!topItems.length) return [];
  const maxH=Math.max(...topItems.map(it=>it.h));
  const heights=page.items.map(it=>it.h).slice().sort((a,b)=>a-b);
  const median=heights[Math.floor(heights.length/2)]||maxH;
  if(maxH < median*1.25) return [];        // no clearly-larger title text → skip
  const big=topItems.filter(it=>it.h>=maxH*0.85).sort((a,b)=>a.y-b.y||a.x-b.x);
  const anchor=big[0];
  const gap=Math.max(maxH*1.8, page.w*0.05);
  // Assemble one visual row around vertical position `refY`. Height is gated at
  // 0.72×max (not 0.85) so a trailing token rendered a touch smaller — exactly
  // what OCR word-boxes and mixed typesetting produce for a surname — is NOT
  // dropped (the 3-token name "Ishan Rohit Malhotra" must stay whole). The run
  // is grown left/right only while items stay horizontally contiguous, so a
  // same-row token in another column (2-column layouts) is never swallowed. On
  // a continuation line (colX0/colX1 given) the seed must fall inside the name's
  // running column, so a second column on the same row is not merged.
  });
  return out;
}

/* ───────── text masking (for partial rendering, list display, copy) ───────── */
// Format-preserving partial phone mask: keep every non-digit character (+, spaces,
// dashes, parens) exactly where it is, reveal the leading group + last 4 digits,
// and replace only the middle digits with '*'. Never re-assembles into a fixed
// (Korean) layout. "+91 9599320477" → "+91 95****0477", "010-2345-6789" → "010-2***-6789".
function maskPhone(v){
  const digitIdx=[]; for(let i=0;i<v.length;i++) if(/\d/.test(v[i])) digitIdx.push(i);
  const n=digitIdx.length;
  if(n<6) return v.length? v[0]+'*'.repeat(Math.max(v.length-1,2)) : v;
  const back=4, front=n>=11?4:2;
  const maskFrom=front, maskTo=n-back;              // mask digit positions [maskFrom, maskTo)
  const out=v.split('');
  for(let k=maskFrom;k<maskTo;k++) out[digitIdx[k]]='*';
  return out.join('');
}
function maskHalf(type,v){
  switch(type){
    case 'name': return v.length<=1? v : v.length===2? v[0]+'*' : v[0]+'*'.repeat(v.length-2)+v[v.length-1];
    case 'phone': return maskPhone(v);
    case 'email': { const [a,b]=v.split('@'); return (a[0]||'')+'***@'+(b||''); }
    case 'rrn': case 'ssn': { const i=v.search(/[-‐ ]/); return i>0? v.slice(0,i+1)+'*'.repeat(v.length-i-1) : v.slice(0,6)+'*'.repeat(Math.max(v.length-6,0)); }
    case 'card': return v.slice(0,4)+v.slice(4,-4).replace(/\d/g,'*')+v.slice(-4);
    case 'account': return v.slice(0,3)+'*'.repeat(Math.max(v.length-6,2))+v.slice(-3);
    case 'birth': return v.replace(/\d{1,2}([일.\-\/]?)\s*$/,'**$1');
    case 'address': { const m=v.match(/^(.*?(?:시|군|구))/); return m? m[1]+' ***' : v.slice(0,4)+'***'; }
    case 'company': case 'title': return v[0]+'*'.repeat(Math.max(v.length-1,1));
    case 'ip': return v.replace(/\.\d{1,3}\.\d{1,3}$/,'.***.***');
    case 'url': { try{const u=new URL(v.startsWith('http')?v:'https://'+v);return u.hostname+'/***';}catch(e){return v.slice(0,10)+'***';} }
    default: return v.slice(0,Math.ceil(v.length/2))+'*'.repeat(Math.floor(v.length/2));
  }
}
const maskBlockText=v=>'■'.repeat(Math.min(Math.max(Math.round(v.replace(/\s/g,'').length*0.8),3),12));
// live value shown next to the toggle
function displayValue(e){ if(e.mode==='ok') return e.value; if(e.mode==='half') return maskHalf(e.type,e.value); return maskBlockText(e.value); }

/* ───────── coordinate index & box matching ───────── */
function buildIndex(page){
  if(page._idx) return;
  let s='', map=[];
  page.items.forEach((it,i)=>{ const str=it.str||''; for(let c=0;c<str.length;c++){ s+=str[c]; map.push([i,c]); } s+=' '; map.push(null); });
  page._text=s; page._map=map;
  // spaceless index (fallback for values whose spacing differs from source)
  let ss='', smap=[];
  page.items.forEach((it,i)=>{ const str=it.str||''; for(let c=0;c<str.length;c++){ const ch=str[c]; if(/\s/.test(ch))continue; ss+=ch; smap.push([i,c]); } });
  page._stext=ss; page._smap=smap;
  page._idx=true;
}
2:<html lang="ko">
19:<!-- Canonical / hreflang.
21:     (localStorage → navigator.language). 따라서 언어별 URL 이 존재하지 않으므로
22:     언어 간 상호참조 hreflang 은 가리킬 대상이 없다. Google 이 이 구조에 대해 문서화한
28:<link rel="alternate" hreflang="x-default" href="https://slimfile.net/safe/">
71:.lang-btn{border:1px solid var(--line);background:#fff;border-radius:8px;padding:5px 10px;font-family:inherit;font-size:12px;font-weight:500;cursor:pointer}
72:.lang-btn:hover{border-color:var(--ink)}
113:.btn:focus-visible,.seg button:focus-visible,.lang-btn:focus-visible{outline:2px solid var(--half);outline-offset:2px}
272:  .lang-btn{min-height:44px}
293:      <select class="lang-btn" id="langSel" aria-label="Select language">
516:  renderProg:(p,n)=>`페이지 렌더링 중… (${p}/${n})`, ocrStart:'글자 위치 인식 준비 중…', ocrProg:p=>`글자 인식(OCR) 중… ${p}%`,
517:  scanOcr:'스캔 문서 같아요 — 글자 위치를 OCR로 인식 중…', heicConv:'HEIC 이미지 변환 중…', building:'문서 만드는 중…',
570:  renderProg:(p,n)=>`Rendering pages… (${p}/${n})`, ocrStart:'Preparing text recognition…', ocrProg:p=>`Recognizing text (OCR)… ${p}%`,
571:  scanOcr:'Looks like a scan — recognizing text positions with OCR…', heicConv:'Converting HEIC image…', building:'Building document…',
624:  renderProg:(p,n)=>`ページをレンダリング中… (${p}/${n})`, ocrStart:'文字位置の認識を準備中…', ocrProg:p=>`文字認識(OCR)中… ${p}%`,
625:  scanOcr:'スキャン文書のようです — OCRで文字位置を認識中…', heicConv:'HEIC画像を変換中…', building:'文書を作成中…',
643:  s1:'Subir documento', s2:'Datos personales detectados', s3:'Crear documento', s3sub:'Superpone el enmascarado sobre tu original. El texto bajo las cajas negras no se copia.',
678:  renderProg:(p,n)=>`Renderizando páginas… (${p}/${n})`, ocrStart:'Preparando el reconocimiento de texto…', ocrProg:p=>`Reconociendo texto (OCR)… ${p}%`,
679:  scanOcr:'Parece un escaneo: reconociendo posiciones de texto con OCR…', heicConv:'Convirtiendo imagen HEIC…', building:'Creando documento…',
693:function detectLang(){
694:  try { const s = localStorage.getItem('safefile_lang'); if (s && LANGS.includes(s)) return s; } catch(e){}
695:  const n = (navigator.language||'ko').toLowerCase();
699:let LANG = detectLang();
740:async function ensureTesseract(){ if(!window.Tesseract) await loadScript(CDN_TESSERACT); return window.Tesseract; }
743:function OCR_LANGS(){ return ({ko:'kor+eng',en:'eng',ja:'jpn+eng',es:'spa+eng'})[LANG]||'eng'; }
752:/* ───────── apply language ───────── */
754:  document.documentElement.lang=LANG;
755:  try { localStorage.setItem('safefile_lang', LANG); } catch(e){}
756:  const sel=$('langSel'); if(sel) sel.value=LANG;
768:  // keep the result viewer in sync (fit label + fullscreen aria are language-dependent)
774:$('langSel').addEventListener('change',e=>{LANG=e.target.value;applyLang();});
776:/* ───────── regex detection ───────── */
790:/* International phone detection. Regex + digit-count validation per shape.
833:/* Address detection in 3 tiers (mirrors the name-candidate approach):
910:  // what OCR word-boxes and mixed typesetting produce for a surname — is NOT
1185:// it on language switch). Used for the office save-as-PDF path, which is too long
1219:/* PDF: render each page + text-layer boxes; OCR fallback for scanned pages */
1250:/* Image: draw to canvas, OCR for text boxes */
1273:  const Te=await ensureTesseract();
1274:  const { data } = await Te.recognize(cv, OCR_LANGS(), { logger:m=>{
1361:    // and both types default to 'half' when auto-detected. Defaulting these candidates
1365:    // still 'ok') nor the max_auto body-damage guard (which counts only kind='auto').
1589:/* ───────── detection list (live value next to toggle) ───────── */

hook: PostToolUse
hook: PostToolUse Completed
codex
초기 대조 결과, 전략서의 `pii_patterns`는 아직 실제 `index.html`에 구현되지 않았습니다. 현재 코드는 일본용 マイナンバー·資格確認書·在留カード·일본 여권·일본 주소 정규식이 없고, 일본 OCR 언어만 선택되는 상태라 S1 “완료”와 S3 계획 사이의 제품 공백이 큽니다. 이제 법적·제도적 주장과 문서별 제출 관행을 검증합니다.
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'mkdir -p .firecrawl && firecrawl search "site:ppc.go.jp 告知要求制限 健康保険法 施行 令和2年10月1日 記号 番号 枝番 QR 資格確認書" --limit 10 --scrape -o .firecrawl/search-kokuchi.json --json' in /Users/sunghoon/Projects/docpack
 exited 1 in 273ms:
Error: getaddrinfo ENOTFOUND api.firecrawl.dev

hook: PostToolUse
hook: PostToolUse Completed
codex
`firecrawl-search`는 현재 네트워크 이름 해석 오류로 실행되지 않았습니다. 같은 범위는 일반 웹 검색으로 전환하되, 법령·정부·사업자 공식 발표를 우선하고 확인되지 않는 내용은 요청대로 “확인 불가”로 표시하겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: site:ppc.go.jp 告知要求制限 健康保険法 令和2年10月1日 記号 番号 枝番 QRコード 資格確認書 ...
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: site:kojinbango-card.go.jp 裏面 コピー 個人番号カード 法律 提出 本人確認 ...
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: タイムズカー 個人情報 流出 660万 160万 2026 9月25日 ...
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: 
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: 日本 運転免許証 見本 画像 作成 法律 偽造 公文書 偽造 警察 ...
hook: PostToolUse
hook: PostToolUse Completed
codex
법령 검증에서는 두 가지 핵심 정정이 확인됐습니다. `告知要求制限`의 시행일은 맞지만, 대상은 “모든 제출에서 무조건 마스킹”이 아니라 의료보험 업무 등의 예외를 둔 “고지 요구 제한”입니다. 또 2027년 4월 개정은 모든 본인확인을 IC칩으로 바꾸는 단일 규칙이 아니라, 犯収法상 방법별 폐지·존치·예외를 포함한 개편입니다. 전략서 문구처럼 “그때까지 이미지 계좌개설의 구멍”으로 단순화하면 과장입니다.
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "nl -ba docs/jp/jp_safefile_strategy_2026-10-20.md | sed -n '1,220p' && nl -ba docs/jp/jp_documents_catalog.json | sed -n '1,180p' && nl -ba public/safe/index.html | sed -n '720,890p'" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
     1	# SafeFile 일본 진출 전략 v1 (2026-10-20)
     2	
     3	> 목적: "회사는 지켜주지 않는다. 서류는 내가 가린다"는 일본의 현재 정서를 SafeFile 유입으로 전환
     4	> 범위: 타깃 확정 → 문서 카탈로그 → 제품 요구사항 → 더미데이터 → 콘텐츠 3개월 → 운영
     5	
     6	---
     7	
     8	## 1. 지금이 기회인 이유 (팩트 기반)
     9	
    10	| 신호 | 내용 | 출처 |
    11	|---|---|---|
    12	| 타임즈카 유출 | 2026-09-25 발각. 최대 660만 계정, 그중 **면허증·학생증·주민표 이미지 약 160만 건** | 共同通信 10/3, 週刊アスキー 9/29 |
    13	| 집단소송 | 변호사 사이트 등록 **1만 5천 명(10/2 기준)** | 共同通信 |
    14	| 행정 반응 | 경시청·면허시험장에 재교부 상담 쇄도, 후쿠시마현 특별 재교부 접수(10/10) | bsrweb 10/8, 아메바 블로그 |
    15	| 연쇄 유출 | 10월 들어 大和証券·物語コーポレーション 등 추가 발표 | bsrweb 10/8 |
    16	| 제도 공백 | IC칩 본인확인 의무화는 **2027년 4월** → 그때까지 "이미지만으로 계좌 개설" 창구 잔존 | 週刊アスキー |
    17	| 법적 마스킹 의무 | 保険証·資格確認書 사본 제출 시 **保険者番号·記号·番号·枝番·QR** 마스킹 (告知要求制限, 2020-10-01 시행) — 지자체·은행·카드사가 "마스킹해서 내라" 안내 중 | 大阪府, 東京都共済, PayPay銀行, SoftBank |
    18	
    19	**핵심 통찰**: 일본에는 이미 "黒塗り(구로누리)"라는 **의무이자 관행**이 있고, 사람들은 지금 그것을 **付箋·마스킹테이프·스마트폰 편집앱**으로 손수 하고 있다. 경쟁 도구는 B2B eKYC(ProTech AI Masking, TRUSTDOCK)뿐이고 **개인용 무료 웹툴은 공백**. "黒塗りしたつもりが透ける" 공포(모자이크·반투명 복원)도 커뮤니티에서 반복 언급 → "이미지로 평탄화해서 복원 불가"가 SafeFile의 기술 메시지.
    20	
    21	---
    22	
    23	## 2. 타깃 — 연령이 아니라 "제출을 피할 수 없는 순간"으로 정의
    24	
    25	| 순위 | 세그먼트 | 연령 중심 | 반드시 제출하는 서류 | 왜 1순위인가 | 콘텐츠 훅 |
    26	|---|---|---|---|---|---|
    27	| **1** | 転職・引越し・副業을 동시에 겪는 사회초년~중견 | **25–39** | 履歴書·職務経歴書, 免許証, 資格確認書/保険証, 住民票, 源泉徴収票, 賃貸契約書 | 제출 빈도 최다, 스마트폰으로 서류 찍어 보내는 세대, 타임즈카 피해자 다수(기사 인터뷰 27세·34세 회사원) | "送る前に30秒で黒塗り" |
    28	| 2 | 프리마·중고거래·크라우드소싱 본인확인 | 20–34 | 免許証, マイナカード表面, 在留カード | 메르카리 2025년 고액거래 본인확인 의무화 → 신규 18%가 에러 경험, "画像を送るのが怖い" 질문 다수 | "メルカリに免許証を送る前に" |
    29	| 3 | 건설·개인사업자·관리자 (입찰·허가 서류) | 35–55 | 保険証写し, 標準報酬決定通知書, 住民票 | **법적 마스킹 의무** + 지자체가 견본 PDF 배포 → 검색 의도 명확, 재제출 공포 | "入札書類の保険証マスキング、再提出なしで" |
    30	| 4 | 외국인 거주자 (영어 버전 대상) | 20–40 | 在留カード, パスポート, 住民票 | 영어 버전 운영 요구에 부합, 일본어 서류를 영어 UI로 가릴 수 있는 유일한 툴 포지션 | "Redact your 在留カード in English UI" |
    31	
    32	**결정**: 1순위 세그먼트(25–39)를 메인, 3순위(건설·사업자)를 SEO 롱테일로 병행. 2·4는 콘텐츠만.
    33	
    34	### 저장 기능 → 수수료 정책 (요청 반영)
    35	- 무료: 업로드→마스킹→다운로드(서버 미저장 유지)
    36	- 유료(후속): **"マスキング済み書類ボックス"** — 가린 사본만 암호화 저장, 다음 제출 때 재사용. 원본은 절대 저장하지 않음(개인정보처리방침과 무충돌). 과금 근거: "매번 다시 가리지 않아도 됨"
    37	- 가격 가설: 月額 300~500엔 또는 1회 100엔. 검증은 콘텐츠 반응 후
    38	
    39	---
    40	
    41	## 3. 제품 요구사항 (JP 출시 게이트)
    42	
    43	### 3-1. 마스킹 방식 단일화 (결정 반영)
    44	- 별표(***)·부분값 오버레이 **폐지** → 띠(바)만. 색은 검정 기본 + 흰색·사용자 지정 1색
    45	- 띠는 OCR/텍스트 좌표 박스를 2px 패딩으로 덮고 **래스터 평탄화** → "透けない黒塗り" 보증 문구 사용 가능
    46	- 출력: JPG(0.85~0.92)·PNG·PDF(텍스트 레이어 없음). docx/xlsx 원본 포맷 유지는 2차
    47	
    48	### 3-2. 일본어 탐지(JP-1) 필수 패턴
    49	| 유형 | 패턴 | 비고 |
    50	|---|---|---|
    51	| マイナンバー | 12자리, 4-4-4 구분 허용, **체크디지트 검증** | 裏面·通知カード·源泉徴収票·住民票에 등장 |
    52	| 保険者番号 | 8자리(健保) / 6자리(国保) | |
    53	| 記号・番号・枝番 | 記号 1~8자리 + 番号 1~8자리 + 枝番 2자리 | 레이블 앵커 "記号"/"番号"/"枝番" 필수 |
    54	| 運転免許証番号 | 12자리 | 레이블 "番号"/"第" 앵커 |
    55	| 在留カード番号 | 영2+숫8+영2 (AB12345678CD) | |
    56	| パスポート | 영2+숫7 (TR1234567) | |
    57	| 電話 | 0X0-XXXX-XXXX / 03-XXXX-XXXX / 0120 | 시외국번 가변 |
    58	| 郵便番号 | 〒?\d{3}-\d{4} | |
    59	| 住所 | 都道府県+市区町村+丁目番地号 (전각 숫자·漢数字 포함) | |
    60	| 生年月日 | 和暦(昭和/平成/令和 N年M月D日)+서기 | 和暦 → 서기 변환 불필요, 탐지만 |
    61	| 銀行口座 | 支店番号 3자리 + 口座番号 7자리, 레이블 앵커 | 通帳·給与明細 |
    62	| 本籍 | 레이블 "本籍" 뒤 주소 | 住民票·戸籍 |
    63	| QR/二次元コード | 이미지 탐지(OpenCV 불가 시 사각 고대비 영역 휴리스틱) | 資格確認書 마스킹 항목 |
    64	- 전각/반각 정규화, 오탐 가드에 **일본 기관명·지명 리스트** 추가
    65	- 골든 하네스에 일본어 픽스처 ≥8종 추가, max_auto 상한 재산정
    66	
    67	### 3-3. 서류 프리셋(JP-3) — "이 서류는 여기"를 버튼 하나로
    68	| 프리셋 | 자동 띠 위치 | 근거 |
    69	|---|---|---|
    70	| 健康保険証 / 資格確認書 | 保険者番号, 記号, 番号, 枝番, QR, 性別 | 告知要求制限 + 은행·카드사 안내 |
    71	| 運転免許証 | 臓器提供意思表示欄(裏), 本籍変更履歴, 免許証番号(선택) | SoftBank 안내 |
    72	| マイナンバーカード | **裏面 전체 경고 + 업로드 차단 권유**, 表面 性別·臓器提供 | 지자체 안내(裏面 コピー禁止) |
    73	| 住民票 | 個人番号, 本籍, 性別, 世帯主 이외 가족 | 大阪府·SoftBank |
    74	| 在留カード / パスポート | 番号, 性別(선택) | |
    75	| 履歴書(JIS) | 住所 상세, 電話, 生年月日 일부, 写真(선택) | 공유용 |
    76	
    77	### 3-4. 워터마크 프리셋(일본 관행 문구)
    78	「〇〇提出用」「本人確認のみに使用」「コピー・転用禁止」「2026年10月20日 ○○社提出」 + 날짜 자동
    79	
    80	---
    81	
    82	## 4. 일본 개인정보 문서 카탈로그 (더미 생성 대상)
    83	
    84	> 상세 필드는 `jp_documents_catalog.json` 참조. 공공 7 + 개인 6 = 13종, 포맷별 변형 포함 40~50개 파일 목표.
    85	
    86	| # | 문서 | 유형 | 주 포맷 | 핵심 PII | 마스킹 관행 |
    87	|---|---|---|---|---|---|
    88	| 1 | 運転免許証 | 카드(표·裏) | JPG(스마트폰 촬영) | 氏名, 生年月日, 住所, 番号, 顔写真, 本籍変更履歴 | 臓器提供欄·裏面 변경이력 |
    89	| 2 | マイナンバーカード | 카드(표·裏) | JPG | 氏名, 住所, 生年月日, 性別, 個人番号(裏), 顔写真 | 裏面 제출 금지 |
    90	| 3 | 健康保険証(구) / 資格確認書(신) | 카드/A4 | JPG, PDF | 記号, 番号, 枝番, 保険者番号, QR, 事業所名 | 법적 의무 마스킹 |
    91	| 4 | 住民票の写し | A4 공문서 | PDF, JPG | 氏名, 住所, 本籍, 個人番号, 世帯員, 続柄 | 本籍·個人番号·가족 |
    92	| 5 | 在留カード | 카드 | JPG | 番号, 国籍, 在留資格, 期間 | 番号 |
    93	| 6 | パスポート 身分事項ページ | 책 | JPG | 旅券番号, 本籍(都道府県), MRZ | 番号·MRZ |
    94	| 7 | 源泉徴収票 | A4 세무 | PDF, XLSX | 個人番号, 住所, 支払金額, 控除対象配偶者 | 個人番号·금액 |
    95	| 8 | 履歴書(JIS 規格) | A4/A3 개인 | DOCX, PDF, XLSX | 氏名, 生年月日, 住所, 電話, メール, 写真, 学歴·職歴 | 공유 시 상세주소·전화 |
    96	| 9 | 職務経歴書 | A4 개인 | DOCX, PDF | 氏名, 連絡先, 会社名, 年収(가끔) | 연봉·회사명 |
    97	| 10 | 給与明細 / 標準報酬決定通知書 | A4 | PDF, XLSX | 社員番号, 口座, 支給額, 被保険者整理番号 | 整理番号·口座 |
    98	| 11 | 賃貸借契約書 | A4 복수쪽 | PDF | 貸主·借主 氏名住所, 保証人, 印影, 口座 | 제3자 정보·印影 |
    99	| 12 | 通帳 / 振込明細 | 책/영수 | JPG | 口座番号, 残高, 取引履歴 | 口座·残高 |
   100	| 13 | 在職証明書 / 卒業証明書 / 成績証明書 | A4 | PDF, DOCX | 氏名, 生年月日, 学籍番号, 成績 | 학적번호·성적 |
   101	
   102	더미 생성 원칙: 이름(架空 姓名 생성), 주소(존재하지 않는 番地), 번호(체크디지트는 맞되 실존 불가 패턴), 사진(실루엣/生成 아바타), 모든 카드에 「見本」 워터마크. 실물 디자인의 문양·홀로그램은 재현하지 않음.
   103	
   104	---
   105	
   106	## 5. 콘텐츠 전략 (3개월, 3일 1회 = 30편)
   107	
   108	### 플랫폼 3개 (근거: ICT総研 2026-07 — LINE 71.1%, YouTube 67.6%, X 45.4%, Instagram 42.0%)
   109	1. **X** — 유출 뉴스가 실시간으로 도는 곳. 텍스트+이미지 1장, 스레드. 가장 빠른 유입
   110	2. **YouTube Shorts** — 사용법 How-to 10편의 집. 검색 유입(「保険証 マスキング やり方」) 지속
   111	3. **Instagram Reels** — 25–39 여성 비중 보강, 카루셀로 "どこを隠す" 도해 재활용
   112	- LINE: 유저 최다이나 신규 계정 도달 0 → 제외. 단, LINE 공식계정은 유료 전환 후 CRM용으로 재검토
   113	
   114	### 2트랙
   115	- **트랙 A: How-to 10편(서류 1종=1편)** — 더미 문서를 실제 사이트에 올려 가리고 내려받는 60초 화면녹화 + 자막. 일본어/영어 2버전
   116	- **트랙 B: 에피소드 20편** — 1인 상황극(텍스트+정지화면 슬라이드, 추후 영상화). 예: "メルカリに免許証を送る夜", "入札書類を再提出させられた日", "元彼に住民票を送っていた話(픽션)"
   117	
   118	### 30편 주제안 (검수용)
   119	| 회 | 트랙 | 주제(일본어 제목) | 서류 |
   120	|---|---|---|---|
   121	| 1 | B | 免許証の画像、会社は守ってくれなかった — 660万件のあと私がしたこと | 免許証 |
   122	| 2 | A | 【30秒】保険証・資格確認書の記号番号を黒塗りする方法 | 資格確認書 |
   123	| 3 | A | 運転免許証を送る前に隠すべき3か所 | 免許証 |
   124	| 4 | B | 「黒塗りしたつもり」が透けていた話 | — |
   125	| 5 | A | マイナンバーカード、裏面は絶対に送らない。表面はここを隠す | マイナカード |
   126	| 6 | B | メルカリ本人確認、怖くてできない人へ | 免許証 |
   127	| 7 | A | 住民票の写し、本籍とマイナンバーを消して提出する | 住民票 |
   128	| 8 | B | 入札書類の保険証、マスキング忘れで再提出になった | 保険証 |
   129	| 9 | A | 履歴書PDFから住所と電話だけ消して共有する | 履歴書 |
   130	| 10 | B | 付箋とマスキングテープ、もうやめませんか | — |
   131	| 11 | A | 源泉徴収票のマイナンバー欄を隠して提出 | 源泉徴収票 |
   132	| 12 | B | 賃貸契約で身分証コピーを求められたとき | 免許証·住民票 |
   133	| 13 | A | 在留カードを安全に送る(英語版同時) | 在留カード |
   134	| 14 | B | 退会しても7年保存されていた私の免許証 | — |
   135	| 15 | A | 給与明細の口座番号と社員番号を隠す | 給与明細 |
   136	| 16 | B | 口座開設は「画像だけ」で通る?2027年4月まで続く穴 | — |
   137	| 17 | A | 賃貸借契約書、相手の個人情報まで消してから相談する | 契約書 |
   138	| 18 | B | 黒塗りは誰の責任?企業は「マスキングして送れ」と言う | — |
   139	| 19 | A | パスポートの番号とMRZを隠す | パスポート |
   140	| 20 | B | 信用情報機関への本人申告(JICC/CIC)と一緒にやること | — |
   141	| 21 | A | 通帳の残高と口座番号、スクショ前に消す | 通帳 |
   142	| 22 | B | 学生証の画像も流出していた — 学生がいま出来ること | 学生証 |
   143	| 23 | A | 職務経歴書の年収と会社名を伏せて送る | 職務経歴書 |
   144	| 24 | B | 「サーバーに保存しない」ツールしか使わない理由 | — |
   145	| 25 | A | スマホだけで完結:撮影→黒塗り→送信 | 全般 |
   146	| 26 | B | 副業の本人確認、毎回同じ書類を撮り直していませんか | — |
   147	| 27 | A | 透かし「〇〇提出用」を入れて転用を防ぐ | 全般 |
   148	| 28 | B | 家族の分も:子どもの保険証、親の住民票 | 保険証 |
   149	| 29 | A | 10枚まとめて黒塗り(一括処理) | 全般 |
   150	| 30 | B | 2か月やってみた総括 + 読者の黒塗り失敗集 | — |
   151	
   152	---
   153	
   154	## 6. 실행 순서와 게이트
   155	
   156	| 단계 | 산출물 | 완료 기준 | 담당 |
   157	|---|---|---|---|
   158	| S1 조사·카탈로그 | 본 문서 + catalog.json | 13종 필드·관행 확정 | 완료(본 문서) |
   159	| S2 더미 생성 | 40~50 파일 (docx/pdf/xlsx/jpg) | 각 문서에 기대 마스킹 specs.json 동봉 | Claude(이 세션) |
   160	| S3 JP-1 탐지 + 띠 단일화 | index.html 수정, 골든 +8 | `node run.mjs` 0 exit, 일본어 픽스처 전부 통과 | Claude Code |
   161	| S4 JP-3 프리셋 + 워터마크 | 프리셋 6종 | 더미 13종 수동 검수 통과 | Claude Code |
   162	| S5 실사이트 검증 | 제가 Chrome로 업로드·다운로드 | 13종 중 12종 이상 1분 내 완료 | Claude |
   163	| S6 콘텐츠 제작 | 30편(JA/EN) + How-to 녹화 10편 | 주제 검수 후 순차 | Claude |
   164	| S7 게시 운영 | 3일 1회 전달 → Justin 게시 | 반응 데이터로 유료화 결정 | Justin |
   165	
   166	**홍보는 S5 통과 전 시작 금지.** 타임즈카 이슈는 길어야 2~3개월 지속 → S3~S5를 2주 안에 끝내야 파도를 탐.
   167	
   168	---
   169	
   170	## 7. 리스크·미확인
   171	
   172	- 일본어 OCR recall 미측정(Tesseract jpn). 스마트폰 사진 품질에서 記号·番号 인식률이 낮으면 프리셋(좌표 기반)이 백업
   173	- 카드 더미 이미지의 법적 민감성 → 「見本」 명시·문양 미재현으로 관리
   174	- safefile.net 도메인 미확정. 일본어 콘텐츠 URL이 slimfile.net/safe/ 로 노출되면 브랜드 분산
   175	- X 소셜리스닝은 API 없이 검색엔진 경유만 가능 → 정량 데이터는 Yahoo!知恵袋·bengo4·note로 보완
     1	{
     2	  "version": "2026-10-20",
     3	  "purpose": "SafeFile JP — 일본 개인정보 문서 카탈로그. 더미 생성·프리셋·탐지 규칙의 정본.",
     4	  "pii_patterns": {
     5	    "my_number": {"regex": "\\d{4}[-\\s]?\\d{4}[-\\s]?\\d{4}", "digits": 12, "check_digit": "mod11 (個人番号検査用数字)", "appears_in": ["マイナンバーカード裏面", "通知カード", "住民票(記載あり)", "源泉徴収票", "扶養控除申告書"]},
     6	    "hokensha_bango": {"regex": "(?<=保険者番号)\\s*\\d{6,8}", "note": "健保8桁 / 国保6桁"},
     7	    "kigo_bango_edaban": {"regex": "記号\\s*[\\d０-９A-Za-z]{1,8}.*?番号\\s*[\\d０-９]{1,8}(.*?枝番\\s*\\d{2})?", "note": "告知要求制限 대상"},
     8	    "driver_license_no": {"regex": "(?<=番号|第)\\s*\\d{12}", "digits": 12},
     9	    "zairyu_card_no": {"regex": "[A-Z]{2}\\d{8}[A-Z]{2}"},
    10	    "passport_no": {"regex": "[A-Z]{2}\\d{7}"},
    11	    "phone": {"regex": "(0[5-9]0-?\\d{4}-?\\d{4}|0\\d{1,4}-?\\d{1,4}-?\\d{4}|0120-?\\d{3}-?\\d{3})"},
    12	    "postal": {"regex": "〒?\\s*\\d{3}-\\d{4}"},
    13	    "address": {"regex": "(北海道|東京都|(?:京都|大阪)府|.{2,3}県).{1,12}?(市|区|郡|町|村).{0,20}?([0-9０-９一二三四五六七八九十]+丁目)?.{0,15}?[0-9０-９一二三四五六七八九十]+(番地?|-|−|ー)[0-9０-９]*(号)?"},
    14	    "birth_wareki": {"regex": "(明治|大正|昭和|平成|令和|M|T|S|H|R)\\s*(元|\\d{1,2})年\\s*\\d{1,2}月\\s*\\d{1,2}日"},
    15	    "birth_seireki": {"regex": "(19|20)\\d{2}[年/.-]\\s*\\d{1,2}[月/.-]\\s*\\d{1,2}日?"},
    16	    "bank_account": {"regex": "(店番|支店(番号|コード))\\s*\\d{3}.*?(口座番号|口座)\\s*\\d{7}", "note": "레이블 앵커 필수"},
    17	    "honseki": {"regex": "(?<=本籍)\\s*.{4,40}"},
    18	    "qr": {"type": "image-heuristic", "note": "資格確認書 二次元コード"}
    19	  },
    20	  "documents": [
    21	    {"id": "jp01", "name": "運転免許証", "category": "公的身分証", "owner_segment": [1,2], "formats": ["jpg(表)", "jpg(裏)", "pdf(両面コピー)"],
    22	     "fields": ["氏名", "生年月日(和暦)", "住所", "交付日", "有効期限", "免許の条件", "番号(12桁)", "種類", "顔写真", "公安委員会名", "裏面:本籍変更/住所変更履歴", "裏面:臓器提供意思表示欄"],
    23	     "mask_norm": {"always": ["臓器提供意思表示欄", "裏面変更履歴"], "optional": ["番号", "本籍"], "keep_for_kyc": ["氏名", "生年月日", "住所", "顔写真", "有効期限"]},
    24	     "preset": "license", "source": ["SoftBank Dialpad 本人確認書類案内", "aspicjapan.org"]},
    25	    {"id": "jp02", "name": "マイナンバーカード(個人番号カード)", "category": "公的身分証", "owner_segment": [1,2], "formats": ["jpg(表)", "jpg(裏)"],
    26	     "fields": ["氏名", "住所", "生年月日", "性別", "有効期限", "顔写真", "券面記載事項追記欄", "裏面:個人番号(12桁)", "裏面:氏名", "裏面:生年月日", "裏面:臓器提供意思", "裏面:QR"],
    27	     "mask_norm": {"always": ["裏面全体(提出禁止)"], "optional": ["性別", "臓器提供意思"], "keep_for_kyc": ["表面"]},
    28	     "preset": "mynumber_card", "source": ["愛知県 本人確認書類留意点", "墨田区·品川区 利用案内", "秋田市FAQ"]},
    29	    {"id": "jp03", "name": "健康保険証(旧) / 資格確認書(新)", "category": "公的身分証", "owner_segment": [1,3], "formats": ["jpg(カード)", "pdf(A4 資格確認書)", "jpg(縦型紙)"],
    30	     "fields": ["記号", "番号", "枝番", "氏名", "生年月日", "性別", "資格取得年月日", "事業所名称", "保険者番号", "保険者名称", "保険者所在地", "交付日", "二次元コード"],
    31	     "mask_norm": {"always": ["保険者番号", "記号", "番号", "枝番", "二次元コード"], "optional": ["性別", "通院歴(家族分含む)"], "keep_for_kyc": ["氏名", "生年月日", "住所", "事業所名称"]},
    32	     "legal": "健康保険法 告知要求制限 (令和2年10月1日施行)", "preset": "insurance", "source": ["大阪府 添付注意", "東京都共済 R8.7.27 加筆", "PayPay銀行", "千葉市", "長崎県建設企画課"]},
    33	    {"id": "jp04", "name": "住民票の写し", "category": "公文書", "owner_segment": [1,3,4], "formats": ["pdf", "jpg(撮影)"],
    34	     "fields": ["氏名", "生年月日", "性別", "住所", "世帯主", "続柄", "本籍", "筆頭者", "住民となった日", "個人番号(記載選択時)", "住民票コード", "市区町村長印"],
    35	     "mask_norm": {"always": ["個人番号", "住民票コード"], "optional": ["本籍", "筆頭者", "性別", "本人以外の世帯員"], "keep_for_kyc": ["氏名", "生年月日", "住所", "発行日"]},
    36	     "preset": "juminhyo", "source": ["大阪府", "SoftBank", "aspicjapan"]},
    37	    {"id": "jp05", "name": "在留カード", "category": "公的身分証", "owner_segment": [4], "formats": ["jpg(表)", "jpg(裏)"],
    38	     "fields": ["氏名(ローマ字)", "生年月日", "性別", "国籍·地域", "住居地", "在留資格", "就労制限の有無", "在留期間", "在留カード番号", "顔写真", "裏面:住居地変更", "裏面:資格外活動許可"],
    39	     "mask_norm": {"always": [], "optional": ["在留カード番号", "性別"], "keep_for_kyc": ["氏名", "生年月日", "住居地", "在留資格", "在留期間"]},
    40	     "preset": "zairyu", "source": ["TRUSTDOCK 対応書類"]},
    41	    {"id": "jp06", "name": "パスポート 身分事項ページ", "category": "公的身分証", "owner_segment": [1,4], "formats": ["jpg"],
    42	     "fields": ["旅券番号", "姓", "名", "国籍", "生年月日", "性別", "本籍(都道府県)", "発行日", "有効期限", "発行官庁", "顔写真", "MRZ 2行"],
    43	     "mask_norm": {"always": [], "optional": ["旅券番号", "MRZ", "性別", "本籍"], "keep_for_kyc": ["姓名", "生年月日", "有効期限", "顔写真"]},
    44	     "preset": "passport", "source": ["aspicjapan"]},
    45	    {"id": "jp07", "name": "源泉徴収票(給与所得の)", "category": "税務", "owner_segment": [1,3], "formats": ["pdf", "xlsx", "jpg"],
    46	     "fields": ["支払を受ける者 住所", "氏名", "個人番号", "支払金額", "給与所得控除後の金額", "所得控除の額の合計額", "源泉徴収税額", "控除対象配偶者", "扶養親族", "社会保険料等", "生命保険料", "住宅借入金", "支払者 名称·住所·法人番号"],
    47	     "mask_norm": {"always": ["個人番号"], "optional": ["支払金額", "税額", "配偶者·扶養親族氏名", "住所"], "keep_for_kyc": ["氏名", "支払者名", "年分"]},
    48	     "preset": "gensen", "source": ["一般慣行"]},
    49	    {"id": "jp08", "name": "履歴書(JIS規格)", "category": "個人文書", "owner_segment": [1,2], "formats": ["docx", "pdf", "xlsx", "jpg(手書きスキャン)"],
    50	     "fields": ["氏名", "ふりがな", "生年月日", "年齢", "性別", "現住所", "〒", "電話", "携帯", "メール", "連絡先", "写真", "学歴", "職歴", "免許·資格", "志望動機", "本人希望欄", "配偶者·扶養家族(旧様式)"],
    51	     "mask_norm": {"always": [], "optional": ["現住所 番地以下", "電話", "メール", "写真", "生年月日 日", "配偶者·扶養"], "keep_for_share": ["氏名(or イニシャル)", "学歴", "職歴", "資格"]},
    52	     "preset": "rirekisho", "source": ["JIS Z 8303 様式慣行"]},
    53	    {"id": "jp09", "name": "職務経歴書", "category": "個人文書", "owner_segment": [1], "formats": ["docx", "pdf"],
    54	     "fields": ["氏名", "日付", "連絡先", "職務要約", "会社名", "在籍期間", "部署·役職", "年収(記載時)", "実績数値", "取引先名"],
    55	     "mask_norm": {"optional": ["連絡先", "会社名", "年収", "取引先名"]},
    56	     "preset": "shokumu", "source": ["一般慣行"]},
    57	    {"id": "jp10", "name": "給与明細 / 標準報酬決定通知書", "category": "給与", "owner_segment": [1,3], "formats": ["pdf", "xlsx", "jpg"],
    58	     "fields": ["社員番号", "氏名", "所属", "支給額内訳", "控除額内訳", "差引支給額", "振込口座(銀行·支店·口座番号)", "被保険者整理番号", "事業所整理番号", "標準報酬月額"],
    59	     "mask_norm": {"always": ["被保険者整理番号", "口座番号"], "optional": ["社員番号", "金額"], "keep_for_kyc": ["氏名", "事業所名", "対象月"]},
    60	     "preset": "payslip", "source": ["山梨県 標準報酬決定通知書 マスキング", "京都府"]},
    61	    {"id": "jp11", "name": "賃貸借契約書", "category": "契約", "owner_segment": [1], "formats": ["pdf(複数頁)", "jpg(撮影)"],
    62	     "fields": ["物件所在地", "貸主 氏名·住所", "借主 氏名·住所·生年月日·電話", "連帯保証人 氏名·住所·電話·勤務先", "緊急連絡先", "賃料", "敷金·礼金", "振込口座", "印影", "仲介業者 免許番号"],
    63	     "mask_norm": {"always": ["第三者(貸主·保証人)の個人情報", "印影", "振込口座"], "optional": ["借主 電話·生年月日", "物件 号室"]},
    64	     "preset": "lease", "source": ["bengo4 相談事例"]},
    65	    {"id": "jp12", "name": "通帳 / 振込明細 / 残高証明", "category": "金融", "owner_segment": [1,2], "formats": ["jpg", "pdf(ネット銀行)"],
    66	     "fields": ["銀行名", "支店名·店番", "口座番号", "口座名義(カナ)", "残高", "取引履歴(日付·摘要·金額)", "振込先名"],
    67	     "mask_norm": {"always": ["口座番号", "残高"], "optional": ["取引履歴 相手名"], "keep": ["銀行名", "支店名", "名義"]},
    68	     "preset": "bankbook", "source": ["一般慣行"]},
    69	    {"id": "jp13", "name": "在職証明書 / 卒業証明書 / 成績証明書 / 学生証", "category": "証明書", "owner_segment": [1,2], "formats": ["pdf", "docx", "jpg(学生証)"],
    70	     "fields": ["氏名", "生年月日", "学籍番号/社員番号", "所属", "入学·入社日", "成績(科目·評価·GPA)", "発行者印", "顔写真(学生証)"],
    71	     "mask_norm": {"always": ["学籍番号·社員番号"], "optional": ["成績明細", "生年月日", "顔写真"]},
    72	     "preset": "certificate", "source": ["タイムズカー流出 学生証画像 事例"]}
    73	  ],
    74	  "watermark_presets_ja": ["〇〇提出用", "本人確認のみに使用", "コピー・転用禁止", "{date} {recipient}提出用", "SafeFileで黒塗り済み"],
    75	  "dummy_generation_rules": {
    76	    "names": "架空姓名(常用漢字ランダム組合せ, 実在有名人回避)",
    77	    "addresses": "実在都道府県·市区 + 存在しない丁目番地(例: 99丁目)",
    78	    "numbers": "チェックディジット整合, 先頭に非実在プレフィックス",
    79	    "photos": "生成アバター or シルエット",
    80	    "all_cards": "「見本」透かし必須, 公的紋様·ホログラム非再現",
    81	    "formats_per_doc": ["docx", "pdf", "xlsx(表形式のみ)", "jpg 撮影風(斜め·影)", "png スキャン風"]
    82	  },
    83	  "sources": [
    84	    "https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf",
    85	    "https://www.kyosai.metro.tokyo.jp/assets/84b47fd406a8378372a6015863f83bc93c0c8a75.pdf",
    86	    "https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html",
    87	    "https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf",
    88	    "https://www.aspicjapan.org/asu/article/6908",
    89	    "https://www.pref.aichi.jp/uploaded/attachment/364666.pdf",
    90	    "https://www.sn-hoki.co.jp/articles/article4935267/",
    91	    "https://weekly.ascii.jp/elem/000/004/437/4437878/",
    92	    "https://bsrweb.jp/article/480322",
    93	    "https://prtimes.jp/main/html/rd/p/000000030.000019182.html"
    94	  ]
    95	}
   720	
   721	const TYPES = {
   722	  rrn:{icon:'🪪',risk:'no'}, ssn:{icon:'🪪',risk:'no'}, passport:{icon:'🛂',risk:'no'},
   723	  license:{icon:'🚗',risk:'no'}, card:{icon:'💳',risk:'no'}, account:{icon:'🏦',risk:'no'},
   724	  phone:{icon:'📞',risk:'half'}, email:{icon:'✉️',risk:'half'}, birth:{icon:'🎂',risk:'half'},
   725	  address:{icon:'📍',risk:'half'}, name:{icon:'👤',risk:'half'},
   726	  company:{icon:'🏢',risk:'ok'}, title:{icon:'💼',risk:'ok'},
   727	  ip:{icon:'🌐',risk:'no'}, url:{icon:'🔗',risk:'half'}, health:{icon:'🏥',risk:'no'},
   728	  // 'other' = "분류 불확실". 불확실한 것을 기본 마스킹하면 시험명·수상명·자격증명 같은
   729	  // 비(非)PII 본문이 자동으로 훼손된다(예: TOPIK→TOP**). 확실한 유형만 기본 마스킹하고
   730	  // other 는 기본 공개(ok) 후 사용자가 필요 시 직접 켠다. (오탐 본문 훼손 방지)
   731	  other:{icon:'📌',risk:'ok'}
   732	};
   733	Object.keys(TYPES).forEach(t=>{catEnabled[t]=true;catDefault[t]=TYPES[t].risk;});
   734	const isOn=e=>catEnabled[e.type]!==false;
   735	const tLabel=t=>T().types[t]||t;
   736	
   737	/* ───────── lazy library loaders ───────── */
   738	const _scripts={};
   739	function loadScript(src){return _scripts[src]||(_scripts[src]=new Promise((res,rej)=>{const s=document.createElement('script');s.src=src;s.async=true;s.onload=res;s.onerror=()=>rej(new Error('load fail '+src));document.head.appendChild(s);}));}
   740	async function ensureTesseract(){ if(!window.Tesseract) await loadScript(CDN_TESSERACT); return window.Tesseract; }
   741	async function ensureHeic(){ if(!window.heic2any) await loadScript(CDN_HEIC); return window.heic2any; }
   742	async function ensureJsPDF(){ if(!(window.jspdf&&window.jspdf.jsPDF)) await loadScript(CDN_JSPDF); return window.jspdf; }
   743	function OCR_LANGS(){ return ({ko:'kor+eng',en:'eng',ja:'jpn+eng',es:'spa+eng'})[LANG]||'eng'; }
   744	
   745	/* ───────── hero cycle ───────── */
   746	let cw=0;
   747	function renderHero(){
   748	  $('heroH1').innerHTML = T().heroPre + `<span class="redact-word"><span id="cycleWord">${T().cycle[cw]}</span><span class="bar" aria-hidden="true"></span></span>` + T().heroPost;
   749	}
   750	setInterval(()=>{cw=(cw+1)%T().cycle.length;const el=$('cycleWord');if(el)el.textContent=T().cycle[cw];},3600);
   751	
   752	/* ───────── apply language ───────── */
   753	function applyLang(){
   754	  document.documentElement.lang=LANG;
   755	  try { localStorage.setItem('safefile_lang', LANG); } catch(e){}
   756	  const sel=$('langSel'); if(sel) sel.value=LANG;
   757	  document.querySelectorAll('[data-i18n]').forEach(el=>{
   758	    const k=el.dataset.i18n; const v=T()[k];
   759	    if(typeof v==='string') el.innerHTML=v;
   760	  });
   761	  document.querySelectorAll('[data-i18n-ph]').forEach(el=>{const v=T()[el.dataset.i18nPh];if(typeof v==='string')el.placeholder=v;});
   762	  document.querySelectorAll('[data-i18n-aria]').forEach(el=>{const v=T()[el.dataset.i18nAria];if(typeof v==='string')el.setAttribute('aria-label',v);});
   763	  $('pasteArea').placeholder=T().pastePh;
   764	  const ml=$('manifestLink'); if(ml) ml.href=`/safe/manifest.${LANG}.webmanifest`;
   765	  if(typeof refreshInstallBanner==='function') refreshInstallBanner();
   766	  buildWmPresets();
   767	  renderHero(); renderList(); buildPreview();
   768	  // keep the result viewer in sync (fit label + fullscreen aria are language-dependent)
   769	  if(typeof rvPages!=='undefined' && rvPages.length && $('result') && $('result').style.display!=='none'){
   770	    const b=$('rvFull'); if(b&&rvIsFull) b.setAttribute('aria-label',T().rvExitAria);
   771	    rvRender();
   772	  }
   773	}
   774	$('langSel').addEventListener('change',e=>{LANG=e.target.value;applyLang();});
   775	
   776	/* ───────── regex detection ───────── */
   777	const REGEX_RULES=[
   778	  {type:'rrn',    re:/\d{6}[-‐ ]?[1-4]\d{6}/g},
   779	  {type:'ssn',    re:/\b\d{3}-\d{2}-\d{4}\b/g},
   780	  {type:'card',   re:/\b\d{4}[- ]\d{4}[- ]\d{4}[- ]\d{4}\b/g},
   781	  {type:'email',  re:/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g},
   782	  {type:'passport',re:/\b[MSRODG]\d{8}\b/g},
   783	  {type:'license',re:/\b\d{2}-\d{2}-\d{6}-\d{2}\b/g},
   784	  {type:'account',re:/\b\d{3,6}-\d{2,6}-\d{3,6}\b/g},
   785	  {type:'ip',     re:/\b(?:\d{1,3}\.){3}\d{1,3}\b/g},
   786	  {type:'birth',  re:/\b(19|20)\d{2}[.\-\/년 ]\s?\d{1,2}[.\-\/월 ]\s?\d{1,2}일?\b/g},
   787	  {type:'address',re:/(서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충청?[북남]|전라?[북남]|경상?[북남]|제주)[^\n,()]{0,20}?(시|군|구)\s?[^\n,()]{0,25}?(로|길|대로)\s?\d+[^\n,()]{0,20}/g},
   788	  {type:'url',    re:/https?:\/\/[^\s)>\]]+|(?:instagram|facebook|linkedin|twitter|x)\.com\/[^\s)>\]]+/g},
   789	];
   790	/* International phone detection. Regex + digit-count validation per shape.
   791	   Covers +country-code (any), KR/JP/ID/BR/US/ES/MX domestic & grouped forms.
   792	   Digit-count gates keep false positives (IDs, dates, accounts) out. */
   793	const RRN_LIKE=/\d{6}[-‐ ]?[1-4]\d{6}/;
   794	function phoneScan(text){
   795	  const out=[], seen=new Set();
   796	  const add=(raw,min,max)=>{
   797	    let v=raw.trim().replace(/[.\s,;:]+$/,'').replace(/^[.\s,;:]+/,'');
   798	    const d=v.replace(/\D/g,'');
   799	    if(d.length<min||d.length>max) return;
   800	    if(RRN_LIKE.test(v)) return;                 // Korean RRN, not a phone
   801	    if(/^0+$/.test(d)||/^(\d)\1+$/.test(d)) return; // all-same digits
   802	    if(seen.has(d)) return; seen.add(d);
   803	    out.push({type:'phone',value:v});
   804	  };
   805	  let m,re;
   806	  // 1) international, starts with + and country code
   807	  re=/\+\d[\d\s().\-]{5,17}\d/g;
   808	  while((m=re.exec(text))) add(m[0],8,15);
   809	  // 2) parenthesised area code, e.g. Brazil (11) 91234-5678, (415) 555-2671
   810	  re=/\(\d{2,4}\)[\s.\-]?\d{3,5}[\s.\-]?\d{3,4}/g;
   811	  while((m=re.exec(text))) add(m[0],9,12);
   812	  // 3) domestic trunk starting with 0 (KR 010/02, JP 090, ID 0812 …)
   813	  re=/\b0\d{1,3}[\s.\-]?\d{3,4}[\s.\-]?\d{3,4}(?:[\s.\-]?\d{2,4})?(?!\d)/g;
   814	  while((m=re.exec(text))) add(m[0],9,13);
   815	  // 4) grouped 3-3/4-4 without +, e.g. US 415-555-2671, 415.555.2671
   816	  re=/\b\d{3}[\s.\-]\d{3,4}[\s.\-]\d{4}(?!\d)/g;
   817	  while((m=re.exec(text))) add(m[0],10,11);
   818	  return out;
   819	}
   820	function regexScan(text){
   821	  const found=phoneScan(text);            // phones first so numeric dedup below defers to them
   822	  for(const rule of REGEX_RULES){
   823	    let m; const re=new RegExp(rule.re.source,rule.re.flags);
   824	    while((m=re.exec(text))!==null){
   825	      const v=m[0].trim();
   826	      if(rule.type==='birth' && found.some(f=>f.type==='rrn'&&f.value.includes(v))) continue;
   827	      if((rule.type==='account'||rule.type==='ip') && found.some(f=>f.value.includes(v)||v.includes(f.value))) continue;
   828	      found.push({type:rule.type,value:v});
   829	    }
   830	  }
   831	  return found;
   832	}
   833	/* Address detection in 3 tiers (mirrors the name-candidate approach):
   834	   (1) confirmed  — a number (street/postal) → auto-masked as before
   835	   (2) candidate  — place/city with a country or address keyword, NOT combined
   836	                    with an institution/org → visible "review" item, not masked
   837	   (3) excluded   — institution/org names, lone tokens, country-only, prose */
   838	const INSTITUTION_RE=/\b(univ|university|college|institute|institution|school|academy|polytechnic|faculty|department|hospital|clinic|seminary)\b|대학교|대학원|대학|고등학교|중학교|초등학교|학원|학교|병원|연구소|大学|大學|高校|高等学校|学院|学校|universidad|colegio|instituto|escuela|facultad|academia/i;
   839	const ORG_RE=/\b(foundation|trust|ngo|organi[sz]ation|association|federation|council|ministry|bank|ltd|inc|corp|pvt|company|technolog|solutions?|systems?|services?|labs?|studios?|agency|enterprises?)\b|재단|협회|공사|공단|주식회사|株式会社|財団|協会/i;
   840	const COUNTRY_RE=/\b(india|indonesia|korea|japan|brazil|brasil|spain|espa[nñ]a|mexico|m[eé]xico|usa|u\.s\.a\.?|united states|u\.k\.?|united kingdom|england|canada|australia|singapore|philippines|vietnam|thailand|malaysia|germany|france|italy|netherlands|nepal|bangladesh|pakistan|sri lanka|china|taiwan|uae|dubai|qatar)\b/i;
   841	const ADDR_KEYWORD_RE=/\b(road|rd|street|st|avenue|ave|lane|ln|nagar|sector|colony|society|apartment|apartments|apt|flat|block|marg|enclave|vihar|puram|layout|phase|cross|extension|residency|towers?|heights?|villa|plot|gali|chowk|mohalla|bagh|ganj)\b|[가-힣]{2,}(로|길|동|읍|면|리)\b|丁目|区|市/i;
   842	const isOrgName=v=>INSTITUTION_RE.test(v)||ORG_RE.test(v);
   843	// Country names and nationality adjectives are NEVER personal info — a lone
   844	// "Korea"/"India"/"Indian" must be excluded outright (not masked, not a
   845	// candidate), no matter which path (regex, candidate, or AI) proposes it.
   846	const COUNTRY_ADJ_RE=/^(korean|indian|japanese|chinese|american|british|english|spanish|mexican|brazilian|canadian|australian|french|german|italian|dutch|nepali|nepalese|bangladeshi|pakistani|filipino|filipina|vietnamese|thai|malaysian|singaporean|taiwanese|emirati|qatari|russian|swiss|swedish|norwegian|danish|finnish|polish|turkish|greek|portuguese|indonesian)$/i;
   847	const DIRWORD_RE=/^(south|north|east|west|republic|of|the)$/i;
   848	function isCountryOrAdj(v){
   849	  const raw=(v||'').trim();
   850	  if(!raw) return false;
   851	  // Strip a parenthetical suffix (award/title) BEFORE the country test, then
   852	  // trim stray edge punctuation. This keeps the country "anchor" judgment
   853	  // identical whether a line stands alone ("Korea") or has merged with an
   854	  // adjacent parenthetical ("Korea (Koreaz Contest)") — both are anchored on
   855	  // the country and must be dropped, not proposed as an address.
   856	  const core=raw.replace(/\([^)]*\)/g,' ').replace(/\s+/g,' ').trim();
   857	  const t=core.replace(/^[.,()'"’]+|[.,()'"’]+$/g,'').trim();
   858	  if(!t) return false;
   859	  if(COUNTRY_ADJ_RE.test(t)) return true;                 // "Indian"
   860	  const words=t.split(/\s+/).filter(Boolean);
   861	  // A phrase built ONLY of direction/filler words + a country name is a country
   862	  // anchor, never PII — the `words.every` guard keeps this tight (a single non
   863	  // dir/country token disqualifies it). The length cap is 4 (not 2) so a wrapped
   864	  // official name whose tail line reads "Republic of Korea (Koreaz Contest)"
   865	  // — the real-résumé merged-line trap — is still dropped, not proposed as an
   866	  // address candidate. "of the republic of korea" = 4 words, still all dir+country.
   867	  if(words.length && words.length<=4 && COUNTRY_RE.test(t) && !/\d/.test(t) && !isOrgName(t)
   868	     && words.every(w=>{const c=w.replace(/[.,]/g,''); return DIRWORD_RE.test(c)||COUNTRY_RE.test(c);}))
   869	    return true;                                           // "Korea", "South Korea", "Republic of Korea (…)"
   870	  return false;
   871	}
   872	function classifyAddress(v){
   873	  if(/\d/.test(v)) return 'address';        // (1) number → confirmed, auto-mask
   874	  if(isOrgName(v)) return 'company';         // (3) org/institution → visible, not address
   875	  if(isCountryOrAdj(v)) return 'drop';       // (3) lone country/nationality → not PII
   876	  const words=v.trim().split(/\s+/);
   877	  if(words.length<=1) return 'drop';         // (3) lone place token (e.g. "Imphal")
   878	  if(COUNTRY_RE.test(v)||ADDR_KEYWORD_RE.test(v)) return 'candidate'; // (2)
   879	  return 'drop';                             // (3) no address signal
   880	}
   881	/* Name heuristic: the largest text near the top of page 1 is likely the
   882	   person's name. Conservative — skips doc titles, only fires when clear font
   883	   variation exists (so plain text docs never produce a candidate). */
   884	const DOC_TITLE_RE=/^(resume|r[eé]sum[eé]|cv|curriculum\s*vitae|curriculum|bio\s*data|biodata|profile|portfolio|자기?소개서|이력서|履歴書|職務経歴書|hoja\s*de\s*vida)$/i;
   885	const NON_NAME_RE=/증명서|명세서|계약서|신청서|경력|재직|이력|자기소개|졸업|성적|证明|証明|明細|履歴|resume|résumé|profile|curriculum|contract|certificate|statement|invoice/i;
   886	function isLikelyName(text){
   887	  if(!text||text.length<2||text.length>40) return false;
   888	  if(/[\d@]|https?:|www\./i.test(text)) return false;
   889	  if(DOC_TITLE_RE.test(text.trim())||NON_NAME_RE.test(text)) return false;
   890	  if(isOrgName(text)||isCountryOrAdj(text)) return false;  // schools/orgs/countries are not names

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: 
hook: PostToolUse
hook: PostToolUse Completed
codex
검토 기준일은 2026-10-21이다. 전략서·카탈로그·현재 탐지 코드를 대조했고, 변동 가능성이 있는 사실은 공식 자료를 우선 확인했다.

## 1. 사실 오류·과장

### 1-1. タイムズカー 유출 날짜와 범위

- 문제 / “2026-09-25 발각, 면허증·학생증·주민표 이미지 약 160만 건”은 날짜와 자료 유형을 섞었다.
- 근거 / 9월 25일은 부정 접근 탐지 및 제1보 공표일이다. 약 660만 계정 취득 확인은 9월 28일 제2보, 약 160만 계정의 본인확인서류 유출 확인은 9월 29일 제3보다. 160만 건에 포함된 공식 열거는 `運転免許証画像`, 공공요금 청구서 등 `現住所確認書類画像`, `学生証画像`, `家族確認書類画像`이며 `住民票`를 특정하지 않는다. [제2보](https://share.timescar.jp/news/2026/0928/1815.html), [제3보](https://share.timescar.jp/news/2026/0929/1816.html)
- 수정안 / “2026-09-25 부정 접근 탐지·제1보, 9월 28일 약 660만 계정 취득 확인, 9월 29일 그중 약 160만 계정에서 본인확인서류 이미지 유출 확인”으로 분리한다. `住民票`는 삭제하고 `現住所確認書類（公共料金請求書等）`로 바꾼다.

### 1-2. 집단소송 1만 5천 명

- 문제 / “10/2 기준 1만 5천 명”은 신뢰할 수 있는 원문 근거를 확인하지 못했다.
- 근거 / 변호사 사이트는 등록 인원 숫자를 현재 공개하지 않고, 등록은 소송 참가 확정이나 위임계약 체결이 아니라 “参加意思の表明”이라고 명시한다. 전략서가 든 共同通信 원문도 확인되지 않았다. [집단소송 사이트](https://timescar-lawsuit.com/)
- 수정안 / “집단소송 참가 등록 모집 중”까지만 쓰고 숫자는 `확인 불가`로 표시한다. 등록자·위임계약자·실제 원고를 구분한다.

### 1-3. 告知要求制限

- 문제 / 시행일은 맞지만 “保険証·資格確認書 제출 시 법적 의무 마스킹”이라는 보편 명제가 틀렸다.
- 근거 / 2020-10-01 시행 대상은 `保険者番号` 및 `被保険者等記号・番号`의 고지 요구다. 보험자·의료기관 및 의료보험 관련 사무처럼 법정 예외가 있다. QR도 해당 번호를 읽을 수 있는 경우에 한해 동일 취급한다. 厚生労働省 설명은 `枝番`을 별도 법정 범주로 열거하지 않지만, `番号`에 결합된 개인식별용 번호로 실무 마스킹하는 것이 안전하다. [厚生労働省](https://www.mhlw.go.jp/stf/newpage_13989.html)
- 수정안 / “의료보험 업무 외의 본인확인 등에서 원칙적으로 요구 제한. 사본을 받는 경우 대상 번호와 이를 담은 QR을 복원 불가능하게 마스킹. 법정 예외 있음”으로 쓴다. `性別`은 이 법의 의무 항목에서 제외한다.

### 1-4. 資格確認書 필드

- 문제 / `資格確認書`에 `事業所名称`, `保険者所在地`, `二次元コード`, `通院歴`가 보편적으로 존재한다고 전제했다.
- 근거 / 양식은 보험자별 차이가 있다. `通院歴`는 資格確認書의 통상적인 권면 항목이 아니다. 카탈로그의 `keep_for_kyc`에는 필드 목록에 없는 `住所`도 들어 있다. 공식 예시는 `記号／番号（枝番）`, 보험자 정보 등을 보여주지만 모든 발급자가 동일한 QR·사업소 필드를 쓰는 것은 확인되지 않는다. [厚生労働省 예시](https://www.mhlw.go.jp/content/12401000/001323480.pdf)
- 수정안 / 구 `健康保険証`과 `資格確認書`를 별도 문서 유형으로 분리하고, 필드를 `required/common/issuer_specific`으로 나눈다. `通院歴`는 삭제한다.

### 1-5. マイナンバーカード 裏面

- 문제 / “裏面 제출 금지”는 지나치게 절대적이다. 또한 카탈로그는 뒷면에 `生年月日`, `臓器提供意思`가 있다고 잘못 기재했다.
- 근거 / 일반 신분확인 목적으로 뒷면 개인번호를 복사·수집하면 번호법상 수집·보관 제한 위반 가능성이 있다. 그러나 세무·사회보장 등 적법한 個人番号関係事務에서는 뒷면 제출이 필요할 수 있다. `臓器提供意思表示欄`은 앞면 하단이며, 뒷면의 핵심은 個人番号·氏名·QR 등이다. [個人情報保護委員会 FAQ](https://www.ppc.go.jp/all_faq_index/faq5-q6-12/), [QR 주의 안내](https://www.ppc.go.jp/news/careful_information/qrcode/)
- 수정안 / “일반 신분확인에는 앞면만, 번호법상 허용된 목적일 때만 뒷면 제출”로 바꾼다. 업로드를 전면 차단하지 말고 목적 선택 → 경고 → 기본 전체 가림 → 적법한 개인번호 제출 모드만 명시적으로 해제하도록 한다.

### 1-6. 2027년 4월 IC칩 본인확인

- 문제 / “2027년 4월부터 IC칩 의무화, 그때까지 이미지만으로 계좌 개설 가능”은 적용 범위를 과도하게 단순화했다.
- 근거 / 2027-04-01 시행 예정 개편은 犯収法상의 대면·비대면 확인 방법별 변경이다. 비대면의 얼굴+신분증 이미지 방식 등은 폐지되지만, 우편 결합 방식·비거주 외국인 방식 등 존치·예외가 있다. 모든 웹서비스의 본인확인이나 모든 계좌개설에 일률적으로 적용되는 규칙이 아니다. [警察庁 JAFIC 연차보고서](https://www.npa.go.jp/sosikihanzai/jafic/nenzihokoku/data/jafic_2025.pdf)
- 수정안 / “犯収法 적용 특정사업자의 일부 이미지 기반 본인확인 방식이 2027-04-01 개편·폐지된다”로 한정한다. “구멍” 표현은 삭제한다.

---

## 2. jp01~jp13 카탈로그

### 2-1. 공통 구조

- 문제 / `always/optional/keep_for_kyc`가 제출 목적과 수령기관을 무시한 단일 규칙이다. `always`로 가린 항목이 실제 제출 목적의 필수 증빙일 수 있다.
- 근거 / 通帳의 口座番号, 残高証明의 残高, 在職証明의 社員番号, 賃貸借契約書의 당사자·印影 등은 제출 목적에 따라 반드시 남겨야 한다. 반대로 KYC에서는 임의 마스킹 시 접수가 거부될 수 있다. 카탈로그 출처도 `一般慣行`, 블로그, 상담 사례가 많아 `always`를 정당화하지 못한다.
- 수정안 / `always`를 폐지하고 `mask_when_purpose`, `must_keep_when_purpose`, `recipient_instruction_overrides`, `legal_basis`, `source_url`, `verified_at`으로 재설계한다.

### 2-2. jp01 運転免許証

- 문제 / `本籍変更履歴`를 뒷면의 일반 인쇄 필드처럼 취급했고, `本籍`을 optional 필드로 넣었다. 면허 종류별 최초 취득일도 빠졌다.
- 근거 / 현행 카드에서 本籍은 기본적으로 권면이 아니라 IC칩 정보다. 뒷면 備考欄에는 주소·성명 등의 변경사항이 기재될 수 있지만 이를 `本籍変更履歴`로 고정할 수 없다. IC칩에서 本籍을 읽을 수 있다는 경찰 안내는 확인된다. [神奈川県警察](https://www.police.pref.kanagawa.jp/tetsuzuki/menkyo/mes83080.html)
- 수정안 / `裏面:備考欄（住所・氏名等の変更記載）`로 바꾸고 `本籍`은 권면 필드에서 제거한다. `二・小・原`, `他` 등 취득일 필드를 추가한다.

### 2-3. jp02 マイナンバーカード

- 문제 / 뒷면 필드 위치가 틀렸고, “裏面全体 항상 금지”가 적법한 번호 제출 업무를 막는다.
- 근거 / 앞 절의 PPC 자료. `裏面:生年月日`, `裏面:臓器提供意思`는 잘못된 위치다.
- 수정안 / 앞면과 뒷면 스키마를 재작성하고, `identity_only`와 `my_number_procedure` 두 제출 목적을 분리한다.

### 2-4. jp03 健康保険証 / 資格確認書

- 문제 / 서로 다른 구·신 문서를 합쳤고, 2026년 현재 구 보험증을 주력 문서처럼 유지한다.
- 근거 / 기존 健康保険証의 유효기간은 원칙적으로 2025-12-01 종료했고, 잠정 대응도 2026-07-31 종료됐다. [厚生労働省](https://www.mhlw.go.jp/stf/newpage_50657.html)
- 수정안 / `資格確認書`를 주 문서로 올리고, 구 보험증은 `legacy_fixture`로 격리한다. 보험자별 변형을 테스트한다.

### 2-5. jp04 住民票の写し

- 문제 / 일본인 기준 필드만 있고 외국인 주민의 `国籍・地域`, `在留資格`, `在留期間`, `在留カード番号` 등의 선택기재 항목이 빠졌다. `世帯員` 전체를 문서 기본 필드처럼 전제했다.
- 근거 / 발급 종류가 `世帯全員/世帯一部`, 기재사항 선택에 따라 달라진다.
- 수정안 / `世帯全員/一部`, `個人番号あり/なし`, `本籍あり/なし`, 외국인 주민 변형을 별도 fixture로 만든다.

### 2-6. jp05 在留カード

- 문제 / 앞·뒷면을 합쳐 놓고 `always`가 비어 있다. `交付年月日`, `有効期間満了日`, `許可の種類`, 뒷면 신청·허가 관련 란이 빠졌다.
- 근거 / 현재 출처가 민간 KYC 업체 한 곳뿐이어서 완전성을 담보하지 못한다.
- 수정안 / 出入国在留管理庁의 권면 견본을 1차 출처로 추가하고 앞·뒷면 필드를 분리한다. 제출처가 요구하는 뒷면까지 임의로 가리지 않도록 한다.

### 2-7. jp06 パスポート

- 문제 / `旅券番号`와 MRZ를 optional로 가리면서 어떤 제출 목적에도 필요한지 구분하지 않는다. 소지인 자서 등 세대별 권면 차이도 빠졌다.
- 근거 / KYC에서는 번호와 MRZ가 핵심 검증 데이터일 수 있다. 현재 출처는 민간 비교기사뿐이다.
- 수정안 / 2025년 여권을 포함한 발급 세대별 fixture와 `KYC/상담용 공유` 규칙을 분리한다. 외무성 공식 견본 확인 전에는 필드 완결성을 `확인 불가`로 표시한다.

### 2-8. jp07 源泉徴収票

- 문제 / 수급자 교부용 源泉徴収票에 個人番号가 항상 표시되는 것처럼 설계했다.
- 근거 / 제출처·교부본에 따라 개인번호 기재 여부가 달라진다. `always: 個人番号`는 번호가 존재할 때의 규칙이어야 한다.
- 수정안 / `税務署提出用/受給者交付用`을 분리하고 `if_present` 규칙으로 바꾼다.

### 2-9. jp08 履歴書

- 문제 / `履歴書(JIS規格)`라는 명칭이 현행 표준처럼 보이며 성별·배우자·부양가족을 정상 필드로 유지한다.
- 근거 / 전략서 출처가 `JIS Z 8303 様式慣行`뿐이며 현행 공식 채용양식의 필수성을 입증하지 못한다. 현행 JIS 규격 여부와 필수 필드는 `확인 불가`.
- 수정안 / `履歴書（厚生労働省様式例／民間様式）`로 바꾸고, 성별·배우자·부양가족은 legacy fixture로 격리한다.

### 2-10. jp09~jp13

- 문제 / 서로 성격이 다른 문서를 과도하게 합쳤다.
- 근거 /
  - jp09는 `mask_norm.always`조차 없어 스키마가 불일치한다.
  - jp10의 給与明細와 標準報酬決定通知書는 발행자·필드·사용 목적이 다르다.
  - jp11의 “第三者情報·印影·振込口座 항상 가림”은 계약 검토 목적에 따라 틀릴 수 있다.
  - jp12의 口座番号·残高를 항상 가리면 계좌·잔액 증명이라는 문서 목적을 파괴한다.
  - jp13은 在職証明書·卒業証明書·成績証明書·学生証 네 종류를 한 스키마로 뭉쳤다. 学籍番号·社員番号의 의무 마스킹 근거도 없다.
- 수정안 / jp10, jp12, jp13을 각각 독립 문서로 쪼갠다. `always`는 법령 또는 제출기관의 공식 지침이 있을 때만 허용한다.

### 2-11. 빠진 문서

- 문제 / 고빈도·고민감 문서가 빠졌다.
- 근거 / 현재 13개는 취업·KYC 위주이고 행정·복지·세금·상속 흐름을 거의 다루지 않는다.
- 수정안 / 최소 다음을 추가한다.

  - `基礎年金番号通知書` 및 legacy `年金手帳`—2022년 이후 신규 年金手帳 발급이 끝났으므로 별도 세대 처리
  - `印鑑登録証明書`
  - `課税証明書・所得証明書・納税証明書`
  - `障害者手帳`—장애 종류·등급 등 고위험 민감정보
  - `戸籍謄本・戸籍抄本`
  - `介護保険被保険者証`
  - `母子健康手帳`
  - `健康診断書・診断書`
  - `雇用保険被保険者証`
  - `離職票`
  - `住民税決定通知書`

---

## 3. pii_patterns 및 실제 코드

### 3-1. 카탈로그 패턴이 실제 제품에 없다

- 문제 / 카탈로그를 “정본”이라고 했지만 실제 서비스는 이를 사용하지 않는다.
- 근거 / [카탈로그](/Users/sunghoon/Projects/docpack/docs/jp/jp_documents_catalog.json:4)에는 일본 패턴이 있으나, [index.html](/Users/sunghoon/Projects/docpack/public/safe/index.html:776)은 한국 주민번호·한국 면허번호·한국 주소와 범용 전화번호 중심이다. 일본어 선택 시 달라지는 것은 주로 `jpn+eng` OCR 언어다.
- 수정안 / S1 완료 표시를 취소한다. 카탈로그 규칙을 실제 실행 가능한 테스트 코드로 옮기고, 전각·OCR 변형 fixture와 precision/recall 기준을 먼저 만든다.

### 3-2. マイナンバー

- 문제 / `\d{4}...\d{4}...\d{4}`는 경계·레이블 없이 임의의 12자리 숫자를 잡고 전각 숫자를 놓친다. 체크디지트는 메타데이터에만 있고 regex가 검증하지 않는다.
- 근거 / 계좌·고객번호·OCR로 붙은 날짜 등에서 오탐 가능. `１２３４...`는 미탐한다.
- 수정안 / NFKC 정규화 후 숫자 경계, 주변 레이블/문서 프리셋, 별도 체크디지트 함수의 3단계를 적용한다. 체크디지트 불일치는 자동 마스킹이 아니라 검토 후보로 둔다.

### 3-3. 記号・番号・枝番

- 문제 / 1~8자리 가정이 좁고, `.*?`가 관계없는 `番号`까지 연결할 수 있다. 줄바꿈에는 기본적으로 매칭되지 않는다. 전각·OCR 공백·콜론·괄호 변형도 불충분하다.
- 근거 / `番号`는 거의 모든 공문서에 등장하는 저특이도 앵커다. 현재 운전면허 패턴도 `番号`만으로 12자리 수를 잡아 보험·접수번호와 충돌한다.
- 수정안 / 문서분류 또는 같은 시각 행/근접 박스 조건을 요구한다. `被保険者`, `保険者番号`, `記号`, `枝番` 조합 점수제로 처리하고 정규식 단독 자동 마스킹을 금지한다.

### 3-4. 電話

- 문제 / 카탈로그 regex는 `0800`, 괄호 표기, 전각 숫자·전각 하이픈을 놓치고, 하이픈 없는 번호는 다른 긴 숫자와 충돌한다. 실제 코드 역시 전각 숫자를 처리하지 않는다.
- 근거 / 실제 코드는 숫자 길이만 검증하고 일본 유효 국번 체계를 확인하지 않는다. [index.html](/Users/sunghoon/Projects/docpack/public/safe/index.html:790)
- 수정안 / NFKC 후 `TEL/電話/連絡先/携帯/FAX` 앵커와 일본 번호계획 기반 파서를 결합한다. FAX를 별도 유형으로 두고, 하이픈 없는 값은 저신뢰 후보로 낮춘다.

### 3-5. 住所

- 문제 / 현 regex는 도도부현과 숫자형 番地를 모두 요구해 `港区芝公園…`, `京都市…`, `○○郡△△町…`, `大字・字`, 무번지 주소를 놓친다. 반대로 `.{2,3}県`과 긴 `.*?` 구간은 문장을 과다 포획한다.
- 근거 / 漢数字도 `一~十`뿐이어서 `百`, `千`, `廿`, `番`, `番地`, `号`, `の` 등의 변형이 불완전하다. 실제 코드의 주소 판단은 “숫자 포함이면 주소”라 일본 기관명이나 날짜가 섞인 문자열을 오탐할 수 있다. [index.html](/Users/sunghoon/Projects/docpack/public/safe/index.html:872)
- 수정안 / 우편번호→都道府県→市区町村→町域→丁目番地→건물명 계층 파서를 사용한다. 일본 우편주소 사전은 후보 생성에만 쓰고 기관명 사전은 자동 제외가 아니라 신뢰도 감점에 쓴다.

### 3-6. 전각·漢数字와 OCR

- 문제 / “전각/반각 정규화”가 요구사항에만 있고 구현 순서·좌표 복원이 없다.
- 근거 / OCR 텍스트를 NFKC로 바꾸면 원문 인덱스 길이가 달라질 수 있어 마스킹 박스가 어긋난다. `髙/高`, `﨑/崎`, `ー/−/―`, `〇/○/0`, `一/1` 혼동도 미처리다.
- 수정안 / 원문↔정규화 문자열의 문자 위치 매핑을 보존한다. NFKC, 이체자, OCR 혼동치환은 단계별 후보로 적용하고, 원본 좌표 박스에 역매핑하는 테스트를 추가한다.

---

## 4. 타깃과 유료화

### 4-1. “25–39 転職・引越し・副業”

- 문제 / 세 개의 생활사건을 동시에 겪는 연령 집단으로 묶어 시장을 과도하게 좁혔다. “제출 빈도 최다”, “피해자 다수”는 근거가 없다.
- 근거 / 인터뷰에 27세·34세가 등장한다는 사실은 피해자 연령 분포를 증명하지 않는다. 転職 과정에서는 오히려 마스킹한 履歴書가 정상 지원을 방해할 수 있다. 정량 근거는 `확인 불가`.
- 수정안 / 연령 대신 검색 의도와 제출 목적별로 분리한다: `保険証・資格確認書の本人確認提出`, `相談용 계약서 익명화`, `입찰 첨부`, `SNS·AI 업로드 전 익명화`. 최초 시장은 법적 요구가 명확한 보험번호 마스킹과 전문가 상담용 공유가 적합하다.

### 4-2. “マスキング済み書類ボックス” 월 300~500엔

- 문제 / “원본을 저장하지 않으므로 개인정보처리방침과 무충돌”은 명백히 틀렸다.
- 근거 / 마스킹 사본에도 성명·얼굴·주소·계약내용 등이 남는다. 서버 저장은 개인정보 취급, 보안조치, 보존기간, 삭제, 침해대응, 위탁·국외이전 설명을 새로 발생시킨다. 타임즈카 사건을 마케팅하면서 신분서류 보관 상품을 파는 것은 메시지 자체도 충돌한다.
- 수정안 / 초기는 로컬 PWA 보관, 암호화 ZIP, 사용자 소유 클라우드로 내보내기를 우선한다. 서버 보관은 수요 검증 후 zero-knowledge 암호화·자동 만료·기기키·복구정책을 갖추고 별도 동의를 받는다. 가격은 콘텐츠 반응이 아니라 결제 의향·재사용 빈도·CAC 테스트로 검증한다.

---

## 5. 더미 카드 법적·안전 리스크

### 5-1. 동일 레이아웃과 유효 번호

- 문제 / 실제 레이아웃을 유지하면서 “체크디지트가 맞는 번호”를 생성하는 것은 `見本`과 문양 생략만으로 충분히 안전하지 않다.
- 근거 / 일본의 공문서 위조 책임은 실제 발급기관 명의처럼 보이는 외관, 행사 목적 등 구체적 사정에 좌우된다. 교육용 이미지가 자동으로 범죄라는 근거는 없으므로 그 결론은 `확인 불가`다. 다만 실물 유사 면허증을 제작·행사한 사례는 有印公文書偽造로 처벌된다. 또한 マイナンバー 로고는 별도 사용규정·신청 대상이다. [관련 판례](https://www.courts.go.jp/assets/hanrei/hanrei-pdf-20493.pdf), [デジタル庁 로고 규정](https://www.digital.go.jp/policies/mynumber_logo)
- 수정안 / 법률검토 전에는 실물과 동일한 카드 제작을 중단한다. 다음 조건을 모두 적용한다.

  - 실제 종횡비·색·서체·구획을 동시에 복제하지 않는다.
  - 앞·뒤 중앙에 삭제 불가능한 대형 `見本／架空／本人確認に使用不可` 표시를 넣는다.
  - 公安委員会名, 市区町村長名, 관인·공인·로고를 사용하지 않는다.
  - QR·바코드·IC 표시·유효 체크디지트를 만들지 않는다.
  - 번호는 명백히 규격 외 문자나 잘못된 체크디지트를 사용한다.
  - 실존 주소·실존 가능성이 있는 인물 조합을 쓰지 않는다.
  - 고해상도 개별 카드 파일을 공개 배포하지 않고 전체 문서 안의 축소 삽화로 제한한다.
  - 제작 전 일본 변호사의 公文書偽造·상표/저작권 검토를 받는다.

---

## 6. 채널과 콘텐츠 30편

### 6-1. X·Shorts·Reels 선정

- 문제 / 전체 이용률만으로 전환 채널을 정했고, `Instagram Reels`와 “카루셀”을 혼용했다. X는 사건 반응에는 유리하지만 민감정보 도구의 신뢰 형성·검색 전환을 보장하지 않는다.
- 근거 / 전략서의 ICT総研 수치는 연령별 도달률·클릭·검색의도·전환율을 제공하지 않는다. 원문도 이번 검토에서 확인되지 않아 `확인 불가`.
- 수정안 / Google/Yahoo 검색 SEO를 핵심 채널로 두고, YouTube 일반 검색형 영상+Shorts를 보조한다. X는 사건 해설과 공지, Instagram은 정지형 carousel과 Reels를 별도 제작한다. 2주간 채널별 랜딩 전환을 측정한 뒤 확대한다.

### 6-2. 법적으로 위험하거나 오도하는 제목

- 문제 / 다음 제목은 사실을 과장하거나 제출 실패를 유발한다.
- 근거 /
  - 1번 `660万件のあと私がしたこと`: 화자가 실제 피해자가 아니면 허위 체험담처럼 보인다.
  - 3번 `隠すべき3か所`: 제출처마다 유지 항목이 달라 고정 3곳이 없다.
  - 5번 `裏面は絶対に送らない`: 적법한 個人番号 제출 업무 예외를 부정한다.
  - 7·11·15·19·21·23번: 목적 확인 없이 번호·MRZ·금액·회사명을 가리면 반려될 수 있다.
  - 16번 `2027年4月まで続く穴`: 犯収法 개정을 과장한다.
  - 18번 `企業は「マスキングして送れ」と言う`: 모든 기업과 모든 문서에 일반화한다.
  - 20번 JICC/CIC 행동 안내: 피해 대응의 효과·적용 조건에 대한 검증이 없다.
  - 27번 `転用を防ぐ`: 워터마크는 억제책이지 방지를 보증하지 않는다.
  - 29번 일괄처리: 현재 구현·검증되지 않은 기능을 홍보한다.
  - 30번: 3일마다 30편이면 약 3개월인데 `2か月` 총괄이다.
- 수정안 / 모든 how-to 제목에 `提出先の指定を確認`을 넣고, “防ぐ/絶対/べき”를 “リスクを下げる/原則/確認する”로 낮춘다. 16번은 제도 해설로 재작성하고, 29번은 기능 출시 후로 연기한다.

### 6-3. タイムズカー 피해자 소재

- 문제 / 사고 직후 피해자의 불안을 전환 퍼널로 직접 이용하며, 1인칭 가상 피해담을 만들려 한다.
- 근거 / 전략서 자체 목적이 “현재 정서를 유입으로 전환”이라고 명시한다. 실제 피해자가 아닌 브랜드가 `私の免許証`, `会社は守ってくれなかった`를 쓰면 오인·반발 위험이 있다.
- 수정안 / 공식 발표 사실만 인용한 비개인적 설명으로 제한한다. 피해자 인터뷰·실패담은 명시적 동의와 사실검증 없이는 쓰지 않는다. 집단소송·재교부·신용정보 조치를 서비스 홍보 CTA와 같은 게시물에 섞지 않는다.

---

## 7. S1~S7 및 출시 게이트

### 7-1. 현재 실행 순서

- 문제 / S1을 완료 처리했지만 사실·필드·법적 분류가 확정되지 않았다. S2에서 40~50개 더미를 먼저 만들면 잘못된 스키마가 테스트 정답으로 굳어진다.
- 근거 / 위에서 확인한 jp01~jp13 오류와 실제 코드 미구현 상태. [전략서](/Users/sunghoon/Projects/docpack/docs/jp/jp_safefile_strategy_2026-10-20.md:154)
- 수정안 / 순서를 `법적 매트릭스 → 최소 4문서 fixture → 탐지/수동 편집 → 안전성 테스트 → 제한 베타 → 콘텐츠`로 바꾼다.

### 7-2. “S5 통과 전 홍보 금지”

- 문제 / 방향은 맞지만 S5의 “13종 중 12종 이상 1분 내 완료”는 개인정보 도구의 안전 게이트로 부적절하다. 한 문서 실패를 허용하며 미탐률·복원 가능성·오탐 훼손을 측정하지 않는다.
- 근거 / UI 완료시간은 보안성과 무관하다. 현재 “2px 패딩이면 透けない 보증 가능”도 OCR 박스가 글리프 바깥을 놓치는지, PDF 메타데이터·원본 첨부·EXIF가 남는지 검증하지 않았다.
- 수정안 / 공개 홍보 게이트를 다음으로 바꾼다.

  - 필수 민감항목 미탐 0건을 요구하는 문서별 골든 테스트
  - 원본 텍스트 레이어·주석·첨부·증분저장·EXIF 제거 검증
  - OCR 박스 외곽과 회전·왜곡·저해상도 사진 테스트
  - 다운로드 결과를 다른 PDF/이미지 도구로 재추출하는 공격 테스트
  - 지원하지 않는 문서는 자동 마스킹 금지 및 명확한 경고
  - 법적 문구 검수 완료

### 7-3. 2주 일정의 대안

- 문제 / 13종, 40~50 fixture, 일본어 OCR, 프리셋 6종, 워터마크, 실사이트 검증을 2주에 완성하는 것은 비현실적이다.
- 근거 / 주소·QR·카드 문서분류는 정규식 몇 개로 끝나지 않고 OCR 좌표·레이아웃 변형·법적 제출목적 테스트가 필요하다. 현재 코드는 일본 전용 탐지가 사실상 없다.
- 수정안 / 2주 안에는 범위를 축소한다.

  1. `資格確認書`, `住民票`, `マイナンバーカード`, `運転免許証` 네 종류만 알파 지원.
  2. 자동탐지는 `保険者番号・記号番号・個人番号`처럼 고신뢰 항목만 제공.
  3. 나머지는 수동 사각형 마스킹과 워터마크 중심.
  4. “자동으로 안전하게 가려준다”가 아니라 “로컬에서 직접 확인하며 가리는 도구”로 출시.
  5. 사건명 광고 대신 보험번호 마스킹 가이드와 제한 베타 모집만 시작.
  6. 4주 이상 실제 fixture를 모은 뒤 지원 문서를 순차 확대.

## 즉시 수정해야 할 상위 5개

1. `マイナンバーカード裏面は絶対提出禁止`, `2027年4月まで画像本人確認の穴` 등 잘못된 법률 표현과 콘텐츠 5·16번을 즉시 삭제한다.
2. `always/optional` 단일 분류를 폐지하고 제출 목적·수령기관별 규칙으로 바꾼다. 특히 jp10~jp13을 분리한다.
3. S1 “완료”와 S5의 “12/13 성공” 기준을 취소하고, 미탐 0·메타데이터 제거·복원 불가 검증을 출시 게이트로 지정한다.
4. 실물과 같은 免許証·マイナンバーカード 더미 및 유효 체크디지트 생성 계획을 중단하고, 명백히 비실물인 교육용 도식으로 교체한다.
5. 서버형 `マスキング済み書類ボックス`와 “개인정보처리방침과 무충돌” 문구를 철회한다. 초기 유료화는 로컬 저장·내보내기 기능으로 검증한다.
hook: Stop
hook: Stop Completed
tokens used
114,891
검토 기준일은 2026-10-21이다. 전략서·카탈로그·현재 탐지 코드를 대조했고, 변동 가능성이 있는 사실은 공식 자료를 우선 확인했다.

## 1. 사실 오류·과장

### 1-1. タイムズカー 유출 날짜와 범위

- 문제 / “2026-09-25 발각, 면허증·학생증·주민표 이미지 약 160만 건”은 날짜와 자료 유형을 섞었다.
- 근거 / 9월 25일은 부정 접근 탐지 및 제1보 공표일이다. 약 660만 계정 취득 확인은 9월 28일 제2보, 약 160만 계정의 본인확인서류 유출 확인은 9월 29일 제3보다. 160만 건에 포함된 공식 열거는 `運転免許証画像`, 공공요금 청구서 등 `現住所確認書類画像`, `学生証画像`, `家族確認書類画像`이며 `住民票`를 특정하지 않는다. [제2보](https://share.timescar.jp/news/2026/0928/1815.html), [제3보](https://share.timescar.jp/news/2026/0929/1816.html)
- 수정안 / “2026-09-25 부정 접근 탐지·제1보, 9월 28일 약 660만 계정 취득 확인, 9월 29일 그중 약 160만 계정에서 본인확인서류 이미지 유출 확인”으로 분리한다. `住民票`는 삭제하고 `現住所確認書類（公共料金請求書等）`로 바꾼다.

### 1-2. 집단소송 1만 5천 명

- 문제 / “10/2 기준 1만 5천 명”은 신뢰할 수 있는 원문 근거를 확인하지 못했다.
- 근거 / 변호사 사이트는 등록 인원 숫자를 현재 공개하지 않고, 등록은 소송 참가 확정이나 위임계약 체결이 아니라 “参加意思の表明”이라고 명시한다. 전략서가 든 共同通信 원문도 확인되지 않았다. [집단소송 사이트](https://timescar-lawsuit.com/)
- 수정안 / “집단소송 참가 등록 모집 중”까지만 쓰고 숫자는 `확인 불가`로 표시한다. 등록자·위임계약자·실제 원고를 구분한다.

### 1-3. 告知要求制限

- 문제 / 시행일은 맞지만 “保険証·資格確認書 제출 시 법적 의무 마스킹”이라는 보편 명제가 틀렸다.
- 근거 / 2020-10-01 시행 대상은 `保険者番号` 및 `被保険者等記号・番号`의 고지 요구다. 보험자·의료기관 및 의료보험 관련 사무처럼 법정 예외가 있다. QR도 해당 번호를 읽을 수 있는 경우에 한해 동일 취급한다. 厚生労働省 설명은 `枝番`을 별도 법정 범주로 열거하지 않지만, `番号`에 결합된 개인식별용 번호로 실무 마스킹하는 것이 안전하다. [厚生労働省](https://www.mhlw.go.jp/stf/newpage_13989.html)
- 수정안 / “의료보험 업무 외의 본인확인 등에서 원칙적으로 요구 제한. 사본을 받는 경우 대상 번호와 이를 담은 QR을 복원 불가능하게 마스킹. 법정 예외 있음”으로 쓴다. `性別`은 이 법의 의무 항목에서 제외한다.

### 1-4. 資格確認書 필드

- 문제 / `資格確認書`에 `事業所名称`, `保険者所在地`, `二次元コード`, `通院歴`가 보편적으로 존재한다고 전제했다.
- 근거 / 양식은 보험자별 차이가 있다. `通院歴`는 資格確認書의 통상적인 권면 항목이 아니다. 카탈로그의 `keep_for_kyc`에는 필드 목록에 없는 `住所`도 들어 있다. 공식 예시는 `記号／番号（枝番）`, 보험자 정보 등을 보여주지만 모든 발급자가 동일한 QR·사업소 필드를 쓰는 것은 확인되지 않는다. [厚生労働省 예시](https://www.mhlw.go.jp/content/12401000/001323480.pdf)
- 수정안 / 구 `健康保険証`과 `資格確認書`를 별도 문서 유형으로 분리하고, 필드를 `required/common/issuer_specific`으로 나눈다. `通院歴`는 삭제한다.

### 1-5. マイナンバーカード 裏面

- 문제 / “裏面 제출 금지”는 지나치게 절대적이다. 또한 카탈로그는 뒷면에 `生年月日`, `臓器提供意思`가 있다고 잘못 기재했다.
- 근거 / 일반 신분확인 목적으로 뒷면 개인번호를 복사·수집하면 번호법상 수집·보관 제한 위반 가능성이 있다. 그러나 세무·사회보장 등 적법한 個人番号関係事務에서는 뒷면 제출이 필요할 수 있다. `臓器提供意思表示欄`은 앞면 하단이며, 뒷면의 핵심은 個人番号·氏名·QR 등이다. [個人情報保護委員会 FAQ](https://www.ppc.go.jp/all_faq_index/faq5-q6-12/), [QR 주의 안내](https://www.ppc.go.jp/news/careful_information/qrcode/)
- 수정안 / “일반 신분확인에는 앞면만, 번호법상 허용된 목적일 때만 뒷면 제출”로 바꾼다. 업로드를 전면 차단하지 말고 목적 선택 → 경고 → 기본 전체 가림 → 적법한 개인번호 제출 모드만 명시적으로 해제하도록 한다.

### 1-6. 2027년 4월 IC칩 본인확인

- 문제 / “2027년 4월부터 IC칩 의무화, 그때까지 이미지만으로 계좌 개설 가능”은 적용 범위를 과도하게 단순화했다.
- 근거 / 2027-04-01 시행 예정 개편은 犯収法상의 대면·비대면 확인 방법별 변경이다. 비대면의 얼굴+신분증 이미지 방식 등은 폐지되지만, 우편 결합 방식·비거주 외국인 방식 등 존치·예외가 있다. 모든 웹서비스의 본인확인이나 모든 계좌개설에 일률적으로 적용되는 규칙이 아니다. [警察庁 JAFIC 연차보고서](https://www.npa.go.jp/sosikihanzai/jafic/nenzihokoku/data/jafic_2025.pdf)
- 수정안 / “犯収法 적용 특정사업자의 일부 이미지 기반 본인확인 방식이 2027-04-01 개편·폐지된다”로 한정한다. “구멍” 표현은 삭제한다.

---

## 2. jp01~jp13 카탈로그

### 2-1. 공통 구조

- 문제 / `always/optional/keep_for_kyc`가 제출 목적과 수령기관을 무시한 단일 규칙이다. `always`로 가린 항목이 실제 제출 목적의 필수 증빙일 수 있다.
- 근거 / 通帳의 口座番号, 残高証明의 残高, 在職証明의 社員番号, 賃貸借契約書의 당사자·印影 등은 제출 목적에 따라 반드시 남겨야 한다. 반대로 KYC에서는 임의 마스킹 시 접수가 거부될 수 있다. 카탈로그 출처도 `一般慣行`, 블로그, 상담 사례가 많아 `always`를 정당화하지 못한다.
- 수정안 / `always`를 폐지하고 `mask_when_purpose`, `must_keep_when_purpose`, `recipient_instruction_overrides`, `legal_basis`, `source_url`, `verified_at`으로 재설계한다.

### 2-2. jp01 運転免許証

- 문제 / `本籍変更履歴`를 뒷면의 일반 인쇄 필드처럼 취급했고, `本籍`을 optional 필드로 넣었다. 면허 종류별 최초 취득일도 빠졌다.
- 근거 / 현행 카드에서 本籍은 기본적으로 권면이 아니라 IC칩 정보다. 뒷면 備考欄에는 주소·성명 등의 변경사항이 기재될 수 있지만 이를 `本籍変更履歴`로 고정할 수 없다. IC칩에서 本籍을 읽을 수 있다는 경찰 안내는 확인된다. [神奈川県警察](https://www.police.pref.kanagawa.jp/tetsuzuki/menkyo/mes83080.html)
- 수정안 / `裏面:備考欄（住所・氏名等の変更記載）`로 바꾸고 `本籍`은 권면 필드에서 제거한다. `二・小・原`, `他` 등 취득일 필드를 추가한다.

### 2-3. jp02 マイナンバーカード

- 문제 / 뒷면 필드 위치가 틀렸고, “裏面全体 항상 금지”가 적법한 번호 제출 업무를 막는다.
- 근거 / 앞 절의 PPC 자료. `裏面:生年月日`, `裏面:臓器提供意思`는 잘못된 위치다.
- 수정안 / 앞면과 뒷면 스키마를 재작성하고, `identity_only`와 `my_number_procedure` 두 제출 목적을 분리한다.

### 2-4. jp03 健康保険証 / 資格確認書

- 문제 / 서로 다른 구·신 문서를 합쳤고, 2026년 현재 구 보험증을 주력 문서처럼 유지한다.
- 근거 / 기존 健康保険証의 유효기간은 원칙적으로 2025-12-01 종료했고, 잠정 대응도 2026-07-31 종료됐다. [厚生労働省](https://www.mhlw.go.jp/stf/newpage_50657.html)
- 수정안 / `資格確認書`를 주 문서로 올리고, 구 보험증은 `legacy_fixture`로 격리한다. 보험자별 변형을 테스트한다.

### 2-5. jp04 住民票の写し

- 문제 / 일본인 기준 필드만 있고 외국인 주민의 `国籍・地域`, `在留資格`, `在留期間`, `在留カード番号` 등의 선택기재 항목이 빠졌다. `世帯員` 전체를 문서 기본 필드처럼 전제했다.
- 근거 / 발급 종류가 `世帯全員/世帯一部`, 기재사항 선택에 따라 달라진다.
- 수정안 / `世帯全員/一部`, `個人番号あり/なし`, `本籍あり/なし`, 외국인 주민 변형을 별도 fixture로 만든다.

### 2-6. jp05 在留カード

- 문제 / 앞·뒷면을 합쳐 놓고 `always`가 비어 있다. `交付年月日`, `有効期間満了日`, `許可の種類`, 뒷면 신청·허가 관련 란이 빠졌다.
- 근거 / 현재 출처가 민간 KYC 업체 한 곳뿐이어서 완전성을 담보하지 못한다.
- 수정안 / 出入国在留管理庁의 권면 견본을 1차 출처로 추가하고 앞·뒷면 필드를 분리한다. 제출처가 요구하는 뒷면까지 임의로 가리지 않도록 한다.

### 2-7. jp06 パスポート

- 문제 / `旅券番号`와 MRZ를 optional로 가리면서 어떤 제출 목적에도 필요한지 구분하지 않는다. 소지인 자서 등 세대별 권면 차이도 빠졌다.
- 근거 / KYC에서는 번호와 MRZ가 핵심 검증 데이터일 수 있다. 현재 출처는 민간 비교기사뿐이다.
- 수정안 / 2025년 여권을 포함한 발급 세대별 fixture와 `KYC/상담용 공유` 규칙을 분리한다. 외무성 공식 견본 확인 전에는 필드 완결성을 `확인 불가`로 표시한다.

### 2-8. jp07 源泉徴収票

- 문제 / 수급자 교부용 源泉徴収票에 個人番号가 항상 표시되는 것처럼 설계했다.
- 근거 / 제출처·교부본에 따라 개인번호 기재 여부가 달라진다. `always: 個人番号`는 번호가 존재할 때의 규칙이어야 한다.
- 수정안 / `税務署提出用/受給者交付用`을 분리하고 `if_present` 규칙으로 바꾼다.

### 2-9. jp08 履歴書

- 문제 / `履歴書(JIS規格)`라는 명칭이 현행 표준처럼 보이며 성별·배우자·부양가족을 정상 필드로 유지한다.
- 근거 / 전략서 출처가 `JIS Z 8303 様式慣行`뿐이며 현행 공식 채용양식의 필수성을 입증하지 못한다. 현행 JIS 규격 여부와 필수 필드는 `확인 불가`.
- 수정안 / `履歴書（厚生労働省様式例／民間様式）`로 바꾸고, 성별·배우자·부양가족은 legacy fixture로 격리한다.

### 2-10. jp09~jp13

- 문제 / 서로 성격이 다른 문서를 과도하게 합쳤다.
- 근거 /
  - jp09는 `mask_norm.always`조차 없어 스키마가 불일치한다.
  - jp10의 給与明細와 標準報酬決定通知書는 발행자·필드·사용 목적이 다르다.
  - jp11의 “第三者情報·印影·振込口座 항상 가림”은 계약 검토 목적에 따라 틀릴 수 있다.
  - jp12의 口座番号·残高를 항상 가리면 계좌·잔액 증명이라는 문서 목적을 파괴한다.
  - jp13은 在職証明書·卒業証明書·成績証明書·学生証 네 종류를 한 스키마로 뭉쳤다. 学籍番号·社員番号의 의무 마스킹 근거도 없다.
- 수정안 / jp10, jp12, jp13을 각각 독립 문서로 쪼갠다. `always`는 법령 또는 제출기관의 공식 지침이 있을 때만 허용한다.

### 2-11. 빠진 문서

- 문제 / 고빈도·고민감 문서가 빠졌다.
- 근거 / 현재 13개는 취업·KYC 위주이고 행정·복지·세금·상속 흐름을 거의 다루지 않는다.
- 수정안 / 최소 다음을 추가한다.

  - `基礎年金番号通知書` 및 legacy `年金手帳`—2022년 이후 신규 年金手帳 발급이 끝났으므로 별도 세대 처리
  - `印鑑登録証明書`
  - `課税証明書・所得証明書・納税証明書`
  - `障害者手帳`—장애 종류·등급 등 고위험 민감정보
  - `戸籍謄本・戸籍抄本`
  - `介護保険被保険者証`
  - `母子健康手帳`
  - `健康診断書・診断書`
  - `雇用保険被保険者証`
  - `離職票`
  - `住民税決定通知書`

---

## 3. pii_patterns 및 실제 코드

### 3-1. 카탈로그 패턴이 실제 제품에 없다

- 문제 / 카탈로그를 “정본”이라고 했지만 실제 서비스는 이를 사용하지 않는다.
- 근거 / [카탈로그](/Users/sunghoon/Projects/docpack/docs/jp/jp_documents_catalog.json:4)에는 일본 패턴이 있으나, [index.html](/Users/sunghoon/Projects/docpack/public/safe/index.html:776)은 한국 주민번호·한국 면허번호·한국 주소와 범용 전화번호 중심이다. 일본어 선택 시 달라지는 것은 주로 `jpn+eng` OCR 언어다.
- 수정안 / S1 완료 표시를 취소한다. 카탈로그 규칙을 실제 실행 가능한 테스트 코드로 옮기고, 전각·OCR 변형 fixture와 precision/recall 기준을 먼저 만든다.

### 3-2. マイナンバー

- 문제 / `\d{4}...\d{4}...\d{4}`는 경계·레이블 없이 임의의 12자리 숫자를 잡고 전각 숫자를 놓친다. 체크디지트는 메타데이터에만 있고 regex가 검증하지 않는다.
- 근거 / 계좌·고객번호·OCR로 붙은 날짜 등에서 오탐 가능. `１２３４...`는 미탐한다.
- 수정안 / NFKC 정규화 후 숫자 경계, 주변 레이블/문서 프리셋, 별도 체크디지트 함수의 3단계를 적용한다. 체크디지트 불일치는 자동 마스킹이 아니라 검토 후보로 둔다.

### 3-3. 記号・番号・枝番

- 문제 / 1~8자리 가정이 좁고, `.*?`가 관계없는 `番号`까지 연결할 수 있다. 줄바꿈에는 기본적으로 매칭되지 않는다. 전각·OCR 공백·콜론·괄호 변형도 불충분하다.
- 근거 / `番号`는 거의 모든 공문서에 등장하는 저특이도 앵커다. 현재 운전면허 패턴도 `番号`만으로 12자리 수를 잡아 보험·접수번호와 충돌한다.
- 수정안 / 문서분류 또는 같은 시각 행/근접 박스 조건을 요구한다. `被保険者`, `保険者番号`, `記号`, `枝番` 조합 점수제로 처리하고 정규식 단독 자동 마스킹을 금지한다.

### 3-4. 電話

- 문제 / 카탈로그 regex는 `0800`, 괄호 표기, 전각 숫자·전각 하이픈을 놓치고, 하이픈 없는 번호는 다른 긴 숫자와 충돌한다. 실제 코드 역시 전각 숫자를 처리하지 않는다.
- 근거 / 실제 코드는 숫자 길이만 검증하고 일본 유효 국번 체계를 확인하지 않는다. [index.html](/Users/sunghoon/Projects/docpack/public/safe/index.html:790)
- 수정안 / NFKC 후 `TEL/電話/連絡先/携帯/FAX` 앵커와 일본 번호계획 기반 파서를 결합한다. FAX를 별도 유형으로 두고, 하이픈 없는 값은 저신뢰 후보로 낮춘다.

### 3-5. 住所

- 문제 / 현 regex는 도도부현과 숫자형 番地를 모두 요구해 `港区芝公園…`, `京都市…`, `○○郡△△町…`, `大字・字`, 무번지 주소를 놓친다. 반대로 `.{2,3}県`과 긴 `.*?` 구간은 문장을 과다 포획한다.
- 근거 / 漢数字도 `一~十`뿐이어서 `百`, `千`, `廿`, `番`, `番地`, `号`, `の` 등의 변형이 불완전하다. 실제 코드의 주소 판단은 “숫자 포함이면 주소”라 일본 기관명이나 날짜가 섞인 문자열을 오탐할 수 있다. [index.html](/Users/sunghoon/Projects/docpack/public/safe/index.html:872)
- 수정안 / 우편번호→都道府県→市区町村→町域→丁目番地→건물명 계층 파서를 사용한다. 일본 우편주소 사전은 후보 생성에만 쓰고 기관명 사전은 자동 제외가 아니라 신뢰도 감점에 쓴다.

### 3-6. 전각·漢数字와 OCR

- 문제 / “전각/반각 정규화”가 요구사항에만 있고 구현 순서·좌표 복원이 없다.
- 근거 / OCR 텍스트를 NFKC로 바꾸면 원문 인덱스 길이가 달라질 수 있어 마스킹 박스가 어긋난다. `髙/高`, `﨑/崎`, `ー/−/―`, `〇/○/0`, `一/1` 혼동도 미처리다.
- 수정안 / 원문↔정규화 문자열의 문자 위치 매핑을 보존한다. NFKC, 이체자, OCR 혼동치환은 단계별 후보로 적용하고, 원본 좌표 박스에 역매핑하는 테스트를 추가한다.

---

## 4. 타깃과 유료화

### 4-1. “25–39 転職・引越し・副業”

- 문제 / 세 개의 생활사건을 동시에 겪는 연령 집단으로 묶어 시장을 과도하게 좁혔다. “제출 빈도 최다”, “피해자 다수”는 근거가 없다.
- 근거 / 인터뷰에 27세·34세가 등장한다는 사실은 피해자 연령 분포를 증명하지 않는다. 転職 과정에서는 오히려 마스킹한 履歴書가 정상 지원을 방해할 수 있다. 정량 근거는 `확인 불가`.
- 수정안 / 연령 대신 검색 의도와 제출 목적별로 분리한다: `保険証・資格確認書の本人確認提出`, `相談용 계약서 익명화`, `입찰 첨부`, `SNS·AI 업로드 전 익명화`. 최초 시장은 법적 요구가 명확한 보험번호 마스킹과 전문가 상담용 공유가 적합하다.

### 4-2. “マスキング済み書類ボックス” 월 300~500엔

- 문제 / “원본을 저장하지 않으므로 개인정보처리방침과 무충돌”은 명백히 틀렸다.
- 근거 / 마스킹 사본에도 성명·얼굴·주소·계약내용 등이 남는다. 서버 저장은 개인정보 취급, 보안조치, 보존기간, 삭제, 침해대응, 위탁·국외이전 설명을 새로 발생시킨다. 타임즈카 사건을 마케팅하면서 신분서류 보관 상품을 파는 것은 메시지 자체도 충돌한다.
- 수정안 / 초기는 로컬 PWA 보관, 암호화 ZIP, 사용자 소유 클라우드로 내보내기를 우선한다. 서버 보관은 수요 검증 후 zero-knowledge 암호화·자동 만료·기기키·복구정책을 갖추고 별도 동의를 받는다. 가격은 콘텐츠 반응이 아니라 결제 의향·재사용 빈도·CAC 테스트로 검증한다.

---

## 5. 더미 카드 법적·안전 리스크

### 5-1. 동일 레이아웃과 유효 번호

- 문제 / 실제 레이아웃을 유지하면서 “체크디지트가 맞는 번호”를 생성하는 것은 `見本`과 문양 생략만으로 충분히 안전하지 않다.
- 근거 / 일본의 공문서 위조 책임은 실제 발급기관 명의처럼 보이는 외관, 행사 목적 등 구체적 사정에 좌우된다. 교육용 이미지가 자동으로 범죄라는 근거는 없으므로 그 결론은 `확인 불가`다. 다만 실물 유사 면허증을 제작·행사한 사례는 有印公文書偽造로 처벌된다. 또한 マイナンバー 로고는 별도 사용규정·신청 대상이다. [관련 판례](https://www.courts.go.jp/assets/hanrei/hanrei-pdf-20493.pdf), [デジタル庁 로고 규정](https://www.digital.go.jp/policies/mynumber_logo)
- 수정안 / 법률검토 전에는 실물과 동일한 카드 제작을 중단한다. 다음 조건을 모두 적용한다.

  - 실제 종횡비·색·서체·구획을 동시에 복제하지 않는다.
  - 앞·뒤 중앙에 삭제 불가능한 대형 `見本／架空／本人確認に使用不可` 표시를 넣는다.
  - 公安委員会名, 市区町村長名, 관인·공인·로고를 사용하지 않는다.
  - QR·바코드·IC 표시·유효 체크디지트를 만들지 않는다.
  - 번호는 명백히 규격 외 문자나 잘못된 체크디지트를 사용한다.
  - 실존 주소·실존 가능성이 있는 인물 조합을 쓰지 않는다.
  - 고해상도 개별 카드 파일을 공개 배포하지 않고 전체 문서 안의 축소 삽화로 제한한다.
  - 제작 전 일본 변호사의 公文書偽造·상표/저작권 검토를 받는다.

---

## 6. 채널과 콘텐츠 30편

### 6-1. X·Shorts·Reels 선정

- 문제 / 전체 이용률만으로 전환 채널을 정했고, `Instagram Reels`와 “카루셀”을 혼용했다. X는 사건 반응에는 유리하지만 민감정보 도구의 신뢰 형성·검색 전환을 보장하지 않는다.
- 근거 / 전략서의 ICT総研 수치는 연령별 도달률·클릭·검색의도·전환율을 제공하지 않는다. 원문도 이번 검토에서 확인되지 않아 `확인 불가`.
- 수정안 / Google/Yahoo 검색 SEO를 핵심 채널로 두고, YouTube 일반 검색형 영상+Shorts를 보조한다. X는 사건 해설과 공지, Instagram은 정지형 carousel과 Reels를 별도 제작한다. 2주간 채널별 랜딩 전환을 측정한 뒤 확대한다.

### 6-2. 법적으로 위험하거나 오도하는 제목

- 문제 / 다음 제목은 사실을 과장하거나 제출 실패를 유발한다.
- 근거 /
  - 1번 `660万件のあと私がしたこと`: 화자가 실제 피해자가 아니면 허위 체험담처럼 보인다.
  - 3번 `隠すべき3か所`: 제출처마다 유지 항목이 달라 고정 3곳이 없다.
  - 5번 `裏面は絶対に送らない`: 적법한 個人番号 제출 업무 예외를 부정한다.
  - 7·11·15·19·21·23번: 목적 확인 없이 번호·MRZ·금액·회사명을 가리면 반려될 수 있다.
  - 16번 `2027年4月まで続く穴`: 犯収法 개정을 과장한다.
  - 18번 `企業は「マスキングして送れ」と言う`: 모든 기업과 모든 문서에 일반화한다.
  - 20번 JICC/CIC 행동 안내: 피해 대응의 효과·적용 조건에 대한 검증이 없다.
  - 27번 `転用を防ぐ`: 워터마크는 억제책이지 방지를 보증하지 않는다.
  - 29번 일괄처리: 현재 구현·검증되지 않은 기능을 홍보한다.
  - 30번: 3일마다 30편이면 약 3개월인데 `2か月` 총괄이다.
- 수정안 / 모든 how-to 제목에 `提出先の指定を確認`을 넣고, “防ぐ/絶対/べき”를 “リスクを下げる/原則/確認する”로 낮춘다. 16번은 제도 해설로 재작성하고, 29번은 기능 출시 후로 연기한다.

### 6-3. タイムズカー 피해자 소재

- 문제 / 사고 직후 피해자의 불안을 전환 퍼널로 직접 이용하며, 1인칭 가상 피해담을 만들려 한다.
- 근거 / 전략서 자체 목적이 “현재 정서를 유입으로 전환”이라고 명시한다. 실제 피해자가 아닌 브랜드가 `私の免許証`, `会社は守ってくれなかった`를 쓰면 오인·반발 위험이 있다.
- 수정안 / 공식 발표 사실만 인용한 비개인적 설명으로 제한한다. 피해자 인터뷰·실패담은 명시적 동의와 사실검증 없이는 쓰지 않는다. 집단소송·재교부·신용정보 조치를 서비스 홍보 CTA와 같은 게시물에 섞지 않는다.

---

## 7. S1~S7 및 출시 게이트

### 7-1. 현재 실행 순서

- 문제 / S1을 완료 처리했지만 사실·필드·법적 분류가 확정되지 않았다. S2에서 40~50개 더미를 먼저 만들면 잘못된 스키마가 테스트 정답으로 굳어진다.
- 근거 / 위에서 확인한 jp01~jp13 오류와 실제 코드 미구현 상태. [전략서](/Users/sunghoon/Projects/docpack/docs/jp/jp_safefile_strategy_2026-10-20.md:154)
- 수정안 / 순서를 `법적 매트릭스 → 최소 4문서 fixture → 탐지/수동 편집 → 안전성 테스트 → 제한 베타 → 콘텐츠`로 바꾼다.

### 7-2. “S5 통과 전 홍보 금지”

- 문제 / 방향은 맞지만 S5의 “13종 중 12종 이상 1분 내 완료”는 개인정보 도구의 안전 게이트로 부적절하다. 한 문서 실패를 허용하며 미탐률·복원 가능성·오탐 훼손을 측정하지 않는다.
- 근거 / UI 완료시간은 보안성과 무관하다. 현재 “2px 패딩이면 透けない 보증 가능”도 OCR 박스가 글리프 바깥을 놓치는지, PDF 메타데이터·원본 첨부·EXIF가 남는지 검증하지 않았다.
- 수정안 / 공개 홍보 게이트를 다음으로 바꾼다.

  - 필수 민감항목 미탐 0건을 요구하는 문서별 골든 테스트
  - 원본 텍스트 레이어·주석·첨부·증분저장·EXIF 제거 검증
  - OCR 박스 외곽과 회전·왜곡·저해상도 사진 테스트
  - 다운로드 결과를 다른 PDF/이미지 도구로 재추출하는 공격 테스트
  - 지원하지 않는 문서는 자동 마스킹 금지 및 명확한 경고
  - 법적 문구 검수 완료

### 7-3. 2주 일정의 대안

- 문제 / 13종, 40~50 fixture, 일본어 OCR, 프리셋 6종, 워터마크, 실사이트 검증을 2주에 완성하는 것은 비현실적이다.
- 근거 / 주소·QR·카드 문서분류는 정규식 몇 개로 끝나지 않고 OCR 좌표·레이아웃 변형·법적 제출목적 테스트가 필요하다. 현재 코드는 일본 전용 탐지가 사실상 없다.
- 수정안 / 2주 안에는 범위를 축소한다.

  1. `資格確認書`, `住民票`, `マイナンバーカード`, `運転免許証` 네 종류만 알파 지원.
  2. 자동탐지는 `保険者番号・記号番号・個人番号`처럼 고신뢰 항목만 제공.
  3. 나머지는 수동 사각형 마스킹과 워터마크 중심.
  4. “자동으로 안전하게 가려준다”가 아니라 “로컬에서 직접 확인하며 가리는 도구”로 출시.
  5. 사건명 광고 대신 보험번호 마스킹 가이드와 제한 베타 모집만 시작.
  6. 4주 이상 실제 fixture를 모은 뒤 지원 문서를 순차 확대.

## 즉시 수정해야 할 상위 5개

1. `マイナンバーカード裏面は絶対提出禁止`, `2027年4月まで画像本人確認の穴` 등 잘못된 법률 표현과 콘텐츠 5·16번을 즉시 삭제한다.
2. `always/optional` 단일 분류를 폐지하고 제출 목적·수령기관별 규칙으로 바꾼다. 특히 jp10~jp13을 분리한다.
3. S1 “완료”와 S5의 “12/13 성공” 기준을 취소하고, 미탐 0·메타데이터 제거·복원 불가 검증을 출시 게이트로 지정한다.
4. 실물과 같은 免許証·マイナンバーカード 더미 및 유효 체크디지트 생성 계획을 중단하고, 명백히 비실물인 교육용 도식으로 교체한다.
5. 서버형 `マスキング済み書類ボックス`와 “개인정보처리방침과 무충돌” 문구를 철회한다. 초기 유료화는 로컬 저장·내보내기 기능으로 검증한다.
