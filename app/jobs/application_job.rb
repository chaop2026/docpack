# Retry policy for this app's own jobs.
#
# ── What the queue actually does (read from the gem, not assumed) ───────────
#
# Solid Queue does NOT retry on its own. SolidQueue::ClaimedExecution#perform
# calls `failed_with(result.error)` and re-raises immediately
# (solid_queue-1.4.0/app/models/solid_queue/claimed_execution.rb:65-73), and
# SolidQueue::FailedExecution#retry is a manual operation — something a human or
# a task has to invoke (failed_execution.rb:21-29). Every retry in this app
# therefore comes from ActiveJob's retry_on and nowhere else.
#
# Until 2026-09-18 both declarations here were commented-out scaffold, so
# `ApplicationJob.rescue_handlers` was literally `[]` (verified at runtime): a
# job that raised got ZERO retries and went straight into
# solid_queue_failed_executions, which nothing in this app read. `rake
# jobs:failed` now reads it.
#
# ── The mailer is NOT covered by this class ─────────────────────────────────
#
# ActionMailer::MailDeliveryJob inherits from ActiveJob::Base, not from
# ApplicationJob (verified: its ancestors are [MailDeliveryJob, ActiveJob::Base,
# …]). So nothing here affects `deliver_later`, and simply uncommenting those
# scaffold lines — the obvious "fix" — would have left mail delivery exactly as
# fragile while looking like it had been handled. Mail has its own policy in
# ApplicationMailDeliveryJob, wired up via config.action_mailer.delivery_job.
#
# ── Where the retries are declared, and why not here ────────────────────────
#
# Retrying is only safe for a job that can run twice without DOING anything
# twice, and that is a per-job property. It is deliberately not declared on this
# class, even though the scaffold invites exactly that:
#
#   * PublishScheduledPostsJob — retries the two transient database errors.
#     Replaying it is a no-op for work already done: Post.scheduled_ready stops
#     returning a post the moment it is published, so a second pass neither
#     re-publishes nor re-notifies anything.
#   * AutoGenerateBlogPostJob — takes NO retries, by omission and on purpose.
#     It spends Claude API credit and creates a Post, and a failure partway
#     through (say after Post.create! but before topic.update!) would on replay
#     pay for a second article and leave a duplicate slugged `-1`. When it
#     fails, it fails visibly (rake jobs:failed) and a human decides whether the
#     work is worth paying for again.
#
# A blanket `retry_on` here would quietly hand the second job the first job's
# policy. Anything shared belongs below; anything conditional belongs in the job
# that can actually answer the question.
class ApplicationJob < ActiveJob::Base
  # Safe for every job: the record the job was enqueued for no longer exists, so
  # no retry can ever succeed. Discarded rather than left to fail repeatedly —
  # but logged, because a job pointing at a deleted record usually means
  # something upstream deleted more than it meant to.
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.error("#{job.class}: discarded — the record no longer exists (#{error.class}: #{error.message})")
  end
end
