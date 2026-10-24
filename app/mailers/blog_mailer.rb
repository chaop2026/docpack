class BlogMailer < ApplicationMailer
  def post_published(post)
    @post = post
    @upcoming_posts = Post.where(status: "scheduled").order(:published_at).limit(3)
    @remaining_topics = BlogTopic.next_ko.count

    mail(
      to: "chaop2@gmail.com",
      subject: "[SlimFile 블로그] 새 글 발행: #{post.title_ko}"
    )
  end

  # Sent by PublishScheduledPostsJob once per run in which at least one post
  # could not be published. `failures` is an array of plain hashes with string
  # keys ("slug", "id", "errors") — not Post records, because this crosses an
  # ActiveJob serialization boundary, and not exceptions, for the same reason.
  #
  # A post that fails validation stays `scheduled` and would otherwise sit there
  # unnoticed forever; the job runs daily, so this arrives daily until the record
  # is fixed. That repetition is intentional.
  def publish_failed(failures)
    @failures = failures

    mail(
      to: "chaop2@gmail.com",
      subject: "[SlimFile 블로그] 발행 실패 #{failures.size}건 — 예약 상태로 남았습니다"
    )
  end

  # ── SafeFile JP weekly package ──────────────────────────────────────────────
  #
  # Takes a post ID, not a Post. Everything these three mails put on the page is
  # looked up here, so nothing but integers and strings crosses the ActiveJob
  # serialization boundary — the trap PublishScheduledPostsJob#describe_failure
  # already documents, where a Post or an exception object in the arguments
  # fails only in production while the job test stays green.
  def jp_review_requested(post_id)
    @post = Post.find(post_id)
    @topic = BlogTopic.find_by(track: "jp", ep: @post.content_ep)
    @kpi = JpWeeklyKpi.new.rows
    @violations = @post.guard_violations
    @thread = @post.package_x_thread
    @reply_en = @post.package["x_reply_en"]
    @linkedin = @post.package["linkedin_text"]
    @remaining = BlogTopic.jp.where(review_sent_at: nil).count
    @assets_missing = @post.package["assets_missing"].present?
    @awaiting_verification = @topic&.awaiting_verification?
    @x_due_at = @post.published_at ? @post.published_at + JpApproval::X_DELAY : nil
    @preview_url = "#{base}/admin/jp/packages/#{@post.content_ep}"

    subject = "[SafeFile JP] 第#{format('%02d', @post.content_ep)}回 承認依頼: #{@post.title_ja}"
    subject = "#{subject.sub('] ', '] [アセット未生成] ')}" if @assets_missing
    subject = subject.sub("] ", "] [要事前確認] ") if @awaiting_verification

    mail(to: "chaop2@gmail.com", subject: subject)
  end

  # The X thread stopped because an answer was lost, not because it failed.
  # Deliberately a different mail from jp_x_failed: the action is different —
  # somebody has to LOOK AT THE TIMELINE and say whether the tweet is there.
  def jp_x_unknown(post_id, seq)
    @post = Post.find(post_id)
    @seq = seq
    @tweets = @post.package.dig("x", "tweets") || []
    @preview_url = "#{base}/admin/jp/packages/#{@post.content_ep}"

    mail(to: "chaop2@gmail.com",
         subject: "[SafeFile JP] 第#{format('%02d', @post.content_ep)}回 Xスレッド #{seq}件目の結果が不明 — 確認が必要です")
  end

  def jp_x_failed(post_id, reason)
    @post = Post.find(post_id)
    @reason = reason
    @tweets = @post.package.dig("x", "tweets") || []
    @state = @post.package.dig("x", "state")
    @preview_url = "#{base}/admin/jp/packages/#{@post.content_ep}"

    mail(to: "chaop2@gmail.com",
         subject: "[SafeFile JP] 第#{format('%02d', @post.content_ep)}回 Xスレッド失敗 (#{@state})")
  end

  def review_requested(post)
    @post = post
    @remaining_topics = BlogTopic.next_ko.count

    mail(
      to: "chaop2@gmail.com",
      subject: "[SlimFile 블로그] 검토 요청: #{post.title_ko}"
    )
  end

  private

  def base
    ENV.fetch("BASE_URL", "https://slimfile.net")
  end
end
