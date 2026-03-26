class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_locale

  private

  def set_locale
    I18n.locale = cookies[:locale]&.to_sym || locale_from_browser || I18n.default_locale
  end

  def locale_from_browser
    accept_language = request.env["HTTP_ACCEPT_LANGUAGE"]
    return nil unless accept_language
    accept_language.scan(/[a-z]{2}/).find { |lang| %w[ko en].include?(lang) }&.to_sym
  end
end
