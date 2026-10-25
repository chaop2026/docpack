# S8c 보고 — X 게시 잔여 결함 2건 (unknown 기록 원자화 · resume 범위 한정 · finish 원자화)

시작 2026-10-25 14:27 KST · 종료 2026-10-25 15:20 KST (약 55분)
브랜치 `main`. **미배포·미푸시·실제 게시 0건.** 프로덕션 DB 미접촉. `X_API_DRY_RUN=1` 고정.

입력: [`s8c_prompt.md`](s8c_prompt.md) · 근거 [`codex_review_s8b_2026-10-25.md`](codex_review_s8b_2026-10-25.md) (Q3' **RED**, Q2' AMBER)

| 검증 | 결과 |
|---|---|
| `bin/rails test` | **367 runs / 2,348 assertions / 0 failures** (직전 354/2,287) · 연속 5회 |
| 골든 `run.mjs` | **557/557** 무변화 |
| `check_matrix` | 188 triple + 10 legal pair |
| E-1 스냅샷 | **38/38** 무변화 |
| `jp_landing_check` | **128/128** |
| SW 장애주입 | **9/9** |
| `canonical_sweep` | **6/6** |
| rubocop | **86** — 베이스라인 동일 |
| brakeman | **8** — 베이스라인 동일 |
| 프로덕션 DB | **미접촉** |

---

## 1. 먼저 재현했다 (둘 다 실재)

### 1-1. RED — unknown 기록의 분리 쓰기가 **살아 있는 트윗을 재게시**했다

`handle_indeterminate` 가 ① `mark_tweet!(seq→unknown)` ② `write_x!(state→unknown,
resume_requested→false)` 를 **두 번** 쓴다. ① 과 ② 사이에서 크래시시키고, 그 시점에
`resume_requested` 가 **이전의 무관한 사람 결정**으로 true 인 상태를 만들었다:

```
CRASHED:       killed between the two writes
STATE AFTER:   x.state="running" resume_requested=true
TWEETS AFTER:  [[1,"done"],[2,"done"],[3,"unknown"],[4,"pending"],[5,"pending"],[6,"pending"]]
--- TTL 경과 후 새 워커 선점 ---
RESENT COUNT:  4  ["t3", "t4", "t5", "en reply"]
FINAL:         x.state="done"
```

**결과가 불명이던 t3 가 다시 올라갔고, 스레드는 `done` 으로 끝났다.** 아무도 몰랐을 것이다.

### 1-2. AMBER — `finish!` 가 「done 인데 posted 없음」을 만들고 **자가 복구하지 못했다**

```
CRASHED:     killed after x.state=done, before posted
HALF STATE:  x.state="done" posted=nil url="https://x.com/safefile_jp/status/id-1"
SELF-HEAL?:  posted=nil  api_calls=0
x_stuck?:    false  (state=done)
```

`done` 은 `x_stuck` 이 아니고 `claim!` 도 재처리하지 않으므로 **영원히 그 상태로 남는다.**
어떤 채널도 보고하지 않는다.

---

## 2. 수정

| 함수 | 전 | 후 |
|---|---|---|
| `write_x!` | `attrs` 만 | `write_x!(post, token, attrs, tweet_patches: {seq => {...}})` — 스레드 상태와 트윗 상태를 **한 UPDATE** 로 |
| `mark_tweet!` | 독립 UPDATE | `write_x!` 의 얇은 래퍼 |
| `handle_indeterminate` | 2 UPDATE | **1 UPDATE** |
| `promote_sending_to_unknown!` | N+1 UPDATE | **1 UPDATE** |
| `fail_tweet!` | 2 UPDATE | **1 UPDATE** |
| `finish!` | `write_x!` + 토큰 조건 **없는** `update_column(posted)` | `jsonb_set(jsonb_set(package,'{x}',…),'{posted}',…)` **1 UPDATE**, 토큰 조건부, 0행이면 `ClaimLost` |
| `claim!` | — | `x.state=='done' && posted.x != true` → **finish 만 재실행**(API 호출 0) |
| 재개 권한 | `resume_requested` (boolean) | **`resume_seqs: [N, …]`** |
| `JpApproval#approve!` | `Post.transaction`, reload 없음 | `post.with_lock { post.reload; 검사; version_for }` |

### 2-1. 왜 boolean 이 **결함**이었나 (스타일 문제가 아니다)

`resume_requested` 는 「unknown 을 지나가도 된다」를 일반적으로 허가했다. 「트윗 3을 다시
보내도 된다」가 아니다. 그래서 한 번 재개된 스레드는 **나중에 불명이 된 다른 트윗**도 통과시켰고,
그게 위 재현의 `RESENT COUNT: 4` 다.

`resume_seqs` 는 그럴 수 없다 — **아무도 보지 않은 seq 는 목록에 없다.**

권한은 **한 번만 소비된다**: 잡이 해당 seq 에 도달하면 `pending` 으로 되돌리고 목록에서 빼는 것을
**한 번의 쓰기**로 한다. 이 쓰기가 커밋된 뒤 프로세스가 죽으면 seq 는 `pending` — 사람이 단언한
「보내지 않았다」 그대로이고, 권한은 이미 소진돼 다른 unknown 에 재사용될 수 없다.

어드민 두 버튼은 **같은 트윗에 대한 상호배타적 답**이므로 그 seq 의 항목을 **덮어쓴다**(누적 아님):
- 「未送信として再開」 → seq 는 `unknown` 유지 + `resume_seqs += [N]`
- 「送信済みとして記録」 → seq 는 `done` + `resume_seqs -= [N]` (아무것도 허가하지 않는다)

### 2-2. 같은 프로브를 수정 후 코드에

```
CRASHED: killed at the unknown write (now ONE statement, so this is all-or-nothing)
AFTER:   x.state="running" resume_seqs=[1]          ← 무관한 권한이 그대로 있어도
TWEETS:  [[1,"done"],[2,"done"],[3,"sending"], …]   ← 쓰기가 통째로 안 landed
--- TTL 경과 후 선점 ---
RESENT:  0  []
FINAL:   x.state="unknown"  seq3="unknown"
```

```
NORMAL FINISH: x.state="done" posted.x=true token=nil
PLANTED:       x.state="done" posted={}        ← 옛 코드가 만들 수 있던 모양을 손으로 심음
REPAIRED:      posted={"x"=>true, "x_url"=>"…"}  api_calls=0
```

---

## 3. 테스트

`test/jobs/x_publish_job_test.rb` 26 → **33** · `test/integration/jp_approval_test.rb` 16 → **19** ·
`test/integration/jp_approval_lock_test.rb` **신규 3** · concurrency 2 유지.

| # | 테스트 | 고정하는 것 |
|---|---|---|
| 5 | 재개 중 **새** unknown + 쓰기 직전 크래시 | seq 는 `sending` 으로 남고(1회 쓰기 = all-or-nothing), 선점 후 `unknown`, **재전송 0**, 무관한 `resume_seqs=[1]` 은 seq 3 을 덮지 않음 |
| 5' | 권한은 한 seq 만 | seq 2 허가 → 2 재전송 → seq 3 불명 → **3은 막힘**, 권한 소진 확인 |
| 5'' | 권한 소비 | `done` + `resume_seqs` 비움이 함께 |
| 6 | finish 는 done↔posted 가 **항상 일치** | `x.url == posted.x_url`, 토큰 해제까지 같은 쓰기 |
| 6' | **UPDATE 문 수를 센다** | `sql.active_record` 구독 → **정확히 1건**, `jsonb_set(jsonb_set(` 포함, 토큰 조건 포함 |
| 6'' | 레거시 반쪽 상태 복구 | 손으로 심은 뒤 → `posted` 복구, **API 호출 0**(`ForbiddenClient` 가 보내면 실패) |
| 7 | 토큰 조건 | 다른 토큰으로 `finish!` → `ClaimLost`, DB 불변 |
| 9 | 어드민 두 버튼 (실제 라우트) | `resume_seqs` 내용, 레거시 키 제거, 상호배타 |
| 9' | 승인 잠금 | 아래 §4 |

### 🔴 옛 코드(7cf81ec) 대조 — 지시 8번

```
=== OLD CODE (7cf81ec) vs the S8c test file ===
XPublishJobTest#test_a_legacy_half-finished_thread_is_repaired_without_touching_the_API
XPublishJobTest#test_a_NEW_unknown_during_a_resumed_run_is_not_covered_by_the_earlier_authorisation
XPublishJobTest#test_after_a_human_marks_the_unknown_tweet_as_unsent,_the_job_resends_THAT_one
XPublishJobTest#test_an_authorisation_for_one_sequence_never_covers_another
XPublishJobTest#test_consuming_an_authorisation_clears_the_unknown_and_the_list_entry_together
XPublishJobTest#test_finish_is_exactly_ONE_update_statement
33 runs, 112 assertions, 6 failures, 0 errors, 0 skips     ← 옛 코드
33 runs, 134 assertions, 0 failures, 0 errors, 0 skips     ← 새 코드
```

**B-5(새 unknown) · B-6(finish) 둘 다 옛 코드에서 실패하고 새 코드에서 통과한다.**
어드민 컨트롤러도 따로 대조: 옛 컨트롤러에서 **2건 실패**.
`JpApproval` 도 따로 대조: 옛 `approve!` 에서 **2건 실패**.

> ⚠️ `test_finish_refuses_to_write_under_a_token_that_is_no_longer_ours` 는 **옛 코드에서도
> 통과한다** — 옛 `finish!` 도 첫 쓰기는 토큰 조건부였기 때문이다. 판별력이 없는 테스트라는
> 뜻이므로, 원자성 주장은 **UPDATE 문 수를 세는 6'** 가 담당한다. 끝 상태만 보는 단언은
> 2문짜리 구현도 깨끗한 실행에서는 통과시킨다.

---

## 4. Q2' — 승인 측 잠금 (지시 9번)

**확인 결과 고쳐야 했다.** 옛 `approve!` 는 `Post.transaction` 만 쓰고 **reload 하지 않았다**.
검사도 `version_for` 도 전부 호출자가 들고 있던 in-memory 사본 기준이었다.

지문은 승인의 전부다 — 「이 텍스트를 검토했다」. 낡은 사본으로 계산하면 **DB 에 없는 버전에 대한
서명**이 되고, XPublishJob 이 12:00 JST 에 재검사하므로 증상은 「어드민은 초록인데 스레드가
스스로를 막는다」로 나타난다.

수정: `post.with_lock { post.reload; topic&.reload; 검사…; version_for(post) }`.
검사도 전부 안으로 옮겼다 — `approvable?` 는 `package` 의 가드 위반을 읽는데, 그건 import 가
바로 다시 쓰는 것이다.

신규 `test/integration/jp_approval_lock_test.rb`(비트랜잭션, 실제 커넥션):

| 테스트 | 결과 |
|---|---|
| 낡은 in-memory 사본으로 `approve!` 호출 | 지문이 **DB 의 본문** 기준으로 계산됨 (옛 코드: 실패) |
| import 가 잠금을 쥔 채 동시 승인 | 승인이 **대기**(스레드 alive 단언) → import 본문이 서고, `approved_version` 이 **저장된 본문과 일치** (옛 코드: 실패) |
| 승인이 먼저 | 이후 import 는 `:conflict`, 본문·지문 불변 |

**「옛 지문으로 새 본문 승인」은 두 경로 모두에서 도달 불가**가 됐다.

---

## 5. 변경 파일

| 파일 | 변경 |
|---|---|
| `app/jobs/x_publish_job.rb` | `write_x!` 에 `tweet_patches:`, unknown·실패 기록 1회 쓰기, `resume_seqs` 가드와 소비, `finish!` 1문 원자화, `claim!` 복구 경로 |
| `app/controllers/admin/jp_packages_controller.rb` | `arm_resume!`·`update_tweet`·`write_x` → `resume!` 하나로. 레거시 키 삭제, 상호배타 |
| `app/services/jp_approval.rb` | `approve!` 를 행 잠금 + reload 안으로 |
| `lib/tasks/jobs.rake` | `x_pending` 이 `resume_seqs` 를 본다 |
| `test/jobs/x_publish_job_test.rb` | 26 → 33, 어드민 shape 헬퍼 2개, `CrashAtUnknownWrite` 서브클래스 |
| `test/integration/jp_approval_test.rb` | 16 → 19 (실제 라우트로 두 버튼) |
| `test/integration/jp_approval_lock_test.rb` | **신규** 3 |

---

## 6. 배포 체크리스트

**[`s8b_report.md` §5](s8b_report.md) 8항목이 그대로 유효하다. 변경 없음.**
S8c 는 잡·컨트롤러·서비스의 내부 구조만 바꿨고, 배포 대상·환경 변수·마이그레이션·정적 자산은
건드리지 않았다. ⓪ `pg_dump` → ① recurring 등록 → ② `X_API_DRY_RUN` → ③ UID 1000 읽기 →
④ 브랜드 아이콘 200 → ⑤ KO 블로그 두 모양 → ⑥ 과거 slug 301 → ⑦ `blog:stuck` exit 0 →
⑧ JP 패키지 확인.

한 줄만 추가로 읽을 것: **배포 후 기존 행에 `resume_requested` 가 남아 있어도 무해하다.**
새 코드는 그 키를 읽지 않고, 어드민이 그 패키지를 건드리는 순간 삭제한다. 다만 **그 키만으로는
이제 아무것도 허가되지 않으므로**, 배포 시점에 「사람이 재개를 눌러둔 unknown 스레드」가 있었다면
버튼을 **한 번 더** 눌러야 한다(해당 seq 를 `resume_seqs` 에 넣기 위해). 현재 프로덕션에 JP
패키지는 **0건**이므로 이번 배포에는 해당 사항이 없다.

---

## 7. 남는 공백

| # | 항목 |
|---|---|
| B-1 | **X 요금제·월 쓰기 한도·미디어 업로드 권한 미확인 → `X_API_DRY_RUN=1` 유지** |
| B-2 | 크래시 후 스레드는 claim TTL **30분** 멈춘다(안전하지만 재개가 늦다). `x_stuck` 유예가 2시간이라 알림은 그보다 더 늦다 |
| B-3 | `write_x!` 는 `x` 서브트리를 통째로 다시 쓴다. 형제 키는 `jsonb_set` 으로 안전하지만, **같은 토큰을 든 두 쓰기**가 겹치면 뒤엣것이 이긴다 — 토큰 소유자는 한 명이므로 현재 발생 불가 |
| B-4 | `claim!` 의 복구 경로는 **레거시 전용 안전망**이다. 새 코드가 그 상태를 만들 수 없으므로, 언젠가 「한 번도 발화하지 않는 코드」가 된다 — 지울 시점은 프로덕션에 그 모양이 0건임을 확인한 뒤 |
| B-5 | ep04~33 본문 미작성 · 본문 분량 규칙 미강제 · `JpMarkdown` 서브셋 밖은 조용히 평문 |
| B-6 | **일본 변호사 검토는 여전히 없다** |

**S8C_DONE**
