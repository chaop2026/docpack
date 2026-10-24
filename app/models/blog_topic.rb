class BlogTopic < ApplicationRecord
  TRACKS = %w[ko jp].freeze

  validates :topic, presence: true
  # `privacy` added 2026-10-25: Post already allowed it (the SafeFile guide
  # posts use it) but BlogTopic did not, so a topic for one of them could not be
  # saved. The JP track uses it for every episode.
  validates :category, inclusion: { in: %w[privacy pdf image office student freelancer global] }
  validates :track, inclusion: { in: TRACKS }

  scope :unused, -> { where(used: false) }
  scope :jp, -> { where(track: "jp") }

  # ── Why the JP track does not use `used` ────────────────────────────────────
  #
  # `used` means "a post has been generated from this topic", which is the right
  # question for the Korean track: AutoGenerateBlogPostJob picks a random unused
  # topic, writes an article, and marks it used.
  #
  # For JP it is the wrong question and cross-review Q2 named the failure. JP
  # episodes are written on a Mac a month ahead and registered by
  # content:jp_import, so every imported episode would be "used" the moment it
  # existed — a `.next` scope keying on `used` would skip precisely the episodes
  # that are ready and only ever offer the ones nobody has written. The weekly
  # job is not asking "which topic is unwritten", it is asking "which episode
  # have I not yet sent for review".
  #
  # So selection keys on `review_sent_at`, and `used` is left alone on jp rows.
  #
  # The 9-day horizon: the job runs Saturday 00:00 KST for the following Monday,
  # so the episode it wants is 2 days out. Nine days of slack covers a run that
  # was skipped once (a deploy, a queue outage) without reaching forward into a
  # month it has no assets for. Ordered by publish_on then ep so a backlog comes
  # out in publication order rather than by id.
  scope :next_jp, -> {
    jp.where(review_sent_at: nil)
      .where("publish_on <= ?", 9.days.from_now)
      .order(:publish_on, :ep)
  }

  # The Korean job's selection, named so it cannot drift. Before S8 it was
  # `BlogTopic.unused` — which, once jp rows exist in the same table, would hand
  # a Japanese episode to the Korean generator and produce a Korean article
  # about 資格確認書. The track filter is the fix and a test pins it.
  scope :next_ko, -> { where(track: "ko").unused }

  def jp?
    track == "jp"
  end

  # Needs its facts re-confirmed before the package may be scheduled: ep30
  # cites a rule that is not in force yet, ep32 describes a feature that has not
  # shipped. `verified_at` is set by a human pressing a button in the admin
  # package page, never by a job.
  def awaiting_verification?
    verify_before? && verified_at.nil?
  end
end
