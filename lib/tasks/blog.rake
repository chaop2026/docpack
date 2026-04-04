namespace :blog do
  desc "Generate N blog posts from unused topics (default: 10)"
  task :generate, [:count] => :environment do |_t, args|
    count = (args[:count] || 10).to_i
    service = BlogGeneratorService.new
    generated = 0

    count.times do |i|
      topic = BlogTopic.unused.order("RANDOM()").first
      unless topic
        puts "No more unused topics available. Generated #{generated} posts."
        break
      end

      puts "[#{i + 1}/#{count}] Generating: #{topic.topic} (#{topic.category})..."

      result = service.generate_post(topic.topic, topic.category)
      unless result
        puts "  FAILED — skipping"
        next
      end

      last_scheduled = Post.where(status: "scheduled").order(published_at: :desc).first
      base_date = if last_scheduled&.published_at&.future?
        last_scheduled.published_at.to_date + 1.day
      else
        Date.current
      end

      date = base_date
      date += 1.day until [1, 3, 5].include?(date.cwday)
      published_at = date.in_time_zone("Asia/Seoul").change(hour: 9)

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
      generated += 1
      puts "  OK — '#{post.slug}' scheduled for #{published_at.strftime('%Y-%m-%d %H:%M %Z')}"

      sleep 2 if i < count - 1
    end

    puts "\nDone! Generated #{generated} posts total."
  end

  desc "Seed blog topics from db/seeds/blog_topics.rb"
  task seed_topics: :environment do
    load Rails.root.join("db/seeds/blog_topics.rb")
  end
end
