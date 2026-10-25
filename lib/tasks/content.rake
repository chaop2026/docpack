require "digest"

# Registers one JP episode's package as a blog post.
#
#   bin/rails content:jp_import[1]
#
# Reads content/jp/epNN/ (written on a Mac by Claude Code + make_episode.mjs)
# and upserts a Post keyed on (content_track='jp', content_ep=NN).
#
# ── Exit codes ──────────────────────────────────────────────────────────────
#   0  imported, updated, or already up to date ("unchanged" — nothing written)
#   1  the episode cannot be imported at all: missing folder, blocked topic,
#      unparseable file, or it fails input validation (no title, no prose, no
#      tweets). This is "there is no package here", NOT "the package breaks a
#      writing rule" — a guard violation imports fine and exits 0, it just
#      leaves the approval button disabled.
#   2  refused: the package is already APPROVED or past draft.
#
# Code 2 is the interesting one. Cross-review Q2: approval has to mean "this
# exact text, these exact assets, at this exact time", and an import that
# silently replaced the body of an approved package would publish something
# nobody approved while the admin page went on showing a green checkmark. So
# approval freezes the row, and a later import reports the collision instead of
# resolving it. The human un-approves (差し戻す) and re-runs.
#
# What "refused" writes, precisely: the body, title, assets, status and
# approval fingerprint are untouched, and `package.import_conflict` — one key —
# is added so the admin page can name the version on disk that was refused.
# The earlier wording, "nothing was written", was wrong about that one key.
#
# The enforcement lives in JpImport#apply! under the row lock, not here. The
# check below is a fast-fail with a readable message; the service is the judge.
namespace :content do
  JP_TRACK = "jp".freeze

  # `package` keys this task MUST NOT touch. Each is owned by something that
  # knows a fact the files on disk do not:
  #   x, posted      — what has actually been published (tweet ids!). Losing
  #                    these would mean posting a thread twice.
  #   approved_at    — a human's decision, and the moment it was made.
  #   approved_version — the fingerprint that decision was made against.
  #   guard          — recomputed below, but by the guard, not copied from disk.
  IMPORT_NEVER_WRITES = %w[x posted approved_at approved_version].freeze

  desc "Import content/jp/epNN into a Post (upsert by content_track=jp, content_ep=NN)"
  task :jp_import, [ :ep ] => :environment do |_t, args|
    ep = args[:ep].to_i
    abort "usage: bin/rails content:jp_import[NN]" unless ep.positive?

    plan = JSON.parse(Rails.root.join("content", "jp", "topics.json").read)
    topic_row = plan["episodes"].find { |e| e["ep"] == ep }
    abort "ep#{ep} is not in content/jp/topics.json" unless topic_row

    # A blocked episode refuses to import for the same reason make_episode.mjs
    # refuses to build it: the piece describes something that does not exist.
    if topic_row["blocked_until"].present?
      abort "ep#{ep} is blocked until #{topic_row['blocked_until']} — refusing to import " \
            "(#{topic_row['note']})"
    end

    dir = Rails.root.join("content", "jp", format("ep%02d", ep))
    abort "#{dir} does not exist — run `node scripts/content/make_episode.mjs #{ep}` first" unless dir.directory?

    source = JpEpisodeSource.new(dir: dir, topic_row: topic_row, ep: ep)
    # Input validation, not content rules. A missing title or an empty body is
    # not a package with a problem — it is not a package, and importing it would
    # create a row nothing can explain. Exit 1 here is deliberately a different
    # answer from a guard violation (exit 0, approval disabled).
    begin
      source.validate!
    rescue JpEpisodeSource::InvalidEpisode => e
      abort "ep#{ep}: #{e.message}"
    end

    topic = JpImport.upsert_topic!(topic_row)
    post, created = JpImport.find_or_create_post!(ep: ep, source: source)

    # The freeze is enforced INSIDE JpImport#apply!, under the row lock — this
    # early check only exists to fail fast and print a useful message. It is not
    # load-bearing: an approval landing between here and the write is caught by
    # the service, which is the point of cross-review Q2.
    post.reload
    unless JpImport.writable?(post)
      warn "ep#{ep}: 承認された(または公開段階の)パッケージと衝突 — " \
           "admin で 差し戻す してから再実行してください " \
           "(status=#{post.status}, approved_at=#{post.package['approved_at'].inspect}, " \
           "content_hash=#{source.content_hash})"
      JpImport.record_conflict!(post, source)
      exit 2
    end

    outcome = JpImport.apply!(post: post, source: source, topic: topic)
    post.reload

    if outcome == :conflict
      # The race the early check cannot see: approved between the check above
      # and the lock inside the service.
      warn "ep#{ep}: 直前に承認されました — 何も書いていません " \
           "(status=#{post.status}, approved_at=#{post.package['approved_at'].inspect})"
      exit 2
    end

    if outcome == :unchanged
      puts "ep#{format('%02d', ep)}: unchanged — disk and row already agree " \
           "(content_hash=#{source.content_hash.first(12)}). Nothing was written."
      next
    end

    puts "ep#{format('%02d', ep)}: #{created ? 'created' : 'updated'} Post ##{post.id} " \
         "slug=#{post.slug} status=#{post.status}"
    puts "  title_ja  : #{post.title_ja}"
    puts "  body_ja   : #{post.body_ja.to_s.length} chars of HTML"
    puts "  body_en   : #{post.body_en.present? ? "#{post.body_en.length} chars" : '(none)'}"
    puts "  hero      : #{post.hero_image.attached? ? post.hero_image.filename : '(none)'}"
    puts "  assets    : #{post.package_assets.map { |a| a.filename.to_s }.join(', ').presence || '(none)'}"
    puts "  x_thread  : #{post.package_x_thread.length} tweets"
    puts "  faq       : #{post.package_faq.length} entries"
    puts "  linkedin  : #{post.package['linkedin_text'].to_s.length} chars"
    puts "  publish_on: #{topic.publish_on} (blog 09:00 JST)"
    violations = post.guard_violations
    if violations.any?
      puts "  guard     : #{violations.length} VIOLATION(S) — 承認ボタンは無効です"
      violations.each { |v| puts "    - #{v}" }
    else
      puts "  guard     : clean"
    end
  end

  desc "Import every episode that has a content/jp/epNN folder"
  task jp_import_all: :environment do
    Dir[Rails.root.join("content", "jp", "ep*").to_s].sort.each do |d|
      ep = File.basename(d).delete_prefix("ep").to_i
      next unless ep.positive?

      system(RbConfig.ruby, Rails.root.join("bin", "rails").to_s, "content:jp_import[#{ep}]")
    end
  end
end
