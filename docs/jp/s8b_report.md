# S8b 보고 — 교차검증 RED 2건 수정 (X 게시 크래시 내구성 + import 승인 보호)

시작 2026-10-25 13:37 KST · 종료 2026-10-25 15:05 KST (약 1시간 30분)
브랜치 `main`. **미배포·미푸시·실제 게시 0건.** 프로덕션 DB 미접촉. `X_API_DRY_RUN=1` 고정.

입력: [`s8b_prompt.md`](s8b_prompt.md) · 근거 [`codex_review_s8_2026-10-25.md`](codex_review_s8_2026-10-25.md) (Q2·Q3 **RED**, Q1·Q4·Q5 AMBER)

| 검증 | 결과 |
|---|---|
| `bin/rails test` | **354 runs / 2,287 assertions / 0 failures** (직전 333/2,200) · **연속 5회 동일** |
| 골든 `run.mjs` | **557/557** 무변화 |
| `check_matrix` | 188 triple + 10 legal pair |
| `jp_landing_check` | **128/128** |
| SW 장애주입 | **9/9** |
| `canonical_sweep` | **6/6** |
| E-1 스냅샷 | 25 → **38 항목**. **기존 25개 바이트 동일**(변경 0·누락 0) |
| rubocop | **86** — 베이스라인 동일 |
| brakeman | **8** — 베이스라인 동일 |
| 마이그레이션 롤백 왕복 | 성공, `schema.rb` 바이트 동일 |
| 프로덕션 DB | **미접촉** |

---

## 1. RED Q3 — 크래시 내구성 (수용 조건)

### 1-1. 먼저 재현했다

리뷰의 지적("`with_lock`이 `run` 전체를 한 트랜잭션으로 감싸므로 `update_column`은 커밋이 아님")을
받아들이기 전에 측정했다. 스텁이 seq 3의 API 성공 **직후** `Interrupt` 를 던진다:

```
CRASHED: process killed right after the API returned seq 3
state="pending"
tweets=[]
```

**지적보다 나빴다.** 트윗 3개가 타임라인에 올라갔는데 DB 에는 id 가 아니라 **배열 자체가 없다.**
다음 실행은 1·2·3 을 전부 다시 올린다. 코드의 주석은 바로 그 줄에서
「written FIRST, and alone … a crash one line later must not lose it」 라고 말하고 있었는데,
트랜잭션 안에서 **쓰기는 커밋 전까지 사실이 아니고** 그 커밋은 루프 끝에 있었다.

### 1-2. 구조: 잠금 → **소유권 선점**

| | 전 | 후 |
|---|---|---|
| 잠금 범위 | `with_lock { 루프 전체 }` | `with_lock { 상태·승인 검사 + 토큰 기록 }` → **커밋하고 나온다** |
| 전송 루프 | 트랜잭션 **안** | 트랜잭션 **밖** |
| 트윗당 쓰기 | 1회(커밋 안 됨) | **2회 독립 커밋** — ⓐ `sending` ⓑ `tweet_id`+`done` |
| 쓰기 조건 | 없음 | `WHERE package->'x'->>'worker_token' = ?` — 토큰이 바뀌었으면 0행 → `ClaimLost` 로 즉시 중단 |
| 쓰기 범위 | 패키지 전체 read-modify-write | `jsonb_set(package,'{x}',…)` — **형제 키를 덮지 않는다** |

`sending` 이 핵심이다. API 를 **부르기 전에** 커밋하므로, 죽은 프로세스가
「아예 시작도 안 했다」와 구별된다 — 그 구별이 없으면 재전송을 부른다.
재실행 시 `sending` 인 seq 는 **`unknown` 으로 승격**하고 멈춘다. 결과가 불명인 것이 사실이고,
「안 보냈을 것」이라고 판단하면 살아 있는 트윗을 다시 올린다.

**선점 TTL 30분**: 크래시한 워커도 신선한 claim 을 남기므로, 다른 워커는 TTL 이 지나야 가져간다.
6트윗 × 45초 read timeout = 최악 5분이므로 30분을 넘긴 것은 **느린 게 아니라 죽은 것**이다.

### 1-3. 같은 프로브를 새 코드에 (재전송 0 증거)

```
CRASHED: process killed right after the API returned seq 3
AFTER CRASH  state="running"
AFTER CRASH  tweets=[[1,"done","id-1"], [2,"done","id-2"], [3,"sending",nil], [4,"pending",nil], …]

--- 재실행: 트윗을 하나라도 보내면 raise 하는 클라이언트 ---
AFTER RERUN  (신선한 claim → 가져가지 않음, 아무것도 안 건드림)

--- claim 을 45분 전으로 늙힌 뒤(= 죽은 워커) 재실행 ---
AFTER STALE-CLAIM RERUN  state="unknown"
AFTER STALE-CLAIM RERUN  tweets=[[1,"done","id-1"], [2,"done","id-2"], [3,"unknown",nil], …]
```

확정된 id 2개가 **살아남았고**, 재전송은 **0건**이며, 결과 불명인 1개만 사람에게 넘어간다.

### 1-4. 테스트 (`test/jobs/x_publish_job_test.rb` 17 → 26)

신규 9개. `Interrupt` 는 `StandardError` 가 아니므로 잡의 어떤 rescue 도 잡지 않는다 —
**프로세스가 사라지는 것**을 모사한다. 재실행에는 **보내면 실패하는 클라이언트**(`ForbiddenClient`)를
쓴다. 「0건 전송」을 세는 대신 **보이게** 만든 것이다 — 0 은 다른 이유로도 0 일 수 있다.

| 테스트 | 고정하는 것 |
|---|---|
| API 성공 직후 크래시 → 재실행 | 확정 id 보존, **재전송 0**, seq 3 `unknown` |
| API 호출 **직전** 크래시 → 재실행 | 똑같이 `unknown` — 「안 보냈다」고 **판단하지 않는다** |
| 크래시發 unknown | 타임아웃과 **동일하게** 사람에게 메일 |
| 사람이 해결 후 | 다음 seq 부터 재개, 사람이 적은 id 에 체인 |
| 신선한 claim | **가져가지 않는다** |
| 5분 vs 30분+ | 전자 불가, 후자 가능 |
| 토큰이 바뀐 쓰기 | `ClaimLost`, 0행 |
| 승인 지문 없음 | **blocked** |
| 드라이런 | 승인 검사를 **우회하지 않는다** |

**실효성 — 옛 잡으로 같은 테스트를 돌렸다: 26개 중 9개 실패/에러.** 새 잡에서 0.

### 1-5. 2워커 테스트 (`test/jobs/x_publish_concurrency_test.rb`, 신규)

`use_transactional_tests = false`. 트랜잭션 픽스처 아래에서는 두 번째 스레드가 첫 번째의
커밋되지 않은 행을 볼 수 없으므로, 「동시성 테스트」가 사실은 **서로 다른 DB 를 보는 두 스레드**가 된다.
정리는 명시적으로 한다.

- 2스레드 × 각자 커넥션 → **전송 총합 = 5**(트윗 4 + 영어 답글), 중복 0, id 중복 0.
- 패배자는 **토큰을 덮지 않는다.**
- ⚠️ **공허 방지**: 두 번째 워커가 커밋된 claim 을 **실제로 보았는지** 단언한다. 안 보였다면 그 실행은
  경쟁을 재현하지 못한 것이고, 조용히 통과하면 안 된다.
- **실효성**: 신선-claim 가드를 끄면 **실패**한다.

> 🔴 **그 공허 방지 단언이 실제로 발화했고, 내 테스트가 틀렸다는 뜻이었다.**
> 처음엔 `sleep 0.05` 뒤에 두 번째 워커를 띄웠다. 단독 실행은 통과, 전체 병렬 스위트에서는 실패 —
> 「두 번째 워커가 커밋된 claim 을 보지 못했다」. 타이머를 **폴링**으로 바꿔도 **매번** 5초 데드라인을
> 때렸다. 원인은 타이밍 흔들림이 아니라 **창 자체가 닫혀 있던 것**이다: 잡 전체가 0.1초 만에 끝나고
> `finish!` 가 `worker_token` 을 지우므로, 무엇이 보러 갔을 때는 창이 열렸다 닫힌 뒤였다.
> → `Queue` 2개로 **래치**를 만들어 첫 워커를 전송 루프 **안에서 붙잡는다**. 창이 희망이 아니라
> 사실이 된다. 이후 전체 스위트 5회 연속 녹색.
> **타이밍에 기대는 동시성 테스트는 「경쟁을 재현했다」와 「운이 좋았다」를 구별하지 못한다.**

⚠️ `minitest` 의 `stub` 은 **스레드 안전하지 않다** — 두 스레드가 같은 싱글턴 메서드를 바꿨다 되돌리면
`undefined method 'new' for class XClient` 가 난다(실측). 스텁은 두 스레드를 **감싸서 한 번만** 건다.

### 1-6. 승인 지문 fail-closed

`approved_version` 이 **없으면 false → blocked**. 전에는 true 였다(「어드민을 거치지 않은 패키지」).
**정확히 반대다** — 승인 기록이 없는 패키지는 아무도 승인하지 않은 패키지이고, 이 잡이 절대 하면 안 되는 일이
미승인 원고를 공개 계정에 올리는 것이다. **드라이런도 예외가 아니다**: 승인 검사를 건너뛰는 드라이런은
실제로 돌 경로를 검증하지 않으므로, 테스트가 출하물이 아닌 다른 것을 증명하게 된다.

부수: `rake blog:x_pending` 이 `approved_at` 없는 패키지를 **enqueue 하지 않는다**. 잡이 어차피 막지만,
막으면 `x.state='blocked'` 가 남아 「뭔가 잘못됐다」로 읽힌다 — 사실은 「아직 승인 안 했다」다.

---

## 2. RED Q2 — 승인 보호를 서비스 안으로

### 2-1. 검사가 **호출부**에 있었다

rake 가 `status == 'draft'` 를 읽고, 그 사이 Justin 이 承認 을 누르고, import 가 승인된 패키지를
덮어쓴다 — 어드민은 여전히 초록 체크를 보여준다. **호출부의 가드는 그 호출부를 지킨다.**

이제 `JpImport#apply!` 가 `post.with_lock` 안에서 재검사한다. `SELECT … FOR UPDATE` 이므로
승인이 우리 읽기와 쓰기 사이에 들어오면 **기다려야 하고**, 먼저 들어왔으면 **우리를 막는다**.
rake 의 사전 검사는 빠른 실패와 읽을 만한 메시지를 위해 남겼지만 **판정자는 서비스**다.

반환값 `:applied` / `:unchanged` / `:conflict` — 셋 다 오류가 아니라 「이 import 는 써야 하는가」에 대한
정상적인 답이라 예외가 아니라 값이다.

### 2-2. `:unchanged` — 같은 바이트면 **완전 무쓰기**

`content_hash` 와 가드 판정이 모두 같고 기록된 충돌이 없으면 **아무것도 쓰지 않는다** —
행도, 자산도, `updated_at` 도. 같은 바이트를 다시 쓰면 Active Storage blob 이 churn 하고
`updated_at` 이 「본문이 마지막으로 바뀐 때」에 대해 거짓말을 한다.

가드 판정을 조건에 **포함**한 이유: 규칙은 에피소드 폴더에 없는 파일(`guard_rules.json`)에 산다.
규칙을 조이면 **원고가 한 글자도 안 움직여도** 위반으로 다시 표시할 수 있어야 한다.

### 2-3. 계약 문구 정정

「승인된 패키지 재import = **아무것도 쓰지 않는다**」는 **사실이 아니었다** — `record_conflict!` 는 쓴다.
`jp_import.rb` 상단과 `content.rake` 헤더를 정확한 문장으로 바꿨다:

> 본문·제목·자산·상태·승인 지문은 **쓰지 않는다.**
> `package.import_conflict` **1키**는 쓴다 — 그것이 무쓰기의 **명시적 예외**이고,
> 어드민이 「뭔가 낡았다」 대신 **어느 버전이 거부됐는지** 말할 수 있는 이유다.

### 2-4. `RecordInvalid` rescue 를 좁혔다

전: 「오류가 났고 행이 있으면 경쟁에서 졌다」. **빈 제목으로 거부된 것도 같은 모양**이라,
내용 오류가 성공 보고로 둔갑했다.
후: `e.record.errors.details` 가 **`{slug: [{error: :taken}]}` 뿐일 때만** 흡수. 그 외 re-raise.
`RecordNotUnique` 는 DB 가 거부한 것이고 posts 의 unique 인덱스는 slug 와 (track, ep) 뿐이라 그대로 둔다.

**테스트가 가장 날카로운 경우를 고정한다**: `slug` 의 **`:blank`**. 속성은 같고 오류 종류만 다르다 —
속성만 보는 rescue 도, 「행이 있다」만 보는 rescue 도 이것을 삼킨다.

> ⚠️ 처음 쓴 테스트는 빈 `title_ja` 로 재현하려 했는데 **아무 예외도 안 났다**. JP 글은 draft 로
> 생성되고 발행 불변식은 draft 에 적용되지 않기 때문이다 — 리뷰가 말한 바로 그 구멍이고,
> 그래서 §2-5 의 입력 검증이 필요하다.

### 2-5. 입력 검증 — 「패키지가 없다」와 「규칙을 어겼다」는 다른 답

| | 묻는 것 | 결과 |
|---|---|---|
| `JpEpisodeSource#validate!` | 여기에 에피소드가 **있기는 한가** | import **거부**, exit **1** |
| `JpContentGuard` | 글쓰기 규칙을 지키는가 | import **됨**, exit **0**, 승인 버튼 비활성 |

추가한 검사: 해결된 `title_ja` 공백 · `body_ja` 가 **산문 없이** 렌더됨(태그만) · `x_thread` 0개.
원본 파일이 아니라 **실제로 저장될 값**을 본다 — frontmatter 만 있는 파일도, 아무것도 렌더되지 않는
마크다운도 「파일은 비어 있지 않다」를 통과한다.

**실측한 종료 코드 3종**:
```
exit=0  ep01: unchanged — disk and row already agree (content_hash=4164a57e0f9d). Nothing was written.
exit=2  ep2: 承認された(または公開段階の)パッケージと衝突 — admin で 差し戻す してから再実行してください
exit=1  ep3: /rails/content/jp/ep03/post_ja.md has no frontmatter title
```

### 2-6. 테스트 (`jp_content_track_test.rb` 20 → 30)

| 테스트 | 고정하는 것 |
|---|---|
| **다른 본문**으로 승인된 패키지 import | 본문·제목·자산·지문 **불변**, conflict 가 거부된 해시를 기록 |
| **사전 검사 통과 직후 승인** | 서비스가 잠금 아래에서 재검사 → `:conflict` (= Q2 가 지적한 바로 그 창) |
| 같은 해시 재import | `updated_at` · package · **blob id** 전부 불변 |
| 가드 판정만 바뀜 | `:applied` — 파일이 안 움직여도 다시 쓴다 |
| slug `:blank` | **re-raise** |
| slug `:taken` | 흡수(승자 행이 실제로 있을 때만) |
| validate! 3종 | 공백 제목 · 산문 없음 · 트윗 0 |
| 가드 위반 | validate! 통과 + 승인 비활성 + 행 존재 |

**실효성 — 옛 `JpImport`·옛 `validate!` 로 돌리면 30개 중 9개 실패/에러.** 둘 다 RED 시나리오 포함.

---

## 3. AMBER 처리

### Q1 — 중복 검증 (측정 결과 **사용자에게 보이지 않았다**)
`validates :title_ko` 와 `primary_title_and_body_present` 가 둘 다 `:title_ko, :blank` 를 더한다.
**측정**: Rails 는 동일 (속성, 종류) 쌍을 **중복 제거**한다 — `errors.where(:title_ko).size == 1`,
`full_messages` 도 1줄. 그래서 **결함이 아니라 중복**이었다. 그래도 제거한 이유는 다음 읽는 사람이
어느 규칙이 효력을 갖는지 알아내려고 같은 측정을 다시 하지 않아도 되게 하기 위해서다.
JA 제목만 이 메서드가 본다. **KO 메시지 바이트 동일** 확인:
`["제목(한국어)을(를) 입력해 주세요", "본문(한국어)을(를) 입력해 주세요"]`.

부수: JA 속성이 `"Title ja을(를) 입력해 주세요"`(영어 humanize + 한국어 조사)로 나오고 있었다 →
`ko.yml` 에 `title_ja`·`body_ja`·`subtitle_ja`·`meta_description_ja`·`primary_locale`·
`content_track`·`content_ep` 추가. 어드민 폼과 발행 실패 메일이 읽는 문자열이다.

### Q4 — 마이그레이션 타임아웃 + 롤백 왕복
`up` 첫 두 줄에 `SET LOCAL lock_timeout='5s'`, `SET LOCAL statement_timeout='30s'`.
`ADD COLUMN` 은 ACCESS EXCLUSIVE 를 잡고, **큐에 서면 그 뒤의 SELECT 가 전부 그 뒤에 선다** —
느린 리더 하나가 1초짜리 마이그레이션을 사이트 전체 정지로 만든다. 5초면 배포가 **실패하고 재시도**된다.
`SET LOCAL` 이라 이 마이그레이션 트랜잭션이 끝나면 되돌아간다.

**롤백 왕복 실측**(JP 행을 지운 상태, 개발 DB):
```
db:rollback → 컬럼 8개 제거, Post 의 ja/primary_locale/content_*/package 전부 사라짐
db:migrate  → execute SET LOCAL … ×2, assert 0 rows ×2 (posts 3행 / blog_topics 100행)
              컬럼·부분 unique 인덱스 복원, KO 글 3편 무사
git diff db/schema.rb → (출력 없음 = 바이트 동일)
```
`down` 주석에 **JP 행 생성 전/후**를 구분해 적었다: 행이 생긴 뒤의 down 은 `package.x.tweets` —
**어느 트윗이 이미 타임라인에 있는지에 대한 유일한 기록** — 까지 지운다. 덤프를 떠도 **트윗은 되돌릴 수 없다.**

### Q1(E-1) — 픽스처 2모양
| 추가 | 고정하는 것 |
|---|---|
| `english_only_draft` (body_en 있음 / body_ko 없음 / draft) | `translated(en)=true` 인데 `indexable_locales=[]`, `/en` 은 `noindex,follow` — **발행 상태 게이트가 이 모양에서도 성립** |
| OLD_BLOG_SLUGS 8 URL | `rrn-masking`·`contract-checklist` × 4 로케일 → **301 + Location** |

**기존 25항목 바이트 동일**(변경 0·누락 0), 13개 추가 → **38항목**, 하한 36.

리다이렉트 목록은 **라우팅 테이블에서 열거**한다. `OLD_BLOG_SLUGS` 는 `draw` 블록 안에 있어
테스트에서 도달할 수 없고(실측), 손으로 베낀 목록은 「두 목록이 어긋난다」 문제다 —
세 번째 rename 이 생기면 스냅샷이 조용히 둘만 덮는다. 0개면 **raise** 한다.

> ⚠️ **처음 추가한 픽스처가 기존 가드를 깼다.** 리다이렉트 **대상** 슬러그(`resident-number-masking`)에
> 글을 두었더니 `PrivacyGuideOwnershipTest` 가 8건 실패했다 — 그 슬러그는 `blog:migrate_privacy` 의
> 소유이고, 그 테스트는 「태스크 실행 전 DB 에 없어야 한다」를 단언한다.
> **대상 글은 넣지 않기로 했다.** 회귀할 수 있는 신호는 301 자체이고 그건 8개 전부 고정돼 있다.
> 기존 소유권 가드가 여기 단언 하나보다 가치 있다. 픽스처 파일에 그 이유를 적었다.

---

## 4. 변경 파일

| 파일 | 변경 |
|---|---|
| `app/jobs/x_publish_job.rb` | **재작성** — claim/send 분리, 토큰 조건부 `jsonb_set` 쓰기, `sending`→`unknown`, fail-closed 지문 |
| `app/services/jp_import.rb` | `apply!` 가 잠금 아래에서 판정, `:applied/:unchanged/:conflict`, rescue 좁힘, 계약 문구 정정 |
| `app/services/jp_episode_source.rb` | `validate!` 에 해결값 기준 입력 검증 3종 |
| `app/models/post.rb` | `primary_title_and_body_present` 중복 제거(JA 제목만) |
| `db/migrate/2026…_add_jp_content_track.rb` | `lock_timeout`·`statement_timeout`, `down` 의 데이터 소실 경고 |
| `lib/tasks/content.rake` | 종료 코드 문서 정정, `:unchanged`/`:conflict` 처리, validate! 를 exit 1 로 |
| `lib/tasks/jobs.rake` | `x_pending` 이 미승인 패키지를 enqueue 하지 않음 |
| `config/locales/ko.yml` | JA·트랙 속성명 7개 |
| `test/jobs/x_publish_job_test.rb` | 17 → **26** |
| `test/jobs/x_publish_concurrency_test.rb` | **신규** 2 (비트랜잭션, 2커넥션) |
| `test/integration/jp_content_track_test.rb` | 20 → **30** |
| `test/integration/blog_seo_snapshot_test.rb` · `test/fixtures/posts.yml` · `blog_seo_snapshot.json` | E-1 25 → 38 |

---

## 5. 배포 전 체크리스트 (s8_report §8 ③ 을 **대체**)

> 배포는 **Justin 만** 합니다. 아래는 순서대로 실행하세요.

### ⓪ 배포 직전 백업 — 먼저

> **[새 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac, 일반 터미널

```
ssh root@<프로덕션호스트>
```

> **[기존 터미널]** 위 ssh 세션 안(프롬프트 `root@...#`) — 원격 서버

```
docker exec -i $(docker ps -qf name=docpack-db) pg_dump -U docpack docpack_production | gzip > ~/docpack_pre_s8b_$(date +%Y%m%d_%H%M).sql.gz && ls -lh ~/docpack_pre_s8b_*.sql.gz
```

마이그레이션의 `down` 은 JP 행이 생긴 뒤에는 **데이터 소실**입니다(`package.x.tweets` = 어느 트윗이
이미 올라갔는지에 대한 유일한 기록). 덤프를 떠도 **트윗은 되돌릴 수 없습니다** — 백업은 DB 용이지
타임라인 용이 아닙니다.

### ① recurring 작업이 실제로 등록됐는가

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac, 일반 터미널

```
kamal app exec --reuse 'bin/rails runner "puts SolidQueue::RecurringTask.pluck(:key, :schedule).inspect"'
```

`auto_generate_jp` 가 보이고 schedule 이 `every Saturday at 0am Asia/Seoul` 이어야 합니다.
**보이지 않으면** Solid Queue scheduler 가 새 `recurring.yml` 을 아직 안 읽은 것입니다 —
worker 컨테이너를 재시작하세요.

다음 실행 시각까지 확인:

```
kamal app exec --reuse 'bin/rails runner "t=SolidQueue::RecurringTask.find_by(key: %q{auto_generate_jp}); puts t ? t.next_time.in_time_zone(%q{Asia/Seoul}).to_s : %q{NOT REGISTERED}"'
```

토요일 00:00 KST 가 아니면 멈추고 확인하세요.

### ② worker 환경에 `X_API_DRY_RUN=1` 이 실제로 적용됐는가

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac, 일반 터미널

```
kamal app exec --reuse 'bin/rails runner "puts({dry_run_env: ENV[%q{X_API_DRY_RUN}], effective: XClient.dry_run?, creds: XClient.credential_report}.inspect)"'
```

🔴 **`effective: true` 가 아니면 배포를 멈추세요.** `credential_report` 는 값이 아니라
`present?`/`length` 만 출력합니다(테스트로 고정). 키 4개가 아직 없으면 `dry_run?` 은 자동으로 true 입니다.

⚠️ **web 컨테이너에서 확인한 값은 worker 에 대한 증거가 아닙니다.** `SOLID_QUEUE_IN_PUMA=true` 라
같은 프로세스지만, 그 설정이 바뀌면 둘이 갈라집니다. 위 명령이 보는 것은 app 컨테이너입니다.

### ③ 최종 이미지에서 콘텐츠 파일이 UID 1000 으로 읽히는가

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac, 일반 터미널

S8 에서 `public/safe/brand/` 가 700 권한이라 프로덕션에서 전부 404 날 뻔했습니다(dev 는 root 라
보이지 않았음). 같은 함정을 콘텐츠 파일에 대해 확인합니다:

```
docker run --rm --user 1000:1000 --entrypoint sh $(grep -m1 'image:' config/deploy.yml | awk '{print $2}'):latest -c 'ls -la content/jp/ep01 && head -c 80 content/jp/guard_rules.json && echo OK'
```

`Permission denied` 가 나오면 `chmod -R a+rX content/jp public/safe/brand` 후 재빌드하세요.

### ④ 브랜드 아이콘이 200 인가

> **[읽기만]** 브라우저 또는 아래 한 줄 — 로컬 Mac

```
for f in icon-192.png icon.svg og_1200x630.png favicon.ico; do printf '%s ' "$f"; curl -s -o /dev/null -w '%{http_code}\n' "https://slimfile.net/safe/brand/$f"; done
```

전부 `200` 이어야 합니다.

### ⑤ KO 블로그 — **두 모양을 구별해서** 확인

> **[읽기만]** 시크릿 창 — 로컬 Mac

S8 보고서 §8 ③ 은 「`/en` 은 noindex」라고 적었는데 **`body_en` 이 있는 글에는 틀립니다**
(교차검증 Q5). 두 모양을 각각 봐야 합니다:

**(가) `body_en` 이 없는 글** — 라이브 42편 전부가 이 모양입니다. 예: `/blog/resume-privacy`

| URL | 기대 |
|---|---|
| `/blog/<slug>` | canonical = 자기 자신, **robots 태그 없음** |
| `/en/blog/<slug>` | **`noindex,follow`**, canonical = `/blog/<slug>` |
| `/ja/blog/<slug>` | **`noindex,follow`**, canonical = `/blog/<slug>` |

**(나) `body_en` 이 있는 글** — 현재 라이브에는 **없을 수 있습니다**. 있으면 확인하고, 없으면
「해당 없음」으로 적으세요(없는 것을 확인한 것도 결과입니다).

| URL | 기대 |
|---|---|
| `/blog/<slug>` | canonical = 자기 자신, robots 없음 |
| `/en/blog/<slug>` | **canonical = 자기 자신**, **robots 없음**(= 색인 가능) |
| `/ja/blog/<slug>` | `noindex,follow`, canonical = `/blog/<slug>` |

어느 글이 어느 모양인지:

```
kamal app exec --reuse 'bin/rails runner "puts Post.published.where(primary_locale: %q{ko}).map { |p| [p.slug, p.body_en.present? ? %q{HAS body_en} : %q{ko only}] }.inspect"'
```

### ⑥ 과거 slug 301

> **[읽기만]** 로컬 Mac

```
for u in /blog/rrn-masking /blog/contract-checklist /ja/blog/rrn-masking; do printf '%s -> ' "$u"; curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://slimfile.net$u"; done
```

전부 `301` 이고 Location 이 각각 `resident-number-masking` / `contract-sharing-checklist` 이며
**로케일 프리픽스가 보존**되어야 합니다.

### ⑦ 막힌 것이 없는가

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac, 일반 터미널

```
kamal app exec --reuse 'bin/rails blog:stuck' ; echo "exit=$?"
```

`exit=0` 이어야 합니다. 0 이 아니면 출력이 무엇이 막혔는지(발행 / X 스레드 / 미승인 패키지) 말해줍니다.

```
kamal app exec --reuse 'bin/rails jobs:failed' ; echo "exit=$?"
```

### ⑧ JP 패키지가 실제로 들어갔는가

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac, 일반 터미널

```
kamal app exec --reuse 'bin/rails runner "Post.jp.order(:content_ep).each { |p| puts [p.content_ep, p.slug, p.status, p.guard_violations.size].inspect }"'
```

배포만으로는 JP 글이 생기지 않습니다 — import 는 맥에서 돌리고 커밋한 **코드**만 배포됩니다.
프로덕션에 ep01~03 을 넣으려면 배포 후:

```
kamal app exec --reuse 'bin/rails content:jp_import[1]' && kamal app exec --reuse 'bin/rails content:jp_import[2]' && kamal app exec --reuse 'bin/rails content:jp_import[3]'
```

---

## 6. 남는 공백

| # | 항목 |
|---|---|
| B-1 | **X 요금제·월 쓰기 한도·미디어 업로드 권한 미확인** — 확인 전까지 `X_API_DRY_RUN=1` 유지 |
| B-2 | 크래시 후 스레드는 **30분** 멈춘다(claim TTL). 안전한 기본값이지만, 월요일 12:00 JST 에 죽으면 12:30 까지 재개되지 않는다. `x_stuck` 유예가 2시간이라 알림은 그보다 늦다 |
| B-3 | `write_x!` 는 `x` 서브트리를 통째로 다시 쓴다(`jsonb_set`). 형제 키는 안전하지만 **같은 토큰을 든 두 쓰기**가 겹치면 뒤엣것이 이긴다 — 토큰 소유자는 한 명이므로 현재 발생 불가 |
| B-4 | ep04~33 본문 미작성(33편 중 3편) |
| B-5 | `JpMarkdown` 은 좁은 서브셋 — 밖의 문법은 **조용히 평문**이 된다 |
| B-6 | 본문 분량 1,500~2,200자는 `limits` 에 값만 있고 미강제(켜면 세 편 다 막힌다) |
| B-7 | `utm_source` 는 배포 후에만 쌓인다 — 배포 전 주차의 P16 을 이 표로 판정하지 말 것 |
| B-8 | **일본 변호사 검토는 여전히 없다** |

**S8B_DONE**
