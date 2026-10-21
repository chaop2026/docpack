warning: `--full-auto` is deprecated; use `--sandbox workspace-write` instead.
2026-10-21T17:05:27.262061Z ERROR codex_models_manager::cache: failed to load models cache: missing field `base_instructions` at line 139 column 5
OpenAI Codex v0.146.0
--------
workdir: /Users/sunghoon/Projects/docpack
model: gpt-5.6-sol
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR]
reasoning effort: none
reasoning summaries: none
session id: 01a15f6c-ca4c-7f91-aa9a-050eab7fa5e1
--------
user
당신은 일본 B2C/B2B SaaS 시장과 개인정보 관련 서비스 사업에 정통한 독립 검토자입니다. docs/jp/jp_market_brief_2026-10-22.md 를 읽고, 이를 작성한 Claude와 독립적으로 교차 검증하세요. 칭찬은 생략하고 틀린 것·빠진 것·과장된 것만 쓰세요. 각 항목은 "문제 / 근거(URL) / 수정안" 형식, 근거를 못 찾으면 "확인 불가"라고 명시. 추측을 근거처럼 쓰지 마세요. 웹 검색을 적극 사용하세요.

검증 질문:
1. 브리프 §1 "일본에서 개인용 서류 黒塗り 전용 서비스로 매출이 확인되는 곳이 없다"가 맞는가? 놓친 서비스(앱스토어·웹·LINE 미니앱 포함)가 있으면 이름·가격·규모 신호와 함께 제시.
2. §2 인접 시장 4개(B2B eKYC, PDF 스위트, 개인 신원보호, 물리 케이스)의 수치와 해석이 타당한가? IMARC 수치의 신뢰도, ノートン ID アドバイザー 등 개인 서비스의 일본 유료 규모에 대해 더 나은 출처가 있으면 제시.
3. 빠진 인접 시장: 예) 行政書士·司法書士 대행 서비스, 不動産 입주심사 SaaS, 건설업 전자입찰 보조 SaaS, 메르카리·フリマ 본인확인 관련 유료 도구, 프린트 서비스(コンビニ) 등에서 "마스킹"에 돈이 흐르는 경로가 있는가?
4. §3 수익 경로 A~D의 현실성 평가에 동의하는가? 특히 B(B2B-lite 팀 플랜 月額 ¥1,000~3,000)의 지불 의사와 경쟁 상황, C(개인 소액 과금)의 전례를 일본 사례로 반박 또는 보강.
5. 타이밍: 2026-09 타임즈카 유출 직후인 지금이 B2C 홍보에 유리하다는 판단에 반론이 있는가(예: 유출 피로, 규제 변화로 수요 소멸, 대기업의 무료 기능 출시 가능성 등)?
마지막에 "SafeFile이 일본에서 12개월 내 월 10만엔 매출에 도달할 가장 현실적 경로 1개"를 근거와 함께 한 문단으로 결론 내리세요. 일본어 고유명사는 그대로, 답변은 한국어로.
warning: Skill descriptions were shortened to fit the 2% skills context budget. Codex can still see every skill, but some descriptions are shorter. Disable unused skills or plugins to leave more room for the rest.
hook: SessionStart
hook: SessionStart Completed
hook: UserPromptSubmit
hook: UserPromptSubmit Completed
codex
요청하신 형식대로 독립 검증하겠습니다. 먼저 원문 전체를 읽고, Firecrawl 검색 스킬의 절차를 확인한 뒤 일본어 검색어를 중심으로 주장별 1차 출처와 가격·실적 신호를 대조하겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "sed -n '1,240p' /Users/sunghoon/.agents/skills/firecrawl-search/SKILL.md && sed -n '1,280p' docs/jp/jp_market_brief_2026-10-22.md" in /Users/sunghoon/Projects/docpack
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
# SafeFile JP — 시장·매출 가능성 브리프 v1 (2026-10-22, Claude 1차 / Codex 교차검증 대기)

> 질문: ① 일본에서 "개인 서류 黒塗り" 서비스로 매출을 내는 곳이 있는가 ② 없다면 비슷한 성격으로 매출을 내는 것은 무엇인가 ③ 그래서 SafeFile의 현실적 수익 경로는?
> 조사 깊이: 1시간 미만의 웹 조사. 숫자는 출처 신뢰도를 함께 표기. **확인 불가는 확인 불가로 적음.**

## 1. 직접 경쟁(B2C 서류 黒塗り 전용)으로 매출이 확인되는 곳 — **없음**

| 후보 | 실체 | 매출 신호 | 신뢰도 |
|---|---|---|---|
| 사진 모자이크 앱 (MOZA 등) | 얼굴 자동 가림·모자이크. 서류 특화 아님 | 月額 ¥200 / 年額 ¥1,300 과금. 평가 27건(3.7) → 사용자 규모 매우 작음 | App Store 공개 정보, 높음 |
| 肖像権(Android) 등 무료 모자이크 앱 | 무료, 광고 | 매출 불명 | 낮음 |
| Trupeer 등 AI 블러 툴 | 영어권 B2B 데모용, 일본어 랜딩만 | 일본 매출 확인 불가 | — |
| 개인용 "書類黒塗り" 웹툴 | **검색에서 발견되지 않음** | — | — |

→ "개인이 돈 내고 쓰는 서류 黒塗り 전용 서비스"는 일본에 **확인된 사례가 없다**. 이는 시장이 없다는 뜻일 수도, 공백이라는 뜻일 수도 있다. 아래 인접 시장이 판단 근거.

## 2. 인접 시장에서 매출이 확인되는 것

### 2-1 B2B eKYC·자동 마스킹 (있음, 성장 중)
- 일본 eKYC 시장: **USD 56.1M(2025) → 229.1M(2034), CAGR 16.9%** — IMARC 유료 리포트 요약, 신뢰도 중(시장조사사 추정치)
- ProTech AI Masking(ショーケース), TRUSTDOCK: 보험증 자동 마스킹을 **B2B SaaS로 판매** 중(2020-10 告知要求制限 시행 직후 출시). 매출 비공개
- 시사점: "마스킹에 돈을 내는 주체"는 현재 **서류를 받는 기업**이지 내는 개인이 아니다

### 2-2 PDF 편집 스위트 안의 墨消し 기능 (있음, 글로벌)
- Adobe Acrobat(개인 月額 약 ¥1,980대), Smallpdf Pro, iLovePDF Premium — 墨消し는 유료 스위트의 한 기능. 일본 매출 비중은 확인 불가
- 시사점: 개인은 "墨消し 단독"이 아니라 "PDF 편집 전체"에 돈을 낸다. 단독 기능 과금은 어려움

### 2-3 개인용 신원보호 서비스 (있음, 규모 불명)
- ノートン ID アドバイザー(2019~, 다크웹 모니터링+복구 상담): "상정 이상으로 이용자 증가"라는 정성 서술만, 숫자 없음(스폰서 기사)
- Whoscall: 일본 개인 유료회원 수 비공개
- 시사점: "유출 후 보호"에 돈 내는 개인 시장은 존재하나 규모 불명

### 2-4 물리적 "가리기" 상품 (있음, 지불 의사 확인)
- マイナンバーカード 뒷면 가리는 케이스: NuCover(티타늄), rokora(가죽, 일반 판매가 **¥5,480**, Makuake), Creema 수제 케이스 다수
- 시사점: 일본인은 **"번호를 가린다"에 ¥4,000~6,000을 낸다**. 디지털 서류에서 같은 욕구가 있다는 간접 증거

## 3. 결론 — SafeFile의 현실적 수익 경로 (Claude 1차 판단)

| 경로 | 근거 | 현실성 | 시점 |
|---|---|---|---|
| A. **일본어 SEO 랜딩 + AdSense** | 「保険証 マスキング やり方」류 검색은 법적 의무가 만드는 상시 수요. 트래픽 기반이라 전환 불필요 | 높음(규모는 작음) | 즉시 |
| B. **B2B-lite: 서류를 "매일 받는/내는" 소규모 사업자** — 건설업(입찰 첨부), 부동산 중개, 行政書士·社労士 | 2-1의 수요 주체와 같고, 대형 eKYC는 과잉·고가. 月額 ¥1,000~3,000 팀 플랜 | 중 | 베타 반응 후 |
| C. 개인 로컬 보관함·일괄처리 유료(¥100/회 또는 月額 ¥300) | 2-2·2-4 간접 근거뿐. 단독 기능 과금은 전례 없음 | 낮음~중 | 반응 본 뒤 |
| D. 개인 구독 전용 서비스 | 1절: 전례 없음 | 낮음 | 보류 |

**결정 제안**: 알파는 무료 B2C로 트래픽·반응 확보(A) → 베타 피드백에서 B의 사업자 비중을 측정 → B가 보이면 팀 플랜 우선, 안 보이면 C 소액 테스트. D는 하지 않는다.

**전략 v2와의 충돌 여부**: 없음. 타깃 2순위(입찰 첨부)가 B의 입구이므로 랜딩 3페이지 중 1개를 사업자용(「入札添付の資格確認書マスキング」)으로 유지.

## 4. 확인 불가·보강 필요
- 일본 PDF 툴(Smallpdf/iLovePDF)의 일본 유료 전환율·매출
- ノートン ID アドバイザー·Whoscall 일본 유료 회원 수
- 건설업 입찰에서 마스킹 재제출 빈도(지자체 담당자 인터뷰 필요)
- 行政書士 등 대행업의 서류 처리 건수·툴 비용

## 출처
- https://www.imarcgroup.com/japan-e-kyc-market
- https://www.showcase-tv.com/pressrelease/20210303aimasking
- https://apps.apple.com/jp/app/id6475031416 (MOZA)
- https://www.businessinsider.jp/article/254276/ (ノートン ID アドバイザー)
- https://www.makuake.com/project/my-number-cardcase-rokora/
- https://www.roomie.jp/2026/08/1874613/ (NuCover)
- https://smallpdf.com/jp/pricing , https://www.ilovepdf.com/ja/pricing

hook: PostToolUse
hook: PostToolUse Completed
codex
원문은 직접 경쟁의 정의를 지나치게 좁게 잡고, 물리 카드 케이스의 구매 이유를 “번호 가림”으로 단정한 부분이 특히 취약해 보입니다. 이제 전용 앱·LINE/웹, 인접 업무 흐름, 가격과 실제 유료 채택 신호를 분리해 확인하겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "mkdir -p .firecrawl && firecrawl search '日本 書類 黒塗り アプリ 個人情報 マスキング 料金' --limit 10 --scrape -o .firecrawl/direct1.json --json & firecrawl search 'App Store 日本 書類 マスキング 黒塗り 個人情報 アプリ' --limit 10 --scrape -o .firecrawl/direct2.json --json & firecrawl search 'LINE ミニアプリ 書類 マスキング 個人情報 黒塗り' --limit 10 --scrape -o .firecrawl/direct3.json --json & firecrawl search '日本 PDF 墨消し 料金 Adobe Acrobat Smallpdf iLovePDF' --limit 8 --scrape -o .firecrawl/pdf.json --json & wait" in /Users/sunghoon/Projects/docpack
 succeeded in 200ms:
Error: getaddrinfo ENOTFOUND api.firecrawl.dev
Error: getaddrinfo ENOTFOUND api.firecrawl.dev
Error: getaddrinfo ENOTFOUND api.firecrawl.dev
Error: getaddrinfo ENOTFOUND api.firecrawl.dev

hook: PostToolUse
hook: PostToolUse Completed
codex
Firecrawl 검색은 현재 실행 환경의 DNS 차단으로 실패했습니다. 같은 검증 범위를 일반 웹 검색으로 전환하되, 검색 스니펫보다 정부·사업자 공식 페이지와 앱스토어 원문을 우선하겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: site:apps.apple.com/jp 書類 黒塗り マスキング 個人情報 アプリ ...
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
web search: site:apps.apple.com/jp "PDF Masker" "¥" ...
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: 行政書士 個人情報 マスキング 書類 ソフト 料金 ...
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: タイムズカー 個人情報 漏えい 2026年9月 公式 ...
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: site:adobe.com/jp/acrobat/pricing Acrobat Pro 個人 月額 2026 墨消し ...
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: '5,480'
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
web search: 'アプリ内課金'
hook: PostToolUse
hook: PostToolUse Completed
codex
검증 기준일은 2026-10-22이다. “매출 확인”은 실제 매출·유료회원·다운로드가 공개된 경우로 한정했고, 앱 내 결제 옵션의 존재만으로 매출이 발생했다고 간주하지 않았다.

## 1. 직접 경쟁

1. 문제 / §1의 “개인용 書類黒塗り 웹툴이 검색되지 않는다”는 사실과 다르다. 일본어로 제공되는 무료 도구만 해도 Capsule Tools, みんなの電卓, エッジAIラボ 등이 있으며, 모두 PDF·이미지의 개인정보를 브라우저 또는 단말 내에서 마스킹한다고 명시한다. / 근거(URL) / [Capsule Tools](https://capsuletools.app/ja/pay-stub-redactor/), [みんなの電卓](https://minna-no-dentaku.com/tool/pdf-redaction-tool/), [エッジAIラボ](https://ai-edge-lab.com/demos/doc-redact/) / 수정안 / “유료 매출이 공개된 일본 사업자는 확인하지 못했으나 무료 전용 웹툴은 다수 존재한다. 따라서 공백은 제품 공백이 아니라 수익화 공백”으로 고쳐야 한다.

2. 문제 / 서류 黒塗り 전용 유료 앱 Pixelate를 누락했다. 이 앱은 2026년 9월 14일 출시됐고, 免許証·住民票·口座明細·PDF를 명시적으로 대상으로 하며 월 ¥600, 연 ¥5,000, 매입형 ¥2,500/¥5,000을 판매한다. 다만 리뷰 수가 표시 기준 미달이므로 실제 매출 규모는 확인 불가다. / 근거(URL) / [送信前に黒塗り・モザイクで個人情報を隠す（Pixelate）](https://apps.apple.com/jp/app/%E9%80%81%E4%BF%A1%E5%89%8D%E3%81%AB%E9%BB%92%E5%A1%97%E3%82%8A-%E3%83%A2%E3%82%B6%E3%82%A4%E3%82%AF%E3%81%A7%E5%80%8B%E4%BA%BA%E6%83%85%E5%A0%B1%E3%82%92%E9%9A%A0%E3%81%99/id6796954642) / 수정안 / “매출액은 확인 불가이나, 일본 App Store에서 직접 경쟁 유료 상품이 실제 판매 중”이라고 기록해야 한다.

3. 문제 / PDF 전용 경쟁 앱도 누락됐다. PDF Masker는 2025년 7월 출시, 완전 오프라인·키워드 일괄 마스킹·광고 제거 인앱 결제를 제공하고 평점은 5건이다. 가격과 매출은 확인 불가지만 “전용 서비스가 없다”는 제품 존재 주장에는 반례다. / 근거(URL) / [PDF Masker - かんたん墨消し](https://apps.apple.com/jp/app/pdf-masker-%E3%81%8B%E3%82%93%E3%81%9F%E3%82%93%E5%A2%A8%E6%B6%88%E3%81%97/id6748043661) / 수정안 / 경쟁표에 추가하고 규모 신호는 “평가 5건, 매출 확인 불가”로 제한해야 한다.

4. 문제 / 자동 개인정보 검출형 직접 경쟁도 누락됐다. プライバシーマスク는 문서·사진·PDF에서 전화번호, 주소, 계좌번호, 운전면허, QR 등을 온디바이스로 자동 검출하며 무료 1일 3건과 주·월·연 Pro 구독을 제시한다. 가격·평가·매출은 확인 불가다. / 근거(URL) / [プライバシーマスク](https://apps.apple.com/jp/app/%E3%83%97%E3%83%A9%E3%82%A4%E3%83%90%E3%82%B7%E3%83%BC%E3%83%9E%E3%82%B9%E3%82%AF/id6777008308) / 수정안 / SafeFile의 차별점을 “전용 앱의 부재”가 아니라 정확도, 일본 서류 프리셋, 완전 로컬 처리, 업무 반복처리로 재정의해야 한다.

5. 문제 / “매출이 확인되는 곳이 없다”는 엄밀히는 아직 반증되지 않았지만, 브리프가 이를 경쟁 부재와 혼용한다. Pixelate·PDF Masker·プライバシーマスク는 결제 수단은 있으나 실제 결제자 수나 매출이 공개되지 않았다. LINEミニアプリ형 직접 경쟁은 검색에서 확인 불가다. / 근거(URL) / 위 3개 App Store 페이지; LINE 사례는 확인 불가 / 수정안 / 결론을 “유료 상품은 존재하지만 실제 매출 규모가 공개된 직접 경쟁사는 확인하지 못했다”로 좁혀야 한다.

## 2. 인접 시장 4개

6. 문제 / IMARC의 USD 56.1M→229.1M 수치는 인용 자체는 정확하지만 검증 가능한 통계처럼 쓰기 어렵다. 공개 페이지는 정의·세그먼트·예측치를 제시하지만 표본, 매출 집계 방식, 환율, 중복 제거 및 산출식은 공개하지 않는다. 또한 eKYC 전체 시장은 단순 마스킹보다 훨씬 넓다. / 근거(URL) / [IMARC Japan E-KYC Market](https://www.imarcgroup.com/japan-e-kyc-market) / 수정안 / “유료 시장조사사의 비공개 방법론 추정치이며 방향성 참고용, SafeFile TAM 계산에는 사용 금지”로 신뢰도를 ‘중’보다 낮춰야 한다.

7. 문제 / eKYC 성장의 더 나은 검증 지표를 누락했다. デジタル庁은 JPKI 이용 민간사업자 1,411사와 플랫폼 사업자 29사를 공개하며, TRUSTDOCK은 도입 300사 이상, Liquid/ELEMENTS는 누적 1.5억 회·계약 600사 이상을 공시한다. 다만 이것도 마스킹 매출은 아니다. / 근거(URL) / [デジタル庁 JPKI](https://www.digital.go.jp/policies/mynumber/private-business/jpki-introduction), [TRUSTDOCK](https://biz.trustdock.io/), [ELEMENTS 공시자료](https://finance-frontend-pc-dist.west.edge.storage-yahoo.jp/disclosure/20251113/20251113599456.pdf) / 수정안 / 시장금액 대신 이들 실사용 지표를 보강하되 “본인확인 시장의 성장”과 “黒塗り 수요”를 분리해야 한다.

8. 문제 / PDF 스위트 가격이 부정확하다. 현재 일본 공식 가격은 Acrobat Standard ¥1,980/월, 실제 機密情報の墨消し가 포함되는 Acrobat Pro는 ¥2,530/월이다. iLovePDF는 $5/월이며 무료 플랜에도 문서 1건 한도로 PDF墨消し가 표시된다. 즉 SafeFile의 개인 유료 기능은 무료 대체재와도 경쟁한다. / 근거(URL) / [Adobe Acrobat 요금](https://www.adobe.com/jp/acrobat/plans.html?tab=compare-plans-2), [iLovePDF 요금](https://www.ilovepdf.com/ja/pricing), [Smallpdf 요금](https://smallpdf.com/jp/pricing) / 수정안 / “개인은 스위트에 돈을 낸다”뿐 아니라 “저빈도 개인은 무료 스위트·무료 웹툴로 해결 가능하다”를 추가해야 한다.

9. 문제 / ノートン ID アドバイザー의 일본 유료 규모를 “상정 이상 증가” 기사 하나로 판단한 것은 약하다. 현재 공식 연간 갱신가는 ¥5,480이지만 일본 가입자 수·매출은 여전히 확인 불가다. Whoscall은 월 ¥490/연 ¥4,600의 일본 소비자 유료 가격과 楽天モバイル 월 ¥330 유통 사례가 있어 가격 지불 전례로는 더 낫지만, 일본 유료회원 수는 확인 불가다. / 근거(URL) / [ノートン 갱신가격](https://jp.norton.com/pricing), [Whoscall 일본 가격](https://whoscall.com/ja/blog/articles/1890-%E3%81%8A%E8%A6%8B%E9%80%83%E3%81%97%E3%81%AA%E3%81%8F%EF%BC%81Whoscall%E3%83%97%E3%83%AC%E3%83%9F%E3%82%A2%E3%83%A0%E3%82%92%E4%BE%A1%E6%A0%BC%E6%94%B9%E5%AE%9A%E5%89%8D%E3%81%AE%E6%96%99%E9%87%91%E3%81%A7%E6%89%8B%E3%81%AB%E5%85%A5%E3%82%8C%E3%82%88%E3%81%86), [楽天モバイル Whoscall](https://origin-cms.rmb-ss.jp/service/whoscall/?l-id=service_carousel_service_whoscall) / 수정안 / “일본 소비자가 예방형 보안 서비스에 월 ¥330~490을 지불하는 판매 전례는 존재하지만 가입 규모는 확인 불가”라고 써야 한다.

10. 문제 / 물리 카드 케이스를 “번호를 가린다에 ¥4,000~6,000을 낸다”는 증거로 해석한 것은 과장이다. rokora의 판매 명분은 本革 제품과 RFID 스키밍 방지이며, Makuake 페이지에서 지원 총액·지원자 수가 정상적으로 공개되지 않아 판매 규모도 확인 불가다. 이는 단순 시각적 마스킹 구매의사가 아니다. / 근거(URL) / [rokora Makuake](https://www.makuake.com/project/my-number-cardcase-rokora/) / 수정안 / “물리 보안·재질·휴대성의 결합상품”으로 분류하고 디지털 黒塗り WTP 근거에서는 제외해야 한다.

## 3. 빠진 인접 시장과 돈의 흐름

11. 문제 / 기업용 마스킹 시장을 ProTech AI Masking과 TRUSTDOCK 정도로만 다뤘다. マイナマスク君은 住民票·源泉徴収票·確定申告書·マイナンバーカード 및 QR까지 자동 마스킹하는 별도 B2B 시스템이다. 가격·도입사·매출은 확인 불가다. / 근거(URL) / [マイナマスク君](https://www.e-d.co.jp/service/maina_mask_kun/), [RICOH カンタンマスキングアプリ](https://www.ricoh.co.jp/products/list/ricoh-easy-masking-apps) / 수정안 / 인접 경쟁군에 “복합기·스캔 업무용 자동 마스킹”을 추가해야 한다. B2B-lite 고객은 SafeFile뿐 아니라 복합기 벤더와도 경쟁한다.

12. 문제 / 건설·공공조달에서는 실제 반복 마스킹 의무가 확인된다. 입찰공고가 健康保険証의 被保険者記号・番号 등에 마스킹을 요구하고, 전자입찰은 PDF 첨부와 용량 제한을 운영한다. 다만 수급업체가 마스킹 전용 SaaS에 별도 돈을 낸다는 자료는 확인 불가다. / 근거(URL) / [입찰공고의 보험증 마스킹 요구](https://www.kkj.go.jp/d/?A=aGlyb3NoaW1hL2hhdHN1a2FpY2hpX2NpdHkvMjAyNS8yMDI1MDExNl8wMDI3OC5wZGYK&L=ja), [国土交通省 전자입찰 FAQ](https://www.e-bisc.go.jp/faq/index03.html), [F-REI 경비처리 매뉴얼](https://www.f-rei.go.jp/assets/contents/consignment_processing_manual.pdf) / 수정안 / 건설업을 유망 세그먼트로 남기되, 월정액 WTP가 아니라 “월 처리건수·반려 빈도·현재 작업시간” 인터뷰 후 가격을 정해야 한다.

13. 문제 / 行政書士·司法書士, 不動産 입주심사 SaaS, フリマ 본인확인 도구에서 “마스킹 자체”로 돈이 흐른다는 근거가 제시되지 않았다. 해당 업종에서 본인확인·서류대행·eKYC 비용은 발생하지만, 그 비용을 마스킹 기능의 지불의사로 분리할 공개 자료는 확인 불가다. / 근거(URL) / 확인 불가 / 수정안 / 이 업종들은 TAM에 넣지 말고 고객발견 후보군으로만 남겨야 한다.

14. 문제 / コンビニ 프린트도 마스킹 시장으로 계산할 수 없다. 편의점 복합기는 증명서 발급·복사·인쇄에 과금하지만 자동 黒塗り 기능이나 마스킹 추가요금은 확인되지 않는다. / 근거(URL) / [ファミリーマート マルチコピー機](https://www.family.co.jp/services/print/print.html?code=line) / 수정안 / 돈이 흐르는 경로는 “출력·복사료”일 뿐이므로 SafeFile 인접 매출 근거에서 제외해야 한다.

## 4. 수익 경로 A~D

15. 문제 / A의 현실성을 “높음”으로 평가할 근거가 없다. 무료 黒塗り 웹툴이 이미 여러 개이고, 검색량·클릭단가·광고 RPM이 전혀 제시되지 않았다. 민감문서 처리 도구가 제3자 광고 스크립트를 넣으면 “端末内完結·데이터 비수집” 포지셔닝과도 충돌할 수 있다. / 근거(URL) / 무료 경쟁은 [Capsule Tools](https://capsuletools.app/ja/pay-stub-redactor/), [みんなの電卓](https://minna-no-dentaku.com/tool/pdf-redaction-tool/); 일본어 키워드 검색량과 RPM은 확인 불가 / 수정안 / A는 “유입 실험”으로 낮추고, 광고는 랜딩 콘텐츠에만 배치하며 문서 처리 화면에는 넣지 않는 조건이 필요하다.

16. 문제 / B의 월 ¥1,000~3,000이 “지불의사가 확인된 가격”은 아니다. 상한 ¥2,530이면 이미 Acrobat Pro와 직접 비교되고, iLovePDF는 $5/월, Pixelate는 월 ¥600이다. 반대로 건설 SaaS에는 월 ¥1,980 사례가 있어 가격대 자체는 불가능하지 않지만, 그 제품은 안전서류 생성이라는 반복 업무를 판다. / 근거(URL) / [Adobe Acrobat](https://www.adobe.com/jp/acrobat/plans.html?tab=compare-plans-2), [iLovePDF](https://www.ilovepdf.com/ja/pricing), [Pixelate](https://apps.apple.com/jp/app/%E9%80%81%E4%BF%A1%E5%89%8D%E3%81%AB%E9%BB%92%E5%A1%97%E3%82%8A-%E3%83%A2%E3%82%B6%E3%82%A4%E3%82%AF%E3%81%A7%E5%80%8B%E4%BA%BA%E6%83%85%E5%A0%B1%E3%82%92%E9%9A%A0%E3%81%99/id6796954642), [AnzenAI 가격](https://anzen-ai.com/pricing.html) / 수정안 / B는 단순 팀 플랜이 아니라 “보험증·자격확인書類 프리셋, 일괄처리, 감사로그, 로컬 처리” 같은 반복 업무 절감 상품이어야 한다. 가격은 5~10개 업체의 유료 파일럿 전에는 가설로 표시해야 한다.

17. 문제 / C의 “¥100/회 또는 월 ¥300”은 일본 결제 전례를 충분히 반영하지 못한다. Whoscall 월 ¥330, 楽天 배포 ¥330, 기존 Whoscall 앱 월 ¥490, Pixelate 월 ¥600은 소비자 보안 구독 가격의 실제 앵커다. 그러나 黒塗り는 사용 빈도가 낮고 무료 대체가 많아 월정액 유지율은 별도 문제다. / 근거(URL) / [Whoscall 가격 개정](https://whoscall.com/ja/blog/articles/1890-%E3%81%8A%E8%A6%8B%E9%80%83%E3%81%97%E3%81%AA%E3%81%8F%EF%BC%81Whoscall%E3%83%97%E3%83%AC%E3%83%9F%E3%82%A2%E3%83%A0%E3%82%92%E4%BE%A1%E6%A0%BC%E6%94%B9%E5%AE%9A%E5%89%8D%E3%81%AE%E6%96%99%E9%87%91%E3%81%A7%E6%89%8B%E3%81%AB%E5%85%A5%E3%82%8C%E3%82%88%E3%81%86), [楽天モバイル](https://origin-cms.rmb-ss.jp/service/whoscall/?l-id=service_carousel_service_whoscall), [Pixelate](https://apps.apple.com/jp/app/%E9%80%81%E4%BF%A1%E5%89%8D%E3%81%AB%E9%BB%92%E5%A1%97%E3%82%8A-%E3%83%A2%E3%82%B6%E3%82%A4%E3%82%AF%E3%81%A7%E5%80%8B%E4%BA%BA%E6%83%85%E5%A0%B1%E3%82%92%E9%9A%A0%E3%81%99/id6796954642) / 수정안 / 개인 과금은 월 구독보다 ¥500~1,500의 30일 패스 또는 매입형을 먼저 시험하고, 반복 이용자에게만 구독을 제시하는 편이 타당하다.

18. 문제 / D를 단순히 “전례 없음”으로 기각하는 것도 부정확하다. 2026년 9월 출시된 Pixelate가 바로 개인 구독·매입형 전용 서비스다. 다만 리뷰 부족으로 성공 전례는 아니다. / 근거(URL) / [Pixelate App Store](https://apps.apple.com/jp/app/%E9%80%81%E4%BF%A1%E5%89%8D%E3%81%AB%E9%BB%92%E5%A1%97%E3%82%8A-%E3%83%A2%E3%82%B6%E3%82%A4%E3%82%AF%E3%81%A7%E5%80%8B%E4%BA%BA%E6%83%85%E5%A0%B1%E3%82%92%E9%9A%A0%E3%81%99/id6796954642) / 수정안 / “전례는 생겼으나 성공·규모는 확인 불가, 우선순위 낮음”으로 수정해야 한다.

## 5. 타이밍

19. 문제 / タイムズカー 유출 직후가 SafeFile B2C 홍보에 유리하다는 인과가 입증되지 않았다. 사건은 약 660만 계정과 운전면허·본인확인서류를 포함했지만, 이미 기업 서버에 저장된 과거 자료의 유출이다. 사용자가 제출 전에 일부를 가렸다면 가입·본인확인이 성립하지 않았을 가능성도 있어 SafeFile이 막을 수 있었던 사고라고 홍보하면 오도할 위험이 있다. / 근거(URL) / [タイムズモビリティ 제2보](https://www.timesmobi.co.jp/news/2026/09/33b24fb783a2d303b7e8664249ab57022cda975d.html) / 수정안 / 사건명을 직접 전환 광고에 쓰지 말고 “불필요한 정보까지 제출하지 않는 최소화 원칙” 교육 콘텐츠로 제한해야 한다.

20. 문제 / 수요가 계속 커진다는 가정은 규제·기술 변화를 무시한다. デジタル庁은 무료 스마트폰 マイナンバーカード와 JPKI를 확산시키고 있고, 2026년 이후 IC/JPKI 방식이 확대되면 신분증 이미지 업로드 및 사전 마스킹 수요 일부가 사라질 수 있다. / 근거(URL) / [스마트폰 マイナンバーカード](https://www.digital.go.jp/policies/mynumber/smartphone-certification), [JPKI 이용 현황](https://www.digital.go.jp/policies/mynumber/private-business/jpki-introduction), [カード代替電磁的記録](https://www.digital.go.jp/policies/mynumber/mynumbercard-mdoc) / 수정안 / 본인확인용 신분증에 집중하지 말고 입찰·보조금 정산·법원 제출·AI 입력 전 익명화처럼 JPKI로 대체되지 않는 문서 흐름을 우선해야 한다.

21. 문제 / “유출 직후”가 특별한 홍보 창이라는 소비자 반응 자료가 없다. 2026년 9~10월에는 タイムズカー 외에도 여러 대규모 유출이 연이어 공표돼 주목 상승과 동시에 유출 피로가 생길 가능성이 있지만, 일본 소비자의 실제 검색량·구매 전환 변화는 확인 불가다. / 근거(URL) / [2026년 주요 유출 사례 정리](https://self-plus.co.jp/knowledge/ec-news/member-data-leaks-timescar-seicomart-eplus/); 유출 피로 및 전환 상승 자료는 확인 불가 / 수정안 / 타이밍 판단은 Google Trends/Search Console과 사건 전후 랜딩 전환 실험이 나오기 전까지 가설로 내려야 한다.

## 결론: 12개월 내 월 ¥100,000의 가장 현실적인 단일 경로

가장 현실적인 경로는 **건설 입찰·보조금 정산 문서를 반복 제출하는 소규모 사업자용 B2B-lite**다. 이유는 보험증 번호·급여·계좌자료 등에 실제 마스킹 지침이 존재하고, 이 업무는 JPKI로 대체되지 않으며, 개인용 무료 도구보다 반복 프리셋·일괄처리·반려 방지에 돈을 받을 여지가 있기 때문이다. 다만 단순 黒塗り를 월 ¥3,000에 파는 것이 아니라 「被保険者記号・番号」「保険者番号」 등 제출처별 프리셋, 복수 PDF 일괄처리, 완전 로컬 처리, 처리기록을 묶어야 한다. 목표는 월 ¥2,980의 유료 사업자 34곳으로 잡고, 처음 5~10곳은 전자입찰 대행업체·건설업 行政書士를 통해 유료 파일럿으로 확보해야 한다. 이 경로의 업무 발생 근거는 확인되지만 현재 별도 SaaS 지불의사는 확인 불가이므로, 12개월 전망의 핵심 검증조건은 “무료 베타 사용자 수”가 아니라 첫 10개사의 실제 결제다.
hook: Stop
hook: Stop Completed
tokens used
96,657
검증 기준일은 2026-10-22이다. “매출 확인”은 실제 매출·유료회원·다운로드가 공개된 경우로 한정했고, 앱 내 결제 옵션의 존재만으로 매출이 발생했다고 간주하지 않았다.

## 1. 직접 경쟁

1. 문제 / §1의 “개인용 書類黒塗り 웹툴이 검색되지 않는다”는 사실과 다르다. 일본어로 제공되는 무료 도구만 해도 Capsule Tools, みんなの電卓, エッジAIラボ 등이 있으며, 모두 PDF·이미지의 개인정보를 브라우저 또는 단말 내에서 마스킹한다고 명시한다. / 근거(URL) / [Capsule Tools](https://capsuletools.app/ja/pay-stub-redactor/), [みんなの電卓](https://minna-no-dentaku.com/tool/pdf-redaction-tool/), [エッジAIラボ](https://ai-edge-lab.com/demos/doc-redact/) / 수정안 / “유료 매출이 공개된 일본 사업자는 확인하지 못했으나 무료 전용 웹툴은 다수 존재한다. 따라서 공백은 제품 공백이 아니라 수익화 공백”으로 고쳐야 한다.

2. 문제 / 서류 黒塗り 전용 유료 앱 Pixelate를 누락했다. 이 앱은 2026년 9월 14일 출시됐고, 免許証·住民票·口座明細·PDF를 명시적으로 대상으로 하며 월 ¥600, 연 ¥5,000, 매입형 ¥2,500/¥5,000을 판매한다. 다만 리뷰 수가 표시 기준 미달이므로 실제 매출 규모는 확인 불가다. / 근거(URL) / [送信前に黒塗り・モザイクで個人情報を隠す（Pixelate）](https://apps.apple.com/jp/app/%E9%80%81%E4%BF%A1%E5%89%8D%E3%81%AB%E9%BB%92%E5%A1%97%E3%82%8A-%E3%83%A2%E3%82%B6%E3%82%A4%E3%82%AF%E3%81%A7%E5%80%8B%E4%BA%BA%E6%83%85%E5%A0%B1%E3%82%92%E9%9A%A0%E3%81%99/id6796954642) / 수정안 / “매출액은 확인 불가이나, 일본 App Store에서 직접 경쟁 유료 상품이 실제 판매 중”이라고 기록해야 한다.

3. 문제 / PDF 전용 경쟁 앱도 누락됐다. PDF Masker는 2025년 7월 출시, 완전 오프라인·키워드 일괄 마스킹·광고 제거 인앱 결제를 제공하고 평점은 5건이다. 가격과 매출은 확인 불가지만 “전용 서비스가 없다”는 제품 존재 주장에는 반례다. / 근거(URL) / [PDF Masker - かんたん墨消し](https://apps.apple.com/jp/app/pdf-masker-%E3%81%8B%E3%82%93%E3%81%9F%E3%82%93%E5%A2%A8%E6%B6%88%E3%81%97/id6748043661) / 수정안 / 경쟁표에 추가하고 규모 신호는 “평가 5건, 매출 확인 불가”로 제한해야 한다.

4. 문제 / 자동 개인정보 검출형 직접 경쟁도 누락됐다. プライバシーマスク는 문서·사진·PDF에서 전화번호, 주소, 계좌번호, 운전면허, QR 등을 온디바이스로 자동 검출하며 무료 1일 3건과 주·월·연 Pro 구독을 제시한다. 가격·평가·매출은 확인 불가다. / 근거(URL) / [プライバシーマスク](https://apps.apple.com/jp/app/%E3%83%97%E3%83%A9%E3%82%A4%E3%83%90%E3%82%B7%E3%83%BC%E3%83%9E%E3%82%B9%E3%82%AF/id6777008308) / 수정안 / SafeFile의 차별점을 “전용 앱의 부재”가 아니라 정확도, 일본 서류 프리셋, 완전 로컬 처리, 업무 반복처리로 재정의해야 한다.

5. 문제 / “매출이 확인되는 곳이 없다”는 엄밀히는 아직 반증되지 않았지만, 브리프가 이를 경쟁 부재와 혼용한다. Pixelate·PDF Masker·プライバシーマスク는 결제 수단은 있으나 실제 결제자 수나 매출이 공개되지 않았다. LINEミニアプリ형 직접 경쟁은 검색에서 확인 불가다. / 근거(URL) / 위 3개 App Store 페이지; LINE 사례는 확인 불가 / 수정안 / 결론을 “유료 상품은 존재하지만 실제 매출 규모가 공개된 직접 경쟁사는 확인하지 못했다”로 좁혀야 한다.

## 2. 인접 시장 4개

6. 문제 / IMARC의 USD 56.1M→229.1M 수치는 인용 자체는 정확하지만 검증 가능한 통계처럼 쓰기 어렵다. 공개 페이지는 정의·세그먼트·예측치를 제시하지만 표본, 매출 집계 방식, 환율, 중복 제거 및 산출식은 공개하지 않는다. 또한 eKYC 전체 시장은 단순 마스킹보다 훨씬 넓다. / 근거(URL) / [IMARC Japan E-KYC Market](https://www.imarcgroup.com/japan-e-kyc-market) / 수정안 / “유료 시장조사사의 비공개 방법론 추정치이며 방향성 참고용, SafeFile TAM 계산에는 사용 금지”로 신뢰도를 ‘중’보다 낮춰야 한다.

7. 문제 / eKYC 성장의 더 나은 검증 지표를 누락했다. デジタル庁은 JPKI 이용 민간사업자 1,411사와 플랫폼 사업자 29사를 공개하며, TRUSTDOCK은 도입 300사 이상, Liquid/ELEMENTS는 누적 1.5억 회·계약 600사 이상을 공시한다. 다만 이것도 마스킹 매출은 아니다. / 근거(URL) / [デジタル庁 JPKI](https://www.digital.go.jp/policies/mynumber/private-business/jpki-introduction), [TRUSTDOCK](https://biz.trustdock.io/), [ELEMENTS 공시자료](https://finance-frontend-pc-dist.west.edge.storage-yahoo.jp/disclosure/20251113/20251113599456.pdf) / 수정안 / 시장금액 대신 이들 실사용 지표를 보강하되 “본인확인 시장의 성장”과 “黒塗り 수요”를 분리해야 한다.

8. 문제 / PDF 스위트 가격이 부정확하다. 현재 일본 공식 가격은 Acrobat Standard ¥1,980/월, 실제 機密情報の墨消し가 포함되는 Acrobat Pro는 ¥2,530/월이다. iLovePDF는 $5/월이며 무료 플랜에도 문서 1건 한도로 PDF墨消し가 표시된다. 즉 SafeFile의 개인 유료 기능은 무료 대체재와도 경쟁한다. / 근거(URL) / [Adobe Acrobat 요금](https://www.adobe.com/jp/acrobat/plans.html?tab=compare-plans-2), [iLovePDF 요금](https://www.ilovepdf.com/ja/pricing), [Smallpdf 요금](https://smallpdf.com/jp/pricing) / 수정안 / “개인은 스위트에 돈을 낸다”뿐 아니라 “저빈도 개인은 무료 스위트·무료 웹툴로 해결 가능하다”를 추가해야 한다.

9. 문제 / ノートン ID アドバイザー의 일본 유료 규모를 “상정 이상 증가” 기사 하나로 판단한 것은 약하다. 현재 공식 연간 갱신가는 ¥5,480이지만 일본 가입자 수·매출은 여전히 확인 불가다. Whoscall은 월 ¥490/연 ¥4,600의 일본 소비자 유료 가격과 楽天モバイル 월 ¥330 유통 사례가 있어 가격 지불 전례로는 더 낫지만, 일본 유료회원 수는 확인 불가다. / 근거(URL) / [ノートン 갱신가격](https://jp.norton.com/pricing), [Whoscall 일본 가격](https://whoscall.com/ja/blog/articles/1890-%E3%81%8A%E8%A6%8B%E9%80%83%E3%81%97%E3%81%AA%E3%81%8F%EF%BC%81Whoscall%E3%83%97%E3%83%AC%E3%83%9F%E3%82%A2%E3%83%A0%E3%82%92%E4%BE%A1%E6%A0%BC%E6%94%B9%E5%AE%9A%E5%89%8D%E3%81%AE%E6%96%99%E9%87%91%E3%81%A7%E6%89%8B%E3%81%AB%E5%85%A5%E3%82%8C%E3%82%88%E3%81%86), [楽天モバイル Whoscall](https://origin-cms.rmb-ss.jp/service/whoscall/?l-id=service_carousel_service_whoscall) / 수정안 / “일본 소비자가 예방형 보안 서비스에 월 ¥330~490을 지불하는 판매 전례는 존재하지만 가입 규모는 확인 불가”라고 써야 한다.

10. 문제 / 물리 카드 케이스를 “번호를 가린다에 ¥4,000~6,000을 낸다”는 증거로 해석한 것은 과장이다. rokora의 판매 명분은 本革 제품과 RFID 스키밍 방지이며, Makuake 페이지에서 지원 총액·지원자 수가 정상적으로 공개되지 않아 판매 규모도 확인 불가다. 이는 단순 시각적 마스킹 구매의사가 아니다. / 근거(URL) / [rokora Makuake](https://www.makuake.com/project/my-number-cardcase-rokora/) / 수정안 / “물리 보안·재질·휴대성의 결합상품”으로 분류하고 디지털 黒塗り WTP 근거에서는 제외해야 한다.

## 3. 빠진 인접 시장과 돈의 흐름

11. 문제 / 기업용 마스킹 시장을 ProTech AI Masking과 TRUSTDOCK 정도로만 다뤘다. マイナマスク君은 住民票·源泉徴収票·確定申告書·マイナンバーカード 및 QR까지 자동 마스킹하는 별도 B2B 시스템이다. 가격·도입사·매출은 확인 불가다. / 근거(URL) / [マイナマスク君](https://www.e-d.co.jp/service/maina_mask_kun/), [RICOH カンタンマスキングアプリ](https://www.ricoh.co.jp/products/list/ricoh-easy-masking-apps) / 수정안 / 인접 경쟁군에 “복합기·스캔 업무용 자동 마스킹”을 추가해야 한다. B2B-lite 고객은 SafeFile뿐 아니라 복합기 벤더와도 경쟁한다.

12. 문제 / 건설·공공조달에서는 실제 반복 마스킹 의무가 확인된다. 입찰공고가 健康保険証의 被保険者記号・番号 등에 마스킹을 요구하고, 전자입찰은 PDF 첨부와 용량 제한을 운영한다. 다만 수급업체가 마스킹 전용 SaaS에 별도 돈을 낸다는 자료는 확인 불가다. / 근거(URL) / [입찰공고의 보험증 마스킹 요구](https://www.kkj.go.jp/d/?A=aGlyb3NoaW1hL2hhdHN1a2FpY2hpX2NpdHkvMjAyNS8yMDI1MDExNl8wMDI3OC5wZGYK&L=ja), [国土交通省 전자입찰 FAQ](https://www.e-bisc.go.jp/faq/index03.html), [F-REI 경비처리 매뉴얼](https://www.f-rei.go.jp/assets/contents/consignment_processing_manual.pdf) / 수정안 / 건설업을 유망 세그먼트로 남기되, 월정액 WTP가 아니라 “월 처리건수·반려 빈도·현재 작업시간” 인터뷰 후 가격을 정해야 한다.

13. 문제 / 行政書士·司法書士, 不動産 입주심사 SaaS, フリマ 본인확인 도구에서 “마스킹 자체”로 돈이 흐른다는 근거가 제시되지 않았다. 해당 업종에서 본인확인·서류대행·eKYC 비용은 발생하지만, 그 비용을 마스킹 기능의 지불의사로 분리할 공개 자료는 확인 불가다. / 근거(URL) / 확인 불가 / 수정안 / 이 업종들은 TAM에 넣지 말고 고객발견 후보군으로만 남겨야 한다.

14. 문제 / コンビニ 프린트도 마스킹 시장으로 계산할 수 없다. 편의점 복합기는 증명서 발급·복사·인쇄에 과금하지만 자동 黒塗り 기능이나 마스킹 추가요금은 확인되지 않는다. / 근거(URL) / [ファミリーマート マルチコピー機](https://www.family.co.jp/services/print/print.html?code=line) / 수정안 / 돈이 흐르는 경로는 “출력·복사료”일 뿐이므로 SafeFile 인접 매출 근거에서 제외해야 한다.

## 4. 수익 경로 A~D

15. 문제 / A의 현실성을 “높음”으로 평가할 근거가 없다. 무료 黒塗り 웹툴이 이미 여러 개이고, 검색량·클릭단가·광고 RPM이 전혀 제시되지 않았다. 민감문서 처리 도구가 제3자 광고 스크립트를 넣으면 “端末内完結·데이터 비수집” 포지셔닝과도 충돌할 수 있다. / 근거(URL) / 무료 경쟁은 [Capsule Tools](https://capsuletools.app/ja/pay-stub-redactor/), [みんなの電卓](https://minna-no-dentaku.com/tool/pdf-redaction-tool/); 일본어 키워드 검색량과 RPM은 확인 불가 / 수정안 / A는 “유입 실험”으로 낮추고, 광고는 랜딩 콘텐츠에만 배치하며 문서 처리 화면에는 넣지 않는 조건이 필요하다.

16. 문제 / B의 월 ¥1,000~3,000이 “지불의사가 확인된 가격”은 아니다. 상한 ¥2,530이면 이미 Acrobat Pro와 직접 비교되고, iLovePDF는 $5/월, Pixelate는 월 ¥600이다. 반대로 건설 SaaS에는 월 ¥1,980 사례가 있어 가격대 자체는 불가능하지 않지만, 그 제품은 안전서류 생성이라는 반복 업무를 판다. / 근거(URL) / [Adobe Acrobat](https://www.adobe.com/jp/acrobat/plans.html?tab=compare-plans-2), [iLovePDF](https://www.ilovepdf.com/ja/pricing), [Pixelate](https://apps.apple.com/jp/app/%E9%80%81%E4%BF%A1%E5%89%8D%E3%81%AB%E9%BB%92%E5%A1%97%E3%82%8A-%E3%83%A2%E3%82%B6%E3%82%A4%E3%82%AF%E3%81%A7%E5%80%8B%E4%BA%BA%E6%83%85%E5%A0%B1%E3%82%92%E9%9A%A0%E3%81%99/id6796954642), [AnzenAI 가격](https://anzen-ai.com/pricing.html) / 수정안 / B는 단순 팀 플랜이 아니라 “보험증·자격확인書類 프리셋, 일괄처리, 감사로그, 로컬 처리” 같은 반복 업무 절감 상품이어야 한다. 가격은 5~10개 업체의 유료 파일럿 전에는 가설로 표시해야 한다.

17. 문제 / C의 “¥100/회 또는 월 ¥300”은 일본 결제 전례를 충분히 반영하지 못한다. Whoscall 월 ¥330, 楽天 배포 ¥330, 기존 Whoscall 앱 월 ¥490, Pixelate 월 ¥600은 소비자 보안 구독 가격의 실제 앵커다. 그러나 黒塗り는 사용 빈도가 낮고 무료 대체가 많아 월정액 유지율은 별도 문제다. / 근거(URL) / [Whoscall 가격 개정](https://whoscall.com/ja/blog/articles/1890-%E3%81%8A%E8%A6%8B%E9%80%83%E3%81%97%E3%81%AA%E3%81%8F%EF%BC%81Whoscall%E3%83%97%E3%83%AC%E3%83%9F%E3%82%A2%E3%83%A0%E3%82%92%E4%BE%A1%E6%A0%BC%E6%94%B9%E5%AE%9A%E5%89%8D%E3%81%AE%E6%96%99%E9%87%91%E3%81%A7%E6%89%8B%E3%81%AB%E5%85%A5%E3%82%8C%E3%82%88%E3%81%86), [楽天モバイル](https://origin-cms.rmb-ss.jp/service/whoscall/?l-id=service_carousel_service_whoscall), [Pixelate](https://apps.apple.com/jp/app/%E9%80%81%E4%BF%A1%E5%89%8D%E3%81%AB%E9%BB%92%E5%A1%97%E3%82%8A-%E3%83%A2%E3%82%B6%E3%82%A4%E3%82%AF%E3%81%A7%E5%80%8B%E4%BA%BA%E6%83%85%E5%A0%B1%E3%82%92%E9%9A%A0%E3%81%99/id6796954642) / 수정안 / 개인 과금은 월 구독보다 ¥500~1,500의 30일 패스 또는 매입형을 먼저 시험하고, 반복 이용자에게만 구독을 제시하는 편이 타당하다.

18. 문제 / D를 단순히 “전례 없음”으로 기각하는 것도 부정확하다. 2026년 9월 출시된 Pixelate가 바로 개인 구독·매입형 전용 서비스다. 다만 리뷰 부족으로 성공 전례는 아니다. / 근거(URL) / [Pixelate App Store](https://apps.apple.com/jp/app/%E9%80%81%E4%BF%A1%E5%89%8D%E3%81%AB%E9%BB%92%E5%A1%97%E3%82%8A-%E3%83%A2%E3%82%B6%E3%82%A4%E3%82%AF%E3%81%A7%E5%80%8B%E4%BA%BA%E6%83%85%E5%A0%B1%E3%82%92%E9%9A%A0%E3%81%99/id6796954642) / 수정안 / “전례는 생겼으나 성공·규모는 확인 불가, 우선순위 낮음”으로 수정해야 한다.

## 5. 타이밍

19. 문제 / タイムズカー 유출 직후가 SafeFile B2C 홍보에 유리하다는 인과가 입증되지 않았다. 사건은 약 660만 계정과 운전면허·본인확인서류를 포함했지만, 이미 기업 서버에 저장된 과거 자료의 유출이다. 사용자가 제출 전에 일부를 가렸다면 가입·본인확인이 성립하지 않았을 가능성도 있어 SafeFile이 막을 수 있었던 사고라고 홍보하면 오도할 위험이 있다. / 근거(URL) / [タイムズモビリティ 제2보](https://www.timesmobi.co.jp/news/2026/09/33b24fb783a2d303b7e8664249ab57022cda975d.html) / 수정안 / 사건명을 직접 전환 광고에 쓰지 말고 “불필요한 정보까지 제출하지 않는 최소화 원칙” 교육 콘텐츠로 제한해야 한다.

20. 문제 / 수요가 계속 커진다는 가정은 규제·기술 변화를 무시한다. デジタル庁은 무료 스마트폰 マイナンバーカード와 JPKI를 확산시키고 있고, 2026년 이후 IC/JPKI 방식이 확대되면 신분증 이미지 업로드 및 사전 마스킹 수요 일부가 사라질 수 있다. / 근거(URL) / [스마트폰 マイナンバーカード](https://www.digital.go.jp/policies/mynumber/smartphone-certification), [JPKI 이용 현황](https://www.digital.go.jp/policies/mynumber/private-business/jpki-introduction), [カード代替電磁的記録](https://www.digital.go.jp/policies/mynumber/mynumbercard-mdoc) / 수정안 / 본인확인용 신분증에 집중하지 말고 입찰·보조금 정산·법원 제출·AI 입력 전 익명화처럼 JPKI로 대체되지 않는 문서 흐름을 우선해야 한다.

21. 문제 / “유출 직후”가 특별한 홍보 창이라는 소비자 반응 자료가 없다. 2026년 9~10월에는 タイムズカー 외에도 여러 대규모 유출이 연이어 공표돼 주목 상승과 동시에 유출 피로가 생길 가능성이 있지만, 일본 소비자의 실제 검색량·구매 전환 변화는 확인 불가다. / 근거(URL) / [2026년 주요 유출 사례 정리](https://self-plus.co.jp/knowledge/ec-news/member-data-leaks-timescar-seicomart-eplus/); 유출 피로 및 전환 상승 자료는 확인 불가 / 수정안 / 타이밍 판단은 Google Trends/Search Console과 사건 전후 랜딩 전환 실험이 나오기 전까지 가설로 내려야 한다.

## 결론: 12개월 내 월 ¥100,000의 가장 현실적인 단일 경로

가장 현실적인 경로는 **건설 입찰·보조금 정산 문서를 반복 제출하는 소규모 사업자용 B2B-lite**다. 이유는 보험증 번호·급여·계좌자료 등에 실제 마스킹 지침이 존재하고, 이 업무는 JPKI로 대체되지 않으며, 개인용 무료 도구보다 반복 프리셋·일괄처리·반려 방지에 돈을 받을 여지가 있기 때문이다. 다만 단순 黒塗り를 월 ¥3,000에 파는 것이 아니라 「被保険者記号・番号」「保険者番号」 등 제출처별 프리셋, 복수 PDF 일괄처리, 완전 로컬 처리, 처리기록을 묶어야 한다. 목표는 월 ¥2,980의 유료 사업자 34곳으로 잡고, 처음 5~10곳은 전자입찰 대행업체·건설업 行政書士를 통해 유료 파일럿으로 확보해야 한다. 이 경로의 업무 발생 근거는 확인되지만 현재 별도 SaaS 지불의사는 확인 불가이므로, 12개월 전망의 핵심 검증조건은 “무료 베타 사용자 수”가 아니라 첫 10개사의 실제 결제다.
