#!/usr/bin/env node
/*
 * Builds public/safe/brand/og_1200x630.png — the social preview card for the
 * three JP landing pages.
 *
 *   node docs/jp/brand/make_og.mjs
 *
 * Why it exists: LinkedIn previewed /safe/jp/nyusatsu/ as "DocPack - Image
 * Compression & PDF Conversion" with the old SlimFile icon, because the pages
 * pointed og:image at /safe/icon-512.png — a 512×512 app icon. Social cards are
 * 1.91:1; a square icon is letterboxed or cropped, and either way the preview
 * said nothing about what the page is.
 *
 * Rendered through the same chromium the rest of this repo uses (the golden
 * harness's install) rather than drawn with PIL, so the Japanese text is laid
 * out by a real text engine. Tokens come from docs/jp/brand/README.md:
 * INK #1A1613 / CREAM #F6F4EE / SAND #E8E3D8 / YELLOW #FFD84D.
 *
 * ⚠️ The font is whatever the rendering machine has. This is the same open
 * backlog item as the carousel template (s6b B-x, "캐러셀 폰트 고정"): the file is
 * committed, so a machine with different fonts does not change what ships —
 * but re-running this on such a machine would. Check the output before
 * committing a regenerated card.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const OUT = path.join(REPO, 'public', 'safe', 'brand', 'og_1200x630.png');

const INK = '#1A1613', CREAM = '#F6F4EE', SAND = '#E8E3D8', YELLOW = '#FFD84D';

// The logo, inline — same path as public/safe/brand/icon.svg (logo B2: a cream
// S on ink with one segment of its tail detached, the "covered by a black bar"
// idea).
const LOGO = `
<svg viewBox="0 0 400 400" width="128" height="128" xmlns="http://www.w3.org/2000/svg">
  <rect width="400" height="400" rx="72" fill="${CREAM}"/>
  <path d="M296 104 H154 a36 36 0 0 0 0 72 H246 a50 50 0 0 1 0 100 H214"
        fill="none" stroke="${INK}" stroke-width="58" stroke-linecap="round"/>
  <rect x="104" y="247" width="80" height="58" rx="29" fill="${INK}"/>
</svg>`;

const HTML = `<!doctype html><meta charset="utf-8">
<style>
  @page { size: 1200px 630px; }
  html, body { margin: 0; padding: 0; }
  body {
    width: 1200px; height: 630px; background: ${INK}; color: ${CREAM};
    font-family: "Hiragino Sans", "Noto Sans CJK JP", "Noto Sans JP",
                 "Yu Gothic", system-ui, sans-serif;
    display: flex; flex-direction: column; justify-content: center;
    padding: 0 86px; box-sizing: border-box; position: relative;
  }
  .row { display: flex; align-items: center; gap: 28px; margin-bottom: 48px; }
  .name { font-size: 58px; font-weight: 800; letter-spacing: -0.01em; }
  h1 { font-size: 62px; font-weight: 800; line-height: 1.34; margin: 0; letter-spacing: -0.02em; }
  /* The redaction bar is the product, so it is the one graphic device on the
     card — a cream block sitting where a number would be. */
  .bar { background: ${CREAM}; border-radius: 10px; display: inline-block;
         width: 232px; height: 54px; vertical-align: -8px; margin: 0 6px; }
  p { font-size: 31px; line-height: 1.55; margin: 44px 0 0; color: ${SAND}; opacity: 0.86; }
  .rule { position: absolute; left: 0; bottom: 0; height: 12px; width: 100%;
          background: ${YELLOW}; }
</style>
<div class="row">${LOGO}<div class="name">SafeFile</div></div>
<h1>提出先のルールどおりに、<br>自動で正しく<span class="bar"></span></h1>
<p>ファイルはブラウザの外に出ません。登録も不要です。</p>
<div class="rule"></div>`;

const pick = (m) => (m && m.chromium) ? m : (m && m.default) || {};
const local = path.join(REPO, 'test', 'safe', 'node_modules', 'playwright', 'index.js');
const { chromium } = pick(await import(pathToFileURL(local).href));
if (!chromium) throw new Error('playwright not found at test/safe/node_modules');

const browser = await chromium.launch({ channel: 'chrome' });
const page = await browser.newPage({ viewport: { width: 1200, height: 630 }, deviceScaleFactor: 1 });
await page.setContent(HTML, { waitUntil: 'networkidle' });
await page.screenshot({ path: OUT });
await browser.close();

// Read the dimensions back out of the PNG's own IHDR rather than trusting the
// viewport we asked for — the same check make_episode.mjs does on the carousel,
// and for the same reason: a declared size and a file on disk are two different
// facts, and only one of them is what gets shared.
const buf = fs.readFileSync(OUT);
if (buf.toString('ascii', 12, 16) !== 'IHDR') throw new Error('no IHDR where one must be');
const w = buf.readUInt32BE(16), h = buf.readUInt32BE(20);
if (w !== 1200 || h !== 630) throw new Error(`og card is ${w}x${h}, must be 1200x630`);
console.log(`${path.relative(REPO, OUT)}  ${w}x${h}  ${(buf.length / 1024).toFixed(0)}KB`);
