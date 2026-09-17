# Codex 교차검증 결과 원문 — 새 AMBER 2건 수정 · 2026-09-18 (라운드 4)

- 대상 커밋: `7bec679` (브랜치 `fix/blog-indexing-signals`, 미배포)
- 투입 패키지: [`CODEX_REVIEW_PACKAGE_2026-09-18_amber2b.md`](CODEX_REVIEW_PACKAGE_2026-09-18_amber2b.md)
- 도구: `codex exec --sandbox read-only`, codex-cli 0.144.3, model `gpt-5.5`, reasoning effort med
- 주의: Codex 가 인용한 줄 번호는 **패키지 문서의 줄 번호**다 (원본 파일 줄 번호가 아니다).

---

[논리 오류] [낮음] `publish_stuck` 스코프와 술어가 “모든 입력”에서 완전히 동일하다고 보긴 어렵다  
근거: `docs/review/CODEX_REVIEW_PACKAGE_2026-09-18_amber2b.md:660`, `docs/review/CODEX_REVIEW_PACKAGE_2026-09-18_amber2b.md:669`, `docs/review/CODEX_REVIEW_PACKAGE_2026-09-18_amber2b.md:2831`  
설명: 스코프는 `now: Time.current, cutoff: Time.current - grace`를 쿼리 생성 시점에 바인딩하고, 술어는 호출 시점에 `Time.current`를 다시 평가한다. `published_at`이 정확히 `now` 또는 `cutoff` 경계에 걸친 레코드는 두 호출 사이의 시간 차이 때문에 스코프와 술어가 갈릴 수 있다. 기존 테스트는 `+5.minutes`, `-5.minutes`, `-1.minute` 경계는 보지만 정확한 동시성/경계값은 고정하지 않는다. 실사용 영향은 낮다.

Q1. SQL 자체는 의도와 맞다. SQL에서 `AND`가 `OR`보다 우선하므로 조건은 `(publish_error IS NOT NULL AND published_at <= :now) OR published_at <= :cutoff`로 해석된다. 괄호는 동작상 필수는 아니지만 가독성상 넣는 편이 낫다.

Q2. 일반 입력에서는 일치한다. 다만 위 지적처럼 `Time.current`를 별도로 평가하므로 정확한 경계 시각에서는 완전 동일 보장이 없다. 타임존은 둘 다 `Time.current`/Rails 시간 객체를 쓰므로 패키지 근거상 별도 불일치는 보이지 않는다.

Q3. 파생 상태가 플래그보다 낫다는 주장은 성립한다. 잡이 아예 안 돈 경우와 잡이 해당 글 전에 죽은 경우를 잡는다. 반대로 어드민에서 발행 글을 `scheduled`로 되돌리고 과거 `published_at`을 유지하면 “막힌 글”로 보일 수 있는데, 컨트롤러가 `status`와 `published_at` 수정을 허용하므로 가능한 경로다.

Q4. `record_error`/`clear_error`의 `update_column` 사용은 타당하다. 실패 이유 기록은 검증 실패 레코드에도 써야 하고, 이 값은 파생 상태의 보조 설명일 뿐이다. `updated_at` 미갱신은 “콘텐츠 편집 시각”을 오염시키지 않는 장점이 있다.

Q5. 재시도 정책은 앱 구성에 맞다. `PublishScheduledPostsJob`은 `scheduled_ready`가 발행된 글을 제외하므로 재생 시 중복 발행/중복 알림 가능성이 낮다. `AutoGenerateBlogPostJob`은 API 비용과 중복 글 위험 때문에 재시도 없음이 타당하다.

Q6. 패키지 근거상 `ApplicationMailDeliveryJob` 예외 분리는 적절하다. transient SMTP/네트워크는 `retry_on`, 인증/치명/문법 오류는 `rescue_from` 후 재발생한다. 선언 순서 문제나 부모 `ActionMailer::MailDeliveryJob` 충돌은 패키지 안 근거만으로는 결함을 확정할 수 없다.

Q7. `rake jobs:failed`의 `defined? && table_exists?` 가드는 개발 DB에서의 `UndefinedTable` 회피 목적에는 맞다. 다만 프로덕션 큐 DB를 실제로 읽는지는 패키지 자체도 미실측이라고 밝히므로 최종 확정은 불가하다.

Q8. 시드를 가드가 아니라 제거한 판단은 옳다. 테스트가 태스크 부재, 파일 부재, 참조 부재, 단일 소유자를 확인한다.

Q9. `blog:migrate_privacy`의 새 소유 범위는 합리적이다. 생성 시에는 제목/메타/본문을 채우고, 갱신 시에는 slug/category/빈 body만 다룬다. 이는 “파일이 항상 진실”에서 “DB 편집 보존”으로 바뀐 동작 변경이지만, 문제였던 관리자 편집 덮어쓰기를 막는 방향이다.

Q10. `/up`에 걸지 않은 판단은 옳다. Kamal 헬스체크 성격상 앱 데이터 상태를 섞으면 배포/프록시 헬스체크가 운영 알림 역할까지 떠안는다.

Q11. 공허한 단언은 주요 경로에서 보이지 않는다. 메일 완전 실패 테스트는 `assert_empty deliveries`를 포함하고, 레이크 헬퍼는 `SystemExit`를 코드로 번역하며, 시드 제거 테스트는 파일/태스크/참조를 실제로 확인한다.

Q12. 고치지 않기로 한 항목들은 대체로 타당하다. 특히 `blog:generate` 계열 exit 0 유지와 정기 자동화 미도입은 이번 수정 범위 밖으로 보인다. 단, `jobs:failed`의 프로덕션 큐 DB 실측은 배포 후 확인 항목으로 남는다.

판정:
1. 발행 실패 알림의 메일 의존 제거: **해소됨**. 낮은 확신도의 경계값 불일치만 남음.
2. 폐기 시드가 마이그레이션 결과를 되돌리는 문제: **해소됨**. 시드 제거와 단일 소유자 전환이 패키지 근거상 충분히 검증됐다.
hook: Stop
hook: Stop Completed
