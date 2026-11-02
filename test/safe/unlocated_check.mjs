#!/usr/bin/env node
/*
 * S11 item 8 — the "detected but not located" warning on the RESULT screen.
 *
 *   node test/safe/unlocated_check.mjs [base]     # default http://localhost:3001
 *
 * Needs a running app (or any server that serves public/safe/index.html).
 *
 * Why this is its own harness rather than a case in run.mjs: the golden suite
 * measures what gets MASKED — pixel coverage, band geometry, the legal matrix.
 * This box is about what did NOT get masked, and it is rendered at the one
 * moment the golden suite stops looking: after the file is built, when someone
 * is deciding whether to attach it. The sales playbook §5-1 asked for exactly
 * this ("오류가 보이게"), and until S11 the only sign was a small grey chip in
 * the detection list, above the fold and before the document existed.
 *
 * What is checked, in order:
 *   1. a real end-to-end run (paste → scan → build) leaves the box HIDDEN when
 *      nothing was missed — a warning that is usually visible stops being read
 *   2. with unlocated entities present it is visible, red, and counts only the
 *      ones the visitor asked to hide
 *   3. the VALUE is masked, not reprinted — a warning that echoes the secret
 *      puts it on the screen that is about to be handed over
 *   4. a language switch rebuilds it, in all four languages
 *
 * Exit 0 = all pass.
 */
const mod = await import('playwright');
const { chromium } = mod.default ?? mod;
const BASE = process.argv[2] || 'http://localhost:3001';
let pass = 0; const fails = [];
const ok = (l, c, d='') => { if (c) { pass++; return; } fails.push(`${l}${d?' — '+d:''}`); console.log('  FAIL ' + l + (d?' — '+d:'')); };

const b = await chromium.launch({ channel: 'chrome' });
const page = await b.newPage();
const errs = [];
page.on('pageerror', e => errs.push(String(e)));
await page.goto(`${BASE}/safe/?lang=ko`, { waitUntil: 'load' });

const read = () => page.evaluate(() => {
  const el = document.getElementById('resultUnlocated');
  const cs = getComputedStyle(el);
  return { display: cs.display, color: cs.color, border: cs.borderLeftColor, text: el.innerText, html: el.innerHTML };
});

/* ── 1. the WIRING, measured through the real build ───────────────────────
 *
 * The three synthetic entities are pushed BEFORE #btnMake is clicked, and
 * renderUnlocated is never called from here — so this phase fails unless
 * showResult() calls it.
 *
 * ⚠️ The first version of this harness called renderUnlocated() directly and
 * checked the box afterwards. A mutation probe showed what that was worth:
 * deleting the call from showResult left the harness fully green, because
 * "hidden when nothing was missed" is also what a box that is never rendered
 * looks like. The assertions were describing a function, not a screen. */
await page.click('#btnPaste');
await page.fill('#pasteArea', '홍길동 주민등록번호 900101-1234567 전화 010-1234-5678');
await page.click('#btnPasteScan');
await page.waitForSelector('#docWrap', { state: 'visible', timeout: 20000 });

ok('the box exists in the DOM', await page.locator('#resultUnlocated').count() === 1);
const realMisses = await page.evaluate(() => entities.filter(e => isOn(e) && e.mode !== 'ok' && !located(e)).length);
ok('premise: the pasted document itself misses nothing', realMisses === 0, String(realMisses));

// Two entities we "found" but could not place, plus one the visitor chose to
// leave visible — which is not a miss and must not be listed.
await page.evaluate(() => {
  entities.push({ id: 'probe1', type: 'rrn', value: '900101-1234567', mode: 'no', kind: 'auto', boxes: [] });
  entities.push({ id: 'probe2', type: 'account', value: '110-123-456789', mode: 'no', kind: 'auto', boxes: [] });
  entities.push({ id: 'probe3', type: 'phone', value: '010-1234-5678', mode: 'ok', kind: 'auto', boxes: [] });
});
await page.click('#btnMake');
await page.waitForSelector('#result', { state: 'visible', timeout: 20000 });

ok('result screen renders', await page.locator('#result').isVisible());
const shown = await read();
ok('showResult WIRES the box — it is visible after a real build, with no direct call',
   shown.display !== 'none', shown.display);
ok('no JS error during the build', errs.length === 0, errs.join(' | '));

/* ── 2. hidden when nothing was missed ───────────────────────────────────
 * Checked by removing the synthetic entities and rebuilding through the same
 * path, so "hidden" is a decision the function made and not the default
 * state of an element nobody touched. */
await page.evaluate(() => { entities = entities.filter(e => !e.id.startsWith('probe')); });
await page.click('#btnMake');
await page.waitForSelector('#result', { state: 'visible', timeout: 20000 });
ok('box hidden again when nothing was missed', (await read()).display === 'none', (await read()).display);

// Put them back for the content assertions below.
await page.evaluate(() => {
  entities.push({ id: 'probe1', type: 'rrn', value: '900101-1234567', mode: 'no', kind: 'auto', boxes: [] });
  entities.push({ id: 'probe2', type: 'account', value: '110-123-456789', mode: 'no', kind: 'auto', boxes: [] });
  entities.push({ id: 'probe3', type: 'phone', value: '010-1234-5678', mode: 'ok', kind: 'auto', boxes: [] });
  renderUnlocated();
});
Object.assign(shown, await read());

ok('box becomes visible', shown.display !== 'none', shown.display);
ok('box is red', /rgb\(179, *64, *42\)/.test(shown.color), shown.color);
ok('left border is red', /rgb\(179, *64, *42\)/.test(shown.border), shown.border);
ok('counts 2, not 3 — an item left visible on purpose is not a miss',
   shown.text.includes('2건'), shown.text.replace(/\n/g, ' / '));
ok('names both categories', shown.text.includes('주민등록번호') && shown.text.includes('계좌번호'),
   shown.text.replace(/\n/g, ' / '));
ok('tells the reader to check before saving', shown.text.includes('저장'), '');
// The value must NOT be printed in the clear: a warning that reprints the
// secret puts it on the screen the user is about to hand over.
ok('the raw value is masked, not reprinted', !shown.html.includes('900101-1234567'),
   shown.html.slice(0, 200));
ok('masked blocks are shown instead', /■/.test(shown.text), shown.text.replace(/\n/g, ' / '));
// A category whose mode is 'ok' is not listed.
ok('the mode=ok entity is absent', !shown.text.includes('전화번호'), shown.text.replace(/\n/g, ' / '));

// ── language switch must rebuild it (applyLang calls renderUnlocated).
const ja = await page.evaluate(() => { LANG = 'ja'; applyLang(); return document.getElementById('resultUnlocated').innerText; });
ok('language switch rebuilds the box in Japanese', ja.includes('位置を特定できなかった'), ja.replace(/\n/g, ' / '));
const en = await page.evaluate(() => { LANG = 'en'; applyLang(); return document.getElementById('resultUnlocated').innerText; });
ok('and in English', en.includes('could not be located'), en.replace(/\n/g, ' / '));
const es = await page.evaluate(() => { LANG = 'es'; applyLang(); return document.getElementById('resultUnlocated').innerText; });
ok('and in Spanish', es.includes('sin ubicar'), es.replace(/\n/g, ' / '));

ok('no JS error at any point', errs.length === 0, errs.join(' | '));

console.log('\n' + '='.repeat(50));
if (fails.length) { console.log(`${pass} pass / ${fails.length} FAIL`); process.exit(1); }
console.log(`ALL ${pass} CHECKS PASSED`);
await b.close();
