# SafeFile JP S8b: 교차검증 RED 2건 수정 — X 게시 크래시 내구성 + import 승인 보호. 배포·푸시·실제 게시 금지.

## 자율 실행 규칙
- 중간 확인 없이 끝까지. 막히면 CLAUDE.md 「JP-1 이슈 로그」에 기록하고 계속. 3-Strike 적용. 시간 약속 금지.
- 기존 골든·E-1 스냅샷(25/25)·`bin/rails test` 0 failures 유지. KO 색인 신호 불변.
- 프로덕션 DB·X API·SMTP 실제 호출 금지. `X_API_DRY_RUN=1` 고정.
- 완료 시 커밋(푸시·배포 금지). `docs/jp/s8b_report.md` 작성. 마지막 줄 "S8B_DONE".

## 읽을 것
docs/jp/codex_review_s8_2026-10-25.md (이 프롬프트의 근거 — 판정 Q1~Q5와 수정 지시 1~6), docs/jp/s8_report.md §3-2·§3-4, app/jobs/x_publish_job.rb, app/services/jp_import.rb, app/services/jp_approval.rb, lib/tasks/content.rake, app/models/post.rb, db/migrate/20261025000001_add_jp_content_track.rb, test/jobs/x_publish_job_test.rb, test/integration/jp_content_track_test.rb

## A. XPublishJob — 「트윗은 두 번 게시되지 않는다」를 크래시에서도 지킨다 (RED Q3)
현재 `perform`의 `post.with_lock do … run(post) end`가 **루프 전체를 한 트랜잭션**으로 감싸므로 `update_column`은 커밋이 아니다. 트윗 3개 게시 후 프로세스가 죽으면 ID 3개가 전부 롤백되고 재실행이 1번부터 다시 올린다.
1. 잠금을 **소유권 선점**으로 바꾼다: 짧은 트랜잭션(`with_lock`) 안에서 상태·승인 검사 → `x.state='running', x.worker_token=SecureRandom.hex(8), x.claimed_at` 를 쓰고 **커밋하고 나온다**. 이미 `running`이고 `claimed_at < 30분`이면 다른 워커가 진행 중 → 종료(로그). 30분 지났으면 죽은 워커로 보고 선점 가능.
2. 트윗 루프는 **트랜잭션 밖**. 각 seq마다: ① 별도 트랜잭션으로 `seq.state='sending', sending_at` 커밋 → ② API 호출 → ③ 별도 트랜잭션으로 `tweet_id·parent_id·state='done'` 커밋. 각 쓰기는 `worker_token` 일치 조건부(`UPDATE … WHERE package->'x'->>'worker_token' = ?` 또는 재조회 후 비교) — 토큰이 다르면 즉시 중단.
3. 재실행(또는 선점) 시 `state='sending'`인 seq가 있으면 **`unknown`으로 승격**하고 멈춘다(API 호출 뒤 커밋 전 크래시 = 결과 불명). 기존 unknown 처리(메일·사람 확인·「送信済みとして記録/未送信として再開」)를 그대로 탄다.
4. `approved_version_matches?`: 지문이 **없으면 false → blocked**(fail-closed). 드라이런(`X_API_DRY_RUN=1`)에서도 동일 — 드라이런이 승인 검사를 우회하면 테스트가 실제 경로를 검증하지 않는다. 미승인 패키지의 수동 enqueue(`blog:x_pending`)는 `approved_at` 없으면 enqueue 자체를 거부.
5. 테스트(`test/jobs/x_publish_job_test.rb`):
   - **크래시 내구성**: 클라이언트 스텁이 seq 3의 API 성공 **직후**(ID 반환 후, 커밋 전)에 `raise Interrupt` → 재실행 → seq 1·2 재전송 0, seq 3은 `unknown`, seq 4~ 미전송. 그리고 seq 3 API 호출 **직전**(sending 커밋 후) 크래시 → 재실행 → seq 3 `unknown`(실제로는 미게시지만 자동 판단하지 않음).
   - **별도 DB 연결 2워커**: 두 스레드가 각자 커넥션으로 동시 perform → 한쪽만 선점, 전송 총합 = 트윗 수(중복 0). (`use_transactional_tests = false` 로 이 테스트만 실제 커밋 — 정리 코드 포함)
   - 지문 없음 → blocked. 지문 있음+일치 → 진행. 30분 지난 running 선점 가능, 5분 지난 running 선점 불가.
   - 기존 17개 테스트 전부 유지.

## B. JpImport — 승인 보호를 서비스 안으로 (RED Q2)
6. `apply!` 시작에서 `post.with_lock` → 잠금 안에서 `status=='draft' && package['approved_at'].blank?` 재검사. 실패면 `record_conflict!` 후 `:conflict` 반환(rake의 사전 검사는 남겨도 되지만 **서비스가 최종 심판**). 같은 `content_hash`면 자산·topic 포함 **완전 무쓰기**로 `:unchanged` 반환.
7. `find_or_create_post!`의 `RecordInvalid` rescue: `e.record.errors.details` 가 `{slug: [{error: :taken}]}` **뿐일 때만** 흡수, 그 외(빈 제목·카테고리 오류 등)는 re-raise. `RecordNotUnique`는 기존대로.
8. import 입력 검증(`JpEpisodeSource#validate!`): `title_ja`·`body_ja`(산문 1자 이상)·`x_thread`(1개 이상)·`publish_on` 필수. 빈 값이면 import 거부(exit 1, 이유 출력) — 가드 위반(exit 0 + 승인 비활성)과 구별.
9. 문서화: `jp_import.rb` 상단 주석과 s8_report §6의 「승인 후 재import = 아무것도 쓰지 않는다」를 「본문·자산·상태·승인 지문은 쓰지 않는다. `package.import_conflict` 1키만 기록한다」로 정정.
10. 테스트: 승인된 패키지에 다른 해시 import → 본문·자산·approved_version 불변 + import_conflict 기록 / 같은 해시 → 어떤 컬럼도 `updated_at` 포함 불변 / 검사 통과 직후 다른 스레드가 승인 → 서비스가 거부(잠금 순서로 재현) / 빈 title_ja → exit 1 / slug 중복 외 RecordInvalid → re-raise.

## C. 작은 것들 (AMBER Q1·Q4)
11. `Post#primary_title_and_body_present`: KO 제목은 기존 `validates :title_ko` 에 맡기고 JA 제목만 추가 검증 → KO 발행 실패 시 제목 오류 1회. E-1 25/25 유지 확인.
12. 마이그레이션 `up` 첫 줄에 `execute "SET LOCAL lock_timeout = '5s'"`, `execute "SET LOCAL statement_timeout = '30s'"`. 개발 DB에서 `db:rollback` → `db:migrate` 왕복 1회 실행해 가역성 실측(JP 행 없는 상태).
13. E-1 픽스처에 2모양 추가: 「body_en만 있고 body_ko 없는 KO draft」·「OLD_BLOG_SLUGS 리다이렉트 대상 KO 글」(요청은 옛 slug로 → 301 Location까지 스냅샷). 항목 수 하한을 새 수로 올린다. 기존 25항목은 **바이트 동일**이어야 한다.

## D. 보고 (`docs/jp/s8b_report.md`)
14. 변경 파일 표, 크래시 내구성 테스트 로그 발췌(재전송 0 증거), 2워커 테스트 결과, 롤백 왕복 결과, E-1 결과(기존 25 동일 + 신규 2).
15. **배포 전 체크리스트**(s8_report §8 ③을 대체하는 완전판) — 교차검증 Q5 반영: ① 배포 직후 `bin/rails runner 'puts SolidQueue::RecurringTask.pluck(:key, :schedule)'`로 `auto_generate_jp`가 등록됐고 다음 실행이 토 00:00 KST인지 ② worker 컨테이너에서 `ENV["X_API_DRY_RUN"]` 가 "1"인지(`bin/rails runner 'puts ENV["X_API_DRY_RUN"].inspect'`) ③ 최종 이미지에서 `content/jp/guard_rules.json`·`content/jp/ep01/`이 UID 1000으로 읽히는지(`docker run --user 1000:1000 <image> ls -la content/jp/ep01`) ④ `/safe/brand/icon-192.png` 200 ⑤ KO 블로그: body_en **없는** 글 1편(`/en`은 noindex)과 body_en **있는** 글 1편(`/en`은 self-canonical·indexable) 각각 시크릿 창 확인 — 두 모양을 구별해서 적을 것 ⑥ 과거 slug 1건 301 확인 ⑦ `bin/rails blog:stuck` exit 0 ⑧ 배포 직전 `pg_dump` 백업 1회. 각 항목은 `[새 터미널]`/`ssh 원격`/`[읽기만]` 실행 위치와 명령을 붙여 Justin이 복사해 실행할 수 있게.
