class PostsController < ApplicationController
  def index
    # Scoped by track, not just by publication state. The two tracks are
    # different publications that happen to share a table: a Japanese episode
    # appearing in the Korean listing would put a Japanese headline in a Korean
    # index, and vice versa. /ja/blog is the Japanese blog; /blog, /en/blog and
    # /es/blog are the Korean one (/en and /es already showed the Korean posts'
    # English or fallback titles, and that is unchanged).
    @url_locale = helpers.url_locale
    @posts = (@url_locale == :ja ? Post.jp : Post.where.not(primary_locale: "ja")).published.recent
    @posts = @posts.by_category(params[:category]) if params[:category].present?
    # page_meta lives in index.html.erb — a controller-side call is a silent
    # no-op here. See the comment at the top of that view.
  end

  def show
    @post = Post.where(status: [ "published", "scheduled", "draft" ]).find_by!(slug: params[:slug])

    # The gate reads the locale off the URL, not off I18n.locale. set_locale
    # resolves a bare /blog/:slug through the cookie and then Accept-Language, so
    # keying on I18n.locale made the Korean canonical URL answer `noindex,follow`
    # to anyone sending `Accept-Language: en` — including any crawler that does.
    # Measured live 2026-09-17 on /blog/resume-privacy.
    @url_locale = helpers.url_locale

    # A Japanese post's address is /ja/blog/:slug. The unprefixed spelling is the
    # KOREAN blog's address, so for a JP post it is a second URL serving the same
    # document — the duplicate shape this repository has already been penalised
    # for twice (GSC: /safe/ "duplicate without user-selected canonical",
    # /en/about folded by Google). A canonical tag would ask Google to pick; a
    # 301 does not ask.
    #
    # Only the bare path redirects. /en/blog/:slug is a real alternate when
    # body_en exists, and /es/blog/:slug falls back exactly the way a Korean
    # post's /ja URL does today — rendered, noindex, canonical at the original.
    if @post.primary_locale == "ja" && @url_locale == I18n.default_locale
      redirect_to "/ja/blog/#{@post.slug}", status: :moved_permanently, allow_other_host: false
      return
    end

    @post.increment!(:view_count)
    # Related posts stay inside one track for the same reason the listing does.
    @related_posts = Post.published
                         .where(category: @post.category, primary_locale: @post.primary_locale)
                         .where.not(id: @post.id).recent.limit(3)

    # Empty body or a locale we haven't actually translated into → don't index
    # this URL; point its canonical at the post's primary-locale original
    # (see show.html.erb).
    # NOTE: page/meta tags are emitted from the view via content_for — content_for
    # set from a controller's `helpers` proxy does not reach the rendered layout.
    # Instance variables DO reach it, which is why @hreflang_locales is set here.
    @post_translated = @post.translated?(@url_locale)

    # The robots gate. Post#indexable? folds in publication state, which the old
    # gate never looked at: a draft or scheduled post with a Korean body came
    # back 200 with no noindex, so an unpublished article was an indexable
    # public page. The 200 stays — preview still works — and only the directive
    # changes. The signal table lives on Post#indexable?.
    @post_indexable = @post.indexable?(@url_locale)

    # Only advertise the locales this post can actually be indexed under. The
    # default set (all four) pointed at /en|ja|es/blog/:slug — URLs that carry
    # noindex and canonicalise back here, which is both self-contradictory and
    # the route by which Google discovered 126 no-index URLs. Unpublished posts
    # advertise nothing at all: [] is a real answer, not "unspecified".
    @hreflang_locales = @post.indexable_locales

    # x-default must name the post's own primary-locale URL. The layout's
    # default — the unprefixed path — is the Korean address, which for a
    # Japanese post is a 301 and therefore can never be an hreflang target.
    @xdefault_url = "#{helpers.base_url}#{@post.canonical_path_for(@post.primary_locale_sym)}"

    # The language switcher offers only the locales this post has text in.
    # Korean posts keep the full set (they fall back to Korean under every
    # shell, which is the behaviour the 42 live posts have always had); a
    # Japanese post has no Korean or Spanish version at all, and the bare
    # /blog/:slug its 「한국어」 entry pointed at is a 301 straight back here.
    @switcher_locales = [ :ja, :en ] if @post.primary_locale == "ja"

    # FAQ for the JSON-LD FAQPage block. Only present on JP packages, and only
    # emitted when it actually has entries — an empty FAQPage is a structured
    # claim about a section the page does not have.
    @faq = @post.package_faq
  end
end
