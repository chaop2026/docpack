# Retry policy for outgoing mail.
#
# This class exists because ActionMailer::MailDeliveryJob inherits from
# ActiveJob::Base, NOT from ApplicationJob (verified at runtime: its ancestors
# are [ActionMailer::MailDeliveryJob, ActiveJob::Base, …]). Anything declared on
# ApplicationJob is therefore invisible to `deliver_later`, which is a trap: the
# obvious way to "add a retry policy to this app" is to uncomment the scaffold
# lines in ApplicationJob, and that would leave mail delivery untouched while
# looking finished.
#
# Wired up by config.application.rb via config.action_mailer.delivery_job.
#
# ── Why retry at all ────────────────────────────────────────────────────────
#
# Because SMTP has already failed here in production: 2026-04-07, a missing
# GMAIL_PASSWORD produced SMTPAuthenticationError 535-5.7.8. Solid Queue does
# not retry on its own (see ApplicationJob for the source), so before this
# every transient SMTP hiccup dropped a message permanently into
# solid_queue_failed_executions.
#
# ── What is NOT delegated to this ───────────────────────────────────────────
#
# A retry makes a lost message less likely; it does not make delivery a
# dependable channel. 535-5.7.8 was a *configuration* error — no number of
# retries would have delivered it. That is why the publish-failure signal does
# not live in email at all: Post.publish_stuck derives it from the posts table,
# and `rake blog:stuck` reads it without any mail involved. Mail is the nag, not
# the record.
class ApplicationMailDeliveryJob < ActionMailer::MailDeliveryJob
  # Transient SMTP and network conditions: the connection failed or the server
  # asked us to come back later. Spread out, because a mail server refusing
  # connections rarely recovers in a second.
  retry_on Net::SMTPServerBusy,
           Net::OpenTimeout,
           Net::ReadTimeout,
           IOError,
           Errno::ECONNRESET,
           Errno::ECONNREFUSED,
           Errno::EHOSTUNREACH,
           Errno::ETIMEDOUT,
           wait: :polynomially_longer,
           attempts: 5

  # Permanent refusals are NOT retried. A bad address or a rejected credential
  # (535-5.7.8 is exactly this) fails identically every time, so retrying only
  # delays the failure being recorded — and it must be recorded, because the
  # April incident was invisible for as long as nobody looked.
  rescue_from Net::SMTPAuthenticationError,
              Net::SMTPFatalError,
              Net::SMTPSyntaxError do |error|
    Rails.logger.error(
      "ApplicationMailDeliveryJob: mail permanently rejected, not retrying — " \
      "#{error.class}: #{error.message}"
    )
    raise error
  end
end
