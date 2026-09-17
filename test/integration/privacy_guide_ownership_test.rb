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
