#!/usr/bin/env node
/*
 * SafeFile JP — what make_thumbnail.mjs cannot tell you about a cover.
 *
 *   node scripts/content/check_thumbnails.mjs 1 2 3 4 5 6 7 8
 *   node scripts/content/check_thumbnails.mjs            # every ep that has a thumb_ja.json
 *
 * Reports, per Shorts variant:
 *   fit %   · how far fitToBox had to shrink
 *   slack   · 1280 − the bottom of the lowest painted text box
 *   WRAP    · a headline line or step label that broke mid-word
 *
 * ── Why this exists ────────────────────────────────────────────────────────
 *
 * make_thumbnail.mjs measures OVERFLOW — text crossing the safe-area line —
 * and exits 1 on it. It does not measure WRAPPING, and the two are different
 * failures with the same cause (a line too wide for the card):
 *
 *   too wide + no room to wrap  → overflows  → caught, exit 1
 *   too wide + room to wrap     → wraps      → NOT caught, exit 0
 *
 * A wrapped headline does not stick out of anything, so the geometry check
 * passes and a cover ships with a word broken across two lines. steps.html's
 * own comment says a label broken mid-word is slower to read than no label —
 * and on 2026-11-22 this shipped past the generator three times in one session
 * (ep03 ①②, then ep06 a / ep07 b / ep08 b).
 *
 * `slack` is here for the other half of the problem. #safe's clientHeight IS
 * the 1280px safe limit, so a full frame lands ON the line and whether it
 * trips is decided by sub-pixels — ep01 a/b and ep03 a pass with 0.94px to
 * spare. The generator's yes/no hides how close it was, and because shortening
 * text makes fitToBox scale UP, the next edit can push a passing variant over.
 * A number lets you see that coming.
 *
 * ── The measured limits (2026-11-22, this exact Chrome) ────────────────────
 *
 *   headline line : 8 glyphs at 100% fit. 112px × letter-spacing -0.02em
 *                   ≈ 109.8px per glyph; the card gives 1080 − 96×2 = 888px.
 *                   8 → 878px fits, 9 → 988px wraps. (A smaller fit % buys
 *                   more glyphs, which is why this is measured and not a
 *                   constant in the spec file.)
 *   step label    : 7 glyphs — three boxes across a 1080px card.
 *
 * Those numbers are NOT enforced here as glyph counts. This renders the real
 * frame and reads the painted boxes, because the limit moves with the fit
 * scale and with the frame; a glyph constant would be right until it wasn't.
 *
 * Exit 1 if anything wraps or leaves the safe area. `slack` under 3px is
 * reported but does not fail — it is a warning about the next edit, not a
 * defect in this one.
 *
 * Requires: node + playwright with the `chrome` channel (the golden harness's
 * install, borrowed rather than duplicated — same as make_thumbnail.mjs).
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, '..', '..');
const CONTENT = path.join(REPO, 'content', 'jp');
const TPL_DIR = path.join(__dirname, 'templates', 'thumbnail');

const FRAME_FOR_INTENT = { '理由': 'warn.html', '手順': 'steps.html', '比較': 'versus.html' };
const SAFE_H = 1280;
const SLACK_WARN_PX = 3;

const { RULES } = await import(pathToFileURL(path.join(__dirname, 'guard_rules.mjs')).href);
const plan = JSON.parse(fs.readFileSync(path.join(CONTENT, 'topics.json'), 'utf8'));

/* The app's own Japanese field labels — resolved the same way make_thumbnail
 * does, so an unknown key fails here too rather than printing a key name. */
function appFieldLabels() {
  const page = fs.readFileSync(path.join(REPO, 'public', 'safe', 'index.html'), 'utf8');
  const hits = [ ...page.matchAll(/^[ \t]*(ko|en|ja|es)\s*:\s*\{/gm) ].map((m) => ({ loc: m[1], at: m.index }));
  const ja = hits.find((h) => h.loc === 'ja');
  if (!ja) throw new Error('public/safe/index.html has no top-level `ja:` locale block');
  const next = hits.find((h) => h.at > ja.at);
  const block = page.slice(ja.at, next ? next.at : page.length);
  const at = block.indexOf('jpFields:{');
  if (at === -1) throw new Error('the ja dictionary has no jpFields');
  let depth = 0, i = at + 'jpFields:'.length; const open = i;
  for (; i < block.length; i++) {
    if (block[i] === '{') depth++;
    else if (block[i] === '}') { depth--; if (depth === 0) { i++; break; } }
  }
  // eslint-disable-next-line no-new-func
  return new Function(`return (${block.slice(open, i)});`)();
}
const DICT = appFieldLabels();

async function loadPlaywright() {
  const pick = (m) => (m && m.chromium) ? m : (m && m.default) || {};
  try { const m = pick(await import('playwright')); if (m.chromium) return m; } catch { /* next */ }
  const local = path.join(REPO, 'test', 'safe', 'node_modules', 'playwright', 'index.js');
  if (fs.existsSync(local)) { const m = pick(await import(pathToFileURL(local).href)); if (m.chromium) return m; }
  throw new Error('playwright not found. Install it where the golden harness lives:\n'
    + '  cd test/safe && npm i && npx playwright install chrome');
}

let eps = process.argv.slice(2).filter((a) => /^\d+$/.test(a)).map(Number);
if (!eps.length) {
  eps = plan.episodes
    .filter((e) => fs.existsSync(path.join(CONTENT, 'ep' + String(e.ep).padStart(2, '0'), 'thumb_ja.json')))
    .map((e) => e.ep);
}
if (!eps.length) { console.error('no episode has a thumb_ja.json yet'); process.exit(2); }

const { chromium } = await loadPlaywright();
const browser = await chromium.launch({ channel: 'chrome' });

const problems = [];
let checked = 0, tight = 0;
try {
  for (const ep of eps) {
    const epp = String(ep).padStart(2, '0');
    const specPath = path.join(CONTENT, `ep${epp}`, 'thumb_ja.json');
    if (!fs.existsSync(specPath)) { console.log(`ep${epp}  (no thumb_ja.json)`); continue; }
    const spec = JSON.parse(fs.readFileSync(specPath, 'utf8'));
    const topic = plan.episodes.find((e) => e.ep === ep);
    if (!topic) { problems.push(`ep${epp} is not in topics.json`); continue; }
    const frame = FRAME_FOR_INTENT[topic.intent];
    if (!frame) { problems.push(`ep${epp}: intent "${topic.intent}" has no frame`); continue; }

    const rows = (spec.rows || []).map((r) => {
      const label = DICT[r.field];
      if (!label) problems.push(`ep${epp}: field "${r.field}" is not in the app's ja jpFields`);
      return { label: label || r.field, value: String(r.value ?? ''), masked: r.masked !== false, focus: !!r.focus };
    });

    const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
    await page.goto(pathToFileURL(path.join(TPL_DIR, frame)).href);
    await Promise.race([ page.evaluate(() => document.fonts.ready), page.waitForTimeout(6000) ]);

    for (const [ i, letter ] of [ 'a', 'b' ].entries()) {
      const v = (spec.variants || [])[i];
      if (!v) continue;
      const fit = await page.evaluate((s) => window.SF_THUMB(s), {
        size: 'short', badge: `第${epp}回`,
        headline: (v.headline || []).slice(0, 2),
        accent: Number.isInteger(v.accent) ? v.accent : 0,
        redLine: Number.isInteger(v.red_line) ? v.red_line : -1,
        doc: { title: spec.doc_title || '', rows },
        note: RULES.mustSentence,
        tag: v.tag || '', leak: v.leak || '',
        steps: v.steps || spec.steps || [], versus: v.versus || spec.versus || []
      });

      const m = await page.evaluate((safeH) => {
        const card = document.getElementById('card').getBoundingClientRect();
        const safe = document.getElementById('safe');
        const painted = [ ...safe.querySelectorAll(
          '.head,.head .l,.note,.doc .lbl,.doc .val,.doc .dt,.badge,.brand,'
          + '.steps .n,.steps .t,.vs .col,.vs .txt,.vs .res,.warnbar,.leak') ]
          .filter((n) => n.textContent.trim());
        const lowest = Math.max(...painted.map((n) => n.getBoundingClientRect().bottom - card.top));
        /* Wrapping is measured as painted height ÷ line height. Counting
         * glyphs would re-derive the limit from a constant, and the limit
         * moves with the fit scale. */
        const wrap = [];
        for (const n of safe.querySelectorAll('.steps .t,.head .l,.vs .txt,.vs .res')) {
          const lh = parseFloat(getComputedStyle(n).lineHeight)
                  || parseFloat(getComputedStyle(n.parentNode).lineHeight);
          const lines = Math.round(n.getBoundingClientRect().height / lh);
          if (lines > 1) wrap.push({ text: n.textContent.trim(), lines, what: n.className || n.tagName });
        }
        return { slack: +(safeH - lowest).toFixed(2), wrap };
      }, SAFE_H);

      checked++;
      const where = `ep${epp} ${letter}`;
      for (const o of fit.outside) problems.push(`${where}: 「${o.text}」 (${o.what}) leaves the safe area — ${o.over}`);
      for (const w of m.wrap) {
        problems.push(`${where}: 「${w.text}」 (${w.what}) wrapped to ${w.lines} lines — a word broken across lines `
          + 'is slower to read than no label, and the generator does not catch this');
      }
      if (m.slack < SLACK_WARN_PX) tight++;

      const flag = fit.outside.length ? '🔴 OUT' : (m.wrap.length ? '🔴 WRAP' : (m.slack < SLACK_WARN_PX ? '⚠️ tight' : 'ok'));
      process.stdout.write(`${where}  ${frame.padEnd(11)} fit ${String(Math.round(fit.scale * 100)).padStart(3)}%`
        + `  slack ${String(m.slack).padStart(7)}px  ${flag}`
        + (m.wrap.length ? `  ${m.wrap.map((w) => `「${w.text}」→${w.lines}`).join(' ')}` : '') + '\n');
    }
    await page.close();
  }
} finally {
  await browser.close();
}

process.stdout.write(`\n${checked} variant(s) checked · ${problems.length} problem(s) · ${tight} with <${SLACK_WARN_PX}px slack\n`);
if (tight) {
  process.stdout.write('\n⚠️ 「tight」 is not a defect in this build — it means the frame is sitting on the\n'
    + '   safe-area line and the next wording edit can push it over. Note that making a\n'
    + '   line SHORTER makes fitToBox scale UP, so trimming text is not the fix.\n');
}
if (problems.length) {
  console.error('\n🔴 problems:');
  problems.forEach((p) => console.error('  - ' + p));
  process.exitCode = 1;
}
