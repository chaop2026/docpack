# The 「承認」 action, and the fingerprint it freezes.
#
# Cross-review Q2: approval has to mean "this text, these derivatives, these
# assets, at this time — as one version". Without a fingerprint, approval means
# only "this row was approved at some point", and an edit afterwards publishes
# something nobody agreed to while the admin page still shows a green check.
module JpApproval
  extend self

  # Hours between the blog post going live and the X thread. 09:00 JST → 12:00
  # JST, per strategy v3.1 §2-2.
  X_DELAY = 3.hours

  # Everything a reader of the published week would see. If any of it changes,
  # the approval no longer describes what would go out, and XPublishJob refuses
  # to post (state → 'blocked').
  #
  # published_at is in here on purpose: approving a package for Monday 09:00 and
  # then moving it to Friday is a different decision.
  def version_for(post)
    Digest::SHA256.hexdigest([
      post.title_ja.to_s,
      post.body_ja.to_s,
      post.body_en.to_s,
      post.package_x_thread.to_json,
      post.package["x_reply_en"].to_s,
      post.package["linkedin_text"].to_s,
      assets_digest(post),
      post.published_at&.iso8601.to_s
    ].join("\x00"))
  end

  def assets_digest(post)
    names = post.package_assets.map { |a| "#{a.filename}:#{a.byte_size}" }.sort
    hero = post.hero_image.attached? ? "hero:#{post.hero_image.filename}:#{post.hero_image.byte_size}" : "hero:none"
    Digest::SHA256.hexdigest(([ hero ] + names).join(","))
  end

  # One transaction: scheduling the blog post and arming the X thread are the
  # same decision, and a half-applied approval (scheduled, but with no X state)
  # would publish the blog on Monday and silently never post the thread.
  # ── Why the row lock, and why the reload inside it (S8c, cross-review Q2') ──
  #
  # This used to be a bare `Post.transaction` around writes computed from the
  # in-memory `post`. Two problems, and they compound:
  #
  #   * no lock, so JpImport#apply! — which DOES take `with_lock` — could be
  #     rewriting the body concurrently;
  #   * no reload, so `approvable?`, `published_at` and above all `version_for`
  #     were computed from whatever the caller happened to be holding.
  #
  # The fingerprint is the whole point of approval: it says "this exact text was
  # reviewed". Computing it from a stale copy produces a signature over a
  # version that is not the one in the database — and because XPublishJob
  # re-checks it at 12:00 JST, the visible symptom would be a thread that
  # blocks itself while the admin shows a green check.
  #
  # With the lock, the two paths serialise: either the import finishes first and
  # this approves the NEW text (its fingerprint matching what is stored), or
  # this approves first and the import is refused — JpImport re-checks
  # `writable?` under the same lock and returns :conflict. "Old fingerprint over
  # new body" is not reachable either way.
  #
  # Every validity check moved inside for the same reason: `approvable?` reads
  # guard violations out of `package`, which is exactly what an import rewrites.
  def approve!(post, topic: nil)
    raise ArgumentError, "post #{post.id} is not a JP package" unless post.primary_locale == "ja"

    post.with_lock do
      post.reload
      topic&.reload

      raise ArgumentError, "approval is blocked: #{blocked_reason(post, topic)}" unless post.approvable?(topic)
      raise ArgumentError, "published_at is not set — the weekly job sets it from topics.json publish_on" if post.published_at.blank?

      post.update!(status: "scheduled")
      post.update_column(
        :package,
        post.package.merge(
          "approved_at" => Time.current.iso8601,
          "approved_version" => version_for(post),
          "x" => x_plan(post, topic)
        )
      )
    end
    post.reload
  end

  # Un-approve. Cancels the X thread rather than deleting its record: if the
  # thread had already started, `tweets` holds the ids of what is live and that
  # is the only place that knowledge exists.
  def unapprove!(post)
    Post.transaction do
      post.update!(status: "draft")
      x = (post.package["x"] || {}).merge("state" => "cancelled", "cancelled_at" => Time.current.iso8601)
      post.update_column(
        :package,
        post.package.except("approved_at", "approved_version").merge("x" => x)
      )
    end
    post.reload
  end

  # `social_skip` weeks (ep10 year-end, ep28 Golden Week): blog publishes on its
  # Monday, X and LinkedIn roll to the NEXT Monday. v3 said «X only» for these
  # weeks; cross-review Q5 inverted it — the week people are away is the week a
  # thread is least read and a blog post is most patient.
  def x_plan(post, topic)
    due = post.published_at + X_DELAY
    due = next_monday_noon_jst(post.published_at) if topic&.social_skip?

    (post.package["x"] || {}).merge(
      "state" => "pending",
      "due_at" => due.iso8601,
      "deferred_for_social_skip" => !!topic&.social_skip?
    )
  end

  def next_monday_noon_jst(from)
    jst = from.in_time_zone("Asia/Tokyo")
    d = jst.to_date + 1
    d += 1 until d.wday == 1
    Time.use_zone("Asia/Tokyo") { Time.zone.local(d.year, d.month, d.day, 12, 0, 0) }
  end

  def blocked_reason(post, topic)
    reasons = []
    reasons << "guard violations: #{post.guard_violations.length}" if post.guard_violations.any?
    reasons << "import conflict recorded" if post.import_conflict.present?
    reasons << "topic needs verification (verify_before)" if topic&.awaiting_verification?
    reasons.join("; ").presence || "unknown"
  end
end
