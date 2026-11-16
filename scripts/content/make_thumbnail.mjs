#!/usr/bin/env node
/*
 * SafeFile JP thumbnails — one fixed frame per intent, two formats, N variants.
 *
 *   node scripts/content/make_thumbnail.mjs 1
 *   node scripts/content/make_thumbnail.mjs 1 --only=short
 *
 * Input  : content/jp/topics.json          (intent, ep, doc)
 *          content/jp/epNN/thumb_ja.json   (the words — authored, never generated)
 *          public/safe/index.html          (the app's own Japanese field labels)
 *          content/jp/guard_rules.json     (via guard_rules.mjs)
 * Output : content/jp/epNN/thumb_short_a.png  1080×1920   Shorts cover
 *          content/jp/epNN/thumb_short_b.png  1080×1920
 *          content/jp/epNN/thumb_long_a.png   1280×720    long-form
 *          content/jp/epNN/thumb_long_b.png   1280×720
 *          content/jp/epNN/thumb_long_c.png   1280×720
 *          content/jp/epNN/thumbnails.json    the build record
 *
 * ── The frame is NOT chosen here ───────────────────────────────────────────
 *
 * `intent` in topics.json decides it: 理由→warn, 手順→steps, 比較→versus. A
 * script that picked the frame would make every episode a design decision, and
 * then the channel has no frame at all — which is the thing this is for.
 *
 * ── What this script will not do ───────────────────────────────────────────
 *
 * It does not write prose. thumb_ja.json is authored (by a person or by the
 * video-thumbnail agent) and an absent one is an error, not a default: a
 * generated headline would be a headline nobody chose, printed on the one
 * surface whose entire job is to be chosen.
 *
 * Requires: node + playwright with the `chrome` channel — the golden harness's
 * install (test/safe/node_modules), borrowed rather than duplicated.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, '..', '..');
const CONTENT = path.join(REPO, 'content', 'jp');
const TPL_DIR = path.join(__dirname, 'templates', 'thumbnail');
const APP_PAGE = path.join(REPO, 'public', 'safe', 'index.html');

const { RULES, runForbidden, mustLineViolations } =
  await import(pathToFileURL(path.join(__dirname, 'guard_rules.mjs')).href);

/* The frame per intent. Keys are topics.json's own values — a `intent` outside
 * this table is a plan the templates cannot render, and that is an error rather
 * than a fallback: falling back would silently publish the wrong frame. */
const FRAME_FOR_INTENT = { '理由': 'warn.html', '手順': 'steps.html', '比較': 'versus.html' };

/* The two formats, and how many variants each gets.
 *
 * short → 2, because Gate 1 asks a person to pick ONE of two for the Shorts
 * cover (which then becomes the end card). long → 3: the long-form thumbnail
 * is the only one YouTube lets us A/B at all, since Shorts custom thumbnails
 * are a YPP feature we do not have. */
const FORMATS = [
  { size: 'short', letters: [ 'a', 'b' ], px: { w: 1080, h: 1920 } },
  { size: 'long', letters: [ 'a', 'b', 'c' ], px: { w: 1280, h: 720 } }
];

// Two lines, each this many glyphs. Whitespace is not counted: Japanese
// headlines rarely use spaces, and what overflows the band is characters.
const HEADLINE_MAX_GLYPHS = 12;
const HEADLINE_MAX_LINES = 2;

/* ── args ─────────────────────────────────────────────────────────────────── */
const argv = process.argv.slice(2);
const epArg = argv.find((a) => /^\d+$/.test(a));
const only = (argv.find((a) => a.startsWith('--only=')) || '').split('=')[1] || null;
if (!epArg) {
  console.error('usage: node scripts/content/make_thumbnail.mjs <ep> [--only=short|long]');
  process.exit(2);
}
if (only && !FORMATS.some((f) => f.size === only)) {
  console.error(`--only must be one of: ${FORMATS.map((f) => f.size).join(', ')}`);
  process.exit(2);
}
const EP = Number(epArg);
const EPP = String(EP).padStart(2, '0');
const epDir = path.join(CONTENT, 'ep' + EPP);

const die = (code, msg) => { console.error(msg); process.exit(code); };

/* ── plan ─────────────────────────────────────────────────────────────────── */
const plan = JSON.parse(fs.readFileSync(path.join(CONTENT, 'topics.json'), 'utf8'));
const topic = plan.episodes.find((e) => e.ep === EP);
if (!topic) die(2, `ep${EP} is not in content/jp/topics.json`);
if (topic.blocked_until) die(2, `ep${EP} is blocked until ${topic.blocked_until}: ${topic.note || ''}`);

const frame = FRAME_FOR_INTENT[topic.intent];
if (!frame) {
  die(2, `ep${EP}: intent "${topic.intent}" has no frame. Known: ${Object.keys(FRAME_FOR_INTENT).join(' / ')}`);
}

/* ── the words ────────────────────────────────────────────────────────────── */
const specPath = path.join(epDir, 'thumb_ja.json');
if (!fs.existsSync(specPath)) {
  die(2, `${path.relative(REPO, specPath)} does not exist.\n`
    + '  This file is AUTHORED — it holds the headline and the document rows.\n'
    + '  A generated headline is a headline nobody chose. Shape:\n'
    + '  {\n'
    + '    "doc_title": "資格確認書",\n'
    + '    "rows": [{ "field": "hokensha_bango", "value": "01230567", "masked": true, "focus": true }],\n'
    + '    "variants": [{ "headline": ["…", "…"], "accent": 0, "tag": "…", "leak": "…" }]\n'
    + '  }');
}
const authored = JSON.parse(fs.readFileSync(specPath, 'utf8'));
const variants = authored.variants || [];
if (variants.length < 2) {
  die(2, `${path.relative(REPO, specPath)}: ${variants.length} variant(s) — at least 2 are required `
    + '(Gate 1 asks a person to choose, and a choice of one is not a choice)');
}

/* ── the app's own Japanese field labels ──────────────────────────────────── */
/*
 * Field KEYS are what thumb_ja.json names (`hokensha_bango`), and the label
 * printed on the thumbnail is resolved from public/safe/index.html's `ja`
 * dictionary — the same strings the tool shows the user.
 *
 * Why not just write 「保険者番号」 into the JSON: the thumbnail would then be a
 * second, unlinked copy of a vocabulary the app owns. When the app renames a
 * field the thumbnails keep the old word, and nothing says so. Resolving it
 * means an unknown key is a LOUD failure here instead of a key name rendered
 * onto a public image.
 *
 * The `ja` block is located by its own key at the top level of I18N rather
 * than by position — the dictionaries are in ko/en/ja/es order today and
 * reading the third one would survive exactly until someone adds a fifth.
 *
 * ⚠️ The key is matched with a regex that allows any indentation, not with
 * indexOf('\n ja:{'). The first version of this function assumed one leading
 * space because `awk '{print NR": "…}'` had printed ` ja:{` — and the space was
 * the print format's, not the file's. It failed loudly (good) but it failed.
 * Bounding at the NEXT locale key rather than at `es` specifically means a
 * fifth locale inserted after `ja` does not silently widen the block.
 */
function appFieldLabels() {
  const page = fs.readFileSync(APP_PAGE, 'utf8');
  const localeRe = /^[ \t]*(ko|en|ja|es)\s*:\s*\{/gm;
  const hits = [ ...page.matchAll(localeRe) ].map((m) => ({ loc: m[1], at: m.index }));
  const ja = hits.find((h) => h.loc === 'ja');
  if (!ja) throw new Error('public/safe/index.html has no top-level `ja:` locale block');
  const next = hits.find((h) => h.at > ja.at);
  const block = page.slice(ja.at, next ? next.at : page.length);

  const at = block.indexOf('jpFields:{');
  if (at === -1) throw new Error('the ja dictionary has no jpFields');
  // Balance braces from the opening one so a nested object cannot truncate it.
  let depth = 0, i = at + 'jpFields:'.length, open = i;
  for (; i < block.length; i++) {
    if (block[i] === '{') depth++;
    else if (block[i] === '}') { depth--; if (depth === 0) { i++; break; } }
  }
  if (depth !== 0) throw new Error('jpFields braces do not balance');
  const literal = block.slice(open, i);
  // Our own file, read at build time, never user input — the same way
  // test/safe/check_matrix.mjs evaluates JP_RULES out of this page.
  // eslint-disable-next-line no-new-func
  const dict = new Function(`return (${literal});`)();
  if (!dict || typeof dict !== 'object' || !Object.keys(dict).length) {
    throw new Error('jpFields evaluated to nothing');
  }
  return dict;
}

let FIELD_LABELS;
try { FIELD_LABELS = appFieldLabels(); }
catch (e) { die(1, `could not read the app's Japanese field labels: ${e.message}`); }

const rows = (authored.rows || []).map((r) => {
  const label = FIELD_LABELS[r.field];
  if (!label) {
    die(2, `thumb_ja.json: field "${r.field}" is not in the app's ja jpFields dictionary.\n`
      + `  Known keys include: ${Object.keys(FIELD_LABELS).slice(0, 12).join(', ')}, …`);
  }
  return { label, value: String(r.value ?? ''), masked: r.masked !== false, focus: !!r.focus };
});
if (!rows.length) {
  die(2, 'thumb_ja.json: `rows` is empty — the frame needs a document close-up with a covered cell');
}
if (!rows.some((r) => r.masked)) {
  // A document close-up with nothing covered advertises the tool not working,
  // which is the same rule make_episode.mjs applies to the Shorts recording
  // (SHORTS_MIN_MASKED). A thumbnail is seen by strictly more people.
  die(2, 'thumb_ja.json: no row is masked — a close-up where nothing is covered '
    + 'shows the product failing');
}

/* ── headline checks ──────────────────────────────────────────────────────── */
const warnings = [];
function checkHeadline(v, name) {
  const lines = v.headline || [];
  if (!lines.length) die(2, `thumb_ja.json ${name}: headline is empty`);
  if (lines.length > HEADLINE_MAX_LINES) {
    // Reported, not truncated: dropping the third line silently would publish
    // a sentence the author did not write. Same rule as the Shorts title.
    warnings.push(`${name}: headline has ${lines.length} lines — ${HEADLINE_MAX_LINES}行以内`);
  }
  lines.forEach((l, i) => {
    const glyphs = [ ...String(l).replace(/\s/g, '') ].length;
    if (glyphs > HEADLINE_MAX_GLYPHS) {
      warnings.push(`${name}: headline line ${i + 1} is ${glyphs}字 (空白を除く) — ${HEADLINE_MAX_GLYPHS}字以内が望ましい: 「${l}」`);
    }
  });
}
variants.forEach((v, i) => checkHeadline(v, `variants[${i}]`));

/* ── PNG size, read from the file ─────────────────────────────────────────── */
// The IHDR, not what the browser was asked for. Those two can disagree —
// deviceScaleFactor, a CSS edit, a clipped element — and the first place the
// disagreement shows is a cropped upload.
function pngSize(file) {
  const head = Buffer.alloc(24);
  const fd = fs.openSync(file, 'r');
  try { fs.readSync(fd, head, 0, 24, 0); } finally { fs.closeSync(fd); }
  if (head.toString('hex', 0, 8) !== '89504e470d0a1a0a') throw new Error(`${path.basename(file)} is not a PNG`);
  if (head.toString('ascii', 12, 16) !== 'IHDR') throw new Error(`${path.basename(file)} has no IHDR`);
  return { width: head.readUInt32BE(16), height: head.readUInt32BE(20) };
}

/* ── playwright ───────────────────────────────────────────────────────────── */
async function loadPlaywright() {
  // CommonJS package: a dynamic import lands the exports under `.default`, so
  // reading `chromium` off the namespace gives undefined and the failure shows
  // up thirty lines later as "cannot read properties of undefined".
  const pick = (mod) => (mod && mod.chromium) ? mod : (mod && mod.default) || {};
  try {
    const mod = pick(await import('playwright'));
    if (mod.chromium) return mod;
  } catch { /* fall through */ }
  const local = path.join(REPO, 'test', 'safe', 'node_modules', 'playwright', 'index.js');
  if (fs.existsSync(local)) {
    const mod = pick(await import(pathToFileURL(local).href));
    if (mod.chromium) return mod;
  }
  throw new Error('playwright not found. Install it where the golden harness lives:\n'
    + '  cd test/safe && npm i && npx playwright install chrome');
}
const { chromium } = await loadPlaywright();
const browser = await chromium.launch({ channel: 'chrome' });

const built = [];
const sizeProblems = [];
try {
  const tplUrl = pathToFileURL(path.join(TPL_DIR, frame)).href;

  for (const fmt of FORMATS) {
    if (only && fmt.size !== only) continue;

    const page = await browser.newPage({
      viewport: { width: fmt.px.w, height: fmt.px.h }, deviceScaleFactor: 1
    });
    await page.goto(tplUrl);
    // Let the webfonts land but do not hang on them: an offline build should
    // produce a readable cover in Hiragino rather than no cover at all.
    await Promise.race([ page.evaluate(() => document.fonts.ready), page.waitForTimeout(6000) ]);

    for (let i = 0; i < fmt.letters.length; i++) {
      const letter = fmt.letters[i];
      const v = variants[i];
      if (!v) {
        warnings.push(`thumb_${fmt.size}_${letter}.png: only ${variants.length} variant(s) authored — not built`);
        continue;
      }

      const spec = {
        size: fmt.size,
        badge: `第${EPP}回`,
        headline: (v.headline || []).slice(0, HEADLINE_MAX_LINES),
        accent: Number.isInteger(v.accent) ? v.accent : 0,
        redLine: Number.isInteger(v.red_line) ? v.red_line : -1,
        doc: { title: authored.doc_title || '', rows },
        // The standing instruction, from the guard's own copy — not retyped.
        note: RULES.mustSentence,
        tag: v.tag || '',
        leak: v.leak || '',
        steps: v.steps || authored.steps || [],
        versus: v.versus || authored.versus || []
      };

      const fit = await page.evaluate((s) => window.SF_THUMB(s), spec);
      if (fit.overflowed) {
        warnings.push(`thumb_${fmt.size}_${letter}.png: text still overflows at the ${Math.round(fit.scale * 100)}% floor — shorten it`);
      }
      /* The safe-area result is a MEASUREMENT of the rendered boxes, not a
       * restatement of the CSS. On a Shorts cover the platform draws its own UI
       * over the bottom and the right, so a headline that slipped past the line
       * is invisible until it is public. */
      if (fit.outside && fit.outside.length) {
        for (const o of fit.outside) {
          const msg = `thumb_${fmt.size}_${letter}.png: 「${o.text}」 (${o.what}) leaves the safe area — ${o.over}`;
          warnings.push(msg);
          // Promoted from a warning after cross-review (2026-11-16). Glyph
          // count is the author's business — a long headline is still a
          // headline. Leaving the safe area is GEOMETRY, like the pixel size:
          // the platform draws its UI over that text, so it is invisible in
          // the file and invisible until the thumbnail is public. A generator
          // that exits 0 on it means the only thing catching it is remembering
          // to run qa_video.
          sizeProblems.push(msg);
        }
      }

      /* Guards run on the RENDERED TEXT, not on the spec.
       *
       * Checking the spec would be checking our own input: `note` is filled in
       * from RULES.mustSentence four lines above, so a must-line assertion
       * against the spec passes by construction. Reading it back out of the DOM
       * asks a different question — did the required line survive rendering,
       * fitting and the safe-area layout. That is the question that can fail. */
      const painted = await page.evaluate(() => {
        const safe = document.getElementById('safe');
        return {
          all: safe.innerText,
          note: (safe.querySelector('.note') || {}).innerText || ''
        };
      });

      const where = `thumb_${fmt.size}_${letter}.png`;
      const violations = [
        ...runForbidden([ [ `${where} (rendered)`, painted.all ] ]),
        ...mustLineViolations(`${where} (rendered)`, painted.note)
      ];
      if (violations.length) {
        // No file is written for a frame that breaks the writing rules. The
        // pipeline does not edit the author's words to satisfy a regex.
        console.error(`\n🔴 ${where} — ${violations.length} guard violation(s), nothing written:`);
        violations.forEach((x) => console.error('  - ' + x));
        process.exitCode = 1;
        continue;
      }

      const file = path.join(epDir, where);
      await page.locator('#card').screenshot({ path: file });
      const size = pngSize(file);
      if (size.width !== fmt.px.w || size.height !== fmt.px.h) {
        sizeProblems.push(`${where} is ${size.width}×${size.height}, not ${fmt.px.w}×${fmt.px.h}`);
      }
      built.push({
        name: where, variant: letter, format: fmt.size, frame,
        pixels: `${size.width}x${size.height}`,
        bytes: fs.statSync(file).size,
        fit: Math.round(fit.scale * 100) / 100,
        outside: (fit.outside || []).length,
        headline: spec.headline
      });
      process.stdout.write(`  ${where}  (${size.width}×${size.height}, fit ${Math.round(fit.scale * 100)}%`
        + `${(fit.outside || []).length ? `, ${fit.outside.length} outside safe area` : ''})\n`);
    }
    await page.close();
  }
} finally {
  await browser.close();
}

/* A wrong-sized file is a hard failure, reported after everything is built:
 * unlike a missing variant it is not a partial success — it is the deliverable
 * being the wrong shape, and it gets cropped on upload where nobody sees it. */
if (sizeProblems.length) {
  console.error('\n🔴 geometry — the file is the wrong shape, or text sits where the platform UI will cover it:');
  sizeProblems.forEach((p) => console.error('  - ' + p));
  process.exitCode = 1;
}

fs.writeFileSync(path.join(epDir, 'thumbnails.json'), JSON.stringify({
  ep: EP,
  intent: topic.intent,
  frame,
  version: 'v1',
  generated_by: 'scripts/content/make_thumbnail.mjs',
  // Which file the Shorts end card uses. NOT decided here — Gate 1 does, and
  // make_short.mjs reads `cover` out of short_ja.json. Recorded as null so the
  // absence is visible rather than implied.
  cover_chosen_at_gate1: null,
  files: built,
  warnings
}, null, 2) + '\n');

process.stdout.write(`\nep${EPP} thumbnails — frame ${frame} (intent ${topic.intent}), ${built.length} file(s)\n`);
if (warnings.length) {
  process.stdout.write('\nwarnings:\n');
  warnings.forEach((w) => process.stdout.write('  - ' + w + '\n'));
}
