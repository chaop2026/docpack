#!/usr/bin/env node
/*
 * Screenshots for the s8 report: the three imported JP packages as seen in the
 * admin preview, plus the public article.
 *
 *   node scripts/content/shoot_samples.mjs
 *
 * Borrows the golden harness's playwright install (test/safe/node_modules)
 * rather than adding a second copy that can drift in version — same reasoning
 * as make_episode.mjs.
 *
 * The admin pages are behind a session password, so this logs in first. The
 * password comes from ADMIN_PASSWORD or falls back to the development default
 * the app itself uses; nothing is printed.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const OUT = path.join(REPO, 'docs', 'jp', 's8_samples');
const BASE = process.env.BASE || 'http://localhost:3001';
const PASSWORD = process.env.ADMIN_PASSWORD || 'docpack2025';

const pick = (mod) => (mod && mod.chromium) ? mod : (mod && mod.default) || {};
const local = path.join(REPO, 'test', 'safe', 'node_modules', 'playwright', 'index.js');
const { chromium } = pick(await import(pathToFileURL(local).href));
if (!chromium) throw new Error('playwright not found at test/safe/node_modules');

fs.mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({ channel: 'chrome' });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 1000 }, deviceScaleFactor: 1 });
const page = await ctx.newPage();

const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));

// Fail loudly on a non-200 rather than screenshotting an error page. A harness
// that photographs a 404 produces a report that looks like evidence.
async function go(url, label) {
  const res = await page.goto(url, { waitUntil: 'networkidle' });
  const code = res ? res.status() : 0;
  if (code !== 200) throw new Error(`${label}: ${url} returned ${code}, expected 200`);
  return code;
}

await go(`${BASE}/admin/login`, 'login');
await page.fill('#password', PASSWORD);
await Promise.all([
  page.waitForNavigation({ waitUntil: 'networkidle' }).catch(() => {}),
  page.click('input[type="submit"]')
]);
if (page.url().includes('/admin/login')) {
  // Report what the page says rather than guessing. The password has a
  // development fallback, so "wrong password" and "the form moved" look the
  // same from out here.
  const flash = await page.textContent('.admin-flash').catch(() => null);
  throw new Error(`admin login failed (url=${page.url()}, flash=${JSON.stringify(flash)})`);
}

for (const ep of [1, 2, 3]) {
  await go(`${BASE}/admin/jp/packages/${ep}`, `package ep${ep}`);
  // The page must actually be the package page, not a redirect that happened
  // to return 200 — assert a marker before shooting.
  await page.waitForSelector('[data-jp-package]', { timeout: 5000 });
  const file = path.join(OUT, `admin_package_ep${String(ep).padStart(2, '0')}.png`);
  await page.screenshot({ path: file, fullPage: true });
  console.log(`  ${path.relative(REPO, file)}`);
}

// The public article, at its canonical URL.
const slug = process.env.SAMPLE_SLUG;
if (slug) {
  await go(`${BASE}/ja/blog/${slug}`, 'public article');
  const file = path.join(OUT, 'public_ja_article_ep01.png');
  await page.screenshot({ path: file, fullPage: true });
  console.log(`  ${path.relative(REPO, file)}`);
}

await browser.close();
if (errors.length) {
  console.error('\nJS errors on the pages shot:');
  errors.forEach((e) => console.error('  - ' + e));
  process.exit(1);
}
console.log('\nno JS errors');
