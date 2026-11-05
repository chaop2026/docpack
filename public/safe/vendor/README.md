# /safe/vendor/ — the libraries the redaction tool runs on, served from this site

These files are vendored copies of published releases. They are **not modified**:
every byte was fetched from the upstream CDN/registry URL listed below and
checked against an independently published hash (see *Provenance* ).

## Why they are here and not on a CDN

`/safe/` is the screen where someone opens a 運転免許証 or a 住民票. The page's
standing promise is that the file never leaves the browser, and
`public/privacy/index.html` §3-1 states that the page carries **no third-party
script**. Until 2026-11-05 that sentence was false: four of these libraries were
loaded from `cdnjs.cloudflare.com` and one from `cdn.jsdelivr.net`, so opening
the page announced the visitor's IP address and `Referer` to a third party, and
a visitor could not audit what those scripts did from the result file.

The 2026-11-04 cross-review (`docs/jp/codex_review_s11_2026-11-04.md`, item 5)
rated that RED. Rewording the sentence was the cheaper fix; moving the files is
the one that makes the sentence true. It also removes a dependency: a cdnjs
outage used to take the tool down with it, and now does not.

## Provenance

| File | Upstream URL fetched | Verified against |
|---|---|---|
| `pdf.min.js` | `https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js` | cdnjs API `sri` for pdf.js 3.11.174 — sha512 matches |
| `pdf.worker.min.js` | `https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js` | cdnjs API `sri` — sha512 matches |
| `mammoth.browser.min.js` | `https://cdnjs.cloudflare.com/ajax/libs/mammoth/1.6.0/mammoth.browser.min.js` | cdnjs API `sri` — sha512 matches |
| `jspdf.umd.min.js` | `https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js` | cdnjs API `sri` — sha512 matches |
| `heic2any.min.js` | `https://cdn.jsdelivr.net/npm/heic2any@0.0.4/dist/heic2any.min.js` | `package/dist/heic2any.min.js` inside the npm 0.0.4 tarball — sha256 identical |

cdnjs publishes an SRI hash per file through `api.cdnjs.com`, which is a
*different* response than the file itself; comparing the two is what makes this
a check rather than a tautology (re-hashing a download always agrees with
itself). heic2any has no SRI endpoint, so the npm tarball — a different host and
a different artifact — plays that role.

Verify at any time:

    cd public/safe/vendor && shasum -a 256 -c SHA256SUMS

## Versions are pinned, and that is deliberate

The versions here are exactly the ones `/safe/index.html` loaded from the CDN
before the move, so this change is a transport change and not an upgrade. The
golden harness (`test/safe/run.mjs`, 557 assertions over the four Japanese
fixtures) exercises pdf.js rendering, mammoth `.docx` reading and jsPDF output
on every run, and would be the thing that noticed if a version had shifted.

Upgrading one of them means re-running that harness, not just swapping a file:
the box coordinates every JP detection rule depends on come out of pdf.js's text
layer.

## What is still NOT here — Tesseract.js

`CDN_TESSERACT` in `index.html` still points at `cdn.jsdelivr.net`. It is loaded
lazily, only when an image or a scanned page needs OCR. It was left on the CDN
for a reason that is about honesty rather than effort:

* Tesseract.js v5 picks its WebAssembly core at runtime (`simd` / `lstm`
  variants — four candidate files, ~4.7 MB each as the emscripten JS wrapper),
  so self-hosting the library means also hosting and correctly selecting the
  core.
* Even after that, the language data stays third-party. `kor.traineddata.gz`
  alone is 7 MB and the page needs `kor+eng`, `eng`, `jpn+eng` and `spa+eng`
  depending on UI language — roughly 20 MB, fetched from
  `tessdata.projectnaptha.com` at recognise time.

Self-hosting the scripts while the data still leaves the origin would make the
promise *look* closed while a visitor watching the network tab during an OCR run
still sees third-party requests. That is the exact failure the RED named, so the
privacy policy names the OCR exception out loud instead (§3-1), and
`test/integration/jp_analytics_scope_test.rb` holds Tesseract as the single
visible entry on an otherwise empty allowlist — the same pattern S11 used for
AdSense, so that the exception cannot be hidden by a short list.

Google Fonts (`fonts.googleapis.com`, a stylesheet and its woff2 files) is also
still third-party. It is not a script, so §3-1's sentence is not false because
of it, but it is the next thing to bring in-house.
