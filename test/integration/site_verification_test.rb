require "test_helper"

# Search-engine site-ownership tags.
#
# These are claims served to a crawler, and they are only worth anything while
# they are actually served. Both failure modes are silent from the inside: the
# tag disappears and nothing breaks locally, or it appears twice and the
# verifier reads whichever it likes. Neither shows up in any other test — E-1
# captures canonical/robots/hreflang/og:locale/html lang and does not look at
# verification meta, so a snapshot that cannot see a field cannot protect it.
#
# ⚠️ Naver verifies from the ROOT HTML of https://slimfile.net/. That the root
# is this layout at all is a premise, not a given — this repository has already
# been bitten by ActionDispatch::Static answering a path before the router ever
# saw it (/safe, 2026-09-17). So the premise is asserted rather than assumed:
# there is no public/index.html, and "/" renders a Rails view.
class SiteVerificationTest < ActionDispatch::IntegrationTest
  # Two Naver claims, not one: a second Search Advisor account was registered on
  # 2026-11-22 and the first one is not retired. Both have to be served — a
  # verifier that cannot find its own token revokes that account's ownership,
  # and which of the two Naver fetches is not ours to choose.
  NAVER_OLD = "541f515d0df5a153db9d76c689c544a7d88ac2d1".freeze
  NAVER_NEW = "1a5b666e52ab7ee944c03c6f581bc6e10c422e14".freeze
  NAVER_ALL = [ NAVER_OLD, NAVER_NEW ].freeze
  GOOGLE = "kgzqmiPFYQX0JWICmT3tB88tsJ7TADz-uyXJdu1pAEw".freeze

  test "the root is served by Rails, not by the static file handler" do
    # If a public/index.html were ever added, Static would answer "/" with it
    # and every verification tag below would vanish from the page the verifiers
    # actually fetch — while this layout kept rendering them everywhere else.
    refute Rails.root.join("public", "index.html").exist?,
           "public/index.html exists: ActionDispatch::Static now answers / before the " \
           "router, so the verification tags in layouts/application.html.erb are no " \
           "longer on the page Naver and Google fetch. Put them in that file too."

    assert_equal({ controller: "pages", action: "home" },
                 Rails.application.routes.recognize_path("/"),
                 "/ no longer routes to the view that renders this layout")

    get "/"
    assert_response :success
    # A tag only layouts/application.html.erb emits. `csrf_meta_tags` would be
    # the obvious marker and is the wrong one: forgery protection is off in the
    # test environment, so it renders nothing and the assertion would fail for a
    # reason that has nothing to do with the layout.
    assert_includes response.body, %(<meta name="keywords"),
                    "/ did not render through the Rails layout"
  end

  test "GET / carries both Naver ownership tags, each exactly once" do
    get "/"
    assert_response :success
    html = response.body.dup.force_encoding("UTF-8")

    tags = html.scan(/<meta\s+name="naver-site-verification"[^>]*>/)
    assert_equal NAVER_ALL.length, tags.length,
                 "expected #{NAVER_ALL.length} naver-site-verification tags, found #{tags.length}"

    # Counted per token rather than "the set matches": a copy/paste that
    # duplicates one token and drops the other keeps the total at 2, and an
    # equality check on a Set would pass that too.
    NAVER_ALL.each do |token|
      matching = tags.count { |tag| tag.include?(%(content="#{token}")) }
      assert_equal 1, matching,
                   "expected the #{token} claim exactly once, found #{matching}"
    end
  end

  test "the Google ownership tag is still there and still single" do
    # Added alongside, so the obvious regression — a copy/paste that replaces
    # the neighbouring tag instead of following it — fails here.
    get "/"
    tags = response.body.scan(/<meta\s+name="google-site-verification"[^>]*>/)
    assert_equal 1, tags.length
    assert_includes tags.first, %(content="#{GOOGLE}")
  end

  test "both tags follow the layout onto other Rails pages" do
    # Not a requirement of either verifier, but it is the property that makes
    # the tags survive a rework of the home view: they live in the layout.
    [ "/faq", "/about", "/blog" ].each do |path|
      get path
      assert_response :success, path
      NAVER_ALL.each do |token|
        assert_includes response.body, token, "#{path} lost the Naver #{token} tag"
      end
      assert_includes response.body, GOOGLE, "#{path} lost the Google tag"
    end
  end
end
