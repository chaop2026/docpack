# Codex 교차검증 패키지 — 새 AMBER 2건 수정 · 2026-09-18 (라운드 4)

> 대상 커밋 `7bec679` (브랜치 `fix/blog-indexing-signals`, **미배포**)
> 비밀값 스캔 결과는 문서 말미.

## ① 리뷰어용 프롬프트

당신은 이 저장소를 처음 보는 **독립 코드 리뷰어**다. 아래 패키지만 근거로 판단하라.

**맥락**: Rails 8.0.4 앱 `slimfile.net`. 직전 라운드(커밋 `a2a1934`) 교차검증이 (a)등급 2건을
남겼고, 이 커밋(`7bec679`)이 그 2건을 고친다. **아직 배포되지 않았다. 프로덕션 DB 는 건드리지
않았다** — 모든 판정은 로컬 라이브 HTTP 실측 + 코드/젬 소스 인용 + 실제 프로브 실행.

고친 2건:
1. **AMBER** 발행 실패 알림이 **메일 전달 성공에 의존**했다. → 막힌 글을 **파생 상태**
   (`Post.publish_stuck`)로 만들고 **DB 만 의존하는 3곳**에서 읽게 했다. 메일은 보조.
   아울러 재시도 정책을 이 앱의 실제 잡 구성(Solid Queue)에 맞춰 정리했다.
2. **AMBER (프로덕션 데이터)** 폐기된 `db/seeds/safefile_posts.rb` 가 `blog:migrate_privacy`
   결과를 되돌렸다. → **시드와 태스크를 제거**하고 마이그레이션을 create-or-update 단일
   소유자로 만들었다.

**지적 분류 고정**: `정책 위반` / `보안` / `데이터 손실 위험` / `논리 오류`

**규칙**:
- 모든 지적에 **파일:줄 근거**를 달아라. 근거 없는 지적은 적지 마라.
- **확신도(높음/보통/낮음)** 표기. 낮아도 적되 낮다고 밝혀라.
- **여기 없는 파일은 추측하지 마라.** 필요하면 "경로 요청: <파일>" 이라고 적어라.
- 하지 말 것: 스타일 지적(rubocop-rails-omakase 고정, 신규 위반 0 확인됨),
  일반론적 "테스트를 늘려라", 정본 문서(DECISIONS.md)를 고치자는 제안.

**이 저장소가 반복해 당한 실패 유형** (이 관점으로 파고들어라):
1. **조용한 실패** — 실패했는데 성공처럼 보인다. 실사례: ① 라우트가 정적 핸들러에 가려
   한 번도 실행 안 됨 ② minitest 비호환으로 전 테스트가 죽었는데 요약 줄 없이 끊겨 통과처럼
   보임 ③ 컨트롤러발 `page_meta` 가 조용히 무시됨 ④ 이니셜라이저가 dev 에서 리로드되지 않아
   "수정 후" 측정이 실은 수정 전 값 ⑤ 가드 때문에 미들웨어가 스택에서 0개인데 에러 없음
   ⑥ **이번 건: `ApplicationJob` 에 `retry_on` 을 달면 메일이 커버된다고 착각하게 된다**
   (`MailDeliveryJob` 은 `ActiveJob::Base` 상속) ⑦ **이번 건: 시드 덮어쓰기 프로브의 마커를
   대상이 쓰는 값과 같게 잡아 "PRESERVED" 거짓 통과가 났다**
2. **암묵적 상류 의존** — 안전의 근거가 우리 코드 밖에 있다.
3. **공허한 검사** — 아무것도 검증하지 않는 테스트/단언.
4. **협상 의존** — 같은 URL 이 요청자에 따라 다르게 답한다.
5. **하나를 고치며 다른 하나를 깨뜨림.**

**특히 답을 원하는 질문**:
- Q1. **`Post.publish_stuck` 의 SQL 이 정확한가?** 특히
  `"publish_error IS NOT NULL AND published_at <= :now OR published_at <= :cutoff"` —
  SQL 의 `AND`/`OR` 우선순위 때문에 의도가 어긋나지 않는가? 괄호가 필요한가?
  (의도: `(error 있음 AND 지금 지남) OR (유예 지남)`) 반례를 찾아라.
- Q2. `publish_stuck` **스코프**와 `publish_stuck?` **술어** 두 구현이 모든 입력에서
  일치하는가? 타임존·nil·경계값에서 갈리는 지점이 있는가?
  (`PUBLISH_GRACE = 26.hours` 의 근거: 잡이 하루 한 번 09:00 KST — `config/recurring.yml` 참조)
- Q3. **파생 상태가 정말 플래그보다 나은가?** 우리 주장은 "잡이 아예 안 돈 경우를 잡는다"
  인데, 반대로 **파생이 놓치는 경우**가 있는가? (예: 잡이 글을 발행했지만 다른 이유로
  되돌려진 경우, `published_at` 이 나중에 수정되는 경우, 사람이 손으로 `scheduled` 로
  되돌리는 경우 — 어드민에 그런 경로가 있는가?)
- Q4. `record_error`/`clear_error` 가 `update_column` 을 쓴다. **`updated_at` 을 건드리지
  않고 콜백·검증을 건너뛰는 것이 여기서 옳은가?** 다른 부작용이 있는가?
- Q5. **재시도 정책이 이 앱의 잡 구성에 맞는가?**
  `PublishScheduledPostsJob` 의 멱등성 주장("`scheduled_ready` 가 발행된 글을 즉시 제외하니
  재생이 무해")이 **정말 성립하는가?** 재생이 중복 메일을 보내거나 `publish_error` 를
  잘못 지우는 경로가 있는가? `AutoGenerateBlogPostJob` 이 재시도를 **안 받는 것**이 옳은가?
- Q6. `ApplicationMailDeliveryJob` 의 예외 목록이 적절한가? `retry_on` 과 `rescue_from` 을
  섞어 썼는데 **선언 순서에 따른 우선순위**가 의도대로인가?
  (`Net::SMTPAuthenticationError` 는 `retry_on` 목록에 없고 `rescue_from` 에만 있다)
  `ActionMailer::MailDeliveryJob` 자체의 `rescue_from StandardError` 와 충돌하지 않는가?
- Q7. **`rake jobs:failed` 의 가드가 옳은가?** `defined?(…) && table_exists?` 로 썼다
  (처음 상수만 보고 `PG::UndefinedTable` 로 죽는 것을 측정하고 고쳤다).
  프로덕션에서 이 태스크가 큐 DB(`connects_to` 별도 DB)를 제대로 읽는가?
- Q8. **시드를 "가드가 아니라 제거" 한 판단이 옳은가?** 남긴다면 구조적으로 막을 방법이
  있었는가? 마이그레이션이 **단일 소유자**가 된 것이 옳은가, 아니면 생성/갱신을 분리해야 하나?
- Q9. **`blog:migrate_privacy` 의 새 소유 범위가 정확한가?**
  `body_ko` 를 "비어 있을 때만 채운다" 로 바꾼 것이 **동작 변경**인데(전에는 항상 파일로 덮음),
  이로 인해 잃는 것이 있는가? `title_*`·`meta_*` 를 갱신 시 건드리지 않는 것이
  "파일이 진실" 이라는 원래 의도와 어긋나지 않는가?
- Q10. **`/up` 에 걸지 않은 판단**이 옳은가? 더 나은 자동 감지 지점이 있는가?
- Q11. **공허한 단언이 있는가?** 특히: 메일을 죽인 상태의 테스트가 실제로 메일이 죽은 것을
  단언하는가(`assert_empty deliveries`), 레이크 태스크를 같은 프로세스에서 돌리는
  `test/support/rake_task_helper.rb` 가 `abort` 의 종료코드를 제대로 번역하는가,
  "시드가 제거됐다" 테스트가 실제로 무언가를 검증하는가.
- Q12. **고치지 않기로 한 것**의 판단이 옳은가?
  (`rake jobs:failed`·`blog:stuck` 의 정기 실행 자동화 미도입 · `blog:generate` 계열의
  exit 0 유지 · Banner/BlogTopic/Conversion 속성명 ko 번역 없음)

**출력 형식**: 지적별로
```
[분류] [확신도] 제목
근거: <파일:줄>
설명: <어떤 입력에서 무엇이 잘못되는가>
```
마지막에 Q1~Q12 답변. 그리고 2건 각각에 대해 `해소됨 / 부분 해소 / 미해소` 판정.

---

## ② 근거 — 코드·젬 소스에서 다시 확인한 사실 (전부 재확인함)

| 사실 | 근거 |
|---|---|
| Solid Queue 는 **스스로 재시도하지 않는다** | `ClaimedExecution#perform` 이 실패 시 `failed_with(result.error)` 후 즉시 re-raise (`solid_queue-1.4.0/app/models/solid_queue/claimed_execution.rb:65-73`, 아래 인용) |
| `FailedExecution#retry` 는 **수동 전용** | `failed_execution.rb:21-29` (아래 인용) |
| 수정 전 재시도 정책이 **아예 없었다** | `ApplicationJob.rescue_handlers == []` (런타임 실측). 두 선언이 주석 처리된 스캐폴드였다 |
| 실패한 잡을 **아무도 읽지 않았다** | `app/`·`config/`·`lib/` 전체에 `rescue_from`·`failed_executions` 처리 0건 (수정 전) |
| 프로덕션 큐 | `config.active_job.queue_adapter = :solid_queue` (`config/environments/production.rb:53`) |
| dev 큐 | `ActiveJob::QueueAdapters::AsyncAdapter` (실측) — 큐 테이블이 없다 |
| **`MailDeliveryJob` 은 `ApplicationJob` 을 상속하지 않는다** | 실측: 조상 `[ActionMailer::MailDeliveryJob, ActiveJob::Base, ActiveJob::ConcurrencyControls, ActiveJob::EnqueueAfterTransactionCommit]` |
| **SMTP 실패 선례** | CLAUDE.md:145 — 2026-04-07 `GMAIL_PASSWORD` 빈 값 → `SMTPAuthenticationError 535-5.7.8` |
| 잡 실행 주기 | `config/recurring.yml` — `every day at 9am Asia/Seoul` (아래 전문) |
| `/up` 은 Kamal 헬스체크 | `deploy.yml` 에 `healthcheck.path` 없음 → kamal-proxy 기본값. 값 전달 지점은 `kamal-2.11.0/lib/kamal/configuration/proxy.rb:80` (`proxy_config.dig("healthcheck","path")`) |

### 젬 소스 인용 (위 두 줄 근거)

```ruby
# solid_queue-1.4.0/app/models/solid_queue/claimed_execution.rb:65-76
  def perform
    result = execute

    if result.success?
      finished
    else
      failed_with(result.error)
      raise result.error
    end
  ensure
    unblock_next_job
  end
```

```ruby
# solid_queue-1.4.0/app/models/solid_queue/failed_execution.rb:21-29
    def retry
      SolidQueue.instrument(:retry, job_id: job.id) do
        with_lock do
          job.reset_execution_counters
          job.prepare_for_execution
          destroy!
        end
      end
    end
```

## ③ B-2 재현 실측 — 시드가 마이그레이션을 되돌린다

개발 DB, 마이그레이션이 끝난 상태에서:

```
before:        category=privacy   title=이력서 속 개인정보…   status=published
after seed:    category=student   ← 되돌아갔다 (title/title_en/meta_* 도 시드 값으로 덮임)
after migrate: category=privacy   ← 마이그레이션을 다시 돌려야 복구된다
```

그 쓰기는 `abort` **전에** 일어난다 (항목1 저장 → 항목2·3 거부 → abort).

### 다른 시드 전수 확인 — 읽지 않고 **측정**했다

각 시드가 쓰는 레코드의 필드를 마커로 바꾼 뒤 시드를 돌려 마커가 살아남는지 봤다:

| 시드 | 패턴 | 결과 |
|---|---|---|
| `db/seeds.rb` (배너) | `find_or_create_by!(…) do \|b\| … end` — 블록은 **생성 시에만** 실행 | **PRESERVED** |
| `db/seeds/blog_topics.rb` | 동일 | **PRESERVED** |
| `db/seeds/blog_styles.rb` | 동일 | **PRESERVED** |
| `db/seeds/safefile_posts.rb` | `find_or_initialize_by` + **블록 밖** `assign_attributes` + `save!` | **OVERWRITTEN** ← 유일 |

⚠️ **첫 프로브에 결함이 있었다**: safefile 마커를 `"student"` 로 썼는데 시드가 쓰는 값과 같아
덮어쓰기와 보존이 구분되지 않았다("PRESERVED" 거짓 통과). 시드가 쓰지 않는 유효 값(`"office"`)
으로 다시 재서 `student` 로 덮이는 것을 확인했다.

## ④ 수정 후 검증

| 검증 | 결과 |
|---|---|
| `bin/rails test` | **156 runs / 1171 assertions / 0 failures** (직전 110/835) |
| **새 테스트가 직전 코드를 잡는가** | **67개 중 57개 실패/에러**. 원인별: `publish_stuck` 부재 41 · `PUBLISH_GRACE` 부재 2 · `publish_overdue_by` 부재 1 · `ApplicationMailDeliveryJob` 부재 3 · `rescue_handlers == []` 2 · 마이그레이션이 생성 못 함 1 · 마이그레이션이 본문을 덮음 1 |
| **메일이 완전히 죽은 상태** | `post_published`·`publish_failed` 양쪽 raise + `assert_empty deliveries` 단언 후에도 배너·스코프에서 글을 찾는다 |
| 엔드투엔드 (실제 HTTP) | 잡 → `publish_error` 기록 → `rake blog:stuck` exit 1 · 배너 "발행되지 못한 글 1건" · `Stuck (1)` 칩 · 한국어 이유 전부 확인 |
| 마이그레이션 생성 경로 | 3개 글을 **실제로 지우고** 재생성 — 카테고리·본문·제목·메타·발행일 정확 |
| 마이그레이션이 편집을 지키는가 | 5개 필드를 사람이 고친 것처럼 바꾼 뒤 재실행 → `saved_changes` 가 `[category, updated_at]` 뿐 |
| 직전 라운드 재실행 | 137경로 중복 200 **0개**, 루프 0, 홉 `{1: 89, 2: 1}` / 사이트맵 30·내부링크 64·Accept-Language 8페이지 문제 0 / SW 실패주입 **9/9** |
| rubocop | **신규 위반 0** (변경 파일 17개 10건 = 직전 커밋 사본 baseline 10건) |
| 프로덕션 DB | **미접촉** |

---

## ⑤ 핵심 파일 전문

#### `app/jobs/application_job.rb`

```ruby
# Retry policy for this app's own jobs.
#
# ── What the queue actually does (read from the gem, not assumed) ───────────
#
# Solid Queue does NOT retry on its own. SolidQueue::ClaimedExecution#perform
# calls `failed_with(result.error)` and re-raises immediately
# (solid_queue-1.4.0/app/models/solid_queue/claimed_execution.rb:65-73), and
# SolidQueue::FailedExecution#retry is a manual operation — something a human or
# a task has to invoke (failed_execution.rb:21-29). Every retry in this app
# therefore comes from ActiveJob's retry_on and nowhere else.
#
# Until 2026-09-18 both declarations here were commented-out scaffold, so
# `ApplicationJob.rescue_handlers` was literally `[]` (verified at runtime): a
# job that raised got ZERO retries and went straight into
# solid_queue_failed_executions, which nothing in this app read. `rake
# jobs:failed` now reads it.
#
# ── The mailer is NOT covered by this class ─────────────────────────────────
#
# ActionMailer::MailDeliveryJob inherits from ActiveJob::Base, not from
# ApplicationJob (verified: its ancestors are [MailDeliveryJob, ActiveJob::Base,
# …]). So nothing here affects `deliver_later`, and simply uncommenting those
# scaffold lines — the obvious "fix" — would have left mail delivery exactly as
# fragile while looking like it had been handled. Mail has its own policy in
# ApplicationMailDeliveryJob, wired up via config.action_mailer.delivery_job.
#
# ── Where the retries are declared, and why not here ────────────────────────
#
# Retrying is only safe for a job that can run twice without DOING anything
# twice, and that is a per-job property. It is deliberately not declared on this
# class, even though the scaffold invites exactly that:
#
#   * PublishScheduledPostsJob — retries the two transient database errors.
#     Replaying it is a no-op for work already done: Post.scheduled_ready stops
#     returning a post the moment it is published, so a second pass neither
#     re-publishes nor re-notifies anything.
#   * AutoGenerateBlogPostJob — takes NO retries, by omission and on purpose.
#     It spends Claude API credit and creates a Post, and a failure partway
#     through (say after Post.create! but before topic.update!) would on replay
#     pay for a second article and leave a duplicate slugged `-1`. When it
#     fails, it fails visibly (rake jobs:failed) and a human decides whether the
#     work is worth paying for again.
#
# A blanket `retry_on` here would quietly hand the second job the first job's
# policy. Anything shared belongs below; anything conditional belongs in the job
# that can actually answer the question.
class ApplicationJob < ActiveJob::Base
  # Safe for every job: the record the job was enqueued for no longer exists, so
  # no retry can ever succeed. Discarded rather than left to fail repeatedly —
  # but logged, because a job pointing at a deleted record usually means
  # something upstream deleted more than it meant to.
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.error("#{job.class}: discarded — the record no longer exists (#{error.class}: #{error.message})")
  end
end
```

#### `app/jobs/application_mail_delivery_job.rb`

```ruby
# Retry policy for outgoing mail.
#
# This class exists because ActionMailer::MailDeliveryJob inherits from
# ActiveJob::Base, NOT from ApplicationJob (verified at runtime: its ancestors
# are [ActionMailer::MailDeliveryJob, ActiveJob::Base, …]). Anything declared on
# ApplicationJob is therefore invisible to `deliver_later`, which is a trap: the
# obvious way to "add a retry policy to this app" is to uncomment the scaffold
# lines in ApplicationJob, and that would leave mail delivery untouched while
# looking finished.
#
# Wired up by config.application.rb via config.action_mailer.delivery_job.
#
# ── Why retry at all ────────────────────────────────────────────────────────
#
# Because SMTP has already failed here in production: 2026-04-07, a missing
# GMAIL_PASSWORD produced SMTPAuthenticationError 535-5.7.8. Solid Queue does
# not retry on its own (see ApplicationJob for the source), so before this
# every transient SMTP hiccup dropped a message permanently into
# solid_queue_failed_executions.
#
# ── What is NOT delegated to this ───────────────────────────────────────────
#
# A retry makes a lost message less likely; it does not make delivery a
# dependable channel. 535-5.7.8 was a *configuration* error — no number of
# retries would have delivered it. That is why the publish-failure signal does
# not live in email at all: Post.publish_stuck derives it from the posts table,
# and `rake blog:stuck` reads it without any mail involved. Mail is the nag, not
# the record.
class ApplicationMailDeliveryJob < ActionMailer::MailDeliveryJob
  # Transient SMTP and network conditions: the connection failed or the server
  # asked us to come back later. Spread out, because a mail server refusing
  # connections rarely recovers in a second.
  retry_on Net::SMTPServerBusy,
           Net::OpenTimeout,
           Net::ReadTimeout,
           IOError,
           Errno::ECONNRESET,
           Errno::ECONNREFUSED,
           Errno::EHOSTUNREACH,
           Errno::ETIMEDOUT,
           wait: :polynomially_longer,
           attempts: 5

  # Permanent refusals are NOT retried. A bad address or a rejected credential
  # (535-5.7.8 is exactly this) fails identically every time, so retrying only
  # delays the failure being recorded — and it must be recorded, because the
  # April incident was invisible for as long as nobody looked.
  rescue_from Net::SMTPAuthenticationError,
              Net::SMTPFatalError,
              Net::SMTPSyntaxError do |error|
    Rails.logger.error(
      "ApplicationMailDeliveryJob: mail permanently rejected, not retrying — " \
      "#{error.class}: #{error.message}"
    )
    raise error
  end
end
```

#### `app/jobs/publish_scheduled_posts_job.rb`

```ruby
# Publishes every scheduled post whose time has come. Runs daily at 09:00 KST
# (config/recurring.yml) with nobody watching, which is what makes the failure
# handling below the interesting part of this file.
#
# It used to be four unguarded lines: `post.update!` inside `find_each`. That was
# survivable while nothing could reject a Post — and then 2026-09-18 added
# `validates :body_ko, if: published`. From that commit on, one post missing a
# Korean body would raise RecordInvalid and take **every post behind it in the
# batch** down with it, silently, for as long as the bad record sat in the queue.
# Correctness went up and availability went down, and the trade was not noticed
# at the time.
#
# ── What fails, and how each failure is made visible ────────────────────────
#
#   failure                        | isolation          | surfaced as
#   -------------------------------|--------------------|---------------------
#   update! rejects the record     | skip this post,    | the post becomes
#   (RecordInvalid/RecordNotSaved) | batch continues    | Post.publish_stuck
#                                  |                    | + publish_error
#                                  |                    | + logger.error
#                                  |                    | + ONE admin email
#   notification fails to enqueue  | skip the mail,     | logger.error
#                                  | post STAYS         |
#                                  | published          |
#   anything else (DB down, …)     | retried by this    | if the retries are
#                                  | job's retry_on;    | exhausted, Solid
#                                  | otherwise it       | Queue records it
#                                  | propagates         | (rake jobs:failed)
#   the failure report itself      | rescued            | logger.error
#
# Skipping a post trades one failure mode for another: instead of a stalled
# batch we get a post that stays `scheduled` forever. The first version of this
# fix answered that with an email, and the cross-review was right to call that
# insufficient — this app's production SMTP has already failed once (2026-04-07,
# 535-5.7.8), Solid Queue does not retry of its own accord, and nothing here
# read its failed-executions table. A lost alert had to be treated as a premise,
# not a risk.
#
# So the primary channel is now STATE, not notification. Post.publish_stuck
# derives "past due and still scheduled" from columns that are already there, so
# it survives a dead mailer, a dead queue, and the job never running at all.
# Three independent places read it: the /admin/posts banner, its `stuck` filter,
# and `rake blog:stuck` (exit 1), which needs neither a browser nor the admin
# password. This job's only job is to enrich that state with a REASON
# (publish_error) and to keep nagging by email. Both are best-effort; neither is
# load-bearing.
#
# Infrastructure errors are deliberately NOT isolated per post. Swallowing a
# dropped connection would report every post as "invalid" and let the job exit
# successfully, throwing away the replay that would have published them.
class PublishScheduledPostsJob < ApplicationJob
  queue_as :default

  # Safe to replay, which is why the retry policy lives here rather than on
  # ApplicationJob: Post.scheduled_ready stops returning a post the instant it
  # is published, so a second pass re-publishes nothing and re-notifies nobody.
  # Both exceptions mean the database was momentarily unavailable — they say
  # nothing about the work having happened. Bounded attempts: if the database is
  # down longer than this, the failure should become visible (rake jobs:failed)
  # rather than be retried out of sight.
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3
  retry_on ActiveRecord::ConnectionNotEstablished, wait: :polynomially_longer, attempts: 3

  # Errors that mean *this record* cannot be saved. Narrow on purpose: these are
  # deterministic and per-post, so retrying the job would fail identically.
  RECORD_REJECTED = [ ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved ].freeze

  def perform
    skipped = []

    Post.scheduled_ready.find_each do |post|
      skipped << describe_failure(post) unless publish(post)
    end

    report(skipped) if skipped.any?
  end

  private

  # Returns true when the post is now published. Never raises for a rejected
  # record — that is the whole point — and never lets a mail problem undo a
  # publish that already happened.
  def publish(post)
    begin
      post.update!(status: "published")
    rescue *RECORD_REJECTED => e
      Rails.logger.error(
        "PublishScheduledPostsJob: '#{post.slug}' (id=#{post.id}) could not be published " \
        "and stays scheduled — #{e.class}: #{e.message}"
      )
      record_error(post, e)
      return false
    end

    Rails.logger.info("Published scheduled post: #{post.slug}")
    clear_error(post)
    notify(post)
    true
  end

  # Enrichment, not state. update_column on purpose: the record just failed
  # validation, so save would fail too — and writing the reason must not depend
  # on the record being valid. Post.publish_stuck already lists this post with or
  # without a reason, so a failure here costs legibility, never visibility.
  def record_error(post, error)
    post.update_column(:publish_error, "#{Time.current.iso8601} #{error.class}: #{error.message}")
  rescue StandardError => e
    Rails.logger.error("PublishScheduledPostsJob: could not record why '#{post.slug}' failed — #{e.class}: #{e.message}")
  end

  # A published post must not keep a stale reason around; the admin banner would
  # go on explaining a failure that no longer exists.
  def clear_error(post)
    post.update_column(:publish_error, nil) if post.publish_error.present?
  rescue StandardError => e
    Rails.logger.error("PublishScheduledPostsJob: could not clear the old error on '#{post.slug}' — #{e.class}: #{e.message}")
  end

  # The post is live by the time this runs. A mail failure is logged and dropped:
  # rolling the publish back to keep the notification honest would hide a page
  # that is already public.
  def notify(post)
    BlogMailer.post_published(post).deliver_later
  rescue StandardError => e
    Rails.logger.error(
      "PublishScheduledPostsJob: '#{post.slug}' was published but its notification " \
      "could not be enqueued — #{e.class}: #{e.message}"
    )
  end

  # Plain strings and integers only — this crosses an ActiveJob serialization
  # boundary via deliver_later, where a Post or an exception object would not.
  def describe_failure(post)
    { "slug" => post.slug, "id" => post.id, "errors" => post.errors.full_messages.join(", ") }
  end

  def report(skipped)
    Rails.logger.error(
      "PublishScheduledPostsJob: #{skipped.size} post(s) stayed scheduled: " \
      "#{skipped.map { |f| f["slug"] }.join(", ")}"
    )

    # Only the mail is guarded, deliberately narrowly: there is no alert for the
    # alert, and losing it must not cost the run, which has already published
    # everything it could.
    begin
      BlogMailer.publish_failed(skipped).deliver_later
    rescue StandardError => e
      Rails.logger.error("PublishScheduledPostsJob: failure report could not be sent — #{e.class}: #{e.message}")
    end
  end
end
```

#### `app/jobs/auto_generate_blog_post_job.rb`

```ruby
# Takes NO retries, deliberately and by omission — see ApplicationJob for why
# the policy is per-job rather than shared.
#
# This job is not idempotent in two ways that cost something real. It calls the
# Claude API (paid) before it writes anything, so a replay pays twice for one
# article. And a failure between `Post.create!` and `topic.update!` would, on
# replay, pick the same still-unused topic and create a second post whose slug
# collides and gets suffixed `-1`. Neither is a retry's decision to make: when
# this fails it fails visibly (`rake jobs:failed`) and a human decides whether
# the article is worth paying for again.
class AutoGenerateBlogPostJob < ApplicationJob
  queue_as :default

  def perform
    topic = BlogTopic.unused.order("RANDOM()").first
    unless topic
      Rails.logger.info("AutoGenerateBlogPostJob: No unused topics remaining")
      return
    end

    service = BlogGeneratorService.new
    result = service.generate_post(topic.topic, topic.category)

    unless result
      Rails.logger.error("AutoGenerateBlogPostJob: Failed to generate post for topic: #{topic.topic}")
      return
    end

    published_at = next_publish_date

    result.delete(:_generate_hero_image)
    post = Post.create!(
      **result.slice(:title_ko, :subtitle_ko, :body_ko, :meta_description_ko, :slug, :cover_svg,
                      :trust_bar, :pain_tag, :error_mockup, :recognition_text, :loss_items, :stats),
      category: topic.category,
      status: "draft",
      published_at: published_at
    )

    # 히어로 이미지 생성
    begin
      service.generate_hero_image(post)
    rescue => e
      Rails.logger.error("AutoGenerateBlogPostJob: Hero image failed for '#{post.slug}': #{e.message}")
    end

    topic.update!(used: true)
    BlogMailer.review_requested(post).deliver_later
    Rails.logger.info("AutoGenerateBlogPostJob: Created draft post '#{post.slug}' (suggested publish: #{published_at}, image: #{post.hero_image.attached?}) — review email enqueued")
  end

  private

  def next_publish_date
    last_scheduled = Post.where(status: "scheduled").order(published_at: :desc).first
    base_date = if last_scheduled&.published_at&.future?
      last_scheduled.published_at.to_date + 1.day
    else
      Date.current
    end

    find_next_mwf(base_date)
  end

  def find_next_mwf(from_date)
    date = from_date
    date += 1.day until [1, 3, 5].include?(date.cwday)
    date.in_time_zone("Asia/Seoul").change(hour: 9)
  end
end
```

#### `app/mailers/blog_mailer.rb`

```ruby
class BlogMailer < ApplicationMailer
  def post_published(post)
    @post = post
    @upcoming_posts = Post.where(status: "scheduled").order(:published_at).limit(3)
    @remaining_topics = BlogTopic.where(used: false).count

    mail(
      to: "chaop2@gmail.com",
      subject: "[SlimFile 블로그] 새 글 발행: #{post.title_ko}"
    )
  end

  # Sent by PublishScheduledPostsJob once per run in which at least one post
  # could not be published. `failures` is an array of plain hashes with string
  # keys ("slug", "id", "errors") — not Post records, because this crosses an
  # ActiveJob serialization boundary, and not exceptions, for the same reason.
  #
  # A post that fails validation stays `scheduled` and would otherwise sit there
  # unnoticed forever; the job runs daily, so this arrives daily until the record
  # is fixed. That repetition is intentional.
  def publish_failed(failures)
    @failures = failures

    mail(
      to: "chaop2@gmail.com",
      subject: "[SlimFile 블로그] 발행 실패 #{failures.size}건 — 예약 상태로 남았습니다"
    )
  end

  def review_requested(post)
    @post = post
    @remaining_topics = BlogTopic.where(used: false).count

    mail(
      to: "chaop2@gmail.com",
      subject: "[SlimFile 블로그] 검토 요청: #{post.title_ko}"
    )
  end
end
```

#### `app/mailers/application_mailer.rb`

```ruby
class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("GMAIL_USERNAME", "noreply@slimfile.net")
  layout "mailer"
end
```

#### `app/models/post.rb`

```ruby
class Post < ApplicationRecord
  has_one_attached :hero_image

  validates :title_ko, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :category, inclusion: { in: %w[privacy pdf image office student freelancer global] }
  validates :status, inclusion: { in: %w[draft scheduled published] }

  # The invariant: **a published post always has a Korean body.**
  #
  # Korean is the default locale, so /blog/:slug — the address every other
  # locale canonicalises to, the one x-default points at, and the only one the
  # language switcher can always reach — is the Korean page. A published post
  # with body_en but no body_ko makes that address real but not indexable:
  # indexable_locales comes back [:en], yet x-default still aims at the Korean
  # URL, which is noindex. Reproduced before writing this validation.
  #
  # Nothing builds that shape today (BlogGeneratorService writes Korean first,
  # and all 42 live posts have body_ko), so this closes a gap rather than fixing
  # a live defect. Drafts stay exempt: a post is created empty and filled in.
  validates :body_ko, presence: true, if: -> { status == "published" }

  scope :published, -> { where(status: "published") }
  scope :scheduled_ready, -> { where(status: "scheduled").where("published_at <= ?", Time.current) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }

  # ── Stuck posts ─────────────────────────────────────────────────────────
  #
  # A post whose time to be published has come and gone. This is the state that
  # makes a skipped publish visible, and it is DERIVED on purpose.
  #
  # PublishScheduledPostsJob skips a post it cannot publish so the rest of the
  # batch survives; the post then stays `scheduled`, possibly forever. The job
  # also emails about it — but this app's production SMTP has already failed
  # once (2026-04-07, 535-5.7.8), Solid Queue does not retry on its own
  # (ClaimedExecution#perform calls failed_with and re-raises), and nothing read
  # its failed-executions table. A lost alert is a premise here, not a risk.
  #
  # Computing the signal from `status` and `published_at` means it depends on
  # nothing but the row itself, and so it catches strictly more than a flag the
  # job would have had to write:
  #
  #   validation rejected the post   → flag ✓   derived ✓
  #   the job never ran at all       → flag ✗   derived ✓   (happened here:
  #                                                          SOLID_QUEUE_IN_PUMA
  #                                                          was false, 2026-04-07)
  #   the job died before this post  → flag ✗   derived ✓
  #
  # There are two ways to know a post is stuck, and they need different patience.
  #
  #   * A failure was RECORDED (publish_error present). The job tried and the
  #     record was rejected — that is evidence, not suspicion, so it counts the
  #     moment the post is past due. Waiting would mean sitting on a known
  #     answer.
  #   * NOTHING was recorded. Past due might just mean "waiting for the next
  #     run": the job fires once a day at 09:00 KST, so a post scheduled for
  #     09:30 honestly waits ~23.5 hours. Here a grace period is required, and
  #     26 hours clears that maximum honest wait with room to spare.
  #
  # This split came out of a test: with a single 26-hour rule, a post the job had
  # just rejected stayed invisible for a day, which is precisely the delay this
  # whole mechanism exists to remove.
  PUBLISH_GRACE = 26.hours

  scope :publish_stuck, ->(grace = PUBLISH_GRACE) {
    where(status: "scheduled")
      .where.not(published_at: nil)
      .where(
        "publish_error IS NOT NULL AND published_at <= :now OR published_at <= :cutoff",
        now: Time.current, cutoff: Time.current - grace
      )
  }

  def publish_stuck?(grace = PUBLISH_GRACE)
    return false unless status == "scheduled" && published_at.present?
    return published_at <= Time.current if publish_error.present?

    published_at <= Time.current - grace
  end

  # How overdue, for the admin list. nil when the post is not scheduled.
  def publish_overdue_by
    return nil unless status == "scheduled" && published_at.present?

    Time.current - published_at
  end

  before_validation :generate_slug, if: -> { slug.blank? && title_ko.present? }

  # ── Localized content ───────────────────────────────────────────────────
  #
  # `loc` is the locale of the URL being rendered, not the one I18n negotiated —
  # callers pass ApplicationHelper#url_locale. It is REQUIRED on purpose. These
  # three used to default to I18n.locale, and that default is the whole bug: an
  # unprefixed /blog/:slug served an English title and body to anyone sending
  # `Accept-Language: en` while still declaring the Korean canonical — one URL
  # with two contents, and an exact duplicate of /en/blog/:slug. A default would
  # let the next caller reintroduce it in silence; without one, forgetting is an
  # ArgumentError at the call site. Only a prefixed URL may serve localized
  # content.
  #
  # The fallback itself is unchanged: any non-Korean locale prefers the English
  # column and drops to Korean when it is empty (ja/es have no columns at all).
  def title(loc)
    loc.to_sym == :ko ? title_ko : (title_en.presence || title_ko)
  end

  def body(loc)
    loc.to_sym == :ko ? body_ko : (body_en.presence || body_ko)
  end

  def meta_description(loc)
    loc.to_sym == :ko ? meta_description_ko : (meta_description_en.presence || meta_description_ko)
  end

  # ── Indexing ────────────────────────────────────────────────────────────
  #
  # Blog posts only carry ko/en body columns. A locale counts as "translated"
  # only when that locale's body column is actually filled in — ja/es never are,
  # and en falls back to ko text (untranslated) unless body_en is present.
  def translated?(loc = I18n.locale)
    case loc.to_sym
    when :ko then body_ko.present?
    when :en then body_en.present?
    else false
    end
  end

  # The single rule behind every indexing signal this post emits.
  #
  #   status      | robots        | why
  #   ------------|---------------|--------------------------------------------
  #   published   | (none)        | live, and the body exists in this locale
  #   published   | noindex,follow| body not translated into this locale, so the
  #               |               | URL would put Korean text on an /en|ja|es
  #               |               | address
  #   scheduled   | noindex,follow| not live yet — PostsController#show serves it
  #   draft       | noindex,follow| 200 for preview, but it must never be indexed
  #
  # Preview keeps its 200; only the indexing directive changes.
  def indexable?(loc = I18n.locale)
    status == "published" && translated?(loc)
  end

  # Locales this post may actually be indexed under — drives sitemap + hreflang.
  # Empty for anything unpublished, which is a real answer and stays empty:
  # an unpublished post advertises no alternates at all.
  def indexable_locales
    [ :ko, :en ].select { |l| indexable?(l) }
  end

  def publish!
    update!(status: "published", published_at: Time.current) if published_at.blank?
    update!(status: "published")
  end

  private

  def generate_slug
    base = title_ko.to_s.parameterize
    base = SecureRandom.hex(6) if base.blank?
    self.slug = base
    counter = 1
    while Post.where(slug: slug).where.not(id: id).exists?
      self.slug = "#{base}-#{counter}"
      counter += 1
    end
  end
end
```

#### `app/controllers/admin/posts_controller.rb`

```ruby
module Admin
  class PostsController < BaseController
    before_action :set_post, only: [:edit, :update, :destroy, :generate, :improve, :publish]

    def index
      # Loaded unconditionally, not behind the filter: a post stuck at
      # `scheduled` is the one thing on this page nobody went looking for, so it
      # has to appear whichever view is selected. This is the primary channel for
      # that state — the publish-failure email is the secondary one, and this
      # app's production SMTP has already failed once (2026-04-07).
      @stuck_posts = Post.publish_stuck.order(:published_at)

      @posts = Post.recent
      @posts = if params[:status] == "stuck"
        @posts.publish_stuck
      elsif params[:status].present?
        @posts.where(status: params[:status])
      else
        @posts
      end
      @posts = @posts.by_category(params[:category]) if params[:category].present?
    end

    def new
      @post = Post.new(status: "draft")
    end

    def create
      @post = Post.new(post_params)
      if @post.save
        redirect_to edit_admin_post_path(@post), notice: "Post created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @post.update(post_params)
        redirect_to edit_admin_post_path(@post), notice: "Post updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @post.destroy
      redirect_to admin_posts_path, notice: "Post deleted."
    end

    def publish
      published_at = params[:published_at].presence&.then { |t| Time.zone.parse(t) } || Time.current
      @post.update!(status: "published", published_at: published_at)
      redirect_back fallback_location: admin_posts_path, notice: "Post published (#{published_at.strftime('%Y-%m-%d %H:%M')})."
    end

    def generate
      topic = params[:topic].to_s.strip
      if topic.blank?
        redirect_to edit_admin_post_path(@post), alert: "Topic is required."
        return
      end

      service = BlogGeneratorService.new
      result = service.generate_post(topic, @post.category || "image")
      if result
        generate_image = result.delete(:_generate_hero_image)
        @post.update!(result)
        service.generate_hero_image(@post) if generate_image
        redirect_to edit_admin_post_path(@post), notice: "Content generated by AI. #{'Hero image generated.' if @post.hero_image.attached?}"
      else
        redirect_to edit_admin_post_path(@post), alert: "AI generation failed. Check ANTHROPIC_API_KEY."
      end
    end

    def improve
      instruction = params[:instruction].to_s.strip
      if instruction.blank?
        redirect_to edit_admin_post_path(@post), alert: "Instruction is required."
        return
      end

      result = BlogGeneratorService.new.improve_post(@post, instruction)
      if result
        @post.update!(result)
        redirect_to edit_admin_post_path(@post), notice: "Content improved by AI."
      else
        redirect_to edit_admin_post_path(@post), alert: "AI improvement failed."
      end
    end

    def auto_generate
      topic = params[:topic].to_s.strip
      category = params[:category].presence || "image"
      if topic.blank?
        redirect_to admin_posts_path, alert: "Topic is required."
        return
      end

      post = Post.new(status: "draft", category: category)
      service = BlogGeneratorService.new
      result = service.generate_post(topic, category)
      if result
        generate_image = result.delete(:_generate_hero_image)
        post.assign_attributes(result)
        post.save!
        service.generate_hero_image(post) if generate_image
        redirect_to edit_admin_post_path(post), notice: "New post generated by AI. #{'Hero image generated.' if post.hero_image.attached?}"
      else
        redirect_to admin_posts_path, alert: "AI generation failed."
      end
    end

    private

    def set_post
      @post = Post.find(params[:id])
    end

    def post_params
      params.require(:post).permit(
        :title_ko, :title_en, :body_ko, :body_en, :slug, :category,
        :status, :published_at, :cover_svg, :meta_description_ko, :meta_description_en,
        :trust_bar, :pain_tag, :error_mockup, :recognition_text, :loss_items, :stats, :subtitle_ko
      )
    end
  end
end
```

#### `app/views/admin/posts/index.html.erb`

```erb
<% content_for :admin_title, "Blog Posts" %>

<%#
  Stuck posts, shown on every view of this page.

  A post that PublishScheduledPostsJob could not publish stays `scheduled`
  indefinitely, and the thing that used to report it was an email — which is not
  a channel this app can lean on (production SMTP failed 2026-04-07, and Solid
  Queue does not retry of its own accord). So the state is derived from the posts
  table by Post.publish_stuck and read here, where it needs no mailer, no queue,
  and not even the job to have run. `rake blog:stuck` reads the same scope from
  the command line for anyone without a browser.
%>
<% if @stuck_posts.any? %>
  <div style="background: #FCEBEB; border: 1px solid #A32D2D; border-left: 4px solid #A32D2D; border-radius: 14px; padding: 1rem 1.25rem; margin-bottom: 1.5rem;">
    <p style="margin: 0 0 0.75rem; font-size: 15px; font-weight: 600; color: #A32D2D; letter-spacing: -0.01em;">
      발행되지 못한 글 <%= @stuck_posts.size %>건 — 예약 시각이 지났는데 아직 예약 상태입니다
    </p>
    <p style="margin: 0 0 0.75rem; font-size: 13px; color: #6B6963; line-height: 1.55;">
      가장 흔한 원인은 <strong>한국어 본문(body_ko)이 비어 있는 것</strong>입니다 — 발행된 글은
      반드시 한국어 본문을 가져야 합니다. 본문을 채우고 저장하면 다음 실행(매일 09:00 KST)에 발행됩니다.
      잡이 아예 돌지 않는 경우에도 여기에 나타납니다.
    </p>
    <% @stuck_posts.each do |stuck| %>
      <div style="background: #ffffff; border: 0.5px solid #E5E3DC; border-radius: 10px; padding: 0.6rem 0.85rem; margin-bottom: 0.4rem;">
        <div style="display: flex; justify-content: space-between; align-items: center; gap: 0.75rem; flex-wrap: wrap;">
          <div>
            <strong style="font-size: 13px; color: #1A1918;"><%= stuck.slug %></strong>
            <span style="font-size: 12px; color: #6B6963;">
              &middot; 예약 <%= stuck.published_at&.strftime("%Y-%m-%d %H:%M") || "(미지정)" %>
              <% if stuck.publish_overdue_by %>
                &middot; <%= distance_of_time_in_words(stuck.publish_overdue_by) %> 경과
              <% end %>
            </span>
          </div>
          <a href="<%= edit_admin_post_path(stuck) %>" class="admin-btn admin-btn-sm admin-btn-primary">편집</a>
        </div>
        <div style="font-size: 12px; color: #A32D2D; margin-top: 0.35rem; word-break: break-word;">
          <%= stuck.publish_error.presence || "이유 미기록 — 잡이 이 글에 닿지 못했거나 아직 한 번도 시도하지 않았습니다" %>
        </div>
      </div>
    <% end %>
  </div>
<% end %>

<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
  <div style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
    <a href="<%= admin_posts_path %>" class="admin-btn admin-btn-sm <%= 'admin-btn-primary' if params[:status].blank? && params[:category].blank? %>">All</a>
    <% %w[draft scheduled published].each do |s| %>
      <a href="<%= admin_posts_path(status: s) %>" class="admin-btn admin-btn-sm <%= 'admin-btn-primary' if params[:status] == s %>"><%= s.capitalize %></a>
    <% end %>
    <a href="<%= admin_posts_path(status: "stuck") %>"
       class="admin-btn admin-btn-sm <%= 'admin-btn-primary' if params[:status] == 'stuck' %>"
       style="<%= 'border-color: #A32D2D; color: #A32D2D;' if params[:status] != 'stuck' && @stuck_posts.any? %>">
      Stuck<%= " (#{@stuck_posts.size})" if @stuck_posts.any? %>
    </a>
    <span style="color: var(--border-color);">|</span>
    <% %w[image pdf office student freelancer global].each do |c| %>
      <a href="<%= admin_posts_path(category: c) %>" class="admin-btn admin-btn-sm <%= 'admin-btn-primary' if params[:category] == c %>"><%= c.capitalize %></a>
    <% end %>
  </div>
  <a href="<%= new_admin_post_path %>" class="admin-btn admin-btn-primary">+ New Post</a>
</div>

<div style="background: white; border-radius: 14px; border: 0.5px solid #E5E3DC; padding: 1rem; margin-bottom: 1.5rem;">
  <form action="<%= auto_generate_admin_posts_path %>" method="post" style="display: flex; gap: 0.5rem; align-items: end;">
    <%= hidden_field_tag :authenticity_token, form_authenticity_token %>
    <div style="flex: 1;">
      <label style="font-size: 11px; font-weight: 600; color: var(--text-sub); display: block; margin-bottom: 0.25rem;">AI Auto-Generate</label>
      <input type="text" name="topic" placeholder="Enter topic in Korean..." style="width: 100%; padding: 0.4rem 0.75rem; border: 0.5px solid #E5E3DC; border-radius: 10px; font-size: 13px;">
    </div>
    <div>
      <select name="category" style="padding: 0.4rem 0.5rem; border: 0.5px solid #E5E3DC; border-radius: 10px; font-size: 13px;">
        <% %w[image pdf office student freelancer global].each do |c| %>
          <option value="<%= c %>"><%= c.capitalize %></option>
        <% end %>
      </select>
    </div>
    <button type="submit" class="admin-btn admin-btn-primary">Generate</button>
  </form>
</div>

<table class="admin-table">
  <thead>
    <tr>
      <th>Title</th>
      <th>Category</th>
      <th>Status</th>
      <th>Published</th>
      <th>Views</th>
      <th>Actions</th>
    </tr>
  </thead>
  <tbody>
    <% @posts.each do |post| %>
      <tr>
        <td style="max-width: 300px;"><%= truncate(post.title_ko.to_s, length: 50) %></td>
        <td><span class="admin-badge admin-badge-gray"><%= post.category %></span></td>
        <td>
          <span class="admin-badge <%= post.status == 'published' ? 'admin-badge-green' : 'admin-badge-gray' %>">
            <%= post.status %>
          </span>
        </td>
        <td style="font-size: 12px; color: var(--text-sub);"><%= post.published_at&.strftime("%Y-%m-%d %H:%M") || "-" %></td>
        <td style="font-size: 12px;"><%= post.view_count %></td>
        <td>
          <div class="admin-btn-group">
            <a href="<%= edit_admin_post_path(post) %>" class="admin-btn admin-btn-sm">Edit</a>
            <a href="<%= blog_post_path(slug: post.slug) %>" class="admin-btn admin-btn-sm" target="_blank">View</a>
            <% unless post.status == "published" %>
              <%= button_to "Publish", publish_admin_post_path(post), method: :post, class: "admin-btn admin-btn-sm admin-btn-primary", data: { turbo_confirm: "Publish this post now?" } %>
            <% end %>
            <%= button_to "Delete", admin_post_path(post), method: :delete, class: "admin-btn admin-btn-sm admin-btn-danger", data: { turbo_confirm: "Delete this post?" } %>
          </div>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

#### `lib/tasks/jobs.rake`

```ruby
# Visibility for the two things this app used to fail at silently:
# posts that never got published, and background jobs that died.
#
# Both tasks are read-only and exit non-zero when they find something, so they
# work under `kamal app exec` and can be wired to a monitor later without
# changing anything.
namespace :blog do
  desc "List posts whose publish time has passed but which are still scheduled (exit 1 if any)"
  task stuck: :environment do
    # The command-line view of Post.publish_stuck — the same scope the
    # /admin/posts banner reads. This exists because every other channel has a
    # dependency the failure might have taken out: email needs SMTP (which
    # failed here 2026-04-07), the banner needs a browser and the admin
    # password. This needs a shell.
    stuck = Post.publish_stuck.order(:published_at)

    if stuck.empty?
      puts "No stuck posts. (#{Post.where(status: 'scheduled').count} scheduled, all still within the #{Post::PUBLISH_GRACE.inspect} grace window.)"
      next
    end

    puts "#{stuck.size} post(s) past due and still scheduled:"
    stuck.each do |post|
      overdue = post.publish_overdue_by
      puts "  #{post.slug} (id=#{post.id})"
      puts "    scheduled : #{post.published_at&.iso8601 || '(none)'}#{overdue ? "  (#{(overdue / 3600).round} h ago)" : ''}"
      puts "    body_ko   : #{post.body_ko.present? ? "#{post.body_ko.to_s.length} bytes" : 'EMPTY — this is why a published post is rejected'}"
      puts "    reason    : #{post.publish_error.presence || '(not recorded — the job may never have reached this post)'}"
      puts "    edit      : /admin/posts/#{post.id}/edit"
    end

    abort "blog:stuck: #{stuck.size} post(s) need attention"
  end
end

namespace :jobs do
  desc "List Solid Queue failed executions (exit 1 if any)"
  task failed: :environment do
    # Solid Queue does not retry on its own: ClaimedExecution#perform calls
    # failed_with(error) and re-raises, and FailedExecution#retry is manual. So
    # anything in this table is work that stopped and stayed stopped — and until
    # now nothing in this app ever looked at it.
    # Guard on the TABLE, not on the constant. The gem is in the default bundle
    # group, so SolidQueue::FailedExecution is defined in every environment —
    # but only production sets `queue_adapter = :solid_queue`
    # (config/environments/production.rb:53) and only production has the queue
    # database, so in development the constant resolves and the query then dies
    # with PG::UndefinedTable. Measured, after writing it the other way first.
    unless defined?(SolidQueue::FailedExecution) && SolidQueue::FailedExecution.table_exists?
      puts "Solid Queue's queue database is not present here " \
           "(queue adapter: #{ActiveJob::Base.queue_adapter.class}). " \
           "This task is meaningful in production, where the adapter is :solid_queue."
      next
    end

    failures = SolidQueue::FailedExecution.includes(:job).order(created_at: :desc)

    if failures.empty?
      puts "No failed job executions."
      next
    end

    puts "#{failures.size} failed job execution(s), newest first:"
    failures.each do |failure|
      puts "  #{failure.job&.class_name || '(unknown job)'}  failed #{failure.created_at&.iso8601}"
      puts "    #{failure.exception_class}: #{failure.message}"
      puts "    job id #{failure.job_id}  —  retry with: SolidQueue::FailedExecution.find(#{failure.id}).retry"
    end

    abort "jobs:failed: #{failures.size} failed execution(s)"
  end
end
```

#### `lib/tasks/blog_migrate_privacy.rake`

```ruby
# The single owner of the three SafeFile privacy guide posts.
#
# ── Why this task creates as well as updates (2026-09-18) ───────────────────
#
# It used to only update, and `db/seeds/safefile_posts.rb` did the creating.
# That split was the bug. The seed predated everything: its premise was that the
# body lived in `public/blog/<slug>/index.html`, so it created `published` posts
# with no body at all — and `9f8bfff` (2026-07-17) deleted that directory while
# this task moved the bodies into the database and RENAMED two of the slugs.
# The seed kept the pre-rename slugs, so on a migrated database it no longer
# recognised the posts it had made and tried to create body-less duplicates.
#
# Measured, on the development database, before this change: running the seed
# flipped `resume-privacy` from category `privacy` back to `student` and
# overwrote its title and meta_description with its own hardcoded values —
# including anything a person had edited in the admin — and did so *before*
# aborting on the next item. Two tasks owning the same three rows meant whichever
# ran last won.
#
# So the seed is gone and this task creates too. One owner, no argument.
#
# `db/blog_privacy/*.html` is the source for a body that is MISSING. It is not a
# source of truth for a body that exists: this file's own purpose was to make the
# database authoritative, and a task that restores a file's copy over an admin
# edit is a revert button wearing a migration's name. So an existing body is left
# exactly as it is, and only a blank one is filled.
#
# Safe to run any number of times. Locates records by either their old or new
# slug, so a half-migrated database converges.
#
#   Run on production after deploy (safe to repeat):
#     kamal app exec 'bin/rails blog:migrate_privacy'
#
namespace :blog do
  # match_slugs: slugs a record may currently have (old first-run, new re-run)
  # The titles and descriptions are only ever applied at CREATE time — see above.
  PRIVACY_GUIDES = [
    {
      match_slugs: %w[resume-privacy],
      slug: "resume-privacy",
      file: "resume-privacy.html",
      title_ko: "이력서 속 개인정보, 어디까지 써야 할까",
      title_en: "Personal Info on Your Resume: How Much Is Too Much?",
      meta_description_ko: "이력서에 주민등록번호, 집 주소, 생년월일까지 다 써야 할까요? 채용에 꼭 필요한 정보와 지워도 되는 개인정보 7가지, 그리고 안전하게 가리는 방법을 정리했습니다.",
      meta_description_en: "Do you really need your ID number, home address, and birth date on a resume? 7 pieces of personal info you can safely remove — and how to redact them."
    },
    {
      match_slugs: %w[rrn-masking resident-number-masking],
      slug: "resident-number-masking",
      file: "resident-number-masking.html",
      title_ko: "주민등록번호 마스킹, 뒷자리만 가리면 될까",
      title_en: "Masking Korean ID Numbers: Is Hiding the Back Digits Enough?",
      meta_description_ko: "주민등록번호 뒷자리에는 어떤 정보가 들어 있을까요? 서류 제출 전 주민번호를 올바르게 마스킹하는 방법과 등본·신분증 사본 제출 시 주의사항을 정리했습니다.",
      meta_description_en: "What's actually encoded in a Korean RRN? How to mask resident registration numbers correctly before submitting documents or ID copies."
    },
    {
      match_slugs: %w[contract-checklist contract-sharing-checklist],
      slug: "contract-sharing-checklist",
      file: "contract-sharing-checklist.html",
      title_ko: "계약서·서류를 보내기 전, 8가지 체크리스트",
      title_en: "8-Point Privacy Checklist Before Sharing Contracts & Documents",
      meta_description_ko: "부동산 계약서, 프리랜서 계약서, 급여명세서를 카톡이나 메일로 보내기 전에 확인해야 할 개인정보 체크리스트. 계좌번호, 도장, 서명까지 놓치기 쉬운 항목을 정리했습니다.",
      meta_description_en: "A privacy checklist for sharing lease contracts, freelance agreements, and pay stubs — account numbers, stamps, and signatures people forget to redact."
    }
  ].freeze

  # The category these three belong to. The seed used to say student/office/
  # freelancer, which is exactly the disagreement that made them flip back and
  # forth depending on which task ran last.
  PRIVACY_CATEGORY = "privacy"

  desc "Create or update the three SafeFile privacy guide posts (idempotent, single owner)"
  task migrate_privacy: :environment do
    rejected = []

    PRIVACY_GUIDES.each do |spec|
      body = Rails.root.join("db/blog_privacy", spec[:file]).read.strip
      post = Post.where(slug: spec[:match_slugs]).order(:id).first
      creating = post.nil?

      if creating
        post = Post.new(
          slug: spec[:slug],
          title_ko: spec[:title_ko],
          title_en: spec[:title_en],
          meta_description_ko: spec[:meta_description_ko],
          meta_description_en: spec[:meta_description_en],
          body_ko: body,
          category: PRIVACY_CATEGORY,
          status: "published",
          published_at: Time.zone.parse("2026-07-16 09:00:00 +09:00")
        )
      else
        # Only the fields this task owns. Title and description are deliberately
        # untouched: overwriting them is what the deleted seed did wrong.
        post.slug     = spec[:slug]
        post.category = PRIVACY_CATEGORY
        post.body_ko  = body if post.body_ko.blank?
        post.status   = "published" if post.status.blank?
        post.published_at ||= Time.current
      end

      unless creating || post.changed?
        puts "  = #{spec[:slug]} (id=#{post.id}) already current"
        next
      end

      # One bad spec must not stop the others, and this task is idempotent, so
      # re-running after a fix costs nothing.
      begin
        post.save!
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
        rejected << "#{spec[:slug]}: #{e.message}"
        warn "  ! #{spec[:slug]} rejected — #{e.message} — skipping"
        next
      end

      verb = creating ? "created" : "updated"
      puts "  ✓ #{spec[:slug]} (id=#{post.id}) #{verb} [#{post.saved_changes.keys.join(', ')}]"
    end

    puts "Done. privacy posts: #{Post.where(category: PRIVACY_CATEGORY).pluck(:slug).sort.join(', ')}"

    # Every spec got its turn first; now fail, because this runs under
    # `kamal app exec` and a data task that changed nothing must not exit 0.
    abort "blog:migrate_privacy: #{rejected.size} post(s) rejected — #{rejected.join(' | ')}" if rejected.any?
  end
end
```

#### `lib/tasks/blog.rake`

```ruby
namespace :blog do
  desc "Generate N blog posts from unused topics (default: 10)"
  task :generate, [:count] => :environment do |_t, args|
    count = (args[:count] || 10).to_i
    service = BlogGeneratorService.new
    generated = 0

    count.times do |i|
      topic = BlogTopic.unused.order("RANDOM()").first
      unless topic
        puts "No more unused topics available. Generated #{generated} posts."
        break
      end

      puts "[#{i + 1}/#{count}] Generating: #{topic.topic} (#{topic.category})..."

      result = service.generate_post(topic.topic, topic.category)
      unless result
        puts "  FAILED — skipping"
        next
      end

      last_scheduled = Post.where(status: "scheduled").order(published_at: :desc).first
      base_date = if last_scheduled&.published_at&.future?
        last_scheduled.published_at.to_date + 1.day
      else
        Date.current
      end

      date = base_date
      date += 1.day until [1, 3, 5].include?(date.cwday)
      published_at = date.in_time_zone("Asia/Seoul").change(hour: 9)

      # `next` on a generator failure above already says what this loop wants:
      # one bad topic must not cost the ones behind it. A rejected record has to
      # follow the same rule, or a single validation failure throws away the API
      # spend for every remaining iteration.
      begin
        post = Post.create!(
          title_ko: result[:title_ko],
          body_ko: result[:body_ko],
          meta_description_ko: result[:meta_description_ko],
          slug: result[:slug],
          cover_svg: result[:cover_svg],
          category: topic.category,
          status: "scheduled",
          published_at: published_at
        )
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
        puts "  REJECTED — #{e.message} (topic left unused, skipping)"
        next
      end

      topic.update!(used: true)
      generated += 1
      puts "  OK — '#{post.slug}' scheduled for #{published_at.strftime('%Y-%m-%d %H:%M %Z')}"

      sleep 2 if i < count - 1
    end

    puts "\nDone! Generated #{generated} posts total."
  end

  desc "Seed blog topics from db/seeds/blog_topics.rb"
  task seed_topics: :environment do
    load Rails.root.join("db/seeds/blog_topics.rb")
  end

  # blog:seed_safefile_posts is GONE (2026-09-18), along with
  # db/seeds/safefile_posts.rb. It created the three SafeFile privacy guides
  # with pre-rename slugs and no body, so on a migrated database it fought
  # blog:migrate_privacy over the same three rows — measured: it flipped
  # resume-privacy's category from `privacy` back to `student` and overwrote its
  # title and meta_description with hardcoded values, including admin edits,
  # *before* aborting.
  #
  # Removed rather than guarded. Any guard can be argued past at 2am; a task
  # that does not exist cannot be run by mistake. blog:migrate_privacy now
  # creates as well as updates, so nothing was lost — see that file.

  desc "Generate and immediately publish 1 test post from unused topic"
  task publish_test: :environment do
    # Seed topics if none exist
    if BlogTopic.count.zero?
      puts "No blog topics found. Seeding..."
      load Rails.root.join("db/seeds/blog_topics.rb")
    end

    topic = BlogTopic.unused.order("RANDOM()").first
    unless topic
      puts "ERROR: No unused topics remaining"
      exit 1
    end

    puts "Selected topic: #{topic.topic} (#{topic.category})"
    puts "Generating post via Claude API..."

    service = BlogGeneratorService.new
    result = service.generate_post(topic.topic, topic.category)

    unless result
      puts "ERROR: BlogGeneratorService returned nil — check ANTHROPIC_API_KEY"
      exit 1
    end

    post = Post.create!(
      title_ko: result[:title_ko],
      body_ko: result[:body_ko],
      meta_description_ko: result[:meta_description_ko],
      slug: result[:slug],
      cover_svg: result[:cover_svg],
      category: topic.category,
      status: "published",
      published_at: Time.current
    )
    topic.update!(used: true)

    puts "SUCCESS: Published '#{post.title_ko}' (slug: #{post.slug})"
    puts "  URL: /blog/#{post.slug}"
    puts "  Category: #{post.category}"
    puts "  Published at: #{post.published_at}"
  end

  desc "Verify auto-publish flow: run PublishScheduledPostsJob and report results"
  task verify_autopublish: :environment do
    scheduled = Post.where(status: "scheduled")
    ready = Post.scheduled_ready
    puts "Scheduled posts total: #{scheduled.count}"
    puts "Ready to publish (published_at <= now): #{ready.count}"

    ready.each do |p|
      puts "  Will publish: #{p.slug} (published_at: #{p.published_at})"
    end

    if ready.any?
      puts "\nRunning PublishScheduledPostsJob..."
      PublishScheduledPostsJob.perform_now
      puts "Done. Newly published posts:"
      ready.reload.each do |p|
        puts "  #{p.slug}: status=#{p.status}"
      end
    else
      puts "\nNo posts ready to publish. Pulling earliest scheduled post to now for testing..."
      earliest = scheduled.order(:published_at).first
      if earliest
        old_date = earliest.published_at
        earliest.update!(published_at: Time.current - 1.minute)
        puts "  Moved '#{earliest.slug}' from #{old_date} to #{earliest.published_at}"
        puts "Running PublishScheduledPostsJob..."
        PublishScheduledPostsJob.perform_now
        earliest.reload
        puts "  Result: #{earliest.slug} status=#{earliest.status}"
      else
        puts "  No scheduled posts exist at all."
      end
    end

    puts "\n--- Blog Status ---"
    puts "Published: #{Post.where(status: 'published').count}"
    puts "Scheduled: #{Post.where(status: 'scheduled').count}"
    puts "Draft: #{Post.where(status: 'draft').count}"
    Post.where(status: "scheduled").order(:published_at).limit(5).each do |p|
      puts "  Next: #{p.slug} → #{p.published_at}"
    end
  end

  desc "Regenerate scheduled posts with new prompt (max 5)"
  task regenerate_scheduled: :environment do
    service = BlogGeneratorService.new
    posts = Post.where(status: "scheduled").order(:published_at).limit(5)

    if posts.empty?
      puts "No scheduled posts to regenerate."
      next
    end

    puts "Regenerating #{posts.count} scheduled posts..."

    posts.each_with_index do |post, i|
      topic = BlogTopic.find_by(topic: post.title_ko, used: true) ||
              BlogTopic.where(category: post.category, used: true).first

      topic_text = topic&.topic || post.title_ko
      puts "[#{i + 1}/#{posts.count}] Regenerating: #{topic_text} (#{post.category})..."

      result = service.generate_post(topic_text, post.category)
      unless result
        puts "  FAILED — skipping"
        next
      end

      # Same reasoning as blog:generate — the loop already skips a failed
      # generation, so a rejected record must not abort the remaining posts.
      begin
        post.update!(
          title_ko: result[:title_ko],
          body_ko: result[:body_ko],
          meta_description_ko: result[:meta_description_ko],
          cover_svg: result[:cover_svg]
        )
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
        puts "  REJECTED — #{e.message} (left as-is, skipping)"
        next
      end

      puts "  OK — updated '#{post.slug}' (published_at: #{post.published_at})"
      sleep 3 if i < posts.count - 1
    end

    puts "\nDone!"
  end

  desc "Generate 1 new post with new prompt and publish immediately"
  task publish_new: :environment do
    topic = BlogTopic.unused.order("RANDOM()").first
    unless topic
      puts "ERROR: No unused topics remaining"
      exit 1
    end

    puts "Selected topic: #{topic.topic} (#{topic.category})"
    puts "Generating post with psychology-based prompt..."

    service = BlogGeneratorService.new
    result = service.generate_post(topic.topic, topic.category)

    unless result
      puts "ERROR: BlogGeneratorService returned nil — check ANTHROPIC_API_KEY"
      exit 1
    end

    post = Post.create!(
      title_ko: result[:title_ko],
      body_ko: result[:body_ko],
      meta_description_ko: result[:meta_description_ko],
      slug: result[:slug],
      cover_svg: result[:cover_svg],
      category: topic.category,
      status: "published",
      published_at: Time.current
    )
    topic.update!(used: true)

    puts "SUCCESS: Published '#{post.title_ko}'"
    puts "  Slug: #{post.slug}"
    puts "  URL: https://slimfile.net/blog/#{post.slug}"
    puts "  Category: #{post.category}"
  end
end
```

#### `db/seeds.rb`

```ruby
# Default banners
banners = [
  {
    title_en: "Looking for a teaching job?",
    title_ko: "강사 구직 중이신가요?",
    description_en: "Find the perfect teaching position with TeacherMatch.",
    description_ko: "TeacherMatch에서 완벽한 강사 포지션을 찾아보세요.",
    link_url: "https://teachermatch.kr",
    button_text_en: "Visit TeacherMatch",
    button_text_ko: "TeacherMatch 방문",
    position: "after_result",
    page: "all",
    banner_type: "internal",
    sort_order: 1
  },
  {
    title_en: "Want to learn Korean?",
    title_ko: "한국어 배우고 싶으신가요?",
    description_en: "Start your Korean language journey with HelloKorean.",
    description_ko: "HelloKorean과 함께 한국어 학습을 시작하세요.",
    link_url: "https://hellokorean.org",
    button_text_en: "Start Learning",
    button_text_ko: "학습 시작하기",
    position: "after_result",
    page: "all",
    banner_type: "internal",
    sort_order: 2
  },
  {
    title_en: "Create your own link page",
    title_ko: "나만의 링크 페이지 만들기",
    description_en: "Build a beautiful link-in-bio page in minutes with rolli.",
    description_ko: "rolli로 몇 분 만에 아름다운 링크 페이지를 만드세요.",
    link_url: "https://rolli.ac",
    button_text_en: "Try rolli",
    button_text_ko: "rolli 시작하기",
    position: "after_result",
    page: "all",
    banner_type: "internal",
    sort_order: 3
  }
]

banners.each do |attrs|
  Banner.find_or_create_by!(title_en: attrs[:title_en]) do |b|
    b.assign_attributes(attrs)
  end
end

puts "Seeded #{Banner.count} banners."

# Blog topics
load Rails.root.join("db/seeds/blog_topics.rb")

# Blog styles
load Rails.root.join("db/seeds/blog_styles.rb")
```

#### `db/seeds/blog_styles.rb`

```ruby
BlogStyle.find_or_create_by!(source_name: "기본 전략") do |style|
  style.hooking_patterns = [
    { pattern: "오류/문제 상황 직접 묘사", example: "이메일 전송 버튼을 눌렀는데 '파일이 너무 큽니다' 오류가 떴나요?", when_to_use: "독자가 겪는 구체적 오류 상황을 다룰 때" },
    { pattern: "숫자로 손실 보여주기", example: "공항에서 환전하면 10만원당 최대 3,000원을 더 냅니다", when_to_use: "비교/절약 관련 주제일 때" },
    { pattern: "시간 압박형", example: "마감 30분 전, 파일이 안 보내진다면", when_to_use: "긴급한 상황을 다룰 때" }
  ].to_json

  style.sentence_structure = [
    { feature: "짧은 문장으로 리듬감", example: "파일이 크다. 보내지지 않는다. 마감은 다가온다." },
    { feature: "구체적 상황 묘사로 시작", example: "새벽 2시, 과제 제출 마감 10분 전..." }
  ].to_json

  style.psychological_triggers = [
    { trigger: "손실 회피", description: "얻는 것보다 잃는 것에 더 민감하게 반응", example: "지금 이걸 모르면 계속 손해봅니다" },
    { trigger: "사회적 증거", description: "다른 사람들도 같은 문제를 겪는다는 안도감", example: "하루 2,847명이 이 방법으로 해결했어요" },
    { trigger: "즉각 해결 가능성", description: "복잡하지 않고 바로 해결된다는 확신", example: "30초면 됩니다" }
  ].to_json

  style.tone_style = {
    overall_tone: "친근하지만 신뢰감 있는 전문가 톤",
    key_characteristics: ["구체적 숫자 사용", "독자 상황 공감 먼저", "해결책은 단계별로 명확하게"],
    avoid: ["막연한 표현 (예: 많이, 빠르게, 좋아요)", "과장된 수식어", "수동태 남용"]
  }.to_json

  style.is_active = true
  style.notes = "시스템 기본 전략 — 심리 마케팅 기반 블로그 글쓰기 패턴"
end

puts "BlogStyle seed: 기본 전략 created/found"
```

#### `db/migrate/20260917170741_add_publish_error_to_posts.rb`

```ruby
# Why this column carries the reason and not the state.
#
# PublishScheduledPostsJob skips a post it cannot publish, so the post stays
# `scheduled` — possibly forever. The failure that hid before was that the only
# thing telling anyone was an email, and this app's production SMTP has already
# failed once (2026-04-07, 535-5.7.8).
#
# The authoritative signal is therefore DERIVED, not stored: Post.publish_stuck
# computes it from `status` and `published_at`, which are already there. That
# depends on nothing except the post row, so it also catches the job never
# running at all — which is the failure that actually happened here in April.
#
# This column only ever carries the *reason*, written best-effort with
# update_column (deliberately bypassing validation: the record being invalid is
# precisely why we are writing) and cleared on a successful publish. A post with
# no reason recorded still shows up as stuck.
class AddPublishErrorToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :publish_error, :text
  end
end
```

#### `config/recurring.yml`

```yaml
# examples:
#   periodic_cleanup:
#     class: CleanSoftDeletedRecordsJob
#     queue: background
#     args: [ 1000, { batch_size: 500 } ]
#     schedule: every hour
#   periodic_cleanup_with_command:
#     command: "SoftDeletedRecord.due.delete_all"
#     priority: 2
#     schedule: at 5am every day

production:
  publish_scheduled_posts:
    class: PublishScheduledPostsJob
    schedule: every day at 9am Asia/Seoul
  auto_generate_blog_post:
    class: AutoGenerateBlogPostJob
    schedule: every Monday, Wednesday, and Friday at 0am Asia/Seoul
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12
```

#### `config/queue.yml`

```yaml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 0.1

development:
  <<: *default

test:
  <<: *default

production:
  <<: *default
```

#### `test/support/rake_task_helper.rb`

```ruby
# frozen_string_literal: true

require "rake"

# Invoking a rake task from inside a test, without the two traps.
#
# 1. NOT a child process. The first version of these tests shelled out to
#    `bin/rails blog:stuck`, and the task reported nothing — because the records
#    the test had created lived in an uncommitted transaction the child could not
#    see. A green assertion and an invisible database look identical from
#    outside. So the task runs here, in the transaction.
# 2. `abort` raises SystemExit rather than setting an exit status, so it is
#    translated back into the code a shell would have seen. Tasks in this app use
#    `abort` deliberately (they run under `kamal app exec`, where exiting 0 after
#    doing nothing reads as success), and that behaviour is worth asserting.
#
# Rails.application.load_tasks is memoized per process: calling it twice reloads
# railties' own rake files and prints "already initialized constant
# STATS_DIRECTORIES" warnings over the test output.
module RakeTaskHelper
  def self.load_tasks_once
    return if @loaded

    Rails.application.load_tasks
    @loaded = true
  end

  # Returns [combined stdout+stderr, exit code].
  def invoke_task(name)
    RakeTaskHelper.load_tasks_once
    task = Rake::Task[name]
    task.reenable

    captured = StringIO.new
    original_stdout, original_stderr = $stdout, $stderr
    $stdout = $stderr = captured
    code = 0
    begin
      task.invoke
    rescue SystemExit => e
      code = e.status
    ensure
      $stdout, $stderr = original_stdout, original_stderr
    end

    [ captured.string, code ]
  end

  def rake_task_defined?(name)
    RakeTaskHelper.load_tasks_once
    Rake::Task.task_defined?(name)
  end
end
```

#### `test/jobs/publish_scheduled_posts_job_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"
require "minitest/mock" # Object#stub — not loaded by rails/test_help

# The job runs unattended at 09:00 KST, so these tests are about what happens
# when a post refuses to be published — and, just as much, about the failure
# mode the fix introduces: a skipped post stays `scheduled` forever unless
# something says so out loud.
class PublishScheduledPostsJobTest < ActiveJob::TestCase
  REPORT_SUBJECT = "발행 실패"
  NOTICE_SUBJECT = "새 글 발행"

  setup do
    # The fixtures include a scheduled post, but its published_at is in the
    # future, so scheduled_ready is empty until a test fills it.
    assert_empty Post.scheduled_ready, "expected no ready posts before the test sets them up"
    assert_empty Post.publish_stuck, "expected no stuck posts before the test sets them up"
    ActionMailer::Base.deliveries.clear
  end

  # A post that cannot be published: `validates :body_ko, if: published` rejects
  # it. Written with update_column to bypass the very validation under test —
  # nothing in the app builds this shape today, which is the point. The job has
  # to survive a record it has never seen.
  def ready_post(slug:, body_ko: "<p>본문</p>")
    post = Post.create!(
      title_ko: "예약 #{slug}", slug: slug, category: "pdf",
      status: "scheduled", published_at: 1.hour.ago, body_ko: "<p>임시</p>"
    )
    post.update_column(:body_ko, body_ko)
    post
  end

  def with_captured_log
    original = Rails.logger
    buffer = StringIO.new
    logger = ActiveSupport::Logger.new(buffer)
    # The default formatter writes the message alone, which would make an
    # assertion about the severity pass no matter what level was used.
    logger.formatter = ->(severity, _time, _progname, msg) { "#{severity} #{msg}\n" }
    Rails.logger = logger
    yield
    buffer.string
  ensure
    Rails.logger = original
  end

  def mails_titled(fragment)
    ActionMailer::Base.deliveries.select { |m| m.subject.to_s.include?(fragment) }
  end

  # ── one bad record must not cost the batch ──────────────────────────────

  test "a post that fails validation does not stop the posts behind it" do
    # Bad-first on purpose: find_each walks primary key order, so this is the
    # arrangement in which the unguarded update! destroyed the whole run.
    bad = ready_post(slug: "job-bad-first", body_ko: "")
    good_a = ready_post(slug: "job-good-a")
    good_b = ready_post(slug: "job-good-b")

    assert_nothing_raised { PublishScheduledPostsJob.perform_now }

    assert_equal "scheduled", bad.reload.status, "the invalid post must stay scheduled"
    assert_equal "published", good_a.reload.status
    assert_equal "published", good_b.reload.status
  end

  test "a bad record in the middle is skipped and the rest publish" do
    first = ready_post(slug: "job-mid-first")
    bad = ready_post(slug: "job-mid-bad", body_ko: "")
    last = ready_post(slug: "job-mid-last")

    PublishScheduledPostsJob.perform_now

    assert_equal "published", first.reload.status
    assert_equal "scheduled", bad.reload.status
    assert_equal "published", last.reload.status
  end

  test "every ready post publishes when nothing is wrong" do
    posts = 3.times.map { |i| ready_post(slug: "job-ok-#{i}") }

    PublishScheduledPostsJob.perform_now

    posts.each { |p| assert_equal "published", p.reload.status, p.slug }
  end

  # ── the skip has to be visible ──────────────────────────────────────────
  #
  # Skipping is a trade: a stalled batch becomes a post stuck at `scheduled`.
  # If that is only a log line, "stuck" means "stuck forever". These pin both
  # channels — the per-post log and the one-per-run email.

  test "the skipped post is named in the log at error level" do
    ready_post(slug: "job-logged-bad", body_ko: "")
    ready_post(slug: "job-logged-good")

    log = with_captured_log { PublishScheduledPostsJob.perform_now }

    assert_match(/ERROR.*job-logged-bad/, log)
    assert_match(/stays scheduled/, log)
    assert_no_match(/ERROR.*job-logged-good/, log)
  end

  test "a run that skipped anything sends one failure report and publishes the rest" do
    ready_post(slug: "job-report-bad-1", body_ko: "")
    ready_post(slug: "job-report-bad-2", body_ko: "")
    ready_post(slug: "job-report-good")

    PublishScheduledPostsJob.perform_now
    perform_enqueued_jobs

    assert_equal 1, mails_titled(REPORT_SUBJECT).size
    assert_equal 1, mails_titled(NOTICE_SUBJECT).size
  end

  test "the failure report lists every skipped post once, however many there are" do
    ready_post(slug: "job-many-bad-1", body_ko: "")
    ready_post(slug: "job-many-bad-2", body_ko: "")
    ready_post(slug: "job-many-bad-3", body_ko: "")

    PublishScheduledPostsJob.perform_now
    perform_enqueued_jobs

    reports = mails_titled(REPORT_SUBJECT)
    assert_equal 1, reports.size, "a systemic failure must not become a mailbox flood"

    body = reports.first.body.encoded
    %w[job-many-bad-1 job-many-bad-2 job-many-bad-3].each { |slug| assert_includes body, slug }
    assert_includes reports.first.subject, "3건"
  end

  test "the report says which post and why, and links to the editor" do
    post = ready_post(slug: "job-why-bad", body_ko: "")

    PublishScheduledPostsJob.perform_now
    perform_enqueued_jobs

    body = mails_titled(REPORT_SUBJECT).first.body.encoded
    assert_includes body, "job-why-bad"
    assert_includes body, "/admin/posts/#{post.id}/edit"
    # The validation message itself, so the mail explains rather than just alerts.
    assert_match(/본문|body|Body/, body)
  end

  test "no failure report is sent when every post published" do
    ready_post(slug: "job-clean-a")
    ready_post(slug: "job-clean-b")

    PublishScheduledPostsJob.perform_now
    perform_enqueued_jobs

    assert_empty mails_titled(REPORT_SUBJECT)
    assert_equal 2, mails_titled(NOTICE_SUBJECT).size
  end

  test "the report survives the ActiveJob serialization boundary" do
    # Plain strings and integers only. A Post or an exception object would raise
    # on the way into the queue — in production, not here, since deliver_later
    # serializes at enqueue time and the job under test would already be green.
    ready_post(slug: "job-serial-bad", body_ko: "")

    PublishScheduledPostsJob.perform_now
    assert_nothing_raised { perform_enqueued_jobs }

    assert_equal 1, mails_titled(REPORT_SUBJECT).size,
      "the failure report must actually render and deliver, not merely enqueue"
  end

  # ── published posts still get their notification ────────────────────────

  test "each published post is announced" do
    ready_post(slug: "job-notify-a")
    ready_post(slug: "job-notify-b")

    PublishScheduledPostsJob.perform_now
    perform_enqueued_jobs

    assert_equal 2, mails_titled(NOTICE_SUBJECT).size
  end

  test "a notification failure leaves the post published and the batch running" do
    ready_post(slug: "job-mailfail-a")
    ready_post(slug: "job-mailfail-b")

    BlogMailer.stub(:post_published, ->(_post) { raise StandardError, "smtp exploded" }) do
      log = with_captured_log { assert_nothing_raised { PublishScheduledPostsJob.perform_now } }
      assert_match(/was published but its notification/, log)
    end

    # Rolling the publish back to keep the notification honest would hide a page
    # that is already public, so it must not happen.
    assert_equal "published", Post.find_by(slug: "job-mailfail-a").status
    assert_equal "published", Post.find_by(slug: "job-mailfail-b").status
  end

  test "a failure report that cannot be sent does not cost the run" do
    good = ready_post(slug: "job-reportfail-good")
    ready_post(slug: "job-reportfail-bad", body_ko: "")

    BlogMailer.stub(:publish_failed, ->(_failures) { raise StandardError, "mailer down" }) do
      log = with_captured_log { assert_nothing_raised { PublishScheduledPostsJob.perform_now } }
      assert_match(/failure report could not be sent/, log)
    end

    assert_equal "published", good.reload.status
  end

  # ── the state channel, which does not depend on mail ────────────────────
  #
  # This is the part the first version of the fix got wrong. Skipping a post was
  # reported by email alone, and email is not a channel this app can lean on:
  # production SMTP failed on 2026-04-07 (535-5.7.8) and Solid Queue does not
  # retry of its own accord. The assertions below are written so that mail is
  # *broken* in the ones that matter.

  test "a skipped post is visible as state even when mail cannot be sent at all" do
    ready_post(slug: "job-state-bad", body_ko: "")
    good = ready_post(slug: "job-state-good")

    # Every mail path down: the per-post notification AND the failure report.
    BlogMailer.stub(:post_published, ->(_p) { raise StandardError, "smtp down" }) do
      BlogMailer.stub(:publish_failed, ->(_f) { raise StandardError, "smtp down" }) do
        assert_nothing_raised { PublishScheduledPostsJob.perform_now }
      end
    end

    perform_enqueued_jobs
    assert_empty ActionMailer::Base.deliveries, "this test is only meaningful with mail broken"

    # ...and the stuck post is still discoverable, from the database alone.
    assert_equal [ "job-state-bad" ], Post.publish_stuck.map(&:slug)
    assert_equal "published", good.reload.status
  end

  test "the reason is recorded on the post, not only in the log" do
    ready_post(slug: "job-reason-bad", body_ko: "")

    PublishScheduledPostsJob.perform_now

    post = Post.find_by(slug: "job-reason-bad")
    assert post.publish_error.present?, "the admin banner has nothing to show without this"
    assert_match(/RecordInvalid/, post.publish_error)
  end

  test "a post with no recorded reason is still reported as stuck" do
    # The job may never have reached it — Solid Queue was down, the scheduler
    # never fired, the process died. The derived scope must not need the job to
    # have run, because "the job never ran" is the failure that happened here in
    # April 2026.
    post = ready_post(slug: "job-never-tried")
    post.update_columns(published_at: 3.days.ago, publish_error: nil)

    assert_includes Post.publish_stuck.map(&:slug), "job-never-tried"
    assert_nil post.reload.publish_error
  end

  test "a stale reason is cleared once the post publishes" do
    post = ready_post(slug: "job-recovered", body_ko: "")
    PublishScheduledPostsJob.perform_now
    assert post.reload.publish_error.present?

    # The body gets filled in, the way a person would fix it.
    post.update_column(:body_ko, "<p>이제 본문이 있다</p>")
    PublishScheduledPostsJob.perform_now

    assert_equal "published", post.reload.status
    assert_nil post.publish_error, "the banner would keep explaining a failure that is over"
  end

  test "publishing normally leaves no stuck posts behind" do
    ready_post(slug: "job-clean-state-a")
    ready_post(slug: "job-clean-state-b")

    PublishScheduledPostsJob.perform_now

    assert_empty Post.publish_stuck
  end

  # ── retry policy ────────────────────────────────────────────────────────

  test "this job retries transient database errors because replaying it is a no-op" do
    handled = PublishScheduledPostsJob.rescue_handlers.map(&:first)
    assert_includes handled, "ActiveRecord::Deadlocked"
    assert_includes handled, "ActiveRecord::ConnectionNotEstablished"
  end

  test "replaying the job publishes nothing twice" do
    # The property the retry policy rests on: scheduled_ready stops returning a
    # post the moment it is published, so a second pass is a no-op.
    ready_post(slug: "job-replay-a")
    ready_post(slug: "job-replay-b")

    PublishScheduledPostsJob.perform_now
    published_at_values = Post.where(slug: %w[job-replay-a job-replay-b]).order(:slug).pluck(:published_at)

    PublishScheduledPostsJob.perform_now
    perform_enqueued_jobs

    assert_equal published_at_values,
      Post.where(slug: %w[job-replay-a job-replay-b]).order(:slug).pluck(:published_at)
    assert_equal 2, mails_titled(NOTICE_SUBJECT).size, "a replay must not re-announce"
  end

  # ── infrastructure errors must NOT be isolated ──────────────────────────

  # Only errors meaning "this record cannot be saved" are isolated. Anything
  # else must leave the per-post rescue — either to be retried by this job's own
  # retry_on, or to propagate and be recorded.
  def with_error_from_update(error_class, message = "boom")
    victim = Post.new(slug: "job-infra", title_ko: "x")
    victim.define_singleton_method(:update!) { |*| raise error_class, message }

    relation = Object.new
    relation.define_singleton_method(:find_each) { |&block| block.call(victim) }

    Post.stub(:scheduled_ready, relation) { yield }
  end

  test "a transient database error is retried, not mistaken for an invalid record" do
    # Before the retry policy this propagated. Now the job re-enqueues itself.
    # Either way the thing that must NOT happen is it being filed as a rejected
    # record: that would let the run finish "successfully" having published
    # nothing, and report perfectly good posts as broken.
    assert_enqueued_with(job: PublishScheduledPostsJob) do
      with_error_from_update(ActiveRecord::ConnectionNotEstablished, "db gone") do
        assert_nothing_raised { PublishScheduledPostsJob.perform_now }
      end
    end

    assert_empty mails_titled(REPORT_SUBJECT)
    assert_nil Post.find_by(slug: "job-infra"), "nothing should have been written"
  end

  test "an error outside both lists propagates and is recorded, not swallowed" do
    # Solid Queue does not retry on its own — ClaimedExecution#perform calls
    # failed_with and re-raises — so propagating is what puts this failure in
    # solid_queue_failed_executions, where `rake jobs:failed` can find it.
    # Swallowing it would leave no trace anywhere.
    with_error_from_update(ActiveRecord::StatementInvalid, "syntax error") do
      assert_raises(ActiveRecord::StatementInvalid) { PublishScheduledPostsJob.perform_now }
    end

    perform_enqueued_jobs
    assert_empty mails_titled(REPORT_SUBJECT)
  end

  test "a transient error does not leave a post looking stuck for the wrong reason" do
    with_error_from_update(ActiveRecord::ConnectionNotEstablished, "db gone") do
      PublishScheduledPostsJob.perform_now
    end

    assert_empty Post.publish_stuck, "a database blip is not a stuck post"
  end
end
```

#### `test/jobs/retry_policy_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"

# What the retry policy is, pinned where it can be checked.
#
# Two facts make this worth asserting rather than trusting:
#
#   1. Solid Queue does not retry on its own. SolidQueue::ClaimedExecution#perform
#      calls failed_with(error) and re-raises (claimed_execution.rb:65-73), and
#      FailedExecution#retry is a manual operation. Every retry in this app comes
#      from ActiveJob's retry_on and nowhere else, so an empty policy means zero
#      retries — which is what ApplicationJob had until 2026-09-18, its
#      declarations being commented-out scaffold.
#   2. ActionMailer::MailDeliveryJob inherits from ActiveJob::Base, NOT from
#      ApplicationJob. Declaring retries on ApplicationJob therefore does nothing
#      for deliver_later, which is the trap: the obvious fix looks complete and
#      leaves mail exactly as fragile.
class RetryPolicyTest < ActiveSupport::TestCase
  def handlers_for(klass)
    klass.rescue_handlers.map(&:first)
  end

  # ── the premise these tests exist for ───────────────────────────────────

  test "the mail delivery job does not inherit ApplicationJob" do
    # If this ever becomes false, the separate ApplicationMailDeliveryJob is
    # redundant — and if it silently stayed false while someone moved the
    # policy onto ApplicationJob, mail would lose its retries without a word.
    assert_not ActionMailer::MailDeliveryJob <= ApplicationJob
    assert_includes ActionMailer::MailDeliveryJob.ancestors, ActiveJob::Base
  end

  test "deliver_later is routed through the job that has a mail policy" do
    assert_equal "ApplicationMailDeliveryJob", ActionMailer::Base.delivery_job.to_s
    assert ApplicationMailDeliveryJob <= ActionMailer::MailDeliveryJob
  end

  # ── ApplicationJob: shared policy only ──────────────────────────────────

  test "ApplicationJob discards jobs whose record is gone and declares nothing else" do
    handlers = handlers_for(ApplicationJob)

    assert_includes handlers, "ActiveJob::DeserializationError"
    # Retries are per-job on purpose: a blanket retry here would hand
    # AutoGenerateBlogPostJob a policy that costs Claude API credit.
    assert_not_includes handlers, "ActiveRecord::Deadlocked"
    assert_not_includes handlers, "ActiveRecord::ConnectionNotEstablished"
  end

  # ── per-job policy ──────────────────────────────────────────────────────

  test "the publish job retries transient database errors" do
    handlers = handlers_for(PublishScheduledPostsJob)

    assert_includes handlers, "ActiveRecord::Deadlocked"
    assert_includes handlers, "ActiveRecord::ConnectionNotEstablished"
  end

  test "the generate job takes no retries at all" do
    # Not idempotent in two ways that cost money: it calls the paid Claude API
    # before writing anything, and a failure between Post.create! and
    # topic.update! would on replay pay for a second article and leave a
    # duplicate slugged `-1`.
    own = AutoGenerateBlogPostJob.rescue_handlers - ApplicationJob.rescue_handlers
    assert_empty own.map(&:first),
      "AutoGenerateBlogPostJob must not gain retries without someone deciding to pay for them"

    assert_not_includes handlers_for(AutoGenerateBlogPostJob), "ActiveRecord::Deadlocked"
  end

  # ── mail policy ─────────────────────────────────────────────────────────

  test "mail retries transient SMTP conditions" do
    handlers = handlers_for(ApplicationMailDeliveryJob)

    assert_includes handlers, "Net::SMTPServerBusy"
    assert_includes handlers, "Errno::ECONNREFUSED"
    assert_includes handlers, "Net::OpenTimeout"
  end

  test "mail does not retry a permanent rejection" do
    # 535-5.7.8 — the error this app actually hit on 2026-04-07 — was a bad
    # credential. No number of retries would have delivered it, and retrying
    # only delays the failure being recorded.
    handlers = handlers_for(ApplicationMailDeliveryJob)
    assert_includes handlers, "Net::SMTPAuthenticationError"

    # Declared as rescue_from that re-raises, not retry_on: the job must still
    # end up in Solid Queue's failed executions.
    #
    # Asserted on the identical object. Writing this as
    # `assert_raises(...) { handler_call || raise(SameError) }` would pass even
    # if the handler swallowed the error, because the test itself would supply
    # the exception — a check that cannot fail is not a check.
    error = Net::SMTPAuthenticationError.new("535-5.7.8 Username and Password not accepted")
    raised = nil
    begin
      ApplicationMailDeliveryJob.new.rescue_with_handler(error)
    rescue StandardError => e
      raised = e
    end

    assert_same error, raised, "the handler must re-raise the original error, not swallow it"
  end

  test "a permanent mail rejection is logged before it is re-raised" do
    original = Rails.logger
    buffer = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(buffer)

    begin
      ApplicationMailDeliveryJob.new.rescue_with_handler(
        Net::SMTPAuthenticationError.new("535-5.7.8 Username and Password not accepted")
      )
    rescue Net::SMTPAuthenticationError
      # expected
    ensure
      Rails.logger = original
    end

    assert_match(/permanently rejected, not retrying/, buffer.string)
    assert_match(/535-5\.7\.8/, buffer.string)
  end
end
```

#### `test/integration/stuck_posts_visibility_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"
require "minitest/mock" # Object#stub — not loaded by rails/test_help
require_relative "../support/rake_task_helper"

# The cross-review's finding, turned into assertions: a post that could not be
# published must be discoverable without the thing that failed.
#
# The first version of the fix reported skipped posts by email. That is not a
# channel this app can lean on — production SMTP failed on 2026-04-07 with
# SMTPAuthenticationError 535-5.7.8, Solid Queue does not retry of its own
# accord (ClaimedExecution#perform calls failed_with and re-raises), and nothing
# in the app read its failed-executions table. So the state now lives in the
# posts table and three independent readers surface it. These tests exercise the
# two that a person actually looks at.
class StuckPostsVisibilityTest < ActionDispatch::IntegrationTest
  include RakeTaskHelper

  ADMIN_PASSWORD = ENV.fetch("ADMIN_PASSWORD", "docpack2025")

  def login
    post admin_login_path, params: { password: ADMIN_PASSWORD }
    # Admin::SessionsController#create sends you to the banners page, which is
    # also the admin root — asserted so a silent auth failure cannot make the
    # later "the banner is absent" assertions pass for the wrong reason.
    assert_redirected_to admin_banners_path
  end

  def stuck_post(slug: "integration-stuck", error: "ActiveRecord::RecordInvalid: 본문(한국어)을(를) 입력해 주세요")
    post = Post.create!(title_ko: "막힌 글", slug: slug, category: "pdf",
                        status: "scheduled", published_at: 3.days.ago, body_ko: "<p>x</p>")
    post.update_columns(body_ko: "", publish_error: error)
    post
  end

  setup do
    assert_empty Post.publish_stuck, "no post should be stuck before a test creates one"
  end

  # ── the admin banner ────────────────────────────────────────────────────

  test "the posts page says nothing about stuck posts when there are none" do
    login
    get admin_posts_path

    assert_response :success
    assert_no_match(/발행되지 못한 글/, response.body)
  end

  test "a stuck post is announced on the posts page with its reason and an edit link" do
    target = stuck_post

    login
    get admin_posts_path

    assert_response :success
    assert_match(/발행되지 못한 글 1건/, response.body)
    assert_includes response.body, target.slug
    assert_includes response.body, "본문(한국어)을(를) 입력해 주세요"
    assert_includes response.body, edit_admin_post_path(target)
  end

  test "the banner shows on every filter, not just the stuck one" do
    # It is the one thing on this page nobody went looking for.
    stuck_post

    login
    [ nil, "draft", "scheduled", "published" ].each do |status|
      get admin_posts_path(status: status)
      assert_response :success
      assert_match(/발행되지 못한 글 1건/, response.body, "missing on status=#{status.inspect}")
    end
  end

  test "a stuck post with no recorded reason still appears, and says so" do
    # The job may never have reached it — which is the failure that actually
    # happened here (SOLID_QUEUE_IN_PUMA was false, so nothing ran at all).
    post = Post.create!(title_ko: "이유 없음", slug: "integration-noreason", category: "pdf",
                        status: "scheduled", published_at: 4.days.ago, body_ko: "<p>x</p>")
    post.update_column(:publish_error, nil)

    login
    get admin_posts_path

    assert_includes response.body, "integration-noreason"
    assert_match(/이유 미기록/, response.body)
  end

  test "the stuck filter lists exactly the stuck posts" do
    stuck = stuck_post(slug: "integration-filter-stuck")

    login
    get admin_posts_path(status: "stuck")

    assert_response :success
    assert_includes response.body, stuck.slug
    # A healthy published post must not be in the table.
    assert_not_includes response.body, posts(:korean_only).slug
  end

  test "the existing status filters still work and are not confused by the new one" do
    login

    get admin_posts_path(status: "published")
    assert_response :success
    assert_includes response.body, posts(:korean_only).slug

    get admin_posts_path(status: "draft")
    assert_response :success
    assert_includes response.body, posts(:draft_post).slug
    assert_not_includes response.body, posts(:korean_only).slug
  end

  test "the banner survives mail being completely broken" do
    # The point of the whole change. Run the job with every mail path raising,
    # then look at the page: the post is there because the page reads the
    # database, not a mailbox.
    ready = Post.create!(title_ko: "메일 불가", slug: "integration-mailless", category: "pdf",
                         status: "scheduled", published_at: 2.hours.ago, body_ko: "<p>x</p>")
    ready.update_column(:body_ko, "")

    BlogMailer.stub(:post_published, ->(_p) { raise StandardError, "smtp down" }) do
      BlogMailer.stub(:publish_failed, ->(_f) { raise StandardError, "smtp down" }) do
        PublishScheduledPostsJob.perform_now
      end
    end

    login
    get admin_posts_path

    assert_match(/발행되지 못한 글 1건/, response.body)
    assert_includes response.body, "integration-mailless"
  end

  # ── the command line ───────────────────────────────────────────────────

  test "blog:stuck reports nothing and succeeds when nothing is stuck" do
    out, code = invoke_task("blog:stuck")

    assert_equal 0, code, out
    assert_match(/No stuck posts/, out)
  end

  test "blog:stuck lists the post and exits non-zero" do
    # This reader needs neither a browser, the admin password, nor a mailer.
    stuck_post(slug: "rake-stuck")

    out, code = invoke_task("blog:stuck")

    assert_equal 1, code, "a stuck post must make the task fail so automation notices"
    assert_match(/rake-stuck/, out)
    assert_match(/EMPTY/, out, "the output should name the usual cause")
    assert_match(/본문\(한국어\)/, out)
  end

  test "blog:stuck names a post even when nothing recorded a reason" do
    post = Post.create!(title_ko: "이유 없음", slug: "rake-noreason", category: "pdf",
                        status: "scheduled", published_at: 5.days.ago, body_ko: "<p>x</p>")
    post.update_column(:publish_error, nil)

    out, code = invoke_task("blog:stuck")

    assert_equal 1, code
    assert_match(/rake-noreason/, out)
    assert_match(/not recorded/, out)
  end

  # ── the removed seed ───────────────────────────────────────────────────

  test "blog:seed_safefile_posts no longer exists" do
    # It used to revert blog:migrate_privacy. Removed rather than guarded: a
    # task that does not exist cannot be run by mistake.
    assert_not rake_task_defined?("blog:seed_safefile_posts"), "the removed task must not be defined"

    # And running it from a shell must fail, which is the form a person or a
    # deploy script would actually use.
    `cd #{Rails.root} && RAILS_ENV=test bin/rails blog:seed_safefile_posts 2>&1`
    assert_not_equal 0, $?.exitstatus, "the removed task must not be runnable"

    assert_not File.exist?(Rails.root.join("db/seeds/safefile_posts.rb")),
      "the seed file must be gone, not merely unreferenced"
  end

  test "no rake task or seed references the removed seed file" do
    candidates = Dir[
      Rails.root.join("lib/tasks/*.rake"),
      Rails.root.join("db/seeds/**/*.rb"),
      Rails.root.join("db/seeds.rb")
    ]
    assert_not_empty candidates, "the glob matched nothing — this check would pass vacuously"

    referrers = candidates.select { |f| File.read(f).match?(/load\s+Rails\.root\.join\(["']db\/seeds\/safefile_posts/) }
    assert_empty referrers, "still loading a file that is gone: #{referrers.inspect}"
  end

  test "blog:migrate_privacy is the only task that writes the privacy guide posts" do
    # The seed's defect was two tasks owning three rows, so this pins the count
    # at one and a second owner fails here.
    #
    # Comment lines are stripped before matching: blog.rake explains in a
    # comment why the seed was removed, and counting that as ownership would
    # make this assertion fail for saying the right thing.
    owners = Dir[
      Rails.root.join("lib/tasks/*.rake"),
      Rails.root.join("db/seeds/**/*.rb"),
      Rails.root.join("db/seeds.rb")
    ].select { |f|
      File.readlines(f).reject { |l| l.strip.start_with?("#") }.any? { |l| l.include?("resume-privacy") }
    }.map { |f| Pathname.new(f).relative_path_from(Rails.root).to_s }

    assert_equal [ "lib/tasks/blog_migrate_privacy.rake" ], owners
  end
end
```

#### `test/integration/privacy_guide_ownership_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"
require_relative "../support/rake_task_helper"

# blog:migrate_privacy is now the single owner of the three SafeFile privacy
# guide posts, and these tests are about the two properties that made the old
# arrangement lose data.
#
# Before 2026-09-18 the posts had two owners: db/seeds/safefile_posts.rb created
# them (with pre-rename slugs and no body) and this task fixed them up. Whichever
# ran last won. Measured on the development database: running the seed after the
# migration flipped resume-privacy's category from `privacy` back to `student`
# and replaced its title and meta_description with its own hardcoded values —
# including anything a person had edited in the admin.
#
# So: the owner must be able to CREATE (or deleting the seed would have lost the
# fresh-database path) and must not CLOBBER (or it would have inherited the
# defect it replaced).
class PrivacyGuideOwnershipTest < ActionDispatch::IntegrationTest
  include RakeTaskHelper

  SLUGS = %w[resume-privacy resident-number-masking contract-sharing-checklist].freeze

  setup do
    # The fixtures carry no privacy guides, so the create path is the default
    # state here. Asserted rather than assumed — if a fixture ever adds one, the
    # "creates from nothing" test would silently become an update test.
    assert_empty Post.where(slug: SLUGS), "expected no privacy guides before the task runs"
  end

  test "the task creates all three guides on an empty database" do
    out, code = invoke_task("blog:migrate_privacy")

    assert_equal 0, code, out
    assert_equal SLUGS.sort, Post.where(slug: SLUGS).pluck(:slug).sort

    Post.where(slug: SLUGS).each do |post|
      assert_equal "privacy", post.category, post.slug
      assert_equal "published", post.status, post.slug
      assert post.body_ko.present?, "#{post.slug} must have a body — published posts are validated on it"
      assert post.title_ko.present?, post.slug
      assert post.title_en.present?, post.slug
      assert post.meta_description_ko.present?, post.slug
      assert post.published_at.present?, post.slug
    end
  end

  test "the bodies come from db/blog_privacy and match the files" do
    invoke_task("blog:migrate_privacy")

    {
      "resume-privacy" => "resume-privacy.html",
      "resident-number-masking" => "resident-number-masking.html",
      "contract-sharing-checklist" => "contract-sharing-checklist.html"
    }.each do |slug, file|
      expected = Rails.root.join("db/blog_privacy", file).read.strip
      assert_equal expected, Post.find_by(slug: slug).body_ko
    end
  end

  test "running it twice changes nothing the second time" do
    invoke_task("blog:migrate_privacy")
    before = Post.where(slug: SLUGS).order(:slug).pluck(:slug, :category, :title_ko, :body_ko, :updated_at)

    out, code = invoke_task("blog:migrate_privacy")

    assert_equal 0, code, out
    assert_match(/already current/, out)
    assert_equal before, Post.where(slug: SLUGS).order(:slug).pluck(:slug, :category, :title_ko, :body_ko, :updated_at)
  end

  test "it does not overwrite a title, description or body a person edited" do
    # This is the seed's exact defect, asserted against its replacement.
    invoke_task("blog:migrate_privacy")
    post = Post.find_by(slug: "resume-privacy")
    post.update_columns(
      title_ko: "사람이 고친 제목",
      title_en: "Edited by a human",
      meta_description_ko: "사람이 고친 설명",
      body_ko: "<p>사람이 고친 본문 EDITED_MARKER</p>"
    )

    invoke_task("blog:migrate_privacy")
    post.reload

    assert_equal "사람이 고친 제목", post.title_ko
    assert_equal "Edited by a human", post.title_en
    assert_equal "사람이 고친 설명", post.meta_description_ko
    assert_includes post.body_ko, "EDITED_MARKER"
  end

  test "it does reclaim the category, which is the one field it owns" do
    # The category is what the two tasks disagreed about, so the owner asserts
    # it. Everything a person writes is left alone; this is not.
    invoke_task("blog:migrate_privacy")
    post = Post.find_by(slug: "resume-privacy")
    post.update_column(:category, "student")

    invoke_task("blog:migrate_privacy")

    assert_equal "privacy", post.reload.category
  end

  test "it fills a body that is blank, because that was the original job" do
    invoke_task("blog:migrate_privacy")
    post = Post.find_by(slug: "resident-number-masking")
    post.update_column(:body_ko, "")

    invoke_task("blog:migrate_privacy")

    assert_equal Rails.root.join("db/blog_privacy/resident-number-masking.html").read.strip,
      post.reload.body_ko
  end

  test "it converges from the pre-rename slugs" do
    # A half-migrated database: the record still carries the old slug.
    Post.create!(title_ko: "주민등록번호 마스킹", slug: "rrn-masking", category: "office",
                 status: "published", published_at: 1.year.ago,
                 body_ko: "<p>구버전 본문</p>")

    invoke_task("blog:migrate_privacy")

    assert_nil Post.find_by(slug: "rrn-masking"), "the old slug must be renamed, not duplicated"
    renamed = Post.find_by(slug: "resident-number-masking")
    assert_equal "privacy", renamed.category
    # Its body was already present, so it is left alone rather than replaced.
    assert_includes renamed.body_ko, "구버전 본문"
    assert_equal 1, Post.where(slug: SLUGS).where(title_ko: "주민등록번호 마스킹").count
  end

  test "the guides it creates are indexable, so the sitemap will carry them" do
    # A published post with no Korean body would be a real URL that cannot be
    # indexed — the invariant added on 2026-09-18. Creating one would violate it.
    invoke_task("blog:migrate_privacy")

    Post.where(slug: SLUGS).each do |post|
      assert post.valid?, "#{post.slug}: #{post.errors.full_messages.join(', ')}"
      assert_includes post.indexable_locales, :ko, post.slug
      assert_not post.publish_stuck?, post.slug
    end
  end
end
```

#### `test/fixtures/posts.yml`

```yaml
# Two shapes matter for indexing, and they are the two fixtures here:
#
#   korean_only  — the shape every one of the 42 live posts actually has
#                  (body_ko filled, body_en blank). Its /en, /ja and /es URLs
#                  serve the Korean article under a translated shell, so they
#                  carry noindex and canonicalise back to the Korean URL.
#   bilingual    — body_en filled as well. Exists on no live post yet, but it is
#                  the shape the translation gate is written for, so the tests
#                  need it to prove the gate opens and not just that it is shut.

korean_only:
  title_ko: "한국어 전용 글"
  body_ko: "<p>한국어 본문입니다.</p>"
  body_en: ""
  slug: "korean-only-post"
  category: "pdf"
  status: "published"
  published_at: <%= 3.days.ago.to_fs(:db) %>
  meta_description_ko: "한국어 전용 글의 설명"

bilingual:
  title_ko: "번역된 글"
  title_en: "Translated post"
  body_ko: "<p>한국어 본문입니다.</p>"
  body_en: "<p>English body.</p>"
  slug: "bilingual-post"
  category: "global"
  status: "published"
  published_at: <%= 2.days.ago.to_fs(:db) %>
  meta_description_ko: "번역된 글의 설명"
  meta_description_en: "Description of the translated post"

# PostsController#show serves draft and scheduled posts too, so the preview link
# works before publication. That 200 is deliberate; being indexable was not.
# Both have a Korean body, which is precisely the case the old gate waved
# through — translated?(:ko) was true, so no noindex was emitted.

draft_post:
  title_ko: "초안 글"
  body_ko: "<p>아직 발행하지 않은 초안입니다.</p>"
  body_en: ""
  slug: "draft-post"
  category: "office"
  status: "draft"
  meta_description_ko: "초안 글의 설명"

scheduled_post:
  title_ko: "예약된 글"
  body_ko: "<p>발행 예약된 글입니다.</p>"
  body_en: ""
  slug: "scheduled-post"
  category: "student"
  status: "scheduled"
  published_at: <%= 3.days.from_now.to_fs(:db) %>
  meta_description_ko: "예약된 글의 설명"

# A published post translated into English, used to prove the locale split holds
# once body_en is actually filled in: the unprefixed URL must stay Korean no
# matter what the reader's browser asks for, and only /en may serve English.
bilingual_published:
  title_ko: "이중언어 발행 글"
  title_en: "Bilingual published post"
  body_ko: "<p>한국어 본문 고유문자열 KOBODY.</p>"
  body_en: "<p>English body unique marker ENBODY.</p>"
  slug: "bilingual-published-post"
  category: "global"
  status: "published"
  published_at: <%= 1.day.ago.to_fs(:db) %>
  meta_description_ko: "한국어 설명 KODESC"
  meta_description_en: "English description ENDESC"
```

#### `config/application.rb` (delivery_job 연결)

```ruby
require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Docpack
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # i18n — 4 locales, Korean is default (no URL prefix)
    config.i18n.available_locales = %i[ko en ja es]
    config.i18n.default_locale = :ko
    config.i18n.fallbacks = [:ko]

    # Route deliver_later through a job that has a retry policy.
    #
    # The default is ActionMailer::MailDeliveryJob, which inherits from
    # ActiveJob::Base rather than ApplicationJob — so nothing declared on
    # ApplicationJob reaches mail delivery. Without this line, adding retries
    # "to the app's jobs" leaves outgoing mail exactly as fragile as before
    # while appearing to have covered it. See app/jobs/application_mail_delivery_job.rb.
    #
    # A string so it resolves after autoloading rather than at boot.
    config.action_mailer.delivery_job = "ApplicationMailDeliveryJob"

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
```

#### `config/environments/production.rb` — 큐·호스트 관련 줄

```ruby
53:  config.active_job.queue_adapter = :solid_queue
54:  config.solid_queue.connects_to = { database: { writing: :queue } }
58:  # config.action_mailer.raise_delivery_errors = false
61:  config.action_mailer.default_url_options = { host: "slimfile.net" }
63:  config.action_mailer.delivery_method = :smtp
64:  config.action_mailer.raise_delivery_errors = true
65:  config.action_mailer.smtp_settings = {
85:  # config.hosts = [
```

#### `app/models/post.rb` 의 검증·스코프만 발췌 (전문은 위에 있음)

```ruby
class Post < ApplicationRecord
  has_one_attached :hero_image

  validates :title_ko, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :category, inclusion: { in: %w[privacy pdf image office student freelancer global] }
  validates :status, inclusion: { in: %w[draft scheduled published] }

  # The invariant: **a published post always has a Korean body.**
  #
  # Korean is the default locale, so /blog/:slug — the address every other
  # locale canonicalises to, the one x-default points at, and the only one the
  # language switcher can always reach — is the Korean page. A published post
  # with body_en but no body_ko makes that address real but not indexable:
  # indexable_locales comes back [:en], yet x-default still aims at the Korean
  # URL, which is noindex. Reproduced before writing this validation.
  #
  # Nothing builds that shape today (BlogGeneratorService writes Korean first,
  # and all 42 live posts have body_ko), so this closes a gap rather than fixing
  # a live defect. Drafts stay exempt: a post is created empty and filled in.
  validates :body_ko, presence: true, if: -> { status == "published" }

  scope :published, -> { where(status: "published") }
  scope :scheduled_ready, -> { where(status: "scheduled").where("published_at <= ?", Time.current) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }

  # ── Stuck posts ─────────────────────────────────────────────────────────
  #
  # A post whose time to be published has come and gone. This is the state that
```

#### `test/models/post_test.rb` — publish_stuck 절만

```ruby
  # ── publish_stuck ───────────────────────────────────────────────────────
  #
  # This scope is the primary channel for a post that could not be published.
  # It has to be derived from the posts table alone: the email that used to
  # carry the news needs SMTP, which failed in production on 2026-04-07, and
  # Solid Queue does not retry on its own. So these tests are about the scope
  # answering correctly without anything else being alive.

  def scheduled_at(when_, slug:, error: nil)
    post = Post.create!(title_ko: "예약 #{slug}", slug: slug, category: "pdf",
                        status: "scheduled", published_at: when_, body_ko: "<p>x</p>")
    post.update_column(:publish_error, error) if error
    post
  end

  test "a post still waiting for its next run is not stuck" do
    # The job fires once a day, so being a few hours past due is normal.
    post = scheduled_at(2.hours.ago, slug: "stuck-waiting")

    assert_not post.publish_stuck?
    assert_not_includes Post.publish_stuck.map(&:slug), "stuck-waiting"
  end

  test "a post past due by more than the grace window is stuck even with no reason recorded" do
    # This is the case a job-written flag could never catch: the job never ran.
    post = scheduled_at(3.days.ago, slug: "stuck-no-reason")

    assert post.publish_stuck?
    assert_includes Post.publish_stuck.map(&:slug), "stuck-no-reason"
    assert_nil post.publish_error
  end

  test "a recorded failure counts immediately, without waiting out the grace window" do
    # A reason on the record is evidence, not suspicion. Sitting on it for a day
    # would be sitting on a known answer.
    post = scheduled_at(10.minutes.ago, slug: "stuck-with-reason",
                        error: "2026-09-18T00:00:00Z ActiveRecord::RecordInvalid: 본문 없음")

    assert post.publish_stuck?
    assert_includes Post.publish_stuck.map(&:slug), "stuck-with-reason"
  end

  test "a recorded failure on a post that is not due yet is still not stuck" do
    # Guards the boundary from the other side: the OR branch must stay anchored
    # to published_at, or a future post with a stale error would be reported.
    post = scheduled_at(2.days.from_now, slug: "stuck-future-reason", error: "old error")

    assert_not post.publish_stuck?
    assert_not_includes Post.publish_stuck.map(&:slug), "stuck-future-reason"
  end

  test "the grace boundary is exactly PUBLISH_GRACE" do
    inside = scheduled_at(Post::PUBLISH_GRACE.ago + 5.minutes, slug: "stuck-inside")
    outside = scheduled_at(Post::PUBLISH_GRACE.ago - 5.minutes, slug: "stuck-outside")

    assert_not inside.publish_stuck?, "5 minutes inside the window must not report"
    assert outside.publish_stuck?, "5 minutes past the window must report"

    slugs = Post.publish_stuck.map(&:slug)
    assert_not_includes slugs, "stuck-inside"
    assert_includes slugs, "stuck-outside"
  end

  test "published and draft posts are never stuck" do
    # Only `scheduled` can be stuck. A draft has no publish time to miss.
    assert_not posts(:korean_only).publish_stuck?
    assert_not posts(:draft_post).publish_stuck?

    Post.where(slug: "draft-post").update_all(published_at: 5.days.ago)
    assert_not_includes Post.publish_stuck.map(&:slug), "draft-post"
  end

  test "a scheduled post with no publish time is not stuck" do
    # nil published_at cannot be past due; the SQL must not treat it as zero.
    post = Post.create!(title_ko: "시각 없음", slug: "stuck-nil-date", category: "pdf",
                        status: "scheduled", body_ko: "<p>x</p>")

    assert_not post.publish_stuck?
    assert_not_includes Post.publish_stuck.map(&:slug), "stuck-nil-date"
  end

  test "the scope and the predicate agree on every case above" do
    # Two implementations of one rule drift. This pins them together.
    [ 2.hours.ago, 3.days.ago, 2.days.from_now, Post::PUBLISH_GRACE.ago - 1.minute ].each_with_index do |t, i|
      [ nil, "some error" ].each_with_index do |err, j|
        post = scheduled_at(t, slug: "stuck-agree-#{i}-#{j}", error: err)
        in_scope = Post.publish_stuck.exists?(id: post.id)
        assert_equal in_scope, post.publish_stuck?,
          "scope and predicate disagree for published_at=#{t}, error=#{err.inspect}"
      end
    end
  end

  test "publish_overdue_by measures from the scheduled time and is nil off the scheduled path" do
    post = scheduled_at(3.hours.ago, slug: "stuck-overdue")

    assert_in_delta 3.hours, post.publish_overdue_by, 60
    assert_nil posts(:korean_only).publish_overdue_by
    assert_nil posts(:draft_post).publish_overdue_by
  end
end
```

#### `app/views/blog_mailer/publish_failed.html.erb` (보조 채널)

```erb
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 0; background-color: #F8F7F4; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
    .container { max-width: 560px; margin: 32px auto; background: #ffffff; border: 1px solid #E5E3DC; border-radius: 20px; overflow: hidden; }
    .header { background: #A32D2D; padding: 28px 32px; }
    .header h1 { margin: 0; color: #ffffff; font-size: 18px; font-weight: 600; letter-spacing: -0.02em; }
    .body { padding: 28px 32px; }
    .notice { background: #FCEBEB; border-radius: 14px; padding: 14px 18px; font-size: 13px; color: #A32D2D; line-height: 1.6; margin-bottom: 20px; }
    .item { border: 1px solid #E5E3DC; border-left: 4px solid #A32D2D; border-radius: 14px; padding: 14px 18px; margin-bottom: 12px; }
    .item-slug { font-size: 15px; font-weight: 600; color: #1A1918; letter-spacing: -0.01em; margin: 0 0 6px; }
    .item-errors { font-size: 13px; color: #6B6963; line-height: 1.55; margin: 0 0 10px; }
    .btn { display: inline-block; background: #0A6E8A; color: #ffffff; text-decoration: none; padding: 8px 18px; border-radius: 12px; font-size: 13px; font-weight: 600; }
    .stats { background: #F8F7F4; border-radius: 14px; padding: 14px 18px; margin-top: 20px; font-size: 13px; color: #6B6963; line-height: 1.6; }
    .footer { padding: 20px 32px; text-align: center; font-size: 12px; color: #6B6963; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>SlimFile 블로그 발행 실패</h1>
    </div>

    <div class="body">
      <div class="notice">
        예약된 글 <strong><%= @failures.size %>건</strong>이 검증에 걸려 발행되지 않았습니다.
        해당 글은 <strong>예약(scheduled) 상태로 그대로 남아</strong> 있고, 나머지 글은 정상 발행됐습니다.
        고치지 않으면 이 메일이 매일 다시 옵니다.
      </div>

      <% @failures.each do |failure| %>
        <div class="item">
          <p class="item-slug"><%= failure["slug"].presence || "(슬러그 없음)" %></p>
          <p class="item-errors"><%= failure["errors"].presence || "(검증 메시지 없음)" %></p>
          <% if failure["id"].present? %>
            <a href="https://slimfile.net/admin/posts/<%= failure["id"] %>/edit" class="btn">편집 →</a>
          <% end %>
        </div>
      <% end %>

      <div class="stats">
        가장 흔한 원인은 <strong>한국어 본문(body_ko)이 빈 것</strong>입니다 —
        발행된 글은 반드시 한국어 본문을 가져야 합니다
        (<code>/blog/:slug</code> 가 다른 모든 로케일의 canonical 이자 x-default 대상이기 때문).<br>
        본문을 채우고 저장하면 다음 실행에서 발행됩니다.
      </div>
    </div>

    <div class="footer">
      SlimFile &mdash; slimfile.net · PublishScheduledPostsJob
    </div>
  </div>
</body>
</html>
```

#### `db/schema.rb` — posts 테이블

```ruby
  create_table "posts", force: :cascade do |t|
    t.string "title_ko"
    t.string "title_en"
    t.text "body_ko"
    t.text "body_en"
    t.string "slug"
    t.string "category"
    t.string "status"
    t.datetime "published_at"
    t.text "cover_svg"
    t.string "meta_description_ko"
    t.string "meta_description_en"
    t.integer "view_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "trust_bar"
    t.string "pain_tag"
    t.text "error_mockup"
    t.text "recognition_text"
    t.text "loss_items"
    t.text "stats"
    t.string "subtitle_ko"
    t.text "publish_error"
    t.index ["slug"], name: "index_posts_on_slug", unique: true
  end
```

---

## ⑥ 정본 대조표 (DECISIONS.md, 이번에 신설된 행)

| 규칙 | 구현 위치 |
|---|---|
| 막힌 글의 권위 있는 신호는 **파생 스코프** (잡이 쓰는 플래그 아님) | `Post.publish_stuck` |
| **두 가지 인내심** — 이유 기록됨=즉시, 없음=26시간 유예 | `Post::PUBLISH_GRACE`, 스코프 SQL |
| **DB 만 의존하는 3곳**에서 보이게 한다. 메일은 보조 | 어드민 배너·`Stuck` 필터·`rake blog:stuck` |
| `/up` 에 애플리케이션 데이터를 걸지 않는다 | (변경 없음 — 의도적 부작위) |
| 재시도 정책은 **잡마다** 선언 | `PublishScheduledPostsJob` 에 `retry_on`, `AutoGenerateBlogPostJob` 에 없음 |
| 메일에는 **별도 잡**으로 정책 | `ApplicationMailDeliveryJob` + `config.action_mailer.delivery_job` |
| 실패한 잡은 `rake jobs:failed` 로 본다 (**테이블 존재**로 가드) | `lib/tasks/jobs.rake` |
| 시드는 **가드가 아니라 제거** | `db/seeds/safefile_posts.rb` 삭제, `blog:seed_safefile_posts` 삭제 |
| `blog:migrate_privacy` 가 **단일 소유자** (create-or-update, 소유 범위 명시) | `lib/tasks/blog_migrate_privacy.rake` |

## ⑦ 확신이 없는 지점 (이미 아는 것 — 여기에 의견을 달라)

1. **`publish_stuck` 스코프의 SQL 우선순위.** `A AND B OR C` 를 괄호 없이 썼다. SQL 에서
   `AND` 가 `OR` 보다 강하므로 `(A AND B) OR C` 로 파싱된다고 판단했고 테스트가 8개 조합을
   통과하지만, **괄호를 안 쓴 것 자체가 다음 사람을 헷갈리게 할 수 있다.** 의견을 달라.
2. **26시간이 맞는 숫자인지.** 잡이 하루 한 번이라는 전제에서 나왔다. `recurring.yml` 을
   바꾸면 이 상수가 조용히 틀린 값이 된다 — 둘을 묶을 방법이 있는지.
3. **`publish_stuck` 이 놓치는 경우.** 사람이 어드민에서 발행된 글을 `scheduled` 로 되돌리고
   `published_at` 을 과거로 두면 "막힌 글" 로 보고된다. 오탐인지 정탐인지 판단이 안 선다.
4. **메일 재시도 예외 목록의 완결성.** `Net::SMTP*` 와 `Errno::*` 를 나열했는데 전수라고
   확신할 수 없다. `retry_on`/`rescue_from` 혼용의 우선순위도 자신이 없다.
5. **`rake jobs:failed` 가 프로덕션 큐 DB 를 제대로 읽는지 실측하지 못했다.**
   `connects_to = { database: { writing: :queue } }` 로 별도 DB 인데, dev 에는 그 DB 가
   없어 가드로 빠져나간다. **프로덕션에서만 확인 가능한 유일한 항목이다.**
6. **`body_ko` 를 "비어 있을 때만 채운다" 로 바꾼 것**이 동작 변경이다. 마이그레이션이
   파일을 진실로 삼던 것을 DB 우선으로 뒤집었다 — 의도는 설명했지만 판단을 달라.
7. **정기 실행 자동화를 넣지 않았다.** `rake blog:stuck`·`jobs:failed` 는 사람이 돌려야
   보인다. `recurring.yml` 에 넣으면 또 다른 알림 채널을 만드는 셈이라 뺐다.

## 비밀값 스캔 결과

(패키지 생성 직후 실행 — 아래 절 참조)

## 비밀값 스캔 (실행 결과)

패키지 생성 직후 실행. 정규식: `ghp_`/`gho_`/`github_pat_` 토큰 · `sk-ant-` 키 ·
`ANTHROPIC_API_KEY=`/`GMAIL_PASSWORD=`/`SECRET_KEY_BASE=`/`DB_PASSWORD=` 의 **값** 형태 ·
PEM 헤더 · `AKIA`.

- **일치 0건.**
- 등장하는 이메일 2개는 이미 저장소에 평문으로 있다: `chaop2@gmail.com`
  (`BlogMailer` 수신자 상수), `noreply@slimfile.net` (`ApplicationMailer` 기본 발신자 폴백).
- ⚠️ **솔직히 밝힌다**: 테스트 파일에 `ENV.fetch("ADMIN_PASSWORD", "docpack2025")` 가 있어
  패키지에 그 문자열이 들어간다. **프로덕션 자격증명이 아니다** — 개발 폴백이고, 이미
  `CLAUDE.md:93` 과 `app/controllers/admin/sessions_controller.rb:26` 에 평문으로 있다.
  프로덕션은 `.kamal/secrets:17` 이 `.env.production.local` 에서 읽어 덮어쓰며
  (`config/deploy.yml:27` 의 `env.secret` 목록에 있음), 그 파일은 커밋되지 않는다.
- `.env`·`.env.production.local`·`.kamal/secrets` 는 패키지에 **넣지 않았다.**
