# The JP weekly job. Saturday 00:00 KST (config/recurring.yml).
#
# One episode per run: pick the next JP topic that has not been sent for review,
# find the draft Post that content:jp_import registered from the Mac, set its
# publish time, and mail Justin one review request. He opens
# /admin/jp/packages/:ep over the weekend and presses 承認 once; that schedules
# the blog post AND arms the X thread.
#
# ── Two paths, and they fail differently ───────────────────────────────────
#
# (a) THE DRAFT EXISTS — the normal case. Everything here is a database write,
#     so a transient DB error is worth retrying: replaying it re-sends nothing
#     (the 7-day guard below) and re-creates nothing.
#
# (b) NO DRAFT — the monthly batch did not run, or ran short. BlogGeneratorService
#     writes a text-only package (no carousel, no GIF; hero falls back to
#     cover_svg) so the slot does not silently go empty. This path is NOT
#     retried: it calls a paid API before it writes anything, so a replay pays
#     twice for one article. Cross-review Q2 asked for the generated result to be
#     reusable instead — it is saved to tmp/jp_generated/epNN.json BEFORE the row
#     is touched, and a later run picks the file up rather than regenerating.
class AutoGenerateJpPostJob < ApplicationJob
  queue_as :default

  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3
  retry_on ActiveRecord::ConnectionNotEstablished, wait: :polynomially_longer, attempts: 3

  # One review mail per episode per week.
  #
  # ── What this guard does and does not cover ────────────────────────────────
  #
  # BlogTopic.next_jp already excludes any topic with a review_sent_at, so an
  # episode selected the normal way has never been mailed and this check cannot
  # fire. It is not dead, but its reachable paths are narrow and worth naming
  # rather than implying: a manual `AutoGenerateJpPostJob.perform_now` after
  # someone cleared review_sent_at to re-send, and any future widening of
  # next_jp. Measured — a test that set review_sent_at and expected a second
  # mail got zero, because the scope had already removed the topic.
  #
  # The queue deliberately ADVANCES rather than nags: if ep05 is never approved,
  # the next Saturday offers ep06. One un-acted-on episode must not block the
  # publication schedule behind it. What that trades away is visibility of the
  # skipped episode, and that is covered by STATE instead of by mail —
  # Post.jp_unapproved_overdue, surfaced on /admin/posts and `rake blog:stuck`.
  # Same split as publish_stuck: the channel that reports a failure must not be
  # the channel that failed.
  REVIEW_INTERVAL = 7.days

  def perform
    topic = BlogTopic.next_jp.first
    unless topic
      log("no JP topic is due within 9 days — nothing to do")
      return
    end

    post = Post.find_by(content_track: "jp", content_ep: topic.ep)
    post = generate_fallback(topic) if post.nil?
    return if post.nil?

    schedule(post, topic)

    if topic.review_sent_at.present? && topic.review_sent_at > REVIEW_INTERVAL.ago
      log("ep#{topic.ep}: a review request already went out #{topic.review_sent_at} — not sending another")
      return
    end

    BlogMailer.jp_review_requested(post.id).deliver_later
    topic.update!(review_sent_at: Time.current)
    log("ep#{topic.ep}: review request enqueued for '#{post.slug}' " \
        "(publish #{post.published_at&.iso8601 || 'NOT SET — awaiting verification'})")
  end

  private

  # published_at is what approval freezes, so it is set BEFORE the mail goes out
  # — the mail quotes it, and a mail that quotes a time the row does not hold is
  # worse than no mail.
  #
  # Except when the topic is awaiting verification (ep30 cites a rule not yet in
  # force, ep32 a feature that has not shipped). Then the time is deliberately
  # left NULL: JpApproval refuses to approve without one, so the package cannot
  # be scheduled by accident while its facts are unconfirmed. The mail says so.
  def schedule(post, topic)
    if topic.awaiting_verification?
      log("ep#{topic.ep}: verify_before is set and verified_at is nil — published_at left unset")
      return
    end

    post.update!(published_at: publish_time(topic))
  end

  # 09:00 JST on the topic's Monday. If that Monday has already gone by (a run
  # that was skipped, a backlog), the next Monday — never a time in the past,
  # because PublishScheduledPostsJob would then publish it at the next 09:00 KST
  # sweep without anyone having approved it for that day.
  def publish_time(topic)
    Time.use_zone("Asia/Tokyo") do
      t = Time.zone.local(topic.publish_on.year, topic.publish_on.month, topic.publish_on.day, 9, 0, 0)
      t += 7.days while t < Time.current
      t
    end
  end

  # Where a generation is parked before the row is written, so a failed write
  # does not mean paying the API twice.
  #
  # A class_attribute rather than a constant because the tests need to point it
  # somewhere per-process: `bin/rails test` runs across 8 processes, and two
  # tests sharing one real path meant a file written by the "reuse the saved
  # generation" test made the "generate from scratch" test skip its API call
  # entirely — green when run alone, an error in parallel. Overriding an
  # environment-shaped path is a seam; reaching into the filesystem and hoping
  # the ordering holds is not.
  class_attribute :save_dir, default: Rails.root.join("tmp", "jp_generated")

  def generate_fallback(topic)
    saved = saved_generation(topic)
    if saved
      log("ep#{topic.ep}: reusing the saved generation at #{save_path(topic)} — not calling the API again")
    else
      log("ep#{topic.ep}: no imported draft — generating text only (アセット未生成)")
      saved = BlogGeneratorService.new.generate_jp(topic)
      unless saved
        Rails.logger.error("AutoGenerateJpPostJob: ep#{topic.ep} generation failed (check ANTHROPIC_API_KEY)")
        return nil
      end
      # Saved BEFORE the row is created. If the create fails — a unique
      # collision with a concurrent import, a validation — a later run reuses
      # this file instead of paying for the article a second time.
      persist_generation(topic, saved)
    end

    post, _created = create_from_generation(topic, saved)
    post
  end

  def create_from_generation(topic, data)
    existing = Post.find_by(content_track: "jp", content_ep: topic.ep)
    return [ existing, false ] if existing

    post = Post.new(
      content_track: "jp",
      content_ep: topic.ep,
      primary_locale: "ja",
      status: "draft",
      category: "privacy",
      slug: fallback_slug(topic),
      title_ja: data["title_ja"],
      subtitle_ja: data["subtitle_ja"],
      body_ja: data["body_ja"],
      meta_description_ja: data["meta_description_ja"],
      body_en: data["body_en"],
      cover_svg: data["cover_svg"],
      package: fallback_package(topic, data)
    )
    post.save!
    [ post, true ]
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # Both, for the reason JpImport#find_or_create_post! documents: the slug
    # uniqueness VALIDATION rejects the loser before the index ever sees it, so
    # RecordInvalid is the shape this race actually takes.
    #
    # The import landed between the find and the save. Its package is richer
    # (real carousel, real GIF), so the imported row wins and the generated text
    # is left in tmp/ for inspection. Re-raise if no row exists — then the
    # record was rejected for a content reason, not a race.
    found = Post.find_by(content_track: "jp", content_ep: topic.ep)
    raise if found.nil?

    log("ep#{topic.ep}: an import created the row concurrently — using it and discarding the generated text")
    [ found, false ]
  end

  def fallback_package(topic, data)
    guard = JpContentGuard.new(
      surfaces: {
        "generated body_ja" => data["body_ja"].to_s,
        "generated body_en" => data["body_en"].to_s,
        "generated x_thread" => Array(data["x_thread"]).join("\n")
      },
      article_ja: data["body_ja"],
      article_en: data["body_en"],
      title: data["title_ja"],
      tweets: Array(data["x_thread"]),
      linkedin_text: data["linkedin_text"],
      faq: Array(data["faq"])
    ).result

    {
      "ep" => topic.ep,
      "track" => "jp",
      "assets_missing" => true,
      "x_thread" => Array(data["x_thread"]),
      "linkedin_text" => data["linkedin_text"],
      "faq" => Array(data["faq"]),
      "landing_path" => JpEpisodeSource::LANDING_PATH.fetch(topic.landing, "/safe/jp/nyusatsu/"),
      "guard" => guard,
      "generated_at" => Time.current.iso8601
    }
  end

  def fallback_slug(topic)
    base = topic.title_en.to_s.parameterize.first(40).sub(/-\z/, "")
    base = "ep#{format('%02d', topic.ep)}" if base.blank?
    "jp-ep#{format('%02d', topic.ep)}-#{base}"
  end

  def save_path(topic)
    Pathname(self.class.save_dir).join("ep#{format('%02d', topic.ep)}.json")
  end

  def saved_generation(topic)
    p = save_path(topic)
    return nil unless p.exist?

    JSON.parse(p.read)
  rescue JSON::ParserError => e
    Rails.logger.error("AutoGenerateJpPostJob: #{p} is unreadable (#{e.message}) — regenerating")
    nil
  end

  def persist_generation(topic, data)
    p = save_path(topic)
    FileUtils.mkdir_p(p.dirname)
    p.write(JSON.pretty_generate(data))
  rescue StandardError => e
    # Best effort. Losing the cache costs money on a retry; failing the run
    # because of it costs the week's article.
    Rails.logger.error("AutoGenerateJpPostJob: could not save the generation for ep#{topic.ep} — #{e.message}")
  end

  def log(message)
    Rails.logger.info("AutoGenerateJpPostJob: #{message}")
  end
end
