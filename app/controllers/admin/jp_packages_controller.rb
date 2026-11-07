module Admin
  # The one screen the weekly approval happens on.
  #
  # /admin/jp/packages/:ep — the blog article (rendered), the English version,
  # the three carousel slides, the demo, the X thread with per-tweet weighted
  # lengths, the LinkedIn text, the FAQ, both publish times, the guard result and
  # the KPI table. One page, because the approval is one decision: 「승인」 schedules
  # the blog post AND arms the X thread in a single transaction.
  class JpPackagesController < BaseController
    include PostShowAssigns

    # ── preview is 404 for anybody else, not a redirect ───────────────────────
    #
    # The rest of the admin redirects an unauthenticated visitor to the login
    # form, which is right for a person who meant to sign in. It is wrong for
    # THIS route: a redirect confirms that /admin/jp/packages/7/preview is a
    # real address, and the episode number is guessable. A 404 says nothing.
    #
    # Note what this does NOT claim to protect. The same draft is already
    # readable at /ja/blog/:slug by anyone who knows the slug — PostsController
    # serves `draft` and `scheduled` with a 200 on purpose (noindex; see
    # Post#indexable?). So this is about not ADDING a second, enumerable
    # address, not about making the draft secret.
    skip_before_action :require_admin, only: :preview
    before_action :require_admin_or_404, only: :preview
    before_action :set_package

    def show
      @kpi = JpWeeklyKpi.new.rows
      @approvable = @post.approvable?(@topic) && @post.published_at.present?
      @blocked_reason = JpApproval.blocked_reason(@post, @topic) unless @post.approvable?(@topic)
      @preview_path = admin_jp_package_preview_path(@post.content_ep)
    end

    # The article in the public layout.
    #
    # `@url_locale` is the post's own primary locale rather than something read
    # off this URL: /admin/jp/packages/2/preview carries no locale prefix, and
    # the document being rendered is Japanese. Passing the default (Korean)
    # would make the template compute a Korean canonical for a Japanese
    # article — the admin screen would then be previewing indexing signals that
    # no public URL emits.
    #
    # `@preview` is read by the template for the banner and to force noindex.
    # The noindex is belt-and-braces: a draft or scheduled post is already
    # noindex via Post#indexable?, but this URL must never be indexable even
    # after the post is published and indexable at its real address.
    def preview
      @preview = true
      assign_post_show_ivars(@post, @post.primary_locale_sym)
      render template: "posts/show", layout: "application"
    end

    def approve
      JpApproval.approve!(@post, topic: @topic)
      redirect_to admin_jp_package_path(@post.content_ep),
                  notice: t("jp_admin.flash.approved",
                            blog: jst(@post.published_at),
                            x: jst(@post.published_at + JpApproval::X_DELAY))
    rescue ArgumentError => e
      redirect_to admin_jp_package_path(@post.content_ep),
                  alert: t("jp_admin.flash.approve_failed", reason: e.message)
    end

    def unapprove
      JpApproval.unapprove!(@post)
      redirect_to admin_jp_package_path(@post.content_ep),
                  notice: t("jp_admin.flash.unapproved")
    end

    # `verify_before` topics (ep30, ep32). A human asserts the facts have been
    # re-checked; nothing else may set this, and no job ever does.
    def verify
      @topic.update!(verified_at: Time.current)
      redirect_to admin_jp_package_path(@post.content_ep), notice: t("jp_admin.flash.verified")
    end

    # ── the two answers to an 'unknown' tweet ─────────────────────────────────
    #
    # XPublishJob stops dead on an indeterminate response and will not act until
    # one of these is pressed, because the two possible truths need opposite
    # actions and only a person looking at the timeline can tell them apart.

    # "It is on the timeline." Records the id a human read off it and resumes
    # from the NEXT tweet.
    def mark_tweet_sent
      seq = params[:seq].to_i
      tweet_id = params[:tweet_id].to_s.strip
      if tweet_id.blank?
        redirect_to admin_jp_package_path(@post.content_ep),
                    alert: t("jp_admin.flash.tweet_id_required")
        return
      end

      # `done`, so the run guard never looks at it again — this seq needs no
      # re-send authorisation, only the ones AFTER it will be attempted.
      resume!(seq, { "state" => "done", "tweet_id" => tweet_id,
                     "error" => nil, "recorded_by_hand_at" => Time.current.iso8601 })
      redirect_to admin_jp_package_path(@post.content_ep),
                  notice: t("jp_admin.flash.tweet_marked_sent", seq: seq, next: seq + 1)
    end

    # "It is not there." Authorises a re-send of THIS seq, and only this one.
    def mark_tweet_unsent
      seq = params[:seq].to_i
      # The tweet stays `unknown`; what changes is that this seq is now on the
      # authorised list. The job consumes that authorisation when it reaches the
      # seq — see XPublishJob#run. Leaving the state alone keeps the record of
      # what happened ("we asked and did not hear back") until the re-send
      # actually begins.
      resume!(seq, { "recorded_by_hand_at" => Time.current.iso8601,
                     "authorised_resend_at" => Time.current.iso8601 }, authorise: seq)
      redirect_to admin_jp_package_path(@post.content_ep),
                  notice: t("jp_admin.flash.tweet_marked_unsent", seq: seq)
    end

    # LinkedIn is posted by hand (the official API needs app review). P18 counts
    # only episodes whose URL is recorded here, so this field is the measurement
    # — not a note.
    def record_linkedin
      url = params[:linkedin_url].to_s.strip
      posted = (@post.package["posted"] || {}).merge("linkedin_url" => url.presence)
      @post.update_column(:package, @post.package.merge("posted" => posted))
      redirect_to admin_jp_package_path(@post.content_ep),
                  notice: url.present? ? t("jp_admin.flash.linkedin_recorded") : t("jp_admin.flash.linkedin_cleared")
    end

    private

    def require_admin_or_404
      # Admin::BaseController#admin_session_live? — the SAME rule the redirect
      # branch uses, including the twelve-hour expiry (S15). Reading
      # `session[:admin_authenticated]` here instead would make this the one
      # admin surface an expired session can still reach.
      return if admin_session_live?

      # ActionController::RoutingError, so the request is handled by the same
      # 404 path as a genuinely unknown URL — identical status, identical body.
      raise ActionController::RoutingError, "Not Found"
    end

    def set_package
      @post = Post.find_by!(content_track: "jp", content_ep: params[:ep].to_i)
      @topic = BlogTopic.find_by(track: "jp", ep: @post.content_ep)
    end

    # One write for the human's decision, then enqueue.
    #
    # `authorise:` adds the seq to `x.resume_seqs` — the list of tweets a person
    # has confirmed are NOT on the timeline. That list replaced a boolean
    # (`resume_requested`) in S8c, and the boolean was a defect rather than a
    # style choice: it said "move past an unknown" in general, so a thread
    # resumed once would also wave past a DIFFERENT tweet that went
    # indeterminate later and nobody had looked at. Measured against 7cf81ec,
    # that reposted a possibly-live tweet and finished reporting success.
    #
    # 「전송됨으로 기록」 (mark_tweet_sent) therefore authorises nothing: the seq
    # becomes `done` and the guard has no reason to stop at it. The button
    # labels are Korean as of S9 — see config/locales/ko.yml jp_admin.show.
    def resume!(seq, tweet_attrs, authorise: nil)
      x = (@post.package["x"] || {}).dup
      x["tweets"] = (x["tweets"] || []).map { |t| t["seq"] == seq ? t.merge(tweet_attrs) : t }
      x["state"] = "partial_failed"
      # This seq's entry is rewritten, never accumulated: the two buttons are
      # mutually exclusive answers about the same tweet, so pressing
      # 「送信済みとして記録」 must clear any authorisation an earlier
      # 「未送信として再開」 left behind. (Harmless if it lingered — the run guard
      # only consults the list for `unknown` rows — but a list that still names
      # a tweet now marked `done` invites a wrong reading.)
      x["resume_seqs"] = ((Array(x["resume_seqs"]).map(&:to_i) - [ seq ]) + Array(authorise)).uniq.sort
      # The old boolean must not linger: a stale `true` would be read by any
      # code that has not been updated.
      x.delete("resume_requested")

      @post.update_column(:package, @post.package.merge("x" => x))
      @post.reload
      XPublishJob.perform_later(@post.id)
    end

    def jst(time)
      time&.in_time_zone("Asia/Tokyo")&.strftime("%Y-%m-%d %H:%M JST") || "—"
    end
  end
end
