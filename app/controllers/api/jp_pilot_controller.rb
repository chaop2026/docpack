# app/controllers/api/jp_pilot_controller.rb
#
# Pilot sign-ups from the Japanese landing page (public/safe/jp/nyusatsu/).
#
#   POST /api/jp_pilot
#   { company, industry, monthly_count, authority, email, from, website }
#   → 201 { ok: true } | 422 { errors: [...] } | 429 { error: "rate_limited" }
#
# `website` is a honeypot: the form renders it, CSS hides it, a human never
# fills it. Anything in it means the submitter is not using the form, so the
# request is DROPPED — and answered with the same 201 a success gets, because a
# distinguishable rejection is a free oracle for tuning a spam script. The
# record is simply not written.
#
# The per-IP cap here is a different judgement from Api::SafeEventsController,
# which refuses to touch remote_ip at all. This endpoint already takes a name
# and an email address on purpose, so it is not an anonymous surface, and a
# submission form with no per-client ceiling is a mailbox flood waiting to
# happen. The IP is used for the cache key only — it is never written to the
# database, in any form.
module Api
  class JpPilotController < BaseController
    RATE_LIMIT  = 3
    RATE_WINDOW = 10.minutes

    def create
      return render(json: { error: "rate_limited" }, status: :too_many_requests) if throttled?

      # Honeypot. Looks like a success from the outside; writes nothing.
      if params[:website].present?
        Rails.logger.info("[jp_pilot] honeypot rejected a submission")
        return render(json: { ok: true }, status: :created)
      end

      req = JpPilotRequest.new(pilot_params)

      if req.save
        notify(req)
        render json: { ok: true }, status: :created
      else
        # Field NAMES, not rendered messages. The form is Japanese and the page
        # owns its own wording (public/safe/jp/jp.js); echoing
        # `errors.full_messages` would put the server's locale on a Japanese
        # page — and did: the first live check returned
        # "EmailTranslation missing. Options considered were: …" because the
        # format validator had no ko message. Returning keys makes that class of
        # leak impossible instead of fixing one instance of it.
        render json: { ok: false, errors: req.errors.attribute_names.map(&:to_s).uniq },
               status: :unprocessable_entity
      end
    end

    private

    def pilot_params
      params.permit(:company, :industry, :monthly_count, :authority, :email, :from)
            .to_h
            .transform_values { |v| v.to_s.strip }
            .tap { |h| h["from"] = "direct" unless JpPilotRequest::FROMS.include?(h["from"]) }
    end

    # The sign-up is already saved by the time this runs, so a mail failure must
    # not undo it or turn a stored request into a 422 the applicant sees. It is
    # logged and the response stays 201 — the row is the record of truth and the
    # admin list reads it without help from the mailer (the same reasoning as
    # PublishScheduledPostsJob's derived `publish_stuck` state).
    def notify(req)
      JpPilotMailer.pilot_requested(req).deliver_later
    rescue StandardError => e
      Rails.logger.error("[jp_pilot] notification enqueue failed for ##{req.id}: #{e.class}: #{e.message}")
    end

    # Atomic — see Api::BaseController#over_limit? for why the previous
    # read-then-write was not a cap at all under concurrency.
    def throttled?
      over_limit?("jp_pilot:#{request.remote_ip}", limit: RATE_LIMIT, window: RATE_WINDOW)
    end
  end
end
