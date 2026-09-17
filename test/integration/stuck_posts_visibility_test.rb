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
