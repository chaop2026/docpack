module ApplicationHelper
  LOCALE_NAMES = { ko: "한국어", en: "English", ja: "日本語", es: "Español" }.freeze
  OG_LOCALES   = { ko: "ko_KR", en: "en_US", ja: "ja_JP", es: "es_ES" }.freeze

  def base_url
    ENV.fetch("BASE_URL", "https://slimfile.net")
  end

  # `path` is the canonical unprefixed path (e.g. "/faq"); the current locale
  # prefix is applied so each localized page self-canonicalizes.
  def page_meta(title:, description:, path: nil, image: nil)
    canonical = path ? locale_prefixed(path) : request.path
    content_for(:meta_title, title)
    content_for(:meta_description, description)
    content_for(:meta_url, "#{base_url}#{canonical}")
    content_for(:meta_image, image || "#{base_url}/icon.png")
  end

  # Prepend the locale prefix to an unprefixed path (Korean/default stays bare).
  def locale_prefixed(path, locale = I18n.locale)
    return path if locale.to_sym == I18n.default_locale

    path == "/" ? "/#{locale}" : "/#{locale}#{path}"
  end

  # Native language name for the locale switcher.
  def locale_name(locale)
    LOCALE_NAMES[locale.to_sym] || locale.to_s
  end

  def og_locale(locale = I18n.locale)
    OG_LOCALES[locale.to_sym] || "en_US"
  end

  # Current request path with any locale prefix stripped (always starts with "/").
  def path_without_locale
    request.path.sub(%r{\A/(en|ja|es)(?=/|\z)}, "").presence || "/"
  end

  # Path for the current page under a given locale. Korean (default) is unprefixed.
  def localized_path(locale)
    locale_prefixed(path_without_locale, locale)
  end

  # Same as localized_path but preserves the query string (for the switcher links).
  def localized_url_path(locale)
    path = localized_path(locale)
    request.query_string.present? ? "#{path}?#{request.query_string}" : path
  end

  # [[locale, absolute_url], ...] for hreflang alternates (canonical, no query).
  def hreflang_alternates
    I18n.available_locales.map { |loc| [loc, "#{base_url}#{localized_path(loc)}"] }
  end
end
