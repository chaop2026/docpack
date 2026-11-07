require "test_helper"
require "open3"
require "tmpdir"

# bin/admin-password-reset — S15, 2026-11-07.
#
# The tool rotates ADMIN_PASSWORD inside .env.production.local, a file that is
# not in git and exists only on one Mac. Everything here is exercised against a
# FAKE env file in tmp/; the real .env.production.local is never read, written,
# backed up, or named as a target by these tests.
#
# Three properties are worth a test more than the happy path is:
#
#   * the other lines survive byte for byte — this file holds every production
#     secret, and "probably fine" is not a basis for touching it
#   * the generated password never appears in stdout or stderr — a terminal
#     scrollback is permanent, so a tool that prints the secret has not rotated
#     anything
#   * nothing is deleted — the script has no `rm`. On failure it leaves the
#     staged file in place and says where it is
#
# No temp directory is removed afterwards, deliberately: tmp/ is gitignored, and
# a test suite that calls rmtree is doing the thing the deletion-safety policy
# exists to prevent. The leftovers are a handful of small text files.
class AdminPasswordResetTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("bin", "admin-password-reset").to_s

  ORIGINAL_ENV = <<~ENVFILE
    # production secrets — do not commit
    RAILS_MASTER_KEY=mk-aaaaaaaaaaaaaaaa
    ADMIN_PASSWORD=the-old-one
    GMAIL_USERNAME=someone@example.com
    GMAIL_PASSWORD=app-specific-aaaa
    KAMAL_REGISTRY_PASSWORD=ghp_aaaaaaaaaaaaaaaa

    # trailing comment
  ENVFILE

  test "the script is executable" do
    assert File.executable?(SCRIPT), "bin/admin-password-reset must have the executable bit"
  end

  test "it is valid bash" do
    _out, err, status = Open3.capture3("bash", "-n", SCRIPT)
    assert status.success?, "bash -n failed: #{err}"
  end

  # The script must not contain a deletion, at all. ~/.claude/CLAUDE.md's
  # deletion policy names "writing it into a script file and running that" as a
  # forbidden route, so the absence is a property of the file rather than of how
  # it happens to be invoked.
  test "the script contains no deletion command" do
    code = File.readlines(SCRIPT).reject { |line| line.strip.start_with?("#") }.join

    assert_no_match(/\brm\b/, code, "no rm")
    assert_no_match(/\brmdir\b/, code, "no rmdir")
    assert_no_match(/\bunlink\b/, code, "no unlink")
    assert_no_match(/\bshred\b/, code, "no shred")
    assert_no_match(/-delete\b/, code, "no find -delete")
  end

  # ── the happy path ──────────────────────────────────────────────────────────

  test "it replaces only the ADMIN_PASSWORD line" do
    env_file, clip = fixture_env
    before = File.read(env_file)

    out, err, status = run_reset(env_file, clip)
    assert status.success?, "script failed:\n#{out}\n#{err}"

    after = File.read(env_file)
    assert_equal other_lines(before), other_lines(after),
                 "every line except ADMIN_PASSWORD must be byte-identical"
    assert_equal before.lines.length, after.lines.length
    assert_equal 1, after.lines.count { |l| l.start_with?("ADMIN_PASSWORD=") }
    assert_not_includes after, "the-old-one", "the previous value must be gone"
  end

  test "the new value is alphanumeric and at least 24 characters" do
    env_file, clip = fixture_env
    run_reset!(env_file, clip)

    value = admin_password_in(env_file)
    assert_operator value.length, :>=, 24, "generated password is too short"
    assert_match(/\A[A-Za-z0-9]+\z/, value, "generated password must be alphanumeric only")
  end

  # Two consecutive runs must not produce the same value — the whole point is a
  # fresh secret, and a broken generator (a fixed seed, an empty openssl) would
  # otherwise pass every other assertion here.
  test "two runs produce different passwords" do
    first_file, first_clip = fixture_env
    second_file, second_clip = fixture_env
    run_reset!(first_file, first_clip)
    run_reset!(second_file, second_clip)

    assert_not_equal admin_password_in(first_file), admin_password_in(second_file)
  end

  test "neither stdout nor stderr contains the new password" do
    env_file, clip = fixture_env
    out, err = run_reset!(env_file, clip)

    secret = admin_password_in(env_file)

    # Deliberately not assert_not_includes: on failure that prints both sides,
    # which would write the secret into the test output — the exact thing under
    # test.
    assert !out.include?(secret), "stdout contained the generated password"
    assert !err.include?(secret), "stderr contained the generated password"

    # And a vacuity guard: the output has to be substantial enough for the
    # absence to mean something. An empty stdout trivially "does not contain" it.
    assert_operator out.length, :>, 200, "stdout was too short for the check to mean anything"
    assert_includes out, "클립보드"
  end

  test "it copies the new password to the clipboard command" do
    env_file, clip = fixture_env
    run_reset!(env_file, clip)

    assert File.exist?(clip), "the pbcopy stand-in was not invoked"
    assert_equal admin_password_in(env_file), File.read(clip),
                 "the clipboard must receive exactly the value written to the file"
    assert_not_includes File.read(clip), "\n", "no trailing newline in the clipboard"
  end

  test "it tells the operator to store the password in Bitwarden" do
    env_file, clip = fixture_env
    out, = run_reset!(env_file, clip)

    assert_includes out, "Bitwarden"
  end

  # ── the backup ──────────────────────────────────────────────────────────────

  test "it writes a timestamped backup identical to the original" do
    env_file, clip = fixture_env
    before = File.read(env_file)

    run_reset!(env_file, clip)

    backups = Dir.glob("#{env_file}.bak-*")
    assert_equal 1, backups.length, "expected exactly one backup, got #{backups.inspect}"
    assert_match(/\.bak-\d{8}-\d{6}\z/, backups.first, "backup name must carry YYYYmmdd-HHMMSS")
    assert_equal before, File.read(backups.first), "the backup must be the original, byte for byte"
  end

  test "the backup pattern is gitignored" do
    out, _err, status = Open3.capture3(
      "git", "-C", Rails.root.to_s, "check-ignore", "-v",
      ".env.production.local", ".env.production.local.bak-19700101-000000"
    )

    assert status.success?, "git check-ignore reported the paths as not ignored"
    assert_equal 2, out.lines.length
  end

  # Running the tool must not edit the repository. The first version of
  # ensure_ignored() appended to .gitignore whenever check-ignore failed, which
  # would have made "git is unavailable" indistinguishable from "not ignored".
  test "running the tool does not modify .gitignore" do
    gitignore = Rails.root.join(".gitignore")
    before = Digest::SHA256.hexdigest(gitignore.read)

    env_file, clip = fixture_env
    run_reset!(env_file, clip)

    assert_equal before, Digest::SHA256.hexdigest(gitignore.read)
  end

  # ── refusals ────────────────────────────────────────────────────────────────

  test "a missing env file aborts with guidance and writes nothing" do
    dir = workdir
    missing = File.join(dir, "absent.env")

    out, _err, status = run_reset(missing, File.join(dir, "clip"))

    assert_equal 1, status.exitstatus
    assert_not status.success?
    assert_includes out, "없습니다"
    assert_includes out, "Bitwarden"
    assert_empty Dir.glob("#{missing}*"), "nothing may be created when the target is absent"
  end

  test "two ADMIN_PASSWORD lines are refused rather than guessed at" do
    dir = workdir
    env_file = File.join(dir, "env")
    File.write(env_file, "ADMIN_PASSWORD=one\nOTHER=x\nADMIN_PASSWORD=two\n")

    out, _err, status = run_reset(env_file, File.join(dir, "clip"))

    assert_not status.success?
    assert_includes out, "2 개"
    assert_equal "ADMIN_PASSWORD=one\nOTHER=x\nADMIN_PASSWORD=two\n", File.read(env_file),
                 "the file must be untouched"
    assert_empty Dir.glob("#{env_file}.bak-*"), "no backup for a refused run"
  end

  test "a file with no ADMIN_PASSWORD line gets one appended" do
    dir = workdir
    env_file = File.join(dir, "env")
    File.write(env_file, "RAILS_MASTER_KEY=mk\nGMAIL_USERNAME=a@b.c\n")

    out, = run_reset!(env_file, File.join(dir, "clip"))

    lines = File.readlines(env_file)
    assert_equal 3, lines.length
    assert_equal "RAILS_MASTER_KEY=mk\n", lines[0]
    assert_equal "GMAIL_USERNAME=a@b.c\n", lines[1]
    assert_match(/\AADMIN_PASSWORD=[A-Za-z0-9]{24,}\n?\z/, lines[2])
    assert_includes out, "추가했습니다"
  end

  # A file whose last line has no newline is the one case where a byte outside
  # the ADMIN_PASSWORD line changes. The script says so rather than letting it
  # pass unmentioned.
  test "a missing trailing newline is reported, not silently added" do
    dir = workdir
    env_file = File.join(dir, "env")
    File.write(env_file, "ADMIN_PASSWORD=old\nLAST=nonewline")

    out, = run_reset!(env_file, File.join(dir, "clip"))

    assert_includes out, "마지막 줄에 개행이 없습니다"
    assert_equal "LAST=nonewline\n", File.readlines(env_file).last
  end

  test "a world-readable env file is called out" do
    dir = workdir
    env_file = File.join(dir, "env")
    File.write(env_file, ORIGINAL_ENV)
    File.chmod(0o644, env_file)

    out, = run_reset!(env_file, File.join(dir, "clip"))

    assert_includes out, "다른 사용자가 읽을 수 있습니다"
  end

  # ── deploy ──────────────────────────────────────────────────────────────────
  #
  # Answering "n" must not deploy, and the deploy directory handed to the script
  # does not exist in any of these tests — so even an accidental "y" cannot run
  # kamal. The deploy branch itself is not executed by the suite; it talks to a
  # real server.

  test "answering n does not deploy and prints the command instead" do
    env_file, clip = fixture_env
    out, = run_reset!(env_file, clip, answer: "n\n")

    assert_includes out, "배포하지 않았습니다"
    assert_includes out, "배포 전용 폴더가 없습니다"
    # The line the script prints immediately before shelling out to kamal.
    assert_not_includes out, "에서 kamal deploy"
  end

  test "an empty answer is treated as no" do
    env_file, clip = fixture_env
    out, = run_reset!(env_file, clip, answer: "\n")

    assert_includes out, "배포하지 않았습니다"
  end

  test "closed stdin is treated as no rather than hanging or crashing" do
    env_file, clip = fixture_env
    out, _err, status = run_reset(env_file, clip, answer: "")

    assert status.success?
    assert_includes out, "배포하지 않았습니다"
  end

  # y with no deploy-only folder refuses and explains. ~/.claude/CLAUDE.md's
  # "배포 폴더 분리" rule forbids deploying from the development folder, and
  # ~/Projects/docpack-deploy does not exist, so "y" cannot mean "deploy from
  # here". The directory passed here is absent, so kamal is never reached.
  test "answering y without a deploy-only folder refuses to deploy" do
    env_file, clip = fixture_env
    out, _err, status = run_reset(env_file, clip, answer: "y\n")

    assert status.success?, "refusing to deploy is not an error for the rotation itself"
    assert_includes out, "배포 전용 폴더가 없어 배포하지 않았습니다"
    assert_includes out, "git clone"
    # The password was still rotated — the deploy decision is downstream of it.
    assert_match(/\A[A-Za-z0-9]{24,}\z/, admin_password_in(env_file))
  end

  private

  def workdir
    @workdir_base ||= begin
      base = Rails.root.join("tmp", "test", "admin_password_reset")
      FileUtils.mkdir_p(base)
      base.to_s
    end
    Dir.mktmpdir("run-", @workdir_base)
  end

  # A fake env file plus the path a pbcopy stand-in should write to.
  def fixture_env
    dir = workdir
    env_file = File.join(dir, "env")
    File.write(env_file, ORIGINAL_ENV)
    File.chmod(0o600, env_file)
    [ env_file, File.join(dir, "clip") ]
  end

  # `cat > "$CLIP_TARGET"` as a shell command, so the script's
  #   printf '%s' "$pw" | $PBCOPY
  # lands in a file we can compare instead of in the real clipboard.
  def pbcopy_stub(clip_path)
    stub = File.join(File.dirname(clip_path), "pbcopy-stub")
    File.write(stub, "#!/usr/bin/env bash\ncat > #{Shellwords.escape(clip_path)}\n")
    File.chmod(0o755, stub)
    stub
  end

  def run_reset(env_file, clip_path, answer: "n\n")
    env = {
      "ADMIN_PASSWORD_RESET_ENV_FILE" => env_file,
      "ADMIN_PASSWORD_RESET_PBCOPY" => pbcopy_stub(clip_path),
      # Absent on purpose: no test may be able to reach `kamal deploy`.
      "ADMIN_PASSWORD_RESET_DEPLOY_DIR" => File.join(File.dirname(clip_path), "no-deploy-dir")
    }
    Open3.capture3(env, "bash", SCRIPT, stdin_data: answer)
  end

  def run_reset!(env_file, clip_path, answer: "n\n")
    out, err, status = run_reset(env_file, clip_path, answer: answer)
    assert status.success?, "script failed (#{status.exitstatus}):\n#{out}\n#{err}"
    [ out, err ]
  end

  def other_lines(contents)
    contents.lines.reject { |line| line.start_with?("ADMIN_PASSWORD=") }.join
  end

  def admin_password_in(env_file)
    line = File.readlines(env_file).find { |l| l.start_with?("ADMIN_PASSWORD=") }
    line.to_s.chomp.sub("ADMIN_PASSWORD=", "")
  end
end
