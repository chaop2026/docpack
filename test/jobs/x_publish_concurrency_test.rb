require "test_helper"

# Two workers, two real database connections, one timeline.
#
# ── Why this file is separate ───────────────────────────────────────────────
#
# Every other test in this suite runs inside a transaction that is rolled back
# at the end. That is fast and clean, and it makes this particular question
# unaskable: a second thread on a second connection cannot see rows the first
# thread has not committed, so a "concurrency" test under transactional
# fixtures is really two threads looking at two different databases.
#
# So `use_transactional_tests = false` here, and the cleanup is explicit.
#
# The thing being tested is the claim. XPublishJob writes
# `x.state='running' + worker_token + claimed_at` inside a short `with_lock`
# transaction and commits it BEFORE any API call. Two workers racing for the
# same post must therefore resolve to exactly one owner — and the measurable
# consequence is that the total number of tweets sent equals the number of
# tweets in the thread, not twice that.
class XPublishConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  # Shared by both threads, so "how many tweets were sent in total" is one
  # number rather than two that have to be added up on trust.
  class CountingClient
    attr_reader :posted

    def initialize
      @posted = []
      @mutex = Mutex.new
      @barrier = nil
    end

    def dry_run? = false
    def upload_media(path:, content_type:) = "media-1"

    def post_tweet(text:, media_id: nil, reply_to: nil)
      @mutex.synchronize do
        @posted << text
        # Slow enough that a second worker which got past the claim would
        # overlap with this one rather than politely queue behind it.
        sleep 0.02
        "id-#{@posted.length}"
      end
    end
  end

  setup do
    @post = Post.create!(
      content_track: "jp", content_ep: 88, primary_locale: "ja", status: "published",
      category: "privacy", slug: "jp-ep88-concurrency", title_ja: "並行テスト",
      body_ja: "<p>本文</p>", published_at: 1.hour.ago,
      package: {
        "ep" => 88, "track" => "jp",
        "x_thread" => %w[alpha bravo charlie delta],
        "x_reply_en" => "english reply",
        "x" => { "state" => "pending", "due_at" => 1.hour.ago.iso8601 }
      }
    )
    @post.update_column(:package, @post.package.merge("approved_version" => JpApproval.version_for(@post)))
    @post.reload
  end

  teardown do
    # No transaction to roll back — everything here is committed for real.
    Post.where(content_track: "jp", content_ep: 88).destroy_all
  end

  test "two workers on separate connections send each tweet exactly once" do
    client = CountingClient.new
    errors = []

    # Stubbed ONCE, around both threads. minitest's `stub` swaps a singleton
    # method and restores it in an ensure block; two threads doing that to the
    # same method race and leave XClient without a `new` at all (measured:
    # "undefined method `new' for class XClient"). The stub is global anyway,
    # so one wrapper covers both workers.
    XClient.stub(:new, client) do
      threads = 2.times.map do |i|
        Thread.new do
          # Each thread checks out its own connection from the pool, which is
          # the whole point: thread 2 must be able to SEE thread 1's committed
          # claim.
          ActiveRecord::Base.connection_pool.with_connection do
            XPublishJob.perform_now(@post.id)
          end
        rescue StandardError, Interrupt => e
          errors << "worker #{i}: #{e.class}: #{e.message}"
        end
      end
      threads.each(&:join)
    end

    @post.reload
    expected = 5 # 4 JA tweets + the English reply

    assert_empty errors, "neither worker should raise"
    assert_equal expected, client.posted.length,
                 "each tweet must be sent exactly once across BOTH workers — got #{client.posted.inspect}"
    assert_equal expected, client.posted.uniq.length, "no tweet text was sent twice"
    assert_equal "done", @post.package.dig("x", "state")

    ids = @post.package.dig("x", "tweets").map { |t| t["tweet_id"] }
    assert_equal expected, ids.compact.length
    assert_equal ids.compact.length, ids.compact.uniq.length, "no duplicate ids recorded"
  end

  # Holds the first worker INSIDE the send loop until the test lets it go, so
  # the "another worker is mid-send" window is a fact rather than a hope.
  #
  # The timing-based version of this test (sleep, then poll for a token) could
  # not work: the whole job finishes in about a tenth of a second and `finish!`
  # clears `worker_token`, so by the time anything looked, the window had both
  # opened and closed. Measured — the poll hit its 5-second deadline every time.
  class GatedClient
    attr_reader :posted

    def initialize
      @posted = []
      @started = Queue.new   # worker 1 → test: "I am inside the loop"
      @proceed = Queue.new   # test → worker 1: "you may finish"
      @gated = false
    end

    def dry_run? = false
    def upload_media(path:, content_type:) = "media-1"

    def post_tweet(text:, media_id: nil, reply_to: nil)
      @posted << text
      unless @gated
        @gated = true
        @started << :in_the_loop
        @proceed.pop # block here, claim committed and not yet cleared
      end
      "id-#{@posted.length}"
    end

    def wait_until_in_loop = @started.pop
    def release = (@proceed << :go)
  end

  test "the loser of the claim race writes nothing at all" do
    client = GatedClient.new
    loser_saw = nil

    XClient.stub(:new, client) do
      claimer = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection { XPublishJob.perform_now(@post.id) }
      end

      # Worker 1 is now holding mid-send with its claim committed.
      client.wait_until_in_loop

      second = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          before = Post.find(@post.id).package["x"].slice("worker_token", "state")
          XPublishJob.perform_now(@post.id)
          after = Post.find(@post.id).package["x"]["worker_token"]
          loser_saw = [ before["worker_token"], after ]
        end
      end
      second.join

      client.release
      claimer.join
    end
    @post.reload

    assert_equal 5, client.posted.length, "the second worker must not have added sends"

    # Non-vacuity: if the second worker never SAW a committed claim, this test
    # proved nothing about claim ownership — it just watched two threads run in
    # sequence. The gate above makes that deterministic, and this keeps it
    # honest if the gate is ever broken.
    assert loser_saw, "the second worker never ran"
    assert loser_saw.first.present?,
           "the second worker saw no committed claim — the race was not exercised"
    assert_equal loser_saw.first, loser_saw.last,
                 "the second worker must not have overwritten the owner's token"
    # And the owner went on to finish its thread after being released.
    assert_equal "done", @post.package.dig("x", "state")
  end
end
