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

    if stuck.empty?
      puts "No stuck posts. (#{Post.where(status: 'scheduled').count} scheduled, all still within the #{Post::PUBLISH_GRACE.inspect} grace window.)"
      next
    end

    puts "#{stuck.size} post(s) past due and still scheduled:"
    stuck.each do |post|
      overdue = post.publish_overdue_by
      puts "  #{post.slug} (id=#{post.id})"
      puts "    scheduled : #{post.published_at&.iso8601 || '(none)'}#{overdue ? "  (#{(overdue / 3600).round} h ago)" : ''}"
      puts "    body_ko   : #{post.body_ko.present? ? "#{post.body_ko.to_s.length} bytes" : 'EMPTY — this is why a published post is rejected'}"
      puts "    reason    : #{post.publish_error.presence || '(not recorded — the job may never have reached this post)'}"
      puts "    edit      : /admin/posts/#{post.id}/edit"
    end

    abort "blog:stuck: #{stuck.size} post(s) need attention"
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
