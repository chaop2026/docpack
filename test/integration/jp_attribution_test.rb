require "test_helper"

# S10: `?via=<channel>&ep=epNN` replaces `?utm_source=…&utm_medium=…&utm_campaign=…`
# in every link we publish, and the measurement reads BOTH.
#
# The switch is not cosmetic. Ad/tracker-blocking browser extensions strip or
# block `?utm_*` before the request is made — measured 2026-10-27, the author's
# own Chrome would not open his own shared link while the server answered 200 to
# everything. A parameter that never arrives measures nothing, and the failure is
# invisible from the server side.
class JpAttributionTest < ActionDispatch::IntegrationTest
  def topic_row(ep = 1)
    JSON.parse(Rails.root.join("content", "jp", "topics.json").read)["episodes"]
        .find { |e| e["ep"] == ep }
  end

  def source(ep = 1)
    JpEpisodeSource.new(dir: Rails.root.join("content", "jp", format("ep%02d", ep)),
                        topic_row: topic_row(ep), ep: ep)
  end

  # ── the links we publish ───────────────────────────────────────────────────

  test "every generated URL uses via/ep and carries no utm_ parameter at all" do
    urls = source.utm.values + [ source.via_url("x"), source.blog_url(:en), source.x_reply_en.to_s ]
    assert_operator urls.length, :>=, 5, "premise: there are URLs to check"

    urls.each do |u|
      refute_match(/utm_/, u, "a published URL still carries a utm_ parameter: #{u}")
    end
    # Positive half: not carrying utm_ would also be satisfied by carrying
    # nothing at all, which would lose the measurement entirely.
    assert_match(/\?via=x&ep=ep01/, source.via_url("x"))
    assert_match(/\?via=linkedin&ep=ep01/, source.blog_url(:en))
    assert_match(/\?via=blog&ep=ep01/, source.utm["blog"])
    assert_match(/\?via=youtube&ep=ep01/, source.utm["youtube"])
  end

  test "the committed episode files carry no utm_ parameter" do
    files = Dir[Rails.root.join("content", "jp", "ep*", "*.md").to_s] +
            Dir[Rails.root.join("content", "jp", "ep*", "manifest.json").to_s]
    assert_operator files.length, :>=, 15, "premise: the episode folders are there"

    offenders = files.select { |f| File.read(f).match?(/[?&]utm_(source|medium|campaign)=/) }
    assert_empty offenders, "these still publish a utm_ URL: #{offenders.join(', ')}"
  end

  test "the in-article CTA links with via, not utm" do
    post = Post.create!(content_track: "jp", content_ep: 91, primary_locale: "ja",
                        status: "published", published_at: 1.day.ago, category: "privacy",
                        slug: "jp-ep91-attribution", title_ja: "テスト", body_ja: "<p>本文</p>",
                        package: { "landing_path" => "/safe/jp/nyusatsu/" })
    get "/ja/blog/#{post.slug}"
    assert_response :success
    # assert_select, not a substring match on the body: the `&` is correctly
    # emitted as `&amp;` in HTML, so a literal "…&ep=…" search fails on markup
    # that is right. The parser hands back the decoded attribute.
    assert_select "a.jp-cta-link[href=?]", "/safe/jp/nyusatsu/?via=blog&ep=ep91"
    refute_match(/utm_source=blog/, response.body)
  end

  # ── what the server will store ─────────────────────────────────────────────

  test "via and ep are storable, and utm_source is still storable" do
    # `utm_source` is deliberately NOT removed: rows already exist with it, and
    # links already published keep arriving on it. Dropping the key would push
    # those visits into "no source", which reads as a traffic fall when what
    # happened is that we stopped counting.
    %w[via utm_source ep].each do |key|
      assert_includes SafeEvent::KEYS["landing_view"], key
      assert_includes SafeEvent::KEYS["cta_click"], key
    end

    e = SafeEvent.create!(name: "landing_view",
                          props: { "from" => "nyusatsu", "locale" => "ja", "via" => "x", "ep" => "ep07" })
    assert_equal "x", e.reload.props["via"]
    assert_equal "ep07", e.props["ep"]
  end

  test "an out-of-range episode is stored as other rather than rejected" do
    # The list is fixed because `ep` arrives in a URL a visitor can edit. A
    # value outside it is a real visit with an unusable label, not a reason to
    # throw the event away.
    sanitized = SafeEvent.sanitize("landing_view", { "from" => "nyusatsu", "ep" => "ep99" })
    assert_nil sanitized, "an unknown value rejects the whole event (existing contract)"
    assert_includes SafeEvent::VALUES["ep"], "other"
    assert_includes SafeEvent::VALUES["ep"], "ep33"
    refute_includes SafeEvent::VALUES["ep"], "ep34"
  end

  # ── the weekly numbers ─────────────────────────────────────────────────────

  test "P16 sums via and utm_source instead of reading only one of them" do
    SafeEvent.delete_all
    SafeEvent.create!(name: "landing_view", props: { "from" => "nyusatsu", "via" => "x" })
    SafeEvent.create!(name: "landing_view", props: { "from" => "nyusatsu", "utm_source" => "x" })
    SafeEvent.create!(name: "landing_view", props: { "from" => "nyusatsu", "via" => "linkedin" })

    k = JpWeeklyKpi.new.p16
    assert_equal 3, k[:social], "two x (one on each parameter) + one linkedin"
    assert_equal 3, k[:total]
    assert_equal 100.0, k[:share]
  end

  test "P16's denominator counts visits that carried no source at all" do
    # The sharp edge. jp.js omits the key entirely on a direct visit, and the
    # grouping helper drops null groups — so summing the groups would silently
    # make the denominator "visits that had a source" and P16 would climb
    # toward 100% as direct traffic grew. It is a share of ALL landing views.
    SafeEvent.delete_all
    SafeEvent.create!(name: "landing_view", props: { "from" => "nyusatsu", "via" => "x" })
    3.times { SafeEvent.create!(name: "landing_view", props: { "from" => "nyusatsu" }) }

    k = JpWeeklyKpi.new.p16
    assert_equal 4, k[:total], "all four visits are in the denominator"
    assert_equal 1, k[:attributed]
    assert_equal 1, k[:social]
    assert_equal 25.0, k[:share]
  end

  test "blog stays out of P16's numerator on the new parameter too" do
    # Cross-review Q5's rule, carried over: the blog's own in-article CTA is
    # internal navigation. Counting it would make the metric rise as the blog
    # grows, which is the opposite of what P16 asks.
    SafeEvent.delete_all
    SafeEvent.create!(name: "landing_view", props: { "from" => "nyusatsu", "via" => "blog" })
    SafeEvent.create!(name: "landing_view", props: { "from" => "nyusatsu", "via" => "x" })

    k = JpWeeklyKpi.new.p16
    assert_equal 1, k[:social]
    assert_equal 1, k[:blog_excluded]
    assert_equal 2, k[:total]
  end

  test "the weekly report shows the two parameters in separate columns" do
    # Not just the sum: the utm_source column is the only signal for "are the
    # old links still being clicked", which is how anyone knows the migration
    # is finished.
    SafeEvent.delete_all
    SafeEvent.create!(name: "landing_view", props: { "from" => "nyusatsu", "via" => "x" })
    SafeEvent.create!(name: "landing_view", props: { "from" => "nyusatsu", "utm_source" => "x" })

    lines = JpWeeklyKpi.new.lines.join("\n")
    assert_match(/via \(신규 링크\)/, lines)
    assert_match(/utm_source \(기존 링크\)/, lines)
    assert_match(/옛 링크가 계속 클릭되고 있다/, lines,
                 "while the old column is non-zero the report has to say so")
  end
end
