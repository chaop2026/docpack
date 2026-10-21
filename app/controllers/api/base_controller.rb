module Api
  # Shared base for the three JSON endpoints under /api/.
  #
  # It exists for one reason: `ApplicationController#set_locale` writes a
  # one-year `locale` cookie whenever `params[:locale]` is present, and
  # `params` includes the query string. That is correct for a page — the visitor
  # clicked a language — but on an API route it means
  #
  #     POST /api/safe_events?locale=ja   →  204 + Set-Cookie: locale=ja
  #
  # which was measured, not theorised. An endpoint whose entire purpose is to
  # count things WITHOUT identifying anyone must not be able to plant a
  # persistent cookie, and the page that calls it promises exactly that.
  #
  # Nothing under /api/ renders a localized response: safe_scan's prompts are
  # hardcoded, jp_pilot answers with field NAMES so the page can supply its own
  # Japanese wording, and safe_events answers with no body at all. So the locale
  # filter has nothing to contribute here beyond the side effect.
  #
  # CSRF verification is skipped for the same set, as it was before: these are
  # JSON endpoints called with fetch/sendBeacon from a static page that has no
  # Rails-rendered form and therefore no authenticity token to carry. None of
  # them read the session or act on behalf of a signed-in user, so there is no
  # authority for a cross-site request to borrow.
  class BaseController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :set_locale
  end
end
