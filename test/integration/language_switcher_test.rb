require "test_helper"

# S12 — the language switcher offers only languages the page you are on exists
# in.
#
# ── The failure it closes ───────────────────────────────────────────────────
#
# /ja/blog offered 「한국어」, and that link went to /blog. Not a redirect and not
# an error: /blog is the KOREAN listing — a different publication that happens
# to share a table (PostsController#index scopes the rows by track, and S11 gave
# the two listings separate hreflang sets for exactly this reason). A Japanese
# reader looking for the page in Korean landed somewhere else, and the only
# visible symptom was that every headline had changed.
#
# S11 narrowed hreflang. S11c narrowed the switcher on JP *article* pages. The
# listing kept all four locales, which is how the two halves of one rule drift
# apart — so this test holds both halves and the no-op half as well.
class LanguageSwitcherTest < ActionDispatch::IntegrationTest
  # The control itself. Asserted by markup rather than by counting links,
  # because the links in the menu are indistinguishable from any other nav link
  # by href alone.
  DROPDOWN = "lang-dropdown".freeze
  MENU_ITEM = "lang-menu-item".freeze

  def body_of(path)
    get path
    assert_response :success, "#{path} did not render"
    response.body.dup.force_encoding("UTF-8")
  end

  def menu_items(html)
    html.scan(/class="#{MENU_ITEM}[^"]*"[^>]*>([^<]+)</).flatten.map(&:strip)
  end

  # ── the Japanese listing has nothing to switch to ─────────────────────────

  test "the Japanese blog listing renders no language switcher" do
    html = body_of("/ja/blog")

    refute_includes html, DROPDOWN,
                    "/ja/blog still renders a language switcher. The Japanese listing is one " \
                    "Japanese document — /blog, /en/blog and /es/blog list the Korean posts, " \
                    "so there is no other language of this page to offer."
    assert_empty menu_items(html), "/ja/blog offers language links"
  end

  test "the Japanese listing is not merely broken — it still renders its own page" do
    # Vacuity guard for the test above. "No switcher" and "the page failed to
    # render" look identical to a refute, and this route has a track-scoped
    # query that could plausibly blow up. So assert the page is really there.
    html = body_of("/ja/blog")
    assert_includes html, "<html", "/ja/blog did not render a document"
    assert_includes html, "top-bar-right", "/ja/blog did not render the header the switcher lives in"
  end

  # ── the Korean listing is untouched ───────────────────────────────────────

  test "the Korean blog listing still offers all four languages" do
    # The half that must NOT move. /blog, /en/blog and /es/blog really are one
    # listing in three UI languages, and ja is offered because a reader may want
    # the Japanese site. Without this assertion, "narrow the switcher" could be
    # implemented by deleting it everywhere and the test above would pass.
    [ "/blog", "/en/blog", "/es/blog" ].each do |path|
      html = body_of(path)
      assert_includes html, DROPDOWN, "#{path} lost its language switcher"
      assert_equal I18n.available_locales.length, menu_items(html).length,
                   "#{path} offers #{menu_items(html).inspect}"
    end
  end

  test "ordinary pages still offer all four languages" do
    [ "/", "/faq", "/about" ].each do |path|
      html = body_of(path)
      assert_includes html, DROPDOWN, "#{path} lost its language switcher"
      assert_equal I18n.available_locales.length, menu_items(html).length, path
    end
  end
end

# The article half, tested without touching the posts fixtures.
#
# A JP fixture cannot be added: test/integration/blog_seo_snapshot_test.rb (E-1)
# enumerates `Post.order(:slug)` × four locale prefixes and asserts the captured
# KEY SET equals the stored snapshot, so one new row would add five entries and
# fail a test whose whole job is to prove the Korean track did not move. S8b hit
# the same wall from the other side (a fixture on a redirect-target slug broke
# PrivacyGuideOwnershipTest).
#
# So the derivation is exercised directly on an unsaved Post. That is the unit
# under change — `@switcher_locales` is computed from the post, not from the
# request — and it keeps this test independent of which episodes happen to be in
# the database.
class JpSwitcherDerivationTest < ActiveSupport::TestCase
  # The concern calls helpers.base_url for x-default; nothing else in it needs a
  # view context.
  class FakeHelpers
    def base_url = "https://slimfile.net"
  end

  class Host
    include PostShowAssigns
    def helpers = FakeHelpers.new
    attr_reader :switcher_locales
    def run(post) = assign_post_show_ivars(post, post.primary_locale_sym).then { @switcher_locales = instance_variable_get(:@switcher_locales) }
  end

  def switcher_for(post)
    h = Host.new
    h.run(post)
    h.switcher_locales
  end

  def jp_post(body_en:)
    Post.new(slug: "jp-ep99-probe", primary_locale: "ja", status: "draft",
             title_ja: "見本", body_ja: "本文", body_en: body_en)
  end

  test "a JP article with an English edition offers Japanese and English" do
    assert_equal [ :ja, :en ], switcher_for(jp_post(body_en: "English body"))
  end

  test "a JP article without an English edition offers Japanese only" do
    # Which makes the layout drop the control — correct, because the /en URL
    # would render English chrome over Japanese prose. S11c wrote [:ja, :en]
    # flat; every episode in the database carries a body_en today, so this is
    # about the next one imported without post_en.md rather than about current
    # data.
    assert_equal [ :ja ], switcher_for(jp_post(body_en: nil))
    assert_equal [ :ja ], switcher_for(jp_post(body_en: ""))
  end

  test "a Korean article leaves the switcher unset" do
    # nil, not [] — unset means "every locale", which is what the Korean track
    # has always had. The distinction is load-bearing in the layout and this is
    # the only place it is asserted for posts.
    ko = Post.new(slug: "ko-probe", primary_locale: "ko", status: "draft",
                  title_ko: "제목", body_ko: "본문")
    assert_nil switcher_for(ko)
  end
end
