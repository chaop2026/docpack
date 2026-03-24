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

  def about
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
