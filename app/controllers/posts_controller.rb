class PostsController < ApplicationController
  def index
    @posts = Post.published.recent
    @posts = @posts.by_category(params[:category]) if params[:category].present?
    # page_meta lives in index.html.erb — a controller-side call is a silent
    # no-op here. See the comment at the top of that view.
  end

  def show
    @post = Post.where(status: [ "published", "scheduled", "draft" ]).find_by!(slug: params[:slug])
    @post.increment!(:view_count)
    @related_posts = Post.published.where(category: @post.category).where.not(id: @post.id).recent.limit(3)

    # Empty body or a locale we haven't actually translated into → don't index
    # this URL; point its canonical at the Korean original (see show.html.erb).
    # NOTE: page/meta tags are emitted from the view via content_for — content_for
    # set from a controller's `helpers` proxy does not reach the rendered layout.
    # Instance variables DO reach it, which is why @hreflang_locales is set here.
    #
    # The gate reads the locale off the URL, not off I18n.locale. set_locale
    # resolves a bare /blog/:slug through the cookie and then Accept-Language, so
    # keying on I18n.locale made the Korean canonical URL answer `noindex,follow`
    # to anyone sending `Accept-Language: en` — including any crawler that does.
    # Measured live 2026-09-17 on /blog/resume-privacy.
    @url_locale = (params[:locale].presence || I18n.default_locale).to_sym
    @post_translated = @post.translated?(@url_locale)

    # Only advertise the locales this post actually exists in. The default set
    # (all four) pointed at /en|ja|es/blog/:slug — URLs that carry noindex and
    # canonicalise back here, which is both self-contradictory and the route by
    # which Google discovered 126 no-index URLs. Matches the sitemap, which has
    # always used translated_locales.
    @hreflang_locales = @post.translated_locales
  end
end
