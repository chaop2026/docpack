import { chromium } from 'playwright';
import server, { state } from './fault_server.mjs';

const BASE = 'http://localhost:4321/safe/';
const SW_FIXED = new URL('../../public/safe/sw.js', import.meta.url).pathname;
const SW_OLD   = process.argv[2] === '--old' ? true : false;
const LABEL    = SW_OLD ? 'PRE-FIX sw.js (expected to LOSE the offline shell)'
                        : 'FIXED sw.js (expected to KEEP the offline shell)';
state.swFile = SW_OLD ? new URL('./sw_old.js', import.meta.url).pathname : SW_FIXED;

const sleep = ms => new Promise(r => setTimeout(r, ms));
const results = [];
const check = (n, ok) => { results.push([n, ok]); console.log(`   ${ok ? 'OK  ' : 'FAIL'} ${n}`); return ok; };

const shellCaches = (page) => page.evaluate(async () => {
  const keys = (await caches.keys()).filter(k => k.startsWith('safefile-shell-'));
  const out = {};
  for (const k of keys) out[k] = (await (await caches.open(k)).keys()).map(r => new URL(r.url).pathname);
  return out;
});

const browser = await chromium.launch({ channel: 'chrome' });
const ctx = await browser.newContext();
const page = await ctx.newPage();

console.log(`\n══ ${LABEL} ══`);

// ── Phase 1: healthy install ────────────────────────────────────────────
state.failShell = false; state.swVersion = 1;
await page.goto(BASE, { waitUntil: 'load' });
await page.evaluate(() => navigator.serviceWorker.ready);
await sleep(2000);
const p1 = await shellCaches(page);
console.log('\n Phase 1 — healthy install');
console.log('   caches:', Object.keys(p1));
check('v1 shell cache exists', !!p1['safefile-shell-v2-1']);
check('v1 cache holds the shell', (p1['safefile-shell-v2-1'] || []).includes('/safe/'));

// ── Phase 2: update while '/safe/' is failing ───────────────────────────
state.failShell = true; state.swVersion = 2;
console.log("\n Phase 2 — update with '/safe/' returning 503");
await page.evaluate(async () => { const r = await navigator.serviceWorker.getRegistration(); await r.update().catch(()=>{}); });
await sleep(3500);

const p2 = await shellCaches(page);
console.log('   caches:', Object.keys(p2));
const keptOld = (p2['safefile-shell-v2-1'] || []).includes('/safe/');
check('previous version cache SURVIVES the failed update', keptOld);

// offline must still open the app
await ctx.setOffline(true);
let offlineShell = false, offlineShellV = false;
try { await page.goto(BASE, { waitUntil: 'domcontentloaded' }); offlineShell = !!(await page.$('.dropzone')); } catch (e) { console.log('   nav threw:', e.message.split('\n')[0]); }
try { await page.goto(BASE + '?v=20260719', { waitUntil: 'domcontentloaded' }); offlineShellV = !!(await page.$('.dropzone')); } catch (e) { console.log('   nav(?v) threw:', e.message.split('\n')[0]); }
await ctx.setOffline(false);
check('offline /safe/ still serves the shell', offlineShell);
check('offline /safe/?v=… still serves the shell', offlineShellV);

// ── Phase 3: recovery once the network is back ──────────────────────────
state.failShell = false;
console.log('\n Phase 3 — network restored');
await page.goto(BASE, { waitUntil: 'load' });
await page.evaluate(async () => { const r = await navigator.serviceWorker.getRegistration(); await r.update().catch(()=>{}); });
await sleep(3500);
await page.goto(BASE, { waitUntil: 'load' });
await sleep(1500);
const p3 = await shellCaches(page);
console.log('   caches:', Object.keys(p3));
check('v2 shell cache now exists', !!p3['safefile-shell-v2-2']);
check('v2 cache holds the shell', (p3['safefile-shell-v2-2'] || []).includes('/safe/'));
check('stale v1 cache is cleaned up', !p3['safefile-shell-v2-1']);

await ctx.setOffline(true);
let recovered = false;
try { await page.goto(BASE, { waitUntil: 'domcontentloaded' }); recovered = !!(await page.$('.dropzone')); } catch {}
await ctx.setOffline(false);
check('offline works again after recovery', recovered);

await browser.close();
server.close();

const failed = results.filter(([, ok]) => !ok);
console.log(`\n${failed.length === 0 ? 'ALL FAULT-INJECTION CHECKS PASS' : failed.length + ' FAILED: ' + failed.map(([n]) => n).join(' | ')}`);
process.exit(failed.length === 0 ? 0 : 1);
