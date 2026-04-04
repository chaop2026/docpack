class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("GMAIL_USERNAME", "noreply@slimfile.net")
  layout "mailer"
end
