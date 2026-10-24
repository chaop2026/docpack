class Post < ApplicationRecord
  has_one_attached :hero_image
  # The JP weekly package's media: carousel PNGs and the demo GIF/MP4. Many,
  # because the admin preview shows all three carousel slides and XPublishJob
  # picks one file to attach to the first tweet.
  has_many_attached :package_assets

  # Which locale this post was WRITTEN in. Every indexing signal derives from
  # this rather than from which body column happens to be filled: inferring it
  # would make the canonical URL flip the moment a post has two bodies, and the
  # flip would depend on the order someone typed them. NOT NULL, CHECKed to
  # ('ko','ja') in the database, and asserted to be 'ko' for every pre-S8 row.
  PRIMARY_LOCALES = %w[ko ja].freeze
  validates :primary_locale, inclusion: { in: PRIMARY_LOCALES }

  # Conditioned on the primary locale (cross-review Q1). A Japanese post has no
  # Korean title, so an unconditional presence check on title_ko would make the
  # JP track unable to save at all. Korean posts are unaffected: for them the
  # condition is true and the rule is exactly what it was.
  validates :title_ko, presence: true, if: -> { primary_locale == "ko" }
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
  #
  # S8 GENERALISED the invariant rather than loosening it: the rule is now "a
  # published post has a title and a body in ITS OWN primary locale". For a
  # Korean post that is the identical condition on body_ko (plus the title,
  # which was already required unconditionally), so the 42 live posts see no
  # change — E-1 holds it to that. For a Japanese post the Korean columns are
  # empty by design and body_ja is the one that must be there.
  validate :primary_title_and_body_present, if: -> { status == "published" }

  scope :published, -> { where(status: "published") }
  scope :jp, -> { where(primary_locale: "ja") }
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
        # Parenthesised deliberately. SQL binds AND tighter than OR, so the bare
        # form would parse the way this reads anyway (confirmed against Postgres:
        # `true AND false OR true` = `(true AND false) OR true`) — but the reader
        # has to know that to trust the line, and a later edit could reorder the
        # branches and silently change the meaning.
        "(publish_error IS NOT NULL AND published_at <= :now) OR published_at <= :cutoff",
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

  # NEVER for a Japanese post. generate_slug derives from title_ko, which a JP
  # post does not have, and the JP slug is assigned exactly once by
  # content:jp_import (`jp-epNN-<kebab title_en>`) so the published URL is a
  # function of the episode number rather than of the title someone last edited.
  # Cross-review Q2 asked for both halves: import names it, and nothing renames
  # it afterwards (see the slug-immutability validation below).
  before_validation :generate_slug,
                    if: -> { slug.blank? && title_ko.present? && primary_locale != "ja" }

  # A published Japanese URL is an address other people have linked. Changing
  # the slug would strand it, and this app has already paid for that twice (the
  # two OLD_BLOG_SLUGS redirects in config/routes.rb exist because of a rename).
  # So for the JP track the slug is write-once: set at import, immutable after.
  validate :jp_slug_is_immutable, if: -> { primary_locale == "ja" && slug_changed? && persisted? }

  # A recorded publish failure describes the record as it was when the job tried.
  # The moment a person edits the post, that description may be a lie — measured:
  # fix a blank body_ko in the admin and the reason still read "본문(한국어)을(를)
  # 입력해 주세요" until the next daily run, with the admin banner repeating it.
  #
  # So any ordinary save clears it. The post stays listed by Post.publish_stuck
  # (it is still past due and still scheduled) — it just falls back to the grace
  # window, which is the honest state: the old evidence is gone and we are
  # waiting for the next run again.
  #
  # PublishScheduledPostsJob writes and clears publish_error with update_column,
  # which skips callbacks, so this never fights the job over the same field.
  before_save :clear_stale_publish_error, if: -> { publish_error.present? && changed? }

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
  #
  # S8: the fallback CHAIN depends on which locale the post was written in, and
  # the Korean chain is left exactly as it was. For a Japanese post the English
  # column falls back to Japanese, never to Korean — there is no Korean text to
  # fall back to, and 'ko' asking a JP post for its title must answer in
  # Japanese rather than nil (the admin list and the sitemap both call it).
  def title(loc)
    localized(loc, title_ko, title_en, title_ja)
  end

  def body(loc)
    localized(loc, body_ko, body_en, body_ja)
  end

  def meta_description(loc)
    localized(loc, meta_description_ko, meta_description_en, meta_description_ja)
  end

  def subtitle(loc)
    localized(loc, subtitle_ko, nil, subtitle_ja)
  end

  # ── Indexing ────────────────────────────────────────────────────────────
  #
  # Blog posts only carry ko/en body columns. A locale counts as "translated"
  # only when that locale's body column is actually filled in — ja/es never are,
  # and en falls back to ko text (untranslated) unless body_en is present.
  # S8 adds `ja` to the set of columns that can be filled, but ONLY for a post
  # whose primary locale is Japanese. A Korean post with a Japanese body is not
  # a shape anything produces, and treating it as translated would hand
  # /ja/blog/:slug to a Korean post and move signals E-1 pins down. The Korean
  # branch of this method is untouched.
  def translated?(loc = I18n.locale)
    case loc.to_sym
    when :ko then primary_locale == "ko" && body_ko.present?
    when :en then body_en.present?
    when :ja then primary_locale == "ja" && body_ja.present?
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
  # S8: the candidate set follows primary_locale. The GATE is unchanged — still
  # `published AND this locale's body exists` (cross-review Q1 was explicit that
  # replacing it with "body exists" alone would contradict the rule that nothing
  # unpublished is indexable). For a Korean post the candidates are [:ko, :en],
  # exactly as before, so the result and its ORDER are identical; E-1 asserts it
  # byte for byte.
  INDEXABLE_CANDIDATES = { "ko" => [ :ko, :en ], "ja" => [ :ja, :en ] }.freeze

  def indexable_locales
    INDEXABLE_CANDIDATES.fetch(primary_locale, [ :ko, :en ]).select { |l| indexable?(l) }
  end

  # The locale a reader of this post's canonical URL gets. /ja/blog/:slug for a
  # Japanese post, /blog/:slug for a Korean one. This is what x-default points at
  # and what every other locale canonicalises to.
  def primary_locale_sym
    primary_locale.to_sym
  end

  # The canonical path for this post as seen from `loc`.
  #
  #   translated into loc → that locale's own URL (self-canonical)
  #   not translated      → the primary-locale URL
  #
  # For a Korean post this reproduces the pre-S8 expression exactly
  # (`@post_translated ? locale_prefixed(…, url_locale) : "/blog/#{slug}"`),
  # because its primary locale IS the unprefixed one. E-1 pins that.
  def canonical_path_for(loc)
    target = translated?(loc) ? loc.to_sym : primary_locale_sym
    base = "/blog/#{slug}"
    target == I18n.default_locale ? base : "/#{target}#{base}"
  end

  # ── The weekly JP package ───────────────────────────────────────────────────
  #
  # `package` is jsonb and holds everything the week's publication needs that is
  # not blog prose: the X thread, the LinkedIn text, the FAQ, the asset list,
  # the guard result, the approval, and the X delivery state. Readers go through
  # these accessors so a typo in a key name is one place rather than nine.

  # [{ "q" => …, "a" => … }, …] — [] when there is no FAQ, which is a real
  # answer. Callers must not emit a FAQPage for an empty list.
  def package_faq
    faq = package["faq"]
    faq.is_a?(Array) ? faq.select { |e| e.is_a?(Hash) && e["q"].present? && e["a"].present? } : []
  end

  def package_x_thread
    thread = package["x_thread"]
    thread.is_a?(Array) ? thread : []
  end

  def guard_violations
    v = package.dig("guard", "violations")
    v.is_a?(Array) ? v : []
  end

  def approved?
    package["approved_at"].present?
  end

  def import_conflict
    package["import_conflict"]
  end

  # Whether the 「承認」 button may be pressed at all. Three independent blocks,
  # each of which means "a human has not finished something":
  #   * the content guard found a violation (strategy rules, unsourced legal
  #     claim, over-length tweet…)
  #   * an import was refused because this package is already approved — the
  #     files on disk and the row no longer agree
  #   * the topic needs its facts re-confirmed (ep30, ep32)
  def approvable?(topic = nil)
    guard_violations.empty? &&
      import_conflict.blank? &&
      !(topic&.awaiting_verification?)
  end

  # ── The X thread's delivery state ───────────────────────────────────────────
  #
  # Lives in `package.x` rather than in its own column because it is a record of
  # one package's publication, and it has to survive a re-import of the blog
  # text (XPublishJob's tweet IDs are the only proof of what was already posted —
  # losing them would mean posting the thread twice). See JpPackage.
  X_UNFINISHED = %w[pending running partial_failed unknown blocked].freeze

  # A JP post whose X thread was due and did not finish. Derived from the row,
  # for the same reason publish_stuck is: the channel that reports a failure must
  # not be the channel that failed.
  scope :x_stuck, ->(grace = 2.hours) {
    jp.where("package -> 'x' ->> 'state' IN (?)", X_UNFINISHED)
      .where("(package -> 'x' ->> 'due_at')::timestamptz < ?", Time.current - grace)
  }

  # A JP package the weekly job offered for review and nobody ever approved.
  #
  # AutoGenerateJpPostJob's queue advances — if ep05 is never approved, the next
  # Saturday offers ep06, because one un-acted-on episode must not block the
  # schedule behind it. The cost of that choice is that the skipped episode has
  # no further mail coming, so it is surfaced as STATE instead: still a draft,
  # with a publish time that has come and gone.
  #
  # publish_stuck cannot catch these — it only looks at `scheduled` posts, and
  # an unapproved package never leaves `draft`.
  scope :jp_unapproved_overdue, ->(grace = PUBLISH_GRACE) {
    jp.where(status: "draft")
      .where.not(published_at: nil)
      .where("published_at <= ?", Time.current - grace)
  }

  def x_state
    package.dig("x", "state")
  end

  def x_stuck?(grace = 2.hours, now: Time.current)
    return false unless primary_locale == "ja" && X_UNFINISHED.include?(x_state)

    due = package.dig("x", "due_at")
    due.present? && Time.zone.parse(due.to_s) < now - grace
  end

  def publish!
    update!(status: "published", published_at: Time.current) if published_at.blank?
    update!(status: "published")
  end

  private

  # The published-post invariant, keyed on primary_locale.
  #
  # `errors.add(…, :blank)` rather than a literal message on purpose: it resolves
  # through config/locales/ko.yml the same way the old
  # `validates :body_ko, presence: true` did, so the string the admin form shows
  # and the string PublishScheduledPostsJob puts in its failure email are
  # byte-identical to before ("본문(한국어)을(를) 입력해 주세요"). A hand-written
  # message here would have changed an alert that a person reads.
  # The fallback chain, per primary locale. Korean posts keep their exact
  # pre-S8 behaviour: :ko → the Korean column, anything else → English or
  # Korean. Japanese posts mirror it with Japanese as the floor; there is no
  # Korean text on them, so falling back to it would return nil.
  def localized(loc, ko_value, en_value, ja_value)
    if primary_locale == "ja"
      loc.to_sym == :en ? (en_value.presence || ja_value) : ja_value
    else
      loc.to_sym == :ko ? ko_value : (en_value.presence || ko_value)
    end
  end

  def jp_slug_is_immutable
    was, now = slug_was, slug
    errors.add(:slug, "は公開URLの一部なので変更できません (#{was} → #{now})")
  end

  def primary_title_and_body_present
    title_attr = :"title_#{primary_locale}"
    body_attr  = :"body_#{primary_locale}"

    errors.add(title_attr, :blank) if self[title_attr].blank?
    errors.add(body_attr, :blank)  if self[body_attr].blank?
  end

  # See the before_save above. Only ever clears — the job owns writing it, via
  # update_column so this callback does not run for the job's own writes.
  def clear_stale_publish_error
    self.publish_error = nil
  end

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
