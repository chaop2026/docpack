require "test_helper"

# Q2' — approval and import must not interleave.
#
# `JpApproval#approve!` writes a fingerprint that means "this exact text was
# reviewed". `JpImport#apply!` rewrites that text. Both now take the row lock
# and reload inside it, so the two serialise; the outcome must be one of two
# determinate answers, never "old fingerprint over new body".
#
# Real connections and real commits — under transactional fixtures the second
# thread cannot see the first thread's lock at all.
class JpApprovalLockTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  EP = 93

  setup do
    @topic = BlogTopic.create!(track: "jp", ep: EP, topic: "ロックテスト", category: "privacy",
                               title_en: "Lock test", landing: "nyusatsu",
                               publish_on: next_monday)
    @post = Post.create!(
      content_track: "jp", content_ep: EP, primary_locale: "ja", status: "draft",
      category: "privacy", slug: "jp-ep93-lock-test", title_ja: "ロックテスト",
      body_ja: "<p>もとの本文</p>", body_en: "<p>original</p>",
      published_at: 3.days.from_now,
      package: { "ep" => EP, "track" => "jp", "x_thread" => %w[a b],
                 "linkedin_text" => "li", "guard" => { "violations" => [] },
                 "content_hash" => "original-hash" }
    )
  end

  teardown do
    Post.where(content_track: "jp", content_ep: EP).destroy_all
    BlogTopic.where(track: "jp", ep: EP).destroy_all
  end

  def next_monday
    d = Date.current + 1
    d += 1 until d.wday == 1
    d
  end

  test "approve! computes the fingerprint under the row lock, from the stored row" do
    # The stale-read case, made explicit: hand approve! an in-memory copy whose
    # body is NOT what the database holds. Before S8c the fingerprint would have
    # been taken from this copy.
    stale = Post.find(@post.id)
    Post.where(id: @post.id).update_all(body_ja: "<p>データベース側の本文</p>")

    JpApproval.approve!(stale, topic: @topic)
    @post.reload

    assert_equal JpApproval.version_for(@post), @post.package["approved_version"],
                 "the fingerprint must describe the row, not the caller's copy"
    assert_includes @post.body_ja, "データベース側"
  end

  test "an import holding the lock and a concurrent approval resolve one way or the other" do
    # Thread A: import, holding the row lock while it rewrites the body.
    # Thread B: approve, arriving mid-flight.
    #
    # Whichever order they land in, the invariant is the same: the stored
    # approved_version must match the stored body. The forbidden outcome is a
    # fingerprint over text that is no longer there.
    gate = Queue.new
    release = Queue.new
    errors = []

    importer = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Post.find(@post.id).with_lock do
          Post.where(id: @post.id).update_all(body_ja: "<p>インポートが書いた本文</p>")
          gate << :locked
          release.pop          # hold the lock
        end
      end
    rescue StandardError => e
      errors << "importer: #{e.class}: #{e.message}"
    end

    gate.pop                   # the import is inside the lock
    approver = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        JpApproval.approve!(Post.find(@post.id), topic: BlogTopic.find(@topic.id))
      end
    rescue StandardError => e
      errors << "approver: #{e.class}: #{e.message}"
    end

    sleep 0.1                  # the approver is now blocked on the lock
    assert approver.alive?, "approve! must WAIT for the lock, not read around it"

    release << :go
    [ importer, approver ].each(&:join)
    @post.reload

    assert_empty errors
    assert_includes @post.body_ja, "インポートが書いた", "the import's write stands"
    assert_equal "scheduled", @post.status
    assert_equal JpApproval.version_for(@post), @post.package["approved_version"],
                 "approved_version must match the body that is actually stored"
  end

  test "approving first makes a later import refuse rather than overwrite" do
    JpApproval.approve!(@post, topic: @topic)
    @post.reload
    version = @post.package["approved_version"]
    body = @post.body_ja

    source = Struct.new(:content_hash, :body_ja_html, :title_ja, :subtitle_ja,
                        :meta_description_ja, :title_en, :body_en_html,
                        :meta_description_en, :ep, :topic_row, :landing_path,
                        :x_thread, :x_reply_en, :linkedin_text, :captions, :faq,
                        :utm, :asset_paths, :media_for_first_tweet, :manifest,
                        :hero_path, :fm_ja, :body_ja_markdown, :body_en_markdown).new(
      "a-different-hash", "<p>インポートの新本文</p>", "別タイトル", nil, nil, nil, nil, nil,
      EP, { "intent" => "手順" }, "/safe/jp/nyusatsu/", [], nil, nil, [], [], {}, [], nil, {}, nil,
      {}, "", nil
    )

    assert_equal :conflict, JpImport.apply!(post: @post, source: source, topic: @topic)
    @post.reload
    assert_equal body, @post.body_ja
    assert_equal version, @post.package["approved_version"]
  end
end
