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
end
