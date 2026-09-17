# Codex 교차검증 결과 원문 — 교차검증 (a) 3건 수정 · 2026-09-18

- 대상 커밋: `a2a1934` (브랜치 `fix/blog-indexing-signals`, 미배포)
- 투입 패키지: [`CODEX_REVIEW_PACKAGE_2026-09-18_amber3.md`](CODEX_REVIEW_PACKAGE_2026-09-18_amber3.md)
- 도구: `codex exec --sandbox read-only`, codex-cli 0.144.3, model `gpt-5.5`, reasoning effort med
- 소요: **96초**, 단일 조각
- 주의: Codex 가 인용한 줄 번호는 **패키지 문서의 줄 번호**다 (원본 파일 줄 번호가 아니다).
  첫 시도는 stdin 을 닫지 않아 `Reading additional input from stdin...` 에서 10분 멈췄다 —
  `codex exec` 는 `< /dev/null` 이 필요하다.

---

[논리 오류] [확신도 높음] 발행 실패 메일은 실제 전송 실패를 영구 가시화하지 못한다  
근거: `app/jobs/publish_scheduled_posts_job.rb:348-354` (`docs/review/CODEX_REVIEW_PACKAGE_2026-09-18_amber3.md:348-354`), `app/mailers/blog_mailer.rb:448-454` (`...:448-454`), `test/jobs/publish_scheduled_posts_job_test.rb:1558-1568` (`...:1558-1568`), 패키지 자체 인식 (`...:2604-2607`)  
설명: `report`는 `BlogMailer.publish_failed(skipped).deliver_later` 호출 자체만 rescue한다. `deliver_later` 이후 별도 메일 잡에서 `publish_failed` 뷰 렌더 실패나 SMTP 인증 실패가 나면 이 `begin/rescue`는 더 이상 관여하지 않는다. 테스트도 `perform_enqueued_jobs`로 정상 렌더/전달 경로를 확인하지만, 프로덕션에서 실패한 메일 잡이 “스킵된 글이 영구히 scheduled로 남는 문제”를 별도 앱 상태나 헬스체크로 남긴다는 근거는 패키지에 없다. 즉 메일이 유일한 영구 가시화 채널인데, 메일 전달 실패 경로는 여전히 로그/큐 동작 의존이다.

[데이터 손실 위험] [확신도 높음] 대체된 SafeFile 시드가 마이그레이션 결과를 되돌릴 수 있다  
근거: `db/seeds/safefile_posts.rb:1286-1307` (`...:1286-1307`), `db/seeds/safefile_posts.rb:1308-1348` (`...:1308-1348`), `lib/tasks/blog_migrate_privacy.rake:1247-1249` (`...:1247-1249`), 패키지 자체 인식 (`...:2618-2620`)  
설명: `blog:migrate_privacy`는 SafeFile 글을 `privacy` 카테고리로 정리한다. 그런데 `db/seeds/safefile_posts.rb`는 “대체됐다”고 주석으로 밝히면서도 그대로 실행 가능하고, `resume-privacy`는 같은 slug를 찾아 `category: "student"`를 다시 assign/save한다. body가 이미 채워진 마이그레이션 후 DB에서는 검증에 걸리지 않고 저장될 수 있으므로, 최소한 첫 글은 `privacy → student`로 되돌아간다. 나머지 두 글은 개명 전 slug라 거부될 수 있지만, 한 항목이라도 이미 정리된 운영 데이터를 훼손한다.

Q1. `RECORD_REJECTED = [RecordInvalid, RecordNotSaved]`는 이 패키지 근거만으로는 타당한 경계다. `RecordInvalid`는 검증 실패, `RecordNotSaved`는 `throw :abort`류의 저장 거부를 포괄하려는 의도가 맞다. `RecordNotUnique`, `StaleObjectError`, 연결 장애는 격리하면 안 되는 쪽으로 보인다. 경로 요청: `db/schema.rb`, `app/models/**/*.rb` 전체 콜백/락 설정.

Q2. 부분 성립. 글 단위 로그와 런당 메일 enqueue는 있다. 그러나 실제 메일 잡 실행 시점의 렌더/SMTP 실패는 이 잡의 rescue 밖이다. 위 첫 번째 지적.

Q3. 직렬화는 안전해 보인다. `describe_failure`는 slug/id/errors 문자열만 담는다. `errors.full_messages`가 비어도 뷰가 `(검증 메시지 없음)`을 출력한다 (`...:516-517`).

Q4. 일반 슬래시, 빈 `PATH_INFO`, `/safety`, `/safe-x`류는 괜찮다. `SCRIPT_NAME` 보존도 단위 테스트가 있다. `%2F`는 패키지에 경로 테스트가 없다. 경로 요청: Rack/Rails에서 percent-encoded slash가 `PATH_INFO`에 들어오는 실제 통합 테스트 또는 서버 설정.

Q5. 현재 프리캐시 목록에는 `/safe/sw.js/`가 없고, `/safe/`와 manifest/icon만 있다 (`...:2473-2487`). 그래서 현재 SW install을 깨는 근거는 없다. `/safe/sw.js/ → /safe/sw.js` 통합은 중복 URL 제거로 타당해 보인다.

Q6. `unshift` 분기는 부분적으로 타당하다. 이 미들웨어는 DB/AR을 만지지 않고 path-only Location을 내므로 Executor 앞 배치 자체의 위험 근거는 패키지에 없다. 다만 SSL/AssumeSSL 앞 배치의 실제 운영 효과는 패키지의 주석과 덤프뿐이다. 경로 요청: production SSL/force_ssl 설정 및 프록시 헤더 설정.

Q7. 기존 키를 가린다는 근거는 없다. top-level `errors.messages`와 `activerecord.errors.messages`를 둘 다 둔 것은 lookup 경로상 방어적이다. `errors.format` 공백 제거는 한국어 속성명에는 맞지만, 패키지 자체가 번역 없는 모델에서 `Title en을(를)`류 부작용을 인정한다 (`...:2615-2617`). 치명적 깨짐보다는 표시 품질 문제다.

Q8. `migrate_privacy`와 `seed_safefile_posts`의 “항목 격리 후 abort”는 자동화에 맞다. 반대로 `blog:generate`/`regenerate_scheduled`의 exit 0은 사람이 보는 태스크라는 전제면 수용 가능하지만, 자동화에 들어가면 조용한 실패가 된다. 패키지 안 자동화 근거가 부족해 지적까진 보류한다.

Q9. 공허한 단언은 크게 보이지 않는다. 로그 formatter는 severity를 실제 문자열에 넣는다 (`...:1435-1444`). 연결 장애 스텁은 `update!`에서 비격리 예외가 전파되는 경로를 탄다 (`...:1616-1628`). 통합 테스트 `//`는 수정 전 실패 실측과 풀스택 테스트가 함께 제시됐다 (`...:2090-2110`).

Q10. `auto_generate_blog_post_job`의 `topic.update!` 미격리는 런당 글 1개라 수용 가능하다. `blog:generate` exit 0도 사람 실행 전제면 수용 가능하다. 하지만 `db/seeds/safefile_posts.rb` 보류는 부적절하다. 대체된 파일이 여전히 실행 가능하고 마이그레이션 결과를 되돌릴 수 있다.

3건 판정:
1. `PublishScheduledPostsJob` 배치 중단 문제: 부분 해소. 글 단위 격리는 됐지만 실패 가시화가 메일 전달 성공에 과하게 의존한다.
2. 반복 슬래시 canonical 문제: 해소됨. 패키지 안 반례 대부분이 테스트로 고정돼 있다.
3. 미들웨어 삽입 guard 문제: 해소됨. 무조건 삽입으로 바뀌었고 Static 유무별 위치 의도도 문서화돼 있다.
hook: Stop
hook: Stop Completed
