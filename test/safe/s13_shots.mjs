#!/usr/bin/env node
/*
 * S13 — screenshots of the Japanese entry point, before and after the sample.
 *
 *   node test/safe/s13_shots.mjs [base]      # default http://localhost:3001
 *
 * Needs a running app (or any server that serves public/safe/). Writes
 * docs/autorun/s13_01_before_upload.png and s13_02_after_sample.png at 1x.
 *
 * Why a script and not a one-off command: the two screens are the evidence for
 * items 1–3 (which specimen, which category rows, which tab title), and a
 * screenshot nobody can re-take is not evidence. It asserts the page actually
 * reached the state before shooting — a timeout that silently photographs an
 * empty dropzone would look like a passing capture.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const mod = await import('playwright');
const { chromium } = mod.default ?? mod;   // playwright is CJS: chromium hides under .default
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, '..', '..', 'docs', 'autorun');
const BASE = process.argv[2] || 'http://localhost:3001';
const URL = `${BASE}/safe/?lang=ja&purpose=bid_attachment&from=nyusatsu`;

fs.mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ channel: 'chrome' });
const page = await browser.newPage({ viewport: { width: 1280, height: 1600 }, deviceScaleFactor: 1 });
const errs = [];
page.on('pageerror', e => errs.push(String(e)));

const res = await page.goto(URL, { waitUntil: 'load' });
if (!res || res.status() !== 200) throw new Error(`${URL} → ${res && res.status()}`);
await page.waitForSelector('#btnSample');

// ① before uploading anything: the category list is the claim about who this is for
const cats = await page.evaluate(() => [...document.querySelectorAll('#piiList input[data-cat]')].map(i => i.dataset.cat));
if (cats[0] !== 'name') throw new Error('pre-upload list does not start at 氏名: ' + cats.join(','));
if (cats.includes('rrn') || cats.includes('ssn')) throw new Error('rrn/ssn still offered: ' + cats.join(','));
const shot1 = path.join(OUT, 's13_01_before_upload.png');
await page.screenshot({ path: shot1, fullPage: true });

// ② the sample the Japanese UI hands over
await page.click('#btnSample');
await page.waitForFunction(() => Array.isArray(pages) && pages.length > 0
  && document.getElementById('docWrap').style.display === 'flex', { timeout: 40000 });
await page.waitForTimeout(600);
const st = await page.evaluate(() => ({
  file: document.getElementById('fileName').textContent,
  doc: jpState.cls && jpState.cls.doc,
  purpose: jpState.purpose,
  title: document.title,
  bands: entities.filter(e => e.kind === 'auto').map(e => e.jp && e.jp.field),
}));
if (st.file !== '見本_資格確認書.txt') throw new Error('wrong specimen: ' + st.file);
if (st.doc !== 'shikaku_kakuninsho') throw new Error('not classified: ' + st.doc);
const shot2 = path.join(OUT, 's13_02_after_sample.png');
await page.screenshot({ path: shot2, fullPage: true });

console.log(JSON.stringify({ ...st, cats, shots: [shot1, shot2], pageErrors: errs }, null, 1));
await browser.close();
