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

    # The SERVICE refuses, not the caller. Called directly with no pre-check in
    # front of it, which is the arrangement cross-review Q2 asked for.
    assert_equal :conflict, JpImport.apply!(post: post, source: source, topic: topic)
    post.reload

    assert_equal before["title_ja"], post.title_ja
    assert_equal before["body_ja"], post.body_ja
    assert_equal "scheduled", post.status
    assert_equal before["pkg"]["approved_version"], post.package["approved_version"]
    assert post.import_conflict.present?
    assert_equal source.content_hash, post.import_conflict["content_hash"]
  end

  test "a DIFFERENT body cannot be written into an approved package" do
    # The previous test's source happens to match what is already stored. This
    # one makes the disk genuinely different, so "nothing changed" cannot be
    # true by coincidence.
    post, _, topic = import!
    post.update!(published_at: 1.day.from_now)
    JpApproval.approve!(post, topic: topic)
    post.reload
    before_body = post.body_ja
    before_version = post.package["approved_version"]
    before_assets = post.package_assets.map { |a| a.filename.to_s }.sort

    other = source
    other.define_singleton_method(:body_ja_html) { "<p>まったく違う本文</p>" }
    other.define_singleton_method(:title_ja) { "差し替えられたタイトル" }
    other.define_singleton_method(:content_hash) { "deadbeef" * 8 }

    assert_equal :conflict, JpImport.apply!(post: post, source: other, topic: topic)
    post.reload

    assert_equal before_body, post.body_ja, "an approved body must not be replaced"
    refute_equal "差し替えられたタイトル", post.title_ja
    assert_equal before_version, post.package["approved_version"]
    assert_equal before_assets, post.package_assets.map { |a| a.filename.to_s }.sort
    assert_equal "deadbeef" * 8, post.import_conflict["content_hash"],
                 "the conflict record names the version that was refused"
  end

  test "an approval landing after the caller's check still blocks the write" do
    # The window cross-review Q2 named: the rake task reads `status == draft`,
    # the human presses 承認 a moment later, and the import overwrites an
    # approved package. Reproduced by doing the caller's check first, then
    # approving, then calling the service — which is exactly that ordering.
    post, _, topic = import!
    post.update!(published_at: 1.day.from_now)

    assert JpImport.writable?(post), "the caller's check passes at this instant"

    JpApproval.approve!(post, topic: topic)     # ← the race
    body_before = post.reload.body_ja

    other = source
    other.define_singleton_method(:body_ja_html) { "<p>レースで入った本文</p>" }
    other.define_singleton_method(:content_hash) { "f" * 64 }

    assert_equal :conflict, JpImport.apply!(post: post, source: other, topic: topic),
                 "the service must re-check under the lock, not trust the caller"
    assert_equal body_before, post.reload.body_ja
  end

  test "an unchanged import writes nothing at all — not even updated_at" do
    post, = import!
    post.reload
    before = { updated_at: post.updated_at, package: post.package.deep_dup }
    asset_ids = post.package_assets.map(&:id).sort
    hero_id = post.hero_image.attachment&.id

    topic = BlogTopic.find_by(track: "jp", ep: EP)
    assert_equal :unchanged, JpImport.apply!(post: post, source: source, topic: topic)
    post.reload

    assert_equal before[:updated_at].to_f, post.updated_at.to_f,
                 "updated_at must not move — it would lie about when the content last changed"
    assert_equal before[:package], post.package
    assert_equal asset_ids, post.package_assets.map(&:id).sort,
                 "Active Storage blobs must not be churned by a no-op import"
    assert_equal hero_id, post.hero_image.attachment&.id
  end

  test "a changed guard verdict re-imports even when the episode files did not move" do
    # `unchanged?` folds in the guard result on purpose: the rules live in a
    # file the episode folder does not contain, so a tightened guard_rules.json
    # has to be able to re-mark a package as violating.
    post, _, topic = import!
    post.update_column(:package, post.package.merge(
      "guard" => { "violations" => [ "stale verdict from an older rule set" ] }
    ))
    post.reload

    assert_equal :applied, JpImport.apply!(post: post, source: source, topic: topic)
    assert_empty post.reload.guard_violations
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

    # Not :unchanged — `unchanged?` treats a recorded conflict as a reason to
    # write, precisely so the stale conflict gets cleared instead of pinning
    # the admin banner forever.
    assert_equal :applied, JpImport.apply!(post: post, source: source, topic: topic)
    assert_nil post.reload.import_conflict
  end

  # ── what the rescue may and may not swallow (cross-review Q2) ───────────────

  test "a RecordInvalid on slug :blank is re-raised — only :taken means we lost a race" do
    # The sharpest case: the error is on the SAME attribute the rescue cares
    # about, with a different error type. A rescue that keyed on the attribute
    # alone — or, as the old one did, on "a row exists" — would swallow this
    # and report a successful import of a post that was never created.
    #
    # (A blank title_ja cannot be used here: a JP post is created as a draft,
    # and the published-post invariant does not apply to drafts, so it saves
    # fine. That is the hole cross-review Q2 named and JpEpisodeSource#validate!
    # now closes at the import boundary — see the validate! tests below.)
    existing, = JpImport.find_or_create_post!(ep: EP, source: source)
    assert existing.persisted?

    s = source
    s.define_singleton_method(:slug) { "" }

    err = assert_raises(ActiveRecord::RecordInvalid) do
      JpImport.find_or_create_post!(ep: 91, source: s)
    end
    assert_equal [ :slug ], err.record.errors.details.keys
    assert_equal :blank, err.record.errors.details[:slug].first[:error],
                 "a blank slug is a content error, not a lost race"
    assert_nil Post.find_by(content_track: "jp", content_ep: 91),
               "nothing may be created, and nothing may be adopted"
  end

  test "a slug collision IS swallowed, and only when the winner's row exists" do
    first, created = JpImport.find_or_create_post!(ep: EP, source: source)
    assert created

    original_find_by = Post.method(:find_by)
    calls = 0
    Post.stub(:find_by, ->(*args) { (calls += 1) == 1 ? nil : original_find_by.call(*args) }) do
      found, created_again = JpImport.find_or_create_post!(ep: EP, source: source)
      assert_equal first.id, found.id
      refute created_again
    end
  end

  # ── input validation: "there is no package here" vs "it breaks a rule" ──────

  test "a blank resolved title_ja is refused by validate!" do
    s = source
    s.define_singleton_method(:title_ja) { "" }
    err = assert_raises(JpEpisodeSource::InvalidEpisode) { s.validate! }
    assert_match(/blank title_ja/, err.message)
  end

  test "a body that renders to no prose is refused by validate!" do
    s = source
    s.define_singleton_method(:body_ja_html) { "<p></p>\n<table></table>" }
    err = assert_raises(JpEpisodeSource::InvalidEpisode) { s.validate! }
    assert_match(/no prose/, err.message)
  end

  test "an empty x_thread is refused by validate!" do
    s = source
    s.define_singleton_method(:x_thread) { [] }
    err = assert_raises(JpEpisodeSource::InvalidEpisode) { s.validate! }
    assert_match(/no tweets/, err.message)
  end

  test "a guard violation is NOT a validation failure — it imports and disables approval" do
    # The two answers have to stay distinguishable: exit 1 means "there is no
    # package", exit 0 + violations means "there is a package and it breaks a
    # writing rule".
    post, _, topic = import!
    post.update_column(:package, post.package.merge("guard" => { "violations" => [ "x" ] }))
    post.reload

    assert_nothing_raised { source.validate! }
    assert post.guard_violations.any?
    refute post.approvable?(topic), "approval is disabled"
    assert_equal "draft", post.status, "but the package is imported and present"
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
    # space after the colon — the old pretty-printed spelling would pass only by
    # accident of how the block was assembled.
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
