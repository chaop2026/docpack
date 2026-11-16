#!/usr/bin/env node
/*
 * SafeFile JP — build ONE episode's YouTube Shorts cut, on its own.
 *
 *   node scripts/content/make_short.mjs 1
 *   node scripts/content/make_short.mjs 1 --no-record   # cards only, no screen capture
 *
 * Input  : content/jp/topics.json          (track, doc, purpose, landing, title)
 *          content/jp/epNN/post_ja.md      (hook, title, bullets, captions)
 *          content/jp/epNN/short_ja.json   (optional — `cover`, `hooks`, `script`)
 *          content/jp/epNN/thumb_short_*.png (the end card, if Gate 1 picked one)
 * Output : content/jp/epNN/shorts.mp4
 *          content/jp/epNN/shorts_title_ja.txt
 *          content/jp/epNN/shorts_desc_ja.txt
 *          content/jp/epNN/short_ja.json   (updated — `cover`/`hooks`/`script` kept)
 *
 * ── This is not a second recorder ──────────────────────────────────────────
 *
 * The whole cut lives in scripts/content/lib/shorts.mjs and make_episode.mjs
 * calls the same function. This file is the thin way in: read the plan, open a
 * browser, hand both to buildShorts, print what happened.
 *
 * It exists because re-recording a Short is a thing you do on its own — the
 * hook was rewritten, Gate 1 picked the other thumbnail, the recording caught
 * the tool mid-OCR. Running the whole episode build for that would rebuild the
 * carousel, the demo and the guide PDF, and on 2026-11-05 doing exactly that
 * degraded forty-five committed files (the guide lost its real screenshots).
 *
 * 🔴 It does NOT touch manifest.json. That file is make_episode.mjs's, and its
 * `posted` block records what has actually been published. A Shorts rebuild
 * that rewrote the manifest would be a rebuild of the ASSETS rewriting the
 * record of the PUBLISHING — the mistake that file's own comment warns about.
 * What this script changes, it changes in short_ja.json.
 *
 * Requires: node, ffmpeg/ffprobe, and playwright with the `chrome` channel.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { FIXTURE_FOR_DOC, loadTopic, parseFrontmatter, slugFor } from './lib/episode.mjs';
import { loadPlaywright } from './lib/capture.mjs';
import { buildShorts } from './lib/shorts.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, '..', '..');
const PUBLIC = path.join(REPO, 'public');
const FIXTURES = path.join(REPO, 'test', 'safe', 'fixtures');
const CONTENT = path.join(REPO, 'content', 'jp');
const SHORTS_TEMPLATE = path.join(__dirname, 'templates', 'shorts_card.html');

const { RULES } = await import(pathToFileURL(path.join(__dirname, 'guard_rules.mjs')).href);

/* ── args ─────────────────────────────────────────────────────────────────── */
const argv = process.argv.slice(2);
const epArg = argv.find((a) => /^\d+$/.test(a));
const noRecord = argv.includes('--no-record');
if (!epArg) {
  console.error('usage: node scripts/content/make_short.mjs <ep> [--no-record]');
  process.exit(2);
}
const EP = Number(epArg);
const EPP = String(EP).padStart(2, '0');
const epDir = path.join(CONTENT, 'ep' + EPP);

/* ── plan + frontmatter ───────────────────────────────────────────────────── */
let topic, landing;
try { ({ topic, landing } = loadTopic(CONTENT, EP)); }
catch (e) { console.error(e.message); process.exit(2); }

const postPath = path.join(epDir, 'post_ja.md');
if (!fs.existsSync(postPath)) {
  console.error(`missing ${path.relative(REPO, postPath)} — the Short's opening line is the article's hook, `
    + 'so the article comes first (see scripts/content/README.md)');
  process.exit(2);
}
const { data: fm } = parseFrontmatter(fs.readFileSync(postPath, 'utf8'));
for (const key of [ 'title', 'hook' ]) {
  if (!fm[key]) { console.error(`post_ja.md frontmatter is missing "${key}"`); process.exit(2); }
}
if (!Array.isArray(fm.bullets) || fm.bullets.length !== 3) {
  console.error(`post_ja.md needs exactly 3 bullets (got ${Array.isArray(fm.bullets) ? fm.bullets.length : 'none'})`);
  process.exit(2);
}

const warnings = [];
const captions = Array.isArray(fm.captions) ? fm.captions : [];
if (topic.track === 'A' && captions.length !== 3 && !noRecord) {
  warnings.push('captions: track A wants 3 caption lines for the recording; falling back to generic ones');
}

/* ── build ────────────────────────────────────────────────────────────────── */
const { chromium } = await loadPlaywright(REPO);
const browser = await chromium.launch({ channel: 'chrome' });

let result;
try {
  result = await buildShorts({
    browser, epDir, ep: EP, epp: EPP, topic, fm, captions,
    templatePath: SHORTS_TEMPLATE,
    publicDir: PUBLIC, fixturesDir: FIXTURES, fixtureForDoc: FIXTURE_FOR_DOC,
    landing, slug: slugFor(topic),
    mustSentence: RULES.mustSentence,
    record: !noRecord,
    warnings
  });
} finally {
  await browser.close();
}

process.stdout.write(`\nep${EPP} shorts — ${result.status}\n`);
if (result.short.thumbnail_frame_sec != null) {
  const [ a, b ] = result.short.thumbnail_frame_window;
  process.stdout.write(`  cover frame: ${result.short.thumbnail_frame_sec}s  (window ${a}–${b}s — `
    + 'in the Shorts frame picker, drag the scrubber fully to the right)\n');
}
if (warnings.length) {
  process.stdout.write('\nwarnings:\n');
  warnings.forEach((w) => process.stdout.write('  - ' + w + '\n'));
}

// A failed cut exits non-zero. Unlike inside an episode build — where the other
// four artifacts are still worth having — this script has exactly one job.
if (String(result.status).startsWith('failed')) process.exitCode = 1;
