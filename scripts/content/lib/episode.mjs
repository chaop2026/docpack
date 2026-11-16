/*
 * An episode's plan, its frontmatter and its identity — shared by
 * make_episode.mjs, make_short.mjs and make_longform.mjs (2026-11-16).
 *
 * These were make_episode.mjs's local definitions. They moved because the
 * Shorts cut and the monthly long-form cut need exactly the same answers:
 * which landing page, which dummy document, which blog slug, which `?via=`
 * URL. Two copies of `slugFor` means two slugs, and the one printed in a video
 * description is the one nobody checks against the database.
 */
import fs from 'node:fs';
import path from 'node:path';

export const BASE_URL = 'https://slimfile.net';

export const LANDING_PATH = {
  nyusatsu: '/safe/jp/nyusatsu/',
  honnin: '/safe/jp/honnin-kakunin/',
  aimae: '/safe/jp/ai-mae/'
};

/* Which dummy document stands in for each `doc` in topics.json.
 *
 * Two families, and the difference matters when you watch the recording:
 *
 *   the four ALPHA types — the tool CLASSIFIES these and applies the JP rules,
 *   so the demo shows automatic bars appearing in the right places. They have
 *   golden specs (test/safe/fixtures/jp/*.specs.json) and gen.py owns them.
 *
 *   the eight DEMO props (S10, gen_demo_docs.py) — the tool does not classify
 *   these, so the recording shows generic PII detection plus manual region
 *   select. That is the honest demo for them and exactly what the marketing
 *   plan (§0-5) specifies.
 *
 * `学生証` (ep26) has no dummy — stated, not faked. It falls through and the
 * manifest says so.
 */
export const FIXTURE_FOR_DOC = {
  // alpha — classified, golden-backed
  shikaku_kakuninsho: 'jp/shikaku_kakuninsho/kenpo.jpg',
  unten_menkyo: 'jp/unten_menkyo/front.jpg',
  mynumber_card: 'jp/mynumber_card/front.jpg',
  juminhyo: 'jp/juminhyo/ichibu_plain.jpg',
  // demo props — not classified, manual region select
  '契約書': 'jp/keiyakusho/chintai.jpg',
  '源泉徴収票': 'jp/gensen_choshuhyo/mynumber_on.jpg',
  '履歴書': 'jp/rirekisho/plain.jpg',
  '給与明細': 'jp/kyuyo_meisai/plain.jpg',
  '通帳': 'jp/tsucho/spread.jpg',
  '在留カード': 'jp/zairyu_card/front.jpg',
  'パスポート': 'jp/passport/data_page.jpg',
  '職務経歴書': 'jp/shokumu_keirekisho/plain.jpg'
};

/* ── frontmatter ──────────────────────────────────────────────────────────── */
/* A deliberately small YAML subset: `key: value` and `key:` followed by `- `
 * items. Pulling in a YAML dependency for five keys would buy nothing, and a
 * parser that quietly accepted more than this would let the post file drift
 * into shapes the rest of the pipeline does not read. Unknown keys are kept as
 * strings and passed through.
 */
const unquote = (s) => s.replace(/^["'](.*)["']$/, '$1').trim();

export function parseFrontmatter(text) {
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
    const [ , key, value ] = kv;
    if (value === '') { listKey = key; data[key] = []; } else { listKey = null; data[key] = unquote(value); }
  }
  return { data, body };
}

/* ── identity ─────────────────────────────────────────────────────────────── */
/*
 * The published blog slug, mirroring JpEpisodeSource#slug.
 *
 * Duplicated across the Ruby/JS boundary because a video description has to
 * contain the article URL and these scripts never talk to the database. A
 * mirrored implementation can drift, so test/integration/jp_shorts_test.rb
 * compares the two for every episode in topics.json rather than trusting this
 * comment. ActiveSupport's `parameterize` is transliterate + downcase +
 * non-alphanumeric to '-' + squeeze + trim; `title_en` is already ASCII, so
 * transliteration is a no-op here and the rest is this regex chain.
 */
export function slugFor(t) {
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

/* ── attribution ──────────────────────────────────────────────────────────── */
/*
 * `?via=<channel>&ep=epNN`, NOT `?utm_*` (S10).
 *
 * Ad/tracker-blocking extensions strip `?utm_*` before the request is made —
 * measured 2026-10-27, the author's own Chrome would not open his own shared
 * link while the server answered 200 to everything. Mirrors
 * JpEpisodeSource#via_url; the two build the same string for the same episode
 * and a test pins that.
 *
 * 🔴 `channel` must be a value the server will store (SafeEvent::VALUES["via"]).
 * An unknown value does not degrade — `sanitize` returns nil and the WHOLE
 * event is discarded, and sendBeacon never reads the response, so the loss is
 * invisible from both ends. The known video channels are `youtube` (Shorts and
 * the channel profile link) and `yt_long` (the monthly long-form cut).
 */
export function viaUrl({ landing, channel, epp }) {
  return `${BASE_URL}${landing}?via=${channel}&ep=ep${epp}`;
}

export function blogUrl({ slug, channel, epp, locale = 'ja' }) {
  return `${BASE_URL}/${locale}/blog/${slug}?via=${channel}&ep=ep${epp}`;
}

/* ── the plan ─────────────────────────────────────────────────────────────── */
/*
 * Throws rather than returning null for a missing or blocked episode. The one
 * caller that could "handle" it would print a message and exit, so the error
 * carries the message instead.
 */
export function loadTopic(contentDir, ep) {
  const plan = JSON.parse(fs.readFileSync(path.join(contentDir, 'topics.json'), 'utf8'));
  const topic = plan.episodes.find((e) => e.ep === ep);
  if (!topic) throw new Error(`ep${ep} is not in content/jp/topics.json`);
  if (topic.blocked_until) {
    // ep32 advertises batch processing, which does not exist. The strategy
    // forbids promoting unshipped features, so refuse rather than build it.
    throw new Error(`ep${ep} is blocked until ${topic.blocked_until}: ${topic.note || ''}`);
  }
  const landing = LANDING_PATH[topic.landing];
  if (!landing) throw new Error(`ep${ep}: unknown landing "${topic.landing}"`);
  return { plan, topic, landing };
}
