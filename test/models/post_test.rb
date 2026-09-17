# frozen_string_literal: true

require "test_helper"

class PostTest < ActiveSupport::TestCase
  # The invariant: a published post always has a Korean body.
  #
  # Korean is the default locale, so /blog/:slug is the address every other
  # locale canonicalises to and the one x-default points at. A published post
  # with body_en but no body_ko makes that address real but not indexable —
  # indexable_locales comes back [:en] while x-default still aims at the Korean
  # URL, which is noindex. Reproduced before the validation was written.
  test "a published post requires a Korean body" do
    post = Post.new(title_ko: "영어만", title_en: "English only",
                    body_ko: nil, body_en: "<p>EN</p>",
                    slug: "en-only", category: "global",
                    status: "published", published_at: Time.current)
    assert_not post.valid?
    # Asserting the attribute, not the message: config/locales/ko.yml carries no
    # activerecord.errors block, so under the default locale the message comes
    # back as "Translation missing…". That is a real gap in the admin forms and
    # is noted separately; it must not make this test brittle.
    assert_includes post.errors.attribute_names, :body_ko
  end

  test "drafts and scheduled posts may still be empty" do
    # A post is created blank and filled in; the gate belongs at publication.
    %w[draft scheduled].each do |status|
      post = Post.new(title_ko: "초안", slug: "d-#{status}", category: "global", status: status)
      assert post.valid?, "#{status}: #{post.errors.full_messages}"
    end
  end

  test "publishing an empty post fails loudly rather than silently" do
    post = Post.create!(title_ko: "초안", slug: "to-publish", category: "global", status: "draft")
    assert_raises(ActiveRecord::RecordInvalid) { post.publish! }
  end

  test "indexable? requires publication and a body in that locale" do
    ko = posts(:korean_only)
    assert ko.indexable?(:ko)
    assert_not ko.indexable?(:en)
    assert_not ko.indexable?(:ja)

    both = posts(:bilingual)
    assert both.indexable?(:ko)
    assert both.indexable?(:en)

    assert_not posts(:draft_post).indexable?(:ko)
    assert_not posts(:scheduled_post).indexable?(:ko)
  end

  test "indexable_locales is empty for anything unpublished" do
    assert_equal [ :ko ], posts(:korean_only).indexable_locales
    assert_equal [ :ko, :en ], posts(:bilingual).indexable_locales
    assert_empty posts(:draft_post).indexable_locales
    assert_empty posts(:scheduled_post).indexable_locales
  end

  test "the localized readers require an explicit locale" do
    # No default: the default used to be I18n.locale, and that is the bug.
    post = posts(:bilingual)
    assert_raises(ArgumentError) { post.title }
    assert_raises(ArgumentError) { post.body }
    assert_raises(ArgumentError) { post.meta_description }
  end

  test "the localized readers follow the locale they are given" do
    post = posts(:bilingual)
    assert_equal "번역된 글", post.title(:ko)
    assert_equal "Translated post", post.title(:en)
    # ja/es have no columns and fall back to English, then Korean.
    assert_equal "Translated post", post.title(:ja)
    assert_equal "한국어 본문입니다.", post.body(:ko).strip.delete("<p>/")
  end

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
