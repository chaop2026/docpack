require "test_helper"

# Every file under public/ must be world-readable, because the production
# container does not run as the user who created it.
#
# ── This is a repeat, not a hypothetical ────────────────────────────────────
#
# 2026-10-25 (S8): the whole of public/safe/brand/ was mode 700 owned by root,
# the Dockerfile declares `USER 1000:1000`, and so the favicon, the OG card and
# every manifest icon answered 404 in production. Development never showed it
# because the dev container runs as root. Measured inside the built image at the
# time: "UID1000: NOT READABLE".
#
# 2026-11-02 (S11): it happened again. Three brand images added for the YouTube
# and LINE channels arrived as mode 600 from the Mac, and were committed that
# way before this test existed.
#
# git stores only the executable bit, so a fresh clone would be fine — which is
# exactly why this is easy to miss. `kamal deploy` builds the image with
# `COPY . .` from THIS working tree, so the mode on this disk is the mode in
# production.
class PublicAssetsReadableTest < ActiveSupport::TestCase
  PUBLIC = Rails.root.join("public")

  # Generated at request time, not shipped; mode is whatever the process umask
  # produced and nobody serves them from the image.
  IGNORED = %w[assets/ packs/ .DS_Store].freeze

  test "every file under public/ is readable by other" do
    offenders = public_files.reject { |f| File.stat(f).mode & 0o004 != 0 }

    assert_empty offenders.map { |f| "#{relative(f)} (mode #{format('%o', File.stat(f).mode & 0o777)})" },
                 "these files are not world-readable, so the production container " \
                 "(USER 1000:1000, see Dockerfile) will answer 404 for them:\n  " \
                 "fix with: chmod 644 <file>"
  end

  test "every directory under public/ is traversable by other" do
    # A readable file inside an unsearchable directory is still a 404 — the
    # S8 failure was the directory, not the files in it.
    dirs = Dir[PUBLIC.join("**/").to_s].reject { |d| ignored?(d) }
    assert_operator dirs.length, :>=, 5, "premise: public/ has subdirectories"

    offenders = dirs.reject { |d| File.stat(d).mode & 0o001 != 0 && File.stat(d).mode & 0o004 != 0 }
    assert_empty offenders.map { |d| "#{relative(d)} (mode #{format('%o', File.stat(d).mode & 0o777)})" },
                 "these directories are not world-readable/traversable:\n  fix with: chmod 755 <dir>"
  end

  test "the brand directory is covered by the check above" do
    # Vacuity guard. If `public_files` ever stopped returning anything — a
    # changed glob, a renamed directory — both tests above would pass having
    # examined nothing, which is the failure shape this repository has shipped
    # once already (canonical_sweep.rb passing with 0 entries).
    files = public_files
    assert_operator files.length, :>=, 20, "only #{files.length} files were examined"

    brand = files.select { |f| relative(f).start_with?("safe/brand/") }
    assert_operator brand.length, :>=, 10,
                    "public/safe/brand/ is the directory this test exists for and only " \
                    "#{brand.length} of its files were examined"
  end

  private

  def public_files
    Dir[PUBLIC.join("**", "*").to_s].select { |f| File.file?(f) && !ignored?(f) }
  end

  def ignored?(path)
    rel = relative(path)
    IGNORED.any? { |i| rel.start_with?(i) || File.basename(rel) == i }
  end

  def relative(path)
    Pathname.new(path).relative_path_from(PUBLIC).to_s
  end
end
