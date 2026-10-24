# Weekly roll-up of the anonymous SafeFile counters.
#
#   bin/rails safe:jp_weekly            # last 7 days → docs/jp/metrics/YYYY-WW.md
#   bin/rails safe:jp_weekly[2026-W43]  # name the ISO week explicitly
#
# The file it writes is the evidence for the forecast predictions P6/P10/P11
# (docs/jp/jp_forecast_report_2026-10-22.md) — which document types actually
# arrive, which purpose is chosen, and which landing page sent them. Checking it
# into git is the point: a month of these is a series, and a series is the only
# thing that can falsify a prediction.
#
# It reads SafeEvent and nothing else. There is no per-visitor dimension to
# group by because the table has none, so every number here is an event count,
# NOT a user count — the report says so on its own face, because a reader who
# assumes otherwise will overstate reach.
namespace :safe do
  desc "Aggregate the last 7 days of anonymous SafeFile events into docs/jp/metrics/YYYY-WW.md"
  task :jp_weekly, [ :week ] => :environment do |_t, args|
    # ISO week-based year + ISO week number, so the label matches the week the
    # window actually falls in at a year boundary (%Y-%W would print 2027-W01
    # for days that ISO calls 2026-W53).
    label = args[:week].presence || ENV["WEEK"].presence || Time.current.strftime("%G-W%V")
    # The label becomes a file name, so it is validated rather than sanitised —
    # a silently-rewritten label writes a correct-looking report to the wrong
    # week, which is worse than refusing.
    abort "safe:jp_weekly: week must look like 2026-W43 (got #{label.inspect})" unless label.match?(/\A\d{4}-W\d{2}\z/)

    out_dir = Rails.root.join("docs", "jp", "metrics")
    FileUtils.mkdir_p(out_dir)
    path = out_dir.join("#{label}.md")

    window_end   = Time.current
    window_start = window_end - 7.days
    events = SafeEvent.where(created_at: window_start...window_end)

    total = events.count
    by_name = events.group(:name).count

    # Only group by a dimension the event is actually allowed to carry, read
    # straight off SafeEvent::KEYS. Hard-coding the pairs here is how the two
    # lists drift: add a key to the model and this report keeps reporting the
    # old shape while looking just as finished.
    sections = SafeEvent::KEYS.flat_map do |name, keys|
      keys.map { |key| [ name, key ] }
    end

    lines = []
    lines << "# SafeFile JP 週次カウント — #{label}"
    lines << ""
    lines << "> 自動生成: `bin/rails safe:jp_weekly` · 対象 #{window_start.utc.strftime('%Y-%m-%d %H:%M')} 〜 #{window_end.utc.strftime('%Y-%m-%d %H:%M')} UTC"
    lines << ">"
    lines << "> **이 숫자는 이벤트 수이며 사용자 수가 아니다.** `safe_events` 에는 방문자를"
    lines << "> 식별할 열이 없다(IP·해시·쿠키 전부 없음) — 그래서 중복 제거가 불가능하고,"
    lines << "> 한 사람이 다섯 번 올리면 5로 센다. 추세 비교용으로만 읽을 것."
    lines << ""
    lines << "총 이벤트: **#{total}**"
    lines << ""

    if total.zero?
      lines << "이 기간에 기록된 이벤트가 없다. 가능한 이유는 세 가지이고 서로 구별되지 않는다:"
      lines << "① 실제로 트래픽이 없었다 ② `/api/safe_events` 가 거부하고 있다(422 — 화이트리스트 불일치)"
      lines << "③ 배포본에 계측 코드가 없다. 둘째·셋째는 로그로만 구별된다."
      lines << ""
    else
      lines << "## 이벤트별"
      lines << ""
      lines << "| event | count |"
      lines << "| --- | --- |"
      SafeEvent::NAMES.each { |n| lines << "| #{n} | #{by_name.fetch(n, 0)} |" }
      lines << ""

      sections.each do |name, key|
        counts = events.where(name: name)
                       .group(Arel.sql("props ->> #{ActiveRecord::Base.connection.quote(key)}"))
                       .count
                       .reject { |k, _| k.nil? }
        next if counts.empty?

        lines << "## #{name} × #{key}"
        lines << ""
        lines << "| #{key} | count |"
        lines << "| --- | --- |"
        counts.sort_by { |k, v| [ -v, k.to_s ] }.each { |k, v| lines << "| #{k} | #{v} |" }
        lines << ""
      end
    end

    # ── Content channels (S8) ────────────────────────────────────────────────
    #
    # Added so the weekly file answers "what actually went out" from the
    # database rather than from memory, and so the approval screen can quote the
    # same numbers. Every figure below is derived from Post rows; nothing is
    # typed in. The ones this app CANNOT know (X impressions, YouTube views) are
    # printed as 「—」 with a note, not estimated.
    lines.concat(JpWeeklyKpi.new(window: window_start...window_end).lines)

    lines << "## 예측 대조 (jp_forecast_report §7)"
    lines << ""
    lines << "- P6 (資格確認書 가 doc_class 1위인가): `doc_class × doc_class` 표를 본다."
    lines << "- P10 (입찰 랜딩이 유료 문의를 만드는가): `from=nyusatsu` 의 cta_click 과"
    lines << "  `/admin/jp_pilot_requests` 의 신청 수를 함께 본다 — 이 표만으로는 알 수 없다."
    lines << "- P11 (個人番号手続 선택률): `purpose × purpose` 표에서 `my_number_procedure` 비율."
    lines << "  ⚠️ **`purpose × source` 표를 함께 읽을 것** — `source=init` 행은 랜딩의 `?purpose=`"
    lines << "  프리셀렉트이고 사람의 선택이 아니다. 선택률은 `source=user` 로만 세야 한다."
    lines << ""

    File.write(path, lines.join("\n") + "\n")
    puts "wrote #{path} (#{total} events, #{window_start.utc.iso8601} .. #{window_end.utc.iso8601})"
  end
end
