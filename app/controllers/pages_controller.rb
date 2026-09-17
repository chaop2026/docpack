class PagesController < ApplicationController
  def home
  end

  def compress
  end

  def pdf
  end

  def social
    @presets = SocialResizer::PRESETS
  end

  # The about copy is hardcoded English — about.html.erb contains no t() calls
  # and config/locales has no `about.*` keys — so /about, /en/about, /ja/about
  # and /es/about all serve the same document. Measured live 2026-09-17: the
  # four are 92-94% identical, against 28-38% for /faq, /compress and /, which
  # really are translated. Search Console had already folded them, reporting
  # /en/about as a duplicate whose canonical Google chose for itself.
  #
  # One document gets one indexable URL, the same rule blog posts follow for
  # locales they were never translated into: the prefixed variants canonicalise
  # to /about and carry noindex (see about.html.erb), and the sitemap lists only
  # /about. No hreflang at all — an English-only page makes no language claim,
  # and declaring itself the Korean or Japanese alternate would be a false one.
  def about
    @hreflang_locales = []
  end

  def faq
    @faq_items = t("faq.items")
  end

  def sitemap
    @base_url = helpers.base_url
    respond_to do |format|
      format.xml
    end
  end
end
