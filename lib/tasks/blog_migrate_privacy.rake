# Idempotent migration of the three static SafeFile guide posts into the DB.
#
# The Korean bodies used to live as standalone static HTML under public/blog/,
# duplicating DB Post records that had empty bodies. This task makes the DB the
# single source of truth: it copies each Korean body in, renames the slug to the
# descriptive value, and files the post under the `privacy` category.
#
# Safe to run any number of times — it always sets fields to their target value
# and locates records by either their old or new slug.
#
#   Run once on production after deploy:
#     kamal app exec 'bin/rails blog:migrate_privacy'
#
namespace :blog do
  desc "Migrate static SafeFile privacy guides into DB posts (idempotent)"
  task migrate_privacy: :environment do
    # match_slugs: slugs a record may currently have (old first-run, new re-run)
    posts = [
      { match_slugs: %w[resume-privacy],
        slug: "resume-privacy", file: "resume-privacy.html" },
      { match_slugs: %w[rrn-masking resident-number-masking],
        slug: "resident-number-masking", file: "resident-number-masking.html" },
      { match_slugs: %w[contract-checklist contract-sharing-checklist],
        slug: "contract-sharing-checklist", file: "contract-sharing-checklist.html" }
    ]

    posts.each do |spec|
      post = Post.where(slug: spec[:match_slugs]).order(:id).first
      unless post
        warn "  ! no post found for #{spec[:match_slugs].inspect} — skipping"
        next
      end

      body = Rails.root.join("db/blog_privacy", spec[:file]).read.strip

      post.slug     = spec[:slug]
      post.category = "privacy"
      post.body_ko  = body
      post.status   = "published" if post.status.blank?
      post.published_at ||= Time.current

      if post.changed?
        post.save!
        puts "  ✓ #{spec[:slug]} (id=#{post.id}) updated [#{post.saved_changes.keys.join(', ')}]"
      else
        puts "  = #{spec[:slug]} (id=#{post.id}) already current"
      end
    end

    puts "Done. privacy posts: #{Post.where(category: 'privacy').pluck(:slug).sort.join(', ')}"
  end
end
