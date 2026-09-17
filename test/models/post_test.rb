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
end
