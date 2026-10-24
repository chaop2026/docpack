# Posts one approved JP package's X thread.
#
# Enqueued by PublishScheduledPostsJob the moment the blog post goes live, for
# `package.x.due_at` (blog 09:00 JST + 3h = 12:00 JST).
#
# ── The property this job has to have ──────────────────────────────────────
#
# **A tweet is never posted twice.** Everything below follows from that.
#
# A thread is 5–6 sequential calls, each one replying to the previous. Any of
# them can fail, and the interesting failure is not "it failed" but "I asked and
# did not hear back" — a timeout or a 5xx leaves the tweet possibly posted. The
# only safe move there is to stop and let a person look at the timeline; an
# automatic retry is how the same tweet appears twice with two different ids.
#
# So:
#
#   * every tweet has a row in `package.x.tweets` with its sequence number, a
#     hash of its text, its id once known, and its own state;
#   * an id is written with update_column the INSTANT the API returns it,
#     before anything else happens — a crash one line later must not lose it;
#   * a resumed run starts at the first tweet that is not `done`;
#   * `unknown` stops the job and does not advance. A human marks it
#     「送信済みとして記録」 or 「未送信として再開」 in the admin;
#   * `with_lock` means two runs cannot interleave.
#
# ── Why the approved version is re-checked ────────────────────────────────
#
# Approval froze a specific text. If the post was edited between approval and
# 12:00 JST, the thread in `package.x_thread` may no longer be what anyone
# agreed to publish. Re-computing the fingerprint costs nothing and the
# alternative is posting un-approved copy to a public account.
class XPublishJob < ApplicationJob
  queue_as :default

  # Only for errors that mean the request did NOT reach the API. XClient maps
  # timeouts and 5xx to IndeterminateError, which is deliberately NOT retried —
  # see handle_indeterminate.
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3
  retry_on ActiveRecord::ConnectionNotEstablished, wait: :polynomially_longer, attempts: 3

  def perform(post_id)
    post = Post.find_by(id: post_id)
    return log("post #{post_id} no longer exists") unless post

    # with_lock wraps a transaction and SELECT … FOR UPDATE. Two concurrent runs
    # (a retry overlapping a manual `blog:x_pending`) would otherwise both read
    # the same "next unfinished tweet" and post it twice.
    post.with_lock do
      state = post.package.dig("x", "state")
      unless state.in?(%w[pending running partial_failed]) || (state == "unknown" && post.package.dig("x", "resume_requested"))
        return log("#{post.slug}: x.state=#{state.inspect} — nothing to do")
      end

      unless approved_version_matches?(post)
        block!(post, "approved_version mismatch — 承認後に本文または資産が変わっています。差し戻してから再承認してください。")
        return
      end

      run(post)
    end
  end

  private

  def run(post)
    seed_tweets!(post)
    write_x(post, "state" => "running", "started_at" => Time.current.iso8601)

    client = XClient.new
    media_id = nil

    tweets = post.package.dig("x", "tweets")
    parent = last_done_id(tweets)

    tweets.each_with_index do |row, i|
      next if row["state"] == "done"

      # `unknown` blocks everything behind it. Skipping it would post tweet 4 as
      # a reply to tweet 2 and leave tweet 3 possibly duplicated.
      if row["state"] == "unknown" && !post.package.dig("x", "resume_requested")
        log("#{post.slug}: seq #{row['seq']} is 'unknown' — stopping. A human must confirm the timeline.")
        write_x(post, "state" => "unknown")
        notify_unknown(post, row)
        return
      end

      # Media goes on the first tweet only. Uploaded lazily so a thread that
      # resumes at tweet 4 does not re-upload it.
      if i.zero?
        media_id = upload_media(post, client)
        return if media_id == :failed
      end

      begin
        id = client.post_tweet(text: row["text"], media_id: (i.zero? ? media_id : nil), reply_to: parent)
      rescue XClient::IndeterminateError => e
        handle_indeterminate(post, row, e)
        return
      rescue XClient::ClientError => e
        fail_tweet!(post, row, e)
        return
      end

      # Written FIRST, and alone. Everything after this line can crash without
      # costing us the knowledge that this tweet exists.
      mark_tweet!(post, row["seq"], "tweet_id" => id, "parent_id" => parent, "state" => "done",
                               "posted_at" => Time.current.iso8601)
      parent = id
    end

    finish!(post)
  end

  # ── state transitions ──────────────────────────────────────────────────────

  # Built from the APPROVED array, once. Re-seeding an existing list would
  # discard the ids of tweets already posted.
  def seed_tweets!(post)
    return if post.package.dig("x", "tweets").present?

    rows = approved_thread(post).each_with_index.map do |text, i|
      {
        "seq" => i + 1,
        "text" => text,
        "text_sha" => Digest::SHA256.hexdigest(text)[0, 16],
        "tweet_id" => nil,
        "parent_id" => nil,
        "state" => "pending"
      }
    end
    write_x(post, "tweets" => rows)
  end

  # The JA thread plus the English reply as the final tweet (strategy v3.1 §3-3).
  # 5 or 6 entries — v3 assumed exactly 5, which cross-review Q3 corrected: the
  # required line splits into its own tweet when the CTA would overflow.
  def approved_thread(post)
    [ *post.package_x_thread, post.package["x_reply_en"] ].compact_blank
  end

  def last_done_id(tweets)
    tweets.select { |t| t["state"] == "done" }.max_by { |t| t["seq"] }&.dig("tweet_id")
  end

  def upload_media(post, client)
    name = post.package["media_for_first_tweet"]
    asset = post.package_assets.find { |a| a.filename.to_s == name } || post.package_assets.first
    return nil if asset.blank?

    file = Tempfile.new([ "x-media", File.extname(asset.filename.to_s) ], binmode: true)
    file.write(asset.download)
    file.flush
    client.upload_media(path: file.path, content_type: asset.content_type)
  rescue XClient::IndeterminateError, XClient::ClientError => e
    # Deliberately NOT "post the text anyway". The first tweet of this thread is
    # the demo; a text-only version is a different post, and nobody approved it.
    Rails.logger.error("XPublishJob: #{post.slug} media upload failed — #{e.class}: #{e.message}")
    write_x(post, "state" => "failed", "error" => "media upload failed: #{e.message.first(300)}")
    BlogMailer.jp_x_failed(post.id, "media upload failed: #{e.message.first(300)}").deliver_later rescue nil
    :failed
  ensure
    file&.close
    file&.unlink
  end

  def handle_indeterminate(post, row, error)
    Rails.logger.error(
      "XPublishJob: #{post.slug} seq #{row['seq']} — OUTCOME UNKNOWN (#{error.message.first(200)}). " \
      "Not retrying: the tweet may already be live."
    )
    mark_tweet!(post, row["seq"], "state" => "unknown", "error" => error.message.first(300))
    write_x(post, "state" => "unknown", "error" => error.message.first(300), "resume_requested" => false)
    notify_unknown(post, row)
  end

  def fail_tweet!(post, row, error)
    Rails.logger.error("XPublishJob: #{post.slug} seq #{row['seq']} rejected — #{error.message.first(200)}")
    mark_tweet!(post, row["seq"], "state" => "failed", "error" => error.message.first(300))
    any_done = post.package.dig("x", "tweets").any? { |t| t["state"] == "done" }
    write_x(post, "state" => any_done ? "partial_failed" : "failed", "error" => error.message.first(300))
    BlogMailer.jp_x_failed(post.id, error.message.first(300)).deliver_later rescue nil
  end

  def block!(post, reason)
    Rails.logger.error("XPublishJob: #{post.slug} BLOCKED — #{reason}")
    write_x(post, "state" => "blocked", "error" => reason)
    BlogMailer.jp_x_failed(post.id, reason).deliver_later rescue nil
  end

  def finish!(post)
    first = post.package.dig("x", "tweets").find { |t| t["seq"] == 1 }
    url = first && first["tweet_id"] ? "https://x.com/safefile_jp/status/#{first['tweet_id']}" : nil

    write_x(post, "state" => "done", "url" => url, "finished_at" => Time.current.iso8601,
                  "dry_run" => XClient.dry_run?, "error" => nil, "resume_requested" => false)
    posted = (post.package["posted"] || {}).merge("x" => true, "x_url" => url)
    post.update_column(:package, post.package.merge("posted" => posted))
    log("#{post.slug}: thread done (#{XClient.dry_run? ? 'DRY RUN' : 'live'}) #{url}")
  end

  # ── package writes ─────────────────────────────────────────────────────────
  #
  # update_column, not update!: these are records of what happened at the API,
  # and they must not depend on the row passing validation. The same reasoning
  # as PublishScheduledPostsJob#record_error — and it also keeps
  # Post#clear_stale_publish_error from firing on a write that is not an edit.
  def write_x(post, attrs)
    x = (post.package["x"] || {}).merge(attrs)
    post.update_column(:package, post.package.merge("x" => x))
    post.reload
  end

  def mark_tweet!(post, seq, attrs)
    rows = post.package.dig("x", "tweets").map { |t| t["seq"] == seq ? t.merge(attrs) : t }
    write_x(post, "tweets" => rows)
  end

  # ── approval fingerprint ───────────────────────────────────────────────────

  def approved_version_matches?(post)
    recorded = post.package["approved_version"]
    return true if recorded.blank? # never approved through the admin (tests, manual enqueue)

    recorded == JpApproval.version_for(post)
  end

  def notify_unknown(post, row)
    BlogMailer.jp_x_unknown(post.id, row["seq"]).deliver_later
  rescue StandardError => e
    Rails.logger.error("XPublishJob: could not enqueue the unknown-outcome mail for #{post.slug} — #{e.message}")
  end

  def log(message)
    Rails.logger.info("XPublishJob: #{message}")
  end
end
