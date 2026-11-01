#!/usr/bin/env node
/*
 * Live check for the SafeFile JP landing pages and the /safe/ entry parameters.
 *
 *   node test/safe/jp_landing_check.mjs [base]      # default http://localhost:3001
 *
 * Needs a RUNNING app (the pilot form and the counters are server endpoints, so
 * the static server run.mjs uses cannot answer them). Checks, in order:
 *
 *   1. each landing page renders, carries its canonical copy, and its CTA link
 *      agrees with the purpose its click counter reports
 *   2. landing_view fires once per page load and cta_click fires on the CTA
 *   3. /safe/?lang=ja&purpose=…&from=… preselects language and purpose, and the
 *      preselect SURVIVES "another document" (resetAll)
 *   4. the pilot form posts, shows the Japanese thank-you, and rejects a
 *      honeypot submission indistinguishably
 *   5. no third-party script is loaded by any of the three pages
 *
 * Exit 0 = all pass. Failures print the page and the expectation.
 */
import { chromium } from 'playwright';

const BASE = process.argv[2] || 'http://localhost:3001';

let pass = 0;
const fails = [];
function ok(label, cond, detail = '') {
  if (cond) { pass++; return; }
  fails.push(`${label}${detail ? ' — ' + detail : ''}`);
  console.log(`  FAIL  ${label}${detail ? ' — ' + detail : ''}`);
}

// Copy that must appear verbatim. Pulled from
// docs/jp/jp_landing_copy_2026-10-22.md — if a phrase here stops matching, the
// landing page has drifted from the canonical copy, which is the one thing
// S6 was told not to do.
const PAGES = [
  {
    slug: 'nyusatsu',
    from: 'nyusatsu',
    purpose: 'bid_attachment',
    title: '入札添付の資格確認書・保険証コピー、番号だけ自動で黒塗り | SafeFile',
    h1: '入札添付の資格確認書、番号だけを自動で黒塗り。再提出をなくす。',
    copy: [
      '公共工事の入札では、健康保険の資格確認書や被保険者証の写しに「被保険者等記号・番号」「保険者番号」のマスキングが求められます（告知要求制限）。',
      '付箋や修正テープで隠した写しは、スキャン時に番号が透けることがある',
      '枝番や二次元コードを見落とすと、発注者側で差し戻しになる',
      '※ 提出先の指示が優先です。指示と異なる場合は「残す項目」を個別に切り替えられます。',
      '月額 2,980円（税込）／年額 29,800円',
      // The Team plan list is a roadmap: the file input takes one file. Without
      // this line the list reads as shipped, which is advertising a feature
      // that does not exist.
      '※ 以下の機能はパイロット期間中に順次提供します（現在は1ファイルずつ処理）',
      '先行導入パイロット募集',
      '健康保険法等の改正による告知要求制限（2020年10月1日施行）。'
    ],
    // Phrases that were REMOVED and must not come back. The step list used to
    // say 「— 複数まとめて可」, which is not true of the tool today.
    absent: ['複数まとめて可'],
    // The search snippet said 「複数PDFを一括、」 too (B-10, approved 2026-10-22).
    // Asserted as EXACT equality across all three tags, not as an absent
    // phrase: `absent` is checked against body text, which never contains
    // <head>, so the snippet claim was invisible to this harness while the
    // page copy was already corrected. Equality also catches the phrase coming
    // back, in any of the three places it was written.
    description: '公共工事の入札で求められる被保険者記号・番号・保険者番号のマスキングを、ブラウザだけで自動処理。ファイルはサーバーに送信しません。再提出をなくします。'
  },
  {
    slug: 'honnin-kakunin',
    from: 'honnin',
    purpose: 'identity_submit',
    title: '免許証・マイナンバーカードを送る前に — 必要な面だけ、不要な情報は黒塗り | SafeFile',
    h1: '本人確認書類は「必要な面だけ」。求められていない情報は、送らない。',
    copy: [
      '銀行・カード・通信・フリマの本人確認では、提出先が指定した面と項目だけで足ります。',
      '裏面全体、表面の臓器提供欄',
      '裏面の備考欄（旧住所など）、臓器提供欄',
      'スマホの編集アプリで塗った黒は、半透明だったり、PDFの文字層が残っていたりします。',
      '2026年以降、スマートフォンのマイナンバーカードやICチップ読み取り（JPKI）による本人確認が広がり'
    ]
  },
  {
    slug: 'ai-mae',
    from: 'aimae',
    purpose: 'consult_share',
    title: 'ChatGPT・Claudeに契約書や給与明細を貼る前に、個人情報だけ黒塗り | SafeFile',
    h1: 'AIに相談する前に、個人情報だけ黒塗り。文脈はそのまま。',
    copy: [
      '賃貸借契約書、給与明細、請求書、診断書をAIに貼り付けて相談する人が増えています。',
      '相手方（貸主・保証人・取引先）の氏名・住所・電話',
      '残るもの：契約条項、金額の相対関係、日付、見出し — AIが答えるのに必要な部分',
      '制限なしで30日間。契約書を何通も見直す月だけ。サブスクではありません。'
    ]
  }
];

// Phrases the copy rules forbid outright (docs/jp/jp_landing_copy §공통 규칙).
const FORBIDDEN = ['タイムズカー', '絶対', '防ぎます', '唯一', '必ず安全'];

const browser = await chromium.launch({ channel: 'chrome' });

/* Records every counter the page sends, with its payload AND the status the
 * server answered with.
 *
 * Playwright cannot read a sendBeacon payload: the body is a Blob and both
 * postData() and postDataBuffer() come back null for it (measured — every
 * landing_view read as `{}` while the rows were landing in the database
 * correctly). So the payload is captured INSIDE the page by wrapping
 * navigator.sendBeacon, and the wrapper still delegates to the real one so
 * delivery is unchanged.
 *
 * The status matters as much as the payload: /api/safe_events answers 204 only
 * when every key and value passed SafeEvent's whitelist, so a 204 is the
 * server agreeing that nothing un-whitelisted was sent. Asserting the payload
 * alone would only prove what the page MEANT to send.
 */
async function trackBeacons(page) {
  const statuses = [];
  page.on('response', (res) => {
    if (new URL(res.url()).pathname === '/api/safe_events') statuses.push(res.status());
  });

  await page.addInitScript(() => {
    window.__beacons = [];
    const realBeacon = navigator.sendBeacon ? navigator.sendBeacon.bind(navigator) : null;
    const record = (url, body) => {
      if (String(url).indexOf('/api/safe_events') === -1) return;
      // Blob.text() is async; keep the promise and resolve it from the harness.
      window.__beacons.push(body && body.text ? body.text() : Promise.resolve(String(body)));
    };
    if (realBeacon) {
      navigator.sendBeacon = (url, body) => { record(url, body); return realBeacon(url, body); };
    }
    const realFetch = window.fetch.bind(window);
    window.fetch = (url, opts) => { if (opts && opts.body) record(url, opts.body); return realFetch(url, opts); };
  });

  return {
    statuses,
    async read() {
      const raw = await page.evaluate(() => Promise.all(window.__beacons || []));
      return raw.map((r) => { try { return JSON.parse(r); } catch { return { name: '<unparseable>' }; } });
    }
  };
}

function thirdParty(page) {
  const hosts = new Set();
  page.on('request', (req) => {
    const h = new URL(req.url()).hostname;
    if (h !== new URL(BASE).hostname) hosts.add(h);
  });
  return hosts;
}

/* ── 1 + 2 + 5. landing pages ───────────────────────────────────────────── */
console.log('\n[1/4] landing pages — copy, CTA, counters, no third-party script');
for (const p of PAGES) {
  const page = await browser.newPage();
  const beacons = await trackBeacons(page);
  const hosts = thirdParty(page);
  const url = `${BASE}/safe/jp/${p.slug}/`;
  const res = await page.goto(url, { waitUntil: 'networkidle' });

  ok(`${p.slug}: 200`, res.status() === 200, `got ${res.status()}`);
  ok(`${p.slug}: lang=ja`, await page.getAttribute('html', 'lang') === 'ja');
  ok(`${p.slug}: title`, await page.title() === p.title, await page.title());

  const h1 = (await page.textContent('h1') || '').trim();
  ok(`${p.slug}: h1 verbatim`, h1 === p.h1, h1);

  const body = await page.textContent('body');
  for (const phrase of p.copy) {
    ok(`${p.slug}: copy "${phrase.slice(0, 22)}…"`, body.includes(phrase));
  }
  for (const phrase of (p.absent || [])) {
    ok(`${p.slug}: removed "${phrase}" stays removed`, !body.includes(phrase));
  }
  ok(`${p.slug}: carries 提出先の指示を必ず確認`, body.includes('提出先の指示を必ず確認'));

  // The three description tags are written out separately in the HTML, so one
  // of them drifting is the normal failure. Only pages whose snippet copy is
  // pinned by a human decision declare `description`.
  if (p.description) {
    for (const sel of ['meta[name=description]', 'meta[property="og:description"]', 'meta[name="twitter:description"]']) {
      const got = await page.getAttribute(sel, 'content');
      ok(`${p.slug}: ${sel} matches canonical copy`, got === p.description, got);
    }
  }
  for (const bad of FORBIDDEN) {
    ok(`${p.slug}: no forbidden "${bad}"`, !body.includes(bad));
  }

  // The English parallel block lives inside this same URL, which is why the
  // page declares no hreflang. Both halves of that have to hold.
  ok(`${p.slug}: EN block present`, await page.locator('details.en').count() === 1);
  ok(`${p.slug}: no hreflang`, await page.locator('link[rel=alternate][hreflang]').count() === 0);
  const canon = await page.getAttribute('link[rel=canonical]', 'href');
  ok(`${p.slug}: self canonical`, canon === `https://slimfile.net/safe/jp/${p.slug}/`, canon);

  /* ── social preview (S8) ──────────────────────────────────────────────────
   * LinkedIn previewed these pages as "DocPack - Image Compression & PDF
   * Conversion" with a 512×512 app icon: og:title repeated the <title> (which
   * ends in "| SafeFile" and is written for a SERP, not for a card) and
   * og:image pointed at a square icon that a 1.91:1 card letterboxes.
   *
   * og:description is deliberately NOT re-checked here — the block above
   * already asserts it is byte-identical to meta[name=description], which is
   * the no-drift rule B-10 exists for. Adding a second expectation for the
   * same tag is how the two start disagreeing. */
  const ogTitle = await page.getAttribute('meta[property="og:title"]', 'content');
  ok(`${p.slug}: og:title is the page's H1`, ogTitle === p.h1, ogTitle);
  const ogImage = await page.getAttribute('meta[property="og:image"]', 'content');
  ok(`${p.slug}: og:image is the 1200x630 brand card`,
     ogImage === 'https://slimfile.net/safe/brand/og_1200x630.png', ogImage);
  const ogLocale = await page.getAttribute('meta[property="og:locale"]', 'content');
  ok(`${p.slug}: og:locale ja_JP`, ogLocale === 'ja_JP', ogLocale);
  const twCard = await page.getAttribute('meta[name="twitter:card"]', 'content');
  ok(`${p.slug}: twitter:card summary_large_image`, twCard === 'summary_large_image', twCard);

  // CTA: the href's purpose and the counter's purpose must be the same value.
  // They are written in two places (HTML attribute and query string) and a
  // mismatch would silently misattribute every conversion.
  const cta = page.locator('[data-cta]').first();
  const href = await cta.getAttribute('href');
  const dataPurpose = await cta.getAttribute('data-purpose');
  const q = new URLSearchParams(href.split('?')[1] || '');
  ok(`${p.slug}: CTA purpose agrees`, q.get('purpose') === p.purpose && dataPurpose === p.purpose,
     `href=${q.get('purpose')} data=${dataPurpose} want=${p.purpose}`);
  ok(`${p.slug}: CTA from`, q.get('from') === p.from, q.get('from'));
  ok(`${p.slug}: CTA lang=ja`, q.get('lang') === 'ja');

  const sent = await beacons.read();
  const views = sent.filter((b) => b.name === 'landing_view');
  ok(`${p.slug}: exactly one landing_view`, views.length === 1, `got ${views.length} of ${sent.length} beacons`);
  /* "Categories only" is the privacy claim this endpoint is built on, so it is
   * checked as two separate properties rather than as one frozen object:
   *
   *   1. the KEY SET is exactly what we expect — adding a dimension has to be a
   *      deliberate edit here, because each one is a new thing recorded about a
   *      visit;
   *   2. every VALUE is a short lowercase token, i.e. a category and not free
   *      text. Pinning exact values instead would re-assert what the `from` and
   *      `utm_source` checks already cover, and would turn a legitimate new
   *      category into a failure.
   *
   * A source dimension was added 2026-10-25: P16 ("share of landing visits
   * arriving from social") had no dimension to compute from, and would have
   * reported a confident 0 forever.
   *
   * ── S10: the key is OMITTED on a direct visit, not sent as 'none' ─────────
   *
   * It used to send `utm_source: 'none'`. S10 replaced `?utm_*` with `?via=`
   * (blocking extensions strip `utm_*` before the request is made) and made
   * jp.js send only the dimensions the visit actually has — sending
   * `via:'none'` AND `utm_source:'none'` would write the same non-fact into
   * two columns of the weekly table.
   *
   * So a direct visit carries `from` and `locale` and nothing else, and the
   * absent key is the assertion. P16's denominator counts these visits from
   * the event rows rather than from the groupings, which is what makes
   * omitting the key safe (JpWeeklyKpi#p16, and the test that pins it).
   *
   * ⚠️ This expectation was stale for the length of S10: jp.js changed and
   * this harness was not re-run in that session. Caught in S10b. */
  const VIEW_KEYS = ['from', 'locale'];
  const SOURCE_KEYS = ['via', 'utm_source'];
  const props = views.length === 1 ? views[0].props : {};
  ok(`${p.slug}: landing_view carries exactly ${VIEW_KEYS.join('/')} on a direct visit`,
     JSON.stringify(Object.keys(props).sort()) === JSON.stringify([...VIEW_KEYS].sort()),
     JSON.stringify(props));
  ok(`${p.slug}: landing_view props are categories only`,
     Object.values(props).length > 0 && Object.values(props).every((v) => /^[a-z_]{1,24}$/.test(String(v))),
     JSON.stringify(props));
  // The point of the change, asserted directly: no source key at all, and
  // never both of them (SafeEvent rejects the pair outright — S10b).
  ok(`${p.slug}: landing_view carries NO source key on a direct visit`,
     SOURCE_KEYS.every((k) => !(k in props)),
     JSON.stringify(props));
  // 204 = the server's own whitelist accepted it. A 422 here would mean the
  // page is sending something SafeEvent refuses — silently, because sendBeacon
  // never reads the response.
  ok(`${p.slug}: server accepted every counter`,
     beacons.statuses.length > 0 && beacons.statuses.every((s) => s === 204),
     beacons.statuses.join(','));
  // Snapshot the count so the CTA's own status can be checked separately. This
  // assertion runs BEFORE the click, so without the snapshot the cta_click
  // request's status is never looked at — the harness claimed "every counter"
  // while only ever covering landing_view.
  const statusesBeforeClick = beacons.statuses.length;

  // Click the CTA, but cancel the NAVIGATION only — the counter must still run.
  // preventDefault in the capture phase stops the link from being followed
  // without stopping jp.js's own bubble-phase listener. This matters because
  // the payload is recorded in a page-scoped array: let the navigation happen
  // and the array is rebuilt empty on the next document, which reads as "the
  // counter never fired" — exactly the false negative this harness hit first.
  await page.evaluate(() => {
    document.querySelectorAll('[data-cta]').forEach((el) =>
      el.addEventListener('click', (e) => e.preventDefault(), true));
  });
  await cta.click();
  // Wait for the REQUEST, not for a fixed 400 ms. The old sleep made this
  // section intermittently red on whichever page happened to be slow that run
  // — and "the counter did not fire" and "the counter had not fired YET" look
  // identical from out here, which is the failure mode this harness exists to
  // avoid. Polls for up to 3 s and gives up, so a genuine miss still fails.
  for (let i = 0; i < 30 && beacons.statuses.length === statusesBeforeClick; i++) {
    await page.waitForTimeout(100);
  }
  await page.waitForTimeout(100);
  const clicks = (await beacons.read()).filter((b) => b.name === 'cta_click');
  ok(`${p.slug}: cta_click fired`, clicks.length >= 1, `got ${clicks.length}`);
  ok(`${p.slug}: cta_click carries the purpose`,
     clicks.length >= 1 && clicks[0].props.purpose === p.purpose,
     JSON.stringify(clicks[0] && clicks[0].props));
  // The CTA's OWN response, not the page load's. A cta_click whose props the
  // whitelist refuses would 422 here while the payload assertion above stayed
  // green, because the payload only proves what the page meant to send.
  const ctaStatuses = beacons.statuses.slice(statusesBeforeClick);
  ok(`${p.slug}: server accepted the cta_click too`,
     ctaStatuses.length > 0 && ctaStatuses.every((s) => s === 204),
     ctaStatuses.length ? ctaStatuses.join(',') : 'no /api/safe_events response after the click');

  // Google Fonts is the one cross-origin host /safe/ already loads; an ad or
  // analytics host appearing here would break the page's own privacy claim.
  const unexpected = [...hosts].filter((h) => !['fonts.googleapis.com', 'fonts.gstatic.com'].includes(h));
  ok(`${p.slug}: no third-party host beyond the font CDN`, unexpected.length === 0, unexpected.join(', '));

  await page.close();
}

/* ── 3. /safe/ entry parameters ─────────────────────────────────────────── */
console.log('\n[2/4] /safe/ entry parameters — lang + purpose preselect');
{
  const page = await browser.newPage();
  // A stale remembered language must lose to an explicit ?lang=.
  await page.goto(`${BASE}/safe/`);
  await page.evaluate(() => localStorage.setItem('safefile_lang', 'ko'));
  await page.goto(`${BASE}/safe/?lang=ja&purpose=bid_attachment&from=nyusatsu`, { waitUntil: 'load' });

  ok('entry: ?lang=ja wins over remembered ko', await page.evaluate(() => LANG) === 'ja');
  ok('entry: html lang follows', await page.getAttribute('html', 'lang') === 'ja');
  ok('entry: purpose preselected', await page.evaluate(() => jpState.purpose) === 'bid_attachment');
  ok('entry: from captured', await page.evaluate(() => SF_PARAMS.from) === 'nyusatsu');

  // resetAll() rebuilds jpState from JP_STATE0. Without the parameter being
  // read there, pressing "another document" would silently drop back to
  // identity_submit — on the page a tender clerk presses most.
  await page.evaluate(() => resetAll());
  ok('entry: purpose survives resetAll', await page.evaluate(() => jpState.purpose) === 'bid_attachment');

  // An unknown purpose must be ignored, not stored.
  await page.goto(`${BASE}/safe/?purpose=../../etc&from=evil`, { waitUntil: 'load' });
  ok('entry: unknown purpose ignored', await page.evaluate(() => jpState.purpose) === 'identity_submit');
  ok('entry: unknown from becomes direct', await page.evaluate(() => SF_PARAMS.from) === 'direct');
  await page.close();
}

/* ── 4. pilot form ──────────────────────────────────────────────────────── */
console.log('\n[3/4] pilot form — validation, submit, honeypot, cap');
{
  const page = await browser.newPage();
  await page.goto(`${BASE}/safe/jp/nyusatsu/`, { waitUntil: 'networkidle' });

  // The honeypot must be unreachable for a human: off-screen, not focusable.
  const hp = page.locator('input[name=website]');
  ok('form: honeypot present', await hp.count() === 1);
  ok('form: honeypot not focusable', await hp.getAttribute('tabindex') === '-1');
  ok('form: honeypot off-screen', (await hp.boundingBox())?.x < 0);

  // Api::JpPilotController::RATE_LIMIT is 3 per IP per 10 minutes, so the four
  // submissions below are ordered to use that budget deliberately: the three
  // behaviours first, then the cap itself. The harness therefore needs a
  // limiter that has not already been spent — `docker compose restart web`
  // clears it in development (memory_store).
  const submit = async (fill) => {
    await page.goto(`${BASE}/safe/jp/nyusatsu/`, { waitUntil: 'networkidle' });
    await fill();
    const [res] = await Promise.all([
      page.waitForResponse((r) => r.url().includes('/api/jp_pilot')),
      page.click('#pilotSubmit')
    ]);
    await page.waitForTimeout(250);
    return { status: res.status(), msg: await page.textContent('#pilotMsg') };
  };

  const fillValid = async (email = 'pw@example.co.jp') => {
    await page.fill('#pf-company', 'プレイライト建設');
    await page.selectOption('#pf-industry', 'construction');
    await page.selectOption('#pf-count', '3-5');
    await page.fill('#pf-authority', '○○県');
    await page.fill('#pf-email', email);
  };

  // 1/3 — validation failure. The page must show its OWN Japanese wording; the
  // server returns field NAMES precisely so its locale can never land here.
  const bad = await submit(async () => {
    await page.fill('#pf-company', 'テスト');
    await page.fill('#pf-email', 'not-an-email');
  });
  if (bad.status === 429) {
    ok('form: limiter was not already spent', false,
       'got 429 on the first submission — restart the app (docker compose restart web) and re-run');
  } else {
    ok('form: invalid submission rejected', bad.status === 422, String(bad.status));
    ok('form: field-level JA error', bad.msg.includes('連絡先メール'), bad.msg);
    ok('form: no server-locale leak',
       !bad.msg.includes('Translation missing') && !/[가-힣]/.test(bad.msg), bad.msg);
  }

  // 2/3 — the real thing.
  const good = await submit(() => fillValid());
  ok('form: POST accepted', good.status === 201, String(good.status));
  ok('form: Japanese thank-you shown', good.msg.includes('お申し込みをお受けしました'), good.msg);
  ok('form: inputs locked after success', await page.isDisabled('#pilotSubmit'));

  // 3/3 — honeypot. Must be INDISTINGUISHABLE from a success on the wire; the
  // only difference is that no row is written, which the Rails controller test
  // asserts (this harness has no database handle).
  const spam = await submit(async () => {
    await fillValid('spam@example.com');
    await page.evaluate(() => { document.querySelector('input[name=website]').value = 'http://spam.example'; });
  });
  ok('form: honeypot answered like a success', spam.status === 201, String(spam.status));
  ok('form: honeypot shows the same thank-you', spam.msg.includes('お申し込みをお受けしました'), spam.msg);

  // 4th submission — over the per-IP cap.
  const capped = await submit(() => fillValid('over@example.co.jp'));
  ok('form: fourth submission is capped', capped.status === 429, String(capped.status));
  ok('form: cap message is Japanese', capped.msg.includes('送信が集中しています'), capped.msg);

  await page.close();
}

console.log('\n' + '='.repeat(60));
if (fails.length) {
  console.log(`${pass} pass / ${fails.length} FAIL`);
  fails.forEach((f) => console.log('  - ' + f));
  await browser.close();
  process.exit(1);
}
console.log(`ALL ${pass} CHECKS PASSED`);
await browser.close();
