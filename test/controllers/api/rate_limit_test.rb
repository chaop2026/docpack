require "test_helper"
require_relative "../../support/cache_store_helper"

# Both /api/ ceilings used to count with `read → +1 → write`. Two requests that
# read the same 2 both write 3 and both are allowed, so the cap was a cap only
# for traffic that arrived in single file. Solid Cache being shared across Puma
# workers does not help: a shared store is precisely what lets both readers see
# the same stale value.
#
# The old sequential tests could not see this — they still pass against the
# broken code. So this file drives the counter concurrently, and it keeps a
# re-implementation of the OLD pattern next to the new one so the harness has to
# demonstrate that it can tell them apart. A concurrency test that passes for
# both is not a test.
class Api::RateLimitTest < ActiveSupport::TestCase
  include CacheStoreHelper

  THREADS = 20
  LIMIT   = 3
  WINDOW  = 10.minutes

  # over_limit? reads only Time.current and Rails.cache, so it needs no request.
  def counter
    @counter ||= Api::BaseController.new
  end

  def allow_count(key, &increment)
    allowed = 0
    mutex   = Mutex.new
    gate    = Concurrent::CountDownLatch.new(1) if defined?(Concurrent::CountDownLatch)

    threads = THREADS.times.map do
      Thread.new do
        gate&.wait(5)
        over = increment.call(key)
        mutex.synchronize { allowed += 1 unless over }
      end
    end
    gate&.count_down
    threads.each(&:join)
    allowed
  end

  test "the atomic counter admits at most the limit under concurrent calls" do
    with_memory_cache do
      allowed = allow_count("probe:atomic") do |key|
        counter.send(:over_limit?, key, limit: LIMIT, window: WINDOW)
      end

      assert_equal LIMIT, allowed,
                   "#{allowed} of #{THREADS} concurrent calls were admitted; the cap is #{LIMIT}"
    end
  end

  # The mutation probe. Without it, the test above proves nothing about
  # concurrency: a sequential counter would satisfy it too if the threads
  # happened not to interleave. This re-creates the exact shape the two
  # controllers had before this round and asserts the harness CATCHES it.
  test "the old read-then-write counter over-admits, which is why this harness exists" do
    with_memory_cache do
      allowed = allow_count("probe:racy") do |key|
        bucket   = Time.current.to_i / WINDOW.to_i
        full_key = "#{key}:#{bucket}"
        count    = Rails.cache.read(full_key).to_i + 1
        # A deliberate yield between the read and the write. The race exists
        # without it, but it is timing-dependent; a test for a race must not be
        # the thing that decides whether the race happens.
        Thread.pass
        Rails.cache.write(full_key, count, expires_in: WINDOW * 2)
        count > LIMIT
      end

      assert_operator allowed, :>, LIMIT,
                      "the racy counter admitted only #{allowed} — this harness cannot distinguish " \
                      "the two implementations, so the test above is empty"
    end
  end

  # Store-level facts the cap depends on. Asserted rather than read off the gem
  # source, because the comment in Api::BaseController cites that source as the
  # reason no write-then-increment dance is needed.
  test "increment creates a missing key rather than returning nil" do
    with_memory_cache do
      assert_equal 1, Rails.cache.increment("probe:fresh", 1, expires_in: 1.minute)
      assert_equal 2, Rails.cache.increment("probe:fresh", 1, expires_in: 1.minute)
    end
  end

  test "increment keeps the original expiry instead of sliding it" do
    with_memory_cache do
      Rails.cache.increment("probe:ttl", 1, expires_in: 1.second)
      Rails.cache.increment("probe:ttl", 1, expires_in: 1.hour)

      # The second call asked for an hour; the entry must still die in a second,
      # because a window key that keeps being renewed never rolls over.
      travel 2.seconds do
        assert_nil Rails.cache.read("probe:ttl")
      end
    end
  end

  # The test default is :null_store, where increment returns nil. Every "the cap
  # does not fire without a cache that remembers" test depends on that staying
  # true; if increment ever started counting in the null store those reverse
  # guards would silently become assertions about nothing.
  test "the null store still refuses to count, so the reverse guards keep working" do
    assert_nil Rails.cache.increment("probe:null", 1, expires_in: 1.minute)
    assert_not counter.send(:over_limit?, "probe:null", limit: 0, window: WINDOW),
               "a limit of 0 fired under the null store — the reverse-guard tests are now empty"
  end

  # Ties the unit above to the endpoints: both controllers must actually use the
  # bucketed key this file exercises. Without this, over_limit? could be dead
  # code and every assertion here would still be green.
  test "the endpoints write the bucketed key that over_limit? owns" do
    with_memory_cache do
      bucket = Time.current.to_i / Api::JpPilotController::RATE_WINDOW.to_i
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.post "/api/jp_pilot",
                   params: { company: "x", industry: "other", monthly_count: "1-2", email: "key@example.co.jp" }.to_json,
                   headers: { "CONTENT_TYPE" => "application/json" }

      assert_equal 201, session.response.status
      assert_equal 1, Rails.cache.read("jp_pilot:127.0.0.1:#{bucket}"),
                   "jp_pilot did not count into the key shape over_limit? builds"
    end
  ensure
    JpPilotRequest.delete_all
  end
end
