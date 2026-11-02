class PostsController < ApplicationController
  # The show template's inputs, shared with Admin::JpPackagesController#preview
  # (S9). See the concern for what deliberately stayed here.
  include PostShowAssigns

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

    # ── hreflang: the two listings are not translations of each other (S11) ──
    #
    # They used to be advertised as if they were. The layout emits all four UI
    # locales unless a controller narrows the set, so /ja/blog declared /blog as
    # its Korean alternate and /blog declared /ja/blog as its Japanese one —
    # while the two serve DIFFERENT POSTS with different titles. Google's rule
    # is that hreflang targets are the same document in another language, and
    # this is the signal shape that has already cost this repository twice
    # (/safe/ folded as a duplicate, /en/about folded onto /about).
    #
    # S8 scoped the ROWS by track and S11 gave the Japanese listing its own
    # title and description; this is the third half of the same change.
    #
    #   /ja/blog           → [] — one Japanese document. An empty set also
    #                        suppresses x-default (see the layout), which is
    #                        right: a fallback pointer to the Korean blog would
    #                        say "if your language is not listed, read this",
    #                        and the Korean blog is a different publication.
    #   /blog, /en, /es    → the three that ARE translations of one listing.
    #
    # app/views/pages/sitemap.xml.erb carries the same split. A page and a
    # sitemap disagreeing about hreflang is its own documented failure here.
    @hreflang_locales = @url_locale == :ja ? [] : (I18n.available_locales - [ :ja ])
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

    # Everything else the template reads — related posts, the robots gate, the
    # hreflang set, x-default, the language switcher, the FAQ — is assigned by
    # PostShowAssigns so the admin preview renders the same document from the
    # same code. The reasoning for each assignment lives there; the two that
    # stayed in this method (the 301 above and the view counter) are properties
    # of a public request rather than of the article.
    assign_post_show_ivars(@post, @url_locale)
  end
end
