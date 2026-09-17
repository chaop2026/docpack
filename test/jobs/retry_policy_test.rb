# frozen_string_literal: true

require "test_helper"

# What the retry policy is, pinned where it can be checked.
#
# Two facts make this worth asserting rather than trusting:
#
#   1. Solid Queue does not retry on its own. SolidQueue::ClaimedExecution#perform
#      calls failed_with(error) and re-raises (claimed_execution.rb:65-73), and
#      FailedExecution#retry is a manual operation. Every retry in this app comes
#      from ActiveJob's retry_on and nowhere else, so an empty policy means zero
#      retries — which is what ApplicationJob had until 2026-09-18, its
#      declarations being commented-out scaffold.
#   2. ActionMailer::MailDeliveryJob inherits from ActiveJob::Base, NOT from
#      ApplicationJob. Declaring retries on ApplicationJob therefore does nothing
#      for deliver_later, which is the trap: the obvious fix looks complete and
#      leaves mail exactly as fragile.
class RetryPolicyTest < ActiveSupport::TestCase
  def handlers_for(klass)
    klass.rescue_handlers.map(&:first)
  end

  # ── the premise these tests exist for ───────────────────────────────────

  test "the mail delivery job does not inherit ApplicationJob" do
    # If this ever becomes false, the separate ApplicationMailDeliveryJob is
    # redundant — and if it silently stayed false while someone moved the
    # policy onto ApplicationJob, mail would lose its retries without a word.
    assert_not ActionMailer::MailDeliveryJob <= ApplicationJob
    assert_includes ActionMailer::MailDeliveryJob.ancestors, ActiveJob::Base
  end

  test "deliver_later is routed through the job that has a mail policy" do
    assert_equal "ApplicationMailDeliveryJob", ActionMailer::Base.delivery_job.to_s
    assert ApplicationMailDeliveryJob <= ActionMailer::MailDeliveryJob
  end

  # ── ApplicationJob: shared policy only ──────────────────────────────────

  test "ApplicationJob discards jobs whose record is gone and declares nothing else" do
    handlers = handlers_for(ApplicationJob)

    assert_includes handlers, "ActiveJob::DeserializationError"
    # Retries are per-job on purpose: a blanket retry here would hand
    # AutoGenerateBlogPostJob a policy that costs Claude API credit.
    assert_not_includes handlers, "ActiveRecord::Deadlocked"
    assert_not_includes handlers, "ActiveRecord::ConnectionNotEstablished"
  end

  # ── per-job policy ──────────────────────────────────────────────────────

  test "the publish job retries transient database errors" do
    handlers = handlers_for(PublishScheduledPostsJob)

    assert_includes handlers, "ActiveRecord::Deadlocked"
    assert_includes handlers, "ActiveRecord::ConnectionNotEstablished"
  end

  test "the generate job takes no retries at all" do
    # Not idempotent in two ways that cost money: it calls the paid Claude API
    # before writing anything, and a failure between Post.create! and
    # topic.update! would on replay pay for a second article and leave a
    # duplicate slugged `-1`.
    own = AutoGenerateBlogPostJob.rescue_handlers - ApplicationJob.rescue_handlers
    assert_empty own.map(&:first),
      "AutoGenerateBlogPostJob must not gain retries without someone deciding to pay for them"

    assert_not_includes handlers_for(AutoGenerateBlogPostJob), "ActiveRecord::Deadlocked"
  end

  # ── mail policy ─────────────────────────────────────────────────────────

  test "mail retries transient SMTP conditions" do
    handlers = handlers_for(ApplicationMailDeliveryJob)

    assert_includes handlers, "Net::SMTPServerBusy"
    assert_includes handlers, "Errno::ECONNREFUSED"
    assert_includes handlers, "Net::OpenTimeout"
  end

  test "mail does not retry a permanent rejection" do
    # 535-5.7.8 — the error this app actually hit on 2026-04-07 — was a bad
    # credential. No number of retries would have delivered it, and retrying
    # only delays the failure being recorded.
    handlers = handlers_for(ApplicationMailDeliveryJob)
    assert_includes handlers, "Net::SMTPAuthenticationError"

    # Declared as rescue_from that re-raises, not retry_on: the job must still
    # end up in Solid Queue's failed executions.
    #
    # Asserted on the identical object. Writing this as
    # `assert_raises(...) { handler_call || raise(SameError) }` would pass even
    # if the handler swallowed the error, because the test itself would supply
    # the exception — a check that cannot fail is not a check.
    error = Net::SMTPAuthenticationError.new("535-5.7.8 Username and Password not accepted")
    raised = nil
    begin
      ApplicationMailDeliveryJob.new.rescue_with_handler(error)
    rescue StandardError => e
      raised = e
    end

    assert_same error, raised, "the handler must re-raise the original error, not swallow it"
  end

  test "a permanent mail rejection is logged before it is re-raised" do
    original = Rails.logger
    buffer = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(buffer)

    begin
      ApplicationMailDeliveryJob.new.rescue_with_handler(
        Net::SMTPAuthenticationError.new("535-5.7.8 Username and Password not accepted")
      )
    rescue Net::SMTPAuthenticationError
      # expected
    ensure
      Rails.logger = original
    end

    assert_match(/permanently rejected, not retrying/, buffer.string)
    assert_match(/535-5\.7\.8/, buffer.string)
  end
end
