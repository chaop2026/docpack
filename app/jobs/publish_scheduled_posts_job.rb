class PublishScheduledPostsJob < ApplicationJob
  queue_as :default

  def perform
    Post.scheduled_ready.find_each do |post|
      post.update!(status: "published")
      BlogMailer.post_published(post).deliver_later
      Rails.logger.info("Published scheduled post: #{post.slug}")
    end
  end
end
