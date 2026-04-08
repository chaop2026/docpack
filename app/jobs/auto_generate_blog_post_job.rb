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

    result.delete(:_generate_hero_image)
    post = Post.create!(
      **result.slice(:title_ko, :subtitle_ko, :body_ko, :meta_description_ko, :slug, :cover_svg,
                      :trust_bar, :pain_tag, :error_mockup, :recognition_text, :loss_items, :stats),
      category: topic.category,
      status: "scheduled",
      published_at: published_at
    )

    # 히어로 이미지 생성
    begin
      service.generate_hero_image(post)
    rescue => e
      Rails.logger.error("AutoGenerateBlogPostJob: Hero image failed for '#{post.slug}': #{e.message}")
    end

    topic.update!(used: true)
    Rails.logger.info("AutoGenerateBlogPostJob: Created scheduled post '#{post.slug}' for #{published_at} (image: #{post.hero_image.attached?})")
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
