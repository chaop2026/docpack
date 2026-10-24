# Visibility for the two things this app used to fail at silently:
# posts that never got published, and background jobs that died.
#
# Both tasks are read-only and exit non-zero when they find something, so they
# work under `kamal app exec` and can be wired to a monitor later without
# changing anything.
namespace :blog do
  desc "List posts whose publish time has passed but which are still scheduled (exit 1 if any)"
  task stuck: :environment do
    # The command-line view of Post.publish_stuck — the same scope the
    # /admin/posts banner reads. This exists because every other channel has a
    # dependency the failure might have taken out: email needs SMTP (which
    # failed here 2026-04-07), the banner needs a browser and the admin
    # password. This needs a shell.
    stuck = Post.publish_stuck.order(:published_at)
    # The X thread is a SECOND way a week can half-happen: the blog post is live
    # and the thread never went out. Same reasoning as above — derived from the
    # row, so it survives a dead mailer and a dead queue — and reported here so
    # one shell command covers both.
    x_stuck = Post.x_stuck.order(:published_at)
    # A third way a JP week goes missing: the package was offered for review and
    # never approved, so it stayed a draft past its publish date. The weekly job
    # moves on to the next episode by design, which means no further mail is
    # coming about this one.
    unapproved = Post.jp_unapproved_overdue.order(:published_at)

    if stuck.empty? && x_stuck.empty? && unapproved.empty?
      puts "No stuck posts. (#{Post.where(status: 'scheduled').count} scheduled, all still within the #{Post::PUBLISH_GRACE.inspect} grace window.)"
      puts "No unfinished X threads. (#{Post.jp.count} jp packages)"
      next
    end

    if stuck.any?
      puts "#{stuck.size} post(s) past due and still scheduled:"
      stuck.each do |post|
        overdue = post.publish_overdue_by
        primary = post.primary_locale
        puts "  #{post.slug} (id=#{post.id}, primary_locale=#{primary})"
        puts "    scheduled : #{post.published_at&.iso8601 || '(none)'}#{overdue ? "  (#{(overdue / 3600).round} h ago)" : ''}"
        # The invariant is now "a published post has a title and body in its OWN
        # primary locale", so reporting body_ko for a Japanese package would say
        # EMPTY about a column that is empty on purpose.
        body = post.send(:"body_#{primary}")
        puts "    body_#{primary}   : #{body.present? ? "#{body.to_s.length} bytes" : 'EMPTY — this is why a published post is rejected'}"
        puts "    reason    : #{post.publish_error.presence || '(not recorded — the job may never have reached this post)'}"
        puts "    edit      : /admin/posts/#{post.id}/edit"
      end
    end

    if x_stuck.any?
      puts "" if stuck.any?
      puts "#{x_stuck.size} X thread(s) past due and not finished:"
      x_stuck.each do |post|
        x = post.package["x"] || {}
        tweets = x["tweets"] || []
        puts "  ep#{post.content_ep} #{post.slug} (id=#{post.id})"
        puts "    x.state   : #{x['state']}#{x['dry_run'] ? ' (DRY RUN)' : ''}"
        puts "    due_at    : #{x['due_at']}"
        puts "    tweets    : #{tweets.count { |t| t['state'] == 'done' }}/#{tweets.size} done" \
             "#{tweets.any? { |t| t['state'] == 'unknown' } ? "  ⚠ one is 'unknown' — a human must check the timeline" : ''}"
        puts "    error     : #{x['error'].presence || '(none recorded)'}"
        puts "    recover   : bin/rails blog:x_pending   |   /admin/jp/packages/#{post.content_ep}"
      end
    end

    if unapproved.any?
      puts ""
      puts "#{unapproved.size} JP package(s) past their publish date and still unapproved:"
      unapproved.each do |post|
        puts "  ep#{post.content_ep} #{post.slug} (id=#{post.id})"
        puts "    was due   : #{post.published_at&.in_time_zone('Asia/Tokyo')&.strftime('%Y-%m-%d %H:%M JST')}"
        puts "    guard     : #{post.guard_violations.size} violation(s)"
        puts "    approve   : /admin/jp/packages/#{post.content_ep}"
      end
    end

    abort "blog:stuck: #{stuck.size} post(s) + #{x_stuck.size} X thread(s) + " \
          "#{unapproved.size} unapproved JP package(s) need attention"
  end

  desc "Re-enqueue XPublishJob for every JP package whose thread is still pending (exit 0; prints what it did)"
  task x_pending: :environment do
    # The recovery path for a LOST ENQUEUE. PublishScheduledPostsJob writes
    # x.state='pending' at approval time and only then enqueues the job, so an
    # enqueue that fails (queue down, process killed between the two) leaves the
    # state saying "owed" with nothing scheduled to pay it. This re-enqueues
    # from the state.
    #
    # Safe to run repeatedly: XPublishJob takes a row lock, skips every tweet
    # already marked done, and refuses to move past an 'unknown' one without an
    # explicit human decision. Running it twice posts nothing twice.
    candidates = Post.jp.select do |p|
      state = p.package.dig("x", "state")
      state.in?(%w[pending partial_failed]) ||
        (state == "unknown" && p.package.dig("x", "resume_requested"))
    end

    if candidates.empty?
      puts "Nothing to re-enqueue. (#{Post.jp.count} jp packages; " \
           "#{Post.jp.count { |p| p.package.dig('x', 'state') == 'unknown' }} awaiting a human decision on an 'unknown' tweet)"
      next
    end

    candidates.each do |post|
      XPublishJob.perform_later(post.id)
      puts "re-enqueued ep#{post.content_ep} #{post.slug} (state=#{post.package.dig('x', 'state')})"
    end
    puts "#{candidates.size} re-enqueued. X_API_DRY_RUN=#{ENV['X_API_DRY_RUN'].inspect} → #{XClient.dry_run? ? 'DRY RUN (logs only)' : 'LIVE'}"
  end
end

namespace :jobs do
  desc "List Solid Queue failed executions (exit 1 if any)"
  task failed: :environment do
    # Solid Queue does not retry on its own: ClaimedExecution#perform calls
    # failed_with(error) and re-raises, and FailedExecution#retry is manual. So
    # anything in this table is work that stopped and stayed stopped — and until
    # now nothing in this app ever looked at it.
    # Guard on the TABLE, not on the constant. The gem is in the default bundle
    # group, so SolidQueue::FailedExecution is defined in every environment —
    # but only production sets `queue_adapter = :solid_queue`
    # (config/environments/production.rb:53) and only production has the queue
    # database, so in development the constant resolves and the query then dies
    # with PG::UndefinedTable. Measured, after writing it the other way first.
    unless defined?(SolidQueue::FailedExecution) && SolidQueue::FailedExecution.table_exists?
      puts "Solid Queue's queue database is not present here " \
           "(queue adapter: #{ActiveJob::Base.queue_adapter.class}). " \
           "This task is meaningful in production, where the adapter is :solid_queue."
      next
    end

    failures = SolidQueue::FailedExecution.includes(:job).order(created_at: :desc)

    if failures.empty?
      puts "No failed job executions."
      next
    end

    puts "#{failures.size} failed job execution(s), newest first:"
    failures.each do |failure|
      puts "  #{failure.job&.class_name || '(unknown job)'}  failed #{failure.created_at&.iso8601}"
      puts "    #{failure.exception_class}: #{failure.message}"
      puts "    job id #{failure.job_id}  —  retry with: SolidQueue::FailedExecution.find(#{failure.id}).retry"
    end

    abort "jobs:failed: #{failures.size} failed execution(s)"
  end
end
