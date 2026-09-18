# frozen_string_literal: true

# Canonical-URL regression sweep against a running app.
#
#   ruby script/canonical_sweep.rb [base_url]      # default http://localhost:3001
#
# Every round of SEO work in this repo re-measures the same six things, and until
# now the scripts that did it were ad hoc and thrown away. They are here so the
# next gem bump (or the next router change) can re-run them instead of
# rebuilding them from the CLAUDE.md prose.
#
# Checks, in order:
#   1. Duplicate 200s      — trailing and repeated slashes must not serve content
#   2. Redirect hops       — every 301 chain resolves in <= 2 hops, no loops
#   3. Sitemap             — every <loc> is 200, self-referencing canonical, no noindex
#   4. Internal links      — every href on every sitemap page resolves without a redirect
#   5. Signal consistency  — canonical == JSON-LD url == JSON-LD @id; hreflang sane
#   6. Accept-Language     — canonical and robots are identical for every language
#
# Exits non-zero if any check fails, so it can be dropped into CI unchanged.

require "net/http"
require "uri"
require "set"

BASE = ARGV[0] || "http://localhost:3001"
BASE_URI = URI.parse(BASE)

$failures = []
def fail!(check, detail)
  $failures << "#{check}: #{detail}"
  puts "  FAIL  #{detail}"
end

# URI.join is wrong here: it reads a leading "//" as protocol-relative, so
# "//about" — one of the exact spellings under test — resolves to host "about".
# Paths get concatenated onto the base instead.
def absolutize(path)
  return URI.parse(path) if path.start_with?("http://", "https://")

  URI.parse("#{BASE.chomp('/')}#{path}")
end

# `follow: false` is the point of most of these checks — we need to see the 301
# itself, not the page it lands on.
def get(path, follow: false, headers: {})
  uri = absolutize(path)
  req = Net::HTTP::Get.new(uri)
  headers.each { |k, v| req[k] = v }
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |h| h.request(req) }
  return res unless follow && res.is_a?(Net::HTTPRedirection)

  get(res["location"], follow: true, headers: headers)
end

def hops(path, limit: 6)
  seen = [ path ]
  n = 0
  cur = path
  loop do
    res = get(cur)
    return [ n, res.code, seen ] unless res.is_a?(Net::HTTPRedirection)

    n += 1
    cur = absolutize(res["location"]).request_uri
    return [ :loop, res.code, seen ] if seen.include?(cur)

    seen << cur
    return [ :overflow, res.code, seen ] if n > limit
  end
end

def meta(body, name)
  body[/<meta\s+name=["']#{name}["']\s+content=["']([^"']*)["']/i, 1] ||
    body[/<meta\s+content=["']([^"']*)["']\s+name=["']#{name}["']/i, 1]
end

def canonical(body) = body[/<link\s+rel=["']canonical["']\s+href=["']([^"']*)["']/i, 1]
def hreflangs(body) = body.scan(/<link\s+rel=["']alternate["']\s+hreflang=["']([^"']*)["']\s+href=["']([^"']*)["']/i)
def jsonld_blocks(body) = body.scan(%r{<script type="application/ld\+json">(.*?)</script>}m).flatten

# ── paths under test ────────────────────────────────────────────────────────
SLUGS = begin
  sm = get("/sitemap.xml", follow: true).body
  sm.scan(%r{<loc>([^<]+)</loc>}).flatten.map { |u| URI.parse(u).path }
end

STATIC_DIRS = %w[/safe /privacy]
ROUTED = %w[/ /about /faq /compress /pdf /social /blog /sitemap.xml /robots.txt
            /en/about /en/faq /en/blog /ja/blog /es/blog]

puts "base: #{BASE}"
puts "sitemap entries: #{SLUGS.size}"

# ── 1 + 2. spelling variants: no duplicate 200s, <= 2 hops, no loops ────────
puts "\n[1/6] spelling variants — duplicate 200s and hop counts"
variants = []
STATIC_DIRS.each do |d|
  variants += [ "#{d}/", d, "#{d}//", "#{d}///", "#{d}/index.html", "#{d}//index.html", "#{d}/index.html/" ]
end
variants += %w[/safe/sw.js /safe/sw.js/ /safe//sw.js]
ROUTED.each do |p|
  variants << p
  next if p == "/"

  variants += [ "#{p}/", "#{p}//", "/#{p}", p.sub(%r{\A/(\w+)/}, '/\1//') ].uniq
end
SLUGS.select { |s| s.start_with?("/blog/") }.each do |s|
  variants += [ s, "#{s}/", s.sub("/blog/", "/blog//") ]
end
# Renamed slugs: the middleware fixes the SPELLING and the router resolves the
# MOVE, so these are the repo's one accepted 2-hop case (DECISIONS.md 2026-09-18).
variants += %w[/blog/rrn-masking /blog/rrn-masking/ /blog/contract-checklist /blog/contract-checklist/]
variants = variants.uniq

dupes = []
hop_hist = Hash.new(0)
variants.each do |v|
  res = get(v)
  if res.is_a?(Net::HTTPRedirection)
    n, code, chain = hops(v)
    if n == :loop
      fail!("hops", "redirect loop starting at #{v}: #{chain.inspect}")
    elsif n == :overflow
      fail!("hops", "redirect chain over 6 hops at #{v}")
    else
      hop_hist[n] += 1
      fail!("hops", "#{v} takes #{n} hops (#{chain.inspect})") if n > 2
      # A 301 must land somewhere real.
      fail!("hops", "#{v} -> #{chain.last} ends in #{code}") unless code.start_with?("2")
    end
  elsif res.code == "200"
    dupes << v
  end
end
# The canonical spellings themselves are legitimately 200.
allowed_200 = (STATIC_DIRS.map { |d| "#{d}/" } + ROUTED + SLUGS + %w[/safe/sw.js]).uniq
(dupes - allowed_200).each { |v| fail!("duplicate-200", "#{v} serves content at a non-canonical spelling") }
puts "  variants probed: #{variants.size} | 200s: #{dupes.size} (allowed #{(dupes & allowed_200).size})" \
     " | hop histogram: #{hop_hist.sort.to_h.inspect}"

# ── 3. sitemap ───────────────────────────────────────────────────────────────
puts "\n[3/6] sitemap — 200, self-referencing canonical, no noindex, no redirect"
SLUGS.each do |path|
  res = get(path)
  next fail!("sitemap", "#{path} -> #{res.code} (sitemap must list final URLs only)") unless res.code == "200"

  body = res.body
  c = canonical(body)
  fail!("sitemap", "#{path} canonical is #{c.inspect}") unless c && URI.parse(c).path == path
  r = meta(body, "robots")
  fail!("sitemap", "#{path} carries robots=#{r.inspect}") if r&.include?("noindex")
end
puts "  #{SLUGS.size} entries checked"

# ── 4. internal links ────────────────────────────────────────────────────────
puts "\n[4/6] internal links — resolve without redirect"
links = Set.new
SLUGS.each do |path|
  body = get(path).body
  body.scan(/<a\s[^>]*href=["']([^"'#]+)["']/i).flatten.each do |href|
    next if href.start_with?("mailto:", "tel:", "javascript:")
    next if href.start_with?("http") && !href.start_with?(BASE) && !href.include?("slimfile.net")

    links << URI.parse(href).path if href.start_with?("/") || href.include?("slimfile.net")
  end
end
links.each do |l|
  res = get(l)
  fail!("internal-link", "#{l} -> #{res.code} #{res['location']}") unless res.code == "200"
end
puts "  #{links.size} distinct internal link targets checked"

# ── 5. canonical vs JSON-LD ──────────────────────────────────────────────────
puts "\n[5/6] canonical vs JSON-LD url/@id, hreflang sanity"
(SLUGS + %w[/en/blog /about /en/about]).uniq.each do |path|
  res = get(path)
  next unless res.code == "200"

  body = res.body
  c = canonical(body)
  jsonld_blocks(body).each do |block|
    block.scan(/"url"\s*:\s*"([^"]+)"/).flatten.each do |u|
      next unless u.include?("/blog/")

      fail!("json-ld", "#{path}: JSON-LD url #{u} != canonical #{c}") unless u == c
    end
    block.scan(/"@id"\s*:\s*"([^"]+)"/).flatten.each do |u|
      next unless u.include?("/blog/")

      fail!("json-ld", "#{path}: JSON-LD @id #{u} != canonical #{c}") unless u == c
    end
  end
  alts = hreflangs(body)
  xdef = alts.select { |l, _| l == "x-default" }
  # An x-default with no real alternates would point at a page nobody can index.
  fail!("hreflang", "#{path}: x-default with no alternates") if xdef.any? && alts.size == xdef.size && path.start_with?("/blog/")
  alts.each do |_lang, href|
    r = get(URI.parse(href).path)
    fail!("hreflang", "#{path}: alternate #{href} -> #{r.code}") unless r.code == "200"
    fail!("hreflang", "#{path}: alternate #{href} is noindex") if r.code == "200" && meta(r.body, "robots").to_s.include?("noindex")
  end
end
puts "  #{(SLUGS + %w[/en/blog /about /en/about]).uniq.size} pages checked"

# ── 6. Accept-Language invariance ────────────────────────────────────────────
puts "\n[6/6] Accept-Language invariance on prefix-free URLs"
LANGS = [ nil, "en-US", "ja", "es", "ko" ]
prefix_free = (%w[/ /about /faq /compress /pdf /social /blog] +
               SLUGS.select { |s| s.start_with?("/blog/") }).uniq
prefix_free.each do |path|
  seen = LANGS.map do |lang|
    h = lang ? { "Accept-Language" => lang } : {}
    res = get(path, headers: h)
    [ lang, canonical(res.body), meta(res.body, "robots") ]
  end
  cs = seen.map { |_, c, _| c }.uniq
  rs = seen.map { |_, _, r| r }.uniq
  fail!("accept-language", "#{path} canonical varies by language: #{seen.inspect}") if cs.size > 1
  fail!("accept-language", "#{path} robots varies by language: #{seen.inspect}") if rs.size > 1
end
puts "  #{prefix_free.size} pages x #{LANGS.size} languages"

puts "\n#{'=' * 60}"
if $failures.empty?
  puts "ALL CHECKS PASSED"
  exit 0
else
  puts "#{$failures.size} FAILURE(S):"
  $failures.each { |f| puts "  - #{f}" }
  exit 1
end
