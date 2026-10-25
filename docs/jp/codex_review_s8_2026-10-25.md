# 교차검증 결과 — S8 구현 (2026-10-25)

검증자: ChatGPT (GPT-6.1). 입력: `docs/jp/private/review_request_s8_full.md` = 질문 5개 + s8_report.md 전문 + 마이그레이션·post.rb·jp_import.rb·x_publish_job.rb·posts_controller.rb·.dockerignore 전문.
대화: https://chatgpt.com/c/6add84b9-b374-83e8-a3d1-bfdcfcd9c4b8
Claude 독립 확인: Q3의 `with_lock` 트랜잭션 구조는 코드에서 직접 확인함(실제 결함). Q2의 승인 검사 위치(rake 쪽만)도 확인함.

## 판정
- Q1 AMBER — KO 색인 분기는 유지. `title_ko` presence 검증 + `primary_title_and_body_present`가 KO 발행 시 같은 :blank 오류를 2회 추가. E-1 픽스처가 「body_en만 있는 KO draft」·과거 slug 301·쿠키 있는 요청을 덮는지 미확인.
- Q2 **RED** — `JpImport#apply!` 자체에 승인 보호 없음(검사는 rake 호출부) → 검사 후 승인되는 경쟁을 못 막음. `find_or_create_post!`의 `RecordInvalid` rescue가 오류 내용을 안 보고 행 존재만으로 흡수. 빈 JA 제목은 draft라 검증조차 안 됨(import 입력 검증 부재). 「승인 재import = 무쓰기」가 아니라 `import_conflict`는 씀 — 계약 문구를 명시적 예외로.
- Q3 **RED** — `perform`의 `with_lock`이 `run` 전체를 한 트랜잭션으로 감쌈 → `update_column`은 **커밋이 아님**. ① API 성공 직후 크래시 ② update_column 직전 크래시 ③ 첫 워커 롤백 후 대기 워커 진행 — 전부 이미 게시된 트윗 재전송 가능. `approved_version_matches?`가 지문 없으면 true(fail-open).
- Q4 AMBER — DDL은 가역적이나 `lock_timeout`/`statement_timeout` 없음. JP 행 생성 후 down은 데이터 소실.
- Q5 AMBER — Solid Queue scheduler가 새 recurring을 읽었는지·다음 실행이 토 00:00 KST인지·worker 환경에 `X_API_DRY_RUN=1`이 실제 적용됐는지·최종 이미지에 `content/jp/guard_rules.json`·에피소드 자산이 UID 1000 읽기 가능한지 확인 누락. §8 ③의 「/en은 noindex」는 body_en 있는 글엔 틀림(self-canonical·indexable).

## 수정 지시 (→ s8b_prompt.md)
1. XPublishJob: 잠금은 **소유권 선점**(짧은 트랜잭션으로 `x.state='running', worker_token, claimed_at` 커밋)으로, 트윗 루프는 **트랜잭션 밖**에서. 전송 전 `seq.state='sending'` 커밋 → API → 별도 트랜잭션으로 `tweet_id`·`done` 커밋. 재실행 시 `sending`인 seq는 `unknown`으로 승격(자동 재전송 금지). `approved_version` 없으면 **blocked**(fail-closed), 드라이런만 예외 명시.
2. JpImport#apply!: 행 `with_lock` 안에서 승인 상태·`content_hash` 재검사. 같은 해시면 완전 무쓰기(자산·topic 포함) 반환. `record_conflict!`는 「무쓰기의 명시적 예외」로 문서화. `find_or_create_post!` rescue는 `e.record.errors.details[:slug]`가 `:taken`뿐일 때만 흡수, 그 외 re-raise. import 입력 단계에서 title_ja·body_ja·x_thread 필수 검증(빈 값 → import 거부).
3. Post: `primary_title_and_body_present`에서 KO 제목은 기존 presence에 맡기고 JA 제목만 추가 검증(오류 중복 제거).
4. 마이그레이션: `up` 시작에 `SET LOCAL lock_timeout='5s'; SET LOCAL statement_timeout='30s'`. 보고서에 「JP 행 생성 전/후 롤백 절차」 구분.
5. E-1 픽스처에 「body_en만 있는 KO draft」·「과거 slug 301 글」 추가(항목 수 하한 상향). 크래시 내구성 테스트: 트윗 2 성공 후 `Process.kill`/예외로 강제 중단 → 재실행 시 1·2 재전송 0, 3은 unknown.
6. 배포 체크리스트에 Q5 항목 추가.

## 종합
**YES-with-fixes — 배포 전 1~3 필수.** 4~6은 같은 라운드에서 처리.
