# The content-channel section of the weekly roll-up, and the KPI table the
# approval screen and the review email both show.
#
# One class, three readers (`safe:jp_weekly`, BlogMailer#jp_review_requested,
# Admin::JpPackagesController), because a KPI that is computed twice is a KPI
# that disagrees with itself in one of the two places — and the one a person
# acts on is whichever they happened to open.
#
# ── Everything here is derived, and what is not derivable says so ───────────
#
# Blog posts, X threads and LinkedIn URLs come from Post rows. X impressions and
# YouTube views do not exist in this database and are printed as 「—」. An
# estimate in a KPI table becomes a fact the next time someone quotes it.
class JpWeeklyKpi
  # P18 — the new row cross-review Q5 asked for.
  #
  # P15 is NOT redefined. Its original text counts X + YouTube + Instagram, and
  # Instagram is now on hold; v3 claimed that "inherits" the same definition,
  # which it does not. So P15 keeps its wording and its channels (the forecast
  # report's rule is that a prediction past its check date is never edited), and
  # P18 is added as a separate row for the channels actually being operated.
  P18_TARGET = 24
  P18_DUE = Date.new(2027, 1, 22)

  attr_reader :window

  def initialize(window: nil)
    @window = window
  end

  # One "piece" per channel per episode, which is how the forecast report counts
  # and is why a single blog post is not one piece but up to three:
  #   blog published            → 1
  #   X thread fully delivered  → 1   (the JA thread plus its English reply)
  #   LinkedIn URL recorded     → 1
  def p18_counts
    posts = Post.jp
    {
      blog: posts.published.count,
      x: posts.select { |p| p.package.dig("x", "state") == "done" }.size,
      linkedin: posts.select { |p| p.package.dig("posted", "linkedin_url").present? }.size
    }.tap { |h| h[:total] = h[:blog] + h[:x] + h[:linkedin] }
  end

  def p18_row
    c = p18_counts
    {
      id: "P18",
      due: P18_DUE.iso8601,
      statement: "블로그·X·LinkedIn 채널별 실적이 누적 #{P18_TARGET}건 이상",
      target: P18_TARGET,
      current: c[:total],
      detail: "blog #{c[:blog]} + X #{c[:x]} + LinkedIn #{c[:linkedin]}"
    }
  end

  # P16 — share of landing visits arriving from social.
  #
  # `blog` is EXCLUDED from the numerator (cross-review Q5). The blog's own
  # in-article CTA is not a social referral; counting it would make the metric
  # measure our own internal linking and drift upward as the blog grows, which
  # is the opposite of what P16 is for.
  SOCIAL_SOURCES = %w[x linkedin youtube].freeze

  # Both parameter names, summed (S10). Links published from 2026-11-01 carry
  # `?via=`; everything already out there carries `?utm_source=` and keeps being
  # clicked. Reading only one of them would report a drop that is really a
  # change of spelling.
  ATTRIBUTION_KEYS = %w[via utm_source].freeze

  def p16
    by_source = attributed_landing_views

    # ── the denominator is ALL landing views, not just attributed ones ───────
    #
    # Counted from the events, NOT from `by_source.values.sum`. jp.js omits the
    # key entirely on a direct visit (sending via:'none' AND utm_source:'none'
    # would write the same non-fact into two columns), and `landing_views_by`
    # drops null groups — so summing the groups would quietly make the
    # denominator "visits that had a source", and P16 would approach 100% as
    # direct traffic grew. The metric is a share of ALL visits.
    total = scoped(SafeEvent.where(name: "landing_view")).count
    social = by_source.slice(*SOCIAL_SOURCES).values.sum
    {
      total: total,
      social: social,
      blog_excluded: by_source.fetch("blog", 0),
      attributed: by_source.values.sum,
      share: total.zero? ? nil : (social.to_f / total * 100).round(1)
    }
  end

  # { "x" => n, "linkedin" => n, … } — `via` and `utm_source` added together.
  # An event carries at most one of the two (jp.js sends whichever it found),
  # so adding cannot double-count a single visit.
  def attributed_landing_views
    ATTRIBUTION_KEYS.each_with_object(Hash.new(0)) do |key, acc|
      landing_views_by(key).each { |source, n| acc[source] += n }
    end
  end

  # P17 — YouTube only. v3's table had it covering "SNS", which it never did.
  # There is no YouTube channel yet and this app has no YouTube data, so the
  # honest answer is 「—」 rather than 0: zero would read as "measured and found
  # nothing".
  def p17
    { current: nil, note: "YouTube 실측만. 채널 미개설 — 계측 원본이 없다" }
  end

  # `from` is the landing page's own slug (nyusatsu | honnin | aimae | direct) —
  # SafeEvent::KEYS allows nothing else on a landing_view. Not `page`, which
  # does not exist: an earlier draft of this class grouped by it and would have
  # reported 0 for every row while looking exactly as finished.
  def p1_p10
    by_page = landing_views_by("from")
    { nyusatsu: by_page.fetch("nyusatsu", 0), total: by_page.values.sum }
  end

  # [{id:, statement:, target:, current:, detail:}] — the table the approval
  # screen and the review mail render. Plain strings and integers only: it
  # crosses an ActiveJob serialization boundary on its way into the mail.
  #
  # ── Korean, since S9 ────────────────────────────────────────────────────────
  #
  # These were Japanese, which made the KPI table the one part of the Korean
  # approval screen the approver could not read. `rows` has exactly two
  # consumers — that screen and the review mail — and both are now Korean, so
  # there was no third reader the Japanese was serving.
  #
  # The P-NUMBER is what ties a row to docs/jp/jp_forecast_report_2026-10-22.md,
  # not the sentence, so translating the sentence does not detach it from the
  # prediction. Targets, channel sets and `current` values are untouched:
  # strategy §6 forbids revising a predicted value, and that is what P15's
  # 「원문 그대로」 marker is about — the channel set is still X·YouTube·Instagram,
  # which is precisely why this table cannot compute it.
  def rows
    p16v = p16
    [
      { "id" => "P1", "statement" => "랜딩 3페이지의 주간 열람", "target" => "≥300/월",
        "current" => p1_p10[:total].to_s, "detail" => "landing_view 이벤트(이 기간)" },
      { "id" => "P10", "statement" => "입찰 랜딩의 열람", "target" => "≥1,500/월",
        "current" => p1_p10[:nyusatsu].to_s, "detail" => "from=nyusatsu" },
      { "id" => "P15", "statement" => "X·YouTube·Instagram 누적 ≥24 (예측 보고서 원문 그대로)", "target" => "24",
        "current" => "—", "detail" => "Instagram 보류·YouTube 미개설 — 이 표로는 셀 수 없다. P18 을 볼 것" },
      { "id" => "P16", "statement" => "랜딩 유입 중 소셜 경유", "target" => "≥10%",
        "current" => p16v[:share] ? "#{p16v[:share]}%" : "—",
        "detail" => "x+linkedin+youtube #{p16v[:social]} / #{p16v[:total]} " \
                    "(blog #{p16v[:blog_excluded]}건은 분모에만 넣고 분자에서 제외)" },
      { "id" => "P17", "statement" => "YouTube 누적 재생", "target" => "≥3,000",
        "current" => "—", "detail" => p17[:note] },
      { "id" => "P18", "statement" => p18_row[:statement], "target" => P18_TARGET.to_s,
        "current" => p18_row[:current].to_s, "detail" => p18_row[:detail] }
    ]
  end

  def lines
    out = []
    out << "## 콘텐츠·채널 실적 (S8)"
    out << ""
    out << "| # | 지표 | 목표 | 현재 | 내역 |"
    out << "| --- | --- | --- | --- | --- |"
    rows.each { |r| out << "| #{r['id']} | #{r['statement']} | #{r['target']} | **#{r['current']}** | #{r['detail']} |" }
    out << ""
    out << "### ja 블로그"
    out << ""
    out << "| ep | slug | status | published (JST) | PV | X | LinkedIn |"
    out << "| --- | --- | --- | --- | --- | --- | --- |"
    Post.jp.order(:content_ep).each do |p|
      out << "| #{p.content_ep} | `#{p.slug}` | #{p.status} | " \
             "#{p.published_at&.in_time_zone('Asia/Tokyo')&.strftime('%Y-%m-%d %H:%M') || '—'} | " \
             "#{p.view_count} | #{x_cell(p)} | #{p.package.dig('posted', 'linkedin_url').presence || '—'} |"
    end
    out << ""
    out << "> PV は `posts.view_count` の累計で、この期間だけの数ではない(列が1つしかない)。"
    out << "> X のインプレッションと YouTube の再生数はこの DB に存在しない — 「—」は"
    out << "> 「測って0だった」ではなく「測る元がない」の意味。"
    out << ""
    out << "### 유입 채널별 랜딩 방문 (via + utm_source 합산)"
    out << ""
    merged = attributed_landing_views
    p16v = p16
    if merged.empty?
      out << "이 기간에 출처가 기록된 `landing_view` 가 없다" \
             "(전체 landing_view #{p16v[:total]}건)."
      out << ""
      out << "> ⚠️ 두 차원 모두 배포 후에만 쌓인다 — `utm_source` 는 2026-10-25,"
      out << "> `via` 는 2026-11-01(S10) 에 추가했다. 비어 있다는 것은 「소셜 유입이 0이었다」가"
      out << "> 아니라 **「이 차원을 보내는 버전이 아직 배포되지 않았다」** 일 수 있다 —"
      out << "> 배포일 이전 주는 이 표를 근거로 P16 을 판정하지 말 것."
    else
      # 두 열로 나눠 보여준다. 합계만 보면 「옛 링크가 아직 얼마나 돌고 있는지」를 알 수 없고,
      # 그것이 utm → via 전환이 끝났는지 판단하는 유일한 신호다.
      via = landing_views_by("via")
      utm = landing_views_by("utm_source")
      out << "| 채널 | via (신규 링크) | utm_source (기존 링크) | 합계 |"
      out << "| --- | --- | --- | --- |"
      merged.sort_by { |k, v| [ -v, k.to_s ] }.each do |k, v|
        out << "| #{k} | #{via.fetch(k, 0)} | #{utm.fetch(k, 0)} | **#{v}** |"
      end
      out << ""
      out << "> 전체 landing_view **#{p16v[:total]}건** 중 출처가 기록된 것 #{p16v[:attributed]}건."
      out << "> 나머지는 파라미터 없이 들어온 방문이며 **P16 의 분모에는 포함**된다."
      out << "> P16 의 분자는 x + linkedin + youtube 만(`blog` 는 자사 내부 링크이므로 제외)."
      out << "> `other` = 목록 밖 값."
      if utm.values.sum.positive?
        out << "> ℹ️ `utm_source` 열이 아직 0이 아니라는 것은 **옛 링크가 계속 클릭되고 있다**는 뜻이다."
        out << "> 그 열이 0이 될 때까지 두 열을 함께 읽어야 한다."
      end
    end
    out << ""
    out
  end

  private

  # One place that knows the shape. `props ->> key` with the key quoted through
  # the connection, nils dropped — a nil bucket means "the event predates this
  # dimension", which is a different fact from any of the allowed values and
  # must not be silently folded into one of them.
  def landing_views_by(key)
    scoped(SafeEvent.where(name: "landing_view"))
      .group(Arel.sql("props ->> #{ActiveRecord::Base.connection.quote(key)}"))
      .count
      .reject { |k, _| k.nil? }
  end

  def x_cell(post)
    state = post.package.dig("x", "state")
    return "—" if state.blank?

    url = post.package.dig("x", "url")
    dry = post.package.dig("x", "dry_run") ? " (DRY RUN)" : ""
    url.present? ? "#{state}#{dry} #{url}" : "#{state}#{dry}"
  end

  def scoped(relation)
    window ? relation.where(created_at: window) : relation
  end
end
