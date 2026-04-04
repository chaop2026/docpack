class AutoGenerateBlogPostJob < ApplicationJob
  queue_as :default

  def perform
    topic = BlogTopic.unused.order("RANDOM()").first
    unless topic
      Rails.logger.info("AutoGenerateBlogPostJob: No unused topics remaining")
      return
    end

    service = BlogGeneratorService.new
    result = service.generate_post(topic.topic, topic.category)

    unless result
      Rails.logger.error("AutoGenerateBlogPostJob: Failed to generate post for topic: #{topic.topic}")
      return
    end

    published_at = next_publish_date

    post = Post.create!(
      title_ko: result[:title_ko],
      body_ko: result[:body_ko],
      meta_description_ko: result[:meta_description_ko],
      slug: result[:slug],
      cover_svg: result[:cover_svg],
      category: topic.category,
      status: "scheduled",
      published_at: published_at
    )

    topic.update!(used: true)
    Rails.logger.info("AutoGenerateBlogPostJob: Created scheduled post '#{post.slug}' for #{published_at}")
  end

  private

  def next_publish_date
    last_scheduled = Post.where(status: "scheduled").order(published_at: :desc).first
    base_date = if last_scheduled&.published_at&.future?
      last_scheduled.published_at.to_date + 1.day
    else
      Date.current
    end

    find_next_mwf(base_date)
  end

  def find_next_mwf(from_date)
    date = from_date
    date += 1.day until [1, 3, 5].include?(date.cwday)
    date.in_time_zone("Asia/Seoul").change(hour: 9)
  end
end
