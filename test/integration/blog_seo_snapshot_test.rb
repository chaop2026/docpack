require "test_helper"

# E-1 — the regression guard for the Korean blog's indexing signals.
#
# S8 adds a Japanese content track to `posts`: four `*_ja` columns, a
# `primary_locale`, a `/blog/:slug` → `/ja/blog/:slug` redirect, a new
# `indexable_locales` rule, and a rewritten publish invariant. Every one of those
# touches code that the 42 live Korean posts run through. The requirement for
# this round is that their indexing behaviour does not move **by one character**.
#
# The honest way to check that is to record what the signals are *before* the
# change and compare after, and to record them the way a crawler sees them —
# from the rendered HTML, not by re-deriving the canonical formula in the test.
# Re-deriving it would mean the test and the view could drift together and still
# agree, which is the shape of a vacuous assertion.
#
# So capture and comparison run THE SAME extraction code over THE SAME rows:
#
#   capture    BLOG_SEO_SNAPSHOT_WRITE=1 bin/rails test test/integration/blog_seo_snapshot_test.rb
#              (run on the pre-change tree; writes test/fixtures/blog_seo_snapshot.json)
#   compare    bin/rails test        (the default — a diff is a failure)
#
# Rows come from the posts fixtures rather than from the dev database on
# purpose. The fixtures already cover all four shapes that exist in production
# (ko-only published, bilingual published, draft, scheduled) and, unlike the dev
# database, they are identical on every machine and in CI — a snapshot taken
# against three rows of local scratch data would compare equal for the wrong
# reason.
class BlogSeoSnapshotTest < ActionDispatch::IntegrationTest
  SNAPSHOT = Rails.root.join("test", "fixtures", "blog_seo_snapshot.json")

  # Every URL spelling a Korean post is reachable at. `nil` = no prefix (the
  # Korean canonical). The others are the prefixes config/routes.rb accepts.
  LOCALE_PREFIXES = [ nil, "en", "ja", "es" ].freeze

  # Below this, the snapshot is not describing the thing it claims to describe.
  # Four shapes × four prefixes is the floor; the fixtures give five posts today.
  MIN_ENTRIES = 16

  def test_korean_blog_indexing_signals_are_unchanged
    captured = capture_signals

    if ENV["BLOG_SEO_SNAPSHOT_WRITE"] == "1"
      write_snapshot(captured)
      skip "snapshot written to #{SNAPSHOT.relative_path_from(Rails.root)} " \
           "(#{captured.size} entries) — re-run without BLOG_SEO_SNAPSHOT_WRITE to compare"
    end

    assert SNAPSHOT.exist?,
           "#{SNAPSHOT} is missing. It is the pre-change record of the Korean blog's " \
           "indexing signals; without it this test proves nothing. Regenerate it only " \
           "from a tree whose blog behaviour is known good."

    expected = JSON.parse(SNAPSHOT.read)

    # Vacuity guards. An empty or truncated snapshot would compare equal to an
    # empty capture and report success — the exact failure mode this repository
    # has already shipped once (canonical_sweep.rb passing with 0 entries).
    assert_operator expected.size, :>=, MIN_ENTRIES,
                    "snapshot has only #{expected.size} entries; it cannot be describing " \
                    "the blog's indexing signals"
    assert_equal expected.keys.sort, captured.keys.sort,
                 "the set of Korean blog URLs changed. A URL appearing or disappearing is " \
                 "itself a regression in this round's terms."

    diffs = expected.keys.sort.filter_map do |key|
      next if expected[key] == captured[key]

      "#{key}\n    before: #{expected[key].inspect}\n    after:  #{captured[key].inspect}"
    end

    assert_empty diffs,
                 "#{diffs.size} Korean blog URL(s) changed their indexing signals:\n  " \
                 "#{diffs.join("\n  ")}"
  end

  private

  # { "GET /en/blog/korean-only-post" => {status:, location:, canonical:, …} }
  def capture_signals
    Post.order(:slug).each_with_object({}) do |post, acc|
      LOCALE_PREFIXES.each do |prefix|
        path = prefix ? "/#{prefix}/blog/#{post.slug}" : "/blog/#{post.slug}"
        acc["GET #{path}"] = signals_for(path)
      end

      # Model-level signals too: the sitemap and the hreflang block read these
      # directly, so a change here moves signals the HTML above would not show.
      acc["MODEL #{post.slug}"] = {
        "indexable_locales" => post.indexable_locales.map(&:to_s),
        "indexable" => I18n.available_locales.to_h { |l| [ l.to_s, post.indexable?(l) ] },
        "translated" => I18n.available_locales.to_h { |l| [ l.to_s, post.translated?(l) ] }
      }
    end
  end

  def signals_for(path)
    # Each URL is measured from a cold session. Without this the `locale` cookie
    # that set_locale persists on a prefixed request carries into the next one,
    # and the capture becomes order-dependent: measured, the first run recorded
    # `/blog/bilingual-published-post` as `og:locale=es_ES` / `<html lang="es">`
    # purely because the preceding request in the loop was the /es one. A
    # snapshot that moves when minitest changes its seed compares unequal for a
    # reason that has nothing to do with the blog.
    reset!

    # No Accept-Language header on purpose: the signals must be a property of
    # the URL. (A matrix over Accept-Language is already covered by
    # test/integration/blog_indexing_test.rb; duplicating it here would make
    # this snapshot four times larger without adding a shape.)
    get path

    out = { "status" => response.status }

    if response.redirect?
      # Relative so the snapshot does not pin the test host.
      out["location"] = response.headers["Location"].to_s.sub(%r{\Ahttps?://[^/]+}, "")
      return out
    end

    out["canonical"]  = attr_of(%r{<link[^>]+rel="canonical"[^>]*>}, "href")
    out["robots"]     = attr_of(%r{<meta[^>]+name="robots"[^>]*>}, "content")
    out["og_locale"]  = attr_of(%r{<meta[^>]+property="og:locale"[^>]*>}, "content")
    out["og_url"]     = attr_of(%r{<meta[^>]+property="og:url"[^>]*>}, "content")
    out["html_lang"]  = attr_of(%r{<html[^>]*>}, "lang")
    out["hreflang"]   = response.body
                                .scan(%r{<link[^>]+rel="alternate"[^>]+hreflang="([^"]+)"[^>]+href="([^"]+)"[^>]*>})
                                .map { |lang, href| [ lang, href.sub(%r{\Ahttps?://[^/]+}, "") ] }
                                .sort
    out
  end

  def attr_of(tag_re, attr)
    tag = response.body[tag_re]
    return nil unless tag

    m = tag.match(/#{attr}="([^"]*)"/)
    m && m[1].sub(%r{\Ahttps?://[^/]+}, "")
  end

  def write_snapshot(captured)
    SNAPSHOT.write(JSON.pretty_generate(captured) + "\n")
  end
end
