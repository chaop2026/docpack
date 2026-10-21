# SafeFile JP S6 — 랜딩 3페이지 + 파일럿 폼 + 익명 계측 (2026-10-22)

브랜치 `main`. **미배포·미푸시.** 프로덕션 DB 미접촉.
문안 정본 [`jp_landing_copy_2026-10-22.md`](jp_landing_copy_2026-10-22.md) ·
계측 요구 [`jp_forecast_report_2026-10-22.md`](jp_forecast_report_2026-10-22.md) §8 ·
지시서 [`s6_prompt.md`](s6_prompt.md)

**골든 557/557 유지(0 실패) · SW 하네스 9/9 유지 · `bin/rails test` 159→186 runs / 1218→1404 assertions / 0 failures ·
신규 하네스 `jp_landing_check.mjs` 102/102 · canonical sweep 6/6 · rubocop 신규 위반 0 · brakeman 6건(기존과 동일)**

---

## 1. 무엇을 만들었나

### 랜딩 3페이지 (정적, `public/safe/jp/`)

| URL | 축 | CTA 목적 | `from` |
|---|---|---|---|
| `/safe/jp/nyusatsu/` | 사업자 매출 (1층) | `bid_attachment` | `nyusatsu` |
| `/safe/jp/honnin-kakunin/` | 개인 트래픽 (3층) | `identity_submit` | `honnin` |
| `/safe/jp/ai-mae/` | 패스 매출 (2층) | `consult_share` | `aimae` |

- 문안은 **정본 그대로**. 레이아웃만 입혔다. 하네스가 페이지마다 H1 전문과 본문 6~7개
  구절을 **문자열 동일성**으로 단언하므로, 문구가 흔들리면 테스트가 깨진다
  (문구 준수를 읽기 과제가 아니라 실패로 만든 것).
- EN 은 **각 페이지 하단 접이식 `<details>`** — `?lang=en` 토글을 쓰지 않았다.
  **이유**: 토글이면 같은 내용이 두 URL 로 서빙되고, 이 저장소가 두 라운드에 걸쳐 고친
  「같은 바이트를 주는 주소가 여럿인데 canonical 이 없다」 상태를 새로 만든다.
  한 URL 안의 접이식 블록은 그 문제를 **만들지 않는다**.
- 디자인: `/safe/` 의 토큰·IBM Plex Sans KR·헤더(SafeFile │ SlimFile) 그대로.
  모바일 우선, 측면 여백 16px, 표는 **자기 박스 안에서만** 가로 스크롤(페이지 본문은 절대 안 밀림).
- **제3자 스크립트 0**. 하네스가 페이지가 접속하는 호스트를 전부 수집해 폰트 CDN 2개
  (`/safe/` 가 이미 쓰는 것) 외에 아무것도 없음을 단언한다.

### SEO

- `<html lang="ja">`, 정본대로의 title·meta description, 트레일링 슬래시 self-canonical,
  OG/Twitter(이미지는 `/safe/icon-512.png` 재사용), JSON-LD `SoftwareApplication` ×3 +
  `FAQPage`(nyusatsu 만).
- **hreflang 0개 — 의도다.** `/about` 과 같은 판정: 한 URL = 한 일본어 문서이고 영어는 그
  URL **안**에 있다. `en` 알터네이트는 존재하지 않는 URL 을 가리키고, `x-default`
  자기참조는 「이 페이지는 특정 언어를 대상으로 하지 않는다」는 거짓말이 된다.
  `/safe/` 는 반대 경우(1 URL × 4언어 클라이언트 전환)라 x-default 를 갖는다.
- sitemap 에 3개 추가(30 → 33 entries). `robots.txt` 는 `Allow: /` 이므로 그대로 허용.
  ⚠️ CLAUDE.md 의 "Static fallback: `public/sitemap.xml`" 는 **낡은 기록**이다 —
  그 파일은 존재하지 않는다(확인). 갱신할 것이 없었다.

### `CanonicalPathRedirect::DIRS` 확장 — 이번 작업의 숨은 필수 항목

`public/<dir>/index.html` 이 생기면 `ActionDispatch::FileHandler` 가 **슬래시 없는 철자에도
같은 바이트를 200 으로** 돌려준다. 즉 페이지를 만든 것만으로 주소가 둘이 된다.
3개 디렉터리를 DIRS 에 넣었고, **목록을 파일시스템에서 파생해 대조하는 테스트**를 추가했다:

```ruby
Dir.glob("public/**/index.html") - public/assets → DIRS 와 집합 동등
```

→ 다음에 랜딩을 하나 더 만들고 DIRS 를 잊으면 **테스트가 먼저 실패한다**(변이로 확인: ai-mae 를
빼면 2건 실패). 실측 결과:

| 철자 | 응답 |
|---|---|
| `/safe/jp/nyusatsu/` | 200 |
| `/safe/jp/nyusatsu` · `/index.html` · `//` · `///` · `//index.html` · `/index.html/` · `/safe/jp//nyusatsu/` | 전부 **1홉 301 → `/safe/jp/nyusatsu/`** |
| `/safe/jp/jp.css` · `/safe/jp/jp.js` | 200 (디렉터리 밑 에셋은 손대지 않는다) |
| `/safe/jp/` | 301 → `/safe/jp` → **404** |

마지막 줄은 **의도다.** `public/safe/jp/` 에 index.html 이 없으므로 DIRS 에 넣으면 셋 중
하나에 네 번째 주소를 발명하는 셈이다. 아무것도 없는 주소의 정직한 답은 404 이고,
그 앞의 301 은 미들웨어의 「라우팅 경로는 슬래시 없음」 규칙이 한 홉 쓴 것이다.
(sweep 의 「301 은 반드시 실재하는 곳에 떨어져야 한다」 규칙은 **색인된** URL 이 떠내려가는
것을 잡는 장치라, 이 경로는 일부러 sweep 대상에서 뺐다 — 주석으로 남겼다.)

### 파일럿 폼 (`POST /api/jp_pilot`)

- 테이블 `jp_pilot_requests(company, industry, monthly_count, authority, email, from, timestamps)`.
- 서버 검증: 메일 형식·길이, `industry`/`monthly_count`/`from` 은 **select 선택지 집합**.
  `from` 만 예외 — 알 수 없는 값이면 **거부하지 않고 `direct` 로 떨어뜨린다.** 그건 신청자가
  입력한 값이 아니라 마케팅 귀속 힌트이고, 낡은 링크 하나가 진짜 신청을 날려서는 안 된다.
- **스팸 가드 2겹**:
  - **honeypot `website`** — 화면 밖(`position:absolute;left:-9999px`) + `tabindex=-1`.
    채워져 있으면 **행을 쓰지 않고 201 을 돌려준다.** 구별 가능한 거부는 스팸 스크립트에
    공짜 오라클을 주기 때문이다. 밖에서 보이는 유일한 차이는 「행이 없다」.
    ⚠️ 빈 문자열은 스팸이 아니다 — 실제 브라우저는 이 필드를 **항상** 빈 값으로 보낸다.
    그걸 스팸으로 세면 **모든 진짜 신청이 성공 메시지와 함께 버려지고** 증상은
    「관리 목록이 안 늘어난다」뿐이다. 전용 테스트를 뒀다.
  - **IP당 10분 3회**. IP 는 **캐시 키에만** 쓰고 DB 에 어떤 형태로도 쓰지 않는다.
- 알림 메일 `JpPilotMailer#pilot_requested`, 제목 `[SafeFile JP] パイロット申込`.
  메일 enqueue 실패는 **201 을 바꾸지 않는다** — 행이 정본이고, SMTP 는 이 앱에서
  실제로 죽은 적이 있다(2026-04-07 `GMAIL_PASSWORD` 빈 값 → 535-5.7.8).
- 관리: `/admin/jp_pilot_requests` **읽기 전용** 목록 + 사이드바 링크.
  읽기 전용인 이유: 알림이 유실될 수 있는 채널이므로 이 목록이 유실될 수 없는 채널이어야 하고,
  지우거나 고칠 수 없는 목록은 신청을 잃을 수도 없다. 후속 이력은 `outreach_log.md`(git).

### 익명 계측 (`POST /api/safe_events`) — 개인정보 0

`SafeEvent` 가 **저장 가능한 이벤트의 모양을 단독으로 정의**한다. 컨트롤러·집계 레이크·테스트가
전부 같은 상수를 읽는다(사본을 두면 갈라진다는 것을 이 저장소가 반복해 배웠다).

| 이벤트 | 허용 키 |
|---|---|
| `upload` | ext, pages, locale, from |
| `doc_class` | doc_class, locale, from |
| `purpose` | purpose, doc_class, locale, from |
| `download` | format, doc_class, purpose, locale, from |
| `landing_view` | from, locale |
| `cta_click` | from, purpose, locale |

값도 전부 고정 목록(`doc_class` 6종 / `purpose` 4종 / `format` 3 / `locale` 4 / `from` 4 /
`ext` 5 / `pages` 4). **키가 하나라도 화이트리스트 밖이면 이벤트 전체를 거부한다**(422, 부분 저장 없음) —
일부만 저장된 행은 「일어나지 않은 일」을 데이터처럼 기록하고, `sendBeacon` 은 응답을 읽지 않으므로
조용한 누락은 양쪽에서 보이지 않는다.

**하지 않는 것**(코드로 못 박음):
- `request.remote_ip` 를 **읽지 않는다.** 저장도 해시도 레이트리밋 키도 아니다.
  IP 해시도 결국 방문자 식별자다. 대신 **엔드포인트 전체**에 분당 600건 상한을 둔다 —
  누가 하는지 구별할 수 없는 것이 이 교환의 핵심이고, 그래서 상한을 넉넉히 뒀다.
- 쿠키·세션을 쓰지 않는다. 자유 텍스트·좌표·파일명·페이지 내용을 받지 않는다.
- 전용 테스트: `filename`·`text`·`box`·`ip`·`visitor_id`·`pages:"17"` 6종이 전부 422 임을 단언하고,
  **테이블 컬럼이 `id, name, props, created_at` 넷뿐**임을 단언한다(식별 가능한 열이 생기면
  `/safe/` 와 랜딩 3페이지의 약속이 거짓이 되므로, 스타일이 아니라 약속이다).

### `/safe/index.html` 최소 변경 (탐지 로직 **무변경**)

| 추가 | 무엇 |
|---|---|
| `SF_PARAMS` | `?lang` `?purpose` `?from` 을 읽는 **읽기 전용** 3값. `from` 은 `nyusatsu\|honnin\|aimae` 아니면 `direct` |
| `detectLang()` | **명시적 `?lang=` 이 localStorage 보다 앞선다.** 랜딩은 일본어 전용이라, 몇 달 전에 고른 언어로 떨어지면 안 된다 |
| `JP_PURPOSE0` | `JP_STATE0()` 의 초기 목적. **`resetAll()` 이후에도 유지**된다 — 「다른 문서」는 입찰 담당자가 가장 많이 누르는 버튼이고, 거기서 목적이 조용히 되돌아가면 안 된다 |
| `sfEvent()` + 호출 6곳 | `sendBeacon`, 실패는 전부 삼킨다 |

`jpSetPurpose` 는 `JP_PURPOSES` 로 검증하므로 쓰레기 값은 무시된다(실측: `?purpose=../../etc`
→ `identity_submit`). **탐지·마스킹 코드는 한 줄도 건드리지 않았고, 골든 557/557 이 그대로다.**

`download` 이벤트는 **분류된 JP 문서일 때만** `purpose` 를 보낸다. `jpState.purpose` 는 JP
프리셋이 돌지 않아도 기본값을 갖고 있어서, 무조건 보내면 목적 통계가 「목적이 없던 문서」로 부풀어진다.

### 집계 `bin/rails safe:jp_weekly[2026-W43]`

`docs/jp/metrics/YYYY-WW.md` 에 쓴다. 그룹 기준을 `SafeEvent::KEYS` 에서 **파생**하므로
모델에 키를 추가하면 보고서도 따라온다(하드코딩하면 낡은 모양을 계속 완성된 얼굴로 보고한다).
0건일 때는 **세 가지 가능성(트래픽 없음 / 엔드포인트 422 / 배포본에 계측 없음)을 나란히 적는다** —
0 을 「조용한 성공」으로 읽지 않게 하려는 장치다. 주차 라벨은 `%G-W%V`(ISO) 이고 파일명이 되므로
**정규화하지 않고 검증한다**(조용히 고치면 맞게 생긴 보고서가 틀린 주에 쓰인다).

---

## 2. 파일 목록

**신규**
```
public/safe/jp/jp.css · jp.js
public/safe/jp/nyusatsu/index.html · honnin-kakunin/index.html · ai-mae/index.html
app/models/safe_event.rb · jp_pilot_request.rb
app/controllers/api/safe_events_controller.rb · jp_pilot_controller.rb
app/controllers/admin/jp_pilot_requests_controller.rb
app/views/admin/jp_pilot_requests/index.html.erb
app/mailers/jp_pilot_mailer.rb · app/views/jp_pilot_mailer/pilot_requested.html.erb
db/migrate/20261022000100_create_jp_pilot_requests.rb
db/migrate/20261022000200_create_safe_events.rb
lib/tasks/safe.rake
test/controllers/api/safe_events_controller_test.rb · jp_pilot_controller_test.rb
test/support/cache_store_helper.rb
test/safe/jp_landing_check.mjs
docs/jp/outreach_log.md · docs/jp/metrics/README.md · docs/jp/metrics/2026-W43.md
docs/jp/s6_report.md
```

**수정**
```
public/safe/index.html        — SF_PARAMS · detectLang · sfEvent + 호출 6곳 (탐지 무변경)
lib/canonical_path_redirect.rb — DIRS 에 랜딩 3개
config/routes.rb              — POST /api/jp_pilot · /api/safe_events · admin 목록
app/views/pages/sitemap.xml.erb — 랜딩 3개 (hreflang 없음)
app/views/layouts/admin.html.erb — 사이드바 「JP パイロット」
config/locales/ko.yml         — activerecord 메시지 invalid/too_long/too_short/not_a_number + jp_pilot_request 속성명
script/canonical_sweep.rb     — STATIC_DIRS·에셋 변이에 랜딩 추가
test/lib/canonical_path_redirect_test.rb  — DIRS 파생 대조 + 랜딩 철자 4개 테스트
test/integration/canonical_urls_test.rb   — sitemap·canonical·hreflang 3개 테스트
db/schema.rb                  — 마이그레이션 2건
```

라우트 2개 추가:
```
POST /api/jp_pilot     → api/jp_pilot#create
POST /api/safe_events  → api/safe_events#create
GET  /admin/jp_pilot_requests → admin/jp_pilot_requests#index
```

---

## 3. 로컬 확인 방법

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac. 앱 기동(Docker)

```
docker compose up -d
```

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac. 마이그레이션

```
docker compose exec web bin/rails db:migrate
```

브라우저로 열 3개 URL:

```
http://localhost:3001/safe/jp/nyusatsu/
http://localhost:3001/safe/jp/honnin-kakunin/
http://localhost:3001/safe/jp/ai-mae/
```

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac. 파일럿 폼 POST

```
curl -s -w '\n%{http_code}\n' -X POST http://localhost:3001/api/jp_pilot -H 'content-type: application/json' -d '{"company":"○○建設株式会社","industry":"construction","monthly_count":"3-5","authority":"○○県 ○○市","email":"office@example.co.jp","from":"nyusatsu","website":""}'
```

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac. 계측 엔드포인트 POST

```
curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:3001/api/safe_events -H 'content-type: application/json' -d '{"name":"doc_class","props":{"doc_class":"shikaku_kakuninsho","locale":"ja","from":"nyusatsu"}}'
```

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac. 화이트리스트 밖은 422 여야 한다

```
curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:3001/api/safe_events -H 'content-type: application/json' -d '{"name":"upload","props":{"ext":"pdf","filename":"健康保険証.pdf"}}'
```

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac. 주차 집계

```
docker compose exec web bin/rails safe:jp_weekly
```

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack/test/safe` — 로컬 Mac. 랜딩·폼·계측 라이브 하네스

```
node jp_landing_check.mjs
```

⚠️ 이 하네스는 파일럿 폼을 **4회** POST 하고 마지막 1회가 429(IP당 3회 상한)임을 단언한다.
직전에 폼을 손으로 눌렀다면 상한을 이미 쓴 상태이므로 **먼저 `docker compose restart web`**
으로 리미터(dev = memory_store)를 비운다. 하네스는 첫 요청이 429 면 그 이유를 적고 실패한다.

---

## 4. 검증 결과 (전부 로컬 실측)

| 검증 | 결과 |
|---|---|
| `bin/rails test` | **186 runs / 1404 assertions / 0 failures** (직전 159/1218) |
| 신규 `test/controllers/api/safe_events_controller_test.rb` | 10개 |
| 신규 `test/controllers/api/jp_pilot_controller_test.rb` | 10개 |
| 확장 `test/lib/canonical_path_redirect_test.rb` | 30개 / 303 단언 (직전 26개) |
| 확장 `test/integration/canonical_urls_test.rb` | 18개 / 307 단언 (직전 15개) |
| **골든 `node test/safe/run.mjs`** | **557/557 pass, 0 FAIL** — S3d 와 동일 |
| **SW 결함 주입 `test/sw/offline_resilience.mjs`** | **9/9** |
| `script/canonical_sweep.rb` | 115 철자 / **중복 200 = 0** / 홉 `{1=>88, 2=>2}` / sitemap 33 / 6개 검사 전부 통과 |
| 신규 `test/safe/jp_landing_check.mjs` | **102/102** |
| rubocop (전체) | **86건 — 베이스라인과 동일. 신규 위반 0** |
| brakeman | 경고 6 / exit 0 — 기존과 동일 |
| 프로덕션 DB | **미접촉** |

### 변이 프로브 — 새 단언이 공허하지 않음을 실측

| 변이 | 결과 |
|---|---|
| `jp.js` 의 `landing_view` 비콘 제거 + nyusatsu H1 을 「絶対」가 든 문구로 교체 | **91 pass / 11 FAIL** — H1 동일성 1, 금지어 1, landing_view 3페이지 ×3 |
| `DIRS` 에서 `/safe/jp/ai-mae` 제거 | **test/lib 2건 실패** (파생 대조 + 철자 4개) |
| 캐시 상한 테스트를 null_store 로 | 「상한이 발화하지 않는다」 가드 테스트가 그 사실을 고정 |

### 하네스를 만들다 잡은 자기 결함 2건

1. 🔴 **`sendBeacon` 의 payload 는 Playwright 에서 읽을 수 없다.** `postData()` 와
   `postDataBuffer()` 가 **둘 다 null** 이다(실측). 처음 하네스는 그것을 `{}` 로 파싱해
   「landing_view 0건」으로 **빨간불**을 냈는데, 같은 시점 DB 에는 행이 정확히 들어와 있었다.
   → 페이지 안에서 `navigator.sendBeacon` 을 감싸 payload 를 기록하고 **원본에 위임**한다.
   그리고 payload 만으로는 「페이지가 보내려 한 것」만 증명되므로 **응답 204**(= 서버
   화이트리스트가 받아들였다는 서버 쪽 동의)를 함께 단언한다.
2. **CTA 클릭 카운터가 0으로 보이던 것**은 내비게이션이 실제로 일어나 payload 배열이
   새 문서에서 빈 채로 다시 만들어졌기 때문이다. 캡처 단계 `preventDefault` 로 **내비게이션만**
   취소해 jp.js 의 버블 리스너는 그대로 돌게 했다. 「측정 대상이 사라져서 0」과
   「발화하지 않아서 0」은 밖에서 같아 보인다.

### 라이브 중 잡은 실제 결함 1건 (수정 완료)

**메일 형식 검증 실패 메시지가 신청자에게 영어 섞인 조회 흔적으로 나갔다.** 실측:

```
{"ok":false,"errors":["EmailTranslation missing. Options considered were:\n- ko.activerecord.errors.models…"]}
```

`config/locales/ko.yml` 의 `activerecord.errors.messages` 에 `invalid`·`too_long` 이 **없었다**
(2026-09-18 에 presence·uniqueness·inclusion 만 넣었다). 두 겹으로 고쳤다:

- 컨트롤러가 **필드 이름만** 돌려준다(`["company","industry","email"]`). 일본어 페이지가 자기
  문구를 갖고(`jp.js` 의 `FIELD_JA`) 렌더한다 → **서버 로케일이 일본어 페이지에 나타날 경로를
  없앴다.** 한 사례를 고치는 것이 아니라 그 종류를 불가능하게 만든 것.
- ko.yml 에 `invalid`·`too_long`·`too_short`·`not_a_number` + `jp_pilot_request` 속성명 추가.
  신청자는 이 문자열을 보지 않지만 **로그와 콘솔은 본다**. 확인:
  `회사명을(를) 입력해 주세요 | 업종에 허용되지 않는 값이 들어왔습니다 | 연락처 메일의 형식이 올바르지 않습니다`
- 하네스가 에러 메시지에 `Translation missing` 과 **한글이 없음**을 단언한다.

---

## 5. 미완·판단 보류 (다음 라운드)

### 이번에 정본 문안에 **더한** 것 3곳 — 문구 변경이 아니라 추가다

1. 세 페이지 모두에 `提出先の指示を必ず確認してください。` 1줄.
   정본의 공통 규칙이 「모든 페이지에」 요구하는 문장이고, 페이지 1 은 본문에
   `※ 提出先の指示が優先です` 만 갖고 있었다.
2. `ai-mae` 의 「30日パスを買う」 밑에 `※ 決済は準備中です。…` 1줄.
   **결제가 아직 없다**(Stripe JP 상품 미생성 — 예측 보고서 §8 의 미완 항목).
   아무 데도 가지 않는 구매 버튼이 더 나쁘다고 판단했다. 버튼은 메일 링크로 연결했다.
3. 폼 성공/실패 안내 문구(`jp.js`) — 정본에 없는 UI 문자열이다.

→ **세 건 다 사람 확인 대상.** 정본을 고치든 페이지를 고치든, 둘이 갈라진 상태로 두지 않는다.

### 하지 않은 것

- **Stripe JP 상품 2개**(月額¥2,980 / 30日パス¥980) 미생성 — 외부 계정 작업이라 범위 밖.
  `ai-mae` 의 구매 CTA 는 그래서 메일이다.
- **Search Console JA 랜딩 등록** — 배포 후에만 가능.
- **`purpose` 이벤트가 초기화 때도 1건 발생한다.** 랜딩에서 `?purpose=` 로 들어오면
  `jpSetPurpose` 가 init 에서 한 번 불리고 `doc_class:"none"` 으로 1건이 남는다.
  `from` 이 붙어 있어 귀속은 되지만, 「사용자가 드롭다운을 바꿨다」와 구별되지 않는다.
  → 집계에서 `doc_class=none` 을 분리해 읽거나 이벤트 이름을 쪼갤지는 다음 판단.
- **`safe_events` 보존 기간 정책 없음.** 행이 무한히 쌓인다. 식별 정보가 없으므로 개인정보
  보관 문제는 아니지만, 90일 롤오프를 넣을지는 결정 사항.
- **`/safe/jp/` 가 301 → 404 2홉**(위 §1). 수용했고 sweep 대상에서 제외했다.
- **`safe_events` 의 전역 상한은 누가 보냈는지 구별하지 못한다.** 단일 클라이언트가 분당
  600건을 쏘면 그 분의 모든 정상 이벤트가 429 로 떨어진다. IP 를 안 보기로 한 대가이고,
  그래서 상한을 넉넉히 뒀다. 실제로 문제가 되면 **엣지(프록시) 레이어**에서 막을 일이다.
- **메일 전달 자체는 검증하지 않았다**(dev SMTP 없음). 테스트는 `perform_enqueued_jobs` 로
  **렌더·발송까지** 돌려 템플릿이 터지지 않음을 확인한다. 프로덕션 SMTP 는 배포 후 확인 항목.
- **`jp_pilot_requests` 에 행 수 상한이 없다.** 선착 10사 모집이지만 10건째에 폼이 닫히지
  않는다 — 마감 처리는 사람 판단(문안을 바꿀 일).
