# Turns a JpEpisodeSource into a Post row. Called by `rake content:jp_import`
# and by AutoGenerateJpPostJob's fallback path, which is why it lives here and
# not inside the rake file.
module JpImport
  extend self

  TRACK = "jp".freeze

  # Find-or-create on (content_track, content_ep), atomically.
  #
  # ── Why the rescue is the point ────────────────────────────────────────────
  #
  # Two things reach for the same episode by the same name: the monthly import
  # on the Mac and the server's weekly fallback generator. `find_or_create_by!`
  # is read-then-write and loses that race; the partial unique index added in
  # 20261025000001 turns the loser into a RecordNotUnique instead of a second
  # row. Catching it and re-reading is what makes "the approved package is
  # published once" true rather than likely (cross-review Q2) — without the
  # index there is nothing to catch, and without the rescue the index turns a
  # race into a crash.
  def find_or_create_post!(ep:, source:)
    existing = Post.find_by(content_track: TRACK, content_ep: ep)
    return [ existing, false ] if existing

    post = Post.new(
      content_track: TRACK,
      content_ep: ep,
      primary_locale: "ja",
      status: "draft",
      category: "privacy",
      # Assigned exactly once, here. Post validates that it never changes again:
      # a published JP URL is an address other people have linked, and this repo
      # already carries two permanent redirects from a previous rename.
      slug: source.slug,
      title_ja: source.title_ja,
      body_ja: source.body_ja_html
    )
    post.save!
    [ post, true ]
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # BOTH, and the second one is the common case — measured. `validates :slug,
    # uniqueness: true` runs a SELECT before the INSERT, so the loser of the
    # race is rejected by the VALIDATION (RecordInvalid) and never reaches the
    # index at all. A rescue for RecordNotUnique alone therefore catches
    # nothing: the first version of this method had exactly that hole, and a
    # test that stubbed the read miss turned it into an unhandled
    # RecordInvalid.
    #
    # Both processes derive the same slug from the same episode, so a collision
    # here means the other one got there first. Re-read and adopt its row — but
    # only if that row actually exists. If it does not, the record was rejected
    # for some other reason (an empty body, a bad category) and swallowing it
    # would turn a content error into a silent no-op.
    found = Post.find_by(content_track: TRACK, content_ep: ep)
    raise if found.nil?

    [ found, false ]
  end

  # Everything the files own, written in one transaction. Keys the import must
  # never touch are merged around rather than replaced — see
  # content.rake's IMPORT_NEVER_WRITES for why each one is excluded.
  def apply!(post:, source:, topic:)
    guard = build_guard(source).result

    Post.transaction do
      post.update!(
        title_ja: source.title_ja,
        subtitle_ja: source.subtitle_ja,
        body_ja: source.body_ja_html,
        meta_description_ja: source.meta_description_ja,
        title_en: source.title_en,
        body_en: source.body_en_html,
        meta_description_en: source.meta_description_en,
        category: "privacy",
        package: merged_package(post, source, topic, guard)
      )
      attach_assets!(post, source)
    end
    post
  end

  # package, key by key. `post.package.merge(...)` and not a replacement: `x`,
  # `posted`, `approved_at` and `approved_version` describe things that happened
  # outside this folder (a tweet that exists, a decision a person made) and the
  # files on disk cannot know them. Overwriting `x` in particular would discard
  # the tweet ids that are the only proof a thread was already posted — the next
  # XPublishJob run would post it a second time.
  def merged_package(post, source, topic, guard)
    post.package.merge(
      "ep" => source.ep,
      "track" => TRACK,
      "content_hash" => source.content_hash,
      # From topics.json, not from the topic row: `intent` (手順|理由|比較) is a
      # property of the plan, and blog_topics has no column for it.
      "intent" => source.topic_row["intent"],
      "landing_path" => source.landing_path,
      "x_thread" => source.x_thread,
      "x_reply_en" => source.x_reply_en,
      "linkedin_text" => source.linkedin_text,
      "captions" => source.captions,
      "faq" => source.faq,
      "utm" => source.utm,
      "assets" => source.asset_paths.map { |p| { "name" => p.basename.to_s, "bytes" => p.size } },
      "media_for_first_tweet" => source.media_for_first_tweet&.basename&.to_s,
      "demo" => source.manifest["demo"],
      "guard" => guard,
      "imported_at" => Time.current.iso8601
    ).except("import_conflict") # a successful import resolves the last conflict
  end

  # Named surfaces, so a violation says which file it is in. The thread is read
  # from the generated file and the LinkedIn text from the assembled string —
  # both are surfaces a reader will actually see, and both were unchecked before
  # S8.
  def build_guard(source)
    JpContentGuard.new(
      surfaces: {
        "post_ja.md (frontmatter)" => [ source.fm_ja["title"], source.fm_ja["hook"],
                                        source.fm_ja["cta"], *Array(source.fm_ja["bullets"]),
                                        *source.captions ].compact.join("\n"),
        "post_ja.md (body)" => source.body_ja_markdown,
        "post_en.md" => source.body_en_markdown.to_s,
        "x_thread.md (generated)" => source.x_thread.join("\n"),
        "faq_ja.md" => source.faq.map { |e| "#{e['q']}\n#{e['a']}" }.join("\n"),
        "linkedin_text (assembled)" => source.linkedin_text.to_s
      },
      article_ja: [ source.fm_ja["title"], source.fm_ja["hook"], source.body_ja_markdown,
                    source.faq.map { |e| "#{e['q']}\n#{e['a']}" }.join("\n") ].compact.join("\n"),
      article_en: source.body_en_markdown,
      title: source.title_ja,
      # The array XPublishJob will actually post — the JA thread PLUS the
      # English reply. Checking only `x_thread` left the reply unguarded, and it
      # is a tweet like any other: the admin preview showed it over the
      # editorial limit while the import reported the package clean. A guard
      # whose corpus is narrower than the thing being published is the same
      # defect as the 2026-10-22 one, in a new place.
      tweets: [ *source.x_thread, source.x_reply_en ].compact_blank,
      linkedin_text: source.linkedin_text,
      faq: source.faq
    )
  end

  # Re-attached every import so a rebuilt carousel reaches the preview. Purged
  # first because Active Storage would otherwise accumulate one blob per import
  # and the admin page would show six carousel_1s.
  def attach_assets!(post, source)
    if (hero = source.hero_path)
      post.hero_image.purge if post.hero_image.attached?
      post.hero_image.attach(io: hero.open, filename: hero.basename.to_s, content_type: "image/png")
    end

    post.package_assets.purge if post.package_assets.attached?
    source.asset_paths.each do |p|
      post.package_assets.attach(io: p.open, filename: p.basename.to_s, content_type: content_type_for(p))
    end
  end

  def content_type_for(path)
    case path.extname.downcase
    when ".png" then "image/png"
    when ".gif" then "image/gif"
    when ".mp4" then "video/mp4"
    when ".jpg", ".jpeg" then "image/jpeg"
    else "application/octet-stream"
    end
  end

  # The refusal record. Written with update_column-style narrowness — a merge
  # into `package` and nothing else — because the whole point of code 2 is that
  # the post's content did NOT change. The hash says which version on disk was
  # refused, so the admin page can say more than "something is out of date".
  def record_conflict!(post, source)
    post.update_column(
      :package,
      post.package.merge(
        "import_conflict" => {
          "at" => Time.current.iso8601,
          "content_hash" => source.content_hash
        }
      )
    )
  end

  # Mirrors one topics.json row into blog_topics. Upsert on (track, ep), which
  # the database makes unique.
  #
  # `used` is deliberately NOT set. For the Korean track it means "an article
  # has been generated from this topic" and the generator keys on it; for JP
  # every imported episode would be `used` from the moment it existed, and
  # BlogTopic.next_jp would then skip exactly the episodes that are ready. JP
  # selection keys on review_sent_at instead.
  def upsert_topic!(row)
    topic = BlogTopic.find_or_initialize_by(track: TRACK, ep: row["ep"])
    topic.assign_attributes(
      topic: row["blog_title_ja"].presence || row["title_ja"],
      category: "privacy",
      title_en: row["title_en"],
      doc: row["doc"],
      purpose: row["purpose"],
      landing: row["landing"],
      publish_on: row["publish_on"],
      verify_before: !!row["verify_before"],
      social_skip: !!row["social_skip"]
    )
    topic.save!
    topic
  rescue ActiveRecord::RecordNotUnique
    BlogTopic.find_by!(track: TRACK, ep: row["ep"])
  end
end
