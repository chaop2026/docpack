warning: `--full-auto` is deprecated; use `--sandbox workspace-write` instead.
2026-10-21T00:56:07.923204Z ERROR codex_models_manager::cache: failed to load models cache: missing field `base_instructions` at line 139 column 5
OpenAI Codex v0.146.0
--------
workdir: /Users/sunghoon/Projects/docpack
model: gpt-5.6-sol
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR]
reasoning effort: none
reasoning summaries: none
session id: 01a15bf5-59d7-77c3-bcf8-3596a099aaa2
--------
user
당신은 브라우저 내 문서 마스킹 파이프라인과 일본 개인정보 실무에 정통한 독립 검토자입니다. 아래 커밋을 작성한 Claude와 **독립적으로** 비판적 검토를 하세요. 칭찬은 생략하고 **틀린 것·빠진 것·위험한 것만** 쓰세요. 각 항목은 "문제 / 근거(파일:줄) / 수정안" 형식이고, 근거를 못 찾으면 **"확인 불가"** 라고 명시하세요. 추측을 근거처럼 쓰지 마세요.

## 검토 대상

```
git show 546344b --stat
git show 546344b -- public/safe/index.html
```

- 변경 diff 전체 (커밋 `546344b`)
- 구현: `public/safe/index.html` — 특히 `jpNorm` / `jpSegments` / `jpClassify` / `jpExtract` / `jpFrameBelow` / `jpCodeBlocks` / `jpSolidSquares` / `jpAddressSpan` / `myNumberCheckOk` / `JP_RULES` / `jpLevel` / `jpApply` / `bandRect` / `drawRedactions` / `ocrCanvas`
- 하네스: `test/safe/run.mjs`, `test/safe/specs.json` (`jp_docs`·`jp_units`·`jp_auto_fields`)
- 법적 정본: `test/safe/fixtures/jp/jp_legal_matrix_alpha4.json`
- 픽스처 기대값: `test/safe/fixtures/jp/*/*.specs.json`
- 전략: `docs/jp/jp_safefile_strategy_v2_2026-10-21.md` §3 제품 요구사항 · §4 더미 안전조건 · §7 게이트
- 구현자 자술: `docs/jp/s3_report.md` · 전체 통과 로그 `docs/jp/s3_golden_result.md`

실행 환경 참고: `cd test/safe && npm install && node run.mjs` (Chrome 필요, 네트워크로 Tesseract.js·pdf.js CDN 접근). 돌릴 수 없으면 **정적 검토만 하고 그렇다고 적으세요** — 테스트를 돌린 것처럼 쓰지 마세요.

## 1. 탐지의 **미탐** 위험 (가장 중요)

이 제품의 가장 비싼 실패는 가려야 할 번호가 안 가려지는 것입니다.

1-1. `jpClassify` 가 **분류에 실패하면 일본 자동 마스킹이 전부 꺼진다**(`jpScan` → `jpApply`). 임계값 4와 키워드 가중치는 알파 11개 픽스처로만 조정됐습니다. 실제 보험자별 양식·지자체 양식에서 분류가 떨어질 조합이 있습니까? 분류 실패를 **사용자가 알 수 있습니까?**

1-2. `JP_SEG_GAP = max(90, 페이지폭 × 0.10)`. 레이블–값 간격이 이보다 넓거나 칸–칸 간격이 이보다 좁은 실제 양식이 있으면 레이블 앵커가 통째로 끊깁니다. 어떤 조건에서 깨집니까?

1-3. 모든 값 규칙이 **세그먼트 선두 앵커**(`headOnly: true`)입니다. 레이블 앞에 기호·번호·OCR 잡음 한 글자가 붙는 실제 양식에서 전부 미탐이 됩니다. 이 가드가 과한가요, 아니면 대안이 있습니까?

1-4. `資格確認書` 의 6~10자리 구조 폴백과 `住民票` 의 11/12자리 폴백은 **날짜 줄 제외 + 길이**만 봅니다. 실제 양식에서 이 조건을 통과하는 **가려서는 안 될** 숫자열이 있습니까? (`一部負担金割合`, `自己負担限度額区分`, 발행번호, 証明書番号 등)

1-5. `myNumberCheckOk` 를 番号法施行令 별표와 대조해 주세요. 가중치 Q_n·검사식·`≥10→0` 처리가 맞습니까? **틀렸다면 유효한 個人番号가 후보로만 뜨거나 그 반대가 됩니다.**

1-6. 세대원 블록 경계를 `氏名` 레이블 행으로 잡고, 마지막 블록을 `この写し|相違|証明し|市長|区長|町長|村長|公印` 로 끊습니다. 실제 住民票 레이아웃에서 이 경계가 틀려 **제3자 정보가 남거나 발행자가 가려지는** 경우는?

## 2. 탐지의 **오탐** 위험 — 필수 증빙 훼손

2-1. `jpFrameBelow` (150px 이상 연속 잉크 가로줄 + x범위 ±12px, 레이블 높이 12배 이내). 표·괘선이 많은 양식에서 엉뚱한 사각형을 잡아 **필수 기재사항을 덮을** 경우는? `jpRowInk` 가 행당 **가장 긴 런 하나만** 보는 것이 맞습니까?

2-2. `jpSolidSquares` (16px 셀, 밀도 ≥0.6, 면적 ≥60px, 종횡비 0.8~1.25, 채움 ≥0.75). **顔写真**·인감·로고·검은 표 헤더가 이 조건을 통과합니까? 통과하면 `labelled:false` → candidate 로만 뜨지만, **그 candidate 의 기본 모드가 목적에 따라 `no`(= 기본 ON) 가 되는 경로가 있습니까?**

2-3. `jpAddressSpan` 의 기관명 **감점 −2** 와 임계 3. 실제 주소 뒤에 회사명이 붙은 줄에서 주소가 통째로 사라지거나(미탐), 반대로 회사 소재지가 **자동** 띠가 되는(오탐) 경계가 어디입니까? `郵便番号+都道府県 동반 → 자동` 이 과합니까?

2-4. `bandRect` 의 15% 패딩이 **빽빽한 양식에서 이웃 필드를 덮을** 수 있습니까? `region:true` 를 패딩에서 제외한 판단은 맞습니까?

## 3. 출력 안전성의 **완전성**

3-1. `TEXT_LEAK`(추출 문자 0) + 바이트 스캔(`/Annots` `/EmbeddedFile` `/XFA` `/AcroForm` `/Names`, 이미지 EXIF/XMP/IPTC) + `%%EOF` 1개. **이 목록이 충분합니까?** jsPDF 2.5.1 가 만드는 PDF에서 원본이 남을 다른 경로(XObject 메타, `/Metadata` XMP 스트림, 문서 정보 사전, 압축 객체 스트림 안의 문자열)가 있습니까?

3-2. 입력 PDF 의 **주석·첨부·북마크·XMP** 가 출력으로 새는 경로가 정말 없습니까? (`composePage` 는 래스터를 다시 그리고 jsPDF 가 새 문서를 만듭니다 — 이 논증이 맞는지 확인해 주세요.)

3-3. ICC 를 금지하지 않고 **크기 2KB + `dmnd`/`dmdd` 태그**로 경계 지은 판단이 타당합니까? 디스플레이 프로파일이 그 조건을 피해 나갈 수 있습니까?

3-4. PNG 출력에 `eXIf/tEXt/zTXt/iTXt` 만 봅니다. 다른 보조 청크로 데이터가 실릴 수 있습니까?

## 4. 목적 게이트 논리

4-1. `JP_RULES` 를 `jp_legal_matrix_alpha4.json` 과 **한 줄씩 대조**해 주세요. 불일치·누락이 있습니까?

4-2. `jpLevel` 의 **폴백이 항상 `optional`** 입니다. 매트릭스가 그 목적을 명시하지 않은 필드를 "제공하되 꺼둠" 으로 떨어뜨리는 것이 맞습니까, 아니면 `keep` 쪽으로 가야 하는 경우가 있습니까? 특히 **`資格確認書` 의 ID 계열이 `my_number_procedure` 에서 `optional`(기본 OFF)** 이 되는데, 그 조합이 실무에서 발생합니까?

4-3. 의도적 매트릭스 이탈 1건: `本籍`/`筆頭者` 에 `my_number_procedure`·`bid_attachment` 를 추가(level 은 `recommend` 유지). 근거가 충분합니까?

4-4. `マイナカード裏面 + 本人確認 → 면 전체 띠` 와 안내문. 番号法상 정확합니까? **個人番号手続 선택 시 해제**가 올바른 동작입니까?

4-5. `keep` 항목을 사용자가 가릴 수 있게 두고 **경고만** 하는 설계. 개별 토글과 일괄 비공개 양쪽에 경고가 있습니다. 차단해야 할 경우가 있습니까?

4-6. `JP_TYPE` 이 JP 필드를 기존 카테고리에 매핑합니다(`back_all`·`qr` → `other`). **사용자가 `その他` 카테고리 체크박스를 끄면 법적 근거로 걸린 띠가 사라집니다**(`isOn`). 이것이 허용돼야 합니까?

## 5. 하네스가 **진짜로** 검증하는가

5-1. `jp_auto_fields` 가 "어떤 단언을 쓸지" 를 결정합니다. 이 표가 매트릭스 `level` 과 어긋나면 **골든이 틀린 동작을 통과시킵니다.** 대조해 주세요.

5-2. `JP_MASK_OR_CAND`(個人番号) — 띠 **또는** 후보면 통과. 이 느슨함이 실제 회귀를 숨길 수 있습니까? 체크디지트가 **유효한** 個人番号가 자동 띠가 되는지는 어디서 검증됩니까? (현재 픽스처는 전부 불일치입니다.)

5-3. 박스 피복 기준: 박스 안에 텍스트 아이템이 있으면 **각 아이템 ≥60%**, 없으면 **면적 ≥60%**, `keep` 은 **≤10%**. 60% 가 "판독 불가" 를 보장합니까? 숫자 하나가 60% 덮여도 읽힐 수 있습니까?

5-4. `geometry:false` (jpg 3건 + consult_share 1건)는 좌표 단언을 **건너뜁니다.** 이 면제가 숨기는 회귀가 있습니까?

5-5. **공허한 단언이 남아 있습니까?** 특히 `JP_COVERAGE`·`JP_CLEAR`·`JP_OPTIONAL`·`require_banded` 가 조건을 만족하지 못해도 통과하는 경로가 있는지 보세요.

5-6. `max_auto` 상한값(kenpo 8 등)이 **실측 + 여유** 인지, 아니면 회귀를 통과시킬 만큼 느슨한지.

## 6. 커버리지가 없는 구현

구현자가 스스로 올린 공백입니다. **등급이 맞는지, 더 있는지** 판정해 주세요.

6-1. **레이블 없는 QR/바코드** — 픽스처·유닛 둘 다 없음. candidate 고정이 충분한 완화입니까?
6-2. **電話·FAX** — `jp_units` 6건만. 레이블 앵커 → 박스 변환 경로가 한 번도 실행된 적 없습니다.
6-3. **住所 `郵便番号+都道府県 → 자동`** — 유닛에서만 참. 실제 문서로 본 적 없습니다.
6-4. **多ページ 일본 문서** — 2페이지 이후 분류 상속(`jpScan`) 경로 미실행.
6-5. `jpPageBg` 가 페이지 **테두리 24점의 중앙값**을 배경으로 씁니다. 어두운 배경·전면 컬러 양식에서 `jpFrameBelow`·`jpSolidSquares` 가 어떻게 됩니까?

## 7. 공개 저장소 + 카드 더미 (사람 결정 대기)

`chaop2026/docpack` 은 **PUBLIC** 이고, 전략 §4 는 카드 더미를 **법률 검토 전까지 내부 전용**으로 묶어 뒀습니다. 커밋은 그 보류를 사실상 해제합니다. 구현자의 판단과 완화 조치는 `CLAUDE.md` 의 「JP-1 이슈 로그」에 있습니다.

7-1. `test/safe/fixtures/jp/` 의 더미가 §4 의 **생성 안전조건을 전부** 충족합니까? 빠진 조건이 있습니까?
7-2. 공개 저장소 커밋의 실질 위험을 어떻게 평가합니까? (오용 가치 / 일본 법 / GitHub 이용약관)
7-3. 대안(비공개 서브모듈 / 생성 스크립트만 커밋 / 해상도 축소)의 실현성과 비용.

---

마지막에 **"즉시 고쳐야 할 상위 5개"** 를 우선순위로 요약하고, 각각에 **AMBER/GREEN** 등급과 "배포 전/다음 런" 을 붙이세요. 일본어 고유명사는 그대로 두고, 답변은 **한국어**로. **파일을 수정하지 말고 검토 결과만 출력**하세요.
warning: Skill descriptions were shortened to fit the 2% skills context budget. Codex can still see every skill, but some descriptions are shorter. Disable unused skills or plugins to leave more room for the rest.
hook: SessionStart
hook: SessionStart Completed
hook: UserPromptSubmit
hook: UserPromptSubmit Completed
codex
요청하신 형식대로 독립 정적·동적 검토를 하겠습니다. 먼저 저장소 지침과 지정 커밋 전체를 읽고, 법적 정본·전략·하네스·픽스처를 상호 대조한 뒤 가능하면 실제 하네스를 실행하겠습니다. 파일은 수정하지 않습니다.
codex
코드 구조를 빠짐없이 추적하기 위해 `claude-mem:smart-explore` 스킬을 사용하겠습니다. 이 스킬은 함수·호출 관계를 구조적으로 찾는 데 쓰되, 최종 판단은 실제 diff와 원문 줄을 직접 대조해 내리겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "sed -n '1,240p' /Users/sunghoon/.codex/plugins/cache/claude-mem-local/claude-mem/13.8.1/skills/smart-explore/SKILL.md" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
---
name: smart-explore
description: Token-optimized structural code search using tree-sitter AST parsing. Use instead of reading full files when you need to understand code structure, find functions, or explore a codebase efficiently.
---

# Smart Explore

Structural code exploration using AST parsing. **This skill overrides your default exploration behavior.** While this skill is active, use smart_search/smart_outline/smart_unfold as your primary tools instead of Read, Grep, and Glob.

**Core principle:** Index first, fetch on demand. Give yourself a map of the code before loading implementation details. The question before every file read should be: "do I need to see all of this, or can I get a structural overview first?" The answer is almost always: get the map.

## Your Next Tool Call

This skill only loads instructions. You must call the MCP tools yourself. Your next action should be one of:

```
smart_search(query="<topic>", path="./src")    -- discover files + symbols across a directory
smart_outline(file_path="<file>")              -- structural skeleton of one file
smart_unfold(file_path="<file>", symbol_name="<name>")  -- full source of one symbol
```

Do NOT run Grep, Glob, Read, or find to discover files first. `smart_search` walks directories, parses all code files, and returns ranked symbols in one call. It replaces the Glob → Grep → Read discovery cycle.

## 3-Layer Workflow

### Step 1: Search -- Discover Files and Symbols

```
smart_search(query="shutdown", path="./src", max_results=15)
```

**Returns:** Ranked symbols with signatures, line numbers, match reasons, plus folded file views (~2-6k tokens)

```
-- Matching Symbols --
  function performGracefulShutdown (services/infrastructure/GracefulShutdown.ts:56)
  function httpShutdown (services/infrastructure/HealthMonitor.ts:92)
  method WorkerService.shutdown (services/worker-service.ts:846)

-- Folded File Views --
  services/infrastructure/GracefulShutdown.ts (7 symbols)
  services/worker-service.ts (12 symbols)
```

This is your discovery tool. It finds relevant files AND shows their structure. No Glob/find pre-scan needed.

**Parameters:**

- `query` (string, required) -- What to search for (function name, concept, class name)
- `path` (string) -- Root directory to search (defaults to cwd)
- `max_results` (number) -- Max matching symbols, default 20, max 50
- `file_pattern` (string, optional) -- Filter to specific files/paths

### Step 2: Outline -- Get File Structure

```
smart_outline(file_path="services/worker-service.ts")
```

**Returns:** Complete structural skeleton -- all functions, classes, methods, properties, imports (~1-2k tokens per file)

**Skip this step** when Step 1's folded file views already provide enough structure. Most useful for files not covered by the search results.

**Parameters:**

- `file_path` (string, required) -- Path to the file

### Step 3: Unfold -- See Implementation

Review symbols from Steps 1-2. Pick the ones you need. Unfold only those:

```
smart_unfold(file_path="services/worker-service.ts", symbol_name="shutdown")
```

**Returns:** Full source code of the specified symbol including JSDoc, decorators, and complete implementation (~400-2,100 tokens depending on symbol size). AST node boundaries guarantee completeness regardless of symbol size — unlike Read + agent summarization, which may truncate long methods.

**Parameters:**

- `file_path` (string, required) -- Path to the file (as returned by search/outline)
- `symbol_name` (string, required) -- Name of the function/class/method to expand

## When to Use Standard Tools Instead

Use these only when smart_* tools are the wrong fit:

- **Grep:** Exact string/regex search ("find all TODO comments", "where is `ensureWorkerStarted` defined?")
- **Read:** Small files under ~100 lines, non-code files (JSON, markdown, config)
- **Glob:** File path patterns ("find all test files")
- **Explore agent:** When you need synthesized understanding across 6+ files, architecture narratives, or answers to open-ended questions like "how does this entire system work end-to-end?" Smart-explore is a scalpel — it answers "where is this?" and "show me that." It doesn't synthesize cross-file data flows, design decisions, or edge cases across an entire feature.

For code files over ~100 lines, prefer smart_outline + smart_unfold over Read.

## Workflow Examples

**Discover how a feature works (cross-cutting):**

```
1. smart_search(query="shutdown", path="./src")
   -> 14 symbols across 7 files, full picture in one call
2. smart_unfold(file_path="services/infrastructure/GracefulShutdown.ts", symbol_name="performGracefulShutdown")
   -> See the core implementation
```

**Navigate a large file:**

```
1. smart_outline(file_path="services/worker-service.ts")
   -> 1,466 tokens: 12 functions, WorkerService class with 24 members
2. smart_unfold(file_path="services/worker-service.ts", symbol_name="startSessionProcessor")
   -> 1,610 tokens: the specific method you need
Total: ~3,076 tokens vs ~12,000 to Read the full file
```

**Write documentation about code (hybrid workflow):**

```
1. smart_search(query="feature name", path="./src")    -- discover all relevant files and symbols
2. smart_outline on key files                           -- understand structure
3. smart_unfold on important functions                  -- get implementation details
4. Read on small config/markdown/plan files             -- get non-code context
```

Use smart_* tools for code exploration, Read for non-code files. Mix freely.

**Exploration then precision:**

```
1. smart_search(query="session", path="./src", max_results=10)
   -> 10 ranked symbols: SessionMetadata, SessionQueueProcessor, SessionSummary...
2. Pick the relevant one, unfold it
```

## Token Economics

| Approach | Tokens | Use Case |
|----------|--------|----------|
| smart_outline | ~1,000-2,000 | "What's in this file?" |
| smart_unfold | ~400-2,100 | "Show me this function" |
| smart_search | ~2,000-6,000 | "Find all X across the codebase" |
| search + unfold | ~3,000-8,000 | End-to-end: find and read (the primary workflow) |
| Read (full file) | ~12,000+ | When you truly need everything |
| Explore agent | ~39,000-59,000 | Cross-file synthesis with narrative |

**4-8x savings** on file understanding (outline + unfold vs Read). **11-18x savings** on codebase exploration vs Explore agent. The narrower the query, the wider the gap — a 27-line function costs 55x less to read via unfold than via an Explore agent, because the agent still reads the entire file.

## Language Support

Smart-explore uses **tree-sitter AST parsing** for structural analysis. Unsupported file types fall back to text-based search.

### Bundled Languages

| Language | Extensions |
|----------|-----------|
| JavaScript | `.js`, `.mjs`, `.cjs` |
| TypeScript | `.ts` |
| TSX / JSX | `.tsx`, `.jsx` |
| Python | `.py`, `.pyw` |
| Go | `.go` |
| Rust | `.rs` |
| Ruby | `.rb` |
| Java | `.java` |
| C | `.c`, `.h` |
| C++ | `.cpp`, `.cc`, `.cxx`, `.hpp`, `.hh` |

Files with unrecognized extensions are parsed as plain text — `smart_search` still works (grep-style), but `smart_outline` and `smart_unfold` will not extract structured symbols.

### Custom Grammars (`.claude-mem.json`)

You can register additional tree-sitter grammars for file types not in the bundled list. Create or update `.claude-mem.json` in your project root:

```json
{
  "grammars": {
    "solidity": {
      "package": "tree-sitter-solidity",
      "extensions": [".sol"],
      "query": "solidity-query.scm"
    }
  }
}
```

Each key is a language name. `package` is the npm package of the tree-sitter grammar and `extensions` lists the file extensions it covers; the package must be installed in the project's `node_modules` (`npm install tree-sitter-solidity`). `query` (optional) is a path, relative to the config file, to a tree-sitter query whose captures (`@func`, `@cls`, `@method`, `@iface`, `@enm`, `@struct_def`, `@imp`) extract symbols. Without `query`, a minimal generic pattern is used — it only matches grammars that define `function_declaration`/`class_declaration` node types, and query compilation fails silently (0 symbols) for grammars that lack them, so a custom query is effectively required for most languages. Once registered, `smart_outline` and `smart_unfold` parse those extensions structurally instead of falling back to plain text.

### Markdown Special Support

Markdown files (`.md`, `.mdx`) receive special handling beyond the generic plain-text fallback:

- **`smart_outline`** — extracts headings (`#`, `##`, `###`) as the symbol tree. Use it to navigate long documents without reading the full file.
- **`smart_search`** — searches within code fences as well as prose, so queries for function names inside ` ```ts ``` ` blocks work as expected.
- **`smart_unfold`** — expands heading sections rather than function bodies; each section up to the next same-level heading is returned as a chunk.
- **Frontmatter** — YAML frontmatter (lines between leading `---` delimiters) is included in `smart_outline` output under a synthetic `frontmatter` symbol so metadata like `title:` and `description:` is visible without reading the whole file.

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
mcp: mcp-search/smart_search started
hook: PermissionRequest
hook: PermissionRequest Completed
mcp: mcp-search/smart_search (failed)
user cancelled MCP tool call
codex
구조 검색 도구 호출이 취소되어 저장소의 읽기 전용 Git/텍스트 명령으로 전환합니다. 검토 범위나 증거 기준에는 영향이 없으며, 모든 지적은 현재 커밋의 정확한 줄 번호에 고정하겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'git status --short && git show --stat --oneline 546344b && git show --format= --name-only 546344b' in /Users/sunghoon/Projects/docpack
 succeeded in 24ms:
546344b feat(safe): JP-1 alpha — Japanese document presets, purpose gate, band-only masking
 .gitignore                                         |    7 +
 CLAUDE.md                                          |   90 +
 docs/jp/codex_prompt.md                            |    9 +
 docs/jp/codex_review_2026-10-21.md                 | 1924 ++++++++++++++++++++
 docs/jp/jp_documents_catalog.json                  |   95 +
 docs/jp/jp_safefile_strategy_2026-10-20.md         |  175 ++
 docs/jp/jp_safefile_strategy_v2_2026-10-21.md      |  191 ++
 docs/jp/s3_golden_result.md                        |  589 ++++++
 docs/jp/s3_report.md                               |  338 ++++
 public/safe/index.html                             |  893 ++++++++-
 test/safe/README.md                                |   81 +-
 test/safe/fixtures/jp/README.md                    |   43 +
 test/safe/fixtures/jp/gen.py                       |  214 +++
 test/safe/fixtures/jp/jp_legal_matrix_alpha4.json  |   62 +
 test/safe/fixtures/jp/juminhyo/gaikokujin.jpg      |  Bin 0 -> 150558 bytes
 test/safe/fixtures/jp/juminhyo/gaikokujin.pdf      |   79 +
 test/safe/fixtures/jp/juminhyo/gaikokujin.png      |  Bin 0 -> 379659 bytes
 .../fixtures/jp/juminhyo/gaikokujin.specs.json     |  102 ++
 test/safe/fixtures/jp/juminhyo/honseki_on.jpg      |  Bin 0 -> 144256 bytes
 test/safe/fixtures/jp/juminhyo/honseki_on.pdf      |   79 +
 test/safe/fixtures/jp/juminhyo/honseki_on.png      |  Bin 0 -> 364680 bytes
 .../fixtures/jp/juminhyo/honseki_on.specs.json     |   95 +
 test/safe/fixtures/jp/juminhyo/ichibu_plain.jpg    |  Bin 0 -> 141753 bytes
 test/safe/fixtures/jp/juminhyo/ichibu_plain.pdf    |   79 +
 test/safe/fixtures/jp/juminhyo/ichibu_plain.png    |  Bin 0 -> 354262 bytes
 .../fixtures/jp/juminhyo/ichibu_plain.specs.json   |   78 +
 test/safe/fixtures/jp/juminhyo/zenin_mynumber.jpg  |  Bin 0 -> 186391 bytes
 test/safe/fixtures/jp/juminhyo/zenin_mynumber.pdf  |   79 +
 test/safe/fixtures/jp/juminhyo/zenin_mynumber.png  |  Bin 0 -> 445840 bytes
 .../fixtures/jp/juminhyo/zenin_mynumber.specs.json |  230 +++
 test/safe/fixtures/jp/mynumber_card/back.jpg       |  Bin 0 -> 70108 bytes
 test/safe/fixtures/jp/mynumber_card/back.pdf       |   79 +
 test/safe/fixtures/jp/mynumber_card/back.png       |  Bin 0 -> 205908 bytes
 .../safe/fixtures/jp/mynumber_card/back.specs.json |   54 +
 test/safe/fixtures/jp/mynumber_card/front.jpg      |  Bin 0 -> 77758 bytes
 test/safe/fixtures/jp/mynumber_card/front.pdf      |   79 +
 test/safe/fixtures/jp/mynumber_card/front.png      |  Bin 0 -> 213113 bytes
 .../fixtures/jp/mynumber_card/front.specs.json     |   72 +
 test/safe/fixtures/jp/shikaku_kakuninsho/kenpo.jpg |  Bin 0 -> 84735 bytes
 test/safe/fixtures/jp/shikaku_kakuninsho/kenpo.pdf |   79 +
 test/safe/fixtures/jp/shikaku_kakuninsho/kenpo.png |  Bin 0 -> 233815 bytes
 .../jp/shikaku_kakuninsho/kenpo.specs.json         |  119 ++
 .../safe/fixtures/jp/shikaku_kakuninsho/kokuho.jpg |  Bin 0 -> 83924 bytes
 .../safe/fixtures/jp/shikaku_kakuninsho/kokuho.pdf |   79 +
 .../safe/fixtures/jp/shikaku_kakuninsho/kokuho.png |  Bin 0 -> 226721 bytes
 .../jp/shikaku_kakuninsho/kokuho.specs.json        |  113 ++
 test/safe/fixtures/jp/shikaku_kakuninsho/kouki.jpg |  Bin 0 -> 84181 bytes
 test/safe/fixtures/jp/shikaku_kakuninsho/kouki.pdf |   79 +
 test/safe/fixtures/jp/shikaku_kakuninsho/kouki.png |  Bin 0 -> 233773 bytes
 .../jp/shikaku_kakuninsho/kouki.specs.json         |  101 +
 test/safe/fixtures/jp/unten_menkyo/back.jpg        |  Bin 0 -> 82146 bytes
 test/safe/fixtures/jp/unten_menkyo/back.pdf        |   79 +
 test/safe/fixtures/jp/unten_menkyo/back.png        |  Bin 0 -> 218850 bytes
 test/safe/fixtures/jp/unten_menkyo/back.specs.json |   35 +
 test/safe/fixtures/jp/unten_menkyo/front.jpg       |  Bin 0 -> 78601 bytes
 test/safe/fixtures/jp/unten_menkyo/front.pdf       |   79 +
 test/safe/fixtures/jp/unten_menkyo/front.png       |  Bin 0 -> 225041 bytes
 .../safe/fixtures/jp/unten_menkyo/front.specs.json |   76 +
 test/safe/package-lock.json                        |   42 +
 test/safe/render.mjs                               |   68 +
 test/safe/run.mjs                                  |  203 ++-
 test/safe/specs.json                               |   95 +
 test/sw/README.md                                  |   13 +-
 63 files changed, 7049 insertions(+), 27 deletions(-)
.gitignore
CLAUDE.md
docs/jp/codex_prompt.md
docs/jp/codex_review_2026-10-21.md
docs/jp/jp_documents_catalog.json
docs/jp/jp_safefile_strategy_2026-10-20.md
docs/jp/jp_safefile_strategy_v2_2026-10-21.md
docs/jp/s3_golden_result.md
docs/jp/s3_report.md
public/safe/index.html
test/safe/README.md
test/safe/fixtures/jp/README.md
test/safe/fixtures/jp/gen.py
test/safe/fixtures/jp/jp_legal_matrix_alpha4.json
test/safe/fixtures/jp/juminhyo/gaikokujin.jpg
test/safe/fixtures/jp/juminhyo/gaikokujin.pdf
test/safe/fixtures/jp/juminhyo/gaikokujin.png
test/safe/fixtures/jp/juminhyo/gaikokujin.specs.json
test/safe/fixtures/jp/juminhyo/honseki_on.jpg
test/safe/fixtures/jp/juminhyo/honseki_on.pdf
test/safe/fixtures/jp/juminhyo/honseki_on.png
test/safe/fixtures/jp/juminhyo/honseki_on.specs.json
test/safe/fixtures/jp/juminhyo/ichibu_plain.jpg
test/safe/fixtures/jp/juminhyo/ichibu_plain.pdf
test/safe/fixtures/jp/juminhyo/ichibu_plain.png
test/safe/fixtures/jp/juminhyo/ichibu_plain.specs.json
test/safe/fixtures/jp/juminhyo/zenin_mynumber.jpg
test/safe/fixtures/jp/juminhyo/zenin_mynumber.pdf
test/safe/fixtures/jp/juminhyo/zenin_mynumber.png
test/safe/fixtures/jp/juminhyo/zenin_mynumber.specs.json
test/safe/fixtures/jp/mynumber_card/back.jpg
test/safe/fixtures/jp/mynumber_card/back.pdf
test/safe/fixtures/jp/mynumber_card/back.png
test/safe/fixtures/jp/mynumber_card/back.specs.json
test/safe/fixtures/jp/mynumber_card/front.jpg
test/safe/fixtures/jp/mynumber_card/front.pdf
test/safe/fixtures/jp/mynumber_card/front.png
test/safe/fixtures/jp/mynumber_card/front.specs.json
test/safe/fixtures/jp/shikaku_kakuninsho/kenpo.jpg
test/safe/fixtures/jp/shikaku_kakuninsho/kenpo.pdf
test/safe/fixtures/jp/shikaku_kakuninsho/kenpo.png
test/safe/fixtures/jp/shikaku_kakuninsho/kenpo.specs.json
test/safe/fixtures/jp/shikaku_kakuninsho/kokuho.jpg
test/safe/fixtures/jp/shikaku_kakuninsho/kokuho.pdf
test/safe/fixtures/jp/shikaku_kakuninsho/kokuho.png
test/safe/fixtures/jp/shikaku_kakuninsho/kokuho.specs.json
test/safe/fixtures/jp/shikaku_kakuninsho/kouki.jpg
test/safe/fixtures/jp/shikaku_kakuninsho/kouki.pdf
test/safe/fixtures/jp/shikaku_kakuninsho/kouki.png
test/safe/fixtures/jp/shikaku_kakuninsho/kouki.specs.json
test/safe/fixtures/jp/unten_menkyo/back.jpg
test/safe/fixtures/jp/unten_menkyo/back.pdf
test/safe/fixtures/jp/unten_menkyo/back.png
test/safe/fixtures/jp/unten_menkyo/back.specs.json
test/safe/fixtures/jp/unten_menkyo/front.jpg
test/safe/fixtures/jp/unten_menkyo/front.pdf
test/safe/fixtures/jp/unten_menkyo/front.png
test/safe/fixtures/jp/unten_menkyo/front.specs.json
test/safe/package-lock.json
test/safe/render.mjs
test/safe/run.mjs
test/safe/specs.json
test/sw/README.md

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'git rev-parse --short HEAD && git diff -- public/safe/index.html test/safe/run.mjs test/safe/specs.json docs/jp/jp_safefile_strategy_v2_2026-10-21.md docs/jp/s3_report.md docs/jp/s3_golden_result.md test/safe/fixtures/jp/jp_legal_matrix_alpha4.json && rg -n "function (jpNorm|jpSegments|jpClassify|jpExtract|jpFrameBelow|jpCodeBlocks|jpSolidSquares|jpAddressSpan|myNumberCheckOk|jpLevel|jpApply|bandRect|drawRedactions|ocrCanvas)|const (JP_RULES|JP_SEG_GAP|JP_TYPE)|jpScan" public/safe/index.html' in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
0238cbb
1081:function jpNorm(s){
1115:const JP_SEG_GAP = p => Math.max(90, p.w * 0.10);
1123:function jpSegments(pi){
1185:function jpClassify(pi){
1205:function myNumberCheckOk(d12){
1252:function jpFrameBelow(page, anchor){
1283:function jpCodeBlocks(pi){
1334:function jpSolidSquares(page, pi){
1388:const JP_RULES = {
1433:function jpLevel(doc, field, purpose){
1542:function jpAddressSpan(t, from){
1598:function jpExtract(pi, cls){
1778:function jpScan(){
1796:function jpApply(){
1835:const JP_TYPE = { address_loose:'address', tel:'phone', my_number:'rrn', jumin_code:'rrn', hokensha_bango:'health', kigo:'health',
2092:async function ocrCanvas(cv){
2151:    const jp = jpScan();
2292:function bandRect(l){
2324:function drawRedactions(ctx,pi,scale){

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'git diff --stat 546344b..HEAD -- public/safe/index.html test/safe/run.mjs test/safe/specs.json docs/jp/jp_safefile_strategy_v2_2026-10-21.md docs/jp/s3_report.md docs/jp/s3_golden_result.md test/safe/fixtures/jp && git diff --numstat 546344b..HEAD -- public/safe/index.html test/safe/run.mjs test/safe/specs.json' in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
 public/safe/index.html | 10 +++++++---
 1 file changed, 7 insertions(+), 3 deletions(-)
7	3	public/safe/index.html

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "git show 546344b:public/safe/index.html | nl -ba | sed -n '1060,1865p'" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
  1060	     (1) the page classifies as one of the four alpha document types,
  1061	     (2) a label anchor in the same visual row — or one documented, narrower
  1062	         structural fallback for the case where OCR destroyed the label,
  1063	     (3) the value matches the field's format (and, for 個人番号, its check digit).
  1064	   Everything short of that surfaces as a review candidate instead.
  1065	   The asymmetry is deliberate: a missed 保険者番号 is the exact harm the
  1066	   product exists to prevent, while a wrongly banded 氏名 gets the submission
  1067	   rejected — so automatic banding is confined to the fields the legal matrix
  1068	   says may be hidden for the selected purpose. */
  1069	
  1070	/* ── normalisation with index preservation ──
  1071	   Boxes come from item/char indices, so normalisation must never lose the way
  1072	   back to the source character. Each SOURCE character is normalised on its own
  1073	   (never a whole string), so NFKC can expand 1→n but can never combine n→1 and
  1074	   silently drop a source index. Folds that are not 1:1 are simply not applied. */
  1075	const JP_VARIANT = {'髙':'高','﨑':'崎','邊':'辺','邉':'辺'};
  1076	const JP_DASH = new Set(['ー','−','―','‐','—','－','ｰ','‑','–','_']);
  1077	const JP_ZERO = new Set(['〇','○','◯']);
  1078	const JP_ONE  = new Set(['l','I','|','ｌ','Ｉ','丨']);
  1079	const isDigit = c => c >= '0' && c <= '9';
  1080	// Returns {t, src} — t[k] is the k-th normalised char, src[k] its index in `s`.
  1081	function jpNorm(s){
  1082	  let t = '', src = [];
  1083	  for (let i = 0; i < (s||'').length; i++){
  1084	    let o = s[i];
  1085	    try { o = o.normalize('NFKC'); } catch(e){}
  1086	    if (o.length !== 1) { // expansion: every output char points back at this source char
  1087	      for (const c of o) { t += (JP_VARIANT[c] || c); src.push(i); }
  1088	      continue;
  1089	    }
  1090	    t += (JP_VARIANT[o] || o); src.push(i);
  1091	  }
  1092	  // Context-sensitive OCR folds, applied in place so the map stays valid.
  1093	  // ー→- unconditionally would wreck katakana (コード→コ-ド) and with it the
  1094	  // 二次元コード label anchor, so these only fire next to a digit.
  1095	  const a = t.split('');
  1096	  for (let k = 0; k < a.length; k++){
  1097	    const p = a[k-1], n = a[k+1];
  1098	    const nearDigit = (p && isDigit(p)) || (n && isDigit(n));
  1099	    if (JP_DASH.has(a[k]) && nearDigit) a[k] = '-';
  1100	    else if (JP_ZERO.has(a[k]) && nearDigit) a[k] = '0';
  1101	    else if (JP_ONE.has(a[k]) && p && n && isDigit(p) && isDigit(n)) a[k] = '1';
  1102	  }
  1103	  return { t: a.join(''), src };
  1104	}
  1105	
  1106	/* ── row / segment model ──
  1107	   These documents are label-value forms: the label sits left of its value on
  1108	   the same visual row, and several label-value pairs share a row in separate
  1109	   columns. So we group items into rows, then split each row into SEGMENTS at
  1110	   horizontal gaps. The gap threshold has to be wider than a label→value gap
  1111	   (~80px at this scale) and narrower than a column→column gap (~140px);
  1112	   10% of page width sits between them for every alpha fixture.
  1113	   `rowText` keeps the WHOLE visual line, because date context ("年月日") has to
  1114	   be judged per line, not per column. */
  1115	const JP_SEG_GAP = p => Math.max(90, p.w * 0.10);
  1116	function jpPushItem(seg, o){
  1117	  const n = jpNorm(o.it.str || '');
  1118	  seg.start[o.i] = seg.t.length;              // where this item's chars begin in seg.t
  1119	  for (let k = 0; k < n.t.length; k++){ seg.t += n.t[k]; seg.map.push([o.i, n.src[k]]); }
  1120	  seg.x1 = Math.max(seg.x1, o.it.x + o.it.w);
  1121	  seg.items.push(o);
  1122	}
  1123	function jpSegments(pi){
  1124	  const page = pages[pi];
  1125	  if (page._jpsegs) return page._jpsegs;
  1126	  const arr = page.items.map((it,i)=>({it,i})).sort((a,b)=>a.it.y-b.it.y||a.it.x-b.it.x);
  1127	  const rows = []; let row = null;
  1128	  for (const o of arr){
  1129	    if (row && Math.abs(o.it.y - row.y) < row.h * 0.7){ row.list.push(o); row.h = Math.max(row.h, o.it.h); }
  1130	    else { if (row) rows.push(row); row = { y:o.it.y, h:o.it.h, list:[o] }; }
  1131	  }
  1132	  if (row) rows.push(row);
  1133	  const gapT = JP_SEG_GAP(page), segs = [];
  1134	  rows.forEach((r, ri) => {
  1135	    r.list.sort((a,b)=>a.it.x-b.it.x);
  1136	    let rowText = ''; for (const o of r.list) rowText += jpNorm(o.it.str||'').t;
  1137	    const y0 = Math.min(...r.list.map(o=>o.it.y)), y1 = Math.max(...r.list.map(o=>o.it.y+o.it.h));
  1138	    let seg = null;
  1139	    const open = o => ({ pi, row:ri, rowText, y:y0, h:y1-y0, x0:o.it.x, x1:o.it.x, t:'', map:[], items:[], used:[], start:{} });
  1140	    for (const o of r.list){
  1141	      if (seg && o.it.x - seg.x1 < gapT) jpPushItem(seg, o);
  1142	      else { if (seg) segs.push(seg); seg = open(o); jpPushItem(seg, o); }
  1143	    }
  1144	    if (seg) segs.push(seg);
  1145	  });
  1146	  return (page._jpsegs = segs);
  1147	}
  1148	// Boxes for the normalised-text span [a,b) of a segment, via the char map.
  1149	function jpBoxes(seg, a, b){
  1150	  const out = [];
  1151	  boxesFromRange(pages[seg.pi], seg.pi, seg.map, a, b, out);
  1152	  return out;
  1153	}
  1154	function jpSegBox(seg){
  1155	  const page = pages[seg.pi];
  1156	  const b = { page: seg.pi, x: seg.x0, y: seg.y, w: seg.x1 - seg.x0, h: seg.h };
  1157	  b.bg = sampleBg(page, b);
  1158	  return b;
  1159	}
  1160	
  1161	/* ── document classification ──
  1162	   Weighted keyword vote over the whole page's normalised text. Weights express
  1163	   how exclusive a term is to that document: 資格確認書 appears on nothing else,
  1164	   while 本籍 also appears on 戸籍 documents. The threshold is deliberately a
  1165	   SUM, not a single magic keyword, because OCR reliably destroys some share of
  1166	   any given line — on the alpha fixtures the garbled labels are never the same
  1167	   ones twice. Below threshold the page is "一般文書" and NO Japanese automatic
  1168	   masking happens at all. */
  1169	const JP_CLASSES = {
  1170	  shikaku_kakuninsho: { min: 4, kw: [['資格確認書',3],['保険者番号',2],['被保険者',2],['保険者名',2],
  1171	      ['国民健康保険',2],['後期高齢者',2],['枝番',2],['記号',1],['健康保険',1],['一部負担金',1]] },
  1172	  unten_menkyo: { min: 4, kw: [['運転免許証',4],['免許証',2],['公安委員会',2],['備考欄',2],
  1173	      ['臓器提供',1],['提供意思',1],['優良',1],['原付',1]] },
  1174	  mynumber_card: { min: 4, kw: [['個人番号カード',4],['マイナンバーカード',4],['個人番号',2],
  1175	      ['券面記載事項',2],['マイナンバー',2]] },
  1176	  juminhyo: { min: 4, kw: [['住民票',3],['世帯主',2],['続柄',2],['筆頭者',2],['世帯全員',2],
  1177	      ['住民となった日',2],['住民票コード',2],['本籍',1],['住民となつた日',2]] },
  1178	};
  1179	function jpPageText(pi){
  1180	  const page = pages[pi];
  1181	  if (page._jptext != null) return page._jptext;
  1182	  let s = ''; for (const it of page.items) s += jpNorm(it.str || '').t;
  1183	  return (page._jptext = s);
  1184	}
  1185	function jpClassify(pi){
  1186	  const txt = jpPageText(pi);
  1187	  let best = null;
  1188	  for (const [id, def] of Object.entries(JP_CLASSES)){
  1189	    let score = 0, hits = [];
  1190	    for (const [k, w] of def.kw) if (txt.includes(k)) { score += w; hits.push(k); }
  1191	    if (score >= def.min && (!best || score > best.score)) best = { doc: id, score, hits };
  1192	  }
  1193	  if (!best) return null;
  1194	  // Side: cards have two faces with completely different legal treatment.
  1195	  if (best.doc === 'mynumber_card' || best.doc === 'unten_menkyo'){
  1196	    best.side = txt.includes('裏面') ? 'back' : txt.includes('表面') ? 'front'
  1197	              : (best.doc === 'mynumber_card' && /\d[\d\s.\-]{10,}\d/.test(txt)) ? 'back' : 'front';
  1198	  }
  1199	  return best;
  1200	}
  1201	
  1202	/* ── 個人番号 check digit (番号法施行令 別表) ──
  1203	   Σ P_n·Q_n over the 11-digit body counted from the RIGHT (n = 1..11),
  1204	   Q_n = n+1 for n ≤ 6 else n−5; check = 11 − (Σ mod 11), and ≥10 → 0. */
  1205	function myNumberCheckOk(d12){
  1206	  if (!/^\d{12}$/.test(d12)) return false;
  1207	  const d = d12.slice(0, 11).split('').map(Number);
  1208	  let s = 0;
  1209	  for (let n = 1; n <= 11; n++){ const q = n <= 6 ? n + 1 : n - 5; s += d[11 - n] * q; }
  1210	  let chk = 11 - (s % 11); if (chk >= 10) chk = 0;
  1211	  return chk === Number(d12[11]);
  1212	}
  1213	
  1214	/* ── pixel helpers for field FRAMES and code blocks ──
  1215	   A 欄 (field box) is drawn as a thin rectangle; its contents may be empty, so
  1216	   there is nothing for a text-based detector to find. Scanning for the drawn
  1217	   rule is the only way to cover 臓器提供意思表示欄 on a card whose box the
  1218	   holder left blank — and a blank-looking box is exactly where a faint
  1219	   handwritten mark hides. */
  1220	function jpPageBg(page){
  1221	  if (page._jpbg) return page._jpbg;
  1222	  const ctx = page.canvas.getContext('2d', { willReadFrequently: true });
  1223	  const W = page.canvas.width, H = page.canvas.height;
  1224	  const pick = [];
  1225	  for (let i = 0; i < 24; i++){
  1226	    const x = Math.round(W * (i % 6 + 0.5) / 6);
  1227	    const y = [2, H - 3, Math.round(H * 0.01), Math.round(H * 0.99)][Math.floor(i / 6)];
  1228	    const d = ctx.getImageData(Math.max(0, Math.min(W-1, x)), Math.max(0, Math.min(H-1, y)), 1, 1).data;
  1229	    pick.push([d[0], d[1], d[2]]);
  1230	  }
  1231	  const med = c => { const s = pick.map(p => p[c]).sort((a,b)=>a-b); return s[s.length >> 1]; };
  1232	  return (page._jpbg = [med(0), med(1), med(2)]);
  1233	}
  1234	function jpRowInk(page, y, bg, thr){
  1235	  const ctx = page.canvas.getContext('2d', { willReadFrequently: true });
  1236	  const W = page.canvas.width;
  1237	  const d = ctx.getImageData(0, y, W, 1).data;
  1238	  let best = null, runStart = -1;
  1239	  for (let x = 0; x <= W; x++){
  1240	    const ink = x < W && (Math.abs(d[x*4] - bg[0]) > thr || Math.abs(d[x*4+1] - bg[1]) > thr || Math.abs(d[x*4+2] - bg[2]) > thr);
  1241	    if (ink){ if (runStart < 0) runStart = x; }
  1242	    else if (runStart >= 0){ const len = x - runStart; if (!best || len > best.len) best = { x0: runStart, x1: x, len }; runStart = -1; }
  1243	  }
  1244	  return best;
  1245	}
  1246	// The drawn rectangle that starts just under `anchor`. Returns null if none.
  1247	// Starting the scan at the anchor's MIDDLE (not its bottom) matters: on the
  1248	// licence back the 備考欄 frame's top rule overlaps the label's own glyph box.
  1249	// Text can never produce a 150px CONTIGUOUS ink run, so the label cannot be
  1250	// mistaken for a rule, and a diagonal watermark stroke cannot either.
  1251	const JP_RULE_MIN = 150, JP_RULE_TOL = 12;
  1252	function jpFrameBelow(page, anchor){
  1253	  const bg = jpPageBg(page), H = page.canvas.height;
  1254	  const y0 = Math.round(anchor.y + anchor.h * 0.5);
  1255	  const yMax = Math.min(H - 1, Math.round(anchor.y + anchor.h * 12));
  1256	  let top = null;
  1257	  for (let y = y0; y <= yMax; y++){
  1258	    const r = jpRowInk(page, y, bg, 40);
  1259	    if (r && r.len >= JP_RULE_MIN){ top = { y, ...r }; break; }
  1260	  }
  1261	  if (!top) return null;
  1262	  for (let y = top.y + 6; y <= yMax; y++){
  1263	    const r = jpRowInk(page, y, bg, 40);
  1264	    if (r && r.len >= JP_RULE_MIN && Math.abs(r.x0 - top.x0) <= JP_RULE_TOL && Math.abs(r.x1 - top.x1) <= JP_RULE_TOL)
  1265	      return { page: pages.indexOf(page), x: top.x0, y: top.y, w: top.x1 - top.x0, h: y - top.y, region: true };
  1266	  }
  1267	  return null;
  1268	}
  1269	/* A 二次元コード block. Two paths, with different confidence:
  1270	   (a) LABELLED — the page says 二次元コード / QR near it. The block is the
  1271	       cluster of items around that label, squared up. Verified by the golden.
  1272	   (b) UNLABELLED — a solid, near-square, high-fill block of non-background
  1273	       pixels. This is what a real printed QR looks like, but the alpha dummies
  1274	       carry NO real QR (strategy v2 §4 forbids generating one), so this path
  1275	       has no golden coverage. It therefore emits a CANDIDATE, never an
  1276	       automatic band: untested detection must not delete pixels by itself. */
  1277	function jpSquareAround(boxes){
  1278	  const x0 = Math.min(...boxes.map(b=>b.x)), y0 = Math.min(...boxes.map(b=>b.y));
  1279	  const x1 = Math.max(...boxes.map(b=>b.x+b.w)), y1 = Math.max(...boxes.map(b=>b.y+b.h));
  1280	  const side = Math.max(x1-x0, y1-y0), cx = (x0+x1)/2, cy = (y0+y1)/2;
  1281	  return { x: cx - side/2, y: cy - side/2, w: side, h: side };
  1282	}
  1283	function jpCodeBlocks(pi){
  1284	  const page = pages[pi], segs = jpSegments(pi);
  1285	  // 1) Solid, near-square blocks of non-background pixels. This is what a printed
  1286	  //    code BLOCK is, independent of whether anything near it is readable.
  1287	  const blocks = jpSolidSquares(page, pi);
  1288	  const hit = (a,b)=> !(a.x+a.w < b.x || b.x+b.w < a.x || a.y+a.h < b.y || b.y+b.h < a.y);
  1289	  const out = [], usedBlock = blocks.map(()=>false);
  1290	  // 2) Label anchors. A label makes the block's identity CERTAIN, which is what
  1291	  //    lifts it to an automatic band.
  1292	  for (const seg of segs){
  1293	    if (!/二次元コード|次元コード|コード欄|QRコード|ＱＲ/.test(seg.t)) continue;
  1294	    const sb = jpSegBox(seg);
  1295	    const bi = blocks.findIndex(b => hit(b, sb));
  1296	    if (bi >= 0){
  1297	      // Snap to the measured block. The label text sits in one corner of the
  1298	      // block, so a square grown around the TEXT is offset from the block and
  1299	      // leaves a readable strip — 80% of the fixture's code area, which passed a
  1300	      // 60% gate while a real QR stayed decodable. The pixels know better.
  1301	      usedBlock[bi] = true;
  1302	      const g = Math.max(4, blocks[bi].w * 0.04);
  1303	      out.push({ box: { page: pi, x: blocks[bi].x-g, y: blocks[bi].y-g, w: blocks[bi].w+2*g, h: blocks[bi].h+2*g, region: true }, labelled: true });
  1304	      continue;
  1305	    }
  1306	    // No measurable block (a code printed in a light colour, or a frame we
  1307	    // cannot see): fall back to a square around the label's connected cluster.
  1308	    const M = 20;
  1309	    let cl = sb, grew = true;
  1310	    const pool = segs.filter(x => x !== seg && x.pi === pi).map(jpSegBox);
  1311	    const taken = pool.map(()=>false);
  1312	    const touches = (a,b)=> !(a.x+a.w < b.x-M || b.x+b.w < a.x-M || a.y+a.h < b.y-M || b.y+b.h < a.y-M);
  1313	    while (grew){
  1314	      grew = false;
  1315	      pool.forEach((b,k)=>{
  1316	        if (taken[k] || !touches(cl,b)) return;
  1317	        taken[k] = true; grew = true;
  1318	        const x1=Math.max(cl.x+cl.w,b.x+b.w), y1=Math.max(cl.y+cl.h,b.y+b.h);
  1319	        cl = { x:Math.min(cl.x,b.x), y:Math.min(cl.y,b.y), w:0, h:0 };
  1320	        cl.w = x1-cl.x; cl.h = y1-cl.y;
  1321	      });
  1322	    }
  1323	    const sq = jpSquareAround([cl]), g = sq.w * 0.1;
  1324	    out.push({ box: { page: pi, x: sq.x-g, y: sq.y-g, w: sq.w+2*g, h: sq.h+2*g, region: true }, labelled: true });
  1325	  }
  1326	  // 3) Blocks with no label: see the note above — detection without golden
  1327	  //    coverage emits a candidate, never an automatic band.
  1328	  blocks.forEach((b,k)=>{ if (!usedBlock[k]) out.push({ box: { page: pi, ...b, region: true }, labelled: false }); });
  1329	  return out;
  1330	}
  1331	// Connected components of "solidly non-background" 16px cells that are big,
  1332	// near-square and well filled. A diagonal watermark stroke is thin, so its cells
  1333	// never reach the 0.6 density floor; body text never reaches the 0.75 fill.
  1334	function jpSolidSquares(page, pi){
  1335	  const bg = jpPageBg(page), W = page.canvas.width, H = page.canvas.height;
  1336	  const CELL = 16, gw = Math.floor(W / CELL), gh = Math.floor(H / CELL);
  1337	  const ctx = page.canvas.getContext('2d', { willReadFrequently: true });
  1338	  const dense = [];
  1339	  for (let gy = 0; gy < gh; gy++){
  1340	    dense.push([]);
  1341	    for (let gx = 0; gx < gw; gx++){
  1342	      const d = ctx.getImageData(gx*CELL, gy*CELL, CELL, CELL).data;
  1343	      let ink = 0;
  1344	      for (let k = 0; k < CELL*CELL; k++){
  1345	        if (Math.abs(d[k*4]-bg[0]) > 40 || Math.abs(d[k*4+1]-bg[1]) > 40 || Math.abs(d[k*4+2]-bg[2]) > 40) ink++;
  1346	      }
  1347	      dense[gy].push(ink / (CELL*CELL) >= 0.6);
  1348	    }
  1349	  }
  1350	  const seen = dense.map(r => r.map(()=>false)), out = [];
  1351	  for (let gy = 0; gy < gh; gy++) for (let gx = 0; gx < gw; gx++){
  1352	    if (!dense[gy][gx] || seen[gy][gx]) continue;
  1353	    const st = [[gy,gx]]; let minx=gx,maxx=gx,miny=gy,maxy=gy,n=0;
  1354	    seen[gy][gx] = true;
  1355	    while (st.length){
  1356	      const [y,x] = st.pop(); n++;
  1357	      minx=Math.min(minx,x); maxx=Math.max(maxx,x); miny=Math.min(miny,y); maxy=Math.max(maxy,y);
  1358	      for (const [dy,dx] of [[1,0],[-1,0],[0,1],[0,-1]]){
  1359	        const ny=y+dy, nx=x+dx;
  1360	        if (ny>=0&&ny<gh&&nx>=0&&nx<gw&&dense[ny][nx]&&!seen[ny][nx]){ seen[ny][nx]=true; st.push([ny,nx]); }
  1361	      }
  1362	    }
  1363	    const bw = maxx-minx+1, bh = maxy-miny+1, ar = bw/bh, fill = n/(bw*bh);
  1364	    if (bw*CELL >= 60 && bh*CELL >= 60 && ar >= 0.8 && ar <= 1.25 && fill >= 0.75)
  1365	      out.push({ page: pi, x: minx*CELL, y: miny*CELL, w: bw*CELL, h: bh*CELL });
  1366	  }
  1367	  return out;
  1368	}
  1369	
  1370	/* ── legal matrix, as code ──
  1371	   Mirrors test/safe/fixtures/jp/jp_legal_matrix_alpha4.json. Levels:
  1372	     auto      文書分類+ラベル一致で自動黒塗り
  1373	     gate      目的選択後に自動（別目的では解除）= auto_with_purpose_gate
  1374	     recommend 既定ON・解除可
  1375	     optional  既定OFF・選択可
  1376	     keep      黒塗り禁止（警告）
  1377	   Two documented deviations from the JSON, both widening what may be hidden:
  1378	   本籍/筆頭者 also carry `recommend` for my_number_procedure and bid_attachment
  1379	   (the 本籍 is not part of a 個人番号 or tender filing either), matching the
  1380	   fixture expectations. */
  1381	const P_ALL = ['identity_submit','my_number_procedure','bid_attachment','consult_share'];
  1382	const P_NOT_MYNUM = ['identity_submit','bid_attachment','consult_share'];
  1383	// Shared by all four documents: neither a free-standing address nor a phone
  1384	// number is part of what any of them has to prove, so both are always OFFERED —
  1385	// and recommended when the point of sharing is advice, not identification.
  1386	const JP_EXTRA = { address_loose: { recommend: ['consult_share'], optional: P_ALL },
  1387	                   tel:           { recommend: ['consult_share'], optional: P_ALL } };
  1388	const JP_RULES = {
  1389	  shikaku_kakuninsho: {
  1390	    // 健康保険法等 告知要求制限 (2020-10-01) — mhlw.go.jp/stf/newpage_13989.html
  1391	    hokensha_bango:   { auto: P_NOT_MYNUM },
  1392	    kigo:             { auto: P_NOT_MYNUM },
  1393	    bango:            { auto: P_NOT_MYNUM },
  1394	    edaban:           { auto: P_NOT_MYNUM },
  1395	    hihokensha_bango: { auto: P_NOT_MYNUM },
  1396	    // QRは番号を判読可能なため同一扱い（大阪府・千葉市運用）
  1397	    qr:               { auto: P_NOT_MYNUM },
  1398	    // 法定ではない。民間KYC運用（SoftBank, PayPay銀行等）
  1399	    sex:              { recommend: ['identity_submit'] },
  1400	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL},
  1401	    jigyosho:{keep:P_ALL}, hokensha_name:{keep:P_ALL}, shikaku_date:{keep:P_ALL},
  1402	    ...JP_EXTRA,
  1403	  },
  1404	  unten_menkyo: {
  1405	    biko_change:  { recommend: ['identity_submit','consult_share'] },
  1406	    organ_donor:  { recommend: ['identity_submit','consult_share'] },
  1407	    // 個人識別符号だが、KYCでは照合に必要な提出先が多い → 既定OFF
  1408	    license_no:   { optional: P_ALL },
  1409	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL}, issue:{keep:P_ALL},
  1410	    ...JP_EXTRA,
  1411	  },
  1412	  mynumber_card: {
  1413	    // 番号法: 法令で認められた者・目的以外での個人番号の収集・保管禁止
  1414	    back_all:   { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1415	    my_number:  { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1416	    qr:         { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1417	    sex:        { recommend: ['identity_submit'] },
  1418	    organ_donor:{ recommend: ['identity_submit'] },
  1419	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL},
  1420	    ...JP_EXTRA,
  1421	  },
  1422	  juminhyo: {
  1423	    my_number:  { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1424	    // 住民基本台帳法 利用制限（個人識別符号）
  1425	    jumin_code: { auto: P_NOT_MYNUM },
  1426	    honseki:    { recommend: P_ALL },
  1427	    hittosha:   { recommend: P_ALL },
  1428	    setaiin:    { recommend: ['identity_submit','consult_share'] },
  1429	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, issuer:{keep:P_ALL},
  1430	    ...JP_EXTRA,
  1431	  },
  1432	};
  1433	function jpLevel(doc, field, purpose){
  1434	  const r = (JP_RULES[doc] || {})[field];
  1435	  if (!r) return null;
  1436	  for (const lv of ['auto','gate','recommend','optional','keep'])
  1437	    if (r[lv] && r[lv].includes(purpose)) return lv;
  1438	  // A field the matrix knows but this purpose does not list is simply available,
  1439	  // never silently promoted to automatic.
  1440	  return r.keep ? 'optional' : 'optional';
  1441	}
  1442	
  1443	/* ── field extraction ─────────────────────────────────────────────────────
  1444	   Each rule is {field, labels[], re, last} — `labels` are the anchors accepted
  1445	   in the segment (several spellings, because OCR drops or swaps one character
  1446	   of a label far more often than it mangles a digit run), `re` is the value
  1447	   format, and `last` allows falling back to the segment's final item when the
  1448	   value itself was garbled but its POSITION is still certain (e.g. 性別 whose
  1449	   single kanji OCR read as "&" — the box is what we need, not the character). */
  1450	const JP_FIELD_RULES = {
  1451	  shikaku_kakuninsho: [
  1452	    { field:'hokensha_bango',   labels:['保険者番号','険者番号','保険者番'], re:/\d{4,10}/ },
  1453	    { field:'hihokensha_bango', labels:['被保険者番号','被保険者等記号','被保険者番'], re:/[0-9A-Z]{4,12}/ },
  1454	    { field:'kigo',   labels:['記号'], re:/[0-9A-Z]{2,12}/ },
  1455	    { field:'edaban', labels:['枝番'], re:/\d{1,3}/ },
  1456	    // 「番号」単独アンカー禁止 — it is a substring of 保険者番号/被保険者番号, so it
  1457	    // only counts when the segment actually STARTS with it (its own column).
  1458	    { field:'bango',  labels:['番号'], re:/[0-9A-Z]{1,12}/, headOnly:true },
  1459	    { field:'sex',    labels:['性別'], re:/[男女]/, last:true },
  1460	    { field:'name',   labels:['氏名'], re:null, last:true },
  1461	    { field:'birth',  labels:['生年月日'], re:null, last:true },
  1462	    { field:'address',labels:['住所'], re:null, last:true, addr:true },
  1463	    { field:'expiry', labels:['有効期限'], re:null, last:true },
  1464	    { field:'tel',    labels:['電話番号','電話','TEL','携帯','FAX'], tel:true },
  1465	  ],
  1466	  // Front-only: the back carries a 住所変更 line inside 備考欄, and calling that
  1467	  // a keep-field would contradict the very region we are hiding.
  1468	  unten_menkyo: [
  1469	    { field:'license_no', labels:['番号'], re:/第?\s?[0-9A-Z]{10,14}/, headOnly:true, sides:['front'] },
  1470	    { field:'name',   labels:['氏名'], re:null, last:true, sides:['front'] },
  1471	    { field:'birth',  labels:['生年月日'], re:null, last:true, sides:['front'] },
  1472	    { field:'address',labels:['住所'], re:null, last:true, sides:['front'], addr:true },
  1473	    { field:'expiry', labels:['有効期限'], re:null, last:true, sides:['front'] },
  1474	  ],
  1475	  mynumber_card: [
  1476	    { field:'my_number', labels:['個人番号','マイナンバー'], digits:12 },
  1477	    { field:'sex',    labels:['性別'], re:/[男女]/, last:true, sides:['front'] },
  1478	    { field:'name',   labels:['氏名'], re:null, last:true },
  1479	    { field:'birth',  labels:['生年月日'], re:null, last:true },
  1480	    { field:'address',labels:['住所'], re:null, last:true, sides:['front'], addr:true },
  1481	    { field:'expiry', labels:['有効期限'], re:null, last:true, sides:['front'] },
  1482	  ],
  1483	  juminhyo: [
  1484	    { field:'my_number', labels:['個人番号','マイナンバー'], digits:12 },
  1485	    { field:'jumin_code',labels:['住民票コード'], digits:11 },
  1486	    { field:'honseki',  labels:['本籍'], re:null, last:true, addr:true },
  1487	    { field:'hittosha', labels:['筆頭者'], re:null, last:true },
  1488	    { field:'name',   labels:['氏名'], re:null, last:true },
  1489	    { field:'birth',  labels:['生年月日'], re:null, last:true },
  1490	    { field:'address',labels:['住所'], re:null, last:true, addr:true },
  1491	    { field:'tel',    labels:['電話番号','電話','TEL','携帯','FAX'], tel:true },
  1492	  ],
  1493	};
  1494	// Field boxes marked as 欄/regions rather than values.
  1495	const JP_REGION_LABELS = {
  1496	  unten_menkyo: [
  1497	    { field:'biko_change', labels:['備考欄','備考'] },
  1498	    { field:'organ_donor', labels:['臓器提供','提供意思','意思表示欄'] },
  1499	  ],
  1500	  mynumber_card: [
  1501	    { field:'organ_donor', labels:['臓器提供','提供意思','意思表示欄'] },
  1502	  ],
  1503	};
  1504	const JP_DATE_RE = /[年月日]/;
  1505	
  1506	/* ── 住所 hierarchy ──────────────────────────────────────────────────────────
  1507	   郵便番号 → 都道府県 → 市区郡町村 → 町域 → 丁目番地号 → 建物, scored rather than
  1508	   matched as one regex, because a Japanese address is a sequence of optional
  1509	   layers and any single regex either demands them all (misses most real
  1510	   addresses) or demands none (matches every company name ending in 市).
  1511	
  1512	   The span is ANCHORED on a 郵便番号 or a real prefecture from the 47-name list.
  1513	   An invented head like 「架空県」 therefore cannot anchor one — which is exactly
  1514	   what keeps 「架空県後期高齢者医療広域連合」 (a 保険者名) and 「見本市長 架空 太郎」
  1515	   (the issuing mayor) out. Requiring the prefecture misses addresses that omit
  1516	   it, which is common in Japan; for the alpha that trade is deliberate, since a
  1517	   wrongly banded issuer is a rejected submission.
  1518	
  1519	   Institution words are a PENALTY, not an exclusion (strategy v2 §3-2): a real
  1520	   address can legitimately contain 「…市役所前」, so the word lowers the score
  1521	   instead of vetoing the span. */
  1522	const JP_PREFS = ['北海道','青森県','岩手県','宮城県','秋田県','山形県','福島県','茨城県','栃木県','群馬県','埼玉県','千葉県','東京都','神奈川県','新潟県','富山県','石川県','福井県','山梨県','長野県','岐阜県','静岡県','愛知県','三重県','滋賀県','京都府','大阪府','兵庫県','奈良県','和歌山県','鳥取県','島根県','岡山県','広島県','山口県','徳島県','香川県','愛媛県','高知県','福岡県','佐賀県','長崎県','熊本県','大分県','宮崎県','鹿児島県','沖縄県'];
  1523	const JP_POSTAL_RE = /〒?\d{3}-\d{4}/;
  1524	const JP_CITY_RE = /^.{1,8}?[市区郡町村]/;
  1525	// 丁目/番地/番/号 accept 漢数字 一〜十・百・千 as well as digits (official
  1526	// 住民票 printouts still use them, and OCR reads them as kanji, not digits).
  1527	const JP_NUM = '(?:[0-9]{1,4}|[一二三四五六七八九十百千]{1,6})';
  1528	// The numeric tail has to be anchored on a TERMINATOR, not just on "a numeral".
  1529	// A lazy prefix followed by a bare numeral stops at the first numeral-looking
  1530	// kanji in a place name — 「三条通一丁目二番三号」 matched just 「三」 — and a
  1531	// fixed 丁目/番/号 sequence misses the hyphenated form 「霞が関1-3-2」 entirely.
  1532	// So: skip forward to the first position where NUM is followed by one of
  1533	// 丁目/番地/番/号/-, then repeat that pair greedily.
  1534	const JP_SEP = '(?:丁目|番地|番|号|[-－])';
  1535	const JP_BANCHI_RE = new RegExp(`^.{0,14}?${JP_NUM}${JP_SEP}(?:の?${JP_NUM}${JP_SEP})*(?:の?${JP_NUM})?号?`);
  1536	const JP_INSTITUTION_RE = /市役所|区役所|町役場|村役場|株式会社|有限会社|合同会社|大学|学校|病院|診療所|協会|広域連合|組合|銀行|支店|連合会|振興局/;
  1537	// Finds an address starting at or after `from`. Returns {a,b,score,postal,pref}.
  1538	function jpAddressSpan(t, from){
  1539	  let a = -1, score = 0, postal = false, pref = '';
  1540	  const pm = JP_POSTAL_RE.exec(t.slice(from));
  1541	  for (const p of JP_PREFS){
  1542	    const i = t.indexOf(p, from);
  1543	    if (i >= 0 && (a < 0 || i < a)) { a = i; pref = p; }
  1544	  }
  1545	  if (pm && (a < 0 || from + pm.index < a)) { a = from + pm.index; postal = true; }
  1546	  if (a < 0) return null;
  1547	  if (postal) score += 2;
  1548	  let b = a;
  1549	  if (postal) b = a + (pm ? pm[0].length : 0);
  1550	  if (pref){
  1551	    const pi = t.indexOf(pref, a);
  1552	    if (pi >= 0){ score += 2; b = Math.max(b, pi + pref.length); }
  1553	  }
  1554	  const city = JP_CITY_RE.exec(t.slice(b));
  1555	  if (city){ score += 1; b += city[0].length; }
  1556	  const ban = JP_BANCHI_RE.exec(t.slice(b));
  1557	  if (ban && ban[0].length && /[0-9一二三四五六七八九十百千]/.test(ban[0])){ score += 2; b += ban[0].length; }
  1558	  // The penalty looks a little PAST the span, because the shape it is meant to
  1559	  // catch is a city match swallowing the head of an institution name
  1560	  // (「大阪府見本市」+「役所」). −2, not a veto: a complete address scores 5 and
  1561	  // survives at 3 (a candidate), while a partial one falls under the floor.
  1562	  if (JP_INSTITUTION_RE.test(t.slice(a, Math.min(t.length, b + 8)))) score -= 2;
  1563	  return { a, b, score, postal, pref: !!pref };
  1564	}
  1565	
  1566	/* ── 電話・FAX ──
  1567	   Anchored on TEL/電話/携帯/FAX; the value must fit the Japanese numbering plan.
  1568	   A hyphenated value is the confirmed shape; an unseparated digit run of the
  1569	   same length is a CANDIDATE, because at that point it is indistinguishable
  1570	   from an account or reference number and only the label suggests otherwise.
  1571	   NOTE: none of the four alpha documents carries a phone number, so this rule
  1572	   has no golden coverage — it is unexercised code until a fixture has one. */
  1573	const JP_TEL_HYPHEN_RE = /0120-\d{3}-\d{3}|0800-\d{3}-\d{4}|0\d{1,4}-\d{1,4}-\d{4}/;
  1574	const JP_TEL_PLAIN_RE = /(?<!\d)0\d{9,10}(?!\d)/;
  1575	function jpFindLabel(seg, labels, headOnly){
  1576	  for (const L of labels){
  1577	    const p = seg.t.indexOf(L);
  1578	    if (p < 0) continue;
  1579	    if (headOnly && p !== 0) continue;
  1580	    return { at: p, end: p + L.length };
  1581	  }
  1582	  return null;
  1583	}
  1584	// Span of the first `n` digits after `from`, tolerating group separators.
  1585	function jpDigitSpan(seg, from, n){
  1586	  let first = -1, last = -1, count = 0;
  1587	  for (let k = from; k < seg.t.length; k++){
  1588	    const c = seg.t[k];
  1589	    if (isDigit(c)){ if (first < 0) first = k; last = k; if (++count === n) return { a:first, b:last+1, digits: seg.t.slice(first,last+1).replace(/\D/g,'') }; }
  1590	    else if (first >= 0 && !/[\s.\-・,/]/.test(c)) { first = -1; last = -1; count = 0; }
  1591	  }
  1592	  return null;
  1593	}
  1594	function jpExtract(pi, cls){
  1595	  const segs = jpSegments(pi), found = [];
  1596	  // Every value rule anchors at the SEGMENT HEAD. In these forms the label always
  1597	  // opens its own column, so a label found mid-segment is prose, not an anchor —
  1598	  // that is how the 「裏面の生年月日有無は…要確認」 footnote on the card dummy got
  1599	  // read as a 生年月日 field. (The 欄 region labels below deliberately do not use
  1600	  // this: OCR puts a garbled 騰 in front of 器提供意思表示欄.)
  1601	  const rules = (JP_FIELD_RULES[cls.doc] || [])
  1602	    .filter(r => !r.sides || r.sides.includes(cls.side))
  1603	    .map(r => ({ ...r, headOnly: true }));
  1604	  const push = (field, boxes, value, extra) => { if (boxes && boxes.length) found.push({ field, boxes, value, pi, ...extra }); };
  1605	
  1606	  for (const seg of segs){
  1607	    for (const r of rules){
  1608	      const L = jpFindLabel(seg, r.labels, r.headOnly);
  1609	      if (!L) continue;
  1610	      if (r.tel){
  1611	        const tail = seg.t.slice(L.end);
  1612	        const hy = JP_TEL_HYPHEN_RE.exec(tail);
  1613	        const pl = hy ? null : JP_TEL_PLAIN_RE.exec(tail);
  1614	        const m = hy || pl;
  1615	        if (!m) continue;
  1616	        const a2 = L.end + m.index, b2 = a2 + m[0].length;
  1617	        push('tel', jpBoxes(seg, a2, b2), m[0], { loose: !hy });
  1618	        for (let k = a2; k < b2; k++) seg.used[k] = 1;
  1619	        continue;
  1620	      }
  1621	      if (r.digits){
  1622	        const sp = jpDigitSpan(seg, L.end, r.digits);
  1623	        if (!sp) continue;
  1624	        const extra = r.field === 'my_number' ? { checkOk: myNumberCheckOk(sp.digits) } : {};
  1625	        push(r.field, jpBoxes(seg, sp.a, sp.b), sp.digits, extra);
  1626	        for (let k = sp.a; k < sp.b; k++) seg.used[k] = 1;
  1627	        continue;
  1628	      }
  1629	      let a = -1, b = -1, val = '';
  1630	      if (r.addr){
  1631	        // 住所/本籍: bound the value by the address hierarchy rather than by
  1632	        // "everything after the label", so a second column that drifted into
  1633	        // this segment is not swept into the band.
  1634	        const sp = jpAddressSpan(seg.t, L.end);
  1635	        if (sp && sp.b > sp.a){ a = sp.a; b = sp.b; val = seg.t.slice(a, b); }
  1636	      } else if (r.re){
  1637	        const m = r.re.exec(seg.t.slice(L.end));
  1638	        if (m){ a = L.end + m.index; b = a + m[0].length; val = m[0]; }
  1639	      }
  1640	      if (a < 0 && r.last !== true) continue;
  1641	      if (a < 0){
  1642	        // value position certain, characters not: take the items after the label
  1643	        const after = seg.items.filter(o => seg.start[o.i] >= L.end);
  1644	        if (!after.length) continue;
  1645	        const boxes = after.map(o => { const b2 = { page: pi, x:o.it.x, y:o.it.y, w:o.it.w, h:o.it.h }; b2.bg = sampleBg(pages[pi], b2); return b2; });
  1646	        push(r.field, boxes, seg.t.slice(L.end).trim() || '(value)');
  1647	        for (let k = L.end; k < seg.t.length; k++) seg.used[k] = 1;
  1648	        continue;
  1649	      }
  1650	      push(r.field, jpBoxes(seg, a, b), val.trim());
  1651	      for (let k = a; k < b; k++) seg.used[k] = 1;
  1652	    }
  1653	  }
  1654	
  1655	  /* Structural fallback — ONLY where OCR has destroyed the label but the format
  1656	     plus the document class still pin the field down. Each is narrow and stated:
  1657	       資格確認書: a bare 6–10 digit run outside any date line is a member of the
  1658	         保険者番号・記号・番号・枝番 family. The 告知要求制限 covers that whole
  1659	         family as ONE rule, so the cost of guessing which member it is, is zero —
  1660	         while a miss is the exact leak the product exists to prevent. Measured:
  1661	         OCR renders 保険者番号 as "RREES"/"REEES"/"WREEES" on 3 of 5 fixtures.
  1662	       住民票: 12 digits = 個人番号, 11 digits = 住民票コード. Both lengths are
  1663	         fixed by statute and nothing else on the form is that long. */
  1664	  const isDateRow = s => JP_DATE_RE.test(s.rowText) || s.rowText.includes('〒');
  1665	  const unconsumed = (seg, a, b) => { for (let k=a;k<b;k++) if (seg.used[k]) return false; return true; };
  1666	  const runs = seg => { const out=[]; let st=-1;
  1667	    for (let k=0;k<=seg.t.length;k++){ const d = k<seg.t.length && isDigit(seg.t[k]);
  1668	      if (d){ if (st<0) st=k; } else if (st>=0){ out.push([st,k]); st=-1; } } return out; };
  1669	  if (cls.doc === 'shikaku_kakuninsho'){
  1670	    for (const seg of segs){
  1671	      if (isDateRow(seg)) continue;
  1672	      for (const [a,b] of runs(seg)){
  1673	        const len = b - a;
  1674	        if (len < 6 || len > 10 || !unconsumed(seg, a, b)) continue;
  1675	        push('hokensha_bango', jpBoxes(seg, a, b), seg.t.slice(a,b), { viaFallback: true });
  1676	        for (let k=a;k<b;k++) seg.used[k]=1;
  1677	      }
  1678	    }
  1679	  }
  1680	  if (cls.doc === 'juminhyo'){
  1681	    for (const seg of segs){
  1682	      if (isDateRow(seg)) continue;
  1683	      for (const [a,b] of runs(seg)){
  1684	        const len = b - a;
  1685	        if (!unconsumed(seg, a, b)) continue;
  1686	        if (len === 12) push('my_number', jpBoxes(seg, a, b), seg.t.slice(a,b), { checkOk: myNumberCheckOk(seg.t.slice(a,b)), viaFallback: true });
  1687	        else if (len === 11) push('jumin_code', jpBoxes(seg, a, b), seg.t.slice(a,b), { viaFallback: true });
  1688	        else continue;
  1689	        for (let k=a;k<b;k++) seg.used[k]=1;
  1690	      }
  1691	    }
  1692	  }
  1693	
  1694	  /* Unlabelled addresses. Anything a label already claimed is marked consumed,
  1695	     so this only sees text standing on its own — 備考欄 contents, free-form
  1696	     notes. Per strategy v2 §3-2 it is automatic ONLY with 郵便番号 AND 都道府県
  1697	     together; otherwise it is a review candidate. It is filed under its own
  1698	     field key so it can never be confused with the LABELLED 住所, which on all
  1699	     four alpha documents is a keep-field the recipient needs. */
  1700	  for (const seg of segs){
  1701	    let from = 0;
  1702	    for (let guard = 0; guard < 4; guard++){
  1703	      const sp = jpAddressSpan(seg.t, from);
  1704	      if (!sp || sp.b <= sp.a) break;
  1705	      from = sp.b;
  1706	      if (sp.score < 3) continue;
  1707	      let free = true; for (let k = sp.a; k < sp.b; k++) if (seg.used[k]) { free = false; break; }
  1708	      if (!free) continue;
  1709	      push('address_loose', jpBoxes(seg, sp.a, sp.b), seg.t.slice(sp.a, sp.b), { strong: sp.postal && sp.pref });
  1710	      for (let k = sp.a; k < sp.b; k++) seg.used[k] = 1;
  1711	    }
  1712	  }
  1713	
  1714	  // 欄 regions (備考欄 / 臓器提供意思表示欄): the drawn rectangle under the label.
  1715	  for (const rr of (JP_REGION_LABELS[cls.doc] || [])){
  1716	    for (const seg of segs){
  1717	      if (!jpFindLabel(seg, rr.labels, false)) continue;
  1718	      const fr = jpFrameBelow(pages[pi], { y: seg.y, h: seg.h });
  1719	      const box = fr ? { ...fr, page: pi }
  1720	                     : { page: pi, x: seg.x0, y: seg.y, w: Math.max(seg.x1-seg.x0, pages[pi].w*0.5), h: seg.h*3.5, region: true };
  1721	      push(rr.field, [box], rr.field);
  1722	      break;
  1723	    }
  1724	  }
  1725	
  1726	  // 二次元コード
  1727	  if (cls.doc === 'shikaku_kakuninsho' || (cls.doc === 'mynumber_card' && cls.side === 'back')){
  1728	    for (const cb of jpCodeBlocks(pi)) push('qr', [cb.box], '二次元コード', { unlabelledCode: !cb.labelled });
  1729	  }
  1730	
  1731	  // 住民票: household member blocks. Block 1 is the subject; blocks 2..n are
  1732	  // third parties whose data the recipient did not ask for. Found by the 氏名
  1733	  // label rows, because 続柄 (本人/妻/子) is a single kanji that OCR mangles far
  1734	  // more often than it mangles a whole label.
  1735	  if (cls.doc === 'juminhyo'){
  1736	    const nameRows = segs.filter(s => jpFindLabel(s, ['氏名'], false)).sort((a,b)=>a.y-b.y);
  1737	    const endRe = /住民票コード|この写し|相違|証明し|市長|区長|町長|村長|公印/;
  1738	    if (nameRows.length > 1){
  1739	      for (let i = 1; i < nameRows.length; i++){
  1740	        const top = nameRows[i].y;
  1741	        const next = i + 1 < nameRows.length ? nameRows[i+1].y : Infinity;
  1742	        const stop = segs.filter(s => s.y > top && s.y < next && endRe.test(s.rowText)).map(s=>s.y);
  1743	        const bottom = stop.length ? Math.min(...stop) : next;
  1744	        const byRow = {};
  1745	        for (const s of segs){
  1746	          if (s.y < top || s.y >= bottom) continue;
  1747	          (byRow[s.row] = byRow[s.row] || []).push(s);
  1748	        }
  1749	        for (const list of Object.values(byRow))
  1750	          push('setaiin', list.map(jpSegBox), (list[0].t || '(世帯員)').slice(0, 24));
  1751	      }
  1752	    }
  1753	    // 氏名/生年月日 inside a THIRD PARTY's block are not the subject's keep-fields.
  1754	    // Leaving them in would put the same pixels in the 残す項目 list and under a
  1755	    // band at the same time — the list would be telling the user the opposite of
  1756	    // what the page shows.
  1757	    const regions = found.filter(f => f.field === 'setaiin').flatMap(f => f.boxes);
  1758	    if (regions.length){
  1759	      const inside = b => regions.some(r => b.x + b.w/2 >= r.x && b.x + b.w/2 <= r.x + r.w
  1760	                                         && b.y + b.h/2 >= r.y && b.y + b.h/2 <= r.y + r.h);
  1761	      for (let i = found.length - 1; i >= 0; i--){
  1762	        const f = found[i];
  1763	        if (!['name','birth','address'].includes(f.field)) continue;
  1764	        if (f.boxes.every(inside)) found.splice(i, 1);
  1765	      }
  1766	    }
  1767	  }
  1768	  return found;
  1769	}
  1770	
  1771	/* ── state + application ── */
  1772	const JP_PURPOSES = ['identity_submit','my_number_procedure','bid_attachment','consult_share'];
  1773	let jpState = { cls: null, purpose: 'identity_submit', findings: [] };
  1774	function jpScan(){
  1775	  jpState.cls = null; jpState.findings = [];
  1776	  if (!pages.length) return null;
  1777	  const cls = jpClassify(0);
  1778	  if (!cls) return null;
  1779	  jpState.cls = cls;
  1780	  let all = [];
  1781	  for (let pi = 0; pi < pages.length; pi++){
  1782	    const c = pi === 0 ? cls : (jpClassify(pi) || cls);
  1783	    all = all.concat(jpExtract(pi, c));
  1784	  }
  1785	  jpState.findings = all;
  1786	  return cls;
  1787	}
  1788	function jpFieldLabel(f){ return (T().jpFields && T().jpFields[f]) || f; }
  1789	// Build entities from the findings for the current purpose. Called on load and
  1790	// on every purpose change — the purpose IS the policy, so it re-derives rather
  1791	// than patching modes in place.
  1792	function jpApply(){
  1793	  entities = entities.filter(e => !e.jp);
  1794	  const cls = jpState.cls; if (!cls) { renderAll(); return; }
  1795	  const purpose = jpState.purpose;
  1796	  const add = (f, level, boxes, value, note) => {
  1797	    const kind = (level === 'auto' || level === 'gate') ? 'auto'
  1798	               : level === 'keep' ? 'keep' : 'candidate';
  1799	    const mode = (level === 'auto' || level === 'gate' || level === 'recommend') ? 'no' : 'ok';
  1800	    entities.push({ id:'j'+Math.random().toString(36).slice(2,8), type: JP_TYPE[f] || 'other',
  1801	      value, mode, kind, reason: 'jp_' + level, boxes, jp: { doc: cls.doc, side: cls.side || null, field: f, level, note: note || null } });
  1802	  };
  1803	
  1804	  // マイナンバーカード裏面 under a 本人確認 purpose: the whole face. 番号法 does not
  1805	  // let the recipient hold the 個人番号 at all for identity checking, so the
  1806	  // honest instruction is "submit the front instead", and the band says so.
  1807	  if (cls.doc === 'mynumber_card' && cls.side === 'back'){
  1808	    const lv = jpLevel('mynumber_card', 'back_all', purpose);
  1809	    if (lv === 'auto' || lv === 'gate'){
  1810	      for (let pi = 0; pi < pages.length; pi++)
  1811	        add('back_all', lv, [{ page: pi, x: 0, y: 0, w: pages[pi].w, h: pages[pi].h, region: true }], jpFieldLabel('back_all'));
  1812	    }
  1813	  }
  1814	  for (const f of jpState.findings){
  1815	    let level = jpLevel(cls.doc, f.field, purpose);
  1816	    if (!level) continue;
  1817	    // 個人番号 with a check digit that does not verify is NOT confirmed to be a
  1818	    // 個人番号 — it could be any 12-digit reference. Demote the automatic band
  1819	    // to a review candidate (still default-ON) rather than assert something the
  1820	    // arithmetic contradicts.
  1821	    let note = null;
  1822	    if (f.field === 'my_number' && (level === 'auto' || level === 'gate') && f.checkOk === false){ level = 'recommend'; note = 'checkdigit'; }
  1823	    // An unlabelled code block is detection without golden coverage — candidate.
  1824	    if (f.unlabelledCode && (level === 'auto' || level === 'gate')){ level = 'recommend'; note = 'unlabelled_code'; }
  1825	    add(f.field, level, f.boxes, f.field === 'qr' || f.boxes.some(b=>b.region) ? jpFieldLabel(f.field) : (f.value || jpFieldLabel(f.field)), note);
  1826	  }
  1827	  entities.sort((a,b)=>Object.keys(TYPES).indexOf(a.type)-Object.keys(TYPES).indexOf(b.type));
  1828	  jpRenderBar();
  1829	  renderAll();
  1830	}
  1831	const JP_TYPE = { address_loose:'address', tel:'phone', my_number:'rrn', jumin_code:'rrn', hokensha_bango:'health', kigo:'health',
  1832	  bango:'health', edaban:'health', hihokensha_bango:'health', license_no:'license', qr:'other',
  1833	  back_all:'other', biko_change:'address', organ_donor:'health', setaiin:'name', honseki:'address',
  1834	  hittosha:'name', sex:'other', name:'name', birth:'birth', address:'address', expiry:'other', issue:'other' };
  1835	
  1836	function jpSetPurpose(p){
  1837	  if (!JP_PURPOSES.includes(p)) return;
  1838	  jpState.purpose = p;
  1839	  const sel = $('jpPurpose'); if (sel) sel.value = p;
  1840	  jpApply();
  1841	}
  1842	function jpRenderBar(){
  1843	  const bar = $('jpBar'); if (!bar) return;
  1844	  const cls = jpState.cls;
  1845	  if (!cls){ bar.style.display = 'none'; return; }
  1846	  bar.style.display = 'flex';
  1847	  $('jpDocName').textContent = jpFieldLabel('doc_' + cls.doc) + (cls.side ? ' · ' + jpFieldLabel('side_' + cls.side) : '');
  1848	  const sel = $('jpPurpose');
  1849	  sel.innerHTML = JP_PURPOSES.map(p => `<option value="${p}">${escapeHtml(jpFieldLabel('purpose_' + p))}</option>`).join('');
  1850	  sel.value = jpState.purpose;
  1851	  const note = $('jpNote');
  1852	  const backMasked = entities.some(e => e.jp && e.jp.field === 'back_all');
  1853	  note.textContent = backMasked ? T().jpBackNotice : '';
  1854	  note.style.display = backMasked ? 'block' : 'none';
  1855	}
  1856	
  1857	/* ───────── text masking (list display + "copy text") ─────────
  1858	   Band-only: there are exactly two states. 'ok' shows the value; anything else
  1859	   shows a block run of the same rough length. No partial reveal exists, so the
  1860	   list cannot promise a weaker masking than the rendered page delivers. */
  1861	const maskBlockText=v=>'■'.repeat(Math.min(Math.max(Math.round(v.replace(/\s/g,'').length*0.8),3),12));
  1862	// live value shown next to the toggle
  1863	function displayValue(e){ return e.mode==='ok' ? e.value : maskBlockText(e.value); }
  1864	
  1865	/* ───────── coordinate index & box matching ───────── */

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "git show 546344b:public/safe/index.html | nl -ba | sed -n '1380,1548p'; git show 546344b:public/safe/index.html | nl -ba | sed -n '2080,2170p'; git show 546344b:public/safe/index.html | nl -ba | sed -n '2270,2355p'; git show 546344b:test/safe/run.mjs | nl -ba; git show 546344b:test/safe/specs.json | nl -ba" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
  1380	   fixture expectations. */
  1381	const P_ALL = ['identity_submit','my_number_procedure','bid_attachment','consult_share'];
  1382	const P_NOT_MYNUM = ['identity_submit','bid_attachment','consult_share'];
  1383	// Shared by all four documents: neither a free-standing address nor a phone
  1384	// number is part of what any of them has to prove, so both are always OFFERED —
  1385	// and recommended when the point of sharing is advice, not identification.
  1386	const JP_EXTRA = { address_loose: { recommend: ['consult_share'], optional: P_ALL },
  1387	                   tel:           { recommend: ['consult_share'], optional: P_ALL } };
  1388	const JP_RULES = {
  1389	  shikaku_kakuninsho: {
  1390	    // 健康保険法等 告知要求制限 (2020-10-01) — mhlw.go.jp/stf/newpage_13989.html
  1391	    hokensha_bango:   { auto: P_NOT_MYNUM },
  1392	    kigo:             { auto: P_NOT_MYNUM },
  1393	    bango:            { auto: P_NOT_MYNUM },
  1394	    edaban:           { auto: P_NOT_MYNUM },
  1395	    hihokensha_bango: { auto: P_NOT_MYNUM },
  1396	    // QRは番号を判読可能なため同一扱い（大阪府・千葉市運用）
  1397	    qr:               { auto: P_NOT_MYNUM },
  1398	    // 法定ではない。民間KYC運用（SoftBank, PayPay銀行等）
  1399	    sex:              { recommend: ['identity_submit'] },
  1400	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL},
  1401	    jigyosho:{keep:P_ALL}, hokensha_name:{keep:P_ALL}, shikaku_date:{keep:P_ALL},
  1402	    ...JP_EXTRA,
  1403	  },
  1404	  unten_menkyo: {
  1405	    biko_change:  { recommend: ['identity_submit','consult_share'] },
  1406	    organ_donor:  { recommend: ['identity_submit','consult_share'] },
  1407	    // 個人識別符号だが、KYCでは照合に必要な提出先が多い → 既定OFF
  1408	    license_no:   { optional: P_ALL },
  1409	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL}, issue:{keep:P_ALL},
  1410	    ...JP_EXTRA,
  1411	  },
  1412	  mynumber_card: {
  1413	    // 番号法: 法令で認められた者・目的以外での個人番号の収集・保管禁止
  1414	    back_all:   { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1415	    my_number:  { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1416	    qr:         { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1417	    sex:        { recommend: ['identity_submit'] },
  1418	    organ_donor:{ recommend: ['identity_submit'] },
  1419	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL},
  1420	    ...JP_EXTRA,
  1421	  },
  1422	  juminhyo: {
  1423	    my_number:  { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1424	    // 住民基本台帳法 利用制限（個人識別符号）
  1425	    jumin_code: { auto: P_NOT_MYNUM },
  1426	    honseki:    { recommend: P_ALL },
  1427	    hittosha:   { recommend: P_ALL },
  1428	    setaiin:    { recommend: ['identity_submit','consult_share'] },
  1429	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, issuer:{keep:P_ALL},
  1430	    ...JP_EXTRA,
  1431	  },
  1432	};
  1433	function jpLevel(doc, field, purpose){
  1434	  const r = (JP_RULES[doc] || {})[field];
  1435	  if (!r) return null;
  1436	  for (const lv of ['auto','gate','recommend','optional','keep'])
  1437	    if (r[lv] && r[lv].includes(purpose)) return lv;
  1438	  // A field the matrix knows but this purpose does not list is simply available,
  1439	  // never silently promoted to automatic.
  1440	  return r.keep ? 'optional' : 'optional';
  1441	}
  1442	
  1443	/* ── field extraction ─────────────────────────────────────────────────────
  1444	   Each rule is {field, labels[], re, last} — `labels` are the anchors accepted
  1445	   in the segment (several spellings, because OCR drops or swaps one character
  1446	   of a label far more often than it mangles a digit run), `re` is the value
  1447	   format, and `last` allows falling back to the segment's final item when the
  1448	   value itself was garbled but its POSITION is still certain (e.g. 性別 whose
  1449	   single kanji OCR read as "&" — the box is what we need, not the character). */
  1450	const JP_FIELD_RULES = {
  1451	  shikaku_kakuninsho: [
  1452	    { field:'hokensha_bango',   labels:['保険者番号','険者番号','保険者番'], re:/\d{4,10}/ },
  1453	    { field:'hihokensha_bango', labels:['被保険者番号','被保険者等記号','被保険者番'], re:/[0-9A-Z]{4,12}/ },
  1454	    { field:'kigo',   labels:['記号'], re:/[0-9A-Z]{2,12}/ },
  1455	    { field:'edaban', labels:['枝番'], re:/\d{1,3}/ },
  1456	    // 「番号」単独アンカー禁止 — it is a substring of 保険者番号/被保険者番号, so it
  1457	    // only counts when the segment actually STARTS with it (its own column).
  1458	    { field:'bango',  labels:['番号'], re:/[0-9A-Z]{1,12}/, headOnly:true },
  1459	    { field:'sex',    labels:['性別'], re:/[男女]/, last:true },
  1460	    { field:'name',   labels:['氏名'], re:null, last:true },
  1461	    { field:'birth',  labels:['生年月日'], re:null, last:true },
  1462	    { field:'address',labels:['住所'], re:null, last:true, addr:true },
  1463	    { field:'expiry', labels:['有効期限'], re:null, last:true },
  1464	    { field:'tel',    labels:['電話番号','電話','TEL','携帯','FAX'], tel:true },
  1465	  ],
  1466	  // Front-only: the back carries a 住所変更 line inside 備考欄, and calling that
  1467	  // a keep-field would contradict the very region we are hiding.
  1468	  unten_menkyo: [
  1469	    { field:'license_no', labels:['番号'], re:/第?\s?[0-9A-Z]{10,14}/, headOnly:true, sides:['front'] },
  1470	    { field:'name',   labels:['氏名'], re:null, last:true, sides:['front'] },
  1471	    { field:'birth',  labels:['生年月日'], re:null, last:true, sides:['front'] },
  1472	    { field:'address',labels:['住所'], re:null, last:true, sides:['front'], addr:true },
  1473	    { field:'expiry', labels:['有効期限'], re:null, last:true, sides:['front'] },
  1474	  ],
  1475	  mynumber_card: [
  1476	    { field:'my_number', labels:['個人番号','マイナンバー'], digits:12 },
  1477	    { field:'sex',    labels:['性別'], re:/[男女]/, last:true, sides:['front'] },
  1478	    { field:'name',   labels:['氏名'], re:null, last:true },
  1479	    { field:'birth',  labels:['生年月日'], re:null, last:true },
  1480	    { field:'address',labels:['住所'], re:null, last:true, sides:['front'], addr:true },
  1481	    { field:'expiry', labels:['有効期限'], re:null, last:true, sides:['front'] },
  1482	  ],
  1483	  juminhyo: [
  1484	    { field:'my_number', labels:['個人番号','マイナンバー'], digits:12 },
  1485	    { field:'jumin_code',labels:['住民票コード'], digits:11 },
  1486	    { field:'honseki',  labels:['本籍'], re:null, last:true, addr:true },
  1487	    { field:'hittosha', labels:['筆頭者'], re:null, last:true },
  1488	    { field:'name',   labels:['氏名'], re:null, last:true },
  1489	    { field:'birth',  labels:['生年月日'], re:null, last:true },
  1490	    { field:'address',labels:['住所'], re:null, last:true, addr:true },
  1491	    { field:'tel',    labels:['電話番号','電話','TEL','携帯','FAX'], tel:true },
  1492	  ],
  1493	};
  1494	// Field boxes marked as 欄/regions rather than values.
  1495	const JP_REGION_LABELS = {
  1496	  unten_menkyo: [
  1497	    { field:'biko_change', labels:['備考欄','備考'] },
  1498	    { field:'organ_donor', labels:['臓器提供','提供意思','意思表示欄'] },
  1499	  ],
  1500	  mynumber_card: [
  1501	    { field:'organ_donor', labels:['臓器提供','提供意思','意思表示欄'] },
  1502	  ],
  1503	};
  1504	const JP_DATE_RE = /[年月日]/;
  1505	
  1506	/* ── 住所 hierarchy ──────────────────────────────────────────────────────────
  1507	   郵便番号 → 都道府県 → 市区郡町村 → 町域 → 丁目番地号 → 建物, scored rather than
  1508	   matched as one regex, because a Japanese address is a sequence of optional
  1509	   layers and any single regex either demands them all (misses most real
  1510	   addresses) or demands none (matches every company name ending in 市).
  1511	
  1512	   The span is ANCHORED on a 郵便番号 or a real prefecture from the 47-name list.
  1513	   An invented head like 「架空県」 therefore cannot anchor one — which is exactly
  1514	   what keeps 「架空県後期高齢者医療広域連合」 (a 保険者名) and 「見本市長 架空 太郎」
  1515	   (the issuing mayor) out. Requiring the prefecture misses addresses that omit
  1516	   it, which is common in Japan; for the alpha that trade is deliberate, since a
  1517	   wrongly banded issuer is a rejected submission.
  1518	
  1519	   Institution words are a PENALTY, not an exclusion (strategy v2 §3-2): a real
  1520	   address can legitimately contain 「…市役所前」, so the word lowers the score
  1521	   instead of vetoing the span. */
  1522	const JP_PREFS = ['北海道','青森県','岩手県','宮城県','秋田県','山形県','福島県','茨城県','栃木県','群馬県','埼玉県','千葉県','東京都','神奈川県','新潟県','富山県','石川県','福井県','山梨県','長野県','岐阜県','静岡県','愛知県','三重県','滋賀県','京都府','大阪府','兵庫県','奈良県','和歌山県','鳥取県','島根県','岡山県','広島県','山口県','徳島県','香川県','愛媛県','高知県','福岡県','佐賀県','長崎県','熊本県','大分県','宮崎県','鹿児島県','沖縄県'];
  1523	const JP_POSTAL_RE = /〒?\d{3}-\d{4}/;
  1524	const JP_CITY_RE = /^.{1,8}?[市区郡町村]/;
  1525	// 丁目/番地/番/号 accept 漢数字 一〜十・百・千 as well as digits (official
  1526	// 住民票 printouts still use them, and OCR reads them as kanji, not digits).
  1527	const JP_NUM = '(?:[0-9]{1,4}|[一二三四五六七八九十百千]{1,6})';
  1528	// The numeric tail has to be anchored on a TERMINATOR, not just on "a numeral".
  1529	// A lazy prefix followed by a bare numeral stops at the first numeral-looking
  1530	// kanji in a place name — 「三条通一丁目二番三号」 matched just 「三」 — and a
  1531	// fixed 丁目/番/号 sequence misses the hyphenated form 「霞が関1-3-2」 entirely.
  1532	// So: skip forward to the first position where NUM is followed by one of
  1533	// 丁目/番地/番/号/-, then repeat that pair greedily.
  1534	const JP_SEP = '(?:丁目|番地|番|号|[-－])';
  1535	const JP_BANCHI_RE = new RegExp(`^.{0,14}?${JP_NUM}${JP_SEP}(?:の?${JP_NUM}${JP_SEP})*(?:の?${JP_NUM})?号?`);
  1536	const JP_INSTITUTION_RE = /市役所|区役所|町役場|村役場|株式会社|有限会社|合同会社|大学|学校|病院|診療所|協会|広域連合|組合|銀行|支店|連合会|振興局/;
  1537	// Finds an address starting at or after `from`. Returns {a,b,score,postal,pref}.
  1538	function jpAddressSpan(t, from){
  1539	  let a = -1, score = 0, postal = false, pref = '';
  1540	  const pm = JP_POSTAL_RE.exec(t.slice(from));
  1541	  for (const p of JP_PREFS){
  1542	    const i = t.indexOf(p, from);
  1543	    if (i >= 0 && (a < 0 || i < a)) { a = i; pref = p; }
  1544	  }
  1545	  if (pm && (a < 0 || from + pm.index < a)) { a = from + pm.index; postal = true; }
  1546	  if (a < 0) return null;
  1547	  if (postal) score += 2;
  1548	  let b = a;
  2080	  const cv=canvasEl(iw*sc, ih*sc);
  2081	  cv.getContext('2d',{willReadFrequently:true}).drawImage(img,0,0,cv.width,cv.height);
  2082	  setStatus(T().ocrStart);
  2083	  const items=await ocrCanvas(cv);
  2084	  pages=[{canvas:cv,w:cv.width,h:cv.height,ptW:cv.width*0.75,ptH:cv.height*0.75,items}];
  2085	  setProg(0);
  2086	}
  2087	
  2088	async function ocrCanvas(cv){
  2089	  const Te=await ensureTesseract();
  2090	  const { data } = await Te.recognize(cv, OCR_LANGS(), { logger:m=>{
  2091	    if(m.status && m.status.indexOf('recogniz')>=0){ setProg(0.1+m.progress*0.9); setStatus(T().ocrProg(Math.round(m.progress*100))); }
  2092	    else { setStatus(T().ocrStart); }
  2093	  }});
  2094	  const words=(data && data.words) ? data.words : [];
  2095	  // TRIM the word text. Tesseract sometimes returns a word with leading or
  2096	  // trailing whitespace, but its bbox is the INK box — the space has no pixels.
  2097	  // Keeping the space makes str.length one too many, and every character box is
  2098	  // derived by dividing the item width by that length, so the whole run shifts
  2099	  // right by one cell. Measured: " 99221010" on 資格確認書 left the first 9
  2100	  // uncovered by ~7px — a digit of a 保険者番号 surviving the band.
  2101	  return words.filter(w=>w.text && w.text.trim()).map(w=>({
  2102	    str:w.text.trim(), x:w.bbox.x0, y:w.bbox.y0, w:w.bbox.x1-w.bbox.x0, h:w.bbox.y1-w.bbox.y0
  2103	  }));
  2104	}
  2105	
  2106	/* Text (docx/txt/paste/sample) → rendered white pages with word boxes */
  2107	async function renderTextPages(text,name){
  2108	  try{ await document.fonts.ready; }catch(e){}
  2109	  text=(text||'').replace(/\r/g,'');
  2110	  const W=1240, pad=64, fs=24, LH=Math.round(fs*1.62), maxW=W-pad*2, pageH=Math.round(W*1.414);
  2111	  const meas=canvasEl(10,10).getContext('2d'); meas.font=fs+'px "IBM Plex Sans KR",sans-serif';
  2112	  const spaceW=meas.measureText(' ').width;
  2113	  pages=[];
  2114	  let cur=null, y=0;
  2115	  function newPage(){ const c=canvasEl(W,pageH); const ctx=c.getContext('2d',{willReadFrequently:true}); ctx.fillStyle='#FFFFFF'; ctx.fillRect(0,0,W,pageH); ctx.fillStyle=INK; ctx.font=fs+'px "IBM Plex Sans KR",sans-serif'; ctx.textBaseline='alphabetic'; cur={canvas:c,w:W,h:pageH,ptW:W*0.75,ptH:pageH*0.75,items:[],ctx}; y=pad+fs; }
  2116	  function push(){ if(cur){ delete cur.ctx; pages.push(cur); } }
  2117	  function nl(){ y+=LH; if(y>pageH-pad){ push(); newPage(); } }
  2118	  newPage();
  2119	  for(const line of text.split('\n')){
  2120	    if(line.trim()===''){ nl(); continue; }
  2121	    let x=pad;
  2122	    for(const word of line.split(/\s+/).filter(Boolean)){
  2123	      const ww=meas.measureText(word).width;
  2124	      if(x!==pad && x+ww>maxW+pad){ nl(); x=pad; }
  2125	      cur.ctx.fillText(word, x, y);
  2126	      cur.items.push({str:word, x, y:y-fs*0.86, w:ww, h:fs*1.16});
  2127	      x+=ww+spaceW;
  2128	    }
  2129	    nl();
  2130	  }
  2131	  push();
  2132	}
  2133	
  2134	function afterLoad(keepEntities){
  2135	  docText=pages.map(p=>p.items.map(i=>i.str).join(' ')).join('\n\n');
  2136	  $('pasteArea').style.display='none'; $('pasteActions').style.display='none';
  2137	  dz.style.display='none'; $('docWrap').style.display='flex';
  2138	  $('fileName').textContent=docTitle||'doc';
  2139	  $('fileInfo').textContent=T().pages(pages.length);
  2140	  if(!keepEntities){
  2141	    entities=[]; aiDone=false; showAllCats=false;
  2142	    addEntities(regexScan(docText));
  2143	    // A classified Japanese document gets its own preset. The Latin name/address
  2144	    // heuristics are suppressed there — they are tuned for résumé typography and
  2145	    // on a JP form they only ever produced junk ("(被用者", "カー", "裏面"), which
  2146	    // would sit next to the legally-grounded preset looking equally authoritative.
  2147	    const jp = jpScan();
  2148	    if(!jp){
  2149	      addEntities(nameCandidates());     // conservative top-of-doc name suggestion (defaults to visible)
  2150	      addEntities(addressCandidates());  // place/city lines without a number → review candidates
  2151	    }
  2152	    setStatus(T().scanDone(entities.filter(e=>e.kind!=='candidate').length)); setProg(0);
  2153	  }
  2154	  const ab=$('btnAI'); if(!aiDone){ ab.disabled=false; }
  2155	  buildPreview();
  2156	  if(jpState.cls){
  2157	    jpApply();
  2158	    // The status line is written before the preset runs, so on a JP document it
  2159	    // used to report "0 found" next to a list of five bands. Keep-fields are not
  2160	    // "found personal info" — they are what the recipient needs — so they do not count.
  2161	    if(!keepEntities) setStatus(T().scanDone(entities.filter(e=>e.kind!=='keep'&&e.kind!=='manual').length));
  2162	  } else { jpRenderBar(); renderAll(); }
  2163	}
  2164	function resetResult(){ $('result').style.display='none'; lastOut=null; }
  2165	function resetAll(){
  2166	  pages=[]; docText=''; entities=[]; aiDone=false; showAllCats=false; previewCanvases=[];
  2167	  jpState={cls:null, purpose:'identity_submit', findings:[]}; jpRenderBar();
  2168	  $('docWrap').style.display='none'; dz.style.display='flex'; $('preview').innerHTML=''; clearDzAlert();
  2169	  if(typeof setSelectMode==='function') setSelectMode(false);
  2170	  setStatus(''); setProg(0); resetResult();
  2270	      if(ov>0.5){ x0=Math.min(x0,b.x);y0=Math.min(y0,b.y);x1=Math.max(x1,b.x+b.w);y1=Math.max(y1,b.y+b.h);used[j]=true;region=region||b.region; }
  2271	    }
  2272	    lines.push({x:x0,y:y0,w:x1-x0,h:y1-y0,bg,region});
  2273	  }
  2274	  return lines.sort((a,b)=>a.y-b.y||a.x-b.x);
  2275	}
  2276	// The band drawn for a merged line box: the text/OCR box grown by a margin of
  2277	// 15% of the box height (floor 2px) on every side. The margin exists because the
  2278	// box is an ESTIMATE — pdf.js item boxes exclude side bearings and overshoot,
  2279	// OCR word boxes clip anti-aliased glyph edges, and both drift under rotation.
  2280	// A band that stops exactly at the estimate leaves a hairline of original ink.
  2281	// Percentage-of-height (not a fixed 2px) so the margin scales with the font;
  2282	// the floor keeps tiny OCR boxes from getting a sub-pixel margin.
  2283	// A box flagged `region` was drawn by a human (manual drag) or taken from a
  2284	// detected block/frame — its edges are the intent, not an estimate of where
  2285	// glyphs end, so it is NOT grown. Growing it would silently cover neighbouring
  2286	// content the user did not choose to hide.
  2287	const BAND_PAD_RATIO=0.15, BAND_PAD_MIN=2;
  2288	function bandRect(l){
  2289	  if(l.region) return {x:l.x, y:l.y, w:l.w, h:l.h};
  2290	  const p=Math.max(l.h*BAND_PAD_RATIO, BAND_PAD_MIN);
  2291	  return {x:l.x-p, y:l.y-p, w:l.w+p*2, h:l.h+p*2};
  2292	}
  2293	/* Band colour. Default ink; white and a user-picked single colour are the only
  2294	   alternatives (a colour is opaque either way — this is a legibility choice on
  2295	   the submitted copy, not a masking-strength choice). */
  2296	let BAND_COLOR=INK;
  2297	function bandColor(){ return BAND_COLOR; }
  2298	(function(){
  2299	  const sel=$('bandColor'), cust=$('bandCustom');
  2300	  if(!sel||!cust) return;
  2301	  const apply=()=>{
  2302	    const custom = sel.value==='custom';
  2303	    cust.style.display = custom? 'inline-block':'none';
  2304	    BAND_COLOR = custom ? cust.value : sel.value;
  2305	    if(typeof drawPreview==='function' && pages.length) drawPreview();
  2306	  };
  2307	  sel.addEventListener('change',apply);
  2308	  cust.addEventListener('input',apply);
  2309	})();
  2310	function isDarkColor(bg){
  2311	  const m=/rgb\((\d+),\s*(\d+),\s*(\d+)\)/.exec(bg||''); if(!m) return false;
  2312	  return (0.299*+m[1]+0.587*+m[2]+0.114*+m[3]) < 130;
  2313	}
  2314	// Band-only redaction: every active entity becomes one opaque rect per visual
  2315	// line, grown by bandRect(). There is no ordering or overlap subtlety left to
  2316	// get wrong — two entities landing on the same coordinates simply paint the same
  2317	// opaque colour twice. (The previous partial-mask path needed an escalation pass
  2318	// to stop two asterisk strings from ghosting over each other and leaving an
  2319	// uncovered tail; removing the mode removed that whole failure class.)
  2320	function drawRedactions(ctx,pi,scale){
  2321	  const S=v=>v*scale;
  2322	  const col=bandColor();
  2323	  for(const e of entities){
  2324	    if(!isOn(e)||e.mode==='ok') continue;
  2325	    const lines=mergeLineBoxes(e.boxes,pi);
  2326	    if(!lines.length) continue;
  2327	    ctx.fillStyle=col;
  2328	    for(const l of lines){ const r=bandRect(l); ctx.fillRect(S(r.x),S(r.y),S(r.w),S(r.h)); }
  2329	  }
  2330	}
  2331	function drawWatermark(ctx,W,H,text){
  2332	  if(!text) return;
  2333	  ctx.save();
  2334	  // keep bottom margin clear (QR/stamp/signature area) + small top margin
  2335	  ctx.beginPath(); ctx.rect(0, H*0.05, W, H*0.81); ctx.clip();
  2336	  ctx.globalAlpha=0.10; ctx.fillStyle=INK;
  2337	  const fs=Math.max(16, W*0.028);
  2338	  ctx.font='700 '+fs+'px "IBM Plex Sans KR",sans-serif';
  2339	  ctx.textAlign='center'; ctx.textBaseline='middle';
  2340	  ctx.translate(W/2,H/2); ctx.rotate(-Math.PI/6);
  2341	  const tw=ctx.measureText(text).width;
  2342	  const stepX=tw+fs*3.5, stepY=fs*4.2, diag=Math.hypot(W,H);
  2343	  for(let yy=-diag; yy<diag; yy+=stepY) for(let xx=-diag; xx<diag; xx+=stepX) ctx.fillText(text,xx,yy);
  2344	  ctx.restore();
  2345	}
  2346	
  2347	/* ───────── manual region selection (drag to redact photo/signature/name) ───────── */
  2348	let selectMode=false, sel=null;
  2349	function setSelectMode(on){
  2350	  selectMode=on;
  2351	  const btn=$('btnSelect'); if(btn){ btn.classList.toggle('on',on); btn.textContent=on? T().btnSelectOn : T().btnSelect; }
  2352	  $('preview').classList.toggle('selmode',on);
  2353	  const hint=$('selHint'); if(hint) hint.style.display=on?'block':'none';
  2354	}
  2355	function attachSelect(cv){
     1	#!/usr/bin/env node
     2	/*
     3	 * Golden verification harness for the SafeFile PII pipeline.
     4	 *
     5	 * Serves the REAL public/safe/index.html in headless Chrome, drives the live
     6	 * detection over each fixture, and checks every value against specs.json:
     7	 *   - MUST_MASK      : value is geometrically covered by an active mask rect
     8	 *   - MUST_NOT_MASK  : value is NOT covered by any mask rect
     9	 *   - NEVER_CANDIDATE: value is not proposed as a review candidate
    10	 *   - SHOULD_CANDIDATE: value surfaces as a candidate (visible, not hidden)
    11	 *   - AI_INJECT      : adversarial AI labels are neutralised in addEntities
    12	 *   - TEXT_LEAK      : output PDF has 0 extractable characters
    13	 *   - OUT_SAFE       : output carries no annots/embedded files/incremental save/EXIF
    14	 *
    15	 * Requires: node, playwright (chrome channel). Fixtures from generate_fixtures.py.
    16	 * Usage: node run.mjs [--only 7_resume_dark.pdf]  (exit 0 = all pass)
    17	 */
    18	import { chromium } from 'playwright';
    19	import http from 'node:http';
    20	import fs from 'node:fs';
    21	import path from 'node:path';
    22	import { fileURLToPath } from 'node:url';
    23	
    24	const __dirname = path.dirname(fileURLToPath(import.meta.url));
    25	const REPO = path.resolve(__dirname, '..', '..');
    26	const PUBLIC = path.join(REPO, 'public');
    27	const DOCS = path.join(__dirname, 'testdocs');
    28	const FIXTURES = path.join(__dirname, 'fixtures');
    29	const SPECS = JSON.parse(fs.readFileSync(path.join(__dirname, 'specs.json'), 'utf8'));
    30	const OUT = path.join(__dirname, 'out');
    31	fs.mkdirSync(OUT, { recursive: true });
    32	
    33	const onlyArg = (() => { const i = process.argv.indexOf('--only'); return i >= 0 ? process.argv[i + 1] : null; })();
    34	
    35	const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json', '.txt': 'text/plain' };
    36	
    37	function startServer() {
    38	  return new Promise(resolve => {
    39	    const srv = http.createServer((req, res) => {
    40	      let p = decodeURIComponent(req.url.split('?')[0]);
    41	      if (p === '/') p = '/index.html';
    42	      const fp = path.join(PUBLIC, p);
    43	      if (!fp.startsWith(PUBLIC) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end('nf'); return; }
    44	      res.writeHead(200, { 'content-type': MIME[path.extname(fp)] || 'application/octet-stream' });
    45	      fs.createReadStream(fp).pipe(res);
    46	    });
    47	    srv.listen(0, '127.0.0.1', () => resolve(srv));
    48	  });
    49	}
    50	
    51	// ── in-page helpers, serialised into the browser context ──
    52	const PAGE_HELPERS = () => {
    53	  // Active mask rects: every entity that is ON, not 'ok', and located — passed
    54	  // through bandRect() so the harness measures the pixels that are ACTUALLY
    55	  // painted (box + padding), not the pre-padding estimate. This makes MUST_MASK
    56	  // easier and MUST_NOT_MASK harder, which is the honest direction: a padding
    57	  // that bleeds onto a neighbouring must-keep value now fails the golden.
    58	  window.__maskRects = function () {
    59	    const rects = [];
    60	    for (const e of entities) {
    61	      if (!isOn(e) || e.mode === 'ok' || !(e.boxes && e.boxes.length)) continue;
    62	      for (let pi = 0; pi < pages.length; pi++) {
    63	        for (const l of mergeLineBoxes(e.boxes, pi)) { const r = bandRect(l); rects.push({ pi, x: r.x, y: r.y, w: r.w, h: r.h }); }
    64	      }
    65	    }
    66	    return rects;
    67	  };
    68	  window.__rectsFor = function (v) {
    69	    return boxesForValue(v).map(b => ({ pi: b.page, x: b.x, y: b.y, w: b.w, h: b.h }));
    70	  };
    71	  window.__isMasked = function (v) {
    72	    const mr = window.__maskRects(), vr = window.__rectsFor(v);
    73	    const ov = (a, b) => {
    74	      if (a.pi !== b.pi) return 0;
    75	      const ix = Math.max(0, Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x));
    76	      const iy = Math.max(0, Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y));
    77	      return ix * iy;
    78	    };
    79	    for (const b of vr) { const area = b.w * b.h; if (area <= 0) continue; for (const a of mr) if (ov(a, b) > area * 0.25) return true; }
    80	    return false;
    81	  };
    82	  const norm = s => (s || '').toLowerCase().replace(/\s+/g, ' ').replace(/[.,;:'"()]+$/g, '').replace(/^[.,;:'"()]+/g, '').trim();
    83	  window.__norm = norm;
    84	  window.__entitySnapshot = function () {
    85	    return entities.map(e => ({ type: e.type, value: e.value, kind: e.kind, mode: e.mode, reason: e.reason, located: !!(e.boxes && e.boxes.length) }));
    86	  };
    87	  /* ── JP: geometry is checked against the FIXTURE'S OWN box table, not against
    88	     a value string. A Japanese form's value is exactly what OCR mangles
    89	     (美咲 → "S=0%"), so asserting on the string would test Tesseract, not us;
    90	     the box is what the band has to cover either way. ── */
    91	  // fraction of `rect` (page coords) covered by the union of active mask rects,
    92	  // sampled on a grid so overlapping bands count once.
    93	  window.__coverage = function (rect) {
    94	    const mr = window.__maskRects().filter(r => r.pi === rect.pi);
    95	    if (!mr.length) return 0;
    96	    const N = 24; let hit = 0;
    97	    for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) {
    98	      const x = rect.x + rect.w * (i + 0.5) / N, y = rect.y + rect.h * (j + 0.5) / N;
    99	      if (mr.some(r => x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h)) hit++;
   100	    }
   101	    return hit / (N * N);
   102	  };
   103	  // OCR/text item boxes whose centre falls inside `rect`
   104	  window.__itemsIn = function (rect) {
   105	    const p = pages[rect.pi]; if (!p) return [];
   106	    return (p.items || []).filter(it => it.x + it.w / 2 >= rect.x && it.x + it.w / 2 <= rect.x + rect.w
   107	                                     && it.y + it.h / 2 >= rect.y && it.y + it.h / 2 <= rect.y + rect.h)
   108	      .map(it => ({ pi: rect.pi, x: it.x, y: it.y, w: it.w, h: it.h }));
   109	  };
   110	  // any ACTIVE candidate entity overlapping `rect` (did the field surface for review?)
   111	  window.__candidateOver = function (rect) {
   112	    for (const e of entities) {
   113	      if (e.kind !== 'candidate' || !e.boxes) continue;
   114	      for (const b of e.boxes) {
   115	        if (b.page !== rect.pi) continue;
   116	        if (!(b.x + b.w < rect.x || rect.x + rect.w < b.x || b.y + b.h < rect.y || rect.y + rect.h < b.y)) return true;
   117	      }
   118	    }
   119	    return false;
   120	  };
   121	  window.__jpState = function () {
   122	    return { cls: jpState.cls && { doc: jpState.cls.doc, side: jpState.cls.side || null, score: jpState.cls.score },
   123	      purpose: jpState.purpose, pw: pages.map(p => p.w),
   124	      fields: entities.filter(e => e.jp).map(e => ({ field: e.jp.field, level: e.jp.level, note: e.jp.note, kind: e.kind, mode: e.mode })) };
   125	  };
   126	  window.__isCandidateExact = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value) === n); };
   127	  window.__isCandidateContains = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value).includes(n)); };
   128	  // default mode of the candidate whose value contains v (null if not a candidate)
   129	  window.__candidateMode = function (v) { const n = norm(v); const e = entities.find(x => x.kind === 'candidate' && norm(x.value).includes(n)); return e ? e.mode : null; };
   130	  // name-bar geometry: glyph union (raw pdf items) vs drawn bar rect
   131	  window.__nameBar = function (v) {
   132	    const rects = boxesForValue(v).filter(b => b.page === 0);
   133	    if (!rects.length) return null;
   134	    const lines = mergeLineBoxes(rects, 0); const bar = lines[0];
   135	    // glyph union straight from page items overlapping the value
   136	    const its = (pages[0].items || []).filter(it => (v.split(/\s+/).some(w => (it.str || '').includes(w))));
   137	    if (!its.length) return null;
   138	    const gx0 = Math.min(...its.map(i => i.x)), gy0 = Math.min(...its.map(i => i.y));
   139	    const gx1 = Math.max(...its.map(i => i.x + i.w)), gy1 = Math.max(...its.map(i => i.y + i.h));
   140	    const gW = gx1 - gx0, gH = gy1 - gy0;
   141	    // replicate the drawn-band geometry exactly as the page would paint it.
   142	    const drawn = bandRect(bar);
   143	    // Ink safety: the bar must cover the full glyph WIDTH and, vertically, the
   144	    // cap-height→descent band (raw pdf font box minus the top ascent gap where
   145	    // no ink lives). It should NOT need to cover the empty ascent whitespace.
   146	    const inkTop = gy0 + gH * 0.18, inkBot = gy1;
   147	    const coversInk = drawn.x <= gx0 + 1 && drawn.x + drawn.w >= gx1 - 1 && drawn.y <= inkTop + 1 && drawn.y + drawn.h >= inkBot - 1;
   148	    return { barW: bar.w, barH: bar.h, drawnH: drawn.h, drawnW: drawn.w, glyphW: gW, glyphH: gH, containsGlyph: coversInk };
   149	  };
   150	};
   151	
   152	// `jp/...` paths resolve under fixtures/, everything else under testdocs/.
   153	const docPath = file => file.startsWith('jp/') ? path.join(FIXTURES, file) : path.join(DOCS, file);
   154	async function loadDoc(page, file, ocr) {
   155	  await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
   156	  await page.setInputFiles('#fileInput', docPath(file));
   157	  await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0, { timeout: ocr ? 240000 : 40000 });
   158	  await page.waitForTimeout(ocr ? 800 : 400);
   159	  await page.evaluate(PAGE_HELPERS);
   160	}
   161	
   162	const rows = [];
   163	const rec = (doc, cat, item, expected, actual, pass, info = false) => rows.push({ doc, cat, item, expected, actual, pass, info });
   164	
   165	async function checkDoc(page, spec) {
   166	  const { doc, ocr } = spec;
   167	  await loadDoc(page, doc, ocr);
   168	  const snap = await page.evaluate(() => window.__entitySnapshot());
   169	  const autoCount = snap.filter(e => e.kind === 'auto').length;
   170	  process.stderr.write(`    [autoCount] ${doc} = ${autoCount}\n`);
   171	  if (spec.min_auto != null) rec(doc, 'REGRESSION', `auto>=${spec.min_auto}`, `>=${spec.min_auto}`, String(autoCount), autoCount >= spec.min_auto);
   172	  // False-positive regression guard: a hard CEILING on auto-detected entities.
   173	  // The golden's MUST_MASK checks catch "did we mask what we should"; max_auto
   174	  // catches the inverse — a detection change that starts auto-masking body text
   175	  // (the résumé-defect class where 95/95 passed while the body got shredded).
   176	  if (spec.max_auto != null) rec(doc, 'REGRESSION', `auto<=${spec.max_auto}`, `<=${spec.max_auto}`, String(autoCount), autoCount <= spec.max_auto);
   177	
   178	  // Turn a name candidate ON (hide → solid) so must_mask can assert the whole
   179	  // name — surname included — is geometrically covered once the user activates it.
   180	  if (spec.activate_name) {
   181	    const ok = await page.evaluate(v => {
   182	      const e = entities.find(x => x.value === v && x.type === 'name');
   183	      if (!e) return false;
   184	      e.mode = 'no'; renderAll(); return true;
   185	    }, spec.activate_name);
   186	    rec(doc, 'NAME_WHOLE', spec.activate_name, 'detected-whole', ok ? 'detected' : 'MISSING/truncated', ok);
   187	  }
   188	
   189	  for (const v of spec.must_mask || []) {
   190	    const masked = await page.evaluate(x => window.__isMasked(x), v);
   191	    rec(doc, 'MUST_MASK', v, 'masked', masked ? 'masked' : 'NOT masked', masked);
   192	  }
   193	  for (const v of spec.must_not_mask || []) {
   194	    const masked = await page.evaluate(x => window.__isMasked(x), v);
   195	    rec(doc, 'MUST_NOT_MASK', v, 'clear', masked ? 'MASKED' : 'clear', !masked);
   196	  }
   197	  for (const v of spec.never_candidate || []) {
   198	    const isCand = await page.evaluate(x => window.__isCandidateExact(x), v);
   199	    rec(doc, 'NEVER_CANDIDATE', v, 'not-cand', isCand ? 'CANDIDATE' : 'not-cand', !isCand);
   200	  }
   201	  for (const v of spec.should_candidate || []) {
   202	    // A candidate must SURFACE as a review candidate. (Its default redaction level
   203	    // — name/address candidates now default to 'half' — is asserted separately by
   204	    // CANDIDATE_MODE; "surfaced" is no longer coupled to "left in the clear".)
   205	    const isCand = await page.evaluate(x => window.__isCandidateContains(x), v);
   206	    rec(doc, 'SHOULD_CANDIDATE', v, 'candidate', isCand ? 'candidate' : 'missing', isCand);
   207	  }
   208	  // Candidate default-mode policy: name/address candidates default to 'half' so the
   209	  // "확인 필요" label matches a visibly-partial state. Old code defaulted them to 'ok'.
   210	  for (const [v, exp] of Object.entries(spec.candidate_mode || {})) {
   211	    const mode = await page.evaluate(x => window.__candidateMode(x), v);
   212	    rec(doc, 'CANDIDATE_MODE', v, exp, mode || 'not-candidate', mode === exp);
   213	  }
   214	  if (spec.name_bar) {
   215	    const nb = await page.evaluate(x => window.__nameBar(x), spec.name_bar);
   216	    if (nb) {
   217	      const ratioH = nb.drawnH / nb.glyphH;
   218	      const ok = nb.containsGlyph && ratioH <= 1.5;
   219	      rec(doc, 'NAME_BAR', spec.name_bar, 'tight&contains', `hRatio=${ratioH.toFixed(2)} contains=${nb.containsGlyph}`, ok);
   220	    } else rec(doc, 'NAME_BAR', spec.name_bar, 'measurable', 'no-boxes', false);
   221	  }
   222	  if (spec.dark_bg_value) {
   223	    const dk = await page.evaluate(v => { const e = entities.find(x => x.value === v); const bg = e && e.boxes[0] ? e.boxes[0].bg : null; return { bg, dark: bg ? isDarkColor(bg) : null }; }, spec.dark_bg_value);
   224	    rec(doc, 'DARK_BG', spec.dark_bg_value, 'dark bg detected', `${dk.bg} dark=${dk.dark}`, dk.dark === true, true);
   225	  }
   226	  for (const fmt of (spec.out_formats || (spec.type === 'pdf' ? ['pdf'] : []))) {
   227	    await checkOutput(page, doc, fmt);
   228	  }
   229	}
   230	
   231	/* ── output safety ──────────────────────────────────────────────────────────
   232	   What the user ships is the output file, not our preview. Three separate ways
   233	   a redacted-looking file still carries the original:
   234	     1. a text layer under the ink (the classic "透ける黒塗り"),
   235	     2. metadata the renderer never shows — EXIF/XMP/IPTC on images, annotations
   236	        or embedded files in a PDF,
   237	     3. an incrementally-saved PDF, where the PREVIOUS revision (unredacted) is
   238	        still physically present earlier in the same byte stream.
   239	   Each needs its own probe: pdf.js text extraction catches (1) and is blind to
   240	   (2) and (3). So we read the produced BYTES. */
   241	const MARKERS = {
   242	  // PNG: every ancillary text/EXIF chunk type. Canvas encodes none of these, but
   243	  // "it currently doesn't" is not a guarantee — assert it.
   244	  png: [['eXIf', 'EXIF chunk'], ['tEXt', 'tEXt chunk'], ['zTXt', 'zTXt chunk'], ['iTXt', 'iTXt chunk']],
   245	  // ICC_PROFILE is deliberately NOT forbidden: Chrome's JPEG encoder attaches a
   246	  // 456-byte generic sRGB profile (tags: desc/rXYZ/gXYZ/bXYZ/wtpt/rTRC/cprt —
   247	  // measured, no device identifiers). That is a colour space declaration, not
   248	  // document content and not an identifier. What WOULD be a leak is the
   249	  // viewer's *display* profile, which carries manufacturer/model tags and is
   250	  // much larger — iccSafe() below bounds exactly that.
   251	  jpg: [['Exif\0\0', 'EXIF APP1'], ['http://ns.adobe.com/xap/', 'XMP APP1'], ['Photoshop 3.0\0', 'IPTC APP13']],
   252	  pdf: [['/Annots', 'annotation'], ['/EmbeddedFile', 'embedded file'], ['/XFA', 'XFA form'], ['/AcroForm', 'form fields'], ['/Names', 'name tree']],
   253	};
   254	function scanMarkers(buf, kind) {
   255	  const hay = buf.toString('latin1');
   256	  return MARKERS[kind].filter(([m]) => hay.includes(m)).map(([, label]) => label);
   257	}
   258	// An embedded ICC profile is acceptable only while it stays a generic colour
   259	// space. A display profile (which identifies the machine that produced the file)
   260	// is large and carries the device manufacturer / model description tags.
   261	const ICC_MAX = 2048;
   262	function iccSafe(buf) {
   263	  const hay = buf.toString('latin1');
   264	  const at = hay.indexOf('ICC_PROFILE\0');
   265	  if (at < 0) return { ok: true, note: 'absent' };
   266	  const size = buf.readUInt32BE(at + 14);          // profile header: byte 0..3 = size
   267	  const body = hay.slice(at + 14, at + 14 + Math.min(size, 65535));
   268	  const dev = ['dmnd', 'dmdd'].filter(t => body.includes(t));
   269	  const ok = size <= ICC_MAX && dev.length === 0;
   270	  return { ok, note: `${size}B${dev.length ? ' +' + dev.join('/') : ''}` };
   271	}
   272	async function checkOutput(page, doc, fmt) {
   273	  const tag = `OUT_${fmt.toUpperCase()}`;
   274	  try {
   275	    await page.evaluate(f => { const r = document.querySelector(`input[name=fmt][value="${f}"]`); if (r) r.checked = true; }, fmt);
   276	    // force at least one masked, located entity so Make is enabled
   277	    await page.evaluate(() => { const e = entities.find(x => isOn(x) && x.boxes && x.boxes.length); if (e) e.mode = 'no'; renderAll(); });
   278	    await page.click('#btnMake');
   279	    await page.waitForSelector('#result', { state: 'visible', timeout: 60000 });
   280	    const dl = await Promise.all([
   281	      page.waitForEvent('download', { timeout: 30000 }),
   282	      page.click('#btnDownload'),
   283	    ]).then(a => a[0]).catch(() => null);
   284	    if (!dl) { rec(doc, tag, `output ${fmt}`, 'clean', 'no-download', false); return; }
   285	    const fp = path.join(OUT, doc.replace(/[\/\\]/g, '_').replace(/\.\w+$/, `_out.${fmt}`));
   286	    await dl.saveAs(fp);
   287	    const buf = fs.readFileSync(fp);
   288	
   289	    if (fmt === 'pdf') {
   290	      const chars = await page.evaluate(async (b64) => {
   291	        const bin = atob(b64); const arr = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
   292	        const pdf = await pdfjsLib.getDocument({ data: arr }).promise;
   293	        let n = 0;
   294	        for (let p = 1; p <= pdf.numPages; p++) { const tc = await (await pdf.getPage(p)).getTextContent(); n += tc.items.reduce((s, it) => s + (it.str || '').replace(/\s/g, '').length, 0); }
   295	        return n;
   296	      }, buf.toString('base64'));
   297	      rec(doc, 'TEXT_LEAK', `output ${fmt}`, '0 chars', `${chars} chars`, chars === 0);
   298	      // One %%EOF means one revision. An incremental save appends a second body
   299	      // + xref + %%EOF, leaving revision 1 (pre-redaction) readable in the file.
   300	      const eofs = (buf.toString('latin1').match(/%%EOF/g) || []).length;
   301	      rec(doc, tag, `output ${fmt} revisions`, '1 %%EOF', `${eofs} %%EOF`, eofs === 1);
   302	    }
   303	    const hits = scanMarkers(buf, fmt);
   304	    rec(doc, tag, `output ${fmt} metadata`, 'none', hits.length ? hits.join('+') : 'none', hits.length === 0);
   305	    if (fmt === 'jpg') { const icc = iccSafe(buf); rec(doc, tag, `output ${fmt} ICC`, `generic <=${ICC_MAX}B`, icc.note, icc.ok); }
   306	  } catch (e) { rec(doc, tag, `output ${fmt}`, 'clean', 'ERR:' + e.message.split('\n')[0], false); }
   307	}
   308	
   309	async function checkAiInject(page) {
   310	  const inj = SPECS.ai_inject; if (!inj) return;
   311	  await loadDoc(page, inj._doc, false);
   312	  for (const c of inj.cases) {
   313	    // fresh reload so each case is isolated
   314	    await loadDoc(page, inj._doc, false);
   315	    const res = await page.evaluate((ent) => {
   316	      const before = entities.length;
   317	      addEntities([ent]);
   318	      const added = entities.slice(before);
   319	      const mine = added.find(e => e.value === ent.value) || entities.find(e => e.value === ent.value && e.kind !== 'candidate' && e.type !== 'name-candidate');
   320	      const masked = window.__isMasked(ent.value);
   321	      return { present: !!mine, type: mine ? mine.type : null, mode: mine ? mine.mode : null, masked };
   322	    }, c.entity);
   323	    let pass, actual;
   324	    if (c.expect === 'masked') { pass = res.masked; actual = res.masked ? 'masked' : `not-masked(${res.type}/${res.mode})`; }
   325	    else if (c.expect === 'dropped') { pass = !res.present && !res.masked; actual = res.present ? `KEPT(${res.type}/${res.mode})` : 'dropped'; }
   326	    else { pass = !res.masked; actual = res.masked ? 'MASKED' : `visible(${res.type || 'dropped'}/${res.mode || '-'})`; }
   327	    rec('7_resume_dark.pdf', 'AI_INJECT', c.label + ` [${c.entity.type}:${c.entity.value}]`, c.expect, actual, pass);
   328	  }
   329	}
   330	
   331	async function checkAiCatState(page) {
   332	  const cs = SPECS.ai_cat_state; if (!cs) return;
   333	  await loadDoc(page, cs._doc, false);
   334	  const res = await page.evaluate(({ labels, want }) => {
   335	    // record active state BEFORE the AI merge, then inject AI labels
   336	    const before = {}; for (const t of want) before[t] = catEnabled[t] !== false;
   337	    addEntities(labels); renderAll();
   338	    const after = {}, boxChecked = {};
   339	    for (const t of want) {
   340	      after[t] = catEnabled[t] !== false;
   341	      const cb = document.querySelector(`#piiList input[data-cat="${t}"]`);
   342	      boxChecked[t] = cb ? cb.checked : null; // null = row not rendered (still a fail signal)
   343	    }
   344	    return { before, after, boxChecked };
   345	  }, { labels: cs.labels, want: cs.assert_enabled });
   346	  for (const t of cs.assert_enabled) {
   347	    const pass = res.after[t] === true && res.boxChecked[t] === true;
   348	    rec(cs._doc, 'AI_CAT_STATE', `${t} stays enabled`, 'on+checked',
   349	      `enabled=${res.after[t]} checked=${res.boxChecked[t]}`, pass);
   350	  }
   351	}
   352	
   353	async function checkCandidateDedup(page) {
   354	  const cd = SPECS.candidate_dedup; if (!cd) return;
   355	  for (const c of cd.cases) {
   356	    await loadDoc(page, cd._doc, false);   // fresh load so the base candidate is present
   357	    const res = await page.evaluate(({ cand, confirm }) => {
   358	      const before = window.__isCandidateContains(cand);
   359	      addEntities([confirm]); renderAll();
   360	      const after = window.__isCandidateContains(cand);
   361	      // Dedup must be directional: it removes redundant CANDIDATES, never the
   362	      // CONFIRMED entity that contains them. A reversed containment test (or a
   363	      // mutual-removal bug) would delete the confirmed name — leaving the value
   364	      // wholly UNMASKED. Assert the confirmed entity is still present after dedup.
   365	      // (Location isn't asserted here: these cases inject a superset value with a
   366	      // token absent from the fixture, so it is intentionally unlocated.)
   367	      const nc = window.__norm(confirm.value);
   368	      const confEnt = window.__entitySnapshot().find(e => e.kind !== 'candidate' && window.__norm(e.value) === nc);
   369	      return { before, after, confirmedSurvives: !!confEnt };
   370	    }, { cand: c.candidate, confirm: c.confirm });
   371	    let pass, actual;
   372	    if (c.expect === 'removed') {
   373	      pass = res.before && !res.after;
   374	      actual = !res.before ? 'not-present-before' : (res.after ? 'STILL present' : 'removed');
   375	    } else { // kept
   376	      pass = res.before && res.after;
   377	      actual = !res.before ? 'not-present-before' : (res.after ? 'kept' : 'DROPPED');
   378	    }
   379	    rec(cd._doc, 'CANDIDATE_DEDUP', `${c.label} [${c.confirm.value}]`, c.expect, actual, pass);
   380	    // Confirmed-preservation guard (the regression the candidate-only test missed):
   381	    // the confirmed entity that triggered the dedup must SURVIVE it.
   382	    rec(cd._doc, 'CONFIRMED_SURVIVES', `confirmed kept [${c.confirm.value}]`, 'survives',
   383	      res.confirmedSurvives ? 'survives' : 'REMOVED', res.confirmedSurvives);
   384	  }
   385	}
   386	
   387	/* ── JP golden ───────────────────────────────────────────────────────────────
   388	   Each JP fixture ships its own specs.json with a BOX TABLE in PNG pixel
   389	   coordinates plus, per 提出目的, which boxes must be hidden / recommended /
   390	   optional / kept. The harness replays that table against the live pipeline.
   391	
   392	   Coordinate frames: a PNG loads at its natural size, a PDF renders at
   393	   min(2.2, 1500/ptWidth) — so the mapping is a single uniform scale, taken at
   394	   runtime from page.w / fixtureWidth rather than hard-coded. A JPG fixture is
   395	   deliberately rotated and blurred (a phone photo), so its OCR boxes do NOT
   396	   land on the PNG coordinates; those cases assert at FIELD level instead and
   397	   say so, rather than quietly comparing coordinates that cannot match.
   398	
   399	   Which assertion a box gets comes from the LEGAL MATRIX level, not from which
   400	   list the fixture put it in — `mask` holds everything the purpose hides, at
   401	   both the automatic and the recommended strength, and those are different
   402	   promises. specs.json carries the key→level mapping (jp_auto_fields) so the
   403	   harness derives it independently of the app it is testing. */
   404	const JP_COVER_MIN = 0.6;      // a band must cover this much of a value/box
   405	const JP_KEEP_MAX = 0.10;      // a keep field may not be grazed by more than this
   406	function jpFieldOf(key) { return key.replace(/^m\d+_/, ''); }
   407	async function jpCheckBox(page, doc, cat, key, rect, kind) {
   408	  const items = await page.evaluate(r => window.__itemsIn(r), rect);
   409	  let frac, what;
   410	  if (items.length) {
   411	    // The meaningful question for a box holding text is whether the TEXT is
   412	    // covered — not whether the generator's padding around it was painted.
   413	    const fr = await Promise.all(items.map(it => page.evaluate(r => window.__coverage(r), it)));
   414	    frac = Math.min(...fr); what = `${items.length} item(s) min ${(frac * 100).toFixed(0)}%`;
   415	  } else {
   416	    frac = await page.evaluate(r => window.__coverage(r), rect); what = `area ${(frac * 100).toFixed(0)}%`;
   417	  }
   418	  if (kind === 'keep') { rec(doc, 'JP_KEEP', key, `<=${JP_KEEP_MAX * 100}%`, what, frac <= JP_KEEP_MAX); return; }
   419	  const covered = frac >= JP_COVER_MIN;
   420	  if (kind === 'mask') { rec(doc, 'JP_MASK', key, `>=${JP_COVER_MIN * 100}%`, what, covered); return; }
   421	  const cand = await page.evaluate(r => window.__candidateOver(r), rect);
   422	  if (kind === 'candidate') { rec(doc, 'JP_CANDIDATE', key, 'surfaced', cand ? (covered ? 'candidate+banded' : 'candidate') : 'MISSING', cand); return; }
   423	  if (kind === 'mask_or_candidate') {
   424	    rec(doc, 'JP_MASK_OR_CAND', key, 'banded or candidate', covered ? 'banded' : cand ? 'candidate' : 'NEITHER', covered || cand); return;
   425	  }
   426	  if (kind === 'optional') {   // detected, offered, and OFF until the user says so
   427	    rec(doc, 'JP_OPTIONAL', key, 'offered+clear', cand ? (frac <= JP_KEEP_MAX ? 'offered+clear' : 'OFFERED BUT BANDED') : 'MISSING', cand && frac <= JP_KEEP_MAX);
   428	  }
   429	}
   430	async function checkJpDoc(page, spec) {
   431	  const fx = JSON.parse(fs.readFileSync(path.join(__dirname, spec.fixture), 'utf8'));
   432	  const autoFields = (SPECS.jp_auto_fields || {})[spec.expect_doc] || [];
   433	  const mocFields = SPECS.jp_candidate_or_mask || [];
   434	  for (const c of spec.cases) {
   435	    const tag = `${spec.doc} [${c.purpose}]`;
   436	    await loadDoc(page, spec.doc, true);
   437	    await page.evaluate(p => jpSetPurpose(p), c.purpose);
   438	    const st = await page.evaluate(() => window.__jpState());
   439	    rec(tag, 'JP_CLASS', spec.expect_doc + (spec.expect_side ? '/' + spec.expect_side : ''), 'classified',
   440	      st.cls ? st.cls.doc + (st.cls.side ? '/' + st.cls.side : '') + ' sc=' + st.cls.score : 'NOT classified',
   441	      !!st.cls && st.cls.doc === spec.expect_doc && (!spec.expect_side || st.cls.side === spec.expect_side));
   442	    if (!st.cls) continue;
   443	    const autoCount = await page.evaluate(() => entities.filter(e => e.kind === 'auto').length);
   444	    process.stderr.write(`    [jp autoCount] ${tag} = ${autoCount}\n`);
   445	    if (c.min_auto != null) rec(tag, 'REGRESSION', `auto>=${c.min_auto}`, `>=${c.min_auto}`, String(autoCount), autoCount >= c.min_auto);
   446	    if (c.max_auto != null) rec(tag, 'REGRESSION', `auto<=${c.max_auto}`, `<=${c.max_auto}`, String(autoCount), autoCount <= c.max_auto);
   447	
   448	    // Field-level: every required field must have been FOUND. This is the only
   449	    // assertion a rotated phone-photo fixture can make, and it is also the one
   450	    // the 미탐 0 gate is actually about.
   451	    const got = new Set(st.fields.map(f => f.field));
   452	    for (const f of (c.require_fields || [])) rec(tag, 'JP_FIELD', f, 'detected', got.has(f) ? 'detected' : 'MISSING', got.has(f));
   453	    for (const f of (c.require_banded || [])) {
   454	      const on = st.fields.some(x => x.field === f && x.mode !== 'ok');
   455	      rec(tag, 'JP_BANDED', f, 'banded', on ? 'banded' : (got.has(f) ? 'DETECTED BUT CLEAR' : 'MISSING'), on);
   456	    }
   457	    // The inverse of require_banded, and the half that makes a purpose-gate test
   458	    // mean something: without it, "banded under 相談用共有" could be true simply
   459	    // because the field is banded under every purpose.
   460	    for (const f of (c.require_clear || [])) {
   461	      const hits = st.fields.filter(x => x.field === f);
   462	      const clear = hits.length > 0 && hits.every(x => x.mode === 'ok');
   463	      rec(tag, 'JP_CLEAR', f, 'detected+clear', hits.length ? (clear ? 'detected+clear' : 'BANDED') : 'MISSING', clear);
   464	    }
   465	    if (spec.geometry === false || c.geometry === false) continue;
   466	
   467	    const P = fx.purposes[c.key];
   468	    if (!P) { rec(tag, 'JP_SPEC', c.key, 'purpose in fixture', 'MISSING', false); continue; }
   469	    const scale = st.pw[0] / fx.size[0];
   470	    let checked = 0;
   471	    const box = k => { const b = fx.boxes_png[k]; return b && { pi: 0, x: b[0] * scale, y: b[1] * scale, w: (b[2] - b[0]) * scale, h: (b[3] - b[1]) * scale }; };
   472	    const seen = new Set(); const skipped = [];
   473	    const run = async (keys, kindFor) => {
   474	      for (const k of (keys || [])) {
   475	        if (k === 'ALL' || seen.has(k)) continue;
   476	        const r = box(k);
   477	        // The fixture's purpose list is shared across variants of the same
   478	        // document, so a key absent from THIS variant is not a case — but it is
   479	        // REPORTED, never silently dropped. A harness that quietly checks zero
   480	        // boxes prints the same green as one that checked forty.
   481	        if (!r) { skipped.push(k); continue; }
   482	        seen.add(k);
   483	        await jpCheckBox(page, tag, null, k, r, kindFor(k));
   484	        checked++;
   485	      }
   486	    };
   487	    // whole-face rule (マイナカード裏面 under a 本人確認 purpose)
   488	    if ((P.mask || []).includes('ALL')) {
   489	      const pg = await page.evaluate(() => ({ pi: 0, x: 0, y: 0, w: pages[0].w, h: pages[0].h }));
   490	      await jpCheckBox(page, tag, null, 'ALL(face)', pg, 'mask');
   491	      checked++;
   492	      for (const k of Object.keys(fx.boxes_png)) { const r = box(k); if (r) { await jpCheckBox(page, tag, null, k, r, 'mask'); checked++; } }
   493	      seen.add('ALL');
   494	    }
   495	    await run(P.mask, k => mocFields.includes(jpFieldOf(k)) ? 'mask_or_candidate'
   496	                        : autoFields.includes(jpFieldOf(k)) ? 'mask' : 'candidate');
   497	    await run(P.recommend, () => 'candidate');
   498	    await run(P.optional, () => 'optional');
   499	    await run(P.keep === 'all' ? [] : P.keep, () => 'keep');
   500	    rec(tag, 'JP_COVERAGE', `boxes checked (skipped: ${skipped.join(',') || 'none'})`, '>0', String(checked), checked > 0);
   501	    for (const fmt of (c.out_formats || [])) await checkOutput(page, tag, fmt);
   502	  }
   503	}
   504	
   505	/* ── JP unit rules ──────────────────────────────────────────────────────────
   506	   Two detection rules cannot be exercised by the alpha fixtures: none of the
   507	   four documents carries a phone number, and on all four the 住所 is a KEEP
   508	   field, so the address hierarchy's own scoring never decides anything there.
   509	   Shipping them with no coverage at all would be shipping untested detection,
   510	   so they are pinned at unit level against crafted strings — stated as such
   511	   rather than left to look like fixture coverage. */
   512	async function checkJpUnits(page) {
   513	  const U = SPECS.jp_units; if (!U) return;
   514	  for (const c of (U.address || [])) {
   515	    const got = await page.evaluate(t => {
   516	      const sp = jpAddressSpan(t, 0);
   517	      return sp ? { span: t.slice(sp.a, sp.b), score: sp.score, strong: !!(sp.postal && sp.pref) } : null;
   518	    }, c.text);
   519	    const ok = c.expect === null ? (got === null || got.score < 3)
   520	      : !!got && got.span === c.expect.span && got.score === c.expect.score && got.strong === !!c.expect.strong;
   521	    rec('(jp units)', 'JP_ADDRESS', c.label, c.expect === null ? 'no address' : `${c.expect.span} s=${c.expect.score}${c.expect.strong ? ' strong' : ''}`,
   522	      got ? `${got.span} s=${got.score}${got.strong ? ' strong' : ''}` : 'none', ok);
   523	  }
   524	  for (const c of (U.tel || [])) {
   525	    const got = await page.evaluate(t => {
   526	      const hy = JP_TEL_HYPHEN_RE.exec(t), pl = hy ? null : JP_TEL_PLAIN_RE.exec(t);
   527	      const m = hy || pl; return m ? { v: m[0], loose: !hy } : null;
   528	    }, c.text);
   529	    const ok = c.expect === null ? got === null
   530	      : !!got && got.v === c.expect.v && got.loose === !!c.expect.loose;
   531	    rec('(jp units)', 'JP_TEL', c.label, c.expect === null ? 'no match' : `${c.expect.v}${c.expect.loose ? ' (candidate)' : ''}`,
   532	      got ? `${got.v}${got.loose ? ' (candidate)' : ''}` : 'none', ok);
   533	  }
   534	}
   535	
   536	function printTable() {
   537	  const pad = (s, n) => { s = String(s); return s.length > n ? s.slice(0, n - 1) + '…' : s.padEnd(n); };
   538	  let lastDoc = '';
   539	  console.log('\n' + '═'.repeat(120));
   540	  console.log(pad('DOC', 20) + pad('CATEGORY', 17) + pad('ITEM', 40) + pad('EXPECTED', 18) + pad('ACTUAL', 18) + 'RESULT');
   541	  console.log('─'.repeat(120));
   542	  for (const r of rows) {
   543	    if (r.doc !== lastDoc) { console.log('─'.repeat(120)); lastDoc = r.doc; }
   544	    const mark = r.info ? (r.pass ? 'ℹ ok' : 'ℹ note') : (r.pass ? '✅ PASS' : '❌ FAIL');
   545	    console.log(pad(r.doc, 20) + pad(r.cat, 17) + pad(r.item, 40) + pad(r.expected, 18) + pad(r.actual, 18) + mark);
   546	  }
   547	  console.log('═'.repeat(120));
   548	  const gating = rows.filter(r => !r.info);
   549	  const fails = gating.filter(r => !r.pass);
   550	  const byCat = {};
   551	  for (const r of gating) { byCat[r.cat] = byCat[r.cat] || { p: 0, f: 0 }; r.pass ? byCat[r.cat].p++ : byCat[r.cat].f++; }
   552	  console.log('\nSummary by category:');
   553	  for (const [c, v] of Object.entries(byCat)) console.log(`  ${pad(c, 18)} ${v.p} pass / ${v.f} fail`);
   554	  console.log(`\n  TOTAL: ${gating.length - fails.length}/${gating.length} pass, ${fails.length} FAIL`);
   555	  if (fails.length) {
   556	    console.log('\n  Failing:');
   557	    for (const r of fails) console.log(`    ✗ [${r.doc}] ${r.cat} — ${r.item}  (expected ${r.expected}, got ${r.actual})`);
   558	  }
   559	  return fails.length;
   560	}
   561	
   562	(async () => {
   563	  const srv = await startServer();
   564	  const port = srv.address().port;
   565	  const URL = `http://127.0.0.1:${port}/safe/index.html`;
   566	  const browser = await chromium.launch({ channel: 'chrome', headless: true });
   567	  const ctx = await browser.newContext({ acceptDownloads: true, locale: 'ko-KR', viewport: { width: 1200, height: 900 } });
   568	  const page = await ctx.newPage();
   569	  const consoleErrors = [];
   570	  page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
   571	  page.on('pageerror', e => consoleErrors.push('PageError: ' + e.message));
   572	  await page.goto(URL, { waitUntil: 'networkidle' });
   573	  await page.evaluate(() => { LANG = 'ko'; applyLang(); });
   574	
   575	  const docs = SPECS.docs.filter(d => !onlyArg || d.doc === onlyArg);
   576	  for (const spec of docs) {
   577	    process.stderr.write(`… ${spec.doc}\n`);
   578	    try { await checkDoc(page, spec); }
   579	    catch (e) { rec(spec.doc, 'LOAD', spec.doc, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
   580	  }
   581	  for (const spec of (SPECS.jp_docs || [])) {
   582	    if (onlyArg && spec.doc !== onlyArg) continue;
   583	    process.stderr.write(`… ${spec.doc}\n`);
   584	    // The JP presets only exist in the Japanese UI, and OCR language follows it.
   585	    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
   586	    try { await checkJpDoc(page, spec); }
   587	    catch (e) { rec(spec.doc, 'LOAD', spec.doc, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
   588	    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
   589	  }
   590	  if (!onlyArg || onlyArg === '(jp units)') { process.stderr.write('… jp units\n'); await checkJpUnits(page); }
   591	  if (!onlyArg || onlyArg === '7_resume_dark.pdf') { process.stderr.write('… ai_inject\n'); await checkAiInject(page); }
   592	  if (!onlyArg || onlyArg === '7_resume_dark.pdf') { process.stderr.write('… ai_cat_state\n'); await checkAiCatState(page); }
   593	  if (!onlyArg || onlyArg === (SPECS.candidate_dedup && SPECS.candidate_dedup._doc)) { process.stderr.write('… candidate_dedup\n'); await checkCandidateDedup(page); }
   594	
   595	  const failCount = printTable();
   596	  if (consoleErrors.length) { console.log('\n  ⚠ console errors:'); consoleErrors.slice(0, 10).forEach(e => console.log('    ' + e)); }
   597	  fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify({ rows, consoleErrors }, null, 2));
   598	
   599	  await browser.close(); srv.close();
   600	  process.exit(failCount ? 1 : 0);
   601	})().catch(e => { console.error(e); process.exit(2); });
     1	{
     2	  "_readme": "Golden specification for the SafeFile PII pipeline. Each doc lists values that MUST be masked, MUST NOT be masked (geometrically covered), and values that should surface only as review CANDIDATES. Checked headlessly by run.mjs against the live detection in public/safe/index.html. never_candidate = value must not be proposed as a candidate at all. ai_inject = adversarial AI-label cases fed to addEntities (reproduces the real-doc name/country/org false positives without a live API).",
     3	
     4	  "_band_only": "2026-10-21: masking is band-only — a value is shown ('ok') or covered by an opaque band ('no'). The partial/asterisk mode and its PHONE_FORMAT assertions are gone: a partial overlay re-renders part of the secret, so its safety depends on how much we chose to reveal. MUST_MASK / MUST_NOT_MASK keep their meaning exactly (geometric coverage by an active mask rect) — the types that used to default to partial now default to band, which is strictly more covering. CANDIDATE_MODE now asserts 'ok': a review candidate is a guess and must not delete content before the user confirms it.",
     5	
     6	  "_max_auto_basis": "max_auto is a per-fixture CEILING on auto-detected entities — the false-positive regression guard. Without it the golden only proved 'we masked what we should' and a detection change shredded résumé body text while 95/95 stayed green. Ceilings measured 2026-07-20 against the fixed pipeline (actual auto counts: 1=9, 2=3, 3=3, 4=5, 5=10, 6=4, 7=2, 8=2). Headroom: deterministic text/table/résumé docs get a TIGHT ceiling (actual + ~2-3) so any new auto-mask of body text (schools, exam/contest names, countries) trips it; OCR docs (2,3) get a LOOSE ceiling (8) because Tesseract counts vary run-to-run and a tight bound would flake. The résumé docs 7/8 (actual 2 = phone+email only; everything else is candidate/excluded) are the primary guard — a ceiling of 4 catches the exact defect class this task fixed.",
     7	
     8	  "docs": [
     9	    {
    10	      "doc": "1_text.pdf", "type": "pdf", "ocr": false, "min_auto": 5, "max_auto": 12, "out_formats": ["pdf", "png", "jpg"],
    11	      "must_mask": ["900315-1234567", "010-2345-6789", "minjun.kim@hanmail.net", "010-9876-5432", "123456-04-789012"],
    12	      "must_not_mask": ["한빛테크"],
    13	      "should_candidate": [],
    14	      "never_candidate": ["한빛테크"]
    15	    },
    16	    {
    17	      "doc": "2_scanned.pdf", "type": "pdf", "ocr": true, "min_auto": 3, "max_auto": 8,
    18	      "must_mask": [], "must_not_mask": [], "should_candidate": [], "never_candidate": []
    19	    },
    20	    {
    21	      "doc": "3_photo.jpg", "type": "image", "ocr": true, "min_auto": 3, "max_auto": 8, "out_formats": ["png", "jpg"],
    22	      "must_mask": [], "must_not_mask": [], "should_candidate": [], "never_candidate": []
    23	    },
    24	    {
    25	      "doc": "4_table.pdf", "type": "pdf", "ocr": false, "min_auto": 4, "max_auto": 8,
    26	      "must_mask": ["870915-1234567", "010-3456-7890", "daeho@corp.com", "110-234-567890"],
    27	      "must_not_mask": [], "should_candidate": [], "never_candidate": []
    28	    },
    29	    {
    30	      "doc": "5_multipage.pdf", "type": "pdf", "ocr": false, "min_auto": 9, "max_auto": 13,
    31	      "must_mask": ["900315-1234567", "920820-2345678", "880505-1234567", "minjun@a.com", "seoyeon@b.com", "doyoon@c.com"],
    32	      "must_not_mask": [], "should_candidate": [], "never_candidate": []
    33	    },
    34	    {
    35	      "doc": "6_resume_light.pdf", "type": "pdf", "ocr": false, "min_auto": 3, "max_auto": 7,
    36	      "must_mask": ["+91 9599320477", "aarav.sharma@gmail.com"],
    37	      "_note_ai_only": "English street addresses (e.g. 'Signature Global Mall, Sector 84') are detected only by the AI deep-scan path, not the deterministic regex path this harness exercises.",
    38	      "must_not_mask": ["Delhi University", "Maharaja Agrasen College", "Saket", "Imphal"],
    39	      "should_candidate": ["Aarav Sharma"],
    40	      "candidate_mode": {"Aarav Sharma": "ok"},
    41	      "never_candidate": ["Delhi University", "Maharaja Agrasen College"],
    42	      "name_bar": "Aarav Sharma"
    43	    },
    44	    {
    45	      "doc": "7_resume_dark.pdf", "type": "pdf", "ocr": false, "min_auto": 2, "max_auto": 4,
    46	      "must_mask": ["+91 9599320477", "aarav.sharma@gmail.com"],
    47	      "must_not_mask": [
    48	        "Delhi University", "Maharaja Agrasen College", "Vidya Niketan School",
    49	        "King Sejong Institute", "Concern India Foundation", "Korea",
    50	        "Koreaz Contest", "Imphal", "Saket", "India"
    51	      ],
    52	      "should_candidate": ["Aarav Sharma", "Signature Global"],
    53	      "candidate_mode": {"Aarav Sharma": "ok", "Signature Global": "ok"},
    54	      "never_candidate": [
    55	        "Korea", "Maharaja Agrasen College", "Vidya Niketan School",
    56	        "King Sejong Institute", "Concern India Foundation", "Delhi University", "Imphal"
    57	      ],
    58	      "name_bar": "Aarav Sharma",
    59	      "dark_bg_value": "aarav.sharma@gmail.com"
    60	    },
    61	    {
    62	      "doc": "8_resume_2col.pdf", "type": "pdf", "ocr": false, "min_auto": 2, "max_auto": 4,
    63	      "_note": "Regression for real-résumé defects: (1) a 3-token name in a 2-column layout whose surname renders slightly smaller must stay whole and be fully maskable (surname included) — activate_name turns the name candidate on, then must_mask asserts every token incl. the surname is covered; (2) a country inside a WRAPPED flowing sentence whose tail line reads 'Republic of Korea (Koreaz Contest)' must not be proposed as an address candidate (the old <=2-word country-anchor cap let the 3-word 'Republic of Korea' slip past); the isolated 'Korea (Koreaz Contest)' line is covered too. Koreaz Contest is a contest name (not PII) and must never be masked.",
    64	      "activate_name": "Ishan Rohit Malhotra",
    65	      "must_mask": ["Ishan Rohit Malhotra", "Malhotra", "+91 9599320477", "ishan.malhotra@gmail.com"],
    66	      "must_not_mask": ["Software Engineer", "Delhi University", "Maharaja Agrasen College", "Koreaz Contest", "Republic of Korea (Koreaz Contest)"],
    67	      "should_candidate": [],
    68	      "never_candidate": ["Republic of Korea (Koreaz Contest)", "Korea (Koreaz Contest)", "Korea", "Maharaja Agrasen College", "Delhi University"]
    69	    },
    70	    {
    71	      "doc": "9_resume_2line.pdf", "type": "pdf", "ocr": false, "min_auto": 2, "max_auto": 4,
    72	      "_note": "Regression for the real-résumé defect where the header name WRAPS onto two visual lines (given names on line 1, surname on its own line 2, same large font). The old name-line assembly grew only horizontally within the anchor row, so it captured 'MANSI GAZAL' and left the whole second line 'TIWARI' exposed — the name surfaced only as a truncated 'MANSI GAZAL' candidate. Detection must assemble the wrapped name whole: the candidate is 'MANSI GAZAL TIWARI' and activating it covers BOTH lines incl. the surname. The smaller-font subtitle 'Software Developer' must NOT be merged into the name (a merge would either mask the subtitle or fail isLikelyName and drop the name).",
    73	      "activate_name": "MANSI GAZAL TIWARI",
    74	      "must_mask": ["MANSI GAZAL TIWARI", "TIWARI", "+91 98765 43210", "mansi.tiwari@example.com"],
    75	      "must_not_mask": ["Software Developer", "Delhi University"],
    76	      "should_candidate": ["MANSI GAZAL TIWARI"],
    77	      "never_candidate": ["Software Developer", "Delhi University"]
    78	    }
    79	  ],
    80	
    81	  "_jp_basis": "JP-1 alpha. Fixtures live in fixtures/jp/<doc>/<variant>.{png,jpg,pdf} with a sibling .specs.json carrying a BOX TABLE in PNG pixels plus, per 提出目的, which boxes the purpose hides / recommends / offers / keeps. The harness replays that table against the live pipeline, so the expectations are the fixture's, not the detector's. PNG and PDF differ from the table by one uniform scale (taken at runtime from page.w / fixture width); the JPG variants are rotated and blurred on purpose (phone photo), so their OCR boxes cannot land on those coordinates and those cases assert at FIELD level instead — detected, and banded — which is what the 미탐 0 gate is actually about.",
    82	
    83	  "jp_auto_fields": {
    84	    "_why": "The fixture's `mask` list holds every box the purpose hides, at BOTH the automatic and the recommended strength — those are different promises, so the harness has to know which is which independently of the app it is testing. This table is the legal matrix's `level` field (jp_legal_matrix_alpha4.json), keyed by fixture box name with the m<N>_ household prefix stripped. Anything NOT listed here that appears under `mask` is level=recommend and is asserted as a surfaced review candidate.",
    85	    "shikaku_kakuninsho": ["hokensha_bango", "kigo", "bango", "edaban", "hihokensha_bango", "qr"],
    86	    "unten_menkyo": [],
    87	    "mynumber_card": ["my_number", "qr"],
    88	    "juminhyo": ["my_number", "jumin_code"]
    89	  },
    90	  "jp_candidate_or_mask": ["my_number"],
    91	  "_jp_candidate_or_mask_why": "個人番号 is level=auto_with_purpose_gate, but strategy v2 §4 requires every dummy's number to FAIL its check digit (生成 of a valid one is forbidden). A correct implementation must therefore refuse to assert 'this is a 個人番号' and demote the automatic band to a default-ON review candidate. Asserting a hard band here would make the golden reward the wrong behaviour; asserting only a candidate would let a real regression (never detecting it) pass. So: banded OR surfaced, and the demotion reason is checked separately via the entity note.",
    92	
    93	  "jp_docs": [
    94	    { "doc": "jp/shikaku_kakuninsho/kenpo.png", "fixture": "fixtures/jp/shikaku_kakuninsho/kenpo.specs.json", "expect_doc": "shikaku_kakuninsho",
    95	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "min_auto": 4, "max_auto": 8,
    96	                  "require_fields": ["kigo", "bango", "edaban", "hokensha_bango", "qr", "sex"],
    97	                  "require_banded": ["kigo", "bango", "edaban", "hokensha_bango", "qr"],
    98	                  "out_formats": ["png", "jpg"] }] },
    99	    { "doc": "jp/shikaku_kakuninsho/kokuho.png", "fixture": "fixtures/jp/shikaku_kakuninsho/kokuho.specs.json", "expect_doc": "shikaku_kakuninsho",
   100	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "min_auto": 4, "max_auto": 8,
   101	                  "require_banded": ["kigo", "bango", "edaban", "hokensha_bango", "qr"] }] },
   102	    { "doc": "jp/shikaku_kakuninsho/kouki.png", "fixture": "fixtures/jp/shikaku_kakuninsho/kouki.specs.json", "expect_doc": "shikaku_kakuninsho",
   103	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "min_auto": 2, "max_auto": 8,
   104	                  "require_banded": ["hokensha_bango", "qr"] }] },
   105	
   106	    { "doc": "jp/unten_menkyo/front.png", "fixture": "fixtures/jp/unten_menkyo/front.specs.json", "expect_doc": "unten_menkyo", "expect_side": "front",
   107	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "max_auto": 2, "require_fields": ["license_no"] }] },
   108	    { "doc": "jp/unten_menkyo/back.png", "fixture": "fixtures/jp/unten_menkyo/back.specs.json", "expect_doc": "unten_menkyo", "expect_side": "back",
   109	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "max_auto": 2,
   110	                  "require_banded": ["biko_change", "organ_donor"],
   111	                  "require_clear": ["address_loose"] }] },
   112	
   113	    { "doc": "jp/unten_menkyo/back.png", "fixture": "fixtures/jp/unten_menkyo/back.specs.json", "expect_doc": "unten_menkyo", "expect_side": "back", "geometry": false,
   114	      "_why": "Same document, same field, two 提出目的, opposite outcomes — the purpose gate is the product, so one case has to prove it actually moves. The 備考欄 carries a free-standing 住所変更 line: for 本人確認提出 that address is `optional` (offered, left clear — see the geometry case above), for 相談用共有 it is `recommend` (banded by default). Geometry is off because the fixture's box table only declares the 本人確認提出 purpose.",
   115	      "cases": [{ "purpose": "consult_share", "key": "本人確認提出", "max_auto": 2,
   116	                  "require_fields": ["address_loose"], "require_banded": ["address_loose", "biko_change", "organ_donor"] }] },
   117	
   118	    { "doc": "jp/mynumber_card/front.png", "fixture": "fixtures/jp/mynumber_card/front.specs.json", "expect_doc": "mynumber_card", "expect_side": "front",
   119	      "cases": [{ "purpose": "identity_submit", "key": "身元確認", "max_auto": 2,
   120	                  "require_banded": ["sex", "organ_donor"] }] },
   121	    { "doc": "jp/mynumber_card/back.png", "fixture": "fixtures/jp/mynumber_card/back.specs.json", "expect_doc": "mynumber_card", "expect_side": "back",
   122	      "cases": [{ "purpose": "identity_submit", "key": "身元確認", "min_auto": 1, "max_auto": 3,
   123	                  "require_banded": ["back_all", "my_number"], "out_formats": ["pdf"] },
   124	                { "purpose": "my_number_procedure", "key": "個人番号手続", "max_auto": 1,
   125	                  "require_fields": ["my_number"] }] },
   126	
   127	    { "doc": "jp/juminhyo/zenin_mynumber.png", "fixture": "fixtures/jp/juminhyo/zenin_mynumber.specs.json", "expect_doc": "juminhyo",
   128	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "min_auto": 1, "max_auto": 4,
   129	                  "require_fields": ["my_number", "jumin_code", "honseki", "hittosha", "setaiin"],
   130	                  "require_banded": ["jumin_code", "setaiin"] },
   131	                { "purpose": "my_number_procedure", "key": "個人番号手続", "max_auto": 2,
   132	                  "require_banded": ["honseki"] }] },
   133	    { "doc": "jp/juminhyo/ichibu_plain.png", "fixture": "fixtures/jp/juminhyo/ichibu_plain.specs.json", "expect_doc": "juminhyo",
   134	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "max_auto": 2 }] },
   135	    { "doc": "jp/juminhyo/honseki_on.png", "fixture": "fixtures/jp/juminhyo/honseki_on.specs.json", "expect_doc": "juminhyo",
   136	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "max_auto": 2, "require_banded": ["honseki", "hittosha"] },
   137	                { "purpose": "my_number_procedure", "key": "個人番号手続", "max_auto": 2, "require_banded": ["honseki"] }] },
   138	    { "doc": "jp/juminhyo/gaikokujin.png", "fixture": "fixtures/jp/juminhyo/gaikokujin.specs.json", "expect_doc": "juminhyo",
   139	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "max_auto": 2 }] },
   140	
   141	    { "doc": "jp/shikaku_kakuninsho/kenpo.pdf", "fixture": "fixtures/jp/shikaku_kakuninsho/kenpo.specs.json", "expect_doc": "shikaku_kakuninsho",
   142	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "min_auto": 4, "max_auto": 8,
   143	                  "require_banded": ["kigo", "bango", "edaban", "hokensha_bango", "qr"], "out_formats": ["pdf"] }] },
   144	
   145	    { "doc": "jp/shikaku_kakuninsho/kenpo.jpg", "fixture": "fixtures/jp/shikaku_kakuninsho/kenpo.specs.json", "expect_doc": "shikaku_kakuninsho", "geometry": false,
   146	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "min_auto": 4, "max_auto": 8,
   147	                  "require_banded": ["kigo", "bango", "edaban", "hokensha_bango", "qr"] }] },
   148	    { "doc": "jp/juminhyo/zenin_mynumber.jpg", "fixture": "fixtures/jp/juminhyo/zenin_mynumber.specs.json", "expect_doc": "juminhyo", "geometry": false,
   149	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "min_auto": 1, "max_auto": 4,
   150	                  "require_fields": ["my_number", "jumin_code"], "require_banded": ["jumin_code", "my_number"] }] },
   151	    { "doc": "jp/mynumber_card/back.jpg", "fixture": "fixtures/jp/mynumber_card/back.specs.json", "expect_doc": "mynumber_card", "expect_side": "back", "geometry": false,
   152	      "cases": [{ "purpose": "identity_submit", "key": "身元確認", "min_auto": 1, "max_auto": 3,
   153	                  "require_banded": ["back_all", "my_number"], "out_formats": ["jpg"] }] }
   154	  ],
   155	  "jp_units": {
   156	    "_why": "The alpha fixtures cannot exercise these two rules: none of the four documents carries a phone number, and on all four the 住所 is a KEEP field, so the address hierarchy never gets to decide anything there. Pinning them at unit level is the honest alternative to shipping untested detection — and it states what it is, instead of looking like fixture coverage. Scores: 郵便番号 +2, 都道府県 +2, 市区郡町村 +1, 丁目番地号 +2, institution word within/near the span −2. Automatic only with 郵便番号 AND 都道府県 together (strong); score >= 3 is a review candidate; below that, nothing.",
   157	    "address": [
   158	      { "label": "都道府県+市区+丁目番地号", "text": "住所東京都千代田区霞が関1丁目2番3号", "expect": { "span": "東京都千代田区霞が関1丁目2番3号", "score": 5 } },
   159	      { "label": "郵便番号を伴う → strong (自動)", "text": "〒100-8926東京都千代田区霞が関1-3-2", "expect": { "span": "〒100-8926東京都千代田区霞が関1-3-2", "score": 7, "strong": true } },
   160	      { "label": "漢数字の丁目番号も拾う", "text": "本籍京都府京都市中京区三条通一丁目二番三号", "expect": { "span": "京都府京都市中京区三条通一丁目二番三号", "score": 5 } },
   161	      { "label": "架空の県名はアンカーにならない（保険者名）", "text": "保険者名架空県後期高齢者医療広域連合", "expect": null },
   162	      { "label": "発行者名（見本市長）を住所と読まない", "text": "見本市長架空太郎（公印省略）", "expect": null },
   163	      { "label": "株式会社名を住所と読まない", "text": "事業所名称架空株式会社", "expect": null },
   164	      { "label": "機関名は減点 — 部分一致は閾値割れ", "text": "大阪府見本市役所", "expect": null },
   165	      { "label": "完全な住所は機関名が続いても候補として残る", "text": "東京都新宿区西新宿2丁目8番1号新宿区役所", "expect": { "span": "東京都新宿区西新宿2丁目8番1号", "score": 3 } }
   166	    ],
   167	    "tel": [
   168	      { "label": "市外局番2桁", "text": "電話03-1234-5678", "expect": { "v": "03-1234-5678" } },
   169	      { "label": "携帯", "text": "携帯090-1234-5678", "expect": { "v": "090-1234-5678" } },
   170	      { "label": "フリーダイヤル 0120", "text": "TEL0120-123-456", "expect": { "v": "0120-123-456" } },
   171	      { "label": "フリーダイヤル 0800", "text": "FAX0800-123-4567", "expect": { "v": "0800-123-4567" } },
   172	      { "label": "ハイフンなしは候補どまり", "text": "電話番号09012345678", "expect": { "v": "09012345678", "loose": true } },
   173	      { "label": "11桁を超える数字列は電話ではない", "text": "個人番号720463027637", "expect": null }
   174	    ]
   175	  },
   176	  "ai_inject": {
   177	    "_doc": "7_resume_dark.pdf",
   178	    "cases": [
   179	      {"label": "college labelled as person name", "entity": {"type": "name", "value": "Maharaja Agrasen College"}, "expect": "not_masked"},
   180	      {"label": "foundation labelled as person name", "entity": {"type": "name", "value": "Concern India Foundation"}, "expect": "not_masked"},
   181	      {"label": "institute labelled as name", "entity": {"type": "name", "value": "King Sejong Institute"}, "expect": "not_masked"},
   182	      {"label": "lone country labelled as address", "entity": {"type": "address", "value": "Korea"}, "expect": "dropped"},
   183	      {"label": "lone country labelled as name", "entity": {"type": "name", "value": "India"}, "expect": "dropped"},
   184	      {"label": "country adjective labelled as name", "entity": {"type": "name", "value": "Indian"}, "expect": "dropped"},
   185	      {"label": "country+parenthetical labelled as address", "entity": {"type": "address", "value": "Korea (Koreaz Contest)"}, "expect": "dropped"},
   186	      {"label": "exam name labelled 'other' stays visible", "entity": {"type": "other", "value": "TOPIK"}, "expect": "not_masked"},
   187	      {"label": "exam name with UNKNOWN type → 'other', visible", "entity": {"type": "certificate", "value": "TOPIK"}, "expect": "not_masked"},
   188	      {"label": "contest name labelled 'other' stays visible", "entity": {"type": "other", "value": "Koreaz Contest"}, "expect": "not_masked"},
   189	      {"label": "genuine body name (positive control)", "entity": {"type": "name", "value": "Rohan Mehta"}, "expect": "masked"}
   190	    ]
   191	  },
   192	
   193	  "ai_cat_state": {
   194	    "_doc": "7_resume_dark.pdf",
   195	    "_note": "After an AI deep-scan injects name/company labels, the category ACTIVE state (checkbox) must stay ON — a disabled name category would silently leave names unmasked when the user trusts the AI and just builds. Asserts catEnabled stays true and the rendered checkbox stays checked.",
   196	    "labels": [
   197	      {"type": "name", "value": "Rohan Mehta"},
   198	      {"type": "company", "value": "Globex Solutions Pvt Ltd"}
   199	    ],
   200	    "assert_enabled": ["name", "company"]
   201	  },
   202	
   203	  "candidate_dedup": {
   204	    "_doc": "6_resume_light.pdf",
   205	    "_note": "A CONFIRMED entity whose value wholly contains a review candidate (as whole space-separated tokens) makes that candidate redundant — the confirmed mask already covers it — so the candidate must be removed. Reproduces confirmed 'MANSI GAZAL TIWARI' hiding candidate 'MANSI GAZAL'. Directional: only the shorter, fully-contained candidate is dropped; a candidate that ADDS a token beyond the confirmed value must be kept (removing it would lose coverage). The base doc surfaces 'Aarav Sharma' as a name candidate; each case injects a confirmed name and asserts the candidate is dropped/kept accordingly. Old code (no dedupe) leaves the candidate in place, so the 'removed' case fails on it.",
   206	    "cases": [
   207	      {"label": "candidate contained in confirmed name is removed", "candidate": "Aarav Sharma", "confirm": {"type": "name", "value": "Aarav Sharma Verma"}, "expect": "removed"},
   208	      {"label": "candidate adding a token beyond confirmed is kept", "candidate": "Aarav Sharma", "confirm": {"type": "name", "value": "Aarav"}, "expect": "kept"}
   209	    ]
   210	  }
   211	}

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "git show 546344b:test/safe/fixtures/jp/jp_legal_matrix_alpha4.json | nl -ba; git show 546344b:docs/jp/jp_safefile_strategy_v2_2026-10-21.md | nl -ba; git show 546344b:docs/jp/s3_report.md | nl -ba | sed -n '1,380p'; git show 546344b:CLAUDE.md | nl -ba | sed -n '/JP-1/,/"'^[''^ ]/p'"'" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
     1	{
     2	  "version": "2026-10-21",
     3	  "scope": "SafeFile JP 알파 4종. 규칙은 제출 목적(purpose)별. 출처 없는 규칙은 verified=false로 표기하고 자동 마스킹 금지.",
     4	  "purposes": {
     5	    "identity_submit": "本人確認書類として提出（銀行・カード・通信・フリマ・賃貸）",
     6	    "my_number_procedure": "個人番号関係事務（税・社会保障・勤務先提出）",
     7	    "bid_attachment": "入札・許可申請への添付",
     8	    "consult_share": "専門家・SNS等への相談用共有"
     9	  },
    10	  "documents": [
    11	    {
    12	      "id": "shikaku_kakuninsho", "name": "資格確認書", "replaces": "健康保険証（2025-12-01 失効・暫定2026-07-31終了）",
    13	      "variants": ["被用者保険(協会けんぽ・健保組合)", "国民健康保険", "後期高齢者医療"],
    14	      "fields_common": ["氏名", "生年月日", "性別", "住所", "資格取得年月日", "有効期限", "保険者番号", "保険者名", "記号/番号/枝番 または 被保険者番号"],
    15	      "fields_issuer_specific": ["事業所名称", "二次元コード", "一部負担金割合", "自己負担限度額区分"],
    16	      "rules": [
    17	        {"field": "保険者番号・記号・番号・枝番・被保険者番号", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": [], "level": "auto",
    18	         "legal_basis": "健康保険法等 告知要求制限（2020-10-01施行）: 医療保険事務以外の目的での告知要求を原則禁止。提出先が受領する場合もマスキングを求める運用",
    19	         "source": ["https://www.mhlw.go.jp/stf/newpage_13989.html", "https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf", "https://www.kyosai.metro.tokyo.jp/assets/84b47fd406a8378372a6015863f83bc93c0c8a75.pdf"], "verified": true},
    20	        {"field": "二次元コード", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "level": "auto", "legal_basis": "番号を判読可能なため同一扱い（大阪府・千葉市運用）", "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"], "verified": true},
    21	        {"field": "性別", "mask_when": ["identity_submit"], "level": "recommend", "legal_basis": "法定ではない。民間KYC事業者の運用（SoftBank, PayPay銀行等）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
    22	        {"field": "氏名・生年月日・住所・有効期限", "mask_when": [], "must_keep_when": ["identity_submit", "bid_attachment"], "level": "keep", "legal_basis": "本人特定事項。マスキングすると受付不可", "source": ["https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html"], "verified": true}
    23	      ]
    24	    },
    25	    {
    26	      "id": "unten_menkyo", "name": "運転免許証", "sides": ["表", "裏"],
    27	      "fields_front": ["氏名", "生年月日", "住所", "交付日", "有効期限", "免許の条件", "番号(12桁)", "種類・取得日", "顔写真", "公安委員会名"],
    28	      "fields_back": ["備考欄（住所・氏名等の変更記載）", "臓器提供意思表示欄"],
    29	      "note": "本籍は券面に印字されない（ICチップ内）",
    30	      "rules": [
    31	        {"field": "裏面 備考欄（変更記載）", "mask_when": ["identity_submit", "consult_share"], "level": "recommend", "legal_basis": "旧住所等の不要情報。提出先指示優先（住所変更確認で裏面が必要な場合あり）", "source": ["https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true},
    32	        {"field": "臓器提供意思表示欄", "mask_when": ["identity_submit", "consult_share"], "level": "recommend", "legal_basis": "民間KYC運用（SoftBank: 臓器提供意思をマスキング）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
    33	        {"field": "番号(12桁)", "mask_when": ["consult_share"], "must_keep_when": ["identity_submit"], "level": "optional", "legal_basis": "個人識別符号（個人情報保護法施行令）。KYCでは照合に必要な提出先が多い", "source": [], "verified": false},
    34	        {"field": "氏名・生年月日・住所・有効期限・顔写真", "must_keep_when": ["identity_submit"], "level": "keep", "verified": true, "source": ["https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html"]}
    35	      ]
    36	    },
    37	    {
    38	      "id": "mynumber_card", "name": "マイナンバーカード（個人番号カード）", "sides": ["表", "裏"],
    39	      "fields_front": ["氏名", "住所", "生年月日", "性別", "有効期限", "顔写真", "券面記載事項追記欄", "臓器提供意思表示欄"],
    40	      "fields_back": ["個人番号", "氏名", "生年月日(要確認)", "二次元コード"],
    41	      "unverified": ["裏面の生年月日印字有無"],
    42	      "rules": [
    43	        {"field": "裏面全体", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": ["my_number_procedure"], "level": "auto_with_purpose_gate",
    44	         "legal_basis": "番号法: 法令で認められた者・目的以外での個人番号の収集・保管禁止。身元確認目的では裏面を提出しない", "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/", "https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true},
    45	        {"field": "表面 性別・臓器提供意思表示欄", "mask_when": ["identity_submit"], "level": "recommend", "legal_basis": "民間KYC運用", "source": ["https://www.aspicjapan.org/asu/article/6908"], "verified": true},
    46	        {"field": "表面 氏名・住所・生年月日・有効期限・顔写真", "must_keep_when": ["identity_submit", "my_number_procedure"], "level": "keep", "verified": true, "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"]}
    47	      ]
    48	    },
    49	    {
    50	      "id": "juminhyo", "name": "住民票の写し",
    51	      "variants": ["世帯全員/一部", "個人番号 あり/なし", "本籍・筆頭者 あり/なし", "外国人住民（国籍・在留資格・在留期間・在留カード番号）", "住民票コード付（窓口のみ）"],
    52	      "rules": [
    53	        {"field": "個人番号", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": ["my_number_procedure"], "level": "auto_with_purpose_gate", "legal_basis": "番号法 収集制限。本人確認目的なら個人番号なしの住民票を取り直すのが原則", "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"], "verified": true},
    54	        {"field": "住民票コード", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "level": "auto", "legal_basis": "住民基本台帳法 利用制限（個人識別符号）", "source": [], "verified": false},
    55	        {"field": "本籍・筆頭者", "mask_when": ["identity_submit", "consult_share"], "level": "recommend", "legal_basis": "民間KYC運用（SoftBank: 住民票の本籍をマスキング）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
    56	        {"field": "本人以外の世帯員", "mask_when": ["identity_submit", "consult_share"], "level": "recommend", "legal_basis": "第三者情報。提出先が世帯全員を要求する場合は維持", "source": [], "verified": false},
    57	        {"field": "氏名・生年月日・住所・発行日・発行者", "must_keep_when": ["identity_submit", "bid_attachment"], "level": "keep", "verified": true, "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"]}
    58	      ]
    59	    }
    60	  ],
    61	  "levels": {"auto": "文書分類+ラベル一致で自動黒塗り", "auto_with_purpose_gate": "目的選択後に自動（別目的では解除）", "recommend": "既定ON・解除可", "optional": "既定OFF・選択可", "keep": "黒塗り禁止（警告）"}
    62	}
     1	# SafeFile 일본 진출 전략 v2 (2026-10-21) — Codex 독립 검토 반영
     2	
     3	> v1(10-20) → Codex 검토(10-21) → Claude 교차검증 → v2. 변경 근거는 §0에 모두 기록.
     4	
     5	---
     6	
     7	## 0. Codex 지적 처리표 (수용 / 부분수용 / 반려)
     8	
     9	| # | Codex 지적 | 판정 | 처리 |
    10	|---|---|---|---|
    11	| 1-1 | 타임즈카 날짜·자료유형 혼합. 住民票는 공식 목록에 없음 | **수용** | 9/25 탐지·1보, 9/28 660만 확인, 9/29 160만 본인확인서류 확인으로 분리. 住民票→現住所確認書類(公共料金請求書等). 단 共同通信 보도에는 "住民票の写し"가 언급됨 → "보도상 언급, 공식 목록 미포함"으로 병기 |
    12	| 1-2 | 집단소송 1만5천 명 근거 없음 | **반려(근거 보강)** | 출처는 共同通信 10/3 기사(sn-hoki 전재: "2日午後9時までに1万5千人以上が登録"). 다만 "参加意思表明 등록자"이지 원고 수가 아님 → 표현 수정 |
    13	| 1-3 | 告知要求制限을 "보편 의무"로 과장. 性別·枝番은 법정 항목 아님 | **수용** | "의료보험 사무 외 목적의 요구 제한, 예외 있음, QR은 번호 판독 가능 시 동일 취급"으로 한정. 性別은 법 밖(실무 권고)으로 분리 |
    14	| 1-4 | 資格確認書 필드가 보험자별 상이. 通院歴 삭제 | **수용** | 구 보험증/資格確認書 분리. 필드를 common / issuer_specific으로 |
    15	| 1-5 | マイナカード 裏面 "절대 금지" 과장. 臓器提供欄은 앞면 | **수용** | 목적 선택(身元確認 / 個人番号手続) → 기본 전체 가림 → 명시 해제. 臓器提供欄 앞면으로 정정. 裏面 生年月日 유무는 **확인 필요**(상충) |
    16	| 1-6 | 2027-04 IC칩은 犯収法 특정사업자 한정 | **수용** | "구멍" 표현 삭제. 콘텐츠 16번 제도 해설로 재작성 |
    17	| 2-1 | always/optional 단일 규칙은 제출 목적 무시 | **수용(핵심)** | `purpose` 축 도입: `mask_when_purpose` / `must_keep_when_purpose` / `legal_basis` / `source_url` |
    18	| 2-2 | 免許証 本籍은 권면에 없음(IC칩) | **수용** | 권면 필드에서 本籍 제거, 裏面은 備考欄(変更記載) |
    19	| 2-4 | 구 健康保険証 2025-12-01 실효, 잠정 2026-07-31 종료 | **수용** | 資格確認書를 주 문서로, 구 보험증은 legacy fixture |
    20	| 2-5~2-10 | 문서 묶음 과다, 출처 약함 | **수용** | jp10·jp12·jp13 분리. 출처 없는 always 금지 |
    21	| 2-11 | 누락 문서 11종 | **부분수용** | v2 범위엔 넣지 않음(알파 4종 집중). 백로그에 등재 |
    22	| 3-1 | 카탈로그 패턴이 실제 코드에 없음 | **수용** | S1 "완료" 취소 → "조사 완료, 구현 0" |
    23	| 3-2~3-6 | 정규식 오탐·미탐, NFKC 좌표 역매핑 | **수용** | 정규식 단독 자동마스킹 금지. 레이블 앵커+문서분류+체크디지트 3단. 원문↔정규화 인덱스 매핑 필수 |
    24	| 4-1 | 25–39 연령 타깃 근거 없음 | **수용** | 연령 폐기 → 제출 목적 4종으로 세그먼트 |
    25	| 4-2 | 서버형 書類ボックス는 개인정보 취급 발생, 메시지 충돌 | **수용** | 서버 보관 철회. 초기 유료화는 로컬 보관(PWA/IndexedDB 암호화)+내보내기 |
    26	| 5-1 | 실물 동일 레이아웃+유효 체크디지트 더미는 위험 | **수용** | 비실물 도식형 더미로 전환. 조건 §4 참조. 유효 체크디지트 생성 금지 |
    27	| 6-1 | 채널을 전체 이용률로만 선정 | **부분수용** | 검색(SEO) 랜딩을 핵심 축으로 추가. X·Shorts·Reels는 유지하되 2주 전환 측정 후 배분 |
    28	| 6-2 | 위험·과장 제목 10건 | **수용** | §6 제목 전면 재작성. "絶対/防ぐ/べき" 금지 |
    29	| 6-3 | 가상 1인칭 피해담 금지 | **수용** | 공식 발표 사실 인용의 비개인 해설로 제한. 소송·재교부 안내와 CTA 분리 |
    30	| 7-1~7-3 | 2주 13종 비현실. 4종 알파로 축소 | **수용** | §7 일정 재편 |
    31	
    32	---
    33	
    34	## 1. 사실 정리 (정정판)
    35	
    36	- 2026-09-25 タイムズカー 부정 접근 탐지·제1보 → 09-28 약 660만 계정 정보 취득 확인(제2보) → 09-29 그중 약 160만 계정에서 본인확인서류 이미지(運転免許証·現住所確認書類·学生証·家族確認書類) 유출 확인(제3보). 共同通信은 住民票の写し도 언급. [제2보](https://share.timescar.jp/news/2026/0928/1815.html) [제3보](https://share.timescar.jp/news/2026/0929/1816.html)
    37	- 집단소송: 변호사 개설 사이트에 10/2 밤까지 1만5천 명 이상 "참가 의사 등록"(共同通信). 원고 수 아님
    38	- 10월 들어 大和証券·物語コーポレーション 등 추가 유출 발표. 경시청에 재교부 상담 쇄도, 福島県 특별 재교부 접수
    39	- 告知要求制限(2020-10-01): 의료보험 사무 외 목적으로 保険者番号·被保険者等記号・番号의 고지를 요구하는 것을 원칙 금지. 예외 있음. QR은 번호 판독 가능 시 동일. 지자체·은행·카드사가 사본 제출 시 마스킹 요청 중. [厚労省](https://www.mhlw.go.jp/stf/newpage_13989.html)
    40	- 구 健康保険証: 2025-12-01 원칙 실효, 잠정 대응 2026-07-31 종료 → 현재 주 문서는 **資格確認書**(보험자별 양식 상이)
    41	- マイナンバーカード: 一般 身元確認에는 앞면만. 裏面 個人番号 복사·보관은 번호법상 허용 목적(세무·사회보장 등)에 한정. 臓器提供意思表示欄은 앞면 하단
    42	- 犯収法 개정 2027-04-01: 특정사업자의 비대면 "얼굴+신분증 이미지" 방식 등 폐지·개편. 전 서비스 일률 아님
    43	- SNS 이용률(ICT総研 2026-07 보도자료): LINE 71.1 / YouTube 67.6 / X 45.4 / Instagram 42.0 — 연령별 전환율 자료 아님
    44	
    45	**핵심 통찰(유지)**: 일본에는 "黒塗り"가 법적 요구+관행으로 존재하고, 개인은 付箋·테이프·편집앱으로 수작업 중. 개인용 무료 웹툴 공백. "透ける黒塗り" 공포에 "래스터 평탄화 + 메타데이터 제거"로 답한다.
    46	
    47	---
    48	
    49	## 2. 타깃 — 제출 목적 4종 (연령 폐기)
    50	
    51	| 우선 | 제출 목적 | 대표 문서 | 법적·관행 근거 | 첫 콘텐츠 훅 |
    52	|---|---|---|---|---|
    53	| **1** | 本人確認書類 제출(은행·카드·통신·프리마) | 資格確認書, 免許証, マイナカード 표면 | 告知要求制限, 수령기관 마스킹 안내 | 「資格確認書の番号、提出先が"隠して"と言う理由」 |
    54	| **2** | 입찰·허가·건설업 첨부 | 資格確認書 사본, 標準報酬決定通知書 | 지자체 공식 마스킹 견본 PDF | 「入札添付、マスキング忘れで再提出にならないために」 |
    55	| 3 | 전문가 상담용 익명화(변호사·세무사·SNS 질문) | 賃貸借契約書, 給与明細, 通帳 | 관행 | 「契約書を相談に出す前に、相手の情報を消す」 |
    56	| 4 | 외국인 거주자 서류(영어 UI) | 在留カード, 住民票(외국인 기재) | 관행 | 영어 버전 |
    57	
    58	**유료화(수정)**: 서버 보관 철회. 1차는 **로컬 보관함**(브라우저 IndexedDB 암호화, 기기 내, 자동 만료) + **암호화 ZIP 내보내기**. 과금은 결제 의향 테스트 후. "개인정보처리방침과 무충돌" 문구 삭제.
    59	
    60	---
    61	
    62	## 3. 제품 요구사항 (알파 게이트)
    63	
    64	### 3-1 마스킹
    65	- 띠(검정 기본·흰색·지정 1색)만. 별표·부분값 폐지(결정 유지)
    66	- OCR 박스 + 글리프 외곽 여유(2px 고정이 아니라 **박스 높이의 15%**)로 덮고 래스터 평탄화
    67	- 출력 시 **원본 텍스트 레이어·주석·첨부·증분저장·EXIF 전부 제거** 검증
    68	- 지원 외 문서는 자동 마스킹 금지, 수동 사각형+워터마크만
    69	
    70	### 3-2 탐지(JP-1) — 정규식 단독 자동마스킹 금지
    71	| 항목 | 방식 | 자동 띠 조건 |
    72	|---|---|---|
    73	| 個人番号 12자리 | NFKC → 숫자 경계 → 레이블(個人番号/マイナンバー) 또는 문서분류 → 체크디지트 함수 | 3조건 충족 시 자동, 아니면 검토 후보 |
    74	| 保険者番号 / 記号・番号・枝番 | 레이블 근접(같은 행·인접 박스) 점수제 | 資格確認書 분류 + 레이블 일치 시 자동 |
    75	| 免許証番号 12자리 | 免許証 분류 + "第"/"番号" 앵커 | 분류 확정 시만 |
    76	| 電話·FAX | NFKC → TEL/電話/携帯/FAX 앵커 + 일본 번호계획 | 앵커 있을 때 자동, 하이픈 없는 값은 후보 |
    77	| 住所 | 郵便番号 → 都道府県 → 市区郡 → 町域 → 丁目番地 → 建物 계층 파서. 漢数字 百·千 포함 | 郵便番호+都道府県 동반 시 자동 |
    78	| 生年月日(和暦) | 和暦·서기 양쪽 | 후보 |
    79	| QR | 이미지 휴리스틱 | 資格確認書 분류 시 자동 |
    80	- **원문↔NFKC 인덱스 매핑 보존**, 이체자(髙/高, 﨑/崎), OCR 혼동(ー/−/―, 〇/0) 단계별 처리, 원본 좌표 역매핑 테스트
    81	
    82	### 3-3 프리셋 — 알파 4종만
    83	| 프리셋 | 목적 선택 | 기본 띠 | 해제 가능 |
    84	|---|---|---|---|
    85	| 資格確認書 | 本人確認 | 保険者番号, 記号, 番号, 枝番, QR | 性別(권고) |
    86	| 運転免許証 | 本人確認 | 裏面 備考欄 | 番号 |
    87	| マイナンバーカード | 身元確認 / 個人番号手続 | 身元確認: 裏面 전체 + 앞면 臓器提供欄 | 個人番号手続 선택 시 裏面 해제 |
    88	| 住民票の写し | 用途 선택 | 個人番号, 住民票コード | 本籍, 世帯員 |
    89	
    90	### 3-4 워터마크
    91	「{提出先}提出用」「本人確認のみに使用」「転用禁止」+ 날짜. 문구는 "防止"가 아니라 "抑止" 수준으로 안내.
    92	
    93	---
    94	
    95	## 4. 더미 데이터 — 비실물 도식형
    96	
    97	- **실물 동일 재현 금지**: 종횡비·색·서체·구획을 동시에 복제하지 않음. 카드류는 "필드 위치 도식(와이어프레임형)"으로
    98	- 앞뒤 중앙 대형 「見本・架空・本人確認に使用不可」 영구 표기
    99	- 公安委員会名·市区町村長名·관인·マイナンバー 로고·QR·IC 표시 금지
   100	- 번호는 **체크디지트 불일치** 또는 규격 외 문자(예: 개인번호 12자리 중 'X' 포함)
   101	- 실존 불가 주소(99丁目 등), 架空 인명, 생성 아바타
   102	- 개별 고해상 카드 파일은 공개 배포 금지. 콘텐츠에는 축소 삽화만
   103	- 더미 범위: 알파 4종 × (PDF·JPG 촬영풍·PNG 스캔풍) + 변형(資格確認書 보험자 3종, 住民票 全員/一部·個人番号 유무·외국인) ≈ **20파일**
   104	- 법률 검토 전까지 카드 더미는 내부 테스트 전용
   105	
   106	---
   107	
   108	## 5. 카탈로그 v2 스키마 (jp_documents_catalog_v2.json으로 갱신 예정)
   109	
   110	```
   111	{id, name, variants[], sides[], fields:{common[], issuer_specific[]},
   112	 rules:[{field, mask_when_purpose[], must_keep_when_purpose[], legal_basis, source_url, verified_at}],
   113	 fixtures[]}
   114	```
   115	- 분리: jp10→給与明細 / 標準報酬決定通知書, jp12→通帳 / 残高証明, jp13→在職証明 / 卒業証明 / 成績証明 / 学生証
   116	- 백로그 추가: 基礎年金番号通知書(年金手帳 legacy), 印鑑登録証明書, 課税·所得·納税証明書, 障害者手帳, 戸籍謄抄本, 介護保険被保険者証, 母子健康手帳, 診断書, 雇用保険被保険者証, 離職票, 住民税決定通知書
   117	
   118	---
   119	
   120	## 6. 콘텐츠 (3개월 30편 → 제목 재작성, 알파 4종 중심으로 순서 재배치)
   121	
   122	### 채널
   123	- **핵심**: 검색 랜딩 3페이지(資格確認書 마스킹 / 免許証 제출 전 / マイナカード 裏面) — Google·Yahoo! JAPAN
   124	- **보조**: YouTube(검색형 2분 + Shorts) · X(사건 해설·공지) · Instagram(carousel·Reels 별도 제작)
   125	- 2주 전환 측정 후 배분 조정
   126	
   127	### 원칙
   128	- 모든 How-to에 「提出先の指定を必ず確認」 포함
   129	- "絶対 / 防ぐ / べき" → "原則 / リスクを下げる / 確認する"
   130	- タイムズカー: 공식 발표 사실만, 1인칭 피해담 금지, 소송·재교부·JICC 안내는 CTA와 분리
   131	- 미구현 기능(일괄처리) 홍보 금지
   132	
   133	### 30편 (JA 제목, EN 병행)
   134	| 회 | 트랙 | 제목 | 문서 |
   135	|---|---|---|---|
   136	| 1 | B | 本人確認書類の画像流出で何が起きるか — 公式発表から分かっていること | — |
   137	| 2 | A | 資格確認書の番号を隠して提出する手順【提出先の指定を確認】 | 資格確認書 |
   138	| 3 | A | 運転免許証を送る前に確認する3つのこと | 免許証 |
   139	| 4 | B | 「黒塗りしたつもり」が復元される仕組みと、復元されない方法 | — |
   140	| 5 | A | マイナンバーカード:身元確認なら表面だけ。裏面が必要な手続きとは | マイナカード |
   141	| 6 | B | フリマ・ネット銀行の本人確認、画像を送る前にできること | 免許証 |
   142	| 7 | A | 住民票の写し:用途別に残す項目・隠す項目 | 住民票 |
   143	| 8 | B | 入札添付の資格確認書、マスキング指示の読み方 | 資格確認書 |
   144	| 9 | A | 履歴書PDF、相談用に連絡先だけ隠す | 履歴書 |
   145	| 10 | B | 付箋・マスキングテープ撮影の限界 | — |
   146	| 11 | A | 源泉徴収票に個人番号があるとき、ないとき | 源泉徴収票 |
   147	| 12 | B | 賃貸契約で身分証コピーを求められたら確認すること | 免許証 |
   148	| 13 | A | 在留カード:提出先が求める面を確認してから隠す(EN同時) | 在留カード |
   149	| 14 | B | 退会後も本人確認書類が保存される理由と、確認する方法 | — |
   150	| 15 | A | 給与明細を相談に出すとき、口座と社員番号の扱い | 給与明細 |
   151	| 16 | B | 2027年4月 犯収法改正で本人確認はどう変わるか(解説) | — |
   152	| 17 | A | 賃貸借契約書を専門家に相談する前の匿名化 | 契約書 |
   153	| 18 | B | 「マスキングしてください」と言う提出先、言わない提出先 | — |
   154	| 19 | A | パスポート:番号・MRZを隠してよい場面、いけない場面 | パスポート |
   155	| 20 | B | 流出後にできる手続き一覧(JICC/CIC 本人申告ほか) ※CTAなし | — |
   156	| 21 | A | 通帳画像:残高証明として出す場合と相談用の違い | 通帳 |
   157	| 22 | B | 学生証画像の流出 — 学生ができる確認 | 学生証 |
   158	| 23 | A | 職務経歴書を匿名で共有するときの考え方 | 職務経歴書 |
   159	| 24 | B | 「サーバーに保存しない」ツールの見分け方 | — |
   160	| 25 | A | スマホだけで:撮影→黒塗り→確認→送信 | 全般 |
   161	| 26 | B | 副業の本人確認を毎回やり直さないために(ローカル保管) | — |
   162	| 27 | A | 透かし「〇〇提出用」の入れ方と限界 | 全般 |
   163	| 28 | B | 家族の書類を代理で出すときの注意 | 資格確認書 |
   164	| 29 | A | (一括処理 出시 후) 複数書類をまとめて処理 | 全般 |
   165	| 30 | B | 3か月の振り返りと読者の黒塗り失敗集 | — |
   166	
   167	---
   168	
   169	## 7. 실행 순서 v2
   170	
   171	| 단계 | 산출물 | 게이트 | 담당 |
   172	|---|---|---|---|
   173	| S1 법적 매트릭스 | 알파 4종 purpose 규칙 + 출처 URL + verified_at | 출처 없는 규칙 0 | Claude |
   174	| S2 fixture | 4종 × 3포맷 + 변형 ≈ 20파일, 기대 마스킹 specs.json | §4 안전조건 전부 충족 | Claude |
   175	| S3 탐지·띠 | NFKC 매핑, 4종 분류기, 고신뢰 항목 자동, 나머지 후보 | 골든: 필수 민감항목 **미탐 0**, 오탐으로 필수 증빙 훼손 0 | Claude Code |
   176	| S4 안전성 | 텍스트레이어·주석·첨부·EXIF 제거, 회전·저해상·왜곡 사진, 타 도구 재추출 공격 테스트 | 전부 통과 | Claude Code + Codex 리뷰 |
   177	| S5 랜딩·법적 문구 | JA 랜딩 3페이지 + 면책·개인정보 문구 | 문구 검수 완료 | Claude |
   178	| S6 제한 베타 | 보험번호 마스킹 가이드 + 베타 모집(사건명 광고 없음) | 2주 전환 측정 | Justin |
   179	| S7 콘텐츠 | 30편 순차 제작, 3일 1회 전달 | 베타 피드백 반영 | Claude |
   180	| S8 확대 | fixture 4주 수집 후 문서 순차 추가 | — | — |
   181	
   182	**게이트 원칙**: "12/13 성공, 1분 완료" 같은 UX 기준은 안전 게이트가 아님. 미탐 0·복원 불가·메타데이터 제거가 게이트.
   183	
   184	---
   185	
   186	## 8. 미확인·보류
   187	
   188	- マイナンバーカード 裏面에 生年月日 인쇄 여부(Codex: 없음 / v1: 있음) → 공식 견본으로 확인
   189	- 履歴書 현행 JIS 규격 여부 → 확인 불가, 「厚労省様式例／民間様式」로 표기
   190	- 카드 더미의 법적 안전선 → 일본 변호사 검토 전 내부 전용
   191	- safefile.net 도메인
     1	# S3 — JP-1 알파: 탐지·띠 구현 보고 (2026-10-21)
     2	
     3	시작 2026-10-21 00:41 KST · 종료 2026-10-21 01:50 KST · 약 1시간 10분
     4	브랜치 `main` · **미배포** · 프로덕션 DB 미접촉
     5	
     6	전략 문서: [`jp_safefile_strategy_v2_2026-10-21.md`](jp_safefile_strategy_v2_2026-10-21.md) §3 제품 요구사항 / §7 게이트
     7	법적 정본: [`../../test/safe/fixtures/jp/jp_legal_matrix_alpha4.json`](../../test/safe/fixtures/jp/jp_legal_matrix_alpha4.json)
     8	전체 통과 로그: [`s3_golden_result.md`](s3_golden_result.md)
     9	
    10	| 게이트 (§7 S3) | 결과 |
    11	|---|---|
    12	| 일본 픽스처에서 `auto`/`auto_with_purpose_gate` 항목 **미탐 0건** | ✅ `JP_MASK` 24 + `JP_MASK_OR_CAND` 3 + `JP_BANDED` 41 전부 통과 |
    13	| `keep` 항목 **오탐 0건** | ✅ `JP_KEEP` 46건 전부 피복 0% |
    14	| 모든 출력에서 **텍스트 레이어·EXIF 0** | ✅ `TEXT_LEAK` 10 + `OUT_PDF` 20 + `OUT_PNG` 3 + `OUT_JPG` 6 |
    15	| 기존 한국 골든 **전부 통과** | ✅ (130 → 120, 아래 설명) |
    16	| 목적 게이트가 실제로 움직이는가 | ✅ 같은 문서·같은 필드를 두 목적으로 — `JP_CLEAR` ↔ `JP_BANDED` |
    17	| 전체 | **389/389 pass, 0 FAIL, exit 0** |
    18	
    19	---
    20	
    21	## A. 마스킹 방식 단일화 — 띠만
    22	
    23	**모드가 2개가 됐다**: `ok`(공개) / `no`(띠). 별표·부분값 오버레이·흰색 처리 전부 제거.
    24	
    25	왜 모드를 줄이는 것이 안전을 올리는가: 부분 마스킹은 비밀의 일부를 배경색 패치 **위에
    26	다시 그린다.** 따라서 그 안전성은 "우리가 얼마나 드러내기로 했는가" 에 달려 있고,
    27	제출하는 사람은 결과 파일만 보고 그 판단을 감사할 수 없다. 띠에는 그 자유도가 없다.
    28	부분이 기본이던 유형(phone·email·birth·address·name·url)은 전부 **띠** 기본이 됐다 —
    29	더 많이 가리지, 덜 가리지 않는다.
    30	
    31	### 띠 기하 — `bandRect()`
    32	박스 + **박스 높이의 15%(최소 2px)** 를 사방으로. 박스가 **추정치**이기 때문이다:
    33	pdf.js 아이템 박스는 사이드베어링을 빼고, OCR 단어 박스는 안티앨리어싱된 글리프 가장자리를
    34	자르며, 회전이 들어가면 둘 다 흔들린다. 추정치에서 정확히 멈추는 띠는 원본 잉크의
    35	머리카락 한 줄을 남긴다.
    36	
    37	**`region:true` 박스는 키우지 않는다** — 사람이 드래그한 영역과 탐지된 欄/블록은
    38	"글리프가 어디서 끝나는가"의 추정이 아니라 **의도**다. 키우면 사용자가 고르지 않은
    39	이웃 내용을 조용히 덮는다.
    40	
    41	### 띠 색
    42	먹(기본) / 흰색 / 사용자 지정 1색. 불투명이라는 점은 셋 다 같으므로 이것은
    43	마스킹 강도의 선택이 아니라 제출본 가독성의 선택이다.
    44	
    45	### 사라진 코드
    46	`maskHalf` · `maskPhone` · `drawFitText` · `largeBarRect` · `pageMedH` ·
    47	`drawRedactions` 의 오버랩 에스컬레이션 경로 전체. 그 에스컬레이션은 두 별표 문자열이
    48	서로 위에 그려져 유령 문자를 만들고 짧은 쪽이 원본 꼬리를 남기던 것을 막는 장치였다 —
    49	**모드를 없애니 그 실패 종류 전체가 함께 사라졌다.**
    50	
    51	### 기존 한국 골든 갱신
    52	- `phone_format` / `phone_format_units` **10건 삭제** — 그 단언이 검증하던 모드가 없다.
    53	  `must_mask`/`must_not_mask` 의미는 **그대로**(활성 마스크 사각형에 의한 기하 피복).
    54	- `candidate_mode` `half` → **`ok`**. 후보는 *추측*이고, 추측이 사용자 확인 전에 문서에서
    55	  내용을 지우면 안 된다. (JP `recommend` 처럼 법적 근거로 既定ON 이어야 하는 호출자는
    56	  명시적 `mode` 를 넘긴다.)
    57	- 하네스의 `__maskRects` 가 이제 **패딩 적용 후** 사각형을 잰다 → `MUST_MASK` 는 쉬워지고
    58	  **`MUST_NOT_MASK` 는 어려워진다.** 정직한 방향이다: 패딩이 이웃의 남겨야 할 값으로
    59	  번지면 골든이 떨어진다.
    60	
    61	### 출력 안전성 확장 (`OUT_*`)
    62	"0 extractable characters" 는 **세 누출 경로 중 하나**만 본다. 나머지 둘은 바이트를 읽어야 한다.
    63	
    64	| 누출 | 검사 |
    65	|---|---|
    66	| 잉크 밑 텍스트 레이어 (透ける黒塗り) | PDF 재파싱 → 추출 문자 0 |
    67	| 렌더러가 보여주지 않는 메타데이터 | 바이트 스캔: 이미지 EXIF/XMP/IPTC, PDF `/Annots` `/EmbeddedFile` `/XFA` `/AcroForm` |
    68	| 증분 저장 (리비전 1 = 미마스킹본이 같은 파일에 물리적으로 남음) | 바이트 스캔: `%%EOF` 정확히 **1개** |
    69	
    70	ICC 프로파일은 **금지하지 않되 경계를 둔다**: Chrome 이 붙이는 456바이트 일반 sRGB
    71	프로파일은 색공간 선언이지 식별자가 아니다(태그 전수 확인: desc/rXYZ/gXYZ/bXYZ/wtpt/rTRC/cprt,
    72	기기 식별 태그 0개). 진짜 위험은 **열람자의 디스플레이 프로파일**이고 그것은 제조사·모델
    73	태그(`dmnd`/`dmdd`)를 달고 훨씬 크다 → 크기 상한 2KB + 그 태그 거부.
    74	
    75	---
    76	
    77	## B. 일본어 탐지 (JP-1)
    78	
    79	**전제대로: 정규식은 단독으로 자동 마스킹하지 않는다.** 자동 띠는 세 독립 합의를 요구한다 —
    80	① 문서 분류 ② 같은 행의 레이블 앵커(또는 아래 명시한 좁은 구조 폴백) ③ 형식(個人番号는 체크디지트).
    81	그 미만은 전부 **검토 후보**로 뜬다.
    82	
    83	비대칭은 의도적이다: 놓친 保険者番号 는 이 제품이 막으려는 바로 그 피해이고,
    84	잘못 가린 氏名 은 제출이 반려되는 일이다. 그래서 자동 띠는 **법적 매트릭스가 "가려도 된다"고
    85	적어둔 필드로만 한정**된다.
    86	
    87	### B-1. 정규화 — 원문↔정규화 인덱스 매핑 보존
    88	박스는 아이템/문자 인덱스에서 나오므로, 정규화는 **원문으로 돌아가는 길을 절대 잃으면 안 된다.**
    89	- **문자 단위로** NFKC 를 돌린다(문자열 단위가 아니라). 그래야 1→n 확장은 허용하면서
    90	  n→1 결합(`ｶ`+`ﾞ`→`ガ`)이 원본 인덱스를 조용히 삼키는 일이 **구조적으로 불가능**해진다.
    91	- 이체자 `髙→高 﨑→崎 邊/邉→辺` (1:1).
    92	- **OCR 혼동은 문맥 조건부**: `ー/−/―/‐/—/－` → `-` 과 `〇/○/◯` → `0` 은 **숫자에 인접할 때만**,
    93	  `l/I/|` → `1` 은 **양쪽이 다 숫자일 때만**.
    94	  무조건 접으면 `コード` 가 `コ-ド` 가 되어 **二次元コード 레이블 앵커 자체가 깨진다** —
    95	  실제로 이 픽스처에서 그 앵커가 유일한 탐지 경로다.
    96	
    97	### B-2. 행/세그먼트 모델
    98	이 문서들은 **레이블–값 폼**이다. 행으로 묶고 수평 간격에서 **세그먼트**로 자른다.
    99	임계값은 레이블→값 간격(이 배율에서 ~80px)보다 넓고 칸→칸 간격(~140px)보다 좁아야 한다 —
   100	**페이지 폭의 10%** 가 알파 픽스처 전부에서 그 사이에 들어간다.
   101	`rowText` 로 **행 전체**를 따로 들고 있는다: 날짜 문맥(`年月日`)은 칸이 아니라 줄 단위로 판단해야 한다.
   102	
   103	### B-3. 문서 분류기 (4종)
   104	가중 키워드 투표. 가중치는 **배타성**을 뜻한다(資格確認書 는 다른 문서에 안 나오고,
   105	本籍 은 戸籍 에도 나온다). 임계값이 단일 키워드가 아니라 **합**인 이유: OCR 은 어떤 줄이든
   106	일정 비율을 반드시 뭉개는데, **알파 픽스처에서 뭉개지는 레이블이 매번 다르다.**
   107	임계 미달이면 "일반 문서" 이고 **일본 자동 마스킹은 아예 일어나지 않는다.**
   108	
   109	실측 점수: kenpo 6 / kokuho 11 / kouki 9 / 免許 앞 9 · 뒤 10 / マイナ 앞 6 · 뒤 6 /
   110	住民票 7~12 (임계 4).
   111	
   112	앞뒤 면은 `表面`/`裏面` 로 구분한다 — 두 면의 **법적 취급이 완전히 다르기 때문**이다.
   113	
   114	### B-4. 필드 추출
   115	
   116	| 항목 | 자동 조건 | 비고 |
   117	|---|---|---|
   118	| 個人番号 12자리 | 레이블(`個人番号`/`マイナンバー`) + 12자리 + **체크디지트 일치** | 불일치 → `recommend` 후보로 **강등**(아래) |
   119	| 保険者番号 / 記号 / 番号 / 枝番 / 被保険者番号 | 資格確認書 분류 + 세그먼트 **선두** 레이블 | `番号` 단독 앵커 금지 → 선두일 때만(保険者番号·被保険者番号의 부분문자열) |
   120	| 免許証番号 | 免許証 분류 + 선두 `番号` + `第…` 형식 | level `optional` (기본 OFF) |
   121	| 住民票コード | 住民票 분류 + 11자리 | 법정 고정 길이 |
   122	| 備考欄 / 臓器提供意思表示欄 | 레이블 + **그려진 사각형 탐지** | 아래 |
   123	| 二次元コード | 레이블 + **측정된 블록으로 스냅** | 아래 |
   124	| 本籍 / 筆頭者 / 세대원 블록 | 住民票 분류 + 레이블 / 氏名 행 경계 | level `recommend` |
   125	| 電話·FAX | `TEL/電話/携帯/FAX` 앵커 + 일본 번호계획, 하이픈 없는 값은 후보 | 알파 4종에 전화번호가 **없다** → `jp_units` 6건으로 고정 |
   126	| 住所 (레이블 없는 본문 내) | `郵便番号`+`都道府県` 동반 시 자동, 아니면 후보. 기관명 **감점** | 알파 4종의 `住所` 는 전부 `keep` → `jp_units` 8건으로 고정 |
   127	| 生年月日 (和暦·西暦) | — | level `keep` (제출처가 요구) |
   128	
   129	#### 체크디지트 불일치 → 자동 아님
   130	番号法施行令 별표의 Σ P_n·Q_n (Q_n = n+1 (n≤6), else n−5; check = 11−(Σ mod 11), ≥10→0).
   131	**더미는 전략 §4 가 유효 체크디지트 생성을 금지하므로 전부 불일치한다.** 올바른 구현은
   132	"이것이 個人番号다" 라고 단정하기를 거부하고 **既定ON 검토 후보로 강등**해야 한다.
   133	→ 골든의 `JP_MASK_OR_CAND`: 띠 **또는** 후보. 하드 띠를 단언하면 골든이 **틀린 동작에 상을 주고**,
   134	후보만 단언하면 "영영 탐지 못 함" 이 통과한다.
   135	
   136	#### 구조 폴백 — OCR 이 레이블을 파괴한 경우만, 좁게
   137	`保険者番号` 레이블은 **5개 픽스처 중 3개에서** `RREES`/`REEES`/`WREEES` 로 읽혔다(실측).
   138	그래서 資格確認書 로 분류된 페이지에서 **날짜 줄이 아닌 세그먼트의 순수 6~10자리 숫자열**을
   139	保険者番号 계열로 본다. 근거: 告知要求制限 은 保険者番号·記号・番号・枝番 **전 계열을 하나의
   140	규칙으로** 덮으므로 "어느 멤버인지" 를 틀려도 비용이 0이고, 놓치면 바로 그 유출이다.
   141	住民票 은 더 좁다 — **12자리 = 個人番号, 11자리 = 住民票コード**, 둘 다 법정 고정 길이이고
   142	그 폼에 그만큼 긴 다른 수가 없다.
   143	
   144	#### 欄(필드 박스)은 **그려진 사각형**으로 찾는다
   145	欄 은 비어 있을 수 있다 — 텍스트 기반 탐지기에는 찾을 것이 없다. 그런데 **비어 보이는 칸이
   146	바로 흐린 손글씨가 숨는 자리다.** 그래서 레이블 아래에서 첫 **150px 이상 연속 잉크 가로줄**을
   147	찾고, x 범위가 ±12px 로 일치하는 다음 줄을 바닥으로 삼는다.
   148	- 글자는 150px **연속** 잉크를 만들 수 없고, 대각선 워터마크 획도 마찬가지다.
   149	- 스캔 시작점은 레이블의 **중간**이다(바닥이 아니라) — 免許証 裏面에서 備考欄 틀의 윗줄이
   150	  레이블 글리프 박스와 겹친다(실측: 레이블 113–150, 틀 145).
   151	- x 범위 일치 조건이 카드 외곽선(20..1080)을 欄(40..1060)의 바닥으로 오인하는 것을 막는다.
   152	실측 결과 세 欄 전부 **픽셀 단위로 정확**: 免許 裏 `[40,145,1020,185]`·`[40,395,1020,165]`,
   153	マイナ 表 `[40,328,721,90]`.
   154	
   155	#### 二次元コード — 라벨은 **신원**, 픽셀은 **경계**
   156	레이블이 블록의 정체를 확정하고(→ 자동 띠), **경계는 픽셀로 측정한다**.
   157	처음엔 레이블 텍스트 클러스터를 정사각으로 키웠는데, 레이블은 블록의 **한쪽 구석**에 있어서
   158	띠가 어긋나 판독 가능한 띠가 남았다 — **피복 80%, 60% 게이트 통과.** 숫자는 통과시키고
   159	눈은 바로 잡았다. 지금은 16px 셀 밀도 연결성분으로 측정한 블록에 **스냅**한다.
   160	레이블은 있는데 블록이 측정되지 않으면(연한 색) 클러스터 정사각 + 10% 로 폴백한다.
   161	
   162	**레이블 없는 고대비 정사각 블록은 `candidate` 로만 낸다.** 더미에 진짜 QR 이 없어서(§4 금지)
   163	그 경로는 **골든 커버리지가 없다** — 검증되지 않은 탐지가 스스로 픽셀을 지우면 안 된다.
   164	(이 판정의 부수 효과로 マイナ 裏 의 코드 칸이 `[880,480,160,160]` 으로 **정확히** 측정됐다.)
   165	
   166	#### 세대원 블록 (住民票)
   167	블록 1 = 본인, 2..n = 수령처가 요구하지 않은 제3자. `続柄`(本人/妻/子)는 한 글자라
   168	OCR 이 레이블보다 훨씬 자주 뭉갠다 → **`氏名` 레이블 행으로 블록 경계를 잡는다.**
   169	마지막 블록은 `この写し|相違|証明し|市長|…` 가 나오는 행에서 끝난다 — 그래야 **발행자·증명문이
   170	남는다**(매트릭스 `keep`).
   171	
   172	#### 住所 계층 파서
   173	`郵便番号 → 都道府県 → 市区郡町村 → 町域 → 丁目番地号 → 建物` 을 **하나의 정규식이 아니라
   174	점수**로 다룬다. 일본 주소는 선택적 계층의 나열이라, 단일 정규식은 전부를 요구해서 대부분을
   175	놓치거나 아무것도 요구하지 않아서 `市` 로 끝나는 회사명을 전부 잡는다.
   176	
   177	**앵커는 郵便番号 또는 47개 실제 都道府県 목록**이다. 그래서 지어낸 머리말 「架空県」 은
   178	앵커가 될 수 없고 — 이것이 바로 「架空県後期高齢者医療広域連合」(保険者名) 과
   179	「見本市長 架空 太郎」(발행자) 를 걸러내는 장치다. 都道府県을 요구하면 그것을 생략한 주소
   180	(일본에서 흔하다)를 놓치지만, 알파에서는 **잘못 가린 발행자 = 반려** 쪽이 더 비싸다.
   181	
   182	기관명(`市役所|区役所|株式会社|大学|広域連合|…`)은 **제외가 아니라 감점(−2)** 이다(§3-2) —
   183	실제 주소가 「…市役所前」 을 포함할 수 있기 때문이다. 감점은 스팬을 **8자 넘겨서까지** 본다.
   184	걸러내려는 모양이 "도시 매칭이 기관명의 머리를 삼키는 것"(「大阪府見本市」+「役所」)이기 때문.
   185	완전한 주소(5점)는 감점 후에도 3점으로 **후보로 남고**, 부분 주소(3점)는 1점으로 떨어진다.
   186	
   187	番地 꼬리는 **종결자에 앵커**한다 — 숫자처럼 보이는 글자가 아니라.
   188	게으른 접두사 + 맨 숫자 형태는 지명 속 한자 수사에서 멈추고(「三条通一丁目二番三号」 가
   189	「三」 만 잡혔다), 고정된 丁目/番/号 순서는 하이픈 형식(「霞が関1-3-2」)을 통째로 놓친다.
   190	그래서 `NUM` 뒤에 `丁目|番地|番|号|-` 중 하나가 오는 **첫 위치**까지 건너뛴 뒤 그 쌍을
   191	탐욕적으로 반복한다. 漢数字 `一〜十・百・千` 포함.
   192	
   193	**레이블 없는 주소**는 별도 필드 키(`address_loose`)로 낸다 — 레이블이 붙은 `住所` 는 네 문서
   194	모두에서 수령처가 필요로 하는 `keep` 필드이고, 둘이 섞이면 안 된다. 레이블이 이미 차지한
   195	문자는 소비 표시가 돼 있으므로 이 패스는 **스스로 서 있는 텍스트만** 본다(備考欄 내용 등).
   196	
   197	#### 오탐 가드
   198	- 모든 값 규칙은 **세그먼트 선두 앵커**. 이 폼에서 레이블은 항상 자기 칸을 연다.
   199	  (이 가드가 없을 때 マイナ 裏 의 각주 「裏面の生年月日有無は…要確認」 가 生年月日 필드로 읽혔다 — 실측.)
   200	- 日付·金額 단독 숫자열은 자동 마스킹하지 않는다(날짜 줄 제외 + 길이 조건).
   201	- 기존 `max_auto` 상한 체계를 일본 픽스처 전부에 적용(실측 auto: kenpo 5 · kouki 3 · kokuho 5 ·
   202	  免許 0 · マイナ 表 0 · 裏 1 · 住民票 0~1).
   203	- **JP 분류가 서면 라틴 이름/주소 휴리스틱을 끈다.** 그 휴리스틱은 이력서 타이포그래피용이라
   204	  JP 폼에서는 `(被用者`·`カー`·`裏面` 같은 쓰레기만 만들었고, 법적 근거가 있는 프리셋 옆에서
   205	  똑같이 권위 있어 보인다.
   206	
   207	#### ⚠ 이번에 **실제로 잡은 결함 2건** (둘 다 숫자가 아니라 그림이 잡았다)
   208	1. **`保険者番号` 의 선두 숫자가 띠 밖으로 남았다.** Tesseract 가 단어를 ` 99221010` 로
   209	   (앞 공백 포함) 돌려주는데 bbox 는 **잉크 박스**다. 공백을 남기면 `str.length` 가 1 많고
   210	   모든 문자 박스가 폭/길이로 나뉘므로 전체가 한 칸 오른쪽으로 밀린다 → 첫 `9` 가 ~7px 노출.
   211	   피복률은 **96%** 라 게이트를 통과했다. `ocrCanvas` 에서 `w.text.trim()`.
   212	2. **二次元コード 띠 어긋남** (위 참조, 피복 80%로 통과).
   213	
   214	---
   215	
   216	## C. 목적 선택 + 프리셋
   217	
   218	업로드 직후 **提出目的** 선택이 뜬다 — `本人確認提出 / 個人番号手続 / 入札添付 / 相談用共有`,
   219	매트릭스 `purposes` 키와 1:1. 기본 `identity_submit`.
   220	
   221	목적을 바꾸면 **모드를 고쳐 쓰는 것이 아니라 엔티티를 다시 유도한다** — 목적이 곧 정책이다.
   222	
   223	| level | kind | 기본 mode | UI |
   224	|---|---|---|---|
   225	| `auto` / `auto_with_purpose_gate` | `auto` | `no` | 카테고리 목록 |
   226	| `recommend` | `candidate` | **`no`** (既定ON·해제 가능) | 要確認 섹션 |
   227	| `optional` | `candidate` | `ok` (기본 OFF) | 要確認 섹션 |
   228	| `keep` | `keep` | `ok` | **残す項目** 섹션 (🛡) |
   229	
   230	`keep` 항목을 사용자가 가리려 하면 경고한다 —
   231	「提出先が受付できない可能性があります（本人特定事項）」. 개별 토글과 **일괄 비공개** 양쪽에서.
   232	일괄 버튼은 같은 결정을 한 번에 내리는 것이므로 같은 경고가 필요하다.
   233	
   234	**マイナカード裏面 + 本人確認 목적 → 면 전체 띠 + 안내문**
   235	「身元確認なら表面のみ提出。番号法により、法定目的以外で裏面の個人番号を収集・保管することは
   236	できません。「個人番号手続」を選ぶと解除されます。」 — 番号法 상 수령처가 身元確認 목적으로
   237	個人番号 를 보유할 수 없으므로, 정직한 안내는 "앞면을 내라" 이고 띠가 그렇게 말한다.
   238	
   239	**매트릭스와의 명시적 차이 1건**: `本籍`/`筆頭者` 에 `my_number_procedure`·`bid_attachment` 를
   240	추가했다(level 은 `recommend` 그대로). 本籍 은 個人番号 사무에도 입찰에도 필요 없고,
   241	픽스처 기대값(`honseki_on` 의 個人番号手続 mask)이 그렇게 적혀 있다. **가릴 수 있는 범위를
   242	넓히는 방향**이라 안전 쪽이다.
   243	
   244	### 워터마크 프리셋 (ja)
   245	「○○ 提出用」「本人確認のみに使用」「転用禁止」「{date} ○○ に提出」.
   246	`{date}` 는 **오늘 날짜로 실제 치환**된다 — 날짜 프리셋의 존재 이유가 "언제 건넸는지 보이게"
   247	인데 `YYYY-MM-DD` 라고 적힌 워터마크는 아무 말도 하지 않는다. 4개 언어 모두 같은 구성.
   248	
   249	---
   250	
   251	## D. 골든 확장
   252	
   253	**11 png (資格確認書 3 · 免許証 2 · マイナカード 2 · 住民票 4) + 3 jpg + 1 pdf**,
   254	목적 2종 교차(마이나 裏·住民票 zenin·honseki_on 에 `個人番号手続`, 免許 裏에 `相談用共有`)
   255	= **19 케이스 / 215 단언** + `jp_units` 14건.
   256	
   257	- **좌표계**: PNG 는 원본 크기, PDF 는 `min(2.2, 1500/ptWidth)` 배 — **단일 균일 배율**이라
   258	  하드코딩하지 않고 `page.w / fixtureWidth` 로 런타임에 구한다.
   259	  **JPG 는 일부러 회전·흐림(휴대폰 촬영)** 이라 PNG 좌표에 떨어질 수 없다 →
   260	  그 케이스는 **필드 수준**(탐지됐는가·띠가 켜졌는가)으로 단언하고 **그렇다고 적는다**.
   261	  맞을 수 없는 좌표를 조용히 비교하지 않는다.
   262	- **단언 종류는 매트릭스 level 에서 나온다, 픽스처가 어느 목록에 넣었는지가 아니라.**
   263	  목적의 `mask` 목록에는 자동 강도와 권장 강도가 **섞여** 있고 그 둘은 다른 약속이다.
   264	  `specs.json` 의 `jp_auto_fields` 가 그 매핑을 들고 있어서 **하네스가 테스트 대상 앱과
   265	  독립적으로** 판정한다.
   266	- **박스 피복 기준**: 박스 안에 텍스트 아이템이 있으면 *각 아이템이* ≥60% 덮였는지
   267	  (의미 있는 질문은 "읽을 수 있는 글자가 덮였는가" 이지 "생성기가 넣은 여백까지 칠했는가"가 아니다),
   268	  없으면(빈 欄·코드 칸) 박스 면적 ≥60%. `keep` 은 ≤10%.
   269	- **`JP_COVERAGE`**: 각 케이스가 **실제로 몇 개 박스를 검사했는지**와 **건너뛴 키**를 출력하고,
   270	  0이면 실패한다. 0건 검사하고 통과하는 하네스는 40건 검사한 하네스와 **같은 초록색**을 찍는다.
   271	  ⚠ 이 가드는 추가 직후 **내 자신의 집계 결함을 잡았다** — `mask:["ALL"]` 경로가 카운터를
   272	  올리지 않고 있었다. `canonical_sweep.rb` 가 sitemap 이 죽으면 0건 검사하고 통과하던 것과
   273	  같은 모양을, 그 교훈이 적힌 저장소에서 또 만들 뻔했다.
   274	
   275	- **`JP_CLEAR` (목적 게이트의 반대 방향)**: `require_banded` 만 있으면 "相談用共有에서 띠가
   276	  켜진다" 는 단언이 **모든 목적에서 켜져 있어도** 통과한다. 같은 문서·같은 필드를 두 목적으로
   277	  돌려 한쪽은 `clear`, 다른 쪽은 `banded` 를 단언한다 — 그래야 게이트가 *움직인다*는 말이 된다.
   278	
   279	### 하네스가 공허하지 않다는 증거 (변이 4건, 전부 실제 주입·재측정)
   280	[`s3_golden_result.md`](s3_golden_result.md) 말미 참조. 요약: 구조 폴백 제거 → 4건 실패,
   281	세대원 규칙 제거 → 13건 실패, `keep`→`recommend` 승격 → 4건 실패, 빈 검사 가드 → 1건 실패
   282	(마지막은 **가드가 추가 직후 내 자신의 집계 결함을 잡은 것**).
   283	
   284	---
   285	
   286	## E. 검증 요약
   287	
   288	| 검증 | 결과 |
   289	|---|---|
   290	| `cd test/safe && node run.mjs` | **389/389 pass · 0 FAIL · exit 0** (직전 130/130) |
   291	| 변이 프로브 4건 | 전부 의도대로 **실패를 일으킴** |
   292	| `cd test/sw && node offline_resilience.mjs` | **9/9 통과** (회귀 없음) |
   293	| 렌더 육안 검증 (`render.mjs`) | 資格確認書 2 · 住民票 1 · 免許証 앞·뒤 · マイナ 表 — 전부 의도대로 |
   294	| 목적 게이트 차등 (`JP_CLEAR`↔`JP_BANDED`) | 免許 裏 `address_loose`: 本人確認提出=clear / 相談用共有=banded |
   295	| JS 구문 검사 (`node --check`) | 통과 |
   296	| 페이지 콘솔 에러 | 0 (SW 등록 404 는 하네스가 sw.js 를 서빙하지 않아서 — 기존과 동일) |
   297	| 프로덕션 DB | **미접촉** |
   298	| 배포 | **하지 않음** |
   299	
   300	---
   301	
   302	## F. 남은 이슈 · 미확인 항목
   303	
   304	### 미확인 (전략 §8 그대로 남음)
   305	- **マイナンバーカード 裏面의 生年月日 인쇄 여부.** 매트릭스가 `unverified` 로 표기한 그대로다.
   306	  더미에는 있고 구현은 있으면 `keep`(個人番号手続) 으로 다룬다. **공식 견본으로 확인 필요** —
   307	  없다면 그 필드 규칙은 죽은 코드가 되고, 있다면 현재 취급이 맞다. 어느 쪽이든 유출 방향은 아니다.
   308	- 카드 더미의 법적 안전선 — 일본 변호사 검토 전 **내부 전용** (§4).
   309	
   310	### 커버리지가 약한 구현 (= 알고 있는 공백)
   311	1. **레이블 없는 QR/바코드 탐지 — 픽스처·유닛 둘 다 없음.** 더미에 진짜 QR 이 없어서(§4 금지)
   312	   검증 불가 → 그래서 **candidate 로만** 낸다. 실제 資格確認書 사본으로 검증한 뒤에야
   313	   자동으로 올릴 수 있다. *(마이나 裏의 코드 칸을 `[880,480,160,160]` 으로 정확히 측정한
   314	   것은 같은 탐지기의 부수 결과지만, 그것은 "회색 사각형"이지 QR 이 아니다.)*
   315	2. **電話·FAX — 유닛만 (`jp_units` 6건).** 알파 4종에 전화번호가 **없다.** 번호계획 정규식과
   316	   하이픈 유무에 따른 자동/후보 분기는 유닛으로 고정했지만, **실제 문서에서 레이블 앵커를 타고
   317	   박스로 변환되는 경로는 한 번도 실행된 적이 없다.**
   318	3. **住所 계층 파서 — 유닛 8건 + `address_loose` 경로 1건.** 알파 4종에서 레이블 붙은 住所 는
   319	   전부 `keep` 이라, 점수 판정이 *아무것도 결정하지 않는다*. 점수·감점·番地 파싱은 유닛으로
   320	   고정했고, 레이블 없는 경로는 免許 裏 備考欄의 住所変更 줄 하나로 목적 차등까지 확인했다.
   321	   **郵便番号+都道府県 동반 → 자동** 분기는 유닛에서만 참이다 — 실제 문서로 본 적이 없다.
   322	4. **多ページ 일본 문서.** 픽스처가 전부 1페이지다. 분류는 페이지별로 돌고 2페이지 이후는
   323	   1페이지 분류를 상속하는데(`jpScan`), 이 경로는 실행된 적이 없다.
   324	
   325	### 설계상 남겨둔 것
   326	- **資格確認書 의 6~10자리 폴백은 분류기에 전적으로 기댄다.** 분류기가 틀리면 숫자 하나가
   327	  잘못 가려진다. 비용은 재제출이고, 반대 방향(미탐)의 비용은 번호 유출이다. 그 교환을
   328	  의식적으로 선택했다 — 다만 **분류 임계값(4) 은 알파 4종 11개 픽스처로만 조정됐다.**
   329	- `その他` 카테고리가 `back_all`·`qr` 를 담는다. 사용자가 그 **카테고리 토글**을 끄면
   330	  マイナ 裏 전체 띠가 사라진다. 카테고리 토글은 원래 사용자 권한이지만, 법적 근거로 걸린
   331	  띠에까지 같은 권한을 주는 것이 맞는지는 제품 판단이다.
   332	- `displayValue` 가 `keep` 항목의 **원문을 그대로 보여준다**(mode `ok`). 의도대로지만,
   333	  화면 공유 중이라면 그것도 노출이다. 전역 "목록 가리기" 토글은 범위 밖으로 뒀다.
   334	
   335	### 이전 세션들에서 넘어온 관찰 (이번 작업과 무관, 그대로 유지)
   336	- `<html lang>`·`og:locale`·UI 크롬은 여전히 Accept-Language 로 협상된다. 제품 결정.
   337	- CI 의 `lint`(rubocop 86건)·`scan_ruby`(brakeman 6건)는 **이번 브랜치 이전부터** 빨갛다.
   338	- `rake jobs:failed` 의 프로덕션 큐 DB 실측은 **배포 후 확인 항목**.
  1577	## SafeFile JP-1 알파 — 띠 단일화 + 일본 4종 탐지 + 목적 프리셋 (2026-10-21)
  1578	
  1579	브랜치 `main`. **미배포.** 프로덕션 DB 미접촉.
  1580	보고 [`docs/jp/s3_report.md`](docs/jp/s3_report.md) · 전체 로그 [`docs/jp/s3_golden_result.md`](docs/jp/s3_golden_result.md)
  1581	전략 [`docs/jp/jp_safefile_strategy_v2_2026-10-21.md`](docs/jp/jp_safefile_strategy_v2_2026-10-21.md) §3·§7
  1582	법적 정본 [`test/safe/fixtures/jp/jp_legal_matrix_alpha4.json`](test/safe/fixtures/jp/jp_legal_matrix_alpha4.json)
  1583	
  1584	**골든 130 → 389, 0 실패.** SW 하네스 9/9 유지.
  1585	
  1586	### 1. 마스킹이 **띠만** 남았다 (모드 3 → 2)
  1587	부분 마스킹은 비밀의 일부를 배경색 패치 **위에 다시 그린다** — 안전성이 "우리가 얼마나
  1588	드러내기로 했는가" 에 달려 있고, 제출하는 사람은 결과 파일만 보고 그 판단을 감사할 수 없다.
  1589	띠에는 그 자유도가 없다. 부분이 기본이던 유형은 전부 띠 기본이 됐다(더 많이 가린다).
  1590	`drawRedactions` 의 오버랩 에스컬레이션 경로 전체가 **모드와 함께 사라졌다** — 두 별표
  1591	문자열이 서로 위에 그려지던 실패 종류가 통째로 없어졌다.
  1592	
  1593	- `bandRect()` = 박스 + max(높이 15%, 2px). 박스는 **추정치**다(pdf.js 는 사이드베어링 제외,
  1594	  OCR 은 안티앨리어싱 가장자리 절단). `region:true`(사람이 드래그한 영역·탐지된 欄)는 **키우지 않는다** — 그건 추정이 아니라 의도다.
  1595	- 띠 색: 먹(기본)·흰색·지정 1색.
  1596	- 골든의 `__maskRects` 가 **패딩 적용 후**를 잰다 → `MUST_NOT_MASK` 가 더 엄격해졌다.
  1597	
  1598	### 2. 출력 안전성: "0 extractable characters" 는 **세 누출 중 하나**다
  1599	나머지 둘은 바이트를 읽어야 보인다 — 이미지 EXIF/XMP/IPTC, PDF `/Annots`·`/EmbeddedFile`,
  1600	그리고 **증분 저장**(리비전 1 = 미마스킹본이 같은 파일에 물리적으로 남음 → `%%EOF` 정확히 1개).
  1601	ICC 는 금지하지 않되 경계를 둔다: Chrome 의 456B 일반 sRGB 는 색공간 선언이지만
  1602	**열람자의 디스플레이 프로파일**은 제조사·모델 태그(`dmnd`/`dmdd`)를 달고 훨씬 크다.
  1603	
  1604	### 3. 일본 탐지 — 정규식 단독 자동마스킹 금지
  1605	자동 띠 = ① 문서분류 ∧ ② 같은 행 레이블 앵커 ∧ ③ 형식(個人番号는 체크디지트). 그 미만은 후보.
  1606	
  1607	- **NFKC 를 문자 단위로** 돌린다 → 1→n 확장은 허용하되 n→1 결합(`ｶ`+`ﾞ`→`ガ`)이 원본
  1608	  인덱스를 삼키는 일이 **구조적으로 불가능**.
  1609	- **OCR 혼동 접기는 문맥 조건부.** `ー`→`-` 를 무조건 접으면 `コード`→`コ-ド` 가 되어
  1610	  **二次元コード 앵커 자체가 깨진다** — 그게 이 픽스처의 유일한 코드 탐지 경로였다.
  1611	- 세그먼트 분리 임계 = 페이지 폭 10%. 레이블→값 간격(~80px)보다 넓고 칸→칸(~140px)보다 좁다.
  1612	- 분류는 **가중 합**이지 단일 키워드가 아니다 — OCR 은 어떤 줄이든 뭉개는데 **뭉개지는 레이블이
  1613	  매번 다르다**(`保険者番号` 가 5개 중 3개에서 `RREES`/`REEES`/`WREEES`).
  1614	- 欄(備考欄·臓器提供欄)은 **그려진 사각형**으로 찾는다(150px 연속 잉크 가로줄 + x범위 ±12px).
  1615	  비어 보이는 칸이 바로 흐린 손글씨가 숨는 자리다. 세 欄 전부 픽셀 단위로 정확.
  1616	- **二次元コード: 라벨은 신원, 픽셀은 경계.** 라벨 클러스터를 정사각으로 키우면 라벨이 블록
  1617	  한쪽 구석에 있어 띠가 어긋난다. 레이블 없는 블록은 **candidate 로만** 낸다(진짜 QR 더미가
  1618	  §4 로 금지돼 골든 커버리지가 없다 — 검증 안 된 탐지가 스스로 픽셀을 지우면 안 된다).
  1619	
  1620	### ⚠ 숫자는 통과시키고 **그림이 잡은 결함 2건**
  1621	1. `保険者番号` 선두 숫자가 띠 밖으로 남았다 — Tesseract 가 ` 99221010` 처럼 **앞 공백 포함**
  1622	   문자열을 주는데 bbox 는 잉크 박스다. 공백을 세면 문자 폭 계산이 한 칸 밀린다. **피복률 96%.**
  1623	   → `ocrCanvas` 에서 `w.text.trim()`.
  1624	2. 二次元コード 띠 어긋남 — **피복 80%, 60% 게이트 통과.**
  1625	
  1626	⇒ **피복률은 "얼마나" 를 말하지 "어디" 를 말하지 않는다.** `test/safe/render.mjs` 를
  1627	고정했다(게이트 아님, 육안 검증 전용).
  1628	
  1629	### 4. 골든이 공허하지 않은지 **변이로 확인**
  1630	구조 폴백 제거 → 4건 실패 / 세대원 규칙 제거 → 13건 실패 / `keep`→`recommend` → 4건 실패.
  1631	⚠ **`JP_COVERAGE`(검사한 박스 수가 0이면 실패) 가드는 추가 직후 내 자신의 집계 결함을 잡았다**
  1632	— `mask:["ALL"]` 경로가 카운터를 안 올리고 있었다. `canonical_sweep.rb` 가 sitemap 이 죽으면
  1633	0건 검사하고 통과하던 것과 **같은 모양**을, 그 교훈이 적힌 저장소에서 또 만들 뻔했다.
  1634	`JP_CLEAR` 도 같은 이유다 — `require_banded` 만 있으면 "이 목적에서 띠가 켜진다"는 단언이
  1635	**모든 목적에서 켜져 있어도** 통과한다.
  1636	
  1637	### 5. 남은 공백 (다음 런)
  1638	- **레이블 없는 QR**: 픽스처·유닛 둘 다 없음 → candidate 고정.
  1639	- **電話·FAX / 住所 자동 분기**: 알파 4종에 전화번호가 없고 住所 는 전부 `keep` →
  1640	  `jp_units` 로만 고정했다. **실제 문서에서 박스로 변환되는 경로는 한 번도 실행된 적이 없다.**
  1641	- **多ページ 일본 문서**: 픽스처가 전부 1페이지. 2페이지 이후 분류 상속 경로 미실행.
  1642	- 운영 메모: `test/sw/node_modules` 는 `ln -s ../safe/node_modules` 로 공유한다(README 갱신).
  1643	
  1644	### JP-1 이슈 로그
  1645	
  1646	**2026-10-21 · 미해결 · 사람 판단 필요 — 카드 더미를 공개 저장소에 커밋한 건**
  1647	`chaop2026/docpack` 은 **PUBLIC** 이다(`gh repo view` 확인). 전략 v2 §4 는
  1648	「개별 고해상 카드 파일은 공개 배포 금지 / 법률 검토 전까지 카드 더미는 내부 테스트 전용」
  1649	이라고 적고 있다. 커밋하면 그 보류를 사실상 해제하는 셈이다.
  1650	
  1651	**그럼에도 커밋한 이유**와 **줄인 범위**:
  1652	- §4 의 *생성* 안전조건은 전부 충족한다 — 와이어프레임형, 전면 「見本・架空・本人確認に
  1653	  使用不可」 워터마크, 公安委員会名·관인·로고·실제 QR·IC 표시 전부 없음, 체크디지트 불일치,
  1654	  실존 불가 주소, 架空 인명, 사진 없음(빈 회색 패널). 오용 가치는 사실상 0이다.
  1655	  남은 제약은 "이 파일들이 위험하다" 가 아니라 **"일본 변호사 검토 전까지 보류"** 다.
  1656	- 골든 하네스가 그 파일 없이는 **돌지 않는다.** `gen.py` 는 결정적이지만 Linux + Noto CJK
  1657	  전제라 이 맥에서 재생성이 불가능하고, 재생성하면 PIL 버전 차이로 **박스 좌표가 흔들려
  1658	  모든 spec 이 깨진다.**
  1659	- **줄인 것**: `docs/jp/jp_fixtures_alpha4.zip`(6.1MB, 같은 바이트의 중복)은 **커밋하지 않고
  1660	  gitignore** 했다 — zip 은 기술적 목적이 없고 모양 자체가 재배포다.
  1661	  `test/safe/fixtures/jp/README.md` 에 §4 상태를 명시했다.
  1662	
  1663	→ **사람이 결정할 것**: (a) 이대로 둔다 / (b) 픽스처를 별도 비공개 저장소로 옮기고
  1664	submodule 로 받는다 / (c) 변호사 검토 후 재판단. **푸시 전에 결정하는 편이 싸다** —
  1665	공개 git 히스토리는 되돌리기 어렵다.

hook: PostToolUse
hook: PostToolUse Completed
codex
정적 대조에서 이미 중요한 불일치가 보입니다. 예를 들어 법적 정본은 `資格確認書` 번호군을 `my_number_procedure`에서 규정하지 않는데 구현 폴백은 일률 `optional`로 노출하고, `住民票コード`는 정본 자체가 `verified:false`인데 자동 띠입니다. 이제 하네스가 이 차이를 실제로 잡는지와 출력물 검사를 확인하겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'node run.mjs' in /Users/sunghoon/Projects/docpack/test/safe
 exited 1 in 310ms:
node:events:486
      throw er; // Unhandled 'error' event
      ^

Error: listen EPERM: operation not permitted 127.0.0.1
    at Server.setupListenHandle [as _listen2] (node:net:1994:21)
    at listenInCluster (node:net:2073:12)
    at node:net:2282:7
    at process.processTicksAndRejections (node:internal/process/task_queues:90:21)
Emitted 'error' event on Server instance at:
    at emitErrorNT (node:net:2052:8)
    at process.processTicksAndRejections (node:internal/process/task_queues:90:21) {
  code: 'EPERM',
  errno: -1,
  syscall: 'listen',
  address: '127.0.0.1'
}

Node.js v25.6.1

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "git show 546344b:test/safe/run.mjs | nl -ba | sed -n '1,260p'; git show 546344b:test/safe/run.mjs | nl -ba | sed -n '260,560p'; git show 546344b:test/safe/run.mjs | nl -ba | sed -n '560,900p'" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
     1	#!/usr/bin/env node
     2	/*
     3	 * Golden verification harness for the SafeFile PII pipeline.
     4	 *
     5	 * Serves the REAL public/safe/index.html in headless Chrome, drives the live
     6	 * detection over each fixture, and checks every value against specs.json:
     7	 *   - MUST_MASK      : value is geometrically covered by an active mask rect
     8	 *   - MUST_NOT_MASK  : value is NOT covered by any mask rect
     9	 *   - NEVER_CANDIDATE: value is not proposed as a review candidate
    10	 *   - SHOULD_CANDIDATE: value surfaces as a candidate (visible, not hidden)
    11	 *   - AI_INJECT      : adversarial AI labels are neutralised in addEntities
    12	 *   - TEXT_LEAK      : output PDF has 0 extractable characters
    13	 *   - OUT_SAFE       : output carries no annots/embedded files/incremental save/EXIF
    14	 *
    15	 * Requires: node, playwright (chrome channel). Fixtures from generate_fixtures.py.
    16	 * Usage: node run.mjs [--only 7_resume_dark.pdf]  (exit 0 = all pass)
    17	 */
    18	import { chromium } from 'playwright';
    19	import http from 'node:http';
    20	import fs from 'node:fs';
    21	import path from 'node:path';
    22	import { fileURLToPath } from 'node:url';
    23	
    24	const __dirname = path.dirname(fileURLToPath(import.meta.url));
    25	const REPO = path.resolve(__dirname, '..', '..');
    26	const PUBLIC = path.join(REPO, 'public');
    27	const DOCS = path.join(__dirname, 'testdocs');
    28	const FIXTURES = path.join(__dirname, 'fixtures');
    29	const SPECS = JSON.parse(fs.readFileSync(path.join(__dirname, 'specs.json'), 'utf8'));
    30	const OUT = path.join(__dirname, 'out');
    31	fs.mkdirSync(OUT, { recursive: true });
    32	
    33	const onlyArg = (() => { const i = process.argv.indexOf('--only'); return i >= 0 ? process.argv[i + 1] : null; })();
    34	
    35	const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json', '.txt': 'text/plain' };
    36	
    37	function startServer() {
    38	  return new Promise(resolve => {
    39	    const srv = http.createServer((req, res) => {
    40	      let p = decodeURIComponent(req.url.split('?')[0]);
    41	      if (p === '/') p = '/index.html';
    42	      const fp = path.join(PUBLIC, p);
    43	      if (!fp.startsWith(PUBLIC) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end('nf'); return; }
    44	      res.writeHead(200, { 'content-type': MIME[path.extname(fp)] || 'application/octet-stream' });
    45	      fs.createReadStream(fp).pipe(res);
    46	    });
    47	    srv.listen(0, '127.0.0.1', () => resolve(srv));
    48	  });
    49	}
    50	
    51	// ── in-page helpers, serialised into the browser context ──
    52	const PAGE_HELPERS = () => {
    53	  // Active mask rects: every entity that is ON, not 'ok', and located — passed
    54	  // through bandRect() so the harness measures the pixels that are ACTUALLY
    55	  // painted (box + padding), not the pre-padding estimate. This makes MUST_MASK
    56	  // easier and MUST_NOT_MASK harder, which is the honest direction: a padding
    57	  // that bleeds onto a neighbouring must-keep value now fails the golden.
    58	  window.__maskRects = function () {
    59	    const rects = [];
    60	    for (const e of entities) {
    61	      if (!isOn(e) || e.mode === 'ok' || !(e.boxes && e.boxes.length)) continue;
    62	      for (let pi = 0; pi < pages.length; pi++) {
    63	        for (const l of mergeLineBoxes(e.boxes, pi)) { const r = bandRect(l); rects.push({ pi, x: r.x, y: r.y, w: r.w, h: r.h }); }
    64	      }
    65	    }
    66	    return rects;
    67	  };
    68	  window.__rectsFor = function (v) {
    69	    return boxesForValue(v).map(b => ({ pi: b.page, x: b.x, y: b.y, w: b.w, h: b.h }));
    70	  };
    71	  window.__isMasked = function (v) {
    72	    const mr = window.__maskRects(), vr = window.__rectsFor(v);
    73	    const ov = (a, b) => {
    74	      if (a.pi !== b.pi) return 0;
    75	      const ix = Math.max(0, Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x));
    76	      const iy = Math.max(0, Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y));
    77	      return ix * iy;
    78	    };
    79	    for (const b of vr) { const area = b.w * b.h; if (area <= 0) continue; for (const a of mr) if (ov(a, b) > area * 0.25) return true; }
    80	    return false;
    81	  };
    82	  const norm = s => (s || '').toLowerCase().replace(/\s+/g, ' ').replace(/[.,;:'"()]+$/g, '').replace(/^[.,;:'"()]+/g, '').trim();
    83	  window.__norm = norm;
    84	  window.__entitySnapshot = function () {
    85	    return entities.map(e => ({ type: e.type, value: e.value, kind: e.kind, mode: e.mode, reason: e.reason, located: !!(e.boxes && e.boxes.length) }));
    86	  };
    87	  /* ── JP: geometry is checked against the FIXTURE'S OWN box table, not against
    88	     a value string. A Japanese form's value is exactly what OCR mangles
    89	     (美咲 → "S=0%"), so asserting on the string would test Tesseract, not us;
    90	     the box is what the band has to cover either way. ── */
    91	  // fraction of `rect` (page coords) covered by the union of active mask rects,
    92	  // sampled on a grid so overlapping bands count once.
    93	  window.__coverage = function (rect) {
    94	    const mr = window.__maskRects().filter(r => r.pi === rect.pi);
    95	    if (!mr.length) return 0;
    96	    const N = 24; let hit = 0;
    97	    for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) {
    98	      const x = rect.x + rect.w * (i + 0.5) / N, y = rect.y + rect.h * (j + 0.5) / N;
    99	      if (mr.some(r => x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h)) hit++;
   100	    }
   101	    return hit / (N * N);
   102	  };
   103	  // OCR/text item boxes whose centre falls inside `rect`
   104	  window.__itemsIn = function (rect) {
   105	    const p = pages[rect.pi]; if (!p) return [];
   106	    return (p.items || []).filter(it => it.x + it.w / 2 >= rect.x && it.x + it.w / 2 <= rect.x + rect.w
   107	                                     && it.y + it.h / 2 >= rect.y && it.y + it.h / 2 <= rect.y + rect.h)
   108	      .map(it => ({ pi: rect.pi, x: it.x, y: it.y, w: it.w, h: it.h }));
   109	  };
   110	  // any ACTIVE candidate entity overlapping `rect` (did the field surface for review?)
   111	  window.__candidateOver = function (rect) {
   112	    for (const e of entities) {
   113	      if (e.kind !== 'candidate' || !e.boxes) continue;
   114	      for (const b of e.boxes) {
   115	        if (b.page !== rect.pi) continue;
   116	        if (!(b.x + b.w < rect.x || rect.x + rect.w < b.x || b.y + b.h < rect.y || rect.y + rect.h < b.y)) return true;
   117	      }
   118	    }
   119	    return false;
   120	  };
   121	  window.__jpState = function () {
   122	    return { cls: jpState.cls && { doc: jpState.cls.doc, side: jpState.cls.side || null, score: jpState.cls.score },
   123	      purpose: jpState.purpose, pw: pages.map(p => p.w),
   124	      fields: entities.filter(e => e.jp).map(e => ({ field: e.jp.field, level: e.jp.level, note: e.jp.note, kind: e.kind, mode: e.mode })) };
   125	  };
   126	  window.__isCandidateExact = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value) === n); };
   127	  window.__isCandidateContains = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value).includes(n)); };
   128	  // default mode of the candidate whose value contains v (null if not a candidate)
   129	  window.__candidateMode = function (v) { const n = norm(v); const e = entities.find(x => x.kind === 'candidate' && norm(x.value).includes(n)); return e ? e.mode : null; };
   130	  // name-bar geometry: glyph union (raw pdf items) vs drawn bar rect
   131	  window.__nameBar = function (v) {
   132	    const rects = boxesForValue(v).filter(b => b.page === 0);
   133	    if (!rects.length) return null;
   134	    const lines = mergeLineBoxes(rects, 0); const bar = lines[0];
   135	    // glyph union straight from page items overlapping the value
   136	    const its = (pages[0].items || []).filter(it => (v.split(/\s+/).some(w => (it.str || '').includes(w))));
   137	    if (!its.length) return null;
   138	    const gx0 = Math.min(...its.map(i => i.x)), gy0 = Math.min(...its.map(i => i.y));
   139	    const gx1 = Math.max(...its.map(i => i.x + i.w)), gy1 = Math.max(...its.map(i => i.y + i.h));
   140	    const gW = gx1 - gx0, gH = gy1 - gy0;
   141	    // replicate the drawn-band geometry exactly as the page would paint it.
   142	    const drawn = bandRect(bar);
   143	    // Ink safety: the bar must cover the full glyph WIDTH and, vertically, the
   144	    // cap-height→descent band (raw pdf font box minus the top ascent gap where
   145	    // no ink lives). It should NOT need to cover the empty ascent whitespace.
   146	    const inkTop = gy0 + gH * 0.18, inkBot = gy1;
   147	    const coversInk = drawn.x <= gx0 + 1 && drawn.x + drawn.w >= gx1 - 1 && drawn.y <= inkTop + 1 && drawn.y + drawn.h >= inkBot - 1;
   148	    return { barW: bar.w, barH: bar.h, drawnH: drawn.h, drawnW: drawn.w, glyphW: gW, glyphH: gH, containsGlyph: coversInk };
   149	  };
   150	};
   151	
   152	// `jp/...` paths resolve under fixtures/, everything else under testdocs/.
   153	const docPath = file => file.startsWith('jp/') ? path.join(FIXTURES, file) : path.join(DOCS, file);
   154	async function loadDoc(page, file, ocr) {
   155	  await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
   156	  await page.setInputFiles('#fileInput', docPath(file));
   157	  await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0, { timeout: ocr ? 240000 : 40000 });
   158	  await page.waitForTimeout(ocr ? 800 : 400);
   159	  await page.evaluate(PAGE_HELPERS);
   160	}
   161	
   162	const rows = [];
   163	const rec = (doc, cat, item, expected, actual, pass, info = false) => rows.push({ doc, cat, item, expected, actual, pass, info });
   164	
   165	async function checkDoc(page, spec) {
   166	  const { doc, ocr } = spec;
   167	  await loadDoc(page, doc, ocr);
   168	  const snap = await page.evaluate(() => window.__entitySnapshot());
   169	  const autoCount = snap.filter(e => e.kind === 'auto').length;
   170	  process.stderr.write(`    [autoCount] ${doc} = ${autoCount}\n`);
   171	  if (spec.min_auto != null) rec(doc, 'REGRESSION', `auto>=${spec.min_auto}`, `>=${spec.min_auto}`, String(autoCount), autoCount >= spec.min_auto);
   172	  // False-positive regression guard: a hard CEILING on auto-detected entities.
   173	  // The golden's MUST_MASK checks catch "did we mask what we should"; max_auto
   174	  // catches the inverse — a detection change that starts auto-masking body text
   175	  // (the résumé-defect class where 95/95 passed while the body got shredded).
   176	  if (spec.max_auto != null) rec(doc, 'REGRESSION', `auto<=${spec.max_auto}`, `<=${spec.max_auto}`, String(autoCount), autoCount <= spec.max_auto);
   177	
   178	  // Turn a name candidate ON (hide → solid) so must_mask can assert the whole
   179	  // name — surname included — is geometrically covered once the user activates it.
   180	  if (spec.activate_name) {
   181	    const ok = await page.evaluate(v => {
   182	      const e = entities.find(x => x.value === v && x.type === 'name');
   183	      if (!e) return false;
   184	      e.mode = 'no'; renderAll(); return true;
   185	    }, spec.activate_name);
   186	    rec(doc, 'NAME_WHOLE', spec.activate_name, 'detected-whole', ok ? 'detected' : 'MISSING/truncated', ok);
   187	  }
   188	
   189	  for (const v of spec.must_mask || []) {
   190	    const masked = await page.evaluate(x => window.__isMasked(x), v);
   191	    rec(doc, 'MUST_MASK', v, 'masked', masked ? 'masked' : 'NOT masked', masked);
   192	  }
   193	  for (const v of spec.must_not_mask || []) {
   194	    const masked = await page.evaluate(x => window.__isMasked(x), v);
   195	    rec(doc, 'MUST_NOT_MASK', v, 'clear', masked ? 'MASKED' : 'clear', !masked);
   196	  }
   197	  for (const v of spec.never_candidate || []) {
   198	    const isCand = await page.evaluate(x => window.__isCandidateExact(x), v);
   199	    rec(doc, 'NEVER_CANDIDATE', v, 'not-cand', isCand ? 'CANDIDATE' : 'not-cand', !isCand);
   200	  }
   201	  for (const v of spec.should_candidate || []) {
   202	    // A candidate must SURFACE as a review candidate. (Its default redaction level
   203	    // — name/address candidates now default to 'half' — is asserted separately by
   204	    // CANDIDATE_MODE; "surfaced" is no longer coupled to "left in the clear".)
   205	    const isCand = await page.evaluate(x => window.__isCandidateContains(x), v);
   206	    rec(doc, 'SHOULD_CANDIDATE', v, 'candidate', isCand ? 'candidate' : 'missing', isCand);
   207	  }
   208	  // Candidate default-mode policy: name/address candidates default to 'half' so the
   209	  // "확인 필요" label matches a visibly-partial state. Old code defaulted them to 'ok'.
   210	  for (const [v, exp] of Object.entries(spec.candidate_mode || {})) {
   211	    const mode = await page.evaluate(x => window.__candidateMode(x), v);
   212	    rec(doc, 'CANDIDATE_MODE', v, exp, mode || 'not-candidate', mode === exp);
   213	  }
   214	  if (spec.name_bar) {
   215	    const nb = await page.evaluate(x => window.__nameBar(x), spec.name_bar);
   216	    if (nb) {
   217	      const ratioH = nb.drawnH / nb.glyphH;
   218	      const ok = nb.containsGlyph && ratioH <= 1.5;
   219	      rec(doc, 'NAME_BAR', spec.name_bar, 'tight&contains', `hRatio=${ratioH.toFixed(2)} contains=${nb.containsGlyph}`, ok);
   220	    } else rec(doc, 'NAME_BAR', spec.name_bar, 'measurable', 'no-boxes', false);
   221	  }
   222	  if (spec.dark_bg_value) {
   223	    const dk = await page.evaluate(v => { const e = entities.find(x => x.value === v); const bg = e && e.boxes[0] ? e.boxes[0].bg : null; return { bg, dark: bg ? isDarkColor(bg) : null }; }, spec.dark_bg_value);
   224	    rec(doc, 'DARK_BG', spec.dark_bg_value, 'dark bg detected', `${dk.bg} dark=${dk.dark}`, dk.dark === true, true);
   225	  }
   226	  for (const fmt of (spec.out_formats || (spec.type === 'pdf' ? ['pdf'] : []))) {
   227	    await checkOutput(page, doc, fmt);
   228	  }
   229	}
   230	
   231	/* ── output safety ──────────────────────────────────────────────────────────
   232	   What the user ships is the output file, not our preview. Three separate ways
   233	   a redacted-looking file still carries the original:
   234	     1. a text layer under the ink (the classic "透ける黒塗り"),
   235	     2. metadata the renderer never shows — EXIF/XMP/IPTC on images, annotations
   236	        or embedded files in a PDF,
   237	     3. an incrementally-saved PDF, where the PREVIOUS revision (unredacted) is
   238	        still physically present earlier in the same byte stream.
   239	   Each needs its own probe: pdf.js text extraction catches (1) and is blind to
   240	   (2) and (3). So we read the produced BYTES. */
   241	const MARKERS = {
   242	  // PNG: every ancillary text/EXIF chunk type. Canvas encodes none of these, but
   243	  // "it currently doesn't" is not a guarantee — assert it.
   244	  png: [['eXIf', 'EXIF chunk'], ['tEXt', 'tEXt chunk'], ['zTXt', 'zTXt chunk'], ['iTXt', 'iTXt chunk']],
   245	  // ICC_PROFILE is deliberately NOT forbidden: Chrome's JPEG encoder attaches a
   246	  // 456-byte generic sRGB profile (tags: desc/rXYZ/gXYZ/bXYZ/wtpt/rTRC/cprt —
   247	  // measured, no device identifiers). That is a colour space declaration, not
   248	  // document content and not an identifier. What WOULD be a leak is the
   249	  // viewer's *display* profile, which carries manufacturer/model tags and is
   250	  // much larger — iccSafe() below bounds exactly that.
   251	  jpg: [['Exif\0\0', 'EXIF APP1'], ['http://ns.adobe.com/xap/', 'XMP APP1'], ['Photoshop 3.0\0', 'IPTC APP13']],
   252	  pdf: [['/Annots', 'annotation'], ['/EmbeddedFile', 'embedded file'], ['/XFA', 'XFA form'], ['/AcroForm', 'form fields'], ['/Names', 'name tree']],
   253	};
   254	function scanMarkers(buf, kind) {
   255	  const hay = buf.toString('latin1');
   256	  return MARKERS[kind].filter(([m]) => hay.includes(m)).map(([, label]) => label);
   257	}
   258	// An embedded ICC profile is acceptable only while it stays a generic colour
   259	// space. A display profile (which identifies the machine that produced the file)
   260	// is large and carries the device manufacturer / model description tags.
   260	// is large and carries the device manufacturer / model description tags.
   261	const ICC_MAX = 2048;
   262	function iccSafe(buf) {
   263	  const hay = buf.toString('latin1');
   264	  const at = hay.indexOf('ICC_PROFILE\0');
   265	  if (at < 0) return { ok: true, note: 'absent' };
   266	  const size = buf.readUInt32BE(at + 14);          // profile header: byte 0..3 = size
   267	  const body = hay.slice(at + 14, at + 14 + Math.min(size, 65535));
   268	  const dev = ['dmnd', 'dmdd'].filter(t => body.includes(t));
   269	  const ok = size <= ICC_MAX && dev.length === 0;
   270	  return { ok, note: `${size}B${dev.length ? ' +' + dev.join('/') : ''}` };
   271	}
   272	async function checkOutput(page, doc, fmt) {
   273	  const tag = `OUT_${fmt.toUpperCase()}`;
   274	  try {
   275	    await page.evaluate(f => { const r = document.querySelector(`input[name=fmt][value="${f}"]`); if (r) r.checked = true; }, fmt);
   276	    // force at least one masked, located entity so Make is enabled
   277	    await page.evaluate(() => { const e = entities.find(x => isOn(x) && x.boxes && x.boxes.length); if (e) e.mode = 'no'; renderAll(); });
   278	    await page.click('#btnMake');
   279	    await page.waitForSelector('#result', { state: 'visible', timeout: 60000 });
   280	    const dl = await Promise.all([
   281	      page.waitForEvent('download', { timeout: 30000 }),
   282	      page.click('#btnDownload'),
   283	    ]).then(a => a[0]).catch(() => null);
   284	    if (!dl) { rec(doc, tag, `output ${fmt}`, 'clean', 'no-download', false); return; }
   285	    const fp = path.join(OUT, doc.replace(/[\/\\]/g, '_').replace(/\.\w+$/, `_out.${fmt}`));
   286	    await dl.saveAs(fp);
   287	    const buf = fs.readFileSync(fp);
   288	
   289	    if (fmt === 'pdf') {
   290	      const chars = await page.evaluate(async (b64) => {
   291	        const bin = atob(b64); const arr = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
   292	        const pdf = await pdfjsLib.getDocument({ data: arr }).promise;
   293	        let n = 0;
   294	        for (let p = 1; p <= pdf.numPages; p++) { const tc = await (await pdf.getPage(p)).getTextContent(); n += tc.items.reduce((s, it) => s + (it.str || '').replace(/\s/g, '').length, 0); }
   295	        return n;
   296	      }, buf.toString('base64'));
   297	      rec(doc, 'TEXT_LEAK', `output ${fmt}`, '0 chars', `${chars} chars`, chars === 0);
   298	      // One %%EOF means one revision. An incremental save appends a second body
   299	      // + xref + %%EOF, leaving revision 1 (pre-redaction) readable in the file.
   300	      const eofs = (buf.toString('latin1').match(/%%EOF/g) || []).length;
   301	      rec(doc, tag, `output ${fmt} revisions`, '1 %%EOF', `${eofs} %%EOF`, eofs === 1);
   302	    }
   303	    const hits = scanMarkers(buf, fmt);
   304	    rec(doc, tag, `output ${fmt} metadata`, 'none', hits.length ? hits.join('+') : 'none', hits.length === 0);
   305	    if (fmt === 'jpg') { const icc = iccSafe(buf); rec(doc, tag, `output ${fmt} ICC`, `generic <=${ICC_MAX}B`, icc.note, icc.ok); }
   306	  } catch (e) { rec(doc, tag, `output ${fmt}`, 'clean', 'ERR:' + e.message.split('\n')[0], false); }
   307	}
   308	
   309	async function checkAiInject(page) {
   310	  const inj = SPECS.ai_inject; if (!inj) return;
   311	  await loadDoc(page, inj._doc, false);
   312	  for (const c of inj.cases) {
   313	    // fresh reload so each case is isolated
   314	    await loadDoc(page, inj._doc, false);
   315	    const res = await page.evaluate((ent) => {
   316	      const before = entities.length;
   317	      addEntities([ent]);
   318	      const added = entities.slice(before);
   319	      const mine = added.find(e => e.value === ent.value) || entities.find(e => e.value === ent.value && e.kind !== 'candidate' && e.type !== 'name-candidate');
   320	      const masked = window.__isMasked(ent.value);
   321	      return { present: !!mine, type: mine ? mine.type : null, mode: mine ? mine.mode : null, masked };
   322	    }, c.entity);
   323	    let pass, actual;
   324	    if (c.expect === 'masked') { pass = res.masked; actual = res.masked ? 'masked' : `not-masked(${res.type}/${res.mode})`; }
   325	    else if (c.expect === 'dropped') { pass = !res.present && !res.masked; actual = res.present ? `KEPT(${res.type}/${res.mode})` : 'dropped'; }
   326	    else { pass = !res.masked; actual = res.masked ? 'MASKED' : `visible(${res.type || 'dropped'}/${res.mode || '-'})`; }
   327	    rec('7_resume_dark.pdf', 'AI_INJECT', c.label + ` [${c.entity.type}:${c.entity.value}]`, c.expect, actual, pass);
   328	  }
   329	}
   330	
   331	async function checkAiCatState(page) {
   332	  const cs = SPECS.ai_cat_state; if (!cs) return;
   333	  await loadDoc(page, cs._doc, false);
   334	  const res = await page.evaluate(({ labels, want }) => {
   335	    // record active state BEFORE the AI merge, then inject AI labels
   336	    const before = {}; for (const t of want) before[t] = catEnabled[t] !== false;
   337	    addEntities(labels); renderAll();
   338	    const after = {}, boxChecked = {};
   339	    for (const t of want) {
   340	      after[t] = catEnabled[t] !== false;
   341	      const cb = document.querySelector(`#piiList input[data-cat="${t}"]`);
   342	      boxChecked[t] = cb ? cb.checked : null; // null = row not rendered (still a fail signal)
   343	    }
   344	    return { before, after, boxChecked };
   345	  }, { labels: cs.labels, want: cs.assert_enabled });
   346	  for (const t of cs.assert_enabled) {
   347	    const pass = res.after[t] === true && res.boxChecked[t] === true;
   348	    rec(cs._doc, 'AI_CAT_STATE', `${t} stays enabled`, 'on+checked',
   349	      `enabled=${res.after[t]} checked=${res.boxChecked[t]}`, pass);
   350	  }
   351	}
   352	
   353	async function checkCandidateDedup(page) {
   354	  const cd = SPECS.candidate_dedup; if (!cd) return;
   355	  for (const c of cd.cases) {
   356	    await loadDoc(page, cd._doc, false);   // fresh load so the base candidate is present
   357	    const res = await page.evaluate(({ cand, confirm }) => {
   358	      const before = window.__isCandidateContains(cand);
   359	      addEntities([confirm]); renderAll();
   360	      const after = window.__isCandidateContains(cand);
   361	      // Dedup must be directional: it removes redundant CANDIDATES, never the
   362	      // CONFIRMED entity that contains them. A reversed containment test (or a
   363	      // mutual-removal bug) would delete the confirmed name — leaving the value
   364	      // wholly UNMASKED. Assert the confirmed entity is still present after dedup.
   365	      // (Location isn't asserted here: these cases inject a superset value with a
   366	      // token absent from the fixture, so it is intentionally unlocated.)
   367	      const nc = window.__norm(confirm.value);
   368	      const confEnt = window.__entitySnapshot().find(e => e.kind !== 'candidate' && window.__norm(e.value) === nc);
   369	      return { before, after, confirmedSurvives: !!confEnt };
   370	    }, { cand: c.candidate, confirm: c.confirm });
   371	    let pass, actual;
   372	    if (c.expect === 'removed') {
   373	      pass = res.before && !res.after;
   374	      actual = !res.before ? 'not-present-before' : (res.after ? 'STILL present' : 'removed');
   375	    } else { // kept
   376	      pass = res.before && res.after;
   377	      actual = !res.before ? 'not-present-before' : (res.after ? 'kept' : 'DROPPED');
   378	    }
   379	    rec(cd._doc, 'CANDIDATE_DEDUP', `${c.label} [${c.confirm.value}]`, c.expect, actual, pass);
   380	    // Confirmed-preservation guard (the regression the candidate-only test missed):
   381	    // the confirmed entity that triggered the dedup must SURVIVE it.
   382	    rec(cd._doc, 'CONFIRMED_SURVIVES', `confirmed kept [${c.confirm.value}]`, 'survives',
   383	      res.confirmedSurvives ? 'survives' : 'REMOVED', res.confirmedSurvives);
   384	  }
   385	}
   386	
   387	/* ── JP golden ───────────────────────────────────────────────────────────────
   388	   Each JP fixture ships its own specs.json with a BOX TABLE in PNG pixel
   389	   coordinates plus, per 提出目的, which boxes must be hidden / recommended /
   390	   optional / kept. The harness replays that table against the live pipeline.
   391	
   392	   Coordinate frames: a PNG loads at its natural size, a PDF renders at
   393	   min(2.2, 1500/ptWidth) — so the mapping is a single uniform scale, taken at
   394	   runtime from page.w / fixtureWidth rather than hard-coded. A JPG fixture is
   395	   deliberately rotated and blurred (a phone photo), so its OCR boxes do NOT
   396	   land on the PNG coordinates; those cases assert at FIELD level instead and
   397	   say so, rather than quietly comparing coordinates that cannot match.
   398	
   399	   Which assertion a box gets comes from the LEGAL MATRIX level, not from which
   400	   list the fixture put it in — `mask` holds everything the purpose hides, at
   401	   both the automatic and the recommended strength, and those are different
   402	   promises. specs.json carries the key→level mapping (jp_auto_fields) so the
   403	   harness derives it independently of the app it is testing. */
   404	const JP_COVER_MIN = 0.6;      // a band must cover this much of a value/box
   405	const JP_KEEP_MAX = 0.10;      // a keep field may not be grazed by more than this
   406	function jpFieldOf(key) { return key.replace(/^m\d+_/, ''); }
   407	async function jpCheckBox(page, doc, cat, key, rect, kind) {
   408	  const items = await page.evaluate(r => window.__itemsIn(r), rect);
   409	  let frac, what;
   410	  if (items.length) {
   411	    // The meaningful question for a box holding text is whether the TEXT is
   412	    // covered — not whether the generator's padding around it was painted.
   413	    const fr = await Promise.all(items.map(it => page.evaluate(r => window.__coverage(r), it)));
   414	    frac = Math.min(...fr); what = `${items.length} item(s) min ${(frac * 100).toFixed(0)}%`;
   415	  } else {
   416	    frac = await page.evaluate(r => window.__coverage(r), rect); what = `area ${(frac * 100).toFixed(0)}%`;
   417	  }
   418	  if (kind === 'keep') { rec(doc, 'JP_KEEP', key, `<=${JP_KEEP_MAX * 100}%`, what, frac <= JP_KEEP_MAX); return; }
   419	  const covered = frac >= JP_COVER_MIN;
   420	  if (kind === 'mask') { rec(doc, 'JP_MASK', key, `>=${JP_COVER_MIN * 100}%`, what, covered); return; }
   421	  const cand = await page.evaluate(r => window.__candidateOver(r), rect);
   422	  if (kind === 'candidate') { rec(doc, 'JP_CANDIDATE', key, 'surfaced', cand ? (covered ? 'candidate+banded' : 'candidate') : 'MISSING', cand); return; }
   423	  if (kind === 'mask_or_candidate') {
   424	    rec(doc, 'JP_MASK_OR_CAND', key, 'banded or candidate', covered ? 'banded' : cand ? 'candidate' : 'NEITHER', covered || cand); return;
   425	  }
   426	  if (kind === 'optional') {   // detected, offered, and OFF until the user says so
   427	    rec(doc, 'JP_OPTIONAL', key, 'offered+clear', cand ? (frac <= JP_KEEP_MAX ? 'offered+clear' : 'OFFERED BUT BANDED') : 'MISSING', cand && frac <= JP_KEEP_MAX);
   428	  }
   429	}
   430	async function checkJpDoc(page, spec) {
   431	  const fx = JSON.parse(fs.readFileSync(path.join(__dirname, spec.fixture), 'utf8'));
   432	  const autoFields = (SPECS.jp_auto_fields || {})[spec.expect_doc] || [];
   433	  const mocFields = SPECS.jp_candidate_or_mask || [];
   434	  for (const c of spec.cases) {
   435	    const tag = `${spec.doc} [${c.purpose}]`;
   436	    await loadDoc(page, spec.doc, true);
   437	    await page.evaluate(p => jpSetPurpose(p), c.purpose);
   438	    const st = await page.evaluate(() => window.__jpState());
   439	    rec(tag, 'JP_CLASS', spec.expect_doc + (spec.expect_side ? '/' + spec.expect_side : ''), 'classified',
   440	      st.cls ? st.cls.doc + (st.cls.side ? '/' + st.cls.side : '') + ' sc=' + st.cls.score : 'NOT classified',
   441	      !!st.cls && st.cls.doc === spec.expect_doc && (!spec.expect_side || st.cls.side === spec.expect_side));
   442	    if (!st.cls) continue;
   443	    const autoCount = await page.evaluate(() => entities.filter(e => e.kind === 'auto').length);
   444	    process.stderr.write(`    [jp autoCount] ${tag} = ${autoCount}\n`);
   445	    if (c.min_auto != null) rec(tag, 'REGRESSION', `auto>=${c.min_auto}`, `>=${c.min_auto}`, String(autoCount), autoCount >= c.min_auto);
   446	    if (c.max_auto != null) rec(tag, 'REGRESSION', `auto<=${c.max_auto}`, `<=${c.max_auto}`, String(autoCount), autoCount <= c.max_auto);
   447	
   448	    // Field-level: every required field must have been FOUND. This is the only
   449	    // assertion a rotated phone-photo fixture can make, and it is also the one
   450	    // the 미탐 0 gate is actually about.
   451	    const got = new Set(st.fields.map(f => f.field));
   452	    for (const f of (c.require_fields || [])) rec(tag, 'JP_FIELD', f, 'detected', got.has(f) ? 'detected' : 'MISSING', got.has(f));
   453	    for (const f of (c.require_banded || [])) {
   454	      const on = st.fields.some(x => x.field === f && x.mode !== 'ok');
   455	      rec(tag, 'JP_BANDED', f, 'banded', on ? 'banded' : (got.has(f) ? 'DETECTED BUT CLEAR' : 'MISSING'), on);
   456	    }
   457	    // The inverse of require_banded, and the half that makes a purpose-gate test
   458	    // mean something: without it, "banded under 相談用共有" could be true simply
   459	    // because the field is banded under every purpose.
   460	    for (const f of (c.require_clear || [])) {
   461	      const hits = st.fields.filter(x => x.field === f);
   462	      const clear = hits.length > 0 && hits.every(x => x.mode === 'ok');
   463	      rec(tag, 'JP_CLEAR', f, 'detected+clear', hits.length ? (clear ? 'detected+clear' : 'BANDED') : 'MISSING', clear);
   464	    }
   465	    if (spec.geometry === false || c.geometry === false) continue;
   466	
   467	    const P = fx.purposes[c.key];
   468	    if (!P) { rec(tag, 'JP_SPEC', c.key, 'purpose in fixture', 'MISSING', false); continue; }
   469	    const scale = st.pw[0] / fx.size[0];
   470	    let checked = 0;
   471	    const box = k => { const b = fx.boxes_png[k]; return b && { pi: 0, x: b[0] * scale, y: b[1] * scale, w: (b[2] - b[0]) * scale, h: (b[3] - b[1]) * scale }; };
   472	    const seen = new Set(); const skipped = [];
   473	    const run = async (keys, kindFor) => {
   474	      for (const k of (keys || [])) {
   475	        if (k === 'ALL' || seen.has(k)) continue;
   476	        const r = box(k);
   477	        // The fixture's purpose list is shared across variants of the same
   478	        // document, so a key absent from THIS variant is not a case — but it is
   479	        // REPORTED, never silently dropped. A harness that quietly checks zero
   480	        // boxes prints the same green as one that checked forty.
   481	        if (!r) { skipped.push(k); continue; }
   482	        seen.add(k);
   483	        await jpCheckBox(page, tag, null, k, r, kindFor(k));
   484	        checked++;
   485	      }
   486	    };
   487	    // whole-face rule (マイナカード裏面 under a 本人確認 purpose)
   488	    if ((P.mask || []).includes('ALL')) {
   489	      const pg = await page.evaluate(() => ({ pi: 0, x: 0, y: 0, w: pages[0].w, h: pages[0].h }));
   490	      await jpCheckBox(page, tag, null, 'ALL(face)', pg, 'mask');
   491	      checked++;
   492	      for (const k of Object.keys(fx.boxes_png)) { const r = box(k); if (r) { await jpCheckBox(page, tag, null, k, r, 'mask'); checked++; } }
   493	      seen.add('ALL');
   494	    }
   495	    await run(P.mask, k => mocFields.includes(jpFieldOf(k)) ? 'mask_or_candidate'
   496	                        : autoFields.includes(jpFieldOf(k)) ? 'mask' : 'candidate');
   497	    await run(P.recommend, () => 'candidate');
   498	    await run(P.optional, () => 'optional');
   499	    await run(P.keep === 'all' ? [] : P.keep, () => 'keep');
   500	    rec(tag, 'JP_COVERAGE', `boxes checked (skipped: ${skipped.join(',') || 'none'})`, '>0', String(checked), checked > 0);
   501	    for (const fmt of (c.out_formats || [])) await checkOutput(page, tag, fmt);
   502	  }
   503	}
   504	
   505	/* ── JP unit rules ──────────────────────────────────────────────────────────
   506	   Two detection rules cannot be exercised by the alpha fixtures: none of the
   507	   four documents carries a phone number, and on all four the 住所 is a KEEP
   508	   field, so the address hierarchy's own scoring never decides anything there.
   509	   Shipping them with no coverage at all would be shipping untested detection,
   510	   so they are pinned at unit level against crafted strings — stated as such
   511	   rather than left to look like fixture coverage. */
   512	async function checkJpUnits(page) {
   513	  const U = SPECS.jp_units; if (!U) return;
   514	  for (const c of (U.address || [])) {
   515	    const got = await page.evaluate(t => {
   516	      const sp = jpAddressSpan(t, 0);
   517	      return sp ? { span: t.slice(sp.a, sp.b), score: sp.score, strong: !!(sp.postal && sp.pref) } : null;
   518	    }, c.text);
   519	    const ok = c.expect === null ? (got === null || got.score < 3)
   520	      : !!got && got.span === c.expect.span && got.score === c.expect.score && got.strong === !!c.expect.strong;
   521	    rec('(jp units)', 'JP_ADDRESS', c.label, c.expect === null ? 'no address' : `${c.expect.span} s=${c.expect.score}${c.expect.strong ? ' strong' : ''}`,
   522	      got ? `${got.span} s=${got.score}${got.strong ? ' strong' : ''}` : 'none', ok);
   523	  }
   524	  for (const c of (U.tel || [])) {
   525	    const got = await page.evaluate(t => {
   526	      const hy = JP_TEL_HYPHEN_RE.exec(t), pl = hy ? null : JP_TEL_PLAIN_RE.exec(t);
   527	      const m = hy || pl; return m ? { v: m[0], loose: !hy } : null;
   528	    }, c.text);
   529	    const ok = c.expect === null ? got === null
   530	      : !!got && got.v === c.expect.v && got.loose === !!c.expect.loose;
   531	    rec('(jp units)', 'JP_TEL', c.label, c.expect === null ? 'no match' : `${c.expect.v}${c.expect.loose ? ' (candidate)' : ''}`,
   532	      got ? `${got.v}${got.loose ? ' (candidate)' : ''}` : 'none', ok);
   533	  }
   534	}
   535	
   536	function printTable() {
   537	  const pad = (s, n) => { s = String(s); return s.length > n ? s.slice(0, n - 1) + '…' : s.padEnd(n); };
   538	  let lastDoc = '';
   539	  console.log('\n' + '═'.repeat(120));
   540	  console.log(pad('DOC', 20) + pad('CATEGORY', 17) + pad('ITEM', 40) + pad('EXPECTED', 18) + pad('ACTUAL', 18) + 'RESULT');
   541	  console.log('─'.repeat(120));
   542	  for (const r of rows) {
   543	    if (r.doc !== lastDoc) { console.log('─'.repeat(120)); lastDoc = r.doc; }
   544	    const mark = r.info ? (r.pass ? 'ℹ ok' : 'ℹ note') : (r.pass ? '✅ PASS' : '❌ FAIL');
   545	    console.log(pad(r.doc, 20) + pad(r.cat, 17) + pad(r.item, 40) + pad(r.expected, 18) + pad(r.actual, 18) + mark);
   546	  }
   547	  console.log('═'.repeat(120));
   548	  const gating = rows.filter(r => !r.info);
   549	  const fails = gating.filter(r => !r.pass);
   550	  const byCat = {};
   551	  for (const r of gating) { byCat[r.cat] = byCat[r.cat] || { p: 0, f: 0 }; r.pass ? byCat[r.cat].p++ : byCat[r.cat].f++; }
   552	  console.log('\nSummary by category:');
   553	  for (const [c, v] of Object.entries(byCat)) console.log(`  ${pad(c, 18)} ${v.p} pass / ${v.f} fail`);
   554	  console.log(`\n  TOTAL: ${gating.length - fails.length}/${gating.length} pass, ${fails.length} FAIL`);
   555	  if (fails.length) {
   556	    console.log('\n  Failing:');
   557	    for (const r of fails) console.log(`    ✗ [${r.doc}] ${r.cat} — ${r.item}  (expected ${r.expected}, got ${r.actual})`);
   558	  }
   559	  return fails.length;
   560	}
   560	}
   561	
   562	(async () => {
   563	  const srv = await startServer();
   564	  const port = srv.address().port;
   565	  const URL = `http://127.0.0.1:${port}/safe/index.html`;
   566	  const browser = await chromium.launch({ channel: 'chrome', headless: true });
   567	  const ctx = await browser.newContext({ acceptDownloads: true, locale: 'ko-KR', viewport: { width: 1200, height: 900 } });
   568	  const page = await ctx.newPage();
   569	  const consoleErrors = [];
   570	  page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
   571	  page.on('pageerror', e => consoleErrors.push('PageError: ' + e.message));
   572	  await page.goto(URL, { waitUntil: 'networkidle' });
   573	  await page.evaluate(() => { LANG = 'ko'; applyLang(); });
   574	
   575	  const docs = SPECS.docs.filter(d => !onlyArg || d.doc === onlyArg);
   576	  for (const spec of docs) {
   577	    process.stderr.write(`… ${spec.doc}\n`);
   578	    try { await checkDoc(page, spec); }
   579	    catch (e) { rec(spec.doc, 'LOAD', spec.doc, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
   580	  }
   581	  for (const spec of (SPECS.jp_docs || [])) {
   582	    if (onlyArg && spec.doc !== onlyArg) continue;
   583	    process.stderr.write(`… ${spec.doc}\n`);
   584	    // The JP presets only exist in the Japanese UI, and OCR language follows it.
   585	    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
   586	    try { await checkJpDoc(page, spec); }
   587	    catch (e) { rec(spec.doc, 'LOAD', spec.doc, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
   588	    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
   589	  }
   590	  if (!onlyArg || onlyArg === '(jp units)') { process.stderr.write('… jp units\n'); await checkJpUnits(page); }
   591	  if (!onlyArg || onlyArg === '7_resume_dark.pdf') { process.stderr.write('… ai_inject\n'); await checkAiInject(page); }
   592	  if (!onlyArg || onlyArg === '7_resume_dark.pdf') { process.stderr.write('… ai_cat_state\n'); await checkAiCatState(page); }
   593	  if (!onlyArg || onlyArg === (SPECS.candidate_dedup && SPECS.candidate_dedup._doc)) { process.stderr.write('… candidate_dedup\n'); await checkCandidateDedup(page); }
   594	
   595	  const failCount = printTable();
   596	  if (consoleErrors.length) { console.log('\n  ⚠ console errors:'); consoleErrors.slice(0, 10).forEach(e => console.log('    ' + e)); }
   597	  fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify({ rows, consoleErrors }, null, 2));
   598	
   599	  await browser.close(); srv.close();
   600	  process.exit(failCount ? 1 : 0);
   601	})().catch(e => { console.error(e); process.exit(2); });

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "git show 546344b:public/safe/index.html | nl -ba | sed -n '2200,2278p'; git show 546344b:public/safe/index.html | nl -ba | sed -n '2310,2385p'; git show 546344b:public/safe/index.html | nl -ba | sed -n '2385,2480p'; git show 546344b:public/safe/index.html | nl -ba | sed -n '2480,2610p'" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
  2200	    // a guess must not silently delete content from a document the user is about
  2201	    // to submit. A caller that knows better (the JP purpose presets, where the
  2202	    // legal matrix says 既定ON) passes an explicit mode and overrides this.
  2203	    const mode = e.mode || (kind==='candidate' ? 'ok' : catDefault[type]);
  2204	    entities.push({id:'e'+Math.random().toString(36).slice(2,8),type,value:v,mode,kind,reason,boxes});
  2205	  }
  2206	  entities.sort((a,b)=>Object.keys(TYPES).indexOf(a.type)-Object.keys(TYPES).indexOf(b.type));
  2207	  dedupeCandidates();
  2208	}
  2209	// Remove review candidates wholly contained (as whole space-separated tokens) in a
  2210	// CONFIRMED entity's value — e.g. confirmed "MANSI GAZAL TIWARI" makes the candidate
  2211	// "MANSI GAZAL" redundant (the confirmed mask already covers it). Only the shorter,
  2212	// fully-contained candidate is dropped; a candidate that adds tokens is kept. Runs
  2213	// after every addEntities batch so a later AI-confirmed name also clears an earlier
  2214	// candidate.
  2215	function dedupeCandidates(){
  2216	  const norm=s=>(s||'').toLowerCase().replace(/\s+/g,' ').trim();
  2217	  const confirmed=entities.filter(e=>e.kind!=='candidate').map(e=>norm(e.value)).filter(Boolean);
  2218	  if(!confirmed.length) return;
  2219	  entities=entities.filter(e=>{
  2220	    if(e.kind!=='candidate') return true;
  2221	    const cv=norm(e.value); if(!cv) return true;
  2222	    return !confirmed.some(fv=>fv!==cv && (' '+fv+' ').includes(' '+cv+' '));
  2223	  });
  2224	}
  2225	const located=e=>e.boxes&&e.boxes.length>0;
  2226	
  2227	function renderAll(){ renderList(); drawPreview(); updateMake(); }
  2228	function updateMake(){ $('btnMake').disabled = !pages.length || !( entities.some(e=>isOn(e)&&e.mode!=='ok'&&located(e)) || wmEnabled() ); }
  2229	function escapeHtml(s){return s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
  2230	
  2231	/* ───────── preview (rendered page + live redaction overlay) ───────── */
  2232	function buildPreview(){
  2233	  const host=$('preview'); host.innerHTML=''; previewCanvases=[];
  2234	  if(!pages.length) return;
  2235	  const dispW=Math.min(host.clientWidth-24||600, 660);
  2236	  pages.forEach((page,pi)=>{
  2237	    const scale=dispW/page.w;
  2238	    const cv=canvasEl(dispW, page.h*scale); cv.className='pg';
  2239	    cv.dataset.pi=pi; cv.dataset.scale=scale;
  2240	    host.appendChild(cv); previewCanvases.push(cv);
  2241	    attachSelect(cv);
  2242	  });
  2243	  drawPreview();
  2244	}
  2245	function drawPreview(){
  2246	  previewCanvases.forEach(cv=>{
  2247	    const pi=+cv.dataset.pi, scale=+cv.dataset.scale, page=pages[pi];
  2248	    if(!page) return;
  2249	    const ctx=cv.getContext('2d');
  2250	    ctx.clearRect(0,0,cv.width,cv.height);
  2251	    ctx.drawImage(page.canvas,0,0,cv.width,cv.height);
  2252	    drawRedactions(ctx,pi,scale);
  2253	    if(wmEnabled()) drawWatermark(ctx,cv.width,cv.height,wmText());
  2254	  });
  2255	}
  2256	// Merge an entity's boxes that sit on the same visual line into one rect, so a
  2257	// wrapped address (multiple boxes) is covered cleanly and the partial value is
  2258	// drawn once — not duplicated per box.
  2259	function mergeLineBoxes(boxes,pi){
  2260	  const arr=boxes.filter(b=>b.page===pi).slice().sort((a,b)=>a.y-b.y||a.x-b.x);
  2261	  const used=new Array(arr.length).fill(false), lines=[];
  2262	  for(let i=0;i<arr.length;i++){
  2263	    if(used[i])continue;
  2264	    let x0=arr[i].x,y0=arr[i].y,x1=arr[i].x+arr[i].w,y1=arr[i].y+arr[i].h,bg=arr[i].bg,region=arr[i].region;
  2265	    used[i]=true;
  2266	    for(let j=i+1;j<arr.length;j++){
  2267	      if(used[j])continue; const b=arr[j];
  2268	      const oy0=Math.max(y0,b.y), oy1=Math.min(y1,b.y+b.h);
  2269	      const ov=(oy1-oy0)/Math.max(1,Math.min(y1-y0,b.h));
  2270	      if(ov>0.5){ x0=Math.min(x0,b.x);y0=Math.min(y0,b.y);x1=Math.max(x1,b.x+b.w);y1=Math.max(y1,b.y+b.h);used[j]=true;region=region||b.region; }
  2271	    }
  2272	    lines.push({x:x0,y:y0,w:x1-x0,h:y1-y0,bg,region});
  2273	  }
  2274	  return lines.sort((a,b)=>a.y-b.y||a.x-b.x);
  2275	}
  2276	// The band drawn for a merged line box: the text/OCR box grown by a margin of
  2277	// 15% of the box height (floor 2px) on every side. The margin exists because the
  2278	// box is an ESTIMATE — pdf.js item boxes exclude side bearings and overshoot,
  2310	function isDarkColor(bg){
  2311	  const m=/rgb\((\d+),\s*(\d+),\s*(\d+)\)/.exec(bg||''); if(!m) return false;
  2312	  return (0.299*+m[1]+0.587*+m[2]+0.114*+m[3]) < 130;
  2313	}
  2314	// Band-only redaction: every active entity becomes one opaque rect per visual
  2315	// line, grown by bandRect(). There is no ordering or overlap subtlety left to
  2316	// get wrong — two entities landing on the same coordinates simply paint the same
  2317	// opaque colour twice. (The previous partial-mask path needed an escalation pass
  2318	// to stop two asterisk strings from ghosting over each other and leaving an
  2319	// uncovered tail; removing the mode removed that whole failure class.)
  2320	function drawRedactions(ctx,pi,scale){
  2321	  const S=v=>v*scale;
  2322	  const col=bandColor();
  2323	  for(const e of entities){
  2324	    if(!isOn(e)||e.mode==='ok') continue;
  2325	    const lines=mergeLineBoxes(e.boxes,pi);
  2326	    if(!lines.length) continue;
  2327	    ctx.fillStyle=col;
  2328	    for(const l of lines){ const r=bandRect(l); ctx.fillRect(S(r.x),S(r.y),S(r.w),S(r.h)); }
  2329	  }
  2330	}
  2331	function drawWatermark(ctx,W,H,text){
  2332	  if(!text) return;
  2333	  ctx.save();
  2334	  // keep bottom margin clear (QR/stamp/signature area) + small top margin
  2335	  ctx.beginPath(); ctx.rect(0, H*0.05, W, H*0.81); ctx.clip();
  2336	  ctx.globalAlpha=0.10; ctx.fillStyle=INK;
  2337	  const fs=Math.max(16, W*0.028);
  2338	  ctx.font='700 '+fs+'px "IBM Plex Sans KR",sans-serif';
  2339	  ctx.textAlign='center'; ctx.textBaseline='middle';
  2340	  ctx.translate(W/2,H/2); ctx.rotate(-Math.PI/6);
  2341	  const tw=ctx.measureText(text).width;
  2342	  const stepX=tw+fs*3.5, stepY=fs*4.2, diag=Math.hypot(W,H);
  2343	  for(let yy=-diag; yy<diag; yy+=stepY) for(let xx=-diag; xx<diag; xx+=stepX) ctx.fillText(text,xx,yy);
  2344	  ctx.restore();
  2345	}
  2346	
  2347	/* ───────── manual region selection (drag to redact photo/signature/name) ───────── */
  2348	let selectMode=false, sel=null;
  2349	function setSelectMode(on){
  2350	  selectMode=on;
  2351	  const btn=$('btnSelect'); if(btn){ btn.classList.toggle('on',on); btn.textContent=on? T().btnSelectOn : T().btnSelect; }
  2352	  $('preview').classList.toggle('selmode',on);
  2353	  const hint=$('selHint'); if(hint) hint.style.display=on?'block':'none';
  2354	}
  2355	function attachSelect(cv){
  2356	  const toCanvas=e=>{ const r=cv.getBoundingClientRect(); return { x:(e.clientX-r.left)*(cv.width/r.width), y:(e.clientY-r.top)*(cv.height/r.height) }; };
  2357	  cv.addEventListener('pointerdown',e=>{
  2358	    if(!selectMode) return; e.preventDefault();
  2359	    try{cv.setPointerCapture(e.pointerId);}catch(_){}
  2360	    const p=toCanvas(e); sel={cv,x0:p.x,y0:p.y,x1:p.x,y1:p.y};
  2361	  });
  2362	  cv.addEventListener('pointermove',e=>{
  2363	    if(!selectMode||!sel||sel.cv!==cv) return; e.preventDefault();
  2364	    const p=toCanvas(e); sel.x1=p.x; sel.y1=p.y; drawSelOverlay();
  2365	  });
  2366	  const finish=e=>{ if(!selectMode||!sel||sel.cv!==cv) return; e.preventDefault(); finalizeSel(); };
  2367	  cv.addEventListener('pointerup',finish);
  2368	  cv.addEventListener('pointercancel',()=>{ sel=null; drawPreview(); });
  2369	}
  2370	function drawSelOverlay(){
  2371	  if(!sel) return;
  2372	  const cv=sel.cv, ctx=cv.getContext('2d'), pi=+cv.dataset.pi, scale=+cv.dataset.scale, page=pages[pi];
  2373	  ctx.clearRect(0,0,cv.width,cv.height);
  2374	  ctx.drawImage(page.canvas,0,0,cv.width,cv.height);
  2375	  drawRedactions(ctx,pi,scale);
  2376	  if(wmEnabled()) drawWatermark(ctx,cv.width,cv.height,wmText());
  2377	  const x=Math.min(sel.x0,sel.x1), y=Math.min(sel.y0,sel.y1), w=Math.abs(sel.x1-sel.x0), h=Math.abs(sel.y1-sel.y0);
  2378	  ctx.save();
  2379	  ctx.fillStyle='rgba(23,20,15,0.30)'; ctx.fillRect(x,y,w,h);
  2380	  ctx.strokeStyle=INK; ctx.lineWidth=2; ctx.setLineDash([6,4]); ctx.strokeRect(x,y,w,h);
  2381	  ctx.restore();
  2382	}
  2383	function finalizeSel(){
  2384	  const s=sel; sel=null;
  2385	  if(!s){ return; }
  2385	  if(!s){ return; }
  2386	  const pi=+s.cv.dataset.pi, scale=+s.cv.dataset.scale, page=pages[pi];
  2387	  const dx=Math.min(s.x0,s.x1), dy=Math.min(s.y0,s.y1), dw=Math.abs(s.x1-s.x0), dh=Math.abs(s.y1-s.y0);
  2388	  if(dw<8||dh<8){ drawPreview(); toast(T().tSelSmall); return; }
  2389	  // region:true — the drag rectangle IS the intent; bandRect must not grow it.
  2390	  const box={page:pi, x:dx/scale, y:dy/scale, w:dw/scale, h:dh/scale, region:true}; // display px → page px
  2391	  box.bg=sampleBg(page,box);
  2392	  entities.push({id:'e'+Math.random().toString(36).slice(2,8),type:'manual',value:'('+T().manualItem+')',mode:'no',kind:'manual',boxes:[box]});
  2393	  renderAll();
  2394	  toast(T().tManualAdded);
  2395	}
  2396	$('btnSelect').addEventListener('click',()=>setSelectMode(!selectMode));
  2397	$('jpPurpose').addEventListener('change',e=>jpSetPurpose(e.target.value));
  2398	
  2399	/* ───────── detection list (live value next to toggle) ───────── */
  2400	function catRowHtml(type,items){
  2401	  const on=catEnabled[type], d=catDefault[type], t=T();
  2402	  return `
  2403	  <div class="cat-row ${on?'':'off'}">
  2404	    <div class="cat-head">
  2405	      <label class="cat-tgl">
  2406	        <input type="checkbox" data-cat="${type}" ${on?'checked':''}>
  2407	        <span class="cl">${TYPES[type].icon} ${tLabel(type)}</span>
  2408	      </label>
  2409	      <span class="cnt ${items.length?'hit':''}">${items.length? t.cnt(items.length) : ''}</span>
  2410	      <div class="seg" data-cat-seg="${type}" role="radiogroup">
  2411	        <button class="${d==='ok'?'on-ok':''}" data-cmode="ok">${t.segOk}</button>
  2412	        <button class="${d==='no'?'on-no':''}" data-cmode="no">${t.segNo}</button>
  2413	      </div>
  2414	    </div>
  2415	    ${items.length?`<div class="cat-items">${items.map(e=>`
  2416	      <div class="pii-item${located(e)?'':' nolocate'}">
  2417	        <span class="val mono" title="${escapeHtml(e.value)}">${escapeHtml(displayValue(e))}</span>
  2418	        ${located(e)?'':`<span class="nl">${t.notLocated}</span>`}
  2419	        <div class="seg" role="radiogroup">
  2420	          <button class="${e.mode==='ok'?'on-ok':''}" data-id="${e.id}" data-mode="ok">${t.segOk}</button>
  2421	          <button class="${e.mode==='no'?'on-no':''}" data-id="${e.id}" data-mode="no">${t.segNo}</button>
  2422	        </div>
  2423	      </div>`).join('')}</div>`:''}
  2424	  </div>`;
  2425	}
  2426	// Flat item box for manual selections / name candidates (not category-grouped).
  2427	function sectionHtml(kind,title,items){
  2428	  const t=T(), cand=kind==='candidate';
  2429	  const icon=kind==='candidate'?'❓':kind==='keep'?'🛡':'✏️';
  2430	  return `
  2431	  <div class="cat-row sec-${kind}">
  2432	    <div class="cat-head">
  2433	      <span class="cl">${icon} ${title}</span>
  2434	      <span class="cnt hit">${t.cnt(items.length)}</span>
  2435	    </div>
  2436	    <div class="cat-items">${items.map(e=>`
  2437	      <div class="pii-item${cand?' is-cand':''}">
  2438	        <div class="val-wrap">
  2439	          <span class="val ${cand?'':'mono'}" title="${escapeHtml(e.value)}">${escapeHtml(kind==='manual'? t.manualItem : displayValue(e))}</span>
  2440	          ${(cand||kind==='keep')?`<span class="reason">${(TYPES[e.type]||{}).icon||''} ${t.reasons[e.reason]||(e.jp?t.reasons.jp_keep:t.reasons.name)}</span>`:''}
  2441	        </div>
  2442	        <div class="seg" role="radiogroup">
  2443	          <button class="${e.mode==='ok'?'on-ok':''}" data-id="${e.id}" data-mode="ok">${t.segOk}</button>
  2444	          <button class="${e.mode==='no'?'on-no':''}" data-id="${e.id}" data-mode="no">${t.segNo}</button>
  2445	        </div>
  2446	        ${kind==='manual'?`<button class="del" data-del="${e.id}" title="remove" aria-label="remove">✕</button>`:''}
  2447	      </div>`).join('')}</div>
  2448	  </div>`;
  2449	}
  2450	function renderList(){
  2451	  const list=$('piiList'), t=T();
  2452	  const autoE=entities.filter(e=>e.kind!=='candidate'&&e.kind!=='manual'&&e.kind!=='keep');
  2453	  const manualE=entities.filter(e=>e.kind==='manual');
  2454	  const candE=entities.filter(e=>e.kind==='candidate');
  2455	  const keepE=entities.filter(e=>e.kind==='keep');
  2456	  const total=entities.filter(isOn).length;
  2457	  $('piiCount').textContent= total? t.cntUse(total):'';
  2458	  document.querySelectorAll('#bulkBtns button').forEach(b=>b.disabled=!total);
  2459	  $('catHint').textContent = pages.length? t.hintAfter : t.hintBefore;
  2460	  const groups={};
  2461	  for(const e of autoE){(groups[e.type]=groups[e.type]||[]).push(e);}
  2462	  const all=Object.keys(TYPES).filter(ty=>ty!=='manual');
  2463	  if(!pages.length){
  2464	    list.innerHTML = all.map(ty=>catRowHtml(ty,[])).join('');
  2465	    return;
  2466	  }
  2467	  const hits=all.filter(ty=>groups[ty]&&groups[ty].length);
  2468	  const misses=all.filter(ty=>!groups[ty]||!groups[ty].length);
  2469	  let html=hits.map(ty=>catRowHtml(ty,groups[ty])).join('');
  2470	  if(misses.length){
  2471	    html+=`<button class="more-cats" id="moreCats">${showAllCats? t.moreHide : t.moreShow(misses.length)}</button>`;
  2472	    if(showAllCats) html+=misses.map(ty=>catRowHtml(ty,[])).join('');
  2473	  }
  2474	  if(manualE.length) html+=sectionHtml('manual', t.manualSection, manualE);
  2475	  if(candE.length)   html+=sectionHtml('candidate', t.candSection, candE);
  2476	  if(keepE.length)   html+=sectionHtml('keep', t.keepSection, keepE);
  2477	  list.innerHTML=html;
  2478	}
  2479	$('piiList').addEventListener('change',e=>{
  2480	  const cb=e.target.closest('input[data-cat]'); if(!cb) return;
  2480	  const cb=e.target.closest('input[data-cat]'); if(!cb) return;
  2481	  catEnabled[cb.dataset.cat]=cb.checked; renderAll();
  2482	});
  2483	$('piiList').addEventListener('click',e=>{
  2484	  if(e.target.closest('#moreCats')){showAllCats=!showAllCats;renderList();return;}
  2485	  const del=e.target.closest('button[data-del]');
  2486	  if(del){ entities=entities.filter(x=>x.id!==del.dataset.del); renderAll(); toast(T().tManualRemoved); return; }
  2487	  const cm=e.target.closest('button[data-cmode]');
  2488	  if(cm){
  2489	    const type=cm.closest('[data-cat-seg]').dataset.catSeg;
  2490	    catDefault[type]=cm.dataset.cmode;
  2491	    entities.filter(x=>x.type===type).forEach(x=>x.mode=cm.dataset.cmode);
  2492	    renderAll(); return;
  2493	  }
  2494	  const b=e.target.closest('button[data-id]'); if(!b) return;
  2495	  const ent=entities.find(x=>x.id===b.dataset.id); if(!ent) return;
  2496	  // A `keep` field is one the legal matrix says the RECIPIENT needs. Hiding it
  2497	  // is the user's call, but it must not be a silent one — the usual failure is
  2498	  // a rejected submission and a second round of sending the same document.
  2499	  if(ent.kind==='keep' && b.dataset.mode!=='ok') toast(T().jpKeepWarn);
  2500	  ent.mode=b.dataset.mode; renderAll();
  2501	});
  2502	$('bulkBtns').addEventListener('click',e=>{
  2503	  const b=e.target.closest('button[data-mode]'); if(!b||b.disabled) return;
  2504	  const hidesKeep = b.dataset.mode!=='ok' && entities.some(x=>isOn(x)&&x.kind==='keep');
  2505	  entities.filter(isOn).forEach(x=>x.mode=b.dataset.mode); renderAll();
  2506	  toast(hidesKeep? T().jpKeepWarn : b.dataset.mode==='ok'?T().tBulkOk:T().tBulkNo);
  2507	});
  2508	
  2509	/* ───────── AI scan (text-only; maps found strings back to boxes) ───────── */
  2510	$('btnAI').addEventListener('click',runAI);
  2511	async function runAI(){
  2512	  if(aiDone){toast(T().tAIDup);return;}
  2513	  if(!docText){return;}
  2514	  const btn=$('btnAI');
  2515	  btn.disabled=true; btn.innerHTML='<span class="spinner"></span>'+T().aiBusy;
  2516	  try{
  2517	    const res=await fetch('/api/safe_scan',{
  2518	      method:'POST',headers:{'Content-Type':'application/json'},
  2519	      body:JSON.stringify({text: docText.slice(0,6000)})
  2520	    });
  2521	    const data=await res.json();
  2522	    if(!res.ok||data.error) throw new Error(data.error||'scan_failed');
  2523	    const raw=(data.raw||'').replace(/```json|```/g,'').trim();
  2524	    addEntities(JSON.parse(raw));
  2525	    aiDone=true;
  2526	    btn.innerHTML='✅ '+T().aiDone;
  2527	    setStatus(T().scanAI(entities.length));
  2528	    renderAll();
  2529	    toast(T().tAIDone);
  2530	  }catch(err){
  2531	    console.error(err);
  2532	    btn.disabled=false; btn.innerHTML='🤖 <span data-i18n="btnAI">'+T().btnAI+'</span>';
  2533	    toast(T().tAIFail);
  2534	  }
  2535	}
  2536	
  2537	/* ───────── watermark controls ───────── */
  2538	// {date} is filled with today's date at build time rather than left as a
  2539	// "YYYY-MM-DD" placeholder: the dated preset exists so the recipient can see WHEN
  2540	// the copy was handed over, and a watermark reading "YYYY-MM-DD" says nothing.
  2541	const wmPreset=i=>(T().wmPresets[i]||'').replace('{date}', new Date().toISOString().slice(0,10));
  2542	function buildWmPresets(){
  2543	  const sel=$('wmPreset'); if(!sel) return;
  2544	  const prev=sel.value;
  2545	  const t=T();
  2546	  sel.innerHTML = t.wmPresets.map((p,i)=>`<option value="p${i}">${escapeHtml(wmPreset(i))}</option>`).join('') + `<option value="custom">${t.wmCustom}</option>`;
  2547	  // keep prior selection if still valid
  2548	  if(prev && [...sel.options].some(o=>o.value===prev)) sel.value=prev; else sel.value='p0';
  2549	  if($('wmText') && !$('wmText').value) $('wmText').value=wmPreset(0);
  2550	}
  2551	$('wmOn').addEventListener('change',()=>{ $('wmBody').classList.toggle('on',$('wmOn').checked); drawPreview(); updateMake(); });
  2552	$('wmPreset').addEventListener('change',()=>{ const v=$('wmPreset').value; if(v!=='custom'){ const i=+v.slice(1); $('wmText').value=wmPreset(i); } else { $('wmText').focus(); } drawPreview(); updateMake(); });
  2553	$('wmText').addEventListener('input',()=>{ drawPreview(); updateMake(); });
  2554	const wmEnabled=()=>$('wmOn').checked && $('wmText').value.trim().length>0;
  2555	const wmText=()=>$('wmText').value.trim();
  2556	
  2557	/* ───────── build & download (flattened raster) ───────── */
  2558	function buildMaskedText(){
  2559	  let out=docText;
  2560	  const sorted=[...entities].filter(isOn).sort((a,b)=>b.value.length-a.value.length);
  2561	  for(const e of sorted){
  2562	    if(e.mode==='ok') continue;
  2563	    const re=new RegExp(e.value.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'),'g');
  2564	    out=out.replace(re, maskBlockText(e.value));
  2565	  }
  2566	  return out;
  2567	}
  2568	function composePage(pi){
  2569	  const page=pages[pi];
  2570	  const cv=canvasEl(page.w,page.h);
  2571	  const ctx=cv.getContext('2d');
  2572	  ctx.drawImage(page.canvas,0,0);
  2573	  drawRedactions(ctx,pi,1);
  2574	  if(wmEnabled()) drawWatermark(ctx,cv.width,cv.height,wmText());
  2575	  return cv;
  2576	}
  2577	$('btnMake').addEventListener('click',async()=>{
  2578	  const btn=$('btnMake'); btn.disabled=true;
  2579	  setStatus(T().building);
  2580	  try{
  2581	    const outs=pages.map((_,pi)=>composePage(pi));
  2582	    const fmt=document.querySelector('input[name=fmt]:checked').value;
  2583	    const base=(docTitle||'doc').replace(/\.[^.]+$/,'')+'_safe';
  2584	    if(fmt==='pdf'){
  2585	      const {jsPDF}=await ensureJsPDF();
  2586	      let doc;
  2587	      outs.forEach((cv,i)=>{
  2588	        const wpt=pages[i].ptW, hpt=pages[i].ptH, o=wpt>hpt?'l':'p';
  2589	        if(i===0) doc=new jsPDF({unit:'pt',format:[wpt,hpt],orientation:o});
  2590	        else doc.addPage([wpt,hpt], o);
  2591	        doc.addImage(cv.toDataURL('image/jpeg',0.92),'JPEG',0,0,wpt,hpt);
  2592	      });
  2593	      lastOut={fmt:'pdf', pdf:doc, name:base+'.pdf'};
  2594	      showResult(outs);
  2595	    } else {
  2596	      const type=fmt==='jpg'?'image/jpeg':'image/png';
  2597	      const dataUrls=outs.map(cv=>cv.toDataURL(type,0.92));
  2598	      lastOut={fmt, dataUrls, name:base+'.'+fmt};
  2599	      showResult(outs);
  2600	    }
  2601	    const hidden=entities.filter(e=>isOn(e)&&e.mode!=='ok'&&located(e)).reduce((s,e)=>s+e.boxes.length,0);
  2602	    toast(hidden? T().tMade(hidden) : T().tMadeWM);
  2603	  }catch(err){ console.error(err); toast(T().tReadFail); }
  2604	  finally{ setStatus(''); btn.disabled=false; }
  2605	});
  2606	/* ───────── result viewer (fit-to-page, pager, zoom, fullscreen) ───────── */
  2607	let rvPages=[];        // composed source canvases (final pixels)
  2608	let rvIndex=0;         // current page
  2609	let rvZoom=null;       // null = fit-to-page; else multiplier of fit (>1)
  2610	let rvIsFull=false;    // fullscreen overlay open?

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'git show 546344b:public/safe/index.html | nl -ba | rg "function isOn|const isOn|catEnabled|catDefault"' in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
   751	const catEnabled={}, catDefault={};
   776	Object.keys(TYPES).forEach(t=>{catEnabled[t]=true;catDefault[t]=TYPES[t].risk;});
   777	const isOn=e=>catEnabled[e.type]!==false;
  2203	    const mode = e.mode || (kind==='candidate' ? 'ok' : catDefault[type]);
  2401	  const on=catEnabled[type], d=catDefault[type], t=T();
  2481	  catEnabled[cb.dataset.cat]=cb.checked; renderAll();
  2490	    catDefault[type]=cm.dataset.cmode;

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "git show 546344b:test/safe/fixtures/jp/gen.py | nl -ba | sed -n '1,280p'; for f in test/safe/fixtures/jp/*/*.specs.json; do echo \"FILE "'$f"; git show 546344b:$f | rg -n '"'name|address|number|watermark|boxes_png|purposes|公安|公印|市長|顔写真|写真|logo|qr|個人番号|免許'; done" in /Users/sunghoon/Projects/docpack
 succeeded in 2ms:
7: "boxes_png": {
14:  "name": [
26:  "address": [
57: "doc": "運転免許証",
59: "purposes": {
66:    "name",
68:    "address",

hook: PostToolUse
hook: PostToolUse Completed
codex
동적 실행은 시도했지만 샌드박스가 로컬 서버 바인딩을 `EPERM`으로 차단해 한 건도 실행되지 않았습니다. 따라서 최종 보고서는 명확히 “정적 검토”로 표기하고, 구현자가 남긴 389/389 로그를 제가 재현한 결과처럼 취급하지 않겠습니다. 법률 부분은 일본 정부의 현행 원문으로 별도 검증 중입니다.
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: site:elaws.e-gov.go.jp 番号法施行令 別表 検査用数字 Qn 個人番号 ...
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: 個人番号 検査用数字 算式 Pn Qn n 6 番号法施行令 PDF ...
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: W3C PNG specification ancillary chunks unknown private chunk safe-to-copy iCCP tIME ...
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: site:city.*.jp 住民票 見本 PDF 氏名 世帯全員 ...
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'git show 546344b:public/safe/index.html | nl -ba | rg "strong|viaFallback|checkOk|unlabelledCode"' in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
   101	.dropzone strong{font-size:15px}
   179	.make .info strong{font-size:15px}
   246	.partner-card strong{font-size:14px;display:block;margin-bottom:4px}
   261	.install-banner .ib-body strong{display:block;font-size:13.5px;font-weight:700;letter-spacing:-.01em}
   334	          <strong data-i18n="dzTitle">파일을 끌어다 놓거나 클릭하세요</strong>
   397	        <strong><span class="step-n" style="vertical-align:-4px;margin-right:6px">3</span><span data-i18n="s3">문서 만들기</span></strong>
   471	      <a class="partner-card" href="https://slimfile.net" target="_blank" rel="noopener"><strong>🗜 SlimFile</strong><span data-i18n="pSlim">이미지 압축과 PDF 변환, 2MB 이하로 간단하게.</span></a>
   472	      <a class="partner-card" href="https://schooljob.site" target="_blank" rel="noopener"><strong>🎓 Schooljob</strong><span data-i18n="pSchool">선생님을 위한 채용 정보, 딱 맞는 학교 찾기.</span></a>
   473	      <a class="partner-card" href="https://hellokorean.org" target="_blank" rel="noopener"><strong>🌏 HelloKorean</strong><span data-i18n="pHello">한국어 배우기, 오늘부터 시작하세요.</span></a>
   487	    <strong id="ibTitle"></strong>
  1624	        const extra = r.field === 'my_number' ? { checkOk: myNumberCheckOk(sp.digits) } : {};
  1675	        push('hokensha_bango', jpBoxes(seg, a, b), seg.t.slice(a,b), { viaFallback: true });
  1686	        if (len === 12) push('my_number', jpBoxes(seg, a, b), seg.t.slice(a,b), { checkOk: myNumberCheckOk(seg.t.slice(a,b)), viaFallback: true });
  1687	        else if (len === 11) push('jumin_code', jpBoxes(seg, a, b), seg.t.slice(a,b), { viaFallback: true });
  1709	      push('address_loose', jpBoxes(seg, sp.a, sp.b), seg.t.slice(sp.a, sp.b), { strong: sp.postal && sp.pref });
  1728	    for (const cb of jpCodeBlocks(pi)) push('qr', [cb.box], '二次元コード', { unlabelledCode: !cb.labelled });
  1822	    if (f.field === 'my_number' && (level === 'auto' || level === 'gate') && f.checkOk === false){ level = 'recommend'; note = 'checkdigit'; }
  1824	    if (f.unlabelledCode && (level === 'auto' || level === 'gate')){ level = 'recommend'; note = 'unlabelled_code'; }

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: site:laws.e-gov.go.jp 刑法 公文書偽造 行使の目的 第155条 ...
hook: PostToolUse
hook: PostToolUse Completed
codex
검토 범위는 커밋 `546344b`의 파일 내용을 `git show`로 직접 읽은 정적 검토입니다. `node run.mjs`도 시도했지만 `127.0.0.1` 서버 바인딩이 `EPERM`으로 차단되어 실행되지 않았습니다. 따라서 `389/389`는 구현자 로그일 뿐, 제가 재현한 결과가 아닙니다.

## 1. 탐지 미탐 위험

### 1-1. 문서 분류 실패 시 무경고로 JP 보호가 전부 사라짐

문제 / `資格確認書`는 제목만 정상 인식되면 3점이라 임계값 4에 못 미칩니다. `保険者番号` 등 추가 키워드 하나가 깨지면 실제 문서가 “一般文書”로 떨어지고 JP 번호 탐지가 전혀 실행되지 않습니다. 사용자는 분류 실패 사실이나 수동 확인 필요성을 알 수 없습니다.

근거 / `public/safe/index.html:1161-1199`, 특히 `資格確認書=3`, `min:4`; `public/safe/index.html:1774-1784`의 `if (!cls) return null`; `public/safe/index.html:2143-2151`은 실패 시 일반 이름·주소 휴리스틱으로 조용히 전환합니다. 실제 보험자별 실패율은 **확인 불가**입니다.

수정안 / 임계 미달이어도 JP 의심 점수·일본 문서 특징이 있으면 “문서 종류를 확인하지 못해 자동 마스킹을 적용하지 않았다”는 차단성 경고를 표시하십시오. `資格確認書` 제목 단독은 최소 candidate scan을 허용하고, 보험자별 실물 익명 샘플로 분류 recall 게이트를 별도로 두어야 합니다.

### 1-2. 고정 세그먼트 간격이 DPI·레이아웃 변화에 취약함

문제 / 레이블 끝과 값 시작의 공백이 `max(90px, 폭×10%)` 이상이면 둘이 분리되어 값 규칙이 미탐됩니다. 반대로 다음 칸과의 간격이 그보다 작으면 두 칸이 합쳐지고, 두 번째 레이블은 세그먼트 선두가 아니어서 미탐됩니다. OCR 렌더 배율과 사진 원근에 따라 같은 서식도 양쪽 실패가 가능합니다.

근거 / `public/safe/index.html:1115-1145`, `public/safe/index.html:1575-1581`, `public/safe/index.html:1601-1609`. 80px/140px 가정은 알파 픽스처 측정뿐입니다.

수정안 / 페이지 폭이 아니라 행 글자 높이와 인접 박스 분포에서 동적 임계값을 구하고, 레이블과 값이 분리된 인접 세그먼트도 동일 행·수직 중첩·최대 거리 조건으로 결합하십시오. 좁은 표에서는 열 경계/괘선을 함께 사용해야 합니다.

### 1-3. 모든 규칙의 `headOnly` 강제가 과도함

문제 / `●`, `※`, 항목번호, 괄호, OCR 잡음 한 글자, 표 셀의 선행 문자가 붙으면 모든 값 레이블이 거부됩니다. 한 각주 오탐을 막기 위해 전체 필드의 recall을 희생합니다.

근거 / `public/safe/index.html:1575-1581`, `public/safe/index.html:1594-1609`. 원래 개별 규칙의 `headOnly` 설정과 무관하게 `.map(... headOnly:true)`로 덮어씁니다.

수정안 / 선두에 허용할 잡음 클래스를 제한하십시오. 예: 공백·`※●○□・(1)①`·1문자 저신뢰 OCR만 건너뛰고, 레이블 이후 값 형식·동일 셀·거리 점수로 확정하십시오. 각주 방지는 “레이블 뒤 필드값 형식 존재”와 문장형 종결 패턴으로 처리해야 합니다.

### 1-4. 숫자 길이 폴백이 비민감 번호를 자동 마스킹함

문제 / `資格確認書`의 모든 독립 6~10자리 숫자가 `hokensha_bango`가 됩니다. 하이픈 없는 우편번호, 압축 날짜, 전화번호, 교부·발행·証明書番号 같은 숫자도 자동 마스킹될 수 있습니다. `一部負担金割合`과 일반적인 `限度額区分`은 보통 해당 길이가 아니지만, 발행·관리번호의 실제 존재와 자릿수는 현재 자료로 **확인 불가**입니다. 후期高齢者용 `資格確認書`에는 실제로 負担割合·交付年月日·適用区分 등이 존재합니다. [旭川市 안내](https://www.city.asahikawa.hokkaido.jp/kurashi/135/171/176/p004497.html)

`住民票`의 11자리 폴백은 하이픈 없는 휴대전화나 증명서 일련번호를 `住民票コード`로, 12자리는 임의 참조번호를 `個人番号` 후보로 오인할 수 있습니다.

근거 / `public/safe/index.html:1655-1691`. 제외 조건은 `[年月日]` 또는 `〒`가 있는 행뿐입니다.

수정안 / `資格確認書` 폴백은 번호가 위치한 셀의 인접 레이블 조각, 번호군 주변 좌표, 보험자 번호 형식/코드체계까지 요구하십시오. `住民票コード`에는 체크디지트와 레이블/열 헤더를 요구하고, `個人番号`는 체크디지트가 실패하면 폴백 자동 경로에서 제외하거나 명확한 수동 검토로 낮추십시오.

### 1-5. `myNumberCheckOk` 계산은 맞지만 법적 출처 표기가 틀림

문제 / 함수 계산 자체는 맞습니다. 다만 주석의 “番号法施行令 別表”는 정확한 근거 위치가 아닙니다. 현재 산식은 관련 명령 제5조의 산식입니다.

근거 / `public/safe/index.html:1202-1211`. 구현은 오른쪽부터 `Pₙ`, `Qₙ=n+1 (n≤6), n−5 (n≥7)`, `11-(합 mod 11)`, 결과 10·11이면 0으로 처리합니다. 정부 원문도 합의 11 나머지가 0 또는 1이면 검사 숫자를 0으로 하므로 동치입니다. [e-Gov 관련 명령 제5조](https://laws.e-gov.go.jp/document?lawid=426M60000008085_20231215_505M60004008017)

수정안 / 로직은 유지하고 주석·법적 매트릭스 출처를 정확한 명령 제5조로 고치십시오. 유효·무효 경계값을 독립 테스트 벡터로 추가해야 합니다.

### 1-6. 世帯員 경계가 실제 양식 변형을 견디지 못함

문제 / 반복되는 `氏名` 레이블이 하나라도 OCR에서 깨지면 해당 세대원 블록이 통째로 남습니다. 반대로 블록 내부의 발행자·증명문이 종료 표현과 일치하지 않으면 마지막 세대원 영역이 페이지 끝까지 확장되어 발행자까지 가릴 수 있습니다. 공통 열 헤더 하나 아래 여러 명을 행으로 나열하는 `世帯連記式`은 `nameRows.length > 1` 조건 자체를 충족하지 않을 수 있습니다.

근거 / `public/safe/index.html:1731-1766`. 실제 지자체는 `世帯連記式`과 `個人票様式`을 모두 사용합니다. [宇都宮市 양식 안내](https://www.city.utsunomiya.lg.jp/kurashi/jumin/koseki/1043547.html). 반복 블록 예시는 `氏名` 외에 `個人番号`, `住民票コード`, `備考`가 각 세대원 블록에 포함됩니다. [大阪市 공식 견본](https://www.city.osaka.lg.jp/toshiseibi/cmsfiles/contents/0000648/648120/syoruininntei.pdf)

수정안 / `氏名` 단일 앵커가 아니라 행 번호, `続柄`, 반복 열 구조, 구분선, 다음 사람 번호를 함께 사용하십시오. 마지막 경계는 발행일·증명문·발행기관 영역을 별도 보호구역으로 먼저 검출하고 그 위에서 강제로 종료해야 합니다.

## 2. 오탐 및 증빙 훼손

### 2-1. `jpFrameBelow`는 사각형이 아니라 평행 가로선 두 개만 검증함

문제 / 표의 상하 괘선이나 외곽선 두 개를 欄으로 오인할 수 있습니다. 세로 변, 내부 영역, 레이블과 프레임의 x관계를 검사하지 않습니다. `jpRowInk`가 행별 가장 긴 런 하나만 반환하므로 실제 작은 欄보다 페이지 전체 표선이 우선됩니다.

근거 / `public/safe/index.html:1234-1267`. 폴백도 실패 시 페이지 폭의 최소 50%, 레이블 높이 3.5배를 덮습니다(`1714-1722`).

수정안 / 좌우 세로선 존재, 모서리 연결, 프레임 내부 포함관계, 레이블 x근접성을 검증하십시오. 한 행의 모든 런을 보존한 뒤 앵커와 가까운 런을 선택해야 합니다.

### 2-2. 레이블 없는 사각형 candidate가 실제로 기본 ON임

문제 / 얼굴사진·검은 인감·정사각 로고·검은 표 헤더는 크기·종횡비·밀도 조건을 만족할 수 있습니다. 특히 채워진 원형 인감은 이론상 경계상자 채움률이 약 0.785라 `fill≥0.75`를 넘을 수 있습니다. 코드 주석은 “candidate, never automatic band”라고 하지만, `recommend` candidate의 기본 mode는 `no`여서 실제 출력에서는 기본으로 가려집니다.

근거 / `public/safe/index.html:1334-1366`, `public/safe/index.html:1796-1801`, `public/safe/index.html:1823-1825`. `labelled:false` → `recommend` → `mode:'no'`.

수정안 / 미검증 `unlabelledCode`는 `optional`, `mode:'ok'`로 두십시오. finder 패턴·quiet zone·모듈 주기 등 QR 고유 특징을 확인하기 전에는 기본 출력에 포함하면 안 됩니다.

### 2-3. 주소 “강한 자동 조건”이 구현되지 않음

문제 / `郵便番号+都道府県`를 `strong:true`로 계산하지만 그 값은 어디에서도 사용하지 않습니다. 따라서 전략의 “동반 시 자동”은 구현되지 않았습니다. `consult_share`에서는 모든 `address_loose`가 강도와 무관하게 권장 ON이고, 다른 목적에서는 모두 optional입니다.

근거 / `public/safe/index.html:1538-1563`, `public/safe/index.html:1694-1710`; `strong` 검색 결과 사용처 없음; `JP_EXTRA`는 `public/safe/index.html:1383-1387`.

수정안 / `strong`을 실제 level 결정에 반영하거나 전략에서 자동 약속을 삭제하십시오. 기관명 감점은 주소 뒤 8자까지만 보므로 더 멀리 붙은 회사명은 감점되지 않습니다. 회사 소재지와 개인 주소 구별에는 `住所変更`, `現住所`, `送付先` 같은 개인 문맥이 추가로 필요합니다.

### 2-4. 15% 패딩은 가까운 이웃 필드를 덮을 수 있음

문제 / 높이 `h`인 두 필드의 간격이 약 `0.3h`보다 작으면 상하 패딩이 겹칩니다. 좌우도 각 필드 경계에서 `0.15h`만큼 침범합니다. 더 큰 문제는 `mergeLineBoxes`가 하나라도 `region:true`이면 합쳐진 전체 라인의 패딩을 제거하여 다른 OCR 박스의 가장자리가 노출될 수 있다는 점입니다.

근거 / `public/safe/index.html:2256-2274`, `public/safe/index.html:2276-2291`.

수정안 / 패딩을 인접 OCR 박스·셀 경계까지 clamp하고, region과 텍스트 박스를 같은 merged line으로 합치지 마십시오. `region:true`의 패딩 제외는 수동 드래그에는 맞지만 자동 검출 프레임까지 같은 신뢰도로 취급하는 것은 부적절합니다.

## 3. 출력 안전성

### 3-1. PDF 바이트 marker 목록은 완전한 검사가 아님

문제 / `/Metadata`, 문서 `/Info`, `/EF`, `/Filespec`, `/OpenAction`, `/AA`, `/JS`, `/Launch`, `/RichMedia`가 빠졌습니다. 문자열 검색은 Flate 압축 스트림과 object stream 내부 이름·문자열도 보지 못합니다. PDF는 간접 객체를 object stream 안에 압축 저장할 수 있습니다. [Adobe PDF 32000-1 §7.5.7](https://developer.adobe.com/document-services/docs/assets/35e4369068f86065372c18787171a17e/PDF_ISO_32000-1.pdf)

근거 / `test/safe/run.mjs:241-257`, `289-305`.

수정안 / qpdf 또는 PDF 파서로 객체 그래프를 풀어 Catalog, Info, Metadata, Names, annotations, actions, file specifications, embedded streams를 검사하십시오. `%%EOF` 개수는 증분 저장 신호일 뿐 완전한 구조 검사가 아닙니다.

### 3-2. 입력 PDF 구조물이 직접 출력되는 경로는 없음

문제 / 입력 주석·첨부·북마크·XMP가 jsPDF 새 문서에 복사되는 경로는 찾지 못했습니다. 이 항목에서 원본 구조 누출 주장은 성립하지 않습니다. 다만 픽셀 자체에 숨겨진 데이터나 육안상 남은 원본은 래스터 재인코딩만으로 제거되지 않습니다.

근거 / `public/safe/index.html:2568-2593`: 원본 페이지를 canvas에 그리고 JPEG data URL만 새 jsPDF에 삽입합니다. jsPDF `addImage`도 Canvas/data URL 입력을 받는 API입니다. [jsPDF addImage 문서](https://parallax.github.io/jsPDF/docs/module-addImage.html)

수정안 / “원본 PDF 객체를 계승하지 않는다”는 논증은 유지하되, 테스트 문구를 “모든 가능한 PDF 누출을 검사한다”가 아니라 “새 래스터 PDF 생성 경로와 출력 객체 allowlist를 검증한다”로 제한하십시오.

### 3-3. ICC 2KB·`dmnd/dmdd` 기준은 신원정보 부재를 증명하지 못함

문제 / 2KB 이하 임의 프로파일도 `desc`, `mluc`, `cprt` 또는 private payload에 장치·사용자 정보를 넣을 수 있고, 디스플레이 프로파일이 반드시 `dmnd/dmdd`를 갖는 것도 아닙니다. 현재 검사는 첫 `ICC_PROFILE`만 보고 분할 APP2 프로파일 전체도 구조적으로 검증하지 않습니다.

근거 / `test/safe/run.mjs:258-270`.

수정안 / 허용할 ICC 프로파일의 전체 바이트 SHA-256 allowlist를 사용하거나 출력 후 ICC를 제거하십시오. “크기+두 태그 부재”를 안전성 경계로 사용하면 안 됩니다.

### 3-4. PNG는 네 청크만 금지하여 임의 보조 청크를 놓침

문제 / `iCCP`, `tIME`, `sPLT` 및 private ancillary chunk에도 데이터가 실릴 수 있습니다. PNG 규격은 private·unknown ancillary chunk를 명시적으로 허용합니다. [W3C PNG 규격](https://www.w3.org/TR/png/)

근거 / `test/safe/run.mjs:241-245`.

수정안 / PNG 청크를 구조적으로 파싱하여 `IHDR`, 필요한 색공간 청크, `IDAT`, `IEND`의 allowlist만 허용하십시오. 적어도 모든 ancillary/private chunk의 목록과 payload 크기를 검증해야 합니다.

## 4. 목적 게이트와 법적 매트릭스

### 4-1. `JP_RULES`는 정본과 일치하지 않음

문제 / 주요 불일치는 다음과 같습니다.

- `JP_EXTRA(address_loose/tel)`는 법적 정본에 전혀 없습니다.
- `資格確認書`의 keep 항목을 모든 목적에 적용하며 `事業所名称`, `保険者名`, `資格取得年月日`까지 추가합니다.
- `運転免許証番号`은 정본상 `identity_submit`에서 must-keep인데 구현은 모든 목적 optional입니다.
- `マイナンバーカード`의 `my_number`, `qr` 개별 gate는 정본의 `裏面全体` 규칙을 코드에서 분해해 추가한 것입니다.
- `住民票`의 keep은 정본상 `identity_submit`, `bid_attachment`인데 구현은 모든 목적입니다.
- 정본의 `発行日・発行者`는 검출 규칙이 없어 keep 경고가 실제로 생성되지 않습니다.
- `住民票コード`는 정본에서 `verified:false`인데 자동 마스킹됩니다.

근거 / `test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:16-57`; `public/safe/index.html:1381-1431`, `1450-1503`.

수정안 / 사람이 작성한 두 번째 표가 아니라 legal matrix JSON을 빌드 시 변환해 단일 소스로 사용하십시오. `verified:false`는 자동 level을 금지하는 검증 규칙을 추가해야 합니다.

### 4-2. 미명시 목적을 항상 `optional`로 만드는 폴백은 잘못됨

문제 / `return r.keep ? 'optional' : 'optional'`은 조건문이 무의미하며, 매트릭스가 의도적으로 명시하지 않은 조합과 “선택 제공”을 구별하지 못합니다. 특히 `資格確認書` 번호군은 `my_number_procedure`에서 optional로 노출되지만, 해당 목적이 의료보험 관련 개인번호 사무인지에 따라 번호가 필요한 예외가 존재할 수 있습니다. 구체적 업무 조합은 **확인 불가**입니다. 厚労省도 건강보험 사무 또는 관련 사무에는 고지 제한 예외가 있음을 명시합니다. [厚労省](https://www.mhlw.go.jp/stf/newpage_13989.html)

근거 / `public/safe/index.html:1433-1441`.

수정안 / 미명시는 `null`로 두고 UI에 내지 마십시오. 명시적으로 `optional`인 경우만 optional을 반환하도록 매트릭스에 목적별 상태를 완전 열거해야 합니다.

### 4-3. `本籍`/`筆頭者` 확장은 법적 근거가 없음

문제 / 근거가 “필요 없어 보인다”와 픽스처 기대값뿐이라 순환 논증입니다. `my_number_procedure`·`bid_attachment`의 모든 하위 업무에서 불필요하다는 출처가 없습니다.

근거 / `public/safe/index.html:1377-1380`, `1426-1427`; `docs/jp/s3_report.md:239-242`.

수정안 / 법적 정본을 바꾸기 전에는 해당 두 목적을 optional로 두십시오. 실제 제출처 요구사항 또는 공식 지침을 목적별로 확보한 뒤 recommend로 승격해야 합니다.

### 4-4. マイナカード裏面 안내는 지나치게 단정적임

문제 / 身元確認 목적으로 뒷면을 복사·보관하면 제한 위반 가능성이 있으므로 앞면 제출 안내는 타당합니다. 다만 단순히 보았다는 것까지 불법인 것은 아니므로 “番号法により…できません”은 행위·주체·예외를 생략합니다. `個人番号手続` 선택만으로 모든 수령처가 적법한 개인번호 이용사무 수행자임을 확인할 수도 없습니다.

근거 / `public/safe/index.html:1804-1812`; PPC는 의도치 않게 본 것과 복사·기록을 구별합니다. [PPC FAQ Q6-12](https://www.ppc.go.jp/all_faq_index/faq5-q6-12/)

수정안 / “법정 개인번호 사무를 수행하는 제출처에 한해 해제” 확인을 추가하고, 단순 목적 드롭다운만으로 전면 해제하지 마십시오.

### 4-5. keep을 가릴 수 있게 둔 것은 법 위반이 아니라 제출 유효성 문제

문제 / 모든 keep 필드를 법적으로 차단해야 한다는 근거는 없습니다. 그러나 `my_number_procedure`의 個人番号처럼 목적 자체가 성립하지 않는 필드까지 일괄 비공개할 수 있어, 사용자가 “해당 목적용 안전 파일”이라고 오해할 수 있습니다.

근거 / `public/safe/index.html:2494-2506`. 법적 차단 필요성은 **확인 불가**입니다.

수정안 / 일반 keep은 경고 유지, 목적의 핵심 필드는 “강제 유지” 또는 최종 확인 대화상자로 분리하십시오. 최소한 목적 적합성 상태를 실패로 표시해야 합니다.

### 4-6. `その他` 토글이 법적 띠를 무조건 해제함

문제 / `back_all`과 `qr`가 `other`에 매핑되고 `isOn`은 카테고리 boolean만 봅니다. 사용자가 その他를 끄면 マイナカード裏面 전체와 資格確認書 QR 띠가 출력에서 사라집니다. 별도 강한 경고도 없습니다.

근거 / `public/safe/index.html:1831-1834`, `751-777`, `2320-2329`, `2480-2482`.

수정안 / 법적 preset 엔티티는 일반 카테고리 토글에서 분리하십시오. 해제는 개별 항목과 목적별 확인을 거치게 하고, 하네스도 카테고리 OFF 상태에서 법적 띠가 유지되는지 검증해야 합니다.

## 5. 하네스 유효성

### 5-1. `jp_auto_fields`는 목적·검증 상태를 표현하지 못함

문제 / 문서별 정적 배열이라 목적별 `auto/gate/keep` 차이를 나타내지 못합니다. `住民票コード`의 `verified:false`도 무시됩니다. 앱과 하네스가 같은 잘못된 해석을 공유할 수 있습니다.

근거 / `test/safe/specs.json:83-90`; `test/safe/run.mjs:430-496`.

수정안 / legal matrix JSON에서 `(doc, field, purpose)`별 기대 level을 직접 계산하고, 정적 중복표를 제거하십시오.

### 5-2. 유효 個人番号 자동 띠가 전혀 검증되지 않음

문제 / `JP_MASK_OR_CAND`는 잘못된 체크디지트 더미가 candidate만 되어도 통과합니다. 유효 체크디지트가 `auto/gate`가 되는 테스트는 없습니다.

근거 / `test/safe/specs.json:90-91`; `test/safe/run.mjs:423-425`, `495-496`; 생성기는 모두 무효 번호만 만듭니다(`gen.py:35-45`).

수정안 / 실물과 무관한 텍스트/캔버스 유닛 픽스처로 유효 체크디지트 번호를 생성하여 `checkOk:true`, 자동 띠, 목적 전환 해제를 각각 검증하십시오. 공개 카드 이미지에 유효 번호를 넣을 필요는 없습니다.

### 5-3. 60% 피복은 판독 불가를 보장하지 않음

문제 / 한 OCR word의 60%만 덮고 나머지 40%에 여러 숫자가 그대로 남아도 통과합니다. 구현자 스스로 96% 피복인데 첫 숫자가 노출된 사례를 기록했으므로 현재 기준의 부적합성이 이미 입증되었습니다.

근거 / `test/safe/run.mjs:404-424`; `docs/jp/s3_report.md:207-212`.

수정안 / 숫자 필드는 각 문자 또는 잉크 연결요소가 100%+허용 오차로 덮이는지 검사하십시오. 출력 이미지에 대해 OCR 재검사와 픽셀 차분을 병행해야 합니다.

### 5-4. `geometry:false`가 가장 어려운 입력의 오배치를 숨김

문제 / JPG 세 건과 목적 교차 한 건은 field와 mode만 검사합니다. 완전히 엉뚱한 위치의 띠, 빈 박스, 카테고리 OFF 상태도 통과할 수 있습니다.

근거 / `test/safe/specs.json:113-116`, `145-153`; `test/safe/run.mjs:448-465`. `require_banded`는 `mode !== 'ok'`만 봅니다.

수정안 / 회전·원근 변환 행렬을 픽스처에 기록하거나 출력 이미지의 알려진 민감 문자열/영역을 OCR·픽셀 기준으로 검사하십시오.

### 5-5. 공허한 단언 경로가 남아 있음

문제 / 다음 경로가 공허하거나 약합니다.

- absent box는 `skipped`로 기록만 하고, 다른 박스 하나만 검사하면 `JP_COVERAGE > 0` 통과.
- `P.keep === 'all'`이면 keep 검사를 아예 빈 배열로 만듦.
- `require_banded`는 좌표·located·`isOn`을 확인하지 않음.
- `JP_CLEAR`도 위치와 실제 출력 피복을 확인하지 않음.
- `__candidateOver`는 주석과 달리 candidate의 활성 상태나 mode를 확인하지 않음.

근거 / `test/safe/run.mjs:111-119`, `453-465`, `473-500`.

수정안 / 기대 키 누락을 즉시 실패시키고 `checked === expectedExistingCount`를 요구하십시오. field 단언은 실제 `__maskRects`와 교차하도록 바꾸고 `keep:'all'`은 모든 box를 열거해 검사해야 합니다.

### 5-6. `max_auto`는 오탐 종류를 제한하지 못함

문제 / kenpo 실측 5에 상한 8, kouki 실측 3에 상한 8이면 각각 3개·5개의 신규 오탐이 생겨도 통과합니다. 올바른 엔티티가 빠지고 잘못된 엔티티가 대신 생겨 총수만 같아도 통과합니다.

근거 / `test/safe/specs.json:94-104`; 실측값은 `docs/jp/s3_report.md:201-202`.

수정안 / 총수 상한을 보조 지표로만 두고 필드·좌표별 allowlist와 “예상하지 않은 자동 엔티티 0” 단언을 추가하십시오.

## 6. 커버리지 없는 구현

### 6-1. 레이블 없는 QR 완화가 충분하지 않음

문제 / candidate로 낮췄지만 기본 ON이므로 완화가 실패했습니다.

근거 / `public/safe/index.html:1823-1825`, `1796-1801`.

수정안 / 실제 QR fixture가 생기기 전까지 optional·기본 OFF로 고정하십시오.

### 6-2. 電話·FAX 테스트가 통합 경로를 검증하지 않음

문제 / 유닛은 정규식만 직접 호출하며 `jpFindLabel → jpBoxes → jpApply`를 지나지 않습니다.

근거 / `test/safe/run.mjs:524-532`.

수정안 / 합성 canvas/PDF에 레이블과 번호를 분리 배치해 세그먼트·좌표·mode까지 검증하십시오.

### 6-3. 주소 자동 분기는 “미검증”이 아니라 사실상 미구현

문제 / `strong`이 사용되지 않아 실제 문서뿐 아니라 코드상으로도 자동 승격이 없습니다.

근거 / `public/safe/index.html:1709`; 사용처 없음.

수정안 / 전략과 구현 중 하나를 일치시키고 그 경로를 통합 테스트하십시오.

### 6-4. 다중 페이지는 단순 상속보다 더 위험함

문제 / 페이지별로 다른 `c`로 추출하면서 `jpApply`는 1페이지 `cls.doc/side` 규칙만 적용합니다. マイナカード 앞·뒤 양면 PDF에서 첫 페이지가 back이면 모든 페이지에 `back_all`을 씌우고, 첫 페이지가 front이면 뒤 페이지 전체 띠가 생성되지 않습니다.

근거 / `public/safe/index.html:1774-1784`, `1792-1812`.

수정안 / finding마다 `doc/side`를 저장하고 페이지별로 level·whole-face rule을 적용하십시오. 앞→뒤, 뒤→앞, 동일 문서 2페이지, 혼합 문서 PDF를 모두 테스트해야 합니다.

### 6-5. 테두리 중앙값 배경은 컬러 양식에 취약함

문제 / 가장자리 24점이 테두리·그라데이션·사진 배경이면 잘못된 단일 RGB가 배경이 됩니다. 이후 거의 모든 셀이 ink가 되거나 실제 검은 구조가 배경으로 간주되어 `jpFrameBelow`와 `jpSolidSquares`가 붕괴합니다.

근거 / `public/safe/index.html:1220-1244`, `1334-1347`.

수정안 / 페이지 다영역 색상 클러스터, 로컬 배경, 명도/색차 기반 적응 임계값을 사용하십시오. 어두운 전면·컬러·테두리 있는 합성 fixture가 필요합니다.

## 7. 공개 저장소와 카드 더미

### 7-1. §4 안전조건을 전부 충족하지 않음

문제 / 명백한 위반은 “개별 고해상 카드 파일 공개 배포 금지”와 “법률 검토 전 내부 전용”입니다. 또한 모든 번호가 불일치/규격 외라는 주장도 코드와 맞지 않습니다. `mynumber_invalid()`와 면허번호만 의도적으로 무효화하며, `hokensha()`·記号/番号/枝番·고정 `住民票コード`에는 유효성 부정 로직이 없습니다. 우편번호 `999-99xx`가 실제 미할당임도 검증하지 않습니다.

근거 / `docs/jp/jp_safefile_strategy_v2_2026-10-21.md:95-104`; `test/safe/fixtures/jp/gen.py:29-47`, `69-80`, `91-108`, `199-203`. 실제 번호·주소와 충돌하지 않는다는 증거는 **확인 불가**입니다.

수정안 / 모든 번호군에 문자를 삽입하거나 명시적 무효 검사를 두고, 주소·우편번호도 예약된 비실재 네임스페이스를 사용하십시오. 공개 고해상도 바이너리는 법률 검토 전 제거해야 합니다.

### 7-2. 실질 위험은 낮지만 “0”은 아님

문제 / 워터마크·도식형·인감/실QR 부재 때문에 직접 오용 가치는 낮습니다. 그러나 공개 Git 기록은 영구 복제 가능하고, 일부 번호가 실제 형식이며 고해상도 카드형 이미지라는 점 때문에 편집 재료 가치는 남습니다. 일본 형법상 공문서 위조는 `行使の目的`이 핵심이므로 이 테스트 fixture 자체가 곧 위법이라고 단정할 근거는 없습니다. [刑法 제155조](https://laws.e-gov.go.jp/document?lawid=140AC0000000045_20250601_505AC0000000028)

GitHub 정책도 이 fixture를 명시적으로 금지한다고 확인할 수 없습니다. 다만 불법·사기·기만·사칭 목적 사용은 금지됩니다. [GitHub Acceptable Use](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies?apiVersion=2022-11-28)

근거 / `CLAUDE.md:1646-1665`; 구체적 일본 변호사 검토 결과는 **확인 불가**입니다.

수정안 / “오용 가치 사실상 0” 표현을 삭제하고, 법률·플랫폼 위험을 낮음이지만 미해결로 표기하십시오.

### 7-3. 대안 비교

문제 / 비공개 submodule은 접근권한·CI secret·외부 기여자 재현성이 나빠집니다. 생성 스크립트만 커밋하면 폰트/Pillow 차이로 픽셀 골든이 흔들립니다. 해상도 축소는 OCR·기하 테스트의 의미를 훼손합니다.

근거 / `CLAUDE.md:1656-1664`.

수정안 / 가장 현실적인 순서는 다음입니다.

- 공개 저장소에는 구조 테스트용 저위험 SVG/캔버스 생성 스크립트와 의미 기반 assertions만 유지.
- 픽셀 골든은 고정 컨테이너 이미지로 결정적으로 생성하고 해시 검증.
- 꼭 필요한 고해상도 카드 fixture만 비공개 artifact 저장소에서 CI에 주입.
- 단순 축소본은 문서·마케팅 검토용으로만 사용하고 OCR 골든 대체물로 쓰지 않음.

## 즉시 고쳐야 할 상위 5개

1. **AMBER · 배포 전** — 분류 실패가 무경고로 JP 탐지를 전부 끄는 문제. 실패 경고와 저신뢰 fallback이 필요합니다.
2. **AMBER · 배포 전** — 레이블 없는 사각형이 candidate임에도 기본 ON인 문제. 얼굴사진·인감 오탐을 기본 출력에 넣습니다.
3. **AMBER · 배포 전** — 다중 페이지에서 첫 페이지 `doc/side`를 전 페이지에 적용하는 문제. マイナカード 양면 처리 결과가 순서에 따라 반대가 됩니다.
4. **AMBER · 배포 전** — `その他` 카테고리 OFF로 `back_all`·QR 법적 띠가 조용히 사라지는 문제.
5. **AMBER · 다음 런 전** — 하네스의 60% 피복, skipped-key 허용, `require_banded` 좌표 미검증. 현재 389/389는 숫자 노출과 오배치를 배제하지 못합니다.
hook: Stop
hook: Stop Completed
tokens used
155,930
검토 범위는 커밋 `546344b`의 파일 내용을 `git show`로 직접 읽은 정적 검토입니다. `node run.mjs`도 시도했지만 `127.0.0.1` 서버 바인딩이 `EPERM`으로 차단되어 실행되지 않았습니다. 따라서 `389/389`는 구현자 로그일 뿐, 제가 재현한 결과가 아닙니다.

## 1. 탐지 미탐 위험

### 1-1. 문서 분류 실패 시 무경고로 JP 보호가 전부 사라짐

문제 / `資格確認書`는 제목만 정상 인식되면 3점이라 임계값 4에 못 미칩니다. `保険者番号` 등 추가 키워드 하나가 깨지면 실제 문서가 “一般文書”로 떨어지고 JP 번호 탐지가 전혀 실행되지 않습니다. 사용자는 분류 실패 사실이나 수동 확인 필요성을 알 수 없습니다.

근거 / `public/safe/index.html:1161-1199`, 특히 `資格確認書=3`, `min:4`; `public/safe/index.html:1774-1784`의 `if (!cls) return null`; `public/safe/index.html:2143-2151`은 실패 시 일반 이름·주소 휴리스틱으로 조용히 전환합니다. 실제 보험자별 실패율은 **확인 불가**입니다.

수정안 / 임계 미달이어도 JP 의심 점수·일본 문서 특징이 있으면 “문서 종류를 확인하지 못해 자동 마스킹을 적용하지 않았다”는 차단성 경고를 표시하십시오. `資格確認書` 제목 단독은 최소 candidate scan을 허용하고, 보험자별 실물 익명 샘플로 분류 recall 게이트를 별도로 두어야 합니다.

### 1-2. 고정 세그먼트 간격이 DPI·레이아웃 변화에 취약함

문제 / 레이블 끝과 값 시작의 공백이 `max(90px, 폭×10%)` 이상이면 둘이 분리되어 값 규칙이 미탐됩니다. 반대로 다음 칸과의 간격이 그보다 작으면 두 칸이 합쳐지고, 두 번째 레이블은 세그먼트 선두가 아니어서 미탐됩니다. OCR 렌더 배율과 사진 원근에 따라 같은 서식도 양쪽 실패가 가능합니다.

근거 / `public/safe/index.html:1115-1145`, `public/safe/index.html:1575-1581`, `public/safe/index.html:1601-1609`. 80px/140px 가정은 알파 픽스처 측정뿐입니다.

수정안 / 페이지 폭이 아니라 행 글자 높이와 인접 박스 분포에서 동적 임계값을 구하고, 레이블과 값이 분리된 인접 세그먼트도 동일 행·수직 중첩·최대 거리 조건으로 결합하십시오. 좁은 표에서는 열 경계/괘선을 함께 사용해야 합니다.

### 1-3. 모든 규칙의 `headOnly` 강제가 과도함

문제 / `●`, `※`, 항목번호, 괄호, OCR 잡음 한 글자, 표 셀의 선행 문자가 붙으면 모든 값 레이블이 거부됩니다. 한 각주 오탐을 막기 위해 전체 필드의 recall을 희생합니다.

근거 / `public/safe/index.html:1575-1581`, `public/safe/index.html:1594-1609`. 원래 개별 규칙의 `headOnly` 설정과 무관하게 `.map(... headOnly:true)`로 덮어씁니다.

수정안 / 선두에 허용할 잡음 클래스를 제한하십시오. 예: 공백·`※●○□・(1)①`·1문자 저신뢰 OCR만 건너뛰고, 레이블 이후 값 형식·동일 셀·거리 점수로 확정하십시오. 각주 방지는 “레이블 뒤 필드값 형식 존재”와 문장형 종결 패턴으로 처리해야 합니다.

### 1-4. 숫자 길이 폴백이 비민감 번호를 자동 마스킹함

문제 / `資格確認書`의 모든 독립 6~10자리 숫자가 `hokensha_bango`가 됩니다. 하이픈 없는 우편번호, 압축 날짜, 전화번호, 교부·발행·証明書番号 같은 숫자도 자동 마스킹될 수 있습니다. `一部負担金割合`과 일반적인 `限度額区分`은 보통 해당 길이가 아니지만, 발행·관리번호의 실제 존재와 자릿수는 현재 자료로 **확인 불가**입니다. 후期高齢者용 `資格確認書`에는 실제로 負担割合·交付年月日·適用区分 등이 존재합니다. [旭川市 안내](https://www.city.asahikawa.hokkaido.jp/kurashi/135/171/176/p004497.html)

`住民票`의 11자리 폴백은 하이픈 없는 휴대전화나 증명서 일련번호를 `住民票コード`로, 12자리는 임의 참조번호를 `個人番号` 후보로 오인할 수 있습니다.

근거 / `public/safe/index.html:1655-1691`. 제외 조건은 `[年月日]` 또는 `〒`가 있는 행뿐입니다.

수정안 / `資格確認書` 폴백은 번호가 위치한 셀의 인접 레이블 조각, 번호군 주변 좌표, 보험자 번호 형식/코드체계까지 요구하십시오. `住民票コード`에는 체크디지트와 레이블/열 헤더를 요구하고, `個人番号`는 체크디지트가 실패하면 폴백 자동 경로에서 제외하거나 명확한 수동 검토로 낮추십시오.

### 1-5. `myNumberCheckOk` 계산은 맞지만 법적 출처 표기가 틀림

문제 / 함수 계산 자체는 맞습니다. 다만 주석의 “番号法施行令 別表”는 정확한 근거 위치가 아닙니다. 현재 산식은 관련 명령 제5조의 산식입니다.

근거 / `public/safe/index.html:1202-1211`. 구현은 오른쪽부터 `Pₙ`, `Qₙ=n+1 (n≤6), n−5 (n≥7)`, `11-(합 mod 11)`, 결과 10·11이면 0으로 처리합니다. 정부 원문도 합의 11 나머지가 0 또는 1이면 검사 숫자를 0으로 하므로 동치입니다. [e-Gov 관련 명령 제5조](https://laws.e-gov.go.jp/document?lawid=426M60000008085_20231215_505M60004008017)

수정안 / 로직은 유지하고 주석·법적 매트릭스 출처를 정확한 명령 제5조로 고치십시오. 유효·무효 경계값을 독립 테스트 벡터로 추가해야 합니다.

### 1-6. 世帯員 경계가 실제 양식 변형을 견디지 못함

문제 / 반복되는 `氏名` 레이블이 하나라도 OCR에서 깨지면 해당 세대원 블록이 통째로 남습니다. 반대로 블록 내부의 발행자·증명문이 종료 표현과 일치하지 않으면 마지막 세대원 영역이 페이지 끝까지 확장되어 발행자까지 가릴 수 있습니다. 공통 열 헤더 하나 아래 여러 명을 행으로 나열하는 `世帯連記式`은 `nameRows.length > 1` 조건 자체를 충족하지 않을 수 있습니다.

근거 / `public/safe/index.html:1731-1766`. 실제 지자체는 `世帯連記式`과 `個人票様式`을 모두 사용합니다. [宇都宮市 양식 안내](https://www.city.utsunomiya.lg.jp/kurashi/jumin/koseki/1043547.html). 반복 블록 예시는 `氏名` 외에 `個人番号`, `住民票コード`, `備考`가 각 세대원 블록에 포함됩니다. [大阪市 공식 견본](https://www.city.osaka.lg.jp/toshiseibi/cmsfiles/contents/0000648/648120/syoruininntei.pdf)

수정안 / `氏名` 단일 앵커가 아니라 행 번호, `続柄`, 반복 열 구조, 구분선, 다음 사람 번호를 함께 사용하십시오. 마지막 경계는 발행일·증명문·발행기관 영역을 별도 보호구역으로 먼저 검출하고 그 위에서 강제로 종료해야 합니다.

## 2. 오탐 및 증빙 훼손

### 2-1. `jpFrameBelow`는 사각형이 아니라 평행 가로선 두 개만 검증함

문제 / 표의 상하 괘선이나 외곽선 두 개를 欄으로 오인할 수 있습니다. 세로 변, 내부 영역, 레이블과 프레임의 x관계를 검사하지 않습니다. `jpRowInk`가 행별 가장 긴 런 하나만 반환하므로 실제 작은 欄보다 페이지 전체 표선이 우선됩니다.

근거 / `public/safe/index.html:1234-1267`. 폴백도 실패 시 페이지 폭의 최소 50%, 레이블 높이 3.5배를 덮습니다(`1714-1722`).

수정안 / 좌우 세로선 존재, 모서리 연결, 프레임 내부 포함관계, 레이블 x근접성을 검증하십시오. 한 행의 모든 런을 보존한 뒤 앵커와 가까운 런을 선택해야 합니다.

### 2-2. 레이블 없는 사각형 candidate가 실제로 기본 ON임

문제 / 얼굴사진·검은 인감·정사각 로고·검은 표 헤더는 크기·종횡비·밀도 조건을 만족할 수 있습니다. 특히 채워진 원형 인감은 이론상 경계상자 채움률이 약 0.785라 `fill≥0.75`를 넘을 수 있습니다. 코드 주석은 “candidate, never automatic band”라고 하지만, `recommend` candidate의 기본 mode는 `no`여서 실제 출력에서는 기본으로 가려집니다.

근거 / `public/safe/index.html:1334-1366`, `public/safe/index.html:1796-1801`, `public/safe/index.html:1823-1825`. `labelled:false` → `recommend` → `mode:'no'`.

수정안 / 미검증 `unlabelledCode`는 `optional`, `mode:'ok'`로 두십시오. finder 패턴·quiet zone·모듈 주기 등 QR 고유 특징을 확인하기 전에는 기본 출력에 포함하면 안 됩니다.

### 2-3. 주소 “강한 자동 조건”이 구현되지 않음

문제 / `郵便番号+都道府県`를 `strong:true`로 계산하지만 그 값은 어디에서도 사용하지 않습니다. 따라서 전략의 “동반 시 자동”은 구현되지 않았습니다. `consult_share`에서는 모든 `address_loose`가 강도와 무관하게 권장 ON이고, 다른 목적에서는 모두 optional입니다.

근거 / `public/safe/index.html:1538-1563`, `public/safe/index.html:1694-1710`; `strong` 검색 결과 사용처 없음; `JP_EXTRA`는 `public/safe/index.html:1383-1387`.

수정안 / `strong`을 실제 level 결정에 반영하거나 전략에서 자동 약속을 삭제하십시오. 기관명 감점은 주소 뒤 8자까지만 보므로 더 멀리 붙은 회사명은 감점되지 않습니다. 회사 소재지와 개인 주소 구별에는 `住所変更`, `現住所`, `送付先` 같은 개인 문맥이 추가로 필요합니다.

### 2-4. 15% 패딩은 가까운 이웃 필드를 덮을 수 있음

문제 / 높이 `h`인 두 필드의 간격이 약 `0.3h`보다 작으면 상하 패딩이 겹칩니다. 좌우도 각 필드 경계에서 `0.15h`만큼 침범합니다. 더 큰 문제는 `mergeLineBoxes`가 하나라도 `region:true`이면 합쳐진 전체 라인의 패딩을 제거하여 다른 OCR 박스의 가장자리가 노출될 수 있다는 점입니다.

근거 / `public/safe/index.html:2256-2274`, `public/safe/index.html:2276-2291`.

수정안 / 패딩을 인접 OCR 박스·셀 경계까지 clamp하고, region과 텍스트 박스를 같은 merged line으로 합치지 마십시오. `region:true`의 패딩 제외는 수동 드래그에는 맞지만 자동 검출 프레임까지 같은 신뢰도로 취급하는 것은 부적절합니다.

## 3. 출력 안전성

### 3-1. PDF 바이트 marker 목록은 완전한 검사가 아님

문제 / `/Metadata`, 문서 `/Info`, `/EF`, `/Filespec`, `/OpenAction`, `/AA`, `/JS`, `/Launch`, `/RichMedia`가 빠졌습니다. 문자열 검색은 Flate 압축 스트림과 object stream 내부 이름·문자열도 보지 못합니다. PDF는 간접 객체를 object stream 안에 압축 저장할 수 있습니다. [Adobe PDF 32000-1 §7.5.7](https://developer.adobe.com/document-services/docs/assets/35e4369068f86065372c18787171a17e/PDF_ISO_32000-1.pdf)

근거 / `test/safe/run.mjs:241-257`, `289-305`.

수정안 / qpdf 또는 PDF 파서로 객체 그래프를 풀어 Catalog, Info, Metadata, Names, annotations, actions, file specifications, embedded streams를 검사하십시오. `%%EOF` 개수는 증분 저장 신호일 뿐 완전한 구조 검사가 아닙니다.

### 3-2. 입력 PDF 구조물이 직접 출력되는 경로는 없음

문제 / 입력 주석·첨부·북마크·XMP가 jsPDF 새 문서에 복사되는 경로는 찾지 못했습니다. 이 항목에서 원본 구조 누출 주장은 성립하지 않습니다. 다만 픽셀 자체에 숨겨진 데이터나 육안상 남은 원본은 래스터 재인코딩만으로 제거되지 않습니다.

근거 / `public/safe/index.html:2568-2593`: 원본 페이지를 canvas에 그리고 JPEG data URL만 새 jsPDF에 삽입합니다. jsPDF `addImage`도 Canvas/data URL 입력을 받는 API입니다. [jsPDF addImage 문서](https://parallax.github.io/jsPDF/docs/module-addImage.html)

수정안 / “원본 PDF 객체를 계승하지 않는다”는 논증은 유지하되, 테스트 문구를 “모든 가능한 PDF 누출을 검사한다”가 아니라 “새 래스터 PDF 생성 경로와 출력 객체 allowlist를 검증한다”로 제한하십시오.

### 3-3. ICC 2KB·`dmnd/dmdd` 기준은 신원정보 부재를 증명하지 못함

문제 / 2KB 이하 임의 프로파일도 `desc`, `mluc`, `cprt` 또는 private payload에 장치·사용자 정보를 넣을 수 있고, 디스플레이 프로파일이 반드시 `dmnd/dmdd`를 갖는 것도 아닙니다. 현재 검사는 첫 `ICC_PROFILE`만 보고 분할 APP2 프로파일 전체도 구조적으로 검증하지 않습니다.

근거 / `test/safe/run.mjs:258-270`.

수정안 / 허용할 ICC 프로파일의 전체 바이트 SHA-256 allowlist를 사용하거나 출력 후 ICC를 제거하십시오. “크기+두 태그 부재”를 안전성 경계로 사용하면 안 됩니다.

### 3-4. PNG는 네 청크만 금지하여 임의 보조 청크를 놓침

문제 / `iCCP`, `tIME`, `sPLT` 및 private ancillary chunk에도 데이터가 실릴 수 있습니다. PNG 규격은 private·unknown ancillary chunk를 명시적으로 허용합니다. [W3C PNG 규격](https://www.w3.org/TR/png/)

근거 / `test/safe/run.mjs:241-245`.

수정안 / PNG 청크를 구조적으로 파싱하여 `IHDR`, 필요한 색공간 청크, `IDAT`, `IEND`의 allowlist만 허용하십시오. 적어도 모든 ancillary/private chunk의 목록과 payload 크기를 검증해야 합니다.

## 4. 목적 게이트와 법적 매트릭스

### 4-1. `JP_RULES`는 정본과 일치하지 않음

문제 / 주요 불일치는 다음과 같습니다.

- `JP_EXTRA(address_loose/tel)`는 법적 정본에 전혀 없습니다.
- `資格確認書`의 keep 항목을 모든 목적에 적용하며 `事業所名称`, `保険者名`, `資格取得年月日`까지 추가합니다.
- `運転免許証番号`은 정본상 `identity_submit`에서 must-keep인데 구현은 모든 목적 optional입니다.
- `マイナンバーカード`의 `my_number`, `qr` 개별 gate는 정본의 `裏面全体` 규칙을 코드에서 분해해 추가한 것입니다.
- `住民票`의 keep은 정본상 `identity_submit`, `bid_attachment`인데 구현은 모든 목적입니다.
- 정본의 `発行日・発行者`는 검출 규칙이 없어 keep 경고가 실제로 생성되지 않습니다.
- `住民票コード`는 정본에서 `verified:false`인데 자동 마스킹됩니다.

근거 / `test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:16-57`; `public/safe/index.html:1381-1431`, `1450-1503`.

수정안 / 사람이 작성한 두 번째 표가 아니라 legal matrix JSON을 빌드 시 변환해 단일 소스로 사용하십시오. `verified:false`는 자동 level을 금지하는 검증 규칙을 추가해야 합니다.

### 4-2. 미명시 목적을 항상 `optional`로 만드는 폴백은 잘못됨

문제 / `return r.keep ? 'optional' : 'optional'`은 조건문이 무의미하며, 매트릭스가 의도적으로 명시하지 않은 조합과 “선택 제공”을 구별하지 못합니다. 특히 `資格確認書` 번호군은 `my_number_procedure`에서 optional로 노출되지만, 해당 목적이 의료보험 관련 개인번호 사무인지에 따라 번호가 필요한 예외가 존재할 수 있습니다. 구체적 업무 조합은 **확인 불가**입니다. 厚労省도 건강보험 사무 또는 관련 사무에는 고지 제한 예외가 있음을 명시합니다. [厚労省](https://www.mhlw.go.jp/stf/newpage_13989.html)

근거 / `public/safe/index.html:1433-1441`.

수정안 / 미명시는 `null`로 두고 UI에 내지 마십시오. 명시적으로 `optional`인 경우만 optional을 반환하도록 매트릭스에 목적별 상태를 완전 열거해야 합니다.

### 4-3. `本籍`/`筆頭者` 확장은 법적 근거가 없음

문제 / 근거가 “필요 없어 보인다”와 픽스처 기대값뿐이라 순환 논증입니다. `my_number_procedure`·`bid_attachment`의 모든 하위 업무에서 불필요하다는 출처가 없습니다.

근거 / `public/safe/index.html:1377-1380`, `1426-1427`; `docs/jp/s3_report.md:239-242`.

수정안 / 법적 정본을 바꾸기 전에는 해당 두 목적을 optional로 두십시오. 실제 제출처 요구사항 또는 공식 지침을 목적별로 확보한 뒤 recommend로 승격해야 합니다.

### 4-4. マイナカード裏面 안내는 지나치게 단정적임

문제 / 身元確認 목적으로 뒷면을 복사·보관하면 제한 위반 가능성이 있으므로 앞면 제출 안내는 타당합니다. 다만 단순히 보았다는 것까지 불법인 것은 아니므로 “番号法により…できません”은 행위·주체·예외를 생략합니다. `個人番号手続` 선택만으로 모든 수령처가 적법한 개인번호 이용사무 수행자임을 확인할 수도 없습니다.

근거 / `public/safe/index.html:1804-1812`; PPC는 의도치 않게 본 것과 복사·기록을 구별합니다. [PPC FAQ Q6-12](https://www.ppc.go.jp/all_faq_index/faq5-q6-12/)

수정안 / “법정 개인번호 사무를 수행하는 제출처에 한해 해제” 확인을 추가하고, 단순 목적 드롭다운만으로 전면 해제하지 마십시오.

### 4-5. keep을 가릴 수 있게 둔 것은 법 위반이 아니라 제출 유효성 문제

문제 / 모든 keep 필드를 법적으로 차단해야 한다는 근거는 없습니다. 그러나 `my_number_procedure`의 個人番号처럼 목적 자체가 성립하지 않는 필드까지 일괄 비공개할 수 있어, 사용자가 “해당 목적용 안전 파일”이라고 오해할 수 있습니다.

근거 / `public/safe/index.html:2494-2506`. 법적 차단 필요성은 **확인 불가**입니다.

수정안 / 일반 keep은 경고 유지, 목적의 핵심 필드는 “강제 유지” 또는 최종 확인 대화상자로 분리하십시오. 최소한 목적 적합성 상태를 실패로 표시해야 합니다.

### 4-6. `その他` 토글이 법적 띠를 무조건 해제함

문제 / `back_all`과 `qr`가 `other`에 매핑되고 `isOn`은 카테고리 boolean만 봅니다. 사용자가 その他를 끄면 マイナカード裏面 전체와 資格確認書 QR 띠가 출력에서 사라집니다. 별도 강한 경고도 없습니다.

근거 / `public/safe/index.html:1831-1834`, `751-777`, `2320-2329`, `2480-2482`.

수정안 / 법적 preset 엔티티는 일반 카테고리 토글에서 분리하십시오. 해제는 개별 항목과 목적별 확인을 거치게 하고, 하네스도 카테고리 OFF 상태에서 법적 띠가 유지되는지 검증해야 합니다.

## 5. 하네스 유효성

### 5-1. `jp_auto_fields`는 목적·검증 상태를 표현하지 못함

문제 / 문서별 정적 배열이라 목적별 `auto/gate/keep` 차이를 나타내지 못합니다. `住民票コード`의 `verified:false`도 무시됩니다. 앱과 하네스가 같은 잘못된 해석을 공유할 수 있습니다.

근거 / `test/safe/specs.json:83-90`; `test/safe/run.mjs:430-496`.

수정안 / legal matrix JSON에서 `(doc, field, purpose)`별 기대 level을 직접 계산하고, 정적 중복표를 제거하십시오.

### 5-2. 유효 個人番号 자동 띠가 전혀 검증되지 않음

문제 / `JP_MASK_OR_CAND`는 잘못된 체크디지트 더미가 candidate만 되어도 통과합니다. 유효 체크디지트가 `auto/gate`가 되는 테스트는 없습니다.

근거 / `test/safe/specs.json:90-91`; `test/safe/run.mjs:423-425`, `495-496`; 생성기는 모두 무효 번호만 만듭니다(`gen.py:35-45`).

수정안 / 실물과 무관한 텍스트/캔버스 유닛 픽스처로 유효 체크디지트 번호를 생성하여 `checkOk:true`, 자동 띠, 목적 전환 해제를 각각 검증하십시오. 공개 카드 이미지에 유효 번호를 넣을 필요는 없습니다.

### 5-3. 60% 피복은 판독 불가를 보장하지 않음

문제 / 한 OCR word의 60%만 덮고 나머지 40%에 여러 숫자가 그대로 남아도 통과합니다. 구현자 스스로 96% 피복인데 첫 숫자가 노출된 사례를 기록했으므로 현재 기준의 부적합성이 이미 입증되었습니다.

근거 / `test/safe/run.mjs:404-424`; `docs/jp/s3_report.md:207-212`.

수정안 / 숫자 필드는 각 문자 또는 잉크 연결요소가 100%+허용 오차로 덮이는지 검사하십시오. 출력 이미지에 대해 OCR 재검사와 픽셀 차분을 병행해야 합니다.

### 5-4. `geometry:false`가 가장 어려운 입력의 오배치를 숨김

문제 / JPG 세 건과 목적 교차 한 건은 field와 mode만 검사합니다. 완전히 엉뚱한 위치의 띠, 빈 박스, 카테고리 OFF 상태도 통과할 수 있습니다.

근거 / `test/safe/specs.json:113-116`, `145-153`; `test/safe/run.mjs:448-465`. `require_banded`는 `mode !== 'ok'`만 봅니다.

수정안 / 회전·원근 변환 행렬을 픽스처에 기록하거나 출력 이미지의 알려진 민감 문자열/영역을 OCR·픽셀 기준으로 검사하십시오.

### 5-5. 공허한 단언 경로가 남아 있음

문제 / 다음 경로가 공허하거나 약합니다.

- absent box는 `skipped`로 기록만 하고, 다른 박스 하나만 검사하면 `JP_COVERAGE > 0` 통과.
- `P.keep === 'all'`이면 keep 검사를 아예 빈 배열로 만듦.
- `require_banded`는 좌표·located·`isOn`을 확인하지 않음.
- `JP_CLEAR`도 위치와 실제 출력 피복을 확인하지 않음.
- `__candidateOver`는 주석과 달리 candidate의 활성 상태나 mode를 확인하지 않음.

근거 / `test/safe/run.mjs:111-119`, `453-465`, `473-500`.

수정안 / 기대 키 누락을 즉시 실패시키고 `checked === expectedExistingCount`를 요구하십시오. field 단언은 실제 `__maskRects`와 교차하도록 바꾸고 `keep:'all'`은 모든 box를 열거해 검사해야 합니다.

### 5-6. `max_auto`는 오탐 종류를 제한하지 못함

문제 / kenpo 실측 5에 상한 8, kouki 실측 3에 상한 8이면 각각 3개·5개의 신규 오탐이 생겨도 통과합니다. 올바른 엔티티가 빠지고 잘못된 엔티티가 대신 생겨 총수만 같아도 통과합니다.

근거 / `test/safe/specs.json:94-104`; 실측값은 `docs/jp/s3_report.md:201-202`.

수정안 / 총수 상한을 보조 지표로만 두고 필드·좌표별 allowlist와 “예상하지 않은 자동 엔티티 0” 단언을 추가하십시오.

## 6. 커버리지 없는 구현

### 6-1. 레이블 없는 QR 완화가 충분하지 않음

문제 / candidate로 낮췄지만 기본 ON이므로 완화가 실패했습니다.

근거 / `public/safe/index.html:1823-1825`, `1796-1801`.

수정안 / 실제 QR fixture가 생기기 전까지 optional·기본 OFF로 고정하십시오.

### 6-2. 電話·FAX 테스트가 통합 경로를 검증하지 않음

문제 / 유닛은 정규식만 직접 호출하며 `jpFindLabel → jpBoxes → jpApply`를 지나지 않습니다.

근거 / `test/safe/run.mjs:524-532`.

수정안 / 합성 canvas/PDF에 레이블과 번호를 분리 배치해 세그먼트·좌표·mode까지 검증하십시오.

### 6-3. 주소 자동 분기는 “미검증”이 아니라 사실상 미구현

문제 / `strong`이 사용되지 않아 실제 문서뿐 아니라 코드상으로도 자동 승격이 없습니다.

근거 / `public/safe/index.html:1709`; 사용처 없음.

수정안 / 전략과 구현 중 하나를 일치시키고 그 경로를 통합 테스트하십시오.

### 6-4. 다중 페이지는 단순 상속보다 더 위험함

문제 / 페이지별로 다른 `c`로 추출하면서 `jpApply`는 1페이지 `cls.doc/side` 규칙만 적용합니다. マイナカード 앞·뒤 양면 PDF에서 첫 페이지가 back이면 모든 페이지에 `back_all`을 씌우고, 첫 페이지가 front이면 뒤 페이지 전체 띠가 생성되지 않습니다.

근거 / `public/safe/index.html:1774-1784`, `1792-1812`.

수정안 / finding마다 `doc/side`를 저장하고 페이지별로 level·whole-face rule을 적용하십시오. 앞→뒤, 뒤→앞, 동일 문서 2페이지, 혼합 문서 PDF를 모두 테스트해야 합니다.

### 6-5. 테두리 중앙값 배경은 컬러 양식에 취약함

문제 / 가장자리 24점이 테두리·그라데이션·사진 배경이면 잘못된 단일 RGB가 배경이 됩니다. 이후 거의 모든 셀이 ink가 되거나 실제 검은 구조가 배경으로 간주되어 `jpFrameBelow`와 `jpSolidSquares`가 붕괴합니다.

근거 / `public/safe/index.html:1220-1244`, `1334-1347`.

수정안 / 페이지 다영역 색상 클러스터, 로컬 배경, 명도/색차 기반 적응 임계값을 사용하십시오. 어두운 전면·컬러·테두리 있는 합성 fixture가 필요합니다.

## 7. 공개 저장소와 카드 더미

### 7-1. §4 안전조건을 전부 충족하지 않음

문제 / 명백한 위반은 “개별 고해상 카드 파일 공개 배포 금지”와 “법률 검토 전 내부 전용”입니다. 또한 모든 번호가 불일치/규격 외라는 주장도 코드와 맞지 않습니다. `mynumber_invalid()`와 면허번호만 의도적으로 무효화하며, `hokensha()`·記号/番号/枝番·고정 `住民票コード`에는 유효성 부정 로직이 없습니다. 우편번호 `999-99xx`가 실제 미할당임도 검증하지 않습니다.

근거 / `docs/jp/jp_safefile_strategy_v2_2026-10-21.md:95-104`; `test/safe/fixtures/jp/gen.py:29-47`, `69-80`, `91-108`, `199-203`. 실제 번호·주소와 충돌하지 않는다는 증거는 **확인 불가**입니다.

수정안 / 모든 번호군에 문자를 삽입하거나 명시적 무효 검사를 두고, 주소·우편번호도 예약된 비실재 네임스페이스를 사용하십시오. 공개 고해상도 바이너리는 법률 검토 전 제거해야 합니다.

### 7-2. 실질 위험은 낮지만 “0”은 아님

문제 / 워터마크·도식형·인감/실QR 부재 때문에 직접 오용 가치는 낮습니다. 그러나 공개 Git 기록은 영구 복제 가능하고, 일부 번호가 실제 형식이며 고해상도 카드형 이미지라는 점 때문에 편집 재료 가치는 남습니다. 일본 형법상 공문서 위조는 `行使の目的`이 핵심이므로 이 테스트 fixture 자체가 곧 위법이라고 단정할 근거는 없습니다. [刑法 제155조](https://laws.e-gov.go.jp/document?lawid=140AC0000000045_20250601_505AC0000000028)

GitHub 정책도 이 fixture를 명시적으로 금지한다고 확인할 수 없습니다. 다만 불법·사기·기만·사칭 목적 사용은 금지됩니다. [GitHub Acceptable Use](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies?apiVersion=2022-11-28)

근거 / `CLAUDE.md:1646-1665`; 구체적 일본 변호사 검토 결과는 **확인 불가**입니다.

수정안 / “오용 가치 사실상 0” 표현을 삭제하고, 법률·플랫폼 위험을 낮음이지만 미해결로 표기하십시오.

### 7-3. 대안 비교

문제 / 비공개 submodule은 접근권한·CI secret·외부 기여자 재현성이 나빠집니다. 생성 스크립트만 커밋하면 폰트/Pillow 차이로 픽셀 골든이 흔들립니다. 해상도 축소는 OCR·기하 테스트의 의미를 훼손합니다.

근거 / `CLAUDE.md:1656-1664`.

수정안 / 가장 현실적인 순서는 다음입니다.

- 공개 저장소에는 구조 테스트용 저위험 SVG/캔버스 생성 스크립트와 의미 기반 assertions만 유지.
- 픽셀 골든은 고정 컨테이너 이미지로 결정적으로 생성하고 해시 검증.
- 꼭 필요한 고해상도 카드 fixture만 비공개 artifact 저장소에서 CI에 주입.
- 단순 축소본은 문서·마케팅 검토용으로만 사용하고 OCR 골든 대체물로 쓰지 않음.

## 즉시 고쳐야 할 상위 5개

1. **AMBER · 배포 전** — 분류 실패가 무경고로 JP 탐지를 전부 끄는 문제. 실패 경고와 저신뢰 fallback이 필요합니다.
2. **AMBER · 배포 전** — 레이블 없는 사각형이 candidate임에도 기본 ON인 문제. 얼굴사진·인감 오탐을 기본 출력에 넣습니다.
3. **AMBER · 배포 전** — 다중 페이지에서 첫 페이지 `doc/side`를 전 페이지에 적용하는 문제. マイナカード 양면 처리 결과가 순서에 따라 반대가 됩니다.
4. **AMBER · 배포 전** — `その他` 카테고리 OFF로 `back_all`·QR 법적 띠가 조용히 사라지는 문제.
5. **AMBER · 다음 런 전** — 하네스의 60% 피복, skipped-key 허용, `require_banded` 좌표 미검증. 현재 389/389는 숫자 노출과 오배치를 배제하지 못합니다.
