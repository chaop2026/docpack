# SafeFile JP S6b — Codex 교차검증 반영 (2026-10-22)

브랜치 `main`. **미배포·미푸시·미게시.** 프로덕션 DB 미접촉. **배포 전 마지막 라운드.**

입력 [`docs/jp/codex_review_s6s7_2026-10-22.md`](codex_review_s6s7_2026-10-22.md)
직전 보고 [`docs/jp/s6_report.md`](s6_report.md) · [`docs/jp/s7_report.md`](s7_report.md)
문안 정본 [`docs/jp/jp_landing_copy_2026-10-22.md`](jp_landing_copy_2026-10-22.md)

| 검증 | 결과 |
|---|---|
| `bin/rails test` | **208 runs / 1487 assertions / 0 failures** (직전 188/1414) |
| `test/safe/run.mjs` (골든) | **557/557, 0 fail** — 탐지 로직 무변경 |
| `test/safe/check_matrix.mjs` | **188 triple + 10 legal pair 동일**, `verified:false ⇒ no-auto/no-legal` 유지 |
| `test/safe/jp_landing_check.mjs` (라이브) | **107/107** (직전 102) |
| `test/sw/offline_resilience.mjs` | **9/9** |
| `script/canonical_sweep.rb` (라이브) | **6/6** — 철자 115, 중복 200 = 0, 홉 `{1=>88, 2=>2}` |
| rubocop | 86건 — **베이스라인과 동일, 신규 0** (변경한 Ruby 파일 10개에 돌려 0건) |
| brakeman | 경고 6 / exit 3 — 베이스라인과 동일 |
| `make_episode.mjs` | ep01 **33.6초**(OCR+GIF+MP4) · ep02 · ep03 전부 재생성, 가드 통과 |
| 프로덕션 DB | **미접촉** |

---

## 1. 처리표 — AMBER 7건

| # | 지적 | 판정 | 조치 |
|---|---|---|---|
| **A-1** | jp_pilot IP 상한이 `read → +1 → write` 라서 동시 요청에서 상한이 아니다 | **(a) 진짜 문제** | `Api::BaseController#over_limit?` 로 원자적 `increment` 교체 (§2) |
| **A-2** | CSRF skip 의 근거(「JSON 엔드포인트」)가 구현으로 강제되지 않는다 — 외부 폼이 행과 메일을 만든다 | **(a) 진짜 문제 · 라이브 재현** | Content-Type 415 + Origin/Referer 403 (§3) |
| **A-3** | honeypot 이 타이밍까지 구별 불가능하지는 않다 | **(b) 의견 차이 → 백로그** | §6 B-1 |
| **A-4** | safe_events 전역 600건 상한도 원자적이지 않다 | **(a) 진짜 문제** | A-1 과 같은 헬퍼 (§2) |
| **A-5** | ep01~03 X 스레드에 필수 문장이 없다 | **(a) 진짜 문제** | 생성기가 자동 포함 + 가드 (§4) |
| **A-6** | ep01 이 미출시 다중 파일 처리를 홍보한다 | **(a) 진짜 문제** | 본문 삭제 + 가드 확장 + **정본·랜딩 수정**(사람 결정) (§4·§5) |
| **A-7** | 법적 효과 표현이 `topics.json` 의 상한보다 강하다 | **(a) 진짜 문제** | 6곳 수정 + 가드 (§5) |

**(c) 오탐 0건.** Q3(랜딩 문구 정본 일치)는 Codex 판정 `닫힘` 을 그대로 받았다.

### 「확신하지 못한다」 7건 — Codex 판정 수용 여부

| # | 우리가 올린 불확실 | Codex 판정 | 이번 라운드 |
|---|---|---|---|
| 1 | `notify` rescue 범위가 `publish_stuck` 과 동급인가 | **부분 수용** — 신청은 유실 안 되지만 메일 실패를 드러내는 파생 상태가 없다 | **백로그 B-2.** 판정이 옳다 |
| 2 | 전역 분당 600 의 근거 | **근거 불충분** | **백로그 B-3.** 숫자는 그대로 두고 근거가 없다고 적었다 |
| 3 | `sanitize` 의 `v.to_s` 가 새는 경로 | **안전** | 유지. 회귀 테스트 명시화는 백로그 B-4 |
| 4 | init `purpose` 이벤트가 사용자 선택과 구별되지 않는다 | **데이터 품질 결함** | **수정 — `source: init\|user`** (§7) |
| 5 | `/safe/jp/` 301→404 | **백로그** | **백로그 B-5** |
| 6 | Google Fonts 의존(캐러셀 재현성) | **재현성 백로그** | **백로그 B-6** |
| 7 | PNG/GIF/MP4 git 커밋 | **현재 규모에서 수용** | 유지. 임계치 문서화는 백로그 B-7 |

---

## 2. A-1 · A-4 — 상한이 동시 요청에서 상한이 아니었다

`read → +1 → write` 는 lost update 다. 두 요청이 같은 `2` 를 읽으면 둘 다 `3` 을 쓰고 둘 다
통과한다. **Solid Cache 가 프로세스 공유라는 사실은 이 경쟁을 해결하지 않는다** — 공유 스토어는
두 리더가 같은 낡은 값을 보게 만드는 바로 그 조건이다. 기존 상한 테스트는 요청을 **한 줄로**
보내므로 깨진 코드에서도 초록이었다.

**수정**: `Api::BaseController#over_limit?(key, limit:, window:)` 하나로 통일했다. 세 엔드포인트
중 상한이 있는 두 곳이 이것을 쓰므로, **「세는 것이 원자적인가」를 판정할 장소가 한 곳**이 된다.

`Rails.cache.increment` 가 이 앱이 가질 수 있는 **모든 스토어에서 원자적이고 키가 없으면
만든다** — 그래서 지시서가 제안한 write-then-increment 춤이 필요하지 않다. 추정하지 않고
**소스를 인용하고 테스트로 고정**했다:

| 스토어 | 원자성 | 키 부재 | 쓰이는 곳 |
|---|---|---|---|
| `:solid_cache_store` | `SELECT … FOR UPDATE` in transaction (`solid_cache-1.0.10/app/models/solid_cache/entry.rb:70`) | `Entry.new(amount)` (`lib/solid_cache/store/api.rb:174`) | **프로덕션** |
| `:memory_store` | `synchronize { … }` (`activesupport cache/memory_store.rb:243`) | `write(amount)` | 개발 · `CacheStoreHelper` |
| `:null_store` | `increment` 가 `nil` 반환 | — | **테스트 기본값** |

마지막 줄이 중요하다 — 「캐시가 기억하지 않으면 상한이 발화하지 않는다」 역가드 테스트 두 개가
그 성질에 기대고 있다. null store 가 세기 시작하면 그 역가드가 **아무것도 아닌 것에 대한
단언**으로 조용히 바뀌므로, 「limit 0 에서도 발화하지 않는다」를 전용 테스트로 고정했다.

TTL 도 바뀐다: 전에는 매 요청이 `write(expires_in:)` 로 TTL 을 **갱신**했고 이제는 키 생성
시점에만 설정된다(두 스토어 모두 `expires_at` 을 보존한다 — 테스트로 확인). 키가 이름에 자기
윈도를 담고 있으므로 이것이 맞다 — 미끄러지는 TTL 은 죽은 버킷을 살려두는 일만 한다.

### 변이 프로브 — 하네스가 두 구현을 구별하는가 (실측)

`test/controllers/api/rate_limit_test.rb` 는 **옛 패턴의 재구현을 옆에 둔다.** 두 구현에서 다
통과하는 동시성 테스트는 테스트가 아니다. 20 스레드, 상한 3, `CountDownLatch` 로 동시 출발:

```
racy admitted:   6 of 20 (cap 3)     ← read → Thread.pass → write
atomic admitted: 3 of 20 (cap 3)     ← Rails.cache.increment
```

read 와 write 사이의 `Thread.pass` 는 **의도적**이다. 그것 없이도 경쟁은 있지만 타이밍에
의존하고, **경쟁을 잡는 테스트가 경쟁이 일어날지를 결정하는 주체가 되면 안 된다.**

### 이 유닛이 죽은 코드가 아님을 고정

`over_limit?` 가 호출되지 않아도 위 단언은 전부 초록이다. 그래서 엔드포인트가 **그 키 모양으로
실제로 센다**를 단언한다 — POST 한 번 뒤 `jp_pilot:127.0.0.1:<bucket>` 가 `1` 이다.
(safe_events 쪽은 기존 테스트가 이미 그 키를 직접 prime 한다.)

### 범위에서 뺀 것 — `/api/safe_scan`

`safe_scan_controller.rb:96` 에 **같은 패턴이 남아 있다**(IP당 시간당 30회). 같은 결함이고
헬퍼가 있으니 한 줄이지만, 이 엔드포인트에는 **테스트가 하나도 없다** — 유료 API 를 부르는
경로의 상한을 커버 없이 바꾸는 것이 고치지 않는 것보다 낫다고 판정하지 않았다. 백로그 B-8.

---

## 3. A-2 — CSRF skip 의 근거가 구현이 아니라 관습이었다

「세션을 읽지 않으므로 빌릴 권한이 없다」는 **사실이지만 질문에 답하지 않는다.** 외부에서 오는
POST 는 권한을 빌릴 필요가 없다 — 남의 페이지에 있는 평범한 HTML `<form>` 이
form-urlencoded 로 보내면 Rails 가 **같은 `params`** 를 만들고, `/api/jp_pilot` 은 행을 쓰고
메일을 보낸다. 공격자는 응답을 읽을 필요조차 없다.

### 라이브 실측 — 수정 전/후 (로컬 Puma, 같은 요청)

```
— 가드 없음 (이 라운드가 발견한 상태)
  form POST            → 201      jp_pilot_requests: 0 → 1   (행이 실제로 써졌다)
  foreign Origin JSON  → 204
— 가드 있음
  form POST            → 415      행 0
  foreign Origin JSON  → 403
  own Origin JSON      → 204
  no Origin JSON       → 204      (sendBeacon · curl · 모니터)
```

**수정**은 `Api::BaseController` 에 두 겹을 둔다 — 네 번째 `/api/` 엔드포인트가 **기억하지 않고
상속**하도록.

1. **JSON 전용 (415).** Content-Type 이 `application/json` 이 아닌 POST 는 파라미터를 읽기
   **전에** 거부된다. 이것이 **실제로 구멍을 막는 절반**이다 — 외부 `<form>` 은 세 가지 폼
   enctype 밖으로 나갈 수 없고, fetch/XHR 로 JSON 을 보내려는 순간 CORS 아래로 들어간다.
   전제를 관습에서 **참**으로 바꾼다.
2. **Origin — 브라우저가 보냈을 때만 (403).** 동명 출처 POST 도 `Origin` 을 싣는다(Fetch 규격이
   GET/HEAD 외 모든 메서드에 보낸다), 그래서 **불일치는 진짜 신호**다. 그러나 **부재는 신호가
   아니고, 그래서도 안 된다** — curl·모니터는 둘 다 안 보내고 막을 이유가 없다. 규칙은
   「있으면 우리 것이어야 한다」이고 「있어야 한다」가 아니다.
   호스트를 비교한다(전체 origin 이 아니라): kamal-proxy 뒤에서 앱이 보는 scheme 과 브라우저가
   쓴 scheme 이 일치할 필요가 없고, **외부 요청의 Host 헤더는 브라우저가 우리 URL 에서 설정**
   하므로 공격자는 자기 Origin 값은 위조할 수 있어도 브라우저가 우리 Origin 을 말하게 할 수는
   없다.
   `Origin: null`(샌드박스 iframe·리다이렉트로 벗겨진 출처)은 **부재로 취급하지 않는다** —
   브라우저가 「우리 것이 아니다」를 말하는 것이므로 침묵과 반대말이다.

### 클라이언트 — 바꿀 것이 없었다 (확인함)

| 호출부 | Content-Type | 확인 |
|---|---|---|
| `public/safe/jp/jp.js:26` landing_view·cta_click | `new Blob([body], {type:'application/json'})` | sendBeacon 이 Blob 의 type 을 Content-Type 으로 쓴다 |
| 같은 파일 fallback · 폼 제출 | `'content-type': 'application/json'` | — |
| `public/safe/index.html:808` sfEvent | 동일 Blob | — |
| `public/safe/index.html:2934` safe_scan | `'Content-Type':'application/json'` | — |

라이브 하네스가 **세 랜딩 전부에서 204** 를 확인했으므로 sendBeacon 경로가 415 에 걸리지 않음이
측정됐다. 문자열 본문 sendBeacon 의 기본값(`text/plain;charset=UTF-8`)은 이제 415 이고,
전용 테스트가 그것을 고정한다 — Blob 으로 감싸는 것이 **습관이 아니라 요구사항**이 됐다.

---

## 4. A-5 · A-6 — 가드가 한 면만 보고 있었다

가드는 JA frontmatter + 본문을 **한 문자열로 합쳐** 검사했다. 범위가 코드에서 안 보였고 실제로
틀렸다 — **영어 원고와 생성된 X 스레드는 아예 검사되지 않았다.** 결과:

- ep01 이 「複数枚をまとめて読み込めます」/"Several files at once is fine" 를 실었다.
  **실측**: 파일 입력에 `multiple` 속성이 없고(`index.html:390`) 핸들러는 `files[0]` 을 읽는다.
- 세 회차의 X 스레드가 필수 문장 없이 나갔다.
- 그런데 **빌드는 위반 0건을 보고했다.**

### 검사 범위를 이름 있는 다섯 면으로

위반 메시지가 **어느 파일인지** 말한다:
`post_ja.md (frontmatter)` · `post_ja.md (body)` · `post_en.md` · `x_thread.md (generated)` ·
`carousel text (generated)`. 면을 늘리는 것이 여기 한 줄 추가가 된다.

`x_thread.md (generated)` 는 **완성된 파일 문자열**을 스캔한다(트윗 배열이 아니다) — 헤더 줄이
`topics.json` 의 `title_ja` 를 싣고, 그 문자열은 frontmatter 가드가 영원히 보지 못한다.
그래서 `threadMd` 를 가드 **앞**에서 만들고 통과한 뒤에 쓴다 — 「위반이면 아무 파일도 쓰지
않는다」는 성질을 유지하면서.

### 미출시 기능 — 「`一括処理` 금지」가 왜 충분하지 않았나

금지어가 **정확한 일본어 한 덩어리**였고, 초안이 실제로 손을 뻗는 것은 **우회 표현과 영어**다.
이제 `一括` · `複数(枚|ファイル|のPDF|PDF)` · `まとめて(読み込|処理|ダウンロード)` · `処理記録` ·
`batch` · `several files` · `multiple files` · `at once is fine` · `processing log` 를 다섯 면
전부에서 본다.

### 필수 문장 — 자동 포함, 넘치면 별도 트윗

X 스레드 마지막 트윗에 `提出先の指示を必ず確認してください。` 를 **생성기가 붙인다.** 한 출력에
강제되고 다른 출력에는 맡겨지는 규칙은 **한 출력에만 존재하는 규칙**이다.
140자를 넘기면 **CTA 를 줄이지 않고 별도 트윗으로 뺀다** — 여섯 트윗은 괜찮지만 저자가 쓰지
않은 CTA 는 아니다(자르지 않는다는 기존 원칙과 같은 근거).

EN 본문에도 영어판 필수 문장(`check the recipient's own instructions`)을 요구한다. 세 회차 모두
이미 갖고 있었다(확인함) — 요구사항이 없었을 뿐이다.

### 캐러셀 PNG — 선언 세 곳, 대조 0곳

1080×1350 은 템플릿 주석 · `#card` CSS · 이 스크립트가 여는 뷰포트 **세 곳에 선언**돼 있었고
**디스크의 파일과 대조하는 곳은 없었다.** `deviceScaleFactor`·CSS 수정·요소 클리핑이 전부
실제 픽셀을 바꾸면서 빌드는 침묵하고, 처음 드러나는 곳은 잘린 업로드다.

PNG 의 **IHDR 을 직접 읽는다**(의존성 0, 그리고 우리 의도가 아니라 **파일 자신의 진술**) →
manifest `pixels` 에 적고, 어긋나면 **세 장을 다 만든 뒤 exit 1**. 데모 녹화 실패와 달리
잘못된 크기는 부분 성공이 아니라 **산출물 자체가 틀린 것**이다.

### 1인칭 피해담 — 휴리스틱이고, 그렇게 적었다

`/私の…(免許証|保険証|住民票|マイナンバー)…(流出|漏えい|漏洩|晒され)/` 는 전략이 금지한 **모양
하나**를 잡는다. 의미 판정이 아니고 원고 읽기를 대체하지 않는다.
**README 에 「코드가 강제하는 규칙」과 「사람이 지키는 규칙」을 분리한 표를 넣었다** —
「규칙이 있다」와 「규칙이 강제된다」가 같아 보이면 안 된다.

### 변이 프로브 7/7 (전부 실측)

| 프로브 | 결과 |
|---|---|
| P1 JA 「複数枚をまとめて読み込めます」 복원 | **exit 1** — `post_ja.md (body)` 2건 |
| P2 JA 「原則として制限されています」 복원 | **exit 1** — `post_ja.md (body)` |
| P3 EN "Several files at once is fine." 복원 | **exit 1** — `post_en.md` |
| P4 1인칭 피해담 삽입 | **exit 1** — 매치한 문자열을 인용 |
| P5 생성기에서 필수 문장 제거 | **exit 1** — `x_thread.md (generated)` |
| P6 캐러셀 기대 크기를 1351 로 | **exit 1** — 세 장 전부 보고 |
| P7 `TWEET_LIMIT` 90 으로 | **6트윗** — 5번=CTA+URL(90자), 6번=필수 문장(18자) |

P7 은 실제 세 회차가 전부 140자 안에 들어가서 **평소에는 돌지 않는 분기**다. 돌지 않는 분기를
「구현했다」고 적지 않기 위해 강제로 밟았다.

### 재생성 결과

| ep | 트랙 | 결과 |
|---|---|---|
| 01 | A | 5트윗(마지막 109자) · 캐러셀 3장 1080×1350 fit 100% · demo 40프레임 GIF 396KB / MP4 219KB · warnings 0 · **33.6초** |
| 02 | B | 5트윗(114자) · 캐러셀 3장 · `demo: skipped: track B has no tool demo` |
| 03 | A | 5트윗(110자) · 캐러셀 3장 · `demo: failed: no dummy document exists for doc="契約書"` |

`docs/jp/s7_samples/` 4개 파일 갱신.

---

## 5. A-6 정본 수정 (사람 결정) · A-7 법적 표현

### A-6 — 정본과 랜딩을 **함께** 고쳤다

| 위치 | 전 | 후 |
|---|---|---|
| 仕組み 1단계 (정본 + `nyusatsu/index.html`) | `PDF・写真をドラッグ — 複数まとめて可` | `PDF・写真をドラッグ` |
| チームプラン 기능 목록 **위** (양쪽) | (없음) | `※ 以下の機能はパイロット期間中に順次提供します（現在は1ファイルずつ処理）` |
| EN 블록 Team plan (양쪽) | `… Japanese email support. Pilot: …` | `… Japanese email support. These arrive progressively during the pilot; today the tool processes one file at a time. Pilot: …` |

기능 목록 자체는 **그대로 뒀다** — 그것은 로드맵이고, 로드맵임을 말하는 줄이 붙었다.
`jp_landing_check.mjs` 는 새 줄을 기대값에 넣고, **제거한 문구가 돌아오지 않는지**도 본다
(`absent: ['複数まとめて可']`). 기대값에 추가만 하면 「지웠다」는 회귀를 잡지 못한다.

### ⚠️ 남은 같은 종류의 주장 1건 — **사람 확인 필요**

`nyusatsu/index.html` 의 **meta description · og:description · twitter:description 세 곳**이
여전히 `複数PDFを一括、…` 라고 말한다(정본 11행도 동일). 랜딩 본문의 주장은 위 한 줄이
완화하지만 **검색 스니펫에는 그 단서가 들어갈 자리가 없다.**

사람 결정 A-6 은 두 수정을 명시했고 meta 는 그 안에 없어서 **건드리지 않았다** — 결정을 조용히
넓히지 않는다. 한 줄로 승인할 수 있게 대안을 적어둔다:

```
公共工事の入札で求められる被保険者記号・番号・保険者番号のマスキングを、ブラウザだけで自動処理。
ファイルはサーバーに送信しません。再提出をなくします。
```
(= `複数PDFを一括、` 삭제. 전·후 모두 120자 이내. 세 곳 + 정본 11행 + `jp_landing_check` 기대값)

정본의 **접촉 메일 문안**(151·155·165행)도 `複数PDFを一括処理` / `processes multiple PDFs at
once` 라고 말한다. 이것은 페이지가 아니라 사람이 보내는 메일이고 가드 밖이다 — 백로그 B-9.

### A-7 — 법적 효과 단정 6곳

| 파일 | 전 | 후 |
|---|---|---|
| `public/safe/jp/nyusatsu/index.html` (FAQ 본문 + JSON-LD `acceptedAnswer`, **2곳**) | `原則制限されています` | `制限される場合があります` |
| `docs/jp/jp_landing_copy_2026-10-22.md:61` (FAQ) | `原則制限されています` | 동일 |
| `content/jp/ep01/post_ja.md` | `原則として制限されています` | 동일 |
| `content/jp/ep01/post_en.md` | `is restricted in principle` | `may be restricted` |
| `content/jp/ep02/post_en.md` | `The law constrains the party that may not *ask* for the number;` | `The party that asks for the number may be restricted by law;` |

JSON-LD 를 **본문과 함께** 고친 것이 핵심이다 — 리치 결과는 본문과 다른 문장을 인용할 수 있고,
사람이 읽는 페이지만 완화하면 구글이 단정형을 계속 보여준다.

가드가 이제 `制限されています` · `禁止されています` · `違法です` · `is restricted` ·
`is prohibited` · `is illegal` · `law constrains` 를 다섯 면 전부에서 막는다.
**근거는 「우리가 신중하다」가 아니다 — 일본 변호사 검토가 아직 없으므로 현재 법 상태를
단정할 자료가 없다.**

---

## 6. 백로그

| # | 항목 | 왜 이번이 아닌가 |
|---|---|---|
| **B-1** | honeypot 타이밍 오라클 (A-3) | 정상 경로는 validation·INSERT·메일 enqueue 를 하고 honeypot 은 즉시 돌아온다. 상수 시간으로 만들려면 **거부 경로도 같은 일을 하는 것처럼 지연**시켜야 하는데, 그건 「스팸을 위해 DB 를 두드린다」 또는 「임의의 sleep」이다. 전자는 공격 표면을 늘리고 후자는 분포를 평탄하게 만들지 못한다. **등급 재판정: 「일반 봇을 속이는 fake success」는 성립하고 「타이밍까지 구별 불가」는 성립하지 않는다** — 문서의 주장을 그 수준으로 낮추는 것이 먼저다 |
| **B-2** | 메일 전달 실패의 능동적 가시성 (불확실 1) | 신청 행은 메일보다 **먼저** 저장되고 어드민 목록이 그 행을 직접 읽으므로 **유실은 없다.** 없는 것은 `publish_stuck` 같은 파생 상태 — 「새 신청이 아직 확인되지 않음」. 알림 채널을 또 만드는 판단이라 범위 밖 |
| **B-3** | 전역 600/분의 **근거** | 방향(개인정보 없는 전역 상한)은 유지한다. 숫자는 측정 근거가 없다 — 실제 트래픽 한 주를 보고 정한다. 지금은 유기적 사용량보다 훨씬 위라는 믿음뿐이고, 그렇게 적었다 |
| **B-4** | `SafeEvent` 의 array/nil/upload 모양 회귀 테스트 | Codex 가 **안전**으로 판정했다(새는 경로 없음). 현재의 안전 성질을 **문서화**하는 테스트가 없을 뿐 |
| **B-5** | `/safe/jp/` 가 301→404 | 거짓 콘텐츠는 아니지만 크롤러에 불필요한 redirect-to-error. 직접 404 로 하거나 유효한 허브를 만든다 |
| **B-6** | 캐러셀 폰트 고정 | Google Fonts 가 없으면 Hiragino 로 떨어진다(의도) — 그러나 같은 원고의 픽셀 결과가 환경에 따라 다르다. manifest 에 실제 사용 폰트를 적는 것이 최소 조치 |
| **B-7** | 생성물(PNG/GIF/MP4) 저장 정책·용량 임계치 | 33편 ~30MB 는 감당 가능하고 재생성이 비결정적이라는 사실이 보존 이유가 된다(GIF 바이트가 런마다 바뀐다 — 실측). 임계치를 문서화하지 않았다 |
| **B-8** | `/api/safe_scan` 의 상한도 비원자적 | 같은 결함이고 헬퍼로 한 줄이지만 **이 엔드포인트에는 테스트가 0개**다. 유료 API 경로의 상한을 커버 없이 바꾸지 않는다 |
| **B-9** | 정본 접촉 메일 문안의 `複数PDFを一括処理` | 페이지가 아니라 사람이 보내는 메일. 가드 밖이고 A-6 결정 밖 |
| **B-10** | `nyusatsu` meta/og/twitter description 의 `複数PDFを一括` | §5 — **사람 확인 대상**, 대안 문안 준비됨 |
| **B-11** | `purpose` 이벤트의 `source` 집계 해석 | 수정은 끝났고, 과거에 쌓인 행에는 `source` 가 없다(지금 `safe_events` 는 비어 있으므로 영향 0). 레이크가 `purpose × source` 표를 자동 생성한다 |

S6 §5 · S7 §8 의 남은 공백은 그 보고서가 계속 정본이다 (Stripe JP 상품 2개 · GSC JA 랜딩 등록 ·
`safe_events` 보존 기간 · 프로덕션 SMTP 실발송 · 「선착 10사」 마감 처리 · ep04~33 본문 ·
ep05·ep06 근거 확인 · `x_thread` t.co 단축).

---

## 7. 그 외 반영 (값싼 것만)

### `purpose` 이벤트에 `source: init | user` (불확실 4)

랜딩이 `?purpose=` 로 들어오면 init 중에 `jpSetPurpose` 가 돌아 `purpose` 행이 하나 써진다 —
**사용자가 아무것도 만지기 전에.** 그 행은 `doc_class:"none"` 까지 달고 있어서 「드롭다운 변경」
과 사후에 구별되지도 않았고, 모든 목적 통계가 **프리셀렉트를 선택으로** 세고 있었다.

고정 범주 두 개(`SafeEvent::VALUES["source"]`)만 추가했다. 자유 텍스트 0, 새 컬럼 0 —
개인정보 0 성질은 그대로다.

**라이브 실측** (실제 브라우저 + 실제 서버):
```
purpose event: {"locale":"ja","from":"nyusatsu","purpose":"bid_attachment","doc_class":"none","source":"init"}
purpose event: {"locale":"ja","from":"nyusatsu","purpose":"consult_share","doc_class":"none","source":"user"}
server statuses: 204,204
```
`204` 두 개가 중요하다 — payload 만 보면 「페이지가 보내려 한 것」만 증명된다.

레이크는 `SafeEvent::KEYS` 에서 섹션을 **파생**하므로 `purpose × source` 표가 자동으로 생겼다
(실측). P11(個人番号手続 선택률) 주석에 **`source=user` 로만 세라**는 줄을 넣었다 — 표가
생기는 것과 사람이 바르게 읽는 것은 다른 문제다.

### 쿠키 회귀 테스트가 세 엔드포인트 전부를 부른다 (Q2 테스트 범위)

테스트 이름은 「모든 `/api/` 엔드포인트」인데 `safe_scan` 은 직접 부르지 않았다. 공통 상속
때문에 현재 코드는 안전하지만 **이름보다 좁게 단언하는 테스트는 다음 엔드포인트가 테스트 없이
추가되는 방식**이다. `POST /api/safe_scan?locale=ja` 를 **빈 본문**으로 부른다 — Anthropic 에
닿기 전에 400 `empty` 로 답하므로 토큰을 쓰지 않고 필터는 이미 돌았다.
라이브로도 확인: 세 경로 전부 `set-cookie` 0건.

### `jp_landing_check` 가 CTA 클릭의 응답도 본다 (Q3 하네스)

「server accepted every counter」 단언이 **CTA 클릭 전에** 실행돼서 `cta_click` 요청의 상태는
한 번도 보지 않았다 — 「every counter」라고 말하면서 `landing_view` 만 덮고 있었다.
클릭 전 개수를 스냅샷하고 클릭 **이후** 응답만 잘라서 따로 단언한다(3페이지 전부 204).

---

## 8. self-check 로 잡은 것

- **`Rails.cache.increment` 를 소스로만 판정하려 했다.** 「원자적이고 키를 만든다」를 gem 소스
  인용으로 끝내려다, 그 인용이 **주석의 근거**이므로 테스트로 고정했다 — 키 부재 시 1, TTL
  미끄러짐 없음, null store 는 여전히 안 센다. 세 번째가 특히 중요하다(역가드 두 개가 거기
  기댄다).
- **멀티파트 415 테스트가 틀린 이유로 초록이었다.** `params:` 해시를 주면 통합 세션이 자기
  boundary 를 Content-Type 에 덧붙여 **Rack 이 우리 필터 전에** `BoundaryTooLongError` 로
  거부한다(실측). raw 본문으로 바꿨다 — 가드와 무관한 이유로 통과하는 테스트는 가드를 증명하지
  않는다.
- **「페이로드가 유효하다」 역가드.** 415/403 테스트 11개가 전부 「거부됐다」를 단언한다. 쓰는
  페이로드가 어느 날 무효가 되면 **11개가 전부 잘못된 이유로 초록**이 된다. 같은 페이로드가
  정상 경로에서 행을 만드는지 단언하는 테스트를 뒀다.
- **`over_limit?` 가 죽은 코드일 수 있었다.** §2 마지막 항목.
- **라이브 하네스가 429 로 빨개졌다.** 내 curl 프로브가 IP 상한을 써버린 것 — 하네스 README 가
  이미 경고하는 그 상황이다(`docker compose restart web` 으로 초기화). 재시작 후 107/107.
  **「상한이 깨졌다」와 「상한이 이미 소진됐다」가 밖에서 같아 보인다.**
- **메트릭 파일을 더럽혔다.** `safe:jp_weekly` 를 실측하려고 돌려 `docs/jp/metrics/2026-W43.md`
  를 개발 DB 노이즈로 덮었다. `git checkout` 으로 원복하고 확인했다.

## 9. 아직 없는 것

**일본 변호사 검토.** A-7 은 표현을 상한 아래로 내렸을 뿐이고, 카드 더미가 공개 저장소에 있다는
2026-10-21 사람 결정도 그대로다. 「오용 가치 0」이라고 쓰지 않는다.
