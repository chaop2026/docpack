# 교차검증 대조(triage) — 교차검증 (a) 3건 수정

- 대상 커밋: `a2a1934` (브랜치 `fix/blog-indexing-signals`, **미배포**)
- 외부 모델 출력 원문: [`CODEX_RESULT_2026-09-18_amber3.md`](CODEX_RESULT_2026-09-18_amber3.md)
- 투입 패키지: [`CODEX_REVIEW_PACKAGE_2026-09-18_amber3.md`](CODEX_REVIEW_PACKAGE_2026-09-18_amber3.md)
- 직전 라운드: [`CROSS_REVIEW_TRIAGE_2026-09-18_gsc3.md`](CROSS_REVIEW_TRIAGE_2026-09-18_gsc3.md)
- 🔴 **이 세션에서는 새 (a) 를 고치지 않았다.** 아래 2건은 **다음 수정 런의 입력**이다.
  (전역 규칙: 외부 지적은 검증 없이 반영하지 않고, 검증과 수정을 한 세션에 섞지 않는다.)

## 결론

| 항목 | Codex 판정 | 우리 대조 |
|---|---|---|
| A-1 잡의 배치 중단 | **부분 해소** | **동의** — 격리는 됐으나 가시화가 메일 전달 성공에 의존한다. 아래 N-1 |
| A-2 반복 슬래시 | **해소됨** | 동의 |
| A-3 미들웨어 삽입 가드 | **해소됨** | 동의 |

지적 2건 + Q1~Q10 답변 10건 = **12건 전부 분류했다.**
**새 (a) 2건** — 둘 다 우리가 ⑥ 에서 "확신 없음" 으로 올린 항목이고, 둘 다 Codex 판단이 옳다.

---

## (a) 진짜 문제 — 2건

### N-1. 발행 실패 알림이 **메일 전달 성공에 의존**한다 — **AMBER**

**Codex 지적** `[논리 오류][확신도 높음]`: `report` 는 `deliver_later` **호출만** rescue 한다.
그 뒤 별도 메일 잡에서 뷰 렌더나 SMTP 가 실패하면 이 rescue 밖이고, "건너뛴 글이 영구히
`scheduled` 로 남는 문제" 를 알릴 다른 앱 상태나 헬스체크가 없다.

**우리가 ⑥.2 에 "확신 없음" 으로 올린 그 지점이다. Codex 가 옳다 — 그리고 이 저장소에는
선례가 있다.** 코드로 확인한 것:

| 확인 | 결과 |
|---|---|
| `app/jobs/application_job.rb` | `retry_on`·`discard_on` 전부 **주석 처리된 스캐폴드 그대로** |
| `app/`·`config/`·`lib/` 전체의 `rescue_from`·`failed_executions` 처리 | **0건** |
| 프로덕션 큐 | `config.active_job.queue_adapter = :solid_queue` (`production.rb:53`) |
| 실패 잡의 종착지 | Solid Queue 기본 = 재시도 소진 후 `solid_queue_failed_executions` 행. **이 앱은 그 테이블을 어디서도 보지 않는다** |
| **SMTP 실패 선례** | **실제로 있었다** — CLAUDE.md:145, 2026-04-07 `GMAIL_PASSWORD` 가 프로덕션에서 빈 값이라 `SMTPAuthenticationError 535-5.7.8` |

즉 **가정된 실패가 아니라 이미 한 번 일어난 실패다.** SMTP 가 다시 어긋나면 발행 실패 알림은
아무도 읽지 않는 행으로 들어가고, 멈춘 글은 다시 보이지 않게 된다 — 이 수정이 닫으려던 바로
그 실패 모드다. **메일 하나에 가시화를 전부 걸었다는 것이 설계의 약점이고, 그 설계는 우리가
한 것이다.**

**AMBER 인 이유**: 현재 SMTP 는 동작한다(2026-04-04 검증). 촉발에는 두 가지가 동시에
필요하다 — ① 검증에 걸리는 예약 글이 존재 ② 그 시점에 메일 경로가 고장. 다만 ②는 전례가 있고
①은 프로덕션 DB 를 보지 않으므로 **있는지 알 수 없다**(추정하지 않는다).

**예상 수정 범위** (다음 런): 메일과 **독립적인** 채널을 하나 둔다. 후보 —
① `scheduled` 이면서 `published_at` 이 임계치보다 오래된 글을 세는 지표를 `/up` 헬스체크나
어드민 목록 상단 배너로 노출(앱 상태를 읽으므로 메일·큐에 의존하지 않는다),
② `ApplicationJob` 에 `retry_on`/`rescue_from` 을 두어 메일 잡 최종 실패를 로그·DB 에 남긴다,
③ `deliver_now` 로 바꿔 실패를 잡 안에서 잡는다(대신 잡 런타임이 SMTP 에 묶인다).
**①이 가장 튼튼하다** — "멈춘 글" 을 알림이 아니라 **상태**로 만든다. 알림은 유실되지만
상태는 유실되지 않는다.

---

### N-2. 대체된 SafeFile 시드가 **마이그레이션 결과를 되돌린다** — **AMBER (프로덕션 데이터)**

**Codex 지적** `[데이터 손실 위험][확신도 높음]`: `db/seeds/safefile_posts.rb` 는 "대체됐다" 고
주석으로 밝히면서도 **그대로 실행 가능**하고, `resume-privacy` 는 같은 슬러그를 찾아
`category: "student"` 를 다시 assign·save 한다. 본문이 이미 채워진 마이그레이션 후 DB 에서는
검증에 걸리지 않으므로 **최소한 첫 글은 `privacy` → `student` 로 되돌아간다**.

**직접 측정해 확인했다** (개발 DB):

```
before:       category=privacy   title=이력서 속 개인정보…   status=published
after seed:   category=student   ← 되돌아갔다
after migrate:category=privacy   ← 마이그레이션을 다시 돌려야 복구된다
```

**우리는 이것을 이미 관찰했고 "남는 관찰" 로 내려놨다. Codex 의 등급이 더 정확하다.**
우리는 카테고리 표시 문제로 봤지만, 실제로는 **정리된 운영 콘텐츠를 쓰기**다 —
`category` 뿐 아니라 `title_ko`·`title_en`·`meta_description_*` 를 시드의 하드코딩 값으로
덮으므로, 어드민에서 사람이 편집한 내용도 함께 사라진다. 그리고 그 쓰기는 `abort` **전에**
일어난다(항목 1 저장 → 항목 2·3 거부 → abort). 즉 "실패하는 태스크" 가 실패하기 전에
데이터를 바꾼다.

**이 커밋이 만든 문제는 아니다** — 격리 전에도 항목 1 은 저장되고 항목 2 에서 죽었으므로
결과는 같다. 다만 **우리가 그것을 보고도 보류했다는 점**이 (a) 인 이유다.

**예상 수정 범위** (다음 런): 세 선택지 중 하나를 정한다 —
① 파일 삭제 + `blog:seed_safefile_posts` 태스크 제거(마이그레이션이 소유),
② 시드가 `db/blog_privacy/*.html` 에서 본문을 읽고 **개명 후** 슬러그·`category: "privacy"` 를
쓰게 해 마이그레이션과 같은 진실을 말하게 하기,
③ 신선한 DB 에서만 동작하도록 "이미 존재하면 손대지 않는다" 로 바꾸기.
**①이 가장 단순하다** — 마이그레이션은 이미 멱등이고 개명 전/후 슬러그를 모두 찾는다.
다만 **신선한 DB 에서 이 3개 글을 만들 경로가 사라진다**(마이그레이션은 기존 레코드만 고친다) —
그래서 ②가 실질적으로는 맞을 수 있다. 결정이 필요하다.

---

## (b) 의견 차이 — 0건

이번 라운드에는 없다. Q1~Q10 중 판단이 갈린 항목이 없었다.

---

## (c) 오탐 / 해당 없음 — 8건 (Q 답변)

### C-1. Q1 — `RECORD_REJECTED` 의 경계
Codex: "타당한 경계다. `RecordNotUnique`·`StaleObjectError`·연결 장애는 격리하면 안 되는 쪽."
우리 판단과 일치. **경로 요청을 받아 실제로 측정했다** (`bin/rails runner` 로 콜백 체인을 덤프):

```
before_save       : []           ← throw :abort 로 RecordNotSaved 를 낼 콜백이 없다
around_save       : []
before_validation : [:normalize_changed_in_place_attributes, :generate_slug]
locking_column present : false (lock_version)   ← StaleObjectError 가 날 수 없다
unique db indexes : [["slug"]]
```

- `RecordNotSaved` 를 낼 경로가 현재 **없다**. 그래도 남겨둔다 — 콜백이 추가되는 날
  조용히 배치가 다시 멈추는 쪽이 나쁘다.
- `StaleObjectError` 는 `lock_version` 컬럼이 없어 **발생 불가**.
- `RecordNotUnique` 는 `slug` 유니크 인덱스가 있어 이론상 가능하지만, `update!(status:)` 는
  `slug` 를 건드리지 않으므로 이 잡에서는 발생할 수 없다. 격리 대상에서 뺀 것이 맞다.

즉 요청한 파일을 실제로 확인해도 답은 바뀌지 않았다.

### C-2. Q3 — ActiveJob 직렬화
Codex: "안전해 보인다. `errors.full_messages` 가 비어도 뷰가 `(검증 메시지 없음)` 를 출력한다."
우리 주장이 독립 확인됐다. 지적 아님.

### C-3. Q4 — `canonical_spelling` 의 반례
Codex: "일반 슬래시·빈 `PATH_INFO`·`/safety`·`/safe-x` 는 괜찮다. `SCRIPT_NAME` 보존도
단위 테스트가 있다." **반례를 찾지 못했다.** `%2F` 는 경로 테스트가 없다고 지적 —
percent-encoded 슬래시는 **중복 콘텐츠 위험이 아니다**(디코딩 주체가 서버마다 다르고,
디코딩되지 않으면 우리 정규화 대상이 아니며, 디코딩되면 `squeeze` 가 처리한다).
(b) 로도 세지 않는다 — Codex 도 지적이 아니라 경로 요청으로 적었다.

### C-4. Q5 — `/safe/sw.js/` 301 의 SW 부작용
Codex: "현재 프리캐시 목록에 `/safe/sw.js/` 가 없다. SW install 을 깨는 근거는 없다.
중복 URL 제거로 타당해 보인다." 우리 실측(프리캐시 11개 URL 전부 직접 200)과 일치.

### C-5. Q6 — `unshift` 위치
Codex: "부분적으로 타당하다. DB/AR 을 만지지 않고 path-only Location 을 내므로 Executor 앞
배치의 위험 근거는 없다." 경로 요청(프로덕션 SSL·프록시 헤더 설정)을 받아 **측정했다** —
`ActionDispatch::HostAuthorization` 은 **프로덕션 스택에 아예 없다**(`config.hosts` 가
`production.rb:85` 에서 주석 처리). SSL 앞 배치는 홉 수가 양쪽 다 2 이고, 그것을 안전하게
만드는 성질(Location 이 path-only, Host 를 읽지도 반사하지도 않음)을
**self-check 에서 테스트로 고정했다** (`test/lib/canonical_path_redirect_test.rb`,
`HTTP_HOST: evil.example.com` 주입). 지적 아님 — 근거를 보강했다.

### C-6. Q7 — ko.yml
Codex: "기존 키를 가린다는 근거는 없다. 둘 다 둔 것은 lookup 경로상 방어적이다.
공백 제거는 표시 품질 문제." 우리 판단과 일치(키 충돌 0건 실측).

### C-7. Q9 — 공허한 단언
Codex: "크게 보이지 않는다. 로그 formatter 는 severity 를 실제 문자열에 넣는다. 연결 장애
스텁은 비격리 예외 전파 경로를 탄다. 통합 테스트 `//` 는 수정 전 실패 실측과 함께 제시됐다."
self-check 에서 우리가 고친 세 지점을 독립적으로 확인했다. 지적 아님.

### C-8. Q8/Q10 중 수용된 부분
`auto_generate_blog_post_job` 의 `topic.update!` 미격리(런당 글 1개), `blog:generate` 계열의
exit 0(사람 실행 전제) 은 **수용 가능**으로 확인. Q8 은 "자동화 근거가 부족해 지적까진 보류"
라고 했는데 — 그 지적이 정당하다. 아래 자체 평가 참조.

---

## 이번 라운드 자체 평가

- **패키지에 잡·메일러·레이크·시드·SW 를 전부 넣었다.** 직전 라운드의 빈틈(잡 계층 누락 →
  가장 값진 지적이 "경로 요청" 으로 늦게 나옴)을 고친 것이다. 이번 "경로 요청" 은 3건이었고
  (모델 콜백/락 · `%2F` 통합 테스트 · 프로덕션 SSL 설정) **셋 다 받아서 확인했고 답이
  바뀌지 않았다** (C-1·C-3·C-5).
- **우리가 ⑥ 에 올린 "확신 없음" 7개 중 2개가 (a) 로 확정됐다** (⑥.2 → N-1, ⑥.6 → N-2).
  확신 없는 지점을 숨기지 않고 명시하는 것이 실제로 작동했다 — 둘 다 스스로는 (a) 로
  올리지 못했던 것이다.
- **우리 문서에 사실 오류 1건이 있었고 이 라운드에서 잡아 고쳤다**: CLAUDE.md·DECISIONS.md 가
  `blog:seed_safefile_posts`·`blog:migrate_privacy` 를 "CLAUDE.md 의 Post-deploy commands
  목록에 있다" 고 적었으나, 그 목록(CLAUDE.md:138-141)에는 `blog:seed_topics`·
  `blog:publish_test`·`blog:verify_autopublish` 셋뿐이다. `migrate_privacy` 는 **자기 파일
  헤더 주석**에 `kamal app exec` 실행법을 적어두고 있고, `seed_safefile_posts` 는 어디에도
  배포 후 단계로 문서화돼 있지 않다. `abort` 결정 자체는 유지하되(둘 다 `kamal app exec`
  후보이고 하나는 스스로 그렇게 문서화한다) **인용한 근거를 정정했다.**

## 다음 런 작업 목록 (이 문서의 산출물)

| # | 항목 | 위험도 | 파일 |
|---|---|---|---|
| 1 | 멈춘 글을 **메일과 무관한 상태**로 노출 (헬스체크·어드민 배너·잡 최종실패 기록 중 택1) | AMBER | `app/jobs/application_job.rb`, 어드민 또는 `/up` |
| 2 | `db/seeds/safefile_posts.rb` 의 소유권 결정 (삭제 / 본문·개명슬러그로 재작성 / 존재 시 미변경) | AMBER (프로덕션 데이터) | `db/seeds/safefile_posts.rb`, `lib/tasks/blog.rake` |

⛔ 전부 **이번 세션에서 고치지 않았다.**
**2번은 프로덕션에서 이 시드를 돌리기 전에 처리해야 한다** — 돌리면 정리된 글 1개의
카테고리·제목·메타 설명이 시드의 하드코딩 값으로 덮인다(실측). 배포 자체를 막지는 않는다.
