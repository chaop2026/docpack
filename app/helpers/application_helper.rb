module ApplicationHelper
  LOCALE_NAMES = { ko: "한국어", en: "English", ja: "日本語", es: "Español" }.freeze
  # The prefixes that appear in a URL. Must stay in step with the route
  # constraint in config/routes.rb (`scope "(:locale)", locale: /en|ja|es/`) —
  # Korean is the default and never carries a prefix.
  LOCALE_PREFIX = %r{\A/(en|ja|es)(?=/|\z)}.freeze
  OG_LOCALES   = { ko: "ko_KR", en: "en_US", ja: "ja_JP", es: "es_ES" }.freeze

  def base_url
    ENV.fetch("BASE_URL", "https://slimfile.net")
  end

  # The locale the URL itself declares, ignoring cookie / Accept-Language
  # negotiation. Every indexing signal must be derived from this rather than from
  # I18n.locale: set_locale resolves a *bare* path through the cookie and then
  # Accept-Language, so the same URL used to answer different crawlers
  # differently — GET /faq with `Accept-Language: en` declared its canonical to
  # be /en/faq, and GET /blog/:slug with the same header came back noindex.
  # A URL has to send one answer to everyone.
  def url_locale
    m = request.path.match(LOCALE_PREFIX)
    m ? m[1].to_sym : I18n.default_locale
  end

  # `path` is the canonical unprefixed path (e.g. "/faq"); the URL's own locale
  # prefix is applied so each localized page self-canonicalizes.
  # `canonical` (when given) is an absolute path already resolved to the correct
  # locale — used to point untranslated blog pages at the Korean original.
  def page_meta(title:, description:, path: nil, image: nil, canonical: nil)
    canonical_path = canonical || (path ? locale_prefixed(path, url_locale) : request.path)
    content_for(:meta_title, title)
    content_for(:meta_description, description)
    content_for(:meta_url, "#{base_url}#{canonical_path}")
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
    request.path.sub(LOCALE_PREFIX, "").presence || "/"
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

  # Path used by the language switcher. The default (Korean) locale has no URL
  # prefix, so a bare path is ambiguous with a stale `locale` cookie and
  # set_locale would keep the previous language. Make the choice explicit with
  # ?locale=ko (read with top priority by set_locale, which then persists it).
  # Non-default locales are unambiguous via their prefix; we only carry over any
  # existing non-locale query (e.g. ?category=privacy).
  def locale_switch_path(locale)
    base = localized_path(locale)
    query = request.query_parameters.except("locale")
    query["locale"] = locale if locale.to_sym == I18n.default_locale
    query.present? ? "#{base}?#{query.to_query}" : base
  end

  # [[locale, absolute_url], ...] for hreflang alternates (canonical, no query).
  #
  # `locales` narrows the set for pages that do not genuinely exist in every UI
  # language. Blog posts are the case: the UI chrome is translated but the body
  # is not, so /ja/blog/:slug serves the Korean article under a Japanese shell —
  # it carries noindex and canonicalises to the Korean URL. Advertising it as
  # the Japanese alternate contradicts both of those signals (Google requires
  # hreflang targets to be canonical and indexable) and is how those URLs get
  # discovered in the first place. The sitemap has always used the narrowed set
  # (Post#translated_locales); this makes the page agree with it.
  # nil means "not specified" → every UI locale. An empty array is a real answer
  # ("this page exists in no locale yet") and must stay empty rather than fall
  # back to all four.
  def hreflang_alternates(locales = nil)
    (locales.nil? ? I18n.available_locales : locales)
      .map { |loc| [loc, "#{base_url}#{localized_path(loc)}"] }
  end
end
