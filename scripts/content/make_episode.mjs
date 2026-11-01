#!/usr/bin/env node
/*
 * SafeFile JP content pipeline — builds one episode's publishable assets.
 *
 *   node scripts/content/make_episode.mjs 1
 *   node scripts/content/make_episode.mjs 1 --no-demo     # skip the GIF/MP4
 *
 * Input  : content/jp/topics.json  (the plan)
 *          content/jp/epNN/post_ja.md      frontmatter + body, written by a
 *          content/jp/epNN/linkedin_en.md  human or by Claude Code — this
 *          content/jp/epNN/summary_ko.md   script never writes prose
 * Output : same folder — x_thread.md, carousel_1..3.png, demo.gif, demo.mp4,
 *          guide_en.pdf, guide_en_pages/NN.png, manifest.json
 *
 * post_en.md, linkedin_en.md and summary_ko.md are NOT generated.
 *
 * post_en.md: a machine translation of marketing copy reads like one, and the
 * English half of this project is a parallel rewrite rather than a translation
 * (see the landing pages).
 *
 * linkedin_en.md (S9): the LinkedIn post is a DEV LOG — a first-person account
 * of what was built and why it was designed that way (strategy v3.1 §3-3, as
 * revised 2026-10-25). It used to be assembled from post_en.md's hook and
 * bullets, which produced a competent summary of the ARTICLE; there is no
 * arrangement of an article's bullet points that becomes a dev log.
 *
 * summary_ko.md (S9): the approver reads Korean and the package is Japanese.
 *
 * If any of the three is absent this script WARNS and records it; the import
 * (JpEpisodeSource#validate!) is what refuses. The split is deliberate — the
 * article is normally drafted before the dev log and the Korean summary are
 * written, and failing the build would mean no carousel until every file
 * exists, so the pipeline would get run later and less often.
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
const GUIDE_TEMPLATE = path.join(__dirname, 'templates', 'guide.html');
const SHORTS_TEMPLATE = path.join(__dirname, 'templates', 'shorts_card.html');

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
const { RULES, weightedLength, runForbidden, runLegalClaim, mustLineViolations, runLinkedIn, runXThread } =
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
/* Attribution: ?via=<channel>&ep=NN, not ?utm_* (S10).
 *
 * Ad/tracker-blocking extensions strip ?utm_* before the request is made —
 * measured 2026-10-27, the author's own Chrome would not open his own shared
 * link while the server answered 200 to everything. Mirrors
 * JpEpisodeSource#via_url; the two build the same string for the same episode
 * and a test pins that. */
const viaUrl = (channel) => `${BASE_URL}${landing}?via=${channel}&ep=ep${EPP}`;
const utmUrl = viaUrl('x');

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

/* The published blog slug, mirroring JpEpisodeSource#slug.
 *
 * Duplicated across the Ruby/JS boundary because the Shorts description has to
 * contain the article URL and this script never talks to the database. A
 * mirrored implementation can drift, so test/integration/jp_shorts_test.rb
 * compares the two for every episode in topics.json rather than trusting this
 * comment. ActiveSupport's `parameterize` is transliterate + downcase +
 * non-alphanumeric to '-' + squeeze + trim; `title_en` is already ASCII, so
 * transliteration is a no-op here and the rest is this regex chain. */
function slugFor(t) {
  const epp = String(t.ep).padStart(2, '0');
  let base = String(t.title_en || '')
    .toLowerCase()
    .replace(/[^a-z0-9\-_]+/g, '-')
    .replace(/-{2,}/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 40)
    .replace(/-$/, '');
  if (!base) base = `ep${epp}`;
  return `jp-ep${epp}-${base}`;
}

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

/* linkedin_en.md and summary_ko.md — written by hand, read here only to CHECK.
 *
 * Both are warnings at this stage and refusals at import (JpEpisodeSource#
 * validate!). The split is deliberate: this script builds assets from the
 * article, and the article is normally drafted before the dev log and the
 * Korean summary are written. Failing the build would mean no carousel until
 * every file exists, so the pipeline would get run later and less often. The
 * import is the gate, because that is the step that creates something a
 * reviewer can approve.
 */
const liPath = path.join(epDir, 'linkedin_en.md');
const liBody = fs.existsSync(liPath) ? fs.readFileSync(liPath, 'utf8').trim() : null;
if (liBody === null) {
  warnings.push('linkedin_en.md is absent — the dev log is written by hand (strategy v3.1 §3-3, revised 2026-10-25); content:jp_import will REFUSE without it');
}
const summaryPath = path.join(epDir, 'summary_ko.md');
if (!fs.existsSync(summaryPath)) {
  warnings.push('summary_ko.md is absent — 승인자가 읽을 수 없는 패키지는 만들지 않는다; content:jp_import will REFUSE without it');
}

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
  ...(weightedLength(ctaTweet) <= TWEET_LIMIT
    ? [ctaTweet]
    : [`${fm.cta}\n${utmUrl}`, MUST_SENTENCE])
];
// Measured in WEIGHTED length, the unit strategy v3.1 §3-3 defines the limit
// in (「140字(全角2・半角1・URL 23 換算)」). Comparing 140 against a raw character
// count — which this line did until 2026-10-25 — silently doubles the
// allowance for Japanese: 140 raw CJK characters weigh 280.
const over = tweets.map((t, i) => ({ i: i + 1, w: weightedLength(t), len: [...t].length })).filter((t) => t.w > TWEET_LIMIT);
if (over.length) warnings.push(`x_thread: tweet(s) ${over.map((o) => `${o.i} (weighted ${o.w} / ${o.len}字)`).join(', ')} exceed the ${TWEET_LIMIT} weighted editorial limit — shorten by hand`);

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
      w > TWEET_LIMIT ? `⚠ 編集上限 ${TWEET_LIMIT}(weighted) 超過` : '',
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

// The LinkedIn dev log, checked on its own rules (S9). A violation here blocks
// the build the same way a forbidden word in the body does — this text is
// published as written, so there is no later step that could catch it.
//
// NOTE it is deliberately NOT in CORPUS above. The global forbidden list is
// about unshipped features and legal overstatement, which apply to every
// surface; the LinkedIn rules are about voice, and 「日本の」 in CORPUS would
// fail every Japanese article ever written.
violations.push(...runLinkedIn(liBody));

// The first line of tweet 1 must be the reader's pain (marketing plan §6-1).
// Checked on the BUILT thread rather than on fm.hook, because the thread is
// what gets posted — if the assembly below ever stops putting the hook first,
// this catches it instead of silently passing.
violations.push(...runXThread(tweets));

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

/* Screenshots for guide_en.pdf, captured DURING the recording.
 *
 * Taken at the four moments the guide describes (drop → pick a purpose → the
 * bars appear → save) rather than mined out of the GIF frames afterwards. Two
 * reasons: the frames are deleted on success, and picking frame 17 of 40 as
 * "the moment the purpose bar appeared" is a guess that silently becomes wrong
 * the first time OCR is slower.
 *
 * The caption bar is hidden for these — the guide carries its own English
 * captions, and leaving the Japanese one in would put two captions on one page.
 */
const guideShots = [];

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

    /* One guide screenshot.
     *
     * Taken at a WIDER viewport than the recording, then restored. The GIF is
     * a 720×1280 phone shape, which is right for the GIF; dropped into the
     * guide's image box that portrait letterboxes to about 444px inside a
     * 1080px page, and LinkedIn renders a document page at roughly half size —
     * so the app's own text came out around 250px wide and unreadable, which
     * is the whole point of including a screenshot. Measured on the first
     * build of ep01.
     *
     * The caption bar is hidden for the shot: the guide carries its own
     * English captions and two captions on one page is worse than none.
     */
    const GUIDE_VIEWPORT = { width: 1120, height: 1000 };
    const guideShot = async (name, scrollTo) => {
      await page.evaluate(() => { const b = document.getElementById('__cap'); if (b) b.style.display = 'none'; });
      await page.setViewportSize(GUIDE_VIEWPORT);
      // Re-anchor AFTER the reflow — a wider viewport moves everything, so a
      // scroll position from before the resize points at the wrong element.
      if (scrollTo) await page.locator(scrollTo).scrollIntoViewIfNeeded().catch(() => {});
      await page.waitForTimeout(250);
      const buf = await page.screenshot();
      await page.setViewportSize({ width: 720, height: 1280 });
      if (scrollTo) await page.locator(scrollTo).scrollIntoViewIfNeeded().catch(() => {});
      await page.evaluate(() => { const b = document.getElementById('__cap'); if (b) b.style.display = ''; });
      guideShots.push({ name, dataUri: 'data:image/png;base64,' + buf.toString('base64') });
    };

    await setCap(1);
    await shoot(4);
    await guideShot('drop');

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
    await guideShot('detected', '#docWrap');

    await page.locator('#jpBar').scrollIntoViewIfNeeded().catch(() => {});
    await shoot(6);
    await guideShot('purpose', '#jpBar');

    await page.click('#btnMake');
    await page.waitForFunction(() => document.getElementById('result').style.display === 'block', { timeout: 120000 });
    await setCap(3);
    await page.locator('#result').scrollIntoViewIfNeeded().catch(() => {});
    await page.waitForTimeout(500);
    await guideShot('result', '#result');
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

/* ── guide_en.pdf — the LinkedIn "document" post ──────────────────────────── */
/*
 * 1080×1350 portrait, 6–8 pages (hard ceiling 10), carousel.html's tokens and
 * fonts. The LinkedIn post is a dev log and this is the thing a reader can
 * swipe through without leaving the feed.
 *
 * Page 1's question is linkedin_en.md's FIRST LINE, de-bolded — not a separate
 * headline written here. The dev log already opens with the plain-English
 * question the post is about; writing a second one would give the same artifact
 * two different openings, and the one nobody edits goes stale.
 *
 * Pages 3–6 are the REAL screenshots captured during the recording when there
 * is one. Track B (and --no-demo, and any episode whose `doc` has no dummy
 * document) gets diagram pages instead, at the SAME page count — a shorter PDF
 * for those episodes would read as a less finished product rather than as a
 * different track.
 */
const GUIDE_MIN_PAGES = 6;
const GUIDE_MAX_PAGES = 10;
const GUIDE_MAX_BYTES = 5 * 1024 * 1024;

// 𝗔-𝘇 and 𝟬-𝟵 back to ASCII. linkedin_en.md's first line is written in the
// Unicode mathematical-bold block because LinkedIn has no formatting controls;
// a PDF has real type, so the cover uses real type. Left alone for anything
// outside those ranges — there is no bold form of a Japanese character and
// substituting a lookalike would be worse than leaving it.
function plainify(text) {
  return Array.from(String(text)).map((ch) => {
    const cp = ch.codePointAt(0);
    if (cp >= 0x1d400 && cp <= 0x1d419) return String.fromCharCode(65 + (cp - 0x1d400)); // bold A-Z
    if (cp >= 0x1d41a && cp <= 0x1d433) return String.fromCharCode(97 + (cp - 0x1d41a)); // bold a-z
    if (cp >= 0x1d5d4 && cp <= 0x1d5ed) return String.fromCharCode(65 + (cp - 0x1d5d4)); // sans-bold A-Z
    if (cp >= 0x1d5ee && cp <= 0x1d607) return String.fromCharCode(97 + (cp - 0x1d5ee)); // sans-bold a-z
    if (cp >= 0x1d608 && cp <= 0x1d621) return String.fromCharCode(65 + (cp - 0x1d608)); // sans-italic A-Z
    if (cp >= 0x1d622 && cp <= 0x1d63b) return String.fromCharCode(97 + (cp - 0x1d622)); // sans-italic a-z
    if (cp >= 0x1d670 && cp <= 0x1d689) return String.fromCharCode(65 + (cp - 0x1d670)); // mono A-Z
    if (cp >= 0x1d68a && cp <= 0x1d6a3) return String.fromCharCode(97 + (cp - 0x1d68a)); // mono a-z
    if (cp >= 0x1d7ce && cp <= 0x1d7d7) return String.fromCharCode(48 + (cp - 0x1d7ce)); // bold 0-9
    if (cp >= 0x1d7e2 && cp <= 0x1d7eb) return String.fromCharCode(48 + (cp - 0x1d7e2)); // sans-bold 0-9
    return ch;
  }).join('');
}

// The tool's flow, in plain English. Fixed rather than per-episode because the
// four steps ARE the same four steps every week; only the purpose changes.
// Written at the reading level the LinkedIn rule asks for (short sentences, no
// jargon) — the same voice as linkedin_en.md.
const GUIDE_STEPS = [
  'Drop the file in. A PDF or a photo both work.',
  `Say where it is going. This one is "${topic.purpose}".`,
  'The parts to cover are marked for you. You can change any of them.',
  'Save. The file becomes a flat picture, so nothing is hidden underneath.'
];
const GUIDE_SHOT_TITLES = ['Step 1 — drop it in', 'Step 2 — say where it is going',
                           'Step 3 — check what will be covered', 'Step 4 — save it'];
const LINKEDIN_UTM = viaUrl('linkedin');

let guide = 'skipped';
{
  const coverQuestion = liBody
    ? plainify(liBody.split('\n').find((l) => l.trim())).trim()
    : `What do you cover before you send ${topic.doc || 'a document'}?`;

  const pages = [
    { kind: 'cover', title: coverQuestion,
      sub: 'SafeFile covers the personal details in a document. It runs in your browser, so the file never leaves your computer.' },
    { kind: 'problem', title: 'A black box is not always a redaction.',
      lede: 'Draw a black rectangle over a number in a PDF and the number is usually still there underneath.' }
  ];

  // Four step pages: real captures when we have them, diagrams when we do not.
  const haveShots = guideShots.length === 4;
  for (let i = 0; i < 4; i++) {
    pages.push(haveShots
      ? { kind: 'shot', title: GUIDE_SHOT_TITLES[i], lede: GUIDE_STEPS[i], image: guideShots[i].dataUri }
      : { kind: 'step', title: GUIDE_SHOT_TITLES[i], lede: GUIDE_STEPS[i], steps: GUIDE_STEPS, active: i });
  }

  pages.push({
    kind: 'cta',
    title: 'It\'s free. Try it and tell me what confused you.',
    body: 'No account, no upload. If you handle documents like this, the part that felt confusing is the most useful thing you can send me.',
    url: LINKEDIN_UTM
  });

  if (pages.length < GUIDE_MIN_PAGES || pages.length > GUIDE_MAX_PAGES) {
    // Structural, so it is a hard failure rather than a warning: a guide
    // outside the declared range is the deliverable being wrong, not a partial
    // success the way a missing recording is.
    console.error(`\nep${EP}: guide_en.pdf would be ${pages.length} pages, outside ${GUIDE_MIN_PAGES}–${GUIDE_MAX_PAGES}`);
    await browser.close();
    process.exit(1);
  }

  const pageDir = path.join(epDir, 'guide_en_pages');
  const pdfPath = path.join(epDir, 'guide_en.pdf');
  try {
    const gp = await browser.newPage({ viewport: { width: 1080, height: 1350 }, deviceScaleFactor: 1 });
    await gp.goto(pathToFileURL(GUIDE_TEMPLATE).href);
    await Promise.race([gp.evaluate(() => document.fonts.ready), gp.waitForTimeout(6000)]);

    const report = await gp.evaluate((pp) => window.SF_GUIDE(pp), pages);
    report.filter((r) => r.overflowed).forEach((r) =>
      warnings.push(`guide_en.pdf page ${r.i} (${r.kind}): text still overflows at the ${Math.round(r.scale * 100)}% floor — shorten the copy`));
    report.filter((r) => !r.overflowed && r.scale < 1).forEach((r) =>
      warnings.push(`guide_en.pdf page ${r.i} (${r.kind}): text was shrunk to ${Math.round(r.scale * 100)}% to fit`));

    // PNGs first, off the same DOM the PDF is paginated from, so a page and its
    // PNG cannot disagree about what it says.
    fs.rmSync(pageDir, { recursive: true, force: true });
    fs.mkdirSync(pageDir, { recursive: true });
    for (let i = 0; i < pages.length; i++) {
      const file = path.join(pageDir, `${String(i + 1).padStart(2, '0')}.png`);
      await gp.locator(`.page[data-index="${i + 1}"]`).screenshot({ path: file });
      const size = pngSize(file);
      if (size.width !== CAROUSEL_SIZE.width || size.height !== CAROUSEL_SIZE.height) {
        throw new Error(`guide_en_pages/${path.basename(file)} is ${size.width}×${size.height}, not 1080×1350`);
      }
    }

    // ONE call. `preferCSSPageSize: false` + explicit px: the CSS page box and
    // the PDF page box have to be the same number or the pages come out scaled.
    await gp.pdf({ path: pdfPath, width: '1080px', height: '1350px',
                   printBackground: true, margin: { top: 0, right: 0, bottom: 0, left: 0 } });
    await gp.close();

    const bytes = fs.statSync(pdfPath).size;
    // Counted from the file, not from `pages.length`. The point of recording it
    // is that the two can disagree — a stray `break-after` or a page that grew
    // past 1350px would paginate into more pages than we laid out, and the
    // first place anyone would notice is a LinkedIn upload.
    const pdfPages = countPdfPages(pdfPath);
    if (pdfPages !== pages.length) {
      throw new Error(`guide_en.pdf has ${pdfPages} pages, laid out ${pages.length} — the CSS page box and the PDF page box disagree`);
    }
    if (bytes > GUIDE_MAX_BYTES) {
      throw new Error(`guide_en.pdf is ${Math.round(bytes / 1024)}KB, over the ${GUIDE_MAX_BYTES / 1024 / 1024}MB cap`);
    }
    guide = `ok: ${pdfPages} pages, ${Math.round(bytes / 1024)}KB, ${haveShots ? 'real screenshots' : 'diagrams (no recording)'}`;
    process.stdout.write(`  guide_en.pdf  (${pdfPages} pages, ${Math.round(bytes / 1024)}KB, ${haveShots ? 'screenshots' : 'diagrams'})\n`);
  } catch (e) {
    // Partial by design, like the demo: four good files are not thrown away
    // because the fifth did not render. The manifest says what happened.
    guide = `failed: ${e.message}`;
    warnings.push(`guide_en.pdf: ${e.message}`);
    process.stdout.write(`  guide_en.pdf FAILED: ${e.message}\n`);
  }
}

/* ── shorts.mp4 — the YouTube Shorts cut ──────────────────────────────────── */
/*
 * 1080×1920, 30 seconds, structure from the marketing plan §1:
 *
 *   0– 5s  the pain, one sentence, as big as it will go
 *   5–10s  why it happens
 *  10–25s  the fix — real screen recording (track A) or three comparison
 *          cards (track B, which has no tool flow to record)
 *  25–30s  the result + the landing URL
 *
 * ── Why this is not the GIF with a different aspect ratio ──────────────────
 *
 * demo.gif is a 720×1280 screen recording for X: it shows the tool working to
 * someone who already clicked. Shorts has to stop a thumb, so the first five
 * seconds are not the tool at all — they are the reader's problem. The two
 * are different films and both are kept.
 *
 * ── Everything is burned in ────────────────────────────────────────────────
 *
 * No subtitle track. Shorts autoplay muted and the platform does not reliably
 * render soft subtitles, so text that is not in the pixels is text nobody
 * reads. The cards carry their own text; the screen section gets a caption bar
 * injected into the PAGE before capture, which also keeps the Japanese font
 * inside the browser instead of hardcoding a font path into an ffmpeg filter.
 */
const SHORTS = { w: 1080, h: 1920, fps: 30, maxSeconds: 30 };
const SHORTS_SEGMENTS = { pain: 5, why: 5, fix: 15, done: 5 };

let shorts = 'skipped';
{
  const outDir = path.join(epDir, '.shorts');
  const mp4 = path.join(epDir, 'shorts.mp4');
  try {
    fs.rmSync(outDir, { recursive: true, force: true });
    fs.mkdirSync(outDir, { recursive: true });

    /* ── the three cards ───────────────────────────────────────────────── */
    const cardPage = await browser.newPage({ viewport: { width: SHORTS.w, height: SHORTS.h }, deviceScaleFactor: 1 });
    await cardPage.goto(pathToFileURL(SHORTS_TEMPLATE).href);
    await Promise.race([cardPage.evaluate(() => document.fonts.ready), cardPage.waitForTimeout(6000)]);

    // The pain line is fm.hook — the same sentence that opens the X thread,
    // which S10 made a rule about. One opener per episode, written once.
    const cards = [
      ['pain', { tag: 'よくある差し戻し', text: fm.hook }],
      ['why', { text: '黒い四角を重ねただけでは、\n下の文字が残ることがあります。',
                note: 'PDFの文字層はコピーできてしまいます。' }]
    ];
    if (topic.track === 'A') {
      cards.push(['done', { text: '画像に平坦化されるので、\n黒塗りの下に原文は残りません。',
                            note: 'ファイルはブラウザの中だけで処理されます。',
                            url: viaUrl('youtube') }]);
    } else {
      // Track B: the middle 15s is comparison cards instead of a recording.
      cards.splice(2, 0, ['compare', { text: '隠し方で結果が変わります', items: [
        { ok: false, txt: '付箋を貼って撮影 — 光で透けることがある' },
        { ok: false, txt: '画像編集アプリで黒い四角 — 文字層が残る' },
        { ok: true, txt: '画像に平坦化 — 下に原文が残らない' }
      ] }]);
      cards.push(['done', { text: '提出先の指示に合わせて\n隠す範囲を選べます。',
                            note: 'ファイルはブラウザの中だけで処理されます。',
                            url: viaUrl('youtube') }]);
    }

    const cardFiles = [];
    for (let i = 0; i < cards.length; i++) {
      const [kind, data] = cards[i];
      const fit = await cardPage.evaluate(([k, d]) => window.SF_CARD(k, d), [kind, data]);
      if (fit.overflowed) warnings.push(`shorts card ${i + 1} (${kind}): text still overflows at the ${Math.round(fit.scale * 100)}% floor — shorten it`);
      const f = path.join(outDir, `card${i + 1}_${kind}.png`);
      await cardPage.locator('#card').screenshot({ path: f });
      const size = pngSize(f);
      if (size.width !== SHORTS.w || size.height !== SHORTS.h) {
        throw new Error(`${path.basename(f)} is ${size.width}×${size.height}, not ${SHORTS.w}×${SHORTS.h}`);
      }
      cardFiles.push({ file: f, kind });
    }
    await cardPage.close();

    /* ── the fix section ───────────────────────────────────────────────── */
    /* Track A records the tool at a PHONE viewport with deviceScaleFactor 2,
     * so the frames come out 1080×1920 natively — scaling a 1080-wide desktop
     * layout down to a phone frame would make the app's own text unreadable,
     * which is the mistake the guide PDF already made once (S9 §E). */
    let fixFrames = [];
    let srv;
    if (topic.track === 'A' && !noDemo && FIXTURE_FOR_DOC[topic.doc]) {
      try {
        srv = await startServer();
        const port = srv.address().port;
        const vp = await browser.newPage({
          viewport: { width: SHORTS.w / 2, height: SHORTS.h / 2 }, deviceScaleFactor: 2
        });
        const url = `http://127.0.0.1:${port}/safe/?lang=ja&purpose=${topic.purpose}&from=direct`;
        const resp = await vp.goto(url, { waitUntil: 'load' });
        if (!resp || !resp.ok()) throw new Error(`${url} returned ${resp ? resp.status() : 'no response'}`);
        if (!(await vp.locator('#fileInput').count())) throw new Error('no #fileInput — wrong document?');

        // Caption bar, injected into the page (not drawn by ffmpeg) so the
        // Japanese font stays inside the browser.
        await vp.evaluate(() => {
          const bar = document.createElement('div');
          bar.id = '__scap';
          bar.style.cssText = 'position:fixed;left:0;right:0;bottom:0;z-index:9999;'
            + 'background:rgba(23,20,15,.94);color:#fff;'
            + 'font:700 25px/1.5 "Hiragino Kaku Gothic ProN","Noto Sans JP",sans-serif;'
            + 'padding:22px 24px;white-space:pre-line;min-height:104px';
          document.body.appendChild(bar);
          window.__scap = (t) => { bar.textContent = t; };
        });
        const caps = captions.length === 3 ? captions : [
          '① PDF・写真をドラッグ',
          `② 「提出目的：${topic.purpose}」を選ぶ`,
          '③ ダウンロード — 下に原文は残りません'
        ];
        const setCap = (t) => vp.evaluate((x) => window.__scap(x), t);

        let n = 0;
        const grab = async (count) => {
          for (let i = 0; i < count; i++) {
            await vp.screenshot({ path: path.join(outDir, `fix${String(n).padStart(3, '0')}.png`) });
            n++;
            if (i < count - 1) await vp.waitForTimeout(400);
          }
        };

        await setCap(caps[0]);
        await grab(4);
        await vp.setInputFiles('#fileInput', path.join(FIXTURES, FIXTURE_FOR_DOC[topic.doc]));
        await vp.waitForFunction(
          () => Array.isArray(pages) && pages.length > 0 && document.getElementById('docWrap').style.display === 'flex',
          { timeout: 300000 }
        );
        await setCap(caps[1]);
        await vp.locator('#jpBar').scrollIntoViewIfNeeded().catch(() => {});
        await grab(5);
        await vp.click('#btnMake');
        await vp.waitForFunction(() => document.getElementById('result').style.display === 'block', { timeout: 120000 });
        await setCap(caps[2]);
        await vp.locator('#result').scrollIntoViewIfNeeded().catch(() => {});
        await vp.waitForTimeout(400);
        await grab(6);
        await vp.close();
        fixFrames = fs.readdirSync(outDir).filter((f) => f.startsWith('fix')).sort();
        if (fixFrames.length < 6) throw new Error(`only ${fixFrames.length} fix frames`);
      } catch (e) {
        // Partial by design: a failed recording falls back to comparison cards
        // rather than losing the whole Short.
        warnings.push(`shorts: screen recording failed (${e.message}) — using comparison cards instead`);
        fixFrames = [];
      } finally {
        if (srv) srv.close();
      }
    }

    /* ── stitch ────────────────────────────────────────────────────────── */
    const segs = [];
    const seg = (file, seconds) => {
      const out = path.join(outDir, `seg${segs.length}.mp4`);
      run('ffmpeg', ['-y', '-loop', '1', '-i', file, '-t', String(seconds),
        '-r', String(SHORTS.fps), '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
        '-vf', `scale=${SHORTS.w}:${SHORTS.h}:force_original_aspect_ratio=decrease,pad=${SHORTS.w}:${SHORTS.h}:(ow-iw)/2:(oh-ih)/2:color=0xF7F5EF`,
        out]);
      segs.push(out);
    };

    const painCard = cardFiles.find((c) => c.kind === 'pain');
    const whyCard = cardFiles.find((c) => c.kind === 'why');
    const cmpCard = cardFiles.find((c) => c.kind === 'compare');
    const doneCard = cardFiles.find((c) => c.kind === 'done');

    seg(painCard.file, SHORTS_SEGMENTS.pain);
    seg(whyCard.file, SHORTS_SEGMENTS.why);

    if (fixFrames.length) {
      // The recording, stretched to exactly the fix window so the total stays
      // at 30s whatever the frame count turned out to be.
      const fps = fixFrames.length / SHORTS_SEGMENTS.fix;
      const out = path.join(outDir, `seg${segs.length}.mp4`);
      run('ffmpeg', ['-y', '-framerate', String(fps), '-i', path.join(outDir, 'fix%03d.png'),
        '-r', String(SHORTS.fps), '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
        '-vf', `scale=${SHORTS.w}:${SHORTS.h}:force_original_aspect_ratio=decrease,pad=${SHORTS.w}:${SHORTS.h}:(ow-iw)/2:(oh-ih)/2:color=0x111111`,
        out]);
      segs.push(out);
    } else if (cmpCard) {
      seg(cmpCard.file, SHORTS_SEGMENTS.fix);
    } else {
      // Track A whose recording failed and which has no comparison card: hold
      // the why card. Stated in the manifest rather than silently shortened.
      seg(whyCard.file, SHORTS_SEGMENTS.fix);
      warnings.push('shorts: no fix footage and no comparison card — held the why card for the middle 15s');
    }
    seg(doneCard.file, SHORTS_SEGMENTS.done);

    const listFile = path.join(outDir, 'concat.txt');
    fs.writeFileSync(listFile, segs.map((f) => `file '${f.replace(/'/g, "'\\\\''")}'`).join('\n') + '\n');
    run('ffmpeg', ['-y', '-f', 'concat', '-safe', '0', '-i', listFile, '-c', 'copy', '-movflags', '+faststart', mp4]);

    /* ── verify from the FILE, not from what we asked for ──────────────── */
    const probe = spawnSync('ffprobe', ['-v', 'error', '-select_streams', 'v:0',
      '-show_entries', 'stream=width,height:format=duration', '-of', 'json', mp4], { encoding: 'utf8' });
    if (probe.status !== 0) throw new Error(`ffprobe failed: ${(probe.stderr || '').slice(-200)}`);
    const meta = JSON.parse(probe.stdout);
    const st = meta.streams[0];
    const dur = Number(meta.format.duration);
    if (st.width !== SHORTS.w || st.height !== SHORTS.h) {
      throw new Error(`shorts.mp4 is ${st.width}×${st.height}, not ${SHORTS.w}×${SHORTS.h}`);
    }
    if (!(dur > 0) || dur > SHORTS.maxSeconds + 0.5) {
      throw new Error(`shorts.mp4 is ${dur.toFixed(2)}s, over the ${SHORTS.maxSeconds}s cap`);
    }

    /* ── title and description ─────────────────────────────────────────── */
    // Title: question form, JA, <=20 chars + 3 hashtags (marketing plan §6-3).
    // Taken from topics.json rather than invented here, and TRUNCATION IS NOT
    // SILENT — an over-length title is reported the same way an over-length
    // tweet is, because a headline cut at a byte boundary is one the author
    // did not write.
    const shortsTitle = (topic.shorts_title_ja || fm.title).trim();
    if ([...shortsTitle].length > 20) {
      warnings.push(`shorts_title_ja: ${[...shortsTitle].length}字 — 20字以内が望ましい(topics.json に shorts_title_ja を足す)`);
    }
    const tags = (topic.shorts_tags || ['#黒塗り', '#個人情報', '#提出書類']).slice(0, 3);
    fs.writeFileSync(path.join(epDir, 'shorts_title_ja.txt'), `${shortsTitle} ${tags.join(' ')}\n`);
    fs.writeFileSync(path.join(epDir, 'shorts_desc_ja.txt'), [
      fm.hook,
      '',
      ...fm.bullets.map((b, i) => `${['①', '②', '③'][i]}${b}`),
      '',
      MUST_SENTENCE,
      '',
      `くわしく: ${BASE_URL}/ja/blog/${slugFor(topic)}?via=youtube&ep=ep${EPP}`,
      `試す: ${viaUrl('youtube')}`,
      '',
      tags.join(' ')
    ].join('\n') + '\n');

    const kb = Math.round(fs.statSync(mp4).size / 1024);
    shorts = `ok: ${dur.toFixed(1)}s, ${st.width}x${st.height}, ${kb}KB, ${fixFrames.length ? `${fixFrames.length} recorded frames` : 'cards only'}`;
    process.stdout.write(`  shorts.mp4  (${dur.toFixed(1)}s, ${st.width}x${st.height}, ${kb}KB, ${fixFrames.length ? 'recording' : 'cards'})\n`);
    fs.rmSync(outDir, { recursive: true, force: true });
  } catch (e) {
    shorts = `failed: ${e.message}`;
    warnings.push(`shorts.mp4: ${e.message}`);
    process.stdout.write(`  shorts.mp4 FAILED: ${e.message}\n`);
    // Intermediates are left behind on failure — they are the only evidence of
    // how far the build got, same rule as the demo frames.
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
  // Strip any suffix a previous --no-demo run added before adding one. Without
  // this, three rebuilds produce three copies of the note and the manifest
  // grows a sentence per run.
  const base = prevManifest.demo.replace(/( \(carried over — this run used --no-demo\))+$/, '');
  return `${base} (carried over — this run used --no-demo)`;
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
  files: ['post_ja.md', 'post_en.md', 'linkedin_en.md', 'summary_ko.md', 'x_thread.md',
          'carousel_1.png', 'carousel_2.png', 'carousel_3.png', 'demo.gif', 'demo.mp4', 'guide_en.pdf', 'shorts.mp4']
    .map(fileEntry).filter(Boolean),
  demo: demoForManifest(),
  guide: guide,
  shorts: shorts,
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

/* Page count read out of the PDF itself.
 *
 * `/Type /Pages … /Count N` is the page tree root. Counting `/Type /Page`
 * occurrences instead would be wrong in both directions — it matches the
 * `/Pages` node too (it starts with `/Page`), and a compressed object stream
 * hides the rest. Chromium writes this file, uncompressed enough that /Count is
 * in the clear; if a future Chromium changes that, `counted === null` surfaces
 * as a loud failure rather than as a wrong number.
 */
function countPdfPages(file) {
  const buf = fs.readFileSync(file).toString('latin1');
  const counts = [...buf.matchAll(/\/Type\s*\/Pages[^>]*?\/Count\s+(\d+)/g)].map((m) => Number(m[1]));
  if (!counts.length) {
    const alt = [...buf.matchAll(/\/Count\s+(\d+)/g)].map((m) => Number(m[1]));
    if (!alt.length) throw new Error('could not read a page count out of the PDF');
    return Math.max(...alt);
  }
  return Math.max(...counts);
}

function run(bin, args) {
  const r = spawnSync(bin, args, { encoding: 'utf8' });
  if (r.error) throw new Error(`${bin} not available: ${r.error.message}`);
  if (r.status !== 0) throw new Error(`${bin} exited ${r.status}: ${(r.stderr || '').split('\n').slice(-4).join(' ')}`);
}
