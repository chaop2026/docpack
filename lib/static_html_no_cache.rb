# frozen_string_literal: true

# Rack middleware that downgrades the far-future Cache-Control on *static HTML*
# files to `no-cache`, so returning visitors always revalidate the HTML and a
# deploy reaches them immediately (a stale cached ETag/Last-Modified still gets
# a cheap 304, so unchanged pages cost no bandwidth).
#
# Why this exists: `config.public_file_server.headers` applies ONE header hash
# to every file under public/ (assets AND html). That is correct for digest-
# stamped assets (immutable, safe to cache for a year) but catastrophic for
# HTML entrypoints like /safe/ and /privacy/ — once a browser caches them with
# `max-age=1.year` it will not even ask the server again for up to a year.
#
# This middleware sits in front of ActionDispatch::Static and rewrites ONLY the
# responses that carry the static long-cache signature (`public, max-age=…`)
# AND are `text/html`. That precisely targets static HTML files and leaves:
#   - digest-stamped assets  → not text/html, untouched (keep long cache)
#   - dynamic Rails pages     → no `public, max-age` header, untouched
#   - sitemap.xml             → application/xml, untouched (keeps its own 3600)
class StaticHtmlNoCache
  # Serve stored copy but always revalidate first. Conditional GET via
  # Last-Modified/ETag still yields 304 when the file is unchanged.
  REVALIDATE = "no-cache"

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    rewrite!(headers, env["PATH_INFO"].to_s)
    [status, headers, body]
  end

  private

  # Paths that, like static HTML, must always revalidate so a deploy reaches
  # returning visitors immediately:
  #   - the service worker (/safe/sw.js): a 1-year-cached SW would pin an old
  #     app shell / caching logic on returning visitors — the very failure this
  #     middleware exists to prevent, one layer deeper.
  #   - PWA manifests (*.webmanifest): small, occasionally-edited metadata.
  # Digest-stamped assets and immutable icons keep their long cache.
  REVALIDATE_PATHS = /\/sw\.js\z|\.webmanifest\z/i

  def rewrite!(headers, path)
    content_type = lookup(headers, "content-type")
    is_html = content_type&.downcase&.include?("text/html")
    return unless is_html || path =~ REVALIDATE_PATHS

    cache_control = lookup(headers, "cache-control")
    return unless cache_control
    # only touch the far-future static header (public + a max-age), never the
    # `private/must-revalidate` that dynamic responses already carry.
    return unless cache_control =~ /\bpublic\b/i && cache_control =~ /max-age=\s*\d+/i

    assign(headers, "cache-control", REVALIDATE)
  end

  # Case-insensitive header access that works for both a plain Hash (Rack 2)
  # and Rack::Headers (Rack 3, already case-insensitive).
  def lookup(headers, name)
    return headers[name] if headers.key?(name)
    key = headers.keys.find { |k| k.to_s.casecmp?(name) }
    key && headers[key]
  end

  def assign(headers, name, value)
    key = headers.key?(name) ? name : (headers.keys.find { |k| k.to_s.casecmp?(name) } || name)
    headers[key] = value
  end
end
