# /fonts/ — the webfonts, served from this site

`IBM Plex Sans KR` (400/500/700) and `IBM Plex Mono` (400/500), vendored from
Google Fonts on **2026-11-06 (S12)**. Not modified, not subset, not upgraded:
every byte is the byte `fonts.gstatic.com` served.

## Why they are here and not on Google's CDN

`/safe/` is the screen where someone opens a 運転免許証 or a 住民票, and
`public/privacy/index.html` §3-1 promises that screen loads no access analytics
and no third-party script, then names its exceptions out loud.

S11c (2026-11-05) moved pdf.js, its worker, mammoth, jsPDF and heic2any
on-origin for exactly that reason, and `public/safe/vendor/README.md` closed
with: *"Google Fonts … is not a script, so §3-1's sentence is not false because
of it, but it is the next thing to bring in-house."* This is that.

A webfont is not a script, so this did not make a false sentence true — it
removed an exception from a list. What it does change is observable: before the
move, loading any of the five pages announced the visitor's IP address and
`Referer` to `fonts.googleapis.com` and `fonts.gstatic.com`, and a reader
auditing their own network tab could not tell a font request from any other
third-party request. §3-1 now names **one** exception (OCR) instead of two.

Side effect worth having: a Google Fonts outage or a network that blocks it no
longer changes how the tool looks.

## What was deliberately NOT done

**No re-subsetting.** The 292 `@font-face` blocks keep Google's exact
`unicode-range` split — 5 named subsets per Mono weight, and 94 per Sans KR
weight (latin, latin-ext, and ~92 unlabelled Korean ranges). Those ranges are
the mechanism that makes a browser download only the handful of Korean subsets a
page actually contains. So runtime traffic after this change has the same shape
as before it; only the origin differs.

Building one merged font per weight would have been fewer files, but it would
have meant deciding which glyphs are allowed to appear on pages whose UI text is
a four-language i18n dictionary (`/safe/` switches ko/en/ja/es client-side). A
glyph left out of that decision does not fail loudly — it silently falls back to
`-apple-system`, on one page, in one language, for whoever happens to read it.

**No version change.** These are the files the pages were already loading, so
this is a transport change. 2.34 MB across 292 files.

**Japanese is still system-rendered.** `IBM Plex Sans KR` covers Latin and
Hangul, not Japanese. The JP landings' stack
(`'IBM Plex Sans KR', -apple-system, 'Hiragino Kaku Gothic ProN', 'Noto Sans JP', …`)
has always drawn kana and kanji from the reader's own system fonts, and still
does. Nothing regressed; it is just not something this change fixed.

## Provenance and how far it is checked

| | |
|---|---|
| Upstream stylesheet | `https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+KR:wght@400;500;700&family=IBM+Plex+Mono:wght@400;500&display=swap` |
| As received | `_google-css2.txt` (kept verbatim, so a re-vendor can diff against it) |
| Generated from it | `fonts.css` — rewritten, not string-patched |
| Licence | `LICENSE.ibm-plex.txt` — SIL OFL 1.1, fetched from `IBM/plex` |

Google publishes **no SRI hash for font files**, so the check
`public/safe/vendor/` uses — compare the download against an independently
published hash — is not available here. Re-hashing a download agrees with itself
and proves nothing. What `script/vendor_fonts.mjs` does instead:

1. fetches every file **twice**, in separate connections, and requires the two
   sha256 to agree — this catches a truncated or corrupted transfer, which is
   the failure actually in play on an immutable versioned URL;
2. requires the byte length to equal the `Content-Length` the server advertised
   (a different field, of a different response);
3. requires every file to begin with the woff2 magic `wOF2`.

**This is weaker than an upstream hash, and saying so is the point.** It
establishes that we received intact what that URL served; it does not
independently establish what that URL *should* serve.

Verify the committed bytes at any time:

    cd public/fonts && shasum -a 256 -c SHA256SUMS

## Re-vendoring

    node script/vendor_fonts.mjs            # fetch, write, verify
    node script/vendor_fonts.mjs --verify   # check what is on disk, fetch nothing

The script pins a modern browser `User-Agent`: `css2` serves legacy `ttf` to a
bare curl UA, so without the pin the output format would depend on whoever ran
it. It also refuses to continue if two `@font-face` blocks would land on the
same filename — a silent overwrite there would drop a `unicode-range` and lose
glyphs for one script, in one weight, with nothing failing.

If the upstream subset split ever changes, `fonts.css` changes shape and the
file count moves. That is a decision to look at, not a diff to wave through:
`test/integration/webfont_self_hosting_test.rb` asserts the family/weight
coverage, so a shift that drops a weight fails rather than passing quietly.

## Who loads this

`/fonts/fonts.css` is referenced by the five static pages that used to carry the
Google Fonts `<link>` pair:

- `public/safe/index.html`
- `public/privacy/index.html`
- `public/safe/jp/nyusatsu/index.html`
- `public/safe/jp/honnin-kakunin/index.html`
- `public/safe/jp/ai-mae/index.html`

The Rails layout (`app/views/layouts/application.html.erb`) never loaded Google
Fonts — the Korean site runs on a system font stack
(`-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, …`). It is covered by
the same test anyway, so that stays true by assertion rather than by habit.

The generation templates under `scripts/content/templates/` (carousel, guide,
shorts card) still fetch from Google Fonts. They render locally through
Playwright to produce PNG/PDF artefacts and are never served to a visitor, so
they are outside the promise this directory exists to keep. They were left alone
on purpose: changing them means re-running the episode generator to verify, and
that generator overwrote 45 committed artefacts in the 2026-11-05 run.
