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

  desc "Generate and immediately publish 1 test post from unused topic"
  task publish_test: :environment do
    # Seed topics if none exist
    if BlogTopic.count.zero?
      puts "No blog topics found. Seeding..."
      load Rails.root.join("db/seeds/blog_topics.rb")
    end

    topic = BlogTopic.unused.order("RANDOM()").first
    unless topic
      puts "ERROR: No unused topics remaining"
      exit 1
    end

    puts "Selected topic: #{topic.topic} (#{topic.category})"
    puts "Generating post via Claude API..."

    service = BlogGeneratorService.new
    result = service.generate_post(topic.topic, topic.category)

    unless result
      puts "ERROR: BlogGeneratorService returned nil — check ANTHROPIC_API_KEY"
      exit 1
    end

    post = Post.create!(
      title_ko: result[:title_ko],
      body_ko: result[:body_ko],
      meta_description_ko: result[:meta_description_ko],
      slug: result[:slug],
      cover_svg: result[:cover_svg],
      category: topic.category,
      status: "published",
      published_at: Time.current
    )
    topic.update!(used: true)

    puts "SUCCESS: Published '#{post.title_ko}' (slug: #{post.slug})"
    puts "  URL: /blog/#{post.slug}"
    puts "  Category: #{post.category}"
    puts "  Published at: #{post.published_at}"
  end

  desc "Verify auto-publish flow: run PublishScheduledPostsJob and report results"
  task verify_autopublish: :environment do
    scheduled = Post.where(status: "scheduled")
    ready = Post.scheduled_ready
    puts "Scheduled posts total: #{scheduled.count}"
    puts "Ready to publish (published_at <= now): #{ready.count}"

    ready.each do |p|
      puts "  Will publish: #{p.slug} (published_at: #{p.published_at})"
    end

    if ready.any?
      puts "\nRunning PublishScheduledPostsJob..."
      PublishScheduledPostsJob.perform_now
      puts "Done. Newly published posts:"
      ready.reload.each do |p|
        puts "  #{p.slug}: status=#{p.status}"
      end
    else
      puts "\nNo posts ready to publish. Pulling earliest scheduled post to now for testing..."
      earliest = scheduled.order(:published_at).first
      if earliest
        old_date = earliest.published_at
        earliest.update!(published_at: Time.current - 1.minute)
        puts "  Moved '#{earliest.slug}' from #{old_date} to #{earliest.published_at}"
        puts "Running PublishScheduledPostsJob..."
        PublishScheduledPostsJob.perform_now
        earliest.reload
        puts "  Result: #{earliest.slug} status=#{earliest.status}"
      else
        puts "  No scheduled posts exist at all."
      end
    end

    puts "\n--- Blog Status ---"
    puts "Published: #{Post.where(status: 'published').count}"
    puts "Scheduled: #{Post.where(status: 'scheduled').count}"
    puts "Draft: #{Post.where(status: 'draft').count}"
    Post.where(status: "scheduled").order(:published_at).limit(5).each do |p|
      puts "  Next: #{p.slug} → #{p.published_at}"
    end
  end

  desc "Regenerate scheduled posts with new prompt (max 5)"
  task regenerate_scheduled: :environment do
    service = BlogGeneratorService.new
    posts = Post.where(status: "scheduled").order(:published_at).limit(5)

    if posts.empty?
      puts "No scheduled posts to regenerate."
      next
    end

    puts "Regenerating #{posts.count} scheduled posts..."

    posts.each_with_index do |post, i|
      topic = BlogTopic.find_by(topic: post.title_ko, used: true) ||
              BlogTopic.where(category: post.category, used: true).first

      topic_text = topic&.topic || post.title_ko
      puts "[#{i + 1}/#{posts.count}] Regenerating: #{topic_text} (#{post.category})..."

      result = service.generate_post(topic_text, post.category)
      unless result
        puts "  FAILED — skipping"
        next
      end

      post.update!(
        title_ko: result[:title_ko],
        body_ko: result[:body_ko],
        meta_description_ko: result[:meta_description_ko],
        cover_svg: result[:cover_svg]
      )

      puts "  OK — updated '#{post.slug}' (published_at: #{post.published_at})"
      sleep 3 if i < posts.count - 1
    end

    puts "\nDone!"
  end

  desc "Generate 1 new post with new prompt and publish immediately"
  task publish_new: :environment do
    topic = BlogTopic.unused.order("RANDOM()").first
    unless topic
      puts "ERROR: No unused topics remaining"
      exit 1
    end

    puts "Selected topic: #{topic.topic} (#{topic.category})"
    puts "Generating post with psychology-based prompt..."

    service = BlogGeneratorService.new
    result = service.generate_post(topic.topic, topic.category)

    unless result
      puts "ERROR: BlogGeneratorService returned nil — check ANTHROPIC_API_KEY"
      exit 1
    end

    post = Post.create!(
      title_ko: result[:title_ko],
      body_ko: result[:body_ko],
      meta_description_ko: result[:meta_description_ko],
      slug: result[:slug],
      cover_svg: result[:cover_svg],
      category: topic.category,
      status: "published",
      published_at: Time.current
    )
    topic.update!(used: true)

    puts "SUCCESS: Published '#{post.title_ko}'"
    puts "  Slug: #{post.slug}"
    puts "  URL: https://slimfile.net/blog/#{post.slug}"
    puts "  Category: #{post.category}"
  end
end
