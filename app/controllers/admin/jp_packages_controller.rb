module Admin
  # The one screen the weekly approval happens on.
  #
  # /admin/jp/packages/:ep — the blog article (rendered), the English version,
  # the three carousel slides, the demo, the X thread with per-tweet weighted
  # lengths, the LinkedIn text, the FAQ, both publish times, the guard result and
  # the KPI table. One page, because the approval is one decision: 承認 schedules
  # the blog post AND arms the X thread in a single transaction.
  class JpPackagesController < BaseController
    before_action :set_package

    def show
      @kpi = JpWeeklyKpi.new.rows
      @approvable = @post.approvable?(@topic) && @post.published_at.present?
      @blocked_reason = JpApproval.blocked_reason(@post, @topic) unless @post.approvable?(@topic)
    end

    def approve
      JpApproval.approve!(@post, topic: @topic)
      redirect_to admin_jp_package_path(@post.content_ep),
                  notice: "承認しました。ブログ #{jst(@post.published_at)} / X #{jst(@post.published_at + JpApproval::X_DELAY)}"
    rescue ArgumentError => e
      redirect_to admin_jp_package_path(@post.content_ep), alert: "承認できません: #{e.message}"
    end

    def unapprove
      JpApproval.unapprove!(@post)
      redirect_to admin_jp_package_path(@post.content_ep),
                  notice: "差し戻しました。下書きに戻り、X の予約は取り消されています。"
    end

    # `verify_before` topics (ep30, ep32). A human asserts the facts have been
    # re-checked; nothing else may set this, and no job ever does.
    def verify
      @topic.update!(verified_at: Time.current)
      redirect_to admin_jp_package_path(@post.content_ep), notice: "確認済みにしました。"
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
                    alert: "タイムラインに出ているツイートの ID を入れてください(URL の末尾の数字)。"
        return
      end

      update_tweet(seq, "state" => "done", "tweet_id" => tweet_id,
                        "recorded_by_hand_at" => Time.current.iso8601)
      arm_resume!
      redirect_to admin_jp_package_path(@post.content_ep),
                  notice: "#{seq}件目を送信済みとして記録しました。#{seq + 1}件目から再開します。"
    end

    # "It is not there." Clears the id and resumes from THIS tweet.
    def mark_tweet_unsent
      seq = params[:seq].to_i
      update_tweet(seq, "state" => "pending", "tweet_id" => nil,
                        "recorded_by_hand_at" => Time.current.iso8601)
      arm_resume!
      redirect_to admin_jp_package_path(@post.content_ep),
                  notice: "#{seq}件目を未送信として、そこから再開します。"
    end

    # LinkedIn is posted by hand (the official API needs app review). P18 counts
    # only episodes whose URL is recorded here, so this field is the measurement
    # — not a note.
    def record_linkedin
      url = params[:linkedin_url].to_s.strip
      posted = (@post.package["posted"] || {}).merge("linkedin_url" => url.presence)
      @post.update_column(:package, @post.package.merge("posted" => posted))
      redirect_to admin_jp_package_path(@post.content_ep),
                  notice: url.present? ? "LinkedIn の URL を記録しました(P18 に反映されます)。" : "LinkedIn の URL を消しました。"
    end

    private

    def set_package
      @post = Post.find_by!(content_track: "jp", content_ep: params[:ep].to_i)
      @topic = BlogTopic.find_by(track: "jp", ep: @post.content_ep)
    end

    def update_tweet(seq, attrs)
      rows = (@post.package.dig("x", "tweets") || []).map { |t| t["seq"] == seq ? t.merge(attrs) : t }
      write_x("tweets" => rows)
    end

    # `resume_requested` is what lets XPublishJob move past an `unknown` — it is
    # the recorded fact that a human looked. Cleared by the job once it runs, so
    # it can never authorise a second automatic pass.
    def arm_resume!
      write_x("state" => "partial_failed", "resume_requested" => true)
      XPublishJob.perform_later(@post.id)
    end

    def write_x(attrs)
      x = (@post.package["x"] || {}).merge(attrs)
      @post.update_column(:package, @post.package.merge("x" => x))
      @post.reload
    end

    def jst(time)
      time&.in_time_zone("Asia/Tokyo")&.strftime("%Y-%m-%d %H:%M JST") || "—"
    end
  end
end
