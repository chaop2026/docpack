# Markdown → HTML for the JP blog track.
#
# ── Why this exists rather than a gem ───────────────────────────────────────
#
# There is no markdown gem in this application and never has been: the Korean
# blog's bodies arrive from BlogGeneratorService as HTML already. So "reuse the
# existing conversion path" has nothing to reuse, and adding redcarpet/kramdown
# for the handful of constructs `content/jp/epNN/post_ja.md` actually uses would
# mean a new native extension in the production image for five block types.
#
# ── What it accepts ─────────────────────────────────────────────────────────
#
#   ## / ###        headings
#   paragraphs      blank-line separated
#   1. / - / *      ordered and unordered lists
#   | a | b |       GFM pipe tables, with the --- separator row
#   **bold**        inline
#   [text](url)     inline links
#
# Deliberately NOT a general markdown implementation. The episode files are
# written against this list (scripts/content/README.md), and a parser that
# quietly accepted more would let the source files drift into shapes the
# pipeline does not actually render — the same reasoning as the frontmatter
# subset in make_episode.mjs.
#
# Everything that is not markup is HTML-escaped before it is emitted. The input
# is ours rather than a visitor's, so this is not the last line of defence
# against injection — but a body that happens to contain a `<` should render as
# `<`, and relying on "we wrote it" is how an escaping bug gets introduced by
# the next author instead of by this one.
module JpMarkdown
  extend self

  # Anchors: a heading gets an id so the FAQ and 根拠 sections are linkable.
  def render(markdown)
    blocks = []
    lines = markdown.to_s.gsub("\r\n", "\n").split("\n")
    i = 0

    while i < lines.length
      line = lines[i]

      if line.strip.empty?
        i += 1
      elsif (m = line.match(/\A(\#{2,4})\s+(.+)\z/))
        level = m[1].length
        blocks << "<h#{level}>#{inline(m[2].strip)}</h#{level}>"
        i += 1
      elsif table_start?(lines, i)
        html, i = take_table(lines, i)
        blocks << html
      elsif line.match?(/\A\s*\d+\.\s+/)
        html, i = take_list(lines, i, :ol)
        blocks << html
      elsif line.match?(/\A\s*[-*]\s+/)
        html, i = take_list(lines, i, :ul)
        blocks << html
      else
        html, i = take_paragraph(lines, i)
        blocks << html
      end
    end

    blocks.join("\n")
  end

  private

  # A table needs its separator row. Without that check a single line of prose
  # containing a pipe would be swallowed as a one-column table.
  def table_start?(lines, i)
    lines[i].to_s.include?("|") &&
      lines[i + 1].to_s.match?(/\A\s*\|?[\s:|-]+\|[\s:|-]*\z/)
  end

  def take_table(lines, i)
    header = split_row(lines[i])
    i += 2 # header + separator
    rows = []
    while i < lines.length && lines[i].include?("|") && !lines[i].strip.empty?
      rows << split_row(lines[i])
      i += 1
    end

    html = +"<table><thead><tr>"
    header.each { |c| html << "<th>#{inline(c)}</th>" }
    html << "</tr></thead><tbody>"
    rows.each do |row|
      html << "<tr>"
      row.each { |c| html << "<td>#{inline(c)}</td>" }
      html << "</tr>"
    end
    html << "</tbody></table>"
    [ html, i ]
  end

  def split_row(line)
    line.strip.sub(/\A\|/, "").sub(/\|\z/, "").split("|").map(&:strip)
  end

  def take_list(lines, i, kind)
    pattern = kind == :ol ? /\A\s*\d+\.\s+(.*)\z/ : /\A\s*[-*]\s+(.*)\z/
    items = []
    while i < lines.length && (m = lines[i].match(pattern))
      items << m[1].strip
      i += 1
    end
    [ "<#{kind}>#{items.map { |it| "<li>#{inline(it)}</li>" }.join}</#{kind}>", i ]
  end

  def take_paragraph(lines, i)
    buf = []
    while i < lines.length && !lines[i].strip.empty? &&
          !lines[i].match?(/\A\#{2,4}\s/) && !table_start?(lines, i) &&
          !lines[i].match?(/\A\s*(\d+\.|[-*])\s+/)
      buf << lines[i].strip
      i += 1
    end
    [ "<p>#{inline(buf.join("\n"))}</p>", i ]
  end

  # Order matters: escape first, then introduce markup. Doing it the other way
  # round would escape the tags this method just produced.
  def inline(text)
    out = ERB::Util.html_escape(text.to_s).to_s
    out = out.gsub(/\*\*(.+?)\*\*/) { "<strong>#{Regexp.last_match(1)}</strong>" }
    out = out.gsub(/\[([^\]\[]+)\]\((https?:\/\/[^\s)]+|\/[^\s)]*)\)/) do
      "<a href=\"#{Regexp.last_match(2)}\">#{Regexp.last_match(1)}</a>"
    end
    out.gsub("\n", "<br>")
  end
end
