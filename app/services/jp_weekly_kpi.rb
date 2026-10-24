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
      statement: "ブログ・X・LinkedIn のチャネル別実績が累計 #{P18_TARGET} 件以上",
      target: P18_TARGET,
      current: c[:total],
      detail: "blog #{c[:blog]} + X #{c[:x]} + LinkedIn #{c[:linkedin]}"
    }
  end

  # P16 — share of landing visits arriving from social.
  #
  # `utm_source=blog` is EXCLUDED from the numerator (cross-review Q5). The
  # blog's own in-article CTA is not a social referral; counting it would make
  # the metric measure our own internal linking and drift upward as the blog
  # grows, which is the opposite of what P16 is for.
  SOCIAL_SOURCES = %w[x linkedin youtube].freeze

  def p16
    by_source = landing_views_by("utm_source")
    total = by_source.values.sum
    social = by_source.slice(*SOCIAL_SOURCES).values.sum
    {
      total: total,
      social: social,
      blog_excluded: by_source.fetch("blog", 0),
      share: total.zero? ? nil : (social.to_f / total * 100).round(1)
    }
  end

  # P17 — YouTube only. v3's table had it covering "SNS", which it never did.
  # There is no YouTube channel yet and this app has no YouTube data, so the
  # honest answer is 「—」 rather than 0: zero would read as "measured and found
  # nothing".
  def p17
    { current: nil, note: "YouTube 実測のみ。チャネル未開設 — 計測元がない" }
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
  def rows
    p16v = p16
    [
      { "id" => "P1", "statement" => "ランディング3ページの週次閲覧", "target" => "≥300/月",
        "current" => p1_p10[:total].to_s, "detail" => "landing_view イベント(この期間)" },
      { "id" => "P10", "statement" => "入札ランディングの閲覧", "target" => "≥1,500/月",
        "current" => p1_p10[:nyusatsu].to_s, "detail" => "from=nyusatsu" },
      { "id" => "P15", "statement" => "X・YouTube・Instagram 累計 ≥24(原文のまま)", "target" => "24",
        "current" => "—", "detail" => "Instagram 보류·YouTube 미개설 — 이 표로는 셀 수 없다. P18 을 볼 것" },
      { "id" => "P16", "statement" => "ランディング流入のうちソーシャル経由", "target" => "≥10%",
        "current" => p16v[:share] ? "#{p16v[:share]}%" : "—",
        "detail" => "x+linkedin+youtube #{p16v[:social]} / #{p16v[:total]} " \
                    "(utm_source=blog #{p16v[:blog_excluded]}件は分母にのみ含め分子から除外)" },
      { "id" => "P17", "statement" => "YouTube 累計再生", "target" => "≥3,000",
        "current" => "—", "detail" => p17[:note] },
      { "id" => "P18", "statement" => p18_row[:statement], "target" => P18_TARGET.to_s,
        "current" => p18_row[:current].to_s, "detail" => p18_row[:detail] }
    ]
  end

  def lines
    out = []
    out << "## コンテンツ・チャネル実績 (S8)"
    out << ""
    out << "| # | 指標 | 目標 | 現在 | 内訳 |"
    out << "| --- | --- | --- | --- | --- |"
    rows.each { |r| out << "| #{r['id']} | #{r['statement']} | #{r['target']} | **#{r['current']}** | #{r['detail']} |" }
    out << ""
    out << "### ja ブログ"
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
    out << "### UTM別ランディング流入"
    out << ""
    utm = landing_views_by("utm_source")
    if utm.empty?
      out << "この期間に `landing_view` が記録されていない。"
      out << ""
      out << "> ⚠️ `utm_source` は 2026-10-25 に追加した次元で、**その日より前のイベントには"
      out << "> 存在しない**。空であることは「ソーシャル流入が0だった」ではなく「この次元を"
      out << "> 送る版がまだ配備されていない」を意味する場合がある — 配備日より前の週は"
      out << "> この表を根拠に P16 を判定しないこと。"
    else
      out << "| utm_source | count |"
      out << "| --- | --- |"
      utm.sort_by { |k, v| [ -v, k.to_s ] }.each { |k, v| out << "| #{k} | #{v} |" }
      out << ""
      out << "> `none` = utm_source が付いていない訪問。`other` = 一覧外の値。"
      out << "> P16 の分子は x + linkedin + youtube のみ(`blog` は自サイト内リンクなので除外)。"
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
