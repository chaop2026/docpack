#!/usr/bin/env node
/*
 * vendor_fonts.mjs — bring the Google Fonts stylesheet and its woff2 files
 * on-origin, into public/fonts/. Re-runnable.
 *
 *   node script/vendor_fonts.mjs            # fetch + write + verify
 *   node script/vendor_fonts.mjs --verify   # verify what is on disk, fetch nothing
 *
 * Why this exists (S12, 2026-11-06)
 *   /safe/ is the screen where someone opens a 運転免許証. public/privacy/ §3-1
 *   promises that screen carries no third-party script and names its exceptions.
 *   S11c moved pdf.js/mammoth/jsPDF/heic2any on-origin for that reason and its
 *   README closed with "Google Fonts … is the next thing to bring in-house".
 *   This is that. A webfont is not a script, but it is still a request that
 *   announces the visitor's IP and Referer to a third party on every page view,
 *   and a reader auditing their own network tab cannot tell the difference.
 *
 * What is NOT done here
 *   No subsetting, no re-compression, no version change. Every byte is the byte
 *   fonts.gstatic.com served, and the @font-face blocks keep Google's exact
 *   `unicode-range` split. That matters: the ranges are what make the browser
 *   download only the handful of Korean subsets a page actually needs, so
 *   runtime traffic after this change is the same shape as before it — only the
 *   origin differs. Re-subsetting would have meant deciding which glyphs are
 *   allowed to appear on a page whose UI text is a 4-language i18n dictionary.
 *
 * Integrity
 *   Google publishes no SRI for font files, so there is no independent hash to
 *   compare against (the pattern public/safe/vendor/README.md uses). Re-hashing
 *   a download agrees with itself and proves nothing. What IS available:
 *     1. every file is fetched TWICE, in separate connections, and the two
 *        sha256 must agree — catches a truncated or corrupted transfer, which
 *        is the failure mode actually in play on an immutable versioned URL;
 *     2. the byte length must equal the Content-Length the server advertised
 *        (a different field of a different response);
 *     3. every file must begin with the woff2 magic `wOF2`.
 *   This is weaker than an upstream hash and the README says so out loud.
 */

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const ROOT = path.resolve(import.meta.dirname, "..");
const OUT = path.join(ROOT, "public", "fonts");

// Pinned exactly as the pages requested it before the move, so this is a
// transport change and not a font upgrade. Keep these two strings in sync with
// the comment in public/fonts/README.md if they ever change.
const SRC = "https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+KR:wght@400;500;700&family=IBM+Plex+Mono:wght@400;500&display=swap";
// css2 serves woff2 only to UAs it believes support it; with a bare curl UA it
// returns legacy ttf. Pin a modern UA so the output format is not a function of
// whatever the runner happens to send.
const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

const VERIFY_ONLY = process.argv.includes("--verify");
const sha256 = (buf) => crypto.createHash("sha256").update(buf).digest("hex");

/** Slug for a @font-face: family + weight + subset label (or ordinal). */
function fileName(family, weight, label, ordinal) {
  const fam = family.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
  const tail = label ?? `s${String(ordinal).padStart(3, "0")}`;
  return `${fam}-${weight}-${tail}.woff2`;
}

/** Split the Google stylesheet into blocks, carrying the /* subset *​/ comment. */
function parseCss(css) {
  const out = [];
  // Comments label only the named subsets (latin, cyrillic, …). The ~92 Korean
  // ranges per weight arrive unlabelled, which is why fileName() falls back to
  // an ordinal rather than inventing a name for them.
  const re = /(?:\/\*\s*([^*]+?)\s*\*\/\s*)?@font-face\s*\{([^}]*)\}/g;
  const perKey = new Map();
  let m;
  while ((m = re.exec(css))) {
    const [, label, body] = m;
    const family = (body.match(/font-family:\s*['"]([^'"]+)['"]/) || [])[1];
    const weight = (body.match(/font-weight:\s*(\d+)/) || [])[1];
    const style = (body.match(/font-style:\s*([a-z]+)/) || [])[1] ?? "normal";
    const url = (body.match(/url\((https:\/\/[^)]+)\)/) || [])[1];
    const range = (body.match(/unicode-range:\s*([^;]+);/) || [])[1];
    if (!family || !weight || !url) throw new Error(`unparsable @font-face:\n${body}`);
    const key = `${family}|${weight}`;
    const ordinal = (perKey.get(key) ?? 0) + 1;
    perKey.set(key, ordinal);
    out.push({
      family, weight, style, url,
      range: range ? range.trim() : null,
      label: label ? label.trim() : null,
      file: fileName(family, weight, label ? label.trim() : null, ordinal),
    });
  }
  return out;
}

async function fetchBuf(url) {
  const res = await fetch(url, { headers: { "User-Agent": UA } });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${url}`);
  const advertised = Number(res.headers.get("content-length") ?? 0);
  const buf = Buffer.from(await res.arrayBuffer());
  return { buf, advertised };
}

/** Run jobs with bounded concurrency; preserves input order in the result. */
async function pool(items, limit, fn) {
  const results = new Array(items.length);
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(limit, items.length) }, async () => {
      while (true) {
        const i = next++;
        if (i >= items.length) return;
        results[i] = await fn(items[i], i);
      }
    }),
  );
  return results;
}

// ── 1. the stylesheet ───────────────────────────────────────────────────────
const cssPath = path.join(OUT, "_google-css2.txt");
let rawCss;
if (VERIFY_ONLY) {
  rawCss = fs.readFileSync(cssPath, "utf8");
  console.log(`[verify] 저장된 상류 CSS 사용: ${path.relative(ROOT, cssPath)}`);
} else {
  const r = await fetchBuf(SRC);
  rawCss = r.buf.toString("utf8");
  fs.mkdirSync(OUT, { recursive: true });
  // Kept so --verify and the next re-vendor can diff against what we actually
  // received, instead of re-deriving it from a URL that may have moved on.
  fs.writeFileSync(cssPath, rawCss);
}

const faces = parseCss(rawCss);
const families = [...new Set(faces.map((f) => f.family))];
console.log(`[css] @font-face ${faces.length}개 · family ${families.join(" / ")}`);
for (const fam of families) {
  const ws = [...new Set(faces.filter((f) => f.family === fam).map((f) => f.weight))].sort();
  for (const w of ws) {
    const n = faces.filter((f) => f.family === fam && f.weight === w).length;
    console.log(`       ${fam} ${w}: ${n} subset`);
  }
}
if (!faces.length) { console.error("❌ @font-face 0개 — 상류 CSS 형식이 바뀌었다"); process.exit(1); }

// Two files must never collide; a silent overwrite would drop a unicode-range.
const dupes = faces.map((f) => f.file).filter((f, i, a) => a.indexOf(f) !== i);
if (dupes.length) { console.error(`❌ 파일명 충돌: ${[...new Set(dupes)].join(", ")}`); process.exit(1); }

// ── 2. the woff2 files ──────────────────────────────────────────────────────
let failures = 0;
const sums = [];

if (VERIFY_ONLY) {
  for (const f of faces) {
    const p = path.join(OUT, f.file);
    if (!fs.existsSync(p)) { console.error(`❌ 없음: ${f.file}`); failures++; continue; }
    const buf = fs.readFileSync(p);
    if (buf.subarray(0, 4).toString("latin1") !== "wOF2") {
      console.error(`❌ woff2 매직 불일치: ${f.file}`); failures++; continue;
    }
    sums.push(`${sha256(buf)}  ${f.file}`);
  }
  console.log(`[verify] ${faces.length - failures}/${faces.length} 파일 확인`);
} else {
  const res = await pool(faces, 8, async (f) => {
    // Fetched twice on purpose — see the Integrity note at the top.
    const a = await fetchBuf(f.url);
    const b = await fetchBuf(f.url);
    const ha = sha256(a.buf), hb = sha256(b.buf);
    const problems = [];
    if (ha !== hb) problems.push("두 번의 fetch 결과가 다름");
    if (a.advertised && a.advertised !== a.buf.length) {
      problems.push(`Content-Length ${a.advertised} ≠ 실제 ${a.buf.length}`);
    }
    if (a.buf.subarray(0, 4).toString("latin1") !== "wOF2") problems.push("woff2 매직 아님");
    return { f, buf: a.buf, hash: ha, problems };
  });

  for (const r of res) {
    if (r.problems.length) {
      console.error(`❌ ${r.f.file}: ${r.problems.join(" · ")}`);
      failures++;
      continue;
    }
    fs.writeFileSync(path.join(OUT, r.f.file), r.buf);
    fs.chmodSync(path.join(OUT, r.f.file), 0o644);
    sums.push(`${r.hash}  ${r.f.file}`);
  }
  const bytes = res.reduce((a, r) => a + (r.buf?.length ?? 0), 0);
  console.log(`[woff2] ${res.length - failures}/${res.length} 파일 · ${(bytes / 1048576).toFixed(2)} MB`);
}

if (failures) { console.error(`❌ ${failures}건 실패 — 아무 것도 신뢰하지 말 것`); process.exit(1); }

// ── 3. the local stylesheet ─────────────────────────────────────────────────
// Rewritten rather than string-replaced so a change in Google's formatting
// cannot smuggle anything through; every property emitted here is one this
// script understood and re-stated.
const header = `/* IBM Plex Sans KR + IBM Plex Mono — served from this origin.
 *
 * GENERATED by script/vendor_fonts.mjs. Do not hand-edit: re-run the script.
 * Upstream: ${SRC}
 * Vendored: 2026-11-06 (S12). See public/fonts/README.md for why and for the
 * licence. unicode-range values are Google's, unchanged — they are what keeps
 * the browser downloading only the subsets a page actually needs.
 */
`;
const blocks = faces.map((f) => [
  f.label ? `/* ${f.label} */` : null,
  "@font-face {",
  `  font-family: '${f.family}';`,
  `  font-style: ${f.style};`,
  `  font-weight: ${f.weight};`,
  "  font-display: swap;",
  `  src: url(/fonts/${f.file}) format('woff2');`,
  f.range ? `  unicode-range: ${f.range};` : null,
  "}",
].filter(Boolean).join("\n"));

const cssOut = path.join(OUT, "fonts.css");
fs.writeFileSync(cssOut, `${header}${blocks.join("\n")}\n`);
fs.chmodSync(cssOut, 0o644);

if (!VERIFY_ONLY) {
  fs.writeFileSync(path.join(OUT, "SHA256SUMS"), `${sums.sort().join("\n")}\n`);
  fs.chmodSync(path.join(OUT, "SHA256SUMS"), 0o644);
  fs.chmodSync(cssPath, 0o644);
}

console.log(`✅ public/fonts/fonts.css · @font-face ${faces.length} · ${faces.length} woff2`);
console.log(`   확인: cd public/fonts && shasum -a 256 -c SHA256SUMS`);
