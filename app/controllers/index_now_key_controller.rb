# Serves the IndexNow ownership key at /<key>.txt.
#
# ── Why this is a route and not a file in public/ ───────────────────────────
#
# IndexNow verifies ownership by fetching the key back from the site, so the
# key is PUBLIC by protocol design. It is still not committed, for two reasons
# that have nothing to do with secrecy:
#
#   1. chaop2026/docpack is a public repository with a permanent history. A
#      committed key cannot be rotated without a commit, and the old value
#      stays readable forever.
#   2. S11's instruction is that the value is read from ENV and never printed.
#      A file in the repository is printing it.
#
# Serving it from ENV["INDEXNOW_KEY"] also removes a way for the two halves to
# disagree: IndexNow.submit sends `keyLocation` derived from the same value, so
# the file Bing fetches and the key we send are the same string by
# construction rather than by somebody remembering to update both.
#
# A plain `==` comparison, not a constant-time one. The key is served to
# anybody who asks for it — that is the whole mechanism — so a timing-safe
# compare here would imply a secret and mislead the next reader.
class IndexNowKeyController < ApplicationController
  # No locale-dependent output, and — the reason this matters —
  # ApplicationController#set_locale writes a one-year `locale` cookie whenever
  # params[:locale] is present, and params includes the query string. A crawler
  # fetching /<key>.txt?locale=ja would be handed a cookie. Same finding as
  # Api::BaseController (S6b).
  skip_before_action :set_locale

  def show
    configured = IndexNow.key
    return head :not_found if configured.blank?

    requested = params[:indexnow_key].to_s.delete_suffix(".txt")
    return head :not_found unless requested == configured

    # text/plain is what the protocol expects. `plain:` so nothing in the
    # layout — which carries a GA tag and a nav — can end up in the file.
    render plain: configured, content_type: "text/plain"
  end
end
