# The single owner of the three SafeFile privacy guide posts.
#
# ── Why this task creates as well as updates (2026-09-18) ───────────────────
#
# It used to only update, and `db/seeds/safefile_posts.rb` did the creating.
# That split was the bug. The seed predated everything: its premise was that the
# body lived in `public/blog/<slug>/index.html`, so it created `published` posts
# with no body at all — and `9f8bfff` (2026-07-17) deleted that directory while
# this task moved the bodies into the database and RENAMED two of the slugs.
# The seed kept the pre-rename slugs, so on a migrated database it no longer
# recognised the posts it had made and tried to create body-less duplicates.
#
# Measured, on the development database, before this change: running the seed
# flipped `resume-privacy` from category `privacy` back to `student` and
# overwrote its title and meta_description with its own hardcoded values —
# including anything a person had edited in the admin — and did so *before*
# aborting on the next item. Two tasks owning the same three rows meant whichever
# ran last won.
#
# So the seed is gone and this task creates too. One owner, no argument.
#
# `db/blog_privacy/*.html` is the source for a body that is MISSING. It is not a
# source of truth for a body that exists: this file's own purpose was to make the
# database authoritative, and a task that restores a file's copy over an admin
# edit is a revert button wearing a migration's name. So an existing body is left
# exactly as it is, and only a blank one is filled.
#
# Safe to run any number of times. Locates records by either their old or new
# slug, so a half-migrated database converges.
#
#   Run on production after deploy (safe to repeat):
#     kamal app exec 'bin/rails blog:migrate_privacy'
#
namespace :blog do
  # match_slugs: slugs a record may currently have (old first-run, new re-run)
  # The titles and descriptions are only ever applied at CREATE time — see above.
  PRIVACY_GUIDES = [
    {
      match_slugs: %w[resume-privacy],
      slug: "resume-privacy",
      file: "resume-privacy.html",
      title_ko: "이력서 속 개인정보, 어디까지 써야 할까",
      title_en: "Personal Info on Your Resume: How Much Is Too Much?",
      meta_description_ko: "이력서에 주민등록번호, 집 주소, 생년월일까지 다 써야 할까요? 채용에 꼭 필요한 정보와 지워도 되는 개인정보 7가지, 그리고 안전하게 가리는 방법을 정리했습니다.",
      meta_description_en: "Do you really need your ID number, home address, and birth date on a resume? 7 pieces of personal info you can safely remove — and how to redact them."
    },
    {
      match_slugs: %w[rrn-masking resident-number-masking],
      slug: "resident-number-masking",
      file: "resident-number-masking.html",
      title_ko: "주민등록번호 마스킹, 뒷자리만 가리면 될까",
      title_en: "Masking Korean ID Numbers: Is Hiding the Back Digits Enough?",
      meta_description_ko: "주민등록번호 뒷자리에는 어떤 정보가 들어 있을까요? 서류 제출 전 주민번호를 올바르게 마스킹하는 방법과 등본·신분증 사본 제출 시 주의사항을 정리했습니다.",
      meta_description_en: "What's actually encoded in a Korean RRN? How to mask resident registration numbers correctly before submitting documents or ID copies."
    },
    {
      match_slugs: %w[contract-checklist contract-sharing-checklist],
      slug: "contract-sharing-checklist",
      file: "contract-sharing-checklist.html",
      title_ko: "계약서·서류를 보내기 전, 8가지 체크리스트",
      title_en: "8-Point Privacy Checklist Before Sharing Contracts & Documents",
      meta_description_ko: "부동산 계약서, 프리랜서 계약서, 급여명세서를 카톡이나 메일로 보내기 전에 확인해야 할 개인정보 체크리스트. 계좌번호, 도장, 서명까지 놓치기 쉬운 항목을 정리했습니다.",
      meta_description_en: "A privacy checklist for sharing lease contracts, freelance agreements, and pay stubs — account numbers, stamps, and signatures people forget to redact."
    }
  ].freeze

  # The category these three belong to. The seed used to say student/office/
  # freelancer, which is exactly the disagreement that made them flip back and
  # forth depending on which task ran last.
  PRIVACY_CATEGORY = "privacy"

  desc "Create or update the three SafeFile privacy guide posts (idempotent, single owner)"
  task migrate_privacy: :environment do
    rejected = []

    PRIVACY_GUIDES.each do |spec|
      body = Rails.root.join("db/blog_privacy", spec[:file]).read.strip
      post = Post.where(slug: spec[:match_slugs]).order(:id).first
      creating = post.nil?

      if creating
        post = Post.new(
          slug: spec[:slug],
          title_ko: spec[:title_ko],
          title_en: spec[:title_en],
          meta_description_ko: spec[:meta_description_ko],
          meta_description_en: spec[:meta_description_en],
          body_ko: body,
          category: PRIVACY_CATEGORY,
          status: "published",
          published_at: Time.zone.parse("2026-07-16 09:00:00 +09:00")
        )
      else
        # Only the fields this task owns. Title and description are deliberately
        # untouched: overwriting them is what the deleted seed did wrong.
        post.slug     = spec[:slug]
        post.category = PRIVACY_CATEGORY
        post.body_ko  = body if post.body_ko.blank?
        post.status   = "published" if post.status.blank?
        post.published_at ||= Time.current
      end

      unless creating || post.changed?
        puts "  = #{spec[:slug]} (id=#{post.id}) already current"
        next
      end

      # One bad spec must not stop the others, and this task is idempotent, so
      # re-running after a fix costs nothing.
      begin
        post.save!
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
        rejected << "#{spec[:slug]}: #{e.message}"
        warn "  ! #{spec[:slug]} rejected — #{e.message} — skipping"
        next
      end

      verb = creating ? "created" : "updated"
      puts "  ✓ #{spec[:slug]} (id=#{post.id}) #{verb} [#{post.saved_changes.keys.join(', ')}]"
    end

    puts "Done. privacy posts: #{Post.where(category: PRIVACY_CATEGORY).pluck(:slug).sort.join(', ')}"

    # Every spec got its turn first; now fail, because this runs under
    # `kamal app exec` and a data task that changed nothing must not exit 0.
    abort "blog:migrate_privacy: #{rejected.size} post(s) rejected — #{rejected.join(' | ')}" if rejected.any?
  end
end
