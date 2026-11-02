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

  # ── one visit has one source (S10b, cross-review Q1) ───────────────────────

  test "an event carrying BOTH via and utm_source is not stored at all" do
    # Not a style rule. JpWeeklyKpi#attributed_landing_views ADDS the two
    # groupings together, so a row with both would be counted twice — in the
    # one metric (P16) whose whole job is a ratio.
    assert_nil SafeEvent.sanitize("landing_view",
                                  { "from" => "nyusatsu", "via" => "x", "utm_source" => "x" })
    assert_nil SafeEvent.sanitize("cta_click",
                                  { "from" => "nyusatsu", "via" => "x", "utm_source" => "linkedin" })

    assert_no_difference -> { SafeEvent.count } do
      post "/api/safe_events",
           params: { name: "landing_view",
                     props: { from: "nyusatsu", via: "x", utm_source: "x" } }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      assert_response :unprocessable_entity
    end
  end

  test "either key ALONE is still accepted — the rejection is about the pair" do
    # The inverse. Without it, a sanitize that rejected everything would pass
    # the test above and nothing would ever be measured again.
    %w[via utm_source].each do |key|
      assert_difference -> { SafeEvent.count }, 1 do
        post "/api/safe_events",
             params: { name: "landing_view", props: { from: "nyusatsu", key => "x" } }.to_json,
             headers: { "CONTENT_TYPE" => "application/json" }
        assert_response :no_content
      end
      assert_equal "x", SafeEvent.last.props.fetch(key)
    end
  end

  test "the exclusion is declared, not hardcoded in the loop" do
    # So a future third spelling of "which channel" joins the group rather than
    # being added to KEYS and silently double-counted.
    assert_includes SafeEvent::MUTUALLY_EXCLUSIVE_KEYS, %w[via utm_source]
    SafeEvent::MUTUALLY_EXCLUSIVE_KEYS.flatten.each do |k|
      assert SafeEvent::VALUES.key?(k), "#{k} is declared exclusive but is not a real key"
    end
  end

  test "a double-counted pair cannot reach P16 through the endpoint" do
    # End to end: the metric this protects, exercised through the real route.
    SafeEvent.delete_all
    post "/api/safe_events",
         params: { name: "landing_view", props: { from: "nyusatsu", via: "x", utm_source: "x" } }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    post "/api/safe_events",
         params: { name: "landing_view", props: { from: "nyusatsu", via: "x" } }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    k = JpWeeklyKpi.new.p16
    assert_equal 1, k[:total], "only the single-source visit was stored"
    assert_equal 1, k[:social], "and it is counted once, not twice"
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

  # ── `via=email` (S11) ──────────────────────────────────────────────────────
  #
  # Outreach mail is the channel with real volume right now — eight firms on
  # 2026-11-01, the second round planned — and every one of those visits was
  # being recorded as "no source". The playbook asked for the value in §5-3.

  test "via=email is storable through the endpoint" do
    assert_includes SafeEvent::VALUES["via"], "email"

    assert_difference -> { SafeEvent.count }, 1 do
      post "/api/safe_events",
           params: { name: "landing_view", props: { from: "nyusatsu", locale: "ja", via: "email" } }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      assert_response :no_content
    end
    assert_equal "email", SafeEvent.last.props.fetch("via")
  end

  test "utm_source=email is NOT storable — the two lists are not the same list" do
    # `utm_source` describes links that are already published and is frozen.
    # This is asserted rather than left implicit because the server rejecting a
    # value the client was willing to send discards the WHOLE event
    # (sanitize → nil), and sendBeacon never reads the response: the loss would
    # be invisible from both ends. jp.js therefore keeps two arrays, and the
    # test below checks that it does.
    refute_includes SafeEvent::VALUES["utm_source"], "email"
    assert_nil SafeEvent.sanitize("landing_view", { "from" => "nyusatsu", "utm_source" => "email" })
  end

  test "jp.js offers exactly the channels the server will accept, per key" do
    # The two lists live in two files by necessity (one is a static JS asset,
    # one is a Rails model). What can be checked is that they agree — a value
    # the page sends and the server refuses throws the event away silently.
    js = Rails.root.join("public", "safe", "jp", "jp.js").read

    via_js = js[/var VIA_CHANNELS = \[(.*?)\];/m, 1]
    utm_js = js[/var UTM_CHANNELS = \[(.*?)\];/m, 1]
    assert via_js && utm_js, "jp.js no longer declares VIA_CHANNELS / UTM_CHANNELS"

    parse = ->(s) { s.scan(/'([a-z_]+)'/).flatten.sort }

    # 'none' and 'other' are produced by the server-side mapping, never sent as
    # a literal, so they are expected in VALUES and not in the JS arrays.
    assert_equal (SafeEvent::VALUES["via"] - %w[none other]).sort, parse.(via_js),
                 "VIA_CHANNELS and SafeEvent::VALUES['via'] disagree"
    assert_equal (SafeEvent::VALUES["utm_source"] - %w[none other]).sort, parse.(utm_js),
                 "UTM_CHANNELS and SafeEvent::VALUES['utm_source'] disagree"
    refute_equal parse.(via_js), parse.(utm_js),
                 "the two arrays are identical again — sharing one list is how " \
                 "?utm_source=email would get sent and thrown away"
  end

  test "email stays out of P16's numerator and inside its denominator" do
    # Same rule as `blog`, different reason: a mail sent by hand to a named
    # firm is outreach, not social reach. It is the channel with the most
    # volume today, so counting it would let P16 report ≥10% off the back of
    # work P16 was never asked about.
    SafeEvent.delete_all
    3.times { SafeEvent.create!(name: "landing_view", props: { "from" => "nyusatsu", "via" => "email" }) }
    SafeEvent.create!(name: "landing_view", props: { "from" => "nyusatsu", "via" => "x" })

    k = JpWeeklyKpi.new.p16
    assert_equal 1, k[:social], "only the x visit is social"
    assert_equal 3, k[:email_excluded]
    assert_equal 4, k[:total], "all four are in the denominator"
    assert_equal 25.0, k[:share]
    refute_includes JpWeeklyKpi::SOCIAL_SOURCES, "email"
    assert_includes JpWeeklyKpi::NON_SOCIAL_SOURCES, "email"
  end

  test "the P16 row names both exclusions so the number can be read" do
    SafeEvent.delete_all
    SafeEvent.create!(name: "landing_view", props: { "from" => "nyusatsu", "via" => "email" })
    SafeEvent.create!(name: "landing_view", props: { "from" => "nyusatsu", "via" => "blog" })

    row = JpWeeklyKpi.new.rows.find { |r| r["id"] == "P16" }
    assert_match(/blog 1건/, row["detail"])
    assert_match(/email 1건/, row["detail"])
    assert_match(/email/, JpWeeklyKpi.new.lines.join("\n"),
                 "the weekly table has to explain why email is not in the numerator")
  end
end
