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

    rejected = []

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
        # The `next` above already establishes that one bad spec must not stop
        # the others. A rejected record follows the same rule — and this task is
        # idempotent, so re-running after a fix costs nothing.
        begin
          post.save!
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
          rejected << "#{spec[:slug]}: #{e.message}"
          warn "  ! #{spec[:slug]} (id=#{post.id}) rejected — #{e.message} — skipping"
          next
        end
        puts "  ✓ #{spec[:slug]} (id=#{post.id}) updated [#{post.saved_changes.keys.join(', ')}]"
      else
        puts "  = #{spec[:slug]} (id=#{post.id}) already current"
      end
    end

    puts "Done. privacy posts: #{Post.where(category: 'privacy').pluck(:slug).sort.join(', ')}"

    # Every spec got its turn first; now fail, because this task is on the
    # post-deploy command list and a migration that silently migrated nothing
    # must not exit 0. (A missing record is NOT a failure — the task is
    # idempotent and a fresh DB legitimately has nothing to migrate yet.)
    abort "blog:migrate_privacy: #{rejected.size} post(s) rejected — #{rejected.join(' | ')}" if rejected.any?
  end
end
