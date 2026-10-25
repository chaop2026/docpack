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
# did not hear back" — a timeout, a 5xx, or the process dying — all of which
# leave the tweet possibly posted. The only safe move there is to stop and let a
# person look at the timeline; an automatic retry is how the same tweet appears
# twice with two different ids.
#
# ── Why the lock is a CLAIM and not a transaction (2026-10-25, S8b) ────────
#
# The first version wrapped the whole send loop in `post.with_lock do … end`.
# That reads as "nobody else can interleave", and it is true — but it also means
# every `update_column` inside the loop is part of ONE uncommitted transaction.
# Measured, before this rewrite, with a stub that raised `Interrupt` right after
# the API returned the third tweet id:
#
#     CRASHED: process killed right after the API returned seq 3
#     state="pending"
#     tweets=[]
#
# Three tweets were on the timeline and the database had forgotten all of them —
# not just the ids, the whole array. The next run would have posted 1, 2 and 3
# again. The comment on the write even said "written FIRST, and alone … a crash
# one line later must not lose it", which was precisely wrong: inside a
# transaction, a write is not a fact until the commit, and the commit was at the
# end of the loop.
#
# So the structure is now:
#
#   1. CLAIM — a short transaction (`with_lock`) that checks the state and the
#      approval, writes `x.state='running'` + a `worker_token` + `claimed_at`,
#      and COMMITS. Ownership is a committed fact before any API call happens.
#   2. SEND — the loop runs with NO transaction open. Per tweet:
#        a. commit `seq.state='sending'`   ← "I am about to call the API"
#        b. call the API
#        c. commit `tweet_id` + `state='done'`
#      Every write is conditional on the token still being ours; if another
#      worker stole a stale claim, our write affects zero rows and we stop.
#   3. RESUME — a `sending` row means the process died between (a) and (c), so
#      the outcome is unknown by construction: it is promoted to `unknown` and
#      a human is asked to look. We do not guess, and we never resend it.
#
# A crash anywhere now loses at most the knowledge of ONE tweet's outcome, and
# that one is reported as unknown rather than retried.
class XPublishJob < ApplicationJob
  queue_as :default

  # Only for errors that mean the request did NOT reach the API. XClient maps
  # timeouts and 5xx to IndeterminateError, which is deliberately NOT retried —
  # see handle_indeterminate.
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3
  retry_on ActiveRecord::ConnectionNotEstablished, wait: :polynomially_longer, attempts: 3

  # How long a claim is honoured before another worker may take it.
  #
  # Too short and a slow-but-alive worker gets its thread stolen mid-send (two
  # workers, one timeline). Too long and a crashed worker's thread sits frozen.
  # 30 minutes is far past any plausible run — six tweets with a 45s read
  # timeout each is under five minutes even in the worst case — so crossing it
  # means the worker is gone, not slow.
  CLAIM_TTL = 30.minutes

  # States a run may start from.
  CLAIMABLE = %w[pending running partial_failed].freeze

  # Raised when our token is no longer in the row: another worker took over a
  # claim we thought was ours. Nothing to clean up — the new owner is
  # authoritative — so this just ends the run.
  class ClaimLost < StandardError; end

  def perform(post_id)
    post = Post.find_by(id: post_id)
    return log("post #{post_id} no longer exists") unless post

    token = claim!(post)
    return unless token

    begin
      run(post, token)
    rescue ClaimLost
      log("#{post.slug}: our claim was taken over by another worker — stopping without writing")
    end
  end

  private

  # ── 1. claim ────────────────────────────────────────────────────────────────
  #
  # The ONLY transaction in this job. It is short on purpose: everything inside
  # it is a database read or write, no API call, so it cannot be held open by a
  # network stall.
  #
  # Returns the token on success, nil when there is nothing to do or somebody
  # else owns the thread.
  def claim!(post)
    token = SecureRandom.hex(8)

    post.with_lock do
      post.reload
      x = post.package["x"] || {}
      state = x["state"]

      # Repair for a half-finished thread (S8c). `finish!` is now a single
      # UPDATE, so this shape cannot be produced any more — but rows written by
      # the previous version can carry it: `x.state='done'` with `posted.x`
      # never recorded, because the old finish wrote the two separately and a
      # crash in between left the second one undone. Nothing reported it either
      # (`done` is not x_stuck, and claim! declined to re-process it), so it
      # would have sat like that forever.
      #
      # No API call. The thread IS posted; only our record of it is incomplete,
      # and `x.url` already holds what the record needs.
      if state == "done" && post.package.dig("posted", "x") != true
        repair_unfinished_posted!(post)
        return nil
      end

      unless CLAIMABLE.include?(state) || (state == "unknown" && resume_seqs(x).any?)
        log("#{post.slug}: x.state=#{state.inspect} — nothing to do")
        return nil
      end

      # Somebody else is mid-send. Their claim is young, so they are alive.
      if state == "running" && claim_fresh?(x)
        log("#{post.slug}: already running under worker #{x['worker_token'].inspect} " \
            "(claimed #{x['claimed_at']}) — leaving it alone")
        return nil
      end

      unless approved_version_matches?(post)
        block!(post, approval_block_reason(post))
        return nil
      end

      seed_tweets!(post)

      write_x_unlocked(post,
                       "state" => "running",
                       "worker_token" => token,
                       "claimed_at" => Time.current.iso8601,
                       "started_at" => (x["started_at"] || Time.current.iso8601))
    end

    token
  end

  def claim_fresh?(x)
    at = x["claimed_at"]
    return false if at.blank?

    Time.zone.parse(at.to_s) > Time.current - CLAIM_TTL
  rescue ArgumentError
    false # an unparseable timestamp is not evidence that a worker is alive
  end

  # Which tweets a HUMAN has authorised a re-send of, by sequence number.
  #
  # This replaced a boolean `resume_requested` in S8c, and the boolean was a
  # real defect rather than a style problem: it authorised "move past an
  # unknown" in general, not "re-send tweet 3". Measured against the previous
  # version — a thread that had been resumed once (flag true) and then hit a
  # NEW indeterminate at tweet 3 reposted tweet 3 and ran to completion:
  #
  #   RESENT COUNT: 4  ["t3", "t4", "t5", "en reply"]
  #
  # with t3 possibly already live. A list cannot do that: a seq nobody has
  # looked at is simply not in it.
  def resume_seqs(x)
    Array(x["resume_seqs"]).map(&:to_i)
  end

  # The thread is live; only our record of it is incomplete. Called under the
  # row lock, so the write is unconditional.
  def repair_unfinished_posted!(post)
    url = post.package.dig("x", "url")
    posted = (post.package["posted"] || {}).merge("x" => true, "x_url" => url)
    post.update_column(:package, post.package.merge("posted" => posted))
    post.reload
    log("#{post.slug}: repaired a thread left 'done' without posted.x (no API call) — #{url}")
  end

  # ── 2. send ─────────────────────────────────────────────────────────────────

  def run(post, token)
    # A row left in `sending` means a previous process died between "about to
    # call" and "the call returned". Whether the tweet exists is unknowable from
    # here, which is the definition of unknown — promote it and stop.
    return if promote_sending_to_unknown!(post, token)

    client = XClient.new
    media_id = nil
    tweets = post.package.dig("x", "tweets")
    parent = last_done_id(tweets)

    tweets.each_with_index do |row, i|
      next if row["state"] == "done"

      # `unknown` blocks everything behind it. Skipping it would post tweet 4 as
      # a reply to tweet 2 and leave tweet 3 possibly duplicated.
      #
      # Authorisation is PER SEQUENCE. A human who confirmed tweet 3 was not on
      # the timeline authorised re-sending tweet 3 — nothing else, and nothing
      # later. The old boolean said "move past unknowns" and therefore waved
      # through a tweet nobody had looked at.
      if row["state"] == "unknown"
        authorised = resume_seqs(post.package["x"] || {})
        unless authorised.include?(row["seq"])
          log("#{post.slug}: seq #{row['seq']} is 'unknown' and not in resume_seqs=#{authorised.inspect} " \
              "— stopping. A human must confirm the timeline.")
          write_x!(post, token, { "state" => "unknown" })
          notify_unknown(post, row)
          return
        end

        # Consume the authorisation and clear the unknown in ONE write. If this
        # commits and the process then dies, the seq is `pending` — which is
        # exactly what the human asserted ("it was not sent") — and the
        # authorisation is spent, so it cannot be replayed for some later
        # unknown.
        log("#{post.slug}: seq #{row['seq']} re-send authorised by a human — consuming it")
        write_x!(post, token,
                 { "resume_seqs" => authorised - [ row["seq"] ] },
                 tweet_patches: { row["seq"] => { "state" => "pending", "error" => nil } })
      end

      # Media goes on the first tweet only. Uploaded lazily so a thread that
      # resumes at tweet 4 does not re-upload it.
      if i.zero?
        media_id = upload_media(post, token, client)
        return if media_id == :failed
      end

      # (a) The intent to call, committed BEFORE the call. This is the record
      #     that makes a crash during the call detectable: without it, a dead
      #     process is indistinguishable from one that never started the tweet,
      #     and "never started" invites a resend.
      mark_tweet!(post, token, row["seq"], "state" => "sending", "sending_at" => Time.current.iso8601)

      begin
        # (b) No transaction is open here. A crash loses nothing that was
        #     already committed.
        id = client.post_tweet(text: row["text"], media_id: (i.zero? ? media_id : nil), reply_to: parent)
      rescue XClient::IndeterminateError => e
        handle_indeterminate(post, token, row, e)
        return
      rescue XClient::ClientError => e
        fail_tweet!(post, token, row, e)
        return
      end

      # (c) The outcome, committed on its own.
      mark_tweet!(post, token, row["seq"],
                  "tweet_id" => id, "parent_id" => parent, "state" => "done",
                  "posted_at" => Time.current.iso8601, "sending_at" => nil)
      parent = id
    end

    finish!(post, token)
  end

  # Returns true when it stopped the run.
  #
  # ONE write, like handle_indeterminate below and for the same reason: a crash
  # between "this tweet is unknown" and "this thread is unknown" used to leave a
  # row that said `running` while a tweet said `unknown`, and the run guard read
  # the thread-level flag.
  def promote_sending_to_unknown!(post, token)
    stuck = (post.package.dig("x", "tweets") || []).select { |t| t["state"] == "sending" }
    return false if stuck.empty?

    stuck.each do |row|
      Rails.logger.error(
        "XPublishJob: #{post.slug} seq #{row['seq']} was left in 'sending' (since #{row['sending_at']}) — " \
        "the previous run died during the API call. Outcome UNKNOWN; not resending."
      )
    end

    patches = stuck.to_h do |row|
      [ row["seq"], { "state" => "unknown",
                      "error" => "process ended during the API call (sending since #{row['sending_at']})" } ]
    end

    write_x!(post, token,
             { "state" => "unknown",
               "error" => "a previous run ended mid-send; #{stuck.size} tweet(s) need a human check" },
             tweet_patches: patches)
    notify_unknown(post, stuck.first)
    true
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
    write_x_unlocked(post, "tweets" => rows)
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

  def upload_media(post, token, client)
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
    write_x!(post, token, { "state" => "failed", "error" => "media upload failed: #{e.message.first(300)}" })
    BlogMailer.jp_x_failed(post.id, "media upload failed: #{e.message.first(300)}").deliver_later rescue nil
    :failed
  ensure
    file&.close
    file&.unlink
  end

  # ONE write. The tweet's state and the thread's state are the same fact seen
  # at two levels, and splitting them across two UPDATEs created a window in
  # which they disagreed.
  #
  # Measured against the split version: crash between the two writes, with
  # `resume_requested` still true from an earlier human decision, and the row
  # came back `x.state=running, resume_requested=true, seq 3=unknown`. A worker
  # taking over after the TTL read the thread-level flag, waved past seq 3, and
  # reposted it — `RESENT COUNT: 4 ["t3","t4","t5","en reply"]` — finishing with
  # `x.state=done` as though nothing had happened. The per-seq authorisation
  # list fixes the guard; writing once removes the disagreement entirely.
  def handle_indeterminate(post, token, row, error)
    Rails.logger.error(
      "XPublishJob: #{post.slug} seq #{row['seq']} — OUTCOME UNKNOWN (#{error.message.first(200)}). " \
      "Not retrying: the tweet may already be live."
    )
    write_x!(post, token,
             { "state" => "unknown", "error" => error.message.first(300) },
             tweet_patches: { row["seq"] => { "state" => "unknown", "error" => error.message.first(300) } })
    notify_unknown(post, row)
  end

  def fail_tweet!(post, token, row, error)
    Rails.logger.error("XPublishJob: #{post.slug} seq #{row['seq']} rejected — #{error.message.first(200)}")
    any_done = post.package.dig("x", "tweets").any? { |t| t["state"] == "done" }
    write_x!(post, token,
             { "state" => any_done ? "partial_failed" : "failed", "error" => error.message.first(300) },
             tweet_patches: { row["seq"] => { "state" => "failed", "error" => error.message.first(300),
                                              "sending_at" => nil } })
    BlogMailer.jp_x_failed(post.id, error.message.first(300)).deliver_later rescue nil
  end

  # Called from inside the claim transaction (no token yet), so it uses the
  # unconditional write.
  def block!(post, reason)
    Rails.logger.error("XPublishJob: #{post.slug} BLOCKED — #{reason}")
    write_x_unlocked(post, "state" => "blocked", "error" => reason)
    BlogMailer.jp_x_failed(post.id, reason).deliver_later rescue nil
  end

  # ONE write, covering both subtrees.
  #
  # `posted` lives outside `x`, and the previous version therefore wrote it in a
  # second statement — one that carried no token condition. Two consequences,
  # both measured: a crash in between produced `x.state='done'` with `posted`
  # absent, and nothing recovered from it (`done` is not x_stuck, and claim!
  # declined to re-process it, so `SELF-HEAL?: posted=nil api_calls=0`); and the
  # unconditional `reload.package.merge` could overwrite a sibling key another
  # process had just written.
  #
  # `jsonb_set(jsonb_set(package,'{x}',…),'{posted}',…)` writes both paths in a
  # single statement, under the same token condition as every other write in the
  # send loop. There is no longer an "in between".
  def finish!(post, token)
    first = post.package.dig("x", "tweets").find { |t| t["seq"] == 1 }
    url = first && first["tweet_id"] ? "https://x.com/safefile_jp/status/#{first['tweet_id']}" : nil

    post.reload
    x = (post.package["x"] || {}).merge(
      "state" => "done", "url" => url, "finished_at" => Time.current.iso8601,
      "dry_run" => XClient.dry_run?, "error" => nil, "resume_seqs" => [],
      "worker_token" => nil
    )
    posted = (post.package["posted"] || {}).merge("x" => true, "x_url" => url)

    updated = Post.where(id: post.id)
                  .where("package -> 'x' ->> 'worker_token' = ?", token)
                  .update_all([
                    "package = jsonb_set(jsonb_set(package, '{x}', ?::jsonb), '{posted}', ?::jsonb)",
                    x.to_json, posted.to_json
                  ])

    raise ClaimLost, "worker_token no longer matches for post #{post.id}" if updated.zero?

    post.reload
    log("#{post.slug}: thread done (#{XClient.dry_run? ? 'DRY RUN' : 'live'}) #{url}")
  end

  # ── package writes ─────────────────────────────────────────────────────────
  #
  # Two flavours, and the difference matters.
  #
  # write_x_unlocked — used ONLY inside the claim transaction, where the row
  #   lock is held and no token exists yet.
  #
  # write_x! — used everywhere in the send loop. Conditional on our token still
  #   being in the row, so a worker whose stale claim was taken over cannot
  #   write anything. `jsonb_set(package, '{x}', …)` touches only the `x`
  #   subtree, so a concurrent write to a sibling key (the admin recording a
  #   LinkedIn URL, say) is not clobbered by a read-modify-write of the whole
  #   document.
  #
  # Both use raw column writes rather than `update!`: these are records of what
  # happened at the API and must not depend on the row passing validation (the
  # same reasoning as PublishScheduledPostsJob#record_error), and it keeps
  # Post#clear_stale_publish_error from firing on a write that is not an edit.
  def write_x_unlocked(post, attrs)
    x = (post.package["x"] || {}).merge(attrs)
    post.update_column(:package, post.package.merge("x" => x))
    post.reload
  end

  # `tweet_patches` is { seq => { attrs } } and is applied in the SAME statement
  # as `attrs`. That pairing is the point: the thread-level state and the
  # per-tweet state describe one event, and every place that used to write them
  # as two statements had a window where a crash left them contradicting each
  # other (see handle_indeterminate).
  # NOTE the explicit braces at every call site. With a keyword argument in the
  # signature, a trailing bare hash (`write_x!(post, token, "state" => "x")`) is
  # parsed as keywords and dies with `unknown keyword: "state"` — caught by the
  # existing token test rather than in production, but worth naming here.
  def write_x!(post, token, attrs = {}, tweet_patches: nil)
    raise ArgumentError, "attrs must be a Hash, got #{attrs.class}" unless attrs.is_a?(Hash)

    post.reload
    x = (post.package["x"] || {}).merge(attrs)

    if tweet_patches.present?
      x["tweets"] = (x["tweets"] || []).map do |t|
        patch = tweet_patches[t["seq"]]
        patch ? t.merge(patch) : t
      end
    end

    updated = Post.where(id: post.id)
                  .where("package -> 'x' ->> 'worker_token' = ?", token)
                  .update_all([ "package = jsonb_set(package, '{x}', ?::jsonb)", x.to_json ])

    raise ClaimLost, "worker_token no longer matches for post #{post.id}" if updated.zero?

    post.reload
  end

  def mark_tweet!(post, token, seq, attrs)
    write_x!(post, token, tweet_patches: { seq => attrs })
  end

  # ── approval fingerprint ───────────────────────────────────────────────────
  #
  # FAIL-CLOSED (cross-review Q3). This used to return true when no fingerprint
  # was recorded, on the reasoning that such a package "was never approved
  # through the admin (tests, manual enqueue)". That is exactly backwards: a
  # package with no recorded approval is a package nobody approved, and the one
  # thing this job must not do is post un-approved copy to a public account.
  #
  # Dry run is NOT an exception. A dry run that skips the approval check is not
  # exercising the code path that will run for real, and the tests would then be
  # proving something other than the thing being shipped.
  def approved_version_matches?(post)
    recorded = post.package["approved_version"]
    return false if recorded.blank?

    recorded == JpApproval.version_for(post)
  end

  def approval_block_reason(post)
    if post.package["approved_version"].blank?
      "承認の記録がありません（approved_version 未設定）。/admin/jp/packages/#{post.content_ep} で承認してください。"
    else
      "approved_version mismatch — 承認後に本文または資産が変わっています。差し戻してから再承認してください。"
    end
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
