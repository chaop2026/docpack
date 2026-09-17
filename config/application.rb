require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Docpack
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # i18n — 4 locales, Korean is default (no URL prefix)
    config.i18n.available_locales = %i[ko en ja es]
    config.i18n.default_locale = :ko
    config.i18n.fallbacks = [:ko]

    # Route deliver_later through a job that has a retry policy.
    #
    # The default is ActionMailer::MailDeliveryJob, which inherits from
    # ActiveJob::Base rather than ApplicationJob — so nothing declared on
    # ApplicationJob reaches mail delivery. Without this line, adding retries
    # "to the app's jobs" leaves outgoing mail exactly as fragile as before
    # while appearing to have covered it. See app/jobs/application_mail_delivery_job.rb.
    #
    # A string so it resolves after autoloading rather than at boot.
    config.action_mailer.delivery_job = "ApplicationMailDeliveryJob"

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
