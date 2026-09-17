# Why this column carries the reason and not the state.
#
# PublishScheduledPostsJob skips a post it cannot publish, so the post stays
# `scheduled` — possibly forever. The failure that hid before was that the only
# thing telling anyone was an email, and this app's production SMTP has already
# failed once (2026-04-07, 535-5.7.8).
#
# The authoritative signal is therefore DERIVED, not stored: Post.publish_stuck
# computes it from `status` and `published_at`, which are already there. That
# depends on nothing except the post row, so it also catches the job never
# running at all — which is the failure that actually happened here in April.
#
# This column only ever carries the *reason*, written best-effort with
# update_column (deliberately bypassing validation: the record being invalid is
# precisely why we are writing) and cleared on a successful publish. A post with
# no reason recorded still shows up as stuck.
class AddPublishErrorToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :publish_error, :text
  end
end
