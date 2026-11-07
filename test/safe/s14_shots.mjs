#!/usr/bin/env node
/*
 * S14 — screenshots for the three naming/market fixes.
 *
 *   node test/safe/s14_shots.mjs [base]      # default http://localhost:3001
 *
 * Writes, at 1x:
 *   docs/autorun/s14_01_after_sample.png  ja, after 「サンプル文書で試す」 — the
 *     covered rows now name their field
 *   docs/autorun/s14_02_footer.png        ja, the recommended-services block
 *   docs/autorun/s14_03_ko.png            ko regression — unchanged
 *
 * Same contract as s13_shots.mjs: assert the page reached the state BEFORE
 * shooting, because a timeout that photographs an empty dropzone looks exactly
 * like a passing capture.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const mod = await import('playwright');
const { chromium } = mod.default ?? mod;   // playwright is CJS: chromium hides under .default
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, '..', '..', 'docs', 'autorun');
const BASE = process.argv[2] || 'http://localhost:3001';

fs.mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ channel: 'chrome' });
const errs = [];

async function open(url) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 1600 }, deviceScaleFactor: 1 });
  page.on('pageerror', e => errs.push(String(e)));
  const res = await page.goto(url, { waitUntil: 'load' });
  if (!res || res.status() !== 200) throw new Error(`${url} → ${res && res.status()}`);
  await page.waitForSelector('#btnSample');
  return page;
}
async function sample(page) {
  await page.click('#btnSample');
  await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0
    && document.getElementById('docWrap').style.display === 'flex', { timeout: 40000 });
  await page.waitForTimeout(600);
}

// ── ja: sample loaded, rows named ────────────────────────────────────────────
const ja = await open(`${BASE}/safe/?lang=ja&purpose=bid_attachment&from=nyusatsu`);
await sample(ja);
const jaState = await ja.evaluate(() => ({
  file: document.getElementById('fileName').textContent,
  doc: jpState.cls && jpState.cls.doc,
  legalFld: [...document.querySelectorAll('.sec-legal .fld')].map(n => n.textContent),
  keepFld: [...document.querySelectorAll('.sec-keep .fld')].map(n => n.textContent),
  cards: [...document.querySelectorAll('.partner-card')].filter(a => a.offsetParent !== null)
    .map(a => a.querySelector('strong').textContent.trim()),
}));
if (jaState.doc !== 'shikaku_kakuninsho') throw new Error('not classified: ' + jaState.doc);
if (jaState.legalFld.join(',') !== '保険者番号,記号,番号,枝番') throw new Error('legal rows unnamed: ' + jaState.legalFld);
if (jaState.cards.length !== 1) throw new Error('ja footer cards: ' + jaState.cards.join(','));
const shot1 = path.join(OUT, 's14_01_after_sample.png');
await ja.screenshot({ path: shot1, fullPage: true });

// the footer block on its own, so the single-card layout is legible
const shot2 = path.join(OUT, 's14_02_footer.png');
await ja.locator('.partners').scrollIntoViewIfNeeded();
await ja.locator('.partners').screenshot({ path: shot2 });
await ja.close();

// ── ko regression: same screen, nothing moved ────────────────────────────────
const ko = await open(`${BASE}/safe/?lang=ko`);
await sample(ko);
const koState = await ko.evaluate(() => ({
  file: document.getElementById('fileName').textContent,
  doc: jpState.cls && jpState.cls.doc,
  cards: [...document.querySelectorAll('.partner-card')].filter(a => a.offsetParent !== null)
    .map(a => a.querySelector('strong').textContent.trim()),
  cats: [...document.querySelectorAll('#piiList input[data-cat]')].map(i => i.dataset.cat),
  title: document.title,
}));
if (koState.file !== '샘플_재직증명서.txt') throw new Error('ko specimen moved: ' + koState.file);
if (koState.doc) throw new Error('ko sample classified as JP: ' + koState.doc);
if (koState.cards.length !== 3) throw new Error('ko footer cards: ' + koState.cards.join(','));
const shot3 = path.join(OUT, 's14_03_ko.png');
await ko.screenshot({ path: shot3, fullPage: true });
await ko.close();

console.log(JSON.stringify({ ja: jaState, ko: koState, shots: [shot1, shot2, shot3], pageErrors: errs }, null, 1));
await browser.close();
