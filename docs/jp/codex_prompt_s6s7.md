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
