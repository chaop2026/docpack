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
 *   - PHONE_FORMAT   : partial mask preserves the original string format
 *   - AI_INJECT      : adversarial AI labels are neutralised in addEntities
 *   - TEXT_LEAK      : output PDF has 0 extractable characters
 *
 * Requires: node, playwright (chrome channel). Fixtures from generate_fixtures.py.
 * Usage: node run.mjs [--only 7_resume_dark.pdf]  (exit 0 = all pass)
 */
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, '..', '..');
const PUBLIC = path.join(REPO, 'public');
const DOCS = path.join(__dirname, 'testdocs');
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
      const fp = path.join(PUBLIC, p);
      if (!fp.startsWith(PUBLIC) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end('nf'); return; }
      res.writeHead(200, { 'content-type': MIME[path.extname(fp)] || 'application/octet-stream' });
      fs.createReadStream(fp).pipe(res);
    });
    srv.listen(0, '127.0.0.1', () => resolve(srv));
  });
}

// ── in-page helpers, serialised into the browser context ──
const PAGE_HELPERS = () => {
  // active mask rects: every entity that is ON, not 'ok', and located.
  window.__maskRects = function () {
    const rects = [];
    for (const e of entities) {
      if (!isOn(e) || e.mode === 'ok' || !(e.boxes && e.boxes.length)) continue;
      for (let pi = 0; pi < pages.length; pi++) {
        for (const l of mergeLineBoxes(e.boxes, pi)) rects.push({ pi, x: l.x, y: l.y, w: l.w, h: l.h });
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
  window.__isCandidateExact = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value) === n); };
  window.__isCandidateContains = function (v) { const n = norm(v); return entities.some(e => e.kind === 'candidate' && norm(e.value).includes(n)); };
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
    // replicate the drawn-bar geometry: the large-name path uses barRect() if the
    // page defines it, otherwise the raw merged box.
    const drawn = (typeof largeBarRect === 'function') ? largeBarRect(bar) : bar;
    // Ink safety: the bar must cover the full glyph WIDTH and, vertically, the
    // cap-height→descent band (raw pdf font box minus the top ascent gap where
    // no ink lives). It should NOT need to cover the empty ascent whitespace.
    const inkTop = gy0 + gH * 0.18, inkBot = gy1;
    const coversInk = drawn.x <= gx0 + 1 && drawn.x + drawn.w >= gx1 - 1 && drawn.y <= inkTop + 1 && drawn.y + drawn.h >= inkBot - 1;
    return { barW: bar.w, barH: bar.h, drawnH: drawn.h, drawnW: drawn.w, glyphW: gW, glyphH: gH, containsGlyph: coversInk };
  };
};

async function loadDoc(page, file, ocr) {
  await page.evaluate(() => { if (typeof pages !== 'undefined' && pages.length) resetAll(); });
  await page.setInputFiles('#fileInput', path.join(DOCS, file));
  await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0, { timeout: ocr ? 240000 : 40000 });
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
    const isCand = await page.evaluate(x => window.__isCandidateContains(x), v);
    const masked = await page.evaluate(x => window.__isMasked(x), v);
    rec(doc, 'SHOULD_CANDIDATE', v, 'candidate', isCand ? (masked ? 'cand+MASKED' : 'candidate') : 'missing', isCand && !masked);
  }
  if (spec.phone_format) {
    for (const [orig, exp] of Object.entries(spec.phone_format)) {
      const got = await page.evaluate(x => maskHalf('phone', x), orig);
      rec(doc, 'PHONE_FORMAT', orig, exp, got, got === exp);
    }
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
  // text-leak on PDF output
  if (spec.type === 'pdf') {
    try {
      await page.evaluate(() => { const r = document.querySelector('input[name=fmt][value="pdf"]'); if (r) r.checked = true; });
      // force at least one masked, located entity so Make is enabled
      await page.evaluate(() => { const e = entities.find(x => isOn(x) && x.boxes && x.boxes.length); if (e) e.mode = 'no'; renderAll(); });
      await page.click('#btnMake');
      await page.waitForSelector('#result', { state: 'visible', timeout: 60000 });
      const dl = await Promise.all([
        page.waitForEvent('download', { timeout: 30000 }),
        page.click('#btnDownload'),
      ]).then(a => a[0]).catch(() => null);
      if (dl) {
        const fp = path.join(OUT, doc.replace(/\.\w+$/, '_out.pdf'));
        await dl.saveAs(fp);
        const b64 = fs.readFileSync(fp).toString('base64');
        const chars = await page.evaluate(async (b64) => {
          const bin = atob(b64); const arr = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
          const pdf = await pdfjsLib.getDocument({ data: arr }).promise;
          let n = 0;
          for (let p = 1; p <= pdf.numPages; p++) { const tc = await (await pdf.getPage(p)).getTextContent(); n += tc.items.reduce((s, it) => s + (it.str || '').replace(/\s/g, '').length, 0); }
          return n;
        }, b64);
        rec(doc, 'TEXT_LEAK', 'output PDF', '0 chars', `${chars} chars`, chars === 0);
      } else rec(doc, 'TEXT_LEAK', 'output PDF', '0 chars', 'no-download', false);
    } catch (e) { rec(doc, 'TEXT_LEAK', 'output PDF', '0 chars', 'ERR:' + e.message.split('\n')[0], false); }
  }
}

async function checkPhoneUnits(page) {
  for (const [orig, exp] of Object.entries(SPECS.phone_format_units || {})) {
    const got = await page.evaluate(x => maskHalf('phone', x), orig);
    rec('(units)', 'PHONE_FORMAT', orig, exp, got, got === exp);
  }
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
  if (!onlyArg || onlyArg === '(units)') await checkPhoneUnits(page);
  if (!onlyArg || onlyArg === '7_resume_dark.pdf') { process.stderr.write('… ai_inject\n'); await checkAiInject(page); }
  if (!onlyArg || onlyArg === '7_resume_dark.pdf') { process.stderr.write('… ai_cat_state\n'); await checkAiCatState(page); }

  const failCount = printTable();
  if (consoleErrors.length) { console.log('\n  ⚠ console errors:'); consoleErrors.slice(0, 10).forEach(e => console.log('    ' + e)); }
  fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify({ rows, consoleErrors }, null, 2));

  await browser.close(); srv.close();
  process.exit(failCount ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });
