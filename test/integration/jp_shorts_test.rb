require "test_helper"

# S10 (c): the YouTube Shorts cut.
#
# Checked over the COMMITTED artifacts rather than by re-running the generator:
# the generator needs playwright, a browser and ffmpeg, none of which the Rails
# suite has. What has to be true is a property of the file that actually ships.
# make_episode.mjs asserts the same numbers at build time (from ffprobe, not
# from what it asked for) — these are the backstop for a file replaced by hand.
class JpShortsTest < ActiveSupport::TestCase
  WIDTH = 1080
  HEIGHT = 1920
  MAX_SECONDS = 30

  def shorts
    @shorts ||= Dir[Rails.root.join("content", "jp", "ep*", "shorts.mp4").to_s].sort.map { |f| Pathname(f) }
  end

  # mp4 is a box format: a `moov` atom holds `trak`s, and the video track's
  # `tkhd` carries width/height as 16.16 fixed point. Read directly rather than
  # shelling out to ffprobe — the suite must not depend on a binary that is
  # present on this Mac and not in CI.
  def tkhd_dimensions(path)
    raw = path.binread
    out = []
    idx = 0
    while (idx = raw.index("tkhd", idx))
      # tkhd payload: version(1) flags(3) then times; width/height are the LAST
      # 8 bytes of the box. Version 0 box is 92 bytes incl. the 8-byte header.
      version = raw[idx + 4].unpack1("C")
      box_len = version.zero? ? 84 : 96
      tail = raw[(idx + 4 + box_len - 8), 8]
      break if tail.nil? || tail.bytesize < 8

      w, h = tail.unpack("N2")
      out << [ w >> 16, h >> 16 ]
      idx += 4
    end
    out.reject { |w, h| w.zero? || h.zero? }
  end

  test "an episode that has been built carries a Shorts cut" do
    # The guard against a vacuous pass — every assertion below iterates, and an
    # empty list iterates happily. Same shape as the sitemap sweep that checked
    # 0 entries and reported ALL CHECKS PASSED.
    assert_operator shorts.length, :>=, 3,
                    "expected a Shorts cut for ep01-ep03, found #{shorts.length}"
  end

  test "every Shorts cut is exactly 1080x1920 portrait" do
    shorts.each do |f|
      dims = tkhd_dimensions(f)
      assert_includes dims, [ WIDTH, HEIGHT ],
                      "#{f.parent.basename}/shorts.mp4 has no #{WIDTH}x#{HEIGHT} video track (found #{dims.inspect})"
    end
  end

  test "every Shorts cut is within the 30 second cap" do
    # Duration from the mvhd atom: timescale then duration, both 32-bit in a
    # version-0 box. Shorts over 60s are not Shorts at all, and the house limit
    # is 30 (marketing plan §1).
    shorts.each do |f|
      raw = f.binread
      i = raw.index("mvhd")
      refute_nil i, "#{f}: no mvhd atom"
      # mvhd payload after the 4-byte type: version(1) flags(3), then
      #   v0: creation(4) modification(4) timescale(4) duration(4)
      #   v1: creation(8) modification(8) timescale(4) duration(8)
      # so timescale sits at +16 (v0) or +24 (v1) from the type. The first
      # draft read +12/+20 — one field early — which returned the modification
      # time as the timescale and a duration of Infinity. Caught by the test
      # itself rather than by reading the spec twice.
      version = raw[i + 4].unpack1("C")
      timescale, duration = if version.zero?
                              raw[(i + 16), 8].unpack("N2")
      else
                              [ raw[(i + 24), 4].unpack1("N"), raw[(i + 28), 8].unpack1("Q>") ]
      end
      assert_operator timescale, :>, 0, "#{f}: unreadable mvhd timescale"
      seconds = duration.to_f / timescale
      assert_operator seconds, :>, 0, "#{f.parent.basename}: zero-length video"
      assert_operator seconds, :<=, MAX_SECONDS + 0.5,
                      "#{f.parent.basename}/shorts.mp4 is #{seconds.round(2)}s"
    end
  end

  test "every Shorts cut ships a title and a description" do
    shorts.each do |f|
      dir = f.parent
      title = dir.join("shorts_title_ja.txt")
      desc  = dir.join("shorts_desc_ja.txt")
      assert title.exist?, "#{dir.basename}: shorts_title_ja.txt missing"
      assert desc.exist?,  "#{dir.basename}: shorts_desc_ja.txt missing"

      # Question form, <=20 chars, + exactly 3 hashtags (marketing plan §6-3).
      line = title.read.strip
      tags = line.scan(/(?<![\p{Alnum}_#])#[\p{Alnum}_]+/)
      assert_equal 3, tags.length, "#{dir.basename}: #{tags.length} hashtags, want 3"
      headline = line.sub(/\s*#.*\z/m, "").strip
      assert_operator headline.length, :<=, 20,
                      "#{dir.basename}: title is #{headline.length} chars — #{headline}"
      assert_match(/[?？]\z/, headline, "#{dir.basename}: the title should be a question")
    end
  end

  test "the description links with via, carries the required line, and names no unshipped feature" do
    shorts.each do |f|
      body = f.parent.join("shorts_desc_ja.txt").read
      assert_includes body, JpContentGuard.must_line["ja_sentence"],
                       "#{f.parent.basename}: the standing instruction is missing"
      assert_match(/\?via=youtube&ep=ep\d\d/, body, "#{f.parent.basename}: no via-tagged link")
      refute_match(/utm_/, body, "#{f.parent.basename}: still carries a utm_ parameter")

      # The description is published copy like any other surface, so the
      # unshipped-feature rules apply to it too.
      v = JpContentGuard.new(surfaces: { "shorts_desc_ja.txt" => body }).violations
      assert_empty v, "#{f.parent.basename}: #{v.inspect}"
    end
  end

  test "the JS slug mirror agrees with JpEpisodeSource for every planned episode" do
    # make_episode.mjs reimplements the slug because it never talks to the
    # database, and the Shorts description contains the article URL. A mirrored
    # implementation drifts; this compares the two rather than trusting the
    # comment that says they match.
    plan = JSON.parse(Rails.root.join("content", "jp", "topics.json").read)["episodes"]
    assert_operator plan.length, :>=, 30, "premise: the plan is populated"

    js = Rails.root.join("scripts", "content", "make_episode.mjs").read
    assert_match(/function slugFor\(t\)/, js, "the mirror this test exists to check is gone")

    plan.each do |row|
      ruby = JpEpisodeSource.new(dir: Rails.root.join("content", "jp", format("ep%02d", row["ep"])),
                                 topic_row: row, ep: row["ep"]).slug
      epp = format("%02d", row["ep"])
      base = row["title_en"].to_s.downcase
                            .gsub(/[^a-z0-9\-_]+/, "-")
                            .gsub(/-{2,}/, "-")
                            .sub(/\A-/, "").sub(/-\z/, "")[0, 40].to_s.sub(/-\z/, "")
      base = "ep#{epp}" if base.empty?
      assert_equal ruby, "jp-ep#{epp}-#{base}",
                   "ep#{row['ep']}: the JS slug rule and JpEpisodeSource#slug disagree"
    end
  end
end
