class Post < ApplicationRecord
  has_one_attached :hero_image

  validates :title_ko, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :category, inclusion: { in: %w[privacy pdf image office student freelancer global] }
  validates :status, inclusion: { in: %w[draft scheduled published] }

  # The invariant: **a published post always has a Korean body.**
  #
  # Korean is the default locale, so /blog/:slug — the address every other
  # locale canonicalises to, the one x-default points at, and the only one the
  # language switcher can always reach — is the Korean page. A published post
  # with body_en but no body_ko makes that address real but not indexable:
  # indexable_locales comes back [:en], yet x-default still aims at the Korean
  # URL, which is noindex. Reproduced before writing this validation.
  #
  # Nothing builds that shape today (BlogGeneratorService writes Korean first,
  # and all 42 live posts have body_ko), so this closes a gap rather than fixing
  # a live defect. Drafts stay exempt: a post is created empty and filled in.
  validates :body_ko, presence: true, if: -> { status == "published" }

  scope :published, -> { where(status: "published") }
  scope :scheduled_ready, -> { where(status: "scheduled").where("published_at <= ?", Time.current) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }

  # ── Stuck posts ─────────────────────────────────────────────────────────
  #
  # A post whose time to be published has come and gone. This is the state that
  # makes a skipped publish visible, and it is DERIVED on purpose.
  #
  # PublishScheduledPostsJob skips a post it cannot publish so the rest of the
  # batch survives; the post then stays `scheduled`, possibly forever. The job
  # also emails about it — but this app's production SMTP has already failed
  # once (2026-04-07, 535-5.7.8), Solid Queue does not retry on its own
  # (ClaimedExecution#perform calls failed_with and re-raises), and nothing read
  # its failed-executions table. A lost alert is a premise here, not a risk.
  #
  # Computing the signal from `status` and `published_at` means it depends on
  # nothing but the row itself, and so it catches strictly more than a flag the
  # job would have had to write:
  #
  #   validation rejected the post   → flag ✓   derived ✓
  #   the job never ran at all       → flag ✗   derived ✓   (happened here:
  #                                                          SOLID_QUEUE_IN_PUMA
  #                                                          was false, 2026-04-07)
  #   the job died before this post  → flag ✗   derived ✓
  #
  # There are two ways to know a post is stuck, and they need different patience.
  #
  #   * A failure was RECORDED (publish_error present). The job tried and the
  #     record was rejected — that is evidence, not suspicion, so it counts the
  #     moment the post is past due. Waiting would mean sitting on a known
  #     answer.
  #   * NOTHING was recorded. Past due might just mean "waiting for the next
  #     run": the job fires once a day at 09:00 KST, so a post scheduled for
  #     09:30 honestly waits ~23.5 hours. Here a grace period is required, and
  #     26 hours clears that maximum honest wait with room to spare.
  #
  # This split came out of a test: with a single 26-hour rule, a post the job had
  # just rejected stayed invisible for a day, which is precisely the delay this
  # whole mechanism exists to remove.
  PUBLISH_GRACE = 26.hours

  scope :publish_stuck, ->(grace = PUBLISH_GRACE) {
    where(status: "scheduled")
      .where.not(published_at: nil)
      .where(
        "publish_error IS NOT NULL AND published_at <= :now OR published_at <= :cutoff",
        now: Time.current, cutoff: Time.current - grace
      )
  }

  def publish_stuck?(grace = PUBLISH_GRACE)
    return false unless status == "scheduled" && published_at.present?
    return published_at <= Time.current if publish_error.present?

    published_at <= Time.current - grace
  end

  # How overdue, for the admin list. nil when the post is not scheduled.
  def publish_overdue_by
    return nil unless status == "scheduled" && published_at.present?

    Time.current - published_at
  end

  before_validation :generate_slug, if: -> { slug.blank? && title_ko.present? }

  # ── Localized content ───────────────────────────────────────────────────
  #
  # `loc` is the locale of the URL being rendered, not the one I18n negotiated —
  # callers pass ApplicationHelper#url_locale. It is REQUIRED on purpose. These
  # three used to default to I18n.locale, and that default is the whole bug: an
  # unprefixed /blog/:slug served an English title and body to anyone sending
  # `Accept-Language: en` while still declaring the Korean canonical — one URL
  # with two contents, and an exact duplicate of /en/blog/:slug. A default would
  # let the next caller reintroduce it in silence; without one, forgetting is an
  # ArgumentError at the call site. Only a prefixed URL may serve localized
  # content.
  #
  # The fallback itself is unchanged: any non-Korean locale prefers the English
  # column and drops to Korean when it is empty (ja/es have no columns at all).
  def title(loc)
    loc.to_sym == :ko ? title_ko : (title_en.presence || title_ko)
  end

  def body(loc)
    loc.to_sym == :ko ? body_ko : (body_en.presence || body_ko)
  end

  def meta_description(loc)
    loc.to_sym == :ko ? meta_description_ko : (meta_description_en.presence || meta_description_ko)
  end

  # ── Indexing ────────────────────────────────────────────────────────────
  #
  # Blog posts only carry ko/en body columns. A locale counts as "translated"
  # only when that locale's body column is actually filled in — ja/es never are,
  # and en falls back to ko text (untranslated) unless body_en is present.
  def translated?(loc = I18n.locale)
    case loc.to_sym
    when :ko then body_ko.present?
    when :en then body_en.present?
    else false
    end
  end

  # The single rule behind every indexing signal this post emits.
  #
  #   status      | robots        | why
  #   ------------|---------------|--------------------------------------------
  #   published   | (none)        | live, and the body exists in this locale
  #   published   | noindex,follow| body not translated into this locale, so the
  #               |               | URL would put Korean text on an /en|ja|es
  #               |               | address
  #   scheduled   | noindex,follow| not live yet — PostsController#show serves it
  #   draft       | noindex,follow| 200 for preview, but it must never be indexed
  #
  # Preview keeps its 200; only the indexing directive changes.
  def indexable?(loc = I18n.locale)
    status == "published" && translated?(loc)
  end

  # Locales this post may actually be indexed under — drives sitemap + hreflang.
  # Empty for anything unpublished, which is a real answer and stays empty:
  # an unpublished post advertises no alternates at all.
  def indexable_locales
    [ :ko, :en ].select { |l| indexable?(l) }
  end

  def publish!
    update!(status: "published", published_at: Time.current) if published_at.blank?
    update!(status: "published")
  end

  private

  def generate_slug
    base = title_ko.to_s.parameterize
    base = SecureRandom.hex(6) if base.blank?
    self.slug = base
    counter = 1
    while Post.where(slug: slug).where.not(id: id).exists?
      self.slug = "#{base}-#{counter}"
      counter += 1
    end
  end
end
