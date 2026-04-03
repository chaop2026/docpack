class PublishScheduledPostsJob < ApplicationJob
  queue_as :default

  def perform
    Post.scheduled_ready.find_each do |post|
      post.update!(status: "published")
      Rails.logger.info("Published scheduled post: #{post.slug}")
    end
  end
end
