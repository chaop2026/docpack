require "test_helper"

# The JP content track end to end: import, identity, slug, routing, and the
# Korean track's isolation from all of it.
class JpContentTrackTest < ActionDispatch::IntegrationTest
  EP = 1

  def topic_row
    @topic_row ||= JSON.parse(Rails.root.join("content", "jp", "topics.json").read)["episodes"]
                       .find { |e| e["ep"] == EP }
  end

  def source
    JpEpisodeSource.new(dir: Rails.root.join("content", "jp", format("ep%02d", EP)),
                        topic_row: topic_row, ep: EP)
  end

  def import!
    s = source
    s.validate!
    topic = JpImport.upsert_topic!(topic_row)
    post, created = JpImport.find_or_create_post!(ep: EP, source: s)
    JpImport.apply!(post: post, source: s, topic: topic)
    [ post.reload, created, topic ]
  end

  # ── identity and idempotence ────────────────────────────────────────────────

  test "import creates one post and a second import updates it rather than adding another" do
    post, created, = import!
    assert created
    assert_equal 1, Post.where(content_track: "jp", content_ep: EP).count

    assert_no_difference -> { Post.count } do
      _, created_again, = import!
      refute created_again
    end
    assert_equal 1, Post.where(content_track: "jp", content_ep: EP).count
    assert_equal post.id, Post.find_by(content_track: "jp", content_ep: EP).id
  end

  test "the database refuses a second post with the same (track, ep)" do
    # The partial unique index is what makes "published once" true rather than
    # likely — JpImport's rescue has nothing to catch without it.
    #
    # Asserted through `create!`, which is what JpImport actually calls.
    # `Post.insert` would NOT raise here: measured, it compiles to ON CONFLICT
    # DO NOTHING and silently inserts nothing, so a test written against it
    # would be green whether the index existed or not.
    import!
    assert_raises ActiveRecord::RecordNotUnique do
      Post.create!(content_track: "jp", content_ep: EP, primary_locale: "ja", status: "draft",
                   category: "privacy", slug: "another-slug", title_ja: "x", body_ja: "<p>y</p>")
    end
    assert_equal 1, Post.where(content_track: "jp", content_ep: EP).count
  end

  test "losing the find/create race returns the existing row instead of duplicating" do
    # The race JpImport's rescue exists for: the monthly Mac import and the
    # server's weekly fallback reach for the same episode by the same name, and
    # find_or_create_by is read-then-write.
    s = source
    first, created = JpImport.find_or_create_post!(ep: EP, source: s)
    assert created

    # Make the READ miss (as it would if the other process committed between
    # our SELECT and our INSERT) while leaving the write path real. The index
    # turns the lost update into RecordNotUnique; the rescue re-reads.
    # The original must be captured BEFORE the stub replaces it — calling
    # Post.find_by from inside the stub calls the stub (measured: SystemStackError).
    original_find_by = Post.method(:find_by)
    calls = 0
    stub = lambda do |*args|
      calls += 1
      calls == 1 ? nil : original_find_by.call(*args)
    end

    second = nil
    created_again = nil
    Post.stub(:find_by, stub) do
      second, created_again = JpImport.find_or_create_post!(ep: EP, source: s)
    end

    assert_equal first.id, second.id, "the loser must adopt the winner's row"
    refute created_again
    assert_equal 1, Post.where(content_track: "jp", content_ep: EP).count
  end

  test "the Korean track is never offered a Japanese episode" do
    import!
    assert BlogTopic.jp.any?, "the fixture import must have created a jp topic"
    # The scope the KO generator uses, and every rake task that generates KO.
    assert_empty BlogTopic.next_ko.where(track: "jp")
    assert BlogTopic.next_ko.all? { |t| t.track == "ko" }
  end

  test "next_jp ignores `used` and keys on review_sent_at" do
    _, _, topic = import!
    topic.update!(used: true, publish_on: Date.current)
    assert_includes BlogTopic.next_jp, topic, "a `used` jp topic must still be selectable"

    topic.update!(review_sent_at: Time.current)
    refute_includes BlogTopic.next_jp, topic, "a topic already sent for review must not come back"
  end

  # ── slug ────────────────────────────────────────────────────────────────────

  test "slug is assigned once and cannot change afterwards" do
    post, = import!
    original = post.slug
    assert_match(/\Ajp-ep01-/, original)

    post.slug = "something-else"
    refute post.valid?
    assert post.errors[:slug].any?

    post.reload
    assert_equal original, post.slug
  end

  test "generate_slug never runs for a Japanese post" do
    post = Post.new(primary_locale: "ja", status: "draft", category: "privacy",
                    title_ja: "日本語タイトル", body_ja: "<p>x</p>", content_track: "jp", content_ep: 99)
    post.valid?
    # title_ko is nil, so the old callback would have produced a random hex slug
    # and the URL would not be a function of the episode number.
    assert_nil post.slug
  end

  # ── the approved-package freeze ─────────────────────────────────────────────

  test "re-import of an approved package changes nothing and records the conflict" do
    post, _, topic = import!
    post.update!(published_at: 1.day.from_now)
    JpApproval.approve!(post, topic: topic)
    post.reload

    before = post.slice(:title_ja, :body_ja, :body_en, :status).merge("pkg" => post.package)

    # What the rake task does when the freeze holds.
    refute(post.status == "draft" && post.package["approved_at"].blank?,
           "the guard condition must be false for an approved package")
    JpImport.record_conflict!(post, source)
    post.reload

    assert_equal before["title_ja"], post.title_ja
    assert_equal before["body_ja"], post.body_ja
    assert_equal "scheduled", post.status
    assert_equal before["pkg"]["approved_version"], post.package["approved_version"]
    assert post.import_conflict.present?
    assert_equal source.content_hash, post.import_conflict["content_hash"]
  end

  test "import never overwrites the keys that record what was published" do
    post, _, topic = import!
    post.update!(published_at: 1.day.from_now)
    JpApproval.approve!(post, topic: topic)
    post.reload
    # Pretend the thread went out.
    post.update_column(:package, post.package.deep_merge(
      "x" => { "state" => "done", "tweets" => [ { "seq" => 1, "tweet_id" => "123" } ] },
      "posted" => { "x" => true, "linkedin_url" => "https://linkedin.example/p/1" }
    ))
    post.reload

    merged = JpImport.merged_package(post, source, topic, { "violations" => [] })

    assert_equal "done", merged.dig("x", "state"), "the X delivery record must survive an import"
    assert_equal "123", merged.dig("x", "tweets", 0, "tweet_id"),
                 "tweet ids are the only proof a thread was already posted"
    assert_equal true, merged.dig("posted", "x")
    assert_equal "https://linkedin.example/p/1", merged.dig("posted", "linkedin_url")
    assert merged["approved_at"].present?
    assert merged["approved_version"].present?
  end

  test "a successful import clears a previous conflict record" do
    post, _, topic = import!
    JpImport.record_conflict!(post, source)
    assert post.reload.import_conflict.present?

    JpImport.apply!(post: post, source: source, topic: topic)
    assert_nil post.reload.import_conflict
  end

  # ── routing ─────────────────────────────────────────────────────────────────

  test "the bare /blog/:slug 301s to /ja for a Japanese post" do
    post, = import!
    post.update!(status: "published", published_at: 1.hour.ago)

    get "/blog/#{post.slug}"
    assert_response :moved_permanently
    assert_equal "/ja/blog/#{post.slug}", response.headers["Location"].sub(%r{\Ahttps?://[^/]+}, "")
  end

  test "the bare /blog/:slug does NOT redirect for a Korean post" do
    get "/blog/#{posts(:korean_only).slug}"
    assert_response :success
  end

  test "a published Japanese post self-canonicalises at /ja and advertises ja + en" do
    post, = import!
    post.update!(status: "published", published_at: 1.hour.ago)

    get "/ja/blog/#{post.slug}"
    assert_response :success
    assert_includes response.body, %(<link rel="canonical" href="https://slimfile.net/ja/blog/#{post.slug}">)
    assert_includes response.body, %(hreflang="x-default" href="https://slimfile.net/ja/blog/#{post.slug}")
    refute_includes response.body, %(<meta name="robots")
    assert_includes response.body, %("inLanguage": "ja")
    assert_includes response.body, post.title_ja
  end

  test "a locale with no translation is noindex and canonicalises at the Japanese original" do
    post, = import!
    post.update!(status: "published", published_at: 1.hour.ago)

    get "/es/blog/#{post.slug}"
    assert_response :success
    assert_includes response.body, %(<meta name="robots" content="noindex,follow">)
    assert_includes response.body, %(<link rel="canonical" href="https://slimfile.net/ja/blog/#{post.slug}">)
  end

  test "a draft Japanese post is previewable, noindex, and advertises no alternates" do
    post, = import!
    assert_equal "draft", post.status

    get "/ja/blog/#{post.slug}"
    assert_response :success
    assert_includes response.body, %(<meta name="robots" content="noindex,follow">)
    assert_equal [], post.indexable_locales
    refute_includes response.body, %(<link rel="alternate" hreflang=)
  end

  test "/ja/blog lists only Japanese posts and /blog lists only Korean ones" do
    post, = import!
    post.update!(status: "published", published_at: 1.hour.ago)

    get "/ja/blog"
    assert_response :success
    assert_includes response.body, post.slug

    get "/blog"
    assert_response :success
    refute_includes response.body, post.slug
    assert_includes response.body, posts(:korean_only).slug
  end

  test "the sitemap lists the Japanese post at /ja and x-defaults to it" do
    post, = import!
    post.update!(status: "published", published_at: 1.hour.ago)

    get "/sitemap.xml"
    assert_response :success
    assert_includes response.body, "<loc>https://slimfile.net/ja/blog/#{post.slug}</loc>"
    assert_includes response.body,
                    %(<xhtml:link rel="alternate" hreflang="x-default" href="https://slimfile.net/ja/blog/#{post.slug}"/>)
    refute_includes response.body, "<loc>https://slimfile.net/blog/#{post.slug}</loc>"
  end

  test "FAQPage is emitted only when the package actually carries an FAQ" do
    post, = import!
    post.update!(status: "published", published_at: 1.hour.ago)

    get "/ja/blog/#{post.slug}"
    # Compact JSON now (built as a Hash and serialised with to_json), so no
            # space after the colon — the old pretty-printed spelling would pass
            # only by accident of how the block was assembled.
    assert_includes response.body, '"@type":"FAQPage"'

    post.update_column(:package, post.package.merge("faq" => []))
    get "/ja/blog/#{post.slug}"
    refute_includes response.body, "FAQPage",
                    "an empty FAQPage announces a section the document does not have"
  end

  # ── the publish invariant ───────────────────────────────────────────────────

  test "a published Japanese post needs a Japanese title and body, not Korean ones" do
    post = Post.new(primary_locale: "ja", status: "published", category: "privacy",
                    slug: "jp-ep99-x", content_track: "jp", content_ep: 99)
    refute post.valid?
    assert post.errors[:title_ja].any?
    assert post.errors[:body_ja].any?
    assert_empty post.errors[:body_ko], "a Japanese post must not be asked for Korean text"

    post.title_ja = "タイトル"
    post.body_ja = "<p>本文</p>"
    assert post.valid?, post.errors.full_messages.inspect
  end

  test "the Korean invariant and its error message are unchanged" do
    # Pinned to :ko, because the string under test is locale-dependent and this
    # ran in a parallel suite where a sibling had left I18n.locale set.
    # Measured: under :en the same failure renders
    # 「본문(한국어) 을(를) 입력해 주세요」 — Rails' default "%{attribute} %{message}"
    # format, with a space, instead of ko.yml's space-less one (Korean
    # particles attach to the noun). That is pre-existing behaviour, not
    # something S8 changed, but an assertion that depends on ambient state is
    # flaky in exactly the way that gets a real regression dismissed as noise.
    #
    # :ko is the locale the two readers of this string actually run under: the
    # admin form and PublishScheduledPostsJob's failure email.
    I18n.with_locale(:ko) do
      post = posts(:korean_only)
      post.body_ko = ""
      refute post.valid?
      # Byte-identical to the pre-S8 message.
      assert_includes post.errors.full_messages, "본문(한국어)을(를) 입력해 주세요"
    end
  end
end
