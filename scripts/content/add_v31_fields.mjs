#!/usr/bin/env node
/*
 * One-shot: add the v3.1 §4 fields to content/jp/topics.json.
 *
 * Run once (2026-10-25, S8 §A.3) and kept in the tree so the derivation is
 * auditable — the blog titles below are the strategy's §4 table, not a
 * paraphrase, and `publish_on` is derived from it by a stated rule rather than
 * typed out 33 times.
 *
 * ── The date rule, and why it is a subtraction ──────────────────────────────
 *
 * Strategy v3 §4 prints a date per episode and calls the column 「게시(月)」
 * (publish, Monday). Every date in that column is a TUESDAY — cross-review Q5
 * measured it: 2026-10-27 is a Tuesday. The correction it asked for is to move
 * the whole table one day earlier, which makes ep01 2026-10-26 and keeps the
 * weekly cadence intact. So publish_on = (the §4 date) − 1 day, uniformly; the
 * table is left as the source and the shift is one line of code. A test asserts
 * every result is a Monday, because that is the property the operating schedule
 * depends on and a typo in a hand-written list of 33 dates is invisible.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const FILE = path.join(REPO, 'content', 'jp', 'topics.json');

// [ep, §4 date (the Tuesday as printed), intent, blog_title_ja]
const TABLE = [
  [1,  '2026-10-27', '手順', '【入札添付】資格確認書の番号を隠して提出する手順'],
  [2,  '2026-11-03', '理由', '入札添付の資格確認書、「マスキング指示」の読み方'],
  [3,  '2026-11-10', '手順', 'ChatGPTに契約書を貼る前に個人情報だけ黒塗りする方法'],
  [4,  '2026-11-17', '手順', '賃貸借契約書を専門家に相談する前の匿名化の手順'],
  [5,  '2026-11-24', '手順', '電子入札のPDF容量制限と黒塗りを一度に済ませる方法'],
  [6,  '2026-12-01', '比較', '補助金精算の添付書類、どこまで隠すか【用途別】'],
  [7,  '2026-12-08', '比較', '源泉徴収票に個人番号がある場合・ない場合の扱い'],
  [8,  '2026-12-15', '手順', '家族の書類を代理で提出するときに確認すること'],
  [9,  '2026-12-22', '比較', 'マイナンバーカードの表面・裏面、提出が必要なのはどちらか'],
  [10, '2026-12-29', '手順', '運転免許証のコピーを送る前に確認する3つのこと'],
  [11, '2027-01-05', '比較', '住民票の写し：用途別に残す項目・隠す項目'],
  [12, '2027-01-12', '理由', '「黒塗りしたつもり」が読めてしまう仕組み'],
  [13, '2027-01-19', '理由', '付箋・マスキングテープで隠して撮影する方法の限界'],
  [14, '2027-01-26', '比較', '「マスキングしてください」と書く提出先、書かない提出先'],
  [15, '2027-02-02', '理由', '本人確認書類は「最小化」が原則 — 求められた面と項目だけ'],
  [16, '2027-02-09', '手順', 'フリマ・ネット銀行の本人確認、画像を送る前にできること'],
  [17, '2027-02-16', '手順', '賃貸契約で身分証のコピーを求められたら確認すること'],
  [18, '2027-02-23', '手順', '履歴書PDFを相談用に共有する — 連絡先だけ隠す方法'],
  [19, '2027-03-02', '比較', '給与明細を相談に出すとき、口座番号と社員番号の扱い'],
  [20, '2027-03-09', '比較', '通帳画像：残高証明として出す場合と相談用の違い'],
  [21, '2027-03-16', '手順', '在留カード：提出先が求める面を確認してから隠す'],
  [22, '2027-03-23', '比較', 'パスポートの番号・MRZを隠してよい場面、いけない場面'],
  [23, '2027-03-30', '理由', '職務経歴書を匿名で共有するときの考え方'],
  [24, '2027-04-06', '手順', 'スマホだけで：撮影 → 黒塗り → 確認 → 送信'],
  [25, '2027-04-13', '手順', '透かし「〇〇提出用」の入れ方と、その限界'],
  [26, '2027-04-20', '理由', '提出した本人確認書類はいつまで残るのか'],
  [27, '2027-04-27', '理由', '「そもそも出さない」という選択 — 最小化原則の実務'],
  [28, '2027-05-04', '手順', '学生証の画像を送るとき、学生が確認できること'],
  [29, '2027-05-11', '比較', '「サーバーに保存しない」ツールの見分け方'],
  [30, '2027-05-18', '理由', '2027年4月の犯収法改正で本人確認はどう変わるか'],
  [31, '2027-05-25', '手順', '副業の本人確認を毎回やり直さないために'],
  [32, '2027-06-01', '手順', '複数書類をまとめて処理する'],
  [33, '2027-06-08', '理由', '7か月の振り返りと、よくある黒塗りの落とし穴']
];

// ep30: the 2027-04 AML rule change — a claim about law that is not in force
// yet. ep32: batch processing, which has not shipped (it also carries
// blocked_until, which stops the build outright).
const VERIFY_BEFORE = new Set([ 30, 32 ]);
// Year-end (ep10) and Golden Week (ep28): blog only, X and LinkedIn roll into
// the following week. v3 said 「X만」 for these; cross-review Q5 inverted it,
// because the week people are away is the week a thread is least read and a
// blog post is most patient.
const SOCIAL_SKIP = new Set([ 10, 28 ]);

const minusOneDay = (iso) => {
  const d = new Date(`${iso}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() - 1);
  return d.toISOString().slice(0, 10);
};

const doc = JSON.parse(fs.readFileSync(FILE, 'utf8'));
const byEp = new Map(TABLE.map(([ep, date, intent, title]) => [ep, { date, intent, title }]));

if (doc.episodes.length !== TABLE.length) {
  throw new Error(`topics.json has ${doc.episodes.length} episodes, the §4 table has ${TABLE.length}`);
}

for (const e of doc.episodes) {
  const row = byEp.get(e.ep);
  if (!row) throw new Error(`ep${e.ep} is not in the §4 table`);

  const publishOn = minusOneDay(row.date);
  const dow = new Date(`${publishOn}T00:00:00Z`).getUTCDay();
  if (dow !== 1) throw new Error(`ep${e.ep}: publish_on ${publishOn} is not a Monday (getUTCDay=${dow})`);

  e.blog_title_ja = row.title;
  e.intent = row.intent;
  e.publish_on = publishOn;
  e.verify_before = VERIFY_BEFORE.has(e.ep);
  e.social_skip = SOCIAL_SKIP.has(e.ep);
}

const README_ADD = [
  '',
  '`publish_on` = the Monday the BLOG post goes live, 09:00 JST. ep01 = 2026-10-26.',
  'Strategy v3 §4 prints these dates one day later (all of them are Tuesdays —',
  'cross-review Q5 measured it), so publish_on is that table minus one day;',
  'scripts/content/add_v31_fields.mjs derives it and a Rails test asserts every',
  'value really is a Monday. `blog_title_ja` is the §4 search-intent title and is',
  'what the blog publishes; `title_ja` stays the X/carousel headline. `intent` is',
  'one of 手順 | 理由 | 比較. `verify_before` means the facts must be re-confirmed',
  'before the package may be scheduled (ep30 cites a rule that is not in force,',
  'ep32 describes a feature that has not shipped). `social_skip` means blog only',
  'that week — the X thread and LinkedIn post roll forward to the next Monday.'
];

if (!doc._readme.some((l) => l.includes('publish_on'))) doc._readme.push(...README_ADD);

fs.writeFileSync(FILE, JSON.stringify(doc, null, 2) + '\n');
console.log(`topics.json: ${doc.episodes.length} episodes updated; ep01 publish_on = ${doc.episodes[0].publish_on}`);
