class LocalesController < ApplicationController
  def toggle
    new_locale = I18n.locale == :en ? :ko : :en
    cookies[:locale] = { value: new_locale, expires: 1.year.from_now }
    redirect_back fallback_location: root_path
  end
end
