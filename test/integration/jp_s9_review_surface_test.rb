require "test_helper"

# S9: the surfaces the weekly approver actually reads, and the two inputs that
# are now written by a human rather than derived.
#
#   * the approval screen and the review mail are KOREAN (content stays JA/EN)
#   * summary_ko.md and linkedin_en.md are REQUIRED — a missing one refuses the
#     import rather than producing a package that looks complete
#   * the public-page preview is admin-only, noindex, and does not add a public
#     address
#   * KO posts now declare inLanguage in their Article JSON-LD
class JpS9ReviewSurfaceTest < ActionDispatch::IntegrationTest
  EP = 77

  def login
    post admin_login_path, params: { password: ENV.fetch("ADMIN_PASSWORD") }
  end

  def make_package(**overrides)
    Post.create!({
      content_track: "jp", content_ep: EP, primary_locale: "ja", status: "draft",
      category: "privacy", slug: "jp-ep#{EP}-s9", title_ja: "承認テスト",
      body_ja: "<p>本文</p>", body_en: "<p>Body</p>", published_at: 3.days.from_now,
      package: {
        "ep" => EP, "track" => "jp", "x_thread" => [ "いち", "に" ],
        "x_reply_en" => "reply", "linkedin_text" => "li",
        "guard" => { "violations" => [] },
        "faq" => [ { "q" => "質問1", "a" => "答1" } ],
        "summary_ko" => {
          "title" => "한국어 제목", "gist" => "한국어 요지입니다.",
          "table" => "| 가린다 | 남긴다 |", "basis" => "근거 한 줄",
          "tweets" => [ "첫 트윗 한국어", "둘째 트윗 한국어", "영어 답글 한국어" ],
          "faq" => [ "FAQ1 한국어" ],
          "judgment" => "내가 책임지는 주장 한 개"
        }
      }
    }.merge(overrides))
  end

  def make_topic
    BlogTopic.create!(track: "jp", ep: EP, topic: "t", category: "privacy",
                      title_en: "S9", landing: "nyusatsu", purpose: "bid_attachment",
                      publish_on: 3.days.from_now.to_date)
  end

  # ── B. the approval screen is Korean ───────────────────────────────────────

  test "the approval screen carries Korean UI and the Japanese content untouched" do
    make_package
    make_topic
    login
    get admin_jp_package_path(EP)
    assert_response :success

    # Korean chrome, by the strings the approver has to act on.
    [ "승인", "공개 예정", "블로그(일본어)", "X 스레드", "자주 묻는 질문",
      "KPI 대조", "사람이 판단할 한 가지", "공개 페이지 미리보기" ].each do |ko|
      assert_includes response.body, ko, "missing Korean label: #{ko}"
    end

    # The content is NOT translated. Asserted alongside, because a screen that
    # translated the article would satisfy every assertion above.
    assert_includes response.body, "承認テスト", "the Japanese title is content"
    assert_includes response.body, "いち", "the Japanese tweet is content"
  end

  test "an approved package shows the Korean reject button" do
    # 「반려」 only exists on an approved package, so it needs its own fixture
    # state rather than a line in the list above — which is where it was first
    # written, and it failed on the draft.
    pkg = make_package
    topic = make_topic
    JpApproval.approve!(pkg, topic: topic)
    login
    get admin_jp_package_path(EP)
    assert_response :success
    assert_includes response.body, "반려"
    refute_includes response.body, "差し戻す", "the pre-S9 Japanese label"
  end

  test "no translation is missing anywhere on the approval screen" do
    # The whole screen is t() calls, so a typo'd key renders the literal
    # "translation missing: …" and the page still returns 200. This repository
    # has already shipped that exact string to a user once (2026-10-22, the
    # pilot form's validation errors), which is why it is asserted rather than
    # eyeballed.
    make_package
    make_topic
    login
    get admin_jp_package_path(EP)
    assert_response :success
    refute_match(/translation missing/i, response.body)
    refute_match(/Translation missing/, response.body)
  end

  test "the judgment sentence is shown, and its absence is named" do
    make_package
    make_topic
    login
    get admin_jp_package_path(EP)
    assert_includes response.body, "내가 책임지는 주장 한 개"

    # Rendered TWICE — once above each approve button (top and bottom). The
    # count is asserted because "it appears" would pass if the bottom button
    # silently lost its box.
    assert_equal 2, response.body.scan("내가 책임지는 주장 한 개").size,
                 "the judgment box belongs above both approve buttons"
  end

  test "a package with no judgment section says so instead of rendering nothing" do
    pkg = make_package
    pkg.update_column(:package, pkg.package.merge(
      "summary_ko" => pkg.package["summary_ko"].except("judgment")
    ))
    make_topic
    login
    get admin_jp_package_path(EP)
    assert_response :success
    assert_includes response.body, "사람이 판단할 한 가지"
    assert_match(/비어 있습니다/, response.body,
                 "an empty judgment must be stated — a blank box reads as 'nothing to decide'")
  end

  test "the approve button appears at the top AND the bottom, posting to one path" do
    make_package
    make_topic
    login
    get admin_jp_package_path(EP)

    forms = response.body.scan(%r{<form[^>]*action="#{Regexp.escape(admin_jp_package_approve_path(EP))}"})
    assert_equal 2, forms.size,
                 "the screen is long enough that one button is in the wrong place whichever end it is at"
  end

  test "the Korean summary is rendered next to the Japanese it summarises" do
    make_package
    make_topic
    login
    get admin_jp_package_path(EP)
    body = response.body

    # Position, not just presence: tweet 1's Korean has to come after tweet 1's
    # Japanese and before tweet 2's. A "Korean section" at the bottom of the
    # page would satisfy an assert_includes and defeat the point.
    ja1 = body.index("いち")
    ko1 = body.index("첫 트윗 한국어")
    ja2 = body.index("に<")  || body.index("に</pre>") || body.index("둘째 트윗 한국어")
    assert ja1 && ko1, "both the Japanese tweet and its Korean must render"
    assert_operator ko1, :>, ja1, "the Korean goes under its own tweet"
    assert_operator ko1, :<, ja2, "…and above the next one"
  end

  # ── B.5 the preview route ──────────────────────────────────────────────────

  test "preview renders the public layout for an admin" do
    make_package
    make_topic
    login
    get admin_jp_package_preview_path(EP)
    assert_response :success
    assert_includes response.body, "本文", "the article body renders"
  end

  test "preview is noindex,nofollow even for a published, indexable post" do
    pkg = make_package
    pkg.update!(status: "published", published_at: 1.day.ago)
    make_topic
    login

    # The real address of this post IS indexable now…
    get "/ja/blog/#{pkg.slug}"
    assert_response :success
    assert_select "meta[name=robots]", false,
                  "the published article's own URL must stay indexable"

    # …and the preview address must still never be.
    get admin_jp_package_preview_path(EP)
    assert_response :success
    assert_select "meta[name=robots][content=?]", "noindex,nofollow"
  end

  test "a draft preview emits ONE well-formed robots directive, not two concatenated" do
    # content_for APPENDS. A draft rendered through the preview satisfies both
    # conditions, and the first version of this emitted
    # "noindex,follownoindex,nofollow" — a malformed value is IGNORED rather
    # than rejected, so the page would have been indexable with a tag that
    # looked correct.
    make_package # status: draft
    make_topic
    login
    get admin_jp_package_preview_path(EP)
    assert_response :success
    assert_select "meta[name=robots]", count: 1
    assert_select "meta[name=robots][content=?]", "noindex,nofollow"
  end

  test "preview is 404 without an admin session, not a redirect to login" do
    make_package
    make_topic
    get admin_jp_package_preview_path(EP)
    assert_response :not_found,
                    "a redirect would confirm the episode exists; the ep number is guessable"
  end

  test "the rest of the admin still redirects to login" do
    # The inverse, so the 404 above is not passing because authentication broke
    # everywhere.
    make_package
    make_topic
    get admin_jp_package_path(EP)
    assert_redirected_to admin_login_path
  end

  # ── C/D. the two required inputs ───────────────────────────────────────────

  def source_for(dir)
    JpEpisodeSource.new(dir: dir, topic_row: real_topic_row, ep: 1)
  end

  def real_topic_row
    @real_topic_row ||= JSON.parse(Rails.root.join("content", "jp", "topics.json").read)["episodes"]
                            .find { |e| e["ep"] == 1 }
  end

  # A real episode folder, copied so a file can be removed without touching the
  # repository. Copied rather than stubbed: the thing under test is what
  # happens when the FILE is absent.
  def with_episode_copy
    Dir.mktmpdir("ep01copy") do |tmp|
      dir = Pathname(tmp).join("ep01")
      FileUtils.cp_r(Rails.root.join("content", "jp", "ep01"), dir)
      yield dir
    end
  end

  test "the real ep01 folder validates — the premise of the two tests below" do
    with_episode_copy { |dir| assert source_for(dir).validate! }
  end

  test "import refuses an episode with no summary_ko.md" do
    with_episode_copy do |dir|
      dir.join("summary_ko.md").delete
      e = assert_raises(JpEpisodeSource::InvalidEpisode) { source_for(dir).validate! }
      assert_match(/summary_ko\.md is missing/, e.message)
      assert_match(/승인자가 읽을 수 없는 패키지는 만들지 않는다/, e.message)
    end
  end

  test "import refuses an episode with no linkedin_en.md" do
    with_episode_copy do |dir|
      dir.join("linkedin_en.md").delete
      e = assert_raises(JpEpisodeSource::InvalidEpisode) { source_for(dir).validate! }
      assert_match(/linkedin_en\.md is missing/, e.message)
      assert_match(/dev log written by hand/, e.message)
    end
  end

  test "an empty linkedin_en.md is refused too, not treated as present" do
    with_episode_copy do |dir|
      dir.join("linkedin_en.md").write("\n   \n")
      e = assert_raises(JpEpisodeSource::InvalidEpisode) { source_for(dir).validate! }
      assert_match(/linkedin_en\.md is empty/, e.message)
    end
  end

  test "linkedin_text is the file verbatim — not assembled from post_en.md" do
    with_episode_copy do |dir|
      dir.join("linkedin_en.md").write("ONE LINE ONLY\n")
      assert_equal "ONE LINE ONLY", source_for(dir).linkedin_text
    end
  end

  test "a summary_ko.md whose sections are mistyped imports but names them" do
    # The file/guard split: a MISSING file refuses (above); a file that exists
    # and is incomplete imports and disables approval, so a human can look at
    # the package and decide.
    with_episode_copy do |dir|
      dir.join("summary_ko.md").write("## 제목\n제목\n\n## 요지\n요지\n")
      src = source_for(dir)
      assert src.validate!, "an incomplete summary must NOT refuse the import"
      missing = src.summary_ko_missing_sections
      assert_includes missing, "사람이 판단할 한 가지"
      assert_equal 5, missing.size, missing.inspect

      v = JpImport.build_guard(src).violations
      assert v.any? { |x| x.start_with?("summary_ko.md:") }, v.inspect
    end
  end

  test "summary_ko parses all seven sections and splits the numbered ones" do
    with_episode_copy do |dir|
      s = source_for(dir).summary_ko
      assert_equal JpEpisodeSource::SUMMARY_SECTIONS.values.sort, s.keys.sort
      assert_kind_of Array, s["tweets"]
      assert_kind_of Array, s["faq"]
      assert_operator s["tweets"].length, :>=, 5
      refute s["tweets"].first.start_with?("1."), "the number prefix is stripped"
    end
  end

  test "numbered items keep FILE order rather than being sorted by their number" do
    # Deliberate. If the author numbers them 1,3,2 the screen shows 1,3,2 and
    # the mistake is visible; re-sorting would silently pair Korean text with
    # the wrong Japanese tweet, and both would look fine.
    with_episode_copy do |dir|
      dir.join("summary_ko.md").write(<<~MD)
        ## 제목
        t
        ## 요지
        g
        ## 표
        tb
        ## 근거
        b
        ## 트윗
        1. first
        3. third
        2. second
        ## FAQ
        1. q
        ## 사람이 판단할 한 가지
        j
      MD
      assert_equal %w[first third second], source_for(dir).summary_ko["tweets"]
    end
  end

  # ── D. the LinkedIn guard ──────────────────────────────────────────────────

  def li_violations(text)
    JpContentGuard.new(surfaces: {}, linkedin_text: text).violations
  end

  LI_FORBIDDEN = {
    "li_brand_voice" => "SafeFile helps you cover your data.",
    "li_free_for_first" => "It is free for the first 100 users.",
    "li_japan_targeting" => "日本の入札では必要です。",
    "li_japan_targeting_en" => "Japanese companies should try this.",
    "li_signup_cta" => "Sign up today.",
    "li_urgency" => "Only for a limited time."
  }.freeze

  test "every LinkedIn forbidden pattern fires on text that contains it" do
    LI_FORBIDDEN.each do |id, text|
      v = li_violations(text)
      assert v.any? { |x| x.include?("[#{id}]") },
             "#{id} did not fire on #{text.inspect} — got #{v.inspect}"
    end
  end

  test "none of the LinkedIn patterns fires on a clean dev log" do
    # The negative half. Without it, a pattern of `.` would pass the test above
    # six times over.
    clean = <<~TEXT
      This week I shipped a thing.

      I build a small tool. It covers personal details in a document. It runs in your browser.

      I learned two things. Rules differ by recipient. A black box is not a redaction.

      It is free and rough. Try it and tell me what confused you.

      https://slimfile.net/en/blog/x?utm_source=linkedin

      #buildinpublic #privacy #sideproject
    TEXT
    assert_empty li_violations(clean), "a clean dev log must produce no violations"
  end

  test "the committed LinkedIn posts pass their own guard" do
    # The rule and the content, checked together. A guard nothing in the
    # repository satisfies is a guard that will be turned off.
    (1..3).each do |ep|
      text = Rails.root.join("content", "jp", format("ep%02d", ep), "linkedin_en.md").read.strip
      assert_empty li_violations(text), "ep#{ep} linkedin_en.md"
    end
  end

  test "too many links, too many hashtags and long sentences are each reported" do
    two_links = "A short line.\n\nhttps://a.example/1\nhttps://b.example/2\n"
    assert li_violations(two_links).any? { |x| x.include?("リンク") }, li_violations(two_links).inspect

    four_tags = "A short line.\n\n#a #b #c #d\n"
    assert li_violations(four_tags).any? { |x| x.include?("ハッシュタグ") }, li_violations(four_tags).inspect

    wordy = ([ "word " * 40 ].first.strip + ".") * 1
    assert li_violations(wordy).any? { |x| x.include?("平均") }, li_violations(wordy).inspect
  end

  test "hashtag-only and URL-only lines are excluded from the sentence average" do
    # Otherwise three hashtags and a URL count as four one-word sentences and
    # drag a wordy post under the limit — the measure would reward adding tags.
    wordy_with_tags = ("word " * 40).strip + ".\n\nhttps://a.example/1\n\n#a #b #c\n"
    assert li_violations(wordy_with_tags).any? { |x| x.include?("平均") },
           "the average must describe the prose, not the chrome"
  end

  # ── E. guide_en.pdf ────────────────────────────────────────────────────────
  #
  # Checked over the COMMITTED artifacts rather than by re-running the
  # generator: the generator needs playwright and a browser, which the Rails
  # suite does not have, and what has to be true is a property of the file that
  # actually ships. If a rebuild produces something outside these bounds the
  # build itself fails first (make_episode.mjs asserts the same numbers) —
  # these are the backstop for a file edited or replaced by hand.

  GUIDE_MIN_PAGES = 6
  GUIDE_MAX_PAGES = 10
  GUIDE_MAX_BYTES = 5 * 1024 * 1024

  # /Type /Pages … /Count N is the page-tree root. Counting "/Type /Page"
  # would overcount — the /Pages node itself starts with /Page.
  def pdf_page_count(path)
    raw = path.binread.force_encoding(Encoding::BINARY)
    counts = raw.scan(%r{/Type\s*/Pages[^>]{0,200}?/Count\s+(\d+)}m).flatten.map(&:to_i)
    counts = raw.scan(%r{/Count\s+(\d+)}).flatten.map(&:to_i) if counts.empty?
    refute_empty counts, "could not read a page count out of #{path.basename}"
    counts.max
  end

  test "every committed guide_en.pdf is 6-10 pages and under 5MB" do
    pdfs = Dir[Rails.root.join("content", "jp", "ep*", "guide_en.pdf").to_s].sort.map { |f| Pathname(f) }
    # The guard against a vacuous pass. Without it this test is green on a
    # repository that has no guides at all — the same shape as the sitemap
    # sweep that checked 0 entries and reported ALL CHECKS PASSED.
    assert_operator pdfs.length, :>=, 3, "expected a guide for ep01-ep03, found #{pdfs.length}"

    pdfs.each do |pdf|
      pages = pdf_page_count(pdf)
      assert_operator pages, :>=, GUIDE_MIN_PAGES, "#{pdf.parent.basename}/guide_en.pdf has #{pages} pages"
      assert_operator pages, :<=, GUIDE_MAX_PAGES, "#{pdf.parent.basename}/guide_en.pdf has #{pages} pages"
      assert_operator pdf.size, :<=, GUIDE_MAX_BYTES,
                      "#{pdf.parent.basename}/guide_en.pdf is #{(pdf.size / 1024.0).round}KB"

      # The PNGs and the PDF come off the same DOM, so a mismatch means one of
      # them was produced by a different run.
      pngs = Dir[pdf.parent.join("guide_en_pages", "*.png").to_s]
      assert_equal pages, pngs.length,
                   "#{pdf.parent.basename}: #{pages} PDF pages but #{pngs.length} PNGs"
    end
  end

  test "every guide page PNG is exactly 1080x1350" do
    pngs = Dir[Rails.root.join("content", "jp", "ep*", "guide_en_pages", "*.png").to_s].sort
    assert_operator pngs.length, :>=, 18, "expected >=6 pages for each of ep01-03, found #{pngs.length}"

    pngs.each do |f|
      head = File.binread(f, 24)
      assert_equal "89504e470d0a1a0a", head[0, 8].unpack1("H*"), "#{f} is not a PNG"
      assert_equal "IHDR", head[12, 4], "#{f} has no IHDR where one must be"
      w, h = head[16, 8].unpack("N2")
      assert_equal [ 1080, 1350 ], [ w, h ], "#{File.basename(File.dirname(File.dirname(f)))}/#{File.basename(f)} is #{w}x#{h}"
    end
  end

  test "the guide is attached to an imported package as a PDF, not as octet-stream" do
    # BlogMailer selects attachments BY CONTENT TYPE. Stored as
    # application/octet-stream the guide would be silently skipped by the
    # mailer, and shown by Gmail as an unopenable blob if it got through.
    assert_includes JpEpisodeSource::ASSET_FILES, "guide_en.pdf"
    assert_equal "application/pdf", JpImport.content_type_for(Pathname("x/guide_en.pdf"))
  end

  test "XPublishJob will not hand a PDF to the X media endpoint" do
    # The fallback used to be package_assets.first, which was an image only by
    # accident of list order. An episode with no carousel would have handed the
    # media endpoint a PDF and failed the whole thread.
    assert_equal %w[image/png image/jpeg image/gif video/mp4], XPublishJob::X_MEDIA_TYPES
    refute_includes XPublishJob::X_MEDIA_TYPES, "application/pdf"
  end

  # ── F. JSON-LD inLanguage ──────────────────────────────────────────────────
  #
  # Tested here rather than left to E-1: that snapshot captures canonical,
  # robots, hreflang, og:locale and html lang out of the rendered head and does
  # not look at JSON-LD at all. A snapshot that cannot see a field cannot
  # protect it, and all 38 of its rows are expected to be byte-identical.

  def ld_for(path)
    get path
    assert_response :success
    blocks = response.body.scan(%r{<script type="application/ld\+json">\s*(\{.*?\})\s*</script>}m).flatten
    blocks.map { |b| JSON.parse(b) }.find { |j| j["@type"] == "Article" }
  end

  test "a Korean post declares inLanguage ko" do
    ld = ld_for("/blog/korean-only-post")
    assert_equal "ko", ld["inLanguage"]
    assert_equal "#{helpers_base_url}/blog/korean-only-post", ld["url"],
                 "inLanguage must agree with the document the url field names"
  end

  test "a bilingual Korean post declares ko on its own URL and en on /en" do
    assert_equal "ko", ld_for("/blog/bilingual-post")["inLanguage"]
    assert_equal "en", ld_for("/en/blog/bilingual-post")["inLanguage"]
  end

  test "an untranslated locale declares the language actually served, not the URL's" do
    # /es/blog/:slug falls back to the Korean text and canonicalises at the
    # Korean address, so claiming inLanguage=es would describe a translation
    # that does not exist.
    ld = ld_for("/es/blog/korean-only-post")
    assert_equal "ko", ld["inLanguage"]
  end

  test "a Japanese post still declares ja — the JP track did not move" do
    make_package.update!(status: "published", published_at: 1.day.ago)
    make_topic
    ld = ld_for("/ja/blog/jp-ep#{EP}-s9")
    assert_equal "ja", ld["inLanguage"]
  end

  def helpers_base_url
    ActionController::Base.helpers.instance_eval { nil }
    ENV.fetch("BASE_URL", "https://slimfile.net")
  end
end
