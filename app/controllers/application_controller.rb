class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_locale

  private

  def set_locale
    I18n.locale = cookies[:locale]&.to_sym || I18n.default_locale
  end
end
