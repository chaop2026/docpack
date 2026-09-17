# Codex 교차검증 패키지 — 교차검증 (a) 3건 수정 · 2026-09-18

> 대상 커밋 `a2a1934` (브랜치 `fix/blog-indexing-signals`, **미배포**)
> 비밀값 스캔 결과는 문서 말미.

## ① 리뷰어용 프롬프트

당신은 이 저장소를 처음 보는 **독립 코드 리뷰어**다. 아래 패키지만 근거로 판단하라.

**맥락**: Rails 8.0.4 앱 `slimfile.net`. 직전 커밋(`2ee3e72`)에 대한 교차검증이 (a)등급 3건을
남겼고, 이 커밋(`a2a1934`)이 그 3건을 고친다. **아직 배포되지 않았다. 프로덕션 DB 는 건드리지
않았다** — 모든 판정은 로컬 라이브 HTTP 실측 + 코드 인용 + 프로덕션 환경 미들웨어 스택 덤프.

고친 3건:
1. **AMBER** `PublishScheduledPostsJob` 의 `find_each` 안 rescue 없는 `update!` 가
   직전 커밋의 `validates :body_ko, if: published` 에 걸리면 **배치 나머지 전부**가 발행되지
   않는다. → 글 단위 격리 + 실패 가시화.
2. **GREEN** 반복 슬래시가 `CanonicalPathRedirect` 를 빠져나가 중복 URL 가족을 만든다.
   → 정규화→매핑 순서로 재작성. (재현 중 **지적보다 넓은 두 가족**을 더 찾았다)
3. **GREEN** 미들웨어 삽입이 `public_file_server.enabled` 에 묶여 있어, 정적 서빙을 프록시로
   옮기면 라우팅 페이지 정규화까지 조용히 사라진다. → 무조건 삽입, 가드는 위치만 선택.

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
   보임 ③ 컨트롤러발 `page_meta` 가 조용히 무시돼 `/blog` 가 기본 `<title>` 로 나감
   ④ **이니셜라이저가 dev 에서 리로드되지 않아 "수정 후" 측정이 실은 수정 전 값**
   ⑤ **이번 건: 가드 때문에 미들웨어가 스택에서 0개인데 아무 에러도 없다**
2. **암묵적 상류 의존** — 안전의 근거가 우리 코드 밖에 있다.
3. **공허한 검사** — 아무것도 검증하지 않는 테스트/단언.
4. **협상 의존** — 같은 URL 이 요청자에 따라 다르게 답한다.
5. **하나를 고치며 다른 하나를 깨뜨림** — 직전 커밋의 검증이 바로 이 3건 중 1번을 만들었다.

**특히 답을 원하는 질문**:
- Q1. 잡의 `RECORD_REJECTED = [RecordInvalid, RecordNotSaved]` 가 **정확한 집합인가?**
  `update!` 가 던질 수 있는 "이 레코드는 저장 불가" 예외를 빠뜨렸는가? 반대로 이 둘 중
  하나라도 **인프라 장애**로 발생할 수 있어 잘못 격리되는 경우가 있는가?
  (`RecordNotUnique`, `StaleObjectError`, `ActiveRecord::Rollback`, `throw :abort` 콜백 등)
- Q2. **실패 가시화 설계가 실제로 성립하는가?** 건너뛴 글이 영구히 `scheduled` 로 남는 것이
  이 수정의 새 실패 모드다. 런당 메일 1통 + 매일 반복이 그것을 잡는가?
  메일이 **절대 도달하지 못하는 경로**가 남아 있는가? (`deliver_later` 가 큐에 넣기만 함,
  `publish_failed` 뷰 렌더 실패, SMTP 인증 실패 — 이때 어디에도 안 남는가?)
- Q3. `describe_failure` 가 문자열·정수만 담는 것으로 **ActiveJob 직렬화가 정말 안전한가?**
  `post.errors.full_messages` 가 비어 있을 수 있는 경로가 있는가?
- Q4. `canonical_spelling` 의 **정규화→매핑 순서**가 모든 입력에 대해 1홉·무루프를 보장하는가?
  반례를 찾아라. 특히: `SCRIPT_NAME` 이 있는 마운트, `PATH_INFO` 가 `""`, percent-encoded
  `%2F`, `/safe` 로 시작하지만 디렉터리가 아닌 경로(`/safety`, `/safe-x`),
  `DIRS` 에 새 항목이 추가되는 경우.
- Q5. **정적 디렉터리 밑 에셋의 트레일링 슬래시를 301 하기로 한 것**(`/safe/sw.js/` →
  `/safe/sw.js`)이 옳은가? 서비스워커·매니페스트·PWA scope 에 부작용이 없는가?
  (`public/safe/sw.js` 의 `precache()` 는 `r.redirected` 를 실패로 올려 **install 을
  실패시킨다** — 프리캐시 목록 URL 중 하나라도 301 이 되면 SW 업데이트가 멈춘다)
- Q6. 이니셜라이저의 `unshift` 분기가 옳은가? `CanonicalPathRedirect` 가
  `ActionDispatch::SSL`·`AssumeSSL`·`Rack::Sendfile` **앞**에 오는 것이 안전한가?
  (`ActionDispatch::Executor` 없이 도는 것이 문제가 되는가?)
- Q7. `config/locales/ko.yml` 에 넣은 검증 메시지 블록이 **기존 키를 가리거나**
  다른 로케일/기능을 깨뜨리지 않는가? `errors.format` 에서 공백을 뺀 것의 부작용은?
  `activerecord.errors.messages` 와 top-level `errors.messages` 를 둘 다 둔 것이 옳은가?
- Q8. **레이크 태스크의 `abort` 판단**이 옳은가? 항목 단위 격리 + 끝에서 exit≠0 이
  `kamal app exec` 자동화에서 의도대로 동작하는가? `blog:generate`·`regenerate_scheduled` 는
  exit 0 로 남긴 것이 일관성 위반인가?
- Q9. `test/jobs/publish_scheduled_posts_job_test.rb` 와 확장된 두 테스트 파일에
  **공허한 단언**이 있는가? 특히: 로그 formatter 주입이 severity 단언을 실제로 의미 있게
  만드는가, `with_connection_dropped` 의 스텁이 실제 경로를 타는가,
  통합 테스트의 `//` 경로가 미들웨어에 raw 로 도달하는가.
- Q10. **고치지 않기로 한 것**의 판단이 옳은가?
  (`db/seeds/safefile_posts.rb` 의 존재 이유 정리 보류 · `auto_generate_blog_post_job` 의
  `topic.update!` 미격리 · Banner/BlogTopic/Conversion 속성명 ko 번역 없음 ·
  `blog:generate` 계열의 exit 0)

**출력 형식**: 지적별로
```
[분류] [확신도] 제목
근거: <파일:줄>
설명: <어떤 입력에서 무엇이 잘못되는가>
```
마지막에 Q1~Q10 답변. 그리고 3건 각각에 대해 `해소됨 / 부분 해소 / 미해소` 판정.

---

## ② 수정 전 재현 실측 (전부 로컬 `localhost:3001`, 코드 인용 병기)

### A-1 — 잡의 수정 전 코드 (전문)

```ruby
class PublishScheduledPostsJob < ApplicationJob
  queue_as :default

  def perform
    Post.scheduled_ready.find_each do |post|
      post.update!(status: "published")          # ← rescue 없음
      BlogMailer.post_published(post).deliver_later
      Rails.logger.info("Published scheduled post: #{post.slug}")
    end
  end
end
```

직전 커밋이 `app/models/post.rb` 에 넣은 검증:
`validates :body_ko, presence: true, if: -> { status == "published" }`

### A-1 부수 — 검증 메시지가 "Translation missing" 이었다 (실측)

```
I18n.default_locale = :ko
RecordInvalid#message → "Translation missing: ko.activerecord.errors.messages.record_invalid"
errors.full_messages  → ["Body ko Translation missing. Options considered were:
                          - ko.activerecord.errors.models.post.attributes.body_ko.blank
                          - ko.activerecord.errors.models.post.blank
                          - ko.activerecord.errors.messages.blank
                          - ko.errors.attributes.body_ko.blank
                          - ko.errors.messages.blank"]
(locale :en → "Body ko can't be blank"  — Rails 기본은 정상)
```

수정 후:
```
RecordInvalid#message → "저장할 수 없습니다: 본문(한국어)을(를) 입력해 주세요"
errors.full_messages  → ["본문(한국어)을(를) 입력해 주세요"]
```

이 문자열을 사람이 읽는 곳: `app/views/admin/posts/_form.html.erb:4` 와
`app/views/admin/banners/_form.html.erb:7` (둘 다 `errors.full_messages` 를 출력),
그리고 이번에 추가한 발행 실패 메일의 "이유" 칸.

### A-1 전수 스캔 — "rescue 없는 bang 메서드가 순회 안에" 5건

| # | 위치 | 조치 |
|---|---|---|
| 1 | `app/jobs/publish_scheduled_posts_job.rb:6` | 잡 재작성 (전문 아래) |
| 2 | `lib/tasks/blog.rake:34` `Post.create!` in `count.times` | 글 단위 rescue, exit 0 유지 |
| 3 | `lib/tasks/blog.rake:176` `post.update!` in `each_with_index` | 동일 |
| 4 | `lib/tasks/blog_migrate_privacy.rake:43` `post.save!` in `each` | 항목 rescue + 끝에 `abort` |
| 5 | `db/seeds/safefile_posts.rb:40` `post.save!` in `each` | 항목 rescue + 끝에 `abort` |

**5번은 이번 스캔이 새로 찾았고, 직전 커밋으로 실제로 깨져 있었다** (실측):

```
$ bin/rails blog:seed_safefile_posts     # 수정 전
Seeded post: resume-privacy (published)
bin/rails aborted!
ActiveRecord::RecordInvalid: ... (두 번째 항목에서 중단, 세 번째는 시도 못 함)
```

원인 두 겹: ① 시드의 전제("본문은 `public/blog/<slug>/index.html` 이 담당")가
`9f8bfff`(2026-07-17)의 `public/blog/` 삭제로 무효가 됐고, `blog:migrate_privacy` 가
슬러그를 개명했는데(`rrn-masking`→`resident-number-masking`,
`contract-checklist`→`contract-sharing-checklist`) 시드는 개명 전 값을 쓴다 → 마이그레이션
후 DB 에서는 **본문 없는 중복 글을 새로 만들려 한다** ② 검증이 그 생성을 거부한다.

즉 **검증이 이 시드의 오래된 버그를 잡아준 것**이다 — 검증 전에는 본문 없는 published
중복 2개를 조용히 만들어 `/blog` 목록·사이트맵을 오염시켰다.
수정 후 재실행: 항목 3개 모두 시도 → 2건 거부 로그 → `abort` (exit 1), **DB 중복 0건**.

**격리하지 않은 것** (순회 안이 아니므로 예외가 올바른 결과):
`auto_generate_blog_post_job`(런당 글 1개), `app/controllers/**`(요청 스코프, 예외=500=즉시 보임;
`banners#swap_order` 는 트랜잭션 안 2개 업데이트라 둘 다 성공해야 함), `Post#publish!`.
부수 확인: `posts_controller.rb:11` 의 `increment!(:view_count)` 는 **검증을 우회**한다
(`update_counters` = 직접 SQL). 실측 — 본문 없는 글의 공개 페이지가 500 이 되지 않는다.

### A-2 — 반복 슬래시 재현 (수정 전, md5·바이트 동기)

교차검증이 지적한 것:
```
 200  /safe/            bytes=129584  md5=d52dec97
 200  /safe//           bytes=129584  md5=d52dec97   ← 동일
 200  /safe///          bytes=129584  md5=d52dec97   ← 동일
 200  /safe//index.html bytes=129584  md5=d52dec97   ← /safe/index.html 의 301 규칙 우회
 200  /safe//sw.js      bytes=8979    md5=81d8b697
 200  /privacy//        bytes=7006    md5=242f514a
```

**재현하면서 더 찾은 두 가족** (지적에 없던 것):
```
 200  /safe/sw.js/      bytes=8979    md5=81d8b697   ← 정적 디렉터리 밑 에셋의 트레일링 슬래시
                                                       "밑은 절대 손대지 않는다" 분기가 통과시켰다
 200  //about           bytes=10255                  ← 경로 중간 반복 슬래시 (라우팅 페이지)
 200  /en//about        bytes=10132                  ← CSRF 정규화 후 /en/about 과 바이트 동일 (diff 확인)
 200  /en///about       bytes=10132
 200  //en/about        bytes=10132
 200  //faq //blog //sitemap.xml //robots.txt
 200  /blog//contract-sharing-checklist
 200  /en//blog//contract-sharing-checklist
```

**트레일링 슬래시를 얼마나 벗겨도 경로 중간은 못 잡는다** — 지적된 "squeeze 를 디렉터리 분기
앞으로" 가 아니라 **순서 자체**를 바꿨다.

### A-3 — 미들웨어 스택 실측 (프로덕션 환경으로 덤프)

| 구성 | 수정 전 `CanonicalPathRedirect` | 수정 후 |
|---|---|---|
| `RAILS_ENV=production RAILS_SERVE_STATIC_FILES=true` | 1개 (Static 앞) | 1개 (Static 앞) |
| `RAILS_ENV=production` (변수 미설정) | 1개 (Static 앞) | 1개 (Static 앞) |
| **`public_file_server.enabled = false`** | **0개** | **1개 (스택 최상단)** |

수정 후 최상단 배치 시 실제 스택:
```
use CanonicalPathRedirect
use ActionDispatch::AssumeSSL
use ActionDispatch::SSL
use Rack::Sendfile
use ActionDispatch::Executor
...
```

`enabled=false` 는 프로덕션에서 `Rails.application.config.public_file_server.enabled = false`
를 이니셜라이저 앞에 주입하는 임시 프로브로 만들었다 (측정 후 삭제, `git status` 로 확인).
`unshift` 가 `Rails::Configuration::MiddlewareStackProxy` 에 존재하는 것도 확인:
`[:+, :delete, :delete_operations, :insert, :insert_after, :insert_before, :merge_into,
:move, :move_after, :move_before, :operations, :swap, :unshift, :use]`

---

## ③ 수정 후 검증 (전부 로컬, 프로덕션 DB 미접촉)

| 검증 | 결과 |
|---|---|
| `bin/rails test` | **109 runs / 793 assertions / 0 failures** (직전 87/502) |
| **반복 슬래시 단언이 수정 전 미들웨어를 잡는가** | **22/25 실패** (root 3건은 원래도 동작했다) |
| **잡 테스트가 수정 전 잡을 잡는가** | **9/14 테스트 실패** |
| **통합 테스트의 `//` 가 raw 로 도달하는가** | 옛 미들웨어로 돌리면 `/safe//` 단언이 실패 → 도달함 (공허하지 않음) |
| 로컬 137경로 스윕 (리다이렉트 미추적) | 중복 200 **0개**, 루프 0, 3홉 이상 0, 홉 분포 `{1: 89, 2: 1}` |
| 그 2홉 1건 | `/blog/contract-checklist/` → `/blog/contract-checklist` → `/blog/contract-sharing-checklist` (미들웨어=철자, 라우터=이동. DECISIONS.md 2026-09-18 에서 수용) |
| 사이트맵 30개 | 전부 200 · 자기참조 canonical · noindex 0 · 리다이렉트 0 |
| 내부 링크 64개 (로컬 DB 는 글 3개) | 깨짐 0 · 리다이렉트 0 |
| Accept-Language(none/en/ja/es/ko) × 무프리픽스 8페이지 | canonical·robots 전부 불변 |
| **SW 프리캐시 URL 11개** | 전부 직접 200 (새 301 이 프리캐시 경로에 없음) |
| SW 네트워크 실패 주입 (`test/sw/offline_resilience.mjs`) | **9/9** |
| rubocop (변경 파일 10개) | 신규 위반 0 (남은 12건은 HEAD 사본에 돌려 기존 것임을 확인) |
| 측정 전 `docker compose restart web` | 매번 실행 (이니셜라이저·`lib/` 는 dev 리로드 안 됨) |

---

## ④ 핵심 파일 전문

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
#   update! rejects the record     | skip this post,    | logger.error per post
#   (RecordInvalid/RecordNotSaved) | batch continues    | + ONE admin email at
#                                  |                    | the end of the run
#   notification fails to enqueue  | skip the mail,     | logger.error
#                                  | post STAYS         |
#                                  | published          |
#   anything else (DB down, …)     | NOT isolated —     | the job fails, and
#                                  | it propagates      | Solid Queue retries
#   the failure report itself      | rescued            | logger.error
#
# The email matters more than it looks. Skipping a post trades one failure mode
# for another: instead of a stalled batch we now get a post that stays
# `scheduled` forever, and "forever" is exactly the kind of thing a log line in
# a container nobody tails will not tell anyone. So each run that skipped
# anything sends one message (one per run, not per post — a systemic problem
# must not turn into a mailbox flood). The job runs daily, so an unfixed post
# nags once a day until someone fixes it. The nagging IS the safety net.
#
# Infrastructure errors are deliberately NOT caught. Swallowing a dropped
# connection would report every post as "invalid" and let the job exit
# successfully, throwing away the retry that would have published them.
class PublishScheduledPostsJob < ApplicationJob
  queue_as :default

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
      return false
    end

    Rails.logger.info("Published scheduled post: #{post.slug}")
    notify(post)
    true
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

#### `app/views/blog_mailer/publish_failed.html.erb`

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

#### `lib/canonical_path_redirect.rb`

```ruby
# frozen_string_literal: true

require "cgi/escape"

# Rack middleware that gives every page exactly one spelling of its address.
#
# Two different layers were handing out duplicates, in opposite directions:
#
#   1. ActionDispatch::FileHandler resolves a request for `/safe` by probing
#      `public/safe`, `public/safe.html` and finally `public/safe/index.html`,
#      so `/safe`, `/safe/` and `/safe/index.html` all returned an identical
#      200. And because ActionDispatch::Static sits *in front of* the router,
#      `get "/safe", to: redirect("/safe/")` never ran — the static handler
#      answered first and the route was dead code.
#
#   2. The Rails router matches a trailing slash as if it were not there, so
#      every routed page answered twice as well: `/about` and `/about/`,
#      `/blog/:slug` and `/blog/:slug/`, down to `/sitemap.xml/`. Measured live
#      2026-09-17: 168 of 168 post URLs and 32 other paths, all real 200s, no
#      redirect involved. Search Console had already picked one of them up —
#      `/blog/contract-checklist/` was reported as a duplicate whose canonical
#      Google chose for itself.
#
# These need opposite fixes, which is why one middleware owns both: a static
# directory is canonical WITH the trailing slash (that is what `public/safe/`
# is), and a routed page is canonical WITHOUT it.
#
# It must be inserted BEFORE ActionDispatch::Static (see the initializer) or the
# static handler wins again for case 1.
class CanonicalPathRedirect
  # Directory-backed static HTML entrypoints, spelled without the trailing
  # slash. Each is served from `public/<dir>/index.html` and is canonical WITH
  # the slash. These are the only two directories under public/ (verified), and
  # both are declared that way in the sitemap.
  DIRS = %w[/safe /privacy].freeze

  # Only GET/HEAD are redirected. A POST must never be turned into a 301 — the
  # method and body would be silently dropped by the client.
  SAFE_METHODS = %w[GET HEAD].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    target = canonical_target(env)
    return @app.call(env) unless target

    location = redirect_location(env, target)

    [
      301,
      {
        "location" => location,
        "content-type" => "text/html; charset=utf-8",
        # A permanently-cached 301 is effectively irreversible in the browser.
        # This app has already been bitten once by a pinned static cache
        # (see lib/static_html_no_cache.rb), so the redirect always revalidates.
        "cache-control" => "no-cache"
      },
      [body_for(location)]
    ]
  end

  private

  # Returns the canonical spelling of this path, or nil when the request is
  # already canonical and should pass through untouched.
  def canonical_target(env)
    return nil unless SAFE_METHODS.include?(env["REQUEST_METHOD"])

    path = env["PATH_INFO"].to_s
    return nil if path.empty?

    canonical = canonical_spelling(path)
    canonical == path ? nil : canonical
  end

  # The single canonical address for a path, in two steps that must happen in
  # this order: reduce the path to its bare form, then map that form onto the
  # address it belongs to.
  #
  # Normalising FIRST is what makes this correct, and it is the fix for the
  # duplicate family the earlier version left open. Repeated slashes are
  # invisible to the layers behind this one — ActionDispatch::FileHandler
  # resolves `/safe//index.html` to the same file as `/safe/index.html`, and the
  # Rails router matches `/en//about` as `/en/about` — so every extra slash was
  # another address serving identical bytes, and `/safe//index.html` walked
  # straight past the `/safe/index.html` rule. Measured locally 2026-09-18,
  # before the fix, byte-identical 200s across the board:
  #
  #   /safe//  /safe///  /safe//index.html  /safe//sw.js  /safe/sw.js/
  #   /privacy//  /privacy//index.html
  #   //about  /en//about  /en///about  //faq  //blog  //sitemap.xml
  #   /blog//some-slug  /en//blog//some-slug
  #
  # The last two rows are mid-path, not trailing, and no amount of trailing-slash
  # stripping would have caught them.
  #
  # Doing it in this order also bounds the fix to ONE hop: `/safe//index.html/`
  # reaches `/safe/` directly instead of through two 301s. Every value this
  # method can return is a fixed point of it — `/safe/` reduces to `/safe` which
  # maps back to `/safe/`, and a bare routed path maps to itself — so a redirect
  # can never chain or loop. That is asserted in the tests.
  def canonical_spelling(path)
    bare = path.squeeze("/").sub(%r{/+\z}, "")
    return "/" if bare.empty?

    # Static directories are canonical WITH the trailing slash (that is what
    # `public/safe/` actually is); routed pages are canonical without it, which
    # is what `bare` already holds.
    DIRS.each do |dir|
      return "#{dir}/" if bare == dir || bare == "#{dir}/index.html"
    end

    bare
  end

  # The Location the client is sent to. The query string is echoed back from the
  # request, so strip anything that could break out of the header. Puma already
  # rejects a request line containing CR or LF, but relying on that would make
  # this middleware's safety a property of the upstream parser rather than of
  # this code — swap the server or put a proxy in front and the guarantee is
  # gone. Strip them here so the invariant holds on its own.
  def redirect_location(env, target)
    # SCRIPT_NAME is "" for a root-mounted app (the case here), but including it
    # keeps the Location correct if this app is ever mounted under a sub-path.
    #
    # String#delete takes a character SET, not a substring — this removes every
    # CR and every LF, not just the "\r\n" pair.
    query = env["QUERY_STRING"].to_s.delete("\r\n")
    location = "#{env["SCRIPT_NAME"]}#{target}"
    query.empty? ? location : "#{location}?#{query}"
  end

  # The 301 body is a courtesy for clients that do not follow Location (browsers
  # never render it). It still echoes request-controlled input, so escape it:
  # the same reasoning as above — the raw `<`, `>` and `"` that would make this
  # an injection are currently stopped by Puma's request-line parser, and that
  # is not a guarantee this file should depend on.
  def body_for(location)
    escaped = CGI.escapeHTML(location)
    "<html><body>Moved Permanently: <a href=\"#{escaped}\">#{escaped}</a></body></html>"
  end
end
```

#### `config/initializers/canonical_path_redirect.rb`

```ruby
# frozen_string_literal: true

# Insert CanonicalPathRedirect so every page has one address: `/safe` and
# `/safe/index.html` collapse onto `/safe/`, every routed page's trailing-slash
# twin collapses onto the bare path, and repeated slashes collapse anywhere they
# appear. See lib/canonical_path_redirect.rb for the full rationale.
#
# ── Why this is inserted unconditionally ────────────────────────────────────
#
# It used to be wrapped in `if config.public_file_server.enabled`, copied from
# the sibling initializer below. That was right when this middleware only fixed
# static directories: with no ActionDispatch::Static there was nothing to get in
# front of. It stopped being right on 2026-09-18, when the middleware took over
# trailing-slash normalisation for *routed* pages (`/about/`, `/blog/:slug/`,
# `/sitemap.xml/`) — those have nothing to do with static file serving.
#
# Measured, not assumed: with the guard in place and `public_file_server.enabled`
# false, `bin/rails middleware` listed CanonicalPathRedirect zero times. Moving
# public/ behind nginx would therefore have deleted canonical-URL normalisation
# for the whole site with no error and no log line — the exact silent-failure
# shape this repo keeps getting bitten by.
#
# So the middleware always goes in. Only its POSITION depends on Static:
#
#   * Static present  — insert directly in front of it. Required: the file
#     handler answers `/safe` from public/safe/index.html before the router ever
#     sees the request, which is why the equivalent route in config/routes.rb
#     was dead code for as long as it existed.
#   * Static absent   — unshift to the top of the stack. There is nothing to
#     insert before, and `insert_before` would raise at boot ("No such
#     middleware to insert before"), turning a deployment change into a crash.
#     This does put it ahead of ActionDispatch::SSL, so a plain-HTTP request
#     would be normalised before being upgraded rather than after. Same two
#     hops either way (scheme, then spelling, in the other order), and the
#     Location stays path-only, so SSL still gets its turn.
#
# Order vs StaticHtmlNoCache: both target the front of the stack, and
# initializers load alphabetically (canonical_path_redirect →
# static_html_no_cache), so this one ends up the *outer* of the two. Harmless
# either way: the rewriter only touches responses carrying `public, max-age=…`,
# and this 301 sends `no-cache`.
#
# The guard on static_html_no_cache.rb is NOT the same mistake and stays put —
# that middleware exists purely to rewrite the cache headers Static emits, so
# without Static it genuinely has no work to do.
require Rails.root.join("lib", "canonical_path_redirect").to_s

if Rails.application.config.public_file_server.enabled
  Rails.application.config.middleware.insert_before(
    ActionDispatch::Static, CanonicalPathRedirect
  )
else
  Rails.application.config.middleware.unshift(CanonicalPathRedirect)
end
```

#### `config/initializers/static_html_no_cache.rb`

```ruby
# frozen_string_literal: true

# Insert StaticHtmlNoCache in front of the static file server so static HTML
# entrypoints (/safe/, /privacy/, static blog posts) are served `no-cache`
# instead of inheriting the 1-year `public_file_server.headers` meant for
# digest-stamped assets. See lib/static_html_no_cache.rb for the full rationale.
#
# Only relevant when this app serves static files itself (RAILS_SERVE_STATIC_FILES
# in production; enabled by default in dev/test). Guarded so it is a no-op when
# ActionDispatch::Static is not in the stack.
require Rails.root.join("lib", "static_html_no_cache").to_s

Rails.application.config.middleware.insert_before(
  ActionDispatch::Static, StaticHtmlNoCache
) if Rails.application.config.public_file_server.enabled
```

#### `lib/static_html_no_cache.rb`

```ruby
# frozen_string_literal: true

# Rack middleware that downgrades the far-future Cache-Control on *static HTML*
# files to `no-cache`, so returning visitors always revalidate the HTML and a
# deploy reaches them immediately (a stale cached ETag/Last-Modified still gets
# a cheap 304, so unchanged pages cost no bandwidth).
#
# Why this exists: `config.public_file_server.headers` applies ONE header hash
# to every file under public/ (assets AND html). That is correct for digest-
# stamped assets (immutable, safe to cache for a year) but catastrophic for
# HTML entrypoints like /safe/ and /privacy/ — once a browser caches them with
# `max-age=1.year` it will not even ask the server again for up to a year.
#
# This middleware sits in front of ActionDispatch::Static and rewrites ONLY the
# responses that carry the static long-cache signature (`public, max-age=…`)
# AND are `text/html`. That precisely targets static HTML files and leaves:
#   - digest-stamped assets  → not text/html, untouched (keep long cache)
#   - dynamic Rails pages     → no `public, max-age` header, untouched
#   - sitemap.xml             → application/xml, untouched (keeps its own 3600)
class StaticHtmlNoCache
  # Serve stored copy but always revalidate first. Conditional GET via
  # Last-Modified/ETag still yields 304 when the file is unchanged.
  REVALIDATE = "no-cache"

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    rewrite!(headers, env["PATH_INFO"].to_s)
    [status, headers, body]
  end

  private

  # Paths that, like static HTML, must always revalidate so a deploy reaches
  # returning visitors immediately:
  #   - the service worker (/safe/sw.js): a 1-year-cached SW would pin an old
  #     app shell / caching logic on returning visitors — the very failure this
  #     middleware exists to prevent, one layer deeper.
  #   - PWA manifests (*.webmanifest): small, occasionally-edited metadata.
  # Digest-stamped assets and immutable icons keep their long cache.
  REVALIDATE_PATHS = /\/sw\.js\z|\.webmanifest\z/i

  def rewrite!(headers, path)
    content_type = lookup(headers, "content-type")
    is_html = content_type&.downcase&.include?("text/html")
    return unless is_html || path =~ REVALIDATE_PATHS

    cache_control = lookup(headers, "cache-control")
    return unless cache_control
    # only touch the far-future static header (public + a max-age), never the
    # `private/must-revalidate` that dynamic responses already carry.
    return unless cache_control =~ /\bpublic\b/i && cache_control =~ /max-age=\s*\d+/i

    assign(headers, "cache-control", REVALIDATE)
  end

  # Case-insensitive header access that works for both a plain Hash (Rack 2)
  # and Rack::Headers (Rack 3, already case-insensitive).
  def lookup(headers, name)
    return headers[name] if headers.key?(name)
    key = headers.keys.find { |k| k.to_s.casecmp?(name) }
    key && headers[key]
  end

  def assign(headers, name, value)
    key = headers.key?(name) ? name : (headers.keys.find { |k| k.to_s.casecmp?(name) } || name)
    headers[key] = value
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

  desc "Seed SafeFile guide posts (static pages) into blog index from db/seeds/safefile_posts.rb"
  task seed_safefile_posts: :environment do
    load Rails.root.join("db/seeds/safefile_posts.rb")
  end

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

#### `lib/tasks/blog_migrate_privacy.rake`

```ruby
# Idempotent migration of the three static SafeFile guide posts into the DB.
#
# The Korean bodies used to live as standalone static HTML under public/blog/,
# duplicating DB Post records that had empty bodies. This task makes the DB the
# single source of truth: it copies each Korean body in, renames the slug to the
# descriptive value, and files the post under the `privacy` category.
#
# Safe to run any number of times — it always sets fields to their target value
# and locates records by either their old or new slug.
#
#   Run once on production after deploy:
#     kamal app exec 'bin/rails blog:migrate_privacy'
#
namespace :blog do
  desc "Migrate static SafeFile privacy guides into DB posts (idempotent)"
  task migrate_privacy: :environment do
    # match_slugs: slugs a record may currently have (old first-run, new re-run)
    posts = [
      { match_slugs: %w[resume-privacy],
        slug: "resume-privacy", file: "resume-privacy.html" },
      { match_slugs: %w[rrn-masking resident-number-masking],
        slug: "resident-number-masking", file: "resident-number-masking.html" },
      { match_slugs: %w[contract-checklist contract-sharing-checklist],
        slug: "contract-sharing-checklist", file: "contract-sharing-checklist.html" }
    ]

    rejected = []

    posts.each do |spec|
      post = Post.where(slug: spec[:match_slugs]).order(:id).first
      unless post
        warn "  ! no post found for #{spec[:match_slugs].inspect} — skipping"
        next
      end

      body = Rails.root.join("db/blog_privacy", spec[:file]).read.strip

      post.slug     = spec[:slug]
      post.category = "privacy"
      post.body_ko  = body
      post.status   = "published" if post.status.blank?
      post.published_at ||= Time.current

      if post.changed?
        # The `next` above already establishes that one bad spec must not stop
        # the others. A rejected record follows the same rule — and this task is
        # idempotent, so re-running after a fix costs nothing.
        begin
          post.save!
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
          rejected << "#{spec[:slug]}: #{e.message}"
          warn "  ! #{spec[:slug]} (id=#{post.id}) rejected — #{e.message} — skipping"
          next
        end
        puts "  ✓ #{spec[:slug]} (id=#{post.id}) updated [#{post.saved_changes.keys.join(', ')}]"
      else
        puts "  = #{spec[:slug]} (id=#{post.id}) already current"
      end
    end

    puts "Done. privacy posts: #{Post.where(category: 'privacy').pluck(:slug).sort.join(', ')}"

    # Every spec got its turn first; now fail, because this task is on the
    # post-deploy command list and a migration that silently migrated nothing
    # must not exit 0. (A missing record is NOT a failure — the task is
    # idempotent and a fresh DB legitimately has nothing to migrate yet.)
    abort "blog:migrate_privacy: #{rejected.size} post(s) rejected — #{rejected.join(' | ')}" if rejected.any?
  end
end
```

#### `db/seeds/safefile_posts.rb`

```ruby
# SafeFile 가이드 글 3개의 Post 레코드.
#
# ⚠️ 이 시드는 **`blog:migrate_privacy` 로 대체됐다.** 원래 전제는 위 주석에 있던
# "본문은 `public/blog/<slug>/index.html` 정적 페이지가 담당한다" 였고, 그래서
# 본문 없는 published 레코드를 만드는 것이 의도였다. 그 전제는 두 번 깨졌다:
#
#   1. `9f8bfff`(2026-07-17)가 `public/blog/` 를 삭제했다 — 본문을 담당할 정적
#      파일이 더는 없다. `blog:migrate_privacy` 가 `db/blog_privacy/*.html` 를
#      DB 로 옮기면서 슬러그도 서술형으로 **개명**했다
#      (`rrn-masking` → `resident-number-masking`,
#       `contract-checklist` → `contract-sharing-checklist`).
#      아래 슬러그는 개명 **전** 값이라, 마이그레이션이 끝난 DB 에서 이 시드를
#      돌리면 기존 글을 찾지 못하고 **본문 없는 중복 글을 새로 만든다.**
#   2. 2026-09-18 의 `validates :body_ko, if: published` 가 그 생성을 거부한다.
#      즉 지금 이 시드는 신선한 DB 에서도 완주하지 못한다 (실측: 두 번째 항목에서
#      `RecordInvalid` 로 중단).
#
# 검증이 이 시드의 버그를 **잡아준 것**이다 — 검증 전에는 조용히 본문 없는 published
# 중복 2개를 만들어 /blog 목록과 사이트맵을 오염시켰다.
#
# 아래 루프는 그래도 항목 단위로 격리한다(같은 커밋에서 잡·레이크 전체에 적용한
# 규칙). 한 항목의 실패가 다른 항목을 막지 않고, 실패는 조용히 지나가지 않는다.
# **이 파일을 어떻게 정리할지(마이그레이션에 합치기 / 본문을 `db/blog_privacy/`
# 에서 읽게 하기 / 삭제)는 별도 결정이라 이번 커밋에서 손대지 않았다.**
safefile_posts = [
  {
    slug: "resume-privacy",
    title_ko: "이력서 속 개인정보, 어디까지 써야 할까",
    title_en: "Personal Info on Your Resume: How Much Is Too Much?",
    category: "student",
    meta_description_ko: "이력서에 주민등록번호, 집 주소, 생년월일까지 다 써야 할까요? 채용에 꼭 필요한 정보와 지워도 되는 개인정보 7가지, 그리고 안전하게 가리는 방법을 정리했습니다.",
    meta_description_en: "Do you really need your ID number, home address, and birth date on a resume? 7 pieces of personal info you can safely remove — and how to redact them."
  },
  {
    slug: "rrn-masking",
    title_ko: "주민등록번호 마스킹, 뒷자리만 가리면 될까",
    title_en: "Masking Korean ID Numbers: Is Hiding the Back Digits Enough?",
    category: "office",
    meta_description_ko: "주민등록번호 뒷자리에는 어떤 정보가 들어 있을까요? 서류 제출 전 주민번호를 올바르게 마스킹하는 방법과 등본·신분증 사본 제출 시 주의사항을 정리했습니다.",
    meta_description_en: "What's actually encoded in a Korean RRN? How to mask resident registration numbers correctly before submitting documents or ID copies."
  },
  {
    slug: "contract-checklist",
    title_ko: "계약서·서류를 보내기 전, 8가지 체크리스트",
    title_en: "8-Point Privacy Checklist Before Sharing Contracts & Documents",
    category: "freelancer",
    meta_description_ko: "부동산 계약서, 프리랜서 계약서, 급여명세서를 카톡이나 메일로 보내기 전에 확인해야 할 개인정보 체크리스트. 계좌번호, 도장, 서명까지 놓치기 쉬운 항목을 정리했습니다.",
    meta_description_en: "A privacy checklist for sharing lease contracts, freelance agreements, and pay stubs — account numbers, stamps, and signatures people forget to redact."
  }
]

seeded = 0
rejected = []

safefile_posts.each do |attrs|
  post = Post.find_or_initialize_by(slug: attrs[:slug])
  post.assign_attributes(
    attrs.merge(
      status: "published",
      published_at: post.published_at || Time.zone.parse("2026-07-16 09:00:00 +09:00")
    )
  )

  begin
    post.save!
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    rejected << [ attrs[:slug], e.message ]
    warn "  ! #{attrs[:slug]} rejected — #{e.message} — skipping"
    next
  end

  seeded += 1
  puts "Seeded post: #{post.slug} (#{post.status})"
end

puts "SafeFile guide posts: #{Post.where(slug: safefile_posts.map { |p| p[:slug] }).count}/3 present"

if rejected.any?
  # Loud on purpose, and non-zero on purpose. Isolating the bad item keeps the
  # others going, but this task is on the post-deploy command list (CLAUDE.md),
  # where a run that seeds nothing and exits 0 reads as success. So: every item
  # gets its turn, then the task fails.
  warn "\n#{rejected.size}/#{safefile_posts.size} rejected — this seed is superseded by " \
       "blog:migrate_privacy (see the header comment). Seeded #{seeded}."
  rejected.each { |slug, message| warn "  #{slug}: #{message}" }
  abort "blog:seed_safefile_posts: #{rejected.size} post(s) could not be seeded"
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

  # ── infrastructure errors must NOT be isolated ──────────────────────────

  # Only errors meaning "this record cannot be saved" are caught. A dropped
  # connection has to propagate: swallowing it would report every post as
  # invalid and let the job exit successfully, throwing away the Solid Queue
  # retry that would have published them.
  def with_connection_dropped
    victim = Post.new(slug: "job-infra", title_ko: "x")
    victim.define_singleton_method(:update!) { |*| raise ActiveRecord::ConnectionNotEstablished, "db gone" }

    relation = Object.new
    relation.define_singleton_method(:find_each) { |&block| block.call(victim) }

    Post.stub(:scheduled_ready, relation) { yield }
  end

  test "an error that is not a rejected record propagates so the queue can retry" do
    with_connection_dropped do
      assert_raises(ActiveRecord::ConnectionNotEstablished) { PublishScheduledPostsJob.perform_now }
    end
  end

  test "a dropped connection is not reported as a validation failure" do
    with_connection_dropped do
      assert_raises(ActiveRecord::ConnectionNotEstablished) { PublishScheduledPostsJob.perform_now }
    end

    perform_enqueued_jobs
    assert_empty mails_titled(REPORT_SUBJECT)
  end
end
```

#### `test/lib/canonical_path_redirect_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib", "canonical_path_redirect").to_s

# Unit tests for the redirect middleware, driven with a hand-built Rack env.
#
# Why not drive these through ActionDispatch::IntegrationTest: that stack parses
# and percent-encodes the URI before the middleware runs, so `<`, `>`, `"` and
# CR/LF arrive already neutralised and the assertions would pass vacuously.
# Puma does the same in production — it answers 400 to a request line carrying
# those bytes. That is precisely the dependency these tests exist to remove: the
# escaping has to be a property of this file, not of whatever parser happens to
# sit in front of it. Handing the middleware a raw env is the only altitude at
# which that can actually be asserted.
class CanonicalPathRedirectTest < ActiveSupport::TestCase
  # Inner app stands in for ActionDispatch::Static; a 200 means "passed through".
  PASSTHROUGH = ->(env) { [200, { "content-type" => "text/html" }, ["STATIC:#{env["PATH_INFO"]}"]] }

  def call(path, method: "GET", query: "", script_name: "")
    CanonicalPathRedirect.new(PASSTHROUGH).call(
      "PATH_INFO" => path,
      "REQUEST_METHOD" => method,
      "QUERY_STRING" => query,
      "SCRIPT_NAME" => script_name
    )
  end

  # ── redirect targets ────────────────────────────────────────────────────

  test "duplicate spellings redirect to the trailing-slash URL" do
    {
      "/safe" => "/safe/",
      "/safe/index.html" => "/safe/",
      "/privacy" => "/privacy/",
      "/privacy/index.html" => "/privacy/"
    }.each do |path, target|
      status, headers, = call(path)
      assert_equal 301, status, path
      assert_equal target, headers["location"], path
    end
  end

  test "the canonical spelling and everything else passes through" do
    %w[/ /safe/ /privacy/ /safe/sw.js /safe/icon.svg /safe/manifest.ko.webmanifest
       /api/safe_scan /safety /blog/safe /about /blog/some-slug].each do |path|
      status, = call(path)
      assert_equal 200, status, path
    end
  end

  # ── routed pages are canonical WITHOUT the trailing slash ───────────────
  #
  # The Rails router matches a trailing slash as if it were absent, so every
  # routed page answered twice. Measured live 2026-09-17: 168 of 168 post URLs
  # and 32 other paths returned a real 200 both ways, no redirect involved.

  test "a trailing slash on a routed page redirects to the bare path" do
    {
      "/about/" => "/about",
      "/faq/" => "/faq",
      "/blog/" => "/blog",
      "/blog/some-slug/" => "/blog/some-slug",
      "/en/" => "/en",
      "/en/about/" => "/en/about",
      "/ja/blog/some-slug/" => "/ja/blog/some-slug",
      "/sitemap.xml/" => "/sitemap.xml"
    }.each do |path, target|
      status, headers, = call(path)
      assert_equal 301, status, path
      assert_equal target, headers["location"], path
    end
  end

  test "the site root keeps its slash" do
    status, = call("/")
    assert_equal 200, status, "/ is already canonical and must not redirect"
  end

  test "repeated trailing slashes collapse in a single hop" do
    _, headers, = call("/about//")
    assert_equal "/about", headers["location"]
    _, headers, = call("/about///")
    assert_equal "/about", headers["location"]
  end

  # ── repeated slashes anywhere in the path ───────────────────────────────
  #
  # The layers behind this one cannot see a repeated slash: FileHandler resolves
  # `/safe//index.html` to the same file as `/safe/index.html`, and the Rails
  # router matches `/en//about` as `/en/about`. Every extra slash was therefore
  # another address serving identical bytes. Measured locally 2026-09-18 before
  # the fix — every path below answered 200 with a byte-identical body, and
  # `/safe//index.html` slipped past the `/safe/index.html` rule entirely.

  test "repeated slashes under a static directory collapse onto its canonical URL" do
    {
      "/safe//" => "/safe/",
      "/safe///" => "/safe/",
      "/safe//index.html" => "/safe/",
      "/safe///index.html" => "/safe/",
      "/safe/index.html/" => "/safe/",
      "/privacy//" => "/privacy/",
      "/privacy//index.html" => "/privacy/"
    }.each do |path, target|
      status, headers, = call(path)
      assert_equal 301, status, path
      assert_equal target, headers["location"], path
    end
  end

  test "repeated slashes in front of a static asset collapse onto the single asset URL" do
    {
      "/safe//sw.js" => "/safe/sw.js",
      "/safe///sw.js" => "/safe/sw.js",
      "/safe//manifest.ko.webmanifest" => "/safe/manifest.ko.webmanifest",
      # A trailing slash on an asset is a duplicate too: /safe/sw.js/ served the
      # same 8979 bytes as /safe/sw.js. The old code's "never touch anything
      # under a static dir" branch let this through.
      "/safe/sw.js/" => "/safe/sw.js",
      "/privacy//style.css" => "/privacy/style.css"
    }.each do |path, target|
      status, headers, = call(path)
      assert_equal 301, status, path
      assert_equal target, headers["location"], path
    end
  end

  test "repeated slashes mid-path on a routed page collapse in one hop" do
    # Not trailing — no amount of trailing-slash stripping would catch these.
    {
      "//about" => "/about",
      "/en//about" => "/en/about",
      "/en///about" => "/en/about",
      "//en/about" => "/en/about",
      "//faq" => "/faq",
      "//blog" => "/blog",
      "//sitemap.xml" => "/sitemap.xml",
      "/blog//some-slug" => "/blog/some-slug",
      "/en//blog//some-slug" => "/en/blog/some-slug",
      "//robots.txt" => "/robots.txt"
    }.each do |path, target|
      status, headers, = call(path)
      assert_equal 301, status, path
      assert_equal target, headers["location"], path
    end
  end

  test "repeated slashes at the root collapse onto /" do
    { "//" => "/", "///" => "/", "////" => "/" }.each do |path, target|
      status, headers, = call(path)
      assert_equal 301, status, path
      assert_equal target, headers["location"], path
    end
  end

  # ── no chains, no loops ─────────────────────────────────────────────────
  #
  # Normalising the path before mapping it is what bounds this to a single hop.
  # Rather than trust that argument, follow the middleware's own output back
  # into itself: if any Location it emits would redirect again, the fix has
  # created a chain, and if one ever returns to its input it has created a loop.
  # (config/routes.rb may add a second hop for an old slug — that is the router,
  # deliberately accepted, and out of this middleware's reach. DECISIONS.md
  # 2026-09-18.)

  test "no Location this middleware emits redirects again" do
    paths = %w[
      / // /// //// /safe /safe/ /safe// /safe/// /safe/index.html /safe//index.html
      /safe/index.html/ /safe/sw.js /safe/sw.js/ /safe//sw.js /privacy /privacy/
      /privacy// /privacy//index.html /about /about/ /about// /about/// //about
      /en//about /en///about //en/about /faq/ //faq /blog/ //blog /blog//some-slug
      /en//blog//some-slug /sitemap.xml/ //sitemap.xml /robots.txt //robots.txt
      /api/safe_scan /blog/safe /safety /en /en/
    ]

    paths.each do |path|
      status, headers, = call(path)
      next if status == 200

      location = headers["location"]
      follow_status, follow_headers, = call(location)
      assert_equal 200, follow_status,
        "#{path} -> #{location} -> #{follow_headers["location"]} is a redirect chain"
      assert_not_equal path, location, "#{path} redirects to itself"
    end
  end

  test "every canonical spelling is a fixed point" do
    # The same invariant stated directly on the pure function, so a regression
    # is reported at the rule rather than at one of its symptoms.
    mw = CanonicalPathRedirect.new(PASSTHROUGH)
    %w[
      / // /safe /safe/ /safe// /safe/index.html /safe/sw.js/ /privacy//
      /about/ //about /en//about /blog//some-slug /sitemap.xml/ ////
    ].each do |path|
      once = mw.send(:canonical_spelling, path)
      twice = mw.send(:canonical_spelling, once)
      assert_equal once, twice, "canonical_spelling is not idempotent for #{path}"
    end
  end

  test "a static directory keeps its slash while routed paths lose theirs" do
    # The two rules point in opposite directions, which is why one middleware
    # owns both. /safe/ is a real directory under public/; /about/ is not.
    assert_equal 200, call("/safe/").first
    assert_equal 200, call("/privacy/").first
    assert_equal 301, call("/about/").first
  end

  test "assets underneath a static directory are never rewritten" do
    %w[/safe/sw.js /safe/icon.svg /safe/manifest.ko.webmanifest /privacy/style.css].each do |path|
      assert_equal 200, call(path).first, path
    end
  end

  test "the trailing-slash redirect preserves the query string" do
    _, headers, = call("/blog/", query: "category=privacy")
    assert_equal "/blog?category=privacy", headers["location"]
  end

  test "only GET and HEAD lose the trailing slash" do
    assert_equal 301, call("/about/", method: "HEAD").first
    assert_equal 200, call("/about/", method: "POST").first
  end

  test "only GET and HEAD are redirected" do
    assert_equal 301, call("/safe", method: "HEAD").first
    # Turning a POST into a 301 would silently drop the method and body.
    assert_equal 200, call("/safe", method: "POST").first
    assert_equal 200, call("/privacy/index.html", method: "PUT").first
  end

  test "SCRIPT_NAME is preserved for a sub-path mount" do
    _, headers, = call("/safe", script_name: "/app")
    assert_equal "/app/safe/", headers["location"]
  end

  # ── query string handling ───────────────────────────────────────────────

  test "the query string is preserved" do
    _, headers, = call("/safe", query: "v=20260719")
    assert_equal "/safe/?v=20260719", headers["location"]
  end

  test "CR and LF are stripped from the Location header" do
    _, headers, = call("/safe", query: "a=1\r\nX-Injected: yes")
    assert_no_match(/[\r\n]/, headers["location"])
    assert_equal "/safe/?a=1X-Injected: yes", headers["location"]
  end

  # ── 301 body escaping ───────────────────────────────────────────────────

  test "HTML metacharacters from the query string are escaped in the body" do
    _, _, body = call("/safe", query: %(x="><script>alert(1)</script>))
    html = body.first

    assert_not_includes html, "<script>"
    assert_includes html, "&lt;script&gt;"
    assert_includes html, "&quot;"
    # The anchor the template itself writes is the only markup left standing.
    assert_equal 1, html.scan("<a href=").length
    assert_equal 1, html.scan("</a>").length
  end

  test "an attribute-breaking payload cannot escape the href" do
    _, _, body = call("/safe", query: %(x=a" onmouseover="alert(1)))
    html = body.first

    assert_not_includes html, "onmouseover=\"alert"
    assert_includes html, "&quot;"
    # exactly two quote characters remain: the ones delimiting href="…"
    assert_equal 2, html.count('"')
  end

  test "ampersands and single quotes are escaped" do
    _, _, body = call("/safe", query: "x=a&b='c'")
    html = body.first

    assert_includes html, "&amp;"
    assert_not_includes html, "'"
  end

  test "percent-encoded payloads stay inert and unmangled" do
    encoded = "x=%22%3E%3Cscript%3E"
    _, headers, body = call("/safe", query: encoded)

    assert_equal "/safe/?#{encoded}", headers["location"]
    assert_includes body.first, encoded
    assert_not_includes body.first, "<script>"
  end

  test "an ordinary query string stays readable in the body" do
    _, _, body = call("/safe", query: "v=20260719")
    assert_includes body.first, %(<a href="/safe/?v=20260719">/safe/?v=20260719</a>)
  end

  # ── response shape ──────────────────────────────────────────────────────

  test "the redirect is not cached permanently by the browser" do
    _, headers, = call("/safe")
    assert_equal "no-cache", headers["cache-control"]
    assert_equal "text/html; charset=utf-8", headers["content-type"]
  end
end
```

#### `test/integration/canonical_urls_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"

# Search Console named three URLs on 2026-09-18, and every earlier guess about
# which they would be had been wrong. These tests pin the measured causes.
#
#   https://slimfile.net/api/safe_scan            404, first seen 2026-09-05
#   https://slimfile.net/en/about                 duplicate, Google-chosen canonical
#   https://slimfile.net/blog/contract-checklist/ duplicate, Google-chosen canonical
class CanonicalUrlsTest < ActionDispatch::IntegrationTest
  BASE = "https://slimfile.net"

  def canonical(body) = body[/<link rel="canonical" href="([^"]*)"/, 1]
  def robots(body) = body[/<meta name="robots" content="([^"]*)"/, 1]
  def hreflangs(body) = body.scan(/<link rel="alternate" hreflang="([^"]+)"/).flatten

  # ── the middleware is actually installed ────────────────────────────────

  test "CanonicalPathRedirect is in the stack, ahead of the static file server" do
    # Every assertion in this file is worthless if the middleware silently
    # stops being inserted — which is exactly what its old
    # `if public_file_server.enabled` guard could have caused the day public/
    # moved behind a proxy (measured: the middleware appeared zero times).
    #
    # This covers the branch this environment boots with (Static present). The
    # other branch cannot be exercised in-process, since the stack is built
    # once at boot; it was verified by booting the production environment with
    # public_file_server.enabled forced false and reading `bin/rails middleware`
    # — recorded in CLAUDE.md.
    names = Rails.application.middleware.map { |m| m.name.to_s }

    assert_includes names, "CanonicalPathRedirect"
    assert_includes names, "ActionDispatch::Static",
      "this environment is expected to serve public/ itself"
    assert_operator names.index("CanonicalPathRedirect"), :<,
      names.index("ActionDispatch::Static"),
      "the static handler would answer /safe before the middleware could redirect it"
  end

  # ── /api/safe_scan ──────────────────────────────────────────────────────

  test "the API endpoint is blocked from crawling in robots.txt" do
    # Not X-Robots-Tag: a noindex header has to be fetched to be obeyed, which
    # is the crawl we are preventing, and GET returns 404 so there is no
    # response of ours to attach a header to.
    get "/robots.txt"
    assert_match %r{^Disallow: /api/$}, response.body
  end

  test "GET on the API endpoint is still a 404 and that is fine" do
    # It is POST-only by design; robots.txt is what keeps crawlers away.
    get "/api/safe_scan"
    assert_response :not_found
  end

  # ── trailing slashes ────────────────────────────────────────────────────

  test "every routed page redirects its trailing-slash twin to the bare path" do
    {
      "/about/" => "/about",
      "/faq/" => "/faq",
      "/compress/" => "/compress",
      "/pdf/" => "/pdf",
      "/social/" => "/social",
      "/blog/" => "/blog",
      "/en/" => "/en",
      "/en/faq/" => "/en/faq",
      "/ja/compress/" => "/ja/compress",
      "/es/blog/" => "/es/blog",
      "/blog/korean-only-post/" => "/blog/korean-only-post",
      "/en/blog/bilingual-post/" => "/en/blog/bilingual-post"
    }.each do |path, target|
      get path
      assert_response :moved_permanently, path
      assert_redirected_to target
    end
  end

  test "the static directories keep their trailing slash" do
    %w[/safe/ /privacy/].each do |path|
      get path
      assert_response :success, "#{path} is a real directory under public/"
    end
    get "/safe"
    assert_redirected_to "/safe/"
  end

  test "a renamed slug spelled with a trailing slash still lands on the new address" do
    # Two hops, by design and bounded: this middleware normalises *spelling* and
    # runs ahead of the router, which resolves the *move*. So
    # /blog/contract-checklist/ → /blog/contract-checklist → the new slug.
    # Pulling the slug table into the middleware would collapse it to one hop
    # and make the route in config/routes.rb dead code — the exact trap /safe
    # fell into. Two 301s is the cheaper price.
    #
    # The targets no longer carry a trailing slash of their own, which would
    # have added a third hop.
    get "/blog/contract-checklist/"
    assert_response :moved_permanently
    assert_redirected_to "/blog/contract-checklist"

    follow_redirect!
    assert_response :moved_permanently
    assert_redirected_to "/blog/contract-sharing-checklist"

    follow_redirect!
    assert_response :not_found, "the fixture set has no such post, but the chain terminates"
  end

  test "the bare spelling of a renamed slug is still one hop" do
    get "/blog/contract-checklist"
    assert_response :moved_permanently
    assert_redirected_to "/blog/contract-sharing-checklist"

    get "/en/blog/rrn-masking"
    assert_response :moved_permanently
    assert_redirected_to "/en/blog/resident-number-masking"
  end

  # ── repeated slashes ────────────────────────────────────────────────────
  #
  # Both layers behind the middleware are blind to a repeated slash:
  # FileHandler resolves /safe//index.html to the same file as
  # /safe/index.html, and the router matches /en//about as /en/about. Measured
  # locally 2026-09-18 before the fix: every path below answered a 200 whose
  # body was byte-identical to its canonical twin, and /safe//index.html walked
  # past the /safe/index.html rule entirely.
  #
  # These go through the full stack, so they prove the *app* has one address per
  # page. The middleware's own rules are pinned at the Rack level in
  # test/lib/canonical_path_redirect_test.rb, where the path can be handed over
  # verbatim.

  test "repeated slashes collapse onto the canonical address" do
    {
      "/safe//" => "/safe/",
      "/safe///" => "/safe/",
      "/safe//index.html" => "/safe/",
      "/safe/index.html/" => "/safe/",
      "/privacy//" => "/privacy/",
      "/privacy//index.html" => "/privacy/",
      "/safe//sw.js" => "/safe/sw.js",
      "/safe/sw.js/" => "/safe/sw.js",
      "//about" => "/about",
      "/en//about" => "/en/about",
      "//faq" => "/faq",
      "//blog" => "/blog",
      "/blog//contract-sharing-checklist" => "/blog/contract-sharing-checklist",
      "//sitemap.xml" => "/sitemap.xml"
    }.each do |path, target|
      get path
      assert_response :moved_permanently, "#{path} should not answer directly"
      assert_equal target, response.headers["location"], path
    end
  end

  test "no redirect chain loops or exceeds two hops" do
    %w[/about/ /blog/ /en/faq/ /blog/contract-checklist/ /safe /safe/index.html
       /blog/index.html /blog/rrn-masking/
       /safe// /safe/// /safe//index.html /safe/index.html/ /safe//sw.js
       /safe/sw.js/ /privacy// //about /en//about /en///about //faq
       /blog//contract-checklist /blog//contract-checklist/ //sitemap.xml
       // ///].each do |path|
      get path
      seen = [path]
      hops = 0
      while response.redirect? && hops < 5
        loc = response.headers["location"].sub("http://www.example.com", "")
        assert_not_includes seen, loc, "#{path} loops at #{loc}"
        seen << loc
        follow_redirect!
        hops += 1
      end
      assert_operator hops, :<=, 2, "#{path} took #{hops} hops: #{seen.inspect}"
    end
  end

  test "no sitemap URL is itself a redirect" do
    get "/sitemap.xml"
    locs = response.body.scan(%r{<loc>([^<]+)</loc>}).flatten
    locs.each do |u|
      get u.sub(BASE, "")
      assert_response :success, "#{u} is advertised in the sitemap but redirects"
    end
  end

  # ── /about is one document, not four ────────────────────────────────────

  test "the about page canonicalises every locale onto /about" do
    %w[/about /en/about /ja/about /es/about].each do |path|
      get path
      assert_response :success, path
      assert_equal "#{BASE}/about", canonical(response.body), path
    end
  end

  test "only the unprefixed about page is indexable" do
    get "/about"
    assert_nil robots(response.body)

    %w[/en/about /ja/about /es/about].each do |path|
      get path
      assert_equal "noindex,follow", robots(response.body),
                   "#{path} serves the same English document as /about"
    end
  end

  test "the about page claims no language at all" do
    # Hardcoded English with no t() calls: declaring itself the Korean or
    # Japanese alternate would be a false claim, and x-default would be too.
    %w[/about /en/about].each do |path|
      get path
      assert_empty hreflangs(response.body), path
    end
  end

  test "the sitemap lists about once, unprefixed" do
    get "/sitemap.xml"
    locs = response.body.scan(%r{<loc>([^<]+)</loc>}).flatten
    assert_includes locs, "#{BASE}/about"
    %w[en ja es].each { |loc| assert_not_includes locs, "#{BASE}/#{loc}/about" }
  end

  test "genuinely translated pages keep all four locale URLs" do
    # The narrowing must not leak onto /faq, /compress or / — those really are
    # translated (28-38% similar to Korean, measured, vs 92-94% for about).
    get "/sitemap.xml"
    locs = response.body.scan(%r{<loc>([^<]+)</loc>}).flatten
    %w[/faq /compress /pdf /social].each do |path|
      %w[en ja es].each do |loc|
        assert_includes locs, "#{BASE}/#{loc}#{path}"
      end
    end
    get "/en/faq"
    assert_nil robots(response.body)
    assert_equal %w[ko en ja es x-default], hreflangs(response.body)
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

#### `config/routes.rb`

```ruby
Rails.application.routes.draw do
  # Permanent slug renames for the static SafeFile guide posts. These must come
  # before the "/blog/:slug" route below so they win; after the folder rename the
  # old paths no longer resolve as static files and fall through to here.
  # 301 (redirect default) — never reverse. Rails matches the routes with or
  # without a trailing slash, so both /blog/rrn-masking and /blog/rrn-masking/
  # are covered. The locale prefix is preserved in the target so a Spanish reader
  # stays in Spanish (/es/blog/contract-checklist → /es/blog/contract-sharing-checklist).
  #
  # The targets carry NO trailing slash (2026-09-18). They used to, and once
  # CanonicalPathRedirect started normalising routed paths that made every one of
  # these a 301 to a 301. Search Console had already caught the old spelling:
  # /blog/contract-checklist/ was reported as a duplicate with a Google-chosen
  # canonical, last crawled 2026-07-18 — a day before the rename shipped.
  OLD_BLOG_SLUGS = {
    "rrn-masking"        => "resident-number-masking",
    "contract-checklist" => "contract-sharing-checklist"
  }.freeze

  OLD_BLOG_SLUGS.each do |old_slug, new_slug|
    get "/blog/#{old_slug}", to: redirect("/blog/#{new_slug}")
    %w[en ja es].each do |loc|
      get "/#{loc}/blog/#{old_slug}", to: redirect("/#{loc}/blog/#{new_slug}")
    end
  end

  # Locale-prefixed public pages. Korean (default) uses bare paths; the
  # constraint only matches en/ja/es, so /ko/... never resolves here.
  scope "(:locale)", locale: /en|ja|es/ do
    root "pages#home"

    resources :conversions, only: [:create, :show] do
      member do
        get :download
      end
    end

    get "/compress", to: "pages#compress"
    get "/pdf",      to: "pages#pdf"
    get "/social",   to: "pages#social"
    get "/about",    to: "pages#about"
    get "/faq",      to: "pages#faq"

    get "/blog",       to: "posts#index", as: :blog

    # The blog index used to be a static file at public/blog/index.html, so
    # ActionDispatch::Static answered /blog, /blog/ AND /blog/index.html with an
    # identical 200 and Google indexed all three. 9f8bfff (2026-07-17) deleted
    # the file when the listing moved into Rails, which left /blog/index.html
    # falling through to "/blog/:slug" below as slug="index.html" → 404.
    # 301 it back onto the listing instead of stranding an indexed URL.
    # MUST stay above "/blog/:slug" — routes match in declaration order.
    get "/blog/index.html",
        to: redirect { |params, _req| params[:locale] ? "/#{params[:locale]}/blog" : "/blog" }

    get "/blog/:slug", to: "posts#show",  as: :blog_post
  end

  # SafeFile — public/safe/index.html은 Rails가 정적 서빙(언어 독립 단일 URL),
  # API는 AI 정밀 검사 중계. 로케일 프리픽스 없음.
  #
  # `get "/safe", to: redirect("/safe/")` 는 여기 있었지만 **한 번도 실행된 적이 없다**
  # (2026-09-17 제거). ActionDispatch::Static 이 라우터보다 앞에 있고,
  # FileHandler 가 `/safe` 요청을 `public/safe/index.html` 로 해석해 200 을 먼저
  # 돌려주기 때문이다. 트레일링 슬래시 정규화는 정적 핸들러보다 앞서야 하므로
  # Rack 미들웨어(lib/canonical_path_redirect.rb)로 옮겼다.
  post "/api/safe_scan", to: "api/safe_scan#create"

  namespace :admin do
    get  "login",  to: "sessions#new",     as: :login
    post "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    resources :posts do
      member do
        post :generate
        post :improve
        post :publish
      end
      collection do
        post :auto_generate
      end
    end

    resources :banners do
      member do
        patch :toggle
        patch :move
      end
    end

    resources :blog_styles do
      member do
        post :analyze
        post :toggle
      end
    end

    root to: "banners#index"
  end

  get "sitemap.xml", to: "pages#sitemap", as: :sitemap, defaults: { format: :xml }

  get "up" => "rails/health#show", as: :rails_health_check
end
```

#### `config/locales/ko.yml` — 이번에 추가한 검증 메시지 블록 (파일 말미)

```yaml
  # ── Validation messages ─────────────────────────────────────────────────
  #
  # There was no activerecord block here at all, and ko is the default locale,
  # so every validation failure rendered as its own lookup trace:
  #
  #   ActiveRecord::RecordInvalid#message
  #     → "Translation missing: ko.activerecord.errors.messages.record_invalid"
  #   errors.full_messages
  #     → "Body ko Translation missing. Options considered were: …"
  #
  # Two places read those strings where a person is meant to understand them:
  # the admin post/banner forms, and — since 2026-09-18 — the failure report
  # PublishScheduledPostsJob mails when a post cannot be published. An alert
  # whose reason field says "Translation missing" is an alert that does not
  # work, so this block is part of that fix rather than a cosmetic aside.
  #
  # Scoped to the three validators this app actually uses (presence, uniqueness,
  # inclusion) plus the record_invalid wrapper. There is no rails-i18n gem here;
  # if one is ever added it supersedes this block.
  errors:
    # No space between attribute and message: Korean particles attach to the
    # noun ("본문(한국어)을(를) …", "카테고리에 …"), so the default
    # "%{attribute} %{message}" would put a gap in the middle of a word.
    format: "%{attribute}%{message}"
    messages:
      blank: "을(를) 입력해 주세요"
      taken: "은(는) 이미 사용 중입니다"
      inclusion: "에 허용되지 않는 값이 들어왔습니다"
  activerecord:
    errors:
      messages:
        record_invalid: "저장할 수 없습니다: %{errors}"
        blank: "을(를) 입력해 주세요"
        taken: "은(는) 이미 사용 중입니다"
        inclusion: "에 허용되지 않는 값이 들어왔습니다"
    models:
      post: "블로그 글"
      banner: "배너"
    attributes:
      post:
        title_ko: "제목(한국어)"
        title_en: "제목(영어)"
        body_ko: "본문(한국어)"
        body_en: "본문(영어)"
        meta_description_ko: "메타 설명(한국어)"
        meta_description_en: "메타 설명(영어)"
        slug: "슬러그"
        category: "카테고리"
        status: "상태"
        published_at: "발행일시"
      banner:
        title_en: "제목(영어)"
        title_ko: "제목(한국어)"
        position: "위치"
        page: "페이지"
        banner_type: "배너 종류"
```

#### `app/views/admin/posts/_form.html.erb` — 검증 메시지를 출력하는 곳 (첫 12줄)

```erb
<%= form_with(model: [:admin, post], class: "admin-form") do |f| %>
  <% if post.errors.any? %>
    <div class="admin-flash admin-flash-alert">
      <% post.errors.full_messages.each do |msg| %>
        <p><%= msg %></p>
      <% end %>
    </div>
  <% end %>

  <div class="admin-form-row">
    <div class="admin-form-group">
      <label>Status</label>
```

#### `public/safe/sw.js` — 프리캐시 부분 (30~115줄)

```javascript
// The one asset the offline UI cannot open without. Precaching it is REQUIRED:
// if it fails, install fails (see below) rather than silently producing a
// version that can never open offline.
//
// It used to have a twin, '/safe/index.html', which is deliberately gone: since
// 2026-09-17 that URL 301s to '/safe/' (lib/canonical_path_redirect.rb, SEO
// de-duplication) and cache.put() rejects a redirected Response, so precaching
// it could only ever be a silent no-op. Losing the twin also lost the
// redundancy that used to absorb a failed '/safe/' fetch — which is exactly why
// the required/optional split below exists.
const REQUIRED_SHELL = '/safe/';

// Best-effort extras. A transient miss on an icon must NOT block the update:
// the UI still opens offline without them.
const OPTIONAL_SHELL_ASSETS = [
  '/safe/manifest.ko.webmanifest',
  '/safe/manifest.en.webmanifest',
  '/safe/manifest.ja.webmanifest',
  '/safe/manifest.es.webmanifest',
  '/safe/icon.svg',
  '/safe/icon-192.png',
  '/safe/icon-512.png',
  '/safe/icon-maskable-512.png',
  '/safe/apple-touch-icon.png',
];

// Cross-origin hosts whose (version-pinned) assets we cache-first for revisit speed.
const CACHEABLE_CDN = [
  'cdnjs.cloudflare.com',
  'cdn.jsdelivr.net',
  'fonts.googleapis.com',
  'fonts.gstatic.com',
];

// Precache with cache:'reload' so a stale HTTP-cache entry (e.g. a legacy
// long-max-age shell) can NEVER be baked into the offline cache — that exact
// chain pinned an old app shell on returning visitors.
function precache(cache, url) {
  return fetch(new Request(url, { cache: 'reload' })).then((r) => {
    // A redirected Response would make cache.put() reject, so surface it as a
    // plain failure with a readable reason instead.
    if (!r || !r.ok || r.redirected) {
      throw new Error(`precache ${url}: ${r ? (r.redirected ? 'redirected' : r.status) : 'no response'}`);
    }
    return cache.put(url, r.clone());
  });
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(SHELL_CACHE);

    // REQUIRED first, and let a failure reject the whole install. Without this
    // a transient network blip during install produced a "successful" SW that
    // then took over (skipWaiting) and evicted the previous version's caches in
    // activate — costing a returning visitor a working offline shell. A failed
    // install instead leaves the OLD service worker active with its caches
    // intact, and the browser retries the update on a later visit.
    await precache(cache, REQUIRED_SHELL);

    // Optional extras: tolerate individual misses (a 404 must not fail install).
    await Promise.all(OPTIONAL_SHELL_ASSETS.map((u) => precache(cache, u).catch(() => null)));

    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // Evicting the previous version's caches is irreversible, so confirm this
    // version's shell is actually present before doing it. install already
    // guarantees that, but the browser may drop cache entries under storage
    // pressure at any time — verify rather than assume.
    //
    // When the shell is missing we keep the old caches. That is safe: the
    // offline fallback in fetch() uses the global caches.match(), which
    // searches EVERY cache in the origin, so a previous version's shell still
    // opens the app. The next version's activate clears the backlog.
    const cache = await caches.open(SHELL_CACHE);
    const shellReady = !!(await cache.match(REQUIRED_SHELL));

    if (shellReady) {
      const keys = await caches.keys();
      await Promise.all(
        keys
          .filter((k) => k.startsWith('safefile-') && k !== SHELL_CACHE && k !== RUNTIME_CACHE)
```

#### `app/controllers/posts_controller.rb` (참고: increment! 위치)

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.published.recent
    @posts = @posts.by_category(params[:category]) if params[:category].present?
    # page_meta lives in index.html.erb — a controller-side call is a silent
    # no-op here. See the comment at the top of that view.
  end

  def show
    @post = Post.where(status: [ "published", "scheduled", "draft" ]).find_by!(slug: params[:slug])
    @post.increment!(:view_count)
    @related_posts = Post.published.where(category: @post.category).where.not(id: @post.id).recent.limit(3)

    # Empty body or a locale we haven't actually translated into → don't index
    # this URL; point its canonical at the Korean original (see show.html.erb).
    # NOTE: page/meta tags are emitted from the view via content_for — content_for
    # set from a controller's `helpers` proxy does not reach the rendered layout.
    # Instance variables DO reach it, which is why @hreflang_locales is set here.
    #
    # The gate reads the locale off the URL, not off I18n.locale. set_locale
```

---

## ⑤ 정본 대조표 (DECISIONS.md, 이번에 신설된 행)

| 규칙 | 구현 위치 |
|---|---|
| 잡은 **레코드 거부만** 글 단위로 격리하고, 그 외 예외는 **전파** | `PublishScheduledPostsJob::RECORD_REJECTED`, `#publish` |
| 건너뛴 글은 **런당 관리자 메일 1통** (글당 아님, 로그만도 아님) | `#report` + `BlogMailer#publish_failed` |
| 알림 메일 실패는 **발행을 롤백하지 않는다** | `#notify` |
| `ko.yml` 에 검증 메시지 블록 (rails-i18n 젬 없음) | `config/locales/ko.yml` 말미 |
| 정본 경로는 **정규화 → 매핑** 순서 | `CanonicalPathRedirect#canonical_spelling` |
| 미들웨어는 **무조건 삽입**, `public_file_server.enabled` 는 **위치만** 선택 | `config/initializers/canonical_path_redirect.rb` |
| 배포 후 명령 목록의 레이크 태스크는 **전 항목 처리 후 `abort`** | `blog_migrate_privacy.rake`, `safefile_posts.rb` |

기존 행 중 이번 건과 맞물리는 것:
- (2026-09-18) 정적 디렉터리는 슬래시 **있는** 쪽, 라우팅 페이지는 **없는** 쪽이 정본.
  한 미들웨어가 둘 다 갖는다.
- (2026-09-18) 구 슬러그 리다이렉트는 **2홉을 수용**한다 (슬러그 표를 미들웨어로 옮기지 않음).
- (2026-09-18) 발행된 글은 반드시 한국어 본문을 가진다 (`validates :body_ko, if: published`).
- (2026-09-17) 301 에 `cache-control: no-cache`.
- (2026-09-17) 301 본문·Location 의 방어를 상류 파서에 맡기지 않는다.
- (2026-09-17) SW 셸을 필수/선택으로 나누고 필수 실패 시 install 을 실패시킨다.

## ⑥ 확신이 없는 지점 (이미 아는 것 — 여기에 의견을 달라)

1. **`RECORD_REJECTED` 의 경계.** `RecordInvalid`·`RecordNotSaved` 두 개로 좁혔다.
   넓히면 인프라 장애가 "글 문제" 로 오분류되고 잡이 성공으로 끝난다. 좁히면 놓치는
   "저장 불가" 가 생겨 배치가 다시 멈춘다. **이 경계가 맞는지 확신이 없다.**
2. **메일이 유일한 영구-가시화 채널이다.** `deliver_later` 가 enqueue 만 하므로 큐가
   죽어 있으면 로그밖에 남지 않는다. 더 나은 채널(관리자 화면의 배너, `/up` 헬스체크 확장,
   `scheduled` 이면서 `published_at` 이 한참 과거인 글을 세는 지표)을 고려했으나
   이번 범위에서 빼두었다. **판단을 달라.**
3. **`/safe/sw.js/` 를 301 하기로 한 것.** 중복 URL 이므로 통합이 맞다고 봤지만,
   `sw.js` 는 브라우저가 특별 취급하는 파일이다. 프리캐시 목록에는 `/safe/sw.js/` 가 없어
   현재 무해함은 확인했으나, PWA 쪽 부작용을 놓쳤을 수 있다.
4. **`unshift` 시 `ActionDispatch::SSL` 보다 위에 놓인다.** 홉 수는 양쪽 다 2 이고
   Location 이 경로만 담으므로 SSL 이 자기 차례를 잃지 않는다고 판단했다. 또한
   `ActionDispatch::Executor` 보다 앞에서 도는데, 이 미들웨어는 DB·AR 을 만지지 않으므로
   문제 없다고 봤다. **둘 다 확신이 낮다.**
5. **`errors.format` 에서 공백을 뺀 것.** 한국어 조사 때문인데, 속성명 번역이 없는 모델
   (Banner·BlogTopic·Conversion)에서는 `Title en을(를) 입력해 주세요` 처럼 영어+한국어가
   붙는다. 어드민 폼이 있는 Post·Banner 만 속성명을 넣었다.
6. **`db/seeds/safefile_posts.rb` 의 존재 이유 정리를 보류했다.** 패턴만 고쳤고, 이 시드가
   `blog:migrate_privacy` 와 싸우는 문제(마이그레이션 후 돌리면 `category` 를
   `privacy`→`student` 로 되돌린다 — 실행 로그로 확인)는 남아 있다. 보류가 옳은가?
7. **`blog:generate`·`regenerate_scheduled` 는 exit 0 로 남겼다.** 사람이 보는 앞에서
   돌리고 기존 관례가 그렇다는 이유인데, 4·5 와 일관성이 없는 것은 사실이다.

## 비밀값 스캔 결과

(패키지 생성 직후 실행 — 아래 절 참조)

## 비밀값 스캔 (실행 결과)

패키지 생성 직후 실행. 정규식: `ghp_`/`gho_`/`github_pat_` 토큰 · `sk-ant-` 키 ·
`ANTHROPIC_API_KEY=`/`GMAIL_PASSWORD=`/`SECRET_KEY_BASE=`/`DB_PASSWORD=` 의 **값** 형태 ·
PEM 헤더 · `AKIA` · 인라인 `password: "…"`.

- **일치 0건.**
- 등장하는 이메일 2개는 이미 저장소에 평문으로 있는 것이다:
  `chaop2@gmail.com`(`BlogMailer` 수신자 상수), `noreply@slimfile.net`(`ApplicationMailer`
  기본 발신자의 폴백). 비밀값이 아니다.
- `ENV` 참조는 **이름만** 포함됐다 (`ENV.fetch("GMAIL_USERNAME", …)`, `ENV["ANTHROPIC_API_KEY"]`).
  값은 없다.
- `SECRET_KEY_BASE=x` 는 프로덕션 환경으로 `bin/rails middleware` 를 돌리기 위한 **더미**다.
- `.env`·`.env.production.local`·`.kamal/secrets` 는 패키지에 **넣지 않았다**.
