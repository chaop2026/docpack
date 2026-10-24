#!/usr/bin/env node
/*
 * SafeFile JP content pipeline — builds one episode's publishable assets.
 *
 *   node scripts/content/make_episode.mjs 1
 *   node scripts/content/make_episode.mjs 1 --no-demo     # skip the GIF/MP4
 *
 * Input  : content/jp/topics.json  (the plan)
 *          content/jp/epNN/post_ja.md  (frontmatter + body, written by a human
 *          or by Claude Code — this script never writes prose)
 * Output : same folder — x_thread.md, carousel_1..3.png, demo.gif, demo.mp4,
 *          manifest.json
 *
 * post_en.md is NOT generated. A machine translation of marketing copy reads
 * like one, and the English half of this project is a parallel rewrite rather
 * than a translation (see the landing pages). If the file is absent this script
 * warns and records it in the manifest; it does not invent one.
 *
 * Failure is partial by design: if the demo recording fails, every other
 * artifact is still produced and the manifest says `demo: "failed: <reason>"`.
 * A pipeline that throws away four good files because the fifth did not render
 * just gets run less often.
 *
 * Requires: node, ffmpeg (GIF/MP4), and playwright with the `chrome` channel —
 * the same install the golden harness uses (test/safe/node_modules).
 */
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, '..', '..');
const PUBLIC = path.join(REPO, 'public');
const FIXTURES = path.join(REPO, 'test', 'safe', 'fixtures');
const CONTENT = path.join(REPO, 'content', 'jp');
const TEMPLATE = path.join(__dirname, 'templates', 'carousel.html');

const BASE_URL = 'https://slimfile.net';
const LANDING_PATH = { nyusatsu: '/safe/jp/nyusatsu/', honnin: '/safe/jp/honnin-kakunin/', aimae: '/safe/jp/ai-mae/' };

// A dummy document exists only for the four alpha document types. Anything else
// in topics.json is a plain Japanese label and gets no demo — stated, not faked.
const FIXTURE_FOR_DOC = {
  shikaku_kakuninsho: 'jp/shikaku_kakuninsho/kenpo.jpg',
  unten_menkyo: 'jp/unten_menkyo/front.jpg',
  mynumber_card: 'jp/mynumber_card/front.jpg',
  juminhyo: 'jp/juminhyo/ichibu_plain.jpg'
};

// The writing rules are NOT defined here any more. They live in
// content/jp/guard_rules.json so the server's JpContentGuard enforces the same
// list on import — a rule that exists in one of the two places is a rule the
// other half of the project can break without anything saying so.
const { RULES, weightedLength, runForbidden, runLegalClaim, mustLineViolations } =
  await import(pathToFileURL(path.join(__dirname, 'guard_rules.mjs')).href);

// Our editorial limit, not X's. X's actual cap is RULES.limits.tweet_weighted
// (280 weighted); 140 keeps a thread readable. Both are reported by name.
const TWEET_LIMIT = RULES.limits.tweet_editorial;

/* ── args ─────────────────────────────────────────────────────────────────── */
const argv = process.argv.slice(2);
const epArg = argv.find((a) => /^\d+$/.test(a));
const noDemo = argv.includes('--no-demo');
if (!epArg) {
  console.error('usage: node scripts/content/make_episode.mjs <ep> [--no-demo]');
  process.exit(2);
}
const EP = Number(epArg);
const EPP = String(EP).padStart(2, '0');   // the zero-padded form used in folder names, UTM tags and labels
const epDir = path.join(CONTENT, 'ep' + EPP);

// Read BEFORE anything is written. The parts of a manifest this script does not
// own — `posted`, which records what has actually been published — are carried
// forward from it; see the manifest literal near the bottom of this file.
const manifestPath = path.join(epDir, 'manifest.json');
const prevManifest = fs.existsSync(manifestPath)
  ? (() => { try { return JSON.parse(fs.readFileSync(manifestPath, 'utf8')); } catch { return {}; } })()
  : {};

/* ── plan ─────────────────────────────────────────────────────────────────── */
const plan = JSON.parse(fs.readFileSync(path.join(CONTENT, 'topics.json'), 'utf8'));
const topic = plan.episodes.find((e) => e.ep === EP);
if (!topic) {
  console.error(`ep${EP} is not in content/jp/topics.json`);
  process.exit(2);
}
if (topic.blocked_until) {
  // ep32 advertises batch processing, which does not exist. The strategy
  // forbids promoting unshipped features, so refuse rather than build it.
  console.error(`ep${EP} is blocked until: ${topic.blocked_until}`);
  console.error(topic.note || '');
  process.exit(2);
}
const landing = LANDING_PATH[topic.landing];
if (!landing) {
  console.error(`ep${EP}: unknown landing "${topic.landing}"`);
  process.exit(2);
}
const utmUrl = `${BASE_URL}${landing}?utm_source=x&utm_campaign=ep${EPP}`;

/* ── frontmatter ──────────────────────────────────────────────────────────── */
/* A deliberately small YAML subset: `key: value` and `key:` followed by `- `
 * items. Pulling in a YAML dependency for five keys would buy nothing, and a
 * parser that quietly accepted more than this would let the post file drift
 * into shapes the rest of the script does not read. Unknown keys are kept as
 * strings and passed through to the manifest.
 */
function parseFrontmatter(text) {
  if (!text.startsWith('---')) throw new Error('post_ja.md must open with a --- frontmatter block');
  const end = text.indexOf('\n---', 3);
  if (end === -1) throw new Error('post_ja.md frontmatter is not closed with ---');
  const head = text.slice(3, end).split('\n');
  const body = text.slice(text.indexOf('\n', end + 1) + 1);

  const data = {};
  let listKey = null;
  for (const raw of head) {
    const line = raw.replace(/\s+$/, '');
    if (!line.trim() || line.trim().startsWith('#')) continue;
    const item = line.match(/^\s*-\s+(.*)$/);
    if (item && listKey) { data[listKey].push(unquote(item[1])); continue; }
    const kv = line.match(/^([A-Za-z_][\w-]*):\s*(.*)$/);
    if (!kv) throw new Error(`frontmatter line not understood: ${line}`);
    const [, key, value] = kv;
    if (value === '') { listKey = key; data[key] = []; } else { listKey = null; data[key] = unquote(value); }
  }
  return { data, body };
}
const unquote = (s) => s.replace(/^["'](.*)["']$/, '$1').trim();

const postPath = path.join(epDir, 'post_ja.md');
if (!fs.existsSync(postPath)) {
  console.error(`missing ${path.relative(REPO, postPath)} — write the body first (see scripts/content/README.md)`);
  process.exit(2);
}
const { data: fm, body } = parseFrontmatter(fs.readFileSync(postPath, 'utf8'));

const warnings = [];
for (const key of ['title', 'hook', 'cta']) {
  if (!fm[key]) throw new Error(`post_ja.md frontmatter is missing "${key}"`);
}
if (!Array.isArray(fm.bullets) || fm.bullets.length !== 3) {
  throw new Error(`post_ja.md needs exactly 3 bullets (got ${Array.isArray(fm.bullets) ? fm.bullets.length : 'none'})`);
}
const captions = Array.isArray(fm.captions) ? fm.captions : [];
if (topic.track === 'A' && captions.length !== 3 && !noDemo) {
  warnings.push('captions: track A wants 3 caption lines for the demo; falling back to generic ones');
}

const enPath = path.join(epDir, 'post_en.md');
const enBody = fs.existsSync(enPath) ? fs.readFileSync(enPath, 'utf8') : null;
if (enBody === null) warnings.push('post_en.md is absent — write the English version by hand (it is not generated)');

/* ── x_thread.md ──────────────────────────────────────────────────────────── */
/* Five tweets: hook, three bullets, CTA + the UTM URL — plus the required
 * recipient-instructions line, which the thread did NOT carry until this round.
 *
 * The strategy says every piece of published material must state it, and the
 * guard below only ever read the JA body, so three threads shipped without it
 * while the build reported no violation. The line is appended to the last tweet
 * here rather than left to the author, because a rule that is enforced on one
 * output and trusted on another is a rule that exists on one output.
 *
 * Over-length tweets are REPORTED, never truncated. Truncating marketing copy
 * at a byte boundary produces a sentence the author did not write, and the
 * damage is invisible once it is posted; a count next to each line makes the
 * problem obvious before it is. The same reasoning splits the required line
 * into its own tweet rather than squeezing the CTA to make room: a thread with
 * six tweets is fine, a CTA the author did not write is not.
 */
const MUST_LINE = RULES.mustLine;
const MUST_SENTENCE = RULES.mustSentence;
const ctaTweet = `${fm.cta}\n${MUST_SENTENCE}\n${utmUrl}`;
const tweets = [
  `${fm.hook}\n\n${fm.title}`,
  `①${fm.bullets[0]}`,
  `②${fm.bullets[1]}`,
  `③${fm.bullets[2]}`,
  ...([...ctaTweet].length <= TWEET_LIMIT
    ? [ctaTweet]
    : [`${fm.cta}\n${utmUrl}`, MUST_SENTENCE])
];
const over = tweets.map((t, i) => ({ i: i + 1, len: [...t].length })).filter((t) => t.len > TWEET_LIMIT);
if (over.length) warnings.push(`x_thread: tweet(s) ${over.map((o) => `${o.i} (${o.len}字)`).join(', ')} exceed ${TWEET_LIMIT}字 — shorten by hand`);

// Built here, written only after the guard passes. Scanning the finished file
// rather than the tweet array means the header lines — which carry
// topics.json's `title_ja`, a string the frontmatter guard never sees — are
// covered too.
const threadMd = [
  `<!-- generated by scripts/content/make_episode.mjs — ep${EPP}. Edit post_ja.md and re-run. -->`,
  `# X thread — ep${EPP}`,
  '',
  `> ${topic.title_ja}`,
  `> landing: ${utmUrl}`,
  '',
  // Both numbers, labelled. 字 is what the author counts; weighted is what X
  // counts (CJK 2, URL a flat 23) and is the only one that decides whether the
  // tweet can be posted. v3 conflated them.
  ...tweets.flatMap((t, i) => {
    const len = [...t].length;
    const w = weightedLength(t);
    const flag = [
      len > TWEET_LIMIT ? `⚠ 編集上限 ${TWEET_LIMIT}字 超過` : '',
      w > RULES.limits.tweet_weighted ? `🛑 X上限 ${RULES.limits.tweet_weighted} 超過` : ''
    ].filter(Boolean).join(' / ');
    return [`## ${i + 1} / ${tweets.length}  (${len}字 / weighted ${w})${flag ? '  ' + flag : ''}`, '', '```', t, '```', ''];
  })
].join('\n');

/* ── content rules the strategy forbids breaking ──────────────────────────── */
/* Checked here rather than left to review because these are the rules a draft
 * written in a hurry breaks, and the whole body is in front of us. They are
 * reported, not auto-corrected: rewriting someone's sentence to satisfy a
 * regex produces copy nobody chose.
 *
 * ── Why the corpus is named, not concatenated ───────────────────────────────
 *
 * The first version joined the JA frontmatter and body into one string. That
 * made the scope invisible, and the scope was wrong: the English post and the
 * generated thread were never scanned, so ep01 shipped
 * 「複数枚をまとめて読み込めます」/"Several files at once is fine" (the tool's
 * file input takes one file) and the thread shipped without the required line,
 * all with a clean build. Each surface is now a labelled entry, so a violation
 * says WHICH file it is in and adding a surface means adding a line here.
 */
const CORPUS = [
  [ 'post_ja.md (frontmatter)', [fm.title, fm.hook, fm.cta, ...fm.bullets, ...captions].join('\n') ],
  [ 'post_ja.md (body)', body ],
  [ 'post_en.md', enBody || '' ],
  // The thread and the carousel are generated from the frontmatter, so a
  // violation there is already caught above — but they are scanned anyway,
  // because that derivation is a fact about today's code and not a promise.
  [ 'x_thread.md (generated)', threadMd ],
  [ 'carousel text (generated)', [fm.title, fm.hook, ...fm.bullets, fm.cta].join('\n') ]
];

// The list itself is content/jp/guard_rules.json (see guard_rules.mjs).
const violations = runForbidden(CORPUS);

// The required line, checked as its own line ending in 「。」 rather than as a
// substring — cross-review Q4 asked for the punctuation and the line break to
// be part of the rule, because a line buried mid-paragraph reads as copy
// instead of as the standing instruction.
violations.push(...mustLineViolations('post_ja.md (body)', body));

if (enBody && !new RegExp(RULES.mustLineEn, 'i').test(enBody)) {
  violations.push(`post_en.md is missing the English form of the required line ("${RULES.mustLineEn}")`);
}
// The required line is appended above, so this can only fail if that code is
// changed. That is exactly when it should fail: the thread is the surface that
// shipped without it.
if (!tweets.some((t) => t.includes(MUST_LINE))) {
  violations.push(`x_thread.md (generated) carries no 「${MUST_LINE}」 — the generator stopped adding it`);
}

// Conditional source requirement: only fires when the article actually makes a
// claim about what the law requires or restricts. The whole published article is
// the scope — the claim and its source need not share a paragraph, but they do
// have to reach the same reader.
violations.push(...runLegalClaim('post_ja.md', [fm.title, fm.hook, fm.cta, ...fm.bullets, body].join('\n')));
if (enBody) violations.push(...runLegalClaim('post_en.md', enBody));

// Title length, by the same number the server uses.
if ([...fm.title].length > RULES.limits.title_chars) {
  violations.push(`post_ja.md (frontmatter): title は ${RULES.limits.title_chars}字以内 — 現在 ${[...fm.title].length}字`);
}

// Weighted length, reported for every tweet. The editorial limit is a warning
// (above); exceeding X's own 280 weighted cap is a violation, because such a
// tweet cannot be posted at all.
const tooHeavy = tweets
  .map((t, i) => ({ i: i + 1, w: weightedLength(t) }))
  .filter((t) => t.w > RULES.limits.tweet_weighted);
if (tooHeavy.length) {
  violations.push(`x_thread.md (generated): tweet(s) ${tooHeavy.map((t) => `${t.i} (weighted ${t.w})`).join(', ')} exceed X's own limit of ${RULES.limits.tweet_weighted}`);
}
if (violations.length) {
  console.error(`\nep${EP}: content rules violated — nothing was written:\n`);
  violations.forEach((v) => console.error('  - ' + v));
  process.exit(1);
}

fs.writeFileSync(path.join(epDir, 'x_thread.md'), threadMd);

/* ── playwright ───────────────────────────────────────────────────────────── */
async function loadPlaywright() {
  // Playwright is a CommonJS package, so a dynamic import of its entry file
  // lands the exports under `.default` rather than as named exports. Reading
  // `chromium` off the namespace gives `undefined` and the failure surfaces
  // thirty lines later as "cannot read properties of undefined" — measured.
  const pick = (mod) => (mod && mod.chromium) ? mod : (mod && mod.default) || {};

  try {
    const mod = pick(await import('playwright'));
    if (mod.chromium) return mod;
  } catch { /* not installed at this level — fall through */ }

  // The golden harness owns the install (test/safe/node_modules); this script
  // borrows it rather than adding a second copy that can drift in version.
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

/* ── carousel ─────────────────────────────────────────────────────────────── */
/* The slide is declared 1080×1350 in three places — the template's comment, its
 * #card CSS, and the viewport this script opens — and until now nothing checked
 * that the file on disk agreed with any of them. deviceScaleFactor, a CSS edit
 * or a clipped element would all change the real pixels while the build stayed
 * silent, and the first place the mismatch would show is a cropped upload.
 *
 * Read from the PNG itself rather than asked of the browser: the IHDR chunk is
 * the first 8 bytes after the signature, so it needs no dependency, and it is
 * the file's own account of its size rather than our intention.
 */
const CAROUSEL_SIZE = { width: 1080, height: 1350 };
// The strategy's illustration rule — a reduced dummy-card image must have a
// long side of at most 800px — has no automated check because no episode embeds
// one yet. This is the measurement it would use; see the report's rule table for
// which rules are enforced and which are still a human reading the draft.
const ILLUSTRATION_MAX_LONG_SIDE = 800;

function pngSize(file) {
  const head = Buffer.alloc(24);
  const fd = fs.openSync(file, 'r');
  try { fs.readSync(fd, head, 0, 24, 0); } finally { fs.closeSync(fd); }
  if (head.toString('hex', 0, 8) !== '89504e470d0a1a0a') throw new Error(`${path.basename(file)} is not a PNG`);
  if (head.toString('ascii', 12, 16) !== 'IHDR') throw new Error(`${path.basename(file)} has no IHDR where one must be`);
  return { width: head.readUInt32BE(16), height: head.readUInt32BE(20) };
}

const carousel = [];
const carouselSizes = {};
const sizeProblems = [];
{
  const page = await browser.newPage({ viewport: { width: 1080, height: 1350 }, deviceScaleFactor: 1 });
  await page.goto(pathToFileURL(TEMPLATE).href);
  // Let the webfonts land, but do not hang on them: an offline build should
  // produce a slide in Hiragino rather than no slide at all.
  await Promise.race([page.evaluate(() => document.fonts.ready), page.waitForTimeout(6000)]);

  const slideData = { ep: EP, track: topic.track, title: fm.title, hook: fm.hook, bullets: fm.bullets, cta: fm.cta, url: utmUrl };
  for (const n of [1, 2, 3]) {
    const fit = await page.evaluate(([slide, d]) => window.SF_RENDER(slide, d), [n, slideData]);
    if (fit.overflowed) warnings.push(`carousel_${n}: text still overflows at the ${Math.round(fit.scale * 100)}% floor — shorten the copy`);
    else if (fit.scale < 1) warnings.push(`carousel_${n}: text was shrunk to ${Math.round(fit.scale * 100)}% to fit`);
    const file = path.join(epDir, `carousel_${n}.png`);
    await page.locator('#card').screenshot({ path: file });
    carousel.push(file);
    const size = pngSize(file);
    carouselSizes[`carousel_${n}.png`] = size;
    if (size.width !== CAROUSEL_SIZE.width || size.height !== CAROUSEL_SIZE.height) {
      sizeProblems.push(`carousel_${n}.png is ${size.width}×${size.height}, not ${CAROUSEL_SIZE.width}×${CAROUSEL_SIZE.height}`);
    }
    process.stdout.write(`  carousel_${n}.png  (${size.width}×${size.height}, fit ${Math.round(fit.scale * 100)}%)\n`);
  }
  await page.close();
}

/* Reported as a hard failure, after all three slides exist: a wrong-sized slide
 * is not a partial success the way a missing demo recording is — it is the
 * deliverable itself being wrong, and it would be found by a cropped upload
 * rather than by anyone reading the manifest. The sizes stay in the manifest
 * either way so the record says what was actually produced.
 */
if (sizeProblems.length) {
  console.error(`\nep${EP}: carousel output has the wrong pixel size:\n`);
  sizeProblems.forEach((p) => console.error('  - ' + p));
  console.error(`\n(the template declares ${CAROUSEL_SIZE.width}×${CAROUSEL_SIZE.height}; a reduced dummy-card`);
  console.error(`illustration, if one is ever embedded, must have a long side of at most ${ILLUSTRATION_MAX_LONG_SIDE}px)`);
  await browser.close();
  process.exit(1);
}

/* ── demo recording (track A only) ────────────────────────────────────────── */
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json', '.txt': 'text/plain', '.pdf': 'application/pdf' };

// Same shape as the golden harness's server: public/ at the root, the fixture
// tree under /__fx/. Local only — the recording must never touch production.
function startServer() {
  return new Promise((resolve) => {
    const srv = http.createServer((req, res) => {
      let p = decodeURIComponent(req.url.split('?')[0]);
      if (p === '/') p = '/index.html';
      const root = p.startsWith('/__fx/') ? FIXTURES : PUBLIC;
      if (p.startsWith('/__fx/')) p = p.slice(5);
      let fp = path.join(root, p);
      // Serve <dir>/index.html for a directory request. The real app relies on
      // ActionDispatch::Static doing exactly this for /safe/, so a server that
      // 404s here records a demo of an error page — which is what the first run
      // of this script actually produced.
      if (fp.startsWith(root) && fs.existsSync(fp) && fs.statSync(fp).isDirectory()) fp = path.join(fp, 'index.html');
      if (!fp.startsWith(root) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end('nf'); return; }
      res.writeHead(200, { 'content-type': MIME[path.extname(fp)] || 'application/octet-stream' });
      fs.createReadStream(fp).pipe(res);
    });
    srv.listen(0, '127.0.0.1', () => resolve(srv));
  });
}

let demo = 'skipped: track B has no tool demo';
if (noDemo) demo = 'skipped: --no-demo';
else if (topic.track !== 'A') demo = 'skipped: track B has no tool demo';
else if (!FIXTURE_FOR_DOC[topic.doc]) demo = `failed: no dummy document exists for doc="${topic.doc}" (only ${Object.keys(FIXTURE_FOR_DOC).join(', ')} have fixtures)`;
else {
  let srv;
  const frameDir = path.join(epDir, '.frames');
  try {
    fs.rmSync(frameDir, { recursive: true, force: true });
    fs.mkdirSync(frameDir, { recursive: true });
    srv = await startServer();
    const port = srv.address().port;
    const page = await browser.newPage({ viewport: { width: 720, height: 1280 }, deviceScaleFactor: 1 });

    let frame = 0;
    const MAX_FRAMES = 40;
    /* 0.5s interval, <= 40 frames — but captured in PHASES rather than as one
     * continuous 20s window. OCR on a photographed card takes tens of seconds,
     * so a single timed run would spend every frame on a progress bar and the
     * finished GIF would show no document at all. Each phase takes its own
     * frames once that step is actually on screen.
     */
    const shoot = async (n) => {
      for (let i = 0; i < n && frame < MAX_FRAMES; i++) {
        await page.screenshot({ path: path.join(frameDir, `f${String(frame).padStart(3, '0')}.png`) });
        frame++;
        if (i < n - 1) await page.waitForTimeout(500);
      }
    };

    const toolUrl = `http://127.0.0.1:${port}/safe/?lang=ja&purpose=${topic.purpose}&from=direct`;
    const resp = await page.goto(toolUrl, { waitUntil: 'load' });
    // Fail here, with the status, rather than thirty seconds later on a missing
    // selector. The first run of this script 404'd on /safe/ and reported
    // "waiting for locator('#fileInput')" — true, and useless.
    if (!resp || !resp.ok()) throw new Error(`${toolUrl} returned ${resp ? resp.status() : 'no response'}`);
    if (!(await page.locator('#fileInput').count())) throw new Error(`${toolUrl} loaded but has no #fileInput — wrong document?`);

    // Caption bar, injected into the page so the frames already carry the text.
    // Drawing it afterwards with ffmpeg means shipping a Japanese font path and
    // a second place for the wording to live.
    const caps = captions.length === 3 ? captions : [
      '① PDF・写真をドラッグ',
      `② 「提出目的：${topic.purpose}」を選ぶ`,
      '③ ダウンロード — 黒塗りの下に原文は残りません'
    ];
    await page.evaluate(() => {
      const bar = document.createElement('div');
      bar.id = '__cap';
      bar.style.cssText = 'position:fixed;left:0;right:0;bottom:0;z-index:9999;background:rgba(23,20,15,.92);'
        + 'color:#fff;font:500 19px/1.6 "Hiragino Kaku Gothic ProN","Noto Sans JP",sans-serif;'
        + 'padding:16px 20px;white-space:pre-line;min-height:96px';
      document.body.appendChild(bar);
      window.__cap = (lines) => { bar.textContent = lines.join('\n'); };
    });
    const setCap = (upto) => page.evaluate((l) => window.__cap(l), caps.slice(0, upto));

    await setCap(1);
    await shoot(4);

    await page.setInputFiles('#fileInput', path.join(FIXTURES, FIXTURE_FOR_DOC[topic.doc]));
    // #docWrap becoming visible is afterLoad()'s last step — `pages.length > 0`
    // goes true while a later page is still inside Tesseract.
    await page.waitForFunction(
      () => Array.isArray(pages) && pages.length > 0 && document.getElementById('docWrap').style.display === 'flex',
      { timeout: 300000 }
    );
    await page.waitForTimeout(700);
    await setCap(2);
    await shoot(10);

    await page.locator('#jpBar').scrollIntoViewIfNeeded().catch(() => {});
    await shoot(6);

    await page.click('#btnMake');
    await page.waitForFunction(() => document.getElementById('result').style.display === 'block', { timeout: 120000 });
    await setCap(3);
    await page.locator('#result').scrollIntoViewIfNeeded().catch(() => {});
    await page.waitForTimeout(500);
    await shoot(MAX_FRAMES - frame);

    await page.close();

    if (frame < 6) throw new Error(`only ${frame} frames captured`);

    const gif = path.join(epDir, 'demo.gif');
    const mp4 = path.join(epDir, 'demo.mp4');
    const pattern = path.join(frameDir, 'f%03d.png');
    // Two-pass palette: a 256-colour global palette picked from the actual
    // frames. The single-pass default dithers the black bars into speckle,
    // which on a redaction demo reads as "the bar is see-through".
    const palette = path.join(frameDir, 'palette.png');
    run('ffmpeg', ['-y', '-framerate', '2', '-i', pattern, '-vf', 'palettegen=stats_mode=diff', palette]);
    run('ffmpeg', ['-y', '-framerate', '2', '-i', pattern, '-i', palette,
      '-lavfi', 'paletteuse=dither=bayer:bayer_scale=3', '-loop', '0', gif]);
    let mp4ok = true;
    try {
      run('ffmpeg', ['-y', '-framerate', '2', '-i', pattern, '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
        '-vf', 'scale=720:-2:flags=lanczos,pad=ceil(iw/2)*2:ceil(ih/2)*2', mp4]);
    } catch (e) { mp4ok = false; warnings.push(`demo.mp4: ${e.message}`); }

    const kb = (f) => Math.round(fs.statSync(f).size / 1024);
    demo = `ok: ${frame} frames, demo.gif ${kb(gif)}KB${mp4ok ? `, demo.mp4 ${kb(mp4)}KB` : ', mp4 failed'}`;
    process.stdout.write(`  demo.gif  (${frame} frames, ${kb(gif)}KB)\n`);
    fs.rmSync(frameDir, { recursive: true, force: true });
  } catch (e) {
    demo = `failed: ${e.message}`;
    warnings.push(`demo: ${e.message}`);
    // Frames are left behind on failure — they are the only evidence of how far
    // the recording got, and deleting them deletes the diagnosis.
    process.stdout.write(`  demo FAILED: ${e.message}\n`);
  } finally {
    if (srv) srv.close();
  }
}

await browser.close();

/* ── manifest ─────────────────────────────────────────────────────────────── */
// `pixels` is the file's own IHDR, not the size we asked the browser for — the
// point of recording it is that the two can disagree.
const fileEntry = (name) => {
  const f = path.join(epDir, name);
  if (!fs.existsSync(f)) return null;
  const entry = { name, bytes: fs.statSync(f).size };
  const size = carouselSizes[name];
  if (size) entry.pixels = `${size.width}x${size.height}`;
  return entry;
};
// `--no-demo` means "do not re-record", not "the demo does not exist". If the
// artifacts are still on disk, the previous manifest's own description of them
// is the truest thing we have; overwriting it with "skipped" would make a
// rebuild-for-a-guard-change look like a regression in the assets.
const demoForManifest = () => {
  if (!noDemo) return demo;
  const kept = ['demo.gif', 'demo.mp4'].filter((n) => fs.existsSync(path.join(epDir, n)));
  if (!kept.length || !prevManifest.demo || /^(skipped|failed)/.test(prevManifest.demo)) return demo;
  return `${prevManifest.demo} (carried over — this run used --no-demo)`;
};

const manifest = {
  ep: EP,
  week: topic.week,
  track: topic.track,
  title_ja: fm.title,
  title_en: topic.title_en,
  doc: topic.doc,
  purpose: topic.purpose,
  landing,
  utm_url: utmUrl,
  generated_by: 'scripts/content/make_episode.mjs',
  files: ['post_ja.md', 'post_en.md', 'x_thread.md', 'carousel_1.png', 'carousel_2.png', 'carousel_3.png', 'demo.gif', 'demo.mp4']
    .map(fileEntry).filter(Boolean),
  demo: demoForManifest(),
  warnings,
  // Publishing checklist. Justin ticks these by hand after posting, then sets
  // topics.json status to "posted". They start false — a checklist that
  // defaults to done is not a checklist.
  //
  // CARRIED OVER, not recomputed. These record what happened in the world, and
  // this script cannot know it. Measured 2026-10-25: re-running ep01 with
  // --no-demo to pick up a guard change reset `posted.x` from true to false and
  // dropped the pinned tweet URL — the manifest then said the thread had never
  // been posted, which is the kind of wrong that reads as fresh work. A rebuild
  // of the ASSETS must not rewrite the record of the PUBLISHING.
  posted: { x: false, youtube_shorts: false, instagram: false, blog: false, ...(prevManifest.posted || {}) }
};
fs.writeFileSync(path.join(epDir, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');

process.stdout.write(`\nep${EPP} built in ${path.relative(REPO, epDir)}\n`);
process.stdout.write(`  demo: ${manifest.demo}\n`);
if (warnings.length) {
  process.stdout.write('\nwarnings:\n');
  warnings.forEach((w) => process.stdout.write('  - ' + w + '\n'));
}

function run(bin, args) {
  const r = spawnSync(bin, args, { encoding: 'utf8' });
  if (r.error) throw new Error(`${bin} not available: ${r.error.message}`);
  if (r.status !== 0) throw new Error(`${bin} exited ${r.status}: ${(r.stderr || '').split('\n').slice(-4).join(' ')}`);
}
