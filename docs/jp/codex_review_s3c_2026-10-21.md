warning: `--full-auto` is deprecated; use `--sandbox workspace-write` instead.
2026-10-21T16:27:02.873464Z ERROR codex_models_manager::cache: failed to load models cache: missing field `base_instructions` at line 139 column 5
OpenAI Codex v0.146.0
--------
workdir: /Users/sunghoon/Projects/docpack
model: gpt-5.6-sol
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR]
reasoning effort: none
reasoning summaries: none
session id: 01a15f49-a0c4-7f82-ad18-b2c513606c07
--------
user
# Codex 교차검증 요청 — SafeFile JP-1 S3c

## 이 라운드가 무엇인지

S3b 검토(`docs/jp/codex_review_s3b_2026-10-21.md`)가 「즉시 고쳐야 할 상위 5개」로 올린
**AMBER 4건**과, 같은 검토의 **하네스 공허 경로 3건**을 닫은 라운드다.
이것이 **배포 전 마지막 라운드**다.

### 🔴 검토 범위 — 반드시 이 범위만

**판정해야 하는 질문은 하나다: 아래 AMBER 4건이 실제로 닫혔는가.**

| # | S3b 발견 | 요구된 변경 |
|---|---|---|
| A-1 | 발견 3 | 다중 페이지에서 **분류 불가 페이지의 `cls0` 상속 제거**. 예외는 「앞 페이지가 カード 表面이고 이 페이지에 그 카드의 裏面 전용 앵커가 있다」는 조건을 **입증한 경우**만 |
| A-2 | 발견 1, 2 | `lowconf` / `unclassified` **경고 분리**(문구가 실제 출력과 일치), `JP_SUSPECT_RE` 에서 **和暦 단독 조건 제거** |
| A-3 | 발견 5 | `last:true` keep 필드가 **같은 행의 保険者番号를 소비해 미탐시키던 경계** 수정 |
| A-4 | 발견 10, 11 | `verified:false` 인 `jumin_code` 를 **법령 그룹에서 제외**(그룹 멤버십을 정본의 명시 속성에서 파생), **個人番号 확인 문구를 사용자가 검증 가능한 사실로** 변경 |

부수로 닫은 하네스 항목(발견 14·16·18)과 UI 안내(발견 12)도 같은 기준으로 봐주되,
**이 7건 밖의 지적은 AMBER 로 올리지 마십시오.**

**그 외 발견은 백로그로 기록만 하고 AMBER 판정 금지.**
S3b 의 발견 4·6·7·8·9·13·15·17·19·20·21·22·23·24 는 이번 범위가 아니다 —
`docs/jp/s3c_report.md` §5 에 전부 등재돼 있고, 거기에 근거와 함께 「이번 라운드에서
고치지 않은 이유」가 적혀 있다. 그 항목들에 대한 새로운 관찰은 환영하지만
**등급은 백로그(다음 런)로 달아주십시오.** 배포 차단 등급은 위 7건에만 쓸 수 있다.

## 읽을 것

| 파일 | 역할 |
|---|---|
| `docs/jp/s3c_report.md` | 이번 라운드 처리표 + 변이 프로브 결과 + 백로그 |
| `public/safe/index.html` | 페이지 전체(빌드 단계 없음). JP 코드는 `JP_CLASSES`~`jpRenderBar` |
| `test/safe/fixtures/jp/jp_legal_matrix_alpha4.json` | 법적 정본 |
| `test/safe/check_matrix.mjs` | 정본 ↔ 코드 대조기 |
| `test/safe/run.mjs` · `test/safe/specs.json` | 골든 하네스 + 기대표 |
| `docs/jp/s3b_report.md` | 직전 라운드 |

## 검증 상태

```
node test/safe/check_matrix.mjs   → 188 triple + 10 legal pair 일치, exit 0
cd test/safe && node run.mjs      → 아래 보고서 §4 의 수치, exit 0
```

`run.mjs` 는 `127.0.0.1` 에 임시 서버를 띄우고 실제 Chrome 을 몬다 —
샌드박스가 listen 을 막으면 **돌 수 없다.** 그 경우 하네스에 대한 평가는 정적 검토임을
명시해 주십시오(직전 라운드가 그렇게 했고, 그 표기 덕분에 어디까지가 근거인지 알 수 있었다).

## 특별히 의심해 주셨으면 하는 곳

1. **A-1 의 예외 조건이 너무 넓지 않은가.** 승격 조건은 「직전 페이지가 `side==='front'`
   이고 `JP_BACK_ANCHORS[doc]` 가 이 페이지 텍스트에 맞는다」 뿐이다. 페이지 크기·비율·
   연속성은 보지 않는다. 이 조건으로 승격된 페이지는 **전면 띠**를 받는다.
2. **A-3 의 교환.** keep 전용 필드가 4자리 이상 숫자 런을 `used`·boxes·value 에서
   **일괄 포기**한다. 그래서 「事業所名称 架空株式会社 123456」 같은 행의 숫자가 이제
   資格確認書 폴백에 잡힐 수 있다 — 과잉 마스킹 방향이다. 보고서 §2-A3 에 그 교환을
   적었지만, 이 선택이 옳은지는 독립 판단이 필요하다.
3. **A-4 의 `legal_enforcement` 부여 기준.** `qr`(資格確認書)에 부여했다. 그 규칙의
   `legal_basis` 는 지자체 **운용 통지**이고, 우리는 「그 통지가 실시하는 告知要求制限」을
   근거로 삼았다. 이 추론이 「출처 없는 판단의 정본 승격」(발견 7)과 같은 종류의 실수인가.
4. **새 확인 문구가 여전히 사용자가 확인할 수 없는 사실을 묻는가.**
   「提出先の案内で、個人番号（裏面）の提出が明示的に求められていることを確認しました」.
5. **발견 12 의 안내 조건.** 「이 목적의 규칙이 0개」를 코드는 「현재 목적에서 JP 엔티티가
   0개」로 구현했다. 문구와 조건이 어긋나는가.
6. **변이 프로브가 실제로 결함을 되살리는가.** 보고서 §3 의 7개 프로브는 전부 실측이다.
   프로브가 「고친 것」이 아니라 「다른 것」을 재우고 있지 않은지 봐주십시오.

CODEX_REVIEW_READY
warning: Skill descriptions were shortened to fit the 2% skills context budget. Codex can still see every skill, but some descriptions are shorter. Disable unused skills or plugins to leave more room for the rest.
hook: SessionStart
hook: SessionStart Completed
hook: UserPromptSubmit
hook: UserPromptSubmit Completed
codex
요청하신 범위를 엄격히 지키겠습니다. 먼저 S3b의 원래 판정과 S3c 처리표를 대조한 뒤, A-1~A-4와 하네스 3건·UI 안내만 코드/정본/테스트까지 추적하고, 실행 가능하면 두 검증 명령도 직접 재현하겠습니다. 범위 밖 관찰은 배포 차단이 아닌 백로그로만 분리하겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
  → S3b 원문과 S3c 처리표에서 판정 기준·변이 프로브를 추출
  • A-1~A-4 및 하네스/UI 구현을 정적 교차검증
  • 매트릭스 검사와 브라우저 하네스를 실행·결과 확인
  • 범위 준수한 최종 판정 문서 작성
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "sed -n '1,260p' docs/jp/s3c_report.md && sed -n '1,280p' docs/jp/codex_review_s3b_2026-10-21.md && sed -n '1,220p' docs/jp/s3b_report.md" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
# SafeFile JP-1 S3c — Codex 2차 AMBER 4건 + 하네스 공허 경로 3건

입력: [`docs/jp/codex_review_s3b_2026-10-21.md`](codex_review_s3b_2026-10-21.md) 「즉시 고쳐야 할 상위 5개」
직전 라운드: [`docs/jp/s3b_report.md`](s3b_report.md)
다음 라운드 프롬프트: [`docs/jp/codex_prompt_s3c.md`](codex_prompt_s3c.md)
법적 정본: [`test/safe/fixtures/jp/jp_legal_matrix_alpha4.json`](../../test/safe/fixtures/jp/jp_legal_matrix_alpha4.json)

브랜치 `main`. **미배포.** 프로덕션 DB 미접촉. **배포 전 마지막 라운드.**

---

## 0. 요약

| | 전 (S3b) | 후 (S3c) |
|---|---|---|
| 골든 단언 | 484 pass / 0 fail | **533 pass / 0 fail** |
| 정본 ↔ 코드 대조 | 188 triple | **188 triple + 10 legal pair** |
| 변이 프로브 | 6건 | **7건 (전부 실측, 아래 §3)** |
| SW 하네스 | 9/9 | 9/9 (미변경) |

닫은 것은 **네 건 다 「밖에서 보면 정상과 구별되지 않던」 종류**다 —
경고 문구가 출력과 반대였고, 분류 불가 페이지가 남의 규칙으로 통치됐고,
가리지 않겠다고 약속한 필드가 가려야 하는 번호를 숨겼고,
출처를 확보하지 못했다고 스스로 적은 규칙이 법령 금지를 단정했다.

---

## 1. 처리표

| # | S3b 발견 | 상태 | 닫힘 증거 (하네스 케이스명) | 변이 프로브 |
|---|---|---|---|---|
| A-1 | 발견 3 — 분류 불가 페이지의 `cls0` 상속 | **닫힘** | `jp/2page 表 + 無関係な添付 → 分類なし` · `jp/2page 表 + 裏(タイトル切除) → 裏面に昇格` | P-2 → 5 실패 |
| A-2 | 발견 1 — `lowconf` 문구가 출력과 모순 | **닫힘** | `(jp warn) 資格確認書 제목 단독 … 후보 띠 적용 + 확인 요구` (JP_WARN_TEXT + JP_WARN_BANDS) | P-1 → 1 실패 |
| A-2 | 발견 2 — `JP_SUSPECT_RE` 和暦 단독 오경고 | **닫힘** | `(jp warn) 和暦만 있는 일본어 이력서 → 경고 없음` · `(jp warn) 免許証 언급만 … 차단성 경고 + 띠 0` | P-1 → 1 실패 |
| A-3 | 발견 5 — `last:true` keep 필드가 保険者番号를 소비 | **닫힘** | `(jp synth) 保険者名 과 保険者番号 가 한 행` · `(jp synth) 保険者番号 라벨이 OCR 로 깨진 한 행` | P-3 → 2 실패 · P-4 → 2 실패 |
| A-4 | 발견 10 — 법령 그룹이 문자열 Set 에서 파생 | **닫힘** | `check_matrix.mjs` 의 10 legal pair 집합 동등성 + `juminhyo` 의 `require_legal: [my_number]` | P-5 → exit 1 |
| A-4 | 발견 11 — 확인 문구가 검증 불가한 사실을 단정 | **닫힘** | 문구 교체 (4개 언어) + 정본 `gate_requires_confirmation` 갱신 | — (문구 변경, 측정 대상 아님) |
| B-1 | 발견 14 — `filter().every()` 공허 통과 | **닫힘** | `(jp unlabelled) labelled code still banded` → `>=1 banded` | P-6 → 1 실패 |
| B-2 | 발견 16 — allowlist 가 부분집합만 확인 | **닫힘** | `JP_AUTO_SET` 16 케이스가 **집합 동등**(`required_auto`), 3 케이스만 부분집합(`allowed_auto`) | 전환 직후 kouki 의 유령 멤버를 즉시 잡음 (§2-B2) |
| B-3 | 발견 18 — `__allCatsOff` 에 `try/finally` 없음 | **닫힘** | 전체 런에 예외 주입 → 8 LOAD 에러로 **격리**, 나머지 398 단언 전부 녹색 | P-7 (§3) |
| B-4 | 발견 12 — 목적 규칙 0개일 때 무설명 | **닫힘** | `jp/shikaku_kakuninsho/kenpo.png [my_number_procedure]` (JP_EMPTY + JP_ENTITIES) | — (신규 경로, 케이스가 유일한 증거) |

**백로그로 넘긴 것: 발견 4·6·7·8·9·13·15·17·19·20·21·22·23·24 — §5.**

---

## 2. 무엇을 어떻게 바꿨는가

### A-1 (발견 3) — 분류 불가 페이지는 아무 규칙도 받지 않는다

직전 라운드는 `jpClassify(pi) || cls0` 로 썼다. 양면 카드의 스캔 순서 문제는 그것으로 닫혔지만
**통장 사본·세금 통지서·빈 간지가 같은 PDF 에 묶이면 그것들이 카드 규칙으로 통치됐다.**
이 방향의 오류는 누출이 아니라 **제출에 필요한 증빙의 훼손**이다.

**지금**: 분류 불가 페이지는 `null` 이고, 그 페이지에는 **일본 규칙이 하나도 돌지 않는다.**
유일한 예외는 카드의 **裏面** 이다 — 뒷면은 문서 이름을 싣지 않으므로 스스로 분류될 수 없다
(`個人番号` 는 필요한 4점 중 2점이고, 카드의 **이름**은 앞면에 인쇄된다).
승격 조건은 두 개를 **동시에** 요구한다:

```
직전 페이지의 class 가 { doc: D, side: 'front' }   ∧   이 페이지 텍스트가 JP_BACK_ANCHORS[D] 와 일치
```

```js
const JP_BACK_ANCHORS = {
  mynumber_card: /個人番号|マイナンバー|二次元コード/,
  unten_menkyo: /備考欄|臓器提供|提供意思|意思表示欄/,
};
```

`臓器提供` 는 **카드 목록에서 의도적으로 빠졌다** — マイナンバーカード에서는 **앞면** 항목이라
뒷면의 증거가 될 수 없다. 승격된 페이지는 `viaBackAnchor: true` 를 달아 추적 가능하다.

**하네스**: 기존 두 케이스(表→裏·裏→表)는 두 페이지가 **각자 독립적으로** 분류되므로 승격 경로를
밟지 않는다. 그래서 두 케이스를 **런타임에 합성**했다 — 저장소에 새 바이너리를 넣지 않고
이미 커밋된 파일로만 만든다:

| 케이스 | 2페이지 구성 | 기대 |
|---|---|---|
| `表 + 裏(タイトル切除)` | `front.png` + `back.png` 를 **y≥100 으로 크롭**(타이틀 「個人番号カード 裏面」 제거 → 스스로 분류 불가, 그러나 `個人番号` 앵커는 남는다) | `mynumber_card/front + mynumber_card/back`, `viaBackAnchor=true`, 2페이지 전면 띠 ≥99%, 1페이지 ≤60% |
| `表 + 無関係な添付` | `front.png` + `testdocs/1_text.pdf` **1페이지를 pdf.js 로 렌더** (한국어 이력서 — 네 문서 중 어느 것도 아니다) | `mynumber_card/front + null`, `viaBackAnchor=false`, **2페이지 JP 엔티티 0**, 2페이지 피복 ≤10%, 1페이지 JP 엔티티 ≥1 |

마지막 줄이 **공허 방지**다: 「2페이지에 아무것도 없다」가 「프리셋이 통째로 죽었다」로도 참이 될 수 있다.

> ⚠️ **남는 조건**: 승격은 페이지 **크기·비율·연속성**을 보지 않는다. 앵커 하나와 직전 페이지의
> side 뿐이다. 승격된 페이지는 **전면 띠**를 받는다 — 과잉 마스킹 방향이므로 누출보다는 낫지만,
> Codex 가 제안한 추가 조건은 넣지 않았다. §5 백로그 C-1.

### A-2 (발견 1·2) — 경고 두 개는 반대말을 한다

`lowconf` 는 자동 레벨을 **`recommend` 로 강등**한다. 그런데 `recommend` 의 기본 mode 는 `'no'` 다 —
**띠는 출력에 들어간다.** 그 상태에 「自動黒塗りは適用していません」(자동 마스킹을 적용하지
않았습니다) 를 붙이고 있었다. 사용자가 출력 상태를 **반대로** 이해하게 만드는 문구다.

| 상태 | 실제 출력 | 문구 (ja) | 스타일 |
|---|---|---|---|
| `lowconf` — 어느 서식인지는 알지만 확신도가 낮다 | **후보 띠가 적용돼 있다** | 「文書の種類の確信度が低いため、候補の黒塗りを既定で適用しました。必ず確認してください。」 | `.jp-warn.is-low` (앰버 — 확인 요구) |
| `unclassified` — 일본 규칙이 하나도 돌지 않았다 | **아무것도 가려지지 않았다** | 「文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。」 | `.jp-warn` (적색 — 정지 신호) |

**4개 언어 각각 자국어만** 쓴다 (발견 25). 직전까지 ko/en/es 는 일본어 원문을 **먼저** 노출하고
괄호로 번역을 붙이고 있었다 — 좁은 모바일 배너에서 핵심 행동 지침이 뒤로 밀린다.
같은 이유로 `jpLegalSection` 의 어순도 뒤집었다(ko: 「법령·제출처 규칙 (法令・提出先ルール)」).

**`JP_SUSPECT_RE` 에서 `令和|平成|昭和` 를 제거했다.** 일본어 이력서·청구서·계약서는 전부 和暦을
싣는다 — 경고가 「이 네 문서 중 하나로 의심된다」가 아니라 **「이 텍스트는 일본어다」**를 뜻하게
되고, 그러면 사용자가 배너를 무시하는 법을 배운다. 그 다음에 정작 필요할 때 거기 없다.

**하네스**: 경고의 **문구**(`expect_text_has`)와 **실제로 칠해진 띠 수**(`expect_mask_rects`)를
함께 단언한다. 가시성만 보는 단언은 문구가 출력과 반대여도 통과한다 — 그게 이 결함이었다.
`lowconf` 픽스처에 **맨 숫자 8자리 한 줄**을 넣었다: 구조 폴백이 `保険者番号` 계열로 잡고
`auto → recommend` 로 강등되지만 **기본 ON 이라 띠가 남는다**. 그 띠가 바로 `lowconf` 문구가
약속하는 것이고, 그게 없으면 두 배너를 **측정으로** 구별할 수 없다.

### A-3 (발견 5) — keep 필드가 같은 행의 번호를 숨기던 문제

모든 값 규칙은 **세그먼트 머리**에 앵커한다. 두 레이블-값 쌍은 **열 간격이 세그먼트 임계값
아래로 내려가는 순간 하나의 세그먼트**가 된다. 그 세그먼트에서 `保険者番号` 는 더 이상 머리에
없으므로 **자기 규칙으로 앵커할 수 없다** — 번호는 구조 폴백에 맡겨지고, 폴백은 **아무도
`used` 로 표시하지 않은 span 만** claim 한다. 그런데 `保険者名` 은 `last:true` keep 필드로서
**레이블 뒤의 모든 item** 을 가져가며 tail 전체를 `used` 로 찍었다.
**가리지 않겠다고 약속한 필드가, 告知要求制限 이 가리라고 요구하는 번호를 침묵시켰다.**

두 겹으로 고쳤고, **두 겹 다 실측으로 load-bearing 임을 확인했다**:

| 겹 | 무엇 | 어느 실패를 닫는가 |
|---|---|---|
| ① `jpTailEnd` — 값의 끝을 **같은 세그먼트의 다음 알려진 레이블 직전**으로 제한 | 모든 값 경로(tel·digits·re·addr·last)에 적용. 性別 정규식이 다음 열의 `男` 을 잡을 이유도 없다 | 이웃 레이블이 **읽힌** 경우 |
| ② `jpKeepOnly` 필드는 **4자리 이상 숫자 런**을 `used`·boxes·value **어디에도** claim 하지 않는다 | keep/optional 레벨만 가진 필드 = 아무것도 가리지 않는 필드 | 이웃 레이블이 **OCR 로 깨진** 경우 — 이 서식에서는 **측정된 정상**이다 (`保険者番号` 가 5개 중 3개에서 `RREES`/`REEES`/`WREEES`) |

②를 `used` 에만 적용하지 않고 **boxes·value 까지** 함께 뺀 이유: 번호가 출력에서는 띠로 덮이는데
사이드바 keep 목록에는 **평문으로 인쇄되는** 상태가 되기 때문이다. 목록이 페이지와 반대말을 한다.

> ⚠️ **교환을 명시한다.** ② 때문에 keep 필드 **자기 값에 속하는** 4자리 이상 숫자 런
> (예 「事業所名称 架空株式会社 123456」)이 이제 claim 되지 않은 채 남고, 資格確認書 폴백이 그것을
> 띠로 덮을 수 있다 — **과잉 마스킹 방향**이다. 이 문서의 규칙은 이미 그 방향을 의도적으로
> 택하고 있다(코드 주석: 告知要求制限 이 保険者番号 계열을 **한 규칙**으로 덮으므로 「어느 멤버인지
> 추측하는 비용은 0, 반면 놓치는 것은 이 제품이 막으려는 바로 그 누출」). 띠는 항목 단위로
> 해제 가능하다. **그래도 이 선택은 독립 판단이 필요하다 — 교차검증 질문 ②로 올렸다.**

**하네스**: 알파 픽스처는 `保険者名` 과 `保険者番号` 를 **230px** 떨어뜨려 놓는다(임계값 124px보다
넓다) — 그래서 **커밋된 어떤 픽스처도 이 상태에 도달할 수 없다.** 붙여넣기 경로로 행을 만들었고,
그것이 **보장하는 범위는 레이블→값 경계이지 OCR 이 아니라고 명시**했다.

### A-4 (발견 10·11) — 법령 그룹은 정본의 명시 속성에서 파생된다

**발견 10.** `JP_LEGAL_FIELDS` 는 평평한 필드명 Set 이었고, 검증은 「그 이름이 매트릭스
어딘가에 있는가」만 물었다. 그래서 **`住民票コード` 가 법령 그룹에 들어갔다** — 자기 매트릭스
항목이 「조문·운용의 출처를 확보하지 못했다(`verified:false`)」고 적어둔 바로 그 규칙이,
해제하면 「제출처가 보관할 수 없는 정보」라고 단정하는 배너 아래 앉아 있었다.

**지금**: 정본에 **명시 속성 `legal_enforcement: true`** 를 두고, 코드는 **문서별** 집합을 갖는다.

```js
const JP_LEGAL = {
  shikaku_kakuninsho: ['hokensha_bango','kigo','bango','edaban','hihokensha_bango','qr'],
  unten_menkyo: [],
  mynumber_card: ['back_all','my_number','qr'],
  juminhyo: ['my_number'],
};
```

문서 범위가 중요한 이유가 여기서 드러난다 — `my_number` 는 住民票 에서 **番号法 근거가 있고**,
`jumin_code` 는 어디에도 근거가 없다. 평평한 Set 은 그 구별을 표현할 수 없었다.

`check_matrix.mjs` 가 강제하는 것 **세 가지**:
1. `legal_enforcement: true` ⇒ `verified: false` **금지** (출처를 확보하지 못했다고 스스로 적은
   규칙이 법령 제한을 단정할 수 없다)
2. 정본에서 파생한 문서별 집합 ↔ `JP_LEGAL` **집합 동등** (부분집합이 아니다 —
   빠지면 법적 띠가 조용히 카테고리 체크박스 아래로 돌아가고[발견 4-6], 남으면 매트릭스가
   주장하지 않는 제한을 단정한다[발견 10])
3. `legalPairs < 8` 이면 **실패** — 0회 비교는 많이 비교한 것과 같은 녹색을 찍는다
   (`compared < 100` 과 같은 이유)

`qr`(資格確認書)에 부여한 근거는 정본에 적었다: 그 규칙의 `legal_basis` 는 지자체 **운용 통지**
이지만, 제한의 근거는 통지 자체가 아니라 **그 통지가 실시하는 告知要求制限** 이다 —
기계 가독 복제도 번호의 告知 에 해당하므로 같은 제한이 미친다. **이 추론이 발견 7 과 같은
종류의 실수인지 교차검증 질문 ③으로 올렸다.**

`jumin_code` 는 **既定ON 그대로**다 — 바뀐 것은 그룹 멤버십뿐이고, 이제 일반 「要確認」 항목처럼
카테고리 제어를 받는다. 하네스의 `require_legal` 은 `jumin_code` → `my_number` 로 옮겼다
(住民票 에서 「전 카테고리 OFF 를 견딘다」를 증명하는 역할은 番号法 근거가 있는 쪽이 맡는다).
`jumin_code` 의 띠는 `require_banded` + `JP_INK` 가 계속 지킨다.

**발견 11.** 확인 체크박스가 **사용자가 확인할 수 없는 사실**을 단정하게 했다.
「提出先が法定の個人番号関係事務を行うことを確認しました」 — 수신자의 법적 지위와 구체적 사무의
판정이다. PPC Q6-12 는 단순 열람과 복사·기록을 구분하고 복사 시에도 「위반할 가능성」이라고
설명하며, **체크박스 같은 사용자 확인을 적법성 증명 수단으로 제시하지 않는다.**

| | 전 | 후 |
|---|---|---|
| 확인 문구 (ja) | 「提出先が法定の個人番号関係事務を行うことを確認しました。」 | 「提出先の案内で、個人番号（裏面）の提出が明示的に求められていることを確認しました。求められていない場合は解除しないでください。」 |
| 법적 효과 (`jpBackNotice`) | 「制限されています」 | 「制限される**場合があります**」 |
| 법적 띠 해제 토스트 | 「提出先が保管できない情報がそのまま出力されます」 | 「法令上、収集・保管が制限される**場合がある**情報がそのまま出力されます」 |

사용자가 실제로 **읽을 수 있는 종이**(제출처 안내문)에 대한 사실로 바꾸고, 요구가 없으면
해제하지 말라는 지침을 붙였다. 4개 언어 전부. 정본의 `gate_requires_confirmation` 에 이유를 적었다.

### B-1 (발견 14) — 빈 배열의 `.every()`

```js
// 전: 대상이 0개면 true
window.__fieldBands('qr').filter(b => b.note !== 'unlabelled_code').every(b => …)
```

이 단언의 존재 이유는 「레이블 없는 블록이 띠를 받지 않는다」가 **아무것도 띠를 받지 않아서**
참이 되는 경우를 배제하는 것이다. 그런데 레이블 붙은 QR 탐지가 **통째로 사라져도** 녹색이었다.
`length > 0` 을 먼저 요구하고, 실패 문구를 `NO LABELLED CODE FOUND` 로 구별한다.

### B-2 (발견 16) — `required_auto` (집합 동등) / `allowed_auto` (부분집합)

부분집합 검사는 「맞는 다섯」과 **「전혀 없음」**을 구별하지 못한다 — 빈 집합은 모든 집합의
부분집합이므로, 탐지가 통째로 멈춰도 녹색이다.

| 강도 | 적용 | 이유 |
|---|---|---|
| `required_auto` — **집합 동등** | PNG 11개 + PDF 1개 … **16 케이스** | 결정적 입력 |
| `allowed_auto` — 부분집합 | JPG 3개 (회전·흐림 촬영풍) | `保険者番号` 계열 중 **어느 멤버**를 OCR 이 복원하는지는 우리가 할 수 있는 약속이 아니다 |

> **전환 직후 이 검사가 바로 유령 멤버를 잡았다.** `kouki.png` 의 기대표는
> `hihokensha_bango` 를 싣고 있었는데 **그 필드는 한 번도 발화하지 않는다** — 後期高齢者 변형의
> `被保険者番号` 레이블이 충분히 깨져서 값은 **구조 폴백**이 복원하고, 폴백은 保険者番号 계열
> 전체를 한 키로 파일한다. 부분집합 검사에서는 「허용된 여분」으로 조용히 통과하던 항목이다.
> 告知要求制限 이 그 계열을 **한 규칙**으로 덮으므로 **덮이는 것은 달라지지 않는다** —
> 달라진 것은 기대표가 사실을 말하는지 여부다.

### B-3 (발견 18) — `try/finally`

`catEnabled` 는 `resetAll()` 도 파일 재로드도 복원하지 않는 모듈 상태다. `__allCatsOff()` 와
`__restoreCats()` 사이에서 **무엇이든** 던지면 그 뒤 모든 케이스가 전 카테고리 OFF 로 돈다 —
직전 라운드에 한 번 당했고, 그때 빨개진 14건 중 **11건은 다른 문서의 멀쩡한 단언**이었다.

이제 `try/finally` 로 감싸고, **복원 자체를 단언**한다 (`restored` + `catEnabled` 에 `false` 가
하나도 없음). 전체 런에 예외를 주입한 실측: **8개 LOAD 에러로 격리, 나머지 398 단언 전부 녹색**
(§3 P-7). 복원 행 8개 전부 `restored` 로 기록됐다.

### B-4 (발견 12) — 「이 목적의 규칙이 없습니다」

매트릭스는 **제공하려는 (문서, 필드, 목적) 을 전부 열거**하고, 열거하지 않은 조합은 `null` 이다
— 「침묵은 허가가 아니다」. 그 결과 목적을 바꾸면 목록이 **통째로 빌 수 있다**:
`資格確認書 + 個人番号手続` 은 아무것도 제공하지 않는다
(告知要求制限 쪽은 医療保険関係事務 예외의 유무를 확인할 수 없어 `null`,
本人特定事項 keep 은 `identity_submit`·`bid_attachment` 만 지명).

드롭다운을 바꿨는데 아무 설명 없이 결과가 비면 **고장난 도구**로 읽히고, 그 다음으로 유력한
해석은 **「가릴 것이 없었다」**다. 그래서 바 안에 안내를 띄운다 —
「この文書で検出した項目には、この目的に適用されるルールがありません。手動で範囲を選択してください。」

조건은 **「현재 목적에서 JP 엔티티가 0개」**다. `JP_RULES` 기준의 「규칙 0개」는 `JP_EXTRA`
(`address_loose`·`tel`)가 네 목적 전부를 덮으므로 **영원히 참이 되지 않는다** — 사용자가 보는
증상은 「목록이 비었다」이므로 그쪽을 조건으로 삼았다. **문구와 조건의 어긋남 여부는
교차검증 질문 ⑤로 올렸다.**

> 이것은 **발견 6 의 완화이지 해결이 아니다.** 「미명시 조합을 `null` 로 버리는 대신
> 『탐지됨·정책 미확정·기본 OFF』로 노출할 것인가」는 제품 결정이고 §5 백로그 B-6 이다.

---

## 3. 변이 프로브 — 새 단언이 공허하지 않음을 전부 실측

전부 `public/safe/index.html` 또는 `test/safe/run.mjs` 를 되돌려 **결함을 되살린 뒤** 측정했다.
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
# SafeFile JP-1 S3b — Codex 지적 반영 (배포 차단 4건 + 정본 일치 + 하네스 강화)

날짜 2026-10-21 · 브랜치 `main` · **미배포 · 프로덕션 DB 미접촉**
입력 [`codex_review_s3_2026-10-21.md`](codex_review_s3_2026-10-21.md) · 직전 [`s3_report.md`](s3_report.md)
법적 정본 [`test/safe/fixtures/jp/jp_legal_matrix_alpha4.json`](../../test/safe/fixtures/jp/jp_legal_matrix_alpha4.json) (v2026-10-21b)

**골든 389 → 484, 0 실패.** 매트릭스 대조 188 triple 일치. SW 하네스 **9/9** 유지.

---

## 0. 한 줄 요약

> 이번 라운드가 닫은 것은 **「검출은 맞았는데 출력에서 조용히 사라지거나, 조용히 더 지워지는」 경로**다.
> 분류 실패가 무경고로 보호를 꺼버리던 것, カテゴリ 토글 하나가 법적 띠를 지우던 것,
> 페이지 순서가 양면 카드의 결과를 뒤집던 것, 검증 안 된 사각형이 기본으로 픽셀을 지우던 것.
> 네 건 모두 **밖에서 보면 정상 동작과 구별되지 않는다** — 그래서 네 건 모두 하네스로 고정했고,
> 고치기 전 코드를 실제로 넣어 **그 하네스가 빨개지는 것까지 확인**했다.

---

## 1. 필수 수정 4건 (배포 차단 해제 조건)

### 1-1 [Codex 1-1] 분류 실패가 무경고로 JP 보호를 전부 끄던 문제

`資格確認書` 는 제목만 읽히면 3점, 임계는 4점이다. 라벨 하나가 OCR 에서 깨지면 문서는
「一般文書」로 떨어지고 **일본 규칙이 하나도 실행되지 않은 채** 라틴 이름·주소 휴리스틱으로
조용히 넘어갔다. 사용자는 그 사실을 알 길이 없었다.

분류 결과를 **두 가지**로 나눴다. 하나는 `confident`(score ≥ min, 지금까지의 동작),
다른 하나는 **`low`** — 그 문서의 **제목**은 읽혔지만 점수가 모자란 상태다.

| | 분류 | 자동 띠 | 경고 배너 |
|---|---|---|---|
| score ≥ min | 확정 | 매트릭스대로 | 없음 |
| score < min **이고 제목 일치** | `low` (candidate scan only) | **전부 recommend 로 강등** | **표시** |
| 그 미만 + 일본 공문서 특징 있음 | 없음 | 없음 | **표시(차단성)** |
| 그 미만 + 특징 없음 | 없음 | 없음 | 없음 |

- 「일본 공문서 특징」 = `資格確認書|免許証|個人番号|マイナンバー|住民票|令和|平成|昭和` (`JP_SUSPECT_RE`).
  **분류가 아니라 경고의 방아쇠**다 — 이 정규식이 하는 유일한 일은 "자동 마스킹이 돌지 않았다"고
  말할지 말지를 정하는 것이다.
- 배너 문구(4개 언어): 「文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を
  選択してください。」 ko/en/es 에는 같은 뜻의 자국어 문장을 괄호로 덧붙였다 — 일본 문서를 다루는
  한국·영어권 사용자가 실제 사용자다.
- 배너는 `jpBar` 와 **독립**이다. 존재 이유가 "분류가 없어서 바가 안 뜨는 경우"에 보이는 것이기 때문.
- 스타일은 힌트가 아니라 **정지 신호**로 했다(좌측 5px 굵은 테두리 · `--no` 색 · 700).

**하네스**: `jp_warn` 4 케이스 (제목 단독 → `low`+경고 / 和暦만 → 경고 / 일본어 특징 없음 → 경고 없음 /
완전한 資格確認書 → 경고 없음). `low` 케이스는 **jp 자동 엔티티가 0인 것까지** 단언한다.

### 1-2 [Codex 2-2 · 6-1] 레이블 없는 사각 블록이 기본 출력에서 가려지던 문제

코드 주석은 "candidate, never automatic band" 라고 적고 있었지만, `recommend` 의 기본 mode 는
`no` 다 — **주석과 동작이 반대**였다. 얼굴사진·채워진 원형 인감(경계상자 채움률 ≈ 0.785)·검은 표
헤더가 전부 크기·종횡비·밀도 조건을 통과할 수 있고, 알파 더미에는 진짜 QR 이 없어(전략 v2 §4)
**이 경로는 골든 커버리지가 0이다.**

→ `unlabelledCode` 는 레벨과 무관하게 **`optional` / mode `ok`** 로 고정했다.
검증 안 된 추측이 기본 출력에서 내용을 지우지 않는다.

**실측으로 드러난 것**: `mynumber_card/back` 의 二次元コード 는 실제로 **레이블이 읽히지 않아**
이 경로를 탄다(같은 그림을 쓰는 `資格確認書` 3종은 레이블이 읽혀 자동 띠). 즉 이 분기는 픽스처에서
실행된다. 뒷면은 `back_all` 이 면 전체를 덮으므로 결과는 바뀌지 않는다 — §5 잔여 위험에 적었다.

**하네스**: `jp_unlabelled_block` — 주입된 finding 이 `optional`/`ok`/기본 출력 피복 ≤10% 임을 단언하고,
**같은 페이지의 레이블 있는 코드는 여전히 띠인 것**을 함께 단언한다(아무것도 안 가려서 통과하는 것을 막는다).

### 1-3 [Codex 6-4] 다중 페이지에서 첫 페이지가 전 페이지의 규칙을 정하던 문제

`jpExtract` 는 페이지별로 분류했지만 `jpApply` 는 1페이지의 `cls.doc/side` 로 전부 판정했다.
양면 카드를 한 PDF 로 스캔하면 **순서가 결과를 뒤집는다**:

| 순서 | 수정 전 | 수정 후 |
|---|---|---|
| 表 → 裏 | 裏面 에 띠 **없음** (個人番号 노출) | 裏(p1)만 전면 띠 |
| 裏 → 表 | **表까지** 전면 띠 | 裏(p0)만 전면 띠 |

- finding 마다 `doc`·`side`·`page` 를 저장하고, `jpState.pageCls[]` 를 둔다.
- 전면 띠(`back_all`)는 **그 페이지가 실제로 裏面인 페이지마다** 건다.
- 분류 불가 페이지는 **1페이지에 분류가 있을 때만** 1페이지 규칙을 상속한다.

**하네스**: `jp/2page` — 커밋된 단면 PNG 2장으로 **런타임에** 2페이지 PDF 를 만들어(`out/gen/`,
비커밋) 양쪽 순서를 돌린다. 페이지별 doc/side · `back_all` 이 걸린 페이지 번호 · 뒷면 피복 ≥99% ·
앞면 피복 ≤60% 를 단언한다.
> 부수로 하네스 결함 하나를 잡았다: `pages.length > 0` 은 **"로드 완료"가 아니다**. 페이지는 한 장씩
> push 되므로 2페이지 OCR 문서에서는 2페이지가 아직 Tesseract 안에 있을 때 true 가 되고,
> 그 뒤 측정값은 전부 **문서 절반**을 설명한다. 완료 신호를 `#docWrap` 노출로 바꿨다.

### 1-4 [Codex 4-6] 일반 카테고리 토글이 법적 띠를 조용히 해제하던 문제

`back_all`·`qr` 는 타입이 `other` 다. 사용자가 「その他」 체크를 끄면 **マイナカード裏面 전체 띠와
資格確認書 QR 띠가 출력에서 사라진다.** 경고도 없다.

- 엔티티에 `legal` 플래그를 두고 `isOn` 이 **카테고리를 보지 않게** 했다.
  `const isOn = e => e.legal ? true : catEnabled[e.type] !== false;`
- 법적 preset 은 **「法令・提出先ルール」 전용 그룹**(⚖️, 붉은 좌측 테두리)에 모아 카테고리 그룹에서
  꺼냈다. 해제는 **개별 항목에서만** 가능하고 해제하면 경고 토스트가 뜬다.
- 카테고리 세그먼트 버튼(타입 단위 일괄)과 **전체 공개** 버튼은 법적 띠를 건드리지 않는다.
  **전체 비공개**는 건드린다 — 그 방향은 피복을 늘리기만 한다.
- 대상: `back_all · qr · my_number · jumin_code · hokensha_bango · kigo · bango · edaban · hihokensha_bango`.

**하네스**: `require_legal` — **모든 카테고리를 끈 상태**에서 해당 필드의 띠가 살아 있는지
(`located ∧ on ∧ mode≠ok ∧ __maskRects 교차`) 단언한다.

---

## 2. 정본 일치 (Codex 4-1 ~ 4-4, 5-1)

### 2-1 `check_matrix.mjs` — 두 번째 손으로 쓴 표를 테스트로 묶었다

페이지는 빌드 단계가 없는 단일 정적 파일이라 `JP_RULES` 는 JSON 정본의 **손으로 쓴 거울**이다.
손으로 쓴 두 번째 표는 어긋나기 마련이고(Codex 가 7건을 찾았다), 그래서 어긋남을 **읽기 과제가 아니라
테스트 실패**로 만들었다:

1. JSON 에서 `(doc, field, purpose) → level` 을 파생한다,
2. `index.html` 에서 `JP_RULES`·`jpLevel`·`JP_LEGAL_FIELDS` 를 **잘라내 실행**한다,
3. 두 표 중 **어느 쪽에라도 있는** 모든 triple 을 대조한다 (188개),
4. 불변식 **`verified:false ⇒ auto·gate 금지`** 를 JSON 에 강제한다,
5. 비교 횟수가 100 미만이면 **추출이 깨진 것으로 보고 실패**시킨다 (공허한 통과 방지).

`run.mjs` 가 맨 먼저 호출한다 — 표가 어긋난 채로 골든이 초록일 수 없다.
**실효성 확인**: `jumin_code` 를 `auto` 로 되돌려 넣으니 3건 불일치로 exit 1.

### 2-2 매트릭스 스키마 확장

| 추가 | 왜 |
|---|---|
| `fields: [코드 필드 키]` | 사람이 읽는 필드명(「保険者番号・記号・番号・枝番・被保険者番号」)과 코드 키를 기계적으로 잇는다. 정본이 분해 방식까지 소유한다 |
| `optional_when: [purpose]` | 「법적 주장 없이 UI 로만 제공」을 명시적으로 쓴다. 코드 폴백이 아니라 데이터다 |
| `gate_requires_confirmation` | 個人番号 해제가 드롭다운만으로 되지 않는다는 사실을 정본에 적는다 |
| `_schema.derivation` / `.invariant` | 파생 규칙과 불변식을 표 옆에 둔다 — `check_matrix.mjs` 가 구현이고 이쪽이 명세다 |

### 2-3 레벨 변경 (요청받은 대로 + 근거)

| 문서 | 필드 | 전 | 후 | 근거 |
|---|---|---|---|---|
| 運転免許証 | `license_no` | 전 목적 `optional` | `identity_submit`=**keep**, `consult_share`=`optional`, 나머지 **null** | 정본의 `must_keep_when:[identity_submit]` 그대로 |
| 住民票 | `jumin_code` | `auto` | **`recommend`** | 정본 `verified:false`. 출처 없는 규칙은 자동이 될 수 없다. **기본 ON 은 그대로** — 띠의 세기는 안 변하고 「auto」라고 부르지 않을 뿐 |
| 住民票 | `honseki`·`hittosha` | 전 목적 `recommend` | `identity_submit`·`consult_share`=`recommend`, `my_number_procedure`·`bid_attachment`=**`optional`** | 그 두 목적에서 불필요하다는 출처가 없다 |
| 住民票 | `setaiin` | 2목적 recommend + 폴백 optional | 위와 동일하게 명시 | 폴백이 아니라 명시 |
| 資格確認書 | `jigyosho`·`hokensha_name`·`shikaku_date` | 코드에만 있던 keep | 정본에 **`verified:false` keep 으로 편입** + **탐지 규칙 신설** | Codex 4-1 「구현이 정본에 없는 항목을 추가함」. 숨기는 대신 정본에 적고 출처 없음을 표기했다. 탐지 규칙이 없어 **keep 경고가 생길 수 없던 죽은 규칙**이었으므로 규칙도 함께 넣었다 |
| 4문서 공통 | 本人特定事項 | `keep: P_ALL` | `keep: [해당 목적]`, `optional: [consult_share]` | 相談用共有 에는 제출처 요건이 없다. 정본이 침묵하면 **UI 에 내지 않는 것**이 기본인데(아래), 그러면 상담 공유에서 자기 이름을 가릴 수단이 사라진다 → 정본에 `optional_when` 으로 **명시**했다(출처 없음·자동 불가) |
| 4문서 공통 | `address_loose`·`tel` | 코드에만 있던 `JP_EXTRA` | 정본 **`general_jp` 섹션**으로 편입 | Codex 4-1 「법적 정본에 전혀 없음」 |

### 2-4 [Codex 4-2] 미명시 조합은 `null` — UI 에 내지 않는다

`return r.keep ? 'optional' : 'optional'` 은 조건이 무의미했고, 매트릭스가 **의도적으로 침묵한 조합**과
「선택 제공」을 구별하지 못했다. 이제 `jpLevel` 은 **어느 목록에도 없으면 `null`** 을 돌려주고
`jpApply` 가 그 finding 을 건너뛴다. 「침묵은 허가가 아니다」.

### 2-5 [Codex 4-4] マイナ裏面 안내 완화 + 확인 체크박스

문구를 4개 언어에서 바꿨다 — 「~できません」(행위·주체·예외 생략) → 복사·보관의 **제한**과
**제출처 조건**을 말한다:

> 身元確認が目的なら表面のみ提出してください。番号法上、法令で認められた事務以外で個人番号を
> 複写・保管することは制限されています。「個人番号手続」は、提出先が法定の個人番号関係事務を
> 行う場合にのみ選んでください。

그리고 **드롭다운만으로는 해제되지 않게** 했다. `個人番号手続` 선택 + **확인 체크박스 1개**
(「提出先が法定の個人番号関係事務を行うことを確認しました。」)가 모두 있어야 `back_all`·`my_number`·`qr`
의 띠가 풀린다. 미확인 상태에서는 레벨이 `keep` → **`gate`** 로 되돌아가 띠가 유지된다
(note `mn_unconfirmed`). 목적을 바꾸면 체크는 **항상 초기화**된다 — 이전 목적에서 켜둔 체크는
이번 목적의 확인이 아니다.

**하네스**: 같은 문서·같은 목적으로 **두 케이스**를 둔다 — 확인 ✓(keep·clear) / 확인 ✗(gate·banded).
한쪽만으로는 게이트가 움직인다는 것도, 안 움직인다는 것도 증명되지 않는다.

### 2-6 [Codex 1-5] 체크디지트 출처 정정 + 경계 벡터

산식은 옳았고 **출처 표기만 틀렸다**(「番号法施行令 別表」). 정확한 근거는
**e-Gov 관련 명령 제5조**(`426M60000008085_20231215_505M60004008017`)다. 주석에 링크와 함께
"2026-10-21 이전 인용이 틀렸다"는 사실을 남겼다 — 틀린 인용을 조용히 지우면 다음 사람이
같은 출처를 다시 찾는다. 省令 은 「나머지가 0 또는 1 이면 검사숫자 0」으로 쓰는데 구현의
`chk ≥ 10 → 0` 과 **동치**임을 주석에 적고, **그 두 경계를 테스트 벡터로** 넣었다.

---

## 3. 하네스 강화 (Codex 5-2 · 5-3 · 5-5 · 5-6)

### 3-1 숫자 필드는 피복률이 아니라 **잉크 연결요소**로 본다 [5-3]

60% 는 **얼마나** 가렸는지만 말하고 **어디를** 가렸는지는 말하지 않는다. 직전 라운드가 스스로
기록한 사례가 바로 그것이다 — `保険者番号` 피복 **96%**, 선두 숫자는 띠 **밖**.

→ `保険者番号계열 · 個人番号 · 住民票コード · 免許証番号` 는 기대 박스 안의 잉크를
**연결요소로 라벨링**해 **모든 성분이 99% 이상 덮였는지** 본다. 성분이 **0개면 실패** —
숫자 박스에 잉크가 없을 리 없고, 0개를 통과시키면 그 단언은 공허하다.
임계는 탐지기의 40 이 아니라 **60** 을 쓴다: 픽스처의 見本 워터마크는 합성 후 배경에서 약 48 떨어져
있고, 띠가 워터마크까지 덮을 의무는 없다.

**실효성 확인**: `ocrCanvas` 의 `w.text.trim()` 을 제거해 **실제로 기록된 그 결함**을 되살리니
`JP_INK — hihokensha_bango (8 comp, worst 74%)` 로 실패했다. 같은 상태에서 60% 게이트는 통과한다.

### 3-2 기대 키가 픽스처에 없으면 **FAIL** [5-5]

「variant 에 없는 키는 skipped 로 보고」는 **초록 총계 옆의 아무도 안 읽는 한 줄**이었다.
이제 `JP_SPEC` 실패다. 대신 **variant 별 기대표를 실제로 맞췄다** — `gen.py` 의 `finalize()` 가
해당 variant 의 boxes 로 purpose 목록을 **가지치기**하고, 기존 5건(kenpo/kokuho 의 `hihokensha_bango`,
kokuho/kouki 의 `jigyosho`, kouki 의 `kigo/bango/edaban`)을 정리했다.

### 3-3 `keep: "all"` 은 전 박스를 열거한다 [5-5]

빈 배열로 치환하면 **표에서 가장 강한 약속이 유일하게 아무도 검사하지 않는 항목**이 된다.
이제 `boxes_png` 전체를 열거한다.
⚠️ **다만 현재 이 분기에 도달하는 케이스는 없다** — `keep:"all"` 을 가진 픽스처 목적은
`医療機関提示` 뿐이고 그에 대응하는 앱 제출목적이 없다(진료 제시는 마스킹 대상이 아니다).
수정은 올바르지만 **지금은 실행되지 않는다**. 백로그에 올렸다.

### 3-4 `require_banded` 는 좌표까지 본다 [5-5]

`mode !== 'ok'` 는 **카테고리가 꺼졌거나 박스가 비어 있어도 참**이다.
이제 `located ∧ isOn ∧ mode≠'ok' ∧ 그 엔티티가 칠할 rect 가 실제 __maskRects 안에 있음`을 전부 본다.
`require_clear` 도 같은 방식으로 "maskRects 에 없음"까지 단언한다.

> ⚠️ **정직하게 적어둘 것**: 네 번째 조건(`inMask`)은 **지금은 앞의 세 조건에서 따라 나온다.**
> `__maskRects` 와 `__fieldBands` 가 **같은 `mergeLineBoxes`+`bandRect`** 로 좌표를 계산하므로
> `inMask ⟺ located ∧ isOn ∧ mode≠'ok'` 이다 — 반례를 만들 수 없다.
> 실제로 힘을 보태는 것은 **`located`·`isOn` 두 조건**(이것이 지적된 공백이다)과,
> 좌표를 독립적으로 재는 `JP_INK`·`JP_MASK`·`JP_KEEP` 쪽이다.

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'rg -n "JP_BACK_ANCHORS|viaBackAnchor|JP_SUSPECT_RE|JP_WARN|jpTailEnd|jpKeepOnly|JP_LEGAL|legal_enforcement|gate_requires_confirmation|JP_EMPTY|__allCatsOff|__restoreCats|required_auto|allowed_auto|NO LABELLED|labelled code" public/safe/index.html test/safe/check_matrix.mjs test/safe/run.mjs test/safe/specs.json test/safe/fixtures/jp/jp_legal_matrix_alpha4.json docs/jp/s3c_report.md docs/jp/codex_review_s3b_2026-10-21.md' in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
test/safe/specs.json:278:          "required_auto": [
test/safe/specs.json:310:          "required_auto": [
test/safe/specs.json:339:          "required_auto": [
test/safe/specs.json:364:          "required_auto": []
test/safe/specs.json:385:          "required_auto": []
test/safe/specs.json:409:          "required_auto": []
test/safe/specs.json:427:          "required_auto": []
test/safe/specs.json:452:          "required_auto": [
test/safe/specs.json:468:          "required_auto": [],
test/safe/specs.json:509:          "required_auto": [],
test/safe/specs.json:521:          "required_auto": []
test/safe/specs.json:534:          "required_auto": []
test/safe/specs.json:551:          "required_auto": []
test/safe/specs.json:560:          "required_auto": [],
test/safe/specs.json:574:          "required_auto": []
test/safe/specs.json:602:          "required_auto": [
test/safe/specs.json:635:          "allowed_auto": [
test/safe/specs.json:664:          "allowed_auto": []
test/safe/specs.json:690:          "allowed_auto": [
test/safe/specs.json:708:          "required_auto": [],
test/safe/check_matrix.mjs:16: *   6. derive the LEGAL group per document from `legal_enforcement: true` and
test/safe/check_matrix.mjs:17: *      require set equality with JP_LEGAL — plus the invariant
test/safe/check_matrix.mjs:18: *      `verified:false ⇒ never legal_enforcement`. The old check only asked
test/safe/check_matrix.mjs:53:  if (rule.legal_enforcement === true) {
test/safe/check_matrix.mjs:55:      fail(where, 'verified:false but legal_enforcement:true — a rule whose citation we could not secure may not assert a statutory restriction');
test/safe/check_matrix.mjs:95:const legalSrc = slice('const JP_LEGAL = {', '\n};\n');
test/safe/check_matrix.mjs:96:let JP_RULES, jpLevel, JP_LEGAL;
test/safe/check_matrix.mjs:98:  ({ JP_RULES, jpLevel, JP_LEGAL } =
test/safe/check_matrix.mjs:99:    new Function(`${rulesSrc}\n${levelSrc}\n${legalSrc}\nreturn {JP_RULES, jpLevel, JP_LEGAL};`)());
test/safe/check_matrix.mjs:131:for (const doc of new Set([...Object.keys(matrixLegal), ...Object.keys(JP_LEGAL)])) {
test/safe/check_matrix.mjs:133:  const got = new Set(JP_LEGAL[doc] || []);
test/safe/check_matrix.mjs:134:  if (!JP_LEGAL[doc]) fail(`JP_LEGAL.${doc}`, 'document missing from JP_LEGAL (write [] if it has no statutory field)');
test/safe/check_matrix.mjs:135:  for (const f of got) if (!want.has(f)) fail(`JP_LEGAL.${doc}.${f}`, 'in the legal group but the matrix does not mark it legal_enforcement:true');
test/safe/check_matrix.mjs:136:  for (const f of want) if (!got.has(f)) fail(`JP_LEGAL.${doc}.${f}`, 'matrix says legal_enforcement:true but the code leaves it to the category checkboxes');
test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:10:    "legal_enforcement": "true 인 규칙만 UI 의 「法令・提出先ルール」 그룹에 들어간다. 그 그룹의 항목은 카테고리 체크박스로 사라지지 않고, 해제하면 「法令上、収集・保管が制限される場合があります」 를 말한다. 그러므로 verified=false 인 규칙에는 허용되지 않는다 — 출처를 확보하지 못했다고 스스로 적은 규칙이 법령 제한을 단정할 수는 없다. (住民票コード 가 그 경우다: 既定ON·解除可 인 일반 「要確認」 항목으로 둔다.) 속성이 없으면 false. test/safe/check_matrix.mjs 가 이 속성에서 문서별 집합을 파생해 public/safe/index.html 의 JP_LEGAL 과 집합 동등성을 대조하고, verified=false 에 붙는 것을 금지한다."
test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:29:         "source": ["https://www.mhlw.go.jp/stf/newpage_13989.html", "https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf", "https://www.kyosai.metro.tokyo.jp/assets/84b47fd406a8378372a6015863f83bc93c0c8a75.pdf"], "verified": true, "legal_enforcement": true},
test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:32:         "legal_basis": "番号を判読可能なため同一扱い（大阪府・千葉市運用）。制限の根拠は運用通知そのものではなく、その通知が実施している 告知要求制限 — 機械可読な複製も番号の告知に当たるため同じ制限が及ぶ → legal_enforcement", "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"], "verified": true, "legal_enforcement": true},
test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:76:         "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/", "https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true, "legal_enforcement": true,
test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:77:         "gate_requires_confirmation": "my_number_procedure への解除は目的ドロップダウンだけでは足りない。確認（チェックボックス1つ）を要求する。確認の文言は利用者が実際に確かめられる事実でなければならない — 「提出先が法定の個人番号関係事務を行う」は受領者の法的地位の判定であって利用者には確かめられない。代わりに 「提出先の案内で個人番号（裏面）の提出が明示的に求められていることを確認した」 を問い、求められていなければ解除しないよう添える。PPC FAQ は「意図せず見た」と「複写・記録」を区別するが、どちらも提出先の適法性を前提にしており、FAQ 自体はチェックボックスのような利用者確認を適法性の証明手段として示していない（Codex 6b-11）"},
test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:92:         "legal_basis": "番号法 収集制限。本人確認目的なら個人番号なしの住民票を取り直すのが原則", "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"], "verified": true, "legal_enforcement": true,
test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:93:         "gate_requires_confirmation": "mynumber_card 裏面全体と同じ確認を要求する"},
test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:96:         "legal_basis": "住民基本台帳法 利用制限（個人識別符号）と理解しているが条文・運用の出典を確保できていない → verified=false。既定ON で帯を引くが『自動（auto）』とは呼ばない。legal_enforcement も付けない — 出典を確保できていないと自ら書いた規則が「提出先は保管できない」と断定することはできない。一般の「要確認」項目としてカテゴリ制御下に置く（Codex 6b-10）",
docs/jp/s3c_report.md:33:| A-2 | 발견 1 — `lowconf` 문구가 출력과 모순 | **닫힘** | `(jp warn) 資格確認書 제목 단독 … 후보 띠 적용 + 확인 요구` (JP_WARN_TEXT + JP_WARN_BANDS) | P-1 → 1 실패 |
docs/jp/s3c_report.md:34:| A-2 | 발견 2 — `JP_SUSPECT_RE` 和暦 단독 오경고 | **닫힘** | `(jp warn) 和暦만 있는 일본어 이력서 → 경고 없음` · `(jp warn) 免許証 언급만 … 차단성 경고 + 띠 0` | P-1 → 1 실패 |
docs/jp/s3c_report.md:37:| A-4 | 발견 11 — 확인 문구가 검증 불가한 사실을 단정 | **닫힘** | 문구 교체 (4개 언어) + 정본 `gate_requires_confirmation` 갱신 | — (문구 변경, 측정 대상 아님) |
docs/jp/s3c_report.md:38:| B-1 | 발견 14 — `filter().every()` 공허 통과 | **닫힘** | `(jp unlabelled) labelled code still banded` → `>=1 banded` | P-6 → 1 실패 |
docs/jp/s3c_report.md:39:| B-2 | 발견 16 — allowlist 가 부분집합만 확인 | **닫힘** | `JP_AUTO_SET` 16 케이스가 **집합 동등**(`required_auto`), 3 케이스만 부분집합(`allowed_auto`) | 전환 직후 kouki 의 유령 멤버를 즉시 잡음 (§2-B2) |
docs/jp/s3c_report.md:40:| B-3 | 발견 18 — `__allCatsOff` 에 `try/finally` 없음 | **닫힘** | 전체 런에 예외 주입 → 8 LOAD 에러로 **격리**, 나머지 398 단언 전부 녹색 | P-7 (§3) |
docs/jp/s3c_report.md:41:| B-4 | 발견 12 — 목적 규칙 0개일 때 무설명 | **닫힘** | `jp/shikaku_kakuninsho/kenpo.png [my_number_procedure]` (JP_EMPTY + JP_ENTITIES) | — (신규 경로, 케이스가 유일한 증거) |
docs/jp/s3c_report.md:61:직전 페이지의 class 가 { doc: D, side: 'front' }   ∧   이 페이지 텍스트가 JP_BACK_ANCHORS[D] 와 일치
docs/jp/s3c_report.md:65:const JP_BACK_ANCHORS = {
docs/jp/s3c_report.md:72:뒷면의 증거가 될 수 없다. 승격된 페이지는 `viaBackAnchor: true` 를 달아 추적 가능하다.
docs/jp/s3c_report.md:80:| `表 + 裏(タイトル切除)` | `front.png` + `back.png` 를 **y≥100 으로 크롭**(타이틀 「個人番号カード 裏面」 제거 → 스스로 분류 불가, 그러나 `個人番号` 앵커는 남는다) | `mynumber_card/front + mynumber_card/back`, `viaBackAnchor=true`, 2페이지 전면 띠 ≥99%, 1페이지 ≤60% |
docs/jp/s3c_report.md:81:| `表 + 無関係な添付` | `front.png` + `testdocs/1_text.pdf` **1페이지를 pdf.js 로 렌더** (한국어 이력서 — 네 문서 중 어느 것도 아니다) | `mynumber_card/front + null`, `viaBackAnchor=false`, **2페이지 JP 엔티티 0**, 2페이지 피복 ≤10%, 1페이지 JP 엔티티 ≥1 |
docs/jp/s3c_report.md:104:**`JP_SUSPECT_RE` 에서 `令和|平成|昭和` 를 제거했다.** 일본어 이력서·청구서·계약서는 전부 和暦을
docs/jp/s3c_report.md:127:| ① `jpTailEnd` — 값의 끝을 **같은 세그먼트의 다음 알려진 레이블 직전**으로 제한 | 모든 값 경로(tel·digits·re·addr·last)에 적용. 性別 정규식이 다음 열의 `男` 을 잡을 이유도 없다 | 이웃 레이블이 **읽힌** 경우 |
docs/jp/s3c_report.md:128:| ② `jpKeepOnly` 필드는 **4자리 이상 숫자 런**을 `used`·boxes·value **어디에도** claim 하지 않는다 | keep/optional 레벨만 가진 필드 = 아무것도 가리지 않는 필드 | 이웃 레이블이 **OCR 로 깨진** 경우 — 이 서식에서는 **측정된 정상**이다 (`保険者番号` 가 5개 중 3개에서 `RREES`/`REEES`/`WREEES`) |
docs/jp/s3c_report.md:146:**발견 10.** `JP_LEGAL_FIELDS` 는 평평한 필드명 Set 이었고, 검증은 「그 이름이 매트릭스
docs/jp/s3c_report.md:151:**지금**: 정본에 **명시 속성 `legal_enforcement: true`** 를 두고, 코드는 **문서별** 집합을 갖는다.
docs/jp/s3c_report.md:154:const JP_LEGAL = {
docs/jp/s3c_report.md:166:1. `legal_enforcement: true` ⇒ `verified: false` **금지** (출처를 확보하지 못했다고 스스로 적은
docs/jp/s3c_report.md:168:2. 정본에서 파생한 문서별 집합 ↔ `JP_LEGAL` **집합 동등** (부분집합이 아니다 —
docs/jp/s3c_report.md:196:해제하지 말라는 지침을 붙였다. 4개 언어 전부. 정본의 `gate_requires_confirmation` 에 이유를 적었다.
docs/jp/s3c_report.md:207:`length > 0` 을 먼저 요구하고, 실패 문구를 `NO LABELLED CODE FOUND` 로 구별한다.
docs/jp/s3c_report.md:209:### B-2 (발견 16) — `required_auto` (집합 동등) / `allowed_auto` (부분집합)
docs/jp/s3c_report.md:216:| `required_auto` — **집합 동등** | PNG 11개 + PDF 1개 … **16 케이스** | 결정적 입력 |
docs/jp/s3c_report.md:217:| `allowed_auto` — 부분집합 | JPG 3개 (회전·흐림 촬영풍) | `保険者番号` 계열 중 **어느 멤버**를 OCR 이 복원하는지는 우리가 할 수 있는 약속이 아니다 |
docs/jp/s3c_report.md:228:`catEnabled` 는 `resetAll()` 도 파일 재로드도 복원하지 않는 모듈 상태다. `__allCatsOff()` 와
docs/jp/s3c_report.md:229:`__restoreCats()` 사이에서 **무엇이든** 던지면 그 뒤 모든 케이스가 전 카테고리 OFF 로 돈다 —
docs/jp/s3c_report.md:264:| P-1 | `JP_SUSPECT_RE` 에 `令和\|平成\|昭和` 복원 **+** `lowconf` 가 `jpWarnUnclassified` 를 쓰게 | **2 실패** — `JP_WARN_TEXT`(lowconf 배너가 「自動黒塗りは適用していません」를 말한다) · `JP_WARN`(和暦만 있는 이력서에 `unclassified` 경고) |
docs/jp/s3c_report.md:266:| P-3 | `jpTailEnd(...)` → `seg.t.length` (경계 제거) + ② 비활성 | **2 실패** — `hokensha_bango` **MISSING**, `99221010` **NOT masked** |
docs/jp/s3c_report.md:268:| P-5 | `JP_LEGAL.juminhyo` 에 `jumin_code` 복원 | `check_matrix` **exit 1** — 「in the legal group but the matrix does not mark it legal_enforcement:true」 |
docs/jp/s3c_report.md:269:| P-6 | `unlabelledCode: true` 강제 (레이블 QR 탐지 제거) | **1 실패** — `NO LABELLED CODE FOUND`. 참고: 옛 형태 `[].every(...)` 는 node 에서 **`true`** (실측) |
public/safe/index.html:1217:const JP_SUSPECT_RE = /資格確認書|免許証|個人番号|マイナンバー|住民票/;
public/safe/index.html:1218:function jpSuspect(pi){ return JP_SUSPECT_RE.test(jpPageText(pi)); }
public/safe/index.html:1263:const JP_BACK_ANCHORS = {
public/safe/index.html:1531:   Mirrors `legal_enforcement: true` in the matrix, which check_matrix.mjs
public/safe/index.html:1538:const JP_LEGAL = {
public/safe/index.html:1544:function jpIsLegal(doc, field){ return (JP_LEGAL[doc] || []).includes(field); }
public/safe/index.html:1716:function jpTailEnd(seg, from, labels){
public/safe/index.html:1726:function jpKeepOnly(doc, field){
public/safe/index.html:1776:      const tailEnd = jpTailEnd(seg, L.end, labelSet);
public/safe/index.html:1777:      /* A keep-only field (jpKeepOnly) does not claim an identifier it happens
public/safe/index.html:1792:      const keepOnly = jpKeepOnly(cls.doc, r.field);
public/safe/index.html:1979:  // carries a back-only anchor for that same card (JP_BACK_ANCHORS). Anything
public/safe/index.html:1989:      const re = prev && prev.side === 'front' && JP_BACK_ANCHORS[prev.doc];
public/safe/index.html:1991:        c = { doc: prev.doc, side: 'back', score: prev.score, hits: prev.hits, low: !!prev.low, viaBackAnchor: true };
test/safe/run.mjs:196:      pageCls: jpState.pageCls.map(c => c && { doc: c.doc, side: c.side || null, low: !!c.low, viaBackAnchor: !!c.viaBackAnchor }),
test/safe/run.mjs:222:  window.__allCatsOff = function () {
test/safe/run.mjs:228:  window.__restoreCats = function () {
test/safe/run.mjs:593:      rec(tag, 'JP_WARN', 'blocking banner', c.expect_warn ? 'shown' : 'absent',
test/safe/run.mjs:639:        const left = await page.evaluate(() => window.__allCatsOff());
test/safe/run.mjs:642:        rec(tag, 'JP_LEGAL', f, 'survives all-categories-off',
test/safe/run.mjs:648:        const restored = await page.evaluate(() => window.__restoreCats());
test/safe/run.mjs:650:        rec(tag, 'JP_LEGAL', f + ' (categories restored)', 'restored+none-off',
test/safe/run.mjs:660:         required_auto — SET EQUALITY. A ceiling on the count cannot tell "the
test/safe/run.mjs:665:         allowed_auto — subset only, for the rotated/blurred JPG and the
test/safe/run.mjs:668:    if (c.required_auto || c.allowed_auto) {
test/safe/run.mjs:671:      if (c.required_auto) {
test/safe/run.mjs:672:        const want = [...new Set(c.required_auto)].sort();
test/safe/run.mjs:676:        const bad = got.filter(f => !c.allowed_auto.includes(f));
test/safe/run.mjs:677:        rec(tag, 'JP_AUTO_SET', 'auto fields ⊆ allowlist', '⊆ ' + (c.allowed_auto.join(',') || '(none)'),
test/safe/run.mjs:686:        rec(tag, 'JP_EMPTY', 'no-rules-for-purpose notice', c.expect_empty_notice ? 'shown' : 'absent',
test/safe/run.mjs:885:        String(!!(st.pageCls[1] && st.pageCls[1].viaBackAnchor)),
test/safe/run.mjs:886:        !!(st.pageCls[1] && st.pageCls[1].viaBackAnchor) === c.wantPromoted);
test/safe/run.mjs:1038:  rec(tag, 'JP_UNLABELLED', 'labelled code still banded', '>=1 banded',
test/safe/run.mjs:1039:    res.labelledCount ? (res.labelledBanded ? `banded ×${res.labelledCount}` : 'CLEAR') : 'NO LABELLED CODE FOUND', res.labelledBanded);
test/safe/run.mjs:1056:    rec('(jp warn)', 'JP_WARN', c.label, c.expect_warn ? `shown/${c.expect_warn}` : 'absent',
test/safe/run.mjs:1059:    rec('(jp warn)', 'JP_WARN_CLASS', c.label + ' class', c.expect_doc || 'null',
test/safe/run.mjs:1069:      rec('(jp warn)', 'JP_WARN_TEXT', c.label + ' banner text', c.expect_text_has,
test/safe/run.mjs:1075:      rec('(jp warn)', 'JP_WARN_BANDS', c.label + ' bands in output', '>=1',
test/safe/run.mjs:1078:      rec('(jp warn)', 'JP_WARN_BANDS', c.label + ' bands in output', '0',
test/safe/run.mjs:1084:      rec('(jp warn)', 'JP_WARN_NOAUTO', c.label + ' no jp auto', '(none)',
docs/jp/codex_review_s3b_2026-10-21.md:30:- 구현: `public/safe/index.html` — `jpClassify` / `jpSuspect` / `JP_SUSPECT_RE` / `JP_RULES` / `jpLevel` / `JP_LEGAL_FIELDS` / `jpScan` / `jpExtract`(push 의 doc·side) / `jpApply`(`resolve`) / `jpMnGateOpen` / `jpRenderBar` / `jpSetPurpose` / `isOn` / `renderList` / `sectionHtml` / 토글·bulk 핸들러 / `myNumberCheckOk` 주석 / i18n 4개 언어
docs/jp/codex_review_s3b_2026-10-21.md:33:- 하네스: `test/safe/run.mjs` (`__inkCover` / `__fieldBands` / `__allCatsOff`·`__restoreCats` / `__autoFields` / `jpCheckBox` / `checkJpDoc` / `checkJpMultiPage` / `checkJpMyNumber` / `checkJpUnlabelled` / `checkJpWarn` / `checkMatrix` / `loadDoc` 완료 조건)
docs/jp/codex_review_s3b_2026-10-21.md:46:1-1. **분류 실패 경고**. `jpClassify` 의 `low` 분기는 `def.title.some(t => txt.includes(t))` 하나에 걸려 있습니다. ① 제목이 깨지고 다른 키워드만 살아 점수가 3 이하인 양식에서는 `low` 에도 못 들어가고 **경고만** 뜨는데, 그 경고로 충분합니까? ② `JP_SUSPECT_RE` 에 `令和|平成|昭和` 가 들어 있어 **일본 문서 전반**이 걸립니다 — 일본어 이력서·청구서를 올린 사용자가 매번 「자동 마스킹이 적용되지 않았다」는 붉은 배너를 보게 되는데, 이 경고가 **늑대소년이 되어 진짜 실패를 묻어버릴** 위험은? ③ `low` 일 때 auto/gate 를 `recommend` 로 강등하는데, `recommend` 는 **기본 ON** 입니다. "자동 마스킹은 적용하지 않았다" 는 배너 문구와 실제 동작(기본 ON 띠가 그려짐)이 **모순됩니까?**
docs/jp/codex_review_s3b_2026-10-21.md:58:2-1. `check_matrix.mjs` 는 `index.html` 에서 **문자열 슬라이스**로 `JP_RULES`·`jpLevel`·`JP_LEGAL_FIELDS` 를 잘라 `new Function` 으로 실행합니다. 마커(`const P_NOT_MYNUM =` → 첫 `\n};\n`)가 깨지는 편집이 무엇입니까? 깨지면 **조용히 통과**합니까, 실패합니까? (구현자는 `compared < 100` 가드를 뒀다고 주장합니다 — 그 가드가 충분한 경계입니까?)
docs/jp/codex_review_s3b_2026-10-21.md:88:3-6. `require_legal` 은 `__allCatsOff()` 로 전역 `catEnabled` 를 꺼고 `__restoreCats()` 로 되돌립니다. 구현자는 첫 버전이 **복원을 안 해서 이후 300개 단언이 오염됐다**고 §6-2 에 적었습니다. 현재 버전에 **남은 전역 오염 경로**가 있습니까? (`catDefault`, `showAllCats`, `jpState.mnConfirmed`, `BAND_COLOR`, `aiDone` …)
docs/jp/codex_review_s3b_2026-10-21.md:201:    Two harness defects of my own, found and fixed here: __allCatsOff() leaked
docs/jp/codex_review_s3b_2026-10-21.md:297:    Two harness defects of my own, found and fixed here: __allCatsOff() leaked
docs/jp/codex_review_s3b_2026-10-21.md:1591:+  1823	    // An unlabelled code block is detection without golden coverage — candidate.
docs/jp/codex_review_s3b_2026-10-21.md:5294:+- 「일본 공문서 특징」 = `資格確認書|免許証|個人番号|マイナンバー|住民票|令和|平成|昭和` (`JP_SUSPECT_RE`).
docs/jp/codex_review_s3b_2026-10-21.md:5371:+2. `index.html` 에서 `JP_RULES`·`jpLevel`·`JP_LEGAL_FIELDS` 를 **잘라내 실행**한다,
docs/jp/codex_review_s3b_2026-10-21.md:5385:+| `gate_requires_confirmation` | 個人番号 해제가 드롭다운만으로 되지 않는다는 사실을 정본에 적는다 |
docs/jp/codex_review_s3b_2026-10-21.md:5579:+| 신규 단언 카테고리 | `JP_WARN` 12 · `JP_LEGAL` 13 · `JP_AUTO_SET` 19 · `JP_INK` 15 · `JP_MN_BOX` 3 · `JP_PAGECLASS`/`BACK_ONLY`/`BACK_COVER`/`FRONT_CLEAR` 각 2 · `JP_MYNUM_*` 23 · `JP_UNLABELLED` 4 · `JP_MATRIX` 1 |
docs/jp/codex_review_s3b_2026-10-21.md:5590:+| A | `isOn` 이 `e.legal` 을 무시 | `JP_LEGAL — qr / hokensha_bango: DROPPED` **2건 실패** |
docs/jp/codex_review_s3b_2026-10-21.md:5599:+1. **`__allCatsOff()` 가 전역 상태를 흘렸다.** `catEnabled` 는 `resetAll()` 도 파일 재로드도
docs/jp/codex_review_s3b_2026-10-21.md:5704:+const legalSrc = slice('const JP_LEGAL_FIELDS =', ']);');
docs/jp/codex_review_s3b_2026-10-21.md:5705:+let JP_RULES, jpLevel, JP_LEGAL_FIELDS;
docs/jp/codex_review_s3b_2026-10-21.md:5707:+  ({ JP_RULES, jpLevel, JP_LEGAL_FIELDS } =
docs/jp/codex_review_s3b_2026-10-21.md:5708:+    new Function(`${rulesSrc}\n${levelSrc}\n${legalSrc}\nreturn {JP_RULES, jpLevel, JP_LEGAL_FIELDS};`)());
docs/jp/codex_review_s3b_2026-10-21.md:5736:+for (const f of JP_LEGAL_FIELDS) {
docs/jp/codex_review_s3b_2026-10-21.md:5738:+  if (!inSome) fail(`JP_LEGAL_FIELDS.${f}`, 'not a field the legal matrix knows');
docs/jp/codex_review_s3b_2026-10-21.md:5754:/bin/zsh -lc "rg -n \"JP_SUSPECT_RE|function jpClassify|function jpScan|function jpExtract|function jpApply|function jpLevel|JP_LEGAL_FIELDS|function isOn|const isOn|jpMnGateOpen|jpRenderBar|jpSetPurpose|function renderList|function sectionHtml|myNumberCheckOk|JP_FIELD_RULES|shikaku_date|hokensha_name|jigyosho|__inkCover|__fieldBands|__allCatsOff|__restoreCats|__autoFields|checkJpDoc|checkJpMultiPage|checkJpMyNumber|checkJpUnlabelled|checkJpWarn|checkMatrix|async function loadDoc|auto_allow|require_legal|keep === 'all'|keep.*all\" public/safe/index.html test/safe/run.mjs test/safe/specs.json test/safe/fixtures/jp/gen.py test/safe/fixtures/jp/jp_legal_matrix_alpha4.json docs/jp/s3b_report.md" in /Users/sunghoon/Projects/docpack
docs/jp/codex_review_s3b_2026-10-21.md:5791:docs/jp/s3b_report.md:39:- 「일본 공문서 특징」 = `資格確認書|免許証|個人番号|マイナンバー|住民票|令和|平成|昭和` (`JP_SUSPECT_RE`).
docs/jp/codex_review_s3b_2026-10-21.md:5794:docs/jp/s3b_report.md:116:2. `index.html` 에서 `JP_RULES`·`jpLevel`·`JP_LEGAL_FIELDS` 를 **잘라내 실행**한다,
docs/jp/codex_review_s3b_2026-10-21.md:5806:docs/jp/s3b_report.md:344:1. **`__allCatsOff()` 가 전역 상태를 흘렸다.** `catEnabled` 는 `resetAll()` 도 파일 재로드도
docs/jp/codex_review_s3b_2026-10-21.md:5810:test/safe/run.mjs:210:  window.__allCatsOff = function () {
docs/jp/codex_review_s3b_2026-10-21.md:5811:test/safe/run.mjs:216:  window.__restoreCats = function () {
docs/jp/codex_review_s3b_2026-10-21.md:5819:test/safe/run.mjs:621:      const left = await page.evaluate(() => window.__allCatsOff());
docs/jp/codex_review_s3b_2026-10-21.md:5821:test/safe/run.mjs:628:      const restored = await page.evaluate(() => window.__restoreCats());
docs/jp/codex_review_s3b_2026-10-21.md:5851:public/safe/index.html:1204:const JP_SUSPECT_RE = /資格確認書|免許証|個人番号|マイナンバー|住民票|令和|平成|昭和/;
docs/jp/codex_review_s3b_2026-10-21.md:5852:public/safe/index.html:1205:function jpSuspect(pi){ return JP_SUSPECT_RE.test(jpPageText(pi)); }
docs/jp/codex_review_s3b_2026-10-21.md:5856:public/safe/index.html:1503:const JP_LEGAL_FIELDS = new Set(['back_all','qr','my_number','jumin_code',
docs/jp/codex_review_s3b_2026-10-21.md:5870:public/safe/index.html:1904:    const legal = JP_LEGAL_FIELDS.has(f) && mode === 'no';
docs/jp/codex_review_s3b_2026-10-21.md:5942:  1204	const JP_SUSPECT_RE = /資格確認書|免許証|個人番号|マイナンバー|住民票|令和|平成|昭和/;
docs/jp/codex_review_s3b_2026-10-21.md:5943:  1205	function jpSuspect(pi){ return JP_SUSPECT_RE.test(jpPageText(pi)); }
docs/jp/codex_review_s3b_2026-10-21.md:6082:  1503	const JP_LEGAL_FIELDS = new Set(['back_all','qr','my_number','jumin_code',
docs/jp/codex_review_s3b_2026-10-21.md:6384:  1904	    const legal = JP_LEGAL_FIELDS.has(f) && mode === 'no';
docs/jp/codex_review_s3b_2026-10-21.md:6728:   210	  window.__allCatsOff = function () {
docs/jp/codex_review_s3b_2026-10-21.md:6734:   216	  window.__restoreCats = function () {
docs/jp/codex_review_s3b_2026-10-21.md:6841:   581	      rec(tag, 'JP_WARN', 'blocking banner', c.expect_warn ? 'shown' : 'absent',
docs/jp/codex_review_s3b_2026-10-21.md:6881:   621	      const left = await page.evaluate(() => window.__allCatsOff());
docs/jp/codex_review_s3b_2026-10-21.md:6884:   624	      rec(tag, 'JP_LEGAL', f, 'survives all-categories-off',
docs/jp/codex_review_s3b_2026-10-21.md:6888:   628	      const restored = await page.evaluate(() => window.__restoreCats());
docs/jp/codex_review_s3b_2026-10-21.md:6889:   629	      rec(tag, 'JP_LEGAL', f + ' (categories restored)', 'restored', restored ? 'restored' : 'NOT RESTORED', restored, true);
docs/jp/codex_review_s3b_2026-10-21.md:7113:   857	  rec(tag, 'JP_UNLABELLED', 'labelled code still banded', 'banded', res.labelledBanded ? 'banded' : 'CLEAR', res.labelledBanded);
docs/jp/codex_review_s3b_2026-10-21.md:7130:   874	    rec('(jp warn)', 'JP_WARN', c.label, c.expect_warn ? `shown/${c.expect_warn}` : 'absent',
docs/jp/codex_review_s3b_2026-10-21.md:7133:   877	    rec('(jp warn)', 'JP_WARN_CLASS', c.label + ' class', c.expect_doc || 'null',
docs/jp/codex_review_s3b_2026-10-21.md:7140:   884	      rec('(jp warn)', 'JP_WARN_NOAUTO', c.label + ' no jp auto', '(none)',
docs/jp/codex_review_s3b_2026-10-21.md:7238:    82	const legalSrc = slice('const JP_LEGAL_FIELDS =', ']);');
docs/jp/codex_review_s3b_2026-10-21.md:7239:    83	let JP_RULES, jpLevel, JP_LEGAL_FIELDS;
docs/jp/codex_review_s3b_2026-10-21.md:7241:    85	  ({ JP_RULES, jpLevel, JP_LEGAL_FIELDS } =
docs/jp/codex_review_s3b_2026-10-21.md:7242:    86	    new Function(`${rulesSrc}\n${levelSrc}\n${legalSrc}\nreturn {JP_RULES, jpLevel, JP_LEGAL_FIELDS};`)());
docs/jp/codex_review_s3b_2026-10-21.md:7270:   114	for (const f of JP_LEGAL_FIELDS) {
docs/jp/codex_review_s3b_2026-10-21.md:7272:   116	  if (!inSome) fail(`JP_LEGAL_FIELDS.${f}`, 'not a field the legal matrix knows');
docs/jp/codex_review_s3b_2026-10-21.md:7357:    76	         "gate_requires_confirmation": "my_number_procedure への解除は目的ドロップダウンだけでは足りない。提出先が法定の個人番号関係事務を行うという確認（チェックボックス1つ）を要求する — PPC FAQ は「意図せず見た」と「複写・記録」を区別するが、どちらも提出先の適法性を前提にしている"},
docs/jp/codex_review_s3b_2026-10-21.md:7373:    92	         "gate_requires_confirmation": "mynumber_card 裏面全体と同じ確認を要求する"},
docs/jp/codex_review_s3b_2026-10-21.md:7777:  1904	    const legal = JP_LEGAL_FIELDS.has(f) && mode === 'no';
docs/jp/codex_review_s3b_2026-10-21.md:8023:   210	  window.__allCatsOff = function () {
docs/jp/codex_review_s3b_2026-10-21.md:8029:   216	  window.__restoreCats = function () {
docs/jp/codex_review_s3b_2026-10-21.md:8054:   581	      rec(tag, 'JP_WARN', 'blocking banner', c.expect_warn ? 'shown' : 'absent',
docs/jp/codex_review_s3b_2026-10-21.md:8094:   621	      const left = await page.evaluate(() => window.__allCatsOff());
docs/jp/codex_review_s3b_2026-10-21.md:8097:   624	      rec(tag, 'JP_LEGAL', f, 'survives all-categories-off',
docs/jp/codex_review_s3b_2026-10-21.md:8101:   628	      const restored = await page.evaluate(() => window.__restoreCats());
docs/jp/codex_review_s3b_2026-10-21.md:8102:   629	      rec(tag, 'JP_LEGAL', f + ' (categories restored)', 'restored', restored ? 'restored' : 'NOT RESTORED', restored, true);
docs/jp/codex_review_s3b_2026-10-21.md:8313:   857	  rec(tag, 'JP_UNLABELLED', 'labelled code still banded', 'banded', res.labelledBanded ? 'banded' : 'CLEAR', res.labelledBanded);
docs/jp/codex_review_s3b_2026-10-21.md:8330:   874	    rec('(jp warn)', 'JP_WARN', c.label, c.expect_warn ? `shown/${c.expect_warn}` : 'absent',
docs/jp/codex_review_s3b_2026-10-21.md:8333:   877	    rec('(jp warn)', 'JP_WARN_CLASS', c.label + ' class', c.expect_doc || 'null',
docs/jp/codex_review_s3b_2026-10-21.md:8340:   884	      rec('(jp warn)', 'JP_WARN_NOAUTO', c.label + ' no jp auto', '(none)',
docs/jp/codex_review_s3b_2026-10-21.md:8470:   210	  window.__allCatsOff = function () {
docs/jp/codex_review_s3b_2026-10-21.md:8476:   216	  window.__restoreCats = function () {
docs/jp/codex_review_s3b_2026-10-21.md:8538:   581	      rec(tag, 'JP_WARN', 'blocking banner', c.expect_warn ? 'shown' : 'absent',
docs/jp/codex_review_s3b_2026-10-21.md:8578:   621	      const left = await page.evaluate(() => window.__allCatsOff());
docs/jp/codex_review_s3b_2026-10-21.md:8581:   624	      rec(tag, 'JP_LEGAL', f, 'survives all-categories-off',
docs/jp/codex_review_s3b_2026-10-21.md:8585:   628	      const restored = await page.evaluate(() => window.__restoreCats());
docs/jp/codex_review_s3b_2026-10-21.md:8586:   629	      rec(tag, 'JP_LEGAL', f + ' (categories restored)', 'restored', restored ? 'restored' : 'NOT RESTORED', restored, true);
docs/jp/codex_review_s3b_2026-10-21.md:8839:+const JP_SUSPECT_RE = /資格確認書|免許証|個人番号|マイナンバー|住民票|令和|平成|昭和/;
docs/jp/codex_review_s3b_2026-10-21.md:8840:+function jpSuspect(pi){ return JP_SUSPECT_RE.test(jpPageText(pi)); }
docs/jp/codex_review_s3b_2026-10-21.md:8999:+const JP_LEGAL_FIELDS = new Set(['back_all','qr','my_number','jumin_code',
docs/jp/codex_review_s3b_2026-10-21.md:9110:+    const legal = JP_LEGAL_FIELDS.has(f) && mode === 'no';
docs/jp/codex_review_s3b_2026-10-21.md:9149:-    // An unlabelled code block is detection without golden coverage — candidate.
docs/jp/codex_review_s3b_2026-10-21.md:9454:+         "gate_requires_confirmation": "my_number_procedure への解除は目的ドロップダウンだけでは足りない。提出先が法定の個人番号関係事務を行うという確認（チェックボックス1つ）を要求する — PPC FAQ は「意図せず見た」と「複写・記録」を区別するが、どちらも提出先の適法性を前提にしている"},
docs/jp/codex_review_s3b_2026-10-21.md:9475:+         "gate_requires_confirmation": "mynumber_card 裏面全体と同じ確認を要求する"},
docs/jp/codex_review_s3b_2026-10-21.md:9627:+  window.__allCatsOff = function () {
docs/jp/codex_review_s3b_2026-10-21.md:9633:+  window.__restoreCats = function () {
docs/jp/codex_review_s3b_2026-10-21.md:9753:+      rec(tag, 'JP_WARN', 'blocking banner', c.expect_warn ? 'shown' : 'absent',
docs/jp/codex_review_s3b_2026-10-21.md:9792:+      const left = await page.evaluate(() => window.__allCatsOff());
docs/jp/codex_review_s3b_2026-10-21.md:9795:+      rec(tag, 'JP_LEGAL', f, 'survives all-categories-off',
docs/jp/codex_review_s3b_2026-10-21.md:9799:+      const restored = await page.evaluate(() => window.__restoreCats());
docs/jp/codex_review_s3b_2026-10-21.md:9800:+      rec(tag, 'JP_LEGAL', f + ' (categories restored)', 'restored', restored ? 'restored' : 'NOT RESTORED', restored, true);
docs/jp/codex_review_s3b_2026-10-21.md:10314:    82	const legalSrc = slice('const JP_LEGAL_FIELDS =', ']);');
docs/jp/codex_review_s3b_2026-10-21.md:10315:    83	let JP_RULES, jpLevel, JP_LEGAL_FIELDS;
docs/jp/codex_review_s3b_2026-10-21.md:10317:    85	  ({ JP_RULES, jpLevel, JP_LEGAL_FIELDS } =
docs/jp/codex_review_s3b_2026-10-21.md:10318:    86	    new Function(`${rulesSrc}\n${levelSrc}\n${legalSrc}\nreturn {JP_RULES, jpLevel, JP_LEGAL_FIELDS};`)());
docs/jp/codex_review_s3b_2026-10-21.md:10346:   114	for (const f of JP_LEGAL_FIELDS) {
docs/jp/codex_review_s3b_2026-10-21.md:10348:   116	  if (!inSome) fail(`JP_LEGAL_FIELDS.${f}`, 'not a field the legal matrix knows');
docs/jp/codex_review_s3b_2026-10-21.md:10433:    76	         "gate_requires_confirmation": "my_number_procedure への解除は目的ドロップダウンだけでは足りない。提出先が法定の個人番号関係事務を行うという確認（チェックボックス1つ）を要求する — PPC FAQ は「意図せず見た」と「複写・記録」を区別するが、どちらも提出先の適法性を前提にしている"},
docs/jp/codex_review_s3b_2026-10-21.md:10449:    92	         "gate_requires_confirmation": "mynumber_card 裏面全体と同じ確認を要求する"},
docs/jp/codex_review_s3b_2026-10-21.md:10819:2. 문제 / `JP_SUSPECT_RE`의 和暦 단독 조건은 일반 일본 문서에 경고를 과다 발생시킵니다. `令和|平成|昭和`만 있어도 분류 실패 경고가 표시되므로 이력서·청구서·계약서도 “문서 종류를 특정하지 못했다”는 붉은 경고 대상입니다. 경고가 “이 네 문서 중 하나로 의심된다”는 신호가 아니라 “일본 날짜가 있다”는 신호가 되어 늑대소년 위험이 실재합니다. / 근거([public/safe/index.html:1204](/Users/sunghoon/Projects/docpack/public/safe/index.html:1204), [public/safe/index.html:1870](/Users/sunghoon/Projects/docpack/public/safe/index.html:1870)) / 수정안: 문서별 약한 키워드 두 개 이상의 조합, 또는 제목 OCR 유사도와 필드 앵커 조합으로 suspect를 제한하십시오. 적어도 和暦 단독 양성·일본어 이력서·청구서 음성 테스트를 추가해야 합니다.
docs/jp/codex_review_s3b_2026-10-21.md:10835:10. 문제 / `JP_LEGAL_FIELDS` 검증은 “어딘가의 매트릭스에 같은 필드명이 있음”만 확인해 법적 그룹의 의미를 보장하지 않습니다. 문서·목적·`verified`·법적 출처를 보지 않습니다. 실제로 `verified:false`인 `jumin_code`도 legal 그룹에 들어가고, UI는 이를 풀면 “제출처가 보관할 수 없는 정보”라고 단정합니다. 정본은 바로 그 법적 출처를 확보하지 못했다고 씁니다. / 근거([public/safe/index.html:1503](/Users/sunghoon/Projects/docpack/public/safe/index.html:1503), [test/safe/check_matrix.mjs:113](/Users/sunghoon/Projects/docpack/test/safe/check_matrix.mjs:113), [test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:93](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:93), [public/safe/index.html:675](/Users/sunghoon/Projects/docpack/public/safe/index.html:675)) / 수정안: legal 여부를 문자열 Set에서 파생하지 말고 정본의 명시적 `legal_enforcement` 속성으로 문서·목적별 생성하십시오. `verified:false` 항목에는 법적 금지 문구를 표시하지 마십시오.
docs/jp/codex_review_s3b_2026-10-21.md:10843:14. 문제 / 레이블 없는 블록 테스트의 “labelled code still banded”는 빈 배열에서도 통과합니다. `filter(...).every(...)`는 대상이 0개면 `true`이므로 labelled QR 탐지가 완전히 사라져도 녹색입니다. / 근거([test/safe/run.mjs:850](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:850), [test/safe/run.mjs:857](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:857)) / 수정안: 필터 결과의 `length > 0`을 먼저 요구하십시오.
docs/jp/codex_review_s3b_2026-10-21.md:10847:16. 문제 / `auto_allow`의 `[]`와 `undefined` 구분은 실제로 성립하지만, 비어 있지 않은 allowlist는 “부분집합”만 확인합니다. 자동 필드가 전부 사라져 빈 배열이 되어도 `bad.length === 0`으로 통과합니다. 별도의 `min_auto`나 `require_banded`가 모든 allowlist 필드를 포괄하지 않는 케이스에서는 미탐을 숨깁니다. / 근거([test/safe/run.mjs:636](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:636), [test/safe/run.mjs:638](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:638)) / 수정안: 기대가 정확한 케이스는 집합 동등성을 검사하고, 선택적 필드가 있다면 `required_auto`와 `allowed_auto`를 분리하십시오.
docs/jp/codex_review_s3b_2026-10-21.md:10851:18. 문제 / 카테고리 복원은 정상 경로만 처리하고 `try/finally`가 없습니다. `__allCatsOff()` 이후 browser evaluation, reload 또는 assertion 코드가 예외를 던지면 `__restoreCats()`에 도달하지 않아 이후 케이스 전체가 오염됩니다. 구현자가 이미 같은 전역 누출을 한 번 겪었다는 점에서 이 경로를 남길 이유가 없습니다. / 근거([test/safe/run.mjs:620](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:620), [test/safe/run.mjs:628](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:628), [test/safe/run.mjs:630](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:630)) / 수정안: 각 legal 단언을 `try/finally`로 감싸고 finally에서 복원 및 검증하십시오. 더 안전하게는 테스트별 새 page/context를 쓰십시오.
docs/jp/codex_review_s3b_2026-10-21.md:10893:2. 문제 / `JP_SUSPECT_RE`의 和暦 단독 조건은 일반 일본 문서에 경고를 과다 발생시킵니다. `令和|平成|昭和`만 있어도 분류 실패 경고가 표시되므로 이력서·청구서·계약서도 “문서 종류를 특정하지 못했다”는 붉은 경고 대상입니다. 경고가 “이 네 문서 중 하나로 의심된다”는 신호가 아니라 “일본 날짜가 있다”는 신호가 되어 늑대소년 위험이 실재합니다. / 근거([public/safe/index.html:1204](/Users/sunghoon/Projects/docpack/public/safe/index.html:1204), [public/safe/index.html:1870](/Users/sunghoon/Projects/docpack/public/safe/index.html:1870)) / 수정안: 문서별 약한 키워드 두 개 이상의 조합, 또는 제목 OCR 유사도와 필드 앵커 조합으로 suspect를 제한하십시오. 적어도 和暦 단독 양성·일본어 이력서·청구서 음성 테스트를 추가해야 합니다.
docs/jp/codex_review_s3b_2026-10-21.md:10909:10. 문제 / `JP_LEGAL_FIELDS` 검증은 “어딘가의 매트릭스에 같은 필드명이 있음”만 확인해 법적 그룹의 의미를 보장하지 않습니다. 문서·목적·`verified`·법적 출처를 보지 않습니다. 실제로 `verified:false`인 `jumin_code`도 legal 그룹에 들어가고, UI는 이를 풀면 “제출처가 보관할 수 없는 정보”라고 단정합니다. 정본은 바로 그 법적 출처를 확보하지 못했다고 씁니다. / 근거([public/safe/index.html:1503](/Users/sunghoon/Projects/docpack/public/safe/index.html:1503), [test/safe/check_matrix.mjs:113](/Users/sunghoon/Projects/docpack/test/safe/check_matrix.mjs:113), [test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:93](/Users/sunghoon/Projects/docpack/test/safe/fixtures/jp/jp_legal_matrix_alpha4.json:93), [public/safe/index.html:675](/Users/sunghoon/Projects/docpack/public/safe/index.html:675)) / 수정안: legal 여부를 문자열 Set에서 파생하지 말고 정본의 명시적 `legal_enforcement` 속성으로 문서·목적별 생성하십시오. `verified:false` 항목에는 법적 금지 문구를 표시하지 마십시오.
docs/jp/codex_review_s3b_2026-10-21.md:10917:14. 문제 / 레이블 없는 블록 테스트의 “labelled code still banded”는 빈 배열에서도 통과합니다. `filter(...).every(...)`는 대상이 0개면 `true`이므로 labelled QR 탐지가 완전히 사라져도 녹색입니다. / 근거([test/safe/run.mjs:850](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:850), [test/safe/run.mjs:857](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:857)) / 수정안: 필터 결과의 `length > 0`을 먼저 요구하십시오.
docs/jp/codex_review_s3b_2026-10-21.md:10921:16. 문제 / `auto_allow`의 `[]`와 `undefined` 구분은 실제로 성립하지만, 비어 있지 않은 allowlist는 “부분집합”만 확인합니다. 자동 필드가 전부 사라져 빈 배열이 되어도 `bad.length === 0`으로 통과합니다. 별도의 `min_auto`나 `require_banded`가 모든 allowlist 필드를 포괄하지 않는 케이스에서는 미탐을 숨깁니다. / 근거([test/safe/run.mjs:636](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:636), [test/safe/run.mjs:638](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:638)) / 수정안: 기대가 정확한 케이스는 집합 동등성을 검사하고, 선택적 필드가 있다면 `required_auto`와 `allowed_auto`를 분리하십시오.
docs/jp/codex_review_s3b_2026-10-21.md:10925:18. 문제 / 카테고리 복원은 정상 경로만 처리하고 `try/finally`가 없습니다. `__allCatsOff()` 이후 browser evaluation, reload 또는 assertion 코드가 예외를 던지면 `__restoreCats()`에 도달하지 않아 이후 케이스 전체가 오염됩니다. 구현자가 이미 같은 전역 누출을 한 번 겪었다는 점에서 이 경로를 남길 이유가 없습니다. / 근거([test/safe/run.mjs:620](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:620), [test/safe/run.mjs:628](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:628), [test/safe/run.mjs:630](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:630)) / 수정안: 각 legal 단언을 `try/finally`로 감싸고 finally에서 복원 및 검증하십시오. 더 안전하게는 테스트별 새 page/context를 쓰십시오.

hook: PostToolUse
hook: PostToolUse Completed
codex
처리표의 주장과 실제 연결점은 확인했습니다. 이제 승격 조건·keep 경계·법령 그룹·경고/UI 조건을 함수 단위로 읽고 있습니다. 특히 A-1은 “직전 페이지”가 실제 배열상 직전인지, A-3은 숫자 포기가 폴백에 재노출되는지, A-4는 `legal_enforcement`가 문서별로 정확히 소비되는지를 따로 검증하겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "nl -ba public/safe/index.html | sed -n '1170,1305p;1500,1565p;1680,1835p;1940,2045p;2180,2295p;650,710p' && nl -ba test/safe/check_matrix.mjs | sed -n '1,165p' && nl -ba test/safe/run.mjs | sed -n '180,245p;610,705p;840,910p;1000,1100p'" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
   650	  hintBefore:'各項目の初期公開レベルを設定しておきましょう。文書内で見つかると、その設定どおりに隠されます。',
   651	  hintAfter:'文書内で見つかった項目です。項目ごとに公開レベルを変えると、プレビューにすぐ反映されます。',
   652	  moreShow:n=>`検出されなかった項目 ${n}件を表示`, moreHide:'検出されなかった項目を隠す',
   653	  aiHint:'氏名・会社・住所のようにパターンのない情報は、AIが文脈から見つけます。', btnAI:'AI精密検査',
   654	  aiBusy:'AIが読み取り中…', aiDone:'AI検査完了',
   655	  fmtJpg:'画像 (JPG)', fmtPng:'画像 (PNG)', fmtPdf:'PDF', btnMake:'文書を作成',
   656	  resTitle:'完成した文書', btnDl:'ダウンロード', btnCopy:'テキストをコピー',
   657	  rvFit:'フィット', rvPrevAria:'前のページ', rvNextAria:'次のページ', rvZoomInAria:'拡大', rvZoomOutAria:'縮小', rvFullAria:'全画面', rvExitAria:'全画面を閉じる',
   658	  resFlat:'🔒 このファイルは画像に平坦化（フラット化）され、黒いボックスの下に原文は残りません。',
   659	  privacy:'🔒 すべての文書はお使いのブラウザ内でのみ処理されます。AI精密検査を選んだ場合のみ、抽出テキストがAI分析のため送信され、保存されることはありません。',
   660	  partners:'SafeFileのおすすめサービス',
   661	  pSlim:'画像圧縮とPDF変換を、2MB以下で手軽に。', pSchool:'先生のための求人情報、ぴったりの学校探し。', pHello:'韓国語学習を今日から始めましょう。',
   662	  footer:'個人情報を守る、いちばん速い方法', footPrivacy:'プライバシーポリシー', footBlog:'ブログ',
   663	  pwaTitle:'ホーム画面に追加すると、アプリのように使えます', pwaIosDesc:'Safariの共有 <span class="ib-share">↑</span> ボタンをタップして「ホーム画面に追加」を選んでください', pwaAndroidDesc:'インストールするとオフラインでも開き、アプリのように起動します', pwaInstall:'インストール',
   664	  cnt:n=>`${n}件`, cntUse:n=>`· ${n}件使用中`, scanDone:n=>`⚡ 即時検査完了 — ${n}件検出`, scanAI:n=>`🤖 AI検査を含む — 合計${n}件`,
   665	  tPasteEmpty:'内容を貼り付けてください', tBulkOk:'すべての項目を公開に設定しました', tBulkNo:'すべての項目を非公開に設定しました',
   666	  tAIDone:'AIが氏名・会社などの文脈情報まで見つけました', tAIDup:'AI検査はすでに完了しています', tAIFail:'AI検査に失敗しました。しばらくしてからもう一度お試しください。',
   667	  tMade:n=>`完成！ ${n}か所を隠しました`, tMadeWM:'完成！ ウォーターマークを適用しました', tCopied:'クリップボードにコピーしました', tSaved:n=>`${n} を保存しました`,
   668	  tReadFail:'ファイルを読み取れませんでした。テキストの貼り付けをお試しください。',
   669	  tTooBig:'ファイルが大きすぎます（最大20MB）。', tPageCap:n=>`ページが多いため、先頭${n}ページのみ処理しました。`, tUnsupported:e=>`対応していない形式です（.${e}）。PDF・画像・Word・テキストのみ対応します。`,
   670	  tUnsupExcel:'Excelファイルはまだ対応していません。PDFに保存してからアップロードしてください。',
   671	  tUnsupHangul:'ハングル（HWP）ファイルはまだ対応していません。PDFに保存してからアップロードしてください。',
   672	  tUnsupPpt:'PowerPointファイルはまだ対応していません。PDFに保存してからアップロードしてください。',
   673	  dzSaveExcel:'Excelで「ファイル › 名前を付けて保存」（または「エクスポート」）からPDFを選びます。',
   674	  dzSaveHangul:'ハングル（HWP）アプリで「ファイル › PDFで保存」からPDF形式を選びます。',
   675	  dzSavePpt:'PowerPointで「ファイル › 名前を付けて保存」（または「エクスポート」）からPDFを選びます。',
   676	  renderProg:(p,n)=>`ページをレンダリング中… (${p}/${n})`, ocrStart:'文字位置の認識を準備中…', ocrProg:p=>`文字認識(OCR)中… ${p}%`,
   677	  scanOcr:'スキャン文書のようです — OCRで文字位置を認識中…', heicConv:'HEIC画像を変換中…', building:'文書を作成中…',
   678	  notLocated:'位置不明',
   679	  btnSelect:'🖐 範囲を手動で選択', selHint:'隠したい範囲を指またはマウスでドラッグしてください（写真・署名・印鑑・氏名など）',
   680	  manualSection:'手動で選択した範囲', candSection:'要確認 — これも隠しますか？', manualItem:'選択した範囲',
   681	  jpFields:{address_loose:'本文中の住所',tel:'電話・FAX',doc_shikaku_kakuninsho:'資格確認書', doc_unten_menkyo:'運転免許証', doc_mynumber_card:'マイナンバーカード', doc_juminhyo:'住民票の写し', side_front:'表面', side_back:'裏面', purpose_identity_submit:'本人確認提出', purpose_my_number_procedure:'個人番号手続', purpose_bid_attachment:'入札添付', purpose_consult_share:'相談用共有', back_all:'裏面全体', my_number:'個人番号', jumin_code:'住民票コード', hokensha_bango:'保険者番号', kigo:'記号', bango:'番号', edaban:'枝番', hihokensha_bango:'被保険者番号', qr:'二次元コード', license_no:'免許証番号', biko_change:'備考欄（変更記載）', organ_donor:'臓器提供意思表示欄', setaiin:'本人以外の世帯員', honseki:'本籍', hittosha:'筆頭者', sex:'性別', name:'氏名', birth:'生年月日', address:'住所', expiry:'有効期限', issue:'交付日', issuer:'発行者'},
   682	  jpPurposeLabel:'提出目的', jpBackNotice:'身元確認が目的なら表面のみ提出してください。番号法上、法令で認められた事務以外で個人番号を複写・保管することは制限される場合があります。「個人番号手続」は、提出先の案内で個人番号（裏面）の提出が明示的に求められている場合にのみ選んでください。', jpKeepWarn:'提出先が受付できない可能性があります（本人特定事項）。', jpWarnUnclassified:'文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。', jpWarnLowconf:'文書の種類の確信度が低いため、候補の黒塗りを既定で適用しました。必ず確認してください。', jpEmptyPurpose:'この文書で検出した項目には、この目的に適用されるルールがありません。手動で範囲を選択してください。', jpMnConfirm:'提出先の案内で、個人番号（裏面）の提出が明示的に求められていることを確認しました。求められていない場合は解除しないでください。', jpLegalSection:'法令・提出先ルール', jpLegalWarn:'法令に根拠がある項目です。解除すると、法令上、収集・保管が制限される場合がある情報がそのまま出力されます。', keepSection:'残す項目',
   683	  reasons:{name:'氏名の可能性', jp_auto:'法令根拠により自動で黒塗り', jp_gate:'この目的では自動で黒塗り', jp_recommend:'黒塗りを推奨', jp_optional:'任意', jp_keep:'提出先が必要とする項目', addr:'住所の可能性', addr_contact:'住所の可能性 · 連絡先の近く', addr_edge:'住所の可能性 · 文書の上部・下部', addr_kw:'住所の可能性 · 地名・住所語'},
   684	  tManualAdded:'範囲を追加しました', tManualRemoved:'範囲を削除しました', tSelSmall:'小さすぎます。もう少し大きくドラッグしてください。', btnSelectOn:'✓ 選択モード（オフ）',
   685	  wmToggle:'ウォーターマークを入れる（任意）', wmPlaceholder:'ウォーターマーク文言（自由入力可）', wmCustom:'自由入力…',
   686	  wmPresets:['○○ 提出用','本人確認のみに使用','転用禁止','{date} ○○ に提出'],
   687	  wmQR:'⚠ ウォーターマークがQRコード・バーコード・印鑑を隠していないか、結果プレビューで必ずご確認ください。（下部の余白は自動で空けます）',
   688	  pasted:'貼り付けたテキスト', aiChars:n=>`${n}文字（AI抽出）`, chars:n=>`${n}文字`, pages:n=>`${n}ページ`,
   689	  types:{rrn:'住民登録番号(韓国)',ssn:'SSN(米国)',passport:'パスポート番号',license:'運転免許番号',card:'カード番号',account:'口座番号',phone:'電話番号',email:'メール',birth:'生年月日',address:'住所',name:'氏名',company:'会社・所属',title:'役職',ip:'IPアドレス',url:'SNS・URL',health:'健康・センシティブ情報',other:'その他',manual:'手動選択'}
   690	},
   691	es:{
   692	  badge:'Gratis · Sin registro', navHome:'← SlimFile',
   693	  heroPre:'Oculta solo los ', heroPost:'<br>y comparte el documento tal cual',
   694	  cycle:['datos de identidad','números de teléfono','domicilio','números de cuenta','nombres'],
   695	  heroP:'Sube un documento: mantenemos su aspecto original y colocamos barras negras solo sobre los datos personales. Conserva lo que quieras.',
   696	  trust1:'Los archivos nunca salen de tu navegador', trust2:'Sin registro', trust3:'Diseño original intacto',
   697	  s1:'Subir documento', s2:'Datos personales detectados', s3:'Crear documento', s3sub:'Superpone el enmascarado sobre tu original. El texto bajo las cajas negras no se copia.',
   698	  dzTitle:'Arrastra y suelta un archivo o haz clic', dzTypes:'PDF · Imagen (JPG/PNG/WEBP/HEIC) · Word (docx) · Texto',
   699	  dzTypesNote:'Archivos de Excel: guárdalos como PDF antes de subir',
   700	  dzLimit:'Hasta 20MB · 30 páginas · procesado solo en tu navegador',
   701	  btnPick:'Elegir archivo', btnSample:'Probar con un ejemplo', btnPaste:'Pegar texto',
   702	  btnPasteScan:'Analizar este texto', btnCancel:'Cancelar', btnReset:'Nuevo documento',
   703	  pastePh:'Pega aquí el texto de tu documento y pulsa el botón de abajo',
   704	  bulkOk:'Mostrar todo', bulkNo:'Ocultar todo',
   705	  segOk:'Mostrar', segNo:'Ocultar',
   706	  bandLabel:'Color de banda', bandBlack:'Negro', bandWhite:'Blanco', bandCustom:'Personalizado',
   707	  hintBefore:'Define el nivel de visibilidad por defecto de cada categoría. Cuando se encuentren en tu documento, se ocultarán según esa configuración.',
   708	  hintAfter:'Elementos encontrados en tu documento. Cambia la visibilidad de cada uno: la vista previa se actualiza al instante.',
   709	  moreShow:n=>`Mostrar ${n} categorías más`, moreHide:'Ocultar otras categorías',
   710	  aiHint:'La IA encuentra datos sin patrón fijo, como nombres, empresas y direcciones, a partir del contexto.', btnAI:'Análisis con IA',
  1170	    }
  1171	    if (seg) segs.push(seg);
  1172	  });
  1173	  return (page._jpsegs = segs);
  1174	}
  1175	// Boxes for the normalised-text span [a,b) of a segment, via the char map.
  1176	function jpBoxes(seg, a, b){
  1177	  const out = [];
  1178	  boxesFromRange(pages[seg.pi], seg.pi, seg.map, a, b, out);
  1179	  return out;
  1180	}
  1181	function jpSegBox(seg){
  1182	  const page = pages[seg.pi];
  1183	  const b = { page: seg.pi, x: seg.x0, y: seg.y, w: seg.x1 - seg.x0, h: seg.h };
  1184	  b.bg = sampleBg(page, b);
  1185	  return b;
  1186	}
  1187	
  1188	/* ── document classification ──
  1189	   Weighted keyword vote over the whole page's normalised text. Weights express
  1190	   how exclusive a term is to that document: 資格確認書 appears on nothing else,
  1191	   while 本籍 also appears on 戸籍 documents. The threshold is deliberately a
  1192	   SUM, not a single magic keyword, because OCR reliably destroys some share of
  1193	   any given line — on the alpha fixtures the garbled labels are never the same
  1194	   ones twice. Below threshold the page is "一般文書" and NO Japanese automatic
  1195	   masking happens at all. */
  1196	const JP_CLASSES = {
  1197	  shikaku_kakuninsho: { min: 4, title: ['資格確認書'], kw: [['資格確認書',3],['保険者番号',2],['被保険者',2],['保険者名',2],
  1198	      ['国民健康保険',2],['後期高齢者',2],['枝番',2],['記号',1],['健康保険',1],['一部負担金',1]] },
  1199	  unten_menkyo: { min: 4, title: ['運転免許証'], kw: [['運転免許証',4],['免許証',2],['公安委員会',2],['備考欄',2],
  1200	      ['臓器提供',1],['提供意思',1],['優良',1],['原付',1]] },
  1201	  mynumber_card: { min: 4, title: ['個人番号カード','マイナンバーカード'], kw: [['個人番号カード',4],['マイナンバーカード',4],['個人番号',2],
  1202	      ['券面記載事項',2],['マイナンバー',2]] },
  1203	  juminhyo: { min: 4, title: ['住民票'], kw: [['住民票',3],['世帯主',2],['続柄',2],['筆頭者',2],['世帯全員',2],
  1204	      ['住民となった日',2],['住民票コード',2],['本籍',1],['住民となつた日',2]] },
  1205	};
  1206	/* Does this page LOOK like one of the FOUR documents even though no class
  1207	   reached threshold? This is not a classification — it is the trigger for
  1208	   telling the user that automatic masking did NOT run, which is the failure the
  1209	   previous build was silent about (a single garbled label dropped the whole JP
  1210	   preset and nothing said so).
  1211	   和暦 (令和|平成|昭和) used to be enough on its own, and that was wrong: every
  1212	   Japanese résumé, invoice and contract carries an era date, so the banner said
  1213	   "we could not identify this document" on documents that are not any of the
  1214	   four and never were. A warning that fires on "this text is Japanese" teaches
  1215	   the user to dismiss it, and then it is not there when it matters (Codex 6b-2).
  1216	   The names below are document names, not date formats. */
  1217	const JP_SUSPECT_RE = /資格確認書|免許証|個人番号|マイナンバー|住民票/;
  1218	function jpSuspect(pi){ return JP_SUSPECT_RE.test(jpPageText(pi)); }
  1219	function jpPageText(pi){
  1220	  const page = pages[pi];
  1221	  if (page._jptext != null) return page._jptext;
  1222	  let s = ''; for (const it of page.items) s += jpNorm(it.str || '').t;
  1223	  return (page._jptext = s);
  1224	}
  1225	/* Classification has two outcomes that are NOT the same thing:
  1226	     confident  — score >= min. The legal preset applies as written.
  1227	     low        — score < min but the document's own TITLE was read. We know
  1228	                  which form this is, and we do not know it well enough to
  1229	                  delete pixels on our own: every level is demoted to a review
  1230	                  candidate (see jpApply) and the warning banner stays up.
  1231	   Below both, the page is 一般文書 and no Japanese rule runs at all — which is
  1232	   precisely when the banner has to say so (Codex 1-1). */
  1233	function jpClassify(pi){
  1234	  const txt = jpPageText(pi);
  1235	  let best = null, low = null;
  1236	  for (const [id, def] of Object.entries(JP_CLASSES)){
  1237	    let score = 0, hits = [];
  1238	    for (const [k, w] of def.kw) if (txt.includes(k)) { score += w; hits.push(k); }
  1239	    if (score >= def.min && (!best || score > best.score)) best = { doc: id, score, hits };
  1240	    else if (score < def.min && def.title.some(t => txt.includes(t)) && (!low || score > low.score))
  1241	      low = { doc: id, score, hits, low: true };
  1242	  }
  1243	  if (!best) best = low;
  1244	  if (!best) return null;
  1245	  // Side: cards have two faces with completely different legal treatment.
  1246	  if (best.doc === 'mynumber_card' || best.doc === 'unten_menkyo'){
  1247	    best.side = txt.includes('裏面') ? 'back' : txt.includes('表面') ? 'front'
  1248	              : (best.doc === 'mynumber_card' && /\d[\d\s.\-]{10,}\d/.test(txt)) ? 'back' : 'front';
  1249	  }
  1250	  return best;
  1251	}
  1252	/* Anchors that appear ONLY on the back face of each card. A card scanned into
  1253	   two pages leaves the back face unclassifiable on its own — 個人番号 is worth 2
  1254	   of the 4 points the card needs and the card's NAME is printed on the front —
  1255	   so without something the back page can be recognised BY, the only way to
  1256	   govern it was to inherit page 1's class. That inheritance also governed a
  1257	   bank-book copy or any other unrelated attachment bound into the same PDF, and
  1258	   it governed it with CARD rules: the error direction is destroying required
  1259	   evidence, not leaking (Codex 6b-3). These anchors are what a promotion to
  1260	   「the back of the card on the previous page」 has to prove.
  1261	   臓器提供 is deliberately absent from the card list — on マイナンバーカード it is
  1262	   a FRONT field, so it is not evidence of a back face there. */
  1263	const JP_BACK_ANCHORS = {
  1264	  mynumber_card: /個人番号|マイナンバー|二次元コード/,
  1265	  unten_menkyo: /備考欄|臓器提供|提供意思|意思表示欄/,
  1266	};
  1267	
  1268	/* ── 個人番号 check digit ──
  1269	   Source: 行政手続における特定の個人を識別するための番号の利用等に関する法律の
  1270	   規定による通知カード及び個人番号カード並びに情報提供ネットワークシステムによる
  1271	   特定個人情報の提供等に関する省令 **第5条**
  1272	   (https://laws.e-gov.go.jp/document?lawid=426M60000008085_20231215_505M60004008017).
  1273	   NOT 番号法施行令 別表 — that was the citation here until 2026-10-21 and it was
  1274	   wrong; the arithmetic below was always right (Codex 1-5).
  1275	   Σ P_n·Q_n over the 11-digit body counted from the RIGHT (n = 1..11),
  1276	   Q_n = n+1 for n ≤ 6 else n−5; check = 11 − (Σ mod 11), and ≥10 → 0.
  1277	   (The 省令 states it as: remainder 0 or 1 → check digit 0. Equivalent — a
  1278	   remainder of 0 gives 11 and of 1 gives 10, both folded to 0 by the ≥10 rule.) */
  1279	function myNumberCheckOk(d12){
  1280	  if (!/^\d{12}$/.test(d12)) return false;
  1281	  const d = d12.slice(0, 11).split('').map(Number);
  1282	  let s = 0;
  1283	  for (let n = 1; n <= 11; n++){ const q = n <= 6 ? n + 1 : n - 5; s += d[11 - n] * q; }
  1284	  let chk = 11 - (s % 11); if (chk >= 10) chk = 0;
  1285	  return chk === Number(d12[11]);
  1286	}
  1287	
  1288	/* ── pixel helpers for field FRAMES and code blocks ──
  1289	   A 欄 (field box) is drawn as a thin rectangle; its contents may be empty, so
  1290	   there is nothing for a text-based detector to find. Scanning for the drawn
  1291	   rule is the only way to cover 臓器提供意思表示欄 on a card whose box the
  1292	   holder left blank — and a blank-looking box is exactly where a faint
  1293	   handwritten mark hides. */
  1294	function jpPageBg(page){
  1295	  if (page._jpbg) return page._jpbg;
  1296	  const ctx = page.canvas.getContext('2d', { willReadFrequently: true });
  1297	  const W = page.canvas.width, H = page.canvas.height;
  1298	  const pick = [];
  1299	  for (let i = 0; i < 24; i++){
  1300	    const x = Math.round(W * (i % 6 + 0.5) / 6);
  1301	    const y = [2, H - 3, Math.round(H * 0.01), Math.round(H * 0.99)][Math.floor(i / 6)];
  1302	    const d = ctx.getImageData(Math.max(0, Math.min(W-1, x)), Math.max(0, Math.min(H-1, y)), 1, 1).data;
  1303	    pick.push([d[0], d[1], d[2]]);
  1304	  }
  1305	  const med = c => { const s = pick.map(p => p[c]).sort((a,b)=>a-b); return s[s.length >> 1]; };
  1500	  mynumber_card: {
  1501	    // 番号法: 法令で認められた者・目的以外での個人番号の収集・保管禁止
  1502	    back_all:   { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1503	    my_number:  { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1504	    qr:         { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1505	    sex:        { recommend: ['identity_submit'] },
  1506	    organ_donor:{ recommend: ['identity_submit'] },
  1507	    name:{keep:['identity_submit','my_number_procedure'],optional:['consult_share']},
  1508	    birth:{keep:['identity_submit','my_number_procedure'],optional:['consult_share']},
  1509	    address:{keep:['identity_submit','my_number_procedure'],optional:['consult_share']},
  1510	    expiry:{keep:['identity_submit','my_number_procedure'],optional:['consult_share']},
  1511	    ...JP_EXTRA,
  1512	  },
  1513	  juminhyo: {
  1514	    my_number:  { gate: P_NOT_MYNUM, keep: ['my_number_procedure'] },
  1515	    // 住民基本台帳法 利用制限（個人識別符号）と理解しているが出典を確保できていない
  1516	    // → matrix verified:false。既定ON で帯は引くが auto とは呼ばない。
  1517	    jumin_code: { recommend: P_NOT_MYNUM },
  1518	    honseki:    { recommend: P_ID_CONSULT, optional: ['my_number_procedure','bid_attachment'] },
  1519	    hittosha:   { recommend: P_ID_CONSULT, optional: ['my_number_procedure','bid_attachment'] },
  1520	    setaiin:    { recommend: P_ID_CONSULT, optional: ['my_number_procedure','bid_attachment'] },
  1521	    name: KEEP_ID_BID, birth: KEEP_ID_BID, address: KEEP_ID_BID, issuer: KEEP_ID_BID,
  1522	    ...JP_EXTRA,
  1523	  },
  1524	};
  1525	/* The legal-preset fields, PER DOCUMENT: the ones the matrix grounds in 番号法 /
  1526	   告知要求制限 rather than in a submission-desk convention. They are NOT subject
  1527	   to the general category checkboxes — turning off 「その他」 used to silently
  1528	   remove the マイナカード裏面 band and the 資格確認書 QR band from the output, with
  1529	   no warning (Codex 4-6). They live in their own group and can only be released
  1530	   one item at a time, and releasing one says 「法令上…制限される場合があります」.
  1531	   Mirrors `legal_enforcement: true` in the matrix, which check_matrix.mjs
  1532	   compares field-for-field AND allows only on `verified: true` rules. A flat
  1533	   field-name Set could not express that distinction: it put 住民票コード — whose
  1534	   own matrix entry says the statutory citation could NOT be secured
  1535	   (verified:false) — under a banner asserting the recipient may not keep it
  1536	   (Codex 6b-10). Document scope matters for the same reason: `my_number` is
  1537	   番号法-grounded on 住民票, `jumin_code` is not grounded at all. */
  1538	const JP_LEGAL = {
  1539	  shikaku_kakuninsho: ['hokensha_bango','kigo','bango','edaban','hihokensha_bango','qr'],
  1540	  unten_menkyo: [],
  1541	  mynumber_card: ['back_all','my_number','qr'],
  1542	  juminhyo: ['my_number'],
  1543	};
  1544	function jpIsLegal(doc, field){ return (JP_LEGAL[doc] || []).includes(field); }
  1545	function jpLevel(doc, field, purpose){
  1546	  const r = (JP_RULES[doc] || {})[field];
  1547	  if (!r) return null;
  1548	  for (const lv of ['auto','gate','recommend','optional','keep'])
  1549	    if (r[lv] && r[lv].includes(purpose)) return lv;
  1550	  return null;
  1551	}
  1552	
  1553	/* ── field extraction ─────────────────────────────────────────────────────
  1554	   Each rule is {field, labels[], re, last} — `labels` are the anchors accepted
  1555	   in the segment (several spellings, because OCR drops or swaps one character
  1556	   of a label far more often than it mangles a digit run), `re` is the value
  1557	   format, and `last` allows falling back to the segment's final item when the
  1558	   value itself was garbled but its POSITION is still certain (e.g. 性別 whose
  1559	   single kanji OCR read as "&" — the box is what we need, not the character). */
  1560	const JP_FIELD_RULES = {
  1561	  shikaku_kakuninsho: [
  1562	    { field:'hokensha_bango',   labels:['保険者番号','険者番号','保険者番'], re:/\d{4,10}/ },
  1563	    { field:'hihokensha_bango', labels:['被保険者番号','被保険者等記号','被保険者番'], re:/[0-9A-Z]{4,12}/ },
  1564	    { field:'kigo',   labels:['記号'], re:/[0-9A-Z]{2,12}/ },
  1565	    { field:'edaban', labels:['枝番'], re:/\d{1,3}/ },
  1680	  return { a, b, score, postal, pref: !!pref };
  1681	}
  1682	
  1683	/* ── 電話・FAX ──
  1684	   Anchored on TEL/電話/携帯/FAX; the value must fit the Japanese numbering plan.
  1685	   A hyphenated value is the confirmed shape; an unseparated digit run of the
  1686	   same length is a CANDIDATE, because at that point it is indistinguishable
  1687	   from an account or reference number and only the label suggests otherwise.
  1688	   NOTE: none of the four alpha documents carries a phone number, so this rule
  1689	   has no golden coverage — it is unexercised code until a fixture has one. */
  1690	const JP_TEL_HYPHEN_RE = /0120-\d{3}-\d{3}|0800-\d{3}-\d{4}|0\d{1,4}-\d{1,4}-\d{4}/;
  1691	const JP_TEL_PLAIN_RE = /(?<!\d)0\d{9,10}(?!\d)/;
  1692	function jpFindLabel(seg, labels, headOnly){
  1693	  for (const L of labels){
  1694	    const p = seg.t.indexOf(L);
  1695	    if (p < 0) continue;
  1696	    if (headOnly && p !== 0) continue;
  1697	    return { at: p, end: p + L.length };
  1698	  }
  1699	  return null;
  1700	}
  1701	/* Every label this document's rules can anchor on, and where the next one
  1702	   starts. A `last:true` tail has to STOP there. Two label-value pairs on one
  1703	   visual row collapse into ONE segment whenever the gap between the columns
  1704	   falls under the segment threshold, and "every item after my label" then
  1705	   swallows the neighbouring column: 「保険者名 架空健康保険協会 保険者番号 99221010」
  1706	   handed the 保険者名 rule the insurer NUMBER's items and marked them `used` —
  1707	   and `used` is exactly what the structural fallback refuses to re-claim. A
  1708	   field we promise never to redact was suppressing one the 告知要求制限 requires
  1709	   us to redact, and nothing about the output said so (Codex 6b-5). */
  1710	function jpKnownLabels(doc){
  1711	  const out = [];
  1712	  for (const r of (JP_FIELD_RULES[doc] || [])) out.push(...r.labels);
  1713	  for (const r of (JP_REGION_LABELS[doc] || [])) out.push(...(r.labels || []));
  1714	  return out;
  1715	}
  1716	function jpTailEnd(seg, from, labels){
  1717	  let end = seg.t.length;
  1718	  for (const lb of labels){ const i = seg.t.indexOf(lb, from); if (i >= from && i < end) end = i; }
  1719	  return end;
  1720	}
  1721	/* Can this field ever be banded automatically on this document? A field whose
  1722	   only levels are keep/optional never redacts anything — so it must not CONSUME
  1723	   an identifier either. Marking a 4+ digit run as `used` is a claim ("this span
  1724	   belongs to me"), and from a field that will never cover it, that claim only
  1725	   has the effect of hiding the span from the rule that would. */
  1726	function jpKeepOnly(doc, field){
  1727	  const r = (JP_RULES[doc] || {})[field];
  1728	  return !!r && !r.auto && !r.gate && !r.recommend;
  1729	}
  1730	function jpInLongDigitRun(s, k){
  1731	  if (!isDigit(s[k])) return false;
  1732	  let a = k, b = k;
  1733	  while (a > 0 && isDigit(s[a - 1])) a--;
  1734	  while (b + 1 < s.length && isDigit(s[b + 1])) b++;
  1735	  return (b - a + 1) >= 4;
  1736	}
  1737	// Span of the first `n` digits in [from, to), tolerating group separators.
  1738	function jpDigitSpan(seg, from, n, to){
  1739	  let first = -1, last = -1, count = 0;
  1740	  const lim = to == null ? seg.t.length : to;
  1741	  for (let k = from; k < lim; k++){
  1742	    const c = seg.t[k];
  1743	    if (isDigit(c)){ if (first < 0) first = k; last = k; if (++count === n) return { a:first, b:last+1, digits: seg.t.slice(first,last+1).replace(/\D/g,'') }; }
  1744	    else if (first >= 0 && !/[\s.\-・,/]/.test(c)) { first = -1; last = -1; count = 0; }
  1745	  }
  1746	  return null;
  1747	}
  1748	function jpExtract(pi, cls){
  1749	  const segs = jpSegments(pi), found = [];
  1750	  // Every value rule anchors at the SEGMENT HEAD. In these forms the label always
  1751	  // opens its own column, so a label found mid-segment is prose, not an anchor —
  1752	  // that is how the 「裏面の生年月日有無は…要確認」 footnote on the card dummy got
  1753	  // read as a 生年月日 field. (The 欄 region labels below deliberately do not use
  1754	  // this: OCR puts a garbled 騰 in front of 器提供意思表示欄.)
  1755	  const rules = (JP_FIELD_RULES[cls.doc] || [])
  1756	    .filter(r => !r.sides || r.sides.includes(cls.side))
  1757	    .map(r => ({ ...r, headOnly: true }));
  1758	  // Every finding carries the classification of ITS OWN page. A two-sided card
  1759	  // scanned into one PDF has a different legal rule on each page, so applying
  1760	  // page 1's doc/side to every page made the outcome depend on scan order:
  1761	  // front-then-back left the 個人番号 page untouched, back-then-front banded the
  1762	  // front as well (Codex 6-4).
  1763	  const push = (field, boxes, value, extra) => {
  1764	    if (boxes && boxes.length) found.push({ field, boxes, value, pi, doc: cls.doc, side: cls.side || null, low: !!cls.low, ...extra });
  1765	  };
  1766	
  1767	  const labelSet = jpKnownLabels(cls.doc);
  1768	  for (const seg of segs){
  1769	    for (const r of rules){
  1770	      const L = jpFindLabel(seg, r.labels, r.headOnly);
  1771	      if (!L) continue;
  1772	      // Where this label's own value has to end: the next known label in the
  1773	      // same segment, i.e. the next column's anchor. Every value path is bounded
  1774	      // by it, not just the positional `last:true` one — a 性別 regex has no
  1775	      // business matching the 男 that belongs to the column after it either.
  1776	      const tailEnd = jpTailEnd(seg, L.end, labelSet);
  1777	      /* A keep-only field (jpKeepOnly) does not claim an identifier it happens
  1778	         to sit next to — not its `used` marks, and in the positional branch not
  1779	         its pixels or its text either. The boundary above handles the case
  1780	         where the neighbouring LABEL was read; this handles the case where it
  1781	         was not, which on these forms is the measured normal (保険者番号 OCRs as
  1782	         "RREES"/"REEES"/"WREEES" on 3 of 5 fixtures). Without it, the keep
  1783	         field's tail consumes the number and the structural fallback — which
  1784	         only claims spans nothing else marked used — leaves it in the clear.
  1785	         The trade is stated: a 4+ digit run that genuinely belongs to a keep
  1786	         field's own value (a code inside 事業所名称, say) now stays unclaimed
  1787	         and the 資格確認書 fallback may band it. That is the direction this
  1788	         document's rules already choose deliberately — the 告知要求制限 covers
  1789	         the whole 保険者番号 family as one rule, "so the cost of guessing which
  1790	         member it is, is zero, while a miss is the exact leak the product
  1791	         exists to prevent" — and the band is releasable one item at a time. */
  1792	      const keepOnly = jpKeepOnly(cls.doc, r.field);
  1793	      const skip = k => keepOnly && jpInLongDigitRun(seg.t, k);
  1794	      const consume = (from, to) => { for (let k = from; k < to; k++) if (!skip(k)) seg.used[k] = 1; };
  1795	      if (r.tel){
  1796	        const tail = seg.t.slice(L.end, tailEnd);
  1797	        const hy = JP_TEL_HYPHEN_RE.exec(tail);
  1798	        const pl = hy ? null : JP_TEL_PLAIN_RE.exec(tail);
  1799	        const m = hy || pl;
  1800	        if (!m) continue;
  1801	        const a2 = L.end + m.index, b2 = a2 + m[0].length;
  1802	        push('tel', jpBoxes(seg, a2, b2), m[0], { loose: !hy });
  1803	        consume(a2, b2);
  1804	        continue;
  1805	      }
  1806	      if (r.digits){
  1807	        const sp = jpDigitSpan(seg, L.end, r.digits, tailEnd);
  1808	        if (!sp) continue;
  1809	        const extra = r.field === 'my_number' ? { checkOk: myNumberCheckOk(sp.digits) } : {};
  1810	        push(r.field, jpBoxes(seg, sp.a, sp.b), sp.digits, extra);
  1811	        consume(sp.a, sp.b);
  1812	        continue;
  1813	      }
  1814	      let a = -1, b = -1, val = '';
  1815	      if (r.addr){
  1816	        // 住所/本籍: bound the value by the address hierarchy rather than by
  1817	        // "everything after the label", so a second column that drifted into
  1818	        // this segment is not swept into the band.
  1819	        const sp = jpAddressSpan(seg.t.slice(0, tailEnd), L.end);
  1820	        if (sp && sp.b > sp.a){ a = sp.a; b = sp.b; val = seg.t.slice(a, b); }
  1821	      } else if (r.re){
  1822	        const m = r.re.exec(seg.t.slice(L.end, tailEnd));
  1823	        if (m){ a = L.end + m.index; b = a + m[0].length; val = m[0]; }
  1824	      }
  1825	      if (a < 0 && r.last !== true) continue;
  1826	      if (a < 0){
  1827	        // value position certain, characters not: the items after the label, up
  1828	        // to the next column's anchor — minus anything a keep-only field must
  1829	        // not claim (an item that is nothing but a 4+ digit run).
  1830	        const itemChars = o => { const a0 = seg.start[o.i]; const n = (jpNorm(o.it.str || '').t || '').length; return [a0, a0 + n]; };
  1831	        const after = seg.items.filter(o => {
  1832	          const [a0, b0] = itemChars(o);
  1833	          if (!(a0 >= L.end && a0 < tailEnd)) return false;
  1834	          if (b0 <= a0) return true;
  1835	          for (let k = a0; k < Math.min(b0, tailEnd); k++) if (!skip(k)) return true;
  1940	        for (const s of segs){
  1941	          if (s.y < top || s.y >= bottom) continue;
  1942	          (byRow[s.row] = byRow[s.row] || []).push(s);
  1943	        }
  1944	        for (const list of Object.values(byRow))
  1945	          push('setaiin', list.map(jpSegBox), (list[0].t || '(世帯員)').slice(0, 24));
  1946	      }
  1947	    }
  1948	    // 氏名/生年月日 inside a THIRD PARTY's block are not the subject's keep-fields.
  1949	    // Leaving them in would put the same pixels in the 残す項目 list and under a
  1950	    // band at the same time — the list would be telling the user the opposite of
  1951	    // what the page shows.
  1952	    const regions = found.filter(f => f.field === 'setaiin').flatMap(f => f.boxes);
  1953	    if (regions.length){
  1954	      const inside = b => regions.some(r => b.x + b.w/2 >= r.x && b.x + b.w/2 <= r.x + r.w
  1955	                                         && b.y + b.h/2 >= r.y && b.y + b.h/2 <= r.y + r.h);
  1956	      for (let i = found.length - 1; i >= 0; i--){
  1957	        const f = found[i];
  1958	        if (!['name','birth','address'].includes(f.field)) continue;
  1959	        if (f.boxes.every(inside)) found.splice(i, 1);
  1960	      }
  1961	    }
  1962	  }
  1963	  return found;
  1964	}
  1965	
  1966	/* ── state + application ── */
  1967	const JP_PURPOSES = ['identity_submit','my_number_procedure','bid_attachment','consult_share'];
  1968	const JP_STATE0 = () => ({ cls: null, pageCls: [], purpose: 'identity_submit', findings: [], warn: null, mnConfirmed: false });
  1969	let jpState = JP_STATE0();
  1970	function jpScan(){
  1971	  const keepPurpose = jpState.purpose;
  1972	  jpState = JP_STATE0(); jpState.purpose = keepPurpose;
  1973	  if (!pages.length) return null;
  1974	  // Per-page classification. Page 0 names the document in the UI, but each page
  1975	  // is governed by its OWN class. A page that cannot be classified stays null —
  1976	  // NO Japanese rule runs on it. The single exception is a card's back face,
  1977	  // which carries no document name and therefore cannot classify itself: it is
  1978	  // promoted only when the PREVIOUS page is that card's front AND this page
  1979	  // carries a back-only anchor for that same card (JP_BACK_ANCHORS). Anything
  1980	  // else bound into the PDF — a bank book, a tax slip, a blank separator — is
  1981	  // governed by nothing, which is the honest answer for a page we cannot read.
  1982	  const cls0 = jpClassify(0);
  1983	  const pageCls = [];
  1984	  for (let pi = 0; pi < pages.length; pi++){
  1985	    if (pi === 0){ pageCls.push(cls0); continue; }
  1986	    let c = jpClassify(pi);
  1987	    if (!c){
  1988	      const prev = pageCls[pi - 1];
  1989	      const re = prev && prev.side === 'front' && JP_BACK_ANCHORS[prev.doc];
  1990	      if (re && re.test(jpPageText(pi)))
  1991	        c = { doc: prev.doc, side: 'back', score: prev.score, hits: prev.hits, low: !!prev.low, viaBackAnchor: true };
  1992	    }
  1993	    pageCls.push(c);
  1994	  }
  1995	  jpState.pageCls = pageCls;
  1996	  if (!cls0){
  1997	    // No Japanese rule will run. Say so if the page looks like one of these
  1998	    // documents, instead of falling through to the Latin heuristics in silence.
  1999	    if (pages.some((p, pi) => jpSuspect(pi))) jpState.warn = 'unclassified';
  2000	    return null;
  2001	  }
  2002	  jpState.cls = cls0;
  2003	  if (pageCls.some(c => c && c.low)) jpState.warn = 'lowconf';
  2004	  let all = [];
  2005	  for (let pi = 0; pi < pages.length; pi++) if (pageCls[pi]) all = all.concat(jpExtract(pi, pageCls[pi]));
  2006	  jpState.findings = all;
  2007	  return cls0;
  2008	}
  2009	function jpFieldLabel(f){ return (T().jpFields && T().jpFields[f]) || f; }
  2010	// Build entities from the findings for the current purpose. Called on load and
  2011	// on every purpose change — the purpose IS the policy, so it re-derives rather
  2012	// than patching modes in place.
  2013	/* The 個人番号 purpose gate needs more than a dropdown. Choosing 「個人番号手続」
  2014	   releases a band that 番号法 put there, and the dropdown alone cannot establish
  2015	   that the recipient actually performs a 個人番号関係事務 — PPC FAQ Q6-12
  2016	   distinguishes seeing a number from copying and keeping it, and both assume the
  2017	   recipient is entitled to it (Codex 4-4). So the release requires the purpose
  2018	   AND an explicit confirmation; until it is given, the band stays. */
  2019	function jpMnGateOpen(){ return jpState.purpose === 'my_number_procedure' && jpState.mnConfirmed; }
  2020	const JP_MN_GATED = new Set(['back_all','my_number','qr']);
  2021	function jpApply(){
  2022	  entities = entities.filter(e => !e.jp);
  2023	  const cls = jpState.cls; if (!cls) { jpRenderBar(); renderAll(); return; }
  2024	  const purpose = jpState.purpose;
  2025	  const add = (f, level, boxes, value, note, ctx) => {
  2026	    const kind = (level === 'auto' || level === 'gate') ? 'auto'
  2027	               : level === 'keep' ? 'keep' : 'candidate';
  2028	    const mode = (level === 'auto' || level === 'gate' || level === 'recommend') ? 'no' : 'ok';
  2029	    const doc = (ctx && ctx.doc) || cls.doc;
  2030	    // A legal-preset band is not governed by the general category checkboxes.
  2031	    const legal = jpIsLegal(doc, f) && mode === 'no';
  2032	    entities.push({ id:'j'+Math.random().toString(36).slice(2,8), type: JP_TYPE[f] || 'other',
  2033	      value, mode, kind, legal, reason: 'jp_' + level, boxes,
  2034	      jp: { doc, side: (ctx && ctx.side) || cls.side || null, page: ctx ? ctx.page : null, field: f, level, note: note || null } });
  2035	  };
  2036	  // Resolve the level for one finding under the current purpose, including the
  2037	  // two demotions and the confirmation gate. Returns null = not offered.
  2038	  const resolve = (doc, field, f) => {
  2039	    let level = jpLevel(doc, field, purpose), note = null;
  2040	    if (!level) return null;
  2041	    // Unconfirmed 個人番号手続: the matrix says keep, but the release has not
  2042	    // been confirmed, so the 番号法 band stays as if the purpose were 本人確認.
  2043	    if (level === 'keep' && JP_MN_GATED.has(field) && purpose === 'my_number_procedure' && !jpState.mnConfirmed){
  2044	      level = 'gate'; note = 'mn_unconfirmed';
  2045	    }
  2180	    // is where the proportional estimate drifts and leaves a remnant (e.g. the
  2181	    // right side of an email). Middle edges keep a proportional estimate + pad.
  2182	    const x0 = (cMin===0)     ? it.x        : it.x + cw*cMin - cw*0.4;
  2183	    const x1 = (cMax===len-1) ? it.x+it.w   : it.x + cw*(cMax+1) + cw*0.4;
  2184	    const box={page:pi,x:x0-1,y:it.y-2,w:(x1-x0)+2,h:it.h+4};
  2185	    box.bg=sampleBg(page,box);
  2186	    out.push(box);
  2187	  }
  2188	}
  2189	// A Latin word/phrase (name, city, org) must match on word boundaries, so a
  2190	// short value never masks a fragment inside a longer word — e.g. "Korea" must
  2191	// not hit "Koreaz". Numbers/emails (with @ . - separators) are exempt.
  2192	function isLatinToken(v){ return /^[A-Za-z][A-Za-z .,'’&\-]*$/.test(v); }
  2193	function boundaryOk(latin,before,after){
  2194	  if(!latin) return true;
  2195	  return !/[A-Za-z]/.test(before||'') && !/[A-Za-z]/.test(after||'');
  2196	}
  2197	function boxesForValue(value){
  2198	  const out=[];
  2199	  if(!value || value.replace(/\s/g,'').length<2) return out;
  2200	  const latin=isLatinToken(value);
  2201	  pages.forEach((page,pi)=>{
  2202	    buildIndex(page);
  2203	    let from=0, at;
  2204	    while((at=page._text.indexOf(value,from))>=0){
  2205	      if(boundaryOk(latin, page._text[at-1], page._text[at+value.length]))
  2206	        boxesFromRange(page,pi,page._map,at,at+value.length,out);
  2207	      from=at+value.length;
  2208	    }
  2209	  });
  2210	  if(out.length) return out;
  2211	  const tgt=value.replace(/\s/g,'');
  2212	  pages.forEach((page,pi)=>{
  2213	    let from=0, at;
  2214	    while((at=page._stext.indexOf(tgt,from))>=0){
  2215	      if(boundaryOk(latin, page._stext[at-1], page._stext[at+tgt.length]))
  2216	        boxesFromRange(page,pi,page._smap,at,at+tgt.length,out);
  2217	      from=at+tgt.length;
  2218	    }
  2219	  });
  2220	  return out;
  2221	}
  2222	// Estimate the local background color from the clean inter-line gaps just above
  2223	// and below the box (those rows are almost always pure background). Use the
  2224	// MEDIAN per channel — robust for BOTH light and dark backgrounds (picking the
  2225	// "lightest" broke on dark pages, drawing a white box). Never a single pixel.
  2226	function sampleBg(page,b){
  2227	  try{
  2228	    const ctx=page.canvas.getContext('2d'), W=page.canvas.width, H=page.canvas.height;
  2229	    const gap=Math.max(3,b.h*0.5);
  2230	    const xs=[b.x+b.w*0.15, b.x+b.w*0.5, b.x+b.w*0.85], ys=[b.y-gap, b.y+b.h+gap];
  2231	    const cols=[];
  2232	    for(const yy of ys) for(const xx of xs){
  2233	      const px=Math.max(0,Math.min(W-1,Math.round(xx))), py=Math.max(0,Math.min(H-1,Math.round(yy)));
  2234	      const d=ctx.getImageData(px,py,1,1).data;
  2235	      if(d[3]>=200) cols.push([d[0],d[1],d[2]]);
  2236	    }
  2237	    if(!cols.length) return '#FFFFFF';
  2238	    const med=ch=>{ const s=cols.map(c=>c[ch]).sort((a,b)=>a-b); return s[s.length>>1]; };
  2239	    const c=[med(0),med(1),med(2)];
  2240	    return `rgb(${c[0]},${c[1]},${c[2]})`;
  2241	  }catch(e){ return '#FFFFFF'; }
  2242	}
  2243	
  2244	/* ───────── canvas helpers ───────── */
  2245	function canvasEl(w,h){ const c=document.createElement('canvas'); c.width=Math.max(1,Math.round(w)); c.height=Math.max(1,Math.round(h)); return c; }
  2246	
  2247	/* ───────── file loading ───────── */
  2248	const dz=$('dropzone'), fi=$('fileInput');
  2249	dz.addEventListener('click',e=>{if(e.target.closest('button'))return;fi.click();});
  2250	dz.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();fi.click();}});
  2251	$('btnPick').addEventListener('click',()=>fi.click());
  2252	['dragover','dragenter'].forEach(ev=>dz.addEventListener(ev,e=>{e.preventDefault();dz.classList.add('drag');}));
  2253	['dragleave','drop'].forEach(ev=>dz.addEventListener(ev,e=>{e.preventDefault();dz.classList.remove('drag');}));
  2254	dz.addEventListener('drop',e=>{const f=e.dataTransfer.files[0];if(f)handleFile(f);});
  2255	fi.addEventListener('change',()=>{if(fi.files[0])handleFile(fi.files[0]);fi.value='';});
  2256	$('btnPaste').addEventListener('click',()=>{dz.style.display='none';$('pasteArea').style.display='block';$('pasteActions').style.display='flex';$('pasteArea').focus();});
  2257	$('btnPasteCancel').addEventListener('click',()=>{$('pasteArea').style.display='none';$('pasteActions').style.display='none';dz.style.display='flex';});
  2258	$('btnPasteScan').addEventListener('click',()=>{const t=$('pasteArea').value.trim();if(!t){toast(T().tPasteEmpty);return;}loadFromText(t,T().pasted);});
  2259	$('btnReset').addEventListener('click',resetAll);
  2260	
  2261	const SAMPLE_KO=`재직증명서
  2262	
  2263	성명: 김민준
  2264	주민등록번호: 900315-1234567
  2265	생년월일: 1990년 3월 15일
  2266	주소: 서울특별시 강남구 테헤란로 152, 1204호
  2267	연락처: 010-2345-6789
  2268	이메일: minjun.kim@hanmail.net
  2269	
  2270	위 사람은 주식회사 한빛테크 개발팀에서
  2271	2019년 4월 1일부터 현재까지 선임연구원으로
  2272	재직 중임을 증명합니다.
  2273	
  2274	급여계좌: 국민은행 123456-04-789012
  2275	비상연락망: 김서연 (배우자) 010-9876-5432
  2276	
  2277	2026년 7월 15일
  2278	주식회사 한빛테크 대표이사 박정호`;
  2279	const SAMPLE_EN=`CERTIFICATE OF EMPLOYMENT
  2280	
  2281	Name: James Miller
  2282	SSN: 123-45-6789
  2283	Date of Birth: 1990-03-15
  2284	Address: Seoul Gangnam-gu Teheran-ro 152
  2285	Phone: 010-2345-6789
  2286	Email: james.miller@gmail.com
  2287	
  2288	This certifies that the above person has been
  2289	employed at Hanbit Tech Inc. as a Senior Researcher
  2290	since April 1, 2019.
  2291	
  2292	Payroll account: 123456-04-789012
  2293	Emergency contact: Sarah Miller 010-9876-5432`;
  2294	$('btnSample').addEventListener('click',()=>loadFromText(LANG==='ko'?SAMPLE_KO:SAMPLE_EN, LANG==='ko'?'샘플_재직증명서.txt':'sample_certificate.txt'));
  2295	
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
    15	 *   5. enforce that the fields JP_RULES names are the fields the JSON names,
    16	 *   6. derive the LEGAL group per document from `legal_enforcement: true` and
    17	 *      require set equality with JP_LEGAL — plus the invariant
    18	 *      `verified:false ⇒ never legal_enforcement`. The old check only asked
    19	 *      whether a field name appeared somewhere in the matrix, which let
    20	 *      住民票コード (verified:false, no citation secured) sit under a banner
    21	 *      asserting the recipient may not keep it (Codex 6b-10).
    22	 *
    23	 * run.mjs calls this first, so the golden cannot pass while the tables disagree.
    24	 * Usage: node check_matrix.mjs   (exit 0 = identical)
    25	 */
    26	import fs from 'node:fs';
    27	import path from 'node:path';
    28	import { fileURLToPath } from 'node:url';
    29	
    30	const __dirname = path.dirname(fileURLToPath(import.meta.url));
    31	const REPO = path.resolve(__dirname, '..', '..');
    32	const MATRIX = path.join(__dirname, 'fixtures', 'jp', 'jp_legal_matrix_alpha4.json');
    33	const PAGE = path.join(REPO, 'public', 'safe', 'index.html');
    34	
    35	const LEVEL_TOKEN = { auto: 'auto', auto_with_purpose_gate: 'gate', recommend: 'recommend', optional: 'optional', keep: 'keep' };
    36	const AUTOMATIC = new Set(['auto', 'gate']);
    37	
    38	const problems = [];
    39	const fail = (what, msg) => problems.push(`${what}: ${msg}`);
    40	
    41	/* ── 1. the 정본 → a (doc, field, purpose) table ── */
    42	const M = JSON.parse(fs.readFileSync(MATRIX, 'utf8'));
    43	const PURPOSES = Object.keys(M.purposes);
    44	const matrix = {};            // doc → field → purpose → level
    45	const matrixFields = {};      // doc → Set(field)
    46	const matrixLegal = {};       // doc → Set(field) grounded in statute
    47	function applyRule(docId, rule, where) {
    48	  const token = LEVEL_TOKEN[rule.level];
    49	  if (!token) { fail(where, `unknown level "${rule.level}"`); return; }
    50	  if (!Array.isArray(rule.fields) || !rule.fields.length) { fail(where, 'rule has no `fields` (code field keys)'); return; }
    51	  if (rule.verified === false && AUTOMATIC.has(token))
    52	    fail(where, `verified:false but level "${rule.level}" is automatic — an unsourced rule may not delete pixels on its own`);
    53	  if (rule.legal_enforcement === true) {
    54	    if (rule.verified === false)
    55	      fail(where, 'verified:false but legal_enforcement:true — a rule whose citation we could not secure may not assert a statutory restriction');
    56	    matrixLegal[docId] = matrixLegal[docId] || new Set();
    57	    for (const f of rule.fields) matrixLegal[docId].add(f);
    58	  }
    59	  const seen = {};
    60	  const put = (purpose, level) => {
    61	    if (!PURPOSES.includes(purpose)) { fail(where, `unknown purpose "${purpose}"`); return; }
    62	    if (seen[purpose]) { fail(where, `purpose "${purpose}" appears twice (${seen[purpose]} and ${level})`); return; }
    63	    seen[purpose] = level;
    64	    for (const f of rule.fields) {
    65	      matrix[docId] = matrix[docId] || {};
    66	      matrix[docId][f] = matrix[docId][f] || {};
    67	      matrixFields[docId] = matrixFields[docId] || new Set();
    68	      matrixFields[docId].add(f);
    69	      const prev = matrix[docId][f][purpose];
    70	      if (prev && prev !== level) fail(`${docId}.${f}[${purpose}]`, `two rules disagree: ${prev} vs ${level}`);
    71	      matrix[docId][f][purpose] = level;
    72	    }
    73	  };
    74	  for (const p of (rule.must_keep_when || [])) put(p, 'keep');
    75	  for (const p of (rule.mask_when || [])) put(p, token);
    76	  for (const p of (rule.optional_when || [])) put(p, 'optional');
    77	}
    78	for (const doc of M.documents) for (const r of doc.rules) applyRule(doc.id, r, `${doc.id} 「${r.field}」`);
    79	// general_jp applies to every listed document.
    80	const G = M.general_jp || { applies_to: [], rules: [] };
    81	for (const docId of G.applies_to) for (const r of G.rules) applyRule(docId, r, `general_jp→${docId} 「${r.field}」`);
    82	
    83	/* ── 2. the code → JP_RULES + jpLevel ── */
    84	const src = fs.readFileSync(PAGE, 'utf8');
    85	function slice(startMarker, endMarker) {
    86	  const a = src.indexOf(startMarker);
    87	  if (a < 0) throw new Error(`cannot find ${startMarker} in ${PAGE}`);
    88	  const b = src.indexOf(endMarker, a);
    89	  if (b < 0) throw new Error(`cannot find ${endMarker} after ${startMarker}`);
    90	  return src.slice(a, b + endMarker.length);
    91	}
    92	// Everything from the purpose shorthands through the end of JP_RULES, then jpLevel.
    93	const rulesSrc = slice('const P_NOT_MYNUM =', '\n};\n');
    94	const levelSrc = slice('function jpLevel(', '\n}\n');
    95	const legalSrc = slice('const JP_LEGAL = {', '\n};\n');
    96	let JP_RULES, jpLevel, JP_LEGAL;
    97	try {
    98	  ({ JP_RULES, jpLevel, JP_LEGAL } =
    99	    new Function(`${rulesSrc}\n${levelSrc}\n${legalSrc}\nreturn {JP_RULES, jpLevel, JP_LEGAL};`)());
   100	} catch (e) {
   101	  console.error('could not evaluate JP_RULES / jpLevel out of index.html:', e.message);
   102	  process.exit(2);
   103	}
   104	
   105	/* ── 3. compare every triple in EITHER table ── */
   106	let compared = 0;
   107	const docs = new Set([...Object.keys(matrix), ...Object.keys(JP_RULES)]);
   108	for (const doc of docs) {
   109	  const mf = matrixFields[doc] || new Set();
   110	  const cf = new Set(Object.keys(JP_RULES[doc] || {}));
   111	  for (const f of cf) if (!mf.has(f)) fail(`${doc}.${f}`, 'in JP_RULES but not in the legal matrix');
   112	  for (const f of mf) if (!cf.has(f)) fail(`${doc}.${f}`, 'in the legal matrix but not in JP_RULES');
   113	  for (const f of new Set([...mf, ...cf])) {
   114	    for (const p of PURPOSES) {
   115	      const want = ((matrix[doc] || {})[f] || {})[p] || null;
   116	      const got = (JP_RULES[doc] && JP_RULES[doc][f]) ? jpLevel(doc, f, p) : null;
   117	      compared++;
   118	      if (want !== got) fail(`${doc}.${f}[${p}]`, `matrix says ${want || 'null (not offered)'}, code says ${got || 'null (not offered)'}`);
   119	    }
   120	  }
   121	}
   122	// A triple must have been checked. A comparison loop that silently ran zero
   123	// times prints the same green as one that checked two hundred.
   124	if (compared < 100) fail('coverage', `only ${compared} (doc, field, purpose) triples compared — the extraction is probably broken`);
   125	
   126	/* ── 6. the legal group IS what the matrix grounds in statute, per document ──
   127	   Set equality, not subset: a missing member silently drops a statutory band
   128	   back under the category checkboxes (the Codex 4-6 failure), and an extra one
   129	   asserts a restriction the matrix does not claim (the Codex 6b-10 failure). */
   130	let legalPairs = 0;
   131	for (const doc of new Set([...Object.keys(matrixLegal), ...Object.keys(JP_LEGAL)])) {
   132	  const want = matrixLegal[doc] || new Set();
   133	  const got = new Set(JP_LEGAL[doc] || []);
   134	  if (!JP_LEGAL[doc]) fail(`JP_LEGAL.${doc}`, 'document missing from JP_LEGAL (write [] if it has no statutory field)');
   135	  for (const f of got) if (!want.has(f)) fail(`JP_LEGAL.${doc}.${f}`, 'in the legal group but the matrix does not mark it legal_enforcement:true');
   136	  for (const f of want) if (!got.has(f)) fail(`JP_LEGAL.${doc}.${f}`, 'matrix says legal_enforcement:true but the code leaves it to the category checkboxes');
   137	  legalPairs += new Set([...want, ...got]).size;
   138	}
   139	// Same reason as `compared`: zero comparisons print the same green as many.
   140	if (legalPairs < 8) fail('coverage', `only ${legalPairs} legal (doc, field) pairs compared — the extraction is probably broken`);
   141	
   142	if (problems.length) {
   143	  console.log(`\n✗ legal matrix ↔ code: ${problems.length} disagreement(s) over ${compared} triples\n`);
   144	  for (const p of problems) console.log('   ' + p);
   145	  console.log('');
   146	  process.exit(1);
   147	}
   148	console.log(`✅ legal matrix ↔ code: ${compared} (doc, field, purpose) triples identical, ${legalPairs} legal pairs identical, verified:false⇒no-auto/no-legal holds`);
   180	     category is off or whose boxes are empty (Codex 5-5). */
   181	  window.__fieldBands = function (field) {
   182	    const mr = window.__maskRects();
   183	    const same = (a, b) => Math.abs(a.x - b.x) < 0.01 && Math.abs(a.y - b.y) < 0.01 && Math.abs(a.w - b.w) < 0.01 && Math.abs(a.h - b.h) < 0.01;
   184	    return entities.filter(e => e.jp && e.jp.field === field).map(e => {
   185	      const rects = [];
   186	      for (let pi = 0; pi < pages.length; pi++) for (const l of mergeLineBoxes(e.boxes || [], pi)) { const r = bandRect(l); rects.push({ pi, ...r }); }
   187	      return { level: e.jp.level, note: e.jp.note, page: e.jp.page, doc: e.jp.doc, side: e.jp.side,
   188	        kind: e.kind, mode: e.mode, legal: !!e.legal, located: !!(e.boxes && e.boxes.length), on: isOn(e),
   189	        rects: rects.length, inMask: rects.length > 0 && rects.every(r => mr.some(m => m.pi === r.pi && same(m, r))) };
   190	    });
   191	  };
   192	  window.__jpState = function () {
   193	    const warnEl = document.getElementById('jpWarn'), emptyEl = document.getElementById('jpEmpty');
   194	    return { cls: jpState.cls && { doc: jpState.cls.doc, side: jpState.cls.side || null, score: jpState.cls.score, low: !!jpState.cls.low },
   195	      purpose: jpState.purpose, warn: jpState.warn, mnConfirmed: jpState.mnConfirmed,
   196	      pageCls: jpState.pageCls.map(c => c && { doc: c.doc, side: c.side || null, low: !!c.low, viaBackAnchor: !!c.viaBackAnchor }),
   197	      warnShown: !!warnEl && warnEl.style.display !== 'none' && !!warnEl.textContent.trim(),
   198	      // The TEXT, not just "a banner is up": the two warning states describe
   199	      // opposite outputs, so a test that only checks visibility passes while
   200	      // the page tells the user the reverse of what it did (Codex 6b-1).
   201	      warnText: warnEl ? warnEl.textContent.trim() : '',
   202	      warnLowStyle: !!warnEl && warnEl.classList.contains('is-low'),
   203	      // Bands actually painted in the default output, so "no automatic masking"
   204	      // can be contradicted by measurement rather than taken on trust.
   205	      maskRectCount: window.__maskRects().length,
   206	      emptyShown: !!emptyEl && emptyEl.style.display !== 'none' && !!emptyEl.textContent.trim(),
   207	      mnBoxShown: (() => { const el = document.getElementById('jpMnWrap'); return !!el && el.style.display !== 'none'; })(),
   208	      mnLabel: (() => { const el = document.getElementById('jpMnLabel'); return el ? el.textContent.trim() : ''; })(),
   209	      pw: pages.map(p => p.w),
   210	      fields: entities.filter(e => e.jp).map(e => ({ field: e.jp.field, level: e.jp.level, note: e.jp.note, page: e.jp.page, doc: e.jp.doc, side: e.jp.side, kind: e.kind, mode: e.mode, legal: !!e.legal, on: isOn(e) })) };
   211	  };
   212	  // Field labels of every ACTIVE auto entity — the allowlist assertion's input.
   213	  window.__autoFields = function () {
   214	    return entities.filter(e => e.kind === 'auto').map(e => e.jp ? e.jp.field : '(regex:' + e.type + ')');
   215	  };
   216	  /* Turn every general category OFF. A legal-preset band must survive this.
   217	     catEnabled is module-level state that resetAll() and a fresh file load do
   218	     NOT restore, so this hands back a restore function — the first version of
   219	     this helper left every category off for the remaining 300 assertions and
   220	     turned 14 of them red. */
   221	  window.__catSnapshot = null;
   222	  window.__allCatsOff = function () {
   223	    window.__catSnapshot = { ...catEnabled };
   224	    for (const t of Object.keys(catEnabled)) catEnabled[t] = false;
   225	    renderAll();
   226	    return Object.keys(catEnabled).filter(t => catEnabled[t] !== false);
   227	  };
   228	  window.__restoreCats = function () {
   229	    if (!window.__catSnapshot) return false;
   230	    for (const t of Object.keys(window.__catSnapshot)) catEnabled[t] = window.__catSnapshot[t];
   231	    window.__catSnapshot = null; renderAll(); return true;
   232	  };
   233	  window.__setMnConfirm = function (v) { jpSetMnConfirmed(v); };
   234	  window.__isCandidateExact = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value) === n); };
   235	  window.__isCandidateContains = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value).includes(n)); };
   236	  // default mode of the candidate whose value contains v (null if not a candidate)
   237	  window.__candidateMode = function (v) { const n = norm(v); const e = entities.find(x => x.kind === 'candidate' && norm(x.value).includes(n)); return e ? e.mode : null; };
   238	  // name-bar geometry: glyph union (raw pdf items) vs drawn bar rect
   239	  window.__nameBar = function (v) {
   240	    const rects = boxesForValue(v).filter(b => b.page === 0);
   241	    if (!rects.length) return null;
   242	    const lines = mergeLineBoxes(rects, 0); const bar = lines[0];
   243	    // glyph union straight from page items overlapping the value
   244	    const its = (pages[0].items || []).filter(it => (v.split(/\s+/).some(w => (it.str || '').includes(w))));
   245	    if (!its.length) return null;
   610	    for (const f of (c.require_fields || [])) rec(tag, 'JP_FIELD', f, 'detected', got.has(f) ? 'detected' : 'MISSING', got.has(f));
   611	    // A band is only a band if the entity is located, its category is ON, its
   612	    // mode is not 'ok', AND the rect it paints is in the active mask-rect list.
   613	    for (const f of (c.require_banded || [])) {
   614	      const bs = await page.evaluate(x => window.__fieldBands(x), f);
   615	      const ok = bs.length > 0 && bs.every(b => b.located && b.on && b.mode !== 'ok' && b.inMask);
   616	      const why = !bs.length ? 'MISSING'
   617	        : bs.every(b => b.located && b.on && b.mode !== 'ok' && b.inMask) ? `banded ×${bs.length}`
   618	        : bs.map(b => !b.located ? 'NOT LOCATED' : !b.on ? 'CATEGORY OFF' : b.mode === 'ok' ? 'CLEAR' : 'NOT IN MASKRECTS').join('/');
   619	      rec(tag, 'JP_BANDED', f, 'located+on+in-maskrects', why, ok);
   620	    }
   621	    // The inverse of require_banded, and the half that makes a purpose-gate test
   622	    // mean something: without it, "banded under 相談用共有" could be true simply
   623	    // because the field is banded under every purpose. Also asserts the rect is
   624	    // absent from the mask list, not merely that the mode string says 'ok'.
   625	    for (const f of (c.require_clear || [])) {
   626	      const bs = await page.evaluate(x => window.__fieldBands(x), f);
   627	      const clear = bs.length > 0 && bs.every(b => b.mode === 'ok' && !b.inMask);
   628	      rec(tag, 'JP_CLEAR', f, 'detected+clear', !bs.length ? 'MISSING' : (clear ? `detected+clear ×${bs.length}` : 'BANDED'), clear);
   629	    }
   630	    /* Legal-preset fields are not governed by the category checkboxes. Turn
   631	       every category off and require the band to still be there.
   632	       `catEnabled` is module state that neither resetAll() nor a fresh file load
   633	       restores, so an exception anywhere between the two calls below used to
   634	       leave EVERY category off for the remaining assertions — once already, 11
   635	       of the 14 reds it produced belonged to other documents. try/finally, and
   636	       the restore is itself asserted. */
   637	    for (const f of (c.require_legal || [])) {
   638	      try {
   639	        const left = await page.evaluate(() => window.__allCatsOff());
   640	        const bs = await page.evaluate(x => window.__fieldBands(x), f);
   641	        const ok = left.length === 0 && bs.length > 0 && bs.every(b => b.legal && b.on && b.mode !== 'ok' && b.inMask);
   642	        rec(tag, 'JP_LEGAL', f, 'survives all-categories-off',
   643	          left.length ? 'cats still on: ' + left.join(',') : !bs.length ? 'MISSING'
   644	            : bs.every(b => b.legal && b.on && b.mode !== 'ok' && b.inMask) ? `banded ×${bs.length}` : 'DROPPED', ok);
   645	      } finally {
   646	        // put the page back the way the rest of the case expects it — on the
   647	        // error path too, where the rest of the run is what is at stake.
   648	        const restored = await page.evaluate(() => window.__restoreCats());
   649	        const stillOff = await page.evaluate(() => Object.keys(catEnabled).filter(t => catEnabled[t] === false));
   650	        rec(tag, 'JP_LEGAL', f + ' (categories restored)', 'restored+none-off',
   651	          !restored ? 'NOT RESTORED' : stillOff.length ? 'STILL OFF: ' + stillOff.join(',') : 'restored',
   652	          restored && stillOff.length === 0);
   653	        await loadDoc(page, spec.doc, true);
   654	        await page.evaluate(p => jpSetPurpose(p), c.purpose);
   655	        if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
   656	      }
   657	    }
   658	    /* Which fields were automatically banded. Two strengths, because the
   659	       fixtures are two different kinds of evidence:
   660	         required_auto — SET EQUALITY. A ceiling on the count cannot tell "the
   661	           right five" from "two right and three wrong" (Codex 5-6), and a
   662	           subset-only allowlist cannot tell "the right five" from NONE: an
   663	           empty actual set is a subset of everything, so a detection that
   664	           stopped firing entirely still printed green (Codex 6b-16).
   665	         allowed_auto — subset only, for the rotated/blurred JPG and the
   666	           re-rendered PDF, where WHICH member of the 保険者番号 family OCR
   667	           recovers is not a promise we can make. */
   668	    if (c.required_auto || c.allowed_auto) {
   669	      const af = await page.evaluate(() => window.__autoFields());
   670	      const got = [...new Set(af)].sort();
   671	      if (c.required_auto) {
   672	        const want = [...new Set(c.required_auto)].sort();
   673	        rec(tag, 'JP_AUTO_SET', 'auto fields == expected set', want.join(',') || '(none)',
   674	          got.join(',') || '(none)', want.length === got.length && want.every((f, i) => f === got[i]));
   675	      } else {
   676	        const bad = got.filter(f => !c.allowed_auto.includes(f));
   677	        rec(tag, 'JP_AUTO_SET', 'auto fields ⊆ allowlist', '⊆ ' + (c.allowed_auto.join(',') || '(none)'),
   678	          bad.length ? 'UNEXPECTED: ' + bad.join(',') : (got.join(',') || '(none)'), bad.length === 0);
   679	      }
   680	    }
   681	    // Re-read: the require_legal loop above reloads the document, so `st` from
   682	    // the top of the case may no longer describe the page.
   683	    if (c.expect_empty_notice != null || c.expect_jp_entities != null) {
   684	      const now = await page.evaluate(() => window.__jpState());
   685	      if (c.expect_empty_notice != null)
   686	        rec(tag, 'JP_EMPTY', 'no-rules-for-purpose notice', c.expect_empty_notice ? 'shown' : 'absent',
   687	          now.emptyShown ? 'shown' : 'absent', now.emptyShown === !!c.expect_empty_notice);
   688	      if (c.expect_jp_entities != null)
   689	        rec(tag, 'JP_ENTITIES', 'jp entities', String(c.expect_jp_entities), String(now.fields.length),
   690	          now.fields.length === c.expect_jp_entities);
   691	    }
   692	    if (spec.geometry === false || c.geometry === false) continue;
   693	
   694	    const P = fx.purposes[c.key];
   695	    if (!P) { rec(tag, 'JP_SPEC', c.key, 'purpose in fixture', 'MISSING', false); continue; }
   696	    const scale = st.pw[0] / fx.size[0];
   697	    let checked = 0;
   698	    const box = k => { const b = fx.boxes_png[k]; return b && { pi: 0, x: b[0] * scale, y: b[1] * scale, w: (b[2] - b[0]) * scale, h: (b[3] - b[1]) * scale }; };
   699	    const seen = new Set();
   700	    const run = async (keys, kindFor) => {
   701	      for (const k of (keys || [])) {
   702	        if (k === 'ALL' || seen.has(k)) continue;
   703	        const r = box(k);
   704	        // An expectation naming a box this variant does not have is a FAULT in
   705	        // the expectation table, not a case to skip. It used to be "reported as
   840	      rec(tag, 'JP_PAGECLASS', 'per-page doc/side', wantSides.join(' + '), sides.join(' + '),
   841	        sides.length === 2 && sides[c.backPage] === wantSides[c.backPage] && sides[c.frontPage] === wantSides[c.frontPage]);
   842	      // The whole-face band exists on the BACK page and only there.
   843	      const bs = await page.evaluate(() => window.__fieldBands('back_all'));
   844	      const pagesWithBand = bs.filter(b => b.mode !== 'ok' && b.inMask).map(b => b.page);
   845	      rec(tag, 'JP_BACK_ONLY', 'back_all pages', `[${c.backPage}]`, `[${pagesWithBand.join(',')}]`,
   846	        pagesWithBand.length === 1 && pagesWithBand[0] === c.backPage);
   847	      // And geometrically: the back page is covered, the front page is not.
   848	      const cov = await page.evaluate(() => pages.map((p, pi) => window.__coverage({ pi, x: 0, y: 0, w: p.w, h: p.h })));
   849	      rec(tag, 'JP_BACK_COVER', `page ${c.backPage} covered`, '>=99%', `${(cov[c.backPage] * 100).toFixed(0)}%`, cov[c.backPage] >= 0.99);
   850	      rec(tag, 'JP_FRONT_CLEAR', `page ${c.frontPage} not full-face`, '<=60%', `${(cov[c.frontPage] * 100).toFixed(0)}%`, cov[c.frontPage] <= 0.6);
   851	    } catch (e) { rec(tag, 'LOAD', c.file, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
   852	    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
   853	  }
   854	
   855	  /* Page 2 cannot classify itself. Two of those, and they must come out
   856	     OPPOSITE — which is what the old `jpClassify(pi) || cls0` could not do: it
   857	     governed both with page 1's rules, so an unrelated attachment bound into
   858	     the same PDF was redacted with CARD rules. The error direction there is
   859	     destroying required evidence, not leaking (Codex 6b-3).
   860	       (a) the card's own back face with its TITLE cropped away — it still
   861	           carries 個人番号, a back-only anchor, so it is promoted to 裏面;
   862	       (b) a Korean résumé page — no anchor, stays `null`, no Japanese rule runs.
   863	     Both pages are composed at run time from committed files. */
   864	  const front = `${B}/front.png`;
   865	  const mixed = [
   866	    { label: '表 + 裏(タイトル切除) → 裏面に昇格', file: 'gen/mn_front_backcrop.pdf',
   867	      srcs: [front, { url: `${B}/back.png`, crop: [0, 100, 1100, 700] }],
   868	      wantSide: 'mynumber_card/back', wantPromoted: true, wantBand: true },
   869	    { label: '表 + 無関係な添付 → 分類なし', file: 'gen/mn_front_attach.pdf',
   870	      srcs: [front, { pdf: `http://127.0.0.1:${port}/__td/1_text.pdf`, page: 1, scale: 1.5 }],
   871	      wantSide: 'null', wantPromoted: false, wantBand: false },
   872	  ];
   873	  for (const c of mixed) {
   874	    const tag = `jp/2page ${c.label}`;
   875	    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
   876	    try {
   877	      await buildPdfFromImages(page, c.srcs, path.join(OUT, c.file));
   878	      await loadDoc(page, c.file, true);
   879	      await page.evaluate(() => jpSetPurpose('identity_submit'));
   880	      const st = await page.evaluate(() => window.__jpState());
   881	      const sides = st.pageCls.map(x => x ? (x.doc + '/' + (x.side || '-')) : 'null');
   882	      rec(tag, 'JP_PAGECLASS', 'per-page doc/side', `mynumber_card/front + ${c.wantSide}`, sides.join(' + '),
   883	        sides.length === 2 && sides[0] === 'mynumber_card/front' && sides[1] === c.wantSide);
   884	      rec(tag, 'JP_BACKANCHOR', 'page 2 promoted via back anchor', String(c.wantPromoted),
   885	        String(!!(st.pageCls[1] && st.pageCls[1].viaBackAnchor)),
   886	        !!(st.pageCls[1] && st.pageCls[1].viaBackAnchor) === c.wantPromoted);
   887	      // Japanese entities per page. Page 1 must still have its own (otherwise
   888	      // "page 2 has none" could be true because the whole preset collapsed).
   889	      const onP0 = st.fields.filter(f => f.page === 0).length;
   890	      const onP1 = st.fields.filter(f => f.page === 1).length;
   891	      rec(tag, 'JP_ENTITIES', 'page 1 jp entities', '>=1', String(onP0), onP0 >= 1);
   892	      rec(tag, 'JP_ENTITIES', 'page 2 jp entities', c.wantBand ? '>=1' : '0', String(onP1),
   893	        c.wantBand ? onP1 >= 1 : onP1 === 0);
   894	      const bs = await page.evaluate(() => window.__fieldBands('back_all'));
   895	      const bandPages = bs.filter(b => b.mode !== 'ok' && b.inMask).map(b => b.page);
   896	      rec(tag, 'JP_BACK_ONLY', 'back_all pages', c.wantBand ? '[1]' : '[]', `[${bandPages.join(',')}]`,
   897	        c.wantBand ? (bandPages.length === 1 && bandPages[0] === 1) : bandPages.length === 0);
   898	      const cov = await page.evaluate(() => pages.map((p, pi) => window.__coverage({ pi, x: 0, y: 0, w: p.w, h: p.h })));
   899	      rec(tag, c.wantBand ? 'JP_BACK_COVER' : 'JP_ATTACH_CLEAR', 'page 2 coverage',
   900	        c.wantBand ? '>=99%' : '<=10%', `${(cov[1] * 100).toFixed(0)}%`,
   901	        c.wantBand ? cov[1] >= 0.99 : cov[1] <= 0.10);
   902	      rec(tag, 'JP_FRONT_CLEAR', 'page 1 not full-face', '<=60%', `${(cov[0] * 100).toFixed(0)}%`, cov[0] <= 0.6);
   903	    } catch (e) { rec(tag, 'LOAD', c.file, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
   904	    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
   905	  }
   906	}
   907	
   908	/* ── 個人番号 check digit ───────────────────────────────────────────────────
   909	   Two layers. The vectors pin the arithmetic of 省令第5条 (including the two
   910	   remainder cases the 省令 folds to 0). The synthesis then drives a VALID
  1000	}
  1001	
  1002	/* ── unlabelled square block: offered, never banded by default ──────────────
  1003	   The pixel detector for an unlabelled block has no golden coverage (the alpha
  1004	   dummies carry no real QR — strategy v2 §4), and it can fire on a face photo,
  1005	   a round seal (bbox fill ≈ 0.785) or a black table header. So the POLICY is
  1006	   what gets pinned here: a finding flagged `unlabelledCode` comes out of
  1007	   jpApply as `optional` / mode 'ok' / not in the mask list, even on a document
  1008	   whose labelled 二次元コード is an automatic band. The finding is injected —
  1009	   this tests the decision, not the detector, and says so. */
  1010	async function checkJpUnlabelled(page) {
  1011	  const U = SPECS.jp_unlabelled_block; if (!U) return;
  1012	  const tag = '(jp unlabelled)';
  1013	  await page.evaluate(() => { LANG = 'ja'; applyLang(); });
  1014	  await loadDoc(page, U._doc, true);
  1015	  await page.evaluate(p => jpSetPurpose(p), U.purpose);
  1016	  const res = await page.evaluate(() => {
  1017	    // A square where nothing on the page is a code: top-left corner of the page.
  1018	    const r = { page: 0, x: 40, y: 40, w: 120, h: 120, region: true };
  1019	    jpState.findings.push({ field: 'qr', boxes: [r], value: '二次元コード', pi: 0,
  1020	      doc: jpState.cls.doc, side: jpState.cls.side || null, low: false, unlabelledCode: true });
  1021	    jpApply();
  1022	    const inj = entities.find(e => e.jp && e.jp.note === 'unlabelled_code');
  1023	    // `.every()` on an EMPTY array is true, so this companion assertion passed
  1024	    // even if labelled-QR detection had disappeared entirely — which is the one
  1025	    // way the assertion above ("the unlabelled block is not banded") becomes
  1026	    // meaningless (Codex 6b-14). Count first.
  1027	    const lab = window.__fieldBands('qr').filter(b => b.note !== 'unlabelled_code');
  1028	    return { present: !!inj, level: inj && inj.jp.level, mode: inj && inj.mode, kind: inj && inj.kind,
  1029	      covered: window.__coverage({ pi: 0, x: 40, y: 40, w: 120, h: 120 }),
  1030	      labelledCount: lab.length,
  1031	      labelledBanded: lab.length > 0 && lab.every(b => b.mode !== 'ok' && b.inMask) };
  1032	  });
  1033	  rec(tag, 'JP_UNLABELLED', 'level', 'optional', res.present ? res.level : 'MISSING', res.level === 'optional');
  1034	  rec(tag, 'JP_UNLABELLED', 'default mode', 'ok', res.present ? res.mode : 'MISSING', res.mode === 'ok');
  1035	  rec(tag, 'JP_UNLABELLED', 'not in default output', '0% covered', `${(res.covered * 100).toFixed(0)}%`, res.covered <= 0.10);
  1036	  // …and the LABELLED code on the same page is still banded, so the assertion
  1037	  // above is not passing merely because nothing is banded at all.
  1038	  rec(tag, 'JP_UNLABELLED', 'labelled code still banded', '>=1 banded',
  1039	    res.labelledCount ? (res.labelledBanded ? `banded ×${res.labelledCount}` : 'CLEAR') : 'NO LABELLED CODE FOUND', res.labelledBanded);
  1040	  await page.evaluate(() => { LANG = 'ko'; applyLang(); });
  1041	}
  1042	
  1043	/* ── classification failure must be visible ─────────────────────────────────
  1044	   A page that says 資格確認書 and nothing else reaches 3 of the 4 points it
  1045	   needs. The old build dropped the entire Japanese preset and fell through to
  1046	   the Latin name/address heuristics without a word (Codex 1-1). */
  1047	async function checkJpWarn(page) {
  1048	  const W = SPECS.jp_warn; if (!W) return;
  1049	  for (const c of W.cases) {
  1050	    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
  1051	    await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
  1052	    await page.evaluate(t => loadFromText(t, 'warn.txt'), c.text);
  1053	    await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0, { timeout: 40000 });
  1054	    await page.evaluate(PAGE_HELPERS);
  1055	    const st = await page.evaluate(() => window.__jpState());
  1056	    rec('(jp warn)', 'JP_WARN', c.label, c.expect_warn ? `shown/${c.expect_warn}` : 'absent',
  1057	      st.warnShown ? `shown/${st.warn}` : 'absent',
  1058	      st.warnShown === !!c.expect_warn && (!c.expect_warn || st.warn === c.expect_warn));
  1059	    rec('(jp warn)', 'JP_WARN_CLASS', c.label + ' class', c.expect_doc || 'null',
  1060	      st.cls ? st.cls.doc + (st.cls.low ? '(low)' : '') : 'null',
  1061	      (st.cls ? st.cls.doc : null) === (c.expect_doc || null) && (!c.expect_doc || !!st.cls.low === !!c.expect_low));
  1062	    /* The banner's TEXT, against the ja string the case names. The two states
  1063	       make opposite claims about the output, so visibility alone is not the
  1064	       assertion: the old single string said "no automatic redaction was
  1065	       applied" while low-confidence candidate bands were in the output
  1066	       (Codex 6b-1). `expect_text_has` is a distinguishing fragment, so a
  1067	       reworded sentence does not fail but a swapped MEANING does. */
  1068	    if (c.expect_text_has)
  1069	      rec('(jp warn)', 'JP_WARN_TEXT', c.label + ' banner text', c.expect_text_has,
  1070	        st.warnText.includes(c.expect_text_has) ? 'matches' : `"${st.warnText.slice(0, 24)}…"`,
  1071	        st.warnText.includes(c.expect_text_has));
  1072	    // …and what the output actually contains, measured. `lowconf` claims bands
  1073	    // were applied; `unclassified` claims none were.
  1074	    if (c.expect_mask_rects === 'some')
  1075	      rec('(jp warn)', 'JP_WARN_BANDS', c.label + ' bands in output', '>=1',
  1076	        String(st.maskRectCount), st.maskRectCount >= 1);
  1077	    if (c.expect_mask_rects === 'none')
  1078	      rec('(jp warn)', 'JP_WARN_BANDS', c.label + ' bands in output', '0',
  1079	        String(st.maskRectCount), st.maskRectCount === 0);
  1080	    // A low-confidence class may not produce an automatic band.
  1081	    if (c.expect_low) {
  1082	      const af = await page.evaluate(() => window.__autoFields());
  1083	      const jpAuto = af.filter(f => !f.startsWith('(regex:'));
  1084	      rec('(jp warn)', 'JP_WARN_NOAUTO', c.label + ' no jp auto', '(none)',
  1085	        jpAuto.length ? jpAuto.join(',') : '(none)', jpAuto.length === 0);
  1086	    }
  1087	    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
  1088	  }
  1089	}
  1090	
  1091	function printTable() {
  1092	  const pad = (s, n) => { s = String(s); return s.length > n ? s.slice(0, n - 1) + '…' : s.padEnd(n); };
  1093	  let lastDoc = '';
  1094	  console.log('\n' + '═'.repeat(120));
  1095	  console.log(pad('DOC', 20) + pad('CATEGORY', 17) + pad('ITEM', 40) + pad('EXPECTED', 18) + pad('ACTUAL', 18) + 'RESULT');
  1096	  console.log('─'.repeat(120));
  1097	  for (const r of rows) {
  1098	    if (r.doc !== lastDoc) { console.log('─'.repeat(120)); lastDoc = r.doc; }
  1099	    const mark = r.info ? (r.pass ? 'ℹ ok' : 'ℹ note') : (r.pass ? '✅ PASS' : '❌ FAIL');
  1100	    console.log(pad(r.doc, 20) + pad(r.cat, 17) + pad(r.item, 40) + pad(r.expected, 18) + pad(r.actual, 18) + mark);

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "nl -ba public/safe/index.html | sed -n '1525,1555p;1705,1815p;1965,2025p;2100,2185p;2320,2410p' && nl -ba test/safe/check_matrix.mjs | sed -n '35,150p' && nl -ba test/safe/run.mjs | sed -n '205,238p;628,658p'" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
  1525	/* The legal-preset fields, PER DOCUMENT: the ones the matrix grounds in 番号法 /
  1526	   告知要求制限 rather than in a submission-desk convention. They are NOT subject
  1527	   to the general category checkboxes — turning off 「その他」 used to silently
  1528	   remove the マイナカード裏面 band and the 資格確認書 QR band from the output, with
  1529	   no warning (Codex 4-6). They live in their own group and can only be released
  1530	   one item at a time, and releasing one says 「法令上…制限される場合があります」.
  1531	   Mirrors `legal_enforcement: true` in the matrix, which check_matrix.mjs
  1532	   compares field-for-field AND allows only on `verified: true` rules. A flat
  1533	   field-name Set could not express that distinction: it put 住民票コード — whose
  1534	   own matrix entry says the statutory citation could NOT be secured
  1535	   (verified:false) — under a banner asserting the recipient may not keep it
  1536	   (Codex 6b-10). Document scope matters for the same reason: `my_number` is
  1537	   番号法-grounded on 住民票, `jumin_code` is not grounded at all. */
  1538	const JP_LEGAL = {
  1539	  shikaku_kakuninsho: ['hokensha_bango','kigo','bango','edaban','hihokensha_bango','qr'],
  1540	  unten_menkyo: [],
  1541	  mynumber_card: ['back_all','my_number','qr'],
  1542	  juminhyo: ['my_number'],
  1543	};
  1544	function jpIsLegal(doc, field){ return (JP_LEGAL[doc] || []).includes(field); }
  1545	function jpLevel(doc, field, purpose){
  1546	  const r = (JP_RULES[doc] || {})[field];
  1547	  if (!r) return null;
  1548	  for (const lv of ['auto','gate','recommend','optional','keep'])
  1549	    if (r[lv] && r[lv].includes(purpose)) return lv;
  1550	  return null;
  1551	}
  1552	
  1553	/* ── field extraction ─────────────────────────────────────────────────────
  1554	   Each rule is {field, labels[], re, last} — `labels` are the anchors accepted
  1555	   in the segment (several spellings, because OCR drops or swaps one character
  1705	   swallows the neighbouring column: 「保険者名 架空健康保険協会 保険者番号 99221010」
  1706	   handed the 保険者名 rule the insurer NUMBER's items and marked them `used` —
  1707	   and `used` is exactly what the structural fallback refuses to re-claim. A
  1708	   field we promise never to redact was suppressing one the 告知要求制限 requires
  1709	   us to redact, and nothing about the output said so (Codex 6b-5). */
  1710	function jpKnownLabels(doc){
  1711	  const out = [];
  1712	  for (const r of (JP_FIELD_RULES[doc] || [])) out.push(...r.labels);
  1713	  for (const r of (JP_REGION_LABELS[doc] || [])) out.push(...(r.labels || []));
  1714	  return out;
  1715	}
  1716	function jpTailEnd(seg, from, labels){
  1717	  let end = seg.t.length;
  1718	  for (const lb of labels){ const i = seg.t.indexOf(lb, from); if (i >= from && i < end) end = i; }
  1719	  return end;
  1720	}
  1721	/* Can this field ever be banded automatically on this document? A field whose
  1722	   only levels are keep/optional never redacts anything — so it must not CONSUME
  1723	   an identifier either. Marking a 4+ digit run as `used` is a claim ("this span
  1724	   belongs to me"), and from a field that will never cover it, that claim only
  1725	   has the effect of hiding the span from the rule that would. */
  1726	function jpKeepOnly(doc, field){
  1727	  const r = (JP_RULES[doc] || {})[field];
  1728	  return !!r && !r.auto && !r.gate && !r.recommend;
  1729	}
  1730	function jpInLongDigitRun(s, k){
  1731	  if (!isDigit(s[k])) return false;
  1732	  let a = k, b = k;
  1733	  while (a > 0 && isDigit(s[a - 1])) a--;
  1734	  while (b + 1 < s.length && isDigit(s[b + 1])) b++;
  1735	  return (b - a + 1) >= 4;
  1736	}
  1737	// Span of the first `n` digits in [from, to), tolerating group separators.
  1738	function jpDigitSpan(seg, from, n, to){
  1739	  let first = -1, last = -1, count = 0;
  1740	  const lim = to == null ? seg.t.length : to;
  1741	  for (let k = from; k < lim; k++){
  1742	    const c = seg.t[k];
  1743	    if (isDigit(c)){ if (first < 0) first = k; last = k; if (++count === n) return { a:first, b:last+1, digits: seg.t.slice(first,last+1).replace(/\D/g,'') }; }
  1744	    else if (first >= 0 && !/[\s.\-・,/]/.test(c)) { first = -1; last = -1; count = 0; }
  1745	  }
  1746	  return null;
  1747	}
  1748	function jpExtract(pi, cls){
  1749	  const segs = jpSegments(pi), found = [];
  1750	  // Every value rule anchors at the SEGMENT HEAD. In these forms the label always
  1751	  // opens its own column, so a label found mid-segment is prose, not an anchor —
  1752	  // that is how the 「裏面の生年月日有無は…要確認」 footnote on the card dummy got
  1753	  // read as a 生年月日 field. (The 欄 region labels below deliberately do not use
  1754	  // this: OCR puts a garbled 騰 in front of 器提供意思表示欄.)
  1755	  const rules = (JP_FIELD_RULES[cls.doc] || [])
  1756	    .filter(r => !r.sides || r.sides.includes(cls.side))
  1757	    .map(r => ({ ...r, headOnly: true }));
  1758	  // Every finding carries the classification of ITS OWN page. A two-sided card
  1759	  // scanned into one PDF has a different legal rule on each page, so applying
  1760	  // page 1's doc/side to every page made the outcome depend on scan order:
  1761	  // front-then-back left the 個人番号 page untouched, back-then-front banded the
  1762	  // front as well (Codex 6-4).
  1763	  const push = (field, boxes, value, extra) => {
  1764	    if (boxes && boxes.length) found.push({ field, boxes, value, pi, doc: cls.doc, side: cls.side || null, low: !!cls.low, ...extra });
  1765	  };
  1766	
  1767	  const labelSet = jpKnownLabels(cls.doc);
  1768	  for (const seg of segs){
  1769	    for (const r of rules){
  1770	      const L = jpFindLabel(seg, r.labels, r.headOnly);
  1771	      if (!L) continue;
  1772	      // Where this label's own value has to end: the next known label in the
  1773	      // same segment, i.e. the next column's anchor. Every value path is bounded
  1774	      // by it, not just the positional `last:true` one — a 性別 regex has no
  1775	      // business matching the 男 that belongs to the column after it either.
  1776	      const tailEnd = jpTailEnd(seg, L.end, labelSet);
  1777	      /* A keep-only field (jpKeepOnly) does not claim an identifier it happens
  1778	         to sit next to — not its `used` marks, and in the positional branch not
  1779	         its pixels or its text either. The boundary above handles the case
  1780	         where the neighbouring LABEL was read; this handles the case where it
  1781	         was not, which on these forms is the measured normal (保険者番号 OCRs as
  1782	         "RREES"/"REEES"/"WREEES" on 3 of 5 fixtures). Without it, the keep
  1783	         field's tail consumes the number and the structural fallback — which
  1784	         only claims spans nothing else marked used — leaves it in the clear.
  1785	         The trade is stated: a 4+ digit run that genuinely belongs to a keep
  1786	         field's own value (a code inside 事業所名称, say) now stays unclaimed
  1787	         and the 資格確認書 fallback may band it. That is the direction this
  1788	         document's rules already choose deliberately — the 告知要求制限 covers
  1789	         the whole 保険者番号 family as one rule, "so the cost of guessing which
  1790	         member it is, is zero, while a miss is the exact leak the product
  1791	         exists to prevent" — and the band is releasable one item at a time. */
  1792	      const keepOnly = jpKeepOnly(cls.doc, r.field);
  1793	      const skip = k => keepOnly && jpInLongDigitRun(seg.t, k);
  1794	      const consume = (from, to) => { for (let k = from; k < to; k++) if (!skip(k)) seg.used[k] = 1; };
  1795	      if (r.tel){
  1796	        const tail = seg.t.slice(L.end, tailEnd);
  1797	        const hy = JP_TEL_HYPHEN_RE.exec(tail);
  1798	        const pl = hy ? null : JP_TEL_PLAIN_RE.exec(tail);
  1799	        const m = hy || pl;
  1800	        if (!m) continue;
  1801	        const a2 = L.end + m.index, b2 = a2 + m[0].length;
  1802	        push('tel', jpBoxes(seg, a2, b2), m[0], { loose: !hy });
  1803	        consume(a2, b2);
  1804	        continue;
  1805	      }
  1806	      if (r.digits){
  1807	        const sp = jpDigitSpan(seg, L.end, r.digits, tailEnd);
  1808	        if (!sp) continue;
  1809	        const extra = r.field === 'my_number' ? { checkOk: myNumberCheckOk(sp.digits) } : {};
  1810	        push(r.field, jpBoxes(seg, sp.a, sp.b), sp.digits, extra);
  1811	        consume(sp.a, sp.b);
  1812	        continue;
  1813	      }
  1814	      let a = -1, b = -1, val = '';
  1815	      if (r.addr){
  1965	
  1966	/* ── state + application ── */
  1967	const JP_PURPOSES = ['identity_submit','my_number_procedure','bid_attachment','consult_share'];
  1968	const JP_STATE0 = () => ({ cls: null, pageCls: [], purpose: 'identity_submit', findings: [], warn: null, mnConfirmed: false });
  1969	let jpState = JP_STATE0();
  1970	function jpScan(){
  1971	  const keepPurpose = jpState.purpose;
  1972	  jpState = JP_STATE0(); jpState.purpose = keepPurpose;
  1973	  if (!pages.length) return null;
  1974	  // Per-page classification. Page 0 names the document in the UI, but each page
  1975	  // is governed by its OWN class. A page that cannot be classified stays null —
  1976	  // NO Japanese rule runs on it. The single exception is a card's back face,
  1977	  // which carries no document name and therefore cannot classify itself: it is
  1978	  // promoted only when the PREVIOUS page is that card's front AND this page
  1979	  // carries a back-only anchor for that same card (JP_BACK_ANCHORS). Anything
  1980	  // else bound into the PDF — a bank book, a tax slip, a blank separator — is
  1981	  // governed by nothing, which is the honest answer for a page we cannot read.
  1982	  const cls0 = jpClassify(0);
  1983	  const pageCls = [];
  1984	  for (let pi = 0; pi < pages.length; pi++){
  1985	    if (pi === 0){ pageCls.push(cls0); continue; }
  1986	    let c = jpClassify(pi);
  1987	    if (!c){
  1988	      const prev = pageCls[pi - 1];
  1989	      const re = prev && prev.side === 'front' && JP_BACK_ANCHORS[prev.doc];
  1990	      if (re && re.test(jpPageText(pi)))
  1991	        c = { doc: prev.doc, side: 'back', score: prev.score, hits: prev.hits, low: !!prev.low, viaBackAnchor: true };
  1992	    }
  1993	    pageCls.push(c);
  1994	  }
  1995	  jpState.pageCls = pageCls;
  1996	  if (!cls0){
  1997	    // No Japanese rule will run. Say so if the page looks like one of these
  1998	    // documents, instead of falling through to the Latin heuristics in silence.
  1999	    if (pages.some((p, pi) => jpSuspect(pi))) jpState.warn = 'unclassified';
  2000	    return null;
  2001	  }
  2002	  jpState.cls = cls0;
  2003	  if (pageCls.some(c => c && c.low)) jpState.warn = 'lowconf';
  2004	  let all = [];
  2005	  for (let pi = 0; pi < pages.length; pi++) if (pageCls[pi]) all = all.concat(jpExtract(pi, pageCls[pi]));
  2006	  jpState.findings = all;
  2007	  return cls0;
  2008	}
  2009	function jpFieldLabel(f){ return (T().jpFields && T().jpFields[f]) || f; }
  2010	// Build entities from the findings for the current purpose. Called on load and
  2011	// on every purpose change — the purpose IS the policy, so it re-derives rather
  2012	// than patching modes in place.
  2013	/* The 個人番号 purpose gate needs more than a dropdown. Choosing 「個人番号手続」
  2014	   releases a band that 番号法 put there, and the dropdown alone cannot establish
  2015	   that the recipient actually performs a 個人番号関係事務 — PPC FAQ Q6-12
  2016	   distinguishes seeing a number from copying and keeping it, and both assume the
  2017	   recipient is entitled to it (Codex 4-4). So the release requires the purpose
  2018	   AND an explicit confirmation; until it is given, the band stays. */
  2019	function jpMnGateOpen(){ return jpState.purpose === 'my_number_procedure' && jpState.mnConfirmed; }
  2020	const JP_MN_GATED = new Set(['back_all','my_number','qr']);
  2021	function jpApply(){
  2022	  entities = entities.filter(e => !e.jp);
  2023	  const cls = jpState.cls; if (!cls) { jpRenderBar(); renderAll(); return; }
  2024	  const purpose = jpState.purpose;
  2025	  const add = (f, level, boxes, value, note, ctx) => {
  2100	function jpRenderBar(){
  2101	  const bar = $('jpBar'), warn = $('jpWarn'); if (!bar) return;
  2102	  const cls = jpState.cls;
  2103	  /* The blocking warning is independent of the bar: its whole point is to be
  2104	     visible in the case where there is no classification and therefore no bar.
  2105	     The two states say OPPOSITE things about the output and must not share a
  2106	     string. `unclassified` = no Japanese rule ran, nothing was covered, act.
  2107	     `lowconf` = we know which form this is, every automatic level was demoted
  2108	     to a candidate — which is still default-ON, so bands ARE in the output —
  2109	     and what is owed is a check. The old single string claimed "no automatic
  2110	     redaction was applied" in both, which was false in the second (Codex 6b-1). */
  2111	  if (warn){
  2112	    const low = jpState.warn === 'lowconf';
  2113	    const show = !!jpState.warn;
  2114	    warn.textContent = !show ? '' : low ? T().jpWarnLowconf : T().jpWarnUnclassified;
  2115	    warn.classList.toggle('is-low', low);
  2116	    warn.style.display = show ? 'block' : 'none';
  2117	  }
  2118	  if (!cls){ bar.style.display = 'none'; return; }
  2119	  bar.style.display = 'flex';
  2120	  $('jpDocName').textContent = jpFieldLabel('doc_' + cls.doc) + (cls.side ? ' · ' + jpFieldLabel('side_' + cls.side) : '');
  2121	  const sel = $('jpPurpose');
  2122	  sel.innerHTML = JP_PURPOSES.map(p => `<option value="${p}">${escapeHtml(jpFieldLabel('purpose_' + p))}</option>`).join('');
  2123	  sel.value = jpState.purpose;
  2124	  const note = $('jpNote');
  2125	  // The notice is shown whenever this document HAS a 個人番号 rule — including
  2126	  // after the user switched to 個人番号手続, where it is the text that explains
  2127	  // what the confirmation below it means.
  2128	  const hasMn = jpState.findings.some(f => f.field === 'my_number')
  2129	    || jpState.pageCls.some(c => c && c.doc === 'mynumber_card' && c.side === 'back');
  2130	  note.textContent = hasMn ? T().jpBackNotice : '';
  2131	  note.style.display = hasMn ? 'block' : 'none';
  2132	  const cw = $('jpMnWrap'), cb = $('jpMnConfirm');
  2133	  if (cw && cb){
  2134	    const need = hasMn && jpState.purpose === 'my_number_procedure';
  2135	    cw.style.display = need ? 'flex' : 'none';
  2136	    cb.checked = !!jpState.mnConfirmed;
  2137	    const lb = $('jpMnLabel'); if (lb) lb.textContent = T().jpMnConfirm;
  2138	  }
  2139	  /* The matrix names every (document, field, purpose) it means to offer, and a
  2140	     combination it does not name is `null` — not offered. That is deliberate,
  2141	     but it means switching purpose can empty the list completely: 資格確認書
  2142	     under 個人番号手続 offers nothing at all. Changing a dropdown and getting a
  2143	     blank result with no explanation reads as a broken page, and the user's next
  2144	     move is to assume nothing needed covering (Codex 6b-12). Say it instead. */
  2145	  const empty = $('jpEmpty');
  2146	  if (empty){
  2147	    const none = !entities.some(e => e.jp);
  2148	    empty.textContent = none ? T().jpEmptyPurpose : '';
  2149	    empty.style.display = none ? 'block' : 'none';
  2150	  }
  2151	}
  2152	
  2153	/* ───────── text masking (list display + "copy text") ─────────
  2154	   Band-only: there are exactly two states. 'ok' shows the value; anything else
  2155	   shows a block run of the same rough length. No partial reveal exists, so the
  2156	   list cannot promise a weaker masking than the rendered page delivers. */
  2157	const maskBlockText=v=>'■'.repeat(Math.min(Math.max(Math.round(v.replace(/\s/g,'').length*0.8),3),12));
  2158	// live value shown next to the toggle
  2159	function displayValue(e){ return e.mode==='ok' ? e.value : maskBlockText(e.value); }
  2160	
  2161	/* ───────── coordinate index & box matching ───────── */
  2162	function buildIndex(page){
  2163	  if(page._idx) return;
  2164	  let s='', map=[];
  2165	  page.items.forEach((it,i)=>{ const str=it.str||''; for(let c=0;c<str.length;c++){ s+=str[c]; map.push([i,c]); } s+=' '; map.push(null); });
  2166	  page._text=s; page._map=map;
  2167	  // spaceless index (fallback for values whose spacing differs from source)
  2168	  let ss='', smap=[];
  2169	  page.items.forEach((it,i)=>{ const str=it.str||''; for(let c=0;c<str.length;c++){ const ch=str[c]; if(/\s/.test(ch))continue; ss+=ch; smap.push([i,c]); } });
  2170	  page._stext=ss; page._smap=smap;
  2171	  page._idx=true;
  2172	}
  2173	function boxesFromRange(page,pi,map,a,b,out){
  2174	  const byItem={};
  2175	  for(let k=a;k<b;k++){ const m=map[k]; if(!m)continue; const [i,c]=m; (byItem[i]=byItem[i]||[]).push(c); }
  2176	  for(const i in byItem){
  2177	    const cs=byItem[i], it=page.items[i], len=(it.str||'').length||1;
  2178	    const cMin=Math.min(...cs), cMax=Math.max(...cs), cw=it.w/len;
  2179	    // Anchor edges to the item's TRUE bounds when the match reaches them — this
  2180	    // is where the proportional estimate drifts and leaves a remnant (e.g. the
  2181	    // right side of an email). Middle edges keep a proportional estimate + pad.
  2182	    const x0 = (cMin===0)     ? it.x        : it.x + cw*cMin - cw*0.4;
  2183	    const x1 = (cMax===len-1) ? it.x+it.w   : it.x + cw*(cMax+1) + cw*0.4;
  2184	    const box={page:pi,x:x0-1,y:it.y-2,w:(x1-x0)+2,h:it.h+4};
  2185	    box.bg=sampleBg(page,box);
  2320	    docTitle=f.name;
  2321	    afterLoad(false);
  2322	  }catch(err){ console.error(err); toast(T().tReadFail); setProg(0); setStatus(''); }
  2323	}
  2324	
  2325	async function loadFromText(text,name){
  2326	  resetResult();
  2327	  try{ setProg(0.05); await renderTextPages(text,name); docTitle=name||'doc'; afterLoad(false); }
  2328	  catch(err){ console.error(err); toast(T().tReadFail); setProg(0); }
  2329	}
  2330	
  2331	/* PDF: render each page + text-layer boxes; OCR fallback for scanned pages */
  2332	async function loadPdf(f){
  2333	  pdfjsLib.GlobalWorkerOptions.workerSrc=PDF_WORKER;
  2334	  const buf=await f.arrayBuffer();
  2335	  const pdf=await pdfjsLib.getDocument({data:buf}).promise;
  2336	  const n=Math.min(pdf.numPages, MAX_PAGES);
  2337	  if(pdf.numPages>MAX_PAGES) toast(T().tPageCap(MAX_PAGES));
  2338	  pages=[];
  2339	  for(let p=1;p<=n;p++){
  2340	    setStatus(T().renderProg(p,n)); setProg((p-1)/n);
  2341	    const page=await pdf.getPage(p);
  2342	    const vp1=page.getViewport({scale:1});
  2343	    const scale=Math.min(2.2, 1500/vp1.width);
  2344	    const vp=page.getViewport({scale});
  2345	    const cv=canvasEl(vp.width, vp.height);
  2346	    await page.render({canvasContext:cv.getContext('2d',{willReadFrequently:true}), viewport:vp}).promise;
  2347	    const tc=await page.getTextContent();
  2348	    let items=tc.items.filter(it=>it.str && it.str.trim()).map(it=>{
  2349	      const tx=pdfjsLib.Util.transform(vp.transform, it.transform);
  2350	      const h=Math.hypot(tx[2],tx[3])|| (it.height*scale) || 12;
  2351	      const w=(it.width*scale) || (it.str.length*h*0.5);
  2352	      return {str:it.str, x:tx[4], y:tx[5]-h, w, h};
  2353	    });
  2354	    const pageObj={canvas:cv,w:cv.width,h:cv.height,ptW:vp1.width,ptH:vp1.height,items};
  2355	    const textLen=items.reduce((s,i)=>s+i.str.trim().length,0);
  2356	    if(textLen<8){ setStatus(T().scanOcr); pageObj.items=await ocrCanvas(cv); }
  2357	    pages.push(pageObj);
  2358	  }
  2359	  setProg(0);
  2360	}
  2361	
  2362	/* Image: draw to canvas, OCR for text boxes */
  2363	async function loadImage(f,ext){
  2364	  let blob=f;
  2365	  if(ext==='heic'||ext==='heif'||f.type==='image/heic'||f.type==='image/heif'){
  2366	    setStatus(T().heicConv);
  2367	    await ensureHeic();
  2368	    blob=await window.heic2any({blob:f,toType:'image/png',quality:0.92});
  2369	    if(Array.isArray(blob)) blob=blob[0];
  2370	  }
  2371	  const url=URL.createObjectURL(blob);
  2372	  const img=await new Promise((res,rej)=>{const im=new Image();im.onload=()=>res(im);im.onerror=()=>rej(new Error('img'));im.src=url;});
  2373	  URL.revokeObjectURL(url);
  2374	  const maxDim=2400, iw=img.naturalWidth||img.width, ih=img.naturalHeight||img.height;
  2375	  const sc=Math.min(1, maxDim/Math.max(iw,ih));
  2376	  const cv=canvasEl(iw*sc, ih*sc);
  2377	  cv.getContext('2d',{willReadFrequently:true}).drawImage(img,0,0,cv.width,cv.height);
  2378	  setStatus(T().ocrStart);
  2379	  const items=await ocrCanvas(cv);
  2380	  pages=[{canvas:cv,w:cv.width,h:cv.height,ptW:cv.width*0.75,ptH:cv.height*0.75,items}];
  2381	  setProg(0);
  2382	}
  2383	
  2384	async function ocrCanvas(cv){
  2385	  const Te=await ensureTesseract();
  2386	  const { data } = await Te.recognize(cv, OCR_LANGS(), { logger:m=>{
  2387	    if(m.status && m.status.indexOf('recogniz')>=0){ setProg(0.1+m.progress*0.9); setStatus(T().ocrProg(Math.round(m.progress*100))); }
  2388	    else { setStatus(T().ocrStart); }
  2389	  }});
  2390	  const words=(data && data.words) ? data.words : [];
  2391	  // TRIM the word text. Tesseract sometimes returns a word with leading or
  2392	  // trailing whitespace, but its bbox is the INK box — the space has no pixels.
  2393	  // Keeping the space makes str.length one too many, and every character box is
  2394	  // derived by dividing the item width by that length, so the whole run shifts
  2395	  // right by one cell. Measured: " 99221010" on 資格確認書 left the first 9
  2396	  // uncovered by ~7px — a digit of a 保険者番号 surviving the band.
  2397	  return words.filter(w=>w.text && w.text.trim()).map(w=>({
  2398	    str:w.text.trim(), x:w.bbox.x0, y:w.bbox.y0, w:w.bbox.x1-w.bbox.x0, h:w.bbox.y1-w.bbox.y0
  2399	  }));
  2400	}
  2401	
  2402	/* Text (docx/txt/paste/sample) → rendered white pages with word boxes */
  2403	async function renderTextPages(text,name){
  2404	  try{ await document.fonts.ready; }catch(e){}
  2405	  text=(text||'').replace(/\r/g,'');
  2406	  const W=1240, pad=64, fs=24, LH=Math.round(fs*1.62), maxW=W-pad*2, pageH=Math.round(W*1.414);
  2407	  const meas=canvasEl(10,10).getContext('2d'); meas.font=fs+'px "IBM Plex Sans KR",sans-serif';
  2408	  const spaceW=meas.measureText(' ').width;
  2409	  pages=[];
  2410	  let cur=null, y=0;
    35	const LEVEL_TOKEN = { auto: 'auto', auto_with_purpose_gate: 'gate', recommend: 'recommend', optional: 'optional', keep: 'keep' };
    36	const AUTOMATIC = new Set(['auto', 'gate']);
    37	
    38	const problems = [];
    39	const fail = (what, msg) => problems.push(`${what}: ${msg}`);
    40	
    41	/* ── 1. the 정본 → a (doc, field, purpose) table ── */
    42	const M = JSON.parse(fs.readFileSync(MATRIX, 'utf8'));
    43	const PURPOSES = Object.keys(M.purposes);
    44	const matrix = {};            // doc → field → purpose → level
    45	const matrixFields = {};      // doc → Set(field)
    46	const matrixLegal = {};       // doc → Set(field) grounded in statute
    47	function applyRule(docId, rule, where) {
    48	  const token = LEVEL_TOKEN[rule.level];
    49	  if (!token) { fail(where, `unknown level "${rule.level}"`); return; }
    50	  if (!Array.isArray(rule.fields) || !rule.fields.length) { fail(where, 'rule has no `fields` (code field keys)'); return; }
    51	  if (rule.verified === false && AUTOMATIC.has(token))
    52	    fail(where, `verified:false but level "${rule.level}" is automatic — an unsourced rule may not delete pixels on its own`);
    53	  if (rule.legal_enforcement === true) {
    54	    if (rule.verified === false)
    55	      fail(where, 'verified:false but legal_enforcement:true — a rule whose citation we could not secure may not assert a statutory restriction');
    56	    matrixLegal[docId] = matrixLegal[docId] || new Set();
    57	    for (const f of rule.fields) matrixLegal[docId].add(f);
    58	  }
    59	  const seen = {};
    60	  const put = (purpose, level) => {
    61	    if (!PURPOSES.includes(purpose)) { fail(where, `unknown purpose "${purpose}"`); return; }
    62	    if (seen[purpose]) { fail(where, `purpose "${purpose}" appears twice (${seen[purpose]} and ${level})`); return; }
    63	    seen[purpose] = level;
    64	    for (const f of rule.fields) {
    65	      matrix[docId] = matrix[docId] || {};
    66	      matrix[docId][f] = matrix[docId][f] || {};
    67	      matrixFields[docId] = matrixFields[docId] || new Set();
    68	      matrixFields[docId].add(f);
    69	      const prev = matrix[docId][f][purpose];
    70	      if (prev && prev !== level) fail(`${docId}.${f}[${purpose}]`, `two rules disagree: ${prev} vs ${level}`);
    71	      matrix[docId][f][purpose] = level;
    72	    }
    73	  };
    74	  for (const p of (rule.must_keep_when || [])) put(p, 'keep');
    75	  for (const p of (rule.mask_when || [])) put(p, token);
    76	  for (const p of (rule.optional_when || [])) put(p, 'optional');
    77	}
    78	for (const doc of M.documents) for (const r of doc.rules) applyRule(doc.id, r, `${doc.id} 「${r.field}」`);
    79	// general_jp applies to every listed document.
    80	const G = M.general_jp || { applies_to: [], rules: [] };
    81	for (const docId of G.applies_to) for (const r of G.rules) applyRule(docId, r, `general_jp→${docId} 「${r.field}」`);
    82	
    83	/* ── 2. the code → JP_RULES + jpLevel ── */
    84	const src = fs.readFileSync(PAGE, 'utf8');
    85	function slice(startMarker, endMarker) {
    86	  const a = src.indexOf(startMarker);
    87	  if (a < 0) throw new Error(`cannot find ${startMarker} in ${PAGE}`);
    88	  const b = src.indexOf(endMarker, a);
    89	  if (b < 0) throw new Error(`cannot find ${endMarker} after ${startMarker}`);
    90	  return src.slice(a, b + endMarker.length);
    91	}
    92	// Everything from the purpose shorthands through the end of JP_RULES, then jpLevel.
    93	const rulesSrc = slice('const P_NOT_MYNUM =', '\n};\n');
    94	const levelSrc = slice('function jpLevel(', '\n}\n');
    95	const legalSrc = slice('const JP_LEGAL = {', '\n};\n');
    96	let JP_RULES, jpLevel, JP_LEGAL;
    97	try {
    98	  ({ JP_RULES, jpLevel, JP_LEGAL } =
    99	    new Function(`${rulesSrc}\n${levelSrc}\n${legalSrc}\nreturn {JP_RULES, jpLevel, JP_LEGAL};`)());
   100	} catch (e) {
   101	  console.error('could not evaluate JP_RULES / jpLevel out of index.html:', e.message);
   102	  process.exit(2);
   103	}
   104	
   105	/* ── 3. compare every triple in EITHER table ── */
   106	let compared = 0;
   107	const docs = new Set([...Object.keys(matrix), ...Object.keys(JP_RULES)]);
   108	for (const doc of docs) {
   109	  const mf = matrixFields[doc] || new Set();
   110	  const cf = new Set(Object.keys(JP_RULES[doc] || {}));
   111	  for (const f of cf) if (!mf.has(f)) fail(`${doc}.${f}`, 'in JP_RULES but not in the legal matrix');
   112	  for (const f of mf) if (!cf.has(f)) fail(`${doc}.${f}`, 'in the legal matrix but not in JP_RULES');
   113	  for (const f of new Set([...mf, ...cf])) {
   114	    for (const p of PURPOSES) {
   115	      const want = ((matrix[doc] || {})[f] || {})[p] || null;
   116	      const got = (JP_RULES[doc] && JP_RULES[doc][f]) ? jpLevel(doc, f, p) : null;
   117	      compared++;
   118	      if (want !== got) fail(`${doc}.${f}[${p}]`, `matrix says ${want || 'null (not offered)'}, code says ${got || 'null (not offered)'}`);
   119	    }
   120	  }
   121	}
   122	// A triple must have been checked. A comparison loop that silently ran zero
   123	// times prints the same green as one that checked two hundred.
   124	if (compared < 100) fail('coverage', `only ${compared} (doc, field, purpose) triples compared — the extraction is probably broken`);
   125	
   126	/* ── 6. the legal group IS what the matrix grounds in statute, per document ──
   127	   Set equality, not subset: a missing member silently drops a statutory band
   128	   back under the category checkboxes (the Codex 4-6 failure), and an extra one
   129	   asserts a restriction the matrix does not claim (the Codex 6b-10 failure). */
   130	let legalPairs = 0;
   131	for (const doc of new Set([...Object.keys(matrixLegal), ...Object.keys(JP_LEGAL)])) {
   132	  const want = matrixLegal[doc] || new Set();
   133	  const got = new Set(JP_LEGAL[doc] || []);
   134	  if (!JP_LEGAL[doc]) fail(`JP_LEGAL.${doc}`, 'document missing from JP_LEGAL (write [] if it has no statutory field)');
   135	  for (const f of got) if (!want.has(f)) fail(`JP_LEGAL.${doc}.${f}`, 'in the legal group but the matrix does not mark it legal_enforcement:true');
   136	  for (const f of want) if (!got.has(f)) fail(`JP_LEGAL.${doc}.${f}`, 'matrix says legal_enforcement:true but the code leaves it to the category checkboxes');
   137	  legalPairs += new Set([...want, ...got]).size;
   138	}
   139	// Same reason as `compared`: zero comparisons print the same green as many.
   140	if (legalPairs < 8) fail('coverage', `only ${legalPairs} legal (doc, field) pairs compared — the extraction is probably broken`);
   141	
   142	if (problems.length) {
   143	  console.log(`\n✗ legal matrix ↔ code: ${problems.length} disagreement(s) over ${compared} triples\n`);
   144	  for (const p of problems) console.log('   ' + p);
   145	  console.log('');
   146	  process.exit(1);
   147	}
   148	console.log(`✅ legal matrix ↔ code: ${compared} (doc, field, purpose) triples identical, ${legalPairs} legal pairs identical, verified:false⇒no-auto/no-legal holds`);
   205	      maskRectCount: window.__maskRects().length,
   206	      emptyShown: !!emptyEl && emptyEl.style.display !== 'none' && !!emptyEl.textContent.trim(),
   207	      mnBoxShown: (() => { const el = document.getElementById('jpMnWrap'); return !!el && el.style.display !== 'none'; })(),
   208	      mnLabel: (() => { const el = document.getElementById('jpMnLabel'); return el ? el.textContent.trim() : ''; })(),
   209	      pw: pages.map(p => p.w),
   210	      fields: entities.filter(e => e.jp).map(e => ({ field: e.jp.field, level: e.jp.level, note: e.jp.note, page: e.jp.page, doc: e.jp.doc, side: e.jp.side, kind: e.kind, mode: e.mode, legal: !!e.legal, on: isOn(e) })) };
   211	  };
   212	  // Field labels of every ACTIVE auto entity — the allowlist assertion's input.
   213	  window.__autoFields = function () {
   214	    return entities.filter(e => e.kind === 'auto').map(e => e.jp ? e.jp.field : '(regex:' + e.type + ')');
   215	  };
   216	  /* Turn every general category OFF. A legal-preset band must survive this.
   217	     catEnabled is module-level state that resetAll() and a fresh file load do
   218	     NOT restore, so this hands back a restore function — the first version of
   219	     this helper left every category off for the remaining 300 assertions and
   220	     turned 14 of them red. */
   221	  window.__catSnapshot = null;
   222	  window.__allCatsOff = function () {
   223	    window.__catSnapshot = { ...catEnabled };
   224	    for (const t of Object.keys(catEnabled)) catEnabled[t] = false;
   225	    renderAll();
   226	    return Object.keys(catEnabled).filter(t => catEnabled[t] !== false);
   227	  };
   228	  window.__restoreCats = function () {
   229	    if (!window.__catSnapshot) return false;
   230	    for (const t of Object.keys(window.__catSnapshot)) catEnabled[t] = window.__catSnapshot[t];
   231	    window.__catSnapshot = null; renderAll(); return true;
   232	  };
   233	  window.__setMnConfirm = function (v) { jpSetMnConfirmed(v); };
   234	  window.__isCandidateExact = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value) === n); };
   235	  window.__isCandidateContains = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value).includes(n)); };
   236	  // default mode of the candidate whose value contains v (null if not a candidate)
   237	  window.__candidateMode = function (v) { const n = norm(v); const e = entities.find(x => x.kind === 'candidate' && norm(x.value).includes(n)); return e ? e.mode : null; };
   238	  // name-bar geometry: glyph union (raw pdf items) vs drawn bar rect
   628	      rec(tag, 'JP_CLEAR', f, 'detected+clear', !bs.length ? 'MISSING' : (clear ? `detected+clear ×${bs.length}` : 'BANDED'), clear);
   629	    }
   630	    /* Legal-preset fields are not governed by the category checkboxes. Turn
   631	       every category off and require the band to still be there.
   632	       `catEnabled` is module state that neither resetAll() nor a fresh file load
   633	       restores, so an exception anywhere between the two calls below used to
   634	       leave EVERY category off for the remaining assertions — once already, 11
   635	       of the 14 reds it produced belonged to other documents. try/finally, and
   636	       the restore is itself asserted. */
   637	    for (const f of (c.require_legal || [])) {
   638	      try {
   639	        const left = await page.evaluate(() => window.__allCatsOff());
   640	        const bs = await page.evaluate(x => window.__fieldBands(x), f);
   641	        const ok = left.length === 0 && bs.length > 0 && bs.every(b => b.legal && b.on && b.mode !== 'ok' && b.inMask);
   642	        rec(tag, 'JP_LEGAL', f, 'survives all-categories-off',
   643	          left.length ? 'cats still on: ' + left.join(',') : !bs.length ? 'MISSING'
   644	            : bs.every(b => b.legal && b.on && b.mode !== 'ok' && b.inMask) ? `banded ×${bs.length}` : 'DROPPED', ok);
   645	      } finally {
   646	        // put the page back the way the rest of the case expects it — on the
   647	        // error path too, where the rest of the run is what is at stake.
   648	        const restored = await page.evaluate(() => window.__restoreCats());
   649	        const stillOff = await page.evaluate(() => Object.keys(catEnabled).filter(t => catEnabled[t] === false));
   650	        rec(tag, 'JP_LEGAL', f + ' (categories restored)', 'restored+none-off',
   651	          !restored ? 'NOT RESTORED' : stillOff.length ? 'STILL OFF: ' + stillOff.join(',') : 'restored',
   652	          restored && stillOff.length === 0);
   653	        await loadDoc(page, spec.doc, true);
   654	        await page.evaluate(p => jpSetPurpose(p), c.purpose);
   655	        if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
   656	      }
   657	    }
   658	    /* Which fields were automatically banded. Two strengths, because the

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "nl -ba public/safe/index.html | sed -n '1810,1964p;2020,2100p' && rg -n 'jpMnConfirm|jpWarnLowconf|jpWarnUnclassified|jpEmptyPurpose' public/safe/index.html | head -40 && sed -n '1,115p' test/safe/fixtures/jp/jp_legal_matrix_alpha4.json" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
  1810	        push(r.field, jpBoxes(seg, sp.a, sp.b), sp.digits, extra);
  1811	        consume(sp.a, sp.b);
  1812	        continue;
  1813	      }
  1814	      let a = -1, b = -1, val = '';
  1815	      if (r.addr){
  1816	        // 住所/本籍: bound the value by the address hierarchy rather than by
  1817	        // "everything after the label", so a second column that drifted into
  1818	        // this segment is not swept into the band.
  1819	        const sp = jpAddressSpan(seg.t.slice(0, tailEnd), L.end);
  1820	        if (sp && sp.b > sp.a){ a = sp.a; b = sp.b; val = seg.t.slice(a, b); }
  1821	      } else if (r.re){
  1822	        const m = r.re.exec(seg.t.slice(L.end, tailEnd));
  1823	        if (m){ a = L.end + m.index; b = a + m[0].length; val = m[0]; }
  1824	      }
  1825	      if (a < 0 && r.last !== true) continue;
  1826	      if (a < 0){
  1827	        // value position certain, characters not: the items after the label, up
  1828	        // to the next column's anchor — minus anything a keep-only field must
  1829	        // not claim (an item that is nothing but a 4+ digit run).
  1830	        const itemChars = o => { const a0 = seg.start[o.i]; const n = (jpNorm(o.it.str || '').t || '').length; return [a0, a0 + n]; };
  1831	        const after = seg.items.filter(o => {
  1832	          const [a0, b0] = itemChars(o);
  1833	          if (!(a0 >= L.end && a0 < tailEnd)) return false;
  1834	          if (b0 <= a0) return true;
  1835	          for (let k = a0; k < Math.min(b0, tailEnd); k++) if (!skip(k)) return true;
  1836	          return false;                       // every character of this item is an identifier we must not claim
  1837	        });
  1838	        if (!after.length) continue;
  1839	        const boxes = after.map(o => { const b2 = { page: pi, x:o.it.x, y:o.it.y, w:o.it.w, h:o.it.h }; b2.bg = sampleBg(pages[pi], b2); return b2; });
  1840	        let val = ''; for (let k = L.end; k < tailEnd; k++) if (!skip(k)) val += seg.t[k];
  1841	        push(r.field, boxes, val.trim() || '(value)');
  1842	        consume(L.end, tailEnd);
  1843	        continue;
  1844	      }
  1845	      push(r.field, jpBoxes(seg, a, b), val.trim());
  1846	      consume(a, b);
  1847	    }
  1848	  }
  1849	
  1850	  /* Structural fallback — ONLY where OCR has destroyed the label but the format
  1851	     plus the document class still pin the field down. Each is narrow and stated:
  1852	       資格確認書: a bare 6–10 digit run outside any date line is a member of the
  1853	         保険者番号・記号・番号・枝番 family. The 告知要求制限 covers that whole
  1854	         family as ONE rule, so the cost of guessing which member it is, is zero —
  1855	         while a miss is the exact leak the product exists to prevent. Measured:
  1856	         OCR renders 保険者番号 as "RREES"/"REEES"/"WREEES" on 3 of 5 fixtures.
  1857	       住民票: 12 digits = 個人番号, 11 digits = 住民票コード. Both lengths are
  1858	         fixed by statute and nothing else on the form is that long. */
  1859	  const isDateRow = s => JP_DATE_RE.test(s.rowText) || s.rowText.includes('〒');
  1860	  const unconsumed = (seg, a, b) => { for (let k=a;k<b;k++) if (seg.used[k]) return false; return true; };
  1861	  const runs = seg => { const out=[]; let st=-1;
  1862	    for (let k=0;k<=seg.t.length;k++){ const d = k<seg.t.length && isDigit(seg.t[k]);
  1863	      if (d){ if (st<0) st=k; } else if (st>=0){ out.push([st,k]); st=-1; } } return out; };
  1864	  if (cls.doc === 'shikaku_kakuninsho'){
  1865	    for (const seg of segs){
  1866	      if (isDateRow(seg)) continue;
  1867	      for (const [a,b] of runs(seg)){
  1868	        const len = b - a;
  1869	        if (len < 6 || len > 10 || !unconsumed(seg, a, b)) continue;
  1870	        push('hokensha_bango', jpBoxes(seg, a, b), seg.t.slice(a,b), { viaFallback: true });
  1871	        for (let k=a;k<b;k++) seg.used[k]=1;
  1872	      }
  1873	    }
  1874	  }
  1875	  if (cls.doc === 'juminhyo'){
  1876	    for (const seg of segs){
  1877	      if (isDateRow(seg)) continue;
  1878	      for (const [a,b] of runs(seg)){
  1879	        const len = b - a;
  1880	        if (!unconsumed(seg, a, b)) continue;
  1881	        if (len === 12) push('my_number', jpBoxes(seg, a, b), seg.t.slice(a,b), { checkOk: myNumberCheckOk(seg.t.slice(a,b)), viaFallback: true });
  1882	        else if (len === 11) push('jumin_code', jpBoxes(seg, a, b), seg.t.slice(a,b), { viaFallback: true });
  1883	        else continue;
  1884	        for (let k=a;k<b;k++) seg.used[k]=1;
  1885	      }
  1886	    }
  1887	  }
  1888	
  1889	  /* Unlabelled addresses. Anything a label already claimed is marked consumed,
  1890	     so this only sees text standing on its own — 備考欄 contents, free-form
  1891	     notes. Per strategy v2 §3-2 it is automatic ONLY with 郵便番号 AND 都道府県
  1892	     together; otherwise it is a review candidate. It is filed under its own
  1893	     field key so it can never be confused with the LABELLED 住所, which on all
  1894	     four alpha documents is a keep-field the recipient needs. */
  1895	  for (const seg of segs){
  1896	    let from = 0;
  1897	    for (let guard = 0; guard < 4; guard++){
  1898	      const sp = jpAddressSpan(seg.t, from);
  1899	      if (!sp || sp.b <= sp.a) break;
  1900	      from = sp.b;
  1901	      if (sp.score < 3) continue;
  1902	      let free = true; for (let k = sp.a; k < sp.b; k++) if (seg.used[k]) { free = false; break; }
  1903	      if (!free) continue;
  1904	      push('address_loose', jpBoxes(seg, sp.a, sp.b), seg.t.slice(sp.a, sp.b), { strong: sp.postal && sp.pref });
  1905	      for (let k = sp.a; k < sp.b; k++) seg.used[k] = 1;
  1906	    }
  1907	  }
  1908	
  1909	  // 欄 regions (備考欄 / 臓器提供意思表示欄): the drawn rectangle under the label.
  1910	  for (const rr of (JP_REGION_LABELS[cls.doc] || [])){
  1911	    for (const seg of segs){
  1912	      if (!jpFindLabel(seg, rr.labels, false)) continue;
  1913	      const fr = jpFrameBelow(pages[pi], { y: seg.y, h: seg.h });
  1914	      const box = fr ? { ...fr, page: pi }
  1915	                     : { page: pi, x: seg.x0, y: seg.y, w: Math.max(seg.x1-seg.x0, pages[pi].w*0.5), h: seg.h*3.5, region: true };
  1916	      push(rr.field, [box], rr.field);
  1917	      break;
  1918	    }
  1919	  }
  1920	
  1921	  // 二次元コード
  1922	  if (cls.doc === 'shikaku_kakuninsho' || (cls.doc === 'mynumber_card' && cls.side === 'back')){
  1923	    for (const cb of jpCodeBlocks(pi)) push('qr', [cb.box], '二次元コード', { unlabelledCode: !cb.labelled });
  1924	  }
  1925	
  1926	  // 住民票: household member blocks. Block 1 is the subject; blocks 2..n are
  1927	  // third parties whose data the recipient did not ask for. Found by the 氏名
  1928	  // label rows, because 続柄 (本人/妻/子) is a single kanji that OCR mangles far
  1929	  // more often than it mangles a whole label.
  1930	  if (cls.doc === 'juminhyo'){
  1931	    const nameRows = segs.filter(s => jpFindLabel(s, ['氏名'], false)).sort((a,b)=>a.y-b.y);
  1932	    const endRe = /住民票コード|この写し|相違|証明し|市長|区長|町長|村長|公印/;
  1933	    if (nameRows.length > 1){
  1934	      for (let i = 1; i < nameRows.length; i++){
  1935	        const top = nameRows[i].y;
  1936	        const next = i + 1 < nameRows.length ? nameRows[i+1].y : Infinity;
  1937	        const stop = segs.filter(s => s.y > top && s.y < next && endRe.test(s.rowText)).map(s=>s.y);
  1938	        const bottom = stop.length ? Math.min(...stop) : next;
  1939	        const byRow = {};
  1940	        for (const s of segs){
  1941	          if (s.y < top || s.y >= bottom) continue;
  1942	          (byRow[s.row] = byRow[s.row] || []).push(s);
  1943	        }
  1944	        for (const list of Object.values(byRow))
  1945	          push('setaiin', list.map(jpSegBox), (list[0].t || '(世帯員)').slice(0, 24));
  1946	      }
  1947	    }
  1948	    // 氏名/生年月日 inside a THIRD PARTY's block are not the subject's keep-fields.
  1949	    // Leaving them in would put the same pixels in the 残す項目 list and under a
  1950	    // band at the same time — the list would be telling the user the opposite of
  1951	    // what the page shows.
  1952	    const regions = found.filter(f => f.field === 'setaiin').flatMap(f => f.boxes);
  1953	    if (regions.length){
  1954	      const inside = b => regions.some(r => b.x + b.w/2 >= r.x && b.x + b.w/2 <= r.x + r.w
  1955	                                         && b.y + b.h/2 >= r.y && b.y + b.h/2 <= r.y + r.h);
  1956	      for (let i = found.length - 1; i >= 0; i--){
  1957	        const f = found[i];
  1958	        if (!['name','birth','address'].includes(f.field)) continue;
  1959	        if (f.boxes.every(inside)) found.splice(i, 1);
  1960	      }
  1961	    }
  1962	  }
  1963	  return found;
  1964	}
  2020	const JP_MN_GATED = new Set(['back_all','my_number','qr']);
  2021	function jpApply(){
  2022	  entities = entities.filter(e => !e.jp);
  2023	  const cls = jpState.cls; if (!cls) { jpRenderBar(); renderAll(); return; }
  2024	  const purpose = jpState.purpose;
  2025	  const add = (f, level, boxes, value, note, ctx) => {
  2026	    const kind = (level === 'auto' || level === 'gate') ? 'auto'
  2027	               : level === 'keep' ? 'keep' : 'candidate';
  2028	    const mode = (level === 'auto' || level === 'gate' || level === 'recommend') ? 'no' : 'ok';
  2029	    const doc = (ctx && ctx.doc) || cls.doc;
  2030	    // A legal-preset band is not governed by the general category checkboxes.
  2031	    const legal = jpIsLegal(doc, f) && mode === 'no';
  2032	    entities.push({ id:'j'+Math.random().toString(36).slice(2,8), type: JP_TYPE[f] || 'other',
  2033	      value, mode, kind, legal, reason: 'jp_' + level, boxes,
  2034	      jp: { doc, side: (ctx && ctx.side) || cls.side || null, page: ctx ? ctx.page : null, field: f, level, note: note || null } });
  2035	  };
  2036	  // Resolve the level for one finding under the current purpose, including the
  2037	  // two demotions and the confirmation gate. Returns null = not offered.
  2038	  const resolve = (doc, field, f) => {
  2039	    let level = jpLevel(doc, field, purpose), note = null;
  2040	    if (!level) return null;
  2041	    // Unconfirmed 個人番号手続: the matrix says keep, but the release has not
  2042	    // been confirmed, so the 番号法 band stays as if the purpose were 本人確認.
  2043	    if (level === 'keep' && JP_MN_GATED.has(field) && purpose === 'my_number_procedure' && !jpState.mnConfirmed){
  2044	      level = 'gate'; note = 'mn_unconfirmed';
  2045	    }
  2046	    // A low-confidence classification may not delete pixels on its own.
  2047	    if (f && f.low && (level === 'auto' || level === 'gate')){ level = 'recommend'; note = 'lowconf'; }
  2048	    if (!f) return { level, note };
  2049	    // 個人番号 whose check digit does not verify is NOT confirmed to be a
  2050	    // 個人番号 — it could be any 12-digit reference. Demote the automatic band
  2051	    // to a review candidate (still default-ON) rather than assert something the
  2052	    // arithmetic contradicts.
  2053	    if (field === 'my_number' && (level === 'auto' || level === 'gate') && f.checkOk === false){ level = 'recommend'; note = 'checkdigit'; }
  2054	    // An unlabelled square block has no QR-specific evidence behind it (no
  2055	    // finder pattern, no quiet zone, no module pitch) and no golden coverage —
  2056	    // a face photo, a round seal (bbox fill ≈ 0.785) or a black table header
  2057	    // can all satisfy the size/ratio/fill test. It is OFFERED and left OFF:
  2058	    // a guess must not remove content from the default output (Codex 2-2, 6-1).
  2059	    if (f.unlabelledCode){ level = 'optional'; note = 'unlabelled_code'; }
  2060	    return { level, note };
  2061	  };
  2062	
  2063	  // マイナンバーカード裏面 under a 本人確認 purpose: the whole face, PER PAGE that
  2064	  // is actually a back face. 番号法 does not let the recipient hold the 個人番号
  2065	  // at all for identity checking, so the honest instruction is "submit the front
  2066	  // instead", and the band says so.
  2067	  for (let pi = 0; pi < pages.length; pi++){
  2068	    const pc = jpState.pageCls[pi];
  2069	    if (!pc || pc.doc !== 'mynumber_card' || pc.side !== 'back') continue;
  2070	    const r = resolve('mynumber_card', 'back_all', { low: pc.low });
  2071	    if (r && (r.level === 'auto' || r.level === 'gate' || r.level === 'recommend'))
  2072	      add('back_all', r.level, [{ page: pi, x: 0, y: 0, w: pages[pi].w, h: pages[pi].h, region: true }],
  2073	          jpFieldLabel('back_all'), r.note, { doc: pc.doc, side: pc.side, page: pi });
  2074	  }
  2075	  for (const f of jpState.findings){
  2076	    const r = resolve(f.doc, f.field, f);
  2077	    if (!r) continue;
  2078	    add(f.field, r.level, f.boxes, f.field === 'qr' || f.boxes.some(b=>b.region) ? jpFieldLabel(f.field) : (f.value || jpFieldLabel(f.field)),
  2079	        r.note, { doc: f.doc, side: f.side, page: f.pi });
  2080	  }
  2081	  entities.sort((a,b)=>Object.keys(TYPES).indexOf(a.type)-Object.keys(TYPES).indexOf(b.type));
  2082	  jpRenderBar();
  2083	  renderAll();
  2084	}
  2085	const JP_TYPE = { address_loose:'address', tel:'phone', my_number:'rrn', jumin_code:'rrn', hokensha_bango:'health', kigo:'health',
  2086	  bango:'health', edaban:'health', hihokensha_bango:'health', license_no:'license', qr:'other',
  2087	  back_all:'other', biko_change:'address', organ_donor:'health', setaiin:'name', honseki:'address',
  2088	  hittosha:'name', sex:'other', name:'name', birth:'birth', address:'address', expiry:'other', issue:'other' };
  2089	
  2090	function jpSetPurpose(p){
  2091	  if (!JP_PURPOSES.includes(p)) return;
  2092	  jpState.purpose = p;
  2093	  // Switching purpose always re-asks for the 個人番号 confirmation. A checkbox
  2094	  // left ticked from a previous purpose is not a confirmation of this one.
  2095	  jpState.mnConfirmed = false;
  2096	  const sel = $('jpPurpose'); if (sel) sel.value = p;
  2097	  jpApply();
  2098	}
  2099	function jpSetMnConfirmed(v){ jpState.mnConfirmed = !!v; jpApply(); }
  2100	function jpRenderBar(){
379:              <input type="checkbox" id="jpMnConfirm">
568:  jpPurposeLabel:'제출 목적', jpBackNotice:'신원확인이 목적이라면 앞면만 제출하세요. 번호법상 법령이 인정한 사무 외의 목적으로 個人番号를 복사·보관하는 것은 제한될 수 있습니다. 「個人番号 절차」는 제출처 안내문이 個人番号(뒷면) 제출을 명시적으로 요구하는 경우에만 선택하세요.', jpKeepWarn:'제출처가 요구하는 항목입니다. 가리면 접수되지 않을 수 있습니다.', jpWarnUnclassified:'문서 종류를 특정하지 못해 자동 마스킹을 적용하지 않았습니다. 가릴 영역을 직접 선택하세요.', jpWarnLowconf:'문서 종류의 확신도가 낮아 후보 항목에 기본값으로 띠를 적용했습니다. 반드시 확인하세요.', jpEmptyPurpose:'이 문서에서 찾은 항목에는 이 목적에 적용되는 규칙이 없습니다. 가릴 영역을 직접 선택하세요.', jpMnConfirm:'제출처 안내문에서 個人番号(뒷면) 제출을 명시적으로 요구하는 것을 확인했습니다. 요구가 없으면 해제하지 마세요.', jpLegalSection:'법령·제출처 규칙 (法令・提出先ルール)', jpLegalWarn:'법령에 근거가 있는 항목입니다. 해제하면 법령상 수집·보관이 제한될 수 있는 정보가 그대로 나갑니다.', keepSection:'남겨야 하는 항목',
625:  jpPurposeLabel:'Purpose of submission', jpBackNotice:'If identity is what needs checking, submit the front face only. Under the My Number Act, copying or keeping a My Number for anything other than a task the law recognises may be restricted. Choose “My Number procedure” only when the recipient’s own instructions explicitly ask for the My Number (back face).', jpKeepWarn:'The recipient asks for this field. Hiding it may get your submission rejected.', jpWarnUnclassified:'The document type could not be identified, so no automatic redaction was applied. Please select the areas to cover by hand.', jpWarnLowconf:'Confidence in the document type is low, so candidate bands were applied by default. Please check them.', jpEmptyPurpose:'None of the fields found in this document has a rule for this purpose. Select the areas to cover by hand.', jpMnConfirm:'I have checked that the recipient’s instructions explicitly ask for the My Number (back face). Do not release this if they do not.', jpLegalSection:'Statutory / recipient rules', jpLegalWarn:'This band has a legal basis. Releasing it sends data whose collection or retention may be restricted by law.', keepSection:'Fields to keep visible',
682:  jpPurposeLabel:'提出目的', jpBackNotice:'身元確認が目的なら表面のみ提出してください。番号法上、法令で認められた事務以外で個人番号を複写・保管することは制限される場合があります。「個人番号手続」は、提出先の案内で個人番号（裏面）の提出が明示的に求められている場合にのみ選んでください。', jpKeepWarn:'提出先が受付できない可能性があります（本人特定事項）。', jpWarnUnclassified:'文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。', jpWarnLowconf:'文書の種類の確信度が低いため、候補の黒塗りを既定で適用しました。必ず確認してください。', jpEmptyPurpose:'この文書で検出した項目には、この目的に適用されるルールがありません。手動で範囲を選択してください。', jpMnConfirm:'提出先の案内で、個人番号（裏面）の提出が明示的に求められていることを確認しました。求められていない場合は解除しないでください。', jpLegalSection:'法令・提出先ルール', jpLegalWarn:'法令に根拠がある項目です。解除すると、法令上、収集・保管が制限される場合がある情報がそのまま出力されます。', keepSection:'残す項目',
739:  jpPurposeLabel:'Finalidad del envío', jpBackNotice:'Si lo que hay que verificar es la identidad, envía solo el anverso. La Ley My Number puede restringir copiar o conservar un My Number para fines distintos de los trámites reconocidos por la ley. Elige «Trámite de My Number» solo si las instrucciones del destinatario piden expresamente el My Number (reverso).', jpKeepWarn:'El destinatario pide este dato. Ocultarlo puede provocar el rechazo del envío.', jpWarnUnclassified:'No se ha podido identificar el tipo de documento, por lo que no se aplicó ningún tachado automático. Selecciona a mano las zonas que quieras cubrir.', jpWarnLowconf:'La confianza en el tipo de documento es baja, así que se aplicaron bandas de candidatos por defecto. Compruébalas.', jpEmptyPurpose:'Ninguno de los campos encontrados en este documento tiene una regla para esta finalidad. Selecciona a mano las zonas que quieras cubrir.', jpMnConfirm:'He comprobado que las instrucciones del destinatario piden expresamente el My Number (reverso). No lo liberes si no lo piden.', jpLegalSection:'Reglas legales / del destinatario', jpLegalWarn:'Esta banda tiene base legal. Al liberarla envías datos cuya recogida o conservación puede estar restringida por ley.', keepSection:'Campos que deben quedar visibles',
2114:    warn.textContent = !show ? '' : low ? T().jpWarnLowconf : T().jpWarnUnclassified;
2132:  const cw = $('jpMnWrap'), cb = $('jpMnConfirm');
2137:    const lb = $('jpMnLabel'); if (lb) lb.textContent = T().jpMnConfirm;
2148:    empty.textContent = none ? T().jpEmptyPurpose : '';
2815:$('jpMnConfirm').addEventListener('change',e=>jpSetMnConfirmed(e.target.checked));
{
  "version": "2026-10-21b",
  "scope": "SafeFile JP 알파 4종. 규칙은 제출 목적(purpose)별. 출처 없는 규칙은 verified=false로 표기하고 자동 마스킹 금지.",
  "_schema": {
    "rule": "{field: 사람이 읽는 필드명, fields: [코드 필드 키], mask_when: [purpose], must_keep_when: [purpose], optional_when: [purpose], level, legal_basis, source, verified}",
    "derivation": "(doc, code field, purpose) → level: purpose ∈ must_keep_when → keep · purpose ∈ mask_when → level 토큰 · purpose ∈ optional_when → optional · 그 외 → null(UI에 내지 않음). 한 purpose가 두 목록에 동시에 들어가면 오류다.",
    "level_tokens": "auto → auto · auto_with_purpose_gate → gate · recommend → recommend · optional → optional · keep → keep",
    "invariant": "verified=false 인 규칙은 auto·gate 를 가질 수 없다. 출처 없는 판단이 스스로 픽셀을 지우면 안 된다. test/safe/check_matrix.mjs 가 이 표와 public/safe/index.html 의 JP_RULES 를 (doc, field, purpose) 전수 대조하고 이 불변식을 강제한다.",
    "optional_when_basis": "optional 은 「既定OFF・選択可」 — 법적 주장이 아니라 UI 제공이다. 제출 목적이 그 항목을 요구하지 않는 조합(특히 相談用共有)에서 사용자가 자기 정보를 가릴 수단을 잃지 않도록 명시한다. 출처가 없으므로 자동이 될 수 없다.",
    "legal_enforcement": "true 인 규칙만 UI 의 「法令・提出先ルール」 그룹에 들어간다. 그 그룹의 항목은 카테고리 체크박스로 사라지지 않고, 해제하면 「法令上、収集・保管が制限される場合があります」 를 말한다. 그러므로 verified=false 인 규칙에는 허용되지 않는다 — 출처를 확보하지 못했다고 스스로 적은 규칙이 법령 제한을 단정할 수는 없다. (住民票コード 가 그 경우다: 既定ON·解除可 인 일반 「要確認」 항목으로 둔다.) 속성이 없으면 false. test/safe/check_matrix.mjs 가 이 속성에서 문서별 집합을 파생해 public/safe/index.html 의 JP_LEGAL 과 집합 동등성을 대조하고, verified=false 에 붙는 것을 금지한다."
  },
  "purposes": {
    "identity_submit": "本人確認書類として提出（銀行・カード・通信・フリマ・賃貸）",
    "my_number_procedure": "個人番号関係事務（税・社会保障・勤務先提出）",
    "bid_attachment": "入札・許可申請への添付",
    "consult_share": "専門家・SNS等への相談用共有"
  },
  "documents": [
    {
      "id": "shikaku_kakuninsho", "name": "資格確認書", "replaces": "健康保険証（2025-12-01 失効・暫定2026-07-31終了）",
      "variants": ["被用者保険(協会けんぽ・健保組合)", "国民健康保険", "後期高齢者医療"],
      "fields_common": ["氏名", "生年月日", "性別", "住所", "資格取得年月日", "有効期限", "保険者番号", "保険者名", "記号/番号/枝番 または 被保険者番号"],
      "fields_issuer_specific": ["事業所名称", "二次元コード", "一部負担金割合", "自己負担限度額区分"],
      "rules": [
        {"field": "保険者番号・記号・番号・枝番・被保険者番号",
         "fields": ["hokensha_bango", "kigo", "bango", "edaban", "hihokensha_bango"],
         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": [], "level": "auto",
         "legal_basis": "健康保険法等 告知要求制限（2020-10-01施行）: 医療保険事務以外の目的での告知要求を原則禁止。提出先が受領する場合もマスキングを求める運用。my_number_procedure は明示しない（医療保険関係事務で番号が必要な例外の有無が確認不可） → null",
         "source": ["https://www.mhlw.go.jp/stf/newpage_13989.html", "https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf", "https://www.kyosai.metro.tokyo.jp/assets/84b47fd406a8378372a6015863f83bc93c0c8a75.pdf"], "verified": true, "legal_enforcement": true},
        {"field": "二次元コード", "fields": ["qr"],
         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "level": "auto",
         "legal_basis": "番号を判読可能なため同一扱い（大阪府・千葉市運用）。制限の根拠は運用通知そのものではなく、その通知が実施している 告知要求制限 — 機械可読な複製も番号の告知に当たるため同じ制限が及ぶ → legal_enforcement", "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"], "verified": true, "legal_enforcement": true},
        {"field": "性別", "fields": ["sex"], "mask_when": ["identity_submit"], "level": "recommend",
         "legal_basis": "法定ではない。民間KYC事業者の運用（SoftBank, PayPay銀行等）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
        {"field": "氏名・生年月日・住所・有効期限", "fields": ["name", "birth", "address", "expiry"],
         "mask_when": [], "must_keep_when": ["identity_submit", "bid_attachment"], "optional_when": ["consult_share"], "level": "keep",
         "legal_basis": "本人特定事項。マスキングすると受付不可。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）",
         "source": ["https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html"], "verified": true},
        {"field": "事業所名称・保険者名・資格取得年月日", "fields": ["jigyosho", "hokensha_name", "shikaku_date"],
         "mask_when": [], "must_keep_when": ["identity_submit", "bid_attachment"], "optional_when": ["consult_share"], "level": "keep",
         "legal_basis": "資格の有効性を提出先が照合する欄という運用判断。法定の must-keep ではなく出典もない（警告のみで、自動マスキング対象には決してしない）",
         "source": [], "verified": false}
      ]
    },
    {
      "id": "unten_menkyo", "name": "運転免許証", "sides": ["表", "裏"],
      "fields_front": ["氏名", "生年月日", "住所", "交付日", "有効期限", "免許の条件", "番号(12桁)", "種類・取得日", "顔写真", "公安委員会名"],
      "fields_back": ["備考欄（住所・氏名等の変更記載）", "臓器提供意思表示欄"],
      "note": "本籍は券面に印字されない（ICチップ内）",
      "rules": [
        {"field": "裏面 備考欄（変更記載）", "fields": ["biko_change"],
         "mask_when": ["identity_submit", "consult_share"], "level": "recommend",
         "legal_basis": "旧住所等の不要情報。提出先指示優先（住所変更確認で裏面が必要な場合あり）", "source": ["https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true},
        {"field": "臓器提供意思表示欄", "fields": ["organ_donor"],
         "mask_when": ["identity_submit", "consult_share"], "level": "recommend",
         "legal_basis": "民間KYC運用（SoftBank: 臓器提供意思をマスキング）", "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
        {"field": "番号(12桁)", "fields": ["license_no"],
         "mask_when": ["consult_share"], "must_keep_when": ["identity_submit"], "level": "optional",
         "legal_basis": "個人識別符号（個人情報保護法施行令）。KYCでは照合に必要な提出先が多い → 本人確認提出では must-keep、相談用共有では既定OFFで選択可",
         "source": [], "verified": false},
        {"field": "氏名・生年月日・住所・有効期限・顔写真", "fields": ["name", "birth", "address", "expiry"],
         "must_keep_when": ["identity_submit"], "optional_when": ["consult_share"], "level": "keep",
         "legal_basis": "本人特定事項。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）。顔写真は検出規則がないため fields に含まない",
         "verified": true, "source": ["https://www.paypay-bank.co.jp/cardloan/confirm/identity_03.html"]}
      ]
    },
    {
      "id": "mynumber_card", "name": "マイナンバーカード（個人番号カード）", "sides": ["表", "裏"],
      "fields_front": ["氏名", "住所", "生年月日", "性別", "有効期限", "顔写真", "券面記載事項追記欄", "臓器提供意思表示欄"],
      "fields_back": ["個人番号", "氏名", "生年月日(要確認)", "二次元コード"],
      "unverified": ["裏面の生年月日印字有無"],
      "rules": [
        {"field": "裏面全体", "fields": ["back_all", "my_number", "qr"],
         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": ["my_number_procedure"], "level": "auto_with_purpose_gate",
         "legal_basis": "番号法: 法令で認められた者・目的以外での個人番号の収集・保管禁止。身元確認目的では裏面を提出しない。コード上は 裏面全体(back_all) / 個人番号(my_number) / 二次元コード(qr) の3キーに分解する（面全体の띠 + 番号そのもの + コード）が、規則はこの1条である",
         "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/", "https://www.pref.aichi.jp/uploaded/attachment/364666.pdf"], "verified": true, "legal_enforcement": true,
         "gate_requires_confirmation": "my_number_procedure への解除は目的ドロップダウンだけでは足りない。確認（チェックボックス1つ）を要求する。確認の文言は利用者が実際に確かめられる事実でなければならない — 「提出先が法定の個人番号関係事務を行う」は受領者の法的地位の判定であって利用者には確かめられない。代わりに 「提出先の案内で個人番号（裏面）の提出が明示的に求められていることを確認した」 を問い、求められていなければ解除しないよう添える。PPC FAQ は「意図せず見た」と「複写・記録」を区別するが、どちらも提出先の適法性を前提にしており、FAQ 自体はチェックボックスのような利用者確認を適法性の証明手段として示していない（Codex 6b-11）"},
        {"field": "表面 性別・臓器提供意思表示欄", "fields": ["sex", "organ_donor"],
         "mask_when": ["identity_submit"], "level": "recommend", "legal_basis": "民間KYC運用", "source": ["https://www.aspicjapan.org/asu/article/6908"], "verified": true},
        {"field": "表面 氏名・住所・生年月日・有効期限・顔写真", "fields": ["name", "birth", "address", "expiry"],
         "must_keep_when": ["identity_submit", "my_number_procedure"], "optional_when": ["consult_share"], "level": "keep",
         "legal_basis": "本人特定事項。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）。顔写真は検出規則がないため fields に含まない",
         "verified": true, "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"]}
      ]
    },
    {
      "id": "juminhyo", "name": "住民票の写し",
      "variants": ["世帯全員/一部", "個人番号 あり/なし", "本籍・筆頭者 あり/なし", "外国人住民（国籍・在留資格・在留期間・在留カード番号）", "住民票コード付（窓口のみ）"],
      "rules": [
        {"field": "個人番号", "fields": ["my_number"],
         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "must_keep_when": ["my_number_procedure"], "level": "auto_with_purpose_gate",
         "legal_basis": "番号法 収集制限。本人確認目的なら個人番号なしの住民票を取り直すのが原則", "source": ["https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"], "verified": true, "legal_enforcement": true,
         "gate_requires_confirmation": "mynumber_card 裏面全体と同じ確認を要求する"},
        {"field": "住民票コード", "fields": ["jumin_code"],
         "mask_when": ["identity_submit", "bid_attachment", "consult_share"], "level": "recommend",
         "legal_basis": "住民基本台帳法 利用制限（個人識別符号）と理解しているが条文・運用の出典を確保できていない → verified=false。既定ON で帯を引くが『自動（auto）』とは呼ばない。legal_enforcement も付けない — 出典を確保できていないと自ら書いた規則が「提出先は保管できない」と断定することはできない。一般の「要確認」項目としてカテゴリ制御下に置く（Codex 6b-10）",
         "source": [], "verified": false},
        {"field": "本籍・筆頭者", "fields": ["honseki", "hittosha"],
         "mask_when": ["identity_submit", "consult_share"], "optional_when": ["my_number_procedure", "bid_attachment"], "level": "recommend",
         "legal_basis": "民間KYC運用（SoftBank: 住民票の本籍をマスキング）。個人番号手続・入札添付で不要という出典はないため既定ONにはしない（既定OFFで選択可）",
         "source": ["https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"], "verified": true},
        {"field": "本人以外の世帯員", "fields": ["setaiin"],
         "mask_when": ["identity_submit", "consult_share"], "optional_when": ["my_number_procedure", "bid_attachment"], "level": "recommend",
         "legal_basis": "第三者情報。提出先が世帯全員を要求する場合は維持", "source": [], "verified": false},
        {"field": "氏名・生年月日・住所・発行日・発行者", "fields": ["name", "birth", "address", "issuer"],
         "must_keep_when": ["identity_submit", "bid_attachment"], "optional_when": ["consult_share"], "level": "keep",
         "legal_basis": "本人特定事項と証明書の成立要件。相談用共有は提出先要件がないため既定OFFで選択可（出典なし・自動不可）。⚠ 既知の空白: 発行日 も 発行者(issuer) も検出規則がない — ラベルを持たない行（「見本市長 架空 太郎（公印省略）」）なので、ラベル錨ではなく 市長|区長|町長|村長 のヒューリスティックが要る。この keep 規則は現状 警告を生成できない（s3b 백로그 B-15）",
         "verified": true, "source": ["https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"]}
      ]
    }
  ],
  "general_jp": {
    "_why": "문서 종류와 무관하게 네 문서 전부에 적용되는 두 규칙. 어느 문서도 증명해야 하는 내용이 아니므로 항상 제공(optional)하고, 공유의 목적이 상담일 때만 기본 ON(recommend). 법적 출처가 없으므로 recommend 이하만 — auto·gate 는 금지된다.",
    "applies_to": ["shikaku_kakuninsho", "unten_menkyo", "mynumber_card", "juminhyo"],
    "rules": [

hook: PostToolUse
hook: PostToolUse Completed
codex
정적 검토에서 두 가지 쟁점이 남았습니다. A-1의 구현은 요구된 두 조건을 문자 그대로 만족하지만, `二次元コード`처럼 카드 고유성이 없는 단일 문자열도 “입증”으로 취급해 전면 마스킹까지 연결합니다. A-4의 資格確認書 QR 법적 승격은 코드만으로 판단할 수 없으므로, 정본에 적힌 후생노동성·지자체 원문이 QR 자체를 제한 대상으로 명시하는지 공식 출처만 확인하겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
web search: 
web search: https://www.mhlw.go.jp/stf/newpage_13989.html
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'node test/safe/check_matrix.mjs' in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
✅ legal matrix ↔ code: 188 (doc, field, purpose) triples identical, 10 legal pairs identical, verified:false⇒no-auto/no-legal holds

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'node run.mjs' in /Users/sunghoon/Projects/docpack/test/safe
 exited 1 in 280ms:
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
codex
정본 대조기는 직접 재현되어 `188 triple + 10 legal pair`, exit 0입니다. Chrome 하네스는 예상된 샌드박스 제한(`listen EPERM 127.0.0.1`)으로 실행되지 않아, 그 부분은 정적 검토로 명시하겠습니다. 공식 후생노동성 설명은 “QR을 읽어 대상 기호·번호를 알 수 있으면 동일하게 마스킹 필요”라고 직접 규정하므로, 資格確認書 QR의 법령 그룹 편입은 출처 없는 추론으로 보이지 않습니다.
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "sed -n '248,292p' docs/jp/s3c_report.md && sed -n '292,380p' docs/jp/s3c_report.md && git status --short && git diff --stat && rg -n 'jp_tail|保険者名|99221010|OCR.*壊|expect_empty_notice|expect_jp_entities|jp_warn|jp_unlabelled_block' test/safe/run.mjs test/safe/specs.json" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
조건은 **「현재 목적에서 JP 엔티티가 0개」**다. `JP_RULES` 기준의 「규칙 0개」는 `JP_EXTRA`
(`address_loose`·`tel`)가 네 목적 전부를 덮으므로 **영원히 참이 되지 않는다** — 사용자가 보는
증상은 「목록이 비었다」이므로 그쪽을 조건으로 삼았다. **문구와 조건의 어긋남 여부는
교차검증 질문 ⑤로 올렸다.**

> 이것은 **발견 6 의 완화이지 해결이 아니다.** 「미명시 조합을 `null` 로 버리는 대신
> 『탐지됨·정책 미확정·기본 OFF』로 노출할 것인가」는 제품 결정이고 §5 백로그 B-6 이다.

---

## 3. 변이 프로브 — 새 단언이 공허하지 않음을 전부 실측

전부 `public/safe/index.html` 또는 `test/safe/run.mjs` 를 되돌려 **결함을 되살린 뒤** 측정했다.

| # | 되살린 결함 | 결과 |
|---|---|---|
| P-1 | `JP_SUSPECT_RE` 에 `令和\|平成\|昭和` 복원 **+** `lowconf` 가 `jpWarnUnclassified` 를 쓰게 | **2 실패** — `JP_WARN_TEXT`(lowconf 배너가 「自動黒塗りは適用していません」를 말한다) · `JP_WARN`(和暦만 있는 이력서에 `unclassified` 경고) |
| P-2 | `pageCls.push(pi === 0 ? cls0 : (jpClassify(pi) \|\| cls0))` 복원 | **5 실패** — 무관 첨부가 `mynumber_card/front` 로 통치됨 · 크롭된 **진짜 裏面**은 `front` 로 오분류돼 **띠가 아예 없음**(피복 2%). 옛 코드는 **양방향으로** 틀렸다 |
| P-3 | `jpTailEnd(...)` → `seg.t.length` (경계 제거) + ② 비활성 | **2 실패** — `hokensha_bango` **MISSING**, `99221010` **NOT masked** |
| P-4 | ②만 비활성 (`skip = () => false`), 경계는 유지 | **2 실패** — 레이블이 깨진 케이스에서 `hokensha_bango` MISSING. **①만으로는 닫히지 않음을 확인** (①만 있으면 케이스 1은 통과, 케이스 2는 실패) |
| P-5 | `JP_LEGAL.juminhyo` 에 `jumin_code` 복원 | `check_matrix` **exit 1** — 「in the legal group but the matrix does not mark it legal_enforcement:true」 |
| P-6 | `unlabelledCode: true` 강제 (레이블 QR 탐지 제거) | **1 실패** — `NO LABELLED CODE FOUND`. 참고: 옛 형태 `[].every(...)` 는 node 에서 **`true`** (실측) |
| P-7 | `require_legal` 단언 본문에 예외 주입 (`try/finally` 는 유지) | **8 LOAD 에러로 격리**, 나머지 **398 단언 전부 녹색**, 복원 행 8/8 `restored` |

---

## 4. 검증

| 검증 | 결과 |
|---|---|
| `node test/safe/check_matrix.mjs` | **188 triple + 10 legal pair 일치**, exit 0 |
| `cd test/safe && node run.mjs` | **533/533 pass, 0 FAIL**, exit 0 (직전 484/484) |
| 신규 케이스 | `jp/2page` ×2 · `(jp synth)` ×2 · `(jp warn)` ×2 + 기존 3개 확장 · `kenpo.png [my_number_procedure]` ×1 |
| 변이 프로브 | **7/7 실측** (§3) |
| SW 하네스 (`test/sw/offline_resilience.mjs`) | 미변경 — SW·미들웨어 파일 손대지 않음 |
| 프로덕션 DB | **미접촉** |
| 배포 | **하지 않음** |

콘솔 경고 1건은 기존과 동일(`Failed to update a ServiceWorker … script ('Unknown'): Not found`) —
하네스가 `public/` 을 임시 포트로 서빙하면서 생기는 것이고 페이지 동작과 무관하다.

---

## 5. 백로그 — S3b 발견 중 이번 범위가 아닌 것


**이 절의 항목은 전부 「다음 런」이다. 교차검증에서 AMBER 로 올리지 말 것.**

### 이번 라운드가 만든 것

| # | 항목 | 내용 |
|---|---|---|
| C-1 | **裏面 승격 조건의 좁힘** | 승격은 앵커 + 직전 페이지 side 만 본다. 페이지 크기·비율·연속성(같은 스캔 세션인지)은 보지 않는다. 승격된 페이지는 전면 띠를 받는다 |
| C-2 | **page 0 이 분류 불가면 전 페이지 JP OFF** | `jpScan` 은 `cls0` 가 없으면 즉시 반환한다. 표지 다음 장에 카드가 오는 PDF 가 그 모양이다. S3b 이전부터 있던 동작이고 이번에 바꾸지 않았다 |
| C-3 | **A-3 ② 의 과잉 마스킹 경로** | keep 필드 자기 값의 4자리 이상 숫자 런이 資格確認書 폴백에 잡힐 수 있다 (§2-A3 의 교환). 골든 커버리지 없음 |

### S3b 발견 (번호는 원문 기준)

| 발견 | 요지 | 왜 이번이 아닌가 |
|---|---|---|
| 4 | 목적 변경 시 30페이지 `renderAll()` 의 p50/p95 미계측 | 성능 계측은 30페이지 픽스처가 먼저 필요하다. 「확인 불가」가 정확한 현재 상태 |
| **6** | 미명시 조합을 `null` 로 **숨기는** 정책 — 「탐지됨·정책 미확정·기본 OFF」로 노출할 것인가 | **제품 결정.** 이번에는 안내만 띄웠다(§2-B4). 자동 마스킹 여부와 UI 노출 여부를 한 level 값에서 분리하는 것은 매트릭스 스키마 변경이다 |
| **7** | 출처 없는 `must_keep`(`事業所名称·保険者名·資格取得年月日`)의 **정본 승격** | 「제출처 확인 필요」라는 **제3의 상태**가 필요하다 — `keep` 도 `optional` 도 아닌 레벨 토큰 추가. 매트릭스·`jpLevel`·UI 그룹·대조기가 함께 바뀐다 |
| 8 | `check_matrix` 가 사람이 읽는 `field` 문자열을 무시 → `発行日` 누락을 영구히 못 본다. `issuer` 는 탐지 규칙도 없다 | 각 코드 키에 **detector 존재 또는 의도적 `undetectable` 선언**을 요구하는 검사가 필요하다. s3b 백로그 B-15 와 같은 항목 |
| 9 | 대조기의 **문자열 슬라이스**가 포맷에 취약, `compared < 100` 은 완전성 경계가 아니다 | 정본을 실제 JS 모듈/JSON 산출물로 공유하거나 AST 추출로 바꾸는 작업. 예상 문서 ID·목적 수·필드 집합·정확한 triple 수를 고정해야 한다 |
| 13 | `__fieldBands.inMask` 가 `on && mode!=='ok' && located` 뒤에서는 **동어반복** | 실제 preview/output **캔버스 픽셀**을 보거나 독립적인 fixture box 와 중첩을 재야 한다. 지금 단언은 중복이라고 기록 |
| 15 | `__inkCover` 임계값(대비 60 · 6px 미만 제거 · 99%)이 **픽스처 맞춤값** | 저대비·작은 글꼴·JPEG artifact 변이와 **OCR 재판독**이 필요하다. 성분 0 실패 방향은 유지 |
| 17 | 합성 테스트는 **정책 배선**만 증명 (OCR 강건성 아님) | 이번 신규 합성 케이스에도 그 한계를 **명시**했다. 저해상도·회전·서로 다른 앞뒷면 조건의 고정 PDF 픽스처는 별도 작업 |
| 19 | 개별 공개한 `legal` 항목이 그룹·카운트에 남는데 **UI 가 이유를 설명하지 않는다** | 그룹 제목을 상태와 분리하고(「법적 근거가 있는 검토 항목」) 카테고리 토글 옆에 개별 제어임을 적는 UI 작업 |
| 20 | `legal` 을 `mode==='no'` 로 제한해, 같은 `qr` 가 **레이블 인식 여부로** 법적 그룹과 일반 후보 사이를 이동 | 「법적 규칙」과 「탐지 신뢰도」를 **별도 속성**으로 보존하는 구조 변경. 현재 방향(불확실 탐지를 법적 확정으로 표시하지 않음)은 안전한 쪽 |
| 21 | 레이블 없는 코드 블록이 `optional` — 미탐 쪽으로 이동 | 지금은 유지. 코드 후보 존재 시 **별도 경고** + 진짜 QR/바코드 및 사진·인감 음성 픽스처 → finder/quiet-zone 승격 |
| 22 | `general_jp.applies_to` 의 수동 갱신 누락이 **조용히** 가능 | `applies_to: "*"` 또는 대조기에서 documents ID 집합과 **정확한 동등성** 검사 |
| 23 | `keep:"all"` 수정이 **도달하지 않아** 회귀 방지로 인정 불가 | 기대 키 확장을 순수 함수로 분리해 단위 테스트하거나 `医療機関提示` 를 하네스 전용 목적 케이스로 실행 |
| 24 | gen.py 의 variant 가지치기가 **실제 생성 누락도 승인**할 수 있다 | variant 별 필수 필드 schema 를 두고 생성된 `boxes` 가 그것을 포함하는지 assert 한 뒤 가지치기 |

### S3b 에서 이어진 것

`docs/jp/s3b_report.md` §5 의 B-1~B-15 는 전부 유효하다. 특히 **B-15(`発行日`·`発行者`
탐지 규칙 부재 — 정본은 keep 이라고 선언하는데 경고가 생성될 수 없다)** 는 위 발견 8 과 같은 항목이다.

**변호사 검토는 여전히 없다.** 카드 더미의 공개 저장소 배치는 2026-10-21 사람 결정으로
유지되고, 그 결정이 위험을 0으로 만들지 않는다는 평가도 유지된다 (CLAUDE.md 「JP-1 이슈 로그」).
?? docs/jp/codex_review_s3c_2026-10-21.md
test/safe/specs.json:709:          "expect_jp_entities": 0,
test/safe/specs.json:710:          "expect_empty_notice": true,
test/safe/specs.json:745:        "label": "架空の県名はアンカーにならない（保険者名）",
test/safe/specs.json:746:        "text": "保険者名架空県後期高齢者医療広域連合",
test/safe/specs.json:1040:  "jp_unlabelled_block": {
test/safe/specs.json:1045:  "jp_warn": {
test/safe/specs.json:1050:        "text": "資格確認書\n氏名 架空 太郎\n99221010\n住所 東京都架空区架空町99丁目98番97号\n",
test/safe/specs.json:1081:        "text": "資格確認書\n保険者番号 99221010\n記号 90001234\n番号 901\n枝番 02\n氏名 架空 太郎\n",
test/safe/specs.json:1089:    "_why": "Rows where two label-value pairs share one segment. The alpha fixtures put 保険者名 and 保険者番号 230px apart — wider than the segment threshold — so no committed fixture can reach the state where a keep field's `last:true` tail swallows the insurer NUMBER and marks it `used`, which is exactly what silences the structural fallback (Codex 6b-5). Built through the paste path: what this pins is the label\u2192value boundary, not OCR.",
test/safe/specs.json:1092:        "label": "保険者名 과 保険者番号 가 한 행",
test/safe/specs.json:1093:        "text": "資格確認書\n保険者名 架空健康保険協会 保険者番号 99221010\n氏名 架空 太郎\n",
test/safe/specs.json:1100:        "masked": ["99221010"],
test/safe/specs.json:1105:        "text": "資格確認書\n記号 90001234\n保険者名 架空健康保険協会 RREES 99221010\n氏名 架空 太郎\n",
test/safe/specs.json:1112:        "masked": ["99221010"],
test/safe/specs.json:1114:        "_why": "The other half of Codex 6b-5, and the one that makes the digit-run rule load-bearing. Here the neighbouring LABEL is unreadable \u2014 which is the measured normal on these forms: 保険者番号 OCRs as RREES/REEES/WREEES on 3 of 5 alpha fixtures \u2014 so the tail boundary has nothing to stop at. What keeps the number out of 保険者名's claim is the rule that a keep-only field never consumes a 4+ digit run. Mutation-checked: with that rule disabled the number is NOT banded while the boundary alone still passes the case above. The claim is withheld from `used`, from the entity's BOXES and from its displayed VALUE together \u2014 a band in the output with the number still printed in the sidebar list would be the list contradicting the page."
test/safe/run.mjs:683:    if (c.expect_empty_notice != null || c.expect_jp_entities != null) {
test/safe/run.mjs:685:      if (c.expect_empty_notice != null)
test/safe/run.mjs:686:        rec(tag, 'JP_EMPTY', 'no-rules-for-purpose notice', c.expect_empty_notice ? 'shown' : 'absent',
test/safe/run.mjs:687:          now.emptyShown ? 'shown' : 'absent', now.emptyShown === !!c.expect_empty_notice);
test/safe/run.mjs:688:      if (c.expect_jp_entities != null)
test/safe/run.mjs:689:        rec(tag, 'JP_ENTITIES', 'jp entities', String(c.expect_jp_entities), String(now.fields.length),
test/safe/run.mjs:690:          now.fields.length === c.expect_jp_entities);
test/safe/run.mjs:957:   and the fallback only claims spans nothing else marked `used`. 保険者名 is a
test/safe/run.mjs:1011:  const U = SPECS.jp_unlabelled_block; if (!U) return;
test/safe/run.mjs:1048:  const W = SPECS.jp_warn; if (!W) return;

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "wc -l docs/jp/codex_review_s3c_2026-10-21.md && sed -n '1,240p' docs/jp/codex_review_s3c_2026-10-21.md && git log -1 --oneline --decorate" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
    3327 docs/jp/codex_review_s3c_2026-10-21.md
warning: `--full-auto` is deprecated; use `--sandbox workspace-write` instead.
2026-10-21T16:27:02.873464Z ERROR codex_models_manager::cache: failed to load models cache: missing field `base_instructions` at line 139 column 5
OpenAI Codex v0.146.0
--------
workdir: /Users/sunghoon/Projects/docpack
model: gpt-5.6-sol
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR]
reasoning effort: none
reasoning summaries: none
session id: 01a15f49-a0c4-7f82-ad18-b2c513606c07
--------
user
# Codex 교차검증 요청 — SafeFile JP-1 S3c

## 이 라운드가 무엇인지

S3b 검토(`docs/jp/codex_review_s3b_2026-10-21.md`)가 「즉시 고쳐야 할 상위 5개」로 올린
**AMBER 4건**과, 같은 검토의 **하네스 공허 경로 3건**을 닫은 라운드다.
이것이 **배포 전 마지막 라운드**다.

### 🔴 검토 범위 — 반드시 이 범위만

**판정해야 하는 질문은 하나다: 아래 AMBER 4건이 실제로 닫혔는가.**

| # | S3b 발견 | 요구된 변경 |
|---|---|---|
| A-1 | 발견 3 | 다중 페이지에서 **분류 불가 페이지의 `cls0` 상속 제거**. 예외는 「앞 페이지가 カード 表面이고 이 페이지에 그 카드의 裏面 전용 앵커가 있다」는 조건을 **입증한 경우**만 |
| A-2 | 발견 1, 2 | `lowconf` / `unclassified` **경고 분리**(문구가 실제 출력과 일치), `JP_SUSPECT_RE` 에서 **和暦 단독 조건 제거** |
| A-3 | 발견 5 | `last:true` keep 필드가 **같은 행의 保険者番号를 소비해 미탐시키던 경계** 수정 |
| A-4 | 발견 10, 11 | `verified:false` 인 `jumin_code` 를 **법령 그룹에서 제외**(그룹 멤버십을 정본의 명시 속성에서 파생), **個人番号 확인 문구를 사용자가 검증 가능한 사실로** 변경 |

부수로 닫은 하네스 항목(발견 14·16·18)과 UI 안내(발견 12)도 같은 기준으로 봐주되,
**이 7건 밖의 지적은 AMBER 로 올리지 마십시오.**

**그 외 발견은 백로그로 기록만 하고 AMBER 판정 금지.**
S3b 의 발견 4·6·7·8·9·13·15·17·19·20·21·22·23·24 는 이번 범위가 아니다 —
`docs/jp/s3c_report.md` §5 에 전부 등재돼 있고, 거기에 근거와 함께 「이번 라운드에서
고치지 않은 이유」가 적혀 있다. 그 항목들에 대한 새로운 관찰은 환영하지만
**등급은 백로그(다음 런)로 달아주십시오.** 배포 차단 등급은 위 7건에만 쓸 수 있다.

## 읽을 것

| 파일 | 역할 |
|---|---|
| `docs/jp/s3c_report.md` | 이번 라운드 처리표 + 변이 프로브 결과 + 백로그 |
| `public/safe/index.html` | 페이지 전체(빌드 단계 없음). JP 코드는 `JP_CLASSES`~`jpRenderBar` |
| `test/safe/fixtures/jp/jp_legal_matrix_alpha4.json` | 법적 정본 |
| `test/safe/check_matrix.mjs` | 정본 ↔ 코드 대조기 |
| `test/safe/run.mjs` · `test/safe/specs.json` | 골든 하네스 + 기대표 |
| `docs/jp/s3b_report.md` | 직전 라운드 |

## 검증 상태

```
node test/safe/check_matrix.mjs   → 188 triple + 10 legal pair 일치, exit 0
cd test/safe && node run.mjs      → 아래 보고서 §4 의 수치, exit 0
```

`run.mjs` 는 `127.0.0.1` 에 임시 서버를 띄우고 실제 Chrome 을 몬다 —
샌드박스가 listen 을 막으면 **돌 수 없다.** 그 경우 하네스에 대한 평가는 정적 검토임을
명시해 주십시오(직전 라운드가 그렇게 했고, 그 표기 덕분에 어디까지가 근거인지 알 수 있었다).

## 특별히 의심해 주셨으면 하는 곳

1. **A-1 의 예외 조건이 너무 넓지 않은가.** 승격 조건은 「직전 페이지가 `side==='front'`
   이고 `JP_BACK_ANCHORS[doc]` 가 이 페이지 텍스트에 맞는다」 뿐이다. 페이지 크기·비율·
   연속성은 보지 않는다. 이 조건으로 승격된 페이지는 **전면 띠**를 받는다.
2. **A-3 의 교환.** keep 전용 필드가 4자리 이상 숫자 런을 `used`·boxes·value 에서
   **일괄 포기**한다. 그래서 「事業所名称 架空株式会社 123456」 같은 행의 숫자가 이제
   資格確認書 폴백에 잡힐 수 있다 — 과잉 마스킹 방향이다. 보고서 §2-A3 에 그 교환을
   적었지만, 이 선택이 옳은지는 독립 판단이 필요하다.
3. **A-4 의 `legal_enforcement` 부여 기준.** `qr`(資格確認書)에 부여했다. 그 규칙의
   `legal_basis` 는 지자체 **운용 통지**이고, 우리는 「그 통지가 실시하는 告知要求制限」을
   근거로 삼았다. 이 추론이 「출처 없는 판단의 정본 승격」(발견 7)과 같은 종류의 실수인가.
4. **새 확인 문구가 여전히 사용자가 확인할 수 없는 사실을 묻는가.**
   「提出先の案内で、個人番号（裏面）の提出が明示的に求められていることを確認しました」.
5. **발견 12 의 안내 조건.** 「이 목적의 규칙이 0개」를 코드는 「현재 목적에서 JP 엔티티가
   0개」로 구현했다. 문구와 조건이 어긋나는가.
6. **변이 프로브가 실제로 결함을 되살리는가.** 보고서 §3 의 7개 프로브는 전부 실측이다.
   프로브가 「고친 것」이 아니라 「다른 것」을 재우고 있지 않은지 봐주십시오.

CODEX_REVIEW_READY
warning: Skill descriptions were shortened to fit the 2% skills context budget. Codex can still see every skill, but some descriptions are shorter. Disable unused skills or plugins to leave more room for the rest.
hook: SessionStart
hook: SessionStart Completed
hook: UserPromptSubmit
hook: UserPromptSubmit Completed
codex
요청하신 범위를 엄격히 지키겠습니다. 먼저 S3b의 원래 판정과 S3c 처리표를 대조한 뒤, A-1~A-4와 하네스 3건·UI 안내만 코드/정본/테스트까지 추적하고, 실행 가능하면 두 검증 명령도 직접 재현하겠습니다. 범위 밖 관찰은 배포 차단이 아닌 백로그로만 분리하겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
  → S3b 원문과 S3c 처리표에서 판정 기준·변이 프로브를 추출
  • A-1~A-4 및 하네스/UI 구현을 정적 교차검증
  • 매트릭스 검사와 브라우저 하네스를 실행·결과 확인
  • 범위 준수한 최종 판정 문서 작성
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "sed -n '1,260p' docs/jp/s3c_report.md && sed -n '1,280p' docs/jp/codex_review_s3b_2026-10-21.md && sed -n '1,220p' docs/jp/s3b_report.md" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
# SafeFile JP-1 S3c — Codex 2차 AMBER 4건 + 하네스 공허 경로 3건

입력: [`docs/jp/codex_review_s3b_2026-10-21.md`](codex_review_s3b_2026-10-21.md) 「즉시 고쳐야 할 상위 5개」
직전 라운드: [`docs/jp/s3b_report.md`](s3b_report.md)
다음 라운드 프롬프트: [`docs/jp/codex_prompt_s3c.md`](codex_prompt_s3c.md)
법적 정본: [`test/safe/fixtures/jp/jp_legal_matrix_alpha4.json`](../../test/safe/fixtures/jp/jp_legal_matrix_alpha4.json)

브랜치 `main`. **미배포.** 프로덕션 DB 미접촉. **배포 전 마지막 라운드.**

---

## 0. 요약

| | 전 (S3b) | 후 (S3c) |
|---|---|---|
| 골든 단언 | 484 pass / 0 fail | **533 pass / 0 fail** |
| 정본 ↔ 코드 대조 | 188 triple | **188 triple + 10 legal pair** |
| 변이 프로브 | 6건 | **7건 (전부 실측, 아래 §3)** |
| SW 하네스 | 9/9 | 9/9 (미변경) |

닫은 것은 **네 건 다 「밖에서 보면 정상과 구별되지 않던」 종류**다 —
경고 문구가 출력과 반대였고, 분류 불가 페이지가 남의 규칙으로 통치됐고,
가리지 않겠다고 약속한 필드가 가려야 하는 번호를 숨겼고,
출처를 확보하지 못했다고 스스로 적은 규칙이 법령 금지를 단정했다.

---

## 1. 처리표

| # | S3b 발견 | 상태 | 닫힘 증거 (하네스 케이스명) | 변이 프로브 |
|---|---|---|---|---|
| A-1 | 발견 3 — 분류 불가 페이지의 `cls0` 상속 | **닫힘** | `jp/2page 表 + 無関係な添付 → 分類なし` · `jp/2page 表 + 裏(タイトル切除) → 裏面に昇格` | P-2 → 5 실패 |
| A-2 | 발견 1 — `lowconf` 문구가 출력과 모순 | **닫힘** | `(jp warn) 資格確認書 제목 단독 … 후보 띠 적용 + 확인 요구` (JP_WARN_TEXT + JP_WARN_BANDS) | P-1 → 1 실패 |
| A-2 | 발견 2 — `JP_SUSPECT_RE` 和暦 단독 오경고 | **닫힘** | `(jp warn) 和暦만 있는 일본어 이력서 → 경고 없음` · `(jp warn) 免許証 언급만 … 차단성 경고 + 띠 0` | P-1 → 1 실패 |
| A-3 | 발견 5 — `last:true` keep 필드가 保険者番号를 소비 | **닫힘** | `(jp synth) 保険者名 과 保険者番号 가 한 행` · `(jp synth) 保険者番号 라벨이 OCR 로 깨진 한 행` | P-3 → 2 실패 · P-4 → 2 실패 |
| A-4 | 발견 10 — 법령 그룹이 문자열 Set 에서 파생 | **닫힘** | `check_matrix.mjs` 의 10 legal pair 집합 동등성 + `juminhyo` 의 `require_legal: [my_number]` | P-5 → exit 1 |
| A-4 | 발견 11 — 확인 문구가 검증 불가한 사실을 단정 | **닫힘** | 문구 교체 (4개 언어) + 정본 `gate_requires_confirmation` 갱신 | — (문구 변경, 측정 대상 아님) |
| B-1 | 발견 14 — `filter().every()` 공허 통과 | **닫힘** | `(jp unlabelled) labelled code still banded` → `>=1 banded` | P-6 → 1 실패 |
| B-2 | 발견 16 — allowlist 가 부분집합만 확인 | **닫힘** | `JP_AUTO_SET` 16 케이스가 **집합 동등**(`required_auto`), 3 케이스만 부분집합(`allowed_auto`) | 전환 직후 kouki 의 유령 멤버를 즉시 잡음 (§2-B2) |
| B-3 | 발견 18 — `__allCatsOff` 에 `try/finally` 없음 | **닫힘** | 전체 런에 예외 주입 → 8 LOAD 에러로 **격리**, 나머지 398 단언 전부 녹색 | P-7 (§3) |
| B-4 | 발견 12 — 목적 규칙 0개일 때 무설명 | **닫힘** | `jp/shikaku_kakuninsho/kenpo.png [my_number_procedure]` (JP_EMPTY + JP_ENTITIES) | — (신규 경로, 케이스가 유일한 증거) |

**백로그로 넘긴 것: 발견 4·6·7·8·9·13·15·17·19·20·21·22·23·24 — §5.**

---

## 2. 무엇을 어떻게 바꿨는가

### A-1 (발견 3) — 분류 불가 페이지는 아무 규칙도 받지 않는다

직전 라운드는 `jpClassify(pi) || cls0` 로 썼다. 양면 카드의 스캔 순서 문제는 그것으로 닫혔지만
**통장 사본·세금 통지서·빈 간지가 같은 PDF 에 묶이면 그것들이 카드 규칙으로 통치됐다.**
이 방향의 오류는 누출이 아니라 **제출에 필요한 증빙의 훼손**이다.

**지금**: 분류 불가 페이지는 `null` 이고, 그 페이지에는 **일본 규칙이 하나도 돌지 않는다.**
유일한 예외는 카드의 **裏面** 이다 — 뒷면은 문서 이름을 싣지 않으므로 스스로 분류될 수 없다
(`個人番号` 는 필요한 4점 중 2점이고, 카드의 **이름**은 앞면에 인쇄된다).
승격 조건은 두 개를 **동시에** 요구한다:

```
직전 페이지의 class 가 { doc: D, side: 'front' }   ∧   이 페이지 텍스트가 JP_BACK_ANCHORS[D] 와 일치
```

```js
const JP_BACK_ANCHORS = {
  mynumber_card: /個人番号|マイナンバー|二次元コード/,
  unten_menkyo: /備考欄|臓器提供|提供意思|意思表示欄/,
};
```

`臓器提供` 는 **카드 목록에서 의도적으로 빠졌다** — マイナンバーカード에서는 **앞면** 항목이라
뒷면의 증거가 될 수 없다. 승격된 페이지는 `viaBackAnchor: true` 를 달아 추적 가능하다.

**하네스**: 기존 두 케이스(表→裏·裏→表)는 두 페이지가 **각자 독립적으로** 분류되므로 승격 경로를
밟지 않는다. 그래서 두 케이스를 **런타임에 합성**했다 — 저장소에 새 바이너리를 넣지 않고
이미 커밋된 파일로만 만든다:

| 케이스 | 2페이지 구성 | 기대 |
|---|---|---|
| `表 + 裏(タイトル切除)` | `front.png` + `back.png` 를 **y≥100 으로 크롭**(타이틀 「個人番号カード 裏面」 제거 → 스스로 분류 불가, 그러나 `個人番号` 앵커는 남는다) | `mynumber_card/front + mynumber_card/back`, `viaBackAnchor=true`, 2페이지 전면 띠 ≥99%, 1페이지 ≤60% |
| `表 + 無関係な添付` | `front.png` + `testdocs/1_text.pdf` **1페이지를 pdf.js 로 렌더** (한국어 이력서 — 네 문서 중 어느 것도 아니다) | `mynumber_card/front + null`, `viaBackAnchor=false`, **2페이지 JP 엔티티 0**, 2페이지 피복 ≤10%, 1페이지 JP 엔티티 ≥1 |

마지막 줄이 **공허 방지**다: 「2페이지에 아무것도 없다」가 「프리셋이 통째로 죽었다」로도 참이 될 수 있다.

> ⚠️ **남는 조건**: 승격은 페이지 **크기·비율·연속성**을 보지 않는다. 앵커 하나와 직전 페이지의
> side 뿐이다. 승격된 페이지는 **전면 띠**를 받는다 — 과잉 마스킹 방향이므로 누출보다는 낫지만,
> Codex 가 제안한 추가 조건은 넣지 않았다. §5 백로그 C-1.

### A-2 (발견 1·2) — 경고 두 개는 반대말을 한다

`lowconf` 는 자동 레벨을 **`recommend` 로 강등**한다. 그런데 `recommend` 의 기본 mode 는 `'no'` 다 —
**띠는 출력에 들어간다.** 그 상태에 「自動黒塗りは適用していません」(자동 마스킹을 적용하지
않았습니다) 를 붙이고 있었다. 사용자가 출력 상태를 **반대로** 이해하게 만드는 문구다.

| 상태 | 실제 출력 | 문구 (ja) | 스타일 |
|---|---|---|---|
| `lowconf` — 어느 서식인지는 알지만 확신도가 낮다 | **후보 띠가 적용돼 있다** | 「文書の種類の確信度が低いため、候補の黒塗りを既定で適用しました。必ず確認してください。」 | `.jp-warn.is-low` (앰버 — 확인 요구) |
| `unclassified` — 일본 규칙이 하나도 돌지 않았다 | **아무것도 가려지지 않았다** | 「文書の種類を特定できなかったため自動黒塗りは適用していません。手動で範囲を選択してください。」 | `.jp-warn` (적색 — 정지 신호) |

**4개 언어 각각 자국어만** 쓴다 (발견 25). 직전까지 ko/en/es 는 일본어 원문을 **먼저** 노출하고
괄호로 번역을 붙이고 있었다 — 좁은 모바일 배너에서 핵심 행동 지침이 뒤로 밀린다.
같은 이유로 `jpLegalSection` 의 어순도 뒤집었다(ko: 「법령·제출처 규칙 (法令・提出先ルール)」).

**`JP_SUSPECT_RE` 에서 `令和|平成|昭和` 를 제거했다.** 일본어 이력서·청구서·계약서는 전부 和暦을
싣는다 — 경고가 「이 네 문서 중 하나로 의심된다」가 아니라 **「이 텍스트는 일본어다」**를 뜻하게
되고, 그러면 사용자가 배너를 무시하는 법을 배운다. 그 다음에 정작 필요할 때 거기 없다.

**하네스**: 경고의 **문구**(`expect_text_has`)와 **실제로 칠해진 띠 수**(`expect_mask_rects`)를
함께 단언한다. 가시성만 보는 단언은 문구가 출력과 반대여도 통과한다 — 그게 이 결함이었다.
`lowconf` 픽스처에 **맨 숫자 8자리 한 줄**을 넣었다: 구조 폴백이 `保険者番号` 계열로 잡고
`auto → recommend` 로 강등되지만 **기본 ON 이라 띠가 남는다**. 그 띠가 바로 `lowconf` 문구가
약속하는 것이고, 그게 없으면 두 배너를 **측정으로** 구별할 수 없다.

### A-3 (발견 5) — keep 필드가 같은 행의 번호를 숨기던 문제

모든 값 규칙은 **세그먼트 머리**에 앵커한다. 두 레이블-값 쌍은 **열 간격이 세그먼트 임계값
아래로 내려가는 순간 하나의 세그먼트**가 된다. 그 세그먼트에서 `保険者番号` 는 더 이상 머리에
없으므로 **자기 규칙으로 앵커할 수 없다** — 번호는 구조 폴백에 맡겨지고, 폴백은 **아무도
`used` 로 표시하지 않은 span 만** claim 한다. 그런데 `保険者名` 은 `last:true` keep 필드로서
**레이블 뒤의 모든 item** 을 가져가며 tail 전체를 `used` 로 찍었다.
**가리지 않겠다고 약속한 필드가, 告知要求制限 이 가리라고 요구하는 번호를 침묵시켰다.**

두 겹으로 고쳤고, **두 겹 다 실측으로 load-bearing 임을 확인했다**:

| 겹 | 무엇 | 어느 실패를 닫는가 |
|---|---|---|
| ① `jpTailEnd` — 값의 끝을 **같은 세그먼트의 다음 알려진 레이블 직전**으로 제한 | 모든 값 경로(tel·digits·re·addr·last)에 적용. 性別 정규식이 다음 열의 `男` 을 잡을 이유도 없다 | 이웃 레이블이 **읽힌** 경우 |
| ② `jpKeepOnly` 필드는 **4자리 이상 숫자 런**을 `used`·boxes·value **어디에도** claim 하지 않는다 | keep/optional 레벨만 가진 필드 = 아무것도 가리지 않는 필드 | 이웃 레이블이 **OCR 로 깨진** 경우 — 이 서식에서는 **측정된 정상**이다 (`保険者番号` 가 5개 중 3개에서 `RREES`/`REEES`/`WREEES`) |

②를 `used` 에만 적용하지 않고 **boxes·value 까지** 함께 뺀 이유: 번호가 출력에서는 띠로 덮이는데
사이드바 keep 목록에는 **평문으로 인쇄되는** 상태가 되기 때문이다. 목록이 페이지와 반대말을 한다.

> ⚠️ **교환을 명시한다.** ② 때문에 keep 필드 **자기 값에 속하는** 4자리 이상 숫자 런
> (예 「事業所名称 架空株式会社 123456」)이 이제 claim 되지 않은 채 남고, 資格確認書 폴백이 그것을
> 띠로 덮을 수 있다 — **과잉 마스킹 방향**이다. 이 문서의 규칙은 이미 그 방향을 의도적으로
> 택하고 있다(코드 주석: 告知要求制限 이 保険者番号 계열을 **한 규칙**으로 덮으므로 「어느 멤버인지
e1012c0 (HEAD -> main) fix(safe): JP-1 S3c — close the four deploy-blocking AMBERs, make the legal group derived

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
정적 교차검증과 정본 대조 실행을 완료했습니다. 브라우저 하네스는 샌드박스의 localhost listen 제한으로 실행 불가하여 코드·기대표·변이 프로브 배선을 정적으로 평가했습니다.
  ✓ S3b 원문과 S3c 처리표에서 판정 기준·변이 프로브를 추출
  ✓ A-1~A-4 및 하네스/UI 구현을 정적 교차검증
  ✓ 매트릭스 검사와 브라우저 하네스를 실행·결과 확인
  ✓ 범위 준수한 최종 판정 문서 작성
hook: PostToolUse
hook: PostToolUse Completed
codex
## 최종 판정: AMBER 1건

A-2·A-3·A-4와 하네스 3건은 닫혔습니다. A-1은 일반 `cls0` 상속은 제거됐지만, 예외 승격의 증명이 아직 너무 넓어 완전히 닫혔다고 판정하기 어렵습니다.

### AMBER — A-1 예외가 “그 카드의 뒷면”을 충분히 입증하지 못함

승격 로직 자체는 요구된 두 조건을 구현합니다.

- 직전 페이지가 `side === 'front'`
- 현재 페이지가 `JP_BACK_ANCHORS[prev.doc]`와 일치

근거: [index.html](/Users/sunghoon/Projects/docpack/public/safe/index.html:1984)

문제는 マイナンバーカード 앵커가 다음처럼 단일·범용 문자열을 허용한다는 점입니다.

```js
/個人番号|マイナンバー|二次元コード/
```

특히 `二次元コード`는 카드 고유 앵커도, 뒷면 전용 앵커도 아닙니다. 따라서 카드 앞면 다음에 QR 안내문이나 다른 QR 포함 문서가 붙으면 `mynumber_card/back`으로 승격되어 페이지 전체가 마스킹됩니다. `マイナンバー` 역시 일반 안내문에서 충분히 나타날 수 있습니다. 근거: [index.html](/Users/sunghoon/Projects/docpack/public/safe/index.html:1263), [index.html](/Users/sunghoon/Projects/docpack/public/safe/index.html:2067)

현재 음성 테스트는 앵커가 전혀 없는 한국어 이력서뿐이라 이 반례를 잡지 않습니다. 근거: [run.mjs](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:855)

따라서 A-1은 다음 중 하나가 필요합니다.

- `個人番号`와 12자리 번호/체크디지트 등 복합 증거 요구
- 카드 크기·비율과 앞페이지 유사성 추가
- 최소한 `front + 二次元コード 안내문` 음성 테스트 추가

P-2는 옛 `cls0` 무조건 상속은 정확히 되살리지만, 현재의 과도한 앵커 승격 결함은 되살리거나 탐지하지 않습니다.

## 닫힌 항목

- A-2: 닫힘. 두 경고의 문구와 실제 띠 상태가 분리됐고 和暦가 suspect 조건에서 제거됐습니다. 테스트도 문구와 마스크 수를 함께 검사합니다.
- A-3: 닫힘. `jpTailEnd`와 keep-only 숫자 포기가 레이블 정상/파손 양쪽 경로를 막습니다. 숫자 코드가 과잉 마스킹될 수 있는 교환은 실재하지만 이번 결함의 안전한 방향 수정이며 백로그 C-3로 두는 판단이 타당합니다.
- A-4: 닫힘. `jumin_code`는 법령 그룹에서 빠졌고, 정본의 `legal_enforcement`와 문서별 `JP_LEGAL`이 집합 동등으로 검증됩니다. 확인 문구도 사용자가 제출처 안내문에서 직접 확인 가능한 사실을 묻습니다.
- 資格確認書 QR의 법령 그룹 편입도 타당합니다. 후생노동성은 QR을 읽어 대상 기호·번호를 알 수 있는 경우 동일하게 마스킹해야 한다고 명시합니다. 이는 지자체 통지에서 새로 추론한 규칙이 아니라 중앙 행정기관의 직접 설명입니다. [후생노동성 공식 안내](https://www.mhlw.go.jp/stf/newpage_13989.html)
- 발견 14: 닫힘. `length > 0`과 전체 banded 조건이 결합됐습니다.
- 발견 16: 닫힘. 결정적 케이스는 `required_auto` 집합 동등으로 검사합니다.
- 발견 18: 닫힘. 복원이 `finally`에 있고 복원 상태 자체도 단언합니다.
- 발견 12: 닫힘으로 인정합니다. 현재 문구는 “검출된 항목 중 현재 목적에 적용되는 규칙이 없음”이고, 현재 목적에서 생성된 JP 엔티티가 0개인 조건과 사용자 관점에서 일치합니다. 다만 원시 finding도 0인 경우 같은 문구가 나오는 세부 문제는 다음 런 백로그가 적절합니다.

## 변이 프로브 평가

P-1·P-3·P-4·P-5·P-6·P-7은 각각 해당 결함을 직접 되살립니다. P-2도 옛 무조건 상속 회귀에는 유효하지만, 위 AMBER인 범용 앵커 오승격은 커버하지 않습니다. B-2에는 독립 변이 프로브가 없지만 집합 동등 구현 자체는 정적으로 충분히 확인됩니다.

## 직접 검증

- `node test/safe/check_matrix.mjs`: **188 triple + 10 legal pair 일치**, exit 0
- `node test/safe/run.mjs`: 샌드박스가 `127.0.0.1` listen을 차단하여 `EPERM`으로 실행 불가

따라서 533/533 골든 결과는 이번 검토에서 재실행한 결과가 아니라, 하네스와 기대표에 대한 정적 검토 및 보고서의 실측 기록을 근거로 평가했습니다.
hook: Stop
hook: Stop Completed
tokens used
94,647
## 최종 판정: AMBER 1건

A-2·A-3·A-4와 하네스 3건은 닫혔습니다. A-1은 일반 `cls0` 상속은 제거됐지만, 예외 승격의 증명이 아직 너무 넓어 완전히 닫혔다고 판정하기 어렵습니다.

### AMBER — A-1 예외가 “그 카드의 뒷면”을 충분히 입증하지 못함

승격 로직 자체는 요구된 두 조건을 구현합니다.

- 직전 페이지가 `side === 'front'`
- 현재 페이지가 `JP_BACK_ANCHORS[prev.doc]`와 일치

근거: [index.html](/Users/sunghoon/Projects/docpack/public/safe/index.html:1984)

문제는 マイナンバーカード 앵커가 다음처럼 단일·범용 문자열을 허용한다는 점입니다.

```js
/個人番号|マイナンバー|二次元コード/
```

특히 `二次元コード`는 카드 고유 앵커도, 뒷면 전용 앵커도 아닙니다. 따라서 카드 앞면 다음에 QR 안내문이나 다른 QR 포함 문서가 붙으면 `mynumber_card/back`으로 승격되어 페이지 전체가 마스킹됩니다. `マイナンバー` 역시 일반 안내문에서 충분히 나타날 수 있습니다. 근거: [index.html](/Users/sunghoon/Projects/docpack/public/safe/index.html:1263), [index.html](/Users/sunghoon/Projects/docpack/public/safe/index.html:2067)

현재 음성 테스트는 앵커가 전혀 없는 한국어 이력서뿐이라 이 반례를 잡지 않습니다. 근거: [run.mjs](/Users/sunghoon/Projects/docpack/test/safe/run.mjs:855)

따라서 A-1은 다음 중 하나가 필요합니다.

- `個人番号`와 12자리 번호/체크디지트 등 복합 증거 요구
- 카드 크기·비율과 앞페이지 유사성 추가
- 최소한 `front + 二次元コード 안내문` 음성 테스트 추가

P-2는 옛 `cls0` 무조건 상속은 정확히 되살리지만, 현재의 과도한 앵커 승격 결함은 되살리거나 탐지하지 않습니다.

## 닫힌 항목

- A-2: 닫힘. 두 경고의 문구와 실제 띠 상태가 분리됐고 和暦가 suspect 조건에서 제거됐습니다. 테스트도 문구와 마스크 수를 함께 검사합니다.
- A-3: 닫힘. `jpTailEnd`와 keep-only 숫자 포기가 레이블 정상/파손 양쪽 경로를 막습니다. 숫자 코드가 과잉 마스킹될 수 있는 교환은 실재하지만 이번 결함의 안전한 방향 수정이며 백로그 C-3로 두는 판단이 타당합니다.
- A-4: 닫힘. `jumin_code`는 법령 그룹에서 빠졌고, 정본의 `legal_enforcement`와 문서별 `JP_LEGAL`이 집합 동등으로 검증됩니다. 확인 문구도 사용자가 제출처 안내문에서 직접 확인 가능한 사실을 묻습니다.
- 資格確認書 QR의 법령 그룹 편입도 타당합니다. 후생노동성은 QR을 읽어 대상 기호·번호를 알 수 있는 경우 동일하게 마스킹해야 한다고 명시합니다. 이는 지자체 통지에서 새로 추론한 규칙이 아니라 중앙 행정기관의 직접 설명입니다. [후생노동성 공식 안내](https://www.mhlw.go.jp/stf/newpage_13989.html)
- 발견 14: 닫힘. `length > 0`과 전체 banded 조건이 결합됐습니다.
- 발견 16: 닫힘. 결정적 케이스는 `required_auto` 집합 동등으로 검사합니다.
- 발견 18: 닫힘. 복원이 `finally`에 있고 복원 상태 자체도 단언합니다.
- 발견 12: 닫힘으로 인정합니다. 현재 문구는 “검출된 항목 중 현재 목적에 적용되는 규칙이 없음”이고, 현재 목적에서 생성된 JP 엔티티가 0개인 조건과 사용자 관점에서 일치합니다. 다만 원시 finding도 0인 경우 같은 문구가 나오는 세부 문제는 다음 런 백로그가 적절합니다.

## 변이 프로브 평가

P-1·P-3·P-4·P-5·P-6·P-7은 각각 해당 결함을 직접 되살립니다. P-2도 옛 무조건 상속 회귀에는 유효하지만, 위 AMBER인 범용 앵커 오승격은 커버하지 않습니다. B-2에는 독립 변이 프로브가 없지만 집합 동등 구현 자체는 정적으로 충분히 확인됩니다.

## 직접 검증

- `node test/safe/check_matrix.mjs`: **188 triple + 10 legal pair 일치**, exit 0
- `node test/safe/run.mjs`: 샌드박스가 `127.0.0.1` listen을 차단하여 `EPERM`으로 실행 불가

따라서 533/533 골든 결과는 이번 검토에서 재실행한 결과가 아니라, 하네스와 기대표에 대한 정적 검토 및 보고서의 실측 기록을 근거로 평가했습니다.
