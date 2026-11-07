# Rails 8.0.5.1 → 8.1.4.1 업그레이드 검토 패키지 (2026-11-07, docpack)

리포: chaop2026/docpack (PUBLIC). Ruby 3.3.9 (.ruby-version, 무수정).
Rails 8.0 보안지원 종료 2026-11-07. 8.1.4.1 은 2026-11-04 보안 릴리스(CVE 21건).
config.load_defaults 는 **8.0 유지**(지시). new_framework_defaults_8_1.rb 항목 전부 주석.
Dockerfile · .ruby-version · config/deploy.yml · .kamal/ 는 **무수정**.

## 1. Gemfile diff
```diff
diff --git a/Gemfile b/Gemfile
index f6a1cc8..77014dd 100644
--- a/Gemfile
+++ b/Gemfile
@@ -2,13 +2,18 @@ source "https://rubygems.org"
 
 # Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
 #
-# Floor raised to 8.0.5 on 2026-09-18. railties 8.0.5 is the first release whose
-# rails/test_unit/line_filtering.rb branches on Minitest::VERSION and ships a
-# 3-arity `run` for minitest 6; 8.0.4 and earlier only prepend a 2-arity `run`,
-# so resolving minitest 6 alongside them kills the whole test suite before a
-# single assertion runs. This is a floor, not a pin — the cause is gone, so the
-# minitest pin that used to suppress the symptom is gone too (see :test group).
-gem "rails", "~> 8.0.5"
+# Floor raised to 8.1.4 on 2026-11-07. Rails 8.0's security support ENDED
+# 2026-11-07; 8.1 is supported to 2027-10-10. 8.1.4.1 / 8.0.5.2 (2026-11-04)
+# carried 21 CVEs, so the floor is the patched release, not plain 8.1.4.
+#
+# The 8.0.5 floor this replaces was about minitest: railties 8.0.5 was the first
+# release whose rails/test_unit/line_filtering.rb branches on Minitest::VERSION
+# and ships a 3-arity `run` for minitest 6. That reason is subsumed — 8.1.4.1
+# keeps the /^5/ and /^6/ branches (verified in the installed gem, not assumed),
+# so the `minitest "< 7"` ceiling in the :test group still carries its own
+# separate reason: neither branch matches 7, and there is still no `else`, so
+# minitest 7 would silently disable line filtering rather than fail loudly.
+gem "rails", "~> 8.1.4"
 # The modern asset pipeline for Rails [https://github.com/rails/propshaft]
 gem "propshaft"
 # Use postgresql as the database for Active Record
```

## 2. 신규 파일: config/initializers/new_framework_defaults_8_1.rb (전부 주석인지 확인 대상)
```ruby
(주석/빈줄 아닌 줄 0개 — 활성 설정 없음)
```
활성 줄 수: 0
주석 처리된 설정 키 목록:
  - Rails.configuration.action_controller.escape_json_responses
  - Rails.configuration.active_support.escape_js_separators_in_json
  - Rails.configuration.active_record.raise_on_missing_required_finder_order_columns
  - Rails.configuration.action_controller.action_on_path_relative_redirect
  - Rails.configuration.action_view.render_tracker
  - Rails.configuration.action_view.remove_hidden_field_autocomplete

## 3. test diff (유일한 코드 변경)
```diff
diff --git a/test/integration/admin_auth_test.rb b/test/integration/admin_auth_test.rb
index 15be593..13b7e37 100644
--- a/test/integration/admin_auth_test.rb
+++ b/test/integration/admin_auth_test.rb
@@ -335,17 +335,28 @@ class AdminStaleSessionTest < ActionController::TestCase
 
   # The boundary is the constant, not a number copied into the test: a change to
   # SESSION_MAX_AGE should move both sides of this assertion together.
+  #
+  # `freeze_time` is load-bearing, not tidiness. `admin_session_live?` compares
+  # `Time.current.to_i - issued_at.to_i > SESSION_MAX_AGE.to_i`, so "exactly at
+  # the limit" is only exact while the clock stands still. Without the freeze,
+  # any wall-clock tick between computing `max.ago` here and reading
+  # `Time.current` inside the request pushes the difference to max + 1 and the
+  # session reads as expired — the assertion then measures how fast the request
+  # was, not where the boundary is. Measured 2026-11-07: racy on BOTH stacks
+  # (8.0.5.1 failed 3/5, 8.1.4.1 failed 4/5); the green baseline run was luck.
   test "the boundary is Admin::BaseController::SESSION_MAX_AGE" do
     max = Admin::BaseController::SESSION_MAX_AGE
 
-    session[:admin_authenticated] = true
-    session[:admin_authenticated_at] = max.ago.to_i
-    get :index
-    assert_response :success, "exactly at the limit is still live"
-
-    session[:admin_authenticated] = true
-    session[:admin_authenticated_at] = (max + 1.second).ago.to_i
-    get :index
-    assert_redirected_to admin_login_path
+    freeze_time do
+      session[:admin_authenticated] = true
+      session[:admin_authenticated_at] = max.ago.to_i
+      get :index
+      assert_response :success, "exactly at the limit is still live"
+
+      session[:admin_authenticated] = true
+      session[:admin_authenticated_at] = (max + 1.second).ago.to_i
+      get :index
+      assert_redirected_to admin_login_path
+    end
   end
 end
```

## 4. Gemfile.lock 버전 변화 요약 (lock 전문 제외)
```
+    action_text-trix 2.1.19
-    actioncable 8.0.5.1
+    actioncable 8.1.4.1
-    actionmailbox 8.0.5.1
+    actionmailbox 8.1.4.1
-    actionmailer 8.0.5.1
+    actionmailer 8.1.4.1
-    actionpack 8.0.5.1
+    actionpack 8.1.4.1
-    actiontext 8.0.5.1
+    actiontext 8.1.4.1
-    actionview 8.0.5.1
+    actionview 8.1.4.1
-    activejob 8.0.5.1
+    activejob 8.1.4.1
-    activemodel 8.0.5.1
+    activemodel 8.1.4.1
-    activerecord 8.0.5.1
+    activerecord 8.1.4.1
-    activestorage 8.0.5.1
+    activestorage 8.1.4.1
-    activesupport 8.0.5.1
+    activesupport 8.1.4.1
-    benchmark 0.5.0
-    crass 1.0.7
+    crass 1.0.8
-    date 3.5.1
+    date 3.6.0
-    io-console 0.9.4
+    io-console 0.9.5
-    loofah 2.25.2
+    loofah 2.25.3
-    minitest 6.0.6
+    minitest 6.1.0
-    net-imap 0.6.7
+    net-imap 0.6.8
-    net-smtp 0.5.1
+    net-smtp 0.5.2
-    nokogiri 1.19.4-aarch64-linux-gnu
-    nokogiri 1.19.4-aarch64-linux-musl
-    nokogiri 1.19.4-arm-linux-gnu
-    nokogiri 1.19.4-arm-linux-musl
-    nokogiri 1.19.4-arm64-darwin
-    nokogiri 1.19.4-x86_64-darwin
-    nokogiri 1.19.4-x86_64-linux-gnu
-    nokogiri 1.19.4-x86_64-linux-musl
+    nokogiri 1.19.7-aarch64-linux-gnu
+    nokogiri 1.19.7-aarch64-linux-musl
+    nokogiri 1.19.7-arm-linux-gnu
+    nokogiri 1.19.7-arm-linux-musl
+    nokogiri 1.19.7-arm64-darwin
+    nokogiri 1.19.7-x86_64-darwin
+    nokogiri 1.19.7-x86_64-linux-gnu
+    nokogiri 1.19.7-x86_64-linux-musl
-    prettyprint 0.2.0
+    prettyprint 0.2.1
-    rack 3.2.7
+    rack 3.2.8
-    rack-test 2.2.0
+    rack-test 2.3.0
-    rails 8.0.5.1
+    rails 8.1.4.1
-    rails-html-sanitizer 1.7.1
+    rails-html-sanitizer 1.7.2
-    railties 8.0.5.1
+    railties 8.1.4.1
-    rdoc 8.0.0
+    rdoc 8.1.0
-    uri 1.1.1
+    uri 1.1.2
```
의도적으로 고정 유지 중인 젬(2026-09-18 보류 판단) — 실측 현재값:
```
    image_processing (1.14.0)
    kamal (2.11.0)
    minitest (6.1.0)
    puma (7.2.0)
    ruby-vips (2.3.0)
    solid_cable (4.0.2)
    solid_cache (1.0.10)
    solid_queue (1.4.0)
```

## 5. bin/rails app:update 판단 (모든 conflict 를 skip = 리포 고유 설정 보존)
skip(덮어쓰지 않음): config/application.rb · config/puma.rb ·
  config/environments/{development,production}.rb · config/initializers/content_security_policy.rb ·
  config/initializers/filter_parameter_logging.rb · bin/rubocop · bin/setup ·
  public/{400,404,406-unsupported-browser,422,500}.html
create 수용: config/initializers/new_framework_defaults_8_1.rb (표준 업그레이드 산출물)
create 거부(저장소 밖 tmp/ 로 이동, 삭제 안 함):
  - db/migrate/20261107150121_add_service_name_to_active_storage_blobs.active_storage.rb
  - db/migrate/20261107150122_create_active_storage_variant_records.active_storage.rb
  - db/migrate/20261107150123_remove_not_null_on_active_storage_blobs_checksum.active_storage.rb
    이유: db/schema.rb 에 이미 존재한다 — active_storage_blobs.service_name (null:false, schema.rb:32),
    active_storage_variant_records 테이블 (schema.rb:39), checksum nullable (schema.rb:34).
    기존 20260324143948_create_active_storage_tables.active_storage.rb 가 통합 형태로 이미 적용했고
    개별 버전은 schema_migrations 에 기록되지 않아 railties:install:migrations 가 다시 복사한 것.
    ~~커밋하면 배포 시 db:migrate 가 PG::DuplicateColumn / PG::DuplicateTable 로 실패한다.~~
    🔴 **정정 (2026-11-07, Codex 교차검증 지적 · 파일을 직접 읽어 확인) — 위 문장은 거짓이었다.**
    세 파일 전부 **가드가 있어 멱등 no-op** 이다: ① `unless column_exists?(:active_storage_blobs,
    :service_name)` ② `create_table :active_storage_variant_records, …, if_not_exists: true`
    ③ `change_column_null(:active_storage_blobs, :checksum, true)` (이미 nullable). 셋 다
    `return unless table_exists?(:active_storage_blobs)` 로도 감싸여 있다. 즉 커밋해도 깨지지 않는다.
    **거부 판단은 유지하되 근거를 바꾼다**: (ⅰ) 이 GO 의 범위는 Gemfile·Gemfile.lock·config/ 이고,
    마이그레이션을 커밋하면 `db/schema.rb` 의 version 까지 20261107150123 으로 올라가 범위를 넘는다.
    (ⅱ) 이 스키마에서는 전부 no-op 이라 커밋해서 얻는 기능적 이득이 0이고, 얻는 것은
    「마이그레이션 이력 수렴」뿐인데 그건 프로덕션 `schema_migrations` 를 건드리는 별도 결정이다.
    (ⅲ) 보안 패치 커밋의 안전한 기본값은 DB 에 대해 아무것도 바꾸지 않는 것이다.
    **교환**: 커밋하지 않으면 다음 `app:update` 가 이 세 파일을 또 복사한다(버전이 기록되지 않으므로).
    그 수렴을 원하면 별도 커밋으로 한다 — 그때는 `schema.rb` 변경이 의도된 diff 가 된다.
  - config/ci.rb + bin/ci (Rails 8.1 신규 CI 러너 스캐폴드)
    이유: 업그레이드에 불필요. 이 리포는 .github/workflows/ci.yml + ~/.claude/ci-policy.md 로
    CI 가 이미 정의돼 있어 두 번째 정의 지점이 생긴다. bin/ 은 이번 GO 범위(config/) 밖.
  - public/icon.svg (8.1 기본 아이콘) — 이 리포는 자체 favicon/OG 세트를 관리한다(브랜드 자산).

## 6. 검증 실측 (전부 docker compose exec web, Rails 8.1.4.1)
bin/rails test        : 전 565 runs/4183 assertions/0F/0E → 후 565/4183/0F/0E  (동일)
bin/rails test:system : 전 0 runs → 후 0 runs (test/system 디렉터리 없음)
DEPRECATION 경고      : 0건 (테스트 출력 전수 grep)
brakeman              : 전 12 → 후 11. EOLRails 1건 소멸, **신규 0건**
                        (잔존 11 = CrossSiteScripting 7 + FileAccess 4, 기준선 그대로)
rubocop               : 86 offenses (기준선과 동일, 신규 0)
zeitwerk:check        : All is good!
assets:precompile     : RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 성공(32파일).
                        public/assets 는 실행 전 ABSENT 였고 실행 후 tmp/ 로 옮겨 원상복구
middleware stack(prod): 3개 구성 전부 8.0.5.1 측정값과 동일
                        ① RAILS_SERVE_STATIC_FILES=true → CanonicalPathRedirect(4) < Static(6)
                        ② 미설정 → 동일
                        ③ public_file_server.enabled=false → CanonicalPathRedirect 최상단(1), Static 없음
canonical_sweep.rb    : 6/6 ALL CHECKS PASSED. sitemap 33, hop {1=>88, 2=>2}

## 7. 확신이 없는 지점 (여기를 봐 주세요)
7-1. minitest: lock 이 6.0.6 → 6.1.0 으로 올라갔다. Gemfile 의 `minitest "< 7"` 상한을 유지했다.
     근거로 railties-8.1.4.1/lib/rails/test_unit/line_filtering.rb 를 직접 읽어
     `case Minitest::VERSION when /^5/ ... when /^6/ ... end` 이고 **else 가 없음**을 확인했다.
     즉 minitest 7 은 LineFiltering 이 안 붙어 줄 필터링이 조용히 죽는다. 이 판단이 맞나?
     상한을 유지하는 것이 옳은가, 아니면 다른 수단이 나은가?
7-2. action_text-trix (2.1.19) 가 **신규 의존**으로 들어왔다. Rails 8.1 이 trix 를 별도 젬으로
     분리한 결과로 보인다. 이 앱은 Action Text 를 쓰지 않는다고 판단했는데(has_rich_text 없음),
     그래도 assets:precompile 이 trix-65afdb1d.css 를 쓴다. 배포 산출물이 커지는 것 외의
     영향이 있나? 제거해야 하나?
7-3. config.load_defaults 를 8.0 에 둔 채 Rails 8.1 을 돌린다. 지시대로이지만,
     8.1 에서 **기본값이 아니라 동작 자체가 제거된** 항목에 걸릴 위험이 남는가?
     테스트 565개와 deprecation 0건으로 충분한 근거인가?
7-4. Active Storage 마이그레이션 3건 거부 판단(위 §5)이 맞나? schema.rb 를 근거로 삼았는데,
     프로덕션 DB 는 접촉하지 않았다. 프로덕션 schema_migrations 가 dev 와 다를 가능성을
     어떻게 확인해야 하나? (배포 전 사람 확인 항목으로 올려야 하나?)
7-5. app:update 가 skip 한 config/environments/production.rb 등에 8.1 이 요구하는 변경이
     실제로 있었는지는 diff 를 보지 않고 일괄 skip 했다. 이게 위험한가?

## 8. 7-2 · 7-5 는 패키지를 쓰다가 스스로 실측해 답했다 (질문 → 근거)

**7-2 (action_text-trix) 답**: 이 앱은 Action Text 를 쓰지 않는다 — `has_rich_text`·
`rich_text_area` 0건, `db/schema.rb` 에 `action_text_rich_texts` 테이블 없음(전수 grep).
`action_text-trix` 는 `actiontext (8.1.4.1)` 의 의존이고 `actiontext` 는 `rails` 메타젬의
구성요소라 피할 수 없다(lock 의존 트리 확인). **8.0 에서도 trix 에셋은 actiontext 젬 안에
들어 있었으므로 precompile 산출물은 달라지지 않는다** — 젬 경계만 옮겨졌다. 제거하려면
`rails` 메타젬을 버리고 컴포넌트를 개별 선언해야 하는데, 그건 업그레이드와 별개의 변경이다.
→ **조치 없음**. 남은 질문: 이 판단에 빠진 것이 있나?

**7-5 (skip 한 config 에 8.1 이 요구하는 변경이 있었나) 답**: 컨테이너 `/tmp` 에
`rails new`(8.1.4.1, 저장소 밖)로 **순정 8.1 앱을 생성해 6개 파일을 전부 diff 했다.**
차이는 전부 리포 고유 설정이었고, 순정 8.1 에만 있고 우리에게 없는 항목은 **셋뿐**이며
전부 필수가 아니다:
  1. `config/environments/development.rb` — `config.action_dispatch.verbose_redirect_logs = true`
     (8.1 신규 **개발 전용 로깅**)
  2. 같은 파일 — `config.assets.quiet = true` (개발 전용 로그 억제)
  3. `config/initializers/content_security_policy.rb` — `content_security_policy_nonce_auto`
     언급이 **주석으로** 추가됨 (활성 설정 아님)
우리 쪽이 의도적으로 다른 대표 항목: `load_defaults 8.0`(지시) · `Docpack` 모듈명 ·
`port 3001` · `plugin :solid_queue if ENV.fetch("SOLID_QUEUE_IN_PUMA","false") == "true"`
(순정은 `if ENV["SOLID_QUEUE_IN_PUMA"]` — 우리 쪽이 더 엄격하고, 2026-04-07 에 이 값이
`false` 문자열이어서 recurring job 이 안 돌던 사고의 수정이다) · solid_cache/solid_queue ·
`assume_ssl`/`force_ssl` 활성 · Gmail SMTP · SafeFile `filter_parameters`.
→ **일괄 skip 은 안전했다**(근거: 위 diff). 1·2 를 넣지 않은 이유는 개발 전용이고
「업그레이드에 필요한 변경」밖이라 diff 를 넓히지 않기 위해서다. 이 판단이 맞나?

## 9. 질문 (7-1 · 7-3 · 7-4 는 그대로 열려 있다)
7-1 minitest `< 7` 상한 유지 판단 · 7-3 load_defaults 8.0 유지 상태로 8.1 구동의 잔여 위험 ·
7-4 Active Storage 마이그레이션 3건 거부를 dev schema.rb 근거로만 판정한 것(프로덕션 DB 미접촉).
