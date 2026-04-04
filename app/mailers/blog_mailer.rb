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
end
