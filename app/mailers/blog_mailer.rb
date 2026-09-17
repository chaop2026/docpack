class BlogMailer < ApplicationMailer
  def post_published(post)
    @post = post
    @upcoming_posts = Post.where(status: "scheduled").order(:published_at).limit(3)
    @remaining_topics = BlogTopic.where(used: false).count

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

  def review_requested(post)
    @post = post
    @remaining_topics = BlogTopic.where(used: false).count

    mail(
      to: "chaop2@gmail.com",
      subject: "[SlimFile 블로그] 검토 요청: #{post.title_ko}"
    )
  end
end
