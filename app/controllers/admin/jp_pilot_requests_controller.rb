module Admin
  # Read-only list of SafeFile JP pilot sign-ups.
  #
  # Read-only on purpose: the mail notification can fail (SMTP has failed here
  # before), so this page is the channel that cannot, and a list that cannot
  # delete or edit cannot lose a sign-up either. Follow-up state lives in
  # docs/jp/outreach_log.md, where it is reviewable in git.
  class JpPilotRequestsController < BaseController
    def index
      @requests = JpPilotRequest.recent
    end
  end
end
