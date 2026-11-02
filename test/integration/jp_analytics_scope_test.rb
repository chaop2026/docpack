require "test_helper"

# S11 — where analytics may run, and where it must not.
#
# GA4 was added to the three Japanese landing pages because they had no
# measurement at all (GSC/GA4 audit, docs/jp/seo_geo_audit_2026-11-02.md: 16
# views in 30 days, zero on /safe/*). It was deliberately NOT added to /safe/,
# the screen where a document is actually opened — that page's standing promise
# is that it carries no third-party script, and the first-party SafeEvent
# counter exists precisely so it does not need one.
#
# ── Why this is a test and not a comment ────────────────────────────────────
#
# The boundary is a property of four static HTML files. Nothing in the build
# enforces it, and "we remembered not to put the tag there" is the kind of rule
# that holds until the next person copies a <head> between pages. So both
# halves are asserted: the three landings MUST carry it and /safe/ MUST NOT.
# A one-sided test would stay green if the tag were added everywhere.
class JpAnalyticsScopeTest < ActionDispatch::IntegrationTest
  LANDINGS = %w[nyusatsu honnin-kakunin ai-mae].freeze

  # The id already in use by the Korean app (layouts/application.html.erb).
  # Pinned here so a second property cannot be introduced by accident — two
  # measurement ids on one site produce two sets of numbers and no way to know
  # which one a report is quoting.
  GA_ID = "G-1RHNPW0ZTD".freeze

  # ANALYTICS hosts only.
  #
  # ⚠️ Measured while writing this test: /safe/ already loads an ACTIVE Google
  # AdSense script in its <head> (public/safe/index.html:312,
  # pagead2.googlesyndication.com). So the sentence this repository has been
  # repeating — «the tool page carries no third-party script» — was already
  # false before S11, and jp.js said it in a comment. What is true, and what
  # S11 was asked to pin, is that /safe/ carries no ANALYTICS: no GA4, no
  # measurement id, no gtag call, and therefore no per-visitor measurement of
  # the screen where a document is opened. AdSense is disclosed in /privacy/ §3
  # and whether it belongs on this page at all is a revenue decision, not a
  # test's to make — it is written up in docs/jp/s11_report.md §6.
  #
  # Keeping googlesyndication.com OUT of this list is therefore deliberate and
  # is asserted separately below, so the exception is visible rather than
  # hidden by a conveniently short list.
  ANALYTICS_HOSTS = %w[googletagmanager.com google-analytics.com].freeze
  ADSENSE_HOST = "pagead2.googlesyndication.com".freeze

  # `.force_encoding` is not cosmetic. A file served by ActionDispatch::Static
  # arrives as ASCII-8BIT, so every comparison against a Japanese literal in
  # this file raises Encoding::CompatibilityError — which reads as a broken
  # test rather than as a broken page, and the obvious "fix" is to delete the
  # assertion. The bytes are UTF-8; only the label was missing.
  def body_of(path)
    get path
    assert_response :success, "#{path} did not render"
    response.body.dup.force_encoding("UTF-8")
  end

  # ── the tag is on the three landings ──────────────────────────────────────

  test "each landing page loads GA4 with the site's single measurement id" do
    LANDINGS.each do |slug|
      html = body_of("/safe/jp/#{slug}/")
      assert_includes html, "googletagmanager.com/gtag/js?id=#{GA_ID}",
                      "#{slug}: the gtag loader is missing"
      assert_includes html, "gtag('config', '#{GA_ID}'",
                      "#{slug}: gtag is loaded but never configured"

      ids = html.scan(/G-[A-Z0-9]{8,}/).uniq
      assert_equal [ GA_ID ], ids, "#{slug}: more than one measurement id appears"
    end
  end

  test "the privacy-reducing options are all three present on every landing" do
    # Each one is a separate switch and each is off for its own reason:
    # anonymize_ip truncates the address, allow_google_signals turns off
    # cross-device identity, allow_ad_personalization_signals turns off ad
    # audiences. Asserted individually rather than as one blob — a config call
    # that silently lost one of them would still look configured.
    LANDINGS.each do |slug|
      html = body_of("/safe/jp/#{slug}/")
      assert_includes html, "anonymize_ip: true", "#{slug}"
      assert_includes html, "allow_google_signals: false", "#{slug}"
      assert_includes html, "allow_ad_personalization_signals: false", "#{slug}"
    end
  end

  # ── and on nothing else under /safe/ ──────────────────────────────────────

  test "/safe/ loads NO analytics" do
    # Comments stripped: the same file also carries a COMMENTED-OUT AdSense
    # slot placeholder ("▼ Google AdSense 자리"). Asserting against raw bytes
    # would fail on a placeholder that loads nothing, and the obvious "fix"
    # would be to delete the assertion rather than the comment.
    html = body_of("/safe/").gsub(/<!--.*?-->/m, "")

    ANALYTICS_HOSTS.each do |host|
      refute_includes html, host,
                      "/safe/ references #{host}. The screen where a document is opened " \
                      "must not be measured per visitor; SafeEvent is the first-party " \
                      "counter that exists so it does not have to be."
    end
    refute_match(/\bgtag\s*\(/, html, "/safe/ calls gtag()")
    refute_match(/G-[A-Z0-9]{8,}/, html, "/safe/ carries a GA measurement id")
  end

  test "the external scripts /safe/ does load are exactly the three known ones" do
    # An allowlist, not a count — a count passes when one script is swapped for
    # another. Each entry is here for a stated reason, so adding a fourth has
    # to be a deliberate edit of this list:
    #
    #   cdnjs pdf.js    — renders PDF pages to canvas (eagerly loaded; the
    #                     redaction pipeline cannot start without it)
    #   cdnjs mammoth   — reads .docx
    #   AdSense         — revenue on the free tool. ⚠️ This is the one that
    #                     makes «no third-party script on /safe/» false, and
    #                     it predates S11. Disclosed in /privacy/ §3. Whether
    #                     it belongs on a page people open ID documents on is a
    #                     product decision (s11_report §6), not a test's.
    #
    # Tesseract.js, heic2any and jsPDF are NOT here on purpose: they are loaded
    # lazily from JS, so they never appear as a <script src> in the HTML.
    allowed_hosts = [ "cdnjs.cloudflare.com", ADSENSE_HOST ]

    html = body_of("/safe/").gsub(/<!--.*?-->/m, "")
    external = html.scan(/<script[^>]+src="(https?:[^"]+)"/).flatten.uniq

    assert_equal 3, external.length,
                 "/safe/ loads #{external.length} external scripts: #{external.join(', ')}"
    external.each do |src|
      assert_includes allowed_hosts, URI.parse(src).host,
                      "an unlisted external script appeared on /safe/: #{src}"
    end
    assert external.any? { |s| s.include?(ADSENSE_HOST) },
           "AdSense is gone from /safe/ — good, but this test's allowlist now describes " \
           "a page that no longer exists. Drop it from allowed_hosts."

    # And the policy has to cover it. §3 is the AdSense section.
    assert_includes body_of("/privacy/"), "Google AdSense"
  end

  test "jp.js is not where the tag lives" do
    # The shared asset is the one place a tag would reach all three pages at
    # once AND follow them into /safe/ if it were ever included there. Keeping
    # it out is what makes the boundary above a property of four files rather
    # than of one.
    js = Rails.root.join("public", "safe", "jp", "jp.js").read
    (ANALYTICS_HOSTS + [ ADSENSE_HOST ]).each do |host|
      refute_includes js, host, "jp.js references #{host}"
    end
    refute_match(/\bgtag\s*\(/, js)
  end

  test "the privacy policy says where analytics runs and where it does not" do
    # A measurement nobody is told about is the thing being avoided here, so
    # the disclosure is part of the change rather than a nicety. Checked for
    # both halves of the claim, in Japanese, because the pages it describes are
    # Japanese.
    html = body_of("/privacy/")
    assert_includes html, "Google Analytics 4"
    assert_includes html, "日本語の案内ページ"
    assert_includes html, "/safe/jp/nyusatsu/"
    assert_match(/ファイルを開いて処理する画面.*アクセス解析も第三者のスクリプトも利用していません/,
                 html.gsub(/<[^>]+>/, ""),
                 "the policy has to state that /safe/ is excluded, not only that the landings are included")
  end

  # ── Organization (S11 item 3) ─────────────────────────────────────────────

  test "all three landings declare the same Organization" do
    orgs = LANDINGS.to_h do |slug|
      blocks = ld_blocks(body_of("/safe/jp/#{slug}/"))
      [ slug, blocks.find { |b| b["@type"] == "Organization" } ]
    end

    orgs.each do |slug, org|
      assert org, "#{slug}: no Organization block"
      assert_equal "SafeFile", org["name"], slug
      assert_equal "セーフファイル", org["alternateName"], slug
      assert_equal "https://slimfile.net/safe/brand/icon-512.png", org["logo"], slug
      assert_equal "Tasicop", org.dig("parentOrganization", "name"), slug
      assert_equal [ "https://lin.ee/rV1LpPB",
                     "https://www.youtube.com/channel/UC0TZjC4xG0iaRVqFrJroJxA",
                     "https://x.com/safefile_jp" ],
                   org["sameAs"].sort, slug
    end

    # Three copies of one block in three static files is the cost of having no
    # build step for them. What must not happen is three copies that disagree —
    # an answer engine reading two of them sees two entities.
    assert_equal 1, orgs.values.map { |o| o.except("url") }.uniq.length,
                 "the three Organization blocks are not identical: #{orgs.keys.join(', ')}"
  end

  test "the Organization logo is a file that is actually served" do
    # The 2026-10-25 finding was a whole directory of brand images that 404'd
    # in production because of file permissions — dev runs as root and could
    # not see it. A logo URL in structured data that answers 404 is worse than
    # no logo: Google reports it as an error on every article.
    get "/safe/brand/icon-512.png"
    assert_response :success
    assert_equal "image/png", response.media_type
  end

  # ── FAQPage (S11 item 2) ──────────────────────────────────────────────────

  test "every landing carries a FAQPage with three questions" do
    LANDINGS.each do |slug|
      html = body_of("/safe/jp/#{slug}/")
      faq = ld_blocks(html).find { |b| b["@type"] == "FAQPage" }
      assert faq, "#{slug}: no FAQPage block"
      assert_equal 3, faq["mainEntity"].length, "#{slug}: expected three questions"
      assert_equal "ja", faq["inLanguage"], slug

      # The markup must describe a section the document contains. Both the
      # question and the answer are checked against the rendered text: a
      # FAQPage whose answers exist only in the JSON is a claim about the page
      # that is false, and Google treats it as a markup violation.
      text = html.gsub(/<script.*?<\/script>/m, "").gsub(/<[^>]+>/, " ").gsub(/\s+/, "")
      faq["mainEntity"].each do |q|
        assert_includes text, q["name"].gsub(/\s+/, ""),
                        "#{slug}: question is only in the JSON-LD — «#{q['name']}»"
        assert_includes text, q.dig("acceptedAnswer", "text").gsub(/\s+/, ""),
                        "#{slug}: answer is only in the JSON-LD — «#{q['name']}»"
      end
    end
  end

  test "no landing page asserts a legal effect in its FAQ" do
    # Written without legal certainty on purpose: there is still no review by a
    # a Japanese lawyer (every report since S3c says so). The guard's own
    # pattern for this is reused rather than restated here.
    legal = JSON.parse(Rails.root.join("content", "jp", "guard_rules.json").read)["forbidden"]
                .find { |f| f["id"] == "legal_assert_ja" }
    assert legal, "guard_rules.json no longer carries legal_assert_ja"
    re = Regexp.new(legal["re"])

    LANDINGS.each do |slug|
      faq = ld_blocks(body_of("/safe/jp/#{slug}/")).find { |b| b["@type"] == "FAQPage" }
      faq["mainEntity"].each do |q|
        [ q["name"], q.dig("acceptedAnswer", "text") ].each do |s|
          refute_match re, s, "#{slug}: FAQ asserts a legal effect — «#{s}»"
        end
      end
    end
  end

  # ── the scarcity claim is gone (S11 item 10) ──────────────────────────────

  test "no page offers a countdown nobody is counting" do
    # 「先着10社に3か月無料」 promised a discount off a paid plan that does not
    # exist (no Stripe JP product) and a tally nobody kept. The outreach
    # playbook §2 had it on its forbidden list before the first mail went out
    # and the landing was the last place still saying it.
    re = Regexp.new(JSON.parse(Rails.root.join("content", "jp", "guard_rules.json").read)["forbidden"]
                        .find { |f| f["id"] == "pilot_scarcity" }.fetch("re"))

    (LANDINGS.map { |s| "/safe/jp/#{s}/" } + [ "/safe/" ]).each do |path|
      visible = body_of(path).gsub(/<!--.*?-->/m, "")
      refute_match re, visible, "#{path} still advertises 先着N社"
    end

    assert_includes body_of("/safe/jp/nyusatsu/"), "先行利用の事務所を募集しています（無料）",
                    "the replacement copy is missing — removing the old line is only half of it"
  end

  private

  # Every application/ld+json block on the page, parsed. Parsed rather than
  # regex-matched so an invalid block fails loudly here instead of being
  # dropped silently by Google.
  def ld_blocks(html)
    html.scan(%r{<script type="application/ld\+json">(.*?)</script>}m).map do |(raw)|
      JSON.parse(raw)
    rescue JSON::ParserError => e
      flunk "a JSON-LD block does not parse: #{e.message}\n#{raw.to_s.first(300)}"
    end
  end
end
