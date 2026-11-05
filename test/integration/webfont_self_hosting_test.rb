require "test_helper"

# S12 — the webfonts are served from this origin, and no page asks Google for a
# font.
#
# ── Why this is a test ──────────────────────────────────────────────────────
#
# The rule is a property of a <link> tag in five hand-maintained static HTML
# files plus a Rails layout. Nothing in the build enforces it, and "we
# remembered to use the local stylesheet" is the kind of rule that holds until
# the next person copies a <head> between pages — which is exactly how the three
# JP landings came to load IBM Plex for pages that are written in Japanese.
#
# It also closes a disclosure loop. public/privacy/ §3-1 now names ONE external
# exception (OCR) instead of two. If a font <link> came back, that sentence
# would be false and the only thing that would notice is a reader watching their
# own network tab.
#
# ── What is measured ────────────────────────────────────────────────────────
#
# Rendered HTTP responses, not file contents. A grep over public/ would pass on
# a file that is never served, and would miss markup the Rails layout injects.
class WebfontSelfHostingTest < ActionDispatch::IntegrationTest
  GOOGLE_FONT_HOSTS = %w[fonts.googleapis.com fonts.gstatic.com].freeze

  LOCAL_STYLESHEET = "/fonts/fonts.css".freeze

  # The five static pages that carried the Google Fonts <link> pair before S12.
  # They are the ones that must now reference the local stylesheet instead, so
  # both halves can be asserted for them.
  SELF_HOSTED_PAGES = [
    "/safe/",
    "/privacy/",
    "/safe/jp/nyusatsu/",
    "/safe/jp/honnin-kakunin/",
    "/safe/jp/ai-mae/"
  ].freeze

  # Rails-rendered pages. These never loaded Google Fonts — the Korean site runs
  # on a system font stack (-apple-system, BlinkMacSystemFont, …) — so there is
  # no positive half to assert for them. They are here so that stays true by
  # assertion rather than by habit: adding a font <link> to the shared layout
  # would otherwise be invisible.
  LAYOUT_PAGES = [ "/", "/blog", "/faq", "/about", "/ja/blog", "/en", "/es" ].freeze

  # Families and weights the pages actually use:
  #   IBM Plex Sans KR — body text on all five (jp.css, /safe/, /privacy/)
  #   IBM Plex Mono    — .mono spans (URLs, codes) on four of them
  # Asserted so that a re-vendor which silently drops a weight fails here
  # instead of shipping a page whose 500-weight headings fall back to the system
  # font. The subset COUNT is deliberately not pinned: Google re-splits its
  # Korean ranges from time to time and that is a decision to look at, not a
  # test to fail.
  EXPECTED_FACES = {
    "IBM Plex Sans KR" => %w[400 500 700],
    "IBM Plex Mono" => %w[400 500]
  }.freeze

  # Static files arrive as ASCII-8BIT from ActionDispatch::Static, which makes
  # every comparison against a non-ASCII literal raise
  # Encoding::CompatibilityError — reading as a broken test rather than a broken
  # page. Same reason as jp_analytics_scope_test#body_of.
  def body_of(path)
    get path
    assert_response :success, "#{path} did not render"
    response.body.dup.force_encoding("UTF-8")
  end

  # ── no page asks Google for a font ────────────────────────────────────────

  test "no served page references a Google Fonts host" do
    pages = SELF_HOSTED_PAGES + LAYOUT_PAGES

    # Vacuity guard. If this list were emptied — or every `get` started
    # redirecting — the loop below would examine nothing and pass. That exact
    # shape has shipped in this repository before (canonical_sweep.rb reporting
    # ALL CHECKS PASSED over 0 entries).
    assert_operator pages.length, :>=, 12, "premise: there are pages to check"

    offenders = pages.each_with_object([]) do |path, acc|
      html = body_of(path)
      GOOGLE_FONT_HOSTS.each { |h| acc << "#{path} → #{h}" if html.include?(h) }
    end

    assert_empty offenders,
                 "these pages still request a webfont from Google. The fonts are served " \
                 "from #{LOCAL_STYLESHEET} since S12; see public/fonts/README.md:\n  " +
                 offenders.join("\n  ")
  end

  test "the five pages that used Google Fonts now load the local stylesheet" do
    # The positive half, and it is not optional. Without it, deleting the <link>
    # outright would satisfy the test above while leaving every page rendering in
    # a fallback font — "no Google Fonts request" and "no webfont at all" look
    # identical from the outside.
    SELF_HOSTED_PAGES.each do |path|
      assert_includes body_of(path), %(href="#{LOCAL_STYLESHEET}"),
                      "#{path} does not load #{LOCAL_STYLESHEET}"
    end
  end

  # ── the local stylesheet is real ──────────────────────────────────────────

  test "the local stylesheet is served and points only at this origin" do
    css = body_of(LOCAL_STYLESHEET)

    faces = css.scan(/@font-face\s*\{[^}]*\}/m)
    assert_operator faces.length, :>=, 100,
                    "only #{faces.length} @font-face blocks — the stylesheet looks truncated"

    urls = css.scan(/url\(([^)]+)\)/).flatten
    assert_equal faces.length, urls.length, "every @font-face must carry exactly one src url"

    external = urls.reject { |u| u.start_with?("/fonts/") }
    assert_empty external,
                 "the self-hosted stylesheet still points off-origin: #{external.uniq.join(', ')}"
  end

  test "the stylesheet declares every family and weight the pages use" do
    css = body_of(LOCAL_STYLESHEET)

    EXPECTED_FACES.each do |family, weights|
      blocks = css.scan(/@font-face\s*\{[^}]*\}/m)
                  .select { |b| b.include?("font-family: '#{family}'") }
      assert_operator blocks.length, :>, 0, "no @font-face for #{family}"

      weights.each do |w|
        assert blocks.any? { |b| b.match?(/font-weight:\s*#{w}\s*;/) },
               "#{family} is missing weight #{w} — text at that weight will fall back " \
               "to the system font with nothing else failing"
      end
    end
  end

  test "every font file the stylesheet references exists" do
    # Checked on disk for ALL of them rather than over HTTP for a sample. A
    # dangling src is the failure that matters here and it is per-file, whereas
    # the thing that serves them (ActionDispatch::Static) is the same mechanism
    # for every one — so completeness belongs on the per-file property and the
    # serving path is proved separately, in the test below.
    css = body_of(LOCAL_STYLESHEET)
    files = css.scan(/url\(\/fonts\/([^)]+)\)/).flatten

    assert_operator files.length, :>=, 100, "premise: the stylesheet references font files"

    missing = files.reject { |f| Rails.root.join("public", "fonts", f).file? }
    assert_empty missing,
                 "#{missing.length} of #{files.length} referenced font files are not on disk. " \
                 "A missing woff2 does not fail loudly — the glyphs in its unicode-range " \
                 "silently fall back:\n  #{missing.first(10).join("\n  ")}"
  end

  test "a referenced font file is actually served over HTTP" do
    # Proves the route, not the inventory. Takes the first and last file in the
    # stylesheet so the assertion does not depend on which one happens to sort
    # first.
    css = body_of(LOCAL_STYLESHEET)
    files = css.scan(/url\(\/fonts\/([^)]+)\)/).flatten
    assert_operator files.length, :>=, 2, "premise: at least two font files"

    [ files.first, files.last ].each do |f|
      get "/fonts/#{f}"
      assert_response :success, "/fonts/#{f} is referenced but not served"
      assert_equal "wOF2", response.body[0, 4].dup.force_encoding("BINARY"),
                   "/fonts/#{f} is served but is not a woff2"
    end
  end

  test "the licence ships with the fonts" do
    # OFL 1.1 requires the licence to travel with the font files. It lives in
    # public/, so it is served — which is the point; a licence that only exists
    # in git is not distributed with what it licenses.
    body = body_of("/fonts/LICENSE.ibm-plex.txt")
    assert_includes body, "SIL Open Font License"
    assert_includes body, "IBM Corp"
  end

  # ── the service worker agrees ─────────────────────────────────────────────

  test "the service worker no longer names a Google Fonts host" do
    # Read as source, because this is a claim about the worker's constants
    # rather than about a rendered page. A host left in CACHEABLE_CDN would not
    # break anything — it would just be a comment asserting a dependency that no
    # longer exists, which is what S11c cut cdnjs for.
    sw = Rails.root.join("public", "safe", "sw.js").read

    cdn_block = sw[/const CACHEABLE_CDN = \[(.*?)\];/m, 1]
    assert cdn_block, "CACHEABLE_CDN not found — the worker's shape changed"

    GOOGLE_FONT_HOSTS.each do |h|
      refute_includes cdn_block, h, "CACHEABLE_CDN still lists #{h}"
    end
    assert_includes cdn_block, "cdn.jsdelivr.net",
                    "jsdelivr must stay: Tesseract.js is still loaded from it"
  end

  test "the service worker precaches the font stylesheet and bumped its cache version" do
    sw = Rails.root.join("public", "safe", "sw.js").read

    assert_includes sw, "'#{LOCAL_STYLESHEET}'",
                    "#{LOCAL_STYLESHEET} is not precached, so an offline shell renders in " \
                    "the fallback stack even when the fonts were already fetched"

    # The bump is what evicts runtime entries naming fonts.gstatic.com. Asserted
    # as >= 4 rather than == 4 so the next unrelated bump does not fail here,
    # but a *missing* bump does.
    version = sw[/const CACHE_VERSION = 'v(\d+)-/, 1]
    assert version, "CACHE_VERSION not found or no longer has a numeric prefix"
    assert_operator version.to_i, :>=, 4,
                    "the font URLs moved on-origin; without a cache-version bump every " \
                    "returning visitor keeps dead fonts.gstatic.com runtime entries"
  end
end
