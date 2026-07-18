class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_locale

  # Keep the current locale in generated URLs. Korean (default) has no prefix,
  # so we pass locale: nil for it and Rails omits the optional (:locale) segment.
  def default_url_options
    { locale: (I18n.locale == I18n.default_locale ? nil : I18n.locale) }
  end

  private

  # Priority: URL prefix (params[:locale]) → cookie → Accept-Language → default.
  # The route constraint only matches en/ja/es, so a bare path (no prefix) means
  # cookie/browser preference decides — Korean when none is set.
  def set_locale
    requested = params[:locale].presence || cookies[:locale].presence || locale_from_browser
    locale = available?(requested) ? requested.to_sym : I18n.default_locale
    I18n.locale = locale

    # Persist an explicit URL choice so the preference survives later navigation.
    if params[:locale].present? && available?(params[:locale])
      cookies[:locale] = { value: locale, expires: 1.year.from_now }
    end
  end

  def locale_from_browser
    accept_language = request.env["HTTP_ACCEPT_LANGUAGE"]
    return nil unless accept_language

    accept_language.scan(/[a-z]{2}/).find { |lang| available?(lang) }
  end

  def available?(locale)
    locale.present? && I18n.available_locales.map(&:to_s).include?(locale.to_s)
  end
end
