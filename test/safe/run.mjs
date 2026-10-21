#!/usr/bin/env node
/*
 * Golden verification harness for the SafeFile PII pipeline.
 *
 * Serves the REAL public/safe/index.html in headless Chrome, drives the live
 * detection over each fixture, and checks every value against specs.json:
 *   - MUST_MASK      : value is geometrically covered by an active mask rect
 *   - MUST_NOT_MASK  : value is NOT covered by any mask rect
 *   - NEVER_CANDIDATE: value is not proposed as a review candidate
 *   - SHOULD_CANDIDATE: value surfaces as a candidate (visible, not hidden)
 *   - AI_INJECT      : adversarial AI labels are neutralised in addEntities
 *   - TEXT_LEAK      : output PDF has 0 extractable characters
 *   - OUT_SAFE       : output carries no annots/embedded files/incremental save/EXIF
 *
 * Requires: node, playwright (chrome channel). Fixtures from generate_fixtures.py.
 * Usage: node run.mjs [--only 7_resume_dark.pdf]  (exit 0 = all pass)
 */
import { chromium } from 'playwright';
import { spawnSync } from 'node:child_process';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, '..', '..');
const PUBLIC = path.join(REPO, 'public');
const DOCS = path.join(__dirname, 'testdocs');
const FIXTURES = path.join(__dirname, 'fixtures');
const SPECS = JSON.parse(fs.readFileSync(path.join(__dirname, 'specs.json'), 'utf8'));
const OUT = path.join(__dirname, 'out');
fs.mkdirSync(OUT, { recursive: true });

const onlyArg = (() => { const i = process.argv.indexOf('--only'); return i >= 0 ? process.argv[i + 1] : null; })();

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json', '.txt': 'text/plain' };

function startServer() {
  return new Promise(resolve => {
    const srv = http.createServer((req, res) => {
      let p = decodeURIComponent(req.url.split('?')[0]);
      if (p === '/') p = '/index.html';
      // `/__fx/...` serves the fixture tree, so the page can read fixture images
      // back as <img> (used to compose the multi-page PDF fixture at run time).
      const root = p.startsWith('/__fx/') ? FIXTURES : PUBLIC;
      if (p.startsWith('/__fx/')) p = p.slice(5);
      const fp = path.join(root, p);
      if (!fp.startsWith(root) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end('nf'); return; }
      res.writeHead(200, { 'content-type': MIME[path.extname(fp)] || 'application/octet-stream' });
      fs.createReadStream(fp).pipe(res);
    });
    srv.listen(0, '127.0.0.1', () => resolve(srv));
  });
}

// ── in-page helpers, serialised into the browser context ──
const PAGE_HELPERS = () => {
  // Active mask rects: every entity that is ON, not 'ok', and located — passed
  // through bandRect() so the harness measures the pixels that are ACTUALLY
  // painted (box + padding), not the pre-padding estimate. This makes MUST_MASK
  // easier and MUST_NOT_MASK harder, which is the honest direction: a padding
  // that bleeds onto a neighbouring must-keep value now fails the golden.
  window.__maskRects = function () {
    const rects = [];
    for (const e of entities) {
      if (!isOn(e) || e.mode === 'ok' || !(e.boxes && e.boxes.length)) continue;
      for (let pi = 0; pi < pages.length; pi++) {
        for (const l of mergeLineBoxes(e.boxes, pi)) { const r = bandRect(l); rects.push({ pi, x: r.x, y: r.y, w: r.w, h: r.h }); }
      }
    }
    return rects;
  };
  window.__rectsFor = function (v) {
    return boxesForValue(v).map(b => ({ pi: b.page, x: b.x, y: b.y, w: b.w, h: b.h }));
  };
  window.__isMasked = function (v) {
    const mr = window.__maskRects(), vr = window.__rectsFor(v);
    const ov = (a, b) => {
      if (a.pi !== b.pi) return 0;
      const ix = Math.max(0, Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x));
      const iy = Math.max(0, Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y));
      return ix * iy;
    };
    for (const b of vr) { const area = b.w * b.h; if (area <= 0) continue; for (const a of mr) if (ov(a, b) > area * 0.25) return true; }
    return false;
  };
  const norm = s => (s || '').toLowerCase().replace(/\s+/g, ' ').replace(/[.,;:'"()]+$/g, '').replace(/^[.,;:'"()]+/g, '').trim();
  window.__norm = norm;
  window.__entitySnapshot = function () {
    return entities.map(e => ({ type: e.type, value: e.value, kind: e.kind, mode: e.mode, reason: e.reason, located: !!(e.boxes && e.boxes.length) }));
  };
  /* ── JP: geometry is checked against the FIXTURE'S OWN box table, not against
     a value string. A Japanese form's value is exactly what OCR mangles
     (美咲 → "S=0%"), so asserting on the string would test Tesseract, not us;
     the box is what the band has to cover either way. ── */
  // fraction of `rect` (page coords) covered by the union of active mask rects,
  // sampled on a grid so overlapping bands count once.
  window.__coverage = function (rect) {
    const mr = window.__maskRects().filter(r => r.pi === rect.pi);
    if (!mr.length) return 0;
    const N = 24; let hit = 0;
    for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) {
      const x = rect.x + rect.w * (i + 0.5) / N, y = rect.y + rect.h * (j + 0.5) / N;
      if (mr.some(r => x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h)) hit++;
    }
    return hit / (N * N);
  };
  // OCR/text item boxes whose centre falls inside `rect`
  window.__itemsIn = function (rect) {
    const p = pages[rect.pi]; if (!p) return [];
    return (p.items || []).filter(it => it.x + it.w / 2 >= rect.x && it.x + it.w / 2 <= rect.x + rect.w
                                     && it.y + it.h / 2 >= rect.y && it.y + it.h / 2 <= rect.y + rect.h)
      .map(it => ({ pi: rect.pi, x: it.x, y: it.y, w: it.w, h: it.h }));
  };
  // any ACTIVE candidate entity overlapping `rect` (did the field surface for review?)
  window.__candidateOver = function (rect) {
    for (const e of entities) {
      if (e.kind !== 'candidate' || !e.boxes) continue;
      for (const b of e.boxes) {
        if (b.page !== rect.pi) continue;
        if (!(b.x + b.w < rect.x || rect.x + rect.w < b.x || b.y + b.h < rect.y || rect.y + rect.h < b.y)) return true;
      }
    }
    return false;
  };
  /* ── ink coverage (replaces the 60% area gate on number fields) ──
     A 60% area figure says HOW MUCH of a box was painted, never WHERE: the
     kouki fixture measured 96% with its leading digit fully outside the band
     (Codex 5-3, and we had already recorded it). So for a field whose value is
     a number, the question is per-GLYPH: take the ink inside the expected box,
     label its connected components, and require every component to be covered.
     Threshold 60 (not the detector's 40) deliberately excludes the fixtures'
     見本 watermark — composited it sits ~48 off the background, and a band is
     not required to cover a watermark. */
  window.__inkCover = function (rect) {
    const p = pages[rect.pi]; if (!p) return null;
    const CW = p.canvas.width, CH = p.canvas.height;
    const x0 = Math.max(0, Math.floor(rect.x)), y0 = Math.max(0, Math.floor(rect.y));
    const x1 = Math.min(CW, Math.ceil(rect.x + rect.w)), y1 = Math.min(CH, Math.ceil(rect.y + rect.h));
    const W = x1 - x0, H = y1 - y0;
    if (W <= 0 || H <= 0) return { components: 0, inkPx: 0, uncovered: 0, worst: 1 };
    const ctx = p.canvas.getContext('2d', { willReadFrequently: true });
    const d = ctx.getImageData(x0, y0, W, H).data, bg = jpPageBg(p);
    const ink = new Uint8Array(W * H);
    let inkPx = 0;
    for (let i = 0; i < W * H; i++) {
      if (Math.abs(d[i * 4] - bg[0]) > 60 || Math.abs(d[i * 4 + 1] - bg[1]) > 60 || Math.abs(d[i * 4 + 2] - bg[2]) > 60) { ink[i] = 1; inkPx++; }
    }
    const mr = window.__maskRects().filter(r => r.pi === rect.pi);
    const covered = (px, py) => mr.some(r => px >= r.x && px <= r.x + r.w && py >= r.y && py <= r.y + r.h);
    const seen = new Uint8Array(W * H);
    let components = 0, uncovered = 0, worst = 1;
    for (let i = 0; i < W * H; i++) {
      if (!ink[i] || seen[i]) continue;
      const st = [i]; seen[i] = 1; let n = 0, cov = 0;
      while (st.length) {
        const k = st.pop(), kx = k % W, ky = (k - kx) / W;
        n++; if (covered(x0 + kx + 0.5, y0 + ky + 0.5)) cov++;
        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
          const nx = kx + dx, ny = ky + dy;
          if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
          const nk = ny * W + nx;
          if (ink[nk] && !seen[nk]) { seen[nk] = 1; st.push(nk); }
        }
      }
      // Specks (anti-aliasing debris, watermark bleed) are not glyphs.
      if (n < 6) continue;
      components++;
      const f = cov / n;
      if (f < worst) worst = f;
      if (f < 0.99) uncovered++;
    }
    return { components, inkPx, uncovered, worst };
  };
  /* Every entity carrying `field`, with the facts require_banded is actually
     about: is it located, is its category ON, is it not 'ok', and do the rects
     it would paint ACTUALLY appear in the active mask-rect list? The old
     assertion read `mode !== 'ok'` alone, which stays true for an entity whose
     category is off or whose boxes are empty (Codex 5-5). */
  window.__fieldBands = function (field) {
    const mr = window.__maskRects();
    const same = (a, b) => Math.abs(a.x - b.x) < 0.01 && Math.abs(a.y - b.y) < 0.01 && Math.abs(a.w - b.w) < 0.01 && Math.abs(a.h - b.h) < 0.01;
    return entities.filter(e => e.jp && e.jp.field === field).map(e => {
      const rects = [];
      for (let pi = 0; pi < pages.length; pi++) for (const l of mergeLineBoxes(e.boxes || [], pi)) { const r = bandRect(l); rects.push({ pi, ...r }); }
      return { level: e.jp.level, note: e.jp.note, page: e.jp.page, doc: e.jp.doc, side: e.jp.side,
        kind: e.kind, mode: e.mode, legal: !!e.legal, located: !!(e.boxes && e.boxes.length), on: isOn(e),
        rects: rects.length, inMask: rects.length > 0 && rects.every(r => mr.some(m => m.pi === r.pi && same(m, r))) };
    });
  };
  window.__jpState = function () {
    return { cls: jpState.cls && { doc: jpState.cls.doc, side: jpState.cls.side || null, score: jpState.cls.score, low: !!jpState.cls.low },
      purpose: jpState.purpose, warn: jpState.warn, mnConfirmed: jpState.mnConfirmed,
      pageCls: jpState.pageCls.map(c => c && { doc: c.doc, side: c.side || null, low: !!c.low }),
      warnShown: (() => { const el = document.getElementById('jpWarn'); return !!el && el.style.display !== 'none' && !!el.textContent.trim(); })(),
      mnBoxShown: (() => { const el = document.getElementById('jpMnWrap'); return !!el && el.style.display !== 'none'; })(),
      pw: pages.map(p => p.w),
      fields: entities.filter(e => e.jp).map(e => ({ field: e.jp.field, level: e.jp.level, note: e.jp.note, page: e.jp.page, kind: e.kind, mode: e.mode, legal: !!e.legal, on: isOn(e) })) };
  };
  // Field labels of every ACTIVE auto entity — the allowlist assertion's input.
  window.__autoFields = function () {
    return entities.filter(e => e.kind === 'auto').map(e => e.jp ? e.jp.field : '(regex:' + e.type + ')');
  };
  /* Turn every general category OFF. A legal-preset band must survive this.
     catEnabled is module-level state that resetAll() and a fresh file load do
     NOT restore, so this hands back a restore function — the first version of
     this helper left every category off for the remaining 300 assertions and
     turned 14 of them red. */
  window.__catSnapshot = null;
  window.__allCatsOff = function () {
    window.__catSnapshot = { ...catEnabled };
    for (const t of Object.keys(catEnabled)) catEnabled[t] = false;
    renderAll();
    return Object.keys(catEnabled).filter(t => catEnabled[t] !== false);
  };
  window.__restoreCats = function () {
    if (!window.__catSnapshot) return false;
    for (const t of Object.keys(window.__catSnapshot)) catEnabled[t] = window.__catSnapshot[t];
    window.__catSnapshot = null; renderAll(); return true;
  };
  window.__setMnConfirm = function (v) { jpSetMnConfirmed(v); };
  window.__isCandidateExact = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value) === n); };
  window.__isCandidateContains = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value).includes(n)); };
  // default mode of the candidate whose value contains v (null if not a candidate)
  window.__candidateMode = function (v) { const n = norm(v); const e = entities.find(x => x.kind === 'candidate' && norm(x.value).includes(n)); return e ? e.mode : null; };
  // name-bar geometry: glyph union (raw pdf items) vs drawn bar rect
  window.__nameBar = function (v) {
    const rects = boxesForValue(v).filter(b => b.page === 0);
    if (!rects.length) return null;
    const lines = mergeLineBoxes(rects, 0); const bar = lines[0];
    // glyph union straight from page items overlapping the value
    const its = (pages[0].items || []).filter(it => (v.split(/\s+/).some(w => (it.str || '').includes(w))));
    if (!its.length) return null;
    const gx0 = Math.min(...its.map(i => i.x)), gy0 = Math.min(...its.map(i => i.y));
    const gx1 = Math.max(...its.map(i => i.x + i.w)), gy1 = Math.max(...its.map(i => i.y + i.h));
    const gW = gx1 - gx0, gH = gy1 - gy0;
    // replicate the drawn-band geometry exactly as the page would paint it.
    const drawn = bandRect(bar);
    // Ink safety: the bar must cover the full glyph WIDTH and, vertically, the
    // cap-height→descent band (raw pdf font box minus the top ascent gap where
    // no ink lives). It should NOT need to cover the empty ascent whitespace.
    const inkTop = gy0 + gH * 0.18, inkBot = gy1;
    const coversInk = drawn.x <= gx0 + 1 && drawn.x + drawn.w >= gx1 - 1 && drawn.y <= inkTop + 1 && drawn.y + drawn.h >= inkBot - 1;
    return { barW: bar.w, barH: bar.h, drawnH: drawn.h, drawnW: drawn.w, glyphW: gW, glyphH: gH, containsGlyph: coversInk };
  };
};

// `jp/...` paths resolve under fixtures/, `gen/...` under out/gen (built at run
// time from committed fixtures — no new binaries in the repo), everything else
// under testdocs/.
const docPath = file => file.startsWith('jp/') ? path.join(FIXTURES, file)
  : file.startsWith('gen/') ? path.join(OUT, file) : path.join(DOCS, file);
async function loadDoc(page, file, ocr) {
  await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
  await page.setInputFiles('#fileInput', docPath(file));
  // `pages.length > 0` is NOT "loaded": pages are pushed one at a time, so on a
  // multi-page OCR document it goes true while page 2 is still in Tesseract —
  // and everything measured after it describes half a document. afterLoad()
  // reveals #docWrap as its last step, so that is the completion signal.
  await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0
      && document.getElementById('docWrap').style.display === 'flex',
    { timeout: ocr ? 300000 : 40000 });
  await page.waitForTimeout(ocr ? 800 : 400);
  await page.evaluate(PAGE_HELPERS);
}

const rows = [];
const rec = (doc, cat, item, expected, actual, pass, info = false) => rows.push({ doc, cat, item, expected, actual, pass, info });

async function checkDoc(page, spec) {
  const { doc, ocr } = spec;
  await loadDoc(page, doc, ocr);
  const snap = await page.evaluate(() => window.__entitySnapshot());
  const autoCount = snap.filter(e => e.kind === 'auto').length;
  process.stderr.write(`    [autoCount] ${doc} = ${autoCount}\n`);
  if (spec.min_auto != null) rec(doc, 'REGRESSION', `auto>=${spec.min_auto}`, `>=${spec.min_auto}`, String(autoCount), autoCount >= spec.min_auto);
  // False-positive regression guard: a hard CEILING on auto-detected entities.
  // The golden's MUST_MASK checks catch "did we mask what we should"; max_auto
  // catches the inverse — a detection change that starts auto-masking body text
  // (the résumé-defect class where 95/95 passed while the body got shredded).
  if (spec.max_auto != null) rec(doc, 'REGRESSION', `auto<=${spec.max_auto}`, `<=${spec.max_auto}`, String(autoCount), autoCount <= spec.max_auto);

  // Turn a name candidate ON (hide → solid) so must_mask can assert the whole
  // name — surname included — is geometrically covered once the user activates it.
  if (spec.activate_name) {
    const ok = await page.evaluate(v => {
      const e = entities.find(x => x.value === v && x.type === 'name');
      if (!e) return false;
      e.mode = 'no'; renderAll(); return true;
    }, spec.activate_name);
    rec(doc, 'NAME_WHOLE', spec.activate_name, 'detected-whole', ok ? 'detected' : 'MISSING/truncated', ok);
  }

  for (const v of spec.must_mask || []) {
    const masked = await page.evaluate(x => window.__isMasked(x), v);
    rec(doc, 'MUST_MASK', v, 'masked', masked ? 'masked' : 'NOT masked', masked);
  }
  for (const v of spec.must_not_mask || []) {
    const masked = await page.evaluate(x => window.__isMasked(x), v);
    rec(doc, 'MUST_NOT_MASK', v, 'clear', masked ? 'MASKED' : 'clear', !masked);
  }
  for (const v of spec.never_candidate || []) {
    const isCand = await page.evaluate(x => window.__isCandidateExact(x), v);
    rec(doc, 'NEVER_CANDIDATE', v, 'not-cand', isCand ? 'CANDIDATE' : 'not-cand', !isCand);
  }
  for (const v of spec.should_candidate || []) {
    // A candidate must SURFACE as a review candidate. (Its default redaction level
    // — name/address candidates now default to 'half' — is asserted separately by
    // CANDIDATE_MODE; "surfaced" is no longer coupled to "left in the clear".)
    const isCand = await page.evaluate(x => window.__isCandidateContains(x), v);
    rec(doc, 'SHOULD_CANDIDATE', v, 'candidate', isCand ? 'candidate' : 'missing', isCand);
  }
  // Candidate default-mode policy: name/address candidates default to 'half' so the
  // "확인 필요" label matches a visibly-partial state. Old code defaulted them to 'ok'.
  for (const [v, exp] of Object.entries(spec.candidate_mode || {})) {
    const mode = await page.evaluate(x => window.__candidateMode(x), v);
    rec(doc, 'CANDIDATE_MODE', v, exp, mode || 'not-candidate', mode === exp);
  }
  if (spec.name_bar) {
    const nb = await page.evaluate(x => window.__nameBar(x), spec.name_bar);
    if (nb) {
      const ratioH = nb.drawnH / nb.glyphH;
      const ok = nb.containsGlyph && ratioH <= 1.5;
      rec(doc, 'NAME_BAR', spec.name_bar, 'tight&contains', `hRatio=${ratioH.toFixed(2)} contains=${nb.containsGlyph}`, ok);
    } else rec(doc, 'NAME_BAR', spec.name_bar, 'measurable', 'no-boxes', false);
  }
  if (spec.dark_bg_value) {
    const dk = await page.evaluate(v => { const e = entities.find(x => x.value === v); const bg = e && e.boxes[0] ? e.boxes[0].bg : null; return { bg, dark: bg ? isDarkColor(bg) : null }; }, spec.dark_bg_value);
    rec(doc, 'DARK_BG', spec.dark_bg_value, 'dark bg detected', `${dk.bg} dark=${dk.dark}`, dk.dark === true, true);
  }
  for (const fmt of (spec.out_formats || (spec.type === 'pdf' ? ['pdf'] : []))) {
    await checkOutput(page, doc, fmt);
  }
}

/* ── output safety ──────────────────────────────────────────────────────────
   What the user ships is the output file, not our preview. Three separate ways
   a redacted-looking file still carries the original:
     1. a text layer under the ink (the classic "透ける黒塗り"),
     2. metadata the renderer never shows — EXIF/XMP/IPTC on images, annotations
        or embedded files in a PDF,
     3. an incrementally-saved PDF, where the PREVIOUS revision (unredacted) is
        still physically present earlier in the same byte stream.
   Each needs its own probe: pdf.js text extraction catches (1) and is blind to
   (2) and (3). So we read the produced BYTES. */
const MARKERS = {
  // PNG: every ancillary text/EXIF chunk type. Canvas encodes none of these, but
  // "it currently doesn't" is not a guarantee — assert it.
  png: [['eXIf', 'EXIF chunk'], ['tEXt', 'tEXt chunk'], ['zTXt', 'zTXt chunk'], ['iTXt', 'iTXt chunk']],
  // ICC_PROFILE is deliberately NOT forbidden: Chrome's JPEG encoder attaches a
  // 456-byte generic sRGB profile (tags: desc/rXYZ/gXYZ/bXYZ/wtpt/rTRC/cprt —
  // measured, no device identifiers). That is a colour space declaration, not
  // document content and not an identifier. What WOULD be a leak is the
  // viewer's *display* profile, which carries manufacturer/model tags and is
  // much larger — iccSafe() below bounds exactly that.
  jpg: [['Exif\0\0', 'EXIF APP1'], ['http://ns.adobe.com/xap/', 'XMP APP1'], ['Photoshop 3.0\0', 'IPTC APP13']],
  pdf: [['/Annots', 'annotation'], ['/EmbeddedFile', 'embedded file'], ['/XFA', 'XFA form'], ['/AcroForm', 'form fields'], ['/Names', 'name tree']],
};
function scanMarkers(buf, kind) {
  const hay = buf.toString('latin1');
  return MARKERS[kind].filter(([m]) => hay.includes(m)).map(([, label]) => label);
}
// An embedded ICC profile is acceptable only while it stays a generic colour
// space. A display profile (which identifies the machine that produced the file)
// is large and carries the device manufacturer / model description tags.
const ICC_MAX = 2048;
function iccSafe(buf) {
  const hay = buf.toString('latin1');
  const at = hay.indexOf('ICC_PROFILE\0');
  if (at < 0) return { ok: true, note: 'absent' };
  const size = buf.readUInt32BE(at + 14);          // profile header: byte 0..3 = size
  const body = hay.slice(at + 14, at + 14 + Math.min(size, 65535));
  const dev = ['dmnd', 'dmdd'].filter(t => body.includes(t));
  const ok = size <= ICC_MAX && dev.length === 0;
  return { ok, note: `${size}B${dev.length ? ' +' + dev.join('/') : ''}` };
}
async function checkOutput(page, doc, fmt) {
  const tag = `OUT_${fmt.toUpperCase()}`;
  try {
    await page.evaluate(f => { const r = document.querySelector(`input[name=fmt][value="${f}"]`); if (r) r.checked = true; }, fmt);
    // Force at least one masked, located entity so Make is enabled — preferring
    // an AUTO one. Taking the first ON entity happened to pick a `keep` field on
    // some JP fixtures, so the file we then inspected for leaks was one where we
    // had covered a value the recipient needs (Codex 5-5 / instruction 11).
    await page.evaluate(() => {
      const ok = x => isOn(x) && x.boxes && x.boxes.length;
      const e = entities.find(x => ok(x) && x.kind === 'auto')
             || entities.find(x => ok(x) && x.kind !== 'keep')
             || entities.find(ok);
      if (e) e.mode = 'no'; renderAll();
    });
    await page.click('#btnMake');
    await page.waitForSelector('#result', { state: 'visible', timeout: 60000 });
    const dl = await Promise.all([
      page.waitForEvent('download', { timeout: 30000 }),
      page.click('#btnDownload'),
    ]).then(a => a[0]).catch(() => null);
    if (!dl) { rec(doc, tag, `output ${fmt}`, 'clean', 'no-download', false); return; }
    const fp = path.join(OUT, doc.replace(/[\/\\]/g, '_').replace(/\.\w+$/, `_out.${fmt}`));
    await dl.saveAs(fp);
    const buf = fs.readFileSync(fp);

    if (fmt === 'pdf') {
      const chars = await page.evaluate(async (b64) => {
        const bin = atob(b64); const arr = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
        const pdf = await pdfjsLib.getDocument({ data: arr }).promise;
        let n = 0;
        for (let p = 1; p <= pdf.numPages; p++) { const tc = await (await pdf.getPage(p)).getTextContent(); n += tc.items.reduce((s, it) => s + (it.str || '').replace(/\s/g, '').length, 0); }
        return n;
      }, buf.toString('base64'));
      rec(doc, 'TEXT_LEAK', `output ${fmt}`, '0 chars', `${chars} chars`, chars === 0);
      // One %%EOF means one revision. An incremental save appends a second body
      // + xref + %%EOF, leaving revision 1 (pre-redaction) readable in the file.
      const eofs = (buf.toString('latin1').match(/%%EOF/g) || []).length;
      rec(doc, tag, `output ${fmt} revisions`, '1 %%EOF', `${eofs} %%EOF`, eofs === 1);
    }
    const hits = scanMarkers(buf, fmt);
    rec(doc, tag, `output ${fmt} metadata`, 'none', hits.length ? hits.join('+') : 'none', hits.length === 0);
    if (fmt === 'jpg') { const icc = iccSafe(buf); rec(doc, tag, `output ${fmt} ICC`, `generic <=${ICC_MAX}B`, icc.note, icc.ok); }
  } catch (e) { rec(doc, tag, `output ${fmt}`, 'clean', 'ERR:' + e.message.split('\n')[0], false); }
}

async function checkAiInject(page) {
  const inj = SPECS.ai_inject; if (!inj) return;
  await loadDoc(page, inj._doc, false);
  for (const c of inj.cases) {
    // fresh reload so each case is isolated
    await loadDoc(page, inj._doc, false);
    const res = await page.evaluate((ent) => {
      const before = entities.length;
      addEntities([ent]);
      const added = entities.slice(before);
      const mine = added.find(e => e.value === ent.value) || entities.find(e => e.value === ent.value && e.kind !== 'candidate' && e.type !== 'name-candidate');
      const masked = window.__isMasked(ent.value);
      return { present: !!mine, type: mine ? mine.type : null, mode: mine ? mine.mode : null, masked };
    }, c.entity);
    let pass, actual;
    if (c.expect === 'masked') { pass = res.masked; actual = res.masked ? 'masked' : `not-masked(${res.type}/${res.mode})`; }
    else if (c.expect === 'dropped') { pass = !res.present && !res.masked; actual = res.present ? `KEPT(${res.type}/${res.mode})` : 'dropped'; }
    else { pass = !res.masked; actual = res.masked ? 'MASKED' : `visible(${res.type || 'dropped'}/${res.mode || '-'})`; }
    rec('7_resume_dark.pdf', 'AI_INJECT', c.label + ` [${c.entity.type}:${c.entity.value}]`, c.expect, actual, pass);
  }
}

async function checkAiCatState(page) {
  const cs = SPECS.ai_cat_state; if (!cs) return;
  await loadDoc(page, cs._doc, false);
  const res = await page.evaluate(({ labels, want }) => {
    // record active state BEFORE the AI merge, then inject AI labels
    const before = {}; for (const t of want) before[t] = catEnabled[t] !== false;
    addEntities(labels); renderAll();
    const after = {}, boxChecked = {};
    for (const t of want) {
      after[t] = catEnabled[t] !== false;
      const cb = document.querySelector(`#piiList input[data-cat="${t}"]`);
      boxChecked[t] = cb ? cb.checked : null; // null = row not rendered (still a fail signal)
    }
    return { before, after, boxChecked };
  }, { labels: cs.labels, want: cs.assert_enabled });
  for (const t of cs.assert_enabled) {
    const pass = res.after[t] === true && res.boxChecked[t] === true;
    rec(cs._doc, 'AI_CAT_STATE', `${t} stays enabled`, 'on+checked',
      `enabled=${res.after[t]} checked=${res.boxChecked[t]}`, pass);
  }
}

async function checkCandidateDedup(page) {
  const cd = SPECS.candidate_dedup; if (!cd) return;
  for (const c of cd.cases) {
    await loadDoc(page, cd._doc, false);   // fresh load so the base candidate is present
    const res = await page.evaluate(({ cand, confirm }) => {
      const before = window.__isCandidateContains(cand);
      addEntities([confirm]); renderAll();
      const after = window.__isCandidateContains(cand);
      // Dedup must be directional: it removes redundant CANDIDATES, never the
      // CONFIRMED entity that contains them. A reversed containment test (or a
      // mutual-removal bug) would delete the confirmed name — leaving the value
      // wholly UNMASKED. Assert the confirmed entity is still present after dedup.
      // (Location isn't asserted here: these cases inject a superset value with a
      // token absent from the fixture, so it is intentionally unlocated.)
      const nc = window.__norm(confirm.value);
      const confEnt = window.__entitySnapshot().find(e => e.kind !== 'candidate' && window.__norm(e.value) === nc);
      return { before, after, confirmedSurvives: !!confEnt };
    }, { cand: c.candidate, confirm: c.confirm });
    let pass, actual;
    if (c.expect === 'removed') {
      pass = res.before && !res.after;
      actual = !res.before ? 'not-present-before' : (res.after ? 'STILL present' : 'removed');
    } else { // kept
      pass = res.before && res.after;
      actual = !res.before ? 'not-present-before' : (res.after ? 'kept' : 'DROPPED');
    }
    rec(cd._doc, 'CANDIDATE_DEDUP', `${c.label} [${c.confirm.value}]`, c.expect, actual, pass);
    // Confirmed-preservation guard (the regression the candidate-only test missed):
    // the confirmed entity that triggered the dedup must SURVIVE it.
    rec(cd._doc, 'CONFIRMED_SURVIVES', `confirmed kept [${c.confirm.value}]`, 'survives',
      res.confirmedSurvives ? 'survives' : 'REMOVED', res.confirmedSurvives);
  }
}

/* ── JP golden ───────────────────────────────────────────────────────────────
   Each JP fixture ships its own specs.json with a BOX TABLE in PNG pixel
   coordinates plus, per 提出目的, which boxes must be hidden / recommended /
   optional / kept. The harness replays that table against the live pipeline.

   Coordinate frames: a PNG loads at its natural size, a PDF renders at
   min(2.2, 1500/ptWidth) — so the mapping is a single uniform scale, taken at
   runtime from page.w / fixtureWidth rather than hard-coded. A JPG fixture is
   deliberately rotated and blurred (a phone photo), so its OCR boxes do NOT
   land on the PNG coordinates; those cases assert at FIELD level instead and
   say so, rather than quietly comparing coordinates that cannot match.

   Which assertion a box gets comes from the LEGAL MATRIX level, not from which
   list the fixture put it in — `mask` holds everything the purpose hides, at
   both the automatic and the recommended strength, and those are different
   promises. specs.json carries the key→level mapping (jp_auto_fields) so the
   harness derives it independently of the app it is testing. */
const JP_COVER_MIN = 0.6;      // a band must cover this much of a non-numeric box
const JP_KEEP_MAX = 0.10;      // a keep field may not be grazed by more than this
function jpFieldOf(key) { return key.replace(/^m\d+_/, ''); }
/* Number fields get the per-glyph ink test instead of the area fraction. These
   are the fields whose whole value is a digit string, so a single surviving
   character is a leak — and the area gate cannot see that (Codex 5-3). */
const JP_NUMERIC = new Set(['hokensha_bango', 'kigo', 'bango', 'edaban', 'hihokensha_bango',
  'my_number', 'jumin_code', 'license_no']);
async function jpCheckBox(page, doc, cat, key, rect, kind) {
  const field = jpFieldOf(key);
  const items = await page.evaluate(r => window.__itemsIn(r), rect);
  let frac, what;
  if (items.length) {
    // The meaningful question for a box holding text is whether the TEXT is
    // covered — not whether the generator's padding around it was painted.
    const fr = await Promise.all(items.map(it => page.evaluate(r => window.__coverage(r), it)));
    frac = Math.min(...fr); what = `${items.length} item(s) min ${(frac * 100).toFixed(0)}%`;
  } else {
    frac = await page.evaluate(r => window.__coverage(r), rect); what = `area ${(frac * 100).toFixed(0)}%`;
  }
  if (kind === 'keep') { rec(doc, 'JP_KEEP', key, `<=${JP_KEEP_MAX * 100}%`, what, frac <= JP_KEEP_MAX); return; }
  // Covered? For a number box, "covered" means every ink component is covered.
  let covered = frac >= JP_COVER_MIN, how = what;
  if (JP_NUMERIC.has(field) && (kind === 'mask' || kind === 'candidate' || kind === 'mask_or_candidate')) {
    const ic = await page.evaluate(r => window.__inkCover(r), rect);
    const comps = ic ? ic.components : 0;
    how = ic ? `${comps} comp, worst ${(ic.worst * 100).toFixed(0)}%` : 'no-canvas';
    // Zero components would make this assertion vacuous: a number box has ink.
    covered = comps > 0 && ic.uncovered === 0;
    if (kind === 'mask') { rec(doc, 'JP_INK', key, 'all glyphs covered', comps ? how : 'NO INK FOUND', covered); return; }
  }
  if (kind === 'mask') { rec(doc, 'JP_MASK', key, `>=${JP_COVER_MIN * 100}%`, how, covered); return; }
  const cand = await page.evaluate(r => window.__candidateOver(r), rect);
  if (kind === 'candidate') {
    // A recommend-level candidate is default ON, so it is both surfaced AND
    // banded; a number field has to pass the ink test in that case.
    const banded = frac > JP_KEEP_MAX;
    const ok = cand && (!banded || covered);
    rec(doc, 'JP_CANDIDATE', key, 'surfaced(+covered if banded)',
      cand ? (banded ? (covered ? 'candidate+covered' : 'BANDED BUT LEAKING ' + how) : 'candidate') : 'MISSING', ok); return;
  }
  if (kind === 'mask_or_candidate') {
    rec(doc, 'JP_MASK_OR_CAND', key, 'banded(+covered) or candidate', covered ? 'banded ' + how : cand ? 'candidate' : 'NEITHER ' + how, covered || cand); return;
  }
  if (kind === 'optional') {   // detected, offered, and OFF until the user says so
    rec(doc, 'JP_OPTIONAL', key, 'offered+clear', cand ? (frac <= JP_KEEP_MAX ? 'offered+clear' : 'OFFERED BUT BANDED') : 'MISSING', cand && frac <= JP_KEEP_MAX);
  }
}
async function checkJpDoc(page, spec) {
  const fx = JSON.parse(fs.readFileSync(path.join(__dirname, spec.fixture), 'utf8'));
  const autoFields = (SPECS.jp_auto_fields || {})[spec.expect_doc] || [];
  const mocFields = SPECS.jp_candidate_or_mask || [];
  for (const c of spec.cases) {
    const tag = `${spec.doc} [${c.purpose}${c.label ? ' ' + c.label : ''}]`;
    await loadDoc(page, spec.doc, true);
    await page.evaluate(p => jpSetPurpose(p), c.purpose);
    // Releasing a 個人番号 band needs the purpose AND the confirmation. A case
    // that expects the release has to say so — which is itself the assertion
    // that the dropdown alone does not open the gate (the `confirm_mynumber:
    // false` case below proves the other direction).
    if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
    const st = await page.evaluate(() => window.__jpState());
    if (c.expect_warn != null)
      rec(tag, 'JP_WARN', 'blocking banner', c.expect_warn ? 'shown' : 'absent',
        st.warnShown ? 'shown(' + st.warn + ')' : 'absent', st.warnShown === !!c.expect_warn);
    if (c.confirm_mynumber != null)
      rec(tag, 'JP_MN_BOX', 'confirmation checkbox', 'shown', st.mnBoxShown ? 'shown' : 'ABSENT', st.mnBoxShown);
    rec(tag, 'JP_CLASS', spec.expect_doc + (spec.expect_side ? '/' + spec.expect_side : ''), 'classified',
      st.cls ? st.cls.doc + (st.cls.side ? '/' + st.cls.side : '') + ' sc=' + st.cls.score : 'NOT classified',
      !!st.cls && st.cls.doc === spec.expect_doc && (!spec.expect_side || st.cls.side === spec.expect_side));
    if (!st.cls) continue;
    const autoCount = await page.evaluate(() => entities.filter(e => e.kind === 'auto').length);
    process.stderr.write(`    [jp autoCount] ${tag} = ${autoCount}\n`);
    if (c.min_auto != null) rec(tag, 'REGRESSION', `auto>=${c.min_auto}`, `>=${c.min_auto}`, String(autoCount), autoCount >= c.min_auto);
    if (c.max_auto != null) rec(tag, 'REGRESSION', `auto<=${c.max_auto}`, `<=${c.max_auto}`, String(autoCount), autoCount <= c.max_auto);

    // Field-level: every required field must have been FOUND. This is the only
    // assertion a rotated phone-photo fixture can make, and it is also the one
    // the 미탐 0 gate is actually about.
    const got = new Set(st.fields.map(f => f.field));
    for (const f of (c.require_fields || [])) rec(tag, 'JP_FIELD', f, 'detected', got.has(f) ? 'detected' : 'MISSING', got.has(f));
    // A band is only a band if the entity is located, its category is ON, its
    // mode is not 'ok', AND the rect it paints is in the active mask-rect list.
    for (const f of (c.require_banded || [])) {
      const bs = await page.evaluate(x => window.__fieldBands(x), f);
      const ok = bs.length > 0 && bs.every(b => b.located && b.on && b.mode !== 'ok' && b.inMask);
      const why = !bs.length ? 'MISSING'
        : bs.every(b => b.located && b.on && b.mode !== 'ok' && b.inMask) ? `banded ×${bs.length}`
        : bs.map(b => !b.located ? 'NOT LOCATED' : !b.on ? 'CATEGORY OFF' : b.mode === 'ok' ? 'CLEAR' : 'NOT IN MASKRECTS').join('/');
      rec(tag, 'JP_BANDED', f, 'located+on+in-maskrects', why, ok);
    }
    // The inverse of require_banded, and the half that makes a purpose-gate test
    // mean something: without it, "banded under 相談用共有" could be true simply
    // because the field is banded under every purpose. Also asserts the rect is
    // absent from the mask list, not merely that the mode string says 'ok'.
    for (const f of (c.require_clear || [])) {
      const bs = await page.evaluate(x => window.__fieldBands(x), f);
      const clear = bs.length > 0 && bs.every(b => b.mode === 'ok' && !b.inMask);
      rec(tag, 'JP_CLEAR', f, 'detected+clear', !bs.length ? 'MISSING' : (clear ? `detected+clear ×${bs.length}` : 'BANDED'), clear);
    }
    // Legal-preset fields are not governed by the category checkboxes. Turn
    // every category off and require the band to still be there.
    for (const f of (c.require_legal || [])) {
      const left = await page.evaluate(() => window.__allCatsOff());
      const bs = await page.evaluate(x => window.__fieldBands(x), f);
      const ok = left.length === 0 && bs.length > 0 && bs.every(b => b.legal && b.on && b.mode !== 'ok' && b.inMask);
      rec(tag, 'JP_LEGAL', f, 'survives all-categories-off',
        left.length ? 'cats still on: ' + left.join(',') : !bs.length ? 'MISSING'
          : bs.every(b => b.legal && b.on && b.mode !== 'ok' && b.inMask) ? `banded ×${bs.length}` : 'DROPPED', ok);
      // put the page back the way the rest of the case expects it
      const restored = await page.evaluate(() => window.__restoreCats());
      rec(tag, 'JP_LEGAL', f + ' (categories restored)', 'restored', restored ? 'restored' : 'NOT RESTORED', restored, true);
      await loadDoc(page, spec.doc, true);
      await page.evaluate(p => jpSetPurpose(p), c.purpose);
      if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
    }
    // No auto entity outside the allowlist. A ceiling on the COUNT cannot tell
    // "the right five" from "two right and three wrong" (Codex 5-6).
    if (c.auto_allow) {
      const af = await page.evaluate(() => window.__autoFields());
      const bad = af.filter(f => !c.auto_allow.includes(f));
      rec(tag, 'JP_AUTO_SET', 'auto fields ⊆ allowlist', c.auto_allow.join(',') || '(none)',
        bad.length ? 'UNEXPECTED: ' + [...new Set(bad)].join(',') : (af.length ? [...new Set(af)].join(',') : '(none)'), bad.length === 0);
    }
    if (spec.geometry === false || c.geometry === false) continue;

    const P = fx.purposes[c.key];
    if (!P) { rec(tag, 'JP_SPEC', c.key, 'purpose in fixture', 'MISSING', false); continue; }
    const scale = st.pw[0] / fx.size[0];
    let checked = 0;
    const box = k => { const b = fx.boxes_png[k]; return b && { pi: 0, x: b[0] * scale, y: b[1] * scale, w: (b[2] - b[0]) * scale, h: (b[3] - b[1]) * scale }; };
    const seen = new Set();
    const run = async (keys, kindFor) => {
      for (const k of (keys || [])) {
        if (k === 'ALL' || seen.has(k)) continue;
        const r = box(k);
        // An expectation naming a box this variant does not have is a FAULT in
        // the expectation table, not a case to skip. It used to be "reported as
        // skipped", which is a line of text nobody reads next to a green total
        // (Codex 5-5). The variant tables are pruned at generation time now, so
        // a missing key means the table and the fixture went out of sync.
        if (!r) { rec(tag, 'JP_SPEC', k, 'box exists in fixture', 'NO SUCH BOX', false); continue; }
        seen.add(k);
        await jpCheckBox(page, tag, null, k, r, kindFor(k));
        checked++;
      }
    };
    // whole-face rule (マイナカード裏面 under a 本人確認 purpose)
    if ((P.mask || []).includes('ALL')) {
      const pg = await page.evaluate(() => ({ pi: 0, x: 0, y: 0, w: pages[0].w, h: pages[0].h }));
      await jpCheckBox(page, tag, null, 'ALL(face)', pg, 'mask');
      checked++;
      for (const k of Object.keys(fx.boxes_png)) { const r = box(k); if (r) { await jpCheckBox(page, tag, null, k, r, 'mask'); checked++; } }
      seen.add('ALL');
    }
    await run(P.mask, k => mocFields.includes(jpFieldOf(k)) ? 'mask_or_candidate'
                        : autoFields.includes(jpFieldOf(k)) ? 'mask' : 'candidate');
    await run(P.recommend, () => 'candidate');
    await run(P.optional, () => 'optional');
    // `keep: "all"` means every box on the page is a keep field. Turning that
    // into an empty list made the strongest promise in the table the only one
    // nobody checked (Codex 5-5) — enumerate the box table instead.
    await run(P.keep === 'all' ? Object.keys(fx.boxes_png) : P.keep, () => 'keep');
    rec(tag, 'JP_COVERAGE', 'boxes checked', `>=${c.min_boxes || 1}`, String(checked), checked >= (c.min_boxes || 1));
    for (const fmt of (c.out_formats || [])) await checkOutput(page, tag, fmt);
  }
}

/* ── JP unit rules ──────────────────────────────────────────────────────────
   Two detection rules cannot be exercised by the alpha fixtures: none of the
   four documents carries a phone number, and on all four the 住所 is a KEEP
   field, so the address hierarchy's own scoring never decides anything there.
   Shipping them with no coverage at all would be shipping untested detection,
   so they are pinned at unit level against crafted strings — stated as such
   rather than left to look like fixture coverage. */
async function checkJpUnits(page) {
  const U = SPECS.jp_units; if (!U) return;
  for (const c of (U.address || [])) {
    const got = await page.evaluate(t => {
      const sp = jpAddressSpan(t, 0);
      return sp ? { span: t.slice(sp.a, sp.b), score: sp.score, strong: !!(sp.postal && sp.pref) } : null;
    }, c.text);
    const ok = c.expect === null ? (got === null || got.score < 3)
      : !!got && got.span === c.expect.span && got.score === c.expect.score && got.strong === !!c.expect.strong;
    rec('(jp units)', 'JP_ADDRESS', c.label, c.expect === null ? 'no address' : `${c.expect.span} s=${c.expect.score}${c.expect.strong ? ' strong' : ''}`,
      got ? `${got.span} s=${got.score}${got.strong ? ' strong' : ''}` : 'none', ok);
  }
  for (const c of (U.tel || [])) {
    const got = await page.evaluate(t => {
      const hy = JP_TEL_HYPHEN_RE.exec(t), pl = hy ? null : JP_TEL_PLAIN_RE.exec(t);
      const m = hy || pl; return m ? { v: m[0], loose: !hy } : null;
    }, c.text);
    const ok = c.expect === null ? got === null
      : !!got && got.v === c.expect.v && got.loose === !!c.expect.loose;
    rec('(jp units)', 'JP_TEL', c.label, c.expect === null ? 'no match' : `${c.expect.v}${c.expect.loose ? ' (candidate)' : ''}`,
      got ? `${got.v}${got.loose ? ' (candidate)' : ''}` : 'none', ok);
  }
}

/* ── legal matrix ↔ code (check_matrix.mjs) ────────────────────────────────── */
function checkMatrix() {
  const r = spawnSync(process.execPath, [path.join(__dirname, 'check_matrix.mjs')], { encoding: 'utf8' });
  const out = ((r.stdout || '') + (r.stderr || '')).trim().split('\n').filter(Boolean);
  rec('(legal matrix)', 'JP_MATRIX', 'JP_RULES == jp_legal_matrix_alpha4.json', 'identical',
    r.status === 0 ? out[out.length - 1].replace(/^✅ legal matrix ↔ code: /, '') : `${out.length - 1} disagreement(s)`, r.status === 0);
  if (r.status !== 0) for (const l of out.slice(1, 9)) rec('(legal matrix)', 'JP_MATRIX', l.trim().slice(0, 38), '-', 'mismatch', false, true);
}

/* ── multi-page: the rule follows the PAGE, not page 1 ──────────────────────
   A two-sided card scanned into one PDF. The old code read page 1's class and
   applied it to every page, so the outcome depended on scan order: front-then-
   back left the 個人番号 page untouched, back-then-front put a full-face band
   over the front as well (Codex 6-4). Both orders are built here from the
   committed single-page PNGs — written under out/gen, not committed, so the
   repo gains no new card binaries. */
async function buildPdfFromImages(page, srcs, outPath) {
  const b64 = await page.evaluate(async (urls) => {
    const { jsPDF } = await ensureJsPDF();
    let pdf = null;
    for (const u of urls) {
      const im = await new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = u; });
      const cv = document.createElement('canvas'); cv.width = im.width; cv.height = im.height;
      cv.getContext('2d').drawImage(im, 0, 0);
      const data = cv.toDataURL('image/jpeg', 0.95);
      if (!pdf) pdf = new jsPDF({ unit: 'pt', format: [im.width, im.height], compress: true });
      else pdf.addPage([im.width, im.height]);
      pdf.addImage(data, 'JPEG', 0, 0, im.width, im.height);
    }
    return pdf.output('datauristring').split(',')[1];
  }, srcs);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, Buffer.from(b64, 'base64'));
}
async function checkJpMultiPage(page, port) {
  const B = `http://127.0.0.1:${port}/__fx/jp/mynumber_card`;
  const cases = [
    { label: '表→裏', srcs: [`${B}/front.png`, `${B}/back.png`], backPage: 1, frontPage: 0, file: 'gen/mn_front_back.pdf' },
    { label: '裏→表', srcs: [`${B}/back.png`, `${B}/front.png`], backPage: 0, frontPage: 1, file: 'gen/mn_back_front.pdf' },
  ];
  for (const c of cases) {
    const tag = `jp/2page ${c.label}`;
    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
    try {
      await buildPdfFromImages(page, c.srcs, path.join(OUT, c.file));
      await loadDoc(page, c.file, true);
      await page.evaluate(() => jpSetPurpose('identity_submit'));
      const st = await page.evaluate(() => window.__jpState());
      const sides = st.pageCls.map(x => x ? (x.doc + '/' + (x.side || '-')) : 'null');
      const wantSides = []; wantSides[c.backPage] = 'mynumber_card/back'; wantSides[c.frontPage] = 'mynumber_card/front';
      rec(tag, 'JP_PAGECLASS', 'per-page doc/side', wantSides.join(' + '), sides.join(' + '),
        sides.length === 2 && sides[c.backPage] === wantSides[c.backPage] && sides[c.frontPage] === wantSides[c.frontPage]);
      // The whole-face band exists on the BACK page and only there.
      const bs = await page.evaluate(() => window.__fieldBands('back_all'));
      const pagesWithBand = bs.filter(b => b.mode !== 'ok' && b.inMask).map(b => b.page);
      rec(tag, 'JP_BACK_ONLY', 'back_all pages', `[${c.backPage}]`, `[${pagesWithBand.join(',')}]`,
        pagesWithBand.length === 1 && pagesWithBand[0] === c.backPage);
      // And geometrically: the back page is covered, the front page is not.
      const cov = await page.evaluate(() => pages.map((p, pi) => window.__coverage({ pi, x: 0, y: 0, w: p.w, h: p.h })));
      rec(tag, 'JP_BACK_COVER', `page ${c.backPage} covered`, '>=99%', `${(cov[c.backPage] * 100).toFixed(0)}%`, cov[c.backPage] >= 0.99);
      rec(tag, 'JP_FRONT_CLEAR', `page ${c.frontPage} not full-face`, '<=60%', `${(cov[c.frontPage] * 100).toFixed(0)}%`, cov[c.frontPage] <= 0.6);
    } catch (e) { rec(tag, 'LOAD', c.file, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
  }
}

/* ── 個人番号 check digit ───────────────────────────────────────────────────
   Two layers. The vectors pin the arithmetic of 省令第5条 (including the two
   remainder cases the 省令 folds to 0). The synthesis then drives a VALID
   number through the real pipeline — classification, label anchor, digit span,
   check digit, purpose gate — on a page built by the app's own text renderer.
   The alpha card dummies all carry invalid numbers on purpose (strategy v2 §4
   forbids generating a valid one into a card image), so until now nothing
   exercised the `checkOk: true` branch at all (Codex 5-2): a correct number
   would have taken a path the golden had never run. The valid numbers live in
   TEXT only, never in a committed image. */
async function checkJpMyNumber(page) {
  const U = SPECS.jp_my_number; if (!U) return;
  for (const c of (U.vectors || [])) {
    const got = await page.evaluate(v => myNumberCheckOk(v), c.n);
    rec('(jp units)', 'JP_MYNUM_CD', `${c.label} ${c.n}`, String(c.ok), String(got), got === c.ok);
  }
  for (const c of (U.synth || [])) {
    const tag = '(jp synth)';
    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
    await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
    await page.evaluate(t => loadFromText(t, 'synth.txt'), c.text);
    await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0, { timeout: 40000 });
    await page.evaluate(PAGE_HELPERS);
    await page.evaluate(p => jpSetPurpose(p), c.purpose);
    if (c.confirm_mynumber) await page.evaluate(() => window.__setMnConfirm(true));
    const st = await page.evaluate(() => window.__jpState());
    rec(tag, 'JP_CLASS', c.label, c.expect_doc, st.cls ? st.cls.doc : 'NOT classified', !!st.cls && st.cls.doc === c.expect_doc);
    const bs = await page.evaluate(() => window.__fieldBands('my_number'));
    const lv = bs.map(b => b.level + (b.note ? '/' + b.note : '')).join(',') || 'MISSING';
    rec(tag, 'JP_MYNUM_LEVEL', c.label, c.expect_level, lv, bs.length > 0 && bs.every(b => b.level === c.expect_level));
    // A valid number must NOT carry the check-digit demotion note.
    rec(tag, 'JP_MYNUM_NOTE', c.label + ' note', c.expect_note || '(none)',
      bs.length ? (bs[0].note || '(none)') : 'MISSING', bs.length > 0 && (bs[0].note || null) === (c.expect_note || null));
    const banded = bs.length > 0 && bs.every(b => b.mode !== 'ok' && b.inMask);
    rec(tag, 'JP_MYNUM_BAND', c.label + ' band', c.expect_banded ? 'banded' : 'clear',
      banded ? 'banded' : 'clear', banded === !!c.expect_banded);
    if (c.expect_banded) {
      const masked = await page.evaluate(v => window.__isMasked(v), c.number);
      rec(tag, 'JP_MYNUM_GEOM', c.label + ' value covered', 'masked', masked ? 'masked' : 'NOT masked', masked);
    }
    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
  }
}

/* ── unlabelled square block: offered, never banded by default ──────────────
   The pixel detector for an unlabelled block has no golden coverage (the alpha
   dummies carry no real QR — strategy v2 §4), and it can fire on a face photo,
   a round seal (bbox fill ≈ 0.785) or a black table header. So the POLICY is
   what gets pinned here: a finding flagged `unlabelledCode` comes out of
   jpApply as `optional` / mode 'ok' / not in the mask list, even on a document
   whose labelled 二次元コード is an automatic band. The finding is injected —
   this tests the decision, not the detector, and says so. */
async function checkJpUnlabelled(page) {
  const U = SPECS.jp_unlabelled_block; if (!U) return;
  const tag = '(jp unlabelled)';
  await page.evaluate(() => { LANG = 'ja'; applyLang(); });
  await loadDoc(page, U._doc, true);
  await page.evaluate(p => jpSetPurpose(p), U.purpose);
  const res = await page.evaluate(() => {
    // A square where nothing on the page is a code: top-left corner of the page.
    const r = { page: 0, x: 40, y: 40, w: 120, h: 120, region: true };
    jpState.findings.push({ field: 'qr', boxes: [r], value: '二次元コード', pi: 0,
      doc: jpState.cls.doc, side: jpState.cls.side || null, low: false, unlabelledCode: true });
    jpApply();
    const inj = entities.find(e => e.jp && e.jp.note === 'unlabelled_code');
    return { present: !!inj, level: inj && inj.jp.level, mode: inj && inj.mode, kind: inj && inj.kind,
      covered: window.__coverage({ pi: 0, x: 40, y: 40, w: 120, h: 120 }),
      labelledBanded: window.__fieldBands('qr').filter(b => b.note !== 'unlabelled_code').every(b => b.mode !== 'ok' && b.inMask) };
  });
  rec(tag, 'JP_UNLABELLED', 'level', 'optional', res.present ? res.level : 'MISSING', res.level === 'optional');
  rec(tag, 'JP_UNLABELLED', 'default mode', 'ok', res.present ? res.mode : 'MISSING', res.mode === 'ok');
  rec(tag, 'JP_UNLABELLED', 'not in default output', '0% covered', `${(res.covered * 100).toFixed(0)}%`, res.covered <= 0.10);
  // …and the LABELLED code on the same page is still banded, so the assertion
  // above is not passing merely because nothing is banded at all.
  rec(tag, 'JP_UNLABELLED', 'labelled code still banded', 'banded', res.labelledBanded ? 'banded' : 'CLEAR', res.labelledBanded);
  await page.evaluate(() => { LANG = 'ko'; applyLang(); });
}

/* ── classification failure must be visible ─────────────────────────────────
   A page that says 資格確認書 and nothing else reaches 3 of the 4 points it
   needs. The old build dropped the entire Japanese preset and fell through to
   the Latin name/address heuristics without a word (Codex 1-1). */
async function checkJpWarn(page) {
  const W = SPECS.jp_warn; if (!W) return;
  for (const c of W.cases) {
    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
    await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
    await page.evaluate(t => loadFromText(t, 'warn.txt'), c.text);
    await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0, { timeout: 40000 });
    await page.evaluate(PAGE_HELPERS);
    const st = await page.evaluate(() => window.__jpState());
    rec('(jp warn)', 'JP_WARN', c.label, c.expect_warn ? `shown/${c.expect_warn}` : 'absent',
      st.warnShown ? `shown/${st.warn}` : 'absent',
      st.warnShown === !!c.expect_warn && (!c.expect_warn || st.warn === c.expect_warn));
    rec('(jp warn)', 'JP_WARN_CLASS', c.label + ' class', c.expect_doc || 'null',
      st.cls ? st.cls.doc + (st.cls.low ? '(low)' : '') : 'null',
      (st.cls ? st.cls.doc : null) === (c.expect_doc || null) && (!c.expect_doc || !!st.cls.low === !!c.expect_low));
    // A low-confidence class may not produce an automatic band.
    if (c.expect_low) {
      const af = await page.evaluate(() => window.__autoFields());
      const jpAuto = af.filter(f => !f.startsWith('(regex:'));
      rec('(jp warn)', 'JP_WARN_NOAUTO', c.label + ' no jp auto', '(none)',
        jpAuto.length ? jpAuto.join(',') : '(none)', jpAuto.length === 0);
    }
    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
  }
}

function printTable() {
  const pad = (s, n) => { s = String(s); return s.length > n ? s.slice(0, n - 1) + '…' : s.padEnd(n); };
  let lastDoc = '';
  console.log('\n' + '═'.repeat(120));
  console.log(pad('DOC', 20) + pad('CATEGORY', 17) + pad('ITEM', 40) + pad('EXPECTED', 18) + pad('ACTUAL', 18) + 'RESULT');
  console.log('─'.repeat(120));
  for (const r of rows) {
    if (r.doc !== lastDoc) { console.log('─'.repeat(120)); lastDoc = r.doc; }
    const mark = r.info ? (r.pass ? 'ℹ ok' : 'ℹ note') : (r.pass ? '✅ PASS' : '❌ FAIL');
    console.log(pad(r.doc, 20) + pad(r.cat, 17) + pad(r.item, 40) + pad(r.expected, 18) + pad(r.actual, 18) + mark);
  }
  console.log('═'.repeat(120));
  const gating = rows.filter(r => !r.info);
  const fails = gating.filter(r => !r.pass);
  const byCat = {};
  for (const r of gating) { byCat[r.cat] = byCat[r.cat] || { p: 0, f: 0 }; r.pass ? byCat[r.cat].p++ : byCat[r.cat].f++; }
  console.log('\nSummary by category:');
  for (const [c, v] of Object.entries(byCat)) console.log(`  ${pad(c, 18)} ${v.p} pass / ${v.f} fail`);
  console.log(`\n  TOTAL: ${gating.length - fails.length}/${gating.length} pass, ${fails.length} FAIL`);
  if (fails.length) {
    console.log('\n  Failing:');
    for (const r of fails) console.log(`    ✗ [${r.doc}] ${r.cat} — ${r.item}  (expected ${r.expected}, got ${r.actual})`);
  }
  return fails.length;
}

(async () => {
  const srv = await startServer();
  const port = srv.address().port;
  const URL = `http://127.0.0.1:${port}/safe/index.html`;
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const ctx = await browser.newContext({ acceptDownloads: true, locale: 'ko-KR', viewport: { width: 1200, height: 900 } });
  const page = await ctx.newPage();
  const consoleErrors = [];
  page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
  page.on('pageerror', e => consoleErrors.push('PageError: ' + e.message));
  await page.goto(URL, { waitUntil: 'networkidle' });
  await page.evaluate(() => { LANG = 'ko'; applyLang(); });

  const docs = SPECS.docs.filter(d => !onlyArg || d.doc === onlyArg);
  for (const spec of docs) {
    process.stderr.write(`… ${spec.doc}\n`);
    try { await checkDoc(page, spec); }
    catch (e) { rec(spec.doc, 'LOAD', spec.doc, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
  }
  for (const spec of (SPECS.jp_docs || [])) {
    if (onlyArg && spec.doc !== onlyArg) continue;
    process.stderr.write(`… ${spec.doc}\n`);
    // The JP presets only exist in the Japanese UI, and OCR language follows it.
    await page.evaluate(() => { LANG = 'ja'; applyLang(); });
    try { await checkJpDoc(page, spec); }
    catch (e) { rec(spec.doc, 'LOAD', spec.doc, 'loads', 'ERR:' + e.message.split('\n')[0], false); }
    await page.evaluate(() => { LANG = 'ko'; applyLang(); });
  }
  if (!onlyArg) { process.stderr.write('… legal matrix\n'); checkMatrix(); }
  if (!onlyArg || onlyArg === 'jp/2page') { process.stderr.write('… jp multipage\n'); await checkJpMultiPage(page, port); }
  if (!onlyArg || onlyArg === '(jp units)') { process.stderr.write('… jp units\n'); await checkJpUnits(page); }
  if (!onlyArg || onlyArg === '(jp synth)') { process.stderr.write('… jp my_number\n'); await checkJpMyNumber(page); }
  if (!onlyArg || onlyArg === '(jp unlabelled)') { process.stderr.write('… jp unlabelled block\n'); await checkJpUnlabelled(page); }
  if (!onlyArg || onlyArg === '(jp warn)') { process.stderr.write('… jp classification warning\n'); await checkJpWarn(page); }
  if (!onlyArg || onlyArg === '7_resume_dark.pdf') { process.stderr.write('… ai_inject\n'); await checkAiInject(page); }
  if (!onlyArg || onlyArg === '7_resume_dark.pdf') { process.stderr.write('… ai_cat_state\n'); await checkAiCatState(page); }
  if (!onlyArg || onlyArg === (SPECS.candidate_dedup && SPECS.candidate_dedup._doc)) { process.stderr.write('… candidate_dedup\n'); await checkCandidateDedup(page); }

  const failCount = printTable();
  if (consoleErrors.length) { console.log('\n  ⚠ console errors:'); consoleErrors.slice(0, 10).forEach(e => console.log('    ' + e)); }
  fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify({ rows, consoleErrors }, null, 2));

  await browser.close(); srv.close();
  process.exit(failCount ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });
