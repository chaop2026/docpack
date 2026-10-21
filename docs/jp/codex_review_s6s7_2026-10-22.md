warning: `--full-auto` is deprecated; use `--sandbox workspace-write` instead.
2026-10-21T19:22:04.326481Z ERROR codex_models_manager::cache: failed to load models cache: missing field `base_instructions` at line 139 column 5
OpenAI Codex v0.146.0
--------
workdir: /Users/sunghoon/Projects/docpack
model: gpt-5.6-sol
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR]
reasoning effort: none
reasoning summaries: none
session id: 01a15fe9-ddd7-78d0-b0f5-055ed4e9e2c0
--------
user
# Codex 교차검증 요청 — SafeFile JP S6 + S7

## 이 라운드가 무엇인지

JP-1 알파(탐지·마스킹)가 S3d 에서 닫힌 뒤의 **첫 시장 접촉 라운드**다. 탐지 로직은
건드리지 않았다. 두 커밋을 본다:

| 커밋 | 내용 |
|---|---|
| `5a320b5` | S6 — 일본어 랜딩 3페이지 · 파일럿 신청 폼 · 익명 계측 엔드포인트 |
| `e46e128` | S7 — 콘텐츠 33편 계획 · 반자동 파이프라인 · 첫 3편 |

보고서: `docs/jp/s6_report.md` · `docs/jp/s7_report.md`
문안 정본: `docs/jp/jp_landing_copy_2026-10-22.md`
**미배포·미푸시·미게시. 프로덕션 DB 미접촉.**

---

## 🔴 검토 범위 — 반드시 이 네 가지만

판정해야 하는 질문은 네 개다. **이 밖의 지적은 백로그로만 기록하고 AMBER 로 올리지
마십시오.**

### Q1. 파일럿 폼은 스팸과 잘못된 입력을 실제로 막는가

- `app/controllers/api/jp_pilot_controller.rb` · `app/models/jp_pilot_request.rb`
- `public/safe/jp/nyusatsu/index.html` (폼 마크업) · `public/safe/jp/jp.js` (제출)
- `test/controllers/api/jp_pilot_controller_test.rb`

판정해야 할 것:

1. **honeypot 이 성공과 구별되지 않는가.** 채워진 `website` → 행을 쓰지 않고 **201**.
   응답 본문·헤더·타이밍 어디에도 구별 신호가 남지 않는지.
2. **빈 honeypot 이 스팸으로 세어지지 않는가.** 실제 브라우저는 이 필드를 항상 빈 값으로
   보낸다. 그걸 스팸으로 세면 **모든 진짜 신청이 성공 메시지와 함께 버려지고** 증상은
   「관리 목록이 안 늘어난다」뿐이다. 전용 테스트가 있는데 그 테스트가 공허하지 않은지.
3. **IP 당 10분 3회 상한이 실제로 동작하는가.** `config/environments/test.rb` 가
   `:null_store` 라서, 상한 테스트가 `test/support/cache_store_helper.rb` 로 메모리 스토어를
   끼워 넣는다. 그 가드(「캐시가 기억하지 않으면 상한이 발화하지 않는다」 테스트)가
   실제로 공허한 통과를 막는지. 프로덕션은 `:solid_cache_store`(DB 백엔드, 프로세스 공유).
4. **서버 검증이 실제로 좁은가.** `industry`·`monthly_count` 가 select 선택지 집합으로
   제한되는지, `company`·`email`·`authority` 길이 상한, 메일 형식 정규식
   (`JpPilotRequest::EMAIL_RE`)이 과도하게 느슨하거나 엄격하지 않은지.
5. **`from` 만 검증 실패 대신 `direct` 로 떨어뜨리는 판단이 옳은가.** 신청자가 입력한 값이
   아니라 마케팅 귀속 힌트이고, 낡은 링크 하나가 진짜 신청을 날려서는 안 된다는 근거다.
6. **메일 실패가 신청을 잃지 않는가.** `notify` 가 `deliver_later` **호출만** rescue 한다.
   ⚠️ 이 저장소는 같은 모양의 지적을 받은 적이 있다 — `PublishScheduledPostsJob` 의 알림이
   메일 전달 성공에 의존했고(2026-09-18 Codex AMBER B-1), **파생 상태**(`publish_stuck`)로
   닫았다. 여기서는 `/admin/jp_pilot_requests` 가 그 역할을 한다는 주장이다.
   **그 주장이 성립하는지** 판정해 주십시오 — 구체적으로, 메일 잡이 렌더/SMTP 단계에서
   죽으면 그 사실을 아무도 못 보게 되는데, 행 자체는 남으므로 「유실」이 아닌지.
7. CSRF 를 skip 한다(`skip_before_action :verify_authenticity_token`). JSON 엔드포인트라는
   근거가 충분한지, 아니면 origin 검사가 필요한지.

### Q2. 계측 엔드포인트는 개인정보를 **0** 으로 저장하는가

- `app/models/safe_event.rb` (화이트리스트 정본) · `app/controllers/api/safe_events_controller.rb`
- `db/migrate/20261022000200_create_safe_events.rb`
- `public/safe/index.html` 의 `sfEvent` / `SF_PARAMS` / 호출 6곳
- `public/safe/jp/jp.js` 의 `beacon`
- `test/controllers/api/safe_events_controller_test.rb`

판정해야 할 것:

1. **저장되는 모든 경로를 열거했을 때, 자유 텍스트·좌표·파일명·페이지 내용·식별자가
   들어갈 틈이 있는가.** 특히 `SafeEvent.sanitize` 가 `v.to_s` 로 문자열화한 뒤 고정 목록에
   대조하는 방식이, 중첩 해시/배열/`ActionController::Parameters` 같은 입력에서 새지 않는지.
2. **컨트롤러가 클라이언트가 보낸 키를 그대로 sanitize 에 넘기는 판단**(알려진 키만 걸러
   넘기지 않는 것)이 옳은가. 근거는 「걸러 넘기면 드리프트가 성공으로 보이고 `sendBeacon` 은
   응답을 읽지 않으므로 양쪽에서 안 보인다」.
3. **`request.remote_ip` 를 읽지 않는다는 주장이 코드로 참인가.** 저장·해시·레이트리밋 키
   어디에도 없는지. 대신 둔 **전역 분당 600건 상한**이 (a) 실제로 동작하는지 (b) 단일
   클라이언트의 폭주가 다른 모두의 이벤트를 429 로 떨어뜨리는 교환이 수용 가능한지.
4. **테이블 컬럼이 `id, name, props, created_at` 넷뿐**이라는 단언이 실제 스키마와 맞는지.
   `updated_at` 이 없는 것이 ActiveRecord 에서 문제를 일으키지 않는지.
5. **쿠키·세션을 건드리지 않는가.** ⚠️ **이 프롬프트를 쓰다가 실제 결함을 찾아 고쳤다.**
   실측(수정 전): `POST /api/safe_events?locale=ja` → `204` **+ `Set-Cookie: locale=ja`,
   만료 1년**. `ApplicationController#set_locale` 은 `params[:locale]` 이 있으면 쿠키를
   쓰는데 `params` 에는 쿼리스트링이 포함된다. 라우트에 `:locale` 세그먼트가 없다는 사실만
   확인하고 **쿼리스트링을 보지 않은 것**이 우리 실수다.
   → `Api::BaseController`(신규)가 `/api/` 세 엔드포인트 전부에서 `set_locale` 과
   CSRF 검증을 skip 한다. 회귀 테스트 2개(쿠키 0 / 로케일 페이지는 **여전히** 쿠키를 심는다 —
   두 번째가 없으면 첫 번째가 잘못된 이유로 통과한다). 변이로 확인: skip 을 빼면 1건 실패.
   **판정 요청**: ① 이 수정이 완전한가(다른 before_action 이 남아 있지 않은가)
   ② `safe_scan` 까지 묶은 판단이 옳은가(그쪽은 locale 의존 출력이 없다는 근거)
   ③ CSRF skip 을 공통 base 로 올린 것이 범위를 넓힌 것은 아닌가.
6. **집계 레이크(`lib/tasks/safe.rake`)가 개인정보를 재구성할 수 있는가.** 그룹 기준을
   `SafeEvent::KEYS` 에서 파생하는데, 교차 집계로 개인을 좁힐 여지가 있는지
   (현재 식별자가 없으므로 불가능하다는 주장).
7. **`purpose` 이벤트가 init 에서 1건 발생**한다(`?purpose=` 로 들어올 때, `doc_class:"none"`).
   「사용자가 드롭다운을 바꿨다」와 구별되지 않는데, 이것이 데이터 품질 문제인지
   개인정보 문제인지.

### Q3. 랜딩 문구가 정본과 일치하는가

- 정본: `docs/jp/jp_landing_copy_2026-10-22.md`
- 페이지: `public/safe/jp/{nyusatsu,honnin-kakunin,ai-mae}/index.html`
- 하네스: `test/safe/jp_landing_check.mjs` (102 단언, 전부 통과)

판정해야 할 것:

1. **title / meta description / H1 / リード / 표 / 섹션 본문이 정본과 글자 단위로 같은가.**
   하네스가 H1 전문과 본문 6~7개 구절을 문자열 동일성으로 단언하지만, **단언하지 않은
   구절**이 드리프트했을 수 있다. 전수 대조를 요청한다.
2. **우리가 정본에 더한 3곳이 적절한가** (s6_report §5 에 명시):
   - 세 페이지에 `提出先の指示を必ず確認してください。` 1줄 — 정본의 공통 규칙이 요구하는데
     페이지 1 본문엔 `※ 提出先の指示が優先です` 만 있었다
   - `ai-mae` 의 「30日パスを買う」 밑에 `※ 決済は準備中です。…` — **Stripe JP 상품이 아직
     없다**. 아무 데도 가지 않는 구매 버튼이 더 나쁘다는 판단
   - 폼 성공·실패 안내 문구(`jp.js`) — 정본에 없는 UI 문자열
   세 건 모두 **문구 변경이 아니라 추가**라는 주장이다. 판정해 주십시오.
3. **공통 금지 규칙 위반이 없는가**: 사건명(`タイムズカー`) · `絶対`/`防ぐ`/`唯一` ·
   법적 효과를 「制限される場合があります」 수준을 넘어 단정하는 표현.
4. **EN 병기가 정본의 EN 블록과 같은가**, 그리고 **접이식 `<details>` 로 같은 URL 안에 둔
   판단**(= `?lang=en` 토글을 쓰지 않은 것)이 옳은가. 근거는 토글이면 같은 내용이 두 주소로
   서빙되어 이 저장소가 두 라운드에 걸쳐 고친 중복을 새로 만든다는 것.
5. **hreflang 0개 판단.** `/about`(영어 단일 문서)와 같은 판정이라는 주장. 한 URL = 한
   일본어 문서이고 영어는 그 URL 안에 있으므로 `en` 알터네이트는 존재하지 않는 URL 을
   가리키고 `x-default` 자기참조는 거짓이라는 근거.
6. **CTA 링크의 `purpose`/`from`/`lang` 이 계측 이벤트의 값과 일치하는가**
   (`data-purpose` 와 href 쿼리가 두 군데 따로 쓰여 있다).

### Q4. 콘텐츠 금지 규칙 위반이 있는가

- 규칙 정본: `docs/jp/jp_safefile_strategy_v2_2026-10-21.md` §6 원칙 ·
  `docs/jp/jp_market_decision_v2_2026-10-22.md` §4 · `content/jp/topics.json` 의 `_forbidden`
- 검사 구현: `scripts/content/make_episode.mjs` 의 `FORBIDDEN` / `MUST_LINE`
- 대상 원고: `content/jp/ep0{1,2,3}/post_ja.md` · `post_en.md` · `x_thread.md` ·
  `carousel_*.png`(`docs/jp/s7_samples/` 에 사본)

판정해야 할 것:

1. **ep01~03 본문(JA·EN 양쪽)에 금지 규칙 위반이 있는가.** 사건명 · `絶対/防ぐ/唯一/必ず安全` ·
   1인칭 피해담 · 미구현 기능(일괄처리) 홍보 · 법적 효과 단정.
   ⚠️ **EN 본문은 코드 가드가 검사하지 않는다**(정규식이 일본어 문자열 기준) — 사람(=당신)이
   볼 수밖에 없는 지점이다.
2. **「모든 How-to 에 `提出先の指示を必ず確認してください`」가 실제로 모든 산출물에 있는가.**
   본문은 가드가 강제하지만 **x_thread 와 캐러셀에는 본문 가드가 미치지 않는다**
   (캐러셀은 하단 크롬으로 항상 출력된다는 주장 — 확인 요청).
3. **가드가 있는 규칙과 없는 규칙의 구분이 정확한가.** 우리는 「1인칭 피해담 금지」와
   「더미 카드 축소 삽화(긴 변 ≤800px)」는 정규식으로 판정할 수 없어 사람이 지킨다고
   적었다. 자동화 가능한데 포기한 것은 없는지.
4. **`topics.json` 의 33편이 전략 v2 §6 + 시장결정 v2 §4 를 정확히 반영하는가.**
   1·14·20 재작성 · 신규 3편 · 「1층·資格確認書 앞」 · 「AI 익명화 2편 4주 안」.
   `src` 필드로 원래 번호를 추적할 수 있다.
5. **ep32 를 `blocked_until` 로 빌드 거부하는 판단**이 「미구현 기능 홍보 금지」의 올바른
   구현인지, 아니면 목록에서 지우는 편이 나은지.
6. **ep05·ep06(電子入札の容量制限 / 補助金精算)의 근거가 약하다는 자기 신고**가 맞는지.
   우리는 본문을 쓰기 전에 발주처 공고 1건 확인이 필요하다고 적었다.

---

## 우리가 확신하지 못하는 지점 (먼저 밝힌다)

지난 라운드들에서 **이 목록에 올린 항목이 실제로 (a) 로 확정된 전례**가 있으므로 솔직히 적는다.

1. **`notify` 의 rescue 범위.** `deliver_later` 호출만 감싼다. 그 뒤 메일 잡의 렌더/SMTP
   실패는 `solid_queue_failed_executions` 로 가고 아무도 안 본다. 행은 남으므로 「신청
   유실」은 아니지만, **「알림이 왔어야 하는데 안 왔다」를 알 방법이 없다.**
   확인한 것: `config/application.rb:33` 이 `config.action_mailer.delivery_job` 을
   `ApplicationMailDeliveryJob` 으로 전역 설정하므로 `JpPilotMailer` **도 그 경로를 탄다**
   (일시적 SMTP 오류 5회 재시도, 영구 거부는 로그 후 re-raise). 확신이 없는 것은 그 다음이다 —
   re-raise 된 뒤 `solid_queue_failed_executions` 를 읽는 것은 `rake jobs:failed` 뿐이고
   **그것은 사람이 돌려야 보인다.** 블로그 쪽은 그 공백을 파생 상태(`publish_stuck`)로 닫았는데,
   파일럿 신청에는 그에 해당하는 파생 상태가 없다(행이 남는 것으로 충분한가?).
2. **전역 분당 600건 상한의 숫자 근거가 없다.** 「조직적 사용보다 훨씬 위」라고 썼지만
   측정한 값이 아니다. 실제 트래픽이 0인 상태라 추정의 근거가 추정이다.
3. **`SafeEvent.sanitize` 의 `v.to_s`.** `ActionController::Parameters` 중첩 객체가
   `to_s` 로 무엇이 되는지는 테스트 1건(중첩 해시)만 확인했다. 배열·파일 업로드·
   `nil` 등 다른 모양을 전수로 보지 않았다.
4. **`?purpose=` 가 init 에서 `jpSetPurpose` 를 부르면서 발생하는 `purpose` 이벤트 1건.**
   데이터가 오염되는 방향인데, 이벤트 이름을 쪼갤지 집계에서 거를지 정하지 않았다.
5. **`/safe/jp/` 가 301 → 404 로 2홉**인 것. 수용했고 sweep 에서 제외했지만, 색인 신호로서
   문제가 없다고 단정할 만큼 확인하지 않았다.
6. **캐러셀 템플릿이 Google Fonts 를 네트워크에서 받는다.** 오프라인 빌드에서는 Hiragino 로
   떨어지므로 **같은 원고가 환경에 따라 다른 이미지**를 낸다. 폰트를 임베드하지 않은 판단이
   옳은지 확신이 없다.
7. **생성물(PNG/GIF/MP4)을 git 에 커밋하는 판단.** 3편에 1.6MB, 33편이면 30MB 전후.
   「올린 자산을 그대로 보관하는 편이 유용」하다고 봤지만 재생성이 바이트 단위로
   결정적이지 않다는 점(폰트·브라우저 버전)이 그 주장을 약하게 만든다.

---

## 검증 상태 (우리가 이미 돌린 것 — 다시 돌릴 필요 없음)

| 검증 | 결과 |
|---|---|
| `bin/rails test` | 186 runs / 1404 assertions / 0 failures (직전 159/1218) |
| 골든 `node test/safe/run.mjs` | **557/557, 0 FAIL** — S3d 와 동일(탐지 무변경 확인) |
| SW 결함 주입 `test/sw/offline_resilience.mjs` | 9/9 |
| `script/canonical_sweep.rb` | 115 철자 / 중복 200 = 0 / 홉 `{1=>88, 2=>2}` / sitemap 33 |
| `test/safe/jp_landing_check.mjs` | 102/102 |
| rubocop | 86건 — 베이스라인과 동일, 신규 0 |
| brakeman | 경고 6 / exit 0 — 기존과 동일 |
| 변이 프로브 (S6) | 비콘 제거 + H1 드리프트 → 11 실패 · `DIRS` 1개 제거 → 2 실패 |
| 변이 프로브 (S7) | 금지어 exit 1 · 필수 문장 누락 exit 1 · blocked exit 2 · 없는 회차 exit 2 |

**공허한 단언이 있는지**도 함께 봐 주십시오. 특히:
- `jp_landing_check.mjs` 가 `sendBeacon` payload 를 **페이지 안에서 가로채** 읽는 방식
  (Playwright 의 `postData()`/`postDataBuffer()` 가 Blob 에 대해 둘 다 null 이라 그렇게 했다).
  payload 단언과 **응답 204 단언**이 둘 다 필요한 이유를 우리는 「payload 만으로는 페이지가
  *보내려 한 것*만 증명된다」고 적었다 — 그 논증이 성립하는지.
- `safe_events_controller_test.rb` 의 「테이블 컬럼이 넷뿐」 단언.
- `canonical_path_redirect_test.rb` 의 **DIRS 파일시스템 파생 대조**.

---

## 출력 형식

지난 라운드와 같게:

1. **Q1~Q4 각각에 대해 `닫힘` / `부분` / `열림` 판정**과 근거(파일·줄 번호).
2. **새 (a) 지적**은 AMBER/GREEN 등급과 함께, **재현 방법을 포함해서.**
   (a) 는 **Q1~Q4 범위 안에서만** 올려 주십시오.
3. 그 밖의 발견은 **백로그**로 분류해 목록만.
4. **우리가 「확신하지 못한다」고 밝힌 7건**에 대한 판정을 별도 절로.
5. 읽지 못한 파일이 있으면 **경로 요청**으로 명시해 주십시오.

**수정은 하지 마십시오.** 이 라운드는 판정만 받고, 고치는 것은 다음 런입니다.
warning: Skill descriptions were shortened to fit the 2% skills context budget. Codex can still see every skill, but some descriptions are shorter. Disable unused skills or plugins to leave more room for the rest.
hook: SessionStart
hook: SessionStart Completed
hook: UserPromptSubmit
hook: UserPromptSubmit Completed
codex
요청 범위를 Q1~Q4로 고정해 두 커밋과 현재 트리를 읽기 전용으로 대조하겠습니다. 테스트는 재실행하지 않고, 구현·테스트의 공허성·문안 전수 대조·생성물까지 증거 줄 번호 중심으로 보겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
  → 두 커밋 변경 범위와 관련 파일·스키마 구조 확인
  • Q1 폼·검증·메일·CSRF 구현과 테스트 판정
  • Q2 계측·PII·캐시·쿠키·집계 구현과 테스트 판정
  • Q3 정본과 3개 랜딩 페이지·CTA·EN 전수 대조
  • Q4 전략 문서·33편 계획·원고·X·캐러셀·가드 대조
  • 7개 불확실성 및 공허한 단언을 종합해 보고서 작성
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'git status --short && git show --stat --oneline --decorate --no-renames 5a320b5 && git show --stat --oneline --decorate --no-renames e46e128 && rg --files app/controllers/api app/models test/controllers/api test/support public/safe/jp docs/jp content/jp scripts/content lib/tasks db/migrate | sort' in /Users/sunghoon/Projects/docpack
 succeeded in 224ms:
5a320b5 feat(safe): JP S6 — 랜딩 3페이지 + 파일럿 폼 + 익명 계측(개인정보 0)
 CLAUDE.md                                          |  79 ++++
 .../admin/jp_pilot_requests_controller.rb          |  13 +
 app/controllers/api/jp_pilot_controller.rb         |  82 ++++
 app/controllers/api/safe_events_controller.rb      |  83 ++++
 app/mailers/jp_pilot_mailer.rb                     |  18 +
 app/models/jp_pilot_request.rb                     |  28 ++
 app/models/safe_event.rb                           |  90 +++++
 app/views/admin/jp_pilot_requests/index.html.erb   |  37 ++
 app/views/jp_pilot_mailer/pilot_requested.html.erb |  49 +++
 app/views/layouts/admin.html.erb                   |   1 +
 app/views/pages/sitemap.xml.erb                    |  14 +
 config/locales/ko.yml                              |  19 +
 config/routes.rb                                   |  13 +
 .../20261022000100_create_jp_pilot_requests.rb     |  18 +
 db/migrate/20261022000200_create_safe_events.rb    |  18 +
 db/schema.rb                                       |  21 +-
 docs/jp/codex_prompt_market.md                     |   9 +
 docs/jp/codex_review_market_2026-10-22.md          | 441 +++++++++++++++++++++
 docs/jp/jp_forecast_report_2026-10-22.md           |  82 ++++
 docs/jp/jp_landing_copy_2026-10-22.md              | 166 ++++++++
 docs/jp/jp_market_brief_2026-10-22.md              |  63 +++
 docs/jp/jp_market_decision_v2_2026-10-22.md        |  65 +++
 docs/jp/metrics/2026-W43.md                        |  21 +
 docs/jp/metrics/README.md                          |  20 +
 docs/jp/outreach_log.md                            |  46 +++
 docs/jp/s5_live_check_2026-10-22.md                |  17 +
 docs/jp/s6_prompt.md                               |  32 ++
 docs/jp/s6_report.md                               | 341 ++++++++++++++++
 docs/jp/s7_prompt.md                               |  35 ++
 lib/canonical_path_redirect.rb                     |  22 +-
 lib/tasks/safe.rake                                |  99 +++++
 public/safe/index.html                             |  86 +++-
 public/safe/jp/ai-mae/index.html                   | 131 ++++++
 public/safe/jp/honnin-kakunin/index.html           | 149 +++++++
 public/safe/jp/jp.css                              | 103 +++++
 public/safe/jp/jp.js                               | 112 ++++++
 public/safe/jp/nyusatsu/index.html                 | 258 ++++++++++++
 script/canonical_sweep.rb                          |  19 +-
 test/controllers/api/jp_pilot_controller_test.rb   | 139 +++++++
 .../controllers/api/safe_events_controller_test.rb | 126 ++++++
 test/integration/canonical_urls_test.rb            |  40 ++
 test/lib/canonical_path_redirect_test.rb           |  57 +++
 test/safe/jp_landing_check.mjs                     | 336 ++++++++++++++++
 test/support/cache_store_helper.rb                 |  22 +
 44 files changed, 3612 insertions(+), 8 deletions(-)
e46e128 feat(content): JP S7 — 콘텐츠 파이프라인 + 첫 3편
 CLAUDE.md                               |  62 +++++
 content/jp/ep01/carousel_1.png          | Bin 0 -> 110833 bytes
 content/jp/ep01/carousel_2.png          | Bin 0 -> 118822 bytes
 content/jp/ep01/carousel_3.png          | Bin 0 -> 106315 bytes
 content/jp/ep01/demo.gif                | Bin 0 -> 400129 bytes
 content/jp/ep01/demo.mp4                | Bin 0 -> 223914 bytes
 content/jp/ep01/manifest.json           |  54 ++++
 content/jp/ep01/post_en.md              |  37 +++
 content/jp/ep01/post_ja.md              |  41 +++
 content/jp/ep01/x_thread.md             |  38 +++
 content/jp/ep02/carousel_1.png          | Bin 0 -> 100989 bytes
 content/jp/ep02/carousel_2.png          | Bin 0 -> 120257 bytes
 content/jp/ep02/carousel_3.png          | Bin 0 -> 114725 bytes
 content/jp/ep02/manifest.json           |  46 ++++
 content/jp/ep02/post_en.md              |  36 +++
 content/jp/ep02/post_ja.md              |  36 +++
 content/jp/ep02/x_thread.md             |  38 +++
 content/jp/ep03/carousel_1.png          | Bin 0 -> 101497 bytes
 content/jp/ep03/carousel_2.png          | Bin 0 -> 121179 bytes
 content/jp/ep03/carousel_3.png          | Bin 0 -> 109116 bytes
 content/jp/ep03/manifest.json           |  46 ++++
 content/jp/ep03/post_en.md              |  38 +++
 content/jp/ep03/post_ja.md              |  42 ++++
 content/jp/ep03/x_thread.md             |  38 +++
 content/jp/topics.json                  | 277 +++++++++++++++++++++
 docs/jp/s7_report.md                    | 205 +++++++++++++++
 docs/jp/s7_samples/ep01_carousel_1.png  | Bin 0 -> 110833 bytes
 docs/jp/s7_samples/ep01_demo.gif        | Bin 0 -> 408749 bytes
 docs/jp/s7_samples/ep02_carousel_1.png  | Bin 0 -> 100989 bytes
 docs/jp/s7_samples/ep03_carousel_1.png  | Bin 0 -> 101497 bytes
 scripts/content/README.md               |  98 ++++++++
 scripts/content/make_episode.mjs        | 426 ++++++++++++++++++++++++++++++++
 scripts/content/templates/carousel.html | 140 +++++++++++
 33 files changed, 1698 insertions(+)
app/controllers/api/base_controller.rb
app/controllers/api/jp_pilot_controller.rb
app/controllers/api/safe_events_controller.rb
app/controllers/api/safe_scan_controller.rb
app/models/application_record.rb
app/models/banner.rb
app/models/blog_style.rb
app/models/blog_topic.rb
app/models/conversion.rb
app/models/jp_pilot_request.rb
app/models/post.rb
app/models/safe_event.rb
content/jp/ep01/carousel_1.png
content/jp/ep01/carousel_2.png
content/jp/ep01/carousel_3.png
content/jp/ep01/demo.gif
content/jp/ep01/demo.mp4
content/jp/ep01/manifest.json
content/jp/ep01/post_en.md
content/jp/ep01/post_ja.md
content/jp/ep01/x_thread.md
content/jp/ep02/carousel_1.png
content/jp/ep02/carousel_2.png
content/jp/ep02/carousel_3.png
content/jp/ep02/manifest.json
content/jp/ep02/post_en.md
content/jp/ep02/post_ja.md
content/jp/ep02/x_thread.md
content/jp/ep03/carousel_1.png
content/jp/ep03/carousel_2.png
content/jp/ep03/carousel_3.png
content/jp/ep03/manifest.json
content/jp/ep03/post_en.md
content/jp/ep03/post_ja.md
content/jp/ep03/x_thread.md
content/jp/topics.json
db/migrate/20260324143700_create_conversions.rb
db/migrate/20260324143948_create_active_storage_tables.active_storage.rb
db/migrate/20260325100000_create_banners.rb
db/migrate/20260403025744_create_posts.rb
db/migrate/20260404000155_create_blog_topics.rb
db/migrate/20260408015613_create_blog_styles.rb
db/migrate/20260408071252_add_blog_structure_to_posts.rb
db/migrate/20260917170741_add_publish_error_to_posts.rb
db/migrate/20261022000100_create_jp_pilot_requests.rb
db/migrate/20261022000200_create_safe_events.rb
docs/jp/codex_prompt.md
docs/jp/codex_prompt_market.md
docs/jp/codex_prompt_s3.md
docs/jp/codex_prompt_s3b.md
docs/jp/codex_prompt_s3c.md
docs/jp/codex_prompt_s6s7.md
docs/jp/codex_review_2026-10-21.md
docs/jp/codex_review_market_2026-10-22.md
docs/jp/codex_review_s3_2026-10-21.md
docs/jp/codex_review_s3b_2026-10-21.md
docs/jp/codex_review_s3c_2026-10-21.md
docs/jp/codex_review_s6s7_2026-10-22.md
docs/jp/jp_documents_catalog.json
docs/jp/jp_forecast_report_2026-10-22.md
docs/jp/jp_landing_copy_2026-10-22.md
docs/jp/jp_market_brief_2026-10-22.md
docs/jp/jp_market_decision_v2_2026-10-22.md
docs/jp/jp_safefile_strategy_2026-10-20.md
docs/jp/jp_safefile_strategy_v2_2026-10-21.md
docs/jp/metrics/2026-W43.md
docs/jp/metrics/README.md
docs/jp/outreach_log.md
docs/jp/s3_golden_result.md
docs/jp/s3_report.md
docs/jp/s3_visual/kenpo_out.png
docs/jp/s3_visual/mynumber_back_out.png
docs/jp/s3_visual/render_unten_menkyo_front.png
docs/jp/s3_visual/ui_jp.png
docs/jp/s3b_golden_result.md
docs/jp/s3b_report.md
docs/jp/s3b_visual/render_kouki_bands.png
docs/jp/s3b_visual/ui_legal_group.png
docs/jp/s3b_visual/ui_mynumber_confirm.png
docs/jp/s3b_visual/ui_unclassified_warning.png
docs/jp/s3c_golden_result.md
docs/jp/s3c_report.md
docs/jp/s3d_report.md
docs/jp/s5_live_check_2026-10-22.md
docs/jp/s6_prompt.md
docs/jp/s6_report.md
docs/jp/s7_prompt.md
docs/jp/s7_report.md
docs/jp/s7_samples/ep01_carousel_1.png
docs/jp/s7_samples/ep01_demo.gif
docs/jp/s7_samples/ep02_carousel_1.png
docs/jp/s7_samples/ep03_carousel_1.png
lib/tasks/blog.rake
lib/tasks/blog_migrate_privacy.rake
lib/tasks/jobs.rake
lib/tasks/safe.rake
public/safe/jp/ai-mae/index.html
public/safe/jp/honnin-kakunin/index.html
public/safe/jp/jp.css
public/safe/jp/jp.js
public/safe/jp/nyusatsu/index.html
scripts/content/README.md
scripts/content/make_episode.mjs
scripts/content/templates/carousel.html
test/controllers/api/jp_pilot_controller_test.rb
test/controllers/api/safe_events_controller_test.rb
test/support/cache_store_helper.rb
test/support/rake_task_helper.rb

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'for f in app/controllers/api/base_controller.rb app/controllers/api/jp_pilot_controller.rb app/models/jp_pilot_request.rb app/mailers/jp_pilot_mailer.rb test/controllers/api/jp_pilot_controller_test.rb test/support/cache_store_helper.rb config/environments/test.rb config/environments/production.rb config/application.rb config/routes.rb; do echo "### $f"; nl -ba "$f"; done' in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
     1	Rails.application.routes.draw do
     2	  # Permanent slug renames for the static SafeFile guide posts. These must come
     3	  # before the "/blog/:slug" route below so they win; after the folder rename the
     4	  # old paths no longer resolve as static files and fall through to here.
     5	  # 301 (redirect default) — never reverse. Rails matches the routes with or
     6	  # without a trailing slash, so both /blog/rrn-masking and /blog/rrn-masking/
     7	  # are covered. The locale prefix is preserved in the target so a Spanish reader
     8	  # stays in Spanish (/es/blog/contract-checklist → /es/blog/contract-sharing-checklist).
     9	  #
    10	  # The targets carry NO trailing slash (2026-09-18). They used to, and once
    11	  # CanonicalPathRedirect started normalising routed paths that made every one of
    12	  # these a 301 to a 301. Search Console had already caught the old spelling:
    13	  # /blog/contract-checklist/ was reported as a duplicate with a Google-chosen
    14	  # canonical, last crawled 2026-07-18 — a day before the rename shipped.
    15	  OLD_BLOG_SLUGS = {
    16	    "rrn-masking"        => "resident-number-masking",
    17	    "contract-checklist" => "contract-sharing-checklist"
    18	  }.freeze
    19	
    20	  OLD_BLOG_SLUGS.each do |old_slug, new_slug|
    21	    get "/blog/#{old_slug}", to: redirect("/blog/#{new_slug}")
    22	    %w[en ja es].each do |loc|
    23	      get "/#{loc}/blog/#{old_slug}", to: redirect("/#{loc}/blog/#{new_slug}")
    24	    end
    25	  end
    26	
    27	  # Locale-prefixed public pages. Korean (default) uses bare paths; the
    28	  # constraint only matches en/ja/es, so /ko/... never resolves here.
    29	  scope "(:locale)", locale: /en|ja|es/ do
    30	    root "pages#home"
    31	
    32	    resources :conversions, only: [:create, :show] do
    33	      member do
    34	        get :download
    35	      end
    36	    end
    37	
    38	    get "/compress", to: "pages#compress"
    39	    get "/pdf",      to: "pages#pdf"
    40	    get "/social",   to: "pages#social"
    41	    get "/about",    to: "pages#about"
    42	    get "/faq",      to: "pages#faq"
    43	
    44	    get "/blog",       to: "posts#index", as: :blog
    45	
    46	    # The blog index used to be a static file at public/blog/index.html, so
    47	    # ActionDispatch::Static answered /blog, /blog/ AND /blog/index.html with an
    48	    # identical 200 and Google indexed all three. 9f8bfff (2026-07-17) deleted
    49	    # the file when the listing moved into Rails, which left /blog/index.html
    50	    # falling through to "/blog/:slug" below as slug="index.html" → 404.
    51	    # 301 it back onto the listing instead of stranding an indexed URL.
    52	    # MUST stay above "/blog/:slug" — routes match in declaration order.
    53	    get "/blog/index.html",
    54	        to: redirect { |params, _req| params[:locale] ? "/#{params[:locale]}/blog" : "/blog" }
    55	
    56	    get "/blog/:slug", to: "posts#show",  as: :blog_post
    57	  end
    58	
    59	  # SafeFile — public/safe/index.html은 Rails가 정적 서빙(언어 독립 단일 URL),
    60	  # API는 AI 정밀 검사 중계. 로케일 프리픽스 없음.
    61	  #
    62	  # `get "/safe", to: redirect("/safe/")` 는 여기 있었지만 **한 번도 실행된 적이 없다**
    63	  # (2026-09-17 제거). ActionDispatch::Static 이 라우터보다 앞에 있고,
    64	  # FileHandler 가 `/safe` 요청을 `public/safe/index.html` 로 해석해 200 을 먼저
    65	  # 돌려주기 때문이다. 트레일링 슬래시 정규화는 정적 핸들러보다 앞서야 하므로
    66	  # Rack 미들웨어(lib/canonical_path_redirect.rb)로 옮겼다.
    67	  post "/api/safe_scan", to: "api/safe_scan#create"
    68	
    69	  # SafeFile JP (2026-10-22). Both are POST-only, like safe_scan, and both are
    70	  # under the /api/ prefix that robots.txt already disallows — Googlebot
    71	  # harvests fetch() URL literals out of the rendered page, which is how
    72	  # /api/safe_scan ended up reported as a 404 in Search Console.
    73	  #
    74	  #   jp_pilot    — the pilot sign-up form on /safe/jp/nyusatsu/ (personal data)
    75	  #   safe_events — anonymous category counters from /safe/ and the landings
    76	  post "/api/jp_pilot",    to: "api/jp_pilot#create"
    77	  post "/api/safe_events", to: "api/safe_events#create"
    78	
    79	  namespace :admin do
    80	    get  "login",  to: "sessions#new",     as: :login
    81	    post "login",  to: "sessions#create"
    82	    delete "logout", to: "sessions#destroy", as: :logout
    83	
    84	    resources :posts do
    85	      member do
    86	        post :generate
    87	        post :improve
    88	        post :publish
    89	      end
    90	      collection do
    91	        post :auto_generate
    92	      end
    93	    end
    94	
    95	    resources :banners do
    96	      member do
    97	        patch :toggle
    98	        patch :move
    99	      end
   100	    end
   101	
   102	    resources :blog_styles do
   103	      member do
   104	        post :analyze
   105	        post :toggle
   106	      end
   107	    end
   108	
   109	    # Read-only; see Admin::JpPilotRequestsController.
   110	    resources :jp_pilot_requests, only: [ :index ]
   111	
   112	    root to: "banners#index"
   113	  end
   114	
   115	  get "sitemap.xml", to: "pages#sitemap", as: :sitemap, defaults: { format: :xml }
   116	
   117	  get "up" => "rails/health#show", as: :rails_health_check
   118	end

hook: PostToolUse
hook: PostToolUse Completed
codex
초기 Q1 검토에서 중요한 구현상 쟁점이 보입니다. 캐시가 프로세스 공유형이어도 카운터가 `read → +1 → write`라 동시 요청에는 원자적이지 않고, honeypot 응답도 DB 저장·잡 enqueue를 건너뛰어 타이밍까지 성공과 동일하다고 보기는 어렵습니다. 나머지 증거와 심각도를 함께 대조하겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'for f in app/models/safe_event.rb app/controllers/api/safe_events_controller.rb app/controllers/api/safe_scan_controller.rb db/migrate/20261022000200_create_safe_events.rb db/schema.rb test/controllers/api/safe_events_controller_test.rb lib/tasks/safe.rake app/controllers/application_controller.rb app/jobs/application_mail_delivery_job.rb lib/tasks/jobs.rake; do echo "### $f"; nl -ba "$f"; done' in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
### app/models/safe_event.rb
     1	# Anonymous, category-only usage counters for SafeFile.
     2	#
     3	# The whole point of this table is what it CANNOT hold. /safe/ promises that
     4	# files never leave the browser and that the processing screen carries no
     5	# third-party script; a measurement endpoint is the one place where that promise
     6	# could quietly be broken, so the shape of a storable event is fixed here and
     7	# nothing else decides it:
     8	#
     9	#   * `name` must be one of NAMES.
    10	#   * every key in `props` must be allowed FOR THAT EVENT (KEYS).
    11	#   * every value must be one of a short, fixed list (VALUES).
    12	#
    13	# There is no free-text key, no coordinate, no file name, no page content, no
    14	# user agent, and no IP — not even hashed. A hash of an IP is still a stable
    15	# per-visitor identifier, which is exactly what this must not have, so the
    16	# controller never computes one.
    17	#
    18	# This class is the single source of truth: the controller validates through
    19	# `SafeEvent.sanitize`, the rake aggregator reads KEYS/VALUES to decide what it
    20	# may group by, and the tests assert against the same constants. Keeping a
    21	# second copy of the list anywhere else is how the two drift apart.
    22	class SafeEvent < ApplicationRecord
    23	  # The table has created_at but no updated_at (an event is never updated);
    24	  # Rails only writes timestamp columns that exist, so nothing to configure.
    25	
    26	  NAMES = %w[upload doc_class purpose download landing_view cta_click].freeze
    27	
    28	  VALUES = {
    29	    "doc_class" => %w[shikaku_kakuninsho unten_menkyo mynumber_card juminhyo unclassified none],
    30	    "purpose"   => %w[identity_submit my_number_procedure bid_attachment consult_share],
    31	    "format"    => %w[jpg png pdf],
    32	    "locale"    => %w[ko en ja es],
    33	    "from"      => %w[nyusatsu honnin aimae direct],
    34	    "ext"       => %w[pdf jpg png docx other],
    35	    "pages"     => %w[1 2 3-5 6+]
    36	  }.freeze
    37	
    38	  # Which keys each event may carry. A key that is valid for one event is not
    39	  # automatically valid for another — `format` only means something on a
    40	  # download, and a landing page has no document to classify.
    41	  KEYS = {
    42	    "upload"       => %w[ext pages locale from],
    43	    "doc_class"    => %w[doc_class locale from],
    44	    "purpose"      => %w[purpose doc_class locale from],
    45	    "download"     => %w[format doc_class purpose locale from],
    46	    "landing_view" => %w[from locale],
    47	    "cta_click"    => %w[from purpose locale]
    48	  }.freeze
    49	
    50	  validates :name, inclusion: { in: NAMES }
    51	  validate  :props_whitelisted
    52	
    53	  scope :since, ->(time) { where(created_at: time..) }
    54	
    55	  # Returns the props hash reduced to whitelisted (key, value) pairs, or nil if
    56	  # the event name is unknown or ANY key/value is not allowed.
    57	  #
    58	  # Rejecting the whole event rather than dropping the offending pair is
    59	  # deliberate. A partially-stored event is a row that looks like data but
    60	  # describes something that did not happen, and `beacon` responses are never
    61	  # read by the browser, so a silent drop would be invisible from both ends. A
    62	  # rejection is at least a 422 in the logs and a red test.
    63	  def self.sanitize(name, props)
    64	    allowed = KEYS[name.to_s]
    65	    return nil unless allowed
    66	
    67	    out = {}
    68	    (props || {}).each do |k, v|
    69	      key = k.to_s
    70	      return nil unless allowed.include?(key)
    71	
    72	      value = v.to_s
    73	      return nil unless VALUES.fetch(key, []).include?(value)
    74	
    75	      out[key] = value
    76	    end
    77	    out
    78	  end
    79	
    80	  private
    81	
    82	  def props_whitelisted
    83	    unless props.is_a?(Hash)
    84	      errors.add(:props, "must be a hash")
    85	      return
    86	    end
    87	
    88	    errors.add(:props, "contains a key or value that is not whitelisted") if self.class.sanitize(name, props).nil?
    89	  end
    90	end
### app/controllers/api/safe_events_controller.rb
     1	# app/controllers/api/safe_events_controller.rb
     2	#
     3	# Anonymous, category-only usage counters for SafeFile.
     4	#
     5	#   POST /api/safe_events
     6	#   { "name": "doc_class", "props": { "doc_class": "shikaku_kakuninsho", "locale": "ja" } }
     7	#   → 204 No Content
     8	#
     9	# The browser sends these with navigator.sendBeacon and never reads the
    10	# response, so the status code exists for our logs and tests, not for the page.
    11	#
    12	# What this endpoint deliberately does NOT do:
    13	#
    14	#   * It does not look at request.remote_ip. Not to store it, not to hash it,
    15	#     not to rate-limit on it. A per-IP counter is a per-visitor identifier
    16	#     however it is spelled, and /safe/ promises the processing screen carries
    17	#     no tracking. The abuse ceiling is instead a flat per-minute cap on the
    18	#     whole endpoint (see THROTTLE_*), which is blind to who is calling.
    19	#   * It does not set or read a cookie, and it does not touch the session.
    20	#   * It stores nothing that is not on SafeEvent's whitelist. The model owns
    21	#     that list; this controller just refuses what the model will not take.
    22	module Api
    23	  class SafeEventsController < BaseController
    24	    # A global ceiling, not a per-client one. 600 events/minute is far above
    25	    # what organic use produces and still bounds a flood to something the table
    26	    # can absorb. It cannot single out an abuser — that is the trade we are
    27	    # making on purpose, and the reason the cap is generous.
    28	    THROTTLE_LIMIT  = 600
    29	    THROTTLE_WINDOW = 1.minute
    30	
    31	    # Bounds the work per request. Not the gate — SafeEvent::KEYS is.
    32	    MAX_KEYS = 12
    33	
    34	    def create
    35	      return head(:too_many_requests) if throttled?
    36	
    37	      raw = permitted_props
    38	      return head(:unprocessable_entity) if raw.nil?
    39	
    40	      props = SafeEvent.sanitize(params[:name], raw)
    41	      return head(:unprocessable_entity) if props.nil?
    42	
    43	      SafeEvent.create!(name: params[:name].to_s, props: props)
    44	      head :no_content
    45	    rescue ActiveRecord::RecordInvalid
    46	      # sanitize already rejected everything the model would reject, so this is
    47	      # a genuine surprise. 422 rather than 500: the client cannot fix it, but
    48	      # a 500 would page us for a counter.
    49	      head :unprocessable_entity
    50	    end
    51	
    52	    private
    53	
    54	    # Hands SafeEvent.sanitize exactly what the client sent — including keys we
    55	    # do not know — so an unknown key is REJECTED rather than quietly dropped.
    56	    #
    57	    # Filtering to the known keys here would have been the obvious move and is
    58	    # the wrong one: the request would then succeed while losing a field, and
    59	    # since sendBeacon discards the response, a client that drifts would look
    60	    # healthy from both sides. Values are stringified by sanitize, so a nested
    61	    # hash or array arrives as a string that is not on any whitelist and fails
    62	    # the same way. Returns nil when the request is already refusable.
    63	    def permitted_props
    64	      raw = params[:props]
    65	      return {} unless raw.respond_to?(:each_pair)
    66	      return nil if raw.keys.size > MAX_KEYS
    67	
    68	      raw.each_pair.to_h { |k, v| [ k.to_s, v ] }
    69	    end
    70	
    71	    # Window-bucketed counter in Rails.cache, same shape as safe_scan's. No
    72	    # request attribute is part of the key.
    73	    def throttled?
    74	      bucket = (Time.current.to_i / THROTTLE_WINDOW.to_i)
    75	      key    = "safe_events:all:#{bucket}"
    76	      count  = Rails.cache.read(key).to_i + 1
    77	      Rails.cache.write(key, count, expires_in: THROTTLE_WINDOW * 2)
    78	      count > THROTTLE_LIMIT
    79	    end
    80	  end
    81	end
### app/controllers/api/safe_scan_controller.rb
     1	# app/controllers/api/safe_scan_controller.rb
     2	#
     3	# SafeFile의 "AI 정밀 검사"를 중계하는 엔드포인트.
     4	# 브라우저 → 이 컨트롤러 → Anthropic API 순서로 흘러가며,
     5	# API 키는 서버 환경변수(ANTHROPIC_API_KEY)에만 존재한다.
     6	#
     7	# 요청:  POST /api/safe_scan
     8	#        { "text": "문서 내용" }                          — 텍스트 검사
     9	#        { "image": { "data": "<base64>", "media": "image/png" } } — 이미지 검사(OCR 포함)
    10	# 응답:  { "raw": "<모델이 출력한 JSON 문자열>" }
    11	#
    12	require "net/http"
    13	
    14	module Api
    15	  class SafeScanController < BaseController
    16	    ANTHROPIC_URL = "https://api.anthropic.com/v1/messages".freeze
    17	    # 비용 최적화: 개인정보 추출은 소형 모델로 충분하다.
    18	    MODEL         = "claude-haiku-4-5-20251001".freeze
    19	    MAX_TEXT      = 8_000          # 문자 수 제한 (약 1~2페이지)
    20	    MAX_IMAGE_B64 = 7_000_000      # base64 기준 약 5MB
    21	    HOURLY_LIMIT  = 30             # IP당 시간당 AI 검사 횟수
    22	
    23	    TEXT_PROMPT = <<~PROMPT.freeze
    24	      다음 문서에서 개인정보를 모두 찾아라. 특히 사람 이름, 회사·기관명, 직책, 주소,
    25	      건강 관련 정보처럼 패턴이 없는 것들. 반드시 JSON 배열만 출력하라. 마크다운·설명 금지.
    26	      형식: [{"type":"name|phone|email|rrn|ssn|passport|license|card|account|birth|address|company|title|ip|url|health|other","value":"문서에 나온 원문 그대로"}]
    27	
    28	      문서:
    29	      """
    30	      %<doc>s
    31	      """
    32	    PROMPT
    33	
    34	    IMAGE_PROMPT = <<~PROMPT.freeze
    35	      이 이미지 문서에서 (1) 전체 텍스트를 추출하고 (2) 개인정보를 찾아라.
    36	      반드시 아래 JSON만 출력하라. 마크다운 금지.
    37	      {"text":"추출한 전체 텍스트","entities":[{"type":"name|phone|email|rrn|ssn|passport|license|card|account|birth|address|company|title|ip|url|health|other","value":"원문 그대로"}]}
    38	    PROMPT
    39	
    40	    def create
    41	      return render(json: { error: "rate_limited" },  status: 429) if throttled?
    42	
    43	      text  = params[:text].to_s
    44	      image = params[:image]
    45	
    46	      if image.present? && image[:data].present?
    47	        return render(json: { error: "image_too_large" }, status: 413) if image[:data].length > MAX_IMAGE_B64
    48	        content = [
    49	          { type: "image", source: { type: "base64", media_type: image[:media].presence || "image/png", data: image[:data] } },
    50	          { type: "text",  text: IMAGE_PROMPT }
    51	        ]
    52	        max_tokens = 3_000   # OCR 텍스트까지 돌려받아야 하므로 여유
    53	      elsif text.present?
    54	        return render(json: { error: "text_too_long" }, status: 413) if text.length > MAX_TEXT
    55	        content    = [{ type: "text", text: format(TEXT_PROMPT, doc: text) }]
    56	        max_tokens = 1_500
    57	      else
    58	        return render(json: { error: "empty" }, status: 400)
    59	      end
    60	
    61	      raw = call_anthropic(content, max_tokens)
    62	      render json: { raw: raw }
    63	    rescue StandardError => e
    64	      Rails.logger.error("[safe_scan] #{e.class}: #{e.message}")
    65	      render json: { error: "upstream" }, status: 502
    66	    end
    67	
    68	    private
    69	
    70	    def call_anthropic(content, max_tokens)
    71	      uri  = URI(ANTHROPIC_URL)
    72	      http = Net::HTTP.new(uri.host, uri.port)
    73	      http.use_ssl      = true
    74	      http.open_timeout = 10
    75	      http.read_timeout = 60
    76	
    77	      req = Net::HTTP::Post.new(uri)
    78	      req["x-api-key"]         = ENV.fetch("ANTHROPIC_API_KEY")
    79	      req["anthropic-version"] = "2023-06-01"
    80	      req["content-type"]      = "application/json"
    81	      req.body = {
    82	        model:      MODEL,
    83	        max_tokens: max_tokens,
    84	        messages:   [{ role: "user", content: content }]
    85	      }.to_json
    86	
    87	      res = http.request(req)
    88	      raise "anthropic #{res.code}" unless res.code.to_i == 200
    89	
    90	      body = JSON.parse(res.body)
    91	      Array(body["content"]).select { |c| c["type"] == "text" }.map { |c| c["text"] }.join("\n")
    92	    end
    93	
    94	    # 별도 gem 없이 Rails.cache로 구현한 IP당 시간 단위 사용량 제한.
    95	    # (Rack::Attack을 이미 쓰고 있다면 그쪽으로 옮겨도 된다)
    96	    def throttled?
    97	      key   = "safe_scan:#{request.remote_ip}:#{Time.current.strftime('%Y%m%d%H')}"
    98	      count = Rails.cache.read(key).to_i + 1
    99	      Rails.cache.write(key, count, expires_in: 1.hour)
   100	      count > HOURLY_LIMIT
   101	    end
   102	  end
   103	end
### db/migrate/20261022000200_create_safe_events.rb
     1	class CreateSafeEvents < ActiveRecord::Migration[8.0]
     2	  def change
     3	    create_table :safe_events do |t|
     4	      t.string :name, null: false
     5	      # Category-only properties. Every key AND every value is whitelisted in
     6	      # Api::SafeEventsController before it reaches here — no free text, no
     7	      # coordinates, no file names, no IP (not even hashed). The column is jsonb
     8	      # because the key set differs per event, not because it is a free bag.
     9	      t.jsonb  :props, null: false, default: {}
    10	
    11	      # created_at only. There is deliberately no updated_at (an event is never
    12	      # updated) and no request fingerprint of any kind.
    13	      t.datetime :created_at, null: false
    14	    end
    15	
    16	    add_index :safe_events, [ :created_at, :name ]
    17	  end
    18	end
### db/schema.rb
     1	# This file is auto-generated from the current state of the database. Instead
     2	# of editing this file, please use the migrations feature of Active Record to
     3	# incrementally modify your database, and then regenerate this schema definition.
     4	#
     5	# This file is the source Rails uses to define your schema when running `bin/rails
     6	# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
     7	# be faster and is potentially less error prone than running all of your
     8	# migrations from scratch. Old migrations may fail to apply correctly if those
     9	# migrations use external dependencies or application code.
    10	#
    11	# It's strongly recommended that you check this file into your version control system.
    12	
    13	ActiveRecord::Schema[8.0].define(version: 2026_10_22_000200) do
    14	  # These are extensions that must be enabled in order to support this database
    15	  enable_extension "pg_catalog.plpgsql"
    16	
    17	  create_table "active_storage_attachments", force: :cascade do |t|
    18	    t.string "name", null: false
    19	    t.string "record_type", null: false
    20	    t.bigint "record_id", null: false
    21	    t.bigint "blob_id", null: false
    22	    t.datetime "created_at", null: false
    23	    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    24	    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
    25	  end
    26	
    27	  create_table "active_storage_blobs", force: :cascade do |t|
    28	    t.string "key", null: false
    29	    t.string "filename", null: false
    30	    t.string "content_type"
    31	    t.text "metadata"
    32	    t.string "service_name", null: false
    33	    t.bigint "byte_size", null: false
    34	    t.string "checksum"
    35	    t.datetime "created_at", null: false
    36	    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
    37	  end
    38	
    39	  create_table "active_storage_variant_records", force: :cascade do |t|
    40	    t.bigint "blob_id", null: false
    41	    t.string "variation_digest", null: false
    42	    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
    43	  end
    44	
    45	  create_table "banners", force: :cascade do |t|
    46	    t.string "title_en", default: "", null: false
    47	    t.string "title_ko", default: "", null: false
    48	    t.string "description_en", default: ""
    49	    t.string "description_ko", default: ""
    50	    t.string "link_url"
    51	    t.string "button_text_en", default: "Learn More"
    52	    t.string "button_text_ko", default: "자세히 보기"
    53	    t.string "image_url"
    54	    t.string "position", default: "after_result", null: false
    55	    t.string "page", default: "all", null: false
    56	    t.boolean "active", default: true, null: false
    57	    t.integer "sort_order", default: 0, null: false
    58	    t.string "banner_type", default: "internal", null: false
    59	    t.string "adsense_slot_id"
    60	    t.datetime "created_at", null: false
    61	    t.datetime "updated_at", null: false
    62	    t.index ["page", "position", "active", "sort_order"], name: "index_banners_on_page_position_active_sort"
    63	  end
    64	
    65	  create_table "blog_styles", force: :cascade do |t|
    66	    t.string "source_name"
    67	    t.text "raw_script"
    68	    t.text "hooking_patterns"
    69	    t.text "sentence_structure"
    70	    t.text "psychological_triggers"
    71	    t.text "tone_style"
    72	    t.boolean "is_active", default: true
    73	    t.text "notes"
    74	    t.datetime "created_at", null: false
    75	    t.datetime "updated_at", null: false
    76	  end
    77	
    78	  create_table "blog_topics", force: :cascade do |t|
    79	    t.string "topic"
    80	    t.string "category"
    81	    t.boolean "used", default: false, null: false
    82	    t.datetime "created_at", null: false
    83	    t.datetime "updated_at", null: false
    84	  end
    85	
    86	  create_table "conversions", force: :cascade do |t|
    87	    t.string "conversion_type"
    88	    t.string "status"
    89	    t.integer "original_size"
    90	    t.integer "result_size"
    91	    t.datetime "expires_at"
    92	    t.datetime "created_at", null: false
    93	    t.datetime "updated_at", null: false
    94	  end
    95	
    96	  create_table "jp_pilot_requests", force: :cascade do |t|
    97	    t.string "company", null: false
    98	    t.string "industry", null: false
    99	    t.string "monthly_count", null: false
   100	    t.string "authority"
   101	    t.string "email", null: false
   102	    t.string "from", default: "direct", null: false
   103	    t.datetime "created_at", null: false
   104	    t.datetime "updated_at", null: false
   105	    t.index ["created_at"], name: "index_jp_pilot_requests_on_created_at"
   106	  end
   107	
   108	  create_table "posts", force: :cascade do |t|
   109	    t.string "title_ko"
   110	    t.string "title_en"
   111	    t.text "body_ko"
   112	    t.text "body_en"
   113	    t.string "slug"
   114	    t.string "category"
   115	    t.string "status"
   116	    t.datetime "published_at"
   117	    t.text "cover_svg"
   118	    t.string "meta_description_ko"
   119	    t.string "meta_description_en"
   120	    t.integer "view_count", default: 0
   121	    t.datetime "created_at", null: false
   122	    t.datetime "updated_at", null: false
   123	    t.string "trust_bar"
   124	    t.string "pain_tag"
   125	    t.text "error_mockup"
   126	    t.text "recognition_text"
   127	    t.text "loss_items"
   128	    t.text "stats"
   129	    t.string "subtitle_ko"
   130	    t.text "publish_error"
   131	    t.index ["slug"], name: "index_posts_on_slug", unique: true
   132	  end
   133	
   134	  create_table "safe_events", force: :cascade do |t|
   135	    t.string "name", null: false
   136	    t.jsonb "props", default: {}, null: false
   137	    t.datetime "created_at", null: false
   138	    t.index ["created_at", "name"], name: "index_safe_events_on_created_at_and_name"
   139	  end
   140	
   141	  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
   142	  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
   143	end
### test/controllers/api/safe_events_controller_test.rb
     1	require "test_helper"
     2	require_relative "../../support/cache_store_helper"
     3	
     4	# What this endpoint stores is the whole security property, so the tests are
     5	# written from the outside: a request goes in, and the assertion is on the row
     6	# count and on the stored hash — never on the controller's internals.
     7	class Api::SafeEventsControllerTest < ActionDispatch::IntegrationTest
     8	  include CacheStoreHelper
     9	
    10	  setup { SafeEvent.delete_all }
    11	
    12	  def post_event(payload)
    13	    post "/api/safe_events", params: payload.to_json,
    14	                             headers: { "CONTENT_TYPE" => "application/json" }
    15	  end
    16	
    17	  test "stores a whitelisted event" do
    18	    assert_difference "SafeEvent.count", 1 do
    19	      post_event(name: "doc_class", props: { doc_class: "shikaku_kakuninsho", locale: "ja", from: "nyusatsu" })
    20	    end
    21	
    22	    assert_response :no_content
    23	    event = SafeEvent.last
    24	    assert_equal "doc_class", event.name
    25	    assert_equal({ "doc_class" => "shikaku_kakuninsho", "locale" => "ja", "from" => "nyusatsu" }, event.props)
    26	  end
    27	
    28	  test "rejects an event name that is not on the whitelist" do
    29	    assert_no_difference "SafeEvent.count" do
    30	      post_event(name: "keystroke", props: { locale: "ja" })
    31	    end
    32	
    33	    assert_response :unprocessable_entity
    34	  end
    35	
    36	  test "rejects a key that is not allowed for that event" do
    37	    # `format` is meaningful on a download, not on a landing view.
    38	    assert_no_difference "SafeEvent.count" do
    39	      post_event(name: "landing_view", props: { from: "nyusatsu", format: "pdf" })
    40	    end
    41	
    42	    assert_response :unprocessable_entity
    43	  end
    44	
    45	  test "rejects a value that is not on the whitelist" do
    46	    assert_no_difference "SafeEvent.count" do
    47	      post_event(name: "doc_class", props: { doc_class: "passport_scan", locale: "ja" })
    48	    end
    49	
    50	    assert_response :unprocessable_entity
    51	  end
    52	
    53	  # The point of the endpoint is that these cannot be smuggled in. Each of
    54	  # these is a key a well-meaning future change might add; all must bounce.
    55	  test "rejects free text, file names, coordinates and identifiers" do
    56	    [
    57	      { name: "upload", props: { ext: "pdf", filename: "健康保険証.pdf" } },
    58	      { name: "upload", props: { ext: "pdf", text: "被保険者番号 1234567" } },
    59	      { name: "download", props: { format: "pdf", box: "12,40,180,22" } },
    60	      { name: "landing_view", props: { from: "nyusatsu", ip: "203.0.113.9" } },
    61	      { name: "landing_view", props: { from: "nyusatsu", visitor_id: "abc123" } },
    62	      { name: "upload", props: { ext: "pdf", pages: "17" } }
    63	    ].each do |payload|
    64	      assert_no_difference "SafeEvent.count", "#{payload[:props].keys.last} was accepted" do
    65	        post_event(payload)
    66	      end
    67	      assert_response :unprocessable_entity
    68	    end
    69	  end
    70	
    71	  test "a nested value cannot sneak past the value whitelist" do
    72	    assert_no_difference "SafeEvent.count" do
    73	      post_event(name: "doc_class", props: { doc_class: { evil: "shikaku_kakuninsho" } })
    74	    end
    75	
    76	    assert_response :unprocessable_entity
    77	  end
    78	
    79	  test "an event with no props at all is stored" do
    80	    assert_difference "SafeEvent.count", 1 do
    81	      post_event(name: "upload")
    82	    end
    83	
    84	    assert_response :no_content
    85	    assert_equal({}, SafeEvent.last.props)
    86	  end
    87	
    88	  # Not a style assertion — it is the promise. If any of these columns ever
    89	  # appears, the privacy claim on /safe/ and the three landing pages is false.
    90	  test "the table has no column that could identify a visitor" do
    91	    forbidden = %w[ip ip_address ip_hash remote_ip user_agent session_id visitor_id fingerprint cookie referer email]
    92	    present = SafeEvent.column_names & forbidden
    93	    assert_empty present, "safe_events must not carry #{present.join(', ')}"
    94	    assert_equal %w[created_at id name props], SafeEvent.column_names.sort
    95	  end
    96	
    97	  # Measured before the fix: POST /api/safe_events?locale=ja answered 204 AND
    98	  # Set-Cookie: locale=ja, expiring in a year. ApplicationController#set_locale
    99	  # writes that cookie whenever params[:locale] is present, and params includes
   100	  # the query string — correct for a page, wrong for a counter that promises it
   101	  # identifies nobody. Api::BaseController skips the filter for every /api/ route.
   102	  test "no /api/ endpoint can plant a cookie" do
   103	    [
   104	      [ "/api/safe_events?locale=ja", { name: "landing_view", props: { from: "direct" } } ],
   105	      [ "/api/jp_pilot?locale=ja", { company: "x", industry: "other", monthly_count: "1-2", email: "a@b.co.jp" } ]
   106	    ].each do |path, payload|
   107	      post path, params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
   108	      assert_empty response.headers.to_h.slice("Set-Cookie", "set-cookie"),
   109	                   "#{path} set a cookie: #{response.headers['Set-Cookie'] || response.headers['set-cookie']}"
   110	      assert_empty cookies.to_hash, "#{path} left cookies: #{cookies.to_hash.inspect}"
   111	    end
   112	  end
   113	
   114	  # Guards the test above: if a locale-prefixed PAGE stopped setting the cookie
   115	  # too, the assertion would pass for the wrong reason and nobody would notice
   116	  # that language switching had broken.
   117	  test "a locale-prefixed page still does set the cookie" do
   118	    get "/ja/faq"
   119	    assert_response :success
   120	    assert_equal "ja", cookies[:locale]
   121	  end
   122	
   123	  test "the whole endpoint is capped and the cap is not per-visitor" do
   124	    with_memory_cache do
   125	      limit = Api::SafeEventsController::THROTTLE_LIMIT
   126	      # Prime the bucket to the limit rather than issuing hundreds of requests:
   127	      # the key shape is part of the contract being asserted, and a test that
   128	      # only counts requests would still pass if the key gained an IP.
   129	      bucket = Time.current.to_i / Api::SafeEventsController::THROTTLE_WINDOW.to_i
   130	      Rails.cache.write("safe_events:all:#{bucket}", limit, expires_in: 2.minutes)
   131	
   132	      assert_no_difference "SafeEvent.count" do
   133	        post_event(name: "landing_view", props: { from: "nyusatsu" })
   134	      end
   135	      assert_response :too_many_requests
   136	    end
   137	  end
   138	
   139	  # Guards the previous test against the null store. If the cap were asserted
   140	  # under the test default, the counter would write to a store that forgets and
   141	  # the limit could never be reached — green regardless of the code.
   142	  test "the cap does not fire without a cache that remembers" do
   143	    limit = Api::SafeEventsController::THROTTLE_LIMIT
   144	    bucket = Time.current.to_i / Api::SafeEventsController::THROTTLE_WINDOW.to_i
   145	    Rails.cache.write("safe_events:all:#{bucket}", limit, expires_in: 2.minutes)
   146	
   147	    assert_difference "SafeEvent.count", 1 do
   148	      post_event(name: "landing_view", props: { from: "nyusatsu" })
   149	    end
   150	    assert_response :no_content
   151	  end
   152	end
### lib/tasks/safe.rake
     1	# Weekly roll-up of the anonymous SafeFile counters.
     2	#
     3	#   bin/rails safe:jp_weekly            # last 7 days → docs/jp/metrics/YYYY-WW.md
     4	#   bin/rails safe:jp_weekly[2026-W43]  # name the ISO week explicitly
     5	#
     6	# The file it writes is the evidence for the forecast predictions P6/P10/P11
     7	# (docs/jp/jp_forecast_report_2026-10-22.md) — which document types actually
     8	# arrive, which purpose is chosen, and which landing page sent them. Checking it
     9	# into git is the point: a month of these is a series, and a series is the only
    10	# thing that can falsify a prediction.
    11	#
    12	# It reads SafeEvent and nothing else. There is no per-visitor dimension to
    13	# group by because the table has none, so every number here is an event count,
    14	# NOT a user count — the report says so on its own face, because a reader who
    15	# assumes otherwise will overstate reach.
    16	namespace :safe do
    17	  desc "Aggregate the last 7 days of anonymous SafeFile events into docs/jp/metrics/YYYY-WW.md"
    18	  task :jp_weekly, [ :week ] => :environment do |_t, args|
    19	    # ISO week-based year + ISO week number, so the label matches the week the
    20	    # window actually falls in at a year boundary (%Y-%W would print 2027-W01
    21	    # for days that ISO calls 2026-W53).
    22	    label = args[:week].presence || ENV["WEEK"].presence || Time.current.strftime("%G-W%V")
    23	    # The label becomes a file name, so it is validated rather than sanitised —
    24	    # a silently-rewritten label writes a correct-looking report to the wrong
    25	    # week, which is worse than refusing.
    26	    abort "safe:jp_weekly: week must look like 2026-W43 (got #{label.inspect})" unless label.match?(/\A\d{4}-W\d{2}\z/)
    27	
    28	    out_dir = Rails.root.join("docs", "jp", "metrics")
    29	    FileUtils.mkdir_p(out_dir)
    30	    path = out_dir.join("#{label}.md")
    31	
    32	    window_end   = Time.current
    33	    window_start = window_end - 7.days
    34	    events = SafeEvent.where(created_at: window_start...window_end)
    35	
    36	    total = events.count
    37	    by_name = events.group(:name).count
    38	
    39	    # Only group by a dimension the event is actually allowed to carry, read
    40	    # straight off SafeEvent::KEYS. Hard-coding the pairs here is how the two
    41	    # lists drift: add a key to the model and this report keeps reporting the
    42	    # old shape while looking just as finished.
    43	    sections = SafeEvent::KEYS.flat_map do |name, keys|
    44	      keys.map { |key| [ name, key ] }
    45	    end
    46	
    47	    lines = []
    48	    lines << "# SafeFile JP 週次カウント — #{label}"
    49	    lines << ""
    50	    lines << "> 自動生成: `bin/rails safe:jp_weekly` · 対象 #{window_start.utc.strftime('%Y-%m-%d %H:%M')} 〜 #{window_end.utc.strftime('%Y-%m-%d %H:%M')} UTC"
    51	    lines << ">"
    52	    lines << "> **이 숫자는 이벤트 수이며 사용자 수가 아니다.** `safe_events` 에는 방문자를"
    53	    lines << "> 식별할 열이 없다(IP·해시·쿠키 전부 없음) — 그래서 중복 제거가 불가능하고,"
    54	    lines << "> 한 사람이 다섯 번 올리면 5로 센다. 추세 비교용으로만 읽을 것."
    55	    lines << ""
    56	    lines << "총 이벤트: **#{total}**"
    57	    lines << ""
    58	
    59	    if total.zero?
    60	      lines << "이 기간에 기록된 이벤트가 없다. 가능한 이유는 세 가지이고 서로 구별되지 않는다:"
    61	      lines << "① 실제로 트래픽이 없었다 ② `/api/safe_events` 가 거부하고 있다(422 — 화이트리스트 불일치)"
    62	      lines << "③ 배포본에 계측 코드가 없다. 둘째·셋째는 로그로만 구별된다."
    63	      lines << ""
    64	    else
    65	      lines << "## 이벤트별"
    66	      lines << ""
    67	      lines << "| event | count |"
    68	      lines << "| --- | --- |"
    69	      SafeEvent::NAMES.each { |n| lines << "| #{n} | #{by_name.fetch(n, 0)} |" }
    70	      lines << ""
    71	
    72	      sections.each do |name, key|
    73	        counts = events.where(name: name)
    74	                       .group(Arel.sql("props ->> #{ActiveRecord::Base.connection.quote(key)}"))
    75	                       .count
    76	                       .reject { |k, _| k.nil? }
    77	        next if counts.empty?
    78	
    79	        lines << "## #{name} × #{key}"
    80	        lines << ""
    81	        lines << "| #{key} | count |"
    82	        lines << "| --- | --- |"
    83	        counts.sort_by { |k, v| [ -v, k.to_s ] }.each { |k, v| lines << "| #{k} | #{v} |" }
    84	        lines << ""
    85	      end
    86	    end
    87	
    88	    lines << "## 예측 대조 (jp_forecast_report §7)"
    89	    lines << ""
    90	    lines << "- P6 (資格確認書 가 doc_class 1위인가): `doc_class × doc_class` 표를 본다."
    91	    lines << "- P10 (입찰 랜딩이 유료 문의를 만드는가): `from=nyusatsu` 의 cta_click 과"
    92	    lines << "  `/admin/jp_pilot_requests` 의 신청 수를 함께 본다 — 이 표만으로는 알 수 없다."
    93	    lines << "- P11 (個人番号手続 선택률): `purpose × purpose` 표에서 `my_number_procedure` 비율."
    94	    lines << ""
    95	
    96	    File.write(path, lines.join("\n") + "\n")
    97	    puts "wrote #{path} (#{total} events, #{window_start.utc.iso8601} .. #{window_end.utc.iso8601})"
    98	  end
    99	end
### app/controllers/application_controller.rb
     1	class ApplicationController < ActionController::Base
     2	  allow_browser versions: :modern
     3	
     4	  before_action :set_locale
     5	
     6	  # Keep the current locale in generated URLs. Korean (default) has no prefix,
     7	  # so we pass locale: nil for it and Rails omits the optional (:locale) segment.
     8	  def default_url_options
     9	    { locale: (I18n.locale == I18n.default_locale ? nil : I18n.locale) }
    10	  end
    11	
    12	  private
    13	
    14	  # Priority: URL prefix (params[:locale]) → cookie → Accept-Language → default.
    15	  # The route constraint only matches en/ja/es, so a bare path (no prefix) means
    16	  # cookie/browser preference decides — Korean when none is set.
    17	  def set_locale
    18	    requested = params[:locale].presence || cookies[:locale].presence || locale_from_browser
    19	    locale = available?(requested) ? requested.to_sym : I18n.default_locale
    20	    I18n.locale = locale
    21	
    22	    # Persist an explicit URL choice so the preference survives later navigation.
    23	    if params[:locale].present? && available?(params[:locale])
    24	      cookies[:locale] = { value: locale, expires: 1.year.from_now }
    25	    end
    26	  end
    27	
    28	  def locale_from_browser
    29	    accept_language = request.env["HTTP_ACCEPT_LANGUAGE"]
    30	    return nil unless accept_language
    31	
    32	    accept_language.scan(/[a-z]{2}/).find { |lang| available?(lang) }
    33	  end
    34	
    35	  def available?(locale)
    36	    locale.present? && I18n.available_locales.map(&:to_s).include?(locale.to_s)
    37	  end
    38	end
### app/jobs/application_mail_delivery_job.rb
     1	# Retry policy for outgoing mail.
     2	#
     3	# This class exists because ActionMailer::MailDeliveryJob inherits from
     4	# ActiveJob::Base, NOT from ApplicationJob (verified at runtime: its ancestors
     5	# are [ActionMailer::MailDeliveryJob, ActiveJob::Base, …]). Anything declared on
     6	# ApplicationJob is therefore invisible to `deliver_later`, which is a trap: the
     7	# obvious way to "add a retry policy to this app" is to uncomment the scaffold
     8	# lines in ApplicationJob, and that would leave mail delivery untouched while
     9	# looking finished.
    10	#
    11	# Wired up by config.application.rb via config.action_mailer.delivery_job.
    12	#
    13	# ── Why retry at all ────────────────────────────────────────────────────────
    14	#
    15	# Because SMTP has already failed here in production: 2026-04-07, a missing
    16	# GMAIL_PASSWORD produced SMTPAuthenticationError 535-5.7.8. Solid Queue does
    17	# not retry on its own (see ApplicationJob for the source), so before this
    18	# every transient SMTP hiccup dropped a message permanently into
    19	# solid_queue_failed_executions.
    20	#
    21	# ── What is NOT delegated to this ───────────────────────────────────────────
    22	#
    23	# A retry makes a lost message less likely; it does not make delivery a
    24	# dependable channel. 535-5.7.8 was a *configuration* error — no number of
    25	# retries would have delivered it. That is why the publish-failure signal does
    26	# not live in email at all: Post.publish_stuck derives it from the posts table,
    27	# and `rake blog:stuck` reads it without any mail involved. Mail is the nag, not
    28	# the record.
    29	class ApplicationMailDeliveryJob < ActionMailer::MailDeliveryJob
    30	  # Transient SMTP and network conditions: the connection failed or the server
    31	  # asked us to come back later. Spread out, because a mail server refusing
    32	  # connections rarely recovers in a second.
    33	  retry_on Net::SMTPServerBusy,
    34	           Net::OpenTimeout,
    35	           Net::ReadTimeout,
    36	           IOError,
    37	           Errno::ECONNRESET,
    38	           Errno::ECONNREFUSED,
    39	           Errno::EHOSTUNREACH,
    40	           Errno::ETIMEDOUT,
    41	           wait: :polynomially_longer,
    42	           attempts: 5
    43	
    44	  # Permanent refusals are NOT retried. A bad address or a rejected credential
    45	  # (535-5.7.8 is exactly this) fails identically every time, so retrying only
    46	  # delays the failure being recorded — and it must be recorded, because the
    47	  # April incident was invisible for as long as nobody looked.
    48	  rescue_from Net::SMTPAuthenticationError,
    49	              Net::SMTPFatalError,
    50	              Net::SMTPSyntaxError do |error|
    51	    Rails.logger.error(
    52	      "ApplicationMailDeliveryJob: mail permanently rejected, not retrying — " \
    53	      "#{error.class}: #{error.message}"
    54	    )
    55	    raise error
    56	  end
    57	end
### lib/tasks/jobs.rake
     1	# Visibility for the two things this app used to fail at silently:
     2	# posts that never got published, and background jobs that died.
     3	#
     4	# Both tasks are read-only and exit non-zero when they find something, so they
     5	# work under `kamal app exec` and can be wired to a monitor later without
     6	# changing anything.
     7	namespace :blog do
     8	  desc "List posts whose publish time has passed but which are still scheduled (exit 1 if any)"
     9	  task stuck: :environment do
    10	    # The command-line view of Post.publish_stuck — the same scope the
    11	    # /admin/posts banner reads. This exists because every other channel has a
    12	    # dependency the failure might have taken out: email needs SMTP (which
    13	    # failed here 2026-04-07), the banner needs a browser and the admin
    14	    # password. This needs a shell.
    15	    stuck = Post.publish_stuck.order(:published_at)
    16	
    17	    if stuck.empty?
    18	      puts "No stuck posts. (#{Post.where(status: 'scheduled').count} scheduled, all still within the #{Post::PUBLISH_GRACE.inspect} grace window.)"
    19	      next
    20	    end
    21	
    22	    puts "#{stuck.size} post(s) past due and still scheduled:"
    23	    stuck.each do |post|
    24	      overdue = post.publish_overdue_by
    25	      puts "  #{post.slug} (id=#{post.id})"
    26	      puts "    scheduled : #{post.published_at&.iso8601 || '(none)'}#{overdue ? "  (#{(overdue / 3600).round} h ago)" : ''}"
    27	      puts "    body_ko   : #{post.body_ko.present? ? "#{post.body_ko.to_s.length} bytes" : 'EMPTY — this is why a published post is rejected'}"
    28	      puts "    reason    : #{post.publish_error.presence || '(not recorded — the job may never have reached this post)'}"
    29	      puts "    edit      : /admin/posts/#{post.id}/edit"
    30	    end
    31	
    32	    abort "blog:stuck: #{stuck.size} post(s) need attention"
    33	  end
    34	end
    35	
    36	namespace :jobs do
    37	  desc "List Solid Queue failed executions (exit 1 if any)"
    38	  task failed: :environment do
    39	    # Solid Queue does not retry on its own: ClaimedExecution#perform calls
    40	    # failed_with(error) and re-raises, and FailedExecution#retry is manual. So
    41	    # anything in this table is work that stopped and stayed stopped — and until
    42	    # now nothing in this app ever looked at it.
    43	    # Guard on the TABLE, not on the constant. The gem is in the default bundle
    44	    # group, so SolidQueue::FailedExecution is defined in every environment —
    45	    # but only production sets `queue_adapter = :solid_queue`
    46	    # (config/environments/production.rb:53) and only production has the queue
    47	    # database, so in development the constant resolves and the query then dies
    48	    # with PG::UndefinedTable. Measured, after writing it the other way first.
    49	    unless defined?(SolidQueue::FailedExecution) && SolidQueue::FailedExecution.table_exists?
    50	      puts "Solid Queue's queue database is not present here " \
    51	           "(queue adapter: #{ActiveJob::Base.queue_adapter.class}). " \
    52	           "This task is meaningful in production, where the adapter is :solid_queue."
    53	      next
    54	    end
    55	
    56	    failures = SolidQueue::FailedExecution.includes(:job).order(created_at: :desc)
    57	
    58	    if failures.empty?
    59	      puts "No failed job executions."
    60	      next
    61	    end
    62	
    63	    puts "#{failures.size} failed job execution(s), newest first:"
    64	    failures.each do |failure|
    65	      puts "  #{failure.job&.class_name || '(unknown job)'}  failed #{failure.created_at&.iso8601}"
    66	      puts "    #{failure.exception_class}: #{failure.message}"
    67	      puts "    job id #{failure.job_id}  —  retry with: SolidQueue::FailedExecution.find(#{failure.id}).retry"
    68	    end
    69	
    70	    abort "jobs:failed: #{failures.size} failed execution(s)"
    71	  end
    72	end

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "nl -ba test/controllers/api/safe_events_controller_test.rb; rg -n -C 4 'create_table \"safe_events\"' db/schema.rb; rg -n \"remote_ip|session|cookies|Set-Cookie|safe_events\" app config lib test | head -200; nl -ba public/safe/jp/jp.js; rg -n \"sfEvent|SF_PARAMS|safe_events|purpose\" public/safe/index.html" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
     1	require "test_helper"
     2	require_relative "../../support/cache_store_helper"
     3	
     4	# What this endpoint stores is the whole security property, so the tests are
     5	# written from the outside: a request goes in, and the assertion is on the row
     6	# count and on the stored hash — never on the controller's internals.
     7	class Api::SafeEventsControllerTest < ActionDispatch::IntegrationTest
     8	  include CacheStoreHelper
     9	
    10	  setup { SafeEvent.delete_all }
    11	
    12	  def post_event(payload)
    13	    post "/api/safe_events", params: payload.to_json,
    14	                             headers: { "CONTENT_TYPE" => "application/json" }
    15	  end
    16	
    17	  test "stores a whitelisted event" do
    18	    assert_difference "SafeEvent.count", 1 do
    19	      post_event(name: "doc_class", props: { doc_class: "shikaku_kakuninsho", locale: "ja", from: "nyusatsu" })
    20	    end
    21	
    22	    assert_response :no_content
    23	    event = SafeEvent.last
    24	    assert_equal "doc_class", event.name
    25	    assert_equal({ "doc_class" => "shikaku_kakuninsho", "locale" => "ja", "from" => "nyusatsu" }, event.props)
    26	  end
    27	
    28	  test "rejects an event name that is not on the whitelist" do
    29	    assert_no_difference "SafeEvent.count" do
    30	      post_event(name: "keystroke", props: { locale: "ja" })
    31	    end
    32	
    33	    assert_response :unprocessable_entity
    34	  end
    35	
    36	  test "rejects a key that is not allowed for that event" do
    37	    # `format` is meaningful on a download, not on a landing view.
    38	    assert_no_difference "SafeEvent.count" do
    39	      post_event(name: "landing_view", props: { from: "nyusatsu", format: "pdf" })
    40	    end
    41	
    42	    assert_response :unprocessable_entity
    43	  end
    44	
    45	  test "rejects a value that is not on the whitelist" do
    46	    assert_no_difference "SafeEvent.count" do
    47	      post_event(name: "doc_class", props: { doc_class: "passport_scan", locale: "ja" })
    48	    end
    49	
    50	    assert_response :unprocessable_entity
    51	  end
    52	
    53	  # The point of the endpoint is that these cannot be smuggled in. Each of
    54	  # these is a key a well-meaning future change might add; all must bounce.
    55	  test "rejects free text, file names, coordinates and identifiers" do
    56	    [
    57	      { name: "upload", props: { ext: "pdf", filename: "健康保険証.pdf" } },
    58	      { name: "upload", props: { ext: "pdf", text: "被保険者番号 1234567" } },
    59	      { name: "download", props: { format: "pdf", box: "12,40,180,22" } },
    60	      { name: "landing_view", props: { from: "nyusatsu", ip: "203.0.113.9" } },
    61	      { name: "landing_view", props: { from: "nyusatsu", visitor_id: "abc123" } },
    62	      { name: "upload", props: { ext: "pdf", pages: "17" } }
    63	    ].each do |payload|
    64	      assert_no_difference "SafeEvent.count", "#{payload[:props].keys.last} was accepted" do
    65	        post_event(payload)
    66	      end
    67	      assert_response :unprocessable_entity
    68	    end
    69	  end
    70	
    71	  test "a nested value cannot sneak past the value whitelist" do
    72	    assert_no_difference "SafeEvent.count" do
    73	      post_event(name: "doc_class", props: { doc_class: { evil: "shikaku_kakuninsho" } })
    74	    end
    75	
    76	    assert_response :unprocessable_entity
    77	  end
    78	
    79	  test "an event with no props at all is stored" do
    80	    assert_difference "SafeEvent.count", 1 do
    81	      post_event(name: "upload")
    82	    end
    83	
    84	    assert_response :no_content
    85	    assert_equal({}, SafeEvent.last.props)
    86	  end
    87	
    88	  # Not a style assertion — it is the promise. If any of these columns ever
    89	  # appears, the privacy claim on /safe/ and the three landing pages is false.
    90	  test "the table has no column that could identify a visitor" do
    91	    forbidden = %w[ip ip_address ip_hash remote_ip user_agent session_id visitor_id fingerprint cookie referer email]
    92	    present = SafeEvent.column_names & forbidden
    93	    assert_empty present, "safe_events must not carry #{present.join(', ')}"
    94	    assert_equal %w[created_at id name props], SafeEvent.column_names.sort
    95	  end
    96	
    97	  # Measured before the fix: POST /api/safe_events?locale=ja answered 204 AND
    98	  # Set-Cookie: locale=ja, expiring in a year. ApplicationController#set_locale
    99	  # writes that cookie whenever params[:locale] is present, and params includes
   100	  # the query string — correct for a page, wrong for a counter that promises it
   101	  # identifies nobody. Api::BaseController skips the filter for every /api/ route.
   102	  test "no /api/ endpoint can plant a cookie" do
   103	    [
   104	      [ "/api/safe_events?locale=ja", { name: "landing_view", props: { from: "direct" } } ],
   105	      [ "/api/jp_pilot?locale=ja", { company: "x", industry: "other", monthly_count: "1-2", email: "a@b.co.jp" } ]
   106	    ].each do |path, payload|
   107	      post path, params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
   108	      assert_empty response.headers.to_h.slice("Set-Cookie", "set-cookie"),
   109	                   "#{path} set a cookie: #{response.headers['Set-Cookie'] || response.headers['set-cookie']}"
   110	      assert_empty cookies.to_hash, "#{path} left cookies: #{cookies.to_hash.inspect}"
   111	    end
   112	  end
   113	
   114	  # Guards the test above: if a locale-prefixed PAGE stopped setting the cookie
   115	  # too, the assertion would pass for the wrong reason and nobody would notice
   116	  # that language switching had broken.
   117	  test "a locale-prefixed page still does set the cookie" do
   118	    get "/ja/faq"
   119	    assert_response :success
   120	    assert_equal "ja", cookies[:locale]
   121	  end
   122	
   123	  test "the whole endpoint is capped and the cap is not per-visitor" do
   124	    with_memory_cache do
   125	      limit = Api::SafeEventsController::THROTTLE_LIMIT
   126	      # Prime the bucket to the limit rather than issuing hundreds of requests:
   127	      # the key shape is part of the contract being asserted, and a test that
   128	      # only counts requests would still pass if the key gained an IP.
   129	      bucket = Time.current.to_i / Api::SafeEventsController::THROTTLE_WINDOW.to_i
   130	      Rails.cache.write("safe_events:all:#{bucket}", limit, expires_in: 2.minutes)
   131	
   132	      assert_no_difference "SafeEvent.count" do
   133	        post_event(name: "landing_view", props: { from: "nyusatsu" })
   134	      end
   135	      assert_response :too_many_requests
   136	    end
   137	  end
   138	
   139	  # Guards the previous test against the null store. If the cap were asserted
   140	  # under the test default, the counter would write to a store that forgets and
   141	  # the limit could never be reached — green regardless of the code.
   142	  test "the cap does not fire without a cache that remembers" do
   143	    limit = Api::SafeEventsController::THROTTLE_LIMIT
   144	    bucket = Time.current.to_i / Api::SafeEventsController::THROTTLE_WINDOW.to_i
   145	    Rails.cache.write("safe_events:all:#{bucket}", limit, expires_in: 2.minutes)
   146	
   147	    assert_difference "SafeEvent.count", 1 do
   148	      post_event(name: "landing_view", props: { from: "nyusatsu" })
   149	    end
   150	    assert_response :no_content
   151	  end
   152	end
130-    t.text "publish_error"
131-    t.index ["slug"], name: "index_posts_on_slug", unique: true
132-  end
133-
134:  create_table "safe_events", force: :cascade do |t|
135-    t.string "name", null: false
136-    t.jsonb "props", default: {}, null: false
137-    t.datetime "created_at", null: false
138-    t.index ["created_at", "name"], name: "index_safe_events_on_created_at_and_name"
test/controllers/api/safe_events_controller_test.rb:13:    post "/api/safe_events", params: payload.to_json,
test/controllers/api/safe_events_controller_test.rb:91:    forbidden = %w[ip ip_address ip_hash remote_ip user_agent session_id visitor_id fingerprint cookie referer email]
test/controllers/api/safe_events_controller_test.rb:93:    assert_empty present, "safe_events must not carry #{present.join(', ')}"
test/controllers/api/safe_events_controller_test.rb:97:  # Measured before the fix: POST /api/safe_events?locale=ja answered 204 AND
test/controllers/api/safe_events_controller_test.rb:98:  # Set-Cookie: locale=ja, expiring in a year. ApplicationController#set_locale
test/controllers/api/safe_events_controller_test.rb:104:      [ "/api/safe_events?locale=ja", { name: "landing_view", props: { from: "direct" } } ],
test/controllers/api/safe_events_controller_test.rb:108:      assert_empty response.headers.to_h.slice("Set-Cookie", "set-cookie"),
test/controllers/api/safe_events_controller_test.rb:109:                   "#{path} set a cookie: #{response.headers['Set-Cookie'] || response.headers['set-cookie']}"
test/controllers/api/safe_events_controller_test.rb:110:      assert_empty cookies.to_hash, "#{path} left cookies: #{cookies.to_hash.inspect}"
test/controllers/api/safe_events_controller_test.rb:120:    assert_equal "ja", cookies[:locale]
test/controllers/api/safe_events_controller_test.rb:130:      Rails.cache.write("safe_events:all:#{bucket}", limit, expires_in: 2.minutes)
test/controllers/api/safe_events_controller_test.rb:145:    Rails.cache.write("safe_events:all:#{bucket}", limit, expires_in: 2.minutes)
config/initializers/content_security_policy.rb:19:#   # Generate session nonces for permitted importmap, inline scripts, and inline styles.
config/initializers/content_security_policy.rb:20:#   config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
lib/tasks/safe.rake:52:    lines << "> **이 숫자는 이벤트 수이며 사용자 수가 아니다.** `safe_events` 에는 방문자를"
lib/tasks/safe.rake:61:      lines << "① 실제로 트래픽이 없었다 ② `/api/safe_events` 가 거부하고 있다(422 — 화이트리스트 불일치)"
test/sw/README.md:46:(The repo carried a symlink to a per-session scratch directory for a while; it
config/environments/production.rb:30:  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
config/routes.rb:75:  #   safe_events — anonymous category counters from /safe/ and the landings
config/routes.rb:77:  post "/api/safe_events", to: "api/safe_events#create"
config/routes.rb:80:    get  "login",  to: "sessions#new",     as: :login
config/routes.rb:81:    post "login",  to: "sessions#create"
config/routes.rb:82:    delete "logout", to: "sessions#destroy", as: :logout
app/controllers/api/safe_scan_controller.rb:97:      key   = "safe_scan:#{request.remote_ip}:#{Time.current.strftime('%Y%m%d%H')}"
app/controllers/api/safe_events_controller.rb:1:# app/controllers/api/safe_events_controller.rb
app/controllers/api/safe_events_controller.rb:5:#   POST /api/safe_events
app/controllers/api/safe_events_controller.rb:14:#   * It does not look at request.remote_ip. Not to store it, not to hash it,
app/controllers/api/safe_events_controller.rb:19:#   * It does not set or read a cookie, and it does not touch the session.
app/controllers/api/safe_events_controller.rb:75:      key    = "safe_events:all:#{bucket}"
app/controllers/api/jp_pilot_controller.rb:16:# which refuses to touch remote_ip at all. This endpoint already takes a name
app/controllers/api/jp_pilot_controller.rb:74:      key   = "jp_pilot:#{request.remote_ip}:#{Time.current.to_i / RATE_WINDOW.to_i}"
app/controllers/api/base_controller.rb:9:  #     POST /api/safe_events?locale=ja   →  204 + Set-Cookie: locale=ja
app/controllers/api/base_controller.rb:17:  # Japanese wording, and safe_events answers with no body at all. So the locale
app/controllers/api/base_controller.rb:23:  # them read the session or act on behalf of a signed-in user, so there is no
app/controllers/admin/base_controller.rb:10:      unless session[:admin_authenticated]
app/controllers/application_controller.rb:18:    requested = params[:locale].presence || cookies[:locale].presence || locale_from_browser
app/controllers/application_controller.rb:24:      cookies[:locale] = { value: locale, expires: 1.year.from_now }
app/controllers/admin/sessions_controller.rb:10:        session[:admin_authenticated] = true
app/controllers/admin/sessions_controller.rb:19:      session.delete(:admin_authenticated)
test/safe/jp_landing_check.mjs:98: * The status matters as much as the payload: /api/safe_events answers 204 only
test/safe/jp_landing_check.mjs:106:    if (new URL(res.url()).pathname === '/api/safe_events') statuses.push(res.status());
test/safe/jp_landing_check.mjs:113:      if (String(url).indexOf('/api/safe_events') === -1) return;
     1	/* SafeFile JP landing pages — measurement + pilot form.
     2	 *
     3	 * Two jobs, both deliberately small:
     4	 *
     5	 *  1. landing_view / cta_click counters, sent to our OWN /api/safe_events with
     6	 *     navigator.sendBeacon. Category values only — the page's `from` slug and
     7	 *     the purpose the CTA carries. No cookie is set, no identifier is
     8	 *     generated, nothing is read back. There is no third-party script on these
     9	 *     pages and this file must never become the place one is added.
    10	 *
    11	 *  2. The pilot form on /safe/jp/nyusatsu/, posted as JSON so the page can show
    12	 *     a thank-you in place without a navigation.
    13	 *
    14	 * Every failure here is silent by design: a counter that cannot be sent must
    15	 * not change what the visitor sees. The form is the exception — a submit that
    16	 * fails says so, because the visitor is waiting on it.
    17	 */
    18	(function () {
    19	  'use strict';
    20	
    21	  var FROM = document.documentElement.getAttribute('data-from') || 'direct';
    22	
    23	  function beacon(name, props) {
    24	    try {
    25	      var body = JSON.stringify({ name: name, props: props || {} });
    26	      var blob = new Blob([body], { type: 'application/json' });
    27	      if (navigator.sendBeacon && navigator.sendBeacon('/api/safe_events', blob)) return;
    28	      // sendBeacon returns false when the queue is full; a keepalive fetch is
    29	      // the documented fallback and is still fire-and-forget.
    30	      fetch('/api/safe_events', { method: 'POST', headers: { 'content-type': 'application/json' }, body: body, keepalive: true }).catch(function () {});
    31	    } catch (e) { /* never surfaces */ }
    32	  }
    33	
    34	  beacon('landing_view', { from: FROM, locale: 'ja' });
    35	
    36	  // CTA clicks. `data-purpose` mirrors the purpose in the link's own query
    37	  // string so the counter and the destination cannot disagree.
    38	  Array.prototype.forEach.call(document.querySelectorAll('[data-cta]'), function (el) {
    39	    el.addEventListener('click', function () {
    40	      var p = { from: FROM, locale: 'ja' };
    41	      var purpose = el.getAttribute('data-purpose');
    42	      if (purpose) p.purpose = purpose;
    43	      beacon('cta_click', p);
    44	    });
    45	  });
    46	
    47	  /* ── pilot form ── */
    48	  var form = document.getElementById('pilotForm');
    49	  if (!form) return;
    50	
    51	  var msg = document.getElementById('pilotMsg');
    52	  var btn = document.getElementById('pilotSubmit');
    53	
    54	  function show(kind, text) {
    55	    msg.className = 'pf-msg ' + kind;
    56	    msg.textContent = text;
    57	  }
    58	
    59	  form.addEventListener('submit', function (ev) {
    60	    ev.preventDefault();
    61	    var fd = new FormData(form);
    62	    var payload = {};
    63	    fd.forEach(function (v, k) { payload[k] = v; });
    64	    payload.from = FROM;
    65	
    66	    btn.disabled = true;
    67	    var prev = btn.textContent;
    68	    btn.textContent = '送信中…';
    69	
    70	    fetch('/api/jp_pilot', {
    71	      method: 'POST',
    72	      headers: { 'content-type': 'application/json' },
    73	      body: JSON.stringify(payload)
    74	    }).then(function (res) {
    75	      if (res.status === 201) {
    76	        form.reset();
    77	        show('ok', 'お申し込みをお受けしました。2営業日以内にご連絡いたします。よく提出される発注者名をお知らせいただいた場合は、その指示に合わせたプリセットを用意してお送りします。');
    78	        form.querySelectorAll('input, select, button').forEach(function (el) { el.disabled = true; });
    79	        return;
    80	      }
    81	      if (res.status === 429) {
    82	        show('err', '送信が集中しています。しばらくしてからもう一度お試しください。');
    83	        return;
    84	      }
    85	      // The server answers with FIELD NAMES, never rendered messages — a
    86	      // Japanese page must not display the server's locale. The wording lives
    87	      // here, next to the labels it refers to.
    88	      var FIELD_JA = {
    89	        company: '会社名',
    90	        industry: '業種',
    91	        monthly_count: '月間提出件数',
    92	        authority: 'よく使う発注者',
    93	        email: '連絡先メール',
    94	        from: '流入元'
    95	      };
    96	      return res.json().then(function (j) {
    97	        var fields = (j && j.errors && j.errors.length)
    98	          ? j.errors.map(function (f) { return FIELD_JA[f] || f; })
    99	          : [];
   100	        show('err', fields.length
   101	          ? 'つぎの項目をご確認ください：' + fields.join('、')
   102	          : '入力内容をご確認ください。');
   103	      }).catch(function () {
   104	        show('err', '入力内容をご確認ください。');
   105	      });
   106	    }).catch(function () {
   107	      show('err', '送信できませんでした。通信環境をご確認のうえ、もう一度お試しください。chaop2@gmail.com へ直接ご連絡いただいても対応いたします。');
   108	    }).finally(function () {
   109	      if (msg.className.indexOf('ok') === -1) { btn.disabled = false; btn.textContent = prev; }
   110	    });
   111	  });
   112	})();
198:.jp-bar .jp-purpose-l{font-size:12px;color:var(--sub)}
375:            <label class="jp-purpose-l" for="jpPurpose" data-i18n="jpPurposeLabel">提出目的</label>
567:  jpFields:{address_loose:'문서 내 주소',tel:'전화·FAX',doc_shikaku_kakuninsho:'資格確認書(자격확인서)', doc_unten_menkyo:'運転免許証(운전면허증)', doc_mynumber_card:'マイナンバーカード(마이넘버카드)', doc_juminhyo:'住民票(주민표)', side_front:'앞면', side_back:'뒷면', purpose_identity_submit:'本人確認 제출', purpose_my_number_procedure:'個人番号 절차', purpose_bid_attachment:'입찰 첨부', purpose_consult_share:'상담용 공유', back_all:'뒷면 전체', my_number:'개인번호', jumin_code:'주민표 코드', hokensha_bango:'보험자번호', kigo:'기호', bango:'번호', edaban:'가지번호', hihokensha_bango:'피보험자번호', qr:'2차원 코드', license_no:'면허증번호', biko_change:'비고란(변경 기재)', organ_donor:'장기기증 의사표시란', setaiin:'다른 세대원', honseki:'본적', hittosha:'필두자', sex:'성별', name:'성명', birth:'생년월일', address:'주소', expiry:'유효기간', issue:'교부일', issuer:'발행자'},
624:  jpFields:{address_loose:'Address in body',tel:'Phone / FAX',doc_shikaku_kakuninsho:'Qualification certificate (資格確認書)', doc_unten_menkyo:'Driver\'s licence (運転免許証)', doc_mynumber_card:'My Number card', doc_juminhyo:'Residence record (住民票)', side_front:'front', side_back:'back', purpose_identity_submit:'Identity verification', purpose_my_number_procedure:'My Number procedure', purpose_bid_attachment:'Tender attachment', purpose_consult_share:'Sharing for advice', back_all:'Entire back face', my_number:'My Number', jumin_code:'Residence code', hokensha_bango:'Insurer number', kigo:'Symbol', bango:'Number', edaban:'Branch number', hihokensha_bango:'Insured number', qr:'2-D code', license_no:'Licence number', biko_change:'Remarks (changes)', organ_donor:'Organ donation section', setaiin:'Other household members', honseki:'Registered domicile', hittosha:'Head of register', sex:'Sex', name:'Name', birth:'Date of birth', address:'Address', expiry:'Valid until', issue:'Issued', issuer:'Issuer'},
625:  jpPurposeLabel:'Purpose of submission', jpBackNotice:'If identity is what needs checking, submit the front face only. Under the My Number Act, copying or keeping a My Number for anything other than a task the law recognises may be restricted. Choose “My Number procedure” only when the recipient’s own instructions explicitly ask for the My Number (back face).', jpKeepWarn:'The recipient asks for this field. Hiding it may get your submission rejected.', jpWarnUnclassified:'The document type could not be identified, so no automatic redaction was applied. Please select the areas to cover by hand.', jpWarnLowconf:'Confidence in the document type is low, so candidate bands were applied by default. Please check them.', jpEmptyPurpose:'None of the fields found in this document has a rule for this purpose. Select the areas to cover by hand.', jpMnConfirm:'I have checked that the recipient’s instructions explicitly ask for the My Number (back face). Do not release this if they do not.', jpLegalSection:'Statutory / recipient rules', jpLegalWarn:'This band has a legal basis. Releasing it sends data whose collection or retention may be restricted by law.', keepSection:'Fields to keep visible',
626:  reasons:{name:'Possibly a name', jp_auto:'Hidden automatically (legal basis)', jp_gate:'Hidden for this purpose', jp_recommend:'Recommended to hide', jp_optional:'Optional', jp_keep:'Recipient needs this — keep it', addr:'Possibly an address', addr_contact:'Possibly an address · near contact info', addr_edge:'Possibly an address · header/footer', addr_kw:'Possibly an address · place/street term'},
681:  jpFields:{address_loose:'本文中の住所',tel:'電話・FAX',doc_shikaku_kakuninsho:'資格確認書', doc_unten_menkyo:'運転免許証', doc_mynumber_card:'マイナンバーカード', doc_juminhyo:'住民票の写し', side_front:'表面', side_back:'裏面', purpose_identity_submit:'本人確認提出', purpose_my_number_procedure:'個人番号手続', purpose_bid_attachment:'入札添付', purpose_consult_share:'相談用共有', back_all:'裏面全体', my_number:'個人番号', jumin_code:'住民票コード', hokensha_bango:'保険者番号', kigo:'記号', bango:'番号', edaban:'枝番', hihokensha_bango:'被保険者番号', qr:'二次元コード', license_no:'免許証番号', biko_change:'備考欄（変更記載）', organ_donor:'臓器提供意思表示欄', setaiin:'本人以外の世帯員', honseki:'本籍', hittosha:'筆頭者', sex:'性別', name:'氏名', birth:'生年月日', address:'住所', expiry:'有効期限', issue:'交付日', issuer:'発行者'},
738:  jpFields:{address_loose:'Dirección en el texto',tel:'Teléfono / FAX',doc_shikaku_kakuninsho:'Certificado de cobertura (資格確認書)', doc_unten_menkyo:'Permiso de conducir (運転免許証)', doc_mynumber_card:'Tarjeta My Number', doc_juminhyo:'Certificado de residencia (住民票)', side_front:'anverso', side_back:'reverso', purpose_identity_submit:'Verificación de identidad', purpose_my_number_procedure:'Trámite de My Number', purpose_bid_attachment:'Anexo de licitación', purpose_consult_share:'Compartir para consulta', back_all:'Todo el reverso', my_number:'My Number', jumin_code:'Código de residencia', hokensha_bango:'N.º de aseguradora', kigo:'Símbolo', bango:'Número', edaban:'N.º de rama', hihokensha_bango:'N.º de asegurado', qr:'Código 2D', license_no:'N.º de permiso', biko_change:'Observaciones (cambios)', organ_donor:'Apartado de donación de órganos', setaiin:'Otros miembros del hogar', honseki:'Domicilio registral', hittosha:'Titular del registro', sex:'Sexo', name:'Nombre', birth:'Fecha de nacimiento', address:'Dirección', expiry:'Válido hasta', issue:'Emitido', issuer:'Emisor'},
752:   /safe/?lang=ja&purpose=bid_attachment&from=nyusatsu
753:   Three read-only hints, nothing more. `lang` and `purpose` only preselect UI
756:const SF_PARAMS = (() => {
762:    purpose: get('purpose'),                        // validated by jpSetPurpose
771:  if (SF_PARAMS.lang) return SF_PARAMS.lang;
806:function sfEvent(name, props){
808:    const body = JSON.stringify({ name, props: Object.assign({ locale: LANG, from: SF_PARAMS.from }, props||{}) });
810:    if (navigator.sendBeacon && navigator.sendBeacon('/api/safe_events', blob)) return;
811:    fetch('/api/safe_events', { method:'POST', headers:{'content-type':'application/json'}, body, keepalive:true }).catch(()=>{});
1150:   says may be hidden for the selected purpose. */
1336:   資格確認書 and 住民票 have no entry on purpose: they are not two-sided cards,
1540:   — it derives (doc, field, purpose) → level from the JSON, reads this table out
1549:   A (doc, field, purpose) the matrix does not name is `null`: not offered at
1551:   enumerates every purpose it means to allow, and silence is not permission
1637:function jpLevel(doc, field, purpose){
1641:    if (r[lv] && r[lv].includes(purpose)) return lv;
2060:// The starting purpose is 'identity_submit' unless a landing page asked for
2061:// another one (/safe/?purpose=bid_attachment). resetAll() rebuilds this state
2065:const JP_PURPOSE0 = JP_PURPOSES.includes(SF_PARAMS.purpose) ? SF_PARAMS.purpose : 'identity_submit';
2066:const JP_STATE0 = () => ({ cls: null, pageCls: [], purpose: JP_PURPOSE0, findings: [], warn: null, mnConfirmed: false });
2069:  const keepPurpose = jpState.purpose;
2070:  jpState = JP_STATE0(); jpState.purpose = keepPurpose;
2109:// Build entities from the findings for the current purpose. Called on load and
2110:// on every purpose change — the purpose IS the policy, so it re-derives rather
2112:/* The 個人番号 purpose gate needs more than a dropdown. Choosing 「個人番号手続」
2116:   recipient is entitled to it (Codex 4-4). So the release requires the purpose
2118:function jpMnGateOpen(){ return jpState.purpose === 'my_number_procedure' && jpState.mnConfirmed; }
2123:  const purpose = jpState.purpose;
2135:  // Resolve the level for one finding under the current purpose, including the
2138:    let level = jpLevel(doc, field, purpose), note = null;
2141:    // been confirmed, so the 番号法 band stays as if the purpose were 本人確認.
2142:    if (level === 'keep' && JP_MN_GATED.has(field) && purpose === 'my_number_procedure' && !jpState.mnConfirmed){
2162:  // マイナンバーカード裏面 under a 本人確認 purpose: the whole face, PER PAGE that
2191:  jpState.purpose = p;
2192:  // Switching purpose always re-asks for the 個人番号 confirmation. A checkbox
2193:  // left ticked from a previous purpose is not a confirmation of this one.
2197:  sfEvent('purpose', { purpose: p, doc_class: sfDocClass() });
2222:  sel.innerHTML = JP_PURPOSES.map(p => `<option value="${p}">${escapeHtml(jpFieldLabel('purpose_' + p))}</option>`).join('');
2223:  sel.value = jpState.purpose;
2234:    const need = hasMn && jpState.purpose === 'my_number_procedure';
2239:  /* The matrix names every (document, field, purpose) it means to offer, and a
2241:     but it means switching purpose can empty the list completely: 資格確認書
2564:    sfEvent('upload', { ext: SF_LAST_EXT || 'other', pages: sfPagesBucket(pages.length) });
2565:    sfEvent('doc_class', { doc_class: sfDocClass() });
2605:    // to submit. A caller that knows better (the JP purpose presets, where the
3092:  // `purpose` is only meaningful on a classified Japanese document — jpState
3094:  // inflate the purpose counts with documents that never had one.
3096:  sfEvent('download', jpState.cls
3097:    ? { format: lastOut.fmt, doc_class: dc, purpose: jpState.purpose }
3197:/* A ?purpose= from a landing page preselects the submission purpose so the
3203:if (SF_PARAMS.purpose) jpSetPurpose(SF_PARAMS.purpose);

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'git show 5a320b5''^:app/controllers/api/safe_scan_controller.rb | nl -ba | sed -n '"'1,35p'; git diff 5a320b5"'^..HEAD -- app/controllers/api/base_controller.rb app/controllers/api/safe_scan_controller.rb app/controllers/api/jp_pilot_controller.rb app/controllers/api/safe_events_controller.rb test/controllers/api/safe_events_controller_test.rb; sed -n '"'740,825p' public/safe/index.html | nl -ba -v740; sed -n '2180,2210p' public/safe/index.html | nl -ba -v2180; sed -n '3185,3210p' public/safe/index.html | nl -ba -v3185" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
     1	# app/controllers/api/safe_scan_controller.rb
     2	#
     3	# SafeFile의 "AI 정밀 검사"를 중계하는 엔드포인트.
     4	# 브라우저 → 이 컨트롤러 → Anthropic API 순서로 흘러가며,
     5	# API 키는 서버 환경변수(ANTHROPIC_API_KEY)에만 존재한다.
     6	#
     7	# 요청:  POST /api/safe_scan
     8	#        { "text": "문서 내용" }                          — 텍스트 검사
     9	#        { "image": { "data": "<base64>", "media": "image/png" } } — 이미지 검사(OCR 포함)
    10	# 응답:  { "raw": "<모델이 출력한 JSON 문자열>" }
    11	#
    12	require "net/http"
    13	
    14	module Api
    15	  class SafeScanController < ApplicationController
    16	    skip_before_action :verify_authenticity_token
    17	
    18	    ANTHROPIC_URL = "https://api.anthropic.com/v1/messages".freeze
    19	    # 비용 최적화: 개인정보 추출은 소형 모델로 충분하다.
    20	    MODEL         = "claude-haiku-4-5-20251001".freeze
    21	    MAX_TEXT      = 8_000          # 문자 수 제한 (약 1~2페이지)
    22	    MAX_IMAGE_B64 = 7_000_000      # base64 기준 약 5MB
    23	    HOURLY_LIMIT  = 30             # IP당 시간당 AI 검사 횟수
    24	
    25	    TEXT_PROMPT = <<~PROMPT.freeze
    26	      다음 문서에서 개인정보를 모두 찾아라. 특히 사람 이름, 회사·기관명, 직책, 주소,
    27	      건강 관련 정보처럼 패턴이 없는 것들. 반드시 JSON 배열만 출력하라. 마크다운·설명 금지.
    28	      형식: [{"type":"name|phone|email|rrn|ssn|passport|license|card|account|birth|address|company|title|ip|url|health|other","value":"문서에 나온 원문 그대로"}]
    29	
    30	      문서:
    31	      """
    32	      %<doc>s
    33	      """
    34	    PROMPT
    35	
diff --git a/app/controllers/api/base_controller.rb b/app/controllers/api/base_controller.rb
new file mode 100644
index 0000000..bc6add8
--- /dev/null
+++ b/app/controllers/api/base_controller.rb
@@ -0,0 +1,29 @@
+module Api
+  # Shared base for the three JSON endpoints under /api/.
+  #
+  # It exists for one reason: `ApplicationController#set_locale` writes a
+  # one-year `locale` cookie whenever `params[:locale]` is present, and
+  # `params` includes the query string. That is correct for a page — the visitor
+  # clicked a language — but on an API route it means
+  #
+  #     POST /api/safe_events?locale=ja   →  204 + Set-Cookie: locale=ja
+  #
+  # which was measured, not theorised. An endpoint whose entire purpose is to
+  # count things WITHOUT identifying anyone must not be able to plant a
+  # persistent cookie, and the page that calls it promises exactly that.
+  #
+  # Nothing under /api/ renders a localized response: safe_scan's prompts are
+  # hardcoded, jp_pilot answers with field NAMES so the page can supply its own
+  # Japanese wording, and safe_events answers with no body at all. So the locale
+  # filter has nothing to contribute here beyond the side effect.
+  #
+  # CSRF verification is skipped for the same set, as it was before: these are
+  # JSON endpoints called with fetch/sendBeacon from a static page that has no
+  # Rails-rendered form and therefore no authenticity token to carry. None of
+  # them read the session or act on behalf of a signed-in user, so there is no
+  # authority for a cross-site request to borrow.
+  class BaseController < ApplicationController
+    skip_before_action :verify_authenticity_token
+    skip_before_action :set_locale
+  end
+end
diff --git a/app/controllers/api/jp_pilot_controller.rb b/app/controllers/api/jp_pilot_controller.rb
new file mode 100644
index 0000000..018708f
--- /dev/null
+++ b/app/controllers/api/jp_pilot_controller.rb
@@ -0,0 +1,80 @@
+# app/controllers/api/jp_pilot_controller.rb
+#
+# Pilot sign-ups from the Japanese landing page (public/safe/jp/nyusatsu/).
+#
+#   POST /api/jp_pilot
+#   { company, industry, monthly_count, authority, email, from, website }
+#   → 201 { ok: true } | 422 { errors: [...] } | 429 { error: "rate_limited" }
+#
+# `website` is a honeypot: the form renders it, CSS hides it, a human never
+# fills it. Anything in it means the submitter is not using the form, so the
+# request is DROPPED — and answered with the same 201 a success gets, because a
+# distinguishable rejection is a free oracle for tuning a spam script. The
+# record is simply not written.
+#
+# The per-IP cap here is a different judgement from Api::SafeEventsController,
+# which refuses to touch remote_ip at all. This endpoint already takes a name
+# and an email address on purpose, so it is not an anonymous surface, and a
+# submission form with no per-client ceiling is a mailbox flood waiting to
+# happen. The IP is used for the cache key only — it is never written to the
+# database, in any form.
+module Api
+  class JpPilotController < BaseController
+    RATE_LIMIT  = 3
+    RATE_WINDOW = 10.minutes
+
+    def create
+      return render(json: { error: "rate_limited" }, status: :too_many_requests) if throttled?
+
+      # Honeypot. Looks like a success from the outside; writes nothing.
+      if params[:website].present?
+        Rails.logger.info("[jp_pilot] honeypot rejected a submission")
+        return render(json: { ok: true }, status: :created)
+      end
+
+      req = JpPilotRequest.new(pilot_params)
+
+      if req.save
+        notify(req)
+        render json: { ok: true }, status: :created
+      else
+        # Field NAMES, not rendered messages. The form is Japanese and the page
+        # owns its own wording (public/safe/jp/jp.js); echoing
+        # `errors.full_messages` would put the server's locale on a Japanese
+        # page — and did: the first live check returned
+        # "EmailTranslation missing. Options considered were: …" because the
+        # format validator had no ko message. Returning keys makes that class of
+        # leak impossible instead of fixing one instance of it.
+        render json: { ok: false, errors: req.errors.attribute_names.map(&:to_s).uniq },
+               status: :unprocessable_entity
+      end
+    end
+
+    private
+
+    def pilot_params
+      params.permit(:company, :industry, :monthly_count, :authority, :email, :from)
+            .to_h
+            .transform_values { |v| v.to_s.strip }
+            .tap { |h| h["from"] = "direct" unless JpPilotRequest::FROMS.include?(h["from"]) }
+    end
+
+    # The sign-up is already saved by the time this runs, so a mail failure must
+    # not undo it or turn a stored request into a 422 the applicant sees. It is
+    # logged and the response stays 201 — the row is the record of truth and the
+    # admin list reads it without help from the mailer (the same reasoning as
+    # PublishScheduledPostsJob's derived `publish_stuck` state).
+    def notify(req)
+      JpPilotMailer.pilot_requested(req).deliver_later
+    rescue StandardError => e
+      Rails.logger.error("[jp_pilot] notification enqueue failed for ##{req.id}: #{e.class}: #{e.message}")
+    end
+
+    def throttled?
+      key   = "jp_pilot:#{request.remote_ip}:#{Time.current.to_i / RATE_WINDOW.to_i}"
+      count = Rails.cache.read(key).to_i + 1
+      Rails.cache.write(key, count, expires_in: RATE_WINDOW * 2)
+      count > RATE_LIMIT
+    end
+  end
+end
diff --git a/app/controllers/api/safe_events_controller.rb b/app/controllers/api/safe_events_controller.rb
new file mode 100644
index 0000000..4c469c8
--- /dev/null
+++ b/app/controllers/api/safe_events_controller.rb
@@ -0,0 +1,81 @@
+# app/controllers/api/safe_events_controller.rb
+#
+# Anonymous, category-only usage counters for SafeFile.
+#
+#   POST /api/safe_events
+#   { "name": "doc_class", "props": { "doc_class": "shikaku_kakuninsho", "locale": "ja" } }
+#   → 204 No Content
+#
+# The browser sends these with navigator.sendBeacon and never reads the
+# response, so the status code exists for our logs and tests, not for the page.
+#
+# What this endpoint deliberately does NOT do:
+#
+#   * It does not look at request.remote_ip. Not to store it, not to hash it,
+#     not to rate-limit on it. A per-IP counter is a per-visitor identifier
+#     however it is spelled, and /safe/ promises the processing screen carries
+#     no tracking. The abuse ceiling is instead a flat per-minute cap on the
+#     whole endpoint (see THROTTLE_*), which is blind to who is calling.
+#   * It does not set or read a cookie, and it does not touch the session.
+#   * It stores nothing that is not on SafeEvent's whitelist. The model owns
+#     that list; this controller just refuses what the model will not take.
+module Api
+  class SafeEventsController < BaseController
+    # A global ceiling, not a per-client one. 600 events/minute is far above
+    # what organic use produces and still bounds a flood to something the table
+    # can absorb. It cannot single out an abuser — that is the trade we are
+    # making on purpose, and the reason the cap is generous.
+    THROTTLE_LIMIT  = 600
+    THROTTLE_WINDOW = 1.minute
+
+    # Bounds the work per request. Not the gate — SafeEvent::KEYS is.
+    MAX_KEYS = 12
+
+    def create
+      return head(:too_many_requests) if throttled?
+
+      raw = permitted_props
+      return head(:unprocessable_entity) if raw.nil?
+
+      props = SafeEvent.sanitize(params[:name], raw)
+      return head(:unprocessable_entity) if props.nil?
+
+      SafeEvent.create!(name: params[:name].to_s, props: props)
+      head :no_content
+    rescue ActiveRecord::RecordInvalid
+      # sanitize already rejected everything the model would reject, so this is
+      # a genuine surprise. 422 rather than 500: the client cannot fix it, but
+      # a 500 would page us for a counter.
+      head :unprocessable_entity
+    end
+
+    private
+
+    # Hands SafeEvent.sanitize exactly what the client sent — including keys we
+    # do not know — so an unknown key is REJECTED rather than quietly dropped.
+    #
+    # Filtering to the known keys here would have been the obvious move and is
+    # the wrong one: the request would then succeed while losing a field, and
+    # since sendBeacon discards the response, a client that drifts would look
+    # healthy from both sides. Values are stringified by sanitize, so a nested
+    # hash or array arrives as a string that is not on any whitelist and fails
+    # the same way. Returns nil when the request is already refusable.
+    def permitted_props
+      raw = params[:props]
+      return {} unless raw.respond_to?(:each_pair)
+      return nil if raw.keys.size > MAX_KEYS
+
+      raw.each_pair.to_h { |k, v| [ k.to_s, v ] }
+    end
+
+    # Window-bucketed counter in Rails.cache, same shape as safe_scan's. No
+    # request attribute is part of the key.
+    def throttled?
+      bucket = (Time.current.to_i / THROTTLE_WINDOW.to_i)
+      key    = "safe_events:all:#{bucket}"
+      count  = Rails.cache.read(key).to_i + 1
+      Rails.cache.write(key, count, expires_in: THROTTLE_WINDOW * 2)
+      count > THROTTLE_LIMIT
+    end
+  end
+end
diff --git a/app/controllers/api/safe_scan_controller.rb b/app/controllers/api/safe_scan_controller.rb
index 99c98b1..dfb53ce 100644
--- a/app/controllers/api/safe_scan_controller.rb
+++ b/app/controllers/api/safe_scan_controller.rb
@@ -12,9 +12,7 @@
 require "net/http"
 
 module Api
-  class SafeScanController < ApplicationController
-    skip_before_action :verify_authenticity_token
-
+  class SafeScanController < BaseController
     ANTHROPIC_URL = "https://api.anthropic.com/v1/messages".freeze
     # 비용 최적화: 개인정보 추출은 소형 모델로 충분하다.
     MODEL         = "claude-haiku-4-5-20251001".freeze
diff --git a/test/controllers/api/safe_events_controller_test.rb b/test/controllers/api/safe_events_controller_test.rb
new file mode 100644
index 0000000..77925dc
--- /dev/null
+++ b/test/controllers/api/safe_events_controller_test.rb
@@ -0,0 +1,152 @@
+require "test_helper"
+require_relative "../../support/cache_store_helper"
+
+# What this endpoint stores is the whole security property, so the tests are
+# written from the outside: a request goes in, and the assertion is on the row
+# count and on the stored hash — never on the controller's internals.
+class Api::SafeEventsControllerTest < ActionDispatch::IntegrationTest
+  include CacheStoreHelper
+
+  setup { SafeEvent.delete_all }
+
+  def post_event(payload)
+    post "/api/safe_events", params: payload.to_json,
+                             headers: { "CONTENT_TYPE" => "application/json" }
+  end
+
+  test "stores a whitelisted event" do
+    assert_difference "SafeEvent.count", 1 do
+      post_event(name: "doc_class", props: { doc_class: "shikaku_kakuninsho", locale: "ja", from: "nyusatsu" })
+    end
+
+    assert_response :no_content
+    event = SafeEvent.last
+    assert_equal "doc_class", event.name
+    assert_equal({ "doc_class" => "shikaku_kakuninsho", "locale" => "ja", "from" => "nyusatsu" }, event.props)
+  end
+
+  test "rejects an event name that is not on the whitelist" do
+    assert_no_difference "SafeEvent.count" do
+      post_event(name: "keystroke", props: { locale: "ja" })
+    end
+
+    assert_response :unprocessable_entity
+  end
+
+  test "rejects a key that is not allowed for that event" do
+    # `format` is meaningful on a download, not on a landing view.
+    assert_no_difference "SafeEvent.count" do
+      post_event(name: "landing_view", props: { from: "nyusatsu", format: "pdf" })
+    end
+
+    assert_response :unprocessable_entity
+  end
+
+  test "rejects a value that is not on the whitelist" do
+    assert_no_difference "SafeEvent.count" do
+      post_event(name: "doc_class", props: { doc_class: "passport_scan", locale: "ja" })
+    end
+
+    assert_response :unprocessable_entity
+  end
+
+  # The point of the endpoint is that these cannot be smuggled in. Each of
+  # these is a key a well-meaning future change might add; all must bounce.
+  test "rejects free text, file names, coordinates and identifiers" do
+    [
+      { name: "upload", props: { ext: "pdf", filename: "健康保険証.pdf" } },
+      { name: "upload", props: { ext: "pdf", text: "被保険者番号 1234567" } },
+      { name: "download", props: { format: "pdf", box: "12,40,180,22" } },
+      { name: "landing_view", props: { from: "nyusatsu", ip: "203.0.113.9" } },
+      { name: "landing_view", props: { from: "nyusatsu", visitor_id: "abc123" } },
+      { name: "upload", props: { ext: "pdf", pages: "17" } }
+    ].each do |payload|
+      assert_no_difference "SafeEvent.count", "#{payload[:props].keys.last} was accepted" do
+        post_event(payload)
+      end
+      assert_response :unprocessable_entity
+    end
+  end
+
+  test "a nested value cannot sneak past the value whitelist" do
+    assert_no_difference "SafeEvent.count" do
+      post_event(name: "doc_class", props: { doc_class: { evil: "shikaku_kakuninsho" } })
+    end
+
+    assert_response :unprocessable_entity
+  end
+
+  test "an event with no props at all is stored" do
+    assert_difference "SafeEvent.count", 1 do
+      post_event(name: "upload")
+    end
+
+    assert_response :no_content
+    assert_equal({}, SafeEvent.last.props)
+  end
+
+  # Not a style assertion — it is the promise. If any of these columns ever
+  # appears, the privacy claim on /safe/ and the three landing pages is false.
+  test "the table has no column that could identify a visitor" do
+    forbidden = %w[ip ip_address ip_hash remote_ip user_agent session_id visitor_id fingerprint cookie referer email]
+    present = SafeEvent.column_names & forbidden
+    assert_empty present, "safe_events must not carry #{present.join(', ')}"
+    assert_equal %w[created_at id name props], SafeEvent.column_names.sort
+  end
+
+  # Measured before the fix: POST /api/safe_events?locale=ja answered 204 AND
+  # Set-Cookie: locale=ja, expiring in a year. ApplicationController#set_locale
+  # writes that cookie whenever params[:locale] is present, and params includes
+  # the query string — correct for a page, wrong for a counter that promises it
+  # identifies nobody. Api::BaseController skips the filter for every /api/ route.
+  test "no /api/ endpoint can plant a cookie" do
+    [
+      [ "/api/safe_events?locale=ja", { name: "landing_view", props: { from: "direct" } } ],
+      [ "/api/jp_pilot?locale=ja", { company: "x", industry: "other", monthly_count: "1-2", email: "a@b.co.jp" } ]
+    ].each do |path, payload|
+      post path, params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
+      assert_empty response.headers.to_h.slice("Set-Cookie", "set-cookie"),
+                   "#{path} set a cookie: #{response.headers['Set-Cookie'] || response.headers['set-cookie']}"
+      assert_empty cookies.to_hash, "#{path} left cookies: #{cookies.to_hash.inspect}"
+    end
+  end
+
+  # Guards the test above: if a locale-prefixed PAGE stopped setting the cookie
+  # too, the assertion would pass for the wrong reason and nobody would notice
+  # that language switching had broken.
+  test "a locale-prefixed page still does set the cookie" do
+    get "/ja/faq"
+    assert_response :success
+    assert_equal "ja", cookies[:locale]
+  end
+
+  test "the whole endpoint is capped and the cap is not per-visitor" do
+    with_memory_cache do
+      limit = Api::SafeEventsController::THROTTLE_LIMIT
+      # Prime the bucket to the limit rather than issuing hundreds of requests:
+      # the key shape is part of the contract being asserted, and a test that
+      # only counts requests would still pass if the key gained an IP.
+      bucket = Time.current.to_i / Api::SafeEventsController::THROTTLE_WINDOW.to_i
+      Rails.cache.write("safe_events:all:#{bucket}", limit, expires_in: 2.minutes)
+
+      assert_no_difference "SafeEvent.count" do
+        post_event(name: "landing_view", props: { from: "nyusatsu" })
+      end
+      assert_response :too_many_requests
+    end
+  end
+
+  # Guards the previous test against the null store. If the cap were asserted
+  # under the test default, the counter would write to a store that forgets and
+  # the limit could never be reached — green regardless of the code.
+  test "the cap does not fire without a cache that remembers" do
+    limit = Api::SafeEventsController::THROTTLE_LIMIT
+    bucket = Time.current.to_i / Api::SafeEventsController::THROTTLE_WINDOW.to_i
+    Rails.cache.write("safe_events:all:#{bucket}", limit, expires_in: 2.minutes)
+
+    assert_difference "SafeEvent.count", 1 do
+      post_event(name: "landing_view", props: { from: "nyusatsu" })
+    end
+    assert_response :no_content
+  end
+end
   740	  reasons:{name:'Puede ser un nombre', jp_auto:'Oculto automáticamente (base legal)', jp_gate:'Oculto para esta finalidad', jp_recommend:'Se recomienda ocultar', jp_optional:'Opcional', jp_keep:'El destinatario lo necesita', addr:'Puede ser una dirección', addr_contact:'Puede ser una dirección · cerca del contacto', addr_edge:'Puede ser una dirección · encabezado/pie', addr_kw:'Puede ser una dirección · término de lugar/calle'},
   741	  tManualAdded:'Área añadida', tManualRemoved:'Área eliminada', tSelSmall:'Demasiado pequeña — arrastra un poco más.', btnSelectOn:'✓ Seleccionando (desactivar)',
   742	  wmToggle:'Añadir marca de agua (opcional)', wmPlaceholder:'Texto de la marca de agua (editable)', wmCustom:'Personalizado…',
   743	  wmPresets:['Para presentar a ○○','Solo para verificar la identidad','Prohibido otro uso','Presentado a ○○ el {date}'],
   744	  wmQR:'⚠ Revisa la vista previa del resultado para que la marca de agua no cubra ningún código QR, de barras o sello. (El margen inferior se deja libre automáticamente.)',
   745	  pasted:'Texto pegado', aiChars:n=>`${n} caracteres (extraído por IA)`, chars:n=>`${n} caracteres`, pages:n=>`${n} páginas`,
   746	  types:{rrn:'RRN de Corea',ssn:'SSN (EE. UU.)',passport:'N.º de pasaporte',license:'Permiso de conducir',card:'N.º de tarjeta',account:'Cuenta bancaria',phone:'Teléfono',email:'Correo',birth:'Fecha de nacimiento',address:'Dirección',name:'Nombre',company:'Empresa',title:'Cargo',ip:'Dirección IP',url:'Redes · URL',health:'Salud / sensible',other:'Otro',manual:'Manual'}
   747	}
   748	};
   749	const LANGS = ['ko','en','ja','es'];
   750	
   751	/* ───────── entry parameters (set by the JP landing pages) ─────────
   752	   /safe/?lang=ja&purpose=bid_attachment&from=nyusatsu
   753	   Three read-only hints, nothing more. `lang` and `purpose` only preselect UI
   754	   the user can still change; `from` is used for the anonymous counters and for
   755	   nothing else. None of them touch detection. */
   756	const SF_PARAMS = (() => {
   757	  let q; try { q = new URLSearchParams(location.search); } catch(e){ q = null; }
   758	  const get = k => (q ? (q.get(k) || '') : '');
   759	  const from = get('from');
   760	  return {
   761	    lang:    LANGS.includes(get('lang')) ? get('lang') : null,
   762	    purpose: get('purpose'),                        // validated by jpSetPurpose
   763	    from:    ['nyusatsu','honnin','aimae'].includes(from) ? from : 'direct'
   764	  };
   765	})();
   766	
   767	function detectLang(){
   768	  // An explicit ?lang= wins over the remembered choice: it is the most recent
   769	  // explicit signal, and the landing pages are Japanese-only, so a visitor
   770	  // arriving from one should not land in a language they set months ago.
   771	  if (SF_PARAMS.lang) return SF_PARAMS.lang;
   772	  try { const s = localStorage.getItem('safefile_lang'); if (s && LANGS.includes(s)) return s; } catch(e){}
   773	  const n = (navigator.language||'ko').toLowerCase();
   774	  for (const l of LANGS) if (n.startsWith(l)) return l;
   775	  return 'ko';
   776	}
   777	let LANG = detectLang();
   778	const T = () => I18N[LANG];
   779	const INK = '#17140F', PAPER = '#F7F5EF';
   780	
   781	/* ───────── anonymous counters ─────────
   782	   Fire-and-forget category counts to our OWN endpoint. This is the only
   783	   network call this page makes besides the opt-in AI deep scan, and unlike
   784	   that one it carries NO document content: every value is one of a short fixed
   785	   list, enforced again server-side (app/models/safe_event.rb).
   786	
   787	   What is never sent: file name, file size, page text, entity values, box
   788	   coordinates, counts of anything found, any identifier. No cookie is set and
   789	   no response is read. A failure is swallowed — a counter must never change
   790	   what the user sees, and must never be able to block a download. */
   791	let SF_LAST_EXT = null;          // bucketed extension of the loaded file
   792	function sfPagesBucket(n){
   793	  if (n <= 1) return '1';
   794	  if (n === 2) return '2';
   795	  return n <= 5 ? '3-5' : '6+';
   796	}
   797	function sfExtBucket(ext){
   798	  const e = (ext||'').toLowerCase();
   799	  if (e === 'jpeg') return 'jpg';
   800	  return ['pdf','jpg','png','docx'].includes(e) ? e : 'other';
   801	}
   802	function sfDocClass(){
   803	  if (!pages.length) return 'none';
   804	  return jpState.cls ? jpState.cls.doc : 'unclassified';
   805	}
   806	function sfEvent(name, props){
   807	  try{
   808	    const body = JSON.stringify({ name, props: Object.assign({ locale: LANG, from: SF_PARAMS.from }, props||{}) });
   809	    const blob = new Blob([body], { type: 'application/json' });
   810	    if (navigator.sendBeacon && navigator.sendBeacon('/api/safe_events', blob)) return;
   811	    fetch('/api/safe_events', { method:'POST', headers:{'content-type':'application/json'}, body, keepalive:true }).catch(()=>{});
   812	  }catch(e){}
   813	}
   814	
   815	/* ───────── constants ───────── */
   816	const MAX_BYTES = 20*1024*1024;
   817	const MAX_PAGES = 30;
   818	const PDF_WORKER = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
   819	const CDN_TESSERACT = 'https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js';
   820	const CDN_HEIC = 'https://cdn.jsdelivr.net/npm/heic2any@0.0.4/dist/heic2any.min.js';
   821	const CDN_JSPDF = 'https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js';
   822	
   823	/* ───────── state ───────── */
   824	// pages: [{canvas, w, h, ptW, ptH, items:[{str,x,y,w,h}]}]  (x,y,w,h in canvas px, top-left origin)
   825	let pages=[], docText='', docTitle='', entities=[], aiDone=false, showAllCats=false;
  2180	  entities.sort((a,b)=>Object.keys(TYPES).indexOf(a.type)-Object.keys(TYPES).indexOf(b.type));
  2181	  jpRenderBar();
  2182	  renderAll();
  2183	}
  2184	const JP_TYPE = { address_loose:'address', tel:'phone', my_number:'rrn', jumin_code:'rrn', hokensha_bango:'health', kigo:'health',
  2185	  bango:'health', edaban:'health', hihokensha_bango:'health', license_no:'license', qr:'other',
  2186	  back_all:'other', biko_change:'address', organ_donor:'health', setaiin:'name', honseki:'address',
  2187	  hittosha:'name', sex:'other', name:'name', birth:'birth', address:'address', expiry:'other', issue:'other' };
  2188	
  2189	function jpSetPurpose(p){
  2190	  if (!JP_PURPOSES.includes(p)) return;
  2191	  jpState.purpose = p;
  2192	  // Switching purpose always re-asks for the 個人番号 confirmation. A checkbox
  2193	  // left ticked from a previous purpose is not a confirmation of this one.
  2194	  jpState.mnConfirmed = false;
  2195	  const sel = $('jpPurpose'); if (sel) sel.value = p;
  2196	  jpApply();
  2197	  sfEvent('purpose', { purpose: p, doc_class: sfDocClass() });
  2198	}
  2199	function jpSetMnConfirmed(v){ jpState.mnConfirmed = !!v; jpApply(); }
  2200	function jpRenderBar(){
  2201	  const bar = $('jpBar'), warn = $('jpWarn'); if (!bar) return;
  2202	  const cls = jpState.cls;
  2203	  /* The blocking warning is independent of the bar: its whole point is to be
  2204	     visible in the case where there is no classification and therefore no bar.
  2205	     The two states say OPPOSITE things about the output and must not share a
  2206	     string. `unclassified` = no Japanese rule ran, nothing was covered, act.
  2207	     `lowconf` = we know which form this is, every automatic level was demoted
  2208	     to a candidate — which is still default-ON, so bands ARE in the output —
  2209	     and what is owed is a check. The old single string claimed "no automatic
  2210	     redaction was applied" in both, which was false in the second (Codex 6b-1). */
  3185	    });
  3186	  }
  3187	
  3188	  // iOS Safari has no beforeinstallprompt → show the manual A2HS hint after a beat.
  3189	  if (isIosSafari && !isStandalone() && !dismissed()) {
  3190	    setTimeout(() => show('ios'), 1400);
  3191	  }
  3192	})();
  3193	
  3194	/* ───────── init ───────── */
  3195	applyLang();
  3196	renderList();
  3197	/* A ?purpose= from a landing page preselects the submission purpose so the
  3198	   first document loaded is already governed by the right rule set. jpSetPurpose
  3199	   validates the value against JP_PURPOSES and ignores anything else, and
  3200	   jpScan() carries the choice across loads (keepPurpose), so this runs once.
  3201	   It changes no detection — only which rule column the detections are read in,
  3202	   which is what the dropdown does by hand. */
  3203	if (SF_PARAMS.purpose) jpSetPurpose(SF_PARAMS.purpose);
  3204	</script>
  3205	</body>
  3206	</html>

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'nl -ba docs/jp/jp_landing_copy_2026-10-22.md; for f in public/safe/jp/nyusatsu/index.html public/safe/jp/honnin-kakunin/index.html public/safe/jp/ai-mae/index.html; do echo "### $f"; nl -ba "$f"; done' in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
     1	# SafeFile JP 랜딩 3페이지 문안 v1 (2026-10-22) — JA 본문 + EN 병기 + KR 요지
     2	
     3	> 공통 규칙: 사건명(タイムズカー) 불사용 · 「絶対/防ぐ/唯一」 불사용 · 모든 페이지에 「提出先の指示を必ず確認」 · 처리 화면에 광고 없음 · 법적 효과는 「制限される場合があります」 수준
     4	> URL 제안: /safe/jp/nyusatsu/ · /safe/jp/honnin-kakunin/ · /safe/jp/ai-mae/  (safefile.net 확보 시 301)
     5	
     6	---
     7	
     8	## 페이지 1 — 入札添付の資格確認書マスキング (사업자용, 매출 축)
     9	
    10	**title**: 入札添付の資格確認書・保険証コピー、番号だけ自動で黒塗り | SafeFile
    11	**meta description**: 公共工事の入札で求められる被保険者記号・番号・保険者番号のマスキングを、ブラウザだけで自動処理。複数PDFを一括、ファイルはサーバーに送信しません。再提出をなくします。
    12	**KR 요지**: 입찰 첨부 보험증 사본의 번호 마스킹을 브라우저에서 자동·일괄 처리. 서버 미전송. 반려 방지.
    13	
    14	### H1
    15	入札添付の資格確認書、番号だけを自動で黒塗り。再提出をなくす。
    16	
    17	### リード
    18	公共工事の入札では、健康保険の資格確認書や被保険者証の写しに「被保険者等記号・番号」「保険者番号」のマスキングが求められます（告知要求制限）。SafeFile は書類の種類を判定し、提出先ルールどおりの箇所だけを黒塗りします。氏名・生年月日・事業所名など、審査に必要な項目はそのまま残ります。
    19	
    20	[今すぐ試す（無料・登録不要）]  [チームプランの資料を見る]
    21	
    22	### なぜ手作業だと再提出になるのか（3点）
    23	- 付箋や修正テープで隠した写しは、スキャン時に番号が透けることがある
    24	- 画像編集アプリの黒塗りは「上に重ねただけ」で、PDF上で元の文字が残る場合がある
    25	- 枝番や二次元コードを見落とすと、発注者側で差し戻しになる
    26	
    27	### SafeFile が行うこと
    28	| 書類 | 自動で黒塗り | 残す |
    29	| --- | --- | --- |
    30	| 資格確認書（被用者保険・国保・後期高齢） | 保険者番号・記号・番号・枝番・二次元コード | 氏名・生年月日・住所・有効期限・事業所名称 |
    31	| 標準報酬決定通知書 | 被保険者整理番号 | 氏名・事業所名・対象月 |
    32	| 住民票の写し | 個人番号・住民票コード（提出先が求めない場合） | 氏名・住所・発行者 |
    33	
    34	※ 提出先の指示が優先です。指示と異なる場合は「残す項目」を個別に切り替えられます。
    35	
    36	### 仕組み（3ステップ）
    37	1. PDF・写真をドラッグ — 複数まとめて可
    38	2. 「提出目的：入札添付」を選ぶ — 書類ごとに黒塗り箇所が自動で決まる
    39	3. ダウンロード — 画像に平坦化され、黒塗りの下に原文は残りません。EXIF・注釈も削除
    40	
    41	### 安全性
    42	- ファイルはお使いのブラウザ内で処理され、サーバーには送信されません
    43	- 出力はラスター化（画像化）。テキスト層・メタデータは含まれません
    44	- 処理記録はブラウザ内のみ
    45	
    46	### チームプラン（事業者向け）
    47	月額 2,980円（税込）／年額 29,800円
    48	- 提出先別プリセット（自治体・発注者ごとに保存）
    49	- 複数PDFの一括処理・一括ダウンロード
    50	- 処理記録（いつ・どの書類・どの目的）をCSVで
    51	- SlimFile による容量圧縮を同時に（電子入札の容量制限対応）
    52	- メールサポート（日本語）
    53	
    54	**先行導入パイロット募集**：入札書類を月に複数件提出する建設業者・電子入札代行・行政書士の方、先着10社に3か月無料でご提供します。反映したい提出先ルールをお送りください。
    55	[パイロットに申し込む] → フォーム（会社名・業種・月間提出件数・よく使う発注者・連絡先）
    56	
    57	### よくある質問
    58	- **マスキングしていない写しを出したらどうなりますか** — 多くの発注者は受付後に発注者側でマスキングしますが、再提出や差し戻しを求める自治体もあります。提出前の処理が確実です。
    59	- **マイナ保険証しかありません** — 資格確認書または資格情報のお知らせの写しが対象です。マイナンバーカードの裏面は提出しないでください。
    60	- **法律上の根拠は** — 健康保険法等の改正による告知要求制限（2020年10月1日施行）。医療保険事務以外の目的で記号・番号の告知を求めることは原則制限されています。
    61	
    62	### EN (parallel)
    63	**H1**: Redact only the numbers on insurance certificates for public tender attachments — and stop resubmissions.
    64	**Lead**: Japanese public-works tenders require masking of the insured symbol/number and insurer number on health-insurance certificate copies. SafeFile detects the document type and blacks out exactly those fields, keeping name, date of birth and employer visible for review. Files never leave your browser.
    65	**Team plan**: ¥2,980/month — per-recipient presets, batch PDF processing, processing log CSV, SlimFile compression, Japanese email support. Pilot: first 10 companies, 3 months free.
    66	
    67	---
    68	
    69	## 페이지 2 — 本人確認書類は「必要な面だけ」 (개인용, 트래픽)
    70	
    71	**title**: 免許証・マイナンバーカードを送る前に — 必要な面だけ、不要な情報は黒塗り | SafeFile
    72	**meta description**: 本人確認で求められていない情報まで送っていませんか。裏面・臓器提供欄・本籍など、提出先が求めない箇所だけを自動で黒塗り。登録不要、サーバー送信なし。
    73	**KR 요지**: 본인확인 서류 최소화 원칙. 제출처가 요구하지 않는 면·항목만 가리기. 사건명 없음.
    74	
    75	### H1
    76	本人確認書類は「必要な面だけ」。求められていない情報は、送らない。
    77	
    78	### リード
    79	銀行・カード・通信・フリマの本人確認では、提出先が指定した面と項目だけで足ります。マイナンバーカードの裏面（個人番号）は身元確認には不要で、法令で認められた事務以外での複写・保管は制限される場合があります。SafeFile は書類を判定し、提出先が通常求めない箇所だけを黒塗りします。
    80	
    81	### 書類別の目安（提出先の指示が優先）
    82	| 書類 | 通常は送らない／黒塗り推奨 | 必ず残す |
    83	| --- | --- | --- |
    84	| マイナンバーカード | 裏面全体、表面の臓器提供欄 | 表面の氏名・住所・生年月日・有効期限・顔写真 |
    85	| 運転免許証 | 裏面の備考欄（旧住所など）、臓器提供欄 | 表面すべて |
    86	| 住民票の写し | 個人番号、本籍・筆頭者、本人以外の世帯員（求められない場合） | 氏名・住所・発行日・発行者 |
    87	| 資格確認書 | 保険者番号・記号・番号・枝番・二次元コード | 氏名・生年月日・住所 |
    88	
    89	### 「黒塗りしたつもり」が透ける理由
    90	スマホの編集アプリで塗った黒は、半透明だったり、PDFの文字層が残っていたりします。SafeFile の出力は画像に平坦化され、黒塗りの下に原文は残りません。
    91	
    92	### 使い方（30秒）
    93	1. 写真かPDFをドラッグ
    94	2. 「提出目的：本人確認提出」を選ぶ
    95	3. 残す項目を確認してダウンロード
    96	
    97	### これから変わること
    98	2026年以降、スマートフォンのマイナンバーカードやICチップ読み取り（JPKI）による本人確認が広がり、画像での提出は減っていきます。画像提出が残る場面では、最小限の情報だけを送る習慣が自分を守ります。
    99	
   100	### EN (parallel)
   101	**H1**: Send only the side they need. Nothing more.
   102	**Lead**: For KYC in Japan, the recipient's instructions decide what to submit. The back of the My Number card is not needed for identity checks and its copying may be restricted by law. SafeFile detects the document and blacks out only what recipients normally do not need, keeping everything they do.
   103	
   104	---
   105	
   106	## 페이지 3 — AIに貼り付ける前に黒塗り (신규 세그먼트, 패스 매출)
   107	
   108	**title**: ChatGPT・Claudeに契約書や給与明細を貼る前に、個人情報だけ黒塗り | SafeFile
   109	**meta description**: AIに相談するとき、相手の氏名・住所・口座・金額まで送っていませんか。相談に必要な文脈は残し、個人情報だけをブラウザ内で黒塗り。サーバー送信なし。
   110	**KR 요지**: AI 상담 전 익명화. 상대방 정보·금액·계좌만 가리고 문맥은 유지.
   111	
   112	### H1
   113	AIに相談する前に、個人情報だけ黒塗り。文脈はそのまま。
   114	
   115	### リード
   116	賃貸借契約書、給与明細、請求書、診断書をAIに貼り付けて相談する人が増えています。便利ですが、貼り付けた文面には相手方の氏名・住所・口座番号・金額が含まれ、多くのAIサービスはその内容を保存します。SafeFile は「相談用共有」モードで、相談に不要な個人情報だけを黒塗りし、条文や数字の構造は残します。
   117	
   118	### 相談用共有モードで黒塗りされるもの
   119	- 相手方（貸主・保証人・取引先）の氏名・住所・電話
   120	- 口座番号・残高・社員番号
   121	- 印影・署名
   122	- 自分の住所の番地以下（選択）
   123	
   124	残るもの：契約条項、金額の相対関係、日付、見出し — AIが答えるのに必要な部分
   125	
   126	### 使い方
   127	1. PDF・写真をドラッグ
   128	2. 「提出目的：相談用共有」を選ぶ
   129	3. ダウンロードした画像をAIに貼り付け
   130	
   131	### 30日パス 980円
   132	制限なしで30日間。契約書を何通も見直す月だけ。サブスクではありません。
   133	[無料で1枚試す]  [30日パスを買う]
   134	
   135	### EN (parallel)
   136	**H1**: Redact the personal data before you paste it into an AI. Keep the context.
   137	**Lead**: People paste leases, payslips and invoices into ChatGPT or Claude for advice. Those pages carry the other party's name, address, bank account and amounts, and most AI services store what you paste. SafeFile's "share for advice" mode blacks out only the personal data and keeps the clauses and figures the AI needs.
   138	**30-day pass ¥980** — unlimited for 30 days, no subscription.
   139	
   140	---
   141	
   142	## 파일럿 접촉 메일 (JA + EN + KR)
   143	
   144	**件名**: 入札添付書類のマスキング、先着10社に3か月無料でご提供します（SafeFile）
   145	
   146	○○株式会社 ご担当者様
   147	
   148	突然のご連絡失礼いたします。Tasicop の Justin と申します。公共工事の入札で添付する資格確認書・被保険者証の写しについて、被保険者記号・番号・保険者番号の黒塗りをブラウザ内で自動処理するツール「SafeFile」を運営しています。
   149	
   150	- 書類の種類を判定し、告知要求制限の対象箇所だけを黒塗り（氏名・事業所名は残ります）
   151	- 複数PDFを一括処理、ファイルはサーバーに送信しません
   152	- 出力は画像に平坦化され、黒塗りの下に原文が残りません
   153	
   154	現在、入札書類を月に複数件提出されている事業者様を対象に、先着10社へチームプラン（通常月額2,980円）を3か月無料でご提供しています。お返事として「よく提出される発注者名」を1つお知らせいただければ、その発注者の指示に合わせたプリセットを用意してお送りします。
   155	
   156	5分で試せます：https://slimfile.net/safe/jp/nyusatsu/
   157	
   158	ご多忙のところ恐れ入りますが、ご検討いただければ幸いです。
   159	
   160	Tasicop / Justin（成勲）
   161	chaop2@gmail.com
   162	
   163	**EN**: Subject: 3 months free for the first 10 companies — automatic redaction of tender attachment documents (SafeFile)
   164	Dear Sir/Madam, I am Justin at Tasicop. SafeFile automatically redacts the insured symbol/number and insurer number on health-insurance certificate copies attached to public-works tenders, entirely in the browser. It detects the document type, blacks out only the fields subject to the disclosure restriction, processes multiple PDFs at once, and never uploads your files. Output is flattened to an image, so no original text remains under the black bars. We are offering the Team plan (normally ¥2,980/month) free for 3 months to the first 10 companies that submit tender documents monthly. Reply with the name of one contracting authority you submit to most, and we will prepare a preset matching its instructions. Try it in 5 minutes: https://slimfile.net/safe/jp/nyusatsu/ — Justin, Tasicop
   165	
   166	**KR 요지**: 입찰 첨부 서류 자동 마스킹 툴 소개, 선착 10사 3개월 무료, 자주 내는 발주처 1곳만 회신하면 프리셋 제작.
### public/safe/jp/nyusatsu/index.html
     1	<!DOCTYPE html>
     2	<html lang="ja" data-from="nyusatsu">
     3	<head>
     4	<meta charset="UTF-8">
     5	<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
     6	<meta name="theme-color" content="#F7F5EF">
     7	<title>入札添付の資格確認書・保険証コピー、番号だけ自動で黒塗り | SafeFile</title>
     8	<meta name="description" content="公共工事の入札で求められる被保険者記号・番号・保険者番号のマスキングを、ブラウザだけで自動処理。複数PDFを一括、ファイルはサーバーに送信しません。再提出をなくします。">
     9	<meta name="robots" content="index,follow">
    10	<!-- Canonical / hreflang.
    11	     Self-referencing canonical with the trailing slash, because the slash-less
    12	     spelling and /index.html both 301 here (lib/canonical_path_redirect.rb) and
    13	     a page that does not name its own address is how /safe/ got filed as a
    14	     "duplicate without user-selected canonical" in Search Console.
    15	
    16	     NO hreflang at all — on purpose, and for the same reason /about carries
    17	     none. This is a single Japanese document; the English block at the bottom
    18	     is a summary inside this same URL, not a translation living at another one.
    19	     Declaring an `en` alternate would point at a URL that does not exist, and
    20	     an x-default self-reference would claim the page targets no particular
    21	     language, which is false. /safe/ is the opposite case (one URL, four full
    22	     UI languages switched client-side) and that is why it does carry x-default. -->
    23	<link rel="canonical" href="https://slimfile.net/safe/jp/nyusatsu/">
    24	<meta property="og:type" content="website">
    25	<meta property="og:site_name" content="SafeFile">
    26	<meta property="og:url" content="https://slimfile.net/safe/jp/nyusatsu/">
    27	<meta property="og:title" content="入札添付の資格確認書・保険証コピー、番号だけ自動で黒塗り | SafeFile">
    28	<meta property="og:description" content="公共工事の入札で求められる被保険者記号・番号・保険者番号のマスキングを、ブラウザだけで自動処理。複数PDFを一括、ファイルはサーバーに送信しません。再提出をなくします。">
    29	<meta property="og:image" content="https://slimfile.net/safe/icon-512.png">
    30	<meta property="og:locale" content="ja_JP">
    31	<meta name="twitter:card" content="summary">
    32	<meta name="twitter:title" content="入札添付の資格確認書・保険証コピー、番号だけ自動で黒塗り | SafeFile">
    33	<meta name="twitter:description" content="公共工事の入札で求められる被保険者記号・番号・保険者番号のマスキングを、ブラウザだけで自動処理。複数PDFを一括、ファイルはサーバーに送信しません。再提出をなくします。">
    34	<meta name="twitter:image" content="https://slimfile.net/safe/icon-512.png">
    35	<link rel="icon" type="image/svg+xml" href="/safe/icon.svg">
    36	<link rel="apple-touch-icon" href="/safe/apple-touch-icon.png">
    37	<link rel="preconnect" href="https://fonts.googleapis.com">
    38	<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+KR:wght@400;500;700&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">
    39	<link rel="stylesheet" href="/safe/jp/jp.css">
    40	<script type="application/ld+json">
    41	{
    42	  "@context": "https://schema.org",
    43	  "@type": "SoftwareApplication",
    44	  "name": "SafeFile",
    45	  "applicationCategory": "BusinessApplication",
    46	  "operatingSystem": "Web",
    47	  "url": "https://slimfile.net/safe/jp/nyusatsu/",
    48	  "description": "公共工事の入札で求められる被保険者記号・番号・保険者番号のマスキングを、ブラウザだけで自動処理します。",
    49	  "inLanguage": "ja",
    50	  "offers": [
    51	    { "@type": "Offer", "name": "無料", "price": "0", "priceCurrency": "JPY" },
    52	    { "@type": "Offer", "name": "チームプラン", "price": "2980", "priceCurrency": "JPY" }
    53	  ]
    54	}
    55	</script>
    56	<script type="application/ld+json">
    57	{
    58	  "@context": "https://schema.org",
    59	  "@type": "FAQPage",
    60	  "inLanguage": "ja",
    61	  "mainEntity": [
    62	    {
    63	      "@type": "Question",
    64	      "name": "マスキングしていない写しを出したらどうなりますか",
    65	      "acceptedAnswer": { "@type": "Answer", "text": "多くの発注者は受付後に発注者側でマスキングしますが、再提出や差し戻しを求める自治体もあります。提出前の処理が確実です。" }
    66	    },
    67	    {
    68	      "@type": "Question",
    69	      "name": "マイナ保険証しかありません",
    70	      "acceptedAnswer": { "@type": "Answer", "text": "資格確認書または資格情報のお知らせの写しが対象です。マイナンバーカードの裏面は提出しないでください。" }
    71	    },
    72	    {
    73	      "@type": "Question",
    74	      "name": "法律上の根拠は",
    75	      "acceptedAnswer": { "@type": "Answer", "text": "健康保険法等の改正による告知要求制限（2020年10月1日施行）。医療保険事務以外の目的で記号・番号の告知を求めることは原則制限されています。" }
    76	    }
    77	  ]
    78	}
    79	</script>
    80	</head>
    81	<body>
    82	
    83	<header>
    84	  <div class="nav">
    85	    <div class="logo">
    86	      <a class="logo-brand" href="/safe/"><span class="bar" aria-hidden="true"></span>SafeFile</a>
    87	      <span class="brand-sep" aria-hidden="true"></span>
    88	      <a class="logo-slim" href="https://slimfile.net">SlimFile</a>
    89	    </div>
    90	    <div class="links">
    91	      <span class="badge-free">無料 · 登録不要</span>
    92	      <a href="/safe/">ツールを開く</a>
    93	    </div>
    94	  </div>
    95	</header>
    96	
    97	<main class="wrap">
    98	
    99	  <section class="hero">
   100	    <h1>入札添付の資格確認書、番号だけを自動で黒塗り。再提出をなくす。</h1>
   101	    <p class="lead">公共工事の入札では、健康保険の資格確認書や被保険者証の写しに「被保険者等記号・番号」「保険者番号」のマスキングが求められます（告知要求制限）。SafeFile は書類の種類を判定し、提出先ルールどおりの箇所だけを黒塗りします。氏名・生年月日・事業所名など、審査に必要な項目はそのまま残ります。</p>
   102	    <div class="cta-row">
   103	      <a class="btn" data-cta data-purpose="bid_attachment" href="/safe/?lang=ja&amp;purpose=bid_attachment&amp;from=nyusatsu">今すぐ試す（無料・登録不要）</a>
   104	      <a class="btn ghost" href="#team">チームプランの資料を見る</a>
   105	    </div>
   106	  </section>
   107	
   108	  <section class="blk">
   109	    <h2>なぜ手作業だと再提出になるのか（3点）</h2>
   110	    <ul class="plain">
   111	      <li>付箋や修正テープで隠した写しは、スキャン時に番号が透けることがある</li>
   112	      <li>画像編集アプリの黒塗りは「上に重ねただけ」で、PDF上で元の文字が残る場合がある</li>
   113	      <li>枝番や二次元コードを見落とすと、発注者側で差し戻しになる</li>
   114	    </ul>
   115	  </section>
   116	
   117	  <section class="blk">
   118	    <h2>SafeFile が行うこと</h2>
   119	    <div class="tbl">
   120	      <table>
   121	        <thead>
   122	          <tr><th>書類</th><th>自動で黒塗り</th><th>残す</th></tr>
   123	        </thead>
   124	        <tbody>
   125	          <tr>
   126	            <td>資格確認書（被用者保険・国保・後期高齢）</td>
   127	            <td>保険者番号・記号・番号・枝番・二次元コード</td>
   128	            <td>氏名・生年月日・住所・有効期限・事業所名称</td>
   129	          </tr>
   130	          <tr>
   131	            <td>標準報酬決定通知書</td>
   132	            <td>被保険者整理番号</td>
   133	            <td>氏名・事業所名・対象月</td>
   134	          </tr>
   135	          <tr>
   136	            <td>住民票の写し</td>
   137	            <td>個人番号・住民票コード（提出先が求めない場合）</td>
   138	            <td>氏名・住所・発行者</td>
   139	          </tr>
   140	        </tbody>
   141	      </table>
   142	    </div>
   143	    <p class="note">※ 提出先の指示が優先です。指示と異なる場合は「残す項目」を個別に切り替えられます。</p>
   144	  </section>
   145	
   146	  <section class="blk">
   147	    <h2>仕組み（3ステップ）</h2>
   148	    <ol class="plain">
   149	      <li>PDF・写真をドラッグ — 複数まとめて可</li>
   150	      <li>「提出目的：入札添付」を選ぶ — 書類ごとに黒塗り箇所が自動で決まる</li>
   151	      <li>ダウンロード — 画像に平坦化され、黒塗りの下に原文は残りません。EXIF・注釈も削除</li>
   152	    </ol>
   153	  </section>
   154	
   155	  <section class="blk">
   156	    <h2>安全性</h2>
   157	    <ul class="plain">
   158	      <li>ファイルはお使いのブラウザ内で処理され、サーバーには送信されません</li>
   159	      <li>出力はラスター化（画像化）。テキスト層・メタデータは含まれません</li>
   160	      <li>処理記録はブラウザ内のみ</li>
   161	    </ul>
   162	  </section>
   163	
   164	  <section class="blk" id="team">
   165	    <h2>チームプラン（事業者向け）</h2>
   166	    <div class="card">
   167	      <p class="price">月額 2,980円（税込）／年額 29,800円</p>
   168	      <ul class="plain">
   169	        <li>提出先別プリセット（自治体・発注者ごとに保存）</li>
   170	        <li>複数PDFの一括処理・一括ダウンロード</li>
   171	        <li>処理記録（いつ・どの書類・どの目的）をCSVで</li>
   172	        <li>SlimFile による容量圧縮を同時に（電子入札の容量制限対応）</li>
   173	        <li>メールサポート（日本語）</li>
   174	      </ul>
   175	    </div>
   176	
   177	    <div class="pilot" id="pilot">
   178	      <p><strong>先行導入パイロット募集</strong>：入札書類を月に複数件提出する建設業者・電子入札代行・行政書士の方、先着10社に3か月無料でご提供します。反映したい提出先ルールをお送りください。</p>
   179	
   180	      <form class="pf" id="pilotForm" novalidate>
   181	        <div>
   182	          <label class="req" for="pf-company">会社名</label>
   183	          <input type="text" id="pf-company" name="company" maxlength="120" autocomplete="organization" required>
   184	        </div>
   185	        <div>
   186	          <label class="req" for="pf-industry">業種</label>
   187	          <select id="pf-industry" name="industry" required>
   188	            <option value="construction">建設業</option>
   189	            <option value="ebid_agent">電子入札代行</option>
   190	            <option value="gyoseishoshi">行政書士</option>
   191	            <option value="other">その他</option>
   192	          </select>
   193	        </div>
   194	        <div>
   195	          <label class="req" for="pf-count">月間提出件数</label>
   196	          <select id="pf-count" name="monthly_count" required>
   197	            <option value="1-2">月1〜2件</option>
   198	            <option value="3-5">月3〜5件</option>
   199	            <option value="6-10">月6〜10件</option>
   200	            <option value="11+">月11件以上</option>
   201	          </select>
   202	        </div>
   203	        <div>
   204	          <label for="pf-authority">よく使う発注者</label>
   205	          <input type="text" id="pf-authority" name="authority" maxlength="200" placeholder="例：○○県 ○○市">
   206	        </div>
   207	        <div>
   208	          <label class="req" for="pf-email">連絡先メール</label>
   209	          <input type="email" id="pf-email" name="email" maxlength="200" autocomplete="email" required>
   210	        </div>
   211	        <div class="hp" aria-hidden="true">
   212	          <label for="pf-website">Website</label>
   213	          <input type="text" id="pf-website" name="website" tabindex="-1" autocomplete="off">
   214	        </div>
   215	        <p class="consent">ご連絡のためにのみ使用します。</p>
   216	        <div><button class="btn" type="submit" id="pilotSubmit">パイロットに申し込む</button></div>
   217	        <div class="pf-msg" id="pilotMsg" role="status" aria-live="polite"></div>
   218	      </form>
   219	    </div>
   220	  </section>
   221	
   222	  <section class="blk">
   223	    <h2>よくある質問</h2>
   224	    <dl class="faq">
   225	      <dt>マスキングしていない写しを出したらどうなりますか</dt>
   226	      <dd>多くの発注者は受付後に発注者側でマスキングしますが、再提出や差し戻しを求める自治体もあります。提出前の処理が確実です。</dd>
   227	      <dt>マイナ保険証しかありません</dt>
   228	      <dd>資格確認書または資格情報のお知らせの写しが対象です。マイナンバーカードの裏面は提出しないでください。</dd>
   229	      <dt>法律上の根拠は</dt>
   230	      <dd>健康保険法等の改正による告知要求制限（2020年10月1日施行）。医療保険事務以外の目的で記号・番号の告知を求めることは原則制限されています。</dd>
   231	    </dl>
   232	    <p class="note">提出先の指示を必ず確認してください。</p>
   233	  </section>
   234	
   235	  <details class="en">
   236	    <summary>English</summary>
   237	    <div class="en-body">
   238	      <p><strong>Redact only the numbers on insurance certificates for public tender attachments — and stop resubmissions.</strong></p>
   239	      <p>Japanese public-works tenders require masking of the insured symbol/number and insurer number on health-insurance certificate copies. SafeFile detects the document type and blacks out exactly those fields, keeping name, date of birth and employer visible for review. Files never leave your browser.</p>
   240	      <p><strong>Team plan</strong>: ¥2,980/month — per-recipient presets, batch PDF processing, processing log CSV, SlimFile compression, Japanese email support. Pilot: first 10 companies, 3 months free.</p>
   241	    </div>
   242	  </details>
   243	
   244	  <footer>
   245	    <div class="fl">
   246	      <a href="/safe/">SafeFile</a>
   247	      <a href="/safe/jp/honnin-kakunin/">本人確認書類</a>
   248	      <a href="/safe/jp/ai-mae/">AIに貼る前に</a>
   249	      <a href="https://slimfile.net/privacy/">プライバシー</a>
   250	    </div>
   251	    <p>SafeFile · SlimFile — ファイルはブラウザ内で処理され、サーバーには送信されません。</p>
   252	  </footer>
   253	
   254	</main>
   255	
   256	<script src="/safe/jp/jp.js" defer></script>
   257	</body>
   258	</html>
### public/safe/jp/honnin-kakunin/index.html
     1	<!DOCTYPE html>
     2	<html lang="ja" data-from="honnin">
     3	<head>
     4	<meta charset="UTF-8">
     5	<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
     6	<meta name="theme-color" content="#F7F5EF">
     7	<title>免許証・マイナンバーカードを送る前に — 必要な面だけ、不要な情報は黒塗り | SafeFile</title>
     8	<meta name="description" content="本人確認で求められていない情報まで送っていませんか。裏面・臓器提供欄・本籍など、提出先が求めない箇所だけを自動で黒塗り。登録不要、サーバー送信なし。">
     9	<meta name="robots" content="index,follow">
    10	<!-- Self-referencing canonical with the trailing slash; no hreflang.
    11	     See the long note in /safe/jp/nyusatsu/index.html — single Japanese
    12	     document, English block inside this same URL, so there is no alternate
    13	     URL to point at and x-default would be a false claim. -->
    14	<link rel="canonical" href="https://slimfile.net/safe/jp/honnin-kakunin/">
    15	<meta property="og:type" content="website">
    16	<meta property="og:site_name" content="SafeFile">
    17	<meta property="og:url" content="https://slimfile.net/safe/jp/honnin-kakunin/">
    18	<meta property="og:title" content="免許証・マイナンバーカードを送る前に — 必要な面だけ、不要な情報は黒塗り | SafeFile">
    19	<meta property="og:description" content="本人確認で求められていない情報まで送っていませんか。裏面・臓器提供欄・本籍など、提出先が求めない箇所だけを自動で黒塗り。登録不要、サーバー送信なし。">
    20	<meta property="og:image" content="https://slimfile.net/safe/icon-512.png">
    21	<meta property="og:locale" content="ja_JP">
    22	<meta name="twitter:card" content="summary">
    23	<meta name="twitter:title" content="免許証・マイナンバーカードを送る前に — 必要な面だけ、不要な情報は黒塗り | SafeFile">
    24	<meta name="twitter:description" content="本人確認で求められていない情報まで送っていませんか。裏面・臓器提供欄・本籍など、提出先が求めない箇所だけを自動で黒塗り。登録不要、サーバー送信なし。">
    25	<meta name="twitter:image" content="https://slimfile.net/safe/icon-512.png">
    26	<link rel="icon" type="image/svg+xml" href="/safe/icon.svg">
    27	<link rel="apple-touch-icon" href="/safe/apple-touch-icon.png">
    28	<link rel="preconnect" href="https://fonts.googleapis.com">
    29	<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+KR:wght@400;500;700&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">
    30	<link rel="stylesheet" href="/safe/jp/jp.css">
    31	<script type="application/ld+json">
    32	{
    33	  "@context": "https://schema.org",
    34	  "@type": "SoftwareApplication",
    35	  "name": "SafeFile",
    36	  "applicationCategory": "UtilitiesApplication",
    37	  "operatingSystem": "Web",
    38	  "url": "https://slimfile.net/safe/jp/honnin-kakunin/",
    39	  "description": "本人確認書類のうち、提出先が通常求めない面・項目だけをブラウザ内で黒塗りします。",
    40	  "inLanguage": "ja",
    41	  "offers": { "@type": "Offer", "name": "無料", "price": "0", "priceCurrency": "JPY" }
    42	}
    43	</script>
    44	</head>
    45	<body>
    46	
    47	<header>
    48	  <div class="nav">
    49	    <div class="logo">
    50	      <a class="logo-brand" href="/safe/"><span class="bar" aria-hidden="true"></span>SafeFile</a>
    51	      <span class="brand-sep" aria-hidden="true"></span>
    52	      <a class="logo-slim" href="https://slimfile.net">SlimFile</a>
    53	    </div>
    54	    <div class="links">
    55	      <span class="badge-free">無料 · 登録不要</span>
    56	      <a href="/safe/">ツールを開く</a>
    57	    </div>
    58	  </div>
    59	</header>
    60	
    61	<main class="wrap">
    62	
    63	  <section class="hero">
    64	    <h1>本人確認書類は「必要な面だけ」。求められていない情報は、送らない。</h1>
    65	    <p class="lead">銀行・カード・通信・フリマの本人確認では、提出先が指定した面と項目だけで足ります。マイナンバーカードの裏面（個人番号）は身元確認には不要で、法令で認められた事務以外での複写・保管は制限される場合があります。SafeFile は書類を判定し、提出先が通常求めない箇所だけを黒塗りします。</p>
    66	    <div class="cta-row">
    67	      <a class="btn" data-cta data-purpose="identity_submit" href="/safe/?lang=ja&amp;purpose=identity_submit&amp;from=honnin">今すぐ試す（無料・登録不要）</a>
    68	    </div>
    69	  </section>
    70	
    71	  <section class="blk">
    72	    <h2>書類別の目安（提出先の指示が優先）</h2>
    73	    <div class="tbl">
    74	      <table>
    75	        <thead>
    76	          <tr><th>書類</th><th>通常は送らない／黒塗り推奨</th><th>必ず残す</th></tr>
    77	        </thead>
    78	        <tbody>
    79	          <tr>
    80	            <td>マイナンバーカード</td>
    81	            <td>裏面全体、表面の臓器提供欄</td>
    82	            <td>表面の氏名・住所・生年月日・有効期限・顔写真</td>
    83	          </tr>
    84	          <tr>
    85	            <td>運転免許証</td>
    86	            <td>裏面の備考欄（旧住所など）、臓器提供欄</td>
    87	            <td>表面すべて</td>
    88	          </tr>
    89	          <tr>
    90	            <td>住民票の写し</td>
    91	            <td>個人番号、本籍・筆頭者、本人以外の世帯員（求められない場合）</td>
    92	            <td>氏名・住所・発行日・発行者</td>
    93	          </tr>
    94	          <tr>
    95	            <td>資格確認書</td>
    96	            <td>保険者番号・記号・番号・枝番・二次元コード</td>
    97	            <td>氏名・生年月日・住所</td>
    98	          </tr>
    99	        </tbody>
   100	      </table>
   101	    </div>
   102	  </section>
   103	
   104	  <section class="blk">
   105	    <h2>「黒塗りしたつもり」が透ける理由</h2>
   106	    <p>スマホの編集アプリで塗った黒は、半透明だったり、PDFの文字層が残っていたりします。SafeFile の出力は画像に平坦化され、黒塗りの下に原文は残りません。</p>
   107	  </section>
   108	
   109	  <section class="blk">
   110	    <h2>使い方（30秒）</h2>
   111	    <ol class="plain">
   112	      <li>写真かPDFをドラッグ</li>
   113	      <li>「提出目的：本人確認提出」を選ぶ</li>
   114	      <li>残す項目を確認してダウンロード</li>
   115	    </ol>
   116	    <p class="note">提出先の指示を必ず確認してください。</p>
   117	  </section>
   118	
   119	  <section class="blk">
   120	    <h2>これから変わること</h2>
   121	    <p>2026年以降、スマートフォンのマイナンバーカードやICチップ読み取り（JPKI）による本人確認が広がり、画像での提出は減っていきます。画像提出が残る場面では、最小限の情報だけを送る習慣が自分を守ります。</p>
   122	    <div class="cta-row">
   123	      <a class="btn" data-cta data-purpose="identity_submit" href="/safe/?lang=ja&amp;purpose=identity_submit&amp;from=honnin">今すぐ試す（無料・登録不要）</a>
   124	    </div>
   125	  </section>
   126	
   127	  <details class="en">
   128	    <summary>English</summary>
   129	    <div class="en-body">
   130	      <p><strong>Send only the side they need. Nothing more.</strong></p>
   131	      <p>For KYC in Japan, the recipient's instructions decide what to submit. The back of the My Number card is not needed for identity checks and its copying may be restricted by law. SafeFile detects the document and blacks out only what recipients normally do not need, keeping everything they do.</p>
   132	    </div>
   133	  </details>
   134	
   135	  <footer>
   136	    <div class="fl">
   137	      <a href="/safe/">SafeFile</a>
   138	      <a href="/safe/jp/nyusatsu/">入札添付</a>
   139	      <a href="/safe/jp/ai-mae/">AIに貼る前に</a>
   140	      <a href="https://slimfile.net/privacy/">プライバシー</a>
   141	    </div>
   142	    <p>SafeFile · SlimFile — ファイルはブラウザ内で処理され、サーバーには送信されません。</p>
   143	  </footer>
   144	
   145	</main>
   146	
   147	<script src="/safe/jp/jp.js" defer></script>
   148	</body>
   149	</html>
### public/safe/jp/ai-mae/index.html
     1	<!DOCTYPE html>
     2	<html lang="ja" data-from="aimae">
     3	<head>
     4	<meta charset="UTF-8">
     5	<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
     6	<meta name="theme-color" content="#F7F5EF">
     7	<title>ChatGPT・Claudeに契約書や給与明細を貼る前に、個人情報だけ黒塗り | SafeFile</title>
     8	<meta name="description" content="AIに相談するとき、相手の氏名・住所・口座・金額まで送っていませんか。相談に必要な文脈は残し、個人情報だけをブラウザ内で黒塗り。サーバー送信なし。">
     9	<meta name="robots" content="index,follow">
    10	<!-- Self-referencing canonical with the trailing slash; no hreflang.
    11	     See the long note in /safe/jp/nyusatsu/index.html — single Japanese
    12	     document, English block inside this same URL, so there is no alternate
    13	     URL to point at and x-default would be a false claim. -->
    14	<link rel="canonical" href="https://slimfile.net/safe/jp/ai-mae/">
    15	<meta property="og:type" content="website">
    16	<meta property="og:site_name" content="SafeFile">
    17	<meta property="og:url" content="https://slimfile.net/safe/jp/ai-mae/">
    18	<meta property="og:title" content="ChatGPT・Claudeに契約書や給与明細を貼る前に、個人情報だけ黒塗り | SafeFile">
    19	<meta property="og:description" content="AIに相談するとき、相手の氏名・住所・口座・金額まで送っていませんか。相談に必要な文脈は残し、個人情報だけをブラウザ内で黒塗り。サーバー送信なし。">
    20	<meta property="og:image" content="https://slimfile.net/safe/icon-512.png">
    21	<meta property="og:locale" content="ja_JP">
    22	<meta name="twitter:card" content="summary">
    23	<meta name="twitter:title" content="ChatGPT・Claudeに契約書や給与明細を貼る前に、個人情報だけ黒塗り | SafeFile">
    24	<meta name="twitter:description" content="AIに相談するとき、相手の氏名・住所・口座・金額まで送っていませんか。相談に必要な文脈は残し、個人情報だけをブラウザ内で黒塗り。サーバー送信なし。">
    25	<meta name="twitter:image" content="https://slimfile.net/safe/icon-512.png">
    26	<link rel="icon" type="image/svg+xml" href="/safe/icon.svg">
    27	<link rel="apple-touch-icon" href="/safe/apple-touch-icon.png">
    28	<link rel="preconnect" href="https://fonts.googleapis.com">
    29	<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+KR:wght@400;500;700&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">
    30	<link rel="stylesheet" href="/safe/jp/jp.css">
    31	<script type="application/ld+json">
    32	{
    33	  "@context": "https://schema.org",
    34	  "@type": "SoftwareApplication",
    35	  "name": "SafeFile",
    36	  "applicationCategory": "UtilitiesApplication",
    37	  "operatingSystem": "Web",
    38	  "url": "https://slimfile.net/safe/jp/ai-mae/",
    39	  "description": "AIに相談する前に、相談に不要な個人情報だけをブラウザ内で黒塗りし、条文や数字の構造は残します。",
    40	  "inLanguage": "ja",
    41	  "offers": [
    42	    { "@type": "Offer", "name": "無料で1枚", "price": "0", "priceCurrency": "JPY" },
    43	    { "@type": "Offer", "name": "30日パス", "price": "980", "priceCurrency": "JPY" }
    44	  ]
    45	}
    46	</script>
    47	</head>
    48	<body>
    49	
    50	<header>
    51	  <div class="nav">
    52	    <div class="logo">
    53	      <a class="logo-brand" href="/safe/"><span class="bar" aria-hidden="true"></span>SafeFile</a>
    54	      <span class="brand-sep" aria-hidden="true"></span>
    55	      <a class="logo-slim" href="https://slimfile.net">SlimFile</a>
    56	    </div>
    57	    <div class="links">
    58	      <span class="badge-free">無料 · 登録不要</span>
    59	      <a href="/safe/">ツールを開く</a>
    60	    </div>
    61	  </div>
    62	</header>
    63	
    64	<main class="wrap">
    65	
    66	  <section class="hero">
    67	    <h1>AIに相談する前に、個人情報だけ黒塗り。文脈はそのまま。</h1>
    68	    <p class="lead">賃貸借契約書、給与明細、請求書、診断書をAIに貼り付けて相談する人が増えています。便利ですが、貼り付けた文面には相手方の氏名・住所・口座番号・金額が含まれ、多くのAIサービスはその内容を保存します。SafeFile は「相談用共有」モードで、相談に不要な個人情報だけを黒塗りし、条文や数字の構造は残します。</p>
    69	    <div class="cta-row">
    70	      <a class="btn" data-cta data-purpose="consult_share" href="/safe/?lang=ja&amp;purpose=consult_share&amp;from=aimae">無料で1枚試す</a>
    71	      <a class="btn ghost" href="#pass">30日パスを買う</a>
    72	    </div>
    73	  </section>
    74	
    75	  <section class="blk">
    76	    <h2>相談用共有モードで黒塗りされるもの</h2>
    77	    <ul class="plain">
    78	      <li>相手方（貸主・保証人・取引先）の氏名・住所・電話</li>
    79	      <li>口座番号・残高・社員番号</li>
    80	      <li>印影・署名</li>
    81	      <li>自分の住所の番地以下（選択）</li>
    82	    </ul>
    83	    <p>残るもの：契約条項、金額の相対関係、日付、見出し — AIが答えるのに必要な部分</p>
    84	  </section>
    85	
    86	  <section class="blk">
    87	    <h2>使い方</h2>
    88	    <ol class="plain">
    89	      <li>PDF・写真をドラッグ</li>
    90	      <li>「提出目的：相談用共有」を選ぶ</li>
    91	      <li>ダウンロードした画像をAIに貼り付け</li>
    92	    </ol>
    93	    <p class="note">提出先の指示を必ず確認してください。</p>
    94	  </section>
    95	
    96	  <section class="blk" id="pass">
    97	    <h2>30日パス 980円</h2>
    98	    <div class="card">
    99	      <p>制限なしで30日間。契約書を何通も見直す月だけ。サブスクではありません。</p>
   100	      <div class="cta-row">
   101	        <a class="btn" data-cta data-purpose="consult_share" href="/safe/?lang=ja&amp;purpose=consult_share&amp;from=aimae">無料で1枚試す</a>
   102	        <a class="btn ghost" href="mailto:chaop2@gmail.com?subject=30%E6%97%A5%E3%83%91%E3%82%B9%E3%81%AE%E8%B3%BC%E5%85%A5%E3%81%AB%E3%81%A4%E3%81%84%E3%81%A6">30日パスを買う</a>
   103	      </div>
   104	      <p class="note">※ 決済は準備中です。ご希望の方はメールでお知らせください。順次ご案内します。</p>
   105	    </div>
   106	  </section>
   107	
   108	  <details class="en">
   109	    <summary>English</summary>
   110	    <div class="en-body">
   111	      <p><strong>Redact the personal data before you paste it into an AI. Keep the context.</strong></p>
   112	      <p>People paste leases, payslips and invoices into ChatGPT or Claude for advice. Those pages carry the other party's name, address, bank account and amounts, and most AI services store what you paste. SafeFile's "share for advice" mode blacks out only the personal data and keeps the clauses and figures the AI needs.</p>
   113	      <p><strong>30-day pass ¥980</strong> — unlimited for 30 days, no subscription.</p>
   114	    </div>
   115	  </details>
   116	
   117	  <footer>
   118	    <div class="fl">
   119	      <a href="/safe/">SafeFile</a>
   120	      <a href="/safe/jp/nyusatsu/">入札添付</a>
   121	      <a href="/safe/jp/honnin-kakunin/">本人確認書類</a>
   122	      <a href="https://slimfile.net/privacy/">プライバシー</a>
   123	    </div>
   124	    <p>SafeFile · SlimFile — ファイルはブラウザ内で処理され、サーバーには送信されません。</p>
   125	  </footer>
   126	
   127	</main>
   128	
   129	<script src="/safe/jp/jp.js" defer></script>
   130	</body>
   131	</html>

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "sed -n '80,245p' public/safe/jp/nyusatsu/index.html | nl -ba -v80; nl -ba test/safe/jp_landing_check.mjs | sed -n '1,380p'; rg -n \"タイムズカー|絶対|防ぐ|唯一|必ず安全|必ず|制限|断定|prevent|guarantee|only\" public/safe/jp/*.html public/safe/jp/*/index.html public/safe/jp/jp.js" in /Users/sunghoon/Projects/docpack
 exited 1 in 0ms:
    80	</head>
    81	<body>
    82	
    83	<header>
    84	  <div class="nav">
    85	    <div class="logo">
    86	      <a class="logo-brand" href="/safe/"><span class="bar" aria-hidden="true"></span>SafeFile</a>
    87	      <span class="brand-sep" aria-hidden="true"></span>
    88	      <a class="logo-slim" href="https://slimfile.net">SlimFile</a>
    89	    </div>
    90	    <div class="links">
    91	      <span class="badge-free">無料 · 登録不要</span>
    92	      <a href="/safe/">ツールを開く</a>
    93	    </div>
    94	  </div>
    95	</header>
    96	
    97	<main class="wrap">
    98	
    99	  <section class="hero">
   100	    <h1>入札添付の資格確認書、番号だけを自動で黒塗り。再提出をなくす。</h1>
   101	    <p class="lead">公共工事の入札では、健康保険の資格確認書や被保険者証の写しに「被保険者等記号・番号」「保険者番号」のマスキングが求められます（告知要求制限）。SafeFile は書類の種類を判定し、提出先ルールどおりの箇所だけを黒塗りします。氏名・生年月日・事業所名など、審査に必要な項目はそのまま残ります。</p>
   102	    <div class="cta-row">
   103	      <a class="btn" data-cta data-purpose="bid_attachment" href="/safe/?lang=ja&amp;purpose=bid_attachment&amp;from=nyusatsu">今すぐ試す（無料・登録不要）</a>
   104	      <a class="btn ghost" href="#team">チームプランの資料を見る</a>
   105	    </div>
   106	  </section>
   107	
   108	  <section class="blk">
   109	    <h2>なぜ手作業だと再提出になるのか（3点）</h2>
   110	    <ul class="plain">
   111	      <li>付箋や修正テープで隠した写しは、スキャン時に番号が透けることがある</li>
   112	      <li>画像編集アプリの黒塗りは「上に重ねただけ」で、PDF上で元の文字が残る場合がある</li>
   113	      <li>枝番や二次元コードを見落とすと、発注者側で差し戻しになる</li>
   114	    </ul>
   115	  </section>
   116	
   117	  <section class="blk">
   118	    <h2>SafeFile が行うこと</h2>
   119	    <div class="tbl">
   120	      <table>
   121	        <thead>
   122	          <tr><th>書類</th><th>自動で黒塗り</th><th>残す</th></tr>
   123	        </thead>
   124	        <tbody>
   125	          <tr>
   126	            <td>資格確認書（被用者保険・国保・後期高齢）</td>
   127	            <td>保険者番号・記号・番号・枝番・二次元コード</td>
   128	            <td>氏名・生年月日・住所・有効期限・事業所名称</td>
   129	          </tr>
   130	          <tr>
   131	            <td>標準報酬決定通知書</td>
   132	            <td>被保険者整理番号</td>
   133	            <td>氏名・事業所名・対象月</td>
   134	          </tr>
   135	          <tr>
   136	            <td>住民票の写し</td>
   137	            <td>個人番号・住民票コード（提出先が求めない場合）</td>
   138	            <td>氏名・住所・発行者</td>
   139	          </tr>
   140	        </tbody>
   141	      </table>
   142	    </div>
   143	    <p class="note">※ 提出先の指示が優先です。指示と異なる場合は「残す項目」を個別に切り替えられます。</p>
   144	  </section>
   145	
   146	  <section class="blk">
   147	    <h2>仕組み（3ステップ）</h2>
   148	    <ol class="plain">
   149	      <li>PDF・写真をドラッグ — 複数まとめて可</li>
   150	      <li>「提出目的：入札添付」を選ぶ — 書類ごとに黒塗り箇所が自動で決まる</li>
   151	      <li>ダウンロード — 画像に平坦化され、黒塗りの下に原文は残りません。EXIF・注釈も削除</li>
   152	    </ol>
   153	  </section>
   154	
   155	  <section class="blk">
   156	    <h2>安全性</h2>
   157	    <ul class="plain">
   158	      <li>ファイルはお使いのブラウザ内で処理され、サーバーには送信されません</li>
   159	      <li>出力はラスター化（画像化）。テキスト層・メタデータは含まれません</li>
   160	      <li>処理記録はブラウザ内のみ</li>
   161	    </ul>
   162	  </section>
   163	
   164	  <section class="blk" id="team">
   165	    <h2>チームプラン（事業者向け）</h2>
   166	    <div class="card">
   167	      <p class="price">月額 2,980円（税込）／年額 29,800円</p>
   168	      <ul class="plain">
   169	        <li>提出先別プリセット（自治体・発注者ごとに保存）</li>
   170	        <li>複数PDFの一括処理・一括ダウンロード</li>
   171	        <li>処理記録（いつ・どの書類・どの目的）をCSVで</li>
   172	        <li>SlimFile による容量圧縮を同時に（電子入札の容量制限対応）</li>
   173	        <li>メールサポート（日本語）</li>
   174	      </ul>
   175	    </div>
   176	
   177	    <div class="pilot" id="pilot">
   178	      <p><strong>先行導入パイロット募集</strong>：入札書類を月に複数件提出する建設業者・電子入札代行・行政書士の方、先着10社に3か月無料でご提供します。反映したい提出先ルールをお送りください。</p>
   179	
   180	      <form class="pf" id="pilotForm" novalidate>
   181	        <div>
   182	          <label class="req" for="pf-company">会社名</label>
   183	          <input type="text" id="pf-company" name="company" maxlength="120" autocomplete="organization" required>
   184	        </div>
   185	        <div>
   186	          <label class="req" for="pf-industry">業種</label>
   187	          <select id="pf-industry" name="industry" required>
   188	            <option value="construction">建設業</option>
   189	            <option value="ebid_agent">電子入札代行</option>
   190	            <option value="gyoseishoshi">行政書士</option>
   191	            <option value="other">その他</option>
   192	          </select>
   193	        </div>
   194	        <div>
   195	          <label class="req" for="pf-count">月間提出件数</label>
   196	          <select id="pf-count" name="monthly_count" required>
   197	            <option value="1-2">月1〜2件</option>
   198	            <option value="3-5">月3〜5件</option>
   199	            <option value="6-10">月6〜10件</option>
   200	            <option value="11+">月11件以上</option>
   201	          </select>
   202	        </div>
   203	        <div>
   204	          <label for="pf-authority">よく使う発注者</label>
   205	          <input type="text" id="pf-authority" name="authority" maxlength="200" placeholder="例：○○県 ○○市">
   206	        </div>
   207	        <div>
   208	          <label class="req" for="pf-email">連絡先メール</label>
   209	          <input type="email" id="pf-email" name="email" maxlength="200" autocomplete="email" required>
   210	        </div>
   211	        <div class="hp" aria-hidden="true">
   212	          <label for="pf-website">Website</label>
   213	          <input type="text" id="pf-website" name="website" tabindex="-1" autocomplete="off">
   214	        </div>
   215	        <p class="consent">ご連絡のためにのみ使用します。</p>
   216	        <div><button class="btn" type="submit" id="pilotSubmit">パイロットに申し込む</button></div>
   217	        <div class="pf-msg" id="pilotMsg" role="status" aria-live="polite"></div>
   218	      </form>
   219	    </div>
   220	  </section>
   221	
   222	  <section class="blk">
   223	    <h2>よくある質問</h2>
   224	    <dl class="faq">
   225	      <dt>マスキングしていない写しを出したらどうなりますか</dt>
   226	      <dd>多くの発注者は受付後に発注者側でマスキングしますが、再提出や差し戻しを求める自治体もあります。提出前の処理が確実です。</dd>
   227	      <dt>マイナ保険証しかありません</dt>
   228	      <dd>資格確認書または資格情報のお知らせの写しが対象です。マイナンバーカードの裏面は提出しないでください。</dd>
   229	      <dt>法律上の根拠は</dt>
   230	      <dd>健康保険法等の改正による告知要求制限（2020年10月1日施行）。医療保険事務以外の目的で記号・番号の告知を求めることは原則制限されています。</dd>
   231	    </dl>
   232	    <p class="note">提出先の指示を必ず確認してください。</p>
   233	  </section>
   234	
   235	  <details class="en">
   236	    <summary>English</summary>
   237	    <div class="en-body">
   238	      <p><strong>Redact only the numbers on insurance certificates for public tender attachments — and stop resubmissions.</strong></p>
   239	      <p>Japanese public-works tenders require masking of the insured symbol/number and insurer number on health-insurance certificate copies. SafeFile detects the document type and blacks out exactly those fields, keeping name, date of birth and employer visible for review. Files never leave your browser.</p>
   240	      <p><strong>Team plan</strong>: ¥2,980/month — per-recipient presets, batch PDF processing, processing log CSV, SlimFile compression, Japanese email support. Pilot: first 10 companies, 3 months free.</p>
   241	    </div>
   242	  </details>
   243	
   244	  <footer>
   245	    <div class="fl">
     1	#!/usr/bin/env node
     2	/*
     3	 * Live check for the SafeFile JP landing pages and the /safe/ entry parameters.
     4	 *
     5	 *   node test/safe/jp_landing_check.mjs [base]      # default http://localhost:3001
     6	 *
     7	 * Needs a RUNNING app (the pilot form and the counters are server endpoints, so
     8	 * the static server run.mjs uses cannot answer them). Checks, in order:
     9	 *
    10	 *   1. each landing page renders, carries its canonical copy, and its CTA link
    11	 *      agrees with the purpose its click counter reports
    12	 *   2. landing_view fires once per page load and cta_click fires on the CTA
    13	 *   3. /safe/?lang=ja&purpose=…&from=… preselects language and purpose, and the
    14	 *      preselect SURVIVES "another document" (resetAll)
    15	 *   4. the pilot form posts, shows the Japanese thank-you, and rejects a
    16	 *      honeypot submission indistinguishably
    17	 *   5. no third-party script is loaded by any of the three pages
    18	 *
    19	 * Exit 0 = all pass. Failures print the page and the expectation.
    20	 */
    21	import { chromium } from 'playwright';
    22	
    23	const BASE = process.argv[2] || 'http://localhost:3001';
    24	
    25	let pass = 0;
    26	const fails = [];
    27	function ok(label, cond, detail = '') {
    28	  if (cond) { pass++; return; }
    29	  fails.push(`${label}${detail ? ' — ' + detail : ''}`);
    30	  console.log(`  FAIL  ${label}${detail ? ' — ' + detail : ''}`);
    31	}
    32	
    33	// Copy that must appear verbatim. Pulled from
    34	// docs/jp/jp_landing_copy_2026-10-22.md — if a phrase here stops matching, the
    35	// landing page has drifted from the canonical copy, which is the one thing
    36	// S6 was told not to do.
    37	const PAGES = [
    38	  {
    39	    slug: 'nyusatsu',
    40	    from: 'nyusatsu',
    41	    purpose: 'bid_attachment',
    42	    title: '入札添付の資格確認書・保険証コピー、番号だけ自動で黒塗り | SafeFile',
    43	    h1: '入札添付の資格確認書、番号だけを自動で黒塗り。再提出をなくす。',
    44	    copy: [
    45	      '公共工事の入札では、健康保険の資格確認書や被保険者証の写しに「被保険者等記号・番号」「保険者番号」のマスキングが求められます（告知要求制限）。',
    46	      '付箋や修正テープで隠した写しは、スキャン時に番号が透けることがある',
    47	      '枝番や二次元コードを見落とすと、発注者側で差し戻しになる',
    48	      '※ 提出先の指示が優先です。指示と異なる場合は「残す項目」を個別に切り替えられます。',
    49	      '月額 2,980円（税込）／年額 29,800円',
    50	      '先行導入パイロット募集',
    51	      '健康保険法等の改正による告知要求制限（2020年10月1日施行）。'
    52	    ]
    53	  },
    54	  {
    55	    slug: 'honnin-kakunin',
    56	    from: 'honnin',
    57	    purpose: 'identity_submit',
    58	    title: '免許証・マイナンバーカードを送る前に — 必要な面だけ、不要な情報は黒塗り | SafeFile',
    59	    h1: '本人確認書類は「必要な面だけ」。求められていない情報は、送らない。',
    60	    copy: [
    61	      '銀行・カード・通信・フリマの本人確認では、提出先が指定した面と項目だけで足ります。',
    62	      '裏面全体、表面の臓器提供欄',
    63	      '裏面の備考欄（旧住所など）、臓器提供欄',
    64	      'スマホの編集アプリで塗った黒は、半透明だったり、PDFの文字層が残っていたりします。',
    65	      '2026年以降、スマートフォンのマイナンバーカードやICチップ読み取り（JPKI）による本人確認が広がり'
    66	    ]
    67	  },
    68	  {
    69	    slug: 'ai-mae',
    70	    from: 'aimae',
    71	    purpose: 'consult_share',
    72	    title: 'ChatGPT・Claudeに契約書や給与明細を貼る前に、個人情報だけ黒塗り | SafeFile',
    73	    h1: 'AIに相談する前に、個人情報だけ黒塗り。文脈はそのまま。',
    74	    copy: [
    75	      '賃貸借契約書、給与明細、請求書、診断書をAIに貼り付けて相談する人が増えています。',
    76	      '相手方（貸主・保証人・取引先）の氏名・住所・電話',
    77	      '残るもの：契約条項、金額の相対関係、日付、見出し — AIが答えるのに必要な部分',
    78	      '制限なしで30日間。契約書を何通も見直す月だけ。サブスクではありません。'
    79	    ]
    80	  }
    81	];
    82	
    83	// Phrases the copy rules forbid outright (docs/jp/jp_landing_copy §공통 규칙).
    84	const FORBIDDEN = ['タイムズカー', '絶対', '防ぎます', '唯一', '必ず安全'];
    85	
    86	const browser = await chromium.launch({ channel: 'chrome' });
    87	
    88	/* Records every counter the page sends, with its payload AND the status the
    89	 * server answered with.
    90	 *
    91	 * Playwright cannot read a sendBeacon payload: the body is a Blob and both
    92	 * postData() and postDataBuffer() come back null for it (measured — every
    93	 * landing_view read as `{}` while the rows were landing in the database
    94	 * correctly). So the payload is captured INSIDE the page by wrapping
    95	 * navigator.sendBeacon, and the wrapper still delegates to the real one so
    96	 * delivery is unchanged.
    97	 *
    98	 * The status matters as much as the payload: /api/safe_events answers 204 only
    99	 * when every key and value passed SafeEvent's whitelist, so a 204 is the
   100	 * server agreeing that nothing un-whitelisted was sent. Asserting the payload
   101	 * alone would only prove what the page MEANT to send.
   102	 */
   103	async function trackBeacons(page) {
   104	  const statuses = [];
   105	  page.on('response', (res) => {
   106	    if (new URL(res.url()).pathname === '/api/safe_events') statuses.push(res.status());
   107	  });
   108	
   109	  await page.addInitScript(() => {
   110	    window.__beacons = [];
   111	    const realBeacon = navigator.sendBeacon ? navigator.sendBeacon.bind(navigator) : null;
   112	    const record = (url, body) => {
   113	      if (String(url).indexOf('/api/safe_events') === -1) return;
   114	      // Blob.text() is async; keep the promise and resolve it from the harness.
   115	      window.__beacons.push(body && body.text ? body.text() : Promise.resolve(String(body)));
   116	    };
   117	    if (realBeacon) {
   118	      navigator.sendBeacon = (url, body) => { record(url, body); return realBeacon(url, body); };
   119	    }
   120	    const realFetch = window.fetch.bind(window);
   121	    window.fetch = (url, opts) => { if (opts && opts.body) record(url, opts.body); return realFetch(url, opts); };
   122	  });
   123	
   124	  return {
   125	    statuses,
   126	    async read() {
   127	      const raw = await page.evaluate(() => Promise.all(window.__beacons || []));
   128	      return raw.map((r) => { try { return JSON.parse(r); } catch { return { name: '<unparseable>' }; } });
   129	    }
   130	  };
   131	}
   132	
   133	function thirdParty(page) {
   134	  const hosts = new Set();
   135	  page.on('request', (req) => {
   136	    const h = new URL(req.url()).hostname;
   137	    if (h !== new URL(BASE).hostname) hosts.add(h);
   138	  });
   139	  return hosts;
   140	}
   141	
   142	/* ── 1 + 2 + 5. landing pages ───────────────────────────────────────────── */
   143	console.log('\n[1/4] landing pages — copy, CTA, counters, no third-party script');
   144	for (const p of PAGES) {
   145	  const page = await browser.newPage();
   146	  const beacons = await trackBeacons(page);
   147	  const hosts = thirdParty(page);
   148	  const url = `${BASE}/safe/jp/${p.slug}/`;
   149	  const res = await page.goto(url, { waitUntil: 'networkidle' });
   150	
   151	  ok(`${p.slug}: 200`, res.status() === 200, `got ${res.status()}`);
   152	  ok(`${p.slug}: lang=ja`, await page.getAttribute('html', 'lang') === 'ja');
   153	  ok(`${p.slug}: title`, await page.title() === p.title, await page.title());
   154	
   155	  const h1 = (await page.textContent('h1') || '').trim();
   156	  ok(`${p.slug}: h1 verbatim`, h1 === p.h1, h1);
   157	
   158	  const body = await page.textContent('body');
   159	  for (const phrase of p.copy) {
   160	    ok(`${p.slug}: copy "${phrase.slice(0, 22)}…"`, body.includes(phrase));
   161	  }
   162	  ok(`${p.slug}: carries 提出先の指示を必ず確認`, body.includes('提出先の指示を必ず確認'));
   163	  for (const bad of FORBIDDEN) {
   164	    ok(`${p.slug}: no forbidden "${bad}"`, !body.includes(bad));
   165	  }
   166	
   167	  // The English parallel block lives inside this same URL, which is why the
   168	  // page declares no hreflang. Both halves of that have to hold.
   169	  ok(`${p.slug}: EN block present`, await page.locator('details.en').count() === 1);
   170	  ok(`${p.slug}: no hreflang`, await page.locator('link[rel=alternate][hreflang]').count() === 0);
   171	  const canon = await page.getAttribute('link[rel=canonical]', 'href');
   172	  ok(`${p.slug}: self canonical`, canon === `https://slimfile.net/safe/jp/${p.slug}/`, canon);
   173	
   174	  // CTA: the href's purpose and the counter's purpose must be the same value.
   175	  // They are written in two places (HTML attribute and query string) and a
   176	  // mismatch would silently misattribute every conversion.
   177	  const cta = page.locator('[data-cta]').first();
   178	  const href = await cta.getAttribute('href');
   179	  const dataPurpose = await cta.getAttribute('data-purpose');
   180	  const q = new URLSearchParams(href.split('?')[1] || '');
   181	  ok(`${p.slug}: CTA purpose agrees`, q.get('purpose') === p.purpose && dataPurpose === p.purpose,
   182	     `href=${q.get('purpose')} data=${dataPurpose} want=${p.purpose}`);
   183	  ok(`${p.slug}: CTA from`, q.get('from') === p.from, q.get('from'));
   184	  ok(`${p.slug}: CTA lang=ja`, q.get('lang') === 'ja');
   185	
   186	  const sent = await beacons.read();
   187	  const views = sent.filter((b) => b.name === 'landing_view');
   188	  ok(`${p.slug}: exactly one landing_view`, views.length === 1, `got ${views.length} of ${sent.length} beacons`);
   189	  ok(`${p.slug}: landing_view props are categories only`,
   190	     views.length === 1 && JSON.stringify(views[0].props) === JSON.stringify({ from: p.from, locale: 'ja' }),
   191	     JSON.stringify(views[0] && views[0].props));
   192	  // 204 = the server's own whitelist accepted it. A 422 here would mean the
   193	  // page is sending something SafeEvent refuses — silently, because sendBeacon
   194	  // never reads the response.
   195	  ok(`${p.slug}: server accepted every counter`,
   196	     beacons.statuses.length > 0 && beacons.statuses.every((s) => s === 204),
   197	     beacons.statuses.join(','));
   198	
   199	  // Click the CTA, but cancel the NAVIGATION only — the counter must still run.
   200	  // preventDefault in the capture phase stops the link from being followed
   201	  // without stopping jp.js's own bubble-phase listener. This matters because
   202	  // the payload is recorded in a page-scoped array: let the navigation happen
   203	  // and the array is rebuilt empty on the next document, which reads as "the
   204	  // counter never fired" — exactly the false negative this harness hit first.
   205	  await page.evaluate(() => {
   206	    document.querySelectorAll('[data-cta]').forEach((el) =>
   207	      el.addEventListener('click', (e) => e.preventDefault(), true));
   208	  });
   209	  await cta.click();
   210	  await page.waitForTimeout(400);
   211	  const clicks = (await beacons.read()).filter((b) => b.name === 'cta_click');
   212	  ok(`${p.slug}: cta_click fired`, clicks.length >= 1, `got ${clicks.length}`);
   213	  ok(`${p.slug}: cta_click carries the purpose`,
   214	     clicks.length >= 1 && clicks[0].props.purpose === p.purpose,
   215	     JSON.stringify(clicks[0] && clicks[0].props));
   216	
   217	  // Google Fonts is the one cross-origin host /safe/ already loads; an ad or
   218	  // analytics host appearing here would break the page's own privacy claim.
   219	  const unexpected = [...hosts].filter((h) => !['fonts.googleapis.com', 'fonts.gstatic.com'].includes(h));
   220	  ok(`${p.slug}: no third-party host beyond the font CDN`, unexpected.length === 0, unexpected.join(', '));
   221	
   222	  await page.close();
   223	}
   224	
   225	/* ── 3. /safe/ entry parameters ─────────────────────────────────────────── */
   226	console.log('\n[2/4] /safe/ entry parameters — lang + purpose preselect');
   227	{
   228	  const page = await browser.newPage();
   229	  // A stale remembered language must lose to an explicit ?lang=.
   230	  await page.goto(`${BASE}/safe/`);
   231	  await page.evaluate(() => localStorage.setItem('safefile_lang', 'ko'));
   232	  await page.goto(`${BASE}/safe/?lang=ja&purpose=bid_attachment&from=nyusatsu`, { waitUntil: 'load' });
   233	
   234	  ok('entry: ?lang=ja wins over remembered ko', await page.evaluate(() => LANG) === 'ja');
   235	  ok('entry: html lang follows', await page.getAttribute('html', 'lang') === 'ja');
   236	  ok('entry: purpose preselected', await page.evaluate(() => jpState.purpose) === 'bid_attachment');
   237	  ok('entry: from captured', await page.evaluate(() => SF_PARAMS.from) === 'nyusatsu');
   238	
   239	  // resetAll() rebuilds jpState from JP_STATE0. Without the parameter being
   240	  // read there, pressing "another document" would silently drop back to
   241	  // identity_submit — on the page a tender clerk presses most.
   242	  await page.evaluate(() => resetAll());
   243	  ok('entry: purpose survives resetAll', await page.evaluate(() => jpState.purpose) === 'bid_attachment');
   244	
   245	  // An unknown purpose must be ignored, not stored.
   246	  await page.goto(`${BASE}/safe/?purpose=../../etc&from=evil`, { waitUntil: 'load' });
   247	  ok('entry: unknown purpose ignored', await page.evaluate(() => jpState.purpose) === 'identity_submit');
   248	  ok('entry: unknown from becomes direct', await page.evaluate(() => SF_PARAMS.from) === 'direct');
   249	  await page.close();
   250	}
   251	
   252	/* ── 4. pilot form ──────────────────────────────────────────────────────── */
   253	console.log('\n[3/4] pilot form — validation, submit, honeypot, cap');
   254	{
   255	  const page = await browser.newPage();
   256	  await page.goto(`${BASE}/safe/jp/nyusatsu/`, { waitUntil: 'networkidle' });
   257	
   258	  // The honeypot must be unreachable for a human: off-screen, not focusable.
   259	  const hp = page.locator('input[name=website]');
   260	  ok('form: honeypot present', await hp.count() === 1);
   261	  ok('form: honeypot not focusable', await hp.getAttribute('tabindex') === '-1');
   262	  ok('form: honeypot off-screen', (await hp.boundingBox())?.x < 0);
   263	
   264	  // Api::JpPilotController::RATE_LIMIT is 3 per IP per 10 minutes, so the four
   265	  // submissions below are ordered to use that budget deliberately: the three
   266	  // behaviours first, then the cap itself. The harness therefore needs a
   267	  // limiter that has not already been spent — `docker compose restart web`
   268	  // clears it in development (memory_store).
   269	  const submit = async (fill) => {
   270	    await page.goto(`${BASE}/safe/jp/nyusatsu/`, { waitUntil: 'networkidle' });
   271	    await fill();
   272	    const [res] = await Promise.all([
   273	      page.waitForResponse((r) => r.url().includes('/api/jp_pilot')),
   274	      page.click('#pilotSubmit')
   275	    ]);
   276	    await page.waitForTimeout(250);
   277	    return { status: res.status(), msg: await page.textContent('#pilotMsg') };
   278	  };
   279	
   280	  const fillValid = async (email = 'pw@example.co.jp') => {
   281	    await page.fill('#pf-company', 'プレイライト建設');
   282	    await page.selectOption('#pf-industry', 'construction');
   283	    await page.selectOption('#pf-count', '3-5');
   284	    await page.fill('#pf-authority', '○○県');
   285	    await page.fill('#pf-email', email);
   286	  };
   287	
   288	  // 1/3 — validation failure. The page must show its OWN Japanese wording; the
   289	  // server returns field NAMES precisely so its locale can never land here.
   290	  const bad = await submit(async () => {
   291	    await page.fill('#pf-company', 'テスト');
   292	    await page.fill('#pf-email', 'not-an-email');
   293	  });
   294	  if (bad.status === 429) {
   295	    ok('form: limiter was not already spent', false,
   296	       'got 429 on the first submission — restart the app (docker compose restart web) and re-run');
   297	  } else {
   298	    ok('form: invalid submission rejected', bad.status === 422, String(bad.status));
   299	    ok('form: field-level JA error', bad.msg.includes('連絡先メール'), bad.msg);
   300	    ok('form: no server-locale leak',
   301	       !bad.msg.includes('Translation missing') && !/[가-힣]/.test(bad.msg), bad.msg);
   302	  }
   303	
   304	  // 2/3 — the real thing.
   305	  const good = await submit(() => fillValid());
   306	  ok('form: POST accepted', good.status === 201, String(good.status));
   307	  ok('form: Japanese thank-you shown', good.msg.includes('お申し込みをお受けしました'), good.msg);
   308	  ok('form: inputs locked after success', await page.isDisabled('#pilotSubmit'));
   309	
   310	  // 3/3 — honeypot. Must be INDISTINGUISHABLE from a success on the wire; the
   311	  // only difference is that no row is written, which the Rails controller test
   312	  // asserts (this harness has no database handle).
   313	  const spam = await submit(async () => {
   314	    await fillValid('spam@example.com');
   315	    await page.evaluate(() => { document.querySelector('input[name=website]').value = 'http://spam.example'; });
   316	  });
   317	  ok('form: honeypot answered like a success', spam.status === 201, String(spam.status));
   318	  ok('form: honeypot shows the same thank-you', spam.msg.includes('お申し込みをお受けしました'), spam.msg);
   319	
   320	  // 4th submission — over the per-IP cap.
   321	  const capped = await submit(() => fillValid('over@example.co.jp'));
   322	  ok('form: fourth submission is capped', capped.status === 429, String(capped.status));
   323	  ok('form: cap message is Japanese', capped.msg.includes('送信が集中しています'), capped.msg);
   324	
   325	  await page.close();
   326	}
   327	
   328	console.log('\n' + '='.repeat(60));
   329	if (fails.length) {
   330	  console.log(`${pass} pass / ${fails.length} FAIL`);
   331	  fails.forEach((f) => console.log('  - ' + f));
   332	  await browser.close();
   333	  process.exit(1);
   334	}
   335	console.log(`ALL ${pass} CHECKS PASSED`);
   336	await browser.close();
zsh:1: no matches found: public/safe/jp/*.html

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'rg -n "''^##? 6|原則|禁止|33|一括|1階|資格確認書|AI|匿名|4週|ep05|ep06|blocked" docs/jp/jp_safefile_strategy_v2_2026-10-21.md docs/jp/jp_market_decision_v2_2026-10-22.md docs/jp/s7_report.md content/jp/topics.json scripts/content/make_episode.mjs scripts/content/README.md; for f in content/jp/ep0{1,2,3}/post_ja.md content/jp/ep0{1,2,3}/post_en.md content/jp/ep0{1,2,3}/x_thread.md; do echo "### $f"; nl -ba "$f"; done' in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
scripts/content/README.md:56:| `絶対` · `唯一` · `必ず安全` · `防ぎます/防げます` 불사용 | 「原則 / リスクを下げる / 確認する」로 쓴다 |
scripts/content/README.md:57:| `一括処理` · `一括ダウンロード` 불사용 | **아직 출시되지 않았다.** 미구현 기능 홍보 금지 |
scripts/content/README.md:60:`topics.json` 에 `blocked_until` 이 있는 회차(ep32 = 일괄처리)는 **빌드 자체를 거부한다.**
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:14:| 1-4 | 資格確認書 필드가 보험자별 상이. 通院歴 삭제 | **수용** | 구 보험증/資格確認書 분리. 필드를 common / issuer_specific으로 |
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:19:| 2-4 | 구 健康保険証 2025-12-01 실효, 잠정 2026-07-31 종료 | **수용** | 資格確認書를 주 문서로, 구 보험증은 legacy fixture |
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:40:- 구 健康保険証: 2025-12-01 원칙 실효, 잠정 대응 2026-07-31 종료 → 현재 주 문서는 **資格確認書**(보험자별 양식 상이)
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:53:| **1** | 本人確認書類 제출(은행·카드·통신·프리마) | 資格確認書, 免許証, マイナカード 표면 | 告知要求制限, 수령기관 마스킹 안내 | 「資格確認書の番号、提出先が"隠して"と言う理由」 |
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:54:| **2** | 입찰·허가·건설업 첨부 | 資格確認書 사본, 標準報酬決定通知書 | 지자체 공식 마스킹 견본 PDF | 「入札添付、マスキング忘れで再提出にならないために」 |
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:74:| 保険者番号 / 記号・番号・枝番 | 레이블 근접(같은 행·인접 박스) 점수제 | 資格確認書 분류 + 레이블 일치 시 자동 |
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:79:| QR | 이미지 휴리스틱 | 資格確認書 분류 시 자동 |
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:85:| 資格確認書 | 本人確認 | 保険者番号, 記号, 番号, 枝番, QR | 性別(권고) |
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:91:「{提出先}提出用」「本人確認のみに使用」「転用禁止」+ 날짜. 문구는 "防止"가 아니라 "抑止" 수준으로 안내.
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:103:- 더미 범위: 알파 4종 × (PDF·JPG 촬영풍·PNG 스캔풍) + 변형(資格確認書 보험자 3종, 住民票 全員/一部·個人番号 유무·외국인) ≈ **20파일**
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:120:## 6. 콘텐츠 (3개월 30편 → 제목 재작성, 알파 4종 중심으로 순서 재배치)
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:123:- **핵심**: 검색 랜딩 3페이지(資格確認書 마스킹 / 免許証 제출 전 / マイナカード 裏面) — Google·Yahoo! JAPAN
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:129:- "絶対 / 防ぐ / べき" → "原則 / リスクを下げる / 確認する"
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:137:| 2 | A | 資格確認書の番号を隠して提出する手順【提出先の指定を確認】 | 資格確認書 |
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:143:| 8 | B | 入札添付の資格確認書、マスキング指示の読み方 | 資格確認書 |
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:152:| 17 | A | 賃貸借契約書を専門家に相談する前の匿名化 | 契約書 |
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:158:| 23 | A | 職務経歴書を匿名で共有するときの考え方 | 職務経歴書 |
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:163:| 28 | B | 家族の書類を代理で出すときの注意 | 資格確認書 |
docs/jp/jp_safefile_strategy_v2_2026-10-21.md:164:| 29 | A | (一括処理 出시 후) 複数書類をまとめて処理 | 全般 |
docs/jp/jp_market_decision_v2_2026-10-22.md:7:| 1~5 | 직접 경쟁 존재: Pixelate(2026-09 출시, 月¥600/年¥5,000/買切¥2,500·5,000), PDF Masker, プライバシーマスク(온디바이스 자동검출, Pro 구독), 무료 웹툴 Capsule Tools·みんなの電卓·エッジAIラボ | **수용** | "제품 공백"→"수익화 공백(매출 공개된 곳 없음)"으로 정정. 차별점을 **정확도·일본 서류 프리셋·제출 목적 게이트·PC/웹(설치 불요)·완전 로컬** 로 재정의 |
docs/jp/jp_market_decision_v2_2026-10-22.md:10:| 9 | 소비자 보안 구독 가격 앵커: Whoscall 月¥490/年¥4,600, 楽天 경유 ¥330, ノートン 年¥5,480 | 수용 | C 가격 재설정 |
docs/jp/jp_market_decision_v2_2026-10-22.md:17:| 17~18 | C는 月¥330~600 앵커, 저빈도라 유지율 문제. 30일 패스 ¥500~1,500 또는 買切 먼저. D(개인 구독 전용)는 Pixelate가 전례이나 성공 미확인 | 수용 | C: **30일 패스 ¥980** 가설, 반복 이용자에게만 구독 제시 |
docs/jp/jp_market_decision_v2_2026-10-22.md:19:| 20 | JPKI·스마트폰 マイナカード 확산으로 신분증 이미지 업로드 수요 일부 소멸 | **수용(중요)** | 신분증보다 **JPKI로 대체되지 않는 흐름**(입찰·보조금 정산·법원 제출·**AI 입력 전 익명화**) 우선 |
docs/jp/jp_market_decision_v2_2026-10-22.md:30:**2순위 = AI 입력 전 익명화** (신규, Codex 20번에서 도출)
docs/jp/jp_market_decision_v2_2026-10-22.md:39:- 차별점 3개: ① 資格確認書·住民票 등 서류별·제출목적별 프리셋 ② PC 브라우저에서 설치 없이(복합기 스캔 PDF 그대로) ③ 완전 로컬 + 평탄화로 복원 불가
docs/jp/jp_market_decision_v2_2026-10-22.md:43:1. **入札添付の資格確認書マスキング** — 사업자용. 입찰공고 원문 인용, 반려 사례, 일괄처리 데모, 파일럿 모집 폼
docs/jp/jp_market_decision_v2_2026-10-22.md:45:3. **AIに貼り付ける前に黒塗り** — 신규. 계약서·급여명세 익명화, consult_share 프리셋 데모
docs/jp/jp_market_decision_v2_2026-10-22.md:48:- 1·14·20번(타임즈카 1인칭·사건 중심) → "最小化原則" 교육형으로 재작성
scripts/content/make_episode.mjs:73:if (topic.blocked_until) {
scripts/content/make_episode.mjs:76:  console.error(`ep${EP} is blocked until: ${topic.blocked_until}`);
scripts/content/make_episode.mjs:144:  { re: /絶対/, why: '「絶対」 is forbidden; use 原則 / リスクを下げる' },
scripts/content/make_episode.mjs:148:  { re: /一括(処理|ダウンロード)/, why: 'batch processing has not shipped — do not advertise it' }
scripts/content/make_episode.mjs:380:    process.stdout.write(`  demo FAILED: ${e.message}\n`);
docs/jp/s7_report.md:11:## 1. 주제 정본 — 33편
docs/jp/s7_report.md:15:- **1·14·20번을 「最小化原則」 교육형으로 재작성.** 사건 중심·1인칭을 걷어내되 원칙은 남겼다.
docs/jp/s7_report.md:18:- **신규 3편**: ChatGPTに契約書を貼る前に(ep03) / 電子入札のPDF容量と黒塗りを一度に(ep05) /
docs/jp/s7_report.md:19:  補助金精算の添付書類、どこまで隠すか(ep06). 셋 다 새 코드 없이 SlimFile 압축이나 기존
docs/jp/s7_report.md:22:**`ep` = 발행 순서 = `week`** 이다(1~33, 주 1편). 전략 문서의 번호는 더 이상 순서가 아니므로
docs/jp/s7_report.md:27:| 1 | ep01 | A | 資格確認書の番号を隠して提出する手順 | nyusatsu |
docs/jp/s7_report.md:28:| 2 | ep02 | B | 入札添付の資格確認書、マスキング指示の読み方 | nyusatsu |
docs/jp/s7_report.md:30:| 4 | ep04 | A | 賃貸借契約書を専門家に相談する前の匿名化 | **aimae** |
docs/jp/s7_report.md:31:| 5 | ep05 | A | 電子入札のPDF容量と黒塗りを一度に片づける | nyusatsu |
docs/jp/s7_report.md:32:| 6 | ep06 | A | 補助金精算の添付書類、どこまで隠すか | nyusatsu |
docs/jp/s7_report.md:34:1층(사업자)·資格確認書 를 앞에, **AI 익명화 2편(ep03·ep04)을 4주 안에** — 둘 다 충족.
docs/jp/s7_report.md:37:**ep32(複数書類をまとめて処理)는 `blocked_until: "batch processing ships"` 로 표시했고
docs/jp/s7_report.md:46:content/jp/topics.json          계획 (33편)
docs/jp/s7_report.md:73:| `絶対` · `唯一` · `必ず安全` · `防ぎます/防げます` | 「原則 / リスクを下げる / 確認する」로 |
docs/jp/s7_report.md:74:| `一括処理` · `一括ダウンロード` | 미출시 기능 홍보 금지 |
docs/jp/s7_report.md:88:| `make_episode.mjs 1` (캐러셀 + OCR + 데모 GIF/MP4) | **33.0초** |
docs/jp/s7_report.md:90:데모의 대부분은 촬영풍 JPG 의 Tesseract OCR 이다. 33편 전부를 다시 만들어도
docs/jp/s7_report.md:91:트랙 A 11편 × 33초 + 나머지 × 6초 ≈ 8분 수준이다.
docs/jp/s7_report.md:99:| ep01 資格確認書の番号を隠して提出する手順 | 783자 | A | **ok — 40프레임, GIF 399KB / MP4 218KB** |
docs/jp/s7_report.md:100:| ep02 入札添付の資格確認書、マスキング指示の読み方 | 614자 | B | `skipped: track B has no tool demo` |
docs/jp/s7_report.md:147:## 6. 다음 편을 만들 때의 명령 1줄
docs/jp/s7_report.md:166:| `make_episode.mjs 32` (blocked 회차) | **exit 2** · 차단 사유와 이유를 출력 |
docs/jp/s7_report.md:189:- **ep04~ep33 본문 미작성.** 지시서 범위는 첫 3편이다. 주제·랜딩·purpose·주차는 전부
docs/jp/s7_report.md:195:- **ep05·ep06 의 「電子入札の容量制限」·「補助金精算」은 아직 근거가 약하다.** 전략 문서가
docs/jp/s7_report.md:198:- **생성물(PNG/GIF/MP4)을 git 에 커밋한다.** 3편에 약 1.5MB, 33편이면 30MB 전후가 된다.
content/jp/topics.json:3:    "SafeFile JP content plan — 33 episodes, one per week.",
content/jp/topics.json:8:    "    教育型 pieces about the 最小化原則 — the principle survives, the anecdote",
content/jp/topics.json:11:    "  * three new episodes added (ep03, ep05, ep06), all of which lean on",
content/jp/topics.json:19:    "  * tier-1 (business, 資格確認書 / 入札) first — ep01, ep02",
content/jp/topics.json:20:    "  * the two AI-anonymisation pieces inside the first four weeks — ep03, ep04",
content/jp/topics.json:21:    "  * the three new SlimFile-combined business pieces next — ep05, ep06 (ep03 is",
content/jp/topics.json:22:    "    AI, so the third new one is ep06)",
content/jp/topics.json:45:      "title_ja": "資格確認書の番号を隠して提出する手順【提出先の指示を確認】",
content/jp/topics.json:52:      "title_ja": "入札添付の資格確認書、マスキング指示の読み方",
content/jp/topics.json:66:      "title_ja": "賃貸借契約書を専門家に相談する前の匿名化",
content/jp/topics.json:143:      "title_ja": "本人確認書類は「最小化」が原則 — 求められた面と項目だけを出す",
content/jp/topics.json:199:      "title_ja": "職務経歴書を匿名で共有するときの考え方",
content/jp/topics.json:227:      "title_ja": "「そもそも出さない」という選択 — 最小化原則の実務",
content/jp/topics.json:266:      "blocked_until": "batch processing ships",
content/jp/topics.json:270:      "ep": 33, "week": 33, "track": "B", "src": 30,
### content/jp/ep01/post_ja.md
     1	---
     2	title: 資格確認書の番号を隠して提出する手順【提出先の指示を確認】
     3	hook: 入札書類が差し戻される理由の多くは、記号・番号の黒塗りが一箇所だけ残っていることです。
     4	bullets:
     5	  - 隠すのは保険者番号・記号・番号・枝番・二次元コード。氏名と事業所名は残します
     6	  - 画像編集アプリの黒塗りはPDFの文字層が残ることがあり、提出前に確認が必要です
     7	  - 出力を画像に平坦化すれば、黒塗りの下に原文は残りません
     8	cta: 資格確認書の黒塗りを、ブラウザだけで試す
     9	captions:
    10	  - "① 資格確認書の写真をドラッグする"
    11	  - "② 「提出目的：入札添付」を選ぶと、隠す箇所が自動で決まる"
    12	  - "③ ダウンロード — 画像に平坦化され、黒塗りの下に原文は残りません"
    13	---
    14	
    15	公共工事の入札で添付する健康保険の資格確認書や被保険者証の写しは、「被保険者等記号・番号」と「保険者番号」のマスキングを求められることが一般的です。根拠は健康保険法等の改正による告知要求制限（2020年10月1日施行）で、医療保険事務以外の目的で記号・番号の告知を求めることは原則として制限されています。
    16	
    17	差し戻しが起きるのは、たいてい手作業の取りこぼしです。付箋や修正テープで隠して撮影した写しは、スキャンの光量によって数字が透けることがあります。画像編集アプリで黒い四角を重ねただけのPDFは、画面では黒く見えても文字層が残っている場合があり、文字列として読み出せてしまいます。そして枝番と二次元コードは、紙の上では小さく目立たないため最後まで残りやすい箇所です。
    18	
    19	## 書類別に、隠すところと残すところ
    20	
    21	| 書類 | 隠す | 残す |
    22	| --- | --- | --- |
    23	| 資格確認書（被用者保険・国保・後期高齢） | 保険者番号・記号・番号・枝番・二次元コード | 氏名・生年月日・住所・有効期限・事業所名称 |
    24	| 標準報酬決定通知書 | 被保険者整理番号 | 氏名・事業所名・対象月 |
    25	| 住民票の写し | 個人番号・住民票コード（提出先が求めない場合） | 氏名・住所・発行者 |
    26	
    27	審査に使われるのは氏名・生年月日・事業所名称です。番号を隠すことと、審査に必要な項目まで消してしまうことは別の作業で、後者も差し戻しの原因になります。
    28	
    29	## 手順は3つ
    30	
    31	1. 資格確認書のPDFか写真をドラッグします。複数枚をまとめて読み込めます。
    32	2. 「提出目的：入札添付」を選びます。書類の種類が判定され、隠す箇所が自動で決まります。残す項目は個別に切り替えられます。
    33	3. ダウンロードします。出力は画像に平坦化されるため、黒塗りの下に原文は残りません。EXIFや注釈も取り除かれます。
    34	
    35	二次元コードは、記号・番号と同じ情報を持っていることがあります。番号だけ黒塗りしてコードを残すと、隠した意味が薄れます。
    36	
    37	発注者によってマスキングの指定は異なり、受付後に発注者側で処理する運用のところもあります。**提出先の指示を必ず確認してください。** 指示が「記号・番号のみ」であれば、それ以外を隠す必要はありません。
    38	
    39	ファイルはブラウザの中だけで処理され、サーバーには送信されません。登録も不要です。
    40	
    41	[資格確認書の黒塗りを、ブラウザだけで試す](https://slimfile.net/safe/jp/nyusatsu/)
### content/jp/ep02/post_ja.md
     1	---
     2	title: 入札添付の資格確認書、マスキング指示の読み方
     3	hook: 入札公告の「マスキングのうえ提出」は、どこを隠すかを書いていないことがあります。
     4	bullets:
     5	  - 「被保険者等記号・番号」は記号と番号の両方を指し、枝番を含むのが通例です
     6	  - 「個人情報を除いて」は氏名まで消す指示ではなく、審査項目は残すのが前提です
     7	  - 指定が読み取れないときは、発注者の窓口に確認するのが最短です
     8	cta: 提出目的を選ぶだけで、書類別の黒塗り箇所を確認する
     9	---
    10	
    11	入札公告や提出要領の文言は発注者ごとに違います。「被保険者等記号・番号をマスキングのうえ提出してください」と具体的に書く発注者もあれば、「個人情報に配慮し適宜処理のうえ」で止まる発注者もあります。後者が差し戻しの温床で、担当者が自分で範囲を決めることになります。
    12	
    13	## 文言ごとの読み方
    14	
    15	| 公告の文言 | 通常の意味 | 迷いやすい点 |
    16	| --- | --- | --- |
    17	| 被保険者等記号・番号をマスキング | 記号・番号・枝番の3点 | 枝番が別枠に小さく印字されていることがある |
    18	| 保険者番号を含めマスキング | 上記＋保険者番号（8桁または6桁） | 二次元コードに同じ情報が含まれる場合がある |
    19	| 個人情報を除いて提出 | 告知要求制限の対象箇所 | 氏名・生年月日・事業所名は審査項目で、消すと受付されないことがあります |
    20	| 発注者側でマスキングするため原本の写しを提出 | 処理不要 | 先に黒塗りして出すと、記載不備として扱われる場合があります |
    21	
    22	4行目のような運用が実際にあるため、「とりあえず多めに隠す」は安全策になりません。隠しすぎは不備であり、隠し足りないのは告知要求制限に触れる可能性がある、という両側の制約があります。
    23	
    24	二次元コードは紙面では情報の種類が見えません。記号・番号を隠す指示が出ている書類でコードが印字されている場合、コードが同じ情報を持っているかは外から判断できないため、併せて隠す運用が無難です。これも発注者の指示が優先します。
    25	
    26	## 読み取れないときの順番
    27	
    28	1. 提出要領とQ&Aを検索語「マスキング」「記号」「番号」で確認する
    29	2. 同じ発注者の過去案件の提出要領を見る — 文言はほぼ再利用されます
    30	3. それでも不明なら窓口に照会する。照会の記録を残しておくと、次回以降の判断材料になります
    31	
    32	**提出先の指示を必ず確認してください。** 法令は「求めてはいけない」側を縛るもので、提出者が何を隠すべきかを一行で決めてくれるわけではありません。
    33	
    34	SafeFile は書類の種類を判定し、提出目的ごとに「自動で隠す項目」と「残す項目」を分けて表示します。発注者の指示と違うときは、項目単位で切り替えられます。
    35	
    36	[提出目的を選ぶだけで、書類別の黒塗り箇所を確認する](https://slimfile.net/safe/jp/nyusatsu/)
### content/jp/ep03/post_ja.md
     1	---
     2	title: ChatGPTに契約書を貼る前に、個人情報だけ黒塗りする
     3	hook: AIに契約書の意味を聞くとき、相手方の氏名と口座番号まで一緒に送っています。
     4	bullets:
     5	  - 相談に必要なのは条項と金額の関係で、相手方の氏名・住所・口座ではありません
     6	  - 貼り付けた内容を保存するAIサービスは多く、あとから取り消せない前提で考えます
     7	  - 画像にして貼れば、黒塗りの下の文字列はコピーできません
     8	cta: 契約書をAIに貼る前に、個人情報だけ黒塗りする
     9	captions:
    10	  - "① 契約書のPDFか写真をドラッグする"
    11	  - "② 「提出目的：相談用共有」を選ぶと、相手方の情報だけが候補になる"
    12	  - "③ ダウンロードした画像をAIに貼り付ける"
    13	---
    14	
    15	賃貸借契約書の更新料の条項、請負契約の支払期日、給与明細の控除額 — AIに聞けば数十秒で説明が返ってきます。便利さは本物です。ただ、貼り付けた文面には相談と関係のない情報が一緒に入っています。貸主と保証人の氏名、相手方の住所と電話番号、振込先の口座番号、自分の社員番号。多くのAIサービスは入力内容を保存し、設定によっては学習にも使われます。送ったあとで取り消す手段は、基本的にありません。
    16	
    17	相談に必要なのは何かを先に決めると、隠す範囲は短く済みます。
    18	
    19	## 残すもの・隠すもの
    20	
    21	| 残す（AIが答えるのに必要） | 隠す（相談に不要） |
    22	| --- | --- |
    23	| 契約条項の文言、見出し、条番号 | 相手方（貸主・保証人・取引先）の氏名・住所・電話 |
    24	| 金額とその相対関係、支払期日 | 口座番号・残高・社員番号 |
    25	| 日付、期間、更新条件 | 印影・署名 |
    26	| 書類の種類がわかる表題 | 自分の住所の番地以下（必要に応じて） |
    27	
    28	条項の文言を残すのが肝心です。「甲は乙に対し」を匿名化しても意味は変わりませんが、金額や期日を消すと答えの精度が落ちます。相談の質を落とさずに個人情報だけ減らす、というのがここでの最小化です。
    29	
    30	## 手順
    31	
    32	1. 契約書のPDFか写真をドラッグします。
    33	2. 「提出目的：相談用共有」を選びます。相手方の氏名・住所・口座が候補として挙がり、条項や金額は残ります。
    34	3. ダウンロードした画像をAIに貼り付けます。出力は画像に平坦化されているため、黒塗りの下の文字列をコピーすることはできません。
    35	
    36	テキストとして貼り付けたい場合は、黒塗り後に自分で書き写すか、固有名詞を「貸主A」「口座X」のような仮名に置き換えてください。文字列のまま渡すと、見た目で隠しても元の文字が残ります。
    37	
    38	社内規程や受任契約で、第三者サービスへの入力が制限されている場合があります。**提出先の指示を必ず確認してください。** 業務上の文書であれば、AIに貼る前に所属のルールを確認するのが先です。
    39	
    40	ファイルはブラウザの中だけで処理され、サーバーには送信されません。
    41	
    42	[契約書をAIに貼る前に、個人情報だけ黒塗りする](https://slimfile.net/safe/jp/ai-mae/)
### content/jp/ep01/post_en.md
     1	---
     2	title: How to redact the numbers on a qualification certificate before you submit it
     3	hook: Most tender attachments come back for one reason — a single symbol or number that was never covered.
     4	bullets:
     5	  - Cover the insurer number, symbol, number, branch number and 2-D code. Keep the name and the employer
     6	  - A black box drawn in a photo editor can leave the PDF's text layer intact, so check before you submit
     7	  - Flattening the output to an image means nothing survives under the bar
     8	cta: Try redacting a qualification certificate in your browser
     9	---
    10	
    11	Japanese public-works tenders generally require masking of the "insured symbol/number" and the "insurer number" on copies of health-insurance qualification certificates. The basis is the disclosure restriction introduced by amendments to the Health Insurance Act, in force since 1 October 2020: asking for the symbol or number for purposes other than medical-insurance administration is restricted in principle.
    12	
    13	Rejections almost always come from manual work. A copy covered with sticky notes or correction tape can show the digits through, depending on the scanner's light. A PDF with a black rectangle laid on top of the text may look redacted on screen while the text layer underneath is still selectable. And the branch number and the 2-D code are small enough on paper that they are the last things anyone notices.
    14	
    15	## What to cover, and what to keep
    16	
    17	| Document | Cover | Keep |
    18	| --- | --- | --- |
    19	| Qualification certificate (employee / national / late-elderly insurance) | Insurer number, symbol, number, branch number, 2-D code | Name, date of birth, address, expiry, employer name |
    20	| Standard remuneration decision notice | Insured reference number | Name, employer name, period |
    21	| Residence record | My Number, residence code (when the recipient does not ask for them) | Name, address, issuer |
    22	
    23	Review is done on the name, the date of birth and the employer name. Covering the numbers and accidentally covering the fields the reviewer needs are two different mistakes, and the second one also gets your submission sent back.
    24	
    25	## Three steps
    26	
    27	1. Drag in the PDF or the photo. Several files at once is fine.
    28	2. Choose "Purpose: tender attachment". The document type is detected and the fields to cover are decided for you; anything you want to keep can be switched back individually.
    29	3. Download. The output is flattened to an image, so no original text remains under the bars, and EXIF and annotations are stripped.
    30	
    31	The 2-D code often carries the same information as the symbol and number. Redacting the digits and leaving the code defeats most of the point.
    32	
    33	Masking requirements differ between contracting authorities, and some mask the copies themselves after receipt. **Always check the recipient's own instructions.** If they ask only for the symbol and number, there is no need to cover anything else.
    34	
    35	Files are processed inside your browser and are never uploaded. No account is needed.
    36	
    37	[Try redacting a qualification certificate in your browser](https://slimfile.net/safe/jp/nyusatsu/)
### content/jp/ep02/post_en.md
     1	---
     2	title: Reading a tender's masking instructions for insurance certificate copies
     3	hook: "Submit with masking applied" often does not say which part to mask.
     4	bullets:
     5	  - "Insured symbol/number" means both the symbol and the number, and normally includes the branch number
     6	  - "Excluding personal information" is not an instruction to remove the name — the review fields stay
     7	  - When the wording cannot be read either way, asking the authority's desk is the shortest route
     8	cta: Pick a submission purpose and see which fields each document needs covered
     9	---
    10	
    11	Tender notices are written by each contracting authority, so the wording varies. Some say exactly "please mask the insured symbol and number"; others stop at "handle personal information appropriately". The second kind is where rejections come from, because the clerk ends up deciding the scope.
    12	
    13	## What each phrase usually means
    14	
    15	| Wording in the notice | Usual meaning | Easy to get wrong |
    16	| --- | --- | --- |
    17	| Mask the insured symbol/number | Symbol, number and branch number | The branch number is often printed small, in its own box |
    18	| Mask including the insurer number | The above plus the insurer number (8 or 6 digits) | The 2-D code may carry the same information |
    19	| Submit excluding personal information | The fields covered by the disclosure restriction | Name, date of birth and employer are review fields — removing them can mean the submission is not accepted |
    20	| Submit a plain copy; we will mask it ourselves | No processing needed | Redacting it first can be treated as a defective entry |
    21	
    22	Because the fourth row genuinely happens, "cover extra to be safe" is not a safe strategy. Covering too much is a defect; covering too little may touch the disclosure restriction. Both sides are constraints.
    23	
    24	A 2-D code gives no hint on paper about what it encodes. When a document carries one and the notice asks for the symbol and number to be masked, there is no way to tell from the outside whether the code holds the same data, so covering it as well is the safer default. Here too the authority's instructions come first.
    25	
    26	## When you cannot tell
    27	
    28	1. Search the submission guidelines and the Q&A for "masking", "symbol" and "number"
    29	2. Look at the same authority's guidelines for earlier contracts — the wording is usually reused
    30	3. If it is still unclear, ask the desk, and keep a record of the answer for next time
    31	
    32	**Always check the recipient's own instructions.** The law constrains the party that may not *ask* for the number; it does not decide, in one line, what a submitter should cover.
    33	
    34	SafeFile detects the document type and shows, per submission purpose, which fields it covers automatically and which it keeps visible. Where the authority's instruction differs, each field can be switched individually.
    35	
    36	[Pick a submission purpose and see which fields each document needs covered](https://slimfile.net/safe/jp/nyusatsu/)
### content/jp/ep03/post_en.md
     1	---
     2	title: Redact the personal data before you paste a contract into ChatGPT
     3	hook: When you ask an AI what a contract clause means, the other party's name and bank account go with it.
     4	bullets:
     5	  - What the question needs is the clauses and the relationship between the figures — not the other party's name, address or account
     6	  - Many AI services store what you paste, so assume you cannot take it back
     7	  - Paste it as an image and the text under the bars cannot be copied
     8	cta: Redact the personal data before you paste a contract into an AI
     9	---
    10	
    11	A renewal-fee clause in a lease, the payment date in a works contract, a deduction line on a payslip — ask an AI and you get an explanation in seconds. The convenience is real. But the text you pasted carries things the question never needed: the landlord's and guarantor's names, the other party's address and phone number, the account to pay into, your own employee number. Most AI services retain what you type, and depending on the settings it may also be used for training. There is generally no way to take it back afterwards.
    12	
    13	Decide what the question actually needs first, and the amount you have to cover turns out to be small.
    14	
    15	## Keep versus cover
    16	
    17	| Keep (the AI needs it) | Cover (the question does not) |
    18	| --- | --- |
    19	| Clause wording, headings, article numbers | Names, addresses and phone numbers of the other party, guarantor or counterparty |
    20	| Amounts and how they relate, payment dates | Account numbers, balances, employee numbers |
    21	| Dates, terms, renewal conditions | Seals and signatures |
    22	| The title that identifies the document type | Your own street-level address, if you prefer |
    23	
    24	Keeping the clause wording is the part that matters. Anonymising "Party A shall, to Party B" changes nothing, but deleting the amounts and the dates makes the answer worse. Minimisation here means reducing the personal data without reducing the quality of the answer.
    25	
    26	## Steps
    27	
    28	1. Drag in the PDF or the photo of the contract.
    29	2. Choose "Purpose: sharing for advice". The other party's name, address and account come up as candidates; the clauses and figures stay.
    30	3. Paste the downloaded image into the AI. The output is flattened to an image, so the text under the bars cannot be copied out.
    31	
    32	If you need to paste text rather than an image, retype it after redacting, or replace proper nouns with placeholders such as "Landlord A" or "Account X". Handing over a character string keeps the original characters no matter how it looks.
    33	
    34	Internal policy or a client engagement may restrict entering documents into third-party services. **Always check the recipient's own instructions.** For anything work-related, check your organisation's rules before you paste.
    35	
    36	Files are processed inside your browser and are never uploaded.
    37	
    38	[Redact the personal data before you paste a contract into an AI](https://slimfile.net/safe/jp/ai-mae/)
### content/jp/ep01/x_thread.md
     1	<!-- generated by scripts/content/make_episode.mjs — ep01. Edit post_ja.md and re-run. -->
     2	# X thread — ep01
     3	
     4	> 資格確認書の番号を隠して提出する手順【提出先の指示を確認】
     5	> landing: https://slimfile.net/safe/jp/nyusatsu/?utm_source=x&utm_campaign=ep01
     6	
     7	## 1 / 5  (74字)
     8	
     9	```
    10	入札書類が差し戻される理由の多くは、記号・番号の黒塗りが一箇所だけ残っていることです。
    11	
    12	資格確認書の番号を隠して提出する手順【提出先の指示を確認】
    13	```
    14	
    15	## 2 / 5  (39字)
    16	
    17	```
    18	①隠すのは保険者番号・記号・番号・枝番・二次元コード。氏名と事業所名は残します
    19	```
    20	
    21	## 3 / 5  (40字)
    22	
    23	```
    24	②画像編集アプリの黒塗りはPDFの文字層が残ることがあり、提出前に確認が必要です
    25	```
    26	
    27	## 4 / 5  (28字)
    28	
    29	```
    30	③出力を画像に平坦化すれば、黒塗りの下に原文は残りません
    31	```
    32	
    33	## 5 / 5  (90字)
    34	
    35	```
    36	資格確認書の黒塗りを、ブラウザだけで試す
    37	https://slimfile.net/safe/jp/nyusatsu/?utm_source=x&utm_campaign=ep01
    38	```
### content/jp/ep02/x_thread.md
     1	<!-- generated by scripts/content/make_episode.mjs — ep02. Edit post_ja.md and re-run. -->
     2	# X thread — ep02
     3	
     4	> 入札添付の資格確認書、マスキング指示の読み方
     5	> landing: https://slimfile.net/safe/jp/nyusatsu/?utm_source=x&utm_campaign=ep02
     6	
     7	## 1 / 5  (64字)
     8	
     9	```
    10	入札公告の「マスキングのうえ提出」は、どこを隠すかを書いていないことがあります。
    11	
    12	入札添付の資格確認書、マスキング指示の読み方
    13	```
    14	
    15	## 2 / 5  (37字)
    16	
    17	```
    18	①「被保険者等記号・番号」は記号と番号の両方を指し、枝番を含むのが通例です
    19	```
    20	
    21	## 3 / 5  (38字)
    22	
    23	```
    24	②「個人情報を除いて」は氏名まで消す指示ではなく、審査項目は残すのが前提です
    25	```
    26	
    27	## 4 / 5  (31字)
    28	
    29	```
    30	③指定が読み取れないときは、発注者の窓口に確認するのが最短です
    31	```
    32	
    33	## 5 / 5  (95字)
    34	
    35	```
    36	提出目的を選ぶだけで、書類別の黒塗り箇所を確認する
    37	https://slimfile.net/safe/jp/nyusatsu/?utm_source=x&utm_campaign=ep02
    38	```
### content/jp/ep03/x_thread.md
     1	<!-- generated by scripts/content/make_episode.mjs — ep03. Edit post_ja.md and re-run. -->
     2	# X thread — ep03
     3	
     4	> ChatGPTに契約書を貼る前に、個人情報だけ黒塗りする
     5	> landing: https://slimfile.net/safe/jp/ai-mae/?utm_source=x&utm_campaign=ep03
     6	
     7	## 1 / 5  (68字)
     8	
     9	```
    10	AIに契約書の意味を聞くとき、相手方の氏名と口座番号まで一緒に送っています。
    11	
    12	ChatGPTに契約書を貼る前に、個人情報だけ黒塗りする
    13	```
    14	
    15	## 2 / 5  (38字)
    16	
    17	```
    18	①相談に必要なのは条項と金額の関係で、相手方の氏名・住所・口座ではありません
    19	```
    20	
    21	## 3 / 5  (40字)
    22	
    23	```
    24	②貼り付けた内容を保存するAIサービスは多く、あとから取り消せない前提で考えます
    25	```
    26	
    27	## 4 / 5  (28字)
    28	
    29	```
    30	③画像にして貼れば、黒塗りの下の文字列はコピーできません
    31	```
    32	
    33	## 5 / 5  (91字)
    34	
    35	```
    36	契約書をAIに貼る前に、個人情報だけ黒塗りする
    37	https://slimfile.net/safe/jp/ai-mae/?utm_source=x&utm_campaign=ep03
    38	```

hook: PostToolUse
hook: PostToolUse Completed
codex
Q4에서는 실제 범위 내 결함이 확인됩니다. ep01~03의 `x_thread.md` 어느 것도 필수 문장 「提出先の指示を必ず確認してください」를 포함하지 않습니다. 본문만 검사하는 가드와 달리 X 산출물은 누락을 그대로 통과시키므로, 산출물 전체 규칙으로 보면 공허한 통과입니다. 캐러셀은 이미지와 템플릿 양쪽을 이어서 확인하겠습니다.
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "sed -n '118,175p' docs/jp/jp_safefile_strategy_v2_2026-10-21.md | nl -ba -v118; sed -n '35,58p' docs/jp/jp_market_decision_v2_2026-10-22.md | nl -ba -v35; nl -ba content/jp/topics.json; sed -n '55,180p' scripts/content/make_episode.mjs | nl -ba -v55; sed -n '180,440p' scripts/content/make_episode.mjs | nl -ba -v180; nl -ba scripts/content/templates/carousel.html" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
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
    35	**개인 구독(D)**: 하지 않음.
    36	
    37	## 2. 포지셔닝 문장 (확정)
    38	- JA: 「提出先のルールどおりに、自動で正しく黒塗り。ファイルはブラウザの外に出ません。」
    39	- 차별점 3개: ① 資格確認書·住民票 등 서류별·제출목적별 프리셋 ② PC 브라우저에서 설치 없이(복합기 스캔 PDF 그대로) ③ 완전 로컬 + 평탄화로 복원 불가
    40	- 금지: "유일한 툴", 사건명 전환 광고, "막을 수 있었다"
    41	
    42	## 3. 랜딩 3페이지 (변경)
    43	1. **入札添付の資格確認書マスキング** — 사업자용. 입찰공고 원문 인용, 반려 사례, 일괄처리 데모, 파일럿 모집 폼
    44	2. **本人確認書類は「必要な面だけ」** — 개인용. 免許証·マイナカード 최소화 원칙(JPKI 확산도 언급), 사건명 없음
    45	3. **AIに貼り付ける前に黒塗り** — 신규. 계약서·급여명세 익명화, consult_share 프리셋 데모
    46	
    47	## 4. 콘텐츠 30편 수정
    48	- 1·14·20번(타임즈카 1인칭·사건 중심) → "最小化原則" 교육형으로 재작성
    49	- 신규 3편 추가: 「ChatGPTに契約書を貼る前に」「補助金精算の添付書類、どこまで隠す」「電子入札のPDF容量と黒塗りを一度に」 (SlimFile 압축과 결합 — 기존 자산 활용)
    50	
    51	## 5. 다음 액션
    52	- S6 랜딩 3페이지 문안(JA/EN) → Justin 검수 → 구현
    53	- 파일럿 후보 10곳 리스트업(電子入札代行·建設業行政書士·建設業協会 지부) + 접촉 메일 초안(JA/EN)
    54	- 콘텐츠 파이프라인 구현(Claude Code)
    55	- 베타 2주 후 측정: 랜딩별 전환, 파일럿 응답률, 처리 문서 종류 분포
    56	
    57	## 출처(추가)
    58	- Pixelate: https://apps.apple.com/jp/app/id6796954642
     1	{
     2	  "_readme": [
     3	    "SafeFile JP content plan — 33 episodes, one per week.",
     4	    "",
     5	    "Derived from jp_safefile_strategy_v2_2026-10-21.md §6 (30 episodes) with the",
     6	    "changes jp_market_decision_v2_2026-10-22.md §4 requires:",
     7	    "  * §6 numbers 1, 14 and 20 were incident-led and first-person. Rewritten as",
     8	    "    教育型 pieces about the 最小化原則 — the principle survives, the anecdote",
     9	    "    does not. `src` records where each episode came from so the rewrite is",
    10	    "    auditable; `rewritten: true` marks the three.",
    11	    "  * three new episodes added (ep03, ep05, ep06), all of which lean on",
    12	    "    SlimFile compression or an existing landing page rather than new code.",
    13	    "",
    14	    "`ep` IS the publishing order and equals `week` — the folder is content/jp/epNN",
    15	    "and scripts/content/make_episode.mjs takes that number. `src` is the strategy",
    16	    "document's own numbering, which is NOT the order any more.",
    17	    "",
    18	    "Ordering rules applied (from s7_prompt §A):",
    19	    "  * tier-1 (business, 資格確認書 / 入札) first — ep01, ep02",
    20	    "  * the two AI-anonymisation pieces inside the first four weeks — ep03, ep04",
    21	    "  * the three new SlimFile-combined business pieces next — ep05, ep06 (ep03 is",
    22	    "    AI, so the third new one is ep06)",
    23	    "",
    24	    "`doc` is the APP'S document key (shikaku_kakuninsho | unten_menkyo |",
    25	    "mynumber_card | juminhyo) when a golden fixture exists for it, because that is",
    26	    "what make_episode.mjs needs to record a demo. Anything else is a plain",
    27	    "Japanese label and means 'no dummy document exists' — the pipeline then writes",
    28	    "demo: \"failed: …\" into the manifest instead of pretending. null = no single",
    29	    "document (a general or explanatory piece).",
    30	    "",
    31	    "`purpose` is one of the four the app offers; `landing` is the CTA target.",
    32	    "`status`: draft (no body yet) → ready (body written, assets built) → posted."
    33	  ],
    34	  "_forbidden": [
    35	    "No incident names (タイムズカー etc.). No first-person victim account.",
    36	    "Never 絶対 / 防ぐ / 唯一 / 必ず安全.",
    37	    "Every how-to carries 「提出先の指示を必ず確認してください」 on its own line.",
    38	    "Dummy card images only as reduced illustrations (long edge <= 800px).",
    39	    "Legal effects stated at most as 「制限される場合があります」.",
    40	    "Unshipped features must not be advertised (see ep32)."
    41	  ],
    42	  "episodes": [
    43	    {
    44	      "ep": 1, "week": 1, "track": "A", "src": 2,
    45	      "title_ja": "資格確認書の番号を隠して提出する手順【提出先の指示を確認】",
    46	      "title_en": "How to redact the numbers on a qualification certificate before you submit it",
    47	      "doc": "shikaku_kakuninsho", "purpose": "bid_attachment", "landing": "nyusatsu",
    48	      "status": "draft"
    49	    },
    50	    {
    51	      "ep": 2, "week": 2, "track": "B", "src": 8,
    52	      "title_ja": "入札添付の資格確認書、マスキング指示の読み方",
    53	      "title_en": "Reading a tender's masking instructions for insurance certificate copies",
    54	      "doc": "shikaku_kakuninsho", "purpose": "bid_attachment", "landing": "nyusatsu",
    55	      "status": "draft"
    56	    },
    57	    {
    58	      "ep": 3, "week": 3, "track": "A", "src": "new",
    59	      "title_ja": "ChatGPTに契約書を貼る前に、個人情報だけ黒塗りする",
    60	      "title_en": "Redact the personal data before you paste a contract into ChatGPT",
    61	      "doc": "契約書", "purpose": "consult_share", "landing": "aimae",
    62	      "status": "draft"
    63	    },
    64	    {
    65	      "ep": 4, "week": 4, "track": "A", "src": 17,
    66	      "title_ja": "賃貸借契約書を専門家に相談する前の匿名化",
    67	      "title_en": "Anonymising a lease before you ask a professional about it",
    68	      "doc": "契約書", "purpose": "consult_share", "landing": "aimae",
    69	      "status": "draft"
    70	    },
    71	    {
    72	      "ep": 5, "week": 5, "track": "A", "src": "new",
    73	      "title_ja": "電子入札のPDF容量と黒塗りを一度に片づける",
    74	      "title_en": "Handling e-tender PDF size limits and redaction in one pass",
    75	      "doc": "shikaku_kakuninsho", "purpose": "bid_attachment", "landing": "nyusatsu",
    76	      "status": "draft"
    77	    },
    78	    {
    79	      "ep": 6, "week": 6, "track": "A", "src": "new",
    80	      "title_ja": "補助金精算の添付書類、どこまで隠すか",
    81	      "title_en": "Subsidy settlement attachments: how much to redact",
    82	      "doc": "shikaku_kakuninsho", "purpose": "bid_attachment", "landing": "nyusatsu",
    83	      "status": "draft"
    84	    },
    85	    {
    86	      "ep": 7, "week": 7, "track": "A", "src": 11,
    87	      "title_ja": "源泉徴収票に個人番号があるとき、ないとき",
    88	      "title_en": "Withholding slips: when a My Number is printed on them, and when it is not",
    89	      "doc": "源泉徴収票", "purpose": "identity_submit", "landing": "nyusatsu",
    90	      "status": "draft"
    91	    },
    92	    {
    93	      "ep": 8, "week": 8, "track": "B", "src": 28,
    94	      "title_ja": "家族の書類を代理で出すときに確認すること",
    95	      "title_en": "Submitting a family member's documents on their behalf",
    96	      "doc": "shikaku_kakuninsho", "purpose": "identity_submit", "landing": "honnin",
    97	      "status": "draft"
    98	    },
    99	    {
   100	      "ep": 9, "week": 9, "track": "A", "src": 5,
   101	      "title_ja": "マイナンバーカード：身元確認なら表面だけ。裏面が必要な手続きとは",
   102	      "title_en": "My Number card: the front is enough for identity. When is the back actually required?",
   103	      "doc": "mynumber_card", "purpose": "identity_submit", "landing": "honnin",
   104	      "status": "draft"
   105	    },
   106	    {
   107	      "ep": 10, "week": 10, "track": "A", "src": 3,
   108	      "title_ja": "運転免許証を送る前に確認する3つのこと",
   109	      "title_en": "Three things to check before you send a copy of your driving licence",
   110	      "doc": "unten_menkyo", "purpose": "identity_submit", "landing": "honnin",
   111	      "status": "draft"
   112	    },
   113	    {
   114	      "ep": 11, "week": 11, "track": "A", "src": 7,
   115	      "title_ja": "住民票の写し：用途別に残す項目・隠す項目",
   116	      "title_en": "Residence records: what to keep and what to cover, by purpose",
   117	      "doc": "juminhyo", "purpose": "identity_submit", "landing": "honnin",
   118	      "status": "draft"
   119	    },
   120	    {
   121	      "ep": 12, "week": 12, "track": "B", "src": 4,
   122	      "title_ja": "「黒塗りしたつもり」が読めてしまう仕組みと、読めなくする方法",
   123	      "title_en": "Why a redaction you thought you made is still readable — and what makes it not",
   124	      "doc": null, "purpose": "identity_submit", "landing": "honnin",
   125	      "status": "draft"
   126	    },
   127	    {
   128	      "ep": 13, "week": 13, "track": "B", "src": 10,
   129	      "title_ja": "付箋・マスキングテープで隠して撮影する方法の限界",
   130	      "title_en": "The limits of covering a document with tape before photographing it",
   131	      "doc": null, "purpose": "identity_submit", "landing": "honnin",
   132	      "status": "draft"
   133	    },
   134	    {
   135	      "ep": 14, "week": 14, "track": "B", "src": 18,
   136	      "title_ja": "「マスキングしてください」と書く提出先、書かない提出先",
   137	      "title_en": "Recipients who ask for masking, and recipients who do not",
   138	      "doc": null, "purpose": "bid_attachment", "landing": "nyusatsu",
   139	      "status": "draft"
   140	    },
   141	    {
   142	      "ep": 15, "week": 15, "track": "B", "src": 1, "rewritten": true,
   143	      "title_ja": "本人確認書類は「最小化」が原則 — 求められた面と項目だけを出す",
   144	      "title_en": "Minimisation is the rule for identity documents: submit only the side and fields asked for",
   145	      "doc": null, "purpose": "identity_submit", "landing": "honnin",
   146	      "status": "draft"
   147	    },
   148	    {
   149	      "ep": 16, "week": 16, "track": "B", "src": 6,
   150	      "title_ja": "フリマ・ネット銀行の本人確認、画像を送る前にできること",
   151	      "title_en": "KYC for marketplaces and online banks: what to do before you upload",
   152	      "doc": "unten_menkyo", "purpose": "identity_submit", "landing": "honnin",
   153	      "status": "draft"
   154	    },
   155	    {
   156	      "ep": 17, "week": 17, "track": "B", "src": 12,
   157	      "title_ja": "賃貸契約で身分証のコピーを求められたら確認すること",
   158	      "title_en": "When a rental application asks for an ID copy",
   159	      "doc": "unten_menkyo", "purpose": "identity_submit", "landing": "honnin",
   160	      "status": "draft"
   161	    },
   162	    {
   163	      "ep": 18, "week": 18, "track": "A", "src": 9,
   164	      "title_ja": "履歴書PDF、相談用に連絡先だけ隠す",
   165	      "title_en": "Sharing a CV for advice: cover the contact details only",
   166	      "doc": "履歴書", "purpose": "consult_share", "landing": "aimae",
   167	      "status": "draft"
   168	    },
   169	    {
   170	      "ep": 19, "week": 19, "track": "A", "src": 15,
   171	      "title_ja": "給与明細を相談に出すとき、口座と社員番号の扱い",
   172	      "title_en": "Payslips for advice: what to do with the account and employee numbers",
   173	      "doc": "給与明細", "purpose": "consult_share", "landing": "aimae",
   174	      "status": "draft"
   175	    },
   176	    {
   177	      "ep": 20, "week": 20, "track": "A", "src": 21,
   178	      "title_ja": "通帳画像：残高証明として出す場合と相談用の違い",
   179	      "title_en": "Bankbook images: proof of balance versus sharing for advice",
   180	      "doc": "通帳", "purpose": "consult_share", "landing": "aimae",
   181	      "status": "draft"
   182	    },
   183	    {
   184	      "ep": 21, "week": 21, "track": "A", "src": 13,
   185	      "title_ja": "在留カード：提出先が求める面を確認してから隠す",
   186	      "title_en": "Residence cards: confirm which side is required before you cover anything",
   187	      "doc": "在留カード", "purpose": "identity_submit", "landing": "honnin",
   188	      "status": "draft"
   189	    },
   190	    {
   191	      "ep": 22, "week": 22, "track": "A", "src": 19,
   192	      "title_ja": "パスポート：番号・MRZを隠してよい場面、いけない場面",
   193	      "title_en": "Passports: when the number and MRZ may be covered, and when they may not",
   194	      "doc": "パスポート", "purpose": "identity_submit", "landing": "honnin",
   195	      "status": "draft"
   196	    },
   197	    {
   198	      "ep": 23, "week": 23, "track": "A", "src": 23,
   199	      "title_ja": "職務経歴書を匿名で共有するときの考え方",
   200	      "title_en": "Sharing a work history anonymously",
   201	      "doc": "職務経歴書", "purpose": "consult_share", "landing": "aimae",
   202	      "status": "draft"
   203	    },
   204	    {
   205	      "ep": 24, "week": 24, "track": "A", "src": 25,
   206	      "title_ja": "スマホだけで：撮影 → 黒塗り → 確認 → 送信",
   207	      "title_en": "Phone only: photograph, redact, check, send",
   208	      "doc": "unten_menkyo", "purpose": "identity_submit", "landing": "honnin",
   209	      "status": "draft"
   210	    },
   211	    {
   212	      "ep": 25, "week": 25, "track": "A", "src": 27,
   213	      "title_ja": "透かし「〇〇提出用」の入れ方と、その限界",
   214	      "title_en": "Adding a 'for submission to X' watermark — and what it cannot do",
   215	      "doc": "shikaku_kakuninsho", "purpose": "bid_attachment", "landing": "nyusatsu",
   216	      "status": "draft"
   217	    },
   218	    {
   219	      "ep": 26, "week": 26, "track": "B", "src": 14, "rewritten": true,
   220	      "title_ja": "提出した本人確認書類はいつまで残るのか — 最小化が効く理由",
   221	      "title_en": "How long a submitted ID copy stays on file — and why minimisation helps",
   222	      "doc": null, "purpose": "identity_submit", "landing": "honnin",
   223	      "status": "draft"
   224	    },
   225	    {
   226	      "ep": 27, "week": 27, "track": "B", "src": 20, "rewritten": true,
   227	      "title_ja": "「そもそも出さない」という選択 — 最小化原則の実務",
   228	      "title_en": "Choosing not to send it at all: minimisation in practice",
   229	      "doc": null, "purpose": "identity_submit", "landing": "honnin",
   230	      "status": "draft"
   231	    },
   232	    {
   233	      "ep": 28, "week": 28, "track": "B", "src": 22,
   234	      "title_ja": "学生証の画像を送るとき、学生が確認できること",
   235	      "title_en": "Student ID images: what a student can check first",
   236	      "doc": "学生証", "purpose": "identity_submit", "landing": "honnin",
   237	      "status": "draft"
   238	    },
   239	    {
   240	      "ep": 29, "week": 29, "track": "B", "src": 24,
   241	      "title_ja": "「サーバーに保存しない」ツールの見分け方",
   242	      "title_en": "How to tell whether a tool really keeps your file in the browser",
   243	      "doc": null, "purpose": "identity_submit", "landing": "honnin",
   244	      "status": "draft"
   245	    },
   246	    {
   247	      "ep": 30, "week": 30, "track": "B", "src": 16,
   248	      "title_ja": "2027年4月の犯収法改正で本人確認はどう変わるか",
   249	      "title_en": "What the April 2027 AML rule change means for identity verification",
   250	      "doc": null, "purpose": "identity_submit", "landing": "honnin",
   251	      "status": "draft"
   252	    },
   253	    {
   254	      "ep": 31, "week": 31, "track": "B", "src": 26,
   255	      "title_ja": "副業の本人確認を毎回やり直さないために",
   256	      "title_en": "Not redoing side-job identity checks from scratch every time",
   257	      "doc": null, "purpose": "identity_submit", "landing": "honnin",
   258	      "status": "draft"
   259	    },
   260	    {
   261	      "ep": 32, "week": 32, "track": "A", "src": 29,
   262	      "title_ja": "複数書類をまとめて処理する",
   263	      "title_en": "Processing several documents in one pass",
   264	      "doc": "shikaku_kakuninsho", "purpose": "bid_attachment", "landing": "nyusatsu",
   265	      "status": "draft",
   266	      "blocked_until": "batch processing ships",
   267	      "note": "Unshipped feature. The strategy forbids advertising it, so this episode must NOT be written or built before batch processing exists. Kept in the list so the slot is visible rather than forgotten."
   268	    },
   269	    {
   270	      "ep": 33, "week": 33, "track": "B", "src": 30,
   271	      "title_ja": "3か月の振り返りと、よくある黒塗りの落とし穴",
   272	      "title_en": "Three months in: the redaction mistakes we keep seeing",
   273	      "doc": null, "purpose": "identity_submit", "landing": "honnin",
   274	      "status": "draft"
   275	    }
   276	  ]
   277	}
    55	const argv = process.argv.slice(2);
    56	const epArg = argv.find((a) => /^\d+$/.test(a));
    57	const noDemo = argv.includes('--no-demo');
    58	if (!epArg) {
    59	  console.error('usage: node scripts/content/make_episode.mjs <ep> [--no-demo]');
    60	  process.exit(2);
    61	}
    62	const EP = Number(epArg);
    63	const EPP = String(EP).padStart(2, '0');   // the zero-padded form used in folder names, UTM tags and labels
    64	const epDir = path.join(CONTENT, 'ep' + EPP);
    65	
    66	/* ── plan ─────────────────────────────────────────────────────────────────── */
    67	const plan = JSON.parse(fs.readFileSync(path.join(CONTENT, 'topics.json'), 'utf8'));
    68	const topic = plan.episodes.find((e) => e.ep === EP);
    69	if (!topic) {
    70	  console.error(`ep${EP} is not in content/jp/topics.json`);
    71	  process.exit(2);
    72	}
    73	if (topic.blocked_until) {
    74	  // ep32 advertises batch processing, which does not exist. The strategy
    75	  // forbids promoting unshipped features, so refuse rather than build it.
    76	  console.error(`ep${EP} is blocked until: ${topic.blocked_until}`);
    77	  console.error(topic.note || '');
    78	  process.exit(2);
    79	}
    80	const landing = LANDING_PATH[topic.landing];
    81	if (!landing) {
    82	  console.error(`ep${EP}: unknown landing "${topic.landing}"`);
    83	  process.exit(2);
    84	}
    85	const utmUrl = `${BASE_URL}${landing}?utm_source=x&utm_campaign=ep${EPP}`;
    86	
    87	/* ── frontmatter ──────────────────────────────────────────────────────────── */
    88	/* A deliberately small YAML subset: `key: value` and `key:` followed by `- `
    89	 * items. Pulling in a YAML dependency for five keys would buy nothing, and a
    90	 * parser that quietly accepted more than this would let the post file drift
    91	 * into shapes the rest of the script does not read. Unknown keys are kept as
    92	 * strings and passed through to the manifest.
    93	 */
    94	function parseFrontmatter(text) {
    95	  if (!text.startsWith('---')) throw new Error('post_ja.md must open with a --- frontmatter block');
    96	  const end = text.indexOf('\n---', 3);
    97	  if (end === -1) throw new Error('post_ja.md frontmatter is not closed with ---');
    98	  const head = text.slice(3, end).split('\n');
    99	  const body = text.slice(text.indexOf('\n', end + 1) + 1);
   100	
   101	  const data = {};
   102	  let listKey = null;
   103	  for (const raw of head) {
   104	    const line = raw.replace(/\s+$/, '');
   105	    if (!line.trim() || line.trim().startsWith('#')) continue;
   106	    const item = line.match(/^\s*-\s+(.*)$/);
   107	    if (item && listKey) { data[listKey].push(unquote(item[1])); continue; }
   108	    const kv = line.match(/^([A-Za-z_][\w-]*):\s*(.*)$/);
   109	    if (!kv) throw new Error(`frontmatter line not understood: ${line}`);
   110	    const [, key, value] = kv;
   111	    if (value === '') { listKey = key; data[key] = []; } else { listKey = null; data[key] = unquote(value); }
   112	  }
   113	  return { data, body };
   114	}
   115	const unquote = (s) => s.replace(/^["'](.*)["']$/, '$1').trim();
   116	
   117	const postPath = path.join(epDir, 'post_ja.md');
   118	if (!fs.existsSync(postPath)) {
   119	  console.error(`missing ${path.relative(REPO, postPath)} — write the body first (see scripts/content/README.md)`);
   120	  process.exit(2);
   121	}
   122	const { data: fm, body } = parseFrontmatter(fs.readFileSync(postPath, 'utf8'));
   123	
   124	const warnings = [];
   125	for (const key of ['title', 'hook', 'cta']) {
   126	  if (!fm[key]) throw new Error(`post_ja.md frontmatter is missing "${key}"`);
   127	}
   128	if (!Array.isArray(fm.bullets) || fm.bullets.length !== 3) {
   129	  throw new Error(`post_ja.md needs exactly 3 bullets (got ${Array.isArray(fm.bullets) ? fm.bullets.length : 'none'})`);
   130	}
   131	const captions = Array.isArray(fm.captions) ? fm.captions : [];
   132	if (topic.track === 'A' && captions.length !== 3 && !noDemo) {
   133	  warnings.push('captions: track A wants 3 caption lines for the demo; falling back to generic ones');
   134	}
   135	
   136	/* ── content rules the strategy forbids breaking ──────────────────────────── */
   137	/* Checked here rather than left to review because these are the rules a draft
   138	 * written in a hurry breaks, and the whole body is in front of us. They are
   139	 * reported, not auto-corrected: rewriting someone's sentence to satisfy a
   140	 * regex produces copy nobody chose.
   141	 */
   142	const FORBIDDEN = [
   143	  { re: /タイムズカー/, why: 'incident name — the strategy forbids naming it' },
   144	  { re: /絶対/, why: '「絶対」 is forbidden; use 原則 / リスクを下げる' },
   145	  { re: /唯一/, why: '「唯一」 is forbidden' },
   146	  { re: /必ず安全/, why: '「必ず安全」 is forbidden' },
   147	  { re: /防ぎます|防げます/, why: '「防ぐ」 is forbidden; use リスクを下げる' },
   148	  { re: /一括(処理|ダウンロード)/, why: 'batch processing has not shipped — do not advertise it' }
   149	];
   150	const MUST_LINE = '提出先の指示を必ず確認してください';
   151	const fullText = [fm.title, fm.hook, fm.cta, ...fm.bullets, ...captions, body].join('\n');
   152	const violations = FORBIDDEN.filter((f) => f.re.test(fullText)).map((f) => `${f.re.source} — ${f.why}`);
   153	if (!body.includes(MUST_LINE)) violations.push(`body is missing the required line 「${MUST_LINE}」`);
   154	if (violations.length) {
   155	  console.error(`\nep${EP}: content rules violated — nothing was written:\n`);
   156	  violations.forEach((v) => console.error('  - ' + v));
   157	  process.exit(1);
   158	}
   159	
   160	const enPath = path.join(epDir, 'post_en.md');
   161	if (!fs.existsSync(enPath)) warnings.push('post_en.md is absent — write the English version by hand (it is not generated)');
   162	
   163	/* ── x_thread.md ──────────────────────────────────────────────────────────── */
   164	/* Five tweets: hook, three bullets, CTA + the UTM URL.
   165	 *
   166	 * Over-length tweets are REPORTED, never truncated. Truncating marketing copy
   167	 * at a byte boundary produces a sentence the author did not write, and the
   168	 * damage is invisible once it is posted; a count next to each line makes the
   169	 * problem obvious before it is.
   170	 */
   171	const tweets = [
   172	  `${fm.hook}\n\n${fm.title}`,
   173	  `①${fm.bullets[0]}`,
   174	  `②${fm.bullets[1]}`,
   175	  `③${fm.bullets[2]}`,
   176	  `${fm.cta}\n${utmUrl}`
   177	];
   178	const over = tweets.map((t, i) => ({ i: i + 1, len: [...t].length })).filter((t) => t.len > TWEET_LIMIT);
   179	if (over.length) warnings.push(`x_thread: tweet(s) ${over.map((o) => `${o.i} (${o.len}字)`).join(', ')} exceed ${TWEET_LIMIT}字 — shorten by hand`);
   180	
   180	
   181	const threadMd = [
   182	  `<!-- generated by scripts/content/make_episode.mjs — ep${EPP}. Edit post_ja.md and re-run. -->`,
   183	  `# X thread — ep${EPP}`,
   184	  '',
   185	  `> ${topic.title_ja}`,
   186	  `> landing: ${utmUrl}`,
   187	  '',
   188	  ...tweets.flatMap((t, i) => {
   189	    const len = [...t].length;
   190	    const flag = len > TWEET_LIMIT ? `  ⚠ OVER ${TWEET_LIMIT}字` : '';
   191	    return [`## ${i + 1} / ${tweets.length}  (${len}字)${flag}`, '', '```', t, '```', ''];
   192	  })
   193	].join('\n');
   194	fs.writeFileSync(path.join(epDir, 'x_thread.md'), threadMd);
   195	
   196	/* ── playwright ───────────────────────────────────────────────────────────── */
   197	async function loadPlaywright() {
   198	  // Playwright is a CommonJS package, so a dynamic import of its entry file
   199	  // lands the exports under `.default` rather than as named exports. Reading
   200	  // `chromium` off the namespace gives `undefined` and the failure surfaces
   201	  // thirty lines later as "cannot read properties of undefined" — measured.
   202	  const pick = (mod) => (mod && mod.chromium) ? mod : (mod && mod.default) || {};
   203	
   204	  try {
   205	    const mod = pick(await import('playwright'));
   206	    if (mod.chromium) return mod;
   207	  } catch { /* not installed at this level — fall through */ }
   208	
   209	  // The golden harness owns the install (test/safe/node_modules); this script
   210	  // borrows it rather than adding a second copy that can drift in version.
   211	  const local = path.join(REPO, 'test', 'safe', 'node_modules', 'playwright', 'index.js');
   212	  if (fs.existsSync(local)) {
   213	    const mod = pick(await import(pathToFileURL(local).href));
   214	    if (mod.chromium) return mod;
   215	  }
   216	  throw new Error('playwright not found. Install it where the golden harness lives:\n'
   217	    + '  cd test/safe && npm i && npx playwright install chrome');
   218	}
   219	const { chromium } = await loadPlaywright();
   220	const browser = await chromium.launch({ channel: 'chrome' });
   221	
   222	/* ── carousel ─────────────────────────────────────────────────────────────── */
   223	const carousel = [];
   224	{
   225	  const page = await browser.newPage({ viewport: { width: 1080, height: 1350 }, deviceScaleFactor: 1 });
   226	  await page.goto(pathToFileURL(TEMPLATE).href);
   227	  // Let the webfonts land, but do not hang on them: an offline build should
   228	  // produce a slide in Hiragino rather than no slide at all.
   229	  await Promise.race([page.evaluate(() => document.fonts.ready), page.waitForTimeout(6000)]);
   230	
   231	  const slideData = { ep: EP, track: topic.track, title: fm.title, hook: fm.hook, bullets: fm.bullets, cta: fm.cta, url: utmUrl };
   232	  for (const n of [1, 2, 3]) {
   233	    const fit = await page.evaluate(([slide, d]) => window.SF_RENDER(slide, d), [n, slideData]);
   234	    if (fit.overflowed) warnings.push(`carousel_${n}: text still overflows at the ${Math.round(fit.scale * 100)}% floor — shorten the copy`);
   235	    else if (fit.scale < 1) warnings.push(`carousel_${n}: text was shrunk to ${Math.round(fit.scale * 100)}% to fit`);
   236	    const file = path.join(epDir, `carousel_${n}.png`);
   237	    await page.locator('#card').screenshot({ path: file });
   238	    carousel.push(file);
   239	    process.stdout.write(`  carousel_${n}.png  (fit ${Math.round(fit.scale * 100)}%)\n`);
   240	  }
   241	  await page.close();
   242	}
   243	
   244	/* ── demo recording (track A only) ────────────────────────────────────────── */
   245	const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json', '.txt': 'text/plain', '.pdf': 'application/pdf' };
   246	
   247	// Same shape as the golden harness's server: public/ at the root, the fixture
   248	// tree under /__fx/. Local only — the recording must never touch production.
   249	function startServer() {
   250	  return new Promise((resolve) => {
   251	    const srv = http.createServer((req, res) => {
   252	      let p = decodeURIComponent(req.url.split('?')[0]);
   253	      if (p === '/') p = '/index.html';
   254	      const root = p.startsWith('/__fx/') ? FIXTURES : PUBLIC;
   255	      if (p.startsWith('/__fx/')) p = p.slice(5);
   256	      let fp = path.join(root, p);
   257	      // Serve <dir>/index.html for a directory request. The real app relies on
   258	      // ActionDispatch::Static doing exactly this for /safe/, so a server that
   259	      // 404s here records a demo of an error page — which is what the first run
   260	      // of this script actually produced.
   261	      if (fp.startsWith(root) && fs.existsSync(fp) && fs.statSync(fp).isDirectory()) fp = path.join(fp, 'index.html');
   262	      if (!fp.startsWith(root) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end('nf'); return; }
   263	      res.writeHead(200, { 'content-type': MIME[path.extname(fp)] || 'application/octet-stream' });
   264	      fs.createReadStream(fp).pipe(res);
   265	    });
   266	    srv.listen(0, '127.0.0.1', () => resolve(srv));
   267	  });
   268	}
   269	
   270	let demo = 'skipped: track B has no tool demo';
   271	if (noDemo) demo = 'skipped: --no-demo';
   272	else if (topic.track !== 'A') demo = 'skipped: track B has no tool demo';
   273	else if (!FIXTURE_FOR_DOC[topic.doc]) demo = `failed: no dummy document exists for doc="${topic.doc}" (only ${Object.keys(FIXTURE_FOR_DOC).join(', ')} have fixtures)`;
   274	else {
   275	  let srv;
   276	  const frameDir = path.join(epDir, '.frames');
   277	  try {
   278	    fs.rmSync(frameDir, { recursive: true, force: true });
   279	    fs.mkdirSync(frameDir, { recursive: true });
   280	    srv = await startServer();
   281	    const port = srv.address().port;
   282	    const page = await browser.newPage({ viewport: { width: 720, height: 1280 }, deviceScaleFactor: 1 });
   283	
   284	    let frame = 0;
   285	    const MAX_FRAMES = 40;
   286	    /* 0.5s interval, <= 40 frames — but captured in PHASES rather than as one
   287	     * continuous 20s window. OCR on a photographed card takes tens of seconds,
   288	     * so a single timed run would spend every frame on a progress bar and the
   289	     * finished GIF would show no document at all. Each phase takes its own
   290	     * frames once that step is actually on screen.
   291	     */
   292	    const shoot = async (n) => {
   293	      for (let i = 0; i < n && frame < MAX_FRAMES; i++) {
   294	        await page.screenshot({ path: path.join(frameDir, `f${String(frame).padStart(3, '0')}.png`) });
   295	        frame++;
   296	        if (i < n - 1) await page.waitForTimeout(500);
   297	      }
   298	    };
   299	
   300	    const toolUrl = `http://127.0.0.1:${port}/safe/?lang=ja&purpose=${topic.purpose}&from=direct`;
   301	    const resp = await page.goto(toolUrl, { waitUntil: 'load' });
   302	    // Fail here, with the status, rather than thirty seconds later on a missing
   303	    // selector. The first run of this script 404'd on /safe/ and reported
   304	    // "waiting for locator('#fileInput')" — true, and useless.
   305	    if (!resp || !resp.ok()) throw new Error(`${toolUrl} returned ${resp ? resp.status() : 'no response'}`);
   306	    if (!(await page.locator('#fileInput').count())) throw new Error(`${toolUrl} loaded but has no #fileInput — wrong document?`);
   307	
   308	    // Caption bar, injected into the page so the frames already carry the text.
   309	    // Drawing it afterwards with ffmpeg means shipping a Japanese font path and
   310	    // a second place for the wording to live.
   311	    const caps = captions.length === 3 ? captions : [
   312	      '① PDF・写真をドラッグ',
   313	      `② 「提出目的：${topic.purpose}」を選ぶ`,
   314	      '③ ダウンロード — 黒塗りの下に原文は残りません'
   315	    ];
   316	    await page.evaluate(() => {
   317	      const bar = document.createElement('div');
   318	      bar.id = '__cap';
   319	      bar.style.cssText = 'position:fixed;left:0;right:0;bottom:0;z-index:9999;background:rgba(23,20,15,.92);'
   320	        + 'color:#fff;font:500 19px/1.6 "Hiragino Kaku Gothic ProN","Noto Sans JP",sans-serif;'
   321	        + 'padding:16px 20px;white-space:pre-line;min-height:96px';
   322	      document.body.appendChild(bar);
   323	      window.__cap = (lines) => { bar.textContent = lines.join('\n'); };
   324	    });
   325	    const setCap = (upto) => page.evaluate((l) => window.__cap(l), caps.slice(0, upto));
   326	
   327	    await setCap(1);
   328	    await shoot(4);
   329	
   330	    await page.setInputFiles('#fileInput', path.join(FIXTURES, FIXTURE_FOR_DOC[topic.doc]));
   331	    // #docWrap becoming visible is afterLoad()'s last step — `pages.length > 0`
   332	    // goes true while a later page is still inside Tesseract.
   333	    await page.waitForFunction(
   334	      () => Array.isArray(pages) && pages.length > 0 && document.getElementById('docWrap').style.display === 'flex',
   335	      { timeout: 300000 }
   336	    );
   337	    await page.waitForTimeout(700);
   338	    await setCap(2);
   339	    await shoot(10);
   340	
   341	    await page.locator('#jpBar').scrollIntoViewIfNeeded().catch(() => {});
   342	    await shoot(6);
   343	
   344	    await page.click('#btnMake');
   345	    await page.waitForFunction(() => document.getElementById('result').style.display === 'block', { timeout: 120000 });
   346	    await setCap(3);
   347	    await page.locator('#result').scrollIntoViewIfNeeded().catch(() => {});
   348	    await page.waitForTimeout(500);
   349	    await shoot(MAX_FRAMES - frame);
   350	
   351	    await page.close();
   352	
   353	    if (frame < 6) throw new Error(`only ${frame} frames captured`);
   354	
   355	    const gif = path.join(epDir, 'demo.gif');
   356	    const mp4 = path.join(epDir, 'demo.mp4');
   357	    const pattern = path.join(frameDir, 'f%03d.png');
   358	    // Two-pass palette: a 256-colour global palette picked from the actual
   359	    // frames. The single-pass default dithers the black bars into speckle,
   360	    // which on a redaction demo reads as "the bar is see-through".
   361	    const palette = path.join(frameDir, 'palette.png');
   362	    run('ffmpeg', ['-y', '-framerate', '2', '-i', pattern, '-vf', 'palettegen=stats_mode=diff', palette]);
   363	    run('ffmpeg', ['-y', '-framerate', '2', '-i', pattern, '-i', palette,
   364	      '-lavfi', 'paletteuse=dither=bayer:bayer_scale=3', '-loop', '0', gif]);
   365	    let mp4ok = true;
   366	    try {
   367	      run('ffmpeg', ['-y', '-framerate', '2', '-i', pattern, '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
   368	        '-vf', 'scale=720:-2:flags=lanczos,pad=ceil(iw/2)*2:ceil(ih/2)*2', mp4]);
   369	    } catch (e) { mp4ok = false; warnings.push(`demo.mp4: ${e.message}`); }
   370	
   371	    const kb = (f) => Math.round(fs.statSync(f).size / 1024);
   372	    demo = `ok: ${frame} frames, demo.gif ${kb(gif)}KB${mp4ok ? `, demo.mp4 ${kb(mp4)}KB` : ', mp4 failed'}`;
   373	    process.stdout.write(`  demo.gif  (${frame} frames, ${kb(gif)}KB)\n`);
   374	    fs.rmSync(frameDir, { recursive: true, force: true });
   375	  } catch (e) {
   376	    demo = `failed: ${e.message}`;
   377	    warnings.push(`demo: ${e.message}`);
   378	    // Frames are left behind on failure — they are the only evidence of how far
   379	    // the recording got, and deleting them deletes the diagnosis.
   380	    process.stdout.write(`  demo FAILED: ${e.message}\n`);
   381	  } finally {
   382	    if (srv) srv.close();
   383	  }
   384	}
   385	
   386	await browser.close();
   387	
   388	/* ── manifest ─────────────────────────────────────────────────────────────── */
   389	const fileEntry = (name) => {
   390	  const f = path.join(epDir, name);
   391	  return fs.existsSync(f) ? { name, bytes: fs.statSync(f).size } : null;
   392	};
   393	const manifest = {
   394	  ep: EP,
   395	  week: topic.week,
   396	  track: topic.track,
   397	  title_ja: fm.title,
   398	  title_en: topic.title_en,
   399	  doc: topic.doc,
   400	  purpose: topic.purpose,
   401	  landing,
   402	  utm_url: utmUrl,
   403	  generated_by: 'scripts/content/make_episode.mjs',
   404	  files: ['post_ja.md', 'post_en.md', 'x_thread.md', 'carousel_1.png', 'carousel_2.png', 'carousel_3.png', 'demo.gif', 'demo.mp4']
   405	    .map(fileEntry).filter(Boolean),
   406	  demo,
   407	  warnings,
   408	  // Publishing checklist. Justin ticks these by hand after posting, then sets
   409	  // topics.json status to "posted". They start false — a checklist that
   410	  // defaults to done is not a checklist.
   411	  posted: { x: false, youtube_shorts: false, instagram: false, blog: false }
   412	};
   413	fs.writeFileSync(path.join(epDir, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
   414	
   415	process.stdout.write(`\nep${EPP} built in ${path.relative(REPO, epDir)}\n`);
   416	process.stdout.write(`  demo: ${demo}\n`);
   417	if (warnings.length) {
   418	  process.stdout.write('\nwarnings:\n');
   419	  warnings.forEach((w) => process.stdout.write('  - ' + w + '\n'));
   420	}
   421	
   422	function run(bin, args) {
   423	  const r = spawnSync(bin, args, { encoding: 'utf8' });
   424	  if (r.error) throw new Error(`${bin} not available: ${r.error.message}`);
   425	  if (r.status !== 0) throw new Error(`${bin} exited ${r.status}: ${(r.stderr || '').split('\n').slice(-4).join(' ')}`);
   426	}
     1	<!DOCTYPE html>
     2	<html lang="ja">
     3	<head>
     4	<meta charset="UTF-8">
     5	<title>SafeFile JP carousel slide</title>
     6	<!--
     7	  Instagram / X carousel slide, 1080×1350.
     8	
     9	  Rendered by scripts/content/make_episode.mjs: Playwright opens this file,
    10	  calls window.SF_RENDER(slide, data), waits for window.SF_READY, and
    11	  screenshots #card. Nothing here runs in production.
    12	
    13	  Tokens are /safe/'s (public/safe/index.html :root) so a slide and the tool
    14	  look like the same product. Fonts: IBM Plex Sans KR for the Latin/Hangul
    15	  shapes the brand uses, Noto Sans JP for the Japanese body — loaded from
    16	  Google Fonts and allowed to FAIL: the renderer waits for document.fonts.ready
    17	  with a timeout and falls back to Hiragino, because an offline build that
    18	  silently produced a blank slide would be worse than one with a system font.
    19	-->
    20	<link rel="preconnect" href="https://fonts.googleapis.com">
    21	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    22	<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+KR:wght@400;500;700&family=Noto+Sans+JP:wght@400;500;700&display=swap" rel="stylesheet">
    23	<style>
    24	:root{
    25	  --paper:#F7F5EF; --card:#FFFFFF; --ink:#17140F; --sub:#6B655A;
    26	  --line:#E6E1D4; --marker:#FFE066; --marker-soft:#FFF3BF;
    27	}
    28	*{margin:0;padding:0;box-sizing:border-box}
    29	html,body{background:#DDD8CC}
    30	body{display:flex;align-items:flex-start;justify-content:flex-start}
    31	#card{
    32	  width:1080px;height:1350px;background:var(--paper);color:var(--ink);
    33	  font-family:'Noto Sans JP','IBM Plex Sans KR','Hiragino Kaku Gothic ProN',sans-serif;
    34	  display:flex;flex-direction:column;padding:88px 88px 76px;position:relative;overflow:hidden;
    35	}
    36	/* Brand lockup — same bar-and-wordmark as the site header. */
    37	.brand{display:flex;align-items:center;gap:16px;font-family:'IBM Plex Sans KR',sans-serif;font-weight:700;font-size:38px;letter-spacing:-.02em}
    38	.brand .bar{width:52px;height:26px;background:var(--ink);border-radius:7px}
    39	.brand .sep{width:2px;height:34px;background:var(--line)}
    40	.brand .slim{color:var(--sub);font-weight:500}
    41	
    42	.ep{margin-top:14px;font-family:'IBM Plex Sans KR',sans-serif;font-size:26px;font-weight:500;color:var(--sub);letter-spacing:.04em;text-transform:uppercase}
    43	
    44	#fit{flex:1;display:flex;flex-direction:column;justify-content:center;min-height:0;padding:36px 0}
    45	
    46	h1{font-size:76px;font-weight:700;line-height:1.3;letter-spacing:-.02em}
    47	.hook{margin-top:40px;font-size:40px;line-height:1.65;color:var(--ink)}
    48	.hook .hl{background:linear-gradient(transparent 58%, var(--marker) 58%);padding:0 4px}
    49	
    50	ol.bul{list-style:none;display:flex;flex-direction:column;gap:40px}
    51	ol.bul li{display:flex;gap:28px;align-items:flex-start;font-size:42px;line-height:1.55}
    52	ol.bul .n{flex:0 0 auto;width:62px;height:62px;border-radius:16px;background:var(--ink);color:#fff;
    53	  font-family:'IBM Plex Sans KR',sans-serif;font-weight:700;font-size:34px;
    54	  display:flex;align-items:center;justify-content:center}
    55	
    56	.cta-h{font-size:66px;font-weight:700;line-height:1.35;letter-spacing:-.02em}
    57	.cta-body{margin-top:34px;font-size:38px;line-height:1.6;color:var(--sub)}
    58	.url{margin-top:52px;background:var(--card);border:2px solid var(--line);border-radius:22px;
    59	  padding:34px 38px;font-family:'IBM Plex Sans KR',sans-serif;font-size:32px;word-break:break-all;line-height:1.5}
    60	.url .lbl{display:block;font-size:24px;color:var(--sub);margin-bottom:12px;letter-spacing:.04em;text-transform:uppercase}
    61	
    62	/* The compliance line is not decoration — every how-to must carry it, so it
    63	   is part of the slide chrome rather than something the body text can drop. */
    64	.foot{border-top:2px solid var(--line);padding-top:30px;font-size:28px;line-height:1.55;color:var(--sub)}
    65	.foot .must{color:var(--ink);font-weight:500}
    66	.page{position:absolute;right:88px;bottom:76px;font-family:'IBM Plex Sans KR',sans-serif;font-size:28px;color:var(--sub)}
    67	</style>
    68	</head>
    69	<body>
    70	<div id="card">
    71	  <div class="brand">
    72	    <span class="bar"></span>SafeFile<span class="sep"></span><span class="slim">SlimFile</span>
    73	  </div>
    74	  <div class="ep" id="epLabel"></div>
    75	  <div id="fit"></div>
    76	  <div class="foot">
    77	    <span class="must" id="mustLine">提出先の指示を必ず確認してください。</span>
    78	    <span id="footNote"></span>
    79	  </div>
    80	  <div class="page" id="pageNo"></div>
    81	</div>
    82	<script>
    83	window.SF_READY = false;
    84	
    85	/* Shrink to fit rather than clip.
    86	 *
    87	 * A slide is a fixed 1080×1350 and the copy is written by a human, so overflow
    88	 * is not an edge case — it is the normal state for a long Japanese title. The
    89	 * alternative (overflow:hidden) loses the end of a sentence while still
    90	 * looking like a finished image, which is the failure mode that ships.
    91	 *
    92	 * Steps down in 2% increments to a floor of 52%; below that the text would be
    93	 * unreadable on a phone and the right fix is shorter copy, so it reports.
    94	 */
    95	function fitToBox(el, min = 0.52) {
    96	  const base = 1;
    97	  let scale = base;
    98	  el.style.setProperty('--fit', '1');
    99	  const fits = () => el.scrollHeight <= el.clientHeight + 1;
   100	  while (!fits() && scale > min) {
   101	    scale = Math.round((scale - 0.02) * 100) / 100;
   102	    el.querySelectorAll('h1,.hook,ol.bul li,.cta-h,.cta-body,.url').forEach((n) => {
   103	      if (!n.dataset.basePx) n.dataset.basePx = String(parseFloat(getComputedStyle(n).fontSize));
   104	      n.style.fontSize = (parseFloat(n.dataset.basePx) * scale) + 'px';
   105	    });
   106	  }
   107	  return { scale, overflowed: !fits() };
   108	}
   109	
   110	function esc(s) {
   111	  return String(s == null ? '' : s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
   112	}
   113	
   114	window.SF_RENDER = function (slide, d) {
   115	  document.getElementById('epLabel').textContent = `EP${String(d.ep).padStart(2, '0')} · ${d.track === 'A' ? 'HOW-TO' : 'EXPLAINER'}`;
   116	  document.getElementById('pageNo').textContent = `${slide} / 3`;
   117	  const fit = document.getElementById('fit');
   118	
   119	  if (slide === 1) {
   120	    fit.innerHTML = `<h1>${esc(d.title)}</h1><p class="hook"><span class="hl">${esc(d.hook)}</span></p>`;
   121	    document.getElementById('footNote').textContent = '';
   122	  } else if (slide === 2) {
   123	    fit.innerHTML = '<ol class="bul">' + (d.bullets || []).map((b, i) =>
   124	      `<li><span class="n">${i + 1}</span><span>${esc(b)}</span></li>`).join('') + '</ol>';
   125	    document.getElementById('footNote').textContent = '';
   126	  } else {
   127	    fit.innerHTML = `<p class="cta-h">${esc(d.cta)}</p>`
   128	      + `<p class="cta-body">ブラウザ内で処理され、ファイルはサーバーに送信されません。登録不要・無料。</p>`
   129	      + `<div class="url"><span class="lbl">試す</span>${esc(d.url)}</div>`;
   130	    document.getElementById('footNote').textContent = '';
   131	  }
   132	
   133	  const r = fitToBox(fit);
   134	  window.SF_FIT = r;
   135	  window.SF_READY = true;
   136	  return r;
   137	};
   138	</script>
   139	</body>
   140	</html>

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "jq -r '.episodes[] | [.ep,.week,.track,.src,.title_ja,(.rewritten//false),(.blocked_until//\"\")] | @tsv' content/jp/topics.json; sed -n '130,180p' scripts/content/make_episode.mjs | nl -ba -v130; sed -n '250,285p' content/jp/topics.json | nl -ba -v250; identify content/jp/ep0{1,2,3}/carousel_*.png docs/jp/s7_samples/* 2>/dev/null || file content/jp/ep0{1,2,3}/carousel_*.png docs/jp/s7_samples/*; git diff --no-index -- content/jp/ep01/carousel_1.png docs/jp/s7_samples/ep01_carousel_1.png >/dev/null; echo \"ep01 sample diff="'$?"; git diff --no-index -- content/jp/ep02/carousel_1.png docs/jp/s7_samples/ep02_carousel_1.png >/dev/null; echo "ep02 sample diff=$?"; git diff --no-index -- content/jp/ep03/carousel_1.png docs/jp/s7_samples/ep03_carousel_1.png >/dev/null; echo "ep03 sample diff=$?"' in /Users/sunghoon/Projects/docpack
 succeeded in 125ms:
content/jp/ep01/carousel_1.png PNG 1080x1350 1080x1350+0+0 8-bit sRGB 110833B 0.000u 0:00.001
content/jp/ep01/carousel_2.png PNG 1080x1350 1080x1350+0+0 8-bit sRGB 118822B 0.000u 0:00.000
content/jp/ep01/carousel_3.png PNG 1080x1350 1080x1350+0+0 8-bit sRGB 106315B 0.000u 0:00.000
content/jp/ep02/carousel_1.png PNG 1080x1350 1080x1350+0+0 8-bit sRGB 100989B 0.000u 0:00.000
content/jp/ep02/carousel_2.png PNG 1080x1350 1080x1350+0+0 8-bit sRGB 120257B 0.000u 0:00.000
content/jp/ep02/carousel_3.png PNG 1080x1350 1080x1350+0+0 8-bit sRGB 114725B 0.000u 0:00.000
content/jp/ep03/carousel_1.png PNG 1080x1350 1080x1350+0+0 8-bit sRGB 101497B 0.000u 0:00.000
content/jp/ep03/carousel_2.png PNG 1080x1350 1080x1350+0+0 8-bit sRGB 121179B 0.000u 0:00.000
content/jp/ep03/carousel_3.png PNG 1080x1350 1080x1350+0+0 8-bit sRGB 109116B 0.000u 0:00.000
docs/jp/s7_samples/ep01_carousel_1.png PNG 1080x1350 1080x1350+0+0 8-bit sRGB 110833B 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[0] GIF 720x1280 720x1280+0+0 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[1] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[2] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[3] GIF 179x42 720x1280+256+104 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[4] GIF 680x1176 720x1280+20+104 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[5] GIF 141x44 720x1280+276+104 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[6] GIF 417x44 720x1280+151+104 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[7] GIF 138x43 720x1280+276+104 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[8] GIF 138x42 720x1280+276+104 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[9] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[10] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[11] GIF 138x42 720x1280+276+104 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[12] GIF 76x42 720x1280+336+104 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[13] GIF 417x42 720x1280+151+104 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[14] GIF 130x42 720x1280+274+104 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[15] GIF 143x42 720x1280+274+104 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[16] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.001
docs/jp/s7_samples/ep01_demo.gif[17] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[18] GIF 143x42 720x1280+274+104 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[19] GIF 121x42 720x1280+296+104 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[20] GIF 720x1223 720x1280+0+57 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[21] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[22] GIF 190x46 720x1280+265+1212 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[23] GIF 190x45 720x1280+265+1213 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[24] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[25] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[26] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[27] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[28] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[29] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[30] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[31] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[32] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[33] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[34] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[35] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[36] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[37] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[38] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 0.000u 0:00.000
docs/jp/s7_samples/ep01_demo.gif[39] GIF 1x1 720x1280+719+1279 8-bit sRGB 256c 408749B 0.000u 0:00.000
docs/jp/s7_samples/ep02_carousel_1.png PNG 1080x1350 1080x1350+0+0 8-bit sRGB 100989B 0.000u 0:00.000
docs/jp/s7_samples/ep03_carousel_1.png PNG 1080x1350 1080x1350+0+0 8-bit sRGB 101497B 0.000u 0:00.000
ep01 sample diff=0
ep02 sample diff=0
ep03 sample diff=0

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc "jq '.files,.demo,.warnings' content/jp/ep0{1,2,3}/manifest.json; rg -n \"FIXTURE_FOR_DOC|shikaku\" scripts/content/make_episode.mjs; file test/safe/fixtures/* 2>/dev/null | head -40; rg -n \"multiple|複数|fileInput\" public/safe/index.html | head -40; rg -n \"DIRS|filesystem|glob|safe/jp\" test/lib/canonical_path_redirect_test.rb script/canonical_sweep.rb; nl -ba test/lib/canonical_path_redirect_test.rb" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
[
  {
    "name": "post_ja.md",
    "bytes": 3802
  },
  {
    "name": "post_en.md",
    "bytes": 3073
  },
  {
    "name": "x_thread.md",
    "bytes": 1093
  },
  {
    "name": "carousel_1.png",
    "bytes": 110833
  },
  {
    "name": "carousel_2.png",
    "bytes": 118822
  },
  {
    "name": "carousel_3.png",
    "bytes": 106315
  },
  {
    "name": "demo.gif",
    "bytes": 400129
  },
  {
    "name": "demo.mp4",
    "bytes": 223914
  }
]
"ok: 40 frames, demo.gif 391KB, demo.mp4 219KB"
[]
[
  {
    "name": "post_ja.md",
    "bytes": 3331
  },
  {
    "name": "post_en.md",
    "bytes": 2920
  },
  {
    "name": "x_thread.md",
    "bytes": 1060
  },
  {
    "name": "carousel_1.png",
    "bytes": 100989
  },
  {
    "name": "carousel_2.png",
    "bytes": 120257
  },
  {
    "name": "carousel_3.png",
    "bytes": 114725
  }
]
"skipped: track B has no tool demo"
[]
[
  {
    "name": "post_ja.md",
    "bytes": 3441
  },
  {
    "name": "post_en.md",
    "bytes": 2895
  },
  {
    "name": "x_thread.md",
    "bytes": 1040
  },
  {
    "name": "carousel_1.png",
    "bytes": 101497
  },
  {
    "name": "carousel_2.png",
    "bytes": 121179
  },
  {
    "name": "carousel_3.png",
    "bytes": 109116
  }
]
"failed: no dummy document exists for doc=\"契約書\" (only shikaku_kakuninsho, unten_menkyo, mynumber_card, juminhyo have fixtures)"
[]
45:const FIXTURE_FOR_DOC = {
46:  shikaku_kakuninsho: 'jp/shikaku_kakuninsho/kenpo.jpg',
273:else if (!FIXTURE_FOR_DOC[topic.doc]) demo = `failed: no dummy document exists for doc="${topic.doc}" (only ${Object.keys(FIXTURE_FOR_DOC).join(', ')} have fixtures)`;
330:    await page.setInputFiles('#fileInput', path.join(FIXTURES, FIXTURE_FOR_DOC[topic.doc]));
test/safe/fixtures/jp: directory
390:        <input type="file" id="fileInput" accept=".pdf,.docx,.txt,.md,.csv,image/*,.heic,.heif,.webp" hidden>
2348:const dz=$('dropzone'), fi=$('fileInput');
2661:// wrapped address (multiple boxes) is covered cleanly and the partial value is
script/canonical_sweep.rb:88:# Must mirror CanonicalPathRedirect::DIRS. Every directory under public/ with an
script/canonical_sweep.rb:95:# /safe/jp itself is deliberately absent: public/safe/jp/ has no index.html, so
script/canonical_sweep.rb:96:# /safe/jp is a 404 and /safe/jp/ 301s onto that 404. That is the honest answer
script/canonical_sweep.rb:99:STATIC_DIRS = %w[/safe /privacy /safe/jp/nyusatsu /safe/jp/honnin-kakunin /safe/jp/ai-mae]
script/canonical_sweep.rb:109:STATIC_DIRS.each do |d|
script/canonical_sweep.rb:113:               /safe/jp/jp.css /safe/jp/jp.css/ /safe/jp//jp.css
script/canonical_sweep.rb:114:               /safe/jp/jp.js /safe/jp/jp.js/ /safe/jp//jp.js]
script/canonical_sweep.rb:150:allowed_200 = (STATIC_DIRS.map { |d| "#{d}/" } + ROUTED + SLUGS + %w[/safe/sw.js /safe/jp/jp.css /safe/jp/jp.js]).uniq
test/lib/canonical_path_redirect_test.rb:213:  test "DIRS names every directory under public with an index.html" do
test/lib/canonical_path_redirect_test.rb:216:    # that put /safe/ into Search Console. Derive the truth from the filesystem
test/lib/canonical_path_redirect_test.rb:218:    on_disk = Dir.glob(Rails.root.join("public", "**", "index.html"))
test/lib/canonical_path_redirect_test.rb:223:    assert_equal on_disk, CanonicalPathRedirect::DIRS.sort,
test/lib/canonical_path_redirect_test.rb:224:                 "CanonicalPathRedirect::DIRS is out of step with public/**/index.html"
test/lib/canonical_path_redirect_test.rb:228:    %w[/safe/jp/nyusatsu /safe/jp/honnin-kakunin /safe/jp/ai-mae].each do |dir|
test/lib/canonical_path_redirect_test.rb:238:        "/safe/jp//#{File.basename(dir)}/" => "#{dir}/"
test/lib/canonical_path_redirect_test.rb:254:    assert_equal 200, call("/safe/jp/jp.css").first
test/lib/canonical_path_redirect_test.rb:255:    assert_equal 200, call("/safe/jp/jp.js").first
test/lib/canonical_path_redirect_test.rb:258:  test "/safe/jp itself is not a page" do
test/lib/canonical_path_redirect_test.rb:259:    # public/safe/jp/ holds no index.html, so it must NOT be in DIRS: making it
test/lib/canonical_path_redirect_test.rb:263:    _, headers, = call("/safe/jp/")
test/lib/canonical_path_redirect_test.rb:264:    assert_equal "/safe/jp", headers["location"]
test/lib/canonical_path_redirect_test.rb:265:    assert_not_includes CanonicalPathRedirect::DIRS, "/safe/jp"
     1	# frozen_string_literal: true
     2	
     3	require "test_helper"
     4	require Rails.root.join("lib", "canonical_path_redirect").to_s
     5	
     6	# Unit tests for the redirect middleware, driven with a hand-built Rack env.
     7	#
     8	# Why not drive these through ActionDispatch::IntegrationTest: that stack parses
     9	# and percent-encodes the URI before the middleware runs, so `<`, `>`, `"` and
    10	# CR/LF arrive already neutralised and the assertions would pass vacuously.
    11	# Puma does the same in production — it answers 400 to a request line carrying
    12	# those bytes. That is precisely the dependency these tests exist to remove: the
    13	# escaping has to be a property of this file, not of whatever parser happens to
    14	# sit in front of it. Handing the middleware a raw env is the only altitude at
    15	# which that can actually be asserted.
    16	class CanonicalPathRedirectTest < ActiveSupport::TestCase
    17	  # Inner app stands in for ActionDispatch::Static; a 200 means "passed through".
    18	  PASSTHROUGH = ->(env) { [200, { "content-type" => "text/html" }, ["STATIC:#{env["PATH_INFO"]}"]] }
    19	
    20	  def call(path, method: "GET", query: "", script_name: "")
    21	    CanonicalPathRedirect.new(PASSTHROUGH).call(
    22	      "PATH_INFO" => path,
    23	      "REQUEST_METHOD" => method,
    24	      "QUERY_STRING" => query,
    25	      "SCRIPT_NAME" => script_name
    26	    )
    27	  end
    28	
    29	  # ── redirect targets ────────────────────────────────────────────────────
    30	
    31	  test "duplicate spellings redirect to the trailing-slash URL" do
    32	    {
    33	      "/safe" => "/safe/",
    34	      "/safe/index.html" => "/safe/",
    35	      "/privacy" => "/privacy/",
    36	      "/privacy/index.html" => "/privacy/"
    37	    }.each do |path, target|
    38	      status, headers, = call(path)
    39	      assert_equal 301, status, path
    40	      assert_equal target, headers["location"], path
    41	    end
    42	  end
    43	
    44	  test "the canonical spelling and everything else passes through" do
    45	    %w[/ /safe/ /privacy/ /safe/sw.js /safe/icon.svg /safe/manifest.ko.webmanifest
    46	       /api/safe_scan /safety /blog/safe /about /blog/some-slug].each do |path|
    47	      status, = call(path)
    48	      assert_equal 200, status, path
    49	    end
    50	  end
    51	
    52	  # ── routed pages are canonical WITHOUT the trailing slash ───────────────
    53	  #
    54	  # The Rails router matches a trailing slash as if it were absent, so every
    55	  # routed page answered twice. Measured live 2026-09-17: 168 of 168 post URLs
    56	  # and 32 other paths returned a real 200 both ways, no redirect involved.
    57	
    58	  test "a trailing slash on a routed page redirects to the bare path" do
    59	    {
    60	      "/about/" => "/about",
    61	      "/faq/" => "/faq",
    62	      "/blog/" => "/blog",
    63	      "/blog/some-slug/" => "/blog/some-slug",
    64	      "/en/" => "/en",
    65	      "/en/about/" => "/en/about",
    66	      "/ja/blog/some-slug/" => "/ja/blog/some-slug",
    67	      "/sitemap.xml/" => "/sitemap.xml"
    68	    }.each do |path, target|
    69	      status, headers, = call(path)
    70	      assert_equal 301, status, path
    71	      assert_equal target, headers["location"], path
    72	    end
    73	  end
    74	
    75	  test "the site root keeps its slash" do
    76	    status, = call("/")
    77	    assert_equal 200, status, "/ is already canonical and must not redirect"
    78	  end
    79	
    80	  test "repeated trailing slashes collapse in a single hop" do
    81	    _, headers, = call("/about//")
    82	    assert_equal "/about", headers["location"]
    83	    _, headers, = call("/about///")
    84	    assert_equal "/about", headers["location"]
    85	  end
    86	
    87	  # ── repeated slashes anywhere in the path ───────────────────────────────
    88	  #
    89	  # The layers behind this one cannot see a repeated slash: FileHandler resolves
    90	  # `/safe//index.html` to the same file as `/safe/index.html`, and the Rails
    91	  # router matches `/en//about` as `/en/about`. Every extra slash was therefore
    92	  # another address serving identical bytes. Measured locally 2026-09-18 before
    93	  # the fix — every path below answered 200 with a byte-identical body, and
    94	  # `/safe//index.html` slipped past the `/safe/index.html` rule entirely.
    95	
    96	  test "repeated slashes under a static directory collapse onto its canonical URL" do
    97	    {
    98	      "/safe//" => "/safe/",
    99	      "/safe///" => "/safe/",
   100	      "/safe//index.html" => "/safe/",
   101	      "/safe///index.html" => "/safe/",
   102	      "/safe/index.html/" => "/safe/",
   103	      "/privacy//" => "/privacy/",
   104	      "/privacy//index.html" => "/privacy/"
   105	    }.each do |path, target|
   106	      status, headers, = call(path)
   107	      assert_equal 301, status, path
   108	      assert_equal target, headers["location"], path
   109	    end
   110	  end
   111	
   112	  test "repeated slashes in front of a static asset collapse onto the single asset URL" do
   113	    {
   114	      "/safe//sw.js" => "/safe/sw.js",
   115	      "/safe///sw.js" => "/safe/sw.js",
   116	      "/safe//manifest.ko.webmanifest" => "/safe/manifest.ko.webmanifest",
   117	      # A trailing slash on an asset is a duplicate too: /safe/sw.js/ served the
   118	      # same 8979 bytes as /safe/sw.js. The old code's "never touch anything
   119	      # under a static dir" branch let this through.
   120	      "/safe/sw.js/" => "/safe/sw.js",
   121	      "/privacy//style.css" => "/privacy/style.css"
   122	    }.each do |path, target|
   123	      status, headers, = call(path)
   124	      assert_equal 301, status, path
   125	      assert_equal target, headers["location"], path
   126	    end
   127	  end
   128	
   129	  test "repeated slashes mid-path on a routed page collapse in one hop" do
   130	    # Not trailing — no amount of trailing-slash stripping would catch these.
   131	    {
   132	      "//about" => "/about",
   133	      "/en//about" => "/en/about",
   134	      "/en///about" => "/en/about",
   135	      "//en/about" => "/en/about",
   136	      "//faq" => "/faq",
   137	      "//blog" => "/blog",
   138	      "//sitemap.xml" => "/sitemap.xml",
   139	      "/blog//some-slug" => "/blog/some-slug",
   140	      "/en//blog//some-slug" => "/en/blog/some-slug",
   141	      "//robots.txt" => "/robots.txt"
   142	    }.each do |path, target|
   143	      status, headers, = call(path)
   144	      assert_equal 301, status, path
   145	      assert_equal target, headers["location"], path
   146	    end
   147	  end
   148	
   149	  test "repeated slashes at the root collapse onto /" do
   150	    { "//" => "/", "///" => "/", "////" => "/" }.each do |path, target|
   151	      status, headers, = call(path)
   152	      assert_equal 301, status, path
   153	      assert_equal target, headers["location"], path
   154	    end
   155	  end
   156	
   157	  # ── no chains, no loops ─────────────────────────────────────────────────
   158	  #
   159	  # Normalising the path before mapping it is what bounds this to a single hop.
   160	  # Rather than trust that argument, follow the middleware's own output back
   161	  # into itself: if any Location it emits would redirect again, the fix has
   162	  # created a chain, and if one ever returns to its input it has created a loop.
   163	  # (config/routes.rb may add a second hop for an old slug — that is the router,
   164	  # deliberately accepted, and out of this middleware's reach. DECISIONS.md
   165	  # 2026-09-18.)
   166	
   167	  test "no Location this middleware emits redirects again" do
   168	    paths = %w[
   169	      / // /// //// /safe /safe/ /safe// /safe/// /safe/index.html /safe//index.html
   170	      /safe/index.html/ /safe/sw.js /safe/sw.js/ /safe//sw.js /privacy /privacy/
   171	      /privacy// /privacy//index.html /about /about/ /about// /about/// //about
   172	      /en//about /en///about //en/about /faq/ //faq /blog/ //blog /blog//some-slug
   173	      /en//blog//some-slug /sitemap.xml/ //sitemap.xml /robots.txt //robots.txt
   174	      /api/safe_scan /blog/safe /safety /en /en/
   175	    ]
   176	
   177	    paths.each do |path|
   178	      status, headers, = call(path)
   179	      next if status == 200
   180	
   181	      location = headers["location"]
   182	      follow_status, follow_headers, = call(location)
   183	      assert_equal 200, follow_status,
   184	        "#{path} -> #{location} -> #{follow_headers["location"]} is a redirect chain"
   185	      assert_not_equal path, location, "#{path} redirects to itself"
   186	    end
   187	  end
   188	
   189	  test "every canonical spelling is a fixed point" do
   190	    # The same invariant stated directly on the pure function, so a regression
   191	    # is reported at the rule rather than at one of its symptoms.
   192	    mw = CanonicalPathRedirect.new(PASSTHROUGH)
   193	    %w[
   194	      / // /safe /safe/ /safe// /safe/index.html /safe/sw.js/ /privacy//
   195	      /about/ //about /en//about /blog//some-slug /sitemap.xml/ ////
   196	    ].each do |path|
   197	      once = mw.send(:canonical_spelling, path)
   198	      twice = mw.send(:canonical_spelling, once)
   199	      assert_equal once, twice, "canonical_spelling is not idempotent for #{path}"
   200	    end
   201	  end
   202	
   203	  test "a static directory keeps its slash while routed paths lose theirs" do
   204	    # The two rules point in opposite directions, which is why one middleware
   205	    # owns both. /safe/ is a real directory under public/; /about/ is not.
   206	    assert_equal 200, call("/safe/").first
   207	    assert_equal 200, call("/privacy/").first
   208	    assert_equal 301, call("/about/").first
   209	  end
   210	
   211	  # ── SafeFile JP landing pages (2026-10-22) ──────────────────────────────
   212	
   213	  test "DIRS names every directory under public with an index.html" do
   214	    # The list is hand-maintained, and a page added without updating it serves
   215	    # identical bytes at two addresses with nothing to notice — the duplicate
   216	    # that put /safe/ into Search Console. Derive the truth from the filesystem
   217	    # instead of restating the list.
   218	    on_disk = Dir.glob(Rails.root.join("public", "**", "index.html"))
   219	                 .reject { |f| f.include?("/public/assets/") }
   220	                 .map { |f| File.dirname(f).sub(Rails.root.join("public").to_s, "") }
   221	                 .sort
   222	
   223	    assert_equal on_disk, CanonicalPathRedirect::DIRS.sort,
   224	                 "CanonicalPathRedirect::DIRS is out of step with public/**/index.html"
   225	  end
   226	
   227	  test "each JP landing page has exactly one spelling" do
   228	    %w[/safe/jp/nyusatsu /safe/jp/honnin-kakunin /safe/jp/ai-mae].each do |dir|
   229	      assert_equal 200, call("#{dir}/").first, "#{dir}/ must be served"
   230	
   231	      {
   232	        dir => "#{dir}/",
   233	        "#{dir}/index.html" => "#{dir}/",
   234	        "#{dir}//" => "#{dir}/",
   235	        "#{dir}///" => "#{dir}/",
   236	        "#{dir}//index.html" => "#{dir}/",
   237	        "#{dir}/index.html/" => "#{dir}/",
   238	        "/safe/jp//#{File.basename(dir)}/" => "#{dir}/"
   239	      }.each do |path, target|
   240	        status, headers, = call(path)
   241	        assert_equal 301, status, path
   242	        assert_equal target, headers["location"], path
   243	      end
   244	    end
   245	  end
   246	
   247	  test "the JP landing pages do not shadow /safe/ itself" do
   248	    # /safe is a prefix of all three, and the directory rule is an equality
   249	    # test rather than a prefix test precisely so that stays true.
   250	    _, headers, = call("/safe")
   251	    assert_equal "/safe/", headers["location"]
   252	    assert_equal 200, call("/safe/").first
   253	    # And the shared assets under the landing directory are untouched.
   254	    assert_equal 200, call("/safe/jp/jp.css").first
   255	    assert_equal 200, call("/safe/jp/jp.js").first
   256	  end
   257	
   258	  test "/safe/jp itself is not a page" do
   259	    # public/safe/jp/ holds no index.html, so it must NOT be in DIRS: making it
   260	    # one would invent a fourth address for whichever page got served there.
   261	    # The honest result is the routed rule — slash stripped, then a 404 from the
   262	    # layer behind this one.
   263	    _, headers, = call("/safe/jp/")
   264	    assert_equal "/safe/jp", headers["location"]
   265	    assert_not_includes CanonicalPathRedirect::DIRS, "/safe/jp"
   266	  end
   267	
   268	  test "assets underneath a static directory are never rewritten" do
   269	    %w[/safe/sw.js /safe/icon.svg /safe/manifest.ko.webmanifest /privacy/style.css].each do |path|
   270	      assert_equal 200, call(path).first, path
   271	    end
   272	  end
   273	
   274	  test "the trailing-slash redirect preserves the query string" do
   275	    _, headers, = call("/blog/", query: "category=privacy")
   276	    assert_equal "/blog?category=privacy", headers["location"]
   277	  end
   278	
   279	  test "only GET and HEAD lose the trailing slash" do
   280	    assert_equal 301, call("/about/", method: "HEAD").first
   281	    assert_equal 200, call("/about/", method: "POST").first
   282	  end
   283	
   284	  test "only GET and HEAD are redirected" do
   285	    assert_equal 301, call("/safe", method: "HEAD").first
   286	    # Turning a POST into a 301 would silently drop the method and body.
   287	    assert_equal 200, call("/safe", method: "POST").first
   288	    assert_equal 200, call("/privacy/index.html", method: "PUT").first
   289	  end
   290	
   291	  test "SCRIPT_NAME is preserved for a sub-path mount" do
   292	    _, headers, = call("/safe", script_name: "/app")
   293	    assert_equal "/app/safe/", headers["location"]
   294	  end
   295	
   296	  # ── query string handling ───────────────────────────────────────────────
   297	
   298	  test "the query string is preserved" do
   299	    _, headers, = call("/safe", query: "v=20260719")
   300	    assert_equal "/safe/?v=20260719", headers["location"]
   301	  end
   302	
   303	  test "CR and LF are stripped from the Location header" do
   304	    _, headers, = call("/safe", query: "a=1\r\nX-Injected: yes")
   305	    assert_no_match(/[\r\n]/, headers["location"])
   306	    assert_equal "/safe/?a=1X-Injected: yes", headers["location"]
   307	  end
   308	
   309	  # ── 301 body escaping ───────────────────────────────────────────────────
   310	
   311	  test "HTML metacharacters from the query string are escaped in the body" do
   312	    _, _, body = call("/safe", query: %(x="><script>alert(1)</script>))
   313	    html = body.first
   314	
   315	    assert_not_includes html, "<script>"
   316	    assert_includes html, "&lt;script&gt;"
   317	    assert_includes html, "&quot;"
   318	    # The anchor the template itself writes is the only markup left standing.
   319	    assert_equal 1, html.scan("<a href=").length
   320	    assert_equal 1, html.scan("</a>").length
   321	  end
   322	
   323	  test "an attribute-breaking payload cannot escape the href" do
   324	    _, _, body = call("/safe", query: %(x=a" onmouseover="alert(1)))
   325	    html = body.first
   326	
   327	    assert_not_includes html, "onmouseover=\"alert"
   328	    assert_includes html, "&quot;"
   329	    # exactly two quote characters remain: the ones delimiting href="…"
   330	    assert_equal 2, html.count('"')
   331	  end
   332	
   333	  test "ampersands and single quotes are escaped" do
   334	    _, _, body = call("/safe", query: "x=a&b='c'")
   335	    html = body.first
   336	
   337	    assert_includes html, "&amp;"
   338	    assert_not_includes html, "'"
   339	  end
   340	
   341	  test "percent-encoded payloads stay inert and unmangled" do
   342	    encoded = "x=%22%3E%3Cscript%3E"
   343	    _, headers, body = call("/safe", query: encoded)
   344	
   345	    assert_equal "/safe/?#{encoded}", headers["location"]
   346	    assert_includes body.first, encoded
   347	    assert_not_includes body.first, "<script>"
   348	  end
   349	
   350	  test "an ordinary query string stays readable in the body" do
   351	    _, _, body = call("/safe", query: "v=20260719")
   352	    assert_includes body.first, %(<a href="/safe/?v=20260719">/safe/?v=20260719</a>)
   353	  end
   354	
   355	  # ── response shape ──────────────────────────────────────────────────────
   356	
   357	  test "the Location is always path-only and never echoes the Host" do
   358	    # This is what makes the middleware safe to run at any depth in the stack.
   359	    # When ActionDispatch::Static is absent the initializer unshifts it to the
   360	    # very top — ahead of ActionDispatch::SSL — so a plain-HTTP request gets
   361	    # normalised before being upgraded. That costs nothing only because the
   362	    # Location carries no scheme and no host: SSL still gets its turn, and a
   363	    # forged Host header has nothing to land in.
   364	    %w[/safe /safe// /about/ //about /en//about /safe/sw.js/ //].each do |path|
   365	      _, headers, = CanonicalPathRedirect.new(PASSTHROUGH).call(
   366	        "PATH_INFO" => path,
   367	        "REQUEST_METHOD" => "GET",
   368	        "QUERY_STRING" => "",
   369	        "SCRIPT_NAME" => "",
   370	        "HTTP_HOST" => "evil.example.com",
   371	        "HTTPS" => "off"
   372	      )
   373	      location = headers["location"]
   374	      assert_match %r{\A/}, location, "#{path}: Location must be path-only, got #{location.inspect}"
   375	      assert_not_includes location, "evil.example.com", path
   376	      assert_not_includes location, "://", path
   377	    end
   378	  end
   379	
   380	  test "the redirect is not cached permanently by the browser" do
   381	    _, headers, = call("/safe")
   382	    assert_equal "no-cache", headers["cache-control"]
   383	    assert_equal "text/html; charset=utf-8", headers["content-type"]
   384	  end
   385	end

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
exec
/bin/zsh -lc 'for f in app/controllers/admin/jp_pilot_requests_controller.rb app/controllers/admin/base_controller.rb app/views/admin/jp_pilot_requests/index.html.erb db/migrate/20261022000100_create_jp_pilot_requests.rb; do echo "### $f"; nl -ba "$f"; done; sed -n '"'2335,2385p' public/safe/index.html | nl -ba -v2335; git status --short" in /Users/sunghoon/Projects/docpack
 succeeded in 0ms:
### app/controllers/admin/jp_pilot_requests_controller.rb
     1	module Admin
     2	  # Read-only list of SafeFile JP pilot sign-ups.
     3	  #
     4	  # Read-only on purpose: the mail notification can fail (SMTP has failed here
     5	  # before), so this page is the channel that cannot, and a list that cannot
     6	  # delete or edit cannot lose a sign-up either. Follow-up state lives in
     7	  # docs/jp/outreach_log.md, where it is reviewable in git.
     8	  class JpPilotRequestsController < BaseController
     9	    def index
    10	      @requests = JpPilotRequest.recent
    11	    end
    12	  end
    13	end
### app/controllers/admin/base_controller.rb
     1	module Admin
     2	  class BaseController < ApplicationController
     3	    layout "admin"
     4	
     5	    before_action :require_admin
     6	
     7	    private
     8	
     9	    def require_admin
    10	      unless session[:admin_authenticated]
    11	        redirect_to admin_login_path
    12	      end
    13	    end
    14	  end
    15	end
### app/views/admin/jp_pilot_requests/index.html.erb
     1	<% content_for(:admin_title, "SafeFile JP Pilot Requests") %>
     2	
     3	<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1.5rem;">
     4	  <p style="color:#6b7280;margin:0;"><%= @requests.size %> request(s)</p>
     5	  <span class="admin-badge admin-badge-gray">読み取り専用 — 후속 이력은 docs/jp/outreach_log.md</span>
     6	</div>
     7	
     8	<% if @requests.any? %>
     9	  <table class="admin-table">
    10	    <thead>
    11	      <tr>
    12	        <th>受付</th>
    13	        <th>会社名</th>
    14	        <th>業種</th>
    15	        <th>月間件数</th>
    16	        <th>よく使う発注者</th>
    17	        <th>連絡先</th>
    18	        <th>流入元</th>
    19	      </tr>
    20	    </thead>
    21	    <tbody>
    22	      <% @requests.each do |req| %>
    23	        <tr>
    24	          <td style="white-space:nowrap;"><%= req.created_at&.strftime("%Y-%m-%d %H:%M") %></td>
    25	          <td><strong><%= req.company %></strong></td>
    26	          <td><span class="admin-badge admin-badge-gray"><%= req.industry %></span></td>
    27	          <td><%= req.monthly_count %></td>
    28	          <td><%= req.authority.presence || "—" %></td>
    29	          <td><%= mail_to req.email %></td>
    30	          <td><span class="admin-badge admin-badge-gray"><%= req.from %></span></td>
    31	        </tr>
    32	      <% end %>
    33	    </tbody>
    34	  </table>
    35	<% else %>
    36	  <p style="color:#6b7280;">まだ申込はありません。</p>
    37	<% end %>
### db/migrate/20261022000100_create_jp_pilot_requests.rb
     1	class CreateJpPilotRequests < ActiveRecord::Migration[8.0]
     2	  def change
     3	    create_table :jp_pilot_requests do |t|
     4	      t.string :company,        null: false
     5	      t.string :industry,       null: false
     6	      t.string :monthly_count,  null: false
     7	      t.string :authority
     8	      t.string :email,          null: false
     9	      # Which landing page the form was submitted from (nyusatsu|honnin|aimae|direct).
    10	      # Not personal data — one of four fixed strings, validated in the model.
    11	      t.string :from,           null: false, default: "direct"
    12	
    13	      t.timestamps
    14	    end
    15	
    16	    add_index :jp_pilot_requests, :created_at
    17	  end
    18	end
  2335	      if(d[3]>=200) cols.push([d[0],d[1],d[2]]);
  2336	    }
  2337	    if(!cols.length) return '#FFFFFF';
  2338	    const med=ch=>{ const s=cols.map(c=>c[ch]).sort((a,b)=>a-b); return s[s.length>>1]; };
  2339	    const c=[med(0),med(1),med(2)];
  2340	    return `rgb(${c[0]},${c[1]},${c[2]})`;
  2341	  }catch(e){ return '#FFFFFF'; }
  2342	}
  2343	
  2344	/* ───────── canvas helpers ───────── */
  2345	function canvasEl(w,h){ const c=document.createElement('canvas'); c.width=Math.max(1,Math.round(w)); c.height=Math.max(1,Math.round(h)); return c; }
  2346	
  2347	/* ───────── file loading ───────── */
  2348	const dz=$('dropzone'), fi=$('fileInput');
  2349	dz.addEventListener('click',e=>{if(e.target.closest('button'))return;fi.click();});
  2350	dz.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();fi.click();}});
  2351	$('btnPick').addEventListener('click',()=>fi.click());
  2352	['dragover','dragenter'].forEach(ev=>dz.addEventListener(ev,e=>{e.preventDefault();dz.classList.add('drag');}));
  2353	['dragleave','drop'].forEach(ev=>dz.addEventListener(ev,e=>{e.preventDefault();dz.classList.remove('drag');}));
  2354	dz.addEventListener('drop',e=>{const f=e.dataTransfer.files[0];if(f)handleFile(f);});
  2355	fi.addEventListener('change',()=>{if(fi.files[0])handleFile(fi.files[0]);fi.value='';});
  2356	$('btnPaste').addEventListener('click',()=>{dz.style.display='none';$('pasteArea').style.display='block';$('pasteActions').style.display='flex';$('pasteArea').focus();});
  2357	$('btnPasteCancel').addEventListener('click',()=>{$('pasteArea').style.display='none';$('pasteActions').style.display='none';dz.style.display='flex';});
  2358	$('btnPasteScan').addEventListener('click',()=>{const t=$('pasteArea').value.trim();if(!t){toast(T().tPasteEmpty);return;}loadFromText(t,T().pasted);});
  2359	$('btnReset').addEventListener('click',resetAll);
  2360	
  2361	const SAMPLE_KO=`재직증명서
  2362	
  2363	성명: 김민준
  2364	주민등록번호: 900315-1234567
  2365	생년월일: 1990년 3월 15일
  2366	주소: 서울특별시 강남구 테헤란로 152, 1204호
  2367	연락처: 010-2345-6789
  2368	이메일: minjun.kim@hanmail.net
  2369	
  2370	위 사람은 주식회사 한빛테크 개발팀에서
  2371	2019년 4월 1일부터 현재까지 선임연구원으로
  2372	재직 중임을 증명합니다.
  2373	
  2374	급여계좌: 국민은행 123456-04-789012
  2375	비상연락망: 김서연 (배우자) 010-9876-5432
  2376	
  2377	2026년 7월 15일
  2378	주식회사 한빛테크 대표이사 박정호`;
  2379	const SAMPLE_EN=`CERTIFICATE OF EMPLOYMENT
  2380	
  2381	Name: James Miller
  2382	SSN: 123-45-6789
  2383	Date of Birth: 1990-03-15
  2384	Address: Seoul Gangnam-gu Teheran-ro 152
  2385	Phone: 010-2345-6789
?? docs/jp/codex_review_s6s7_2026-10-22.md

hook: PostToolUse
hook: PostToolUse Completed
hook: PreToolUse
hook: PreToolUse Completed
관련 구현·문안·계획·생성물을 모두 읽기 전용으로 대조했습니다. 테스트는 요청대로 재실행하지 않았습니다.
  ✓ 두 커밋 변경 범위와 관련 파일·스키마 구조 확인
  ✓ Q1 폼·검증·메일·CSRF 구현과 테스트 판정
  ✓ Q2 계측·PII·캐시·쿠키·집계 구현과 테스트 판정
  ✓ Q3 정본과 3개 랜딩 페이지·CTA·EN 전수 대조
  ✓ Q4 전략 문서·33편 계획·원고·X·캐러셀·가드 대조
  ✓ 7개 불확실성 및 공허한 단언을 종합해 보고서 작성
hook: PostToolUse
hook: PostToolUse Completed
codex
## 총평

| 질문 | 판정 | 핵심 |
|---|---|---|
| Q1 파일럿 폼 | **부분** | 저장·검증·빈 honeypot·순차 상한은 작동한다. 그러나 상한이 원자적이지 않고, CSRF를 건너뛰면서 JSON만 받도록 강제하지 않으며, honeypot 타이밍까지 동일하지 않다. |
| Q2 익명 계측 | **부분** | 저장되는 데이터는 실제로 고정 범주뿐이며 개인정보 0 주장은 성립한다. 다만 전역 600건 상한도 원자적이지 않아 엄격한 상한은 아니다. |
| Q3 랜딩 문구 | **닫힘** | 정본의 title/meta/H1/리드/표/본문/EN 블록과 일치한다. 명시한 세 추가 문구도 적절하다. |
| Q4 콘텐츠 규칙 | **열림** | X 스레드 필수 문장 누락, ep01의 미출시 다중 파일 처리 홍보, 허용 수준을 넘는 법적 효과 단정이 있다. |

검토한 파일 중 읽지 못한 파일은 없습니다. 요청대로 수정하거나 테스트를 재실행하지 않았습니다.

---

## Q1 — 파일럿 폼: 부분

### 확인된 정상 동작

- honeypot이 채워지면 DB와 메일을 건너뛰고 `201 {"ok":true}`를 반환한다: [jp_pilot_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/jp_pilot_controller.rb:26).
- 빈 문자열은 `present?`가 거짓이므로 정상 저장된다. 전용 테스트도 실제 행 증가를 확인하여 공허하지 않다: [jp_pilot_controller_test.rb](/Users/sunghoon/Projects/docpack/test/controllers/api/jp_pilot_controller_test.rb:56).
- 테스트용 memory cache 교체와 null-store 역가드는 순차 요청 기준으로 유효하다: [cache_store_helper.rb](/Users/sunghoon/Projects/docpack/test/support/cache_store_helper.rb:14), [jp_pilot_controller_test.rb](/Users/sunghoon/Projects/docpack/test/controllers/api/jp_pilot_controller_test.rb:104).
- `industry`, `monthly_count`, `from`은 고정 집합이며 길이 제한도 모델에서 집행된다: [jp_pilot_request.rb](/Users/sunghoon/Projects/docpack/app/models/jp_pilot_request.rb:9).
- 이메일 정규식은 “회신 가능한 기본 구조”라는 목적에는 합리적이다. 일부 RFC 유효 주소를 거부하지만 일반 업무용 주소에 과도하게 엄격하지 않으며, `office@example` 같은 명백한 오입력은 거부한다.
- 알 수 없는 `from`을 `direct`로 내리는 결정은 타당하다. 사용자가 입력한 본체 데이터가 아니며 오래된 링크 때문에 신청을 폐기하지 않는다: [jp_pilot_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/jp_pilot_controller.rb:55).
- 신청 행은 메일 enqueue 전에 저장된다. 따라서 렌더링·SMTP 실패가 나도 신청 자체는 유실되지 않는다: [jp_pilot_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/jp_pilot_controller.rb:35), [admin 목록](/Users/sunghoon/Projects/docpack/app/controllers/admin/jp_pilot_requests_controller.rb:8).

### AMBER A-1 — 레이트리밋이 동시 요청에서 엄격한 3회 상한이 아니다

카운터가 원자적 증가가 아니라 `read → +1 → write`다: [jp_pilot_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/jp_pilot_controller.rb:73).

두 요청이 동시에 같은 값 `2`를 읽으면 둘 다 `3`을 기록하고 둘 다 허용된다. Solid Cache가 프로세스 공유라는 사실은 이 lost-update 경쟁을 해결하지 않는다. 현재 테스트는 순차 요청만 보내므로 이 결함을 잡지 못한다.

재현:

```sh
# 동일 IP에서 각기 다른 유효 이메일로 충분한 수의 요청을 동시에 보낸다.
seq 1 20 | xargs -P20 -I{} curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'Content-Type: application/json' \
  --data "{\"company\":\"x\",\"industry\":\"other\",\"monthly_count\":\"1-2\",\"email\":\"u{}@example.co.jp\",\"from\":\"direct\",\"website\":\"\"}" \
  http://localhost:3000/api/jp_pilot
```

깨끗한 버킷에서 `201`이 3건을 초과하거나 DB 행이 3개를 초과할 수 있다. 결정적 테스트는 cache store의 `read` 뒤에 barrier를 두고 두 요청이 같은 값을 읽게 하면 된다.

### AMBER A-2 — “JSON 엔드포인트라 CSRF skip”이라는 근거가 구현으로 강제되지 않는다

컨트롤러는 CSRF를 공통으로 skip하지만 Content-Type이나 Origin을 검사하지 않는다: [base_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/base_controller.rb:20). Rails의 form-urlencoded 요청도 동일한 `params`를 만들기 때문에 외부 사이트가 일반 HTML `<form>`으로 실제 행과 메일을 생성할 수 있다. 응답을 읽을 필요도 없다.

재현용 외부 페이지:

```html
<form action="https://slimfile.net/api/jp_pilot" method="post">
  <input name="company" value="spam">
  <input name="industry" value="other">
  <input name="monthly_count" value="1-2">
  <input name="email" value="spam@example.com">
  <input name="from" value="direct">
</form>
<script>document.forms[0].submit()</script>
```

따라서 “세션 권한을 빌리지 않는다”는 전통적 CSRF 설명은 맞지만, 외부 사이트를 이용한 신청·메일 증폭까지 막지는 못한다. JSON 전용을 근거로 삼으려면 JSON Content-Type 강제 또는 Origin 검사가 필요하다.

### AMBER A-3 — honeypot은 상태·본문은 같지만 타이밍까지 구별 불가능하지 않다

honeypot 경로는 즉시 반환하지만 정상 경로는 validation, INSERT, mail job enqueue를 수행한다: [jp_pilot_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/jp_pilot_controller.rb:29). 테스트는 status/body만 비교하며 헤더와 반복 타이밍 분포는 보지 않는다: [jp_pilot_controller_test.rb](/Users/sunghoon/Projects/docpack/test/controllers/api/jp_pilot_controller_test.rb:43).

재현:

```sh
# 정상 payload와 website가 채워진 payload를 각각 수백 회 보내 time_total 분포 비교
curl -s -o /dev/null -w '%{time_total}\n' ...
```

헤더는 동일한 `render` 형태라 특별한 구별 신호는 보이지 않지만, DB·queue I/O 차이로 타이밍 오라클은 남는다. “일반 봇을 속이는 fake success”는 성립하나 “타이밍까지 구별 불가”는 성립하지 않는다.

### 메일 실패 판정

- **신청 유실은 아니다.** 행은 먼저 저장되고 admin 목록은 그 행을 직접 읽는다.
- 다만 `/admin/jp_pilot_requests`는 `publish_stuck`과 완전히 같은 파생 실패 상태가 아니다. 메일 실패 여부나 “새 행이 아직 확인되지 않음”을 드러내지 않고, 사람이 목록을 열어야만 발견된다.
- `ApplicationMailDeliveryJob`의 재시도 및 최종 failed execution 기록은 존재한다: [application_mail_delivery_job.rb](/Users/sunghoon/Projects/docpack/app/jobs/application_mail_delivery_job.rb:29), [jobs.rake](/Users/sunghoon/Projects/docpack/lib/tasks/jobs.rake:36).

결론은 “데이터 유실 방지에는 충분, 알림 전달 실패의 능동적 가시성에는 불충분”이다.

---

## Q2 — 계측 개인정보 0: 부분

### 개인정보 0 판정

개인정보 저장 주장은 **닫혔다**.

- 이벤트 이름, 이벤트별 키, 각 값이 모두 고정 목록이다: [safe_event.rb](/Users/sunghoon/Projects/docpack/app/models/safe_event.rb:26).
- 알 수 없는 키 하나라도 포함되면 전체 이벤트를 거부한다: [safe_event.rb](/Users/sunghoon/Projects/docpack/app/models/safe_event.rb:63).
- 컨트롤러가 알려진 키만 먼저 잘라내지 않고 원본 키를 sanitizer에 넘기는 결정은 옳다: [safe_events_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/safe_events_controller.rb:54).
- 중첩 hash, array, uploaded file 객체, `nil`은 `to_s` 결과가 고정 값 목록과 일치하지 않아 거부된다. 배열 자체가 `props`이면 `{}`로 취급될 수 있지만 개인정보가 저장되는 경로는 아니다.
- `remote_ip`, 쿠키, session은 SafeEvents 경로에서 읽거나 저장하지 않는다. IP 사용 검색 결과는 `safe_scan`과 `jp_pilot`에만 있다.
- 테이블은 실제로 `id`, `name`, `props`, `created_at` 네 컬럼뿐이다: [migration](/Users/sunghoon/Projects/docpack/db/migrate/20261022000200_create_safe_events.rb:3), [schema.rb](/Users/sunghoon/Projects/docpack/db/schema.rb:134).
- Active Record는 존재하는 timestamp 컬럼만 쓰므로 `updated_at` 부재는 문제없다.
- 집계는 이벤트별 단일 범주 카운트만 생성한다: [safe.rake](/Users/sunghoon/Projects/docpack/lib/tasks/safe.rake:34). 사용자 식별자나 동일인 연결 키가 없으므로 개인 재구성은 불가능하다.

### 쿠키 수정 판정

수정은 코드상 완전하다.

- `set_locale`를 건너뛰므로 query-string `locale`도 쿠키를 만들 수 없다: [base_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/base_controller.rb:25).
- `ApplicationController`에 남은 명시적 before_action은 `set_locale`뿐이다: [application_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/application_controller.rb:1).
- `safe_scan` 출력은 하드코딩된 프롬프트/오류 키라 locale 의존성이 없다: [safe_scan_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/safe_scan_controller.rb:23).
- CSRF skip은 `safe_scan`에 이미 있던 동작이므로 공통 base 이동으로 그 엔드포인트의 권한 범위가 새로 넓어진 것은 아니다.
- 페이지가 여전히 locale 쿠키를 심는 역가드도 공허하지 않다: [safe_events_controller_test.rb](/Users/sunghoon/Projects/docpack/test/controllers/api/safe_events_controller_test.rb:114).

다만 “모든 `/api/` endpoint”라는 테스트 이름과 달리 cookie 테스트는 `safe_events`와 `jp_pilot`만 호출하고 `safe_scan`은 직접 호출하지 않는다: [safe_events_controller_test.rb](/Users/sunghoon/Projects/docpack/test/controllers/api/safe_events_controller_test.rb:102). 공통 상속 때문에 현재 코드는 안전하지만 테스트 설명이 실제 범위보다 넓다.

### AMBER A-4 — 전역 600건 상한도 원자적이지 않다

Q1과 동일한 `read → write` 경쟁이 있다: [safe_events_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/safe_events_controller.rb:73). 테스트는 카운터를 600으로 미리 넣고 단일 요청이 429인지 확인할 뿐, 600개 동시 증가를 검증하지 않는다: [safe_events_controller_test.rb](/Users/sunghoon/Projects/docpack/test/controllers/api/safe_events_controller_test.rb:123).

따라서 순차 폭주에는 발화하지만 “분당 최대 600행”이라는 엄격한 상한은 아니다. 단일 공격자가 전체 사용자를 429로 떨어뜨리는 구조는 개인정보를 남기지 않기 위해 선택한 가용성 교환으로 수용 가능하지만, 숫자 600의 근거는 아직 없다.

### `purpose` init 이벤트

`?purpose=`가 있으면 초기화 중 `jpSetPurpose`가 호출되고 `doc_class:"none"` 이벤트가 기록된다: [safe index](/Users/sunghoon/Projects/docpack/public/safe/index.html:2189), [init](/Users/sunghoon/Projects/docpack/public/safe/index.html:3197).

이는 개인정보 문제는 아니다. 다만 “사전 선택”과 “사용자가 변경”을 구분할 수 없어 데이터 품질 문제다.

---

## Q3 — 랜딩 문구: 닫힘

세 페이지를 정본과 전수 대조했다.

- title, meta description, H1, 리드, 표의 모든 셀, 목록, 단계, FAQ, 가격, EN 블록이 글자 단위로 일치한다.
- nyusatsu: [정본](/Users/sunghoon/Projects/docpack/docs/jp/jp_landing_copy_2026-10-22.md:8), [페이지](/Users/sunghoon/Projects/docpack/public/safe/jp/nyusatsu/index.html:97).
- honnin-kakunin: [정본](/Users/sunghoon/Projects/docpack/docs/jp/jp_landing_copy_2026-10-22.md:69), [페이지](/Users/sunghoon/Projects/docpack/public/safe/jp/honnin-kakunin/index.html:61).
- ai-mae: [정본](/Users/sunghoon/Projects/docpack/docs/jp/jp_landing_copy_2026-10-22.md:106), [페이지](/Users/sunghoon/Projects/docpack/public/safe/jp/ai-mae/index.html:64).

세 추가도 적절하다.

- `提出先の指示を必ず確認してください。`는 공통 규칙을 실제 페이지에 명시한 보완이다.
- 결제 준비 안내와 mailto는 작동하지 않는 구매 CTA보다 낫고, 원래 가격·상품 설명을 바꾸지 않는다: [ai-mae](/Users/sunghoon/Projects/docpack/public/safe/jp/ai-mae/index.html:96).
- 폼 성공·실패 문구는 정본 본문이 아닌 UI 상태 문구로 적절하다: [jp.js](/Users/sunghoon/Projects/docpack/public/safe/jp/jp.js:74).

금지된 사건명, `絶対`, `防ぐ`, `唯一`, `必ず安全`은 없다. 법적 표현도 정본과 동일하다.

EN 블록은 정본 그대로이며 `<details>`로 같은 문서에 둔 판단이 맞다. 별도의 완전한 영문 URL이 없으므로 hreflang 0개와 self canonical도 맞다.

SafeFile CTA의 `data-purpose`, href의 `purpose/from/lang`, `<html data-from>`은 일치한다.

### 하네스의 공허성

- 페이지 내부에서 Blob payload를 가로채는 방식은 타당하다.
- payload와 서버 `204`는 둘 다 필요하다는 논증도 맞다.
- 다만 “server accepted every counter” 검사는 CTA 클릭 전에 실행된다: [jp_landing_check.mjs](/Users/sunghoon/Projects/docpack/test/safe/jp_landing_check.mjs:186), CTA 클릭은 그 뒤다: [jp_landing_check.mjs](/Users/sunghoon/Projects/docpack/test/safe/jp_landing_check.mjs:199). 따라서 `cta_click` payload는 확인하지만 그 CTA 요청의 `204`는 확인하지 않는다. 제품 결함은 아니나 테스트 설명보다 보장이 좁다.

---

## Q4 — 콘텐츠 규칙: 열림

### AMBER A-5 — ep01~03 X 스레드에 필수 문장이 없다

세 파일 모두 「提出先の指示を必ず確認してください」 또는 동등한 안내가 없다.

- [ep01 x_thread](/Users/sunghoon/Projects/docpack/content/jp/ep01/x_thread.md:7)
- [ep02 x_thread](/Users/sunghoon/Projects/docpack/content/jp/ep02/x_thread.md:7)
- [ep03 x_thread](/Users/sunghoon/Projects/docpack/content/jp/ep03/x_thread.md:7)

가드는 JA 본문 `body`만 검사하고, X 생성 시에는 hook/bullets/CTA만 사용한다: [make_episode.mjs](/Users/sunghoon/Projects/docpack/scripts/content/make_episode.mjs:150), [make_episode.mjs](/Users/sunghoon/Projects/docpack/scripts/content/make_episode.mjs:163).

재현:

```sh
rg -L '提出先の指示を必ず確認してください' content/jp/ep0{1,2,3}/x_thread.md
```

세 파일이 모두 출력된다.

캐러셀은 템플릿 하단 chrome에 필수 문장을 넣고 실제 PNG에도 렌더링되어 있다: [carousel.html](/Users/sunghoon/Projects/docpack/scripts/content/templates/carousel.html:62). 확인한 PNG의 하단에서도 문장이 보인다.

### AMBER A-6 — ep01이 미출시 다중 파일 처리를 홍보한다

JA 원고:

> 複数枚をまとめて読み込めます。

[ep01 post_ja](/Users/sunghoon/Projects/docpack/content/jp/ep01/post_ja.md:29)

EN 원고:

> Several files at once is fine.

[ep01 post_en](/Users/sunghoon/Projects/docpack/content/jp/ep01/post_en.md:25)

실제 파일 input에는 `multiple`이 없고 첫 파일만 처리한다: [safe index input](/Users/sunghoon/Projects/docpack/public/safe/index.html:390), [file handler](/Users/sunghoon/Projects/docpack/public/safe/index.html:2348).

가드는 `一括処理|一括ダウンロード`라는 정확한 일본어만 잡기 때문에 이 우회 표현과 EN 문구를 놓친다: [make_episode.mjs](/Users/sunghoon/Projects/docpack/scripts/content/make_episode.mjs:142).

재현:

```sh
rg -n '複数枚|Several files at once' content/jp/ep01
rg -n 'id="fileInput"|files\\[0\\]' public/safe/index.html
```

### AMBER A-7 — 법적 효과 표현이 `_forbidden`보다 강하다

`topics.json`은 법적 효과를 최대 「制限される場合があります」로 제한한다: [topics.json](/Users/sunghoon/Projects/docpack/content/jp/topics.json:34).

그러나 ep01은 다음과 같이 현재의 법적 효과를 단정한다.

- JA: `原則として制限されています`: [post_ja](/Users/sunghoon/Projects/docpack/content/jp/ep01/post_ja.md:15)
- EN: `is restricted in principle`: [post_en](/Users/sunghoon/Projects/docpack/content/jp/ep01/post_en.md:11)

ep02 EN도 `The law constrains…`로 단정한다: [post_en](/Users/sunghoon/Projects/docpack/content/jp/ep02/post_en.md:32).

재현:

```sh
rg -n '制限されています|is restricted|law constrains' content/jp/ep0{1,2,3}
```

코드 가드는 이 법적 표현과 EN 본문을 검사하지 않는다.

### 나머지 Q4 판정

- 사건명, `絶対/防ぐ/唯一/必ず安全`, 1인칭 피해담은 ep01~03 JA/EN 본문에서 발견되지 않았다.
- `topics.json`은 원래 30편의 `src`를 모두 보존하며, 신규 3편과 1·14·20 재작성, 사업자/資格確認書 우선, AI 2편의 첫 4주 배치를 반영한다.
- ep32의 `blocked_until` 유지가 삭제보다 낫다. 전략의 예정 슬롯을 추적하면서 빌드·게시만 막을 수 있다: [topics.json](/Users/sunghoon/Projects/docpack/content/jp/topics.json:261).
- ep05·ep06은 제목만으로도 발주처별 규칙을 일반화할 위험이 있으므로 “본문 전 공식 공고 1건 확인 필요”라는 자기 신고가 맞다.

자동화 가능하지만 빠진 항목은 최소한 다음이다.

- 생성된 `x_thread.md` 필수 문장 검사
- `post_en.md` 금지 표현 검사
- 미출시 기능의 영문/우회 표현 검사
- 법적 효과 표현 검사
- 이미지의 긴 변, 실제 출력 크기 검사

1인칭 피해담도 `私/私は/私の` 등의 휴리스틱으로 일부 자동화할 수 있다. 완전한 의미 판정은 아니지만 현재처럼 전부 사람에게만 맡길 필요는 없다.

---

## 「확신하지 못한다」 7건 판정

1. **notify rescue 범위 — 부분 수용.** 신청은 유실되지 않는다. 그러나 메일 실패를 능동적으로 드러내는 파생 상태가 없어 `publish_stuck`과 동급이라고 할 수는 없다.

2. **전역 분당 600건 — 근거 불충분.** 개인정보 없는 전역 상한이라는 방향은 수용 가능하지만, 수치는 측정 근거가 없고 구현도 동시 요청에서 엄격하지 않다.

3. **`sanitize`의 `v.to_s` — 안전.** 배열·중첩 객체·Parameters·upload·nil이 화이트리스트 문자열로 변환되어 새는 경로는 찾지 못했다. 개인정보 0 속성에는 문제없다.

4. **init `purpose` 이벤트 — 데이터 품질 결함.** 개인정보 결함은 아니다. 이벤트 이름을 분리하거나 `source:init|user` 같은 고정 범주를 추가하는 쪽이 해석 가능성이 높다.

5. **`/safe/jp/` 301→404 — 백로그.** 거짓 콘텐츠를 제공하지는 않지만 크롤러에는 불필요한 redirect-to-error다. 색인상 “문제없다”고 단정할 근거는 없다.

6. **Google Fonts 의존 — 재현성 백로그.** 빌드는 실패하지 않지만 동일 원고의 픽셀 결과가 환경에 따라 달라진다. 생성물을 승인·재사용할 목적이면 폰트 고정이 바람직하다.

7. **PNG/GIF/MP4 git 커밋 — 현재 규모에서는 수용.** 약 30MB는 감당 가능하며, 재생성이 비결정적이라는 사실은 오히려 승인된 산출물을 보존할 이유가 된다. 증가 추세가 커지면 LFS/릴리스 자산을 검토하면 된다.

---

## 백로그

- `/safe/jp/`의 301→404를 직접 404 또는 유효한 허브로 정리.
- 랜딩 정본 자체의 미출시 팀 기능·다중 PDF·처리 기록 홍보를 제품 상태와 별도로 재검토.
- carousel 폰트 고정 또는 빌드 manifest에 실제 사용 폰트 기록.
- 생성물 저장 정책과 저장 용량 임계치 문서화.
- `jp_landing_check.mjs`에서 CTA 클릭 이후의 `204`도 별도 확인.
- cookie 회귀 테스트에 `/api/safe_scan?locale=ja`를 직접 포함.
- `SafeEvent`의 array/nil/upload 모양을 명시적으로 회귀 테스트해 현재 안전 속성을 문서화.
hook: Stop
hook: Stop Completed
tokens used
127,731
## 총평

| 질문 | 판정 | 핵심 |
|---|---|---|
| Q1 파일럿 폼 | **부분** | 저장·검증·빈 honeypot·순차 상한은 작동한다. 그러나 상한이 원자적이지 않고, CSRF를 건너뛰면서 JSON만 받도록 강제하지 않으며, honeypot 타이밍까지 동일하지 않다. |
| Q2 익명 계측 | **부분** | 저장되는 데이터는 실제로 고정 범주뿐이며 개인정보 0 주장은 성립한다. 다만 전역 600건 상한도 원자적이지 않아 엄격한 상한은 아니다. |
| Q3 랜딩 문구 | **닫힘** | 정본의 title/meta/H1/리드/표/본문/EN 블록과 일치한다. 명시한 세 추가 문구도 적절하다. |
| Q4 콘텐츠 규칙 | **열림** | X 스레드 필수 문장 누락, ep01의 미출시 다중 파일 처리 홍보, 허용 수준을 넘는 법적 효과 단정이 있다. |

검토한 파일 중 읽지 못한 파일은 없습니다. 요청대로 수정하거나 테스트를 재실행하지 않았습니다.

---

## Q1 — 파일럿 폼: 부분

### 확인된 정상 동작

- honeypot이 채워지면 DB와 메일을 건너뛰고 `201 {"ok":true}`를 반환한다: [jp_pilot_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/jp_pilot_controller.rb:26).
- 빈 문자열은 `present?`가 거짓이므로 정상 저장된다. 전용 테스트도 실제 행 증가를 확인하여 공허하지 않다: [jp_pilot_controller_test.rb](/Users/sunghoon/Projects/docpack/test/controllers/api/jp_pilot_controller_test.rb:56).
- 테스트용 memory cache 교체와 null-store 역가드는 순차 요청 기준으로 유효하다: [cache_store_helper.rb](/Users/sunghoon/Projects/docpack/test/support/cache_store_helper.rb:14), [jp_pilot_controller_test.rb](/Users/sunghoon/Projects/docpack/test/controllers/api/jp_pilot_controller_test.rb:104).
- `industry`, `monthly_count`, `from`은 고정 집합이며 길이 제한도 모델에서 집행된다: [jp_pilot_request.rb](/Users/sunghoon/Projects/docpack/app/models/jp_pilot_request.rb:9).
- 이메일 정규식은 “회신 가능한 기본 구조”라는 목적에는 합리적이다. 일부 RFC 유효 주소를 거부하지만 일반 업무용 주소에 과도하게 엄격하지 않으며, `office@example` 같은 명백한 오입력은 거부한다.
- 알 수 없는 `from`을 `direct`로 내리는 결정은 타당하다. 사용자가 입력한 본체 데이터가 아니며 오래된 링크 때문에 신청을 폐기하지 않는다: [jp_pilot_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/jp_pilot_controller.rb:55).
- 신청 행은 메일 enqueue 전에 저장된다. 따라서 렌더링·SMTP 실패가 나도 신청 자체는 유실되지 않는다: [jp_pilot_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/jp_pilot_controller.rb:35), [admin 목록](/Users/sunghoon/Projects/docpack/app/controllers/admin/jp_pilot_requests_controller.rb:8).

### AMBER A-1 — 레이트리밋이 동시 요청에서 엄격한 3회 상한이 아니다

카운터가 원자적 증가가 아니라 `read → +1 → write`다: [jp_pilot_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/jp_pilot_controller.rb:73).

두 요청이 동시에 같은 값 `2`를 읽으면 둘 다 `3`을 기록하고 둘 다 허용된다. Solid Cache가 프로세스 공유라는 사실은 이 lost-update 경쟁을 해결하지 않는다. 현재 테스트는 순차 요청만 보내므로 이 결함을 잡지 못한다.

재현:

```sh
# 동일 IP에서 각기 다른 유효 이메일로 충분한 수의 요청을 동시에 보낸다.
seq 1 20 | xargs -P20 -I{} curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'Content-Type: application/json' \
  --data "{\"company\":\"x\",\"industry\":\"other\",\"monthly_count\":\"1-2\",\"email\":\"u{}@example.co.jp\",\"from\":\"direct\",\"website\":\"\"}" \
  http://localhost:3000/api/jp_pilot
```

깨끗한 버킷에서 `201`이 3건을 초과하거나 DB 행이 3개를 초과할 수 있다. 결정적 테스트는 cache store의 `read` 뒤에 barrier를 두고 두 요청이 같은 값을 읽게 하면 된다.

### AMBER A-2 — “JSON 엔드포인트라 CSRF skip”이라는 근거가 구현으로 강제되지 않는다

컨트롤러는 CSRF를 공통으로 skip하지만 Content-Type이나 Origin을 검사하지 않는다: [base_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/base_controller.rb:20). Rails의 form-urlencoded 요청도 동일한 `params`를 만들기 때문에 외부 사이트가 일반 HTML `<form>`으로 실제 행과 메일을 생성할 수 있다. 응답을 읽을 필요도 없다.

재현용 외부 페이지:

```html
<form action="https://slimfile.net/api/jp_pilot" method="post">
  <input name="company" value="spam">
  <input name="industry" value="other">
  <input name="monthly_count" value="1-2">
  <input name="email" value="spam@example.com">
  <input name="from" value="direct">
</form>
<script>document.forms[0].submit()</script>
```

따라서 “세션 권한을 빌리지 않는다”는 전통적 CSRF 설명은 맞지만, 외부 사이트를 이용한 신청·메일 증폭까지 막지는 못한다. JSON 전용을 근거로 삼으려면 JSON Content-Type 강제 또는 Origin 검사가 필요하다.

### AMBER A-3 — honeypot은 상태·본문은 같지만 타이밍까지 구별 불가능하지 않다

honeypot 경로는 즉시 반환하지만 정상 경로는 validation, INSERT, mail job enqueue를 수행한다: [jp_pilot_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/jp_pilot_controller.rb:29). 테스트는 status/body만 비교하며 헤더와 반복 타이밍 분포는 보지 않는다: [jp_pilot_controller_test.rb](/Users/sunghoon/Projects/docpack/test/controllers/api/jp_pilot_controller_test.rb:43).

재현:

```sh
# 정상 payload와 website가 채워진 payload를 각각 수백 회 보내 time_total 분포 비교
curl -s -o /dev/null -w '%{time_total}\n' ...
```

헤더는 동일한 `render` 형태라 특별한 구별 신호는 보이지 않지만, DB·queue I/O 차이로 타이밍 오라클은 남는다. “일반 봇을 속이는 fake success”는 성립하나 “타이밍까지 구별 불가”는 성립하지 않는다.

### 메일 실패 판정

- **신청 유실은 아니다.** 행은 먼저 저장되고 admin 목록은 그 행을 직접 읽는다.
- 다만 `/admin/jp_pilot_requests`는 `publish_stuck`과 완전히 같은 파생 실패 상태가 아니다. 메일 실패 여부나 “새 행이 아직 확인되지 않음”을 드러내지 않고, 사람이 목록을 열어야만 발견된다.
- `ApplicationMailDeliveryJob`의 재시도 및 최종 failed execution 기록은 존재한다: [application_mail_delivery_job.rb](/Users/sunghoon/Projects/docpack/app/jobs/application_mail_delivery_job.rb:29), [jobs.rake](/Users/sunghoon/Projects/docpack/lib/tasks/jobs.rake:36).

결론은 “데이터 유실 방지에는 충분, 알림 전달 실패의 능동적 가시성에는 불충분”이다.

---

## Q2 — 계측 개인정보 0: 부분

### 개인정보 0 판정

개인정보 저장 주장은 **닫혔다**.

- 이벤트 이름, 이벤트별 키, 각 값이 모두 고정 목록이다: [safe_event.rb](/Users/sunghoon/Projects/docpack/app/models/safe_event.rb:26).
- 알 수 없는 키 하나라도 포함되면 전체 이벤트를 거부한다: [safe_event.rb](/Users/sunghoon/Projects/docpack/app/models/safe_event.rb:63).
- 컨트롤러가 알려진 키만 먼저 잘라내지 않고 원본 키를 sanitizer에 넘기는 결정은 옳다: [safe_events_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/safe_events_controller.rb:54).
- 중첩 hash, array, uploaded file 객체, `nil`은 `to_s` 결과가 고정 값 목록과 일치하지 않아 거부된다. 배열 자체가 `props`이면 `{}`로 취급될 수 있지만 개인정보가 저장되는 경로는 아니다.
- `remote_ip`, 쿠키, session은 SafeEvents 경로에서 읽거나 저장하지 않는다. IP 사용 검색 결과는 `safe_scan`과 `jp_pilot`에만 있다.
- 테이블은 실제로 `id`, `name`, `props`, `created_at` 네 컬럼뿐이다: [migration](/Users/sunghoon/Projects/docpack/db/migrate/20261022000200_create_safe_events.rb:3), [schema.rb](/Users/sunghoon/Projects/docpack/db/schema.rb:134).
- Active Record는 존재하는 timestamp 컬럼만 쓰므로 `updated_at` 부재는 문제없다.
- 집계는 이벤트별 단일 범주 카운트만 생성한다: [safe.rake](/Users/sunghoon/Projects/docpack/lib/tasks/safe.rake:34). 사용자 식별자나 동일인 연결 키가 없으므로 개인 재구성은 불가능하다.

### 쿠키 수정 판정

수정은 코드상 완전하다.

- `set_locale`를 건너뛰므로 query-string `locale`도 쿠키를 만들 수 없다: [base_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/base_controller.rb:25).
- `ApplicationController`에 남은 명시적 before_action은 `set_locale`뿐이다: [application_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/application_controller.rb:1).
- `safe_scan` 출력은 하드코딩된 프롬프트/오류 키라 locale 의존성이 없다: [safe_scan_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/safe_scan_controller.rb:23).
- CSRF skip은 `safe_scan`에 이미 있던 동작이므로 공통 base 이동으로 그 엔드포인트의 권한 범위가 새로 넓어진 것은 아니다.
- 페이지가 여전히 locale 쿠키를 심는 역가드도 공허하지 않다: [safe_events_controller_test.rb](/Users/sunghoon/Projects/docpack/test/controllers/api/safe_events_controller_test.rb:114).

다만 “모든 `/api/` endpoint”라는 테스트 이름과 달리 cookie 테스트는 `safe_events`와 `jp_pilot`만 호출하고 `safe_scan`은 직접 호출하지 않는다: [safe_events_controller_test.rb](/Users/sunghoon/Projects/docpack/test/controllers/api/safe_events_controller_test.rb:102). 공통 상속 때문에 현재 코드는 안전하지만 테스트 설명이 실제 범위보다 넓다.

### AMBER A-4 — 전역 600건 상한도 원자적이지 않다

Q1과 동일한 `read → write` 경쟁이 있다: [safe_events_controller.rb](/Users/sunghoon/Projects/docpack/app/controllers/api/safe_events_controller.rb:73). 테스트는 카운터를 600으로 미리 넣고 단일 요청이 429인지 확인할 뿐, 600개 동시 증가를 검증하지 않는다: [safe_events_controller_test.rb](/Users/sunghoon/Projects/docpack/test/controllers/api/safe_events_controller_test.rb:123).

따라서 순차 폭주에는 발화하지만 “분당 최대 600행”이라는 엄격한 상한은 아니다. 단일 공격자가 전체 사용자를 429로 떨어뜨리는 구조는 개인정보를 남기지 않기 위해 선택한 가용성 교환으로 수용 가능하지만, 숫자 600의 근거는 아직 없다.

### `purpose` init 이벤트

`?purpose=`가 있으면 초기화 중 `jpSetPurpose`가 호출되고 `doc_class:"none"` 이벤트가 기록된다: [safe index](/Users/sunghoon/Projects/docpack/public/safe/index.html:2189), [init](/Users/sunghoon/Projects/docpack/public/safe/index.html:3197).

이는 개인정보 문제는 아니다. 다만 “사전 선택”과 “사용자가 변경”을 구분할 수 없어 데이터 품질 문제다.

---

## Q3 — 랜딩 문구: 닫힘

세 페이지를 정본과 전수 대조했다.

- title, meta description, H1, 리드, 표의 모든 셀, 목록, 단계, FAQ, 가격, EN 블록이 글자 단위로 일치한다.
- nyusatsu: [정본](/Users/sunghoon/Projects/docpack/docs/jp/jp_landing_copy_2026-10-22.md:8), [페이지](/Users/sunghoon/Projects/docpack/public/safe/jp/nyusatsu/index.html:97).
- honnin-kakunin: [정본](/Users/sunghoon/Projects/docpack/docs/jp/jp_landing_copy_2026-10-22.md:69), [페이지](/Users/sunghoon/Projects/docpack/public/safe/jp/honnin-kakunin/index.html:61).
- ai-mae: [정본](/Users/sunghoon/Projects/docpack/docs/jp/jp_landing_copy_2026-10-22.md:106), [페이지](/Users/sunghoon/Projects/docpack/public/safe/jp/ai-mae/index.html:64).

세 추가도 적절하다.

- `提出先の指示を必ず確認してください。`는 공통 규칙을 실제 페이지에 명시한 보완이다.
- 결제 준비 안내와 mailto는 작동하지 않는 구매 CTA보다 낫고, 원래 가격·상품 설명을 바꾸지 않는다: [ai-mae](/Users/sunghoon/Projects/docpack/public/safe/jp/ai-mae/index.html:96).
- 폼 성공·실패 문구는 정본 본문이 아닌 UI 상태 문구로 적절하다: [jp.js](/Users/sunghoon/Projects/docpack/public/safe/jp/jp.js:74).

금지된 사건명, `絶対`, `防ぐ`, `唯一`, `必ず安全`은 없다. 법적 표현도 정본과 동일하다.

EN 블록은 정본 그대로이며 `<details>`로 같은 문서에 둔 판단이 맞다. 별도의 완전한 영문 URL이 없으므로 hreflang 0개와 self canonical도 맞다.

SafeFile CTA의 `data-purpose`, href의 `purpose/from/lang`, `<html data-from>`은 일치한다.

### 하네스의 공허성

- 페이지 내부에서 Blob payload를 가로채는 방식은 타당하다.
- payload와 서버 `204`는 둘 다 필요하다는 논증도 맞다.
- 다만 “server accepted every counter” 검사는 CTA 클릭 전에 실행된다: [jp_landing_check.mjs](/Users/sunghoon/Projects/docpack/test/safe/jp_landing_check.mjs:186), CTA 클릭은 그 뒤다: [jp_landing_check.mjs](/Users/sunghoon/Projects/docpack/test/safe/jp_landing_check.mjs:199). 따라서 `cta_click` payload는 확인하지만 그 CTA 요청의 `204`는 확인하지 않는다. 제품 결함은 아니나 테스트 설명보다 보장이 좁다.

---

## Q4 — 콘텐츠 규칙: 열림

### AMBER A-5 — ep01~03 X 스레드에 필수 문장이 없다

세 파일 모두 「提出先の指示を必ず確認してください」 또는 동등한 안내가 없다.

- [ep01 x_thread](/Users/sunghoon/Projects/docpack/content/jp/ep01/x_thread.md:7)
- [ep02 x_thread](/Users/sunghoon/Projects/docpack/content/jp/ep02/x_thread.md:7)
- [ep03 x_thread](/Users/sunghoon/Projects/docpack/content/jp/ep03/x_thread.md:7)

가드는 JA 본문 `body`만 검사하고, X 생성 시에는 hook/bullets/CTA만 사용한다: [make_episode.mjs](/Users/sunghoon/Projects/docpack/scripts/content/make_episode.mjs:150), [make_episode.mjs](/Users/sunghoon/Projects/docpack/scripts/content/make_episode.mjs:163).

재현:

```sh
rg -L '提出先の指示を必ず確認してください' content/jp/ep0{1,2,3}/x_thread.md
```

세 파일이 모두 출력된다.

캐러셀은 템플릿 하단 chrome에 필수 문장을 넣고 실제 PNG에도 렌더링되어 있다: [carousel.html](/Users/sunghoon/Projects/docpack/scripts/content/templates/carousel.html:62). 확인한 PNG의 하단에서도 문장이 보인다.

### AMBER A-6 — ep01이 미출시 다중 파일 처리를 홍보한다

JA 원고:

> 複数枚をまとめて読み込めます。

[ep01 post_ja](/Users/sunghoon/Projects/docpack/content/jp/ep01/post_ja.md:29)

EN 원고:

> Several files at once is fine.

[ep01 post_en](/Users/sunghoon/Projects/docpack/content/jp/ep01/post_en.md:25)

실제 파일 input에는 `multiple`이 없고 첫 파일만 처리한다: [safe index input](/Users/sunghoon/Projects/docpack/public/safe/index.html:390), [file handler](/Users/sunghoon/Projects/docpack/public/safe/index.html:2348).

가드는 `一括処理|一括ダウンロード`라는 정확한 일본어만 잡기 때문에 이 우회 표현과 EN 문구를 놓친다: [make_episode.mjs](/Users/sunghoon/Projects/docpack/scripts/content/make_episode.mjs:142).

재현:

```sh
rg -n '複数枚|Several files at once' content/jp/ep01
rg -n 'id="fileInput"|files\\[0\\]' public/safe/index.html
```

### AMBER A-7 — 법적 효과 표현이 `_forbidden`보다 강하다

`topics.json`은 법적 효과를 최대 「制限される場合があります」로 제한한다: [topics.json](/Users/sunghoon/Projects/docpack/content/jp/topics.json:34).

그러나 ep01은 다음과 같이 현재의 법적 효과를 단정한다.

- JA: `原則として制限されています`: [post_ja](/Users/sunghoon/Projects/docpack/content/jp/ep01/post_ja.md:15)
- EN: `is restricted in principle`: [post_en](/Users/sunghoon/Projects/docpack/content/jp/ep01/post_en.md:11)

ep02 EN도 `The law constrains…`로 단정한다: [post_en](/Users/sunghoon/Projects/docpack/content/jp/ep02/post_en.md:32).

재현:

```sh
rg -n '制限されています|is restricted|law constrains' content/jp/ep0{1,2,3}
```

코드 가드는 이 법적 표현과 EN 본문을 검사하지 않는다.

### 나머지 Q4 판정

- 사건명, `絶対/防ぐ/唯一/必ず安全`, 1인칭 피해담은 ep01~03 JA/EN 본문에서 발견되지 않았다.
- `topics.json`은 원래 30편의 `src`를 모두 보존하며, 신규 3편과 1·14·20 재작성, 사업자/資格確認書 우선, AI 2편의 첫 4주 배치를 반영한다.
- ep32의 `blocked_until` 유지가 삭제보다 낫다. 전략의 예정 슬롯을 추적하면서 빌드·게시만 막을 수 있다: [topics.json](/Users/sunghoon/Projects/docpack/content/jp/topics.json:261).
- ep05·ep06은 제목만으로도 발주처별 규칙을 일반화할 위험이 있으므로 “본문 전 공식 공고 1건 확인 필요”라는 자기 신고가 맞다.

자동화 가능하지만 빠진 항목은 최소한 다음이다.

- 생성된 `x_thread.md` 필수 문장 검사
- `post_en.md` 금지 표현 검사
- 미출시 기능의 영문/우회 표현 검사
- 법적 효과 표현 검사
- 이미지의 긴 변, 실제 출력 크기 검사

1인칭 피해담도 `私/私は/私の` 등의 휴리스틱으로 일부 자동화할 수 있다. 완전한 의미 판정은 아니지만 현재처럼 전부 사람에게만 맡길 필요는 없다.

---

## 「확신하지 못한다」 7건 판정

1. **notify rescue 범위 — 부분 수용.** 신청은 유실되지 않는다. 그러나 메일 실패를 능동적으로 드러내는 파생 상태가 없어 `publish_stuck`과 동급이라고 할 수는 없다.

2. **전역 분당 600건 — 근거 불충분.** 개인정보 없는 전역 상한이라는 방향은 수용 가능하지만, 수치는 측정 근거가 없고 구현도 동시 요청에서 엄격하지 않다.

3. **`sanitize`의 `v.to_s` — 안전.** 배열·중첩 객체·Parameters·upload·nil이 화이트리스트 문자열로 변환되어 새는 경로는 찾지 못했다. 개인정보 0 속성에는 문제없다.

4. **init `purpose` 이벤트 — 데이터 품질 결함.** 개인정보 결함은 아니다. 이벤트 이름을 분리하거나 `source:init|user` 같은 고정 범주를 추가하는 쪽이 해석 가능성이 높다.

5. **`/safe/jp/` 301→404 — 백로그.** 거짓 콘텐츠를 제공하지는 않지만 크롤러에는 불필요한 redirect-to-error다. 색인상 “문제없다”고 단정할 근거는 없다.

6. **Google Fonts 의존 — 재현성 백로그.** 빌드는 실패하지 않지만 동일 원고의 픽셀 결과가 환경에 따라 달라진다. 생성물을 승인·재사용할 목적이면 폰트 고정이 바람직하다.

7. **PNG/GIF/MP4 git 커밋 — 현재 규모에서는 수용.** 약 30MB는 감당 가능하며, 재생성이 비결정적이라는 사실은 오히려 승인된 산출물을 보존할 이유가 된다. 증가 추세가 커지면 LFS/릴리스 자산을 검토하면 된다.

---

## 백로그

- `/safe/jp/`의 301→404를 직접 404 또는 유효한 허브로 정리.
- 랜딩 정본 자체의 미출시 팀 기능·다중 PDF·처리 기록 홍보를 제품 상태와 별도로 재검토.
- carousel 폰트 고정 또는 빌드 manifest에 실제 사용 폰트 기록.
- 생성물 저장 정책과 저장 용량 임계치 문서화.
- `jp_landing_check.mjs`에서 CTA 클릭 이후의 `204`도 별도 확인.
- cookie 회귀 테스트에 `/api/safe_scan?locale=ja`를 직접 포함.
- `SafeEvent`의 array/nil/upload 모양을 명시적으로 회귀 테스트해 현재 안전 속성을 문서화.
