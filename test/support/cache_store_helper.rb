# Runs a block with a real cache store in place of the test default.
#
# config/environments/test.rb sets `:null_store`, which is the right default —
# it stops one test's memoised state leaking into the next. But it also means
# every rate limit in this app (Api::SafeScanController, Api::JpPilotController,
# Api::SafeEventsController) is a no-op under test: the counter writes to a
# store that forgets, so the read always returns nil and the limit is never
# reached. A test asserting "the cap works" against the null store passes no
# matter what the cap does — the emptiest kind of green.
#
# Production uses :solid_cache_store (DB-backed, shared across Puma workers), so
# a memory store is the closer analogue of "a store that remembers" for the one
# property under test.
module CacheStoreHelper
  def with_memory_cache
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = previous
  end
end
