warning: `--full-auto` is deprecated; use `--sandbox workspace-write` instead.
2026-10-21T02:36:56.659874Z ERROR codex_models_manager::cache: failed to load models cache: missing field `base_instructions` at line 139 column 5
OpenAI Codex v0.146.0
--------
workdir: /Users/sunghoon/Projects/docpack
model: gpt-5.6-sol
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR]
reasoning effort: none
reasoning summaries: none
session id: 01a15c51-a729-7e11-8adb-f2e7d91ef1e2
--------
user
당신은 브라우저 내 문서 마스킹 파이프라인과 일본 개인정보 실무에 정통한 독립 검토자입니다. 아래 **이번 diff** 를 작성한 Claude와 **독립적으로** 비판적 검토를 하세요. 칭찬은 생략하고 **틀린 것·빠진 것·위험한 것만** 쓰세요. 각 항목은 "문제 / 근거(파일:줄) / 수정안" 형식이고, 근거를 못 찾으면 **"확인 불가"** 라고 명시하세요. 추측을 근거처럼 쓰지 마세요.

## 이번 라운드가 무엇인지

직전 라운드(`546344b`)에 대한 당신의 검토가 `docs/jp/codex_review_s3_2026-10-21.md` 입니다. 그 중 **「즉시 고쳐야 할 상위 5개」의 배포 차단 4건 + 정본 불일치 + 하네스 강화**를 반영한 것이 이번 커밋입니다. 처리표(수용/보류/반려 + 이유)는 `docs/jp/s3b_report.md` §4 에 있습니다.

**검토 대상은 이번 diff 뿐입니다.** 직전 라운드에서 이미 지적했고 이번에 「보류」로 분류된 항목(§4 의 1-2, 1-3, 1-6, 2-1, 2-4, 3-1, 3-3, 3-4, 4-5, 5-4, 6-2, 6-5)은 **다시 쓰지 마세요** — 보류 사유 자체가 틀렸다고 판단하는 경우에만, 그 사유를 인용해서 반박하세요.

## 검토 대상

```
git show HEAD --stat
git show HEAD
```

- 구현: `public/safe/index.html` — `jpClassify` / `jpSuspect` / `JP_SUSPECT_RE` / `JP_RULES` / `jpLevel` / `JP_LEGAL_FIELDS` / `jpScan` / `jpExtract`(push 의 doc·side) / `jpApply`(`resolve`) / `jpMnGateOpen` / `jpRenderBar` / `jpSetPurpose` / `isOn` / `renderList` / `sectionHtml` / 토글·bulk 핸들러 / `myNumberCheckOk` 주석 / i18n 4개 언어
- 정본: `test/safe/fixtures/jp/jp_legal_matrix_alpha4.json` (v2026-10-21b — `fields` / `optional_when` / `general_jp` / `_schema` 신설)
- 대조기: `test/safe/check_matrix.mjs` (**신규**)
- 하네스: `test/safe/run.mjs` (`__inkCover` / `__fieldBands` / `__allCatsOff`·`__restoreCats` / `__autoFields` / `jpCheckBox` / `checkJpDoc` / `checkJpMultiPage` / `checkJpMyNumber` / `checkJpUnlabelled` / `checkJpWarn` / `checkMatrix` / `loadDoc` 완료 조건)
- 기대값: `test/safe/specs.json` (`jp_my_number` / `jp_unlabelled_block` / `jp_warn` / `require_legal` / `auto_allow` / `confirm_mynumber` 신설), `test/safe/fixtures/jp/*/*.specs.json`, `test/safe/fixtures/jp/gen.py`
- 구현자 자술: `docs/jp/s3b_report.md` (§4 처리표 · §6-1 변이 프로브 · §7 잔여 위험)
- 직전 검토 원문: `docs/jp/codex_review_s3_2026-10-21.md`

실행 환경 참고: `cd test/safe && npm install && node run.mjs` (Chrome 필요, Tesseract.js·pdf.js CDN 접근 필요). `node test/safe/check_matrix.mjs` 는 **네트워크·브라우저 없이 단독 실행**됩니다 — 적어도 이건 돌려 보세요. 돌릴 수 없으면 **정적 검토만 하고 그렇다고 적으세요.** 테스트를 돌린 것처럼 쓰지 마세요.

---

## 1. 배포 차단 4건이 **실제로 닫혔는가**

구현자 주장: 네 건 모두 고쳤고, 고치기 전 코드를 되돌려 넣어 하네스가 빨개지는 것까지 확인했다(§6-1 프로브 A~F).

1-1. **분류 실패 경고**. `jpClassify` 의 `low` 분기는 `def.title.some(t => txt.includes(t))` 하나에 걸려 있습니다. ① 제목이 깨지고 다른 키워드만 살아 점수가 3 이하인 양식에서는 `low` 에도 못 들어가고 **경고만** 뜨는데, 그 경고로 충분합니까? ② `JP_SUSPECT_RE` 에 `令和|平成|昭和` 가 들어 있어 **일본 문서 전반**이 걸립니다 — 일본어 이력서·청구서를 올린 사용자가 매번 「자동 마스킹이 적용되지 않았다」는 붉은 배너를 보게 되는데, 이 경고가 **늑대소년이 되어 진짜 실패를 묻어버릴** 위험은? ③ `low` 일 때 auto/gate 를 `recommend` 로 강등하는데, `recommend` 는 **기본 ON** 입니다. "자동 마스킹은 적용하지 않았다" 는 배너 문구와 실제 동작(기본 ON 띠가 그려짐)이 **모순됩니까?**

1-2. **레이블 없는 블록**. 이제 `optional`/`ok` 입니다. 구현자는 §7 에서 "`資格確認書` 에서 OCR 이 라벨을 잃으면 QR 이 후보로만 남는다"는 잔여 위험을 스스로 적었습니다. 이 교환이 **미탐 쪽으로 과하지 않습니까?** 라벨 없이도 띠를 정당화할 수 있는 **값싼** 증거(quiet zone, finder pattern 3개, 모듈 주기)가 지금 구현 가능한 수준입니까, 아니면 진짜 QR 픽스처가 선행돼야 합니까?

1-3. **다중 페이지**. `jpScan` 은 `pageCls[pi] = jpClassify(pi) || cls0` 로 **분류 불가 페이지에 1페이지 규칙을 상속**시킵니다. 양면 카드 + 무관한 첨부(예: 통장 사본)가 한 PDF 에 섞이면 그 첨부 페이지가 **카드 규칙으로 판정**됩니다. 이게 안전한 방향입니까, 위험한 방향입니까? 또 `back_all` 은 "그 페이지가 裏面인 페이지마다" 거는데, **`jpApply` 는 매 purpose 변경마다 전 페이지를 다시 도는** 구조입니다 — 30페이지 PDF 에서 비용·UI 반응성 문제는?

1-4. **법적 그룹**. `isOn = e => e.legal ? true : catEnabled[e.type] !== false` 는 **카테고리 체크박스가 법적 띠에 대해 거짓말을 하게** 만듭니다(「その他」를 꺼도 ⚖️ 항목은 남는다). 사용자가 "껐는데 왜 남지?" 로 혼란할 가능성과, 조용히 사라지던 이전 동작 중 어느 쪽이 나쁩니까? `legal` 플래그는 `mode === 'no'` 일 때만 붙습니다 — 사용자가 개별 해제해서 `mode='ok'` 가 되면 `legal` 은 **그대로 true 로 남아** 다음 `renderAll` 에서도 ⚖️ 그룹에 머뭅니다. `jpApply` 재실행 전까지 상태가 어긋나는 경로가 있습니까?

---

## 2. 정본 일치 — **대조기 자체**를 의심하세요

2-1. `check_matrix.mjs` 는 `index.html` 에서 **문자열 슬라이스**로 `JP_RULES`·`jpLevel`·`JP_LEGAL_FIELDS` 를 잘라 `new Function` 으로 실행합니다. 마커(`const P_NOT_MYNUM =` → 첫 `\n};\n`)가 깨지는 편집이 무엇입니까? 깨지면 **조용히 통과**합니까, 실패합니까? (구현자는 `compared < 100` 가드를 뒀다고 주장합니다 — 그 가드가 충분한 경계입니까?)

2-2. 파생 규칙 `must_keep_when → keep · mask_when → level · optional_when → optional · 그 외 null`. 이 파생이 **매트릭스의 의도를 왜곡**하는 조합이 있습니까? 특히 `level: "optional"` 인 규칙(免許証番号)에서 `mask_when: ["consult_share"]` 가 `optional` 로 파생되는 것이 맞습니까 — 「마스킹 대상인데 기본 OFF」라는 상태가 일관됩니까?

2-3. **미명시 → `null` (UI 에 내지 않음)** 의 실제 영향을 세어 주세요. 예: `資格確認書` 의 `hokensha_bango` 는 `my_number_procedure` 에서 이제 **UI 에 아예 안 나옵니다**. 그 목적으로 資格確認書 를 제출하는 사용자가 보험자번호를 가리고 싶으면 수동 드래그뿐입니다. 이게 4-2 지적의 의도대로입니까, 과잉입니까?

2-4. 구현자는 `本人特定事項` 에 `optional_when: ["consult_share"]` 를, `事業所名称·保険者名·資格取得年月日` 에 `verified:false` keep 을 **매트릭스에 새로 써 넣었습니다**. 이것은 "코드의 일탈을 정본으로 승격" 한 것입니까, 아니면 정당한 명세화입니까? **출처 없는 규칙을 정본에 적는 것 자체**가 정본의 신뢰도를 떨어뜨립니까?

2-5. `general_jp` 섹션은 `applies_to` 4문서에 같은 규칙을 복제합니다. 문서가 늘어날 때 이 구조가 틀리는 방식은?

2-6. **個人番号 확인 체크박스**. `jpState.mnConfirmed` 는 목적 변경 시 초기화되지만 **문서를 바꾸면?** (`resetAll` → `JP_STATE0`) 그리고 체크박스는 `hasMn && purpose === 'my_number_procedure'` 일 때만 보입니다 — `資格確認書`·`運転免許証` 처럼 `my_number` 가 없는 문서에서 `my_number_procedure` 를 고르면 **아무것도 바뀌지 않는데 목적만 바뀐 상태**가 됩니다. 사용자에게 그 사실이 보입니까?

2-7. PPC FAQ Q6-12 와 번호법에 비추어, 새 안내 문구가 **여전히 부정확하거나 과한** 부분이 있습니까? 확인 체크박스 문구(「提出先が法定の個人番号関係事務を行うことを確認しました。」)가 사용자에게 **확인할 수 없는 것을 확인시키는** 것은 아닙니까?

---

## 3. 하네스 단언이 **공허하지 않은가** (이번 라운드의 핵심)

직전 라운드에서 당신이 지적한 공허한 경로를 고쳤다고 주장합니다. **새로 만든 단언이 같은 함정에 빠지지 않았는지** 봐 주세요.

3-1. `__inkCover`. ① 임계 60 을 "워터마크 제외"를 근거로 골랐습니다 — 워터마크가 더 진한 픽스처나 **실제 스캔 문서**에서 이 임계가 **진짜 글자를 잉크가 아니라고** 판정할 수 있습니까? ② `n < 6` 픽셀 성분을 버립니다 — 작은 숫자(1, 점)가 통째로 무시될 수 있습니까? ③ 성분당 **99%** 커버 기준은 어디서 왔습니까(근거 없는 fudge 아닙니까)? ④ `components > 0` 가드가 있지만, **기대 박스가 통째로 빈 영역을 가리키면** 성분 0 → 실패로 보고됩니다. 이게 올바른 방향입니까?

3-2. `__fieldBands` 의 `inMask` 는 rect 를 **좌표 0.01 오차로 동일 비교**합니다. `__maskRects` 와 `__fieldBands` 가 **같은 함수(`mergeLineBoxes`+`bandRect`)로 계산**되므로 이 비교는 **항상 참이 되는 동어반복** 아닙니까? 참이 아닐 수 있는 경우를 하나라도 제시할 수 있습니까? (제시 못 하면 이 단언은 `isOn`·`mode` 검사의 중복일 뿐입니다 — 그렇게 적어 주세요.)

3-3. `auto_allow` 는 **빈 배열**인 케이스가 많습니다(`[]`). 빈 allowlist 는 "auto 가 하나도 없어야 한다"는 강한 단언입니까, 아니면 **검사하지 않는 것과 구별되지 않습니까**? (`c.auto_allow` 가 `undefined` 면 단언 자체를 건너뜁니다 — `[]` 와 `undefined` 의 구분이 코드에서 성립합니까?)

3-4. `jp_warn`·`jp_my_number` 는 **붙여넣기 경로**(`renderTextPages`)로 페이지를 합성합니다. 이 경로의 텍스트 레이아웃은 실제 OCR·pdf.js 아이템과 **다른 성질**(완벽한 박스, 잡음 없음, 한 줄 = 한 행)을 가집니다. 이 합성으로 통과한 단언이 **실제 문서에서 통과한다는 보장**이 됩니까? 어디까지가 증명되고 어디서부터가 외삽입니까?

3-5. `checkJpMultiPage` 는 jsPDF 로 **런타임에** 2페이지 PDF 를 만듭니다. 그 PDF 는 pdf.js 가 텍스트 레이어 없이 읽고 OCR 로 떨어집니다 — 즉 **원본 PNG 를 JPEG 재인코딩한 뒤 OCR** 한 결과입니다. 이 경로가 "양면 카드 PDF" 의 현실을 대표합니까?

3-6. `require_legal` 은 `__allCatsOff()` 로 전역 `catEnabled` 를 꺼고 `__restoreCats()` 로 되돌립니다. 구현자는 첫 버전이 **복원을 안 해서 이후 300개 단언이 오염됐다**고 §6-2 에 적었습니다. 현재 버전에 **남은 전역 오염 경로**가 있습니까? (`catDefault`, `showAllCats`, `jpState.mnConfirmed`, `BAND_COLOR`, `aiDone` …)

3-7. `keep: "all"` 분기는 고쳤지만 **도달하는 케이스가 없다**고 §3-3 에 적혀 있습니다. 「고쳤지만 실행되지 않는 코드」를 고친 것으로 치는 게 맞습니까? 도달시킬 값싼 방법이 있습니까?

3-8. 픽스처 기대표를 variant 별로 **가지치기**했습니다(`gen.py` 의 `finalize`). 가지치기는 "검사 안 되던 키를 없앤" 것이라 **커버리지가 줄어든 것**이기도 합니다. 줄어든 것이 정확히 무엇이고, 그중 **실제로 검사했어야 하는 것**이 있습니까? (예: `kouki` 에 `kigo/bango/edaban` 이 정말 없습니까?)

---

## 4. 이번 diff 가 **새로 만든** 위험

4-1. `JP_FIELD_RULES.shikaku_kakuninsho` 에 `shikaku_date`·`hokensha_name`·`jigyosho` 규칙이 추가됐습니다. `last:true` 로 **레이블 뒤 전부**를 가져가며 그 스팬을 `used` 로 마킹합니다 — 기존 폴백(6~10자리)·`address_loose` 가 **그만큼 못 보게** 됩니다. 이 때문에 **가려져야 할 것이 안 가려지는** 경로가 생깁니까? 특히 `保険者名` 행에 번호가 함께 인쇄되는 양식에서?

4-2. `jpLevel` 이 `null` 을 돌려주면 `jpApply` 가 finding 을 **버립니다**. 그 필드는 UI 에도, keep 경고에도, 후보에도 나오지 않습니다. 사용자가 **그 값이 문서에 있다는 사실조차** 모르게 되는 조합이 있습니까?

4-3. `legal` 플래그가 `mode==='no'` 조건에 묶인 결과, **`optional` 로 강등된 `qr`(레이블 없는 블록)** 은 법적 그룹에 들어가지 않습니다. 사용자 입장에서 「法令・提出先ルール」 그룹의 **구성이 문서마다 달라지는** 것이 혼란을 줍니까?

4-4. i18n: `jpUnclassifiedWarn` 은 ko/en/es 에서 **일본어 원문 + 괄호 번역**입니다. 이 형식이 맞습니까?

4-5. 그 밖에 이번 diff 에서 **기능적으로 틀린 것**(경계 조건, null 처리, 이벤트 리스너 누락, 상태 초기화 누락)을 찾아 주세요.

---

## 5. 구현자가 스스로 「확신 없음」으로 올린 것

아래는 §7 「잔여 위험」과 §4 「보류」에서 구현자가 **스스로 불확실하다고 밝힌** 지점입니다. 여기서 틀린 것을 찾으면 그게 가장 값싼 수확입니다.

5-1. 레이블을 잃은 코드 블록이 후보로만 남는 것 — 교환이 올바른 방향입니까?
5-2. `発行日`·`発行者` 가 매트릭스에서 keep 인데 **탐지 규칙이 없어 경고가 생성될 수 없는** 상태로 남겨둔 것 (지우지 않은 이유: 지우면 정본이 침묵하게 된다). 맞습니까?
5-3. `strong`(郵便番号+都道府県) 을 레벨에 반영하지 않고 **전략 쪽 약속을 지운** 선택.
5-4. `jp_auto_fields` 정적 표를 없애지 않고 `check_matrix` 로 묶기만 한 선택 (당신의 5-1 지적에 대한 부분 수용).

---

마지막에 **"즉시 고쳐야 할 상위 5개"** 를 우선순위로 요약하고, 각각에 **AMBER/GREEN** 등급과 "배포 전/다음 런" 을 붙이세요. **배포 차단 4건이 닫혔는지에 대해 명시적으로 `해소됨 / 부분 해소 / 미해소` 판정**을 내려 주세요. 일본어 고유명사는 그대로 두고, 답변은 **한국어**로. **파일을 수정하지 말고 검토 결과만 출력**하세요.

CODEX_REVIEW_READY
warning: Skill descriptions were shortened to fit the 2% skills context budget. Codex can still see every skill, but some descriptions are shorter. Disable unused skills or plugins to leave more room for the rest.
hook: SessionStart
hook: SessionStart Completed
hook: UserPromptSubmit
hook: UserPromptSubmit Completed
codex
요청하신 범위대로 이번 커밋 diff만 독립 검토하겠습니다. 먼저 직전 검토와 처리표를 대조한 뒤, 대조기를 실제 실행하고 구현·하네스의 단언 경로를 줄 단위로 추적하겠습니다. 파일은 수정하지 않습니다.
hook: PreToolUse
hook: PreToolUse Completed
  → 이번 커밋 diff·직전 검토·처리표 범위 확정
  • 구현·정본·대조기·하네스 정적 추적
  • check_matrix 및 가능한 테스트 실행
  • 근거 줄번호와 배포 차단 판정 정리
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'git show HEAD --stat && git status --short && git show --format=fuller --no-ext-diff --find-renames HEAD -- docs/jp/s3b_report.md docs/jp/codex_review_s3_2026-10-21.md test/safe/check_matrix.mjs' in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
commit 4b641bb4462ae6dfc8a1ab5436fb42797f8b7667
Author: Sunghoon Sim <chaop2026@gmail.com>
Date:   Wed Oct 21 10:55:56 2026 +0900

    fix(safe): JP-1 S3b — close the four deploy blockers, make the legal matrix the single source
    
    Cross-review input: docs/jp/codex_review_s3_2026-10-21.md
    Report: docs/jp/s3b_report.md (§4 = per-finding triage, §6-1 = mutation probes)
    
    Golden 389 → 484, 0 fail. Matrix cross-check: 188 (doc, field, purpose) triples
    identical. SW fault-injection harness still 9/9.
    
    All four blockers were failures that look exactly like correct behaviour from
    the outside, which is why each one is now pinned by an assertion that was proved
    to go red against the pre-fix code.
    
    1. Classification failure silently disabled every Japanese rule. Now three
       outcomes: confident / low (title read, score short → auto+gate demoted to
       recommend) / unclassified. The last two raise a blocking banner in four
       languages. The banner is independent of the purpose bar — its reason for
       existing is the case where there is no bar.
    
    2. An unlabelled near-square ink block was banded by DEFAULT: the comment said
       "candidate, never automatic" but `recommend`'s default mode is 'no'. A face
       photo, a filled round seal (bbox fill ~0.785) or a black table header all
       satisfy the size/ratio/fill test, and this path has zero golden coverage.
       It is now `optional` / mode 'ok'.
    
    3. Multi-page used page 1's class for every page, so a two-sided card scanned
       into one PDF came out opposite depending on scan ORDER. Findings now carry
       their own page's doc/side; the whole-face band is applied per back-face page.
    
    4. Unticking the catch-all "その他" category removed the マイナカード裏面 band
       and the 資格確認書 QR band from the output with no warning. Statutory bands
       now carry a `legal` flag, bypass the category checkboxes, live in their own
       「法令・提出先ルール」 group, and can only be released one item at a time.
    
    Legal matrix (jp_legal_matrix_alpha4.json v2026-10-21b) is now the single
    source: new `fields` / `optional_when` / `general_jp` / `_schema`, and
    test/safe/check_matrix.mjs derives every (doc, field, purpose) from it, extracts
    JP_RULES out of index.html, and fails on any disagreement — run.mjs calls it
    first. It also enforces `verified:false ⇒ never auto/gate`. Level changes that
    follow: 免許証番号 → keep for identity_submit, 住民票コード → recommend (no
    source), 本籍/筆頭者 → optional for two purposes, and an unnamed combination is
    now `null` (not offered) instead of silently `optional`.
    
    Releasing a 個人番号 band now needs the purpose AND a confirmation checkbox; the
    裏面 notice was softened in four languages; the check-digit citation is fixed to
    e-Gov 関連命令 第5条 (the arithmetic was always right).
    
    Harness: number fields are checked per ink connected component (60% area says
    how much, never where — the recorded 96%-but-leaking case fails this), a missing
    expectation key is a FAIL rather than a reported skip, `keep:"all"` enumerates,
    `require_banded` checks located+isOn, and an auto-field allowlist catches
    "right count, wrong entities". New coverage for a VALID 個人番号 (every card
    dummy carries an invalid one by design, so that branch had never run).
    
    Two harness defects of my own, found and fixed here: __allCatsOff() leaked
    global catEnabled into every later document (14 red, 11 of them unrelated), and
    `pages.length > 0` is not "loaded" on a multi-page OCR document.
    
    Not deployed. Production DB untouched.
    
    Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>

 CLAUDE.md                                          |   93 +-
 docs/jp/codex_prompt_s3b.md                        |  109 +
 docs/jp/codex_review_s3_2026-10-21.md              | 4939 ++++++++++++++++++++
 docs/jp/s3b_golden_result.md                       |  664 +++
 docs/jp/s3b_report.md                              |  361 ++
 docs/jp/s3b_visual/render_kouki_bands.png          |  Bin 0 -> 275562 bytes
 docs/jp/s3b_visual/ui_legal_group.png              |  Bin 0 -> 149217 bytes
 docs/jp/s3b_visual/ui_mynumber_confirm.png         |  Bin 0 -> 155619 bytes
 docs/jp/s3b_visual/ui_unclassified_warning.png     |  Bin 0 -> 98929 bytes
 public/safe/index.html                             |  341 +-
 test/safe/check_matrix.mjs                         |  125 +
 test/safe/fixtures/jp/gen.py                       |   25 +-
 test/safe/fixtures/jp/jp_legal_matrix_alpha4.json  |  102 +-
 .../fixtures/jp/juminhyo/gaikokujin.specs.json     |    2 +-
 .../fixtures/jp/juminhyo/honseki_on.specs.json     |   11 +-
 .../fixtures/jp/juminhyo/ichibu_plain.specs.json   |    2 +-
 .../fixtures/jp/juminhyo/zenin_mynumber.specs.json |   15 +-
 .../safe/fixtures/jp/mynumber_card/back.specs.json |    2 +-
 .../fixtures/jp/mynumber_card/front.specs.json     |    2 +-
 .../jp/shikaku_kakuninsho/kenpo.specs.json         |    3 +-
 .../jp/shikaku_kakuninsho/kokuho.specs.json        |    6 +-
 .../jp/shikaku_kakuninsho/kouki.specs.json         |    8 +-
 test/safe/fixtures/jp/unten_menkyo/back.specs.json |    2 +-
 .../safe/fixtures/jp/unten_menkyo/front.specs.json |   11 +-
 test/safe/run.mjs                                  |  420 +-
 test/safe/specs.json                               | 1126 ++++-
 26 files changed, 8044 insertions(+), 325 deletions(-)
?? docs/jp/codex_review_s3b_2026-10-21.md
?? docs/jp/s3_visual/
commit 4b641bb4462ae6dfc8a1ab5436fb42797f8b7667
Author:     Sunghoon Sim <chaop2026@gmail.com>
AuthorDate: Wed Oct 21 10:55:56 2026 +0900
Commit:     Sunghoon Sim <chaop2026@gmail.com>
CommitDate: Wed Oct 21 10:55:56 2026 +0900

    fix(safe): JP-1 S3b — close the four deploy blockers, make the legal matrix the single source
    
    Cross-review input: docs/jp/codex_review_s3_2026-10-21.md
    Report: docs/jp/s3b_report.md (§4 = per-finding triage, §6-1 = mutation probes)
    
    Golden 389 → 484, 0 fail. Matrix cross-check: 188 (doc, field, purpose) triples
    identical. SW fault-injection harness still 9/9.
    
    All four blockers were failures that look exactly like correct behaviour from
    the outside, which is why each one is now pinned by an assertion that was proved
    to go red against the pre-fix code.
    
    1. Classification failure silently disabled every Japanese rule. Now three
       outcomes: confident / low (title read, score short → auto+gate demoted to
       recommend) / unclassified. The last two raise a blocking banner in four
       languages. The banner is independent of the purpose bar — its reason for
       existing is the case where there is no bar.
    
    2. An unlabelled near-square ink block was banded by DEFAULT: the comment said
       "candidate, never automatic" but `recommend`'s default mode is 'no'. A face
       photo, a filled round seal (bbox fill ~0.785) or a black table header all
       satisfy the size/ratio/fill test, and this path has zero golden coverage.
       It is now `optional` / mode 'ok'.
    
    3. Multi-page used page 1's class for every page, so a two-sided card scanned
       into one PDF came out opposite depending on scan ORDER. Findings now carry
       their own page's doc/side; the whole-face band is applied per back-face page.
    
    4. Unticking the catch-all "その他" category removed the マイナカード裏面 band
       and the 資格確認書 QR band from the output with no warning. Statutory bands
       now carry a `legal` flag, bypass the category checkboxes, live in their own
       「法令・提出先ルール」 group, and can only be released one item at a time.
    
    Legal matrix (jp_legal_matrix_alpha4.json v2026-10-21b) is now the single
    source: new `fields` / `optional_when` / `general_jp` / `_schema`, and
    test/safe/check_matrix.mjs derives every (doc, field, purpose) from it, extracts
    JP_RULES out of index.html, and fails on any disagreement — run.mjs calls it
    first. It also enforces `verified:false ⇒ never auto/gate`. Level changes that
    follow: 免許証番号 → keep for identity_submit, 住民票コード → recommend (no
    source), 本籍/筆頭者 → optional for two purposes, and an unnamed combination is
    now `null` (not offered) instead of silently `optional`.
    
    Releasing a 個人番号 band now needs the purpose AND a confirmation checkbox; the
    裏面 notice was softened in four languages; the check-digit citation is fixed to
    e-Gov 関連命令 第5条 (the arithmetic was always right).
    
    Harness: number fields are checked per ink connected component (60% area says
    how much, never where — the recorded 96%-but-leaking case fails this), a missing
    expectation key is a FAIL rather than a reported skip, `keep:"all"` enumerates,
    `require_banded` checks located+isOn, and an auto-field allowlist catches
    "right count, wrong entities". New coverage for a VALID 個人番号 (every card
    dummy carries an invalid one by design, so that branch had never run).
    
    Two harness defects of my own, found and fixed here: __allCatsOff() leaked
    global catEnabled into every later document (14 red, 11 of them unrelated), and
    `pages.length > 0` is not "loaded" on a multi-page OCR document.
    
    Not deployed. Production DB untouched.
    
    Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>

diff --git a/docs/jp/codex_review_s3_2026-10-21.md b/docs/jp/codex_review_s3_2026-10-21.md
new file mode 100644
index 0000000..eac2e75
--- /dev/null
+++ b/docs/jp/codex_review_s3_2026-10-21.md
@@ -0,0 +1,4939 @@
+warning: `--full-auto` is deprecated; use `--sandbox workspace-write` instead.
+2026-10-21T00:56:07.923204Z ERROR codex_models_manager::cache: failed to load models cache: missing field `base_instructions` at line 139 column 5
+OpenAI Codex v0.146.0
+--------
+workdir: /Users/sunghoon/Projects/docpack
+model: gpt-5.6-sol
+provider: openai
+approval: never
+sandbox: workspace-write [workdir, /tmp, $TMPDIR]
+reasoning effort: none
+reasoning summaries: none
+session id: 01a15bf5-59d7-77c3-bcf8-3596a099aaa2
+--------
+user
+당신은 브라우저 내 문서 마스킹 파이프라인과 일본 개인정보 실무에 정통한 독립 검토자입니다. 아래 커밋을 작성한 Claude와 **독립적으로** 비판적 검토를 하세요. 칭찬은 생략하고 **틀린 것·빠진 것·위험한 것만** 쓰세요. 각 항목은 "문제 / 근거(파일:줄) / 수정안" 형식이고, 근거를 못 찾으면 **"확인 불가"** 라고 명시하세요. 추측을 근거처럼 쓰지 마세요.
+
+## 검토 대상
+
+```
+git show 546344b --stat
+git show 546344b -- public/safe/index.html
+```
+
+- 변경 diff 전체 (커밋 `546344b`)
+- 구현: `public/safe/index.html` — 특히 `jpNorm` / `jpSegments` / `jpClassify` / `jpExtract` / `jpFrameBelow` / `jpCodeBlocks` / `jpSolidSquares` / `jpAddressSpan` / `myNumberCheckOk` / `JP_RULES` / `jpLevel` / `jpApply` / `bandRect` / `drawRedactions` / `ocrCanvas`
+- 하네스: `test/safe/run.mjs`, `test/safe/specs.json` (`jp_docs`·`jp_units`·`jp_auto_fields`)
+- 법적 정본: `test/safe/fixtures/jp/jp_legal_matrix_alpha4.json`
+- 픽스처 기대값: `test/safe/fixtures/jp/*/*.specs.json`
+- 전략: `docs/jp/jp_safefile_strategy_v2_2026-10-21.md` §3 제품 요구사항 · §4 더미 안전조건 · §7 게이트
+- 구현자 자술: `docs/jp/s3_report.md` · 전체 통과 로그 `docs/jp/s3_golden_result.md`
+
+실행 환경 참고: `cd test/safe && npm install && node run.mjs` (Chrome 필요, 네트워크로 Tesseract.js·pdf.js CDN 접근). 돌릴 수 없으면 **정적 검토만 하고 그렇다고 적으세요** — 테스트를 돌린 것처럼 쓰지 마세요.
+
+## 1. 탐지의 **미탐** 위험 (가장 중요)
+
+이 제품의 가장 비싼 실패는 가려야 할 번호가 안 가려지는 것입니다.
+
+1-1. `jpClassify` 가 **분류에 실패하면 일본 자동 마스킹이 전부 꺼진다**(`jpScan` → `jpApply`). 임계값 4와 키워드 가중치는 알파 11개 픽스처로만 조정됐습니다. 실제 보험자별 양식·지자체 양식에서 분류가 떨어질 조합이 있습니까? 분류 실패를 **사용자가 알 수 있습니까?**
+
+1-2. `JP_SEG_GAP = max(90, 페이지폭 × 0.10)`. 레이블–값 간격이 이보다 넓거나 칸–칸 간격이 이보다 좁은 실제 양식이 있으면 레이블 앵커가 통째로 끊깁니다. 어떤 조건에서 깨집니까?
+
+1-3. 모든 값 규칙이 **세그먼트 선두 앵커**(`headOnly: true`)입니다. 레이블 앞에 기호·번호·OCR 잡음 한 글자가 붙는 실제 양식에서 전부 미탐이 됩니다. 이 가드가 과한가요, 아니면 대안이 있습니까?
+
+1-4. `資格確認書` 의 6~10자리 구조 폴백과 `住民票` 의 11/12자리 폴백은 **날짜 줄 제외 + 길이**만 봅니다. 실제 양식에서 이 조건을 통과하는 **가려서는 안 될** 숫자열이 있습니까? (`一部負担金割合`, `自己負担限度額区分`, 발행번호, 証明書番号 등)
+
+1-5. `myNumberCheckOk` 를 番号法施行令 별표와 대조해 주세요. 가중치 Q_n·검사식·`≥10→0` 처리가 맞습니까? **틀렸다면 유효한 個人番号가 후보로만 뜨거나 그 반대가 됩니다.**
+
+1-6. 세대원 블록 경계를 `氏名` 레이블 행으로 잡고, 마지막 블록을 `この写し|相違|証明し|市長|区長|町長|村長|公印` 로 끊습니다. 실제 住民票 레이아웃에서 이 경계가 틀려 **제3자 정보가 남거나 발행자가 가려지는** 경우는?
+
+## 2. 탐지의 **오탐** 위험 — 필수 증빙 훼손
+
+2-1. `jpFrameBelow` (150px 이상 연속 잉크 가로줄 + x범위 ±12px, 레이블 높이 12배 이내). 표·괘선이 많은 양식에서 엉뚱한 사각형을 잡아 **필수 기재사항을 덮을** 경우는? `jpRowInk` 가 행당 **가장 긴 런 하나만** 보는 것이 맞습니까?
+
+2-2. `jpSolidSquares` (16px 셀, 밀도 ≥0.6, 면적 ≥60px, 종횡비 0.8~1.25, 채움 ≥0.75). **顔写真**·인감·로고·검은 표 헤더가 이 조건을 통과합니까? 통과하면 `labelled:false` → candidate 로만 뜨지만, **그 candidate 의 기본 모드가 목적에 따라 `no`(= 기본 ON) 가 되는 경로가 있습니까?**
+
+2-3. `jpAddressSpan` 의 기관명 **감점 −2** 와 임계 3. 실제 주소 뒤에 회사명이 붙은 줄에서 주소가 통째로 사라지거나(미탐), 반대로 회사 소재지가 **자동** 띠가 되는(오탐) 경계가 어디입니까? `郵便番号+都道府県 동반 → 자동` 이 과합니까?
+
+2-4. `bandRect` 의 15% 패딩이 **빽빽한 양식에서 이웃 필드를 덮을** 수 있습니까? `region:true` 를 패딩에서 제외한 판단은 맞습니까?
+
+## 3. 출력 안전성의 **완전성**
+
+3-1. `TEXT_LEAK`(추출 문자 0) + 바이트 스캔(`/Annots` `/EmbeddedFile` `/XFA` `/AcroForm` `/Names`, 이미지 EXIF/XMP/IPTC) + `%%EOF` 1개. **이 목록이 충분합니까?** jsPDF 2.5.1 가 만드는 PDF에서 원본이 남을 다른 경로(XObject 메타, `/Metadata` XMP 스트림, 문서 정보 사전, 압축 객체 스트림 안의 문자열)가 있습니까?
+
+3-2. 입력 PDF 의 **주석·첨부·북마크·XMP** 가 출력으로 새는 경로가 정말 없습니까? (`composePage` 는 래스터를 다시 그리고 jsPDF 가 새 문서를 만듭니다 — 이 논증이 맞는지 확인해 주세요.)
+
+3-3. ICC 를 금지하지 않고 **크기 2KB + `dmnd`/`dmdd` 태그**로 경계 지은 판단이 타당합니까? 디스플레이 프로파일이 그 조건을 피해 나갈 수 있습니까?
+
+3-4. PNG 출력에 `eXIf/tEXt/zTXt/iTXt` 만 봅니다. 다른 보조 청크로 데이터가 실릴 수 있습니까?
+
+## 4. 목적 게이트 논리
+
+4-1. `JP_RULES` 를 `jp_legal_matrix_alpha4.json` 과 **한 줄씩 대조**해 주세요. 불일치·누락이 있습니까?
+
+4-2. `jpLevel` 의 **폴백이 항상 `optional`** 입니다. 매트릭스가 그 목적을 명시하지 않은 필드를 "제공하되 꺼둠" 으로 떨어뜨리는 것이 맞습니까, 아니면 `keep` 쪽으로 가야 하는 경우가 있습니까? 특히 **`資格確認書` 의 ID 계열이 `my_number_procedure` 에서 `optional`(기본 OFF)** 이 되는데, 그 조합이 실무에서 발생합니까?
+
+4-3. 의도적 매트릭스 이탈 1건: `本籍`/`筆頭者` 에 `my_number_procedure`·`bid_attachment` 를 추가(level 은 `recommend` 유지). 근거가 충분합니까?
+
+4-4. `マイナカード裏面 + 本人確認 → 면 전체 띠` 와 안내문. 番号法상 정확합니까? **個人番号手続 선택 시 해제**가 올바른 동작입니까?
+
+4-5. `keep` 항목을 사용자가 가릴 수 있게 두고 **경고만** 하는 설계. 개별 토글과 일괄 비공개 양쪽에 경고가 있습니다. 차단해야 할 경우가 있습니까?
+
+4-6. `JP_TYPE` 이 JP 필드를 기존 카테고리에 매핑합니다(`back_all`·`qr` → `other`). **사용자가 `その他` 카테고리 체크박스를 끄면 법적 근거로 걸린 띠가 사라집니다**(`isOn`). 이것이 허용돼야 합니까?
+
+## 5. 하네스가 **진짜로** 검증하는가
+
+5-1. `jp_auto_fields` 가 "어떤 단언을 쓸지" 를 결정합니다. 이 표가 매트릭스 `level` 과 어긋나면 **골든이 틀린 동작을 통과시킵니다.** 대조해 주세요.
+
+5-2. `JP_MASK_OR_CAND`(個人番号) — 띠 **또는** 후보면 통과. 이 느슨함이 실제 회귀를 숨길 수 있습니까? 체크디지트가 **유효한** 個人番号가 자동 띠가 되는지는 어디서 검증됩니까? (현재 픽스처는 전부 불일치입니다.)
+
+5-3. 박스 피복 기준: 박스 안에 텍스트 아이템이 있으면 **각 아이템 ≥60%**, 없으면 **면적 ≥60%**, `keep` 은 **≤10%**. 60% 가 "판독 불가" 를 보장합니까? 숫자 하나가 60% 덮여도 읽힐 수 있습니까?
+
+5-4. `geometry:false` (jpg 3건 + consult_share 1건)는 좌표 단언을 **건너뜁니다.** 이 면제가 숨기는 회귀가 있습니까?
+
+5-5. **공허한 단언이 남아 있습니까?** 특히 `JP_COVERAGE`·`JP_CLEAR`·`JP_OPTIONAL`·`require_banded` 가 조건을 만족하지 못해도 통과하는 경로가 있는지 보세요.
+
+5-6. `max_auto` 상한값(kenpo 8 등)이 **실측 + 여유** 인지, 아니면 회귀를 통과시킬 만큼 느슨한지.
+
+## 6. 커버리지가 없는 구현
+
+구현자가 스스로 올린 공백입니다. **등급이 맞는지, 더 있는지** 판정해 주세요.
+
+6-1. **레이블 없는 QR/바코드** — 픽스처·유닛 둘 다 없음. candidate 고정이 충분한 완화입니까?
+6-2. **電話·FAX** — `jp_units` 6건만. 레이블 앵커 → 박스 변환 경로가 한 번도 실행된 적 없습니다.
+6-3. **住所 `郵便番号+都道府県 → 자동`** — 유닛에서만 참. 실제 문서로 본 적 없습니다.
+6-4. **多ページ 일본 문서** — 2페이지 이후 분류 상속(`jpScan`) 경로 미실행.
+6-5. `jpPageBg` 가 페이지 **테두리 24점의 중앙값**을 배경으로 씁니다. 어두운 배경·전면 컬러 양식에서 `jpFrameBelow`·`jpSolidSquares` 가 어떻게 됩니까?
+
+## 7. 공개 저장소 + 카드 더미 (사람 결정 대기)
+
+`chaop2026/docpack` 은 **PUBLIC** 이고, 전략 §4 는 카드 더미를 **법률 검토 전까지 내부 전용**으로 묶어 뒀습니다. 커밋은 그 보류를 사실상 해제합니다. 구현자의 판단과 완화 조치는 `CLAUDE.md` 의 「JP-1 이슈 로그」에 있습니다.
+
+7-1. `test/safe/fixtures/jp/` 의 더미가 §4 의 **생성 안전조건을 전부** 충족합니까? 빠진 조건이 있습니까?
+7-2. 공개 저장소 커밋의 실질 위험을 어떻게 평가합니까? (오용 가치 / 일본 법 / GitHub 이용약관)
+7-3. 대안(비공개 서브모듈 / 생성 스크립트만 커밋 / 해상도 축소)의 실현성과 비용.
+
+---
+
+마지막에 **"즉시 고쳐야 할 상위 5개"** 를 우선순위로 요약하고, 각각에 **AMBER/GREEN** 등급과 "배포 전/다음 런" 을 붙이세요. 일본어 고유명사는 그대로 두고, 답변은 **한국어**로. **파일을 수정하지 말고 검토 결과만 출력**하세요.
+warning: Skill descriptions were shortened to fit the 2% skills context budget. Codex can still see every skill, but some descriptions are shorter. Disable unused skills or plugins to leave more room for the rest.
+hook: SessionStart
+hook: SessionStart Completed
+hook: UserPromptSubmit
+hook: UserPromptSubmit Completed
+codex
+요청하신 형식대로 독립 정적·동적 검토를 하겠습니다. 먼저 저장소 지침과 지정 커밋 전체를 읽고, 법적 정본·전략·하네스·픽스처를 상호 대조한 뒤 가능하면 실제 하네스를 실행하겠습니다. 파일은 수정하지 않습니다.
+codex
+코드 구조를 빠짐없이 추적하기 위해 `claude-mem:smart-explore` 스킬을 사용하겠습니다. 이 스킬은 함수·호출 관계를 구조적으로 찾는 데 쓰되, 최종 판단은 실제 diff와 원문 줄을 직접 대조해 내리겠습니다.
+hook: PreToolUse
+hook: PreToolUse Completed
+exec
+/bin/zsh -lc "sed -n '1,240p' /Users/sunghoon/.codex/plugins/cache/claude-mem-local/claude-mem/13.8.1/skills/smart-explore/SKILL.md" in /Users/sunghoon/Projects/docpack
+ succeeded in 0ms:
+---
+name: smart-explore
+description: Token-optimized structural code search using tree-sitter AST parsing. Use instead of reading full files when you need to understand code structure, find functions, or explore a codebase efficiently.
+---
+
+# Smart Explore
+
+Structural code exploration using AST parsing. **This skill overrides your default exploration behavior.** While this skill is active, use smart_search/smart_outline/smart_unfold as your primary tools instead of Read, Grep, and Glob.
+
+**Core principle:** Index first, fetch on demand. Give yourself a map of the code before loading implementation details. The question before every file read should be: "do I need to see all of this, or can I get a structural overview first?" The answer is almost always: get the map.
+
+## Your Next Tool Call
+
+This skill only loads instructions. You must call the MCP tools yourself. Your next action should be one of:
+
+```
+smart_search(query="<topic>", path="./src")    -- discover files + symbols across a directory
+smart_outline(file_path="<file>")              -- structural skeleton of one file
+smart_unfold(file_path="<file>", symbol_name="<name>")  -- full source of one symbol
+```
+
+Do NOT run Grep, Glob, Read, or find to discover files first. `smart_search` walks directories, parses all code files, and returns ranked symbols in one call. It replaces the Glob → Grep → Read discovery cycle.
+
+## 3-Layer Workflow
+
+### Step 1: Search -- Discover Files and Symbols
+
+```
+smart_search(query="shutdown", path="./src", max_results=15)
+```
+
+**Returns:** Ranked symbols with signatures, line numbers, match reasons, plus folded file views (~2-6k tokens)
+
+```
+-- Matching Symbols --
+  function performGracefulShutdown (services/infrastructure/GracefulShutdown.ts:56)
+  function httpShutdown (services/infrastructure/HealthMonitor.ts:92)
+  method WorkerService.shutdown (services/worker-service.ts:846)
+
+-- Folded File Views --
+  services/infrastructure/GracefulShutdown.ts (7 symbols)
+  services/worker-service.ts (12 symbols)
+```
+
+This is your discovery tool. It finds relevant files AND shows their structure. No Glob/find pre-scan needed.
+
+**Parameters:**
+
+- `query` (string, required) -- What to search for (function name, concept, class name)
+- `path` (string) -- Root directory to search (defaults to cwd)
+- `max_results` (number) -- Max matching symbols, default 20, max 50
+- `file_pattern` (string, optional) -- Filter to specific files/paths
+
+### Step 2: Outline -- Get File Structure
+
+```
+smart_outline(file_path="services/worker-service.ts")
+```
+
+**Returns:** Complete structural skeleton -- all functions, classes, methods, properties, imports (~1-2k tokens per file)
+
+**Skip this step** when Step 1's folded file views already provide enough structure. Most useful for files not covered by the search results.
+
+**Parameters:**
+
+- `file_path` (string, required) -- Path to the file
+
+### Step 3: Unfold -- See Implementation
+
+Review symbols from Steps 1-2. Pick the ones you need. Unfold only those:
+
+```
+smart_unfold(file_path="services/worker-service.ts", symbol_name="shutdown")
+```
+
+**Returns:** Full source code of the specified symbol including JSDoc, decorators, and complete implementation (~400-2,100 tokens depending on symbol size). AST node boundaries guarantee completeness regardless of symbol size — unlike Read + agent summarization, which may truncate long methods.
+
+**Parameters:**
+
+- `file_path` (string, required) -- Path to the file (as returned by search/outline)
+- `symbol_name` (string, required) -- Name of the function/class/method to expand
+
+## When to Use Standard Tools Instead
+
+Use these only when smart_* tools are the wrong fit:
+
+- **Grep:** Exact string/regex search ("find all TODO comments", "where is `ensureWorkerStarted` defined?")
+- **Read:** Small files under ~100 lines, non-code files (JSON, markdown, config)
+- **Glob:** File path patterns ("find all test files")
+- **Explore agent:** When you need synthesized understanding across 6+ files, architecture narratives, or answers to open-ended questions like "how does this entire system work end-to-end?" Smart-explore is a scalpel — it answers "where is this?" and "show me that." It doesn't synthesize cross-file data flows, design decisions, or edge cases across an entire feature.
+
+For code files over ~100 lines, prefer smart_outline + smart_unfold over Read.
+
+## Workflow Examples
+
+**Discover how a feature works (cross-cutting):**
+
+```
+1. smart_search(query="shutdown", path="./src")
+   -> 14 symbols across 7 files, full picture in one call
+2. smart_unfold(file_path="services/infrastructure/GracefulShutdown.ts", symbol_name="performGracefulShutdown")
+   -> See the core implementation
+```
+
+**Navigate a large file:**
+
+```
+1. smart_outline(file_path="services/worker-service.ts")
+   -> 1,466 tokens: 12 functions, WorkerService class with 24 members
+2. smart_unfold(file_path="services/worker-service.ts", symbol_name="startSessionProcessor")
+   -> 1,610 tokens: the specific method you need
+Total: ~3,076 tokens vs ~12,000 to Read the full file
+```
+
+**Write documentation about code (hybrid workflow):**
+
+```
+1. smart_search(query="feature name", path="./src")    -- discover all relevant files and symbols
+2. smart_outline on key files                           -- understand structure
+3. smart_unfold on important functions                  -- get implementation details
+4. Read on small config/markdown/plan files             -- get non-code context
+```
+
+Use smart_* tools for code exploration, Read for non-code files. Mix freely.
+
+**Exploration then precision:**
+
+```
+1. smart_search(query="session", path="./src", max_results=10)
+   -> 10 ranked symbols: SessionMetadata, SessionQueueProcessor, SessionSummary...
+2. Pick the relevant one, unfold it
+```
+
+## Token Economics
+
+| Approach | Tokens | Use Case |
+|----------|--------|----------|
+| smart_outline | ~1,000-2,000 | "What's in this file?" |
+| smart_unfold | ~400-2,100 | "Show me this function" |
+| smart_search | ~2,000-6,000 | "Find all X across the codebase" |
+| search + unfold | ~3,000-8,000 | End-to-end: find and read (the primary workflow) |
+| Read (full file) | ~12,000+ | When you truly need everything |
+| Explore agent | ~39,000-59,000 | Cross-file synthesis with narrative |
+
+**4-8x savings** on file understanding (outline + unfold vs Read). **11-18x savings** on codebase exploration vs Explore agent. The narrower the query, the wider the gap — a 27-line function costs 55x less to read via unfold than via an Explore agent, because the agent still reads the entire file.
+
+## Language Support
+
+Smart-explore uses **tree-sitter AST parsing** for structural analysis. Unsupported file types fall back to text-based search.
+
+### Bundled Languages
+
+| Language | Extensions |
+|----------|-----------|
+| JavaScript | `.js`, `.mjs`, `.cjs` |
+| TypeScript | `.ts` |
+| TSX / JSX | `.tsx`, `.jsx` |
+| Python | `.py`, `.pyw` |
+| Go | `.go` |
+| Rust | `.rs` |
+| Ruby | `.rb` |
+| Java | `.java` |
+| C | `.c`, `.h` |
+| C++ | `.cpp`, `.cc`, `.cxx`, `.hpp`, `.hh` |
+
+Files with unrecognized extensions are parsed as plain text — `smart_search` still works (grep-style), but `smart_outline` and `smart_unfold` will not extract structured symbols.
+
+### Custom Grammars (`.claude-mem.json`)
+
+You can register additional tree-sitter grammars for file types not in the bundled list. Create or update `.claude-mem.json` in your project root:
+
+```json
+{
+  "grammars": {
+    "solidity": {
+      "package": "tree-sitter-solidity",
+      "extensions": [".sol"],
+      "query": "solidity-query.scm"
+    }
+  }
+}
+```
+
+Each key is a language name. `package` is the npm package of the tree-sitter grammar and `extensions` lists the file extensions it covers; the package must be installed in the project's `node_modules` (`npm install tree-sitter-solidity`). `query` (optional) is a path, relative to the config file, to a tree-sitter query whose captures (`@func`, `@cls`, `@method`, `@iface`, `@enm`, `@struct_def`, `@imp`) extract symbols. Without `query`, a minimal generic pattern is used — it only matches grammars that define `function_declaration`/`class_declaration` node types, and query compilation fails silently (0 symbols) for grammars that lack them, so a custom query is effectively required for most languages. Once registered, `smart_outline` and `smart_unfold` parse those extensions structurally instead of falling back to plain text.
+
+### Markdown Special Support
+
+Markdown files (`.md`, `.mdx`) receive special handling beyond the generic plain-text fallback:
+
+- **`smart_outline`** — extracts headings (`#`, `##`, `###`) as the symbol tree. Use it to navigate long documents without reading the full file.
+- **`smart_search`** — searches within code fences as well as prose, so queries for function names inside ` ```ts ``` ` blocks work as expected.
+- **`smart_unfold`** — expands heading sections rather than function bodies; each section up to the next same-level heading is returned as a chunk.
+- **Frontmatter** — YAML frontmatter (lines between leading `---` delimiters) is included in `smart_outline` output under a synthetic `frontmatter` symbol so metadata like `title:` and `description:` is visible without reading the whole file.
+
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+mcp: mcp-search/smart_search started
+hook: PermissionRequest
+hook: PermissionRequest Completed
+mcp: mcp-search/smart_search (failed)
+user cancelled MCP tool call
+codex
+구조 검색 도구 호출이 취소되어 저장소의 읽기 전용 Git/텍스트 명령으로 전환합니다. 검토 범위나 증거 기준에는 영향이 없으며, 모든 지적은 현재 커밋의 정확한 줄 번호에 고정하겠습니다.
+hook: PreToolUse
+hook: PreToolUse Completed
+exec
+/bin/zsh -lc 'git status --short && git show --stat --oneline 546344b && git show --format= --name-only 546344b' in /Users/sunghoon/Projects/docpack
+ succeeded in 24ms:
+546344b feat(safe): JP-1 alpha — Japanese document presets, purpose gate, band-only masking
+ .gitignore                                         |    7 +
+ CLAUDE.md                                          |   90 +
+ docs/jp/codex_prompt.md                            |    9 +
+ docs/jp/codex_review_2026-10-21.md                 | 1924 ++++++++++++++++++++
+ docs/jp/jp_documents_catalog.json                  |   95 +
+ docs/jp/jp_safefile_strategy_2026-10-20.md         |  175 ++
+ docs/jp/jp_safefile_strategy_v2_2026-10-21.md      |  191 ++
+ docs/jp/s3_golden_result.md                        |  589 ++++++
+ docs/jp/s3_report.md                               |  338 ++++
+ public/safe/index.html                             |  893 ++++++++-
+ test/safe/README.md                                |   81 +-
+ test/safe/fixtures/jp/README.md                    |   43 +
+ test/safe/fixtures/jp/gen.py                       |  214 +++
+ test/safe/fixtures/jp/jp_legal_matrix_alpha4.json  |   62 +
+ test/safe/fixtures/jp/juminhyo/gaikokujin.jpg      |  Bin 0 -> 150558 bytes
+ test/safe/fixtures/jp/juminhyo/gaikokujin.pdf      |   79 +
+ test/safe/fixtures/jp/juminhyo/gaikokujin.png      |  Bin 0 -> 379659 bytes
+ .../fixtures/jp/juminhyo/gaikokujin.specs.json     |  102 ++
+ test/safe/fixtures/jp/juminhyo/honseki_on.jpg      |  Bin 0 -> 144256 bytes
+ test/safe/fixtures/jp/juminhyo/honseki_on.pdf      |   79 +
+ test/safe/fixtures/jp/juminhyo/honseki_on.png      |  Bin 0 -> 364680 bytes
+ .../fixtures/jp/juminhyo/honseki_on.specs.json     |   95 +
+ test/safe/fixtures/jp/juminhyo/ichibu_plain.jpg    |  Bin 0 -> 141753 bytes
+ test/safe/fixtures/jp/juminhyo/ichibu_plain.pdf    |   79 +
+ test/safe/fixtures/jp/juminhyo/ichibu_plain.png    |  Bin 0 -> 354262 bytes
+ .../fixtures/jp/juminhyo/ichibu_plain.specs.json   |   78 +
+ test/safe/fixtures/jp/juminhyo/zenin_mynumber.jpg  |  Bin 0 -> 186391 bytes
+ test/safe/fixtures/jp/juminhyo/zenin_mynumber.pdf  |   79 +
+ test/safe/fixtures/jp/juminhyo/zenin_mynumber.png  |  Bin 0 -> 445840 bytes
+ .../fixtures/jp/juminhyo/zenin_mynumber.specs.json |  230 +++
+ test/safe/fixtures/jp/mynumber_card/back.jpg       |  Bin 0 -> 70108 bytes
+ test/safe/fixtures/jp/mynumber_card/back.pdf       |   79 +
+ test/safe/fixtures/jp/mynumber_card/back.png       |  Bin 0 -> 205908 bytes
+ .../safe/fixtures/jp/mynumber_card/back.specs.json |   54 +
+ test/safe/fixtures/jp/mynumber_card/front.jpg      |  Bin 0 -> 77758 bytes
+ test/safe/fixtures/jp/mynumber_card/front.pdf      |   79 +
+ test/safe/fixtures/jp/mynumber_card/front.png      |  Bin 0 -> 213113 bytes
+ .../fixtures/jp/mynumber_card/front.specs.json     |   72 +
+ test/safe/fixtures/jp/shikaku_kakuninsho/kenpo.jpg |  Bin 0 -> 84735 bytes
+ test/safe/fixtures/jp/shikaku_kakuninsho/kenpo.pdf |   79 +
+ test/safe/fixtures/jp/shikaku_kakuninsho/kenpo.png |  Bin 0 -> 233815 bytes
+ .../jp/shikaku_kakuninsho/kenpo.specs.json         |  119 ++
+ .../safe/fixtures/jp/shikaku_kakuninsho/kokuho.jpg |  Bin 0 -> 83924 bytes
+ .../safe/fixtures/jp/shikaku_kakuninsho/kokuho.pdf |   79 +
+ .../safe/fixtures/jp/shikaku_kakuninsho/kokuho.png |  Bin 0 -> 226721 bytes
+ .../jp/shikaku_kakuninsho/kokuho.specs.json        |  113 ++
+ test/safe/fixtures/jp/shikaku_kakuninsho/kouki.jpg |  Bin 0 -> 84181 bytes
+ test/safe/fixtures/jp/shikaku_kakuninsho/kouki.pdf |   79 +
+ test/safe/fixtures/jp/shikaku_kakuninsho/kouki.png |  Bin 0 -> 233773 bytes
+ .../jp/shikaku_kakuninsho/kouki.specs.json         |  101 +
+ test/safe/fixtures/jp/unten_menkyo/back.jpg        |  Bin 0 -> 82146 bytes
+ test/safe/fixtures/jp/unten_menkyo/back.pdf        |   79 +
+ test/safe/fixtures/jp/unten_menkyo/back.png        |  Bin 0 -> 218850 bytes
+ test/safe/fixtures/jp/unten_menkyo/back.specs.json |   35 +
+ test/safe/fixtures/jp/unten_menkyo/front.jpg       |  Bin 0 -> 78601 bytes
+ test/safe/fixtures/jp/unten_menkyo/front.pdf       |   79 +
+ test/safe/fixtures/jp/unten_menkyo/front.png       |  Bin 0 -> 225041 bytes
+ .../safe/fixtures/jp/unten_menkyo/front.specs.json |   76 +
+ test/safe/package-lock.json                        |   42 +
+ test/safe/render.mjs                               |   68 +
+ test/safe/run.mjs                                  |  203 ++-
+ test/safe/specs.json                               |   95 +
+ test/sw/README.md                                  |   13 +-
+ 63 files changed, 7049 insertions(+), 27 deletions(-)
+.gitignore
+CLAUDE.md
+docs/jp/codex_prompt.md
+docs/jp/codex_review_2026-10-21.md
+docs/jp/jp_documents_catalog.json
+docs/jp/jp_safefile_strategy_2026-10-20.md
+docs/jp/jp_safefile_strategy_v2_2026-10-21.md
+docs/jp/s3_golden_result.md
+docs/jp/s3_report.md
+public/safe/index.html
+test/safe/README.md
+test/safe/fixtures/jp/README.md
+test/safe/fixtures/jp/gen.py
+test/safe/fixtures/jp/jp_legal_matrix_alpha4.json
+test/safe/fixtures/jp/juminhyo/gaikokujin.jpg
+test/safe/fixtures/jp/juminhyo/gaikokujin.pdf
+test/safe/fixtures/jp/juminhyo/gaikokujin.png
+test/safe/fixtures/jp/juminhyo/gaikokujin.specs.json
+test/safe/fixtures/jp/juminhyo/honseki_on.jpg
+test/safe/fixtures/jp/juminhyo/honseki_on.pdf
+test/safe/fixtures/jp/juminhyo/honseki_on.png
+test/safe/fixtures/jp/juminhyo/honseki_on.specs.json
+test/safe/fixtures/jp/juminhyo/ichibu_plain.jpg
+test/safe/fixtures/jp/juminhyo/ichibu_plain.pdf
+test/safe/fixtures/jp/juminhyo/ichibu_plain.png
+test/safe/fixtures/jp/juminhyo/ichibu_plain.specs.json
+test/safe/fixtures/jp/juminhyo/zenin_mynumber.jpg
+test/safe/fixtures/jp/juminhyo/zenin_mynumber.pdf
+test/safe/fixtures/jp/juminhyo/zenin_mynumber.png
+test/safe/fixtures/jp/juminhyo/zenin_mynumber.specs.json
+test/safe/fixtures/jp/mynumber_card/back.jpg
+test/safe/fixtures/jp/mynumber_card/back.pdf
+test/safe/fixtures/jp/mynumber_card/back.png
+test/safe/fixtures/jp/mynumber_card/back.specs.json
+test/safe/fixtures/jp/mynumber_card/front.jpg
+test/safe/fixtures/jp/mynumber_card/front.pdf
+test/safe/fixtures/jp/mynumber_card/front.png
+test/safe/fixtures/jp/mynumber_card/front.specs.json
+test/safe/fixtures/jp/shikaku_kakuninsho/kenpo.jpg
+test/safe/fixtures/jp/shikaku_kakuninsho/kenpo.pdf
+test/safe/fixtures/jp/shikaku_kakuninsho/kenpo.png
+test/safe/fixtures/jp/shikaku_kakuninsho/kenpo.specs.json
+test/safe/fixtures/jp/shikaku_kakuninsho/kokuho.jpg
+test/safe/fixtures/jp/shikaku_kakuninsho/kokuho.pdf
+test/safe/fixtures/jp/shikaku_kakuninsho/kokuho.png
+test/safe/fixtures/jp/shikaku_kakuninsho/kokuho.specs.json
+test/safe/fixtures/jp/shikaku_kakuninsho/kouki.jpg
+test/safe/fixtures/jp/shikaku_kakuninsho/kouki.pdf
+test/safe/fixtures/jp/shikaku_kakuninsho/kouki.png
+test/safe/fixtures/jp/shikaku_kakuninsho/kouki.specs.json
+test/safe/fixtures/jp/unten_menkyo/back.jpg
+test/safe/fixtures/jp/unten_menkyo/back.pdf
+test/safe/fixtures/jp/unten_menkyo/back.png
+test/safe/fixtures/jp/unten_menkyo/back.specs.json
+test/safe/fixtures/jp/unten_menkyo/front.jpg
+test/safe/fixtures/jp/unten_menkyo/front.pdf
+test/safe/fixtures/jp/unten_menkyo/front.png
+test/safe/fixtures/jp/unten_menkyo/front.specs.json
+test/safe/package-lock.json
+test/safe/render.mjs
+test/safe/run.mjs
+test/safe/specs.json
+test/sw/README.md
+
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+exec
+/bin/zsh -lc 'git rev-parse --short HEAD && git diff -- public/safe/index.html test/safe/run.mjs test/safe/specs.json docs/jp/jp_safefile_strategy_v2_2026-10-21.md docs/jp/s3_report.md docs/jp/s3_golden_result.md test/safe/fixtures/jp/jp_legal_matrix_alpha4.json && rg -n "function (jpNorm|jpSegments|jpClassify|jpExtract|jpFrameBelow|jpCodeBlocks|jpSolidSquares|jpAddressSpan|myNumberCheckOk|jpLevel|jpApply|bandRect|drawRedactions|ocrCanvas)|const (JP_RULES|JP_SEG_GAP|JP_TYPE)|jpScan" public/safe/index.html' in /Users/sunghoon/Projects/docpack
+ succeeded in 0ms:
+0238cbb
+1081:function jpNorm(s){
+1115:const JP_SEG_GAP = p => Math.max(90, p.w * 0.10);
+1123:function jpSegments(pi){
+1185:function jpClassify(pi){
+1205:function myNumberCheckOk(d12){
+1252:function jpFrameBelow(page, anchor){
+1283:function jpCodeBlocks(pi){
+1334:function jpSolidSquares(page, pi){
+1388:const JP_RULES = {
+1433:function jpLevel(doc, field, purpose){
+1542:function jpAddressSpan(t, from){
+1598:function jpExtract(pi, cls){
+1778:function jpScan(){
+1796:function jpApply(){
+1835:const JP_TYPE = { address_loose:'address', tel:'phone', my_number:'rrn', jumin_code:'rrn', hokensha_bango:'health', kigo:'health',
+2092:async function ocrCanvas(cv){
+2151:    const jp = jpScan();
+2292:function bandRect(l){
+2324:function drawRedactions(ctx,pi,scale){
+
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+exec
+/bin/zsh -lc 'git diff --stat 546344b..HEAD -- public/safe/index.html test/safe/run.mjs test/safe/specs.json docs/jp/jp_safefile_strategy_v2_2026-10-21.md docs/jp/s3_report.md docs/jp/s3_golden_result.md test/safe/fixtures/jp && git diff --numstat 546344b..HEAD -- public/safe/index.html test/safe/run.mjs test/safe/specs.json' in /Users/sunghoon/Projects/docpack
+ succeeded in 0ms:
+ public/safe/index.html | 10 +++++++---
+ 1 file changed, 7 insertions(+), 3 deletions(-)
+7	3	public/safe/index.html
+
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+exec
+/bin/zsh -lc "git show 546344b:public/safe/index.html | nl -ba | sed -n '1060,1865p'" in /Users/sunghoon/Projects/docpack
+ succeeded in 0ms:
+  1060	     (1) the page classifies as one of the four alpha document types,
+  1061	     (2) a label anchor in the same visual row — or one documented, narrower
+  1062	         structural fallback for the case where OCR destroyed the label,
+  1063	     (3) the value matches the field's format (and, for 個人番号, its check digit).
+  1064	   Everything short of that surfaces as a review candidate instead.
+  1065	   The asymmetry is deliberate: a missed 保険者番号 is the exact harm the
+  1066	   product exists to prevent, while a wrongly banded 氏名 gets the submission
+  1067	   rejected — so automatic banding is confined to the fields the legal matrix
+  1068	   says may be hidden for the selected purpose. */
+  1069	
+  1070	/* ── normalisation with index preservation ──
+  1071	   Boxes come from item/char indices, so normalisation must never lose the way
+  1072	   back to the source character. Each SOURCE character is normalised on its own
+  1073	   (never a whole string), so NFKC can expand 1→n but can never combine n→1 and
+  1074	   silently drop a source index. Folds that are not 1:1 are simply not applied. */
+  1075	const JP_VARIANT = {'髙':'高','﨑':'崎','邊':'辺','邉':'辺'};
+  1076	const JP_DASH = new Set(['ー','−','―','‐','—','－','ｰ','‑','–','_']);
+  1077	const JP_ZERO = new Set(['〇','○','◯']);
+  1078	const JP_ONE  = new Set(['l','I','|','ｌ','Ｉ','丨']);
+  1079	const isDigit = c => c >= '0' && c <= '9';
+  1080	// Returns {t, src} — t[k] is the k-th normalised char, src[k] its index in `s`.
+  1081	function jpNorm(s){
+  1082	  let t = '', src = [];
+  1083	  for (let i = 0; i < (s||'').length; i++){
+  1084	    let o = s[i];
+  1085	    try { o = o.normalize('NFKC'); } catch(e){}
+  1086	    if (o.length !== 1) { // expansion: every output char points back at this source char
+  1087	      for (const c of o) { t += (JP_VARIANT[c] || c); src.push(i); }
+  1088	      continue;
+  1089	    }
+  1090	    t += (JP_VARIANT[o] || o); src.push(i);
+  1091	  }
+  1092	  // Context-sensitive OCR folds, applied in place so the map stays valid.
+  1093	  // ー→- unconditionally would wreck katakana (コード→コ-ド) and with it the
+  1094	  // 二次元コード label anchor, so these only fire next to a digit.
+  1095	  const a = t.split('');
+  1096	  for (let k = 0; k < a.length; k++){
+  1097	    const p = a[k-1], n = a[k+1];
+  1098	    const nearDigit = (p && isDigit(p)) || (n && isDigit(n));
+  1099	    if (JP_DASH.has(a[k]) && nearDigit) a[k] = '-';
+  1100	    else if (JP_ZERO.has(a[k]) && nearDigit) a[k] = '0';
+  1101	    else if (JP_ONE.has(a[k]) && p && n && isDigit(p) && isDigit(n)) a[k] = '1';
+  1102	  }
+  1103	  return { t: a.join(''), src };
+  1104	}
+  1105	
+  1106	/* ── row / segment model ──
+  1107	   These documents are label-value forms: the label sits left of its value on
+  1108	   the same visual row, and several label-value pairs share a row in separate
+  1109	   columns. So we group items into rows, then split each row into SEGMENTS at
+  1110	   horizontal gaps. The gap threshold has to be wider than a label→value gap
+  1111	   (~80px at this scale) and narrower than a column→column gap (~140px);
+  1112	   10% of page width sits between them for every alpha fixture.
+  1113	   `rowText` keeps the WHOLE visual line, because date context ("年月日") has to
+  1114	   be judged per line, not per column. */
+  1115	const JP_SEG_GAP = p => Math.max(90, p.w * 0.10);
+  1116	function jpPushItem(seg, o){
+  1117	  const n = jpNorm(o.it.str || '');
+  1118	  seg.start[o.i] = seg.t.length;              // where this item's chars begin in seg.t
+  1119	  for (let k = 0; k < n.t.length; k++){ seg.t += n.t[k]; seg.map.push([o.i, n.src[k]]); }
+  1120	  seg.x1 = Math.max(seg.x1, o.it.x + o.it.w);
+  1121	  seg.items.push(o);
+  1122	}
+  1123	function jpSegments(pi){
+  1124	  const page = pages[pi];
+  1125	  if (page._jpsegs) return page._jpsegs;
+  1126	  const arr = page.items.map((it,i)=>({it,i})).sort((a,b)=>a.it.y-b.it.y||a.it.x-b.it.x);
+  1127	  const rows = []; let row = null;
+  1128	  for (const o of arr){
+  1129	    if (row && Math.abs(o.it.y - row.y) < row.h * 0.7){ row.list.push(o); row.h = Math.max(row.h, o.it.h); }
+  1130	    else { if (row) rows.push(row); row = { y:o.it.y, h:o.it.h, list:[o] }; }
+  1131	  }
+  1132	  if (row) rows.push(row);
+  1133	  const gapT = JP_SEG_GAP(page), segs = [];
+  1134	  rows.forEach((r, ri) => {
+  1135	    r.list.sort((a,b)=>a.it.x-b.it.x);
+  1136	    let rowText = ''; for (const o of r.list) rowText += jpNorm(o.it.str||'').t;
+  1137	    const y0 = Math.min(...r.list.map(o=>o.it.y)), y1 = Math.max(...r.list.map(o=>o.it.y+o.it.h));
+  1138	    let seg = null;
+  1139	    const open = o => ({ pi, row:ri, rowText, y:y0, h:y1-y0, x0:o.it.x, x1:o.it.x, t:'', map:[], items:[], used:[], start:{} });
+  1140	    for (const o of r.list){
+  1141	      if (seg && o.it.x - seg.x1 < gapT) jpPushItem(seg, o);
+  1142	      else { if (seg) segs.push(seg); seg = open(o); jpPushItem(seg, o); }
+  1143	    }
+  1144	    if (seg) segs.push(seg);
+  1145	  });
+  1146	  return (page._jpsegs = segs);
+  1147	}
+  1148	// Boxes for the normalised-text span [a,b) of a segment, via the char map.
+  1149	function jpBoxes(seg, a, b){
+  1150	  const out = [];
+  1151	  boxesFromRange(pages[seg.pi], seg.pi, seg.map, a, b, out);
+  1152	  return out;
+  1153	}
+  1154	function jpSegBox(seg){
+  1155	  const page = pages[seg.pi];
+  1156	  const b = { page: seg.pi, x: seg.x0, y: seg.y, w: seg.x1 - seg.x0, h: seg.h };
+  1157	  b.bg = sampleBg(page, b);
+  1158	  return b;
+  1159	}
+  1160	
+  1161	/* ── document classification ──
+  1162	   Weighted keyword vote over the whole page's normalised text. Weights express
+  1163	   how exclusive a term is to that document: 資格確認書 appears on nothing else,
+  1164	   while 本籍 also appears on 戸籍 documents. The threshold is deliberately a
+  1165	   SUM, not a single magic keyword, because OCR reliably destroys some share of
+  1166	   any given line — on the alpha fixtures the garbled labels are never the same
+  1167	   ones twice. Below threshold the page is "一般文書" and NO Japanese automatic
+  1168	   masking happens at all. */
+  1169	const JP_CLASSES = {
+  1170	  shikaku_kakuninsho: { min: 4, kw: [['資格確認書',3],['保険者番号',2],['被保険者',2],['保険者名',2],
+  1171	      ['国民健康保険',2],['後期高齢者',2],['枝番',2],['記号',1],['健康保険',1],['一部負担金',1]] },
+  1172	  unten_menkyo: { min: 4, kw: [['運転免許証',4],['免許証',2],['公安委員会',2],['備考欄',2],
+  1173	      ['臓器提供',1],['提供意思',1],['優良',1],['原付',1]] },
+  1174	  mynumber_card: { min: 4, kw: [['個人番号カード',4],['マイナンバーカード',4],['個人番号',2],
+  1175	      ['券面記載事項',2],['マイナンバー',2]] },
+  1176	  juminhyo: { min: 4, kw: [['住民票',3],['世帯主',2],['続柄',2],['筆頭者',2],['世帯全員',2],
+  1177	      ['住民となった日',2],['住民票コード',2],['本籍',1],['住民となつた日',2]] },
+  1178	};
+  1179	function jpPageText(pi){
+  1180	  const page = pages[pi];
+  1181	  if (page._jptext != null) return page._jptext;
+  1182	  let s = ''; for (const it of page.items) s += jpNorm(it.str || '').t;
+  1183	  return (page._jptext = s);
+  1184	}
+  1185	function jpClassify(pi){
+  1186	  const txt = jpPageText(pi);
+  1187	  let best = null;
+  1188	  for (const [id, def] of Object.entries(JP_CLASSES)){
+  1189	    let score = 0, hits = [];
+  1190	    for (const [k, w] of def.kw) if (txt.includes(k)) { score += w; hits.push(k); }
+  1191	    if (score >= def.min && (!best || score > best.score)) best = { doc: id, score, hits };
+  1192	  }
+  1193	  if (!best) return null;
+  1194	  // Side: cards have two faces with completely different legal treatment.
+  1195	  if (best.doc === 'mynumber_card' || best.doc === 'unten_menkyo'){
+  1196	    best.side = txt.includes('裏面') ? 'back' : txt.includes('表面') ? 'front'
+  1197	              : (best.doc === 'mynumber_card' && /\d[\d\s.\-]{10,}\d/.test(txt)) ? 'back' : 'front';
+  1198	  }
+  1199	  return best;
+  1200	}
+  1201	
+  1202	/* ── 個人番号 check digit (番号法施行令 別表) ──
+  1203	   Σ P_n·Q_n over the 11-digit body counted from the RIGHT (n = 1..11),
+  1204	   Q_n = n+1 for n ≤ 6 else n−5; check = 11 − (Σ mod 11), and ≥10 → 0. */
+  1205	function myNumberCheckOk(d12){
+  1206	  if (!/^\d{12}$/.test(d12)) return false;
+  1207	  const d = d12.slice(0, 11).split('').map(Number);
+  1208	  let s = 0;
+  1209	  for (let n = 1; n <= 11; n++){ const q = n <= 6 ? n + 1 : n - 5; s += d[11 - n] * q; }
+  1210	  let chk = 11 - (s % 11); if (chk >= 10) chk = 0;
+  1211	  return chk === Number(d12[11]);
+  1212	}
+  1213	
+  1214	/* ── pixel helpers for field FRAMES and code blocks ──
+  1215	   A 欄 (field box) is drawn as a thin rectangle; its contents may be empty, so
+  1216	   there is nothing for a text-based detector to find. Scanning for the drawn
+  1217	   rule is the only way to cover 臓器提供意思表示欄 on a card whose box the
+  1218	   holder left blank — and a blank-looking box is exactly where a faint
+  1219	   handwritten mark hides. */
+  1220	function jpPageBg(page){
+  1221	  if (page._jpbg) return page._jpbg;
+  1222	  const ctx = page.canvas.getContext('2d', { willReadFrequently: true });
+  1223	  const W = page.canvas.width, H = page.canvas.height;
+  1224	  const pick = [];
+  1225	  for (let i = 0; i < 24; i++){
+  1226	    const x = Math.round(W * (i % 6 + 0.5) / 6);
+  1227	    const y = [2, H - 3, Math.round(H * 0.01), Math.round(H * 0.99)][Math.floor(i / 6)];
+  1228	    const d = ctx.getImageData(Math.max(0, Math.min(W-1, x)), Math.max(0, Math.min(H-1, y)), 1, 1).data;
+  1229	    pick.push([d[0], d[1], d[2]]);
+  1230	  }
+  1231	  const med = c => { const s = pick.map(p => p[c]).sort((a,b)=>a-b); return s[s.length >> 1]; };
+  1232	  return (page._jpbg = [med(0), med(1), med(2)]);
+  1233	}
+  1234	function jpRowInk(page, y, bg, thr){
+  1235	  const ctx = page.canvas.getContext('2d', { willReadFrequently: true });
+  1236	  const W = page.canvas.width;
+  1237	  const d = ctx.getImageData(0, y, W, 1).data;
+  1238	  let best = null, runStart = -1;
+  1239	  for (let x = 0; x <= W; x++){
+  1240	    const ink = x < W && (Math.abs(d[x*4] - bg[0]) > thr || Math.abs(d[x*4+1] - bg[1]) > thr || Math.abs(d[x*4+2] - bg[2]) > thr);
+  1241	    if (ink){ if (runStart < 0) runStart = x; }
+  1242	    else if (runStart >= 0){ const len = x - runStart; if (!best || len > best.len) best = { x0: runStart, x1: x, len }; runStart = -1; }
+  1243	  }
+  1244	  return best;
+  1245	}
+  1246	// The drawn rectangle that starts just under `anchor`. Returns null if none.
+  1247	// Starting the scan at the anchor's MIDDLE (not its bottom) matters: on the
+  1248	// licence back the 備考欄 frame's top rule overlaps the label's own glyph box.
+  1249	// Text can never produce a 150px CONTIGUOUS ink run, so the label cannot be
+  1250	// mistaken for a rule, and a diagonal watermark stroke cannot either.
+  1251	const JP_RULE_MIN = 150, JP_RULE_TOL = 12;
+  1252	function jpFrameBelow(page, anchor){
+  1253	  const bg = jpPageBg(page), H = page.canvas.height;
+  1254	  const y0 = Math.round(anchor.y + anchor.h * 0.5);
+  1255	  const yMax = Math.min(H - 1, Math.round(anchor.y + anchor.h * 12));
+  1256	  let top = null;
+  1257	  for (let y = y0; y <= yMax; y++){
+  1258	    const r = jpRowInk(page, y, bg, 40);
+  1259	    if (r && r.len >= JP_RULE_MIN){ top = { y, ...r }; break; }
+  1260	  }
+  1261	  if (!top) return null;
+  1262	  for (let y = top.y + 6; y <= yMax; y++){
+  1263	    const r = jpRowInk(page, y, bg, 40);
+  1264	    if (r && r.len >= JP_RULE_MIN && Math.abs(r.x0 - top.x0) <= JP_RULE_TOL && Math.abs(r.x1 - top.x1) <= JP_RULE_TOL)
+  1265	      return { page: pages.indexOf(page), x: top.x0, y: top.y, w: top.x1 - top.x0, h: y - top.y, region: true };
+  1266	  }
+  1267	  return null;
+  1268	}
+  1269	/* A 二次元コード block. Two paths, with different confidence:
+  1270	   (a) LABELLED — the page says 二次元コード / QR near it. The block is the
+  1271	       cluster of items around that label, squared up. Verified by the golden.
+  1272	   (b) UNLABELLED — a solid, near-square, high-fill block of non-background
+  1273	       pixels. This is what a real printed QR looks like, but the alpha dummies
+  1274	       carry NO real QR (strategy v2 §4 forbids generating one), so this path
+  1275	       has no golden coverage. It therefore emits a CANDIDATE, never an
+  1276	       automatic band: untested detection must not delete pixels by itself. */
+  1277	function jpSquareAround(boxes){
+  1278	  const x0 = Math.min(...boxes.map(b=>b.x)), y0 = Math.min(...boxes.map(b=>b.y));
+  1279	  const x1 = Math.max(...boxes.map(b=>b.x+b.w)), y1 = Math.max(...boxes.map(b=>b.y+b.h));
+  1280	  const side = Math.max(x1-x0, y1-y0), cx = (x0+x1)/2, cy = (y0+y1)/2;
+  1281	  return { x: cx - side/2, y: cy - side/2, w: side, h: side };
+  1282	}
+  1283	function jpCodeBlocks(pi){
+  1284	  const page = pages[pi], segs = jpSegments(pi);
+  1285	  // 1) Solid, near-square blocks of non-background pixels. This is what a printed
+  1286	  //    code BLOCK is, independent of whether anything near it is readable.
+  1287	  const blocks = jpSolidSquares(page, pi);
+  1288	  const hit = (a,b)=> !(a.x+a.w < b.x || b.x+b.w < a.x || a.y+a.h < b.y || b.y+b.h < a.y);
+  1289	  const out = [], usedBlock = blocks.map(()=>false);
+  1290	  // 2) Label anchors. A label makes the block's identity CERTAIN, which is what
+  1291	  //    lifts it to an automatic band.
+  1292	  for (const seg of segs){
+  1293	    if (!/二次元コード|次元コード|コード欄|QRコード|ＱＲ/.test(seg.t)) continue;
+  1294	    const sb = jpSegBox(seg);
+  1295	    const bi = blocks.findIndex(b => hit(b, sb));
+  1296	    if (bi >= 0){
+  1297	      // Snap to the measured block. The label text sits in one corner of the
+  1298	      // block, so a square grown around the TEXT is offset from the block and
+  1299	      // leaves a readable strip — 80% of the fixture's code area, which passed a
+  1300	      // 60% gate while a real QR stayed decodable. The pixels know better.
+  1301	      usedBlock[bi] = true;
+  1302	      const g = Math.max(4, blocks[bi].w * 0.04);
+  1303	      out.push({ box: { page: pi, x: blocks[bi].x-g, y: blocks[bi].y-g, w: blocks[bi].w+2*g, h: blocks[bi].h+2*g, region: true }, labelled: true });
+  1304	      continue;
+  1305	    }
+  1306	    // No measurable block (a code printed in a light colour, or a frame we
+  1307	    // cannot see): fall back to a square around the label's connected cluster.
+  1308	    const M = 20;
+  1309	    let cl = sb, grew = true;
+  1310	    const pool = segs.filter(x => x !== seg && x.pi === pi).map(jpSegBox);
+  1311	    const taken = pool.map(()=>false);
+  1312	    const touches = (a,b)=> !(a.x+a.w < b.x-M || b.x+b.w < a.x-M || a.y+a.h < b.y-M || b.y+b.h < a.y-M);
+  1313	    while (grew){
+  1314	      grew = false;
+  1315	      pool.forEach((b,k)=>{
+  1316	        if (taken[k] || !touches(cl,b)) return;
+  1317	        taken[k] = true; grew = true;
+  1318	        const x1=Math.max(cl.x+cl.w,b.x+b.w), y1=Math.max(cl.y+cl.h,b.y+b.h);
+  1319	        cl = { x:Math.min(cl.x,b.x), y:Math.min(cl.y,b.y), w:0, h:0 };
+  1320	        cl.w = x1-cl.x; cl.h = y1-cl.y;
+  1321	      });
+  1322	    }
+  1323	    const sq = jpSquareAround([cl]), g = sq.w * 0.1;
+  1324	    out.push({ box: { page: pi, x: sq.x-g, y: sq.y-g, w: sq.w+2*g, h: sq.h+2*g, region: true }, labelled: true });
+  1325	  }
+  1326	  // 3) Blocks with no label: see the note above — detection without golden
+  1327	  //    coverage emits a candidate, never an automatic band.
+  1328	  blocks.forEach((b,k)=>{ if (!usedBlock[k]) out.push({ box: { page: pi, ...b, region: true }, labelled: false }); });
+  1329	  return out;
+  1330	}
+  1331	// Connected components of "solidly non-background" 16px cells that are big,
+  1332	// near-square and well filled. A diagonal watermark stroke is thin, so its cells
+  1333	// never reach the 0.6 density floor; body text never reaches the 0.75 fill.
+  1334	function jpSolidSquares(page, pi){
+  1335	  const bg = jpPageBg(page), W = page.canvas.width, H = page.canvas.height;
+  1336	  const CELL = 16, gw = Math.floor(W / CELL), gh = Math.floor(H / CELL);
+  1337	  const ctx = page.canvas.getContext('2d', { willReadFrequently: true });
+  1338	  const dense = [];
+  1339	  for (let gy = 0; gy < gh; gy++){
+  1340	    dense.push([]);
+  1341	    for (let gx = 0; gx < gw; gx++){
+  1342	      const d = ctx.getImageData(gx*CELL, gy*CELL, CELL, CELL).data;
+  1343	      let ink = 0;
+  1344	      for (let k = 0; k < CELL*CELL; k++){
+  1345	        if (Math.abs(d[k*4]-bg[0]) > 40 || Math.abs(d[k*4+1]-bg[1]) > 40 || Math.abs(d[k*4+2]-bg[2]) > 40) ink++;
+  1346	      }
+  1347	      dense[gy].push(ink / (CELL*CELL) >= 0.6);
+  1348	    }
+  1349	  }
+  1350	  const seen = dense.map(r => r.map(()=>false)), out = [];
+  1351	  for (let gy = 0; gy < gh; gy++) for (let gx = 0; gx < gw; gx++){
+  1352	    if (!dense[gy][gx] || seen[gy][gx]) continue;
+  1353	    const st = [[gy,gx]]; let minx=gx,maxx=gx,miny=gy,maxy=gy,n=0;
+  1354	    seen[gy][gx] = true;
+  1355	    while (st.length){
+  1356	      const [y,x] = st.pop(); n++;
+  1357	      minx=Math.min(minx,x); maxx=Math.max(maxx,x); miny=Math.min(miny,y); maxy=Math.max(maxy,y);
+  1358	      for (const [dy,dx] of [[1,0],[-1,0],[0,1],[0,-1]]){
+  1359	        const ny=y+dy, nx=x+dx;
+  1360	        if (ny>=0&&ny<gh&&nx>=0&&nx<gw&&dense[ny][nx]&&!seen[ny][nx]){ seen[ny][nx]=true; st.push([ny,nx]); }
+  1361	      }
+  1362	    }
+  1363	    const bw = maxx-minx+1, bh = maxy-miny+1, ar = bw/bh, fill = n/(bw*bh);
+  1364	    if (bw*CELL >= 60 && bh*CELL >= 60 && ar >= 0.8 && ar <= 1.25 && fill >= 0.75)
+  1365	      out.push({ page: pi, x: minx*CELL, y: miny*CELL, w: bw*CELL, h: bh*CELL });
+  1366	  }
+  1367	  return out;
+  1368	}
+  1369	
+  1370	/* ── legal matrix, as code ──
+  1371	   Mirrors test/safe/fixtures/jp/jp_legal_matrix_alpha4.json. Levels:
+  1372	     auto      文書分類+ラベル一致で自動黒塗り
+  1373	     gate      目的選択後に自動（別目的では解除）= auto_with_purpose_gate
+  1374	     recommend 既定ON・解除可
+  1375	     optional  既定OFF・選択可
+  1376	     keep      黒塗り禁止（警告）
+  1377	   Two documented deviations from the JSON, both widening what may be hidden:
+  1378	   本籍/筆頭者 also carry `recommend` for my_number_procedure and bid_attachment
+  1379	   (the 本籍 is not part of a 個人番号 or tender filing either), matching the
+  1380	   fixture expectations. */
+  1381	const P_ALL = ['identity_submit','my_number_procedure','bid_attachment','consult_share'];
+  1382	const P_NOT_MYNUM = ['identity_submit','bid_attachment','consult_share'];
+  1383	// Shared by all four documents: neither a free-standing address nor a phone
+  1384	// number is part of what any of them has to prove, so both are always OFFERED —
+  1385	// and recommended when the point of sharing is advice, not identification.
+  1386	const JP_EXTRA = { address_loose: { recommend: ['consult_share'], optional: P_ALL },
+  1387	                   tel:           { recommend: ['consult_share'], optional: P_ALL } };
+  1388	const JP_RULES = {
+  1389	  shikaku_kakuninsho: {
+  1390	    // 健康保険法等 告知要求制限 (2020-10-01) — mhlw.go.jp/stf/newpage_13989.html
+  1391	    hokensha_bango:   { auto: P_NOT_MYNUM },
+  1392	    kigo:             { auto: P_NOT_MYNUM },
+  1393	    bango:            { auto: P_NOT_MYNUM },
+  1394	    edaban:           { auto: P_NOT_MYNUM },
+  1395	    hihokensha_bango: { auto: P_NOT_MYNUM },
+  1396	    // QRは番号を判読可能なため同一扱い（大阪府・千葉市運用）
+  1397	    qr:               { auto: P_NOT_MYNUM },
+  1398	    // 法定ではない。民間KYC運用（SoftBank, PayPay銀行等）
+  1399	    sex:              { recommend: ['identity_submit'] },
+  1400	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL},
+  1401	    jigyosho:{keep:P_ALL}, hokensha_name:{keep:P_ALL}, shikaku_date:{keep:P_ALL},
+  1402	    ...JP_EXTRA,
+  1403	  },
+  1404	  unten_menkyo: {
+  1405	    biko_change:  { recommend: ['identity_submit','consult_share'] },
+  1406	    organ_donor:  { recommend: ['identity_submit','consult_share'] },
+  1407	    // 個人識別符号だが、KYCでは照合に必要な提出先が多い → 既定OFF
+  1408	    license_no:   { optional: P_ALL },
+  1409	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL}, issue:{keep:P_ALL},
+  1410	    ...JP_EXTRA,
+  1411	  },
+  1412	  mynumber_card: {
+  1413	    // 番号法: 法令で認められた者・目的以外での個人番号の収集・保管禁止
+  1414	    back_all:   { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
+  1415	    my_number:  { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
+  1416	    qr:         { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
+  1417	    sex:        { recommend: ['identity_submit'] },
+  1418	    organ_donor:{ recommend: ['identity_submit'] },
+  1419	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL},
+  1420	    ...JP_EXTRA,
+  1421	  },
+  1422	  juminhyo: {
+  1423	    my_number:  { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
+  1424	    // 住民基本台帳法 利用制限（個人識別符号）
+  1425	    jumin_code: { auto: P_NOT_MYNUM },
+  1426	    honseki:    { recommend: P_ALL },
+  1427	    hittosha:   { recommend: P_ALL },
+  1428	    setaiin:    { recommend: ['identity_submit','consult_share'] },
+  1429	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, issuer:{keep:P_ALL},
+  1430	    ...JP_EXTRA,
+  1431	  },
+  1432	};
+  1433	function jpLevel(doc, field, purpose){
+  1434	  const r = (JP_RULES[doc] || {})[field];
+  1435	  if (!r) return null;
+  1436	  for (const lv of ['auto','gate','recommend','optional','keep'])
+  1437	    if (r[lv] && r[lv].includes(purpose)) return lv;
+  1438	  // A field the matrix knows but this purpose does not list is simply available,
+  1439	  // never silently promoted to automatic.
+  1440	  return r.keep ? 'optional' : 'optional';
+  1441	}
+  1442	
+  1443	/* ── field extraction ─────────────────────────────────────────────────────
+  1444	   Each rule is {field, labels[], re, last} — `labels` are the anchors accepted
+  1445	   in the segment (several spellings, because OCR drops or swaps one character
+  1446	   of a label far more often than it mangles a digit run), `re` is the value
+  1447	   format, and `last` allows falling back to the segment's final item when the
+  1448	   value itself was garbled but its POSITION is still certain (e.g. 性別 whose
+  1449	   single kanji OCR read as "&" — the box is what we need, not the character). */
+  1450	const JP_FIELD_RULES = {
+  1451	  shikaku_kakuninsho: [
+  1452	    { field:'hokensha_bango',   labels:['保険者番号','険者番号','保険者番'], re:/\d{4,10}/ },
+  1453	    { field:'hihokensha_bango', labels:['被保険者番号','被保険者等記号','被保険者番'], re:/[0-9A-Z]{4,12}/ },
+  1454	    { field:'kigo',   labels:['記号'], re:/[0-9A-Z]{2,12}/ },
+  1455	    { field:'edaban', labels:['枝番'], re:/\d{1,3}/ },
+  1456	    // 「番号」単独アンカー禁止 — it is a substring of 保険者番号/被保険者番号, so it
+  1457	    // only counts when the segment actually STARTS with it (its own column).
+  1458	    { field:'bango',  labels:['番号'], re:/[0-9A-Z]{1,12}/, headOnly:true },
+  1459	    { field:'sex',    labels:['性別'], re:/[男女]/, last:true },
+  1460	    { field:'name',   labels:['氏名'], re:null, last:true },
+  1461	    { field:'birth',  labels:['生年月日'], re:null, last:true },
+  1462	    { field:'address',labels:['住所'], re:null, last:true, addr:true },
+  1463	    { field:'expiry', labels:['有効期限'], re:null, last:true },
+  1464	    { field:'tel',    labels:['電話番号','電話','TEL','携帯','FAX'], tel:true },
+  1465	  ],
+  1466	  // Front-only: the back carries a 住所変更 line inside 備考欄, and calling that
+  1467	  // a keep-field would contradict the very region we are hiding.
+  1468	  unten_menkyo: [
+  1469	    { field:'license_no', labels:['番号'], re:/第?\s?[0-9A-Z]{10,14}/, headOnly:true, sides:['front'] },
+  1470	    { field:'name',   labels:['氏名'], re:null, last:true, sides:['front'] },
+  1471	    { field:'birth',  labels:['生年月日'], re:null, last:true, sides:['front'] },
+  1472	    { field:'address',labels:['住所'], re:null, last:true, sides:['front'], addr:true },
+  1473	    { field:'expiry', labels:['有効期限'], re:null, last:true, sides:['front'] },
+  1474	  ],
+  1475	  mynumber_card: [
+  1476	    { field:'my_number', labels:['個人番号','マイナンバー'], digits:12 },
+  1477	    { field:'sex',    labels:['性別'], re:/[男女]/, last:true, sides:['front'] },
+  1478	    { field:'name',   labels:['氏名'], re:null, last:true },
+  1479	    { field:'birth',  labels:['生年月日'], re:null, last:true },
+  1480	    { field:'address',labels:['住所'], re:null, last:true, sides:['front'], addr:true },
+  1481	    { field:'expiry', labels:['有効期限'], re:null, last:true, sides:['front'] },
+  1482	  ],
+  1483	  juminhyo: [
+  1484	    { field:'my_number', labels:['個人番号','マイナンバー'], digits:12 },
+  1485	    { field:'jumin_code',labels:['住民票コード'], digits:11 },
+  1486	    { field:'honseki',  labels:['本籍'], re:null, last:true, addr:true },
+  1487	    { field:'hittosha', labels:['筆頭者'], re:null, last:true },
+  1488	    { field:'name',   labels:['氏名'], re:null, last:true },
+  1489	    { field:'birth',  labels:['生年月日'], re:null, last:true },
+  1490	    { field:'address',labels:['住所'], re:null, last:true, addr:true },
+  1491	    { field:'tel',    labels:['電話番号','電話','TEL','携帯','FAX'], tel:true },
+  1492	  ],
+  1493	};
+  1494	// Field boxes marked as 欄/regions rather than values.
+  1495	const JP_REGION_LABELS = {
+  1496	  unten_menkyo: [
+  1497	    { field:'biko_change', labels:['備考欄','備考'] },
+  1498	    { field:'organ_donor', labels:['臓器提供','提供意思','意思表示欄'] },
+  1499	  ],
+  1500	  mynumber_card: [
+  1501	    { field:'organ_donor', labels:['臓器提供','提供意思','意思表示欄'] },
+  1502	  ],
+  1503	};
+  1504	const JP_DATE_RE = /[年月日]/;
+  1505	
+  1506	/* ── 住所 hierarchy ──────────────────────────────────────────────────────────
+  1507	   郵便番号 → 都道府県 → 市区郡町村 → 町域 → 丁目番地号 → 建物, scored rather than
+  1508	   matched as one regex, because a Japanese address is a sequence of optional
+  1509	   layers and any single regex either demands them all (misses most real
+  1510	   addresses) or demands none (matches every company name ending in 市).
+  1511	
+  1512	   The span is ANCHORED on a 郵便番号 or a real prefecture from the 47-name list.
+  1513	   An invented head like 「架空県」 therefore cannot anchor one — which is exactly
+  1514	   what keeps 「架空県後期高齢者医療広域連合」 (a 保険者名) and 「見本市長 架空 太郎」
+  1515	   (the issuing mayor) out. Requiring the prefecture misses addresses that omit
+  1516	   it, which is common in Japan; for the alpha that trade is deliberate, since a
+  1517	   wrongly banded issuer is a rejected submission.
+  1518	
+  1519	   Institution words are a PENALTY, not an exclusion (strategy v2 §3-2): a real
+  1520	   address can legitimately contain 「…市役所前」, so the word lowers the score
+  1521	   instead of vetoing the span. */
+  1522	const JP_PREFS = ['北海道','青森県','岩手県','宮城県','秋田県','山形県','福島県','茨城県','栃木県','群馬県','埼玉県','千葉県','東京都','神奈川県','新潟県','富山県','石川県','福井県','山梨県','長野県','岐阜県','静岡県','愛知県','三重県','滋賀県','京都府','大阪府','兵庫県','奈良県','和歌山県','鳥取県','島根県','岡山県','広島県','山口県','徳島県','香川県','愛媛県','高知県','福岡県','佐賀県','長崎県','熊本県','大分県','宮崎県','鹿児島県','沖縄県'];
+  1523	const JP_POSTAL_RE = /〒?\d{3}-\d{4}/;
+  1524	const JP_CITY_RE = /^.{1,8}?[市区郡町村]/;
+  1525	// 丁目/番地/番/号 accept 漢数字 一〜十・百・千 as well as digits (official
+  1526	// 住民票 printouts still use them, and OCR reads them as kanji, not digits).
+  1527	const JP_NUM = '(?:[0-9]{1,4}|[一二三四五六七八九十百千]{1,6})';
+  1528	// The numeric tail has to be anchored on a TERMINATOR, not just on "a numeral".
+  1529	// A lazy prefix followed by a bare numeral stops at the first numeral-looking
+  1530	// kanji in a place name — 「三条通一丁目二番三号」 matched just 「三」 — and a
+  1531	// fixed 丁目/番/号 sequence misses the hyphenated form 「霞が関1-3-2」 entirely.
+  1532	// So: skip forward to the first position where NUM is followed by one of
+  1533	// 丁目/番地/番/号/-, then repeat that pair greedily.
+  1534	const JP_SEP = '(?:丁目|番地|番|号|[-－])';
+  1535	const JP_BANCHI_RE = new RegExp(`^.{0,14}?${JP_NUM}${JP_SEP}(?:の?${JP_NUM}${JP_SEP})*(?:の?${JP_NUM})?号?`);
+  1536	const JP_INSTITUTION_RE = /市役所|区役所|町役場|村役場|株式会社|有限会社|合同会社|大学|学校|病院|診療所|協会|広域連合|組合|銀行|支店|連合会|振興局/;
+  1537	// Finds an address starting at or after `from`. Returns {a,b,score,postal,pref}.
+  1538	function jpAddressSpan(t, from){
+  1539	  let a = -1, score = 0, postal = false, pref = '';
+  1540	  const pm = JP_POSTAL_RE.exec(t.slice(from));
+  1541	  for (const p of JP_PREFS){
+  1542	    const i = t.indexOf(p, from);
+  1543	    if (i >= 0 && (a < 0 || i < a)) { a = i; pref = p; }
+  1544	  }
+  1545	  if (pm && (a < 0 || from + pm.index < a)) { a = from + pm.index; postal = true; }
+  1546	  if (a < 0) return null;
+  1547	  if (postal) score += 2;
+  1548	  let b = a;
+  1549	  if (postal) b = a + (pm ? pm[0].length : 0);
+  1550	  if (pref){
+  1551	    const pi = t.indexOf(pref, a);
+  1552	    if (pi >= 0){ score += 2; b = Math.max(b, pi + pref.length); }
+  1553	  }
+  1554	  const city = JP_CITY_RE.exec(t.slice(b));
+  1555	  if (city){ score += 1; b += city[0].length; }
+  1556	  const ban = JP_BANCHI_RE.exec(t.slice(b));
+  1557	  if (ban && ban[0].length && /[0-9一二三四五六七八九十百千]/.test(ban[0])){ score += 2; b += ban[0].length; }
+  1558	  // The penalty looks a little PAST the span, because the shape it is meant to
+  1559	  // catch is a city match swallowing the head of an institution name
+  1560	  // (「大阪府見本市」+「役所」). −2, not a veto: a complete address scores 5 and
+  1561	  // survives at 3 (a candidate), while a partial one falls under the floor.
+  1562	  if (JP_INSTITUTION_RE.test(t.slice(a, Math.min(t.length, b + 8)))) score -= 2;
+  1563	  return { a, b, score, postal, pref: !!pref };
+  1564	}
+  1565	
+  1566	/* ── 電話・FAX ──
+  1567	   Anchored on TEL/電話/携帯/FAX; the value must fit the Japanese numbering plan.
+  1568	   A hyphenated value is the confirmed shape; an unseparated digit run of the
+  1569	   same length is a CANDIDATE, because at that point it is indistinguishable
+  1570	   from an account or reference number and only the label suggests otherwise.
+  1571	   NOTE: none of the four alpha documents carries a phone number, so this rule
+  1572	   has no golden coverage — it is unexercised code until a fixture has one. */
+  1573	const JP_TEL_HYPHEN_RE = /0120-\d{3}-\d{3}|0800-\d{3}-\d{4}|0\d{1,4}-\d{1,4}-\d{4}/;
+  1574	const JP_TEL_PLAIN_RE = /(?<!\d)0\d{9,10}(?!\d)/;
+  1575	function jpFindLabel(seg, labels, headOnly){
+  1576	  for (const L of labels){
+  1577	    const p = seg.t.indexOf(L);
+  1578	    if (p < 0) continue;
+  1579	    if (headOnly && p !== 0) continue;
+  1580	    return { at: p, end: p + L.length };
+  1581	  }
+  1582	  return null;
+  1583	}
+  1584	// Span of the first `n` digits after `from`, tolerating group separators.
+  1585	function jpDigitSpan(seg, from, n){
+  1586	  let first = -1, last = -1, count = 0;
+  1587	  for (let k = from; k < seg.t.length; k++){
+  1588	    const c = seg.t[k];
+  1589	    if (isDigit(c)){ if (first < 0) first = k; last = k; if (++count === n) return { a:first, b:last+1, digits: seg.t.slice(first,last+1).replace(/\D/g,'') }; }
+  1590	    else if (first >= 0 && !/[\s.\-・,/]/.test(c)) { first = -1; last = -1; count = 0; }
+  1591	  }
+  1592	  return null;
+  1593	}
+  1594	function jpExtract(pi, cls){
+  1595	  const segs = jpSegments(pi), found = [];
+  1596	  // Every value rule anchors at the SEGMENT HEAD. In these forms the label always
+  1597	  // opens its own column, so a label found mid-segment is prose, not an anchor —
+  1598	  // that is how the 「裏面の生年月日有無は…要確認」 footnote on the card dummy got
+  1599	  // read as a 生年月日 field. (The 欄 region labels below deliberately do not use
+  1600	  // this: OCR puts a garbled 騰 in front of 器提供意思表示欄.)
+  1601	  const rules = (JP_FIELD_RULES[cls.doc] || [])
+  1602	    .filter(r => !r.sides || r.sides.includes(cls.side))
+  1603	    .map(r => ({ ...r, headOnly: true }));
+  1604	  const push = (field, boxes, value, extra) => { if (boxes && boxes.length) found.push({ field, boxes, value, pi, ...extra }); };
+  1605	
+  1606	  for (const seg of segs){
+  1607	    for (const r of rules){
+  1608	      const L = jpFindLabel(seg, r.labels, r.headOnly);
+  1609	      if (!L) continue;
+  1610	      if (r.tel){
+  1611	        const tail = seg.t.slice(L.end);
+  1612	        const hy = JP_TEL_HYPHEN_RE.exec(tail);
+  1613	        const pl = hy ? null : JP_TEL_PLAIN_RE.exec(tail);
+  1614	        const m = hy || pl;
+  1615	        if (!m) continue;
+  1616	        const a2 = L.end + m.index, b2 = a2 + m[0].length;
+  1617	        push('tel', jpBoxes(seg, a2, b2), m[0], { loose: !hy });
+  1618	        for (let k = a2; k < b2; k++) seg.used[k] = 1;
+  1619	        continue;
+  1620	      }
+  1621	      if (r.digits){
+  1622	        const sp = jpDigitSpan(seg, L.end, r.digits);
+  1623	        if (!sp) continue;
+  1624	        const extra = r.field === 'my_number' ? { checkOk: myNumberCheckOk(sp.digits) } : {};
+  1625	        push(r.field, jpBoxes(seg, sp.a, sp.b), sp.digits, extra);
+  1626	        for (let k = sp.a; k < sp.b; k++) seg.used[k] = 1;
+  1627	        continue;
+  1628	      }
+  1629	      let a = -1, b = -1, val = '';
+  1630	      if (r.addr){
+  1631	        // 住所/本籍: bound the value by the address hierarchy rather than by
+  1632	        // "everything after the label", so a second column that drifted into
+  1633	        // this segment is not swept into the band.
+  1634	        const sp = jpAddressSpan(seg.t, L.end);
+  1635	        if (sp && sp.b > sp.a){ a = sp.a; b = sp.b; val = seg.t.slice(a, b); }
+  1636	      } else if (r.re){
+  1637	        const m = r.re.exec(seg.t.slice(L.end));
+  1638	        if (m){ a = L.end + m.index; b = a + m[0].length; val = m[0]; }
+  1639	      }
+  1640	      if (a < 0 && r.last !== true) continue;
+  1641	      if (a < 0){
+  1642	        // value position certain, characters not: take the items after the label
+  1643	        const after = seg.items.filter(o => seg.start[o.i] >= L.end);
+  1644	        if (!after.length) continue;
+  1645	        const boxes = after.map(o => { const b2 = { page: pi, x:o.it.x, y:o.it.y, w:o.it.w, h:o.it.h }; b2.bg = sampleBg(pages[pi], b2); return b2; });
+  1646	        push(r.field, boxes, seg.t.slice(L.end).trim() || '(value)');
+  1647	        for (let k = L.end; k < seg.t.length; k++) seg.used[k] = 1;
+  1648	        continue;
+  1649	      }
+  1650	      push(r.field, jpBoxes(seg, a, b), val.trim());
+  1651	      for (let k = a; k < b; k++) seg.used[k] = 1;
+  1652	    }
+  1653	  }
+  1654	
+  1655	  /* Structural fallback — ONLY where OCR has destroyed the label but the format
+  1656	     plus the document class still pin the field down. Each is narrow and stated:
+  1657	       資格確認書: a bare 6–10 digit run outside any date line is a member of the
+  1658	         保険者番号・記号・番号・枝番 family. The 告知要求制限 covers that whole
+  1659	         family as ONE rule, so the cost of guessing which member it is, is zero —
+  1660	         while a miss is the exact leak the product exists to prevent. Measured:
+  1661	         OCR renders 保険者番号 as "RREES"/"REEES"/"WREEES" on 3 of 5 fixtures.
+  1662	       住民票: 12 digits = 個人番号, 11 digits = 住民票コード. Both lengths are
+  1663	         fixed by statute and nothing else on the form is that long. */
+  1664	  const isDateRow = s => JP_DATE_RE.test(s.rowText) || s.rowText.includes('〒');
+  1665	  const unconsumed = (seg, a, b) => { for (let k=a;k<b;k++) if (seg.used[k]) return false; return true; };
+  1666	  const runs = seg => { const out=[]; let st=-1;
+  1667	    for (let k=0;k<=seg.t.length;k++){ const d = k<seg.t.length && isDigit(seg.t[k]);
+  1668	      if (d){ if (st<0) st=k; } else if (st>=0){ out.push([st,k]); st=-1; } } return out; };
+  1669	  if (cls.doc === 'shikaku_kakuninsho'){
+  1670	    for (const seg of segs){
+  1671	      if (isDateRow(seg)) continue;
+  1672	      for (const [a,b] of runs(seg)){
+  1673	        const len = b - a;
+  1674	        if (len < 6 || len > 10 || !unconsumed(seg, a, b)) continue;
+  1675	        push('hokensha_bango', jpBoxes(seg, a, b), seg.t.slice(a,b), { viaFallback: true });
+  1676	        for (let k=a;k<b;k++) seg.used[k]=1;
+  1677	      }
+  1678	    }
+  1679	  }
+  1680	  if (cls.doc === 'juminhyo'){
+  1681	    for (const seg of segs){
+  1682	      if (isDateRow(seg)) continue;
+  1683	      for (const [a,b] of runs(seg)){
+  1684	        const len = b - a;
+  1685	        if (!unconsumed(seg, a, b)) continue;
+  1686	        if (len === 12) push('my_number', jpBoxes(seg, a, b), seg.t.slice(a,b), { checkOk: myNumberCheckOk(seg.t.slice(a,b)), viaFallback: true });
+  1687	        else if (len === 11) push('jumin_code', jpBoxes(seg, a, b), seg.t.slice(a,b), { viaFallback: true });
+  1688	        else continue;
+  1689	        for (let k=a;k<b;k++) seg.used[k]=1;
+  1690	      }
+  1691	    }
+  1692	  }
+  1693	
+  1694	  /* Unlabelled addresses. Anything a label already claimed is marked consumed,
+  1695	     so this only sees text standing on its own — 備考欄 contents, free-form
+  1696	     notes. Per strategy v2 §3-2 it is automatic ONLY with 郵便番号 AND 都道府県
+  1697	     together; otherwise it is a review candidate. It is filed under its own
+  1698	     field key so it can never be confused with the LABELLED 住所, which on all
+  1699	     four alpha documents is a keep-field the recipient needs. */
+  1700	  for (const seg of segs){
+  1701	    let from = 0;
+  1702	    for (let guard = 0; guard < 4; guard++){
+  1703	      const sp = jpAddressSpan(seg.t, from);
+  1704	      if (!sp || sp.b <= sp.a) break;
+  1705	      from = sp.b;
+  1706	      if (sp.score < 3) continue;
+  1707	      let free = true; for (let k = sp.a; k < sp.b; k++) if (seg.used[k]) { free = false; break; }
+  1708	      if (!free) continue;
+  1709	      push('address_loose', jpBoxes(seg, sp.a, sp.b), seg.t.slice(sp.a, sp.b), { strong: sp.postal && sp.pref });
+  1710	      for (let k = sp.a; k < sp.b; k++) seg.used[k] = 1;
+  1711	    }
+  1712	  }
+  1713	
+  1714	  // 欄 regions (備考欄 / 臓器提供意思表示欄): the drawn rectangle under the label.
+  1715	  for (const rr of (JP_REGION_LABELS[cls.doc] || [])){
+  1716	    for (const seg of segs){
+  1717	      if (!jpFindLabel(seg, rr.labels, false)) continue;
+  1718	      const fr = jpFrameBelow(pages[pi], { y: seg.y, h: seg.h });
+  1719	      const box = fr ? { ...fr, page: pi }
+  1720	                     : { page: pi, x: seg.x0, y: seg.y, w: Math.max(seg.x1-seg.x0, pages[pi].w*0.5), h: seg.h*3.5, region: true };
+  1721	      push(rr.field, [box], rr.field);
+  1722	      break;
+  1723	    }
+  1724	  }
+  1725	
+  1726	  // 二次元コード
+  1727	  if (cls.doc === 'shikaku_kakuninsho' || (cls.doc === 'mynumber_card' && cls.side === 'back')){
+  1728	    for (const cb of jpCodeBlocks(pi)) push('qr', [cb.box], '二次元コード', { unlabelledCode: !cb.labelled });
+  1729	  }
+  1730	
+  1731	  // 住民票: household member blocks. Block 1 is the subject; blocks 2..n are
+  1732	  // third parties whose data the recipient did not ask for. Found by the 氏名
+  1733	  // label rows, because 続柄 (本人/妻/子) is a single kanji that OCR mangles far
+  1734	  // more often than it mangles a whole label.
+  1735	  if (cls.doc === 'juminhyo'){
+  1736	    const nameRows = segs.filter(s => jpFindLabel(s, ['氏名'], false)).sort((a,b)=>a.y-b.y);
+  1737	    const endRe = /住民票コード|この写し|相違|証明し|市長|区長|町長|村長|公印/;
+  1738	    if (nameRows.length > 1){
+  1739	      for (let i = 1; i < nameRows.length; i++){
+  1740	        const top = nameRows[i].y;
+  1741	        const next = i + 1 < nameRows.length ? nameRows[i+1].y : Infinity;
+  1742	        const stop = segs.filter(s => s.y > top && s.y < next && endRe.test(s.rowText)).map(s=>s.y);
+  1743	        const bottom = stop.length ? Math.min(...stop) : next;
+  1744	        const byRow = {};
+  1745	        for (const s of segs){
+  1746	          if (s.y < top || s.y >= bottom) continue;
+  1747	          (byRow[s.row] = byRow[s.row] || []).push(s);
+  1748	        }
+  1749	        for (const list of Object.values(byRow))
+  1750	          push('setaiin', list.map(jpSegBox), (list[0].t || '(世帯員)').slice(0, 24));
+  1751	      }
+  1752	    }
+  1753	    // 氏名/生年月日 inside a THIRD PARTY's block are not the subject's keep-fields.
+  1754	    // Leaving them in would put the same pixels in the 残す項目 list and under a
+  1755	    // band at the same time — the list would be telling the user the opposite of
+  1756	    // what the page shows.
+  1757	    const regions = found.filter(f => f.field === 'setaiin').flatMap(f => f.boxes);
+  1758	    if (regions.length){
+  1759	      const inside = b => regions.some(r => b.x + b.w/2 >= r.x && b.x + b.w/2 <= r.x + r.w
+  1760	                                         && b.y + b.h/2 >= r.y && b.y + b.h/2 <= r.y + r.h);
+  1761	      for (let i = found.length - 1; i >= 0; i--){
+  1762	        const f = found[i];
+  1763	        if (!['name','birth','address'].includes(f.field)) continue;
+  1764	        if (f.boxes.every(inside)) found.splice(i, 1);
+  1765	      }
+  1766	    }
+  1767	  }
+  1768	  return found;
+  1769	}
+  1770	
+  1771	/* ── state + application ── */
+  1772	const JP_PURPOSES = ['identity_submit','my_number_procedure','bid_attachment','consult_share'];
+  1773	let jpState = { cls: null, purpose: 'identity_submit', findings: [] };
+  1774	function jpScan(){
+  1775	  jpState.cls = null; jpState.findings = [];
+  1776	  if (!pages.length) return null;
+  1777	  const cls = jpClassify(0);
+  1778	  if (!cls) return null;
+  1779	  jpState.cls = cls;
+  1780	  let all = [];
+  1781	  for (let pi = 0; pi < pages.length; pi++){
+  1782	    const c = pi === 0 ? cls : (jpClassify(pi) || cls);
+  1783	    all = all.concat(jpExtract(pi, c));
+  1784	  }
+  1785	  jpState.findings = all;
+  1786	  return cls;
+  1787	}
+  1788	function jpFieldLabel(f){ return (T().jpFields && T().jpFields[f]) || f; }
+  1789	// Build entities from the findings for the current purpose. Called on load and
+  1790	// on every purpose change — the purpose IS the policy, so it re-derives rather
+  1791	// than patching modes in place.
+  1792	function jpApply(){
+  1793	  entities = entities.filter(e => !e.jp);
+  1794	  const cls = jpState.cls; if (!cls) { renderAll(); return; }
+  1795	  const purpose = jpState.purpose;
+  1796	  const add = (f, level, boxes, value, note) => {
+  1797	    const kind = (level === 'auto' || level === 'gate') ? 'auto'
+  1798	               : level === 'keep' ? 'keep' : 'candidate';
+  1799	    const mode = (level === 'auto' || level === 'gate' || level === 'recommend') ? 'no' : 'ok';
+  1800	    entities.push({ id:'j'+Math.random().toString(36).slice(2,8), type: JP_TYPE[f] || 'other',
+  1801	      value, mode, kind, reason: 'jp_' + level, boxes, jp: { doc: cls.doc, side: cls.side || null, field: f, level, note: note || null } });
+  1802	  };
+  1803	
+  1804	  // マイナンバーカード裏面 under a 本人確認 purpose: the whole face. 番号法 does not
+  1805	  // let the recipient hold the 個人番号 at all for identity checking, so the
+  1806	  // honest instruction is "submit the front instead", and the band says so.
+  1807	  if (cls.doc === 'mynumber_card' && cls.side === 'back'){
+  1808	    const lv = jpLevel('mynumber_card', 'back_all', purpose);
+  1809	    if (lv === 'auto' || lv === 'gate'){
+  1810	      for (let pi = 0; pi < pages.length; pi++)
+  1811	        add('back_all', lv, [{ page: pi, x: 0, y: 0, w: pages[pi].w, h: pages[pi].h, region: true }], jpFieldLabel('back_all'));
+  1812	    }
+  1813	  }
+  1814	  for (const f of jpState.findings){
+  1815	    let level = jpLevel(cls.doc, f.field, purpose);
+  1816	    if (!level) continue;
+  1817	    // 個人番号 with a check digit that does not verify is NOT confirmed to be a
+  1818	    // 個人番号 — it could be any 12-digit reference. Demote the automatic band
+  1819	    // to a review candidate (still default-ON) rather than assert something the
+  1820	    // arithmetic contradicts.
+  1821	    let note = null;
+  1822	    if (f.field === 'my_number' && (level === 'auto' || level === 'gate') && f.checkOk === false){ level = 'recommend'; note = 'checkdigit'; }
+  1823	    // An unlabelled code block is detection without golden coverage — candidate.
+  1824	    if (f.unlabelledCode && (level === 'auto' || level === 'gate')){ level = 'recommend'; note = 'unlabelled_code'; }
+  1825	    add(f.field, level, f.boxes, f.field === 'qr' || f.boxes.some(b=>b.region) ? jpFieldLabel(f.field) : (f.value || jpFieldLabel(f.field)), note);
+  1826	  }
+  1827	  entities.sort((a,b)=>Object.keys(TYPES).indexOf(a.type)-Object.keys(TYPES).indexOf(b.type));
+  1828	  jpRenderBar();
+  1829	  renderAll();
+  1830	}
+  1831	const JP_TYPE = { address_loose:'address', tel:'phone', my_number:'rrn', jumin_code:'rrn', hokensha_bango:'health', kigo:'health',
+  1832	  bango:'health', edaban:'health', hihokensha_bango:'health', license_no:'license', qr:'other',
+  1833	  back_all:'other', biko_change:'address', organ_donor:'health', setaiin:'name', honseki:'address',
+  1834	  hittosha:'name', sex:'other', name:'name', birth:'birth', address:'address', expiry:'other', issue:'other' };
+  1835	
+  1836	function jpSetPurpose(p){
+  1837	  if (!JP_PURPOSES.includes(p)) return;
+  1838	  jpState.purpose = p;
+  1839	  const sel = $('jpPurpose'); if (sel) sel.value = p;
+  1840	  jpApply();
+  1841	}
+  1842	function jpRenderBar(){
+  1843	  const bar = $('jpBar'); if (!bar) return;
+  1844	  const cls = jpState.cls;
+  1845	  if (!cls){ bar.style.display = 'none'; return; }
+  1846	  bar.style.display = 'flex';
+  1847	  $('jpDocName').textContent = jpFieldLabel('doc_' + cls.doc) + (cls.side ? ' · ' + jpFieldLabel('side_' + cls.side) : '');
+  1848	  const sel = $('jpPurpose');
+  1849	  sel.innerHTML = JP_PURPOSES.map(p => `<option value="${p}">${escapeHtml(jpFieldLabel('purpose_' + p))}</option>`).join('');
+  1850	  sel.value = jpState.purpose;
+  1851	  const note = $('jpNote');
+  1852	  const backMasked = entities.some(e => e.jp && e.jp.field === 'back_all');
+  1853	  note.textContent = backMasked ? T().jpBackNotice : '';
+  1854	  note.style.display = backMasked ? 'block' : 'none';
+  1855	}
+  1856	
+  1857	/* ───────── text masking (list display + "copy text") ─────────
+  1858	   Band-only: there are exactly two states. 'ok' shows the value; anything else
+  1859	   shows a block run of the same rough length. No partial reveal exists, so the
+  1860	   list cannot promise a weaker masking than the rendered page delivers. */
+  1861	const maskBlockText=v=>'■'.repeat(Math.min(Math.max(Math.round(v.replace(/\s/g,'').length*0.8),3),12));
+  1862	// live value shown next to the toggle
+  1863	function displayValue(e){ return e.mode==='ok' ? e.value : maskBlockText(e.value); }
+  1864	
+  1865	/* ───────── coordinate index & box matching ───────── */
+
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+exec
+/bin/zsh -lc "git show 546344b:public/safe/index.html | nl -ba | sed -n '1380,1548p'; git show 546344b:public/safe/index.html | nl -ba | sed -n '2080,2170p'; git show 546344b:public/safe/index.html | nl -ba | sed -n '2270,2355p'; git show 546344b:test/safe/run.mjs | nl -ba; git show 546344b:test/safe/specs.json | nl -ba" in /Users/sunghoon/Projects/docpack
+ succeeded in 0ms:
+  1380	   fixture expectations. */
+  1381	const P_ALL = ['identity_submit','my_number_procedure','bid_attachment','consult_share'];
+  1382	const P_NOT_MYNUM = ['identity_submit','bid_attachment','consult_share'];
+  1383	// Shared by all four documents: neither a free-standing address nor a phone
+  1384	// number is part of what any of them has to prove, so both are always OFFERED —
+  1385	// and recommended when the point of sharing is advice, not identification.
+  1386	const JP_EXTRA = { address_loose: { recommend: ['consult_share'], optional: P_ALL },
+  1387	                   tel:           { recommend: ['consult_share'], optional: P_ALL } };
+  1388	const JP_RULES = {
+  1389	  shikaku_kakuninsho: {
+  1390	    // 健康保険法等 告知要求制限 (2020-10-01) — mhlw.go.jp/stf/newpage_13989.html
+  1391	    hokensha_bango:   { auto: P_NOT_MYNUM },
+  1392	    kigo:             { auto: P_NOT_MYNUM },
+  1393	    bango:            { auto: P_NOT_MYNUM },
+  1394	    edaban:           { auto: P_NOT_MYNUM },
+  1395	    hihokensha_bango: { auto: P_NOT_MYNUM },
+  1396	    // QRは番号を判読可能なため同一扱い（大阪府・千葉市運用）
+  1397	    qr:               { auto: P_NOT_MYNUM },
+  1398	    // 法定ではない。民間KYC運用（SoftBank, PayPay銀行等）
+  1399	    sex:              { recommend: ['identity_submit'] },
+  1400	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL},
+  1401	    jigyosho:{keep:P_ALL}, hokensha_name:{keep:P_ALL}, shikaku_date:{keep:P_ALL},
+  1402	    ...JP_EXTRA,
+  1403	  },
+  1404	  unten_menkyo: {
+  1405	    biko_change:  { recommend: ['identity_submit','consult_share'] },
+  1406	    organ_donor:  { recommend: ['identity_submit','consult_share'] },
+  1407	    // 個人識別符号だが、KYCでは照合に必要な提出先が多い → 既定OFF
+  1408	    license_no:   { optional: P_ALL },
+  1409	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL}, issue:{keep:P_ALL},
+  1410	    ...JP_EXTRA,
+  1411	  },
+  1412	  mynumber_card: {
+  1413	    // 番号法: 法令で認められた者・目的以外での個人番号の収集・保管禁止
+  1414	    back_all:   { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
+  1415	    my_number:  { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
+  1416	    qr:         { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
+  1417	    sex:        { recommend: ['identity_submit'] },
+  1418	    organ_donor:{ recommend: ['identity_submit'] },
+  1419	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL},
+  1420	    ...JP_EXTRA,
+  1421	  },
+  1422	  juminhyo: {
+  1423	    my_number:  { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
+  1424	    // 住民基本台帳法 利用制限（個人識別符号）
+  1425	    jumin_code: { auto: P_NOT_MYNUM },
+  1426	    honseki:    { recommend: P_ALL },
+  1427	    hittosha:   { recommend: P_ALL },
+  1428	    setaiin:    { recommend: ['identity_submit','consult_share'] },
+  1429	    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, issuer:{keep:P_ALL},
+  1430	    ...JP_EXTRA,
+  1431	  },
+  1432	};
+  1433	function jpLevel(doc, field, purpose){
+  1434	  const r = (JP_RULES[doc] || {})[field];
+  1435	  if (!r) return null;
+  1436	  for (const lv of ['auto','gate','recommend','optional','keep'])
+  1437	    if (r[lv] && r[lv].includes(purpose)) return lv;
+  1438	  // A field the matrix knows but this purpose does not list is simply available,
+  1439	  // never silently promoted to automatic.
+  1440	  return r.keep ? 'optional' : 'optional';
+  1441	}
+  1442	
+  1443	/* ── field extraction ─────────────────────────────────────────────────────
+  1444	   Each rule is {field, labels[], re, last} — `labels` are the anchors accepted
+  1445	   in the segment (several spellings, because OCR drops or swaps one character
+  1446	   of a label far more often than it mangles a digit run), `re` is the value
+  1447	   format, and `last` allows falling back to the segment's final item when the
+  1448	   value itself was garbled but its POSITION is still certain (e.g. 性別 whose
+  1449	   single kanji OCR read as "&" — the box is what we need, not the character). */
+  1450	const JP_FIELD_RULES = {
+  1451	  shikaku_kakuninsho: [
+  1452	    { field:'hokensha_bango',   labels:['保険者番号','険者番号','保険者番'], re:/\d{4,10}/ },
+  1453	    { field:'hihokensha_bango', labels:['被保険者番号','被保険者等記号','被保険者番'], re:/[0-9A-Z]{4,12}/ },
+  1454	    { field:'kigo',   labels:['記号'], re:/[0-9A-Z]{2,12}/ },
+  1455	    { field:'edaban', labels:['枝番'], re:/\d{1,3}/ },
+  1456	    // 「番号」単独アンカー禁止 — it is a substring of 保険者番号/被保険者番号, so it
+  1457	    // only counts when the segment actually STARTS with it (its own column).
+  1458	    { field:'bango',  labels:['番号'], re:/[0-9A-Z]{1,12}/, headOnly:true },
+  1459	    { field:'sex',    labels:['性別'], re:/[男女]/, last:true },
+  1460	    { field:'name',   labels:['氏名'], re:null, last:true },
+  1461	    { field:'birth',  labels:['生年月日'], re:null, last:true },
+  1462	    { field:'address',labels:['住所'], re:null, last:true, addr:true },
+  1463	    { field:'expiry', labels:['有効期限'], re:null, last:true },
+  1464	    { field:'tel',    labels:['電話番号','電話','TEL','携帯','FAX'], tel:true },
+  1465	  ],
+  1466	  // Front-only: the back carries a 住所変更 line inside 備考欄, and calling that
+  1467	  // a keep-field would contradict the very region we are hiding.
+  1468	  unten_menkyo: [
+  1469	    { field:'license_no', labels:['番号'], re:/第?\s?[0-9A-Z]{10,14}/, headOnly:true, sides:['front'] },
+  1470	    { field:'name',   labels:['氏名'], re:null, last:true, sides:['front'] },
+  1471	    { field:'birth',  labels:['生年月日'], re:null, last:true, sides:['front'] },
+  1472	    { field:'address',labels:['住所'], re:null, last:true, sides:['front'], addr:true },
+  1473	    { field:'expiry', labels:['有効期限'], re:null, last:true, sides:['front'] },
+  1474	  ],
+  1475	  mynumber_card: [
+  1476	    { field:'my_number', labels:['個人番号','マイナンバー'], digits:12 },
+  1477	    { field:'sex',    labels:['性別'], re:/[男女]/, last:true, sides:['front'] },
+  1478	    { field:'name',   labels:['氏名'], re:null, last:true },
+  1479	    { field:'birth',  labels:['生年月日'], re:null, last:true },
+  1480	    { field:'address',labels:['住所'], re:null, last:true, sides:['front'], addr:true },
+  1481	    { field:'expiry', labels:['有効期限'], re:null, last:true, sides:['front'] },
+  1482	  ],
+  1483	  juminhyo: [
+  1484	    { field:'my_number', labels:['個人番号','マイナンバー'], digits:12 },
+  1485	    { field:'jumin_code',labels:['住民票コード'], digits:11 },
+  1486	    { field:'honseki',  labels:['本籍'], re:null, last:true, addr:true },
+  1487	    { field:'hittosha', labels:['筆頭者'], re:null, last:true },
+  1488	    { field:'name',   labels:['氏名'], re:null, last:true },
+  1489	    { field:'birth',  labels:['生年月日'], re:null, last:true },
+  1490	    { field:'address',labels:['住所'], re:null, last:true, addr:true },
+  1491	    { field:'tel',    labels:['電話番号','電話','TEL','携帯','FAX'], tel:true },
+  1492	  ],
+  1493	};
+  1494	// Field boxes marked as 欄/regions rather than values.
+  1495	const JP_REGION_LABELS = {
+  1496	  unten_menkyo: [
+  1497	    { field:'biko_change', labels:['備考欄','備考'] },
+  1498	    { field:'organ_donor', labels:['臓器提供','提供意思','意思表示欄'] },
+  1499	  ],
+  1500	  mynumber_card: [
+  1501	    { field:'organ_donor', labels:['臓器提供','提供意思','意思表示欄'] },
+  1502	  ],
+  1503	};
+  1504	const JP_DATE_RE = /[年月日]/;
+  1505	
+  1506	/* ── 住所 hierarchy ──────────────────────────────────────────────────────────
+  1507	   郵便番号 → 都道府県 → 市区郡町村 → 町域 → 丁目番地号 → 建物, scored rather than
+  1508	   matched as one regex, because a Japanese address is a sequence of optional
+  1509	   layers and any single regex either demands them all (misses most real
+  1510	   addresses) or demands none (matches every company name ending in 市).
+  1511	
+  1512	   The span is ANCHORED on a 郵便番号 or a real prefecture from the 47-name list.
+  1513	   An invented head like 「架空県」 therefore cannot anchor one — which is exactly
+  1514	   what keeps 「架空県後期高齢者医療広域連合」 (a 保険者名) and 「見本市長 架空 太郎」
+  1515	   (the issuing mayor) out. Requiring the prefecture misses addresses that omit
+  1516	   it, which is common in Japan; for the alpha that trade is deliberate, since a
+  1517	   wrongly banded issuer is a rejected submission.
+  1518	
+  1519	   Institution words are a PENALTY, not an exclusion (strategy v2 §3-2): a real
+  1520	   address can legitimately contain 「…市役所前」, so the word lowers the score
+  1521	   instead of vetoing the span. */
+  1522	const JP_PREFS = ['北海道','青森県','岩手県','宮城県','秋田県','山形県','福島県','茨城県','栃木県','群馬県','埼玉県','千葉県','東京都','神奈川県','新潟県','富山県','石川県','福井県','山梨県','長野県','岐阜県','静岡県','愛知県','三重県','滋賀県','京都府','大阪府','兵庫県','奈良県','和歌山県','鳥取県','島根県','岡山県','広島県','山口県','徳島県','香川県','愛媛県','高知県','福岡県','佐賀県','長崎県','熊本県','大分県','宮崎県','鹿児島県','沖縄県'];
+  1523	const JP_POSTAL_RE = /〒?\d{3}-\d{4}/;
+  1524	const JP_CITY_RE = /^.{1,8}?[市区郡町村]/;
+  1525	// 丁目/番地/番/号 accept 漢数字 一〜十・百・千 as well as digits (official
+  1526	// 住民票 printouts still use them, and OCR reads them as kanji, not digits).
+  1527	const JP_NUM = '(?:[0-9]{1,4}|[一二三四五六七八九十百千]{1,6})';
+  1528	// The numeric tail has to be anchored on a TERMINATOR, not just on "a numeral".
+  1529	// A lazy prefix followed by a bare numeral stops at the first numeral-looking
+  1530	// kanji in a place name — 「三条通一丁目二番三号」 matched just 「三」 — and a
+  1531	// fixed 丁目/番/号 sequence misses the hyphenated form 「霞が関1-3-2」 entirely.
+  1532	// So: skip forward to the first position where NUM is followed by one of
+  1533	// 丁目/番地/番/号/-, then repeat that pair greedily.
+  1534	const JP_SEP = '(?:丁目|番地|番|号|[-－])';
+  1535	const JP_BANCHI_RE = new RegExp(`^.{0,14}?${JP_NUM}${JP_SEP}(?:の?${JP_NUM}${JP_SEP})*(?:の?${JP_NUM})?号?`);
+  1536	const JP_INSTITUTION_RE = /市役所|区役所|町役場|村役場|株式会社|有限会社|合同会社|大学|学校|病院|診療所|協会|広域連合|組合|銀行|支店|連合会|振興局/;
+  1537	// Finds an address starting at or after `from`. Returns {a,b,score,postal,pref}.
+  1538	function jpAddressSpan(t, from){
+  1539	  let a = -1, score = 0, postal = false, pref = '';
+  1540	  const pm = JP_POSTAL_RE.exec(t.slice(from));
+  1541	  for (const p of JP_PREFS){
+  1542	    const i = t.indexOf(p, from);
+  1543	    if (i >= 0 && (a < 0 || i < a)) { a = i; pref = p; }
+  1544	  }
+  1545	  if (pm && (a < 0 || from + pm.index < a)) { a = from + pm.index; postal = true; }
+  1546	  if (a < 0) return null;
+  1547	  if (postal) score += 2;
+  1548	  let b = a;
+  2080	  const cv=canvasEl(iw*sc, ih*sc);
+  2081	  cv.getContext('2d',{willReadFrequently:true}).drawImage(img,0,0,cv.width,cv.height);
+  2082	  setStatus(T().ocrStart);
+  2083	  const items=await ocrCanvas(cv);
+  2084	  pages=[{canvas:cv,w:cv.width,h:cv.height,ptW:cv.width*0.75,ptH:cv.height*0.75,items}];
+  2085	  setProg(0);
+  2086	}
+  2087	
+  2088	async function ocrCanvas(cv){
+  2089	  const Te=await ensureTesseract();
+  2090	  const { data } = await Te.recognize(cv, OCR_LANGS(), { logger:m=>{
+  2091	    if(m.status && m.status.indexOf('recogniz')>=0){ setProg(0.1+m.progress*0.9); setStatus(T().ocrProg(Math.round(m.progress*100))); }
+  2092	    else { setStatus(T().ocrStart); }
+  2093	  }});
+  2094	  const words=(data && data.words) ? data.words : [];
+  2095	  // TRIM the word text. Tesseract sometimes returns a word with leading or
+  2096	  // trailing whitespace, but its bbox is the INK box — the space has no pixels.
+  2097	  // Keeping the space makes str.length one too many, and every character box is
+  2098	  // derived by dividing the item width by that length, so the whole run shifts
+  2099	  // right by one cell. Measured: " 99221010" on 資格確認書 left the first 9
+  2100	  // uncovered by ~7px — a digit of a 保険者番号 surviving the band.
+  2101	  return words.filter(w=>w.text && w.text.trim()).map(w=>({
+  2102	    str:w.text.trim(), x:w.bbox.x0, y:w.bbox.y0, w:w.bbox.x1-w.bbox.x0, h:w.bbox.y1-w.bbox.y0
+  2103	  }));
+  2104	}
+  2105	
+  2106	/* Text (docx/txt/paste/sample) → rendered white pages with word boxes */
+  2107	async function renderTextPages(text,name){
+  2108	  try{ await document.fonts.ready; }catch(e){}
+  2109	  text=(text||'').replace(/\r/g,'');
+  2110	  const W=1240, pad=64, fs=24, LH=Math.round(fs*1.62), maxW=W-pad*2, pageH=Math.round(W*1.414);
+  2111	  const meas=canvasEl(10,10).getContext('2d'); meas.font=fs+'px "IBM Plex Sans KR",sans-serif';
+  2112	  const spaceW=meas.measureText(' ').width;
+  2113	  pages=[];
+  2114	  let cur=null, y=0;
+  2115	  function newPage(){ const c=canvasEl(W,pageH); const ctx=c.getContext('2d',{willReadFrequently:true}); ctx.fillStyle='#FFFFFF'; ctx.fillRect(0,0,W,pageH); ctx.fillStyle=INK; ctx.font=fs+'px "IBM Plex Sans KR",sans-serif'; ctx.textBaseline='alphabetic'; cur={canvas:c,w:W,h:pageH,ptW:W*0.75,ptH:pageH*0.75,items:[],ctx}; y=pad+fs; }
+  2116	  function push(){ if(cur){ delete cur.ctx; pages.push(cur); } }
+  2117	  function nl(){ y+=LH; if(y>pageH-pad){ push(); newPage(); } }
+  2118	  newPage();
+  2119	  for(const line of text.split('\n')){
+  2120	    if(line.trim()===''){ nl(); continue; }
+  2121	    let x=pad;
+  2122	    for(const word of line.split(/\s+/).filter(Boolean)){
+  2123	      const ww=meas.measureText(word).width;
+  2124	      if(x!==pad && x+ww>maxW+pad){ nl(); x=pad; }
+  2125	      cur.ctx.fillText(word, x, y);
+  2126	      cur.items.push({str:word, x, y:y-fs*0.86, w:ww, h:fs*1.16});
+  2127	      x+=ww+spaceW;
+  2128	    }
+  2129	    nl();
+  2130	  }
+  2131	  push();
+  2132	}
+  2133	
+  2134	function afterLoad(keepEntities){
+  2135	  docText=pages.map(p=>p.items.map(i=>i.str).join(' ')).join('\n\n');
+  2136	  $('pasteArea').style.display='none'; $('pasteActions').style.display='none';
+  2137	  dz.style.display='none'; $('docWrap').style.display='flex';
+  2138	  $('fileName').textContent=docTitle||'doc';
+  2139	  $('fileInfo').textContent=T().pages(pages.length);
+  2140	  if(!keepEntities){
+  2141	    entities=[]; aiDone=false; showAllCats=false;
+  2142	    addEntities(regexScan(docText));
+  2143	    // A classified Japanese document gets its own preset. The Latin name/address
+  2144	    // heuristics are suppressed there — they are tuned for résumé typography and
+  2145	    // on a JP form they only ever produced junk ("(被用者", "カー", "裏面"), which
+  2146	    // would sit next to the legally-grounded preset looking equally authoritative.
+  2147	    const jp = jpScan();
+  2148	    if(!jp){
+  2149	      addEntities(nameCandidates());     // conservative top-of-doc name suggestion (defaults to visible)
+  2150	      addEntities(addressCandidates());  // place/city lines without a number → review candidates
+  2151	    }
+  2152	    setStatus(T().scanDone(entities.filter(e=>e.kind!=='candidate').length)); setProg(0);
+  2153	  }
+  2154	  const ab=$('btnAI'); if(!aiDone){ ab.disabled=false; }
+  2155	  buildPreview();
+  2156	  if(jpState.cls){
+  2157	    jpApply();
+  2158	    // The status line is written before the preset runs, so on a JP document it
+  2159	    // used to report "0 found" next to a list of five bands. Keep-fields are not
+  2160	    // "found personal info" — they are what the recipient needs — so they do not count.
+  2161	    if(!keepEntities) setStatus(T().scanDone(entities.filter(e=>e.kind!=='keep'&&e.kind!=='manual').length));
+  2162	  } else { jpRenderBar(); renderAll(); }
+  2163	}
+  2164	function resetResult(){ $('result').style.display='none'; lastOut=null; }
+  2165	function resetAll(){
+  2166	  pages=[]; docText=''; entities=[]; aiDone=false; showAllCats=false; previewCanvases=[];
+  2167	  jpState={cls:null, purpose:'identity_submit', findings:[]}; jpRenderBar();
+  2168	  $('docWrap').style.display='none'; dz.style.display='flex'; $('preview').innerHTML=''; clearDzAlert();
+  2169	  if(typeof setSelectMode==='function') setSelectMode(false);
+  2170	  setStatus(''); setProg(0); resetResult();
+  2270	      if(ov>0.5){ x0=Math.min(x0,b.x);y0=Math.min(y0,b.y);x1=Math.max(x1,b.x+b.w);y1=Math.max(y1,b.y+b.h);used[j]=true;region=region||b.region; }
+  2271	    }
+  2272	    lines.push({x:x0,y:y0,w:x1-x0,h:y1-y0,bg,region});
+  2273	  }
+  2274	  return lines.sort((a,b)=>a.y-b.y||a.x-b.x);
+  2275	}
+  2276	// The band drawn for a merged line box: the text/OCR box grown by a margin of
+  2277	// 15% of the box height (floor 2px) on every side. The margin exists because the
+  2278	// box is an ESTIMATE — pdf.js item boxes exclude side bearings and overshoot,
+  2279	// OCR word boxes clip anti-aliased glyph edges, and both drift under rotation.
+  2280	// A band that stops exactly at the estimate leaves a hairline of original ink.
+  2281	// Percentage-of-height (not a fixed 2px) so the margin scales with the font;
+  2282	// the floor keeps tiny OCR boxes from getting a sub-pixel margin.
+  2283	// A box flagged `region` was drawn by a human (manual drag) or taken from a
+  2284	// detected block/frame — its edges are the intent, not an estimate of where
+  2285	// glyphs end, so it is NOT grown. Growing it would silently cover neighbouring
+  2286	// content the user did not choose to hide.
+  2287	const BAND_PAD_RATIO=0.15, BAND_PAD_MIN=2;
+  2288	function bandRect(l){
+  2289	  if(l.region) return {x:l.x, y:l.y, w:l.w, h:l.h};
+  2290	  const p=Math.max(l.h*BAND_PAD_RATIO, BAND_PAD_MIN);
+  2291	  return {x:l.x-p, y:l.y-p, w:l.w+p*2, h:l.h+p*2};
+  2292	}
+  2293	/* Band colour. Default ink; white and a user-picked single colour are the only
+  2294	   alternatives (a colour is opaque either way — this is a legibility choice on
+  2295	   the submitted copy, not a masking-strength choice). */
+  2296	let BAND_COLOR=INK;
+  2297	function bandColor(){ return BAND_COLOR; }
+  2298	(function(){
+  2299	  const sel=$('bandColor'), cust=$('bandCustom');
+  2300	  if(!sel||!cust) return;
+  2301	  const apply=()=>{
+  2302	    const custom = sel.value==='custom';
+  2303	    cust.style.display = custom? 'inline-block':'none';
+  2304	    BAND_COLOR = custom ? cust.value : sel.value;
+  2305	    if(typeof drawPreview==='function' && pages.length) drawPreview();
+  2306	  };
+  2307	  sel.addEventListener('change',apply);
+  2308	  cust.addEventListener('input',apply);
+  2309	})();
+  2310	function isDarkColor(bg){
+  2311	  const m=/rgb\((\d+),\s*(\d+),\s*(\d+)\)/.exec(bg||''); if(!m) return false;
+  2312	  return (0.299*+m[1]+0.587*+m[2]+0.114*+m[3]) < 130;
+  2313	}
+  2314	// Band-only redaction: every active entity becomes one opaque rect per visual
+  2315	// line, grown by bandRect(). There is no ordering or overlap subtlety left to
+  2316	// get wrong — two entities landing on the same coordinates simply paint the same
+  2317	// opaque colour twice. (The previous partial-mask path needed an escalation pass
+  2318	// to stop two asterisk strings from ghosting over each other and leaving an
+  2319	// uncovered tail; removing the mode removed that whole failure class.)
+  2320	function drawRedactions(ctx,pi,scale){
+  2321	  const S=v=>v*scale;
+  2322	  const col=bandColor();
+  2323	  for(const e of entities){
+  2324	    if(!isOn(e)||e.mode==='ok') continue;
+  2325	    const lines=mergeLineBoxes(e.boxes,pi);
+  2326	    if(!lines.length) continue;
+  2327	    ctx.fillStyle=col;
+  2328	    for(const l of lines){ const r=bandRect(l); ctx.fillRect(S(r.x),S(r.y),S(r.w),S(r.h)); }
+  2329	  }
+  2330	}
+  2331	function drawWatermark(ctx,W,H,text){
+  2332	  if(!text) return;
+  2333	  ctx.save();
+  2334	  // keep bottom margin clear (QR/stamp/signature area) + small top margin
+  2335	  ctx.beginPath(); ctx.rect(0, H*0.05, W, H*0.81); ctx.clip();
+  2336	  ctx.globalAlpha=0.10; ctx.fillStyle=INK;
+  2337	  const fs=Math.max(16, W*0.028);
+  2338	  ctx.font='700 '+fs+'px "IBM Plex Sans KR",sans-serif';
+  2339	  ctx.textAlign='center'; ctx.textBaseline='middle';
+  2340	  ctx.translate(W/2,H/2); ctx.rotate(-Math.PI/6);
+  2341	  const tw=ctx.measureText(text).width;
+  2342	  const stepX=tw+fs*3.5, stepY=fs*4.2, diag=Math.hypot(W,H);
+  2343	  for(let yy=-diag; yy<diag; yy+=stepY) for(let xx=-diag; xx<diag; xx+=stepX) ctx.fillText(text,xx,yy);
+  2344	  ctx.restore();
+  2345	}
+  2346	
+  2347	/* ───────── manual region selection (drag to redact photo/signature/name) ───────── */
+  2348	let selectMode=false, sel=null;
+  2349	function setSelectMode(on){
+  2350	  selectMode=on;
+  2351	  const btn=$('btnSelect'); if(btn){ btn.classList.toggle('on',on); btn.textContent=on? T().btnSelectOn : T().btnSelect; }
+  2352	  $('preview').classList.toggle('selmode',on);
+  2353	  const hint=$('selHint'); if(hint) hint.style.display=on?'block':'none';
+  2354	}
+  2355	function attachSelect(cv){
+     1	#!/usr/bin/env node
+     2	/*
+     3	 * Golden verification harness for the SafeFile PII pipeline.
+     4	 *
+     5	 * Serves the REAL public/safe/index.html in headless Chrome, drives the live
+     6	 * detection over each fixture, and checks every value against specs.json:
+     7	 *   - MUST_MASK      : value is geometrically covered by an active mask rect
+     8	 *   - MUST_NOT_MASK  : value is NOT covered by any mask rect
+     9	 *   - NEVER_CANDIDATE: value is not proposed as a review candidate
+    10	 *   - SHOULD_CANDIDATE: value surfaces as a candidate (visible, not hidden)
+    11	 *   - AI_INJECT      : adversarial AI labels are neutralised in addEntities
+    12	 *   - TEXT_LEAK      : output PDF has 0 extractable characters
+    13	 *   - OUT_SAFE       : output carries no annots/embedded files/incremental save/EXIF
+    14	 *
+    15	 * Requires: node, playwright (chrome channel). Fixtures from generate_fixtures.py.
+    16	 * Usage: node run.mjs [--only 7_resume_dark.pdf]  (exit 0 = all pass)
+    17	 */
+    18	import { chromium } from 'playwright';
+    19	import http from 'node:http';
+    20	import fs from 'node:fs';
+    21	import path from 'node:path';
+    22	import { fileURLToPath } from 'node:url';
+    23	
+    24	const __dirname = path.dirname(fileURLToPath(import.meta.url));
+    25	const REPO = path.resolve(__dirname, '..', '..');
+    26	const PUBLIC = path.join(REPO, 'public');
+    27	const DOCS = path.join(__dirname, 'testdocs');
+    28	const FIXTURES = path.join(__dirname, 'fixtures');
+    29	const SPECS = JSON.parse(fs.readFileSync(path.join(__dirname, 'specs.json'), 'utf8'));
+    30	const OUT = path.join(__dirname, 'out');
+    31	fs.mkdirSync(OUT, { recursive: true });
+    32	
+    33	const onlyArg = (() => { const i = process.argv.indexOf('--only'); return i >= 0 ? process.argv[i + 1] : null; })();
+    34	
+    35	const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json', '.txt': 'text/plain' };
+    36	
+    37	function startServer() {
+    38	  return new Promise(resolve => {
+    39	    const srv = http.createServer((req, res) => {
+    40	      let p = decodeURIComponent(req.url.split('?')[0]);
+    41	      if (p === '/') p = '/index.html';
+    42	      const fp = path.join(PUBLIC, p);
+    43	      if (!fp.startsWith(PUBLIC) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end('nf'); return; }
+    44	      res.writeHead(200, { 'content-type': MIME[path.extname(fp)] || 'application/octet-stream' });
+    45	      fs.createReadStream(fp).pipe(res);
+    46	    });
+    47	    srv.listen(0, '127.0.0.1', () => resolve(srv));
+    48	  });
+    49	}
+    50	
+    51	// ── in-page helpers, serialised into the browser context ──
+    52	const PAGE_HELPERS = () => {
+    53	  // Active mask rects: every entity that is ON, not 'ok', and located — passed
+    54	  // through bandRect() so the harness measures the pixels that are ACTUALLY
+    55	  // painted (box + padding), not the pre-padding estimate. This makes MUST_MASK
+    56	  // easier and MUST_NOT_MASK harder, which is the honest direction: a padding
+    57	  // that bleeds onto a neighbouring must-keep value now fails the golden.
+    58	  window.__maskRects = function () {
+    59	    const rects = [];
+    60	    for (const e of entities) {
+    61	      if (!isOn(e) || e.mode === 'ok' || !(e.boxes && e.boxes.length)) continue;
+    62	      for (let pi = 0; pi < pages.length; pi++) {
+    63	        for (const l of mergeLineBoxes(e.boxes, pi)) { const r = bandRect(l); rects.push({ pi, x: r.x, y: r.y, w: r.w, h: r.h }); }
+    64	      }
+    65	    }
+    66	    return rects;
+    67	  };
+    68	  window.__rectsFor = function (v) {
+    69	    return boxesForValue(v).map(b => ({ pi: b.page, x: b.x, y: b.y, w: b.w, h: b.h }));
+    70	  };
+    71	  window.__isMasked = function (v) {
+    72	    const mr = window.__maskRects(), vr = window.__rectsFor(v);
+    73	    const ov = (a, b) => {
+    74	      if (a.pi !== b.pi) return 0;
+    75	      const ix = Math.max(0, Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x));
+    76	      const iy = Math.max(0, Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y));
+    77	      return ix * iy;
+    78	    };
+    79	    for (const b of vr) { const area = b.w * b.h; if (area <= 0) continue; for (const a of mr) if (ov(a, b) > area * 0.25) return true; }
+    80	    return false;
+    81	  };
+    82	  const norm = s => (s || '').toLowerCase().replace(/\s+/g, ' ').replace(/[.,;:'"()]+$/g, '').replace(/^[.,;:'"()]+/g, '').trim();
+    83	  window.__norm = norm;
+    84	  window.__entitySnapshot = function () {
+    85	    return entities.map(e => ({ type: e.type, value: e.value, kind: e.kind, mode: e.mode, reason: e.reason, located: !!(e.boxes && e.boxes.length) }));
+    86	  };
+    87	  /* ── JP: geometry is checked against the FIXTURE'S OWN box table, not against
+    88	     a value string. A Japanese form's value is exactly what OCR mangles
+    89	     (美咲 → "S=0%"), so asserting on the string would test Tesseract, not us;
+    90	     the box is what the band has to cover either way. ── */
+    91	  // fraction of `rect` (page coords) covered by the union of active mask rects,
+    92	  // sampled on a grid so overlapping bands count once.
+    93	  window.__coverage = function (rect) {
+    94	    const mr = window.__maskRects().filter(r => r.pi === rect.pi);
+    95	    if (!mr.length) return 0;
+    96	    const N = 24; let hit = 0;
+    97	    for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) {
+    98	      const x = rect.x + rect.w * (i + 0.5) / N, y = rect.y + rect.h * (j + 0.5) / N;
+    99	      if (mr.some(r => x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h)) hit++;
+   100	    }
+   101	    return hit / (N * N);
+   102	  };
+   103	  // OCR/text item boxes whose centre falls inside `rect`
+   104	  window.__itemsIn = function (rect) {
+   105	    const p = pages[rect.pi]; if (!p) return [];
+   106	    return (p.items || []).filter(it => it.x + it.w / 2 >= rect.x && it.x + it.w / 2 <= rect.x + rect.w
+   107	                                     && it.y + it.h / 2 >= rect.y && it.y + it.h / 2 <= rect.y + rect.h)
+   108	      .map(it => ({ pi: rect.pi, x: it.x, y: it.y, w: it.w, h: it.h }));
+   109	  };
+   110	  // any ACTIVE candidate entity overlapping `rect` (did the field surface for review?)
+   111	  window.__candidateOver = function (rect) {
+   112	    for (const e of entities) {
+   113	      if (e.kind !== 'candidate' || !e.boxes) continue;
+   114	      for (const b of e.boxes) {
+   115	        if (b.page !== rect.pi) continue;
+   116	        if (!(b.x + b.w < rect.x || rect.x + rect.w < b.x || b.y + b.h < rect.y || rect.y + rect.h < b.y)) return true;
+   117	      }
+   118	    }
+   119	    return false;
+   120	  };
+   121	  window.__jpState = function () {
+   122	    return { cls: jpState.cls && { doc: jpState.cls.doc, side: jpState.cls.side || null, score: jpState.cls.score },
+   123	      purpose: jpState.purpose, pw: pages.map(p => p.w),
+   124	      fields: entities.filter(e => e.jp).map(e => ({ field: e.jp.field, level: e.jp.level, note: e.jp.note, kind: e.kind, mode: e.mode })) };
+   125	  };
+   126	  window.__isCandidateExact = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value) === n); };
+   127	  window.__isCandidateContains = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value).includes(n)); };
+   128	  // default mode of the candidate whose value contains v (null if not a candidate)
+   129	  window.__candidateMode = function (v) { const n = norm(v); const e = entities.find(x => x.kind === 'candidate' && norm(x.value).includes(n)); return e ? e.mode : null; };
+   130	  // name-bar geometry: glyph union (raw pdf items) vs drawn bar rect
+   131	  window.__nameBar = function (v) {
+   132	    const rects = boxesForValue(v).filter(b => b.page === 0);
+   133	    if (!rects.length) return null;
+   134	    const lines = mergeLineBoxes(rects, 0); const bar = lines[0];
+   135	    // glyph union straight from page items overlapping the value
+   136	    const its = (pages[0].items || []).filter(it => (v.split(/\s+/).some(w => (it.str || '').includes(w))));
+   137	    if (!its.length) return null;
+   138	    const gx0 = Math.min(...its.map(i => i.x)), gy0 = Math.min(...its.map(i => i.y));
+   139	    const gx1 = Math.max(...its.map(i => i.x + i.w)), gy1 = Math.max(...its.map(i => i.y + i.h));
+   140	    const gW = gx1 - gx0, gH = gy1 - gy0;
+   141	    // replicate the drawn-band geometry exactly as the page would paint it.
+   142	    const drawn = bandRect(bar);
+   143	    // Ink safety: the bar must cover the full glyph WIDTH and, vertically, the
+   144	    // cap-height→descent band (raw pdf font box minus the top ascent gap where
+   145	    // no ink lives). It should NOT need to cover the empty ascent whitespace.
+   146	    const inkTop = gy0 + gH * 0.18, inkBot = gy1;
+   147	    const coversInk = drawn.x <= gx0 + 1 && drawn.x + drawn.w >= gx1 - 1 && drawn.y <= inkTop + 1 && drawn.y + drawn.h >= inkBot - 1;
+   148	    return { barW: bar.w, barH: bar.h, drawnH: drawn.h, drawnW: drawn.w, glyphW: gW, glyphH: gH, containsGlyph: coversInk };
+   149	  };
+   150	};
+   151	
+   152	// `jp/...` paths resolve under fixtures/, everything else under testdocs/.
+   153	const docPath = file => file.startsWith('jp/') ? path.join(FIXTURES, file) : path.join(DOCS, file);
+   154	async function loadDoc(page, file, ocr) {
+   155	  await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
+   156	  await page.setInputFiles('#fileInput', docPath(file));
+   157	  await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0, { timeout: ocr ? 240000 : 40000 });
+   158	  await page.waitForTimeout(ocr ? 800 : 400);
+   159	  await page.evaluate(PAGE_HELPERS);
+   160	}
+   161	
+   162	const rows = [];
+   163	const rec = (doc, cat, item, expected, actual, pass, info = false) => rows.push({ doc, cat, item, expected, actual, pass, info });
+   164	
+   165	async function checkDoc(page, spec) {
+   166	  const { doc, ocr } = spec;
+   167	  await loadDoc(page, doc, ocr);
+   168	  const snap = await page.evaluate(() => window.__entitySnapshot());
+   169	  const autoCount = snap.filter(e => e.kind === 'auto').length;
+   170	  process.stderr.write(`    [autoCount] ${doc} = ${autoCount}\n`);
+   171	  if (spec.min_auto != null) rec(doc, 'REGRESSION', `auto>=${spec.min_auto}`, `>=${spec.min_auto}`, String(autoCount), autoCount >= spec.min_auto);
+   172	  // False-positive regression guard: a hard CEILING on auto-detected entities.
+   173	  // The golden's MUST_MASK checks catch "did we mask what we should"; max_auto
+   174	  // catches the inverse — a detection change that starts auto-masking body text
+   175	  // (the résumé-defect class where 95/95 passed while the body got shredded).
+   176	  if (spec.max_auto != null) rec(doc, 'REGRESSION', `auto<=${spec.max_auto}`, `<=${spec.max_auto}`, String(autoCount), autoCount <= spec.max_auto);
+   177	
+   178	  // Turn a name candidate ON (hide → solid) so must_mask can assert the whole
+   179	  // name — surname included — is geometrically covered once the user activates it.
+   180	  if (spec.activate_name) {
+   181	    const ok = await page.evaluate(v => {
+   182	      const e = entities.find(x => x.value === v && x.type === 'name');
+   183	      if (!e) return false;
+   184	      e.mode = 'no'; renderAll(); return true;
+   185	    }, spec.activate_name);
+   186	    rec(doc, 'NAME_WHOLE', spec.activate_name, 'detected-whole', ok ? 'detected' : 'MISSING/truncated', ok);
+   187	  }
+   188	
+   189	  for (const v of spec.must_mask || []) {
+   190	    const masked = await page.evaluate(x => window.__isMasked(x), v);
+   191	    rec(doc, 'MUST_MASK', v, 'masked', masked ? 'masked' : 'NOT masked', masked);
+   192	  }
+   193	  for (const v of spec.must_not_mask || []) {
+   194	    const masked = await page.evaluate(x => window.__isMasked(x), v);
+   195	    rec(doc, 'MUST_NOT_MASK', v, 'clear', masked ? 'MASKED' : 'clear', !masked);
+   196	  }
+   197	  for (const v of spec.never_candidate || []) {
+   198	    const isCand = await page.evaluate(x => window.__isCandidateExact(x), v);
+   199	    rec(doc, 'NEVER_CANDIDATE', v, 'not-cand', isCand ? 'CANDIDATE' : 'not-cand', !isCand);
+   200	  }
+   201	  for (const v of spec.should_candidate || []) {
+   202	    // A candidate must SURFACE as a review candidate. (Its default redaction level
+   203	    // — name/address candidates now default to 'half' — is asserted separately by
+   204	    // CANDIDATE_MODE; "surfaced" is no longer coupled to "left in the clear".)
+   205	    const isCand = await page.evaluate(x => window.__isCandidateContains(x), v);
+   206	    rec(doc, 'SHOULD_CANDIDATE', v, 'candidate', isCand ? 'candidate' : 'missing', isCand);
+   207	  }
+   208	  // Candidate default-mode policy: name/address candidates default to 'half' so the
+   209	  // "확인 필요" label matches a visibly-partial state. Old code defaulted them to 'ok'.
+   210	  for (const [v, exp] of Object.entries(spec.candidate_mode || {})) {
+   211	    const mode = await page.evaluate(x => window.__candidateMode(x), v);
+   212	    rec(doc, 'CANDIDATE_MODE', v, exp, mode || 'not-candidate', mode === exp);
+   213	  }
+   214	  if (spec.name_bar) {
+   215	    const nb = await page.evaluate(x => window.__nameBar(x), spec.name_bar);
+   216	    if (nb) {
+   217	      const ratioH = nb.drawnH / nb.glyphH;
+   218	      const ok = nb.containsGlyph && ratioH <= 1.5;
+   219	      rec(doc, 'NAME_BAR', spec.name_bar, 'tight&contains', `hRatio=${ratioH.toFixed(2)} contains=${nb.containsGlyph}`, ok);
+   220	    } else rec(doc, 'NAME_BAR', spec.name_bar, 'measurable', 'no-boxes', false);
+   221	  }
+   222	  if (spec.dark_bg_value) {
+   223	    const dk = await page.evaluate(v => { const e = entities.find(x => x.value === v); const bg = e && e.boxes[0] ? e.boxes[0].bg : null; return { bg, dark: bg ? isDarkColor(bg) : null }; }, spec.dark_bg_value);
+   224	    rec(doc, 'DARK_BG', spec.dark_bg_value, 'dark bg detected', `${dk.bg} dark=${dk.dark}`, dk.dark === true, true);
+   225	  }
+   226	  for (const fmt of (spec.out_formats || (spec.type === 'pdf' ? ['pdf'] : []))) {
+   227	    await checkOutput(page, doc, fmt);
+   228	  }
+   229	}
+   230	
+   231	/* ── output safety ──────────────────────────────────────────────────────────
+   232	   What the user ships is the output file, not our preview. Three separate ways
+   233	   a redacted-looking file still carries the original:
+   234	     1. a text layer under the ink (the classic "透ける黒塗り"),
+   235	     2. metadata the renderer never shows — EXIF/XMP/IPTC on images, annotations
+   236	        or embedded files in a PDF,
+   237	     3. an incrementally-saved PDF, where the PREVIOUS revision (unredacted) is
+   238	        still physically present earlier in the same byte stream.
+   239	   Each needs its own probe: pdf.js text extraction catches (1) and is blind to
+   240	   (2) and (3). So we read the produced BYTES. */
+   241	const MARKERS = {
+   242	  // PNG: every ancillary text/EXIF chunk type. Canvas encodes none of these, but
+   243	  // "it currently doesn't" is not a guarantee — assert it.
+   244	  png: [['eXIf', 'EXIF chunk'], ['tEXt', 'tEXt chunk'], ['zTXt', 'zTXt chunk'], ['iTXt', 'iTXt chunk']],
+   245	  // ICC_PROFILE is deliberately NOT forbidden: Chrome's JPEG encoder attaches a
+   246	  // 456-byte generic sRGB profile (tags: desc/rXYZ/gXYZ/bXYZ/wtpt/rTRC/cprt —
+   247	  // measured, no device identifiers). That is a colour space declaration, not
+   248	  // document content and not an identifier. What WOULD be a leak is the
+   249	  // viewer's *display* profile, which carries manufacturer/model tags and is
+   250	  // much larger — iccSafe() below bounds exactly that.
+   251	  jpg: [['Exif\0\0', 'EXIF APP1'], ['http://ns.adobe.com/xap/', 'XMP APP1'], ['Photoshop 3.0\0', 'IPTC APP13']],
+   252	  pdf: [['/Annots', 'annotation'], ['/EmbeddedFile', 'embedded file'], ['/XFA', 'XFA form'], ['/AcroForm', 'form fields'], ['/Names', 'name tree']],
+   253	};
+   254	function scanMarkers(buf, kind) {
+   255	  const hay = buf.toString('latin1');
+   256	  return MARKERS[kind].filter(([m]) => hay.includes(m)).map(([, label]) => label);
+   257	}
+   258	// An embedded ICC profile is acceptable only while it stays a generic colour
+   259	// space. A display profile (which identifies the machine that produced the file)
+   260	// is large and carries the device manufacturer / model description tags.
+   261	const ICC_MAX = 2048;
+   262	function iccSafe(buf) {
+   263	  const hay = buf.toString('latin1');
+   264	  const at = hay.indexOf('ICC_PROFILE\0');
+   265	  if (at < 0) return { ok: true, note: 'absent' };
+   266	  const size = buf.readUInt32BE(at + 14);          // profile header: byte 0..3 = size
+   267	  const body = hay.slice(at + 14, at + 14 + Math.min(size, 65535));
+   268	  const dev = ['dmnd', 'dmdd'].filter(t => body.includes(t));
+   269	  const ok = size <= ICC_MAX && dev.length === 0;
+   270	  return { ok, note: `${size}B${dev.length ? ' +' + dev.join('/') : ''}` };
+   271	}
+   272	async function checkOutput(page, doc, fmt) {
+   273	  const tag = `OUT_${fmt.toUpperCase()}`;
+   274	  try {
+   275	    await page.evaluate(f => { const r = document.querySelector(`input[name=fmt][value="${f}"]`); if (r) r.checked = true; }, fmt);
+   276	    // force at least one masked, located entity so Make is enabled
+   277	    await page.evaluate(() => { const e = entities.find(x => isOn(x) && x.boxes && x.boxes.length); if (e) e.mode = 'no'; renderAll(); });
+   278	    await page.click('#btnMake');
+   279	    await page.waitForSelector('#result', { state: 'visible', timeout: 60000 });
+   280	    const dl = await Promise.all([
+   281	      page.waitForEvent('download', { timeout: 30000 }),
+   282	      page.click('#btnDownload'),
+   283	    ]).then(a => a[0]).catch(() => null);
+   284	    if (!dl) { rec(doc, tag, `output ${fmt}`, 'clean', 'no-download', false); return; }
+   285	    const fp = path.join(OUT, doc.replace(/[\/\\]/g, '_').replace(/\.\w+$/, `_out.${fmt}`));
+   286	    await dl.saveAs(fp);
+   287	    const buf = fs.readFileSync(fp);
+   288	
+   289	    if (fmt === 'pdf') {
+   290	      const chars = await page.evaluate(async (b64) => {
+   291	        const bin = atob(b64); const arr = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
+   292	        const pdf = await pdfjsLib.getDocument({ data: arr }).promise;
+   293	        let n = 0;
+   294	        for (let p = 1; p <= pdf.numPages; p++) { const tc = await (await pdf.getPage(p)).getTextContent(); n += tc.items.reduce((s, it) => s + (it.str || '').replace(/\s/g, '').length, 0); }
+   295	        return n;
+   296	      }, buf.toString('base64'));
+   297	      rec(doc, 'TEXT_LEAK', `output ${fmt}`, '0 chars', `${chars} chars`, chars === 0);
+   298	      // One %%EOF means one revision. An incremental save appends a second body
+   299	      // + xref + %%EOF, leaving revision 1 (pre-redaction) readable in the file.
+   300	      const eofs = (buf.toString('latin1').match(/%%EOF/g) || []).length;
+   301	      rec(doc, tag, `output ${fmt} revisions`, '1 %%EOF', `${eofs} %%EOF`, eofs === 1);
+   302	    }
+   303	    const hits = scanMarkers(buf, fmt);
+   304	    rec(doc, tag, `output ${fmt} metadata`, 'none', hits.length ? hits.join('+') : 'none', hits.length === 0);
+   305	    if (fmt === 'jpg') { const icc = iccSafe(buf); rec(doc, tag, `output ${fmt} ICC`, `generic <=${ICC_MAX}B`, icc.note, icc.ok); }
+   306	  } catch (e) { rec(doc, tag, `output ${fmt}`, 'clean', 'ERR:' + e.message.split('\n')[0], false); }
+   307	}
+   308	
+   309	async function checkAiInject(page) {
+   310	  const inj = SPECS.ai_inject; if (!inj) return;
+   311	  await loadDoc(page, inj._doc, false);
+   312	  for (const c of inj.cases) {
+   313	    // fresh reload so each case is isolated
+   314	    await loadDoc(page, inj._doc, false);
+   315	    const res = await page.evaluate((ent) => {
+   316	      const before = entities.length;
+   317	      addEntities([ent]);
+   318	      const added = entities.slice(before);
+   319	      const mine = added.find(e => e.value === ent.value) || entities.find(e => e.value === ent.value && e.kind !== 'candidate' && e.type !== 'name-candidate');
+   320	      const masked = window.__isMasked(ent.value);
+   321	      return { present: !!mine, type: mine ? mine.type : null, mode: mine ? mine.mode : null, masked };
+   322	    }, c.entity);
+   323	    let pass, actual;
+   324	    if (c.expect === 'masked') { pass = res.masked; actual = res.masked ? 'masked' : `not-masked(${res.type}/${res.mode})`; }
+   325	    else if (c.expect === 'dropped') { pass = !res.present && !res.masked; actual = res.present ? `KEPT(${res.type}/${res.mode})` : 'dropped'; }
+   326	    else { pass = !res.masked; actual = res.masked ? 'MASKED' : `visible(${res.type || 'dropped'}/${res.mode || '-'})`; }
+   327	    rec('7_resume_dark.pdf', 'AI_INJECT', c.label + ` [${c.entity.type}:${c.entity.value}]`, c.expect, actual, pass);
+   328	  }
+   329	}
+   330	
+   331	async function checkAiCatState(page) {
+   332	  const cs = SPECS.ai_cat_state; if (!cs) return;
+   333	  await loadDoc(page, cs._doc, false);
+   334	  const res = await page.evaluate(({ labels, want }) => {
+   335	    // record active state BEFORE the AI merge, then inject AI labels
+   336	    const before = {}; for (const t of want) before[t] = catEnabled[t] !== false;
+   337	    addEntities(labels); renderAll();
+   338	    const after = {}, boxChecked = {};
+   339	    for (const t of want) {
+   340	      after[t] = catEnabled[t] !== false;
+   341	      const cb = document.querySelector(`#piiList input[data-cat="${t}"]`);
+   342	      boxChecked[t] = cb ? cb.checked : null; // null = row not rendered (still a fail signal)
+   343	    }
+   344	    return { before, after, boxChecked };
+   345	  }, { labels: cs.labels, want: cs.assert_enabled });
+   346	  for (const t of cs.assert_enabled) {
+   347	    const pass = res.after[t] === true && res.boxChecked[t] === true;
+   348	    rec(cs._doc, 'AI_CAT_STATE', `${t} stays enabled`, 'on+checked',
+   349	      `enabled=${res.after[t]} checked=${res.boxChecked[t]}`, pass);
+   350	  }
+   351	}
+   352	
+   353	async function checkCandidateDedup(page) {
+   354	  const cd = SPECS.candidate_dedup; if (!cd) return;
+   355	  for (const c of cd.cases) {
+   356	    await loadDoc(page, cd._doc, false);   // fresh load so the base candidate is present
+   357	    const res = await page.evaluate(({ cand, confirm }) => {
+   358	      const before = window.__isCandidateContains(cand);
+   359	      addEntities([confirm]); renderAll();
+   360	      const after = window.__isCandidateContains(cand);
+   361	      // Dedup must be directional: it removes redundant CANDIDATES, never the
+   362	      // CONFIRMED entity that contains them. A reversed containment test (or a
+   363	      // mutual-removal bug) would delete the confirmed name — leaving the value
+   364	      // wholly UNMASKED. Assert the confirmed entity is still present after dedup.
+   365	      // (Location isn't asserted here: these cases inject a superset value with a
+   366	      // token absent from the fixture, so it is intentionally unlocated.)
+   367	      const nc = window.__norm(confirm.value);
+   368	      const confEnt = window.__entitySnapshot().find(e => e.kind !== 'candidate' && window.__norm(e.value) === nc);
+   369	      return { before, after, confirmedSurvives: !!confEnt };
+   370	    }, { cand: c.candidate, confirm: c.confirm });
+   371	    let pass, actual;
+   372	    if (c.expect === 'removed') {
+   373	      pass = res.before && !res.after;
+   374	      actual = !res.before ? 'not-present-before' : (res.after ? 'STILL present' : 'removed');
+   375	    } else { // kept
+   376	      pass = res.before && res.after;
+   377	      actual = !res.before ? 'not-present-before' : (res.after ? 'kept' : 'DROPPED');
+   378	    }
+   379	    rec(cd._doc, 'CANDIDATE_DEDUP', `${c.label} [${c.confirm.value}]`, c.expect, actual, pass);
+   380	    // Confirmed-preservation guard (the regression the candidate-only test missed):
+   381	    // the confirmed entity that triggered the dedup must SURVIVE it.
+   382	    rec(cd._doc, 'CONFIRMED_SURVIVES', `confirmed kept [${c.confirm.value}]`, 'survives',
+   383	      res.confirmedSurvives ? 'survives' : 'REMOVED', res.confirmedSurvives);
+   384	  }
+   385	}
+   386	
+   387	/* ── JP golden ───────────────────────────────────────────────────────────────
+   388	   Each JP fixture ships its own specs.json with a BOX TABLE in PNG pixel
+   389	   coordinates plus, per 提出目的, which boxes must be hidden / recommended /
+   390	   optional / kept. The harness replays that table against the live pipeline.
+   391	
+   392	   Coordinate frames: a PNG loads at its natural size, a PDF renders at
+   393	   min(2.2, 1500/ptWidth) — so the mapping is a single uniform scale, taken at
+   394	   runtime from page.w / fixtureWidth rather than hard-coded. A JPG fixture is
+   395	   deliberately rotated and blurred (a phone photo), so its OCR boxes do NOT
+   396	   land on the PNG coordinates; those cases assert at FIELD level instead and
+   397	   say so, rather than quietly comparing coordinates that cannot match.
+   398	
+   399	   Which assertion a box gets comes from the LEGAL MATRIX level, not from which
+   400	   list the fixture put it in — `mask` holds everything the purpose hides, at
+   401	   both the automatic and the recommended strength, and those are different
+   402	   promises. specs.json carries the key→level mapping (jp_auto_fields) so the
+   403	   harness derives it independently of the app it is testing. */
+   404	const JP_COVER_MIN = 0.6;      // a band must cover this much of a value/box
+   405	const JP_KEEP_MAX = 0.10;      // a keep field may not be grazed by more than this
+   406	function jpFieldOf(key) { return key.replace(/^m\d+_/, ''); }
+   407	async function jpCheckBox(page, doc, cat, key, rect, kind) {
+   408	  const items = await page.evaluate(r => window.__itemsIn(r), rect);
+   409	  let frac, what;
+   410	  if (items.length) {
+   411	    // The meaningful question for a box holding text is whether the TEXT is
+   412	    // covered — not whether the generator's padding around it was painted.
+   413	    const fr = await Promise.all(items.map(it => page.evaluate(r => window.__coverage(r), it)));
+   414	    frac = Math.min(...fr); what = `${items.length} item(s) min ${(frac * 100).toFixed(0)}%`;
+   415	  } else {
+   416	    frac = await page.evaluate(r => window.__coverage(r), rect); what = `area ${(frac * 100).toFixed(0)}%`;
+   417	  }
+   418	  if (kind === 'keep') { rec(doc, 'JP_KEEP', key, `<=${JP_KEEP_MAX * 100}%`, what, frac <= JP_KEEP_MAX); return; }
+   419	  const covered = frac >= JP_COVER_MIN;
+   420	  if (kind === 'mask') { rec(doc, 'JP_MASK', key, `>=${JP_COVER_MIN * 100}%`, what, covered); return; }
+   421	  const cand = await page.evaluate(r => window.__candidateOver(r), rect);
+   422	  if (kind === 'candidate') { rec(doc, 'JP_CANDIDATE', key, 'surfaced', cand ? (covered ? 'candidate+banded' : 'candidate') : 'MISSING', cand); return; }
+   423	  if (kind === 'mask_or_candidate') {
+   424	    rec(doc, 'JP_MASK_OR_CAND', key, 'banded or candidate', covered ? 'banded' : cand ? 'candidate' : 'NEITHER', covered || cand); return;
+   425	  }
+   426	  if (kind === 'optional') {   // detected, offered, and OFF until the user says so
+   427	    rec(doc, 'JP_OPTIONAL', key, 'offered+clear', cand ? (frac <= JP_KEEP_MAX ? 'offered+clear' : 'OFFERED BUT BANDED') : 'MISSING', cand && frac <= JP_KEEP_MAX);
+   428	  }
+   429	}
+   430	async function checkJpDoc(page, spec) {
+   431	  const fx = JSON.parse(fs.readFileSync(path.join(__dirname, spec.fixture), 'utf8'));
+   432	  const autoFields = (SPECS.jp_auto_fields || {})[spec.expect_doc] || [];
+   433	  const mocFields = SPECS.jp_candidate_or_mask || [];
+   434	  for (const c of spec.cases) {
+   435	    const tag = `${spec.doc} [${c.purpose}]`;
+   436	    await loadDoc(page, spec.doc, true);
+   437	    await page.evaluate(p => jpSetPurpose(p), c.purpose);
+   438	    const st = await page.evaluate(() => window.__jpState());
+   439	    rec(tag, 'JP_CLASS', spec.expect_doc + (spec.expect_side ? '/' + spec.expect_side : ''), 'classified',
+   440	      st.cls ? st.cls.doc + (st.cls.side ? '/' + st.cls.side : '') + ' sc=' + st.cls.score : 'NOT classified',
+   441	      !!st.cls && st.cls.doc === spec.expect_doc && (!spec.expect_side || st.cls.side === spec.expect_side));
+   442	    if (!st.cls) continue;
+   443	    const autoCount = await page.evaluate(() => entities.filter(e => e.kind === 'auto').length);
+   444	    process.stderr.write(`    [jp autoCount] ${tag} = ${autoCount}\n`);
+   445	    if (c.min_auto != null) rec(tag, 'REGRESSION', `auto>=${c.min_auto}`, `>=${c.min_auto}`, String(autoCount), autoCount >= c.min_auto);
+   446	    if (c.max_auto != null) rec(tag, 'REGRESSION', `auto<=${c.max_auto}`, `<=${c.max_auto}`, String(autoCount), autoCount <= c.max_auto);
+   447	
+   448	    // Field-level: every required field must have been FOUND. This is the only
+   449	    // assertion a rotated phone-photo fixture can make, and it is also the one
+   450	    // the 미탐 0 gate is actually about.
+   451	    const got = new Set(st.fields.map(f => f.field));
+   452	    for (const f of (c.require_fields || [])) rec(tag, 'JP_FIELD', f, 'detected', got.has(f) ? 'detected' : 'MISSING', got.has(f));
+   453	    for (const f of (c.require_banded || [])) {
+   454	      const on = st.fields.some(x => x.field === f && x.mode !== 'ok');
+   455	      rec(tag, 'JP_BANDED', f, 'banded', on ? 'banded' : (got.has(f) ? 'DETECTED BUT CLEAR' : 'MISSING'), on);
+   456	    }
+   457	    // The inverse of require_banded, and the half that makes a purpose-gate test
+   458	    // mean something: without it, "banded under 相談用共有" could be true simply
+   459	    // because the field is banded under every purpose.
+   460	    for (const f of (c.require_clear || [])) {
+   461	      const hits = st.fields.filter(x => x.field === f);
+   462	      const clear = hits.length > 0 && hits.every(x => x.mode === 'ok');
+   463	      rec(tag, 'JP_CLEAR', f, 'detected+clear', hits.length ? (clear ? 'detected+clear' : 'BANDED') : 'MISSING', clear);
+   464	    }
+   465	    if (spec.geometry === false || c.geometry === false) continue;
+   466	
+   467	    const P = fx.purposes[c.key];
+   468	    if (!P) { rec(tag, 'JP_SPEC', c.key, 'purpose in fixture', 'MISSING', false); continue; }
+   469	    const scale = st.pw[0] / fx.size[0];
+   470	    let checked = 0;
+   471	    const box = k => { const b = fx.boxes_png[k]; return b && { pi: 0, x: b[0] * scale, y: b[1] * scale, w: (b[2] - b[0]) * scale, h: (b[3] - b[1]) * scale }; };
+   472	    const seen = new Set(); const skipped = [];
+   473	    const run = async (keys, kindFor) => {
+   474	      for (const k of (keys || [])) {
+   475	        if (k === 'ALL' || seen.has(k)) continue;
+   476	        const r = box(k);
+   477	        // The fixture's purpose list is shared across variants of the same
+   478	        // document, so a key absent from THIS variant is not a case — but it is
+   479	        // REPORTED, never silently dropped. A harness that quietly checks zero
+   480	        // boxes prints the same green as one that checked forty.
+   481	        if (!r) { skipped.push(k); continue; }
+   482	        seen.add(k);
+   483	        await jpCheckBox(page, tag, null, k, r, kindFor(k));
+   484	        checked++;
+   485	      }
+   486	    };
+   487	    // whole-face rule (マイナカード裏面 under a 本人確認 purpose)
+   488	    if ((P.mask || []).includes('ALL')) {
+   489	      const pg = await page.evaluate(() => ({ pi: 0, x: 0, y: 0, w: pages[0].w, h: pages[0].h }));
+   490	      await jpCheckBox(page, tag, null, 'ALL(face)', pg, 'mask');
+   491	      checked++;
+   492	      for (const k of Object.keys(fx.boxes_png)) { const r = box(k); if (r) { await jpCheckBox(page, tag, null, k, r, 'mask'); checked++; } }
+   493	      seen.add('ALL');
+   494	    }
+   495	    await run(P.mask, k => mocFields.includes(jpFieldOf(k)) ? 'mask_or_candidate'
+   496	                        : autoFields.includes(jpFieldOf(k)) ? 'mask' : 'candidate');
+   497	    await run(P.recommend, () => 'candidate');
+   498	    await run(P.optional, () => 'optional');
+   499	    await run(P.keep === 'all' ? [] : P.keep, () => 'keep');
+   500	    rec(tag, 'JP_COVERAGE', `boxes checked (skipped: ${skipped.join(',') || 'none'})`, '>0', String(checked), checked > 0);
+   501	    for (const fmt of (c.out_formats || [])) await checkOutput(page, tag, fmt);
+   502	  }
+   503	}
+   504	
+   505	/* ── JP unit rules ──────────────────────────────────────────────────────────
+   506	   Two detection rules cannot be exercised by the alpha fixtures: none of the
+   507	   four documents carries a phone number, and on all four the 住所 is a KEEP
+   508	   field, so the address hierarchy's own scoring never decides anything there.
+   509	   Shipping them with no coverage at all would be shipping untested detection,
+   510	   so they are pinned at unit level against crafted strings — stated as such
+   511	   rather than left to look like fixture coverage. */
+   512	async function checkJpUnits(page) {
+   513	  const U = SPECS.jp_units; if (!U) return;
+   514	  for (const c of (U.address || [])) {
+   515	    const got = await page.evaluate(t => {
+   516	      const sp = jpAddressSpan(t, 0);
+   517	      return sp ? { span: t.slice(sp.a, sp.b), score: sp.score, strong: !!(sp.postal && sp.pref) } : null;
+   518	    }, c.text);
+   519	    const ok = c.expect === null ? (got === null || got.score < 3)
+   520	      : !!got && got.span === c.expect.span && got.score === c.expect.score && got.strong === !!c.expect.strong;
+   521	    rec('(jp units)', 'JP_ADDRESS', c.label, c.expect === null ? 'no address' : `${c.expect.span} s=${c.expect.score}${c.expect.strong ? ' strong' : ''}`,
+   522	      got ? `${got.span} s=${got.score}${got.strong ? ' strong' : ''}` : 'none', ok);
+   523	  }
+   524	  for (const c of (U.tel || [])) {
+   525	    const got = await page.evaluate(t => {
+   526	      const hy = JP_TEL_HYPHEN_RE.exec(t), pl = hy ? null : JP_TEL_PLAIN_RE.exec(t);
+   527	      const m = hy || pl; return m ? { v: m[0], loose: !hy } : null;
+   528	    }, c.text);
+   529	    const ok = c.expect === null ? got === null
+   530	      : !!got && got.v === c.expect.v && got.loose === !!c.expect.loose;
+   531	    rec('(jp units)', 'JP_TEL', c.label, c.expect === null ? 'no match' : `${c.expect.v}${c.expect.loose ? ' (candidate)' : ''}`,
+   532	      got ? `${got.v}${got.loose ? ' (candidate)' : ''}` : 'none', ok);
+   533	  }
+   534	}
+   535	
+   536	function printTable() {
+   537	  const pad = (s, n) => { s = String(s); return s.length > n ? s.slice(0, n - 1) + '…' : s.padEnd(n); };
+   538	  let lastDoc = '';
+   539	  console.log('\n' + '═'.repeat(120));
+   540	  console.log(pad('DOC', 20) + pad('CATEGORY', 17) + pad('ITEM', 40) + pad('EXPECTED', 18) + pad('ACTUAL', 18) + 'RESULT');
+   541	  console.log('─'.repeat(120));
+   542	  for (const r of rows) {
+   543	    if (r.doc !== lastDoc) { console.log('─'.repeat(120)); lastDoc = r.doc; }
+   544	    const mark = r.info ? (r.pass ? 'ℹ ok' : 'ℹ note') : (r.pass ? '✅ PASS' : '❌ FAIL');
+   545	    console.log(pad(r.doc, 20) + pad(r.cat, 17) + pad(r.item, 40) + pad(r.expected, 18) + pad(r.actual, 18) + mark);
+   546	  }
+   547	  console.log('═'.repeat(120));
+   548	  const gating = rows.filter(r => !r.info);
+   549	  const fails = gating.filter(r => !r.pass);
+   550	  const byCat = {};
+   551	  for (const r of gating) { byCat[r.cat] = byCat[r.cat] || { p: 0, f: 0 }; r.pass ? byCat[r.cat].p++ : byCat[r.cat].f++; }
+   552	  console.log('\nSummary by category:');
+   553	  for (const [c, v] of Object.entries(byCat)) console.log(`  ${pad(c, 18)} ${v.p} pass / ${v.f} fail`);
+   554	  console.log(`\n  TOTAL: ${gating.length - fails.length}/${gating.length} pass, ${fails.length} FAIL`);
+   555	  if (fails.length) {
+   556	    console.log('\n  Failing:');
+   557	    for (const r of fails) console.log(`    ✗ [${r.doc}] ${r.cat} — ${r.item}  (expected ${r.expected}, got ${r.actual})`);
+   558	  }
+   559	  return fails.length;
+   560	}
+   561	
+   562	(async () => {
+   563	  const srv = await startServer();
+   564	  const port = srv.address().port;
+   565	  const URL = `http://127.0.0.1:${port}/safe/index.html`;
+   566	  const browser = await chromium.launch({ channel: 'chrome', headless: true });
+   567	  const ctx = await browser.newContext({ acceptDownloads: true, locale: 'ko-KR', viewport: { width: 1200, height: 900 } });
+   568	  const page = await ctx.newPage();
+   569	  const consoleErrors = [];
+   570	  page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
+   571	  page.on('pageerror', e => consoleErrors.push('PageError: ' + e.message));
+   572	  await page.goto(URL, { waitUntil: 'networkidle' });
+   573	  await page.evaluate(() => { LANG = 'ko'; applyLang(); });
+   574	
+   575	  const docs = SPECS.docs.filter(d => !onlyArg || d.doc === onlyArg);
+   576	  for (const spec of docs) {
+   577	    process.stderr.write(`… ${spec.doc}\n`);
+   578	    try { await checkDoc(page, spec); }
+   579	    catch (e) { rec(spec.doc, 'LOAD', spec.doc, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
+   580	  }
+   581	  for (const spec of (SPECS.jp_docs || [])) {
+   582	    if (onlyArg && spec.doc !== onlyArg) continue;
+   583	    process.stderr.write(`… ${spec.doc}\n`);
+   584	    // The JP presets only exist in the Japanese UI, and OCR language follows it.
+   585	    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
+   586	    try { await checkJpDoc(page, spec); }
+   587	    catch (e) { rec(spec.doc, 'LOAD', spec.doc, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
+   588	    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
+   589	  }
+   590	  if (!onlyArg || onlyArg === '(jp units)') { process.stderr.write('… jp units\n'); await checkJpUnits(page); }
+   591	  if (!onlyArg || onlyArg === '7_resume_dark.pdf') { process.stderr.write('… ai_inject\n'); await checkAiInject(page); }
+   592	  if (!onlyArg || onlyArg === '7_resume_dark.pdf') { process.stderr.write('… ai_cat_state\n'); await checkAiCatState(page); }
+   593	  if (!onlyArg || onlyArg === (SPECS.candidate_dedup && SPECS.candidate_dedup._doc)) { process.stderr.write('… candidate_dedup\n'); await checkCandidateDedup(page); }
+   594	
+   595	  const failCount = printTable();
+   596	  if (consoleErrors.length) { console.log('\n  ⚠ console errors:'); consoleErrors.slice(0, 10).forEach(e => console.log('    ' + e)); }
+   597	  fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify({ rows, consoleErrors }, null, 2));
+   598	
+   599	  await browser.close(); srv.close();
+   600	  process.exit(failCount ? 1 : 0);
+   601	})().catch(e => { console.error(e); process.exit(2); });
+     1	{
+     2	  "_readme": "Golden specification for the SafeFile PII pipeline. Each doc lists values that MUST be masked, MUST NOT be masked (geometrically covered), and values that should surface only as review CANDIDATES. Checked headlessly by run.mjs against the live detection in public/safe/index.html. never_candidate = value must not be proposed as a candidate at all. ai_inject = adversarial AI-label cases fed to addEntities (reproduces the real-doc name/country/org false positives without a live API).",
+     3	
+     4	  "_band_only": "2026-10-21: masking is band-only — a value is shown ('ok') or covered by an opaque band ('no'). The partial/asterisk mode and its PHONE_FORMAT assertions are gone: a partial overlay re-renders part of the secret, so its safety depends on how much we chose to reveal. MUST_MASK / MUST_NOT_MASK keep their meaning exactly (geometric coverage by an active mask rect) — the types that used to default to partial now default to band, which is strictly more covering. CANDIDATE_MODE now asserts 'ok': a review candidate is a guess and must not delete content before the user confirms it.",
+     5	
+     6	  "_max_auto_basis": "max_auto is a per-fixture CEILING on auto-detected entities — the false-positive regression guard. Without it the golden only proved 'we masked what we should' and a detection change shredded résumé body text while 95/95 stayed green. Ceilings measured 2026-07-20 against the fixed pipeline (actual auto counts: 1=9, 2=3, 3=3, 4=5, 5=10, 6=4, 7=2, 8=2). Headroom: deterministic text/table/résumé docs get a TIGHT ceiling (actual + ~2-3) so any new auto-mask of body text (schools, exam/contest names, countries) trips it; OCR docs (2,3) get a LOOSE ceiling (8) because Tesseract counts vary run-to-run and a tight bound would flake. The résumé docs 7/8 (actual 2 = phone+email only; everything else is candidate/excluded) are the primary guard — a ceiling of 4 catches the exact defect class this task fixed.",
+     7	
+     8	  "docs": [
+     9	    {
+    10	      "doc": "1_text.pdf", "type": "pdf", "ocr": false, "min_auto": 5, "max_auto": 12, "out_formats": ["pdf", "png", "jpg"],
+    11	      "must_mask": ["900315-1234567", "010-2345-6789", "minjun.kim@hanmail.net", "010-9876-5432", "123456-04-789012"],
+    12	      "must_not_mask": ["한빛테크"],
+    13	      "should_candidate": [],
+    14	      "never_candidate": ["한빛테크"]
+    15	    },
+    16	    {
+    17	      "doc": "2_scanned.pdf", "type": "pdf", "ocr": true, "min_auto": 3, "max_auto": 8,
+    18	      "must_mask": [], "must_not_mask": [], "should_candidate": [], "never_candidate": []
+    19	    },
+    20	    {
+    21	      "doc": "3_photo.jpg", "type": "image", "ocr": true, "min_auto": 3, "max_auto": 8, "out_formats": ["png", "jpg"],
+    22	      "must_mask": [], "must_not_mask": [], "should_candidate": [], "never_candidate": []
+    23	    },
+    24	    {
+    25	      "doc": "4_table.pdf", "type": "pdf", "ocr": false, "min_auto": 4, "max_auto": 8,
+    26	      "must_mask": ["870915-1234567", "010-3456-7890", "daeho@corp.com", "110-234-567890"],
+    27	      "must_not_mask": [], "should_candidate": [], "never_candidate": []
+    28	    },
+    29	    {
+    30	      "doc": "5_multipage.pdf", "type": "pdf", "ocr": false, "min_auto": 9, "max_auto": 13,
+    31	      "must_mask": ["900315-1234567", "920820-2345678", "880505-1234567", "minjun@a.com", "seoyeon@b.com", "doyoon@c.com"],
+    32	      "must_not_mask": [], "should_candidate": [], "never_candidate": []
+    33	    },
+    34	    {
+    35	      "doc": "6_resume_light.pdf", "type": "pdf", "ocr": false, "min_auto": 3, "max_auto": 7,
+    36	      "must_mask": ["+91 9599320477", "aarav.sharma@gmail.com"],
+    37	      "_note_ai_only": "English street addresses (e.g. 'Signature Global Mall, Sector 84') are detected only by the AI deep-scan path, not the deterministic regex path this harness exercises.",
+    38	      "must_not_mask": ["Delhi University", "Maharaja Agrasen College", "Saket", "Imphal"],
+    39	      "should_candidate": ["Aarav Sharma"],
+    40	      "candidate_mode": {"Aarav Sharma": "ok"},
+    41	      "never_candidate": ["Delhi University", "Maharaja Agrasen College"],
+    42	      "name_bar": "Aarav Sharma"
+    43	    },
+    44	    {
+    45	      "doc": "7_resume_dark.pdf", "type": "pdf", "ocr": false, "min_auto": 2, "max_auto": 4,
+    46	      "must_mask": ["+91 9599320477", "aarav.sharma@gmail.com"],
+    47	      "must_not_mask": [
+    48	        "Delhi University", "Maharaja Agrasen College", "Vidya Niketan School",
+    49	        "King Sejong Institute", "Concern India Foundation", "Korea",
+    50	        "Koreaz Contest", "Imphal", "Saket", "India"
+    51	      ],
+    52	      "should_candidate": ["Aarav Sharma", "Signature Global"],
+    53	      "candidate_mode": {"Aarav Sharma": "ok", "Signature Global": "ok"},
+    54	      "never_candidate": [
+    55	        "Korea", "Maharaja Agrasen College", "Vidya Niketan School",
+    56	        "King Sejong Institute", "Concern India Foundation", "Delhi University", "Imphal"
+    57	      ],
+    58	      "name_bar": "Aarav Sharma",
+    59	      "dark_bg_value": "aarav.sharma@gmail.com"
+    60	    },
+    61	    {
+    62	      "doc": "8_resume_2col.pdf", "type": "pdf", "ocr": false, "min_auto": 2, "max_auto": 4,
+    63	      "_note": "Regression for real-résumé defects: (1) a 3-token name in a 2-column layout whose surname renders slightly smaller must stay whole and be fully maskable (surname included) — activate_name turns the name candidate on, then must_mask asserts every token incl. the surname is covered; (2) a country inside a WRAPPED flowing sentence whose tail line reads 'Republic of Korea (Koreaz Contest)' must not be proposed as an address candidate (the old <=2-word country-anchor cap let the 3-word 'Republic of Korea' slip past); the isolated 'Korea (Koreaz Contest)' line is covered too. Koreaz Contest is a contest name (not PII) and must never be masked.",
+    64	      "activate_name": "Ishan Rohit Malhotra",
+    65	      "must_mask": ["Ishan Rohit Malhotra", "Malhotra", "+91 9599320477", "ishan.malhotra@gmail.com"],
+    66	      "must_not_mask": ["Software Engineer", "Delhi University", "Maharaja Agrasen College", "Koreaz Contest", "Republic of Korea (Koreaz Contest)"],
+    67	      "should_candidate": [],
+    68	      "never_candidate": ["Republic of Korea (Koreaz Contest)", "Korea (Koreaz Contest)", "Korea", "Maharaja Agrasen College", "Delhi University"]
+    69	    },
+    70	    {
+    71	      "doc": "9_resume_2line.pdf", "type": "pdf", "ocr": false, "min_auto": 2, "max_auto": 4,
+    72	      "_note": "Regression for the real-résumé defect where the header name WRAPS onto two visual lines (given names on line 1, surname on its own line 2, same large font). The old name-line assembly grew only horizontally within the anchor row, so it captured 'MANSI GAZAL' and left the whole second line 'TIWARI' exposed — the name surfaced only as a truncated 'MANSI GAZAL' candidate. Detection must assemble the wrapped name whole: the candidate is 'MANSI GAZAL TIWARI' and activating it covers BOTH lines incl. the surname. The smaller-font subtitle 'Software Developer' must NOT be merged into the name (a merge would either mask the subtitle or fail isLikelyName and drop the name).",
+    73	      "activate_name": "MANSI GAZAL TIWARI",
+    74	      "must_mask": ["MANSI GAZAL TIWARI", "TIWARI", "+91 98765 43210", "mansi.tiwari@example.com"],
+    75	      "must_not_mask": ["Software Developer", "Delhi University"],
+    76	      "should_candidate": ["MANSI GAZAL TIWARI"],
+    77	      "never_candidate": ["Software Developer", "Delhi University"]
+    78	    }
+    79	  ],
+    80	
+    81	  "_jp_basis": "JP-1 alpha. Fixtures live in fixtures/jp/<doc>/<variant>.{png,jpg,pdf} with a sibling .specs.json carrying a BOX TABLE in PNG pixels plus, per 提出目的, which boxes the purpose hides / recommends / offers / keeps. The harness replays that table against the live pipeline, so the expectations are the fixture's, not the detector's. PNG and PDF differ from the table by one uniform scale (taken at runtime from page.w / fixture width); the JPG variants are rotated and blurred on purpose (phone photo), so their OCR boxes cannot land on those coordinates and those cases assert at FIELD level instead — detected, and banded — which is what the 미탐 0 gate is actually about.",
+    82	
+    83	  "jp_auto_fields": {
+    84	    "_why": "The fixture's `mask` list holds every box the purpose hides, at BOTH the automatic and the recommended strength — those are different promises, so the harness has to know which is which independently of the app it is testing. This table is the legal matrix's `level` field (jp_legal_matrix_alpha4.json), keyed by fixture box name with the m<N>_ household prefix stripped. Anything NOT listed here that appears under `mask` is level=recommend and is asserted as a surfaced review candidate.",
+    85	    "shikaku_kakuninsho": ["hokensha_bango", "kigo", "bango", "edaban", "hihokensha_bango", "qr"],
+    86	    "unten_menkyo": [],
+    87	    "mynumber_card": ["my_number", "qr"],
+    88	    "juminhyo": ["my_number", "jumin_code"]
+    89	  },
+    90	  "jp_candidate_or_mask": ["my_number"],
+    91	  "_jp_candidate_or_mask_why": "個人番号 is level=auto_with_purpose_gate, but strategy v2 §4 requires every dummy's number to FAIL its check digit (生成 of a valid one is forbidden). A correct implementation must therefore refuse to assert 'this is a 個人番号' and demote the automatic band to a default-ON review candidate. Asserting a hard band here would make the golden reward the wrong behaviour; asserting only a candidate would let a real regression (never detecting it) pass. So: banded OR surfaced, and the demotion reason is checked separately via the entity note.",
+    92	
+    93	  "jp_docs": [
+    94	    { "doc": "jp/shikaku_kakuninsho/kenpo.png", "fixture": "fixtures/jp/shikaku_kakuninsho/kenpo.specs.json", "expect_doc": "shikaku_kakuninsho",
+    95	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "min_auto": 4, "max_auto": 8,
+    96	                  "require_fields": ["kigo", "bango", "edaban", "hokensha_bango", "qr", "sex"],
+    97	                  "require_banded": ["kigo", "bango", "edaban", "hokensha_bango", "qr"],
+    98	                  "out_formats": ["png", "jpg"] }] },
+    99	    { "doc": "jp/shikaku_kakuninsho/kokuho.png", "fixture": "fixtures/jp/shikaku_kakuninsho/kokuho.specs.json", "expect_doc": "shikaku_kakuninsho",
+   100	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "min_auto": 4, "max_auto": 8,
+   101	                  "require_banded": ["kigo", "bango", "edaban", "hokensha_bango", "qr"] }] },
+   102	    { "doc": "jp/shikaku_kakuninsho/kouki.png", "fixture": "fixtures/jp/shikaku_kakuninsho/kouki.specs.json", "expect_doc": "shikaku_kakuninsho",
+   103	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "min_auto": 2, "max_auto": 8,
+   104	                  "require_banded": ["hokensha_bango", "qr"] }] },
+   105	
+   106	    { "doc": "jp/unten_menkyo/front.png", "fixture": "fixtures/jp/unten_menkyo/front.specs.json", "expect_doc": "unten_menkyo", "expect_side": "front",
+   107	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "max_auto": 2, "require_fields": ["license_no"] }] },
+   108	    { "doc": "jp/unten_menkyo/back.png", "fixture": "fixtures/jp/unten_menkyo/back.specs.json", "expect_doc": "unten_menkyo", "expect_side": "back",
+   109	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "max_auto": 2,
+   110	                  "require_banded": ["biko_change", "organ_donor"],
+   111	                  "require_clear": ["address_loose"] }] },
+   112	
+   113	    { "doc": "jp/unten_menkyo/back.png", "fixture": "fixtures/jp/unten_menkyo/back.specs.json", "expect_doc": "unten_menkyo", "expect_side": "back", "geometry": false,
+   114	      "_why": "Same document, same field, two 提出目的, opposite outcomes — the purpose gate is the product, so one case has to prove it actually moves. The 備考欄 carries a free-standing 住所変更 line: for 本人確認提出 that address is `optional` (offered, left clear — see the geometry case above), for 相談用共有 it is `recommend` (banded by default). Geometry is off because the fixture's box table only declares the 本人確認提出 purpose.",
+   115	      "cases": [{ "purpose": "consult_share", "key": "本人確認提出", "max_auto": 2,
+   116	                  "require_fields": ["address_loose"], "require_banded": ["address_loose", "biko_change", "organ_donor"] }] },
+   117	
+   118	    { "doc": "jp/mynumber_card/front.png", "fixture": "fixtures/jp/mynumber_card/front.specs.json", "expect_doc": "mynumber_card", "expect_side": "front",
+   119	      "cases": [{ "purpose": "identity_submit", "key": "身元確認", "max_auto": 2,
+   120	                  "require_banded": ["sex", "organ_donor"] }] },
+   121	    { "doc": "jp/mynumber_card/back.png", "fixture": "fixtures/jp/mynumber_card/back.specs.json", "expect_doc": "mynumber_card", "expect_side": "back",
+   122	      "cases": [{ "purpose": "identity_submit", "key": "身元確認", "min_auto": 1, "max_auto": 3,
+   123	                  "require_banded": ["back_all", "my_number"], "out_formats": ["pdf"] },
+   124	                { "purpose": "my_number_procedure", "key": "個人番号手続", "max_auto": 1,
+   125	                  "require_fields": ["my_number"] }] },
+   126	
+   127	    { "doc": "jp/juminhyo/zenin_mynumber.png", "fixture": "fixtures/jp/juminhyo/zenin_mynumber.specs.json", "expect_doc": "juminhyo",
+   128	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "min_auto": 1, "max_auto": 4,
+   129	                  "require_fields": ["my_number", "jumin_code", "honseki", "hittosha", "setaiin"],
+   130	                  "require_banded": ["jumin_code", "setaiin"] },
+   131	                { "purpose": "my_number_procedure", "key": "個人番号手続", "max_auto": 2,
+   132	                  "require_banded": ["honseki"] }] },
+   133	    { "doc": "jp/juminhyo/ichibu_plain.png", "fixture": "fixtures/jp/juminhyo/ichibu_plain.specs.json", "expect_doc": "juminhyo",
+   134	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "max_auto": 2 }] },
+   135	    { "doc": "jp/juminhyo/honseki_on.png", "fixture": "fixtures/jp/juminhyo/honseki_on.specs.json", "expect_doc": "juminhyo",
+   136	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "max_auto": 2, "require_banded": ["honseki", "hittosha"] },
+   137	                { "purpose": "my_number_procedure", "key": "個人番号手続", "max_auto": 2, "require_banded": ["honseki"] }] },
+   138	    { "doc": "jp/juminhyo/gaikokujin.png", "fixture": "fixtures/jp/juminhyo/gaikokujin.specs.json", "expect_doc": "juminhyo",
+   139	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "max_auto": 2 }] },
+   140	
+   141	    { "doc": "jp/shikaku_kakuninsho/kenpo.pdf", "fixture": "fixtures/jp/shikaku_kakuninsho/kenpo.specs.json", "expect_doc": "shikaku_kakuninsho",
+   142	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "min_auto": 4, "max_auto": 8,
+   143	                  "require_banded": ["kigo", "bango", "edaban", "hokensha_bango", "qr"], "out_formats": ["pdf"] }] },
+   144	
+   145	    { "doc": "jp/shikaku_kakuninsho/kenpo.jpg", "fixture": "fixtures/jp/shikaku_kakuninsho/kenpo.specs.json", "expect_doc": "shikaku_kakuninsho", "geometry": false,
+   146	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "min_auto": 4, "max_auto": 8,
+   147	                  "require_banded": ["kigo", "bango", "edaban", "hokensha_bango", "qr"] }] },
+   148	    { "doc": "jp/juminhyo/zenin_mynumber.jpg", "fixture": "fixtures/jp/juminhyo/zenin_mynumber.specs.json", "expect_doc": "juminhyo", "geometry": false,
+   149	      "cases": [{ "purpose": "identity_submit", "key": "本人確認提出", "min_auto": 1, "max_auto": 4,
+   150	                  "require_fields": ["my_number", "jumin_code"], "require_banded": ["jumin_code", "my_number"] }] },
+   151	    { "doc": "jp/mynumber_card/back.jpg", "fixture": "fixtures/jp/mynumber_card/back.specs.json", "expect_doc": "mynumber_card", "expect_side": "back", "geometry": false,
+   152	      "cases": [{ "purpose": "identity_submit", "key": "身元確認", "min_auto": 1, "max_auto": 3,
+   153	                  "require_banded": ["back_all", "my_number"], "out_formats": ["jpg"] }] }
+   154	  ],
+   155	  "jp_units": {
+   156	    "_why": "The alpha fixtures cannot exercise these two rules: none of the four documents carries a phone number, and on all four the 住所 is a KEEP field, so the address hierarchy never gets to decide anything there. Pinning them at unit level is the honest alternative to shipping untested detection — and it states what it is, instead of looking like fixture coverage. Scores: 郵便番号 +2, 都道府県 +2, 市区郡町村 +1, 丁目番地号 +2, institution word within/near the span −2. Automatic only with 郵便番号 AND 都道府県 together (strong); score >= 3 is a review candidate; below that, nothing.",
+   157	    "address": [
+   158	      { "label": "都道府県+市区+丁目番地号", "text": "住所東京都千代田区霞が関1丁目2番3号", "expect": { "span": "東京都千代田区霞が関1丁目2番3号", "score": 5 } },
+   159	      { "label": "郵便番号を伴う → strong (自動)", "text": "〒100-8926東京都千代田区霞が関1-3-2", "expect": { "span": "〒100-8926東京都千代田区霞が関1-3-2", "score": 7, "strong": true } },
+   160	      { "label": "漢数字の丁目番号も拾う", "text": "本籍京都府京都市中京区三条通一丁目二番三号", "expect": { "span": "京都府京都市中京区三条通一丁目二番三号", "score": 5 } },
+   161	      { "label": "架空の県名はアンカーにならない（保険者名）", "text": "保険者名架空県後期高齢者医療広域連合", "expect": null },
+   162	      { "label": "発行者名（見本市長）を住所と読まない", "text": "見本市長架空太郎（公印省略）", "expect": null },
+   163	      { "label": "株式会社名を住所と読まない", "text": "事業所名称架空株式会社", "expect": null },
+   164	      { "label": "機関名は減点 — 部分一致は閾値割れ", "text": "大阪府見本市役所", "expect": null },
+   165	      { "label": "完全な住所は機関名が続いても候補として残る", "text": "東京都新宿区西新宿2丁目8番1号新宿区役所", "expect": { "span": "東京都新宿区西新宿2丁目8番1号", "score": 3 } }
+   166	    ],
+   167	    "tel": [
+   168	      { "label": "市外局番2桁", "text": "電話03-1234-5678", "expect": { "v": "03-1234-5678" } },
+   169	      { "label": "携帯", "text": "携帯090-1234-5678", "expect": { "v": "090-1234-5678" } },
+   170	      { "label": "フリーダイヤル 0120", "text": "TEL0120-123-456", "expect": { "v": "0120-123-456" } },
+   171	      { "label": "フリーダイヤル 0800", "text": "FAX0800-123-4567", "expect": { "v": "0800-123-4567" } },
+   172	      { "label": "ハイフンなしは候補どまり", "text": "電話番号09012345678", "expect": { "v": "09012345678", "loose": true } },
+   173	      { "label": "11桁を超える数字列は電話ではない", "text": "個人番号720463027637", "expect": null }
+   174	    ]
+   175	  },
+   176	  "ai_inject": {
+   177	    "_doc": "7_resume_dark.pdf",
+   178	    "cases": [
+   179	      {"label": "college labelled as person name", "entity": {"type": "name", "value": "Maharaja Agrasen College"}, "expect": "not_masked"},
+   180	      {"label": "foundation labelled as person name", "entity": {"type": "name", "value": "Concern India Foundation"}, "expect": "not_masked"},
+   181	      {"label": "institute labelled as name", "entity": {"type": "name", "value": "King Sejong Institute"}, "expect": "not_masked"},
+   182	      {"label": "lone country labelled as address", "entity": {"type": "address", "value": "Korea"}, "expect": "dropped"},
+   183	      {"label": "lone country labelled as name", "entity": {"type": "name", "value": "India"}, "expect": "dropped"},
+   184	      {"label": "country adjective labelled as name", "entity": {"type": "name", "value": "Indian"}, "expect": "dropped"},
+   185	      {"label": "country+parenthetical labelled as address", "entity": {"type": "address", "value": "Korea (Koreaz Contest)"}, "expect": "dropped"},
+   186	      {"label": "exam name labelled 'other' stays visible", "entity": {"type": "other", "value": "TOPIK"}, "expect": "not_masked"},
+   187	      {"label": "exam name with UNKNOWN type → 'other', visible", "entity": {"type": "certificate", "value": "TOPIK"}, "expect": "not_masked"},
+   188	      {"label": "contest name labelled 'other' stays visible", "entity": {"type": "other", "value": "Koreaz Contest"}, "expect": "not_masked"},
+   189	      {"label": "genuine body name (positive control)", "entity": {"type": "name", "value": "Rohan Mehta"}, "expect": "masked"}
+   190	    ]
+   191	  },
+   192	
+   193	  "ai_cat_state": {
+   194	    "_doc": "7_resume_dark.pdf",
+   195	    "_note": "After an AI deep-scan injects name/company labels, the category ACTIVE state (checkbox) must stay ON — a disabled name category would silently leave names unmasked when the user trusts the AI and just builds. Asserts catEnabled stays true and the rendered checkbox stays checked.",
+   196	    "labels": [
+   197	      {"type": "name", "value": "Rohan Mehta"},
+   198	      {"type": "company", "value": "Globex Solutions Pvt Ltd"}
+   199	    ],
+   200	    "assert_enabled": ["name", "company"]
+   201	  },
+   202	
+   203	  "candidate_dedup": {
+   204	    "_doc": "6_resume_light.pdf",
+   205	    "_note": "A CONFIRMED entity whose value wholly contains a review candidate (as whole space-separated tokens) makes that candidate redundant — the confirmed mask already covers it — so the candidate must be removed. Reproduces confirmed 'MANSI GAZAL TIWARI' hiding candidate 'MANSI GAZAL'. Directional: only the shorter, fully-contained candidate is dropped; a candidate that ADDS a token beyond the confirmed value must be kept (removing it would lose coverage). The base doc surfaces 'Aarav Sharma' as a name candidate; each case injects a confirmed name and asserts the candidate is dropped/kept accordingly. Old code (no dedupe) leaves the candidate in place, so the 'removed' case fails on it.",
+   206	    "cases": [
+   207	      {"label": "candidate contained in confirmed name is removed", "candidate": "Aarav Sharma", "confirm": {"type": "name", "value": "Aarav Sharma Verma"}, "expect": "removed"},
+   208	      {"label": "candidate adding a token beyond confirmed is kept", "candidate": "Aarav Sharma", "confirm": {"type": "name", "value": "Aarav"}, "expect": "kept"}
+   209	    ]
+   210	  }
+   211	}
+
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+exec
+/bin/zsh -lc "git show 546344b:test/safe/fixtures/jp/jp_legal_matrix_alpha4.json | nl -ba; git show 546344b:docs/jp/jp_safefile_strategy_v2_2026-10-21.md | nl -ba; git show 546344b:docs/jp/s3_report.md | nl -ba | sed -n '1,380p'; git show 546344b:CLAUDE.md | nl -ba | sed -n '/JP-1/,/"'^[''^ ]/p'"'" in /Users/sunghoon/Projects/docpack
+ succeeded in 0ms:
+     1	{
+     2	  "version": "2026-10-21",
+     3	  "scope": "SafeFile JP 알파 4종. 규칙은 제출 목적(purpose)별. 출처 없는 규칙은 verified=false로 표기하고 자동 마스킹 금지.",
+     4	  "purposes": {
+     5	    "identity_submit": "本人確認書類として提出（銀行・カード・通信・フリマ・賃貸）",
+     6	    "my_number_procedure": "個人番号関係事務（税・社会保障・勤務先提出）",
+     7	    "bid_attachment": "入札・許可申請への添付",
+     8	    "consult_share": "専門家・SNS等への相談用共有"
+     9	  },
+    10	  "documents": [
+    11	    {
+    12	      "id": "shikaku_kakuninsho", "name": "資格確認書", "replaces": "健康保険証（2025-12-01 失効・暫定2026-07-31終了）",
+    13	      "variants": ["被用者保険(協会けんぽ・健保組合)", "国民健康保険", "後期高齢者医療"],
+    14	      "fields_common": ["氏名", "生年月日", "性別", "住所", "資格取得年月日", "有効期限", "保険者番号", "保険者名", "記号/番号/枝番 または 被保険者番号"],
+    15	      "fields_issuer_specific": ["事業所名称", "二次元コード", "一部負担金割合", "自己負担限度額区分"],
+    16	      "rules": [
+    17	        {"field": "保険者番号・記号・番号・枝番・被保険者番号", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": [], "level": "auto",
+    18	         "legal_basis": "健康保険法等 告知要求制限（2020-10-01施行）: 医療保険事務以外の目的での告知要求を原則禁止。提出先が受領する場合もマスキングを求める運用",
+    19	         "source": ["https://www.mhlw.go.jp/stf/newpage_13989.html", "https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf", "https://www.kyosai.metro.tokyo.jp/assets/84b47fd406a8378372a6015863f83bc93c0c8a75.pdf"], "verified": true},
+    20	        {"field": "二次元コード", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "level": "auto", "legal_basis": "番号を判読可能なため同一扱い（大阪府・千葉市運用）", "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"], "verified": true},
+    21	        {"field": "性別", "mask_when": ["identity_submit"], "level": "recommend", "legal_basis": "法定ではない。民間KYC事業者の運用（SoftBank, PayPay銀行等）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
+    22	        {"field": "氏名・生年月日・住所・有効期限", "mask_when": [], "must_keep_when": ["identity_submit", "bid_attachment"], "level": "keep", "legal_basis": "本人特定事項。マスキングすると受付不可", "source": ["https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html"], "verified": true}
+    23	      ]
+    24	    },
+    25	    {
+    26	      "id": "unten_menkyo", "name": "運転免許証", "sides": ["表", "裏"],
+    27	      "fields_front": ["氏名", "生年月日", "住所", "交付日", "有効期限", "免許の条件", "番号(12桁)", "種類・取得日", "顔写真", "公安委員会名"],
+    28	      "fields_back": ["備考欄（住所・氏名等の変更記載）", "臓器提供意思表示欄"],
+    29	      "note": "本籍は券面に印字されない（ICチップ内）",
+    30	      "rules": [
+    31	        {"field": "裏面 備考欄（変更記載）", "mask_when": ["identity_submit", "consult_share"], "level": "recommend", "legal_basis": "旧住所等の不要情報。提出先指示優先（住所変更確認で裏面が必要な場合あり）", "source": ["https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true},
+    32	        {"field": "臓器提供意思表示欄", "mask_when": ["identity_submit", "consult_share"], "level": "recommend", "legal_basis": "民間KYC運用（SoftBank: 臓器提供意思をマスキング）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
+    33	        {"field": "番号(12桁)", "mask_when": ["consult_share"], "must_keep_when": ["identity_submit"], "level": "optional", "legal_basis": "個人識別符号（個人情報保護法施行令）。KYCでは照合に必要な提出先が多い", "source": [], "verified": false},
+    34	        {"field": "氏名・生年月日・住所・有効期限・顔写真", "must_keep_when": ["identity_submit"], "level": "keep", "verified": true, "source": ["https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html"]}
+    35	      ]
+    36	    },
+    37	    {
+    38	      "id": "mynumber_card", "name": "マイナンバーカード（個人番号カード）", "sides": ["表", "裏"],
+    39	      "fields_front": ["氏名", "住所", "生年月日", "性別", "有効期限", "顔写真", "券面記載事項追記欄", "臓器提供意思表示欄"],
+    40	      "fields_back": ["個人番号", "氏名", "生年月日(要確認)", "二次元コード"],
+    41	      "unverified": ["裏面の生年月日印字有無"],
+    42	      "rules": [
+    43	        {"field": "裏面全体", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": ["my_number_procedure"], "level": "auto_with_purpose_gate",
+    44	         "legal_basis": "番号法: 法令で認められた者・目的以外での個人番号の収集・保管禁止。身元確認目的では裏面を提出しない", "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/", "https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true},
+    45	        {"field": "表面 性別・臓器提供意思表示欄", "mask_when": ["identity_submit"], "level": "recommend", "legal_basis": "民間KYC運用", "source": ["https://www.aspicjapan.org/asu/article/6908"], "verified": true},
+    46	        {"field": "表面 氏名・住所・生年月日・有効期限・顔写真", "must_keep_when": ["identity_submit", "my_number_procedure"], "level": "keep", "verified": true, "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"]}
+    47	      ]
+    48	    },
+    49	    {
+    50	      "id": "juminhyo", "name": "住民票の写し",
+    51	      "variants": ["世帯全員/一部", "個人番号 あり/なし", "本籍・筆頭者 あり/なし", "外国人住民（国籍・在留資格・在留期間・在留カード番号）", "住民票コード付（窓口のみ）"],
+    52	      "rules": [
+    53	        {"field": "個人番号", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": ["my_number_procedure"], "level": "auto_with_purpose_gate", "legal_basis": "番号法 収集制限。本人確認目的なら個人番号なしの住民票を取り直すのが原則", "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"], "verified": true},
+    54	        {"field": "住民票コード", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "level": "auto", "legal_basis": "住民基本台帳法 利用制限（個人識別符号）", "source": [], "verified": false},
+    55	        {"field": "本籍・筆頭者", "mask_when": ["identity_submit", "consult_share"], "level": "recommend", "legal_basis": "民間KYC運用（SoftBank: 住民票の本籍をマスキング）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
+    56	        {"field": "本人以外の世帯員", "mask_when": ["identity_submit", "consult_share"], "level": "recommend", "legal_basis": "第三者情報。提出先が世帯全員を要求する場合は維持", "source": [], "verified": false},
+    57	        {"field": "氏名・生年月日・住所・発行日・発行者", "must_keep_when": ["identity_submit", "bid_attachment"], "level": "keep", "verified": true, "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"]}
+    58	      ]
+    59	    }
+    60	  ],
+    61	  "levels": {"auto": "文書分類+ラベル一致で自動黒塗り", "auto_with_purpose_gate": "目的選択後に自動（別目的では解除）", "recommend": "既定ON・解除可", "optional": "既定OFF・選択可", "keep": "黒塗り禁止（警告）"}
+    62	}
+     1	# SafeFile 일본 진출 전략 v2 (2026-10-21) — Codex 독립 검토 반영
+     2	
+     3	> v1(10-20) → Codex 검토(10-21) → Claude 교차검증 → v2. 변경 근거는 §0에 모두 기록.
+     4	
+     5	---
+     6	
+     7	## 0. Codex 지적 처리표 (수용 / 부분수용 / 반려)
+     8	
+     9	| # | Codex 지적 | 판정 | 처리 |
+    10	|---|---|---|---|
+    11	| 1-1 | 타임즈카 날짜·자료유형 혼합. 住民票는 공식 목록에 없음 | **수용** | 9/25 탐지·1보, 9/28 660만 확인, 9/29 160만 본인확인서류 확인으로 분리. 住民票→現住所確認書類(公共料金請求書等). 단 共同通信 보도에는 "住民票の写し"가 언급됨 → "보도상 언급, 공식 목록 미포함"으로 병기 |
+    12	| 1-2 | 집단소송 1만5천 명 근거 없음 | **반려(근거 보강)** | 출처는 共同通信 10/3 기사(sn-hoki 전재: "2日午後9時までに1万5千人以上が登録"). 다만 "参加意思表明 등록자"이지 원고 수가 아님 → 표현 수정 |
+    13	| 1-3 | 告知要求制限을 "보편 의무"로 과장. 性別·枝番은 법정 항목 아님 | **수용** | "의료보험 사무 외 목적의 요구 제한, 예외 있음, QR은 번호 판독 가능 시 동일 취급"으로 한정. 性別은 법 밖(실무 권고)으로 분리 |
+    14	| 1-4 | 資格確認書 필드가 보험자별 상이. 通院歴 삭제 | **수용** | 구 보험증/資格確認書 분리. 필드를 common / issuer_specific으로 |
+    15	| 1-5 | マイナカード 裏面 "절대 금지" 과장. 臓器提供欄은 앞면 | **수용** | 목적 선택(身元確認 / 個人番号手続) → 기본 전체 가림 → 명시 해제. 臓器提供欄 앞면으로 정정. 裏面 生年月日 유무는 **확인 필요**(상충) |
+    16	| 1-6 | 2027-04 IC칩은 犯収法 특정사업자 한정 | **수용** | "구멍" 표현 삭제. 콘텐츠 16번 제도 해설로 재작성 |
+    17	| 2-1 | always/optional 단일 규칙은 제출 목적 무시 | **수용(핵심)** | `purpose` 축 도입: `mask_when_purpose` / `must_keep_when_purpose` / `legal_basis` / `source_url` |
+    18	| 2-2 | 免許証 本籍은 권면에 없음(IC칩) | **수용** | 권면 필드에서 本籍 제거, 裏面은 備考欄(変更記載) |
+    19	| 2-4 | 구 健康保険証 2025-12-01 실효, 잠정 2026-07-31 종료 | **수용** | 資格確認書를 주 문서로, 구 보험증은 legacy fixture |
+    20	| 2-5~2-10 | 문서 묶음 과다, 출처 약함 | **수용** | jp10·jp12·jp13 분리. 출처 없는 always 금지 |
+    21	| 2-11 | 누락 문서 11종 | **부분수용** | v2 범위엔 넣지 않음(알파 4종 집중). 백로그에 등재 |
+    22	| 3-1 | 카탈로그 패턴이 실제 코드에 없음 | **수용** | S1 "완료" 취소 → "조사 완료, 구현 0" |
+    23	| 3-2~3-6 | 정규식 오탐·미탐, NFKC 좌표 역매핑 | **수용** | 정규식 단독 자동마스킹 금지. 레이블 앵커+문서분류+체크디지트 3단. 원문↔정규화 인덱스 매핑 필수 |
+    24	| 4-1 | 25–39 연령 타깃 근거 없음 | **수용** | 연령 폐기 → 제출 목적 4종으로 세그먼트 |
+    25	| 4-2 | 서버형 書類ボックス는 개인정보 취급 발생, 메시지 충돌 | **수용** | 서버 보관 철회. 초기 유료화는 로컬 보관(PWA/IndexedDB 암호화)+내보내기 |
+    26	| 5-1 | 실물 동일 레이아웃+유효 체크디지트 더미는 위험 | **수용** | 비실물 도식형 더미로 전환. 조건 §4 참조. 유효 체크디지트 생성 금지 |
+    27	| 6-1 | 채널을 전체 이용률로만 선정 | **부분수용** | 검색(SEO) 랜딩을 핵심 축으로 추가. X·Shorts·Reels는 유지하되 2주 전환 측정 후 배분 |
+    28	| 6-2 | 위험·과장 제목 10건 | **수용** | §6 제목 전면 재작성. "絶対/防ぐ/べき" 금지 |
+    29	| 6-3 | 가상 1인칭 피해담 금지 | **수용** | 공식 발표 사실 인용의 비개인 해설로 제한. 소송·재교부 안내와 CTA 분리 |
+    30	| 7-1~7-3 | 2주 13종 비현실. 4종 알파로 축소 | **수용** | §7 일정 재편 |
+    31	
+    32	---
+    33	
+    34	## 1. 사실 정리 (정정판)
+    35	
+    36	- 2026-09-25 タイムズカー 부정 접근 탐지·제1보 → 09-28 약 660만 계정 정보 취득 확인(제2보) → 09-29 그중 약 160만 계정에서 본인확인서류 이미지(運転免許証·現住所確認書類·学生証·家族確認書類) 유출 확인(제3보). 共同通信은 住民票の写し도 언급. [제2보](https://share.timescar.jp/news/2026/0928/1815.html) [제3보](https://share.timescar.jp/news/2026/0929/1816.html)
+    37	- 집단소송: 변호사 개설 사이트에 10/2 밤까지 1만5천 명 이상 "참가 의사 등록"(共同通信). 원고 수 아님
+    38	- 10월 들어 大和証券·物語コーポレーション 등 추가 유출 발표. 경시청에 재교부 상담 쇄도, 福島県 특별 재교부 접수
+    39	- 告知要求制限(2020-10-01): 의료보험 사무 외 목적으로 保険者番号·被保険者等記号・番号의 고지를 요구하는 것을 원칙 금지. 예외 있음. QR은 번호 판독 가능 시 동일. 지자체·은행·카드사가 사본 제출 시 마스킹 요청 중. [厚労省](https://www.mhlw.go.jp/stf/newpage_13989.html)
+    40	- 구 健康保険証: 2025-12-01 원칙 실효, 잠정 대응 2026-07-31 종료 → 현재 주 문서는 **資格確認書**(보험자별 양식 상이)
+    41	- マイナンバーカード: 一般 身元確認에는 앞면만. 裏面 個人番号 복사·보관은 번호법상 허용 목적(세무·사회보장 등)에 한정. 臓器提供意思表示欄은 앞면 하단
+    42	- 犯収法 개정 2027-04-01: 특정사업자의 비대면 "얼굴+신분증 이미지" 방식 등 폐지·개편. 전 서비스 일률 아님
+    43	- SNS 이용률(ICT総研 2026-07 보도자료): LINE 71.1 / YouTube 67.6 / X 45.4 / Instagram 42.0 — 연령별 전환율 자료 아님
+    44	
+    45	**핵심 통찰(유지)**: 일본에는 "黒塗り"가 법적 요구+관행으로 존재하고, 개인은 付箋·테이프·편집앱으로 수작업 중. 개인용 무료 웹툴 공백. "透ける黒塗り" 공포에 "래스터 평탄화 + 메타데이터 제거"로 답한다.
+    46	
+    47	---
+    48	
+    49	## 2. 타깃 — 제출 목적 4종 (연령 폐기)
+    50	
+    51	| 우선 | 제출 목적 | 대표 문서 | 법적·관행 근거 | 첫 콘텐츠 훅 |
+    52	|---|---|---|---|---|
+    53	| **1** | 本人確認書類 제출(은행·카드·통신·프리마) | 資格確認書, 免許証, マイナカード 표면 | 告知要求制限, 수령기관 마스킹 안내 | 「資格確認書の番号、提出先が"隠して"と言う理由」 |
+    54	| **2** | 입찰·허가·건설업 첨부 | 資格確認書 사본, 標準報酬決定通知書 | 지자체 공식 마스킹 견본 PDF | 「入札添付、マスキング忘れで再提出にならないために」 |
+    55	| 3 | 전문가 상담용 익명화(변호사·세무사·SNS 질문) | 賃貸借契約書, 給与明細, 通帳 | 관행 | 「契約書を相談に出す前に、相手の情報を消す」 |
+    56	| 4 | 외국인 거주자 서류(영어 UI) | 在留カード, 住民票(외국인 기재) | 관행 | 영어 버전 |
+    57	
+    58	**유료화(수정)**: 서버 보관 철회. 1차는 **로컬 보관함**(브라우저 IndexedDB 암호화, 기기 내, 자동 만료) + **암호화 ZIP 내보내기**. 과금은 결제 의향 테스트 후. "개인정보처리방침과 무충돌" 문구 삭제.
+    59	
+    60	---
+    61	
+    62	## 3. 제품 요구사항 (알파 게이트)
+    63	
+    64	### 3-1 마스킹
+    65	- 띠(검정 기본·흰색·지정 1색)만. 별표·부분값 폐지(결정 유지)
+    66	- OCR 박스 + 글리프 외곽 여유(2px 고정이 아니라 **박스 높이의 15%**)로 덮고 래스터 평탄화
+    67	- 출력 시 **원본 텍스트 레이어·주석·첨부·증분저장·EXIF 전부 제거** 검증
+    68	- 지원 외 문서는 자동 마스킹 금지, 수동 사각형+워터마크만
+    69	
+    70	### 3-2 탐지(JP-1) — 정규식 단독 자동마스킹 금지
+    71	| 항목 | 방식 | 자동 띠 조건 |
+    72	|---|---|---|
+    73	| 個人番号 12자리 | NFKC → 숫자 경계 → 레이블(個人番号/マイナンバー) 또는 문서분류 → 체크디지트 함수 | 3조건 충족 시 자동, 아니면 검토 후보 |
+    74	| 保険者番号 / 記号・番号・枝番 | 레이블 근접(같은 행·인접 박스) 점수제 | 資格確認書 분류 + 레이블 일치 시 자동 |
+    75	| 免許証番号 12자리 | 免許証 분류 + "第"/"番号" 앵커 | 분류 확정 시만 |
+    76	| 電話·FAX | NFKC → TEL/電話/携帯/FAX 앵커 + 일본 번호계획 | 앵커 있을 때 자동, 하이픈 없는 값은 후보 |
+    77	| 住所 | 郵便番号 → 都道府県 → 市区郡 → 町域 → 丁目番地 → 建物 계층 파서. 漢数字 百·千 포함 | 郵便番호+都道府県 동반 시 자동 |
+    78	| 生年月日(和暦) | 和暦·서기 양쪽 | 후보 |
+    79	| QR | 이미지 휴리스틱 | 資格確認書 분류 시 자동 |
+    80	- **원문↔NFKC 인덱스 매핑 보존**, 이체자(髙/高, 﨑/崎), OCR 혼동(ー/−/―, 〇/0) 단계별 처리, 원본 좌표 역매핑 테스트
+    81	
+    82	### 3-3 프리셋 — 알파 4종만
+    83	| 프리셋 | 목적 선택 | 기본 띠 | 해제 가능 |
+    84	|---|---|---|---|
+    85	| 資格確認書 | 本人確認 | 保険者番号, 記号, 番号, 枝番, QR | 性別(권고) |
+    86	| 運転免許証 | 本人確認 | 裏面 備考欄 | 番号 |
+    87	| マイナンバーカード | 身元確認 / 個人番号手続 | 身元確認: 裏面 전체 + 앞면 臓器提供欄 | 個人番号手続 선택 시 裏面 해제 |
+    88	| 住民票の写し | 用途 선택 | 個人番号, 住民票コード | 本籍, 世帯員 |
+    89	
+    90	### 3-4 워터마크
+    91	「{提出先}提出用」「本人確認のみに使用」「転用禁止」+ 날짜. 문구는 "防止"가 아니라 "抑止" 수준으로 안내.
+    92	
+    93	---
+    94	
+    95	## 4. 더미 데이터 — 비실물 도식형
+    96	
+    97	- **실물 동일 재현 금지**: 종횡비·색·서체·구획을 동시에 복제하지 않음. 카드류는 "필드 위치 도식(와이어프레임형)"으로
+    98	- 앞뒤 중앙 대형 「見本・架空・本人確認に使用不可」 영구 표기
+    99	- 公安委員会名·市区町村長名·관인·マイナンバー 로고·QR·IC 표시 금지
+   100	- 번호는 **체크디지트 불일치** 또는 규격 외 문자(예: 개인번호 12자리 중 'X' 포함)
+   101	- 실존 불가 주소(99丁目 등), 架空 인명, 생성 아바타
+   102	- 개별 고해상 카드 파일은 공개 배포 금지. 콘텐츠에는 축소 삽화만
+   103	- 더미 범위: 알파 4종 × (PDF·JPG 촬영풍·PNG 스캔풍) + 변형(資格確認書 보험자 3종, 住民票 全員/一部·個人番号 유무·외국인) ≈ **20파일**
+   104	- 법률 검토 전까지 카드 더미는 내부 테스트 전용
+   105	
+   106	---
+   107	
+   108	## 5. 카탈로그 v2 스키마 (jp_documents_catalog_v2.json으로 갱신 예정)
+   109	
+   110	```
+   111	{id, name, variants[], sides[], fields:{common[], issuer_specific[]},
+   112	 rules:[{field, mask_when_purpose[], must_keep_when_purpose[], legal_basis, source_url, verified_at}],
+   113	 fixtures[]}
+   114	```
+   115	- 분리: jp10→給与明細 / 標準報酬決定通知書, jp12→通帳 / 残高証明, jp13→在職証明 / 卒業証明 / 成績証明 / 学生証
+   116	- 백로그 추가: 基礎年金番号通知書(年金手帳 legacy), 印鑑登録証明書, 課税·所得·納税証明書, 障害者手帳, 戸籍謄抄本, 介護保険被保険者証, 母子健康手帳, 診断書, 雇用保険被保険者証, 離職票, 住民税決定通知書
+   117	
+   118	---
+   119	
+   120	## 6. 콘텐츠 (3개월 30편 → 제목 재작성, 알파 4종 중심으로 순서 재배치)
+   121	
+   122	### 채널
+   123	- **핵심**: 검색 랜딩 3페이지(資格確認書 마스킹 / 免許証 제출 전 / マイナカード 裏面) — Google·Yahoo! JAPAN
+   124	- **보조**: YouTube(검색형 2분 + Shorts) · X(사건 해설·공지) · Instagram(carousel·Reels 별도 제작)
+   125	- 2주 전환 측정 후 배분 조정
+   126	
+   127	### 원칙
+   128	- 모든 How-to에 「提出先の指定を必ず確認」 포함
+   129	- "絶対 / 防ぐ / べき" → "原則 / リスクを下げる / 確認する"
+   130	- タイムズカー: 공식 발표 사실만, 1인칭 피해담 금지, 소송·재교부·JICC 안내는 CTA와 분리
+   131	- 미구현 기능(일괄처리) 홍보 금지
+   132	
+   133	### 30편 (JA 제목, EN 병행)
+   134	| 회 | 트랙 | 제목 | 문서 |
+   135	|---|---|---|---|
+   136	| 1 | B | 本人確認書類の画像流出で何が起きるか — 公式発表から分かっていること | — |
+   137	| 2 | A | 資格確認書の番号を隠して提出する手順【提出先の指定を確認】 | 資格確認書 |
+   138	| 3 | A | 運転免許証を送る前に確認する3つのこと | 免許証 |
+   139	| 4 | B | 「黒塗りしたつもり」が復元される仕組みと、復元されない方法 | — |
+   140	| 5 | A | マイナンバーカード:身元確認なら表面だけ。裏面が必要な手続きとは | マイナカード |
+   141	| 6 | B | フリマ・ネット銀行の本人確認、画像を送る前にできること | 免許証 |
+   142	| 7 | A | 住民票の写し:用途別に残す項目・隠す項目 | 住民票 |
+   143	| 8 | B | 入札添付の資格確認書、マスキング指示の読み方 | 資格確認書 |
+   144	| 9 | A | 履歴書PDF、相談用に連絡先だけ隠す | 履歴書 |
+   145	| 10 | B | 付箋・マスキングテープ撮影の限界 | — |
+   146	| 11 | A | 源泉徴収票に個人番号があるとき、ないとき | 源泉徴収票 |
+   147	| 12 | B | 賃貸契約で身分証コピーを求められたら確認すること | 免許証 |
+   148	| 13 | A | 在留カード:提出先が求める面を確認してから隠す(EN同時) | 在留カード |
+   149	| 14 | B | 退会後も本人確認書類が保存される理由と、確認する方法 | — |
+   150	| 15 | A | 給与明細を相談に出すとき、口座と社員番号の扱い | 給与明細 |
+   151	| 16 | B | 2027年4月 犯収法改正で本人確認はどう変わるか(解説) | — |
+   152	| 17 | A | 賃貸借契約書を専門家に相談する前の匿名化 | 契約書 |
+   153	| 18 | B | 「マスキングしてください」と言う提出先、言わない提出先 | — |
+   154	| 19 | A | パスポート:番号・MRZを隠してよい場面、いけない場面 | パスポート |
+   155	| 20 | B | 流出後にできる手続き一覧(JICC/CIC 本人申告ほか) ※CTAなし | — |
+   156	| 21 | A | 通帳画像:残高証明として出す場合と相談用の違い | 通帳 |
+   157	| 22 | B | 学生証画像の流出 — 学生ができる確認 | 学生証 |
+   158	| 23 | A | 職務経歴書を匿名で共有するときの考え方 | 職務経歴書 |
+   159	| 24 | B | 「サーバーに保存しない」ツールの見分け方 | — |
+   160	| 25 | A | スマホだけで:撮影→黒塗り→確認→送信 | 全般 |
+   161	| 26 | B | 副業の本人確認を毎回やり直さないために(ローカル保管) | — |
+   162	| 27 | A | 透かし「〇〇提出用」の入れ方と限界 | 全般 |
+   163	| 28 | B | 家族の書類を代理で出すときの注意 | 資格確認書 |
+   164	| 29 | A | (一括処理 出시 후) 複数書類をまとめて処理 | 全般 |
+   165	| 30 | B | 3か月の振り返りと読者の黒塗り失敗集 | — |
+   166	
+   167	---
+   168	
+   169	## 7. 실행 순서 v2
+   170	
+   171	| 단계 | 산출물 | 게이트 | 담당 |
+   172	|---|---|---|---|
+   173	| S1 법적 매트릭스 | 알파 4종 purpose 규칙 + 출처 URL + verified_at | 출처 없는 규칙 0 | Claude |
+   174	| S2 fixture | 4종 × 3포맷 + 변형 ≈ 20파일, 기대 마스킹 specs.json | §4 안전조건 전부 충족 | Claude |
+   175	| S3 탐지·띠 | NFKC 매핑, 4종 분류기, 고신뢰 항목 자동, 나머지 후보 | 골든: 필수 민감항목 **미탐 0**, 오탐으로 필수 증빙 훼손 0 | Claude Code |
+   176	| S4 안전성 | 텍스트레이어·주석·첨부·EXIF 제거, 회전·저해상·왜곡 사진, 타 도구 재추출 공격 테스트 | 전부 통과 | Claude Code + Codex 리뷰 |
+   177	| S5 랜딩·법적 문구 | JA 랜딩 3페이지 + 면책·개인정보 문구 | 문구 검수 완료 | Claude |
+   178	| S6 제한 베타 | 보험번호 마스킹 가이드 + 베타 모집(사건명 광고 없음) | 2주 전환 측정 | Justin |
+   179	| S7 콘텐츠 | 30편 순차 제작, 3일 1회 전달 | 베타 피드백 반영 | Claude |
+   180	| S8 확대 | fixture 4주 수집 후 문서 순차 추가 | — | — |
+   181	
+   182	**게이트 원칙**: "12/13 성공, 1분 완료" 같은 UX 기준은 안전 게이트가 아님. 미탐 0·복원 불가·메타데이터 제거가 게이트.
+   183	
+   184	---
+   185	
+   186	## 8. 미확인·보류
+   187	
+   188	- マイナンバーカード 裏面에 生年月日 인쇄 여부(Codex: 없음 / v1: 있음) → 공식 견본으로 확인
+   189	- 履歴書 현행 JIS 규격 여부 → 확인 불가, 「厚労省様式例／民間様式」로 표기
+   190	- 카드 더미의 법적 안전선 → 일본 변호사 검토 전 내부 전용
+   191	- safefile.net 도메인
+     1	# S3 — JP-1 알파: 탐지·띠 구현 보고 (2026-10-21)
+     2	
+     3	시작 2026-10-21 00:41 KST · 종료 2026-10-21 01:50 KST · 약 1시간 10분
+     4	브랜치 `main` · **미배포** · 프로덕션 DB 미접촉
+     5	
+     6	전략 문서: [`jp_safefile_strategy_v2_2026-10-21.md`](jp_safefile_strategy_v2_2026-10-21.md) §3 제품 요구사항 / §7 게이트
+     7	법적 정본: [`../../test/safe/fixtures/jp/jp_legal_matrix_alpha4.json`](../../test/safe/fixtures/jp/jp_legal_matrix_alpha4.json)
+     8	전체 통과 로그: [`s3_golden_result.md`](s3_golden_result.md)
+     9	
+    10	| 게이트 (§7 S3) | 결과 |
+    11	|---|---|
+    12	| 일본 픽스처에서 `auto`/`auto_with_purpose_gate` 항목 **미탐 0건** | ✅ `JP_MASK` 24 + `JP_MASK_OR_CAND` 3 + `JP_BANDED` 41 전부 통과 |
+    13	| `keep` 항목 **오탐 0건** | ✅ `JP_KEEP` 46건 전부 피복 0% |
+    14	| 모든 출력에서 **텍스트 레이어·EXIF 0** | ✅ `TEXT_LEAK` 10 + `OUT_PDF` 20 + `OUT_PNG` 3 + `OUT_JPG` 6 |
+    15	| 기존 한국 골든 **전부 통과** | ✅ (130 → 120, 아래 설명) |
+    16	| 목적 게이트가 실제로 움직이는가 | ✅ 같은 문서·같은 필드를 두 목적으로 — `JP_CLEAR` ↔ `JP_BANDED` |
+    17	| 전체 | **389/389 pass, 0 FAIL, exit 0** |
+    18	
+    19	---
+    20	
+    21	## A. 마스킹 방식 단일화 — 띠만
+    22	
+    23	**모드가 2개가 됐다**: `ok`(공개) / `no`(띠). 별표·부분값 오버레이·흰색 처리 전부 제거.
+    24	
+    25	왜 모드를 줄이는 것이 안전을 올리는가: 부분 마스킹은 비밀의 일부를 배경색 패치 **위에
+    26	다시 그린다.** 따라서 그 안전성은 "우리가 얼마나 드러내기로 했는가" 에 달려 있고,
+    27	제출하는 사람은 결과 파일만 보고 그 판단을 감사할 수 없다. 띠에는 그 자유도가 없다.
+    28	부분이 기본이던 유형(phone·email·birth·address·name·url)은 전부 **띠** 기본이 됐다 —
+    29	더 많이 가리지, 덜 가리지 않는다.
+    30	
+    31	### 띠 기하 — `bandRect()`
+    32	박스 + **박스 높이의 15%(최소 2px)** 를 사방으로. 박스가 **추정치**이기 때문이다:
+    33	pdf.js 아이템 박스는 사이드베어링을 빼고, OCR 단어 박스는 안티앨리어싱된 글리프 가장자리를
+    34	자르며, 회전이 들어가면 둘 다 흔들린다. 추정치에서 정확히 멈추는 띠는 원본 잉크의
+    35	머리카락 한 줄을 남긴다.
+    36	
+    37	**`region:true` 박스는 키우지 않는다** — 사람이 드래그한 영역과 탐지된 欄/블록은
+    38	"글리프가 어디서 끝나는가"의 추정이 아니라 **의도**다. 키우면 사용자가 고르지 않은
+    39	이웃 내용을 조용히 덮는다.
+    40	
+    41	### 띠 색
+    42	먹(기본) / 흰색 / 사용자 지정 1색. 불투명이라는 점은 셋 다 같으므로 이것은
+    43	마스킹 강도의 선택이 아니라 제출본 가독성의 선택이다.
+    44	
+    45	### 사라진 코드
+    46	`maskHalf` · `maskPhone` · `drawFitText` · `largeBarRect` · `pageMedH` ·
+    47	`drawRedactions` 의 오버랩 에스컬레이션 경로 전체. 그 에스컬레이션은 두 별표 문자열이
+    48	서로 위에 그려져 유령 문자를 만들고 짧은 쪽이 원본 꼬리를 남기던 것을 막는 장치였다 —
+    49	**모드를 없애니 그 실패 종류 전체가 함께 사라졌다.**
+    50	
+    51	### 기존 한국 골든 갱신
+    52	- `phone_format` / `phone_format_units` **10건 삭제** — 그 단언이 검증하던 모드가 없다.
+    53	  `must_mask`/`must_not_mask` 의미는 **그대로**(활성 마스크 사각형에 의한 기하 피복).
+    54	- `candidate_mode` `half` → **`ok`**. 후보는 *추측*이고, 추측이 사용자 확인 전에 문서에서
+    55	  내용을 지우면 안 된다. (JP `recommend` 처럼 법적 근거로 既定ON 이어야 하는 호출자는
+    56	  명시적 `mode` 를 넘긴다.)
+    57	- 하네스의 `__maskRects` 가 이제 **패딩 적용 후** 사각형을 잰다 → `MUST_MASK` 는 쉬워지고
+    58	  **`MUST_NOT_MASK` 는 어려워진다.** 정직한 방향이다: 패딩이 이웃의 남겨야 할 값으로
+    59	  번지면 골든이 떨어진다.
+    60	
+    61	### 출력 안전성 확장 (`OUT_*`)
+    62	"0 extractable characters" 는 **세 누출 경로 중 하나**만 본다. 나머지 둘은 바이트를 읽어야 한다.
+    63	
+    64	| 누출 | 검사 |
+    65	|---|---|
+    66	| 잉크 밑 텍스트 레이어 (透ける黒塗り) | PDF 재파싱 → 추출 문자 0 |
+    67	| 렌더러가 보여주지 않는 메타데이터 | 바이트 스캔: 이미지 EXIF/XMP/IPTC, PDF `/Annots` `/EmbeddedFile` `/XFA` `/AcroForm` |
+    68	| 증분 저장 (리비전 1 = 미마스킹본이 같은 파일에 물리적으로 남음) | 바이트 스캔: `%%EOF` 정확히 **1개** |
+    69	
+    70	ICC 프로파일은 **금지하지 않되 경계를 둔다**: Chrome 이 붙이는 456바이트 일반 sRGB
+    71	프로파일은 색공간 선언이지 식별자가 아니다(태그 전수 확인: desc/rXYZ/gXYZ/bXYZ/wtpt/rTRC/cprt,
+    72	기기 식별 태그 0개). 진짜 위험은 **열람자의 디스플레이 프로파일**이고 그것은 제조사·모델
+    73	태그(`dmnd`/`dmdd`)를 달고 훨씬 크다 → 크기 상한 2KB + 그 태그 거부.
+    74	
+    75	---
+    76	
+    77	## B. 일본어 탐지 (JP-1)
+    78	
+    79	**전제대로: 정규식은 단독으로 자동 마스킹하지 않는다.** 자동 띠는 세 독립 합의를 요구한다 —
+    80	① 문서 분류 ② 같은 행의 레이블 앵커(또는 아래 명시한 좁은 구조 폴백) ③ 형식(個人番号는 체크디지트).
+    81	그 미만은 전부 **검토 후보**로 뜬다.
+    82	
+    83	비대칭은 의도적이다: 놓친 保険者番号 는 이 제품이 막으려는 바로 그 피해이고,
+    84	잘못 가린 氏名 은 제출이 반려되는 일이다. 그래서 자동 띠는 **법적 매트릭스가 "가려도 된다"고
+    85	적어둔 필드로만 한정**된다.
+    86	
+    87	### B-1. 정규화 — 원문↔정규화 인덱스 매핑 보존
+    88	박스는 아이템/문자 인덱스에서 나오므로, 정규화는 **원문으로 돌아가는 길을 절대 잃으면 안 된다.**
+    89	- **문자 단위로** NFKC 를 돌린다(문자열 단위가 아니라). 그래야 1→n 확장은 허용하면서
+    90	  n→1 결합(`ｶ`+`ﾞ`→`ガ`)이 원본 인덱스를 조용히 삼키는 일이 **구조적으로 불가능**해진다.
+    91	- 이체자 `髙→高 﨑→崎 邊/邉→辺` (1:1).
+    92	- **OCR 혼동은 문맥 조건부**: `ー/−/―/‐/—/－` → `-` 과 `〇/○/◯` → `0` 은 **숫자에 인접할 때만**,
+    93	  `l/I/|` → `1` 은 **양쪽이 다 숫자일 때만**.
+    94	  무조건 접으면 `コード` 가 `コ-ド` 가 되어 **二次元コード 레이블 앵커 자체가 깨진다** —
+    95	  실제로 이 픽스처에서 그 앵커가 유일한 탐지 경로다.
+    96	
+    97	### B-2. 행/세그먼트 모델
+    98	이 문서들은 **레이블–값 폼**이다. 행으로 묶고 수평 간격에서 **세그먼트**로 자른다.
+    99	임계값은 레이블→값 간격(이 배율에서 ~80px)보다 넓고 칸→칸 간격(~140px)보다 좁아야 한다 —
+   100	**페이지 폭의 10%** 가 알파 픽스처 전부에서 그 사이에 들어간다.
+   101	`rowText` 로 **행 전체**를 따로 들고 있는다: 날짜 문맥(`年月日`)은 칸이 아니라 줄 단위로 판단해야 한다.
+   102	
+   103	### B-3. 문서 분류기 (4종)
+   104	가중 키워드 투표. 가중치는 **배타성**을 뜻한다(資格確認書 는 다른 문서에 안 나오고,
+   105	本籍 은 戸籍 에도 나온다). 임계값이 단일 키워드가 아니라 **합**인 이유: OCR 은 어떤 줄이든
+   106	일정 비율을 반드시 뭉개는데, **알파 픽스처에서 뭉개지는 레이블이 매번 다르다.**
+   107	임계 미달이면 "일반 문서" 이고 **일본 자동 마스킹은 아예 일어나지 않는다.**
+   108	
+   109	실측 점수: kenpo 6 / kokuho 11 / kouki 9 / 免許 앞 9 · 뒤 10 / マイナ 앞 6 · 뒤 6 /
+   110	住民票 7~12 (임계 4).
+   111	
+   112	앞뒤 면은 `表面`/`裏面` 로 구분한다 — 두 면의 **법적 취급이 완전히 다르기 때문**이다.
+   113	
+   114	### B-4. 필드 추출
+   115	
+   116	| 항목 | 자동 조건 | 비고 |
+   117	|---|---|---|
+   118	| 個人番号 12자리 | 레이블(`個人番号`/`マイナンバー`) + 12자리 + **체크디지트 일치** | 불일치 → `recommend` 후보로 **강등**(아래) |
+   119	| 保険者番号 / 記号 / 番号 / 枝番 / 被保険者番号 | 資格確認書 분류 + 세그먼트 **선두** 레이블 | `番号` 단독 앵커 금지 → 선두일 때만(保険者番号·被保険者番号의 부분문자열) |
+   120	| 免許証番号 | 免許証 분류 + 선두 `番号` + `第…` 형식 | level `optional` (기본 OFF) |
+   121	| 住民票コード | 住民票 분류 + 11자리 | 법정 고정 길이 |
+   122	| 備考欄 / 臓器提供意思表示欄 | 레이블 + **그려진 사각형 탐지** | 아래 |
+   123	| 二次元コード | 레이블 + **측정된 블록으로 스냅** | 아래 |
+   124	| 本籍 / 筆頭者 / 세대원 블록 | 住民票 분류 + 레이블 / 氏名 행 경계 | level `recommend` |
+   125	| 電話·FAX | `TEL/電話/携帯/FAX` 앵커 + 일본 번호계획, 하이픈 없는 값은 후보 | 알파 4종에 전화번호가 **없다** → `jp_units` 6건으로 고정 |
+   126	| 住所 (레이블 없는 본문 내) | `郵便番号`+`都道府県` 동반 시 자동, 아니면 후보. 기관명 **감점** | 알파 4종의 `住所` 는 전부 `keep` → `jp_units` 8건으로 고정 |
+   127	| 生年月日 (和暦·西暦) | — | level `keep` (제출처가 요구) |
+   128	
+   129	#### 체크디지트 불일치 → 자동 아님
+   130	番号法施行令 별표의 Σ P_n·Q_n (Q_n = n+1 (n≤6), else n−5; check = 11−(Σ mod 11), ≥10→0).
+   131	**더미는 전략 §4 가 유효 체크디지트 생성을 금지하므로 전부 불일치한다.** 올바른 구현은
+   132	"이것이 個人番号다" 라고 단정하기를 거부하고 **既定ON 검토 후보로 강등**해야 한다.
+   133	→ 골든의 `JP_MASK_OR_CAND`: 띠 **또는** 후보. 하드 띠를 단언하면 골든이 **틀린 동작에 상을 주고**,
+   134	후보만 단언하면 "영영 탐지 못 함" 이 통과한다.
+   135	
+   136	#### 구조 폴백 — OCR 이 레이블을 파괴한 경우만, 좁게
+   137	`保険者番号` 레이블은 **5개 픽스처 중 3개에서** `RREES`/`REEES`/`WREEES` 로 읽혔다(실측).
+   138	그래서 資格確認書 로 분류된 페이지에서 **날짜 줄이 아닌 세그먼트의 순수 6~10자리 숫자열**을
+   139	保険者番号 계열로 본다. 근거: 告知要求制限 은 保険者番号·記号・番号・枝番 **전 계열을 하나의
+   140	규칙으로** 덮으므로 "어느 멤버인지" 를 틀려도 비용이 0이고, 놓치면 바로 그 유출이다.
+   141	住民票 은 더 좁다 — **12자리 = 個人番号, 11자리 = 住民票コード**, 둘 다 법정 고정 길이이고
+   142	그 폼에 그만큼 긴 다른 수가 없다.
+   143	
+   144	#### 欄(필드 박스)은 **그려진 사각형**으로 찾는다
+   145	欄 은 비어 있을 수 있다 — 텍스트 기반 탐지기에는 찾을 것이 없다. 그런데 **비어 보이는 칸이
+   146	바로 흐린 손글씨가 숨는 자리다.** 그래서 레이블 아래에서 첫 **150px 이상 연속 잉크 가로줄**을
+   147	찾고, x 범위가 ±12px 로 일치하는 다음 줄을 바닥으로 삼는다.
+   148	- 글자는 150px **연속** 잉크를 만들 수 없고, 대각선 워터마크 획도 마찬가지다.
+   149	- 스캔 시작점은 레이블의 **중간**이다(바닥이 아니라) — 免許証 裏面에서 備考欄 틀의 윗줄이
+   150	  레이블 글리프 박스와 겹친다(실측: 레이블 113–150, 틀 145).
+   151	- x 범위 일치 조건이 카드 외곽선(20..1080)을 欄(40..1060)의 바닥으로 오인하는 것을 막는다.
+   152	실측 결과 세 欄 전부 **픽셀 단위로 정확**: 免許 裏 `[40,145,1020,185]`·`[40,395,1020,165]`,
+   153	マイナ 表 `[40,328,721,90]`.
+   154	
+   155	#### 二次元コード — 라벨은 **신원**, 픽셀은 **경계**
+   156	레이블이 블록의 정체를 확정하고(→ 자동 띠), **경계는 픽셀로 측정한다**.
+   157	처음엔 레이블 텍스트 클러스터를 정사각으로 키웠는데, 레이블은 블록의 **한쪽 구석**에 있어서
+   158	띠가 어긋나 판독 가능한 띠가 남았다 — **피복 80%, 60% 게이트 통과.** 숫자는 통과시키고
+   159	눈은 바로 잡았다. 지금은 16px 셀 밀도 연결성분으로 측정한 블록에 **스냅**한다.
+   160	레이블은 있는데 블록이 측정되지 않으면(연한 색) 클러스터 정사각 + 10% 로 폴백한다.
+   161	
+   162	**레이블 없는 고대비 정사각 블록은 `candidate` 로만 낸다.** 더미에 진짜 QR 이 없어서(§4 금지)
+   163	그 경로는 **골든 커버리지가 없다** — 검증되지 않은 탐지가 스스로 픽셀을 지우면 안 된다.
+   164	(이 판정의 부수 효과로 マイナ 裏 의 코드 칸이 `[880,480,160,160]` 으로 **정확히** 측정됐다.)
+   165	
+   166	#### 세대원 블록 (住民票)
+   167	블록 1 = 본인, 2..n = 수령처가 요구하지 않은 제3자. `続柄`(本人/妻/子)는 한 글자라
+   168	OCR 이 레이블보다 훨씬 자주 뭉갠다 → **`氏名` 레이블 행으로 블록 경계를 잡는다.**
+   169	마지막 블록은 `この写し|相違|証明し|市長|…` 가 나오는 행에서 끝난다 — 그래야 **발행자·증명문이
+   170	남는다**(매트릭스 `keep`).
+   171	
+   172	#### 住所 계층 파서
+   173	`郵便番号 → 都道府県 → 市区郡町村 → 町域 → 丁目番地号 → 建物` 을 **하나의 정규식이 아니라
+   174	점수**로 다룬다. 일본 주소는 선택적 계층의 나열이라, 단일 정규식은 전부를 요구해서 대부분을
+   175	놓치거나 아무것도 요구하지 않아서 `市` 로 끝나는 회사명을 전부 잡는다.
+   176	
+   177	**앵커는 郵便番号 또는 47개 실제 都道府県 목록**이다. 그래서 지어낸 머리말 「架空県」 은
+   178	앵커가 될 수 없고 — 이것이 바로 「架空県後期高齢者医療広域連合」(保険者名) 과
+   179	「見本市長 架空 太郎」(발행자) 를 걸러내는 장치다. 都道府県을 요구하면 그것을 생략한 주소
+   180	(일본에서 흔하다)를 놓치지만, 알파에서는 **잘못 가린 발행자 = 반려** 쪽이 더 비싸다.
+   181	
+   182	기관명(`市役所|区役所|株式会社|大学|広域連合|…`)은 **제외가 아니라 감점(−2)** 이다(§3-2) —
+   183	실제 주소가 「…市役所前」 을 포함할 수 있기 때문이다. 감점은 스팬을 **8자 넘겨서까지** 본다.
+   184	걸러내려는 모양이 "도시 매칭이 기관명의 머리를 삼키는 것"(「大阪府見本市」+「役所」)이기 때문.
+   185	완전한 주소(5점)는 감점 후에도 3점으로 **후보로 남고**, 부분 주소(3점)는 1점으로 떨어진다.
+   186	
+   187	番地 꼬리는 **종결자에 앵커**한다 — 숫자처럼 보이는 글자가 아니라.
+   188	게으른 접두사 + 맨 숫자 형태는 지명 속 한자 수사에서 멈추고(「三条通一丁目二番三号」 가
+   189	「三」 만 잡혔다), 고정된 丁目/番/号 순서는 하이픈 형식(「霞が関1-3-2」)을 통째로 놓친다.
+   190	그래서 `NUM` 뒤에 `丁目|番地|番|号|-` 중 하나가 오는 **첫 위치**까지 건너뛴 뒤 그 쌍을
+   191	탐욕적으로 반복한다. 漢数字 `一〜十・百・千` 포함.
+   192	
+   193	**레이블 없는 주소**는 별도 필드 키(`address_loose`)로 낸다 — 레이블이 붙은 `住所` 는 네 문서
+   194	모두에서 수령처가 필요로 하는 `keep` 필드이고, 둘이 섞이면 안 된다. 레이블이 이미 차지한
+   195	문자는 소비 표시가 돼 있으므로 이 패스는 **스스로 서 있는 텍스트만** 본다(備考欄 내용 등).
+   196	
+   197	#### 오탐 가드
+   198	- 모든 값 규칙은 **세그먼트 선두 앵커**. 이 폼에서 레이블은 항상 자기 칸을 연다.
+   199	  (이 가드가 없을 때 マイナ 裏 의 각주 「裏面の生年月日有無は…要確認」 가 生年月日 필드로 읽혔다 — 실측.)
+   200	- 日付·金額 단독 숫자열은 자동 마스킹하지 않는다(날짜 줄 제외 + 길이 조건).
+   201	- 기존 `max_auto` 상한 체계를 일본 픽스처 전부에 적용(실측 auto: kenpo 5 · kouki 3 · kokuho 5 ·
+   202	  免許 0 · マイナ 表 0 · 裏 1 · 住民票 0~1).
+   203	- **JP 분류가 서면 라틴 이름/주소 휴리스틱을 끈다.** 그 휴리스틱은 이력서 타이포그래피용이라
+   204	  JP 폼에서는 `(被用者`·`カー`·`裏面` 같은 쓰레기만 만들었고, 법적 근거가 있는 프리셋 옆에서
+   205	  똑같이 권위 있어 보인다.
+   206	
+   207	#### ⚠ 이번에 **실제로 잡은 결함 2건** (둘 다 숫자가 아니라 그림이 잡았다)
+   208	1. **`保険者番号` 의 선두 숫자가 띠 밖으로 남았다.** Tesseract 가 단어를 ` 99221010` 로
+   209	   (앞 공백 포함) 돌려주는데 bbox 는 **잉크 박스**다. 공백을 남기면 `str.length` 가 1 많고
+   210	   모든 문자 박스가 폭/길이로 나뉘므로 전체가 한 칸 오른쪽으로 밀린다 → 첫 `9` 가 ~7px 노출.
+   211	   피복률은 **96%** 라 게이트를 통과했다. `ocrCanvas` 에서 `w.text.trim()`.
+   212	2. **二次元コード 띠 어긋남** (위 참조, 피복 80%로 통과).
+   213	
+   214	---
+   215	
+   216	## C. 목적 선택 + 프리셋
+   217	
+   218	업로드 직후 **提出目的** 선택이 뜬다 — `本人確認提出 / 個人番号手続 / 入札添付 / 相談用共有`,
+   219	매트릭스 `purposes` 키와 1:1. 기본 `identity_submit`.
+   220	
+   221	목적을 바꾸면 **모드를 고쳐 쓰는 것이 아니라 엔티티를 다시 유도한다** — 목적이 곧 정책이다.
+   222	
+   223	| level | kind | 기본 mode | UI |
+   224	|---|---|---|---|
+   225	| `auto` / `auto_with_purpose_gate` | `auto` | `no` | 카테고리 목록 |
+   226	| `recommend` | `candidate` | **`no`** (既定ON·해제 가능) | 要確認 섹션 |
+   227	| `optional` | `candidate` | `ok` (기본 OFF) | 要確認 섹션 |
+   228	| `keep` | `keep` | `ok` | **残す項目** 섹션 (🛡) |
+   229	
+   230	`keep` 항목을 사용자가 가리려 하면 경고한다 —
+   231	「提出先が受付できない可能性があります（本人特定事項）」. 개별 토글과 **일괄 비공개** 양쪽에서.
+   232	일괄 버튼은 같은 결정을 한 번에 내리는 것이므로 같은 경고가 필요하다.
+   233	
+   234	**マイナカード裏面 + 本人確認 목적 → 면 전체 띠 + 안내문**
+   235	「身元確認なら表面のみ提出。番号法により、法定目的以外で裏面の個人番号を収集・保管することは
+   236	できません。「個人番号手続」を選ぶと解除されます。」 — 番号法 상 수령처가 身元確認 목적으로
+   237	個人番号 를 보유할 수 없으므로, 정직한 안내는 "앞면을 내라" 이고 띠가 그렇게 말한다.
+   238	
+   239	**매트릭스와의 명시적 차이 1건**: `本籍`/`筆頭者` 에 `my_number_procedure`·`bid_attachment` 를
+   240	추가했다(level 은 `recommend` 그대로). 本籍 은 個人番号 사무에도 입찰에도 필요 없고,
+   241	픽스처 기대값(`honseki_on` 의 個人番号手続 mask)이 그렇게 적혀 있다. **가릴 수 있는 범위를
+   242	넓히는 방향**이라 안전 쪽이다.
+   243	
+   244	### 워터마크 프리셋 (ja)
+   245	「○○ 提出用」「本人確認のみに使用」「転用禁止」「{date} ○○ に提出」.
+   246	`{date}` 는 **오늘 날짜로 실제 치환**된다 — 날짜 프리셋의 존재 이유가 "언제 건넸는지 보이게"
+   247	인데 `YYYY-MM-DD` 라고 적힌 워터마크는 아무 말도 하지 않는다. 4개 언어 모두 같은 구성.
+   248	
+   249	---
+   250	
+   251	## D. 골든 확장
+   252	
+   253	**11 png (資格確認書 3 · 免許証 2 · マイナカード 2 · 住民票 4) + 3 jpg + 1 pdf**,
+   254	목적 2종 교차(마이나 裏·住民票 zenin·honseki_on 에 `個人番号手続`, 免許 裏에 `相談用共有`)
+   255	= **19 케이스 / 215 단언** + `jp_units` 14건.
+   256	
+   257	- **좌표계**: PNG 는 원본 크기, PDF 는 `min(2.2, 1500/ptWidth)` 배 — **단일 균일 배율**이라
+   258	  하드코딩하지 않고 `page.w / fixtureWidth` 로 런타임에 구한다.
+   259	  **JPG 는 일부러 회전·흐림(휴대폰 촬영)** 이라 PNG 좌표에 떨어질 수 없다 →
+   260	  그 케이스는 **필드 수준**(탐지됐는가·띠가 켜졌는가)으로 단언하고 **그렇다고 적는다**.
+   261	  맞을 수 없는 좌표를 조용히 비교하지 않는다.
+   262	- **단언 종류는 매트릭스 level 에서 나온다, 픽스처가 어느 목록에 넣었는지가 아니라.**
+   263	  목적의 `mask` 목록에는 자동 강도와 권장 강도가 **섞여** 있고 그 둘은 다른 약속이다.
+   264	  `specs.json` 의 `jp_auto_fields` 가 그 매핑을 들고 있어서 **하네스가 테스트 대상 앱과
+   265	  독립적으로** 판정한다.
+   266	- **박스 피복 기준**: 박스 안에 텍스트 아이템이 있으면 *각 아이템이* ≥60% 덮였는지
+   267	  (의미 있는 질문은 "읽을 수 있는 글자가 덮였는가" 이지 "생성기가 넣은 여백까지 칠했는가"가 아니다),
+   268	  없으면(빈 欄·코드 칸) 박스 면적 ≥60%. `keep` 은 ≤10%.
+   269	- **`JP_COVERAGE`**: 각 케이스가 **실제로 몇 개 박스를 검사했는지**와 **건너뛴 키**를 출력하고,
+   270	  0이면 실패한다. 0건 검사하고 통과하는 하네스는 40건 검사한 하네스와 **같은 초록색**을 찍는다.
+   271	  ⚠ 이 가드는 추가 직후 **내 자신의 집계 결함을 잡았다** — `mask:["ALL"]` 경로가 카운터를
+   272	  올리지 않고 있었다. `canonical_sweep.rb` 가 sitemap 이 죽으면 0건 검사하고 통과하던 것과
+   273	  같은 모양을, 그 교훈이 적힌 저장소에서 또 만들 뻔했다.
+   274	
+   275	- **`JP_CLEAR` (목적 게이트의 반대 방향)**: `require_banded` 만 있으면 "相談用共有에서 띠가
+   276	  켜진다" 는 단언이 **모든 목적에서 켜져 있어도** 통과한다. 같은 문서·같은 필드를 두 목적으로
+   277	  돌려 한쪽은 `clear`, 다른 쪽은 `banded` 를 단언한다 — 그래야 게이트가 *움직인다*는 말이 된다.
+   278	
+   279	### 하네스가 공허하지 않다는 증거 (변이 4건, 전부 실제 주입·재측정)
+   280	[`s3_golden_result.md`](s3_golden_result.md) 말미 참조. 요약: 구조 폴백 제거 → 4건 실패,
+   281	세대원 규칙 제거 → 13건 실패, `keep`→`recommend` 승격 → 4건 실패, 빈 검사 가드 → 1건 실패
+   282	(마지막은 **가드가 추가 직후 내 자신의 집계 결함을 잡은 것**).
+   283	
+   284	---
+   285	
+   286	## E. 검증 요약
+   287	
+   288	| 검증 | 결과 |
+   289	|---|---|
+   290	| `cd test/safe && node run.mjs` | **389/389 pass · 0 FAIL · exit 0** (직전 130/130) |
+   291	| 변이 프로브 4건 | 전부 의도대로 **실패를 일으킴** |
+   292	| `cd test/sw && node offline_resilience.mjs` | **9/9 통과** (회귀 없음) |
+   293	| 렌더 육안 검증 (`render.mjs`) | 資格確認書 2 · 住民票 1 · 免許証 앞·뒤 · マイナ 表 — 전부 의도대로 |
+   294	| 목적 게이트 차등 (`JP_CLEAR`↔`JP_BANDED`) | 免許 裏 `address_loose`: 本人確認提出=clear / 相談用共有=banded |
+   295	| JS 구문 검사 (`node --check`) | 통과 |
+   296	| 페이지 콘솔 에러 | 0 (SW 등록 404 는 하네스가 sw.js 를 서빙하지 않아서 — 기존과 동일) |
+   297	| 프로덕션 DB | **미접촉** |
+   298	| 배포 | **하지 않음** |
+   299	
+   300	---
+   301	
+   302	## F. 남은 이슈 · 미확인 항목
+   303	
+   304	### 미확인 (전략 §8 그대로 남음)
+   305	- **マイナンバーカード 裏面의 生年月日 인쇄 여부.** 매트릭스가 `unverified` 로 표기한 그대로다.
+   306	  더미에는 있고 구현은 있으면 `keep`(個人番号手続) 으로 다룬다. **공식 견본으로 확인 필요** —
+   307	  없다면 그 필드 규칙은 죽은 코드가 되고, 있다면 현재 취급이 맞다. 어느 쪽이든 유출 방향은 아니다.
+   308	- 카드 더미의 법적 안전선 — 일본 변호사 검토 전 **내부 전용** (§4).
+   309	
+   310	### 커버리지가 약한 구현 (= 알고 있는 공백)
+   311	1. **레이블 없는 QR/바코드 탐지 — 픽스처·유닛 둘 다 없음.** 더미에 진짜 QR 이 없어서(§4 금지)
+   312	   검증 불가 → 그래서 **candidate 로만** 낸다. 실제 資格確認書 사본으로 검증한 뒤에야
+   313	   자동으로 올릴 수 있다. *(마이나 裏의 코드 칸을 `[880,480,160,160]` 으로 정확히 측정한
+   314	   것은 같은 탐지기의 부수 결과지만, 그것은 "회색 사각형"이지 QR 이 아니다.)*
+   315	2. **電話·FAX — 유닛만 (`jp_units` 6건).** 알파 4종에 전화번호가 **없다.** 번호계획 정규식과
+   316	   하이픈 유무에 따른 자동/후보 분기는 유닛으로 고정했지만, **실제 문서에서 레이블 앵커를 타고
+   317	   박스로 변환되는 경로는 한 번도 실행된 적이 없다.**
+   318	3. **住所 계층 파서 — 유닛 8건 + `address_loose` 경로 1건.** 알파 4종에서 레이블 붙은 住所 는
+   319	   전부 `keep` 이라, 점수 판정이 *아무것도 결정하지 않는다*. 점수·감점·番地 파싱은 유닛으로
+   320	   고정했고, 레이블 없는 경로는 免許 裏 備考欄의 住所変更 줄 하나로 목적 차등까지 확인했다.
+   321	   **郵便番号+都道府県 동반 → 자동** 분기는 유닛에서만 참이다 — 실제 문서로 본 적이 없다.
+   322	4. **多ページ 일본 문서.** 픽스처가 전부 1페이지다. 분류는 페이지별로 돌고 2페이지 이후는
+   323	   1페이지 분류를 상속하는데(`jpScan`), 이 경로는 실행된 적이 없다.
+   324	
+   325	### 설계상 남겨둔 것
+   326	- **資格確認書 의 6~10자리 폴백은 분류기에 전적으로 기댄다.** 분류기가 틀리면 숫자 하나가
+   327	  잘못 가려진다. 비용은 재제출이고, 반대 방향(미탐)의 비용은 번호 유출이다. 그 교환을
+   328	  의식적으로 선택했다 — 다만 **분류 임계값(4) 은 알파 4종 11개 픽스처로만 조정됐다.**
+   329	- `その他` 카테고리가 `back_all`·`qr` 를 담는다. 사용자가 그 **카테고리 토글**을 끄면
+   330	  マイナ 裏 전체 띠가 사라진다. 카테고리 토글은 원래 사용자 권한이지만, 법적 근거로 걸린
+   331	  띠에까지 같은 권한을 주는 것이 맞는지는 제품 판단이다.
+   332	- `displayValue` 가 `keep` 항목의 **원문을 그대로 보여준다**(mode `ok`). 의도대로지만,
+   333	  화면 공유 중이라면 그것도 노출이다. 전역 "목록 가리기" 토글은 범위 밖으로 뒀다.
+   334	
+   335	### 이전 세션들에서 넘어온 관찰 (이번 작업과 무관, 그대로 유지)
+   336	- `<html lang>`·`og:locale`·UI 크롬은 여전히 Accept-Language 로 협상된다. 제품 결정.
+   337	- CI 의 `lint`(rubocop 86건)·`scan_ruby`(brakeman 6건)는 **이번 브랜치 이전부터** 빨갛다.
+   338	- `rake jobs:failed` 의 프로덕션 큐 DB 실측은 **배포 후 확인 항목**.
+  1577	## SafeFile JP-1 알파 — 띠 단일화 + 일본 4종 탐지 + 목적 프리셋 (2026-10-21)
+  1578	
+  1579	브랜치 `main`. **미배포.** 프로덕션 DB 미접촉.
+  1580	보고 [`docs/jp/s3_report.md`](docs/jp/s3_report.md) · 전체 로그 [`docs/jp/s3_golden_result.md`](docs/jp/s3_golden_result.md)
+  1581	전략 [`docs/jp/jp_safefile_strategy_v2_2026-10-21.md`](docs/jp/jp_safefile_strategy_v2_2026-10-21.md) §3·§7
+  1582	법적 정본 [`test/safe/fixtures/jp/jp_legal_matrix_alpha4.json`](test/safe/fixtures/jp/jp_legal_matrix_alpha4.json)
+  1583	
+  1584	**골든 130 → 389, 0 실패.** SW 하네스 9/9 유지.
+  1585	
+  1586	### 1. 마스킹이 **띠만** 남았다 (모드 3 → 2)
+  1587	부분 마스킹은 비밀의 일부를 배경색 패치 **위에 다시 그린다** — 안전성이 "우리가 얼마나
+  1588	드러내기로 했는가" 에 달려 있고, 제출하는 사람은 결과 파일만 보고 그 판단을 감사할 수 없다.
+  1589	띠에는 그 자유도가 없다. 부분이 기본이던 유형은 전부 띠 기본이 됐다(더 많이 가린다).
+  1590	`drawRedactions` 의 오버랩 에스컬레이션 경로 전체가 **모드와 함께 사라졌다** — 두 별표
+  1591	문자열이 서로 위에 그려지던 실패 종류가 통째로 없어졌다.
+  1592	
+  1593	- `bandRect()` = 박스 + max(높이 15%, 2px). 박스는 **추정치**다(pdf.js 는 사이드베어링 제외,
+  1594	  OCR 은 안티앨리어싱 가장자리 절단). `region:true`(사람이 드래그한 영역·탐지된 欄)는 **키우지 않는다** — 그건 추정이 아니라 의도다.
+  1595	- 띠 색: 먹(기본)·흰색·지정 1색.
+  1596	- 골든의 `__maskRects` 가 **패딩 적용 후**를 잰다 → `MUST_NOT_MASK` 가 더 엄격해졌다.
+  1597	
+  1598	### 2. 출력 안전성: "0 extractable characters" 는 **세 누출 중 하나**다
+  1599	나머지 둘은 바이트를 읽어야 보인다 — 이미지 EXIF/XMP/IPTC, PDF `/Annots`·`/EmbeddedFile`,
+  1600	그리고 **증분 저장**(리비전 1 = 미마스킹본이 같은 파일에 물리적으로 남음 → `%%EOF` 정확히 1개).
+  1601	ICC 는 금지하지 않되 경계를 둔다: Chrome 의 456B 일반 sRGB 는 색공간 선언이지만
+  1602	**열람자의 디스플레이 프로파일**은 제조사·모델 태그(`dmnd`/`dmdd`)를 달고 훨씬 크다.
+  1603	
+  1604	### 3. 일본 탐지 — 정규식 단독 자동마스킹 금지
+  1605	자동 띠 = ① 문서분류 ∧ ② 같은 행 레이블 앵커 ∧ ③ 형식(個人番号는 체크디지트). 그 미만은 후보.
+  1606	
+  1607	- **NFKC 를 문자 단위로** 돌린다 → 1→n 확장은 허용하되 n→1 결합(`ｶ`+`ﾞ`→`ガ`)이 원본
+  1608	  인덱스를 삼키는 일이 **구조적으로 불가능**.
+  1609	- **OCR 혼동 접기는 문맥 조건부.** `ー`→`-` 를 무조건 접으면 `コード`→`コ-ド` 가 되어
+  1610	  **二次元コード 앵커 자체가 깨진다** — 그게 이 픽스처의 유일한 코드 탐지 경로였다.
+  1611	- 세그먼트 분리 임계 = 페이지 폭 10%. 레이블→값 간격(~80px)보다 넓고 칸→칸(~140px)보다 좁다.
+  1612	- 분류는 **가중 합**이지 단일 키워드가 아니다 — OCR 은 어떤 줄이든 뭉개는데 **뭉개지는 레이블이
+  1613	  매번 다르다**(`保険者番号` 가 5개 중 3개에서 `RREES`/`REEES`/`WREEES`).
+  1614	- 欄(備考欄·臓器提供欄)은 **그려진 사각형**으로 찾는다(150px 연속 잉크 가로줄 + x범위 ±12px).
+  1615	  비어 보이는 칸이 바로 흐린 손글씨가 숨는 자리다. 세 欄 전부 픽셀 단위로 정확.
+  1616	- **二次元コード: 라벨은 신원, 픽셀은 경계.** 라벨 클러스터를 정사각으로 키우면 라벨이 블록
+  1617	  한쪽 구석에 있어 띠가 어긋난다. 레이블 없는 블록은 **candidate 로만** 낸다(진짜 QR 더미가
+  1618	  §4 로 금지돼 골든 커버리지가 없다 — 검증 안 된 탐지가 스스로 픽셀을 지우면 안 된다).
+  1619	
+  1620	### ⚠ 숫자는 통과시키고 **그림이 잡은 결함 2건**
+  1621	1. `保険者番号` 선두 숫자가 띠 밖으로 남았다 — Tesseract 가 ` 99221010` 처럼 **앞 공백 포함**
+  1622	   문자열을 주는데 bbox 는 잉크 박스다. 공백을 세면 문자 폭 계산이 한 칸 밀린다. **피복률 96%.**
+  1623	   → `ocrCanvas` 에서 `w.text.trim()`.
+  1624	2. 二次元コード 띠 어긋남 — **피복 80%, 60% 게이트 통과.**
+  1625	
+  1626	⇒ **피복률은 "얼마나" 를 말하지 "어디" 를 말하지 않는다.** `test/safe/render.mjs` 를
+  1627	고정했다(게이트 아님, 육안 검증 전용).
+  1628	
+  1629	### 4. 골든이 공허하지 않은지 **변이로 확인**
+  1630	구조 폴백 제거 → 4건 실패 / 세대원 규칙 제거 → 13건 실패 / `keep`→`recommend` → 4건 실패.
+  1631	⚠ **`JP_COVERAGE`(검사한 박스 수가 0이면 실패) 가드는 추가 직후 내 자신의 집계 결함을 잡았다**
+  1632	— `mask:["ALL"]` 경로가 카운터를 안 올리고 있었다. `canonical_sweep.rb` 가 sitemap 이 죽으면
+  1633	0건 검사하고 통과하던 것과 **같은 모양**을, 그 교훈이 적힌 저장소에서 또 만들 뻔했다.
+  1634	`JP_CLEAR` 도 같은 이유다 — `require_banded` 만 있으면 "이 목적에서 띠가 켜진다"는 단언이
+  1635	**모든 목적에서 켜져 있어도** 통과한다.
+  1636	
+  1637	### 5. 남은 공백 (다음 런)
+  1638	- **레이블 없는 QR**: 픽스처·유닛 둘 다 없음 → candidate 고정.
+  1639	- **電話·FAX / 住所 자동 분기**: 알파 4종에 전화번호가 없고 住所 는 전부 `keep` →
+  1640	  `jp_units` 로만 고정했다. **실제 문서에서 박스로 변환되는 경로는 한 번도 실행된 적이 없다.**
+  1641	- **多ページ 일본 문서**: 픽스처가 전부 1페이지. 2페이지 이후 분류 상속 경로 미실행.
+  1642	- 운영 메모: `test/sw/node_modules` 는 `ln -s ../safe/node_modules` 로 공유한다(README 갱신).
+  1643	
+  1644	### JP-1 이슈 로그
+  1645	
+  1646	**2026-10-21 · 미해결 · 사람 판단 필요 — 카드 더미를 공개 저장소에 커밋한 건**
+  1647	`chaop2026/docpack` 은 **PUBLIC** 이다(`gh repo view` 확인). 전략 v2 §4 는
+  1648	「개별 고해상 카드 파일은 공개 배포 금지 / 법률 검토 전까지 카드 더미는 내부 테스트 전용」
+  1649	이라고 적고 있다. 커밋하면 그 보류를 사실상 해제하는 셈이다.
+  1650	
+  1651	**그럼에도 커밋한 이유**와 **줄인 범위**:
+  1652	- §4 의 *생성* 안전조건은 전부 충족한다 — 와이어프레임형, 전면 「見本・架空・本人確認に
+  1653	  使用不可」 워터마크, 公安委員会名·관인·로고·실제 QR·IC 표시 전부 없음, 체크디지트 불일치,
+  1654	  실존 불가 주소, 架空 인명, 사진 없음(빈 회색 패널). 오용 가치는 사실상 0이다.
+  1655	  남은 제약은 "이 파일들이 위험하다" 가 아니라 **"일본 변호사 검토 전까지 보류"** 다.
+  1656	- 골든 하네스가 그 파일 없이는 **돌지 않는다.** `gen.py` 는 결정적이지만 Linux + Noto CJK
+  1657	  전제라 이 맥에서 재생성이 불가능하고, 재생성하면 PIL 버전 차이로 **박스 좌표가 흔들려
+  1658	  모든 spec 이 깨진다.**
+  1659	- **줄인 것**: `docs/jp/jp_fixtures_alpha4.zip`(6.1MB, 같은 바이트의 중복)은 **커밋하지 않고
+  1660	  gitignore** 했다 — zip 은 기술적 목적이 없고 모양 자체가 재배포다.
+  1661	  `test/safe/fixtures/jp/README.md` 에 §4 상태를 명시했다.
+  1662	
+  1663	→ **사람이 결정할 것**: (a) 이대로 둔다 / (b) 픽스처를 별도 비공개 저장소로 옮기고
+  1664	submodule 로 받는다 / (c) 변호사 검토 후 재판단. **푸시 전에 결정하는 편이 싸다** —
+  1665	공개 git 히스토리는 되돌리기 어렵다.
+
+hook: PostToolUse
+hook: PostToolUse Completed
+codex
+정적 대조에서 이미 중요한 불일치가 보입니다. 예를 들어 법적 정본은 `資格確認書` 번호군을 `my_number_procedure`에서 규정하지 않는데 구현 폴백은 일률 `optional`로 노출하고, `住民票コード`는 정본 자체가 `verified:false`인데 자동 띠입니다. 이제 하네스가 이 차이를 실제로 잡는지와 출력물 검사를 확인하겠습니다.
+hook: PreToolUse
+hook: PreToolUse Completed
+exec
+/bin/zsh -lc 'node run.mjs' in /Users/sunghoon/Projects/docpack/test/safe
+ exited 1 in 310ms:
+node:events:486
+      throw er; // Unhandled 'error' event
+      ^
+
+Error: listen EPERM: operation not permitted 127.0.0.1
+    at Server.setupListenHandle [as _listen2] (node:net:1994:21)
+    at listenInCluster (node:net:2073:12)
+    at node:net:2282:7
+    at process.processTicksAndRejections (node:internal/process/task_queues:90:21)
+Emitted 'error' event on Server instance at:
+    at emitErrorNT (node:net:2052:8)
+    at process.processTicksAndRejections (node:internal/process/task_queues:90:21) {
+  code: 'EPERM',
+  errno: -1,
+  syscall: 'listen',
+  address: '127.0.0.1'
+}
+
+Node.js v25.6.1
+
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+exec
+/bin/zsh -lc "git show 546344b:test/safe/run.mjs | nl -ba | sed -n '1,260p'; git show 546344b:test/safe/run.mjs | nl -ba | sed -n '260,560p'; git show 546344b:test/safe/run.mjs | nl -ba | sed -n '560,900p'" in /Users/sunghoon/Projects/docpack
+ succeeded in 0ms:
+     1	#!/usr/bin/env node
+     2	/*
+     3	 * Golden verification harness for the SafeFile PII pipeline.
+     4	 *
+     5	 * Serves the REAL public/safe/index.html in headless Chrome, drives the live
+     6	 * detection over each fixture, and checks every value against specs.json:
+     7	 *   - MUST_MASK      : value is geometrically covered by an active mask rect
+     8	 *   - MUST_NOT_MASK  : value is NOT covered by any mask rect
+     9	 *   - NEVER_CANDIDATE: value is not proposed as a review candidate
+    10	 *   - SHOULD_CANDIDATE: value surfaces as a candidate (visible, not hidden)
+    11	 *   - AI_INJECT      : adversarial AI labels are neutralised in addEntities
+    12	 *   - TEXT_LEAK      : output PDF has 0 extractable characters
+    13	 *   - OUT_SAFE       : output carries no annots/embedded files/incremental save/EXIF
+    14	 *
+    15	 * Requires: node, playwright (chrome channel). Fixtures from generate_fixtures.py.
+    16	 * Usage: node run.mjs [--only 7_resume_dark.pdf]  (exit 0 = all pass)
+    17	 */
+    18	import { chromium } from 'playwright';
+    19	import http from 'node:http';
+    20	import fs from 'node:fs';
+    21	import path from 'node:path';
+    22	import { fileURLToPath } from 'node:url';
+    23	
+    24	const __dirname = path.dirname(fileURLToPath(import.meta.url));
+    25	const REPO = path.resolve(__dirname, '..', '..');
+    26	const PUBLIC = path.join(REPO, 'public');
+    27	const DOCS = path.join(__dirname, 'testdocs');
+    28	const FIXTURES = path.join(__dirname, 'fixtures');
+    29	const SPECS = JSON.parse(fs.readFileSync(path.join(__dirname, 'specs.json'), 'utf8'));
+    30	const OUT = path.join(__dirname, 'out');
+    31	fs.mkdirSync(OUT, { recursive: true });
+    32	
+    33	const onlyArg = (() => { const i = process.argv.indexOf('--only'); return i >= 0 ? process.argv[i + 1] : null; })();
+    34	
+    35	const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json', '.txt': 'text/plain' };
+    36	
+    37	function startServer() {
+    38	  return new Promise(resolve => {
+    39	    const srv = http.createServer((req, res) => {
+    40	      let p = decodeURIComponent(req.url.split('?')[0]);
+    41	      if (p === '/') p = '/index.html';
+    42	      const fp = path.join(PUBLIC, p);
+    43	      if (!fp.startsWith(PUBLIC) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end('nf'); return; }
+    44	      res.writeHead(200, { 'content-type': MIME[path.extname(fp)] || 'application/octet-stream' });
+    45	      fs.createReadStream(fp).pipe(res);
+    46	    });
+    47	    srv.listen(0, '127.0.0.1', () => resolve(srv));
+    48	  });
+    49	}
+    50	
+    51	// ── in-page helpers, serialised into the browser context ──
+    52	const PAGE_HELPERS = () => {
+    53	  // Active mask rects: every entity that is ON, not 'ok', and located — passed
+    54	  // through bandRect() so the harness measures the pixels that are ACTUALLY
+    55	  // painted (box + padding), not the pre-padding estimate. This makes MUST_MASK
+    56	  // easier and MUST_NOT_MASK harder, which is the honest direction: a padding
+    57	  // that bleeds onto a neighbouring must-keep value now fails the golden.
+    58	  window.__maskRects = function () {
+    59	    const rects = [];
+    60	    for (const e of entities) {
+    61	      if (!isOn(e) || e.mode === 'ok' || !(e.boxes && e.boxes.length)) continue;
+    62	      for (let pi = 0; pi < pages.length; pi++) {
+    63	        for (const l of mergeLineBoxes(e.boxes, pi)) { const r = bandRect(l); rects.push({ pi, x: r.x, y: r.y, w: r.w, h: r.h }); }
+    64	      }
+    65	    }
+    66	    return rects;
+    67	  };
+    68	  window.__rectsFor = function (v) {
+    69	    return boxesForValue(v).map(b => ({ pi: b.page, x: b.x, y: b.y, w: b.w, h: b.h }));
+    70	  };
+    71	  window.__isMasked = function (v) {
+    72	    const mr = window.__maskRects(), vr = window.__rectsFor(v);
+    73	    const ov = (a, b) => {
+    74	      if (a.pi !== b.pi) return 0;
+    75	      const ix = Math.max(0, Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x));
+    76	      const iy = Math.max(0, Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y));
+    77	      return ix * iy;
+    78	    };
+    79	    for (const b of vr) { const area = b.w * b.h; if (area <= 0) continue; for (const a of mr) if (ov(a, b) > area * 0.25) return true; }
+    80	    return false;
+    81	  };
+    82	  const norm = s => (s || '').toLowerCase().replace(/\s+/g, ' ').replace(/[.,;:'"()]+$/g, '').replace(/^[.,;:'"()]+/g, '').trim();
+    83	  window.__norm = norm;
+    84	  window.__entitySnapshot = function () {
+    85	    return entities.map(e => ({ type: e.type, value: e.value, kind: e.kind, mode: e.mode, reason: e.reason, located: !!(e.boxes && e.boxes.length) }));
+    86	  };
+    87	  /* ── JP: geometry is checked against the FIXTURE'S OWN box table, not against
+    88	     a value string. A Japanese form's value is exactly what OCR mangles
+    89	     (美咲 → "S=0%"), so asserting on the string would test Tesseract, not us;
+    90	     the box is what the band has to cover either way. ── */
+    91	  // fraction of `rect` (page coords) covered by the union of active mask rects,
+    92	  // sampled on a grid so overlapping bands count once.
+    93	  window.__coverage = function (rect) {
+    94	    const mr = window.__maskRects().filter(r => r.pi === rect.pi);
+    95	    if (!mr.length) return 0;
+    96	    const N = 24; let hit = 0;
+    97	    for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) {
+    98	      const x = rect.x + rect.w * (i + 0.5) / N, y = rect.y + rect.h * (j + 0.5) / N;
+    99	      if (mr.some(r => x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h)) hit++;
+   100	    }
+   101	    return hit / (N * N);
+   102	  };
+   103	  // OCR/text item boxes whose centre falls inside `rect`
+   104	  window.__itemsIn = function (rect) {
+   105	    const p = pages[rect.pi]; if (!p) return [];
+   106	    return (p.items || []).filter(it => it.x + it.w / 2 >= rect.x && it.x + it.w / 2 <= rect.x + rect.w
+   107	                                     && it.y + it.h / 2 >= rect.y && it.y + it.h / 2 <= rect.y + rect.h)
+   108	      .map(it => ({ pi: rect.pi, x: it.x, y: it.y, w: it.w, h: it.h }));
+   109	  };
+   110	  // any ACTIVE candidate entity overlapping `rect` (did the field surface for review?)
+   111	  window.__candidateOver = function (rect) {
+   112	    for (const e of entities) {
+   113	      if (e.kind !== 'candidate' || !e.boxes) continue;
+   114	      for (const b of e.boxes) {
+   115	        if (b.page !== rect.pi) continue;
+   116	        if (!(b.x + b.w < rect.x || rect.x + rect.w < b.x || b.y + b.h < rect.y || rect.y + rect.h < b.y)) return true;
+   117	      }
+   118	    }
+   119	    return false;
+   120	  };
+   121	  window.__jpState = function () {
+   122	    return { cls: jpState.cls && { doc: jpState.cls.doc, side: jpState.cls.side || null, score: jpState.cls.score },
+   123	      purpose: jpState.purpose, pw: pages.map(p => p.w),
+   124	      fields: entities.filter(e => e.jp).map(e => ({ field: e.jp.field, level: e.jp.level, note: e.jp.note, kind: e.kind, mode: e.mode })) };
+   125	  };
+   126	  window.__isCandidateExact = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value) === n); };
+   127	  window.__isCandidateContains = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value).includes(n)); };
+   128	  // default mode of the candidate whose value contains v (null if not a candidate)
+   129	  window.__candidateMode = function (v) { const n = norm(v); const e = entities.find(x => x.kind === 'candidate' && norm(x.value).includes(n)); return e ? e.mode : null; };
+   130	  // name-bar geometry: glyph union (raw pdf items) vs drawn bar rect
+   131	  window.__nameBar = function (v) {
+   132	    const rects = boxesForValue(v).filter(b => b.page === 0);
+   133	    if (!rects.length) return null;
+   134	    const lines = mergeLineBoxes(rects, 0); const bar = lines[0];
+   135	    // glyph union straight from page items overlapping the value
+   136	    const its = (pages[0].items || []).filter(it => (v.split(/\s+/).some(w => (it.str || '').includes(w))));
+   137	    if (!its.length) return null;
+   138	    const gx0 = Math.min(...its.map(i => i.x)), gy0 = Math.min(...its.map(i => i.y));
+   139	    const gx1 = Math.max(...its.map(i => i.x + i.w)), gy1 = Math.max(...its.map(i => i.y + i.h));
+   140	    const gW = gx1 - gx0, gH = gy1 - gy0;
+   141	    // replicate the drawn-band geometry exactly as the page would paint it.
+   142	    const drawn = bandRect(bar);
+   143	    // Ink safety: the bar must cover the full glyph WIDTH and, vertically, the
+   144	    // cap-height→descent band (raw pdf font box minus the top ascent gap where
+   145	    // no ink lives). It should NOT need to cover the empty ascent whitespace.
+   146	    const inkTop = gy0 + gH * 0.18, inkBot = gy1;
+   147	    const coversInk = drawn.x <= gx0 + 1 && drawn.x + drawn.w >= gx1 - 1 && drawn.y <= inkTop + 1 && drawn.y + drawn.h >= inkBot - 1;
+   148	    return { barW: bar.w, barH: bar.h, drawnH: drawn.h, drawnW: drawn.w, glyphW: gW, glyphH: gH, containsGlyph: coversInk };
+   149	  };
+   150	};
+   151	
+   152	// `jp/...` paths resolve under fixtures/, everything else under testdocs/.
+   153	const docPath = file => file.startsWith('jp/') ? path.join(FIXTURES, file) : path.join(DOCS, file);
+   154	async function loadDoc(page, file, ocr) {
+   155	  await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
+   156	  await page.setInputFiles('#fileInput', docPath(file));
+   157	  await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0, { timeout: ocr ? 240000 : 40000 });
+   158	  await page.waitForTimeout(ocr ? 800 : 400);
+   159	  await page.evaluate(PAGE_HELPERS);
+   160	}
+   161	
+   162	const rows = [];
+   163	const rec = (doc, cat, item, expected, actual, pass, info = false) => rows.push({ doc, cat, item, expected, actual, pass, info });
+   164	
+   165	async function checkDoc(page, spec) {
+   166	  const { doc, ocr } = spec;
+   167	  await loadDoc(page, doc, ocr);
+   168	  const snap = await page.evaluate(() => window.__entitySnapshot());
+   169	  const autoCount = snap.filter(e => e.kind === 'auto').length;
+   170	  process.stderr.write(`    [autoCount] ${doc} = ${autoCount}\n`);
+   171	  if (spec.min_auto != null) rec(doc, 'REGRESSION', `auto>=${spec.min_auto}`, `>=${spec.min_auto}`, String(autoCount), autoCount >= spec.min_auto);
+   172	  // False-positive regression guard: a hard CEILING on auto-detected entities.
+   173	  // The golden's MUST_MASK checks catch "did we mask what we should"; max_auto
+   174	  // catches the inverse — a detection change that starts auto-masking body text
+   175	  // (the résumé-defect class where 95/95 passed while the body got shredded).
+   176	  if (spec.max_auto != null) rec(doc, 'REGRESSION', `auto<=${spec.max_auto}`, `<=${spec.max_auto}`, String(autoCount), autoCount <= spec.max_auto);
+   177	
+   178	  // Turn a name candidate ON (hide → solid) so must_mask can assert the whole
+   179	  // name — surname included — is geometrically covered once the user activates it.
+   180	  if (spec.activate_name) {
+   181	    const ok = await page.evaluate(v => {
+   182	      const e = entities.find(x => x.value === v && x.type === 'name');
+   183	      if (!e) return false;
+   184	      e.mode = 'no'; renderAll(); return true;
+   185	    }, spec.activate_name);
+   186	    rec(doc, 'NAME_WHOLE', spec.activate_name, 'detected-whole', ok ? 'detected' : 'MISSING/truncated', ok);
+   187	  }
+   188	
+   189	  for (const v of spec.must_mask || []) {
+   190	    const masked = await page.evaluate(x => window.__isMasked(x), v);
+   191	    rec(doc, 'MUST_MASK', v, 'masked', masked ? 'masked' : 'NOT masked', masked);
+   192	  }
+   193	  for (const v of spec.must_not_mask || []) {
+   194	    const masked = await page.evaluate(x => window.__isMasked(x), v);
+   195	    rec(doc, 'MUST_NOT_MASK', v, 'clear', masked ? 'MASKED' : 'clear', !masked);
+   196	  }
+   197	  for (const v of spec.never_candidate || []) {
+   198	    const isCand = await page.evaluate(x => window.__isCandidateExact(x), v);
+   199	    rec(doc, 'NEVER_CANDIDATE', v, 'not-cand', isCand ? 'CANDIDATE' : 'not-cand', !isCand);
+   200	  }
+   201	  for (const v of spec.should_candidate || []) {
+   202	    // A candidate must SURFACE as a review candidate. (Its default redaction level
+   203	    // — name/address candidates now default to 'half' — is asserted separately by
+   204	    // CANDIDATE_MODE; "surfaced" is no longer coupled to "left in the clear".)
+   205	    const isCand = await page.evaluate(x => window.__isCandidateContains(x), v);
+   206	    rec(doc, 'SHOULD_CANDIDATE', v, 'candidate', isCand ? 'candidate' : 'missing', isCand);
+   207	  }
+   208	  // Candidate default-mode policy: name/address candidates default to 'half' so the
+   209	  // "확인 필요" label matches a visibly-partial state. Old code defaulted them to 'ok'.
+   210	  for (const [v, exp] of Object.entries(spec.candidate_mode || {})) {
+   211	    const mode = await page.evaluate(x => window.__candidateMode(x), v);
+   212	    rec(doc, 'CANDIDATE_MODE', v, exp, mode || 'not-candidate', mode === exp);
+   213	  }
+   214	  if (spec.name_bar) {
+   215	    const nb = await page.evaluate(x => window.__nameBar(x), spec.name_bar);
+   216	    if (nb) {
+   217	      const ratioH = nb.drawnH / nb.glyphH;
+   218	      const ok = nb.containsGlyph && ratioH <= 1.5;
+   219	      rec(doc, 'NAME_BAR', spec.name_bar, 'tight&contains', `hRatio=${ratioH.toFixed(2)} contains=${nb.containsGlyph}`, ok);
+   220	    } else rec(doc, 'NAME_BAR', spec.name_bar, 'measurable', 'no-boxes', false);
+   221	  }
+   222	  if (spec.dark_bg_value) {
+   223	    const dk = await page.evaluate(v => { const e = entities.find(x => x.value === v); const bg = e && e.boxes[0] ? e.boxes[0].bg : null; return { bg, dark: bg ? isDarkColor(bg) : null }; }, spec.dark_bg_value);
+   224	    rec(doc, 'DARK_BG', spec.dark_bg_value, 'dark bg detected', `${dk.bg} dark=${dk.dark}`, dk.dark === true, true);
+   225	  }
+   226	  for (const fmt of (spec.out_formats || (spec.type === 'pdf' ? ['pdf'] : []))) {
+   227	    await checkOutput(page, doc, fmt);
+   228	  }
+   229	}
+   230	
+   231	/* ── output safety ──────────────────────────────────────────────────────────
+   232	   What the user ships is the output file, not our preview. Three separate ways
+   233	   a redacted-looking file still carries the original:
+   234	     1. a text layer under the ink (the classic "透ける黒塗り"),
+   235	     2. metadata the renderer never shows — EXIF/XMP/IPTC on images, annotations
+   236	        or embedded files in a PDF,
+   237	     3. an incrementally-saved PDF, where the PREVIOUS revision (unredacted) is
+   238	        still physically present earlier in the same byte stream.
+   239	   Each needs its own probe: pdf.js text extraction catches (1) and is blind to
+   240	   (2) and (3). So we read the produced BYTES. */
+   241	const MARKERS = {
+   242	  // PNG: every ancillary text/EXIF chunk type. Canvas encodes none of these, but
+   243	  // "it currently doesn't" is not a guarantee — assert it.
+   244	  png: [['eXIf', 'EXIF chunk'], ['tEXt', 'tEXt chunk'], ['zTXt', 'zTXt chunk'], ['iTXt', 'iTXt chunk']],
+   245	  // ICC_PROFILE is deliberately NOT forbidden: Chrome's JPEG encoder attaches a
+   246	  // 456-byte generic sRGB profile (tags: desc/rXYZ/gXYZ/bXYZ/wtpt/rTRC/cprt —
+   247	  // measured, no device identifiers). That is a colour space declaration, not
+   248	  // document content and not an identifier. What WOULD be a leak is the
+   249	  // viewer's *display* profile, which carries manufacturer/model tags and is
+   250	  // much larger — iccSafe() below bounds exactly that.
+   251	  jpg: [['Exif\0\0', 'EXIF APP1'], ['http://ns.adobe.com/xap/', 'XMP APP1'], ['Photoshop 3.0\0', 'IPTC APP13']],
+   252	  pdf: [['/Annots', 'annotation'], ['/EmbeddedFile', 'embedded file'], ['/XFA', 'XFA form'], ['/AcroForm', 'form fields'], ['/Names', 'name tree']],
+   253	};
+   254	function scanMarkers(buf, kind) {
+   255	  const hay = buf.toString('latin1');
+   256	  return MARKERS[kind].filter(([m]) => hay.includes(m)).map(([, label]) => label);
+   257	}
+   258	// An embedded ICC profile is acceptable only while it stays a generic colour
+   259	// space. A display profile (which identifies the machine that produced the file)
+   260	// is large and carries the device manufacturer / model description tags.
+   260	// is large and carries the device manufacturer / model description tags.
+   261	const ICC_MAX = 2048;
+   262	function iccSafe(buf) {
+   263	  const hay = buf.toString('latin1');
+   264	  const at = hay.indexOf('ICC_PROFILE\0');
+   265	  if (at < 0) return { ok: true, note: 'absent' };
+   266	  const size = buf.readUInt32BE(at + 14);          // profile header: byte 0..3 = size
+   267	  const body = hay.slice(at + 14, at + 14 + Math.min(size, 65535));
+   268	  const dev = ['dmnd', 'dmdd'].filter(t => body.includes(t));
+   269	  const ok = size <= ICC_MAX && dev.length === 0;
+   270	  return { ok, note: `${size}B${dev.length ? ' +' + dev.join('/') : ''}` };
+   271	}
+   272	async function checkOutput(page, doc, fmt) {
+   273	  const tag = `OUT_${fmt.toUpperCase()}`;
+   274	  try {
+   275	    await page.evaluate(f => { const r = document.querySelector(`input[name=fmt][value="${f}"]`); if (r) r.checked = true; }, fmt);
+   276	    // force at least one masked, located entity so Make is enabled
+   277	    await page.evaluate(() => { const e = entities.find(x => isOn(x) && x.boxes && x.boxes.length); if (e) e.mode = 'no'; renderAll(); });
+   278	    await page.click('#btnMake');
+   279	    await page.waitForSelector('#result', { state: 'visible', timeout: 60000 });
+   280	    const dl = await Promise.all([
+   281	      page.waitForEvent('download', { timeout: 30000 }),
+   282	      page.click('#btnDownload'),
+   283	    ]).then(a => a[0]).catch(() => null);
+   284	    if (!dl) { rec(doc, tag, `output ${fmt}`, 'clean', 'no-download', false); return; }
+   285	    const fp = path.join(OUT, doc.replace(/[\/\\]/g, '_').replace(/\.\w+$/, `_out.${fmt}`));
+   286	    await dl.saveAs(fp);
+   287	    const buf = fs.readFileSync(fp);
+   288	
+   289	    if (fmt === 'pdf') {
+   290	      const chars = await page.evaluate(async (b64) => {
+   291	        const bin = atob(b64); const arr = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
+   292	        const pdf = await pdfjsLib.getDocument({ data: arr }).promise;
+   293	        let n = 0;
+   294	        for (let p = 1; p <= pdf.numPages; p++) { const tc = await (await pdf.getPage(p)).getTextContent(); n += tc.items.reduce((s, it) => s + (it.str || '').replace(/\s/g, '').length, 0); }
+   295	        return n;
+   296	      }, buf.toString('base64'));
+   297	      rec(doc, 'TEXT_LEAK', `output ${fmt}`, '0 chars', `${chars} chars`, chars === 0);
+   298	      // One %%EOF means one revision. An incremental save appends a second body
+   299	      // + xref + %%EOF, leaving revision 1 (pre-redaction) readable in the file.
+   300	      const eofs = (buf.toString('latin1').match(/%%EOF/g) || []).length;
+   301	      rec(doc, tag, `output ${fmt} revisions`, '1 %%EOF', `${eofs} %%EOF`, eofs === 1);
+   302	    }
+   303	    const hits = scanMarkers(buf, fmt);
+   304	    rec(doc, tag, `output ${fmt} metadata`, 'none', hits.length ? hits.join('+') : 'none', hits.length === 0);
+   305	    if (fmt === 'jpg') { const icc = iccSafe(buf); rec(doc, tag, `output ${fmt} ICC`, `generic <=${ICC_MAX}B`, icc.note, icc.ok); }
+   306	  } catch (e) { rec(doc, tag, `output ${fmt}`, 'clean', 'ERR:' + e.message.split('\n')[0], false); }
+   307	}
+   308	
+   309	async function checkAiInject(page) {
+   310	  const inj = SPECS.ai_inject; if (!inj) return;
+   311	  await loadDoc(page, inj._doc, false);
+   312	  for (const c of inj.cases) {
+   313	    // fresh reload so each case is isolated
+   314	    await loadDoc(page, inj._doc, false);
+   315	    const res = await page.evaluate((ent) => {
+   316	      const before = entities.length;
+   317	      addEntities([ent]);
+   318	      const added = entities.slice(before);
+   319	      const mine = added.find(e => e.value === ent.value) || entities.find(e => e.value === ent.value && e.kind !== 'candidate' && e.type !== 'name-candidate');
+   320	      const masked = window.__isMasked(ent.value);
+   321	      return { present: !!mine, type: mine ? mine.type : null, mode: mine ? mine.mode : null, masked };
+   322	    }, c.entity);
+   323	    let pass, actual;
+   324	    if (c.expect === 'masked') { pass = res.masked; actual = res.masked ? 'masked' : `not-masked(${res.type}/${res.mode})`; }
+   325	    else if (c.expect === 'dropped') { pass = !res.present && !res.masked; actual = res.present ? `KEPT(${res.type}/${res.mode})` : 'dropped'; }
+   326	    else { pass = !res.masked; actual = res.masked ? 'MASKED' : `visible(${res.type || 'dropped'}/${res.mode || '-'})`; }
+   327	    rec('7_resume_dark.pdf', 'AI_INJECT', c.label + ` [${c.entity.type}:${c.entity.value}]`, c.expect, actual, pass);
+   328	  }
+   329	}
+   330	
+   331	async function checkAiCatState(page) {
+   332	  const cs = SPECS.ai_cat_state; if (!cs) return;
+   333	  await loadDoc(page, cs._doc, false);
+   334	  const res = await page.evaluate(({ labels, want }) => {
+   335	    // record active state BEFORE the AI merge, then inject AI labels
+   336	    const before = {}; for (const t of want) before[t] = catEnabled[t] !== false;
+   337	    addEntities(labels); renderAll();
+   338	    const after = {}, boxChecked = {};
+   339	    for (const t of want) {
+   340	      after[t] = catEnabled[t] !== false;
+   341	      const cb = document.querySelector(`#piiList input[data-cat="${t}"]`);
+   342	      boxChecked[t] = cb ? cb.checked : null; // null = row not rendered (still a fail signal)
+   343	    }
+   344	    return { before, after, boxChecked };
+   345	  }, { labels: cs.labels, want: cs.assert_enabled });
+   346	  for (const t of cs.assert_enabled) {
+   347	    const pass = res.after[t] === true && res.boxChecked[t] === true;
+   348	    rec(cs._doc, 'AI_CAT_STATE', `${t} stays enabled`, 'on+checked',
+   349	      `enabled=${res.after[t]} checked=${res.boxChecked[t]}`, pass);
+   350	  }
+   351	}
+   352	
+   353	async function checkCandidateDedup(page) {
+   354	  const cd = SPECS.candidate_dedup; if (!cd) return;
+   355	  for (const c of cd.cases) {
+   356	    await loadDoc(page, cd._doc, false);   // fresh load so the base candidate is present
+   357	    const res = await page.evaluate(({ cand, confirm }) => {
+   358	      const before = window.__isCandidateContains(cand);
+   359	      addEntities([confirm]); renderAll();
+   360	      const after = window.__isCandidateContains(cand);
+   361	      // Dedup must be directional: it removes redundant CANDIDATES, never the
+   362	      // CONFIRMED entity that contains them. A reversed containment test (or a
+   363	      // mutual-removal bug) would delete the confirmed name — leaving the value
+   364	      // wholly UNMASKED. Assert the confirmed entity is still present after dedup.
+   365	      // (Location isn't asserted here: these cases inject a superset value with a
+   366	      // token absent from the fixture, so it is intentionally unlocated.)
+   367	      const nc = window.__norm(confirm.value);
+   368	      const confEnt = window.__entitySnapshot().find(e => e.kind !== 'candidate' && window.__norm(e.value) === nc);
+   369	      return { before, after, confirmedSurvives: !!confEnt };
+   370	    }, { cand: c.candidate, confirm: c.confirm });
+   371	    let pass, actual;
+   372	    if (c.expect === 'removed') {
+   373	      pass = res.before && !res.after;
+   374	      actual = !res.before ? 'not-present-before' : (res.after ? 'STILL present' : 'removed');
+   375	    } else { // kept
+   376	      pass = res.before && res.after;
+   377	      actual = !res.before ? 'not-present-before' : (res.after ? 'kept' : 'DROPPED');
+   378	    }
+   379	    rec(cd._doc, 'CANDIDATE_DEDUP', `${c.label} [${c.confirm.value}]`, c.expect, actual, pass);
+   380	    // Confirmed-preservation guard (the regression the candidate-only test missed):
+   381	    // the confirmed entity that triggered the dedup must SURVIVE it.
+   382	    rec(cd._doc, 'CONFIRMED_SURVIVES', `confirmed kept [${c.confirm.value}]`, 'survives',
+   383	      res.confirmedSurvives ? 'survives' : 'REMOVED', res.confirmedSurvives);
+   384	  }
+   385	}
+   386	
+   387	/* ── JP golden ───────────────────────────────────────────────────────────────
+   388	   Each JP fixture ships its own specs.json with a BOX TABLE in PNG pixel
+   389	   coordinates plus, per 提出目的, which boxes must be hidden / recommended /
+   390	   optional / kept. The harness replays that table against the live pipeline.
+   391	
+   392	   Coordinate frames: a PNG loads at its natural size, a PDF renders at
+   393	   min(2.2, 1500/ptWidth) — so the mapping is a single uniform scale, taken at
+   394	   runtime from page.w / fixtureWidth rather than hard-coded. A JPG fixture is
+   395	   deliberately rotated and blurred (a phone photo), so its OCR boxes do NOT
+   396	   land on the PNG coordinates; those cases assert at FIELD level instead and
+   397	   say so, rather than quietly comparing coordinates that cannot match.
+   398	
+   399	   Which assertion a box gets comes from the LEGAL MATRIX level, not from which
+   400	   list the fixture put it in — `mask` holds everything the purpose hides, at
+   401	   both the automatic and the recommended strength, and those are different
+   402	   promises. specs.json carries the key→level mapping (jp_auto_fields) so the
+   403	   harness derives it independently of the app it is testing. */
+   404	const JP_COVER_MIN = 0.6;      // a band must cover this much of a value/box
+   405	const JP_KEEP_MAX = 0.10;      // a keep field may not be grazed by more than this
+   406	function jpFieldOf(key) { return key.replace(/^m\d+_/, ''); }
+   407	async function jpCheckBox(page, doc, cat, key, rect, kind) {
+   408	  const items = await page.evaluate(r => window.__itemsIn(r), rect);
+   409	  let frac, what;
+   410	  if (items.length) {
+   411	    // The meaningful question for a box holding text is whether the TEXT is
+   412	    // covered — not whether the generator's padding around it was painted.
+   413	    const fr = await Promise.all(items.map(it => page.evaluate(r => window.__coverage(r), it)));
+   414	    frac = Math.min(...fr); what = `${items.length} item(s) min ${(frac * 100).toFixed(0)}%`;
+   415	  } else {
+   416	    frac = await page.evaluate(r => window.__coverage(r), rect); what = `area ${(frac * 100).toFixed(0)}%`;
+   417	  }
+   418	  if (kind === 'keep') { rec(doc, 'JP_KEEP', key, `<=${JP_KEEP_MAX * 100}%`, what, frac <= JP_KEEP_MAX); return; }
+   419	  const covered = frac >= JP_COVER_MIN;
+   420	  if (kind === 'mask') { rec(doc, 'JP_MASK', key, `>=${JP_COVER_MIN * 100}%`, what, covered); return; }
+   421	  const cand = await page.evaluate(r => window.__candidateOver(r), rect);
+   422	  if (kind === 'candidate') { rec(doc, 'JP_CANDIDATE', key, 'surfaced', cand ? (covered ? 'candidate+banded' : 'candidate') : 'MISSING', cand); return; }
+   423	  if (kind === 'mask_or_candidate') {
+   424	    rec(doc, 'JP_MASK_OR_CAND', key, 'banded or candidate', covered ? 'banded' : cand ? 'candidate' : 'NEITHER', covered || cand); return;
+   425	  }
+   426	  if (kind === 'optional') {   // detected, offered, and OFF until the user says so
+   427	    rec(doc, 'JP_OPTIONAL', key, 'offered+clear', cand ? (frac <= JP_KEEP_MAX ? 'offered+clear' : 'OFFERED BUT BANDED') : 'MISSING', cand && frac <= JP_KEEP_MAX);
+   428	  }
+   429	}
+   430	async function checkJpDoc(page, spec) {
+   431	  const fx = JSON.parse(fs.readFileSync(path.join(__dirname, spec.fixture), 'utf8'));
+   432	  const autoFields = (SPECS.jp_auto_fields || {})[spec.expect_doc] || [];
+   433	  const mocFields = SPECS.jp_candidate_or_mask || [];
+   434	  for (const c of spec.cases) {
+   435	    const tag = `${spec.doc} [${c.purpose}]`;
+   436	    await loadDoc(page, spec.doc, true);
+   437	    await page.evaluate(p => jpSetPurpose(p), c.purpose);
+   438	    const st = await page.evaluate(() => window.__jpState());
+   439	    rec(tag, 'JP_CLASS', spec.expect_doc + (spec.expect_side ? '/' + spec.expect_side : ''), 'classified',
+   440	      st.cls ? st.cls.doc + (st.cls.side ? '/' + st.cls.side : '') + ' sc=' + st.cls.score : 'NOT classified',
+   441	      !!st.cls && st.cls.doc === spec.expect_doc && (!spec.expect_side || st.cls.side === spec.expect_side));
+   442	    if (!st.cls) continue;
+   443	    const autoCount = await page.evaluate(() => entities.filter(e => e.kind === 'auto').length);
+   444	    process.stderr.write(`    [jp autoCount] ${tag} = ${autoCount}\n`);
+   445	    if (c.min_auto != null) rec(tag, 'REGRESSION', `auto>=${c.min_auto}`, `>=${c.min_auto}`, String(autoCount), autoCount >= c.min_auto);
+   446	    if (c.max_auto != null) rec(tag, 'REGRESSION', `auto<=${c.max_auto}`, `<=${c.max_auto}`, String(autoCount), autoCount <= c.max_auto);
+   447	
+   448	    // Field-level: every required field must have been FOUND. This is the only
+   449	    // assertion a rotated phone-photo fixture can make, and it is also the one
+   450	    // the 미탐 0 gate is actually about.
+   451	    const got = new Set(st.fields.map(f => f.field));
+   452	    for (const f of (c.require_fields || [])) rec(tag, 'JP_FIELD', f, 'detected', got.has(f) ? 'detected' : 'MISSING', got.has(f));
+   453	    for (const f of (c.require_banded || [])) {
+   454	      const on = st.fields.some(x => x.field === f && x.mode !== 'ok');
+   455	      rec(tag, 'JP_BANDED', f, 'banded', on ? 'banded' : (got.has(f) ? 'DETECTED BUT CLEAR' : 'MISSING'), on);
+   456	    }
+   457	    // The inverse of require_banded, and the half that makes a purpose-gate test
+   458	    // mean something: without it, "banded under 相談用共有" could be true simply
+   459	    // because the field is banded under every purpose.
+   460	    for (const f of (c.require_clear || [])) {
+   461	      const hits = st.fields.filter(x => x.field === f);
+   462	      const clear = hits.length > 0 && hits.every(x => x.mode === 'ok');
+   463	      rec(tag, 'JP_CLEAR', f, 'detected+clear', hits.length ? (clear ? 'detected+clear' : 'BANDED') : 'MISSING', clear);
+   464	    }
+   465	    if (spec.geometry === false || c.geometry === false) continue;
+   466	
+   467	    const P = fx.purposes[c.key];
+   468	    if (!P) { rec(tag, 'JP_SPEC', c.key, 'purpose in fixture', 'MISSING', false); continue; }
+   469	    const scale = st.pw[0] / fx.size[0];
+   470	    let checked = 0;
+   471	    const box = k => { const b = fx.boxes_png[k]; return b && { pi: 0, x: b[0] * scale, y: b[1] * scale, w: (b[2] - b[0]) * scale, h: (b[3] - b[1]) * scale }; };
+   472	    const seen = new Set(); const skipped = [];
+   473	    const run = async (keys, kindFor) => {
+   474	      for (const k of (keys || [])) {
+   475	        if (k === 'ALL' || seen.has(k)) continue;
+   476	        const r = box(k);
+   477	        // The fixture's purpose list is shared across variants of the same
+   478	        // document, so a key absent from THIS variant is not a case — but it is
+   479	        // REPORTED, never silently dropped. A harness that quietly checks zero
+   480	        // boxes prints the same green as one that checked forty.
+   481	        if (!r) { skipped.push(k); continue; }
+   482	        seen.add(k);
+   483	        await jpCheckBox(page, tag, null, k, r, kindFor(k));
+   484	        checked++;
+   485	      }
+   486	    };
+   487	    // whole-face rule (マイナカード裏面 under a 本人確認 purpose)
+   488	    if ((P.mask || []).includes('ALL')) {
+   489	      const pg = await page.evaluate(() => ({ pi: 0, x: 0, y: 0, w: pages[0].w, h: pages[0].h }));
+   490	      await jpCheckBox(page, tag, null, 'ALL(face)', pg, 'mask');
+   491	      checked++;
+   492	      for (const k of Object.keys(fx.boxes_png)) { const r = box(k); if (r) { await jpCheckBox(page, tag, null, k, r, 'mask'); checked++; } }
+   493	      seen.add('ALL');
+   494	    }
+   495	    await run(P.mask, k => mocFields.includes(jpFieldOf(k)) ? 'mask_or_candidate'
+   496	                        : autoFields.includes(jpFieldOf(k)) ? 'mask' : 'candidate');
+   497	    await run(P.recommend, () => 'candidate');
+   498	    await run(P.optional, () => 'optional');
+   499	    await run(P.keep === 'all' ? [] : P.keep, () => 'keep');
+   500	    rec(tag, 'JP_COVERAGE', `boxes checked (skipped: ${skipped.join(',') || 'none'})`, '>0', String(checked), checked > 0);
+   501	    for (const fmt of (c.out_formats || [])) await checkOutput(page, tag, fmt);
+   502	  }
+   503	}
+   504	
+   505	/* ── JP unit rules ──────────────────────────────────────────────────────────
+   506	   Two detection rules cannot be exercised by the alpha fixtures: none of the
+   507	   four documents carries a phone number, and on all four the 住所 is a KEEP
+   508	   field, so the address hierarchy's own scoring never decides anything there.
+   509	   Shipping them with no coverage at all would be shipping untested detection,
+   510	   so they are pinned at unit level against crafted strings — stated as such
+   511	   rather than left to look like fixture coverage. */
+   512	async function checkJpUnits(page) {
+   513	  const U = SPECS.jp_units; if (!U) return;
+   514	  for (const c of (U.address || [])) {
+   515	    const got = await page.evaluate(t => {
+   516	      const sp = jpAddressSpan(t, 0);
+   517	      return sp ? { span: t.slice(sp.a, sp.b), score: sp.score, strong: !!(sp.postal && sp.pref) } : null;
+   518	    }, c.text);
+   519	    const ok = c.expect === null ? (got === null || got.score < 3)
+   520	      : !!got && got.span === c.expect.span && got.score === c.expect.score && got.strong === !!c.expect.strong;
+   521	    rec('(jp units)', 'JP_ADDRESS', c.label, c.expect === null ? 'no address' : `${c.expect.span} s=${c.expect.score}${c.expect.strong ? ' strong' : ''}`,
+   522	      got ? `${got.span} s=${got.score}${got.strong ? ' strong' : ''}` : 'none', ok);
+   523	  }
+   524	  for (const c of (U.tel || [])) {
+   525	    const got = await page.evaluate(t => {
+   526	      const hy = JP_TEL_HYPHEN_RE.exec(t), pl = hy ? null : JP_TEL_PLAIN_RE.exec(t);
+   527	      const m = hy || pl; return m ? { v: m[0], loose: !hy } : null;
+   528	    }, c.text);
+   529	    const ok = c.expect === null ? got === null
+   530	      : !!got && got.v === c.expect.v && got.loose === !!c.expect.loose;
+   531	    rec('(jp units)', 'JP_TEL', c.label, c.expect === null ? 'no match' : `${c.expect.v}${c.expect.loose ? ' (candidate)' : ''}`,
+   532	      got ? `${got.v}${got.loose ? ' (candidate)' : ''}` : 'none', ok);
+   533	  }
+   534	}
+   535	
+   536	function printTable() {
+   537	  const pad = (s, n) => { s = String(s); return s.length > n ? s.slice(0, n - 1) + '…' : s.padEnd(n); };
+   538	  let lastDoc = '';
+   539	  console.log('\n' + '═'.repeat(120));
+   540	  console.log(pad('DOC', 20) + pad('CATEGORY', 17) + pad('ITEM', 40) + pad('EXPECTED', 18) + pad('ACTUAL', 18) + 'RESULT');
+   541	  console.log('─'.repeat(120));
+   542	  for (const r of rows) {
+   543	    if (r.doc !== lastDoc) { console.log('─'.repeat(120)); lastDoc = r.doc; }
+   544	    const mark = r.info ? (r.pass ? 'ℹ ok' : 'ℹ note') : (r.pass ? '✅ PASS' : '❌ FAIL');
+   545	    console.log(pad(r.doc, 20) + pad(r.cat, 17) + pad(r.item, 40) + pad(r.expected, 18) + pad(r.actual, 18) + mark);
+   546	  }
+   547	  console.log('═'.repeat(120));
+   548	  const gating = rows.filter(r => !r.info);
+   549	  const fails = gating.filter(r => !r.pass);
+   550	  const byCat = {};
+   551	  for (const r of gating) { byCat[r.cat] = byCat[r.cat] || { p: 0, f: 0 }; r.pass ? byCat[r.cat].p++ : byCat[r.cat].f++; }
+   552	  console.log('\nSummary by category:');
+   553	  for (const [c, v] of Object.entries(byCat)) console.log(`  ${pad(c, 18)} ${v.p} pass / ${v.f} fail`);
+   554	  console.log(`\n  TOTAL: ${gating.length - fails.length}/${gating.length} pass, ${fails.length} FAIL`);
+   555	  if (fails.length) {
+   556	    console.log('\n  Failing:');
+   557	    for (const r of fails) console.log(`    ✗ [${r.doc}] ${r.cat} — ${r.item}  (expected ${r.expected}, got ${r.actual})`);
+   558	  }
+   559	  return fails.length;
+   560	}
+   560	}
+   561	
+   562	(async () => {
+   563	  const srv = await startServer();
+   564	  const port = srv.address().port;
+   565	  const URL = `http://127.0.0.1:${port}/safe/index.html`;
+   566	  const browser = await chromium.launch({ channel: 'chrome', headless: true });
+   567	  const ctx = await browser.newContext({ acceptDownloads: true, locale: 'ko-KR', viewport: { width: 1200, height: 900 } });
+   568	  const page = await ctx.newPage();
+   569	  const consoleErrors = [];
+   570	  page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
+   571	  page.on('pageerror', e => consoleErrors.push('PageError: ' + e.message));
+   572	  await page.goto(URL, { waitUntil: 'networkidle' });
+   573	  await page.evaluate(() => { LANG = 'ko'; applyLang(); });
+   574	
+   575	  const docs = SPECS.docs.filter(d => !onlyArg || d.doc === onlyArg);
+   576	  for (const spec of docs) {
+   577	    process.stderr.write(`… ${spec.doc}\n`);
+   578	    try { await checkDoc(page, spec); }
+   579	    catch (e) { rec(spec.doc, 'LOAD', spec.doc, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
+   580	  }
+   581	  for (const spec of (SPECS.jp_docs || [])) {
+   582	    if (onlyArg && spec.doc !== onlyArg) continue;
+   583	    process.stderr.write(`… ${spec.doc}\n`);
+   584	    // The JP presets only exist in the Japanese UI, and OCR language follows it.
+   585	    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
+   586	    try { await checkJpDoc(page, spec); }
+   587	    catch (e) { rec(spec.doc, 'LOAD', spec.doc, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
+   588	    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
+   589	  }
+   590	  if (!onlyArg || onlyArg === '(jp units)') { process.stderr.write('… jp units\n'); await checkJpUnits(page); }
+   591	  if (!onlyArg || onlyArg === '7_resume_dark.pdf') { process.stderr.write('… ai_inject\n'); await checkAiInject(page); }
+   592	  if (!onlyArg || onlyArg === '7_resume_dark.pdf') { process.stderr.write('… ai_cat_state\n'); await checkAiCatState(page); }
+   593	  if (!onlyArg || onlyArg === (SPECS.candidate_dedup && SPECS.candidate_dedup._doc)) { process.stderr.write('… candidate_dedup\n'); await checkCandidateDedup(page); }
+   594	
+   595	  const failCount = printTable();
+   596	  if (consoleErrors.length) { console.log('\n  ⚠ console errors:'); consoleErrors.slice(0, 10).forEach(e => console.log('    ' + e)); }
+   597	  fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify({ rows, consoleErrors }, null, 2));
+   598	
+   599	  await browser.close(); srv.close();
+   600	  process.exit(failCount ? 1 : 0);
+   601	})().catch(e => { console.error(e); process.exit(2); });
+
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+exec
+/bin/zsh -lc "git show 546344b:public/safe/index.html | nl -ba | sed -n '2200,2278p'; git show 546344b:public/safe/index.html | nl -ba | sed -n '2310,2385p'; git show 546344b:public/safe/index.html | nl -ba | sed -n '2385,2480p'; git show 546344b:public/safe/index.html | nl -ba | sed -n '2480,2610p'" in /Users/sunghoon/Projects/docpack
+ succeeded in 0ms:
+  2200	    // a guess must not silently delete content from a document the user is about
+  2201	    // to submit. A caller that knows better (the JP purpose presets, where the
+  2202	    // legal matrix says 既定ON) passes an explicit mode and overrides this.
+  2203	    const mode = e.mode || (kind==='candidate' ? 'ok' : catDefault[type]);
+  2204	    entities.push({id:'e'+Math.random().toString(36).slice(2,8),type,value:v,mode,kind,reason,boxes});
+  2205	  }
+  2206	  entities.sort((a,b)=>Object.keys(TYPES).indexOf(a.type)-Object.keys(TYPES).indexOf(b.type));
+  2207	  dedupeCandidates();
+  2208	}
+  2209	// Remove review candidates wholly contained (as whole space-separated tokens) in a
+  2210	// CONFIRMED entity's value — e.g. confirmed "MANSI GAZAL TIWARI" makes the candidate
+  2211	// "MANSI GAZAL" redundant (the confirmed mask already covers it). Only the shorter,
+  2212	// fully-contained candidate is dropped; a candidate that adds tokens is kept. Runs
+  2213	// after every addEntities batch so a later AI-confirmed name also clears an earlier
+  2214	// candidate.
+  2215	function dedupeCandidates(){
+  2216	  const norm=s=>(s||'').toLowerCase().replace(/\s+/g,' ').trim();
+  2217	  const confirmed=entities.filter(e=>e.kind!=='candidate').map(e=>norm(e.value)).filter(Boolean);
+  2218	  if(!confirmed.length) return;
+  2219	  entities=entities.filter(e=>{
+  2220	    if(e.kind!=='candidate') return true;
+  2221	    const cv=norm(e.value); if(!cv) return true;
+  2222	    return !confirmed.some(fv=>fv!==cv && (' '+fv+' ').includes(' '+cv+' '));
+  2223	  });
+  2224	}
+  2225	const located=e=>e.boxes&&e.boxes.length>0;
+  2226	
+  2227	function renderAll(){ renderList(); drawPreview(); updateMake(); }
+  2228	function updateMake(){ $('btnMake').disabled = !pages.length || !( entities.some(e=>isOn(e)&&e.mode!=='ok'&&located(e)) || wmEnabled() ); }
+  2229	function escapeHtml(s){return s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
+  2230	
+  2231	/* ───────── preview (rendered page + live redaction overlay) ───────── */
+  2232	function buildPreview(){
+  2233	  const host=$('preview'); host.innerHTML=''; previewCanvases=[];
+  2234	  if(!pages.length) return;
+  2235	  const dispW=Math.min(host.clientWidth-24||600, 660);
+  2236	  pages.forEach((page,pi)=>{
+  2237	    const scale=dispW/page.w;
+  2238	    const cv=canvasEl(dispW, page.h*scale); cv.className='pg';
+  2239	    cv.dataset.pi=pi; cv.dataset.scale=scale;
+  2240	    host.appendChild(cv); previewCanvases.push(cv);
+  2241	    attachSelect(cv);
+  2242	  });
+  2243	  drawPreview();
+  2244	}
+  2245	function drawPreview(){
+  2246	  previewCanvases.forEach(cv=>{
+  2247	    const pi=+cv.dataset.pi, scale=+cv.dataset.scale, page=pages[pi];
+  2248	    if(!page) return;
+  2249	    const ctx=cv.getContext('2d');
+  2250	    ctx.clearRect(0,0,cv.width,cv.height);
+  2251	    ctx.drawImage(page.canvas,0,0,cv.width,cv.height);
+  2252	    drawRedactions(ctx,pi,scale);
+  2253	    if(wmEnabled()) drawWatermark(ctx,cv.width,cv.height,wmText());
+  2254	  });
+  2255	}
+  2256	// Merge an entity's boxes that sit on the same visual line into one rect, so a
+  2257	// wrapped address (multiple boxes) is covered cleanly and the partial value is
+  2258	// drawn once — not duplicated per box.
+  2259	function mergeLineBoxes(boxes,pi){
+  2260	  const arr=boxes.filter(b=>b.page===pi).slice().sort((a,b)=>a.y-b.y||a.x-b.x);
+  2261	  const used=new Array(arr.length).fill(false), lines=[];
+  2262	  for(let i=0;i<arr.length;i++){
+  2263	    if(used[i])continue;
+  2264	    let x0=arr[i].x,y0=arr[i].y,x1=arr[i].x+arr[i].w,y1=arr[i].y+arr[i].h,bg=arr[i].bg,region=arr[i].region;
+  2265	    used[i]=true;
+  2266	    for(let j=i+1;j<arr.length;j++){
+  2267	      if(used[j])continue; const b=arr[j];
+  2268	      const oy0=Math.max(y0,b.y), oy1=Math.min(y1,b.y+b.h);
+  2269	      const ov=(oy1-oy0)/Math.max(1,Math.min(y1-y0,b.h));
+  2270	      if(ov>0.5){ x0=Math.min(x0,b.x);y0=Math.min(y0,b.y);x1=Math.max(x1,b.x+b.w);y1=Math.max(y1,b.y+b.h);used[j]=true;region=region||b.region; }
+  2271	    }
+  2272	    lines.push({x:x0,y:y0,w:x1-x0,h:y1-y0,bg,region});
+  2273	  }
+  2274	  return lines.sort((a,b)=>a.y-b.y||a.x-b.x);
+  2275	}
+  2276	// The band drawn for a merged line box: the text/OCR box grown by a margin of
+  2277	// 15% of the box height (floor 2px) on every side. The margin exists because the
+  2278	// box is an ESTIMATE — pdf.js item boxes exclude side bearings and overshoot,
+  2310	function isDarkColor(bg){
+  2311	  const m=/rgb\((\d+),\s*(\d+),\s*(\d+)\)/.exec(bg||''); if(!m) return false;
+  2312	  return (0.299*+m[1]+0.587*+m[2]+0.114*+m[3]) < 130;
+  2313	}
+  2314	// Band-only redaction: every active entity becomes one opaque rect per visual
+  2315	// line, grown by bandRect(). There is no ordering or overlap subtlety left to
+  2316	// get wrong — two entities landing on the same coordinates simply paint the same
+  2317	// opaque colour twice. (The previous partial-mask path needed an escalation pass
+  2318	// to stop two asterisk strings from ghosting over each other and leaving an
+  2319	// uncovered tail; removing the mode removed that whole failure class.)
+  2320	function drawRedactions(ctx,pi,scale){
+  2321	  const S=v=>v*scale;
+  2322	  const col=bandColor();
+  2323	  for(const e of entities){
+  2324	    if(!isOn(e)||e.mode==='ok') continue;
+  2325	    const lines=mergeLineBoxes(e.boxes,pi);
+  2326	    if(!lines.length) continue;
+  2327	    ctx.fillStyle=col;
+  2328	    for(const l of lines){ const r=bandRect(l); ctx.fillRect(S(r.x),S(r.y),S(r.w),S(r.h)); }
+  2329	  }
+  2330	}
+  2331	function drawWatermark(ctx,W,H,text){
+  2332	  if(!text) return;
+  2333	  ctx.save();
+  2334	  // keep bottom margin clear (QR/stamp/signature area) + small top margin
+  2335	  ctx.beginPath(); ctx.rect(0, H*0.05, W, H*0.81); ctx.clip();
+  2336	  ctx.globalAlpha=0.10; ctx.fillStyle=INK;
+  2337	  const fs=Math.max(16, W*0.028);
+  2338	  ctx.font='700 '+fs+'px "IBM Plex Sans KR",sans-serif';
+  2339	  ctx.textAlign='center'; ctx.textBaseline='middle';
+  2340	  ctx.translate(W/2,H/2); ctx.rotate(-Math.PI/6);
+  2341	  const tw=ctx.measureText(text).width;
+  2342	  const stepX=tw+fs*3.5, stepY=fs*4.2, diag=Math.hypot(W,H);
+  2343	  for(let yy=-diag; yy<diag; yy+=stepY) for(let xx=-diag; xx<diag; xx+=stepX) ctx.fillText(text,xx,yy);
+  2344	  ctx.restore();
+  2345	}
+  2346	
+  2347	/* ───────── manual region selection (drag to redact photo/signature/name) ───────── */
+  2348	let selectMode=false, sel=null;
+  2349	function setSelectMode(on){
+  2350	  selectMode=on;
+  2351	  const btn=$('btnSelect'); if(btn){ btn.classList.toggle('on',on); btn.textContent=on? T().btnSelectOn : T().btnSelect; }
+  2352	  $('preview').classList.toggle('selmode',on);
+  2353	  const hint=$('selHint'); if(hint) hint.style.display=on?'block':'none';
+  2354	}
+  2355	function attachSelect(cv){
+  2356	  const toCanvas=e=>{ const r=cv.getBoundingClientRect(); return { x:(e.clientX-r.left)*(cv.width/r.width), y:(e.clientY-r.top)*(cv.height/r.height) }; };
+  2357	  cv.addEventListener('pointerdown',e=>{
+  2358	    if(!selectMode) return; e.preventDefault();
+  2359	    try{cv.setPointerCapture(e.pointerId);}catch(_){}
+  2360	    const p=toCanvas(e); sel={cv,x0:p.x,y0:p.y,x1:p.x,y1:p.y};
+  2361	  });
+  2362	  cv.addEventListener('pointermove',e=>{
+  2363	    if(!selectMode||!sel||sel.cv!==cv) return; e.preventDefault();
+  2364	    const p=toCanvas(e); sel.x1=p.x; sel.y1=p.y; drawSelOverlay();
+  2365	  });
+  2366	  const finish=e=>{ if(!selectMode||!sel||sel.cv!==cv) return; e.preventDefault(); finalizeSel(); };
+  2367	  cv.addEventListener('pointerup',finish);
+  2368	  cv.addEventListener('pointercancel',()=>{ sel=null; drawPreview(); });
+  2369	}
+  2370	function drawSelOverlay(){
+  2371	  if(!sel) return;
+  2372	  const cv=sel.cv, ctx=cv.getContext('2d'), pi=+cv.dataset.pi, scale=+cv.dataset.scale, page=pages[pi];
+  2373	  ctx.clearRect(0,0,cv.width,cv.height);
+  2374	  ctx.drawImage(page.canvas,0,0,cv.width,cv.height);
+  2375	  drawRedactions(ctx,pi,scale);
+  2376	  if(wmEnabled()) drawWatermark(ctx,cv.width,cv.height,wmText());
+  2377	  const x=Math.min(sel.x0,sel.x1), y=Math.min(sel.y0,sel.y1), w=Math.abs(sel.x1-sel.x0), h=Math.abs(sel.y1-sel.y0);
+  2378	  ctx.save();
+  2379	  ctx.fillStyle='rgba(23,20,15,0.30)'; ctx.fillRect(x,y,w,h);
+  2380	  ctx.strokeStyle=INK; ctx.lineWidth=2; ctx.setLineDash([6,4]); ctx.strokeRect(x,y,w,h);
+  2381	  ctx.restore();
+  2382	}
+  2383	function finalizeSel(){
+  2384	  const s=sel; sel=null;
+  2385	  if(!s){ return; }
+  2385	  if(!s){ return; }
+  2386	  const pi=+s.cv.dataset.pi, scale=+s.cv.dataset.scale, page=pages[pi];
+  2387	  const dx=Math.min(s.x0,s.x1), dy=Math.min(s.y0,s.y1), dw=Math.abs(s.x1-s.x0), dh=Math.abs(s.y1-s.y0);
+  2388	  if(dw<8||dh<8){ drawPreview(); toast(T().tSelSmall); return; }
+  2389	  // region:true — the drag rectangle IS the intent; bandRect must not grow it.
+  2390	  const box={page:pi, x:dx/scale, y:dy/scale, w:dw/scale, h:dh/scale, region:true}; // display px → page px
+  2391	  box.bg=sampleBg(page,box);
+  2392	  entities.push({id:'e'+Math.random().toString(36).slice(2,8),type:'manual',value:'('+T().manualItem+')',mode:'no',kind:'manual',boxes:[box]});
+  2393	  renderAll();
+  2394	  toast(T().tManualAdded);
+  2395	}
+  2396	$('btnSelect').addEventListener('click',()=>setSelectMode(!selectMode));
+  2397	$('jpPurpose').addEventListener('change',e=>jpSetPurpose(e.target.value));
+  2398	
+  2399	/* ───────── detection list (live value next to toggle) ───────── */
+  2400	function catRowHtml(type,items){
+  2401	  const on=catEnabled[type], d=catDefault[type], t=T();
+  2402	  return `
+  2403	  <div class="cat-row ${on?'':'off'}">
+  2404	    <div class="cat-head">
+  2405	      <label class="cat-tgl">
+  2406	        <input type="checkbox" data-cat="${type}" ${on?'checked':''}>
+  2407	        <span class="cl">${TYPES[type].icon} ${tLabel(type)}</span>
+  2408	      </label>
+  2409	      <span class="cnt ${items.length?'hit':''}">${items.length? t.cnt(items.length) : ''}</span>
+  2410	      <div class="seg" data-cat-seg="${type}" role="radiogroup">
+  2411	        <button class="${d==='ok'?'on-ok':''}" data-cmode="ok">${t.segOk}</button>
+  2412	        <button class="${d==='no'?'on-no':''}" data-cmode="no">${t.segNo}</button>
+  2413	      </div>
+  2414	    </div>
+  2415	    ${items.length?`<div class="cat-items">${items.map(e=>`
+  2416	      <div class="pii-item${located(e)?'':' nolocate'}">
+  2417	        <span class="val mono" title="${escapeHtml(e.value)}">${escapeHtml(displayValue(e))}</span>
+  2418	        ${located(e)?'':`<span class="nl">${t.notLocated}</span>`}
+  2419	        <div class="seg" role="radiogroup">
+  2420	          <button class="${e.mode==='ok'?'on-ok':''}" data-id="${e.id}" data-mode="ok">${t.segOk}</button>
+  2421	          <button class="${e.mode==='no'?'on-no':''}" data-id="${e.id}" data-mode="no">${t.segNo}</button>
+  2422	        </div>
+  2423	      </div>`).join('')}</div>`:''}
+  2424	  </div>`;
+  2425	}
+  2426	// Flat item box for manual selections / name candidates (not category-grouped).
+  2427	function sectionHtml(kind,title,items){
+  2428	  const t=T(), cand=kind==='candidate';
+  2429	  const icon=kind==='candidate'?'❓':kind==='keep'?'🛡':'✏️';
+  2430	  return `
+  2431	  <div class="cat-row sec-${kind}">
+  2432	    <div class="cat-head">
+  2433	      <span class="cl">${icon} ${title}</span>
+  2434	      <span class="cnt hit">${t.cnt(items.length)}</span>
+  2435	    </div>
+  2436	    <div class="cat-items">${items.map(e=>`
+  2437	      <div class="pii-item${cand?' is-cand':''}">
+  2438	        <div class="val-wrap">
+  2439	          <span class="val ${cand?'':'mono'}" title="${escapeHtml(e.value)}">${escapeHtml(kind==='manual'? t.manualItem : displayValue(e))}</span>
+  2440	          ${(cand||kind==='keep')?`<span class="reason">${(TYPES[e.type]||{}).icon||''} ${t.reasons[e.reason]||(e.jp?t.reasons.jp_keep:t.reasons.name)}</span>`:''}
+  2441	        </div>
+  2442	        <div class="seg" role="radiogroup">
+  2443	          <button class="${e.mode==='ok'?'on-ok':''}" data-id="${e.id}" data-mode="ok">${t.segOk}</button>
+  2444	          <button class="${e.mode==='no'?'on-no':''}" data-id="${e.id}" data-mode="no">${t.segNo}</button>
+  2445	        </div>
+  2446	        ${kind==='manual'?`<button class="del" data-del="${e.id}" title="remove" aria-label="remove">✕</button>`:''}
+  2447	      </div>`).join('')}</div>
+  2448	  </div>`;
+  2449	}
+  2450	function renderList(){
+  2451	  const list=$('piiList'), t=T();
+  2452	  const autoE=entities.filter(e=>e.kind!=='candidate'&&e.kind!=='manual'&&e.kind!=='keep');
+  2453	  const manualE=entities.filter(e=>e.kind==='manual');
+  2454	  const candE=entities.filter(e=>e.kind==='candidate');
+  2455	  const keepE=entities.filter(e=>e.kind==='keep');
+  2456	  const total=entities.filter(isOn).length;
+  2457	  $('piiCount').textContent= total? t.cntUse(total):'';
+  2458	  document.querySelectorAll('#bulkBtns button').forEach(b=>b.disabled=!total);
+  2459	  $('catHint').textContent = pages.length? t.hintAfter : t.hintBefore;
+  2460	  const groups={};
+  2461	  for(const e of autoE){(groups[e.type]=groups[e.type]||[]).push(e);}
+  2462	  const all=Object.keys(TYPES).filter(ty=>ty!=='manual');
+  2463	  if(!pages.length){
+  2464	    list.innerHTML = all.map(ty=>catRowHtml(ty,[])).join('');
+  2465	    return;
+  2466	  }
+  2467	  const hits=all.filter(ty=>groups[ty]&&groups[ty].length);
+  2468	  const misses=all.filter(ty=>!groups[ty]||!groups[ty].length);
+  2469	  let html=hits.map(ty=>catRowHtml(ty,groups[ty])).join('');
+  2470	  if(misses.length){
+  2471	    html+=`<button class="more-cats" id="moreCats">${showAllCats? t.moreHide : t.moreShow(misses.length)}</button>`;
+  2472	    if(showAllCats) html+=misses.map(ty=>catRowHtml(ty,[])).join('');
+  2473	  }
+  2474	  if(manualE.length) html+=sectionHtml('manual', t.manualSection, manualE);
+  2475	  if(candE.length)   html+=sectionHtml('candidate', t.candSection, candE);
+  2476	  if(keepE.length)   html+=sectionHtml('keep', t.keepSection, keepE);
+  2477	  list.innerHTML=html;
+  2478	}
+  2479	$('piiList').addEventListener('change',e=>{
+  2480	  const cb=e.target.closest('input[data-cat]'); if(!cb) return;
+  2480	  const cb=e.target.closest('input[data-cat]'); if(!cb) return;
+  2481	  catEnabled[cb.dataset.cat]=cb.checked; renderAll();
+  2482	});
+  2483	$('piiList').addEventListener('click',e=>{
+  2484	  if(e.target.closest('#moreCats')){showAllCats=!showAllCats;renderList();return;}
+  2485	  const del=e.target.closest('button[data-del]');
+  2486	  if(del){ entities=entities.filter(x=>x.id!==del.dataset.del); renderAll(); toast(T().tManualRemoved); return; }
+  2487	  const cm=e.target.closest('button[data-cmode]');
+  2488	  if(cm){
+  2489	    const type=cm.closest('[data-cat-seg]').dataset.catSeg;
+  2490	    catDefault[type]=cm.dataset.cmode;
+  2491	    entities.filter(x=>x.type===type).forEach(x=>x.mode=cm.dataset.cmode);
+  2492	    renderAll(); return;
+  2493	  }
+  2494	  const b=e.target.closest('button[data-id]'); if(!b) return;
+  2495	  const ent=entities.find(x=>x.id===b.dataset.id); if(!ent) return;
+  2496	  // A `keep` field is one the legal matrix says the RECIPIENT needs. Hiding it
+  2497	  // is the user's call, but it must not be a silent one — the usual failure is
+  2498	  // a rejected submission and a second round of sending the same document.
+  2499	  if(ent.kind==='keep' && b.dataset.mode!=='ok') toast(T().jpKeepWarn);
+  2500	  ent.mode=b.dataset.mode; renderAll();
+  2501	});
+  2502	$('bulkBtns').addEventListener('click',e=>{
+  2503	  const b=e.target.closest('button[data-mode]'); if(!b||b.disabled) return;
+  2504	  const hidesKeep = b.dataset.mode!=='ok' && entities.some(x=>isOn(x)&&x.kind==='keep');
+  2505	  entities.filter(isOn).forEach(x=>x.mode=b.dataset.mode); renderAll();
+  2506	  toast(hidesKeep? T().jpKeepWarn : b.dataset.mode==='ok'?T().tBulkOk:T().tBulkNo);
+  2507	});
+  2508	
+  2509	/* ───────── AI scan (text-only; maps found strings back to boxes) ───────── */
+  2510	$('btnAI').addEventListener('click',runAI);
+  2511	async function runAI(){
+  2512	  if(aiDone){toast(T().tAIDup);return;}
+  2513	  if(!docText){return;}
+  2514	  const btn=$('btnAI');
+  2515	  btn.disabled=true; btn.innerHTML='<span class="spinner"></span>'+T().aiBusy;
+  2516	  try{
+  2517	    const res=await fetch('/api/safe_scan',{
+  2518	      method:'POST',headers:{'Content-Type':'application/json'},
+  2519	      body:JSON.stringify({text: docText.slice(0,6000)})
+  2520	    });
+  2521	    const data=await res.json();
+  2522	    if(!res.ok||data.error) throw new Error(data.error||'scan_failed');
+  2523	    const raw=(data.raw||'').replace(/```json|```/g,'').trim();
+  2524	    addEntities(JSON.parse(raw));
+  2525	    aiDone=true;
+  2526	    btn.innerHTML='✅ '+T().aiDone;
+  2527	    setStatus(T().scanAI(entities.length));
+  2528	    renderAll();
+  2529	    toast(T().tAIDone);
+  2530	  }catch(err){
+  2531	    console.error(err);
+  2532	    btn.disabled=false; btn.innerHTML='🤖 <span data-i18n="btnAI">'+T().btnAI+'</span>';
+  2533	    toast(T().tAIFail);
+  2534	  }
+  2535	}
+  2536	
+  2537	/* ───────── watermark controls ───────── */
+  2538	// {date} is filled with today's date at build time rather than left as a
+  2539	// "YYYY-MM-DD" placeholder: the dated preset exists so the recipient can see WHEN
+  2540	// the copy was handed over, and a watermark reading "YYYY-MM-DD" says nothing.
+  2541	const wmPreset=i=>(T().wmPresets[i]||'').replace('{date}', new Date().toISOString().slice(0,10));
+  2542	function buildWmPresets(){
+  2543	  const sel=$('wmPreset'); if(!sel) return;
+  2544	  const prev=sel.value;
+  2545	  const t=T();
+  2546	  sel.innerHTML = t.wmPresets.map((p,i)=>`<option value="p${i}">${escapeHtml(wmPreset(i))}</option>`).join('') + `<option value="custom">${t.wmCustom}</option>`;
+  2547	  // keep prior selection if still valid
+  2548	  if(prev && [...sel.options].some(o=>o.value===prev)) sel.value=prev; else sel.value='p0';
+  2549	  if($('wmText') && !$('wmText').value) $('wmText').value=wmPreset(0);
+  2550	}
+  2551	$('wmOn').addEventListener('change',()=>{ $('wmBody').classList.toggle('on',$('wmOn').checked); drawPreview(); updateMake(); });
+  2552	$('wmPreset').addEventListener('change',()=>{ const v=$('wmPreset').value; if(v!=='custom'){ const i=+v.slice(1); $('wmText').value=wmPreset(i); } else { $('wmText').focus(); } drawPreview(); updateMake(); });
+  2553	$('wmText').addEventListener('input',()=>{ drawPreview(); updateMake(); });
+  2554	const wmEnabled=()=>$('wmOn').checked && $('wmText').value.trim().length>0;
+  2555	const wmText=()=>$('wmText').value.trim();
+  2556	
+  2557	/* ───────── build & download (flattened raster) ───────── */
+  2558	function buildMaskedText(){
+  2559	  let out=docText;
+  2560	  const sorted=[...entities].filter(isOn).sort((a,b)=>b.value.length-a.value.length);
+  2561	  for(const e of sorted){
+  2562	    if(e.mode==='ok') continue;
+  2563	    const re=new RegExp(e.value.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'),'g');
+  2564	    out=out.replace(re, maskBlockText(e.value));
+  2565	  }
+  2566	  return out;
+  2567	}
+  2568	function composePage(pi){
+  2569	  const page=pages[pi];
+  2570	  const cv=canvasEl(page.w,page.h);
+  2571	  const ctx=cv.getContext('2d');
+  2572	  ctx.drawImage(page.canvas,0,0);
+  2573	  drawRedactions(ctx,pi,1);
+  2574	  if(wmEnabled()) drawWatermark(ctx,cv.width,cv.height,wmText());
+  2575	  return cv;
+  2576	}
+  2577	$('btnMake').addEventListener('click',async()=>{
+  2578	  const btn=$('btnMake'); btn.disabled=true;
+  2579	  setStatus(T().building);
+  2580	  try{
+  2581	    const outs=pages.map((_,pi)=>composePage(pi));
+  2582	    const fmt=document.querySelector('input[name=fmt]:checked').value;
+  2583	    const base=(docTitle||'doc').replace(/\.[^.]+$/,'')+'_safe';
+  2584	    if(fmt==='pdf'){
+  2585	      const {jsPDF}=await ensureJsPDF();
+  2586	      let doc;
+  2587	      outs.forEach((cv,i)=>{
+  2588	        const wpt=pages[i].ptW, hpt=pages[i].ptH, o=wpt>hpt?'l':'p';
+  2589	        if(i===0) doc=new jsPDF({unit:'pt',format:[wpt,hpt],orientation:o});
+  2590	        else doc.addPage([wpt,hpt], o);
+  2591	        doc.addImage(cv.toDataURL('image/jpeg',0.92),'JPEG',0,0,wpt,hpt);
+  2592	      });
+  2593	      lastOut={fmt:'pdf', pdf:doc, name:base+'.pdf'};
+  2594	      showResult(outs);
+  2595	    } else {
+  2596	      const type=fmt==='jpg'?'image/jpeg':'image/png';
+  2597	      const dataUrls=outs.map(cv=>cv.toDataURL(type,0.92));
+  2598	      lastOut={fmt, dataUrls, name:base+'.'+fmt};
+  2599	      showResult(outs);
+  2600	    }
+  2601	    const hidden=entities.filter(e=>isOn(e)&&e.mode!=='ok'&&located(e)).reduce((s,e)=>s+e.boxes.length,0);
+  2602	    toast(hidden? T().tMade(hidden) : T().tMadeWM);
+  2603	  }catch(err){ console.error(err); toast(T().tReadFail); }
+  2604	  finally{ setStatus(''); btn.disabled=false; }
+  2605	});
+  2606	/* ───────── result viewer (fit-to-page, pager, zoom, fullscreen) ───────── */
+  2607	let rvPages=[];        // composed source canvases (final pixels)
+  2608	let rvIndex=0;         // current page
+  2609	let rvZoom=null;       // null = fit-to-page; else multiplier of fit (>1)
+  2610	let rvIsFull=false;    // fullscreen overlay open?
+
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+exec
+/bin/zsh -lc 'git show 546344b:public/safe/index.html | nl -ba | rg "function isOn|const isOn|catEnabled|catDefault"' in /Users/sunghoon/Projects/docpack
+ succeeded in 0ms:
+   751	const catEnabled={}, catDefault={};
+   776	Object.keys(TYPES).forEach(t=>{catEnabled[t]=true;catDefault[t]=TYPES[t].risk;});
+   777	const isOn=e=>catEnabled[e.type]!==false;
+  2203	    const mode = e.mode || (kind==='candidate' ? 'ok' : catDefault[type]);
+  2401	  const on=catEnabled[type], d=catDefault[type], t=T();
+  2481	  catEnabled[cb.dataset.cat]=cb.checked; renderAll();
+  2490	    catDefault[type]=cm.dataset.cmode;
+
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+exec
+/bin/zsh -lc "git show 546344b:test/safe/fixtures/jp/gen.py | nl -ba | sed -n '1,280p'; for f in test/safe/fixtures/jp/*/*.specs.json; do echo \"FILE "'$f"; git show 546344b:$f | rg -n '"'name|address|number|watermark|boxes_png|purposes|公安|公印|市長|顔写真|写真|logo|qr|個人番号|免許'; done" in /Users/sunghoon/Projects/docpack
+ succeeded in 2ms:
+7: "boxes_png": {
+14:  "name": [
+26:  "address": [
+57: "doc": "運転免許証",
+59: "purposes": {
+66:    "name",
+68:    "address",
+
+hook: PostToolUse
+hook: PostToolUse Completed
+codex
+동적 실행은 시도했지만 샌드박스가 로컬 서버 바인딩을 `EPERM`으로 차단해 한 건도 실행되지 않았습니다. 따라서 최종 보고서는 명확히 “정적 검토”로 표기하고, 구현자가 남긴 389/389 로그를 제가 재현한 결과처럼 취급하지 않겠습니다. 법률 부분은 일본 정부의 현행 원문으로 별도 검증 중입니다.
+hook: PreToolUse
+hook: PreToolUse Completed
+web search: 
+web search: site:elaws.e-gov.go.jp 番号法施行令 別表 検査用数字 Qn 個人番号 ...
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+web search: 
+web search: 個人番号 検査用数字 算式 Pn Qn n 6 番号法施行令 PDF ...
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+web search: 
+web search: W3C PNG specification ancillary chunks unknown private chunk safe-to-copy iCCP tIME ...
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+web search: 
+web search: site:city.*.jp 住民票 見本 PDF 氏名 世帯全員 ...
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+exec
+/bin/zsh -lc 'git show 546344b:public/safe/index.html | nl -ba | rg "strong|viaFallback|checkOk|unlabelledCode"' in /Users/sunghoon/Projects/docpack
+ succeeded in 0ms:
+   101	.dropzone strong{font-size:15px}
+   179	.make .info strong{font-size:15px}
+   246	.partner-card strong{font-size:14px;display:block;margin-bottom:4px}
+   261	.install-banner .ib-body strong{display:block;font-size:13.5px;font-weight:700;letter-spacing:-.01em}
+   334	          <strong data-i18n="dzTitle">파일을 끌어다 놓거나 클릭하세요</strong>
+   397	        <strong><span class="step-n" style="vertical-align:-4px;margin-right:6px">3</span><span data-i18n="s3">문서 만들기</span></strong>
+   471	      <a class="partner-card" href="https://slimfile.net" target="_blank" rel="noopener"><strong>🗜 SlimFile</strong><span data-i18n="pSlim">이미지 압축과 PDF 변환, 2MB 이하로 간단하게.</span></a>
+   472	      <a class="partner-card" href="https://schooljob.site" target="_blank" rel="noopener"><strong>🎓 Schooljob</strong><span data-i18n="pSchool">선생님을 위한 채용 정보, 딱 맞는 학교 찾기.</span></a>
+   473	      <a class="partner-card" href="https://hellokorean.org" target="_blank" rel="noopener"><strong>🌏 HelloKorean</strong><span data-i18n="pHello">한국어 배우기, 오늘부터 시작하세요.</span></a>
+   487	    <strong id="ibTitle"></strong>
+  1624	        const extra = r.field === 'my_number' ? { checkOk: myNumberCheckOk(sp.digits) } : {};
+  1675	        push('hokensha_bango', jpBoxes(seg, a, b), seg.t.slice(a,b), { viaFallback: true });
+  1686	        if (len === 12) push('my_number', jpBoxes(seg, a, b), seg.t.slice(a,b), { checkOk: myNumberCheckOk(seg.t.slice(a,b)), viaFallback: true });
+  1687	        else if (len === 11) push('jumin_code', jpBoxes(seg, a, b), seg.t.slice(a,b), { viaFallback: true });
+  1709	      push('address_loose', jpBoxes(seg, sp.a, sp.b), seg.t.slice(sp.a, sp.b), { strong: sp.postal && sp.pref });
+  1728	    for (const cb of jpCodeBlocks(pi)) push('qr', [cb.box], '二次元コード', { unlabelledCode: !cb.labelled });
+  1822	    if (f.field === 'my_number' && (level === 'auto' || level === 'gate') && f.checkOk === false){ level = 'recommend'; note = 'checkdigit'; }
+  1824	    if (f.unlabelledCode && (level === 'auto' || level === 'gate')){ level = 'recommend'; note = 'unlabelled_code'; }
+
+hook: PostToolUse
+hook: PostToolUse Completed
+hook: PreToolUse
+hook: PreToolUse Completed
+web search: 
+web search: site:laws.e-gov.go.jp 刑法 公文書偽造 行使の目的 第155条 ...
+hook: PostToolUse
+hook: PostToolUse Completed
+codex
+검토 범위는 커밋 `546344b`의 파일 내용을 `git show`로 직접 읽은 정적 검토입니다. `node run.mjs`도 시도했지만 `127.0.0.1` 서버 바인딩이 `EPERM`으로 차단되어 실행되지 않았습니다. 따라서 `389/389`는 구현자 로그일 뿐, 제가 재현한 결과가 아닙니다.
+
+## 1. 탐지 미탐 위험
+
+### 1-1. 문서 분류 실패 시 무경고로 JP 보호가 전부 사라짐
+
+문제 / `資格確認書`는 제목만 정상 인식되면 3점이라 임계값 4에 못 미칩니다. `保険者番号` 등 추가 키워드 하나가 깨지면 실제 문서가 “一般文書”로 떨어지고 JP 번호 탐지가 전혀 실행되지 않습니다. 사용자는 분류 실패 사실이나 수동 확인 필요성을 알 수 없습니다.
+
+근거 / `public/safe/index.html:1161-1199`, 특히 `資格確認書=3`, `min:4`; `public/safe/index.html:1774-1784`의 `if (!cls) return null`; `public/safe/index.html:2143-2151`은 실패 시 일반 이름·주소 휴리스틱으로 조용히 전환합니다. 실제 보험자별 실패율은 **확인 불가**입니다.
+
+수정안 / 임계 미달이어도 JP 의심 점수·일본 문서 특징이 있으면 “문서 종류를 확인하지 못해 자동 마스킹을 적용하지 않았다”는 차단성 경고를 표시하십시오. `資格確認書` 제목 단독은 최소 candidate scan을 허용하고, 보험자별 실물 익명 샘플로 분류 recall 게이트를 별도로 두어야 합니다.
+
+### 1-2. 고정 세그먼트 간격이 DPI·레이아웃 변화에 취약함
+
+문제 / 레이블 끝과 값 시작의 공백이 `max(90px, 폭×10%)` 이상이면 둘이 분리되어 값 규칙이 미탐됩니다. 반대로 다음 칸과의 간격이 그보다 작으면 두 칸이 합쳐지고, 두 번째 레이블은 세그먼트 선두가 아니어서 미탐됩니다. OCR 렌더 배율과 사진 원근에 따라 같은 서식도 양쪽 실패가 가능합니다.
+
+근거 / `public/safe/index.html:1115-1145`, `public/safe/index.html:1575-1581`, `public/safe/index.html:1601-1609`. 80px/140px 가정은 알파 픽스처 측정뿐입니다.
+
+수정안 / 페이지 폭이 아니라 행 글자 높이와 인접 박스 분포에서 동적 임계값을 구하고, 레이블과 값이 분리된 인접 세그먼트도 동일 행·수직 중첩·최대 거리 조건으로 결합하십시오. 좁은 표에서는 열 경계/괘선을 함께 사용해야 합니다.
+
+### 1-3. 모든 규칙의 `headOnly` 강제가 과도함
+
+문제 / `●`, `※`, 항목번호, 괄호, OCR 잡음 한 글자, 표 셀의 선행 문자가 붙으면 모든 값 레이블이 거부됩니다. 한 각주 오탐을 막기 위해 전체 필드의 recall을 희생합니다.
+
+근거 / `public/safe/index.html:1575-1581`, `public/safe/index.html:1594-1609`. 원래 개별 규칙의 `headOnly` 설정과 무관하게 `.map(... headOnly:true)`로 덮어씁니다.
+
+수정안 / 선두에 허용할 잡음 클래스를 제한하십시오. 예: 공백·`※●○□・(1)①`·1문자 저신뢰 OCR만 건너뛰고, 레이블 이후 값 형식·동일 셀·거리 점수로 확정하십시오. 각주 방지는 “레이블 뒤 필드값 형식 존재”와 문장형 종결 패턴으로 처리해야 합니다.
+
+### 1-4. 숫자 길이 폴백이 비민감 번호를 자동 마스킹함
+
+문제 / `資格確認書`의 모든 독립 6~10자리 숫자가 `hokensha_bango`가 됩니다. 하이픈 없는 우편번호, 압축 날짜, 전화번호, 교부·발행·証明書番号 같은 숫자도 자동 마스킹될 수 있습니다. `一部負担金割合`과 일반적인 `限度額区分`은 보통 해당 길이가 아니지만, 발행·관리번호의 실제 존재와 자릿수는 현재 자료로 **확인 불가**입니다. 후期高齢者용 `資格確認書`에는 실제로 負担割合·交付年月日·適用区分 등이 존재합니다. [旭川市 안내](https://www.city.asahikawa.hokkaido.jp/kurashi/135/171/176/p004497.html)
+
+`住民票`의 11자리 폴백은 하이픈 없는 휴대전화나 증명서 일련번호를 `住民票コード`로, 12자리는 임의 참조번호를 `個人番号` 후보로 오인할 수 있습니다.
+
+근거 / `public/safe/index.html:1655-1691`. 제외 조건은 `[年月日]` 또는 `〒`가 있는 행뿐입니다.
+
+수정안 / `資格確認書` 폴백은 번호가 위치한 셀의 인접 레이블 조각, 번호군 주변 좌표, 보험자 번호 형식/코드체계까지 요구하십시오. `住民票コード`에는 체크디지트와 레이블/열 헤더를 요구하고, `個人番号`는 체크디지트가 실패하면 폴백 자동 경로에서 제외하거나 명확한 수동 검토로 낮추십시오.
+
+### 1-5. `myNumberCheckOk` 계산은 맞지만 법적 출처 표기가 틀림
+
+문제 / 함수 계산 자체는 맞습니다. 다만 주석의 “番号法施行令 別表”는 정확한 근거 위치가 아닙니다. 현재 산식은 관련 명령 제5조의 산식입니다.
+
+근거 / `public/safe/index.html:1202-1211`. 구현은 오른쪽부터 `Pₙ`, `Qₙ=n+1 (n≤6), n−5 (n≥7)`, `11-(합 mod 11)`, 결과 10·11이면 0으로 처리합니다. 정부 원문도 합의 11 나머지가 0 또는 1이면 검사 숫자를 0으로 하므로 동치입니다. [e-Gov 관련 명령 제5조](https://laws.e-gov.go.jp/document?lawid=426M60000008085_20231215_505M60004008017)
+
+수정안 / 로직은 유지하고 주석·법적 매트릭스 출처를 정확한 명령 제5조로 고치십시오. 유효·무효 경계값을 독립 테스트 벡터로 추가해야 합니다.
+
+### 1-6. 世帯員 경계가 실제 양식 변형을 견디지 못함
+
+문제 / 반복되는 `氏名` 레이블이 하나라도 OCR에서 깨지면 해당 세대원 블록이 통째로 남습니다. 반대로 블록 내부의 발행자·증명문이 종료 표현과 일치하지 않으면 마지막 세대원 영역이 페이지 끝까지 확장되어 발행자까지 가릴 수 있습니다. 공통 열 헤더 하나 아래 여러 명을 행으로 나열하는 `世帯連記式`은 `nameRows.length > 1` 조건 자체를 충족하지 않을 수 있습니다.
+
+근거 / `public/safe/index.html:1731-1766`. 실제 지자체는 `世帯連記式`과 `個人票様式`을 모두 사용합니다. [宇都宮市 양식 안내](https://www.city.utsunomiya.lg.jp/kurashi/jumin/koseki/1043547.html). 반복 블록 예시는 `氏名` 외에 `個人番号`, `住民票コード`, `備考`가 각 세대원 블록에 포함됩니다. [大阪市 공식 견본](https://www.city.osaka.lg.jp/toshiseibi/cmsfiles/contents/0000648/648120/syoruininntei.pdf)
+
+수정안 / `氏名` 단일 앵커가 아니라 행 번호, `続柄`, 반복 열 구조, 구분선, 다음 사람 번호를 함께 사용하십시오. 마지막 경계는 발행일·증명문·발행기관 영역을 별도 보호구역으로 먼저 검출하고 그 위에서 강제로 종료해야 합니다.
+
+## 2. 오탐 및 증빙 훼손
+
+### 2-1. `jpFrameBelow`는 사각형이 아니라 평행 가로선 두 개만 검증함
+
+문제 / 표의 상하 괘선이나 외곽선 두 개를 欄으로 오인할 수 있습니다. 세로 변, 내부 영역, 레이블과 프레임의 x관계를 검사하지 않습니다. `jpRowInk`가 행별 가장 긴 런 하나만 반환하므로 실제 작은 欄보다 페이지 전체 표선이 우선됩니다.
+
+근거 / `public/safe/index.html:1234-1267`. 폴백도 실패 시 페이지 폭의 최소 50%, 레이블 높이 3.5배를 덮습니다(`1714-1722`).
+
+수정안 / 좌우 세로선 존재, 모서리 연결, 프레임 내부 포함관계, 레이블 x근접성을 검증하십시오. 한 행의 모든 런을 보존한 뒤 앵커와 가까운 런을 선택해야 합니다.
+
+### 2-2. 레이블 없는 사각형 candidate가 실제로 기본 ON임
+
+문제 / 얼굴사진·검은 인감·정사각 로고·검은 표 헤더는 크기·종횡비·밀도 조건을 만족할 수 있습니다. 특히 채워진 원형 인감은 이론상 경계상자 채움률이 약 0.785라 `fill≥0.75`를 넘을 수 있습니다. 코드 주석은 “candidate, never automatic band”라고 하지만, `recommend` candidate의 기본 mode는 `no`여서 실제 출력에서는 기본으로 가려집니다.
+
+근거 / `public/safe/index.html:1334-1366`, `public/safe/index.html:1796-1801`, `public/safe/index.html:1823-1825`. `labelled:false` → `recommend` → `mode:'no'`.
+
+수정안 / 미검증 `unlabelledCode`는 `optional`, `mode:'ok'`로 두십시오. finder 패턴·quiet zone·모듈 주기 등 QR 고유 특징을 확인하기 전에는 기본 출력에 포함하면 안 됩니다.
+
+### 2-3. 주소 “강한 자동 조건”이 구현되지 않음
+
+문제 / `郵便番号+都道府県`를 `strong:true`로 계산하지만 그 값은 어디에서도 사용하지 않습니다. 따라서 전략의 “동반 시 자동”은 구현되지 않았습니다. `consult_share`에서는 모든 `address_loose`가 강도와 무관하게 권장 ON이고, 다른 목적에서는 모두 optional입니다.
+
+근거 / `public/safe/index.html:1538-1563`, `public/safe/index.html:1694-1710`; `strong` 검색 결과 사용처 없음; `JP_EXTRA`는 `public/safe/index.html:1383-1387`.
+
+수정안 / `strong`을 실제 level 결정에 반영하거나 전략에서 자동 약속을 삭제하십시오. 기관명 감점은 주소 뒤 8자까지만 보므로 더 멀리 붙은 회사명은 감점되지 않습니다. 회사 소재지와 개인 주소 구별에는 `住所変更`, `現住所`, `送付先` 같은 개인 문맥이 추가로 필요합니다.
+
+### 2-4. 15% 패딩은 가까운 이웃 필드를 덮을 수 있음
+
+문제 / 높이 `h`인 두 필드의 간격이 약 `0.3h`보다 작으면 상하 패딩이 겹칩니다. 좌우도 각 필드 경계에서 `0.15h`만큼 침범합니다. 더 큰 문제는 `mergeLineBoxes`가 하나라도 `region:true`이면 합쳐진 전체 라인의 패딩을 제거하여 다른 OCR 박스의 가장자리가 노출될 수 있다는 점입니다.
+
+근거 / `public/safe/index.html:2256-2274`, `public/safe/index.html:2276-2291`.
+
+수정안 / 패딩을 인접 OCR 박스·셀 경계까지 clamp하고, region과 텍스트 박스를 같은 merged line으로 합치지 마십시오. `region:true`의 패딩 제외는 수동 드래그에는 맞지만 자동 검출 프레임까지 같은 신뢰도로 취급하는 것은 부적절합니다.
+
+## 3. 출력 안전성
+
+### 3-1. PDF 바이트 marker 목록은 완전한 검사가 아님
+
+문제 / `/Metadata`, 문서 `/Info`, `/EF`, `/Filespec`, `/OpenAction`, `/AA`, `/JS`, `/Launch`, `/RichMedia`가 빠졌습니다. 문자열 검색은 Flate 압축 스트림과 object stream 내부 이름·문자열도 보지 못합니다. PDF는 간접 객체를 object stream 안에 압축 저장할 수 있습니다. [Adobe PDF 32000-1 §7.5.7](https://developer.adobe.com/document-services/docs/assets/35e4369068f86065372c18787171a17e/PDF_ISO_32000-1.pdf)
+
+근거 / `test/safe/run.mjs:241-257`, `289-305`.
+
+수정안 / qpdf 또는 PDF 파서로 객체 그래프를 풀어 Catalog, Info, Metadata, Names, annotations, actions, file specifications, embedded streams를 검사하십시오. `%%EOF` 개수는 증분 저장 신호일 뿐 완전한 구조 검사가 아닙니다.
+
+### 3-2. 입력 PDF 구조물이 직접 출력되는 경로는 없음
+
+문제 / 입력 주석·첨부·북마크·XMP가 jsPDF 새 문서에 복사되는 경로는 찾지 못했습니다. 이 항목에서 원본 구조 누출 주장은 성립하지 않습니다. 다만 픽셀 자체에 숨겨진 데이터나 육안상 남은 원본은 래스터 재인코딩만으로 제거되지 않습니다.
+
+근거 / `public/safe/index.html:2568-2593`: 원본 페이지를 canvas에 그리고 JPEG data URL만 새 jsPDF에 삽입합니다. jsPDF `addImage`도 Canvas/data URL 입력을 받는 API입니다. [jsPDF addImage 문서](https://parallax.github.io/jsPDF/docs/module-addImage.html)
+
+수정안 / “원본 PDF 객체를 계승하지 않는다”는 논증은 유지하되, 테스트 문구를 “모든 가능한 PDF 누출을 검사한다”가 아니라 “새 래스터 PDF 생성 경로와 출력 객체 allowlist를 검증한다”로 제한하십시오.
+
+### 3-3. ICC 2KB·`dmnd/dmdd` 기준은 신원정보 부재를 증명하지 못함
+
+문제 / 2KB 이하 임의 프로파일도 `desc`, `mluc`, `cprt` 또는 private payload에 장치·사용자 정보를 넣을 수 있고, 디스플레이 프로파일이 반드시 `dmnd/dmdd`를 갖는 것도 아닙니다. 현재 검사는 첫 `ICC_PROFILE`만 보고 분할 APP2 프로파일 전체도 구조적으로 검증하지 않습니다.
+
+근거 / `test/safe/run.mjs:258-270`.
+
+수정안 / 허용할 ICC 프로파일의 전체 바이트 SHA-256 allowlist를 사용하거나 출력 후 ICC를 제거하십시오. “크기+두 태그 부재”를 안전성 경계로 사용하면 안 됩니다.
+
+### 3-4. PNG는 네 청크만 금지하여 임의 보조 청크를 놓침
+
+문제 / `iCCP`, `tIME`, `sPLT` 및 private ancillary chunk에도 데이터가 실릴 수 있습니다. PNG 규격은 private·unknown ancillary chunk를 명시적으로 허용합니다. [W3C PNG 규격](https://www.w3.org/TR/png/)
+
+근거 / `test/safe/run.mjs:241-245`.
+
+수정안 / PNG 청크를 구조적으로 파싱하여 `IHDR`, 필요한 색공간 청크, `IDAT`, `IEND`의 allowlist만 허용하십시오. 적어도 모든 ancillary/private chunk의 목록과 payload 크기를 검증해야 합니다.
+
+## 4. 목적 게이트와 법적 매트릭스
+
+### 4-1. `JP_RULES`는 정본과 일치하지 않음
+
+문제 / 주요 불일치는 다음과 같습니다.
+
+- `JP_EXTRA(address_loose/tel)`는 법적 정본에 전혀 없습니다.
+- `資格確認書`의 keep 항목을 모든 목적에 적용하며 `事業所名称`, `保険者名`, `資格取得年月日`까지 추가합니다.
+- `運転免許証番号`은 정본상 `identity_submit`에서 must-keep인데 구현은 모든 목적 optional입니다.
+- `マイナンバーカード`의 `my_number`, `qr` 개별 gate는 정본의 `裏面全体` 규칙을 코드에서 분해해 추가한 것입니다.
+- `住民票`의 keep은 정본상 `identity_submit`, `bid_attachment`인데 구현은 모든 목적입니다.
+- 정본의 `発行日・発行者`는 검출 규칙이 없어 keep 경고가 실제로 생성되지 않습니다.
+- `住民票コード`는 정본에서 `verified:false`인데 자동 마스킹됩니다.
+
+근거 / `test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:16-57`; `public/safe/index.html:1381-1431`, `1450-1503`.
+
+수정안 / 사람이 작성한 두 번째 표가 아니라 legal matrix JSON을 빌드 시 변환해 단일 소스로 사용하십시오. `verified:false`는 자동 level을 금지하는 검증 규칙을 추가해야 합니다.
+
+### 4-2. 미명시 목적을 항상 `optional`로 만드는 폴백은 잘못됨
+
+문제 / `return r.keep ? 'optional' : 'optional'`은 조건문이 무의미하며, 매트릭스가 의도적으로 명시하지 않은 조합과 “선택 제공”을 구별하지 못합니다. 특히 `資格確認書` 번호군은 `my_number_procedure`에서 optional로 노출되지만, 해당 목적이 의료보험 관련 개인번호 사무인지에 따라 번호가 필요한 예외가 존재할 수 있습니다. 구체적 업무 조합은 **확인 불가**입니다. 厚労省도 건강보험 사무 또는 관련 사무에는 고지 제한 예외가 있음을 명시합니다. [厚労省](https://www.mhlw.go.jp/stf/newpage_13989.html)
+
+근거 / `public/safe/index.html:1433-1441`.
+
+수정안 / 미명시는 `null`로 두고 UI에 내지 마십시오. 명시적으로 `optional`인 경우만 optional을 반환하도록 매트릭스에 목적별 상태를 완전 열거해야 합니다.
+
+### 4-3. `本籍`/`筆頭者` 확장은 법적 근거가 없음
+
+문제 / 근거가 “필요 없어 보인다”와 픽스처 기대값뿐이라 순환 논증입니다. `my_number_procedure`·`bid_attachment`의 모든 하위 업무에서 불필요하다는 출처가 없습니다.
+
+근거 / `public/safe/index.html:1377-1380`, `1426-1427`; `docs/jp/s3_report.md:239-242`.
+
+수정안 / 법적 정본을 바꾸기 전에는 해당 두 목적을 optional로 두십시오. 실제 제출처 요구사항 또는 공식 지침을 목적별로 확보한 뒤 recommend로 승격해야 합니다.
+
+### 4-4. マイナカード裏面 안내는 지나치게 단정적임
+
+문제 / 身元確認 목적으로 뒷면을 복사·보관하면 제한 위반 가능성이 있으므로 앞면 제출 안내는 타당합니다. 다만 단순히 보았다는 것까지 불법인 것은 아니므로 “番号法により…できません”은 행위·주체·예외를 생략합니다. `個人番号手続` 선택만으로 모든 수령처가 적법한 개인번호 이용사무 수행자임을 확인할 수도 없습니다.
+
+근거 / `public/safe/index.html:1804-1812`; PPC는 의도치 않게 본 것과 복사·기록을 구별합니다. [PPC FAQ Q6-12](https://www.ppc.go.jp/all_faq_index/faq5-q6-12/)
+
+수정안 / “법정 개인번호 사무를 수행하는 제출처에 한해 해제” 확인을 추가하고, 단순 목적 드롭다운만으로 전면 해제하지 마십시오.
+
+### 4-5. keep을 가릴 수 있게 둔 것은 법 위반이 아니라 제출 유효성 문제
+
+문제 / 모든 keep 필드를 법적으로 차단해야 한다는 근거는 없습니다. 그러나 `my_number_procedure`의 個人番号처럼 목적 자체가 성립하지 않는 필드까지 일괄 비공개할 수 있어, 사용자가 “해당 목적용 안전 파일”이라고 오해할 수 있습니다.
+
+근거 / `public/safe/index.html:2494-2506`. 법적 차단 필요성은 **확인 불가**입니다.
+
+수정안 / 일반 keep은 경고 유지, 목적의 핵심 필드는 “강제 유지” 또는 최종 확인 대화상자로 분리하십시오. 최소한 목적 적합성 상태를 실패로 표시해야 합니다.
+
+### 4-6. `その他` 토글이 법적 띠를 무조건 해제함
+
+문제 / `back_all`과 `qr`가 `other`에 매핑되고 `isOn`은 카테고리 boolean만 봅니다. 사용자가 その他를 끄면 マイナカード裏面 전체와 資格確認書 QR 띠가 출력에서 사라집니다. 별도 강한 경고도 없습니다.
+
+근거 / `public/safe/index.html:1831-1834`, `751-777`, `2320-2329`, `2480-2482`.
+
+수정안 / 법적 preset 엔티티는 일반 카테고리 토글에서 분리하십시오. 해제는 개별 항목과 목적별 확인을 거치게 하고, 하네스도 카테고리 OFF 상태에서 법적 띠가 유지되는지 검증해야 합니다.
+
+## 5. 하네스 유효성
+
+### 5-1. `jp_auto_fields`는 목적·검증 상태를 표현하지 못함
+
+문제 / 문서별 정적 배열이라 목적별 `auto/gate/keep` 차이를 나타내지 못합니다. `住民票コード`의 `verified:false`도 무시됩니다. 앱과 하네스가 같은 잘못된 해석을 공유할 수 있습니다.
+
+근거 / `test/safe/specs.json:83-90`; `test/safe/run.mjs:430-496`.
+
+수정안 / legal matrix JSON에서 `(doc, field, purpose)`별 기대 level을 직접 계산하고, 정적 중복표를 제거하십시오.
+
+### 5-2. 유효 個人番号 자동 띠가 전혀 검증되지 않음
+
+문제 / `JP_MASK_OR_CAND`는 잘못된 체크디지트 더미가 candidate만 되어도 통과합니다. 유효 체크디지트가 `auto/gate`가 되는 테스트는 없습니다.
+
+근거 / `test/safe/specs.json:90-91`; `test/safe/run.mjs:423-425`, `495-496`; 생성기는 모두 무효 번호만 만듭니다(`gen.py:35-45`).
+
+수정안 / 실물과 무관한 텍스트/캔버스 유닛 픽스처로 유효 체크디지트 번호를 생성하여 `checkOk:true`, 자동 띠, 목적 전환 해제를 각각 검증하십시오. 공개 카드 이미지에 유효 번호를 넣을 필요는 없습니다.
+
+### 5-3. 60% 피복은 판독 불가를 보장하지 않음
+
+문제 / 한 OCR word의 60%만 덮고 나머지 40%에 여러 숫자가 그대로 남아도 통과합니다. 구현자 스스로 96% 피복인데 첫 숫자가 노출된 사례를 기록했으므로 현재 기준의 부적합성이 이미 입증되었습니다.
+
+근거 / `test/safe/run.mjs:404-424`; `docs/jp/s3_report.md:207-212`.
+
+수정안 / 숫자 필드는 각 문자 또는 잉크 연결요소가 100%+허용 오차로 덮이는지 검사하십시오. 출력 이미지에 대해 OCR 재검사와 픽셀 차분을 병행해야 합니다.
+
+### 5-4. `geometry:false`가 가장 어려운 입력의 오배치를 숨김
+
+문제 / JPG 세 건과 목적 교차 한 건은 field와 mode만 검사합니다. 완전히 엉뚱한 위치의 띠, 빈 박스, 카테고리 OFF 상태도 통과할 수 있습니다.
+
+근거 / `test/safe/specs.json:113-116`, `145-153`; `test/safe/run.mjs:448-465`. `require_banded`는 `mode !== 'ok'`만 봅니다.
+
+수정안 / 회전·원근 변환 행렬을 픽스처에 기록하거나 출력 이미지의 알려진 민감 문자열/영역을 OCR·픽셀 기준으로 검사하십시오.
+
+### 5-5. 공허한 단언 경로가 남아 있음
+
+문제 / 다음 경로가 공허하거나 약합니다.
+
+- absent box는 `skipped`로 기록만 하고, 다른 박스 하나만 검사하면 `JP_COVERAGE > 0` 통과.
+- `P.keep === 'all'`이면 keep 검사를 아예 빈 배열로 만듦.
+- `require_banded`는 좌표·located·`isOn`을 확인하지 않음.
+- `JP_CLEAR`도 위치와 실제 출력 피복을 확인하지 않음.
+- `__candidateOver`는 주석과 달리 candidate의 활성 상태나 mode를 확인하지 않음.
+
+근거 / `test/safe/run.mjs:111-119`, `453-465`, `473-500`.
+
+수정안 / 기대 키 누락을 즉시 실패시키고 `checked === expectedExistingCount`를 요구하십시오. field 단언은 실제 `__maskRects`와 교차하도록 바꾸고 `keep:'all'`은 모든 box를 열거해 검사해야 합니다.
+
+### 5-6. `max_auto`는 오탐 종류를 제한하지 못함
+
+문제 / kenpo 실측 5에 상한 8, kouki 실측 3에 상한 8이면 각각 3개·5개의 신규 오탐이 생겨도 통과합니다. 올바른 엔티티가 빠지고 잘못된 엔티티가 대신 생겨 총수만 같아도 통과합니다.
+
+근거 / `test/safe/specs.json:94-104`; 실측값은 `docs/jp/s3_report.md:201-202`.
+
+수정안 / 총수 상한을 보조 지표로만 두고 필드·좌표별 allowlist와 “예상하지 않은 자동 엔티티 0” 단언을 추가하십시오.
+
+## 6. 커버리지 없는 구현
+
+### 6-1. 레이블 없는 QR 완화가 충분하지 않음
+
+문제 / candidate로 낮췄지만 기본 ON이므로 완화가 실패했습니다.
+
+근거 / `public/safe/index.html:1823-1825`, `1796-1801`.
+
+수정안 / 실제 QR fixture가 생기기 전까지 optional·기본 OFF로 고정하십시오.
+
+### 6-2. 電話·FAX 테스트가 통합 경로를 검증하지 않음
+
+문제 / 유닛은 정규식만 직접 호출하며 `jpFindLabel → jpBoxes → jpApply`를 지나지 않습니다.
+
+근거 / `test/safe/run.mjs:524-532`.
+
+수정안 / 합성 canvas/PDF에 레이블과 번호를 분리 배치해 세그먼트·좌표·mode까지 검증하십시오.
+
+### 6-3. 주소 자동 분기는 “미검증”이 아니라 사실상 미구현
+
+문제 / `strong`이 사용되지 않아 실제 문서뿐 아니라 코드상으로도 자동 승격이 없습니다.
+
+근거 / `public/safe/index.html:1709`; 사용처 없음.
+
+수정안 / 전략과 구현 중 하나를 일치시키고 그 경로를 통합 테스트하십시오.
+
+### 6-4. 다중 페이지는 단순 상속보다 더 위험함
+
+문제 / 페이지별로 다른 `c`로 추출하면서 `jpApply`는 1페이지 `cls.doc/side` 규칙만 적용합니다. マイナカード 앞·뒤 양면 PDF에서 첫 페이지가 back이면 모든 페이지에 `back_all`을 씌우고, 첫 페이지가 front이면 뒤 페이지 전체 띠가 생성되지 않습니다.
+
+근거 / `public/safe/index.html:1774-1784`, `1792-1812`.
+
+수정안 / finding마다 `doc/side`를 저장하고 페이지별로 level·whole-face rule을 적용하십시오. 앞→뒤, 뒤→앞, 동일 문서 2페이지, 혼합 문서 PDF를 모두 테스트해야 합니다.
+
+### 6-5. 테두리 중앙값 배경은 컬러 양식에 취약함
+
+문제 / 가장자리 24점이 테두리·그라데이션·사진 배경이면 잘못된 단일 RGB가 배경이 됩니다. 이후 거의 모든 셀이 ink가 되거나 실제 검은 구조가 배경으로 간주되어 `jpFrameBelow`와 `jpSolidSquares`가 붕괴합니다.
+
+근거 / `public/safe/index.html:1220-1244`, `1334-1347`.
+
+수정안 / 페이지 다영역 색상 클러스터, 로컬 배경, 명도/색차 기반 적응 임계값을 사용하십시오. 어두운 전면·컬러·테두리 있는 합성 fixture가 필요합니다.
+
+## 7. 공개 저장소와 카드 더미
+
+### 7-1. §4 안전조건을 전부 충족하지 않음
+
+문제 / 명백한 위반은 “개별 고해상 카드 파일 공개 배포 금지”와 “법률 검토 전 내부 전용”입니다. 또한 모든 번호가 불일치/규격 외라는 주장도 코드와 맞지 않습니다. `mynumber_invalid()`와 면허번호만 의도적으로 무효화하며, `hokensha()`·記号/番号/枝番·고정 `住民票コード`에는 유효성 부정 로직이 없습니다. 우편번호 `999-99xx`가 실제 미할당임도 검증하지 않습니다.
+
+근거 / `docs/jp/jp_safefile_strategy_v2_2026-10-21.md:95-104`; `test/safe/fixtures/jp/gen.py:29-47`, `69-80`, `91-108`, `199-203`. 실제 번호·주소와 충돌하지 않는다는 증거는 **확인 불가**입니다.
+
+수정안 / 모든 번호군에 문자를 삽입하거나 명시적 무효 검사를 두고, 주소·우편번호도 예약된 비실재 네임스페이스를 사용하십시오. 공개 고해상도 바이너리는 법률 검토 전 제거해야 합니다.
+
+### 7-2. 실질 위험은 낮지만 “0”은 아님
+
+문제 / 워터마크·도식형·인감/실QR 부재 때문에 직접 오용 가치는 낮습니다. 그러나 공개 Git 기록은 영구 복제 가능하고, 일부 번호가 실제 형식이며 고해상도 카드형 이미지라는 점 때문에 편집 재료 가치는 남습니다. 일본 형법상 공문서 위조는 `行使の目的`이 핵심이므로 이 테스트 fixture 자체가 곧 위법이라고 단정할 근거는 없습니다. [刑法 제155조](https://laws.e-gov.go.jp/document?lawid=140AC0000000045_20250601_505AC0000000028)
+
+GitHub 정책도 이 fixture를 명시적으로 금지한다고 확인할 수 없습니다. 다만 불법·사기·기만·사칭 목적 사용은 금지됩니다. [GitHub Acceptable Use](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies?apiVersion=2022-11-28)
+
+근거 / `CLAUDE.md:1646-1665`; 구체적 일본 변호사 검토 결과는 **확인 불가**입니다.
+
+수정안 / “오용 가치 사실상 0” 표현을 삭제하고, 법률·플랫폼 위험을 낮음이지만 미해결로 표기하십시오.
+
+### 7-3. 대안 비교
+
+문제 / 비공개 submodule은 접근권한·CI secret·외부 기여자 재현성이 나빠집니다. 생성 스크립트만 커밋하면 폰트/Pillow 차이로 픽셀 골든이 흔들립니다. 해상도 축소는 OCR·기하 테스트의 의미를 훼손합니다.
+
+근거 / `CLAUDE.md:1656-1664`.
+
+수정안 / 가장 현실적인 순서는 다음입니다.
+
+- 공개 저장소에는 구조 테스트용 저위험 SVG/캔버스 생성 스크립트와 의미 기반 assertions만 유지.
+- 픽셀 골든은 고정 컨테이너 이미지로 결정적으로 생성하고 해시 검증.
+- 꼭 필요한 고해상도 카드 fixture만 비공개 artifact 저장소에서 CI에 주입.
+- 단순 축소본은 문서·마케팅 검토용으로만 사용하고 OCR 골든 대체물로 쓰지 않음.
+
+## 즉시 고쳐야 할 상위 5개
+
+1. **AMBER · 배포 전** — 분류 실패가 무경고로 JP 탐지를 전부 끄는 문제. 실패 경고와 저신뢰 fallback이 필요합니다.
+2. **AMBER · 배포 전** — 레이블 없는 사각형이 candidate임에도 기본 ON인 문제. 얼굴사진·인감 오탐을 기본 출력에 넣습니다.
+3. **AMBER · 배포 전** — 다중 페이지에서 첫 페이지 `doc/side`를 전 페이지에 적용하는 문제. マイナカード 양면 처리 결과가 순서에 따라 반대가 됩니다.
+4. **AMBER · 배포 전** — `その他` 카테고리 OFF로 `back_all`·QR 법적 띠가 조용히 사라지는 문제.
+5. **AMBER · 다음 런 전** — 하네스의 60% 피복, skipped-key 허용, `require_banded` 좌표 미검증. 현재 389/389는 숫자 노출과 오배치를 배제하지 못합니다.
+hook: Stop
+hook: Stop Completed
+tokens used
+155,930
+검토 범위는 커밋 `546344b`의 파일 내용을 `git show`로 직접 읽은 정적 검토입니다. `node run.mjs`도 시도했지만 `127.0.0.1` 서버 바인딩이 `EPERM`으로 차단되어 실행되지 않았습니다. 따라서 `389/389`는 구현자 로그일 뿐, 제가 재현한 결과가 아닙니다.
+
+## 1. 탐지 미탐 위험
+
+### 1-1. 문서 분류 실패 시 무경고로 JP 보호가 전부 사라짐
+
+문제 / `資格確認書`는 제목만 정상 인식되면 3점이라 임계값 4에 못 미칩니다. `保険者番号` 등 추가 키워드 하나가 깨지면 실제 문서가 “一般文書”로 떨어지고 JP 번호 탐지가 전혀 실행되지 않습니다. 사용자는 분류 실패 사실이나 수동 확인 필요성을 알 수 없습니다.
+
+근거 / `public/safe/index.html:1161-1199`, 특히 `資格確認書=3`, `min:4`; `public/safe/index.html:1774-1784`의 `if (!cls) return null`; `public/safe/index.html:2143-2151`은 실패 시 일반 이름·주소 휴리스틱으로 조용히 전환합니다. 실제 보험자별 실패율은 **확인 불가**입니다.
+
+수정안 / 임계 미달이어도 JP 의심 점수·일본 문서 특징이 있으면 “문서 종류를 확인하지 못해 자동 마스킹을 적용하지 않았다”는 차단성 경고를 표시하십시오. `資格確認書` 제목 단독은 최소 candidate scan을 허용하고, 보험자별 실물 익명 샘플로 분류 recall 게이트를 별도로 두어야 합니다.
+
+### 1-2. 고정 세그먼트 간격이 DPI·레이아웃 변화에 취약함
+
+문제 / 레이블 끝과 값 시작의 공백이 `max(90px, 폭×10%)` 이상이면 둘이 분리되어 값 규칙이 미탐됩니다. 반대로 다음 칸과의 간격이 그보다 작으면 두 칸이 합쳐지고, 두 번째 레이블은 세그먼트 선두가 아니어서 미탐됩니다. OCR 렌더 배율과 사진 원근에 따라 같은 서식도 양쪽 실패가 가능합니다.
+
+근거 / `public/safe/index.html:1115-1145`, `public/safe/index.html:1575-1581`, `public/safe/index.html:1601-1609`. 80px/140px 가정은 알파 픽스처 측정뿐입니다.
+
+수정안 / 페이지 폭이 아니라 행 글자 높이와 인접 박스 분포에서 동적 임계값을 구하고, 레이블과 값이 분리된 인접 세그먼트도 동일 행·수직 중첩·최대 거리 조건으로 결합하십시오. 좁은 표에서는 열 경계/괘선을 함께 사용해야 합니다.
+
+### 1-3. 모든 규칙의 `headOnly` 강제가 과도함
+
+문제 / `●`, `※`, 항목번호, 괄호, OCR 잡음 한 글자, 표 셀의 선행 문자가 붙으면 모든 값 레이블이 거부됩니다. 한 각주 오탐을 막기 위해 전체 필드의 recall을 희생합니다.
+
+근거 / `public/safe/index.html:1575-1581`, `public/safe/index.html:1594-1609`. 원래 개별 규칙의 `headOnly` 설정과 무관하게 `.map(... headOnly:true)`로 덮어씁니다.
+
+수정안 / 선두에 허용할 잡음 클래스를 제한하십시오. 예: 공백·`※●○□・(1)①`·1문자 저신뢰 OCR만 건너뛰고, 레이블 이후 값 형식·동일 셀·거리 점수로 확정하십시오. 각주 방지는 “레이블 뒤 필드값 형식 존재”와 문장형 종결 패턴으로 처리해야 합니다.
+
+### 1-4. 숫자 길이 폴백이 비민감 번호를 자동 마스킹함
+
+문제 / `資格確認書`의 모든 독립 6~10자리 숫자가 `hokensha_bango`가 됩니다. 하이픈 없는 우편번호, 압축 날짜, 전화번호, 교부·발행·証明書番号 같은 숫자도 자동 마스킹될 수 있습니다. `一部負担金割合`과 일반적인 `限度額区分`은 보통 해당 길이가 아니지만, 발행·관리번호의 실제 존재와 자릿수는 현재 자료로 **확인 불가**입니다. 후期高齢者용 `資格確認書`에는 실제로 負担割合·交付年月日·適用区分 등이 존재합니다. [旭川市 안내](https://www.city.asahikawa.hokkaido.jp/kurashi/135/171/176/p004497.html)
+
+`住民票`의 11자리 폴백은 하이픈 없는 휴대전화나 증명서 일련번호를 `住民票コード`로, 12자리는 임의 참조번호를 `個人番号` 후보로 오인할 수 있습니다.
+
+근거 / `public/safe/index.html:1655-1691`. 제외 조건은 `[年月日]` 또는 `〒`가 있는 행뿐입니다.
+
+수정안 / `資格確認書` 폴백은 번호가 위치한 셀의 인접 레이블 조각, 번호군 주변 좌표, 보험자 번호 형식/코드체계까지 요구하십시오. `住民票コード`에는 체크디지트와 레이블/열 헤더를 요구하고, `個人番号`는 체크디지트가 실패하면 폴백 자동 경로에서 제외하거나 명확한 수동 검토로 낮추십시오.
+
+### 1-5. `myNumberCheckOk` 계산은 맞지만 법적 출처 표기가 틀림
+
+문제 / 함수 계산 자체는 맞습니다. 다만 주석의 “番号法施行令 別表”는 정확한 근거 위치가 아닙니다. 현재 산식은 관련 명령 제5조의 산식입니다.
+
+근거 / `public/safe/index.html:1202-1211`. 구현은 오른쪽부터 `Pₙ`, `Qₙ=n+1 (n≤6), n−5 (n≥7)`, `11-(합 mod 11)`, 결과 10·11이면 0으로 처리합니다. 정부 원문도 합의 11 나머지가 0 또는 1이면 검사 숫자를 0으로 하므로 동치입니다. [e-Gov 관련 명령 제5조](https://laws.e-gov.go.jp/document?lawid=426M60000008085_20231215_505M60004008017)
+
+수정안 / 로직은 유지하고 주석·법적 매트릭스 출처를 정확한 명령 제5조로 고치십시오. 유효·무효 경계값을 독립 테스트 벡터로 추가해야 합니다.
+
+### 1-6. 世帯員 경계가 실제 양식 변형을 견디지 못함
+
+문제 / 반복되는 `氏名` 레이블이 하나라도 OCR에서 깨지면 해당 세대원 블록이 통째로 남습니다. 반대로 블록 내부의 발행자·증명문이 종료 표현과 일치하지 않으면 마지막 세대원 영역이 페이지 끝까지 확장되어 발행자까지 가릴 수 있습니다. 공통 열 헤더 하나 아래 여러 명을 행으로 나열하는 `世帯連記式`은 `nameRows.length > 1` 조건 자체를 충족하지 않을 수 있습니다.
+
+근거 / `public/safe/index.html:1731-1766`. 실제 지자체는 `世帯連記式`과 `個人票様式`을 모두 사용합니다. [宇都宮市 양식 안내](https://www.city.utsunomiya.lg.jp/kurashi/jumin/koseki/1043547.html). 반복 블록 예시는 `氏名` 외에 `個人番号`, `住民票コード`, `備考`가 각 세대원 블록에 포함됩니다. [大阪市 공식 견본](https://www.city.osaka.lg.jp/toshiseibi/cmsfiles/contents/0000648/648120/syoruininntei.pdf)
+
+수정안 / `氏名` 단일 앵커가 아니라 행 번호, `続柄`, 반복 열 구조, 구분선, 다음 사람 번호를 함께 사용하십시오. 마지막 경계는 발행일·증명문·발행기관 영역을 별도 보호구역으로 먼저 검출하고 그 위에서 강제로 종료해야 합니다.
+
+## 2. 오탐 및 증빙 훼손
+
+### 2-1. `jpFrameBelow`는 사각형이 아니라 평행 가로선 두 개만 검증함
+
+문제 / 표의 상하 괘선이나 외곽선 두 개를 欄으로 오인할 수 있습니다. 세로 변, 내부 영역, 레이블과 프레임의 x관계를 검사하지 않습니다. `jpRowInk`가 행별 가장 긴 런 하나만 반환하므로 실제 작은 欄보다 페이지 전체 표선이 우선됩니다.
+
+근거 / `public/safe/index.html:1234-1267`. 폴백도 실패 시 페이지 폭의 최소 50%, 레이블 높이 3.5배를 덮습니다(`1714-1722`).
+
+수정안 / 좌우 세로선 존재, 모서리 연결, 프레임 내부 포함관계, 레이블 x근접성을 검증하십시오. 한 행의 모든 런을 보존한 뒤 앵커와 가까운 런을 선택해야 합니다.
+
+### 2-2. 레이블 없는 사각형 candidate가 실제로 기본 ON임
+
+문제 / 얼굴사진·검은 인감·정사각 로고·검은 표 헤더는 크기·종횡비·밀도 조건을 만족할 수 있습니다. 특히 채워진 원형 인감은 이론상 경계상자 채움률이 약 0.785라 `fill≥0.75`를 넘을 수 있습니다. 코드 주석은 “candidate, never automatic band”라고 하지만, `recommend` candidate의 기본 mode는 `no`여서 실제 출력에서는 기본으로 가려집니다.
+
+근거 / `public/safe/index.html:1334-1366`, `public/safe/index.html:1796-1801`, `public/safe/index.html:1823-1825`. `labelled:false` → `recommend` → `mode:'no'`.
+
+수정안 / 미검증 `unlabelledCode`는 `optional`, `mode:'ok'`로 두십시오. finder 패턴·quiet zone·모듈 주기 등 QR 고유 특징을 확인하기 전에는 기본 출력에 포함하면 안 됩니다.
+
+### 2-3. 주소 “강한 자동 조건”이 구현되지 않음
+
+문제 / `郵便番号+都道府県`를 `strong:true`로 계산하지만 그 값은 어디에서도 사용하지 않습니다. 따라서 전략의 “동반 시 자동”은 구현되지 않았습니다. `consult_share`에서는 모든 `address_loose`가 강도와 무관하게 권장 ON이고, 다른 목적에서는 모두 optional입니다.
+
+근거 / `public/safe/index.html:1538-1563`, `public/safe/index.html:1694-1710`; `strong` 검색 결과 사용처 없음; `JP_EXTRA`는 `public/safe/index.html:1383-1387`.
+
+수정안 / `strong`을 실제 level 결정에 반영하거나 전략에서 자동 약속을 삭제하십시오. 기관명 감점은 주소 뒤 8자까지만 보므로 더 멀리 붙은 회사명은 감점되지 않습니다. 회사 소재지와 개인 주소 구별에는 `住所変更`, `現住所`, `送付先` 같은 개인 문맥이 추가로 필요합니다.
+
+### 2-4. 15% 패딩은 가까운 이웃 필드를 덮을 수 있음
+
+문제 / 높이 `h`인 두 필드의 간격이 약 `0.3h`보다 작으면 상하 패딩이 겹칩니다. 좌우도 각 필드 경계에서 `0.15h`만큼 침범합니다. 더 큰 문제는 `mergeLineBoxes`가 하나라도 `region:true`이면 합쳐진 전체 라인의 패딩을 제거하여 다른 OCR 박스의 가장자리가 노출될 수 있다는 점입니다.
+
+근거 / `public/safe/index.html:2256-2274`, `public/safe/index.html:2276-2291`.
+
+수정안 / 패딩을 인접 OCR 박스·셀 경계까지 clamp하고, region과 텍스트 박스를 같은 merged line으로 합치지 마십시오. `region:true`의 패딩 제외는 수동 드래그에는 맞지만 자동 검출 프레임까지 같은 신뢰도로 취급하는 것은 부적절합니다.
+
+## 3. 출력 안전성
+
+### 3-1. PDF 바이트 marker 목록은 완전한 검사가 아님
+
+문제 / `/Metadata`, 문서 `/Info`, `/EF`, `/Filespec`, `/OpenAction`, `/AA`, `/JS`, `/Launch`, `/RichMedia`가 빠졌습니다. 문자열 검색은 Flate 압축 스트림과 object stream 내부 이름·문자열도 보지 못합니다. PDF는 간접 객체를 object stream 안에 압축 저장할 수 있습니다. [Adobe PDF 32000-1 §7.5.7](https://developer.adobe.com/document-services/docs/assets/35e4369068f86065372c18787171a17e/PDF_ISO_32000-1.pdf)
+
+근거 / `test/safe/run.mjs:241-257`, `289-305`.
+
+수정안 / qpdf 또는 PDF 파서로 객체 그래프를 풀어 Catalog, Info, Metadata, Names, annotations, actions, file specifications, embedded streams를 검사하십시오. `%%EOF` 개수는 증분 저장 신호일 뿐 완전한 구조 검사가 아닙니다.
+
+### 3-2. 입력 PDF 구조물이 직접 출력되는 경로는 없음
+
+문제 / 입력 주석·첨부·북마크·XMP가 jsPDF 새 문서에 복사되는 경로는 찾지 못했습니다. 이 항목에서 원본 구조 누출 주장은 성립하지 않습니다. 다만 픽셀 자체에 숨겨진 데이터나 육안상 남은 원본은 래스터 재인코딩만으로 제거되지 않습니다.
+
+근거 / `public/safe/index.html:2568-2593`: 원본 페이지를 canvas에 그리고 JPEG data URL만 새 jsPDF에 삽입합니다. jsPDF `addImage`도 Canvas/data URL 입력을 받는 API입니다. [jsPDF addImage 문서](https://parallax.github.io/jsPDF/docs/module-addImage.html)
+
+수정안 / “원본 PDF 객체를 계승하지 않는다”는 논증은 유지하되, 테스트 문구를 “모든 가능한 PDF 누출을 검사한다”가 아니라 “새 래스터 PDF 생성 경로와 출력 객체 allowlist를 검증한다”로 제한하십시오.
+
+### 3-3. ICC 2KB·`dmnd/dmdd` 기준은 신원정보 부재를 증명하지 못함
+
+문제 / 2KB 이하 임의 프로파일도 `desc`, `mluc`, `cprt` 또는 private payload에 장치·사용자 정보를 넣을 수 있고, 디스플레이 프로파일이 반드시 `dmnd/dmdd`를 갖는 것도 아닙니다. 현재 검사는 첫 `ICC_PROFILE`만 보고 분할 APP2 프로파일 전체도 구조적으로 검증하지 않습니다.
+
+근거 / `test/safe/run.mjs:258-270`.
+
+수정안 / 허용할 ICC 프로파일의 전체 바이트 SHA-256 allowlist를 사용하거나 출력 후 ICC를 제거하십시오. “크기+두 태그 부재”를 안전성 경계로 사용하면 안 됩니다.
+
+### 3-4. PNG는 네 청크만 금지하여 임의 보조 청크를 놓침
+
+문제 / `iCCP`, `tIME`, `sPLT` 및 private ancillary chunk에도 데이터가 실릴 수 있습니다. PNG 규격은 private·unknown ancillary chunk를 명시적으로 허용합니다. [W3C PNG 규격](https://www.w3.org/TR/png/)
+
+근거 / `test/safe/run.mjs:241-245`.
+
+수정안 / PNG 청크를 구조적으로 파싱하여 `IHDR`, 필요한 색공간 청크, `IDAT`, `IEND`의 allowlist만 허용하십시오. 적어도 모든 ancillary/private chunk의 목록과 payload 크기를 검증해야 합니다.
+
+## 4. 목적 게이트와 법적 매트릭스
+
+### 4-1. `JP_RULES`는 정본과 일치하지 않음
+
+문제 / 주요 불일치는 다음과 같습니다.
+
+- `JP_EXTRA(address_loose/tel)`는 법적 정본에 전혀 없습니다.
+- `資格確認書`의 keep 항목을 모든 목적에 적용하며 `事業所名称`, `保険者名`, `資格取得年月日`까지 추가합니다.
+- `運転免許証番号`은 정본상 `identity_submit`에서 must-keep인데 구현은 모든 목적 optional입니다.
+- `マイナンバーカード`의 `my_number`, `qr` 개별 gate는 정본의 `裏面全体` 규칙을 코드에서 분해해 추가한 것입니다.
+- `住民票`의 keep은 정본상 `identity_submit`, `bid_attachment`인데 구현은 모든 목적입니다.
+- 정본의 `発行日・発行者`는 검출 규칙이 없어 keep 경고가 실제로 생성되지 않습니다.
+- `住民票コード`는 정본에서 `verified:false`인데 자동 마스킹됩니다.
+
+근거 / `test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:16-57`; `public/safe/index.html:1381-1431`, `1450-1503`.
+
+수정안 / 사람이 작성한 두 번째 표가 아니라 legal matrix JSON을 빌드 시 변환해 단일 소스로 사용하십시오. `verified:false`는 자동 level을 금지하는 검증 규칙을 추가해야 합니다.
+
+### 4-2. 미명시 목적을 항상 `optional`로 만드는 폴백은 잘못됨
+
+문제 / `return r.keep ? 'optional' : 'optional'`은 조건문이 무의미하며, 매트릭스가 의도적으로 명시하지 않은 조합과 “선택 제공”을 구별하지 못합니다. 특히 `資格確認書` 번호군은 `my_number_procedure`에서 optional로 노출되지만, 해당 목적이 의료보험 관련 개인번호 사무인지에 따라 번호가 필요한 예외가 존재할 수 있습니다. 구체적 업무 조합은 **확인 불가**입니다. 厚労省도 건강보험 사무 또는 관련 사무에는 고지 제한 예외가 있음을 명시합니다. [厚労省](https://www.mhlw.go.jp/stf/newpage_13989.html)
+
+근거 / `public/safe/index.html:1433-1441`.
+
+수정안 / 미명시는 `null`로 두고 UI에 내지 마십시오. 명시적으로 `optional`인 경우만 optional을 반환하도록 매트릭스에 목적별 상태를 완전 열거해야 합니다.
+
+### 4-3. `本籍`/`筆頭者` 확장은 법적 근거가 없음
+
+문제 / 근거가 “필요 없어 보인다”와 픽스처 기대값뿐이라 순환 논증입니다. `my_number_procedure`·`bid_attachment`의 모든 하위 업무에서 불필요하다는 출처가 없습니다.
+
+근거 / `public/safe/index.html:1377-1380`, `1426-1427`; `docs/jp/s3_report.md:239-242`.
+
+수정안 / 법적 정본을 바꾸기 전에는 해당 두 목적을 optional로 두십시오. 실제 제출처 요구사항 또는 공식 지침을 목적별로 확보한 뒤 recommend로 승격해야 합니다.
+
+### 4-4. マイナカード裏面 안내는 지나치게 단정적임
+
+문제 / 身元確認 목적으로 뒷면을 복사·보관하면 제한 위반 가능성이 있으므로 앞면 제출 안내는 타당합니다. 다만 단순히 보았다는 것까지 불법인 것은 아니므로 “番号法により…できません”은 행위·주체·예외를 생략합니다. `個人番号手続` 선택만으로 모든 수령처가 적법한 개인번호 이용사무 수행자임을 확인할 수도 없습니다.
+
+근거 / `public/safe/index.html:1804-1812`; PPC는 의도치 않게 본 것과 복사·기록을 구별합니다. [PPC FAQ Q6-12](https://www.ppc.go.jp/all_faq_index/faq5-q6-12/)
+
+수정안 / “법정 개인번호 사무를 수행하는 제출처에 한해 해제” 확인을 추가하고, 단순 목적 드롭다운만으로 전면 해제하지 마십시오.
+
+### 4-5. keep을 가릴 수 있게 둔 것은 법 위반이 아니라 제출 유효성 문제
+
+문제 / 모든 keep 필드를 법적으로 차단해야 한다는 근거는 없습니다. 그러나 `my_number_procedure`의 個人番号처럼 목적 자체가 성립하지 않는 필드까지 일괄 비공개할 수 있어, 사용자가 “해당 목적용 안전 파일”이라고 오해할 수 있습니다.
+
+근거 / `public/safe/index.html:2494-2506`. 법적 차단 필요성은 **확인 불가**입니다.
+
+수정안 / 일반 keep은 경고 유지, 목적의 핵심 필드는 “강제 유지” 또는 최종 확인 대화상자로 분리하십시오. 최소한 목적 적합성 상태를 실패로 표시해야 합니다.
+
+### 4-6. `その他` 토글이 법적 띠를 무조건 해제함
+
+문제 / `back_all`과 `qr`가 `other`에 매핑되고 `isOn`은 카테고리 boolean만 봅니다. 사용자가 その他를 끄면 マイナカード裏面 전체와 資格確認書 QR 띠가 출력에서 사라집니다. 별도 강한 경고도 없습니다.
+
+근거 / `public/safe/index.html:1831-1834`, `751-777`, `2320-2329`, `2480-2482`.
+
+수정안 / 법적 preset 엔티티는 일반 카테고리 토글에서 분리하십시오. 해제는 개별 항목과 목적별 확인을 거치게 하고, 하네스도 카테고리 OFF 상태에서 법적 띠가 유지되는지 검증해야 합니다.
+
+## 5. 하네스 유효성
+
+### 5-1. `jp_auto_fields`는 목적·검증 상태를 표현하지 못함
+
+문제 / 문서별 정적 배열이라 목적별 `auto/gate/keep` 차이를 나타내지 못합니다. `住民票コード`의 `verified:false`도 무시됩니다. 앱과 하네스가 같은 잘못된 해석을 공유할 수 있습니다.
+
+근거 / `test/safe/specs.json:83-90`; `test/safe/run.mjs:430-496`.
+
+수정안 / legal matrix JSON에서 `(doc, field, purpose)`별 기대 level을 직접 계산하고, 정적 중복표를 제거하십시오.
+
+### 5-2. 유효 個人番号 자동 띠가 전혀 검증되지 않음
+
+문제 / `JP_MASK_OR_CAND`는 잘못된 체크디지트 더미가 candidate만 되어도 통과합니다. 유효 체크디지트가 `auto/gate`가 되는 테스트는 없습니다.
+
+근거 / `test/safe/specs.json:90-91`; `test/safe/run.mjs:423-425`, `495-496`; 생성기는 모두 무효 번호만 만듭니다(`gen.py:35-45`).
+
+수정안 / 실물과 무관한 텍스트/캔버스 유닛 픽스처로 유효 체크디지트 번호를 생성하여 `checkOk:true`, 자동 띠, 목적 전환 해제를 각각 검증하십시오. 공개 카드 이미지에 유효 번호를 넣을 필요는 없습니다.
+
+### 5-3. 60% 피복은 판독 불가를 보장하지 않음
+
+문제 / 한 OCR word의 60%만 덮고 나머지 40%에 여러 숫자가 그대로 남아도 통과합니다. 구현자 스스로 96% 피복인데 첫 숫자가 노출된 사례를 기록했으므로 현재 기준의 부적합성이 이미 입증되었습니다.
+
+근거 / `test/safe/run.mjs:404-424`; `docs/jp/s3_report.md:207-212`.
+
+수정안 / 숫자 필드는 각 문자 또는 잉크 연결요소가 100%+허용 오차로 덮이는지 검사하십시오. 출력 이미지에 대해 OCR 재검사와 픽셀 차분을 병행해야 합니다.
+
+### 5-4. `geometry:false`가 가장 어려운 입력의 오배치를 숨김
+
+문제 / JPG 세 건과 목적 교차 한 건은 field와 mode만 검사합니다. 완전히 엉뚱한 위치의 띠, 빈 박스, 카테고리 OFF 상태도 통과할 수 있습니다.
+
+근거 / `test/safe/specs.json:113-116`, `145-153`; `test/safe/run.mjs:448-465`. `require_banded`는 `mode !== 'ok'`만 봅니다.
+
+수정안 / 회전·원근 변환 행렬을 픽스처에 기록하거나 출력 이미지의 알려진 민감 문자열/영역을 OCR·픽셀 기준으로 검사하십시오.
+
+### 5-5. 공허한 단언 경로가 남아 있음
+
+문제 / 다음 경로가 공허하거나 약합니다.
+
+- absent box는 `skipped`로 기록만 하고, 다른 박스 하나만 검사하면 `JP_COVERAGE > 0` 통과.
+- `P.keep === 'all'`이면 keep 검사를 아예 빈 배열로 만듦.
+- `require_banded`는 좌표·located·`isOn`을 확인하지 않음.
+- `JP_CLEAR`도 위치와 실제 출력 피복을 확인하지 않음.
+- `__candidateOver`는 주석과 달리 candidate의 활성 상태나 mode를 확인하지 않음.
+
+근거 / `test/safe/run.mjs:111-119`, `453-465`, `473-500`.
+
+수정안 / 기대 키 누락을 즉시 실패시키고 `checked === expectedExistingCount`를 요구하십시오. field 단언은 실제 `__maskRects`와 교차하도록 바꾸고 `keep:'all'`은 모든 box를 열거해 검사해야 합니다.
+
+### 5-6. `max_auto`는 오탐 종류를 제한하지 못함
+
+문제 / kenpo 실측 5에 상한 8, kouki 실측 3에 상한 8이면 각각 3개·5개의 신규 오탐이 생겨도 통과합니다. 올바른 엔티티가 빠지고 잘못된 엔티티가 대신 생겨 총수만 같아도 통과합니다.
+
+근거 / `test/safe/specs.json:94-104`; 실측값은 `docs/jp/s3_report.md:201-202`.
+
+수정안 / 총수 상한을 보조 지표로만 두고 필드·좌표별 allowlist와 “예상하지 않은 자동 엔티티 0” 단언을 추가하십시오.
+
+## 6. 커버리지 없는 구현
+
+### 6-1. 레이블 없는 QR 완화가 충분하지 않음
+
+문제 / candidate로 낮췄지만 기본 ON이므로 완화가 실패했습니다.
+
+근거 / `public/safe/index.html:1823-1825`, `1796-1801`.
+
+수정안 / 실제 QR fixture가 생기기 전까지 optional·기본 OFF로 고정하십시오.
+
+### 6-2. 電話·FAX 테스트가 통합 경로를 검증하지 않음
+
+문제 / 유닛은 정규식만 직접 호출하며 `jpFindLabel → jpBoxes → jpApply`를 지나지 않습니다.
+
+근거 / `test/safe/run.mjs:524-532`.
+
+수정안 / 합성 canvas/PDF에 레이블과 번호를 분리 배치해 세그먼트·좌표·mode까지 검증하십시오.
+
+### 6-3. 주소 자동 분기는 “미검증”이 아니라 사실상 미구현
+
+문제 / `strong`이 사용되지 않아 실제 문서뿐 아니라 코드상으로도 자동 승격이 없습니다.
+
+근거 / `public/safe/index.html:1709`; 사용처 없음.
+
+수정안 / 전략과 구현 중 하나를 일치시키고 그 경로를 통합 테스트하십시오.
+
+### 6-4. 다중 페이지는 단순 상속보다 더 위험함
+
+문제 / 페이지별로 다른 `c`로 추출하면서 `jpApply`는 1페이지 `cls.doc/side` 규칙만 적용합니다. マイナカード 앞·뒤 양면 PDF에서 첫 페이지가 back이면 모든 페이지에 `back_all`을 씌우고, 첫 페이지가 front이면 뒤 페이지 전체 띠가 생성되지 않습니다.
+
+근거 / `public/safe/index.html:1774-1784`, `1792-1812`.
+
+수정안 / finding마다 `doc/side`를 저장하고 페이지별로 level·whole-face rule을 적용하십시오. 앞→뒤, 뒤→앞, 동일 문서 2페이지, 혼합 문서 PDF를 모두 테스트해야 합니다.
+
+### 6-5. 테두리 중앙값 배경은 컬러 양식에 취약함
+
+문제 / 가장자리 24점이 테두리·그라데이션·사진 배경이면 잘못된 단일 RGB가 배경이 됩니다. 이후 거의 모든 셀이 ink가 되거나 실제 검은 구조가 배경으로 간주되어 `jpFrameBelow`와 `jpSolidSquares`가 붕괴합니다.
+
+근거 / `public/safe/index.html:1220-1244`, `1334-1347`.
+
+수정안 / 페이지 다영역 색상 클러스터, 로컬 배경, 명도/색차 기반 적응 임계값을 사용하십시오. 어두운 전면·컬러·테두리 있는 합성 fixture가 필요합니다.
+
+## 7. 공개 저장소와 카드 더미
+
+### 7-1. §4 안전조건을 전부 충족하지 않음
+
+문제 / 명백한 위반은 “개별 고해상 카드 파일 공개 배포 금지”와 “법률 검토 전 내부 전용”입니다. 또한 모든 번호가 불일치/규격 외라는 주장도 코드와 맞지 않습니다. `mynumber_invalid()`와 면허번호만 의도적으로 무효화하며, `hokensha()`·記号/番号/枝番·고정 `住民票コード`에는 유효성 부정 로직이 없습니다. 우편번호 `999-99xx`가 실제 미할당임도 검증하지 않습니다.
+
+근거 / `docs/jp/jp_safefile_strategy_v2_2026-10-21.md:95-104`; `test/safe/fixtures/jp/gen.py:29-47`, `69-80`, `91-108`, `199-203`. 실제 번호·주소와 충돌하지 않는다는 증거는 **확인 불가**입니다.
+
+수정안 / 모든 번호군에 문자를 삽입하거나 명시적 무효 검사를 두고, 주소·우편번호도 예약된 비실재 네임스페이스를 사용하십시오. 공개 고해상도 바이너리는 법률 검토 전 제거해야 합니다.
+
+### 7-2. 실질 위험은 낮지만 “0”은 아님
+
+문제 / 워터마크·도식형·인감/실QR 부재 때문에 직접 오용 가치는 낮습니다. 그러나 공개 Git 기록은 영구 복제 가능하고, 일부 번호가 실제 형식이며 고해상도 카드형 이미지라는 점 때문에 편집 재료 가치는 남습니다. 일본 형법상 공문서 위조는 `行使の目的`이 핵심이므로 이 테스트 fixture 자체가 곧 위법이라고 단정할 근거는 없습니다. [刑法 제155조](https://laws.e-gov.go.jp/document?lawid=140AC0000000045_20250601_505AC0000000028)
+
+GitHub 정책도 이 fixture를 명시적으로 금지한다고 확인할 수 없습니다. 다만 불법·사기·기만·사칭 목적 사용은 금지됩니다. [GitHub Acceptable Use](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies?apiVersion=2022-11-28)
+
+근거 / `CLAUDE.md:1646-1665`; 구체적 일본 변호사 검토 결과는 **확인 불가**입니다.
+
+수정안 / “오용 가치 사실상 0” 표현을 삭제하고, 법률·플랫폼 위험을 낮음이지만 미해결로 표기하십시오.
+
+### 7-3. 대안 비교
+
+문제 / 비공개 submodule은 접근권한·CI secret·외부 기여자 재현성이 나빠집니다. 생성 스크립트만 커밋하면 폰트/Pillow 차이로 픽셀 골든이 흔들립니다. 해상도 축소는 OCR·기하 테스트의 의미를 훼손합니다.
+
+근거 / `CLAUDE.md:1656-1664`.
+
+수정안 / 가장 현실적인 순서는 다음입니다.
+
+- 공개 저장소에는 구조 테스트용 저위험 SVG/캔버스 생성 스크립트와 의미 기반 assertions만 유지.
+- 픽셀 골든은 고정 컨테이너 이미지로 결정적으로 생성하고 해시 검증.
+- 꼭 필요한 고해상도 카드 fixture만 비공개 artifact 저장소에서 CI에 주입.
+- 단순 축소본은 문서·마케팅 검토용으로만 사용하고 OCR 골든 대체물로 쓰지 않음.
+
+## 즉시 고쳐야 할 상위 5개
+
+1. **AMBER · 배포 전** — 분류 실패가 무경고로 JP 탐지를 전부 끄는 문제. 실패 경고와 저신뢰 fallback이 필요합니다.
+2. **AMBER · 배포 전** — 레이블 없는 사각형이 candidate임에도 기본 ON인 문제. 얼굴사진·인감 오탐을 기본 출력에 넣습니다.
+3. **AMBER · 배포 전** — 다중 페이지에서 첫 페이지 `doc/side`를 전 페이지에 적용하는 문제. マイナカード 양면 처리 결과가 순서에 따라 반대가 됩니다.
+4. **AMBER · 배포 전** — `その他` 카테고리 OFF로 `back_all`·QR 법적 띠가 조용히 사라지는 문제.
+5. **AMBER · 다음 런 전** — 하네스의 60% 피복, skipped-key 허용, `require_banded` 좌표 미검증. 현재 389/389는 숫자 노출과 오배치를 배제하지 못합니다.
diff --git a/docs/jp/s3b_report.md b/docs/jp/s3b_report.md
new file mode 100644
index 0000000..bc87933
--- /dev/null
+++ b/docs/jp/s3b_report.md
@@ -0,0 +1,361 @@
+# SafeFile JP-1 S3b — Codex 지적 반영 (배포 차단 4건 + 정본 일치 + 하네스 강화)
+
+날짜 2026-10-21 · 브랜치 `main` · **미배포 · 프로덕션 DB 미접촉**
+입력 [`codex_review_s3_2026-10-21.md`](codex_review_s3_2026-10-21.md) · 직전 [`s3_report.md`](s3_report.md)
+법적 정본 [`test/safe/fixtures/jp/jp_legal_matrix_alpha4.json`](../../test/safe/fixtures/jp/jp_legal_matrix_alpha4.json) (v2026-10-21b)
+
+**골든 389 → 484, 0 실패.** 매트릭스 대조 188 triple 일치. SW 하네스 **9/9** 유지.
+
+---
+
+## 0. 한 줄 요약
+
+> 이번 라운드가 닫은 것은 **「검출은 맞았는데 출력에서 조용히 사라지거나, 조용히 더 지워지는」 경로**다.
+> 분류 실패가 무경고로 보호를 꺼버리던 것, カテゴリ 토글 하나가 법적 띠를 지우던 것,
+> 페이지 순서가 양면 카드의 결과를 뒤집던 것, 검증 안 된 사각형이 기본으로 픽셀을 지우던 것.
+> 네 건 모두 **밖에서 보면 정상 동작과 구별되지 않는다** — 그래서 네 건 모두 하네스로 고정했고,
+> 고치기 전 코드를 실제로 넣어 **그 하네스가 빨개지는 것까지 확인**했다.
+
+---
+
+## 1. 필수 수정 4건 (배포 차단 해제 조건)
+
+### 1-1 [Codex 1-1] 분류 실패가 무경고로 JP 보호를 전부 끄던 문제
+
+`資格確認書` 는 제목만 읽히면 3점, 임계는 4점이다. 라벨 하나가 OCR 에서 깨지면 문서는
+「一般文書」로 떨어지고 **일본 규칙이 하나도 실행되지 않은 채** 라틴 이름·주소 휴리스틱으로
+조용히 넘어갔다. 사용자는 그 사실을 알 길이 없었다.
+
+분류 결과를 **두 가지**로 나눴다. 하나는 `confident`(score ≥ min, 지금까지의 동작),
+다른 하나는 **`low`** — 그 문서의 **제목**은 읽혔지만 점수가 모자란 상태다.
+
+| | 분류 | 자동 띠 | 경고 배너 |
+|---|---|---|---|
+| score ≥ min | 확정 | 매트릭스대로 | 없음 |
+| score < min **이고 제목 일치** | `low` (candidate scan only) | **전부 recommend 로 강등** | **표시** |
+| 그 미만 + 일본 공문서 특징 있음 | 없음 | 없음 | **표시(차단성)** |
+| 그 미만 + 특징 없음 | 없음 | 없음 | 없음 |
+
+- 「일본 공문서 특징」 = `資格確認書|免許証|個人番号|マイナンバー|住民票|令和|平成|昭和` (`JP_SUSPECT_RE`).
+  **분류가 아니라 경고의 방아쇠**다 — 이 정규식이 하는 유일한 일은 "자동 마스킹이 돌지 않았다"고
+  말할지 말지를 정하는 것이다.
+- 배너 문구(4개 언어): 「文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を
+  選択してください。」 ko/en/es 에는 같은 뜻의 자국어 문장을 괄호로 덧붙였다 — 일본 문서를 다루는
+  한국·영어권 사용자가 실제 사용자다.
+- 배너는 `jpBar` 와 **독립**이다. 존재 이유가 "분류가 없어서 바가 안 뜨는 경우"에 보이는 것이기 때문.
+- 스타일은 힌트가 아니라 **정지 신호**로 했다(좌측 5px 굵은 테두리 · `--no` 색 · 700).
+
+**하네스**: `jp_warn` 4 케이스 (제목 단독 → `low`+경고 / 和暦만 → 경고 / 일본어 특징 없음 → 경고 없음 /
+완전한 資格確認書 → 경고 없음). `low` 케이스는 **jp 자동 엔티티가 0인 것까지** 단언한다.
+
+### 1-2 [Codex 2-2 · 6-1] 레이블 없는 사각 블록이 기본 출력에서 가려지던 문제
+
+코드 주석은 "candidate, never automatic band" 라고 적고 있었지만, `recommend` 의 기본 mode 는
+`no` 다 — **주석과 동작이 반대**였다. 얼굴사진·채워진 원형 인감(경계상자 채움률 ≈ 0.785)·검은 표
+헤더가 전부 크기·종횡비·밀도 조건을 통과할 수 있고, 알파 더미에는 진짜 QR 이 없어(전략 v2 §4)
+**이 경로는 골든 커버리지가 0이다.**
+
+→ `unlabelledCode` 는 레벨과 무관하게 **`optional` / mode `ok`** 로 고정했다.
+검증 안 된 추측이 기본 출력에서 내용을 지우지 않는다.
+
+**실측으로 드러난 것**: `mynumber_card/back` 의 二次元コード 는 실제로 **레이블이 읽히지 않아**
+이 경로를 탄다(같은 그림을 쓰는 `資格確認書` 3종은 레이블이 읽혀 자동 띠). 즉 이 분기는 픽스처에서
+실행된다. 뒷면은 `back_all` 이 면 전체를 덮으므로 결과는 바뀌지 않는다 — §5 잔여 위험에 적었다.
+
+**하네스**: `jp_unlabelled_block` — 주입된 finding 이 `optional`/`ok`/기본 출력 피복 ≤10% 임을 단언하고,
+**같은 페이지의 레이블 있는 코드는 여전히 띠인 것**을 함께 단언한다(아무것도 안 가려서 통과하는 것을 막는다).
+
+### 1-3 [Codex 6-4] 다중 페이지에서 첫 페이지가 전 페이지의 규칙을 정하던 문제
+
+`jpExtract` 는 페이지별로 분류했지만 `jpApply` 는 1페이지의 `cls.doc/side` 로 전부 판정했다.
+양면 카드를 한 PDF 로 스캔하면 **순서가 결과를 뒤집는다**:
+
+| 순서 | 수정 전 | 수정 후 |
+|---|---|---|
+| 表 → 裏 | 裏面 에 띠 **없음** (個人番号 노출) | 裏(p1)만 전면 띠 |
+| 裏 → 表 | **表까지** 전면 띠 | 裏(p0)만 전면 띠 |
+
+- finding 마다 `doc`·`side`·`page` 를 저장하고, `jpState.pageCls[]` 를 둔다.
+- 전면 띠(`back_all`)는 **그 페이지가 실제로 裏面인 페이지마다** 건다.
+- 분류 불가 페이지는 **1페이지에 분류가 있을 때만** 1페이지 규칙을 상속한다.
+
+**하네스**: `jp/2page` — 커밋된 단면 PNG 2장으로 **런타임에** 2페이지 PDF 를 만들어(`out/gen/`,
+비커밋) 양쪽 순서를 돌린다. 페이지별 doc/side · `back_all` 이 걸린 페이지 번호 · 뒷면 피복 ≥99% ·
+앞면 피복 ≤60% 를 단언한다.
+> 부수로 하네스 결함 하나를 잡았다: `pages.length > 0` 은 **"로드 완료"가 아니다**. 페이지는 한 장씩
+> push 되므로 2페이지 OCR 문서에서는 2페이지가 아직 Tesseract 안에 있을 때 true 가 되고,
+> 그 뒤 측정값은 전부 **문서 절반**을 설명한다. 완료 신호를 `#docWrap` 노출로 바꿨다.
+
+### 1-4 [Codex 4-6] 일반 카테고리 토글이 법적 띠를 조용히 해제하던 문제
+
+`back_all`·`qr` 는 타입이 `other` 다. 사용자가 「その他」 체크를 끄면 **マイナカード裏面 전체 띠와
+資格確認書 QR 띠가 출력에서 사라진다.** 경고도 없다.
+
+- 엔티티에 `legal` 플래그를 두고 `isOn` 이 **카테고리를 보지 않게** 했다.
+  `const isOn = e => e.legal ? true : catEnabled[e.type] !== false;`
+- 법적 preset 은 **「法令・提出先ルール」 전용 그룹**(⚖️, 붉은 좌측 테두리)에 모아 카테고리 그룹에서
+  꺼냈다. 해제는 **개별 항목에서만** 가능하고 해제하면 경고 토스트가 뜬다.
+- 카테고리 세그먼트 버튼(타입 단위 일괄)과 **전체 공개** 버튼은 법적 띠를 건드리지 않는다.
+  **전체 비공개**는 건드린다 — 그 방향은 피복을 늘리기만 한다.
+- 대상: `back_all · qr · my_number · jumin_code · hokensha_bango · kigo · bango · edaban · hihokensha_bango`.
+
+**하네스**: `require_legal` — **모든 카테고리를 끈 상태**에서 해당 필드의 띠가 살아 있는지
+(`located ∧ on ∧ mode≠ok ∧ __maskRects 교차`) 단언한다.
+
+---
+
+## 2. 정본 일치 (Codex 4-1 ~ 4-4, 5-1)
+
+### 2-1 `check_matrix.mjs` — 두 번째 손으로 쓴 표를 테스트로 묶었다
+
+페이지는 빌드 단계가 없는 단일 정적 파일이라 `JP_RULES` 는 JSON 정본의 **손으로 쓴 거울**이다.
+손으로 쓴 두 번째 표는 어긋나기 마련이고(Codex 가 7건을 찾았다), 그래서 어긋남을 **읽기 과제가 아니라
+테스트 실패**로 만들었다:
+
+1. JSON 에서 `(doc, field, purpose) → level` 을 파생한다,
+2. `index.html` 에서 `JP_RULES`·`jpLevel`·`JP_LEGAL_FIELDS` 를 **잘라내 실행**한다,
+3. 두 표 중 **어느 쪽에라도 있는** 모든 triple 을 대조한다 (188개),
+4. 불변식 **`verified:false ⇒ auto·gate 금지`** 를 JSON 에 강제한다,
+5. 비교 횟수가 100 미만이면 **추출이 깨진 것으로 보고 실패**시킨다 (공허한 통과 방지).
+
+`run.mjs` 가 맨 먼저 호출한다 — 표가 어긋난 채로 골든이 초록일 수 없다.
+**실효성 확인**: `jumin_code` 를 `auto` 로 되돌려 넣으니 3건 불일치로 exit 1.
+
+### 2-2 매트릭스 스키마 확장
+
+| 추가 | 왜 |
+|---|---|
+| `fields: [코드 필드 키]` | 사람이 읽는 필드명(「保険者番号・記号・番号・枝番・被保険者番号」)과 코드 키를 기계적으로 잇는다. 정본이 분해 방식까지 소유한다 |
+| `optional_when: [purpose]` | 「법적 주장 없이 UI 로만 제공」을 명시적으로 쓴다. 코드 폴백이 아니라 데이터다 |
+| `gate_requires_confirmation` | 個人番号 해제가 드롭다운만으로 되지 않는다는 사실을 정본에 적는다 |
+| `_schema.derivation` / `.invariant` | 파생 규칙과 불변식을 표 옆에 둔다 — `check_matrix.mjs` 가 구현이고 이쪽이 명세다 |
+
+### 2-3 레벨 변경 (요청받은 대로 + 근거)
+
+| 문서 | 필드 | 전 | 후 | 근거 |
+|---|---|---|---|---|
+| 運転免許証 | `license_no` | 전 목적 `optional` | `identity_submit`=**keep**, `consult_share`=`optional`, 나머지 **null** | 정본의 `must_keep_when:[identity_submit]` 그대로 |
+| 住民票 | `jumin_code` | `auto` | **`recommend`** | 정본 `verified:false`. 출처 없는 규칙은 자동이 될 수 없다. **기본 ON 은 그대로** — 띠의 세기는 안 변하고 「auto」라고 부르지 않을 뿐 |
+| 住民票 | `honseki`·`hittosha` | 전 목적 `recommend` | `identity_submit`·`consult_share`=`recommend`, `my_number_procedure`·`bid_attachment`=**`optional`** | 그 두 목적에서 불필요하다는 출처가 없다 |
+| 住民票 | `setaiin` | 2목적 recommend + 폴백 optional | 위와 동일하게 명시 | 폴백이 아니라 명시 |
+| 資格確認書 | `jigyosho`·`hokensha_name`·`shikaku_date` | 코드에만 있던 keep | 정본에 **`verified:false` keep 으로 편입** + **탐지 규칙 신설** | Codex 4-1 「구현이 정본에 없는 항목을 추가함」. 숨기는 대신 정본에 적고 출처 없음을 표기했다. 탐지 규칙이 없어 **keep 경고가 생길 수 없던 죽은 규칙**이었으므로 규칙도 함께 넣었다 |
+| 4문서 공통 | 本人特定事項 | `keep: P_ALL` | `keep: [해당 목적]`, `optional: [consult_share]` | 相談用共有 에는 제출처 요건이 없다. 정본이 침묵하면 **UI 에 내지 않는 것**이 기본인데(아래), 그러면 상담 공유에서 자기 이름을 가릴 수단이 사라진다 → 정본에 `optional_when` 으로 **명시**했다(출처 없음·자동 불가) |
+| 4문서 공통 | `address_loose`·`tel` | 코드에만 있던 `JP_EXTRA` | 정본 **`general_jp` 섹션**으로 편입 | Codex 4-1 「법적 정본에 전혀 없음」 |
+
+### 2-4 [Codex 4-2] 미명시 조합은 `null` — UI 에 내지 않는다
+
+`return r.keep ? 'optional' : 'optional'` 은 조건이 무의미했고, 매트릭스가 **의도적으로 침묵한 조합**과
+「선택 제공」을 구별하지 못했다. 이제 `jpLevel` 은 **어느 목록에도 없으면 `null`** 을 돌려주고
+`jpApply` 가 그 finding 을 건너뛴다. 「침묵은 허가가 아니다」.
+
+### 2-5 [Codex 4-4] マイナ裏面 안내 완화 + 확인 체크박스
+
+문구를 4개 언어에서 바꿨다 — 「~できません」(행위·주체·예외 생략) → 복사·보관의 **제한**과
+**제출처 조건**을 말한다:
+
+> 身元確認が目的なら表面のみ提出してください。番号法上、法令で認められた事務以外で個人番号を
+> 複写・保管することは制限されています。「個人番号手続」は、提出先が法定の個人番号関係事務を
+> 行う場合にのみ選んでください。
+
+그리고 **드롭다운만으로는 해제되지 않게** 했다. `個人番号手続` 선택 + **확인 체크박스 1개**
+(「提出先が法定の個人番号関係事務を行うことを確認しました。」)가 모두 있어야 `back_all`·`my_number`·`qr`
+의 띠가 풀린다. 미확인 상태에서는 레벨이 `keep` → **`gate`** 로 되돌아가 띠가 유지된다
+(note `mn_unconfirmed`). 목적을 바꾸면 체크는 **항상 초기화**된다 — 이전 목적에서 켜둔 체크는
+이번 목적의 확인이 아니다.
+
+**하네스**: 같은 문서·같은 목적으로 **두 케이스**를 둔다 — 확인 ✓(keep·clear) / 확인 ✗(gate·banded).
+한쪽만으로는 게이트가 움직인다는 것도, 안 움직인다는 것도 증명되지 않는다.
+
+### 2-6 [Codex 1-5] 체크디지트 출처 정정 + 경계 벡터
+
+산식은 옳았고 **출처 표기만 틀렸다**(「番号法施行令 別表」). 정확한 근거는
+**e-Gov 관련 명령 제5조**(`426M60000008085_20231215_505M60004008017`)다. 주석에 링크와 함께
+"2026-10-21 이전 인용이 틀렸다"는 사실을 남겼다 — 틀린 인용을 조용히 지우면 다음 사람이
+같은 출처를 다시 찾는다. 省令 은 「나머지가 0 또는 1 이면 검사숫자 0」으로 쓰는데 구현의
+`chk ≥ 10 → 0` 과 **동치**임을 주석에 적고, **그 두 경계를 테스트 벡터로** 넣었다.
+
+---
+
+## 3. 하네스 강화 (Codex 5-2 · 5-3 · 5-5 · 5-6)
+
+### 3-1 숫자 필드는 피복률이 아니라 **잉크 연결요소**로 본다 [5-3]
+
+60% 는 **얼마나** 가렸는지만 말하고 **어디를** 가렸는지는 말하지 않는다. 직전 라운드가 스스로
+기록한 사례가 바로 그것이다 — `保険者番号` 피복 **96%**, 선두 숫자는 띠 **밖**.
+
+→ `保険者番号계열 · 個人番号 · 住民票コード · 免許証番号` 는 기대 박스 안의 잉크를
+**연결요소로 라벨링**해 **모든 성분이 99% 이상 덮였는지** 본다. 성분이 **0개면 실패** —
+숫자 박스에 잉크가 없을 리 없고, 0개를 통과시키면 그 단언은 공허하다.
+임계는 탐지기의 40 이 아니라 **60** 을 쓴다: 픽스처의 見本 워터마크는 합성 후 배경에서 약 48 떨어져
+있고, 띠가 워터마크까지 덮을 의무는 없다.
+
+**실효성 확인**: `ocrCanvas` 의 `w.text.trim()` 을 제거해 **실제로 기록된 그 결함**을 되살리니
+`JP_INK — hihokensha_bango (8 comp, worst 74%)` 로 실패했다. 같은 상태에서 60% 게이트는 통과한다.
+
+### 3-2 기대 키가 픽스처에 없으면 **FAIL** [5-5]
+
+「variant 에 없는 키는 skipped 로 보고」는 **초록 총계 옆의 아무도 안 읽는 한 줄**이었다.
+이제 `JP_SPEC` 실패다. 대신 **variant 별 기대표를 실제로 맞췄다** — `gen.py` 의 `finalize()` 가
+해당 variant 의 boxes 로 purpose 목록을 **가지치기**하고, 기존 5건(kenpo/kokuho 의 `hihokensha_bango`,
+kokuho/kouki 의 `jigyosho`, kouki 의 `kigo/bango/edaban`)을 정리했다.
+
+### 3-3 `keep: "all"` 은 전 박스를 열거한다 [5-5]
+
+빈 배열로 치환하면 **표에서 가장 강한 약속이 유일하게 아무도 검사하지 않는 항목**이 된다.
+이제 `boxes_png` 전체를 열거한다.
+⚠️ **다만 현재 이 분기에 도달하는 케이스는 없다** — `keep:"all"` 을 가진 픽스처 목적은
+`医療機関提示` 뿐이고 그에 대응하는 앱 제출목적이 없다(진료 제시는 마스킹 대상이 아니다).
+수정은 올바르지만 **지금은 실행되지 않는다**. 백로그에 올렸다.
+
+### 3-4 `require_banded` 는 좌표까지 본다 [5-5]
+
+`mode !== 'ok'` 는 **카테고리가 꺼졌거나 박스가 비어 있어도 참**이다.
+이제 `located ∧ isOn ∧ mode≠'ok' ∧ 그 엔티티가 칠할 rect 가 실제 __maskRects 안에 있음`을 전부 본다.
+`require_clear` 도 같은 방식으로 "maskRects 에 없음"까지 단언한다.
+
+> ⚠️ **정직하게 적어둘 것**: 네 번째 조건(`inMask`)은 **지금은 앞의 세 조건에서 따라 나온다.**
+> `__maskRects` 와 `__fieldBands` 가 **같은 `mergeLineBoxes`+`bandRect`** 로 좌표를 계산하므로
+> `inMask ⟺ located ∧ isOn ∧ mode≠'ok'` 이다 — 반례를 만들 수 없다.
+> 실제로 힘을 보태는 것은 **`located`·`isOn` 두 조건**(이것이 지적된 공백이다)과,
+> 좌표를 독립적으로 재는 `JP_INK`·`JP_MASK`·`JP_KEEP` 쪽이다.
+> `inMask` 는 **발산 감시용 카나리아**로 남긴다 — `drawRedactions` 가 `__maskRects` 와 다른
+> 기준으로 그리기 시작하면 (예: 필터가 하나 추가되면) 이 단언이 먼저 빨개진다.
+> 프로브 A(`isOn` 이 `legal` 무시)가 잡은 것도 네 번째가 아니라 **`isOn`** 이다.
+
+### 3-5 유효 個人番号가 auto/gate 가 되는 경로를 실제로 돌린다 [5-2]
+
+알파 카드 더미는 **전부 무효 번호**(전략 v2 §4)라, 지금까지 `checkOk: true` 분기는
+**한 번도 실행된 적이 없었다** — 올바른 번호는 골든이 한 번도 돌려보지 않은 경로를 탔다.
+유효 번호를 카드 이미지에 넣지 않고, 앱 자신의 텍스트 렌더러(붙여넣기 경로)로 住民票 페이지를
+합성해 **분류 → 레이블 앵커 → 자릿수 스팬 → 체크디지트 → 목적 게이트**를 전부 통과시킨다.
+4 케이스(유효/본인확인=gate·띠 / 유효/번호수속+확인=keep·해제 / 유효/번호수속·확인없음=gate·띠 /
+무효=recommend+`checkdigit`·띠) + 체크디지트 벡터 8개(나머지 0·1 경계 포함).
+
+### 3-6 "예상하지 않은 자동 엔티티 0" [5-6]
+
+총수 상한은 **「맞는 5개」와 「맞는 2개 + 틀린 3개」를 구별하지 못한다.**
+케이스마다 `auto_allow` 필드 allowlist 를 두고 `kind==='auto'` 엔티티의 필드 집합이 그 부분집합인지
+단언한다(비-JP 정규식 자동 엔티티는 `(regex:<type>)` 로 집계되어 함께 걸린다). 19개 단언.
+`auto_allow: []` 는 **「자동 엔티티가 하나도 없어야 한다」는 강한 단언**이고, 필드를 생략한 것과는 다르다
+— JS 에서 `[]` 는 truthy 이므로 `if (c.auto_allow)` 가 실행된다(생략 = `undefined` = 건너뜀). 실측으로
+`juminhyo` 4개 variant 와 `unten_menkyo`·`mynumber_card/front` 가 전부 auto 0 이고, 그 0 이 단언된다.
+**실효성 확인**: `jumin_code` 를 auto 로 되돌리니 `UNEXPECTED: jumin_code` 로 실패.
+
+### 3-7 `checkOutput` 이 keep 필드를 가린 파일을 검사하던 문제 [지시 11]
+
+"Make 를 활성화하려고 첫 ON 엔티티를 강제로 `no`" → JP 픽스처에서 종종 **keep 필드**가 걸렸다.
+그러면 누출을 검사하는 그 파일이 **제출처가 필요로 하는 값을 가린 파일**이다.
+`auto` → `keep 아님` → 아무거나 순으로 고르게 바꿨다.
+
+---
+
+## 4. Codex 지적 처리표 (전 32건)
+
+범례: **수용** = 이번에 고쳤다 · **보류** = 백로그 등재(§5) · **반려** = 고치지 않고 근거를 남긴다
+
+| # | 지적 | 처리 | 근거 |
+|---|---|---|---|
+| 1-1 | 분류 실패 무경고 | **수용** | §1-1. 경고 배너 + low-confidence 강등 |
+| 1-2 | 고정 세그먼트 간격이 DPI·레이아웃에 취약 | **보류** | 동적 임계값은 탐지 모델 변경이다. 알파 픽스처 전부에서 80px/140px 사이가 성립함은 측정값이고, 바꾸려면 **다른 DPI·원근의 픽스처가 먼저** 필요하다 |
+| 1-3 | `headOnly` 강제가 과도 | **보류** | 완화하면 각주 오탐이 돌아온다(이 강제가 생긴 이유가 그것이다). 「선두 허용 잡음 클래스」는 그 클래스를 정하는 근거(실물 샘플)가 있어야 한다 |
+| 1-4 | 숫자 길이 폴백이 비민감 번호를 자동 마스킹 | **부분 수용** | `住民票コード` 는 `recommend` 로 내려가 더 이상 자동이 아니다(§2-3). 資格確認書 폴백 축소는 **보류** — 그 폴백은 OCR 이 5개 중 3개에서 `保険者番号` 라벨을 뭉갠다는 측정에 근거하고, 줄이면 그만큼이 미탐이 된다 |
+| 1-5 | 체크디지트 **출처** 표기 오류 | **수용** | §2-6. 산식은 유지, 출처 정정 + 경계 벡터 |
+| 1-6 | 世帯員 경계(世帯連記式 등) | **보류** | 양식 변형 픽스처가 없다. 반복 열 구조·続柄·구분선을 쓰려면 그 양식의 더미가 먼저 필요하다 |
+| 2-1 | `jpFrameBelow` 가 가로선 2개만 검증 | **보류** | 세로변·모서리 검증은 탐지 변경이다. 현재 3개 欄 전부 픽셀 단위로 정확함을 렌더로 확인했고, 오탐 사례가 아직 없다 |
+| 2-2 | 레이블 없는 사각형이 기본 ON | **수용** | §1-2 |
+| 2-3 | 주소 `strong` 이 쓰이지 않음 | **부분 수용** | `strong` 은 여전히 레벨을 바꾸지 않는다 — **대신 전략의 「동반 시 자동」 약속 쪽을 매트릭스에서 지웠다**: `general_jp` 의 `address_loose` 는 `verified:false` 라 **자동이 될 수 없다**(`check_matrix` 가 강제). 코드와 정본이 이제 같은 말을 한다. `strong` 값 자체는 `jp_units` 가 계속 단언한다 |
+| 2-4 | 15% 패딩이 이웃 필드를 덮을 수 있음 | **보류** | 인접 박스 clamp 는 레이아웃 모델 변경이다. 현재 `MUST_NOT_MASK`·`JP_KEEP`(47건)이 패딩 **적용 후** 좌표를 재므로, 실제로 이웃을 덮으면 골든이 빨개진다 |
+| 3-1 | PDF 바이트 marker 가 완전한 검사가 아님 | **보류 + 문구 정정** | 객체그래프 검사는 qpdf 의존이 생긴다. Codex 3-2 가 **입력 구조물이 출력으로 계승되는 경로는 없다**고 독립 확인해줬으므로, 주장 범위를 「새 래스터 PDF 생성 경로 검증」으로 좁혀 적는다 |
+| 3-2 | 입력 PDF 구조물 계승 경로 없음 (지적 아님) | **확인** | 우리 판단과 일치 |
+| 3-3 | ICC 2KB·`dmnd/dmdd` 기준이 부재를 증명 못함 | **보류** | SHA-256 allowlist 는 Chrome 버전이 프로파일을 바꾸면 전부 빨개진다. 타당한 지적이라 백로그 |
+| 3-4 | PNG 보조 청크 allowlist | **보류** | 청크 파서를 쓰는 편이 맞다. 백로그 |
+| 4-1 | `JP_RULES` 가 정본과 불일치 (7건) | **수용 6 / 1 기록** | §2-1 ~ §2-3. 6건 해소 + 188 triple 대조를 테스트로 고정. **남은 1건**: 「`発行日・発行者` 는 검출 규칙이 없어 keep 경고가 실제로 생성되지 않는다」 — 사실이다. `jigyosho`·`hokensha_name`·`shikaku_date` 는 **라벨 앵커**라 규칙을 바로 넣었지만, 発行者 는 라벨이 없는 행(「見本市長 架空 太郎（公印省略）」)이라 `市長|区長|町長|村長` 휴리스틱이 필요하다 — 새 탐지 규칙이므로 이번 범위 밖. 매트릭스 `legal_basis` 에 「既知の空白」으로 적고 B-15 로 등재 |
+| 4-2 | 미명시 → 항상 optional 폴백 | **수용** | §2-4 |
+| 4-3 | `本籍/筆頭者` 확장에 법적 근거 없음 | **수용** | §2-3. 두 목적에서 `optional` 로 환원 |
+| 4-4 | マイナ裏面 안내가 단정적 | **수용** | §2-5. 문구 완화 + 확인 체크박스 |
+| 4-5 | keep 을 가릴 수 있게 둔 것 | **보류** | 「목적의 핵심 필드는 강제 유지」는 UX 결정이다. 현재는 경고 토스트 유지 |
+| 4-6 | `その他` 토글이 법적 띠를 해제 | **수용** | §1-4 |
+| 5-1 | `jp_auto_fields` 가 목적·검증 상태를 표현 못함 | **부분 수용** | 정적 표는 남겼지만 **정본과의 불일치는 `check_matrix` 가 막는다**. 표 자체도 `jumin_code` 제거로 정본을 따라갔다. 하네스가 앱과 같은 오해를 공유하는 위험은 **교차 대조**로 닫았다 |
+| 5-2 | 유효 個人番号 자동 띠 미검증 | **수용** | §3-5 |
+| 5-3 | 60% 피복이 판독 불가를 보장 못함 | **수용** | §3-1 |
+| 5-4 | `geometry:false` 가 오배치를 숨김 | **보류** | 회전 행렬 기록은 픽스처 재생성이 필요하다(좌표가 흔들려 전 spec 이 깨진다). 백로그 |
+| 5-5 | 공허한 단언 경로 5개 | **수용(4) + 1 미도달** | skipped→FAIL ✓ · `keep:'all'` ✓(단 미도달, §3-3) · `require_banded` ✓ · `JP_CLEAR` ✓ · `__candidateOver` → `JP_CANDIDATE` 가 이제 "띠가 걸렸으면 숫자 피복까지" 본다 |
+| 5-6 | `max_auto` 가 오탐 종류를 제한 못함 | **수용** | §3-6 |
+| 6-1 | 레이블 없는 QR 완화 불충분 | **수용** | §1-2 |
+| 6-2 | 電話·FAX 가 통합 경로 미검증 | **보류** | 알파 4종에 전화번호가 없다. 합성 픽스처가 필요하고, 같은 합성 기법(붙여넣기 경로)을 §3-5 에서 먼저 썼으므로 다음 라운드에 싸게 할 수 있다 |
+| 6-3 | 주소 자동 분기 사실상 미구현 | **수용(정본 쪽으로)** | 4-1 /2-3 과 동일 — 약속을 지웠다 |
+| 6-4 | 다중 페이지 | **수용** | §1-3 |
+| 6-5 | 테두리 중앙값 배경이 컬러 양식에 취약 | **보류** | 적응 임계값은 탐지 변경 + 컬러/어두운 픽스처가 먼저 필요하다 |
+| 7-1 | §4 안전조건 미충족 (무효화가 전수가 아님) | **수용(기록)** | CLAUDE.md 이슈 로그 정정 — 「오용 가치 0」 삭제, 무효화 비전수·우편번호 미검증을 명시 |
+| 7-2 | 실질 위험 낮으나 0은 아님 | **수용(기록)** | 동일. **공개 저장소 유지는 사람 결정으로 확정**(2026-10-21) |
+| 7-3 | 대안 비교 | **반려(이번 범위)** | 사람이 (a) 를 선택했다. 비공개 artifact 분리는 그 결정을 뒤집는 일이라 에이전트가 할 수 없다 |
+
+---
+
+## 5. 백로그 (다음 런)
+
+| # | 항목 | 선행 조건 |
+|---|---|---|
+| B-1 | 동적 세그먼트 임계값 (1-2) | 다른 DPI·원근 픽스처 |
+| B-2 | `headOnly` 선두 잡음 클래스 (1-3) | 실물 익명 샘플 |
+| B-3 | 世帯連記式 / 반복 열 구조 (1-6) | 해당 양식 더미 |
+| B-4 | `jpFrameBelow` 세로변·모서리 검증 (2-1) | 오탐 사례 또는 표 픽스처 |
+| B-5 | 패딩 인접 박스 clamp (2-4) | 근접 필드 픽스처 |
+| B-6 | PDF 객체그래프 검사 (3-1) | qpdf 의존 승인 |
+| B-7 | ICC SHA-256 allowlist (3-3) | Chrome 프로파일 고정 전략 |
+| B-8 | PNG 청크 파서 allowlist (3-4) | — |
+| B-9 | 적응 배경 추정 (6-5) | 컬러·어두운 합성 픽스처 |
+| B-10 | `geometry:false` 케이스의 기하 검증 (5-4) | 회전 행렬을 기록하는 픽스처 재생성 |
+| B-11 | 電話·FAX 통합 경로 (6-2) | 합성 픽스처 (§3-5 기법 재사용) |
+| B-12 | `keep:"all"` 분기에 도달하는 케이스 (§3-3) | `医療機関提示` 에 대응하는 제출목적을 둘지 제품 결정 |
+| B-13 | 모든 번호군의 명시적 무효화 (7-1) | gen.py 재생성 = 좌표 변동 → 전 spec 재생성과 한 묶음 |
+| B-14 | 일본 변호사 검토 | 사람 |
+| B-15 | `発行日`·`発行者` 탐지 규칙 (4-1 잔여) | 라벨 없는 행용 `市長|区長|町長|村長` 휴리스틱 설계 + 오탐 평가 |
+
+---
+
+## 6. 검증
+
+| 검증 | 결과 |
+|---|---|
+| `node test/safe/run.mjs` | **484 / 484 pass · 0 FAIL · exit 0** (직전 389) — 전체 로그 [`s3b_golden_result.md`](s3b_golden_result.md) |
+| `node test/safe/check_matrix.mjs` | **188 triple 일치**, `verified:false ⇒ no-auto` 성립 |
+| `node test/sw/offline_resilience.mjs` | **9 / 9** (회귀 없음) |
+| 신규 단언 카테고리 | `JP_WARN` 12 · `JP_LEGAL` 13 · `JP_AUTO_SET` 19 · `JP_INK` 15 · `JP_MN_BOX` 3 · `JP_PAGECLASS`/`BACK_ONLY`/`BACK_COVER`/`FRONT_CLEAR` 각 2 · `JP_MYNUM_*` 23 · `JP_UNLABELLED` 4 · `JP_MATRIX` 1 |
+| 렌더 육안 확인 | `kouki` (被保険者番号·性別·保険者番号·QR 전부 피복, keep 전부 가시) · `mynumber_card/back` |
+| UI 육안 확인 | 경고 배너 / 「法令・提出先ルール」 그룹 / 個人番号手続 확인 체크박스 (ja) — [`s3b_visual/`](s3b_visual/): [`ui_unclassified_warning.png`](s3b_visual/ui_unclassified_warning.png) · [`ui_legal_group.png`](s3b_visual/ui_legal_group.png) · [`ui_mynumber_confirm.png`](s3b_visual/ui_mynumber_confirm.png) · [`render_kouki_bands.png`](s3b_visual/render_kouki_bands.png) |
+| 프로덕션 DB | **미접촉** |
+
+### 6-1 변이 프로브 — **새 단언이 공허하지 않은지 전부 실측**
+
+고치기 전 코드를 실제로 되돌려 넣고 그 단언이 빨개지는지 확인했다(각 프로브 후 원복 + 바이트 동일 확인).
+
+| 프로브 | 되돌린 것 | 결과 |
+|---|---|---|
+| A | `isOn` 이 `e.legal` 을 무시 | `JP_LEGAL — qr / hokensha_bango: DROPPED` **2건 실패** |
+| B | `ocrCanvas` 의 `w.text.trim()` 제거 | `JP_INK — hihokensha_bango: 8 comp, worst 74%` **실패** (같은 상태에서 60% 게이트는 통과) |
+| C | 個人番号 게이트가 확인을 요구하지 않음 | `JP_BANDED — back_all: MISSING · my_number: CLEAR` **2건 실패** |
+| D | 레이블 없는 블록이 `recommend` | `JP_UNLABELLED — level/mode/기본 출력 피복(100%)` **3건 실패** |
+| E | `jumin_code` 를 `auto` 로 | `JP_AUTO_SET — UNEXPECTED: jumin_code` **실패** + `check_matrix` 3건 불일치 |
+| F | `back_all` 이 1페이지 class 로 판정 | `表→裏`: 뒷면 띠 없음(1%) · `裏→表`: 앞면까지 100% — **4건 실패**, 양방향 모두 |
+
+### 6-2 이번 라운드에 스스로 잡은 하네스 결함 2건
+
+1. **`__allCatsOff()` 가 전역 상태를 흘렸다.** `catEnabled` 는 `resetAll()` 도 파일 재로드도
+   복원하지 않는 모듈 상태라, 카테고리를 끈 뒤 문서만 다시 읽으면 **그 뒤 모든 문서가 카테고리 OFF
+   상태로** 돈다. 첫 전체 런에서 14건이 빨개졌고 그중 11건은 **다른 문서의 멀쩡한 단언**이었다.
+   스냅샷/복원 쌍으로 바꾸고, 복원 성공 자체를 정보 행으로 남긴다.
+2. **`pages.length > 0` 을 로드 완료로 쓴 것** (§1-3 각주). 1페이지 픽스처에서는 우연히 맞았다.
+
+---
+
+## 7. 잔여 위험 (수정 안 함 · 명시)
+
+- **레이블이 읽히지 않은 코드 블록은 이제 기본으로 가려지지 않는다.** 이것은 요청받은 교환이고
+  (검증 안 된 탐지가 픽셀을 지우지 않는다), 실측상 `mynumber_card/back` 의 二次元コード 가 그 경로를
+  탄다 — 거기서는 `back_all` 이 면 전체를 덮어 결과가 같다. **그러나 資格確認書 에서 OCR 이 라벨을
+  잃으면 QR 이 후보로만 남는다.** 진짜 QR 픽스처(§4 해제 후)가 생기면 finder pattern·quiet zone 으로
+  승격 조건을 만들 수 있다. 그 전까지는 **후보 + 경고가 우리가 정직하게 할 수 있는 전부**다.
+- **`発行日`·`発行者(issuer)` 는 둘 다 탐지 규칙이 없다.** 매트릭스는 keep 이라고 선언하는데 그 keep 경고는 생성될 수 없다 — 죽은 규칙이다. 지우지 않고 「既知の空白」으로 매트릭스에 적어 남긴 이유: 지우면 **정본이 침묵하게 되어** 다음 라운드가 「원래 keep 이 아니었다」고 읽는다. B-15.
+- `<html lang>`·`og:locale`·UI 크롬 협상은 그대로 (이전 세션들의 관찰).
+- 알파 4종에 전화번호가 없어 `tel` 은 여전히 `jp_units` 로만 고정돼 있다 (B-11).
diff --git a/test/safe/check_matrix.mjs b/test/safe/check_matrix.mjs
new file mode 100644
index 0000000..3552148
--- /dev/null
+++ b/test/safe/check_matrix.mjs
@@ -0,0 +1,125 @@
+#!/usr/bin/env node
+/*
+ * Legal matrix ↔ code cross-check.
+ *
+ * jp_legal_matrix_alpha4.json is the 정본 (single source of truth). The page is a
+ * single static HTML file with no build step, so JP_RULES in public/safe/index.html
+ * is a hand-written mirror of it. A second hand-written table is exactly how the
+ * two drift apart (Codex 4-1 found seven disagreements), so this file makes the
+ * drift a test failure instead of a reading exercise:
+ *
+ *   1. derive (doc, field, purpose) → level from the JSON,
+ *   2. read JP_RULES + jpLevel out of index.html and evaluate them,
+ *   3. compare EVERY (doc, field, purpose) triple in either table,
+ *   4. enforce the invariant `verified:false ⇒ never auto/gate` on the JSON,
+ *   5. enforce that the fields JP_RULES names are the fields the JSON names.
+ *
+ * run.mjs calls this first, so the golden cannot pass while the tables disagree.
+ * Usage: node check_matrix.mjs   (exit 0 = identical)
+ */
+import fs from 'node:fs';
+import path from 'node:path';
+import { fileURLToPath } from 'node:url';
+
+const __dirname = path.dirname(fileURLToPath(import.meta.url));
+const REPO = path.resolve(__dirname, '..', '..');
+const MATRIX = path.join(__dirname, 'fixtures', 'jp', 'jp_legal_matrix_alpha4.json');
+const PAGE = path.join(REPO, 'public', 'safe', 'index.html');
+
+const LEVEL_TOKEN = { auto: 'auto', auto_with_purpose_gate: 'gate', recommend: 'recommend', optional: 'optional', keep: 'keep' };
+const AUTOMATIC = new Set(['auto', 'gate']);
+
+const problems = [];
+const fail = (what, msg) => problems.push(`${what}: ${msg}`);
+
+/* ── 1. the 정본 → a (doc, field, purpose) table ── */
+const M = JSON.parse(fs.readFileSync(MATRIX, 'utf8'));
+const PURPOSES = Object.keys(M.purposes);
+const matrix = {};            // doc → field → purpose → level
+const matrixFields = {};      // doc → Set(field)
+function applyRule(docId, rule, where) {
+  const token = LEVEL_TOKEN[rule.level];
+  if (!token) { fail(where, `unknown level "${rule.level}"`); return; }
+  if (!Array.isArray(rule.fields) || !rule.fields.length) { fail(where, 'rule has no `fields` (code field keys)'); return; }
+  if (rule.verified === false && AUTOMATIC.has(token))
+    fail(where, `verified:false but level "${rule.level}" is automatic — an unsourced rule may not delete pixels on its own`);
+  const seen = {};
+  const put = (purpose, level) => {
+    if (!PURPOSES.includes(purpose)) { fail(where, `unknown purpose "${purpose}"`); return; }
+    if (seen[purpose]) { fail(where, `purpose "${purpose}" appears twice (${seen[purpose]} and ${level})`); return; }
+    seen[purpose] = level;
+    for (const f of rule.fields) {
+      matrix[docId] = matrix[docId] || {};
+      matrix[docId][f] = matrix[docId][f] || {};
+      matrixFields[docId] = matrixFields[docId] || new Set();
+      matrixFields[docId].add(f);
+      const prev = matrix[docId][f][purpose];
+      if (prev && prev !== level) fail(`${docId}.${f}[${purpose}]`, `two rules disagree: ${prev} vs ${level}`);
+      matrix[docId][f][purpose] = level;
+    }
+  };
+  for (const p of (rule.must_keep_when || [])) put(p, 'keep');
+  for (const p of (rule.mask_when || [])) put(p, token);
+  for (const p of (rule.optional_when || [])) put(p, 'optional');
+}
+for (const doc of M.documents) for (const r of doc.rules) applyRule(doc.id, r, `${doc.id} 「${r.field}」`);
+// general_jp applies to every listed document.
+const G = M.general_jp || { applies_to: [], rules: [] };
+for (const docId of G.applies_to) for (const r of G.rules) applyRule(docId, r, `general_jp→${docId} 「${r.field}」`);
+
+/* ── 2. the code → JP_RULES + jpLevel ── */
+const src = fs.readFileSync(PAGE, 'utf8');
+function slice(startMarker, endMarker) {
+  const a = src.indexOf(startMarker);
+  if (a < 0) throw new Error(`cannot find ${startMarker} in ${PAGE}`);
+  const b = src.indexOf(endMarker, a);
+  if (b < 0) throw new Error(`cannot find ${endMarker} after ${startMarker}`);
+  return src.slice(a, b + endMarker.length);
+}
+// Everything from the purpose shorthands through the end of JP_RULES, then jpLevel.
+const rulesSrc = slice('const P_NOT_MYNUM =', '\n};\n');
+const levelSrc = slice('function jpLevel(', '\n}\n');
+const legalSrc = slice('const JP_LEGAL_FIELDS =', ']);');
+let JP_RULES, jpLevel, JP_LEGAL_FIELDS;
+try {
+  ({ JP_RULES, jpLevel, JP_LEGAL_FIELDS } =
+    new Function(`${rulesSrc}\n${levelSrc}\n${legalSrc}\nreturn {JP_RULES, jpLevel, JP_LEGAL_FIELDS};`)());
+} catch (e) {
+  console.error('could not evaluate JP_RULES / jpLevel out of index.html:', e.message);
+  process.exit(2);
+}
+
+/* ── 3. compare every triple in EITHER table ── */
+let compared = 0;
+const docs = new Set([...Object.keys(matrix), ...Object.keys(JP_RULES)]);
+for (const doc of docs) {
+  const mf = matrixFields[doc] || new Set();
+  const cf = new Set(Object.keys(JP_RULES[doc] || {}));
+  for (const f of cf) if (!mf.has(f)) fail(`${doc}.${f}`, 'in JP_RULES but not in the legal matrix');
+  for (const f of mf) if (!cf.has(f)) fail(`${doc}.${f}`, 'in the legal matrix but not in JP_RULES');
+  for (const f of new Set([...mf, ...cf])) {
+    for (const p of PURPOSES) {
+      const want = ((matrix[doc] || {})[f] || {})[p] || null;
+      const got = (JP_RULES[doc] && JP_RULES[doc][f]) ? jpLevel(doc, f, p) : null;
+      compared++;
+      if (want !== got) fail(`${doc}.${f}[${p}]`, `matrix says ${want || 'null (not offered)'}, code says ${got || 'null (not offered)'}`);
+    }
+  }
+}
+// A triple must have been checked. A comparison loop that silently ran zero
+// times prints the same green as one that checked two hundred.
+if (compared < 100) fail('coverage', `only ${compared} (doc, field, purpose) triples compared — the extraction is probably broken`);
+
+/* ── 4/5. the legal group must be a subset of what the matrix grounds in statute ── */
+for (const f of JP_LEGAL_FIELDS) {
+  const inSome = Object.keys(matrix).some(d => matrix[d][f]);
+  if (!inSome) fail(`JP_LEGAL_FIELDS.${f}`, 'not a field the legal matrix knows');
+}
+
+if (problems.length) {
+  console.log(`\n✗ legal matrix ↔ code: ${problems.length} disagreement(s) over ${compared} triples\n`);
+  for (const p of problems) console.log('   ' + p);
+  console.log('');
+  process.exit(1);
+}
+console.log(`✅ legal matrix ↔ code: ${compared} (doc, field, purpose) triples identical, verified:false⇒no-auto holds`);

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "rg -n \"JP_SUSPECT_RE|function jpClassify|function jpScan|function jpExtract|function jpApply|function jpLevel|JP_LEGAL_FIELDS|function isOn|const isOn|jpMnGateOpen|jpRenderBar|jpSetPurpose|function renderList|function sectionHtml|myNumberCheckOk|JP_FIELD_RULES|shikaku_date|hokensha_name|jigyosho|__inkCover|__fieldBands|__allCatsOff|__restoreCats|__autoFields|checkJpDoc|checkJpMultiPage|checkJpMyNumber|checkJpUnlabelled|checkJpWarn|checkMatrix|async function loadDoc|auto_allow|require_legal|keep === 'all'|keep.*all\" public/safe/index.html test/safe/run.mjs test/safe/specs.json test/safe/fixtures/jp/gen.py test/safe/fixtures/jp/jp_legal_matrix_alpha4.json docs/jp/s3b_report.md" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:38:        {"field": "事業所名称・保険者名・資格取得年月日", "fields": ["jigyosho", "hokensha_name", "shikaku_date"],
test/safe/fixtures/jp/gen.py:117:    label_val(d, 40, y, "資格取得年月日", "令和7年4月1日", 220, 22, boxes, "shikaku_date")
test/safe/fixtures/jp/gen.py:120:        label_val(d, 40, y, "事業所名称", "架空株式会社", 160, 22, boxes, "jigyosho"); y += 46
test/safe/fixtures/jp/gen.py:122:    label_val(d, 520, y, "保険者名", {"kenpo":"架空健康保険協会","kokuho":"見本市","kouki":"架空県後期高齢者医療広域連合"}[variant], 140, 20, boxes, "hokensha_name"); y += 50
test/safe/fixtures/jp/gen.py:128:        "本人確認提出": {"mask": ["hokensha_bango","kigo","bango","edaban","hihokensha_bango","qr"], "recommend": ["sex"], "keep": ["name","birth","address","expiry","jigyosho"],
test/safe/fixtures/jp/gen.py:130:        "医療機関提示": {"mask": [], "keep": "all", "legal_basis": "医療保険事務は告知要求制限の対象外"}}
test/safe/fixtures/jp/gen.py:177:        purposes = {"身元確認": {"mask": [], "recommend": ["sex","organ_donor"], "keep": ["name","address","birth","expiry","photo"], "legal_basis": "表面は本人同意で複写可（PPC FAQ）", "source": "https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"}}
test/safe/specs.json:220:  "_jp_basis": "JP-1 alpha. Fixtures live in fixtures/jp/<doc>/<variant>.{png,jpg,pdf} with a sibling .specs.json carrying a BOX TABLE in PNG pixels plus, per 提出目的, which boxes the purpose hides / recommends / offers / keeps. The harness replays that table against the live pipeline, so the expectations are the fixture's, not the detector's. PNG and PDF differ from the table by one uniform scale (taken at runtime from page.w / fixture width); the JPG variants are rotated and blurred on purpose (phone photo), so their OCR boxes cannot land on those coordinates and those cases assert at FIELD level instead — detected, and banded — which is what the 미탐 0 gate is actually about.",
test/safe/specs.json:274:          "require_legal": [
test/safe/specs.json:278:          "auto_allow": [
test/safe/specs.json:306:          "require_legal": [
test/safe/specs.json:310:          "auto_allow": [
test/safe/specs.json:335:          "require_legal": [
test/safe/specs.json:339:          "auto_allow": [
test/safe/specs.json:364:          "auto_allow": []
test/safe/specs.json:385:          "auto_allow": []
test/safe/specs.json:409:          "auto_allow": []
test/safe/specs.json:427:          "auto_allow": []
test/safe/specs.json:449:          "require_legal": [
test/safe/specs.json:452:          "auto_allow": [
test/safe/specs.json:468:          "auto_allow": [],
test/safe/specs.json:505:          "require_legal": [
test/safe/specs.json:508:          "auto_allow": [],
test/safe/specs.json:520:          "auto_allow": []
test/safe/specs.json:533:          "auto_allow": []
test/safe/specs.json:550:          "auto_allow": []
test/safe/specs.json:559:          "auto_allow": [],
test/safe/specs.json:573:          "auto_allow": []
test/safe/specs.json:597:          "require_legal": [
test/safe/specs.json:601:          "auto_allow": [
test/safe/specs.json:630:          "require_legal": [
test/safe/specs.json:634:          "auto_allow": [
test/safe/specs.json:663:          "auto_allow": []
test/safe/specs.json:686:          "require_legal": [
test/safe/specs.json:689:          "auto_allow": [
docs/jp/s3b_report.md:39:- 「일본 공문서 특징」 = `資格確認書|免許証|個人番号|マイナンバー|住民票|令和|平成|昭和` (`JP_SUSPECT_RE`).
docs/jp/s3b_report.md:95:  `const isOn = e => e.legal ? true : catEnabled[e.type] !== false;`
docs/jp/s3b_report.md:102:**하네스**: `require_legal` — **모든 카테고리를 끈 상태**에서 해당 필드의 띠가 살아 있는지
docs/jp/s3b_report.md:116:2. `index.html` 에서 `JP_RULES`·`jpLevel`·`JP_LEGAL_FIELDS` 를 **잘라내 실행**한다,
docs/jp/s3b_report.md:141:| 資格確認書 | `jigyosho`·`hokensha_name`·`shikaku_date` | 코드에만 있던 keep | 정본에 **`verified:false` keep 으로 편입** + **탐지 규칙 신설** | Codex 4-1 「구현이 정본에 없는 항목을 추가함」. 숨기는 대신 정본에 적고 출처 없음을 표기했다. 탐지 규칙이 없어 **keep 경고가 생길 수 없던 죽은 규칙**이었으므로 규칙도 함께 넣었다 |
docs/jp/s3b_report.md:200:kokuho/kouki 의 `jigyosho`, kouki 의 `kigo/bango/edaban`)을 정리했다.
docs/jp/s3b_report.md:202:### 3-3 `keep: "all"` 은 전 박스를 열거한다 [5-5]
docs/jp/s3b_report.md:206:⚠️ **다만 현재 이 분기에 도달하는 케이스는 없다** — `keep:"all"` 을 가진 픽스처 목적은
docs/jp/s3b_report.md:217:> `__maskRects` 와 `__fieldBands` 가 **같은 `mergeLineBoxes`+`bandRect`** 로 좌표를 계산하므로
docs/jp/s3b_report.md:237:케이스마다 `auto_allow` 필드 allowlist 를 두고 `kind==='auto'` 엔티티의 필드 집합이 그 부분집합인지
docs/jp/s3b_report.md:239:`auto_allow: []` 는 **「자동 엔티티가 하나도 없어야 한다」는 강한 단언**이고, 필드를 생략한 것과는 다르다
docs/jp/s3b_report.md:240:— JS 에서 `[]` 는 truthy 이므로 `if (c.auto_allow)` 가 실행된다(생략 = `undefined` = 건너뜀). 실측으로
docs/jp/s3b_report.md:272:| 4-1 | `JP_RULES` 가 정본과 불일치 (7건) | **수용 6 / 1 기록** | §2-1 ~ §2-3. 6건 해소 + 188 triple 대조를 테스트로 고정. **남은 1건**: 「`発行日・発行者` 는 검출 규칙이 없어 keep 경고가 실제로 생성되지 않는다」 — 사실이다. `jigyosho`·`hokensha_name`·`shikaku_date` 는 **라벨 앵커**라 규칙을 바로 넣었지만, 発行者 는 라벨이 없는 행(「見本市長 架空 太郎（公印省略）」)이라 `市長|区長|町長|村長` 휴리스틱이 필요하다 — 새 탐지 규칙이므로 이번 범위 밖. 매트릭스 `legal_basis` 에 「既知の空白」으로 적고 B-15 로 등재 |
docs/jp/s3b_report.md:282:| 5-5 | 공허한 단언 경로 5개 | **수용(4) + 1 미도달** | skipped→FAIL ✓ · `keep:'all'` ✓(단 미도달, §3-3) · `require_banded` ✓ · `JP_CLEAR` ✓ · `__candidateOver` → `JP_CANDIDATE` 가 이제 "띠가 걸렸으면 숫자 피복까지" 본다 |
docs/jp/s3b_report.md:310:| B-12 | `keep:"all"` 분기에 도달하는 케이스 (§3-3) | `医療機関提示` 에 대응하는 제출목적을 둘지 제품 결정 |
docs/jp/s3b_report.md:344:1. **`__allCatsOff()` 가 전역 상태를 흘렸다.** `catEnabled` 는 `resetAll()` 도 파일 재로드도
test/safe/run.mjs:135:  window.__inkCover = function (rect) {
test/safe/run.mjs:180:  window.__fieldBands = function (field) {
test/safe/run.mjs:201:  window.__autoFields = function () {
test/safe/run.mjs:210:  window.__allCatsOff = function () {
test/safe/run.mjs:216:  window.__restoreCats = function () {
test/safe/run.mjs:253:async function loadDoc(page, file, ocr) {
test/safe/run.mjs:542:    const ic = await page.evaluate(r => window.__inkCover(r), rect);
test/safe/run.mjs:566:async function checkJpDoc(page, spec) {
test/safe/run.mjs:573:    await page.evaluate(p => jpSetPurpose(p), c.purpose);
test/safe/run.mjs:602:      const bs = await page.evaluate(x => window.__fieldBands(x), f);
test/safe/run.mjs:614:      const bs = await page.evaluate(x => window.__fieldBands(x), f);
test/safe/run.mjs:620:    for (const f of (c.require_legal || [])) {
test/safe/run.mjs:621:      const left = await page.evaluate(() => window.__allCatsOff());
test/safe/run.mjs:622:      const bs = await page.evaluate(x => window.__fieldBands(x), f);
test/safe/run.mjs:628:      const restored = await page.evaluate(() => window.__restoreCats());
test/safe/run.mjs:631:      await page.evaluate(p => jpSetPurpose(p), c.purpose);
test/safe/run.mjs:636:    if (c.auto_allow) {
test/safe/run.mjs:637:      const af = await page.evaluate(() => window.__autoFields());
test/safe/run.mjs:638:      const bad = af.filter(f => !c.auto_allow.includes(f));
test/safe/run.mjs:639:      rec(tag, 'JP_AUTO_SET', 'auto fields ⊆ allowlist', c.auto_allow.join(',') || '(none)',
test/safe/run.mjs:677:    // `keep: "all"` means every box on the page is a keep field. Turning that
test/safe/run.mjs:680:    await run(P.keep === 'all' ? Object.keys(fx.boxes_png) : P.keep, () => 'keep');
test/safe/run.mjs:718:function checkMatrix() {
test/safe/run.mjs:751:async function checkJpMultiPage(page, port) {
test/safe/run.mjs:763:      await page.evaluate(() => jpSetPurpose('identity_submit'));
test/safe/run.mjs:770:      const bs = await page.evaluate(() => window.__fieldBands('back_all'));
test/safe/run.mjs:793:async function checkJpMyNumber(page) {
test/safe/run.mjs:796:    const got = await page.evaluate(v => myNumberCheckOk(v), c.n);
test/safe/run.mjs:806:    await page.evaluate(p => jpSetPurpose(p), c.purpose);
test/safe/run.mjs:810:    const bs = await page.evaluate(() => window.__fieldBands('my_number'));
test/safe/run.mjs:835:async function checkJpUnlabelled(page) {
test/safe/run.mjs:840:  await page.evaluate(p => jpSetPurpose(p), U.purpose);
test/safe/run.mjs:850:      labelledBanded: window.__fieldBands('qr').filter(b => b.note !== 'unlabelled_code').every(b => b.mode !== 'ok' && b.inMask) };
test/safe/run.mjs:865:async function checkJpWarn(page) {
test/safe/run.mjs:882:      const af = await page.evaluate(() => window.__autoFields());
test/safe/run.mjs:941:    try { await checkJpDoc(page, spec); }
test/safe/run.mjs:945:  if (!onlyArg) { process.stderr.write('… legal matrix\n'); checkMatrix(); }
test/safe/run.mjs:946:  if (!onlyArg || onlyArg === 'jp/2page') { process.stderr.write('… jp multipage\n'); await checkJpMultiPage(page, port); }
test/safe/run.mjs:948:  if (!onlyArg || onlyArg === '(jp synth)') { process.stderr.write('… jp my_number\n'); await checkJpMyNumber(page); }
test/safe/run.mjs:949:  if (!onlyArg || onlyArg === '(jp unlabelled)') { process.stderr.write('… jp unlabelled block\n'); await checkJpUnlabelled(page); }
test/safe/run.mjs:950:  if (!onlyArg || onlyArg === '(jp warn)') { process.stderr.write('… jp classification warning\n'); await checkJpWarn(page); }
public/safe/index.html:618:  jpPurposeLabel:'Purpose of submission', jpBackNotice:'If identity is what needs checking, submit the front face only. Under the My Number Act, copying or keeping a My Number for anything other than a task the law recognises is restricted. Choose “My Number procedure” only when the recipient performs a statutory My Number task.', jpKeepWarn:'The recipient asks for this field. Hiding it may get your submission rejected.', jpUnclassifiedWarn:'文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。 (The document type could not be identified, so no automatic redaction was applied. Please select the areas to cover by hand.)', jpMnConfirm:'I confirm the recipient performs a statutory My Number (個人番号関係事務) task.', jpLegalSection:'Statutory / recipient rules (法令・提出先ルール)', jpLegalWarn:'This band has a legal basis. Releasing it sends data the recipient is not allowed to keep.', keepSection:'Fields to keep visible',
public/safe/index.html:733:  reasons:{name:'Puede ser un nombre', jp_auto:'Oculto automáticamente (base legal)', jp_gate:'Oculto para esta finalidad', jp_recommend:'Se recomienda ocultar', jp_optional:'Opcional', jp_keep:'El destinatario lo necesita', addr:'Puede ser una dirección', addr_contact:'Puede ser una dirección · cerca del contacto', addr_edge:'Puede ser una dirección · encabezado/pie', addr_kw:'Puede ser una dirección · término de lugar/calle'},
public/safe/index.html:797:const isOn=e=>e.legal?true:catEnabled[e.type]!==false;
public/safe/index.html:1204:const JP_SUSPECT_RE = /資格確認書|免許証|個人番号|マイナンバー|住民票|令和|平成|昭和/;
public/safe/index.html:1205:function jpSuspect(pi){ return JP_SUSPECT_RE.test(jpPageText(pi)); }
public/safe/index.html:1220:function jpClassify(pi){
public/safe/index.html:1251:function myNumberCheckOk(d12){
public/safe/index.html:1459:    jigyosho: KEEP_ID_BID, hokensha_name: KEEP_ID_BID, shikaku_date: KEEP_ID_BID,
public/safe/index.html:1503:const JP_LEGAL_FIELDS = new Set(['back_all','qr','my_number','jumin_code',
public/safe/index.html:1505:function jpLevel(doc, field, purpose){
public/safe/index.html:1520:const JP_FIELD_RULES = {
public/safe/index.html:1538:    { field:'shikaku_date',  labels:['資格取得年月日','資格取得'], re:null, last:true },
public/safe/index.html:1539:    { field:'hokensha_name', labels:['保険者名'], re:null, last:true },
public/safe/index.html:1540:    { field:'jigyosho',      labels:['事業所名称','事業所名'], re:null, last:true },
public/safe/index.html:1671:function jpExtract(pi, cls){
public/safe/index.html:1678:  const rules = (JP_FIELD_RULES[cls.doc] || [])
public/safe/index.html:1708:        const extra = r.field === 'my_number' ? { checkOk: myNumberCheckOk(sp.digits) } : {};
public/safe/index.html:1770:        if (len === 12) push('my_number', jpBoxes(seg, a, b), seg.t.slice(a,b), { checkOk: myNumberCheckOk(seg.t.slice(a,b)), viaFallback: true });
public/safe/index.html:1859:function jpScan(){
public/safe/index.html:1893:function jpMnGateOpen(){ return jpState.purpose === 'my_number_procedure' && jpState.mnConfirmed; }
public/safe/index.html:1895:function jpApply(){
public/safe/index.html:1897:  const cls = jpState.cls; if (!cls) { jpRenderBar(); renderAll(); return; }
public/safe/index.html:1904:    const legal = JP_LEGAL_FIELDS.has(f) && mode === 'no';
public/safe/index.html:1955:  jpRenderBar();
public/safe/index.html:1963:function jpSetPurpose(p){
public/safe/index.html:1973:function jpRenderBar(){
public/safe/index.html:2311:  } else { jpRenderBar(); renderAll(); }
public/safe/index.html:2316:  jpState=JP_STATE0(); jpRenderBar();
public/safe/index.html:2483:  // keep bottom margin clear (QR/stamp/signature area) + small top margin
public/safe/index.html:2546:$('jpPurpose').addEventListener('change',e=>jpSetPurpose(e.target.value));
public/safe/index.html:2576:function sectionHtml(kind,title,items){
public/safe/index.html:2599:function renderList(){

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "nl -ba public/safe/index.html | sed -n '780,815p;1190,1270p;1430,1560p;1660,1995p;2290,2330p;2535,2635p'
nl -ba test/safe/run.mjs | sed -n '100,230p;245,275p;520,705p;710,900p'
nl -ba test/safe/check_matrix.mjs | sed -n '1,150p'
nl -ba test/safe/fixtures/jp/jp_legal_matrix_alpha4.json | sed -n '1,180p'
nl -ba test/safe/fixtures/jp/gen.py | sed -n '90,215p'" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
   780	  license:{icon:'🚗',risk:'no'}, card:{icon:'💳',risk:'no'}, account:{icon:'🏦',risk:'no'},
   781	  phone:{icon:'📞',risk:'no'}, email:{icon:'✉️',risk:'no'}, birth:{icon:'🎂',risk:'no'},
   782	  address:{icon:'📍',risk:'no'}, name:{icon:'👤',risk:'no'},
   783	  company:{icon:'🏢',risk:'ok'}, title:{icon:'💼',risk:'ok'},
   784	  ip:{icon:'🌐',risk:'no'}, url:{icon:'🔗',risk:'no'}, health:{icon:'🏥',risk:'no'},
   785	  // 'other' = "분류 불확실". 불확실한 것을 기본 마스킹하면 시험명·수상명·자격증명 같은
   786	  // 비(非)PII 본문이 자동으로 훼손된다(예: TOPIK→TOP**). 확실한 유형만 기본 마스킹하고
   787	  // other 는 기본 공개(ok) 후 사용자가 필요 시 직접 켠다. (오탐 본문 훼손 방지)
   788	  other:{icon:'📌',risk:'ok'}
   789	};
   790	Object.keys(TYPES).forEach(t=>{catEnabled[t]=true;catDefault[t]=TYPES[t].risk;});
   791	/* `e.legal` = a band the Japanese legal matrix grounds in statute (番号法 /
   792	   告知要求制限 / 住民基本台帳法). It is NOT governed by the general category
   793	   checkboxes: 二次元コード and 裏面全体 map to the catch-all 'other' type, so
   794	   unticking 「その他」 silently deleted the マイナカード裏面 band and the
   795	   資格確認書 QR band from the output (Codex 4-6). Those can only be released
   796	   one item at a time, and the release warns. */
   797	const isOn=e=>e.legal?true:catEnabled[e.type]!==false;
   798	const tLabel=t=>T().types[t]||t;
   799	
   800	/* ───────── lazy library loaders ───────── */
   801	const _scripts={};
   802	function loadScript(src){return _scripts[src]||(_scripts[src]=new Promise((res,rej)=>{const s=document.createElement('script');s.src=src;s.async=true;s.onload=res;s.onerror=()=>rej(new Error('load fail '+src));document.head.appendChild(s);}));}
   803	async function ensureTesseract(){ if(!window.Tesseract) await loadScript(CDN_TESSERACT); return window.Tesseract; }
   804	async function ensureHeic(){ if(!window.heic2any) await loadScript(CDN_HEIC); return window.heic2any; }
   805	async function ensureJsPDF(){ if(!(window.jspdf&&window.jspdf.jsPDF)) await loadScript(CDN_JSPDF); return window.jspdf; }
   806	function OCR_LANGS(){ return ({ko:'kor+eng',en:'eng',ja:'jpn+eng',es:'spa+eng'})[LANG]||'eng'; }
   807	
   808	/* ───────── hero cycle ───────── */
   809	let cw=0;
   810	function renderHero(){
   811	  $('heroH1').innerHTML = T().heroPre + `<span class="redact-word"><span id="cycleWord">${T().cycle[cw]}</span><span class="bar" aria-hidden="true"></span></span>` + T().heroPost;
   812	}
   813	setInterval(()=>{cw=(cw+1)%T().cycle.length;const el=$('cycleWord');if(el)el.textContent=T().cycle[cw];},3600);
   814	
   815	/* ───────── apply language ───────── */
  1190	  shikaku_kakuninsho: { min: 4, title: ['資格確認書'], kw: [['資格確認書',3],['保険者番号',2],['被保険者',2],['保険者名',2],
  1191	      ['国民健康保険',2],['後期高齢者',2],['枝番',2],['記号',1],['健康保険',1],['一部負担金',1]] },
  1192	  unten_menkyo: { min: 4, title: ['運転免許証'], kw: [['運転免許証',4],['免許証',2],['公安委員会',2],['備考欄',2],
  1193	      ['臓器提供',1],['提供意思',1],['優良',1],['原付',1]] },
  1194	  mynumber_card: { min: 4, title: ['個人番号カード','マイナンバーカード'], kw: [['個人番号カード',4],['マイナンバーカード',4],['個人番号',2],
  1195	      ['券面記載事項',2],['マイナンバー',2]] },
  1196	  juminhyo: { min: 4, title: ['住民票'], kw: [['住民票',3],['世帯主',2],['続柄',2],['筆頭者',2],['世帯全員',2],
  1197	      ['住民となった日',2],['住民票コード',2],['本籍',1],['住民となつた日',2]] },
  1198	};
  1199	/* Does this page LOOK Japanese-official even though no class reached threshold?
  1200	   Any one of the four document names, or a 和暦 era marker, is enough. This is
  1201	   not a classification — it is the trigger for telling the user that automatic
  1202	   masking did NOT run, which is the failure the previous build was silent about
  1203	   (a single garbled label dropped the whole JP preset and nothing said so). */
  1204	const JP_SUSPECT_RE = /資格確認書|免許証|個人番号|マイナンバー|住民票|令和|平成|昭和/;
  1205	function jpSuspect(pi){ return JP_SUSPECT_RE.test(jpPageText(pi)); }
  1206	function jpPageText(pi){
  1207	  const page = pages[pi];
  1208	  if (page._jptext != null) return page._jptext;
  1209	  let s = ''; for (const it of page.items) s += jpNorm(it.str || '').t;
  1210	  return (page._jptext = s);
  1211	}
  1212	/* Classification has two outcomes that are NOT the same thing:
  1213	     confident  — score >= min. The legal preset applies as written.
  1214	     low        — score < min but the document's own TITLE was read. We know
  1215	                  which form this is, and we do not know it well enough to
  1216	                  delete pixels on our own: every level is demoted to a review
  1217	                  candidate (see jpApply) and the warning banner stays up.
  1218	   Below both, the page is 一般文書 and no Japanese rule runs at all — which is
  1219	   precisely when the banner has to say so (Codex 1-1). */
  1220	function jpClassify(pi){
  1221	  const txt = jpPageText(pi);
  1222	  let best = null, low = null;
  1223	  for (const [id, def] of Object.entries(JP_CLASSES)){
  1224	    let score = 0, hits = [];
  1225	    for (const [k, w] of def.kw) if (txt.includes(k)) { score += w; hits.push(k); }
  1226	    if (score >= def.min && (!best || score > best.score)) best = { doc: id, score, hits };
  1227	    else if (score < def.min && def.title.some(t => txt.includes(t)) && (!low || score > low.score))
  1228	      low = { doc: id, score, hits, low: true };
  1229	  }
  1230	  if (!best) best = low;
  1231	  if (!best) return null;
  1232	  // Side: cards have two faces with completely different legal treatment.
  1233	  if (best.doc === 'mynumber_card' || best.doc === 'unten_menkyo'){
  1234	    best.side = txt.includes('裏面') ? 'back' : txt.includes('表面') ? 'front'
  1235	              : (best.doc === 'mynumber_card' && /\d[\d\s.\-]{10,}\d/.test(txt)) ? 'back' : 'front';
  1236	  }
  1237	  return best;
  1238	}
  1239	
  1240	/* ── 個人番号 check digit ──
  1241	   Source: 行政手続における特定の個人を識別するための番号の利用等に関する法律の
  1242	   規定による通知カード及び個人番号カード並びに情報提供ネットワークシステムによる
  1243	   特定個人情報の提供等に関する省令 **第5条**
  1244	   (https://laws.e-gov.go.jp/document?lawid=426M60000008085_20231215_505M60004008017).
  1245	   NOT 番号法施行令 別表 — that was the citation here until 2026-10-21 and it was
  1246	   wrong; the arithmetic below was always right (Codex 1-5).
  1247	   Σ P_n·Q_n over the 11-digit body counted from the RIGHT (n = 1..11),
  1248	   Q_n = n+1 for n ≤ 6 else n−5; check = 11 − (Σ mod 11), and ≥10 → 0.
  1249	   (The 省令 states it as: remainder 0 or 1 → check digit 0. Equivalent — a
  1250	   remainder of 0 gives 11 and of 1 gives 10, both folded to 0 by the ≥10 rule.) */
  1251	function myNumberCheckOk(d12){
  1252	  if (!/^\d{12}$/.test(d12)) return false;
  1253	  const d = d12.slice(0, 11).split('').map(Number);
  1254	  let s = 0;
  1255	  for (let n = 1; n <= 11; n++){ const q = n <= 6 ? n + 1 : n - 5; s += d[11 - n] * q; }
  1256	  let chk = 11 - (s % 11); if (chk >= 10) chk = 0;
  1257	  return chk === Number(d12[11]);
  1258	}
  1259	
  1260	/* ── pixel helpers for field FRAMES and code blocks ──
  1261	   A 欄 (field box) is drawn as a thin rectangle; its contents may be empty, so
  1262	   there is nothing for a text-based detector to find. Scanning for the drawn
  1263	   rule is the only way to cover 臓器提供意思表示欄 on a card whose box the
  1264	   holder left blank — and a blank-looking box is exactly where a faint
  1265	   handwritten mark hides. */
  1266	function jpPageBg(page){
  1267	  if (page._jpbg) return page._jpbg;
  1268	  const ctx = page.canvas.getContext('2d', { willReadFrequently: true });
  1269	  const W = page.canvas.width, H = page.canvas.height;
  1270	  const pick = [];
  1430	   all. There is deliberately no "default to optional" fallback — the matrix
  1431	   enumerates every purpose it means to allow, and silence is not permission
  1432	   (Codex 4-2). */
  1433	const P_NOT_MYNUM = ['identity_submit','bid_attachment','consult_share'];
  1434	const P_ID_BID = ['identity_submit','bid_attachment'];
  1435	const P_ID_CONSULT = ['identity_submit','consult_share'];
  1436	// Shared by all four documents (matrix: general_jp): neither a free-standing
  1437	// address nor a phone number is part of what any of them has to prove, so both
  1438	// are always OFFERED — and recommended when the point of sharing is advice.
  1439	// Both are verified:false in the matrix, so neither may ever be auto/gate.
  1440	const JP_EXTRA = { address_loose: { recommend: ['consult_share'], optional: ['identity_submit','my_number_procedure','bid_attachment'] },
  1441	                   tel:           { recommend: ['consult_share'], optional: ['identity_submit','my_number_procedure','bid_attachment'] } };
  1442	// 本人特定事項: must-keep where the recipient is checking identity, offered
  1443	// (default OFF) where no recipient requirement exists at all.
  1444	const KEEP_ID_BID  = { keep: P_ID_BID, optional: ['consult_share'] };
  1445	const JP_RULES = {
  1446	  shikaku_kakuninsho: {
  1447	    // 健康保険法等 告知要求制限 (2020-10-01) — mhlw.go.jp/stf/newpage_13989.html
  1448	    hokensha_bango:   { auto: P_NOT_MYNUM },
  1449	    kigo:             { auto: P_NOT_MYNUM },
  1450	    bango:            { auto: P_NOT_MYNUM },
  1451	    edaban:           { auto: P_NOT_MYNUM },
  1452	    hihokensha_bango: { auto: P_NOT_MYNUM },
  1453	    // QRは番号を判読可能なため同一扱い（大阪府・千葉市運用）
  1454	    qr:               { auto: P_NOT_MYNUM },
  1455	    // 法定ではない。民間KYC運用（SoftBank, PayPay銀行等）
  1456	    sex:              { recommend: ['identity_submit'] },
  1457	    name: KEEP_ID_BID, birth: KEEP_ID_BID, address: KEEP_ID_BID, expiry: KEEP_ID_BID,
  1458	    // verified:false in the matrix — warning only, never automatic.
  1459	    jigyosho: KEEP_ID_BID, hokensha_name: KEEP_ID_BID, shikaku_date: KEEP_ID_BID,
  1460	    ...JP_EXTRA,
  1461	  },
  1462	  unten_menkyo: {
  1463	    biko_change:  { recommend: P_ID_CONSULT },
  1464	    organ_donor:  { recommend: P_ID_CONSULT },
  1465	    // 個人識別符号。KYCでは照合に必要な提出先が多い → 本人確認提出は must-keep,
  1466	    // 相談用共有は既定OFFで選択可。他の目的は matrix が명시しない → null.
  1467	    license_no:   { keep: ['identity_submit'], optional: ['consult_share'] },
  1468	    name:{keep:['identity_submit'],optional:['consult_share']}, birth:{keep:['identity_submit'],optional:['consult_share']},
  1469	    address:{keep:['identity_submit'],optional:['consult_share']}, expiry:{keep:['identity_submit'],optional:['consult_share']},
  1470	    ...JP_EXTRA,
  1471	  },
  1472	  mynumber_card: {
  1473	    // 番号法: 法令で認められた者・目的以外での個人番号の収集・保管禁止
  1474	    back_all:   { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1475	    my_number:  { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1476	    qr:         { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1477	    sex:        { recommend: ['identity_submit'] },
  1478	    organ_donor:{ recommend: ['identity_submit'] },
  1479	    name:{keep:['identity_submit','my_number_procedure'],optional:['consult_share']},
  1480	    birth:{keep:['identity_submit','my_number_procedure'],optional:['consult_share']},
  1481	    address:{keep:['identity_submit','my_number_procedure'],optional:['consult_share']},
  1482	    expiry:{keep:['identity_submit','my_number_procedure'],optional:['consult_share']},
  1483	    ...JP_EXTRA,
  1484	  },
  1485	  juminhyo: {
  1486	    my_number:  { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1487	    // 住民基本台帳法 利用制限（個人識別符号）と理解しているが出典を確保できていない
  1488	    // → matrix verified:false。既定ON で帯は引くが auto とは呼ばない。
  1489	    jumin_code: { recommend: P_NOT_MYNUM },
  1490	    honseki:    { recommend: P_ID_CONSULT, optional: ['my_number_procedure','bid_attachment'] },
  1491	    hittosha:   { recommend: P_ID_CONSULT, optional: ['my_number_procedure','bid_attachment'] },
  1492	    setaiin:    { recommend: P_ID_CONSULT, optional: ['my_number_procedure','bid_attachment'] },
  1493	    name: KEEP_ID_BID, birth: KEEP_ID_BID, address: KEEP_ID_BID, issuer: KEEP_ID_BID,
  1494	    ...JP_EXTRA,
  1495	  },
  1496	};
  1497	/* The legal-preset fields: the ones the matrix grounds in 番号法 / 告知要求制限 /
  1498	   住民基本台帳法 rather than in a submission-desk convention. They are NOT
  1499	   subject to the general category checkboxes — turning off 「その他」 used to
  1500	   silently remove the マイナカード裏面 band and the 資格確認書 QR band from the
  1501	   output, with no warning (Codex 4-6). They live in their own group and can only
  1502	   be released one item at a time. */
  1503	const JP_LEGAL_FIELDS = new Set(['back_all','qr','my_number','jumin_code',
  1504	  'hokensha_bango','kigo','bango','edaban','hihokensha_bango']);
  1505	function jpLevel(doc, field, purpose){
  1506	  const r = (JP_RULES[doc] || {})[field];
  1507	  if (!r) return null;
  1508	  for (const lv of ['auto','gate','recommend','optional','keep'])
  1509	    if (r[lv] && r[lv].includes(purpose)) return lv;
  1510	  return null;
  1511	}
  1512	
  1513	/* ── field extraction ─────────────────────────────────────────────────────
  1514	   Each rule is {field, labels[], re, last} — `labels` are the anchors accepted
  1515	   in the segment (several spellings, because OCR drops or swaps one character
  1516	   of a label far more often than it mangles a digit run), `re` is the value
  1517	   format, and `last` allows falling back to the segment's final item when the
  1518	   value itself was garbled but its POSITION is still certain (e.g. 性別 whose
  1519	   single kanji OCR read as "&" — the box is what we need, not the character). */
  1520	const JP_FIELD_RULES = {
  1521	  shikaku_kakuninsho: [
  1522	    { field:'hokensha_bango',   labels:['保険者番号','険者番号','保険者番'], re:/\d{4,10}/ },
  1523	    { field:'hihokensha_bango', labels:['被保険者番号','被保険者等記号','被保険者番'], re:/[0-9A-Z]{4,12}/ },
  1524	    { field:'kigo',   labels:['記号'], re:/[0-9A-Z]{2,12}/ },
  1525	    { field:'edaban', labels:['枝番'], re:/\d{1,3}/ },
  1526	    // 「番号」単独アンカー禁止 — it is a substring of 保険者番号/被保険者番号, so it
  1527	    // only counts when the segment actually STARTS with it (its own column).
  1528	    { field:'bango',  labels:['番号'], re:/[0-9A-Z]{1,12}/, headOnly:true },
  1529	    { field:'sex',    labels:['性別'], re:/[男女]/, last:true },
  1530	    { field:'name',   labels:['氏名'], re:null, last:true },
  1531	    { field:'birth',  labels:['生年月日'], re:null, last:true },
  1532	    { field:'address',labels:['住所'], re:null, last:true, addr:true },
  1533	    { field:'expiry', labels:['有効期限'], re:null, last:true },
  1534	    // These three carry a keep rule in the matrix (verified:false — warning
  1535	    // only). Without a detection rule the keep rule was dead code: the warning
  1536	    // it promises could never be shown. 資格取得年月日 holds 年月日, so the
  1537	    // numeric fallback already skips its row.
  1538	    { field:'shikaku_date',  labels:['資格取得年月日','資格取得'], re:null, last:true },
  1539	    { field:'hokensha_name', labels:['保険者名'], re:null, last:true },
  1540	    { field:'jigyosho',      labels:['事業所名称','事業所名'], re:null, last:true },
  1541	    { field:'tel',    labels:['電話番号','電話','TEL','携帯','FAX'], tel:true },
  1542	  ],
  1543	  // Front-only: the back carries a 住所変更 line inside 備考欄, and calling that
  1544	  // a keep-field would contradict the very region we are hiding.
  1545	  unten_menkyo: [
  1546	    { field:'license_no', labels:['番号'], re:/第?\s?[0-9A-Z]{10,14}/, headOnly:true, sides:['front'] },
  1547	    { field:'name',   labels:['氏名'], re:null, last:true, sides:['front'] },
  1548	    { field:'birth',  labels:['生年月日'], re:null, last:true, sides:['front'] },
  1549	    { field:'address',labels:['住所'], re:null, last:true, sides:['front'], addr:true },
  1550	    { field:'expiry', labels:['有効期限'], re:null, last:true, sides:['front'] },
  1551	  ],
  1552	  mynumber_card: [
  1553	    { field:'my_number', labels:['個人番号','マイナンバー'], digits:12 },
  1554	    { field:'sex',    labels:['性別'], re:/[男女]/, last:true, sides:['front'] },
  1555	    { field:'name',   labels:['氏名'], re:null, last:true },
  1556	    { field:'birth',  labels:['生年月日'], re:null, last:true },
  1557	    { field:'address',labels:['住所'], re:null, last:true, sides:['front'], addr:true },
  1558	    { field:'expiry', labels:['有効期限'], re:null, last:true, sides:['front'] },
  1559	  ],
  1560	  juminhyo: [
  1660	}
  1661	// Span of the first `n` digits after `from`, tolerating group separators.
  1662	function jpDigitSpan(seg, from, n){
  1663	  let first = -1, last = -1, count = 0;
  1664	  for (let k = from; k < seg.t.length; k++){
  1665	    const c = seg.t[k];
  1666	    if (isDigit(c)){ if (first < 0) first = k; last = k; if (++count === n) return { a:first, b:last+1, digits: seg.t.slice(first,last+1).replace(/\D/g,'') }; }
  1667	    else if (first >= 0 && !/[\s.\-・,/]/.test(c)) { first = -1; last = -1; count = 0; }
  1668	  }
  1669	  return null;
  1670	}
  1671	function jpExtract(pi, cls){
  1672	  const segs = jpSegments(pi), found = [];
  1673	  // Every value rule anchors at the SEGMENT HEAD. In these forms the label always
  1674	  // opens its own column, so a label found mid-segment is prose, not an anchor —
  1675	  // that is how the 「裏面の生年月日有無は…要確認」 footnote on the card dummy got
  1676	  // read as a 生年月日 field. (The 欄 region labels below deliberately do not use
  1677	  // this: OCR puts a garbled 騰 in front of 器提供意思表示欄.)
  1678	  const rules = (JP_FIELD_RULES[cls.doc] || [])
  1679	    .filter(r => !r.sides || r.sides.includes(cls.side))
  1680	    .map(r => ({ ...r, headOnly: true }));
  1681	  // Every finding carries the classification of ITS OWN page. A two-sided card
  1682	  // scanned into one PDF has a different legal rule on each page, so applying
  1683	  // page 1's doc/side to every page made the outcome depend on scan order:
  1684	  // front-then-back left the 個人番号 page untouched, back-then-front banded the
  1685	  // front as well (Codex 6-4).
  1686	  const push = (field, boxes, value, extra) => {
  1687	    if (boxes && boxes.length) found.push({ field, boxes, value, pi, doc: cls.doc, side: cls.side || null, low: !!cls.low, ...extra });
  1688	  };
  1689	
  1690	  for (const seg of segs){
  1691	    for (const r of rules){
  1692	      const L = jpFindLabel(seg, r.labels, r.headOnly);
  1693	      if (!L) continue;
  1694	      if (r.tel){
  1695	        const tail = seg.t.slice(L.end);
  1696	        const hy = JP_TEL_HYPHEN_RE.exec(tail);
  1697	        const pl = hy ? null : JP_TEL_PLAIN_RE.exec(tail);
  1698	        const m = hy || pl;
  1699	        if (!m) continue;
  1700	        const a2 = L.end + m.index, b2 = a2 + m[0].length;
  1701	        push('tel', jpBoxes(seg, a2, b2), m[0], { loose: !hy });
  1702	        for (let k = a2; k < b2; k++) seg.used[k] = 1;
  1703	        continue;
  1704	      }
  1705	      if (r.digits){
  1706	        const sp = jpDigitSpan(seg, L.end, r.digits);
  1707	        if (!sp) continue;
  1708	        const extra = r.field === 'my_number' ? { checkOk: myNumberCheckOk(sp.digits) } : {};
  1709	        push(r.field, jpBoxes(seg, sp.a, sp.b), sp.digits, extra);
  1710	        for (let k = sp.a; k < sp.b; k++) seg.used[k] = 1;
  1711	        continue;
  1712	      }
  1713	      let a = -1, b = -1, val = '';
  1714	      if (r.addr){
  1715	        // 住所/本籍: bound the value by the address hierarchy rather than by
  1716	        // "everything after the label", so a second column that drifted into
  1717	        // this segment is not swept into the band.
  1718	        const sp = jpAddressSpan(seg.t, L.end);
  1719	        if (sp && sp.b > sp.a){ a = sp.a; b = sp.b; val = seg.t.slice(a, b); }
  1720	      } else if (r.re){
  1721	        const m = r.re.exec(seg.t.slice(L.end));
  1722	        if (m){ a = L.end + m.index; b = a + m[0].length; val = m[0]; }
  1723	      }
  1724	      if (a < 0 && r.last !== true) continue;
  1725	      if (a < 0){
  1726	        // value position certain, characters not: take the items after the label
  1727	        const after = seg.items.filter(o => seg.start[o.i] >= L.end);
  1728	        if (!after.length) continue;
  1729	        const boxes = after.map(o => { const b2 = { page: pi, x:o.it.x, y:o.it.y, w:o.it.w, h:o.it.h }; b2.bg = sampleBg(pages[pi], b2); return b2; });
  1730	        push(r.field, boxes, seg.t.slice(L.end).trim() || '(value)');
  1731	        for (let k = L.end; k < seg.t.length; k++) seg.used[k] = 1;
  1732	        continue;
  1733	      }
  1734	      push(r.field, jpBoxes(seg, a, b), val.trim());
  1735	      for (let k = a; k < b; k++) seg.used[k] = 1;
  1736	    }
  1737	  }
  1738	
  1739	  /* Structural fallback — ONLY where OCR has destroyed the label but the format
  1740	     plus the document class still pin the field down. Each is narrow and stated:
  1741	       資格確認書: a bare 6–10 digit run outside any date line is a member of the
  1742	         保険者番号・記号・番号・枝番 family. The 告知要求制限 covers that whole
  1743	         family as ONE rule, so the cost of guessing which member it is, is zero —
  1744	         while a miss is the exact leak the product exists to prevent. Measured:
  1745	         OCR renders 保険者番号 as "RREES"/"REEES"/"WREEES" on 3 of 5 fixtures.
  1746	       住民票: 12 digits = 個人番号, 11 digits = 住民票コード. Both lengths are
  1747	         fixed by statute and nothing else on the form is that long. */
  1748	  const isDateRow = s => JP_DATE_RE.test(s.rowText) || s.rowText.includes('〒');
  1749	  const unconsumed = (seg, a, b) => { for (let k=a;k<b;k++) if (seg.used[k]) return false; return true; };
  1750	  const runs = seg => { const out=[]; let st=-1;
  1751	    for (let k=0;k<=seg.t.length;k++){ const d = k<seg.t.length && isDigit(seg.t[k]);
  1752	      if (d){ if (st<0) st=k; } else if (st>=0){ out.push([st,k]); st=-1; } } return out; };
  1753	  if (cls.doc === 'shikaku_kakuninsho'){
  1754	    for (const seg of segs){
  1755	      if (isDateRow(seg)) continue;
  1756	      for (const [a,b] of runs(seg)){
  1757	        const len = b - a;
  1758	        if (len < 6 || len > 10 || !unconsumed(seg, a, b)) continue;
  1759	        push('hokensha_bango', jpBoxes(seg, a, b), seg.t.slice(a,b), { viaFallback: true });
  1760	        for (let k=a;k<b;k++) seg.used[k]=1;
  1761	      }
  1762	    }
  1763	  }
  1764	  if (cls.doc === 'juminhyo'){
  1765	    for (const seg of segs){
  1766	      if (isDateRow(seg)) continue;
  1767	      for (const [a,b] of runs(seg)){
  1768	        const len = b - a;
  1769	        if (!unconsumed(seg, a, b)) continue;
  1770	        if (len === 12) push('my_number', jpBoxes(seg, a, b), seg.t.slice(a,b), { checkOk: myNumberCheckOk(seg.t.slice(a,b)), viaFallback: true });
  1771	        else if (len === 11) push('jumin_code', jpBoxes(seg, a, b), seg.t.slice(a,b), { viaFallback: true });
  1772	        else continue;
  1773	        for (let k=a;k<b;k++) seg.used[k]=1;
  1774	      }
  1775	    }
  1776	  }
  1777	
  1778	  /* Unlabelled addresses. Anything a label already claimed is marked consumed,
  1779	     so this only sees text standing on its own — 備考欄 contents, free-form
  1780	     notes. Per strategy v2 §3-2 it is automatic ONLY with 郵便番号 AND 都道府県
  1781	     together; otherwise it is a review candidate. It is filed under its own
  1782	     field key so it can never be confused with the LABELLED 住所, which on all
  1783	     four alpha documents is a keep-field the recipient needs. */
  1784	  for (const seg of segs){
  1785	    let from = 0;
  1786	    for (let guard = 0; guard < 4; guard++){
  1787	      const sp = jpAddressSpan(seg.t, from);
  1788	      if (!sp || sp.b <= sp.a) break;
  1789	      from = sp.b;
  1790	      if (sp.score < 3) continue;
  1791	      let free = true; for (let k = sp.a; k < sp.b; k++) if (seg.used[k]) { free = false; break; }
  1792	      if (!free) continue;
  1793	      push('address_loose', jpBoxes(seg, sp.a, sp.b), seg.t.slice(sp.a, sp.b), { strong: sp.postal && sp.pref });
  1794	      for (let k = sp.a; k < sp.b; k++) seg.used[k] = 1;
  1795	    }
  1796	  }
  1797	
  1798	  // 欄 regions (備考欄 / 臓器提供意思表示欄): the drawn rectangle under the label.
  1799	  for (const rr of (JP_REGION_LABELS[cls.doc] || [])){
  1800	    for (const seg of segs){
  1801	      if (!jpFindLabel(seg, rr.labels, false)) continue;
  1802	      const fr = jpFrameBelow(pages[pi], { y: seg.y, h: seg.h });
  1803	      const box = fr ? { ...fr, page: pi }
  1804	                     : { page: pi, x: seg.x0, y: seg.y, w: Math.max(seg.x1-seg.x0, pages[pi].w*0.5), h: seg.h*3.5, region: true };
  1805	      push(rr.field, [box], rr.field);
  1806	      break;
  1807	    }
  1808	  }
  1809	
  1810	  // 二次元コード
  1811	  if (cls.doc === 'shikaku_kakuninsho' || (cls.doc === 'mynumber_card' && cls.side === 'back')){
  1812	    for (const cb of jpCodeBlocks(pi)) push('qr', [cb.box], '二次元コード', { unlabelledCode: !cb.labelled });
  1813	  }
  1814	
  1815	  // 住民票: household member blocks. Block 1 is the subject; blocks 2..n are
  1816	  // third parties whose data the recipient did not ask for. Found by the 氏名
  1817	  // label rows, because 続柄 (本人/妻/子) is a single kanji that OCR mangles far
  1818	  // more often than it mangles a whole label.
  1819	  if (cls.doc === 'juminhyo'){
  1820	    const nameRows = segs.filter(s => jpFindLabel(s, ['氏名'], false)).sort((a,b)=>a.y-b.y);
  1821	    const endRe = /住民票コード|この写し|相違|証明し|市長|区長|町長|村長|公印/;
  1822	    if (nameRows.length > 1){
  1823	      for (let i = 1; i < nameRows.length; i++){
  1824	        const top = nameRows[i].y;
  1825	        const next = i + 1 < nameRows.length ? nameRows[i+1].y : Infinity;
  1826	        const stop = segs.filter(s => s.y > top && s.y < next && endRe.test(s.rowText)).map(s=>s.y);
  1827	        const bottom = stop.length ? Math.min(...stop) : next;
  1828	        const byRow = {};
  1829	        for (const s of segs){
  1830	          if (s.y < top || s.y >= bottom) continue;
  1831	          (byRow[s.row] = byRow[s.row] || []).push(s);
  1832	        }
  1833	        for (const list of Object.values(byRow))
  1834	          push('setaiin', list.map(jpSegBox), (list[0].t || '(世帯員)').slice(0, 24));
  1835	      }
  1836	    }
  1837	    // 氏名/生年月日 inside a THIRD PARTY's block are not the subject's keep-fields.
  1838	    // Leaving them in would put the same pixels in the 残す項目 list and under a
  1839	    // band at the same time — the list would be telling the user the opposite of
  1840	    // what the page shows.
  1841	    const regions = found.filter(f => f.field === 'setaiin').flatMap(f => f.boxes);
  1842	    if (regions.length){
  1843	      const inside = b => regions.some(r => b.x + b.w/2 >= r.x && b.x + b.w/2 <= r.x + r.w
  1844	                                         && b.y + b.h/2 >= r.y && b.y + b.h/2 <= r.y + r.h);
  1845	      for (let i = found.length - 1; i >= 0; i--){
  1846	        const f = found[i];
  1847	        if (!['name','birth','address'].includes(f.field)) continue;
  1848	        if (f.boxes.every(inside)) found.splice(i, 1);
  1849	      }
  1850	    }
  1851	  }
  1852	  return found;
  1853	}
  1854	
  1855	/* ── state + application ── */
  1856	const JP_PURPOSES = ['identity_submit','my_number_procedure','bid_attachment','consult_share'];
  1857	const JP_STATE0 = () => ({ cls: null, pageCls: [], purpose: 'identity_submit', findings: [], warn: null, mnConfirmed: false });
  1858	let jpState = JP_STATE0();
  1859	function jpScan(){
  1860	  const keepPurpose = jpState.purpose;
  1861	  jpState = JP_STATE0(); jpState.purpose = keepPurpose;
  1862	  if (!pages.length) return null;
  1863	  // Per-page classification. Page 0 names the document in the UI, but each page
  1864	  // is governed by its OWN class — and a page that cannot be classified falls
  1865	  // back to page 0's class only when page 0 HAS one.
  1866	  const cls0 = jpClassify(0);
  1867	  const pageCls = [];
  1868	  for (let pi = 0; pi < pages.length; pi++) pageCls.push(pi === 0 ? cls0 : (jpClassify(pi) || cls0));
  1869	  jpState.pageCls = pageCls;
  1870	  if (!cls0){
  1871	    // No Japanese rule will run. Say so if the page looks like one of these
  1872	    // documents, instead of falling through to the Latin heuristics in silence.
  1873	    if (pages.some((p, pi) => jpSuspect(pi))) jpState.warn = 'unclassified';
  1874	    return null;
  1875	  }
  1876	  jpState.cls = cls0;
  1877	  if (pageCls.some(c => c && c.low)) jpState.warn = 'lowconf';
  1878	  let all = [];
  1879	  for (let pi = 0; pi < pages.length; pi++) if (pageCls[pi]) all = all.concat(jpExtract(pi, pageCls[pi]));
  1880	  jpState.findings = all;
  1881	  return cls0;
  1882	}
  1883	function jpFieldLabel(f){ return (T().jpFields && T().jpFields[f]) || f; }
  1884	// Build entities from the findings for the current purpose. Called on load and
  1885	// on every purpose change — the purpose IS the policy, so it re-derives rather
  1886	// than patching modes in place.
  1887	/* The 個人番号 purpose gate needs more than a dropdown. Choosing 「個人番号手続」
  1888	   releases a band that 番号法 put there, and the dropdown alone cannot establish
  1889	   that the recipient actually performs a 個人番号関係事務 — PPC FAQ Q6-12
  1890	   distinguishes seeing a number from copying and keeping it, and both assume the
  1891	   recipient is entitled to it (Codex 4-4). So the release requires the purpose
  1892	   AND an explicit confirmation; until it is given, the band stays. */
  1893	function jpMnGateOpen(){ return jpState.purpose === 'my_number_procedure' && jpState.mnConfirmed; }
  1894	const JP_MN_GATED = new Set(['back_all','my_number','qr']);
  1895	function jpApply(){
  1896	  entities = entities.filter(e => !e.jp);
  1897	  const cls = jpState.cls; if (!cls) { jpRenderBar(); renderAll(); return; }
  1898	  const purpose = jpState.purpose;
  1899	  const add = (f, level, boxes, value, note, ctx) => {
  1900	    const kind = (level === 'auto' || level === 'gate') ? 'auto'
  1901	               : level === 'keep' ? 'keep' : 'candidate';
  1902	    const mode = (level === 'auto' || level === 'gate' || level === 'recommend') ? 'no' : 'ok';
  1903	    // A legal-preset band is not governed by the general category checkboxes.
  1904	    const legal = JP_LEGAL_FIELDS.has(f) && mode === 'no';
  1905	    entities.push({ id:'j'+Math.random().toString(36).slice(2,8), type: JP_TYPE[f] || 'other',
  1906	      value, mode, kind, legal, reason: 'jp_' + level, boxes,
  1907	      jp: { doc: (ctx && ctx.doc) || cls.doc, side: (ctx && ctx.side) || cls.side || null, page: ctx ? ctx.page : null, field: f, level, note: note || null } });
  1908	  };
  1909	  // Resolve the level for one finding under the current purpose, including the
  1910	  // two demotions and the confirmation gate. Returns null = not offered.
  1911	  const resolve = (doc, field, f) => {
  1912	    let level = jpLevel(doc, field, purpose), note = null;
  1913	    if (!level) return null;
  1914	    // Unconfirmed 個人番号手続: the matrix says keep, but the release has not
  1915	    // been confirmed, so the 番号法 band stays as if the purpose were 本人確認.
  1916	    if (level === 'keep' && JP_MN_GATED.has(field) && purpose === 'my_number_procedure' && !jpState.mnConfirmed){
  1917	      level = 'gate'; note = 'mn_unconfirmed';
  1918	    }
  1919	    // A low-confidence classification may not delete pixels on its own.
  1920	    if (f && f.low && (level === 'auto' || level === 'gate')){ level = 'recommend'; note = 'lowconf'; }
  1921	    if (!f) return { level, note };
  1922	    // 個人番号 whose check digit does not verify is NOT confirmed to be a
  1923	    // 個人番号 — it could be any 12-digit reference. Demote the automatic band
  1924	    // to a review candidate (still default-ON) rather than assert something the
  1925	    // arithmetic contradicts.
  1926	    if (field === 'my_number' && (level === 'auto' || level === 'gate') && f.checkOk === false){ level = 'recommend'; note = 'checkdigit'; }
  1927	    // An unlabelled square block has no QR-specific evidence behind it (no
  1928	    // finder pattern, no quiet zone, no module pitch) and no golden coverage —
  1929	    // a face photo, a round seal (bbox fill ≈ 0.785) or a black table header
  1930	    // can all satisfy the size/ratio/fill test. It is OFFERED and left OFF:
  1931	    // a guess must not remove content from the default output (Codex 2-2, 6-1).
  1932	    if (f.unlabelledCode){ level = 'optional'; note = 'unlabelled_code'; }
  1933	    return { level, note };
  1934	  };
  1935	
  1936	  // マイナンバーカード裏面 under a 本人確認 purpose: the whole face, PER PAGE that
  1937	  // is actually a back face. 番号法 does not let the recipient hold the 個人番号
  1938	  // at all for identity checking, so the honest instruction is "submit the front
  1939	  // instead", and the band says so.
  1940	  for (let pi = 0; pi < pages.length; pi++){
  1941	    const pc = jpState.pageCls[pi];
  1942	    if (!pc || pc.doc !== 'mynumber_card' || pc.side !== 'back') continue;
  1943	    const r = resolve('mynumber_card', 'back_all', { low: pc.low });
  1944	    if (r && (r.level === 'auto' || r.level === 'gate' || r.level === 'recommend'))
  1945	      add('back_all', r.level, [{ page: pi, x: 0, y: 0, w: pages[pi].w, h: pages[pi].h, region: true }],
  1946	          jpFieldLabel('back_all'), r.note, { doc: pc.doc, side: pc.side, page: pi });
  1947	  }
  1948	  for (const f of jpState.findings){
  1949	    const r = resolve(f.doc, f.field, f);
  1950	    if (!r) continue;
  1951	    add(f.field, r.level, f.boxes, f.field === 'qr' || f.boxes.some(b=>b.region) ? jpFieldLabel(f.field) : (f.value || jpFieldLabel(f.field)),
  1952	        r.note, { doc: f.doc, side: f.side, page: f.pi });
  1953	  }
  1954	  entities.sort((a,b)=>Object.keys(TYPES).indexOf(a.type)-Object.keys(TYPES).indexOf(b.type));
  1955	  jpRenderBar();
  1956	  renderAll();
  1957	}
  1958	const JP_TYPE = { address_loose:'address', tel:'phone', my_number:'rrn', jumin_code:'rrn', hokensha_bango:'health', kigo:'health',
  1959	  bango:'health', edaban:'health', hihokensha_bango:'health', license_no:'license', qr:'other',
  1960	  back_all:'other', biko_change:'address', organ_donor:'health', setaiin:'name', honseki:'address',
  1961	  hittosha:'name', sex:'other', name:'name', birth:'birth', address:'address', expiry:'other', issue:'other' };
  1962	
  1963	function jpSetPurpose(p){
  1964	  if (!JP_PURPOSES.includes(p)) return;
  1965	  jpState.purpose = p;
  1966	  // Switching purpose always re-asks for the 個人番号 confirmation. A checkbox
  1967	  // left ticked from a previous purpose is not a confirmation of this one.
  1968	  jpState.mnConfirmed = false;
  1969	  const sel = $('jpPurpose'); if (sel) sel.value = p;
  1970	  jpApply();
  1971	}
  1972	function jpSetMnConfirmed(v){ jpState.mnConfirmed = !!v; jpApply(); }
  1973	function jpRenderBar(){
  1974	  const bar = $('jpBar'), warn = $('jpWarn'); if (!bar) return;
  1975	  const cls = jpState.cls;
  1976	  // The blocking warning is independent of the bar: its whole point is to be
  1977	  // visible in the case where there is no classification and therefore no bar.
  1978	  if (warn){
  1979	    const show = !!jpState.warn;
  1980	    warn.textContent = show ? T().jpUnclassifiedWarn : '';
  1981	    warn.style.display = show ? 'block' : 'none';
  1982	  }
  1983	  if (!cls){ bar.style.display = 'none'; return; }
  1984	  bar.style.display = 'flex';
  1985	  $('jpDocName').textContent = jpFieldLabel('doc_' + cls.doc) + (cls.side ? ' · ' + jpFieldLabel('side_' + cls.side) : '');
  1986	  const sel = $('jpPurpose');
  1987	  sel.innerHTML = JP_PURPOSES.map(p => `<option value="${p}">${escapeHtml(jpFieldLabel('purpose_' + p))}</option>`).join('');
  1988	  sel.value = jpState.purpose;
  1989	  const note = $('jpNote');
  1990	  // The notice is shown whenever this document HAS a 個人番号 rule — including
  1991	  // after the user switched to 個人番号手続, where it is the text that explains
  1992	  // what the confirmation below it means.
  1993	  const hasMn = jpState.findings.some(f => f.field === 'my_number')
  1994	    || jpState.pageCls.some(c => c && c.doc === 'mynumber_card' && c.side === 'back');
  1995	  note.textContent = hasMn ? T().jpBackNotice : '';
  2290	    entities=[]; aiDone=false; showAllCats=false;
  2291	    addEntities(regexScan(docText));
  2292	    // A classified Japanese document gets its own preset. The Latin name/address
  2293	    // heuristics are suppressed there — they are tuned for résumé typography and
  2294	    // on a JP form they only ever produced junk ("(被用者", "カー", "裏面"), which
  2295	    // would sit next to the legally-grounded preset looking equally authoritative.
  2296	    const jp = jpScan();
  2297	    if(!jp){
  2298	      addEntities(nameCandidates());     // conservative top-of-doc name suggestion (defaults to visible)
  2299	      addEntities(addressCandidates());  // place/city lines without a number → review candidates
  2300	    }
  2301	    setStatus(T().scanDone(entities.filter(e=>e.kind!=='candidate').length)); setProg(0);
  2302	  }
  2303	  const ab=$('btnAI'); if(!aiDone){ ab.disabled=false; }
  2304	  buildPreview();
  2305	  if(jpState.cls){
  2306	    jpApply();
  2307	    // The status line is written before the preset runs, so on a JP document it
  2308	    // used to report "0 found" next to a list of five bands. Keep-fields are not
  2309	    // "found personal info" — they are what the recipient needs — so they do not count.
  2310	    if(!keepEntities) setStatus(T().scanDone(entities.filter(e=>e.kind!=='keep'&&e.kind!=='manual').length));
  2311	  } else { jpRenderBar(); renderAll(); }
  2312	}
  2313	function resetResult(){ $('result').style.display='none'; lastOut=null; }
  2314	function resetAll(){
  2315	  pages=[]; docText=''; entities=[]; aiDone=false; showAllCats=false; previewCanvases=[];
  2316	  jpState=JP_STATE0(); jpRenderBar();
  2317	  $('docWrap').style.display='none'; dz.style.display='flex'; $('preview').innerHTML=''; clearDzAlert();
  2318	  if(typeof setSelectMode==='function') setSelectMode(false);
  2319	  setStatus(''); setProg(0); resetResult();
  2320	  const ab=$('btnAI'); ab.disabled=true; ab.innerHTML='🤖 <span data-i18n="btnAI">'+T().btnAI+'</span>';
  2321	  renderAll();
  2322	}
  2323	
  2324	/* ───────── entities ───────── */
  2325	function addEntities(list){
  2326	  for(const e of list){
  2327	    const v=(e.value||'').trim(); if(!v||v.replace(/\s/g,'').length<2) continue;
  2328	    let type=TYPES[e.type]?e.type:'other';
  2329	    let kind=e.kind||'auto', reason=e.reason||null;
  2330	    // Country / nationality is never PII — drop it regardless of proposed type
  2535	  const pi=+s.cv.dataset.pi, scale=+s.cv.dataset.scale, page=pages[pi];
  2536	  const dx=Math.min(s.x0,s.x1), dy=Math.min(s.y0,s.y1), dw=Math.abs(s.x1-s.x0), dh=Math.abs(s.y1-s.y0);
  2537	  if(dw<8||dh<8){ drawPreview(); toast(T().tSelSmall); return; }
  2538	  // region:true — the drag rectangle IS the intent; bandRect must not grow it.
  2539	  const box={page:pi, x:dx/scale, y:dy/scale, w:dw/scale, h:dh/scale, region:true}; // display px → page px
  2540	  box.bg=sampleBg(page,box);
  2541	  entities.push({id:'e'+Math.random().toString(36).slice(2,8),type:'manual',value:'('+T().manualItem+')',mode:'no',kind:'manual',boxes:[box]});
  2542	  renderAll();
  2543	  toast(T().tManualAdded);
  2544	}
  2545	$('btnSelect').addEventListener('click',()=>setSelectMode(!selectMode));
  2546	$('jpPurpose').addEventListener('change',e=>jpSetPurpose(e.target.value));
  2547	
  2548	/* ───────── detection list (live value next to toggle) ───────── */
  2549	function catRowHtml(type,items){
  2550	  const on=catEnabled[type], d=catDefault[type], t=T();
  2551	  return `
  2552	  <div class="cat-row ${on?'':'off'}">
  2553	    <div class="cat-head">
  2554	      <label class="cat-tgl">
  2555	        <input type="checkbox" data-cat="${type}" ${on?'checked':''}>
  2556	        <span class="cl">${TYPES[type].icon} ${tLabel(type)}</span>
  2557	      </label>
  2558	      <span class="cnt ${items.length?'hit':''}">${items.length? t.cnt(items.length) : ''}</span>
  2559	      <div class="seg" data-cat-seg="${type}" role="radiogroup">
  2560	        <button class="${d==='ok'?'on-ok':''}" data-cmode="ok">${t.segOk}</button>
  2561	        <button class="${d==='no'?'on-no':''}" data-cmode="no">${t.segNo}</button>
  2562	      </div>
  2563	    </div>
  2564	    ${items.length?`<div class="cat-items">${items.map(e=>`
  2565	      <div class="pii-item${located(e)?'':' nolocate'}">
  2566	        <span class="val mono" title="${escapeHtml(e.value)}">${escapeHtml(displayValue(e))}</span>
  2567	        ${located(e)?'':`<span class="nl">${t.notLocated}</span>`}
  2568	        <div class="seg" role="radiogroup">
  2569	          <button class="${e.mode==='ok'?'on-ok':''}" data-id="${e.id}" data-mode="ok">${t.segOk}</button>
  2570	          <button class="${e.mode==='no'?'on-no':''}" data-id="${e.id}" data-mode="no">${t.segNo}</button>
  2571	        </div>
  2572	      </div>`).join('')}</div>`:''}
  2573	  </div>`;
  2574	}
  2575	// Flat item box for manual selections / name candidates (not category-grouped).
  2576	function sectionHtml(kind,title,items){
  2577	  const t=T(), cand=kind==='candidate';
  2578	  const icon=kind==='candidate'?'❓':kind==='keep'?'🛡':kind==='legal'?'⚖️':'✏️';
  2579	  return `
  2580	  <div class="cat-row sec-${kind}">
  2581	    <div class="cat-head">
  2582	      <span class="cl">${icon} ${title}</span>
  2583	      <span class="cnt hit">${t.cnt(items.length)}</span>
  2584	    </div>
  2585	    <div class="cat-items">${items.map(e=>`
  2586	      <div class="pii-item${cand?' is-cand':''}">
  2587	        <div class="val-wrap">
  2588	          <span class="val ${cand?'':'mono'}" title="${escapeHtml(e.value)}">${escapeHtml(kind==='manual'? t.manualItem : displayValue(e))}</span>
  2589	          ${(cand||kind==='keep'||kind==='legal')?`<span class="reason">${(TYPES[e.type]||{}).icon||''} ${t.reasons[e.reason]||(e.jp?t.reasons.jp_keep:t.reasons.name)}</span>`:''}
  2590	        </div>
  2591	        <div class="seg" role="radiogroup">
  2592	          <button class="${e.mode==='ok'?'on-ok':''}" data-id="${e.id}" data-mode="ok">${t.segOk}</button>
  2593	          <button class="${e.mode==='no'?'on-no':''}" data-id="${e.id}" data-mode="no">${t.segNo}</button>
  2594	        </div>
  2595	        ${kind==='manual'?`<button class="del" data-del="${e.id}" title="remove" aria-label="remove">✕</button>`:''}
  2596	      </div>`).join('')}</div>
  2597	  </div>`;
  2598	}
  2599	function renderList(){
  2600	  const list=$('piiList'), t=T();
  2601	  // Legal-preset bands come out of the category grouping entirely — they are not
  2602	  // a "type" the user turns off, they are a rule with a citation.
  2603	  const legalE=entities.filter(e=>e.legal);
  2604	  const autoE=entities.filter(e=>!e.legal&&e.kind!=='candidate'&&e.kind!=='manual'&&e.kind!=='keep');
  2605	  const manualE=entities.filter(e=>!e.legal&&e.kind==='manual');
  2606	  const candE=entities.filter(e=>!e.legal&&e.kind==='candidate');
  2607	  const keepE=entities.filter(e=>!e.legal&&e.kind==='keep');
  2608	  const total=entities.filter(isOn).length;
  2609	  $('piiCount').textContent= total? t.cntUse(total):'';
  2610	  document.querySelectorAll('#bulkBtns button').forEach(b=>b.disabled=!total);
  2611	  $('catHint').textContent = pages.length? t.hintAfter : t.hintBefore;
  2612	  const groups={};
  2613	  for(const e of autoE){(groups[e.type]=groups[e.type]||[]).push(e);}
  2614	  const all=Object.keys(TYPES).filter(ty=>ty!=='manual');
  2615	  if(!pages.length){
  2616	    list.innerHTML = all.map(ty=>catRowHtml(ty,[])).join('');
  2617	    return;
  2618	  }
  2619	  const hits=all.filter(ty=>groups[ty]&&groups[ty].length);
  2620	  const misses=all.filter(ty=>!groups[ty]||!groups[ty].length);
  2621	  let html=hits.map(ty=>catRowHtml(ty,groups[ty])).join('');
  2622	  if(misses.length){
  2623	    html+=`<button class="more-cats" id="moreCats">${showAllCats? t.moreHide : t.moreShow(misses.length)}</button>`;
  2624	    if(showAllCats) html+=misses.map(ty=>catRowHtml(ty,[])).join('');
  2625	  }
  2626	  if(legalE.length)  html=sectionHtml('legal', t.jpLegalSection, legalE)+html;
  2627	  if(manualE.length) html+=sectionHtml('manual', t.manualSection, manualE);
  2628	  if(candE.length)   html+=sectionHtml('candidate', t.candSection, candE);
  2629	  if(keepE.length)   html+=sectionHtml('keep', t.keepSection, keepE);
  2630	  list.innerHTML=html;
  2631	}
  2632	$('piiList').addEventListener('change',e=>{
  2633	  const cb=e.target.closest('input[data-cat]'); if(!cb) return;
  2634	  catEnabled[cb.dataset.cat]=cb.checked; renderAll();
  2635	});
   100	    if (!mr.length) return 0;
   101	    const N = 24; let hit = 0;
   102	    for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) {
   103	      const x = rect.x + rect.w * (i + 0.5) / N, y = rect.y + rect.h * (j + 0.5) / N;
   104	      if (mr.some(r => x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h)) hit++;
   105	    }
   106	    return hit / (N * N);
   107	  };
   108	  // OCR/text item boxes whose centre falls inside `rect`
   109	  window.__itemsIn = function (rect) {
   110	    const p = pages[rect.pi]; if (!p) return [];
   111	    return (p.items || []).filter(it => it.x + it.w / 2 >= rect.x && it.x + it.w / 2 <= rect.x + rect.w
   112	                                     && it.y + it.h / 2 >= rect.y && it.y + it.h / 2 <= rect.y + rect.h)
   113	      .map(it => ({ pi: rect.pi, x: it.x, y: it.y, w: it.w, h: it.h }));
   114	  };
   115	  // any ACTIVE candidate entity overlapping `rect` (did the field surface for review?)
   116	  window.__candidateOver = function (rect) {
   117	    for (const e of entities) {
   118	      if (e.kind !== 'candidate' || !e.boxes) continue;
   119	      for (const b of e.boxes) {
   120	        if (b.page !== rect.pi) continue;
   121	        if (!(b.x + b.w < rect.x || rect.x + rect.w < b.x || b.y + b.h < rect.y || rect.y + rect.h < b.y)) return true;
   122	      }
   123	    }
   124	    return false;
   125	  };
   126	  /* ── ink coverage (replaces the 60% area gate on number fields) ──
   127	     A 60% area figure says HOW MUCH of a box was painted, never WHERE: the
   128	     kouki fixture measured 96% with its leading digit fully outside the band
   129	     (Codex 5-3, and we had already recorded it). So for a field whose value is
   130	     a number, the question is per-GLYPH: take the ink inside the expected box,
   131	     label its connected components, and require every component to be covered.
   132	     Threshold 60 (not the detector's 40) deliberately excludes the fixtures'
   133	     見本 watermark — composited it sits ~48 off the background, and a band is
   134	     not required to cover a watermark. */
   135	  window.__inkCover = function (rect) {
   136	    const p = pages[rect.pi]; if (!p) return null;
   137	    const CW = p.canvas.width, CH = p.canvas.height;
   138	    const x0 = Math.max(0, Math.floor(rect.x)), y0 = Math.max(0, Math.floor(rect.y));
   139	    const x1 = Math.min(CW, Math.ceil(rect.x + rect.w)), y1 = Math.min(CH, Math.ceil(rect.y + rect.h));
   140	    const W = x1 - x0, H = y1 - y0;
   141	    if (W <= 0 || H <= 0) return { components: 0, inkPx: 0, uncovered: 0, worst: 1 };
   142	    const ctx = p.canvas.getContext('2d', { willReadFrequently: true });
   143	    const d = ctx.getImageData(x0, y0, W, H).data, bg = jpPageBg(p);
   144	    const ink = new Uint8Array(W * H);
   145	    let inkPx = 0;
   146	    for (let i = 0; i < W * H; i++) {
   147	      if (Math.abs(d[i * 4] - bg[0]) > 60 || Math.abs(d[i * 4 + 1] - bg[1]) > 60 || Math.abs(d[i * 4 + 2] - bg[2]) > 60) { ink[i] = 1; inkPx++; }
   148	    }
   149	    const mr = window.__maskRects().filter(r => r.pi === rect.pi);
   150	    const covered = (px, py) => mr.some(r => px >= r.x && px <= r.x + r.w && py >= r.y && py <= r.y + r.h);
   151	    const seen = new Uint8Array(W * H);
   152	    let components = 0, uncovered = 0, worst = 1;
   153	    for (let i = 0; i < W * H; i++) {
   154	      if (!ink[i] || seen[i]) continue;
   155	      const st = [i]; seen[i] = 1; let n = 0, cov = 0;
   156	      while (st.length) {
   157	        const k = st.pop(), kx = k % W, ky = (k - kx) / W;
   158	        n++; if (covered(x0 + kx + 0.5, y0 + ky + 0.5)) cov++;
   159	        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
   160	          const nx = kx + dx, ny = ky + dy;
   161	          if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
   162	          const nk = ny * W + nx;
   163	          if (ink[nk] && !seen[nk]) { seen[nk] = 1; st.push(nk); }
   164	        }
   165	      }
   166	      // Specks (anti-aliasing debris, watermark bleed) are not glyphs.
   167	      if (n < 6) continue;
   168	      components++;
   169	      const f = cov / n;
   170	      if (f < worst) worst = f;
   171	      if (f < 0.99) uncovered++;
   172	    }
   173	    return { components, inkPx, uncovered, worst };
   174	  };
   175	  /* Every entity carrying `field`, with the facts require_banded is actually
   176	     about: is it located, is its category ON, is it not 'ok', and do the rects
   177	     it would paint ACTUALLY appear in the active mask-rect list? The old
   178	     assertion read `mode !== 'ok'` alone, which stays true for an entity whose
   179	     category is off or whose boxes are empty (Codex 5-5). */
   180	  window.__fieldBands = function (field) {
   181	    const mr = window.__maskRects();
   182	    const same = (a, b) => Math.abs(a.x - b.x) < 0.01 && Math.abs(a.y - b.y) < 0.01 && Math.abs(a.w - b.w) < 0.01 && Math.abs(a.h - b.h) < 0.01;
   183	    return entities.filter(e => e.jp && e.jp.field === field).map(e => {
   184	      const rects = [];
   185	      for (let pi = 0; pi < pages.length; pi++) for (const l of mergeLineBoxes(e.boxes || [], pi)) { const r = bandRect(l); rects.push({ pi, ...r }); }
   186	      return { level: e.jp.level, note: e.jp.note, page: e.jp.page, doc: e.jp.doc, side: e.jp.side,
   187	        kind: e.kind, mode: e.mode, legal: !!e.legal, located: !!(e.boxes && e.boxes.length), on: isOn(e),
   188	        rects: rects.length, inMask: rects.length > 0 && rects.every(r => mr.some(m => m.pi === r.pi && same(m, r))) };
   189	    });
   190	  };
   191	  window.__jpState = function () {
   192	    return { cls: jpState.cls && { doc: jpState.cls.doc, side: jpState.cls.side || null, score: jpState.cls.score, low: !!jpState.cls.low },
   193	      purpose: jpState.purpose, warn: jpState.warn, mnConfirmed: jpState.mnConfirmed,
   194	      pageCls: jpState.pageCls.map(c => c && { doc: c.doc, side: c.side || null, low: !!c.low }),
   195	      warnShown: (() => { const el = document.getElementById('jpWarn'); return !!el && el.style.display !== 'none' && !!el.textContent.trim(); })(),
   196	      mnBoxShown: (() => { const el = document.getElementById('jpMnWrap'); return !!el && el.style.display !== 'none'; })(),
   197	      pw: pages.map(p => p.w),
   198	      fields: entities.filter(e => e.jp).map(e => ({ field: e.jp.field, level: e.jp.level, note: e.jp.note, page: e.jp.page, kind: e.kind, mode: e.mode, legal: !!e.legal, on: isOn(e) })) };
   199	  };
   200	  // Field labels of every ACTIVE auto entity — the allowlist assertion's input.
   201	  window.__autoFields = function () {
   202	    return entities.filter(e => e.kind === 'auto').map(e => e.jp ? e.jp.field : '(regex:' + e.type + ')');
   203	  };
   204	  /* Turn every general category OFF. A legal-preset band must survive this.
   205	     catEnabled is module-level state that resetAll() and a fresh file load do
   206	     NOT restore, so this hands back a restore function — the first version of
   207	     this helper left every category off for the remaining 300 assertions and
   208	     turned 14 of them red. */
   209	  window.__catSnapshot = null;
   210	  window.__allCatsOff = function () {
   211	    window.__catSnapshot = { ...catEnabled };
   212	    for (const t of Object.keys(catEnabled)) catEnabled[t] = false;
   213	    renderAll();
   214	    return Object.keys(catEnabled).filter(t => catEnabled[t] !== false);
   215	  };
   216	  window.__restoreCats = function () {
   217	    if (!window.__catSnapshot) return false;
   218	    for (const t of Object.keys(window.__catSnapshot)) catEnabled[t] = window.__catSnapshot[t];
   219	    window.__catSnapshot = null; renderAll(); return true;
   220	  };
   221	  window.__setMnConfirm = function (v) { jpSetMnConfirmed(v); };
   222	  window.__isCandidateExact = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value) === n); };
   223	  window.__isCandidateContains = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value).includes(n)); };
   224	  // default mode of the candidate whose value contains v (null if not a candidate)
   225	  window.__candidateMode = function (v) { const n = norm(v); const e = entities.find(x => x.kind === 'candidate' && norm(x.value).includes(n)); return e ? e.mode : null; };
   226	  // name-bar geometry: glyph union (raw pdf items) vs drawn bar rect
   227	  window.__nameBar = function (v) {
   228	    const rects = boxesForValue(v).filter(b => b.page === 0);
   229	    if (!rects.length) return null;
   230	    const lines = mergeLineBoxes(rects, 0); const bar = lines[0];
   245	  };
   246	};
   247	
   248	// `jp/...` paths resolve under fixtures/, `gen/...` under out/gen (built at run
   249	// time from committed fixtures — no new binaries in the repo), everything else
   250	// under testdocs/.
   251	const docPath = file => file.startsWith('jp/') ? path.join(FIXTURES, file)
   252	  : file.startsWith('gen/') ? path.join(OUT, file) : path.join(DOCS, file);
   253	async function loadDoc(page, file, ocr) {
   254	  await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
   255	  await page.setInputFiles('#fileInput', docPath(file));
   256	  // `pages.length > 0` is NOT "loaded": pages are pushed one at a time, so on a
   257	  // multi-page OCR document it goes true while page 2 is still in Tesseract —
   258	  // and everything measured after it describes half a document. afterLoad()
   259	  // reveals #docWrap as its last step, so that is the completion signal.
   260	  await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0
   261	      && document.getElementById('docWrap').style.display === 'flex',
   262	    { timeout: ocr ? 300000 : 40000 });
   263	  await page.waitForTimeout(ocr ? 800 : 400);
   264	  await page.evaluate(PAGE_HELPERS);
   265	}
   266	
   267	const rows = [];
   268	const rec = (doc, cat, item, expected, actual, pass, info = false) => rows.push({ doc, cat, item, expected, actual, pass, info });
   269	
   270	async function checkDoc(page, spec) {
   271	  const { doc, ocr } = spec;
   272	  await loadDoc(page, doc, ocr);
   273	  const snap = await page.evaluate(() => window.__entitySnapshot());
   274	  const autoCount = snap.filter(e => e.kind === 'auto').length;
   275	  process.stderr.write(`    [autoCount] ${doc} = ${autoCount}\n`);
   520	function jpFieldOf(key) { return key.replace(/^m\d+_/, ''); }
   521	/* Number fields get the per-glyph ink test instead of the area fraction. These
   522	   are the fields whose whole value is a digit string, so a single surviving
   523	   character is a leak — and the area gate cannot see that (Codex 5-3). */
   524	const JP_NUMERIC = new Set(['hokensha_bango', 'kigo', 'bango', 'edaban', 'hihokensha_bango',
   525	  'my_number', 'jumin_code', 'license_no']);
   526	async function jpCheckBox(page, doc, cat, key, rect, kind) {
   527	  const field = jpFieldOf(key);
   528	  const items = await page.evaluate(r => window.__itemsIn(r), rect);
   529	  let frac, what;
   530	  if (items.length) {
   531	    // The meaningful question for a box holding text is whether the TEXT is
   532	    // covered — not whether the generator's padding around it was painted.
   533	    const fr = await Promise.all(items.map(it => page.evaluate(r => window.__coverage(r), it)));
   534	    frac = Math.min(...fr); what = `${items.length} item(s) min ${(frac * 100).toFixed(0)}%`;
   535	  } else {
   536	    frac = await page.evaluate(r => window.__coverage(r), rect); what = `area ${(frac * 100).toFixed(0)}%`;
   537	  }
   538	  if (kind === 'keep') { rec(doc, 'JP_KEEP', key, `<=${JP_KEEP_MAX * 100}%`, what, frac <= JP_KEEP_MAX); return; }
   539	  // Covered? For a number box, "covered" means every ink component is covered.
   540	  let covered = frac >= JP_COVER_MIN, how = what;
   541	  if (JP_NUMERIC.has(field) && (kind === 'mask' || kind === 'candidate' || kind === 'mask_or_candidate')) {
   542	    const ic = await page.evaluate(r => window.__inkCover(r), rect);
   543	    const comps = ic ? ic.components : 0;
   544	    how = ic ? `${comps} comp, worst ${(ic.worst * 100).toFixed(0)}%` : 'no-canvas';
   545	    // Zero components would make this assertion vacuous: a number box has ink.
   546	    covered = comps > 0 && ic.uncovered === 0;
   547	    if (kind === 'mask') { rec(doc, 'JP_INK', key, 'all glyphs covered', comps ? how : 'NO INK FOUND', covered); return; }
   548	  }
   549	  if (kind === 'mask') { rec(doc, 'JP_MASK', key, `>=${JP_COVER_MIN * 100}%`, how, covered); return; }
   550	  const cand = await page.evaluate(r => window.__candidateOver(r), rect);
   551	  if (kind === 'candidate') {
   552	    // A recommend-level candidate is default ON, so it is both surfaced AND
   553	    // banded; a number field has to pass the ink test in that case.
   554	    const banded = frac > JP_KEEP_MAX;
   555	    const ok = cand && (!banded || covered);
   556	    rec(doc, 'JP_CANDIDATE', key, 'surfaced(+covered if banded)',
   557	      cand ? (banded ? (covered ? 'candidate+covered' : 'BANDED BUT LEAKING ' + how) : 'candidate') : 'MISSING', ok); return;
   558	  }
   559	  if (kind === 'mask_or_candidate') {
   560	    rec(doc, 'JP_MASK_OR_CAND', key, 'banded(+covered) or candidate', covered ? 'banded ' + how : cand ? 'candidate' : 'NEITHER ' + how, covered || cand); return;
   561	  }
   562	  if (kind === 'optional') {   // detected, offered, and OFF until the user says so
   563	    rec(doc, 'JP_OPTIONAL', key, 'offered+clear', cand ? (frac <= JP_KEEP_MAX ? 'offered+clear' : 'OFFERED BUT BANDED') : 'MISSING', cand && frac <= JP_KEEP_MAX);
   564	  }
   565	}
   566	async function checkJpDoc(page, spec) {
   567	  const fx = JSON.parse(fs.readFileSync(path.join(__dirname, spec.fixture), 'utf8'));
   568	  const autoFields = (SPECS.jp_auto_fields || {})[spec.expect_doc] || [];
   569	  const mocFields = SPECS.jp_candidate_or_mask || [];
   570	  for (const c of spec.cases) {
   571	    const tag = `${spec.doc} [${c.purpose}${c.label ? ' ' + c.label : ''}]`;
   572	    await loadDoc(page, spec.doc, true);
   573	    await page.evaluate(p => jpSetPurpose(p), c.purpose);
   574	    // Releasing a 個人番号 band needs the purpose AND the confirmation. A case
   575	    // that expects the release has to say so — which is itself the assertion
   576	    // that the dropdown alone does not open the gate (the `confirm_mynumber:
   577	    // false` case below proves the other direction).
   578	    if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
   579	    const st = await page.evaluate(() => window.__jpState());
   580	    if (c.expect_warn != null)
   581	      rec(tag, 'JP_WARN', 'blocking banner', c.expect_warn ? 'shown' : 'absent',
   582	        st.warnShown ? 'shown(' + st.warn + ')' : 'absent', st.warnShown === !!c.expect_warn);
   583	    if (c.confirm_mynumber != null)
   584	      rec(tag, 'JP_MN_BOX', 'confirmation checkbox', 'shown', st.mnBoxShown ? 'shown' : 'ABSENT', st.mnBoxShown);
   585	    rec(tag, 'JP_CLASS', spec.expect_doc + (spec.expect_side ? '/' + spec.expect_side : ''), 'classified',
   586	      st.cls ? st.cls.doc + (st.cls.side ? '/' + st.cls.side : '') + ' sc=' + st.cls.score : 'NOT classified',
   587	      !!st.cls && st.cls.doc === spec.expect_doc && (!spec.expect_side || st.cls.side === spec.expect_side));
   588	    if (!st.cls) continue;
   589	    const autoCount = await page.evaluate(() => entities.filter(e => e.kind === 'auto').length);
   590	    process.stderr.write(`    [jp autoCount] ${tag} = ${autoCount}\n`);
   591	    if (c.min_auto != null) rec(tag, 'REGRESSION', `auto>=${c.min_auto}`, `>=${c.min_auto}`, String(autoCount), autoCount >= c.min_auto);
   592	    if (c.max_auto != null) rec(tag, 'REGRESSION', `auto<=${c.max_auto}`, `<=${c.max_auto}`, String(autoCount), autoCount <= c.max_auto);
   593	
   594	    // Field-level: every required field must have been FOUND. This is the only
   595	    // assertion a rotated phone-photo fixture can make, and it is also the one
   596	    // the 미탐 0 gate is actually about.
   597	    const got = new Set(st.fields.map(f => f.field));
   598	    for (const f of (c.require_fields || [])) rec(tag, 'JP_FIELD', f, 'detected', got.has(f) ? 'detected' : 'MISSING', got.has(f));
   599	    // A band is only a band if the entity is located, its category is ON, its
   600	    // mode is not 'ok', AND the rect it paints is in the active mask-rect list.
   601	    for (const f of (c.require_banded || [])) {
   602	      const bs = await page.evaluate(x => window.__fieldBands(x), f);
   603	      const ok = bs.length > 0 && bs.every(b => b.located && b.on && b.mode !== 'ok' && b.inMask);
   604	      const why = !bs.length ? 'MISSING'
   605	        : bs.every(b => b.located && b.on && b.mode !== 'ok' && b.inMask) ? `banded ×${bs.length}`
   606	        : bs.map(b => !b.located ? 'NOT LOCATED' : !b.on ? 'CATEGORY OFF' : b.mode === 'ok' ? 'CLEAR' : 'NOT IN MASKRECTS').join('/');
   607	      rec(tag, 'JP_BANDED', f, 'located+on+in-maskrects', why, ok);
   608	    }
   609	    // The inverse of require_banded, and the half that makes a purpose-gate test
   610	    // mean something: without it, "banded under 相談用共有" could be true simply
   611	    // because the field is banded under every purpose. Also asserts the rect is
   612	    // absent from the mask list, not merely that the mode string says 'ok'.
   613	    for (const f of (c.require_clear || [])) {
   614	      const bs = await page.evaluate(x => window.__fieldBands(x), f);
   615	      const clear = bs.length > 0 && bs.every(b => b.mode === 'ok' && !b.inMask);
   616	      rec(tag, 'JP_CLEAR', f, 'detected+clear', !bs.length ? 'MISSING' : (clear ? `detected+clear ×${bs.length}` : 'BANDED'), clear);
   617	    }
   618	    // Legal-preset fields are not governed by the category checkboxes. Turn
   619	    // every category off and require the band to still be there.
   620	    for (const f of (c.require_legal || [])) {
   621	      const left = await page.evaluate(() => window.__allCatsOff());
   622	      const bs = await page.evaluate(x => window.__fieldBands(x), f);
   623	      const ok = left.length === 0 && bs.length > 0 && bs.every(b => b.legal && b.on && b.mode !== 'ok' && b.inMask);
   624	      rec(tag, 'JP_LEGAL', f, 'survives all-categories-off',
   625	        left.length ? 'cats still on: ' + left.join(',') : !bs.length ? 'MISSING'
   626	          : bs.every(b => b.legal && b.on && b.mode !== 'ok' && b.inMask) ? `banded ×${bs.length}` : 'DROPPED', ok);
   627	      // put the page back the way the rest of the case expects it
   628	      const restored = await page.evaluate(() => window.__restoreCats());
   629	      rec(tag, 'JP_LEGAL', f + ' (categories restored)', 'restored', restored ? 'restored' : 'NOT RESTORED', restored, true);
   630	      await loadDoc(page, spec.doc, true);
   631	      await page.evaluate(p => jpSetPurpose(p), c.purpose);
   632	      if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
   633	    }
   634	    // No auto entity outside the allowlist. A ceiling on the COUNT cannot tell
   635	    // "the right five" from "two right and three wrong" (Codex 5-6).
   636	    if (c.auto_allow) {
   637	      const af = await page.evaluate(() => window.__autoFields());
   638	      const bad = af.filter(f => !c.auto_allow.includes(f));
   639	      rec(tag, 'JP_AUTO_SET', 'auto fields ⊆ allowlist', c.auto_allow.join(',') || '(none)',
   640	        bad.length ? 'UNEXPECTED: ' + [...new Set(bad)].join(',') : (af.length ? [...new Set(af)].join(',') : '(none)'), bad.length === 0);
   641	    }
   642	    if (spec.geometry === false || c.geometry === false) continue;
   643	
   644	    const P = fx.purposes[c.key];
   645	    if (!P) { rec(tag, 'JP_SPEC', c.key, 'purpose in fixture', 'MISSING', false); continue; }
   646	    const scale = st.pw[0] / fx.size[0];
   647	    let checked = 0;
   648	    const box = k => { const b = fx.boxes_png[k]; return b && { pi: 0, x: b[0] * scale, y: b[1] * scale, w: (b[2] - b[0]) * scale, h: (b[3] - b[1]) * scale }; };
   649	    const seen = new Set();
   650	    const run = async (keys, kindFor) => {
   651	      for (const k of (keys || [])) {
   652	        if (k === 'ALL' || seen.has(k)) continue;
   653	        const r = box(k);
   654	        // An expectation naming a box this variant does not have is a FAULT in
   655	        // the expectation table, not a case to skip. It used to be "reported as
   656	        // skipped", which is a line of text nobody reads next to a green total
   657	        // (Codex 5-5). The variant tables are pruned at generation time now, so
   658	        // a missing key means the table and the fixture went out of sync.
   659	        if (!r) { rec(tag, 'JP_SPEC', k, 'box exists in fixture', 'NO SUCH BOX', false); continue; }
   660	        seen.add(k);
   661	        await jpCheckBox(page, tag, null, k, r, kindFor(k));
   662	        checked++;
   663	      }
   664	    };
   665	    // whole-face rule (マイナカード裏面 under a 本人確認 purpose)
   666	    if ((P.mask || []).includes('ALL')) {
   667	      const pg = await page.evaluate(() => ({ pi: 0, x: 0, y: 0, w: pages[0].w, h: pages[0].h }));
   668	      await jpCheckBox(page, tag, null, 'ALL(face)', pg, 'mask');
   669	      checked++;
   670	      for (const k of Object.keys(fx.boxes_png)) { const r = box(k); if (r) { await jpCheckBox(page, tag, null, k, r, 'mask'); checked++; } }
   671	      seen.add('ALL');
   672	    }
   673	    await run(P.mask, k => mocFields.includes(jpFieldOf(k)) ? 'mask_or_candidate'
   674	                        : autoFields.includes(jpFieldOf(k)) ? 'mask' : 'candidate');
   675	    await run(P.recommend, () => 'candidate');
   676	    await run(P.optional, () => 'optional');
   677	    // `keep: "all"` means every box on the page is a keep field. Turning that
   678	    // into an empty list made the strongest promise in the table the only one
   679	    // nobody checked (Codex 5-5) — enumerate the box table instead.
   680	    await run(P.keep === 'all' ? Object.keys(fx.boxes_png) : P.keep, () => 'keep');
   681	    rec(tag, 'JP_COVERAGE', 'boxes checked', `>=${c.min_boxes || 1}`, String(checked), checked >= (c.min_boxes || 1));
   682	    for (const fmt of (c.out_formats || [])) await checkOutput(page, tag, fmt);
   683	  }
   684	}
   685	
   686	/* ── JP unit rules ──────────────────────────────────────────────────────────
   687	   Two detection rules cannot be exercised by the alpha fixtures: none of the
   688	   four documents carries a phone number, and on all four the 住所 is a KEEP
   689	   field, so the address hierarchy's own scoring never decides anything there.
   690	   Shipping them with no coverage at all would be shipping untested detection,
   691	   so they are pinned at unit level against crafted strings — stated as such
   692	   rather than left to look like fixture coverage. */
   693	async function checkJpUnits(page) {
   694	  const U = SPECS.jp_units; if (!U) return;
   695	  for (const c of (U.address || [])) {
   696	    const got = await page.evaluate(t => {
   697	      const sp = jpAddressSpan(t, 0);
   698	      return sp ? { span: t.slice(sp.a, sp.b), score: sp.score, strong: !!(sp.postal && sp.pref) } : null;
   699	    }, c.text);
   700	    const ok = c.expect === null ? (got === null || got.score < 3)
   701	      : !!got && got.span === c.expect.span && got.score === c.expect.score && got.strong === !!c.expect.strong;
   702	    rec('(jp units)', 'JP_ADDRESS', c.label, c.expect === null ? 'no address' : `${c.expect.span} s=${c.expect.score}${c.expect.strong ? ' strong' : ''}`,
   703	      got ? `${got.span} s=${got.score}${got.strong ? ' strong' : ''}` : 'none', ok);
   704	  }
   705	  for (const c of (U.tel || [])) {
   710	    const ok = c.expect === null ? got === null
   711	      : !!got && got.v === c.expect.v && got.loose === !!c.expect.loose;
   712	    rec('(jp units)', 'JP_TEL', c.label, c.expect === null ? 'no match' : `${c.expect.v}${c.expect.loose ? ' (candidate)' : ''}`,
   713	      got ? `${got.v}${got.loose ? ' (candidate)' : ''}` : 'none', ok);
   714	  }
   715	}
   716	
   717	/* ── legal matrix ↔ code (check_matrix.mjs) ────────────────────────────────── */
   718	function checkMatrix() {
   719	  const r = spawnSync(process.execPath, [path.join(__dirname, 'check_matrix.mjs')], { encoding: 'utf8' });
   720	  const out = ((r.stdout || '') + (r.stderr || '')).trim().split('\n').filter(Boolean);
   721	  rec('(legal matrix)', 'JP_MATRIX', 'JP_RULES == jp_legal_matrix_alpha4.json', 'identical',
   722	    r.status === 0 ? out[out.length - 1].replace(/^✅ legal matrix ↔ code: /, '') : `${out.length - 1} disagreement(s)`, r.status === 0);
   723	  if (r.status !== 0) for (const l of out.slice(1, 9)) rec('(legal matrix)', 'JP_MATRIX', l.trim().slice(0, 38), '-', 'mismatch', false, true);
   724	}
   725	
   726	/* ── multi-page: the rule follows the PAGE, not page 1 ──────────────────────
   727	   A two-sided card scanned into one PDF. The old code read page 1's class and
   728	   applied it to every page, so the outcome depended on scan order: front-then-
   729	   back left the 個人番号 page untouched, back-then-front put a full-face band
   730	   over the front as well (Codex 6-4). Both orders are built here from the
   731	   committed single-page PNGs — written under out/gen, not committed, so the
   732	   repo gains no new card binaries. */
   733	async function buildPdfFromImages(page, srcs, outPath) {
   734	  const b64 = await page.evaluate(async (urls) => {
   735	    const { jsPDF } = await ensureJsPDF();
   736	    let pdf = null;
   737	    for (const u of urls) {
   738	      const im = await new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = u; });
   739	      const cv = document.createElement('canvas'); cv.width = im.width; cv.height = im.height;
   740	      cv.getContext('2d').drawImage(im, 0, 0);
   741	      const data = cv.toDataURL('image/jpeg', 0.95);
   742	      if (!pdf) pdf = new jsPDF({ unit: 'pt', format: [im.width, im.height], compress: true });
   743	      else pdf.addPage([im.width, im.height]);
   744	      pdf.addImage(data, 'JPEG', 0, 0, im.width, im.height);
   745	    }
   746	    return pdf.output('datauristring').split(',')[1];
   747	  }, srcs);
   748	  fs.mkdirSync(path.dirname(outPath), { recursive: true });
   749	  fs.writeFileSync(outPath, Buffer.from(b64, 'base64'));
   750	}
   751	async function checkJpMultiPage(page, port) {
   752	  const B = `http://127.0.0.1:${port}/__fx/jp/mynumber_card`;
   753	  const cases = [
   754	    { label: '表→裏', srcs: [`${B}/front.png`, `${B}/back.png`], backPage: 1, frontPage: 0, file: 'gen/mn_front_back.pdf' },
   755	    { label: '裏→表', srcs: [`${B}/back.png`, `${B}/front.png`], backPage: 0, frontPage: 1, file: 'gen/mn_back_front.pdf' },
   756	  ];
   757	  for (const c of cases) {
   758	    const tag = `jp/2page ${c.label}`;
   759	    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
   760	    try {
   761	      await buildPdfFromImages(page, c.srcs, path.join(OUT, c.file));
   762	      await loadDoc(page, c.file, true);
   763	      await page.evaluate(() => jpSetPurpose('identity_submit'));
   764	      const st = await page.evaluate(() => window.__jpState());
   765	      const sides = st.pageCls.map(x => x ? (x.doc + '/' + (x.side || '-')) : 'null');
   766	      const wantSides = []; wantSides[c.backPage] = 'mynumber_card/back'; wantSides[c.frontPage] = 'mynumber_card/front';
   767	      rec(tag, 'JP_PAGECLASS', 'per-page doc/side', wantSides.join(' + '), sides.join(' + '),
   768	        sides.length === 2 && sides[c.backPage] === wantSides[c.backPage] && sides[c.frontPage] === wantSides[c.frontPage]);
   769	      // The whole-face band exists on the BACK page and only there.
   770	      const bs = await page.evaluate(() => window.__fieldBands('back_all'));
   771	      const pagesWithBand = bs.filter(b => b.mode !== 'ok' && b.inMask).map(b => b.page);
   772	      rec(tag, 'JP_BACK_ONLY', 'back_all pages', `[${c.backPage}]`, `[${pagesWithBand.join(',')}]`,
   773	        pagesWithBand.length === 1 && pagesWithBand[0] === c.backPage);
   774	      // And geometrically: the back page is covered, the front page is not.
   775	      const cov = await page.evaluate(() => pages.map((p, pi) => window.__coverage({ pi, x: 0, y: 0, w: p.w, h: p.h })));
   776	      rec(tag, 'JP_BACK_COVER', `page ${c.backPage} covered`, '>=99%', `${(cov[c.backPage] * 100).toFixed(0)}%`, cov[c.backPage] >= 0.99);
   777	      rec(tag, 'JP_FRONT_CLEAR', `page ${c.frontPage} not full-face`, '<=60%', `${(cov[c.frontPage] * 100).toFixed(0)}%`, cov[c.frontPage] <= 0.6);
   778	    } catch (e) { rec(tag, 'LOAD', c.file, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
   779	    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
   780	  }
   781	}
   782	
   783	/* ── 個人番号 check digit ───────────────────────────────────────────────────
   784	   Two layers. The vectors pin the arithmetic of 省令第5条 (including the two
   785	   remainder cases the 省令 folds to 0). The synthesis then drives a VALID
   786	   number through the real pipeline — classification, label anchor, digit span,
   787	   check digit, purpose gate — on a page built by the app's own text renderer.
   788	   The alpha card dummies all carry invalid numbers on purpose (strategy v2 §4
   789	   forbids generating a valid one into a card image), so until now nothing
   790	   exercised the `checkOk: true` branch at all (Codex 5-2): a correct number
   791	   would have taken a path the golden had never run. The valid numbers live in
   792	   TEXT only, never in a committed image. */
   793	async function checkJpMyNumber(page) {
   794	  const U = SPECS.jp_my_number; if (!U) return;
   795	  for (const c of (U.vectors || [])) {
   796	    const got = await page.evaluate(v => myNumberCheckOk(v), c.n);
   797	    rec('(jp units)', 'JP_MYNUM_CD', `${c.label} ${c.n}`, String(c.ok), String(got), got === c.ok);
   798	  }
   799	  for (const c of (U.synth || [])) {
   800	    const tag = '(jp synth)';
   801	    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
   802	    await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
   803	    await page.evaluate(t => loadFromText(t, 'synth.txt'), c.text);
   804	    await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0, { timeout: 40000 });
   805	    await page.evaluate(PAGE_HELPERS);
   806	    await page.evaluate(p => jpSetPurpose(p), c.purpose);
   807	    if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
   808	    const st = await page.evaluate(() => window.__jpState());
   809	    rec(tag, 'JP_CLASS', c.label, c.expect_doc, st.cls ? st.cls.doc : 'NOT classified', !!st.cls && st.cls.doc === c.expect_doc);
   810	    const bs = await page.evaluate(() => window.__fieldBands('my_number'));
   811	    const lv = bs.map(b => b.level + (b.note ? '/' + b.note : '')).join(',') || 'MISSING';
   812	    rec(tag, 'JP_MYNUM_LEVEL', c.label, c.expect_level, lv, bs.length > 0 && bs.every(b => b.level === c.expect_level));
   813	    // A valid number must NOT carry the check-digit demotion note.
   814	    rec(tag, 'JP_MYNUM_NOTE', c.label + ' note', c.expect_note || '(none)',
   815	      bs.length ? (bs[0].note || '(none)') : 'MISSING', bs.length > 0 && (bs[0].note || null) === (c.expect_note || null));
   816	    const banded = bs.length > 0 && bs.every(b => b.mode !== 'ok' && b.inMask);
   817	    rec(tag, 'JP_MYNUM_BAND', c.label + ' band', c.expect_banded ? 'banded' : 'clear',
   818	      banded ? 'banded' : 'clear', banded === !!c.expect_banded);
   819	    if (c.expect_banded) {
   820	      const masked = await page.evaluate(v => window.__isMasked(v), c.number);
   821	      rec(tag, 'JP_MYNUM_GEOM', c.label + ' value covered', 'masked', masked ? 'masked' : 'NOT masked', masked);
   822	    }
   823	    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
   824	  }
   825	}
   826	
   827	/* ── unlabelled square block: offered, never banded by default ──────────────
   828	   The pixel detector for an unlabelled block has no golden coverage (the alpha
   829	   dummies carry no real QR — strategy v2 §4), and it can fire on a face photo,
   830	   a round seal (bbox fill ≈ 0.785) or a black table header. So the POLICY is
   831	   what gets pinned here: a finding flagged `unlabelledCode` comes out of
   832	   jpApply as `optional` / mode 'ok' / not in the mask list, even on a document
   833	   whose labelled 二次元コード is an automatic band. The finding is injected —
   834	   this tests the decision, not the detector, and says so. */
   835	async function checkJpUnlabelled(page) {
   836	  const U = SPECS.jp_unlabelled_block; if (!U) return;
   837	  const tag = '(jp unlabelled)';
   838	  await page.evaluate(() => { LANG = 'ja'; applyLang(); });
   839	  await loadDoc(page, U._doc, true);
   840	  await page.evaluate(p => jpSetPurpose(p), U.purpose);
   841	  const res = await page.evaluate(() => {
   842	    // A square where nothing on the page is a code: top-left corner of the page.
   843	    const r = { page: 0, x: 40, y: 40, w: 120, h: 120, region: true };
   844	    jpState.findings.push({ field: 'qr', boxes: [r], value: '二次元コード', pi: 0,
   845	      doc: jpState.cls.doc, side: jpState.cls.side || null, low: false, unlabelledCode: true });
   846	    jpApply();
   847	    const inj = entities.find(e => e.jp && e.jp.note === 'unlabelled_code');
   848	    return { present: !!inj, level: inj && inj.jp.level, mode: inj && inj.mode, kind: inj && inj.kind,
   849	      covered: window.__coverage({ pi: 0, x: 40, y: 40, w: 120, h: 120 }),
   850	      labelledBanded: window.__fieldBands('qr').filter(b => b.note !== 'unlabelled_code').every(b => b.mode !== 'ok' && b.inMask) };
   851	  });
   852	  rec(tag, 'JP_UNLABELLED', 'level', 'optional', res.present ? res.level : 'MISSING', res.level === 'optional');
   853	  rec(tag, 'JP_UNLABELLED', 'default mode', 'ok', res.present ? res.mode : 'MISSING', res.mode === 'ok');
   854	  rec(tag, 'JP_UNLABELLED', 'not in default output', '0% covered', `${(res.covered * 100).toFixed(0)}%`, res.covered <= 0.10);
   855	  // …and the LABELLED code on the same page is still banded, so the assertion
   856	  // above is not passing merely because nothing is banded at all.
   857	  rec(tag, 'JP_UNLABELLED', 'labelled code still banded', 'banded', res.labelledBanded ? 'banded' : 'CLEAR', res.labelledBanded);
   858	  await page.evaluate(() => { LANG = 'ko'; applyLang(); });
   859	}
   860	
   861	/* ── classification failure must be visible ─────────────────────────────────
   862	   A page that says 資格確認書 and nothing else reaches 3 of the 4 points it
   863	   needs. The old build dropped the entire Japanese preset and fell through to
   864	   the Latin name/address heuristics without a word (Codex 1-1). */
   865	async function checkJpWarn(page) {
   866	  const W = SPECS.jp_warn; if (!W) return;
   867	  for (const c of W.cases) {
   868	    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
   869	    await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
   870	    await page.evaluate(t => loadFromText(t, 'warn.txt'), c.text);
   871	    await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0, { timeout: 40000 });
   872	    await page.evaluate(PAGE_HELPERS);
   873	    const st = await page.evaluate(() => window.__jpState());
   874	    rec('(jp warn)', 'JP_WARN', c.label, c.expect_warn ? `shown/${c.expect_warn}` : 'absent',
   875	      st.warnShown ? `shown/${st.warn}` : 'absent',
   876	      st.warnShown === !!c.expect_warn && (!c.expect_warn || st.warn === c.expect_warn));
   877	    rec('(jp warn)', 'JP_WARN_CLASS', c.label + ' class', c.expect_doc || 'null',
   878	      st.cls ? st.cls.doc + (st.cls.low ? '(low)' : '') : 'null',
   879	      (st.cls ? st.cls.doc : null) === (c.expect_doc || null) && (!c.expect_doc || !!st.cls.low === !!c.expect_low));
   880	    // A low-confidence class may not produce an automatic band.
   881	    if (c.expect_low) {
   882	      const af = await page.evaluate(() => window.__autoFields());
   883	      const jpAuto = af.filter(f => !f.startsWith('(regex:'));
   884	      rec('(jp warn)', 'JP_WARN_NOAUTO', c.label + ' no jp auto', '(none)',
   885	        jpAuto.length ? jpAuto.join(',') : '(none)', jpAuto.length === 0);
   886	    }
   887	    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
   888	  }
   889	}
   890	
   891	function printTable() {
   892	  const pad = (s, n) => { s = String(s); return s.length > n ? s.slice(0, n - 1) + '…' : s.padEnd(n); };
   893	  let lastDoc = '';
   894	  console.log('\n' + '═'.repeat(120));
   895	  console.log(pad('DOC', 20) + pad('CATEGORY', 17) + pad('ITEM', 40) + pad('EXPECTED', 18) + pad('ACTUAL', 18) + 'RESULT');
   896	  console.log('─'.repeat(120));
   897	  for (const r of rows) {
   898	    if (r.doc !== lastDoc) { console.log('─'.repeat(120)); lastDoc = r.doc; }
   899	    const mark = r.info ? (r.pass ? 'ℹ ok' : 'ℹ note') : (r.pass ? '✅ PASS' : '❌ FAIL');
   900	    console.log(pad(r.doc, 20) + pad(r.cat, 17) + pad(r.item, 40) + pad(r.expected, 18) + pad(r.actual, 18) + mark);
     1	#!/usr/bin/env node
     2	/*
     3	 * Legal matrix ↔ code cross-check.
     4	 *
     5	 * jp_legal_matrix_alpha4.json is the 정본 (single source of truth). The page is a
     6	 * single static HTML file with no build step, so JP_RULES in public/safe/index.html
     7	 * is a hand-written mirror of it. A second hand-written table is exactly how the
     8	 * two drift apart (Codex 4-1 found seven disagreements), so this file makes the
     9	 * drift a test failure instead of a reading exercise:
    10	 *
    11	 *   1. derive (doc, field, purpose) → level from the JSON,
    12	 *   2. read JP_RULES + jpLevel out of index.html and evaluate them,
    13	 *   3. compare EVERY (doc, field, purpose) triple in either table,
    14	 *   4. enforce the invariant `verified:false ⇒ never auto/gate` on the JSON,
    15	 *   5. enforce that the fields JP_RULES names are the fields the JSON names.
    16	 *
    17	 * run.mjs calls this first, so the golden cannot pass while the tables disagree.
    18	 * Usage: node check_matrix.mjs   (exit 0 = identical)
    19	 */
    20	import fs from 'node:fs';
    21	import path from 'node:path';
    22	import { fileURLToPath } from 'node:url';
    23	
    24	const __dirname = path.dirname(fileURLToPath(import.meta.url));
    25	const REPO = path.resolve(__dirname, '..', '..');
    26	const MATRIX = path.join(__dirname, 'fixtures', 'jp', 'jp_legal_matrix_alpha4.json');
    27	const PAGE = path.join(REPO, 'public', 'safe', 'index.html');
    28	
    29	const LEVEL_TOKEN = { auto: 'auto', auto_with_purpose_gate: 'gate', recommend: 'recommend', optional: 'optional', keep: 'keep' };
    30	const AUTOMATIC = new Set(['auto', 'gate']);
    31	
    32	const problems = [];
    33	const fail = (what, msg) => problems.push(`${what}: ${msg}`);
    34	
    35	/* ── 1. the 정본 → a (doc, field, purpose) table ── */
    36	const M = JSON.parse(fs.readFileSync(MATRIX, 'utf8'));
    37	const PURPOSES = Object.keys(M.purposes);
    38	const matrix = {};            // doc → field → purpose → level
    39	const matrixFields = {};      // doc → Set(field)
    40	function applyRule(docId, rule, where) {
    41	  const token = LEVEL_TOKEN[rule.level];
    42	  if (!token) { fail(where, `unknown level "${rule.level}"`); return; }
    43	  if (!Array.isArray(rule.fields) || !rule.fields.length) { fail(where, 'rule has no `fields` (code field keys)'); return; }
    44	  if (rule.verified === false && AUTOMATIC.has(token))
    45	    fail(where, `verified:false but level "${rule.level}" is automatic — an unsourced rule may not delete pixels on its own`);
    46	  const seen = {};
    47	  const put = (purpose, level) => {
    48	    if (!PURPOSES.includes(purpose)) { fail(where, `unknown purpose "${purpose}"`); return; }
    49	    if (seen[purpose]) { fail(where, `purpose "${purpose}" appears twice (${seen[purpose]} and ${level})`); return; }
    50	    seen[purpose] = level;
    51	    for (const f of rule.fields) {
    52	      matrix[docId] = matrix[docId] || {};
    53	      matrix[docId][f] = matrix[docId][f] || {};
    54	      matrixFields[docId] = matrixFields[docId] || new Set();
    55	      matrixFields[docId].add(f);
    56	      const prev = matrix[docId][f][purpose];
    57	      if (prev && prev !== level) fail(`${docId}.${f}[${purpose}]`, `two rules disagree: ${prev} vs ${level}`);
    58	      matrix[docId][f][purpose] = level;
    59	    }
    60	  };
    61	  for (const p of (rule.must_keep_when || [])) put(p, 'keep');
    62	  for (const p of (rule.mask_when || [])) put(p, token);
    63	  for (const p of (rule.optional_when || [])) put(p, 'optional');
    64	}
    65	for (const doc of M.documents) for (const r of doc.rules) applyRule(doc.id, r, `${doc.id} 「${r.field}」`);
    66	// general_jp applies to every listed document.
    67	const G = M.general_jp || { applies_to: [], rules: [] };
    68	for (const docId of G.applies_to) for (const r of G.rules) applyRule(docId, r, `general_jp→${docId} 「${r.field}」`);
    69	
    70	/* ── 2. the code → JP_RULES + jpLevel ── */
    71	const src = fs.readFileSync(PAGE, 'utf8');
    72	function slice(startMarker, endMarker) {
    73	  const a = src.indexOf(startMarker);
    74	  if (a < 0) throw new Error(`cannot find ${startMarker} in ${PAGE}`);
    75	  const b = src.indexOf(endMarker, a);
    76	  if (b < 0) throw new Error(`cannot find ${endMarker} after ${startMarker}`);
    77	  return src.slice(a, b + endMarker.length);
    78	}
    79	// Everything from the purpose shorthands through the end of JP_RULES, then jpLevel.
    80	const rulesSrc = slice('const P_NOT_MYNUM =', '\n};\n');
    81	const levelSrc = slice('function jpLevel(', '\n}\n');
    82	const legalSrc = slice('const JP_LEGAL_FIELDS =', ']);');
    83	let JP_RULES, jpLevel, JP_LEGAL_FIELDS;
    84	try {
    85	  ({ JP_RULES, jpLevel, JP_LEGAL_FIELDS } =
    86	    new Function(`${rulesSrc}\n${levelSrc}\n${legalSrc}\nreturn {JP_RULES, jpLevel, JP_LEGAL_FIELDS};`)());
    87	} catch (e) {
    88	  console.error('could not evaluate JP_RULES / jpLevel out of index.html:', e.message);
    89	  process.exit(2);
    90	}
    91	
    92	/* ── 3. compare every triple in EITHER table ── */
    93	let compared = 0;
    94	const docs = new Set([...Object.keys(matrix), ...Object.keys(JP_RULES)]);
    95	for (const doc of docs) {
    96	  const mf = matrixFields[doc] || new Set();
    97	  const cf = new Set(Object.keys(JP_RULES[doc] || {}));
    98	  for (const f of cf) if (!mf.has(f)) fail(`${doc}.${f}`, 'in JP_RULES but not in the legal matrix');
    99	  for (const f of mf) if (!cf.has(f)) fail(`${doc}.${f}`, 'in the legal matrix but not in JP_RULES');
   100	  for (const f of new Set([...mf, ...cf])) {
   101	    for (const p of PURPOSES) {
   102	      const want = ((matrix[doc] || {})[f] || {})[p] || null;
   103	      const got = (JP_RULES[doc] && JP_RULES[doc][f]) ? jpLevel(doc, f, p) : null;
   104	      compared++;
   105	      if (want !== got) fail(`${doc}.${f}[${p}]`, `matrix says ${want || 'null (not offered)'}, code says ${got || 'null (not offered)'}`);
   106	    }
   107	  }
   108	}
   109	// A triple must have been checked. A comparison loop that silently ran zero
   110	// times prints the same green as one that checked two hundred.
   111	if (compared < 100) fail('coverage', `only ${compared} (doc, field, purpose) triples compared — the extraction is probably broken`);
   112	
   113	/* ── 4/5. the legal group must be a subset of what the matrix grounds in statute ── */
   114	for (const f of JP_LEGAL_FIELDS) {
   115	  const inSome = Object.keys(matrix).some(d => matrix[d][f]);
   116	  if (!inSome) fail(`JP_LEGAL_FIELDS.${f}`, 'not a field the legal matrix knows');
   117	}
   118	
   119	if (problems.length) {
   120	  console.log(`\n✗ legal matrix ↔ code: ${problems.length} disagreement(s) over ${compared} triples\n`);
   121	  for (const p of problems) console.log('   ' + p);
   122	  console.log('');
   123	  process.exit(1);
   124	}
   125	console.log(`✅ legal matrix ↔ code: ${compared} (doc, field, purpose) triples identical, verified:false⇒no-auto holds`);
     1	{
     2	  "version": "2026-10-21b",
     3	  "scope": "SafeFile JP 알파 4종. 규칙은 제출 목적(purpose)별. 출처 없는 규칙은 verified=false로 표기하고 자동 마스킹 금지.",
     4	  "_schema": {
     5	    "rule": "{field: 사람이 읽는 필드명, fields: [코드 필드 키], mask_when: [purpose], must_keep_when: [purpose], optional_when: [purpose], level, legal_basis, source, verified}",
     6	    "derivation": "(doc, code field, purpose) → level: purpose ∈ must_keep_when → keep · purpose ∈ mask_when → level 토큰 · purpose ∈ optional_when → optional · 그 외 → null(UI에 내지 않음). 한 purpose가 두 목록에 동시에 들어가면 오류다.",
     7	    "level_tokens": "auto → auto · auto_with_purpose_gate → gate · recommend → recommend · optional → optional · keep → keep",
     8	    "invariant": "verified=false 인 규칙은 auto·gate 를 가질 수 없다. 출처 없는 판단이 스스로 픽셀을 지우면 안 된다. test/safe/check_matrix.mjs 가 이 표와 public/safe/index.html 의 JP_RULES 를 (doc, field, purpose) 전수 대조하고 이 불변식을 강제한다.",
     9	    "optional_when_basis": "optional 은 「既定OFF・選択可」 — 법적 주장이 아니라 UI 제공이다. 제출 목적이 그 항목을 요구하지 않는 조합(특히 相談用共有)에서 사용자가 자기 정보를 가릴 수단을 잃지 않도록 명시한다. 출처가 없으므로 자동이 될 수 없다."
    10	  },
    11	  "purposes": {
    12	    "identity_submit": "本人確認書類として提出（銀行・カード・通信・フリマ・賃貸）",
    13	    "my_number_procedure": "個人番号関係事務（税・社会保障・勤務先提出）",
    14	    "bid_attachment": "入札・許可申請への添付",
    15	    "consult_share": "専門家・SNS等への相談用共有"
    16	  },
    17	  "documents": [
    18	    {
    19	      "id": "shikaku_kakuninsho", "name": "資格確認書", "replaces": "健康保険証（2025-12-01 失効・暫定2026-07-31終了）",
    20	      "variants": ["被用者保険(協会けんぽ・健保組合)", "国民健康保険", "後期高齢者医療"],
    21	      "fields_common": ["氏名", "生年月日", "性別", "住所", "資格取得年月日", "有効期限", "保険者番号", "保険者名", "記号/番号/枝番 または 被保険者番号"],
    22	      "fields_issuer_specific": ["事業所名称", "二次元コード", "一部負担金割合", "自己負担限度額区分"],
    23	      "rules": [
    24	        {"field": "保険者番号・記号・番号・枝番・被保険者番号",
    25	         "fields": ["hokensha_bango", "kigo", "bango", "edaban", "hihokensha_bango"],
    26	         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": [], "level": "auto",
    27	         "legal_basis": "健康保険法等 告知要求制限（2020-10-01施行）: 医療保険事務以外の目的での告知要求を原則禁止。提出先が受領する場合もマスキングを求める運用。my_number_procedure は明示しない（医療保険関係事務で番号が必要な例外の有無が確認不可） → null",
    28	         "source": ["https://www.mhlw.go.jp/stf/newpage_13989.html", "https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf", "https://www.kyosai.metro.tokyo.jp/assets/84b47fd406a8378372a6015863f83bc93c0c8a75.pdf"], "verified": true},
    29	        {"field": "二次元コード", "fields": ["qr"],
    30	         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "level": "auto",
    31	         "legal_basis": "番号を判読可能なため同一扱い（大阪府・千葉市運用）", "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"], "verified": true},
    32	        {"field": "性別", "fields": ["sex"], "mask_when": ["identity_submit"], "level": "recommend",
    33	         "legal_basis": "法定ではない。民間KYC事業者の運用（SoftBank, PayPay銀行等）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
    34	        {"field": "氏名・生年月日・住所・有効期限", "fields": ["name", "birth", "address", "expiry"],
    35	         "mask_when": [], "must_keep_when": ["identity_submit", "bid_attachment"], "optional_when": ["consult_share"], "level": "keep",
    36	         "legal_basis": "本人特定事項。マスキングすると受付不可。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）",
    37	         "source": ["https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html"], "verified": true},
    38	        {"field": "事業所名称・保険者名・資格取得年月日", "fields": ["jigyosho", "hokensha_name", "shikaku_date"],
    39	         "mask_when": [], "must_keep_when": ["identity_submit", "bid_attachment"], "optional_when": ["consult_share"], "level": "keep",
    40	         "legal_basis": "資格の有効性を提出先が照合する欄という運用判断。法定の must-keep ではなく出典もない（警告のみで、自動マスキング対象には決してしない）",
    41	         "source": [], "verified": false}
    42	      ]
    43	    },
    44	    {
    45	      "id": "unten_menkyo", "name": "運転免許証", "sides": ["表", "裏"],
    46	      "fields_front": ["氏名", "生年月日", "住所", "交付日", "有効期限", "免許の条件", "番号(12桁)", "種類・取得日", "顔写真", "公安委員会名"],
    47	      "fields_back": ["備考欄（住所・氏名等の変更記載）", "臓器提供意思表示欄"],
    48	      "note": "本籍は券面に印字されない（ICチップ内）",
    49	      "rules": [
    50	        {"field": "裏面 備考欄（変更記載）", "fields": ["biko_change"],
    51	         "mask_when": ["identity_submit", "consult_share"], "level": "recommend",
    52	         "legal_basis": "旧住所等の不要情報。提出先指示優先（住所変更確認で裏面が必要な場合あり）", "source": ["https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true},
    53	        {"field": "臓器提供意思表示欄", "fields": ["organ_donor"],
    54	         "mask_when": ["identity_submit", "consult_share"], "level": "recommend",
    55	         "legal_basis": "民間KYC運用（SoftBank: 臓器提供意思をマスキング）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
    56	        {"field": "番号(12桁)", "fields": ["license_no"],
    57	         "mask_when": ["consult_share"], "must_keep_when": ["identity_submit"], "level": "optional",
    58	         "legal_basis": "個人識別符号（個人情報保護法施行令）。KYCでは照合に必要な提出先が多い → 本人確認提出では must-keep、相談用共有では既定OFFで選択可",
    59	         "source": [], "verified": false},
    60	        {"field": "氏名・生年月日・住所・有効期限・顔写真", "fields": ["name", "birth", "address", "expiry"],
    61	         "must_keep_when": ["identity_submit"], "optional_when": ["consult_share"], "level": "keep",
    62	         "legal_basis": "本人特定事項。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）。顔写真は検出規則がないため fields に含まない",
    63	         "verified": true, "source": ["https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html"]}
    64	      ]
    65	    },
    66	    {
    67	      "id": "mynumber_card", "name": "マイナンバーカード（個人番号カード）", "sides": ["表", "裏"],
    68	      "fields_front": ["氏名", "住所", "生年月日", "性別", "有効期限", "顔写真", "券面記載事項追記欄", "臓器提供意思表示欄"],
    69	      "fields_back": ["個人番号", "氏名", "生年月日(要確認)", "二次元コード"],
    70	      "unverified": ["裏面の生年月日印字有無"],
    71	      "rules": [
    72	        {"field": "裏面全体", "fields": ["back_all", "my_number", "qr"],
    73	         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": ["my_number_procedure"], "level": "auto_with_purpose_gate",
    74	         "legal_basis": "番号法: 法令で認められた者・目的以外での個人番号の収集・保管禁止。身元確認目的では裏面を提出しない。コード上は 裏面全体(back_all) / 個人番号(my_number) / 二次元コード(qr) の3キーに分解する（面全体の띠 + 番号そのもの + コード）が、規則はこの1条である",
    75	         "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/", "https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true,
    76	         "gate_requires_confirmation": "my_number_procedure への解除は目的ドロップダウンだけでは足りない。提出先が法定の個人番号関係事務を行うという確認（チェックボックス1つ）を要求する — PPC FAQ は「意図せず見た」と「複写・記録」を区別するが、どちらも提出先の適法性を前提にしている"},
    77	        {"field": "表面 性別・臓器提供意思表示欄", "fields": ["sex", "organ_donor"],
    78	         "mask_when": ["identity_submit"], "level": "recommend", "legal_basis": "民間KYC運用", "source": ["https://www.aspicjapan.org/asu/article/6908"], "verified": true},
    79	        {"field": "表面 氏名・住所・生年月日・有効期限・顔写真", "fields": ["name", "birth", "address", "expiry"],
    80	         "must_keep_when": ["identity_submit", "my_number_procedure"], "optional_when": ["consult_share"], "level": "keep",
    81	         "legal_basis": "本人特定事項。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）。顔写真は検出規則がないため fields に含まない",
    82	         "verified": true, "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"]}
    83	      ]
    84	    },
    85	    {
    86	      "id": "juminhyo", "name": "住民票の写し",
    87	      "variants": ["世帯全員/一部", "個人番号 あり/なし", "本籍・筆頭者 あり/なし", "外国人住民（国籍・在留資格・在留期間・在留カード番号）", "住民票コード付（窓口のみ）"],
    88	      "rules": [
    89	        {"field": "個人番号", "fields": ["my_number"],
    90	         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": ["my_number_procedure"], "level": "auto_with_purpose_gate",
    91	         "legal_basis": "番号法 収集制限。本人確認目的なら個人番号なしの住民票を取り直すのが原則", "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"], "verified": true,
    92	         "gate_requires_confirmation": "mynumber_card 裏面全体と同じ確認を要求する"},
    93	        {"field": "住民票コード", "fields": ["jumin_code"],
    94	         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "level": "recommend",
    95	         "legal_basis": "住民基本台帳法 利用制限（個人識別符号）と理解しているが条文・運用の出典を確保できていない → verified=false。既定ON で帯を引くが『自動（auto）』とは呼ばない",
    96	         "source": [], "verified": false},
    97	        {"field": "本籍・筆頭者", "fields": ["honseki", "hittosha"],
    98	         "mask_when": ["identity_submit", "consult_share"], "optional_when": ["my_number_procedure", "bid_attachment"], "level": "recommend",
    99	         "legal_basis": "民間KYC運用（SoftBank: 住民票の本籍をマスキング）。個人番号手続・入札添付で不要という出典はないため既定ONにはしない（既定OFFで選択可）",
   100	         "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
   101	        {"field": "本人以外の世帯員", "fields": ["setaiin"],
   102	         "mask_when": ["identity_submit", "consult_share"], "optional_when": ["my_number_procedure", "bid_attachment"], "level": "recommend",
   103	         "legal_basis": "第三者情報。提出先が世帯全員を要求する場合は維持", "source": [], "verified": false},
   104	        {"field": "氏名・生年月日・住所・発行日・発行者", "fields": ["name", "birth", "address", "issuer"],
   105	         "must_keep_when": ["identity_submit", "bid_attachment"], "optional_when": ["consult_share"], "level": "keep",
   106	         "legal_basis": "本人特定事項と証明書の成立要件。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）。⚠ 既知の空白: 発行日 も 発行者(issuer) も検出規則がない — ラベルを持たない行（「見本市長 架空 太郎（公印省略）」）なので、ラベル錨ではなく 市長|区長|町長|村長 のヒューリスティックが要る。この keep 規則は現状 警告を生成できない（s3b 백로그 B-15）",
   107	         "verified": true, "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"]}
   108	      ]
   109	    }
   110	  ],
   111	  "general_jp": {
   112	    "_why": "문서 종류와 무관하게 네 문서 전부에 적용되는 두 규칙. 어느 문서도 증명해야 하는 내용이 아니므로 항상 제공(optional)하고, 공유의 목적이 상담일 때만 기본 ON(recommend). 법적 출처가 없으므로 recommend 이하만 — auto·gate 는 금지된다.",
   113	    "applies_to": ["shikaku_kakuninsho", "unten_menkyo", "mynumber_card", "juminhyo"],
   114	    "rules": [
   115	      {"field": "文書内の自由記述の住所（ラベルのない住所）", "fields": ["address_loose"],
   116	       "mask_when": ["consult_share"], "optional_when": ["identity_submit", "my_number_procedure", "bid_attachment"], "level": "recommend",
   117	       "legal_basis": "ラベル付きの 住所 とは別キー。備考欄や自由記述に残った旧住所など、提出先が要求していない住所。出典なし", "source": [], "verified": false},
   118	      {"field": "電話・FAX", "fields": ["tel"],
   119	       "mask_when": ["consult_share"], "optional_when": ["identity_submit", "my_number_procedure", "bid_attachment"], "level": "recommend",
   120	       "legal_basis": "4文書のいずれも電話番号を証明事項として持たない。出典なし", "source": [], "verified": false}
   121	    ]
   122	  },
   123	  "levels": {"auto": "文書分類+ラベル一致で自動黒塗り", "auto_with_purpose_gate": "目的選択後に自動（別目的では解除。解除には確認が必要）", "recommend": "既定ON・解除可", "optional": "既定OFF・選択可", "keep": "黒塗り禁止（警告）", "null": "この目的では UI に出さない（매트릭스가 명시하지 않은 조합）"}
   124	}
    90	                v = Q.get(kind)
    91	                if isinstance(v, list):
    92	                    Q[kind] = [k for k in v if k == "ALL" or k in boxes]
    93	            pruned[pk] = Q
    94	        meta["purposes"] = pruned
    95	    spec = {"file": os.path.basename(path_base), "size": [W, H], "boxes_png": boxes, **meta,
    96	            "note": "jpg는 회전·흐림 적용으로 박스 좌표 불일치 → 탐지는 OCR 좌표로 재계산, png/pdf 좌표만 골든 비교"}
    97	    json.dump(spec, open(path_base + ".specs.json", "w"), ensure_ascii=False, indent=1)
    98	
    99	# ---------- 1. 資格確認書 (카드형, 보험자 3종 변형) ----------
   100	def shikaku(variant):
   101	    W, H = 1100, 700; img = Image.new("RGBA", (W, H), (248, 248, 244, 255)); d = ImageDraw.Draw(img)
   102	    d.rectangle([20,20,W-20,H-20], outline=(120,120,120), width=3)
   103	    title = {"kenpo":"資格確認書（被用者保険・架空）", "kokuho":"国民健康保険 資格確認書（架空）", "kouki":"後期高齢者医療 資格確認書（架空）"}[variant]
   104	    d.text((40, 40), title, font=F(30, True), fill=(30,30,30))
   105	    boxes = {}; n = name(); mn = mynumber_invalid()
   106	    y = 110
   107	    if variant == "kouki":
   108	        label_val(d, 40, y, "被保険者番号", "9999" + str(random.randint(1000,9999)), 200, 26, boxes, "hihokensha_bango"); y += 50
   109	    else:
   110	        label_val(d, 40, y, "記号", str(random.randint(90000000,99999999)), 120, 26, boxes, "kigo")
   111	        label_val(d, 420, y, "番号", str(random.randint(900,999)), 100, 26, boxes, "bango")
   112	        label_val(d, 700, y, "枝番", f"{random.randint(0,99):02d}", 100, 26, boxes, "edaban"); y += 50
   113	    label_val(d, 40, y, "氏名", n, 120, 28, boxes, "name"); y += 48
   114	    label_val(d, 40, y, "生年月日", wareki(), 160, 24, boxes, "birth")
   115	    label_val(d, 520, y, "性別", random.choice(["男","女"]), 80, 24, boxes, "sex"); y += 46
   116	    label_val(d, 40, y, "住所", addr(), 120, 22, boxes, "address"); y += 46
   117	    label_val(d, 40, y, "資格取得年月日", "令和7年4月1日", 220, 22, boxes, "shikaku_date")
   118	    label_val(d, 520, y, "有効期限", "令和12年3月31日", 140, 22, boxes, "expiry"); y += 46
   119	    if variant == "kenpo":
   120	        label_val(d, 40, y, "事業所名称", "架空株式会社", 160, 22, boxes, "jigyosho"); y += 46
   121	    label_val(d, 40, y, "保険者番号", hokensha(), 160, 26, boxes, "hokensha_bango")
   122	    label_val(d, 520, y, "保険者名", {"kenpo":"架空健康保険協会","kokuho":"見本市","kouki":"架空県後期高齢者医療広域連合"}[variant], 140, 20, boxes, "hokensha_name"); y += 50
   123	    # 二次元コード 자리: 실제 QR 대신 "二次元コード欄(模擬)" 회색 박스 — 판독 불가
   124	    d.rectangle([W-220, H-220, W-60, H-60], fill=(200,200,200), outline=(120,120,120)); d.text((W-212, H-150), "二次元コード欄\n(模擬・判読不可)", font=F(16), fill=(80,80,80))
   125	    boxes["qr"] = [W-220, H-220, W-60, H-60]
   126	    mihon(d, W, H)
   127	    purposes = {
   128	        "本人確認提出": {"mask": ["hokensha_bango","kigo","bango","edaban","hihokensha_bango","qr"], "recommend": ["sex"], "keep": ["name","birth","address","expiry","jigyosho"],
   129	                     "legal_basis": "健康保険法 告知要求制限 (2020-10-01). QRは番号判読可能なため同一扱い", "source": "https://www.mhlw.go.jp/stf/newpage_13989.html"},
   130	        "医療機関提示": {"mask": [], "keep": "all", "legal_basis": "医療保険事務は告知要求制限の対象外"}}
   131	    finalize(img, f"{OUT}/shikaku_kakuninsho/{variant}", {k:v for k,v in boxes.items()}, {"doc":"資格確認書","variant":variant,"purposes":purposes})
   132	
   133	# ---------- 2. 運転免許証 (앞·뒤, 도식형) ----------
   134	def license_card(side):
   135	    W, H = 1100, 700; img = Image.new("RGBA", (W, H), (244, 247, 244, 255)); d = ImageDraw.Draw(img)
   136	    d.rectangle([20,20,W-20,H-20], outline=(120,120,120), width=3); boxes = {}
   137	    if side == "front":
   138	        d.text((40, 40), "運転免許証（架空・図式）", font=F(30, True), fill=(30,30,30))
   139	        d.rectangle([W-300, 100, W-80, 380], fill=(210,215,220), outline=(120,120,120)); d.text((W-280, 220), "顔写真欄\n(シルエット)", font=F(18), fill=(70,70,70)); boxes["photo"]=[W-300,100,W-80,380]
   140	        n = name(); y = 110
   141	        label_val(d, 40, y, "氏名", n, 120, 28, boxes, "name"); y += 50
   142	        label_val(d, 40, y, "生年月日", wareki(), 160, 24, boxes, "birth"); y += 46
   143	        label_val(d, 40, y, "住所", addr(), 120, 22, boxes, "address"); y += 46
   144	        label_val(d, 40, y, "交付", "令和6年5月10日", 120, 22, boxes, "issue"); y += 46
   145	        label_val(d, 40, y, "有効期限", "令和11年6月30日まで有効", 160, 22, boxes, "expiry"); y += 46
   146	        label_val(d, 40, y, "番号", "第 " + license_no() + " 号", 120, 26, boxes, "license_no"); y += 50
   147	        label_val(d, 40, y, "種類", "普通 / 原付", 120, 22, boxes, "types")
   148	        d.text((40, H-80), "（公安委員会名・公印・IC表示は意図的に省略）", font=F(16), fill=(120,120,120))
   149	        # 免許証番号 is must-keep for 本人確認提出 per the legal matrix (照合に必要と
   150	        # する提出先が多い); it is `optional` only under 相談用共有.
   151	        purposes = {"本人確認提出": {"mask": [], "optional": [], "keep": ["name","birth","address","expiry","photo","license_no"], "legal_basis": "提出先指示優先。免許証番号は本人確認提出では must-keep（照合に必要とする提出先が多い）、相談用共有では既定OFFで選択可"}}
   152	    else:
   153	        d.text((40, 40), "運転免許証 裏面（架空・図式）", font=F(30, True), fill=(30,30,30))
   154	        d.text((40, 110), "備考欄（住所・氏名等の変更記載）", font=F(22), fill=(90,90,90))
   155	        d.rectangle([40, 145, W-40, 330], outline=(120,120,120));
   156	        d.text((60, 160), "令和7年1月15日 住所変更  " + addr(), font=F(22), fill=(20,20,20)); boxes["biko_change"] = [40,145,W-40,330]
   157	        d.text((40, 360), "臓器提供意思表示欄（任意記載・模擬）", font=F(22), fill=(90,90,90))
   158	        d.rectangle([40, 395, W-40, 560], outline=(120,120,120)); d.text((60, 410), "1. 脳死後・心停止後のいずれでも提供します（模擬）", font=F(20), fill=(20,20,20)); boxes["organ_donor"] = [40,395,W-40,560]
   159	        purposes = {"本人確認提出": {"mask": ["biko_change","organ_donor"], "keep": [], "legal_basis": "裏面変更記載は旧住所等の不要情報、臓器提供欄は要配慮情報に準ずる（SoftBank等の提出先指示）", "source": "https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"}}
   160	    mihon(d, W, H)
   161	    finalize(img, f"{OUT}/unten_menkyo/{side}", boxes, {"doc":"運転免許証","variant":side,"purposes":purposes})
   162	
   163	# ---------- 3. マイナンバーカード (앞·뒤, 도식형) ----------
   164	def mynumber_card(side):
   165	    W, H = 1100, 700; img = Image.new("RGBA", (W, H), (246, 244, 250, 255)); d = ImageDraw.Draw(img)
   166	    d.rectangle([20,20,W-20,H-20], outline=(120,120,120), width=3); boxes = {}
   167	    if side == "front":
   168	        d.text((40, 40), "個人番号カード 表面（架空・図式）", font=F(30, True), fill=(30,30,30))
   169	        d.rectangle([W-300, 100, W-80, 380], fill=(210,215,220), outline=(120,120,120)); d.text((W-280, 220), "顔写真欄\n(シルエット)", font=F(18), fill=(70,70,70)); boxes["photo"]=[W-300,100,W-80,380]
   170	        n = name(); y = 110
   171	        label_val(d, 40, y, "氏名", n, 120, 28, boxes, "name"); y += 50
   172	        label_val(d, 40, y, "住所", addr(), 120, 22, boxes, "address"); y += 46
   173	        label_val(d, 40, y, "生年月日", wareki(), 160, 24, boxes, "birth")
   174	        label_val(d, 560, y, "性別", random.choice(["男","女"]), 80, 24, boxes, "sex"); y += 46
   175	        label_val(d, 40, y, "有効期限", "2035年3月31日まで有効", 160, 22, boxes, "expiry"); y += 46
   176	        d.text((40, y), "臓器提供意思表示欄（模擬）", font=F(18), fill=(90,90,90)); d.rectangle([40, y+30, W-340, y+120], outline=(120,120,120)); boxes["organ_donor"]=[40,y+30,W-340,y+120]
   177	        purposes = {"身元確認": {"mask": [], "recommend": ["sex","organ_donor"], "keep": ["name","address","birth","expiry","photo"], "legal_basis": "表面は本人同意で複写可（PPC FAQ）", "source": "https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"}}
   178	    else:
   179	        d.text((40, 40), "個人番号カード 裏面（架空・図式）", font=F(30, True), fill=(30,30,30))
   180	        y = 130
   181	        label_val(d, 40, y, "個人番号", " ".join([mynumber_invalid()[i:i+4] for i in (0,4,8)]), 160, 34, boxes, "my_number"); y += 70
   182	        label_val(d, 40, y, "氏名", name(), 120, 26, boxes, "name"); y += 50
   183	        label_val(d, 40, y, "生年月日", wareki(), 160, 24, boxes, "birth"); y += 50
   184	        d.rectangle([W-220, H-220, W-60, H-60], fill=(200,200,200), outline=(120,120,120)); d.text((W-212, H-150), "二次元コード欄\n(模擬・判読不可)", font=F(16), fill=(80,80,80)); boxes["qr"]=[W-220,H-220,W-60,H-60]
   185	        d.text((40, H-80), "（裏面の生年月日有無は公式見本で要確認 — 未確認項目）", font=F(16), fill=(120,120,120))
   186	        purposes = {"身元確認": {"mask": ["ALL"], "legal_basis": "番号法: 法定目的以外の個人番号の複写・保管禁止 → 身元確認では裏面を提出しない", "source": "https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"},
   187	                    "個人番号手続": {"mask": [], "keep": ["my_number","name","birth"], "legal_basis": "税・社会保障等の個人番号関係事務では裏面提出が必要"}}
   188	    mihon(d, W, H)
   189	    finalize(img, f"{OUT}/mynumber_card/{side}", boxes, {"doc":"マイナンバーカード","variant":side,"purposes":purposes})
   190	
   191	# ---------- 4. 住民票の写し (A4 PDF + PNG, 변형 4) ----------
   192	def juminhyo(variant):
   193	    # variant: zenin_mynumber / ichibu_plain / honseki_on / gaikokujin
   194	    W, H = 1240, 1754; img = Image.new("RGBA", (W, H), (255,255,255,255)); d = ImageDraw.Draw(img); boxes = {}
   195	    d.text((W/2-120, 70), "住 民 票（架空・図式）", font=F(40, True), fill=(20,20,20))
   196	    d.text((W-420, 130), "発行日 令和8年10月21日", font=F(22), fill=(20,20,20))
   197	    y = 200; members = 3 if variant == "zenin_mynumber" else 1
   198	    label_val(d, 80, y, "住所", addr(), 140, 26, boxes, "address"); y += 60
   199	    head = name()
   200	    label_val(d, 80, y, "世帯主", head, 140, 26, boxes, "setainushi"); y += 70
   201	    for i in range(members):
   202	        d.line([80, y-10, W-80, y-10], fill=(150,150,150), width=2)
   203	        n = head if i == 0 else name(); k = f"m{i+1}_"
   204	        label_val(d, 80, y, "氏名", n, 140, 28, boxes, k+"name"); label_val(d, 700, y, "続柄", ["本人","妻","子"][i], 100, 24, boxes, k+"zokugara"); y += 50
   205	        label_val(d, 80, y, "生年月日", wareki(), 160, 24, boxes, k+"birth"); label_val(d, 700, y, "性別", random.choice(["男","女"]), 100, 24, boxes, k+"sex"); y += 50
   206	        label_val(d, 80, y, "住民となった日", "平成30年4月1日", 220, 22, boxes, k+"since"); y += 50
   207	        if variant in ("honseki_on", "zenin_mynumber"):
   208	            label_val(d, 80, y, "本籍", addr(), 140, 22, boxes, k+"honseki"); y += 46
   209	            label_val(d, 80, y, "筆頭者", n, 140, 22, boxes, k+"hittosha"); y += 46
   210	        if variant == "zenin_mynumber":
   211	            label_val(d, 80, y, "個人番号", mynumber_invalid(), 160, 26, boxes, k+"my_number"); y += 50
   212	        if variant == "gaikokujin":
   213	            label_val(d, 80, y, "国籍・地域", "架空国", 160, 22, boxes, k+"kokuseki"); y += 46
   214	            label_val(d, 80, y, "在留資格", "技術・人文知識・国際業務", 160, 22, boxes, k+"zairyu_shikaku"); y += 46
   215	            label_val(d, 80, y, "在留期間", "5年（2030年3月31日まで）", 160, 22, boxes, k+"zairyu_kikan"); y += 46

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "nl -ba public/safe/index.html | sed -n '1671,1988p'
nl -ba public/safe/index.html | sed -n '2570,2640p'
nl -ba test/safe/run.mjs | sed -n '120,225p'
nl -ba test/safe/run.mjs | sed -n '566,700p'
nl -ba test/safe/run.mjs | sed -n '718,895p'" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
  1671	function jpExtract(pi, cls){
  1672	  const segs = jpSegments(pi), found = [];
  1673	  // Every value rule anchors at the SEGMENT HEAD. In these forms the label always
  1674	  // opens its own column, so a label found mid-segment is prose, not an anchor —
  1675	  // that is how the 「裏面の生年月日有無は…要確認」 footnote on the card dummy got
  1676	  // read as a 生年月日 field. (The 欄 region labels below deliberately do not use
  1677	  // this: OCR puts a garbled 騰 in front of 器提供意思表示欄.)
  1678	  const rules = (JP_FIELD_RULES[cls.doc] || [])
  1679	    .filter(r => !r.sides || r.sides.includes(cls.side))
  1680	    .map(r => ({ ...r, headOnly: true }));
  1681	  // Every finding carries the classification of ITS OWN page. A two-sided card
  1682	  // scanned into one PDF has a different legal rule on each page, so applying
  1683	  // page 1's doc/side to every page made the outcome depend on scan order:
  1684	  // front-then-back left the 個人番号 page untouched, back-then-front banded the
  1685	  // front as well (Codex 6-4).
  1686	  const push = (field, boxes, value, extra) => {
  1687	    if (boxes && boxes.length) found.push({ field, boxes, value, pi, doc: cls.doc, side: cls.side || null, low: !!cls.low, ...extra });
  1688	  };
  1689	
  1690	  for (const seg of segs){
  1691	    for (const r of rules){
  1692	      const L = jpFindLabel(seg, r.labels, r.headOnly);
  1693	      if (!L) continue;
  1694	      if (r.tel){
  1695	        const tail = seg.t.slice(L.end);
  1696	        const hy = JP_TEL_HYPHEN_RE.exec(tail);
  1697	        const pl = hy ? null : JP_TEL_PLAIN_RE.exec(tail);
  1698	        const m = hy || pl;
  1699	        if (!m) continue;
  1700	        const a2 = L.end + m.index, b2 = a2 + m[0].length;
  1701	        push('tel', jpBoxes(seg, a2, b2), m[0], { loose: !hy });
  1702	        for (let k = a2; k < b2; k++) seg.used[k] = 1;
  1703	        continue;
  1704	      }
  1705	      if (r.digits){
  1706	        const sp = jpDigitSpan(seg, L.end, r.digits);
  1707	        if (!sp) continue;
  1708	        const extra = r.field === 'my_number' ? { checkOk: myNumberCheckOk(sp.digits) } : {};
  1709	        push(r.field, jpBoxes(seg, sp.a, sp.b), sp.digits, extra);
  1710	        for (let k = sp.a; k < sp.b; k++) seg.used[k] = 1;
  1711	        continue;
  1712	      }
  1713	      let a = -1, b = -1, val = '';
  1714	      if (r.addr){
  1715	        // 住所/本籍: bound the value by the address hierarchy rather than by
  1716	        // "everything after the label", so a second column that drifted into
  1717	        // this segment is not swept into the band.
  1718	        const sp = jpAddressSpan(seg.t, L.end);
  1719	        if (sp && sp.b > sp.a){ a = sp.a; b = sp.b; val = seg.t.slice(a, b); }
  1720	      } else if (r.re){
  1721	        const m = r.re.exec(seg.t.slice(L.end));
  1722	        if (m){ a = L.end + m.index; b = a + m[0].length; val = m[0]; }
  1723	      }
  1724	      if (a < 0 && r.last !== true) continue;
  1725	      if (a < 0){
  1726	        // value position certain, characters not: take the items after the label
  1727	        const after = seg.items.filter(o => seg.start[o.i] >= L.end);
  1728	        if (!after.length) continue;
  1729	        const boxes = after.map(o => { const b2 = { page: pi, x:o.it.x, y:o.it.y, w:o.it.w, h:o.it.h }; b2.bg = sampleBg(pages[pi], b2); return b2; });
  1730	        push(r.field, boxes, seg.t.slice(L.end).trim() || '(value)');
  1731	        for (let k = L.end; k < seg.t.length; k++) seg.used[k] = 1;
  1732	        continue;
  1733	      }
  1734	      push(r.field, jpBoxes(seg, a, b), val.trim());
  1735	      for (let k = a; k < b; k++) seg.used[k] = 1;
  1736	    }
  1737	  }
  1738	
  1739	  /* Structural fallback — ONLY where OCR has destroyed the label but the format
  1740	     plus the document class still pin the field down. Each is narrow and stated:
  1741	       資格確認書: a bare 6–10 digit run outside any date line is a member of the
  1742	         保険者番号・記号・番号・枝番 family. The 告知要求制限 covers that whole
  1743	         family as ONE rule, so the cost of guessing which member it is, is zero —
  1744	         while a miss is the exact leak the product exists to prevent. Measured:
  1745	         OCR renders 保険者番号 as "RREES"/"REEES"/"WREEES" on 3 of 5 fixtures.
  1746	       住民票: 12 digits = 個人番号, 11 digits = 住民票コード. Both lengths are
  1747	         fixed by statute and nothing else on the form is that long. */
  1748	  const isDateRow = s => JP_DATE_RE.test(s.rowText) || s.rowText.includes('〒');
  1749	  const unconsumed = (seg, a, b) => { for (let k=a;k<b;k++) if (seg.used[k]) return false; return true; };
  1750	  const runs = seg => { const out=[]; let st=-1;
  1751	    for (let k=0;k<=seg.t.length;k++){ const d = k<seg.t.length && isDigit(seg.t[k]);
  1752	      if (d){ if (st<0) st=k; } else if (st>=0){ out.push([st,k]); st=-1; } } return out; };
  1753	  if (cls.doc === 'shikaku_kakuninsho'){
  1754	    for (const seg of segs){
  1755	      if (isDateRow(seg)) continue;
  1756	      for (const [a,b] of runs(seg)){
  1757	        const len = b - a;
  1758	        if (len < 6 || len > 10 || !unconsumed(seg, a, b)) continue;
  1759	        push('hokensha_bango', jpBoxes(seg, a, b), seg.t.slice(a,b), { viaFallback: true });
  1760	        for (let k=a;k<b;k++) seg.used[k]=1;
  1761	      }
  1762	    }
  1763	  }
  1764	  if (cls.doc === 'juminhyo'){
  1765	    for (const seg of segs){
  1766	      if (isDateRow(seg)) continue;
  1767	      for (const [a,b] of runs(seg)){
  1768	        const len = b - a;
  1769	        if (!unconsumed(seg, a, b)) continue;
  1770	        if (len === 12) push('my_number', jpBoxes(seg, a, b), seg.t.slice(a,b), { checkOk: myNumberCheckOk(seg.t.slice(a,b)), viaFallback: true });
  1771	        else if (len === 11) push('jumin_code', jpBoxes(seg, a, b), seg.t.slice(a,b), { viaFallback: true });
  1772	        else continue;
  1773	        for (let k=a;k<b;k++) seg.used[k]=1;
  1774	      }
  1775	    }
  1776	  }
  1777	
  1778	  /* Unlabelled addresses. Anything a label already claimed is marked consumed,
  1779	     so this only sees text standing on its own — 備考欄 contents, free-form
  1780	     notes. Per strategy v2 §3-2 it is automatic ONLY with 郵便番号 AND 都道府県
  1781	     together; otherwise it is a review candidate. It is filed under its own
  1782	     field key so it can never be confused with the LABELLED 住所, which on all
  1783	     four alpha documents is a keep-field the recipient needs. */
  1784	  for (const seg of segs){
  1785	    let from = 0;
  1786	    for (let guard = 0; guard < 4; guard++){
  1787	      const sp = jpAddressSpan(seg.t, from);
  1788	      if (!sp || sp.b <= sp.a) break;
  1789	      from = sp.b;
  1790	      if (sp.score < 3) continue;
  1791	      let free = true; for (let k = sp.a; k < sp.b; k++) if (seg.used[k]) { free = false; break; }
  1792	      if (!free) continue;
  1793	      push('address_loose', jpBoxes(seg, sp.a, sp.b), seg.t.slice(sp.a, sp.b), { strong: sp.postal && sp.pref });
  1794	      for (let k = sp.a; k < sp.b; k++) seg.used[k] = 1;
  1795	    }
  1796	  }
  1797	
  1798	  // 欄 regions (備考欄 / 臓器提供意思表示欄): the drawn rectangle under the label.
  1799	  for (const rr of (JP_REGION_LABELS[cls.doc] || [])){
  1800	    for (const seg of segs){
  1801	      if (!jpFindLabel(seg, rr.labels, false)) continue;
  1802	      const fr = jpFrameBelow(pages[pi], { y: seg.y, h: seg.h });
  1803	      const box = fr ? { ...fr, page: pi }
  1804	                     : { page: pi, x: seg.x0, y: seg.y, w: Math.max(seg.x1-seg.x0, pages[pi].w*0.5), h: seg.h*3.5, region: true };
  1805	      push(rr.field, [box], rr.field);
  1806	      break;
  1807	    }
  1808	  }
  1809	
  1810	  // 二次元コード
  1811	  if (cls.doc === 'shikaku_kakuninsho' || (cls.doc === 'mynumber_card' && cls.side === 'back')){
  1812	    for (const cb of jpCodeBlocks(pi)) push('qr', [cb.box], '二次元コード', { unlabelledCode: !cb.labelled });
  1813	  }
  1814	
  1815	  // 住民票: household member blocks. Block 1 is the subject; blocks 2..n are
  1816	  // third parties whose data the recipient did not ask for. Found by the 氏名
  1817	  // label rows, because 続柄 (本人/妻/子) is a single kanji that OCR mangles far
  1818	  // more often than it mangles a whole label.
  1819	  if (cls.doc === 'juminhyo'){
  1820	    const nameRows = segs.filter(s => jpFindLabel(s, ['氏名'], false)).sort((a,b)=>a.y-b.y);
  1821	    const endRe = /住民票コード|この写し|相違|証明し|市長|区長|町長|村長|公印/;
  1822	    if (nameRows.length > 1){
  1823	      for (let i = 1; i < nameRows.length; i++){
  1824	        const top = nameRows[i].y;
  1825	        const next = i + 1 < nameRows.length ? nameRows[i+1].y : Infinity;
  1826	        const stop = segs.filter(s => s.y > top && s.y < next && endRe.test(s.rowText)).map(s=>s.y);
  1827	        const bottom = stop.length ? Math.min(...stop) : next;
  1828	        const byRow = {};
  1829	        for (const s of segs){
  1830	          if (s.y < top || s.y >= bottom) continue;
  1831	          (byRow[s.row] = byRow[s.row] || []).push(s);
  1832	        }
  1833	        for (const list of Object.values(byRow))
  1834	          push('setaiin', list.map(jpSegBox), (list[0].t || '(世帯員)').slice(0, 24));
  1835	      }
  1836	    }
  1837	    // 氏名/生年月日 inside a THIRD PARTY's block are not the subject's keep-fields.
  1838	    // Leaving them in would put the same pixels in the 残す項目 list and under a
  1839	    // band at the same time — the list would be telling the user the opposite of
  1840	    // what the page shows.
  1841	    const regions = found.filter(f => f.field === 'setaiin').flatMap(f => f.boxes);
  1842	    if (regions.length){
  1843	      const inside = b => regions.some(r => b.x + b.w/2 >= r.x && b.x + b.w/2 <= r.x + r.w
  1844	                                         && b.y + b.h/2 >= r.y && b.y + b.h/2 <= r.y + r.h);
  1845	      for (let i = found.length - 1; i >= 0; i--){
  1846	        const f = found[i];
  1847	        if (!['name','birth','address'].includes(f.field)) continue;
  1848	        if (f.boxes.every(inside)) found.splice(i, 1);
  1849	      }
  1850	    }
  1851	  }
  1852	  return found;
  1853	}
  1854	
  1855	/* ── state + application ── */
  1856	const JP_PURPOSES = ['identity_submit','my_number_procedure','bid_attachment','consult_share'];
  1857	const JP_STATE0 = () => ({ cls: null, pageCls: [], purpose: 'identity_submit', findings: [], warn: null, mnConfirmed: false });
  1858	let jpState = JP_STATE0();
  1859	function jpScan(){
  1860	  const keepPurpose = jpState.purpose;
  1861	  jpState = JP_STATE0(); jpState.purpose = keepPurpose;
  1862	  if (!pages.length) return null;
  1863	  // Per-page classification. Page 0 names the document in the UI, but each page
  1864	  // is governed by its OWN class — and a page that cannot be classified falls
  1865	  // back to page 0's class only when page 0 HAS one.
  1866	  const cls0 = jpClassify(0);
  1867	  const pageCls = [];
  1868	  for (let pi = 0; pi < pages.length; pi++) pageCls.push(pi === 0 ? cls0 : (jpClassify(pi) || cls0));
  1869	  jpState.pageCls = pageCls;
  1870	  if (!cls0){
  1871	    // No Japanese rule will run. Say so if the page looks like one of these
  1872	    // documents, instead of falling through to the Latin heuristics in silence.
  1873	    if (pages.some((p, pi) => jpSuspect(pi))) jpState.warn = 'unclassified';
  1874	    return null;
  1875	  }
  1876	  jpState.cls = cls0;
  1877	  if (pageCls.some(c => c && c.low)) jpState.warn = 'lowconf';
  1878	  let all = [];
  1879	  for (let pi = 0; pi < pages.length; pi++) if (pageCls[pi]) all = all.concat(jpExtract(pi, pageCls[pi]));
  1880	  jpState.findings = all;
  1881	  return cls0;
  1882	}
  1883	function jpFieldLabel(f){ return (T().jpFields && T().jpFields[f]) || f; }
  1884	// Build entities from the findings for the current purpose. Called on load and
  1885	// on every purpose change — the purpose IS the policy, so it re-derives rather
  1886	// than patching modes in place.
  1887	/* The 個人番号 purpose gate needs more than a dropdown. Choosing 「個人番号手続」
  1888	   releases a band that 番号法 put there, and the dropdown alone cannot establish
  1889	   that the recipient actually performs a 個人番号関係事務 — PPC FAQ Q6-12
  1890	   distinguishes seeing a number from copying and keeping it, and both assume the
  1891	   recipient is entitled to it (Codex 4-4). So the release requires the purpose
  1892	   AND an explicit confirmation; until it is given, the band stays. */
  1893	function jpMnGateOpen(){ return jpState.purpose === 'my_number_procedure' && jpState.mnConfirmed; }
  1894	const JP_MN_GATED = new Set(['back_all','my_number','qr']);
  1895	function jpApply(){
  1896	  entities = entities.filter(e => !e.jp);
  1897	  const cls = jpState.cls; if (!cls) { jpRenderBar(); renderAll(); return; }
  1898	  const purpose = jpState.purpose;
  1899	  const add = (f, level, boxes, value, note, ctx) => {
  1900	    const kind = (level === 'auto' || level === 'gate') ? 'auto'
  1901	               : level === 'keep' ? 'keep' : 'candidate';
  1902	    const mode = (level === 'auto' || level === 'gate' || level === 'recommend') ? 'no' : 'ok';
  1903	    // A legal-preset band is not governed by the general category checkboxes.
  1904	    const legal = JP_LEGAL_FIELDS.has(f) && mode === 'no';
  1905	    entities.push({ id:'j'+Math.random().toString(36).slice(2,8), type: JP_TYPE[f] || 'other',
  1906	      value, mode, kind, legal, reason: 'jp_' + level, boxes,
  1907	      jp: { doc: (ctx && ctx.doc) || cls.doc, side: (ctx && ctx.side) || cls.side || null, page: ctx ? ctx.page : null, field: f, level, note: note || null } });
  1908	  };
  1909	  // Resolve the level for one finding under the current purpose, including the
  1910	  // two demotions and the confirmation gate. Returns null = not offered.
  1911	  const resolve = (doc, field, f) => {
  1912	    let level = jpLevel(doc, field, purpose), note = null;
  1913	    if (!level) return null;
  1914	    // Unconfirmed 個人番号手続: the matrix says keep, but the release has not
  1915	    // been confirmed, so the 番号法 band stays as if the purpose were 本人確認.
  1916	    if (level === 'keep' && JP_MN_GATED.has(field) && purpose === 'my_number_procedure' && !jpState.mnConfirmed){
  1917	      level = 'gate'; note = 'mn_unconfirmed';
  1918	    }
  1919	    // A low-confidence classification may not delete pixels on its own.
  1920	    if (f && f.low && (level === 'auto' || level === 'gate')){ level = 'recommend'; note = 'lowconf'; }
  1921	    if (!f) return { level, note };
  1922	    // 個人番号 whose check digit does not verify is NOT confirmed to be a
  1923	    // 個人番号 — it could be any 12-digit reference. Demote the automatic band
  1924	    // to a review candidate (still default-ON) rather than assert something the
  1925	    // arithmetic contradicts.
  1926	    if (field === 'my_number' && (level === 'auto' || level === 'gate') && f.checkOk === false){ level = 'recommend'; note = 'checkdigit'; }
  1927	    // An unlabelled square block has no QR-specific evidence behind it (no
  1928	    // finder pattern, no quiet zone, no module pitch) and no golden coverage —
  1929	    // a face photo, a round seal (bbox fill ≈ 0.785) or a black table header
  1930	    // can all satisfy the size/ratio/fill test. It is OFFERED and left OFF:
  1931	    // a guess must not remove content from the default output (Codex 2-2, 6-1).
  1932	    if (f.unlabelledCode){ level = 'optional'; note = 'unlabelled_code'; }
  1933	    return { level, note };
  1934	  };
  1935	
  1936	  // マイナンバーカード裏面 under a 本人確認 purpose: the whole face, PER PAGE that
  1937	  // is actually a back face. 番号法 does not let the recipient hold the 個人番号
  1938	  // at all for identity checking, so the honest instruction is "submit the front
  1939	  // instead", and the band says so.
  1940	  for (let pi = 0; pi < pages.length; pi++){
  1941	    const pc = jpState.pageCls[pi];
  1942	    if (!pc || pc.doc !== 'mynumber_card' || pc.side !== 'back') continue;
  1943	    const r = resolve('mynumber_card', 'back_all', { low: pc.low });
  1944	    if (r && (r.level === 'auto' || r.level === 'gate' || r.level === 'recommend'))
  1945	      add('back_all', r.level, [{ page: pi, x: 0, y: 0, w: pages[pi].w, h: pages[pi].h, region: true }],
  1946	          jpFieldLabel('back_all'), r.note, { doc: pc.doc, side: pc.side, page: pi });
  1947	  }
  1948	  for (const f of jpState.findings){
  1949	    const r = resolve(f.doc, f.field, f);
  1950	    if (!r) continue;
  1951	    add(f.field, r.level, f.boxes, f.field === 'qr' || f.boxes.some(b=>b.region) ? jpFieldLabel(f.field) : (f.value || jpFieldLabel(f.field)),
  1952	        r.note, { doc: f.doc, side: f.side, page: f.pi });
  1953	  }
  1954	  entities.sort((a,b)=>Object.keys(TYPES).indexOf(a.type)-Object.keys(TYPES).indexOf(b.type));
  1955	  jpRenderBar();
  1956	  renderAll();
  1957	}
  1958	const JP_TYPE = { address_loose:'address', tel:'phone', my_number:'rrn', jumin_code:'rrn', hokensha_bango:'health', kigo:'health',
  1959	  bango:'health', edaban:'health', hihokensha_bango:'health', license_no:'license', qr:'other',
  1960	  back_all:'other', biko_change:'address', organ_donor:'health', setaiin:'name', honseki:'address',
  1961	  hittosha:'name', sex:'other', name:'name', birth:'birth', address:'address', expiry:'other', issue:'other' };
  1962	
  1963	function jpSetPurpose(p){
  1964	  if (!JP_PURPOSES.includes(p)) return;
  1965	  jpState.purpose = p;
  1966	  // Switching purpose always re-asks for the 個人番号 confirmation. A checkbox
  1967	  // left ticked from a previous purpose is not a confirmation of this one.
  1968	  jpState.mnConfirmed = false;
  1969	  const sel = $('jpPurpose'); if (sel) sel.value = p;
  1970	  jpApply();
  1971	}
  1972	function jpSetMnConfirmed(v){ jpState.mnConfirmed = !!v; jpApply(); }
  1973	function jpRenderBar(){
  1974	  const bar = $('jpBar'), warn = $('jpWarn'); if (!bar) return;
  1975	  const cls = jpState.cls;
  1976	  // The blocking warning is independent of the bar: its whole point is to be
  1977	  // visible in the case where there is no classification and therefore no bar.
  1978	  if (warn){
  1979	    const show = !!jpState.warn;
  1980	    warn.textContent = show ? T().jpUnclassifiedWarn : '';
  1981	    warn.style.display = show ? 'block' : 'none';
  1982	  }
  1983	  if (!cls){ bar.style.display = 'none'; return; }
  1984	  bar.style.display = 'flex';
  1985	  $('jpDocName').textContent = jpFieldLabel('doc_' + cls.doc) + (cls.side ? ' · ' + jpFieldLabel('side_' + cls.side) : '');
  1986	  const sel = $('jpPurpose');
  1987	  sel.innerHTML = JP_PURPOSES.map(p => `<option value="${p}">${escapeHtml(jpFieldLabel('purpose_' + p))}</option>`).join('');
  1988	  sel.value = jpState.purpose;
  2570	          <button class="${e.mode==='no'?'on-no':''}" data-id="${e.id}" data-mode="no">${t.segNo}</button>
  2571	        </div>
  2572	      </div>`).join('')}</div>`:''}
  2573	  </div>`;
  2574	}
  2575	// Flat item box for manual selections / name candidates (not category-grouped).
  2576	function sectionHtml(kind,title,items){
  2577	  const t=T(), cand=kind==='candidate';
  2578	  const icon=kind==='candidate'?'❓':kind==='keep'?'🛡':kind==='legal'?'⚖️':'✏️';
  2579	  return `
  2580	  <div class="cat-row sec-${kind}">
  2581	    <div class="cat-head">
  2582	      <span class="cl">${icon} ${title}</span>
  2583	      <span class="cnt hit">${t.cnt(items.length)}</span>
  2584	    </div>
  2585	    <div class="cat-items">${items.map(e=>`
  2586	      <div class="pii-item${cand?' is-cand':''}">
  2587	        <div class="val-wrap">
  2588	          <span class="val ${cand?'':'mono'}" title="${escapeHtml(e.value)}">${escapeHtml(kind==='manual'? t.manualItem : displayValue(e))}</span>
  2589	          ${(cand||kind==='keep'||kind==='legal')?`<span class="reason">${(TYPES[e.type]||{}).icon||''} ${t.reasons[e.reason]||(e.jp?t.reasons.jp_keep:t.reasons.name)}</span>`:''}
  2590	        </div>
  2591	        <div class="seg" role="radiogroup">
  2592	          <button class="${e.mode==='ok'?'on-ok':''}" data-id="${e.id}" data-mode="ok">${t.segOk}</button>
  2593	          <button class="${e.mode==='no'?'on-no':''}" data-id="${e.id}" data-mode="no">${t.segNo}</button>
  2594	        </div>
  2595	        ${kind==='manual'?`<button class="del" data-del="${e.id}" title="remove" aria-label="remove">✕</button>`:''}
  2596	      </div>`).join('')}</div>
  2597	  </div>`;
  2598	}
  2599	function renderList(){
  2600	  const list=$('piiList'), t=T();
  2601	  // Legal-preset bands come out of the category grouping entirely — they are not
  2602	  // a "type" the user turns off, they are a rule with a citation.
  2603	  const legalE=entities.filter(e=>e.legal);
  2604	  const autoE=entities.filter(e=>!e.legal&&e.kind!=='candidate'&&e.kind!=='manual'&&e.kind!=='keep');
  2605	  const manualE=entities.filter(e=>!e.legal&&e.kind==='manual');
  2606	  const candE=entities.filter(e=>!e.legal&&e.kind==='candidate');
  2607	  const keepE=entities.filter(e=>!e.legal&&e.kind==='keep');
  2608	  const total=entities.filter(isOn).length;
  2609	  $('piiCount').textContent= total? t.cntUse(total):'';
  2610	  document.querySelectorAll('#bulkBtns button').forEach(b=>b.disabled=!total);
  2611	  $('catHint').textContent = pages.length? t.hintAfter : t.hintBefore;
  2612	  const groups={};
  2613	  for(const e of autoE){(groups[e.type]=groups[e.type]||[]).push(e);}
  2614	  const all=Object.keys(TYPES).filter(ty=>ty!=='manual');
  2615	  if(!pages.length){
  2616	    list.innerHTML = all.map(ty=>catRowHtml(ty,[])).join('');
  2617	    return;
  2618	  }
  2619	  const hits=all.filter(ty=>groups[ty]&&groups[ty].length);
  2620	  const misses=all.filter(ty=>!groups[ty]||!groups[ty].length);
  2621	  let html=hits.map(ty=>catRowHtml(ty,groups[ty])).join('');
  2622	  if(misses.length){
  2623	    html+=`<button class="more-cats" id="moreCats">${showAllCats? t.moreHide : t.moreShow(misses.length)}</button>`;
  2624	    if(showAllCats) html+=misses.map(ty=>catRowHtml(ty,[])).join('');
  2625	  }
  2626	  if(legalE.length)  html=sectionHtml('legal', t.jpLegalSection, legalE)+html;
  2627	  if(manualE.length) html+=sectionHtml('manual', t.manualSection, manualE);
  2628	  if(candE.length)   html+=sectionHtml('candidate', t.candSection, candE);
  2629	  if(keepE.length)   html+=sectionHtml('keep', t.keepSection, keepE);
  2630	  list.innerHTML=html;
  2631	}
  2632	$('piiList').addEventListener('change',e=>{
  2633	  const cb=e.target.closest('input[data-cat]'); if(!cb) return;
  2634	  catEnabled[cb.dataset.cat]=cb.checked; renderAll();
  2635	});
  2636	$('piiList').addEventListener('click',e=>{
  2637	  if(e.target.closest('#moreCats')){showAllCats=!showAllCats;renderList();return;}
  2638	  const del=e.target.closest('button[data-del]');
  2639	  if(del){ entities=entities.filter(x=>x.id!==del.dataset.del); renderAll(); toast(T().tManualRemoved); return; }
  2640	  const cm=e.target.closest('button[data-cmode]');
   120	        if (b.page !== rect.pi) continue;
   121	        if (!(b.x + b.w < rect.x || rect.x + rect.w < b.x || b.y + b.h < rect.y || rect.y + rect.h < b.y)) return true;
   122	      }
   123	    }
   124	    return false;
   125	  };
   126	  /* ── ink coverage (replaces the 60% area gate on number fields) ──
   127	     A 60% area figure says HOW MUCH of a box was painted, never WHERE: the
   128	     kouki fixture measured 96% with its leading digit fully outside the band
   129	     (Codex 5-3, and we had already recorded it). So for a field whose value is
   130	     a number, the question is per-GLYPH: take the ink inside the expected box,
   131	     label its connected components, and require every component to be covered.
   132	     Threshold 60 (not the detector's 40) deliberately excludes the fixtures'
   133	     見本 watermark — composited it sits ~48 off the background, and a band is
   134	     not required to cover a watermark. */
   135	  window.__inkCover = function (rect) {
   136	    const p = pages[rect.pi]; if (!p) return null;
   137	    const CW = p.canvas.width, CH = p.canvas.height;
   138	    const x0 = Math.max(0, Math.floor(rect.x)), y0 = Math.max(0, Math.floor(rect.y));
   139	    const x1 = Math.min(CW, Math.ceil(rect.x + rect.w)), y1 = Math.min(CH, Math.ceil(rect.y + rect.h));
   140	    const W = x1 - x0, H = y1 - y0;
   141	    if (W <= 0 || H <= 0) return { components: 0, inkPx: 0, uncovered: 0, worst: 1 };
   142	    const ctx = p.canvas.getContext('2d', { willReadFrequently: true });
   143	    const d = ctx.getImageData(x0, y0, W, H).data, bg = jpPageBg(p);
   144	    const ink = new Uint8Array(W * H);
   145	    let inkPx = 0;
   146	    for (let i = 0; i < W * H; i++) {
   147	      if (Math.abs(d[i * 4] - bg[0]) > 60 || Math.abs(d[i * 4 + 1] - bg[1]) > 60 || Math.abs(d[i * 4 + 2] - bg[2]) > 60) { ink[i] = 1; inkPx++; }
   148	    }
   149	    const mr = window.__maskRects().filter(r => r.pi === rect.pi);
   150	    const covered = (px, py) => mr.some(r => px >= r.x && px <= r.x + r.w && py >= r.y && py <= r.y + r.h);
   151	    const seen = new Uint8Array(W * H);
   152	    let components = 0, uncovered = 0, worst = 1;
   153	    for (let i = 0; i < W * H; i++) {
   154	      if (!ink[i] || seen[i]) continue;
   155	      const st = [i]; seen[i] = 1; let n = 0, cov = 0;
   156	      while (st.length) {
   157	        const k = st.pop(), kx = k % W, ky = (k - kx) / W;
   158	        n++; if (covered(x0 + kx + 0.5, y0 + ky + 0.5)) cov++;
   159	        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
   160	          const nx = kx + dx, ny = ky + dy;
   161	          if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
   162	          const nk = ny * W + nx;
   163	          if (ink[nk] && !seen[nk]) { seen[nk] = 1; st.push(nk); }
   164	        }
   165	      }
   166	      // Specks (anti-aliasing debris, watermark bleed) are not glyphs.
   167	      if (n < 6) continue;
   168	      components++;
   169	      const f = cov / n;
   170	      if (f < worst) worst = f;
   171	      if (f < 0.99) uncovered++;
   172	    }
   173	    return { components, inkPx, uncovered, worst };
   174	  };
   175	  /* Every entity carrying `field`, with the facts require_banded is actually
   176	     about: is it located, is its category ON, is it not 'ok', and do the rects
   177	     it would paint ACTUALLY appear in the active mask-rect list? The old
   178	     assertion read `mode !== 'ok'` alone, which stays true for an entity whose
   179	     category is off or whose boxes are empty (Codex 5-5). */
   180	  window.__fieldBands = function (field) {
   181	    const mr = window.__maskRects();
   182	    const same = (a, b) => Math.abs(a.x - b.x) < 0.01 && Math.abs(a.y - b.y) < 0.01 && Math.abs(a.w - b.w) < 0.01 && Math.abs(a.h - b.h) < 0.01;
   183	    return entities.filter(e => e.jp && e.jp.field === field).map(e => {
   184	      const rects = [];
   185	      for (let pi = 0; pi < pages.length; pi++) for (const l of mergeLineBoxes(e.boxes || [], pi)) { const r = bandRect(l); rects.push({ pi, ...r }); }
   186	      return { level: e.jp.level, note: e.jp.note, page: e.jp.page, doc: e.jp.doc, side: e.jp.side,
   187	        kind: e.kind, mode: e.mode, legal: !!e.legal, located: !!(e.boxes && e.boxes.length), on: isOn(e),
   188	        rects: rects.length, inMask: rects.length > 0 && rects.every(r => mr.some(m => m.pi === r.pi && same(m, r))) };
   189	    });
   190	  };
   191	  window.__jpState = function () {
   192	    return { cls: jpState.cls && { doc: jpState.cls.doc, side: jpState.cls.side || null, score: jpState.cls.score, low: !!jpState.cls.low },
   193	      purpose: jpState.purpose, warn: jpState.warn, mnConfirmed: jpState.mnConfirmed,
   194	      pageCls: jpState.pageCls.map(c => c && { doc: c.doc, side: c.side || null, low: !!c.low }),
   195	      warnShown: (() => { const el = document.getElementById('jpWarn'); return !!el && el.style.display !== 'none' && !!el.textContent.trim(); })(),
   196	      mnBoxShown: (() => { const el = document.getElementById('jpMnWrap'); return !!el && el.style.display !== 'none'; })(),
   197	      pw: pages.map(p => p.w),
   198	      fields: entities.filter(e => e.jp).map(e => ({ field: e.jp.field, level: e.jp.level, note: e.jp.note, page: e.jp.page, kind: e.kind, mode: e.mode, legal: !!e.legal, on: isOn(e) })) };
   199	  };
   200	  // Field labels of every ACTIVE auto entity — the allowlist assertion's input.
   201	  window.__autoFields = function () {
   202	    return entities.filter(e => e.kind === 'auto').map(e => e.jp ? e.jp.field : '(regex:' + e.type + ')');
   203	  };
   204	  /* Turn every general category OFF. A legal-preset band must survive this.
   205	     catEnabled is module-level state that resetAll() and a fresh file load do
   206	     NOT restore, so this hands back a restore function — the first version of
   207	     this helper left every category off for the remaining 300 assertions and
   208	     turned 14 of them red. */
   209	  window.__catSnapshot = null;
   210	  window.__allCatsOff = function () {
   211	    window.__catSnapshot = { ...catEnabled };
   212	    for (const t of Object.keys(catEnabled)) catEnabled[t] = false;
   213	    renderAll();
   214	    return Object.keys(catEnabled).filter(t => catEnabled[t] !== false);
   215	  };
   216	  window.__restoreCats = function () {
   217	    if (!window.__catSnapshot) return false;
   218	    for (const t of Object.keys(window.__catSnapshot)) catEnabled[t] = window.__catSnapshot[t];
   219	    window.__catSnapshot = null; renderAll(); return true;
   220	  };
   221	  window.__setMnConfirm = function (v) { jpSetMnConfirmed(v); };
   222	  window.__isCandidateExact = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value) === n); };
   223	  window.__isCandidateContains = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value).includes(n)); };
   224	  // default mode of the candidate whose value contains v (null if not a candidate)
   225	  window.__candidateMode = function (v) { const n = norm(v); const e = entities.find(x => x.kind === 'candidate' && norm(x.value).includes(n)); return e ? e.mode : null; };
   566	async function checkJpDoc(page, spec) {
   567	  const fx = JSON.parse(fs.readFileSync(path.join(__dirname, spec.fixture), 'utf8'));
   568	  const autoFields = (SPECS.jp_auto_fields || {})[spec.expect_doc] || [];
   569	  const mocFields = SPECS.jp_candidate_or_mask || [];
   570	  for (const c of spec.cases) {
   571	    const tag = `${spec.doc} [${c.purpose}${c.label ? ' ' + c.label : ''}]`;
   572	    await loadDoc(page, spec.doc, true);
   573	    await page.evaluate(p => jpSetPurpose(p), c.purpose);
   574	    // Releasing a 個人番号 band needs the purpose AND the confirmation. A case
   575	    // that expects the release has to say so — which is itself the assertion
   576	    // that the dropdown alone does not open the gate (the `confirm_mynumber:
   577	    // false` case below proves the other direction).
   578	    if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
   579	    const st = await page.evaluate(() => window.__jpState());
   580	    if (c.expect_warn != null)
   581	      rec(tag, 'JP_WARN', 'blocking banner', c.expect_warn ? 'shown' : 'absent',
   582	        st.warnShown ? 'shown(' + st.warn + ')' : 'absent', st.warnShown === !!c.expect_warn);
   583	    if (c.confirm_mynumber != null)
   584	      rec(tag, 'JP_MN_BOX', 'confirmation checkbox', 'shown', st.mnBoxShown ? 'shown' : 'ABSENT', st.mnBoxShown);
   585	    rec(tag, 'JP_CLASS', spec.expect_doc + (spec.expect_side ? '/' + spec.expect_side : ''), 'classified',
   586	      st.cls ? st.cls.doc + (st.cls.side ? '/' + st.cls.side : '') + ' sc=' + st.cls.score : 'NOT classified',
   587	      !!st.cls && st.cls.doc === spec.expect_doc && (!spec.expect_side || st.cls.side === spec.expect_side));
   588	    if (!st.cls) continue;
   589	    const autoCount = await page.evaluate(() => entities.filter(e => e.kind === 'auto').length);
   590	    process.stderr.write(`    [jp autoCount] ${tag} = ${autoCount}\n`);
   591	    if (c.min_auto != null) rec(tag, 'REGRESSION', `auto>=${c.min_auto}`, `>=${c.min_auto}`, String(autoCount), autoCount >= c.min_auto);
   592	    if (c.max_auto != null) rec(tag, 'REGRESSION', `auto<=${c.max_auto}`, `<=${c.max_auto}`, String(autoCount), autoCount <= c.max_auto);
   593	
   594	    // Field-level: every required field must have been FOUND. This is the only
   595	    // assertion a rotated phone-photo fixture can make, and it is also the one
   596	    // the 미탐 0 gate is actually about.
   597	    const got = new Set(st.fields.map(f => f.field));
   598	    for (const f of (c.require_fields || [])) rec(tag, 'JP_FIELD', f, 'detected', got.has(f) ? 'detected' : 'MISSING', got.has(f));
   599	    // A band is only a band if the entity is located, its category is ON, its
   600	    // mode is not 'ok', AND the rect it paints is in the active mask-rect list.
   601	    for (const f of (c.require_banded || [])) {
   602	      const bs = await page.evaluate(x => window.__fieldBands(x), f);
   603	      const ok = bs.length > 0 && bs.every(b => b.located && b.on && b.mode !== 'ok' && b.inMask);
   604	      const why = !bs.length ? 'MISSING'
   605	        : bs.every(b => b.located && b.on && b.mode !== 'ok' && b.inMask) ? `banded ×${bs.length}`
   606	        : bs.map(b => !b.located ? 'NOT LOCATED' : !b.on ? 'CATEGORY OFF' : b.mode === 'ok' ? 'CLEAR' : 'NOT IN MASKRECTS').join('/');
   607	      rec(tag, 'JP_BANDED', f, 'located+on+in-maskrects', why, ok);
   608	    }
   609	    // The inverse of require_banded, and the half that makes a purpose-gate test
   610	    // mean something: without it, "banded under 相談用共有" could be true simply
   611	    // because the field is banded under every purpose. Also asserts the rect is
   612	    // absent from the mask list, not merely that the mode string says 'ok'.
   613	    for (const f of (c.require_clear || [])) {
   614	      const bs = await page.evaluate(x => window.__fieldBands(x), f);
   615	      const clear = bs.length > 0 && bs.every(b => b.mode === 'ok' && !b.inMask);
   616	      rec(tag, 'JP_CLEAR', f, 'detected+clear', !bs.length ? 'MISSING' : (clear ? `detected+clear ×${bs.length}` : 'BANDED'), clear);
   617	    }
   618	    // Legal-preset fields are not governed by the category checkboxes. Turn
   619	    // every category off and require the band to still be there.
   620	    for (const f of (c.require_legal || [])) {
   621	      const left = await page.evaluate(() => window.__allCatsOff());
   622	      const bs = await page.evaluate(x => window.__fieldBands(x), f);
   623	      const ok = left.length === 0 && bs.length > 0 && bs.every(b => b.legal && b.on && b.mode !== 'ok' && b.inMask);
   624	      rec(tag, 'JP_LEGAL', f, 'survives all-categories-off',
   625	        left.length ? 'cats still on: ' + left.join(',') : !bs.length ? 'MISSING'
   626	          : bs.every(b => b.legal && b.on && b.mode !== 'ok' && b.inMask) ? `banded ×${bs.length}` : 'DROPPED', ok);
   627	      // put the page back the way the rest of the case expects it
   628	      const restored = await page.evaluate(() => window.__restoreCats());
   629	      rec(tag, 'JP_LEGAL', f + ' (categories restored)', 'restored', restored ? 'restored' : 'NOT RESTORED', restored, true);
   630	      await loadDoc(page, spec.doc, true);
   631	      await page.evaluate(p => jpSetPurpose(p), c.purpose);
   632	      if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
   633	    }
   634	    // No auto entity outside the allowlist. A ceiling on the COUNT cannot tell
   635	    // "the right five" from "two right and three wrong" (Codex 5-6).
   636	    if (c.auto_allow) {
   637	      const af = await page.evaluate(() => window.__autoFields());
   638	      const bad = af.filter(f => !c.auto_allow.includes(f));
   639	      rec(tag, 'JP_AUTO_SET', 'auto fields ⊆ allowlist', c.auto_allow.join(',') || '(none)',
   640	        bad.length ? 'UNEXPECTED: ' + [...new Set(bad)].join(',') : (af.length ? [...new Set(af)].join(',') : '(none)'), bad.length === 0);
   641	    }
   642	    if (spec.geometry === false || c.geometry === false) continue;
   643	
   644	    const P = fx.purposes[c.key];
   645	    if (!P) { rec(tag, 'JP_SPEC', c.key, 'purpose in fixture', 'MISSING', false); continue; }
   646	    const scale = st.pw[0] / fx.size[0];
   647	    let checked = 0;
   648	    const box = k => { const b = fx.boxes_png[k]; return b && { pi: 0, x: b[0] * scale, y: b[1] * scale, w: (b[2] - b[0]) * scale, h: (b[3] - b[1]) * scale }; };
   649	    const seen = new Set();
   650	    const run = async (keys, kindFor) => {
   651	      for (const k of (keys || [])) {
   652	        if (k === 'ALL' || seen.has(k)) continue;
   653	        const r = box(k);
   654	        // An expectation naming a box this variant does not have is a FAULT in
   655	        // the expectation table, not a case to skip. It used to be "reported as
   656	        // skipped", which is a line of text nobody reads next to a green total
   657	        // (Codex 5-5). The variant tables are pruned at generation time now, so
   658	        // a missing key means the table and the fixture went out of sync.
   659	        if (!r) { rec(tag, 'JP_SPEC', k, 'box exists in fixture', 'NO SUCH BOX', false); continue; }
   660	        seen.add(k);
   661	        await jpCheckBox(page, tag, null, k, r, kindFor(k));
   662	        checked++;
   663	      }
   664	    };
   665	    // whole-face rule (マイナカード裏面 under a 本人確認 purpose)
   666	    if ((P.mask || []).includes('ALL')) {
   667	      const pg = await page.evaluate(() => ({ pi: 0, x: 0, y: 0, w: pages[0].w, h: pages[0].h }));
   668	      await jpCheckBox(page, tag, null, 'ALL(face)', pg, 'mask');
   669	      checked++;
   670	      for (const k of Object.keys(fx.boxes_png)) { const r = box(k); if (r) { await jpCheckBox(page, tag, null, k, r, 'mask'); checked++; } }
   671	      seen.add('ALL');
   672	    }
   673	    await run(P.mask, k => mocFields.includes(jpFieldOf(k)) ? 'mask_or_candidate'
   674	                        : autoFields.includes(jpFieldOf(k)) ? 'mask' : 'candidate');
   675	    await run(P.recommend, () => 'candidate');
   676	    await run(P.optional, () => 'optional');
   677	    // `keep: "all"` means every box on the page is a keep field. Turning that
   678	    // into an empty list made the strongest promise in the table the only one
   679	    // nobody checked (Codex 5-5) — enumerate the box table instead.
   680	    await run(P.keep === 'all' ? Object.keys(fx.boxes_png) : P.keep, () => 'keep');
   681	    rec(tag, 'JP_COVERAGE', 'boxes checked', `>=${c.min_boxes || 1}`, String(checked), checked >= (c.min_boxes || 1));
   682	    for (const fmt of (c.out_formats || [])) await checkOutput(page, tag, fmt);
   683	  }
   684	}
   685	
   686	/* ── JP unit rules ──────────────────────────────────────────────────────────
   687	   Two detection rules cannot be exercised by the alpha fixtures: none of the
   688	   four documents carries a phone number, and on all four the 住所 is a KEEP
   689	   field, so the address hierarchy's own scoring never decides anything there.
   690	   Shipping them with no coverage at all would be shipping untested detection,
   691	   so they are pinned at unit level against crafted strings — stated as such
   692	   rather than left to look like fixture coverage. */
   693	async function checkJpUnits(page) {
   694	  const U = SPECS.jp_units; if (!U) return;
   695	  for (const c of (U.address || [])) {
   696	    const got = await page.evaluate(t => {
   697	      const sp = jpAddressSpan(t, 0);
   698	      return sp ? { span: t.slice(sp.a, sp.b), score: sp.score, strong: !!(sp.postal && sp.pref) } : null;
   699	    }, c.text);
   700	    const ok = c.expect === null ? (got === null || got.score < 3)
   718	function checkMatrix() {
   719	  const r = spawnSync(process.execPath, [path.join(__dirname, 'check_matrix.mjs')], { encoding: 'utf8' });
   720	  const out = ((r.stdout || '') + (r.stderr || '')).trim().split('\n').filter(Boolean);
   721	  rec('(legal matrix)', 'JP_MATRIX', 'JP_RULES == jp_legal_matrix_alpha4.json', 'identical',
   722	    r.status === 0 ? out[out.length - 1].replace(/^✅ legal matrix ↔ code: /, '') : `${out.length - 1} disagreement(s)`, r.status === 0);
   723	  if (r.status !== 0) for (const l of out.slice(1, 9)) rec('(legal matrix)', 'JP_MATRIX', l.trim().slice(0, 38), '-', 'mismatch', false, true);
   724	}
   725	
   726	/* ── multi-page: the rule follows the PAGE, not page 1 ──────────────────────
   727	   A two-sided card scanned into one PDF. The old code read page 1's class and
   728	   applied it to every page, so the outcome depended on scan order: front-then-
   729	   back left the 個人番号 page untouched, back-then-front put a full-face band
   730	   over the front as well (Codex 6-4). Both orders are built here from the
   731	   committed single-page PNGs — written under out/gen, not committed, so the
   732	   repo gains no new card binaries. */
   733	async function buildPdfFromImages(page, srcs, outPath) {
   734	  const b64 = await page.evaluate(async (urls) => {
   735	    const { jsPDF } = await ensureJsPDF();
   736	    let pdf = null;
   737	    for (const u of urls) {
   738	      const im = await new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = u; });
   739	      const cv = document.createElement('canvas'); cv.width = im.width; cv.height = im.height;
   740	      cv.getContext('2d').drawImage(im, 0, 0);
   741	      const data = cv.toDataURL('image/jpeg', 0.95);
   742	      if (!pdf) pdf = new jsPDF({ unit: 'pt', format: [im.width, im.height], compress: true });
   743	      else pdf.addPage([im.width, im.height]);
   744	      pdf.addImage(data, 'JPEG', 0, 0, im.width, im.height);
   745	    }
   746	    return pdf.output('datauristring').split(',')[1];
   747	  }, srcs);
   748	  fs.mkdirSync(path.dirname(outPath), { recursive: true });
   749	  fs.writeFileSync(outPath, Buffer.from(b64, 'base64'));
   750	}
   751	async function checkJpMultiPage(page, port) {
   752	  const B = `http://127.0.0.1:${port}/__fx/jp/mynumber_card`;
   753	  const cases = [
   754	    { label: '表→裏', srcs: [`${B}/front.png`, `${B}/back.png`], backPage: 1, frontPage: 0, file: 'gen/mn_front_back.pdf' },
   755	    { label: '裏→表', srcs: [`${B}/back.png`, `${B}/front.png`], backPage: 0, frontPage: 1, file: 'gen/mn_back_front.pdf' },
   756	  ];
   757	  for (const c of cases) {
   758	    const tag = `jp/2page ${c.label}`;
   759	    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
   760	    try {
   761	      await buildPdfFromImages(page, c.srcs, path.join(OUT, c.file));
   762	      await loadDoc(page, c.file, true);
   763	      await page.evaluate(() => jpSetPurpose('identity_submit'));
   764	      const st = await page.evaluate(() => window.__jpState());
   765	      const sides = st.pageCls.map(x => x ? (x.doc + '/' + (x.side || '-')) : 'null');
   766	      const wantSides = []; wantSides[c.backPage] = 'mynumber_card/back'; wantSides[c.frontPage] = 'mynumber_card/front';
   767	      rec(tag, 'JP_PAGECLASS', 'per-page doc/side', wantSides.join(' + '), sides.join(' + '),
   768	        sides.length === 2 && sides[c.backPage] === wantSides[c.backPage] && sides[c.frontPage] === wantSides[c.frontPage]);
   769	      // The whole-face band exists on the BACK page and only there.
   770	      const bs = await page.evaluate(() => window.__fieldBands('back_all'));
   771	      const pagesWithBand = bs.filter(b => b.mode !== 'ok' && b.inMask).map(b => b.page);
   772	      rec(tag, 'JP_BACK_ONLY', 'back_all pages', `[${c.backPage}]`, `[${pagesWithBand.join(',')}]`,
   773	        pagesWithBand.length === 1 && pagesWithBand[0] === c.backPage);
   774	      // And geometrically: the back page is covered, the front page is not.
   775	      const cov = await page.evaluate(() => pages.map((p, pi) => window.__coverage({ pi, x: 0, y: 0, w: p.w, h: p.h })));
   776	      rec(tag, 'JP_BACK_COVER', `page ${c.backPage} covered`, '>=99%', `${(cov[c.backPage] * 100).toFixed(0)}%`, cov[c.backPage] >= 0.99);
   777	      rec(tag, 'JP_FRONT_CLEAR', `page ${c.frontPage} not full-face`, '<=60%', `${(cov[c.frontPage] * 100).toFixed(0)}%`, cov[c.frontPage] <= 0.6);
   778	    } catch (e) { rec(tag, 'LOAD', c.file, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
   779	    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
   780	  }
   781	}
   782	
   783	/* ── 個人番号 check digit ───────────────────────────────────────────────────
   784	   Two layers. The vectors pin the arithmetic of 省令第5条 (including the two
   785	   remainder cases the 省令 folds to 0). The synthesis then drives a VALID
   786	   number through the real pipeline — classification, label anchor, digit span,
   787	   check digit, purpose gate — on a page built by the app's own text renderer.
   788	   The alpha card dummies all carry invalid numbers on purpose (strategy v2 §4
   789	   forbids generating a valid one into a card image), so until now nothing
   790	   exercised the `checkOk: true` branch at all (Codex 5-2): a correct number
   791	   would have taken a path the golden had never run. The valid numbers live in
   792	   TEXT only, never in a committed image. */
   793	async function checkJpMyNumber(page) {
   794	  const U = SPECS.jp_my_number; if (!U) return;
   795	  for (const c of (U.vectors || [])) {
   796	    const got = await page.evaluate(v => myNumberCheckOk(v), c.n);
   797	    rec('(jp units)', 'JP_MYNUM_CD', `${c.label} ${c.n}`, String(c.ok), String(got), got === c.ok);
   798	  }
   799	  for (const c of (U.synth || [])) {
   800	    const tag = '(jp synth)';
   801	    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
   802	    await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
   803	    await page.evaluate(t => loadFromText(t, 'synth.txt'), c.text);
   804	    await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0, { timeout: 40000 });
   805	    await page.evaluate(PAGE_HELPERS);
   806	    await page.evaluate(p => jpSetPurpose(p), c.purpose);
   807	    if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
   808	    const st = await page.evaluate(() => window.__jpState());
   809	    rec(tag, 'JP_CLASS', c.label, c.expect_doc, st.cls ? st.cls.doc : 'NOT classified', !!st.cls && st.cls.doc === c.expect_doc);
   810	    const bs = await page.evaluate(() => window.__fieldBands('my_number'));
   811	    const lv = bs.map(b => b.level + (b.note ? '/' + b.note : '')).join(',') || 'MISSING';
   812	    rec(tag, 'JP_MYNUM_LEVEL', c.label, c.expect_level, lv, bs.length > 0 && bs.every(b => b.level === c.expect_level));
   813	    // A valid number must NOT carry the check-digit demotion note.
   814	    rec(tag, 'JP_MYNUM_NOTE', c.label + ' note', c.expect_note || '(none)',
   815	      bs.length ? (bs[0].note || '(none)') : 'MISSING', bs.length > 0 && (bs[0].note || null) === (c.expect_note || null));
   816	    const banded = bs.length > 0 && bs.every(b => b.mode !== 'ok' && b.inMask);
   817	    rec(tag, 'JP_MYNUM_BAND', c.label + ' band', c.expect_banded ? 'banded' : 'clear',
   818	      banded ? 'banded' : 'clear', banded === !!c.expect_banded);
   819	    if (c.expect_banded) {
   820	      const masked = await page.evaluate(v => window.__isMasked(v), c.number);
   821	      rec(tag, 'JP_MYNUM_GEOM', c.label + ' value covered', 'masked', masked ? 'masked' : 'NOT masked', masked);
   822	    }
   823	    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
   824	  }
   825	}
   826	
   827	/* ── unlabelled square block: offered, never banded by default ──────────────
   828	   The pixel detector for an unlabelled block has no golden coverage (the alpha
   829	   dummies carry no real QR — strategy v2 §4), and it can fire on a face photo,
   830	   a round seal (bbox fill ≈ 0.785) or a black table header. So the POLICY is
   831	   what gets pinned here: a finding flagged `unlabelledCode` comes out of
   832	   jpApply as `optional` / mode 'ok' / not in the mask list, even on a document
   833	   whose labelled 二次元コード is an automatic band. The finding is injected —
   834	   this tests the decision, not the detector, and says so. */
   835	async function checkJpUnlabelled(page) {
   836	  const U = SPECS.jp_unlabelled_block; if (!U) return;
   837	  const tag = '(jp unlabelled)';
   838	  await page.evaluate(() => { LANG = 'ja'; applyLang(); });
   839	  await loadDoc(page, U._doc, true);
   840	  await page.evaluate(p => jpSetPurpose(p), U.purpose);
   841	  const res = await page.evaluate(() => {
   842	    // A square where nothing on the page is a code: top-left corner of the page.
   843	    const r = { page: 0, x: 40, y: 40, w: 120, h: 120, region: true };
   844	    jpState.findings.push({ field: 'qr', boxes: [r], value: '二次元コード', pi: 0,
   845	      doc: jpState.cls.doc, side: jpState.cls.side || null, low: false, unlabelledCode: true });
   846	    jpApply();
   847	    const inj = entities.find(e => e.jp && e.jp.note === 'unlabelled_code');
   848	    return { present: !!inj, level: inj && inj.jp.level, mode: inj && inj.mode, kind: inj && inj.kind,
   849	      covered: window.__coverage({ pi: 0, x: 40, y: 40, w: 120, h: 120 }),
   850	      labelledBanded: window.__fieldBands('qr').filter(b => b.note !== 'unlabelled_code').every(b => b.mode !== 'ok' && b.inMask) };
   851	  });
   852	  rec(tag, 'JP_UNLABELLED', 'level', 'optional', res.present ? res.level : 'MISSING', res.level === 'optional');
   853	  rec(tag, 'JP_UNLABELLED', 'default mode', 'ok', res.present ? res.mode : 'MISSING', res.mode === 'ok');
   854	  rec(tag, 'JP_UNLABELLED', 'not in default output', '0% covered', `${(res.covered * 100).toFixed(0)}%`, res.covered <= 0.10);
   855	  // …and the LABELLED code on the same page is still banded, so the assertion
   856	  // above is not passing merely because nothing is banded at all.
   857	  rec(tag, 'JP_UNLABELLED', 'labelled code still banded', 'banded', res.labelledBanded ? 'banded' : 'CLEAR', res.labelledBanded);
   858	  await page.evaluate(() => { LANG = 'ko'; applyLang(); });
   859	}
   860	
   861	/* ── classification failure must be visible ─────────────────────────────────
   862	   A page that says 資格確認書 and nothing else reaches 3 of the 4 points it
   863	   needs. The old build dropped the entire Japanese preset and fell through to
   864	   the Latin name/address heuristics without a word (Codex 1-1). */
   865	async function checkJpWarn(page) {
   866	  const W = SPECS.jp_warn; if (!W) return;
   867	  for (const c of W.cases) {
   868	    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
   869	    await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
   870	    await page.evaluate(t => loadFromText(t, 'warn.txt'), c.text);
   871	    await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0, { timeout: 40000 });
   872	    await page.evaluate(PAGE_HELPERS);
   873	    const st = await page.evaluate(() => window.__jpState());
   874	    rec('(jp warn)', 'JP_WARN', c.label, c.expect_warn ? `shown/${c.expect_warn}` : 'absent',
   875	      st.warnShown ? `shown/${st.warn}` : 'absent',
   876	      st.warnShown === !!c.expect_warn && (!c.expect_warn || st.warn === c.expect_warn));
   877	    rec('(jp warn)', 'JP_WARN_CLASS', c.label + ' class', c.expect_doc || 'null',
   878	      st.cls ? st.cls.doc + (st.cls.low ? '(low)' : '') : 'null',
   879	      (st.cls ? st.cls.doc : null) === (c.expect_doc || null) && (!c.expect_doc || !!st.cls.low === !!c.expect_low));
   880	    // A low-confidence class may not produce an automatic band.
   881	    if (c.expect_low) {
   882	      const af = await page.evaluate(() => window.__autoFields());
   883	      const jpAuto = af.filter(f => !f.startsWith('(regex:'));
   884	      rec('(jp warn)', 'JP_WARN_NOAUTO', c.label + ' no jp auto', '(none)',
   885	        jpAuto.length ? jpAuto.join(',') : '(none)', jpAuto.length === 0);
   886	    }
   887	    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
   888	  }
   889	}
   890	
   891	function printTable() {
   892	  const pad = (s, n) => { s = String(s); return s.length > n ? s.slice(0, n - 1) + '…' : s.padEnd(n); };
   893	  let lastDoc = '';
   894	  console.log('\n' + '═'.repeat(120));
   895	  console.log(pad('DOC', 20) + pad('CATEGORY', 17) + pad('ITEM', 40) + pad('EXPECTED', 18) + pad('ACTUAL', 18) + 'RESULT');

hook: PostToolUse
hook: PostToolUse Completed
codex
현재까지 구현자 주장과 달리 즉시 확인되는 핵심 경로가 있습니다. 저신뢰 분류는 “자동 마스킹 미적용” 경고를 띄우면서도 `recommend`를 기본 ON으로 만들어 실제 출력에는 띠가 들어가며, 다중 페이지는 분류 불가 첨부에 1페이지 카드 분류를 그대로 상속합니다. 이제 대조기 실행 결과와 하네스의 상태 오염·동어반복 여부를 확인하겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'node test/safe/check_matrix.mjs' in /Users/sunghoon/Projects/docpack
 succeeded in 35ms:
✅ legal matrix ↔ code: 188 (doc, field, purpose) triples identical, verified:false⇒no-auto holds

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "test -d test/safe/node_modules && echo installed || echo not-installed
nl -ba test/safe/run.mjs | sed -n '115,225p;245,275p;560,645p'
nl -ba public/safe/index.html | sed -n '1970,2025p;2568,2635p'
git diff HEAD"'^ HEAD -- public/safe/index.html test/safe/run.mjs test/safe/fixtures/jp/gen.py test/safe/fixtures/jp/jp_legal_matrix_alpha4.json | sed -n '"'1,1200p'" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
installed
   115	  // any ACTIVE candidate entity overlapping `rect` (did the field surface for review?)
   116	  window.__candidateOver = function (rect) {
   117	    for (const e of entities) {
   118	      if (e.kind !== 'candidate' || !e.boxes) continue;
   119	      for (const b of e.boxes) {
   120	        if (b.page !== rect.pi) continue;
   121	        if (!(b.x + b.w < rect.x || rect.x + rect.w < b.x || b.y + b.h < rect.y || rect.y + rect.h < b.y)) return true;
   122	      }
   123	    }
   124	    return false;
   125	  };
   126	  /* ── ink coverage (replaces the 60% area gate on number fields) ──
   127	     A 60% area figure says HOW MUCH of a box was painted, never WHERE: the
   128	     kouki fixture measured 96% with its leading digit fully outside the band
   129	     (Codex 5-3, and we had already recorded it). So for a field whose value is
   130	     a number, the question is per-GLYPH: take the ink inside the expected box,
   131	     label its connected components, and require every component to be covered.
   132	     Threshold 60 (not the detector's 40) deliberately excludes the fixtures'
   133	     見本 watermark — composited it sits ~48 off the background, and a band is
   134	     not required to cover a watermark. */
   135	  window.__inkCover = function (rect) {
   136	    const p = pages[rect.pi]; if (!p) return null;
   137	    const CW = p.canvas.width, CH = p.canvas.height;
   138	    const x0 = Math.max(0, Math.floor(rect.x)), y0 = Math.max(0, Math.floor(rect.y));
   139	    const x1 = Math.min(CW, Math.ceil(rect.x + rect.w)), y1 = Math.min(CH, Math.ceil(rect.y + rect.h));
   140	    const W = x1 - x0, H = y1 - y0;
   141	    if (W <= 0 || H <= 0) return { components: 0, inkPx: 0, uncovered: 0, worst: 1 };
   142	    const ctx = p.canvas.getContext('2d', { willReadFrequently: true });
   143	    const d = ctx.getImageData(x0, y0, W, H).data, bg = jpPageBg(p);
   144	    const ink = new Uint8Array(W * H);
   145	    let inkPx = 0;
   146	    for (let i = 0; i < W * H; i++) {
   147	      if (Math.abs(d[i * 4] - bg[0]) > 60 || Math.abs(d[i * 4 + 1] - bg[1]) > 60 || Math.abs(d[i * 4 + 2] - bg[2]) > 60) { ink[i] = 1; inkPx++; }
   148	    }
   149	    const mr = window.__maskRects().filter(r => r.pi === rect.pi);
   150	    const covered = (px, py) => mr.some(r => px >= r.x && px <= r.x + r.w && py >= r.y && py <= r.y + r.h);
   151	    const seen = new Uint8Array(W * H);
   152	    let components = 0, uncovered = 0, worst = 1;
   153	    for (let i = 0; i < W * H; i++) {
   154	      if (!ink[i] || seen[i]) continue;
   155	      const st = [i]; seen[i] = 1; let n = 0, cov = 0;
   156	      while (st.length) {
   157	        const k = st.pop(), kx = k % W, ky = (k - kx) / W;
   158	        n++; if (covered(x0 + kx + 0.5, y0 + ky + 0.5)) cov++;
   159	        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
   160	          const nx = kx + dx, ny = ky + dy;
   161	          if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
   162	          const nk = ny * W + nx;
   163	          if (ink[nk] && !seen[nk]) { seen[nk] = 1; st.push(nk); }
   164	        }
   165	      }
   166	      // Specks (anti-aliasing debris, watermark bleed) are not glyphs.
   167	      if (n < 6) continue;
   168	      components++;
   169	      const f = cov / n;
   170	      if (f < worst) worst = f;
   171	      if (f < 0.99) uncovered++;
   172	    }
   173	    return { components, inkPx, uncovered, worst };
   174	  };
   175	  /* Every entity carrying `field`, with the facts require_banded is actually
   176	     about: is it located, is its category ON, is it not 'ok', and do the rects
   177	     it would paint ACTUALLY appear in the active mask-rect list? The old
   178	     assertion read `mode !== 'ok'` alone, which stays true for an entity whose
   179	     category is off or whose boxes are empty (Codex 5-5). */
   180	  window.__fieldBands = function (field) {
   181	    const mr = window.__maskRects();
   182	    const same = (a, b) => Math.abs(a.x - b.x) < 0.01 && Math.abs(a.y - b.y) < 0.01 && Math.abs(a.w - b.w) < 0.01 && Math.abs(a.h - b.h) < 0.01;
   183	    return entities.filter(e => e.jp && e.jp.field === field).map(e => {
   184	      const rects = [];
   185	      for (let pi = 0; pi < pages.length; pi++) for (const l of mergeLineBoxes(e.boxes || [], pi)) { const r = bandRect(l); rects.push({ pi, ...r }); }
   186	      return { level: e.jp.level, note: e.jp.note, page: e.jp.page, doc: e.jp.doc, side: e.jp.side,
   187	        kind: e.kind, mode: e.mode, legal: !!e.legal, located: !!(e.boxes && e.boxes.length), on: isOn(e),
   188	        rects: rects.length, inMask: rects.length > 0 && rects.every(r => mr.some(m => m.pi === r.pi && same(m, r))) };
   189	    });
   190	  };
   191	  window.__jpState = function () {
   192	    return { cls: jpState.cls && { doc: jpState.cls.doc, side: jpState.cls.side || null, score: jpState.cls.score, low: !!jpState.cls.low },
   193	      purpose: jpState.purpose, warn: jpState.warn, mnConfirmed: jpState.mnConfirmed,
   194	      pageCls: jpState.pageCls.map(c => c && { doc: c.doc, side: c.side || null, low: !!c.low }),
   195	      warnShown: (() => { const el = document.getElementById('jpWarn'); return !!el && el.style.display !== 'none' && !!el.textContent.trim(); })(),
   196	      mnBoxShown: (() => { const el = document.getElementById('jpMnWrap'); return !!el && el.style.display !== 'none'; })(),
   197	      pw: pages.map(p => p.w),
   198	      fields: entities.filter(e => e.jp).map(e => ({ field: e.jp.field, level: e.jp.level, note: e.jp.note, page: e.jp.page, kind: e.kind, mode: e.mode, legal: !!e.legal, on: isOn(e) })) };
   199	  };
   200	  // Field labels of every ACTIVE auto entity — the allowlist assertion's input.
   201	  window.__autoFields = function () {
   202	    return entities.filter(e => e.kind === 'auto').map(e => e.jp ? e.jp.field : '(regex:' + e.type + ')');
   203	  };
   204	  /* Turn every general category OFF. A legal-preset band must survive this.
   205	     catEnabled is module-level state that resetAll() and a fresh file load do
   206	     NOT restore, so this hands back a restore function — the first version of
   207	     this helper left every category off for the remaining 300 assertions and
   208	     turned 14 of them red. */
   209	  window.__catSnapshot = null;
   210	  window.__allCatsOff = function () {
   211	    window.__catSnapshot = { ...catEnabled };
   212	    for (const t of Object.keys(catEnabled)) catEnabled[t] = false;
   213	    renderAll();
   214	    return Object.keys(catEnabled).filter(t => catEnabled[t] !== false);
   215	  };
   216	  window.__restoreCats = function () {
   217	    if (!window.__catSnapshot) return false;
   218	    for (const t of Object.keys(window.__catSnapshot)) catEnabled[t] = window.__catSnapshot[t];
   219	    window.__catSnapshot = null; renderAll(); return true;
   220	  };
   221	  window.__setMnConfirm = function (v) { jpSetMnConfirmed(v); };
   222	  window.__isCandidateExact = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value) === n); };
   223	  window.__isCandidateContains = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value).includes(n)); };
   224	  // default mode of the candidate whose value contains v (null if not a candidate)
   225	  window.__candidateMode = function (v) { const n = norm(v); const e = entities.find(x => x.kind === 'candidate' && norm(x.value).includes(n)); return e ? e.mode : null; };
   245	  };
   246	};
   247	
   248	// `jp/...` paths resolve under fixtures/, `gen/...` under out/gen (built at run
   249	// time from committed fixtures — no new binaries in the repo), everything else
   250	// under testdocs/.
   251	const docPath = file => file.startsWith('jp/') ? path.join(FIXTURES, file)
   252	  : file.startsWith('gen/') ? path.join(OUT, file) : path.join(DOCS, file);
   253	async function loadDoc(page, file, ocr) {
   254	  await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
   255	  await page.setInputFiles('#fileInput', docPath(file));
   256	  // `pages.length > 0` is NOT "loaded": pages are pushed one at a time, so on a
   257	  // multi-page OCR document it goes true while page 2 is still in Tesseract —
   258	  // and everything measured after it describes half a document. afterLoad()
   259	  // reveals #docWrap as its last step, so that is the completion signal.
   260	  await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0
   261	      && document.getElementById('docWrap').style.display === 'flex',
   262	    { timeout: ocr ? 300000 : 40000 });
   263	  await page.waitForTimeout(ocr ? 800 : 400);
   264	  await page.evaluate(PAGE_HELPERS);
   265	}
   266	
   267	const rows = [];
   268	const rec = (doc, cat, item, expected, actual, pass, info = false) => rows.push({ doc, cat, item, expected, actual, pass, info });
   269	
   270	async function checkDoc(page, spec) {
   271	  const { doc, ocr } = spec;
   272	  await loadDoc(page, doc, ocr);
   273	  const snap = await page.evaluate(() => window.__entitySnapshot());
   274	  const autoCount = snap.filter(e => e.kind === 'auto').length;
   275	  process.stderr.write(`    [autoCount] ${doc} = ${autoCount}\n`);
   560	    rec(doc, 'JP_MASK_OR_CAND', key, 'banded(+covered) or candidate', covered ? 'banded ' + how : cand ? 'candidate' : 'NEITHER ' + how, covered || cand); return;
   561	  }
   562	  if (kind === 'optional') {   // detected, offered, and OFF until the user says so
   563	    rec(doc, 'JP_OPTIONAL', key, 'offered+clear', cand ? (frac <= JP_KEEP_MAX ? 'offered+clear' : 'OFFERED BUT BANDED') : 'MISSING', cand && frac <= JP_KEEP_MAX);
   564	  }
   565	}
   566	async function checkJpDoc(page, spec) {
   567	  const fx = JSON.parse(fs.readFileSync(path.join(__dirname, spec.fixture), 'utf8'));
   568	  const autoFields = (SPECS.jp_auto_fields || {})[spec.expect_doc] || [];
   569	  const mocFields = SPECS.jp_candidate_or_mask || [];
   570	  for (const c of spec.cases) {
   571	    const tag = `${spec.doc} [${c.purpose}${c.label ? ' ' + c.label : ''}]`;
   572	    await loadDoc(page, spec.doc, true);
   573	    await page.evaluate(p => jpSetPurpose(p), c.purpose);
   574	    // Releasing a 個人番号 band needs the purpose AND the confirmation. A case
   575	    // that expects the release has to say so — which is itself the assertion
   576	    // that the dropdown alone does not open the gate (the `confirm_mynumber:
   577	    // false` case below proves the other direction).
   578	    if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
   579	    const st = await page.evaluate(() => window.__jpState());
   580	    if (c.expect_warn != null)
   581	      rec(tag, 'JP_WARN', 'blocking banner', c.expect_warn ? 'shown' : 'absent',
   582	        st.warnShown ? 'shown(' + st.warn + ')' : 'absent', st.warnShown === !!c.expect_warn);
   583	    if (c.confirm_mynumber != null)
   584	      rec(tag, 'JP_MN_BOX', 'confirmation checkbox', 'shown', st.mnBoxShown ? 'shown' : 'ABSENT', st.mnBoxShown);
   585	    rec(tag, 'JP_CLASS', spec.expect_doc + (spec.expect_side ? '/' + spec.expect_side : ''), 'classified',
   586	      st.cls ? st.cls.doc + (st.cls.side ? '/' + st.cls.side : '') + ' sc=' + st.cls.score : 'NOT classified',
   587	      !!st.cls && st.cls.doc === spec.expect_doc && (!spec.expect_side || st.cls.side === spec.expect_side));
   588	    if (!st.cls) continue;
   589	    const autoCount = await page.evaluate(() => entities.filter(e => e.kind === 'auto').length);
   590	    process.stderr.write(`    [jp autoCount] ${tag} = ${autoCount}\n`);
   591	    if (c.min_auto != null) rec(tag, 'REGRESSION', `auto>=${c.min_auto}`, `>=${c.min_auto}`, String(autoCount), autoCount >= c.min_auto);
   592	    if (c.max_auto != null) rec(tag, 'REGRESSION', `auto<=${c.max_auto}`, `<=${c.max_auto}`, String(autoCount), autoCount <= c.max_auto);
   593	
   594	    // Field-level: every required field must have been FOUND. This is the only
   595	    // assertion a rotated phone-photo fixture can make, and it is also the one
   596	    // the 미탐 0 gate is actually about.
   597	    const got = new Set(st.fields.map(f => f.field));
   598	    for (const f of (c.require_fields || [])) rec(tag, 'JP_FIELD', f, 'detected', got.has(f) ? 'detected' : 'MISSING', got.has(f));
   599	    // A band is only a band if the entity is located, its category is ON, its
   600	    // mode is not 'ok', AND the rect it paints is in the active mask-rect list.
   601	    for (const f of (c.require_banded || [])) {
   602	      const bs = await page.evaluate(x => window.__fieldBands(x), f);
   603	      const ok = bs.length > 0 && bs.every(b => b.located && b.on && b.mode !== 'ok' && b.inMask);
   604	      const why = !bs.length ? 'MISSING'
   605	        : bs.every(b => b.located && b.on && b.mode !== 'ok' && b.inMask) ? `banded ×${bs.length}`
   606	        : bs.map(b => !b.located ? 'NOT LOCATED' : !b.on ? 'CATEGORY OFF' : b.mode === 'ok' ? 'CLEAR' : 'NOT IN MASKRECTS').join('/');
   607	      rec(tag, 'JP_BANDED', f, 'located+on+in-maskrects', why, ok);
   608	    }
   609	    // The inverse of require_banded, and the half that makes a purpose-gate test
   610	    // mean something: without it, "banded under 相談用共有" could be true simply
   611	    // because the field is banded under every purpose. Also asserts the rect is
   612	    // absent from the mask list, not merely that the mode string says 'ok'.
   613	    for (const f of (c.require_clear || [])) {
   614	      const bs = await page.evaluate(x => window.__fieldBands(x), f);
   615	      const clear = bs.length > 0 && bs.every(b => b.mode === 'ok' && !b.inMask);
   616	      rec(tag, 'JP_CLEAR', f, 'detected+clear', !bs.length ? 'MISSING' : (clear ? `detected+clear ×${bs.length}` : 'BANDED'), clear);
   617	    }
   618	    // Legal-preset fields are not governed by the category checkboxes. Turn
   619	    // every category off and require the band to still be there.
   620	    for (const f of (c.require_legal || [])) {
   621	      const left = await page.evaluate(() => window.__allCatsOff());
   622	      const bs = await page.evaluate(x => window.__fieldBands(x), f);
   623	      const ok = left.length === 0 && bs.length > 0 && bs.every(b => b.legal && b.on && b.mode !== 'ok' && b.inMask);
   624	      rec(tag, 'JP_LEGAL', f, 'survives all-categories-off',
   625	        left.length ? 'cats still on: ' + left.join(',') : !bs.length ? 'MISSING'
   626	          : bs.every(b => b.legal && b.on && b.mode !== 'ok' && b.inMask) ? `banded ×${bs.length}` : 'DROPPED', ok);
   627	      // put the page back the way the rest of the case expects it
   628	      const restored = await page.evaluate(() => window.__restoreCats());
   629	      rec(tag, 'JP_LEGAL', f + ' (categories restored)', 'restored', restored ? 'restored' : 'NOT RESTORED', restored, true);
   630	      await loadDoc(page, spec.doc, true);
   631	      await page.evaluate(p => jpSetPurpose(p), c.purpose);
   632	      if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
   633	    }
   634	    // No auto entity outside the allowlist. A ceiling on the COUNT cannot tell
   635	    // "the right five" from "two right and three wrong" (Codex 5-6).
   636	    if (c.auto_allow) {
   637	      const af = await page.evaluate(() => window.__autoFields());
   638	      const bad = af.filter(f => !c.auto_allow.includes(f));
   639	      rec(tag, 'JP_AUTO_SET', 'auto fields ⊆ allowlist', c.auto_allow.join(',') || '(none)',
   640	        bad.length ? 'UNEXPECTED: ' + [...new Set(bad)].join(',') : (af.length ? [...new Set(af)].join(',') : '(none)'), bad.length === 0);
   641	    }
   642	    if (spec.geometry === false || c.geometry === false) continue;
   643	
   644	    const P = fx.purposes[c.key];
   645	    if (!P) { rec(tag, 'JP_SPEC', c.key, 'purpose in fixture', 'MISSING', false); continue; }
  1970	  jpApply();
  1971	}
  1972	function jpSetMnConfirmed(v){ jpState.mnConfirmed = !!v; jpApply(); }
  1973	function jpRenderBar(){
  1974	  const bar = $('jpBar'), warn = $('jpWarn'); if (!bar) return;
  1975	  const cls = jpState.cls;
  1976	  // The blocking warning is independent of the bar: its whole point is to be
  1977	  // visible in the case where there is no classification and therefore no bar.
  1978	  if (warn){
  1979	    const show = !!jpState.warn;
  1980	    warn.textContent = show ? T().jpUnclassifiedWarn : '';
  1981	    warn.style.display = show ? 'block' : 'none';
  1982	  }
  1983	  if (!cls){ bar.style.display = 'none'; return; }
  1984	  bar.style.display = 'flex';
  1985	  $('jpDocName').textContent = jpFieldLabel('doc_' + cls.doc) + (cls.side ? ' · ' + jpFieldLabel('side_' + cls.side) : '');
  1986	  const sel = $('jpPurpose');
  1987	  sel.innerHTML = JP_PURPOSES.map(p => `<option value="${p}">${escapeHtml(jpFieldLabel('purpose_' + p))}</option>`).join('');
  1988	  sel.value = jpState.purpose;
  1989	  const note = $('jpNote');
  1990	  // The notice is shown whenever this document HAS a 個人番号 rule — including
  1991	  // after the user switched to 個人番号手続, where it is the text that explains
  1992	  // what the confirmation below it means.
  1993	  const hasMn = jpState.findings.some(f => f.field === 'my_number')
  1994	    || jpState.pageCls.some(c => c && c.doc === 'mynumber_card' && c.side === 'back');
  1995	  note.textContent = hasMn ? T().jpBackNotice : '';
  1996	  note.style.display = hasMn ? 'block' : 'none';
  1997	  const cw = $('jpMnWrap'), cb = $('jpMnConfirm');
  1998	  if (cw && cb){
  1999	    const need = hasMn && jpState.purpose === 'my_number_procedure';
  2000	    cw.style.display = need ? 'flex' : 'none';
  2001	    cb.checked = !!jpState.mnConfirmed;
  2002	    const lb = $('jpMnLabel'); if (lb) lb.textContent = T().jpMnConfirm;
  2003	  }
  2004	}
  2005	
  2006	/* ───────── text masking (list display + "copy text") ─────────
  2007	   Band-only: there are exactly two states. 'ok' shows the value; anything else
  2008	   shows a block run of the same rough length. No partial reveal exists, so the
  2009	   list cannot promise a weaker masking than the rendered page delivers. */
  2010	const maskBlockText=v=>'■'.repeat(Math.min(Math.max(Math.round(v.replace(/\s/g,'').length*0.8),3),12));
  2011	// live value shown next to the toggle
  2012	function displayValue(e){ return e.mode==='ok' ? e.value : maskBlockText(e.value); }
  2013	
  2014	/* ───────── coordinate index & box matching ───────── */
  2015	function buildIndex(page){
  2016	  if(page._idx) return;
  2017	  let s='', map=[];
  2018	  page.items.forEach((it,i)=>{ const str=it.str||''; for(let c=0;c<str.length;c++){ s+=str[c]; map.push([i,c]); } s+=' '; map.push(null); });
  2019	  page._text=s; page._map=map;
  2020	  // spaceless index (fallback for values whose spacing differs from source)
  2021	  let ss='', smap=[];
  2022	  page.items.forEach((it,i)=>{ const str=it.str||''; for(let c=0;c<str.length;c++){ const ch=str[c]; if(/\s/.test(ch))continue; ss+=ch; smap.push([i,c]); } });
  2023	  page._stext=ss; page._smap=smap;
  2024	  page._idx=true;
  2025	}
  2568	        <div class="seg" role="radiogroup">
  2569	          <button class="${e.mode==='ok'?'on-ok':''}" data-id="${e.id}" data-mode="ok">${t.segOk}</button>
  2570	          <button class="${e.mode==='no'?'on-no':''}" data-id="${e.id}" data-mode="no">${t.segNo}</button>
  2571	        </div>
  2572	      </div>`).join('')}</div>`:''}
  2573	  </div>`;
  2574	}
  2575	// Flat item box for manual selections / name candidates (not category-grouped).
  2576	function sectionHtml(kind,title,items){
  2577	  const t=T(), cand=kind==='candidate';
  2578	  const icon=kind==='candidate'?'❓':kind==='keep'?'🛡':kind==='legal'?'⚖️':'✏️';
  2579	  return `
  2580	  <div class="cat-row sec-${kind}">
  2581	    <div class="cat-head">
  2582	      <span class="cl">${icon} ${title}</span>
  2583	      <span class="cnt hit">${t.cnt(items.length)}</span>
  2584	    </div>
  2585	    <div class="cat-items">${items.map(e=>`
  2586	      <div class="pii-item${cand?' is-cand':''}">
  2587	        <div class="val-wrap">
  2588	          <span class="val ${cand?'':'mono'}" title="${escapeHtml(e.value)}">${escapeHtml(kind==='manual'? t.manualItem : displayValue(e))}</span>
  2589	          ${(cand||kind==='keep'||kind==='legal')?`<span class="reason">${(TYPES[e.type]||{}).icon||''} ${t.reasons[e.reason]||(e.jp?t.reasons.jp_keep:t.reasons.name)}</span>`:''}
  2590	        </div>
  2591	        <div class="seg" role="radiogroup">
  2592	          <button class="${e.mode==='ok'?'on-ok':''}" data-id="${e.id}" data-mode="ok">${t.segOk}</button>
  2593	          <button class="${e.mode==='no'?'on-no':''}" data-id="${e.id}" data-mode="no">${t.segNo}</button>
  2594	        </div>
  2595	        ${kind==='manual'?`<button class="del" data-del="${e.id}" title="remove" aria-label="remove">✕</button>`:''}
  2596	      </div>`).join('')}</div>
  2597	  </div>`;
  2598	}
  2599	function renderList(){
  2600	  const list=$('piiList'), t=T();
  2601	  // Legal-preset bands come out of the category grouping entirely — they are not
  2602	  // a "type" the user turns off, they are a rule with a citation.
  2603	  const legalE=entities.filter(e=>e.legal);
  2604	  const autoE=entities.filter(e=>!e.legal&&e.kind!=='candidate'&&e.kind!=='manual'&&e.kind!=='keep');
  2605	  const manualE=entities.filter(e=>!e.legal&&e.kind==='manual');
  2606	  const candE=entities.filter(e=>!e.legal&&e.kind==='candidate');
  2607	  const keepE=entities.filter(e=>!e.legal&&e.kind==='keep');
  2608	  const total=entities.filter(isOn).length;
  2609	  $('piiCount').textContent= total? t.cntUse(total):'';
  2610	  document.querySelectorAll('#bulkBtns button').forEach(b=>b.disabled=!total);
  2611	  $('catHint').textContent = pages.length? t.hintAfter : t.hintBefore;
  2612	  const groups={};
  2613	  for(const e of autoE){(groups[e.type]=groups[e.type]||[]).push(e);}
  2614	  const all=Object.keys(TYPES).filter(ty=>ty!=='manual');
  2615	  if(!pages.length){
  2616	    list.innerHTML = all.map(ty=>catRowHtml(ty,[])).join('');
  2617	    return;
  2618	  }
  2619	  const hits=all.filter(ty=>groups[ty]&&groups[ty].length);
  2620	  const misses=all.filter(ty=>!groups[ty]||!groups[ty].length);
  2621	  let html=hits.map(ty=>catRowHtml(ty,groups[ty])).join('');
  2622	  if(misses.length){
  2623	    html+=`<button class="more-cats" id="moreCats">${showAllCats? t.moreHide : t.moreShow(misses.length)}</button>`;
  2624	    if(showAllCats) html+=misses.map(ty=>catRowHtml(ty,[])).join('');
  2625	  }
  2626	  if(legalE.length)  html=sectionHtml('legal', t.jpLegalSection, legalE)+html;
  2627	  if(manualE.length) html+=sectionHtml('manual', t.manualSection, manualE);
  2628	  if(candE.length)   html+=sectionHtml('candidate', t.candSection, candE);
  2629	  if(keepE.length)   html+=sectionHtml('keep', t.keepSection, keepE);
  2630	  list.innerHTML=html;
  2631	}
  2632	$('piiList').addEventListener('change',e=>{
  2633	  const cb=e.target.closest('input[data-cat]'); if(!cb) return;
  2634	  catEnabled[cb.dataset.cat]=cb.checked; renderAll();
  2635	});
diff --git a/public/safe/index.html b/public/safe/index.html
index 2f22732..053f66b 100644
--- a/public/safe/index.html
+++ b/public/safe/index.html
@@ -198,8 +198,17 @@ header{border-bottom:1px solid var(--line);background:var(--paper);position:stic
 .jp-bar .jp-purpose-l{font-size:12px;color:var(--sub)}
 .jp-bar select{font-family:inherit;font-size:12.5px;border:1px solid var(--line);border-radius:8px;padding:4px 6px;background:#fff}
 .jp-bar .jp-note{width:100%;font-size:11.5px;line-height:1.5;color:var(--no);background:var(--no-bg);border-radius:8px;padding:6px 10px}
+.jp-bar .jp-mn{width:100%;display:flex;align-items:flex-start;gap:7px;font-size:11.5px;line-height:1.5;font-weight:600;cursor:pointer}
+.jp-bar .jp-mn input{margin-top:2px;flex:none}
+/* Classification failed. This has to read as a stop sign, not a hint: nothing
+   was masked automatically and the user has to act. */
+.jp-warn{margin:8px 0 2px;padding:9px 11px;border:1.5px solid var(--no);border-left-width:5px;border-radius:10px;
+  background:var(--no-bg);color:var(--no);font-size:12.5px;font-weight:700;line-height:1.55}
 .cat-row.sec-keep{border-color:var(--ok);background:var(--ok-bg)}
 .cat-row.sec-keep .cl{color:var(--ok)}
+/* Statutory bands: outside the category checkboxes, released one at a time. */
+.cat-row.sec-legal{border-color:var(--no);border-left:5px solid var(--no);background:var(--no-bg)}
+.cat-row.sec-legal .cl{color:var(--no)}
 .band-pick{display:flex;align-items:center;gap:7px;font-size:12.5px;color:var(--sub)}
 .band-pick select,.band-pick input[type=color]{font-family:inherit;font-size:12.5px;border:1px solid var(--line);border-radius:8px;padding:4px 6px;background:#fff}
 .band-pick input[type=color]{padding:2px;width:36px;height:28px}
@@ -354,11 +363,16 @@ footer a{color:var(--sub)}
             <span id="fileInfo"></span>
             <button class="btn ghost small" id="btnReset" style="margin-left:auto" data-i18n="btnReset">다른 문서</button>
           </div>
+          <div class="jp-warn" id="jpWarn" role="alert" style="display:none"></div>
           <div class="jp-bar" id="jpBar" style="display:none">
             <span class="jp-doc" id="jpDocName"></span>
             <label class="jp-purpose-l" for="jpPurpose" data-i18n="jpPurposeLabel">提出目的</label>
             <select id="jpPurpose"></select>
             <div class="jp-note" id="jpNote" style="display:none"></div>
+            <label class="jp-mn" id="jpMnWrap" style="display:none">
+              <input type="checkbox" id="jpMnConfirm">
+              <span id="jpMnLabel"></span>
+            </label>
           </div>
           <div class="sel-bar">
             <button class="btn ghost small" id="btnSelect" data-i18n="btnSelect">🖐 영역 직접 선택</button>
@@ -544,7 +558,7 @@ ko:{
   btnSelect:'🖐 영역 직접 선택', selHint:'가릴 영역을 손가락이나 마우스로 드래그하세요 (사진·서명·도장·이름 등)',
   manualSection:'직접 선택한 영역', candSection:'확인 필요 — 이것도 가릴까요?', manualItem:'직접 선택한 영역',
   jpFields:{address_loose:'문서 내 주소',tel:'전화·FAX',doc_shikaku_kakuninsho:'資格確認書(자격확인서)', doc_unten_menkyo:'運転免許証(운전면허증)', doc_mynumber_card:'マイナンバーカード(마이넘버카드)', doc_juminhyo:'住民票(주민표)', side_front:'앞면', side_back:'뒷면', purpose_identity_submit:'本人確認 제출', purpose_my_number_procedure:'個人番号 절차', purpose_bid_attachment:'입찰 첨부', purpose_consult_share:'상담용 공유', back_all:'뒷면 전체', my_number:'개인번호', jumin_code:'주민표 코드', hokensha_bango:'보험자번호', kigo:'기호', bango:'번호', edaban:'가지번호', hihokensha_bango:'피보험자번호', qr:'2차원 코드', license_no:'면허증번호', biko_change:'비고란(변경 기재)', organ_donor:'장기기증 의사표시란', setaiin:'다른 세대원', honseki:'본적', hittosha:'필두자', sex:'성별', name:'성명', birth:'생년월일', address:'주소', expiry:'유효기간', issue:'교부일', issuer:'발행자'},
-  jpPurposeLabel:'제출 목적', jpBackNotice:'本人確認(신원확인)만 필요하다면 앞면만 제출하세요. 번호법상 뒷면의 個人番号는 법정 목적 외 수집·보관이 금지됩니다. 個人番号 절차를 고르면 해제됩니다.', jpKeepWarn:'제출처가 요구하는 항목입니다. 가리면 접수되지 않을 수 있습니다.', keepSection:'남겨야 하는 항목',
+  jpPurposeLabel:'제출 목적', jpBackNotice:'신원확인이 목적이라면 앞면만 제출하세요. 번호법상 법령이 인정한 사무 외의 목적으로 個人番号를 복사·보관하는 것은 제한됩니다. 「個人番号 절차」는 제출처가 법정 個人番号関係事務를 수행하는 경우에만 선택하세요.', jpKeepWarn:'제출처가 요구하는 항목입니다. 가리면 접수되지 않을 수 있습니다.', jpUnclassifiedWarn:'文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。 (문서 종류를 특정하지 못해 자동 마스킹을 적용하지 않았습니다. 가릴 영역을 직접 선택하세요.)', jpMnConfirm:'제출처가 법정 個人番号関係事務를 수행함을 확인했습니다.', jpLegalSection:'法令・提出先ルール (법령·제출처 규칙)', jpLegalWarn:'법령 근거가 있는 항목입니다. 해제하면 제출처가 보관할 수 없는 정보가 그대로 나갑니다.', keepSection:'남겨야 하는 항목',
   reasons:{name:'이름일 수 있음', jp_auto:'법적 근거로 자동 가림', jp_gate:'목적에 따라 자동 가림', jp_recommend:'가리는 것을 권장', jp_optional:'선택 가능', jp_keep:'제출처가 요구 — 가리지 마세요', addr:'주소일 수 있음', addr_contact:'주소일 수 있음 · 연락처 영역', addr_edge:'주소일 수 있음 · 문서 상·하단', addr_kw:'주소일 수 있음 · 지명·주소어'},
   tManualAdded:'영역을 추가했어요', tManualRemoved:'영역을 삭제했어요', tSelSmall:'너무 작아요. 조금 더 크게 드래그하세요.', btnSelectOn:'✓ 선택 모드 (끄기)',
   wmToggle:'워터마크 넣기 (선택)', wmPlaceholder:'워터마크 문구 (직접 입력 가능)', wmCustom:'직접 입력…',
@@ -601,7 +615,7 @@ en:{
   btnSelect:'🖐 Select area manually', selHint:'Drag with your finger or mouse over the area to hide (photo, signature, stamp, name…)',
   manualSection:'Manually selected areas', candSection:'Please review — hide these too?', manualItem:'Selected area',
   jpFields:{address_loose:'Address in body',tel:'Phone / FAX',doc_shikaku_kakuninsho:'Qualification certificate (資格確認書)', doc_unten_menkyo:'Driver\'s licence (運転免許証)', doc_mynumber_card:'My Number card', doc_juminhyo:'Residence record (住民票)', side_front:'front', side_back:'back', purpose_identity_submit:'Identity verification', purpose_my_number_procedure:'My Number procedure', purpose_bid_attachment:'Tender attachment', purpose_consult_share:'Sharing for advice', back_all:'Entire back face', my_number:'My Number', jumin_code:'Residence code', hokensha_bango:'Insurer number', kigo:'Symbol', bango:'Number', edaban:'Branch number', hihokensha_bango:'Insured number', qr:'2-D code', license_no:'Licence number', biko_change:'Remarks (changes)', organ_donor:'Organ donation section', setaiin:'Other household members', honseki:'Registered domicile', hittosha:'Head of register', sex:'Sex', name:'Name', birth:'Date of birth', address:'Address', expiry:'Valid until', issue:'Issued', issuer:'Issuer'},
-  jpPurposeLabel:'Purpose of submission', jpBackNotice:'If only identity needs checking, submit the front face. Under the My Number Act the number on the back may not be collected or kept outside statutory purposes. Choosing “My Number procedure” releases this.', jpKeepWarn:'The recipient asks for this field. Hiding it may get your submission rejected.', keepSection:'Fields to keep visible',
+  jpPurposeLabel:'Purpose of submission', jpBackNotice:'If identity is what needs checking, submit the front face only. Under the My Number Act, copying or keeping a My Number for anything other than a task the law recognises is restricted. Choose “My Number procedure” only when the recipient performs a statutory My Number task.', jpKeepWarn:'The recipient asks for this field. Hiding it may get your submission rejected.', jpUnclassifiedWarn:'文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。 (The document type could not be identified, so no automatic redaction was applied. Please select the areas to cover by hand.)', jpMnConfirm:'I confirm the recipient performs a statutory My Number (個人番号関係事務) task.', jpLegalSection:'Statutory / recipient rules (法令・提出先ルール)', jpLegalWarn:'This band has a legal basis. Releasing it sends data the recipient is not allowed to keep.', keepSection:'Fields to keep visible',
   reasons:{name:'Possibly a name', jp_auto:'Hidden automatically (legal basis)', jp_gate:'Hidden for this purpose', jp_recommend:'Recommended to hide', jp_optional:'Optional', jp_keep:'Recipient needs this — keep it', addr:'Possibly an address', addr_contact:'Possibly an address · near contact info', addr_edge:'Possibly an address · header/footer', addr_kw:'Possibly an address · place/street term'},
   tManualAdded:'Area added', tManualRemoved:'Area removed', tSelSmall:'Too small — drag a bit larger.', btnSelectOn:'✓ Selecting (turn off)',
   wmToggle:'Add watermark (optional)', wmPlaceholder:'Watermark text (editable)', wmCustom:'Custom…',
@@ -658,7 +672,7 @@ ja:{
   btnSelect:'🖐 範囲を手動で選択', selHint:'隠したい範囲を指またはマウスでドラッグしてください（写真・署名・印鑑・氏名など）',
   manualSection:'手動で選択した範囲', candSection:'要確認 — これも隠しますか？', manualItem:'選択した範囲',
   jpFields:{address_loose:'本文中の住所',tel:'電話・FAX',doc_shikaku_kakuninsho:'資格確認書', doc_unten_menkyo:'運転免許証', doc_mynumber_card:'マイナンバーカード', doc_juminhyo:'住民票の写し', side_front:'表面', side_back:'裏面', purpose_identity_submit:'本人確認提出', purpose_my_number_procedure:'個人番号手続', purpose_bid_attachment:'入札添付', purpose_consult_share:'相談用共有', back_all:'裏面全体', my_number:'個人番号', jumin_code:'住民票コード', hokensha_bango:'保険者番号', kigo:'記号', bango:'番号', edaban:'枝番', hihokensha_bango:'被保険者番号', qr:'二次元コード', license_no:'免許証番号', biko_change:'備考欄（変更記載）', organ_donor:'臓器提供意思表示欄', setaiin:'本人以外の世帯員', honseki:'本籍', hittosha:'筆頭者', sex:'性別', name:'氏名', birth:'生年月日', address:'住所', expiry:'有効期限', issue:'交付日', issuer:'発行者'},
-  jpPurposeLabel:'提出目的', jpBackNotice:'身元確認なら表面のみ提出。番号法により、法定目的以外で裏面の個人番号を収集・保管することはできません。「個人番号手続」を選ぶと解除されます。', jpKeepWarn:'提出先が受付できない可能性があります（本人特定事項）。', keepSection:'残す項目',
+  jpPurposeLabel:'提出目的', jpBackNotice:'身元確認が目的なら表面のみ提出してください。番号法上、法令で認められた事務以外で個人番号を複写・保管することは制限されています。「個人番号手続」は、提出先が法定の個人番号関係事務を行う場合にのみ選んでください。', jpKeepWarn:'提出先が受付できない可能性があります（本人特定事項）。', jpUnclassifiedWarn:'文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。', jpMnConfirm:'提出先が法定の個人番号関係事務を行うことを確認しました。', jpLegalSection:'法令・提出先ルール', jpLegalWarn:'法令に根拠がある項目です。解除すると、提出先が保管できない情報がそのまま出力されます。', keepSection:'残す項目',
   reasons:{name:'氏名の可能性', jp_auto:'法令根拠により自動で黒塗り', jp_gate:'この目的では自動で黒塗り', jp_recommend:'黒塗りを推奨', jp_optional:'任意', jp_keep:'提出先が必要とする項目', addr:'住所の可能性', addr_contact:'住所の可能性 · 連絡先の近く', addr_edge:'住所の可能性 · 文書の上部・下部', addr_kw:'住所の可能性 · 地名・住所語'},
   tManualAdded:'範囲を追加しました', tManualRemoved:'範囲を削除しました', tSelSmall:'小さすぎます。もう少し大きくドラッグしてください。', btnSelectOn:'✓ 選択モード（オフ）',
   wmToggle:'ウォーターマークを入れる（任意）', wmPlaceholder:'ウォーターマーク文言（自由入力可）', wmCustom:'自由入力…',
@@ -715,7 +729,7 @@ es:{
   btnSelect:'🖐 Seleccionar área manualmente', selHint:'Arrastra con el dedo o el ratón sobre el área a ocultar (foto, firma, sello, nombre…)',
   manualSection:'Áreas seleccionadas manualmente', candSection:'Revisar — ¿ocultar también esto?', manualItem:'Área seleccionada',
   jpFields:{address_loose:'Dirección en el texto',tel:'Teléfono / FAX',doc_shikaku_kakuninsho:'Certificado de cobertura (資格確認書)', doc_unten_menkyo:'Permiso de conducir (運転免許証)', doc_mynumber_card:'Tarjeta My Number', doc_juminhyo:'Certificado de residencia (住民票)', side_front:'anverso', side_back:'reverso', purpose_identity_submit:'Verificación de identidad', purpose_my_number_procedure:'Trámite de My Number', purpose_bid_attachment:'Anexo de licitación', purpose_consult_share:'Compartir para consulta', back_all:'Todo el reverso', my_number:'My Number', jumin_code:'Código de residencia', hokensha_bango:'N.º de aseguradora', kigo:'Símbolo', bango:'Número', edaban:'N.º de rama', hihokensha_bango:'N.º de asegurado', qr:'Código 2D', license_no:'N.º de permiso', biko_change:'Observaciones (cambios)', organ_donor:'Apartado de donación de órganos', setaiin:'Otros miembros del hogar', honseki:'Domicilio registral', hittosha:'Titular del registro', sex:'Sexo', name:'Nombre', birth:'Fecha de nacimiento', address:'Dirección', expiry:'Válido hasta', issue:'Emitido', issuer:'Emisor'},
-  jpPurposeLabel:'Finalidad del envío', jpBackNotice:'Si solo hay que verificar la identidad, envía el anverso. La Ley My Number prohíbe recoger o conservar el número del reverso fuera de los fines legales. Elegir «Trámite de My Number» lo libera.', jpKeepWarn:'El destinatario pide este dato. Ocultarlo puede provocar el rechazo del envío.', keepSection:'Campos que deben quedar visibles',
+  jpPurposeLabel:'Finalidad del envío', jpBackNotice:'Si lo que hay que verificar es la identidad, envía solo el anverso. La Ley My Number restringe copiar o conservar un My Number para fines distintos de los trámites reconocidos por la ley. Elige «Trámite de My Number» solo si el destinatario realiza un trámite legal de My Number.', jpKeepWarn:'El destinatario pide este dato. Ocultarlo puede provocar el rechazo del envío.', jpUnclassifiedWarn:'文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。 (No se ha podido identificar el tipo de documento, por lo que no se aplicó ningún tachado automático. Selecciona a mano las zonas que quieras cubrir.)', jpMnConfirm:'Confirmo que el destinatario realiza un trámite legal de My Number (個人番号関係事務).', jpLegalSection:'Reglas legales / del destinatario (法令・提出先ルール)', jpLegalWarn:'Esta banda tiene base legal. Al liberarla envías datos que el destinatario no puede conservar.', keepSection:'Campos que deben quedar visibles',
   reasons:{name:'Puede ser un nombre', jp_auto:'Oculto automáticamente (base legal)', jp_gate:'Oculto para esta finalidad', jp_recommend:'Se recomienda ocultar', jp_optional:'Opcional', jp_keep:'El destinatario lo necesita', addr:'Puede ser una dirección', addr_contact:'Puede ser una dirección · cerca del contacto', addr_edge:'Puede ser una dirección · encabezado/pie', addr_kw:'Puede ser una dirección · término de lugar/calle'},
   tManualAdded:'Área añadida', tManualRemoved:'Área eliminada', tSelSmall:'Demasiado pequeña — arrastra un poco más.', btnSelectOn:'✓ Seleccionando (desactivar)',
   wmToggle:'Añadir marca de agua (opcional)', wmPlaceholder:'Texto de la marca de agua (editable)', wmCustom:'Personalizado…',
@@ -774,7 +788,13 @@ const TYPES = {
   other:{icon:'📌',risk:'ok'}
 };
 Object.keys(TYPES).forEach(t=>{catEnabled[t]=true;catDefault[t]=TYPES[t].risk;});
-const isOn=e=>catEnabled[e.type]!==false;
+/* `e.legal` = a band the Japanese legal matrix grounds in statute (番号法 /
+   告知要求制限 / 住民基本台帳法). It is NOT governed by the general category
+   checkboxes: 二次元コード and 裏面全体 map to the catch-all 'other' type, so
+   unticking 「その他」 silently deleted the マイナカード裏面 band and the
+   資格確認書 QR band from the output (Codex 4-6). Those can only be released
+   one item at a time, and the release warns. */
+const isOn=e=>e.legal?true:catEnabled[e.type]!==false;
 const tLabel=t=>T().types[t]||t;
 
 /* ───────── lazy library loaders ───────── */
@@ -1167,29 +1187,47 @@ function jpSegBox(seg){
    ones twice. Below threshold the page is "一般文書" and NO Japanese automatic
    masking happens at all. */
 const JP_CLASSES = {
-  shikaku_kakuninsho: { min: 4, kw: [['資格確認書',3],['保険者番号',2],['被保険者',2],['保険者名',2],
+  shikaku_kakuninsho: { min: 4, title: ['資格確認書'], kw: [['資格確認書',3],['保険者番号',2],['被保険者',2],['保険者名',2],
       ['国民健康保険',2],['後期高齢者',2],['枝番',2],['記号',1],['健康保険',1],['一部負担金',1]] },
-  unten_menkyo: { min: 4, kw: [['運転免許証',4],['免許証',2],['公安委員会',2],['備考欄',2],
+  unten_menkyo: { min: 4, title: ['運転免許証'], kw: [['運転免許証',4],['免許証',2],['公安委員会',2],['備考欄',2],
       ['臓器提供',1],['提供意思',1],['優良',1],['原付',1]] },
-  mynumber_card: { min: 4, kw: [['個人番号カード',4],['マイナンバーカード',4],['個人番号',2],
+  mynumber_card: { min: 4, title: ['個人番号カード','マイナンバーカード'], kw: [['個人番号カード',4],['マイナンバーカード',4],['個人番号',2],
       ['券面記載事項',2],['マイナンバー',2]] },
-  juminhyo: { min: 4, kw: [['住民票',3],['世帯主',2],['続柄',2],['筆頭者',2],['世帯全員',2],
+  juminhyo: { min: 4, title: ['住民票'], kw: [['住民票',3],['世帯主',2],['続柄',2],['筆頭者',2],['世帯全員',2],
       ['住民となった日',2],['住民票コード',2],['本籍',1],['住民となつた日',2]] },
 };
+/* Does this page LOOK Japanese-official even though no class reached threshold?
+   Any one of the four document names, or a 和暦 era marker, is enough. This is
+   not a classification — it is the trigger for telling the user that automatic
+   masking did NOT run, which is the failure the previous build was silent about
+   (a single garbled label dropped the whole JP preset and nothing said so). */
+const JP_SUSPECT_RE = /資格確認書|免許証|個人番号|マイナンバー|住民票|令和|平成|昭和/;
+function jpSuspect(pi){ return JP_SUSPECT_RE.test(jpPageText(pi)); }
 function jpPageText(pi){
   const page = pages[pi];
   if (page._jptext != null) return page._jptext;
   let s = ''; for (const it of page.items) s += jpNorm(it.str || '').t;
   return (page._jptext = s);
 }
+/* Classification has two outcomes that are NOT the same thing:
+     confident  — score >= min. The legal preset applies as written.
+     low        — score < min but the document's own TITLE was read. We know
+                  which form this is, and we do not know it well enough to
+                  delete pixels on our own: every level is demoted to a review
+                  candidate (see jpApply) and the warning banner stays up.
+   Below both, the page is 一般文書 and no Japanese rule runs at all — which is
+   precisely when the banner has to say so (Codex 1-1). */
 function jpClassify(pi){
   const txt = jpPageText(pi);
-  let best = null;
+  let best = null, low = null;
   for (const [id, def] of Object.entries(JP_CLASSES)){
     let score = 0, hits = [];
     for (const [k, w] of def.kw) if (txt.includes(k)) { score += w; hits.push(k); }
     if (score >= def.min && (!best || score > best.score)) best = { doc: id, score, hits };
+    else if (score < def.min && def.title.some(t => txt.includes(t)) && (!low || score > low.score))
+      low = { doc: id, score, hits, low: true };
   }
+  if (!best) best = low;
   if (!best) return null;
   // Side: cards have two faces with completely different legal treatment.
   if (best.doc === 'mynumber_card' || best.doc === 'unten_menkyo'){
@@ -1199,9 +1237,17 @@ function jpClassify(pi){
   return best;
 }
 
-/* ── 個人番号 check digit (番号法施行令 別表) ──
+/* ── 個人番号 check digit ──
+   Source: 行政手続における特定の個人を識別するための番号の利用等に関する法律の
+   規定による通知カード及び個人番号カード並びに情報提供ネットワークシステムによる
+   特定個人情報の提供等に関する省令 **第5条**
+   (https://laws.e-gov.go.jp/document?lawid=426M60000008085_20231215_505M60004008017).
+   NOT 番号法施行令 別表 — that was the citation here until 2026-10-21 and it was
+   wrong; the arithmetic below was always right (Codex 1-5).
    Σ P_n·Q_n over the 11-digit body counted from the RIGHT (n = 1..11),
-   Q_n = n+1 for n ≤ 6 else n−5; check = 11 − (Σ mod 11), and ≥10 → 0. */
+   Q_n = n+1 for n ≤ 6 else n−5; check = 11 − (Σ mod 11), and ≥10 → 0.
+   (The 省令 states it as: remainder 0 or 1 → check digit 0. Equivalent — a
+   remainder of 0 gives 11 and of 1 gives 10, both folded to 0 by the ≥10 rule.) */
 function myNumberCheckOk(d12){
   if (!/^\d{12}$/.test(d12)) return false;
   const d = d12.slice(0, 11).split('').map(Number);
@@ -1368,23 +1414,34 @@ function jpSolidSquares(page, pi){
 }
 
 /* ── legal matrix, as code ──
-   Mirrors test/safe/fixtures/jp/jp_legal_matrix_alpha4.json. Levels:
+   Mirrors test/safe/fixtures/jp/jp_legal_matrix_alpha4.json, which is the 정본.
+   The JSON is NOT loaded at runtime (this page is a single static file with no
+   build step), so the two are kept identical by `node test/safe/check_matrix.mjs`
+   — it derives (doc, field, purpose) → level from the JSON, reads this table out
+   of this file, and fails on any disagreement. run.mjs calls it first, so the
+   golden cannot pass while the two tables drift apart (Codex 4-1, 5-1).
+   Levels:
      auto      文書分類+ラベル一致で自動黒塗り
-     gate      目的選択後に自動（別目的では解除）= auto_with_purpose_gate
+     gate      目的選択後に自動（別目的では解除。解除に確認を要求）
      recommend 既定ON・解除可
      optional  既定OFF・選択可
      keep      黒塗り禁止（警告）
-   Two documented deviations from the JSON, both widening what may be hidden:
-   本籍/筆頭者 also carry `recommend` for my_number_procedure and bid_attachment
-   (the 本籍 is not part of a 個人番号 or tender filing either), matching the
-   fixture expectations. */
-const P_ALL = ['identity_submit','my_number_procedure','bid_attachment','consult_share'];
+   A (doc, field, purpose) the matrix does not name is `null`: not offered at
+   all. There is deliberately no "default to optional" fallback — the matrix
+   enumerates every purpose it means to allow, and silence is not permission
+   (Codex 4-2). */
 const P_NOT_MYNUM = ['identity_submit','bid_attachment','consult_share'];
-// Shared by all four documents: neither a free-standing address nor a phone
-// number is part of what any of them has to prove, so both are always OFFERED —
-// and recommended when the point of sharing is advice, not identification.
-const JP_EXTRA = { address_loose: { recommend: ['consult_share'], optional: P_ALL },
-                   tel:           { recommend: ['consult_share'], optional: P_ALL } };
+const P_ID_BID = ['identity_submit','bid_attachment'];
+const P_ID_CONSULT = ['identity_submit','consult_share'];
+// Shared by all four documents (matrix: general_jp): neither a free-standing
+// address nor a phone number is part of what any of them has to prove, so both
+// are always OFFERED — and recommended when the point of sharing is advice.
+// Both are verified:false in the matrix, so neither may ever be auto/gate.
+const JP_EXTRA = { address_loose: { recommend: ['consult_share'], optional: ['identity_submit','my_number_procedure','bid_attachment'] },
+                   tel:           { recommend: ['consult_share'], optional: ['identity_submit','my_number_procedure','bid_attachment'] } };
+// 本人特定事項: must-keep where the recipient is checking identity, offered
+// (default OFF) where no recipient requirement exists at all.
+const KEEP_ID_BID  = { keep: P_ID_BID, optional: ['consult_share'] };
 const JP_RULES = {
   shikaku_kakuninsho: {
     // 健康保険法等 告知要求制限 (2020-10-01) — mhlw.go.jp/stf/newpage_13989.html
@@ -1397,16 +1454,19 @@ const JP_RULES = {
     qr:               { auto: P_NOT_MYNUM },
     // 法定ではない。民間KYC運用（SoftBank, PayPay銀行等）
     sex:              { recommend: ['identity_submit'] },
-    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL},
-    jigyosho:{keep:P_ALL}, hokensha_name:{keep:P_ALL}, shikaku_date:{keep:P_ALL},
+    name: KEEP_ID_BID, birth: KEEP_ID_BID, address: KEEP_ID_BID, expiry: KEEP_ID_BID,
+    // verified:false in the matrix — warning only, never automatic.
+    jigyosho: KEEP_ID_BID, hokensha_name: KEEP_ID_BID, shikaku_date: KEEP_ID_BID,
     ...JP_EXTRA,
   },
   unten_menkyo: {
-    biko_change:  { recommend: ['identity_submit','consult_share'] },
-    organ_donor:  { recommend: ['identity_submit','consult_share'] },
-    // 個人識別符号だが、KYCでは照合に必要な提出先が多い → 既定OFF
-    license_no:   { optional: P_ALL },
-    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL}, issue:{keep:P_ALL},
+    biko_change:  { recommend: P_ID_CONSULT },
+    organ_donor:  { recommend: P_ID_CONSULT },
+    // 個人識別符号。KYCでは照合に必要な提出先が多い → 本人確認提出は must-keep,
+    // 相談用共有は既定OFFで選択可。他の目的は matrix が명시しない → null.
+    license_no:   { keep: ['identity_submit'], optional: ['consult_share'] },
+    name:{keep:['identity_submit'],optional:['consult_share']}, birth:{keep:['identity_submit'],optional:['consult_share']},
+    address:{keep:['identity_submit'],optional:['consult_share']}, expiry:{keep:['identity_submit'],optional:['consult_share']},
     ...JP_EXTRA,
   },
   mynumber_card: {
@@ -1416,32 +1476,38 @@ const JP_RULES = {
     qr:         { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
     sex:        { recommend: ['identity_submit'] },
     organ_donor:{ recommend: ['identity_submit'] },
-    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, expiry:{keep:P_ALL},
+    name:{keep:['identity_submit','my_number_procedure'],optional:['consult_share']},
+    birth:{keep:['identity_submit','my_number_procedure'],optional:['consult_share']},
+    address:{keep:['identity_submit','my_number_procedure'],optional:['consult_share']},
+    expiry:{keep:['identity_submit','my_number_procedure'],optional:['consult_share']},
     ...JP_EXTRA,
   },
   juminhyo: {
     my_number:  { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
-    // 住民基本台帳法 利用制限（個人識別符号）
-    jumin_code: { auto: P_NOT_MYNUM },
-    honseki:    { recommend: P_ALL },
-    hittosha:   { recommend: P_ALL },
-    setaiin:    { recommend: ['identity_submit','consult_share'] },
-    name:{keep:P_ALL}, birth:{keep:P_ALL}, address:{keep:P_ALL}, issuer:{keep:P_ALL},
+    // 住民基本台帳法 利用制限（個人識別符号）と理解しているが出典を確保できていない
+    // → matrix verified:false。既定ON で帯は引くが auto とは呼ばない。
+    jumin_code: { recommend: P_NOT_MYNUM },
+    honseki:    { recommend: P_ID_CONSULT, optional: ['my_number_procedure','bid_attachment'] },
+    hittosha:   { recommend: P_ID_CONSULT, optional: ['my_number_procedure','bid_attachment'] },
+    setaiin:    { recommend: P_ID_CONSULT, optional: ['my_number_procedure','bid_attachment'] },
+    name: KEEP_ID_BID, birth: KEEP_ID_BID, address: KEEP_ID_BID, issuer: KEEP_ID_BID,
     ...JP_EXTRA,
   },
 };
+/* The legal-preset fields: the ones the matrix grounds in 番号法 / 告知要求制限 /
+   住民基本台帳法 rather than in a submission-desk convention. They are NOT
+   subject to the general category checkboxes — turning off 「その他」 used to
+   silently remove the マイナカード裏面 band and the 資格確認書 QR band from the
+   output, with no warning (Codex 4-6). They live in their own group and can only
+   be released one item at a time. */
+const JP_LEGAL_FIELDS = new Set(['back_all','qr','my_number','jumin_code',
+  'hokensha_bango','kigo','bango','edaban','hihokensha_bango']);
 function jpLevel(doc, field, purpose){
   const r = (JP_RULES[doc] || {})[field];
   if (!r) return null;
   for (const lv of ['auto','gate','recommend','optional','keep'])
     if (r[lv] && r[lv].includes(purpose)) return lv;
-  // A field the matrix knows but whose rule does not name THIS purpose. It is
-  // offered and left off — not promoted to automatic (we have no basis), and
-  // not pinned to keep either (keep forbids hiding, and "the matrix is silent"
-  // is not a reason to forbid the user anything). Same answer whether or not
-  // the field has a keep clause for other purposes, which is why there is no
-  // branch here.
-  return 'optional';
+  return null;
 }
 
 /* ── field extraction ─────────────────────────────────────────────────────
@@ -1465,6 +1531,13 @@ const JP_FIELD_RULES = {
     { field:'birth',  labels:['生年月日'], re:null, last:true },
     { field:'address',labels:['住所'], re:null, last:true, addr:true },
     { field:'expiry', labels:['有効期限'], re:null, last:true },
+    // These three carry a keep rule in the matrix (verified:false — warning
+    // only). Without a detection rule the keep rule was dead code: the warning
+    // it promises could never be shown. 資格取得年月日 holds 年月日, so the
+    // numeric fallback already skips its row.
+    { field:'shikaku_date',  labels:['資格取得年月日','資格取得'], re:null, last:true },
+    { field:'hokensha_name', labels:['保険者名'], re:null, last:true },
+    { field:'jigyosho',      labels:['事業所名称','事業所名'], re:null, last:true },
     { field:'tel',    labels:['電話番号','電話','TEL','携帯','FAX'], tel:true },
   ],
   // Front-only: the back carries a 住所変更 line inside 備考欄, and calling that
@@ -1605,7 +1678,14 @@ function jpExtract(pi, cls){
   const rules = (JP_FIELD_RULES[cls.doc] || [])
     .filter(r => !r.sides || r.sides.includes(cls.side))
     .map(r => ({ ...r, headOnly: true }));
-  const push = (field, boxes, value, extra) => { if (boxes && boxes.length) found.push({ field, boxes, value, pi, ...extra }); };
+  // Every finding carries the classification of ITS OWN page. A two-sided card
+  // scanned into one PDF has a different legal rule on each page, so applying
+  // page 1's doc/side to every page made the outcome depend on scan order:
+  // front-then-back left the 個人番号 page untouched, back-then-front banded the
+  // front as well (Codex 6-4).
+  const push = (field, boxes, value, extra) => {
+    if (boxes && boxes.length) found.push({ field, boxes, value, pi, doc: cls.doc, side: cls.side || null, low: !!cls.low, ...extra });
+  };
 
   for (const seg of segs){
     for (const r of rules){
@@ -1774,59 +1854,102 @@ function jpExtract(pi, cls){
 
 /* ── state + application ── */
 const JP_PURPOSES = ['identity_submit','my_number_procedure','bid_attachment','consult_share'];
-let jpState = { cls: null, purpose: 'identity_submit', findings: [] };
+const JP_STATE0 = () => ({ cls: null, pageCls: [], purpose: 'identity_submit', findings: [], warn: null, mnConfirmed: false });
+let jpState = JP_STATE0();
 function jpScan(){
-  jpState.cls = null; jpState.findings = [];
+  const keepPurpose = jpState.purpose;
+  jpState = JP_STATE0(); jpState.purpose = keepPurpose;
   if (!pages.length) return null;
-  const cls = jpClassify(0);
-  if (!cls) return null;
-  jpState.cls = cls;
-  let all = [];
-  for (let pi = 0; pi < pages.length; pi++){
-    const c = pi === 0 ? cls : (jpClassify(pi) || cls);
-    all = all.concat(jpExtract(pi, c));
+  // Per-page classification. Page 0 names the document in the UI, but each page
+  // is governed by its OWN class — and a page that cannot be classified falls
+  // back to page 0's class only when page 0 HAS one.
+  const cls0 = jpClassify(0);
+  const pageCls = [];
+  for (let pi = 0; pi < pages.length; pi++) pageCls.push(pi === 0 ? cls0 : (jpClassify(pi) || cls0));
+  jpState.pageCls = pageCls;
+  if (!cls0){
+    // No Japanese rule will run. Say so if the page looks like one of these
+    // documents, instead of falling through to the Latin heuristics in silence.
+    if (pages.some((p, pi) => jpSuspect(pi))) jpState.warn = 'unclassified';
+    return null;
   }
+  jpState.cls = cls0;
+  if (pageCls.some(c => c && c.low)) jpState.warn = 'lowconf';
+  let all = [];
+  for (let pi = 0; pi < pages.length; pi++) if (pageCls[pi]) all = all.concat(jpExtract(pi, pageCls[pi]));
   jpState.findings = all;
-  return cls;
+  return cls0;
 }
 function jpFieldLabel(f){ return (T().jpFields && T().jpFields[f]) || f; }
 // Build entities from the findings for the current purpose. Called on load and
 // on every purpose change — the purpose IS the policy, so it re-derives rather
 // than patching modes in place.
+/* The 個人番号 purpose gate needs more than a dropdown. Choosing 「個人番号手続」
+   releases a band that 番号法 put there, and the dropdown alone cannot establish
+   that the recipient actually performs a 個人番号関係事務 — PPC FAQ Q6-12
+   distinguishes seeing a number from copying and keeping it, and both assume the
+   recipient is entitled to it (Codex 4-4). So the release requires the purpose
+   AND an explicit confirmation; until it is given, the band stays. */
+function jpMnGateOpen(){ return jpState.purpose === 'my_number_procedure' && jpState.mnConfirmed; }
+const JP_MN_GATED = new Set(['back_all','my_number','qr']);
 function jpApply(){
   entities = entities.filter(e => !e.jp);
-  const cls = jpState.cls; if (!cls) { renderAll(); return; }
+  const cls = jpState.cls; if (!cls) { jpRenderBar(); renderAll(); return; }
   const purpose = jpState.purpose;
-  const add = (f, level, boxes, value, note) => {
+  const add = (f, level, boxes, value, note, ctx) => {
     const kind = (level === 'auto' || level === 'gate') ? 'auto'
                : level === 'keep' ? 'keep' : 'candidate';
     const mode = (level === 'auto' || level === 'gate' || level === 'recommend') ? 'no' : 'ok';
+    // A legal-preset band is not governed by the general category checkboxes.
+    const legal = JP_LEGAL_FIELDS.has(f) && mode === 'no';
     entities.push({ id:'j'+Math.random().toString(36).slice(2,8), type: JP_TYPE[f] || 'other',
-      value, mode, kind, reason: 'jp_' + level, boxes, jp: { doc: cls.doc, side: cls.side || null, field: f, level, note: note || null } });
+      value, mode, kind, legal, reason: 'jp_' + level, boxes,
+      jp: { doc: (ctx && ctx.doc) || cls.doc, side: (ctx && ctx.side) || cls.side || null, page: ctx ? ctx.page : null, field: f, level, note: note || null } });
   };
-
-  // マイナンバーカード裏面 under a 本人確認 purpose: the whole face. 番号法 does not
-  // let the recipient hold the 個人番号 at all for identity checking, so the
-  // honest instruction is "submit the front instead", and the band says so.
-  if (cls.doc === 'mynumber_card' && cls.side === 'back'){
-    const lv = jpLevel('mynumber_card', 'back_all', purpose);
-    if (lv === 'auto' || lv === 'gate'){
-      for (let pi = 0; pi < pages.length; pi++)
-        add('back_all', lv, [{ page: pi, x: 0, y: 0, w: pages[pi].w, h: pages[pi].h, region: true }], jpFieldLabel('back_all'));
+  // Resolve the level for one finding under the current purpose, including the
+  // two demotions and the confirmation gate. Returns null = not offered.
+  const resolve = (doc, field, f) => {
+    let level = jpLevel(doc, field, purpose), note = null;
+    if (!level) return null;
+    // Unconfirmed 個人番号手続: the matrix says keep, but the release has not
+    // been confirmed, so the 番号法 band stays as if the purpose were 本人確認.
+    if (level === 'keep' && JP_MN_GATED.has(field) && purpose === 'my_number_procedure' && !jpState.mnConfirmed){
+      level = 'gate'; note = 'mn_unconfirmed';
     }
-  }
-  for (const f of jpState.findings){
-    let level = jpLevel(cls.doc, f.field, purpose);
-    if (!level) continue;
-    // 個人番号 with a check digit that does not verify is NOT confirmed to be a
+    // A low-confidence classification may not delete pixels on its own.
+    if (f && f.low && (level === 'auto' || level === 'gate')){ level = 'recommend'; note = 'lowconf'; }
+    if (!f) return { level, note };
+    // 個人番号 whose check digit does not verify is NOT confirmed to be a
     // 個人番号 — it could be any 12-digit reference. Demote the automatic band
     // to a review candidate (still default-ON) rather than assert something the
     // arithmetic contradicts.
-    let note = null;
-    if (f.field === 'my_number' && (level === 'auto' || level === 'gate') && f.checkOk === false){ level = 'recommend'; note = 'checkdigit'; }
-    // An unlabelled code block is detection without golden coverage — candidate.
-    if (f.unlabelledCode && (level === 'auto' || level === 'gate')){ level = 'recommend'; note = 'unlabelled_code'; }
-    add(f.field, level, f.boxes, f.field === 'qr' || f.boxes.some(b=>b.region) ? jpFieldLabel(f.field) : (f.value || jpFieldLabel(f.field)), note);
+    if (field === 'my_number' && (level === 'auto' || level === 'gate') && f.checkOk === false){ level = 'recommend'; note = 'checkdigit'; }
+    // An unlabelled square block has no QR-specific evidence behind it (no
+    // finder pattern, no quiet zone, no module pitch) and no golden coverage —
+    // a face photo, a round seal (bbox fill ≈ 0.785) or a black table header
+    // can all satisfy the size/ratio/fill test. It is OFFERED and left OFF:
+    // a guess must not remove content from the default output (Codex 2-2, 6-1).
+    if (f.unlabelledCode){ level = 'optional'; note = 'unlabelled_code'; }
+    return { level, note };
+  };
+
+  // マイナンバーカード裏面 under a 本人確認 purpose: the whole face, PER PAGE that
+  // is actually a back face. 番号法 does not let the recipient hold the 個人番号
+  // at all for identity checking, so the honest instruction is "submit the front
+  // instead", and the band says so.
+  for (let pi = 0; pi < pages.length; pi++){
+    const pc = jpState.pageCls[pi];
+    if (!pc || pc.doc !== 'mynumber_card' || pc.side !== 'back') continue;
+    const r = resolve('mynumber_card', 'back_all', { low: pc.low });
+    if (r && (r.level === 'auto' || r.level === 'gate' || r.level === 'recommend'))
+      add('back_all', r.level, [{ page: pi, x: 0, y: 0, w: pages[pi].w, h: pages[pi].h, region: true }],
+          jpFieldLabel('back_all'), r.note, { doc: pc.doc, side: pc.side, page: pi });
+  }
+  for (const f of jpState.findings){
+    const r = resolve(f.doc, f.field, f);
+    if (!r) continue;
+    add(f.field, r.level, f.boxes, f.field === 'qr' || f.boxes.some(b=>b.region) ? jpFieldLabel(f.field) : (f.value || jpFieldLabel(f.field)),
+        r.note, { doc: f.doc, side: f.side, page: f.pi });
   }
   entities.sort((a,b)=>Object.keys(TYPES).indexOf(a.type)-Object.keys(TYPES).indexOf(b.type));
   jpRenderBar();
@@ -1840,12 +1963,23 @@ const JP_TYPE = { address_loose:'address', tel:'phone', my_number:'rrn', jumin_c
 function jpSetPurpose(p){
   if (!JP_PURPOSES.includes(p)) return;
   jpState.purpose = p;
+  // Switching purpose always re-asks for the 個人番号 confirmation. A checkbox
+  // left ticked from a previous purpose is not a confirmation of this one.
+  jpState.mnConfirmed = false;
   const sel = $('jpPurpose'); if (sel) sel.value = p;
   jpApply();
 }
+function jpSetMnConfirmed(v){ jpState.mnConfirmed = !!v; jpApply(); }
 function jpRenderBar(){
-  const bar = $('jpBar'); if (!bar) return;
+  const bar = $('jpBar'), warn = $('jpWarn'); if (!bar) return;
   const cls = jpState.cls;
+  // The blocking warning is independent of the bar: its whole point is to be
+  // visible in the case where there is no classification and therefore no bar.
+  if (warn){
+    const show = !!jpState.warn;
+    warn.textContent = show ? T().jpUnclassifiedWarn : '';
+    warn.style.display = show ? 'block' : 'none';
+  }
   if (!cls){ bar.style.display = 'none'; return; }
   bar.style.display = 'flex';
   $('jpDocName').textContent = jpFieldLabel('doc_' + cls.doc) + (cls.side ? ' · ' + jpFieldLabel('side_' + cls.side) : '');
@@ -1853,9 +1987,20 @@ function jpRenderBar(){
   sel.innerHTML = JP_PURPOSES.map(p => `<option value="${p}">${escapeHtml(jpFieldLabel('purpose_' + p))}</option>`).join('');
   sel.value = jpState.purpose;
   const note = $('jpNote');
-  const backMasked = entities.some(e => e.jp && e.jp.field === 'back_all');
-  note.textContent = backMasked ? T().jpBackNotice : '';
-  note.style.display = backMasked ? 'block' : 'none';
+  // The notice is shown whenever this document HAS a 個人番号 rule — including
+  // after the user switched to 個人番号手続, where it is the text that explains
+  // what the confirmation below it means.
+  const hasMn = jpState.findings.some(f => f.field === 'my_number')
+    || jpState.pageCls.some(c => c && c.doc === 'mynumber_card' && c.side === 'back');
+  note.textContent = hasMn ? T().jpBackNotice : '';
+  note.style.display = hasMn ? 'block' : 'none';
+  const cw = $('jpMnWrap'), cb = $('jpMnConfirm');
+  if (cw && cb){
+    const need = hasMn && jpState.purpose === 'my_number_procedure';
+    cw.style.display = need ? 'flex' : 'none';
+    cb.checked = !!jpState.mnConfirmed;
+    const lb = $('jpMnLabel'); if (lb) lb.textContent = T().jpMnConfirm;
+  }
 }
 
 /* ───────── text masking (list display + "copy text") ─────────
@@ -2168,7 +2313,7 @@ function afterLoad(keepEntities){
 function resetResult(){ $('result').style.display='none'; lastOut=null; }
 function resetAll(){
   pages=[]; docText=''; entities=[]; aiDone=false; showAllCats=false; previewCanvases=[];
-  jpState={cls:null, purpose:'identity_submit', findings:[]}; jpRenderBar();
+  jpState=JP_STATE0(); jpRenderBar();
   $('docWrap').style.display='none'; dz.style.display='flex'; $('preview').innerHTML=''; clearDzAlert();
   if(typeof setSelectMode==='function') setSelectMode(false);
   setStatus(''); setProg(0); resetResult();
@@ -2430,7 +2575,7 @@ function catRowHtml(type,items){
 // Flat item box for manual selections / name candidates (not category-grouped).
 function sectionHtml(kind,title,items){
   const t=T(), cand=kind==='candidate';
-  const icon=kind==='candidate'?'❓':kind==='keep'?'🛡':'✏️';
+  const icon=kind==='candidate'?'❓':kind==='keep'?'🛡':kind==='legal'?'⚖️':'✏️';
   return `
   <div class="cat-row sec-${kind}">
     <div class="cat-head">
@@ -2441,7 +2586,7 @@ function sectionHtml(kind,title,items){
       <div class="pii-item${cand?' is-cand':''}">
         <div class="val-wrap">
           <span class="val ${cand?'':'mono'}" title="${escapeHtml(e.value)}">${escapeHtml(kind==='manual'? t.manualItem : displayValue(e))}</span>
-          ${(cand||kind==='keep')?`<span class="reason">${(TYPES[e.type]||{}).icon||''} ${t.reasons[e.reason]||(e.jp?t.reasons.jp_keep:t.reasons.name)}</span>`:''}
+          ${(cand||kind==='keep'||kind==='legal')?`<span class="reason">${(TYPES[e.type]||{}).icon||''} ${t.reasons[e.reason]||(e.jp?t.reasons.jp_keep:t.reasons.name)}</span>`:''}
         </div>
         <div class="seg" role="radiogroup">
           <button class="${e.mode==='ok'?'on-ok':''}" data-id="${e.id}" data-mode="ok">${t.segOk}</button>
@@ -2453,10 +2598,13 @@ function sectionHtml(kind,title,items){
 }
 function renderList(){
   const list=$('piiList'), t=T();
-  const autoE=entities.filter(e=>e.kind!=='candidate'&&e.kind!=='manual'&&e.kind!=='keep');
-  const manualE=entities.filter(e=>e.kind==='manual');
-  const candE=entities.filter(e=>e.kind==='candidate');
-  const keepE=entities.filter(e=>e.kind==='keep');
+  // Legal-preset bands come out of the category grouping entirely — they are not
+  // a "type" the user turns off, they are a rule with a citation.
+  const legalE=entities.filter(e=>e.legal);
+  const autoE=entities.filter(e=>!e.legal&&e.kind!=='candidate'&&e.kind!=='manual'&&e.kind!=='keep');
+  const manualE=entities.filter(e=>!e.legal&&e.kind==='manual');
+  const candE=entities.filter(e=>!e.legal&&e.kind==='candidate');
+  const keepE=entities.filter(e=>!e.legal&&e.kind==='keep');
   const total=entities.filter(isOn).length;
   $('piiCount').textContent= total? t.cntUse(total):'';
   document.querySelectorAll('#bulkBtns button').forEach(b=>b.disabled=!total);
@@ -2475,6 +2623,7 @@ function renderList(){
     html+=`<button class="more-cats" id="moreCats">${showAllCats? t.moreHide : t.moreShow(misses.length)}</button>`;
     if(showAllCats) html+=misses.map(ty=>catRowHtml(ty,[])).join('');
   }
+  if(legalE.length)  html=sectionHtml('legal', t.jpLegalSection, legalE)+html;
   if(manualE.length) html+=sectionHtml('manual', t.manualSection, manualE);
   if(candE.length)   html+=sectionHtml('candidate', t.candSection, candE);
   if(keepE.length)   html+=sectionHtml('keep', t.keepSection, keepE);
@@ -2492,7 +2641,10 @@ $('piiList').addEventListener('click',e=>{
   if(cm){
     const type=cm.closest('[data-cat-seg]').dataset.catSeg;
     catDefault[type]=cm.dataset.cmode;
-    entities.filter(x=>x.type===type).forEach(x=>x.mode=cm.dataset.cmode);
+    // Legal-preset entities are excluded: this is a per-TYPE control and the
+    // statutory bands share the catch-all types. Releasing them has to be a
+    // deliberate, individual act.
+    entities.filter(x=>x.type===type&&!x.legal).forEach(x=>x.mode=cm.dataset.cmode);
     renderAll(); return;
   }
   const b=e.target.closest('button[data-id]'); if(!b) return;
@@ -2501,14 +2653,19 @@ $('piiList').addEventListener('click',e=>{
   // is the user's call, but it must not be a silent one — the usual failure is
   // a rejected submission and a second round of sending the same document.
   if(ent.kind==='keep' && b.dataset.mode!=='ok') toast(T().jpKeepWarn);
+  // The inverse: releasing a statutory band. Also the user's call, also not silent.
+  if(ent.legal && b.dataset.mode==='ok') toast(T().jpLegalWarn);
   ent.mode=b.dataset.mode; renderAll();
 });
 $('bulkBtns').addEventListener('click',e=>{
   const b=e.target.closest('button[data-mode]'); if(!b||b.disabled) return;
   const hidesKeep = b.dataset.mode!=='ok' && entities.some(x=>isOn(x)&&x.kind==='keep');
-  entities.filter(isOn).forEach(x=>x.mode=b.dataset.mode); renderAll();
-  toast(hidesKeep? T().jpKeepWarn : b.dataset.mode==='ok'?T().tBulkOk:T().tBulkNo);
+  const skipsLegal = b.dataset.mode==='ok' && entities.some(x=>x.legal);
+  // Bulk HIDE may touch legal bands (it only ever covers more); bulk SHOW may not.
+  entities.filter(x=>isOn(x)&&(b.dataset.mode!=='ok'||!x.legal)).forEach(x=>x.mode=b.dataset.mode); renderAll();
+  toast(hidesKeep? T().jpKeepWarn : skipsLegal? T().jpLegalWarn : b.dataset.mode==='ok'?T().tBulkOk:T().tBulkNo);
 });
+$('jpMnConfirm').addEventListener('change',e=>jpSetMnConfirmed(e.target.checked));
 
 /* ───────── AI scan (text-only; maps found strings back to boxes) ───────── */
 $('btnAI').addEventListener('click',runAI);
diff --git a/test/safe/fixtures/jp/gen.py b/test/safe/fixtures/jp/gen.py
index bfedfbb..e20c939 100644
--- a/test/safe/fixtures/jp/gen.py
+++ b/test/safe/fixtures/jp/gen.py
@@ -75,6 +75,23 @@ def finalize(img, path_base, boxes, meta):
     sh = Image.new("RGB", photo.size, (0,0,0)); photo = Image.blend(photo, sh, 0.06)
     photo.save(path_base + ".jpg", quality=82)                        # 촬영풍 (회전·흐림·어두움)
     c = canvas.Canvas(path_base + ".pdf", pagesize=(W*0.5, H*0.5)); c.drawImage(path_base + ".png", 0, 0, W*0.5, H*0.5); c.save()
+    # The purpose tables below are written once per DOCUMENT but each variant has
+    # its own fields (kouki has 被保険者番号 and no 記号/番号/枝番; only kenpo has
+    # 事業所名称). An expectation naming a box this variant does not have used to be
+    # reported as "skipped" by the harness — i.e. not checked, while still printing
+    # green. The harness now FAILS on a missing key, so the table has to be pruned
+    # to this variant here (Codex 5-5).
+    meta = dict(meta)
+    if "purposes" in meta:
+        pruned = {}
+        for pk, P in meta["purposes"].items():
+            Q = dict(P)
+            for kind in ("mask", "recommend", "optional", "keep"):
+                v = Q.get(kind)
+                if isinstance(v, list):
+                    Q[kind] = [k for k in v if k == "ALL" or k in boxes]
+            pruned[pk] = Q
+        meta["purposes"] = pruned
     spec = {"file": os.path.basename(path_base), "size": [W, H], "boxes_png": boxes, **meta,
             "note": "jpg는 회전·흐림 적용으로 박스 좌표 불일치 → 탐지는 OCR 좌표로 재계산, png/pdf 좌표만 골든 비교"}
     json.dump(spec, open(path_base + ".specs.json", "w"), ensure_ascii=False, indent=1)
@@ -129,7 +146,9 @@ def license_card(side):
         label_val(d, 40, y, "番号", "第 " + license_no() + " 号", 120, 26, boxes, "license_no"); y += 50
         label_val(d, 40, y, "種類", "普通 / 原付", 120, 22, boxes, "types")
         d.text((40, H-80), "（公安委員会名・公印・IC表示は意図的に省略）", font=F(16), fill=(120,120,120))
-        purposes = {"本人確認提出": {"mask": [], "optional": ["license_no"], "keep": ["name","birth","address","expiry","photo"], "legal_basis": "提出先指示優先。番号マスキングは任意（KYCで必須とする提出先あり）"}}
+        # 免許証番号 is must-keep for 本人確認提出 per the legal matrix (照合に必要と
+        # する提出先が多い); it is `optional` only under 相談用共有.
+        purposes = {"本人確認提出": {"mask": [], "optional": [], "keep": ["name","birth","address","expiry","photo","license_no"], "legal_basis": "提出先指示優先。免許証番号は本人確認提出では must-keep（照合に必要とする提出先が多い）、相談用共有では既定OFFで選択可"}}
     else:
         d.text((40, 40), "運転免許証 裏面（架空・図式）", font=F(30, True), fill=(30,30,30))
         d.text((40, 110), "備考欄（住所・氏名等の変更記載）", font=F(22), fill=(90,90,90))
@@ -204,7 +223,9 @@ def juminhyo(variant):
     purposes = {
         "本人確認提出": {"mask": [k for k in boxes if k.endswith("my_number") or k=="jumin_code"], "recommend": [k for k in boxes if "honseki" in k or "hittosha" in k or k.startswith("m2_") or k.startswith("m3_")],
                      "keep": ["address","m1_name","m1_birth"], "legal_basis": "個人番号は番号法で収集制限／本籍・他世帯員は提出先指示で不要が多い", "source": "https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"},
-        "個人番号手続": {"mask": [k for k in boxes if "honseki" in k], "keep": [k for k in boxes if k.endswith("my_number")], "legal_basis": "個人番号記載が目的の提出"}}
+        # 本籍 under a My Number filing is `optional` (default OFF): the legal matrix
+        # has no source for "unnecessary in a 個人番号関係事務", so it is offered, not banded.
+        "個人番号手続": {"mask": [], "optional": [k for k in boxes if "honseki" in k], "keep": [k for k in boxes if k.endswith("my_number")], "legal_basis": "個人番号記載が目的の提出。本籍は不要という出典がないため既定OFF（選択可）"}}
     finalize(img, f"{OUT}/juminhyo/{variant}", boxes, {"doc":"住民票の写し","variant":variant,"purposes":purposes})
 
 if __name__ == "__main__":
diff --git a/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json b/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json
index 7b7d747..eb615e6 100644
--- a/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json
+++ b/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json
@@ -1,6 +1,13 @@
 {
-  "version": "2026-10-21",
+  "version": "2026-10-21b",
   "scope": "SafeFile JP 알파 4종. 규칙은 제출 목적(purpose)별. 출처 없는 규칙은 verified=false로 표기하고 자동 마스킹 금지.",
+  "_schema": {
+    "rule": "{field: 사람이 읽는 필드명, fields: [코드 필드 키], mask_when: [purpose], must_keep_when: [purpose], optional_when: [purpose], level, legal_basis, source, verified}",
+    "derivation": "(doc, code field, purpose) → level: purpose ∈ must_keep_when → keep · purpose ∈ mask_when → level 토큰 · purpose ∈ optional_when → optional · 그 외 → null(UI에 내지 않음). 한 purpose가 두 목록에 동시에 들어가면 오류다.",
+    "level_tokens": "auto → auto · auto_with_purpose_gate → gate · recommend → recommend · optional → optional · keep → keep",
+    "invariant": "verified=false 인 규칙은 auto·gate 를 가질 수 없다. 출처 없는 판단이 스스로 픽셀을 지우면 안 된다. test/safe/check_matrix.mjs 가 이 표와 public/safe/index.html 의 JP_RULES 를 (doc, field, purpose) 전수 대조하고 이 불변식을 강제한다.",
+    "optional_when_basis": "optional 은 「既定OFF・選択可」 — 법적 주장이 아니라 UI 제공이다. 제출 목적이 그 항목을 요구하지 않는 조합(특히 相談用共有)에서 사용자가 자기 정보를 가릴 수단을 잃지 않도록 명시한다. 출처가 없으므로 자동이 될 수 없다."
+  },
   "purposes": {
     "identity_submit": "本人確認書類として提出（銀行・カード・通信・フリマ・賃貸）",
     "my_number_procedure": "個人番号関係事務（税・社会保障・勤務先提出）",
@@ -14,12 +21,24 @@
       "fields_common": ["氏名", "生年月日", "性別", "住所", "資格取得年月日", "有効期限", "保険者番号", "保険者名", "記号/番号/枝番 または 被保険者番号"],
       "fields_issuer_specific": ["事業所名称", "二次元コード", "一部負担金割合", "自己負担限度額区分"],
       "rules": [
-        {"field": "保険者番号・記号・番号・枝番・被保険者番号", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": [], "level": "auto",
-         "legal_basis": "健康保険法等 告知要求制限（2020-10-01施行）: 医療保険事務以外の目的での告知要求を原則禁止。提出先が受領する場合もマスキングを求める運用",
+        {"field": "保険者番号・記号・番号・枝番・被保険者番号",
+         "fields": ["hokensha_bango", "kigo", "bango", "edaban", "hihokensha_bango"],
+         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": [], "level": "auto",
+         "legal_basis": "健康保険法等 告知要求制限（2020-10-01施行）: 医療保険事務以外の目的での告知要求を原則禁止。提出先が受領する場合もマスキングを求める運用。my_number_procedure は明示しない（医療保険関係事務で番号が必要な例外の有無が確認不可） → null",
          "source": ["https://www.mhlw.go.jp/stf/newpage_13989.html", "https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf", "https://www.kyosai.metro.tokyo.jp/assets/84b47fd406a8378372a6015863f83bc93c0c8a75.pdf"], "verified": true},
-        {"field": "二次元コード", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "level": "auto", "legal_basis": "番号を判読可能なため同一扱い（大阪府・千葉市運用）", "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"], "verified": true},
-        {"field": "性別", "mask_when": ["identity_submit"], "level": "recommend", "legal_basis": "法定ではない。民間KYC事業者の運用（SoftBank, PayPay銀行等）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
-        {"field": "氏名・生年月日・住所・有効期限", "mask_when": [], "must_keep_when": ["identity_submit", "bid_attachment"], "level": "keep", "legal_basis": "本人特定事項。マスキングすると受付不可", "source": ["https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html"], "verified": true}
+        {"field": "二次元コード", "fields": ["qr"],
+         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "level": "auto",
+         "legal_basis": "番号を判読可能なため同一扱い（大阪府・千葉市運用）", "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"], "verified": true},
+        {"field": "性別", "fields": ["sex"], "mask_when": ["identity_submit"], "level": "recommend",
+         "legal_basis": "法定ではない。民間KYC事業者の運用（SoftBank, PayPay銀行等）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
+        {"field": "氏名・生年月日・住所・有効期限", "fields": ["name", "birth", "address", "expiry"],
+         "mask_when": [], "must_keep_when": ["identity_submit", "bid_attachment"], "optional_when": ["consult_share"], "level": "keep",
+         "legal_basis": "本人特定事項。マスキングすると受付不可。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）",
+         "source": ["https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html"], "verified": true},
+        {"field": "事業所名称・保険者名・資格取得年月日", "fields": ["jigyosho", "hokensha_name", "shikaku_date"],
+         "mask_when": [], "must_keep_when": ["identity_submit", "bid_attachment"], "optional_when": ["consult_share"], "level": "keep",
+         "legal_basis": "資格の有効性を提出先が照合する欄という運用判断。法定の must-keep ではなく出典もない（警告のみで、自動マスキング対象には決してしない）",
+         "source": [], "verified": false}
       ]
     },
     {
@@ -28,10 +47,20 @@
       "fields_back": ["備考欄（住所・氏名等の変更記載）", "臓器提供意思表示欄"],
       "note": "本籍は券面に印字されない（ICチップ内）",
       "rules": [
-        {"field": "裏面 備考欄（変更記載）", "mask_when": ["identity_submit", "consult_share"], "level": "recommend", "legal_basis": "旧住所等の不要情報。提出先指示優先（住所変更確認で裏面が必要な場合あり）", "source": ["https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true},
-        {"field": "臓器提供意思表示欄", "mask_when": ["identity_submit", "consult_share"], "level": "recommend", "legal_basis": "民間KYC運用（SoftBank: 臓器提供意思をマスキング）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
-        {"field": "番号(12桁)", "mask_when": ["consult_share"], "must_keep_when": ["identity_submit"], "level": "optional", "legal_basis": "個人識別符号（個人情報保護法施行令）。KYCでは照合に必要な提出先が多い", "source": [], "verified": false},
-        {"field": "氏名・生年月日・住所・有効期限・顔写真", "must_keep_when": ["identity_submit"], "level": "keep", "verified": true, "source": ["https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html"]}
+        {"field": "裏面 備考欄（変更記載）", "fields": ["biko_change"],
+         "mask_when": ["identity_submit", "consult_share"], "level": "recommend",
+         "legal_basis": "旧住所等の不要情報。提出先指示優先（住所変更確認で裏面が必要な場合あり）", "source": ["https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true},
+        {"field": "臓器提供意思表示欄", "fields": ["organ_donor"],
+         "mask_when": ["identity_submit", "consult_share"], "level": "recommend",
+         "legal_basis": "民間KYC運用（SoftBank: 臓器提供意思をマスキング）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
+        {"field": "番号(12桁)", "fields": ["license_no"],
+         "mask_when": ["consult_share"], "must_keep_when": ["identity_submit"], "level": "optional",
+         "legal_basis": "個人識別符号（個人情報保護法施行令）。KYCでは照合に必要な提出先が多い → 本人確認提出では must-keep、相談用共有では既定OFFで選択可",
+         "source": [], "verified": false},
+        {"field": "氏名・生年月日・住所・有効期限・顔写真", "fields": ["name", "birth", "address", "expiry"],
+         "must_keep_when": ["identity_submit"], "optional_when": ["consult_share"], "level": "keep",
+         "legal_basis": "本人特定事項。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）。顔写真は検出規則がないため fields に含まない",
+         "verified": true, "source": ["https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html"]}
       ]
     },
     {
@@ -40,23 +69,56 @@
       "fields_back": ["個人番号", "氏名", "生年月日(要確認)", "二次元コード"],
       "unverified": ["裏面の生年月日印字有無"],
       "rules": [
-        {"field": "裏面全体", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": ["my_number_procedure"], "level": "auto_with_purpose_gate",
-         "legal_basis": "番号法: 法令で認められた者・目的以外での個人番号の収集・保管禁止。身元確認目的では裏面を提出しない", "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/", "https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true},
-        {"field": "表面 性別・臓器提供意思表示欄", "mask_when": ["identity_submit"], "level": "recommend", "legal_basis": "民間KYC運用", "source": ["https://www.aspicjapan.org/asu/article/6908"], "verified": true},
-        {"field": "表面 氏名・住所・生年月日・有効期限・顔写真", "must_keep_when": ["identity_submit", "my_number_procedure"], "level": "keep", "verified": true, "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"]}
+        {"field": "裏面全体", "fields": ["back_all", "my_number", "qr"],
+         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": ["my_number_procedure"], "level": "auto_with_purpose_gate",
+         "legal_basis": "番号法: 法令で認められた者・目的以外での個人番号の収集・保管禁止。身元確認目的では裏面を提出しない。コード上は 裏面全体(back_all) / 個人番号(my_number) / 二次元コード(qr) の3キーに分解する（面全体の띠 + 番号そのもの + コード）が、規則はこの1条である",
+         "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/", "https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true,
+         "gate_requires_confirmation": "my_number_procedure への解除は目的ドロップダウンだけでは足りない。提出先が法定の個人番号関係事務を行うという確認（チェックボックス1つ）を要求する — PPC FAQ は「意図せず見た」と「複写・記録」を区別するが、どちらも提出先の適法性を前提にしている"},
+        {"field": "表面 性別・臓器提供意思表示欄", "fields": ["sex", "organ_donor"],
+         "mask_when": ["identity_submit"], "level": "recommend", "legal_basis": "民間KYC運用", "source": ["https://www.aspicjapan.org/asu/article/6908"], "verified": true},
+        {"field": "表面 氏名・住所・生年月日・有効期限・顔写真", "fields": ["name", "birth", "address", "expiry"],
+         "must_keep_when": ["identity_submit", "my_number_procedure"], "optional_when": ["consult_share"], "level": "keep",
+         "legal_basis": "本人特定事項。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）。顔写真は検出規則がないため fields に含まない",
+         "verified": true, "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"]}
       ]
     },
     {
       "id": "juminhyo", "name": "住民票の写し",
       "variants": ["世帯全員/一部", "個人番号 あり/なし", "本籍・筆頭者 あり/なし", "外国人住民（国籍・在留資格・在留期間・在留カード番号）", "住民票コード付（窓口のみ）"],
       "rules": [
-        {"field": "個人番号", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": ["my_number_procedure"], "level": "auto_with_purpose_gate", "legal_basis": "番号法 収集制限。本人確認目的なら個人番号なしの住民票を取り直すのが原則", "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"], "verified": true},
-        {"field": "住民票コード", "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "level": "auto", "legal_basis": "住民基本台帳法 利用制限（個人識別符号）", "source": [], "verified": false},
-        {"field": "本籍・筆頭者", "mask_when": ["identity_submit", "consult_share"], "level": "recommend", "legal_basis": "民間KYC運用（SoftBank: 住民票の本籍をマスキング）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
-        {"field": "本人以外の世帯員", "mask_when": ["identity_submit", "consult_share"], "level": "recommend", "legal_basis": "第三者情報。提出先が世帯全員を要求する場合は維持", "source": [], "verified": false},
-        {"field": "氏名・生年月日・住所・発行日・発行者", "must_keep_when": ["identity_submit", "bid_attachment"], "level": "keep", "verified": true, "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"]}
+        {"field": "個人番号", "fields": ["my_number"],
+         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": ["my_number_procedure"], "level": "auto_with_purpose_gate",
+         "legal_basis": "番号法 収集制限。本人確認目的なら個人番号なしの住民票を取り直すのが原則", "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"], "verified": true,
+         "gate_requires_confirmation": "mynumber_card 裏面全体と同じ確認を要求する"},
+        {"field": "住民票コード", "fields": ["jumin_code"],
+         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "level": "recommend",
+         "legal_basis": "住民基本台帳法 利用制限（個人識別符号）と理解しているが条文・運用の出典を確保できていない → verified=false。既定ON で帯を引くが『自動（auto）』とは呼ばない",
+         "source": [], "verified": false},
+        {"field": "本籍・筆頭者", "fields": ["honseki", "hittosha"],
+         "mask_when": ["identity_submit", "consult_share"], "optional_when": ["my_number_procedure", "bid_attachment"], "level": "recommend",
+         "legal_basis": "民間KYC運用（SoftBank: 住民票の本籍をマスキング）。個人番号手続・入札添付で不要という出典はないため既定ONにはしない（既定OFFで選択可）",
+         "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
+        {"field": "本人以外の世帯員", "fields": ["setaiin"],
+         "mask_when": ["identity_submit", "consult_share"], "optional_when": ["my_number_procedure", "bid_attachment"], "level": "recommend",
+         "legal_basis": "第三者情報。提出先が世帯全員を要求する場合は維持", "source": [], "verified": false},
+        {"field": "氏名・生年月日・住所・発行日・発行者", "fields": ["name", "birth", "address", "issuer"],
+         "must_keep_when": ["identity_submit", "bid_attachment"], "optional_when": ["consult_share"], "level": "keep",
+         "legal_basis": "本人特定事項と証明書の成立要件。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）。⚠ 既知の空白: 発行日 も 発行者(issuer) も検出規則がない — ラベルを持たない行（「見本市長 架空 太郎（公印省略）」）なので、ラベル錨ではなく 市長|区長|町長|村長 のヒューリスティックが要る。この keep 規則は現状 警告を生成できない（s3b 백로그 B-15）",
+         "verified": true, "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"]}
       ]
     }
   ],
-  "levels": {"auto": "文書分類+ラベル一致で自動黒塗り", "auto_with_purpose_gate": "目的選択後に自動（別目的では解除）", "recommend": "既定ON・解除可", "optional": "既定OFF・選択可", "keep": "黒塗り禁止（警告）"}
+  "general_jp": {
+    "_why": "문서 종류와 무관하게 네 문서 전부에 적용되는 두 규칙. 어느 문서도 증명해야 하는 내용이 아니므로 항상 제공(optional)하고, 공유의 목적이 상담일 때만 기본 ON(recommend). 법적 출처가 없으므로 recommend 이하만 — auto·gate 는 금지된다.",
+    "applies_to": ["shikaku_kakuninsho", "unten_menkyo", "mynumber_card", "juminhyo"],
+    "rules": [
+      {"field": "文書内の自由記述の住所（ラベルのない住所）", "fields": ["address_loose"],
+       "mask_when": ["consult_share"], "optional_when": ["identity_submit", "my_number_procedure", "bid_attachment"], "level": "recommend",
+       "legal_basis": "ラベル付きの 住所 とは別キー。備考欄や自由記述に残った旧住所など、提出先が要求していない住所。出典なし", "source": [], "verified": false},
+      {"field": "電話・FAX", "fields": ["tel"],
+       "mask_when": ["consult_share"], "optional_when": ["identity_submit", "my_number_procedure", "bid_attachment"], "level": "recommend",
+       "legal_basis": "4文書のいずれも電話番号を証明事項として持たない。出典なし", "source": [], "verified": false}
+    ]
+  },
+  "levels": {"auto": "文書分類+ラベル一致で自動黒塗り", "auto_with_purpose_gate": "目的選択後に自動（別目的では解除。解除には確認が必要）", "recommend": "既定ON・解除可", "optional": "既定OFF・選択可", "keep": "黒塗り禁止（警告）", "null": "この目的では UI に出さない（매트릭스가 명시하지 않은 조합）"}
 }
diff --git a/test/safe/run.mjs b/test/safe/run.mjs
index 13f3669..f4decf7 100644
--- a/test/safe/run.mjs
+++ b/test/safe/run.mjs
@@ -16,6 +16,7 @@
  * Usage: node run.mjs [--only 7_resume_dark.pdf]  (exit 0 = all pass)
  */
 import { chromium } from 'playwright';
+import { spawnSync } from 'node:child_process';
 import http from 'node:http';
 import fs from 'node:fs';
 import path from 'node:path';
@@ -39,8 +40,12 @@ function startServer() {
     const srv = http.createServer((req, res) => {
       let p = decodeURIComponent(req.url.split('?')[0]);
       if (p === '/') p = '/index.html';
-      const fp = path.join(PUBLIC, p);
-      if (!fp.startsWith(PUBLIC) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end('nf'); return; }
+      // `/__fx/...` serves the fixture tree, so the page can read fixture images
+      // back as <img> (used to compose the multi-page PDF fixture at run time).
+      const root = p.startsWith('/__fx/') ? FIXTURES : PUBLIC;
+      if (p.startsWith('/__fx/')) p = p.slice(5);
+      const fp = path.join(root, p);
+      if (!fp.startsWith(root) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end('nf'); return; }
       res.writeHead(200, { 'content-type': MIME[path.extname(fp)] || 'application/octet-stream' });
       fs.createReadStream(fp).pipe(res);
     });
@@ -118,11 +123,102 @@ const PAGE_HELPERS = () => {
     }
     return false;
   };
+  /* ── ink coverage (replaces the 60% area gate on number fields) ──
+     A 60% area figure says HOW MUCH of a box was painted, never WHERE: the
+     kouki fixture measured 96% with its leading digit fully outside the band
+     (Codex 5-3, and we had already recorded it). So for a field whose value is
+     a number, the question is per-GLYPH: take the ink inside the expected box,
+     label its connected components, and require every component to be covered.
+     Threshold 60 (not the detector's 40) deliberately excludes the fixtures'
+     見本 watermark — composited it sits ~48 off the background, and a band is
+     not required to cover a watermark. */
+  window.__inkCover = function (rect) {
+    const p = pages[rect.pi]; if (!p) return null;
+    const CW = p.canvas.width, CH = p.canvas.height;
+    const x0 = Math.max(0, Math.floor(rect.x)), y0 = Math.max(0, Math.floor(rect.y));
+    const x1 = Math.min(CW, Math.ceil(rect.x + rect.w)), y1 = Math.min(CH, Math.ceil(rect.y + rect.h));
+    const W = x1 - x0, H = y1 - y0;
+    if (W <= 0 || H <= 0) return { components: 0, inkPx: 0, uncovered: 0, worst: 1 };
+    const ctx = p.canvas.getContext('2d', { willReadFrequently: true });
+    const d = ctx.getImageData(x0, y0, W, H).data, bg = jpPageBg(p);
+    const ink = new Uint8Array(W * H);
+    let inkPx = 0;
+    for (let i = 0; i < W * H; i++) {
+      if (Math.abs(d[i * 4] - bg[0]) > 60 || Math.abs(d[i * 4 + 1] - bg[1]) > 60 || Math.abs(d[i * 4 + 2] - bg[2]) > 60) { ink[i] = 1; inkPx++; }
+    }
+    const mr = window.__maskRects().filter(r => r.pi === rect.pi);
+    const covered = (px, py) => mr.some(r => px >= r.x && px <= r.x + r.w && py >= r.y && py <= r.y + r.h);
+    const seen = new Uint8Array(W * H);
+    let components = 0, uncovered = 0, worst = 1;
+    for (let i = 0; i < W * H; i++) {
+      if (!ink[i] || seen[i]) continue;
+      const st = [i]; seen[i] = 1; let n = 0, cov = 0;
+      while (st.length) {
+        const k = st.pop(), kx = k % W, ky = (k - kx) / W;
+        n++; if (covered(x0 + kx + 0.5, y0 + ky + 0.5)) cov++;
+        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
+          const nx = kx + dx, ny = ky + dy;
+          if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
+          const nk = ny * W + nx;
+          if (ink[nk] && !seen[nk]) { seen[nk] = 1; st.push(nk); }
+        }
+      }
+      // Specks (anti-aliasing debris, watermark bleed) are not glyphs.
+      if (n < 6) continue;
+      components++;
+      const f = cov / n;
+      if (f < worst) worst = f;
+      if (f < 0.99) uncovered++;
+    }
+    return { components, inkPx, uncovered, worst };
+  };
+  /* Every entity carrying `field`, with the facts require_banded is actually
+     about: is it located, is its category ON, is it not 'ok', and do the rects
+     it would paint ACTUALLY appear in the active mask-rect list? The old
+     assertion read `mode !== 'ok'` alone, which stays true for an entity whose
+     category is off or whose boxes are empty (Codex 5-5). */
+  window.__fieldBands = function (field) {
+    const mr = window.__maskRects();
+    const same = (a, b) => Math.abs(a.x - b.x) < 0.01 && Math.abs(a.y - b.y) < 0.01 && Math.abs(a.w - b.w) < 0.01 && Math.abs(a.h - b.h) < 0.01;
+    return entities.filter(e => e.jp && e.jp.field === field).map(e => {
+      const rects = [];
+      for (let pi = 0; pi < pages.length; pi++) for (const l of mergeLineBoxes(e.boxes || [], pi)) { const r = bandRect(l); rects.push({ pi, ...r }); }
+      return { level: e.jp.level, note: e.jp.note, page: e.jp.page, doc: e.jp.doc, side: e.jp.side,
+        kind: e.kind, mode: e.mode, legal: !!e.legal, located: !!(e.boxes && e.boxes.length), on: isOn(e),
+        rects: rects.length, inMask: rects.length > 0 && rects.every(r => mr.some(m => m.pi === r.pi && same(m, r))) };
+    });
+  };
   window.__jpState = function () {
-    return { cls: jpState.cls && { doc: jpState.cls.doc, side: jpState.cls.side || null, score: jpState.cls.score },
-      purpose: jpState.purpose, pw: pages.map(p => p.w),
-      fields: entities.filter(e => e.jp).map(e => ({ field: e.jp.field, level: e.jp.level, note: e.jp.note, kind: e.kind, mode: e.mode })) };
+    return { cls: jpState.cls && { doc: jpState.cls.doc, side: jpState.cls.side || null, score: jpState.cls.score, low: !!jpState.cls.low },
+      purpose: jpState.purpose, warn: jpState.warn, mnConfirmed: jpState.mnConfirmed,
+      pageCls: jpState.pageCls.map(c => c && { doc: c.doc, side: c.side || null, low: !!c.low }),
+      warnShown: (() => { const el = document.getElementById('jpWarn'); return !!el && el.style.display !== 'none' && !!el.textContent.trim(); })(),
+      mnBoxShown: (() => { const el = document.getElementById('jpMnWrap'); return !!el && el.style.display !== 'none'; })(),
+      pw: pages.map(p => p.w),
+      fields: entities.filter(e => e.jp).map(e => ({ field: e.jp.field, level: e.jp.level, note: e.jp.note, page: e.jp.page, kind: e.kind, mode: e.mode, legal: !!e.legal, on: isOn(e) })) };
+  };
+  // Field labels of every ACTIVE auto entity — the allowlist assertion's input.
+  window.__autoFields = function () {
+    return entities.filter(e => e.kind === 'auto').map(e => e.jp ? e.jp.field : '(regex:' + e.type + ')');
+  };
+  /* Turn every general category OFF. A legal-preset band must survive this.
+     catEnabled is module-level state that resetAll() and a fresh file load do
+     NOT restore, so this hands back a restore function — the first version of
+     this helper left every category off for the remaining 300 assertions and
+     turned 14 of them red. */
+  window.__catSnapshot = null;
+  window.__allCatsOff = function () {
+    window.__catSnapshot = { ...catEnabled };
+    for (const t of Object.keys(catEnabled)) catEnabled[t] = false;
+    renderAll();
+    return Object.keys(catEnabled).filter(t => catEnabled[t] !== false);
   };
+  window.__restoreCats = function () {
+    if (!window.__catSnapshot) return false;
+    for (const t of Object.keys(window.__catSnapshot)) catEnabled[t] = window.__catSnapshot[t];
+    window.__catSnapshot = null; renderAll(); return true;
+  };
+  window.__setMnConfirm = function (v) { jpSetMnConfirmed(v); };
   window.__isCandidateExact = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value) === n); };
   window.__isCandidateContains = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value).includes(n)); };
   // default mode of the candidate whose value contains v (null if not a candidate)
@@ -149,12 +245,21 @@ const PAGE_HELPERS = () => {
   };
 };
 
-// `jp/...` paths resolve under fixtures/, everything else under testdocs/.
-const docPath = file => file.startsWith('jp/') ? path.join(FIXTURES, file) : path.join(DOCS, file);
+// `jp/...` paths resolve under fixtures/, `gen/...` under out/gen (built at run
+// time from committed fixtures — no new binaries in the repo), everything else
+// under testdocs/.
+const docPath = file => file.startsWith('jp/') ? path.join(FIXTURES, file)
+  : file.startsWith('gen/') ? path.join(OUT, file) : path.join(DOCS, file);
 async function loadDoc(page, file, ocr) {
   await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
   await page.setInputFiles('#fileInput', docPath(file));
-  await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0, { timeout: ocr ? 240000 : 40000 });
+  // `pages.length > 0` is NOT "loaded": pages are pushed one at a time, so on a
+  // multi-page OCR document it goes true while page 2 is still in Tesseract —
+  // and everything measured after it describes half a document. afterLoad()
+  // reveals #docWrap as its last step, so that is the completion signal.
+  await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0
+      && document.getElementById('docWrap').style.display === 'flex',
+    { timeout: ocr ? 300000 : 40000 });
   await page.waitForTimeout(ocr ? 800 : 400);
   await page.evaluate(PAGE_HELPERS);
 }
@@ -273,8 +378,17 @@ async function checkOutput(page, doc, fmt) {
   const tag = `OUT_${fmt.toUpperCase()}`;
   try {
     await page.evaluate(f => { const r = document.querySelector(`input[name=fmt][value="${f}"]`); if (r) r.checked = true; }, fmt);
-    // force at least one masked, located entity so Make is enabled
-    await page.evaluate(() => { const e = entities.find(x => isOn(x) && x.boxes && x.boxes.length); if (e) e.mode = 'no'; renderAll(); });
+    // Force at least one masked, located entity so Make is enabled — preferring
+    // an AUTO one. Taking the first ON entity happened to pick a `keep` field on
+    // some JP fixtures, so the file we then inspected for leaks was one where we
+    // had covered a value the recipient needs (Codex 5-5 / instruction 11).
+    await page.evaluate(() => {
+      const ok = x => isOn(x) && x.boxes && x.boxes.length;
+      const e = entities.find(x => ok(x) && x.kind === 'auto')
+             || entities.find(x => ok(x) && x.kind !== 'keep')
+             || entities.find(ok);
+      if (e) e.mode = 'no'; renderAll();
+    });
     await page.click('#btnMake');
     await page.waitForSelector('#result', { state: 'visible', timeout: 60000 });
     const dl = await Promise.all([
@@ -401,10 +515,16 @@ async function checkCandidateDedup(page) {
    both the automatic and the recommended strength, and those are different
    promises. specs.json carries the key→level mapping (jp_auto_fields) so the
    harness derives it independently of the app it is testing. */
-const JP_COVER_MIN = 0.6;      // a band must cover this much of a value/box
+const JP_COVER_MIN = 0.6;      // a band must cover this much of a non-numeric box
 const JP_KEEP_MAX = 0.10;      // a keep field may not be grazed by more than this
 function jpFieldOf(key) { return key.replace(/^m\d+_/, ''); }
+/* Number fields get the per-glyph ink test instead of the area fraction. These
+   are the fields whose whole value is a digit string, so a single surviving
+   character is a leak — and the area gate cannot see that (Codex 5-3). */
+const JP_NUMERIC = new Set(['hokensha_bango', 'kigo', 'bango', 'edaban', 'hihokensha_bango',
+  'my_number', 'jumin_code', 'license_no']);
 async function jpCheckBox(page, doc, cat, key, rect, kind) {
+  const field = jpFieldOf(key);
   const items = await page.evaluate(r => window.__itemsIn(r), rect);
   let frac, what;
   if (items.length) {
@@ -416,12 +536,28 @@ async function jpCheckBox(page, doc, cat, key, rect, kind) {
     frac = await page.evaluate(r => window.__coverage(r), rect); what = `area ${(frac * 100).toFixed(0)}%`;
   }
   if (kind === 'keep') { rec(doc, 'JP_KEEP', key, `<=${JP_KEEP_MAX * 100}%`, what, frac <= JP_KEEP_MAX); return; }
-  const covered = frac >= JP_COVER_MIN;
-  if (kind === 'mask') { rec(doc, 'JP_MASK', key, `>=${JP_COVER_MIN * 100}%`, what, covered); return; }
+  // Covered? For a number box, "covered" means every ink component is covered.
+  let covered = frac >= JP_COVER_MIN, how = what;
+  if (JP_NUMERIC.has(field) && (kind === 'mask' || kind === 'candidate' || kind === 'mask_or_candidate')) {
+    const ic = await page.evaluate(r => window.__inkCover(r), rect);
+    const comps = ic ? ic.components : 0;
+    how = ic ? `${comps} comp, worst ${(ic.worst * 100).toFixed(0)}%` : 'no-canvas';
+    // Zero components would make this assertion vacuous: a number box has ink.
+    covered = comps > 0 && ic.uncovered === 0;
+    if (kind === 'mask') { rec(doc, 'JP_INK', key, 'all glyphs covered', comps ? how : 'NO INK FOUND', covered); return; }
+  }
+  if (kind === 'mask') { rec(doc, 'JP_MASK', key, `>=${JP_COVER_MIN * 100}%`, how, covered); return; }
   const cand = await page.evaluate(r => window.__candidateOver(r), rect);
-  if (kind === 'candidate') { rec(doc, 'JP_CANDIDATE', key, 'surfaced', cand ? (covered ? 'candidate+banded' : 'candidate') : 'MISSING', cand); return; }
+  if (kind === 'candidate') {
+    // A recommend-level candidate is default ON, so it is both surfaced AND
+    // banded; a number field has to pass the ink test in that case.
+    const banded = frac > JP_KEEP_MAX;
+    const ok = cand && (!banded || covered);
+    rec(doc, 'JP_CANDIDATE', key, 'surfaced(+covered if banded)',
+      cand ? (banded ? (covered ? 'candidate+covered' : 'BANDED BUT LEAKING ' + how) : 'candidate') : 'MISSING', ok); return;
+  }
   if (kind === 'mask_or_candidate') {
-    rec(doc, 'JP_MASK_OR_CAND', key, 'banded or candidate', covered ? 'banded' : cand ? 'candidate' : 'NEITHER', covered || cand); return;
+    rec(doc, 'JP_MASK_OR_CAND', key, 'banded(+covered) or candidate', covered ? 'banded ' + how : cand ? 'candidate' : 'NEITHER ' + how, covered || cand); return;
   }
   if (kind === 'optional') {   // detected, offered, and OFF until the user says so
     rec(doc, 'JP_OPTIONAL', key, 'offered+clear', cand ? (frac <= JP_KEEP_MAX ? 'offered+clear' : 'OFFERED BUT BANDED') : 'MISSING', cand && frac <= JP_KEEP_MAX);
@@ -432,10 +568,20 @@ async function checkJpDoc(page, spec) {
   const autoFields = (SPECS.jp_auto_fields || {})[spec.expect_doc] || [];
   const mocFields = SPECS.jp_candidate_or_mask || [];
   for (const c of spec.cases) {
-    const tag = `${spec.doc} [${c.purpose}]`;
+    const tag = `${spec.doc} [${c.purpose}${c.label ? ' ' + c.label : ''}]`;
     await loadDoc(page, spec.doc, true);
     await page.evaluate(p => jpSetPurpose(p), c.purpose);
+    // Releasing a 個人番号 band needs the purpose AND the confirmation. A case
+    // that expects the release has to say so — which is itself the assertion
+    // that the dropdown alone does not open the gate (the `confirm_mynumber:
+    // false` case below proves the other direction).
+    if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
     const st = await page.evaluate(() => window.__jpState());
+    if (c.expect_warn != null)
+      rec(tag, 'JP_WARN', 'blocking banner', c.expect_warn ? 'shown' : 'absent',
+        st.warnShown ? 'shown(' + st.warn + ')' : 'absent', st.warnShown === !!c.expect_warn);
+    if (c.confirm_mynumber != null)
+      rec(tag, 'JP_MN_BOX', 'confirmation checkbox', 'shown', st.mnBoxShown ? 'shown' : 'ABSENT', st.mnBoxShown);
     rec(tag, 'JP_CLASS', spec.expect_doc + (spec.expect_side ? '/' + spec.expect_side : ''), 'classified',
       st.cls ? st.cls.doc + (st.cls.side ? '/' + st.cls.side : '') + ' sc=' + st.cls.score : 'NOT classified',
       !!st.cls && st.cls.doc === spec.expect_doc && (!spec.expect_side || st.cls.side === spec.expect_side));
@@ -450,17 +596,48 @@ async function checkJpDoc(page, spec) {
     // the 미탐 0 gate is actually about.
     const got = new Set(st.fields.map(f => f.field));
     for (const f of (c.require_fields || [])) rec(tag, 'JP_FIELD', f, 'detected', got.has(f) ? 'detected' : 'MISSING', got.has(f));
+    // A band is only a band if the entity is located, its category is ON, its
+    // mode is not 'ok', AND the rect it paints is in the active mask-rect list.
     for (const f of (c.require_banded || [])) {
-      const on = st.fields.some(x => x.field === f && x.mode !== 'ok');
-      rec(tag, 'JP_BANDED', f, 'banded', on ? 'banded' : (got.has(f) ? 'DETECTED BUT CLEAR' : 'MISSING'), on);
+      const bs = await page.evaluate(x => window.__fieldBands(x), f);
+      const ok = bs.length > 0 && bs.every(b => b.located && b.on && b.mode !== 'ok' && b.inMask);
+      const why = !bs.length ? 'MISSING'
+        : bs.every(b => b.located && b.on && b.mode !== 'ok' && b.inMask) ? `banded ×${bs.length}`
+        : bs.map(b => !b.located ? 'NOT LOCATED' : !b.on ? 'CATEGORY OFF' : b.mode === 'ok' ? 'CLEAR' : 'NOT IN MASKRECTS').join('/');
+      rec(tag, 'JP_BANDED', f, 'located+on+in-maskrects', why, ok);
     }
     // The inverse of require_banded, and the half that makes a purpose-gate test
     // mean something: without it, "banded under 相談用共有" could be true simply
-    // because the field is banded under every purpose.
+    // because the field is banded under every purpose. Also asserts the rect is
+    // absent from the mask list, not merely that the mode string says 'ok'.
     for (const f of (c.require_clear || [])) {
-      const hits = st.fields.filter(x => x.field === f);
-      const clear = hits.length > 0 && hits.every(x => x.mode === 'ok');
-      rec(tag, 'JP_CLEAR', f, 'detected+clear', hits.length ? (clear ? 'detected+clear' : 'BANDED') : 'MISSING', clear);
+      const bs = await page.evaluate(x => window.__fieldBands(x), f);
+      const clear = bs.length > 0 && bs.every(b => b.mode === 'ok' && !b.inMask);
+      rec(tag, 'JP_CLEAR', f, 'detected+clear', !bs.length ? 'MISSING' : (clear ? `detected+clear ×${bs.length}` : 'BANDED'), clear);
+    }
+    // Legal-preset fields are not governed by the category checkboxes. Turn
+    // every category off and require the band to still be there.
+    for (const f of (c.require_legal || [])) {
+      const left = await page.evaluate(() => window.__allCatsOff());
+      const bs = await page.evaluate(x => window.__fieldBands(x), f);
+      const ok = left.length === 0 && bs.length > 0 && bs.every(b => b.legal && b.on && b.mode !== 'ok' && b.inMask);
+      rec(tag, 'JP_LEGAL', f, 'survives all-categories-off',
+        left.length ? 'cats still on: ' + left.join(',') : !bs.length ? 'MISSING'
+          : bs.every(b => b.legal && b.on && b.mode !== 'ok' && b.inMask) ? `banded ×${bs.length}` : 'DROPPED', ok);
+      // put the page back the way the rest of the case expects it
+      const restored = await page.evaluate(() => window.__restoreCats());
+      rec(tag, 'JP_LEGAL', f + ' (categories restored)', 'restored', restored ? 'restored' : 'NOT RESTORED', restored, true);
+      await loadDoc(page, spec.doc, true);
+      await page.evaluate(p => jpSetPurpose(p), c.purpose);
+      if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
+    }
+    // No auto entity outside the allowlist. A ceiling on the COUNT cannot tell
+    // "the right five" from "two right and three wrong" (Codex 5-6).
+    if (c.auto_allow) {
+      const af = await page.evaluate(() => window.__autoFields());
+      const bad = af.filter(f => !c.auto_allow.includes(f));
+      rec(tag, 'JP_AUTO_SET', 'auto fields ⊆ allowlist', c.auto_allow.join(',') || '(none)',
+        bad.length ? 'UNEXPECTED: ' + [...new Set(bad)].join(',') : (af.length ? [...new Set(af)].join(',') : '(none)'), bad.length === 0);
     }
     if (spec.geometry === false || c.geometry === false) continue;
 
@@ -469,16 +646,17 @@ async function checkJpDoc(page, spec) {
     const scale = st.pw[0] / fx.size[0];
     let checked = 0;
     const box = k => { const b = fx.boxes_png[k]; return b && { pi: 0, x: b[0] * scale, y: b[1] * scale, w: (b[2] - b[0]) * scale, h: (b[3] - b[1]) * scale }; };
-    const seen = new Set(); const skipped = [];
+    const seen = new Set();
     const run = async (keys, kindFor) => {
       for (const k of (keys || [])) {
         if (k === 'ALL' || seen.has(k)) continue;
         const r = box(k);
-        // The fixture's purpose list is shared across variants of the same
-        // document, so a key absent from THIS variant is not a case — but it is
-        // REPORTED, never silently dropped. A harness that quietly checks zero
-        // boxes prints the same green as one that checked forty.
-        if (!r) { skipped.push(k); continue; }
+        // An expectation naming a box this variant does not have is a FAULT in
+        // the expectation table, not a case to skip. It used to be "reported as
+        // skipped", which is a line of text nobody reads next to a green total
+        // (Codex 5-5). The variant tables are pruned at generation time now, so
+        // a missing key means the table and the fixture went out of sync.
+        if (!r) { rec(tag, 'JP_SPEC', k, 'box exists in fixture', 'NO SUCH BOX', false); continue; }
         seen.add(k);
         await jpCheckBox(page, tag, null, k, r, kindFor(k));
         checked++;
@@ -496,8 +674,11 @@ async function checkJpDoc(page, spec) {
                         : autoFields.includes(jpFieldOf(k)) ? 'mask' : 'candidate');
     await run(P.recommend, () => 'candidate');
     await run(P.optional, () => 'optional');
-    await run(P.keep === 'all' ? [] : P.keep, () => 'keep');
-    rec(tag, 'JP_COVERAGE', `boxes checked (skipped: ${skipped.join(',') || 'none'})`, '>0', String(checked), checked > 0);
+    // `keep: "all"` means every box on the page is a keep field. Turning that
+    // into an empty list made the strongest promise in the table the only one
+    // nobody checked (Codex 5-5) — enumerate the box table instead.
+    await run(P.keep === 'all' ? Object.keys(fx.boxes_png) : P.keep, () => 'keep');
+    rec(tag, 'JP_COVERAGE', 'boxes checked', `>=${c.min_boxes || 1}`, String(checked), checked >= (c.min_boxes || 1));
     for (const fmt of (c.out_formats || [])) await checkOutput(page, tag, fmt);
   }
 }
@@ -533,6 +714,180 @@ async function checkJpUnits(page) {
   }
 }
 
+/* ── legal matrix ↔ code (check_matrix.mjs) ────────────────────────────────── */
+function checkMatrix() {
+  const r = spawnSync(process.execPath, [path.join(__dirname, 'check_matrix.mjs')], { encoding: 'utf8' });
+  const out = ((r.stdout || '') + (r.stderr || '')).trim().split('\n').filter(Boolean);
+  rec('(legal matrix)', 'JP_MATRIX', 'JP_RULES == jp_legal_matrix_alpha4.json', 'identical',
+    r.status === 0 ? out[out.length - 1].replace(/^✅ legal matrix ↔ code: /, '') : `${out.length - 1} disagreement(s)`, r.status === 0);
+  if (r.status !== 0) for (const l of out.slice(1, 9)) rec('(legal matrix)', 'JP_MATRIX', l.trim().slice(0, 38), '-', 'mismatch', false, true);
+}
+
+/* ── multi-page: the rule follows the PAGE, not page 1 ──────────────────────
+   A two-sided card scanned into one PDF. The old code read page 1's class and
+   applied it to every page, so the outcome depended on scan order: front-then-
+   back left the 個人番号 page untouched, back-then-front put a full-face band
+   over the front as well (Codex 6-4). Both orders are built here from the
+   committed single-page PNGs — written under out/gen, not committed, so the
+   repo gains no new card binaries. */
+async function buildPdfFromImages(page, srcs, outPath) {
+  const b64 = await page.evaluate(async (urls) => {
+    const { jsPDF } = await ensureJsPDF();
+    let pdf = null;
+    for (const u of urls) {
+      const im = await new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = u; });
+      const cv = document.createElement('canvas'); cv.width = im.width; cv.height = im.height;
+      cv.getContext('2d').drawImage(im, 0, 0);
+      const data = cv.toDataURL('image/jpeg', 0.95);
+      if (!pdf) pdf = new jsPDF({ unit: 'pt', format: [im.width, im.height], compress: true });
+      else pdf.addPage([im.width, im.height]);
+      pdf.addImage(data, 'JPEG', 0, 0, im.width, im.height);
+    }
+    return pdf.output('datauristring').split(',')[1];
+  }, srcs);
+  fs.mkdirSync(path.dirname(outPath), { recursive: true });
+  fs.writeFileSync(outPath, Buffer.from(b64, 'base64'));
+}
+async function checkJpMultiPage(page, port) {
+  const B = `http://127.0.0.1:${port}/__fx/jp/mynumber_card`;
+  const cases = [
+    { label: '表→裏', srcs: [`${B}/front.png`, `${B}/back.png`], backPage: 1, frontPage: 0, file: 'gen/mn_front_back.pdf' },
+    { label: '裏→表', srcs: [`${B}/back.png`, `${B}/front.png`], backPage: 0, frontPage: 1, file: 'gen/mn_back_front.pdf' },
+  ];
+  for (const c of cases) {
+    const tag = `jp/2page ${c.label}`;
+    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
+    try {
+      await buildPdfFromImages(page, c.srcs, path.join(OUT, c.file));
+      await loadDoc(page, c.file, true);
+      await page.evaluate(() => jpSetPurpose('identity_submit'));
+      const st = await page.evaluate(() => window.__jpState());
+      const sides = st.pageCls.map(x => x ? (x.doc + '/' + (x.side || '-')) : 'null');
+      const wantSides = []; wantSides[c.backPage] = 'mynumber_card/back'; wantSides[c.frontPage] = 'mynumber_card/front';
+      rec(tag, 'JP_PAGECLASS', 'per-page doc/side', wantSides.join(' + '), sides.join(' + '),
+        sides.length === 2 && sides[c.backPage] === wantSides[c.backPage] && sides[c.frontPage] === wantSides[c.frontPage]);
+      // The whole-face band exists on the BACK page and only there.
+      const bs = await page.evaluate(() => window.__fieldBands('back_all'));
+      const pagesWithBand = bs.filter(b => b.mode !== 'ok' && b.inMask).map(b => b.page);
+      rec(tag, 'JP_BACK_ONLY', 'back_all pages', `[${c.backPage}]`, `[${pagesWithBand.join(',')}]`,
+        pagesWithBand.length === 1 && pagesWithBand[0] === c.backPage);
+      // And geometrically: the back page is covered, the front page is not.
+      const cov = await page.evaluate(() => pages.map((p, pi) => window.__coverage({ pi, x: 0, y: 0, w: p.w, h: p.h })));
+      rec(tag, 'JP_BACK_COVER', `page ${c.backPage} covered`, '>=99%', `${(cov[c.backPage] * 100).toFixed(0)}%`, cov[c.backPage] >= 0.99);
+      rec(tag, 'JP_FRONT_CLEAR', `page ${c.frontPage} not full-face`, '<=60%', `${(cov[c.frontPage] * 100).toFixed(0)}%`, cov[c.frontPage] <= 0.6);
+    } catch (e) { rec(tag, 'LOAD', c.file, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
+    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
+  }
+}
+
+/* ── 個人番号 check digit ───────────────────────────────────────────────────
+   Two layers. The vectors pin the arithmetic of 省令第5条 (including the two
+   remainder cases the 省令 folds to 0). The synthesis then drives a VALID
+   number through the real pipeline — classification, label anchor, digit span,

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'node run.mjs' in /Users/sunghoon/Projects/docpack/test/safe
 exited 1 in 424ms:
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
/bin/zsh -lc "nl -ba public/safe/index.html | sed -n '580,750p;2576,2645p;2538,2565p;2300,2322p'
nl -ba test/safe/check_matrix.mjs | sed -n '25,130p'
nl -ba test/safe/fixtures/jp/jp_legal_matrix_alpha4.json | sed -n '1,125p'
nl -ba test/safe/fixtures/jp/gen.py | sed -n '55,100p'" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
   580	  btnPick:'Choose file', btnSample:'Try a sample', btnPaste:'Paste text',
   581	  btnPasteScan:'Scan this text', btnCancel:'Cancel', btnReset:'New document',
   582	  pastePh:'Paste your document text here, then press the button below',
   583	  bulkOk:'Show all', bulkNo:'Hide all',
   584	  segOk:'Show', segNo:'Hide',
   585	  bandLabel:'Band colour', bandBlack:'Black', bandWhite:'White', bandCustom:'Custom',
   586	  hintBefore:'Preset the default visibility for each category. When found in your document, items are masked accordingly.',
   587	  hintAfter:'Items found in your document. Change visibility per item — the preview updates instantly.',
   588	  moreShow:n=>`Show ${n} other categories`, moreHide:'Hide other categories',
   589	  aiHint:'AI finds unpatterned info like names, companies, and addresses from context.', btnAI:'AI deep scan',
   590	  aiBusy:'AI reading…', aiDone:'AI scan complete',
   591	  fmtJpg:'Image (JPG)', fmtPng:'Image (PNG)', fmtPdf:'PDF', btnMake:'Create document',
   592	  resTitle:'Your safe document', btnDl:'Download', btnCopy:'Copy text',
   593	  rvFit:'Fit', rvPrevAria:'Previous page', rvNextAria:'Next page', rvZoomInAria:'Zoom in', rvZoomOutAria:'Zoom out', rvFullAria:'Fullscreen', rvExitAria:'Exit fullscreen',
   594	  resFlat:'🔒 This file is flattened to an image — no original text remains under the black boxes.',
   595	  privacy:'🔒 All documents are processed inside your browser. Only when you choose AI deep scan is the extracted text sent for analysis — never stored.',
   596	  partners:'Recommended by SafeFile',
   597	  pSlim:'Image compression & PDF conversion, all under 2MB.', pSchool:'Teaching jobs — find the perfect school.', pHello:'Start learning Korean today.',
   598	  footer:'The fastest way to protect personal info', footPrivacy:'Privacy Policy', footBlog:'Blog',
   599	  pwaTitle:'Add it to your Home Screen to use it like an app', pwaIosDesc:'Tap Safari’s Share <span class="ib-share">↑</span> button, then choose “Add to Home Screen”', pwaAndroidDesc:'Install it to open offline and launch like an app', pwaInstall:'Install',
   600	  cnt:n=>`${n}`, cntUse:n=>`· ${n} in use`, scanDone:n=>`⚡ Instant scan done — ${n} found`, scanAI:n=>`🤖 With AI scan — ${n} total`,
   601	  tPasteEmpty:'Please paste some text first', tBulkOk:'All items set to show', tBulkNo:'All items set to hidden',
   602	  tAIDone:'AI found contextual info like names & companies', tAIDup:'AI scan already done', tAIFail:'AI scan failed. Please try again shortly.',
   603	  tMade:n=>`Done! ${n} spots masked`, tMadeWM:'Done! Watermark applied', tCopied:'Copied to clipboard', tSaved:n=>`Saved ${n}`,
   604	  tReadFail:"Couldn't read the file. Try pasting the text instead.",
   605	  tTooBig:'File is too large (max 20MB).', tPageCap:n=>`Many pages — processed only the first ${n}.`, tUnsupported:e=>`Unsupported format (.${e}). Only PDF, image, Word, or text.`,
   606	  tUnsupExcel:'Excel files aren’t supported yet. Please save as PDF and upload.',
   607	  tUnsupHangul:'Hangul (HWP) files aren’t supported yet. Please save as PDF and upload.',
   608	  tUnsupPpt:'PowerPoint files aren’t supported yet. Please save as PDF and upload.',
   609	  dzSaveExcel:'In Excel, use File › Save As (or Export) and choose PDF.',
   610	  dzSaveHangul:'In the Hangul (HWP) app, use File › Save as PDF (or Save As → PDF).',
   611	  dzSavePpt:'In PowerPoint, use File › Save As (or Export) and choose PDF.',
   612	  renderProg:(p,n)=>`Rendering pages… (${p}/${n})`, ocrStart:'Preparing text recognition…', ocrProg:p=>`Recognizing text (OCR)… ${p}%`,
   613	  scanOcr:'Looks like a scan — recognizing text positions with OCR…', heicConv:'Converting HEIC image…', building:'Building document…',
   614	  notLocated:'not located',
   615	  btnSelect:'🖐 Select area manually', selHint:'Drag with your finger or mouse over the area to hide (photo, signature, stamp, name…)',
   616	  manualSection:'Manually selected areas', candSection:'Please review — hide these too?', manualItem:'Selected area',
   617	  jpFields:{address_loose:'Address in body',tel:'Phone / FAX',doc_shikaku_kakuninsho:'Qualification certificate (資格確認書)', doc_unten_menkyo:'Driver\'s licence (運転免許証)', doc_mynumber_card:'My Number card', doc_juminhyo:'Residence record (住民票)', side_front:'front', side_back:'back', purpose_identity_submit:'Identity verification', purpose_my_number_procedure:'My Number procedure', purpose_bid_attachment:'Tender attachment', purpose_consult_share:'Sharing for advice', back_all:'Entire back face', my_number:'My Number', jumin_code:'Residence code', hokensha_bango:'Insurer number', kigo:'Symbol', bango:'Number', edaban:'Branch number', hihokensha_bango:'Insured number', qr:'2-D code', license_no:'Licence number', biko_change:'Remarks (changes)', organ_donor:'Organ donation section', setaiin:'Other household members', honseki:'Registered domicile', hittosha:'Head of register', sex:'Sex', name:'Name', birth:'Date of birth', address:'Address', expiry:'Valid until', issue:'Issued', issuer:'Issuer'},
   618	  jpPurposeLabel:'Purpose of submission', jpBackNotice:'If identity is what needs checking, submit the front face only. Under the My Number Act, copying or keeping a My Number for anything other than a task the law recognises is restricted. Choose “My Number procedure” only when the recipient performs a statutory My Number task.', jpKeepWarn:'The recipient asks for this field. Hiding it may get your submission rejected.', jpUnclassifiedWarn:'文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。 (The document type could not be identified, so no automatic redaction was applied. Please select the areas to cover by hand.)', jpMnConfirm:'I confirm the recipient performs a statutory My Number (個人番号関係事務) task.', jpLegalSection:'Statutory / recipient rules (法令・提出先ルール)', jpLegalWarn:'This band has a legal basis. Releasing it sends data the recipient is not allowed to keep.', keepSection:'Fields to keep visible',
   619	  reasons:{name:'Possibly a name', jp_auto:'Hidden automatically (legal basis)', jp_gate:'Hidden for this purpose', jp_recommend:'Recommended to hide', jp_optional:'Optional', jp_keep:'Recipient needs this — keep it', addr:'Possibly an address', addr_contact:'Possibly an address · near contact info', addr_edge:'Possibly an address · header/footer', addr_kw:'Possibly an address · place/street term'},
   620	  tManualAdded:'Area added', tManualRemoved:'Area removed', tSelSmall:'Too small — drag a bit larger.', btnSelectOn:'✓ Selecting (turn off)',
   621	  wmToggle:'Add watermark (optional)', wmPlaceholder:'Watermark text (editable)', wmCustom:'Custom…',
   622	  wmPresets:['For submission to ○○','For identity verification only','Not for any other use','Submitted to ○○ on {date}'],
   623	  wmQR:'⚠ Check the result preview to ensure the watermark does not cover any QR code, barcode, or stamp. (The bottom margin is kept clear automatically.)',
   624	  pasted:'Pasted text', aiChars:n=>`${n} chars (AI extracted)`, chars:n=>`${n} chars`, pages:n=>`${n} pages`,
   625	  types:{rrn:'Korean RRN',ssn:'SSN (US)',passport:'Passport no.',license:"Driver's license",card:'Card number',account:'Bank account',phone:'Phone',email:'Email',birth:'Date of birth',address:'Address',name:'Name',company:'Company',title:'Job title',ip:'IP address',url:'Social · URL',health:'Health / sensitive',other:'Other',manual:'Manual'}
   626	},
   627	ja:{
   628	  badge:'無料 · 登録不要', navHome:'← SlimFile',
   629	  heroPre:'文書内の', heroPost:'だけ隠して<br>元の見た目のまま共有',
   630	  cycle:['身分証番号','電話番号','自宅住所','口座番号','氏名'],
   631	  heroP:'文書をアップロードすると、元の見た目はそのままに個人情報の位置だけ黒いバーで隠します。残すものだけ選んでください。',
   632	  trust1:'ファイルはサーバーに保存されません', trust2:'登録不要', trust3:'元のレイアウトそのまま',
   633	  s1:'文書をアップロード', s2:'検出された個人情報', s3:'文書を作成', s3sub:'元の文書の上にマスキングを合成して新しい文書を作ります。黒いボックスの下の原文はコピーされません。',
   634	  dzTitle:'ファイルをドラッグ＆ドロップ、またはクリック', dzTypes:'PDF · 画像(JPG/PNG/WEBP/HEIC) · Word(docx) · テキスト',
   635	  dzTypesNote:'ExcelファイルはPDFに保存してからアップロードしてください',
   636	  dzLimit:'最大20MB · 30ページ · ブラウザ内でのみ処理',
   637	  btnPick:'ファイルを選択', btnSample:'サンプル文書で試す', btnPaste:'テキストを貼り付け',
   638	  btnPasteScan:'この内容で検査', btnCancel:'キャンセル', btnReset:'別の文書',
   639	  pastePh:'ここに文書の内容を貼り付けて、下のボタンを押してください',
   640	  bulkOk:'すべて公開', bulkNo:'すべて非公開',
   641	  segOk:'公開', segNo:'非公開',
   642	  bandLabel:'帯の色', bandBlack:'黒', bandWhite:'白', bandCustom:'自由選択',
   643	  hintBefore:'各項目の初期公開レベルを設定しておきましょう。文書内で見つかると、その設定どおりに隠されます。',
   644	  hintAfter:'文書内で見つかった項目です。項目ごとに公開レベルを変えると、プレビューにすぐ反映されます。',
   645	  moreShow:n=>`検出されなかった項目 ${n}件を表示`, moreHide:'検出されなかった項目を隠す',
   646	  aiHint:'氏名・会社・住所のようにパターンのない情報は、AIが文脈から見つけます。', btnAI:'AI精密検査',
   647	  aiBusy:'AIが読み取り中…', aiDone:'AI検査完了',
   648	  fmtJpg:'画像 (JPG)', fmtPng:'画像 (PNG)', fmtPdf:'PDF', btnMake:'文書を作成',
   649	  resTitle:'完成した文書', btnDl:'ダウンロード', btnCopy:'テキストをコピー',
   650	  rvFit:'フィット', rvPrevAria:'前のページ', rvNextAria:'次のページ', rvZoomInAria:'拡大', rvZoomOutAria:'縮小', rvFullAria:'全画面', rvExitAria:'全画面を閉じる',
   651	  resFlat:'🔒 このファイルは画像に平坦化（フラット化）され、黒いボックスの下に原文は残りません。',
   652	  privacy:'🔒 すべての文書はお使いのブラウザ内でのみ処理されます。AI精密検査を選んだ場合のみ、抽出テキストがAI分析のため送信され、保存されることはありません。',
   653	  partners:'SafeFileのおすすめサービス',
   654	  pSlim:'画像圧縮とPDF変換を、2MB以下で手軽に。', pSchool:'先生のための求人情報、ぴったりの学校探し。', pHello:'韓国語学習を今日から始めましょう。',
   655	  footer:'個人情報を守る、いちばん速い方法', footPrivacy:'プライバシーポリシー', footBlog:'ブログ',
   656	  pwaTitle:'ホーム画面に追加すると、アプリのように使えます', pwaIosDesc:'Safariの共有 <span class="ib-share">↑</span> ボタンをタップして「ホーム画面に追加」を選んでください', pwaAndroidDesc:'インストールするとオフラインでも開き、アプリのように起動します', pwaInstall:'インストール',
   657	  cnt:n=>`${n}件`, cntUse:n=>`· ${n}件使用中`, scanDone:n=>`⚡ 即時検査完了 — ${n}件検出`, scanAI:n=>`🤖 AI検査を含む — 合計${n}件`,
   658	  tPasteEmpty:'内容を貼り付けてください', tBulkOk:'すべての項目を公開に設定しました', tBulkNo:'すべての項目を非公開に設定しました',
   659	  tAIDone:'AIが氏名・会社などの文脈情報まで見つけました', tAIDup:'AI検査はすでに完了しています', tAIFail:'AI検査に失敗しました。しばらくしてからもう一度お試しください。',
   660	  tMade:n=>`完成！ ${n}か所を隠しました`, tMadeWM:'完成！ ウォーターマークを適用しました', tCopied:'クリップボードにコピーしました', tSaved:n=>`${n} を保存しました`,
   661	  tReadFail:'ファイルを読み取れませんでした。テキストの貼り付けをお試しください。',
   662	  tTooBig:'ファイルが大きすぎます（最大20MB）。', tPageCap:n=>`ページが多いため、先頭${n}ページのみ処理しました。`, tUnsupported:e=>`対応していない形式です（.${e}）。PDF・画像・Word・テキストのみ対応します。`,
   663	  tUnsupExcel:'Excelファイルはまだ対応していません。PDFに保存してからアップロードしてください。',
   664	  tUnsupHangul:'ハングル（HWP）ファイルはまだ対応していません。PDFに保存してからアップロードしてください。',
   665	  tUnsupPpt:'PowerPointファイルはまだ対応していません。PDFに保存してからアップロードしてください。',
   666	  dzSaveExcel:'Excelで「ファイル › 名前を付けて保存」（または「エクスポート」）からPDFを選びます。',
   667	  dzSaveHangul:'ハングル（HWP）アプリで「ファイル › PDFで保存」からPDF形式を選びます。',
   668	  dzSavePpt:'PowerPointで「ファイル › 名前を付けて保存」（または「エクスポート」）からPDFを選びます。',
   669	  renderProg:(p,n)=>`ページをレンダリング中… (${p}/${n})`, ocrStart:'文字位置の認識を準備中…', ocrProg:p=>`文字認識(OCR)中… ${p}%`,
   670	  scanOcr:'スキャン文書のようです — OCRで文字位置を認識中…', heicConv:'HEIC画像を変換中…', building:'文書を作成中…',
   671	  notLocated:'位置不明',
   672	  btnSelect:'🖐 範囲を手動で選択', selHint:'隠したい範囲を指またはマウスでドラッグしてください（写真・署名・印鑑・氏名など）',
   673	  manualSection:'手動で選択した範囲', candSection:'要確認 — これも隠しますか？', manualItem:'選択した範囲',
   674	  jpFields:{address_loose:'本文中の住所',tel:'電話・FAX',doc_shikaku_kakuninsho:'資格確認書', doc_unten_menkyo:'運転免許証', doc_mynumber_card:'マイナンバーカード', doc_juminhyo:'住民票の写し', side_front:'表面', side_back:'裏面', purpose_identity_submit:'本人確認提出', purpose_my_number_procedure:'個人番号手続', purpose_bid_attachment:'入札添付', purpose_consult_share:'相談用共有', back_all:'裏面全体', my_number:'個人番号', jumin_code:'住民票コード', hokensha_bango:'保険者番号', kigo:'記号', bango:'番号', edaban:'枝番', hihokensha_bango:'被保険者番号', qr:'二次元コード', license_no:'免許証番号', biko_change:'備考欄（変更記載）', organ_donor:'臓器提供意思表示欄', setaiin:'本人以外の世帯員', honseki:'本籍', hittosha:'筆頭者', sex:'性別', name:'氏名', birth:'生年月日', address:'住所', expiry:'有効期限', issue:'交付日', issuer:'発行者'},
   675	  jpPurposeLabel:'提出目的', jpBackNotice:'身元確認が目的なら表面のみ提出してください。番号法上、法令で認められた事務以外で個人番号を複写・保管することは制限されています。「個人番号手続」は、提出先が法定の個人番号関係事務を行う場合にのみ選んでください。', jpKeepWarn:'提出先が受付できない可能性があります（本人特定事項）。', jpUnclassifiedWarn:'文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。', jpMnConfirm:'提出先が法定の個人番号関係事務を行うことを確認しました。', jpLegalSection:'法令・提出先ルール', jpLegalWarn:'法令に根拠がある項目です。解除すると、提出先が保管できない情報がそのまま出力されます。', keepSection:'残す項目',
   676	  reasons:{name:'氏名の可能性', jp_auto:'法令根拠により自動で黒塗り', jp_gate:'この目的では自動で黒塗り', jp_recommend:'黒塗りを推奨', jp_optional:'任意', jp_keep:'提出先が必要とする項目', addr:'住所の可能性', addr_contact:'住所の可能性 · 連絡先の近く', addr_edge:'住所の可能性 · 文書の上部・下部', addr_kw:'住所の可能性 · 地名・住所語'},
   677	  tManualAdded:'範囲を追加しました', tManualRemoved:'範囲を削除しました', tSelSmall:'小さすぎます。もう少し大きくドラッグしてください。', btnSelectOn:'✓ 選択モード（オフ）',
   678	  wmToggle:'ウォーターマークを入れる（任意）', wmPlaceholder:'ウォーターマーク文言（自由入力可）', wmCustom:'自由入力…',
   679	  wmPresets:['○○ 提出用','本人確認のみに使用','転用禁止','{date} ○○ に提出'],
   680	  wmQR:'⚠ ウォーターマークがQRコード・バーコード・印鑑を隠していないか、結果プレビューで必ずご確認ください。（下部の余白は自動で空けます）',
   681	  pasted:'貼り付けたテキスト', aiChars:n=>`${n}文字（AI抽出）`, chars:n=>`${n}文字`, pages:n=>`${n}ページ`,
   682	  types:{rrn:'住民登録番号(韓国)',ssn:'SSN(米国)',passport:'パスポート番号',license:'運転免許番号',card:'カード番号',account:'口座番号',phone:'電話番号',email:'メール',birth:'生年月日',address:'住所',name:'氏名',company:'会社・所属',title:'役職',ip:'IPアドレス',url:'SNS・URL',health:'健康・センシティブ情報',other:'その他',manual:'手動選択'}
   683	},
   684	es:{
   685	  badge:'Gratis · Sin registro', navHome:'← SlimFile',
   686	  heroPre:'Oculta solo los ', heroPost:'<br>y comparte el documento tal cual',
   687	  cycle:['datos de identidad','números de teléfono','domicilio','números de cuenta','nombres'],
   688	  heroP:'Sube un documento: mantenemos su aspecto original y colocamos barras negras solo sobre los datos personales. Conserva lo que quieras.',
   689	  trust1:'Los archivos nunca salen de tu navegador', trust2:'Sin registro', trust3:'Diseño original intacto',
   690	  s1:'Subir documento', s2:'Datos personales detectados', s3:'Crear documento', s3sub:'Superpone el enmascarado sobre tu original. El texto bajo las cajas negras no se copia.',
   691	  dzTitle:'Arrastra y suelta un archivo o haz clic', dzTypes:'PDF · Imagen (JPG/PNG/WEBP/HEIC) · Word (docx) · Texto',
   692	  dzTypesNote:'Archivos de Excel: guárdalos como PDF antes de subir',
   693	  dzLimit:'Hasta 20MB · 30 páginas · procesado solo en tu navegador',
   694	  btnPick:'Elegir archivo', btnSample:'Probar con un ejemplo', btnPaste:'Pegar texto',
   695	  btnPasteScan:'Analizar este texto', btnCancel:'Cancelar', btnReset:'Nuevo documento',
   696	  pastePh:'Pega aquí el texto de tu documento y pulsa el botón de abajo',
   697	  bulkOk:'Mostrar todo', bulkNo:'Ocultar todo',
   698	  segOk:'Mostrar', segNo:'Ocultar',
   699	  bandLabel:'Color de banda', bandBlack:'Negro', bandWhite:'Blanco', bandCustom:'Personalizado',
   700	  hintBefore:'Define el nivel de visibilidad por defecto de cada categoría. Cuando se encuentren en tu documento, se ocultarán según esa configuración.',
   701	  hintAfter:'Elementos encontrados en tu documento. Cambia la visibilidad de cada uno: la vista previa se actualiza al instante.',
   702	  moreShow:n=>`Mostrar ${n} categorías más`, moreHide:'Ocultar otras categorías',
   703	  aiHint:'La IA encuentra datos sin patrón fijo, como nombres, empresas y direcciones, a partir del contexto.', btnAI:'Análisis con IA',
   704	  aiBusy:'La IA está leyendo…', aiDone:'Análisis con IA completado',
   705	  fmtJpg:'Imagen (JPG)', fmtPng:'Imagen (PNG)', fmtPdf:'PDF', btnMake:'Crear documento',
   706	  resTitle:'Tu documento seguro', btnDl:'Descargar', btnCopy:'Copiar texto',
   707	  rvFit:'Ajustar', rvPrevAria:'Página anterior', rvNextAria:'Página siguiente', rvZoomInAria:'Acercar', rvZoomOutAria:'Alejar', rvFullAria:'Pantalla completa', rvExitAria:'Salir de pantalla completa',
   708	  resFlat:'🔒 Este archivo está aplanado a imagen: no queda texto original bajo las cajas negras.',
   709	  privacy:'🔒 Todos los documentos se procesan dentro de tu navegador. Solo cuando eliges el análisis con IA se envía el texto extraído para su análisis, y nunca se almacena.',
   710	  partners:'Recomendado por SafeFile',
   711	  pSlim:'Compresión de imágenes y conversión a PDF, todo por debajo de 2 MB.', pSchool:'Empleo docente: encuentra el colegio perfecto.', pHello:'Empieza a aprender coreano hoy.',
   712	  footer:'La forma más rápida de proteger tus datos personales', footPrivacy:'Política de privacidad', footBlog:'Blog',
   713	  pwaTitle:'Añádela a tu pantalla de inicio para usarla como una app', pwaIosDesc:'Pulsa el botón Compartir <span class="ib-share">↑</span> de Safari y elige “Añadir a pantalla de inicio”', pwaAndroidDesc:'Instálala para abrirla sin conexión y ejecutarla como una app', pwaInstall:'Instalar',
   714	  cnt:n=>`${n}`, cntUse:n=>`· ${n} en uso`, scanDone:n=>`⚡ Análisis instantáneo listo — ${n} encontrados`, scanAI:n=>`🤖 Con análisis de IA — ${n} en total`,
   715	  tPasteEmpty:'Primero pega algún texto', tBulkOk:'Todos los elementos configurados como visibles', tBulkNo:'Todos los elementos configurados como ocultos',
   716	  tAIDone:'La IA encontró datos contextuales como nombres y empresas', tAIDup:'El análisis con IA ya está hecho', tAIFail:'El análisis con IA falló. Inténtalo de nuevo en un momento.',
   717	  tMade:n=>`¡Listo! ${n} zonas ocultadas`, tMadeWM:'¡Listo! Marca de agua aplicada', tCopied:'Copiado al portapapeles', tSaved:n=>`${n} guardado`,
   718	  tReadFail:'No se pudo leer el archivo. Prueba a pegar el texto.',
   719	  tTooBig:'El archivo es demasiado grande (máx. 20MB).', tPageCap:n=>`Muchas páginas: solo se procesaron las primeras ${n}.`, tUnsupported:e=>`Formato no admitido (.${e}). Solo PDF, imagen, Word o texto.`,
   720	  tUnsupExcel:'Los archivos de Excel aún no son compatibles. Guárdalos como PDF y súbelos.',
   721	  tUnsupHangul:'Los archivos Hangul (HWP) aún no son compatibles. Guárdalos como PDF y súbelos.',
   722	  tUnsupPpt:'Los archivos de PowerPoint aún no son compatibles. Guárdalos como PDF y súbelos.',
   723	  dzSaveExcel:'En Excel, usa Archivo › Guardar como (o Exportar) y elige PDF.',
   724	  dzSaveHangul:'En la app Hangul (HWP), usa Archivo › Guardar como PDF.',
   725	  dzSavePpt:'En PowerPoint, usa Archivo › Guardar como (o Exportar) y elige PDF.',
   726	  renderProg:(p,n)=>`Renderizando páginas… (${p}/${n})`, ocrStart:'Preparando el reconocimiento de texto…', ocrProg:p=>`Reconociendo texto (OCR)… ${p}%`,
   727	  scanOcr:'Parece un escaneo: reconociendo posiciones de texto con OCR…', heicConv:'Convirtiendo imagen HEIC…', building:'Creando documento…',
   728	  notLocated:'sin ubicar',
   729	  btnSelect:'🖐 Seleccionar área manualmente', selHint:'Arrastra con el dedo o el ratón sobre el área a ocultar (foto, firma, sello, nombre…)',
   730	  manualSection:'Áreas seleccionadas manualmente', candSection:'Revisar — ¿ocultar también esto?', manualItem:'Área seleccionada',
   731	  jpFields:{address_loose:'Dirección en el texto',tel:'Teléfono / FAX',doc_shikaku_kakuninsho:'Certificado de cobertura (資格確認書)', doc_unten_menkyo:'Permiso de conducir (運転免許証)', doc_mynumber_card:'Tarjeta My Number', doc_juminhyo:'Certificado de residencia (住民票)', side_front:'anverso', side_back:'reverso', purpose_identity_submit:'Verificación de identidad', purpose_my_number_procedure:'Trámite de My Number', purpose_bid_attachment:'Anexo de licitación', purpose_consult_share:'Compartir para consulta', back_all:'Todo el reverso', my_number:'My Number', jumin_code:'Código de residencia', hokensha_bango:'N.º de aseguradora', kigo:'Símbolo', bango:'Número', edaban:'N.º de rama', hihokensha_bango:'N.º de asegurado', qr:'Código 2D', license_no:'N.º de permiso', biko_change:'Observaciones (cambios)', organ_donor:'Apartado de donación de órganos', setaiin:'Otros miembros del hogar', honseki:'Domicilio registral', hittosha:'Titular del registro', sex:'Sexo', name:'Nombre', birth:'Fecha de nacimiento', address:'Dirección', expiry:'Válido hasta', issue:'Emitido', issuer:'Emisor'},
   732	  jpPurposeLabel:'Finalidad del envío', jpBackNotice:'Si lo que hay que verificar es la identidad, envía solo el anverso. La Ley My Number restringe copiar o conservar un My Number para fines distintos de los trámites reconocidos por la ley. Elige «Trámite de My Number» solo si el destinatario realiza un trámite legal de My Number.', jpKeepWarn:'El destinatario pide este dato. Ocultarlo puede provocar el rechazo del envío.', jpUnclassifiedWarn:'文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。 (No se ha podido identificar el tipo de documento, por lo que no se aplicó ningún tachado automático. Selecciona a mano las zonas que quieras cubrir.)', jpMnConfirm:'Confirmo que el destinatario realiza un trámite legal de My Number (個人番号関係事務).', jpLegalSection:'Reglas legales / del destinatario (法令・提出先ルール)', jpLegalWarn:'Esta banda tiene base legal. Al liberarla envías datos que el destinatario no puede conservar.', keepSection:'Campos que deben quedar visibles',
   733	  reasons:{name:'Puede ser un nombre', jp_auto:'Oculto automáticamente (base legal)', jp_gate:'Oculto para esta finalidad', jp_recommend:'Se recomienda ocultar', jp_optional:'Opcional', jp_keep:'El destinatario lo necesita', addr:'Puede ser una dirección', addr_contact:'Puede ser una dirección · cerca del contacto', addr_edge:'Puede ser una dirección · encabezado/pie', addr_kw:'Puede ser una dirección · término de lugar/calle'},
   734	  tManualAdded:'Área añadida', tManualRemoved:'Área eliminada', tSelSmall:'Demasiado pequeña — arrastra un poco más.', btnSelectOn:'✓ Seleccionando (desactivar)',
   735	  wmToggle:'Añadir marca de agua (opcional)', wmPlaceholder:'Texto de la marca de agua (editable)', wmCustom:'Personalizado…',
   736	  wmPresets:['Para presentar a ○○','Solo para verificar la identidad','Prohibido otro uso','Presentado a ○○ el {date}'],
   737	  wmQR:'⚠ Revisa la vista previa del resultado para que la marca de agua no cubra ningún código QR, de barras o sello. (El margen inferior se deja libre automáticamente.)',
   738	  pasted:'Texto pegado', aiChars:n=>`${n} caracteres (extraído por IA)`, chars:n=>`${n} caracteres`, pages:n=>`${n} páginas`,
   739	  types:{rrn:'RRN de Corea',ssn:'SSN (EE. UU.)',passport:'N.º de pasaporte',license:'Permiso de conducir',card:'N.º de tarjeta',account:'Cuenta bancaria',phone:'Teléfono',email:'Correo',birth:'Fecha de nacimiento',address:'Dirección',name:'Nombre',company:'Empresa',title:'Cargo',ip:'Dirección IP',url:'Redes · URL',health:'Salud / sensible',other:'Otro',manual:'Manual'}
   740	}
   741	};
   742	const LANGS = ['ko','en','ja','es'];
   743	function detectLang(){
   744	  try { const s = localStorage.getItem('safefile_lang'); if (s && LANGS.includes(s)) return s; } catch(e){}
   745	  const n = (navigator.language||'ko').toLowerCase();
   746	  for (const l of LANGS) if (n.startsWith(l)) return l;
   747	  return 'ko';
   748	}
   749	let LANG = detectLang();
   750	const T = () => I18N[LANG];
  2300	    }
  2301	    setStatus(T().scanDone(entities.filter(e=>e.kind!=='candidate').length)); setProg(0);
  2302	  }
  2303	  const ab=$('btnAI'); if(!aiDone){ ab.disabled=false; }
  2304	  buildPreview();
  2305	  if(jpState.cls){
  2306	    jpApply();
  2307	    // The status line is written before the preset runs, so on a JP document it
  2308	    // used to report "0 found" next to a list of five bands. Keep-fields are not
  2309	    // "found personal info" — they are what the recipient needs — so they do not count.
  2310	    if(!keepEntities) setStatus(T().scanDone(entities.filter(e=>e.kind!=='keep'&&e.kind!=='manual').length));
  2311	  } else { jpRenderBar(); renderAll(); }
  2312	}
  2313	function resetResult(){ $('result').style.display='none'; lastOut=null; }
  2314	function resetAll(){
  2315	  pages=[]; docText=''; entities=[]; aiDone=false; showAllCats=false; previewCanvases=[];
  2316	  jpState=JP_STATE0(); jpRenderBar();
  2317	  $('docWrap').style.display='none'; dz.style.display='flex'; $('preview').innerHTML=''; clearDzAlert();
  2318	  if(typeof setSelectMode==='function') setSelectMode(false);
  2319	  setStatus(''); setProg(0); resetResult();
  2320	  const ab=$('btnAI'); ab.disabled=true; ab.innerHTML='🤖 <span data-i18n="btnAI">'+T().btnAI+'</span>';
  2321	  renderAll();
  2322	}
  2538	  // region:true — the drag rectangle IS the intent; bandRect must not grow it.
  2539	  const box={page:pi, x:dx/scale, y:dy/scale, w:dw/scale, h:dh/scale, region:true}; // display px → page px
  2540	  box.bg=sampleBg(page,box);
  2541	  entities.push({id:'e'+Math.random().toString(36).slice(2,8),type:'manual',value:'('+T().manualItem+')',mode:'no',kind:'manual',boxes:[box]});
  2542	  renderAll();
  2543	  toast(T().tManualAdded);
  2544	}
  2545	$('btnSelect').addEventListener('click',()=>setSelectMode(!selectMode));
  2546	$('jpPurpose').addEventListener('change',e=>jpSetPurpose(e.target.value));
  2547	
  2548	/* ───────── detection list (live value next to toggle) ───────── */
  2549	function catRowHtml(type,items){
  2550	  const on=catEnabled[type], d=catDefault[type], t=T();
  2551	  return `
  2552	  <div class="cat-row ${on?'':'off'}">
  2553	    <div class="cat-head">
  2554	      <label class="cat-tgl">
  2555	        <input type="checkbox" data-cat="${type}" ${on?'checked':''}>
  2556	        <span class="cl">${TYPES[type].icon} ${tLabel(type)}</span>
  2557	      </label>
  2558	      <span class="cnt ${items.length?'hit':''}">${items.length? t.cnt(items.length) : ''}</span>
  2559	      <div class="seg" data-cat-seg="${type}" role="radiogroup">
  2560	        <button class="${d==='ok'?'on-ok':''}" data-cmode="ok">${t.segOk}</button>
  2561	        <button class="${d==='no'?'on-no':''}" data-cmode="no">${t.segNo}</button>
  2562	      </div>
  2563	    </div>
  2564	    ${items.length?`<div class="cat-items">${items.map(e=>`
  2565	      <div class="pii-item${located(e)?'':' nolocate'}">
  2576	function sectionHtml(kind,title,items){
  2577	  const t=T(), cand=kind==='candidate';
  2578	  const icon=kind==='candidate'?'❓':kind==='keep'?'🛡':kind==='legal'?'⚖️':'✏️';
  2579	  return `
  2580	  <div class="cat-row sec-${kind}">
  2581	    <div class="cat-head">
  2582	      <span class="cl">${icon} ${title}</span>
  2583	      <span class="cnt hit">${t.cnt(items.length)}</span>
  2584	    </div>
  2585	    <div class="cat-items">${items.map(e=>`
  2586	      <div class="pii-item${cand?' is-cand':''}">
  2587	        <div class="val-wrap">
  2588	          <span class="val ${cand?'':'mono'}" title="${escapeHtml(e.value)}">${escapeHtml(kind==='manual'? t.manualItem : displayValue(e))}</span>
  2589	          ${(cand||kind==='keep'||kind==='legal')?`<span class="reason">${(TYPES[e.type]||{}).icon||''} ${t.reasons[e.reason]||(e.jp?t.reasons.jp_keep:t.reasons.name)}</span>`:''}
  2590	        </div>
  2591	        <div class="seg" role="radiogroup">
  2592	          <button class="${e.mode==='ok'?'on-ok':''}" data-id="${e.id}" data-mode="ok">${t.segOk}</button>
  2593	          <button class="${e.mode==='no'?'on-no':''}" data-id="${e.id}" data-mode="no">${t.segNo}</button>
  2594	        </div>
  2595	        ${kind==='manual'?`<button class="del" data-del="${e.id}" title="remove" aria-label="remove">✕</button>`:''}
  2596	      </div>`).join('')}</div>
  2597	  </div>`;
  2598	}
  2599	function renderList(){
  2600	  const list=$('piiList'), t=T();
  2601	  // Legal-preset bands come out of the category grouping entirely — they are not
  2602	  // a "type" the user turns off, they are a rule with a citation.
  2603	  const legalE=entities.filter(e=>e.legal);
  2604	  const autoE=entities.filter(e=>!e.legal&&e.kind!=='candidate'&&e.kind!=='manual'&&e.kind!=='keep');
  2605	  const manualE=entities.filter(e=>!e.legal&&e.kind==='manual');
  2606	  const candE=entities.filter(e=>!e.legal&&e.kind==='candidate');
  2607	  const keepE=entities.filter(e=>!e.legal&&e.kind==='keep');
  2608	  const total=entities.filter(isOn).length;
  2609	  $('piiCount').textContent= total? t.cntUse(total):'';
  2610	  document.querySelectorAll('#bulkBtns button').forEach(b=>b.disabled=!total);
  2611	  $('catHint').textContent = pages.length? t.hintAfter : t.hintBefore;
  2612	  const groups={};
  2613	  for(const e of autoE){(groups[e.type]=groups[e.type]||[]).push(e);}
  2614	  const all=Object.keys(TYPES).filter(ty=>ty!=='manual');
  2615	  if(!pages.length){
  2616	    list.innerHTML = all.map(ty=>catRowHtml(ty,[])).join('');
  2617	    return;
  2618	  }
  2619	  const hits=all.filter(ty=>groups[ty]&&groups[ty].length);
  2620	  const misses=all.filter(ty=>!groups[ty]||!groups[ty].length);
  2621	  let html=hits.map(ty=>catRowHtml(ty,groups[ty])).join('');
  2622	  if(misses.length){
  2623	    html+=`<button class="more-cats" id="moreCats">${showAllCats? t.moreHide : t.moreShow(misses.length)}</button>`;
  2624	    if(showAllCats) html+=misses.map(ty=>catRowHtml(ty,[])).join('');
  2625	  }
  2626	  if(legalE.length)  html=sectionHtml('legal', t.jpLegalSection, legalE)+html;
  2627	  if(manualE.length) html+=sectionHtml('manual', t.manualSection, manualE);
  2628	  if(candE.length)   html+=sectionHtml('candidate', t.candSection, candE);
  2629	  if(keepE.length)   html+=sectionHtml('keep', t.keepSection, keepE);
  2630	  list.innerHTML=html;
  2631	}
  2632	$('piiList').addEventListener('change',e=>{
  2633	  const cb=e.target.closest('input[data-cat]'); if(!cb) return;
  2634	  catEnabled[cb.dataset.cat]=cb.checked; renderAll();
  2635	});
  2636	$('piiList').addEventListener('click',e=>{
  2637	  if(e.target.closest('#moreCats')){showAllCats=!showAllCats;renderList();return;}
  2638	  const del=e.target.closest('button[data-del]');
  2639	  if(del){ entities=entities.filter(x=>x.id!==del.dataset.del); renderAll(); toast(T().tManualRemoved); return; }
  2640	  const cm=e.target.closest('button[data-cmode]');
  2641	  if(cm){
  2642	    const type=cm.closest('[data-cat-seg]').dataset.catSeg;
  2643	    catDefault[type]=cm.dataset.cmode;
  2644	    // Legal-preset entities are excluded: this is a per-TYPE control and the
  2645	    // statutory bands share the catch-all types. Releasing them has to be a
    25	const REPO = path.resolve(__dirname, '..', '..');
    26	const MATRIX = path.join(__dirname, 'fixtures', 'jp', 'jp_legal_matrix_alpha4.json');
    27	const PAGE = path.join(REPO, 'public', 'safe', 'index.html');
    28	
    29	const LEVEL_TOKEN = { auto: 'auto', auto_with_purpose_gate: 'gate', recommend: 'recommend', optional: 'optional', keep: 'keep' };
    30	const AUTOMATIC = new Set(['auto', 'gate']);
    31	
    32	const problems = [];
    33	const fail = (what, msg) => problems.push(`${what}: ${msg}`);
    34	
    35	/* ── 1. the 정본 → a (doc, field, purpose) table ── */
    36	const M = JSON.parse(fs.readFileSync(MATRIX, 'utf8'));
    37	const PURPOSES = Object.keys(M.purposes);
    38	const matrix = {};            // doc → field → purpose → level
    39	const matrixFields = {};      // doc → Set(field)
    40	function applyRule(docId, rule, where) {
    41	  const token = LEVEL_TOKEN[rule.level];
    42	  if (!token) { fail(where, `unknown level "${rule.level}"`); return; }
    43	  if (!Array.isArray(rule.fields) || !rule.fields.length) { fail(where, 'rule has no `fields` (code field keys)'); return; }
    44	  if (rule.verified === false && AUTOMATIC.has(token))
    45	    fail(where, `verified:false but level "${rule.level}" is automatic — an unsourced rule may not delete pixels on its own`);
    46	  const seen = {};
    47	  const put = (purpose, level) => {
    48	    if (!PURPOSES.includes(purpose)) { fail(where, `unknown purpose "${purpose}"`); return; }
    49	    if (seen[purpose]) { fail(where, `purpose "${purpose}" appears twice (${seen[purpose]} and ${level})`); return; }
    50	    seen[purpose] = level;
    51	    for (const f of rule.fields) {
    52	      matrix[docId] = matrix[docId] || {};
    53	      matrix[docId][f] = matrix[docId][f] || {};
    54	      matrixFields[docId] = matrixFields[docId] || new Set();
    55	      matrixFields[docId].add(f);
    56	      const prev = matrix[docId][f][purpose];
    57	      if (prev && prev !== level) fail(`${docId}.${f}[${purpose}]`, `two rules disagree: ${prev} vs ${level}`);
    58	      matrix[docId][f][purpose] = level;
    59	    }
    60	  };
    61	  for (const p of (rule.must_keep_when || [])) put(p, 'keep');
    62	  for (const p of (rule.mask_when || [])) put(p, token);
    63	  for (const p of (rule.optional_when || [])) put(p, 'optional');
    64	}
    65	for (const doc of M.documents) for (const r of doc.rules) applyRule(doc.id, r, `${doc.id} 「${r.field}」`);
    66	// general_jp applies to every listed document.
    67	const G = M.general_jp || { applies_to: [], rules: [] };
    68	for (const docId of G.applies_to) for (const r of G.rules) applyRule(docId, r, `general_jp→${docId} 「${r.field}」`);
    69	
    70	/* ── 2. the code → JP_RULES + jpLevel ── */
    71	const src = fs.readFileSync(PAGE, 'utf8');
    72	function slice(startMarker, endMarker) {
    73	  const a = src.indexOf(startMarker);
    74	  if (a < 0) throw new Error(`cannot find ${startMarker} in ${PAGE}`);
    75	  const b = src.indexOf(endMarker, a);
    76	  if (b < 0) throw new Error(`cannot find ${endMarker} after ${startMarker}`);
    77	  return src.slice(a, b + endMarker.length);
    78	}
    79	// Everything from the purpose shorthands through the end of JP_RULES, then jpLevel.
    80	const rulesSrc = slice('const P_NOT_MYNUM =', '\n};\n');
    81	const levelSrc = slice('function jpLevel(', '\n}\n');
    82	const legalSrc = slice('const JP_LEGAL_FIELDS =', ']);');
    83	let JP_RULES, jpLevel, JP_LEGAL_FIELDS;
    84	try {
    85	  ({ JP_RULES, jpLevel, JP_LEGAL_FIELDS } =
    86	    new Function(`${rulesSrc}\n${levelSrc}\n${legalSrc}\nreturn {JP_RULES, jpLevel, JP_LEGAL_FIELDS};`)());
    87	} catch (e) {
    88	  console.error('could not evaluate JP_RULES / jpLevel out of index.html:', e.message);
    89	  process.exit(2);
    90	}
    91	
    92	/* ── 3. compare every triple in EITHER table ── */
    93	let compared = 0;
    94	const docs = new Set([...Object.keys(matrix), ...Object.keys(JP_RULES)]);
    95	for (const doc of docs) {
    96	  const mf = matrixFields[doc] || new Set();
    97	  const cf = new Set(Object.keys(JP_RULES[doc] || {}));
    98	  for (const f of cf) if (!mf.has(f)) fail(`${doc}.${f}`, 'in JP_RULES but not in the legal matrix');
    99	  for (const f of mf) if (!cf.has(f)) fail(`${doc}.${f}`, 'in the legal matrix but not in JP_RULES');
   100	  for (const f of new Set([...mf, ...cf])) {
   101	    for (const p of PURPOSES) {
   102	      const want = ((matrix[doc] || {})[f] || {})[p] || null;
   103	      const got = (JP_RULES[doc] && JP_RULES[doc][f]) ? jpLevel(doc, f, p) : null;
   104	      compared++;
   105	      if (want !== got) fail(`${doc}.${f}[${p}]`, `matrix says ${want || 'null (not offered)'}, code says ${got || 'null (not offered)'}`);
   106	    }
   107	  }
   108	}
   109	// A triple must have been checked. A comparison loop that silently ran zero
   110	// times prints the same green as one that checked two hundred.
   111	if (compared < 100) fail('coverage', `only ${compared} (doc, field, purpose) triples compared — the extraction is probably broken`);
   112	
   113	/* ── 4/5. the legal group must be a subset of what the matrix grounds in statute ── */
   114	for (const f of JP_LEGAL_FIELDS) {
   115	  const inSome = Object.keys(matrix).some(d => matrix[d][f]);
   116	  if (!inSome) fail(`JP_LEGAL_FIELDS.${f}`, 'not a field the legal matrix knows');
   117	}
   118	
   119	if (problems.length) {
   120	  console.log(`\n✗ legal matrix ↔ code: ${problems.length} disagreement(s) over ${compared} triples\n`);
   121	  for (const p of problems) console.log('   ' + p);
   122	  console.log('');
   123	  process.exit(1);
   124	}
   125	console.log(`✅ legal matrix ↔ code: ${compared} (doc, field, purpose) triples identical, verified:false⇒no-auto holds`);
     1	{
     2	  "version": "2026-10-21b",
     3	  "scope": "SafeFile JP 알파 4종. 규칙은 제출 목적(purpose)별. 출처 없는 규칙은 verified=false로 표기하고 자동 마스킹 금지.",
     4	  "_schema": {
     5	    "rule": "{field: 사람이 읽는 필드명, fields: [코드 필드 키], mask_when: [purpose], must_keep_when: [purpose], optional_when: [purpose], level, legal_basis, source, verified}",
     6	    "derivation": "(doc, code field, purpose) → level: purpose ∈ must_keep_when → keep · purpose ∈ mask_when → level 토큰 · purpose ∈ optional_when → optional · 그 외 → null(UI에 내지 않음). 한 purpose가 두 목록에 동시에 들어가면 오류다.",
     7	    "level_tokens": "auto → auto · auto_with_purpose_gate → gate · recommend → recommend · optional → optional · keep → keep",
     8	    "invariant": "verified=false 인 규칙은 auto·gate 를 가질 수 없다. 출처 없는 판단이 스스로 픽셀을 지우면 안 된다. test/safe/check_matrix.mjs 가 이 표와 public/safe/index.html 의 JP_RULES 를 (doc, field, purpose) 전수 대조하고 이 불변식을 강제한다.",
     9	    "optional_when_basis": "optional 은 「既定OFF・選択可」 — 법적 주장이 아니라 UI 제공이다. 제출 목적이 그 항목을 요구하지 않는 조합(특히 相談用共有)에서 사용자가 자기 정보를 가릴 수단을 잃지 않도록 명시한다. 출처가 없으므로 자동이 될 수 없다."
    10	  },
    11	  "purposes": {
    12	    "identity_submit": "本人確認書類として提出（銀行・カード・通信・フリマ・賃貸）",
    13	    "my_number_procedure": "個人番号関係事務（税・社会保障・勤務先提出）",
    14	    "bid_attachment": "入札・許可申請への添付",
    15	    "consult_share": "専門家・SNS等への相談用共有"
    16	  },
    17	  "documents": [
    18	    {
    19	      "id": "shikaku_kakuninsho", "name": "資格確認書", "replaces": "健康保険証（2025-12-01 失効・暫定2026-07-31終了）",
    20	      "variants": ["被用者保険(協会けんぽ・健保組合)", "国民健康保険", "後期高齢者医療"],
    21	      "fields_common": ["氏名", "生年月日", "性別", "住所", "資格取得年月日", "有効期限", "保険者番号", "保険者名", "記号/番号/枝番 または 被保険者番号"],
    22	      "fields_issuer_specific": ["事業所名称", "二次元コード", "一部負担金割合", "自己負担限度額区分"],
    23	      "rules": [
    24	        {"field": "保険者番号・記号・番号・枝番・被保険者番号",
    25	         "fields": ["hokensha_bango", "kigo", "bango", "edaban", "hihokensha_bango"],
    26	         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": [], "level": "auto",
    27	         "legal_basis": "健康保険法等 告知要求制限（2020-10-01施行）: 医療保険事務以外の目的での告知要求を原則禁止。提出先が受領する場合もマスキングを求める運用。my_number_procedure は明示しない（医療保険関係事務で番号が必要な例外の有無が確認不可） → null",
    28	         "source": ["https://www.mhlw.go.jp/stf/newpage_13989.html", "https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf", "https://www.kyosai.metro.tokyo.jp/assets/84b47fd406a8378372a6015863f83bc93c0c8a75.pdf"], "verified": true},
    29	        {"field": "二次元コード", "fields": ["qr"],
    30	         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "level": "auto",
    31	         "legal_basis": "番号を判読可能なため同一扱い（大阪府・千葉市運用）", "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"], "verified": true},
    32	        {"field": "性別", "fields": ["sex"], "mask_when": ["identity_submit"], "level": "recommend",
    33	         "legal_basis": "法定ではない。民間KYC事業者の運用（SoftBank, PayPay銀行等）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
    34	        {"field": "氏名・生年月日・住所・有効期限", "fields": ["name", "birth", "address", "expiry"],
    35	         "mask_when": [], "must_keep_when": ["identity_submit", "bid_attachment"], "optional_when": ["consult_share"], "level": "keep",
    36	         "legal_basis": "本人特定事項。マスキングすると受付不可。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）",
    37	         "source": ["https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html"], "verified": true},
    38	        {"field": "事業所名称・保険者名・資格取得年月日", "fields": ["jigyosho", "hokensha_name", "shikaku_date"],
    39	         "mask_when": [], "must_keep_when": ["identity_submit", "bid_attachment"], "optional_when": ["consult_share"], "level": "keep",
    40	         "legal_basis": "資格の有効性を提出先が照合する欄という運用判断。法定の must-keep ではなく出典もない（警告のみで、自動マスキング対象には決してしない）",
    41	         "source": [], "verified": false}
    42	      ]
    43	    },
    44	    {
    45	      "id": "unten_menkyo", "name": "運転免許証", "sides": ["表", "裏"],
    46	      "fields_front": ["氏名", "生年月日", "住所", "交付日", "有効期限", "免許の条件", "番号(12桁)", "種類・取得日", "顔写真", "公安委員会名"],
    47	      "fields_back": ["備考欄（住所・氏名等の変更記載）", "臓器提供意思表示欄"],
    48	      "note": "本籍は券面に印字されない（ICチップ内）",
    49	      "rules": [
    50	        {"field": "裏面 備考欄（変更記載）", "fields": ["biko_change"],
    51	         "mask_when": ["identity_submit", "consult_share"], "level": "recommend",
    52	         "legal_basis": "旧住所等の不要情報。提出先指示優先（住所変更確認で裏面が必要な場合あり）", "source": ["https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true},
    53	        {"field": "臓器提供意思表示欄", "fields": ["organ_donor"],
    54	         "mask_when": ["identity_submit", "consult_share"], "level": "recommend",
    55	         "legal_basis": "民間KYC運用（SoftBank: 臓器提供意思をマスキング）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
    56	        {"field": "番号(12桁)", "fields": ["license_no"],
    57	         "mask_when": ["consult_share"], "must_keep_when": ["identity_submit"], "level": "optional",
    58	         "legal_basis": "個人識別符号（個人情報保護法施行令）。KYCでは照合に必要な提出先が多い → 本人確認提出では must-keep、相談用共有では既定OFFで選択可",
    59	         "source": [], "verified": false},
    60	        {"field": "氏名・生年月日・住所・有効期限・顔写真", "fields": ["name", "birth", "address", "expiry"],
    61	         "must_keep_when": ["identity_submit"], "optional_when": ["consult_share"], "level": "keep",
    62	         "legal_basis": "本人特定事項。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）。顔写真は検出規則がないため fields に含まない",
    63	         "verified": true, "source": ["https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html"]}
    64	      ]
    65	    },
    66	    {
    67	      "id": "mynumber_card", "name": "マイナンバーカード（個人番号カード）", "sides": ["表", "裏"],
    68	      "fields_front": ["氏名", "住所", "生年月日", "性別", "有効期限", "顔写真", "券面記載事項追記欄", "臓器提供意思表示欄"],
    69	      "fields_back": ["個人番号", "氏名", "生年月日(要確認)", "二次元コード"],
    70	      "unverified": ["裏面の生年月日印字有無"],
    71	      "rules": [
    72	        {"field": "裏面全体", "fields": ["back_all", "my_number", "qr"],
    73	         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": ["my_number_procedure"], "level": "auto_with_purpose_gate",
    74	         "legal_basis": "番号法: 法令で認められた者・目的以外での個人番号の収集・保管禁止。身元確認目的では裏面を提出しない。コード上は 裏面全体(back_all) / 個人番号(my_number) / 二次元コード(qr) の3キーに分解する（面全体の띠 + 番号そのもの + コード）が、規則はこの1条である",
    75	         "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/", "https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true,
    76	         "gate_requires_confirmation": "my_number_procedure への解除は目的ドロップダウンだけでは足りない。提出先が法定の個人番号関係事務を行うという確認（チェックボックス1つ）を要求する — PPC FAQ は「意図せず見た」と「複写・記録」を区別するが、どちらも提出先の適法性を前提にしている"},
    77	        {"field": "表面 性別・臓器提供意思表示欄", "fields": ["sex", "organ_donor"],
    78	         "mask_when": ["identity_submit"], "level": "recommend", "legal_basis": "民間KYC運用", "source": ["https://www.aspicjapan.org/asu/article/6908"], "verified": true},
    79	        {"field": "表面 氏名・住所・生年月日・有効期限・顔写真", "fields": ["name", "birth", "address", "expiry"],
    80	         "must_keep_when": ["identity_submit", "my_number_procedure"], "optional_when": ["consult_share"], "level": "keep",
    81	         "legal_basis": "本人特定事項。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）。顔写真は検出規則がないため fields に含まない",
    82	         "verified": true, "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"]}
    83	      ]
    84	    },
    85	    {
    86	      "id": "juminhyo", "name": "住民票の写し",
    87	      "variants": ["世帯全員/一部", "個人番号 あり/なし", "本籍・筆頭者 あり/なし", "外国人住民（国籍・在留資格・在留期間・在留カード番号）", "住民票コード付（窓口のみ）"],
    88	      "rules": [
    89	        {"field": "個人番号", "fields": ["my_number"],
    90	         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": ["my_number_procedure"], "level": "auto_with_purpose_gate",
    91	         "legal_basis": "番号法 収集制限。本人確認目的なら個人番号なしの住民票を取り直すのが原則", "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"], "verified": true,
    92	         "gate_requires_confirmation": "mynumber_card 裏面全体と同じ確認を要求する"},
    93	        {"field": "住民票コード", "fields": ["jumin_code"],
    94	         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "level": "recommend",
    95	         "legal_basis": "住民基本台帳法 利用制限（個人識別符号）と理解しているが条文・運用の出典を確保できていない → verified=false。既定ON で帯を引くが『自動（auto）』とは呼ばない",
    96	         "source": [], "verified": false},
    97	        {"field": "本籍・筆頭者", "fields": ["honseki", "hittosha"],
    98	         "mask_when": ["identity_submit", "consult_share"], "optional_when": ["my_number_procedure", "bid_attachment"], "level": "recommend",
    99	         "legal_basis": "民間KYC運用（SoftBank: 住民票の本籍をマスキング）。個人番号手続・入札添付で不要という出典はないため既定ONにはしない（既定OFFで選択可）",
   100	         "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
   101	        {"field": "本人以外の世帯員", "fields": ["setaiin"],
   102	         "mask_when": ["identity_submit", "consult_share"], "optional_when": ["my_number_procedure", "bid_attachment"], "level": "recommend",
   103	         "legal_basis": "第三者情報。提出先が世帯全員を要求する場合は維持", "source": [], "verified": false},
   104	        {"field": "氏名・生年月日・住所・発行日・発行者", "fields": ["name", "birth", "address", "issuer"],
   105	         "must_keep_when": ["identity_submit", "bid_attachment"], "optional_when": ["consult_share"], "level": "keep",
   106	         "legal_basis": "本人特定事項と証明書の成立要件。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）。⚠ 既知の空白: 発行日 も 発行者(issuer) も検出規則がない — ラベルを持たない行（「見本市長 架空 太郎（公印省略）」）なので、ラベル錨ではなく 市長|区長|町長|村長 のヒューリスティックが要る。この keep 規則は現状 警告を生成できない（s3b 백로그 B-15）",
   107	         "verified": true, "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"]}
   108	      ]
   109	    }
   110	  ],
   111	  "general_jp": {
   112	    "_why": "문서 종류와 무관하게 네 문서 전부에 적용되는 두 규칙. 어느 문서도 증명해야 하는 내용이 아니므로 항상 제공(optional)하고, 공유의 목적이 상담일 때만 기본 ON(recommend). 법적 출처가 없으므로 recommend 이하만 — auto·gate 는 금지된다.",
   113	    "applies_to": ["shikaku_kakuninsho", "unten_menkyo", "mynumber_card", "juminhyo"],
   114	    "rules": [
   115	      {"field": "文書内の自由記述の住所（ラベルのない住所）", "fields": ["address_loose"],
   116	       "mask_when": ["consult_share"], "optional_when": ["identity_submit", "my_number_procedure", "bid_attachment"], "level": "recommend",
   117	       "legal_basis": "ラベル付きの 住所 とは別キー。備考欄や自由記述に残った旧住所など、提出先が要求していない住所。出典なし", "source": [], "verified": false},
   118	      {"field": "電話・FAX", "fields": ["tel"],
   119	       "mask_when": ["consult_share"], "optional_when": ["identity_submit", "my_number_procedure", "bid_attachment"], "level": "recommend",
   120	       "legal_basis": "4文書のいずれも電話番号を証明事項として持たない。出典なし", "source": [], "verified": false}
   121	    ]
   122	  },
   123	  "levels": {"auto": "文書分類+ラベル一致で自動黒塗り", "auto_with_purpose_gate": "目的選択後に自動（別目的では解除。解除には確認が必要）", "recommend": "既定ON・解除可", "optional": "既定OFF・選択可", "keep": "黒塗り禁止（警告）", "null": "この目的では UI に出さない（매트릭스가 명시하지 않은 조합）"}
   124	}
    55	    for yy in range(0, H*2, step):
    56	        for xx in range(0, int(W*2), int(tw)):
    57	            ld.text((xx, yy), text, font=f, fill=(200, 40, 40, 60))
    58	    layer = layer.rotate(25, resample=Image.BICUBIC)
    59	    base = d._image
    60	    base.alpha_composite(layer.crop((W//2, H//2, W//2+W, H//2+H)))
    61	    # 모서리 고정 표기(불투명, 작게) — 축소 삽화에서도 식별
    62	    d.text((30, H-36), "見本・架空・本人確認に使用不可", font=F(18, True), fill=(200,40,40,255))
    63	def label_val(d, x, y, label, val, lw=120, fs=20, boxes=None, key=None):
    64	    d.text((x, y), label, font=F(fs-4), fill=(90,90,90))
    65	    d.text((x+lw, y), val, font=F(fs), fill=(20,20,20))
    66	    bb = d.textbbox((x+lw, y), val, font=F(fs))
    67	    if boxes is not None and key: boxes[key] = [bb[0]-4, bb[1]-4, bb[2]+4, bb[3]+4]
    68	    return bb
    69	def finalize(img, path_base, boxes, meta):
    70	    os.makedirs(os.path.dirname(path_base), exist_ok=True)
    71	    W, H = img.size
    72	    img.convert("RGB").save(path_base + ".png")                       # 스캔풍
    73	    photo = img.convert("RGB").rotate(random.uniform(-3, 3), expand=True, fillcolor=(235,230,220))
    74	    photo = photo.filter(ImageFilter.GaussianBlur(0.6))
    75	    sh = Image.new("RGB", photo.size, (0,0,0)); photo = Image.blend(photo, sh, 0.06)
    76	    photo.save(path_base + ".jpg", quality=82)                        # 촬영풍 (회전·흐림·어두움)
    77	    c = canvas.Canvas(path_base + ".pdf", pagesize=(W*0.5, H*0.5)); c.drawImage(path_base + ".png", 0, 0, W*0.5, H*0.5); c.save()
    78	    # The purpose tables below are written once per DOCUMENT but each variant has
    79	    # its own fields (kouki has 被保険者番号 and no 記号/番号/枝番; only kenpo has
    80	    # 事業所名称). An expectation naming a box this variant does not have used to be
    81	    # reported as "skipped" by the harness — i.e. not checked, while still printing
    82	    # green. The harness now FAILS on a missing key, so the table has to be pruned
    83	    # to this variant here (Codex 5-5).
    84	    meta = dict(meta)
    85	    if "purposes" in meta:
    86	        pruned = {}
    87	        for pk, P in meta["purposes"].items():
    88	            Q = dict(P)
    89	            for kind in ("mask", "recommend", "optional", "keep"):
    90	                v = Q.get(kind)
    91	                if isinstance(v, list):
    92	                    Q[kind] = [k for k in v if k == "ALL" or k in boxes]
    93	            pruned[pk] = Q
    94	        meta["purposes"] = pruned
    95	    spec = {"file": os.path.basename(path_base), "size": [W, H], "boxes_png": boxes, **meta,
    96	            "note": "jpg는 회전·흐림 적용으로 박스 좌표 불일치 → 탐지는 OCR 좌표로 재계산, png/pdf 좌표만 골든 비교"}
    97	    json.dump(spec, open(path_base + ".specs.json", "w"), ensure_ascii=False, indent=1)
    98	
    99	# ---------- 1. 資格確認書 (카드형, 보험자 3종 변형) ----------
   100	def shikaku(variant):

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: site:ppc.go.jp all_faq_index faq5-q6-12 個人番号カード 裏面 コピー ...
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "rg -n \"jpUnclassifiedWarn|jpMnConfirm|jpLegalWarn\" public/safe/index.html
rg -n \"function maskRects|const maskRects|__maskRects|function resetAll|function afterLoad|docWrap.*display\" public/safe/index.html test/safe/run.mjs
nl -ba public/safe/index.html | sed -n '2590,2645p;2288,2320p'" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
373:              <input type="checkbox" id="jpMnConfirm">
561:  jpPurposeLabel:'제출 목적', jpBackNotice:'신원확인이 목적이라면 앞면만 제출하세요. 번호법상 법령이 인정한 사무 외의 목적으로 個人番号를 복사·보관하는 것은 제한됩니다. 「個人番号 절차」는 제출처가 법정 個人番号関係事務를 수행하는 경우에만 선택하세요.', jpKeepWarn:'제출처가 요구하는 항목입니다. 가리면 접수되지 않을 수 있습니다.', jpUnclassifiedWarn:'文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。 (문서 종류를 특정하지 못해 자동 마스킹을 적용하지 않았습니다. 가릴 영역을 직접 선택하세요.)', jpMnConfirm:'제출처가 법정 個人番号関係事務를 수행함을 확인했습니다.', jpLegalSection:'法令・提出先ルール (법령·제출처 규칙)', jpLegalWarn:'법령 근거가 있는 항목입니다. 해제하면 제출처가 보관할 수 없는 정보가 그대로 나갑니다.', keepSection:'남겨야 하는 항목',
618:  jpPurposeLabel:'Purpose of submission', jpBackNotice:'If identity is what needs checking, submit the front face only. Under the My Number Act, copying or keeping a My Number for anything other than a task the law recognises is restricted. Choose “My Number procedure” only when the recipient performs a statutory My Number task.', jpKeepWarn:'The recipient asks for this field. Hiding it may get your submission rejected.', jpUnclassifiedWarn:'文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。 (The document type could not be identified, so no automatic redaction was applied. Please select the areas to cover by hand.)', jpMnConfirm:'I confirm the recipient performs a statutory My Number (個人番号関係事務) task.', jpLegalSection:'Statutory / recipient rules (法令・提出先ルール)', jpLegalWarn:'This band has a legal basis. Releasing it sends data the recipient is not allowed to keep.', keepSection:'Fields to keep visible',
675:  jpPurposeLabel:'提出目的', jpBackNotice:'身元確認が目的なら表面のみ提出してください。番号法上、法令で認められた事務以外で個人番号を複写・保管することは制限されています。「個人番号手続」は、提出先が法定の個人番号関係事務を行う場合にのみ選んでください。', jpKeepWarn:'提出先が受付できない可能性があります（本人特定事項）。', jpUnclassifiedWarn:'文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。', jpMnConfirm:'提出先が法定の個人番号関係事務を行うことを確認しました。', jpLegalSection:'法令・提出先ルール', jpLegalWarn:'法令に根拠がある項目です。解除すると、提出先が保管できない情報がそのまま出力されます。', keepSection:'残す項目',
732:  jpPurposeLabel:'Finalidad del envío', jpBackNotice:'Si lo que hay que verificar es la identidad, envía solo el anverso. La Ley My Number restringe copiar o conservar un My Number para fines distintos de los trámites reconocidos por la ley. Elige «Trámite de My Number» solo si el destinatario realiza un trámite legal de My Number.', jpKeepWarn:'El destinatario pide este dato. Ocultarlo puede provocar el rechazo del envío.', jpUnclassifiedWarn:'文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。 (No se ha podido identificar el tipo de documento, por lo que no se aplicó ningún tachado automático. Selecciona a mano las zonas que quieras cubrir.)', jpMnConfirm:'Confirmo que el destinatario realiza un trámite legal de My Number (個人番号関係事務).', jpLegalSection:'Reglas legales / del destinatario (法令・提出先ルール)', jpLegalWarn:'Esta banda tiene base legal. Al liberarla envías datos que el destinatario no puede conservar.', keepSection:'Campos que deben quedar visibles',
1980:    warn.textContent = show ? T().jpUnclassifiedWarn : '';
1997:  const cw = $('jpMnWrap'), cb = $('jpMnConfirm');
2002:    const lb = $('jpMnLabel'); if (lb) lb.textContent = T().jpMnConfirm;
2657:  if(ent.legal && b.dataset.mode==='ok') toast(T().jpLegalWarn);
2666:  toast(hidesKeep? T().jpKeepWarn : skipsLegal? T().jpLegalWarn : b.dataset.mode==='ok'?T().tBulkOk:T().tBulkNo);
2668:$('jpMnConfirm').addEventListener('change',e=>jpSetMnConfirmed(e.target.checked));
test/safe/run.mjs:63:  window.__maskRects = function () {
test/safe/run.mjs:77:    const mr = window.__maskRects(), vr = window.__rectsFor(v);
test/safe/run.mjs:99:    const mr = window.__maskRects().filter(r => r.pi === rect.pi);
test/safe/run.mjs:149:    const mr = window.__maskRects().filter(r => r.pi === rect.pi);
test/safe/run.mjs:181:    const mr = window.__maskRects();
test/safe/run.mjs:261:      && document.getElementById('docWrap').style.display === 'flex',
public/safe/index.html:360:        <div id="docWrap" style="display:none;flex:1;min-height:0;flex-direction:column">
public/safe/index.html:2283:function afterLoad(keepEntities){
public/safe/index.html:2286:  dz.style.display='none'; $('docWrap').style.display='flex';
public/safe/index.html:2314:function resetAll(){
public/safe/index.html:2317:  $('docWrap').style.display='none'; dz.style.display='flex'; $('preview').innerHTML=''; clearDzAlert();
  2288	  $('fileInfo').textContent=T().pages(pages.length);
  2289	  if(!keepEntities){
  2290	    entities=[]; aiDone=false; showAllCats=false;
  2291	    addEntities(regexScan(docText));
  2292	    // A classified Japanese document gets its own preset. The Latin name/address
  2293	    // heuristics are suppressed there — they are tuned for résumé typography and
  2294	    // on a JP form they only ever produced junk ("(被用者", "カー", "裏面"), which
  2295	    // would sit next to the legally-grounded preset looking equally authoritative.
  2296	    const jp = jpScan();
  2297	    if(!jp){
  2298	      addEntities(nameCandidates());     // conservative top-of-doc name suggestion (defaults to visible)
  2299	      addEntities(addressCandidates());  // place/city lines without a number → review candidates
  2300	    }
  2301	    setStatus(T().scanDone(entities.filter(e=>e.kind!=='candidate').length)); setProg(0);
  2302	  }
  2303	  const ab=$('btnAI'); if(!aiDone){ ab.disabled=false; }
  2304	  buildPreview();
  2305	  if(jpState.cls){
  2306	    jpApply();
  2307	    // The status line is written before the preset runs, so on a JP document it
  2308	    // used to report "0 found" next to a list of five bands. Keep-fields are not
  2309	    // "found personal info" — they are what the recipient needs — so they do not count.
  2310	    if(!keepEntities) setStatus(T().scanDone(entities.filter(e=>e.kind!=='keep'&&e.kind!=='manual').length));
  2311	  } else { jpRenderBar(); renderAll(); }
  2312	}
  2313	function resetResult(){ $('result').style.display='none'; lastOut=null; }
  2314	function resetAll(){
  2315	  pages=[]; docText=''; entities=[]; aiDone=false; showAllCats=false; previewCanvases=[];
  2316	  jpState=JP_STATE0(); jpRenderBar();
  2317	  $('docWrap').style.display='none'; dz.style.display='flex'; $('preview').innerHTML=''; clearDzAlert();
  2318	  if(typeof setSelectMode==='function') setSelectMode(false);
  2319	  setStatus(''); setProg(0); resetResult();
  2320	  const ab=$('btnAI'); ab.disabled=true; ab.innerHTML='🤖 <span data-i18n="btnAI">'+T().btnAI+'</span>';
  2590	        </div>
  2591	        <div class="seg" role="radiogroup">
  2592	          <button class="${e.mode==='ok'?'on-ok':''}" data-id="${e.id}" data-mode="ok">${t.segOk}</button>
  2593	          <button class="${e.mode==='no'?'on-no':''}" data-id="${e.id}" data-mode="no">${t.segNo}</button>
  2594	        </div>
  2595	        ${kind==='manual'?`<button class="del" data-del="${e.id}" title="remove" aria-label="remove">✕</button>`:''}
  2596	      </div>`).join('')}</div>
  2597	  </div>`;
  2598	}
  2599	function renderList(){
  2600	  const list=$('piiList'), t=T();
  2601	  // Legal-preset bands come out of the category grouping entirely — they are not
  2602	  // a "type" the user turns off, they are a rule with a citation.
  2603	  const legalE=entities.filter(e=>e.legal);
  2604	  const autoE=entities.filter(e=>!e.legal&&e.kind!=='candidate'&&e.kind!=='manual'&&e.kind!=='keep');
  2605	  const manualE=entities.filter(e=>!e.legal&&e.kind==='manual');
  2606	  const candE=entities.filter(e=>!e.legal&&e.kind==='candidate');
  2607	  const keepE=entities.filter(e=>!e.legal&&e.kind==='keep');
  2608	  const total=entities.filter(isOn).length;
  2609	  $('piiCount').textContent= total? t.cntUse(total):'';
  2610	  document.querySelectorAll('#bulkBtns button').forEach(b=>b.disabled=!total);
  2611	  $('catHint').textContent = pages.length? t.hintAfter : t.hintBefore;
  2612	  const groups={};
  2613	  for(const e of autoE){(groups[e.type]=groups[e.type]||[]).push(e);}
  2614	  const all=Object.keys(TYPES).filter(ty=>ty!=='manual');
  2615	  if(!pages.length){
  2616	    list.innerHTML = all.map(ty=>catRowHtml(ty,[])).join('');
  2617	    return;
  2618	  }
  2619	  const hits=all.filter(ty=>groups[ty]&&groups[ty].length);
  2620	  const misses=all.filter(ty=>!groups[ty]||!groups[ty].length);
  2621	  let html=hits.map(ty=>catRowHtml(ty,groups[ty])).join('');
  2622	  if(misses.length){
  2623	    html+=`<button class="more-cats" id="moreCats">${showAllCats? t.moreHide : t.moreShow(misses.length)}</button>`;
  2624	    if(showAllCats) html+=misses.map(ty=>catRowHtml(ty,[])).join('');
  2625	  }
  2626	  if(legalE.length)  html=sectionHtml('legal', t.jpLegalSection, legalE)+html;
  2627	  if(manualE.length) html+=sectionHtml('manual', t.manualSection, manualE);
  2628	  if(candE.length)   html+=sectionHtml('candidate', t.candSection, candE);
  2629	  if(keepE.length)   html+=sectionHtml('keep', t.keepSection, keepE);
  2630	  list.innerHTML=html;
  2631	}
  2632	$('piiList').addEventListener('change',e=>{
  2633	  const cb=e.target.closest('input[data-cat]'); if(!cb) return;
  2634	  catEnabled[cb.dataset.cat]=cb.checked; renderAll();
  2635	});
  2636	$('piiList').addEventListener('click',e=>{
  2637	  if(e.target.closest('#moreCats')){showAllCats=!showAllCats;renderList();return;}
  2638	  const del=e.target.closest('button[data-del]');
  2639	  if(del){ entities=entities.filter(x=>x.id!==del.dataset.del); renderAll(); toast(T().tManualRemoved); return; }
  2640	  const cm=e.target.closest('button[data-cmode]');
  2641	  if(cm){
  2642	    const type=cm.closest('[data-cat-seg]').dataset.catSeg;
  2643	    catDefault[type]=cm.dataset.cmode;
  2644	    // Legal-preset entities are excluded: this is a per-TYPE control and the
  2645	    // statutory bands share the catch-all types. Releasing them has to be a

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "nl -ba public/safe/index.html | sed -n '2636,2672p'
nl -ba test/safe/run.mjs | sed -n '55,112p'
rg -n '\"require_legal\"|\"auto_allow\"|\"confirm_mynumber\"' test/safe/specs.json | head -40" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
  2636	$('piiList').addEventListener('click',e=>{
  2637	  if(e.target.closest('#moreCats')){showAllCats=!showAllCats;renderList();return;}
  2638	  const del=e.target.closest('button[data-del]');
  2639	  if(del){ entities=entities.filter(x=>x.id!==del.dataset.del); renderAll(); toast(T().tManualRemoved); return; }
  2640	  const cm=e.target.closest('button[data-cmode]');
  2641	  if(cm){
  2642	    const type=cm.closest('[data-cat-seg]').dataset.catSeg;
  2643	    catDefault[type]=cm.dataset.cmode;
  2644	    // Legal-preset entities are excluded: this is a per-TYPE control and the
  2645	    // statutory bands share the catch-all types. Releasing them has to be a
  2646	    // deliberate, individual act.
  2647	    entities.filter(x=>x.type===type&&!x.legal).forEach(x=>x.mode=cm.dataset.cmode);
  2648	    renderAll(); return;
  2649	  }
  2650	  const b=e.target.closest('button[data-id]'); if(!b) return;
  2651	  const ent=entities.find(x=>x.id===b.dataset.id); if(!ent) return;
  2652	  // A `keep` field is one the legal matrix says the RECIPIENT needs. Hiding it
  2653	  // is the user's call, but it must not be a silent one — the usual failure is
  2654	  // a rejected submission and a second round of sending the same document.
  2655	  if(ent.kind==='keep' && b.dataset.mode!=='ok') toast(T().jpKeepWarn);
  2656	  // The inverse: releasing a statutory band. Also the user's call, also not silent.
  2657	  if(ent.legal && b.dataset.mode==='ok') toast(T().jpLegalWarn);
  2658	  ent.mode=b.dataset.mode; renderAll();
  2659	});
  2660	$('bulkBtns').addEventListener('click',e=>{
  2661	  const b=e.target.closest('button[data-mode]'); if(!b||b.disabled) return;
  2662	  const hidesKeep = b.dataset.mode!=='ok' && entities.some(x=>isOn(x)&&x.kind==='keep');
  2663	  const skipsLegal = b.dataset.mode==='ok' && entities.some(x=>x.legal);
  2664	  // Bulk HIDE may touch legal bands (it only ever covers more); bulk SHOW may not.
  2665	  entities.filter(x=>isOn(x)&&(b.dataset.mode!=='ok'||!x.legal)).forEach(x=>x.mode=b.dataset.mode); renderAll();
  2666	  toast(hidesKeep? T().jpKeepWarn : skipsLegal? T().jpLegalWarn : b.dataset.mode==='ok'?T().tBulkOk:T().tBulkNo);
  2667	});
  2668	$('jpMnConfirm').addEventListener('change',e=>jpSetMnConfirmed(e.target.checked));
  2669	
  2670	/* ───────── AI scan (text-only; maps found strings back to boxes) ───────── */
  2671	$('btnAI').addEventListener('click',runAI);
  2672	async function runAI(){
    55	
    56	// ── in-page helpers, serialised into the browser context ──
    57	const PAGE_HELPERS = () => {
    58	  // Active mask rects: every entity that is ON, not 'ok', and located — passed
    59	  // through bandRect() so the harness measures the pixels that are ACTUALLY
    60	  // painted (box + padding), not the pre-padding estimate. This makes MUST_MASK
    61	  // easier and MUST_NOT_MASK harder, which is the honest direction: a padding
    62	  // that bleeds onto a neighbouring must-keep value now fails the golden.
    63	  window.__maskRects = function () {
    64	    const rects = [];
    65	    for (const e of entities) {
    66	      if (!isOn(e) || e.mode === 'ok' || !(e.boxes && e.boxes.length)) continue;
    67	      for (let pi = 0; pi < pages.length; pi++) {
    68	        for (const l of mergeLineBoxes(e.boxes, pi)) { const r = bandRect(l); rects.push({ pi, x: r.x, y: r.y, w: r.w, h: r.h }); }
    69	      }
    70	    }
    71	    return rects;
    72	  };
    73	  window.__rectsFor = function (v) {
    74	    return boxesForValue(v).map(b => ({ pi: b.page, x: b.x, y: b.y, w: b.w, h: b.h }));
    75	  };
    76	  window.__isMasked = function (v) {
    77	    const mr = window.__maskRects(), vr = window.__rectsFor(v);
    78	    const ov = (a, b) => {
    79	      if (a.pi !== b.pi) return 0;
    80	      const ix = Math.max(0, Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x));
    81	      const iy = Math.max(0, Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y));
    82	      return ix * iy;
    83	    };
    84	    for (const b of vr) { const area = b.w * b.h; if (area <= 0) continue; for (const a of mr) if (ov(a, b) > area * 0.25) return true; }
    85	    return false;
    86	  };
    87	  const norm = s => (s || '').toLowerCase().replace(/\s+/g, ' ').replace(/[.,;:'"()]+$/g, '').replace(/^[.,;:'"()]+/g, '').trim();
    88	  window.__norm = norm;
    89	  window.__entitySnapshot = function () {
    90	    return entities.map(e => ({ type: e.type, value: e.value, kind: e.kind, mode: e.mode, reason: e.reason, located: !!(e.boxes && e.boxes.length) }));
    91	  };
    92	  /* ── JP: geometry is checked against the FIXTURE'S OWN box table, not against
    93	     a value string. A Japanese form's value is exactly what OCR mangles
    94	     (美咲 → "S=0%"), so asserting on the string would test Tesseract, not us;
    95	     the box is what the band has to cover either way. ── */
    96	  // fraction of `rect` (page coords) covered by the union of active mask rects,
    97	  // sampled on a grid so overlapping bands count once.
    98	  window.__coverage = function (rect) {
    99	    const mr = window.__maskRects().filter(r => r.pi === rect.pi);
   100	    if (!mr.length) return 0;
   101	    const N = 24; let hit = 0;
   102	    for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) {
   103	      const x = rect.x + rect.w * (i + 0.5) / N, y = rect.y + rect.h * (j + 0.5) / N;
   104	      if (mr.some(r => x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h)) hit++;
   105	    }
   106	    return hit / (N * N);
   107	  };
   108	  // OCR/text item boxes whose centre falls inside `rect`
   109	  window.__itemsIn = function (rect) {
   110	    const p = pages[rect.pi]; if (!p) return [];
   111	    return (p.items || []).filter(it => it.x + it.w / 2 >= rect.x && it.x + it.w / 2 <= rect.x + rect.w
   112	                                     && it.y + it.h / 2 >= rect.y && it.y + it.h / 2 <= rect.y + rect.h)
274:          "require_legal": [
278:          "auto_allow": [
306:          "require_legal": [
310:          "auto_allow": [
335:          "require_legal": [
339:          "auto_allow": [
364:          "auto_allow": []
385:          "auto_allow": []
409:          "auto_allow": []
427:          "auto_allow": []
449:          "require_legal": [
452:          "auto_allow": [
464:          "confirm_mynumber": true,
468:          "auto_allow": [],
476:          "confirm_mynumber": false,
505:          "require_legal": [
508:          "auto_allow": [],
519:          "confirm_mynumber": true,
520:          "auto_allow": []
533:          "auto_allow": []
550:          "auto_allow": []
559:          "auto_allow": [],
573:          "auto_allow": []
597:          "require_legal": [
601:          "auto_allow": [
630:          "require_legal": [
634:          "auto_allow": [
663:          "auto_allow": []
686:          "require_legal": [
689:          "auto_allow": [
992:        "confirm_mynumber": true,

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
정적 추적과 법적 원문 대조를 마쳤습니다. 독립 대조기는 실제 통과했지만 전체 브라우저 하네스는 샌드박스의 localhost listen EPERM으로 실행되지 않았습니다.
  ✓ 이번 커밋 diff·직전 검토·처리표 범위 확정
  ✓ 구현·정본·대조기·하네스 정적 추적
  ✓ check_matrix 및 가능한 테스트 실행
  → 근거 줄번호와 배포 차단 판정 정리
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
  ✓ 이번 커밋 diff·직전 검토·처리표 범위 확정
  ✓ 구현·정본·대조기·하네스 정적 추적
  ✓ check_matrix 및 가능한 테스트 실행
  ✓ 근거 줄번호와 배포 차단 판정 정리
hook: PostToolUse
hook: PostToolUse Completed
2026-10-21T02:38:41.590807Z ERROR codex_models_manager::manager: failed to renew cache TTL: missing field `base_instructions` at line 139 column 5
codex
검증 결과: `node test/safe/check_matrix.mjs`는 실제 실행해 188 triple 일치로 통과했습니다. 전체 `node run.mjs`는 샌드박스가 `127.0.0.1` listen을 `EPERM`으로 막아 실행하지 못했습니다. 따라서 브라우저 하네스에 관한 평가는 정적 검토입니다.

## 발견 사항

1. 문제 / `low` 경고 문구와 실제 출력이 정면으로 모순됩니다. 저신뢰 분류의 `auto/gate`를 `recommend`로 바꾸지만 `recommend`의 `mode`는 `'no'`라 기본 출력에서 실제로 마스킹됩니다. 그런데 배너는 “자동 마스킹을 적용하지 않았다”고 단정합니다. 이는 보호적으로 동작하는 문제가 아니라 사용자가 출력 상태를 잘못 이해하게 하는 문제입니다. 제목까지 깨져 `null`이 된 경우에는 실제로 아무 JP 규칙도 실행되지 않으므로, 현재 한 문구가 서로 반대인 두 상태를 표현합니다. / 근거([public/safe/index.html:1920](/Users/sunghoon/Projects/docpack/public/safe/index.html:1920), [public/safe/index.html:1902](/Users/sunghoon/Projects/docpack/public/safe/index.html:1902), [public/safe/index.html:1980](/Users/sunghoon/Projects/docpack/public/safe/index.html:1980), [public/safe/index.html:675](/Users/sunghoon/Projects/docpack/public/safe/index.html:675)) / 수정안: `lowconf`와 `unclassified`를 별도 i18n 메시지로 나누십시오. 전자는 “분류 신뢰도가 낮아 후보 띠를 기본 적용했으니 확인 필요”, 후자는 “자동 마스킹이 적용되지 않음”이어야 합니다. 하네스도 `low`에서 `autoFields`가 비었다는 것만 보지 말고 실제 mask rect 존재와 문구를 함께 단언해야 합니다.

2. 문제 / `JP_SUSPECT_RE`의 和暦 단독 조건은 일반 일본 문서에 경고를 과다 발생시킵니다. `令和|平成|昭和`만 있어도 분류 실패 경고가 표시되므로 이력서·청구서·계약서도 “문서 종류를 특정하지 못했다”는 붉은 경고 대상입니다. 경고가 “이 네 문서 중 하나로 의심된다”는 신호가 아니라 “일본 날짜가 있다”는 신호가 되어 늑대소년 위험이 실재합니다. / 근거([public/safe/index.html:1204](/Users/sunghoon/Projects/docpack/public/safe/index.html:1204), [public/safe/index.html:1870](/Users/sunghoon/Projects/docpack/public/safe/index.html:1870)) / 수정안: 문서별 약한 키워드 두 개 이상의 조합, 또는 제목 OCR 유사도와 필드 앵커 조합으로 suspect를 제한하십시오. 적어도 和暦 단독 양성·일본어 이력서·청구서 음성 테스트를 추가해야 합니다.

3. 문제 / 다중 페이지 수정은 양면 카드 순서 문제만 고쳤고, 분류 불가 첨부 페이지를 1페이지 문서로 오분류하는 새 위험을 남겼습니다. `jpClassify(pi) || cls0` 때문에 카드와 통장 사본 등이 섞인 PDF에서 첨부 페이지가 카드 규칙을 상속하고, 카드 필드와 닮은 텍스트나 사각형을 잘못 마스킹할 수 있습니다. 이는 안전한 방향이 아니라 필수 증빙 훼손 방향입니다. / 근거([public/safe/index.html:1863](/Users/sunghoon/Projects/docpack/public/safe/index.html:1863), [public/safe/index.html:1868](/Users/sunghoon/Projects/docpack/public/safe/index.html:1868), [public/safe/index.html:1879](/Users/sunghoon/Projects/docpack/public/safe/index.html:1879)) / 수정안: 분류 불가 페이지는 `null`로 유지하십시오. 상속이 꼭 필요하다면 같은 카드의 뒷면임을 입증하는 side 전용 앵커·페이지 크기/비율·연속성 조건을 별도로 요구하십시오. 하네스에 “카드 + 무관 첨부” 음성 케이스가 필요합니다.

4. 문제 / 목적 변경 때 30페이지를 다시 OCR·추출한다는 주장은 사실이 아니지만, 렌더 비용이 괜찮다는 근거도 없습니다. `jpApply`는 기존 findings를 다시 엔티티화하고 페이지별 `back_all`을 순회할 뿐 `jpExtract`를 재실행하지 않습니다. 다만 매번 `renderAll()`까지 호출하므로 30페이지 UI 반응성은 코드만으로 판정할 수 없습니다. / 근거([public/safe/index.html:1895](/Users/sunghoon/Projects/docpack/public/safe/index.html:1895), [public/safe/index.html:1940](/Users/sunghoon/Projects/docpack/public/safe/index.html:1940), [public/safe/index.html:1948](/Users/sunghoon/Projects/docpack/public/safe/index.html:1948), [public/safe/index.html:1956](/Users/sunghoon/Projects/docpack/public/safe/index.html:1956)) / 수정안: 30페이지에서 목적 변경의 p50/p95 시간을 계측하십시오. 현재 성능 위험은 확인 불가입니다.

5. 문제 / `last:true`로 추가한 `保険者名` 등이 같은 행 뒤의 번호까지 소비하여 구조 폴백을 막을 수 있습니다. 행이 `保険者名 … 保険者番号 12345678`처럼 합쳐져 하나의 segment가 되면 `hokensha_name`은 레이블 뒤의 모든 item을 boxes로 취하고 전 tail을 `used` 처리합니다. 앞선 `hokensha_bango` 규칙은 모든 규칙이 강제로 `headOnly:true`가 되므로 행 중간의 `保険者番号`를 잡지 못합니다. 이후 6~10자리 폴백도 `unconsumed` 조건에서 탈락합니다. / 근거([public/safe/index.html:1539](/Users/sunghoon/Projects/docpack/public/safe/index.html:1539), [public/safe/index.html:1678](/Users/sunghoon/Projects/docpack/public/safe/index.html:1678), [public/safe/index.html:1724](/Users/sunghoon/Projects/docpack/public/safe/index.html:1724), [public/safe/index.html:1731](/Users/sunghoon/Projects/docpack/public/safe/index.html:1731), [public/safe/index.html:1758](/Users/sunghoon/Projects/docpack/public/safe/index.html:1758)) / 수정안: `last:true`의 끝을 다음 알려진 레이블 또는 다음 열 경계로 제한하고, keep 필드가 번호 span을 `used`로 선점하지 못하게 하십시오. 같은 행에 `保険者名`과 `保険者番号`가 있는 변이 픽스처가 필요합니다.

6. 문제 / 미명시 조합을 `null`로 버리는 정책은 `資格確認書 + my_number_procedure`에서 과도합니다. 보험자번호 계열, QR, 본인 특정사항이 모두 UI에서 사라질 수 있어 사용자는 탐지됐다는 사실도 모르고 수동 드래그만 할 수 있습니다. “정본의 침묵은 권한이 아니다”는 원칙을 “탐지 결과 자체를 숨긴다”로 구현한 것은 별개의 결정입니다. / 근거([test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:24](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:24), [test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:27](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:27), [public/safe/index.html:1505](/Users/sunghoon/Projects/docpack/public/safe/index.html:1505), [public/safe/index.html:1912](/Users/sunghoon/Projects/docpack/public/safe/index.html:1912), [public/safe/index.html:1950](/Users/sunghoon/Projects/docpack/public/safe/index.html:1950)) / 수정안: 법적 자동화 권한이 없는 조합은 `null` 대신 “탐지됨·정책 미확정·기본 OFF”인 별도 상태로 노출하십시오. 자동 마스킹 여부와 UI 노출 여부를 한 level 값으로 합치지 마십시오.

7. 문제 / 정본에 출처 없는 `must_keep`을 추가한 것은 “코드 일탈의 정본 승격”입니다. `事業所名称・保険者名・資格取得年月日`을 “자격 유효성 확인 항목”이라는 구현자 판단만으로 `identity_submit`과 `bid_attachment`에서 keep 처리합니다. `verified:false`는 자동 삭제만 막을 뿐, “가리면 접수 거절 가능” 경고라는 제품 행동을 막지 않습니다. / 근거([test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:38](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:38), [test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:40](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:40), [public/safe/index.html:1458](/Users/sunghoon/Projects/docpack/public/safe/index.html:1458)) / 수정안: 출처 없는 항목은 `keep`이 아니라 중립적인 “제출처 확인 필요” 상태로 분리하십시오. 정본은 코드와의 일치를 위한 표가 아니라 외부 근거와 제품 결정을 구분해 기록해야 합니다.

8. 문제 / `check_matrix`는 `発行日` 누락을 영구적으로 보지 못합니다. 정본의 사람이 읽는 필드명은 `氏名・生年月日・住所・発行日・発行者`지만 코드 키 배열은 `issuer` 하나만 두었고, 대조기는 `field` 문자열을 무시하고 `fields`만 비교합니다. 게다가 실제 `issuer` 탐지 규칙도 없습니다. 따라서 188 triple 통과는 이 keep 약속의 실행 가능성을 전혀 증명하지 않습니다. / 근거([test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:104](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:104), [test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:106](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:106), [test/safe/check_matrix.mjs:47](/Users/sunghoon/Projects/docpack/test/safe/check_matrix.mjs:47), [public/safe/index.html:1560](/Users/sunghoon/Projects/docpack/public/safe/index.html:1560)) / 수정안: `issue`와 `issuer`를 각각 `fields`에 명시하고, 각 코드 키가 detector 또는 의도적인 `undetectable` 선언 중 하나를 갖는지 검사하십시오. 지금처럼 “알려진 공백”을 설명문에만 쓰는 것은 실행 가능한 정본이 아닙니다.

9. 문제 / 대조기의 문자열 슬라이스는 조용히 통과하지는 않지만, 포맷에 취약하고 `compared < 100`은 완전성 경계가 아닙니다. 현재 종료 마커는 열 1에서 처음 나타나는 `};`에 의존합니다. 중간에 같은 형태의 상수를 추가하면 잘못 잘라 평가 실패하므로 CI는 빨개지지만, 단순 들여쓰기 변경도 실패 원인이 됩니다. 반대로 매트릭스와 코드에서 문서나 필드를 함께 삭제해도 triple이 100 이상이면 통과합니다. / 근거([test/safe/check_matrix.mjs:65](/Users/sunghoon/Projects/docpack/test/safe/check_matrix.mjs:65), [test/safe/check_matrix.mjs:73](/Users/sunghoon/Projects/docpack/test/safe/check_matrix.mjs:73), [test/safe/check_matrix.mjs:111](/Users/sunghoon/Projects/docpack/test/safe/check_matrix.mjs:111)) / 수정안: 구조화된 JS 모듈/JSON 생성물로 규칙을 공유하거나 AST로 선언 노드를 추출하십시오. 최소한 예상 문서 ID, 목적 수, 필드 집합과 정확한 triple 수를 명시적으로 고정해야 합니다.

10. 문제 / `JP_LEGAL_FIELDS` 검증은 “어딘가의 매트릭스에 같은 필드명이 있음”만 확인해 법적 그룹의 의미를 보장하지 않습니다. 문서·목적·`verified`·법적 출처를 보지 않습니다. 실제로 `verified:false`인 `jumin_code`도 legal 그룹에 들어가고, UI는 이를 풀면 “제출처가 보관할 수 없는 정보”라고 단정합니다. 정본은 바로 그 법적 출처를 확보하지 못했다고 씁니다. / 근거([public/safe/index.html:1503](/Users/sunghoon/Projects/docpack/public/safe/index.html:1503), [test/safe/check_matrix.mjs:113](/Users/sunghoon/Projects/docpack/test/safe/check_matrix.mjs:113), [test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:93](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:93), [public/safe/index.html:675](/Users/sunghoon/Projects/docpack/public/safe/index.html:675)) / 수정안: legal 여부를 문자열 Set에서 파생하지 말고 정본의 명시적 `legal_enforcement` 속성으로 문서·목적별 생성하십시오. `verified:false` 항목에는 법적 금지 문구를 표시하지 마십시오.

11. 문제 / 법적 안내와 확인 체크박스가 사용자가 확인하기 어려운 사실을 단정하게 합니다. PPC Q6-12는 단순 열람과 복사·기록을 구분하고, 복사 시에도 “위반할 가능성”이라고 설명합니다. 현 UI의 “제출처가 보관할 수 없다”, “법정 個人番号関係事務를 수행함을 확인했다”는 문구는 수신자의 법적 지위와 구체적 사무를 사용자가 판단했다고 간주합니다. 특히 단순 세무·복지 관련처럼 보인다는 이유만으로는 個人番号関係事務 해당성이 보장되지 않습니다. [PPC Q6-12](https://www.ppc.go.jp/all_faq_index/faq5-q6-12/)도 체크박스 같은 사용자 확인을 적법성 증명 수단으로 제시하지 않습니다. / 근거([public/safe/index.html:561](/Users/sunghoon/Projects/docpack/public/safe/index.html:561), [public/safe/index.html:675](/Users/sunghoon/Projects/docpack/public/safe/index.html:675), [test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:76](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:76)) / 수정안: “제출처 안내문에서 個人番号 제출을 명시적으로 요구하는지 확인했습니다”처럼 사용자가 실제 확인 가능한 사실로 바꾸고, 수신처 요구가 없으면 해제하지 말라는 안내를 붙이십시오. 법률 효과는 “위반할 수 있음” 수준으로 표현해야 합니다.

12. 문제 / 個人番号가 없는 문서에서 `my_number_procedure`를 선택하면 목적만 바뀌고 아무 설명이 없습니다. 체크박스와 안내는 `hasMn`일 때만 보이고, 미명시 필드는 `null`로 사라질 수 있습니다. 사용자는 목적 변경이 적용됐지만 결과가 왜 비었는지 알 수 없습니다. 문서 교체 시 `resetAll → JP_STATE0`으로 확인 상태가 초기화되는 부분 자체는 정상입니다. / 근거([public/safe/index.html:1993](/Users/sunghoon/Projects/docpack/public/safe/index.html:1993), [public/safe/index.html:1999](/Users/sunghoon/Projects/docpack/public/safe/index.html:1999), [public/safe/index.html:2314](/Users/sunghoon/Projects/docpack/public/safe/index.html:2314)) / 수정안: 해당 문서에 목적별 규칙이 하나도 없으면 목적 옵션을 비활성화하거나 “이 문서에는 이 목적용 규칙이 없습니다” 상태를 표시하십시오.

13. 문제 / `__fieldBands.inMask`는 `on && mode !== ok && located`를 검사한 뒤에는 사실상 동어반복입니다. `__maskRects`와 `__fieldBands`가 동일한 `mergeLineBoxes + bandRect`를 같은 entity에 적용합니다. `inMask`가 거짓이 될 수 있는 정상 경로는 category OFF, `mode='ok'`, boxes 없음이며, 이미 별도 속성으로 검사합니다. 따라서 독립적인 렌더·좌표 검증을 추가하지 못했습니다. / 근거([test/safe/run.mjs:63](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:63), [test/safe/run.mjs:180](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:180), [test/safe/run.mjs:185](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:185), [test/safe/run.mjs:603](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:603)) / 수정안: 실제 preview/output canvas 픽셀을 entity 기대 rect에서 검사하거나, 최소한 독립적인 fixture box와 mask rect의 중첩을 측정하십시오. 현 단언은 `isOn`·`mode` 검사의 중복이라고 기록해야 합니다.

14. 문제 / 레이블 없는 블록 테스트의 “labelled code still banded”는 빈 배열에서도 통과합니다. `filter(...).every(...)`는 대상이 0개면 `true`이므로 labelled QR 탐지가 완전히 사라져도 녹색입니다. / 근거([test/safe/run.mjs:850](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:850), [test/safe/run.mjs:857](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:857)) / 수정안: 필터 결과의 `length > 0`을 먼저 요구하십시오.

15. 문제 / `__inkCover` 임계값들은 픽스처 맞춤값이며 실제 스캔 일반화 근거가 없습니다. 배경 대비 60은 흐린 회색 숫자나 저대비 스캔 글자를 잉크에서 제외할 수 있고, 6픽셀 미만 성분 제거는 점·가느다란 `1`·분리된 안티앨리어싱 조각을 무시할 수 있습니다. 99%는 “모든 글자가 판독 불가”와 연결되는 근거가 없습니다. 반면 성분 0을 실패시키는 방향은 공허한 통과를 막으므로 올바릅니다. / 근거([test/safe/run.mjs:132](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:132), [test/safe/run.mjs:147](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:147), [test/safe/run.mjs:167](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:167), [test/safe/run.mjs:171](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:171), [test/safe/run.mjs:546](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:546)) / 수정안: 저대비·작은 글꼴·JPEG artifact 변이에서 원문 숫자 단위의 잔존 판독 가능성을 검증하십시오. 고정 RGB 차이 대신 국소 대비/이진화와 OCR 재판독을 병행하십시오.

16. 문제 / `auto_allow`의 `[]`와 `undefined` 구분은 실제로 성립하지만, 비어 있지 않은 allowlist는 “부분집합”만 확인합니다. 자동 필드가 전부 사라져 빈 배열이 되어도 `bad.length === 0`으로 통과합니다. 별도의 `min_auto`나 `require_banded`가 모든 allowlist 필드를 포괄하지 않는 케이스에서는 미탐을 숨깁니다. / 근거([test/safe/run.mjs:636](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:636), [test/safe/run.mjs:638](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:638)) / 수정안: 기대가 정확한 케이스는 집합 동등성을 검사하고, 선택적 필드가 있다면 `required_auto`와 `allowed_auto`를 분리하십시오.

17. 문제 / 합성 분류·個人番号 테스트는 정책 배선만 증명하고 OCR 강건성을 증명하지 않습니다. `loadFromText`는 완벽한 텍스트와 박스를 생성하므로 OCR 오인식, item 분절, 줄 병합, 회전·압축을 통과하지 않습니다. 다중 페이지 테스트도 원본 PNG를 JPEG로 재인코딩한 동일 도식 픽스처 두 장이므로 “페이지별 분류” 회귀는 잡지만 현실의 양면 카드 PDF 대표성은 없습니다. / 근거([test/safe/run.mjs:783](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:783), [test/safe/run.mjs:803](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:803), [test/safe/run.mjs:733](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:733), [test/safe/run.mjs:741](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:741)) / 수정안: 합성 테스트의 보장 범위를 “분류/정책 wiring”으로 명시하고, 저해상도·회전·배경·서로 다른 앞뒷면 스캔 조건을 가진 고정 PDF 픽스처를 별도로 추가하십시오.

18. 문제 / 카테고리 복원은 정상 경로만 처리하고 `try/finally`가 없습니다. `__allCatsOff()` 이후 browser evaluation, reload 또는 assertion 코드가 예외를 던지면 `__restoreCats()`에 도달하지 않아 이후 케이스 전체가 오염됩니다. 구현자가 이미 같은 전역 누출을 한 번 겪었다는 점에서 이 경로를 남길 이유가 없습니다. / 근거([test/safe/run.mjs:620](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:620), [test/safe/run.mjs:628](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:628), [test/safe/run.mjs:630](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:630)) / 수정안: 각 legal 단언을 `try/finally`로 감싸고 finally에서 복원 및 검증하십시오. 더 안전하게는 테스트별 새 page/context를 쓰십시오.

19. 문제 / `legal`은 사용자가 개별 공개해도 그대로 남아 법적 그룹과 카운트에 계속 포함됩니다. 출력 마스크에서는 `mode='ok'`라 빠지므로 보안상 즉시 어긋나지는 않지만, “법적 띠” 그룹의 공개된 항목과 `isOn`이 항상 true인 상태가 혼재합니다. 카테고리 체크박스가 legal 항목에 적용되지 않는 것은 이번 결함을 막는 방향이지만, UI는 왜 꺼도 남는지 설명하지 않습니다. / 근거([public/safe/index.html:797](/Users/sunghoon/Projects/docpack/public/safe/index.html:797), [public/safe/index.html:1904](/Users/sunghoon/Projects/docpack/public/safe/index.html:1904), [public/safe/index.html:2603](/Users/sunghoon/Projects/docpack/public/safe/index.html:2603), [public/safe/index.html:2657](/Users/sunghoon/Projects/docpack/public/safe/index.html:2657)) / 수정안: 그룹 제목을 “법적 근거가 있는 검토 항목”처럼 상태와 분리하고, category 토글 옆에 법적 항목은 개별 제어된다고 명시하십시오. `legal`을 mode에 따라 제거할 필요는 없지만 그룹 내부에 공개/비공개 상태를 분명히 표시해야 합니다.

20. 문제 / `legal` 조건을 `mode==='no'`로 제한해 레이블 없는 QR을 법적 그룹에서 빼는 것은 정책상 일관되지 않습니다. 동일한 `qr`가 레이블 인식 여부 하나로 “법령·제출처 규칙”과 일반 후보 사이를 이동합니다. 다만 불확실 탐지를 법적 확정 항목으로 표시하지 않는 방향 자체는 안전합니다. / 근거([public/safe/index.html:1904](/Users/sunghoon/Projects/docpack/public/safe/index.html:1904), [public/safe/index.html:1932](/Users/sunghoon/Projects/docpack/public/safe/index.html:1932), [public/safe/index.html:2603](/Users/sunghoon/Projects/docpack/public/safe/index.html:2603)) / 수정안: “법적 규칙”과 “탐지 신뢰도”를 별도 속성으로 보존하고, 후보 그룹에서 “QR일 경우 동일 법적 제한 대상일 수 있음”을 표시하십시오.

21. 문제 / 레이블 없는 코드 블록을 `optional`로 내린 교환은 오탐 방지에는 맞지만, 資格確認書의 번호 누출 관점에서는 미탐 쪽으로 이동했습니다. 현재 detector는 finder pattern, quiet zone, module 주기를 전혀 보지 않으므로 이를 곧바로 기본 ON으로 승격할 근거는 없습니다. 그 특징들은 구현 가능한 값싼 증거지만 임계값의 정밀도와 오탐률은 진짜 QR/바코드 및 사진·인감 음성 픽스처 없이는 확인 불가입니다. / 근거([public/safe/index.html:1810](/Users/sunghoon/Projects/docpack/public/safe/index.html:1810), [public/safe/index.html:1927](/Users/sunghoon/Projects/docpack/public/safe/index.html:1927)) / 수정안: 지금은 optional을 유지하되, 코드 후보가 존재하면 별도 눈에 띄는 경고를 띄우십시오. 이후 실제 코드 픽스처와 비코드 사각형 음성군을 먼저 만들고 finder/quiet-zone 기반 승격을 도입하십시오.

22. 문제 / `general_jp.applies_to`는 문서 추가 시 수동 갱신 누락이 조용히 가능합니다. 새 문서를 `documents`와 `JP_RULES`에 추가하면서 `JP_EXTRA`를 spread하지 않으면 대조기는 양쪽 모두에 일반 규칙이 없다고 보고 통과할 수 있습니다. / 근거([test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:111](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:111), [test/safe/check_matrix.mjs:59](/Users/sunghoon/Projects/docpack/test/safe/check_matrix.mjs:59), [public/safe/index.html:1440](/Users/sunghoon/Projects/docpack/public/safe/index.html:1440)) / 수정안: “모든 documents”가 의도라면 `applies_to:"*"`로 표현하거나 대조기에서 documents ID 집합과 `applies_to`의 정확한 동등성을 검사하십시오.

23. 문제 / `keep:"all"` 수정은 현재 도달하지 않아 회귀 방지로 인정할 수 없습니다. 값싼 도달 방법은 새 제품 목적을 만들 필요 없이 하네스 유닛에서 fixture metadata를 읽어 `Object.keys(boxes_png)`로 확장되는지 테스트하거나, 테스트 전용 케이스에서 기존 `医療機関提示` 목적표를 직접 검사하는 것입니다. / 근거([test/safe/run.mjs:677](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:677), [test/safe/fixtures/jp/gen.py:130](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/gen.py:130), [docs/jp/s3b_report.md:202](/Users/sunghoon/Projects/docpack/docs/jp/s3b_report.md:202)) / 수정안: 순수 함수로 기대 키 확장을 분리해 단위 테스트하거나 `医療機関提示`를 하네스 전용 목적 케이스로 실행하십시오.

24. 문제 / variant 가지치기 자체는 `kouki`의 존재하지 않는 `kigo/bango/edaban` 기대를 제거하므로 타당하지만, 생성 시 양쪽 표가 같이 줄어드는 구조라 실제 픽스처 생성 누락도 정상으로 승인할 수 있습니다. 예컨대 실수로 `hihokensha_bango` 박스 생성을 지우면 기대표에서도 자동 삭제됩니다. / 근거([test/safe/fixtures/jp/gen.py:78](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/gen.py:78), [test/safe/fixtures/jp/gen.py:89](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/gen.py:89), [test/safe/fixtures/jp/gen.py:107](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/gen.py:107)) / 수정안: variant별 필수 필드 schema를 별도로 두고 생성된 `boxes`가 그것을 포함하는지 assert한 뒤 가지치기하십시오. `kouki`에 `kigo/bango/edaban`이 없다는 것은 현재 생성 코드상 맞습니다.

25. 문제 / ko/en/es의 경고가 일본어 원문과 번역을 한 문자열로 중복 표시합니다. 법적 고유명사를 병기하는 것과 전체 경고문을 일본어로 먼저 노출하는 것은 다릅니다. 좁은 모바일 배너에서 핵심 행동 지침을 늦추고 언어별 접근성을 악화합니다. / 근거([public/safe/index.html:561](/Users/sunghoon/Projects/docpack/public/safe/index.html:561), [public/safe/index.html:618](/Users/sunghoon/Projects/docpack/public/safe/index.html:618), [public/safe/index.html:732](/Users/sunghoon/Projects/docpack/public/safe/index.html:732)) / 수정안: 각 locale에는 해당 언어만 표시하고, 필요한 고유명사만 일본어를 괄호 병기하십시오.

## 배포 차단 4건 판정

- 분류 실패 경고: **부분 해소** — 완전 무경고는 막았지만 `low`에서 문구와 실제 기본 마스킹이 모순되고 和暦 단독 오경고가 과다합니다.
- 레이블 없는 블록: **부분 해소** — 무근거 기본 마스킹은 제거했지만 실제 코드 후보 경고와 detector 통합 커버리지가 없고, 하네스의 labelled-code 역단언도 공허합니다.
- 다중 페이지: **부분 해소** — 앞/뒤 순서 문제는 고쳤지만 분류 불가 첨부의 `cls0` 상속이 남았습니다.
- 법적 그룹: **부분 해소** — category 토글로 조용히 사라지는 문제는 막았지만, `verified:false`까지 법적 금지로 표시하고 UI 문구가 과도합니다.
- 정본 불일치: **부분 해소** — 188 triple은 일치하지만 `発行日`·detector 존재 여부·법적 속성은 대조하지 않습니다.
- 하네스 강화: **부분 해소** — 여러 공허한 경로를 줄였으나 `__fieldBands.inMask` 동어반복, 빈 `.every()`, subset-only allowlist, 예외 시 전역 오염이 남았습니다.

## 즉시 고쳐야 할 상위 5개

1. **AMBER · 배포 전** — 분류 불가 첨부 페이지에 `cls0`을 상속하는 다중 페이지 오분류 제거.
2. **AMBER · 배포 전** — `lowconf` 경고 문구와 실제 기본 ON 띠의 모순 해소 및 和暦 단독 suspect 제거.
3. **AMBER · 배포 전** — `last:true` keep 필드가 같은 행의 保険者番号를 소비해 미탐시키는 경계 수정.
4. **AMBER · 배포 전** — `verified:false`인 `jumin_code`를 법적 금지 그룹·단정적 안내에서 제외하고 個人番号 확인 문구를 사용자가 검증 가능한 사실로 변경.
5. **GREEN · 다음 런** — 하네스의 동어반복 `inMask`, 빈 `.every()`, exact auto-set 부재, `try/finally` 없는 category 복원을 보강하고 실제 QR·혼합 PDF·저대비 스캔 픽스처 추가.
hook: Stop
hook: Stop Completed
tokens used
106,892
검증 결과: `node test/safe/check_matrix.mjs`는 실제 실행해 188 triple 일치로 통과했습니다. 전체 `node run.mjs`는 샌드박스가 `127.0.0.1` listen을 `EPERM`으로 막아 실행하지 못했습니다. 따라서 브라우저 하네스에 관한 평가는 정적 검토입니다.

## 발견 사항

1. 문제 / `low` 경고 문구와 실제 출력이 정면으로 모순됩니다. 저신뢰 분류의 `auto/gate`를 `recommend`로 바꾸지만 `recommend`의 `mode`는 `'no'`라 기본 출력에서 실제로 마스킹됩니다. 그런데 배너는 “자동 마스킹을 적용하지 않았다”고 단정합니다. 이는 보호적으로 동작하는 문제가 아니라 사용자가 출력 상태를 잘못 이해하게 하는 문제입니다. 제목까지 깨져 `null`이 된 경우에는 실제로 아무 JP 규칙도 실행되지 않으므로, 현재 한 문구가 서로 반대인 두 상태를 표현합니다. / 근거([public/safe/index.html:1920](/Users/sunghoon/Projects/docpack/public/safe/index.html:1920), [public/safe/index.html:1902](/Users/sunghoon/Projects/docpack/public/safe/index.html:1902), [public/safe/index.html:1980](/Users/sunghoon/Projects/docpack/public/safe/index.html:1980), [public/safe/index.html:675](/Users/sunghoon/Projects/docpack/public/safe/index.html:675)) / 수정안: `lowconf`와 `unclassified`를 별도 i18n 메시지로 나누십시오. 전자는 “분류 신뢰도가 낮아 후보 띠를 기본 적용했으니 확인 필요”, 후자는 “자동 마스킹이 적용되지 않음”이어야 합니다. 하네스도 `low`에서 `autoFields`가 비었다는 것만 보지 말고 실제 mask rect 존재와 문구를 함께 단언해야 합니다.

2. 문제 / `JP_SUSPECT_RE`의 和暦 단독 조건은 일반 일본 문서에 경고를 과다 발생시킵니다. `令和|平成|昭和`만 있어도 분류 실패 경고가 표시되므로 이력서·청구서·계약서도 “문서 종류를 특정하지 못했다”는 붉은 경고 대상입니다. 경고가 “이 네 문서 중 하나로 의심된다”는 신호가 아니라 “일본 날짜가 있다”는 신호가 되어 늑대소년 위험이 실재합니다. / 근거([public/safe/index.html:1204](/Users/sunghoon/Projects/docpack/public/safe/index.html:1204), [public/safe/index.html:1870](/Users/sunghoon/Projects/docpack/public/safe/index.html:1870)) / 수정안: 문서별 약한 키워드 두 개 이상의 조합, 또는 제목 OCR 유사도와 필드 앵커 조합으로 suspect를 제한하십시오. 적어도 和暦 단독 양성·일본어 이력서·청구서 음성 테스트를 추가해야 합니다.

3. 문제 / 다중 페이지 수정은 양면 카드 순서 문제만 고쳤고, 분류 불가 첨부 페이지를 1페이지 문서로 오분류하는 새 위험을 남겼습니다. `jpClassify(pi) || cls0` 때문에 카드와 통장 사본 등이 섞인 PDF에서 첨부 페이지가 카드 규칙을 상속하고, 카드 필드와 닮은 텍스트나 사각형을 잘못 마스킹할 수 있습니다. 이는 안전한 방향이 아니라 필수 증빙 훼손 방향입니다. / 근거([public/safe/index.html:1863](/Users/sunghoon/Projects/docpack/public/safe/index.html:1863), [public/safe/index.html:1868](/Users/sunghoon/Projects/docpack/public/safe/index.html:1868), [public/safe/index.html:1879](/Users/sunghoon/Projects/docpack/public/safe/index.html:1879)) / 수정안: 분류 불가 페이지는 `null`로 유지하십시오. 상속이 꼭 필요하다면 같은 카드의 뒷면임을 입증하는 side 전용 앵커·페이지 크기/비율·연속성 조건을 별도로 요구하십시오. 하네스에 “카드 + 무관 첨부” 음성 케이스가 필요합니다.

4. 문제 / 목적 변경 때 30페이지를 다시 OCR·추출한다는 주장은 사실이 아니지만, 렌더 비용이 괜찮다는 근거도 없습니다. `jpApply`는 기존 findings를 다시 엔티티화하고 페이지별 `back_all`을 순회할 뿐 `jpExtract`를 재실행하지 않습니다. 다만 매번 `renderAll()`까지 호출하므로 30페이지 UI 반응성은 코드만으로 판정할 수 없습니다. / 근거([public/safe/index.html:1895](/Users/sunghoon/Projects/docpack/public/safe/index.html:1895), [public/safe/index.html:1940](/Users/sunghoon/Projects/docpack/public/safe/index.html:1940), [public/safe/index.html:1948](/Users/sunghoon/Projects/docpack/public/safe/index.html:1948), [public/safe/index.html:1956](/Users/sunghoon/Projects/docpack/public/safe/index.html:1956)) / 수정안: 30페이지에서 목적 변경의 p50/p95 시간을 계측하십시오. 현재 성능 위험은 확인 불가입니다.

5. 문제 / `last:true`로 추가한 `保険者名` 등이 같은 행 뒤의 번호까지 소비하여 구조 폴백을 막을 수 있습니다. 행이 `保険者名 … 保険者番号 12345678`처럼 합쳐져 하나의 segment가 되면 `hokensha_name`은 레이블 뒤의 모든 item을 boxes로 취하고 전 tail을 `used` 처리합니다. 앞선 `hokensha_bango` 규칙은 모든 규칙이 강제로 `headOnly:true`가 되므로 행 중간의 `保険者番号`를 잡지 못합니다. 이후 6~10자리 폴백도 `unconsumed` 조건에서 탈락합니다. / 근거([public/safe/index.html:1539](/Users/sunghoon/Projects/docpack/public/safe/index.html:1539), [public/safe/index.html:1678](/Users/sunghoon/Projects/docpack/public/safe/index.html:1678), [public/safe/index.html:1724](/Users/sunghoon/Projects/docpack/public/safe/index.html:1724), [public/safe/index.html:1731](/Users/sunghoon/Projects/docpack/public/safe/index.html:1731), [public/safe/index.html:1758](/Users/sunghoon/Projects/docpack/public/safe/index.html:1758)) / 수정안: `last:true`의 끝을 다음 알려진 레이블 또는 다음 열 경계로 제한하고, keep 필드가 번호 span을 `used`로 선점하지 못하게 하십시오. 같은 행에 `保険者名`과 `保険者番号`가 있는 변이 픽스처가 필요합니다.

6. 문제 / 미명시 조합을 `null`로 버리는 정책은 `資格確認書 + my_number_procedure`에서 과도합니다. 보험자번호 계열, QR, 본인 특정사항이 모두 UI에서 사라질 수 있어 사용자는 탐지됐다는 사실도 모르고 수동 드래그만 할 수 있습니다. “정본의 침묵은 권한이 아니다”는 원칙을 “탐지 결과 자체를 숨긴다”로 구현한 것은 별개의 결정입니다. / 근거([test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:24](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:24), [test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:27](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:27), [public/safe/index.html:1505](/Users/sunghoon/Projects/docpack/public/safe/index.html:1505), [public/safe/index.html:1912](/Users/sunghoon/Projects/docpack/public/safe/index.html:1912), [public/safe/index.html:1950](/Users/sunghoon/Projects/docpack/public/safe/index.html:1950)) / 수정안: 법적 자동화 권한이 없는 조합은 `null` 대신 “탐지됨·정책 미확정·기본 OFF”인 별도 상태로 노출하십시오. 자동 마스킹 여부와 UI 노출 여부를 한 level 값으로 합치지 마십시오.

7. 문제 / 정본에 출처 없는 `must_keep`을 추가한 것은 “코드 일탈의 정본 승격”입니다. `事業所名称・保険者名・資格取得年月日`을 “자격 유효성 확인 항목”이라는 구현자 판단만으로 `identity_submit`과 `bid_attachment`에서 keep 처리합니다. `verified:false`는 자동 삭제만 막을 뿐, “가리면 접수 거절 가능” 경고라는 제품 행동을 막지 않습니다. / 근거([test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:38](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:38), [test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:40](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:40), [public/safe/index.html:1458](/Users/sunghoon/Projects/docpack/public/safe/index.html:1458)) / 수정안: 출처 없는 항목은 `keep`이 아니라 중립적인 “제출처 확인 필요” 상태로 분리하십시오. 정본은 코드와의 일치를 위한 표가 아니라 외부 근거와 제품 결정을 구분해 기록해야 합니다.

8. 문제 / `check_matrix`는 `発行日` 누락을 영구적으로 보지 못합니다. 정본의 사람이 읽는 필드명은 `氏名・生年月日・住所・発行日・発行者`지만 코드 키 배열은 `issuer` 하나만 두었고, 대조기는 `field` 문자열을 무시하고 `fields`만 비교합니다. 게다가 실제 `issuer` 탐지 규칙도 없습니다. 따라서 188 triple 통과는 이 keep 약속의 실행 가능성을 전혀 증명하지 않습니다. / 근거([test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:104](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:104), [test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:106](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:106), [test/safe/check_matrix.mjs:47](/Users/sunghoon/Projects/docpack/test/safe/check_matrix.mjs:47), [public/safe/index.html:1560](/Users/sunghoon/Projects/docpack/public/safe/index.html:1560)) / 수정안: `issue`와 `issuer`를 각각 `fields`에 명시하고, 각 코드 키가 detector 또는 의도적인 `undetectable` 선언 중 하나를 갖는지 검사하십시오. 지금처럼 “알려진 공백”을 설명문에만 쓰는 것은 실행 가능한 정본이 아닙니다.

9. 문제 / 대조기의 문자열 슬라이스는 조용히 통과하지는 않지만, 포맷에 취약하고 `compared < 100`은 완전성 경계가 아닙니다. 현재 종료 마커는 열 1에서 처음 나타나는 `};`에 의존합니다. 중간에 같은 형태의 상수를 추가하면 잘못 잘라 평가 실패하므로 CI는 빨개지지만, 단순 들여쓰기 변경도 실패 원인이 됩니다. 반대로 매트릭스와 코드에서 문서나 필드를 함께 삭제해도 triple이 100 이상이면 통과합니다. / 근거([test/safe/check_matrix.mjs:65](/Users/sunghoon/Projects/docpack/test/safe/check_matrix.mjs:65), [test/safe/check_matrix.mjs:73](/Users/sunghoon/Projects/docpack/test/safe/check_matrix.mjs:73), [test/safe/check_matrix.mjs:111](/Users/sunghoon/Projects/docpack/test/safe/check_matrix.mjs:111)) / 수정안: 구조화된 JS 모듈/JSON 생성물로 규칙을 공유하거나 AST로 선언 노드를 추출하십시오. 최소한 예상 문서 ID, 목적 수, 필드 집합과 정확한 triple 수를 명시적으로 고정해야 합니다.

10. 문제 / `JP_LEGAL_FIELDS` 검증은 “어딘가의 매트릭스에 같은 필드명이 있음”만 확인해 법적 그룹의 의미를 보장하지 않습니다. 문서·목적·`verified`·법적 출처를 보지 않습니다. 실제로 `verified:false`인 `jumin_code`도 legal 그룹에 들어가고, UI는 이를 풀면 “제출처가 보관할 수 없는 정보”라고 단정합니다. 정본은 바로 그 법적 출처를 확보하지 못했다고 씁니다. / 근거([public/safe/index.html:1503](/Users/sunghoon/Projects/docpack/public/safe/index.html:1503), [test/safe/check_matrix.mjs:113](/Users/sunghoon/Projects/docpack/test/safe/check_matrix.mjs:113), [test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:93](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:93), [public/safe/index.html:675](/Users/sunghoon/Projects/docpack/public/safe/index.html:675)) / 수정안: legal 여부를 문자열 Set에서 파생하지 말고 정본의 명시적 `legal_enforcement` 속성으로 문서·목적별 생성하십시오. `verified:false` 항목에는 법적 금지 문구를 표시하지 마십시오.

11. 문제 / 법적 안내와 확인 체크박스가 사용자가 확인하기 어려운 사실을 단정하게 합니다. PPC Q6-12는 단순 열람과 복사·기록을 구분하고, 복사 시에도 “위반할 가능성”이라고 설명합니다. 현 UI의 “제출처가 보관할 수 없다”, “법정 個人番号関係事務를 수행함을 확인했다”는 문구는 수신자의 법적 지위와 구체적 사무를 사용자가 판단했다고 간주합니다. 특히 단순 세무·복지 관련처럼 보인다는 이유만으로는 個人番号関係事務 해당성이 보장되지 않습니다. [PPC Q6-12](https://www.ppc.go.jp/all_faq_index/faq5-q6-12/)도 체크박스 같은 사용자 확인을 적법성 증명 수단으로 제시하지 않습니다. / 근거([public/safe/index.html:561](/Users/sunghoon/Projects/docpack/public/safe/index.html:561), [public/safe/index.html:675](/Users/sunghoon/Projects/docpack/public/safe/index.html:675), [test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:76](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:76)) / 수정안: “제출처 안내문에서 個人番号 제출을 명시적으로 요구하는지 확인했습니다”처럼 사용자가 실제 확인 가능한 사실로 바꾸고, 수신처 요구가 없으면 해제하지 말라는 안내를 붙이십시오. 법률 효과는 “위반할 수 있음” 수준으로 표현해야 합니다.

12. 문제 / 個人番号가 없는 문서에서 `my_number_procedure`를 선택하면 목적만 바뀌고 아무 설명이 없습니다. 체크박스와 안내는 `hasMn`일 때만 보이고, 미명시 필드는 `null`로 사라질 수 있습니다. 사용자는 목적 변경이 적용됐지만 결과가 왜 비었는지 알 수 없습니다. 문서 교체 시 `resetAll → JP_STATE0`으로 확인 상태가 초기화되는 부분 자체는 정상입니다. / 근거([public/safe/index.html:1993](/Users/sunghoon/Projects/docpack/public/safe/index.html:1993), [public/safe/index.html:1999](/Users/sunghoon/Projects/docpack/public/safe/index.html:1999), [public/safe/index.html:2314](/Users/sunghoon/Projects/docpack/public/safe/index.html:2314)) / 수정안: 해당 문서에 목적별 규칙이 하나도 없으면 목적 옵션을 비활성화하거나 “이 문서에는 이 목적용 규칙이 없습니다” 상태를 표시하십시오.

13. 문제 / `__fieldBands.inMask`는 `on && mode !== ok && located`를 검사한 뒤에는 사실상 동어반복입니다. `__maskRects`와 `__fieldBands`가 동일한 `mergeLineBoxes + bandRect`를 같은 entity에 적용합니다. `inMask`가 거짓이 될 수 있는 정상 경로는 category OFF, `mode='ok'`, boxes 없음이며, 이미 별도 속성으로 검사합니다. 따라서 독립적인 렌더·좌표 검증을 추가하지 못했습니다. / 근거([test/safe/run.mjs:63](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:63), [test/safe/run.mjs:180](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:180), [test/safe/run.mjs:185](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:185), [test/safe/run.mjs:603](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:603)) / 수정안: 실제 preview/output canvas 픽셀을 entity 기대 rect에서 검사하거나, 최소한 독립적인 fixture box와 mask rect의 중첩을 측정하십시오. 현 단언은 `isOn`·`mode` 검사의 중복이라고 기록해야 합니다.

14. 문제 / 레이블 없는 블록 테스트의 “labelled code still banded”는 빈 배열에서도 통과합니다. `filter(...).every(...)`는 대상이 0개면 `true`이므로 labelled QR 탐지가 완전히 사라져도 녹색입니다. / 근거([test/safe/run.mjs:850](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:850), [test/safe/run.mjs:857](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:857)) / 수정안: 필터 결과의 `length > 0`을 먼저 요구하십시오.

15. 문제 / `__inkCover` 임계값들은 픽스처 맞춤값이며 실제 스캔 일반화 근거가 없습니다. 배경 대비 60은 흐린 회색 숫자나 저대비 스캔 글자를 잉크에서 제외할 수 있고, 6픽셀 미만 성분 제거는 점·가느다란 `1`·분리된 안티앨리어싱 조각을 무시할 수 있습니다. 99%는 “모든 글자가 판독 불가”와 연결되는 근거가 없습니다. 반면 성분 0을 실패시키는 방향은 공허한 통과를 막으므로 올바릅니다. / 근거([test/safe/run.mjs:132](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:132), [test/safe/run.mjs:147](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:147), [test/safe/run.mjs:167](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:167), [test/safe/run.mjs:171](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:171), [test/safe/run.mjs:546](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:546)) / 수정안: 저대비·작은 글꼴·JPEG artifact 변이에서 원문 숫자 단위의 잔존 판독 가능성을 검증하십시오. 고정 RGB 차이 대신 국소 대비/이진화와 OCR 재판독을 병행하십시오.

16. 문제 / `auto_allow`의 `[]`와 `undefined` 구분은 실제로 성립하지만, 비어 있지 않은 allowlist는 “부분집합”만 확인합니다. 자동 필드가 전부 사라져 빈 배열이 되어도 `bad.length === 0`으로 통과합니다. 별도의 `min_auto`나 `require_banded`가 모든 allowlist 필드를 포괄하지 않는 케이스에서는 미탐을 숨깁니다. / 근거([test/safe/run.mjs:636](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:636), [test/safe/run.mjs:638](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:638)) / 수정안: 기대가 정확한 케이스는 집합 동등성을 검사하고, 선택적 필드가 있다면 `required_auto`와 `allowed_auto`를 분리하십시오.

17. 문제 / 합성 분류·個人番号 테스트는 정책 배선만 증명하고 OCR 강건성을 증명하지 않습니다. `loadFromText`는 완벽한 텍스트와 박스를 생성하므로 OCR 오인식, item 분절, 줄 병합, 회전·압축을 통과하지 않습니다. 다중 페이지 테스트도 원본 PNG를 JPEG로 재인코딩한 동일 도식 픽스처 두 장이므로 “페이지별 분류” 회귀는 잡지만 현실의 양면 카드 PDF 대표성은 없습니다. / 근거([test/safe/run.mjs:783](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:783), [test/safe/run.mjs:803](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:803), [test/safe/run.mjs:733](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:733), [test/safe/run.mjs:741](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:741)) / 수정안: 합성 테스트의 보장 범위를 “분류/정책 wiring”으로 명시하고, 저해상도·회전·배경·서로 다른 앞뒷면 스캔 조건을 가진 고정 PDF 픽스처를 별도로 추가하십시오.

18. 문제 / 카테고리 복원은 정상 경로만 처리하고 `try/finally`가 없습니다. `__allCatsOff()` 이후 browser evaluation, reload 또는 assertion 코드가 예외를 던지면 `__restoreCats()`에 도달하지 않아 이후 케이스 전체가 오염됩니다. 구현자가 이미 같은 전역 누출을 한 번 겪었다는 점에서 이 경로를 남길 이유가 없습니다. / 근거([test/safe/run.mjs:620](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:620), [test/safe/run.mjs:628](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:628), [test/safe/run.mjs:630](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:630)) / 수정안: 각 legal 단언을 `try/finally`로 감싸고 finally에서 복원 및 검증하십시오. 더 안전하게는 테스트별 새 page/context를 쓰십시오.

19. 문제 / `legal`은 사용자가 개별 공개해도 그대로 남아 법적 그룹과 카운트에 계속 포함됩니다. 출력 마스크에서는 `mode='ok'`라 빠지므로 보안상 즉시 어긋나지는 않지만, “법적 띠” 그룹의 공개된 항목과 `isOn`이 항상 true인 상태가 혼재합니다. 카테고리 체크박스가 legal 항목에 적용되지 않는 것은 이번 결함을 막는 방향이지만, UI는 왜 꺼도 남는지 설명하지 않습니다. / 근거([public/safe/index.html:797](/Users/sunghoon/Projects/docpack/public/safe/index.html:797), [public/safe/index.html:1904](/Users/sunghoon/Projects/docpack/public/safe/index.html:1904), [public/safe/index.html:2603](/Users/sunghoon/Projects/docpack/public/safe/index.html:2603), [public/safe/index.html:2657](/Users/sunghoon/Projects/docpack/public/safe/index.html:2657)) / 수정안: 그룹 제목을 “법적 근거가 있는 검토 항목”처럼 상태와 분리하고, category 토글 옆에 법적 항목은 개별 제어된다고 명시하십시오. `legal`을 mode에 따라 제거할 필요는 없지만 그룹 내부에 공개/비공개 상태를 분명히 표시해야 합니다.

20. 문제 / `legal` 조건을 `mode==='no'`로 제한해 레이블 없는 QR을 법적 그룹에서 빼는 것은 정책상 일관되지 않습니다. 동일한 `qr`가 레이블 인식 여부 하나로 “법령·제출처 규칙”과 일반 후보 사이를 이동합니다. 다만 불확실 탐지를 법적 확정 항목으로 표시하지 않는 방향 자체는 안전합니다. / 근거([public/safe/index.html:1904](/Users/sunghoon/Projects/docpack/public/safe/index.html:1904), [public/safe/index.html:1932](/Users/sunghoon/Projects/docpack/public/safe/index.html:1932), [public/safe/index.html:2603](/Users/sunghoon/Projects/docpack/public/safe/index.html:2603)) / 수정안: “법적 규칙”과 “탐지 신뢰도”를 별도 속성으로 보존하고, 후보 그룹에서 “QR일 경우 동일 법적 제한 대상일 수 있음”을 표시하십시오.

21. 문제 / 레이블 없는 코드 블록을 `optional`로 내린 교환은 오탐 방지에는 맞지만, 資格確認書의 번호 누출 관점에서는 미탐 쪽으로 이동했습니다. 현재 detector는 finder pattern, quiet zone, module 주기를 전혀 보지 않으므로 이를 곧바로 기본 ON으로 승격할 근거는 없습니다. 그 특징들은 구현 가능한 값싼 증거지만 임계값의 정밀도와 오탐률은 진짜 QR/바코드 및 사진·인감 음성 픽스처 없이는 확인 불가입니다. / 근거([public/safe/index.html:1810](/Users/sunghoon/Projects/docpack/public/safe/index.html:1810), [public/safe/index.html:1927](/Users/sunghoon/Projects/docpack/public/safe/index.html:1927)) / 수정안: 지금은 optional을 유지하되, 코드 후보가 존재하면 별도 눈에 띄는 경고를 띄우십시오. 이후 실제 코드 픽스처와 비코드 사각형 음성군을 먼저 만들고 finder/quiet-zone 기반 승격을 도입하십시오.

22. 문제 / `general_jp.applies_to`는 문서 추가 시 수동 갱신 누락이 조용히 가능합니다. 새 문서를 `documents`와 `JP_RULES`에 추가하면서 `JP_EXTRA`를 spread하지 않으면 대조기는 양쪽 모두에 일반 규칙이 없다고 보고 통과할 수 있습니다. / 근거([test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:111](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:111), [test/safe/check_matrix.mjs:59](/Users/sunghoon/Projects/docpack/test/safe/check_matrix.mjs:59), [public/safe/index.html:1440](/Users/sunghoon/Projects/docpack/public/safe/index.html:1440)) / 수정안: “모든 documents”가 의도라면 `applies_to:"*"`로 표현하거나 대조기에서 documents ID 집합과 `applies_to`의 정확한 동등성을 검사하십시오.

23. 문제 / `keep:"all"` 수정은 현재 도달하지 않아 회귀 방지로 인정할 수 없습니다. 값싼 도달 방법은 새 제품 목적을 만들 필요 없이 하네스 유닛에서 fixture metadata를 읽어 `Object.keys(boxes_png)`로 확장되는지 테스트하거나, 테스트 전용 케이스에서 기존 `医療機関提示` 목적표를 직접 검사하는 것입니다. / 근거([test/safe/run.mjs:677](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:677), [test/safe/fixtures/jp/gen.py:130](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/gen.py:130), [docs/jp/s3b_report.md:202](/Users/sunghoon/Projects/docpack/docs/jp/s3b_report.md:202)) / 수정안: 순수 함수로 기대 키 확장을 분리해 단위 테스트하거나 `医療機関提示`를 하네스 전용 목적 케이스로 실행하십시오.

24. 문제 / variant 가지치기 자체는 `kouki`의 존재하지 않는 `kigo/bango/edaban` 기대를 제거하므로 타당하지만, 생성 시 양쪽 표가 같이 줄어드는 구조라 실제 픽스처 생성 누락도 정상으로 승인할 수 있습니다. 예컨대 실수로 `hihokensha_bango` 박스 생성을 지우면 기대표에서도 자동 삭제됩니다. / 근거([test/safe/fixtures/jp/gen.py:78](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/gen.py:78), [test/safe/fixtures/jp/gen.py:89](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/gen.py:89), [test/safe/fixtures/jp/gen.py:107](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/gen.py:107)) / 수정안: variant별 필수 필드 schema를 별도로 두고 생성된 `boxes`가 그것을 포함하는지 assert한 뒤 가지치기하십시오. `kouki`에 `kigo/bango/edaban`이 없다는 것은 현재 생성 코드상 맞습니다.

25. 문제 / ko/en/es의 경고가 일본어 원문과 번역을 한 문자열로 중복 표시합니다. 법적 고유명사를 병기하는 것과 전체 경고문을 일본어로 먼저 노출하는 것은 다릅니다. 좁은 모바일 배너에서 핵심 행동 지침을 늦추고 언어별 접근성을 악화합니다. / 근거([public/safe/index.html:561](/Users/sunghoon/Projects/docpack/public/safe/index.html:561), [public/safe/index.html:618](/Users/sunghoon/Projects/docpack/public/safe/index.html:618), [public/safe/index.html:732](/Users/sunghoon/Projects/docpack/public/safe/index.html:732)) / 수정안: 각 locale에는 해당 언어만 표시하고, 필요한 고유명사만 일본어를 괄호 병기하십시오.

## 배포 차단 4건 판정

- 분류 실패 경고: **부분 해소** — 완전 무경고는 막았지만 `low`에서 문구와 실제 기본 마스킹이 모순되고 和暦 단독 오경고가 과다합니다.
- 레이블 없는 블록: **부분 해소** — 무근거 기본 마스킹은 제거했지만 실제 코드 후보 경고와 detector 통합 커버리지가 없고, 하네스의 labelled-code 역단언도 공허합니다.
- 다중 페이지: **부분 해소** — 앞/뒤 순서 문제는 고쳤지만 분류 불가 첨부의 `cls0` 상속이 남았습니다.
- 법적 그룹: **부분 해소** — category 토글로 조용히 사라지는 문제는 막았지만, `verified:false`까지 법적 금지로 표시하고 UI 문구가 과도합니다.
- 정본 불일치: **부분 해소** — 188 triple은 일치하지만 `発行日`·detector 존재 여부·법적 속성은 대조하지 않습니다.
- 하네스 강화: **부분 해소** — 여러 공허한 경로를 줄였으나 `__fieldBands.inMask` 동어반복, 빈 `.every()`, subset-only allowlist, 예외 시 전역 오염이 남았습니다.

## 즉시 고쳐야 할 상위 5개

1. **AMBER · 배포 전** — 분류 불가 첨부 페이지에 `cls0`을 상속하는 다중 페이지 오분류 제거.
2. **AMBER · 배포 전** — `lowconf` 경고 문구와 실제 기본 ON 띠의 모순 해소 및 和暦 단독 suspect 제거.
3. **AMBER · 배포 전** — `last:true` keep 필드가 같은 행의 保険者番号를 소비해 미탐시키는 경계 수정.
4. **AMBER · 배포 전** — `verified:false`인 `jumin_code`를 법적 금지 그룹·단정적 안내에서 제외하고 個人番号 확인 문구를 사용자가 검증 가능한 사실로 변경.
5. **GREEN · 다음 런** — 하네스의 동어반복 `inMask`, 빈 `.every()`, exact auto-set 부재, `try/finally` 없는 category 복원을 보강하고 실제 QR·혼합 PDF·저대비 스캔 픽스처 추가.
