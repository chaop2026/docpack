/*
 * Browser, local server and ffmpeg helpers, shared by make_episode.mjs and
 * make_short.mjs (2026-11-16).
 *
 * ── Why these moved out of make_episode.mjs ────────────────────────────────
 *
 * make_short.mjs needs every one of them: it drives the same page, records the
 * same flow and probes the same files. Copying them would mean two recorders
 * that start identical and drift — and the drift would be invisible, because
 * each script would keep passing its own expectations. This repository already
 * has the rule written down for the guard rules and for JP_RULES: a rule (or a
 * measurement) that lives in two places is one that can be changed in one of
 * them.
 *
 * Nothing here decides anything about an episode. It opens browsers, serves
 * files on loopback, runs ffmpeg and reads bytes back off disk.
 */
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

/* ── playwright ───────────────────────────────────────────────────────────── */
/*
 * Playwright is a CommonJS package, so a dynamic import of its entry file lands
 * the exports under `.default` rather than as named exports. Reading `chromium`
 * off the namespace gives `undefined` and the failure surfaces thirty lines
 * later as "cannot read properties of undefined" — measured.
 */
export async function loadPlaywright(repo) {
  const pick = (mod) => (mod && mod.chromium) ? mod : (mod && mod.default) || {};

  try {
    const mod = pick(await import('playwright'));
    if (mod.chromium) return mod;
  } catch { /* not installed at this level — fall through */ }

  // The golden harness owns the install (test/safe/node_modules); these scripts
  // borrow it rather than adding a second copy that can drift in version.
  const local = path.join(repo, 'test', 'safe', 'node_modules', 'playwright', 'index.js');
  if (fs.existsSync(local)) {
    const mod = pick(await import(pathToFileURL(local).href));
    if (mod.chromium) return mod;
  }
  throw new Error('playwright not found. Install it where the golden harness lives:\n'
    + '  cd test/safe && npm i && npx playwright install chrome');
}

/* ── local server ─────────────────────────────────────────────────────────── */
const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.ico': 'image/x-icon',
  '.webmanifest': 'application/manifest+json', '.txt': 'text/plain', '.pdf': 'application/pdf',
  '.woff2': 'font/woff2'
};

/*
 * Same shape as the golden harness's server: `publicDir` at the root, the
 * fixture tree under /__fx/. Loopback only — a recording must never touch
 * production.
 */
export function startServer({ publicDir, fixturesDir }) {
  return new Promise((resolve) => {
    const srv = http.createServer((req, res) => {
      let p = decodeURIComponent(req.url.split('?')[0]);
      if (p === '/') p = '/index.html';
      const root = p.startsWith('/__fx/') ? fixturesDir : publicDir;
      if (p.startsWith('/__fx/')) p = p.slice(5);
      let fp = path.join(root, p);
      /* Containment by path.relative, not by string prefix.
       *
       * `fp.startsWith(root)` — what this did until 2026-11-16 — also accepts
       * a SIBLING whose name merely begins with the root's: "/app/public-old"
       * passes startsWith("/app/public"). Loopback-only makes the risk small,
       * not the check correct, and this helper now has three callers.
       * Pre-existing; cross-review raised it. */
      const inside = (f) => {
        const rel = path.relative(root, f);
        return rel !== '' && !rel.startsWith('..') && !path.isAbsolute(rel);
      };
      // Serve <dir>/index.html for a directory request. The real app relies on
      // ActionDispatch::Static doing exactly this for /safe/, so a server that
      // 404s here records a demo of an error page — which is what the first run
      // of the episode script actually produced.
      if (inside(fp) && fs.existsSync(fp) && fs.statSync(fp).isDirectory()) fp = path.join(fp, 'index.html');
      if (!inside(fp) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end('nf'); return; }
      res.writeHead(200, { 'content-type': MIME[path.extname(fp)] || 'application/octet-stream' });
      fs.createReadStream(fp).pipe(res);
    });
    srv.listen(0, '127.0.0.1', () => resolve(srv));
  });
}

/* ── driving the tool ─────────────────────────────────────────────────────── */
/*
 * The four alpha types classify and auto-mask, so #btnMake enables itself.
 * The S10 demo props do not classify — nothing is marked, #btnMake stays
 * disabled, and the recording used to die on a 30s click timeout.
 *
 * Pressing 「すべて非公開」 is not a workaround: for an unclassified document
 * that IS the flow (marketing plan §0-5, "manual region select"), and it is
 * what the article tells the reader to do. Clicked only when the button is
 * actually disabled, so the alpha recordings are unchanged.
 */
export async function ensureMaskable(page) {
  const enabled = await page.$eval('#btnMake', (b) => !b.disabled).catch(() => false);
  if (enabled) return 'auto';
  // If the bulk control is disabled too, the tool found nothing it can mask on
  // this document and no amount of waiting changes that. Say so, rather than
  // letting a 30s waitForFunction time out with Playwright's generic message —
  // measured on ep07, whose 源泉徴収票 prop OCRs poorly under the watermark.
  const bulkReady = await page.$eval('#bulkBtns button[data-mode="no"]', (b) => !b.disabled).catch(() => false);
  if (!bulkReady) throw new Error('the tool detected nothing maskable on this document (bulk control is disabled)');

  await page.click('#bulkBtns button[data-mode="no"]').catch(() => {});
  await page.waitForFunction(() => !document.getElementById('btnMake').disabled, { timeout: 15000 });
  return 'bulk';
}

/*
 * How many regions the tool actually covered.
 *
 * Counted from the page's own state, not from the success banner: the banner
 * is localised prose and parsing it would break the first time the wording
 * changes. `entities` is the array the tool masks from — the same predicate
 * updateMake() uses to enable the button.
 */
export async function maskedCount(page) {
  return page.evaluate(() => {
    try {
      return entities.filter((e) => isOn(e) && e.mode !== 'ok' && located(e)).length;
    } catch (e) { return -1; }
  });
}

/* ── bytes on disk ────────────────────────────────────────────────────────── */
/*
 * The IHDR, not what the browser was asked for — the point of recording a size
 * is that the two can disagree (deviceScaleFactor, a CSS edit, a clipped
 * element), and the first place the disagreement shows is a cropped upload.
 */
export function pngSize(file) {
  const head = Buffer.alloc(24);
  const fd = fs.openSync(file, 'r');
  try { fs.readSync(fd, head, 0, 24, 0); } finally { fs.closeSync(fd); }
  if (head.toString('hex', 0, 8) !== '89504e470d0a1a0a') throw new Error(`${path.basename(file)} is not a PNG`);
  if (head.toString('ascii', 12, 16) !== 'IHDR') throw new Error(`${path.basename(file)} has no IHDR where one must be`);
  return { width: head.readUInt32BE(16), height: head.readUInt32BE(20) };
}

export function run(bin, args) {
  const r = spawnSync(bin, args, { encoding: 'utf8' });
  if (r.error) throw new Error(`${bin} not available: ${r.error.message}`);
  if (r.status !== 0) throw new Error(`${bin} exited ${r.status}: ${(r.stderr || '').split('\n').slice(-4).join(' ')}`);
}

/*
 * Width, height and duration read out of the finished file with ffprobe.
 * Asked of the artifact rather than of the pipeline that produced it: a filter
 * graph that silently did something else still reports success.
 */
export function probeVideo(file) {
  const probe = spawnSync('ffprobe', [ '-v', 'error', '-select_streams', 'v:0',
    '-show_entries', 'stream=width,height:format=duration', '-of', 'json', file ], { encoding: 'utf8' });
  if (probe.status !== 0) throw new Error(`ffprobe failed: ${(probe.stderr || '').slice(-200)}`);
  const meta = JSON.parse(probe.stdout);
  const st = meta.streams && meta.streams[0];
  if (!st) throw new Error('ffprobe found no video stream');
  return { width: st.width, height: st.height, duration: Number(meta.format.duration) };
}

/* A file:// data URI, so a page can show an image without the browser needing
 * to resolve a path relative to a template it was not loaded from. */
export function dataUri(file) {
  const ext = path.extname(file).toLowerCase();
  const mime = MIME[ext] || 'application/octet-stream';
  return `data:${mime};base64,${fs.readFileSync(file).toString('base64')}`;
}
