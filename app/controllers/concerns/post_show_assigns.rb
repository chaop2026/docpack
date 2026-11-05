# The instance variables app/views/posts/show.html.erb reads, assigned in one
# place.
#
# Extracted in S9 because a SECOND controller now renders that template: the
# admin package screen links to /admin/jp/packages/:ep/preview so the approver
# can see the article in the real public layout before pressing 승인. Copying
# the assignments into the admin controller would have given the template two
# sources of truth for its own inputs — and the ones that matter here are the
# indexing signals (canonical, robots, hreflang, x-default), which this
# repository has already been penalised for twice when two code paths disagreed
# about them.
#
# The redirect and the view counter stay in PostsController. Both are properties
# of the PUBLIC request, not of the document:
#
#   * the bare-path 301 exists because /blog/:slug is the Korean blog's address;
#     an admin preview is not at that address and has nothing to redirect.
#   * increment!(:view_count) would make the approver's own preview show up as
#     readership. P-series KPIs read that column.
module PostShowAssigns
  extend ActiveSupport::Concern

  private

  # `url_locale` is passed rather than derived so the caller stays honest about
  # which locale the rendered document claims to be. The public path reads it
  # off the URL; the preview has no locale prefix to read, so it passes the
  # post's own primary locale — the language the text actually is.
  def assign_post_show_ivars(post, url_locale)
    @post = post
    @url_locale = url_locale

    @related_posts = Post.published
                         .where(category: post.category, primary_locale: post.primary_locale)
                         .where.not(id: post.id).recent.limit(3)

    @post_translated = post.translated?(url_locale)
    @post_indexable = post.indexable?(url_locale)
    @hreflang_locales = post.indexable_locales
    @xdefault_url = "#{helpers.base_url}#{post.canonical_path_for(post.primary_locale_sym)}"
    # The switcher offers only languages this article is actually readable in.
    #
    # S11c wrote `[ :ja, :en ]` flat, which is true of every JP episode today
    # (all eight carry a 2–3k character body_en). S12 derives it instead: a
    # future episode imported without post_en.md would otherwise be advertised
    # as having an English edition, and the link would render English chrome
    # over Japanese prose — the half-translated shape this repository already
    # fixed once for /ja|es/blog/:slug. Same value as before for current data,
    # so nothing moves until the data does.
    #
    # A lone [ :ja ] makes the layout drop the control — correct, since there is
    # then nothing to switch to. Korean posts stay unset (all four locales).
    @switcher_locales = [ :ja, (:en if post.translated?(:en)) ].compact if post.primary_locale == "ja"
    @faq = post.package_faq
  end
end
