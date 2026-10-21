# Notifies Justin when someone signs up for the SafeFile JP pilot.
#
# The mail is a convenience, not the record: Api::JpPilotController saves the
# row first and logs (rather than raises) if the delivery cannot even be
# enqueued, and /admin/jp_pilot_requests reads the table directly. If SMTP is
# broken — which has happened here before (2026-04-07, empty GMAIL_PASSWORD →
# 535-5.7.8) — the sign-ups are still all there.
class JpPilotMailer < ApplicationMailer
  def pilot_requested(pilot_request)
    @req   = pilot_request
    @total = JpPilotRequest.count

    mail(
      to: "chaop2@gmail.com",
      subject: "[SafeFile JP] パイロット申込"
    )
  end
end
