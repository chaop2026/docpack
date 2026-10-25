class AddJpContentTrack < ActiveRecord::Migration[8.0]
  # S8 — the Japanese content track.
  #
  # Two tables grow: `posts` gets a Japanese body and a declaration of which
  # locale is its ORIGINAL, and `blog_topics` gets the fields the weekly JP job
  # selects on. Nothing existing changes shape.
  #
  # ── Why primary_locale and not "has a ja body" ─────────────────────────────
  #
  # Every indexing signal this app emits is derived, and the thing it has to be
  # derived from is "which locale is this post written in". Inferring that from
  # which body column happens to be filled works right up until a post has two,
  # and then the canonical flips depending on the order someone typed. So it is
  # declared, NOT NULL, defaulted to 'ko', and CHECK-constrained to the two
  # values that exist. The 42 live Korean posts must come out of this migration
  # as `ko` — asserted below rather than assumed, because a default only applies
  # to rows the default was in place for and this column is being added to rows
  # that already exist.
  def up
    # Bounded waiting, on a table that production serves every blog request
    # from (cross-review Q4).
    #
    # lock_timeout     — ADD COLUMN needs ACCESS EXCLUSIVE. Without a bound it
    #                    queues behind any open transaction on `posts`, and
    #                    because it queues, every SELECT arriving after it
    #                    queues behind IT. One slow reader turns a
    #                    sub-second migration into a site-wide stall. 5s means
    #                    the deploy fails and is retried instead.
    # statement_timeout— a cap on the statements themselves. Everything here is
    #                    metadata-only on Postgres 11+ (the defaults are not
    #                    backfilled into existing rows), so 30s is enormous
    #                    slack; it exists to turn "wedged" into "failed".
    #
    # SET LOCAL, so both revert at the end of this migration's transaction and
    # nothing leaks into the session that runs the next one.
    execute "SET LOCAL lock_timeout = '5s'"
    execute "SET LOCAL statement_timeout = '30s'"

    add_column :posts, :title_ja,            :string
    add_column :posts, :subtitle_ja,         :string
    add_column :posts, :body_ja,             :text
    add_column :posts, :meta_description_ja, :string

    # default + null: false in one step. Postgres backfills existing rows with
    # the default, which is exactly what we want here and is verified after.
    add_column :posts, :primary_locale, :string, default: "ko", null: false
    add_column :posts, :content_track,  :string
    add_column :posts, :content_ep,     :integer
    add_column :posts, :package,        :jsonb, default: {}, null: false

    # The assertion, inside the migration. If a row escaped the backfill — a
    # concurrent insert, a column that already existed with a different default
    # — this fails the deploy instead of shipping a post whose canonical URL
    # depends on a NULL.
    say_with_time "asserting every existing post is primary_locale='ko'" do
      bad = select_value("SELECT COUNT(*) FROM posts WHERE primary_locale IS DISTINCT FROM 'ko'").to_i
      raise ActiveRecord::IrreversibleMigration,
            "#{bad} existing post(s) are not primary_locale='ko' after backfill. " \
            "Every post that existed before S8 is Korean; refusing to continue." if bad.positive?

      select_value("SELECT COUNT(*) FROM posts").to_i
    end

    add_check_constraint :posts,
                         "primary_locale IN ('ko','ja')",
                         name: "posts_primary_locale_check"

    # (track, ep) identity, enforced by the DATABASE and not by the importer.
    #
    # Cross-review Q2: "the approved package is published once" cannot be
    # promised while two processes can both create ep07 — the monthly import on
    # the Mac and the weekly fallback generator on the server reach for the same
    # episode by the same name. A partial index keeps every Korean post (whose
    # content_track is NULL) out of the constraint entirely, so uniqueness
    # applies only where the identity exists.
    add_index :posts, [ :content_track, :content_ep ],
              unique: true,
              where: "content_track IS NOT NULL",
              name: "index_posts_on_content_track_and_ep"

    add_column :blog_topics, :track,          :string,  default: "ko", null: false
    add_column :blog_topics, :ep,             :integer
    add_column :blog_topics, :title_en,       :string
    add_column :blog_topics, :doc,            :string
    add_column :blog_topics, :purpose,        :string
    add_column :blog_topics, :landing,        :string
    add_column :blog_topics, :publish_on,     :date
    add_column :blog_topics, :verify_before,  :boolean, default: false, null: false
    add_column :blog_topics, :verified_at,    :datetime
    add_column :blog_topics, :social_skip,    :boolean, default: false, null: false
    # Not `used`. The JP track selects the next episode to review by
    # review_sent_at, deliberately NOT by `used` — see BlogTopic.next_jp. An
    # episode imported from the Mac would be "used" the moment it existed, and a
    # scope keying on that would skip it forever.
    add_column :blog_topics, :review_sent_at, :datetime

    say_with_time "asserting every existing blog topic is track='ko'" do
      bad = select_value("SELECT COUNT(*) FROM blog_topics WHERE track IS DISTINCT FROM 'ko'").to_i
      raise ActiveRecord::IrreversibleMigration,
            "#{bad} existing blog_topic(s) are not track='ko' after backfill." if bad.positive?

      select_value("SELECT COUNT(*) FROM blog_topics").to_i
    end

    add_check_constraint :blog_topics,
                         "track IN ('ko','jp')",
                         name: "blog_topics_track_check"

    add_index :blog_topics, [ :track, :ep ],
              unique: true,
              where: "ep IS NOT NULL",
              name: "index_blog_topics_on_track_and_ep"
  end

  # ⚠️ `down` DROPS the Japanese columns, and with them every Japanese post's
  # body, title and package — including `package.x.tweets`, which is the only
  # record of which tweets are already live on the timeline.
  #
  # So rolling back is only non-destructive BEFORE any JP row exists:
  #
  #   no jp rows yet   → safe. Verified by a rollback/migrate round trip on the
  #                      development database (see docs/jp/s8b_report.md).
  #   jp rows exist    → DATA LOSS. Take a `pg_dump` first, and expect to lose
  #                      the knowledge of what has been posted even with it —
  #                      restoring a dump does not un-post a tweet.
  #
  # `SELECT count(*) FROM posts WHERE content_track = 'jp'` is the check.
  def down
    remove_index :blog_topics, name: "index_blog_topics_on_track_and_ep"
    remove_check_constraint :blog_topics, name: "blog_topics_track_check"
    %i[track ep title_en doc purpose landing publish_on verify_before verified_at social_skip review_sent_at]
      .each { |c| remove_column :blog_topics, c }

    remove_index :posts, name: "index_posts_on_content_track_and_ep"
    remove_check_constraint :posts, name: "posts_primary_locale_check"
    %i[title_ja subtitle_ja body_ja meta_description_ja primary_locale content_track content_ep package]
      .each { |c| remove_column :posts, c }
  end
end
