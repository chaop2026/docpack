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

    @summary = @post.package["summary_ko"] || {}

    # Korean subject and Korean body chrome; the article, the thread and the
    # LinkedIn post stay in their published language. The approver reads this
    # mail on a phone on a Saturday — the part that has to be instantly legible
    # is what is being asked of them, not the copy itself.
    subject = t("jp_admin.mail.subject",
                nn: format("%02d", @post.content_ep), title: @post.title_ja)
    subject = subject.sub("] ", "] #{t('jp_admin.mail.subject_assets_missing')} ") if @assets_missing
    subject = subject.sub("] ", "] #{t('jp_admin.mail.subject_awaiting_verification')} ") if @awaiting_verification

    # The guide PDF and the demo video, ATTACHED (S9). The LinkedIn post is
    # published by hand from a phone or a laptop, and 「open the admin, find the
    # asset list, download the PDF, then go to LinkedIn」 is three steps that
    # each have to succeed. An attachment is already there.
    #
    # Attached by content type rather than by filename so a renamed asset still
    # travels, and guarded by `attached?` because the fallback generator
    # produces a package with no assets at all.
    attach_package_files(@post) if @post.package_assets.attached?

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
         subject: t("jp_admin.mail.subject_x_unknown",
                    nn: format("%02d", @post.content_ep), seq: seq))
  end

  def jp_x_failed(post_id, reason)
    @post = Post.find(post_id)
    @reason = reason
    @tweets = @post.package.dig("x", "tweets") || []
    @state = @post.package.dig("x", "state")
    @preview_url = "#{base}/admin/jp/packages/#{@post.content_ep}"

    mail(to: "chaop2@gmail.com",
         subject: t("jp_admin.mail.subject_x_failed",
                    nn: format("%02d", @post.content_ep), state: @state))
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

  # PDF + MP4 from package_assets. Images are deliberately left out: the three
  # carousel slides are ~1MB each and the mail already renders what matters
  # about them, while the PDF is the thing the approver has to upload to
  # LinkedIn and the MP4 is the thing they would otherwise have to go and find.
  #
  # `attachments[name] = { mime_type:, content: }` rather than letting Mail
  # guess from the extension — a .pdf served as application/octet-stream shows
  # up in Gmail as an unopenable blob.
  ATTACH_TYPES = { "application/pdf" => true, "video/mp4" => true }.freeze
  ATTACH_MAX_BYTES = 20.megabytes

  def attach_package_files(post)
    total = 0
    post.package_assets.each do |asset|
      next unless ATTACH_TYPES[asset.content_type.to_s]

      # Gmail rejects the whole message over 25MB, and a rejected mail is a
      # silent loss of the ONE thing this mail exists to deliver. Skipping an
      # oversized attachment keeps the rest of the mail — and says so in the
      # log, because an attachment that quietly did not travel is worse than
      # one that is missing for a stated reason.
      if total + asset.byte_size > ATTACH_MAX_BYTES
        Rails.logger.warn("BlogMailer: skipped #{asset.filename} (#{asset.byte_size}B) — " \
                          "would push attachments past #{ATTACH_MAX_BYTES}B")
        next
      end

      total += asset.byte_size
      attachments[asset.filename.to_s] = {
        mime_type: asset.content_type,
        content: asset.download
      }
    end
    @attached_names = attachments.map { |a| a.filename }
  end

  def base
    ENV.fetch("BASE_URL", "https://slimfile.net")
  end
end
