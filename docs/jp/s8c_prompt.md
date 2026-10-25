# SafeFile JP S8c: X 게시 잔여 결함 2건 — unknown 기록 원자화 + resume 범위 한정 + finish 원자화. 배포·푸시·실제 게시 금지.

## 자율 실행 규칙
- 중간 확인 없이 끝까지. 3-Strike. 시간 약속 금지. 기존 테스트 전부(354) + E-1 38/38 유지.
- `X_API_DRY_RUN=1` 고정. 프로덕션 미접촉. 완료 시 커밋, `docs/jp/s8c_report.md`, 마지막 줄 "S8C_DONE".

## 근거 (재검증 2026-10-25 14:40, docs/jp/codex_review_s8b_2026-10-25.md)
RED: `handle_indeterminate`가 ① `mark_tweet!(seq→unknown)` ② `write_x!(state→unknown, resume_requested→false)` **두 번 쓴다**. ①과 ② 사이 크래시 → DB는 `x.state=running, resume_requested=true, seq N=unknown`. TTL 후 새 워커가 선점하면 `run`의 `row["state"]=="unknown" && !resume_requested` 가드가 **resume_requested=true 때문에 통과**해 seq N을 다시 게시한다. 첫 호출이 실제 게시됐다면 중복. `promote_sending_to_unknown!`도 같은 분리 쓰기.
AMBER: `finish!`가 `write_x!(done, token→nil)` 뒤에 **토큰 조건 없는** `update_column(posted)`을 따로 쓴다. 사이에 크래시 → `x.state=done`인데 `posted.x` 미기록, `claim!`은 done을 재처리하지 않아 자가 복구 불가. `reload.merge` 전체 쓰기라 다른 키를 덮을 수도 있음.

## A. 수정
1. **unknown 기록을 원자적 1회 쓰기로**: `write_x!`에 트윗 배열 갱신까지 받는 형태(예: `write_x!(post, token, x_patch, tweet_patches: {seq => {...}})`)를 만들고 `handle_indeterminate`·`promote_sending_to_unknown!`가 **단일 UPDATE**(토큰 조건부, `jsonb_set` 체인 또는 Ruby에서 합쳐 1회)로 `tweets[N].state=unknown`·`x.state=unknown`·`resume_requested=false`를 쓴다. 두 함수의 분리 쓰기 제거.
2. **resume 범위 한정**: `resume_requested`를 boolean에서 **`resume_seqs: [N, …]`**(사람이 「未送信として再開」로 확인한 seq 목록)로 바꾼다. `run`의 가드는 `row["state"]=="unknown" && !resume_seqs.include?(row["seq"])` → 중단. 재개 시 해당 seq를 `pending`으로 되돌리고 `resume_seqs`에서 제거하는 것까지 **한 번의 쓰기**. 새로 생긴 unknown은 목록에 없으므로 자동으로 막힌다. admin 「未送信として再開」·「送信済みとして記録」(tweet_id 입력 → done) 두 액션 모두 이 구조로 갱신. `blog:x_pending` rake도.
3. **finish! 원자화**: `x.state=done, url, finished_at, worker_token=nil`과 `posted.x=true, posted.x_url`을 **하나의 토큰 조건부 UPDATE**로. `jsonb_set(jsonb_set(package, '{x}', …), '{posted}', …) WHERE … worker_token = ?`. 영향 행 0이면 raise(소유권 상실). `reload.merge` 전체 쓰기 제거.
4. `claim!`에 복구 경로 추가: `x.state=='done' && posted.x != true` 인 행은 **finish만 재실행**(API 호출 없음) — 3번 이전에 생긴 반쪽 상태를 위한 안전망.

## B. 테스트 (`test/jobs/x_publish_job_test.rb`, `x_publish_concurrency_test.rb`)
5. 재개 중 신규 unknown 크래시 창: resume_seqs=[3]로 재개 → seq 3 done → seq 5 API 불명 → `handle_indeterminate`의 쓰기 **직전** 크래시 주입(한 번의 쓰기이므로 「직전」만 존재해야 함: 쓰기 전 크래시면 seq 5는 `sending`으로 남아 promote 경로, 쓰기 후면 unknown+resume_seqs에 없음) → TTL 경과 → 재실행 → **seq 5 재전송 0**, 상태 unknown, 중단.
6. `finish!` 중간 크래시: UPDATE 1회이므로 「state=done인데 posted 없음」 상태를 **만들 수 없음**을 단언 + 4번 복구 경로는 수동으로 그 상태를 심어 finish만 재실행되고 API 호출 0인지.
7. 토큰 조건: 다른 토큰으로 `finish!` 호출 → 영향 행 0 → raise, DB 불변.
8. 기존 26+concurrency 테스트 전부 유지. 옛 코드(7cf81ec)로 5·6을 돌리면 실패하는지 1회 확인해 보고서에 기록.

## C. Q2' 잔여 — 승인 측 잠금 확인
9. `JpApproval#approve!`가 **행 잠금 안에서 reload 후** `version_for`를 계산·저장하는지 확인. 아니면 `post.with_lock do post.reload; … version_for(post) … end`로 고쳐 import와 같은 잠금 규율. 테스트: import `apply!`가 잠금을 잡고 있는 동안 approve! 호출 → 대기 후 **새 본문 기준** 지문으로 승인되거나(허용), 또는 승인이 draft 아님을 보고 거부 — 둘 중 하나로 결정론적이어야 하며 「옛 지문으로 새 본문 승인」은 불가능해야 함.

## D. 보고
10. `docs/jp/s8c_report.md`: 변경 함수 표, 5·6·7·9 테스트 로그, 옛 코드 실패 확인, 배포 체크리스트는 s8b_report §5 그대로 유효함을 명시(변경 없으면).
