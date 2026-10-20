#!/usr/bin/env node
/*
 * Render the COMPOSED OUTPUT of a fixture to out/render_<name>.png so a human
 * can look at where the bands actually landed.
 *
 * This is an inspection aid, NOT a gate — run.mjs owns the gating. It exists
 * because the two defects it caught could not be caught by a coverage number:
 *   - a 保険者番号 whose leading digit survived by ~7px (coverage still 96%),
 *   - a 二次元コード band offset off the printed block (coverage still 80%,
 *     which passed a 60% gate while a real QR would have stayed decodable).
 * A fraction says how much is covered; only the picture says WHERE.
 *
 * Usage: node render.mjs <purpose> <file> [file …]
 *        node render.mjs identity_submit fixtures/jp/shikaku_kakuninsho/kenpo.png
 *   purpose: identity_submit | my_number_procedure | bid_attachment | consult_share
 *            (ignored for non-Japanese documents)
 */
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.resolve(__dirname, '..', '..', 'public');
const OUT = path.join(__dirname, 'out');
fs.mkdirSync(OUT, { recursive: true });
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json', '.txt': 'text/plain' };

const srv = await new Promise(r => {
  const s = http.createServer((q, res) => {
    let p = decodeURIComponent(q.url.split('?')[0]);
    if (p === '/') p = '/index.html';
    const fp = path.join(PUBLIC, p);
    if (!fp.startsWith(PUBLIC) || !fs.existsSync(fp) || fs.statSync(fp).isDirectory()) { res.writeHead(404); res.end('nf'); return; }
    res.writeHead(200, { 'content-type': MIME[path.extname(fp)] || 'application/octet-stream' });
    fs.createReadStream(fp).pipe(res);
  });
  s.listen(0, '127.0.0.1', () => r(s));
});

const [purpose, ...files] = process.argv.slice(2);
if (!files.length) { console.error('usage: node render.mjs <purpose> <file> [file …]'); process.exit(2); }

const browser = await chromium.launch({ channel: 'chrome', headless: true });
const ctx = await browser.newContext({ viewport: { width: 1300, height: 1000 }, locale: 'ja-JP' });
const page = await ctx.newPage();
const errs = [];
page.on('pageerror', e => { if (!/ServiceWorker/.test(e.message)) errs.push(e.message); });
await page.goto(`http://127.0.0.1:${srv.address().port}/safe/index.html`, { waitUntil: 'networkidle' });
await page.evaluate(() => { LANG = 'ja'; applyLang(); });

for (const f of files) {
  await page.evaluate(() => { if (pages.length) resetAll(); });
  await page.setInputFiles('#fileInput', f);
  await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0, { timeout: 300000 });
  await page.waitForTimeout(400);
  const cls = await page.evaluate(p => { if (jpState.cls) jpSetPurpose(p); return jpState.cls && jpState.cls.doc; }, purpose);
  const n = await page.evaluate(() => pages.length);
  for (let i = 0; i < n; i++) {
    const b64 = await page.evaluate(pi => composePage(pi).toDataURL('image/png').split(',')[1], i);
    const name = `render_${path.basename(path.dirname(f))}_${path.basename(f).replace(/\.\w+$/, '')}${n > 1 ? '_p' + (i + 1) : ''}.png`;
    fs.writeFileSync(path.join(OUT, name), Buffer.from(b64, 'base64'));
    console.log(`${name}  (class: ${cls || 'none'})`);
  }
}
if (errs.length) { console.error('page errors:', errs); process.exitCode = 1; }
await browser.close(); srv.close();
